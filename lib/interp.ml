(** Call-by-value interpreter over erased terms. At runtime EVERY global
    unfolds: reducibility is a conversion-time notion only, so the opaque
    flag never reaches this module. Global values are cached closed at
    definition time by [define]; rec defs erase to lambdas (the totality
    guard forces every recursive call under the principal binder), so that
    closed eval cannot recurse. [VNeut] exists only for readback: [quote]
    applies closures to fresh neutral variables to reach under binders,
    and a match stuck on such a variable freezes its branches as an
    [FEMatch] frame. *)

let ( let* ) = Result.bind

type v =
  | VClos of string * v list * Eterm.t
  | VCon of string * v list  (** data ctor applied; KEPT args only, in order *)
  | VNeut of int * eframe list  (** readback only: level + frames, newest first *)
  | VErased

and eframe =
  | FEApp of v
  | FEMatch of (string * string list * Eterm.t) list * v list
      (** frozen branches + the env their bodies close over *)

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
  | Eterm.EMatch (scrut, branches) ->
      let* scrut_v = exec eglobals env scrut in
      run_match eglobals env scrut_v branches

and run_match (eglobals : globals) (env : v list) (scrut_v : v)
    (branches : (string * string list * Eterm.t) list) : (v, Error.t) result =
  match scrut_v with
  | VCon (c, args) ->
      (* a miss is unreachable on checked programs; total backstop *)
      let* _c, binders, body =
        List.find_opt (fun (b, _bs, _body) -> String.equal b c) branches
        |> Option.to_result ~none:(Error.Branch_mismatch { expected = c; found = "<none>" })
      in
      if Int.equal (List.length binders) (List.length args) then
        exec eglobals (List.rev_append args env) body
      else
        Error (Error.Branch_mismatch { expected = c; found = c ^ " (wrong runtime arity)" })
  | VNeut (lvl, frames) -> Ok (VNeut (lvl, FEMatch (branches, env) :: frames))
  | VClos (_, _, _) | VErased ->
      Error (Error.Not_inductive "<runtime match on a non-constructor>")

and apply (eglobals : globals) (f : v) (a : v) : (v, Error.t) result =
  match f with
  | VClos (_x, env, body) -> exec eglobals (a :: env) body
  | VCon (c, args) -> Ok (VCon (c, args @ [ a ]))
  | VNeut (lvl, frames) -> Ok (VNeut (lvl, FEApp a :: frames))
  | VErased -> Error (Error.Not_a_function "<erased>")

let define (eglobals : globals) ~(name : string) (def : Eterm.t) :
    (globals, Error.t) result =
  let* v = exec eglobals [] def in
  Ok (Global.StringMap.add name v eglobals)

(** Seed a data constructor: it accumulates its runtime arguments. *)
let add_ctor (eglobals : globals) ~(name : string) : globals =
  Global.StringMap.add name (VCon (name, [])) eglobals

(** Seed a type constructor: types are inert at runtime. *)
let add_erased (eglobals : globals) ~(name : string) : globals =
  Global.StringMap.add name VErased eglobals

let rec quote (eglobals : globals) (size : int) (v : v) : (Eterm.t, Error.t) result =
  match v with
  | VClos (x, _env, _body) as clo ->
      let* body_v = apply eglobals clo (VNeut (size, [])) in
      let* body_e = quote eglobals (size + 1) body_v in
      Ok (Eterm.ELam (x, body_e))
  | VCon (c, args) ->
      List.fold_left
        (fun acc arg ->
          let* f = acc in
          let* arg_e = quote eglobals size arg in
          Ok (Eterm.EApp (f, arg_e)))
        (Ok (Eterm.EGlobal c)) args
  | VNeut (lvl, frames) ->
      let ix = size - lvl - 1 in
      if ix < 0 then Error (Error.Bad_level lvl)
      else
        List.fold_left
          (fun acc fr ->
            let* f = acc in
            match fr with
            | FEApp arg ->
                let* arg_e = quote eglobals size arg in
                Ok (Eterm.EApp (f, arg_e))
            | FEMatch (branches, menv) ->
                let* branches_e =
                  List.fold_left
                    (fun bacc (c, binders, body) ->
                      let* done_ = bacc in
                      let arity = List.length binders in
                      let fresh_env =
                        List.init arity (fun i -> VNeut (size + arity - 1 - i, []))
                      in
                      let* body_v = exec eglobals (fresh_env @ menv) body in
                      let* body_e = quote eglobals (size + arity) body_v in
                      Ok ((c, binders, body_e) :: done_))
                    (Ok []) branches
                  |> Result.map List.rev
                in
                Ok (Eterm.EMatch (f, branches_e)))
          (Ok (Eterm.EVar ix))
          (List.rev frames)
  | VErased -> Ok Eterm.EErased
