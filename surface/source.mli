(** Read source text from a regular file, classifying failures explicitly. *)

type error = Missing | Not_regular | Unreadable

val message : error -> string
val read : string -> (string, error) result
