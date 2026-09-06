(** String and integer literal values. A closed leaf with no dependency
    on any other kernel module (M3 Stage A).

    M8 Stage D: the constructors are PUBLIC on purpose.  Every literal
    is built and matched by [Term], [Eterm], [Value], [Interp] and the
    surface modules. *)

type t =
  | LString of string
  | LInt of int

(** Structural equality: same constructor and same payload. *)
val equal : t -> t -> bool
