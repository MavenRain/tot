(** Surface errors with source locations and driver exit classification. *)

type t =
  | Lex of {
      loc : Loc.t;
      msg : string;
    }
  | Parse of {
      loc : Loc.t;
      msg : string;
    }
  | Unknown_name of {
      loc : Loc.t;
      name : string;
    }
  | Bad_level of {
      loc : Loc.t;
      level : int;
    }
  | Kernel of {
      loc : Loc.t;
      err : Tot_kernel.Error.t;
    }
  | Main_bad_type of { ty : string }
  | Axioms_disabled of {
      loc : Loc.t;
      name : string;
    }
  | Missing_main
  | Json_strict_reject
  | Hole of {
      loc : Loc.t;
      expected : (string list * Tot_kernel.Term.t) option;
    }

val to_string : t -> string
val tag : t -> string
val driver_exit : t -> bool
val is_check_budget : t -> bool
val is_missing_main : t -> bool
