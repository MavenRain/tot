# M4 fix round 1: adjudication and plan

Inputs: `tot-m4-review-r1-survivors.json` (ctxcat mechanical, ids 0-9)
and `tot-m4-opus-r1-report.md` (deep-logic audit, F1/F2/F3).

Baseline recorded BEFORE any edit (staged M4 tree, index vs `b01b3eb`):

```
dunecho build -- --root /Users/oobi/Documents/tot   ->  OK build: 0 errors, 0 warnings
zsh dev/gates.sh                                     ->  GATE-EXIT=0
PASS = 238  (62 gate markers + 79 kernel cases + 97 surface cases)   FAIL = 0
```

Every verdict below that concerns behavior was reached by RUNNING the
staged binary `_build/default/bin/tot.exe`, not by reading.  Probe
scripts and their captured output live in `/Users/oobi/Documents/tot-fix1/`.

---

## F1 (HIGH) cache exe-identity is filesystem metadata, not content

Verdict: CONFIRMED (the audit's own repro is an executed witness; the
code at `surface/cache.ml:144-162` is a `Unix.stat` digest with
`Digest.file` reachable only from the `Unix_error` fallback).

Fix (binding): the TRUE identity returns to `Digest.file` of the running
executable, fail-closed.  On any failure to read the executable's bytes
the cache is DISABLED for the whole run (`load` misses, `save` no-ops)
with one loud stderr line, which is exactly the M3 property that
`PASS-CACHE-NOEXEDIGEST` pinned at `b01b3eb`.

The stat digest survives only as a MEMO: a sidecar file in the cache
directory records `stat-signature -> content-digest` from a run that
actually hashed the bytes.  A run whose signature matches the memo skips
the re-hash;  an absent memo, an unreadable memo, a malformed memo or
any signature mismatch re-hashes the content.  The memo signature adds
`st_ctime` to the four fields the audit broke, because `ctime` is the one
stat field userspace cannot restore: `utimes`/`touch -r` (the audit's
repro 1) resets mtime but BUMPS ctime, so the in-place-overwrite
collision that made two byte-different binaries share one blob now misses
the memo and re-hashes.  The memo never widens trust: it lives in the
cache directory, which the module doc comment already classes as trusted
input, and a wrong memo can only cause an unnecessary re-hash or a blob
miss once the content digest disagrees.

`format_version` 9 -> 10.  The header SHAPE is unchanged (32 hex chars)
but the field's MEANING returns to a content digest, so every stat-
identity blob written by the staged build must be orphaned rather than
read.

Gates: `PASS-CACHE-NOEXEDIGEST` is restored to its `b01b3eb` assertion
(exit 0, ZERO blobs, exactly one stderr line matching `prelude cache
disabled`).  Two new markers: `PASS-CACHE-EXEID-CONTENT` replays the
audit's repro (two byte-different binaries of equal size at one inode
with mtime restored) and requires TWO distinct blobs;
`PASS-CACHE-EXEID-MEMO` requires the second run of the same binary to
take the memo fast path.

## F2 (LOW-MEDIUM) driver channels

Verdict: CONFIRMED, executed.

```
tot.exe check MISSING 2>/dev/null            -> "MISSING: no such file" on STDOUT, exit 1
tot.exe check --serror-exit 0 MISSING        -> exit 0
tot.exe check --bogus-flag F 2>/dev/null     -> "unknown flag: --bogus-flag" on STDOUT, exit 2
tot.exe check 2>/dev/null                    -> usage on STDOUT, exit 2
```

Fix: `prerr_endline` for the missing-file line, the flag-error line and
both usage lines;  the missing-file branch returns the literal `1` again,
outside the `--serror-exit` mapping.  Gates
`PASS-D-MISSING-FILE-CHANNEL` and `PASS-D-USAGE-CHANNEL` pin stdout
empty, stderr exactly one line, and the exit code (1 with
`--serror-exit 0` present, 2 for the flag and usage errors).

## F3 (LOW, latent) `auto` in a result-index position

Verdict: CONFIRMED as an argument gap, executed:
`data AI : Nat -> Type 0 := | ai : AI auto` reaches elaboration (it
fails with `no instance found for Nat`), so the RAW index-cleanliness
ban accepted an `auto` index.

Fix: `no_occur` gets an explicit `Term.Auto -> false` arm.  Its contract
is "PROVABLY free of `name`", and an unresolved `auto` may elaborate to a
spine that mentions the family, so it is not.  `strict_pos` runs on
STAMPED arguments where `Term.Auto` cannot appear, so the arm is reachable
only from `index_expr_clean` on the raw codomain, exactly the hole.
Kernel test A6b pins `index_expr_clean` rejecting `Auto` (bare and
nested under an application) while still accepting a clean `Var`.

## ctxcat 1 + 6 (medium, one root cause) instance-resolution fuel

Verdict: CONFIRMED, executed.  An instance with four dictionary binders
is registrable and unresolvable:

```
instance : (0 A : Type 0) -> C1 A -> C2 A -> C3 A -> C4 A -> DD (Box A) := ...
def useBox : Bool := g (Box Bool) auto (box Bool true)
-> instance resolution for (C4 Bool) exceeded its fuel   EXIT=1
```

The same file with THREE dictionary binders resolves and evaluates
`true`.

Fix: `fuel = (1 + term_depth expected_t) * (2 * max_instance_binders + 2)`.

