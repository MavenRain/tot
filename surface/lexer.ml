(** Lexer. The source is exploded to a char list once; everything after
    that is pure recursion over that list. Numeric-literal overflow is
    unguarded (documented SPEC debt). *)

let is_digit (c : char) : bool = c >= '0' && c <= '9'

let is_ident_start (c : char) : bool =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || Char.equal c '_'

let is_ident_char (c : char) : bool = is_ident_start c || is_digit c || Char.equal c '\''

let keywords : (string * Token.kind) list =
  [
    ("Type", Token.KType);
    ("fun", Token.KFun);
    ("let", Token.KLet);
    ("in", Token.KIn);
    ("def", Token.KDef);
    ("reducible", Token.KReducible);
    ("eval", Token.KEval);
    ("check", Token.KCheck);
  ]

let ident_kind (s : string) : Token.kind =
  List.assoc_opt s keywords |> Option.value ~default:(Token.Ident s)

(** Take the longest prefix satisfying [p]; return it with the location
    just past it and the remaining chars. *)
let rec span (p : char -> bool) (loc : Loc.t) (cs : char list) :
    char list * Loc.t * char list =
  match cs with
  | c :: rest when p c ->
      let taken, loc', rest' = span p (Loc.next_col loc) rest in
      (c :: taken, loc', rest')
  | ([] | _ :: _) as rest -> ([], loc, rest)

let nat_of_digits (digits : char list) : int =
  List.fold_left (fun acc c -> (acc * 10) + (Char.code c - Char.code '0')) 0 digits

let rec go (loc : Loc.t) (cs : char list) (acc : Token.t list) :
    (Token.t list, Serror.t) result =
  match cs with
  | [] -> Ok (List.rev ({ Token.kind = Token.Eof; loc } :: acc))
  | ' ' :: rest | '\t' :: rest | '\r' :: rest -> go (Loc.next_col loc) rest acc
  | '\n' :: rest -> go (Loc.next_line loc) rest acc
  | '-' :: '-' :: rest -> skip_comment (Loc.next_col (Loc.next_col loc)) rest acc
  | '-' :: '>' :: rest ->
      go (Loc.next_col (Loc.next_col loc)) rest ({ Token.kind = Token.Arrow; loc } :: acc)
  | '=' :: '>' :: rest ->
      go (Loc.next_col (Loc.next_col loc)) rest ({ Token.kind = Token.DArrow; loc } :: acc)
  | ':' :: '=' :: rest ->
      go
        (Loc.next_col (Loc.next_col loc))
        rest
        ({ Token.kind = Token.ColonEq; loc } :: acc)
  | ':' :: rest -> go (Loc.next_col loc) rest ({ Token.kind = Token.Colon; loc } :: acc)
  | '(' :: rest -> go (Loc.next_col loc) rest ({ Token.kind = Token.LParen; loc } :: acc)
  | ')' :: rest -> go (Loc.next_col loc) rest ({ Token.kind = Token.RParen; loc } :: acc)
  | c :: rest when is_digit c ->
      let taken, loc', rest' = span is_digit (Loc.next_col loc) rest in
      let digits = c :: taken in
      (* 18 digits always fit in a 63-bit int; a longer run would wrap *)
      if List.length digits > 18 then
        Error (Serror.Lex { loc; msg = "numeric literal too long" })
      else go loc' rest' ({ Token.kind = Token.Nat (nat_of_digits digits); loc } :: acc)
  | c :: rest when is_ident_start c ->
      let taken, loc', rest' = span is_ident_char (Loc.next_col loc) rest in
      let s = List.to_seq (c :: taken) |> String.of_seq in
      go loc' rest' ({ Token.kind = ident_kind s; loc } :: acc)
  | c :: _rest ->
      (* a lone '-' (neither "--" nor "->") lands here too *)
      Error (Serror.Lex { loc; msg = Printf.sprintf "unexpected character %C" c })

(** Run to end of line, advancing the column over the comment chars so
    the Eof location stays honest. *)
and skip_comment (loc : Loc.t) (cs : char list) (acc : Token.t list) :
    (Token.t list, Serror.t) result =
  match cs with
  | [] -> go loc [] acc
  | '\n' :: rest -> go (Loc.next_line loc) rest acc
  | _other :: rest -> skip_comment (Loc.next_col loc) rest acc

let lex (src : string) : (Token.t list, Serror.t) result =
  go Loc.start (String.to_seq src |> List.of_seq) []
