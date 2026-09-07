(** Bidirectional typechecking with 0/omega quantity modes. Every pass
    RETURNS a stamped term: [Lam]/[App] quantities in checker output come
    from the Pi checked against, never from the input placeholder, [Ann]
    is dropped from output (annotations steer checking only), and match
    branch binders are stamped from the constructor telescope. This makes
    checker output the one authority erasure needs. [define],
    [declare_ind] and [define_ind] are the only public ways to extend the
    global environment. *)

type ctx = {
  env : Value.t list;
  locals : (string * Quantity.t * Value.t) list;
  size : int;
  budget : Budget.t;
      (** M5 Stage C (pin 8): the driver's cutoff.  Defaults to
          [Budget.unlimited] in [empty_ctx], so every existing caller
          of [empty_ctx] compiles and behaves unchanged. *)
}

(** The empty checking context: no environment, no locals, no binders
    and an unlimited budget. *)
val empty_ctx : ctx

(** M5 Stage C: the root context for one driver invocation. *)
val root_ctx : Budget.t -> ctx

(** [bind x q ty ctx] extends [ctx] with one binder of quantity [q] at
    type [ty], introducing a fresh neutral variable at the new level. *)
val bind : string -> Quantity.t -> Value.t -> ctx -> ctx

(** [pp_value globals size v] renders [v] as source under [size]
    binders.  Display only. *)
val pp_value : Global.t -> int -> Value.t -> string

(** M4 fixes round 4 (opus R4-5): the longest a printed value may be
    inside a diagnostic that names the USER's whole query.

    M4 fixes round 5 (opus R5-6b): 2000, not 400.  D7c asserts a budget
    computed FROM this number, so the number itself was free to move by
    5x with the battery green;  measured in a scratch copy, 100000 fails
    D7c and 2000 keeps the whole battery green.  2000 is the value that
    leaves every diagnostic the gate set actually prints intact while
    still bounding a query-sized one. *)
val goal_print_cap : int

(** Clamp [s] to [goal_print_cap] bytes, cutting on a CHARACTER
    boundary and marking the cut with an ellipsis, so a diagnostic's
    size is a property of the DIAGNOSTIC and never of the input.

    M4 fixes round 4 (opus R4-5): round 3 made [Inst_depth] name the
    original query instead of the peeled [ity], which is the right
    payload, but [pp_value] then rendered the WHOLE query on the failure
    path: measured on a wide query, one stderr line of 31,748 bytes. The
    one-line channel contract survived (it is still exactly one line),
    but a message whose length tracks the input is not a bounded line.
    The cut keeps a prefix, which is where the query's own head sits, so
    every existing assertion that looks for the head still matches.

    M4 fixes round 5 (opus R5-6a): the cut was a raw byte cut.  [Pp]
    prints string literals raw and a [String]-indexed family is a legal
    type argument, so a multi-byte character could straddle it and put a
    lone continuation byte on a channel whose whole purpose is machine
    consumption (executed: a 0xc3 at position 480 made a UTF-8 decode of
    the stderr line fail).  [char_boundary] backs the cut up to the
    start of the straddled character, so the result is valid UTF-8
    whenever the input was.

    M4 fixes round 5 (opus R5-5, ctxcat r5 id 15): applied at the
    construction site of EVERY [Error.t] payload built from [pp_value],
    not only [Inst_depth].  Round 4 clamped one constructor out of a
    family that shares the payload: measured on the round-4 binary,
    [Inst_unresolved] still printed a 32,122-byte stderr line and
    [Mismatch], which carries TWO such payloads, printed 800,162 bytes.
    The clamp stays at the construction sites and NOT inside
    [Error.to_string], because the suites pin exact short messages and a
    central clamp would make that pin a property of the formatter. *)
val elide : string -> string

(** [pp_value] for a DIAGNOSTIC payload: the same rendering, [elide]d.
    Every [Error.t] payload in this module that embeds a printed value
    is built with this and never with [pp_value] directly, so the bound
    is a property of the error FAMILY instead of whichever constructor a
    round happened to measure.  [pp_value] itself stays unclamped for
    the surface driver's display lines ([surface/run.ml]'s "def .. : .."
    and "eval : .."), which are output, not diagnostics. *)
val pp_goal : Global.t -> int -> Value.t -> string

(** M4 fixes round 1 (ctxcat id 8): strip the [Term.Ann] nodes off a
    term's HEAD.  [infer] deletes its own [Ann] node (its arm returns the
    checked subterm), so a raw type and its stamped counterpart differ by
    exactly these wrappers;  Stage A moved the constructor result-head
    check to the RAW type, which made every annotated codomain
    (`| mk : (Foo : Type 0)`) and every annotated parameter argument
    (`| mk2 : Foo2 (A : Type 0)`) fail [Bad_ctor] with a reason about
    arity that had nothing to do with the real cause.  Total, and the
    IDENTITY on stamped terms, so no elaborated path changes behavior. *)
val strip_ann : Term.t -> Term.t