Justification.  Fuel is consumed along a single resolution PATH (siblings
each get their own `fuel - 1` budget), so the bound has to cover
`nesting levels x per-level cost`.  The per-level cost is what the bug
got wrong: peeling one instance telescope costs up to 2 per binder (one
for entering the sub-resolution, one for the continuation), so it is a
property of the INSTANCE TABLE, and `2 * max_instance_binders + 2` covers
the widest registered telescope with slack.  The nesting count is a
property of the QUERY and cannot come from the table at all: every nested
dictionary resolution descends into a STRICT subvalue of the key, so
nestings are bounded by the key's structural DEPTH, and a table-only
constant would reintroduce the same false negative one level deeper (the
prelude's own `EqD (List^n Int)` resolves for unbounded n).  `term_depth`
replaces `term_size`: depth is the measure that actually bounds nesting,
and size over-counts breadth.  Both factors are needed;  either alone is
a false-negative source in one direction.

Regression: fixture `test/fixtures/m4fix-inst-binders.tot` (four
dictionary binders) must resolve and print `true`, gated by
`PASS-M4FIX-INST-BINDERS`.

## ctxcat 7 (medium) `match_scrut` infers the scrutinee twice

Verdict: CONFIRMED, executed and MEASURED.  A chain of matches nested in
scrutinee position doubles per level on the staged binary:

```
depth 12 -> 0.01s    depth 16 -> 0.07s    depth 18 -> 0.27s    depth 20 -> 1.08s
```

4x per two levels is exactly 2^d.  Extrapolated, depth 26 is ~70 s,
past the 30 s gate watchdog.

Fix: infer ONCE at the ambient mode;  fall back to a `Zero` inference
only when the ambient inference FAILED.

Soundness.  Mode affects `infer`/`check` in exactly three places: the
`Var` rule (an erased local at `Many` is `Erased_use`), the `Global` rule
(an axiom at `Many` is `Axiom_runtime_use`), and multiplicative
propagation into applications, lets, matches and lambdas.  None of them
changes the STAMPED output: `App` stamps the Pi's own quantity, `Lam`
stamps the Pi's, `Match` stamps `scrut_q`, which this function derives
from `zero_eliminable` alone.  So for a term that checks at both modes
the two inferences return the SAME term and the SAME type, and mode only
decides whether inference errors.  Therefore:

- ambient succeeds, family subsingleton: reuse the ambient stamp with
  `scrut_q = Zero` (identical term to the old `Zero`-pass stamp).
- ambient succeeds, family not subsingleton: reuse it with
  `scrut_q = Many` (the old second pass, minus the recomputation).
- ambient fails: re-infer at `Zero`, the weakest mode.  Subsingleton
  family -> accept with `scrut_q = Zero` (the erased-hypothesis
  allowance, unchanged).  Otherwise -> return the AMBIENT error, the
  exact error the old second pass raised.
- `Zero` also fails -> that error, exactly as before (the old code
  inferred at `Zero` first and propagated it).

Cost: one inference per match on every path that type-checks, so the
chain is linear.  The fallback cannot re-explode: a nested match that
needs the allowance SUCCEEDS at the ambient mode (its own `match_scrut`
absorbed the fallback), so an ambient failure is not itself nested.

Regression: `test/fixtures/m4fix-nest26.tot`, a 26-level chain, under the
gate watchdog, marker `PASS-M4FIX-NEST-DEPTH`.

## ctxcat 8 (low) raw `is_applied` vs deleted `Term.Ann`

Verdict: CONFIRMED, source-reachable, executed:

```
data Foo : Type 0 := | mk : (Foo : Type 0)
-> invalid constructor mk: constructor must end in Foo applied to its parameters ...
data Foo2 (0 A : Type 0) : Type 0 := | mk2 : Foo2 (A : Type 0)
-> invalid constructor mk2: ... (same misleading reason)
data Foo3 (0 A : Type 0) : Type 0 := | mk3 : Foo3 A     -> checks clean
```

The parser builds `Syntax.SAnn` for any parenthesized `(e : T)`, so both
shapes are ordinary surface input, and elaboration would have accepted
them before Stage A moved the check ahead of `infer`.

Fix: a total `strip_ann` head-stripper, applied inside `define_ind` at
`strip_pis`'s match scrutinee (so an annotated telescope still peels) and
inside `is_applied` at the codomain and at each PARAMETER-position
argument.  Index positions keep the un-stripped argument, so
`index_expr_clean` still inspects the annotation's TYPE half for
occurrences of the family.  `strip_ann` is the identity on stamped terms
(`infer` deletes `Ann`), so the positivity path is untouched.
Positive fixture `test/fixtures/m4fix-ann-ctor.tot` plus gate
`PASS-M4FIX-ANN-CTOR`, and kernel case A6c for `strip_ann` itself.

## ctxcat 2 (low) eager `unresolved ()`

Verdict: CONFIRMED by reading the call (`Option.to_result ~none:` is a
strict argument).  Fix with the house lazy idiom, no match on Option:
`Option.to_result ~none:() |> Result.map_error (fun () -> unresolved ())`.
Covered by the existing instance suite plus the new binder fixture.

## ctxcat 3 (low) `IInstance` duplicates `IDef`

Verdict: CONFIRMED.  Fix: one local `define_and_summarize` closure in
`surface/run.ml` taking the registered name plus the already-elaborated
`ty_t`/`def_t`, called from both arms.  Covered by the existing
class/instance surface cases and `PASS-M4D-*`.

## ctxcat 4 + 5 (low, nit) test helper duplication and temp-file leaks

Verdict: CONFIRMED.  Fix: one `run_cli` helper in `test/surface.ml` that
takes the argv tail plus an optional source file, runs it under the
watchdog and returns `(exit_code, out_lines)`, with `Fun.protect
~finally` removing every temp file on all paths.  Both
`expect_cli_run_lines` and `expect_cli_exit` become thin wrappers.  This
also gives the F2 channel cases a helper that can capture stdout and
stderr SEPARATELY.

## ctxcat 9 (nit) `define_instance` installs a second elaboration

Verdict: CONFIRMED.  Fix: `define` gains an optional `?stamped_ty`
(documented precondition: the caller's own `infer_univ` output for the
SAME `globals` and `ty`), and `define_instance` threads the `ty'` it
validated.  Elaboration runs once and the validated artifact is the
installed one.  Covered by the existing instance cases;  the shape
validator already recomputes the mangled name from the installed type.

## ctxcat 0 (nit) byte-identical guard predicates

Verdict: CONFIRMED.  Fix: `verdictOfDanger2` becomes definitionally
different but propositionally equal (it matches on the NEGATED bool with
the arms swapped), so `agreeOnTrue` and `denyStable` compare two distinct
programs.  `PASS-M4D-GUARD-CLASSES` already runs the example end to end.

---

## Log-only

None.  All ten ctxcat findings and all three audit findings are fixed in
this round.

---

# Round 2

Inputs: `tot-m4-review-r2-survivors.json` (ctxcat round 2, six
survivors: ids 1, 3, 4, 5, 6, 7) and `tot-m4-opus-r2-report.md` (opus
re-probe of the seven surfaces round 1 touched, four findings R1-R4).
Both were adjudicated against the staged tree, with the behavioral ones
re-run on a binary built from it.  The baseline before any round-2 edit
was green: `dunecho build` 0 errors, `dev/gates.sh` GATE-EXIT=0,
250 PASS / 0 FAIL.

Every finding here is a REGRESSION ROUND 1 ITSELF INTRODUCED or left
open, not new ground.  Soundness is untouched throughout: no probe on
either side accepted a wrong program, and every error text is unchanged
except where a false REJECT is removed.

## ctxcat 4 + opus R1 (medium, the headline) `match_scrut`'s Zero fallback re-runs a byte-identical inference

Verdict: CONFIRMED by execution.  Round 1 replaced the unconditional
two-pass with a fallback, and argued it "cannot re-explode, because an
ambient failure is never itself nested".  That holds only for
well-typed input.  An ill-typed nested chain fails at the ambient mode
AND at `Zero` at every level, so each level re-ran the whole subterm and
the `2^depth` curve came back on the ERROR path.  Measured on the
round-1 binary (`tot check`, wall clock, innermost missing `false`
branch): 0.06s at depth 14, 0.11s at 18, 1.21s at 22, 18.18s at 26.  The
motive-less shape: 0.05s at 14, 0.41s at 22, 5.79s at 26.  The
wrong-scrutinee-type shape: 0.81s at 22, 11.78s at 26.  About 2x per
level in all three, which is `2^d`.  Every one of those is an ordinary
typo, so a hook author's broken guard hangs the checker instead of
being diagnosed.

Fix: guard the fallback on the ambient mode.  `infer` is a pure
function of `(globals, ctx, mode, scrut)`, so when `mode` is ALREADY
`Zero` the second call is byte-identical to the first and can only fail
again with the same error value;  round 1 propagated that second
error, which IS `e`.  Skipping it is observationally equivalent.

Recurrence after the fix, written out because the claim it replaces was
the false one.  Let `Z d` be one `infer` at mode `Zero` over a chain of
`d` matches nested in scrutinee position, `A d` the same at ambient
`Many`.  At `Zero` the fallback is skipped, so
`Z d = Z (d-1) + O(1) = O(d)`: one linear pass.  At `Many` each level
runs the ambient recursion once and, only when that failed, ONE linear
`Zero` pass over the same subterm, so
`A d = A (d-1) + Z (d-1) + O(1) = O(d^2)`.  Polynomial, never `2^d`.
There is no third case: quantity multiplication never raises a mode, so
a mode below the top can only be `Zero`.

Regressions, both required, both under `"$watchdog" 10`:
`PASS-M4FIX-NEST-ILL` (`m4fix-nest26-ill.tot`, depth 26, innermost
branch missing) pins exit 1 AND the exact diagnosis, because a fast
WRONG error is not a fix;  `PASS-M4FIX-NEST-NOMOTIVE`
(`m4fix-nest30-nomotive.tot`, depth 30, no `as .. return` anywhere) is
the opus report's motive-less variant, at depth 30 so the pre-fix cost
clears the budget by 8x rather than by a hair.  The existing well-typed
`PASS-M4FIX-NEST-DEPTH` is re-timed and keeps its 15s budget.

## ctxcat 5 (medium) instance fuel bounds only the PATH

Verdict: CONFIRMED by execution.  `build_instance` handed `fuel - 1` to
BOTH the dictionary sub-resolution and the continuation, so the
sub-resolution's own consumption was never deducted: fuel bounded the
depth of one path, never the total number of resolutions, and there is
no memo.  `validate_instance_shape` accepts
`(0 A : Type 0) -> C A -> C A -> C (Box A)`, so resolving `C (Box^n Bool)`
performs 2^n identical sub-resolutions while `inst_fuel` grows only
linearly in n: the belt cannot fire.  Measured on the round-1 binary
(`tot run`): 0.06s at n=10, 0.41s at 14, 7.43s at 18, 32.82s at 20.

Fix: the preferred one.  `resolve_auto` returns the REMAINING fuel
beside the resolved term, and the dictionary arm of `build_instance`
passes `left - 1` to the continuation instead of a second copy of
`fuel - 1`.  No mutation, no memo table.  Every recursive step of
`build_instance` decrements a now-global budget and `resolve_auto` only
forwards it, so the whole walk performs at most `inst_fuel` steps: it
resolves or reports `Inst_depth`, and cannot hang.  `inst_fuel`'s size
is unchanged, because total steps and per-path steps coincide on every
NON-branching telescope, which is every shape the prelude and the gates
register.

Regressions: the 4-binder `PASS-M4FIX-INST-BINDERS` stays green
(re-run, exit 0), and the new `PASS-M4FIX-INST-BRANCHING`
(`m4fix-inst-branching.tot`, two dictionary binders at nesting depth 20)
runs under `"$watchdog" 10` with the oracle "resolve or report
`Inst_depth`, never hang": either exact outcome passes, a 124 or any
other exit fails, so adding a `(class, key)` memo later flips the gate
deliberately rather than silently.  Checked separately that the fix
opens no new false negative: the NON-branching chain resolves at nesting
1, 5, 10, 20, 40 and 80, all exit 0, all under 0.1s.

## ctxcat 1 (medium) `scrut_q` stamps the literal `Many`

Verdict: REFUTED BY DESIGN.  `dev/M4-PLAN.md` A6.4 ratifies exactly
this, verbatim: "the non-subsingleton stamp is `Many`, NOT the ambient
mode.  Erasure only distinguishes `Zero` from `Many`, and restricting
the `Zero` stamp to the subsingleton case is what makes `Erase`'s
two-or-more-branch backstop provably unreachable.  The alternative
rejected: stamping the ambient mode, which would let a mode-`Zero`
match on a two-constructor family carry `scrut_q = Zero` and reach the
`Zero` erasure arm through a `Lam Zero` walk."  The reviewer's
suggested `Ok mode` IS the rejected alternative, and taking it would
make the erasure `Zero` arm reachable.  No code change;  a one-line
comment at the site now cites the A6 rule so the next reviewer stops
here.

## opus R3 (low) the Ann false-reject survives on the spine HEAD

Verdict: CONFIRMED by execution, and the fix IS local to the
Ann-stripping helper, so it is fixed rather than recorded as debt.
`Totality.spine` unwinds `App` nodes without stripping, so an
annotation on the spine's own head survived round 1's outer
`strip_ann` and left `head_ok` false.  Executed pair on the round-1
binary: `data AVec : Nat -> Type 0 := | avnil : (AVec : (0 n : Nat) -> Type 0) zero`
is rejected as an invalid constructor, while the identical expression
in `def probe : Type 0 := ...` position checks.  Fix: strip the head
`spine` returns, inside `is_applied`, one line.  `Totality.spine`'s
shared walk is untouched (the report's own second-choice direction, and
the larger change).  Cost was a misleading diagnosis on a legal surface
term, never an unsound accept.

Regressions: `PASS-M4FIX-ANN-HEAD` pins the exact accepted output for
both the codomain and the parameter-argument form, and
`PASS-M4FIX-ANN-HEAD-NEG` pins that `(Nat : Type 0) zero` as `BVec`'s
codomain still fails with `BVec`'s own result-shape reason, so the
strip does not start accepting a wrong head.

## opus R2 (low-medium) three sibling driver paths escape the channel fix

Verdict: CONFIRMED by execution.  `Sys.file_exists` is TRUE for a
directory, for a FIFO and for a regular file with no read permission,
so control reached `In_channel.with_open_text`.  Re-run on the round-1
binary: a directory and an unreadable file each printed
`Fatal error: exception Sys_error(...)` and exited 2, the code the
driver reserves for USAGE errors, with `--serror-exit` never consulted;
a FIFO did not exit at all (124 at the watchdog).  The debt SPEC.md
recorded was narrower than what runs: a directory is deterministic, not
a race, and a FIFO is a hang, not a raise.

Fix: `bin/tot.ml` gains a `source_error` sum (`Missing`, `Not_regular`,
`Unreadable`) and a total `read_source` that classifies before reading.
`Sys.is_regular_file` stats rather than opens, so the FIFO is
classified without blocking;  the one residual raise
(`In_channel.with_open_text` on a file that loses its read bit between
the stat and the open) is converted at that single stdlib boundary and
becomes `cannot be read`.  All three now take the missing-file
contract exactly: stdout EMPTY, one driver line on stderr, the literal
exit 1, outside the `--serror-exit` mapping.

Regressions: both channel gates are extended.  `dev/gates.sh` gains
`PASS-D-UNUSABLE-FILE-CHANNEL` (six probes: directory, FIFO and
unreadable file, each bare and under `--serror-exit 0`, each pinning
exit code, empty stdout and the exact stderr line, all under
`"$watchdog" 15` so a re-blocking open returns a loud 124), and
`test/surface.ml` gains the matching in-process case `R2-F2c`.

## opus R4 (low) `--require-main` under `--serror-exit 0`

Verdict: CONFIRMED as a consistency gap, RECORDED, not changed.  A file
that exists but declares no `main` is still routed through
`serror_exit`, so `--require-main --serror-exit 0` exits 0, which a
hook reads as allow.  The missing-FILE branch is deliberately outside
that mapping because it is a driver-level verdict about the target's
usability;  a mainless file is a script-level verdict about content, so
flipping it is a behavior change to a shipped flag and belongs to a
deliberate decision, not to a fix round.  SPEC.md section 6 now records
the rule and the repro.

## ctxcat 3 (low) `expect_cli_run_lines` hardcodes `~what:"F1"`

Verdict: CONFIRMED.  The helper drives F1's witness fixture, T0's
erased-guard fixture and B6's subst fixture, so a missing watchdog
binary named the wrong regression for two of the three.  Fix: `~what`
becomes the helper's own required parameter, and the three call sites
pass `"F1"`, `"T0"` and `"B6"`.

## ctxcat 6 (low) three Stage D CLI gates run with no watchdog

Verdict: CONFIRMED.  `PASS-M4D-SERROR-EXIT`, `PASS-M4D-REQUIRE-MAIN`
and `PASS-M4D-GUARD-CLASSES` invoked `dune exec` bare while every
neighbour wraps it.  Both exponential paths above are reachable through
`check`, so a hang there stalls the gate run with no FAIL marker.  Fix:
`"$watchdog" 30` on all six invocations, exit-code assertions kept, so a
124 fails loudly.

## ctxcat 7 (low) the nest-depth timing gate charges `dune exec` to its budget

Verdict: CONFIRMED.  `PASS-M4FIX-NEST-DEPTH` is a TIMING assertion, but
the watchdog wrapped `dune exec --root`, which takes the workspace build
lock and may rebuild;  a parallel build or an editor's dune RPC holding
that lock hits 124 with no regression present.  Fix: run the
already-built `"$ROOT"/_build/default/bin/tot.exe`, as the F2 gates in
the same block already do;  the 15s budget is kept and now measures the
checker alone.  Every gate above it has already forced that binary to
be built.  The three new timing gates use the same form.

---

# Round 3

Inputs: `tot-m4-opus-r3-report.md` (six findings, R3-1 to R3-6, every
one repro-executed) and `tot-m4-review-r3-survivors.json` (six ctxcat
survivors, ids 0, 1, 2, 3, 4, 6, all test/gate/doc hygiene).
`dev/M4-PLAN.md`'s "Known debts entering M5" was read for the two
refute-as-designed adjudications only.

Baseline recorded BEFORE any edit (staged M4 tree, index vs `b01b3eb`,
57 files):

```
dunecho build      ->  OK build: 0 errors, 0 warnings
zsh dev/gates.sh   ->  GATE-EXIT=0
PASS = 257  (81 test/main.exe + 100 test/surface.exe + 76 gate markers)   FAIL = 0
```

Every behavioural verdict below was reached by RUNNING a binary, not by
reading: the staged one for the "before", a mutated one for each
non-vacuity proof, and a round-2 reference tree
(`/Users/oobi/Documents/tot-fix3/tot-r2/`, the four round-3 source files
restored from the git INDEX, built clean) for the answer-equivalence
check.  Probe scripts and captured output live in
`/Users/oobi/Documents/tot-fix3/`.

## R3-1 + R3-5 + R3-6 and the retired memo debt (medium-high, the headline) the fuel saga, third and final attempt

Verdict: CONFIRMED (executed, reproduced exactly).  Round 2 made
`inst_fuel` a budget for the whole resolution but left it sized like a
per-path depth counter, `(1 + term_depth query) * (2 * max_binders +
2)`, which grows LINEARLY in the query's depth.  A telescope with `k`
recursing dictionary binders costs about `3k` decrements per level, so
the budget is out-run by any shape whose total work grows faster than
the depth.  Nothing exponential is needed.  Reproduced on the staged
binary against the round-1 accounting, `run`, and matching the report
line for line:

```
shape                                            r2 (staged)   r1
(0 A) -> TC A -> TD A -> TC (TBox A), two CLASSES
  nesting 5 / 6                                  0 / Inst_depth   0 / 0
  nesting 10, 20, 30                             Inst_depth       0 (0.034s at 30)
(0 A) -> DC A -> DC A -> DC (DBox A), the SPEC shape
  nesting 3 / 4                                  0 / Inst_depth   0 / 0
  nesting 8, 12, 16, 20                          Inst_depth       0 (1.673s at 16)
k INDEPENDENT chains
  k=6 n=20, k=8 n=10                             0                0
  k=8 n=20, k=8 n=40, k=10 n=20                  Inst_depth       0 (0.043s at k=8 n=40)
```

Three things make this more than the recorded debt, all three verified:
the fence is not "two dictionary binders on the same type variable"
(two DIFFERENT classes fail, from nesting 6);  the trade is not
"instead of running 2^n sub-resolutions" (`k=8 n=20` performs exactly
160 sub-resolutions, linear, and is rejected);  and the reach was not
merely unbought, it SHIPPED in round 1 and round 2 removed it.

Decided fix, the one the SPEC recorded as a debt: implement the (class,
key) MEMO.

- An immutable `Term.t Map.Make(String).t` threaded through
  `resolve_auto`/`build_instance` exactly as round 2 threaded the fuel:
  passed in, returned updated, no mutable state anywhere.  It lives in
  a new `inst_state` record beside the fuel, so one parameter carries
  the whole walk's state.
- Scoped to ONE `Term.Auto`: `check`'s Auto arm builds a fresh
  `inst_start`, so nothing crosses two resolutions.  That scoping is
  what makes the memo sound with no invalidation rule at all, because
  `globals` and `ctx` are invariant across a single walk (every
  recursive call forwards both unchanged), so a key that resolved once
  resolves identically again.
- Written only on SUCCESS, and consulted before the instance lookup.  A
  divergent path therefore never hits it and the fuel backstop stays
  reachable for one.
- KEYED on the class name paired with the class argument's own quoted
  term, the (class, key) pair spelled in FULL.  A head-only key, which
  is what the debt's own wording suggests, is UNSOUND: an instance with
  two type binders puts two sibling dictionary sub-goals in one
  telescope, and those can share a key head while differing in its
  arguments (`PC (PBox Bool)` and `PC (PBox Nat)`).  Executed on a
  head-only mutant: `m4fix-inst-memo-key.tot` and even the ordinary
  `m4fix-inst-twoclass.tot` fail with a type mismatch, because the
  candidate re-check catches the wrong dictionary.  So the full key is
  load-bearing, and `PASS-M4FIX-INST-MEMO-KEY` pins it.
- The map key is a hand-rolled INJECTIVE string encoding of `Term.t`
  (tag letter per constructor, length-prefixed strings, count-prefixed
  lists), not `Stdlib.compare` on the term.  Polymorphic compare is
  total on this first-order type today, but that is not a property
  `Term.t` promises, and a future functional payload would turn a wrong
  instance into a raise inside a `Map` rebalance.

Fuel stays, resized.  With the memo the work is bounded by the number
of DISTINCT (class, key) pairs a query can reach, which is the class
count times the query's distinct subvalue count.  A depth-only formula
cannot bound that quantity at all, because a WIDE query has many
subvalues at one depth.  So `inst_fuel` is now the round-2 formula
times 16, floored at a flat 10000: the 16x keeps the shape of the old
argument for deep queries and the floor covers wide ones.  Measured
headroom after the memo: the deepest gate shape spends 133 of 10000,
and a 400-level chain about 1200.  The backstop must never fire on
legitimate input, and the reach gates below are what says so.

R3-1's boundary detail (`build_instance` tests `fuel <= 0` at entry even
when the telescope is empty, making the effective budget one step
tighter than the formula reads) is deliberately NOT changed.  It is a
symptom of a tight budget, and the budget is no longer tight;  moving
the test would also weaken `test/main.ml`'s D7, whose contract is
"fuel 0 is `Inst_depth`, whatever `ity` is", and this round weakens
nothing that is not explicitly authorised.

