(** Elaboration: pure scope resolution plus sugar. ALL typechecking stays
    in the kernel; this pass only turns names into de Bruijn indices,
    levels into [Level.t], and rejects unknown names. Locals shadow
    globals. *)

open Tot_kernel

let ( let* ) = Result.bind

let rec index_of (name : string) (scope : string list) : int option =
  match scope with
  | [] -> None
  | x :: rest ->
      if String.equal x name then Some 0
      else index_of name rest |> Option.map (fun ix -> ix + 1)

(** Lazy fallback for Option: [Option.fold ~none] is eager, this is not. *)
let or_else (fallback : unit -> 'a option) (o : 'a option) : 'a option =
  if Option.is_some o then o else fallback ()

let rec term (globals : Global.t) (scope : string list) (s : Syntax.t) :
    (Term.t, Serror.t) result =
  match s with
  | Syntax.SVar (loc, x) ->
      index_of x scope
      |> Option.map (fun ix -> Term.Var ix)
      |> or_else (fun () ->
             Global.find x globals |> Option.map (fun _entry -> Term.Global x))
      |> Option.to_result ~none:(Serror.Unknown_name { loc; name = x })
  | Syntax.SType (loc, n) ->
      Level.of_int n
      |> Option.map (fun l -> Term.Univ l)
      |> Option.to_result ~none:(Serror.Bad_level { loc; level = n })
  | Syntax.SPi (_loc, q, x, dom, cod) ->
      let* dom_t = term globals scope dom in
      let* cod_t = term globals (x :: scope) cod in
      Ok (Term.Pi (q, x, dom_t, cod_t))
  | Syntax.SLam (_loc, x, body) ->
      let* body_t = term globals (x :: scope) body in
      Ok (Term.Lam (x, body_t))
  | Syntax.SApp (_loc, f, a) ->
      let* f_t = term globals scope f in
      let* a_t = term globals scope a in
      Ok (Term.App (f_t, a_t))
  | Syntax.SLet (_loc, x, ty, def, body) ->
      let* ty_t = term globals scope ty in
      let* def_t = term globals scope def in
      let* body_t = term globals (x :: scope) body in
      Ok (Term.Let (x, ty_t, def_t, body_t))
  | Syntax.SAnn (_loc, tm, ty) ->
      let* tm_t = term globals scope tm in
      let* ty_t = term globals scope ty in
      Ok (Term.Ann (tm_t, ty_t))