(** An index expression may be any term that does not mention the
    inductive being defined. Named and separated from [is_applied] so a
    kernel test can exercise it directly (see kernel test A6). Named and
    separated from [is_applied] so a kernel test can exercise it
    directly; see the reachability note carried into SPEC.md: an index
    expression's own TYPE is bounded by [declare_ind]'s [Level.le] check
    to live at or below the family's declared level, strictly below
    [Univ level]'s own level, so an index expression can never itself be
    an application of [name] (whose type is [Univ level]). The check is
    therefore a total backstop, unreachable from source, and must NOT be
    deleted even though no source fixture can witness it. *)
val index_expr_clean : string -> Term.t -> bool

(** M4 Stage A: the three-part subsingleton criterion (user decision 1).
    [true] iff eliminating a value of this family can never observe a
    runtime bit: at most one constructor, every constructor argument
    binder at quantity 0, and the constructor NOT self-recursive. *)
val zero_eliminable : Global.t -> Global.ind_entry -> bool

(** M4 fixes round 4 (opus R4-3): the WIDTH measure, [t]'s node count.
    Every leaf counts 1, so a query mentioning [L] distinct leaf types
    has [term_size >= L] whatever its depth. [term_depth] cannot see
    this dimension at all (a balanced tree over [L] leaves has depth
    [log2 L]), which is why [inst_fuel] needs both. *)
val term_size : Term.t -> int

(** M5 Stage C (pin 12): the round-5 shape above, multiplied by
    [1 + class_count], where the count is the number of DISTINCT class
    components of [inst$] mangled names in the table (there is no class
    registry; a class is an ordinary [Ind], so the count is a property
    of the INSTANCE TABLE, which is where the round-5 comment above
    already places it).  The factor is measured, not proved: on the
    [classes K] generated shape the charge and this bound are BOTH
    about quadratic in K, so the leaf is re-bisected
    (dev/bisect-inst-classes.sh), never asserted gone. *)
val inst_fuel : Global.t -> Term.t -> int

(** M4 fixes round 3 (opus R3-1): an INJECTIVE, total encoding of a
    [Term.t] as a string.  Used only to build [inst_memo_key];  it is
    never printed and never parsed back.

    Injectivity is what makes the memo SOUND, so it is bought
    explicitly rather than assumed: every constructor carries its own
    leading tag letter, every embedded string is length-prefixed
    ("3:abc"), and every variable-length list is count-prefixed, so no
    delimiter can be forged from inside a name and two distinct terms
    never encode alike.

    Hand-rolled rather than [Stdlib.compare] on [Term.t] itself:
    polymorphic compare happens to be total on this first-order type
    today, but that is not a property [Term.t] promises, and a future
    functional payload would turn a wrong instance into a raise inside
    a [Map] rebalance.  Pieces are accumulated in REVERSE and joined
    once, so the encoding is linear in the term's size rather than
    quadratic in it. *)
val inst_key_enc : Term.t -> string

(** M5 Stage B (pin 4): one instance application, with its dictionary
    arguments named by SLOT NUMBER instead of by de Bruijn index.  A
    slot number is an index into [inst_state.entries] in DEFINITION
    order, and it never changes as the walk proceeds; a de Bruijn index
    for the same slot depends on how many lets finally enclose the use
    site, which the walk does not know until it ends.  [islot_term]
    converts one to the other, once, at materialization. *)
type islot = IHead of string | IApp of Quantity.t * islot * iarg
and iarg = IType of Term.t | ISlot of int

(** M8 Stage D: the state of one [Term.Auto] resolution.  ABSTRACT
    here.  The fuel counter, the memo carrier and the slot list are
    kernel bookkeeping;  a caller builds a state with [inst_start] and
    threads it through [build_instance] without reading it. *)
type inst_state

(** The initial state for one [Term.Auto]: full fuel, an EMPTY memo. *)
val inst_start : int -> Value.t -> inst_state

(** M4 Stage D (D2): peel the instance's own Pi telescope, filling type
    arguments positionally from the key's own arguments ([targs]) and
    recursing into [resolve_auto] on every dictionary domain.  [fuel] is
    a belt over the structural termination argument: each dictionary
    recursion descends into a strict subvalue of the query, so the walk
    terminates anyway.

    M4 fixes round 2 (ctxcat id 5): [fuel] is the budget for everything
    still to come, and the pair returned carries what is left of it.

    M4 fixes round 3 (opus R3-1, R3-6): the budget travels inside
    [inst_state] together with the memo and the original goal;  the
    [Inst_depth] payload names that goal, not the partially peeled
    [ity] this call happens to hold.

    M4 fixes round 4 (opus R4-5): that payload is [elide]d, so the one
    stderr line the driver contract promises is also a BOUNDED line.

    M5 Stage B (pins 4, 5): the accumulator is an [islot], and a
    parallel VALUE accumulator [acc_v] rides beside it, seeded with the
    instance head's own value and advanced one [Eval.apply] per
    argument.  That is what retires M4's per-argument
    [Eval.eval globals ctx.env sub] (the old lib/check.ml:725): the
    value of a resolved sub-dictionary now arrives from the
    sub-resolution itself, and NbE's own [App] equation
    (lib/eval.ml:56-59) makes the two spellings the same value. *)
