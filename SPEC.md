# tot: design record

Working name: `tot` (total). Rename is a find/replace away.

## 1. Purpose

One language for everyday automation: PreToolUse hooks, gate scripts,
verdict CLIs, small tools. The house rules are the semantics:

- No exceptions. Errors are values (`Option`, `Result`, error variants).
- Total by default. Every hook terminates; the checker proves it.
- No loop keywords. Recursion and combinators only.
- Exhaustive matches. No catch-all arms.
- Partial operations (indexing, division) do not exist. Each one either
  returns an `Option` or demands a proof.
- A hook is a typed value indexed by its JSON schema and its permitted
  exit codes. A guard that typechecks cannot emit garbage.

## 2. Decision log

- 2026-08-31: goal triangle set: Lean-4-strength types, OCaml-speed
  checking on the ML fragment, OCaml-grade expressiveness. Uniform speed
  is impossible (conversion runs user code); pay-as-you-go is the bar.
- 2026-09-01: host language = OCaml (user decision).
- 2026-09-01: kernel-first (user decision). Small dependent kernel now;
  surface language on top; no retrofit.
- 2026-09-01: first dogfood target = a PreToolUse guard (user decision).
- 2026-09-01: weak definitional equality. Globals are opaque by default;
  evaluation unfolds only globals marked reducible; conversion never
  unfolds on its own. Predictable check times; more explicit proofs.
- 2026-09-01: quantities 0/omega (QTT fragment). Quantity-0 binders erase
  before evaluation. Full linearity (quantity 1) is deferred.
- 2026-09-01: predicative universe hierarchy, no cumulativity in v0.
  Revisit at M2 if annotation burden is too high.
- 2026-09-01: execution model = erase, then interpret in-process, with a
  content-addressed cache of elaborated modules. Native codegen is a
  later milestone.
- 2026-09-01: surface pins (M1). `:=` introduces def and let bodies;
  `--` starts a line comment; quantity markers are `0` and `w`, where
  `(w x : A)` marks quantity only when another identifier follows the
  `w` (so `(w : A)` is a binder actually NAMED `w`); `A -> B` is sugar
  for `(w _ : A) -> B`; bare `Type` defaults to level 0; chained binder
  groups before one arrow (`(a : A) (b : B) -> C`) are not supported in
  v0, each group needs its own `->`.
- 2026-09-01: erasure pin (M1). Type-directed single pass mirroring
  `Check`'s bidirectional shape; no conversion checks, types are
  consulted only for Pi quantities. Quantities are NOT stamped on core
  terms yet; revisit at M2 when inductives force a `Term` revision.
- 2026-09-01: runtime pin (M1). Call-by-value over erased terms. Every
  global unfolds at runtime; reducibility is a conversion-time notion
  only. Global values are cached closed at definition time.
- 2026-09-01: items pin (M1). Scripts are sequences of `def` (optionally
  `reducible`), `check`, and `eval` items. Check mode prints types; run
  mode executes `eval` items and prints the readback.
- 2026-09-01 (M2): stamped quantities. `Term.Lam`/`Term.App` carry a
  `Quantity.t`. Elaboration and hand-built terms write `w` placeholders;
  the checker OVERWRITES stamps from the Pi it checks against and
  returns the stamped term — checker output is authoritative. `(t : T)`
  annotations steer checking only: `Ann` is dropped from checker output.
  Erasure is purely structural over stamped terms (no types, no globals
  consulted); this supersedes the M1 erasure pin.
- 2026-09-01 (M2): inductives. Parameterized only; indices deferred to
  M4 (they arrive with `Eq`; the match motive already abstracts the
  scrutinee, so indices are additive). Flat namespace: the inductive
  name and every constructor name are globals in the one map (entry
  kinds `Def`/`Ind`/`Ctor`). Parameters are ALWAYS quantity-0: param
  arguments at constructor applications erase, so runtime constructor
  values carry kept (`w`) args only. Strict positivity with uniform
  parameters: a constructor argument type may mention the inductive `I`
  only as `I p1..pn` (its own params, in order), either as the whole
  argument type or as the codomain of a Pi telescope whose domains never
  mention `I`; no nested, no mutual, no local fix in v0. Predicative
  universe rule: each constructor argument type's level must satisfy
  `Level.le` against the declared level of the inductive.
