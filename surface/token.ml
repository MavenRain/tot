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
  | Ident of string
  | Nat of int
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
  | Ident s -> Printf.sprintf "identifier %s" s
  | Nat n -> Printf.sprintf "number %d" n
  | Eof -> "end of input"
