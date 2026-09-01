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

## 3. Core calculus (M0 core, M2 inductives)

Syntax (de Bruijn indices; binder names are display-only):

    t ::= x | Type l | (q x : t) -> t | fun x => t
        | t t | let x : t = t in t | (t : t) | g
        | match t [as x return t] with {| c x .. => t} end

Surface items: `[reducible] def [rec] NAME : t := t`, `check t`,
`eval t`, and

    data NAME (0 p : t) .. : Type l := | c1 : t | c2 : t ..

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
comes after M2. `partial` will exist, quarantined from the erased
fragment.

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
- M3: IO ladder (Tot < Div < IO), literals, String/process/JSON/regex
  stdlib, prelude auto-loading, shebang runner, content-addressed
  elaboration cache. Port the first PreToolUse guard and run it for
  real.
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
