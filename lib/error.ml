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
  | Prim_arity of {
      prim : string;
      expected : int;
      found : int;
    }  (** a [VPrim] application spine grew past its catalog arity (M3
          Stage A); a total backstop, unreachable on a checked program *)
  | Not_quotable of string
      (** M3 Stage A: readback reached a runtime value [quote] has no
          syntax for. Stage B's [VIOAction] is its first real user. *)
  | Missing_prelude_ctor of string
      (** M3 Stage A: a name a prim builds by hand (e.g. "true") does
          not resolve after the prelude has folded *)
  | Effect_def_reducible of string
      (** M3 Stage B: [reducible] on a def whose STAMPED type head is
          [Div] or [IO] (decision 9 of the M3 design verdict); building
          such a value is inert, but marking it [reducible] would let
          conversion step INTO the effect, which the ladder forbids *)
  | Partial_reducible_conflict of string
      (** M3 Stage C: [reducible] together with [partial] on the same
          def (decision 10 of the M3 design verdict); a partial def is
          always opaque to conversion *)
  | Partial_not_div of string
      (** M3 Stage C: a [partial] def whose codomain (after peeling its
          leading Pi telescope) does not have head [Div]; [partial] is
          the one sanctioned way to reach [Div] from tot source, so its
          codomain must say so *)
  | Regex_bad_pattern of string
      (** M3 fixes, B1 (C19): [Str.regexp] rejected the pattern itself
          (its own [Failure] channel).  A malformed pattern is a
          DISTINCT runtime error, never the same silent no-match a
          benign miss produces: a typo'd pattern in a guard must error,
          not fail open.  Payload: the pattern plus Str's reason. *)
  | Exit_code_out_of_range of int
      (** M3 fixes, B4 (C10): [exitWith] outside 0..255.  The OS
          truncates an exit code to its low 8 bits, which would
          silently change a hook-protocol decision, so the range
          violation is an error instead of a wrap. *)

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
  | Prim_arity { prim; expected; found } ->
      Printf.sprintf "prim %s expects %d argument(s), got %d" prim expected found
  | Not_quotable s -> Printf.sprintf "cannot read back a %s value" s
  | Missing_prelude_ctor n ->
      Printf.sprintf "prelude constructor %s did not resolve after bootstrap" n
  | Effect_def_reducible n ->
      Printf.sprintf "def %s: reducible on a Div- or IO-headed def is not allowed" n
  | Partial_reducible_conflict n ->
      Printf.sprintf "def %s: reducible on a partial def is not allowed" n
  | Partial_not_div n ->
      Printf.sprintf "def %s: partial requires a Div-headed codomain" n
  | Regex_bad_pattern p -> Printf.sprintf "malformed regex pattern: %s" p
  | Exit_code_out_of_range n ->
      Printf.sprintf "exitWith %d: exit code out of range 0..255" n

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
  | Prim_arity _ -> "Prim_arity"
  | Not_quotable _ -> "Not_quotable"
  | Missing_prelude_ctor _ -> "Missing_prelude_ctor"
  | Effect_def_reducible _ -> "Effect_def_reducible"
  | Partial_reducible_conflict _ -> "Partial_reducible_conflict"
  | Partial_not_div _ -> "Partial_not_div"
  | Regex_bad_pattern _ -> "Regex_bad_pattern"
  | Exit_code_out_of_range _ -> "Exit_code_out_of_range"