R3-6, same fix family: `Inst_depth`'s payload named `ity`, the instance
type at the point the budget ran out, which after partial peeling is a
Pi telescope naming neither the user's goal nor an unresolvable one (a
nesting-20 query reported as four levels).  The ORIGINAL query value now
travels in `inst_state.goal` and is what the error renders.  Carried as
a `Value.t`, not a rendered string, so `pp_value` runs on the failure
path only.

R3-5, the gate-set half: `PASS-M4FIX-INST-BRANCHING`'s oracle accepted
"resolve OR report `Inst_depth`", so nothing in the battery would have
failed if the fix had started rejecting two-dictionary telescopes at
depth 1.  Its oracle now requires RESOLUTION (the deliberate flip round
2's log pre-authorised), and four companion gates pin the reach class it
could not see.

## R3-2 (medium) the prelude read is the unfixed fourth sibling

Verdict: CONFIRMED (executed).  Reproduced on the staged binary with a
valid target file throughout: `TOT_PRELUDE` at a directory or an
unreadable file gave `Fatal error: exception Sys_error(...)` and exit 2
(the code the driver reserves for USAGE errors), a FIFO did not exit at
all (124 at the watchdog, no output), and a missing path under
`--serror-exit 0` exited 0 -- the fail-open the round-2 log itself
argued must not happen.  `TOT_PRELUDE` is operator-controlled and this
path runs on every ordinary `check`/`run`.

Decided fix: lift the classifier, do not re-derive it.
`bin/tot.ml`'s `source_error`/`is_regular_file`/`read_source` move to a
new `surface/source.ml` (`error`/`message`/`is_regular_file`/`read`), so
the target read and the prelude read share ONE precheck and cannot drift
again.  `Bootstrap.prelude_source ()` classifies the prelude path with
it and returns the bytes;  `run_with_prelude` routes a classification
failure to the target file's contract exactly (stdout empty, one stderr
line, the literal exit 1, OUTSIDE the `--serror-exit` mapping) and hands
the bytes to a new `cached_state_of_src`, so the prelude is still read
once per invocation.  A prelude whose CONTENT is broken is a different
verdict and keeps the `serror_exit` mapping, unchanged.
`read_prelude_src` itself becomes total for the in-band callers
(`state ()`, which both test suites drive directly).  Its docstring
cited "the SAME documented SPEC debt `bin/tot.ml`'s own file read
already accepts";  round 2 retired that debt in place, so the comment
pointed at a retired entry while the raise it excused was still live.
Rewritten.

