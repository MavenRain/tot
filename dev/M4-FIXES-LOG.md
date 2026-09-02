# M4 fixes log

Per-round record for the M4 fix batch (dev/M4-FIXES-PLAN.md).  Each
round appends: the verdict per finding, what changed, new tests and
gates, the final PASS decomposition, and the gate tails.

## Fix round 1 (2026-09-02): ctxcat ids 0-9 plus audit F1/F2/F3

Inputs: `tot-m4-review-r1-survivors.json` (10 mechanical survivors) and
`tot-m4-opus-r1-report.md` (deep-logic audit, F1 HIGH, F2, F3).

Baseline recorded BEFORE any edit, on the staged M4 tree (index vs
`b01b3eb`):

```
dunecho build -- --root /Users/oobi/Documents/tot   ->  OK build: 0 errors, 0 warnings
zsh dev/gates.sh                                     ->  GATE-EXIT=0
PASS = 238  (62 gate markers + 79 kernel cases + 97 surface cases)   FAIL = 0
```

### Verdicts

| id | severity | verdict | fixed |
| --- | --- | --- | --- |
| F1 | HIGH | confirmed (audit repro re-executed) | yes |
| F2 | low-medium | confirmed (executed) | yes |
| F3 | low, latent | confirmed (executed) | yes |
| 1 + 6 | medium | confirmed (executed) | yes |
| 2 | low | confirmed (by the call's strictness) | yes |
| 3 | low | confirmed | yes |
| 4 | low | confirmed | yes |
| 5 | nit | confirmed | yes |
| 7 | medium | confirmed (executed and MEASURED) | yes |
| 8 | low | confirmed, source-reachable (executed) | yes |
| 9 | nit | confirmed | yes |
| 0 | nit | confirmed | yes |

Nothing was adjudicated log-only.

### F1 (HIGH): the cache identity is the executable's CONTENT again

`surface/cache.ml`.  `exe_digest_hex` is `Digest.file` once more, and
fails CLOSED: an unreadable image disables the cache for the whole run
(`load` misses, `save` no-ops) with one loud stderr line.  The
`Unix.stat` fields survive only as the key of a MEMO recorded in the
cache directory (`exeid-<md5 of the exe path>.txt`, holding the
signature and the content digest a previous run verified); a matching
signature skips the re-hash, and an absent, unreadable, malformed or
mismatched memo re-hashes.  The signature gained `st_ctime`, the one
field userspace cannot restore: `utimes` (what `touch -r` and a
reproducible-build install step call) resets mtime and BUMPS ctime, so
the in-place overwrite that produced the audit's collision now misses
the memo.  `format_version` 9 -> 10, so every stat-identity blob is
orphaned rather than read.  `cache_dir_opt`/`mkdir_one`/`ensure_dir`
moved above the identity block, which now needs them.

Executed differential (`/Users/oobi/Documents/tot-fix1/cache-f1.sh`,
the audit's own repro):

```
v1 md5=76e036fd3ea4ff28fabb7873d2e3c2ee  v2 md5=2450a33669abdb6aba0038580888937f  (equal size)
install(v1): dev=16777235 ino=516276236 size=2266304 mtime=1788355659.895768267
install(v2): dev=16777235 ino=516276236 size=2266304 mtime=1788355659.895768267
IDENTITY FIELDS IDENTICAL      content now v2? md5=2450a3...   (prints "no such fila")
blobs after run 1: 1
blobs after run 2: 2           <- staged code: 1 (the second binary READ the first one's blob)
markers: run 1 TOT-CACHE-EXEID-CONTENT, run 2 TOT-CACHE-EXEID-MEMO + TOT-CACHE-VERIFY-OK
execute-only install: EXIT=0, 1 stderr line "prelude cache disabled", 0 blobs
```

Gates: `PASS-CACHE-NOEXEDIGEST` restored to its `b01b3eb` assertion
(exit 0, exactly one stderr line matching `prelude cache disabled`,
ZERO blobs), plus two new markers.  `PASS-CACHE-EXEID-CONTENT` replays
the repro inside the battery and requires TWO blobs, the blob header's
exe field to equal the binary's own md5, the memo's recorded digest to
equal it too, the mtime to be genuinely restored, the sizes to match,
and the patched binary to prove it is a different program (its patched
literal reads back).  `PASS-CACHE-EXEID-MEMO` requires a cold run to
announce `TOT-CACHE-EXEID-CONTENT` and NOT the memo marker, and the next
run of the same untouched binary to announce `TOT-CACHE-EXEID-MEMO`.
The md5 tool and the code signer are probed, never assumed;  a missing
md5 tool is a loud failure, never a skipped marker.

### F2: driver channels

`bin/tot.ml`.  The missing-file line, the flag-error line and both usage
lines go to `prerr_endline`.  The missing-file branch returns the
literal `1` again, outside the `--serror-exit` mapping.

Gates `PASS-D-MISSING-FILE-CHANNEL` and `PASS-D-USAGE-CHANNEL` pin
stdout EMPTY, the exact stderr line, and the exit code (1 for the
missing file with and without `--serror-exit 0`; 2 for the unknown flag
and the pathless invocation).  Surface cases `R1-F2a` and `R1-F2b` pin
the same three facts in-process through the new split-channel helper.
Pre-fix, all three assertions failed: the line was on stdout, and
`--serror-exit 0` exited 0.

### F3: `auto` in a result-index position

`lib/check.ml`.  `no_occur` has an explicit `Term.Auto -> false` arm:
its contract is "PROVABLY free of `name`", and the RAW constructor type
is checked before resolution, so an unresolved `auto` may still become a
spine mentioning the family.  The arm is unreachable from `strict_pos`,
which runs on STAMPED arguments.

```
data AutoIdx : Nat -> Type 0 := | autoIdx : AutoIdx auto
pre-fix:  no instance found for Nat            (the ban was skipped; the error came from elaboration)
post-fix: invalid constructor autoIdx: constructor must end in AutoIdx applied to its
          parameters and 1 index expression(s)
```

New: kernel case A6b (bare `Auto` and `Auto` nested under an `App` are
both unclean, an auto-free expression is still clean) and gate
`PASS-M4FIX-AUTO-INDEX`, which also requires the old message NOT to
appear.

### ctxcat 1 + 6: instance-resolution fuel

`lib/check.ml`.  `term_size` is replaced by `term_depth` (the nesting
measure) plus `pi_arity` and `inst_fuel`, and the `Term.Auto` arm passes
`inst_fuel globals expected_t` =
`(1 + term_depth expected_t) * (2 * max instance binders + 2)`.  The
per-level factor comes from the registered instance TABLE, which is what
the finding demands: `build_instance` charges up to 2 per binder (one to
enter the dictionary sub-resolution, one for the continuation), a cost
the query cannot see.  The nesting factor has to come from the query,
because each nested resolution descends into a strict subvalue of the
key and legitimate resolutions nest arbitrarily deep in the query alone
(`EqD (List^n Int)`), so a table-only constant would reintroduce the
same false negative one level deeper.

```
instance : (0 A : Type 0) -> FC1 A -> FC2 A -> FC3 A -> FC4 A -> FCD (FBox A) := ...
pre-fix:  instance resolution for (FC4 Bool) exceeded its fuel   EXIT=1
post-fix: true                                                   EXIT=0
```

New: fixture `test/fixtures/m4fix-inst-binders.tot` and gate
`PASS-M4FIX-INST-BINDERS` (exit 0, `true` printed, and no "fuel" in the
output).

### ctxcat 7: `match_scrut` inferred every scrutinee twice

`lib/check.ml`.  Inference now runs ONCE at the ambient mode;  the
mode-`Zero` pass is a FALLBACK taken only when that one failed, and a
non-subsingleton family then returns the ambient error.  The soundness
argument is written out at the function: mode reaches only the `Var`
rule, the `Global` axiom rule and multiplicative propagation, none of
which changes the stamped output, so the two passes agree on the term
and the type whenever both succeed and the mode decides only whether
inference errors.  The fallback cannot re-explode, because a nested
match that needs the erased-hypothesis allowance succeeds at the ambient
mode (its own `match_scrut` absorbed the fallback).

Measured on the staged binary, matches nested in SCRUTINEE position:

```
depth 12 -> 0.01s    depth 16 -> 0.07s    depth 18 -> 0.27s    depth 20 -> 1.08s
```

4x per two levels, so depth 26 extrapolates to ~70 s.  After the fix:

```
depth 12 -> 0.00s    depth 20 -> 0.00s    depth 26 -> 0.00s    depth 30 -> 0.00s
```

New: fixture `test/fixtures/m4fix-nest26.tot` (26 levels) and gate
`PASS-M4FIX-NEST-DEPTH` under a 15 s watchdog, with the exact output
pinned;  the pre-fix cost turns into exit 124, never a silently slow
gate.

### ctxcat 8: the raw result-head check vs deleted `Term.Ann`

Adjudicated BY EXECUTION, and the surface grammar does express it (the
parser builds `Syntax.SAnn` for any parenthesized `(e : T)`):

```
data Foo : Type 0 := | mk : (Foo : Type 0)
data Foo2 (0 A : Type 0) : Type 0 := | mk2 : Foo2 (A : Type 0)
pre-fix:  invalid constructor mk / mk2: constructor must end in ... applied to its
          parameters and 0 index expression(s)        (a reason unrelated to the cause)
post-fix: both check clean
```

`lib/check.ml` gains the total head-stripper `strip_ann`, applied at
`strip_pis`'s match scrutinee (so an annotated telescope still peels),
at `is_applied`'s codomain, and at each PARAMETER-position argument.
Index positions keep the un-stripped argument, so `index_expr_clean`
still inspects an annotation's TYPE half for occurrences of the family.
`strip_ann` is the identity on stamped terms, so the positivity path and
every elaborated call are unchanged.

New: fixture `test/fixtures/m4fix-ann-ctor.tot` with gate
`PASS-M4FIX-ANN-CTOR` (exact output pinned), and kernel case A6c for
`strip_ann` itself (nested wrappers collapse, an unannotated term is
untouched, an annotated ARGUMENT is not rewritten).

### ctxcat 2: eager `unresolved ()`

`lib/check.ml`.  `Option.to_result ~none:` takes a strict argument, so
the `pp_value` call ran on every successful resolution.  Both sites now
use the house lazy idiom, no match on Option:

```
key_of av |> Option.to_result ~none:() |> Result.map_error (fun () -> unresolved ())
```

No new test: the rewrite is observationally equivalent (`pp_value` is
pure), and both paths are already pinned, the success path by kernel D1
/ D5 and `PASS-M4D-AUTO`, the failure path by kernel D2 / D3 / D4, which
assert the `Inst_unresolved` tag on the message this code builds.

### ctxcat 3: `IInstance` duplicated `IDef`

`surface/run.ml` gains `install_def ~loc ~exec ~name ~ty_t st globals`,
the shared tail (fetch the entry back, define the runtime thunk in RUN
mode only, format the summary line).  Both arms call it, so the two
differ solely in the name they register under.  Covered by the existing
class/instance cases (kernel D-suite, surface D11 to D13,
`PASS-M4D-AUTO`, `PASS-M4D-COHERENCE`, `PASS-M4D-GUARD-CLASSES`).

### ctxcat 4 + 5: test-helper duplication and temp-file leaks

`test/surface.ml` gains `with_temp_file` (removal rides `Fun.protect`'s
finaliser, which cannot itself raise) and `run_cli`, one spawn helper
that runs the CLI under the watchdog and returns
`(exit code, stdout lines, stderr lines)` with the channels captured
SEPARATELY.  `expect_cli_run_lines` and `expect_cli_exit` are now thin
wrappers over it, and the split channels are what the new F2 cases
needed.

### ctxcat 9: `define_instance` installed a second elaboration

`lib/check.ml`.  `define` gains `?stamped_ty` (documented precondition:
the caller's own `infer_univ globals empty_ctx ty` output, for the same
`globals` and `ty`), threaded through a thunk so `Option.fold`'s eager
`~none` does not run the elaboration anyway.  `define_instance` passes
the `ty'` it validated, so the validated artifact IS the installed one
and elaboration runs once per instance instead of twice.

### ctxcat 0: byte-identical guard predicates

`examples/guard-classes.tot`.  `verdictOfDanger2` now tests the negated
case and swaps the arms (`match boolEq b false with | true => allow |
false => deny ..`), a definitionally different program that is
propositionally equal, so `agreeOnTrue` compares two guards instead of
two copies of one.  `boolEq` is `reducible`, so the true case still
computes and `PASS-M4D-GUARD-CLASSES`'s pinned output is byte-identical.

### SPEC.md

Four decision entries corrected, because a spec that states a false
property is worse than the code: the stat-identity entry now records the
reversal and the memo design;  the `--serror-exit` entry records that
the missing-file branch is no longer routed through it;  the Stage A
raw-check entry records the two node shapes elaboration deletes and how
each is handled;  the subsingleton entry records the single-inference
`match_scrut`;  and the class entry records `inst_fuel`.

### Result

```
dunecho build -- --root /Users/oobi/Documents/tot   ->  OK build: 0 errors, 0 warnings
zsh dev/gates.sh                                     ->  GATE-EXIT=0
PASS = 250  (70 gate markers + 81 kernel cases + 99 surface cases)   FAIL = 0
```

Decomposition versus the 238-PASS baseline: +8 gate markers
(`PASS-CACHE-EXEID-CONTENT`, `PASS-CACHE-EXEID-MEMO`,
`PASS-M4FIX-ANN-CTOR`, `PASS-M4FIX-AUTO-INDEX`,
`PASS-M4FIX-INST-BINDERS`, `PASS-M4FIX-NEST-DEPTH`,
`PASS-D-MISSING-FILE-CHANNEL`, `PASS-D-USAGE-CHANNEL`), +2 kernel cases
(A6b, A6c), +2 surface cases (R1-F2a, R1-F2b).  No existing case or
marker was deleted or weakened;  `PASS-CACHE-NOEXEDIGEST` was RESTORED
to its stricter `b01b3eb` meaning, the one change the round was
explicitly chartered to make.

Gate tail:

```
PASS-M4C-SUBST-IDENTITY
PASS-M4D-AUTO
PASS-M4D-COHERENCE
PASS-M4D-SERROR-EXIT
PASS-M4D-REQUIRE-MAIN
PASS-M4D-GUARD-CLASSES
PASS-M4FIX-ANN-CTOR
PASS-M4FIX-AUTO-INDEX
PASS-M4FIX-INST-BINDERS
PASS-M4FIX-NEST-DEPTH
PASS-D-MISSING-FILE-CHANNEL
PASS-D-USAGE-CHANNEL
GATE-EXIT=0
```

Cache markers, in place:

```
PASS-CACHE-NOHOME
PASS-CACHE-NOEXEDIGEST
PASS-CACHE-EXEID-CONTENT
PASS-CACHE-EXEID-MEMO
```

Files touched (15): `lib/check.ml`, `surface/cache.ml`,
`surface/run.ml`, `bin/tot.ml`, `test/main.ml`, `test/surface.ml`,
`dev/gates.sh`, `examples/guard-classes.tot`, `SPEC.md`,
`dev/M4-FIXES-PLAN.md` (new), `dev/M4-FIXES-LOG.md` (new), and four new
fixtures (`test/fixtures/m4fix-ann-ctor.tot`,
`m4fix-auto-index.tot`, `m4fix-inst-binders.tot`, `m4fix-nest26.tot`).
No git mutation was run.

### Residuals

- The memo is a file in the cache directory, which the module doc
  comment already classes as a TRUSTED input (the same class as the
  binary).  Someone who can write there can still forge a memo, which
  makes a run adopt a wrong identity;  that is the pre-existing
  cache-directory trust class, unchanged, and SPEC.md section 6 already
  records it.  What the fix removes is the accidental collision: a
  reproducible-build install can no longer make two byte-different
  binaries share a blob.
- `inst_fuel` folds the globals table per `auto` node.  Instance tables
  are small and the fold is one string-prefix test per entry, so this
  was not memoized;  if a future prelude makes it measurable, cache the
  table cost in `Global.t` at registration time.

---

## Fix round 2 (2026-09-02): ctxcat r2 ids 1/3/4/5/6/7 plus opus R1-R4

Scope: the regressions round 1 ITSELF introduced or left open, on the
staged tree (52 files vs `b01b3eb`).  Ground that held in round 1 was
not re-audited.  Inputs: `tot-m4-review-r2-survivors.json` (six ctxcat
survivors), `tot-m4-opus-r2-report.md` (four findings), `dev/M4-PLAN.md`
section A6 for the stamp adjudication.  Adjudications and the decided
fixes are in `dev/M4-FIXES-PLAN.md` under "# Round 2".

Baseline before any edit, re-run and green: `dunecho build` 0 errors,
0 warnings;  `zsh dev/gates.sh` GATE-EXIT=0;  250 PASS / 0 FAIL
(81 `test/main.exe` + 99 `test/surface.exe` + 70 gate markers).

Soundness is unchanged.  Nothing here relaxes a rule.  Two of the four
code fixes are pure cost fixes with provably identical observable
behavior, one removes a false REJECT, one removes a crash and a hang.

### Verdicts

| id | finding | verdict | fixed |
| --- | --- | --- | --- |
| ctxcat 4 + opus R1 | `match_scrut` Zero fallback re-runs a byte-identical inference | CONFIRMED (executed) | yes |
| ctxcat 5 | instance fuel bounds only the resolution PATH | CONFIRMED (executed) | yes |
| ctxcat 1 | `scrut_q` stamps the literal `Many` | REFUTED BY DESIGN (M4-PLAN A6.4) | no, by design |
| opus R3 | Ann false-reject survives on the spine HEAD | CONFIRMED (executed) | yes |
| opus R2 | three sibling driver paths escape the channel fix | CONFIRMED (executed) | yes |
| opus R4 | `--require-main` under `--serror-exit 0` | CONFIRMED, recorded not changed | no, SPEC debt |
| ctxcat 3 | `expect_cli_run_lines` hardcodes `~what:"F1"` | CONFIRMED | yes |
| ctxcat 6 | three Stage D CLI gates run unwatchdogged | CONFIRMED | yes |
| ctxcat 7 | nest-depth timing gate charges `dune exec` to its budget | CONFIRMED | yes |

### ctxcat 4 + opus R1: the `2^depth` blowup moved to the error path

Round 1's docstring claimed the fallback "cannot re-explode, because a
nested match that NEEDS the erased-hypothesis allowance succeeds at the
ambient mode, so an ambient failure is never itself nested".  That is
true only for well-typed files.  A missing branch, a wrong scrutinee
type or a missing motive fails at the ambient mode AND at `Zero`, at
every level, so each level re-ran the whole subterm.  Re-measured here
on a binary built from the staged tree, `tot check`, wall clock:

```
innermost branch missing   d=14 0.06s   18 0.11s   22 1.21s   26 18.18s
wrong scrutinee type       d=14 0.05s   18 0.09s   22 0.81s   26 11.78s
no `as .. return`          d=14 0.05s   18 0.07s   22 0.41s   26  5.79s
```

About 2x per level in all three, which is `2^d`.

Change (`lib/check.ml`, `match_scrut`): the `Zero` fallback is now
guarded on the ambient mode.  When `mode` is already `Zero`, the
ambient error is propagated with NO second call.  `infer` is a pure
function of `(globals, ctx, mode, scrut)`, so the skipped call was
byte-identical to the first and could only fail again with the same
error value, which is the value round 1 propagated;  the change is
observationally equivalent.

The recurrence, written into the docstring because the sentence it
replaces was the false one.  Let `Z d` be one `infer` at mode `Zero`
over a chain of `d` matches nested in SCRUTINEE position, and `A d` the
same at an ambient `Many`.  At `Zero` the fallback is skipped, so
`Z d = Z (d-1) + O(1) = O(d)`, a single linear pass.  At `Many` each
level pays one ambient attempt and, only when that failed, ONE linear
`Zero` pass over the same subterm:
`A d = A (d-1) + Z (d-1) + O(1)`, hence `A d = O(d^2)`.  Polynomial at
every ambient mode, never `2^d`.  No third case exists: quantity
multiplication never raises a mode, so any mode below the top is
`Zero`.

New fixtures: `test/fixtures/m4fix-nest26-ill.tot` (26 levels, the
innermost match missing its `false` branch) and
`test/fixtures/m4fix-nest30-nomotive.tot` (30 levels, no `as .. return`
anywhere, the opus report's motive-less variant;  depth 30 rather than
26 so the pre-fix cost clears the budget by 8x, not by a hair).

New gates, both under `"$watchdog" 10`, both on the already-built
binary: `PASS-M4FIX-NEST-ILL` pins exit 1 AND
`match branches do not fit the declaration: expected false, found <none>`;
`PASS-M4FIX-NEST-NOMOTIVE` pins exit 1 AND
`cannot infer a type for a match without 'as .. return'`.  Pinning the
message matters: a fast WRONG error is not a fix.

### ctxcat 5: instance fuel is now a budget, not a path counter

`build_instance` handed `fuel - 1` to BOTH the dictionary
sub-resolution and the continuation, so the sub-resolution's own
consumption was never deducted.  `validate_instance_shape` accepts
`(0 A : Type 0) -> C A -> C A -> C (Box A)`, so resolving
`C (Box^n Bool)` ran 2^n identical sub-resolutions while `inst_fuel`
grew only linearly in n and could not fire.  Re-measured on the staged
binary, `tot run`: 0.06s at n=10, 0.41s at 14, 7.43s at 18, 32.82s at 20.

Change (`lib/check.ml`): `resolve_auto` and `build_instance` now return
`(Term.t * int)`, the resolved term paired with the REMAINING fuel, and
the dictionary arm passes `left - 1` to the continuation.  Threading,
no mutation and no memo table, per the preferred option.  Every
recursive step of `build_instance` decrements a now-global budget and
`resolve_auto` only forwards it, so the walk performs at most
`inst_fuel` steps: it resolves or reports `Inst_depth`, and cannot
hang.  `inst_fuel`'s formula is unchanged, because total steps and
per-path steps coincide on every non-branching telescope.  The one
external caller (`check`'s `Term.Auto` arm) destructures the pair;
`test/main.ml`'s D7 case already ignored the `ok` payload, so it needed
no edit.

Checked that no new false negative was opened: a NON-branching chain
(`(0 A : Type 0) -> C A -> C (Box A)`) resolves at nesting 1, 5, 10, 20,
40 and 80, all exit 0, all under 0.1s.  `PASS-M4FIX-INST-BINDERS` (the
4-binder telescope round 1 added) stays green.

New fixture `test/fixtures/m4fix-inst-branching.tot` (two dictionary
binders on the same type variable, nesting depth 20) and new gate
`PASS-M4FIX-INST-BRANCHING` under `"$watchdog" 10`.  Its oracle is
"resolve or report `Inst_depth`, never hang": either exact outcome
passes and a 124 or any other exit fails, so a future `(class, key)`
memo flips the gate deliberately rather than silently.  The reach limit
is recorded as a SPEC debt.

### ctxcat 1: refuted by design

`dev/M4-PLAN.md` A6.4 ratifies the literal `Many` stamp verbatim: "the
non-subsingleton stamp is `Many`, NOT the ambient mode ... restricting
the `Zero` stamp to the subsingleton case is what makes `Erase`'s
two-or-more-branch backstop provably unreachable.  The alternative
rejected: stamping the ambient mode, which would let a mode-`Zero`
match on a two-constructor family carry `scrut_q = Zero` and reach the
`Zero` erasure arm through a `Lam Zero` walk."  The suggested `Ok mode`
IS the rejected alternative and would make the erasure `Zero` arm
reachable.  No code change.  A one-line comment at the site now cites
the A6 rule, so the next reviewer stops there.

### opus R3: the Ann false-reject on the spine head, FIXED (not deferred)

The fix is local to the Ann-stripping helper, so it was made rather
than recorded as debt.  `Totality.spine` unwinds `App` nodes without
stripping, so an annotation on the spine's own head survived round 1's
outer `strip_ann` and left `head_ok` false.  Change (`lib/check.ml`,
`is_applied`): strip the head that `spine` returns.  One line;
`Totality.spine`'s shared walk is untouched, which is why this
direction was taken over peeling `Ann` inside `spine`.

New fixtures `m4fix-ann-head.tot` (the codomain form AND the
parameter-argument form) and `m4fix-ann-head-neg.tot`.  New gates
`PASS-M4FIX-ANN-HEAD` (exact output pinned) and
`PASS-M4FIX-ANN-HEAD-NEG` (`(Nat : Type 0) zero` as `BVec`'s codomain
still fails with `BVec`'s own result-shape reason, so the strip does
not start accepting a wrong head).

### opus R2: the three sibling driver paths

`Sys.file_exists` is TRUE for a directory, for a FIFO and for a regular
file with no read permission, so control reached
`In_channel.with_open_text`.  Re-run on the staged binary: a directory
and an unreadable file each printed `Fatal error: exception Sys_error(...)`
and exited 2 (the code the driver reserves for USAGE errors, so a hook
could not tell "you called me wrong" from "your script is unreadable"),
with `--serror-exit` never consulted;  a FIFO did not exit at all.

Change (`bin/tot.ml`): a `source_error` sum (`Missing`, `Not_regular`,
`Unreadable`) and a total `read_source` that classifies before reading.
`Sys.is_regular_file` stats rather than opens, so a FIFO is classified
without blocking on a writer;  the single residual raise (a file that
loses its read bit between the stat and the open) is converted at that
one stdlib boundary and becomes `cannot be read`.  All three now take
the missing-file contract exactly: stdout EMPTY, one driver line on
stderr, the literal exit 1, outside the `--serror-exit` mapping.
Verified after the change:

```
check DIR                     exit 1  stdout 0B  "<path>: not a regular file"
check --serror-exit 0 DIR     exit 1  stdout 0B  (same line)
check FIFO                    exit 1  stdout 0B  "<path>: not a regular file"
check --serror-exit 0 FIFO    exit 1  stdout 0B  (same line)
check UNREADABLE              exit 1  stdout 0B  "<path>: cannot be read"
check --serror-exit 0 UNREAD. exit 1  stdout 0B  (same line)
check MISSING                 exit 1  stdout 0B  "<path>: no such file"  (unchanged)
```

Both channel gates were extended, as required: `dev/gates.sh` gains
`PASS-D-UNUSABLE-FILE-CHANNEL` (six probes under `"$watchdog" 15`, so a
re-blocking open returns a loud 124 rather than stalling the run), and
`test/surface.ml` gains the in-process twin `R2-F2c`.  The existing
`PASS-D-MISSING-FILE-CHANNEL`, `PASS-D-USAGE-CHANNEL`, `R1-F2a` and
`R1-F2b` are untouched and still green.

SPEC.md's "The CLI file-open can still raise on a permission race
despite the existence guard" is retired in place, with the new contract
written out.

### opus R4: recorded, not changed

`--require-main` under `--serror-exit 0` exits 0 on a mainless file,
which a hook reads as allow.  The missing-FILE branch is deliberately
outside the mapping because it is a driver-level verdict about the
target's usability;  a mainless file is a script-level verdict about
content, so flipping it changes a shipped flag's behavior and belongs
to a deliberate decision.  SPEC.md section 6 now records the rule and
the repro.

### ctxcat 3, 6, 7: the test and gate surfaces

- ctxcat 3: `expect_cli_run_lines` takes `~what` as its own required
  parameter;  the three call sites pass `"F1"`, `"T0"` and `"B6"`, so
  `no_watchdog_error` names the regression that is actually running.
- ctxcat 6: `PASS-M4D-SERROR-EXIT`, `PASS-M4D-REQUIRE-MAIN` and
  `PASS-M4D-GUARD-CLASSES` now wrap all six `dune exec` invocations in
  `"$watchdog" 30`, exit-code assertions kept, so a 124 fails loudly.
- ctxcat 7: `PASS-M4FIX-NEST-DEPTH` runs
  `"$ROOT"/_build/default/bin/tot.exe` under its 15s watchdog instead of
  `dune exec --root`, so the workspace build lock and a possible rebuild
  are no longer charged to a TIMING budget.  Every gate above it has
  already forced that binary to be built, which is the same precondition
  the F2 gates in the block rely on.  The three new timing gates use the
  same form.

### Non-vacuity

Every new gate was run against a temporarily reverted build (all four
code fixes backed out, rebuilt green) and every one failed there:

```
m4fix-nest26-ill        exit 124 at the 10s budget   (post-fix 0.011s, exit 1)
m4fix-nest30-nomotive   exit 124 at the 10s budget   (post-fix 0.011s, exit 1)
m4fix-inst-branching    exit 124 at the 10s budget   (post-fix 0.011s, exit 1)
m4fix-ann-head          exit 1, Bad_ctor on avnil    (post-fix 0.011s, exit 0)
check DIR               exit 2, Sys_error crash dump (post-fix exit 1, driver line)
check FIFO              exit 124, no output at all   (post-fix exit 1, driver line)
check UNREADABLE        exit 2, Sys_error crash dump (post-fix exit 1, driver line)
```

`m4fix-ann-head-neg` passes on both sides, which is what a negative
oracle is for: it pins that the strip does not start over-accepting.
`m4fix-nest26` (well typed) passes on both sides too, which is round
1's own fix still holding.  The sources were restored from a
byte-for-byte snapshot and rebuilt before the final battery.

### Result

`dunecho build --root .`: 0 errors, 0 warnings.
`zsh dev/gates.sh`: GATE-EXIT=0, **257 PASS / 0 FAIL**, up from 250.

Decomposition: 81 `test/main.exe` (unchanged) + 100 `test/surface.exe`
(+1: `R2-F2c`) + 76 `dev/gates.sh` markers (+6:
`PASS-M4FIX-NEST-ILL`, `PASS-M4FIX-NEST-NOMOTIVE`,
`PASS-M4FIX-INST-BRANCHING`, `PASS-M4FIX-ANN-HEAD`,
`PASS-M4FIX-ANN-HEAD-NEG`, `PASS-D-UNUSABLE-FILE-CHANNEL`).

Post-fix wall times, warm, best of three runs of the built binary:

```
m4fix-nest26-ill.tot        check  exit 1  0.011s   (was 18.18s)
m4fix-nest30-nomotive.tot   check  exit 1  0.011s   (was about 80s)
m4fix-inst-branching.tot    run    exit 1  0.011s   (was 32.82s)
m4fix-nest26.tot            check  exit 0  0.011s   (re-timed, unchanged)
m4fix-inst-binders.tot      run    exit 0  0.011s   (re-timed, unchanged)
m4fix-ann-head.tot          check  exit 0  0.011s   (was a false Bad_ctor)
```

Files touched: 12.  Seven edited (`lib/check.ml`, `bin/tot.ml`,
`test/surface.ml`, `dev/gates.sh`, `SPEC.md`, `dev/M4-FIXES-PLAN.md`,
`dev/M4-FIXES-LOG.md`) and five new fixtures under `test/fixtures/`
(`m4fix-nest26-ill.tot`, `m4fix-nest30-nomotive.tot`,
`m4fix-inst-branching.tot`, `m4fix-ann-head.tot`,
`m4fix-ann-head-neg.tot`).  No existing test, gate or fixture was
weakened or deleted.  No git mutation was run.

### Residuals

- The `(class, key)` instance memo.  Fuel is a real budget now, so a
  branching telescope terminates, but it terminates with `Inst_depth`
  rather than resolving.  Recorded in SPEC.md section 6 with the shape
  and the measured reach;  `PASS-M4FIX-INST-BRANCHING`'s oracle accepts
  either outcome, so adding the memo is a one-line gate update.
- `--require-main` under a fail-open exit mapping (opus R4), recorded in
  SPEC.md section 6 with its repro.
- `test/surface.ml`'s own `run_gate` still guards on `Sys.file_exists`
  alone.  It is the TEST harness's gate driver, not the shipped CLI, it
  is only ever pointed at repo fixtures by `dev/gates.sh`, and it writes
  to stdout by design (it is the thing whose stdout the gates read), so
  the driver contract this round repaired does not apply to it.

## Fix round 3 (2026-09-02): opus R3-1..R3-6 plus ctxcat r3 ids 0-4, 6

Scope: the five round-2 surfaces the round-3 reviews re-opened.  Ground
that held two rounds of executed attack was not re-audited.  Inputs:
`tot-m4-opus-r3-report.md` (six findings, all repro-executed) and
`tot-m4-review-r3-survivors.json` (six ctxcat survivors, all
test/gate/doc hygiene).  Adjudications and the decided fixes are in
`dev/M4-FIXES-PLAN.md` under "# Round 3".

Baseline before any edit, re-run and green: `dunecho build` 0 errors, 0
warnings;  `zsh dev/gates.sh` GATE-EXIT=0;  257 PASS / 0 FAIL (81
`test/main.exe` + 100 `test/surface.exe` + 76 gate markers).

Soundness is unchanged.  Nothing here relaxes a kernel rule.  The
headline fix RESTORES reach round 2 removed;  the second removes a crash,
a hang and a fail-open from the last unguarded read in the tree.

### Verdicts

| id | finding | verdict | fixed |
| --- | --- | --- | --- |
| opus R3-1 | threaded fuel is a broad reach regression | CONFIRMED (executed) | yes |
| opus R3-2 | the PRELUDE read is the unfixed fourth channel sibling | CONFIRMED (executed) | yes |
| opus R3-3 | the `(class, key)` SPEC debt misdescribes what ships | CONFIRMED | yes, entry retired and rewritten |
| opus R3-4 | `is_regular_file` also rejects live pipes and `/dev/stdin` | CONFIRMED, kept BY DECISION | no, documented contract |
| opus R3-5 | no gate can see the R3-1 regression class | CONFIRMED | yes |
| opus R3-6 | `Inst_depth` names a partially peeled Pi, not the query | CONFIRMED (executed) | yes |
| ctxcat 0 | `--require-main` + `--serror-exit 0` fail-open | REFUTED BY DESIGN (SPEC section 6 records it) | no, log-only |
| ctxcat 1 | gate `chmod 000` sibling is not root-safe | CONFIRMED | yes |
| ctxcat 2 | anonymous arrow-sugar index coerced to quantity 0 | REFUTED BY DESIGN (M4-PLAN M5 debts) | no, log-only |
| ctxcat 3 | `require_main` fires in check mode too | CONFIRMED as observation, uniform BY DESIGN | doc + a new gate leg |
| ctxcat 4 | `test/surface.ml` `chmod 000` case is not root-safe | CONFIRMED | yes |
| ctxcat 6 | the cache memo's HIT condition is never adversarially tested | CONFIRMED, ACCEPTED as residual | no, argued in gate + SPEC |

### R3-1 + R3-5 + R3-6: the (class, key) memo, third and final attempt

Round 2 turned `inst_fuel` into a budget for the whole resolution but
kept it sized like a per-path depth counter, so it rejected any shape
whose total work grows faster than the query's DEPTH.  Reproduced here
on the staged binary, matching the report exactly: the two-class shape
`(0 A) -> TC A -> TD A -> TC (TBox A)` failed from nesting 6 (round 1
answered nesting 30 in 0.034s), the SPEC's own same-variable shape
failed from nesting 4, and eight INDEPENDENT chains -- `k*n`
sub-resolutions, linear work, answered by round 1 at k=8 n=40 in 43ms --
failed from k=8 n=20.

Change (`lib/check.ml`).  `resolve_auto` and `build_instance` now thread
an `inst_state` record: the fuel, an immutable `Term.t` map memo, and
the ORIGINAL goal.  Passed in, returned updated, no mutable state.  The
memo is consulted before the instance lookup, charges no fuel on a hit,
and is written only on success, so a divergent path can never hit it and
the backstop stays reachable for one.  It is scoped to ONE `Term.Auto`
(`check`'s Auto arm builds a fresh `inst_start`), and that scoping is
the whole soundness argument: `globals` and `ctx` are invariant across a
single walk, so a key that resolved once resolves identically again.

The KEY is the class name paired with the class argument's own quoted
term, not its head symbol.  A head-only key is unsound and the mutant
proves it: two sibling dictionary sub-goals of a two-type-binder
instance can share a head while differing in its arguments, and on the
head-only build `m4fix-inst-memo-key.tot` AND the ordinary
`m4fix-inst-twoclass.tot` both fail with a type mismatch (the candidate
re-check catching the wrong dictionary).  The map key is a hand-rolled
INJECTIVE encoding of `Term.t` -- tag letter per constructor,
length-prefixed strings, count-prefixed lists, pieces accumulated in
reverse and joined once so it is linear in the term -- rather than
`Stdlib.compare`, which is total on this first-order type today but is
not a property `Term.t` promises.

`inst_fuel` is now `Int.max 10000 (16 * <round-2 formula>)`.  With the
memo the work is bounded by the number of distinct (class, key) pairs
reachable, which is the class count times the query's distinct SUBVALUE
count;  a depth-only formula cannot bound that, because a wide query has
many subvalues at one depth.  The 16x keeps the old argument's shape for
deep queries and the flat floor covers wide ones.  Measured headroom:
the deepest gate shape spends 133 of 10000, a 400-level chain about
1200.

R3-6: `Inst_depth`'s payload is `inst_state.goal`, the original query
value, not the partially peeled `ity`.  Carried as a `Value.t` so
`pp_value` still runs on the failure path only.

R3-1's boundary detail (the `fuel <= 0` test at `build_instance`'s
entry firing on a no-op step) is deliberately NOT changed: it is a
symptom of a tight budget, the budget is no longer tight, and moving the
test would weaken `test/main.ml`'s D7, whose contract is "fuel 0 is
`Inst_depth`, whatever `ity` is".

Post-fix reach, `run`, warm, best of three:

```
m4fix-inst-twoclass.tot     two classes, nesting 30    exit 0   0.039s
m4fix-inst-spec16.tot       SPEC shape, nesting 16     exit 0   1.050s
m4fix-inst-chains.tot       8 chains, n=40             exit 0   0.051s
m4fix-inst-small-reach.tot  both shapes, small depth   exit 0   0.016s
m4fix-inst-memo-key.tot     colliding key HEADS        exit 0   0.015s
m4fix-inst-branching.tot    SPEC shape, nesting 20     exit 0  20.515s
```

The last line is the one honest disappointment of this round and it is
recorded as such.  Depth 20 RESOLVES, where round 2 rejected it and
round 1 took 32.82s, but it is not fast, and the memo cannot make it
fast.  A branching telescope's resolved dictionary is a BINARY TREE, so
at nesting n the emitted term is 2^n nodes (about a million here)
however quick the walk that built it was.  Measured split at depth 20:
2.8s for everything up to and including resolution, 16.8s for the
mandatory re-check of the candidate, which walks the term as a tree
because `Term.t` has no sharing.  That is a TERM SIZE limit, not a
resolution one, it is now what SPEC.md section 6 records in place of the
retired memo debt, and term-level sharing (a `let`-nest over the memo's
entries, or hash-consing) is the M5 fix.  `PASS-M4FIX-INST-BRANCHING`
therefore keeps the depth-20 fixture, requires RESOLUTION, and gets a
60s budget with the measurement and the reason in its comment.

New fixtures: `m4fix-inst-twoclass.tot`, `m4fix-inst-spec16.tot`,
`m4fix-inst-chains.tot`, `m4fix-inst-small-reach.tot`,
`m4fix-inst-memo-key.tot`.  New gates: `PASS-M4FIX-INST-TWOCLASS`,
`PASS-M4FIX-INST-SPEC16`, `PASS-M4FIX-INST-CHAINS`,
`PASS-M4FIX-INST-SMALL-REACH`, `PASS-M4FIX-INST-MEMO-KEY`, all under the
watchdog, all pinning the computed VALUE and not just the exit code (a
fast wrong answer is not a fix).  New kernel case: `D7b: Inst_depth
names the query, not the peeled Pi`.

Oracle changes, both authorised by this round's brief and by round 2's
own log: `PASS-M4FIX-INST-BRANCHING` now requires resolution instead of
accepting either outcome, and `test/main.ml`'s D7 call site spells
`Check.inst_start 0 ity` for the new signature with its assertion
unchanged.

### R3-2: the prelude read, the fourth channel sibling

Reproduced on the staged binary with a valid target file throughout:

```
TOT_PRELUDE=<dir>       check                 exit 2   Sys_error crash dump
TOT_PRELUDE=<dir>       check --serror-exit 0 exit 2   same
TOT_PRELUDE=<unread>    check                 exit 2   Sys_error crash dump
TOT_PRELUDE=<fifo>      check                 exit 124 blocked, no output at all
TOT_PRELUDE=<missing>   check --serror-exit 0 exit 0   FAIL-OPEN
```

Change: the classifier moves out of `bin/tot.ml` into a new
`surface/source.ml` (`error`, `message`, `is_regular_file`, `read`), so
the target read and the prelude read share ONE precheck instead of two
copies that can drift.  `Bootstrap.prelude_source ()` classifies the
prelude path with it and returns the bytes;  `run_with_prelude` routes a
classification failure to the TARGET file's contract exactly and hands
the bytes to a new `cached_state_of_src`, so the prelude is still read
once per invocation.  `read_prelude_src` is total for the in-band
callers.  After the change, all four cases, both with and without
`--serror-exit 0`:

```
prelude: <path>: not a regular file   exit 1  stdout 0B   (dir, FIFO)
prelude: <path>: cannot be read       exit 1  stdout 0B
prelude: <path>: no such file         exit 1  stdout 0B
```

A prelude whose CONTENT is broken keeps the `serror_exit` mapping,
unchanged.  New gate `PASS-D-PRELUDE-CHANNEL`, eight probes under
`"$watchdog" 15`.  The stale docstring that cited a retired SPEC debt
as live is rewritten.

### R3-4: the regular-file contract, kept and documented

`tot check <(gen)` and `tot check /dev/stdin` stay rejected.  Hooks are
handed real files, and a target that can block the checker forever is
the worse failure.  What changes is that it is now a stated contract:
SPEC.md section 6 and README.md each say the target must be a REGULAR
file, that process substitution and `/dev/stdin` are rejected, and that
generated source goes through a temporary file.  The message already
names the requirement and the path (`<path>: not a regular file`), so
its wording is unchanged.

### ctxcat 1 + 4: the chmod-000 cases are root-guarded

`chmod 000` does not deny uid 0.  `test/surface.ml` now guards its
unreadable sub-case on `Unix.geteuid ()` and prints
`SKIP R2-unreadable: ...` under root;  `dev/gates.sh` guards the F2
sibling and the new prelude gate on `id -u` and prints
`SKIP-D-UNUSABLE-FILE-CHANNEL-UNREADABLE` /
`SKIP-D-PRELUDE-CHANNEL-UNREADABLE`.  Both gates still PASS overall
under root, saying out loud that the sub-case was skipped rather than
claiming coverage.  Unprivileged runs are unchanged and keep every
probe -- proved by mutation, below.

### ctxcat 3: uniform `require_main`, now pinned

No behaviour change.  `main_epilogue`'s doc comment says the flag fires
in check and run alike and why (a content verdict must not depend on the
verb), and `PASS-M4D-REQUIRE-MAIN` gains a `check --require-main` leg so
a later "gate it on exec" change fails the battery.

### ctxcat 6: accepted residual, argued not asserted

No fake-stat seam.  `PASS-CACHE-EXEID-MEMO`'s comment and SPEC.md
section 6 now state exactly why a memo HIT on changed bytes is not
testable unprivileged (opus round 2 proved `setattrlist` with
`ATTR_CMN_CHGTIME` returns `EPERM` for a non-root caller, and no
unprivileged call sets ctime), why a privileged attacker is already
inside the accepted cache-directory trust class, and what exposure
genuinely remains (a mount whose observed ctime does not move on an
in-place overwrite).

### Non-vacuity

Every new gate and every new case was run against a temporarily mutated
build, one mutation at a time, each followed by a byte-for-byte restore
verified by md5 (`/Users/oobi/Documents/tot-fix3/snap.sh`).  Every one
failed on the mutant:

```
M1  memo removed + inst_fuel back to the round-2 formula
      m4fix-inst-twoclass      exit 1 Inst_depth   (post-fix exit 0, 0.039s)
      m4fix-inst-spec16        exit 1 Inst_depth   (post-fix exit 0, 1.050s)
      m4fix-inst-chains        exit 1 Inst_depth   (post-fix exit 0, 0.051s)
      m4fix-inst-small-reach   exit 1 Inst_depth   (post-fix exit 0, 0.016s)
      m4fix-inst-branching     exit 1 Inst_depth   (post-fix exit 0, 20.5s)
M2  memo key = the key HEAD only, not the full key term
      m4fix-inst-memo-key      exit 1 type mismatch (post-fix (succ zero))
      m4fix-inst-twoclass      exit 1 type mismatch (post-fix true)
      m4fix-inst-small-reach   exit 1 type mismatch (post-fix true)
M3  Inst_depth payload back to `ity`
      D7b FAIL: "instance resolution for (w _ : (Cls Key)) -> (Cls Key)"
M4  read_prelude_src and run_with_prelude back to the round-2 shape
      all 8 PASS-D-PRELUDE-CHANNEL probes deviate: exit 2 crash dumps,
      exit 124 on the FIFO, exit 0 fail-open on the missing path
M5  require_main gated on `exec`
      check --require-main <mainless>  exit 0   (gate needs nonzero)
M6  Source.message Unreadable text mutated, run at euid 501
      R2-F2c FAIL and the prelude gate's unreadable probes FAIL, so the
      root guard did not weaken unprivileged coverage
```

`m4fix-inst-memo-key` passes under M1, which is what a soundness pin is
for: removing the memo does not make the answer wrong, only slow.  The
sources were restored from the snapshot and rebuilt before the final
battery;  all eight md5s match.

### Answer equivalence

Ten repo fixtures and examples (`m4d-classes`, `m4fix-inst-binders`,
`m4fix-auto-index`, `m4fix-ann-ctor`, `m4a-vec`, `m4b-deceq-runs`,
`m4c-frozen`, `x2-prelude-run`, `examples/guard-classes`,
`examples/church`), BOTH verbs, against a round-2 reference tree built
from the git INDEX (`/Users/oobi/Documents/tot-fix3/tot-r2/`, no git
mutation, `git show :path`): stdout, stderr and exit code byte-identical
on all 20 runs.  `EQUIV-DIFFS=0`.

### Result

`dunecho build`: 0 errors, 0 warnings.
`zsh dev/gates.sh`: GATE-EXIT=0, **264 PASS / 0 FAIL**, up from 257.

Decomposition: 82 `test/main.exe` (+1: `D7b`) + 100 `test/surface.exe`
(unchanged) + 82 `dev/gates.sh` markers (+6:
`PASS-M4FIX-INST-TWOCLASS`, `PASS-M4FIX-INST-SPEC16`,
`PASS-M4FIX-INST-CHAINS`, `PASS-M4FIX-INST-SMALL-REACH`,
`PASS-M4FIX-INST-MEMO-KEY`, `PASS-D-PRELUDE-CHANNEL`).

Battery wall time about 34s (33.8s and 36.6s on two runs), measured against 19.2s for the round-2
reference tree running its own gates.  Essentially all of the increase
is `PASS-M4FIX-INST-BRANCHING`'s depth-20 fixture (20.5s), which now
resolves instead of being rejected in 11ms.  That is the price of the
flipped oracle and it is visible on purpose.

Ill-typed nest26 (`m4fix-nest26-ill.tot`, `check`, best of three):
**0.015 s**, exit 1, unchanged from round 2.  `m4fix-nest26.tot` 0.017s,
`m4fix-nest30-nomotive.tot` 0.017s, `m4fix-inst-binders.tot` 0.016s: the
round-1 and round-2 fixes all still hold.

Files touched: 17.  Eleven edited (`lib/check.ml`,
`surface/bootstrap.ml`, `surface/run.ml`, `bin/tot.ml`, `test/main.ml`,
`test/surface.ml`, `dev/gates.sh`, `SPEC.md`, `README.md`,
`dev/M4-FIXES-PLAN.md`, `dev/M4-FIXES-LOG.md`), one new module
(`surface/source.ml`) and five new fixtures under `test/fixtures/`.  No
existing test, gate or fixture was weakened or deleted;  the only
oracle changes are the two this round authorised.  No git mutation was
run.

### Residuals

- The branching-telescope TERM SIZE limit described above (2^n emitted
  nodes at nesting n).  Recorded in SPEC.md section 6 in place of the
  retired `(class, key)` memo debt;  term sharing is the M5 fix.
- The cache exe-identity memo's HIT condition (ctxcat 6), accepted with
  its argument in the gate comment and SPEC.md.
- `--require-main` under a fail-open exit mapping (opus R4, round 2),
  unchanged.
- `test/surface.ml`'s own `run_gate` still guards on `Sys.file_exists`
  alone.  It is the TEST harness's gate driver, not the shipped CLI,
  and it is only ever pointed at repo fixtures, so the driver contract
  does not apply to it.  Unchanged from round 2.

## Fix round 4 (2026-09-02): ctxcat r4 ids 0-5 plus opus R4-1..R4-5

Scope: the round-3 surfaces the round-4 reviews re-opened.  Inputs:
`tot-m4-review-r4-survivors.json` (six ctxcat survivors) and
`tot-m4-opus-r4-report.md` (five findings, all repro-executed, plus a
table of six surfaces that HELD).  Adjudications and the decided fixes
are in `dev/M4-FIXES-PLAN.md` under "# Round 4".

Baseline before any edit, re-run and green: `dunecho build` 0 errors, 0
warnings;  `zsh dev/gates.sh` GATE-EXIT=0;  264 PASS / 0 FAIL / 0 SKIP
(82 `test/main.exe` + 100 `test/surface.exe` + 82 gate markers).

Two soundness-adjacent holes closed, one in the kernel and one on the
prelude path.  No kernel rule is relaxed;  the kernel change is a
NARROWING (an error class that used to be forgiven no longer is), and
the prelude change removes a fail-open and a cache-poisoning window by
construction.

### Verdicts

| id | finding | verdict | fixed |
| --- | --- | --- | --- |
| ctxcat 3 | an axiom laundered to runtime through a zero-constructor family | CONFIRMED (executed) | yes |
| opus R4-2 | the prelude is read TWICE on a cold run; fail-open plus cache poisoning | CONFIRMED (executed) | yes |
| opus R4-1 | the branching gate's 60 s budget is not a margin, and it gates six later markers | CONFIRMED (executed) | yes, authorised re-scope |
| opus R4-3 | the flat 10000 fuel floor rejects wide queries at leaf 1668 | CONFIRMED (bisected) | yes, one residual recorded |
| opus R4-5 | the `Inst_depth` message is proportional to the query | CONFIRMED (31,748 bytes) | yes |
| opus R4-4 | SPEC.md and README.md overstate the `/dev/stdin` rejection | CONFIRMED (executed) | yes, docs only |
| ctxcat 0 | the `m_idx` binder-order comments contradict | REFUTED as a contradiction, CONFIRMED as an ambiguity | yes, comments plus two new pins |
| ctxcat 4 | a whole-type-annotated ctor is rejected by the raw result-head check | REFUTED on behaviour (executed) | no code change, regression pin added |
| ctxcat 1 | `with_scratch_dir` leaks its scratch directory | CONFIRMED | yes |
| ctxcat 5 | the patched-literal probe escapes the gate's cache sandbox | CONFIRMED | yes |
| ctxcat 2 | TOCTOU in temp-name-to-dir | CONFIRMED, accepted | no, log-only |

### ctxcat 3 (medium, the headline) the axiom launder

Reproduced first, on the staged round-3 binary:

```
axiom ff : Empty
def boom : Nat := match ff with end          ->  exit 0, "def boom : Nat"
eval boom                                    ->  <erased>
eval (add boom (succ zero))                  ->  ((add <erased>) (succ zero))
```

So an erasure marker reaches a `Many`-quantity `Nat` computation.  The
route is the `Zero` fallback in `match_scrut`: inference at the ambient
mode failed with `Axiom_runtime_use`, the fallback re-inferred at
`Zero`, `zero_eliminable` accepted `Empty` (`Global.Complete []`), the
match shipped with `scrut_q = Zero`, and `Erase` maps a zero-branch
`Zero` match to `Eterm.EErased`.

Change (`lib/error.ml`, `lib/check.ml`).  `Error.is_erased_use` is a new
exhaustive predicate over `Error.t`, and `match_scrut`'s fallback is
guarded on it.  Mode reaches `infer` through exactly two rules and they
raise two different errors: `Var` raises `Erased_use`, which is the
class the fallback exists for, and `Global` raises
`Axiom_runtime_use`, which is the rule being overridden.  Every ambient
error other than `Erased_use` now propagates unchanged.  The predicate
is an exhaustive match rather than a `tag` string comparison, so adding
an `Error.t` constructor is a compile error here and the soundness
condition never depends on a display string.

After the change, the same file reports
`axiom ff used at runtime: axioms are usable only at quantity 0` at
exit 1.

Scope, stated because it would otherwise be overclaimed: this restores
the ambient mode's own verdict, it does not make an inconsistent axiom
set consistent.  `exfalso` takes its `Empty` at quantity 0, so
`def boom6 : Nat := exfalso Nat ff` checks and evaluates to `<erased>`
before AND after this round.  That is the sanctioned quantity-0 route
and `--no-axioms` is what switches it off.

Regressions checked, all green: the prelude itself (`exfalso`,
`subst0`, `J0` are all erased-hypothesis matches on subsingleton
families, so a too-eager narrowing breaks every bootstrap, and the M2
mutant below shows exactly that);  `m4a-box.tot`, `m4a-sx.tot`,
`m4a-ese-neg.tot` unchanged at `Erased_use`;  and one non-`Erased_use`
ambient error shown to propagate identically pre and post
(`match (zero zero) with ..` gives `not a function type: Nat` on both
binaries).

### opus R4-2 (medium) the prelude read

Round 3 asserted "read exactly ONCE per invocation" in three places
(`bin/tot.ml`, and twice in `surface/bootstrap.ml`) and the claim was
false on every cache MISS.  Reproduced on the staged binary with a
padded 20 MB prelude and an unlink into the window
(`tot-fix4/race-prelude4.sh`, the reporter's script re-pointed): 12 of
12 attempts hit read 2's message shape and exited 0 under
`--serror-exit 0`.

Change (`surface/bootstrap.ml`, `bin/tot.ml`).  `state ()` splits into
`state_of_src src` (elaborates the bytes it is given) and `state ()`
(reads, then calls it).  `cached_state_of_src` uses `state_of_src src`
in BOTH branches: the cache miss and the `TOT_CACHE_VERIFY=1`
recompute.  The key and the elaborated content are now the same bytes,
so the poisoning window closes BY CONSTRUCTION rather than by being
made small, and no second `read_prelude_src` sits on the driver's path
to fail inside the `--serror-exit` mapping.

Re-run of the same repro on the fixed binary: `READ2-FAILED = 0`,
`read1-failed = 1` at the correct driver contract (exit 1, outside the
mapping), 11 clean.

All three doc claims were re-read and each is now true;  each also
says, at its own site, that it was false under round 3, so the next
reader does not have to re-derive it.

### opus R4-1 (medium-high operationally) the branching gate

Authorised oracle re-scope.  `m4fix-inst-branching.tot` drops from
nesting 20 to 16 and keeps its 60 s budget.  The regression boundary
the file pins is nesting 4 to 6, so 16 over-pins it by an order of
magnitude, and the emitted dictionary (a binary tree of 2^n nodes that
the mandatory candidate re-check walks as a tree) shrinks 16x.
Measured after the change, three consecutive runs at load average 8.1:
0.97 s, 0.97 s, 0.97 s, against 20.5 s idle and 58 to 90 s under load
before.  60 s is now about 62x headroom instead of 2.9x.  The depth-20
measurement is kept in the fixture header on purpose: it is the M5
hash-consing motivation, since a `Term.t` with sharing makes the
re-check linear in the DAG.

The leg also MOVED, from ahead of six later markers to the end of the
M4-fixes block, so a future flake there cannot blank
`PASS-M4FIX-INST-MEMO-KEY` (the memo's own soundness pin) or
`PASS-D-PRELUDE-CHANNEL`.

(Round 5, opus R5-4: that last sentence was only HALF true when it was
written.  The move went from six lost markers to four, and
`PASS-D-PRELUDE-CHANNEL`, the marker it names, was one of the four
still downstream.  Round 5 made the sentence true rather than editing
it: the branching leg is now the LAST leg in `dev/gates.sh`, so no
marker at all sits behind it.  See "## Fix round 5".)

### opus R4-3 (low-medium) the fuel width dimension

`inst_fuel` now takes the max of the round-3 depth formula (unchanged,
so no deep shape loses fuel) and `8 * term_size expected_t`, where
`term_size` is a new node count next to `term_depth`.  A width-L query
gets at least 8L;  on the generated shape `term_size` is about 4L, so
the L = 2500 gate gets about 32L of fuel against a 6L charge.

Residual, recorded not fixed.  CORRECTED in round 5 (opus R5-3): the
sentence that stood here named a mechanism that cannot occur.  It said
a def-shared query whose VALUE unfolds wide is still bounded by the
10000 floor "because `Term.Global` counts 1".  It is not.  `term_size`
is taken on `Eval.quote globals ctx.size expected_v`, the quote of the
ALREADY EVALUATED expected value, so a reducible def is unfolded by
`Eval.eval` before it can be quoted and no `Term.Global` for it
survives into `expected_t`;  an opaque def stays a `VNeutral`, `key_of`
returns `None`, and the query fails earlier with `Inst_unresolved`
instead.  Both halves executed (`defshare-d15.tot` exit 0
"eval : Nat";  `opaque-test.tot` exit 1 "no instance found for
(WC opaqueTy)").

The REAL residual is the opposite and worse: there is no rejection at
all, only unbounded wall clock.  `let` and `def` sharing build a
doubling type in about 40 source bytes per level, fuel never fires
(because `term_size` of the fully quoted value is correctly huge, so
`inst_fuel` is oversized), and the cost sits in computing that quote
and in re-quoting the key before every memo lookup, neither of which a
memo HIT charges for.  Measured: depth 15 / 1447 bytes / 3.5s, depth 16
/ 971 bytes / 7.7s, depth 17 / 1010 bytes / 24.6s, depth 18 / 1049
bytes / 41.4s, all at exit 0.  A sub-2 KB file therefore buys
attacker-tunable exponential CPU with no cutoff.  That is the carried
CHECK-BUDGET debt, not a fuel debt, and it is the same sharing
blindness the branching fixture's own header names as the M5
hash-consing motivation.

### opus R4-5 and R4-4 (low) the message cap and the doc corrections

`Inst_depth`'s payload is elided past a 400-character prefix
(`Check.goal_print_cap`, `Check.elide`).  The prefix carries the
query's head, so every assertion that looks for the head still matches,
and D7b (a SHORT goal, named in full) keeps the cap from being
satisfied by dropping the payload.

`SPEC.md`, `README.md` and `surface/source.ml`'s doc comment now say
that a PIPE-backed `/dev/stdin` is rejected while a regular-file-backed
redirection is accepted.  Executed both ways in both trees.  The code
is right;  only the prose was wrong.

### ctxcat 0 (medium) the motive binder order

Determined by construction rather than by re-reading the comments: a
family with TWO indices, since one index is symmetric under any
reordering.  `data Tw : Nat -> Bool -> Type 0` with
`match t as x in Tw i c return (TwP i c)` elaborates, and the swapped
reading fails with "type mismatch: expected Bool, found Nat".  From the
kernel side, test A13 builds the motive directly, checks it, and quotes
it back: with `m_idx = ["i"; "c"]` the body `Var 1` has type `Bool`
(the SECOND index) and the round-tripped term prints `in A13Tw i c`.

NO module had the direction backwards.  The three comments were reading
"index" in two senses, one as a position in `m_idx` and one as a de
Bruijn index.  The single convention is now stated once on
`Term.motive` (list order is DECLARATION order, outermost first;  inside
`m_body` de Bruijn 0 is `m_self`, de Bruijn 1 is the LAST element of
`m_idx`, de Bruijn m is its FIRST) and `lib/pp.ml` and `lib/eval.ml`
cite it and name the axis they mean.

### ctxcat 4 (low) the whole-type-annotated ctor

Refuted on behaviour.  `strip_pis` calls `strip_ann` at every level
including the first (round 1, ctxcat id 8), so all three spellings
already checked on the round-3 binary.  The `Type 1` variant the
finding names does fail, but with "type mismatch: expected Type 1,
found Type 0", a correct verdict about the annotation and not a
`Bad_ctor`.  No code change;  what was missing was the regression pin,
which is now `m4fix-ann-whole.tot` plus its negative.

### New tests and gates

Kernel (`test/main.ml`), 2 new cases:

- `A13`: the motive's two index binders keep declaration order.  Checks
  a two-index family, asserts the result type is the SECOND index,
  asserts the printed and the quote-round-tripped motive both read
  `in A13Tw i c`.
- `D7c`: `Inst_depth`'s message is bounded whatever the query's size.
  Deep goal, assertion on the LENGTH against
  `goal_print_cap` plus the fixed prefix, plus the elision marker.

Gates (`dev/gates.sh`), 8 new markers:

- `PASS-M4FIX-AXIOM-EMPTY` (negative), `PASS-M4FIX-ABSURD` (positive,
  three subsingleton shapes), `PASS-M4FIX-SCRUT-NOTFUN` (the
  non-`Erased_use` control).
- `PASS-M4FIX-ANN-WHOLE` and `PASS-M4FIX-ANN-WHOLE-NEG`.
- `PASS-M4FIX-MOTIVE-ORDER` (positive and negative in ONE marker, so
  neither half can pass alone).
- `PASS-M4FIX-INST-WIDE` (L = 2500, charge 14994).
- `PASS-D-PRELUDE-ONEREAD`: two deterministic structural facts (no
  `state ()` call site in `surface/bootstrap.ml`, `state_of_src src`
  applied in three places) plus the channel contract for a missing
  prelude.  The race itself is not a battery-shaped oracle, so it lives
  in this log and in `tot-fix4/race-prelude4.sh`, and the gate pins the
  invariants that make the race impossible.

Fixtures, 8 new: `m4fix-axiom-empty.tot`, `m4fix-absurd.tot`,
`m4fix-scrut-notfun.tot`, `m4fix-ann-whole.tot`,
`m4fix-ann-whole-neg.tot`, `m4fix-motive-order.tot`,
`m4fix-motive-order-neg.tot`, `m4fix-inst-wide.tot`.  The last is 224
KB and GENERATED;  `dev/gen-wide-instance.py` is committed with it and
reproduces the committed bytes exactly (verified: identical md5).

### Non-vacuity

Every new gate and case was run against a MUTATED build and observed to
fail, then the file was restored from a byte copy and the restore
verified by md5.  Two first-pass mutations were rejected as invalid
proofs and replaced: one broke the build (so its leg ran against a
stale binary) and one reversed only a display-name list and was
behaviourally a no-op.

| gate or case | mutation | observed |
| --- | --- | --- |
| `PASS-M4FIX-AXIOM-EMPTY` | fallback guard forced off | FAIL, `boom` checks at exit 0 |
| `PASS-M4FIX-ABSURD` | fallback removed entirely | FAIL, and the PRELUDE stops bootstrapping ("prelude: 60:1: erased variable e used at runtime") |
| `PASS-M4FIX-SCRUT-NOTFUN` | `Not_a_function` message altered | FAIL |
| `PASS-M4FIX-ANN-WHOLE` | `strip_pis` stops stripping `Ann` | FAIL, `Bad_ctor` on `wmk` |
| `PASS-M4FIX-ANN-WHOLE-NEG` | result-head check short-circuited true | FAIL, `ZBad` accepted at exit 0 |
| `PASS-M4FIX-MOTIVE-ORDER` | elaborator scope pushed UNreversed | FAIL, positive rejected AND negative accepted |
| `PASS-M4FIX-INST-WIDE` | width term zeroed out of `inst_fuel` | FAIL, `Inst_depth` |
| `PASS-D-PRELUDE-ONEREAD` | miss branch back to `state ()` | FAIL, calls 1 (want 0), srcs 2 (want 3) |
| kernel `D7c` | `elide` removed | FAIL, 2851 bytes against a 445 budget |
| kernel `A13` | index env unreversed in the result type | FAIL, result type `Nat` instead of `Bool` |

### Final state

```
dunecho build     ->  OK build: 0 errors, 0 warnings
zsh dev/gates.sh  ->  GATE-EXIT=0   (run TWICE, identical marker sets)
run 1: PASS = 274   FAIL = 0   SKIP = 0
run 2: PASS = 274   FAIL = 0   SKIP = 0
274 = 84 test/main.exe + 100 test/surface.exe + 90 gate markers
```

Against the 264 baseline: plus 2 kernel cases and plus 8 gate markers,
minus nothing.  No marker changed name and no oracle was weakened
except the two this round authorises (the branching fixture depth, with
its comment, and the two `/dev/stdin` doc sentences).

Answer equivalence against the STAGED tree (materialised from the git
index into a scratch copy and built separately;  no git mutation): 10
pre-existing fixtures x `check` and `run`, 20 comparisons, 0 diffs.
`m4fix-inst-branching.tot` is excluded because this round changes it on
purpose.

Files touched: 25.  Sixteen edited (`lib/check.ml`, `lib/error.ml`,
`lib/eval.ml`, `lib/pp.ml`, `lib/term.ml`, `surface/bootstrap.ml`,
`surface/source.ml`, `bin/tot.ml`, `test/main.ml`, `test/surface.ml`,
`dev/gates.sh`, `SPEC.md`, `README.md`,
`test/fixtures/m4fix-inst-branching.tot`, `dev/M4-FIXES-PLAN.md`,
`dev/M4-FIXES-LOG.md`), one new dev generator
(`dev/gen-wide-instance.py`) and eight new fixtures.  No git mutation
was run.

### Residuals

- Fuel is sized from the query TERM, so a def-shared query whose VALUE
  unfolds wide is still bounded by the 10000 floor (opus R4-3, above).
  M5, with hash consing.
- The branching-telescope TERM SIZE limit, unchanged from round 3 and
  still recorded in SPEC.md section 6;  the depth-20 measurement now
  lives in the fixture header as its motivation.
- `PASS-D-PRELUDE-ONEREAD`'s discriminating half is STRUCTURAL, not
  behavioural.  The behavioural repro needs a 20 MB prelude and a
  background unlink, which is not a battery-shaped oracle;  it is
  recorded here with its before and after numbers instead.
- ctxcat 2's TOCTOU between `Filename.temp_file` and `Sys.mkdir`,
  accepted: single-process harness, and a collision is a loud test
  error either way.
- `--require-main` under a fail-open exit mapping, unchanged from round
  2.
- `test/surface.ml`'s own `run_gate` still guards on `Sys.file_exists`
  alone, unchanged from round 2 and round 3.

## Fix round 5 (2026-09-02): opus R5-1..R5-7 plus ctxcat r5 ids 1, 6, 9, 14, 15, 16, 17

Scope: the surfaces the round-5 reviews re-opened.  Inputs:
`tot-m4-review-r5-survivors.json` (16 ctxcat survivors) and
`tot-m4-opus-r5-report.md` (seven findings, every one repro-executed).
Adjudications and the decided fixes are in `dev/M4-FIXES-PLAN.md` under
"# Round 5".

Baseline before any edit, re-run and green: `dunecho build` 0 errors, 0
warnings;  `zsh dev/gates.sh` GATE-EXIT=0;  274 PASS / 0 FAIL / 0 SKIP
(84 `test/main.exe` + 100 `test/surface.exe` + 90 gate markers).

Both round-4 soundness fixes HELD under every attack executed against
them, so this is a polish round.  No kernel rule moves, no error is
newly forgiven, and the one number that changed in the kernel
(`inst_fuel`) only ever grows, which cannot turn an accepted program
into a rejected one.

### Verdicts

| id | finding | verdict | fixed |
| --- | --- | --- | --- |
| opus R5-1 | the binder-order pins pin neither mechanism the doc names | CONFIRMED (two mutations, both green on round 4) | yes |
| opus R5-2 | `Inst_depth` rejects a resolvable query on the class-count dimension | CONFIRMED (bisected, K = 56 to 57) | yes |
| ctxcat 16 | `inst_fuel` takes a MAX where the walk charges a PRODUCT | CONFIRMED (same defect, other dimension) | yes |
| opus R5-3 | the recorded fuel residual names a mechanism that cannot occur | CONFIRMED (refuted structurally and by execution) | yes, text |
| opus R5-4 | the gate re-scope names a marker it did not protect | CONFIRMED (read plus simulation) | yes, leg moved |
| opus R5-5 | the cap covers one constructor out of a family | CONFIRMED (800,162-byte line) | yes |
| ctxcat 15 | `Inst_unresolved` renders the whole query unelided | CONFIRMED (32,122-byte line) | yes |
| opus R5-6a | the cut counts BYTES, so a character can straddle it | CONFIRMED (lone 0xC3 on stderr) | yes |
| opus R5-6b | D7c does not pin the constant | CONFIRMED (100000 fails, 2000 green) | yes, cap 2000 |
| opus R5-7 | `Term.motive`'s level formula is backwards | CONFIRMED (by substitution) | yes |
| ctxcat 17 | SPEC section 6 documents the REVERSED cache identity as shipped | CONFIRMED | yes |
| ctxcat 9 | the `%.6f` stat signature can collide | SPLIT: rendering CONFIRMED, granularity REFUTED as new | yes, `%.17g` |
| ctxcat 6 | `fold_items`'s hardcoded policy is inheritable by accident | CONFIRMED as naming, refuted as behaviour | yes, renamed |
| ctxcat 1 | `index expression(s)` | CONFIRMED | yes |
| ctxcat 14 | trivial `Result.fold` passthrough wrappers | CONFIRMED | yes |
| ctxcat 7 | anonymous arrow-sugar data index coerced to quantity 0 | REFUTED BY DESIGN, third round running | no, verbatim known debt |
| ctxcat 2, 4, 5, 8, 10, 11, 12, 13 | style, informational and accepted-residual notes | log only | no |

### opus R5-1 the binder-order pins, made real

`Term.motive` states the convention once and cites two mechanisms.
Neither was pinned.  Both mutations were built in a scratch COPY and
the whole battery run against each, on the ROUND-4 tree:

```
lib/pp.ml    List.rev dropped from the motive names extension
             ->  GATE-EXIT=0   274 PASS   0 FAIL
lib/eval.ml  idx_env (size + m - 1 - i)  ->  (size + i)
             ->  GATE-EXIT=0   274 PASS   0 FAIL
```

A13 now uses an asymmetric two-index family whose motive body names
both binders in order, `a13snd i c` with `a13snd` a reducible selector
returning its second argument, so the family's two indices are `Nat`
and `Bool` at this scrutinee and the printed body carries the ORDER
rather than one name.  Three independent assertions, one per mechanism:
the printed checked term must read `return ((a13snd i) c)` and must not
contain `((a13snd c) i)`;  the round-tripped motive body must be
`Term.Var 1` read STRUCTURALLY off the quoted term, which is
printer-independent;  and the inferred type must quote to exactly
`Bool`.

Re-executed against the ROUND-5 tree, both mutations now FAIL, and the
source file md5 was verified identical before and after each run:

```
lib/pp.ml    List.rev dropped
             ->  GATE-EXIT=1   183 PASS
                 FAIL A13: the motive's two index binders keep declaration order
                 SRC-INTACT md5=e4db235f2fba0d42330723756e9e8421
lib/eval.ml  idx_env (size + m - 1 - i)  ->  (size + i)
             ->  GATE-EXIT=1   183 PASS
                 FAIL A13: the motive's two index binders keep declaration order
                 SRC-INTACT md5=d12d0d31544081d039393fcd62d1b382
```

`lib/term.ml`'s own formula is corrected in the same place (opus R5-7):
`size + j`, not `size + m - 1 - j`, with the substitution
`j = m - 1 - i` recorded beside it.

### opus R5-2 and ctxcat 16 the fuel bound becomes a product

`inst_fuel`'s width term is now
`8 * term_size expected_t * ((2 * max_binders) + 2)`.  The depth term is
untouched, and the new width term is at least twice the old one for
every instance table, so no shape that resolved before can stop
resolving.

Measured on the two dimensions, round-4 binary against round-5 binary,
same file:

```
K = 57 classes, four-leaf query (test/fixtures/m4fix-inst-classes.tot)
  round 4  ->  exit 1, "instance resolution for (C0 ((WPair ((WPair
               Waaaa) Wbbbb)) ((WPair Wcccc) Wdddd))) exceeded its fuel"
  round 5  ->  exit 0, "zero", 5s

8-binder instance, 3 classes, balanced 256-leaf query
  round 4  ->  exit 1, Inst_depth (1s to reject, surface form)
  round 5  ->  exit 0 (kernel D9f;  fuel 147312 against a charge of
               about 10710, term_size 1023)
```

Gates added: `PASS-M4FIX-INST-CLASSES` (surface, the K = 57 leaf,
regenerated by `python3 dev/gen-inst-fuel.py classes 57`) and
test/main.ml's D9f.  D9f is kernel-level deliberately: as a surface
fixture the same shape also pays the mandatory candidate re-check,
which walks the resolved dictionary as a TREE, measured at 15 to 20s
for L = 256 and 47s for L = 320.  That is the M5 hash-consing debt, not
the bound under test.  Sizing is forced from both sides and recorded at
the case: the charge must clear the 10000 floor, which puts L at 240 or
more, and `Eval.eval` re-walks each resolved dictionary once per
occurrence (six per level), so the cost is 6^depth and L must stay at
256 or below to keep the depth at 8.  The margin over the round-4 bound
is therefore 7 percent, which is a hard boolean against a fixed formula
but a number to re-measure if `build_instance`'s charge accounting ever
changes.

The kernel suite's watchdog in `dev/gates.sh` moves 120 -> 300 for the
same reason: D9f takes the suite from about 1s to 15 to 25s, and 300
keeps that a HANG detector at about 12x the observed runtime instead of
a performance gate that flakes on ambient load.

Non-vacuity, executed, with the source md5 verified intact:

```
inst_fuel width term reverted to the round-4 8 * term_size
  ->  GATE-EXIT=1   185 PASS
      FAIL D9f: a wide query against an 8-binder instance resolves
      SRC-INTACT md5=559b24ce7707379b402f8029bf22a480
```

`PASS-M4FIX-INST-CLASSES`'s own non-vacuity is the differential above
(the round-4 binary reports `Inst_depth` on the committed fixture at
exit 1), which is stronger than a mutation, since the mutated kernel
suite fails before the gate leg is reached.

The "a genuinely unbounded shape still errors" half of the gate set is
a REGISTRATION argument, not a fixture, and it is recorded here because
no such fixture is constructible: `validate_instance_shape` requires
every dictionary domain to be a single-parameter class applied to an
earlier type BINDER, and the codomain to be that class at an applied
key, so every dictionary sub-resolution descends into a strict subvalue
of the key.  There is no registrable instance whose walk does not
terminate, which is exactly why fuel is documented as a backstop over
the structural argument rather than as a decision procedure.

### opus R5-3 the fuel residual, corrected

The round-4 residual sentence in this file and in
`dev/M4-FIXES-PLAN.md` named a mechanism that cannot occur.  Both are
rewritten in place, above and in the plan, and `SPEC.md`'s own
resolution paragraph now carries the corrected version.  Executed
refutation: `term_size` is taken on
`Eval.quote globals ctx.size expected_v`, so a reducible def is
unfolded before it can be quoted (`defshare-d15.tot`, exit 0,
"eval : Nat") and an opaque def fails earlier with `Inst_unresolved`
(`opaque-test.tot`, exit 1, "no instance found for (WC opaqueTy)").
The real residual, recorded, is that a legitimately huge resolution has
no TIME cutoff: 3.5s at depth 15, 7.7s at 16, 24.6s at 17, 41.4s at 18,
all at exit 0, from files of about 1 KB.  It points at the carried
check-budget debt and at M5 hash consing.

### opus R5-4 the branching leg runs last

`dev/gates.sh`'s marker order after the move, read back:

```
1152  PASS-M4FIX-INST-MEMO-KEY
1403  PASS-D-PRELUDE-ONEREAD
1440  PASS-D-MISSING-FILE-CHANNEL
1509  PASS-D-UNUSABLE-FILE-CHANNEL
1572  PASS-D-PRELUDE-CHANNEL
1587  PASS-D-USAGE-CHANNEL
1630  PASS-M4FIX-INST-BRANCHING     <- last leg in the file
```

Nothing is downstream of the branching leg now, so the round-4
sentence is true as written for every marker rather than for four out
of eight.  The leg is the most expensive and the most timing-sensitive
in the file, which is exactly why nothing cheap may depend on it.

### opus R5-5, ctxcat 15 and opus R5-6 the whole error family is bounded

`Check.pp_goal` is `elide (pp_value ..)`, and it is now the ONLY way an
`Error.t` payload in `lib/check.ml` is built from a printed value.  An
`rg` audit of `pp_value` and `Pp.term` in error construction found nine
sites in `lib/check.ml` (`Inst_unresolved`, `Inst_depth`,
`Not_a_function`, `Not_a_universe`, the two `Mismatch` payloads plus
the "a function" one, and three `Not_inductive`) and exactly one
outside it, `Serror.Main_bad_type` in `surface/run.ml`, which lands on
the same one-line stderr channel and takes the same clamp.  Every other
constructor's payload is a name or a fixed string.  `pp_value` itself
stays unclamped for the driver's display lines ("def .. : .." and
"eval : .."), which are output, not diagnostics.  The clamp is NOT in
`Error.to_string`: the suites pin exact short messages, and a central
clamp would make that pin a property of the formatter.

`goal_print_cap` is 2000, the opus-corrected value, and the cut backs
up to a UTF-8 character boundary (`Check.char_boundary`, one left fold,
no indexing).

Longest single stderr line, round-4 binary against round-5 binary, on
opus's own repro files:

```
                       round 4      round 5
mismatch-huge.tot      800,162  ->    4,102
unres-huge.tot          32,122  ->    2,087
bhuge.tot                  503  ->    2,103   (the cap moved 400 -> 2000)
```

Input independence, the property the cap exists to deliver, on the same
shape generated at two sizes:

```
                       round 4      round 5
Wrap nest depth 300      5,531  ->    4,084
Wrap nest depth 900     16,331  ->    4,084
short (depth 1)            147  ->      147   (printed in full, no marker)
```

UTF-8, on opus's `u383.tot`:

```
round 4  ->  'utf-8' codec can't decode byte 0xc3 in position 480
round 5  ->  stderr decodes as UTF-8: OK
```

New pins: D7d (kernel) asserts that the `Mismatch` message length is
IDENTICAL at nest depth 300 and 900, that the `Inst_unresolved` message
length is identical at the same two depths, that both carry the elision
marker, that a short `Mismatch` prints both types in full and matches
its exact text, that a string exactly at the cap keeps every byte, and
that a two-byte U+00E9 straddling the cap loses the whole character
rather than half of it.  `PASS-M4FIX-ERROR-LINE-BOUNDED` (surface)
asserts the same independence property on the DRIVER's stderr, on a
source the gate generates itself at two depths.  Independence is used
as the oracle instead of a constant precisely because a constant can be
satisfied by moving `goal_print_cap`, which is the weakness R5-6b
found in D7c.

Non-vacuity, executed, source md5 verified intact each time:

```
goal_print_cap 2000 -> 100000000 (elide becomes a no-op)
  ->  GATE-EXIT=1  184 PASS
      FAIL D7c: Inst_depth's message is bounded, whatever the query's size
      FAIL D7d: every printed-type error payload is bounded, not just Inst_depth
the cut ignores UTF-8 boundaries (char_boundary dropped)
  ->  GATE-EXIT=1  185 PASS
      FAIL D7d: every printed-type error payload is bounded, not just Inst_depth
```

`PASS-M4FIX-ERROR-LINE-BOUNDED`'s own non-vacuity is again the
differential rather than a mutation: on the round-4 binary the two
generated depths produce 5,531 and 16,331 bytes, so the leg's
`[ "$mm_len1" = "$mm_len2" ]` assertion fails.

### ctxcat 17 and ctxcat 9 the cache identity entry, corrected

SPEC section 6's cache-identity debt entry described D5.3's
`device:inode:mtime:size` stat identity as current design.  It is not:
audit F1 proved that shape forgeable and reversed it in round 1.  The
entry now records the reversal (identity is `Digest.file`, fail-closed;
`format_version` 9 -> 10 orphaned every stat-identity blob;  the stat
signature survives as a five-field MEMO KEY only, `st_ctime` included
because `utimes` restores mtime but bumps ctime), cross-references
`PASS-CACHE-EXEID-CONTENT` and `PASS-CACHE-EXEID-MEMO`, and states the
residual.

ctxcat 9 splits.  The RENDERING half is real and fixed: `%.6f` is
microsecond resolution, `st_mtime` and `st_ctime` are floats carrying
whatever the filesystem provides, and APFS and ext4 both provide
nanoseconds, so two distinct floats could render to one string.  The
signature now uses `%.17g`, which round-trips a float exactly.  The
CLOCK-GRANULARITY half is refuted as new: on a mount whose observed
ctime does not move on an in-place overwrite the two timestamps are
genuinely equal and no precision can separate them.  That exposure is
already recorded at length in `dev/gates.sh`'s `PASS-CACHE-EXEID-MEMO`
comment (opus round 2 executed the search for an unprivileged
construction and found none: `setattrlist` with `ATTR_CMN_CHGTIME` is
EPERM for a non-root caller, and ctime is not settable by `utimes` or
`utimensat`), and a privileged writer is inside the cache directory's
accepted trust class.  Removing the memo was considered and rejected:
it buys nothing against the granularity exposure that the documented
residual does not already buy, and costs the ~3.3ms re-hash on every
invocation of a language built for per-hook startup.

### The small ones

`Bootstrap.fold_items` is `Bootstrap.fold_prelude_items` (ctxcat 6):
the hardcoded `Run.default_policy` is correct for its one caller and
wrong for any other, so the restriction now travels with the name.
Three comment references updated with it.

`Bad_ctor` pluralises on `n_indices` (ctxcat 1).  Four gate assertions
pinned the old `expression(s)` text and are updated with it, and this
is the ONE intentional answer change in the round.

`test/surface.ml`'s three `run_cli` call sites use `let*` instead of a
spelled-out `Result.fold ~error:(fun e -> Error e)` (ctxcat 14).

Em-dashes removed from `lib/eval.ml`, `SPEC.md` (two) and, beyond the
three the round was opened on, `lib/interp.ml`.  ASCII punctuation
only, no content change.

### Battery

Green twice at the end, both runs from a clean invocation:

```
run 1  ->  GATE-EXIT=0   278 PASS   0 FAIL   0 SKIP
run 2  ->  GATE-EXIT=0   278 PASS   0 FAIL   0 SKIP
           (86 test/main.exe + 100 test/surface.exe + 92 gate markers)
```

274 -> 278 is exactly the four additions: D7d and D9f in the kernel
suite, `PASS-M4FIX-INST-CLASSES` and `PASS-M4FIX-ERROR-LINE-BOUNDED` in
the gate block.  Nothing was removed or weakened.

Answer equivalence against the staged tree's own binary, 10 fixtures x
2 verbs (`check` and `run`), comparing exit code, stdout and stderr
byte for byte:

```
20 runs, 2 diffs
both diffs are m4a-fording, and both are exactly the ctxcat 1
pluralisation: "0 index expression(s)" -> "0 index expressions"
```

### Carried, unchanged

- The check budget is still a fuel counter and not a TIME budget;  a
  sub-2 KB file whose type doubles per level costs 41.4s at depth 18 at
  exit 0.  M5 hash consing.  (Round 6: the doubling type understates the
  reach.  A plain LINEAR chain of about 800 nested boxes, 7.2 KB of the
  `m4fix-inst-chains` shape, exceeds a 60s budget with no verdict at
  all, exit 124.)
- The cache memo's ctime-granularity residual, argued above.
- The anonymous arrow-sugar data index, verbatim `dev/M4-PLAN.md`'s
  known debt, refuted by design for the third round running.
- `--require-main` under a fail-open exit mapping, unchanged from round
  2.
- `test/surface.ml`'s own `run_gate` still guards on `Sys.file_exists`
  alone, unchanged from rounds 2, 3 and 4.

## Round 6 (close-out) (2026-09-02): opus R6-1 and R6-2, TEXT ONLY

Input: `tot-m4-opus-r6-report.md`, the round-6 certification probe of
the round-5 staged tree.  It certified every BEHAVIORAL surface by
execution and blocked convergence on two claim-versus-execution
defects.  This round closes both, and no code semantics move: not one
kernel rule, error, fixture, expectation or gate oracle changes, no
gate is added or removed, and the battery count stays 278.

Certification summary carried from the probe, all executed on the
staged tree: the binder-order pins are non-vacuous (both mutations
re-executed, both FAIL, source md5 identical before and after);  the
elide caps hold at the shipped `goal_print_cap = 2000` over five error
constructors plus a four-parity UTF-8 sweep at the cut;  `Term.motive`'s
level formula is exact by substitution at m = 0, 1 and 2;  the round-5
spec-honesty edits match the code (cache identity, `%.17g` stat
rendering, the corrected fuel residual, zero em-dashes in the M4 text);
and no expected output was weakened anywhere (the one intentional answer
change, the `index expression(s)` pluralisation, TIGHTENED its two
assertions).  Convergence is closed by text, which is what the two
findings asked for.

### opus R6-1 (medium) fuel is a reachable rejection, and three files said it is not

`lib/check.ml`'s contract sentence and `dev/M4-FIXES-PLAN.md`'s round-5
fix paragraph both said "never a reachable rejection".  Re-executed
this round against the staged binary, with files from the repo's own
`dev/gen-inst-fuel.py classes K`:

```
K = 57 (the committed fixture)  ->  exit 0, "zero", 1s
K = 60                          ->  exit 0, "zero", under 1s
K = 61                          ->  exit 1, "instance resolution for
    (C0 ((WPair ((WPair Waaaa) Wbbbb)) ((WPair Wcccc) Wdddd)))
    exceeded its fuel"
```

K = 61 is the committed shape with four more classes.  Every instance
in it passes `validate_instance_shape`, so by the tree's own
registration argument its walk descends into strict subvalues and
terminates;  it is rejected anyway.  The claim is false as written, in
exactly the way opus R5-3 was true of the old fuel residual.

Text fix, no kernel change, four sites:

- `lib/check.ml`, the `inst_fuel` doc comment.  The contract is now what
  the number buys: a BACKSTOP over the structural termination argument,
  covering every SHIPPED gate shape with a recorded margin
  (`PASS-M4FIX-INST-WIDE` at L = 2500, `PASS-M4FIX-INST-CLASSES` at
  K = 57, D9f's charge of about 10710 against a bound of 147312 at
  `term_size` 1023), with a WIDE-CLASS query rejecting beyond a MEASURED
  leaf at K = 60 / K = 61, and the honest close named as the carried
  check-budget and time-cutoff residual.  The leaf moved by under 10
  percent, not by the amount round 5's wording implies: the round-4
  bisection recorded in this tree is K = 56 / K = 57 and the probe's
  round-6 differential, reverting ONLY the width term in a scratch copy,
  measured K = 55 / K = 56.  Both numbers are recorded rather than
  reconciled, because the round-4 figure is a historical measurement on
  a binary this tree no longer builds.  The reason the dimension is
  narrowed and not closed is arithmetic: the class count enters the
  CHARGE through both the (class, key) pair count and the telescope
  length, while every term of the bound stays linear in `per_key`.
- `dev/M4-FIXES-PLAN.md`, the round-5 fix paragraph, with a CORRECTED
  note in the round-5 house style rather than a silent rewrite.
- `dev/gates.sh`, the `PASS-M4FIX-INST-CLASSES` comment: the pin's
  margin, recorded for the first time.  K = 57 sits THREE classes under
  the K = 60 leaf, about 5 percent, thinner than D9f's recorded 7
  percent, plus the recipe for re-measuring the leaf whenever
  `inst_fuel` or `build_instance`'s charge accounting changes.
- `SPEC.md`, section 2's resolution paragraph and ONE new section 6
  entry that carries both halves of the debt (reach and time cutoff),
  since the same walk pays them.  Section 6's round-3 memo entry keeps
  its "must not fire on legitimate input" sentence, now labelled as the
  INTENT it was rather than an achieved property, pointing at the new
  entry.

Not a regression, and nothing that resolved before can stop resolving:
`per_key = 2 * max_binders + 2 >= 2`, so the round-5 bound is pointwise
at least the round-4 one.

### opus R6-2 (low) two load-sensitive legs keep markers downstream: OPS DEBT, both left in place

`dev/gates.sh:164-169` (`PASS-B-DEFERRED`, a 5s wall-clock bound around
a `dune exec`) and `dev/gates.sh:308-311`
(`PASS-C-REGEX-PATHOLOGICAL`, a 5s watchdog that must NOT fire) are
both load-sensitive, both pre-existing, and both have markers
downstream.  Counted on disk by `echo PASS-` lines below each leg: 80
downstream of the deferred leg and 65 downstream of the pathological
check leg.

Decision: LEAVE BOTH IN PLACE and record the exposure here.  Each leg
is variable-self-contained (`t0`, `t1`, `c3`, `elapsed` and `pcode` are
either reassigned before any downstream read or dead after their own
assertion;  `t1` at line 36 is the kernel suite's exit code and is
consumed at line 40, well upstream), so a move is mechanically
possible.  It buys nothing:

- `PASS-B-DIV-MEMO`, `dev/gates.sh:178-185`, carries the IDENTICAL 5s
  wall-clock assertion, sits between the two legs at line 183, and is
  outside this round's scope.  79 markers are downstream of it.  Every
  marker either in-scope leg protects is therefore still exposed to a
  load flake after any move of a strict subset of the three, so the set
  of markers a flake can blank does not change.
- The pathological leg is half of a deliberate differential PAIR on one
  fixture (check must exit 0 fast, run must be killed at exit 124) and
  is summarised by the `PASS-C-REGEX` aggregate marker three lines
  below it.  Moving the check half alone would print the aggregate
  before its component ran.
- The end of the battery is not a neutral place to run a leg.  Gate D
  exports `PATH="$tot_scratch:$PATH"` at line 381 and both `TOT_PRELUDE`
  and `TOT_CACHE_DIR` for the cache block, and the environment at the
  tail of the file is not the one either leg was calibrated in.

Closure condition, recorded as the ops debt: the three wall-clock legs
(`PASS-B-DEFERRED`, `PASS-B-DIV-MEMO`, `PASS-C-REGEX-PATHOLOGICAL`)
move together, or their bounds become watchdog-only assertions with no
elapsed comparison, under an env-neutral tail.  That is an M5 ops
change with its own gate re-run, not a close-out edit;  round 5's own
`PASS-M4FIX-INST-BRANCHING` move is the precedent for doing it
deliberately and alone.  A botched move that blanks 80 markers is worse
than the flake exposure it removes.

### Residual text touch-up

The time-budget residual's recorded example understated its own reach.
One sentence added at both residual sites (`SPEC.md` section 2 and
section 6, plus round 5's carried-residual bullet above): beyond the
doubling type at 41.4s and depth 18, a plain LINEAR chain of about 800
nested boxes (7.2 KB of the `m4fix-inst-chains` shape) exceeds a 60s
budget with NO verdict at all, exit 124.  Re-measured this round on the
staged binary, not carried from the probe.

### Battery

Green twice at the end, both runs from a clean invocation of
`zsh dev/gates.sh` on the edited tree:

```
run 1  ->  GATE-EXIT=0   278 PASS   0 FAIL   0 SKIP
run 2  ->  GATE-EXIT=0   278 PASS   0 FAIL   0 SKIP
           (86 test/main.exe + 100 test/surface.exe + 92 gate markers)
```

Unchanged from round 5, as required: this round edited comments and
prose only, so the count could not move and did not.  `lib/check.ml`'s
edit is inside one doc comment, which dune rebuilds and the compiler
discards.

### Files touched

`lib/check.ml` (doc comment only), `dev/gates.sh` (gate comment only),
`SPEC.md`, `dev/M4-FIXES-PLAN.md`, `dev/M4-FIXES-LOG.md`.  No fixture,
no test, no oracle and no executable line of any file changed.
