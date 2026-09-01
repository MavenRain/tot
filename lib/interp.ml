(** Call-by-value interpreter over erased terms. At runtime EVERY global
    unfolds: reducibility is a conversion-time notion only, so the opaque
    flag never reaches this module. Global values are cached closed at
    definition time by [define]. [VNeut] exists only for readback: [quote]
    applies closures to fresh neutral variables to reach under binders. *)

let ( let* ) = Result.bind

type v =
  | VClos of string * v list * Eterm.t
  | VNeut of int * v list  (** readback only: level + spine, newest first *)
  | VErased

type globals = v Global.StringMap.t

let empty_globals : globals = Global.StringMap.empty

let rec exec (eglobals : globals) (env : v list) (e : Eterm.t) : (v, Error.t) result =
  match e with
  | Eterm.EVar ix -> List.nth_opt env ix |> Option.to_result ~none:(Error.Unbound_var ix)
  | Eterm.ELam (x, body) -> Ok (VClos (x, env, body))
  | Eterm.EApp (f, a) ->
      let* f_v = exec eglobals env f in
      let* a_v = exec eglobals env a in
      apply eglobals f_v a_v
  | Eterm.ELet (_x, def, body) ->
      let* def_v = exec eglobals env def in
      exec eglobals (def_v :: env) body
  | Eterm.EGlobal name ->
      Global.StringMap.find_opt name eglobals
      |> Option.to_result ~none:(Error.Unbound_global name)
  | Eterm.EErased -> Ok VErased

and apply (eglobals : globals) (f : v) (a : v) : (v, Error.t) result =
  match f with
  | VClos (_x, env, body) -> exec eglobals (a :: env) body
  | VNeut (lvl, spine) -> Ok (VNeut (lvl, a :: spine))
  | VErased -> Error (Error.Not_a_function "<erased>")

let define (eglobals : globals) ~(name : string) (def : Eterm.t) :
    (globals, Error.t) result =
  let* v = exec eglobals [] def in
  Ok (Global.StringMap.add name v eglobals)

let rec quote (eglobals : globals) (size : int) (v : v) : (Eterm.t, Error.t) result =
  match v with
  | VClos (x, _env, _body) as clo ->
      let* body_v = apply eglobals clo (VNeut (size, [])) in
      let* body_e = quote eglobals (size + 1) body_v in
      Ok (Eterm.ELam (x, body_e))
  | VNeut (lvl, spine) ->
      let ix = size - lvl - 1 in
      if ix < 0 then Error (Error.Bad_level lvl)
      else
        List.fold_right
          (fun arg acc ->
            let* f = acc in
            let* arg_e = quote eglobals size arg in
            Ok (Eterm.EApp (f, arg_e)))
          spine (Ok (Eterm.EVar ix))
  | VErased -> Ok Eterm.EErased