val build_instance :
  Global.t ->
  ctx ->
  inst_state ->
  Value.t ->
  Value.t list ->
  islot ->
  Value.t -> (islot * Value.t * inst_state, Error.t) result

(** M5 Stage C (pin 8): one poll per checked node, then the M4 body
    unchanged.  The wrapper, not the body, is what every recursive call
    reaches, so "node granularity" is a property of the call graph and
    not of a list of hand-picked sites. *)
val infer :
  Global.t ->
  ctx -> Quantity.t -> Term.t -> (Term.t * Value.t, Error.t) result

(** M5 Stage C (pin 8): [check]'s polling wrapper, the twin of
    [infer]'s above. *)
val check :
  Global.t ->
  ctx -> Quantity.t -> Term.t -> Value.t -> (Term.t, Error.t) result

(** [stamped_ty] (M4 fixes round 1, ctxcat id 9) lets a caller that has
    ALREADY elaborated [ty] hand in that artifact instead of paying for a
    second, independent elaboration whose agreement with the first rests
    on an unstated determinism assumption.  Precondition, and the only
    caller ([define_instance]) meets it: [stamped_ty] is
    [infer_univ globals empty_ctx ty]'s own output term, for this same
    [globals] and this same [ty].  Absent it, nothing changes. *)
(** [rule] (M6 Stage A, verdict pin 8): the totality rule the [rec_]
    path's guard runs.  [Totality.rule] has the single constructor
    [Totality.Structural], the shipped M2 rule;  an M7 admission rule
    re-enters by adding a constructor.  REQUIRED, not optional, so the
    compiler enumerates every call site and none can pick up a silent
    default. *)
val define :
  ?rec_:bool ->
  ?partial:bool ->
  ?stamped_ty:Term.t ->
  ?budget:Budget.t ->
  rule:Totality.rule ->
  Global.t ->
  name:string ->
  reducible:bool ->
  ty:Term.t -> def:Term.t -> (Global.t, Error.t) result

(** Extend the environment with a native prim (M3 Stage A). The only
    public way to grow [Global.t] with a [Prim] entry. It does NOT check
    that [Prim.arity prim] agrees with [ty]; a catalog-level test does
    that instead. *)
val define_prim :
  ?budget:Budget.t ->
  Global.t ->
  name:string -> ty:Term.t -> prim:Prim.t -> (Global.t, Error.t) result

(** Extend the environment with a postulated statement (M4 Stage B). The
    only public way to grow [Global.t] with an [Axiom] entry: [ty]
    validates and stamps exactly like [define_prim]'s, and the stored
    entry carries no runtime body at all, so an axiom is confined to
    quantity 0 by [infer]'s own [Term.Global] guard above, never by
    anything here. *)
val define_axiom :
  ?budget:Budget.t ->
  Global.t -> name:string -> ty:Term.t -> (Global.t, Error.t) result

(** M4 Stage D (D2): register an instance under its mangled name.
    Validates the STAMPED type's registration shape BEFORE calling
    [define], which performs the actual coherence check
    ([ensure_fresh]):  a second instance at the same key is
    [Duplicate_global], exactly like any other duplicate global;  there
    is no separate class-coherence kernel state.  Instances are forced
    [reducible = true]:  they are small constructor values, and proofs
    about method calls want them to compute. *)
val define_instance :
  ?budget:Budget.t ->
  Global.t ->
  name:string -> ty:Term.t -> def:Term.t -> (Global.t, Error.t) result

(** Declare an inductive's name, parameters, index telescope and level.
    Constructors arrive separately via [define_ind] so their types can
    mention the inductive. [indices] is REQUIRED (not optional with a
    [] default), so every existing call site is visited by the
    compiler. *)
val declare_ind :
  ?budget:Budget.t ->
  Global.t ->
  name:string ->
  params:Global.telescope ->
  indices:Global.telescope ->
  level:Level.t -> (Global.t, Error.t) result

(** M4 Stage A: the bootstrap-only entry point for a type former that
    will NEVER be [define_ind]'d (String, Int, Div, IO). Same as
    [declare_ind ~indices:[]], except the stored status is [Builtin]:
    [define_ind] on a [Builtin] inductive is [Ind_redefined], and a match
    on one is [Builtin_not_eliminable] rather than [Ind_incomplete]. *)
val declare_builtin :
  Global.t ->
  name:string -> params:Global.telescope -> (Global.t, Error.t) result

(** Check and install the constructors of an already-declared inductive.
    Enforces the result-head rule, strict positivity with uniform
    parameters, and the predicative universe bound. Nested occurrences
    may pass through certified parameter slots of completed, unindexed
    inductives with erased plain universe parameters. The container's
    whole reachable global closure must also be free of the family
    being defined and of any provisional inductive. A definition alias
    in a direct field is not walked. Function domains must remain
    occurrence-free. On any error the caller keeps its
    pre-declaration globals. *)
val define_ind :
  ?budget:Budget.t ->
  Global.t ->
  name:string ->
  ctors:(string * Term.t) list -> (Global.t, Error.t) result
