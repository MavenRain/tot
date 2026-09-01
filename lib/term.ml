(** Core syntax. Variables are de Bruijn indices; binder names are
    display-only and never affect equality. [Lam] and [App] carry a
    quantity stamp: elaboration writes a [Many] placeholder and the
    checker overwrites it with the Pi's quantity, so checker OUTPUT
    terms are authoritative and erasure can be purely structural. *)

type t =
  | Var of int
  | Univ of Level.t
  | Pi of Quantity.t * string * t * t
  | Lam of Quantity.t * string * t
  | App of Quantity.t * t * t
  | Let of string * t * t * t  (** let x : ty = def in body *)
  | Ann of t * t  (** (term : type); the checker drops it from output *)
  | Global of string
  | Match of {
      scrut : t;
      motive : (string * t) option;
          (** binder over the scrutinee; [None] only survives checking in
              check-mode (constant motive = the expected type) *)
      branches : (string * (Quantity.t * string) list * t) list;
          (** ctor name, its OWN args (binder quantities stamped by the
              checker; elaboration writes [Many] placeholders), body *)
    }
