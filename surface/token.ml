(** Lexical tokens. Every token carries the location of its first
    character; [Eof] carries the location just past the source. *)

type kind =
  | LParen
  | RParen
  | Colon
  | ColonEq
  | Arrow
  | DArrow
  | KType
  | KFun
  | KLet
  | KIn
  | KDef
  | KReducible
  | KEval
  | KCheck
  | KData
  | KMatch
  | KWith
  | KAs
  | KReturn
  | KRec
  | KEnd
  | KLetStar  (** M3 Stage C: "let*", the [bindIO] sugar keyword *)
  | KLetStarDiv  (** M3 Stage C: "let*!", the [bindDiv] sugar keyword *)
  | KPartial  (** M3 Stage C: "partial", follows "rec" in a def header *)
  | Pipe
  | Ident of string
  | Nat of int
  | Str of string  (** M3 Stage A: a double-quoted string literal *)
  | Eof

type t = {
  kind : kind;
  loc : Loc.t;
}

let describe (k : kind) : string =
  match k with
  | LParen -> "'('"
  | RParen -> "')'"
  | Colon -> "':'"
  | ColonEq -> "':='"
  | Arrow -> "'->'"
  | DArrow -> "'=>'"
  | KType -> "'Type'"
  | KFun -> "'fun'"
  | KLet -> "'let'"
  | KIn -> "'in'"
  | KDef -> "'def'"
  | KReducible -> "'reducible'"
  | KEval -> "'eval'"
  | KCheck -> "'check'"
  | KData -> "'data'"
  | KMatch -> "'match'"
  | KWith -> "'with'"
  | KAs -> "'as'"
  | KReturn -> "'return'"
  | KRec -> "'rec'"
  | KEnd -> "'end'"
  | KLetStar -> "'let*'"
  | KLetStarDiv -> "'let*!'"
  | KPartial -> "'partial'"
  | Pipe -> "'|'"
  | Ident s -> Printf.sprintf "identifier %s" s
  | Nat n -> Printf.sprintf "number %d" n
  | Str s -> Printf.sprintf "string literal %S" s
  | Eof -> "end of input"
