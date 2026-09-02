(** Erased runtime syntax: an untyped lambda calculus. Erasure removes
    every quantity-0 binder and argument, so indices here count only the
    binders that survive. [EErased] is the inert residue of a type-level
    term in a runtime position; applying it is a runtime error.

    Marshal-format checklist (M3 Stage D): every [Interp.v] [VClos]
    closes over a value of this type, and [surface/cache.ml] marshals
    [Interp.globals] whole. Any change here bumps
    [Cache.format_version]. *)

type t =
  | EVar of int
  | ELam of string * t
  | EApp of t * t
  | ELet of string * t * t  (** let x := def in body; the type is gone *)
  | EGlobal of string
  | EErased
  | EMatch of t * (string * string list * t) list
      (** scrutinee, then per branch: ctor name, KEPT arg binder names
          (quantity-0 binders are gone), body *)
  | ELit of Literal.t
      (** M3 Stage A. Cache-format note: this type feeds Stage D's
          prelude cache, so any change here bumps that cache's format
          version constant once it exists. *)
