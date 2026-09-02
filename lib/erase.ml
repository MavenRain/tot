(** Structural erasure. Runs ONLY on checker OUTPUT terms, whose [Lam]
    and [App] quantity stamps are authoritative: quantity-0 binders
    vanish (indices under them shift down) and quantity-0 arguments are
    dropped. No types, globals, or evaluation are consulted. *)

let ( let* ) = Result.bind

(** Newest binder first; the bool means: this binder survives erasure. *)
type ctx = (string * bool) list

(** How many kept binders sit strictly closer to the use site than [ix]. *)
let kept_index (ix : int) (ctx : ctx) : int =
  List.length (List.filteri (fun i (_x, kept) -> i < ix && kept) ctx)

let rec term (ctx : ctx) (tm : Term.t) : (Eterm.t, Error.t) result =
  match tm with
  | Term.Var ix ->
      let* x, kept =
        List.nth_opt ctx ix |> Option.to_result ~none:(Error.Unbound_var ix)
      in
      if kept then Ok (Eterm.EVar (kept_index ix ctx))
      else
        (* unreachable on checked terms: Check's Var rule rejects a mode-w
           use of a 0-binder (mode Many, q Zero -> Erased_use). Kept as a
           total backstop. *)
        Error (Error.Erased_use x)
  | Term.Univ _ -> Ok Eterm.EErased
  | Term.Pi (_q, _x, _dom, _cod) -> Ok Eterm.EErased
  | Term.Lam (Quantity.Zero, x, body) -> term ((x, false) :: ctx) body
  | Term.Lam (Quantity.Many, x, body) ->
      let* body_e = term ((x, true) :: ctx) body in
      Ok (Eterm.ELam (x, body_e))
  | Term.App (Quantity.Zero, f, _a) -> term ctx f
  | Term.App (Quantity.Many, f, a) ->
      let* f_e = term ctx f in
      let* a_e = term ctx a in
      Ok (Eterm.EApp (f_e, a_e))
  | Term.Let (x, _ty, def, body) ->
      let* def_e = term ctx def in
      let* body_e = term ((x, true) :: ctx) body in
      Ok (Eterm.ELet (x, def_e, body_e))
  | Term.Ann (tm', _ty) -> term ctx tm'
  | Term.Global name -> Ok (Eterm.EGlobal name)
  | Term.Lit l -> Ok (Eterm.ELit l)
  | Term.Auto ->
      (* M4 Stage A: unreachable on checker output; [Auto] never survives
         [Check]. Total backstop. *)
      Error (Error.Cannot_infer "auto")
  | Term.Match { scrut = _; scrut_q = Quantity.Zero; motive = _; branches } ->
      (* M4 Stage A, subsingleton elimination: the family carries no
         runtime bits (user decision 1), so the scrutinee is dropped
         entirely. Dropping it is sound because the language is total:
         the scrutinee is a pure, terminating computation whose value the
         branch cannot inspect. The checker stamps [scrut_q = Zero] only
         for a zero-constructor family or for one all-erased
         non-self-recursive constructor, so the one-branch arm below
         binds only dropped binders and the two-or-more arm is genuinely
         unreachable; both stay as total backstops. *)
      (match branches with
      | [] -> Ok Eterm.EErased
      | [ (_c, binders, body) ] ->
          let ctx' = List.fold_left (fun cacc (_q, x) -> (x, false) :: cacc) ctx binders in
          term ctx' body
      | _ :: _ :: _ -> Error (Error.Erased_use "match"))
  | Term.Match { scrut; scrut_q = Quantity.Many; motive = _; branches } ->
      (* the motive is a type: it never reaches runtime. Branch binders
         keep only the Many-stamped positions. *)
      let* scrut_e = term ctx scrut in
      let* branches_e =
        List.fold_left
          (fun acc (c, binders, body) ->
            let* done_ = acc in
            let ctx' =
              List.fold_left
                (fun cacc (q, x) -> (x, Quantity.equal q Quantity.Many) :: cacc)
                ctx binders
            in
            let kept =
              List.filter_map
                (fun (q, x) -> if Quantity.equal q Quantity.Many then Some x else None)
                binders
            in
            let* body_e = term ctx' body in
            Ok ((c, kept, body_e) :: done_))
          (Ok []) branches
        |> Result.map List.rev
      in
      Ok (Eterm.EMatch (scrut_e, branches_e))

let closed (def : Term.t) : (Eterm.t, Error.t) result = term [] def
