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
  | KAxiom  (** M4 Stage B: "axiom", a postulated statement item *)
  | KClass  (** M4 Stage D: "class", a dictionary-type declaration item *)
  | KInstance  (** M4 Stage D: "instance", an instance-registration item *)
  | KAuto  (** M4 Stage D: "auto", an instance-request atom *)
  | KInst  (** M4 Stage D: "inst", the explicit instance escape hatch *)
  | Underscore
      (** M6 Stage C (verdict pin 2, ruling R2): the reserved token
          [_].  Term position: a hole ([Syntax.SHole]).  Binder
          position: the anonymous binder, the same display name "_"
          the printer already uses.  Never a definable or
          referencable name.  Reserved as the EXACT token: [_foo],
          [_1] and [_'] stay ordinary identifiers. *)
  | LBrace  (** M4 Stage D: "{", opens a class's method list *)
  | RBrace  (** M4 Stage D: "}", closes a class's method list *)
  | Semi  (** M4 Stage D: ";", separates a class's methods *)
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
  | KAxiom -> "'axiom'"
  | KClass -> "'class'"
  | KInstance -> "'instance'"
  | KAuto -> "'auto'"
  | KInst -> "'inst'"
  | Underscore -> "'_'"
  | LBrace -> "'{'"
  | RBrace -> "'}'"
  | Semi -> "';'"
  | Pipe -> "'|'"
  | Ident s -> Printf.sprintf "identifier %s" s
  | Nat n -> Printf.sprintf "number %d" n
  | Str s -> Printf.sprintf "string literal %S" s
  | Eof -> "end of input"