## R3-4 (low-medium) `is_regular_file` rejects live pipes and `/dev/stdin`

Verdict: CONFIRMED (executed): `tot check <(gen)` and
`tot check /dev/stdin` are rejected, and round 1 read both correctly.

Decision: KEEP the regular-file contract.  Hooks are handed real files,
and a target that can block the checker forever with no timeout of its
own is the worse failure;  a non-blocking open or a read under a
deadline would buy the pipes back at the cost of a second failure mode
to reason about, in a fix round.  What changes is that it stops being an
accident: SPEC.md section 6 and README.md each gain a sentence saying
the target must be a REGULAR file, that process substitution and
`/dev/stdin` are rejected, and that generated source goes through a
temporary file.  The rejection message already names the requirement and
the path in the driver's uniform `<path>: <reason>` shape
(`<path>: not a regular file`), so its wording is unchanged;
re-ordering it would re-pin six gate probes and six in-process probes
for no gain in information.

## ctxcat r3 ids 1 + 4 (low, medium) the chmod-000 tests are not root-safe

Verdict: CONFIRMED for both (one cause, two sites).  `chmod 000` does
not deny uid 0, so under root the open SUCCEEDS and both sites either
fail for a reason unrelated to the code or coincide and pass without
ever reaching the `Unreadable` branch.

