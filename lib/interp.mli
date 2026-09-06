(** Call-by-value interpreter over erased terms. Reducibility never
    reaches this module (that is a conversion-time notion); every
    non-rec global still unfolds unconditionally at application time,
    exactly as before. A rec global, however, carries its kernel
    [rec_arg] into the runtime global table and unfolds only when its
    principal argument is a canonical (fully applied) constructor value:
    applying it before that starts (or extends) a neutral application
    under the new [EHGlobal] head, mirroring the kernel's [Value.HGlobal]
    guarded-unfolding discipline (see [Eval]). Without this a rec
    global's cached closure would unfold eagerly under [quote]'s fresh
    neutral binders, re-freezing one level deeper on every peel and
    diverging; readback of a rec function value is now total. [VNeut]
    also still serves its original role: [quote] applies closures to
    fresh neutral variables to reach under binders, and a match stuck on
    such a variable freezes its branches as an [FEMatch] frame. *)

(** Marshal-format checklist (M3 Stage D): [surface/cache.ml] marshals a
    whole [Interp.globals] (every stored [gval] is a [gbody ref] over
    [v]), so any change to this type, to [gbody]/[gentry], or to
    [io_action] below bumps [Cache.format_version]. *)
type v =
  | VClos of string * v list * Eterm.t
  | VCon of string * v list  (** data ctor applied; KEPT args only, in order *)
  | VNeut of ehead * eframe list  (** head + frames, newest first *)
  | VErased
  | VLit of Literal.t  (** M3 Stage A *)
  | VPrim of Prim.t * v list
      (** M3 Stage A: a prim accumulating args toward its catalog
          arity.  Stored NEWEST FIRST since the M3 fixes (C4'):
          [apply] reverses into argument order at fire time, [quote]
          at readback. *)
  | VIOAction of io_action
      (** M3 Stage B: an inert, first-class reified IO action tree.
          Building one performs no OCaml effect; only
          [surface/effect.ml]'s [run_io] ever walks it. *)

and io_action =
  | IOPure of v  (** [pureIO x] / [liftIO dv]: a already-computed value *)
  | IOBind of v * v
      (** [bindIO m k]: the inner action VALUE (expected to itself be a
          [VIOAction], coerced lazily by [Effect.require_action]) and
          the continuation closure *)
  | IONative of Prim.t * v list
      (** a fully-applied native effect prim, undischarged; only
          [Effect.dispatch] performs the actual host call *)

and ehead =
  | EHVar of int  (** readback: a fresh binder introduced by [quote] *)
  | EHGlobal of string
      (** a rec global whose principal argument is not yet known
          canonical; frames accumulate here until the guard is met *)

and eframe =
  | FEApp of v
  | FEMatch of (string * string list * Eterm.t) list * v list
      (** frozen branches + the env their bodies close over *)

(** M3 Stage B: a global's runtime body is forced immediately
    ([GForced]) or recorded as a closed erased term and forced lazily
    ([GDeferred]) whenever [EGlobal] resolves it or a guarded rec
    global unfolds it. [surface/run.ml]'s [IDef] handling (RUN mode
    only, M3 fixes A1) chooses [GDeferred] exactly when the def's
    STAMPED type head is [Div] or [IO] (keyed on the type, not a new
    attribute; decision 11 of the M3 design verdict). M3 fixes, A2
    (C17, 2026-09-01): forcing MEMOIZES. The entry holds a [gbody ref];
    the first force [exec]s the deferred term once and writes the
    computed value back as [GForced], so a chain of n Div-headed defs
    each referencing the previous twice costs n forces, not 2^n
    (Div computation is pure modulo divergence, and an IO-headed body
    only ever BUILDS an inert action tree, identical on every rebuild,
    so storing it changes no observable behavior; [Effect.run_io]
    still fires effects once per WALK of the tree, not per build).
    Every other entry kind (ctor, erased type, prim, ordinary def)
    stays [GForced] from birth, exactly as before this stage. *)
type gbody =
  | GForced of v
  | GDeferred of Eterm.t

(** M4 Stage C: the runtime unfolding guard, three-state.
    [Unguarded] and [GuardedAt] are the M2-fixes behaviors: [Unguarded]
    covers a plain (non-rec) def, a data ctor, an erased type
    constructor, or a prim (every one of [add_ctor]/[add_erased]/
    [add_prim] seeds it); [GuardedAt k] marks a rec def guarded on
    (erased-spine) argument [k], tested for canonicity before it
    unfolds. [Frozen] NEVER unfolds: the global stays an [EHGlobal]
    neutral under any application. [Frozen] is reachable only through
    an inhabitant of a provably empty type, so it is dead code by the
    Stage A soundness argument; it exists so that a missed case
    degrades to a permanent neutral instead of a loop. *)
type guard =
  | Unguarded
  | GuardedAt of int
  | Frozen

(** One runtime global binding. [gval] is the body [EGlobal] resolves to
    when the guard does not apply (a non-rec def's cached closure or
    deferred term, a ctor's growing [VCon], or [VErased] for an inert
    type constructor); for a rec def it also doubles as the closure
    [replay] unfolds onto once the guard is satisfied. It is a [ref]
    cell so [force] can memoize a deferred body's computed value in
    place (M3 fixes, A2); map copies threaded through [Run.state]
    share the cell, so one force pays for every later reference.
    [gguard]: see [guard] above (M4 Stage C; was [grec_arg : int
    option], [Some k]/[None], before this stage widened it to a third
    state).
    [gctor_arity]: [Some n] marks a data constructor whose KEPT
    (quantity-`w`) arity is [n], the runtime analogue of
    [Eval.is_canonical]'s full-arity check (erased args and params
    never reach a runtime [VCon]). *)
