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
  | Index_not_zero of string
      (** M4 Stage A: an index binder of an inductive declaration
          carries quantity [w] *)
  | Index_above_universe of {
      ind : string;
      index : string;
    }  (** M4 Stage A: an index TYPE lives above the inductive's
           declared universe *)
  | Motive_index_arity of {
      ind : string;
      expected : int;
      found : int;
    }  (** M4 Stage A: the motive binds the wrong number of index names *)
  | Motive_wrong_ind of {
      expected : string;
      found : string;
    }  (** M4 Stage A: the motive's "in I .." clause names a different
           family *)
  | Builtin_not_eliminable of string
      (** M4 Stage A: a match reached a builtin type former, which has
          no constructors and never will *)
  | Axiom_runtime_use of string
      (** M4 Stage B: an axiom was used at quantity mode w; axioms are
          proof-only *)
  | Inst_unresolved of string
      (** M4 Stage D: no instance for this expected type; payload is the
          printed type *)
  | Inst_bad_shape of {
      name : string;
      reason : string;
    }  (** M4 Stage D: an instance whose type does not fit the
           registration shape *)
  | Inst_depth of string
      (** M4 Stage D: instance resolution ran out of fuel; payload is the
          printed type *)

(** M4 fixes round 4 (ctxcat r4 id 3): [true] iff [e] is [Erased_use].
    [Check.match_scrut]'s [Zero] fallback exists to forgive exactly ONE
    error class, an erased hypothesis used as a match scrutinee, so it
    must be able to name that class instead of forgiving every failure
    the ambient mode reports. Spelled as an exhaustive match here (not
    [String.equal (tag e) "Erased_use"]) so that adding a constructor to
    [t] is a compile error at this predicate too, and so the soundness
    condition never depends on a display string. *)
let is_erased_use (e : t) : bool =
  match e with
  | Erased_use _ -> true
  | Unbound_var _ | Unbound_global _ | Duplicate_global _ | Bad_level _ | Not_a_function _
  | Not_a_universe _
  | Mismatch _
  | Cannot_infer _ | Not_inductive _
  | Bad_ctor _
  | Branch_mismatch _
  | Termination _ | Ind_redefined _ | Ind_incomplete _
  | Prim_arity _
  | Not_quotable _ | Missing_prelude_ctor _ | Effect_def_reducible _
  | Partial_reducible_conflict _ | Partial_not_div _ | Regex_bad_pattern _
  | Exit_code_out_of_range _ | Index_not_zero _ | Index_above_universe _
  | Motive_index_arity _
  | Motive_wrong_ind _
  | Builtin_not_eliminable _ | Axiom_runtime_use _ | Inst_unresolved _
  | Inst_bad_shape _
  | Inst_depth _ ->
      false

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
  | Index_not_zero n ->
      Printf.sprintf "inductive %s: every index binder must be marked 0" n
  | Index_above_universe { ind; index } ->
      Printf.sprintf "inductive %s: index %s lives above the declared universe" ind index
  | Motive_index_arity { ind; expected; found } ->
      Printf.sprintf "match motive for %s binds %d index name(s), expected %d" ind found
        expected
  | Motive_wrong_ind { expected; found } ->
      Printf.sprintf "match motive names inductive %s, but the scrutinee is a %s" found
        expected
  | Builtin_not_eliminable n ->
      Printf.sprintf "cannot eliminate %s: it is a builtin type former with no constructors" n
  | Axiom_runtime_use n ->
      Printf.sprintf "axiom %s used at runtime: axioms are usable only at quantity 0" n
  | Inst_unresolved s -> Printf.sprintf "no instance found for %s" s
  | Inst_bad_shape { name; reason } -> Printf.sprintf "instance %s: %s" name reason
  | Inst_depth s -> Printf.sprintf "instance resolution for %s exceeded its fuel" s

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
  | Index_not_zero _ -> "Index_not_zero"
  | Index_above_universe _ -> "Index_above_universe"
  | Motive_index_arity _ -> "Motive_index_arity"
  | Motive_wrong_ind _ -> "Motive_wrong_ind"
  | Builtin_not_eliminable _ -> "Builtin_not_eliminable"
  | Axiom_runtime_use _ -> "Axiom_runtime_use"
  | Inst_unresolved _ -> "Inst_unresolved"
  | Inst_bad_shape _ -> "Inst_bad_shape"
  | Inst_depth _ -> "Inst_depth"