Decided fix: guard BOTH on the effective uid, and SAY SO when skipping.
`test/surface.ml` uses `Unix.geteuid ()` and prints
`SKIP R2-unreadable: running as root, ...`;  `dev/gates.sh` uses
`id -u` and prints `SKIP-D-UNUSABLE-FILE-CHANNEL-UNREADABLE` (and the
same for the new prelude gate), with the gate still PASSing overall so a
root run is not a red battery but is also not a silent claim of
coverage.  An unprivileged run keeps every probe.  The directory and
FIFO sub-cases need no guard: they are classified by a stat, which root
does not bypass.

## ctxcat r3 id 6 (low) the cache memo's HIT condition is never adversarially tested

Verdict: CONFIRMED as stated, ACCEPTED as a residual.  The finding is
right that `PASS-CACHE-EXEID-MEMO` runs one untouched binary twice and
`PASS-CACHE-EXEID-CONTENT` exercises the MISS, so no gate forges a hit
on changed bytes.

Decision: do NOT build a fake-stat seam, and record exactly why.  The
honest construction is "change the bytes, restore the observed
signature", and it has no unprivileged form on this platform: opus round
2 proved by execution that `setattrlist` with `ATTR_CMN_CHGTIME` returns
`EPERM` for a non-root caller and that no unprivileged call sets ctime.
The suggested third leg (hand-edit the memo's digest, or copy one
signature's memo onto another) tests a memo file an attacker who can
write it has already won against, because the cache directory is inside
the accepted trust class;  such a gate would assert something about the
seam, not about the threat model.  The gate's comment and SPEC.md
section 6 now carry that argument in full, plus the exposure that does
remain: a mount whose observed ctime does not move on an in-place
overwrite degrades the memo to a metadata check.

## ctxcat r3 id 3 (low) `require_main` fires in check mode too

Verdict: CONFIRMED as an observation, REFUTED as a defect.  Uniform
behaviour is the intent: `--require-main` implements "this file must
define a driver main", a verdict about the file's CONTENT, and a content
verdict must not depend on which verb asked for it.  A hook that
pre-flights a guard script with `tot check --require-main` would
otherwise accept a mainless script that `tot run --require-main` then
rejects.  Fix: the doc comment says so now, and
`PASS-M4D-REQUIRE-MAIN` gains a CHECK-mode leg so the claim is pinned
rather than asserted.

## ctxcat r3 ids 0 and 2 (low) refuted by design, log-only

- id 0 flags `--require-main` under `--serror-exit 0` as a fail-open
  gap.  It is quoting SPEC.md section 6's own entry for that residual,
  recorded deliberately by round 2 (opus R4) with its repro and its
  rationale: the missing-FILE branch is outside the mapping because it
  is a driver-level verdict about the target's usability, while a
  mainless file is a script-level verdict about content, and flipping a
  shipped flag's exit mapping is a deliberate decision, not fix-round
  work.  No code change.
- id 2 flags the anonymous arrow-sugar data index being coerced to
  quantity 0.  It is verbatim `dev/M4-PLAN.md`'s "Known debts entering
  M5" anonymous-index entry, which the parser comment at the site
  already cites.  No code change.

# Round 4

Inputs: `tot-m4-review-r4-survivors.json` (six ctxcat survivors, ids 0
to 5) and `tot-m4-opus-r4-report.md` (five findings plus a held-surface
table).  Round 3 is the tree under review (63 files staged vs `b01b3eb`,
battery 264 PASS / 0 FAIL).

Baseline re-run before any edit and green:

```
dunecho build            ->  OK build: 0 errors, 0 warnings
zsh dev/gates.sh         ->  GATE-EXIT=0
PASS = 264 (82 kernel + 100 surface + 82 gate markers)   FAIL = 0   SKIP = 0
```

Two of the eleven findings are soundness-adjacent and both are
CONFIRMED by an executed repro.  The rest are robustness, doc and test
hygiene.  Two are refuted on behaviour and kept as regression pins.

## ctxcat r4 id 3 (medium, the sharp one) an axiom laundered to runtime through a zero-constructor family

Adjudication: CONFIRMED, executed.  On the round-3 binary
`axiom ff : Empty` plus `def boom : Nat := match ff with end` CHECKS
(exit 0), and `tot run` on the same file prints `<erased>` for
`eval boom` and `((add <erased>) (succ zero))` for
`eval (add boom (succ zero))`.  So an erasure marker reaches a
`Many`-quantity `Nat` computation.

Mechanism, re-read at the cited lines.  `match_scrut` infers the
scrutinee once at the ambient mode and, on ANY failure, re-infers at
`Zero`;  `zero_eliminable` returns `true` for `Global.Complete []`, so
the match is stamped `scrut_q = Zero` and `Erase` maps a zero-branch
`Zero` match to `Eterm.EErased`.  Mode reaches `infer` through two rules
that raise two DIFFERENT errors: the `Var` rule raises `Erased_use` and
the `Global` rule raises `Axiom_runtime_use`.  The fallback exists for
the FIRST only.  Forgiving the second is the checker overriding its own
runtime-quantity verdict.

Fix: guard the fallback on `Error.is_erased_use`.  Every other ambient
error propagates unchanged.  `Error.is_erased_use` is spelled as an
exhaustive match over `Error.t`, not as a `tag` string comparison, so a
new constructor is a compile error at the predicate and the soundness
condition never rides on a display string.

Scope, stated because it matters.  This restores the ambient mode's own
verdict;  it does not make an inconsistent axiom set consistent.
`exfalso` takes its `Empty` at quantity 0, so
`def boom6 : Nat := exfalso Nat ff` checks and evaluates to `<erased>`
before AND after.  That is the sanctioned quantity-0 route, the one
`--no-axioms` switches off.

Rejected alternative: returning `false` from `zero_eliminable` for
`Global.Complete []`.  That would break the legitimate absurd
elimination, which is the prelude's own `exfalso`, so every bootstrap
would fail.

## opus R4-2 (medium) the prelude is read TWICE on a cold run

Adjudication: CONFIRMED, executed, and round 3's own docstrings assert
the opposite in three places.  `run_with_prelude` reads the path
(read 1, which becomes `Cache.key`), and `cached_state_of_src`'s miss
branch calls `state ()`, which reads it again (read 2, whose bytes are
what get elaborated).

Two consequences, both reproduced.  (a) Read 2's failure is a
`Serror.Lex` INSIDE the `--serror-exit` mapping, so a prelude removed
between the two reads exits 0 under `--serror-exit 0`: 12 attempts, 12
hits on the round-3 binary.  (b) The entry stored under content A's key
holds a state elaborated from content B, with no privilege on the cache
directory needed: 5 of 8 sampled delays poisoned, `cmp`-verified.

Fix: `state_of_src` elaborates the bytes it is given;  `state ()` is
`read_prelude_src` followed by `state_of_src`;  `cached_state_of_src`
uses `state_of_src src` in BOTH branches (the miss and the
`TOT_CACHE_VERIFY` recompute).  This closes both by CONSTRUCTION, not by
narrowing a window: the key and the elaborated content are the same
bytes, and no second `read_prelude_src` sits on the driver's path.  The
three doc claims are now true and each says so.

## opus R4-1 (medium-high operationally) the branching gate's 60 s budget is not a margin

Adjudication: CONFIRMED, executed by the reporter (two of three
gate-shaped runs at exit 124, raw runs of 58 to 90 s against a 60 s
watchdog).  The leg sat ahead of six later markers in a fail-fast
script, so a load-induced timeout blanked the memo's own soundness pin
and the whole prelude-channel gate.

Decision, an AUTHORIZED oracle re-scope: the fixture drops from nesting
20 to 16 and the 60 s budget stays as a real margin.  The regression
boundary this file pins is nesting 4 to 6, so 16 still over-pins it by
an order of magnitude while the emitted term, and with it the wall
clock, shrinks 16x (measured after the change: 0.97 s, so 60 s is about
60x headroom instead of 2.9x).  The depth-20 measurement is kept in the
fixture header as the M5 hash-consing motivation.  The leg also MOVES to
the end of the M4-fixes block so a future flake cannot blank the cheap
markers.

## opus R4-3 (low-medium) the flat 10000 fuel floor rejects wide queries

Adjudication: CONFIRMED, bisected to the leaf.  A balanced `WPair` tree
over L pairwise distinct leaf types charges 6 per distinct (class, key)
pair, so L = 1667 resolves at charge 9996 and L = 1668 reports
`Inst_depth` at 10002, while the query's DEPTH is only log2 L and the
round-3 formula therefore sits at its constant floor.  A finite, well
formed, resolvable query rejected in 0.35 s is exactly what this
number's own contract forbids.

Fix: `inst_fuel` takes the max of the round-3 depth formula (unchanged,
so no deep shape loses fuel) and `8 * term_size expected_t`.
`term_size` counts every node, so a width-L query gets at least 8L.

Residual, recorded rather than fixed.  CORRECTED in round 5 (opus
R5-3), see "# Round 5" below: `term_size` is taken on the QUOTE of the
already-evaluated expected value, not on the user's source term, so def
sharing does not undercount it and the mechanism this paragraph named
cannot occur.  The real residual is that a legitimately huge resolution
has no TIME cutoff: quoting and key encoding are blind to sharing, so a
sub-2 KB file costs 24.6s at depth 17 and 41.4s at depth 18 without
ever reaching the fuel counter.  That is the carried check-budget debt
and M5 hash-consing work, not a fuel-formula debt.

## opus R4-5 (low) the `Inst_depth` message is proportional to the query

Adjudication: CONFIRMED (31,748 bytes on one stderr line).  Fix: the
payload is elided past a 400-character prefix.  The prefix is where the
query's head sits, so every existing assertion that looks for the head
still matches, and D7b (a short goal named in full) keeps the cap from
being satisfied by dropping the payload.

## opus R4-4 (low) SPEC.md and README.md overstate the `/dev/stdin` rejection

Adjudication: CONFIRMED, executed.  `tot check /dev/stdin < f` exits 0;
`cat f | tot check /dev/stdin` and `tot check <(cat f)` exit 1 with
"not a regular file".  The code classifies by the true stat and is
right;  only the two documentation sentences and the `surface/source.ml`
doc comment were wrong.  Fix: the docs, not the code.

## ctxcat r4 id 0 (medium) the `m_idx` binder-order comments contradict

Adjudication: REFUTED as a contradiction, CONFIRMED as an ambiguity.
The word "index" carries two senses around `Term.motive` and the three
comments each pick one without saying which.

Determined by construction, on a TWO-index family (one index is
symmetric under any reordering, which is why `Vec` could not settle
it).  `data Tw : Nat -> Bool -> Type 0` with
`match t as x in Tw i c return (TwP i c)` where `TwP : Nat -> Bool ->
Type 0` elaborates;  the swapped reading (`TwQ : Bool -> Nat ->
Type 0`) fails with "expected Bool, found Nat".  The kernel-side
quote/pp round trip (test A13) shows the same thing from the other
side: with `m_idx = ["i"; "c"]` the motive body `Var 1` has type `Bool`,
the SECOND index, and the round-tripped term prints `in A13Tw i c`.

The one convention: `m_idx` is stored in DECLARATION order (outermost
first);  inside `m_body` de Bruijn 0 is `m_self`, de Bruijn 1 is the
LAST element of `m_idx` and de Bruijn m is its FIRST.  The de Bruijn
sequence is the reverse of the list, which is why `Pp.term` reverses and
`Eval.quote` assigns level `size + m - 1 - j`.  NO module had the
direction backwards.  The convention is now stated once on
`Term.motive` and cited from `pp.ml` and `eval.ml`.

## ctxcat r4 id 4 (low) a whole-type-annotated ctor rejected by the raw result-head check

Adjudication: REFUTED on behaviour, executed.  The finding assumes
`strip_pis` stops at an `Ann` node;  round 1 (ctxcat id 8) made it call
`strip_ann` at EVERY level, the first included, so
`| wmk : ((0 x : Nat) -> WFoo A x : Type 0)` peels to its binders and
checks.  All three spellings (annotation outside the arrow, around the
whole parenthesised telescope, and nested on the codomain) already
checked on the round-3 binary.  The `Type 1` variant the finding names
fails, but with "type mismatch: expected Type 1, found Type 0", a
correct verdict about the annotation itself and not a `Bad_ctor`.

No code change.  What was genuinely missing is the regression pin, so
the round-3 Ann handling gains a positive fixture covering the three
spellings and a negative whose codomain is wrong under the same
annotation shape.

## ctxcat r4 id 1 (medium) `with_scratch_dir` leaks its scratch directory

Adjudication: CONFIRMED by reading.  `case_unusable_file_channel`
creates `dir/adir`, the cleanup removes only the two files, `Sys.rmdir
dir` raises "Directory not empty" and the guard swallows it.  Fix: a
guarded `Sys.rmdir` on the nested directory first.

## ctxcat r4 id 5 (low) the patched-literal probe escapes the gate's sandbox

Adjudication: CONFIRMED by reading.  The one bare invocation in a gate
where every sibling is wrapped, so it ran a deliberately corrupted
binary against the developer's REAL cache dir and REAL prelude path,
unwatchdogged.  Fix: wrapped like its neighbours, with a cache dir
SEPARATE from the one whose blob counts the gate asserts on.

## ctxcat r4 id 2 (low) TOCTOU in temp-name-to-dir, log-only

`with_scratch_dir` reserves a unique name with `Filename.temp_file`,
removes the file and calls `Sys.mkdir` on the same path, so a
concurrent recreate would surface as "could not create the scratch
directory" instead of a collision-specific message;  the harness is
single-process and the failure is a loud test error either way, so this
is recorded and not fixed.

# Round 5

Inputs: `tot-m4-review-r5-survivors.json` (16 ctxcat survivors, ids 1,
2, 4 to 17) and `tot-m4-opus-r5-report.md` (seven findings, every one
repro-executed against the staged binary, plus a table of the surfaces
that HELD).  Round 4 is the tree under review (72 files staged vs
`b01b3eb`, battery 274 PASS / 0 FAIL).

Baseline re-run before any edit and green:

```
dunecho build            ->  OK build: 0 errors, 0 warnings
zsh dev/gates.sh         ->  GATE-EXIT=0
PASS = 274 (84 kernel + 100 surface + 90 gate markers)   FAIL = 0   SKIP = 0
```

Both round-4 soundness fixes HELD under every attack opus executed
against them: the kernel narrowing (`Error.is_erased_use`) and the
prelude single read.  Neither could be broken.  This is therefore a
polish round: every finding below is a bound, a gate, a test that does
not pin what its comment says it pins, or a doc that describes a design
the tree does not have.  No kernel rule moves.

The reference binary for every "before" number in this round is the
staged tree's own build, rebuilt in `/Users/oobi/Documents/tot-fix5/snap1`.
Its `lib/check.ml`, `lib/pp.ml`, `lib/error.ml`, `surface/run.ml`,
`surface/cache.ml` and `surface/bootstrap.ml` are md5 identical to the
index;  `lib/eval.ml` and `lib/term.ml` differ by comment text only
(diffed, verbatim, in the log).

## opus R5-1 (medium, the sharpest) the binder-order pins pin neither mechanism

Adjudication: CONFIRMED, and re-executed here rather than read.  Two
mutations were built in a scratch COPY of the tree and the whole
battery run against each:

```
lib/pp.ml    List.rev DROPPED from the motive's names extension
             -> round-4 tree: GATE-EXIT=0, 274 PASS, 0 FAIL
lib/eval.ml  idx_env levels (size + m - 1 - i) -> (size + i)
             -> round-4 tree: GATE-EXIT=0, 274 PASS, 0 FAIL
```

So the ONE convention `Term.motive` states, and cites two mechanisms
for, could be reversed in either mechanism with a green battery.  A13's
assertions all read the "in" clause, and `Eval.quote` copies `m_idx`
verbatim, so the "in" clause cannot see the level arithmetic at all.
The surface fixture cannot help either: `PASS-M4FIX-MOTIVE-ORDER` pins
the printed TYPE `twOrder : .. -> Nat`, and `TwP` is reducible and
constant, so no motive text reaches the pinned output.

Fix (binding): A13 gets an ASYMMETRIC two-index family whose motive
BODY names both binders in order.  `A13Tw`'s two indices are `Nat` and
`Bool` at this scrutinee, and the body is `a13snd i c` where `a13snd`
is a reducible selector returning its SECOND argument.  Three
assertions, one per mechanism, each independent of the others:

- the printed CHECKED term must read `return ((a13snd i) c)` and must
  not contain `((a13snd c) i)`.  Kills the `Pp.term` mutation, which
  leaves the "in" clause untouched.
- the ROUND-TRIPPED motive body must be `Term.Var 1` STRUCTURALLY,
  read off the quoted term and not off its printing, so a broken
  printer cannot mask it.  Kills the `Eval.quote` mutation, which turns
  it into `Term.Var 2`.
- the inferred TYPE must quote to exactly `Bool`.  That is the
  evaluated result and the pin on `Check.infer`'s binding walk: a flip
  there makes the motive `Nat` and the branch body `true` stops
  checking.

## opus R5-2 (medium) `Inst_depth` still rejects a resolvable query, on the class-count dimension

Adjudication: CONFIRMED, bisected to the leaf on the staged binary.  57
single-field classes, one `WPair` instance per class demanding every
class on both parameters, four-leaf query:

```
K = 56  ->  exit 0, "def q : Nat"
K = 57  ->  exit 1, "instance resolution for (C0 ((WPair ((WPair Waaaa)
            Wbbbb)) ((WPair Wcccc) Wdddd))) exceeded its fuel"
```

## ctxcat r5 id 16 (medium) `inst_fuel` takes a MAX where the walk charges a PRODUCT

Adjudication: CONFIRMED, and the same defect as R5-2 seen from the
other side.  After the memo the walk peels one telescope per DISTINCT
(class, key) pair, so the charge is (key count) x (per-key cost).
Round 4's bound was `max(10000, 16 (1 + depth) (2 b + 2), 8 term_size)`:
a MAX of a depth-scaled term and a width-scaled term, and the
width-scaled term carried NO per-key factor, so it was calibrated for
the shipped two-type-binder two-dictionary-binder shape alone.  A MAX
bounds a product only up to the smaller factor.  R5-2's class count
enters through the per-key cost (a K-class table has 2K-binder
instances);  ctxcat 16's 8-binder instance enters through the same
factor with K fixed.

Fix (binding), both findings at once: the width term becomes the
PRODUCT the walk actually charges,
`8 * term_size expected_t * (2 * max_binders + 2)`, and the depth term
is left exactly as it was.  The new value is at least twice the old one
for every instance table, so nothing that resolved before can stop
resolving, and it is a strict increase in a number whose contract is a
BACKSTOP over the structural termination argument.

CORRECTED in round 6 (opus R6-1).  The clause this replaces called that
contract "never a reachable rejection", and execution refutes it: on
the same generated shape, run against the round-5 binary, `K = 60`
resolves and `K = 61` reports `Inst_depth` ("exceeded its fuel"), and
`K = 61` is a registrable, structurally terminating query.  What the
product term bought is a leaf four or five classes higher (round 4's
recorded bisection: `K = 56` resolves, `K = 57` rejects;  a round-6
differential that reverted ONLY the width term: `K = 55` resolves,
`K = 56` rejects), under 10 percent, because the class count enters the
CHARGE through both the (class, key) pair count and the telescope
length while every term of the bound stays linear in `per_key`.  So the
truthful contract is: the bound covers every SHIPPED gate shape with a
recorded margin, a wide-class query rejects beyond a MEASURED leaf, and
the honest residual is the carried check-budget / time-cutoff debt
(SPEC.md section 6), not a fuel-formula debt.

Gates: `PASS-M4FIX-INST-CLASSES` (the K = 57 leaf, generated by
`dev/gen-inst-fuel.py classes 57`) and test/main.ml's D9f (the 8-binder
instance against a balanced 256-leaf query).  D9f is kernel-level
deliberately: the same shape as a surface fixture also pays the
mandatory candidate re-check, which walks the resolved dictionary as a
TREE and costs 15 to 20s at L = 256 and 47s at L = 320, an M5
hash-consing debt unrelated to the bound under test.