- 2026-09-01 (M2): recursion. Top-level `def rec` only. The recursive
  global is opaque while its own body is checked (recursive calls do not
  unfold); a structural totality guard must accept the stamped body and
  picks the principal argument first-fit. Evaluation unfolds a REDUCIBLE
  rec global only when its principal argument is a canonical constructor
  value (guarded unfolding), so conversion cannot diverge; opaque rec
  globals never unfold in conversion. The runtime interpreter is
  unaffected (call-by-value on erased terms; every global unfolds at
  application time). No eta for inductives: a neutral never equals a
  constructor value.
- 2026-09-01 (M2): surface pins. `data NAME (0 p : T) .. : Type L := |
  c1 : CT1 | c2 : CT2 ..` — every parameter group must carry the literal
  `0` marker; `: Type L` is required (`L` defaults to 0); zero
  constructors is legal (empty type). `match S with | c x y => B | ..
  end` with optional `as x return P`; branch patterns are flat (a ctor
  name plus distinct binder names); `end` is required; branches must
  list the constructors exactly in declaration order. A match in infer
  position needs the explicit motive; in check position a motive-free
  match reuses the expected type as a constant motive. Recursive
  definitions: `[reducible] def rec NAME : TY := BODY`. The checker
  stamps branch binders with the constructor telescope's quantities, so
  erasure stays structural.
- 2026-09-01 (M2): deferred to M3: literals, `String`, `Json`, and
  prelude auto-loading (`stdlib/prelude.tot` is a script you run, not an
  implicit import).
- 2026-09-01 (M2 fixes, Stage A): inductive parameters may live at ANY
  universe; the declared level bounds constructor ARGUMENTS only. This
  follows the Coq/Lean precedent: parameters are not fields, so they
  never enter the positivity/universe accounting that bounds a
  constructor's own args.
