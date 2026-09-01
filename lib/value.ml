(** NbE semantic domain. Neutral spines store the newest argument first. *)

type t =
  | VUniv of Level.t
  | VPi of Quantity.t * string * t * closure
  | VLam of string * closure
  | VNeutral of head * t list

and head =
  | HVar of int  (** de Bruijn level *)
  | HGlobal of string

and closure = {
  env : t list;
  body : Term.t;
}

let var (lvl : int) : t = VNeutral (HVar lvl, [])