No unbounded shape is registrable, so the "still errors" half of the
gate set is a REGISTRATION argument rather than a fixture:
`validate_instance_shape` requires every dictionary domain to be a
single-parameter class over a strict subvalue of the head's key, so the
walk descends and terminates without consulting the number at all.  The
fuel counter remains as a backstop over that argument.

## opus R5-3 (medium) the recorded fuel residual names a mechanism that cannot occur

Adjudication: CONFIRMED, refuted structurally at `lib/check.ml`'s
`expected_t` and confirmed by execution.  The recorded residual said a
def-shared query whose VALUE unfolds wide is bounded by the 10000 floor
"because `Term.Global` counts 1".  `term_size` is taken on
`Eval.quote globals ctx.size expected_v`, the quote of the ALREADY
EVALUATED expected value, so a reducible def is unfolded before it can
be quoted and no `Term.Global` for it survives;  an opaque def stays a
`VNeutral`, `key_of` returns `None`, and the query fails earlier with
`Inst_unresolved`.  Both executed.

Fix (binding): replace the residual text.  The REAL residual is the
opposite of the recorded one and worse: fuel never fires, because
`term_size` of the fully quoted value is correctly huge, and the cost
sits in computing that quote and in re-quoting the key before every
memo lookup, neither of which is charged.  Measured by opus: a 1 KB
file costs 24.6s at depth 17 and 41.4s at depth 18.  That is the
carried check-budget debt, not a fuel debt, and it is the same sharing
blindness the branching fixture's own header already names as the M5
hash-consing motivation.

