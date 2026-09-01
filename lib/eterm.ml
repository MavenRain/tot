(** Erased runtime syntax: an untyped lambda calculus. Erasure removes
    every quantity-0 binder and argument, so indices here count only the
    binders that survive. [EErased] is the inert residue of a type-level
    term in a runtime position; applying it is a runtime error. *)

type t =
  | EVar of int
  | ELam of string * t
  | EApp of t * t
  | ELet of string * t * t  (** let x := def in body; the type is gone *)
  | EGlobal of string
  | EErased