- 2026-09-01 (M2 fixes, Stage A): `Global.Ind.ctor_names` is
  `string list option`: `None` while an inductive is declared but not
  yet defined (between `declare_ind` and `define_ind`), `Some names`
  once complete. A reader that needs to eliminate the inductive (a
  match's scrutinee type) rejects a `None` window with `Ind_incomplete`;
  a second `define_ind` call on an already-complete inductive rejects
  with `Ind_redefined` instead of silently overwriting `ctor_names`.
  Closes the window where a constructor argument's own type could
  eliminate its still-declaring inductive with a vacuously exhaustive
  empty match.
- 2026-09-01 (M2 fixes, Stage A): a `def rec` body with NO occurrence of
  its own name skips the structural totality guard entirely and stores
  `rec_arg = None`, behaving exactly like a plain `def` (unfolds in
  conversion when reducible, no guarded-unfolding gate). Previously
  first-fit was vacuously satisfied at the first formal (k = 0) even
  with zero recursive spine, which could pin `rec_arg` to a
  non-canonical (non-ctor-typed) formal and block unfolding forever.
  This also makes a zero-formal `def rec` with no self-occurrence check
  as a plain def instead of failing `Termination`.
- 2026-09-01 (M2 fixes, Stage A): guarded unfolding's canonical check
  (`Eval.is_canonical`) now means a data constructor FULLY applied
  (parameter arity plus its own args telescope arity, looked up from the
  `Ctor`/`Ind` globals), not merely `VCtor _` regardless of how many
  args it has received. A partially applied constructor in the
  principal position no longer unlocks a rec global's unfolding.
  `Eval.run_match` also gained an arity backstop (mirroring
  `Interp.run_match`'s existing one): a branch whose binder count
  disagrees with the scrutinee's kept args is `Branch_mismatch` rather
  than a silently misaligned environment.
- 2026-09-01 (M2 fixes, Stage A): check-position matches now
  materialize an explicit constant motive in checker OUTPUT (quoted
  from the expected type, weakened under the extra scrutinee binder by
  NbE de-Bruijn-level quoting) instead of storing `motive = None`.
  Infer position and explicit `as .. return` are unchanged. This makes
  a motive-free match and an equivalent explicit-motive match produce
  FMatch frames that compare equal in conversion; previously two
  identically-reducing stuck matches could fail conversion purely by
  spelling (`None` vs `Some` on the motive option).
- 2026-09-01 (M2 fixes, Stage B): runtime guarded unfolding for rec
  globals. `Interp`'s global table now carries each def's `rec_arg`
  alongside its cached value, and its value domain gains a neutral
  `EHGlobal` head mirroring the kernel's `Value.HGlobal`. Applying a rec
  global freezes into (or extends) an `EHGlobal` neutral application
  instead of entering its closure until the accumulated frames' leading
  argument at position `rec_arg` is a canonical constructor value: fully
  applied counting only KEPT (quantity-`w`) args, since an erased
  program never carries params or quantity-0 args at runtime (the
  runtime analogue of F4's kernel-level check, over `Eterm`'s already-
  erased arity instead of the kernel's full unerased one). Once the
  guard is met, the accumulated frames replay onto the def's cached
  closure. Non-rec globals are unaffected: they still unfold
  unconditionally at application time. This retires the interp-readback
  debt below: `quote` no longer re-executes a rec global's frozen match
  branches under every fresh binder it peels (which diverged, since
  each peel re-applied the eager closure and froze one level deeper);
  a rec function value now reads back as its frozen neutral
  application, and closed (fully canonical) calls compute exactly as
  before. (2026-09-01, M2 fixes Round 2, R0): since `rec_arg` counts the
  kernel's UNERASED formal telescope while `Interp`'s spine is ERASED,
  `surface/run.ml` remaps it before calling `Interp.define` by counting
  the quantity-`w` formals strictly before `rec_arg` in the stamped
  def's own `Lam` telescope. (2026-09-01, M2 fixes Round 4, revising
  Round 3's S0): when the guarded formal is itself quantity-0, the
  runtime spine never carries it, so there is no principal position left
  to test; the def remaps to `None` (eager unfold, plain-def behavior at
  runtime), never a freeze. This is SOUND: a quantity-0 formal can only
  be eliminated (matched on) while checking at `Quantity.Zero` mode (the
  same attenuation `Check.infer`'s `Var` rule enforces), so every branch
  of a match on it, and every recursive call reachable through those
  branches, is itself checked at mode `Zero`. `Erase.term`'s
  `App (Quantity.Zero, f, _a) -> term ctx f` arm drops such a subterm
  WHOLESALE at its use site without walking it, so the ERASED body of a
  rec def guarded on an erased formal contains NO occurrence of the
  def's own global name: eager unfolding cannot loop, and it computes
  the definitionally correct value. Mechanically confirmed for the
  `ghost` witness (`test/fixtures/s0-erased-guard.tot`) by a kernel-level
  `Eterm.t` walk, `test/main.ml`'s "T0: rec def guarded on an erased
  formal has no self-reference after erasure". Round 3's S0 text (freeze
  on an out-of-range index) is superseded: that divergence claim had no
  actual witness, and re-verification killed a fresh over-application
  variant of the same claim. See `dev/M2-FIXES-LOG.md` "## Round 4" for
  the full correction.
- 2026-09-01 (M3): the effect ladder, literals, stdlib breadth, real
  hooks. Design authority: `tot-m3-design-verdict.md` (M3-SYNTH), the
  judged synthesis of the three M3 design proposals, transcribed into
  `dev/M3-PLAN.md`. Verdict 3.10's fourteen decisions, transcribed:
  1. `Term.Pi`, `Lam` and `App` keep their M2 arity. Effects are types,
     not a stamp.
  2. `Prim` is a fourth `Global.entry` kind with no `def` and no
     `reducible` field.
  3. `Prim.t` is a closed enum with a name and arity table, no
     closures, for the sake of the `Marshal` cache.
  4. `Prim.arity` counts kept arguments only.
  5. `String`, `Int`, `Div` and `IO` are zero-constructor `Ind`
     bootstrap entries. `Json`, `ProcessResult`, `Unit`, `Ordering` and
     `Verdict` are ordinary prelude `data` items.
  6. No `liftDiv`, no `runDiv`. `Div` is absorbing.
  7. One elaboration per literal token; no numeric overloading; `Nat`
     stays Peano and separate from `Int`.
  8. `Interp.quote` on `VPrim` rebuilds the spine; on `VIOAction` it
     returns `Not_quotable`.
  9. `Check.define` refuses `reducible` on a `Div`-headed or
     `IO`-headed def.
  10. `def rec` that fails the guard stays a hard error; `partial` is
      the only way to `Div`, and it forces a `Div`-headed codomain.
  11. Deferred definition-time execution keys on the def's type head,
      not on a new attribute.
  12. Every prim carries a one-line comment justifying its ladder
      classification; `dev/prim-lint.sh` lists the catalog.
  13. An execution budget for a hung guard is the hook runner's job
      (`timeout` in the shebang wrapper or the calling harness), not
      M3 kernel work. Recorded as a risk, not built.
  14. `tot run --no-prelude` exists for kernel tests.

  Three confirmed user decisions (2026-09-01, final):
  1. **Effect model: monadic reified IO.** `Div` and `IO` are opaque
     zero-constructor type formers. `Prim` is a fourth `Global.entry`
     kind with no `def` field and no `reducible` field. Div prims fire
     inline. IO is reified as an action tree that only `run_io` walks.
     Hooks write `main : IO Verdict` with `let*` sugar and an explicit
     `liftIO` at every Div-to-IO step.
  2. **Json: self-recursive `data Json` with its own cons cells** in
     the prelude. No builtin opaque Json. No nested inductives.
  3. **Hook protocol: driver-rendered `Verdict`.** `allow` exits 0,
     `ask` exits 1, `deny` exits 2, and the driver renders the JSON
     envelope. `main : IO Unit` plus an explicit `exitWith` stays legal
     as a second accepted shape.

  Plan-level fill-ins (`dev/M3-PLAN.md`), each with its rationale:
  - Builtin type formers are DECLARED and never DEFINED, so
    `ctor_names` stays `None` and any `match` on `String`, `Int`,
    `Div` or `IO` is `Ind_incomplete`. This closes the vacuous empty
    match that would otherwise inhabit any type from a `String`
    scrutinee.
  - Integer literals reuse the existing `Nat` token, so the M1 numeric
    cap now bounds int literals as a Lex error.
  - `exitWith` returns an `Exited` outcome through `run_io`; the single
    process exit stays in `bin/tot.ml`.
  - `intCompare : Int -> Int -> Ordering`, with `Ordering` a prelude
    data type, chosen over an `Int` sentinel.
  - Regex uses OCaml's `Str` dialect, not PCRE, and `str` is linked
    into `tot_kernel` for exactly two prims.
  - The prim catalog is seeded in phases around the prelude fold,
    because prim types mention prelude data types (in the shipped
    build, three phases and three prelude-fold segments, since the
    prelude's own Stage C accessor defs call a phase-2 prim; recorded
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
  before the body digest; on any read failure of the binary the
  cache is DISABLED for the run, one loud stderr line, never a
  crash.  Only the exact binary that wrote a blob ever reads it, so
  a forgotten `format_version` bump degrades to two independent cold
  caches.  Section 6 keeps the trusted-directory residual.

## 3. Core calculus (M0 core, M2 inductives, M3 literals and effects)

Syntax (de Bruijn indices; binder names are display-only):

    t ::= x | Type l | (q x : t) -> t | fun x => t
        | t t | let x : t = t in t | (t : t) | g | lit
        | match t [as x return t] with {| c x .. => t} end

`lit` is a `Term.Lit` leaf (M3): a string or int literal, opaque to
conversion beyond structural equality (`VLit` is canonical, like
`VCtor`, but is NOT eliminable and is NOT itself a smaller value for
guarded unfolding).

Surface items: `[reducible] def [rec] [partial] NAME : t := t`,
`check t`, `eval t`, and

    data NAME (0 p : t) .. : Type l := | c1 : t | c2 : t ..

M3 surface sugar, both purely syntactic (desugared in `Elab`, before
any typechecking, never touching `Eval.conv`):

    let* A B x := e in body    -- bindIO A B e (fun x => body)
    let*! A B x := e in body   -- bindDiv A B e (fun x => body)

`A`/`B` are the two EXPLICIT type arguments the desugared `bindIO`/
`bindDiv` application needs (the shipped fallback shape: the bounded
hole pass did not ship this milestone, so every `let*`/`let*!` names
its monad's two type parameters explicitly, exactly as `stdlib/
prelude.tot`'s own `map` calls already do; a compound type needs
parens, e.g. `let* (Option String) Verdict x := ... in ...`).

A script MAY start with a shebang line (`#!` at column 0, line 1);
the lexer strips exactly that one line before tokenizing. `--` stays
the only comment marker for everything else. A hook script's first
line is `#!/usr/bin/env -S tot run`.

Quantities: `0` (erased: types, proofs) and `w` (runtime). The checker
carries a mode. Inside types the mode is `0` and every variable is
usable. At mode `w`, use of a `0`-bound variable is an error. Argument
positions multiply: applying a `(0 x : A) -> B` keeps the argument
erased even at runtime.

Universes: `Type l : Type (l+1)`. Pi takes the max of the two levels.
No cumulativity, no universe polymorphism (yet).

Definitional equality: beta, let, eta for functions, and unfolding of
reducible globals during evaluation. Opaque globals are equal only to
themselves. Conversion is checked by NbE: evaluate, then compare values.

Totality: a `def rec` body must pass the structural guard: one formal
is the principal argument, and every recursive call passes a strictly
smaller variable there (a binder bound by a match on the principal or
on something already smaller). Well-founded recursion with measures
comes after M2. `def rec` that fails the guard stays a hard error; the
ONE sanctioned escape (M3) is the `partial` keyword, which skips the
guard, forces `reducible = false` and `rec_arg = None`, and requires a
`Div`-headed codomain (`Check.define ~partial`): divergence stays
visible in the type, quarantined to the `Div` rung of the effect
ladder, never silently reachable from an ordinary `def rec`.

The effect ladder (M3, verdict 3.2): `Div` and `IO` are declared-only,
zero-constructor `Ind` bootstrap entries (non-eliminable, for the same
reason `String`/`Int` are), each `(0 A : Type 0) -> Type 0`. `Div` is
absorbing (no `liftDiv`, no `runDiv`): any def that touches a `Div`
prim has a `Div`-headed type, and only `partial` reaches it from `tot`
source. `IO` is reified: `pureIO`/`bindIO`/`liftIO` and the native OS
prims never perform a host effect while a value is merely being BUILT
(`Interp.apply` only ever constructs a `VIOAction` action-tree node for
them); `surface/effect.ml`'s `run_io` is the one place that walks a
built tree and performs the effects it describes, and `Check.define`
separately refuses `reducible` on a `Div`- or `IO`-headed def, so
conversion can never step into an effect either way.  Hard constraint
1, scoped honestly (M3 fixes round 2, R3, 2026-09-01), claims
exactly this: `tot check` performs no host effects and never
executes the interpreter (`surface/run.ml` builds no runtime
environment for the user file at all; `Interp.define` is never
called for user-file defs in check mode, whatever a def's type
shape, a `Div`/`IO` head or a `Div` value nested under a pure head
such as `Option (Div Nat)` alike).  It does NOT claim bounded
compute: kernel CONVERSION can be driven to unbounded work by
`reducible` definitions (a handful of lines of reducible arithmetic
drives conversion past minutes), the same as any dependent checker,
Coq and Lean included; opaque-by-default is the mitigation, and a
driver-level check budget is M4 work (section 6).  In RUN mode (M3
fixes round 2, R2) EVERY user def is recorded WITHOUT executing its
body (`Interp`'s `GDeferred`), and forcing memoizes: the first
force, by an eval item or by `main`, stores the computed value back
into the entry's cell, later forces return it (sound: a pure body
is pure, `Div` is pure modulo divergence, and an `IO` body only
ever builds an inert action tree).  A def `main` never mentions
never runs at all, so dead code can neither abort nor hang a guard;
a LIVE def's definition-time abort surfaces at force time.

## 4. Kernel modules

- `Level`, `Quantity`: newtyped universe levels and usage marks.
- `Term`: core syntax; quantity-stamped `Lam`/`App`, `Match` with an
  optional motive and quantity-stamped branch binders.
- `Value`: NbE semantic domain. Closures; canonical inductive values
  (`VInd`/`VCtor`); neutrals are a head plus a frame list (`FApp`
  applications and `FMatch` stuck matches, newest first).
- `Eval`: eval / apply / quote / conv, with guarded unfolding of
  reducible rec globals. All total, all `Result`.
- `Global`: name -> entry, with entry kinds `Def` (carrying `reducible`
  and `rec_arg`), `Ind` (params telescope, level, ctor names), and
  `Ctor` (owning inductive, args telescope). Extend only via `Check`.
- `Check`: bidirectional infer/check with quantity modes; `define`
  (with the rec path), `declare_ind`, and `define_ind` are the public
  ways to grow the global environment.
- `Totality`: the structural guard for `def rec`; picks the principal
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
- `Elab`: scope resolution and sugar only; all typechecking stays in
  the kernel.
- `Run`: the script driver threading `Global.t` and `Interp.globals`.

The `tot` executable (`bin/`) wraps `Run` as `tot (check|run) FILE`.

## 5. Milestones

- M0 (done): kernel + tests. No parser.
- M1 (done): surface syntax, elaborator, erasure, interpreter,
  and the `tot` CLI. ML-fragment scripts run end to end.
- M2 (done): quantity-stamped core terms with structural erasure;
  parameterized inductives with strict positivity and the predicative
  universe bound; dependent match; `def rec` with the structural
  totality guard and guarded unfolding; `data`/`match`/`def rec`
  surface syntax; core stdlib (`stdlib/prelude.tot`: Bool, Nat, Option,
  Result, List, Pair). String and Json moved to M3.
- M3 (done): IO ladder (Tot < Div < IO), literals, String/Int/process/
  JSON/regex stdlib, `let*`/`let*!`/`partial` surface sugar, prelude
  auto-loading with a content-addressed elaboration cache, a shebang
  runner, and `main : IO Verdict` driver-rendered hook output. Ported
  the first real PreToolUse guard (`examples/guard.tot`: `rg`/`sd`
  house rule) and ran it end to end against allow/deny/other/garbage
  fixtures.
- M4: propositional equality, indexed inductives, rewriting,
  deterministic type classes, proof ergonomics. Then measure and decide
  the next tradeoff.

## 6. Known debts (deliberate)

- No `.mli` interfaces yet except `Level`; `Global.add` is public but
  documented as kernel-internal.
- No cumulativity: concrete types live one universe up from where
  church-encoded tests want them.
- Apache license text not vendored yet (README notes dual intent).
- Errors carry mostly pre-rendered strings, not structured values (the
  M2 variants add small records). Fine at this scale; revisit when the
  elaborator wants error recovery.
- The CLI file-open can still raise on a permission race despite the
  existence guard.
- Parser and lexer error arms bind structural catch-alls over token and
  char lists.
- `fun` binders cannot carry annotations; use def types or `(e : T)`.
- No indexed, nested, or mutual inductives, and no local fixpoints;
  all deferred to M4 (indices arrive with `Eq`).
- `rec_arg` auto-selection is first-fit: the guard takes the first
  formal that works; there is no annotation to override it. A body with
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
  longer diverges. The interpreter now threads guarded unfolding down
  to the runtime, mirroring the kernel: a rec global stays neutral
  (`EHGlobal`, mirroring `Value.HGlobal`) until applied to a canonical
  constructor value in its principal position, and only then replays
  onto its cached closure. See Section 2's dated entry for the exact
  rule.
- `Eval.is_canonical` (M2 fixes, Round 5 review, T2) does a second
  `Global.find_ind` lookup (on top of the `Global.find_ctor` lookup) per
  canonicity check, on the guarded-unfolding hot path (every application
  of a rec global). Not restructured now: a suggested cleanup is a
  ctor-entry arity cache (fold `n_params` into `Global.ctor_entry` at
  `define_ind` time, so canonicity checks a single field instead of
  chaining through `Global.Ind`), deferred to M3 or later.

Known debts entering M4 (M3, carried from `tot-m3-design-verdict.md`
section 6 plus `dev/M3-PLAN.md`'s own additions):

- The prim catalog is an unverified trust boundary: nothing checks that
  an OCaml implementation matches its declared ladder position. The
  mitigation is the one-line justification per prim and
  `dev/prim-lint.sh`.
- Monad laws are invisible to conversion by design. `liftIO (pureDiv x)`
  and `pureIO x` are different neutrals. M4 propositional equality can
  postulate them; unfolding will never derive them.
- `Div` typing gives provenance, not a termination proof. A guard can
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
  duplicate the `List` combinators until nested inductives land. The
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
  `Interp.v` and `Prim.t` stays as documentation; bumping eagerly
  orphans stale files, but nothing rests on it anymore.  Measured
  cost (M3 fixes round 3, O2): hashing the executable's own contents
  takes ~3.3ms of an ~8ms warm-hit startup on the build machine,
  accepted as correctness-first hook latency;  a stat-identity fast
  path (device/inode/mtime/size instead of a re-hash) is possible M4
  work.
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
- Builtin type formers (`String`, `Int`, `Div`, `IO`) are non-eliminable
  through the `Ind_incomplete` path, whose error wording ("cannot
  eliminate NAME: its constructors are declared but not yet defined")
  was written for M2's provisional-inductive window, not for a builtin
  that will never be defined. M4 should give builtins their own marker
  and message.
- `Str` is linked into `tot_kernel` for exactly two prims (`regexTest`,
  `regexMatch`), and `Str`'s match state is process-global. The regex
  prims must not be re-entered from within a match; the interpreter is
  single threaded today, so this holds by construction. M4 should
  replace `Str` with a bounded engine.
- `tot run` stores every user def as a lazy memoized thunk (M3 fixes
  round 2, R2; the round-1 eager rule let dead code abort or hang a
  guard).  Nothing runs before `main` needs it, so a pathological
  computation in an UNUSED def costs nothing; the traded-away
  property is failure locality: a LIVE def's definition-time abort
  surfaces only at force time, and `tot check` over-approximates
  run's definition-time failure set for dead code.  Laziness
  protects only defs that neither an eval item nor `main`
  transitively forces (M3 fixes round 3, O5): an eval item forces
  its expression's dependencies transitively, exactly like `main`.
- `tot check` has no compute budget: kernel conversion can be driven
  to unbounded work by `reducible` definitions (M3 fixes round 2,
  R3; inherent to dependent checking, shared with Coq and Lean).
  Opaque-by-default is the mitigation; a driver-level fuel or
  wall-clock budget flag for check mode is M4 work.  Until then,
  hook installations should wrap `tot` in an external `timeout`,
  exactly as decision 13 already prescribes for hung guards.
- A MISSPELLED `main` (`mian`, `Main`, ...) is an ordinary def: the
  script stays script mode and exits 0, so a typo'd guard is still a
  silent permit-all (M3 fixes, C1'; the reserved-name check catches
  only a def literally named `main` with the wrong type).  A strict
  driver flag ("this file MUST define a driver main") is M4 work.
  test/fixtures/x11-main-misspelled.tot and gate
  PASS-D-MAIN-MISSPELLED pin the residual on purpose.
- A script-level `Serror` (type error, missing file, bootstrap
  failure, `Main_bad_type`) exits 1 through `bin/tot.ml`, the same
  exit code the hook protocol assigns to the `ask` verdict: a broken
  guard degrades to ask, not to deny (M3 fixes, C1' records the
  collision;  a distinct error exit code is a protocol change, M4).
- The `(rec_, partial)` flag pair on `Syntax.IDef` admits the illegal
  `partial = true, rec_ = false` state;  only the parser maintains
  the invariant (M3 fixes, C12).  Collapsing the two flags into one
  sum type (NonRec | Rec | RecPartial) is the M4 shape.
