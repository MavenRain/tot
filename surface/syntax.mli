(** Surface syntax with names, source locations and elaboration sugar. *)

type smotive = {
  sm_self : string;
  sm_ind : string option;
  sm_idx : string list;
  sm_body : t;
}

and t =
  | SVar of Loc.t * string
  | SType of Loc.t * int
  | SPi of Loc.t * Tot_kernel.Quantity.t * string * t * t
  | SLam of Loc.t * string * t
  | SApp of Loc.t * t * t
  | SLet of Loc.t * string * t * t * t
  | SAnn of Loc.t * t * t
  | SMatch of Loc.t * t * smotive option * (string * string list * t) list
  | SStr of Loc.t * string
  | SInt of Loc.t * int
  | SLetStar of Loc.t * bool * t * t * string * t * t
  | SAuto of Loc.t
  | SInst of Loc.t * t * t
  | SHole of Loc.t

type defkind =
  | DNonRec
  | DRec
  | DRecPartial

type item =
  | IDef of {
      loc : Loc.t;
      name : string;
      reducible : bool;
      kind : defkind;
      ty : t;
      def : t;
    }
  | IData of {
      loc : Loc.t;
      name : string;
      params : (string * t) list;
      indices : (Tot_kernel.Quantity.t * string * t) list;
      level : int;
      ctors : (string * t) list;
    }
  | IAxiom of {
      loc : Loc.t;
      name : string;
      ty : t;
    }
  | IClass of {
      loc : Loc.t;
      name : string;
      param : string * t;
      methods : (string * t) list;
    }
  | IInstance of {
      loc : Loc.t;
      ty : t;
      def : t;
    }
  | ICheck of Loc.t * t
  | IEval of Loc.t * t

val loc_of : t -> Loc.t
