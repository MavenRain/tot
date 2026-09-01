(** Evaluation, readback, and conversion. NbE with closures; syntax uses
    indices, values use levels. Everything returns [Result]: a scope bug
    surfaces as an error value, never as an exception. *)

let ( let* ) = Result.bind

let rec eval (globals : Global.t) (env : Value.t list) (tm : Term.t) :
    (Value.t, Error.t) result =
  match tm with
  | Term.Var ix -> List.nth_opt env ix |> Option.to_result ~none:(Error.Unbound_var ix)
  | Term.Univ l -> Ok (Value.VUniv l)
  | Term.Pi (q, x, dom, cod) ->
      let* dom_v = eval globals env dom in
      Ok (Value.VPi (q, x, dom_v, { Value.env; body = cod }))
  | Term.Lam (x, body) -> Ok (Value.VLam (x, { Value.env; body }))
  | Term.App (f, a) ->
      let* f_v = eval globals env f in
      let* a_v = eval globals env a in
      apply globals f_v a_v
  | Term.Let (_x, _ty, def, body) ->
      let* def_v = eval globals env def in
      eval globals (def_v :: env) body
  | Term.Ann (tm', _ty) -> eval globals env tm'
  | Term.Global name ->
      let* entry =
        Global.find name globals |> Option.to_result ~none:(Error.Unbound_global name)
      in
      if entry.Global.reducible then eval globals [] entry.Global.def
      else Ok (Value.VNeutral (Value.HGlobal name, []))

and apply (globals : Global.t) (f : Value.t) (a : Value.t) : (Value.t, Error.t) result =
  match f with
  | Value.VLam (_x, clo) -> app_closure globals clo a
  | Value.VNeutral (h, spine) -> Ok (Value.VNeutral (h, a :: spine))
  | Value.VPi (_, _, _, _) -> Error (Error.Not_a_function "<pi value>")
  | Value.VUniv l -> Error (Error.Not_a_function ("Type " ^ Level.to_string l))

and app_closure (globals : Global.t) (clo : Value.closure) (arg : Value.t) :
    (Value.t, Error.t) result =
  eval globals (arg :: clo.Value.env) clo.Value.body

and quote (globals : Global.t) (size : int) (v : Value.t) : (Term.t, Error.t) result =
  match v with
  | Value.VUniv l -> Ok (Term.Univ l)
  | Value.VPi (q, x, dom, clo) ->
      let* dom_t = quote globals size dom in
      let* cod_v = app_closure globals clo (Value.var size) in
      let* cod_t = quote globals (size + 1) cod_v in
      Ok (Term.Pi (q, x, dom_t, cod_t))
  | Value.VLam (x, clo) ->
      let* body_v = app_closure globals clo (Value.var size) in
      let* body_t = quote globals (size + 1) body_v in
      Ok (Term.Lam (x, body_t))
  | Value.VNeutral (h, spine) ->
      let* head_t =
        match h with
        | Value.HVar lvl ->
            let ix = size - lvl - 1 in
            if ix >= 0 then Ok (Term.Var ix) else Error (Error.Bad_level lvl)
        | Value.HGlobal n -> Ok (Term.Global n)
      in
      List.fold_left
        (fun acc arg ->
          let* f = acc in
          let* arg_t = quote globals size arg in
          Ok (Term.App (f, arg_t)))
        (Ok head_t) (List.rev spine)

and conv (globals : Global.t) (size : int) (a : Value.t) (b : Value.t) :
    (bool, Error.t) result =
  match (a, b) with
  | Value.VUniv l1, Value.VUniv l2 -> Ok (Level.equal l1 l2)
  | Value.VPi (q1, _x1, dom1, clo1), Value.VPi (q2, _x2, dom2, clo2) ->
      let* dom_eq = conv globals size dom1 dom2 in
      (match () with
      | () when not (Quantity.equal q1 q2) -> Ok false
      | () when not dom_eq -> Ok false
      | () ->
          let fresh = Value.var size in
          let* cod1 = app_closure globals clo1 fresh in
          let* cod2 = app_closure globals clo2 fresh in
          conv globals (size + 1) cod1 cod2)
  | Value.VLam (_x1, clo1), Value.VLam (_x2, clo2) ->
      let fresh = Value.var size in
      let* b1 = app_closure globals clo1 fresh in
      let* b2 = app_closure globals clo2 fresh in
      conv globals (size + 1) b1 b2
  | Value.VLam (_x, clo), Value.VNeutral (h, spine) ->
      let fresh = Value.var size in
      let* b1 = app_closure globals clo fresh in
      conv globals (size + 1) b1 (Value.VNeutral (h, fresh :: spine))
  | Value.VNeutral (h, spine), Value.VLam (_x, clo) ->
      let fresh = Value.var size in
      let* b2 = app_closure globals clo fresh in
      conv globals (size + 1) (Value.VNeutral (h, fresh :: spine)) b2
  | Value.VNeutral (h1, s1), Value.VNeutral (h2, s2) ->
      if conv_head h1 h2 then conv_spine globals size s1 s2 else Ok false
  | Value.VUniv _, (Value.VPi (_, _, _, _) | Value.VLam (_, _) | Value.VNeutral (_, _)) ->
      Ok false
  | (Value.VPi (_, _, _, _) | Value.VLam (_, _) | Value.VNeutral (_, _)), Value.VUniv _ ->
      Ok false
  | Value.VPi (_, _, _, _), (Value.VLam (_, _) | Value.VNeutral (_, _)) -> Ok false
  | (Value.VLam (_, _) | Value.VNeutral (_, _)), Value.VPi (_, _, _, _) -> Ok false

and conv_head (h1 : Value.head) (h2 : Value.head) : bool =
  match (h1, h2) with
  | Value.HVar l1, Value.HVar l2 -> Int.equal l1 l2
  | Value.HGlobal n1, Value.HGlobal n2 -> String.equal n1 n2
  | Value.HVar _, Value.HGlobal _ -> false
  | Value.HGlobal _, Value.HVar _ -> false

and conv_spine (globals : Global.t) (size : int) (s1 : Value.t list) (s2 : Value.t list)
    : (bool, Error.t) result =
  match (s1, s2) with
  | [], [] -> Ok true
  | v1 :: r1, v2 :: r2 ->
      let* head_eq = conv globals size v1 v2 in
      if head_eq then conv_spine globals size r1 r2 else Ok false
  | [], _v :: _ -> Ok false
  | _v :: _, [] -> Ok false
