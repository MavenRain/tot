(** Whole-script and single-term parsing, retaining per-item hole positions. *)

val parse_with_holes :
  Token.t list -> ((Syntax.item * Loc.t list) list, Serror.t) result

val parse : Token.t list -> (Syntax.item list, Serror.t) result
val term_only : Token.t list -> (Syntax.t, Serror.t) result
