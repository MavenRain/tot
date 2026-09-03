# tot: design record

Working name: `tot` (total).  Rename is a find/replace away.

## 1.  Purpose

One language for everyday automation: PreToolUse hooks, gate scripts,
verdict CLIs, small tools.  The house rules are the semantics:

- No exceptions.  Errors are values (`Option`, `Result`, error variants).
- Total by default.  Every hook terminates;  the checker proves it.
- No loop keywords.  Recursion and combinators only.
- Exhaustive matches.  No catch-all arms.
- Partial operations (indexing, division) do not exist.  Each one either
  returns an `Option` or demands a proof.
- A hook is a typed value indexed by its JSON schema and its permitted
  exit codes.  A guard that typechecks cannot emit garbage.

## 2.  Decision log

- 2026-08-31: goal triangle set: Lean-4-strength types, OCaml-speed
  checking on the ML fragment, OCaml-grade expressiveness.  Uniform speed
  is impossible (conversion runs user code);  pay-as-you-go is the bar.
- 2026-09-01: host language = OCaml (user decision).
- 2026-09-01: kernel-first (user decision).  Small dependent kernel now;
  surface language on top;  no retrofit.
- 2026-09-01: first dogfood target = a PreToolUse guard (user decision).
- 2026-09-01: weak definitional equality.  Globals are opaque by default;
  evaluation unfolds only globals marked reducible;  conversion never
  unfolds on its own.  Predictable check times;  more explicit proofs.
- 2026-09-01: quantities 0/omega (QTT fragment).  Quantity-0 binders erase
  before evaluation.  Full linearity (quantity 1) is deferred.
- 2026-09-01: predicative universe hierarchy, no cumulativity in v0.
  Revisit at M2 if annotation burden is too high.
- 2026-09-01: execution model = erase, then interpret in-process, with a
  content-addressed cache of elaborated modules.  Native codegen is a
  later milestone.
- 2026-09-01: surface pins (M1).  `:=` introduces def and let bodies;
  `--` starts a line comment;  quantity markers are `0` and `w`, where
  `(w x : A)` marks quantity only when another identifier follows the
  `w` (so `(w : A)` is a binder actually NAMED `w`);  `A -> B` is sugar
  for `(w _ : A) -> B`;  bare `Type` defaults to level 0;  chained binder
  groups before one arrow (`(a : A) (b : B) -> C`) are not supported in
  v0, each group needs its own `->`.
- 2026-09-01: erasure pin (M1).  Type-directed single pass mirroring
  `Check`'s bidirectional shape;  no conversion checks, types are
  consulted only for Pi quantities.  Quantities are NOT stamped on core
  terms yet;  revisit at M2 when inductives force a `Term` revision.
- 2026-09-01: runtime pin (M1).  Call-by-value over erased terms.  Every
  global unfolds at runtime;  reducibility is a conversion-time notion
  only.  Global values are cached closed at definition time.
- 2026-09-01: items pin (M1).  Scripts are sequences of `def` (optionally
  `reducible`), `check`, and `eval` items.  Check mode prints types;  run
  mode executes `eval` items and prints the readback.
- 2026-09-01 (M2): stamped quantities.  `Term.Lam`/`Term.App` carry a
  `Quantity.t`.  Elaboration and hand-built terms write `w` placeholders;
  the checker OVERWRITES stamps from the Pi it checks against and
  returns the stamped term: checker output is authoritative.  `(t : T)`
  annotations steer checking only: `Ann` is dropped from checker output.
  Erasure is purely structural over stamped terms (no types, no globals
  consulted);  this supersedes the M1 erasure pin.
- 2026-09-01 (M2): inductives.  Parameterized only;  indices deferred to
  M4 (they arrive with `Eq`;  the match motive already abstracts the
  scrutinee, so indices are additive).  Flat namespace: the inductive
  name and every constructor name are globals in the one map (entry
  kinds `Def`/`Ind`/`Ctor`).  Parameters are ALWAYS quantity-0: param
  arguments at constructor applications erase, so runtime constructor
  values carry kept (`w`) args only.  Strict positivity with uniform
  parameters: a constructor argument type may mention the inductive `I`
  only as `I p1..pn` (its own params, in order), either as the whole
  argument type or as the codomain of a Pi telescope whose domains never
  mention `I`;  no nested, no mutual, no local fix in v0.  Predicative
  universe rule: each constructor argument type's level must satisfy
  `Level.le` against the declared level of the inductive.
- 2026-09-01 (M2): recursion.  Top-level `def rec` only.  The recursive
  global is opaque while its own body is checked (recursive calls do not
  unfold);  a structural totality guard must accept the stamped body and
  picks the principal argument first-fit.  Evaluation unfolds a REDUCIBLE
  rec global only when its principal argument is a canonical constructor
  value (guarded unfolding), so conversion cannot diverge;  opaque rec
  globals never unfold in conversion.  The runtime interpreter is
  unaffected (call-by-value on erased terms;  every global unfolds at
  application time).  No eta for inductives: a neutral never equals a
  constructor value.
- 2026-09-01 (M2): surface pins.  `data NAME (0 p : T) .. : Type L := |
  c1 : CT1 | c2 : CT2 ..`;  every parameter group must carry the literal
  `0` marker;  `: Type L` is required (`L` defaults to 0);  zero
  constructors is legal (empty type).  `match S with | c x y => B | ..
  end` with optional `as x return P`;  branch patterns are flat (a ctor
  name plus distinct binder names);  `end` is required;  branches must
  list the constructors exactly in declaration order.  A match in infer
  position needs the explicit motive;  in check position a motive-free
  match reuses the expected type as a constant motive.  Recursive
  definitions: `[reducible] def rec NAME : TY := BODY`.  The checker
  stamps branch binders with the constructor telescope's quantities, so
  erasure stays structural.
- 2026-09-01 (M2): deferred to M3: literals, `String`, `Json`, and
  prelude auto-loading (`stdlib/prelude.tot` is a script you run, not an
  implicit import).
- 2026-09-01 (M2 fixes, Stage A): inductive parameters may live at ANY
  universe;  the declared level bounds constructor ARGUMENTS only.  This
  follows the Coq/Lean precedent: parameters are not fields, so they
  never enter the positivity/universe accounting that bounds a
  constructor's own args.
