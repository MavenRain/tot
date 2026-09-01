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
  | Term.Global _ | Term.Match _ ->
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
  | Syntax.IDef { loc; name; reducible; rec_; ty; def } ->
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
               })
            st.globals
        else st.globals
      in
      let* def_t = Elab.term elab_globals [] def in
      let* globals =
        kernel loc (Check.define ~rec_ st.globals ~name ~reducible ~ty:ty_t ~def:def_t)
      in
      (* fetch the entry back: its def carries the checker's quantity
         stamps, which structural erasure relies on *)
      let* dentry =
        kernel loc
          (Global.find_def name globals
          |> Option.to_result ~none:(Error.Unbound_global name))
      in
      let* def_e = kernel loc (Erase.closed dentry.Global.def) in
      let* eglobals =
        kernel loc
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

let script ~(exec : bool) (src : string) : (string list, Serror.t) result =
  let* tokens = Lexer.lex src in
  let* items = Parser.parse tokens in
  let* final =
    List.fold_left
      (fun acc it ->
        let* st = acc in
        item ~exec st it)
      (Ok initial) items
  in
  Ok (List.rev final.lines)
