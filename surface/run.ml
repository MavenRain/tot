(** Script driver: lex, parse, elaborate, kernel-check, erase, and (in
    run mode) execute, threading both global environments through the
    items. Output lines accumulate newest-first and are reversed at the
    end. *)

open Tot_kernel

let ( let* ) = Result.bind

type state = {
  globals : Global.t;
  eglobals : Interp.globals;
  lines : string list;  (** newest first *)
}

let initial : state = { globals = Global.empty; eglobals = Interp.empty_globals; lines = [] }

(** M4 Stage B: installation policy, distinct from anything the kernel
    knows about (a driver flag has no business in the trusted base).
    [no_axioms] rejects an [axiom] item in the USER file; it is never
    applied to the prelude ([Bootstrap.fold_prelude_items] always folds with
    [default_policy]), so a hook installation that runs with
    [--no-axioms] still gets the monad-law axioms the prelude itself
    postulates. [require_main] (M4 Stage D, D5.2) rejects a script with
    no "main" def; the misspelled-main residual (SPEC section 6) stays
    the documented default, an opt-in strictness for an installation's
    shebang wrapper. *)
type policy = {
  no_axioms : bool;
  require_main : bool;
  strict_json : bool;
      (** M5 Stage A (pin 20): under [--strict-json] a stdin payload
          that is not one well-formed JSON value is refused at
          [Effect.dispatch]'s [readStdin] arm, BEFORE the script sees
          it: an [IO Verdict] script renders the deny envelope and
          exits 2, an [IO Unit] script takes the driver contract
          ([Serror.Json_strict_reject], exit 1).  Default off, so
          every installed guard keeps the fail-open posture
          byte-identical on upgrade. *)
  wf_rule : Totality.rule;
      (** M5 Stage E (SPIKE): which totality rule a user-file [def rec]
          is guarded under.  [Totality.Structural] is the shipped rule;
          [Totality.Structural_wf] is the measured prototype, reachable
          only through the driver flag --experimental-wf.  The prelude
          bootstrap folds with [default_policy], so a prelude [def rec]
          is never checked under the prototype and no flag can enter
          the cache key. *)
}

let default_policy : policy =
  { no_axioms = false; require_main = false; strict_json = false; wf_rule = Totality.Structural }

let kernel (loc : Loc.t) (r : ('a, Error.t) result) : ('a, Serror.t) result =
  Result.map_error (fun err -> Serror.Kernel { loc; err }) r

(** Quantities of a stamped def body's leading [Term.Lam] telescope,
    outermost first. Same walk shape as [Totality.peel], but keeping the
    quantities instead of the peeled body: [Totality.guard]'s [rec_arg]
    indexes into exactly this list. *)
let rec lam_quantities (t : Term.t) : Quantity.t list =
  match t with
  | Term.Lam (q, _x, b) -> q :: lam_quantities b
  | Term.Var _ | Term.Univ _ | Term.Auto
  | Term.Pi (_, _, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Match _ | Term.Lit _ ->
      []

(** Turn the kernel's [rec_arg] (an index into the UNERASED formal
    telescope, outermost first, per [Totality.peel]/[Totality.guard])
    into the runtime guard (an index into the ERASED spine
    [Interp.apply]'s guard actually walks: [Erase.term] drops every
    [Quantity.Zero] [Lam] binder and [Quantity.Zero] [App] argument, so
    the two spines diverge whenever an erased formal precedes the
    principal one). [GuardedAt k'] where [k'] counts the [Quantity.Many]
    formals strictly before position [k] is the [Many] case, M2 fixes
    Round 2's remap, verbatim.

    The [Zero] case is M2 fixes Round 4's rule made EXECUTABLE: when the
    guarded formal is erased the runtime spine never carries it, so
    there is no principal position left to test. Round 4 argued that
    such a def's erased body cannot mention its own name, and therefore
    unfolds eagerly without looping: a quantity-0 formal can only be
    eliminated (matched on) while checking at [Quantity.Zero] mode, the
    same attenuation [Check.infer]'s [Var] arm enforces (using a
    0-bound variable at mode [Many] is [Erased_use]), so every branch of
    a match on it, and every recursive call reachable through those
    branches, is itself checked at mode [Zero]; [Erase.term]'s
    [App (Quantity.Zero, f, _a) -> term ctx f] arm drops such a subterm
    WHOLESALE at its use site without walking it. Mechanically confirmed
    for the [ghost] fixture (test/fixtures/s0-erased-guard.tot) by a
    kernel-level [Eterm.t] walk: test/main.ml's "T0: rec def guarded on
    an erased formal has no self-reference after erasure".

    M4 Stage A relaxed the invariant that argument rested on (subsingleton
    elimination lets a match run at mode [w] on an erased scrutinee of a
    family with no runtime bits, which was not true when Round 4 argued
    this), so we no longer assume it: we RUN [Eterm.mentions] on the
    erased body. No mention gives [Unguarded], the Round 4 behavior and
    the only live case. A mention gives [Frozen], a permanent neutral,
    dead code by the emptiness argument in SPEC's Stage A entry. (An
    earlier revision of this arm froze unconditionally instead, on a
    divergence claim that had no actual witness; reverted, see the log.)

    Total: an out-of-range [k] (should not arise, [Totality.guard] only
    returns in-range positions) also falls back to [Unguarded] (no guard
    at all, i.e. today's plain-def behavior), since [List.nth_opt qs k]
    itself misses first. *)
