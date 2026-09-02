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

let kernel (loc : Loc.t) (r : ('a, Error.t) result) : ('a, Serror.t) result =
  Result.map_error (fun err -> Serror.Kernel { loc; err }) r

(** Quantities of a stamped def body's leading [Term.Lam] telescope,
    outermost first. Same walk shape as [Totality.peel], but keeping the
    quantities instead of the peeled body: [Totality.guard]'s [rec_arg]
    indexes into exactly this list. *)
let rec lam_quantities (t : Term.t) : Quantity.t list =
  match t with
  | Term.Lam (q, _x, b) -> q :: lam_quantities b
  | Term.Var _ | Term.Univ _
  | Term.Pi (_, _, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Match _ | Term.Lit _ ->
      []

(** Remap a kernel [rec_arg] (an index into the UNERASED formal telescope,
    outermost first, per [Totality.peel]/[Totality.guard]) to an index
    into the runtime's ERASED application spine that [Interp.apply]'s
    guard actually walks ([Erase.term] drops every [Quantity.Zero] [Lam]
    binder and [Quantity.Zero] [App] argument, so the two spines diverge
    whenever an erased formal precedes the principal one). [Some k'] where
    [k'] counts the [Quantity.Many] formals strictly before position [k].

    If formal [k] is itself [Quantity.Zero] (erased), remap to [None]:
    eager unfolding, the def is treated as non-recursive at runtime (M2
    fixes, round 4 review; see dev/M2-FIXES-LOG.md "## Round 4" for the
    full correction). This is SOUND, not merely permissive: a quantity-0
    formal can only be eliminated (matched on) while checking at
    [Quantity.Zero] mode, the same attenuation [Check.infer]'s [Var] arm
    enforces (using a 0-bound variable at mode [Many] is [Erased_use]),
    so every branch of a match on it, and every recursive call reachable
    through those branches, is itself checked at mode [Zero].
    [Erase.term]'s [App (Quantity.Zero, f, _a) -> term ctx f] arm drops
    such a subterm WHOLESALE at its use site without walking it, so the
    ERASED body of a rec def guarded on an erased formal contains NO
    occurrence of the def's own global name: eager unfolding cannot loop
    and computes the definitionally correct value. Mechanically confirmed
    for the [ghost] fixture (test/fixtures/s0-erased-guard.tot) by a
    kernel-level [Eterm.t] walk: test/main.ml's "T0: rec def guarded on
    an erased formal has no self-reference after erasure". (An earlier
    revision of this arm froze here instead, on a divergence claim that
    had no actual witness; reverted, see the log.)

    Total: an out-of-range [k] (should not arise, [Totality.guard] only
    returns in-range positions) also falls back to [None] (no guard at
    all, i.e. today's plain-def behavior), since [List.nth_opt qs k]
    itself misses first. *)
let remap_rec_arg (def : Term.t) (rec_arg : int option) : int option =
  let qs = lam_quantities def in
  Option.bind rec_arg (fun k ->
      Option.bind (List.nth_opt qs k) (fun q ->
          match q with
          | Quantity.Zero -> None
          | Quantity.Many ->
              Some
                (List.length
                   (List.filteri
                      (fun ix q' -> ix < k && Quantity.equal q' Quantity.Many)
                      qs))))

let item ~(exec : bool) (st : state) (it : Syntax.item) : (state, Serror.t) result =
  match it with
  | Syntax.IDef { loc; name; reducible; rec_; partial; ty; def } ->
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
          (Check.define ~rec_ ~partial st.globals ~name ~reducible ~ty:ty_t ~def:def_t)
      in
      (* fetch the entry back: its def carries the checker's quantity
         stamps, which structural erasure relies on *)
      let* dentry =
        kernel loc
          (Global.find_def name globals
          |> Option.to_result ~none:(Error.Unbound_global name))
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
      let* eglobals =
        if not exec then Ok st.eglobals
        else
          let* def_e = kernel loc (Erase.closed dentry.Global.def) in
          Ok
            (Interp.define st.eglobals ~name
               ~rec_arg:(remap_rec_arg dentry.Global.def dentry.Global.rec_arg)
               def_e)
      in
      let line = Printf.sprintf "def %s : %s" name (Pp.term [] ty_t) in
      Ok { globals; eglobals; lines = line :: st.lines }
  | Syntax.IData { loc; name; params; level; ctors } ->
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
      let* level_l =
        Level.of_int level |> Option.to_result ~none:(Serror.Bad_level { loc; level })
      in
      (* declare first so the ctor types can mention the inductive *)
      let* provisional =
        kernel loc
          (Check.declare_ind st.globals ~name ~params:(List.rev rev_params)
             ~level:level_l)
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
        kernel loc (Check.define_ind provisional ~name ~ctors:(List.rev rev_ctors))
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
  | Syntax.ICheck (loc, s) ->
      let* tm = Elab.term st.globals [] s in
      let* tm', ty_v =
        kernel loc (Check.infer st.globals Check.empty_ctx Quantity.Zero tm)
      in
      let line =
        Printf.sprintf "%s : %s" (Pp.term [] tm') (Check.pp_value st.globals 0 ty_v)
      in
      Ok { st with lines = line :: st.lines }
  | Syntax.IEval (loc, s) ->
      let* tm = Elab.term st.globals [] s in
      let* tm', ty_v =
        kernel loc (Check.infer st.globals Check.empty_ctx Quantity.Many tm)
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
let run_main (final : state) : (Effect.outcome, Serror.t) result =
  let* main_v = kernel Loc.start (Interp.exec final.eglobals [] (Eterm.EGlobal "main")) in
  let* action = kernel Loc.start (Effect.require_action main_v) in
  kernel Loc.start (Effect.run_io final.eglobals action)

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
let run_verdict_main (final : state) : (string list * int, Serror.t) result =
  let* outcome = run_main final in
  match outcome with
  | Effect.Exited n -> Ok ([], n)
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
let run_unit_main (final : state) : (int option, Serror.t) result =
  let* outcome = run_main final in
  match outcome with
  | Effect.Exited n -> Ok (Some n)
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
    nothing runs. *)
let main_epilogue (final : state) ~(exec : bool) :
    (string list option * int option, Serror.t) result =
  Global.find_def "main" final.globals
  |> Option.fold ~none:(Ok (None, None)) ~some:(fun dentry ->
         let* main_ty_v = kernel Loc.start (Eval.eval final.globals [] dentry.Global.ty) in
         let* is_verdict = converts_to final.globals main_ty_v ~io_arg:"Verdict" in
         let* is_unit =
           if is_verdict then Ok false else converts_to final.globals main_ty_v ~io_arg:"Unit"
         in
         match () with
         | () when (not is_verdict) && not is_unit ->
             Error (Serror.Main_bad_type { ty = Check.pp_value final.globals 0 main_ty_v })
         | () when not exec -> Ok (None, None)
         | () when is_verdict ->
             let* lines, code = run_verdict_main final in
             Ok (Some lines, Some code)
         | () ->
             let* code = run_unit_main final in
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
let script ?(st : state = initial) ~(exec : bool) (src : string) :
    (string list * int option, Serror.t) result =
  let* tokens = Lexer.lex src in
  let* items = Parser.parse tokens in
  let* final =
    List.fold_left
      (fun acc it ->
        let* st = acc in
        item ~exec st it)
      (Ok st) items
  in
  let* replacement_lines, exit_code = main_epilogue final ~exec in
  let base_lines = List.rev final.lines in
  let out_lines = replacement_lines |> Option.fold ~none:base_lines ~some:Fun.id in
  Ok (out_lines, exit_code)
