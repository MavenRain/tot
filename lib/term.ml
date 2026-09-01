(** Core syntax. Variables are de Bruijn indices; binder names are
    display-only and never affect equality. *)

type t =
  | Var of int
  | Univ of Level.t
  | Pi of Quantity.t * string * t * t
  | Lam of string * t
  | App of t * t
  | Let of string * t * t * t  (** let x : ty = def in body *)
  | Ann of t * t  (** (term : type) *)
  | Global of string
