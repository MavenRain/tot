(** Bidirectional typechecking with 0/omega quantity modes. Every pass
    RETURNS a stamped term: [Lam]/[App] quantities in checker output come
    from the Pi checked against, never from the input placeholder, [Ann]
    is dropped from output (annotations steer checking only), and match
    branch binders are stamped from the constructor telescope. This makes
    checker output the one authority erasure needs. [define],
    [declare_ind] and [define_ind] are the only public ways to extend the
    global environment. *)

let ( let* ) = Result.bind

type ctx = {
  env : Value.t list;
  locals : (string * Quantity.t * Value.t) list;
  size : int;
}

let empty_ctx : ctx = { env = []; locals = []; size = 0 }

let bind (x : string) (q : Quantity.t) (ty : Value.t) (ctx : ctx) : ctx =
  { env = Value.var ctx.size :: ctx.env; locals = (x, q, ty) :: ctx.locals; size = ctx.size + 1 }

let bind_def (x : string) (ty : Value.t) (v : Value.t) (ctx : ctx) : ctx =
  { env = v :: ctx.env; locals = (x, Quantity.Many, ty) :: ctx.locals; size = ctx.size + 1 }

let pp_value (globals : Global.t) (size : int) (v : Value.t) : string =
  Eval.quote globals size v
  |> Result.fold ~ok:(Pp.term []) ~error:(fun _e -> "<unprintable>")

(** M4 fixes round 4 (opus R4-5): the longest a printed value may be
    inside a diagnostic that names the USER's whole query.

    M4 fixes round 5 (opus R5-6b): 2000, not 400.  D7c asserts a budget
    computed FROM this number, so the number itself was free to move by
    5x with the battery green;  measured in a scratch copy, 100000 fails
    D7c and 2000 keeps the whole battery green.  2000 is the value that
    leaves every diagnostic the gate set actually prints intact while
    still bounding a query-sized one. *)
let goal_print_cap : int = 2000

(** The largest byte offset at most [n] that STARTS a UTF-8 character.
    One left fold: a byte starts a character unless it is a
    continuation byte ([0b10xxxxxx]), so the answer is the greatest
    such offset not past [n], and 0 when there is none. *)
let char_boundary (s : string) (n : int) : int =
  let _, best =
    String.fold_left
      (fun ((i : int), (best : int)) (c : char) ->
        let starts_char = not (Int.equal (Char.code c land 0xC0) 0x80) in
        let best' = if starts_char && i <= n then i else best in
        (i + 1, best'))
      (0, 0) s
  in
  best

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
let elide (s : string) : string =
  if String.length s <= goal_print_cap then s
  else String.sub s 0 (char_boundary s goal_print_cap) (* @total-accessor *) ^ "..."

(** [pp_value] for a DIAGNOSTIC payload: the same rendering, [elide]d.
    Every [Error.t] payload in this module that embeds a printed value
    is built with this and never with [pp_value] directly, so the bound
    is a property of the error FAMILY instead of whichever constructor a
    round happened to measure.  [pp_value] itself stays unclamped for
    the surface driver's display lines ([surface/run.ml]'s "def .. : .."
    and "eval : .."), which are output, not diagnostics. *)
let pp_goal (globals : Global.t) (size : int) (v : Value.t) : string =
  elide (pp_value globals size v)

(** M3 Stage B: the head name of an already-evaluated type value, peeling
    nothing else. [None] for every shape that is not an applied (or
    bare) inductive type constructor. *)
let ind_head_name (ty_v : Value.t) : string option =
  match ty_v with
  | Value.VInd (n, _) -> Some n
  | Value.VUniv _ | Value.VPi (_, _, _, _) | Value.VLam (_, _) | Value.VCtor (_, _)
  | Value.VNeutral (_, _) | Value.VLit _ ->
      None

(** [true] iff [ty_v]'s head is the [Div] or [IO] type former (M3 Stage
    B decisions 9 and 11): both are declared-only inductives, so a hit
    is exactly [Value.VInd ("Div", _)] or [Value.VInd ("IO", _)],
    peeling nothing else. A def of type [String -> IO Unit] has head
    [VPi], so it is unaffected: building a function that RETURNS an
    action is inert. Shared by [define]'s [reducible] refusal and
    [surface/run.ml]'s deferred-definition-time-execution decision. *)
let is_effect_headed (ty_v : Value.t) : bool =
  ind_head_name ty_v
  |> Option.fold ~none:false ~some:(fun n -> String.equal n "Div" || String.equal n "IO")

(** [true] iff [ty_v]'s head is exactly the [Div] type former (M3 Stage
    C, decision 10). Shared by [define]'s [partial] codomain check. *)
let is_div_headed (ty_v : Value.t) : bool =
  ind_head_name ty_v |> Option.fold ~none:false ~some:(String.equal "Div")

(** M3 Stage C: peel [t]'s leading [Term.Pi] binders and evaluate the
    codomain under an env of one fresh neutral variable per peeled
    binder, so a codomain that depends on an earlier binder (e.g.
    [(0 A : Type 0) -> Div A]) evaluates correctly. Mirrors
    [Totality.peel]'s shape but keeps binder TYPES (it must call
    [Eval.eval], not just count them). Used only by [define]'s
    [partial] codomain check. *)
let rec peel_codomain (globals : Global.t) (env : Value.t list) (size : int) (t : Term.t) :
    (Value.t, Error.t) result =
  match t with
  | Term.Pi (_q, _x, _dom, cod) -> peel_codomain globals (Value.var size :: env) (size + 1) cod
  | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto
  | Term.Lam (_, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Match _ ->
      Eval.eval globals env t

(** M4 fixes round 1 (ctxcat id 8): strip the [Term.Ann] nodes off a
    term's HEAD.  [infer] deletes its own [Ann] node (its arm returns the
    checked subterm), so a raw type and its stamped counterpart differ by
    exactly these wrappers;  Stage A moved the constructor result-head
    check to the RAW type, which made every annotated codomain
    (`| mk : (Foo : Type 0)`) and every annotated parameter argument
    (`| mk2 : Foo2 (A : Type 0)`) fail [Bad_ctor] with a reason about
    arity that had nothing to do with the real cause.  Total, and the
    IDENTITY on stamped terms, so no elaborated path changes behavior. *)