let compute_guard ~(name : string) (def : Term.t) (rec_arg : int option)
    (def_e : Eterm.t) : Interp.guard =
  let qs = lam_quantities def in
  rec_arg
  |> Option.fold ~none:Interp.Unguarded ~some:(fun k ->
         List.nth_opt qs k
         |> Option.fold ~none:Interp.Unguarded ~some:(fun q ->
                match q with
                | Quantity.Many ->
                    Interp.GuardedAt
                      (List.length
                         (List.filteri
                            (fun ix q' -> ix < k && Quantity.equal q' Quantity.Many)
                            qs))
                | Quantity.Zero ->
                    (match () with
                    | () when Eterm.mentions name def_e -> Interp.Frozen
                    | () -> Interp.Unguarded)))

(** M4 Stage D (D5.4): [Syntax.defkind] back to the kernel's own
    [~rec_]/[~partial] pair. [Check.define]'s signature is unchanged
    (its shape is marshaled and this stage must not touch the cache
    shape twice), so every consumer maps the sum back with this one
    exhaustive match. *)
let defkind_bools (k : Syntax.defkind) : bool * bool =
  match k with
  | Syntax.DNonRec -> (false, false)
  | Syntax.DRec -> (true, false)
  | Syntax.DRecPartial -> (true, true)

