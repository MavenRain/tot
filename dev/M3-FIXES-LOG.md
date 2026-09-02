# M3 fixes log

Per-stage record for the M3 fix batch (dev/M3-FIXES-PLAN.md).  Each
stage appends: what changed, files touched, new Error/Serror variants,
test names, gate tails, and every mutation-confirmation transcript.

## Stage A (2026-09-01): check-mode semantics (A1 O1+C14, A2 C17, A3 O5+C18+C15)

### A1 (O1 CRITICAL + C14): check mode never executes user def bodies

`surface/run.ml`'s `IDef` arm now builds the runtime environment ONLY
in run mode: when `exec = false`, `Interp.define` (and the erasure and
type-head evaluation that fed it) is skipped and `st.eglobals` passes
through unchanged.  Kernel elaboration and type checking are
untouched;  the plan's claim that elaboration consults kernel globals
only (never `Interp` values) held against the full suite and gate
battery below, with no downstream consumer missing the entries
(check-mode `eval` items print types only;  `main_epilogue` returns
early on `exec = false`;  bootstrap folds the prelude with
`exec = true`, so the prelude path is unchanged).  Run mode keeps the
M3 Stage B semantics exactly: eager for pure heads, deferred for
Div/IO heads;  a Div value nested under a pure head executing at
definition time in RUN mode is by design.

Mutation confirmation (recorded pre-fix, then re-run post-fix):

    $ timeout 5 dune exec --root ~/Documents/tot bin/tot.exe -- check \
        test/fixtures/x1-nested-div.tot
    PRE-FIX  exit=124   (spin zero executed under check; diverged)
    POST-FIX exit=0     (prints the two def type lines, sub-second)

New fixture `test/fixtures/x1-nested-div.tot` holds exactly the O1
repro (`spin` + `boom : Option (Div Nat)`).  New gate
PASS-CHECK-NESTED-DIV in dev/gates.sh asserts exit 0 under
`timeout 5` and treats 124 as FAIL.  Existing surface tests B5/B6/B7
stay green (verified in the suite run below).

### A2 (C17): memoized deferred forcing

`lib/interp.ml`: `gentry.gval` became a `gbody ref` memo cell.
`force` now writes the computed value back as `GForced` on the first
force of a `GDeferred` body;  later forces return the stored value.
Sound for both deferred kinds: Div is pure modulo divergence, and an
IO-headed body only builds an inert action tree (identical on every
rebuild;  `Effect.run_io` still fires effects once per walk).  Map
copies threaded through `Run.state` share the cell, so one force pays
for every later reference.  `test/main.ml`'s
`case_add_prim_arity0_ioaction` dereferences the cell now (`!`).
`surface/cache.ml` `format_version` bumped 1 -> 2 (the ref is a
Marshal layout change;  the checklist comments in both files updated).

New fixture `test/fixtures/x3-div-chain.tot`: a chain of 8 Div-headed
defs, each body referencing the previous def twice through `bindDiv`,
over a base `regexTest "\\(a+\\)+b"` call on 24 'a's.  Base-cost
calibration on this machine (single eval, run mode, includes ~0.15s
dune-exec overhead): 20 'a's 0.19s;  22 'a's 0.24s;  24 'a's 0.74s;
26 'a's 2.71s.  Unmemoized forcing re-executes the base once per
reference: 2^8 = 256 executions, roughly 150s.

Mutation confirmation (the pre-fix binary IS the memo-less variant
for this run-mode path;  A1 touches check mode only, so the memo is
the single variable here):

    $ timeout 10 dune exec --root ~/Documents/tot test/surface.exe -- \
        gate-run test/fixtures/x3-div-chain.tot
    PRE-FIX  exit=124 under timeout 10  (blew the bound; ~150s course)
    POST-FIX exit=0, elapsed 1s, output ends with the pinned `false`

New gate PASS-B-DIV-MEMO in dev/gates.sh: exit 0, the pinned `false`
line, AND a coarse 5s wall-clock bound, under a 30s watchdog.

### A3 (O5 + C18 + C15): the deferral gates can now fail

dev/gates.sh changes (the watchdog probe moved up, ahead of Gate B
(iii), since Gate B lines use it now):

- PASS-C-REGEX-PATHOLOGICAL no longer accepts exit 124: check mode on
  the pathological fixture must exit 0 FAST under `timeout 5`;  124
  is a FAIL.  Green in the battery below.
- NEW PASS-C-REGEX-PATHOLOGICAL-RUN: the separate run-mode line, where
  the watchdog acceptance is documented, and it is REQUIRED there:
  exit 124 exactly (the pathological regex must actually run and be
  killed).  A quick completion with any verdict is the C18
  silent-swallow regression and FAILS.  Green (124 observed), which
  also proves the fixture is genuinely pathological, so the check
  line's fast exit 0 is meaningful rather than vacuous.
- PASS-CHECK-PRELUDE keeps the bootstrap-only exit code;
  PASS-RUN-PRELUDE now executes a prelude rec applied to data in run
  mode: new fixture `test/fixtures/x2-prelude-run.tot`
  (`eval add (succ (succ zero)) (succ zero)`) through gate-run, exact
  output pinned to the computed readback `(succ (succ (succ zero)))`.
  Discriminator probe (recorded): the same fixture under gate-CHECK
  prints `eval : Nat` (a type, exit 0), which does NOT satisfy the
  pinned line, so the marker can no longer be earned by a check-only
  code path (the exact C15 collapse).

### SPEC.md

- Section 2: dated entry `2026-09-01 (M3 fixes, stage A)` recording
  the A1 decision (check builds no runtime environment for the user
  file;  run-mode deferral unchanged;  nested-Div-under-pure-head at
  run-mode definition time is by design) and the A2 memo (`gbody ref`,
  cache format bump).
- Section 3 (old lines 322-329): the hard-constraint-1 paragraph now
  describes the driver mechanism (no runtime environment in check
  mode) plus memoized run-mode forcing, instead of the falsified
  head-only-deferral claim.
- Section 6 (old lines 472-475): the residual-execution debt is now
  run-mode only, reworded accordingly.

### Files touched

- surface/run.ml (A1: exec-gated `Interp.define`)
- lib/interp.ml (A2: `gval : gbody ref`, memoizing `force`, comments)
- surface/cache.ml (A2: `format_version` 1 -> 2, checklist comment)
- test/main.ml (A2: deref in `case_add_prim_arity0_ioaction`)
- dev/gates.sh (A3 + new gates; watchdog probe moved up)
- SPEC.md (sections 2, 3, 6)
- test/fixtures/x1-nested-div.tot (new)
- test/fixtures/x2-prelude-run.tot (new)
- test/fixtures/x3-div-chain.tot (new)

