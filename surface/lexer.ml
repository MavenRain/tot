(** Lexer. The source is exploded to a char list once; everything after
    that is pure recursion over that list. Numeric-literal overflow is
    unguarded (documented SPEC debt). *)

let ( let* ) = Result.bind

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
    ("data", Token.KData);
    ("match", Token.KMatch);
    ("with", Token.KWith);
    ("as", Token.KAs);
    ("return", Token.KReturn);
    ("rec", Token.KRec);
    ("end", Token.KEnd);
    ("partial", Token.KPartial);  (** M3 Stage C *)
    ("axiom", Token.KAxiom);  (** M4 Stage B *)
    ("class", Token.KClass);  (** M4 Stage D *)
    ("instance", Token.KInstance);  (** M4 Stage D *)
    ("auto", Token.KAuto);  (** M4 Stage D *)
    ("inst", Token.KInst);  (** M4 Stage D *)
    ("_", Token.Underscore);  (** M6 Stage C, ruling R2 *)
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

(** Scan a double-quoted string literal's body, immediately after the
    opening quote. Honors backslash-backslash, backslash-quote,
    backslash-n, backslash-t, and backslash-r escapes (M3 fixes round
    4: [\r] added so a guard can name the carriage-return IFS
    separator; mirrors [json_string_body]); accumulates decoded
    characters newest-first. An unterminated literal, an unknown escape, or a RAW
    newline before the closing quote (write [\n] instead; M3 fixes
    round 2, ctxcat id 14: silently absorbing the newline made a
    missing close quote swallow the rest of the file instead of
    failing fast at its own line) is a [Serror.Lex] (M3 Stage A). *)
let rec scan_string (loc : Loc.t) (cs : char list) (acc : char list) :
    (string * Loc.t * char list, Serror.t) result =
  match cs with
  | [] -> Error (Serror.Lex { loc; msg = "unterminated string literal" })
  | '"' :: rest ->
      let s = List.rev acc |> List.to_seq |> String.of_seq in
      Ok (s, Loc.next_col loc, rest)
  | '\\' :: 'n' :: rest -> scan_string (Loc.next_col (Loc.next_col loc)) rest ('\n' :: acc)
  | '\\' :: 't' :: rest -> scan_string (Loc.next_col (Loc.next_col loc)) rest ('\t' :: acc)
  | '\\' :: 'r' :: rest -> scan_string (Loc.next_col (Loc.next_col loc)) rest ('\r' :: acc)
  | '\\' :: '\\' :: rest -> scan_string (Loc.next_col (Loc.next_col loc)) rest ('\\' :: acc)
  | '\\' :: '"' :: rest -> scan_string (Loc.next_col (Loc.next_col loc)) rest ('"' :: acc)
  | [ '\\' ] -> Error (Serror.Lex { loc; msg = "unterminated escape at end of input" })
  | '\\' :: c :: _rest ->
      Error (Serror.Lex { loc; msg = Printf.sprintf "unknown escape \\%c" c })
  | '\n' :: _rest ->
      Error (Serror.Lex { loc; msg = "newline in string literal (use \\n)" })
  | c :: rest -> scan_string (Loc.next_col loc) rest (c :: acc)

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
  | '{' :: rest -> go (Loc.next_col loc) rest ({ Token.kind = Token.LBrace; loc } :: acc)
  | '}' :: rest -> go (Loc.next_col loc) rest ({ Token.kind = Token.RBrace; loc } :: acc)
  | ';' :: rest -> go (Loc.next_col loc) rest ({ Token.kind = Token.Semi; loc } :: acc)
  | '|' :: rest -> go (Loc.next_col loc) rest ({ Token.kind = Token.Pipe; loc } :: acc)
  | '"' :: rest ->
      let* s, loc', rest' = scan_string (Loc.next_col loc) rest [] in
      go loc' rest' ({ Token.kind = Token.Str s; loc } :: acc)
  | c :: rest when is_digit c ->
      let taken, loc', rest' = span is_digit (Loc.next_col loc) rest in
      let digits = c :: taken in
      (* 18 digits always fit in a 63-bit int; a longer run would wrap *)
      if List.length digits > 18 then
        Error (Serror.Lex { loc; msg = "numeric literal too long" })
      else go loc' rest' ({ Token.kind = Token.Nat (nat_of_digits digits); loc } :: acc)
  (* M3 Stage C: "let*!" and "let*" are matched as LITERAL prefixes,
     longest first, BEFORE the identifier scanner below: '*' is not an
     identifier character, so the keyword table above cannot carry
     these (the ordinary "let" scan would stop at "let" and then hit
     "unexpected character '*'"). The bare "let" keyword is unaffected:
     neither pattern matches unless the very next character after "let"
     is '*'. *)
  | 'l' :: 'e' :: 't' :: '*' :: '!' :: rest ->
      go (Loc.advance loc 5) rest ({ Token.kind = Token.KLetStarDiv; loc } :: acc)
  | 'l' :: 'e' :: 't' :: '*' :: rest ->
      go (Loc.advance loc 4) rest ({ Token.kind = Token.KLetStar; loc } :: acc)
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

(** M3 Stage D, D3: strip ONE leading shebang line ("#!" at column 0,
    line 1) before tokenizing, so a hook script can start with
    "#!/usr/bin/env -S tot run". "--" stays the only comment marker for
    everything else; this handles ONLY the very first line, and ONLY
    when it starts with the literal two characters "#!" -- a "#!"
    appearing anywhere else (mid-file, or after a leading space) is
    left alone and falls through to the ordinary lexer, where a bare
    '#' is "unexpected character" (there is no line comment marker
    other than "--"). Line numbers in every later token/error stay
    accurate: the rest of the source is lexed starting from
    [Loc.next_line Loc.start] (line 2), not line 1, since physically it
    IS line 2 onward in the original file. A shebang line with no
    trailing newline at all (the whole source is just the shebang)
    strips to an empty remaining program, handled downstream the
    ordinary way (no tokens but [Eof]). Both slices below carry their
    own length precondition ON THE SAME LINE, so neither [String.sub]
    call can raise. *)
let strip_shebang (src : string) : string * Loc.t =
  let is_shebang =
    String.length src >= 2 && String.equal (String.sub src 0 2 (* @total-accessor *)) "#!"
  in
  if not is_shebang then (src, Loc.start)
  else
    String.index_opt src '\n'
    |> Option.fold
         ~none:("", Loc.next_line Loc.start)
         ~some:(fun i ->
           let rest_len = String.length src - i - 1 in
           (String.sub src (i + 1) rest_len (* @total-accessor *), Loc.next_line Loc.start))

let lex (src : string) : (Token.t list, Serror.t) result =
  let src', loc0 = strip_shebang src in
  go loc0 (String.to_seq src' |> List.of_seq) []
