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
  | Check_budget
      (** M5 Stage C (verdict item 2, pin 8): the driver's check budget
          is spent.  A CUTOFF, not a verdict about the program: the
          same file with a larger budget, or with none, may check
          clean.  Nullary by design.  The kernel knows only that its
          poll said stop;  the driver owns the number of milliseconds
          and prints it. *)

(** M4 fixes round 4 (ctxcat r4 id 3): [true] iff [e] is [Erased_use].
    [Check.match_scrut]'s [Zero] fallback exists to forgive exactly ONE
    error class, an erased hypothesis used as a match scrutinee, so it
    must be able to name that class instead of forgiving every failure
    the ambient mode reports. Spelled as an exhaustive match here (not
    [String.equal (tag e) "Erased_use"]) so that adding a constructor to
    [t] is a compile error at this predicate too, and so the soundness
    condition never depends on a display string. *)
val is_erased_use : t -> bool

(** M5 Stage C: [true] iff [e] is the budget cutoff.  Spelled as an
    exhaustive match, never as [String.equal (tag e) "Check_budget"],
    so a new constructor is a compile error here too and the driver's
    exit-code decision never depends on a display string. *)
val is_check_budget : t -> bool

(** The human-readable message for [e].  Display only: no caller
    decides anything by matching on this string. *)
val to_string : t -> string

(** The constructor name of [e], the stable machine-readable tag the
    JSON verdict envelope carries. *)
val tag : t -> string