New Error/Serror variants: none (stage A adds no error channels).
Test names added: gates PASS-CHECK-NESTED-DIV, PASS-B-DIV-MEMO,
PASS-C-REGEX-PATHOLOGICAL-RUN;  reworked PASS-RUN-PRELUDE and
PASS-C-REGEX-PATHOLOGICAL.  No in-process suite cases added (the
plan's stage A tests are gate-level;  B5/B6/B7 re-verified).

Note for C5' (doc truth sweep): test/fixtures/b-deferred-div.tot's
header comment still explains check-mode speed via the Stage B
head-keyed deferral rule;  the claim it pins ("check must never force
this body") stays true, but the cited mechanism is now the stronger
A1 rule.  Left for the sweep since the plan freezes fixture behavior
here.

### Gate tails

    $ dunecho build -- --root ~/Documents/tot
    OK build: 0 errors, 0 warnings

    $ dune exec --root ~/Documents/tot test/main.exe | tail -3
    expected error (Bad_ctor): invalid constructor jarrK: negative or non-uniform occurrence of JsonBadK
    PASS C4: Json-shaped self-recursive ctors pass positivity; List T -> T nesting is Bad_ctor
    M0 kernel: all tests green

    $ dune exec --root ~/Documents/tot test/surface.exe | tail -3
    PASS D4d: an explicit exitWith inside an IO Verdict main short-circuits and wins over ever rendering a verdict
    PASS D4e: main : IO Unit still runs when it does not convert to IO Verdict, and honors exitWith (the ordinary per-item echo is unaffected, unlike the Verdict path)
    M1 surface: all tests green

    $ zsh dev/gates.sh; echo exit=$?
    exit=0
    (markers, in order) BUILD-OK TEST-OK PASS-A-LITERALS
    PASS-CHECK-PRELUDE PASS-RUN-PRELUDE PASS-CHECK-CHURCH
    PASS-RUN-CHURCH PASS-CHECK-NAT PASS-RUN-NAT SCRIPTS-OK
    PASS-B-EXITCODE PASS-B-NOEFFECT PASS-B-DEFERRED PASS-B-DIV-MEMO
    PASS-CHECK-NESTED-DIV PASS-C-JSON PASS-C-POSITIVITY PASS-C-PROC
    PASS-C-REGEX-BENIGN PASS-C-REGEX-PATHOLOGICAL
    PASS-C-REGEX-PATHOLOGICAL-RUN PASS-C-REGEX PASS-C-PARTIAL
    PASS-C-PRIMLINT PASS-D-GUARD-ALLOW PASS-D-GUARD-DENY
    PASS-D-GUARD-OTHER PASS-D-CACHE-HIT PASS-D-CACHE-MISS

## Stage B (2026-09-01): runtime robustness (B1 O2+C3+C19, B2 O3+C6+C7+O7, B3 C8+C16+C9, B4 C10)

### B1 (O2 + C3 + C19): regex group state machine and error channel

`lib/interp.ml`'s `regex_group_count` is now a state machine over an
explicit `group_scan` enum, counting a group exactly when Str's own
parser would: `\(` with the backslash read in the normal state only.
The Str dialect rules it honors: an escaped backslash consumes both
characters (C3's desync);  `[` opens a class;  inside a class a
backslash is an ORDINARY member (Str classes have no escapes);  `]`
closes the class except as its first member (`[]a]`, `[^]a]`, with
`^` right after `[` preserving the first-member position).

State naming deviation from the plan, recorded: the plan sketched
"normal, after-backslash, in-class, in-class-after-backslash";  the
implementation has five states (normal, backslash, class-open,
class-neg, class-body) because the plan's own dialect rules make an
in-class-after-backslash state WRONG (a backslash in a class is an
ordinary member, so `[\]` closes at the `]`;  a state that consumed
the char after an in-class backslash would misparse it), and the
first-member `]` rule needs the `[` vs `[^` split.  The dialect
bullet, not the state sketch, is the binding spec.

New `Error.t` variant `Regex_bad_pattern of string` (pattern plus
Str's reason): `regex_compile` fences `Str.regexp`'s `Failure` and
routes it through the ordinary Result channel, so a malformed
pattern is a runtime error, never the silent no-match `None` (C19's
fail-open).  `str_opt` keeps `Not_found` as the no-match fence and
adds `Invalid_argument` as the O2 backstop.  `regex_test_run` /
`regex_match_run` return `(_, Error.t) result` now;  `fire_prim`'s
two regex arms thread the error.  The wrong comment block (old
lib/interp.ml:409-412 claiming a "documented SPEC debt" that did not
exist, understating a process kill as an imprecise count) is
replaced;  SPEC.md section 2 has the real dialect-caveat entry.

Mutation confirmations (recorded pre-fix, then re-run post-fix):

    $ gate-run test/fixtures/x5-regex-class.tot     # eval regexMatch "[\(]x" "(x"
    PRE-FIX  Fatal error: exception Invalid_argument("Str.matched_group"), exit=2
    POST-FIX (some ((cons "(x") nil)), exit=0   [pinned by PASS-C-REGEX-CLASS]

    $ gate-run test/fixtures/x6-regex-backslashes.tot
    PRE-FIX  Fatal error: exception Invalid_argument("Str.matched_group"), exit=2
    POST-FIX (some ((cons "\\..64 backslashes..\\(") nil)), exit=0
             [pinned exactly by PASS-C-REGEX-BACKSLASHES]
    Honesty note: the pre-fix transcript above was captured with a
    16-escaped-backslash variant of the fixture (a generator escaping
    slip);  the shipped fixture holds the report's full 32 units, the
    identical phantom-group mechanism (any even backslash run before
    `(` overcounted by one), and the opus report executed the 32-unit
    crash against the pre-fix binary independently.

    $ gate-run test/fixtures/x7-regex-badpattern.tot   # eval regexTest "a\(" "aaa"
    PRE-FIX  prints `false`, exit=0  (the C19 silent fail-open)
    POST-FIX x7-regex-badpattern.tot: 7:1: malformed regex pattern: a\( (\( group not closed by \)), exit=1
             [the negative test rejects for the intended reason;
              pinned by PASS-C-REGEX-BADPATTERN]

New kernel case B5 (`case_regex_group_count`) pins seven counter
verdicts: `\(a\)@\(b\)`=2, `[\(]x`=0, `\\(`=0, `\\\(`=1,
`[]a]\(b\)`=1, `[^]a]\(b\)`=1, `[]\(]`=0.  PASS-C-REGEX-BENIGN,
PASS-C-REGEX-PATHOLOGICAL and PASS-C-REGEX-PATHOLOGICAL-RUN all stay
green (the RUN line still exits 124, so the engine still really runs
pathological patterns).

### B2 (O3 + C6 + C7 + O7): cache integrity

`surface/cache.ml`: the on-disk format is now magic `TOTCACHE` (8
bytes) + fixed-width `format_version` (8 ASCII digits) + MD5 hex
digest of the body (32 chars) + body.  `load` verifies magic, version
AND digest before `Marshal.from_string` sees a byte;  any mismatch is
a silent miss.  `decode_body`'s fence widened to
`Failure | Invalid_argument` as a backstop.  `format_version` bumped
2 -> 3.  `save` best-effort unlinks its temp file on a failed rename
(C7).  Module doc rewritten: the never-crash claim now states its
actual mechanism, and the trust class is explicit (the cache dir is
a TRUSTED input, same class as the binary;  the digest defends
against corruption, not an attacker with write access;  SPEC.md
section 6 records the residual).  O7 decision executed: `tot check`
KEEPS writing the prelude cache;  bin/tot.ml's stale "types only"
line 1 reworded to say so.

Mutation confirmations (pre-fix binary, scratch TOT_CACHE_DIR,
warmed by `tot check` on x2-prelude-run.tot):

    six 0xFF bytes written at offset 2000 (mid-body):
    PRE-FIX  exit=139 (SIGSEGV, no output at all)
    POST-FIX silent miss, clean re-elaboration, exit=0
             [PASS-D-CACHE-CORRUPT re-does this with a guaranteed
              od-read xor-1 bit flip at offset 2000 every gate run]

    body truncated to 1000 bytes (8-byte v2 header intact):
    PRE-FIX  Fatal error: exception Invalid_argument("Marshal.from_bytes"), exit=2
    POST-FIX silent miss, exit=0  [PASS-D-CACHE-BODYTRUNC drops the
             last byte, a deterministic digest mismatch]

Gates: PASS-D-CACHE-HIT / PASS-D-CACHE-MISS updated to the new
format and green;  NEW PASS-D-CACHE-BODYTRUNC, PASS-D-CACHE-CORRUPT,
PASS-D-CACHE-MAGIC (first 8 bytes overwritten with XXXXXXXX).  The
in-process D2 case now walks header truncation, body truncation, a
guaranteed one-byte body corruption (total `String.mapi` traversal,
index 60, past the 48-byte header), wrong magic, and a final
re-save/re-hit;  each miss is asserted as a miss, so a wrongly
accepted corrupt blob turns the suite red, which the gate's
exit-0-plus-empty-stdout shape alone could not distinguish from a
hit.

### B3 (C8 + C16 + C9): procRun via temp files

`surface/effect.ml`'s `Proc_run` arm captures via two temp files
(`temp_capture`/`open_write`), never pipes: the child's stdout and
stderr are redirected to them, EVERY parent-held descriptor is
closed immediately after the spawn decision on the success AND
failure paths alike (each acquisition step is individually fenced,
with cleanup threaded through `Result.map_error`), waitpid runs,
both files are read back and unlinked on both paths.  This closes
the C8 descriptor leak and the C16 sequential-drain deadlock in one
move.  C9: `wait_exit_code` splits the arms honestly: WEXITED n is
n;  WSIGNALED maps to 128+signo through a NEW `host_signal_number`
ladder (OCaml's `Unix.WSIGNALED` payload is OCaml's own negative
encoding, so the ladder maps the `Sys.sig*` constants to the host's
(Darwin) numbers and passes already-positive unknown signals
through);  WSTOPPED waits again (unreachable without WUNTRACED,
kept honest);  EINTR retries.  The 128+signo convention is in
SPEC.md section 2.

Plan-detail fill-in, recorded: on this host `Unix.create_process`
reports an exec failure in the PARENT (posix_spawn), so a
nonexistent binary takes the fenced spawn-failure path and returns
the sentinel triple `(-1, "", "tot: cannot exec CMD")`, identical
pre- and post-fix;  the fixture pins CODE=-1, not a child-side 127.

Mutation confirmations:

    $ gtimeout 10 gate-run test/fixtures/x8-proc-bigstderr.tot
      (child: head -c 300000 /dev/zero | tr '\0' e 1>&2)
    PRE-FIX  exit=124, no output (the C16 deadlock, killed by the watchdog)
    POST-FIX CODE=0 / ERRLEN=300000, exit=0 in ~1s  [PASS-C-PROC-BIGSTDERR,
             under a 15s watchdog]

    $ gate-run test/fixtures/x9-proc-noexec.tot
    PRE-FIX  CODE=-1, exit=0
    POST-FIX CODE=-1, exit=0  [PASS-C-PROC-NOEXEC pins the value;  the
             NEW in-process case "B3: procRun spawn failure returns
             the -1 sentinel and leaks no descriptors across 5
             attempts" pins /dev/fd entry-count stability, the C8
             observable]

PASS-C-PROC (the /bin/echo triple) stays green.

### B4 (C10): exitWith range

`Effect.dispatch`'s `Exit_with` arm validates 0..255 at the single
chokepoint every exitWith crosses;  out of range is the NEW
`Error.t` variant `Exit_code_out_of_range of int` through the
ordinary Result channel (`run_verdict_main`/`run_unit_main` then
never see an out-of-range `Exited`).  bin/tot.ml's runtime
script-error print moved from stdout to STDERR in `run_file`'s
error arm, per the plan's "message on stderr, process exit 1":
recorded as affecting every CLI script error, not only this one
(stdout is the hook protocol's channel and must carry only a
rendered decision;  the C1' stage still owns the exit-1-vs-ask
collision residual).

Mutation confirmation:

    $ gate-run test/fixtures/x4-exit-range.tot     # def main : IO Unit := exitWith 300
    PRE-FIX  exit=44 (300 mod 256, the silent wrap)
    POST-FIX stdout empty;  stderr:
             x4-exit-range.tot:1:1: exitWith 300: exit code out of range 0..255
             exit=1  [PASS-B-EXITRANGE captures stderr ONLY, so the
             marker also pins the stream]

### Files touched

- lib/error.ml (NEW variants `Regex_bad_pattern`,
  `Exit_code_out_of_range`, with to_string/tag arms)
- lib/interp.ml (B1: `regex_compile`, widened `str_opt`,
  `group_scan` state machine, Result-typed regex runners, threaded
  fire_prim arms, comment block rewritten)
- surface/effect.ml (B3 helpers + temp-file `Proc_run` arm;  B4
  range check in `Exit_with`)
- surface/cache.ml (B2: magic/version/digest format, verified load,
  widened Marshal fence, tmp unlink on failed rename,
  format_version 3, module doc rewritten)
- bin/tot.ml (O7 line-1 reword;  B4 stderr routing for script
  errors)
- test/main.ml (NEW case B5 `case_regex_group_count`)
- test/surface.ml (D2 case extended to body-trunc/corrupt/magic +
  re-hit;  NEW B3 fd-count case)
- dev/gates.sh (NEW PASS-B-EXITRANGE, PASS-C-PROC-BIGSTDERR,
  PASS-C-PROC-NOEXEC, PASS-C-REGEX-CLASS, PASS-C-REGEX-BACKSLASHES,
  PASS-C-REGEX-BADPATTERN, PASS-D-CACHE-BODYTRUNC,
  PASS-D-CACHE-CORRUPT, PASS-D-CACHE-MAGIC)
- SPEC.md (section 2 dated stage-B entry;  section 6 cache
  trust-class residual + forgotten-bump note)
- test/fixtures/x4-exit-range.tot, x5-regex-class.tot,
  x6-regex-backslashes.tot, x7-regex-badpattern.tot,
  x8-proc-bigstderr.tot, x9-proc-noexec.tot (all new)

New Error/Serror variants: `Error.Regex_bad_pattern of string`,
`Error.Exit_code_out_of_range of int`.  Test names added: kernel B5
`case_regex_group_count`;  surface "B3: procRun spawn failure
returns the -1 sentinel and leaks no descriptors across 5 attempts";
surface D2 extended (title now names truncation, corruption and
magic);  the nine new gate markers listed above.

### Gate tails

    $ dunecho build -- --root ~/Documents/tot
    OK build: 0 errors, 0 warnings

    $ dune exec --root ~/Documents/tot test/main.exe | tail -3
    PASS C4: Json-shaped self-recursive ctors pass positivity; List T -> T nesting is Bad_ctor
    PASS B5: regex_group_count agrees with the Str dialect on classes and escaped backslashes
    M0 kernel: all tests green

    $ dune exec --root ~/Documents/tot test/surface.exe | tail -3
    PASS D4e: main : IO Unit still runs when it does not convert to IO Verdict, and honors exitWith (the ordinary per-item echo is unaffected, unlike the Verdict path)
    PASS B3: procRun spawn failure returns the -1 sentinel and leaks no descriptors across 5 attempts
    M1 surface: all tests green

    $ zsh dev/gates.sh; echo exit=$?
    exit=0
    (markers, in order) BUILD-OK TEST-OK PASS-A-LITERALS
    PASS-CHECK-PRELUDE PASS-RUN-PRELUDE PASS-CHECK-CHURCH
    PASS-RUN-CHURCH PASS-CHECK-NAT PASS-RUN-NAT SCRIPTS-OK
    PASS-B-EXITCODE PASS-B-NOEFFECT PASS-B-DEFERRED PASS-B-DIV-MEMO
    PASS-CHECK-NESTED-DIV PASS-B-EXITRANGE PASS-C-JSON
    PASS-C-POSITIVITY PASS-C-PROC PASS-C-PROC-BIGSTDERR
    PASS-C-PROC-NOEXEC PASS-C-REGEX-BENIGN PASS-C-REGEX-CLASS
    PASS-C-REGEX-BACKSLASHES PASS-C-REGEX-BADPATTERN
    PASS-C-REGEX-PATHOLOGICAL PASS-C-REGEX-PATHOLOGICAL-RUN
    PASS-C-REGEX PASS-C-PARTIAL PASS-C-PRIMLINT PASS-D-GUARD-ALLOW
    PASS-D-GUARD-DENY PASS-D-GUARD-OTHER PASS-D-CACHE-HIT
    PASS-D-CACHE-MISS PASS-D-CACHE-BODYTRUNC PASS-D-CACHE-CORRUPT
    PASS-D-CACHE-MAGIC

## Stage C (2026-09-01): driver, tests, docs (C1' O4, C2' O6, C3' C1, C4' C2+C11+C13+C0+C4+C12, C5' sweep)

### C1' (O4): main is a reserved driver name

`surface/run.ml`'s `main_epilogue` now runs in BOTH modes: when the
user file defines a global literally named `main`, its stored type is
evaluated exactly once (kernel NbE only, never `Interp`, so check
mode still executes no user def body and never calls `run_io`) and
must convert to `IO Verdict` or `IO Unit`;  anything else is the NEW
`Serror.Main_bad_type` variant, carrying the printed type.  No `main`
at all stays script mode, unchanged.  A misspelled `main` stays
silent: the documented residual, along with the exit-1-vs-ask
collision, both now in SPEC.md section 6.

Mutation confirmation (recorded pre-fix, then re-run post-fix; the
fixtures hold exactly the two O4 repro scripts):

    $ tot check test/fixtures/x10-main-bad-type.tot   # def main : IO Bool
    PRE-FIX  prints "def main : (IO Bool)", exit=0  (silent no-op)
    POST-FIX x10-main-bad-type.tot:main is a reserved driver name: its type must convert to IO Verdict or IO Unit, got (IO Bool)
             exit=1  (stderr; the same result under `tot run`, where
             pre-fix was also exit=0 printing nothing, and the
             fixture's printLine effect never fires)

    $ tot run test/fixtures/x11-main-misspelled.tot   # def mian : IO Verdict
    PRE-FIX  prints "def mian : (IO Verdict)", exit=0
    POST-FIX identical BY DESIGN: the pinned documented residual

New gates PASS-D-MAIN-BADTYPE (check AND run must exit 1 with the
reserved-name message, and the run-mode output must NOT contain the
fixture's effect line) and PASS-D-MAIN-MISSPELLED (exit 0 plus the
ordinary def echo, pinning the residual on purpose).  New suite cases
D4f (run mode, error printed via expect_err_printed), D4g (CHECK mode
errors too) and D4h (misspelled main, exit None);  the printed
rejection reason for both negatives:

    expected error (Main_bad_type): main is a reserved driver name: its type must convert to IO Verdict or IO Unit, got (IO Bool)

Guard fixtures allow/deny/other stay green (battery below).

### C2' (O6): full prim-arity pin

`test/main.ml`'s `case_prim_arity_agreement` table is now
`phase1_prims @ phase2_prims @ phase3_prims`: all 29 catalog rows sit
under the pin (verified: prim-bootstrap-count = 29 = strict-row count
of `tot prims`), so the 12 Stage C prims are covered by the dedicated
regression test, not only the live `seed_prim` bootstrap check.  The
claim at lib/prim.ml (old line 96) now names the test and the
three-phase scope, so it is true as written.

### C3' (C1): prim-lint line discipline

`dev/prim-lint.sh` no longer compares `wc -l` against a pattern
count.  Every NON-EMPTY line of `tot prims` must match the strict
catalog-row shape;  any line that does not is printed BY NAME and
fails the lint, and `n_total` is then the strict-row count itself, so
the catalog-size agreement against prim-bootstrap-count shares one
line shape with the discipline check.  Mutation confirmation
(simulated through the exact script logic, since the live output has
no offending line):

    PRE-FIX  a header line gives total=2 justified=1: spurious FAIL
             with a bare count and NO offending line named;  output
             missing a trailing newline undercounts total via wc -l,
             masking a missing justification
    POST-FIX the same input lists the offender and fails by name:
             PRIM CATALOG (header line)
             -> FAIL-C-PRIMLINT (lines outside the strict shape)

### C4' (small fixes)

- C2: `lib/check.ml` `define` reuses the already-computed `ty_v` for
  the partial-def Div-codomain check when the type has no leading Pi
  (exhaustive match over `Term.t`, no catch-all), instead of
  re-evaluating through `peel_codomain`'s base case.  Covered by the
  existing kernel C1-C3 partial cases and PASS-C-PARTIAL.
- C11: `main_epilogue` evaluates main's type ONCE and passes the
  VALUE into `converts_to` (signature now takes `Value.t`) for both
  the `IO Verdict` and `IO Unit` comparisons.  Covered by D4b-D4h.
- C13: `test/surface.ml`'s argv dispatch errors on a malformed or
  unknown subcommand (exit 2, usage message on stderr);  only a BARE
  argv still runs the ordinary suite, so `dune runtest` is
  unaffected.  Mutation confirmation:

      $ test/surface.exe gate-check      # path argument missing
      PRE-FIX  silently ran the FULL suite: "M1 surface: all tests green", exit=0
      POST-FIX unknown subcommand: gate-check
               usage: surface.exe [gate-check FILE | gate-run FILE | prim-bootstrap-count | bootstrap-only]
               exit=2   [pinned by new gate PASS-C-ARGV-USAGE]

- C0: dev/gates.sh chmods ONLY the scratch binary copy;  the tracked
  examples/guard.tot chmod is deleted from the script, and the file's
  executable bit is set once in the working tree (plain chmod +x, no
  git commands) so the mode rides the next staging.
- C4: `lib/interp.ml` `VPrim` spines accumulate NEWEST FIRST (cons,
  O(1) per application, the `VNeut` frame convention) and reverse
  into argument order once at fire time;  `quote` reverses at
  readback.  Repo-wide sweep confirmed `apply` and `quote` are the
  only order-sensitive consumers (every other `VPrim` site reads the
  prim name or ignores the args).  `Cache.format_version` bumped
  3 -> 4: same OCaml type, but an old-order blob read by a new binary
  would fire prims with reversed arguments, so the version fences it
  out.  Argument order stays pinned by the kernel arity/order cases
  and the exact-capture regex gates (PASS-C-REGEX-BENIGN/-CLASS/
  -BACKSLASHES all pin multi-arg results).
- C12: the `(rec_, partial)` invariant on `Syntax.IDef` is documented
  as NOT type-enforced (doc comment names the parser as the only
  enforcement and the NonRec | Rec | RecPartial sum type as the M4
  shape);  SPEC.md section 6 carries the debt line.

### C5' (doc truth sweep)

- lib/prim.ml arity claim: made true by C2' (names the test and the
  three-phase scope).
- lib/interp.ml regex comment: replaced by stage B (verified gone;
  only the state-machine comment remains).
- surface/cache.ml module doc and bin/tot.ml line 1: rewritten by
  stage B (verified: never-crash claims match the verified-load code;
  check-may-write-cache wording in place).
- test/fixtures/b-deferred-div.tot header: now describes the A1
  mechanism (check builds no runtime environment;  the head-keyed
  deferral governs run mode only), replacing the retired Stage B
  head-rule citation stage A's log flagged for this sweep.
- NEW finding, same falsehood class as B1's comment: lib/interp.ml's
  two JSON comments call the `\uXXXX` gap and the serializer escape
  set a "documented SPEC debt", but SPEC.md had NO such entry.  Fixed
  by adding the JSON-conformance debt to section 6, making both
  comments true as written.
- SPEC.md: section 2 dated stage C entry (C1' decision with both
  residuals;  C4 spine order + format bump;  C1/C13/O6/C0/C2 notes);
  section 6 gains four debt lines (misspelled main;  Serror exit 1
  colliding with ask;  the rec_/partial flag pair;  JSON conformance).
- README.md: checked against every stage C change;  no claim it makes
  became false (it names no driver typing rule, no prim-lint
  internals, no argv dispatch), so it is UNCHANGED.

### Files touched

- surface/serror.ml (NEW variant `Main_bad_type of { ty : string }`,
  to_string/tag arms)
- surface/run.ml (C1' reserved-main check in both modes;  C11 single
  type evaluation;  `converts_to` takes the evaluated `Value.t`)
- lib/check.ml (C2: reuse `ty_v` on the no-leading-Pi partial path)
- lib/interp.ml (C4: cons-accumulated `VPrim` spine, reverse at fire
  and readback, `v` type doc)
- surface/cache.ml (C4: `format_version` 3 -> 4, checklist comment)
- surface/syntax.ml (C12 doc comment)
- lib/prim.ml (C2'/C5' claim reword)
- test/main.ml (C2': three-phase arity table;  comment reword)
- test/surface.ml (C13 argv usage error;  NEW cases D4f/D4g/D4h)
- dev/prim-lint.sh (C3' line discipline)
- dev/gates.sh (C0 scratch-only chmod;  NEW gates PASS-C-ARGV-USAGE,
  PASS-D-MAIN-BADTYPE, PASS-D-MAIN-MISSPELLED)
- SPEC.md (section 2 stage C entry;  section 6: four new debt lines)
- test/fixtures/x10-main-bad-type.tot (new),
  x11-main-misspelled.tot (new), b-deferred-div.tot (header comment
  only)
- examples/guard.tot (mode bit only, chmod +x;  content unchanged)

New Error/Serror variants: `Serror.Main_bad_type of { ty : string }`.
Test names added: surface D4f, D4g, D4h;  gates PASS-C-ARGV-USAGE,
PASS-D-MAIN-BADTYPE, PASS-D-MAIN-MISSPELLED.

### Gate tails

    $ dunecho build -- --root ~/Documents/tot
    OK build: 0 errors, 0 warnings

    $ dune exec --root ~/Documents/tot test/main.exe | tail -3
    PASS C4: Json-shaped self-recursive ctors pass positivity; List T -> T nesting is Bad_ctor
    PASS B5: regex_group_count agrees with the Str dialect on classes and escaped backslashes
    M0 kernel: all tests green

    $ dune exec --root ~/Documents/tot test/surface.exe | tail -3
    PASS D4h: a misspelled main (mian) stays script mode with no driver exit code (the documented residual)
    PASS B3: procRun spawn failure returns the -1 sentinel and leaks no descriptors across 5 attempts
    M1 surface: all tests green

    $ zsh dev/gates.sh; echo exit=$?
    exit=0
    (markers, in order) BUILD-OK TEST-OK PASS-A-LITERALS
    PASS-CHECK-PRELUDE PASS-RUN-PRELUDE PASS-CHECK-CHURCH
    PASS-RUN-CHURCH PASS-CHECK-NAT PASS-RUN-NAT SCRIPTS-OK
    PASS-B-EXITCODE PASS-B-NOEFFECT PASS-B-DEFERRED PASS-B-DIV-MEMO
    PASS-CHECK-NESTED-DIV PASS-B-EXITRANGE PASS-C-JSON
    PASS-C-POSITIVITY PASS-C-PROC PASS-C-PROC-BIGSTDERR
    PASS-C-PROC-NOEXEC PASS-C-REGEX-BENIGN PASS-C-REGEX-CLASS
    PASS-C-REGEX-BACKSLASHES PASS-C-REGEX-BADPATTERN
    PASS-C-REGEX-PATHOLOGICAL PASS-C-REGEX-PATHOLOGICAL-RUN
    PASS-C-REGEX PASS-C-PARTIAL PASS-C-PRIMLINT PASS-C-ARGV-USAGE
    PASS-D-GUARD-ALLOW PASS-D-GUARD-DENY PASS-D-GUARD-OTHER
    PASS-D-MAIN-BADTYPE PASS-D-MAIN-MISSPELLED PASS-D-CACHE-HIT
    PASS-D-CACHE-MISS PASS-D-CACHE-BODYTRUNC PASS-D-CACHE-CORRUPT
    PASS-D-CACHE-MAGIC

## Round 2

### Stage A (2026-09-01): re-probe findings R1, R2, R3

Files touched: surface/cache.ml, lib/interp.ml, surface/run.ml,
test/surface.ml, test/fixtures/x12-dead-abort.tot (new),
test/fixtures/x13-dead-hang.tot (new), dev/gates.sh, SPEC.md.
No new Error/Serror variants.

R1 (HIGH), cache layout drift undetectable by construction: the cache
is now bound to the exact executable.  surface/cache.ml computes,
once per process (a lazy cell), the MD5 digest of the running
binary's own contents (Digest.file Sys.executable_name; a Sys_error
disables the cache for the whole run with one loud stderr line, and
save then writes nothing).  The digest is folded into the cache KEY
and written as a fourth fixed-width header field (layout: magic 8,
version 8, body digest 32, exe digest 32; header 80 bytes), which
load verifies before the body digest.  format_version bumped 4 -> 5
(the header grew AND R2 changed the stored gval contents); since R1
the version is belt-and-suspenders, the exe digest is the fence.
Module doc, SPEC section 6 cache bullets, and a new dated SPEC
decision entry rewritten to match; the trusted-directory residual is
kept, now noting the attacker can also read the binary digest.

R1 mutation confirmation, cross-binary drift (tot-adv2/run-drift2.sh,
drift binary totcopy shares format_version 4 but differs in one
marshaled payload type).  Pre-fix transcript (2026-09-01, this
session):

    drift-write exit=0
    drift-own-read exit=0        (succ (succ (succ zero)))
    REAL-read-of-drift-blob exit=0
        ((add (succ (succ zero))) (succ zero))   <- SILENTLY WRONG
    real-write exit=0
    DRIFT-read-of-real-blob exit=139             <- SIGSEGV
    real-cold exit=0 / drift-cold exit=0         (correct numeral)

Post-fix transcript (same script, fixed binary): every read prints
the correct numeral (succ (succ (succ zero))) and exits 0; the two
binaries never open each other's blobs (different keys: exe digest
and version both differ), i.e. two independent cold caches, no
segfault in either order.

R1 mutation confirmation, forged blob (tot-adv2/run-forge.sh; forge
writes correct magic + version 00000004 + body digest over a foreign
Marshal body at the blob path).  Pre-fix: intpair/listpair/triple
exit 1 printing "unknown name Nat" (the forged blob silently REPLACED
the checked prelude), strpair/unit exit 139 (SIGSEGV).  Post-fix: all
five kinds exit 0 and print "def probeValue : Nat" (fresh
elaboration; the forged header is rejected on the version field and
lacks the exe field entirely).  Additional probe: on a warmed cache,
TOT_CACHE_VERIFY=1 prints TOT-CACHE-VERIFY-OK (hit); after xor-1 of
byte 60 (inside the exe-digest field 48..79, body and body digest
untouched) the same command is a silent miss, exit 0, proving the exe
field check alone forces the miss.

R1 tests: test/surface.ml D2 gained the wrong-binary-digest header
case (corrupt_at 60, inside the exe field, body digest left VALID),
expecting a silent miss; the corrupted-body index moved 60 -> 120
(past the 80-byte header) and the stale 48-byte-header comments in
the test and dev/gates.sh were updated.  All PASS-D-CACHE-* gates
stay green.

R2 (MEDIUM), dead code could abort or hang a run-mode guard: in RUN
mode Interp.define now stores EVERY user def as a GDeferred memoized
thunk (the A2 memo machinery generalizes; define is total now, no
result).  Elaboration, checking, erasure and closedness stay EAGER at
definition time; evaluation happens on first force by an eval item or
by main; the memo keeps single-execution.  Check mode is unchanged.
surface/run.ml drops the head-keyed defer decision (the ty_v eval and
Check.is_effect_headed call; the latter is still used by
Check.define's reducible refusal).  SPEC: the round-1 "eager by
design" decision text now points at a new dated round-2 entry with
the lazy-memoized rule, the hard-constraint-1 paragraph's run-mode
half restates it, and the section 6 debt bullet records the trade:
check over-approximates run's definition-time failure set for dead
code, and a LIVE def's definition-time abort surfaces only at force
time.

R2 mutation confirmation (pre-fix exits, this session, probe fixtures
tot-adv2/divergence/deadbad.tot and deadhang.tot, identical shapes to
the new fixtures): `tot run` on the dead-abort shape exited 1
("malformed regex pattern: a\\( ...", the ask exit) and on the
dead-hang shape exited 124 under a 5s watchdog, while `tot check`
reported both clean.  Post-fix both fixtures exit 0 with an empty
stdout envelope.

R2 tests and gates: fixtures moved in as
test/fixtures/x12-dead-abort.tot and x13-dead-hang.tot; new gates
PASS-RUN-DEADCODE-ABORT and PASS-RUN-DEADCODE-HANG run `tot run` on
each under the watchdog and require exit 0 AND empty stdout.
b-deferred-div and x3-div-chain gates stay green (they force through
eval/main; timings unchanged: PASS-B-DEFERRED, PASS-B-DIV-MEMO).

R3 (doc), hard constraint 1 scoped honestly (no code change, per the
round-2 plan): SPEC's hard-constraint-1 paragraph now claims exactly
that check performs no host effects and never executes the
interpreter, while kernel CONVERSION can be driven to unbounded
compute by reducible definitions (the re-probe's eight reducible
lines drove `tot check` past 300 s), same as any dependent checker;
opaque-by-default is the mitigation.  New section 6 debt bullet: a
driver-level fuel or wall-clock budget flag for check mode is M4
work; hook installations should wrap `tot` in an external timeout
until then.  dev/M3-PLAN.md lines 521-522 left frozen.

Adjudications: none beyond plan scope (Stage A carries no survivor
list); the one discretionary call was making Interp.define total
(always-deferred has no error path), which removes the dead eager
branch instead of keeping a vestigial ~defer flag.

Gate battery (2026-09-01, /tmp/claude/m3fix-gates.log, exit=0), tail:

    PASS-D-GUARD-ALLOW PASS-D-GUARD-DENY PASS-D-GUARD-OTHER
    PASS-D-MAIN-BADTYPE PASS-D-MAIN-MISSPELLED PASS-D-CACHE-HIT
    PASS-D-CACHE-MISS PASS-D-CACHE-BODYTRUNC PASS-D-CACHE-CORRUPT
    PASS-D-CACHE-MAGIC

with both suites green (M0 kernel: all tests green;  M1 surface: all
tests green, including the extended D2 case) and the full marker roll
including the two new markers:

    BUILD-OK TEST-OK PASS-A-LITERALS PASS-CHECK-PRELUDE
    PASS-RUN-PRELUDE PASS-CHECK-CHURCH PASS-RUN-CHURCH PASS-CHECK-NAT
    PASS-RUN-NAT SCRIPTS-OK PASS-B-EXITCODE PASS-B-NOEFFECT
    PASS-B-DEFERRED PASS-B-DIV-MEMO PASS-CHECK-NESTED-DIV
    PASS-RUN-DEADCODE-ABORT PASS-RUN-DEADCODE-HANG PASS-B-EXITRANGE
    PASS-C-JSON PASS-C-POSITIVITY PASS-C-PROC PASS-C-PROC-BIGSTDERR
    PASS-C-PROC-NOEXEC PASS-C-REGEX-BENIGN PASS-C-REGEX-CLASS
    PASS-C-REGEX-BACKSLASHES PASS-C-REGEX-BADPATTERN
    PASS-C-REGEX-PATHOLOGICAL PASS-C-REGEX-PATHOLOGICAL-RUN
    PASS-C-REGEX PASS-C-PARTIAL PASS-C-PRIMLINT PASS-C-ARGV-USAGE
    PASS-D-GUARD-ALLOW PASS-D-GUARD-DENY PASS-D-GUARD-OTHER
    PASS-D-MAIN-BADTYPE PASS-D-MAIN-MISSPELLED PASS-D-CACHE-HIT
    PASS-D-CACHE-MISS PASS-D-CACHE-BODYTRUNC PASS-D-CACHE-CORRUPT
    PASS-D-CACHE-MAGIC

### Stage B (2026-09-01): ctxcat round-2 survivor sweep (22 findings)

Survivor source: parsed the JSON at the round-2 plan's tmp path
(.result.survivors, 22 entries;  the id sequence runs 0..22 with id 8
absent from the JSON itself, dropped upstream before this stage).
Disposition: 17 fixed, 4 adjudicated no-change, 1 refuted.  One
logged line per survivor:

- id 0 (bin/tot.ml, medium) FIXED: run_with_prelude's bootstrap
  error now goes through prerr_endline (the B4 channel rule);  new
  gate PASS-PRELUDE-ERR-STDERR pins exit 1 + EMPTY stdout + the
  "prelude: " line on stderr.
- id 1 (gates.sh Gate B(iii), medium) FIXED: the deferred-div check
  now runs under `"$watchdog" 10`;  the 5s elapsed bound stays as the
  tighter in-bound assertion.
- id 2 (gates.sh prim-lint call, low) FIXED: captured
  (`out=$(... 2>&1)`), replayed on failure AND success;  the
  PASS-C-PRIMLINT marker keeps its ONE emission point inside
  prim-lint.sh (verified: exactly 1 occurrence in the gate log).
- id 3 (gates.sh hardcoded paths, nit) FIXED: `ROOT="$(cd
  "$(dirname "$0")/.." && pwd)"` at the top;  all 33 literal
  occurrences replaced with `"$ROOT"`.
- id 4 (prim-lint.sh hardcoded path, medium) FIXED: same ROOT
  derivation from the script's own location;  both dune exec
  invocations use it.
- id 5 (examples/guard.tot fail-open, medium) ADJUDICATED no-change
  BY DESIGN: the driver protocol fails open on unparseable hook
  input (M3 Stage D, D5;  SPEC's M3 record runs the guard against the
  garbage fixture expecting exit 0).  Extended the comment above
  main to cite the decision and PASS-D-GUARD-OTHER, and to note the
  same posture inside decide for missing tool_name/tool_input.
- id 6 (lib/check.ml provisional partial, medium) FIXED: the
  provisional self-reference entry now carries the def's REAL
  partial flag.  Audit (rg over every Global.Def consumer): the only
  reads of a global's partial field in the tree are
  test/main.ml:1093/1101, asserting on the FINAL entry after
  Check.define returns;  Eval.eval reads rec_arg/reducible/def only,
  and no code consults partial during body checking.  The wrong
  value was therefore unreachable by any current consumer, so per
  the plan no regression test is added;  the fix removes the trap for
  future consumers.
- id 7 (lib/check.ml non-Pi arm duplication, nit) ADJUDICATED
  no-change: the suggested is_pi helper cannot be shared with
  peel_codomain (which must keep its own match to recurse through
  Pi), so factoring it would ADD a third exhaustive Term.t
  enumeration instead of removing one;  the finding itself offers
  accepting the documented perf-rationale duplication.
- id 9 (lib/interp.ml String_to_int, medium) FIXED: new
  decimal_int_opt validates optional '-' plus digits before
  int_of_string_opt, so 0x/0o/0b prefixes, '_' separators, '+',
  and leading spaces all yield none.  Prim.justification for
  String_to_int rewritten to match.  Mutation confirmation, pre-fix
  (this session, via `tot run`): stringToInt "0x1A" printed
  (some 26) and "1_000" printed (some 1000);  post-fix both print
  none while "-42" keeps (some -42).  Regression test C8b.
- id 10 (lib/prim.ml duplicated justification, nit) FIXED: one
  shared `Regex_test | Regex_match` arm, single string.
- id 11 (stdlib/prelude.tot headOr unused, low) REFUTED: headOr HAS
  a caller in this batch, examples/guard.tot's firstToken (line 17,
  `headOr String "" (stringSplit cmd " ")`), exercised by every
  Gate D guard run;  bootstrap.ml's segment-3 comment also names it.
  No change.
- id 12 (surface/bootstrap.ml is_some/value pair, nit) FIXED:
  cached_state dispatches via Option.to_result + Result.fold (both
  branches closures, so the cold path stays unevaluated on a hit;
  Option.fold's eager ~none: would have evaluated it), removing the
  throwaway-default re-unwrap.
- id 13 (surface/effect.ml bare `with _`, medium) FIXED: Read_stdin
  and Print_line now fence `exception Sys_error _` by name (the one
  exception those channel calls are documented to raise), and the
  module doc comment now states the named-exception posture instead
  of claiming a bare `with _` design.
- id 14 (surface/lexer.ml raw newline in string, medium) FIXED: a
  raw '\n' before the closing quote is now `Serror.Lex "newline in
  string literal (use \n)"`.  Mutation confirmation, pre-fix (this
  session): `eval stringLength "a<newline>b"` printed 3, exit 0;
  post-fix it errors at 1:21 with the message above, exit 1.  A
  quote-parity scan over all 27 in-tree .tot files found no string
  spanning a line, so nothing in-tree changes meaning.  Regression
  test C8c (expect_err_printed shows the exact message).
- id 15 (test/main.ml B5 ordering, nit) FIXED: B5 registration moved
  between B4 and C1.
- id 16 (test/surface.ml misattached doc comment, medium) FIXED: the
  C6 comment now sits on print_bootstrap_prim_count and names all
  THREE phase lists;  bootstrap_only's own comment also corrected (it
  still claimed both prelude markers derive from its one exit code,
  stale since round-1 A3 split PASS-RUN-PRELUDE out).
- id 17 (test/surface.ml magic offset 60, nit) FIXED: D2's corruption
  offsets now derive from Cache's own exposed width constants
  (header_width + 40 for the body byte;  magic_width + version_width
  + digest_width + 12 for the exe-digest field), same bytes as
  before (120 and 60), so a header resize shifts the test with it.
- id 18 (gates.sh bare `timeout 5`, medium) FIXED: all three Gate D
  main-name invocations use `"$watchdog" 5`.
- id 19 (gates.sh vacuous cache-corruption markers, medium) FIXED:
  each case re-globs the blob after its re-warm via a shared
  rewarm_cache_file helper (which also proves the blob holds the
  target offset: size >= 2001), proves the mutation landed (od byte
  non-empty, dd exit checked, `cmp` against the corrupted copy), and
  requires the run to have REWRITTEN the corrupted blob (post-run
  bytes must differ from the corrupted copy: a real miss
  re-elaborates and re-saves;  a hit would leave them identical and
  turn the marker red).
- id 20 (gates.sh Gate B(iii) watchdog, low) FIXED: duplicate of id
  1, same edit.
- id 21 (gates.sh PASS-C-REGEX-PATHOLOGICAL-RUN wants 124, low)
  ADJUDICATED no-change: the exit-124 pin is round-1 A3's documented
  design (the run-mode line is the falsifiable half of the
  check-vs-run differential;  accepting 0 OR 124 recreates the exact
  cannot-fail shape A3 removed, and a sentinel needs a fixture
  redesign this sweep does not own).  When M4's bounded regex engine
  lands, the gate must be updated deliberately with it, and the
  in-file comment already records the measurement basis.
- id 22 (gates.sh scratch-dir leak, nit) FIXED: an EXIT trap right
  after the tot_scratch mktemp removes both scratch dirs on every
  exit path (single-quoted so $cache_scratch resolves at exit time);
  the final explicit rm now rides the trap.  Post-battery TMPDIR
  scan shows zero tot-gate-d leftovers.

Files touched (Stage B): bin/tot.ml, lib/check.ml, lib/interp.ml,
lib/prim.ml, surface/bootstrap.ml, surface/effect.ml,
surface/lexer.ml, test/main.ml, test/surface.ml, dev/gates.sh,
dev/prim-lint.sh, examples/guard.tot.  New Error/Serror variants:
none (the lexer reuses Serror.Lex).  New tests: C8b, C8c (surface
suite);  new gate marker: PASS-PRELUDE-ERR-STDERR;  strengthened
markers: PASS-B-DEFERRED (watchdogged), PASS-D-MAIN-BADTYPE /
PASS-D-MAIN-MISSPELLED (watchdog portability), PASS-D-CACHE-BODYTRUNC
/ -CORRUPT / -MAGIC (mutation-proof + rewrite-proof).

Gate battery (2026-09-01, /tmp/claude/m3fix-gates.log, exit=0), tail:

    PASS-D-CACHE-HIT
    PASS-D-CACHE-MISS
    PASS-D-CACHE-BODYTRUNC
    PASS-D-CACHE-CORRUPT
    PASS-D-CACHE-MAGIC

with both suites green (M0 kernel: all tests green;  M1 surface: all
tests green, including C8b/C8c and the rewritten D2 offsets) and the
full marker roll:

    BUILD-OK TEST-OK PASS-A-LITERALS PASS-CHECK-PRELUDE
    PASS-RUN-PRELUDE PASS-PRELUDE-ERR-STDERR PASS-CHECK-CHURCH
    PASS-RUN-CHURCH PASS-CHECK-NAT PASS-RUN-NAT SCRIPTS-OK
    PASS-B-EXITCODE PASS-B-NOEFFECT PASS-B-DEFERRED PASS-B-DIV-MEMO
    PASS-CHECK-NESTED-DIV PASS-RUN-DEADCODE-ABORT
    PASS-RUN-DEADCODE-HANG PASS-B-EXITRANGE PASS-C-JSON
    PASS-C-POSITIVITY PASS-C-PROC PASS-C-PROC-BIGSTDERR
    PASS-C-PROC-NOEXEC PASS-C-REGEX-BENIGN PASS-C-REGEX-CLASS
    PASS-C-REGEX-BACKSLASHES PASS-C-REGEX-BADPATTERN
    PASS-C-REGEX-PATHOLOGICAL PASS-C-REGEX-PATHOLOGICAL-RUN
    PASS-C-REGEX PASS-C-PARTIAL PASS-C-PRIMLINT PASS-C-ARGV-USAGE
    PASS-D-GUARD-ALLOW PASS-D-GUARD-DENY PASS-D-GUARD-OTHER
    PASS-D-MAIN-BADTYPE PASS-D-MAIN-MISSPELLED PASS-D-CACHE-HIT
    PASS-D-CACHE-MISS PASS-D-CACHE-BODYTRUNC PASS-D-CACHE-CORRUPT
    PASS-D-CACHE-MAGIC

prim-lint.sh also verified standalone (exit 0, PASS-C-PRIMLINT) via
its own ROOT derivation.

## Round 3

2026-09-01, round-3 fix batch: 17 ctxcat survivors dispositioned (14
fixed, 2 adjudicated no-change, 1 fixed in reduced scope) plus the 5
opus re-probe findings O1..O5 (3 fixed, 1 adjudicated, 1 gates-only).
The R1/R2 mechanisms themselves survived all round-3 attacks and are
untouched.

### Fix list (ctxcat survivors, by id)

- id 5 (HIGH, lib/interp.ml string_slice_opt): the additive bounds
  guard `start + len <= String.length s` wrapped negative on huge
  user-controlled ints and admitted an out-of-range String.sub.
  Rewritten overflow-safe: `start >= 0 && len >= 0 && start <=
  String.length s && len <= String.length s - start` (subtraction of
  bounded nonnegatives cannot overflow).  Sibling sweep over
  lib/interp.ml and surface/effect.ml for `a + b <= n` guards found
  only find_from (string_split_on) and contains_from, both loop
  indices stepping by 1 from 0 against string lengths, no
  user-controlled operand, and effect.ml's `128 + host_signal_number`
  (not a bounds guard);  no sibling fix needed.  Regression: surface
  test C8d (overflow-scale start+len, and huge-start/len-1) pins
  `none`/`none`.
- id 3 (MEDIUM, examples/guard.tot): usesBanned was bypassable by a
  leading/doubled space (empty first token) and by a path-qualified
  binary.  firstToken now takes the first NON-EMPTY token
  (firstNonEmpty over stringSplit on " "), and the comparison uses
  the BASENAME (lastOr over stringSplit on "/").  New fixture
  test/fixtures/deny-path.json (" /usr/bin/grep foo /tmp/x": leading
  space AND path in one payload) wired as gate
  PASS-D-GUARD-DENY-PATH;  "rg x" and "ripgrep foo" stay allowed
  (post-fix matrix below).
- id 0 (MEDIUM, dev/gates.sh PASS-PRELUDE-ERR-STDERR): exit code,
  stdout and stderr now come from ONE invocation (stderr to a mktemp
  file, read back and removed), never two runs asserted as one.
- id 1 (LOW, dev/gates.sh + dev/prim-lint.sh): ROOT derivation
  resolves a symlinked $0 via `readlink -f` with a plain-$0 fallback.
- id 15 (LOW, dev/gates.sh sentinel gate): the mktemp-created file is
  kept and truncated in place by the `>` redirects;  the
  rm-then-recreate TOCTOU window is gone.
- id 16 (LOW, dev/gates.sh): the watchdog probe moved to the TOP
  (right after BUILD-OK), and every previously-unguarded invocation
  ahead of the old probe site now runs under it: both suites
  (`"$watchdog" 120`) and the Gate A/B lead-in dune execs
  (`"$watchdog" 30`).  Gates after the old probe site keep their
  existing wrapping.
- id 17 (LOW, dev/gates.sh PASS-RUN-PRELUDE): stdout captured alone
  and matched per-line with `rg -qx`;  stderr to a temp file for the
  failure replay, so a benign stderr byte (dune notice, the R1
  cache-disabled line) cannot flip the marker.
- id 9 (MEDIUM, surface/cache.ml save): a FAILED Out_channel write
  (disk full, permission race) now best-effort unlinks the .tmp file
  too, via a shared remove_tmp;  previously only the rename path did.
- id 10 (LOW, surface/cache.ml ensure_dir): recursive
  create-parents-first (terminates at Filename.dirname fixpoints), so
  a TOT_CACHE_DIR override nested more than one level under an
  existing directory works;  the old two-level unroll silently
  no-opped.
- id 11 (MEDIUM, surface/effect.ml Print_line): `flush stdout` rides
  INSIDE the Sys_error fence with the print, so a broken-pipe error
  surfaces in the guarded region, not at the unguarded at_exit flush.
- id 4 (NIT, lib/check.ml): new ensure_fresh helper (Option.fold over
  Global.find) replaces the four verbatim Duplicate_global lookup
  matches in define, define_prim, declare_ind and define_ind's ctor
  loop.  Pure refactor, zero behavior change (suites + gates pin it).
- id 6 (NIT, lib/interp.ml): add_erased/add_prim record literals
  wrapped to match add_ctor's multi-line shape.
- id 7 (NIT, lib/prim.ml classification): one arm per rung;  the
  Stage A and Stage C constructors sat in separate same-rung arms.
- id 8 (LOW, surface/bootstrap.ml split_after_name): tail-recursive
  accumulator + one List.rev, replacing the Option.map-after-the-call
  shape that stacked a frame per item.
- id 12 (NIT, surface/lexer.ml): new Loc.advance n;  the 4/5-fold
  Loc.next_col chains for let*/let*! use it.

### Adjudications (no change, with reasons)

- id 2 (NIT, run_gate dedup helper in dev/gates.sh): NO CHANGE.
  Explicit per-gate predicates keep each gate independently
  falsifiable;  a shared helper hides the predicate behind an
  abstraction and turns a per-gate review into a helper-semantics
  review.  The duplication is the review surface, on purpose.
- id 13 (NIT, surface/lexer.ml scan_string list-vs-Buffer): NO
  CHANGE.  Cons-accumulation with one List.rev + String.of_seq is the
  house immutable-accumulator style (Buffer is a mutable structure);
  the cost is O(n) per string literal, lexed once, with small
  constants.  Style beats a nit-scale constant factor here.
- O2 (exe self-MD5 ~3.3ms of ~8ms warm hit): NO CHANGE to the
  mechanism (correctness first;  8ms total is acceptable hook
  latency).  SPEC.md section 6 now records the measured cost and the
  stat-identity fast path as possible M4 work.

### Opus findings

- O1 (surface/cache.ml cache_dir, HOME unset): FIXED.  cache_dir is
  now an option computed once per process;  with neither TOT_CACHE_DIR
  nor HOME the cache is DISABLED for the run (load misses, save
  no-ops) with exactly one stderr line, the same posture as the
  unreadable-executable branch, and NOTHING is ever written into the
  cwd.  load/save thread the directory through file_path.  The D2
  in-process test binds the option through Option.to_result.  New
  gate PASS-CACHE-NOHOME (scratch cwd, env -u HOME -u TOT_CACHE_DIR:
  exit 0, no .cache entry, one pinned stderr line).
- O2: adjudicated above;  SPEC.md section 6 sentence added.
- O3 (surface/cache.ml module doc): FIXED.  "all THREE" is now "all
  FOUR" (magic, version, body digest, exe digest since R1), and the
  never-a-crash claim is scoped to content produced WITHOUT write
  access to the cache directory, citing the trust-class paragraph and
  the SPEC section 6 residual.  The stale "all THREE" comment in
  dev/gates.sh's Gate D corruption block got the same correction.
- O4 (unreadable-executable branch untested): FIXED with new gate
  PASS-CACHE-NOEXEDIGEST: a chmod-111 COPY of the built binary runs a
  trivial script;  exit 0, exactly one stderr line, no blob written.
  First process-level coverage of exe_digest_hex = None.
- O5 (surface/run.ml comment + SPEC): FIXED.  The comment now says
  Interp.define is never called for user DEFS in check mode while
  data-ctor seeding (add_erased/add_ctor in the IData arm) is
  mode-independent and inert;  SPEC.md's R2 entry drops the "no
  runtime environment at all" parenthetical for the same wording, and
  the section 6 lazy-thunk bullet gains: laziness protects only defs
  that neither an eval item nor `main` transitively forces.

### Mutation confirmations (pre-fix transcripts, staged batch on a65321f)

stringSlice overflow (id 5), pre-fix:

    $ tot run slice-overflow.tot   # eval stringSlice "abc" (~3e18) (~3e18)
    Fatal error: exception Invalid_argument("String.sub / Bytes.sub")
    EXIT=2

post-fix the same script prints `none` / `none`, EXIT=0 (and surface
test C8d pins it).

guard bypass (id 3), pre-fix (payloads through examples/guard.tot):

    cmd=[ /usr/bin/grep foo /tmp/x] exit=0   (ALLOWED: the bypass)
    cmd=[ grep x]                   exit=0   (ALLOWED: the bypass)
    cmd=[/bin/sed -i s/a/b/ f]      exit=0   (ALLOWED: the bypass)

post-fix:

    cmd=[ /usr/bin/grep foo /tmp/x] exit=2   (denied)
    cmd=[ grep x]                   exit=2   (denied)
    cmd=[/bin/sed -i s/a/b/ f]      exit=2   (denied)
    cmd=[rg x]                      exit=0   (allowed)
    cmd=[ripgrep foo]               exit=0   (allowed)
    cmd=[grep foo]                  exit=2   (denied, unchanged)

HOME-unset cwd blob (O1), pre-fix (scratch cwd, env -u HOME -u
TOT_CACHE_DIR, x2-prelude-run.tot):

    (succ (succ (succ zero)))
    EXIT=0
    ./.cache/tot/prelude-f47e232ed9fd6cdc379b8594e5be63fe.bin  (8006 bytes, in the CWD)

post-fix, same invocation:

    (succ (succ (succ zero)))
    EXIT=0
    stderr: tot: prelude cache disabled for this run: neither TOT_CACHE_DIR nor HOME is set
    stderr-lines=1, no .cache entry

### Files touched

lib/interp.ml, lib/check.ml, lib/prim.ml, surface/cache.ml,
surface/effect.ml, surface/run.ml, surface/bootstrap.ml,
surface/lexer.ml, surface/loc.ml, examples/guard.tot,
test/surface.ml, test/fixtures/deny-path.json (new), dev/gates.sh,
dev/prim-lint.sh, SPEC.md.  New test: surface C8d.  New gates:
PASS-D-GUARD-DENY-PATH, PASS-CACHE-NOHOME, PASS-CACHE-NOEXEDIGEST.
No new Error/Serror variants.

### Gate battery

    dunecho build: OK build: 0 errors, 0 warnings
    test/main.exe: M0 kernel: all tests green (exit 0)
    test/surface.exe: M1 surface: all tests green (exit 0)
    zsh dev/gates.sh: GATE-EXIT=0, 165 PASS markers, no FAIL lines
    tail: ... PASS-D-CACHE-MAGIC PASS-CACHE-NOHOME PASS-CACHE-NOEXEDIGEST

## Round 4

2026-09-01, round-4 fix batch (sign-off findings).  This entry: the
guard's IFS-whitespace tokenization bypass.

### Finding (executed by the sign-off agent)

examples/guard.tot firstToken tokenized via stringSplit on the ASCII
space only, so a command whose first token hid behind a TAB, NEWLINE,
or CARRIAGE RETURN bypassed the grep/sed deny while sh still executed
it.  The space forms denied correctly.

### Fix

firstToken now tokenizes on all four shell IFS whitespace characters:
the space-split fragment list is re-split on tab, newline, and
carriage return in turn (new rec def splitEach: fold of stringSplit
over the fragments, concatenating the piece lists in order), then the
first NON-EMPTY fragment is taken and basenamed as before.  The doc
comment now states the IFS tokenization and that NBSP (U+00A0) is not
shell IFS whitespace and stays out of scope by design.

Prerequisite lexer verification (the plan said "the tot lexer
supports \t \n \r escapes in string literals: verify and use them"):
verification showed \t and \n present but \r MISSING (pre-fix,
`eval stringSplit "a\rb" "\r"` died with `unknown escape \r`).  Added
the [\r] case to surface/lexer.ml scan_string beside \t, mirroring
lib/interp.ml json_string_body which already decodes \r; doc comment
updated.  Surface test C8e pins the escape end to end as a split
separator.

Fixture note: the finding's example fixture command
"\t/usr/bin/grep -r x /" was ALREADY denied pre-fix (exit 2), because
baseName strips everything through the LAST '/' and the tab sits
before a '/'; as a mutation pin it would be vacuous.  deny-tab.json
instead carries "\t/usr/bin/grep\t-r x /" (leading tab AND tab as the
argument separator, path-qualified binary), verified ALLOWED exit 0
pre-fix, so the gate genuinely reaches the new tokenizer.

### Mutation confirmation (transcripts through examples/guard.tot's own shebang)

Pre-fix (staged batch on a65321f, this session):

    cmd=[\tgrep -r secret /]         exit=0 out=[]   (ALLOWED: the bypass)
    cmd=[\ngrep x]                   exit=0 out=[]   (ALLOWED: the bypass)
    cmd=[\rgrep x]                   exit=0 out=[]   (ALLOWED: the bypass)
    cmd=[grep\tx]                    exit=0 out=[]   (ALLOWED: the bypass)
    cmd=[\t/usr/bin/grep\t-r x /]    exit=0 out=[]   (ALLOWED: the fixture form)

Post-fix (same payloads, same shebang path):

    cmd=[\tgrep -r secret /]         exit=2 (denied, exact envelope)
    cmd=[\ngrep x]                   exit=2 (denied, exact envelope)
    cmd=[\rgrep x]                   exit=2 (denied, exact envelope)
    cmd=[grep\tx]                    exit=2 (denied, exact envelope)
    cmd=[\t/usr/bin/grep\t-r x /]    exit=2 (denied, exact envelope; deny-tab.json)
    cmd=[rg\tx]                      exit=0 out=[]   (allowed: the control)
    cmd=[rg x]                       exit=0 out=[]   (allowed, unchanged)

### Files touched

examples/guard.tot (splitEach + firstToken + doc comment),
surface/lexer.ml (\r escape + doc comment), test/surface.ml (new test
C8e), test/fixtures/deny-tab.json (new), dev/gates.sh (new gate
PASS-D-GUARD-DENY-TAB: fixture deny + inline "\ngrep x" and
"grep\tx" denies, each the exact one-line envelope at exit 2, plus
the "rg\tx" allow control at exit 0 with empty stdout).  No new
Error/Serror variants.

### Gate battery

    dunecho build: OK build: 0 errors, 0 warnings
    test/main.exe: M0 kernel: all tests green (exit 0)
    test/surface.exe: M1 surface: all tests green (exit 0)
    zsh dev/gates.sh: GATE-EXIT=0, 167 PASS markers, no FAIL lines
    (one new echo site vs the staged battery: PASS-D-GUARD-DENY-TAB)
    tail: ... PASS-D-CACHE-MAGIC PASS-CACHE-NOHOME PASS-CACHE-NOEXEDIGEST