type gentry = {
  gval : gbody ref;
  gguard : guard;
  gctor_arity : int option;
}

type globals = gentry Global.StringMap.t

(** The empty runtime environment. *)
val empty_globals : globals

(** The whole payload must parse as exactly one JSON value (trailing
    non-whitespace garbage rejects the whole parse); [None] on any
    failure. *)
val json_parse_top : string -> v option

(** M3 Stage C, C1 ([jsonSerialize], Tot: walks a finite value). A
    shape the prelude's own [data Json] declaration cannot produce
    (e.g. a [jnum] whose argument is not a [VLit (LInt _)]) is
    unreachable on a checked program; the fallback arms are total
    backstops only, mirroring [fire_prim]'s own shape-mismatch style.
    [Json_escape]'s [string] quotes every JSON string this serializer
    emits.  [Pp.escape_string] is the SOURCE escaper and is NOT reused
    here.  M4's claim that the source escape set is a SUBSET of JSON's
    was false: the parser accepts \r, \b and \f (the arms above) and
    the source escaper leaves all three raw, so a parsed-then-
    serialized payload could carry an unescaped control byte.  M5
    Stage A, pin 13. *)
val json_serialize : v -> (string, Error.t) result

(** Count of `\(` group openers in [pattern], as Str's own parser
    reads it: a small state machine over [group_scan], agreeing with
    [Str.regexp]'s group numbering so [Str.matched_group] is never
    asked for a group the compiled pattern does not have (pre-fix, a
    two-char scan counted `\(` inside classes and after escaped
    backslashes too, and the resulting phantom group killed the
    process with an uncaught [Invalid_argument]; O2). *)
val regex_group_count : string -> int

(** [exec eglobals env e] runs the erased term [e] under [env] (newest
    binding first), call by value. *)
val exec : globals -> v list -> Eterm.t -> (v, Error.t) result

(** [apply eglobals f a] applies the runtime value [f] to [a], firing a
    prim or unfolding a guarded rec global when [a] makes it fire. *)
val apply : globals -> v -> v -> (v, Error.t) result

(** Fire a fully-applied prim on its accumulated (oldest-first) argument
    values. [Tot] and [Div] prims (M3 Stage A catalog, plus [pureDiv]
    and [bindDiv]) compute an ordinary value inline: under call-by-value
    a [Div]-typed argument has already been computed by the time it is
    one, so [Div] is a marker at the type level and costs nothing at
    runtime (M3 Stage B, verdict 3.2). [Io] prims never perform an
    OCaml effect here: they wrap their (undischarged) arguments as an
    inert [VIOAction]; only [surface/effect.ml]'s [run_io] ever walks
    one. Argument shapes are checked: a well-typed program can only
    reach the intended shape per prim, so a mismatch here is a total
    backstop, never reachable on a checked program. [eglobals] is used
    only by [Bind_div] (it applies the continuation to the already-
    computed inner value). *)
val fire_prim : globals -> Prim.t -> v list -> (v, Error.t) result

(** Record a user def as a lazy MEMOIZED thunk (M3 fixes round 2, R2:
    every def, not just the Div/IO-headed ones the M3 Stage B rule
    deferred).  Nothing executes here: the body runs on first [force]
    (an eval item or [main] reaching it) and the memo cell keeps
    single-execution, so DEAD code (a def [main] never mentions) can
    neither abort nor hang a run.  Sound because laziness is
    observationally invisible: [Div] carries no host effects and an
    [IO] body only builds an inert action tree.  Erasure and
    closedness are the caller's eager duty ([def] is already a closed
    [Eterm.t]); the one observable shift is that a LIVE def's
    definition-time abort now surfaces at force time.  Total: no body
    execution means no error path, hence no [result]. *)
val define : globals -> name:string -> guard:guard -> Eterm.t -> globals

(** Seed a data constructor: it accumulates its runtime (KEPT) arguments
    up to [arity]. *)
val add_ctor : globals -> name:string -> arity:int -> globals

(** Seed a type constructor: types are inert at runtime. *)
val add_erased : globals -> name:string -> globals

(** Seed a native prim (M3 Stage A). TRAP: a prim of arity 0 can never
    fire on application (there is no application to trigger it), so it
    is fired right here at seed time and the RESULT is stored; every
    other prim starts as an empty [VPrim] spine. [readStdin] (M3 Stage
    B) is the first arity-0 prim this hits: its stored [gval] is
    already [GForced (VIOAction (IONative (Read_stdin, [])))], which
    performs nothing (that is the whole point). *)
val add_prim :
  globals -> name:string -> prim:Prim.t -> (globals, Error.t) result

(** [quote eglobals size v] reads a runtime value back to an erased
    term under [size] fresh neutral binders. *)
val quote : globals -> int -> v -> (Eterm.t, Error.t) result