## opus R5-4 (medium) the gate re-scope names a marker it did not protect

Adjudication: CONFIRMED by reading `dev/gates.sh`'s order and by
simulation.  The round-4 log says the branching leg moved so a flake
there "cannot blank `PASS-M4FIX-INST-MEMO-KEY` or
`PASS-D-PRELUDE-CHANNEL`".  Half true: four `PASS-D-*` markers still
sat downstream, and the one the sentence names is one of the four.

Fix (binding): move the leg, not the sentence.  The branching leg is
now the LAST leg in the file, below `PASS-D-USAGE-CHANNEL`, so nothing
at all is downstream of it and the round-4 sentence is true as written
for every marker.

## opus R5-5 (medium) plus ctxcat r5 id 15 (medium) the cap covers one constructor of a family

Adjudication: CONFIRMED, measured on the staged binary.  Worst single
stderr line per file: `Inst_depth` 503 bytes (capped), `Inst_unresolved`
32,122, `Mismatch` 800,162 (two uncapped payloads).  `Inst_unresolved`
is built 77 lines above the elided call, in the same function, from the
same `pp_value` payload, and it is the far MORE reachable of the two
instance errors.

Fix (binding): the clamp moves to the construction site of EVERY
`Error.t` payload built from a printed value, through one helper,
`Check.pp_goal`.  An `rg` audit of `pp_value`/`Pp.term` in error
construction found nine such sites in `lib/check.ml`
(`Inst_unresolved`, `Inst_depth`, `Not_a_function`, `Not_a_universe`,
two `Mismatch` payloads plus the "a function" one, three
`Not_inductive`) and exactly one outside it, `Serror.Main_bad_type` in
`surface/run.ml`, which lands on the same one-line stderr channel and
takes the same clamp.  Every other constructor's payload is a NAME or a
fixed string, not a printed term.  The clamp stays at the construction
sites and NOT inside `Error.to_string`, because the suites pin exact
short messages and a central clamp would make that pin a property of
the formatter.

