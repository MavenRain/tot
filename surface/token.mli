(** Lexical tokens and the source location of each token's first character. *)

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
  | KLetStar
  | KLetStarDiv
  | KPartial
  | KAxiom
  | KClass
  | KInstance
  | KAuto
  | KInst
  | Underscore
  | LBrace
  | RBrace
  | Semi
  | Pipe
  | Ident of string
  | Nat of int
  | Str of string
  | Eof

type t = {
  kind : kind;
  loc : Loc.t;
}

val describe : kind -> string
