(** NbE semantic domain. Neutral frames store the newest frame first.
    [VInd] and [VCtor] are canonical inductive values: a type constructor
    or data constructor applied to its arguments in order (a data ctor
    carries its erased parameter values too; evaluation of a match drops
    them). A stuck match freezes its motive and branch BODIES as terms
    together with the env they close over.

    Marshal-format checklist (M3 Stage D): [Value.t] itself is never
    marshaled (it holds closures), but it is the checker's semantic
    domain for [Term.t], so a shape change here usually tracks a
    [Term.t] change; treat the two together against
    [Cache.format_version]. *)

type t =
  | VUniv of Level.t
  | VPi of Quantity.t * string * t * closure
  | VLam of string * closure
  | VInd of string * t list  (** type ctor applied; args in order *)
  | VCtor of string * t list  (** data ctor applied; args in order, params included *)
  | VNeutral of head * frame list  (** frames newest first *)
  | VLit of Literal.t
      (** canonical, like [VCtor] (M3 Stage A). Cache-format note: this
          type feeds Stage D's prelude cache, so any change here bumps
          that cache's format version constant once it exists. *)

and head =
  | HVar of int  (** de Bruijn level *)
  | HGlobal of string

and frame =
  | FApp of t
  | FMatch of stuck_match

and stuck_match = {
  motive : Term.motive option;  (** M4 Stage A: CHANGED payload, same option *)
  branches : (string * (Quantity.t * string) list * Term.t) list;
  menv : t list;  (** env for motive and branch bodies alike *)
}

and closure = {
  env : t list;
  body : Term.t;
}

let var (lvl : int) : t = VNeutral (HVar lvl, [])