(** M4 Stage D (D3): peel [t]'s leading [Syntax.SPi] binders (a
    parametric instance's own type/dictionary telescope), unelaborated. *)
let rec peel_syntax_codomain (t : Syntax.t) : Syntax.t =
  match t with
  | Syntax.SPi (_loc, _q, _x, _dom, cod) -> peel_syntax_codomain cod
  | Syntax.SVar _ | Syntax.SType _ | Syntax.SLam _ | Syntax.SApp _ | Syntax.SLet _
  | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _
  | Syntax.SAuto _ | Syntax.SInst _ ->
      t

(** Application spine over unelaborated [Syntax.t], head plus args
    oldest first; mirrors [Totality.spine]'s shape one level up. *)
let rec syntax_spine (t : Syntax.t) (args : Syntax.t list) : Syntax.t * Syntax.t list =
  match t with
  | Syntax.SApp (_loc, f, a) -> syntax_spine f (a :: args)
  | Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SLet _
  | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _
  | Syntax.SAuto _ | Syntax.SInst _ ->
      (t, args)

(** M4 Stage D (D3): [(C, K)] from an instance's UNELABORATED type's
    codomain spine "C (K ..)" or "C K";  [None] when the codomain is not
    of that shape (an identifier applied to exactly one identifier-headed
    spine).  Exposed for [Bootstrap.item_name] too, which needs the same
    walk to name an [IInstance] item without elaborating it. *)
let instance_key (ty : Syntax.t) : (string * string) option =
  match syntax_spine (peel_syntax_codomain ty) [] with
  | Syntax.SVar (_, c_name), [ karg ] -> (
      match syntax_spine karg [] with
      | Syntax.SVar (_, k_name), _kargs -> Some (c_name, k_name)
      | ( Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SApp _ | Syntax.SLet _
        | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _
        | Syntax.SAuto _ | Syntax.SInst _ ),
        _ ->
          None)
  | ( ( Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SApp _
      | Syntax.SLet _ | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _
      | Syntax.SLetStar _ | Syntax.SAuto _ | Syntax.SInst _ ),
      (_ : Syntax.t list) ) ->
      None

(** M4 fixes round 1 (ctxcat id 3): the tail every def-shaped item
    shares, once.  [Check.define]/[Check.define_instance] has already
    produced [globals];  fetch the entry back (its def carries the
    checker's quantity stamps, which structural erasure relies on),
    record the runtime thunk in RUN mode only, and format the summary
    line.  [IDef] and [IInstance] differ solely in the name they register
    under, so they now differ solely in what they pass here, and a future
    change to the erase/guard/exec branching has ONE site. *)
let install_def ~(loc : Loc.t) ~(exec : bool) ~(name : string) ~(ty_t : Term.t) (st : state)
    (globals : Global.t) : (state, Serror.t) result =
  let* dentry =
    kernel loc
      (Global.find_def name globals |> Option.to_result ~none:(Error.Unbound_global name))
  in
  let* eglobals =
    if not exec then Ok st.eglobals
    else
      let* def_e = kernel loc (Erase.closed dentry.Global.def) in
      Ok
        (Interp.define st.eglobals ~name
           ~guard:(compute_guard ~name dentry.Global.def dentry.Global.rec_arg def_e)
           def_e)
  in
  let line = Printf.sprintf "def %s : %s" name (Pp.term [] ty_t) in
  Ok { globals; eglobals; lines = line :: st.lines }

(** M5 Stage C (pin 8): [budget] is the driver's check cutoff, threaded
    into every [Check.*] entry point an item reaches.  An OPTIONAL
    argument, not a [policy] field: [policy] is a record of
    installation booleans built as a literal at three sites, so a new
    field breaks all three, while the [Budget.unlimited] default breaks
    none.  The prelude guarantee survives too:
    [Bootstrap.fold_prelude_items] passes no [~budget], so the prelude
    fold runs unlimited by construction. *)
let rec item ?(budget : Budget.t = Budget.unlimited) ~(exec : bool) ~(policy : policy)
    (st : state) (it : Syntax.item) : (state, Serror.t) result =
  match it with
  | Syntax.IDef { loc; name; reducible; kind; ty; def } ->
      let rec_, partial = defkind_bools kind in
      let* ty_t = Elab.term st.globals [] ty in
      (* a rec body mentions its own name: elaborate it against a
         provisional self-entry (the kernel re-adds its own opaque one
         inside [Check.define], which also rejects duplicates against
         the ORIGINAL globals) *)
      let elab_globals =
        if rec_ then
          Global.add name
            (Global.Def
               {
                 Global.ty = ty_t;
                 def = Term.Global name;
                 reducible = false;
                 rec_arg = None;
                 partial = false;
               })
            st.globals
        else st.globals
      in
      let* def_t = Elab.term elab_globals [] def in
      let* globals =
        kernel loc
          (Check.define ~rec_ ~partial ~budget ~rule:policy.wf_rule st.globals ~name
             ~reducible ~ty:ty_t ~def:def_t)
      in
      (* M3 fixes, A1 (O1 + C14, 2026-09-01): in CHECK mode
         [Interp.define] is never called for USER DEFS, so no def body
         (a Div/IO HEAD, or a Div value nested under a pure head like
         [Option (Div Nat)]) can execute host computation under
         `tot check`. Data-ctor seeding is MODE-INDEPENDENT (round 3,
         O5): the [IData] arm below calls [Interp.add_erased]/
         [add_ctor] in both modes, which is harmless -- those entries
         are inert canonical-value scaffolding, they execute no user
         code. Elaboration and kernel checking above only ever
         consult kernel globals ([Eval]'s NbE), never [Interp] values,
         so nothing downstream needs the def entries; check-mode
         [eval] items print types only (below) and [main_epilogue]
         returns early on [exec = false]. Bootstrap folds the prelude
         with
         [exec = true], so the prelude path is unchanged. In RUN mode
         (M3 fixes round 2, R2, superseding the Stage B head-keyed
         rule) EVERY user def is recorded as a lazy memoized thunk:
         elaboration, checking, erasure and closedness above stay
         EAGER (a malformed def is still caught right here), the body
         runs on first force by an eval item or by [main], and the A2
         memo keeps single-execution. Dead code (a def [main] never
         mentions) therefore never runs, so it can neither abort nor
         hang a guard; the flip side, recorded in SPEC.md, is that a
         LIVE def's definition-time abort surfaces only at force
         time. *)
      install_def ~loc ~exec ~name ~ty_t st globals
  | Syntax.IData { loc; name; params; indices; level; ctors } ->
      (* params telescope, left to right: each type is elaborated in the
         scope of the names before it; the parser forced quantity 0 *)
      let* pscope, rev_params =
        List.fold_left
          (fun acc (x, ty) ->
            let* scope, rev_tele = acc in
            let* ty_t = Elab.term st.globals scope ty in
            Ok (x :: scope, (Quantity.Zero, x, ty_t) :: rev_tele))
          (Ok ([], []))
          params
      in
      (* M4 Stage A: the index telescope, scoped under params PLUS
         earlier index binders (an index type may depend on an earlier
         index, exactly like the params telescope); ctor types below stay
         scoped under [pscope] alone, never under the indices, since no
         constructor telescope ever binds the family's own index name. *)
      let* _iscope, rev_indices =
        List.fold_left
          (fun acc (q, x, ty) ->
            let* scope, rev_tele = acc in
            let* ty_t = Elab.term st.globals scope ty in
            Ok (x :: scope, (q, x, ty_t) :: rev_tele))
          (Ok (pscope, []))
          indices
      in
      let* level_l =
        Level.of_int level |> Option.to_result ~none:(Serror.Bad_level { loc; level })
      in
      (* declare first so the ctor types can mention the inductive *)
      let* provisional =
        kernel loc
          (Check.declare_ind ~budget st.globals ~name ~params:(List.rev rev_params)
             ~indices:(List.rev rev_indices) ~level:level_l)
      in
      let* rev_ctors =
        List.fold_left
          (fun acc (cname, cty) ->
            let* rev = acc in
            let* cty_t = Elab.term provisional pscope cty in
            Ok ((cname, cty_t) :: rev))
          (Ok []) ctors
      in
      let* globals =
        kernel loc (Check.define_ind ~budget provisional ~name ~ctors:(List.rev rev_ctors))
      in
      (* runtime seeds: the type constructor is inert, data constructors
         accumulate their kept arguments up to their runtime (Many-only)
         arity, the canonical-value test a rec global's guard uses when
         its principal argument lands on one of these ctors *)
      let* eglobals =
        List.fold_left
          (fun acc (cname, _cty) ->
            let* eg = acc in
            let* centry =
              kernel loc
                (Global.find_ctor cname globals
                |> Option.to_result ~none:(Error.Unbound_global cname))
            in
            let arity =
              List.length
                (List.filter
                   (fun (q, _x, _ty) -> Quantity.equal q Quantity.Many)
                   centry.Global.args)
            in
            Ok (Interp.add_ctor eg ~name:cname ~arity))
          (Ok (Interp.add_erased st.eglobals ~name))
          ctors
      in
      (* print the CLOSED kernel types fetched back from the new entries *)
      let* ind =
        kernel loc
          (Global.find_ind name globals
          |> Option.to_result ~none:(Error.Unbound_global name))
      in
      let data_line = Printf.sprintf "data %s : %s" name (Pp.term [] ind.Global.ind_ty) in
      let* rev_ctor_lines =
        List.fold_left
          (fun acc (cname, _cty) ->
            let* rev = acc in
            let* centry =
              kernel loc
                (Global.find_ctor cname globals
                |> Option.to_result ~none:(Error.Unbound_global cname))
            in
            Ok
              (Printf.sprintf "ctor %s : %s" cname (Pp.term [] centry.Global.ctor_ty)
              :: rev))
          (Ok []) ctors
      in
      Ok { globals; eglobals; lines = rev_ctor_lines @ data_line :: st.lines }
  | Syntax.IClass { loc; name; param = a, aty; methods } ->
      (* D3: a class is a convention, not a kernel notion.  Expand into an
         [IData] dictionary (one constructor, "mk" ^ name, uniformly)
         plus one projection [IDef] per method, and fold each through
         [item] itself.  The class parameter's type must literally be
         "Type L": that is the whole grammar ("class NAME (0 A :
         Type L) := .."), so anything else is a parse-shaped error here
         rather than a kernel one. *)
      let* level =
        match aty with
        | Syntax.SType (_, l) -> Ok l
        | Syntax.SVar _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SApp _ | Syntax.SLet _
        | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _
        | Syntax.SAuto _ | Syntax.SInst _ ->
            Error (Serror.Parse { loc; msg = "class parameter must have type 'Type L'" })
      in
      let mk_ctor = "mk" ^ name in
      let binder_names = List.mapi (fun j (_m, _t) -> "x" ^ string_of_int (j + 1)) methods in
      let ctor_ty =
        List.fold_right
          (fun (_mname, mty) acc -> Syntax.SPi (loc, Quantity.Many, "_", mty, acc))
          methods
          (Syntax.SApp (loc, Syntax.SVar (loc, name), Syntax.SVar (loc, a)))
      in
      let data_item =
        Syntax.IData
          { loc; name; params = [ (a, aty) ]; indices = []; level; ctors = [ (mk_ctor, ctor_ty) ] }
      in
      let def_items =
        List.mapi
          (fun i (mname, mty) ->
            let xi = "x" ^ string_of_int (i + 1) in
            Syntax.IDef
              {
                loc;
                name = mname;
                reducible = false;
                kind = Syntax.DNonRec;
                ty =
                  Syntax.SPi
                    ( loc,
                      Quantity.Zero,
                      a,
                      aty,
                      Syntax.SPi
                        ( loc,
                          Quantity.Many,
                          "d",
                          Syntax.SApp (loc, Syntax.SVar (loc, name), Syntax.SVar (loc, a)),
                          mty ) );
                def =
                  Syntax.SLam
                    ( loc,
                      a,
                      Syntax.SLam
                        ( loc,
                          "d",
                          Syntax.SMatch
                            ( loc,
                              Syntax.SVar (loc, "d"),
                              None,
                              [ (mk_ctor, binder_names, Syntax.SVar (loc, xi)) ] ) ) );
              })
          methods
      in
      List.fold_left
        (fun acc sub_item ->
          let* st' = acc in
          item ~budget ~exec ~policy st' sub_item)
        (item ~budget ~exec ~policy st data_item)
        def_items
  | Syntax.IInstance { loc; ty; def } ->
      (* D3: register under the mangled "inst$C$K" name read off [ty]'s
         own codomain spine.  The instance body is an ORDINARY term, then
         an ordinary [Def] entry (reducible, D2), exactly like a plain
         [IDef]'s own eglobals bookkeeping below. *)
      let* c_name, k_name =
        instance_key ty
        |> Option.to_result
             ~none:(Serror.Parse { loc; msg = "instance type must end in CLASS (KEY ..)" })
      in
      let mangled = "inst$" ^ c_name ^ "$" ^ k_name in
      let* ty_t = Elab.term st.globals [] ty in
      let* def_t = Elab.term st.globals [] def in
      let* globals =
        kernel loc
          (Check.define_instance ~budget st.globals ~name:mangled ~ty:ty_t ~def:def_t)
      in
      install_def ~loc ~exec ~name:mangled ~ty_t st globals
  | Syntax.IAxiom { loc; name; ty } ->
      let* ty_t = Elab.term st.globals [] ty in
      (* M4 Stage B: [policy.no_axioms] applies to the USER file only;
         [Bootstrap.fold_prelude_items] always folds the prelude with
         [default_policy], so this guard never sees the prelude's own
         monad-law axioms. *)
      (match () with
      | () when policy.no_axioms -> Error (Serror.Axioms_disabled { loc; name })
      | () ->
          let* globals = kernel loc (Check.define_axiom ~budget st.globals ~name ~ty:ty_t) in
          (* an axiom has NO runtime entry at all: [Interp.define] is
             never called. If one ever reached [Interp.exec], the
             existing [Unbound_global] backstop fires (test B9). *)
          let line = Printf.sprintf "axiom %s : %s" name (Pp.term [] ty_t) in
          Ok { st with globals; lines = line :: st.lines })
  | Syntax.ICheck (loc, s) ->
      let* tm = Elab.term st.globals [] s in
      let* tm', ty_v =
        kernel loc (Check.infer st.globals (Check.root_ctx budget) Quantity.Zero tm)
      in
      let line =
        Printf.sprintf "%s : %s" (Pp.term [] tm') (Check.pp_value st.globals 0 ty_v)
      in
      Ok { st with lines = line :: st.lines }
  | Syntax.IEval (loc, s) ->
      let* tm = Elab.term st.globals [] s in
      let* tm', ty_v =
        kernel loc (Check.infer st.globals (Check.root_ctx budget) Quantity.Many tm)
      in
      let* e = kernel loc (Erase.closed tm') in
      if exec then
        let* v = kernel loc (Interp.exec st.eglobals [] e) in
        let* e' = kernel loc (Interp.quote st.eglobals 0 v) in
        Ok { st with lines = Pp.eterm [] e' :: st.lines }
      else
        Ok { st with lines = ("eval : " ^ Check.pp_value st.globals 0 ty_v) :: st.lines }

(** [main]'s EVALUATED type converts (by [Eval.conv], not just a head
    test) to [IO io_arg] -- e.g. [io_arg = "Verdict"] or ["Unit"].
    Guarded first by [IO]/[io_arg] actually resolving in [globals], so
    an unrelated "main" in a non-bootstrapped environment never trips
    an [Unbound_global] on "IO". Takes the type VALUE, not the term:
    [main_epilogue] evaluates [main]'s stored type exactly ONCE and
    reuses it for both target comparisons (M3 fixes, C11, 2026-09-01;
    M3 Stage D, D4: [IO Verdict] is tried FIRST, then [IO Unit], the
    plan's own priority order). *)
let converts_to (globals : Global.t) (main_ty_v : Value.t) ~(io_arg : string) :
    (bool, Serror.t) result =
  let has_target = Option.is_some (Global.find "IO" globals) && Option.is_some (Global.find io_arg globals) in
  if not has_target then Ok false
  else
    let* target_v =
      kernel Loc.start
        (Eval.eval globals [] (Term.App (Quantity.Many, Term.Global "IO", Term.Global io_arg)))
    in
    kernel Loc.start (Eval.conv globals 0 main_ty_v target_v)

(** Force [main] (through [Interp.exec] on the [EGlobal] lookup, which
    forces a [GDeferred] body exactly once here) and run its action
    tree to completion, EXACTLY once. Shared by the [IO Verdict] and
    [IO Unit] epilogue paths below (M3 Stage D; M3 Stage B for the
    [IO Unit] shape alone). *)
let run_main ~(strict_json : bool) (final : state) : (Effect.outcome, Serror.t) result =
  let* main_v = kernel Loc.start (Interp.exec final.eglobals [] (Eterm.EGlobal "main")) in
  let* action = kernel Loc.start (Effect.require_action main_v) in
  kernel Loc.start (Effect.run_io ~strict_json final.eglobals action)

(** M3 Stage D, D4: the [IO Verdict] epilogue path, tried FIRST. An
    [Exited n] outcome (an explicit [exitWith] fired before ever
    reaching a [Verdict] value) SHORT CIRCUITS: it wins over rendering
    a verdict, exactly the plan's own rule, and [Effect.render_verdict]
    is never even called. A [Done v] outcome renders [v] (a checked
    [allow]/[ask _]/[deny _] value) into the driver's envelope line (or
    nothing, for [allow]) and its OS exit code. The replacement LINE
    LIST here REPLACES the whole script's ordinary per-item echo
    (`script` below never appends to it): the hook-protocol contract is
    that stdout carries EXACTLY the rendered decision, nothing else,
    not "def main : (IO Verdict)" or any earlier item's echo. *)
let run_verdict_main ~(strict_json : bool) (final : state) : (string list * int, Serror.t) result =
  let* outcome = run_main ~strict_json final in
  match outcome with
  | Effect.Exited n -> Ok ([], n)
  (* M5 Stage A (pin 20): a strict-json refusal on a verdict script IS
     a verdict, the deny envelope with the fixed reason and the
     literal deny code 2, OUTSIDE the --serror-exit mapping, exactly
     like the driver contract for an unusable target. *)
  | Effect.Rejected reason -> Ok ([ Effect.deny_envelope reason ], 2)
  | Effect.Done v ->
      let* line_opt, code = kernel Loc.start (Effect.render_verdict v) in
      Ok (line_opt |> Option.fold ~none:[] ~some:(fun l -> [ l ]), code)

(** M3 Stage B: the [IO Unit] epilogue path, tried SECOND (only once
    [main] does not convert to [IO Verdict]). Unlike the [IO Verdict]
    path, this one does NOT replace the script's ordinary per-item
    echo lines: `run` mode has always printed one "def ..." line per
    top-level item, [main] included, and this stage does not change
    that for a plain [IO Unit] script. [Exited n] becomes exit code
    [Some n]; completing without an explicit [exitWith] stays [None]
    ([bin/tot.ml] defaults that to 0). *)
let run_unit_main ~(strict_json : bool) (final : state) : (int option, Serror.t) result =
  let* outcome = run_main ~strict_json final in
  match outcome with
  | Effect.Exited n -> Ok (Some n)
  (* M5 Stage A (pin 20): an [IO Unit] script has no verdict channel,
     so a strict-json refusal takes the DRIVER contract instead: one
     stderr line, exit 1, outside the --serror-exit mapping
     ([Serror.driver_exit]); the same posture --require-main takes. *)
  | Effect.Rejected _reason -> Error Serror.Json_strict_reject
  | Effect.Done _ -> Ok None

(** [main]'s epilogue. Looks up a global literally named "main"; every
    M2 script defines no such name, so [None] here (via [Option.fold]'s
    [~none]) is the OVERWHELMINGLY common, and totally unaffected,
    path.

    M3 fixes, C1' (O4, 2026-09-01): [main] is a RESERVED driver name
    in BOTH modes. When the user file defines it, its stored type is
    evaluated exactly ONCE (C11) and must convert to [IO Verdict] or
    [IO Unit]; anything else is [Serror.Main_bad_type], in check mode
    too, so `tot check` flags the guard `tot run` would have silently
    no-op'd (the O4 permit-all). Type evaluation here is kernel NbE
    only, never [Interp]: check mode still executes no user def body
    and never calls [run_io]. A MISSPELLED main stays silent by
    design this milestone (SPEC section 6 residual).

    In RUN mode (M3 Stage D, D4): [IO Verdict] is tried FIRST
    ([run_verdict_main], REPLACING the printed lines); only if that
    does not match is [IO Unit] tried ([run_unit_main], M3 Stage B,
    leaving the printed lines alone). Returns
    [(replacement_lines option, exit_code option)]: [Some lines]
    REPLACES [script]'s own accumulated output; [None] leaves it
    unchanged. In CHECK mode a well-typed [main] stays [None, None]:
    nothing runs.

    M4 fixes round 3 (ctxcat r3 id 3): [policy.require_main] fires
    UNIFORMLY, in check mode and in run mode alike, and that is the
    intended scope, not an oversight of the [exec] flag. The flag's own
    doc comment (see [policy]) frames it by its motivating consumer, an
    installation's shebang wrapper, which reads as execution-only; the
    RULE it implements is "this file must define a driver main", a
    statement about the file's CONTENT, and a content verdict must not
    depend on which verb asked for it. A hook that pre-flights a guard
    script with `tot check --require-main` would otherwise accept a
    mainless script that `tot run --require-main` then rejects. Pinned
    in both modes by PASS-M4D-REQUIRE-MAIN. *)
let main_epilogue (final : state) ~(exec : bool) ~(policy : policy) :
    (string list option * int option, Serror.t) result =
  Global.find_def "main" final.globals
  |> Option.fold
       ~none:
         (match () with
         | () when policy.require_main -> Error Serror.Missing_main
         | () -> Ok (None, None))
       ~some:(fun dentry ->
         let* main_ty_v = kernel Loc.start (Eval.eval final.globals [] dentry.Global.ty) in
         let* is_verdict = converts_to final.globals main_ty_v ~io_arg:"Verdict" in
         let* is_unit =
           if is_verdict then Ok false else converts_to final.globals main_ty_v ~io_arg:"Unit"
         in
         match () with
         | () when (not is_verdict) && not is_unit ->
             (* M4 fixes round 5 (opus R5-5): this is the one DRIVER
                error whose payload is a printed type, and it lands on
                the same one-line stderr channel the kernel diagnostics
                do, so it takes the same [Check.pp_goal] clamp.  Below
                [Check.goal_print_cap] the rendering is identical, so
                every message the suites pin is untouched. *)
             Error (Serror.Main_bad_type { ty = Check.pp_goal final.globals 0 main_ty_v })
         | () when not exec -> Ok (None, None)
         | () when is_verdict ->
             let* lines, code = run_verdict_main ~strict_json:policy.strict_json final in
             Ok (Some lines, Some code)
         | () ->
             let* code = run_unit_main ~strict_json:policy.strict_json final in
             Ok (None, code))

(** [st] seeds the starting environment (M3 Stage A); default [initial]
    keeps every existing caller and every existing test unchanged. M3
    Stage B: [script] additionally returns the process exit code
    [main]'s epilogue computed, [None] when there is no [IO Unit] (or,
    M3 Stage D, [IO Verdict]) [main], or it never called [exitWith]
    (verdict 3.7). M3 Stage D, D4: when the epilogue returns
    [Some replacement_lines] (the [IO Verdict] driver path took over
    rendering), that list REPLACES the ordinary accumulated output
    instead of appending to it. *)
let script ?(st : state = initial) ?(policy : policy = default_policy)
    ?(budget : Budget.t = Budget.unlimited) ~(exec : bool) (src : string) :
    (string list * int option, Serror.t) result =
  let* tokens = Lexer.lex src in
  let* items = Parser.parse tokens in
  let* final =
    List.fold_left
      (fun acc it ->
        let* st = acc in
        item ~budget ~exec ~policy st it)
      (Ok st) items
  in
  let* replacement_lines, exit_code = main_epilogue final ~exec ~policy in
  let base_lines = List.rev final.lines in
  let out_lines = replacement_lines |> Option.fold ~none:base_lines ~some:Fun.id in
  Ok (out_lines, exit_code)
