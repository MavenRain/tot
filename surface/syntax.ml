(** Surface syntax: names, locations, and sugar; no indices yet. *)

type t =
  | SVar of Loc.t * string
  | SType of Loc.t * int
  | SPi of Loc.t * Tot_kernel.Quantity.t * string * t * t
  | SLam of Loc.t * string * t
  | SApp of Loc.t * t * t
  | SLet of Loc.t * string * t * t * t  (** let x : ty := def in body *)
  | SAnn of Loc.t * t * t  (** (term : type) *)

type item =
  | IDef of {
      loc : Loc.t;
      name : string;
      reducible : bool;
      ty : t;
      def : t;
    }
  | ICheck of Loc.t * t
  | IEval of Loc.t * t

let loc_of (s : t) : Loc.t =
  match s with
  | SVar (loc, _) -> loc
  | SType (loc, _) -> loc
  | SPi (loc, _, _, _, _) -> loc
  | SLam (loc, _, _) -> loc
  | SApp (loc, _, _) -> loc
  | SLet (loc, _, _, _, _) -> loc
  | SAnn (loc, _, _) -> loc
