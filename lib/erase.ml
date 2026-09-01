(** Type-directed erasure. Runs ONLY on kernel-checked terms: quantity-0
    lambda binders vanish (indices under them shift down) and quantity-0
    application arguments are dropped. The pass mirrors [Check]'s
    bidirectional shape but performs no conversion checks; types are
    consulted only for Pi quantities. *)

let ( let* ) = Result.bind

type ctx = {
  env : Value.t list;
  locals : (string * bool * Value.t) list;
      (** the bool means: this binder survives erasure *)
  size : int;  (** counts every binder, erased ones included: it tracks
                   [Value.var] levels, not erased indices *)
}

let empty_ctx : ctx = { env = []; locals = []; size = 0 }

let bind (x : string) ~(kept : bool) (ty : Value.t) (v : Value.t) (ctx : ctx) : ctx =
  { env = v :: ctx.env; locals = (x, kept, ty) :: ctx.locals; size = ctx.size + 1 }

(** How many kept binders sit strictly closer to the use site than [ix]. *)
let erased_index (ix : int) (ctx : ctx) : int =
  List.length (List.filteri (fun i (_x, kept, _ty) -> i < ix && kept) ctx.locals)

let to_check_ctx (ctx : ctx) : Check.ctx =
  {
    Check.env = ctx.env;
    locals =
      List.map
        (fun (x, kept, ty) ->
          (x, (if kept then Quantity.Many else Quantity.Zero), ty))
        ctx.locals;
    size = ctx.size;
  }

let rec infer (globals : Global.t) (ctx : ctx) (tm : Term.t) :
    (Eterm.t * Value.t, Error.t) result =
  match tm with
  | Term.Var ix ->
      let* x, kept, ty =
        List.nth_opt ctx.locals ix |> Option.to_result ~none:(Error.Unbound_var ix)
      in
      if kept then Ok (Eterm.EVar (erased_index ix ctx), ty)
      else
        (* unreachable on checked terms: Check's Var rule rejects a mode-w
           use of a 0-binder (mode Many, q Zero -> Erased_use), and erasure
           never visits erased positions. Kept as a total backstop. *)
        Error (Error.Erased_use x)
  | Term.Univ l -> Ok (Eterm.EErased, Value.VUniv (Level.succ l))
  | Term.Pi (_q, _x, _dom, _cod) ->
      let* ty = Check.infer globals (to_check_ctx ctx) Quantity.Zero tm in
      Ok (Eterm.EErased, ty)
  | Term.Lam (x, _body) ->
      (* cannot occur post-check: a bare lambda never reaches infer *)
      Error (Error.Cannot_infer x)
  | Term.App (f, a) ->
      let* f_e, f_ty = infer globals ctx f in
      (match f_ty with
      | Value.VPi (q, _x, dom, clo) ->
          let* a_v = Eval.eval globals ctx.env a in
          let* cod = Eval.app_closure globals clo a_v in
          (match q with
          | Quantity.Zero -> Ok (f_e, cod)
          | Quantity.Many ->
              let* a_e = check globals ctx a dom in
              Ok (Eterm.EApp (f_e, a_e), cod))
      | Value.VUniv _ | Value.VLam (_, _) | Value.VNeutral (_, _) ->
          Error (Error.Not_a_function (Check.pp_value globals ctx.size f_ty)))
  | Term.Let (x, ty, def, body) ->
      let* ty_v = Eval.eval globals ctx.env ty in
      let* def_e = check globals ctx def ty_v in
      let* def_v = Eval.eval globals ctx.env def in
      let* body_e, body_ty = infer globals (bind x ~kept:true ty_v def_v ctx) body in
      Ok (Eterm.ELet (x, def_e, body_e), body_ty)
  | Term.Ann (tm', ty) ->
      let* ty_v = Eval.eval globals ctx.env ty in
      let* e = check globals ctx tm' ty_v in
      Ok (e, ty_v)
  | Term.Global name ->
      let* entry =
        Global.find name globals |> Option.to_result ~none:(Error.Unbound_global name)
      in
      let* ty_v = Eval.eval globals [] entry.Global.ty in
      Ok (Eterm.EGlobal name, ty_v)

and check (globals : Global.t) (ctx : ctx) (tm : Term.t) (expected : Value.t) :
    (Eterm.t, Error.t) result =
  match (tm, expected) with
  | Term.Lam (x, body), Value.VPi (q, _y, dom, clo) ->
      let fresh = Value.var ctx.size in
      let* cod = Eval.app_closure globals clo fresh in
      let kept = Quantity.equal q Quantity.Many in
      let* body_e = check globals (bind x ~kept dom fresh ctx) body cod in
      if kept then Ok (Eterm.ELam (x, body_e)) else Ok body_e
  | Term.Lam (_x, _body), (Value.VUniv _ | Value.VLam (_, _) | Value.VNeutral (_, _)) ->
      Error
        (Error.Mismatch
           { expected = Check.pp_value globals ctx.size expected; actual = "a function" })
  | Term.Let (x, ty, def, body), expected_v ->
      let* ty_v = Eval.eval globals ctx.env ty in
      let* def_e = check globals ctx def ty_v in
      let* def_v = Eval.eval globals ctx.env def in
      let* body_e = check globals (bind x ~kept:true ty_v def_v ctx) body expected_v in
      Ok (Eterm.ELet (x, def_e, body_e))
  | ( (Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _) | Term.App (_, _) | Term.Ann (_, _)
      | Term.Global _),
      _expected_v ) ->
      (* no conversion here: the kernel already accepted the term *)
      let* e, _ty = infer globals ctx tm in
      Ok e

let closed (globals : Global.t) ~(ty : Value.t) ~(def : Term.t) :
    (Eterm.t, Error.t) result =
  check globals empty_ctx def ty
