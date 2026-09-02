(** Display-only printer. Free variables print as [#n]. *)

(** Render a string literal's SOURCE form: double-quoted, with
    backslash, double-quote, newline and tab escaped (M3 Stage A).
    Reused by Stage C's JSON serializer and Stage D's verdict renderer,
    both reachable from [surface/] through this module. *)
let escape_string (s : string) : string =
  let buf = Buffer.create (String.length s + 2) in
  Buffer.add_char buf '"';
  String.iter
    (fun c ->
      match c with
      | '\\' -> Buffer.add_string buf "\\\\"
      | '"' -> Buffer.add_string buf "\\\""
      | '\n' -> Buffer.add_string buf "\\n"
      | '\t' -> Buffer.add_string buf "\\t"
      | _ -> Buffer.add_char buf c)
    s;
  Buffer.add_char buf '"';
  Buffer.contents buf

let literal (l : Literal.t) : string =
  match l with
  | Literal.LString s -> escape_string s
  | Literal.LInt n -> string_of_int n

let rec term (names : string list) (tm : Term.t) : string =
  match tm with
  | Term.Var ix -> List.nth_opt names ix |> Option.value ~default:(Printf.sprintf "#%d" ix)
  | Term.Univ l -> "Type " ^ Level.to_string l
  | Term.Pi (q, x, dom, cod) ->
      Printf.sprintf "(%s %s : %s) -> %s" (Quantity.to_string q) x (term names dom)
        (term (x :: names) cod)
  | Term.Lam (_q, x, body) -> Printf.sprintf "fun %s => %s" x (term (x :: names) body)
  | Term.App (_q, f, a) -> Printf.sprintf "(%s %s)" (term names f) (term names a)
  | Term.Let (x, ty, def, body) ->
      Printf.sprintf "let %s : %s = %s in %s" x (term names ty) (term names def)
        (term (x :: names) body)
  | Term.Ann (tm', ty) -> Printf.sprintf "(%s : %s)" (term names tm') (term names ty)
  | Term.Global n -> n
  | Term.Lit l -> literal l
  | Term.Match { scrut; motive; branches } ->
      let motive_s =
        motive
        |> Option.fold ~none:"" ~some:(fun (x, mot) ->
               Printf.sprintf " as %s return %s" x (term (x :: names) mot))
      in
      let branch_s (c, binders, body) =
        let bnames = List.map (fun (_q, x) -> x) binders in
        let names' = List.fold_left (fun acc x -> x :: acc) names bnames in
        Printf.sprintf " | %s => %s" (String.concat " " (c :: bnames)) (term names' body)
      in
      Printf.sprintf "match %s%s with%s end" (term names scrut) motive_s
        (String.concat "" (List.map branch_s branches))

let rec eterm (names : string list) (e : Eterm.t) : string =
  match e with
  | Eterm.EVar ix ->
      List.nth_opt names ix |> Option.value ~default:(Printf.sprintf "#%d" ix)
  | Eterm.ELam (x, body) -> Printf.sprintf "fun %s => %s" x (eterm (x :: names) body)
  | Eterm.EApp (f, a) -> Printf.sprintf "(%s %s)" (eterm names f) (eterm names a)
  | Eterm.ELet (x, def, body) ->
      Printf.sprintf "let %s := %s in %s" x (eterm names def) (eterm (x :: names) body)
  | Eterm.EGlobal n -> n
  | Eterm.EErased -> "<erased>"
  | Eterm.ELit l -> literal l
  | Eterm.EMatch (scrut, branches) ->
      let branch_s (c, binders, body) =
        let names' = List.fold_left (fun acc x -> x :: acc) names binders in
        Printf.sprintf " | %s => %s" (String.concat " " (c :: binders)) (eterm names' body)
      in
      Printf.sprintf "match %s with%s end" (eterm names scrut)
        (String.concat "" (List.map branch_s branches))
