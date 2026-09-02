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
- M5: well-founded recursion (now unblocked by indexed families), holes,
  nested/mutual inductives (unblocks the `Json` cons-cell migration to
  `jarr : List Json -> Json`), universe polymorphism (`Eq` is currently
  `Type 0`-monomorphic).  Then measure and decide the next tradeoff.

## 6.  Known debts (deliberate)

- No `.mli` interfaces yet except `Level`;  `Global.add` is public but
  documented as kernel-internal.
- No cumulativity: concrete types live one universe up from where
  church-encoded tests want them.
- Apache license text not vendored yet (README notes dual intent).
- Errors carry mostly pre-rendered strings, not structured values (the
  M2 variants add small records).  Fine at this scale;  revisit when the
  elaborator wants error recovery.
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
- JSON conformance gaps (recorded by the M3 fixes' C5' doc sweep;
  `lib/interp.ml`'s comments already referred here): `jsonParse`
  supports no `\uXXXX` unicode escapes, and `jsonSerialize` escapes
  only `Pp.escape_string`'s set (backslash, quote, newline, tab),
  which covers every string `jsonParse` can itself produce but not
  other control characters reachable from string literals.  A
  conformance suite is M4+ work.
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
- `tot check` has no compute budget: kernel conversion can be driven
  to unbounded work by `reducible` definitions (M3 fixes round 2,
  R3;  inherent to dependent checking, shared with Coq and Lean).
  Opaque-by-default is the mitigation;  a driver-level fuel or
  wall-clock budget flag for check mode is M4 work.  Until then,
  hook installations should wrap `tot` in an external `timeout`,
  exactly as decision 13 already prescribes for hung guards.
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
  entry).  The fence is syntactic and the backstop is executable;
  revisit if mutual or nested inductives ever land, since either could
  open a gap the current fence does not cover.
- The `$`-mangled instance namespace (M4 Stage D) is flat, matching the
  flat global namespace.  There are no per-module instances because
  there are no modules.
- No holes, again (a pre-M4 debt too): every proof names its type
  arguments.  Measure after M4;  holes stay an M5 candidate.
- Frozen-guard fixtures (M4 Stage C: m4c-frozen.tot and friends) must be
  maintained as the erasure story evolves.
- Nested inductives and the `Json` cons-cell migration to
  `jarr : List Json -> Json` (a pre-M4 debt, restated): waits for the M5
  positivity door.
- The bounded regex engine.  `Str` stays single-threaded-safe;  the
  replacement is its own mini-milestone.
- The JSON conformance suite (no `\uXXXX` escapes, partial serializer
  escaping;  a pre-M4 debt, restated).
- The check-budget flag (a pre-M4 debt, restated).  A driver wrapper
  `timeout` suffices for hooks today.
- The prim catalog's unverified trust boundary (a pre-M4 debt,
  restated).
- `Div` typing gives provenance, not a termination proof (a pre-M4
  debt, restated).
- Well-founded recursion, now UNBLOCKED by indexed families (M4 Stage
  A): an M5 candidate, not scheduled.
- `--require-main` is ADVISORY under a fail-open exit mapping (M4 fixes
  round 2, opus R4).  A file that exists but declares no `main` is
  routed through `serror_exit`, so `tot check --require-main
  --serror-exit 0 ok.tot` writes the "this file must define a driver
  main" line to stderr and exits 0, which a hook reads as allow.  The
  missing-FILE branch is deliberately outside that mapping;  a mainless
  file is not, because it is a script-level verdict about content, not
  a driver-level verdict about the target's usability.  An operator who
  wants a mainless script to FAIL open-mapped must leave
  `--serror-exit` at its default.  Repro:
  `printf 'def x : Bool := true\n' > ok.tot;
  tot check --require-main --serror-exit 0 ok.tot; echo $?` prints 0.
  Changing it is a behavior change to a shipped flag, so it waits for a
  deliberate decision rather than riding a fix round.
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
- What remains after that memo is a TERM SIZE limit, not a resolution
  one (M4 fixes round 3, opus R3-1).  A branching telescope's resolved
  dictionary is a binary tree: `(0 A : Type 0) -> C A -> C A ->
  C (Box A)` at nesting n emits a term of 2^n nodes however fast the
  walk that built it was, because `Term.t` has no sharing.  Resolution
  is now linear in n, but the mandatory re-check of the resolved
  candidate, its evaluation and its erasure are each linear in that
  emitted TERM.  Measured on `test/fixtures/m4fix-inst-branching.tot`
  (nesting 20, about a million nodes): 19.6s total, of which 16.8s is
  the re-check and 2.8s everything else;  nesting 16 is 1.03s and
  nesting 12 is 0.064s.  Non-branching shapes are unaffected at any
  depth (nesting 400 in 3.7s, unchanged since round 1).  Term-level
  sharing (a `let`-nest over the memo's own entries, or hash-consing)
  is the fix and is an M5 candidate;  it needs de Bruijn shifting over
  a term the memo currently stores at one fixed context depth, which is
  why it did not ride a fix round.  Pinned by
  `PASS-M4FIX-INST-BRANCHING` (resolution required, 60s budget) and, at
  depths whose emitted term is small, by `PASS-M4FIX-INST-SPEC16`,
  `PASS-M4FIX-INST-TWOCLASS`, `PASS-M4FIX-INST-CHAINS` and
  `PASS-M4FIX-INST-SMALL-REACH`.
- `Check.inst_fuel` is a backstop with MEASURED margins, and neither an
  unreachable one nor a time budget (M4 fixes round 6, opus R6-1;  this
  one entry carries both halves, because the same walk pays them).
  Reach: the bound clears every shipped gate shape with a recorded
  margin (`PASS-M4FIX-INST-WIDE` at L = 2500, `PASS-M4FIX-INST-CLASSES`
  at K = 57, D9f's charge of about 10710 against a bound of 147312), but
  a WIDE-CLASS query rejects beyond a measured leaf: on the generated
  shape of `dev/gen-inst-fuel.py classes K`, K = 60 resolves and K = 61
  reports `Inst_depth` even though K = 61 is registrable and its walk is
  structurally terminating.  Round 5's product term moved that leaf by
  under 10 percent (round-4 bisection K = 56 / K = 57;  a round-6
  differential reverting only the width term, K = 55 / K = 56), because
  the class count enters the CHARGE through both the (class, key) pair
  count and the telescope length while every term of the bound is linear
  in `per_key`.  The pinned K = 57 therefore sits three classes under
  the leaf, about 5 percent, and the leaf must be re-measured whenever
  `build_instance`'s charge accounting or `inst_fuel` changes (the gate
  comment carries the recipe).  Time: the counter is fuel, not wall
  clock, so a large LEGITIMATE resolution buys unbounded time with no
  verdict.  A sub-2 KB doubling type costs 41.4s at depth 18 at exit 0,
  and a plain LINEAR chain of about 800 nested boxes (7.2 KB, the
  `m4fix-inst-chains` shape) exceeds a 60s budget with no verdict at
  all, exit 124.  Closing either half is M5 work: hash consing for the
  cost, and the driver-level check budget above for the cutoff.  Until
  then a hook installation wraps `tot` in an external `timeout`, exactly
  as decision 13 prescribes.