let rec strip_ann (t : Term.t) : Term.t =
  match t with
  | Term.Ann (tm, _ty) -> strip_ann tm
  | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto
  | Term.Pi (_, _, _, _)
  | Term.Lam (_, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Global _ | Term.Match _ ->
      t

(** M4 Stage A: does [name] occur anywhere in [t] as a [Term.Global]?
    Top-level (not nested inside [define_ind]) so a kernel test can
    exercise [index_expr_clean] below directly.

    M4 fixes round 1 (audit F3): the contract is "PROVABLY free of
    [name]", so [Term.Auto] answers FALSE, not true.  [is_applied] runs
    this on the RAW (pre-elaboration) constructor type, where an
    unresolved [auto] stands for a spine the resolver has not produced
    yet;  that spine may mention [name], so accepting [Auto] let a
    result-index position skip the index-cleanliness ban entirely
    (`data AI : Nat -> Type 0 := | ai : AI auto` reached elaboration).
    The arm is unreachable from [strict_pos], which runs on STAMPED
    arguments where [infer] has already replaced every [Auto]. *)
let rec no_occur (name : string) (t : Term.t) : bool =
  match t with
  | Term.Auto -> false
  | Term.Var _ | Term.Univ _ | Term.Lit _ -> true
  | Term.Global g -> not (String.equal g name)
  | Term.Pi (_q, _x, dom, cod) -> no_occur name dom && no_occur name cod
  | Term.Lam (_q, _x, b) -> no_occur name b
  | Term.App (_q, f, a) -> no_occur name f && no_occur name a
  | Term.Let (_x, ty, def, b) -> no_occur name ty && no_occur name def && no_occur name b
  | Term.Ann (tm, ty) -> no_occur name tm && no_occur name ty
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      no_occur name scrut
      && (motive
         |> Option.fold ~none:true ~some:(fun (mo : Term.motive) -> no_occur name mo.Term.m_body))
      && List.for_all (fun (_c, _bs, b) -> no_occur name b) branches

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
let index_expr_clean (name : string) (e : Term.t) : bool = no_occur name e

(** M4 Stage A: the three-part subsingleton criterion (user decision 1).
    [true] iff eliminating a value of this family can never observe a
    runtime bit: at most one constructor, every constructor argument
    binder at quantity 0, and the constructor NOT self-recursive. *)
let zero_eliminable (globals : Global.t) (ind : Global.ind_entry) : bool =
  match ind.Global.ctors with
  | Global.Provisional -> false
  | Global.Builtin -> false
  | Global.Complete [] -> true
  | Global.Complete [ c ] ->
      Global.find_ctor c globals
      |> Option.fold ~none:false ~some:(fun (ctor : Global.ctor_entry) ->
             List.for_all (fun (q, _x, _ty) -> Quantity.equal q Quantity.Zero) ctor.Global.args
             && not ctor.Global.self_rec)
  | Global.Complete (_ :: _ :: _) -> false

(** M4 Stage B: [true] iff [e] is the [Axiom] entry kind. Shared by
    [infer]'s [Term.Global] arm, which combines this with the mode
    check that confines an axiom to quantity 0. *)
let is_axiom (e : Global.entry) : bool =
  match e with
  | Global.Axiom _ -> true
  | Global.Def _ | Global.Ind _ | Global.Ctor _ | Global.Prim _ -> false

(** M4 fixes round 1 (ctxcat ids 1+6): the NESTING measure for instance
    resolution, the syntactic DEPTH of a term (was: [term_size], its node
    count).  Depth is what actually bounds the nesting: every nested
    dictionary resolution descends into a STRICT subvalue of the key, so
    a resolution can nest at most as deep as the query type is, whatever
    that type's breadth. *)
let rec term_depth (t : Term.t) : int =
  match t with
  | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto | Term.Global _ -> 1
  | Term.Pi (_q, _x, dom, cod) -> 1 + Int.max (term_depth dom) (term_depth cod)
  | Term.Lam (_q, _x, body) -> 1 + term_depth body
  | Term.App (_q, f, a) -> 1 + Int.max (term_depth f) (term_depth a)
  | Term.Let (_x, ty, def, body) ->
      1 + Int.max (term_depth ty) (Int.max (term_depth def) (term_depth body))
  | Term.Ann (tm, ty) -> 1 + Int.max (term_depth tm) (term_depth ty)
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      1
      + Int.max
          (Int.max (term_depth scrut)
             (motive
             |> Option.fold ~none:0 ~some:(fun (mo : Term.motive) -> term_depth mo.Term.m_body)))
          (List.fold_left (fun acc (_c, _binders, b) -> Int.max acc (term_depth b)) 0 branches)

(** M4 fixes round 4 (opus R4-3): the WIDTH measure, [t]'s node count.
    Every leaf counts 1, so a query mentioning [L] distinct leaf types
    has [term_size >= L] whatever its depth. [term_depth] cannot see
    this dimension at all (a balanced tree over [L] leaves has depth
    [log2 L]), which is why [inst_fuel] needs both. *)
let rec term_size (t : Term.t) : int =
  match t with
  | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto | Term.Global _ -> 1
  | Term.Pi (_q, _x, dom, cod) -> 1 + term_size dom + term_size cod
  | Term.Lam (_q, _x, body) -> 1 + term_size body
  | Term.App (_q, f, a) -> 1 + term_size f + term_size a
  | Term.Let (_x, ty, def, body) -> 1 + term_size ty + term_size def + term_size body
  | Term.Ann (tm, ty) -> 1 + term_size tm + term_size ty
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      1 + term_size scrut
      + (motive
        |> Option.fold ~none:0 ~some:(fun (mo : Term.motive) -> term_size mo.Term.m_body))
      + List.fold_left (fun acc (_c, _binders, b) -> acc + term_size b) 0 branches

(** Leading Pi binders of [t]. *)
let rec pi_arity (t : Term.t) : int =
  match t with
  | Term.Pi (_q, _x, _dom, cod) -> 1 + pi_arity cod
  | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto
  | Term.Lam (_, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Match _ ->
      0

(** M4 fixes round 1 (ctxcat ids 1+6): the initial fuel for one instance
    resolution.  The staged Stage D code passed [term_size] of the QUERY,
    which is a false-negative source rather than the intended backstop:
    fuel is spent on a quantity the query cannot see.  [build_instance]
    charges up to 2 per instance binder (one for entering the dictionary
    sub-resolution, one for the continuation), so an instance with four
    dictionary binders (a registrable, well-formed shape
    [validate_instance_shape] accepts) failed [Inst_depth] for a query
    whose node count is 5, even though the resolution is finite and
    would have succeeded.

    The bound is a PRODUCT of the two independent quantities that
    actually govern the walk:

    - per level, [2 * max binders over the registered instance table + 2]
      fuel covers peeling the widest telescope any registered instance
      HAS, with slack.  This factor is a property of the table, never of
      the query, which is exactly what the finding demands.
    - the number of levels is bounded by [term_depth] of the query,
      because each nested resolution descends into a strict subvalue of
      the key.  This factor cannot come from the table: legitimate
      resolutions nest arbitrarily deep in the query alone (the prelude's
      own [EqD (List^n Int)] for growing n), so any table-only constant
      would reintroduce the same false negative one level deeper.

    Fuel therefore stays a belt over the structural termination argument
    (each dictionary recursion descends into a strict subvalue, so the
    walk terminates anyway) instead of a reachable rejection.

    M4 fixes round 2 (ctxcat id 5): this number is now a genuine BUDGET
    for the whole resolution, not a per-path depth counter;  see
    [resolve_auto].

    M4 fixes round 3 (opus R3-1): the round-2 size was WRONG for a
    budget, and measurably so.  Total steps and per-path steps coincide
    only on a single-dictionary-binder chain;  on every other accepted
    telescope the total grows faster than the query's depth while this
    number grows linearly in it, so the belt fired on legitimate input:
    [(0 A) -> TC A -> TD A -> TC (TBox A)] (two DIFFERENT classes) at
    nesting 6, the SPEC's own [DC A -> DC A -> DC (DBox A)] at nesting
    4, and eight INDEPENDENT chains (k*n sub-resolutions, linear work)
    at k=8, n=20.  All three resolved on the round-1 binary.

    Round 3 makes the walk polynomial with a real (class, key) memo (see
    [resolve_auto]) and keeps fuel as what it was always documented to
    be: a BACKSTOP over the structural termination argument, never a
    reachable rejection.  With the memo the work is bounded by the
    number of DISTINCT (class, key) pairs the query can reach, which is
    the class count times the query's distinct subvalue count, a
    quantity a depth-only formula cannot bound at all (a wide query has
    many subvalues at the same depth).  So the number is now the round-2
    formula times 16, floored at a flat 10000: 16x keeps the shape of
    the old argument for deep queries, and the floor covers wide ones,
    for which depth says nothing.  Measured headroom after the memo: the
    deepest legitimate shape in the gate set spends 133 fuel of 10000,
    and a 400-level chain (the deepest shape either opus round timed)
    spends about 1200.

    M4 fixes round 4 (opus R4-3): "the floor covers wide ones" was
    FALSE, and measurably so.  A constant bounds width only up to that
    constant.  After the memo the walk peels one telescope per DISTINCT
    (class, key) pair, and a two-type-binder two-dictionary-binder
    instance charges exactly 6 per distinct internal key, so a balanced
    [WPair] tree over [L] pairwise distinct leaf types (depth [log2 L],
    so the depth term stays pinned at its floor) charges [6 (L - 1)] and
    was rejected from [6 (L - 1) > 10000], that is [L >= 1668].
    Bisected on the round-3 binary to the leaf: [L = 1667] resolves at
    charge 9996, [L = 1668] reports [Inst_depth] at charge 10002.  That
    is a REACHABLE rejection of a finite, well formed, resolvable query,
    which is exactly what this number's own contract forbids.  The
    backstop now scales in BOTH dimensions: the round-3 depth formula
    unchanged (so no deep shape loses fuel) and, additionally,
    [8 * term_size], which gives a width-[L] query at least [8 L].  On
    the generated shape [term_size] is about [4 L], so the wide query
    gets about [32 L] against a [6 L] charge, a 5x margin that grows
    with the query instead of running out at a constant.  Pinned by
    PASS-M4FIX-INST-WIDE at [L = 2500] (charge 14994, over the old
    10000 floor and rejected by the round-3 binary).

    M4 fixes round 5 (ctxcat r5 id 16, opus R5-2): round 4 took the MAX
    of a depth-scaled term and a width-scaled term, and the walk's cost
    is their PRODUCT, so a MAX bounds it only up to the smaller factor.
    Both dimensions of the product are real and both were reachable:

    - width times per-key cost.  The width term [8 * term_size] carried
      NO per-key factor, so it was calibrated for the shipped
      two-type-binder two-dictionary-binder instance (charge 6 per key)
      alone.  An 8-binder instance
      [(0 A) (0 B) -> C A -> C B -> D A -> D B -> E A -> E B ->
      C (WPair A B)], which [validate_instance_shape] accepts, charges
      about 14 per key against the same query.
    - class count times width.  [K] single-field classes and one
      [WPair] instance per class demanding every class on both
      parameters charges about [K^2] per query node, while every round-4
      term was linear in [K].  Bisected on the round-4 binary to the
      leaf on a four-leaf query: [K = 56] resolves, [K = 57] reports
      [Inst_depth].

    So the width term is now the PRODUCT the walk actually charges:
    a key-count bound ([term_size] of the quoted query, which is at
    least the number of distinct subvalues a key can name) times the
    per-key cost ([2 * max_binders + 2], a property of the instance
    TABLE, which is where the class count enters, since a K-class table
    has [2 K]-binder instances), times the safety constant 8.  The
    depth term is unchanged, so no deep shape loses fuel, and the new
    width term is at least twice the old one for every table
    ([2 * max_binders + 2 >= 2]), so no shape that resolved before can
    stop resolving.

    M4 fixes round 6 (opus R6-1): the sentence this replaces claimed
    fuel is "never a reachable rejection", and execution refutes it, so
    the contract is stated as what the number actually buys.  Fuel is a
    BACKSTOP over a STRUCTURAL termination argument, not a decision
    procedure: [validate_instance_shape] requires every dictionary
    domain to be a single-parameter class over a STRICT subvalue of the
    head's key, so every registrable walk descends into strict
    subvalues and terminates whatever this number says.  The bound
    covers every SHIPPED gate shape with a recorded margin
    (PASS-M4FIX-INST-WIDE at [L = 2500];  PASS-M4FIX-INST-CLASSES at
    [K = 57], three classes under the measured leaf below;
    test/main.ml's D9f, the 8-binder instance against a wide balanced
    query, charge about 10710 against [fuel = 147312] at
    [term_size = 1023], which is the 7 percent margin its own case
    records over the round-4 floor and about 13x headroom under this
    bound, kernel-level so the pin does not also pay the candidate
    re-check's tree walk).  A WIDE-CLASS query still rejects
    beyond a MEASURED leaf: on the four-leaf generated shape of
    [dev/gen-inst-fuel.py classes K], executed on this binary, [K = 60]
    resolves and [K = 61] reports [Inst_depth] ("exceeded its fuel").
    The round-4 bound put that leaf four or five classes lower (the
    round-4 bisection recorded above: [K = 56] resolves, [K = 57]
    rejects;  a round-6 differential that reverted ONLY the width term
    measured [K = 55] resolving and [K = 56] rejecting), so the product
    term above moved the leaf by under 10 percent;  it NARROWS the
    MAX-over-a-product defect on this dimension
    rather than closing it, because the class count enters the CHARGE
    through both the (class, key) pair count and the telescope length
    while every term of this bound stays linear in [per_key].  The
    honest close is the residual SPEC.md section 6 records: this counter
    is not a TIME budget, so a large legitimate resolution buys wall
    clock with no verdict at all, which is the check-budget debt and M5
    hash consing, not a fuel-formula debt. *)
let inst_fuel (globals : Global.t) (expected_t : Term.t) : int =
  let max_binders =
    Global.StringMap.fold
      (fun (name : string) (entry : Global.entry) (acc : int) ->
        let is_instance =
          String.length name >= 5 && String.equal (String.sub name 0 5 (* @total-accessor *)) "inst$"
        in
        if is_instance then Int.max acc (pi_arity (Global.entry_ty entry)) else acc)
      globals 0
  in
  let per_key = (2 * max_binders) + 2 in
  Int.max
    (Int.max 10000 (16 * ((1 + term_depth expected_t) * per_key)))
    (8 * term_size expected_t * per_key)

(** M4 Stage D: the [Term.Global] name at the head of [t]'s application
    spine.  Every [build_instance] accumulator starts as [Term.Global]
    and only ever grows by [Term.App], so the head is always [Global] in
    practice;  the other arms are a total backstop for a shape this
    function's own callers never actually produce. *)
let instance_head_name (t : Term.t) : string =
  let head, _args = Totality.spine t [] in
  match head with
  | Term.Global g -> g
  | Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _)
  | Term.Lam (_, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Lit _ | Term.Auto | Term.Match _ ->
      "<instance>"

(** M4 fixes round 3 (opus R3-1): the instance memo's carrier.  Keyed by
    a STRING, because the key half of a (class, key) pair is a
    [Term.t]: see [inst_memo_key]. *)
module InstMemo = Map.Make (String)

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
let inst_key_enc (t : Term.t) : string =
  let enc_str (x : string) : string = string_of_int (String.length x) ^ ":" ^ x in
  let enc_q (q : Quantity.t) : string =
    match q with Quantity.Zero -> "0" | Quantity.Many -> "w"
  in
  let rec go (acc : string list) (t : Term.t) : string list =
    match t with
    | Term.Var i -> ("V" ^ string_of_int i ^ ";") :: acc
    | Term.Univ l -> ("U" ^ Level.to_string l ^ ";") :: acc
    | Term.Pi (q, x, dom, cod) -> go (go (("P" ^ enc_q q ^ enc_str x) :: acc) dom) cod
    | Term.Lam (q, x, body) -> go (("L" ^ enc_q q ^ enc_str x) :: acc) body
    | Term.App (q, f, a) -> go (go (("A" ^ enc_q q) :: acc) f) a
    | Term.Let (x, ty, def, body) -> go (go (go (("E" ^ enc_str x) :: acc) ty) def) body
    | Term.Ann (tm, ty) -> go (go ("N" :: acc) tm) ty
    | Term.Global g -> ("G" ^ enc_str g) :: acc
    | Term.Lit (Literal.LString s) -> ("S" ^ enc_str s) :: acc
    | Term.Lit (Literal.LInt n) -> ("I" ^ string_of_int n ^ ";") :: acc
    | Term.Auto -> "?" :: acc
    | Term.Match { scrut; scrut_q; motive; branches } ->
        let acc_scrut = go (("M" ^ enc_q scrut_q) :: acc) scrut in
        let acc_motive =
          motive
          |> Option.fold ~none:("m0" :: acc_scrut) ~some:(fun (mo : Term.motive) ->
                 let head =
                   "m1"
                   ^ (mo.Term.m_ind |> Option.fold ~none:"i0" ~some:(fun i -> "i1" ^ enc_str i))
                   ^ string_of_int (List.length mo.Term.m_idx)
                   ^ ";"
                   ^ String.concat "" (List.map enc_str mo.Term.m_idx)
                   ^ enc_str mo.Term.m_self
                 in
                 go (head :: acc_scrut) mo.Term.m_body)
        in
        List.fold_left
          (fun (acc' : string list) ((c, binders, body) : string * (Quantity.t * string) list * Term.t) ->
            let head =
              "b" ^ enc_str c
              ^ string_of_int (List.length binders)
              ^ ";"
              ^ String.concat "" (List.map (fun (q, x) -> enc_q q ^ enc_str x) binders)
            in
            go (head :: acc') body)
          ((string_of_int (List.length branches) ^ ";") :: acc_motive)
          branches
  in
  String.concat "" (List.rev (go [] t))

(** M4 fixes round 3 (opus R3-1): the memo key, the (class, key) pair
    the SPEC debt named, spelled in full.  The key half is the class
    argument's own QUOTED term, not just its head symbol: within one
    resolution [C (Box (Box Bool))] and [C (Box Bool)] share the head
    [Box] but resolve to different instance applications, so a
    head-only key would serve the inner term for the outer query. *)
let inst_memo_key (cls : string) (key_t : Term.t) : string =
  string_of_int (String.length cls) ^ ":" ^ cls ^ inst_key_enc key_t

(** M4 fixes round 3 (opus R3-1, R3-6): everything ONE [Term.Auto]
    resolution threads through itself.  Immutable, passed in and
    returned updated exactly as round 2 threaded the bare fuel; there
    is no mutable state anywhere in the walk.

    - [fuel] is the backstop, see [inst_fuel].
    - [memo] maps an [inst_memo_key] to the instance application that
      key already resolved to, DURING THIS resolution only. Scoping it
      to one [Term.Auto] is what makes it sound without an invalidation
      rule: [globals] and [ctx] are invariant across the whole walk
      (every recursive call forwards both unchanged), so a key that
      resolved once resolves identically again.
    - [goal] is the ORIGINAL query value, carried only so [Inst_depth]
      can name what the user actually asked for. Round 2 rendered
      [ity], the instance type at the point the budget ran out, which
      after partial peeling is a Pi telescope naming neither the user's
      goal nor an unresolvable one (opus R3-6). Kept as a [Value.t], not
      a rendered string, so [pp_value] runs on the failure path only. *)
type inst_state = { fuel : int; memo : Term.t InstMemo.t; goal : Value.t }

(** The initial state for one [Term.Auto]: full fuel, an EMPTY memo. *)
let inst_start (fuel : int) (goal : Value.t) : inst_state =
  { fuel; memo = InstMemo.empty; goal }

(** M4 Stage D (D2): resolve [Term.Auto] against [expected], a total
    function of the expected type VALUE with no search and no
    backtracking (user decision 2).  [expected] must be a class applied
    to exactly one type;  the KEY is that type's own head symbol;  the
    instance lives under the mangled name ["inst$" ^ cls ^ "$" ^ key].
    Mutually recursive with [build_instance], which peels the found
    instance's own Pi telescope and recurses here for every dictionary
    sub-argument.

    M4 fixes round 2 (ctxcat id 5): returns the REMAINING fuel beside
    the resolved term, and [build_instance] passes that remainder on to
    the continuation instead of its own [fuel - 1]. Round 1's counter
    handed [fuel - 1] to BOTH the sub-resolution and the continuation,
    so it bounded the depth of a single path and never the total number
    of resolutions: an instance with two dictionary binders on the same
    type variable (a shape [validate_instance_shape] accepts, e.g.
    [(0 A : Type 0) -> C A -> C A -> C (Box A)]) performed 2^n identical
    sub-resolutions for a query at nesting n, while fuel grew only
    linearly in n, so the belt could not fire. Measured on the round-1
    binary: 0.41s at n=14, 7.43s at n=18, 32.82s at n=20.

    M4 fixes round 3 (opus R3-1): round 2 bounded that blow-up by
    REJECTING it, which cost reach round 1 already shipped. The real
    fix, the one the SPEC recorded as a debt, is here now: a (class,
    key) MEMO, threaded in [inst_state] beside the fuel, immutable,
    passed in and returned updated. It is consulted BEFORE the instance
    lookup and written only on success, so a divergent path can never
    hit it and the fuel backstop stays reachable for one.

    What the memo buys, and why it is sound.  Round 2's blow-up was
    re-derivation, never new work: [(0 A) -> C A -> C A -> C (Box A)]
    resolves [C (Box^(n-1) Bool)] TWICE per level, and
    [(0 A) -> TC A -> TD A -> TC (TBox A)] re-derives the whole [TD]
    chain once per [TC] level. Both are the SAME query at the same
    [globals] and the same [ctx], which never change during a
    resolution, so answering the second from the first is an identity,
    not an approximation. The walk therefore performs at most one
    telescope peel per DISTINCT (class, key) pair: 2^n becomes O(n) and
    the quadratic two-class shape becomes O(n).

    Fuel remains a total backstop over the structural termination
    argument: every recursive step of [build_instance] decrements,
    [resolve_auto] only forwards, and a memo HIT does no work and
    charges nothing, so the walk still performs at most [inst_fuel]
    steps and cannot hang. With [inst_fuel] resized (16x, floored at
    10000) it does not fire on legitimate input either: measured reach
    after this change is nesting 30 for the two-class shape, 16 for the
    SPEC shape, k=8 n=40 for independent chains and depth 20 for the
    branching fixture, all in about 0.01s. Pinned by
    PASS-M4FIX-INST-BRANCHING (which now requires RESOLUTION),
    PASS-M4FIX-INST-TWOCLASS, PASS-M4FIX-INST-SPEC-SHAPE,
    PASS-M4FIX-INST-CHAINS and PASS-M4FIX-INST-SMALL-REACH. *)
let rec resolve_auto (globals : Global.t) (ctx : ctx) (st : inst_state) (expected : Value.t) :
    (Term.t * inst_state, Error.t) result =
  let unresolved () = Error.Inst_unresolved (pp_goal globals ctx.size expected) in
  match expected with
  | Value.VInd (cls, [ av ]) ->
      let key_of (v : Value.t) : string option =
        match v with
        | Value.VInd (k, _ts) -> Some k
        | Value.VPi (_, _, _, _) | Value.VUniv _ | Value.VNeutral (_, _) | Value.VLam (_, _)
        | Value.VCtor (_, _) | Value.VLit _ ->
            None
      in
      (* M4 fixes round 1 (ctxcat id 2): [Option.to_result ~none:] takes a
         STRICT argument, so spelling the failure inline ran [pp_value]
         on every successful resolution too.  [~none:()] plus
         [Result.map_error] defers it to the failure path without
         matching on the option. *)
      let* k =
        key_of av |> Option.to_result ~none:() |> Result.map_error (fun () -> unresolved ())
      in
      let mangled = "inst$" ^ cls ^ "$" ^ k in
      let* key_t = Eval.quote globals ctx.size av in
      let mkey = inst_memo_key cls key_t in
      (* A memo HIT returns the term this very resolution already built
         for this (class, key) and charges no fuel;  a MISS resolves and
         records. [Result.fold]'s two arms are both functions, so the
         miss path is not evaluated on a hit (the same eagerness trap
         [Option.fold ~none:] carries, M4 fixes round 1 ctxcat id 2). *)
      InstMemo.find_opt mkey st.memo
      |> Option.to_result ~none:()
      |> Result.fold
           ~ok:(fun (cached : Term.t) -> Ok (cached, st))
           ~error:(fun () ->
             let* d =
               Global.find_def mangled globals
               |> Option.to_result ~none:()
               |> Result.map_error (fun () -> unresolved ())
             in
             let* ity = Eval.eval globals [] d.Global.ty in
             let targs =
               match av with
               | Value.VInd (_, ts) -> ts
               | Value.VPi (_, _, _, _) | Value.VUniv _ | Value.VNeutral (_, _)
               | Value.VLam (_, _)
               | Value.VCtor (_, _)
               | Value.VLit _ ->
                   []
             in
             let* tm, st' = build_instance globals ctx st ity targs (Term.Global mangled) in
             Ok (tm, { st' with memo = InstMemo.add mkey tm st'.memo }))
  | Value.VInd (_, ([] | _ :: _ :: _))
  | Value.VPi (_, _, _, _)
  | Value.VUniv _
  | Value.VNeutral (_, _)
  | Value.VLam (_, _)
  | Value.VCtor (_, _)
  | Value.VLit _ ->
      Error (unresolved ())

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
    stderr line the driver contract promises is also a BOUNDED line. *)
and build_instance (globals : Global.t) (ctx : ctx) (st : inst_state) (ity : Value.t)
    (targs : Value.t list) (acc : Term.t) : (Term.t * inst_state, Error.t) result =
  match () with
  | () when st.fuel <= 0 -> Error (Error.Inst_depth (pp_goal globals ctx.size st.goal))
  | () -> (
      match ity with
      | Value.VPi (q, _x, dom, clo) -> (
          match dom with
          | Value.VUniv _ -> (
              match targs with
              | [] ->
                  Error
                    (Error.Inst_bad_shape
                       {
                         name = instance_head_name acc;
                         reason = "ran out of type arguments while resolving an instance";
                       })
              | t_i :: rest ->
                  let* arg_t = Eval.quote globals ctx.size t_i in
                  let acc' = Term.App (q, acc, arg_t) in
                  let* next_ity = Eval.app_closure globals clo t_i in
                  build_instance globals ctx { st with fuel = st.fuel - 1 } next_ity rest acc')
          | Value.VInd (cls_j, [ dv ]) ->
              (* M4 fixes round 2 (ctxcat id 5): the continuation gets
                 the state the SUB-RESOLUTION left, never a second copy
                 of the state this call started with. M4 fixes round 3
                 (opus R3-1): that state now carries the sub-resolution's
                 memo entries too, so a sibling binder asking the same
                 (class, key) is answered rather than re-derived. *)
              let* sub, st' =
                resolve_auto globals ctx
                  { st with fuel = st.fuel - 1 }
                  (Value.VInd (cls_j, [ dv ]))
              in
              let* sub_v = Eval.eval globals ctx.env sub in
              let acc' = Term.App (q, acc, sub) in
              let* next_ity = Eval.app_closure globals clo sub_v in
              build_instance globals ctx { st' with fuel = st'.fuel - 1 } next_ity targs acc'
          | Value.VInd (_, ([] | _ :: _ :: _))
          | Value.VPi (_, _, _, _)
          | Value.VLam (_, _)
          | Value.VCtor (_, _)
          | Value.VNeutral (_, _)
          | Value.VLit _ ->
              Error
                (Error.Inst_bad_shape
                   {
                     name = instance_head_name acc;
                     reason = "instance domain is neither a type binder nor a single-parameter class";
                   }))
      | Value.VUniv _ | Value.VLam (_, _) | Value.VInd (_, _) | Value.VCtor (_, _)
      | Value.VNeutral (_, _) | Value.VLit _ ->
          Ok (acc, st))

let rec infer (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (tm : Term.t) :
    (Term.t * Value.t, Error.t) result =
  match tm with
  | Term.Var ix ->
      let* x, q, ty =
        List.nth_opt ctx.locals ix |> Option.to_result ~none:(Error.Unbound_var ix)
      in
      (match () with
      | () when Quantity.equal mode Quantity.Zero -> Ok (Term.Var ix, ty)
      | () when Quantity.equal q Quantity.Many -> Ok (Term.Var ix, ty)
      | () -> Error (Error.Erased_use x))
  | Term.Univ l -> Ok (tm, Value.VUniv (Level.succ l))
  | Term.Lit (Literal.LString _) ->
      let* string_ty = Eval.eval globals [] (Term.Global "String") in
      Ok (tm, string_ty)
  | Term.Lit (Literal.LInt _) ->
      let* int_ty = Eval.eval globals [] (Term.Global "Int") in
      Ok (tm, int_ty)
  | Term.Pi (q, x, dom, cod) ->
      let* dom', dom_l = infer_univ globals ctx dom in
      let* dom_v = Eval.eval globals ctx.env dom' in
      let* cod', cod_l = infer_univ globals (bind x q dom_v ctx) cod in
      Ok (Term.Pi (q, x, dom', cod'), Value.VUniv (Level.max dom_l cod_l))
  | Term.Lam (_q, x, _body) ->
      Error (Error.Cannot_infer (Printf.sprintf "the bare lambda (binder %s)" x))
  | Term.App (_q, f, a) ->
      let* f', f_ty = infer globals ctx mode f in
      (match f_ty with
      | Value.VPi (q, _x, dom, clo) ->
          let* a' = check globals ctx (Quantity.mul mode q) a dom in
          (* instantiate the codomain with the STAMPED argument so every
             downstream value is built from checker output *)
          let* a_v = Eval.eval globals ctx.env a' in
          let* res_ty = Eval.app_closure globals clo a_v in
          Ok (Term.App (q, f', a'), res_ty)
      | Value.VUniv _
      | Value.VLam (_, _)
      | Value.VInd (_, _)
      | Value.VCtor (_, _)
      | Value.VNeutral (_, _)
      | Value.VLit _ ->
          Error (Error.Not_a_function (pp_goal globals ctx.size f_ty)))
  | Term.Let (x, ty, def, body) ->
      let* ty', _ty_l = infer_univ globals ctx ty in
      let* ty_v = Eval.eval globals ctx.env ty' in
      let* def' = check globals ctx mode def ty_v in
      let* def_v = Eval.eval globals ctx.env def' in
      let* body', body_ty = infer globals (bind_def x ty_v def_v ctx) mode body in
      Ok (Term.Let (x, ty', def', body'), body_ty)
  | Term.Ann (tm', ty) ->
      let* ty', _ty_l = infer_univ globals ctx ty in
      let* ty_v = Eval.eval globals ctx.env ty' in
      let* tm'' = check globals ctx mode tm' ty_v in
      Ok (tm'', ty_v)
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      let* scrut', scrut_q, iname, p_vals, ivals, ctor_names =
        match_scrut globals ctx mode scrut
      in
      let* mo =
        motive
        |> Option.to_result ~none:(Error.Cannot_infer "a match without 'as .. return'")
      in
      let* ind =
        Global.find_ind iname globals |> Option.to_result ~none:(Error.Unbound_global iname)
      in
      let* () =
        mo.Term.m_ind
        |> Option.fold ~none:(Ok ()) ~some:(fun n ->
               if String.equal n iname then Ok ()
               else Error (Error.Motive_wrong_ind { expected = iname; found = n }))
      in
      let n_indices = List.length ivals in
      let* () =
        if Int.equal (List.length mo.Term.m_idx) n_indices then Ok ()
        else
          Error
            (Error.Motive_index_arity
               { ind = iname; expected = n_indices; found = List.length mo.Term.m_idx })
      in
      (* bind each index binder at the j-th index telescope type,
         evaluated under [p_vals] followed by the previously bound fresh
         index variables, at quantity [Many]; collect the fresh values in
         DECLARATION order for [Value.VInd]'s applied-args list. *)
      let* ctx_idx, rev_idx_vals =
        List.fold_left
          (fun acc (j, (_q, _tname, ty)) ->
            let* actx, ienv, rev_vals = acc in
            let* iname_j =
              List.nth_opt mo.Term.m_idx j
              |> Option.to_result
                   ~none:
                     (Error.Motive_index_arity
                        { ind = iname; expected = n_indices; found = List.length mo.Term.m_idx })
            in
            let* ty_v = Eval.eval globals ienv ty in
            let fresh = Value.var actx.size in
            Ok (bind iname_j Quantity.Many ty_v actx, fresh :: ienv, fresh :: rev_vals))
          (Ok (ctx, List.rev p_vals, []))
          (List.mapi (fun j te -> (j, te)) ind.Global.indices)
        |> Result.map (fun (actx, _ienv, rev_vals) -> (actx, rev_vals))
      in
      let idx_vals = List.rev rev_idx_vals in
      let ctx_m = bind mo.Term.m_self Quantity.Many (Value.VInd (iname, p_vals @ idx_vals)) ctx_idx in
      let* mot', _mot_l = infer_univ globals ctx_m mo.Term.m_body in
      let expected_of (c : string) (fresh_args : Value.t list) (tele_env : Value.t list) :
          (Value.t, Error.t) result =
        let* ctor =
          Global.find_ctor c globals |> Option.to_result ~none:(Error.Unbound_global c)
        in
        let* rev_ivals_c =
          List.fold_left
            (fun acc idx_t ->
              let* done_ = acc in
              let* iv = Eval.eval globals tele_env idx_t in
              Ok (iv :: done_))
            (Ok []) ctor.Global.res_idx
        in
        let ivals_c = List.rev rev_ivals_c in
        Eval.eval globals
          (Value.VCtor (c, p_vals @ fresh_args) :: (List.rev ivals_c @ ctx.env))
          mot'
      in
      let* branches' =
        check_branches globals ctx mode ~p_vals ~expected_of ctor_names branches
      in
      let* scrut_v = Eval.eval globals ctx.env scrut' in
      let* res_ty = Eval.eval globals (scrut_v :: (List.rev ivals @ ctx.env)) mot' in
      Ok
        ( Term.Match
            {
              scrut = scrut';
              scrut_q;
              motive =
                Some
                  {
                    Term.m_ind = mo.Term.m_ind;
                    m_idx = mo.Term.m_idx;
                    m_self = mo.Term.m_self;
                    m_body = mot';
                  };
              branches = branches';
            },
          res_ty )
  | Term.Auto ->
      (* M4 Stage A: real resolution lands in Stage D; here [Auto] is a
         total dead end, unreachable on checker output. *)
      Error (Error.Cannot_infer "auto")
  | Term.Global name ->
      let* entry =
        Global.find name globals |> Option.to_result ~none:(Error.Unbound_global name)
      in
      (* M4 Stage B: an axiom is confined to quantity 0; at mode w it can
         never reach erased output, so a stuck axiom at runtime is
         unrepresentable rather than merely unlikely. *)
      let* () =
        match () with
        | () when is_axiom entry && Quantity.equal mode Quantity.Many ->
            Error (Error.Axiom_runtime_use name)
        | () -> Ok ()
      in
      let* ty_v = Eval.eval globals [] (Global.entry_ty entry) in
      Ok (Term.Global name, ty_v)

and infer_univ (globals : Global.t) (ctx : ctx) (tm : Term.t) :
    (Term.t * Level.t, Error.t) result =
  let* tm', ty = infer globals ctx Quantity.Zero tm in
  match ty with
  | Value.VUniv l -> Ok (tm', l)
  | Value.VPi (_, _, _, _)
  | Value.VLam (_, _)
  | Value.VInd (_, _)
  | Value.VCtor (_, _)
  | Value.VNeutral (_, _)
  | Value.VLit _ ->
      Error (Error.Not_a_universe (pp_goal globals ctx.size ty))

and check (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (tm : Term.t)
    (expected : Value.t) : (Term.t, Error.t) result =
  match (tm, expected) with
  | Term.Lam (_q, x, body), Value.VPi (q, _y, dom, clo) ->
      (* the Pi's quantity is authoritative; the input stamp is discarded *)
      let* cod = Eval.app_closure globals clo (Value.var ctx.size) in
      let* body' = check globals (bind x q dom ctx) mode body cod in
      Ok (Term.Lam (q, x, body'))
  | ( Term.Lam (_q, _x, _body),
      ( Value.VUniv _
      | Value.VLam (_, _)
      | Value.VInd (_, _)
      | Value.VCtor (_, _)
      | Value.VNeutral (_, _)
      | Value.VLit _ ) ) ->
      Error
        (Error.Mismatch
           { expected = pp_goal globals ctx.size expected; actual = "a function" })
  | Term.Let (x, ty, def, body), expected_v ->
      let* ty', _ty_l = infer_univ globals ctx ty in
      let* ty_v = Eval.eval globals ctx.env ty' in
      let* def' = check globals ctx mode def ty_v in
      let* def_v = Eval.eval globals ctx.env def' in
      let* body' = check globals (bind_def x ty_v def_v ctx) mode body expected_v in
      Ok (Term.Let (x, ty', def', body'))
  | Term.Match { scrut; scrut_q = _; motive; branches }, expected_v ->
      (match () with
      | () when Option.is_some motive ->
          (* explicit motive: infer, then converse against the expectation *)
          check_via_infer globals ctx mode tm expected_v
      | () ->
          (* constant motive: every branch checks at the expected type,
             index-invariant (it factors through the dependent rule with
             a motive that ignores all [n_indices + 1] of its binders) *)
          let* scrut', scrut_q, _iname, p_vals, ivals, ctor_names =
            match_scrut globals ctx mode scrut
          in
          let n_indices = List.length ivals in
          let expected_of (_c : string) (_fresh_args : Value.t list)
              (_tele_env : Value.t list) : (Value.t, Error.t) result =
            Ok expected_v
          in
          let* branches' =
            check_branches globals ctx mode ~p_vals ~expected_of ctor_names branches
          in
          (* materialize the constant motive in checker OUTPUT: quoting
             the already-computed [expected_v] [n_indices + 1] binders
             further out than it was built (NbE weakening by de Bruijn
             LEVEL) gives a term that is well-scoped under the extra
             index and scrutinee binders and ignores all of them, exactly
             like an explicit constant `as _ in _ y1 .. yn return
             <expected>` would. This makes a motive-free match and an
             equivalent explicit-motive match compare equal in
             conversion instead of differing purely by spelling. *)
          let* motive_t = Eval.quote globals (ctx.size + n_indices + 1) expected_v in
          let mo : Term.motive =
            {
              Term.m_ind = None;
              m_idx = List.init n_indices (fun _i -> "_");
              m_self = "_";
              m_body = motive_t;
            }
          in
          Ok (Term.Match { scrut = scrut'; scrut_q; motive = Some mo; branches = branches' }))
  | Term.Auto, expected_v ->
      (* M4 Stage D (D2): resolve from the EXPECTED type, then RE-CHECK
         the resolved candidate against it through the ordinary rule
         (point 6): the checker stamps and conv-verifies the candidate,
         so a malformed table entry fails loudly instead of resolving
         wrongly.  M4 fixes round 1 (ctxcat ids 1+6): initial fuel is
         [inst_fuel], the query's nesting depth times the registered
         instance table's own per-level cost;  it was the query's node
         count, which rejected legitimate wide-telescope instances.
         M4 fixes round 3 (opus R3-1): the resolution starts from a
         FRESH [inst_state] -- full fuel and an EMPTY memo -- so the
         memo's soundness argument (invariant [globals] and [ctx]) holds
         by construction: nothing carries across two [Term.Auto]s. *)
      let* expected_t = Eval.quote globals ctx.size expected_v in
      let* candidate, _st_left =
        resolve_auto globals ctx (inst_start (inst_fuel globals expected_t) expected_v) expected_v
      in
      check globals ctx mode candidate expected_v
  | ( (Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _) | Term.App (_, _, _)
      | Term.Ann (_, _) | Term.Global _ | Term.Lit _),
      expected_v ) ->
      check_via_infer globals ctx mode tm expected_v

and check_via_infer (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (tm : Term.t)
    (expected_v : Value.t) : (Term.t, Error.t) result =
  let* tm', actual = infer globals ctx mode tm in
  let* ok = Eval.conv globals ctx.size actual expected_v in
  if ok then Ok tm'
  else
    Error
      (Error.Mismatch
         {
           expected = pp_goal globals ctx.size expected_v;
           actual = pp_goal globals ctx.size actual;
         })

(** Infer the scrutinee and demand a fully applied inductive type; returns
    the stamped scrutinee, the STAMPED elimination quantity, the
    inductive's name, its parameter values, its index values, and its
    declared constructor names.

    M4 Stage A: allowing an erased hypothesis to be the scrutinee at all
    rests on mode [Zero] being the WEAKEST mode, so a scrutinee that
    fails at the ambient mode may still infer at [Zero]. When the family
    is subsingleton-eliminable ([zero_eliminable]) that weaker reading is
    the one that ships, with [scrut_q = Zero]; otherwise the ambient
    mode's own verdict stands (surfacing [Erased_use] exactly when the
    ordinary rule would) and [scrut_q = Many]. Restricting the [Zero]
    stamp to the subsingleton case (never the ambient mode) is what makes
    [Erase]'s two-or-more-branch backstop provably unreachable.

    M4 fixes round 1 (ctxcat id 7): the staged shape inferred at [Zero]
    FIRST and then re-inferred at the ambient mode for every ordinary
    (non-subsingleton) family, so every match cost 2x on its scrutinee
    and a chain of matches nested in SCRUTINEE position cost 2^depth
    (measured on the staged binary: 0.01s at depth 12, 1.08s at depth 20,
    doubling per level). Inference now runs ONCE, at the ambient mode,
    and the [Zero] pass is the FALLBACK taken only when that one failed.

    Soundness. Mode reaches [infer]/[check] in exactly three places: the
    [Var] rule (an erased local at [Many] is [Erased_use]), the [Global]
    rule (an axiom at [Many] is [Axiom_runtime_use]), and multiplicative
    propagation into applications, lets, lambdas and matches. None of
    them changes the STAMPED output: an [App] stamps the Pi's own
    quantity, a [Lam] stamps the Pi's, and a [Match] stamps [scrut_q],
    which this function derives from [zero_eliminable] alone. So for a
    scrutinee that infers at both modes the two passes return the SAME
    term and the SAME type, and the mode decides only WHETHER inference
    errors. Case by case: ambient success plus a subsingleton family
    reuses the ambient stamp with [scrut_q = Zero] (identical to the old
    [Zero]-pass stamp); ambient success otherwise is the old second pass
    minus the recomputation; an ambient FAILURE re-infers at [Zero] and
    either takes the subsingleton allowance or returns the AMBIENT error,
    the exact error the old second pass raised; and when [Zero] fails too
    that error propagates, exactly as the old [Zero]-first pass did.

    M4 fixes round 2 (ctxcat id 4, opus R1). Round 1's claim that "the
    fallback cannot re-explode, because an ambient failure is never
    itself nested" is FALSE for ill-typed input: a missing branch, a
    wrong scrutinee type or a missing motive fails at BOTH modes at
    every level, so each level re-ran the whole subterm and the 2^depth
    curve came back on the error path (measured on the round-1 binary:
    0.11s at depth 18, 1.21s at depth 22, 18.18s at depth 26, 2x per
    level). The fallback is now GUARDED on the ambient mode. [infer] is
    a pure function of [(globals, ctx, mode, scrut)], so when [mode] is
    ALREADY [Zero] the second call is byte-identical to the first: it
    can only fail again, with the very same error value. Skipping it is
    therefore observationally equivalent (round 1 propagated the second
    call's error, which IS [e]) and removes the doubling.

    Cost, exactly. Let [Z d] be one [infer] at mode [Zero] over a chain
    of [d] matches nested in SCRUTINEE position, and [A d] the same at an
    ambient [Many]. At [Zero] the fallback is skipped, so
    [Z d = Z (d-1) + O(1) = O(d)], one linear pass. At [Many] each level
    runs the ambient recursion once and, only if it failed, ONE linear
    [Zero] pass over the same subterm: [A d = A (d-1) + Z (d-1) + O(1)],
    hence [A d = O(d^2)]. Polynomial at every ambient mode, never
    [2^d]. A mode below the top can only be [Zero] (quantity
    multiplication never raises a mode), so no third case exists.
    Pinned by PASS-M4FIX-NEST-ILL (missing branch, depth 26) and
    PASS-M4FIX-NEST-NOMOTIVE (motive-less, depth 26), both under a
    watchdog.

    M4 fixes round 4 (ctxcat r4 id 3), the SOUNDNESS narrowing. Rounds
    1 to 3 took the [Zero] fallback on ANY ambient failure, so it
    forgave more than the one error class it exists for. The class it
    exists for is [Erased_use]: the whole point of the fallback is that
    an ERASED HYPOTHESIS may be a match scrutinee even at a runtime
    ambient mode, because a subsingleton family carries no runtime bit
    (the prelude's own [exfalso] and [subst0] are exactly this shape).
    Mode reaches [infer] in two rules, and they raise two DIFFERENT
    errors: the [Var] rule raises [Erased_use], and the [Global] rule
    raises [Axiom_runtime_use]. Forgiving both let an AXIOM be
    laundered past its own rule: with [axiom ff : Empty] in scope,
    [def boom : Nat := match ff with end] failed the ambient mode with
    [Axiom_runtime_use], took the fallback, found [Empty] subsingleton
    ([Global.Complete []]), was stamped [scrut_q = Zero] and became a
    runtime [Nat] whose erased body is [Eterm.EErased] (measured on the
    round-3 binary: [eval boom] prints [<erased>], and
    [eval (add boom (succ zero))] prints [((add <erased>) (succ zero))],
    an erasure marker inside a [Many]-quantity computation). The
    fallback is therefore GUARDED on [Error.is_erased_use]: every other
    ambient error, [Axiom_runtime_use] above all, propagates unchanged
    and never reaches the subsingleton allowance. Pinned positive by
    PASS-M4FIX-ABSURD (the legitimate erased-hypothesis absurd
    elimination) and negative by PASS-M4FIX-AXIOM-EMPTY.

    SCOPE, stated honestly: this restores the ambient mode's own verdict;
    it does not make an inconsistent axiom set consistent. [axiom ff :
    Empty] still inhabits [Empty], and the prelude's [exfalso] takes its
    [Empty] at quantity 0, so [def boom6 : Nat := exfalso Nat ff] checks
    and evaluates to [<erased>] before and after this fix. That is the
    SANCTIONED quantity-0 route, the one [--no-axioms] exists to switch
    off; what round 4 closes is the checker overriding its OWN
    runtime-quantity verdict. *)
and match_scrut (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (scrut : Term.t) :
    (Term.t * Quantity.t * string * Value.t list * Value.t list * string list, Error.t) result
    =
  let* s0, s_ty, ambient_err =
    infer globals ctx mode scrut
    |> Result.fold
         ~ok:(fun (s, ty) -> Ok (s, ty, None))
         ~error:(fun e ->
           match () with
           | () when Quantity.equal mode Quantity.Zero -> Error e
           | () when not (Error.is_erased_use e) -> Error e
           | () ->
               let* s_zero, zero_ty = infer globals ctx Quantity.Zero scrut in
               Ok (s_zero, zero_ty, Some e))
  in
  match s_ty with
  | Value.VInd (iname, avals) ->
      let* ind =
        Global.find_ind iname globals
        |> Option.to_result ~none:(Error.Not_inductive (pp_goal globals ctx.size s_ty))
      in
      let n_params = List.length ind.Global.params in
      let n_indices = List.length ind.Global.indices in
      (* an applied arity disagreeing with the former's own telescope is
         not a well-formed value of that type, whatever the constructor
         status (M2 fixes Round 3's S3 rule, widened by the index count);
         checked FIRST, before the constructor-status dispatch below. *)
      if not (Int.equal (List.length avals) (n_params + n_indices)) then
        Error (Error.Not_inductive (pp_goal globals ctx.size s_ty))
      else
        let p_vals = List.filteri (fun j _v -> j < n_params) avals in
        let ivals = List.filteri (fun j _v -> j >= n_params) avals in
        (match ind.Global.ctors with
        | Global.Provisional -> Error (Error.Ind_incomplete iname)
        | Global.Builtin -> Error (Error.Builtin_not_eliminable iname)
        | Global.Complete ctor_names ->
            let* scrut_q =
              if zero_eliminable globals ind then Ok Quantity.Zero
              else
                (* not subsingleton: the ambient mode's verdict stands,
                   so an ambient failure is the error, unchanged from the
                   staged second pass.  The stamp is the LITERAL [Many],
                   never [mode] (dev/M4-PLAN.md A6.4, ratified: "the
                   non-subsingleton stamp is Many, NOT the ambient mode
                   ... the alternative rejected: stamping the ambient
                   mode, which would let a mode-Zero match on a
                   two-constructor family carry scrut_q = Zero and reach
                   the Zero erasure arm through a Lam Zero walk").  M4
                   fixes round 2 (ctxcat id 1) proposed [Ok mode] here;
                   refuted by design. *)
                ambient_err |> Option.fold ~none:(Ok Quantity.Many) ~some:(fun e -> Error e)
            in
            Ok (s0, scrut_q, iname, p_vals, ivals, ctor_names))
  | Value.VUniv _
  | Value.VPi (_, _, _, _)
  | Value.VLam (_, _)
  | Value.VCtor (_, _)
  | Value.VNeutral (_, _)
  | Value.VLit _ ->
      Error (Error.Not_inductive (pp_goal globals ctx.size s_ty))

(** Walk the declared ctor names and the user's branches together, in
    declaration order. [expected_of] gives each branch body's expected
    type from the ctor name and its fresh argument values. Branch binder
    names come from the user's pattern; quantities from the telescope. *)
and check_branches (globals : Global.t) (ctx : ctx) (mode : Quantity.t)
    ~(p_vals : Value.t list)
    ~(expected_of : string -> Value.t list -> Value.t list -> (Value.t, Error.t) result)
    (ctor_names : string list)
    (branches : (string * (Quantity.t * string) list * Term.t) list) :
    ((string * (Quantity.t * string) list * Term.t) list, Error.t) result =
  match (ctor_names, branches) with
  | [], [] -> Ok []
  | c :: _, [] -> Error (Error.Branch_mismatch { expected = c; found = "<none>" })
  | [], (b, _binders, _body) :: _ ->
      Error (Error.Branch_mismatch { expected = "<none>"; found = b })
  | c :: cs, (b, pat_binders, body) :: bs ->
      (match () with
      | () when not (String.equal c b) ->
          Error (Error.Branch_mismatch { expected = c; found = b })
      | () ->
          let* ctor =
            Global.find_ctor c globals |> Option.to_result ~none:(Error.Unbound_global c)
          in
          let* bctx, rev_fresh, rev_binders, tele_env =
            walk_telescope globals ctx c (List.rev p_vals) [] [] ctor.Global.args
              pat_binders
          in
          let fresh_args = List.rev rev_fresh in
          let binders' = List.rev rev_binders in
          let* expected_body = expected_of c fresh_args tele_env in
          let* body' = check globals bctx mode body expected_body in
          let* rest = check_branches globals ctx mode ~p_vals ~expected_of cs bs in
          Ok ((c, binders', body') :: rest))

(** Bind one branch's pattern variables at the ctor telescope's types.
    [tele_env] evaluates each telescope type: it starts at the reversed
    parameter values and grows one fresh var per binder. Accumulators are
    newest first. M4 Stage A: returns the FINAL [tele_env] too (its
    binder logic is otherwise untouched, since indices add no branch
    binders); it is exactly the right environment to evaluate the ctor's
    own [res_idx] terms in, since both are scoped under params ++ args in
    the same order. *)
and walk_telescope (globals : Global.t) (bctx : ctx) (cname : string)
    (tele_env : Value.t list) (rev_fresh : Value.t list)
    (rev_binders : (Quantity.t * string) list) (tele : Global.telescope)
    (pats : (Quantity.t * string) list) :
    (ctx * Value.t list * (Quantity.t * string) list * Value.t list, Error.t) result =
  match (tele, pats) with
  | [], [] -> Ok (bctx, rev_fresh, rev_binders, tele_env)
  | _ :: _, [] | [], _ :: _ ->
      Error
        (Error.Branch_mismatch { expected = cname; found = cname ^ " (wrong pattern arity)" })
  | (q, _tname, ty) :: tele', (_uq, u) :: pats' ->
      let* ty_v = Eval.eval globals tele_env ty in
      let fresh = Value.var bctx.size in
      walk_telescope globals (bind u q ty_v bctx) cname (fresh :: tele_env)
        (fresh :: rev_fresh) ((q, u) :: rev_binders) tele' pats'

(** The one [Duplicate_global] fence, shared by [define], [define_prim],
    [declare_ind] and [define_ind]'s ctor loop (M3 fixes round 3,
    ctxcat id 4: previously four verbatim copies of the same lookup
    match). *)
let ensure_fresh (globals : Global.t) (name : string) : (unit, Error.t) result =
  Global.find name globals
  |> Option.fold ~none:(Ok ()) ~some:(fun _entry -> Error (Error.Duplicate_global name))

(** [stamped_ty] (M4 fixes round 1, ctxcat id 9) lets a caller that has
    ALREADY elaborated [ty] hand in that artifact instead of paying for a
    second, independent elaboration whose agreement with the first rests
    on an unstated determinism assumption.  Precondition, and the only
    caller ([define_instance]) meets it: [stamped_ty] is
    [infer_univ globals empty_ctx ty]'s own output term, for this same
    [globals] and this same [ty].  Absent it, nothing changes. *)
let define ?(rec_ = false) ?(partial = false) ?(stamped_ty : Term.t option)
    (globals : Global.t) ~(name : string) ~(reducible : bool) ~(ty : Term.t) ~(def : Term.t) :
    (Global.t, Error.t) result =
  let* () = ensure_fresh globals name in
  (* M3 Stage C: [partial] is always opaque to conversion, so it can
     never also be [reducible] (decision 10 of the M3 design
     verdict); checked before touching [ty] at all. *)
  let* () =
    if partial && reducible then Error (Error.Partial_reducible_conflict name) else Ok ()
  in
  (* the thunk keeps [infer_univ] off the [stamped_ty = Some _] path:
     [Option.fold]'s [~none] argument is EAGER. *)
  let* ty' =
    (stamped_ty
    |> Option.fold
         ~none:(fun () -> Result.map fst (infer_univ globals empty_ctx ty))
         ~some:(fun (t : Term.t) () -> Ok t))
      ()
  in
  let* ty_v = Eval.eval globals [] ty' in
  let* () =
    if reducible && is_effect_headed ty_v then Error (Error.Effect_def_reducible name)
    else Ok ()
  in
  (* M3 Stage C: a [partial] def's codomain (after peeling its
     leading Pi telescope) must have head [Div]; [partial] is the
     one sanctioned way to reach [Div] from tot source (decision
     10).  M3 fixes, C4' (C2, 2026-09-01): when the type has NO
     leading Pi (a non-function partial def, whole type [Div A]),
     [peel_codomain]'s base case would just repeat the [Eval.eval]
     that produced [ty_v] above; reuse [ty_v] instead. *)
  let* () =
    if partial then
      let* codomain_v =
        match ty' with
        | Term.Pi (_, _, _, _) -> peel_codomain globals [] 0 ty'
        | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto
        | Term.Lam (_, _, _)
        | Term.App (_, _, _)
        | Term.Let (_, _, _, _)
        | Term.Ann (_, _)
        | Term.Global _ | Term.Match _ -> Ok ty_v
      in
      if is_div_headed codomain_v then Ok () else Error (Error.Partial_not_div name)
    else Ok ()
  in
  if rec_ then
    (* the recursive global is opaque while its own body is checked:
       the provisional entry never unfolds, so recursive calls stay
       neutral during checking. [reducible = false] and [rec_arg =
       None] stay deliberately conservative placeholders; [partial]
       carries the def's REAL flag (M3 fixes round 2, ctxcat id 6:
       no current consumer reads [partial] off a global during body
       checking -- [Eval.eval] consults only [rec_arg]/[reducible]/
       [def] -- but a future one must never see a wrong value). *)
    let provisional =
      Global.add name
        (Global.Def
           {
             Global.ty = ty';
             def = Term.Global name;
             reducible = false;
             rec_arg = None;
             partial;
           })
        globals
    in
    let* def' = check provisional empty_ctx Quantity.Many def ty_v in
    (* a body with NO occurrence of its own name is not recursive at
       all: skip the structural guard entirely (it would otherwise
       be vacuously satisfied at the first formal, k = 0) and behave
       exactly like a plain def. [partial] skips the guard
       unconditionally instead (M3 Stage C, decision 10): its
       self-reference stays unguarded at both conversion time
       (never reducible, so never unfolded during checking) and
       runtime (ordinary, potentially-non-terminating recursion,
       exactly matching its [Div]-headed codomain). *)
    let* rec_arg =
      if partial then Ok None
      else if Totality.mentions name def' then
        Result.map Option.some (Totality.guard ~recname:name def')
      else Ok None
    in
    Ok
      (Global.add name
         (Global.Def { Global.ty = ty'; def = def'; reducible; rec_arg; partial })
         globals)
  else
    let* def' = check globals empty_ctx Quantity.Many def ty_v in
    (* the entry stores the STAMPED type and definition *)
    Ok
      (Global.add name
         (Global.Def { Global.ty = ty'; def = def'; reducible; rec_arg = None; partial })
         globals)

(** Extend the environment with a native prim (M3 Stage A). The only
    public way to grow [Global.t] with a [Prim] entry. It does NOT check
    that [Prim.arity prim] agrees with [ty]; a catalog-level test does
    that instead. *)
let define_prim (globals : Global.t) ~(name : string) ~(ty : Term.t) ~(prim : Prim.t) :
    (Global.t, Error.t) result =
  let* () = ensure_fresh globals name in
  let* ty', _ty_l = infer_univ globals empty_ctx ty in
  Ok (Global.add name (Global.Prim { Global.prim_ty = ty'; prim }) globals)

(** Extend the environment with a postulated statement (M4 Stage B). The
    only public way to grow [Global.t] with an [Axiom] entry: [ty]
    validates and stamps exactly like [define_prim]'s, and the stored
    entry carries no runtime body at all, so an axiom is confined to
    quantity 0 by [infer]'s own [Term.Global] guard above, never by
    anything here. *)
let define_axiom (globals : Global.t) ~(name : string) ~(ty : Term.t) :
    (Global.t, Error.t) result =
  let* () = ensure_fresh globals name in
  let* ty', _ty_l = infer_univ globals empty_ctx ty in
  Ok (Global.add name (Global.Axiom { Global.ax_ty = ty' }) globals)

(** M4 Stage D (D2): [true] iff [c] is a declared inductive with exactly
    one parameter and no indices -- the shape every class (the dictionary
    former) and every instance key must have. *)
let single_param_no_index (globals : Global.t) (c : string) : bool =
  Global.find_ind c globals
  |> Option.fold ~none:false ~some:(fun (ind : Global.ind_entry) ->
         Int.equal (List.length ind.Global.params) 1 && Int.equal (List.length ind.Global.indices) 0)

(** M4 Stage D (D2): validate [define_instance]'s registration shape on
    the STAMPED type [ty].  Peels the leading Pi telescope, classifying
    each domain as a type binder ([Univ _]) or a single-parameter,
    no-index class applied to an EARLIER type binder (a "dictionary
    binder");  the codomain must be [C (K a1 .. ak)] (or the ground
    [C K] when [k = 0]), with [C] and [K] both single-parameter,
    no-index inductives and [a1 .. ak] the recorded type binders IN
    DECLARATION order.  Recomputes the mangled name from [C] and [K] and
    requires it to equal [name], closing the gap between a name computed
    from the surface spelling and the checked type.  A ground instance
    at an APPLIED key (e.g. [EqD (List Int)] with no type binders) is
    rejected here too: the key-argument COUNT check fails against zero
    recorded type binders, so every key has exactly one derivation
    route. [positions_match] is hand-rolled (not [List.for_all2], which
    raises on a length mismatch) even though its own caller already
    proved the two lists equal length; its own base/mismatch arms are a
    total backstop, never actually reached. *)
let validate_instance_shape (globals : Global.t) ~(name : string) (ty : Term.t) :
    (unit, Error.t) result =
  let bad (reason : string) : (unit, Error.t) result =
    Error (Error.Inst_bad_shape { name; reason })
  in
  let is_univ (t : Term.t) : bool =
    match t with
    | Term.Univ _ -> true
    | Term.Var _ | Term.Pi (_, _, _, _)
    | Term.Lam (_, _, _)
    | Term.App (_, _, _)
    | Term.Let (_, _, _, _)
    | Term.Ann (_, _)
    | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
        false
  in
  (* [dom] is [C_j (Var j)] for a single-parameter, no-index [C_j] and an
     earlier type binder [j] ([expected_var] maps a peel POSITION to the
     de Bruijn index it has at the CURRENT depth). *)
  let is_dict_binder (type_positions : int list) (depth : int) (dom : Term.t) : bool =
    let expected_var (p : int) : int = depth - 1 - p in
    match dom with
    | Term.App (_q, Term.Global c_j, arg) -> (
        match arg with
        | Term.Var j ->
            single_param_no_index globals c_j
            && List.exists (fun p -> Int.equal j (expected_var p)) type_positions
        | Term.Univ _ | Term.Pi (_, _, _, _)
        | Term.Lam (_, _, _)
        | Term.App (_, _, _)
        | Term.Let (_, _, _, _)
        | Term.Ann (_, _)
        | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
            false)
    | Term.App
        ( _,
          ( Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _) | Term.Lam (_, _, _) | Term.App (_, _, _)
          | Term.Let (_, _, _, _) | Term.Ann (_, _) | Term.Lit _ | Term.Auto | Term.Match _ ),
          _ )
    | Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _)
    | Term.Lam (_, _, _)
    | Term.Let (_, _, _, _)
    | Term.Ann (_, _)
    | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
        false
  in
  let rec peel (depth : int) (type_positions : int list) (t : Term.t) :
      (int * int list * Term.t, Error.t) result =
    match t with
    | Term.Pi (_q, _x, dom, cod) -> (
        match () with
        | () when is_univ dom -> peel (depth + 1) (type_positions @ [ depth ]) cod
        | () when is_dict_binder type_positions depth dom -> peel (depth + 1) type_positions cod
        | () ->
            Error
              (Error.Inst_bad_shape
                 {
                   name;
                   reason = "instance domain is neither a type binder nor a single-parameter class";
                 }))
    | Term.Var _ | Term.Univ _ | Term.Lam (_, _, _)
    | Term.App (_, _, _)
    | Term.Let (_, _, _, _)
    | Term.Ann (_, _)
    | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
        Ok (depth, type_positions, t)
  in
  let rec key_spine (t : Term.t) (args : Term.t list) : Term.t * Term.t list =
    match t with
    | Term.App (_, f, a) -> key_spine f (a :: args)
    | Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _)
    | Term.Lam (_, _, _)
    | Term.Let (_, _, _, _)
    | Term.Ann (_, _)
    | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
        (t, args)
  in
  let* depth, type_positions, codomain = peel 0 [] ty in
  let expected_var (p : int) : int = depth - 1 - p in
  let rec positions_match (ps : int list) (args : Term.t list) : bool =
    match (ps, args) with
    | [], [] -> true
    | p :: ps', a :: args' -> (
        match a with
        | Term.Var j -> Int.equal j (expected_var p) && positions_match ps' args'
        | Term.Univ _ | Term.Pi (_, _, _, _)
        | Term.Lam (_, _, _)
        | Term.App (_, _, _)
        | Term.Let (_, _, _, _)
        | Term.Ann (_, _)
        | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
            false)
    | [], _ :: _ | _ :: _, [] -> false
  in
  match codomain with
  | Term.App (_q, Term.Global c_name, karg) -> (
      let* () =
        if single_param_no_index globals c_name then Ok ()
        else bad "instance codomain head is not a single-parameter class"
      in
      match key_spine karg [] with
      | Term.Global k_name, kargs -> (
          let* () =
            if Int.equal (List.length kargs) (List.length type_positions) then Ok ()
            else bad "instance key is not applied to exactly its type binders"
          in
          let* () =
            if positions_match type_positions kargs then Ok ()
            else bad "instance key arguments are not the type binders in order"
          in
          let* () =
            Global.find_ind k_name globals
            |> Option.fold
                 ~none:(bad "instance key is not a declared inductive")
                 ~some:(fun (ind : Global.ind_entry) ->
                   if
                     Int.equal (List.length ind.Global.params) (List.length kargs)
                     && Int.equal (List.length ind.Global.indices) 0
                   then Ok ()
                   else bad "instance key's parameter count does not match its application")
          in
          let mangled = "inst$" ^ c_name ^ "$" ^ k_name in
          if String.equal mangled name then Ok () else bad ("instance name does not match " ^ mangled))
      | ( ( Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _)
          | Term.Lam (_, _, _)
          | Term.App (_, _, _)
          | Term.Let (_, _, _, _)
          | Term.Ann (_, _)
          | Term.Lit _ | Term.Auto | Term.Match _ ),
          (_ : Term.t list) ) ->
          bad "instance key is not a declared inductive")
  | Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _)
  | Term.Lam (_, _, _)
  | Term.App
      ( _,
        ( Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _) | Term.Lam (_, _, _) | Term.App (_, _, _)
        | Term.Let (_, _, _, _) | Term.Ann (_, _) | Term.Lit _ | Term.Auto | Term.Match _ ),
        _ )
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
      bad "instance codomain must be a class applied to a key"

(** M4 Stage D (D2): register an instance under its mangled name.
    Validates the STAMPED type's registration shape BEFORE calling
    [define], which performs the actual coherence check
    ([ensure_fresh]):  a second instance at the same key is
    [Duplicate_global], exactly like any other duplicate global;  there
    is no separate class-coherence kernel state.  Instances are forced
    [reducible = true]:  they are small constructor values, and proofs
    about method calls want them to compute. *)
let define_instance (globals : Global.t) ~(name : string) ~(ty : Term.t) ~(def : Term.t) :
    (Global.t, Error.t) result =
  let* ty', _ty_l = infer_univ globals empty_ctx ty in
  let* () = validate_instance_shape globals ~name ty' in
  (* M4 fixes round 1 (ctxcat id 9): install the very artifact the shape
     validator just accepted, rather than a second elaboration of the
     same source type that agrees with it only by determinism. *)
  define ~reducible:true ~stamped_ty:ty' globals ~name ~ty ~def

(** Declare an inductive's name, parameters and level. Constructors arrive
    separately via [define_ind] so their types can mention the inductive. *)
(** Shared implementation of [declare_ind] and [declare_builtin]: check
    the params exactly as before, then fold the index telescope under the
    params context. Per index binder: quantity must be [Zero]
    ([Index_not_zero]), and its inferred level must be [Level.le] the
    declared [level] ([Index_above_universe]). This [Level.le] bound on
    index TYPES is conservative (Agda exempts index types from the
    predicative bound, probably soundly here too since no constructor
    field ever stores an index); it costs [Eq]/[Vec]/[Fin] nothing and
    keeps the soundness argument one sentence long, so it ships (SPEC.md
    section 6 debt). [status] is the caller's choice of initial
    [Global.ctor_status]: [Provisional] for an ordinary [declare_ind],
    [Builtin] for [declare_builtin]. *)
let declare_ind_status (globals : Global.t) ~(name : string) ~(params : Global.telescope)
    ~(indices : Global.telescope) ~(level : Level.t) ~(status : Global.ctor_status) :
    (Global.t, Error.t) result =
  let* () = ensure_fresh globals name in
  let* pctx, rev_params_stamped =
    List.fold_left
      (fun acc (q, x, ty) ->
        let* ctx, rev_acc = acc in
        let* ty', _l = infer_univ globals ctx ty in
        let* ty_v = Eval.eval globals ctx.env ty' in
        Ok (bind x q ty_v ctx, (q, x, ty') :: rev_acc))
      (Ok (empty_ctx, []))
      params
  in
  let params_stamped = List.rev rev_params_stamped in
  let* _ictx, rev_indices_stamped =
    List.fold_left
      (fun acc (q, x, ty) ->
        let* ctx, rev_acc = acc in
        let* () = if Quantity.equal q Quantity.Zero then Ok () else Error (Error.Index_not_zero name) in
        let* ty', l = infer_univ globals ctx ty in
        let* () =
          if Level.le l level then Ok ()
          else Error (Error.Index_above_universe { ind = name; index = x })
        in
        let* ty_v = Eval.eval globals ctx.env ty' in
        Ok (bind x q ty_v ctx, (q, x, ty') :: rev_acc))
      (Ok (pctx, []))
      indices
  in
  let indices_stamped = List.rev rev_indices_stamped in
  let closed =
    List.fold_right
      (fun (q, x, ty) acc -> Term.Pi (q, x, ty, acc))
      params_stamped
      (List.fold_right (fun (q, x, ty) acc -> Term.Pi (q, x, ty, acc)) indices_stamped
         (Term.Univ level))
  in
  Ok
    (Global.add name
       (Global.Ind
          {
            Global.ind_ty = closed;
            params = params_stamped;
            indices = indices_stamped;
            level;
            ctors = status;
          })
       globals)

(** Declare an inductive's name, parameters, index telescope and level.
    Constructors arrive separately via [define_ind] so their types can
    mention the inductive. [indices] is REQUIRED (not optional with a
    [] default), so every existing call site is visited by the
    compiler. *)
let declare_ind (globals : Global.t) ~(name : string) ~(params : Global.telescope)
    ~(indices : Global.telescope) ~(level : Level.t) : (Global.t, Error.t) result =
  declare_ind_status globals ~name ~params ~indices ~level ~status:Global.Provisional

(** M4 Stage A: the bootstrap-only entry point for a type former that
    will NEVER be [define_ind]'d (String, Int, Div, IO). Same as
    [declare_ind ~indices:[]], except the stored status is [Builtin]:
    [define_ind] on a [Builtin] inductive is [Ind_redefined], and a match
    on one is [Builtin_not_eliminable] rather than [Ind_incomplete]. *)
let declare_builtin (globals : Global.t) ~(name : string) ~(params : Global.telescope) :
    (Global.t, Error.t) result =
  declare_ind_status globals ~name ~params ~indices:[] ~level:Level.zero ~status:Global.Builtin

(** Check and install the constructors of an already-declared inductive.
    Enforces the result-head rule, strict positivity with uniform
    parameters, and the predicative universe bound. On any error the
    caller keeps its pre-declaration globals. *)
let define_ind (globals : Global.t) ~(name : string) ~(ctors : (string * Term.t) list) :
    (Global.t, Error.t) result =
  let* ind =
    Global.find_ind name globals |> Option.to_result ~none:(Error.Unbound_global name)
  in
  let* () =
    match ind.Global.ctors with
    | Global.Provisional -> Ok ()
    | Global.Builtin -> Error (Error.Ind_redefined name)
    | Global.Complete _names -> Error (Error.Ind_redefined name)
  in
  let n_params = List.length ind.Global.params in
  let n_indices = List.length ind.Global.indices in
  (* the params ctx every ctor type was elaborated in; indices are NOT in
     scope here (a constructor supplies its own concrete index VALUES
     through its result type; the family's own index binder names never
     appear inside a constructor's own telescope) *)
  let* pctx =
    List.fold_left
      (fun acc (q, x, ty) ->
        let* ctx = acc in
        let* ty_v = Eval.eval globals ctx.env ty in
        Ok (bind x q ty_v ctx))
      (Ok empty_ctx) ind.Global.params
  in
  (* [no_occur]/[index_expr_clean] closed over this [name]; see their
     top-level definitions above [zero_eliminable] for the reachability
     argument. *)
  let no_occur (t : Term.t) : bool = no_occur name t in
  let index_expr_clean (e : Term.t) : bool = index_expr_clean name e in
  (* [name] applied to exactly its parameter variables in order, then to
     [n_indices] index expressions none of which mention [name]. Seen
     under [depth] binders below the parameters. *)
  let is_applied (depth : int) (t : Term.t) : bool =
    (* M4 fixes round 1 (ctxcat id 8): the RAW type this now runs on may
       carry [Term.Ann] wrappers that [infer] would have deleted, so
       strip them off the head here and off each PARAMETER-position
       argument below. Index positions keep the un-stripped argument, so
       [index_expr_clean] still inspects an annotation's TYPE half for
       occurrences of the family. Identity on stamped terms.

       M4 fixes round 2 (opus R3): [Totality.spine] unwinds [App] nodes
       without stripping, so an annotation sitting on the spine's own
       HEAD (`(AVec : (0 n : Nat) -> Type 0) zero`) survived the outer
       [strip_ann] and left [head_ok] false, rejecting a codomain the
       elaborator itself accepts in every other position. Strip the head
       the spine returns as well;  still identity on stamped terms, and
       still local to this function, so [Totality.spine]'s shared walk
       is untouched. *)
    let raw_head, sp = Totality.spine (strip_ann t) [] in
    let head = strip_ann raw_head in
    let head_ok =
      match head with
      | Term.Global g -> String.equal g name
      | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto
      | Term.Pi (_, _, _, _)
      | Term.Lam (_, _, _)
      | Term.App (_, _, _)
      | Term.Let (_, _, _, _)
      | Term.Ann (_, _)
      | Term.Match _ ->
          false
    in
    head_ok
    && Int.equal (List.length sp) (n_params + n_indices)
    && List.mapi (fun j arg -> (j, arg)) sp
       |> List.for_all (fun (j, arg) ->
              match () with
              | () when j >= n_params -> index_expr_clean arg
              | () ->
                  (match strip_ann arg with
                  | Term.Var ix -> Int.equal ix (depth + n_params - 1 - j)
                  | Term.Univ _ | Term.Lit _ | Term.Auto
                  | Term.Pi (_, _, _, _)
                  | Term.Lam (_, _, _)
                  | Term.App (_, _, _)
                  | Term.Let (_, _, _, _)
                  | Term.Ann (_, _)
                  | Term.Global _ | Term.Match _ ->
                      false))
  in
  (* strict positivity: no occurrence at all, or exactly the applied form,
     possibly as the codomain of a Pi telescope whose domains never
     mention the name *)
  let rec strict_pos (depth : int) (t : Term.t) : bool =
    match () with
    | () when no_occur t -> true
    | () ->
        (match t with
        | Term.Pi (_q, _x, dom, cod) -> no_occur dom && strict_pos (depth + 1) cod
        | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto
        | Term.Lam (_, _, _)
        | Term.App (_, _, _)
        | Term.Let (_, _, _, _)
        | Term.Ann (_, _)
        | Term.Global _ | Term.Match _ ->
            is_applied depth t)
  in
  (* M4 fixes round 1 (ctxcat id 8): peel through a [Term.Ann] wrapper
     too, so an annotated telescope (`| mk : ((A : Type 0) -> Foo A :
     Type 0)`) still yields its binders on the RAW pass. The returned
     codomain stays the ORIGINAL node; [is_applied] strips it itself.
     [strip_ann] is the identity on stamped terms, so the elaborated
     call below is unchanged. *)
  let rec strip_pis (acc : Global.telescope) (t : Term.t) : Global.telescope * Term.t =
    match strip_ann t with
    | Term.Pi (q, x, dom, cod) -> strip_pis ((q, x, dom) :: acc) cod
    | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto
    | Term.Lam (_, _, _)
    | Term.App (_, _, _)
    | Term.Let (_, _, _, _)
    | Term.Ann (_, _)
    | Term.Global _ | Term.Match _ ->
        (List.rev acc, t)
  in
  (* M4 fixes round 5 (ctxcat r5 id 1): "1 index expression", not
     "1 index expression(s)".  A one-index family is the common case
     ([Vec] has exactly one), so the parenthesised plural was the shape
     the reader saw most often. *)
  let bad_ctor_result_reason : string =
    "constructor must end in " ^ name ^ " applied to its parameters and "
    ^ string_of_int n_indices
    ^ if Int.equal n_indices 1 then " index expression" else " index expressions"
  in
  let* globals' =
    List.fold_left
      (fun acc (cname, cty) ->
        let* gacc = acc in
        let* () = ensure_fresh gacc cname in
        (* M4 Stage A: check the result-head shape (arity, then per-
           position parameter/index expression) on the RAW ctor type
           FIRST, before elaboration. An under- or over-applied family
           reference does not even have kind Type (a partially-applied
           type former's own type is a further Pi, never Univ), so
           running [infer_univ] on the whole malformed type first would
           report a kind error one layer too late (Not_a_universe /
           Not_a_function) instead of this precise, index-count-aware
           diagnosis. Structural inspection (Var/Global/App/Pi shape,
           which is all [is_applied] and [strip_pis] consult) is
           IDENTICAL whether the term is raw or already stamped: [infer]
           never changes a [Var]'s index, a [Global]'s name, or a [Pi]'s
           own quantity, so reusing [args]/[cod] from the STAMPED type
           just below for the per-argument walk is sound. *)
        let raw_args, raw_cod = strip_pis [] cty in
        let* () =
          if is_applied (List.length raw_args) raw_cod then Ok ()
          else Error (Error.Bad_ctor { ctor = cname; reason = bad_ctor_result_reason })
        in
        let* cty', _cty_l = infer_univ gacc pctx cty in
        let args, cod = strip_pis [] cty' in
        (* per argument: positivity at its own base depth, then the
           predicative universe bound *)
        let* _actx, _n_args =
          List.fold_left
            (fun aacc (q, x, ty) ->
              let* actx, i = aacc in
              let* () =
                if strict_pos i ty then Ok ()
                else
                  Error
                    (Error.Bad_ctor
                       { ctor = cname; reason = "negative or non-uniform occurrence of " ^ name })
              in
              let* ty2, l = infer_univ gacc actx ty in
              let* () =
                if Level.le l ind.Global.level then Ok ()
                else
                  Error
                    (Error.Bad_ctor
                       {
                         ctor = cname;
                         reason = "constructor argument lives above the declared universe";
                       })
              in
              let* ty_v = Eval.eval gacc actx.env ty2 in
              Ok (bind x q ty_v actx, i + 1))
            (Ok (pctx, 0))
            args
        in
        (* M4 Stage A: the codomain spine, dropped of its first n_params
           entries, is this constructor's own [res_idx], scoped under
           params ++ args, exactly matching [walk_telescope]'s final
           [tele_env]. *)
        let _head, sp = Totality.spine cod [] in
        let res_idx = List.filteri (fun j _a -> j >= n_params) sp in
        let full_arity = n_params + List.length args in
        let self_rec = List.exists (fun (_q, _x, ty) -> Totality.mentions name ty) args in
        (* parameters are ALWAYS quantity-0 in the closed constructor type:
           at applications the param args erase *)
        let closed =
          List.fold_right
            (fun (_q, x, ty) acc2 -> Term.Pi (Quantity.Zero, x, ty, acc2))
            ind.Global.params
            (List.fold_right (fun (q, x, ty) acc2 -> Term.Pi (q, x, ty, acc2)) args cod)
        in
        Ok
          (Global.add cname
             (Global.Ctor { Global.ctor_ty = closed; ind = name; args; res_idx; full_arity; self_rec })
             gacc))
      (Ok globals) ctors
  in
  let ctor_names = List.map (fun (c, _cty) -> c) ctors in
  Ok (Global.add name (Global.Ind { ind with Global.ctors = Global.Complete ctor_names }) globals')
