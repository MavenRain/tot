(** Display-only printer. Free variables print as [#n]. *)

let rec term (names : string list) (tm : Term.t) : string =
  match tm with
  | Term.Var ix -> List.nth_opt names ix |> Option.value ~default:(Printf.sprintf "#%d" ix)
  | Term.Univ l -> "Type " ^ Level.to_string l
  | Term.Pi (q, x, dom, cod) ->
      Printf.sprintf "(%s %s : %s) -> %s" (Quantity.to_string q) x (term names dom)
        (term (x :: names) cod)
  | Term.Lam (x, body) -> Printf.sprintf "fun %s => %s" x (term (x :: names) body)
  | Term.App (f, a) -> Printf.sprintf "(%s %s)" (term names f) (term names a)
  | Term.Let (x, ty, def, body) ->
      Printf.sprintf "let %s : %s = %s in %s" x (term names ty) (term names def)
        (term (x :: names) body)
  | Term.Ann (tm', ty) -> Printf.sprintf "(%s : %s)" (term names tm') (term names ty)
  | Term.Global n -> n
