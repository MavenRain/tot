(** The kernel's only failure channel. No exception exists anywhere. *)

type t =
  | Unbound_var of int
  | Unbound_global of string
  | Duplicate_global of string
  | Bad_level of int
  | Not_a_function of string
  | Not_a_universe of string
  | Mismatch of {
      expected : string;
      actual : string;
    }
  | Erased_use of string
  | Cannot_infer of string
  | Not_inductive of string  (** match scrutinee type; payload = printed type *)
  | Bad_ctor of {
      ctor : string;
      reason : string;
    }  (** result-head / positivity / universe violation in a data decl *)
  | Branch_mismatch of {
      expected : string;
      found : string;
    }  (** exhaustiveness + declaration order; "<none>" marks a missing side *)
  | Termination of string  (** rec def failed the structural guard *)
  | Ind_redefined of string
      (** a second [define_ind] call on an inductive that already has its
          constructors *)
  | Ind_incomplete of string
      (** a match (or other reader of ctor_names) reached an inductive
          whose constructors are declared but not yet defined *)

let to_string (e : t) : string =
  match e with
  | Unbound_var ix -> Printf.sprintf "unbound variable (index %d)" ix
  | Unbound_global n -> Printf.sprintf "unknown global %s" n
  | Duplicate_global n -> Printf.sprintf "duplicate global %s" n
  | Bad_level l -> Printf.sprintf "internal: level %d escapes its scope" l
  | Not_a_function s -> Printf.sprintf "not a function type: %s" s
  | Not_a_universe s -> Printf.sprintf "not a universe: %s" s
  | Mismatch { expected; actual } ->
      Printf.sprintf "type mismatch: expected %s, found %s" expected actual
  | Erased_use x -> Printf.sprintf "erased variable %s used at runtime" x
  | Cannot_infer x -> Printf.sprintf "cannot infer a type for %s" x
  | Not_inductive s -> Printf.sprintf "match scrutinee is not an inductive: %s" s
  | Bad_ctor { ctor; reason } -> Printf.sprintf "invalid constructor %s: %s" ctor reason
  | Branch_mismatch { expected; found } ->
      Printf.sprintf "match branches do not fit the declaration: expected %s, found %s"
        expected found
  | Termination n ->
      Printf.sprintf "recursive definition %s failed the structural termination guard" n
  | Ind_redefined n -> Printf.sprintf "inductive %s already has its constructors defined" n
  | Ind_incomplete n ->
      Printf.sprintf
        "cannot eliminate %s: its constructors are declared but not yet defined" n

let tag (e : t) : string =
  match e with
  | Unbound_var _ -> "Unbound_var"
  | Unbound_global _ -> "Unbound_global"
  | Duplicate_global _ -> "Duplicate_global"
  | Bad_level _ -> "Bad_level"
  | Not_a_function _ -> "Not_a_function"
  | Not_a_universe _ -> "Not_a_universe"
  | Mismatch _ -> "Mismatch"
  | Erased_use _ -> "Erased_use"
  | Cannot_infer _ -> "Cannot_infer"
  | Not_inductive _ -> "Not_inductive"
  | Bad_ctor _ -> "Bad_ctor"
  | Branch_mismatch _ -> "Branch_mismatch"
  | Termination _ -> "Termination"
  | Ind_redefined _ -> "Ind_redefined"
  | Ind_incomplete _ -> "Ind_incomplete"
