(** Tokenize source text, preserving source locations in tokens and errors. *)

val lex : string -> (Token.t list, Serror.t) result
