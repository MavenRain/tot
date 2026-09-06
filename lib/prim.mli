(** The native primitive catalog (M3 Stage A). A closed enum with no
    OCaml closures inside, so [Global.t] and [Interp.globals] stay
    marshalable (decision 3 of the M3 design verdict, section 3.10).
    Later stages EXTEND this enum; every extension extends [name],
    [arity], [classification], [justification] and [catalog] together. *)

(** Where a prim sits on the effect ladder. Stage A carries only [Tot]:
    every catalog entry fires inline at runtime, never during
    conversion (a [Prim] entry is always opaque to [Eval.conv], see
    [Global.prim_entry]). [Div] and [Io] arrive in later stages. *)
type ladder =
  | Tot
  | Div
  | Io

(** Marshal-format checklist (M3 Stage D): a [Prim.t] value is the
    payload of every [Interp.v] [VPrim]/[VIOAction] spine and every
    [Global.prim_entry], and [surface/cache.ml] marshals those whole.
    Any change here bumps [Cache.format_version]. *)
type t =
  | String_concat
  | String_length
  | String_eq
  | String_contains
  | Int_add
  | Int_sub
  | Int_eq
  | Int_to_string
  | Pure_div  (** M3 Stage B: the ladder, [Div]'s unit *)
  | Bind_div  (** M3 Stage B: the ladder, [Div]'s bind *)
  | Pure_io  (** M3 Stage B: the ladder, [IO]'s unit *)
  | Bind_io  (** M3 Stage B: the ladder, [IO]'s bind *)
  | Lift_io  (** M3 Stage B: the one [Div] -> [IO] bridge *)
  | Read_stdin  (** M3 Stage B: native IO, arity 0 *)
  | Print_line  (** M3 Stage B: native IO *)
  | Exit_with  (** M3 Stage B: native IO *)
  | Get_env  (** M3 Stage B: native IO *)
  | String_slice  (** M3 Stage C: bounds-checked substring, Tot *)
  | String_split  (** M3 Stage C: split on a separator, Tot *)
  | String_to_int  (** M3 Stage C: decimal parse, Tot *)
  | Int_compare  (** M3 Stage C: three-way compare, Tot *)
  | Read_file  (** M3 Stage C: native IO *)
  | Write_file  (** M3 Stage C: native IO *)
  | Argv  (** M3 Stage C: native IO, arity 0 *)
  | Proc_run  (** M3 Stage C: native IO, spawns a child process *)
  | Json_parse
      (** M3 Stage C: Div, not Tot. The parser is host code with no
          structural termination proof, and its flagship caller
          (hook payload parsing) feeds it attacker-shaped text. *)
  | Json_serialize  (** M3 Stage C: Tot, walks a finite value *)
  | Regex_test
      (** M3 Stage C: Div. Backtracking engines have catastrophic
          input/pattern pairs; the [Div] classification is provenance
          and a composition discipline, NOT an operational
          termination proof (a PreToolUse guard is expected to
          adjudicate attacker-influenced pattern/text pairs). *)
  | Regex_match  (** M3 Stage C: Div, same rationale as [Regex_test] *)


(** The surface spelling of [p], the name the bootstrap seeds and
    [of_name] parses back. *)
val name : t -> string

(** KEPT (quantity-w) arguments only: the erased type arguments a prim's
    Pi telescope may carry never count. Note the M3 Stage B correction:
    [pureIO]'s kept arity is 1 (the value argument only), not 2; the
    monadic design proposal's arity table listed 2, which contradicted
    the verdict's own decision 4. The declared bootstrap type is
    authoritative; [surface/bootstrap.ml]'s [seed_prim] checks every
    catalog entry against it, and test/main.ml's
    [case_prim_arity_agreement] pins the agreement over all three
    seeding phases (M3 fixes, C2'). *)
val arity : t -> int

(** The effect rung [p] sits on.  One arm per rung, exhaustive. *)
val classification : t -> ladder

(** Why [p] carries the rung [classification] gives it.  Display only. *)
val justification : t -> string

(** Every constructor, in declaration order. A Stage A test enforces
    that this list, [name] and [of_name] agree. *)
val catalog : t list

(** [of_name s] is the catalog entry whose [name] is [s], or [None]. *)
val of_name : string -> t option
