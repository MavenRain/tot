(** Bidirectional typechecking with 0/omega quantity modes. [define] is
    the one public way to extend the global environment. *)

let ( let* ) = Result.bind

type ctx = {
  env : Value.t list;
  locals : (string * Quantity.t * Value.t) list;
  size : int;
}

let empty_ctx : ctx = { env = []; locals = []; size = 0 }

let bind (x : string) (q : Quantity.t) (ty : Value.t) (ctx : ctx) : ctx =
  { env = Value.var ctx.size :: ctx.env; locals = (x, q, ty) :: ctx.locals; size = ctx.size + 1 }

let bind_def (x : string) (ty : Value.t) (v : Value.t) (ctx : ctx) : ctx =
  { env = v :: ctx.env; locals = (x, Quantity.Many, ty) :: ctx.locals; size = ctx.size + 1 }

let pp_value (globals : Global.t) (size : int) (v : Value.t) : string =
  Eval.quote globals size v
  |> Result.fold ~ok:(Pp.term []) ~error:(fun _e -> "<unprintable>")

let rec infer (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (tm : Term.t) :
    (Value.t, Error.t) result =
  match tm with
  | Term.Var ix ->
      let* x, q, ty =
        List.nth_opt ctx.locals ix |> Option.to_result ~none:(Error.Unbound_var ix)
      in
      (match () with
      | () when Quantity.equal mode Quantity.Zero -> Ok ty
      | () when Quantity.equal q Quantity.Many -> Ok ty
      | () -> Error (Error.Erased_use x))
  | Term.Univ l -> Ok (Value.VUniv (Level.succ l))
  | Term.Pi (q, x, dom, cod) ->
      let* dom_l = infer_univ globals ctx dom in
      let* dom_v = Eval.eval globals ctx.env dom in
      let* cod_l = infer_univ globals (bind x q dom_v ctx) cod in
      Ok (Value.VUniv (Level.max dom_l cod_l))
  | Term.Lam (x, _body) -> Error (Error.Cannot_infer x)
  | Term.App (f, a) ->
      let* f_ty = infer globals ctx mode f in
      (match f_ty with
      | Value.VPi (q, _x, dom, clo) ->
          let* () = check globals ctx (Quantity.mul mode q) a dom in
          let* a_v = Eval.eval globals ctx.env a in
          Eval.app_closure globals clo a_v
      | Value.VUniv _ | Value.VLam (_, _) | Value.VNeutral (_, _) ->
          Error (Error.Not_a_function (pp_value globals ctx.size f_ty)))
  | Term.Let (x, ty, def, body) ->
      let* _ty_l = infer_univ globals ctx ty in
      let* ty_v = Eval.eval globals ctx.env ty in
      let* () = check globals ctx mode def ty_v in
      let* def_v = Eval.eval globals ctx.env def in
      infer globals (bind_def x ty_v def_v ctx) mode body
  | Term.Ann (tm', ty) ->
      let* _ty_l = infer_univ globals ctx ty in
      let* ty_v = Eval.eval globals ctx.env ty in
      let* () = check globals ctx mode tm' ty_v in
      Ok ty_v
  | Term.Global name ->
      let* entry =
        Global.find name globals |> Option.to_result ~none:(Error.Unbound_global name)
      in
      Eval.eval globals [] entry.Global.ty

and infer_univ (globals : Global.t) (ctx : ctx) (tm : Term.t) : (Level.t, Error.t) result
    =
  let* ty = infer globals ctx Quantity.Zero tm in
  match ty with
  | Value.VUniv l -> Ok l
  | Value.VPi (_, _, _, _) | Value.VLam (_, _) | Value.VNeutral (_, _) ->
      Error (Error.Not_a_universe (pp_value globals ctx.size ty))

and check (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (tm : Term.t)
    (expected : Value.t) : (unit, Error.t) result =
  match (tm, expected) with
  | Term.Lam (x, body), Value.VPi (q, _y, dom, clo) ->
      let* cod = Eval.app_closure globals clo (Value.var ctx.size) in
      check globals (bind x q dom ctx) mode body cod
  | Term.Lam (_x, _body), (Value.VUniv _ | Value.VLam (_, _) | Value.VNeutral (_, _)) ->
      Error
        (Error.Mismatch
           { expected = pp_value globals ctx.size expected; actual = "a function" })
  | Term.Let (x, ty, def, body), expected_v ->
      let* _ty_l = infer_univ globals ctx ty in
      let* ty_v = Eval.eval globals ctx.env ty in
      let* () = check globals ctx mode def ty_v in
      let* def_v = Eval.eval globals ctx.env def in
      check globals (bind_def x ty_v def_v ctx) mode body expected_v
  | ( (Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _) | Term.App (_, _) | Term.Ann (_, _)
      | Term.Global _),
      expected_v ) ->
      let* actual = infer globals ctx mode tm in
      let* ok = Eval.conv globals ctx.size actual expected_v in
      if ok then Ok ()
      else
        Error
          (Error.Mismatch
             {
               expected = pp_value globals ctx.size expected_v;
               actual = pp_value globals ctx.size actual;
             })

let define (globals : Global.t) ~(name : string) ~(reducible : bool) ~(ty : Term.t)
    ~(def : Term.t) : (Global.t, Error.t) result =
  match Option.to_list (Global.find name globals) with
  | _entry :: _ -> Error (Error.Duplicate_global name)
  | [] ->
      let* _ty_l = infer_univ globals empty_ctx ty in
      let* ty_v = Eval.eval globals [] ty in
      let* () = check globals empty_ctx Quantity.Many def ty_v in
      Ok (Global.add name { Global.ty; def; reducible } globals)