- 2026-09-01 (M2 fixes, Stage A): `Global.Ind.ctor_names` is
  `string list option`: `None` while an inductive is declared but not
  yet defined (between `declare_ind` and `define_ind`), `Some names`
  once complete.  A reader that needs to eliminate the inductive (a
  match's scrutinee type) rejects a `None` window with `Ind_incomplete`;
  a second `define_ind` call on an already-complete inductive rejects
  with `Ind_redefined` instead of silently overwriting `ctor_names`.
  Closes the window where a constructor argument's own type could
  eliminate its still-declaring inductive with a vacuously exhaustive
  empty match.
- 2026-09-01 (M2 fixes, Stage A): a `def rec` body with NO occurrence of
  its own name skips the structural totality guard entirely and stores
  `rec_arg = None`, behaving exactly like a plain `def` (unfolds in
  conversion when reducible, no guarded-unfolding gate).  Previously
  first-fit was vacuously satisfied at the first formal (k = 0) even
  with zero recursive spine, which could pin `rec_arg` to a
  non-canonical (non-ctor-typed) formal and block unfolding forever.
  This also makes a zero-formal `def rec` with no self-occurrence check
  as a plain def instead of failing `Termination`.
- 2026-09-01 (M2 fixes, Stage A): guarded unfolding's canonical check
  (`Eval.is_canonical`) now means a data constructor FULLY applied
  (parameter arity plus its own args telescope arity, looked up from the
  `Ctor`/`Ind` globals), not merely `VCtor _` regardless of how many
  args it has received.  A partially applied constructor in the
  principal position no longer unlocks a rec global's unfolding.
  `Eval.run_match` also gained an arity backstop (mirroring
  `Interp.run_match`'s existing one): a branch whose binder count
  disagrees with the scrutinee's kept args is `Branch_mismatch` rather
  than a silently misaligned environment.
- 2026-09-01 (M2 fixes, Stage A): check-position matches now
  materialize an explicit constant motive in checker OUTPUT (quoted
  from the expected type, weakened under the extra scrutinee binder by
  NbE de-Bruijn-level quoting) instead of storing `motive = None`.
  Infer position and explicit `as .. return` are unchanged.  This makes
  a motive-free match and an equivalent explicit-motive match produce
  FMatch frames that compare equal in conversion;  previously two
  identically-reducing stuck matches could fail conversion purely by
  spelling (`None` vs `Some` on the motive option).
- 2026-09-01 (M2 fixes, Stage B): runtime guarded unfolding for rec
  globals.  `Interp`'s global table now carries each def's `rec_arg`
  alongside its cached value, and its value domain gains a neutral
  `EHGlobal` head mirroring the kernel's `Value.HGlobal`.  Applying a rec
  global freezes into (or extends) an `EHGlobal` neutral application
  instead of entering its closure until the accumulated frames' leading
  argument at position `rec_arg` is a canonical constructor value: fully
  applied counting only KEPT (quantity-`w`) args, since an erased
  program never carries params or quantity-0 args at runtime (the
  runtime analogue of F4's kernel-level check, over `Eterm`'s already-
  erased arity instead of the kernel's full unerased one).  Once the
  guard is met, the accumulated frames replay onto the def's cached
  closure.  Non-rec globals are unaffected: they still unfold
  unconditionally at application time.  This retires the interp-readback
  debt below: `quote` no longer re-executes a rec global's frozen match
  branches under every fresh binder it peels (which diverged, since
  each peel re-applied the eager closure and froze one level deeper);
  a rec function value now reads back as its frozen neutral
  application, and closed (fully canonical) calls compute exactly as
  before.  (2026-09-01, M2 fixes Round 2, R0): since `rec_arg` counts the
  kernel's UNERASED formal telescope while `Interp`'s spine is ERASED,
  `surface/run.ml` remaps it before calling `Interp.define` by counting
  the quantity-`w` formals strictly before `rec_arg` in the stamped
  def's own `Lam` telescope.  (2026-09-01, M2 fixes Round 4, revising
  Round 3's S0): when the guarded formal is itself quantity-0, the
  runtime spine never carries it, so there is no principal position left
  to test;  the def remaps to `None` (eager unfold, plain-def behavior at
  runtime), never a freeze.  This is SOUND: a quantity-0 formal can only
  be eliminated (matched on) while checking at `Quantity.Zero` mode (the
  same attenuation `Check.infer`'s `Var` rule enforces), so every branch
  of a match on it, and every recursive call reachable through those
  branches, is itself checked at mode `Zero`.  `Erase.term`'s
  `App (Quantity.Zero, f, _a) -> term ctx f` arm drops such a subterm
  WHOLESALE at its use site without walking it, so the ERASED body of a
  rec def guarded on an erased formal contains NO occurrence of the
  def's own global name: eager unfolding cannot loop, and it computes
  the definitionally correct value.  Mechanically confirmed for the
  `ghost` witness (`test/fixtures/s0-erased-guard.tot`) by a kernel-level
  `Eterm.t` walk, `test/main.ml`'s "T0: rec def guarded on an erased
  formal has no self-reference after erasure".  Round 3's S0 text (freeze
  on an out-of-range index) is superseded: that divergence claim had no
  actual witness, and re-verification killed a fresh over-application
  variant of the same claim.  See `dev/M2-FIXES-LOG.md` "## Round 4" for
  the full correction.
- 2026-09-01 (M3): the effect ladder, literals, stdlib breadth, real
  hooks.  Design authority: `tot-m3-design-verdict.md` (M3-SYNTH), the
  judged synthesis of the three M3 design proposals, transcribed into
  `dev/M3-PLAN.md`.  Verdict 3.10's fourteen decisions, transcribed:
  1.  `Term.Pi`, `Lam` and `App` keep their M2 arity.  Effects are types,
     not a stamp.
  2.  `Prim` is a fourth `Global.entry` kind with no `def` and no
     `reducible` field.
  3.  `Prim.t` is a closed enum with a name and arity table, no
     closures, for the sake of the `Marshal` cache.
  4.  `Prim.arity` counts kept arguments only.
  5.  `String`, `Int`, `Div` and `IO` are zero-constructor `Ind`
     bootstrap entries.  `Json`, `ProcessResult`, `Unit`, `Ordering` and
     `Verdict` are ordinary prelude `data` items.
  6.  No `liftDiv`, no `runDiv`.  `Div` is absorbing.
  7.  One elaboration per literal token;  no numeric overloading;  `Nat`
     stays Peano and separate from `Int`.
  8.  `Interp.quote` on `VPrim` rebuilds the spine;  on `VIOAction` it
     returns `Not_quotable`.
  9.  `Check.define` refuses `reducible` on a `Div`-headed or
     `IO`-headed def.
  10.  `def rec` that fails the guard stays a hard error;  `partial` is
      the only way to `Div`, and it forces a `Div`-headed codomain.
  11.  Deferred definition-time execution keys on the def's type head,
      not on a new attribute.
  12.  Every prim carries a one-line comment justifying its ladder
      classification;  `dev/prim-lint.sh` lists the catalog.
  13.  An execution budget for a hung guard is the hook runner's job
      (`timeout` in the shebang wrapper or the calling harness), not
      M3 kernel work.  Recorded as a risk, not built.
  14.  `tot run --no-prelude` exists for kernel tests.

  Three confirmed user decisions (2026-09-01, final):
  1.  **Effect model: monadic reified IO.** `Div` and `IO` are opaque
     zero-constructor type formers.  `Prim` is a fourth `Global.entry`
     kind with no `def` field and no `reducible` field.  Div prims fire
     inline.  IO is reified as an action tree that only `run_io` walks.
     Hooks write `main : IO Verdict` with `let*` sugar and an explicit
     `liftIO` at every Div-to-IO step.
  2.  **Json: self-recursive `data Json` with its own cons cells** in
     the prelude.  No builtin opaque Json.  No nested inductives.
  3.  **Hook protocol: driver-rendered `Verdict`.** `allow` exits 0,
     `ask` exits 1, `deny` exits 2, and the driver renders the JSON
     envelope.  `main : IO Unit` plus an explicit `exitWith` stays legal
     as a second accepted shape.

  Plan-level fill-ins (`dev/M3-PLAN.md`), each with its rationale:
  - Builtin type formers are DECLARED and never DEFINED, so
    `ctor_names` stays `None` and any `match` on `String`, `Int`,
    `Div` or `IO` is `Ind_incomplete`.  This closes the vacuous empty
    match that would otherwise inhabit any type from a `String`
    scrutinee.
  - Integer literals reuse the existing `Nat` token, so the M1 numeric
    cap now bounds int literals as a Lex error.
  - `exitWith` returns an `Exited` outcome through `run_io`;  the single
    process exit stays in `bin/tot.ml`.
  - `intCompare : Int -> Int -> Ordering`, with `Ordering` a prelude
    data type, chosen over an `Int` sentinel.
  - Regex uses OCaml's `Str` dialect, not PCRE, and `str` is linked
    into `tot_kernel` for exactly two prims.
  - The prim catalog is seeded in phases around the prelude fold,
    because prim types mention prelude data types (in the shipped
    build, three phases and three prelude-fold segments, since the
    prelude's own Stage C accessor defs call a phase-2 prim;  recorded
    in `dev/M3-BUILD-LOG.md`).
- 2026-09-01 (M3 fixes, stage A): check mode builds no runtime
  environment for the user file.  The M3 Stage B rule deferred a def
  exactly when its stamped type HEAD was `Div`/`IO`, so a `Div` value
  nested under a pure head (`Option (Div Nat)`) executed, and could
  diverge, under `tot check` (review round 1, O1).  Now
  `surface/run.ml` never calls `Interp.define` for user-file defs in
  check mode;  kernel elaboration and type checking are unchanged
  (they consult kernel globals only, never `Interp` values), and
  bootstrap keeps folding the prelude with execution on.  Run mode
  kept eager definition-time execution for pure heads at this round,
  a rule the round-2 entry below (M3 fixes round 2, R2) replaced with
  lazy memoized thunks for every def.  Also (C17): forcing a deferred
  global now memoizes.  The
  entry's `gval` is a `gbody ref`;  the first force writes the
  computed value back as `GForced`, so a chain of n `Div`-headed defs
  each referencing the previous twice costs n forces, not 2^n.
  Memoizing an `IO`-headed def changes nothing observable: its body
  only builds an inert action tree, and `Effect.run_io` still fires
  effects once per walk.  `Cache.format_version` bumped 1 -> 2 for
  the layout change.
- 2026-09-01 (M3 fixes, stage B): runtime robustness.
  - Regex Str-dialect caveats and error channel (O2 + C19):
    `regex_group_count` is a state machine that counts a group
    exactly when Str's own parser would: `\(` read in the normal
    state only.  The dialect rules it honors, now recorded: an
    escaped backslash `\\` consumes both characters, so it can never
    lend its backslash to a following `(`;  `[` opens a character
    class;  inside a class a backslash is an ORDINARY member (Str
    classes have no escapes);  `]` closes the class except as its
    first member (`[]a]` and `[^]a]` keep the literal `]`).  A
    malformed pattern (`Str.regexp`'s own `Failure`) is a NEW
    distinct runtime error, `Error.Regex_bad_pattern`, through the
    ordinary Result channel: a typo'd pattern in a guard errors
    instead of reading as a silent no-match forever.  `str_opt` keeps
    `Not_found` as the ordinary no-match fence and adds
    `Invalid_argument` as a backstop for the no-exceptions promise.
  - Prelude cache integrity (O3 + C7 + O7): the blob is the magic
    string `TOTCACHE`, the fixed-width `format_version`, the MD5 hex
    digest of the body, then the body;  `load` verifies all three
    BEFORE `Marshal.from_string` sees a byte, and the Marshal fence
    also catches `Invalid_argument`.  Any mismatch is a silent miss.
    The digest defends against CORRUPTION;  the cache directory
    itself is a TRUSTED input, the same trust class as the tot
    binary (section 6 records the residual).  `save` unlinks its
    temp file on a failed rename.  `format_version` bumped 2 -> 3.
    `tot check` KEEPS writing the prelude cache: hooks need
    warm-cache check latency, and `bin/tot.ml`'s doc says so now.
  - `procRun` capture (C8 + C16 + C9): child stdout/stderr go to two
    temp files, not pipes, so a child that outgrows a pipe buffer
    can never deadlock a sequential drain, and every parent-held
    descriptor is closed immediately after the spawn decision on the
    success AND failure paths alike, with the capture files unlinked
    on both.  A signaled child maps to exit 128+signo (the shell
    convention, host signal numbering);  a stopped child is waited
    on again (unreachable without `WUNTRACED`, kept honest).
  - `exitWith` range (C10): valid domain 0..255.  Out of range is a
    runtime script error (`Error.Exit_code_out_of_range`, message on
    stderr, process exit 1), never a silent OS-level wrap of the
    code modulo 256.
- 2026-09-01 (M3 fixes, stage C): driver, tests, docs.
  - `main` is a RESERVED driver name (O4): a user-file def literally
    named `main` whose type converts to neither `IO Verdict` nor
    `IO Unit` is a script error, `Serror.Main_bad_type` carrying the
    printed type, in BOTH check and run modes.  Pre-fix it was a
    silent exit-0 no-op in both, so an `IO Bool` main turned a
    denying guard into a permit-all that `tot check` reported clean.
    The reserved-name check evaluates `main`'s stored type ONCE
    (kernel NbE only, never `Interp`), shared by both target
    comparisons (C11).  Two residuals stay open in section 6: a
    MISSPELLED main is still silent (a strict driver flag is M4
    work), and a script-level `Serror` exits 1, colliding with the
    `ask` verdict's exit code in the hook protocol.
  - A `VPrim` spine accumulates its arguments NEWEST FIRST (cons,
    like `VNeut`'s frames) and is reversed into argument order once,
    at fire time and at readback (C4);  `Cache.format_version` bumped
    3 -> 4, since an old-order blob read by a new binary would fire
    prims with reversed arguments.
  - `dev/prim-lint.sh` asserts every non-empty `tot prims` line
    matches the strict catalog-row shape and FAILS listing the
    offending lines (C1), replacing wc-l arithmetic that failed
    spuriously on a benign header and undercounted without a
    trailing newline;  the catalog-size agreement against the seeded
    prim count stays.
  - test/surface.exe's argv dispatch errors (exit 2, usage on
    stderr) on a malformed or unknown subcommand instead of silently
    running the full suite (C13);  the prim-arity pin covers all
    three seeding phases (O6);  `dev/gates.sh` chmods only its
    scratch binary copy, with `examples/guard.tot`'s executable bit
    carried by the working tree (C0);  a partial def whose type has
    no leading Pi reuses the already-evaluated type value for the
    Div-codomain check (C2).
- 2026-09-01 (M3 fixes round 2, R2): run mode stores EVERY user def
  as a lazy memoized thunk.  The round-1 rule (eager for pure heads,
  deferred for `Div`/`IO` heads) let a `Div` computation nested under
  a pure head in a def `main` never mentions abort or hang `tot run`
  while `tot check` reported the same file clean (round-2 re-probe).
  Now `Interp.define` records every user def as a `GDeferred` thunk:
  elaboration, checking, erasure and closedness stay EAGER at
  definition time (a malformed def is still caught there), the body
  runs on first force by an eval item or by `main`, and the A2 memo
  keeps single-execution.  `Div` carries no host effects and `IO` is
  reified, so laziness is observationally invisible except that
  unforced defs never run, which is the point.  Check mode is
  unchanged (`Interp.define` is never called for user defs;
  data-ctor seeding stays mode-independent, M3 fixes round 3, O5);
  it therefore
  over-approximates run's definition-time failure set again for DEAD
  code (check may reject or diverge on a def run would never force),
  and a LIVE def's definition-time abort surfaces only at force
  time.  `Cache.format_version` bumped 4 -> 5 (shared with R1: the
  stored prelude `gval` contents changed shape).  Gates:
  PASS-RUN-DEADCODE-ABORT and PASS-RUN-DEADCODE-HANG over
  test/fixtures/x12-dead-abort.tot and x13-dead-hang.tot.
- 2026-09-01 (M3 fixes round 2, R1): the prelude cache is bound to
  the exact executable.  The round-2 re-probe proved layout drift
  undetectable by construction: `format_version` is folded into the
  cache KEY, so the file a mismatched binary opens always carries a
  matching version field, and the body digest is computed by the
  WRITER, so any self-consistent blob reaches `Marshal` (two
  binaries sharing version 4 but differing in one marshaled payload
  type produced a silently wrong prelude one way, exit 0, and a
  SIGSEGV the other, exit 139).  Now `surface/cache.ml` computes,
  once per process, the MD5 digest of the running binary's own
  contents (`Digest.file Sys.executable_name`), folds it into the
  key AND writes it as a fourth header field that `load` verifies
  before the body digest;  on any read failure of the binary the
  cache is DISABLED for the run, one loud stderr line, never a
  crash.  Only the exact binary that wrote a blob ever reads it, so
  a forgotten `format_version` bump degrades to two independent cold
  caches.  Section 6 keeps the trusted-directory residual.
- 2026-09-02 (M4, Stage A): indexed inductive families.  `declare_ind`
  takes an index telescope, every index binder is forced to quantity 0
  (`Index_not_zero` otherwise), and each index TYPE is bounded by
  `Level.le` against the declared level (the conservative bound;  the
  Agda-style exemption from the predicative bound is not taken,
  `Index_above_universe` otherwise).  A constructor codomain must be
  `I p1 .. pn e1 .. em` with the `pi` the constructor's own parameter
  variables in order and each `ej` free of `I` (`index_expr_clean`).
  Strict positivity generalizes the same way for argument types.  The
  result-head/arity check runs on the RAW (pre-elaboration) constructor
  type, before `infer_univ`: an under- or over-applied family reference
  does not even have kind `Type` (a partially-applied type former's own
  type is a further Pi), so checking the whole declared type's kind
  FIRST would report a kind error one layer too late instead of this
  precise, index-count-aware `Bad_ctor` diagnosis;  running the
  structural check first and reusing its `args`/`cod` split for the
  per-argument walk on the STAMPED type is sound because elaboration
  never changes a `Var`'s index, a `Global`'s name, or a `Pi`'s own
  quantity.  Elaboration DOES delete two node shapes, and M4 fixes
  round 1 handles both where they land, in the RAW pass only:
  `Check.strip_ann` removes the `Term.Ann` wrappers `infer` would have
  dropped, at the codomain head and at each parameter-position argument,
  so an annotated codomain or parameter argument keeps checking (ctxcat
  id 8);  and `no_occur` answers FALSE for `Term.Auto`, so `auto` in a
  result-index position hits the cleanliness ban instead of slipping
  past a check that runs before resolution could have produced the spine
  (audit F3).
- 2026-09-02 (M4, Stage A): the motive record.  `Term.Match`'s motive
  becomes `{ m_ind;  m_idx;  m_self;  m_body }`: `m_ind` is the family the
  surface `in I ..` clause names (diagnostic only, conversion IGNORES
  it), `m_idx` is the index binder list (outermost first), `m_self` is
  the scrutinee binder, and `m_body` is scoped under `m_idx` then
  `m_self`.  The surface form is `match S as x in I y1 .. ym return P
  with`;  the index clause sits AFTER `as x` so a `let .. in ..`
  scrutinee cannot collide with it.  The old M2/M3 motive (a bare
  binder over the scrutinee) is exactly the `m_ind = None, m_idx = []`
  case, so every M2/M3 term round-trips unchanged and a motive-free
  match still compares equal, under conversion, to an equivalent
  explicit-motive one via the same materialized-constant-motive rule M2
  fixes established, widened to `n_indices + 1` ignored binders.
- 2026-09-02 (M4, Stage A): the subsingleton elimination rule (user
  decision 1), with its Round-4 relaxation story.  A match whose
  scrutinee is an erased hypothesis may run at quantity mode `w` exactly
  when its inductive carries no runtime bits: THREE required clauses,
  at most one constructor, every constructor argument binder at
  quantity 0, and the constructor NOT self-recursive
  (`Global.ctor_entry.self_rec`).  The stamp is `scrut_q = Zero` exactly
  when the subsingleton criterion holds, and `Many` otherwise (never the
  ambient mode itself, which is what makes `Erase`'s two-or-more-branch
  backstop provably unreachable).  `Check.match_scrut` infers the
  scrutinee ONCE, at the ambient mode, and falls back to a mode-`Zero`
  inference (the weakest mode, so the erased-hypothesis allowance still
  reaches it) only when that one failed;  a non-subsingleton family then
  returns the AMBIENT error.  M4 fixes round 1 (ctxcat id 7) replaced an
  unconditional `Zero`-then-ambient two-pass here, which cost `2^depth`
  inferences for matches nested in scrutinee position.  Soundness rests
  on the mode reaching only three rules (`Var`, `Global`, and
  multiplicative propagation), none of which changes the stamped output,
  so the two passes agree on the term and the type whenever both
  succeed, and the mode decides only WHETHER inference errors.  M2 fixes Round 4 proved its erased-
  guard rule sound through the invariant "a quantity-0 formal can only
  be eliminated while checking at mode `Zero`";  the subsingleton rule
  DELETES that invariant on purpose.  The repaired argument: a
  recursive call guarded on an erased principal argument now requires a
  `Smaller` binder whose type is the principal's own family `F`, and
  `Smaller` binders arise only through subsingleton matches on NON-
  self-recursive families;  chasing that chain, an `F`-typed `Smaller`
  binder forces `F` to occur (through erased fields) strictly inside
  itself, and any such family is empty by induction on term size.  So
  an erased body that still mentions its own global name can only be
  forced through an inhabitant of an empty type, which a total language
  never produces.  The `self_rec = false` clause is the syntactic fence
  that keeps that chain from starting.  M4 Stage C makes the invariant
  EXECUTABLE instead of assumed (the `Frozen` runtime guard).  The
  emptiness claim itself stays UNPROVEN;  nothing load-bearing rests on
  it, because the fence is syntactic and the Stage C backstop is
  executable.
- 2026-09-02 (M4, Stage A): the Fording blockage (user decision 3).
  Encoding an index as a uniform parameter plus equations is
  unavailable: `vpnil : VecP A zero` fails the result-head rule (`zero`
  is not the parameter `n` itself) and `vpcons : .. -> VecP A n` (with
  the recursive field `VecP A m` using the ctor's own fresh `m` instead
  of the parameter `n`) fails uniform positivity.  Both messages are
  pinned, respectively, by `test/fixtures/m4a-fording.tot` (gate
  `PASS-M4A-FORDING`, which observes only the FIRST, since
  `define_ind`'s ctor fold short-circuits at `vpnil` before ever
  reaching `vpcons`) and kernel test A5 (which isolates `vpcons` alone,
  with a uniform codomain, to witness the positivity failure directly).
  This is why decision 3 admits general recursive indexed families now
  rather than fencing them to non-recursive ones: Fording had no escape
  route to fall back to.
- 2026-09-02 (M4, Stage A): the index-expression backstop is
  unreachable from source.  `index_expr_clean` (checked on every INDEX
  position of a constructor's result type) rejects an index expression
  that mentions the inductive being defined.  An index expression `e_j`
  would have to be an application of the family `I` to mention it, and
  `I`'s own type is `Univ level`;  so `e_j`'s type would have to be
  `Univ level`, whose OWN level is `level + 1`, which `declare_ind`'s
  `Level.le` bound on index TYPES rejects at declaration time before any
  constructor is ever checked.  The check is therefore a total
  backstop, unreachable from any well-typed source file;  kernel test
  A6 is its only non-vacuous oracle (a direct unit-test call).  Do not
  delete the check on the grounds that no fixture exercises it.
- 2026-09-02 (M4, Stage A): debts discharged.  The ctor-arity cache
  (`Global.ctor_entry.full_arity` retires `Eval.is_canonical`'s second
  `Global.find_ind` lookup on the guarded-unfolding hot path) and the
  builtin-former marker (`Global.ctor_status.Builtin` plus
  `Error.Builtin_not_eliminable`, replacing `Ind_incomplete`'s reused-
  but-wrong wording for a type former that will never be defined) are
  done here, discharged by the very record changes indexed families
  needed anyway, not deferred to a later stage.
- 2026-09-02 (M4, Stage A): `Cache.format_version` bumped 5 -> 6:
  `Term.t` gained `Auto` and `Match`'s payload gained `scrut_q` plus the
  `motive` record;  `Value.stuck_match`'s motive payload changed the
  same way;  `Global.ind_entry` gained `indices` and its `ctor_names`
  became the three-state `ctors : ctor_status`;  `Global.ctor_entry`
  gained `res_idx`, `full_arity` and `self_rec`.
- 2026-09-02 (M4, Stage B): equality's permanent shape (user decision
  6), written out in full.  `Eq` is homogeneous Paulin-Mohring, an
  ordinary `data`, with parameters `(0 A : Type 0)` and the LEFT
  endpoint `(0 a : A)`, ONE index (the right endpoint), sole
  constructor `refl : Eq A a a`, at `Type 0` only (a `Type 1` need
  duplicates the def, recorded below as a debt).  `J` is an ordinary
  match reducing by ordinary iota (`J0` in `stdlib/prelude.tot`);  there
  is deliberately NO K and NO UIP (no axiom or rule ever proves two
  proofs of the same equation equal), and there is NO `rewrite` surface
  form, because motive selection for a general rewrite needs a
  metavariable/unification engine tot does not have.  Rewriting is the
  four prelude defs `subst0` (transport), `sym0`, `trans0` and `cong0`,
  all `reducible` so they unfold under conversion and cost nothing
  extra at typechecking beyond an ordinary match.  `Dec` (`yes`/`no`,
  both carrying only quantity-0 payloads) and `Empty` ride along in the
  same prelude block because `Dec`'s `no` case needs a codomain to land
  in, and `natDecEq` (structural recursion on the first argument,
  `Dec (Eq Nat m n)`) is the first nontrivial consumer, computing by
  reduction on `natFamZero`'s canonical-scrutinee case split.
- 2026-09-02 (M4, Stage B): `trans0` uses a NESTED double match, not
  `subst0 A b c (fun z => Eq A a z) h2 h1`.  A `def` body checks at
  quantity mode `w`, and `subst0`'s transported argument (its `P a ->
  P b` position) sits at a `w` position;  forwarding the 0-bound proof
  `h1` there is `Erased_use`.  The nested double match instead
  eliminates `h1` INSIDE `h2`'s `refl` branch and returns a freshly
  built `refl A a`, never forwarding a bound proof to a runtime
  position.  Surface test B11 (`test/surface.ml`) is the regression
  oracle: it feeds the broken single-match spelling as a user def and
  pins `Kernel.Erased_use` ("erased variable h1 used at runtime"), so
  the nested shape can never be "simplified" back to the broken one
  without the suite going red.
- 2026-09-02 (M4, Stage B): the `axiom` entry kind and its consistency
  note (user decision 5).  `Global.entry` gains a fifth kind, `Axiom`
  (`{ ax_ty : Term.t }`): no `def` field and no `reducible` flag, the
  same shape as `Prim`, so conversion can never step into one, by the
  same argument SPEC section 3 makes for prims.  `Check.define_axiom`
  is the only public way to install one (`ensure_fresh` then
  `infer_univ` to validate and stamp `ax_ty`, exactly `define_prim`'s
  shape).  Confinement is ONE guard in `infer`'s `Term.Global` arm:
  when the entry is `Axiom` and the checking mode is `Many`, the result
  is `Error.Axiom_runtime_use`;  at mode `Zero` it is the ordinary
  neutral with its stored type.  That single guard is the whole fence:
  an axiom can never flow into erased output, so a stuck axiom at
  runtime is unrepresentable rather than merely unlikely, and
  `Run.item`'s `IAxiom` arm never calls `Interp.define` at all (if one
  ever reached `Interp.exec`, the existing `Unbound_global` backstop
  fires;  surface test B9 pins this).  Consistency argument for the
  three monad-law axioms this stage postulates (`ioBindPure`,
  `ioBindRet`, `ioBindAssoc`, appended to `stdlib/prelude.tot`): `IO`
  and `Div` are declared-only, zero-constructor type formers (M3 Stage
  A/B), so no internal predicate can eliminate an `IO` or `Div` value,
  and therefore nothing definable in tot can distinguish the action
  trees these axioms equate;  every use sits under an erased
  application and is dropped wholesale by erasure, so postulating them
  costs nothing at runtime and adds no new way to derive `False`
  reachable from a `Many`-mode program.  The `--no-axioms` driver flag
  (a `Run.policy` field, plumbed through `bin/tot.ml`'s new total flag
  parser) rejects an `axiom` item with `Serror.Axioms_disabled`, and
  applies to the USER file ONLY:  `Bootstrap.fold_items` always folds
  the prelude with `Run.default_policy` (`no_axioms = false`), so an
  installation that runs hooks with `--no-axioms` still gets the
  prelude's own three monad-law axioms;  gate `PASS-M4B-NOAXIOMS` pins
  both halves of that difference through the real `tot` CLI, since
  `test/surface.exe`'s `gate-check`/`gate-run` subcommands have no
  policy parameter of their own.
- 2026-09-02 (M4, Stage B): `Cache.format_version` bumped 6 -> 7:
  `Global.entry` gained the `Axiom` constructor.
- 2026-09-02 (M4, Stage C): the `Frozen` backstop.  `Interp`'s runtime
  unfolding guard becomes a three-state sum, `Unguarded | GuardedAt of
  int | Frozen` (`Interp.guard`, replacing `Interp.gentry`'s
  `grec_arg : int option`).  `surface/run.ml`'s `compute_guard`
  (replacing `remap_rec_arg`) runs `Eterm.mentions` on a rec def's
  erased body exactly when its guarded formal is erased:  no mention
  gives `Unguarded` (M2 fixes Round 4's behavior, the only LIVE case),
  a mention gives `Frozen`, a permanent neutral that `Interp.exec`'s
  `EGlobal` arm and `Interp.apply`'s `EHGlobal` arm both refuse to
  unfold under any application.  The Round 4 invariant (a rec def
  guarded on an erased formal cannot mention its own name after
  erasure, so eager unfolding is safe) is now EXECUTABLE, checked on
  every such def at definition time, rather than assumed once and
  carried forward on faith.
- 2026-09-02 (M4, Stage C): the emptiness claim stays UNPROVEN.
  Recorded plainly rather than left implicit:  the subsingleton fence
  (section 2, user decision 1) is syntactic (`self_rec = false` plus
  the zero/one-constructor, zero-runtime-argument shape), the `Frozen`
  backstop is executable, and the claim that a self-recursive
  all-erased family (the `SX` shape) is empty is NOT proved anywhere in
  this codebase.  Nothing load-bearing rests on it today: `Frozen` is
  dead code on every def this milestone can construct, reached only if
  the fence's syntactic criterion and the actual semantics it
  approximates ever come apart.  Revisit this note if mutual or nested
  inductives land in a later milestone, since either could open a gap
  the current fence does not cover.
- 2026-09-02 (M4, Stage C): `Eterm.mentions` is promoted from a
  test-private walk (`test/main.ml`'s T0 case) to a kernel function
  (`lib/eterm.ml`), and the T0 case is rewritten to call the promoted
  function instead of its own copy, so the promotion is proven by the
  existing regression rather than merely asserted in a commit message.
- 2026-09-02 (M4, Stage C): `Cache.format_version` bumped 7 -> 8:
  `Interp.gentry`'s `grec_arg : int option` became `gguard : Interp.guard`,
  the three-state runtime unfolding guard above.
- 2026-09-02 (M4, Stage D): the class resolution key and the coherence
  rule (user decision 2).  A class is a convention, not a kernel notion:
  a single-parameter, single-constructor `data` (the dictionary), plain
  projection defs, and instances as ordinary globals under
  `inst$CLASS$KEY`.  The one new checking rule is `Auto`: the expected
  type must be a class applied to one type, the KEY is that type's head
  symbol, and resolution (`Check.resolve_auto`/`Check.build_instance`)
  is a total function of the expected type VALUE with no search and no
  backtracking.  Coherence is `Duplicate_global` on the mangled name, at
  definition time (`ensure_fresh` inside `Check.define`;  there is no
  separate class-coherence kernel state).  `Check.define_instance`'s
  `validate_instance_shape` checks the registration head shape (each Pi
  domain is a type binder or a single-parameter, no-index class applied
  to an earlier type binder;  the codomain is `C (K a1 .. ak)` with `a1
  .. ak` the type binders in declaration order) and recomputes the
  mangled name from the CHECKED type, closing the gap between a name
  computed from the surface spelling and the real type;  a ground
  instance at an APPLIED key (e.g. `EqD (List Int)` with no type
  binders) fails the same key-argument-count check, so every key has
  exactly one derivation route.  Resolution is fuel bounded
  (`Error.Inst_depth`), a belt over the structural termination argument
  (each dictionary sub-resolution recurses on a strict subvalue of the
  query).  The bound is `Check.inst_fuel`.  M4 fixes round 1 (ctxcat ids
  1 and 6) replaced a bound that was the query's node COUNT alone, which
  charged instance binders against a budget the query could not see and
  so rejected a registrable four-dictionary-binder instance outright;
  a table-only constant cannot replace it either, since legitimate
  resolutions nest arbitrarily deep in the query (`EqD (List^n Int)`).
  M4 fixes round 5 (opus R5-2, ctxcat r5 id 16): after the round-3
  (class, key) memo the walk peels one telescope per DISTINCT pair, so
  the charge is a PRODUCT, (key count) times (per-key cost), and a bound
  that took the MAX of a depth-scaled term and a width-scaled term
  bounded it only up to the smaller factor.  Two dimensions were
  reachable on legitimate input and both were bisected to the leaf: 57
  single-field classes with one pair instance per class (K = 56
  resolves, K = 57 does not), and an 8-binder instance against a wide
  balanced query.  The width term is now that product,
  `8 * term_size * (2 * max_binders + 2)`, beside the unchanged depth
  term.  M4 fixes round 6 (opus R6-1): that product NARROWED the
  class-count dimension and did not close it, and the tree said
  otherwise.  Measured on the round-5 binary with the same generator,
  the leaf on that shape is K = 60 resolving and K = 61 reporting
  `Inst_depth`, four or five classes above the round-4 leaf, so fuel
  IS a reachable rejection on a registrable, structurally terminating
  query.  It stays a backstop with a recorded margin on every shipped
  shape, not a decision procedure;  section 6 carries the residual.
  Residual, unchanged and carried to M5: the fuel counter is not
  a TIME budget.  `term_size` is measured on the quote of the already
  evaluated expected value, so def sharing does not undercount it, but
  quoting and per-node key encoding are themselves blind to sharing, so
  a sub-2 KB file whose type doubles per level costs 24.6s at depth 17
  and 41.4s at depth 18 at exit 0, without ever reaching the counter.
  The doubling type understates the reach: a plain LINEAR chain of about
  800 nested boxes (7.2 KB, the `m4fix-inst-chains` shape) exceeds a 60s
  budget with no verdict at all, exit 124.  That is the check-budget
  debt, closed by hash consing, not by this number.
  `inst C T` is `Term.Ann (Term.Auto, Term.App (Quantity.Many,
  C, T))`, pure sugar with no new core constructor.  `Term.Auto` stays
  invalid in checker output;  `Eval`, `Erase` and `Interp` each carry the
  Stage A total backstop arm for it, now genuinely exercised only as a
  backstop, since `Check.check`'s own `Auto` arm always resolves or
  errors before either pass ever sees one.
- 2026-09-02 (M4, Stage D): scope fences, stated as fences and not as
  accidents: single-parameter classes, positional parametric instances
  only, no multi-parameter classes, no superclass constraints beyond
  dictionary binders, no overlapping instances, no instances keyed on
  functions or on variables.
- 2026-09-02 (M4, Stage D): `--serror-exit N` ships with default 1 (user
  decision 4).  `bin/tot.ml`'s script-level `Serror` exit sites
  (`Run.script`'s own error branch and the bootstrap-failure branch)
  return the configured value instead of the literal 1.  The
  missing-file branch was routed through it too and is NOT any more (M4
  fixes round 1, audit F2): a missing script is a driver error, not a
  script-level `Serror`, so it exits 1 whatever `--serror-exit` says and
  reports on stderr, and a fail-open install (`--serror-exit 0`) cannot
  turn a renamed guard script into a silent exit 0 with a junk line on
  the hook decision channel (`PASS-D-MISSING-FILE-CHANNEL`,
  `PASS-D-USAGE-CHANNEL`).  The flip to 3 is scheduled as a separate, later
  change, made only after installed guards migrate;  an unconditional
  flip now would change the production behavior of every deployed guard
  the day it is rebuilt.  This retires the "Serror exits 1, colliding
  with ask" residual as a CONFIGURABLE collision rather than a fixed
  one.
- 2026-09-02 (M4, Stage D): `--require-main` (`Run.policy.require_main`,
  a driver flag like `--no-axioms`, never applied to the prelude) is
  `Serror.Missing_main` when the user file defines no `main`.  Retires
  the misspelled-main residual for installations that opt in;  the
  UNFLAGGED default keeps the documented residual (a misspelled `main`
  stays silent), pinned by the existing `PASS-D-MAIN-MISSPELLED` gate,
  with `PASS-M4D-REQUIRE-MAIN` as its flagged twin.
- 2026-09-02 (M4, Stage D): the stat-identity cache fast path.
  `Cache.exe_digest_hex` replaced the executable's full-file MD5
  (`Digest.file`) with a `device:inode:mtime:size` string hashed through
  `Digest.string`, measured to cut the largest cost off an ~8ms warm-hit
  startup.  REVERSED the same day by M4 fixes round 1;  see the next
  entry.  `Cache.format_version` bumped 8 -> 9 for the header field's
  changed meaning.
- 2026-09-02 (M4 fixes round 1, audit F1): the cache's exe identity is
  the running binary's CONTENT again, and the stat fields are a MEMO.
  The stat-identity shape above lost the property it claimed to keep:
  metadata is forgeable, and an executed repro built two byte-different
  binaries of equal size, installed them at one inode with mtime
  restored, and watched the second one LOAD the first one's blob, whose
  body `Marshal.from_string` deserializes straight into the trusted
  checker and interpreter state.  `Cache.exe_digest_hex` is
  `Digest.file` again and fails CLOSED (an unreadable image disables the
  cache for the run with one loud stderr line, so `PASS-CACHE-NOEXEDIGEST`
  asserts what its name says once more).  The stat signature survives as
  the key of a memo file in the cache directory recording
  "this signature was content-verified to have this digest", so the
  re-hash is skipped on a warm run;  an absent, unreadable, malformed or
  mismatched memo re-hashes.  The signature carries `st_ctime` as well,
  the one field userspace cannot restore (`utimes` resets mtime but
  bumps ctime), so the in-place overwrite that motivated the finding
  misses the memo.  `Cache.format_version` bumped 9 -> 10 to orphan
  every stat-identity blob.  Gates: `PASS-CACHE-EXEID-CONTENT` (the
  repro, now requiring TWO blobs) and `PASS-CACHE-EXEID-MEMO` (the fast
  path, announced under `TOT_CACHE_VERIFY=1`).
  Residual, ACCEPTED (M4 fixes round 3, ctxcat r3 id 6): the one path
  where a wrong identity could still be served is a memo HIT on a binary
  whose bytes changed while its observed signature did not, and no gate
  forges that hit.  It is not testable unprivileged on this platform:
  opus round 2 proved by execution that `setattrlist` with
  `ATTR_CMN_CHGTIME` returns `EPERM` for a non-root caller and that no
  unprivileged call sets ctime, so a hit-on-changed-bytes has no
  unprivileged construction, and a privileged writer is already inside
  the cache-directory trust class below.  A fake-stat seam was
  considered and rejected: it would gate the seam, not the property.
  The exposure that remains is a mount whose observed ctime does not
  move on an in-place overwrite (attribute-cached network mounts,
  ctime-less filesystems), where the memo degrades to a metadata check;
  `PASS-CACHE-EXEID-MEMO`'s own comment carries this argument in full.
- 2026-09-02 (M4, Stage D): `Syntax.defkind` (`DNonRec | DRec |
  DRecPartial`) replaces `Syntax.IDef`'s `(rec_, partial)` bool pair,
  making the illegal `partial = true, rec_ = false` state
  unrepresentable (retires a SPEC section 6 debt).  `parse_def` produces
  the sum directly;  `Run.item`'s `defkind_bools` maps it back to
  `Check.define`'s own two booleans with one exhaustive match --
  `Check.define`'s kernel signature, and `Global.def_entry.partial`'s
  marshaled shape, are UNCHANGED, so this stage does not touch the
  cache shape twice.
- 2026-09-02 (M4, Stage D): debts discharged in Stage A (the ctor-arity
  cache and the builtin-former marker) stay discharged;  nothing in this
  stage touches either.
- 2026-09-02 (M5, Stage A): the JSON parser accepts `\uXXXX` and
  surrogate PAIRS (design pin 13).  A high surrogate (`\uD800` to
  `\uDBFF`) is valid only as the first half of a pair whose second half
  is `\uDC00` to `\uDFFF`;  the pair decodes to one supplementary code
  point, UTF-8 encoded byte for byte.  A lone high surrogate, a lone
  low surrogate, a short escape (fewer than four hex digits), and a
  non-hex escape each return `none` and fail the WHOLE parse, never a
  partial decode.  This closes the milestone's one LIVE exploit: the
  payload `{"tool_name":"Bash","tool_input":{"command":"\u0067rep
  foo"}}` piped to `tot run examples/guard.tot` exited 0 (allow) at M4
  HEAD, because the parser rejected the escape, `jsonParse` returned
  `none`, and the guard maps `none` to allow, so a banned binary ran.
  It now decodes to `grep foo` and DENIES with exit 2
  (`PASS-M5A-BYPASS`;  `PASS-M5A-LONE-SURROGATE` pins the negative
  shapes together with the suite's direct parse assertions).
- 2026-09-02 (M5, Stage A): two escapers, one parser rule (design pin
  13).  `Pp.escape_string` is the SOURCE escaper (tot string
  literals);  `Json_escape.string` (lib/json_escape.ml, NEW) is the
  JSON escaper, covering the RFC 8259 short forms plus `\u00XX` for
  every remaining byte below 0x20, DEL and bytes at or above 0x80
  unescaped.  M4's claim at the serializer (lib/interp.ml) that the
  source escape set is a sufficient SUBSET of JSON's was FALSE: the
  parser accepts `\r`, `\b` and `\f`, the source escaper leaves all
  three raw, and a deny envelope carrying a raw CR or a raw 0x01 was
  rejected by a conforming JSON parser, so a hook fell back to its
  decode-error posture, which is fail-open.  Three call sites were
  rewired to the JSON escaper: the serializer's `jstr` value, the
  serializer's object KEY, and the verdict envelope in
  surface/effect.ml (`PASS-M5A-ENVELOPE-VALID` pins the envelope and
  the serializer independently, one mutation proof per site).
- 2026-09-02 (M5, Stage A): raw C0 bytes inside a parsed string body
  are still ACCEPTED, a deliberate non-change.  The guard's deny set
  does not read control bytes, and tightening the parser moves
  payloads between paths for no exploit found.  `\u0000` decodes to a
  real NUL byte (OCaml strings are byte arrays, so the value is
  carried, not truncated), and the decoded `\u0000grep foo` command
  still yields allow, because the first token's basename is
  `\x00grep`, not `grep`.  That is the honest result, not a
  regression.  Section 6 carries the residual.
- 2026-09-02 (M5, Stage A): `--strict-json` (design pin 20, amendment
  A2).  Default off;  effective in `run` only (`check` never runs the
  epilogue, so `readStdin` never fires);  the flag travels as
  `Run.policy.strict_json` and is enforced at `Effect.dispatch`'s
  `readStdin` arm, the one raw stdin read in the tree, so `lib/` is
  untouched and the guard script needs no edit.  Under the flag a
  stdin payload that is not one well-formed JSON value DENIES: an
  `IO Verdict` script renders the deny envelope with the fixed reason
  `strict-json: stdin is not a single well-formed JSON value` and
  exits 2;  an `IO Unit` script has no verdict channel and takes the
  DRIVER contract instead (`Serror.Json_strict_reject`: one stderr
  line, exit 1, OUTSIDE the `--serror-exit` mapping).  Consequence,
  stated plainly (review round 2026-09-03): a hook harness that
  blocks only on exit 2 treats that exit 1 as NON-blocking, so the
  fail-closed guarantee is `IO Verdict`-only;  a blocking Unit-shape
  posture is an M6 decision, listed in section 5.  Without the
  flag the fail-open posture is byte-identical to M4 HEAD
  (`PASS-M5A-STRICT-DENY`, `PASS-M5A-STRICT-ALLOW`).  Rejected
  alternatives: threading a flag through `Interp.fire_prim` puts
  installation policy in `lib/` against the repo's own rule and costs
  23 call sites for no coverage;  changing `jsonParse`'s posture needs
  a different type (`String -> Div (Option Json)`), moving the prelude
  and every caller;  editing only `examples/guard.tot` gives the
  posture to one file, and a script that ignored an argv-passed flag
  would still fall open, so the flag would guarantee nothing.
- 2026-09-02 (M5, Stage A): the subsingleton fence walks under a Pi
  (design pin 15, amendment A5).  `Totality.mentions` recurses into
  BOTH halves of a `Pi`, so a self-recursive occurrence in a
  constructor argument's Pi CODOMAIN keeps `self_rec = true`, the
  family stays outside `zero_eliminable`, and eliminating it erased at
  mode `w` stays `Erased_use` (`PASS-M5A-FENCE-PI`, fixture
  m5a-fence-pi.tot, with the no-recursion control pinning the flip
  target).  The executable mutation proof is the CODOMAIN half: walk
  the domain only and the fixture flips to exit 0.  The verdict's
  DOMAIN mutation is refuted by `Check.strict_pos`: a constructor
  argument may never mention the family in a Pi DOMAIN (measured
  rejection: `invalid constructor pywrap: negative or non-uniform
  occurrence of PY`), so no admissible declaration witnesses a domain
  occurrence and that mutation can flip nothing.  No later milestone
  should propose it again.
- 2026-09-02 (M5, Stage A): the parameter-level predicativity
  exemption, written down (design pin 16, amendment A5).
  `declare_ind_status` treats three telescopes differently: the
  PARAMETER fold DISCARDS the inferred level (lib/check.ml, `let* ty',
  _l = infer_univ ..`), while every INDEX type and every constructor
  ARGUMENT is bounded by the declared universe
  (`Index_above_universe`, `Bad_ctor`).  A parameter may therefore
  live above the family's level, and this exemption is exactly what
  makes `Acc` check.  The working spelling, verbatim (parameters
  0-marked, accessibility as an INDEX):

      data Acc (0 A : Type 0) (0 R : A -> A -> Type 0) : (0 x : A) -> Type 0 :=
        | acc : (x : A) -> ((y : A) -> R y x -> Acc A R y) -> Acc A R x

  The design verdict's own spelling fails at the parser (`data`
  parameters must be marked 0) and then at the constructor-codomain
  arity rule, so it is elliptical, not runnable.  Gates: the positive
  `Acc`/`PBox` fixture at exit 0 and the two negatives at their exact
  rejection texts (`PASS-M5A-PARAM-LEVEL`).  No milestone may cite
  this exemption as evidence again without this entry.
- 2026-09-02 (M5, Stage A): the positivity door stays SHUT, and the
  recorded reason is the MUTUAL gap (design pin 14).
  `Totality.mentions` tests only the family's OWN name when `self_rec`
  is computed, so a recursive PAIR of families reads as
  non-self-recursive.  The losing proposal's NESTING claim is
  corrected explicitly: nesting does NOT lose `self_rec`, because
  `mentions` recurses into both halves of `App`, so a nested
  occurrence such as `jarr : List Json -> Json` still gives
  `self_rec = true`.  The emptiness claim behind the subsingleton
  soundness argument stays UNPROVEN, and M5 leaves M6 this oracle
  rather than a memory.
- 2026-09-02 (M5, Stage A): `Cache.format_version` stays 10, a
  deliberate no-bump.  Five checkable reasons: (1) `Term.t` is
  unchanged, no constructor and no field;  (2) `Global` entry shapes
  are unchanged, `self_rec` already exists;  (3) the cache stores
  ELABORATED terms and Stage A does not touch the lexer, so the same
  source elaborates to the same term;  (4) `Json_escape.string` and
  the parser's `\u` arm are RUNTIME behaviour, neither runs during
  elaboration;  (5) `Run.policy` is a driver value, never serialized.
  The cache key also carries the running binary's digest, so a
  rebuild invalidates existing entries anyway;  that is a belt, not
  the argument.
- 2026-09-02 (M5, Stage C): the check budget (design pins 8, 9, 11).
  `Budget.t` (lib/budget.ml, NEW, with lib/budget.mli, the second
  interface file after `Level`) is opaque and holds one
  driver-supplied `poll : unit -> bool`.  `lib/` reads no clock, holds
  no mutable state and raises nothing;  `bin/tot.ml` owns the clock
  (`Sys.time`, CPU milliseconds, one read per 1024 polls) and builds
  the budget AFTER the prelude bootstrap returns, so the prelude runs
  unlimited by construction and a 1 ms budget does not pay the warm
  bootstrap's own ~10 ms.  The same construction leaves a COLD
  bootstrap unbounded (review round 2026-09-03): the cache key
  carries the binary digest, so the first invocation after every
  rebuild or upgrade re-elaborates the prelude outside the budget,
  and no `--check-budget-ms` value cuts that window;  decision 13's
  external `timeout` belt owns it.  `ctx.budget` defaults to
  `Budget.unlimited`, so no existing call site changed.
  `--check-budget-ms N` defaults to 0, which is OFF, and applies to
  `check` and to `run`.  The budget covers elaboration and
  type-checking in both verbs.  It does not cover `Interp` execution,
  where decision 13's external `timeout` stays the belt (the claim
  that installs may drop `timeout` stays RETRACTED).
- 2026-09-02 (M5, Stage C): exit 3 is RESERVED for budget exhaustion
  (design pins 10, 19, amendment A1), outside the `--serror-exit`
  mapping, with one exact stderr line
  `<path>: check budget exhausted (<N> ms)` (`<N>` is the CONFIGURED
  number of milliseconds, not an elapsed measurement, so the line is
  deterministic for a given invocation) and stdout untouched.
  Because `exitWith` accepts any 0..255 and `--serror-exit 3` is a
  shipped, tested configuration, the LINE, not the code alone, is the
  discriminator a hook matches;  the reservation is a convention for
  the default configuration, stated plainly rather than implied to be
  an identification.  The PreToolUse harness treats codes other than
  0 and 2 as non-blocking, so the default posture on exhaustion
  matches the external-timeout posture it replaces;  an installation
  that wants fail-closed wraps the driver.  (`PASS-M5C-BUDGET-FIRES`,
  `PASS-M5C-BUDGET-QUIET`, `PASS-M5C-DETERMINISM`.)
- 2026-09-02 (M5, Stage C): the budget is NODE-granular (design pin
  9).  `Check.check` and `Check.infer` are polling wrappers around
  the M4 bodies (`check_node`/`infer_node`), so node granularity is a
  property of the call graph, and `build_instance` polls beside its
  fuel guard with the budget arm FIRST: a run that is out of time
  reports the cutoff, not a fuel exhaustion it reached only because
  the operator waited.  It is a cutoff, not a real-time guarantee:
  one pathological `Eval.eval` or `Eval.conv` call between two poll
  sites is unbounded by it.
- 2026-09-02 (M5, Stage C): `inst_fuel` gains the class-count factor
  (design pin 12).  The round-5 shape is multiplied by
  `1 + class_count globals`, where the count is the number of
  DISTINCT class components of `inst$` mangled names in the table
  (`Check.instance_class_of`/`inst_table_stats`, one fold for both
  numbers the bound needs).  A class is not a distinguishable kind of
  global in this design (`surface/cache.ml`: "classes are ordinary
  `Ind`"), so the count is a property of the INSTANCE TABLE, which is
  where the round-5 comment already places it;  a class with no
  registered instance counts nothing, correctly for a fuel bound.
  The factor is NOT a proof that the leaf is gone: on the
  `classes K` generated shape the charge and the bound are both about
  quadratic in K, so the leaf is re-measured, never asserted (the "by
  construction" claim is dropped).
- 2026-09-02 (M5, Stage C): the K leaf, re-bisected.
  `dev/bisect-inst-classes.sh` makes the stopping rule executable:
  double through 61, 122, 244, 488 (K_max, three doublings from the
  M4 leaf), bisect at the first rejection;  ceilings of 8 MB per
  generated file and 120 s per probe, both checked before the probe
  runs.  Measured 2026-09-02 on this binary: 61, 122, 244 and 488
  ALL resolve, so the verdict is NOLEAF<=488 and no margin is
  invented (pin 12).  The gate pin is the largest K that RESOLVED
  inside the search bound subject to affordability (file at most
  1 MB, run at most 10 s): K = 122, bound by the file ceiling
  (`PASS-M5C-LEAF-MARGIN` carries the probe table and the
  re-measurement recipe;  `PASS-M5C-CLASSES-61` pins the paid M4 leaf
  itself, and its recorded mutation, dropping the factor, restores
  that file's exact exit-1 fuel line).
- 2026-09-02 (M5, Stage C): `--require-main` is a DRIVER failure
  (design pin 21, amendment A3).  A mainless target takes the driver
  contract: one stderr line, the literal exit 1, OUTSIDE the
  `--serror-exit` mapping, exactly like a missing file.  The stderr
  TEXT does not move
  (`<path>:this file must define a driver main, and it does not`,
  the tight separator);  only the exit mapping moves.
  `Serror.Missing_main`, its `to_string` line and `Run.script` are
  unchanged;  the decision lives in `bin/tot.ml`'s error ladder
  (`Serror.is_missing_main`).  An ordinary script error KEEPS the
  mapping (`PASS-M5C-REQUIRE-MAIN-OK`, the anti-overreach half;
  `PASS-M5C-REQUIRE-MAIN-DRIVER` pins all four invocations, check and
  run, bare and under `--serror-exit 0`).
- 2026-09-02 (M5, Stage D, recording Stage B per its B15 handoff):
  instance term sharing (design pins 1 to 5, plus pin 7's measured
  option).  The `Term.Auto` site now emits a LOCAL `let`-nest over
  the memo's own entries (`Check.materialize`, one fold in reverse
  definition order): `islot = IHead | IApp` with
  `iarg = IType of Term.t | ISlot of int`, entry `i` shifting
  `IType t` by `Term.shift ~cutoff:0 ~by:i` and sending `ISlot j` to
  `Term.Var (i - 1 - j)`;  a memo HIT returns the slot and the cached
  `e_val` and never re-evaluates (pin 5).  `Term.shift` is total and
  exhaustive over all eleven constructors (`m_body` at
  `cutoff + |m_idx| + 1`, a branch body at `cutoff + |binders|`;
  `PASS-M5B-SHIFT`).  It is NOT hash-consing: physical identity does
  not survive `Marshal`, `Term.t` gained a function and no
  constructor, and `Cache.format_version` stays 10 (pin 1).
  Measured: term_size 694 at branching nesting 16 against the
  un-shared M4 tree's 458714 (`PASS-M5B-SHARE-SIZE`), and the
  restored nesting-20 file runs in 0.034s against M4 HEAD's 30.188s
  (`PASS-M5B-BRANCHING-20`).  Key-TYPE sharing stays UNSPENT
  (pin 7): the measured 694 sits far under the 4000 gate, so the
  option is recorded as a section 6 debt, not built.
- 2026-09-02 (M5, Stage D, recording Stage B): sharing is a
  performance change under an UNCHANGED kernel rule (design pin 6).
  The `Auto` site re-checks its materialized candidate at
  lib/check.ml:1002, so a mis-shifted nest is a loud type error and
  never a wrong dictionary;  `PASS-M5B-RUNTIME-IDENTITY` pins four
  runtime values through the nest, and the Stage B mutation table in
  dev/M5-BUILD-LOG.md records the slot-arithmetic flips.  Do not
  weaken that re-check to buy speed.
- 2026-09-02 (M5, Stage D): named watchdog tiers (design pin 17).
  `FAST=10`, `MED=30`, `SLOW=120`, `SUITE=300`, plus the non-leg
  calibration constant `BITE_S=1`.  The mapping rule is "smallest
  tier greater than or equal to the current literal", so no budget
  shrank: at plan time 37 of 86 legs grew, and MEASURED at Stage D
  entry, over the corpus Stages A to C grew to 125 executable legs,
  39 got a larger ceiling (8 moved 5 to 10, 26 moved 15 to 30,
  1 moved 20 to 30, 4 moved 60 to 120) and none got a smaller one.
  A tier is a HANG ceiling, not a performance budget;  pin 9 keeps
  the external `timeout` as the belt, and the measurement log
  (`gate_timed`, one MEASURE line per wrapped perf run) is what
  detects a leg that creeps.  The oracle is
  `rg -q '"\$watchdog" [0-9]' dev/gates.sh` asserted on EXIT
  STATUS, with two positive counts beside it (116 direct tier uses
  after 18 perf runs moved inside `gate_timed`, and 2 calibration
  uses), because an absence assertion alone is satisfied by deletion
  (`PASS-M5D-TIERS`;  `PASS-M5D-TIER-BITES` proves the watchdog
  machinery still cuts at a value a tier names).  The corpus record
  is corrected here: at M4 HEAD 91 lines mention `$watchdog`, 89
  match the corrected oracle, and 86 of those are executable legs;
  at Stage D entry the same three numbers are 130, 128 and 125.
- 2026-09-02 (M5, Stage D): the deny message echoes the blocked
  command (plan D3).  The echo is attacker-controlled data inside a
  JSON string, so it is bounded at 2000 bytes with `stringSlice`
  (`elideAt`, the house elision width) and it depends on Stage A's
  C0 escaper: a control byte goes out as its `\uXXXX` escape, never
  raw.  `PASS-M5D-GUARD-ECHO` is the executable statement of that
  dependency: the emitted envelope must re-parse through the same
  binary to the same bytes.
- 2026-09-02 (M5, Stage D): the third guard is a NARROW port (plan
  D4).  `examples/guard-rewrap.tot` implements criteria 1 and 2 of
  the Python Bash map-over-rewrap guard on raw text: only
  `tool_name = "Bash"`, only a command mentioning `.rs`, only the
  line-pair shape (`let` first token, `?;` last token, next line
  starting `Ok(`).  The scrubber, the block-tail test, the used-name
  test and the net-new comparison are not ported.  The guard fails
  open on everything it does not recognise, matching the other two
  guards (`PASS-M5D-REWRAP-GUARD`).
- 2026-09-02 (M5, Stage D): the hole-anchor measurement (scope item
  11, plan D5).  A STATIC classifier (`dev/hole-anchors.py`) walks
  stdlib/prelude.tot plus examples/*.tot (test fixtures excluded on
  purpose: they stress the kernel and would bias the ratio), finds
  every application of a head whose declared type opens with leading
  erased `Type` binders, and buckets each of the first-k anchor
  arguments: E (expected-type-only: check position and the head's
  result type mentions the anchor's binder), A (argument-driven:
  check position but only a later argument's inferred type fixes it)
  and N (proof plumbing, class keys, infer position).  Measured
  2026-09-02: total 98, E 59, A 9, N 30.  E is an UPPER bound on
  what an expected-type-only hole pass would solve, because the
  classifier does not run the checker.  `PASS-M5D-HOLE-ANCHORS`
  pins schema, bucket sum and an independent recount;
  `PASS-M5D-MEASURE-LOG` pins the section 6 number against the log.
- 2026-09-02 (M5, Stage D): every design pin is a dated entry
  (design pin 18).  Stages A and C wrote their own pin entries;
  Stage D wrote Stage B's above (the B15 handoff) and its own, and
  audited the set: pins 1 to 21 and 23 each appear in a dated
  section 2 entry, and pin 22 (the well-founded spike) is OWED BY
  STAGE E, which appends its own dated block after Stage D lands.
  Section 6's measured claims are rewritten with post-M5 numbers at
  the same shapes (plan D7), so the before and after compare.

- 2026-09-02 (M5, Stage E, SPIKE): `--experimental-wf` exists and is
  off by default (design pin 22, amendment A4;  this block pays the
  pin the Stage D audit recorded as owed).  The flag selects
  `Totality.Structural_wf` in place of `Totality.Structural`.  It is a
  DRIVER flag: `bin/tot.ml` maps it into `Run.policy.wf_rule` once,
  and `Check.define`'s REQUIRED `~rule` argument threads it to the
  guard, so the compiler enumerates every call site and none picks up
  a silent default.  It never reaches the prelude, which folds through
  `Run.default_policy`, and an instance body passes
  `Totality.Structural` literally, so no flag can enter the cache key:
  `Cache.format_version` stays 10.  Cost (measurement M2, medians of
  three at Stage E exit): kernel suite 0.198s, surface suite 0.862s,
  the 80-file default-path transcript 5.547s and byte-identical, the
  flagged worked example 0.024s;  the clause runs only inside
  `guarded_call` on the argument at candidate position k, and at
  `Structural` it costs one constructor comparison there.
  `PASS-M5E-DEFAULT-IDENTITY` pins the byte-identity of the whole
  check corpus without the flag.
- 2026-09-02 (M5, Stage E, SPIKE): the prototype rule, in one
  sentence.  At `Structural_wf`, a recursive call whose argument at
  the candidate position is an APPLICATION is guarded when that
  application's head is a variable already marked `Smaller`.  The
  prototype is KNOWN to be too permissive;  it exists to be measured,
  not to be relied on, and M6 either promotes it or deletes it.
- 2026-09-02 (M5, Stage E, SPIKE): the precondition that keeps the
  witness out.  A branch binder becomes `Smaller` only when the match
  scrutinee is a `Principal` or `Smaller` VARIABLE.  The panel witness
  (`def rec bad : T -> Nat := fun t => match mk (fun n => t) with
  | mk g => bad (g zero) end`) builds its own scrutinee, so its binder
  stays `Other` and the call stays rejected, with the SAME message and
  exit code with and without the flag.  This is the missing
  precondition amendment A4 names, and `PASS-M5E-WITNESS-REJECTED`
  pins it (its leg (a) proves the flag is live, so the negative can
  never pass vacuously).
- 2026-09-02 (M5, Stage E, SPIKE): the clause is not specific to
  accessibility.  It inspects the head's STATUS, never the field's
  TYPE, so it unlocks infinitary structural recursion at the same time
  as `accRec`.  Measurement M1, four shapes run with and without the
  flag on 2026-09-02: `accRec` (argument `h y r`) exit 1 -> exit 0;
  `bad2` (variable scrutinee, argument `g zero`) exit 1 -> exit 0;
  `bad` (the panel witness, built scrutinee) exit 1 -> exit 1;  `bad3`
  (argument `mk g`, a constructor head) exit 1 -> exit 1.  Two of the
  four rows flip, so M6 must decide whether it wants one feature or
  two.
- 2026-09-02 (M5, Stage E, SPIKE): `Acc` needs no universe
  polymorphism and no new kernel typing rule.  The declaration
  `data Acc (0 A : Type 0) (0 R : A -> A -> Type 0) : A -> Type 0 :=
  | acc : (x : A) -> ((y : A) -> R y x -> Acc A R y) -> Acc A R x`
  checks at M4 HEAD at exit 0;  only `Totality.guard` rejects
  `accRec`, and under the flag the full worked example checks at
  exit 0 with the five lines `PASS-M5E-ACC-CHECKS` pins byte for
  byte.
- 2026-09-02 (M5, Stage E, SPIKE): a relation supplied as an INDEXED
  FAMILY does not fit `Acc`'s `R`.  An indexed family's stamped
  domains carry `Quantity.Zero` binders, and
  `(0 _ : Nat) -> (0 _ : Nat) -> Type 0` does not convert with the
  `(w _ : Nat) -> (w _ : Nat) -> Type 0` that `Acc`'s parameter
  demands: `type mismatch: expected (w _ : Nat) -> (w _ : Nat) ->
  Type 0, found (0 _ : Nat) -> (0 _ : Nat) -> Type 0`, exit 1.  The
  Stage E worked example supplies the relation as a `reducible def`
  family (`LtNat`) instead.  The gap is real and is M6 work;  a spike
  does not change the quantity rules.
- 2026-09-02 (M5, Stage E, SPIKE): `Frozen_rec` stays un-motivated
  (measurement M3).  `Frozen` stays dead code for every `Acc` shape M5
  can build: an `(0 a : Acc A R x)` argument fails with `erased
  variable a used at runtime` before the guard runs, because `acc`
  carries two runtime fields and so `Acc` is not zero-eliminable under
  the M4 subsingleton fence;  the M4 Stage C claim is unchanged and
  the `Frozen` emptiness claim stays UNPROVEN.  `Frozen_rec` as a
  definition-time error buys nothing until `Acc` gains an erased
  elimination form, which is a subsingleton-fence change, not a
  totality change.  The two changes are therefore COUPLED: M6 must
  size them together or neither, which confirms the verdict's
  "Deferred and TIED to well-founded recursion" line with an
  executable reason.

## 3.  Core calculus (M0 core, M2 inductives, M3 literals and effects)

Syntax (de Bruijn indices;  binder names are display-only):

    t ::= x | Type l | (q x : t) -> t | fun x => t
        | t t | let x : t = t in t | (t : t) | g | lit
        | match t [as x [in I y1 .. ym] return t] with {| c x .. => t} end

`Term.Match` carries a `scrut_q` quantity stamp (M4 Stage A):
elaboration writes `w`, the checker overwrites it with `0` exactly
when the subsingleton elimination rule (section 2) fires, and only
`Erase` consults it.  The motive's optional `in I y1 .. ym` clause
names an index telescope (outermost first);  its absence is the
M2/M3 non-indexed shape.

`lit` is a `Term.Lit` leaf (M3): a string or int literal, opaque to
conversion beyond structural equality (`VLit` is canonical, like
`VCtor`, but is NOT eliminable and is NOT itself a smaller value for
guarded unfolding).

Surface items: `[reducible] def [rec] [partial] NAME : t := t`,
`check t`, `eval t`, `axiom NAME : t` (M4 Stage B: a postulated
statement, usable only at quantity 0, rejected under `--no-axioms` for
the user file, never for the prelude),

    class NAME (0 A : Type L) := { m1 : T1 ;  .. ; mn : Tn }
    instance : TY := TERM

(M4 Stage D: `class` desugars, in `Run.item`, into a single-constructor
dictionary `data` (the constructor uniformly named `"mk" ^ NAME`) plus
one projection `def` per method;  `instance` registers an ordinary
global under the mangled name `"inst$" ^ C ^ "$" ^ K` read off `TY`'s
own codomain spine, `C (K ..)` or the ground `C K`).  `auto` (an atom,
`Term.Auto`) and `inst C T` (pure sugar for `(auto : C T)`) are the two
surface forms that request instance resolution;  see section 2's dated
Stage D entry for the resolution and coherence rules.  And

    data NAME (0 p : t) .. : IDXTELE Type l := | c1 : t | c2 : t ..

`IDXTELE` (M4 Stage A) is zero or more index binders between the
header's `:` and the terminal `Type l`, each forced to quantity 0: an
explicit `(0 x : T) ->` binder, or the ordinary `T ->` arrow-sugar
form (which is silently forced to quantity 0 rather than rejected,
since the arrow sugar and an explicit anonymous `w` binder produce the
identical surface node -- a section 6 debt).  An explicit NAMED `w`
binder there IS rejected (`data indices must be marked 0`).  Every M2/
M3 `data` declaration (`IDXTELE` empty) is unaffected.

M3 surface sugar, both purely syntactic (desugared in `Elab`, before
any typechecking, never touching `Eval.conv`):

    let* A B x := e in body    -- bindIO A B e (fun x => body)
    let*! A B x := e in body   -- bindDiv A B e (fun x => body)

`A`/`B` are the two EXPLICIT type arguments the desugared `bindIO`/
`bindDiv` application needs (the shipped fallback shape: the bounded
hole pass did not ship this milestone, so every `let*`/`let*!` names
its monad's two type parameters explicitly, exactly as `stdlib/
prelude.tot`'s own `map` calls already do;  a compound type needs
parens, e.g. `let* (Option String) Verdict x := ... in ...`).

A script MAY start with a shebang line (`#!` at column 0, line 1);
the lexer strips exactly that one line before tokenizing.  `--` stays
the only comment marker for everything else.  A hook script's first
line is `#!/usr/bin/env -S tot run`.

The driver grammar (M5 Stage A adds `--strict-json`):

    tot (check|run) [--no-prelude] [--no-axioms] [--serror-exit N]
        [--require-main] [--strict-json] FILE | tot prims

A fail-closed installation spells its hook command
`tot run --strict-json <guard>`;  the flag is enforced by the driver
at the `readStdin` boundary, so the guard script itself needs no
edit (section 2, the M5 Stage A `--strict-json` entry).

Quantities: `0` (erased: types, proofs) and `w` (runtime).  The checker
carries a mode.  Inside types the mode is `0` and every variable is
usable.  At mode `w`, use of a `0`-bound variable is an error.  Argument
positions multiply: applying a `(0 x : A) -> B` keeps the argument
erased even at runtime.

Universes: `Type l : Type (l+1)`.  Pi takes the max of the two levels.
No cumulativity, no universe polymorphism (yet).

Definitional equality: beta, let, eta for functions, and unfolding of
reducible globals during evaluation.  Opaque globals are equal only to
themselves.  Conversion is checked by NbE: evaluate, then compare values.

Totality: a `def rec` body must pass the structural guard: one formal
is the principal argument, and every recursive call passes a strictly
smaller variable there (a binder bound by a match on the principal or
on something already smaller).  Well-founded recursion with measures
comes after M2.  `def rec` that fails the guard stays a hard error;  the
ONE sanctioned escape (M3) is the `partial` keyword, which skips the
guard, forces `reducible = false` and `rec_arg = None`, and requires a
`Div`-headed codomain (`Check.define ~partial`): divergence stays
visible in the type, quarantined to the `Div` rung of the effect
ladder, never silently reachable from an ordinary `def rec`.

The effect ladder (M3, verdict 3.2): `Div` and `IO` are declared-only,
zero-constructor `Ind` bootstrap entries (non-eliminable, for the same
reason `String`/`Int` are), each `(0 A : Type 0) -> Type 0`.  `Div` is
absorbing (no `liftDiv`, no `runDiv`): any def that touches a `Div`
prim has a `Div`-headed type, and only `partial` reaches it from `tot`
source.  `IO` is reified: `pureIO`/`bindIO`/`liftIO` and the native OS
prims never perform a host effect while a value is merely being BUILT
(`Interp.apply` only ever constructs a `VIOAction` action-tree node for
them);  `surface/effect.ml`'s `run_io` is the one place that walks a
built tree and performs the effects it describes, and `Check.define`
separately refuses `reducible` on a `Div`- or `IO`-headed def, so
conversion can never step into an effect either way.  Hard constraint
1, scoped honestly (M3 fixes round 2, R3, 2026-09-01), claims
exactly this: `tot check` performs no host effects and never
executes the interpreter (`surface/run.ml` builds no runtime
environment for the user file at all;  `Interp.define` is never
called for user-file defs in check mode, whatever a def's type
shape, a `Div`/`IO` head or a `Div` value nested under a pure head
such as `Option (Div Nat)` alike).  It does NOT claim bounded
compute: kernel CONVERSION can be driven to unbounded work by
`reducible` definitions (a handful of lines of reducible arithmetic
drives conversion past minutes), the same as any dependent checker,
Coq and Lean included;  opaque-by-default is the mitigation, and a
driver-level check budget is M4 work (section 6).  In RUN mode (M3
fixes round 2, R2) EVERY user def is recorded WITHOUT executing its
body (`Interp`'s `GDeferred`), and forcing memoizes: the first
force, by an eval item or by `main`, stores the computed value back
into the entry's cell, later forces return it (sound: a pure body
is pure, `Div` is pure modulo divergence, and an `IO` body only
ever builds an inert action tree).  A def `main` never mentions
never runs at all, so dead code can neither abort nor hang a guard;
a LIVE def's definition-time abort surfaces at force time.

## 4.  Kernel modules

- `Level`, `Quantity`: newtyped universe levels and usage marks.
- `Term`: core syntax;  quantity-stamped `Lam`/`App`, `Auto` (M4 Stage A,
  CHECK-position only, invalid in checker output), `Match` with a
  quantity-stamped `scrut_q`, an optional `motive` record
  (`m_ind`/`m_idx`/`m_self`/`m_body`, M4 Stage A), and quantity-stamped
  branch binders.
- `Value`: NbE semantic domain.  Closures;  canonical inductive values
  (`VInd`/`VCtor`, params then indices in one applied-args list);
  neutrals are a head plus a frame list (`FApp` applications and
  `FMatch` stuck matches, newest first;  a stuck match's motive is the
  same `Term.motive option` as `Term.Match`'s).
- `Eval`: eval / apply / quote / conv, with guarded unfolding of
  reducible rec globals.  All total, all `Result`.
- `Global`: name -> entry, with entry kinds `Def` (carrying `reducible`
  and `rec_arg`), `Ind` (params telescope, index telescope, level,
  three-state `ctors : ctor_status` -- `Provisional` / `Builtin` /
  `Complete names`, M4 Stage A), `Ctor` (owning inductive, args
  telescope, plus `res_idx`, `full_arity` and `self_rec`, M4 Stage A),
  and `Axiom` (`ax_ty` only, M4 Stage B: no `def`, no `reducible`,
  confined to quantity 0 by `Check`).  Extend only via `Check`.
- `Check`: bidirectional infer/check with quantity modes;  `define`
  (with the rec path), `declare_ind`, `declare_builtin` (M4 Stage A,
  for a type former that will never be `define_ind`'d), `define_ind`,
  and `define_axiom` (M4 Stage B) are the public ways to grow the
  global environment.
- `Totality`: the structural guard for `def rec`;  picks the principal
  argument first-fit.
- `Error`: one variant, no exception anywhere in the kernel.
- `Pp`: printer for terms, erased terms, and errors.
- `Eterm`: erased runtime syntax (untyped lambda calculus with an
  `EErased` residue for type-level terms in runtime position).
- `Erase`: type-directed erasure from kernel-checked terms to `Eterm`.
- `Interp`: call-by-value interpreter over erased terms, with readback.

Surface (library `tot_surface`, in `surface/`):

- `Loc`, `Token`, `Serror`: positions, tokens, surface-pipeline errors.
- `Lexer`, `Parser`: char-list lexer and backtracking-free-by-copy
  recursive-descent parser over the token list.
- `Syntax`: located surface terms and items (`def`/`check`/`eval`).
- `Elab`: scope resolution and sugar only;  all typechecking stays in
  the kernel.
- `Run`: the script driver threading `Global.t` and `Interp.globals`.

The `tot` executable (`bin/`) wraps `Run` as `tot (check|run) FILE`.

## 5.  Milestones

- M0 (done): kernel + tests.  No parser.
- M1 (done): surface syntax, elaborator, erasure, interpreter,
  and the `tot` CLI.  ML-fragment scripts run end to end.
- M2 (done): quantity-stamped core terms with structural erasure;
  parameterized inductives with strict positivity and the predicative
  universe bound;  dependent match;  `def rec` with the structural
  totality guard and guarded unfolding;  `data`/`match`/`def rec`
  surface syntax;  core stdlib (`stdlib/prelude.tot`: Bool, Nat, Option,
  Result, List, Pair).  String and Json moved to M3.
- M3 (done): IO ladder (Tot < Div < IO), literals, String/Int/process/
  JSON/regex stdlib, `let*`/`let*!`/`partial` surface sugar, prelude
  auto-loading with a content-addressed elaboration cache, a shebang
  runner, and `main : IO Verdict` driver-rendered hook output.  Ported
  the first real PreToolUse guard (`examples/guard.tot`: `rg`/`sd`
  house rule) and ran it end to end against allow/deny/other/garbage
  fixtures.
- M4 (done): general recursive indexed inductive families (`Vec`, `Fin`)
  with a Coq-style `match .. as .. in .. return ..` rule and no
  unification;  subsingleton elimination (a three-part syntactic fence
  plus an executable `Frozen`-guard backstop);  homogeneous
  Paulin-Mohring propositional equality (`Eq`/`refl`/`J0`) with
  `subst0`/`sym0`/`trans0`/`cong0` as the rewriting layer (no `rewrite`
  surface form, no K, no UIP);  a postulated `axiom` entry kind plus
  `--no-axioms`;  deterministic single-parameter type classes
  (`class`/`instance`/`auto`/`inst`, resolved from the expected type
  with no search);  and four driver debts closed (`--serror-exit N`,
  `--require-main`, the cache identity's memoized fast path,
  `Syntax.defkind`).
  Ported `examples/guard-classes.tot`, the house `rg`/`sd` guard again
  with the flagged command list behind a type class and two `Eq` proofs.
- M6 candidate list (M5 Stage E rewrote the former `M5:` bullet with
  the spike's numbers;  measure and decide the next tradeoff):
  - Well-founded recursion.  Leading candidate.  `Acc` checks today;
    the whole kernel delta sits in `Totality.guard`;  the prototype
    clause is measured in the Stage E entry of section 2 and is too
    permissive as written (2 of 4 measured shapes flip, including
    infinitary structural recursion).
  - Holes.  Sized by Stage D's hole-anchor count (98 anchors over the
    530-line prelude-plus-examples corpus: 59 expected-type-only, 9
    argument-driven, 30 neither), not by taste.
  - Nested and mutual inductives (would unblock the `Json` cons-cell
    migration to `jarr : List Json -> Json`).  Blocked on the MUTUAL
    gap in `Totality.mentions`, which tests only the family's own
    name, over an emptiness claim SPEC still records as UNPROVEN.
  - Universe polymorphism (`Eq` is currently `Type 0`-monomorphic).
    Not needed by `Acc` (Stage E probe P1).
  - A blocking `--strict-json` posture for `IO Unit` scripts.  The
    Stage A entry in section 2 records the exit-1 route as
    `IO Verdict`-only fail-closed (review round 2026-09-03).

## 6.  Known debts (deliberate)

- No `.mli` interfaces yet except `Level` and `Budget`;  `Global.add`
  is public but documented as kernel-internal.
- No cumulativity: concrete types live one universe up from where
  church-encoded tests want them.
- Apache license text not vendored yet (README notes dual intent).
- Errors carry mostly pre-rendered strings, not structured values (the
  M2 variants add small records).  Fine at this scale;  revisit when the
  elaborator wants error recovery.
- Pin 5's cost half is unpinned (review round 2026-09-03).  Tests pin
  that a memo HIT returns the cached `e_val`;  no timing leg pins what
  a re-derive would cost.  The Stage B M9 mutation re-derived at
  6.212 s against the healthy 0.034 s (183x) and every leg stayed
  green (FAST ceiling 10 s).  The `gate_timed` MEASURE line is the
  manual instrument until a leg pins it.
- Retired (M4 fixes round 2, opus R2;  completed round 3, opus R3-2):
  the CLI file-open no longer raises, and no longer blocks, on ANY
  path.  `surface/source.ml`'s `read` classifies a path before reading
  it, so a directory, a FIFO and an unreadable regular file all take
  the missing-file contract (stdout empty, one driver line on stderr,
  the literal exit 1, outside the `--serror-exit` mapping) instead of
  an OCaml crash dump at exit 2 or, for the FIFO, a blocked open that
  never returned.  The residual permission race is closed by the same
  route: the `Sys_error` from a file that loses its read bit between
  the stat and the open is `cannot be read`, not a raise.  Round 2
  fixed the TARGET file only;  round 3 moved the classifier out of
  `bin/tot.ml` so `surface/bootstrap.ml`'s prelude read, the fourth
  sibling and the one `TOT_PRELUDE` points wherever the operator likes,
  shares it rather than re-deriving it.  A prelude PATH that is a
  directory, a FIFO, unreadable or missing is a DRIVER-level verdict
  about the installation and takes the same contract, including the
  exit 1 that ignores `--serror-exit`;  a prelude whose CONTENT is
  broken stays a script-level `Serror` under the `--serror-exit`
  mapping.  Pinned by `PASS-D-PRELUDE-CHANNEL` (all four cases, bare
  and under `--serror-exit 0`).
- The target of `check`/`run` must be a REGULAR file, deliberately (M4
  fixes round 3, opus R3-4).  `Sys.is_regular_file` is false for every
  non-regular path, not only for a FIFO with no writer, so
  `tot check <(gen)` and `cat f | tot check /dev/stdin` are rejected
  with `<path>: not a regular file` even though the pipe has a live
  writer and M0-M1 read both correctly.  That is the contract, not an
  oversight: hooks are handed real files, and a target that can block
  the checker forever with no timeout of its own is the worse failure.
  Feed generated source through a real temporary file.  The rule
  classifies by the TRUE stat, so what it rejects is the PIPE, not the
  spelling: under an input redirection from a regular file,
  `tot check /dev/stdin < f` is fd 0 pointing at that regular file and
  is ACCEPTED, exactly as a symlink to a regular file is (M4 fixes
  round 4, opus R4-4: the two sentences this replaces said
  `/dev/stdin` was rejected outright, which overstated a code path
  that is right as written).
- Parser and lexer error arms bind structural catch-alls over token and
  char lists.
- `fun` binders cannot carry annotations;  use def types or `(e : T)`.
- No nested or mutual inductives, and no local fixpoints;  deferred
  beyond M4 (M4 Stage A landed general recursive INDEXED families;
  see section 2's dated entry).
- `rec_arg` auto-selection is first-fit: the guard takes the first
  formal that works;  there is no annotation to override it.  A body with
  NO occurrence of its own name skips the guard and stores
  `rec_arg = None` (M2 fixes, Stage A), so this debt is scoped to
  bodies that are genuinely recursive somewhere.
- A match in infer position needs an explicit `as .. return` motive;
  only check position gets the constant-motive shortcut.
- The prelude is a file (`stdlib/prelude.tot`), not an auto-import;
  every script that wants it must inline it until M3.
- Guarded unfolding requires `reducible`: a plain `def rec` never
  unfolds in conversion, even on canonical arguments.
- Retired (M2 fixes, Stage B): Interp readback of a rec global no
  longer diverges.  The interpreter now threads guarded unfolding down
  to the runtime, mirroring the kernel: a rec global stays neutral
  (`EHGlobal`, mirroring `Value.HGlobal`) until applied to a canonical
  constructor value in its principal position, and only then replays
  onto its cached closure.  See Section 2's dated entry for the exact
  rule.
- Retired (M4 Stage A): `Eval.is_canonical`'s second `Global.find_ind`
  lookup (M2 fixes, Round 5 review, T2) on the guarded-unfolding hot
  path.  `Global.ctor_entry` now carries its own `full_arity`, computed
  once at `define_ind` time, so canonicity checks a single field
  instead of chaining through `Global.Ind`.

Known debts entering M4 (M3, carried from `tot-m3-design-verdict.md`
section 6 plus `dev/M3-PLAN.md`'s own additions):

- The prim catalog is an unverified trust boundary: nothing checks that
  an OCaml implementation matches its declared ladder position.  The
  mitigation is the one-line justification per prim and
  `dev/prim-lint.sh`.
- Retired (M4 Stage B): monad laws were invisible to conversion by
  design (`liftIO (pureDiv x)` and `pureIO x` are different neutrals).
  `stdlib/prelude.tot` now postulates `ioBindPure`, `ioBindRet` and
  `ioBindAssoc` as `axiom`s (see section 2's dated entry for the
  consistency argument);  unfolding still never derives them, but a
  proof can now cite them by name.
- `Div` typing gives provenance, not a termination proof.  A guard can
  still hang on a crafted regex, so the calling harness keeps a
  `timeout`.
- Retired (M5 Stage A;  this is the M3-era statement of the same debt
  the "JSON conformance suite" bullet below records, retired with it
  so no stale claim survives): `jsonParse` now decodes `\uXXXX` with
  surrogate PAIRS and returns `none` on a lone surrogate or a short
  escape, and the serializer escapes through `Json_escape.string`
  (all of C0), not `Pp.escape_string`'s four-character set.  See the
  dated section 2 entries and the retirement below.
- Json cons cells (`data Json`, its own `jarrCons`/`jobjCons` spine)
  duplicate the `List` combinators until nested inductives land.  The
  accessor names (`jsonGet`, `jsonToList`, ...) are chosen so the
  migration to `jarr : List Json -> Json` is a stdlib change, not an API
  change.
- `Marshal` cache format fragility: since M3 fixes round 2 (R1) the
  cache is bound to the exact executable, which is the load-bearing
  fence.  The MD5 digest of the running binary's own contents is
  folded into the cache key and re-asserted as a header field that
  `load` verifies before the body digest, so only the binary that
  wrote a blob ever reads it and a forgotten `Cache.format_version`
  bump degrades to two independent cold caches, never a
  foreign-shape blob fed to `Marshal`.  (The round-2 re-probe
  falsified the previous claim that the magic/version/digest check
  alone protects against a forgotten bump: the version is part of
  the KEY, so a mismatched binary always opens a file whose version
  field matches, and the body digest is writer-computed.)  The bump
  checklist beside `Term.t`, `Value.t`, `Eterm.t`, `Global.entry`,
  `Interp.v` and `Prim.t` stays as documentation;  bumping eagerly
  orphans stale files, but nothing rests on it anymore.  Measured
  cost (M3 fixes round 3, O2): hashing the executable's own contents
  took ~3.3ms of an ~8ms warm-hit startup on the build machine.
  Retired, then REVERSED (M4 Stage D D5.3, undone by M4 fixes round 1
  audit F1).  D5.3 made `exe_digest_hex` hash a
  `device:inode:mtime:size` `Unix.stat` string AS the identity.  Audit
  F1 proved that shape forgeable: two byte-different equal-size
  binaries at one inode with mtime restored share all four fields, so
  the second loads the first's blob straight into `Marshal.from_string`
  and the trusted checker state.  What SHIPS is the content hash again.
  `Cache.exe_digest_hex` is `Digest.file` and fails CLOSED (unreadable
  bytes disable the cache for the whole run with one stderr line, never
  a blob whose identity field was derived without reading the binary),
  `format_version` went 9 -> 10 to orphan every stat-identity blob, and
  the chmod-111 gate now asserts the OPPOSITE of what D5.3 implied.
  The `Unix.stat` signature survives only as the MEMO KEY of a fast
  path that skips the ~3.3ms re-hash, with five fields not four
  (`st_ctime` joins them, because `utimes` restores mtime but BUMPS
  ctime), and the content digest is the only thing that can produce the
  digest a memo records.  Pinned by PASS-CACHE-EXEID-CONTENT and
  PASS-CACHE-EXEID-MEMO.  M4 fixes round 5 (ctxcat r5 id 9): the memo
  key renders both timestamps losslessly (`%.17g`), because `%.6f` is
  microsecond resolution while APFS and ext4 provide nanoseconds, so
  two distinct float timestamps could render to one string.  Residual,
  unchanged and deliberate: a memo HIT on a binary whose bytes changed
  while all five fields stayed equal.  It has no unprivileged
  construction on this platform (opus round 2 executed it: `setattrlist`
  with `ATTR_CMN_CHGTIME` is EPERM for a non-root caller and ctime is
  not settable by `utimes` or `utimensat`), a privileged writer is
  already inside the cache directory's trust class, and no rendering
  precision can close it on a mount whose observed ctime does not move
  on an in-place overwrite, because there the two timestamps are
  genuinely equal.
- The cache directory (`$TOT_CACHE_DIR`, default `~/.cache/tot`) is a
  TRUSTED input, the same trust class as the tot binary itself (M3
  fixes, B2).  The digests defend against corruption -- torn
  writes, disk faults, truncation -- and against accidental
  cross-binary drift (round 2, R1), not against an attacker with
  write access to the directory: such an attacker can re-digest a
  forged body and can also read the binary and compute its digest,
  and a cache hit replaces the entire checked prelude
  (what `Bool`, `Verdict` and `deny` mean for a guard).  Do not point
  `TOT_CACHE_DIR` at a directory less trusted than the binary.
- Hole resolution (the C3 bounded pass) fires only in check position, so
  a bare `eval` of a bind chain still needs explicit type arguments.
  Shipped fallback: the pass itself did not ship this milestone (see
  `dev/M3-BUILD-LOG.md`, Stage C), so every `let*`/`let*!` in M3 source
  names its monad's two type parameters explicitly.
- Retired (M4 Stage A): builtin type formers (`String`, `Int`, `Div`,
  `IO`) no longer report `Ind_incomplete` (M2's provisional-inductive
  wording, "its constructors are declared but not yet defined", which
  was never accurate for a former that will NEVER be defined) when
  matched.  `Check.declare_builtin` installs them under
  `Global.ctor_status.Builtin`, and a match on one is the honest
  `Error.Builtin_not_eliminable`.
- `Str` is linked into `tot_kernel` for exactly two prims (`regexTest`,
  `regexMatch`), and `Str`'s match state is process-global.  The regex
  prims must not be re-entered from within a match;  the interpreter is
  single threaded today, so this holds by construction.  M4 should
  replace `Str` with a bounded engine.
- `tot run` stores every user def as a lazy memoized thunk (M3 fixes
  round 2, R2;  the round-1 eager rule let dead code abort or hang a
  guard).  Nothing runs before `main` needs it, so a pathological
  computation in an UNUSED def costs nothing;  the traded-away
  property is failure locality: a LIVE def's definition-time abort
  surfaces only at force time, and `tot check` over-approximates
  run's definition-time failure set for dead code.  Laziness
  protects only defs that neither an eval item nor `main`
  transitively forces (M3 fixes round 3, O5): an eval item forces
  its expression's dependencies transitively, exactly like `main`.
- Retired (M5 Stage C): `tot check` HAS a compute budget now.
  `--check-budget-ms N` (default 0, off) cuts elaboration and
  checking at kernel-node granularity with the reserved exit 3 and
  ONE exact stderr line, `<path>: check budget exhausted (<N> ms)`,
  OUTSIDE the `--serror-exit` mapping;  the LINE, not the code
  alone, is the discriminator a hook matches, because `exitWith`
  lets a script exit any code in 0..255 (amendment A1, design pins
  10 and 19;  `PASS-M5C-BUDGET-FIRES`).  The budget is a
  node-granular cutoff and NOT a real-time guarantee, so the
  external `timeout` around a hook install STAYS as the belt over
  one pathological `Eval` or `Conv` call (pin 9;  the old claim that
  a wrapper timeout "suffices" is retracted in the other direction
  too: a wrapper alone gave exit 124 with two empty channels, no
  verdict).  Opaque-by-default remains the underlying mitigation for
  `reducible`-driven conversion blowup, which is inherent to
  dependent checking and shared with Coq and Lean.
- A MISSPELLED `main` (`mian`, `Main`, ...) is an ordinary def: the
  script stays script mode and exits 0, so a typo'd guard is still a
  silent permit-all BY DEFAULT (M3 fixes, C1';  the reserved-name check
  catches only a def literally named `main` with the wrong type).
  test/fixtures/x11-main-misspelled.tot and gate
  PASS-D-MAIN-MISSPELLED pin the UNFLAGGED residual on purpose.
  Retired (M4 Stage D, D5.2): an installation that wants strictness
  now has `--require-main` (`Run.policy.require_main`), rejecting a
  mainless script with `Serror.Missing_main`;  gate
  PASS-M4D-REQUIRE-MAIN pins the flagged half, m4d-nomain.tot.
- A script-level `Serror` (type error, missing file, bootstrap
  failure, `Main_bad_type`) exits 1 through `bin/tot.ml` by DEFAULT,
  the same exit code the hook protocol assigns to the `ask` verdict: a
  broken guard degrades to ask, not to deny (M3 fixes, C1' records the
  collision).  Retired as a FIXED collision (M4 Stage D, D5.1, user
  decision 4): `--serror-exit N` (0..255) makes the exit code
  configurable per installation;  the default stays 1 this milestone,
  the flip to 3 is a later, separate change made only after installed
  guards migrate.
- Retired (M4 Stage D, D5.4): the `(rec_, partial)` flag pair on
  `Syntax.IDef`, which admitted the illegal `partial = true,
  rec_ = false` state (only the parser maintained the invariant, M3
  fixes C12), is now `Syntax.defkind` (`DNonRec | DRec | DRecPartial`),
  making that state unrepresentable.  `Check.define`'s own kernel
  signature (two booleans) is unchanged.
- The conservative `Level.le` bound on index TYPES (M4 Stage A,
  `declare_ind`).  Agda exempts index types from the predicative
  universe bound;  the exemption is probably sound here too, since no
  constructor field ever stores an index, but it costs `Eq`, `Vec` and
  `Fin` nothing and keeps the Stage A soundness argument one sentence
  long, so the conservative bound ships instead.  Revisit if a
  `Type 1`-indexed telescope is ever needed.
- The `index_expr_clean` backstop (M4 Stage A, `define_ind`) is
  unreachable from source under the `Level.le` bound above: only a
  kernel unit test (A6) exercises it directly.  Do not delete it on the
  grounds that no fixture reaches it (see section 2's dated entry for
  the full reachability argument).
- An explicitly written `(w _ : T) ->` index binder is silently forced
  to quantity 0 rather than rejected (M4 Stage A, `peel_data_codomain`),
  because the ordinary `T ->` arrow-sugar form and an explicit anonymous
  `w` binder produce the identical surface node;  threading a "came
  from arrow sugar" bit through `Syntax.SPi` to distinguish them would
  pollute every term for one error message.  A named `w` binder (e.g.
  `(w n : T) ->`) IS rejected.
- `Eq` is monomorphic at `Type 0` (M4 Stage B, user decision 6): a
  `data` declaration cannot be universe-polymorphic (tot has no
  universe polymorphism at all yet, section 6's earlier "no
  cumulativity" debt), so an equation between two `Type 1` values (for
  instance, two inductive TYPE FORMERS rather than two ordinary values)
  needs its own duplicate `Eq1`/`subst1`/`sym1`/`trans1`/`cong1` layer,
  hand-written exactly like `Eq`'s own.  Nothing in this milestone needs
  one;  revisit if a `Type 1`-valued equation is ever needed.

Known debts entering M5 (M4, carried from `dev/M4-PLAN.md`'s own
"Known debts entering M5" section):

- The `Frozen` emptiness claim stays UNPROVEN (M4 Stage C's own dated
  entry;  restated through M5).  The fence is syntactic and the
  backstop is executable;  revisit if mutual or nested inductives
  ever land, since either could open a gap the current fence does
  not cover.  M5 ties it to well-founded recursion: on every def M5
  can construct, `Frozen` is dead code, so promoting it to a
  definition-time error buys nothing until `Acc` values appear at
  erased quantity, which is exactly what the Stage E spike sizes.
- The `$`-mangled instance namespace (M4 Stage D) is flat, matching the
  flat global namespace.  There are no per-module instances because
  there are no modules.
- No holes, again (a pre-M4 debt too): every proof names its type
  arguments.  The "measure after M4" instruction is DISCHARGED here
  (M5 Stage D, scope item 11).  `python3 dev/hole-anchors.py` (add
  `--log <path>` for the machine line, `--count-sites` for the
  independent recount) statically classifies every leading erased
  `Type` anchor argument over stdlib/prelude.tot plus
  examples/*.tot;  measured 2026-09-02:
  ANCHORS total=98 expected-type-only=59 argument-driven=9
  neither=30.  E = 59 is an UPPER bound on what an
  expected-type-only hole pass would solve, because the classifier
  does not run the checker.  The two structural reasons a hole pass
  is real work stand: `infer`'s App arm consumes one argument at a
  time and evaluates the stamped argument to instantiate the
  codomain (lib/check.ml:770-779), and `check` has no App arm at
  all, so argument-driven anchors need bidirectional application
  checking that does not exist today.  Holes stay a candidate,
  now with a number attached (`PASS-M5D-HOLE-ANCHORS`,
  `PASS-M5D-MEASURE-LOG`).
- Frozen-guard fixtures (M4 Stage C: m4c-frozen.tot and friends) must be
  maintained as the erasure story evolves.
- Nested inductives and the `Json` cons-cell migration to
  `jarr : List Json -> Json` (a pre-M4 debt, restated): the door
  stays SHUT through M5, and the recorded REASON is corrected here
  (design pin 14).  The gap is the MUTUAL gap: `Totality.mentions`
  tests only the family's OWN name (lib/check.ml:1828), so a
  recursive PAIR of families reads as non-self-recursive.  It is NOT
  a nesting gap, and the earlier text claiming so was wrong:
  `Totality.mentions` recurses into both halves of `App`
  (lib/totality.ml:52), so `jarr : List Json -> Json` gives
  `self_rec = true` already.  This entry replaces the losing claim.
- The bounded regex engine.  `Str` stays single-threaded-safe;  the
  replacement is its own mini-milestone.
- Retired (M5 Stage A): the JSON conformance suite.  The parser
  accepts `\uXXXX` with surrogate-pair decoding and returns `none`
  on a lone surrogate or a short escape;  the serializer and the
  verdict envelope quote through `Json_escape.string` (RFC 8259
  short forms plus `\u00XX` for the rest of C0), while
  `Pp.escape_string` stays the SOURCE escaper (design pin 13).
  Pinned by `PASS-M5A-BYPASS` (the live `grep` escape bypass,
  now denied) and `PASS-M5A-ENVELOPE-VALID` (envelope and serializer
  each satisfy a conforming parser, proved site-independently).
- Raw C0 bytes inside a parsed JSON string body are ACCEPTED (M5
  Stage A, a deliberate non-change;  section 2 records the reasons and
  the decoded-NUL allow behaviour).  RFC 8259 forbids them;  revisit
  only against a measured exploit.
- `Cache.format_version` stayed 10 through M5 Stage A (a deliberate
  no-bump;  section 2 records the five reasons), so a reviewer must
  not read the missing bump as an oversight.
- The prim catalog's unverified trust boundary (a pre-M4 debt,
  restated).
- `Div` typing gives provenance, not a termination proof (a pre-M4
  debt, restated).
- Well-founded recursion: SCHEDULED as an M5 SPIKE, not a feature
  (amendment A4, design pin 22, owned by M5 Stage E).  The spike
  lives behind an experimental flag;  the default path stays
  byte-identical, and the panel's divergence witness is a pinned
  NEGATIVE under the flag (measured on this binary 2026-09-02: the
  positivity-passing `data TT := | mk : (w f : Nat -> TT) -> TT`
  declares at exit 0 and the recursive def over it fails the
  structural termination guard at exit 1, so the guard alone rejects
  it today).  Proposal 1's evidence stands: `Acc` (indexed families,
  M4 Stage A) checks today at exit 0, and only `Totality.guard`
  rejects `accRec`.  DELIVERED by Stage E (design pin 22): what the
  spike MEASURED is in the dated section 2 Stage E block (the M1
  shape table, 2 of 4 rows flip;  the M2 cost medians with the
  byte-identical default transcript;  the M3 `Frozen_rec` coupling),
  and what it did NOT close is: a sound admission rule (the prototype
  clause inspects the head's status, never the field's type, so it
  admits infinitary structural recursion `bad2` alongside `accRec`);
  the indexed-family relation gap (`R` demands `w`-quantity domains,
  an indexed family stamps `0`);  and the erased elimination form for
  `Acc` (coupled to the subsingleton fence).  M6 either promotes the
  prototype behind a sound side condition or deletes the flag;  no
  stage may promote the spike to a shipped feature.
- Retired (M5 Stage C, design pin 21, amendment A3): `--require-main`
  was ADVISORY under a fail-open exit mapping (M4 fixes round 2, opus
  R4).  A file that exists but declares no `main` was routed through
  `serror_exit`, so `tot check --require-main --serror-exit 0 ok.tot`
  wrote the "this file must define a driver main" line to stderr and
  exited 0, which a hook reads as allow;  executed on M4 HEAD, that
  repro did print 0.  On 2026-09-02 amendment A3 moved the mainless
  verdict onto the DRIVER contract, exactly like a missing file: the
  same stderr line, byte for byte, and the literal exit 1, outside the
  mapping.  New repro: `printf 'def x : Bool := true\n' > ok.tot;
  tot check --require-main --serror-exit 0 ok.tot; echo $?` prints 1,
  with one stderr line.  An ordinary script error keeps the mapping
  (`PASS-M5C-REQUIRE-MAIN-OK`;  `PASS-M5C-REQUIRE-MAIN-DRIVER` pins
  the four driver invocations).
- Retired (M4 fixes round 3, opus R3-1): the `(class, key)` instance
  MEMO is IMPLEMENTED.  `Check.resolve_auto` threads an immutable map
  beside the fuel, scoped to one `Term.Auto`, keyed on the class name
  paired with the class argument's own quoted term (the FULL key, not
  its head symbol, which two sibling sub-goals of a two-type-binder
  instance can share while differing in its arguments;
  `PASS-M4FIX-INST-MEMO-KEY` pins that).  Shared sub-goals are answered
  from the first derivation, so a branching telescope resolves instead
  of reporting `Inst_depth`, and resolution is linear in the query's
  nesting rather than exponential in it.
  The round-2 entry this replaces was wrong in three clauses, recorded
  here because the wording steered the fix: the fence was NOT "two
  dictionary binders on the same type variable" (two DIFFERENT classes
  failed too, from nesting 6), the trade was NOT "instead of running
  2^n sub-resolutions" (eight independent chains run `k*n`
  sub-resolutions, linear, and were rejected at k=8 n=20), and the memo
  did not buy reach that was merely unbought:  round 1 HAD that reach
  and round 2 removed it, so the memo RESTORED working programs.  Fuel
  survives only as a backstop over the structural termination argument,
  resized to 16x the round-2 formula floored at 10000.  "It must not
  fire on legitimate input" is the round-3 INTENT, not an achieved
  property: M4 fixes round 6 measured a leaf on the class-count
  dimension where it still does, and the entry below records it.
- What remained after that memo was a TERM SIZE limit, not a
  resolution one (M4 fixes round 3, opus R3-1) -- PAID by M5 Stage B
  (design pins 1 to 6), with the numbers restated here at the SAME
  shapes so the before and after compare.  A branching telescope's
  resolved dictionary is a binary tree: `(0 A : Type 0) -> C A ->
  C A -> C (Box A)` at nesting n used to emit a term of 2^n nodes,
  because `Term.t` has no sharing (still true: pin 1 leaves `Term.t`
  unchanged).  The `Auto` site now emits a LOCAL `let`-nest over the
  memo's own entries instead, and the fix is that nest, NOT
  hash-consing: physical identity does not survive `Marshal`.  The
  mandatory re-check, evaluation and erasure walk the nest, whose
  size is quadratic in n, not exponential: `term_size` 694 at
  nesting 16 against the un-shared 458714 (`PASS-M5B-SHARE-SIZE`).
  Measured on this binary 2026-09-02 (dev/gen-inst-branching.py, the
  m4fix-inst-branching shape;  M4 numbers in parens): nesting 20
  checks in 0.07s and runs in 0.15s (was 19.6s total, 16.8s of it
  the re-check);  nesting 16 in about 0.08s (was 1.03s);  nesting 12
  in about 0.02s (was 0.064s).  Non-branching shapes were unaffected
  before and stay unaffected.  Pinned by `PASS-M5B-BRANCHING-20`
  (nesting 20 under the FAST tier, about 300x headroom),
  `PASS-M4FIX-INST-BRANCHING` and, at depths whose emitted term is
  small, by `PASS-M4FIX-INST-SPEC16`, `PASS-M4FIX-INST-TWOCLASS`,
  `PASS-M4FIX-INST-CHAINS` and `PASS-M4FIX-INST-SMALL-REACH`.
- `Check.inst_fuel` is a backstop with MEASURED margins, and neither an
  unreachable one nor a time budget (M4 fixes round 6, opus R6-1;
  updated M5 Stage C;  this one entry carries both halves, because the
  same walk pays them).  Reach: M5 Stage C multiplied the round-5
  shape by `1 + class_count` (section 2's dated entry), paying the M4
  leaf: on the generated shape of `dev/gen-inst-fuel.py classes K`,
  the measured M4 leaf was K = 60 resolving and K = 61 reporting
  `Inst_depth`, and BOTH now resolve.  The re-bisection
  (`dev/bisect-inst-classes.sh`: doublings 61, 122, 244, 488 under an
  8 MB file ceiling and a 120 s probe ceiling) found NO rejecting K:
  NOLEAF<=488, measured 2026-09-02 on this binary.  On this shape the
  charge and the bound are both about quadratic in K, so this is a
  measurement, not a proof;  re-run the bisection whenever
  `build_instance`'s charge accounting or `inst_fuel` changes
  (`PASS-M5C-LEAF-MARGIN`'s comment carries the probe table and the
  recipe;  its pin K = 122 is bound by the 1 MB affordability
  ceiling, not by a margin, since no leaf exists to keep a margin
  under;  `PASS-M4FIX-INST-CLASSES` keeps its K = 57 fixture, a gate
  that got cheaper to pass and is still a gate).  Time: the counter
  is fuel, not wall clock, so a large LEGITIMATE resolution still
  buys wall clock;  what M5 Stage C changed is that the operator now
  GETS A VERDICT where exit 124 and two empty channels used to be.
  The same 800-box linear chain (7.2 KB, the `m4fix-inst-chains`
  shape) that exceeded a 60 s external `timeout` with both channels
  empty on M4 HEAD now reports
  `<path>: check budget exhausted (<N> ms)` at the reserved exit 3
  under `--check-budget-ms N` (`PASS-M5C-BUDGET-FIRES`).  The budget
  covers elaboration and checking only;  decision 13's external
  `timeout` stays the belt for `Interp` execution and for any single
  non-polling call.

New debts created by M5 Stage D (deliberate, each with its
compensating instrument):

- Tier slack.  39 of the 125 executable gate legs now carry a larger
  hang ceiling than their old literal (8 moved 5 to 10, 26 moved 15
  to 30, 1 moved 20 to 30, 4 moved 60 to 120;  measured at Stage D
  entry, the plan-time count over the M4 corpus was 37 of 86).  A
  leg that doubles in runtime can stay green where it used to go
  red.  The compensating instruments are the measurement log, which
  records elapsed wall time per wrapped perf run on every battery
  (`gate_timed`, `PASS-M5D-MEASURE-LOG`), and
  `PASS-M5B-SHARE-SIZE`, which is machine-independent and survives
  any later tier relaxation.
- The rewrap guard is a narrow port (plan D4).  Both directions of
  the difference from the Python guard are recorded: LOUDER on a
  pre-existing rewrap tail inside a heredoc (no net-new comparison),
  QUIETER on a single-line `let x = e?; Ok(x)` tail (the line-pair
  shape needs two lines).  The scrubber, the block-tail test and the
  used-name test are not ported.
- The echoed command is bounded at 2000 bytes and the elision marker
  `... (elided)` is prose, not a machine-readable flag.  A consumer
  cannot tell an elided command from one that genuinely ends in that
  literal text.
- Guard helper duplication.  `firstNonEmpty`, `lastOr`, `splitEach`,
  `firstToken`, `orEmpty` and `elideAt` now exist in two example
  files, because there are no modules and the global namespace is
  flat.  A fix to one is a fix to neither until somebody copies it.
  The prelude is the natural home and the move is a cache-format
  change, so it waits.
- Key-TYPE sharing stays unspent (design pin 7).  Stage B's exit
  measurement (term_size 694 against the 4000 gate) left no need to
  share the per-slot key TYPES through the same materializer;  the
  option is recorded here and needs no new design if a later corpus
  reopens it.