## opus R5-6 (low-medium) the cut counts bytes, and D7c does not pin the constant

Adjudication: both halves CONFIRMED and executed.  (a) A lone 0xC3
reached stderr on `u383.tot` and a UTF-8 decode of the line failed at
position 480.  (b) In a scratch copy `goal_print_cap = 100000` fails
D7c, and `goal_print_cap = 2000` keeps the whole battery green, so the
number was free to move by 5x.

Fix (binding): the cap becomes 2000, the opus-corrected value, and the
cut backs up to a UTF-8 character boundary.  D7d asserts the exact cut
offset on `Check.elide` directly (a string exactly at the cap keeps
every byte;  a two-byte U+00E9 straddling the cap loses the whole
character, not half of it), so the constant and the boundary rule are
both pinned by construction rather than by a budget derived from the
constant itself.

## opus R5-7 (low) the single canonical statement has the formula backwards

Adjudication: CONFIRMED by substitution.  `lib/term.ml` said
`Eval.quote` gives the j-th element of `m_idx` the level
`size + m - 1 - j`.  `Eval.quote` builds
`List.init m (fun i -> Value.var (size + m - 1 - i))`, and that `i` is
a DE BRUIJN offset, which is list position `j = m - 1 - i`.
Substituting gives `size + j`.  The quoted formula was right for the de
Bruijn axis and wrong for the list axis, which is exactly the confusion
the comment was written to remove.  Fix: `size + j`, with the
substitution recorded beside it.

## ctxcat r5 id 17 (medium) SPEC section 6 documents the REVERSED cache identity as shipped

Adjudication: CONFIRMED.  Section 6's debt entry still described D5.3's
`device:inode:mtime:size` stat identity as current design, which audit
F1 proved forgeable and reversed in the same change set that section 2
records.  Fix: rewrite the entry to shipped reality (identity is
`Digest.file`, fail-closed;  `format_version` 9 -> 10;  the stat
signature survives as a five-field MEMO KEY only), cross-reference
`PASS-CACHE-EXEID-CONTENT` and `PASS-CACHE-EXEID-MEMO`, and state the
residual precisely.

## ctxcat r5 id 9 (medium) the `%.6f` stat signature can collide

Adjudication: PARTLY CONFIRMED, and the offered remedies split.  The
memo DOES still exist (`surface/cache.ml`'s `exe_stat_signature`,
`read_exe_memo`, `write_exe_memo`, consulted by `exe_digest_hex`), so
the "refute it, the memo is gone" branch does not apply.  Two distinct
exposures hide under one finding:

- RENDERING.  `%.6f` is microsecond resolution while `st_mtime` and
  `st_ctime` are floats carrying whatever the filesystem provides, and
  APFS and ext4 both provide NANOSECONDS.  Two writes less than a
  microsecond apart therefore produced two DISTINCT floats that the
  format string rendered as ONE string.  That is real information the
  kernel gave us and the rendering threw away, and it costs nothing to
  keep.  FIXED: `%.17g`, which round-trips a float exactly.
- CLOCK GRANULARITY.  On a filesystem or mount whose observed ctime
  does not move on an in-place overwrite, the two timestamps are
  genuinely EQUAL and no rendering can separate them.  Widening
  precision does not touch this, which is why "widen the precision" is
  only half a fix and is argued as such here.  REFUTED as new: this is
  the residual `dev/gates.sh`'s own `PASS-CACHE-EXEID-MEMO` comment
  records at length (opus round 2 executed the search for an
  unprivileged construction and found none: `setattrlist` with
  `ATTR_CMN_CHGTIME` is EPERM for a non-root caller, and ctime is not
  settable by `utimes` or `utimensat`), and a privileged writer is
  already inside the cache directory's accepted trust class.  It is now
  stated in SPEC section 6 too, as part of id 17's rewrite.

Removing the memo was considered and rejected: it would buy nothing
against the granularity exposure that a documented residual does not
already buy, and it would cost the ~3.3ms re-hash on every invocation
of a language whose whole purpose is per-hook startup.

## ctxcat r5 id 6 (medium) `fold_items`'s hardcoded policy is inheritable by accident

Adjudication: CONFIRMED as a naming defect, refuted as a behaviour one.
The hardcoded `Run.default_policy` is correct for the one caller it
has.  Fix: rename to `fold_prelude_items`, callers updated, so the
restriction travels with the name.

## ctxcat r5 id 1 (nit) `index expression(s)`

Adjudication: CONFIRMED.  A one-index family is the common case, so the
parenthesised plural was the shape the reader saw most often.  Fix:
pluralise on `n_indices`.  Four gate assertions pinned the old text and
are updated with it.

## ctxcat r5 id 14 (nit) trivial `Result.fold` passthrough wrappers

Adjudication: CONFIRMED.  Fix: `let*` at all three `run_cli` call sites
in `test/surface.ml`, which is what the file's own binder already does
elsewhere.

## ctxcat r5 id 7 (medium) anonymous arrow-sugar data index coerced to quantity 0

Adjudication: REFUTED BY DESIGN, for the third round running.  It is
verbatim `dev/M4-PLAN.md`'s "Known debts entering M5" entry: "An
explicitly written `(w _ : T) ->` index binder is silently forced to
quantity 0 rather than rejected, because the arrow sugar produces the
identical surface node.  A named `w` binder IS rejected."  `SPEC.md`
section 6 carries the same entry with the rejected alternative spelled
out.  The parser comment at the site already cites both.  No code
change.

## Log-only, one line each

- id 2 (nit) `is_erased_use`'s grouped exhaustive match.  The grouping
  is house style and the exhaustiveness is what carries the soundness
  condition;  a new constructor is a compile error at the predicate
  either way.  No change.
- id 4 (low) `Global.ctor_status`'s `Builtin` carries no name.  Every
  call site reaches it through `Global.find_ind`, which holds the name.
  No change.
- id 5 (nit) `GuardedAt` and `Frozen` share an `Ok` branch in `exec`.
  The finding's own text confirms this is correct and informational.
  No change.
- id 8 (low) `IClass` expansion hardcodes `indices = []`.  Classes have
  no indices in this grammar and the class parameter is asserted to be
  `Type L` exactly.  No change.
- id 10 (low) `write_exe_memo`'s temp name is PID-keyed.  The memo is
  best effort, the write is rename-into-place, and the worst outcome is
  a re-hash.  No change.
- id 11 (nit) `lam_quantities` extended for `Term.Auto`.  The finding
  confirms exhaustiveness was preserved.  No change.
- id 12 (nit) `LBrace`/`RBrace`/`Semi` break the `K`-prefix convention.
  Cosmetic, and renaming three constructors touches the lexer, the
  parser and their tests for no behaviour.  No change.
- id 13 (low) `run_cli` splits the channels and `expect_cli_run_lines`
  concatenates stdout before stderr.  Splitting is the POINT of the
  helper (audit F2 pins which channel a driver error lands on), and no
  fixture emits interleaved output.  No change.
