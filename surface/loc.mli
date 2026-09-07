(** Source positions, 1-based. *)

type t = {
  line : int;
  col : int;
}

val start : t
val next_col : t -> t
val advance : t -> int -> t
val next_line : t -> t
val to_string : t -> string
