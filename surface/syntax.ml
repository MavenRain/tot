(** Surface syntax: names, locations, and sugar; no indices yet. *)

type t =
  | SVar of Loc.t * string
  | SType of Loc.t * int
  | SPi of Loc.t * Tot_kernel.Quantity.t * string * t * t
  | SLam of Loc.t * string * t
  | SApp of Loc.t * t * t
  | SLet of Loc.t * string * t * t * t  (** let x : ty := def in body *)
  | SAnn of Loc.t * t * t  (** (term : type) *)
  | SMatch of Loc.t * t * (string * t) option * (string * string list * t) list
      (** scrutinee, optional "as x return P" motive, flat branches
          (ctor name, binder names, body) *)

type item =
  | IDef of {
      loc : Loc.t;
      name : string;
      reducible : bool;
      rec_ : bool;  (** [def rec]: route through the guarded define path *)
      ty : t;
      def : t;
    }
  | IData of {
      loc : Loc.t;
      name : string;
      params : (string * t) list;  (** always quantity-0 (parser-enforced) *)
      level : int;
      ctors : (string * t) list;  (** ctor types, scoped under the params *)
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
  | SMatch (loc, _, _, _) -> loc
