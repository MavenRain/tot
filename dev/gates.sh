#!/bin/zsh
# no set -u: the user's chpwd hook reads CARGO_TARGET_DIR unguarded
# M3 fixes round 2 (ctxcat ids 3+4): the repo root derives from this
# script's own location, so the whole gate battery works from any
# checkout path and any cwd. M3 fixes round 3 (ctxcat id 1): a
# symlinked $0 resolves to its REAL path first (readlink -f, plain-$0
# fallback where readlink -f is unavailable), so a PATH-shim symlink
# cannot silently point ROOT at the wrong tree.
ROOT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)" || exit 9
cd "$ROOT" || exit 9
dunecho build; b=$?
[ "$b" -eq 0 ] && echo BUILD-OK || { echo BUILD-FAIL; exit "$b"; }
# Watchdog probe, FIRST (M3 fixes round 3, ctxcat id 16; it sat after
# the Gate A/B lead-in, so the two suites and every gate before Gate B
# (iii) ran unbounded, and a hang there blanked the battery forever):
# every dune exec below runs under it. GNU coreutils' `timeout` ships
# as `gtimeout` on stock macOS.
watchdog=""
if command -v timeout > /dev/null 2>&1; then watchdog=timeout
elif command -v gtimeout > /dev/null 2>&1; then watchdog=gtimeout
fi
if [ -z "$watchdog" ]; then
  echo "FAIL-WATCHDOG (no timeout/gtimeout on PATH)"
  exit 1
fi
# M5 Stage D (design pin 17): named watchdog tiers. Every leg names
# a tier. No numeric watchdog literal survives in this file, which
# PASS-M5D-TIERS asserts on EXIT STATUS.
#
# A tier is a HANG ceiling, not a performance budget. Pin 9 keeps
# the external timeout as the belt over one pathological Eval or
# Conv call; the tiers are the same belt inside the battery. A leg
# that creeps from 1s to 9s stays green at FAST and shows up in the
# measurement log instead, which is what gate_timed is for.
#
#   FAST  a leg that must finish well under a second.
#   MED   a leg that runs the CLI more than once, or over a fixture.
#   SLOW  a perf leg with a measured runtime in SPEC section 6.
#   SUITE one of the two test executables.
#
# BITE_S is NOT a leg budget. It is the calibration constant that
# PASS-M5D-TIER-BITES uses to prove the watchdog machinery still
# cuts at the value a tier names. Nothing else may use it.
FAST=10
MED=30
SLOW=120
SUITE=300
BITE_S=1
# M5 Stage D (verdict item 6): per-leg measurement. gate_timed runs
# ONE leg under a named tier, records elapsed wall time, and
# forwards the leg's own stdout and exit code unchanged. It adds no
# policy: a leg that was green stays green, and a leg that was red
# stays red with the same output.
#
# 2026-09-03 (M5 review round): one adjudicated exception to the
# next rule.  The two SUITE legs (SUITE-KERNEL, SUITE-SURFACE) had
# no 2>&1 before Stage D; wrapping them in gate_timed added the
# merge.  Accepted: the suite PASS oracles match whole lines, dune
# writes no stderr on a warm build, and the Stage D whole-output
# diff was adjudicated additions-only with the merge in place.
#
# Wrap ONLY a leg that already merges stderr into stdout (2>&1); the
# merge moves inside gate_timed. The prelude legs and the M5C budget
# legs split the two channels on purpose (byte-exact stderr oracles)
# and must stay unwrapped; wrapping one would merge a channel the B4
# channel rule keeps apart.
typeset -F SECONDS
GATE_LOG="${TOT_GATE_LOG:-${TMPDIR:-/tmp}/tot-gate-measure.log}"
: > "$GATE_LOG" || exit 9
gate_timed() {
  local tier="$1"
  local name="$2"
  shift 2
  local t0=$SECONDS
  local out
  out=$("$watchdog" "$tier" "$@" 2>&1)
  local code=$?
  printf 'MEASURE %s tier=%s elapsed=%.3f exit=%d\n' \
    "$name" "$tier" "$((SECONDS - t0))" "$code" >> "$GATE_LOG"
  printf '%s' "$out"
  return $code
}
# dunecho test reports "0 run" on these custom runners (vacuous-pass trap):
# run the test executables directly and require BOTH to exit 0.
# M4 fixes round 5 (ctxcat r5 id 16): the kernel suite's watchdog is 300,
# not 120. D9 resolves a 256-leaf query against an 8-binder instance and
# Eval.eval re-walks each resolved dictionary once per occurrence, so the
# case costs 14 to 24s on its own and the whole suite runs 15 to 25s
# against the 1s it took before. 300 keeps this a HANG detector (about
# 12x the observed runtime) instead of a performance gate that flakes on
# ambient load, which is the exact failure PASS-M4FIX-INST-BRANCHING hit
# in round 4.
main_out=$(gate_timed "$SUITE" SUITE-KERNEL dune exec --root "$ROOT" test/main.exe); t1=$?
printf '%s\n' "$main_out"
surface_out=$(gate_timed "$SLOW" SUITE-SURFACE dune exec --root "$ROOT" test/surface.exe); t2=$?
printf '%s\n' "$surface_out"
{ [ "$t1" -eq 0 ] && [ "$t2" -eq 0 ]; } && echo TEST-OK || { echo TEST-FAIL; exit 1; }
# M3 Stage A gate (iv): stringConcat and intAdd compute correctly in
# run mode. bin/tot.ml has no prelude/bootstrap auto-load yet (Stage D,
# D1), so examples/literals.tot cannot run through the plain `tot run`
# CLI until then; this checks the SAME computation, pinned exactly by
# test/surface.ml's A9/A10 cases (Run.script seeded by
# Bootstrap.state ()), by requiring both PASS lines in the surface
# suite's own captured output above. See examples/literals.tot.
printf '%s\n' "$surface_out" | rg -q '^PASS A9: eval stringConcat computes$' \
  && printf '%s\n' "$surface_out" | rg -q '^PASS A10: eval intAdd computes$' \
  && echo PASS-A-LITERALS || { echo FAIL-A-LITERALS; exit 1; }
# M2 script gates: the prelude and both examples must check AND run.
# Success stays quiet (markers only); a failure replays the captured
# output, where the CLI prints its error, then exits 1.
#
# M3 Stage C: stdlib/prelude.tot is no longer independently checkable
# via bare, unbootstrapped bin/tot.exe (Run.initial has no
# String/Int/Div/IO/stringEq; bin/tot.ml stays unbootstrapped until
# Stage D's D1), and folding it a SECOND time through gate-check/
# gate-run would double-define every global (Bootstrap.state () folds
# it internally). The CHECK marker comes from test/surface.exe's
# "bootstrap-only" mode (see its doc comment): checking the prelude
# and bootstrapping are the same operation.
#
# M3 fixes, A3 (C15): the RUN marker is no longer a copy of the same
# exit code. It executes a prelude rec (`add`) applied to canonical
# Nat data in run mode through gate-run and pins the exact computed
# readback, so an Interp exec/force/quote fault in a prelude def that
# type-checks fine but explodes at execution time turns this marker
# red (the regression class the old duplicated marker missed).
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- bootstrap-only 2>&1)
[ $? -eq 0 ] && echo PASS-CHECK-PRELUDE \
  || { printf '%s\n' "$out"; echo FAIL-CHECK-PRELUDE; exit 1; }
# M3 fixes round 3 (ctxcat id 17): stdout is captured ALONE and the
# pinned line is matched per-line (rg -qx), so a benign stderr byte (a
# dune notice, the R1 cache-disabled line) cannot turn a semantically
# green run red; stderr goes to a temp file for the failure replay.
prelude_err=$(mktemp "${TMPDIR:-/tmp}/tot-gate-prelude-run-err.XXXXXX")
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x2-prelude-run.tot 2> "$prelude_err")
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx '\(succ \(succ \(succ zero\)\)\)'; } \
  && { rm -f "$prelude_err"; echo PASS-RUN-PRELUDE; } \
  || { printf '%s\n' "$out"; cat "$prelude_err"; rm -f "$prelude_err"; echo "FAIL-RUN-PRELUDE (exit=$code)"; exit 1; }
# M3 fixes round 2 (ctxcat id 0): a prelude BOOTSTRAP failure reports
# on STDERR and leaves stdout EMPTY (the B4 channel rule: stdout is
# the hook protocol's channel and must carry only a rendered
# decision), exit 1. Pre-fix the "prelude: ..." line landed on stdout
# (recorded in dev/M3-FIXES-LOG.md). M3 fixes round 3 (ctxcat id 0):
# exit code, stdout AND stderr all come from ONE invocation (stderr
# via a temp file), so the marker can no longer pass or fail on a
# divergence between two separate runs of the same failing bootstrap.
berr_file=$(mktemp "${TMPDIR:-/tmp}/tot-gate-prelude-err.XXXXXX")
bout=$(TOT_PRELUDE="$ROOT/nonexistent-prelude.tot" "$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/examples/church.tot 2> "$berr_file")
bcode=$?
berr=$(cat "$berr_file")
rm -f "$berr_file"
{ [ "$bcode" -eq 1 ] && [ -z "$bout" ] && printf '%s\n' "$berr" | rg -q '^prelude: '; } \
  && echo PASS-PRELUDE-ERR-STDERR \
  || { printf '%s\n' "$berr"; echo "FAIL-PRELUDE-ERR-STDERR (exit=$bcode stdout=[$bout])"; exit 1; }
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/examples/church.tot 2>&1)
[ $? -eq 0 ] && echo PASS-CHECK-CHURCH || { printf '%s\n' "$out"; echo FAIL-CHECK-CHURCH; exit 1; }
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/examples/church.tot 2>&1)
[ $? -eq 0 ] && echo PASS-RUN-CHURCH || { printf '%s\n' "$out"; echo FAIL-RUN-CHURCH; exit 1; }
# M3 Stage D, D1: bin/tot.exe now auto-loads the prelude by default
# (Bootstrap.cached_state ()); examples/nat.tot is a kernel-test-style
# script that declares its OWN "data Nat" from scratch, which would
# otherwise collide with the prelude's own "Nat" (Duplicate_global).
# --no-prelude (decision 14) keeps it on the bare M2-only environment,
# exactly as before this stage.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check --no-prelude "$ROOT"/examples/nat.tot 2>&1)
[ $? -eq 0 ] && echo PASS-CHECK-NAT || { printf '%s\n' "$out"; echo FAIL-CHECK-NAT; exit 1; }
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- run --no-prelude "$ROOT"/examples/nat.tot 2>&1)
[ $? -eq 0 ] && echo PASS-RUN-NAT || { printf '%s\n' "$out"; echo FAIL-RUN-NAT; exit 1; }
echo SCRIPTS-OK
# M3 Stage B gate (process level, because these are OS-observed): the
# effect ladder end to end, via test/surface.exe's OWN gate-check /
# gate-run argv mode (bin/tot.ml stays unbootstrapped until Stage D,
# D1 -- see test/surface.ml's run_gate doc comment for why this
# binary, not bin/tot.exe, drives these three fixtures).
#
# Gate B (i): a script whose main chains three real bindIO steps over
# a stdin fixture; the process's OWN exit code is
# exitWith (stringLength raw), fed "hello\n" (6 bytes) via a
# here-doc, so a pass proves real sequencing occurred, not a
# hardcoded constant.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/b-stdin-chain.tot <<'EOF'
hello
EOF
)
code=$?
[ "$code" -eq 6 ] && echo PASS-B-EXITCODE \
  || { printf '%s\n' "$out"; echo "FAIL-B-EXITCODE (got $code, want 6)"; exit 1; }
# Gate B (ii), the constraint-1 test: `tot check` on a script whose
# `main` prints a sentinel line performs NO I/O; `tot run` performs it
# for real. Stage B's prim catalog has no writeFile yet (Stage C's C1
# adds one), so this observes the distinction through captured
# process stdout: both invocations redirect to the SAME path, so the
# only variable across them is check vs run, never the shell
# scripting around them.
# M3 fixes round 3 (ctxcat id 15): the mktemp-created file is KEPT and
# reused (the `>` redirect truncates it in place); the old rm-then-
# recreate left the predictable path unowned between gates, a symlink
# TOCTOU window on a shared /tmp fallback.
sentinel=$(mktemp "${TMPDIR:-/tmp}/tot-gate-b-sentinel.XXXXXX")
"$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/b-sentinel.tot > "$sentinel" 2>&1
c1=$?
{ [ "$c1" -eq 0 ] && ! rg -q 'SENTINEL-WRITTEN' "$sentinel"; } \
  || { cat "$sentinel"; echo FAIL-B-NOEFFECT; rm -f "$sentinel"; exit 1; }
"$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/b-sentinel.tot > "$sentinel" 2>&1
c2=$?
{ [ "$c2" -eq 0 ] && rg -qx 'SENTINEL-WRITTEN' "$sentinel"; } && echo PASS-B-NOEFFECT \
  || { cat "$sentinel"; echo FAIL-B-NOEFFECT; rm -f "$sentinel"; exit 1; }
rm -f "$sentinel"
# Gate B (iii): a Div-headed def built from a deliberately expensive
# prim (test/fixtures/b-deferred-div.tot; its header comment records
# the exact construction and its empirically measured forced cost,
# ~66s on the build machine) leaves `tot check` fast. The 5s bound is
# deliberately coarse: this pins the deferred rule holding at all, not
# performance tuning. M3 fixes round 2 (ctxcat ids 1+20): the command
# runs UNDER the watchdog probed above, so a deferral regression fails
# fast (exit 124) instead of paying the full ~66s forced cost (or
# hanging the whole battery); the elapsed check stays as the tighter
# in-bound assertion.
t0=$(date +%s)
"$watchdog" "$FAST" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/b-deferred-div.tot > /dev/null 2>&1
c3=$?
t1=$(date +%s)
elapsed=$((t1 - t0))
{ [ "$c3" -eq 0 ] && [ "$elapsed" -le 5 ]; } && echo PASS-B-DEFERRED \
  || { echo "FAIL-B-DEFERRED (exit=$c3 elapsed=${elapsed}s)"; exit 1; }

# M3 fixes, A2 (C17): memoized deferred forcing. A chain of 8
# Div-headed defs each referencing the previous twice over a ~0.6s
# regexTest base (test/fixtures/x3-div-chain.tot, header comment has
# the construction) runs in ~1s memoized; unmemoized forcing
# re-executes the base 2^8 = 256 times, ~150s (pre-fix run recorded
# in dev/M3-FIXES-LOG.md: exit 124 under a 10s watchdog). Requires
# exit 0, the pinned computed line, AND the coarse 5s bound.
t0=$(date +%s)
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x3-div-chain.tot 2>&1)
c4=$?
t1=$(date +%s)
elapsed=$((t1 - t0))
{ [ "$c4" -eq 0 ] && [ "$elapsed" -le 5 ] && printf '%s\n' "$out" | rg -qx 'false'; } \
  && echo PASS-B-DIV-MEMO \
  || { printf '%s\n' "$out"; echo "FAIL-B-DIV-MEMO (exit=$c4 elapsed=${elapsed}s)"; exit 1; }

# M3 fixes, A1 (O1 CRITICAL + C14): check mode never executes user def
# bodies, so a Div computation nested under a PURE type head (the
# exact O1 repro: `def boom : Option (Div Nat) := some (Div Nat)
# (spin zero)`, test/fixtures/x1-nested-div.tot) can no longer make
# `tot check` diverge. Requires exit 0 under the watchdog; exit 124
# is a FAIL (pre-fix this same command exited 124, recorded in
# dev/M3-FIXES-LOG.md as the mutation confirmation).
"$watchdog" "$FAST" dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/x1-nested-div.tot > /dev/null 2>&1
c5=$?
[ "$c5" -eq 0 ] && echo PASS-CHECK-NESTED-DIV \
  || { echo "FAIL-CHECK-NESTED-DIV (exit=$c5)"; exit 1; }

# M3 fixes round 2, R2: run mode stores EVERY user def as a lazy
# memoized thunk, so DEAD code (a def main never mentions) can neither
# abort nor hang a guard. Pre-fix (recorded in dev/M3-FIXES-LOG.md as
# the mutation confirmation): the abort fixture exited 1 (malformed
# regex = ask) and the hang fixture exited 124 under the watchdog.
# Both must now exit 0 with an EMPTY stdout envelope (allow prints
# nothing); stderr is discarded so a dune status line cannot leak in.
out=$("$watchdog" "$FAST" dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/test/fixtures/x12-dead-abort.tot 2> /dev/null)
cda=$?
{ [ "$cda" -eq 0 ] && [ -z "$out" ]; } && echo PASS-RUN-DEADCODE-ABORT \
  || { printf '%s\n' "$out"; echo "FAIL-RUN-DEADCODE-ABORT (exit=$cda)"; exit 1; }
out=$("$watchdog" "$FAST" dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/test/fixtures/x13-dead-hang.tot 2> /dev/null)
cdh=$?
{ [ "$cdh" -eq 0 ] && [ -z "$out" ]; } && echo PASS-RUN-DEADCODE-HANG \
  || { printf '%s\n' "$out"; echo "FAIL-RUN-DEADCODE-HANG (exit=$cdh)"; exit 1; }

# M3 fixes, B4 (C10): exitWith outside 0..255 is a runtime script
# error with its message on STDERR (stdout is the hook protocol's
# channel) and process exit 1, never a silent OS-level wrap (pre-fix:
# exitWith 300 exited 44, recorded in dev/M3-FIXES-LOG.md). The
# capture below keeps stderr ONLY, so the marker also pins the
# message's stream.
err_out=$(dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/test/fixtures/x4-exit-range.tot 2>&1 1>/dev/null)
code=$?
{ [ "$code" -eq 1 ] && printf '%s\n' "$err_out" | rg -q 'exit code out of range 0\.\.255'; } \
  && echo PASS-B-EXITRANGE \
  || { printf '%s\n' "$err_out"; echo "FAIL-B-EXITRANGE (exit=$code)"; exit 1; }

# M3 Stage C gate (dev/gates.sh's own share: C7 tests 9-11), plus the
# PASS-C-JSON / PASS-C-POSITIVITY markers, derived from
# test/surface.exe's own C5/C6 PASS lines (already captured in
# $surface_out above), the exact PASS-A-LITERALS style.
printf '%s\n' "$surface_out" | rg -q '^PASS C5: ' \
  && echo PASS-C-JSON || { echo FAIL-C-JSON; exit 1; }
printf '%s\n' "$surface_out" | rg -q '^PASS C6: ' \
  && echo PASS-C-POSITIVITY || { echo FAIL-C-POSITIVITY; exit 1; }
#
# Gate C (iii): procRun on /bin/echo populates all three
# ProcessResult fields; pin the exit code 0, the stdout text (echo's
# own trailing newline plus printLine's), and the empty stderr.
out=$(dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/c-procrun.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] \
  && printf '%s\n' "$out" | rg -qx 'CODE=0' \
  && printf '%s\n' "$out" | rg -qx 'OUT=tot-gate-c' \
  && printf '%s\n' "$out" | rg -qx 'ERR=' ; } \
  && echo PASS-C-PROC || { printf '%s\n' "$out"; echo "FAIL-C-PROC (exit=$code)"; exit 1; }

# M3 fixes, B3 (C16 + C8): procRun captures via temp files, so a child
# writing 300000 bytes to stderr (far past any pipe buffer) completes
# and returns the FULL stderr (pre-fix: the sequential pipe drain
# deadlocked forever; exit 124 under a 10s watchdog, recorded in
# dev/M3-FIXES-LOG.md), and a spawn of a nonexistent binary returns
# the cannot-exec sentinel triple cleanly (the in-process B3 suite
# case pins the no-descriptor-growth half).
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x8-proc-bigstderr.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] \
  && printf '%s\n' "$out" | rg -qx 'CODE=0' \
  && printf '%s\n' "$out" | rg -qx 'ERRLEN=300000' ; } \
  && echo PASS-C-PROC-BIGSTDERR \
  || { printf '%s\n' "$out"; echo "FAIL-C-PROC-BIGSTDERR (exit=$code)"; exit 1; }
out=$(dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x9-proc-noexec.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'CODE=-1' ; } \
  && echo PASS-C-PROC-NOEXEC \
  || { printf '%s\n' "$out"; echo "FAIL-C-PROC-NOEXEC (exit=$code)"; exit 1; }

# Gate C (iv): regexMatch runs a benign fixture (pinned captures: the
# whole match plus its two groups); the pathological fixture is then
# exercised ONCE PER MODE below with different falsifiable assertions
# (M3 fixes, A3 / O5 + C18: the old single line accepted exit 0 AND
# exit 124, so it could never fail).
out=$(dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/c-regex-benign.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] \
  && printf '%s\n' "$out" | rg -qx 'user@host' \
  && printf '%s\n' "$out" | rg -qx 'user' \
  && printf '%s\n' "$out" | rg -qx 'host' ; } \
  && echo PASS-C-REGEX-BENIGN || { printf '%s\n' "$out"; echo "FAIL-C-REGEX-BENIGN (exit=$code)"; exit 1; }
# M3 fixes, B1 (O2 + C19): the group counter is a state machine that
# agrees with Str's own dialect, so a `\(` inside a class or after an
# escaped backslash opens NOTHING (pre-fix: one phantom group, and
# Str.matched_group killed the process with an uncaught
# Invalid_argument, exit 2 -- recorded in dev/M3-FIXES-LOG.md); and a
# genuinely malformed pattern is a DISTINCT runtime error
# (Regex_bad_pattern, exit 1), never the silent no-match a benign
# miss produces (pre-fix: `false`, exit 0, the fail-open shape).
out=$(dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x5-regex-class.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] && [ "$out" = '(some ((cons "(x") nil))' ]; } \
  && echo PASS-C-REGEX-CLASS \
  || { printf '%s\n' "$out"; echo "FAIL-C-REGEX-CLASS (exit=$code)"; exit 1; }
bs64=$(printf '\\%.0s' {1..64})
out=$(dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x6-regex-backslashes.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] && [ "$out" = "(some ((cons \"${bs64}(\") nil))" ]; } \
  && echo PASS-C-REGEX-BACKSLASHES \
  || { printf '%s\n' "$out"; echo "FAIL-C-REGEX-BACKSLASHES (exit=$code)"; exit 1; }
out=$(dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x7-regex-badpattern.tot 2>&1)
code=$?
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q 'malformed regex pattern' ; } \
  && echo PASS-C-REGEX-BADPATTERN \
  || { printf '%s\n' "$out"; echo "FAIL-C-REGEX-BADPATTERN (exit=$code)"; exit 1; }
# CHECK mode on the pathological fixture must be FAST and exit 0:
# after the A1 fix, check mode builds no runtime environment for the
# user file and never fires any prim, so a watchdog kill here is a
# REGRESSION (exit 124 is a FAIL), exactly what the old
# accept-both-outcomes line could not detect.
"$watchdog" "$FAST" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/c-regex-pathological.tot > /dev/null 2>&1
pcode=$?
[ "$pcode" -eq 0 ] && echo PASS-C-REGEX-PATHOLOGICAL \
  || { echo "FAIL-C-REGEX-PATHOLOGICAL (exit=$pcode, want 0: check must not run the regex)"; exit 1; }
# RUN mode is where the watchdog acceptance lives, and it is REQUIRED:
# the fixture's 35-'a' input exceeds the 5s bound by orders of
# magnitude on this machine (its header comment records the
# measurement), so run mode must be killed by the watchdog (exit 124).
# Completing quickly with any verdict would mean regexTest no longer
# actually runs the pathological pattern (C18's silent-swallow
# regression) and is a FAIL. The Div classification stays provenance,
# never a termination proof: run mode hanging without the external
# watchdog is exactly why the wrapper exists.
"$watchdog" "$FAST" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/c-regex-pathological.tot > /dev/null 2>&1
rcode=$?
[ "$rcode" -eq 124 ] && echo PASS-C-REGEX-PATHOLOGICAL-RUN \
  || { echo "FAIL-C-REGEX-PATHOLOGICAL-RUN (exit=$rcode, want 124: the pathological regex must actually run)"; exit 1; }
echo PASS-C-REGEX

# Gate C (v): a partial def rec whose body fails the structural guard
# is admitted only with the keyword and only with a Div-headed
# codomain, and reducible+partial is a checked error; test/main.exe's
# C1-C3 (captured in $main_out above) cover exactly this.
printf '%s\n' "$main_out" | rg -q '^PASS C1: ' \
  && printf '%s\n' "$main_out" | rg -q '^PASS C2: ' \
  && printf '%s\n' "$main_out" | rg -q '^PASS C3: ' \
  && echo PASS-C-PARTIAL || { echo FAIL-C-PARTIAL; exit 1; }

# Gate C (vi) / C6: the prim catalog review surface. M3 fixes round 2
# (ctxcat id 2): capture and replay, matching every other gate's
# capture-then-print-on-failure shape; the PASS-C-PRIMLINT marker's
# ONE emission point stays inside prim-lint.sh (on success the replay
# below is exactly that marker line, since the script prints nothing
# else on its success path).
out=$("$ROOT"/dev/prim-lint.sh 2>&1)
pcode2=$?
[ "$pcode2" -eq 0 ] || { printf '%s\n' "$out"; exit 1; }
printf '%s\n' "$out"

# M3 fixes, C4' (C13): a malformed subcommand to the surface test
# harness (here gate-check with its path missing) is a usage error,
# exit 2 with a message, never a silent fallback to the full suite
# that would mask a broken gate invocation as a green run.
out=$(dune exec --root "$ROOT" test/surface.exe -- gate-check 2>&1); acode=$?
{ [ "$acode" -eq 2 ] && printf '%s\n' "$out" | rg -q '^unknown subcommand: gate-check$'; } \
  && echo PASS-C-ARGV-USAGE \
  || { printf '%s\n' "$out"; echo "FAIL-C-ARGV-USAGE (exit=$acode)"; exit 1; }

# M3 Stage D gate: prelude auto-load, shebang, cache, the ported guard.
#
# Install a standalone `tot` into a scratch dir (D5: "install it into
# a scratch directory with dune build plus a copy, and put that
# directory first on PATH"), so the shebang line, the prelude
# auto-load (D1) and the elaboration cache (D2) are ALL on the tested
# path, not just `dune exec`. TOT_PRELUDE is set explicitly: a flat
# copy sits outside _build/default/bin's known relative layout, so
# Bootstrap.default_prelude_path's "two directories up from the
# executable" heuristic does not resolve from a copy (a plan-detail
# fill-in recorded in dev/M3-BUILD-LOG.md) -- exactly the case D1
# built the TOT_PRELUDE override for.
tot_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-d-bin.XXXXXX")
# M3 fixes round 2 (ctxcat id 22): an EXIT trap cleans BOTH scratch
# dirs on every path out of the script (the nine Gate D failure exits
# included), so red runs no longer accumulate scratch dirs in TMPDIR.
# Single quotes: $cache_scratch resolves at exit time, after its own
# mktemp below.
# M5 Stage C: the M5C scratch (generated chains/classes fixtures)
# rides the same trap; $m5c_scratch resolves at exit time, empty and
# harmless on any exit before its own mktemp below.
trap 'rm -rf "$tot_scratch" "$cache_scratch" "$m5c_scratch" "$m5d_scratch" "$m5e_scratch" "$m6c_scratch" "$m6d_scratch" "$m7a_scratch" "$m7c_scratch"' EXIT
cp "$ROOT"/_build/default/bin/tot.exe "$tot_scratch/tot"
# M3 fixes, C4' (C0, 2026-09-01): chmod ONLY the scratch copy; the
# tracked examples/guard.tot carries its own executable bit in the
# working tree (set once, rides the next staging), so a gate run
# never mutates a tracked file's mode.
chmod +x "$tot_scratch/tot"
export PATH="$tot_scratch:$PATH"
export TOT_PRELUDE="$ROOT"/stdlib/prelude.tot
guard="$ROOT"/examples/guard.tot
fx="$ROOT"/test/fixtures

# Gate D (i): allow / deny / a non-Bash fixture, exact exit code and
# exact stdout, run through the guard's OWN shebang (not `dune exec`).
out=$("$guard" < "$fx/allow.json"); code=$?
{ [ "$code" -eq 0 ] && [ -z "$out" ]; } && echo PASS-D-GUARD-ALLOW \
  || { printf '%s\n' "$out"; echo "FAIL-D-GUARD-ALLOW (exit=$code)"; exit 1; }

out=$("$guard" < "$fx/deny.json"); code=$?
# M5 Stage D (plan D3): the deny reason now echoes the blocked
# command (bounded at 2000 bytes, quoted by the Stage A JSON
# escaper), so the expected envelope is per-payload.  Raw TAB,
# NEWLINE and CR in a command arrive on the wire as their two-
# character escapes; the single-quoted strings below carry those
# backslashes literally.
want='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo /tmp/x)"}}'
want_path='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command:  /usr/bin/grep foo /tmp/x)"}}'
want_tab='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: \t/usr/bin/grep\t-r x /)"}}'
want_nl='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: \ngrep x)"}}'
want_ts='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep\tx)"}}'
{ [ "$code" -eq 2 ] && [ "$out" = "$want" ]; } && echo PASS-D-GUARD-DENY \
  || { printf '%s\n' "$out"; echo "FAIL-D-GUARD-DENY (exit=$code)"; exit 1; }

# M3 fixes round 3 (ctxcat id 3): a PATH-QUALIFIED banned binary
# behind a LEADING SPACE (" /usr/bin/grep foo /tmp/x") is still
# denied: the guard compares the BASENAME of the first NON-EMPTY
# token. Pre-fix this payload was ALLOWED, exit 0 (both bypass shapes
# recorded in dev/M3-FIXES-LOG.md).
out=$("$guard" < "$fx/deny-path.json"); code=$?
{ [ "$code" -eq 2 ] && [ "$out" = "$want_path" ]; } && echo PASS-D-GUARD-DENY-PATH \
  || { printf '%s\n' "$out"; echo "FAIL-D-GUARD-DENY-PATH (exit=$code)"; exit 1; }

# M3 fixes round 4 (sign-off finding): firstToken split on the SPACE
# only, so a banned binary hidden behind TAB, NEWLINE, or CARRIAGE
# RETURN (the other shell IFS whitespace) bypassed the deny while sh
# still executed it.  The tokenizer now splits on all four IFS
# characters.  deny-tab.json pairs a leading tab with a path-qualified
# binary AND a tab argument separator (the finding's bare
# "\t/usr/bin/grep -r x /" was already denied pre-fix: baseName strips
# through the LAST '/', absorbing the tab); the inline payloads pin
# the newline and tab-separator deny forms plus one allow control.
# Pre/post transcripts in dev/M3-FIXES-LOG.md, Round 4.
out=$("$guard" < "$fx/deny-tab.json"); code=$?
out_nl=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"\ngrep x"}}' | "$guard"); code_nl=$?
out_ts=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"grep\tx"}}' | "$guard"); code_ts=$?
out_ok=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"rg\tx"}}' | "$guard"); code_ok=$?
{ [ "$code" -eq 2 ] && [ "$out" = "$want_tab" ] \
  && [ "$code_nl" -eq 2 ] && [ "$out_nl" = "$want_nl" ] \
  && [ "$code_ts" -eq 2 ] && [ "$out_ts" = "$want_ts" ] \
  && [ "$code_ok" -eq 0 ] && [ -z "$out_ok" ]; } \
  && echo PASS-D-GUARD-DENY-TAB \
  || {
    printf '%s\n%s\n%s\n%s\n' "$out" "$out_nl" "$out_ts" "$out_ok"
    echo "FAIL-D-GUARD-DENY-TAB (exit=$code/$code_nl/$code_ts/$code_ok)"
    exit 1
  }

# other.json (non-Bash) and garbage.json (a malformed payload) both
# fail open (D5's own posture, matching the live hooks): exit 0, empty
# stdout. The plan names no separate garbage.json marker, so both are
# folded into the one PASS-D-GUARD-OTHER check.
out=$("$guard" < "$fx/other.json"); code=$?
out2=$("$guard" < "$fx/garbage.json"); code2=$?
{ [ "$code" -eq 0 ] && [ -z "$out" ] && [ "$code2" -eq 0 ] && [ -z "$out2" ]; } \
  && echo PASS-D-GUARD-OTHER \
  || {
    printf '%s\n%s\n' "$out" "$out2"
    echo "FAIL-D-GUARD-OTHER (exit=$code/$code2)"
    exit 1
  }

# M3 fixes, C1' (O4): main is a RESERVED driver name. A main whose
# type converts to neither IO Verdict nor IO Unit is a script error
# in BOTH modes (pre-fix: silent exit 0 in both, the permit-all
# shape), and the run-mode fixture's printLine effect must never
# fire. The misspelled-main fixture pins the DOCUMENTED residual
# (SPEC section 6): an ordinary def named mian, script mode, exit 0.
# M3 fixes round 2 (ctxcat id 18): "$watchdog", never bare `timeout`
# (which is gtimeout-only on stock macOS and would 127 every check).
out=$("$watchdog" "$FAST" "$tot_scratch/tot" check "$fx/x10-main-bad-type.tot" 2>&1); mc1=$?
out2=$("$watchdog" "$FAST" "$tot_scratch/tot" run "$fx/x10-main-bad-type.tot" 2>&1); mc2=$?
{ [ "$mc1" -eq 1 ] && [ "$mc2" -eq 1 ] \
  && printf '%s\n' "$out" | rg -q 'main is a reserved driver name' \
  && printf '%s\n' "$out2" | rg -q 'main is a reserved driver name' \
  && ! { printf '%s\n' "$out2" | rg -q 'THIS EFFECT NEVER HAPPENS'; }; } \
  && echo PASS-D-MAIN-BADTYPE \
  || { printf '%s\n%s\n' "$out" "$out2"; echo "FAIL-D-MAIN-BADTYPE (exit=$mc1/$mc2)"; exit 1; }

out=$("$watchdog" "$FAST" "$tot_scratch/tot" run "$fx/x11-main-misspelled.tot" 2>&1); mc3=$?
{ [ "$mc3" -eq 0 ] && printf '%s\n' "$out" | rg -q '^def mian : \(IO Verdict\)$'; } \
  && echo PASS-D-MAIN-MISSPELLED \
  || { printf '%s\n' "$out"; echo "FAIL-D-MAIN-MISSPELLED (exit=$mc3)"; exit 1; }

# Gate D (ii): the cache hits on a second invocation (TOT_CACHE_VERIFY=1
# recomputes cold and compares its Marshal bytes against the cached
# blob's, printing TOT-CACHE-VERIFY-OK on a match) and degrades
# silently to a miss (never a crash) on a truncated cache file.
# TOT_CACHE_DIR isolates this from the real ~/.cache/tot (a Stage D
# test-isolation fill-in, surface/cache.ml's own doc comment).
cache_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-d-cache.XXXXXX")
export TOT_CACHE_DIR="$cache_scratch"
"$guard" < "$fx/allow.json" > /dev/null 2>&1
c1=$?
cache_file=$(command ls "$cache_scratch"/prelude-*.bin 2> /dev/null | head -n1)
verify_out=$(TOT_CACHE_VERIFY=1 "$guard" < "$fx/allow.json" 2>&1 1>/dev/null)
c2=$?
{
  [ "$c1" -eq 0 ] && [ "$c2" -eq 0 ] && [ -n "$cache_file" ] \
    && printf '%s\n' "$verify_out" | rg -qx 'TOT-CACHE-VERIFY-OK'
} && echo PASS-D-CACHE-HIT \
  || { printf '%s\n' "$verify_out"; echo FAIL-D-CACHE-HIT; exit 1; }

head -c 5 "$cache_file" > "$cache_file.trunc"
mv "$cache_file.trunc" "$cache_file"
out=$("$guard" < "$fx/allow.json"); c3=$?
{ [ "$c3" -eq 0 ] && [ -z "$out" ]; } && echo PASS-D-CACHE-MISS \
  || { printf '%s\n' "$out"; echo "FAIL-D-CACHE-MISS (exit=$c3)"; exit 1; }

# M3 fixes, B2 (O3 + C7; round 3, O3: FOUR fields since round 2's R1
# added the writing binary's own digest): the blob carries magic +
# format_version + an MD5 digest of the body + the exe digest, and
# load verifies all FOUR before any byte reaches Marshal.from_string,
# so corruption is a silent MISS.
# Pre-fix (recorded in dev/M3-FIXES-LOG.md): a bit-flipped body
# SEGFAULTED the guard (exit 139) and a body-truncated one died on an
# uncaught Invalid_argument (exit 2). Each check re-warms the cache
# (the miss run above already re-saved), corrupts deterministically,
# and requires a clean allow (exit 0, empty stdout).
#
# M3 fixes round 2 (ctxcat id 19): a corruption assertion identical to
# an intact hit's (exit 0, empty stdout) is vacuously green, so each
# case now (a) re-globs the blob path after its re-warm, (b) PROVES
# the mutation landed (blob big enough to hold the target offset, od
# byte read back non-empty, dd exit 0, bytes differ from the
# pre-mutation copy), and (c) requires the run to have REWRITTEN the
# corrupted blob (a real miss re-elaborates and re-saves, so the
# post-run bytes must differ from the corrupted copy; a hit would
# leave them identical and turn the marker red).
rewarm_cache_file() {
  "$guard" < "$fx/allow.json" > /dev/null 2>&1
  cache_file=$(command ls "$cache_scratch"/prelude-*.bin 2> /dev/null | head -n1)
  size=$(wc -c < "$cache_file" | tr -d ' ')
  { [ -n "$cache_file" ] && [ "$size" -ge 2001 ]; } \
    || { echo "FAIL-D-CACHE-REWARM (no blob or blob under 2001 bytes: size=${size:-none})"; exit 1; }
}
# (i) body truncation: drop the last byte; the digest no longer
# matches.
rewarm_cache_file
head -c $((size - 1)) "$cache_file" > "$cache_file.cut"
mv "$cache_file.cut" "$cache_file"
cp "$cache_file" "$cache_file.bad"
out=$("$guard" < "$fx/allow.json"); c4=$?
{ [ "$c4" -eq 0 ] && [ -z "$out" ] && ! cmp -s "$cache_file" "$cache_file.bad"; } \
  && echo PASS-D-CACHE-BODYTRUNC \
  || { printf '%s\n' "$out"; echo "FAIL-D-CACHE-BODYTRUNC (exit=$c4)"; exit 1; }
rm -f "$cache_file.bad"
# (ii) a GUARANTEED bit flip mid-body (offset 2000 sits far past the
# 80-byte header; rewarm_cache_file already proved size >= 2001):
# read the byte, write it back xor 1.
rewarm_cache_file
b=$(od -An -j2000 -N1 -tu1 "$cache_file" | tr -d ' ')
[ -n "$b" ] || { echo "FAIL-D-CACHE-CORRUPT (od read no byte at offset 2000)"; exit 1; }
printf "\\$(printf '%03o' $((b ^ 1)))" | dd of="$cache_file" bs=1 seek=2000 conv=notrunc 2> /dev/null \
  || { echo "FAIL-D-CACHE-CORRUPT (dd write failed)"; exit 1; }
cp "$cache_file" "$cache_file.bad"
out=$("$guard" < "$fx/allow.json"); c5=$?
{ [ "$c5" -eq 0 ] && [ -z "$out" ] && ! cmp -s "$cache_file" "$cache_file.bad"; } \
  && echo PASS-D-CACHE-CORRUPT \
  || { printf '%s\n' "$out"; echo "FAIL-D-CACHE-CORRUPT (exit=$c5)"; exit 1; }
rm -f "$cache_file.bad"
# (iii) wrong magic: the first 8 bytes must read TOTCACHE exactly.
rewarm_cache_file
printf 'XXXXXXXX' | dd of="$cache_file" bs=1 seek=0 conv=notrunc 2> /dev/null \
  || { echo "FAIL-D-CACHE-MAGIC (dd write failed)"; exit 1; }
cp "$cache_file" "$cache_file.bad"
out=$("$guard" < "$fx/allow.json"); c6=$?
{ [ "$c6" -eq 0 ] && [ -z "$out" ] && ! cmp -s "$cache_file" "$cache_file.bad"; } \
  && echo PASS-D-CACHE-MAGIC \
  || { printf '%s\n' "$out"; echo "FAIL-D-CACHE-MAGIC (exit=$c6)"; exit 1; }
rm -f "$cache_file.bad"

# M3 fixes round 3 (O1): with NEITHER TOT_CACHE_DIR nor HOME set the
# cache is DISABLED for the run -- exit 0, exactly ONE stderr line,
# and NO ./.cache entry in the cwd. Pre-fix the fallback silently
# wrote ./.cache/tot/prelude-*.bin into whatever directory the
# process ran from (recorded in dev/M3-FIXES-LOG.md).
nohome_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-nohome.XXXXXX")
( cd "$nohome_scratch" \
    && env -u HOME -u TOT_CACHE_DIR TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
      "$watchdog" "$MED" "$tot_scratch/tot" run "$ROOT"/test/fixtures/x2-prelude-run.tot \
      > stdout.txt 2> stderr.txt )
nhcode=$?
nh_lines=$(rg -c '' "$nohome_scratch/stderr.txt")
nh_lines=${nh_lines:-0}
{ [ "$nhcode" -eq 0 ] && [ ! -e "$nohome_scratch/.cache" ] && [ "$nh_lines" -eq 1 ] \
    && rg -q 'prelude cache disabled' "$nohome_scratch/stderr.txt"; } \
  && echo PASS-CACHE-NOHOME \
  || {
    cat "$nohome_scratch/stderr.txt" 2> /dev/null
    echo "FAIL-CACHE-NOHOME (exit=$nhcode stderr-lines=$nh_lines)"
    rm -rf "$nohome_scratch"
    exit 1
  }
rm -rf "$nohome_scratch"

# M3 fixes round 3 (O4): an UNREADABLE executable image (an
# execute-only chmod-111 COPY of the built binary) makes Digest.file
# raise Sys_error, and the round-2 R1 branch disables the cache for
# the run: exit 0, exactly ONE stderr line, NO blob written. First
# process-level coverage of the exe_digest_hex = None branch.
#
# M4 Stage D (D5.3) REROUTED this gate to assert the OPPOSITE (a blob
# written, no stderr), because the stat-identity fast path needs no READ
# permission on its target. M4 fixes round 1 (audit F1) restores both
# the property and this assertion: the identity is a CONTENT digest
# again, so an unreadable image fails CLOSED exactly as it did at
# b01b3eb, and the marker means what its name says.
noexe_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-noexe.XXXXXX")
cp "$ROOT"/_build/default/bin/tot.exe "$noexe_scratch/tot-noread"
chmod 111 "$noexe_scratch/tot-noread"
env TOT_CACHE_DIR="$noexe_scratch/cache" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
  "$watchdog" "$MED" "$noexe_scratch/tot-noread" run "$ROOT"/test/fixtures/x2-prelude-run.tot \
  > /dev/null 2> "$noexe_scratch/stderr.txt"
nxcode=$?
nx_lines=$(rg -c '' "$noexe_scratch/stderr.txt")
nx_lines=${nx_lines:-0}
# plain-directory listing piped to rg (a bare zsh glob would print its
# own "no matches found" noise when the run correctly wrote nothing)
nx_blobs=$(command ls "$noexe_scratch/cache" 2> /dev/null | rg -c '^prelude-.*\.bin$')
nx_blobs=${nx_blobs:-0}
{ [ "$nxcode" -eq 0 ] && [ "$nx_lines" -eq 1 ] && [ "$nx_blobs" -eq 0 ] \
    && rg -q 'prelude cache disabled' "$noexe_scratch/stderr.txt"; } \
  && echo PASS-CACHE-NOEXEDIGEST \
  || {
    cat "$noexe_scratch/stderr.txt" 2> /dev/null
    echo "FAIL-CACHE-NOEXEDIGEST (exit=$nxcode stderr-lines=$nx_lines blobs=$nx_blobs)"
    rm -rf "$noexe_scratch"
    exit 1
  }
rm -rf "$noexe_scratch"

# M4 fixes round 1 (audit F1): the cache's exe identity is the running
# binary's CONTENT, not its filesystem metadata. This replays the
# audit's own executed repro and requires the fixed outcome. Two
# genuinely different binaries of EQUAL size (v2 has one byte patched
# inside the "no such file" literal) are installed at the SAME inode in
# turn, with v1's mtime restored onto v2 -- what a reproducible-build
# stamp or a `touch -r` install step does -- so every field D5.3 hashed
# AS the identity agrees. The blob count must reach 2: under D5.3 it
# stayed at 1 and the second binary read the first one's blob, which
# Marshal's deserializes straight into the trusted checker state.
#
# md5 tool and code signer are probed, never assumed: macOS ships `md5`
# and kills a modified signed binary unless it is re-signed ad hoc;
# Linux ships `md5sum` and needs no signer. A missing md5 tool is a
# LOUD failure, never a skipped (vacuously green) marker.
md5hex() {
  if command -v md5 > /dev/null 2>&1; then md5 -q "$1"
  elif command -v md5sum > /dev/null 2>&1; then md5sum "$1" | cut -d' ' -f1
  else printf ''; fi
}
sign_exe() {
  if command -v codesign > /dev/null 2>&1; then codesign -f -s - "$1" 2> /dev/null; fi
  return 0
}
exeid_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-exeid.XXXXXX")
mkdir -p "$exeid_scratch/cache"
cp "$ROOT"/_build/default/bin/tot.exe "$exeid_scratch/v1"
chmod u+w "$exeid_scratch/v1"
sign_exe "$exeid_scratch/v1"
cp "$ROOT"/_build/default/bin/tot.exe "$exeid_scratch/v2"
chmod u+w "$exeid_scratch/v2"
patch_off=$(rg -oba 'no such file' "$exeid_scratch/v2" | head -n1 | cut -d: -f1)
[ -n "$patch_off" ] \
  || { echo "FAIL-CACHE-EXEID-CONTENT (no 'no such file' literal to patch)"; rm -rf "$exeid_scratch"; exit 1; }
printf 'a' | dd of="$exeid_scratch/v2" bs=1 seek=$((patch_off + 11)) count=1 conv=notrunc 2> /dev/null \
  || { echo "FAIL-CACHE-EXEID-CONTENT (dd patch failed)"; rm -rf "$exeid_scratch"; exit 1; }
sign_exe "$exeid_scratch/v2"
v1_size=$(wc -c < "$exeid_scratch/v1" | tr -d ' ')
v2_size=$(wc -c < "$exeid_scratch/v2" | tr -d ' ')
v1_md5=$(md5hex "$exeid_scratch/v1")
v2_md5=$(md5hex "$exeid_scratch/v2")
{ [ -n "$v1_md5" ] && [ -n "$v2_md5" ]; } \
  || { echo "FAIL-CACHE-EXEID-CONTENT (no md5/md5sum on PATH)"; rm -rf "$exeid_scratch"; exit 1; }
{ [ "$v1_size" -eq "$v2_size" ] && [ "$v1_md5" != "$v2_md5" ]; } \
  || { echo "FAIL-CACHE-EXEID-CONTENT (setup: sizes $v1_size/$v2_size, md5 $v1_md5/$v2_md5)"; rm -rf "$exeid_scratch"; exit 1; }
cat "$exeid_scratch/v1" > "$exeid_scratch/tot"
chmod 555 "$exeid_scratch/tot"
env TOT_CACHE_DIR="$exeid_scratch/cache" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
  "$watchdog" "$MED" "$exeid_scratch/tot" run "$ROOT"/test/fixtures/x2-prelude-run.tot \
  > /dev/null 2> "$exeid_scratch/e1.txt"
e1code=$?
blobs1=$(command ls "$exeid_scratch/cache" 2> /dev/null | rg -c '^prelude-.*\.bin$')
blobs1=${blobs1:-0}
blob1=$(command ls "$exeid_scratch/cache"/prelude-*.bin 2> /dev/null | head -n1)
# header layout: 8 magic + 8 version + 32 body digest + 32 exe digest
hdr_exe=$(dd if="$blob1" bs=1 skip=48 count=32 2> /dev/null)
memo_hex=$(command ls "$exeid_scratch/cache"/exeid-*.txt 2> /dev/null | head -n1 | xargs -I{} tail -n1 {})
cp -p "$exeid_scratch/tot" "$exeid_scratch/tot.ref"
chmod u+w "$exeid_scratch/tot"
cat "$exeid_scratch/v2" > "$exeid_scratch/tot"
touch -r "$exeid_scratch/tot.ref" "$exeid_scratch/tot"
chmod 555 "$exeid_scratch/tot"
# the four fields D5.3 called the identity now agree again: same inode
# (overwritten in place), same size, same mtime (neither file is newer
# than the other), same device.
same_mtime=no
{ [ ! "$exeid_scratch/tot" -nt "$exeid_scratch/tot.ref" ] \
    && [ ! "$exeid_scratch/tot.ref" -nt "$exeid_scratch/tot" ]; } && same_mtime=yes
tot_size=$(wc -c < "$exeid_scratch/tot" | tr -d ' ')
# v2 really is a DIFFERENT program: its patched literal reads back.
# M4 fixes round 4 (ctxcat r4 id 5): wrapped like its neighbours. Bare,
# this ran the PATCHED binary against the developer's REAL default cache
# dir and REAL default prelude path, so it could write prelude blobs
# keyed on a deliberately corrupted binary's digest into a persistent
# directory the gate never cleans (rm -rf "$exeid_scratch" does not
# reach it), and it was the one unwatchdogged invocation here, so a
# patched binary that blocked would hang the whole battery instead of
# failing loudly. cache-probe is a SEPARATE dir from "$exeid_scratch/
# cache", so the blobs1/blobs2 counts below are untouched.
patched_out=$(env TOT_CACHE_DIR="$exeid_scratch/cache-probe" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
  "$watchdog" "$MED" "$exeid_scratch/tot" check "$exeid_scratch/absent.tot" 2>&1)
env TOT_CACHE_DIR="$exeid_scratch/cache" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
  "$watchdog" "$MED" "$exeid_scratch/tot" run "$ROOT"/test/fixtures/x2-prelude-run.tot \
  > /dev/null 2> "$exeid_scratch/e2.txt"
e2code=$?
blobs2=$(command ls "$exeid_scratch/cache" 2> /dev/null | rg -c '^prelude-.*\.bin$')
blobs2=${blobs2:-0}
{ [ "$e1code" -eq 0 ] && [ "$e2code" -eq 0 ] && [ "$blobs1" -eq 1 ] && [ "$blobs2" -eq 2 ] \
    && [ "$hdr_exe" = "$v1_md5" ] && [ "$memo_hex" = "$v1_md5" ] \
    && [ "$same_mtime" = "yes" ] && [ "$tot_size" -eq "$v1_size" ] \
    && printf '%s\n' "$patched_out" | rg -q 'no such fila'; } \
  && echo PASS-CACHE-EXEID-CONTENT \
  || {
    cat "$exeid_scratch/e1.txt" "$exeid_scratch/e2.txt" 2> /dev/null
    printf '%s\n' "$patched_out"
    echo "FAIL-CACHE-EXEID-CONTENT (exit=$e1code/$e2code blobs=$blobs1/$blobs2 hdr=$hdr_exe memo=$memo_hex v1=$v1_md5 mtime=$same_mtime size=$tot_size/$v1_size)"
    rm -rf "$exeid_scratch"
    exit 1
  }

# M4 fixes round 1 (audit F1), the other half: the stat signature
# survives as a MEMO that skips the re-hash, and TOT_CACHE_VERIFY=1
# announces which branch produced the identity. A cold run must hash
# CONTENT; the next run of the same untouched binary must take the memo
# fast path (and still verify the cold and cached bytes agree).
#
# M4 fixes round 3 (ctxcat r3 id 6): what this gate does NOT cover, and
# why that is ACCEPTED as a residual rather than closed. The one path
# where a wrong identity could be served is a memo HIT on a binary whose
# BYTES changed while its (device:inode:mtime:size:ctime) signature did
# not. This gate runs the same untouched binary twice, so it exercises
# the hit only in the benign direction; PASS-CACHE-EXEID-CONTENT bumps
# ctime deliberately, so it exercises the MISS. Neither forges the hit,
# and the suggested third leg (hand-edit the memo's recorded digest, or
# copy v1's memo onto v2's signature) would test a memo file an attacker
# who can write it has already won against: the cache directory is
# inside the accepted trust class, so a gate built that way asserts
# nothing about the threat model F1 addresses.
#
# The honest construction -- change the bytes and RESTORE the observed
# signature -- cannot be built unprivileged on this platform. Opus round
# 2 proved it by execution: setattrlist with ATTR_CMN_CHGTIME returns
# EPERM for a non-root caller, and ctime is not settable by utimes,
# utimensat or any other unprivileged call, so a hit-on-changed-bytes
# has no unprivileged construction. A privileged writer can forge it,
# and a privileged writer is inside the accepted cache-dir trust class
# by the same argument as above. That leaves exactly the exposure
# SPEC.md section 6 records: a mount whose observed ctime does not move
# on an in-place overwrite (attribute-cached network mounts,
# ctime-less filesystems) weakens the memo to a metadata check. It is a
# residual, deliberately, not an untested claim.
mkdir -p "$exeid_scratch/cache2"
memo1=$(env TOT_CACHE_DIR="$exeid_scratch/cache2" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
    TOT_CACHE_VERIFY=1 "$watchdog" "$MED" "$exeid_scratch/v1" run \
    "$ROOT"/test/fixtures/x2-prelude-run.tot 2>&1 1> /dev/null)
m1code=$?
memo2=$(env TOT_CACHE_DIR="$exeid_scratch/cache2" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
    TOT_CACHE_VERIFY=1 "$watchdog" "$MED" "$exeid_scratch/v1" run \
    "$ROOT"/test/fixtures/x2-prelude-run.tot 2>&1 1> /dev/null)
m2code=$?
{ [ "$m1code" -eq 0 ] && [ "$m2code" -eq 0 ] \
    && printf '%s\n' "$memo1" | rg -qx 'TOT-CACHE-EXEID-CONTENT' \
    && ! printf '%s\n' "$memo1" | rg -qx 'TOT-CACHE-EXEID-MEMO' \
    && printf '%s\n' "$memo2" | rg -qx 'TOT-CACHE-EXEID-MEMO' \
    && printf '%s\n' "$memo2" | rg -qx 'TOT-CACHE-VERIFY-OK'; } \
  && echo PASS-CACHE-EXEID-MEMO \
  || {
    printf '%s\n%s\n' "$memo1" "$memo2"
    echo "FAIL-CACHE-EXEID-MEMO (exit=$m1code/$m2code)"
    rm -rf "$exeid_scratch"
    exit 1
  }
rm -rf "$exeid_scratch"

unset TOT_CACHE_DIR TOT_CACHE_VERIFY TOT_PRELUDE

# M4 Stage A gate (ii): a recursive indexed family (Vec, with a sibling
# Fin) declares, builds a value, and RUNS: the exact erased readback of
# `vcons Nat (succ zero) zero (vcons Nat zero (succ zero) (vnil Nat))`
# (params and the length index erase; only the two runtime-kept
# arguments per vcons survive erasure).
m4a_vec_err=$(mktemp "${TMPDIR:-/tmp}/tot-gate-m4a-vec-err.XXXXXX")
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/m4a-vec.tot 2> "$m4a_vec_err")
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx '\(\(vcons zero\) \(\(vcons \(succ zero\)\) vnil\)\)'; } \
  && { rm -f "$m4a_vec_err"; echo PASS-M4A-VEC; } \
  || { printf '%s\n' "$out"; cat "$m4a_vec_err"; rm -f "$m4a_vec_err"; echo "FAIL-M4A-VEC (exit=$code)"; exit 1; }

# M4 Stage A gate (iii): a wrong-index constructor (VecB A, omitting the
# index) is Bad_ctor, naming the expected index count.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-vec-badindex.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'applied to its parameters and 1 index expression'; } \
  && echo PASS-M4A-VEC-BADIX \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-VEC-BADIX (exit=$code)"; exit 1; }

# M4 Stage A gate (iv), first fence: a w-carrying single constructor
# (Box) stays Erased_use -- the subsingleton criterion's "every
# constructor argument at quantity 0" clause.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-box.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'erased variable b used at runtime'; } \
  && echo PASS-M4A-BOX \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-BOX (exit=$code)"; exit 1; }

# M4 Stage A gate (iv), second fence: a self-recursive erased singleton
# (SX) stays Erased_use -- the subsingleton criterion's "not self-
# recursive" clause, not a quantity; SX itself is still ACCEPTED (only
# the eliminating def sxLoop is rejected).
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-sx.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'erased variable s used at runtime'; } \
  && echo PASS-M4A-SX \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-SX (exit=$code)"; exit 1; }

# M4 Stage A gate (iv), third fence: a two-constructor family (Bool)
# stays Erased_use -- the subsingleton criterion's "at most one
# constructor" clause; this is the "leave failing" half Gate A pairs
# against m4a-box.tot's and m4a-sx.tot's own flips.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-ese-neg.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'erased variable b used at runtime'; } \
  && echo PASS-M4A-ESE-NEG \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-ESE-NEG (exit=$code)"; exit 1; }

# M4 Stage A gate (vi): Fording (encoding an index as a uniform
# parameter) stays blocked; vpnil fails the result-head rule before
# define_ind's ctor fold ever reaches vpcons.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-fording.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'applied to its parameters and 0 index expressions'; } \
  && echo PASS-M4A-FORDING \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-FORDING (exit=$code)"; exit 1; }

# M4 Stage B gate (ii): subst0/castNat check end to end under the
# bootstrapped prelude, pinning the exact printed lines Stage C's own
# erasure gate later relies on (subst0 erases to the identity).
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4b-subst-erases.tot 2>&1)
code=$?
want=$'def symNat : (0 m : Nat) -> (0 n : Nat) -> (0 h : (((Eq Nat) m) n)) -> (((Eq Nat) n) m)\nsymNat : (0 m : Nat) -> (0 n : Nat) -> (0 h : (((Eq Nat) m) n)) -> (((Eq Nat) n) m)\ndef castNat : (0 P : (w _ : Nat) -> Type 0) -> (0 a : Nat) -> (0 b : Nat) -> (0 h : (((Eq Nat) a) b)) -> (w _ : (P a)) -> (P b)\ncastNat : (0 P : (w _ : Nat) -> Type 0) -> (0 a : Nat) -> (0 b : Nat) -> (0 h : (((Eq Nat) a) b)) -> (w _ : (P a)) -> (P b)'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4B-SUBST \
  || { printf '%s\n' "$out"; echo "FAIL-M4B-SUBST (exit=$code)"; exit 1; }

# M4 Stage B gate (iii): natDecEq computes both a yes and a no; a Dec
# scrutinee drives a Bool (sameArity), exact readback "true".
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/m4b-deceq-runs.tot 2>&1)
code=$?
want=$'def sameArity : Bool\ntrue'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4B-DECEQ \
  || { printf '%s\n' "$out"; echo "FAIL-M4B-DECEQ (exit=$code)"; exit 1; }

# M4 Stage B gate (iv): an axiom is accepted at quantity 0 (check) and
# rejected at quantity w (eval), the plan's own two halves; two
# fixtures (m4b-axiom.tot, m4b-axiom-runtime.tot) since ONE script
# cannot exhibit both an ok fold and a later hard error's message in
# its own stdout (a fold-error short-circuits before any of the
# earlier lines print).
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4b-axiom.tot 2>&1)
code=$?
want=$'axiom myAx : (((Eq Nat) zero) zero)\nmyAx : (((Eq Nat) zero) zero)'
out2=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4b-axiom-runtime.tot 2>&1)
code2=$?
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ] \
  && [ "$code2" -ne 0 ] && printf '%s\n' "$out2" | rg -q 'axiom myAx used at runtime'; } \
  && echo PASS-M4B-AXIOM \
  || { printf '%s\n%s\n' "$out" "$out2"; echo "FAIL-M4B-AXIOM (exit=$code/$code2)"; exit 1; }

# M4 Stage B gate (v): --no-axioms rejects a user axiom and exits 1;
# without the flag the same file checks and exits 0. Both halves
# asserted (B9's own instruction), since the flag's whole point is the
# difference. Driven through the real bin/tot.exe CLI (the driver flag
# lives there, not in test/surface.exe's gate-check/gate-run).
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/m4b-noaxioms.tot 2>&1)
code=$?
want=$'axiom bogus : (((Eq Nat) zero) (succ zero))\nbogus : (((Eq Nat) zero) (succ zero))'
out2=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check --no-axioms "$ROOT"/test/fixtures/m4b-noaxioms.tot 2>&1)
code2=$?
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ] \
  && [ "$code2" -ne 0 ] && printf '%s\n' "$out2" | rg -q -- '--no-axioms'; } \
  && echo PASS-M4B-NOAXIOMS \
  || { printf '%s\n%s\n' "$out" "$out2"; echo "FAIL-M4B-NOAXIOMS (exit=$code/$code2)"; exit 1; }

# M4 Stage C gate (v): m4c-frozen.tot exercises subst0's erasure path
# end to end (parse, elaborate, check, erase, exec, quote, print) through
# the real interpreter, under a 10s watchdog: a regression that
# re-introduces a self-reference into subst0's erased body (or otherwise
# breaks the runtime guard) shows up as exit 124, never a silent hang.
out=$("$watchdog" "$FAST" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/m4c-frozen.tot 2>&1)
code=$?
want='(succ zero)'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4C-FROZEN \
  || { printf '%s\n' "$out"; echo "FAIL-M4C-FROZEN (exit=$code)"; exit 1; }

# M4 Stage C gate (ii), derived: the in-process surface suite's own C4
# case (test/surface.ml) already proved subst0 erases to "fun px => px"
# and mentions nothing; this anchors that PASS line in $surface_out
# (captured near the top of this script) the same way PASS-A-LITERALS
# anchors A9/A10, so a future rename or deletion of the case shows up as
# a gate FAIL instead of silently dropping the check.
printf '%s\n' "$surface_out" | rg -q '^PASS C4: subst0 erases to the identity and mentions nothing$' \
  && echo PASS-M4C-SUBST-IDENTITY \
  || { printf '%s\n' "$surface_out"; echo "FAIL-M4C-SUBST-IDENTITY"; exit 1; }

# M4 Stage D, Gate D (i): "member String auto cmd flagged" typechecks,
# resolves and runs -- the flagged/isFlagged pair with auto, plus one
# "inst EqD String" call site, through gate-run's real prelude bootstrap.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/m4d-classes.tot 2>&1)
code=$?
want=$'def flagged : (List String)\ndef isFlagged : (w _ : String) -> Bool\ntrue\nfalse'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4D-AUTO \
  || { printf '%s\n' "$out"; echo "FAIL-M4D-AUTO (exit=$code)"; exit 1; }

# M4 Stage D, Gate D (ii): coherence. A duplicate instance key is
# Duplicate_global at definition time, message containing "inst$".
out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4d-dup-instance.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'duplicate global inst\$'; } \
  && echo PASS-M4D-COHERENCE \
  || { printf '%s\n' "$out"; echo "FAIL-M4D-COHERENCE (exit=$code)"; exit 1; }

# M4 Stage D, Gate D (iii): --serror-exit 3 changes the exit code on a
# one-line type error, and the default stays 1. Driven through the real
# bin/tot.exe CLI (the flag lives there), matching PASS-M4B-NOAXIOMS'
# own precedent.
# M4 fixes round 2 (ctxcat id 6): under the MED tier, like every other
# CLI gate in this block. The checker can be driven to unbounded work,
# so an unguarded invocation turns a hang into an indefinite stall with
# no FAIL marker instead of a loud exit 124.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/m4d-serror-exit.tot 2>&1)
code=$?
out2=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check --serror-exit 3 "$ROOT"/test/fixtures/m4d-serror-exit.tot 2>&1)
code2=$?
{ [ "$code" -eq 1 ] && [ "$code2" -eq 3 ] && [ "$out" = "$out2" ]; } \
  && echo PASS-M4D-SERROR-EXIT \
  || { printf '%s\n%s\n' "$out" "$out2"; echo "FAIL-M4D-SERROR-EXIT (exit=$code/$code2)"; exit 1; }

# M4 Stage D, Gate D (iv): --require-main rejects a mainless script
# (m4d-nomain.tot defines "mian", not "main") and the default behavior
# is unchanged (SPEC's misspelled-main residual, PASS-D-MAIN-MISSPELLED,
# stays a twin of this gate: unflagged, this exact fixture shape exits
# 0). M4 fixes round 2 (ctxcat id 6): under the MED tier.
# M4 fixes round 3 (ctxcat r3 id 3): the CHECK-mode leg is pinned too.
# --require-main is a verdict about the file's CONTENT, so it fires
# uniformly in both verbs by design (surface/run.ml's main_epilogue
# doc comment says so now); the finding read the flag's motivating
# consumer, a shebang wrapper, as its scope. Without this leg nothing
# stopped a later "gate it on exec" change from passing the battery.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/test/fixtures/m4d-nomain.tot 2>&1)
code=$?
out2=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- run --require-main "$ROOT"/test/fixtures/m4d-nomain.tot 2>&1)
code2=$?
out3=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check --require-main "$ROOT"/test/fixtures/m4d-nomain.tot 2>&1)
code3=$?
{ [ "$code" -eq 0 ] && [ "$code2" -ne 0 ] && [ "$code3" -ne 0 ] \
    && printf '%s\n' "$out2" | rg -q 'this file must define a driver main' \
    && printf '%s\n' "$out3" | rg -q 'this file must define a driver main'; } \
  && echo PASS-M4D-REQUIRE-MAIN \
  || {
    printf '%s\n%s\n%s\n' "$out" "$out2" "$out3"
    echo "FAIL-M4D-REQUIRE-MAIN (exit=$code/$code2/$code3)"
    exit 1
  }

# M4 Stage D, Gate D (vii): examples/guard-classes.tot checks and runs
# end to end -- the class layer (EqD/member/auto) plus two Eq proofs
# (agreeOnTrue by computation, denyStable by pure congruence).
# M4 fixes round 2 (ctxcat id 6): under the MED tier.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/examples/guard-classes.tot 2>&1)
code=$?
out2=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/examples/guard-classes.tot 2>&1)
code2=$?
want=$'def verdictOfDanger : (w _ : Bool) -> Verdict\ndef verdictOfDanger2 : (w _ : Bool) -> Verdict\ndef agreeOnTrue : (((Eq Verdict) (verdictOfDanger true)) (verdictOfDanger2 true))\nagreeOnTrue : (((Eq Verdict) (deny "use rg / sd")) (deny "use rg / sd"))\ndef denyStable : (w cmd : String) -> (0 h : (((Eq String) cmd) "grep")) -> (0 flag : (w _ : String) -> Bool) -> (((Eq Verdict) (verdictOfDanger (flag cmd))) (verdictOfDanger (flag "grep")))\ndenyStable : (w cmd : String) -> (0 h : (((Eq String) cmd) "grep")) -> (0 flag : (w _ : String) -> Bool) -> (((Eq Verdict) match (flag cmd) as _ return Verdict with | true => (deny "use rg / sd") | false => allow end) match (flag "grep") as _ return Verdict with | true => (deny "use rg / sd") | false => allow end)\ndef flagged : (List String)\ndef isFlagged : (w _ : String) -> Bool\ntrue\nfalse'
{ [ "$code" -eq 0 ] && [ "$code2" -eq 0 ] && [ "$out2" = "$want" ]; } \
  && echo PASS-M4D-GUARD-CLASSES \
  || { printf '%s\n%s\n' "$out" "$out2"; echo "FAIL-M4D-GUARD-CLASSES (exit=$code/$code2)"; exit 1; }

# ---------------------------------------------------------------------
# M4 fixes round 1
# ---------------------------------------------------------------------

# ctxcat id 8: a constructor whose CODOMAIN carries a type annotation,
# and one whose PARAMETER argument does, both still check. Stage A moved
# the result-head test onto the RAW type, and elaboration is what deletes
# Term.Ann, so before the fix each of these died with a Bad_ctor whose
# stated reason (arity) had nothing to do with the real cause. Exact
# output pinned, so a silent re-rejection cannot hide here.
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/m4fix-ann-ctor.tot 2>&1)
code=$?
want=$'data AnnFoo : Type 0\nctor annMk : AnnFoo\ndata AnnBox : (0 A : Type 0) -> Type 0\nctor annBox : (0 A : Type 0) -> (w _ : A) -> (AnnBox A)'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4FIX-ANN-CTOR \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-ANN-CTOR (exit=$code)"; exit 1; }

# audit F3: `auto` in a result-index position hits the index-cleanliness
# ban ITSELF (Bad_ctor, naming the index expressions), instead of
# slipping past the raw check into elaboration, where the error used to
# arrive as an unrelated "no instance found for Nat".
out=$("$watchdog" "$MED" dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/m4fix-auto-index.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'invalid constructor autoIdx' \
    && printf '%s\n' "$out" | rg -q 'index expression' \
    && ! printf '%s\n' "$out" | rg -q 'no instance found'; } \
  && echo PASS-M4FIX-AUTO-INDEX \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-AUTO-INDEX (exit=$code)"; exit 1; }

# ctxcat ids 1+6: an instance with FOUR dictionary binders resolves and
# computes. validate_instance_shape accepts this shape, so a fuel bound
# that cannot afford it is a reachable false negative, not a backstop:
# before the fix this exact file died with "instance resolution for
# (FC4 Bool) exceeded its fuel".
out=$(gate_timed "$MED" M4FIX-INST-BINDERS dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/test/fixtures/m4fix-inst-binders.tot)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true' \
    && ! printf '%s\n' "$out" | rg -q 'fuel'; } \
  && echo PASS-M4FIX-INST-BINDERS \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-BINDERS (exit=$code)"; exit 1; }

# ctxcat id 7: 26 matches nested in SCRUTINEE position check in well
# under the watchdog. The staged match_scrut inferred every scrutinee
# twice, so this file cost 2^26 inferences (measured on that binary:
# 0.01s at depth 12, 1.08s at depth 20, 4x per two levels, about 70s
# here); a 15s watchdog turns the regression into exit 124, never a
# silent slow gate.
# M4 fixes round 2 (ctxcat id 7): this is a TIMING assertion, so it runs
# the ALREADY-BUILT binary rather than `dune exec`, which acquires the
# workspace build lock and may rebuild -- either would be charged to the
# 15s budget and could hit 124 with no regression present (a parallel
# build or an editor's dune RPC holding the lock is enough). The F2
# gates below run "$ROOT"/_build/default/bin/tot.exe for the same
# reason; every gate above has already forced that binary to be built.
out=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-nest26.tot 2>&1)
code=$?
want=$'def nest26 : Bool\nnest26 : Bool'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4FIX-NEST-DEPTH \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-NEST-DEPTH (exit=$code)"; exit 1; }

# ---------------------------------------------------------------------
# M4 fixes round 2
# ---------------------------------------------------------------------

# ctxcat id 4 + opus R1: the ILL-TYPED twin of the gate above. 26
# matches nested in SCRUTINEE position with the innermost one missing
# its `false` branch. Round 1 removed the unconditional second pass but
# left the Zero fallback unguarded, so an error that also fails at mode
# Zero (a missing branch, a wrong scrutinee type, a missing motive: the
# everyday ones) re-ran the whole subterm at every level and restored
# the 2^depth curve on the ERROR path. Measured on the round-1 binary:
# 0.11s at depth 18, 1.21s at 22, 18.18s at 26. Guarding the fallback on
# the ambient mode makes the failing path O(depth^2). Budget 10s, so the
# pre-fix cost clears it by 1.8x; the exact diagnosis is pinned as well,
# because a FAST WRONG error is not a fix. Built binary, as above.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-nest26-ill.tot 2>&1)
code=$?
{ [ "$code" -eq 1 ] \
    && printf '%s\n' "$out" | rg -q 'match branches do not fit the declaration: expected false, found <none>'; } \
  && echo PASS-M4FIX-NEST-ILL \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-NEST-ILL (exit=$code)"; exit 1; }

# opus R1, the motive-less variant: 30 matches nested in SCRUTINEE
# position with no `as .. return` anywhere. infer's Match arm calls
# match_scrut BEFORE demanding a motive, so every enclosing level still
# inferred the whole subterm and the missing motive failed at both
# modes. Measured on the round-1 binary: 0.41s at depth 22, 5.79s at 26,
# so about 80s at 30 -- 8x this gate's own budget.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-nest30-nomotive.tot 2>&1)
code=$?
{ [ "$code" -eq 1 ] \
    && printf '%s\n' "$out" | rg -q "cannot infer a type for a match without 'as \.\. return'"; } \
  && echo PASS-M4FIX-NEST-NOMOTIVE \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-NEST-NOMOTIVE (exit=$code)"; exit 1; }

# M4 fixes round 4 (opus R4-1): PASS-M4FIX-INST-BRANCHING USED TO SIT
# HERE.  It is the slowest and least informative leg in the battery, and
# this script fail-fasts, so a load-induced exit 124 here blanked six
# later markers, the memo's own soundness pin (PASS-M4FIX-INST-MEMO-KEY)
# and the whole prelude-channel gate among them.  The leg now runs LAST
# in the M4-fixes block, after every cheap marker has already printed.

# ---------------------------------------------------------------------
# M4 fixes round 3
# ---------------------------------------------------------------------

# opus R3-1, the reach gates. Round 2 turned instance fuel into a budget
# for the whole resolution but left the budget sized like a per-path
# depth counter, so it rejected shapes whose total work merely grows
# faster than the query's depth -- including two shapes that are not
# exponential at all. All three files below RESOLVED on the round-1
# binary and reported Inst_depth on the round-2 one; they are the
# regression class made testable. Each pins exit 0 AND the computed
# value (a fast WRONG answer is not a fix), on the already-built binary
# for the same reason PASS-M4FIX-NEST-DEPTH does.

# Two DIFFERENT classes on the same type variable, nesting 30. Work is
# quadratic in the nesting, fuel was linear in it: rejected from nesting
# 6 up. Measured after the memo: 0.052s.
out=$(gate_timed "$MED" M4FIX-INST-TWOCLASS "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-twoclass.tot)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true'; } \
  && echo PASS-M4FIX-INST-TWOCLASS \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-TWOCLASS (exit=$code)"; exit 1; }

# The SPEC's own branching shape (same class twice), nesting 16: 2^16
# identical sub-resolutions without the memo, one derivation per
# distinct sub-goal with it. Round 2 rejected this from nesting 4 up.
# Measured after the memo: 1.03s, of which the resolution itself is a
# small fraction (the rest is the 65k-node emitted dictionary).
out=$(gate_timed "$MED" M4FIX-INST-SPEC16 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-spec16.tot)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true'; } \
  && echo PASS-M4FIX-INST-SPEC16 \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-SPEC16 (exit=$code)"; exit 1; }

# Eight INDEPENDENT chains at n=40: exactly 320 sub-resolutions, linear
# in the input, no sharing and no re-derivation, answered by the round-1
# binary in 43ms and rejected by the round-2 one from k=8 n=20 up. This
# is the file that proves the round-2 budget was not bounding an
# exponential blow-up. Measured after the memo: 0.046s, so the 15s
# budget is 300x headroom and a 124 means a real regression.
out=$(gate_timed "$MED" M4FIX-INST-CHAINS "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-chains.tot)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true'; } \
  && echo PASS-M4FIX-INST-CHAINS \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-CHAINS (exit=$code)"; exit 1; }

# opus R3-5: the SMALL-depth positive the round-2 gate set could not
# see. PASS-M4FIX-INST-BRANCHING's old "resolve OR Inst_depth" oracle
# was satisfied by a fix that rejected two-dictionary telescopes at
# depth 1, so nothing pinned that they resolve at all. Two shapes, both
# at a depth whose emitted term is small: two DIFFERENT classes at
# nesting 6 (the exact shape round 2 first rejected) and the SAME class
# twice at nesting 3. BOTH values pinned, so a fix that resolves one and
# drops the other fails here.
out=$(gate_timed "$MED" M4FIX-INST-SMALL-REACH "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-small-reach.tot)
code=$?
{ [ "$code" -eq 0 ] \
    && [ "$(printf '%s\n' "$out" | rg -cx 'true')" = "2" ]; } \
  && echo PASS-M4FIX-INST-SMALL-REACH \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-SMALL-REACH (exit=$code)"; exit 1; }

# opus R3-1, the memo's SOUNDNESS pin, the half a reach gate cannot see.
# The memo is keyed on (class, key) with the key spelled in FULL -- the
# class argument's own quoted term, not its head symbol. A head-only key
# is what the SPEC debt's wording suggested and it is UNSOUND: an
# instance with two type binders puts two sibling dictionary sub-goals
# in one telescope, and those can share a head while differing in its
# arguments. This file makes PC (PBox Bool) and PC (PBox Nat) collide on
# the head PBox and reads the SECOND dictionary, so a head-only memo
# answers with the FIRST and the file computes `zero` (or fails the
# candidate re-check) instead of `(succ zero)`. Exact value pinned.
out=$(gate_timed "$MED" M4FIX-INST-MEMO-KEY "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-memo-key.tot)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx '\(succ zero\)'; } \
  && echo PASS-M4FIX-INST-MEMO-KEY \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-MEMO-KEY (exit=$code)"; exit 1; }

# opus R3: an annotation on the spine's own HEAD, in a constructor
# codomain and in a constructor PARAMETER argument. Totality.spine
# unwinds App without stripping, so round 1's outer strip_ann never
# reached the head and head_ok was false: a Bad_ctor on a term the
# elaborator accepts in every other position. Exact output pinned.
out=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-ann-head.tot 2>&1)
code=$?
want=$'data AVec : (0 _ : Nat) -> Type 0\nctor avnil : (AVec zero)\ndata ABox : (0 A : Type 0) -> Type 0\nctor abx : (0 A : Type 0) -> (w _ : A) -> (ABox A)\nAVec : (0 _ : Nat) -> Type 0'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4FIX-ANN-HEAD \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-ANN-HEAD (exit=$code)"; exit 1; }

# opus R3, the NEGATIVE half: stripping the annotation off the spine
# head must not start accepting a codomain whose head is the WRONG
# family. `(Nat : Type 0) zero` strips to Global "Nat", not BVec, so
# this stays a Bad_ctor naming BVec's own result shape -- rejected for
# the intended reason, not for arity and not by accident.
out=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-ann-head-neg.tot 2>&1)
code=$?
{ [ "$code" -eq 1 ] \
    && printf '%s\n' "$out" | rg -q 'invalid constructor bvnil: constructor must end in BVec applied to its parameters and 1 index expression'; } \
  && echo PASS-M4FIX-ANN-HEAD-NEG \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-ANN-HEAD-NEG (exit=$code)"; exit 1; }

# ---------------------------------------------------------------------
# M4 fixes round 4
# ---------------------------------------------------------------------

# ctxcat r4 id 3, the NEGATIVE: an axiom must not reach a runtime
# definition through a zero-constructor family. Empty is Complete [],
# which zero_eliminable accepts, so rounds 1 to 3 stamped scrut_q = Zero
# on `match ff with end` even though the ambient mode had already
# rejected the scrutinee with Axiom_runtime_use, and `boom : Nat` became
# a runtime def whose erased body is the erasure residue. The fallback
# is now guarded on Erased_use, the one class it exists for.
out=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-axiom-empty.tot 2>&1)
code=$?
{ [ "$code" -eq 1 ] \
    && printf '%s\n' "$out" | rg -q 'axiom ff used at runtime: axioms are usable only at quantity 0'; } \
  && echo PASS-M4FIX-AXIOM-EMPTY \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-AXIOM-EMPTY (exit=$code)"; exit 1; }

# ctxcat r4 id 3, the POSITIVE: the erased-hypothesis absurd elimination
# the fallback exists for keeps checking, on all three subsingleton
# shapes (zero-constructor Empty, the all-erased Eq/refl, the all-erased
# Unit). The prelude's exfalso, subst0 and J0 are these shapes, so this
# is the half a too-eager narrowing would break. Exact output pinned.
out=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-absurd.tot 2>&1)
code=$?
want=$'def absurdNat : (0 e : Empty) -> Nat\ndef substNat : (0 a : Nat) -> (0 b : Nat) -> (0 h : (((Eq Nat) a) b)) -> (w _ : Nat) -> Nat\ndef unitPeek : (0 u : Unit) -> Nat\nabsurdNat : (0 e : Empty) -> Nat'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4FIX-ABSURD \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-ABSURD (exit=$code)"; exit 1; }

# ctxcat r4 id 3, the CONTROL: an ambient scrutinee error that is
# neither Erased_use nor Axiom_runtime_use still propagates unchanged.
# `zero zero` is Not_a_function "Nat" at the ambient mode; the narrowed
# guard returns it directly instead of re-inferring at Zero, and the
# message is byte-identical to the round-3 one.
out=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-scrut-notfun.tot 2>&1)
code=$?
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q 'not a function type: Nat'; } \
  && echo PASS-M4FIX-SCRUT-NOTFUN \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-SCRUT-NOTFUN (exit=$code)"; exit 1; }

# ctxcat r4 id 4: an annotation wrapping the ENTIRE constructor type.
# The finding predicted a false Bad_ctor; strip_pis calls strip_ann at
# every level (round 1, ctxcat id 8), so all three spellings already
# checked and the finding is refuted on behaviour. This is the missing
# regression pin. Exact output.
out=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-ann-whole.tot 2>&1)
code=$?
want=$'data WFoo : (0 A : Type 0) -> (0 _ : Nat) -> Type 0\nctor wmk : (0 A : Type 0) -> (0 x : Nat) -> ((WFoo A) x)\ndata XFoo : (0 A : Type 0) -> (0 _ : Nat) -> Type 0\nctor xmk : (0 A : Type 0) -> (0 x : Nat) -> ((XFoo A) x)\ndata YFoo : (0 A : Type 0) -> (0 _ : Nat) -> Type 0\nctor ymk : (0 A : Type 0) -> (0 x : Nat) -> ((YFoo A) x)\nWFoo : (0 A : Type 0) -> (0 _ : Nat) -> Type 0'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4FIX-ANN-WHOLE \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-ANN-WHOLE (exit=$code)"; exit 1; }

# ctxcat r4 id 4, the NEGATIVE half: a genuinely wrong codomain under
# the SAME whole-type annotation still fails Bad_ctor, so the positive
# above is not passing because the shape stopped being checked.
out=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-ann-whole-neg.tot 2>&1)
code=$?
{ [ "$code" -eq 1 ] \
    && printf '%s\n' "$out" | rg -q 'invalid constructor zbad: constructor must end in ZBad applied to its parameters and 1 index expression'; } \
  && echo PASS-M4FIX-ANN-WHOLE-NEG \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-ANN-WHOLE-NEG (exit=$code)"; exit 1; }

# ctxcat r4 id 0: the motive's index-binder order on a family with TWO
# indices (Vec has one, and one index cannot tell the two candidate
# conventions apart). "in Tw i c" must bind i to the FIRST declared
# index; the positive elaborates only under that reading and the
# negative, which needs the swapped reading, must fail with a Bool/Nat
# mismatch. Both halves in one marker, so neither can pass alone.
out=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-motive-order.tot 2>&1)
code=$?
outn=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-motive-order-neg.tot 2>&1)
coden=$?
want=$'data Tw : (0 _ : Nat) -> (0 _ : Bool) -> Type 0\nctor tw : ((Tw zero) true)\ndef TwP : (w _ : Nat) -> (w _ : Bool) -> Type 0\ndef twOrder : (0 n : Nat) -> (0 b : Bool) -> (0 t : ((Tw n) b)) -> ((TwP n) b)\ntwOrder : (0 n : Nat) -> (0 b : Bool) -> (0 t : ((Tw n) b)) -> Nat'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ] && [ "$coden" -eq 1 ] \
    && printf '%s\n' "$outn" | rg -q 'type mismatch: expected Bool, found Nat'; } \
  && echo PASS-M4FIX-MOTIVE-ORDER \
  || {
    printf '%s\n' "$out"; printf '%s\n' "$outn"
    echo "FAIL-M4FIX-MOTIVE-ORDER (exit=$code/$coden)"; exit 1
  }

# opus R4-3: a WIDE, SHALLOW instance query. Round 3 argued the flat
# 10000 fuel floor "covers wide ones"; a constant bounds width only up
# to that constant. A balanced WPair tree over 2500 pairwise distinct
# leaf types charges 6 per distinct (class, key) pair, 14994 in all,
# while its DEPTH is only log2 2500, so the round-3 formula sat at its
# floor and rejected this query with Inst_depth (bisected to the leaf:
# L = 1667 resolves at 9996, L = 1668 fails at 10002). inst_fuel now
# also scales with term_size. Exact value pinned; the failure branch is
# tailed because the fixture prints one line per declaration.
out=$(gate_timed "$MED" M4FIX-INST-WIDE "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-wide.tot)
code=$?
{ [ "$code" -eq 0 ] && [ "$(printf '%s\n' "$out" | rg -cx 'zero')" = "1" ] \
    && ! printf '%s\n' "$out" | rg -q 'fuel'; } \
  && echo PASS-M4FIX-INST-WIDE \
  || { printf '%s\n' "$out" | tail -n 5; echo "FAIL-M4FIX-INST-WIDE (exit=$code)"; exit 1; }

# M4 fixes round 5 (opus R5-2): the CLASS-COUNT dimension. 57 classes,
# one WPair instance per class demanding every class on BOTH parameters
# (so each instance carries 114 dictionary binders), and a four-leaf
# query. The walk charges about K^2 per query node while every term of
# the round-4 formula was linear in K, so the backstop fired on a
# finite, well formed, resolvable query. Bisected on the round-4 binary
# to the leaf: K = 56 resolves at exit 0, K = 57 reports "exceeded its
# fuel" at exit 1. Regenerate with
#   python3 dev/gen-inst-fuel.py classes 57 > test/fixtures/m4fix-inst-classes.tot
# Exact value pinned, and an Inst_depth here is a FAIL by name so a
# future re-narrowing cannot pass as a different error.
# M4 fixes round 6 (opus R6-1): this pin's MARGIN, recorded here for the
# first time. Measured on the round-5 binary with the same generator, the
# leaf on this shape is K = 60 resolving at exit 0 and K = 61 reporting
# "exceeded its fuel" at exit 1, so the K = 57 pinned here sits THREE
# classes under the leaf, about 5 percent, thinner than D9f's recorded 7
# percent. The leaf is a MEASUREMENT, not a proof: re-measure it
# (python3 dev/gen-inst-fuel.py classes 61, run, expect exit 1) whenever
# inst_fuel or build_instance's charge accounting changes, and lower K
# here if the margin goes negative.
# M5 Stage C (2026-09-02): inst_fuel gained the (1 + class_count)
# factor and dev/bisect-inst-classes.sh re-bisected this shape to
# NOLEAF<=488 (61, 122, 244 and 488 all resolve), so the 60/61 leaf
# recorded above is STALE; PASS-M5C-CLASSES-61 and
# PASS-M5C-LEAF-MARGIN carry the new pins.  This fixture and its
# marker stay: a gate that got cheaper to pass is still a gate.
out=$(gate_timed "$SLOW" M4FIX-INST-CLASSES "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-classes.tot)
code=$?
{ [ "$code" -eq 0 ] && [ "$(printf '%s\n' "$out" | rg -cx 'zero')" = "1" ] \
    && ! printf '%s\n' "$out" | rg -q 'fuel'; } \
  && echo PASS-M4FIX-INST-CLASSES \
  || { printf '%s\n' "$out" | tail -n 3; echo "FAIL-M4FIX-INST-CLASSES (exit=$code)"; exit 1; }

# M4 fixes round 5 (opus R5-5, ctxcat r5 id 15): the DRIVER's stderr
# line is bounded for the whole printed-type error family, not just for
# Inst_depth. Measured on the round-4 binary, worst single stderr line:
# Inst_depth 503 bytes (capped), Inst_unresolved 32,122, Mismatch
# 800,162 (two uncapped payloads). The oracle is INDEPENDENCE: the same
# shape is generated at two very different sizes and the longest stderr
# line must be the SAME length, which no choice of goal_print_cap can
# fake, plus a SHORT mismatch must still print both types in full.
mm_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-mm.XXXXXX")
mm_nest() {
  mm_n=$1
  mm_i=0
  mm_open=""
  mm_close=""
  while [ "$mm_i" -lt "$mm_n" ]; do
    mm_open="$mm_open(MMWrap "
    mm_close="$mm_close)"
    mm_i=$((mm_i + 1))
  done
  printf '%s%s%s' "$mm_open" "MMKey" "$mm_close"
}
mm_write() {
  mm_path=$1
  mm_depth=$2
  {
    printf -- '-- GENERATED by dev/gates.sh (M4 fixes round 5): a Mismatch\n'
    printf -- '-- whose BOTH payloads are printed types of depth %s.\n' "$mm_depth"
    printf 'data MMKey : Type 0 := | mmKey : MMKey\n'
    printf 'data MMWrap (0 A : Type 0) : Type 0 := | mmWrap : A -> MMWrap A\n'
    printf 'def mmA : %s -> MMKey := fun z => mmKey\n' "$(mm_nest "$mm_depth")"
    printf 'def mmB : %s -> MMKey := fun z => mmKey\n' "$(mm_nest $((mm_depth + 1)))"
    printf 'def mmBad : %s -> MMKey := mmB\n' "$(mm_nest "$mm_depth")"
  } > "$mm_path"
}
mm_write "$mm_scratch/small.tot" 300
mm_write "$mm_scratch/large.tot" 900
printf 'data MMKey : Type 0 := | mmKey : MMKey\ndata MMWrap (0 A : Type 0) : Type 0 := | mmWrap : A -> MMWrap A\ndef mmA : MMWrap MMKey -> MMKey := fun z => mmKey\ndef mmB : MMKey -> MMKey := fun z => mmKey\ndef mmBad : MMWrap MMKey -> MMKey := mmB\n' \
  > "$mm_scratch/short.tot"
"$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$mm_scratch/small.tot" \
  > "$mm_scratch/o1" 2> "$mm_scratch/e1"
mm_c1=$?
"$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$mm_scratch/large.tot" \
  > "$mm_scratch/o2" 2> "$mm_scratch/e2"
mm_c2=$?
"$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$mm_scratch/short.tot" \
  > "$mm_scratch/o3" 2> "$mm_scratch/e3"
mm_c3=$?
mm_len1=$(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$mm_scratch/e1")
mm_len2=$(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$mm_scratch/e2")
mm_len3=$(awk '{ if (length($0) > m) m = length($0) } END { print m + 0 }' "$mm_scratch/e3")
{ [ "$mm_c1" -eq 1 ] && [ "$mm_c2" -eq 1 ] && [ "$mm_c3" -eq 1 ] \
    && [ "$mm_len1" = "$mm_len2" ] && [ "$mm_len1" -lt 5000 ] \
    && rg -q 'type mismatch' "$mm_scratch/e1" && rg -q '\.\.\.' "$mm_scratch/e1" \
    && rg -q '\.\.\.' "$mm_scratch/e2" \
    && ! rg -q '\.\.\.' "$mm_scratch/e3" \
    && [ "$mm_len3" -lt 200 ]; } \
  && echo PASS-M4FIX-ERROR-LINE-BOUNDED \
  || {
    printf 'exit=%s/%s/%s longest=%s/%s/%s\n' "$mm_c1" "$mm_c2" "$mm_c3" "$mm_len1" "$mm_len2" "$mm_len3"
    cut -c1-200 "$mm_scratch/e1" "$mm_scratch/e3"
    echo "FAIL-M4FIX-ERROR-LINE-BOUNDED"
    rm -rf "$mm_scratch"
    exit 1
  }
rm -rf "$mm_scratch"

# opus R4-2: the prelude is read exactly ONCE per driver invocation.
# Round 3 asserted this in three docstrings and it was false on every
# cache MISS: the driver's precheck read the file (read 1, which became
# the cache KEY) and cached_state_of_src's miss branch called state (),
# which read it again (read 2, whose bytes were what got elaborated).
# Two consequences, both reproduced on the round-3 binary: read 2's
# failure is a Serror INSIDE the --serror-exit mapping, so a prelude
# removed between the two reads exited 0 under --serror-exit 0 (12 of
# 12 attempts); and the cache entry stored under content A's key held a
# state elaborated from content B, with no privilege on the cache dir
# needed (5 of 8 sampled delays). Threading one src closes both by
# construction. The race itself is not a battery-shaped oracle (it needs
# a 20 MB prelude and a background unlink), so this leg pins the two
# DETERMINISTIC facts that make the race impossible:
#  (i)  surface/bootstrap.ml CALLS state () nowhere: no line binds it
#       ("= state ()") and no line applies it on its own ("^ state ()").
#       The definition line starts "let state ()" and doc comments spell
#       it "[state ()]", so neither pattern matches them. Round 3 had
#       exactly two such call lines, both inside cached_state_of_src.
#  (ii) state_of_src is applied to src in three places: once inside
#       state () and once in EACH branch of cached_state_of_src (the
#       TOT_CACHE_VERIFY recompute and the cache miss), so the key and
#       the elaborated content are the same bytes. The [^_] excludes
#       "cached_state_of_src src", a substring of the same shape.
# plus the channel contract itself: a prelude that is missing reports
# the DRIVER message ("no such file", the literal exit 1, outside the
# mapping) and never read 2's message shape ("prelude not found:").
oneread_calls=$(rg -c '^\s*state \(\)|= state \(\)' "$ROOT"/surface/bootstrap.ml)
oneread_calls=${oneread_calls:-0}
oneread_srcs=$(rg -c '[^_]state_of_src src' "$ROOT"/surface/bootstrap.ml)
oneread_srcs=${oneread_srcs:-0}
oneread_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-oneread.XXXXXX")
printf 'def oneReadOk : Bool := true\n' > "$oneread_scratch/target.tot"
oneread_out=$(env TOT_PRELUDE="$oneread_scratch/absent-prelude.tot" \
  TOT_CACHE_DIR="$oneread_scratch/cache" \
  "$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check --serror-exit 0 \
  "$oneread_scratch/target.tot" 2>&1 > "$oneread_scratch/out")
oneread_code=$?
{ [ "$oneread_calls" -eq 0 ] && [ "$oneread_srcs" -eq 3 ] \
    && [ "$oneread_code" -eq 1 ] && [ ! -s "$oneread_scratch/out" ] \
    && printf '%s\n' "$oneread_out" | rg -q 'no such file' \
    && ! printf '%s\n' "$oneread_out" | rg -q 'prelude not found'; } \
  && echo PASS-D-PRELUDE-ONEREAD \
  || {
    printf '%s\n' "$oneread_out"
    echo "FAIL-D-PRELUDE-ONEREAD (calls=$oneread_calls srcs=$oneread_srcs exit=$oneread_code)"
    rm -rf "$oneread_scratch"
    exit 1
  }
rm -rf "$oneread_scratch"

# M4 fixes round 5 (opus R5-4): the branching leg USED to sit here, and
# the round-4 log claimed the move to the end of the M4-fixes block
# protected PASS-D-PRELUDE-CHANNEL. It did not. This script has no
# `set -e`; every leg is an `&&` chain onto its marker with an `|| { ..;
# exit 1; }` arm, so a failure here ENDS the script, and four PASS-D-*
# markers still sat downstream, PASS-D-PRELUDE-CHANNEL among them.
# Simulated by pointing the leg at a missing fixture: GATE-EXIT=1,
# FAIL-M4FIX-INST-BRANCHING, and none of the four printed. The leg now
# runs LAST in the whole file (below PASS-D-USAGE-CHANNEL), so the
# sentence is true of every marker, not four out of eight.

# audit F2: driver errors go to STDERR, because stdout is the hook
# protocol's decision channel, and a MISSING script file is an error
# exit regardless of --serror-exit. Runs the built binary directly (not
# `dune exec`) so the two channels can be compared exactly. Pre-fix this
# printed the line on stdout and, under --serror-exit 0, exited 0.
f2_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-f2.XXXXXX")
f2_missing="$f2_scratch/no-such-file.tot"
"$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check --serror-exit 0 "$f2_missing" \
  > "$f2_scratch/out1" 2> "$f2_scratch/err1"
f2c1=$?
"$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$f2_missing" \
  > "$f2_scratch/out2" 2> "$f2_scratch/err2"
f2c2=$?
{ [ "$f2c1" -eq 1 ] && [ "$f2c2" -eq 1 ] \
    && [ ! -s "$f2_scratch/out1" ] && [ ! -s "$f2_scratch/out2" ] \
    && [ "$(cat "$f2_scratch/err1")" = "$f2_missing: no such file" ] \
    && [ "$(cat "$f2_scratch/err2")" = "$f2_missing: no such file" ]; } \
  && echo PASS-D-MISSING-FILE-CHANNEL \
  || {
    cat "$f2_scratch/out1" "$f2_scratch/err1" 2> /dev/null
    echo "FAIL-D-MISSING-FILE-CHANNEL (exit=$f2c1/$f2c2)"
    rm -rf "$f2_scratch"
    exit 1
  }

# M4 fixes round 2 (opus R2): the three SIBLING paths the existence
# guard let through. A directory, a FIFO and a regular file with no read
# permission all satisfy Sys.file_exists, so control reached
# In_channel.with_open_text: the directory and the unreadable file
# printed an OCaml crash dump and exited 2 (the code this driver
# reserves for USAGE errors, so a hook could not tell "you called me
# wrong" from "your script is unreadable"), --serror-exit was not
# consulted at all, and the FIFO did not exit -- the open blocked on a
# writer that never came (exit 124 at 8s, measured). All three now take
# the same route as a missing file: stdout empty, one driver line on
# stderr, the literal exit 1, outside the --serror-exit mapping. The
# FIFO half is also a HANG gate: the watchdog turns a re-blocking open
# into a loud 124.
#
# M4 fixes round 3 (ctxcat r3 id 1): the UNREADABLE sub-case rests on
# `chmod 000`, and the kernel does not enforce permission bits against
# uid 0. Run as root (a common CI container shape) the open would
# SUCCEED, the probe would observe a different exit and stderr, and the
# gate would fail for a reason that has nothing to do with the code --
# or, worse, coincide and pass without ever reaching the Unreadable
# branch. It is now skipped under `id -u` = 0 with an explicit line, so
# a root run says so out loud instead of pretending to cover it. The
# directory and FIFO sub-cases need no guard: their classification is a
# stat, which root does not bypass.
f2_dir="$f2_scratch/adir"
f2_unread="$f2_scratch/unreadable.tot"
f2_fifo="$f2_scratch/pipe.tot"
mkdir "$f2_dir"
printf 'def x : Bool := true\n' > "$f2_unread"
chmod 000 "$f2_unread"
mkfifo "$f2_fifo"
f2_sib_ok=1
# $1 path, $2 the expected stderr tail, then any extra flags. Pins all
# three channels at once: exit 1, EMPTY stdout, exactly the driver line.
# Written as six flat calls, matching this file's own gate style.
f2_sibling() {
  f2_path=$1
  f2_msg=$2
  shift 2
  "$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$@" "$f2_path" \
    > "$f2_scratch/out5" 2> "$f2_scratch/err5"
  f2c5=$?
  { [ "$f2c5" -eq 1 ] && [ ! -s "$f2_scratch/out5" ] \
      && [ "$(cat "$f2_scratch/err5")" = "$f2_path: $f2_msg" ]; } || {
    printf 'sibling %s exit=%s stdout=[%s] stderr=[%s]\n' "$f2_path" "$f2c5" \
      "$(cat "$f2_scratch/out5")" "$(cat "$f2_scratch/err5")"
    f2_sib_ok=0
  }
}
f2_sibling "$f2_dir" "not a regular file"
f2_sibling "$f2_dir" "not a regular file" --serror-exit 0
f2_sibling "$f2_fifo" "not a regular file"
f2_sibling "$f2_fifo" "not a regular file" --serror-exit 0
if [ "$(id -u)" -eq 0 ]; then
  echo "SKIP-D-UNUSABLE-FILE-CHANNEL-UNREADABLE (running as root: chmod 000 does not deny root)"
else
  f2_sibling "$f2_unread" "cannot be read"
  f2_sibling "$f2_unread" "cannot be read" --serror-exit 0
fi
chmod 700 "$f2_unread"
[ "$f2_sib_ok" -eq 1 ] \
  && echo PASS-D-UNUSABLE-FILE-CHANNEL \
  || { echo "FAIL-D-UNUSABLE-FILE-CHANNEL"; rm -rf "$f2_scratch"; exit 1; }

# M4 fixes round 3 (opus R3-2): the FOURTH sibling, the PRELUDE read.
# TOT_PRELUDE makes that path operator-controlled and it is reached on
# every ordinary check/run, but round 2 fixed the target file only, so
# surface/bootstrap.ml's read_prelude_src still guarded on
# Sys.file_exists and then read unguarded. Measured on the round-2
# binary, with a VALID target file throughout: a directory and an
# unreadable file each printed `Fatal error: exception Sys_error(...)`
# and exited 2, a FIFO did not exit at all (124 at the watchdog, no
# output), and a MISSING path under --serror-exit 0 exited 0 -- the
# fail-open the round-2 log itself argued must not happen. All four now
# take the target file's contract: stdout EMPTY, one driver line on
# stderr, the literal exit 1, OUTSIDE the --serror-exit mapping. Each
# case is probed twice, bare and with --serror-exit 0, under
# "$watchdog" "$MED" so a re-blocking open is a loud 124 rather than a
# stalled battery. The unreadable case carries the same root guard as
# the sibling block above (ctxcat r3 id 1).
pre_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-prelude.XXXXXX")
pre_ok="$pre_scratch/ok.tot"
pre_dir="$pre_scratch/adir"
pre_unread="$pre_scratch/unreadable.tot"
pre_fifo="$pre_scratch/pipe.tot"
pre_missing="$pre_scratch/no-such-prelude.tot"
printf 'def x : Bool := true\n' > "$pre_ok"
mkdir "$pre_dir"
printf 'def y : Bool := true\n' > "$pre_unread"
chmod 000 "$pre_unread"
mkfifo "$pre_fifo"
pre_gate_ok=1
# $1 the TOT_PRELUDE value, $2 the expected stderr tail, then any extra
# flags. Pins all three channels at once: exit 1, EMPTY stdout, exactly
# the driver line, with the target file valid throughout.
pre_probe() {
  pre_path=$1
  pre_msg=$2
  shift 2
  env TOT_PRELUDE="$pre_path" "$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check "$@" \
    "$pre_ok" > "$pre_scratch/out" 2> "$pre_scratch/err"
  pre_code=$?
  { [ "$pre_code" -eq 1 ] && [ ! -s "$pre_scratch/out" ] \
      && [ "$(cat "$pre_scratch/err")" = "prelude: $pre_path: $pre_msg" ]; } || {
    printf 'prelude %s exit=%s stdout=[%s] stderr=[%s]\n' "$pre_path" "$pre_code" \
      "$(cat "$pre_scratch/out")" "$(cat "$pre_scratch/err")"
    pre_gate_ok=0
  }
}
pre_probe "$pre_dir" "not a regular file"
pre_probe "$pre_dir" "not a regular file" --serror-exit 0
pre_probe "$pre_fifo" "not a regular file"
pre_probe "$pre_fifo" "not a regular file" --serror-exit 0
pre_probe "$pre_missing" "no such file"
pre_probe "$pre_missing" "no such file" --serror-exit 0
if [ "$(id -u)" -eq 0 ]; then
  echo "SKIP-D-PRELUDE-CHANNEL-UNREADABLE (running as root: chmod 000 does not deny root)"
else
  pre_probe "$pre_unread" "cannot be read"
  pre_probe "$pre_unread" "cannot be read" --serror-exit 0
fi
chmod 700 "$pre_unread"
rm -rf "$pre_scratch"
[ "$pre_gate_ok" -eq 1 ] \
  && echo PASS-D-PRELUDE-CHANNEL \
  || { echo "FAIL-D-PRELUDE-CHANNEL"; exit 1; }

# audit F2, the flag surface: an unknown flag and a pathless invocation
# both report on STDERR and exit 2, with stdout untouched.
"$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check --bogus-flag /dev/null \
  > "$f2_scratch/out3" 2> "$f2_scratch/err3"
f2c3=$?
"$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe check \
  > "$f2_scratch/out4" 2> "$f2_scratch/err4"
f2c4=$?
{ [ "$f2c3" -eq 2 ] && [ "$f2c4" -eq 2 ] \
    && [ ! -s "$f2_scratch/out3" ] && [ ! -s "$f2_scratch/out4" ] \
    && [ "$(cat "$f2_scratch/err3")" = "unknown flag: --bogus-flag" ] \
    && rg -q '^usage: tot ' "$f2_scratch/err4"; } \
  && echo PASS-D-USAGE-CHANNEL \
  || {
    cat "$f2_scratch/out3" "$f2_scratch/err3" "$f2_scratch/out4" "$f2_scratch/err4" 2> /dev/null
    echo "FAIL-D-USAGE-CHANNEL (exit=$f2c3/$f2c4)"
    rm -rf "$f2_scratch"
    exit 1
  }
rm -rf "$f2_scratch"

# ---------------------------------------------------------------------
# M5 STAGE A (plan section A10): JSON conformance, the strict-json
# posture, and the two fence pins.  Eight legs, each with a mutation
# proof recorded in dev/M5-BUILD-LOG.md.  Every leg wears the numeric
# watchdog literal 30 (the MED value Stage D's tier conversion maps 30
# to); Stage D's conversion list gains these sites.
#
# The cache legs above unset TOT_PRELUDE.  Every guard and tot-copy
# invocation below needs the explicit override again (the PATH-shim
# COPY of tot cannot resolve the prelude from its own location; the
# same reason the export at the top of Gate D exists).  Re-exported
# here and unset again at the end of this section, so the environment
# the downstream legs see is exactly what it was before.
# ---------------------------------------------------------------------
export TOT_PRELUDE="$ROOT"/stdlib/prelude.tot

# PASS-M5A-BYPASS (pin 13).  The headline exploit: a banned binary
# spelled through a \uXXXX escape used to fall open to allow (exit 0,
# empty stdout, measured at M4 HEAD, plan A0 rows 1, 9, 10, 12).  All
# four escaped spellings must now decode and DENY with the exact
# house-rule envelope.  MUTATION PROOF: delete the '\\' :: 'u' arm from
# Interp.json_string_body; all four flip back to exit 0, empty stdout.
# M5 Stage D (plan D3): the echoed-command suffix lands here too;
# each decoded payload has its own expected envelope (the pair and
# bmp fixtures decode to raw UTF-8 on the wire, >= 0x80 unescaped).
m5a_want='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo)"}}'
# deny.json's envelope again ($want is a reused name upstream and no
# longer holds Gate D's value by the time this section runs)
m5a_want_deny='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo /tmp/x)"}}'
m5a_want_pair='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep 😀)"}}'
m5a_want_bmp='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep é)"}}'
m5a_o1=$("$watchdog" "$MED" "$guard" < "$fx/m5a-bypass.json"); m5a_c1=$?
m5a_o2=$("$watchdog" "$MED" "$guard" < "$fx/m5a-pair.json"); m5a_c2=$?
m5a_o3=$("$watchdog" "$MED" "$guard" < "$fx/m5a-bmp.json"); m5a_c3=$?
m5a_o4=$("$watchdog" "$MED" "$guard" < "$fx/m5a-name-esc.json"); m5a_c4=$?
{ [ "$m5a_c1" -eq 2 ] && [ "$m5a_o1" = "$m5a_want" ] \
  && [ "$m5a_c2" -eq 2 ] && [ "$m5a_o2" = "$m5a_want_pair" ] \
  && [ "$m5a_c3" -eq 2 ] && [ "$m5a_o3" = "$m5a_want_bmp" ] \
  && [ "$m5a_c4" -eq 2 ] && [ "$m5a_o4" = "$m5a_want" ]; } \
  && echo PASS-M5A-BYPASS \
  || {
    printf '%s\n%s\n%s\n%s\n' "$m5a_o1" "$m5a_o2" "$m5a_o3" "$m5a_o4"
    echo "FAIL-M5A-BYPASS (exit=$m5a_c1/$m5a_c2/$m5a_c3/$m5a_c4)"
    exit 1
  }

# PASS-M5A-FIXTURE-BYTES.  The bypass fixture must still carry the
# LITERAL six characters \u0067 (the authoring path once normalised a
# typed escape to a plain "grep foo", which already denies at M4 HEAD,
# turning PASS-M5A-BYPASS into a vacuous pass; plan A7).  Asserted on
# rg's EXIT STATUS, never on absent output.  MUTATION PROOF: rewrite
# the fixture with a decoded g; rg exits 1 and this leg fails.
"$watchdog" "$MED" rg -c '\\u0067rep' "$fx/m5a-bypass.json" > /dev/null 2>&1 \
  && echo PASS-M5A-FIXTURE-BYTES \
  || { echo "FAIL-M5A-FIXTURE-BYTES (the fixture lost its literal backslash-u escape)"; exit 1; }

# PASS-M5A-ENVELOPE-VALID (pin 13).  Two rewired call sites, one leg,
# two mutation proofs, because one site must not certify the other.
# (a) The verdict ENVELOPE (surface/effect.ml): a deny message
# carrying a raw CR and a raw 0x01 must render as \r and \u0001, and
# the whole line must satisfy a CONFORMING parser (python3
# json.loads); at M4 HEAD json.loads rejected it (plan A0 row 15).
# MUTATION PROOF (a): revert the envelope site to Pp.escape_string;
# json.loads exits 1.
# (b) The SERIALIZER's jstr site (lib/interp.ml): jsonSerialize on a
# CR-carrying string must emit the two-character escape \r, never the
# raw byte, and the emitted text must satisfy json.loads.  The plan's
# round-trip NONE oracle is unbuildable against this repo: a raw C0
# byte inside a string body still PARSES (deliberate non-change 1 of
# plan A2, re-probed 2026-09-02), so the second jsonParse cannot
# return none and only the emitted BYTES discriminate.  Conflict note
# in dev/M5-BUILD-LOG.md; the mutation is unchanged, the oracle half
# is replaced, the leg is not shrunk.  MUTATION PROOF (b): revert the
# jstr site to Pp.escape_string; the line loses the literal \r (a raw
# CR is not the two-character sequence) and json.loads exits 1.
printf 'def main : IO Verdict := pureIO Verdict (deny "a\\rb\001c")\n' > "$tot_scratch/m5a-envelope.tot"
m5a_env=$("$watchdog" "$MED" "$tot_scratch/tot" run "$tot_scratch/m5a-envelope.tot"); m5a_envc=$?
printf '%s' "$m5a_env" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' > /dev/null 2>&1; m5a_pyc=$?
printf 'def main : IO Verdict :=\n  let* String Verdict s := pureIO String (jsonSerialize (jstr "x\\ry")) in\n  let* Unit Verdict u := printLine s in\n  pureIO Verdict allow\n' > "$tot_scratch/m5a-ser.tot"
m5a_ser=$("$watchdog" "$MED" "$tot_scratch/tot" run "$tot_scratch/m5a-ser.tot"); m5a_serc=$?
printf '%s' "$m5a_ser" | python3 -c 'import json,sys; json.loads(sys.stdin.read())' > /dev/null 2>&1; m5a_serpy=$?
{ [ "$m5a_envc" -eq 2 ] && [ "$m5a_pyc" -eq 0 ] \
  && printf '%s' "$m5a_env" | rg -qF '\r' \
  && printf '%s' "$m5a_env" | rg -qF '\u0001' \
  && [ "$m5a_serc" -eq 0 ] && [ "$m5a_serpy" -eq 0 ] \
  && printf '%s' "$m5a_ser" | rg -qF '\r'; } \
  && echo PASS-M5A-ENVELOPE-VALID \
  || {
    printf '%s\n%s\n' "$m5a_env" "$m5a_ser"
    echo "FAIL-M5A-ENVELOPE-VALID (exit=$m5a_envc py=$m5a_pyc ser=$m5a_serc serpy=$m5a_serpy)"
    exit 1
  }

# PASS-M5A-LONE-SURROGATE (pin 13).  The six non-conforming escape
# shapes each fail the WHOLE parse, and with the flag OFF the guard
# still falls open: exit 0, EMPTY stdout, for every one.  The guard
# half alone would be VACUOUS under a parser that silently ACCEPTED a
# lone surrogate (an accepted \ud800 command still allows), so the leg
# also requires the suite's DIRECT parse assertion, M5A-J7, replayed
# in the kernel-suite output captured at the top of this battery.
# MUTATION PROOF: drop the two surrogate guards in the parser's \u
# arm; M5A-J7 fails (json_parse_top "\"\\ud800\"" returns Some), the
# suite goes red, and this leg's rg on the replay finds no PASS line.
m5a_lsok=1
for m5a_f in m5a-lone-hi m5a-lone-lo m5a-short m5a-nonhex m5a-hi-plain m5a-hi-nonlow; do
  m5a_lo=$("$watchdog" "$MED" "$guard" < "$fx/$m5a_f.json"); m5a_lc=$?
  { [ "$m5a_lc" -eq 0 ] && [ -z "$m5a_lo" ]; } || { printf '%s: exit=%s out=[%s]\n' "$m5a_f" "$m5a_lc" "$m5a_lo"; m5a_lsok=0; }
done
{ [ "$m5a_lsok" -eq 1 ] \
  && printf '%s\n' "$main_out" | rg -q '^PASS M5A-J7'; } \
  && echo PASS-M5A-LONE-SURROGATE \
  || { echo "FAIL-M5A-LONE-SURROGATE"; exit 1; }

# PASS-M5A-FENCE-PI (pin 15, amendment A5).  A self-recursive
# occurrence under a Pi CODOMAIN keeps self_rec = true, so PXf stays
# outside zero_eliminable and eliminating it at mode w is Erased_use.
# The control fixture (same shape, no self recursion) pins the flip
# target: it already exits 0 (plan A0 row 24).  MUTATION PROOF: change
# lib/totality.ml's Pi arm to walk the DOMAIN only; self_rec goes
# false and this leg fails.  OBSERVED route (Stage A build log,
# re-proved 2026-09-03): the mutated tree still rejects the fixture,
# but on the structural termination guard, so the exit stays nonzero
# and the leg flips on the missing 'erased variable px' text, not on
# the plan's predicted exit 0.  NOT a
# mutation: skipping Pi DOMAINS, refuted by strict positivity (no
# admissible declaration has a domain occurrence; plan A5 conflict
# note, probe A0 row 23).
m5a_pi=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$fx/m5a-fence-pi.tot" 2>&1); m5a_pic=$?
m5a_pictl=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$fx/m5a-fence-pi-ctl.tot" 2>&1); m5a_pictlc=$?
{ [ "$m5a_pic" -ne 0 ] \
  && printf '%s\n' "$m5a_pi" | rg -q 'erased variable px used at runtime' \
  && [ "$m5a_pictlc" -eq 0 ]; } \
  && echo PASS-M5A-FENCE-PI \
  || {
    printf '%s\n%s\n' "$m5a_pi" "$m5a_pictl"
    echo "FAIL-M5A-FENCE-PI (exit=$m5a_pic/$m5a_pictlc)"
    exit 1
  }

# PASS-M5A-PARAM-LEVEL (pin 16, amendment A5).  The parameter-level
# predicativity exemption (lib/check.ml discards the inferred
# parameter level) is what makes Acc check; the index and
# constructor-argument bounds still bite.  Three fixtures, three
# mutation proofs, no leg certifying another: (1) bound the parameter
# fold like the index fold; the POSITIVE fixture fails (PBox and Acc
# both reject).  (2) drop the constructor-argument bound; KBad checks
# and the pinned Bad_ctor text disappears.  (3) drop the index bound;
# IBad checks.
m5a_pl=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$fx/m5a-param-level.tot" 2>&1); m5a_plc=$?
m5a_pn=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$fx/m5a-param-level-neg.tot" 2>&1); m5a_pnc=$?
m5a_in=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$fx/m5a-index-level-neg.tot" 2>&1); m5a_inc=$?
{ [ "$m5a_plc" -eq 0 ] \
  && [ "$m5a_pnc" -ne 0 ] \
  && printf '%s\n' "$m5a_pn" | rg -q 'invalid constructor kmk: constructor argument lives above the declared universe' \
  && [ "$m5a_inc" -ne 0 ] \
  && printf '%s\n' "$m5a_in" | rg -q 'inductive IBad: index t lives above the declared universe'; } \
  && echo PASS-M5A-PARAM-LEVEL \
  || {
    printf '%s\n%s\n%s\n' "$m5a_pl" "$m5a_pn" "$m5a_in"
    echo "FAIL-M5A-PARAM-LEVEL (exit=$m5a_plc/$m5a_pnc/$m5a_inc)"
    exit 1
  }

# PASS-M5A-STRICT-DENY (pin 20, amendment A2).  Under --strict-json a
# payload that is not one well-formed JSON value DENIES with exit 2
# and the fixed reason string.  garbage.json is obvious garbage; the
# lone-surrogate payload proves the flag covers a NON-CONFORMING
# payload the \u work still refuses, not only non-JSON.  MUTATION
# PROOF: make the strict guard in Effect.dispatch unconditional false;
# both runs flip to exit 0, empty stdout (the M4 HEAD posture, plan A0
# rows 26 and 3).
m5a_sdwant='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"strict-json: stdin is not a single well-formed JSON value"}}'
m5a_sd1=$("$watchdog" "$MED" "$tot_scratch/tot" run --strict-json "$guard" < "$fx/garbage.json"); m5a_sd1c=$?
m5a_sd2=$("$watchdog" "$MED" "$tot_scratch/tot" run --strict-json "$guard" < "$fx/m5a-lone-hi.json"); m5a_sd2c=$?
{ [ "$m5a_sd1c" -eq 2 ] && [ "$m5a_sd1" = "$m5a_sdwant" ] \
  && [ "$m5a_sd2c" -eq 2 ] && [ "$m5a_sd2" = "$m5a_sdwant" ]; } \
  && echo PASS-M5A-STRICT-DENY \
  || {
    printf '%s\n%s\n' "$m5a_sd1" "$m5a_sd2"
    echo "FAIL-M5A-STRICT-DENY (exit=$m5a_sd1c/$m5a_sd2c)"
    exit 1
  }

# PASS-M5A-STRICT-ALLOW (pin 20).  Three assertions: (a) the flag does
# not disturb a real allow, (b) nor a real deny, and (c) WITHOUT the
# flag the garbage payload still falls open, byte-identical to M4
# HEAD.  MUTATION PROOF: default opts.strict_json to true in
# bin/tot.ml; assertion (c) fails (the unflagged garbage run prints
# the strict-json envelope and exits 2).  This is the leg that keeps
# "default off" honest; the deny legs alone cannot see a changed
# default.
m5a_sa1=$("$watchdog" "$MED" "$tot_scratch/tot" run --strict-json "$guard" < "$fx/allow.json"); m5a_sa1c=$?
m5a_sa2=$("$watchdog" "$MED" "$tot_scratch/tot" run --strict-json "$guard" < "$fx/deny.json"); m5a_sa2c=$?
m5a_sa3=$("$watchdog" "$MED" "$tot_scratch/tot" run "$guard" < "$fx/garbage.json"); m5a_sa3c=$?
{ [ "$m5a_sa1c" -eq 0 ] && [ -z "$m5a_sa1" ] \
  && [ "$m5a_sa2c" -eq 2 ] && [ "$m5a_sa2" = "$m5a_want_deny" ] \
  && [ "$m5a_sa3c" -eq 0 ] && [ -z "$m5a_sa3" ]; } \
  && echo PASS-M5A-STRICT-ALLOW \
  || {
    printf '%s\n%s\n%s\n' "$m5a_sa1" "$m5a_sa2" "$m5a_sa3"
    echo "FAIL-M5A-STRICT-ALLOW (exit=$m5a_sa1c/$m5a_sa2c/$m5a_sa3c)"
    exit 1
  }

# end of the M5 Stage A section: restore the unset the cache legs left
unset TOT_PRELUDE

# ---- M5 Stage B (plan B11): instance term sharing.  Five legs.  The
# watchdog literals below are literals on purpose: the named tiers are
# Stage D's contents, and PASS-M5D-TIERS rewrites all five.

# PASS-M5B-SHIFT (pin 2).  The three Term.shift kernel cases, replayed
# from the captured kernel-suite output (the PASS-A-LITERALS pattern).
# MUTATION PROOFS (plan B11): (1) motive cutoff dropped to
# cutoff + |m_idx| flips M5B2; (2) branch cutoff replaced by cutoff + 1
# flips M5B3; (3) an unconditional Var (i + by) flips M5B1.
{ printf '%s\n' "$main_out" | rg -q '^PASS M5B1: ' \
    && printf '%s\n' "$main_out" | rg -q '^PASS M5B2: ' \
    && printf '%s\n' "$main_out" | rg -q '^PASS M5B3: '; } \
  && echo PASS-M5B-SHIFT \
  || { echo "FAIL-M5B-SHIFT"; exit 1; }

# PASS-M5B-SHARE-SIZE (pins 1, 3, 4).  Machine-independent, from the
# same capture: M5B4 checks Term.Auto against SC (SBox^16 Bool) and
# asserts the emitted nest's term_size < 4000 (measured 694 on
# 2026-09-02; the un-shared M4 tree is T(16) = 458714 by the plan B0
# recurrence).  MUTATION PROOF: inline the ISlot arm of islot_term
# (materialize the entry's own term instead of a Var), which is exactly
# the M4 tree; the printed term_size explodes and the < 4000 assertion
# fails.
printf '%s\n' "$main_out" | rg -q '^PASS M5B4: ' \
  && echo PASS-M5B-SHARE-SIZE \
  || { printf '%s\n' "$main_out" | rg 'M5B4'; echo "FAIL-M5B-SHARE-SIZE"; exit 1; }

# PASS-M5B-FUEL-REACHABLE (pin 5 boundary).  Two legs, both through
# `tot run`, so the only path into resolve_auto is the production call
# site (lib/check.ml, the Term.Auto arm) with
# inst_start (inst_fuel globals expected_t): an inst_start-1 unit test
# stays green for ANY bound and duplicates D7/D7b/D7c.  Measured
# 2026-09-02 on the Stage B binary: K = 60 resolved (exit 0, `zero`,
# 0.176s) and K = 61 reported the exact fuel line at exit 1.
# M5 Stage C (conflict note C-C3, 2026-09-02): the C-B2 handoff that
# stood here said Stage C re-bisects K and regenerates both fixtures
# at the new leaf with this oracle unchanged.  The measurement refutes
# the mechanism: with inst_fuel multiplied by 1 + class_count, charge
# and bound are BOTH about quadratic in K on this shape, and
# dev/bisect-inst-classes.sh reports NOLEAF<=488 (61, 122, 244 and 488
# all resolve; K = 976 breaches the 8 MB file ceiling), so NO
# affordable K rejects and the old negative oracle is impossible on
# any committed input.  Per plan section 5 rule 4 the INTENT survives
# and the mechanism moves: both fixtures keep their committed bytes
# (there is no new leaf to regenerate at), the K = 61 leaf fixture now
# must RESOLVE (that flip is the class-count factor working, the M4
# fuel line for this exact file is recorded in the Stage C build log),
# and the exact-fuel-line coverage lives in PASS-M5C-CLASSES-61's
# mutation, which drops the factor and observes this very file's old
# exit-1 line.  MUTATION PROOFS: (1) charge fuel on a memo HIT
# (Stage B M5, recorded); (2) Stage C: drop the (1 + class_count)
# factor from inst_fuel; the K = 61 half exits 1 with the fuel line
# and this leg goes red.
out=$(gate_timed "$MED" M5B-FUEL-REACHABLE-UNDER "$ROOT"/_build/default/bin/tot.exe run \
  "$ROOT"/test/fixtures/m5b-inst-fuel-under.tot)
code=$?
out2=$(gate_timed "$MED" M5B-FUEL-REACHABLE-LEAF "$ROOT"/_build/default/bin/tot.exe run \
  "$ROOT"/test/fixtures/m5b-inst-fuel-leaf.tot)
code2=$?
{ [ "$code" -eq 0 ] && [ "$(printf '%s\n' "$out" | rg -cx 'zero')" = "1" ] \
    && ! printf '%s\n' "$out" | rg -q 'fuel' \
    && [ "$code2" -eq 0 ] && [ "$(printf '%s\n' "$out2" | rg -cx 'zero')" = "1" ] \
    && ! printf '%s\n' "$out2" | rg -q 'fuel'; } \
  && echo PASS-M5B-FUEL-REACHABLE \
  || { printf '%s\n' "$out" "$out2" | tail -n 3; echo "FAIL-M5B-FUEL-REACHABLE (exit=$code/$code2)"; exit 1; }

# PASS-M5B-RUNTIME-IDENTITY (pin 6).  Four files, each pinned to the
# exact runtime line the M4 HEAD binary printed on 2026-09-02 (plan B0
# probes P4, P10, P11, P13): the nest must never change a VALUE, only a
# term's shape.  The memo-key file is here precisely because its value
# depends on WHICH dictionary a slot names; the zero-dict file is the
# 0-quantity dictionary binder whose ELet survives erasure (plan B5
# property 4; the COST half is Stage D's measurement).  MUTATION
# PROOFS: (1) materialize ISlot j as Var (i - 1); memo-key stops
# printing (succ zero) or the re-check rejects.  (2) see the build log
# (the plan's shift-Var mutation is refuted on closed fixtures and
# replaced by Var (i - j), which mis-scopes every nest).  (3) re-derive
# on a memo HIT; no flip HERE (this leg pins output, not cost) and
# PASS-M5B-BRANCHING-20 is the leg that fails on the cost.
# NOT a leg here: chains-800 (plan B12).  gen-inst-chains.py 8 800 has
# no duplicate (class, key) pair, so sharing cannot help it, and the
# per-slot type annotation may make it slightly slower.  It is Stage
# C's check-budget evidence (P12: exit 124 at M4 HEAD); generate it in
# Stage C, not here.
ri_fail=0
for f in m5b-inst-branching-20 m5b-inst-chains-8-40 m5b-inst-zero-dict; do
  out=$(gate_timed "$MED" "M5B-RUNTIME-IDENTITY-$f" "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/$f.tot)
  code=$?
  { [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true'; } \
    || { printf '%s\n' "$out" | tail -n 2; echo "runtime-identity $f (exit=$code)"; ri_fail=1; }
done
out=$(gate_timed "$MED" M5B-RUNTIME-IDENTITY-m4fix-inst-memo-key "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-memo-key.tot)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qxF '(succ zero)'; } \
  || { printf '%s\n' "$out" | tail -n 2; echo "runtime-identity m4fix-inst-memo-key (exit=$code)"; ri_fail=1; }
[ "$ri_fail" -eq 0 ] \
  && echo PASS-M5B-RUNTIME-IDENTITY \
  || { echo "FAIL-M5B-RUNTIME-IDENTITY"; exit 1; }

# ---- M5 Stage C (plan C10): the check budget, the class-count fuel
# factor, and the driver contract.  Seven legs.  Watchdog literals stay
# literals on purpose (Stage D's named tiers rewrite them).  The
# scratch rides the Gate D EXIT trap.
m5c_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m5c.XXXXXX")
m5c_bin="$ROOT"/_build/default/bin/tot.exe
python3 "$ROOT"/dev/gen-inst-chains.py 8 800 > "$m5c_scratch/chains800.tot"
python3 "$ROOT"/dev/gen-inst-chains.py 8 100 > "$m5c_scratch/chains100.tot"
python3 "$ROOT"/dev/gen-inst-fuel.py classes 61 > "$m5c_scratch/cls61.tot"
python3 "$ROOT"/dev/gen-inst-fuel.py classes 122 > "$m5c_scratch/cls122.tot"
printf 'def m5cq : Bool := true\n' > "$m5c_scratch/trivial.tot"

# PASS-M5C-BUDGET-FIRES (pins 10, 19; plan C10).  The 800-box chain
# (measured on M4 HEAD: exit 124 after 60s with BOTH channels empty,
# the no-verdict state this stage replaces) under a 1 ms budget gives
# a VERDICT: the reserved exit 3, an EMPTY stdout, and ONE exact
# stderr line naming the CONFIGURED milliseconds.  Leg 2 adds
# --serror-exit 0: the budget verdict stays OUTSIDE the mapping, so a
# fail-open install cannot turn a no-verdict into an allow (conflict
# note C12.2: --serror-exit 3 is a shipped configuration, so the LINE,
# not the code alone, is the discriminator, and both legs assert it).
# The 30s watchdog is the REACH requirement: the budget cuts only
# between poll sites, so a 124 here means the chains cost sits inside
# a single non-polling call; do not widen this oracle to accept 124.
# MUTATION PROOFS (plan C10): (1) delete the is_check_budget arm from
# run_file's ladder; the cutoff falls through to the script-error arm
# (leg 2 exits 0, leg 1's stderr takes the <path>:<loc>: shape).
# (2) return serror_exit instead of the literal 3 in the budget arm;
# leg 2 exits 0.
bf_want="$m5c_scratch/chains800.tot: check budget exhausted (1 ms)"
bf_out=$("$watchdog" "$MED" "$m5c_bin" check --check-budget-ms 1 \
  "$m5c_scratch/chains800.tot" 2> "$m5c_scratch/bf1.err")
bf_code=$?
bf_err=$(cat "$m5c_scratch/bf1.err")
bf2_out=$("$watchdog" "$MED" "$m5c_bin" check --check-budget-ms 1 --serror-exit 0 \
  "$m5c_scratch/chains800.tot" 2> "$m5c_scratch/bf2.err")
bf2_code=$?
bf2_err=$(cat "$m5c_scratch/bf2.err")
{ [ "$bf_code" -eq 3 ] && [ -z "$bf_out" ] && [ "$bf_err" = "$bf_want" ] \
    && [ "$bf2_code" -eq 3 ] && [ -z "$bf2_out" ] && [ "$bf2_err" = "$bf_want" ]; } \
  && echo PASS-M5C-BUDGET-FIRES \
  || {
    printf '%s\n%s\n' "$bf_err" "$bf2_err"
    echo "FAIL-M5C-BUDGET-FIRES (exit=$bf_code/$bf2_code)"
    exit 1
  }

# PASS-M5C-BUDGET-QUIET (pin 11; plan C10).  No false positive hides
# behind the FIRES leg.  (a) The 100-box chain (same generator, same
# instance table, same poll sites as the 800-box file; 0.65s measured
# on M4 HEAD) under a 60000 ms budget: exit 0 and stdout
# byte-identical to the no-flag run.  The 800-box file itself cannot
# afford a quiet leg (conflict note C12.3: its completion time is
# above 400s by extrapolation).  (b) A trivial one-def target under a
# 1 ms budget: exit 0, empty stderr -- the deadline is captured AFTER
# the prelude bootstrap (bin/tot.ml builds the budget after
# cached_state_of_src returns), and the warm bootstrap alone costs
# about 10 ms of CPU, ten times this budget.  FLAKE CONTROL (plan
# C10): leg (b) ran 20 times before this marker was committed,
# 20 of 20 exit 0 (2026-09-02, under ambient build load).
# MUTATION PROOFS: (1) make the driver poll answer true
# unconditionally; leg (a) exits 3.  (2) capture the deadline BEFORE
# the bootstrap (build the budget in check_or_run); leg (b) exits 3
# (see the build log for the observed mechanism note).
bq_a1=$("$watchdog" "$MED" "$m5c_bin" check --check-budget-ms 60000 \
  "$m5c_scratch/chains100.tot" 2> "$m5c_scratch/qa1.err")
bq_c1=$?
bq_a0=$("$watchdog" "$MED" "$m5c_bin" check "$m5c_scratch/chains100.tot" 2> "$m5c_scratch/qa0.err")
bq_c0=$?
bq_b=$("$watchdog" "$MED" "$m5c_bin" check --check-budget-ms 1 \
  "$m5c_scratch/trivial.tot" 2> "$m5c_scratch/qb.err")
bq_cb=$?
{ [ "$bq_c1" -eq 0 ] && [ "$bq_c0" -eq 0 ] && [ "$bq_a1" = "$bq_a0" ] \
    && [ "$bq_cb" -eq 0 ] && [ ! -s "$m5c_scratch/qb.err" ]; } \
  && echo PASS-M5C-BUDGET-QUIET \
  || {
    cat "$m5c_scratch/qa1.err" "$m5c_scratch/qb.err"
    echo "FAIL-M5C-BUDGET-QUIET (exit=$bq_c1/$bq_c0/$bq_cb)"
    exit 1
  }

# PASS-M5C-DETERMINISM (pin 11; plan C10).  With no flag, with
# --check-budget-ms 0 (off IS the default, the pin-11 leg) and with
# --check-budget-ms 60000, each corpus file under each verb produces
# byte-identical stdout, stderr and exit code -- the binary compared
# against ITSELF, so no committed golden bytes and nothing to rot.
# stdin is /dev/null on every run so the two guard-shaped files stay
# deterministic in run mode.  MUTATION PROOFS (plan C10): (1) default
# check_budget_ms to 1; the no-flag run of the 100-box chain exits 3
# while the 60000 run exits 0.  (2) treat ms = 0 as a zero-millisecond
# deadline instead of Budget.unlimited (ms <= 0 -> ms < 0); the
# --check-budget-ms 0 run of the chain exits 3 and the triples differ.
det_fail=0
for det_f in "$ROOT"/examples/church.tot "$ROOT"/examples/guard-classes.tot \
  "$ROOT"/test/fixtures/m4fix-inst-small-reach.tot \
  "$ROOT"/test/fixtures/m4fix-inst-chains.tot "$m5c_scratch/chains100.tot"; do
  for det_v in check run; do
    det_o0=$("$watchdog" "$MED" "$m5c_bin" "$det_v" "$det_f" \
      < /dev/null 2> "$m5c_scratch/det0.err")
    det_c0=$?
    det_oz=$("$watchdog" "$MED" "$m5c_bin" "$det_v" --check-budget-ms 0 "$det_f" \
      < /dev/null 2> "$m5c_scratch/detz.err")
    det_cz=$?
    det_ob=$("$watchdog" "$MED" "$m5c_bin" "$det_v" --check-budget-ms 60000 "$det_f" \
      < /dev/null 2> "$m5c_scratch/detb.err")
    det_cb=$?
    det_e0=$(cat "$m5c_scratch/det0.err")
    det_ez=$(cat "$m5c_scratch/detz.err")
    det_eb=$(cat "$m5c_scratch/detb.err")
    { [ "$det_c0" -eq "$det_cz" ] && [ "$det_c0" -eq "$det_cb" ] \
        && [ "$det_o0" = "$det_oz" ] && [ "$det_o0" = "$det_ob" ] \
        && [ "$det_e0" = "$det_ez" ] && [ "$det_e0" = "$det_eb" ]; } \
      || { echo "determinism $det_f $det_v (exit=$det_c0/$det_cz/$det_cb)"; det_fail=1; }
  done
done
[ "$det_fail" -eq 0 ] \
  && echo PASS-M5C-DETERMINISM \
  || { echo "FAIL-M5C-DETERMINISM"; exit 1; }

# PASS-M5C-CLASSES-61 (pin 12; plan C10).  The measured M4 leaf, PAID:
# the classes-61 shape that reported "exceeded its fuel" at exit 1 in
# 0.16s on M4 HEAD (plan N1, the exact line recorded in the build log)
# now resolves under the class-count factor.  The shape of
# PASS-M4FIX-INST-CLASSES, one class higher.  MUTATION PROOF (plan
# C10): drop the (1 + class_count) factor from inst_fuel; exit 1 with
# the N1 line -- not a prediction, the measured M4 HEAD behavior of
# this exact command.
c61_out=$(gate_timed "$SLOW" M5C-CLASSES-61 "$m5c_bin" run "$m5c_scratch/cls61.tot")
c61_code=$?
{ [ "$c61_code" -eq 0 ] && [ "$(printf '%s\n' "$c61_out" | rg -cx 'zero')" = "1" ] \
    && ! printf '%s\n' "$c61_out" | rg -q 'fuel'; } \
  && echo PASS-M5C-CLASSES-61 \
  || { printf '%s\n' "$c61_out" | tail -n 3; echo "FAIL-M5C-CLASSES-61 (exit=$c61_code)"; exit 1; }

# PASS-M5C-LEAF-MARGIN (pin 12; plan C7/C10).  Runs the bisection's
# recorded pin, not the search (dev/bisect-inst-classes.sh is the
# development instrument; the search costs ~110s).  MEASURED
# 2026-09-02 on this binary, under ambient build load:
#   PROBE K=61  bytes=121645  secs=0.74  RESOLVES
#   PROBE K=122 bytes=461560  secs=1.17  RESOLVES
#   PROBE K=244 bytes=1875784 secs=10.60 RESOLVES
#   PROBE K=488 bytes=7561960 secs=97.58 RESOLVES
#   VERDICT: NOLEAF<=488 (no rejecting K inside the search bound)
# No leaf, so per pin 12 no margin is invented: the pin is the largest
# K that RESOLVED inside the search bound subject to the two
# affordability ceilings (file <= 1 MB, run <= 10 s), which is K = 122
# (461,560 bytes, 1.17s; K = 244 breaches BOTH at 1.9 MB and 10.60s).
# The BINDING constraint is the 1 MB file ceiling.  RE-MEASUREMENT
# RECIPE (preamble 6.3): re-run `zsh dev/bisect-inst-classes.sh` after
# any change to inst_fuel or to build_instance's charge accounting,
# and re-pin K here from its MARGIN-PIN line.  MUTATION PROOFS (plan
# C10): (1) the pin-at-the-leaf mutation is NOT executable in the
# NOLEAF case (there is no leaf to pin at; recorded in the build log
# per preamble 6.2); (2) the immediately checkable one: drop the
# (1 + class_count) factor; this leg fails at exit 1 with the fuel
# line, since K = 122 is far above the M4 leaf of 60.
lm_out=$(gate_timed "$SLOW" M5C-LEAF-MARGIN "$m5c_bin" run "$m5c_scratch/cls122.tot")
lm_code=$?
{ [ "$lm_code" -eq 0 ] && [ "$(printf '%s\n' "$lm_out" | rg -cx 'zero')" = "1" ] \
    && ! printf '%s\n' "$lm_out" | rg -q 'fuel'; } \
  && echo PASS-M5C-LEAF-MARGIN \
  || { printf '%s\n' "$lm_out" | tail -n 3; echo "FAIL-M5C-LEAF-MARGIN (exit=$lm_code)"; exit 1; }

# PASS-M5C-REQUIRE-MAIN-DRIVER (pin 21, amendment A3; plan C10).  A
# mainless target takes the DRIVER contract in all four invocations
# (check/run, bare and under --serror-exit 0): exit 1, EMPTY stdout,
# and stderr equal byte for byte to the UNCHANGED Serror text behind
# the tight ":" separator (pin P21's verbatim text and the M4-HEAD
# text; a widened "<path>: " here would pin a change P21 forbids).  On
# M4 HEAD the two --serror-exit 0 invocations exited 0, which a hook
# reads as allow; that is the behavior A3 removes.  MUTATION PROOF
# (plan C10): restore serror_exit in the missing-main arm; the two
# --serror-exit 0 legs exit 0, the measured M4 behavior.
rm_want="$ROOT/test/fixtures/m4d-nomain.tot:this file must define a driver main, and it does not"
rm1_out=$("$watchdog" "$MED" "$m5c_bin" check --require-main \
  "$ROOT"/test/fixtures/m4d-nomain.tot 2> "$m5c_scratch/rm1.err")
rm1_code=$?
rm1_err=$(cat "$m5c_scratch/rm1.err")
rm2_out=$("$watchdog" "$MED" "$m5c_bin" check --require-main --serror-exit 0 \
  "$ROOT"/test/fixtures/m4d-nomain.tot 2> "$m5c_scratch/rm2.err")
rm2_code=$?
rm2_err=$(cat "$m5c_scratch/rm2.err")
rm3_out=$("$watchdog" "$MED" "$m5c_bin" run --require-main \
  "$ROOT"/test/fixtures/m4d-nomain.tot 2> "$m5c_scratch/rm3.err")
rm3_code=$?
rm3_err=$(cat "$m5c_scratch/rm3.err")
rm4_out=$("$watchdog" "$MED" "$m5c_bin" run --require-main --serror-exit 0 \
  "$ROOT"/test/fixtures/m4d-nomain.tot 2> "$m5c_scratch/rm4.err")
rm4_code=$?
rm4_err=$(cat "$m5c_scratch/rm4.err")
{ [ "$rm1_code" -eq 1 ] && [ -z "$rm1_out" ] && [ "$rm1_err" = "$rm_want" ] \
    && [ "$rm2_code" -eq 1 ] && [ -z "$rm2_out" ] && [ "$rm2_err" = "$rm_want" ] \
    && [ "$rm3_code" -eq 1 ] && [ -z "$rm3_out" ] && [ "$rm3_err" = "$rm_want" ] \
    && [ "$rm4_code" -eq 1 ] && [ -z "$rm4_out" ] && [ "$rm4_err" = "$rm_want" ]; } \
  && echo PASS-M5C-REQUIRE-MAIN-DRIVER \
  || {
    printf '%s\n%s\n%s\n%s\n' "$rm1_err" "$rm2_err" "$rm3_err" "$rm4_err"
    echo "FAIL-M5C-REQUIRE-MAIN-DRIVER (exit=$rm1_code/$rm2_code/$rm3_code/$rm4_code)"
    exit 1
  }

# PASS-M5C-REQUIRE-MAIN-OK (pin 21; plan C10).  The anti-overreach
# half: A3 moves the MAINLESS verdict out of the --serror-exit mapping
# and nothing else.  (1) A target WITH a main still checks clean under
# --require-main --serror-exit 0 (without this leg the DRIVER leg
# passes on a binary that rejects every file).  (2) An ordinary script
# error (unknown name zzz) KEEPS the mapping: exit 0 under
# --serror-exit 0 with the same one-line stderr, before and after
# Stage C (plan N9).  MUTATION PROOF (plan C10): widen the driver arm
# from is_missing_main to every Serror; leg (2) exits 1 instead of 0.
ok1_out=$("$watchdog" "$MED" "$m5c_bin" check --require-main --serror-exit 0 \
  "$ROOT"/examples/guard.tot 2> "$m5c_scratch/ok1.err")
ok1_code=$?
ok1_err=$(cat "$m5c_scratch/ok1.err")
ok2_out=$("$watchdog" "$MED" "$m5c_bin" check --require-main --serror-exit 0 \
  "$ROOT"/test/fixtures/m4d-serror-exit.tot 2> "$m5c_scratch/ok2.err")
ok2_code=$?
ok2_err=$(cat "$m5c_scratch/ok2.err")
ok2_want="$ROOT/test/fixtures/m4d-serror-exit.tot:1:7: unknown name zzz"
{ [ "$ok1_code" -eq 0 ] && [ -z "$ok1_err" ] \
    && [ "$ok2_code" -eq 0 ] && [ "$ok2_err" = "$ok2_want" ]; } \
  && echo PASS-M5C-REQUIRE-MAIN-OK \
  || {
    printf '%s\n%s\n' "$ok1_err" "$ok2_err"
    echo "FAIL-M5C-REQUIRE-MAIN-OK (exit=$ok1_code/$ok2_code)"
    exit 1
  }

# ---------------------------------------------------------------------
# M5 STAGE D (plan sections D1, D2, D5, D9): named tiers, the
# measurement log, the guard echo, the rewrap port and the
# hole-anchor measurement.  Six legs, each with a mutation proof
# recorded in dev/M5-BUILD-LOG.md.  Every Stage D leg sits BEFORE the
# PASS-M4FIX-INST-BRANCHING block (plan D0-3: that leg's comment says
# nothing cheap may depend on it, and it stays true; only its
# round-5 sibling PASS-M5B-BRANCHING-20 sits after it, Stage B's
# placement).  The scratch rides the Gate D EXIT trap.
# ---------------------------------------------------------------------
m5d_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m5d.XXXXXX")
m5d_bin="$ROOT"/_build/default/bin/tot.exe

# Plan D5: the hole-anchor measurement runs FIRST so its ANCHORS line
# is in $GATE_LOG before PASS-M5D-HOLE-ANCHORS and
# PASS-M5D-MEASURE-LOG read it.  The site list (the hand-audit
# channel) goes to scratch, not to battery stdout; run
# `python3 dev/hole-anchors.py` bare to read it.
"$watchdog" "$MED" python3 "$ROOT"/dev/hole-anchors.py --log "$GATE_LOG" \
  > "$m5d_scratch/hole-sites.txt" 2>&1 \
  || { cat "$m5d_scratch/hole-sites.txt"; echo "FAIL-M5D-HOLE-ANCHORS (classifier run failed)"; exit 1; }

# PASS-M5D-TIERS (pin 17; plan D9, D0-2).  Assertion 1 is pin 17's
# oracle EXACTLY as the pin words it: no numeric watchdog literal
# survives, asserted on EXIT STATUS.  Assertions 2 and 3 are the
# positive counts, because an absence assertion alone is satisfied by
# an empty file: N direct tier uses plus 2 BITE_S calibration uses
# pin the live population (18 more perf runs go through gate_timed
# and are pinned by PASS-M5D-MEASURE-LOG's name list, not here).
# N = 122 is a LIVE literal: any stage that adds a direct
# watchdog-plus-tier use raises N by the number it added, measured
# with `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh`
# before and after, and records both numbers in dev/M5-BUILD-LOG.md.
# M5 Stage E raised it 116 -> 122: its three legs add six direct tier
# uses (1 SLOW + 5 FAST), measured with the recipe above before and
# after the edit.
# M6 Stage A (2026-09-03) raised it 122 -> 126: the ACC-CHECKS deletion
# removes one direct call, the WITNESS-REJECTED rewrite removes two
# (three become one), and the seven PASS-M6A-* legs add seven FAST
# calls, net +4, measured with the recipe above before (122) and
# after (126) the edit.
# M6 Stage B (2026-09-03) raised it 126 -> 134: the four PASS-M6B-*
# legs add eight MED calls and delete none, measured with the recipe
# above before (126) and after (134) the edit.
# M6 Stage C (2026-09-03) raised it 134 -> 151: the five PASS-M6C-*
# legs add seventeen calls (14 FAST, 2 MED, 1 SLOW) and delete none,
# measured with the recipe above before (134) and after (151).
# M6 Stage D raised it 151 -> 157: its legs add six direct tier
# uses (2 SLOW + 1 FAST + 3 MED), measured with the recipe above
# before and after the edit.
# M6 Stage E (2026-09-03) raised it 157 -> 166: the five PASS-M6E-*
# legs add nine FAST calls (3 + 2 + 4) and delete none, measured with
# the recipe above before (157) and after (166) the edit.
# M6 Stage G (2026-09-03) raised it 166 -> 167: leg (d) of
# PASS-M6E-REWRAP-SCRUB adds one FAST call and deletes none, measured
# with the recipe above before (166) and after (167) the edit.
# M6 Stage H (2026-09-03) raised it 167 -> 169: the two legs of
# PASS-M6H-HOLE-FENCE-DOMAIN add two FAST calls and delete none,
# measured with the recipe above before (167) and after (169) the
# edit.
# Do not soften -eq to -ge: -ge would stop the delete-one-leg
# mutation from flipping, and that mutation is why the count exists.
# MUTATION PROOFS (plan D9): (1) restore one numeric literal; nolit
# goes 0.  (2) delete one tier leg; tiers drops below N.  (3) rename
# BITE_S to a numeral in the calibration legs; bites goes 0 AND
# nolit goes 0.
rg -q '"\$watchdog" [0-9]' "$ROOT/dev/gates.sh"; m5d_nolit=$?
m5d_tiers=$(rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' "$ROOT/dev/gates.sh")
m5d_bites=$(rg -c '"\$watchdog" "\$BITE_S"' "$ROOT/dev/gates.sh")
# M7 Stage A (plan section 7): the tier literal is RE-DERIVED, not
# guessed.  After the Stage A block landed,
# `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` printed
# 202 (169 at HEAD, plus 33 tier-call lines in the seven new legs).
# The plan predicted 180 from an 11-line estimate that assumed the
# `for` loops of its own probe commands; the build ground rule keeps
# every new leg loop-free, so each fixture run is its own tier line.
# M7 Stage A review round (2026-09-04) raised it 202 -> 205: leg (vii)
# gained three FAST calls, the error-value legs of conflict note C-A13,
# and deleted none.  Measured with the recipe above before (202) and
# after (205) the edit.
# M7 Stage B (2026-09-04) raised it 205 -> 211: the two new legs add
# six direct FAST calls (three per leg), measured with the recipe
# above before (205) and after (211) the edit.
# M7 Stage C (2026-09-04) raised it 211 -> 218: the two new legs add
# seven direct FAST calls, measured with the recipe above before (211)
# and after (218) the edit.
{ [ "$m5d_nolit" -eq 1 ] && [ "$m5d_tiers" -eq 218 ] && [ "$m5d_bites" -eq 2 ] \
  && [ -s "$ROOT/dev/gates.sh" ]; } \
  && echo PASS-M5D-TIERS \
  || { echo "FAIL-M5D-TIERS (nolit=$m5d_nolit tiers=$m5d_tiers bites=$m5d_bites)"; exit 1; }

# PASS-M5D-TIER-BITES (plan D9).  Leg (a): a REAL tot leg gets cut at
# a tier value: the Stage C chains-800 fixture (generated above into
# $m5c_scratch, reused per plan D8; without a budget flag it exceeds
# 60 s with no verdict, SPEC section 6) under FAST is a certain cut
# at exit 124 (probe P26 pins 124 for the GNU coreutils timeout on
# this machine).  Leg (b), calibration: BITE_S must cut a 3 s sleeper
# AND a never-terminating tail -f (probe P26's own shape; this second
# calibration use is what the plan's bites=2 count names, conflict
# note in dev/M5-BUILD-LOG.md), FAST must NOT cut the sleeper, and
# the tier ladder is ordered.  Leg cost is about 15 s: 10 for (a),
# 1 + 1 + 3 for (b); that price buys a real cut plus a cheap
# calibration, stated here so nobody trims it silently.  MUTATION
# PROOFS (plan D9): (1) raise the sleeper calibration from BITE_S to
# FAST; b goes 124 to 0.  (2) BITE_S=5; same flip.  Stated because
# it does NOT flip: raising leg (a) from FAST to SLOW keeps a = 124
# (the fixture exceeds 120 s too), which is why leg (b) exists.
m5d_tb_a=$("$watchdog" "$FAST" "$m5d_bin" check "$m5c_scratch/chains800.tot" 2>&1); m5d_a=$?
"$watchdog" "$BITE_S" sleep 3; m5d_b=$?
"$watchdog" "$BITE_S" tail -f /dev/null; m5d_b2=$?
"$watchdog" "$FAST" sleep 3; m5d_c=$?
{ [ "$m5d_a" -eq 124 ] && [ "$m5d_b" -eq 124 ] && [ "$m5d_b2" -eq 124 ] && [ "$m5d_c" -eq 0 ] \
  && [ "$BITE_S" -lt "$FAST" ] && [ "$FAST" -lt "$MED" ] \
  && [ "$MED" -lt "$SLOW" ] && [ "$SLOW" -le "$SUITE" ]; } \
  && echo PASS-M5D-TIER-BITES \
  || { printf '%s\n' "$m5d_tb_a"; echo "FAIL-M5D-TIER-BITES (a=$m5d_a b=$m5d_b b2=$m5d_b2 c=$m5d_c)"; exit 1; }

# PASS-M5D-GUARD-ECHO (plan D9; depends on Stage A pin 13 and D3).
# The guard emits an envelope carrying an escaped control byte, and
# the SAME binary parses it back and re-emits it byte-identically.
# Four assertions at once: the guard denies (c1 = 2); the readback
# denies with the same reason, so the envelope re-parses (c2 = 2 and
# e2 = e1); the control byte is ESCAPED on the wire (searched as
# u0001 WITHOUT its backslash: three quoting layers sit over one
# assertion); and no raw 0x01 survives (raw = 1).  Keep both of the
# last two: the five characters u0001 could in principle come from
# the echoed command, and the fixed payload plus the raw-byte check
# close that hole together.  At M4 HEAD this payload produced empty
# stdout at exit 0 (probe P51), so the leg was red until Stage A
# landed the parser and Stage D landed the echo.  MUTATION PROOFS
# (plan D9): (1) revert render_verdict's escaper to
# Pp.escape_string; raw goes 0, c2 goes 0, e2 empties.  (2) drop the
# (command: ...) echo from guard.tot; the u0001 assertion fails.
# (3) readback returns allow on a successful parse; c2 goes 0 and e2
# empties.
m5d_payload='{"tool_name":"Bash","tool_input":{"command":"grep \u0001x"}}'
m5d_e1=$(printf '%s' "$m5d_payload" | "$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard.tot); m5d_c1=$?
m5d_e2=$(printf '%s' "$m5d_e1" | "$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/test/fixtures/m5d-echo-readback.tot); m5d_c2=$?
printf '%s' "$m5d_e1" | LC_ALL=C rg -q $'\x01'; m5d_raw=$?
{ [ "$m5d_c1" -eq 2 ] && [ "$m5d_c2" -eq 2 ] && [ "$m5d_e2" = "$m5d_e1" ] \
  && printf '%s' "$m5d_e1" | rg -q 'u0001' && [ "$m5d_raw" -eq 1 ]; } \
  && echo PASS-M5D-GUARD-ECHO \
  || { printf '%s\n' "$m5d_e1"; echo "FAIL-M5D-GUARD-ECHO (c1=$m5d_c1 c2=$m5d_c2 raw=$m5d_raw)"; exit 1; }

# PASS-M5D-REWRAP-GUARD (plan D9; scope item 10's third hook is a
# deliverable with its own marker: one marker over two guards cannot
# say which guard broke, and guard-rewrap.tot can regress to
# allow-everything without moving a byte of guard.tot's envelope).
# The rewrap payload (plan W5's heredoc) DENIES at exit 2 with an
# envelope echoing the offending let line, so a constant-reason
# deny cannot pass; the allow payload allows at exit 0 with EMPTY
# stdout, so a deny-everything guard cannot pass; and the guard
# still type-checks, so a broken port fails loudly rather than
# quietly at run time.  Keep the fixture and the let-line pattern in
# step: if the fixture's let line changes, the pattern changes with
# it.  MUTATION PROOFS (plan D9): (1) rewrapVerdict returns allow
# unconditionally; rd goes 2 to 0 and deny empties.  (2) drop the
# .rs test; the ALLOW leg flips (ra goes 0 to 2).  (3) drop the echo
# from the deny reason; the let-line assertion fails.
m5d_deny=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/m5d-rewrap-deny.json); m5d_rd=$?
m5d_allow=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/m5d-rewrap-allow.json); m5d_ra=$?
m5d_chk=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard-rewrap.tot 2>&1); m5d_rc=$?
{ [ "$m5d_rd" -eq 2 ] && [ "$m5d_ra" -eq 0 ] && [ -z "$m5d_allow" ] && [ "$m5d_rc" -eq 0 ] \
  && printf '%s' "$m5d_deny" | rg -q '"permissionDecision":"deny"' \
  && printf '%s' "$m5d_deny" | rg -q 'let a = h\(\)\?;'; } \
  && echo PASS-M5D-REWRAP-GUARD \
  || { printf '%s\n%s\n%s\n' "$m5d_deny" "$m5d_allow" "$m5d_chk"; \
       echo "FAIL-M5D-REWRAP-GUARD (rd=$m5d_rd ra=$m5d_ra rc=$m5d_rc)"; exit 1; }

# PASS-M5D-HOLE-ANCHORS (plan D9; scope item 11's measurement is a
# deliverable with its own marker: PASS-M5D-MEASURE-LOG only stops
# the log's E and SPEC's E from DRIFTING, and both could be absent
# or wrong together).  Four assertions at once: the ANCHORS line
# EXISTS in $GATE_LOG and matches its schema; the corpus is
# non-empty; the three buckets SUM to the total; and the total
# equals dev/hole-anchors.py --count-sites, an INDEPENDENT walk that
# never calls the classifier and never reads the log (a count
# derived from the classification would agree by construction and
# prove nothing).  MUTATION PROOFS (plan D9): (1) drop the ANCHORS
# line from the script's output; anchors empties.  (2) classify one
# site into no bucket leaving total alone; the sum check fails.
# (3) drop one site from the CLASSIFIER walk only; sum and total
# move together and the sites comparison fails.
m5d_anchors=$(rg -o '^ANCHORS total=[0-9]+ expected-type-only=[0-9]+ argument-driven=[0-9]+ neither=[0-9]+$' "$GATE_LOG")
m5d_at=$(printf '%s' "$m5d_anchors" | rg -o 'total=[0-9]+'              | rg -o '[0-9]+')
m5d_ae=$(printf '%s' "$m5d_anchors" | rg -o 'expected-type-only=[0-9]+' | rg -o '[0-9]+')
m5d_aa=$(printf '%s' "$m5d_anchors" | rg -o 'argument-driven=[0-9]+'    | rg -o '[0-9]+')
m5d_an=$(printf '%s' "$m5d_anchors" | rg -o 'neither=[0-9]+'            | rg -o '[0-9]+')
m5d_sites=$("$watchdog" "$MED" python3 "$ROOT"/dev/hole-anchors.py --count-sites)
{ [ -n "$m5d_anchors" ] && [ "$m5d_at" -gt 0 ] \
  && [ "$((m5d_ae + m5d_aa + m5d_an))" -eq "$m5d_at" ] && [ "$m5d_at" -eq "$m5d_sites" ]; } \
  && echo PASS-M5D-HOLE-ANCHORS \
  || { printf '%s\n' "$m5d_anchors"; \
       echo "FAIL-M5D-HOLE-ANCHORS (t=$m5d_at e=$m5d_ae a=$m5d_aa n=$m5d_an sites=$m5d_sites)"; exit 1; }

# ---------------------------------------------------------------------
# M5 Stage E (SPIKE): well-founded recursion behind --experimental-wf
# (plan E8).  Three legs, each with a mutation proof recorded in
# dev/M5-BUILD-LOG.md.  Placement (Stage E adjudication of the D12
# item 11 caveat, conflict note C-E3 in dev/M5-BUILD-LOG.md): the
# Stage E legs sit BEFORE the two branching legs, so the branching
# pair stays the file's timing-sensitive tail exactly as Stage D left
# it; the Stage B placement of PASS-M5B-BRANCHING-20 after
# PASS-M4FIX-INST-BRANCHING is kept as a recorded no-change.  The
# scratch rides the Gate D EXIT trap.
# ---------------------------------------------------------------------
m5e_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-e.XXXXXX")

# Gate E (i), PASS-M5E-DEFAULT-IDENTITY.  The driver's whole check corpus
# is byte-identical to the transcript resealed at M6 Stage A over the
# 85-file corpus (pin 14), and accRec still fails the shipped guard.
"$watchdog" "$SLOW" "$ROOT"/dev/gen-m5e-transcript.sh > "$m5e_scratch"/m5e-now.txt 2>&1
code=$?
out2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m5e-acc.tot 2>&1)
code2=$?
{ [ "$code" -eq 0 ] && [ "$code2" -eq 1 ] \
    && diff -q "$ROOT"/dev/m5e-default-transcript.txt "$m5e_scratch"/m5e-now.txt > /dev/null \
    && printf '%s\n' "$out2" \
       | rg -q 'm5e-acc\.tot:5:1: recursive definition accRec failed the structural termination guard'; } \
  && echo PASS-M5E-DEFAULT-IDENTITY \
  || {
    diff "$ROOT"/dev/m5e-default-transcript.txt "$m5e_scratch"/m5e-now.txt | head -40
    printf '%s\n' "$out2"
    echo "FAIL-M5E-DEFAULT-IDENTITY (exit=$code/$code2)"
    exit 1
  }

# ---------------------------------------------------------------------
# M6 Stage A (verdict pins 7-10, ruling R1): --experimental-wf and the
# Structural_wf prototype are DELETED.  The WF negative oracles below
# are flag-free on purpose: they are what M7's admission rule is
# rebuilt against.  Gate E (i) keeps its M5 name and remains the
# pin-14 transcript enforcement point over the resealed 85-file
# corpus.  Mutation proofs in dev/M6-BUILD-LOG.md (plan A10).
# ---------------------------------------------------------------------

# Gate E (iii), PASS-M5E-WITNESS-REJECTED, REWRITTEN flag-free (M6
# Stage A, pin 9).  The M5 leg (a) proved the flag live and leg (b)
# probed it; both died with the flag.  What remains is amendment A4's
# pinned negative on the shipped rule.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m5e-witness.tot 2>&1)
code=$?
wantw='m5e-witness.tot:2:1: recursive definition bad failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantw"; } \
  && echo PASS-M5E-WITNESS-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M5E-WITNESS-REJECTED (exit=$code)"; exit 1; }

# Gate A (i), PASS-M6A-WF-FLAG-UNKNOWN (pin 7).  The deleted spelling
# takes the unknown-flag contract (bin/tot.ml unknown-flag arm): one
# stderr line, exit 2, nothing on stdout.  Exact-string match, not a
# substring: a resurrected accept-and-ignore arm would exit 1 with the
# guard line instead, and this leg must see that as red.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  --experimental-wf "$ROOT"/test/fixtures/m5e-acc.tot 2>&1)
code=$?
{ [ "$code" -eq 2 ] && [ "$out" = "unknown flag: --experimental-wf" ]; } \
  && echo PASS-M6A-WF-FLAG-UNKNOWN \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-WF-FLAG-UNKNOWN (exit=$code)"; exit 1; }

# Gate A (ii), PASS-M6A-ACC-GUARD-REJECTED (pin 9).  m5e-acc.tot is
# byte-identical to M5 and now rejects in the ONLY mode there is.
# This is the flag-free replacement for the deleted PASS-M5E-ACC-CHECKS.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m5e-acc.tot 2>&1)
code=$?
wanta='m5e-acc.tot:5:1: recursive definition accRec failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wanta"; } \
  && echo PASS-M6A-ACC-GUARD-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-ACC-GUARD-REJECTED (exit=$code)"; exit 1; }

# Gate A (iii), PASS-M6A-INFINITARY-REJECTED (pin 9).  bad2 was
# ACCEPTED under the M5 flag (plan A0 probe P6); after deletion its
# rejection is the only behaviour, and this leg is what makes the
# deletion irreversible by accident.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/bad2.tot 2>&1)
code=$?
wantb='bad2.tot:2:1: recursive definition bad2 failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantb"; } \
  && echo PASS-M6A-INFINITARY-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-INFINITARY-REJECTED (exit=$code)"; exit 1; }

# Gate A (iv), PASS-M6A-CROSSFORMAL-REJECTED (pin 9).  Rejected at M5
# HEAD in BOTH modes (plan A0 probes P7/P8): what this leg pins is the
# per-candidate Principal seed, not the deleted flag.  It is the
# executable tripwire for any M7 admission rule without a provenance
# side condition (SPEC section 2 entry, 2026-09-03).
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/crossformal-t.tot 2>&1)
code=$?
wantx='crossformal-t.tot:2:1: recursive definition bad failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantx"; } \
  && echo PASS-M6A-CROSSFORMAL-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-CROSSFORMAL-REJECTED (exit=$code)"; exit 1; }

# Gate A (v), PASS-M6A-DEEP2-REJECTED (pin 9).  The depth-2 field
# application, rejected at M5 HEAD even under the flag (probes
# P9/P10): pins the Var-only scrutinee rule.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/deep2.tot 2>&1)
code=$?
wantd='deep2.tot:2:1: recursive definition deep2 failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantd"; } \
  && echo PASS-M6A-DEEP2-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-DEEP2-REJECTED (exit=$code)"; exit 1; }

# Gate A (vi)+(vii), the positivity-fence tripwires (pin 10).  These
# two legs are DESIGNED to go red the day C3 lands nested inductives,
# forcing the Frozen-emptiness and guard questions open on purpose
# (SPEC.md:851-852).  Do not "fix" them by deleting them; re-open the
# design instead.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/nested-pos.tot 2>&1)
code=$?
wantp='nested-pos.tot:2:1: invalid constructor mkt2: negative or non-uniform occurrence of T2'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantp"; } \
  && echo PASS-M6A-FENCE-COVARIANT \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-FENCE-COVARIANT (exit=$code)"; exit 1; }

out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/nested-neg.tot 2>&1)
code=$?
wantn='nested-neg.tot:2:1: invalid constructor mkt3: negative or non-uniform occurrence of T3'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantn"; } \
  && echo PASS-M6A-FENCE-CONTRAVARIANT \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-FENCE-CONTRAVARIANT (exit=$code)"; exit 1; }

# ---- M6 Stage B (plan B8): the blocking Unit strict-json posture
# (verdict pins 5-6, ruling R3).  Four legs.  None is gate_timed, so
# the PASS-M5D-MEASURE-LOG literal (count 18, pinned name set) does
# not move.  The IO Unit fixture is GENERATED into the Gate D scratch
# dir on purpose (the m5a-envelope.tot precedent): a new
# test/fixtures/*.tot would enter the gen-m5e-transcript.sh glob and
# force a transcript reseal this stage does not need (pin 14).
printf 'def main : IO Unit := let* String Unit raw := readStdin in printLine raw\n' \
  > "$tot_scratch"/m6b-unit-echo.tot
m6b_uerr="$tot_scratch/m6b-unit-echo.tot:stdin is not a single well-formed JSON value, and this installation runs with --strict-json"
m6b_env='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"strict-json: stdin is not a single well-formed JSON value"}}'
m6b_err_f=$(mktemp "${TMPDIR:-/tmp}/tot-gate-m6b-err.XXXXXX")

# PASS-M6B-UNIT-STRICT-EXIT2 (pin 5, ruling R3).  Under --strict-json
# a malformed stdin payload on an IO Unit script exits 2 with the
# SAME single stderr line M5 printed at exit 1 (tight ":" after the
# argv path), and NOTHING on stdout.  The explicit -ne 1 is the
# NEGATIVE of the migration: it states in the leg's own text that the
# OLD exit-1 route is gone (at HEAD this run measured exit=1, plan
# B0 P1/P11).  MUTATION PROOF: plan B9 rows M-B1, M-B2, M-B3.
m6b_x1=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --strict-json \
  "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json 2>"$m6b_err_f"); m6b_x1c=$?
m6b_x1e=$(cat "$m6b_err_f")
{ [ "$m6b_x1c" -eq 2 ] && [ "$m6b_x1c" -ne 1 ] && [ -z "$m6b_x1" ] \
    && [ "$m6b_x1e" = "$m6b_uerr" ]; } \
  && echo PASS-M6B-UNIT-STRICT-EXIT2 \
  || {
    printf '%s\n%s\n' "$m6b_x1" "$m6b_x1e"
    echo "FAIL-M6B-UNIT-STRICT-EXIT2 (exit=$m6b_x1c)"
    exit 1
  }

# PASS-M6B-UNIT-STRICT-NOMAP (pin 5).  The refusal is the literal 2
# under EVERY --serror-exit value: 0 (a fail-open install cannot
# remap it to a silent allow), 1 (the sharp one: it distinguishes
# the literal 2 from BOTH dead routes at once, the old literal 1 and
# a route through the default mapping, which is also 1), and 7 (the
# mapping value plainly not taken; at HEAD this run measured exit=1,
# plan B0 P2).  Same stderr line, empty stdout, all three.
# MUTATION PROOF: plan B9 row M-B2.
m6b_n0=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --serror-exit 0 \
  --strict-json "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json \
  2>"$m6b_err_f"); m6b_n0c=$?
m6b_n0e=$(cat "$m6b_err_f")
m6b_n1=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --serror-exit 1 \
  --strict-json "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json \
  2>"$m6b_err_f"); m6b_n1c=$?
m6b_n1e=$(cat "$m6b_err_f")
m6b_n7=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --serror-exit 7 \
  --strict-json "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json \
  2>"$m6b_err_f"); m6b_n7c=$?
m6b_n7e=$(cat "$m6b_err_f")
{ [ "$m6b_n0c" -eq 2 ] && [ "$m6b_n1c" -eq 2 ] && [ "$m6b_n7c" -eq 2 ] \
    && [ -z "$m6b_n0" ] && [ -z "$m6b_n1" ] && [ -z "$m6b_n7" ] \
    && [ "$m6b_n0e" = "$m6b_uerr" ] && [ "$m6b_n1e" = "$m6b_uerr" ] \
    && [ "$m6b_n7e" = "$m6b_uerr" ]; } \
  && echo PASS-M6B-UNIT-STRICT-NOMAP \
  || {
    printf '%s\n%s\n%s\n' "$m6b_n0e" "$m6b_n1e" "$m6b_n7e"
    echo "FAIL-M6B-UNIT-STRICT-NOMAP (exit=$m6b_n0c/$m6b_n1c/$m6b_n7c)"
    exit 1
  }

# PASS-M6B-VERDICT-STRICT-IDENTITY (pin 6).  The IO Verdict half of
# the strict posture does not move: deny envelope on stdout, nothing
# on stderr, exit 2, and --serror-exit 7 cannot touch it (the
# ok-path literal, surface/run.ml Rejected arm).  Byte-identical to
# the HEAD before-picture (plan B0 P6/P7).  MUTATION PROOF: plan B9
# row M-B5.
m6b_v1=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --strict-json \
  "$guard" < "$fx"/garbage.json 2>"$m6b_err_f"); m6b_v1c=$?
m6b_v1e=$(cat "$m6b_err_f")
m6b_v2=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --serror-exit 7 \
  --strict-json "$guard" < "$fx"/garbage.json); m6b_v2c=$?
{ [ "$m6b_v1c" -eq 2 ] && [ "$m6b_v1" = "$m6b_env" ] && [ -z "$m6b_v1e" ] \
    && [ "$m6b_v2c" -eq 2 ] && [ "$m6b_v2" = "$m6b_env" ]; } \
  && echo PASS-M6B-VERDICT-STRICT-IDENTITY \
  || {
    printf '%s\n%s\n' "$m6b_v1" "$m6b_v2"
    echo "FAIL-M6B-VERDICT-STRICT-IDENTITY (exit=$m6b_v1c/$m6b_v2c)"
    exit 1
  }

# PASS-M6B-OPEN-IDENTITY (pin 6).  WITHOUT the flag both shapes keep
# the fail-open posture byte-identical to HEAD: the Unit script
# echoes the garbage and exits 0 (the printLine echo PRECEDES the
# per-item def line, and the payload's own trailing newline yields
# the interior blank line: plan B0 P4/P10 measured these exact
# bytes), and the Verdict guard allows at exit 0 with empty stdout
# (plan B0 P8).  This is the leg that keeps "default off" honest for
# the UNIT shape, which no M5 leg covered (plan B0 P15).
# MUTATION PROOF: plan B9 row M-B4.
m6b_owant=$'not json at all\n\ndef main : (IO Unit)'
m6b_o1=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run \
  "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json 2>"$m6b_err_f"); m6b_o1c=$?
m6b_o1e=$(cat "$m6b_err_f")
m6b_o2=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run \
  "$guard" < "$fx"/garbage.json); m6b_o2c=$?
{ [ "$m6b_o1c" -eq 0 ] && [ "$m6b_o1" = "$m6b_owant" ] && [ -z "$m6b_o1e" ] \
    && [ "$m6b_o2c" -eq 0 ] && [ -z "$m6b_o2" ]; } \
  && echo PASS-M6B-OPEN-IDENTITY \
  || {
    printf '%s\n%s\n' "$m6b_o1" "$m6b_o2"
    echo "FAIL-M6B-OPEN-IDENTITY (exit=$m6b_o1c/$m6b_o2c)"
    exit 1
  }
rm -f "$m6b_err_f"
# ---- end of the M6 Stage B section

# ---------------------------------------------------------------------
# M6 Stage C: holes core (verdict pins 1-4), underscore reservation
# (ruling R2).  Five markers.  All fixtures committed under
# test/fixtures/, so the transcript corpus grew 85 -> 96 in this
# stage's own commit (pin 14) and Gate C (v) leg (a) holds the reseal.
# ---------------------------------------------------------------------
m6c_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m6c.XXXXXX")

# Gate C (i), PASS-M6C-HOLE-RESOLVES.  The conservativity oracle
# (pin 1): the holed fixture and its explicit twin check at exit 0
# with byte-identical output.  The sentinel rg kills the both-empty
# vacuous pass.  MUT-C3 and MUT-C4 must flip this leg.
outh=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-e.tot 2>&1)
codeh=$?
oute=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-e-explicit.tot 2>&1)
codee=$?
{ [ "$codeh" -eq 0 ] && [ "$codee" -eq 0 ] && [ "$outh" = "$oute" ] \
    && printf '%s\n' "$outh" | rg -q 'def flagged : \(List String\)'; } \
  && echo PASS-M6C-HOLE-RESOLVES \
  || {
    printf '%s\n---\n%s\n' "$outh" "$oute"
    echo "FAIL-M6C-HOLE-RESOLVES (exit=$codeh/$codee)"
    exit 1
  }

# Gate C (ii), PASS-M6C-HOLE-REPORTS.  One A-shaped and three
# N-shaped refusals, each exit 1, stdout EMPTY, stderr exactly one
# pinned pin-3 line.  MUT-C2 flips legs (c)/(d); MUT-C3 flips (a).
#
# M7 Stage A (plan A7 item 1) RE-POINTS leg (a).  The M6 fixture
# test/fixtures/m6c-hole-a.tot binds `readStdin`, which determines the
# slot under the argument-driven rule, so that file is green now and
# PASS-M7A-ARGHOLE-RESOLVES owns it.  Leg (a) moves to
# dev/m7a/arg-exhausted.tot, whose every later argument is a hole, so
# nothing determines the slot in either position.  The leg keeps its
# name, its four sub-legs, its column and its message.  Nothing is
# deleted: the M6 rule is to re-open a tripwire's design.
#
# M7 Stage C (pin 7, C-C1): 2026-09-04.  Sub-leg (a) moves to the pin 7
# shape.  Pin 7 prints a position-only tail as a SECOND stderr line for
# an item that holds more than one term-position hole.
# dev/m7a/arg-exhausted.tot holds three such holes (2:8, 2:35, 2:37),
# so a.err now has two lines.  Line 1 keeps the pinned pin-3 line, with
# no change.  Line 2 is pinned byte for byte to the tail the binary
# prints.  Sub-legs (b), (c) and (d) keep one line each.  The leg name,
# the markers, the exit codes and the empty-stdout checks do not move.
outa=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/arg-exhausted.tot 2> "$m6c_scratch"/a.err)
codea=$?
outb=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-infer.tot 2> "$m6c_scratch"/b.err)
codeb=$?
outc=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-proof.tot 2> "$m6c_scratch"/c.err)
codec=$?
outd=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-class.tot 2> "$m6c_scratch"/d.err)
coded=$?
{ [ "$codea" -eq 1 ] && [ "$codeb" -eq 1 ] && [ "$codec" -eq 1 ] && [ "$coded" -eq 1 ] \
    && [ -z "$outa" ] && [ -z "$outb" ] && [ -z "$outc" ] && [ -z "$outd" ] \
    && [ "$(wc -l < "$m6c_scratch"/a.err)" -eq 2 ] \
    && [ "$(wc -l < "$m6c_scratch"/b.err)" -eq 1 ] \
    && [ "$(wc -l < "$m6c_scratch"/c.err)" -eq 1 ] \
    && [ "$(wc -l < "$m6c_scratch"/d.err)" -eq 1 ] \
    && rg -q '^\S*/arg-exhausted\.tot:2:8: hole: expected Type 0$' "$m6c_scratch"/a.err \
    && [ "$(awk 'NR==2' "$m6c_scratch"/a.err)" = '2 more hole(s) at 2:35, 2:37' ] \
    && rg -q '^\S*/m6c-hole-n-infer\.tot:1:6: hole: no expected type at this position$' "$m6c_scratch"/b.err \
    && rg -q '^\S*/m6c-hole-n-proof\.tot:1:38: hole: expected Type 0$' "$m6c_scratch"/c.err \
    && rg -q '^\S*/m6c-hole-n-class\.tot:1:51: hole: expected Type 0$' "$m6c_scratch"/d.err; } \
  && echo PASS-M6C-HOLE-REPORTS \
  || {
    cat "$m6c_scratch"/a.err "$m6c_scratch"/b.err "$m6c_scratch"/c.err "$m6c_scratch"/d.err
    echo "FAIL-M6C-HOLE-REPORTS (exit=$codea/$codeb/$codec/$coded)"
    exit 1
  }

# Gate C (iii), PASS-M6C-HOLE-NEVER-RUNS.  A holed file never
# reaches eval: run refuses BEFORE main, stdout stays empty, and the
# serror mapping moves only the exit code, never the effects.
#
# M7 Stage A (plan A7 item 2) RE-SPELLS the fixture, in place.  Its M6
# spelling holed the let* A slot, which `printLine "SIDE-EFFECT"` now
# determines, so the file would check and then RUN and this leg would
# watch a file that no longer refuses.  The hole moves to the pureIO
# payload, which nothing determines.  The side effect stays where it
# was.  The leg keeps every assertion and changes one pinned string,
# from `1:28: hole: expected Type 0` to `1:82: hole: expected Unit`.
outr=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe run \
  "$ROOT"/test/fixtures/m6c-hole-run.tot 2> "$m6c_scratch"/r.err)
coder=$?
outs=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe run \
  --serror-exit 0 "$ROOT"/test/fixtures/m6c-hole-run.tot 2> "$m6c_scratch"/s.err)
codes=$?
{ [ "$coder" -eq 1 ] && [ "$codes" -eq 0 ] \
    && [ -z "$outr" ] && [ -z "$outs" ] \
    && rg -q 'm6c-hole-run\.tot:1:82: hole: expected Unit' "$m6c_scratch"/r.err \
    && rg -q 'm6c-hole-run\.tot:1:82: hole: expected Unit' "$m6c_scratch"/s.err \
    && { rg -q 'SIDE-EFFECT' "$m6c_scratch"/r.err; [ $? -eq 1 ]; }; } \
  && echo PASS-M6C-HOLE-NEVER-RUNS \
  || {
    cat "$m6c_scratch"/r.err "$m6c_scratch"/s.err
    echo "FAIL-M6C-HOLE-NEVER-RUNS (exit=$coder/$codes)"
    exit 1
  }

# Gate H, PASS-M6H-HOLE-FENCE-DOMAIN (conflict C-G2, ruling of
# 2026-09-03).  A hole at a FENCED argument slot above the leading
# type formals reports the INSTANTIATED declared domain of its slot,
# not "no expected type at this position".  The fence still refuses
# the hole: nothing is filled, both legs exit 1 with empty stdout.
# Leg (a) is the proof-set trigger of the fence (`refl`, whose
# declared type mentions `Eq`), leg (b) the class-former trigger
# (`member`, fenced by `EqD`).  Both stderr files carry exactly one
# whole-line-anchored pinned line.  MUT-H1 flips both legs from the
# source; MUT-H2 flips leg (a) and MUT-H3 leg (b) from the fixtures.
outfa=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6h-hole-n-fence-proof.tot 2> "$m6c_scratch"/fa.err)
codefa=$?
outfb=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6h-hole-n-fence-class.tot 2> "$m6c_scratch"/fb.err)
codefb=$?
{ [ "$codefa" -eq 1 ] && [ "$codefb" -eq 1 ] \
    && [ -z "$outfa" ] && [ -z "$outfb" ] \
    && [ "$(wc -l < "$m6c_scratch"/fa.err)" -eq 1 ] \
    && [ "$(wc -l < "$m6c_scratch"/fb.err)" -eq 1 ] \
    && rg -q '^\S*/m6h-hole-n-fence-proof\.tot:1:42: hole: expected Nat$' "$m6c_scratch"/fa.err \
    && rg -q '^\S*/m6h-hole-n-fence-class\.tot:1:65: hole: expected \(List String\)$' "$m6c_scratch"/fb.err; } \
  && echo PASS-M6H-HOLE-FENCE-DOMAIN \
  || {
    cat "$m6c_scratch"/fa.err "$m6c_scratch"/fb.err
    echo "FAIL-M6H-HOLE-FENCE-DOMAIN (exit=$codefa/$codefb)"
    exit 1
  }

# Gate C (iv), PASS-M6C-UNDERSCORE-RESERVED.  The three pin-2
# fixtures fail with their pinned lines (legs a-c), and the binder
# positions stay green with the exact four-line output (leg d).
# MUT-C1 flips leg (a); MUT-C5 and MUT-C6 flip leg (d).
outud=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-underscore-def.tot 2> "$m6c_scratch"/ud.err)
codeud=$?
outul=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-underscore-lam.tot 2> "$m6c_scratch"/ul.err)
codeul=$?
outum=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-underscore-match.tot 2> "$m6c_scratch"/um.err)
codeum=$?
outub=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-underscore-binders.tot 2>&1)
codeub=$?
wantub=$'def k : (w _ : Nat) -> Nat\ndef two2 : (w _ : (List Nat)) -> Nat\ndef _foo : Nat\ndef useIt : Nat'
{ [ "$codeud" -eq 1 ] && [ "$codeul" -eq 1 ] && [ "$codeum" -eq 1 ] && [ "$codeub" -eq 0 ] \
    && [ -z "$outud" ] && [ -z "$outul" ] && [ -z "$outum" ] \
    && rg -q "m6c-underscore-def\.tot:1:5: parse error: expected 'NAME : TYPE := TERM' after 'def', found '_'" "$m6c_scratch"/ud.err \
    && rg -q 'm6c-underscore-lam\.tot:1:32: hole: expected Nat' "$m6c_scratch"/ul.err \
    && rg -q 'm6c-underscore-match\.tot:1:72: hole: expected Nat' "$m6c_scratch"/um.err \
    && [ "$outub" = "$wantub" ]; } \
  && echo PASS-M6C-UNDERSCORE-RESERVED \
  || {
    cat "$m6c_scratch"/ud.err "$m6c_scratch"/ul.err "$m6c_scratch"/um.err
    printf '%s\n' "$outub"
    echo "FAIL-M6C-UNDERSCORE-RESERVED (exit=$codeud/$codeul/$codeum/$codeub)"
    exit 1
  }

# Gate C (v), PASS-M6C-DEFAULT-IDENTITY.  Two legs.  Leg (a): the
# whole 96-file corpus is byte-identical to the transcript resealed
# in this stage's commit; the reseal diff was reviewed
# additions-only (pin 14).  Leg (b): a COLD bootstrap under a fresh
# private cache re-lexes and re-checks the prelude through the
# reserved lexer and agrees byte for byte with the warm run; this is
# the stdlib half of the corpus-zero-break proof, which the
# transcript (examples + fixtures only) cannot see.  Probed green at
# HEAD in the plan's C0.
"$watchdog" "$SLOW" "$ROOT"/dev/gen-m5e-transcript.sh > "$m6c_scratch"/now.txt 2>&1
codet=$?
outw=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/examples/guard.tot 2>&1)
codew=$?
outcold=$(TOT_CACHE_DIR="$m6c_scratch"/cold "$watchdog" "$MED" \
  "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/examples/guard.tot 2>&1)
codecold=$?
outw2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/examples/guard-classes.tot 2>&1)
codew2=$?
outcold2=$(TOT_CACHE_DIR="$m6c_scratch"/cold2 "$watchdog" "$MED" \
  "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/examples/guard-classes.tot 2>&1)
codecold2=$?
{ [ "$codet" -eq 0 ] \
    && diff -q "$ROOT"/dev/m5e-default-transcript.txt "$m6c_scratch"/now.txt > /dev/null \
    && [ "$codew" -eq 0 ] && [ "$codecold" -eq 0 ] && [ "$outw" = "$outcold" ] \
    && [ "$codew2" -eq 0 ] && [ "$codecold2" -eq 0 ] && [ "$outw2" = "$outcold2" ]; } \
  && echo PASS-M6C-DEFAULT-IDENTITY \
  || {
    diff "$ROOT"/dev/m5e-default-transcript.txt "$m6c_scratch"/now.txt | head -40
    echo "FAIL-M6C-DEFAULT-IDENTITY (exit=$codet/$codew/$codecold/$codew2/$codecold2)"
    exit 1
  }

# ---------------------------------------------------------------------
# M6 Stage D: the two cost legs (verdict pins 11-13, ruling R4).
# Five legs, no binary change. m6d_scratch rides the one EXIT trap
# at the top of the file (line 434 lists it).
# ---------------------------------------------------------------------
m6d_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m6d.XXXXXX")
mkdir -p "$m6d_scratch/warm" "$m6d_scratch/cold" "$m6d_scratch/cb1" "$m6d_scratch/cb2"
: > "$m6d_scratch/ratio.log"
# One BARE timed run (conflict note D0-2: the watchdog spawn costs
# about 4 ms, measured, which is 80 percent of the healthy signal;
# both fixtures are proven terminating under a WRAPPED run in
# PASS-M6D-HIT-RATIO before any bare run happens, and check is
# deterministic). Appends one RATIO row to the leg-local log.
m6d_time() {
  local m6d_t0=$SECONDS
  env TOT_CACHE_DIR="$m6d_scratch/warm" "$ROOT"/_build/default/bin/tot.exe \
    check "$2" > /dev/null 2>&1
  local m6d_c=$?
  printf 'RATIO %s elapsed=%.3f exit=%d\n' "$1" "$((SECONDS - m6d_t0))" "$m6d_c" \
    >> "$m6d_scratch/ratio.log"
}

# PASS-M6D-HIT-BASELINE (pin 11).  The one-resolution fixture checks
# at exit 0 with the EXACT two-line stdout probed on 2026-09-03. A
# checker that stops resolving `member String auto` exits 1 (the
# unresolved-instance error), and a checker that prints anything
# else breaks the byte pin, so the ratio leg below never runs
# against a fixture that is not doing the work. This wrapped run
# also warms the block's private cache dir.
m6d_base=$(gate_timed "$FAST" M6D-HIT-BASELINE env \
  TOT_CACHE_DIR="$m6d_scratch/warm" "$ROOT"/_build/default/bin/tot.exe \
  check "$ROOT"/test/fixtures/m6d-hit-one.tot); m6d_bc=$?
m6d_wantbase=$'def flagged : (List String)\ndef u1 : Bool'
{ [ "$m6d_bc" -eq 0 ] && [ "$m6d_base" = "$m6d_wantbase" ]; } \
  && echo PASS-M6D-HIT-BASELINE \
  || { printf '%s\n' "$m6d_base"; echo "FAIL-M6D-HIT-BASELINE (exit=$m6d_bc)"; exit 1; }

# PASS-M6D-HIT-RATIO (pin 11; ruling R4: threshold 4.0). Protocol:
# two WRAPPED termination proofs, then 9 bare timed runs per
# fixture (conflict note D0-2), medians compared multiplicatively
# so no division can blow up. Honest constants, both measured
# median-of-9: judge 2026-09-03 healthy 30.4 ms vs 39.0 ms = 1.28;
# this machine 2026-09-03 healthy 0.005 s vs 0.007 s = 1.40; the
# attack's probe-bounded mutated ratio is near 8. 4.0 sits above
# measured noise and below the measured failure. The floor
# m6d_one > 0 refuses a timer that cannot resolve the signal.
# The two MEASURE rows below are DERIVED medians: their exit=0 is
# asserted first over all 18 underlying runs (m6d_ok), then
# written literally.
m6d_w1=$("$watchdog" "$SLOW" env TOT_CACHE_DIR="$m6d_scratch/warm" \
  "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6d-hit-one.tot 2>&1); m6d_wc1=$?
m6d_w2=$("$watchdog" "$SLOW" env TOT_CACHE_DIR="$m6d_scratch/warm" \
  "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6d-hit-many.tot 2>&1); m6d_wc2=$?
{ [ "$m6d_wc1" -eq 0 ] && [ "$m6d_wc2" -eq 0 ]; } \
  || { printf '%s\n%s\n' "$m6d_w1" "$m6d_w2"; \
       echo "FAIL-M6D-HIT-RATIO (warmup exit=$m6d_wc1/$m6d_wc2)"; exit 1; }
m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
m6d_one=$(rg '^RATIO ONE ' "$m6d_scratch/ratio.log" \
  | rg -o 'elapsed=[0-9]+\.[0-9]{3}' | rg -o '[0-9]+\.[0-9]{3}' \
  | sort -n | head -n 5 | tail -n 1)
m6d_many=$(rg '^RATIO MANY ' "$m6d_scratch/ratio.log" \
  | rg -o 'elapsed=[0-9]+\.[0-9]{3}' | rg -o '[0-9]+\.[0-9]{3}' \
  | sort -n | head -n 5 | tail -n 1)
m6d_ok=$(rg -c '^RATIO (ONE|MANY) elapsed=[0-9]+\.[0-9]{3} exit=0$' "$m6d_scratch/ratio.log")
{ [ "$m6d_ok" -eq 18 ] && [ "$(( m6d_one > 0 ))" -eq 1 ] \
    && [ "$(( m6d_many <= 4.0 * m6d_one ))" -eq 1 ]; } \
  && { printf 'MEASURE M6D-HIT-ONE tier=%s elapsed=%.3f exit=0\n' "$SLOW" "$m6d_one" >> "$GATE_LOG"; \
       printf 'MEASURE M6D-HIT-MANY tier=%s elapsed=%.3f exit=0\n' "$SLOW" "$m6d_many" >> "$GATE_LOG"; \
       echo PASS-M6D-HIT-RATIO; } \
  || { cat "$m6d_scratch/ratio.log"; \
       echo "FAIL-M6D-HIT-RATIO (one=$m6d_one many=$m6d_many ok=$m6d_ok)"; exit 1; }

# PASS-M6D-COLD-WINDOW (pin 12).  (pre) The scratch cache dir holds
# ZERO prelude-*.bin entries before the run, so a reused dir (a
# warm leg wearing a cold name) fails here, not silently. (a) The
# cold run bootstraps the prelude from source, exits 0, and its
# MEASURE row records the cold window; the row is a measurement,
# never a ceiling ("A tier is a HANG ceiling, not a performance
# budget", the line this file pins at its top). (b) The warm rerun
# in the SAME dir loads the store and must produce byte-identical
# output. Probed green at HEAD on 2026-09-03: cold 0.017 s, warm
# 0.006 s, identical bytes, empty stderr both sides (D0-4).
m6d_pre_a=( "$m6d_scratch/cold"/prelude-*.bin(N) )
m6d_pre=${#m6d_pre_a}
m6d_coldout=$(gate_timed "$SLOW" M6D-COLD-WINDOW env \
  TOT_CACHE_DIR="$m6d_scratch/cold" "$ROOT"/_build/default/bin/tot.exe \
  check "$ROOT"/test/fixtures/m6d-hit-one.tot); m6d_cc=$?
m6d_warmout=$("$watchdog" "$FAST" env TOT_CACHE_DIR="$m6d_scratch/cold" \
  "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6d-hit-one.tot 2>&1); m6d_wc=$?
{ [ "$m6d_pre" -eq 0 ] && [ "$m6d_cc" -eq 0 ] && [ "$m6d_wc" -eq 0 ] \
    && [ -n "$m6d_coldout" ] && [ "$m6d_coldout" = "$m6d_warmout" ]; } \
  && echo PASS-M6D-COLD-WINDOW \
  || { printf '%s\n%s\n' "$m6d_coldout" "$m6d_warmout"; \
       echo "FAIL-M6D-COLD-WINDOW (pre=$m6d_pre exit=$m6d_cc/$m6d_wc)"; exit 1; }

# PASS-M6D-COLD-STORE (pin 12, the entry-count graft). After the
# WINDOW pair the scratch store holds EXACTLY ONE prelude-*.bin
# (surface/cache.ml:335 names the entries). Zero means the save
# path died and the "warm" identity above compared two cold runs;
# more than one means the key wobbled between two invocations of
# the same binary over the same prelude. The exeid-*.txt stat-memo
# sidecar also lives in this dir (probed 2026-09-03) and is NOT
# counted; the pattern is prelude-*.bin on purpose.
m6d_store_a=( "$m6d_scratch/cold"/prelude-*.bin(N) )
m6d_store=${#m6d_store_a}
[ "$m6d_store" -eq 1 ] \
  && echo PASS-M6D-COLD-STORE \
  || { ls -l "$m6d_scratch/cold"; \
       echo "FAIL-M6D-COLD-STORE (store=$m6d_store)"; exit 1; }

# PASS-M6D-COLD-OUTSIDE-BUDGET (pin 12).  The deadline is captured
# AFTER cached_state_of_src returns (bin/tot.ml:165-166), so a cold
# bootstrap is outside the budget by construction.
# (a) cold + trivial + 5 ms: exit 0, empty stderr. Kept from pin
#     12; the hoist mutation CANNOT flip this run (C-C6, 5 of 5:
#     under 1024 polls the clock is never read), which is exactly
#     why (b) exists.
# (b) cold + m6d-bigcheck + 5 ms: exit 0, empty stderr. Healthy
#     bracket probed 2026-09-03: the file fires at budget 1 and
#     passes at budget 5 warm AND cold. Under the hoist mutation
#     the deadline predates the bootstrap, the cold window (5 to
#     15 ms wall probed, 2026-09-03) spends the 5 ms budget before
#     the target's first clock read, and the read at poll 1024
#     fires: exit 3, `m6d-bigcheck.tot: check budget exhausted
#     (5 ms)`. FLAKE CONTROL: run (b) 20 times before committing
#     this marker and record 20 of 20 exit 0 (the M5C leg-(b)
#     precedent).
# (c) warm + m6d-bigcheck + 1 ms: exit 3, EMPTY stdout, stderr
#     exactly the exit-3 line naming 1 ms. This pins the target's
#     >1024-poll, >1 ms-CPU property, so (b)'s mutation hook stays
#     fireable; a shrunken target fails HERE first.
m6d_ba=$("$watchdog" "$MED" env TOT_CACHE_DIR="$m6d_scratch/cb1" \
  "$ROOT"/_build/default/bin/tot.exe check --check-budget-ms 5 \
  "$ROOT"/test/fixtures/m6d-hit-one.tot 2> "$m6d_scratch/ba.err"); m6d_ca=$?
m6d_bb=$("$watchdog" "$MED" env TOT_CACHE_DIR="$m6d_scratch/cb2" \
  "$ROOT"/_build/default/bin/tot.exe check --check-budget-ms 5 \
  "$ROOT"/test/fixtures/m6d-bigcheck.tot 2> "$m6d_scratch/bb.err"); m6d_cb=$?
m6d_bcout=$("$watchdog" "$MED" env TOT_CACHE_DIR="$m6d_scratch/warm" \
  "$ROOT"/_build/default/bin/tot.exe check --check-budget-ms 1 \
  "$ROOT"/test/fixtures/m6d-bigcheck.tot 2> "$m6d_scratch/bc.err"); m6d_cc3=$?
{ [ "$m6d_ca" -eq 0 ] && [ ! -s "$m6d_scratch/ba.err" ] \
    && [ "$m6d_cb" -eq 0 ] && [ ! -s "$m6d_scratch/bb.err" ] \
    && [ "$m6d_cc3" -eq 3 ] && [ -z "$m6d_bcout" ] \
    && rg -q 'm6d-bigcheck\.tot: check budget exhausted \(1 ms\)$' "$m6d_scratch/bc.err"; } \
  && echo PASS-M6D-COLD-OUTSIDE-BUDGET \
  || { cat "$m6d_scratch/ba.err" "$m6d_scratch/bb.err" "$m6d_scratch/bc.err"; \
       echo "FAIL-M6D-COLD-OUTSIDE-BUDGET (exit=$m6d_ca/$m6d_cb/$m6d_cc3)"; exit 1; }

# PASS-M5D-MEASURE-LOG (verdict item 6; plan D9).  Four assertions
# against $GATE_LOG, run after every UPSTREAM perf leg: the schema'd
# MEASURE line count equals 18; the LC_ALL=C-sorted name set equals
# the pinned literal below (a LITERAL on purpose: deriving it by
# counting gate_timed call sites would drop both numbers together
# when a wrapper is deleted, the exact vacuity this gate exists to
# refuse); the log's expected-type-only number equals SPEC.md's, so
# the SPEC number cannot drift from the script that produced it; and
# every wrapped leg exited 0.  The two DOWNSTREAM wrapped legs
# (M4FIX-INST-BRANCHING and M5B-BRANCHING-20, the file's last two by
# the round-5 placement plan D0-3 preserves) log AFTER this gate
# runs; their MEASURE lines are for the operator via the battery-end
# GATE-LOG line, not for this assertion.  A leg with several CLI
# runs logs one MEASURE line per run under a marker-prefixed name
# (recorded in dev/M5-BUILD-LOG.md).  MUTATION PROOFS (plan D9):
# (1) delete one gate_timed wrapper; the log loses one line and one
# name.  (2) move SPEC's expected-type-only by one; logE and specE
# differ.  (3) print elapsed=%d instead of %.3f; the schema count
# goes 0.
# M6 Stage D (pin 13): count 18 -> 22 and the gate moved below the
# M6D legs so it still runs after every wrapped leg it counts; the
# two branching legs stay the file's tail. The four new rows:
# M6D-HIT-BASELINE and M6D-COLD-WINDOW from gate_timed, plus
# M6D-HIT-ONE and M6D-HIT-MANY, DERIVED median rows the ratio leg
# writes only after asserting all 18 underlying exits are 0. The
# count stays a literal; never re-derive it from call sites.
m5d_lines=$(rg -c '^MEASURE [A-Za-z0-9-]+ tier=[0-9]+ elapsed=[0-9]+\.[0-9]{3} exit=[0-9]+$' "$GATE_LOG")
m5d_okexit=$(rg -c '^MEASURE [A-Za-z0-9-]+ tier=[0-9]+ elapsed=[0-9]+\.[0-9]{3} exit=0$' "$GATE_LOG")
m5d_names=$(rg -o '^MEASURE [A-Za-z0-9-]+' "$GATE_LOG" | rg -o '[A-Za-z0-9-]+$' | LC_ALL=C sort | tr '\n' ' ')
m5d_wantnames='M4FIX-INST-BINDERS M4FIX-INST-CHAINS M4FIX-INST-CLASSES M4FIX-INST-MEMO-KEY M4FIX-INST-SMALL-REACH M4FIX-INST-SPEC16 M4FIX-INST-TWOCLASS M4FIX-INST-WIDE M5B-FUEL-REACHABLE-LEAF M5B-FUEL-REACHABLE-UNDER M5B-RUNTIME-IDENTITY-m4fix-inst-memo-key M5B-RUNTIME-IDENTITY-m5b-inst-branching-20 M5B-RUNTIME-IDENTITY-m5b-inst-chains-8-40 M5B-RUNTIME-IDENTITY-m5b-inst-zero-dict M5C-CLASSES-61 M5C-LEAF-MARGIN M6D-COLD-WINDOW M6D-HIT-BASELINE M6D-HIT-MANY M6D-HIT-ONE SUITE-KERNEL SUITE-SURFACE '
m5d_logE=$(rg -o 'expected-type-only=[0-9]+' "$GATE_LOG")
# M6 Stage E (2026-09-03, plan E4): SPEC.md now spells the literal
# more than once (the M5 baseline and the current record);  the
# NEWEST record is the textually LAST one, so `| tail -n 1` reads it.
# Stage C's one-spelling rule (C-C5) is retired by this splice.
m5d_specE=$(rg -o 'expected-type-only=[0-9]+' "$ROOT/SPEC.md" | tail -n 1)
{ [ "$m5d_lines" -eq 22 ] && [ "$m5d_okexit" -eq 22 ] \
  && [ "$m5d_names" = "$m5d_wantnames" ] \
  && [ -n "$m5d_logE" ] && [ "$m5d_logE" = "$m5d_specE" ]; } \
  && echo PASS-M5D-MEASURE-LOG \
  || { cat "$GATE_LOG"; \
       echo "FAIL-M5D-MEASURE-LOG (lines=$m5d_lines ok=$m5d_okexit names=[$m5d_names] logE=$m5d_logE specE=$m5d_specE)"; exit 1; }

# ---------------------------------------------------------------------
# M6 Stage E: corpus growth and reseal (M6 plan, Stage E section E7).
# Five legs, each with a mutation proof in dev/M6-BUILD-LOG.md.
# Placement: after the M5E block and the relocated PASS-M5D-MEASURE-LOG
# block (Stage D's tail move), before the ctxcat id 5 comment and the
# two branching legs, which stay the file's tail.  No new scratch, no
# gate_timed: these legs reuse $m5d_bin, $m5d_scratch/hole-sites.txt
# and $GATE_LOG from Gate D, and the EXIT trap at the top of the file
# already owns the cleanup.
# ---------------------------------------------------------------------

# PASS-M6E-REWRAP-SCRUB (scope-in 7).  Criterion 3 is live: a rewrap
# pair inside a Rust block comment (a) or a multi-line string (b) no
# longer false-denies (both denied at HEAD, probes P12/P13,
# 2026-09-03), and the genuine pair (c) still denies with the echoed
# let line, so a scrub-everything mutation cannot pass.  M6 Stage G
# (2026-09-03, opus findings 1-2): leg (d) is a genuine pair that
# FOLLOWS a `//` inside a string literal and a plain `//` comment
# line;  it still denies, so a selective over-scrub (a `//` inside a
# string opening a phantom string state, the pre-G behaviour) cannot
# pass either.  MUT-G4 flips (d).
m6e_sc=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/m6e-rewrap-scrub-comment.json); m6e_c1=$?
m6e_ss=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/m6e-rewrap-scrub-string.json); m6e_c2=$?
m6e_sd=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/m5d-rewrap-deny.json); m6e_c3=$?
m6e_sg=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/m6g-rewrap-deny-slash.json); m6e_cg=$?
{ [ "$m6e_c1" -eq 0 ] && [ -z "$m6e_sc" ] \
  && [ "$m6e_c2" -eq 0 ] && [ -z "$m6e_ss" ] \
  && [ "$m6e_c3" -eq 2 ] \
  && printf '%s' "$m6e_sd" | rg -q 'let a = h\(\)\?;' \
  && [ "$m6e_cg" -eq 2 ] \
  && printf '%s' "$m6e_sg" | rg -q 'let a = h\(\)\?;'; } \
  && echo PASS-M6E-REWRAP-SCRUB \
  || { printf '%s\n%s\n%s\n%s\n' "$m6e_sc" "$m6e_ss" "$m6e_sd" "$m6e_sg"; \
       echo "FAIL-M6E-REWRAP-SCRUB (c1=$m6e_c1 c2=$m6e_c2 c3=$m6e_c3 cg=$m6e_cg)"; exit 1; }

# PASS-M6E-REWRAP-OPEN.  The fail-open posture survives the port: a
# non-JSON payload and a non-Bash payload both allow at exit 0 with
# empty stdout (HEAD behaviour, probes P17/P18, re-pinned so the
# scrubber commit cannot flip the posture).
m6e_og=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/garbage.json); m6e_c4=$?
m6e_oo=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/other.json); m6e_c5=$?
{ [ "$m6e_c4" -eq 0 ] && [ -z "$m6e_og" ] \
  && [ "$m6e_c5" -eq 0 ] && [ -z "$m6e_oo" ]; } \
  && echo PASS-M6E-REWRAP-OPEN \
  || { printf '%s\n%s\n' "$m6e_og" "$m6e_oo"; \
       echo "FAIL-M6E-REWRAP-OPEN (c4=$m6e_c4 c5=$m6e_c5)"; exit 1; }

# PASS-M6E-GUARD-HOLES (scope-in 8, ruling R5).  Six assertions: the
# three re-spelled guards check at exit 0; the site list Gate D's
# classifier run wrote carries exactly 22 holed example anchors
# (anchor=[_]: 19 re-spelled sites plus the scrubber's three, measured
# 2026-09-03 with `python3 dev/hole-anchors.py | rg -c 'anchor=\[_\]'`),
# so an un-respelled tree cannot pass; the prelude carries ZERO holed
# anchors (scope-out 5 enforced); and guard.tot's deny envelope on the
# M3 payload is byte-identical to the pre-respell envelope (probe
# P16), so holes changed no behaviour.
# M7 Stage B (2026-09-04): the literal walks 22 to 26.  The four A
# slots of examples/guard.tot:133-134 and examples/guard-rewrap.tot:
# 264-265 close under Stage A's argument-driven rule and infer settle,
# so they re-spell to holes: 19 re-spelled M6 sites, plus the
# scrubber's three, plus these four Stage B A slots, is 26.
m6e_g1=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard.tot 2>&1); m6e_c6=$?
m6e_g2=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard-rewrap.tot 2>&1); m6e_c7=$?
m6e_g3=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard-classes.tot 2>&1); m6e_c8=$?
m6e_holes=$(rg -c 'anchor=\[_\]' "$m5d_scratch/hole-sites.txt")
rg -q 'SITE stdlib/prelude\.tot:.*anchor=\[_\]' "$m5d_scratch/hole-sites.txt"; m6e_pz=$?
m6e_env=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard.tot \
  < "$ROOT"/test/fixtures/deny.json); m6e_c9=$?
m6e_wantenv='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo /tmp/x)"}}'
{ [ "$m6e_c6" -eq 0 ] && [ "$m6e_c7" -eq 0 ] && [ "$m6e_c8" -eq 0 ] \
  && [ "$m6e_holes" -eq 26 ] && [ "$m6e_pz" -eq 1 ] \
  && [ "$m6e_c9" -eq 2 ] && [ "$m6e_env" = "$m6e_wantenv" ]; } \
  && echo PASS-M6E-GUARD-HOLES \
  || { printf '%s\n%s\n%s\n%s\n' "$m6e_g1" "$m6e_g2" "$m6e_g3" "$m6e_env"; \
       echo "FAIL-M6E-GUARD-HOLES (c=$m6e_c6/$m6e_c7/$m6e_c8 holes=$m6e_holes pz=$m6e_pz env=$m6e_c9)"; exit 1; }

# PASS-M6E-ANCHORS (scope-in 7; pins 4 and 17).  The grown corpus was
# re-measured: the ANCHORS line the classifier wrote into $GATE_LOG
# this run equals the literal recorded from the build-time rerun
# (2026-09-03, `python3 dev/hole-anchors.py | tail -1`), and the total
# grew past the HEAD baseline 98 (the scrubber's list rebuild adds
# headOr/cons/nil sites).  Schema, bucket sum and the independent
# --count-sites recount stay owned by PASS-M5D-HOLE-ANCHORS upstream;
# SPEC-vs-log stays owned by the spliced PASS-M5D-MEASURE-LOG (plan
# E4).
m6e_line=$(rg -o '^ANCHORS total=[0-9]+ expected-type-only=[0-9]+ argument-driven=[0-9]+ neither=[0-9]+$' "$GATE_LOG")
m6e_want='ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30'
m6e_tot=$(printf '%s' "$m6e_line" | rg -o 'total=[0-9]+' | rg -o '[0-9]+')
{ [ "$m6e_line" = "$m6e_want" ] && [ "$m6e_tot" -gt 98 ]; } \
  && echo PASS-M6E-ANCHORS \
  || { printf '%s\n' "$m6e_line"; echo "FAIL-M6E-ANCHORS (tot=$m6e_tot)"; exit 1; }

# PASS-M6E-TRANSCRIPT-RESEALED (pin 14, ruling R5).  The FINAL reseal
# is real and complete: the sealed oracle's block count equals the
# LIVE glob count (a corpus or glob change without a reseal cannot
# pass, and PASS-M5E-DEFAULT-IDENTITY alone cannot see a glob
# narrowed in the generator, mutation M-E7); the guard.tot block is
# byte-identical to the pre-respell block (probe P23: pin-1
# conservativity, holes changed no output byte); and the
# guard-rewrap.tot block carries the scrubber (a stale pre-port seal
# cannot pass).  Whole-file identity against a fresh regeneration
# stays owned by PASS-M5E-DEFAULT-IDENTITY above.  The FAIL branch
# diffs through two scratch files, not process substitution, which
# the build sandbox refuses (Stage E conflict note C-E4).
m6e_blocks=$(rg -c '^### ' "$ROOT"/dev/m5e-default-transcript.txt)
m6e_files=$(ls "$ROOT"/examples/*.tot "$ROOT"/test/fixtures/*.tot | wc -l | tr -d ' ')
m6e_gblock=$(rg -A 13 -x -F '### examples/guard.tot' "$ROOT"/dev/m5e-default-transcript.txt)
m6e_wantg=$'### examples/guard.tot\n#exit 0\n#out\ndef firstNonEmpty : (w _ : (List String)) -> String\ndef lastOr : (w _ : String) -> (w _ : (List String)) -> String\ndef splitEach : (w _ : String) -> (w _ : (List String)) -> (List String)\ndef firstToken : (w _ : String) -> String\ndef baseName : (w _ : String) -> String\ndef usesBanned : (w _ : String) -> Bool\ndef orEmpty : (w _ : (Option String)) -> String\ndef elideAt : (w _ : Int) -> (w _ : String) -> String\ndef decide : (w _ : Json) -> Verdict\ndef main : (IO Verdict)\n#err'
m6e_srub=$(rg -c '^def scrubLines : ' "$ROOT"/dev/m5e-default-transcript.txt)
{ [ "$m6e_blocks" -eq "$m6e_files" ] && [ "$m6e_gblock" = "$m6e_wantg" ] \
  && [ "$m6e_srub" -eq 1 ]; } \
  && echo PASS-M6E-TRANSCRIPT-RESEALED \
  || { echo "FAIL-M6E-TRANSCRIPT-RESEALED (blocks=$m6e_blocks files=$m6e_files scrub=$m6e_srub)"; \
       printf '%s\n' "$m6e_wantg" > "$m5d_scratch/m6e-wantg.txt"; \
       printf '%s\n' "$m6e_gblock" > "$m5d_scratch/m6e-gblock.txt"; \
       diff "$m5d_scratch/m6e-wantg.txt" "$m5d_scratch/m6e-gblock.txt" | head -20; exit 1; }

# ---------------------------------------------------------------------
# M7 Stage A (pins 1, 2, 3, 4, 5 and debt item j): the argument-driven
# capture pass and the infer-path settle.  A hole in a leading erased
# slot may now take its type from a LATER argument.  The same capture
# pass runs where there is no expected type at all, so an `eval` spine
# and a nested argument under a fence settle too.  Seven markers.
# Every new fixture lives under dev/m7a/, which no corpus glob reads,
# so this stage adds no transcript block and moves no budget digest.
# Two committed M6C legs are RE-POINTED above, never deleted: their
# old fixtures are green under the new rule (plan A7).  Mutation
# proofs and every measured literal in dev/M7-BUILD-LOG.md.
# ---------------------------------------------------------------------
m7a_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m7a.XXXXXX")

# Gate M7A (i), PASS-M7A-KERNEL-UNCHANGED (pin 1).  The kernel keeps
# its shape while the elaborator changes: the one totality rule stays
# Structural, `define` still takes ~rule, and the seven frozen kernel
# files keep their concatenated md5.  The fourth leg is behavioural and
# MUST flip: dev/m7a/arg-map.tot exits 1 at HEAD with
# `1:30: hole: expected Type 0` and exits 0 after the stage with the
# line its explicit twin prints.  The existence test runs first, so a
# deleted fixture cannot stand in for a refusal.  MUTATION: buy the
# resolution inside lib/eval.ml; the frozen digest moves and this leg
# fails.
[ -f "$ROOT"/dev/m7a/arg-map.tot ] \
  || { echo "FAIL-M7A-KERNEL-UNCHANGED (MISSING-FIXTURE dev/m7a/arg-map.tot)"; exit 1; }
m7a_rule=$(rg -c '^type rule = Structural$' "$ROOT"/lib/totality.ml)
m7a_define=$(rg -c '~\(rule : Totality\.rule\)' "$ROOT"/lib/check.ml)
m7a_frozen=$(cat "$ROOT"/lib/totality.ml "$ROOT"/lib/term.ml "$ROOT"/lib/eval.ml \
  "$ROOT"/lib/value.ml "$ROOT"/lib/erase.ml "$ROOT"/lib/interp.ml "$ROOT"/lib/error.ml | md5 -q)
m7a_map=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/arg-map.tot 2>&1)
m7a_mapcode=$?
{ [ "$m7a_rule" -eq 1 ] && [ "$m7a_define" -eq 1 ] \
    && [ "$m7a_frozen" = f446f043e1ad6c7b85ddedb7736bd8a1 ] \
    && [ "$m7a_mapcode" -eq 0 ] \
    && printf '%s\n' "$m7a_map" | rg -qx 'def probeF : \(List Nat\)'; } \
  && echo PASS-M7A-KERNEL-UNCHANGED \
  || {
    printf '%s\n' "$m7a_map"
    echo "FAIL-M7A-KERNEL-UNCHANGED (rule=$m7a_rule define=$m7a_define frozen=$m7a_frozen exit=$m7a_mapcode)"
    exit 1
  }

# Gate M7A (ii), PASS-M7A-ARGHOLE-RESOLVES (pin 3, and pin 5 by shape).
# Six holed shapes, one per pin 5 anchor family, each compared against
# its explicit twin: same exit code 0, byte-identical stdout, and the
# shared stdout non-empty, which is the anti-vacuity sentinel
# PASS-M6C-HOLE-RESOLVES uses.  All six exit 1 at HEAD.  Two shapes
# must NOT resolve: dev/m7a/arg-exhausted.tot holds every later
# argument as a hole and keeps `2:8: hole: expected Type 0`, and
# dev/m7a/arg-ambiguous.tot reports the kernel mismatch its explicit
# twin already reports, which proves the pass takes the FIRST fit and
# never widens a slot.  MUTATION: drop the arg_caps call; the six
# twins go red.
[ -f "$ROOT"/dev/m7a/s2-holed.tot ] && [ -f "$ROOT"/dev/m7a/s4-holed.tot ] \
  && [ -f "$ROOT"/dev/m7a/s5-holed.tot ] && [ -f "$ROOT"/dev/m7a/s6-holed.tot ] \
  && [ -f "$ROOT"/dev/m7a/s7-holed.tot ] && [ -f "$ROOT"/dev/m7a/arg-exhausted.tot ] \
  && [ -f "$ROOT"/dev/m7a/arg-ambiguous.tot ] \
  || { echo "FAIL-M7A-ARGHOLE-RESOLVES (MISSING-FIXTURE under dev/m7a)"; exit 1; }
m7a_h1=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-a.tot 2>&1)
m7a_c1=$?
m7a_e1=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s1-explicit.tot 2>&1)
m7a_d1=$?
m7a_h2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s2-holed.tot 2>&1)
m7a_c2=$?
m7a_e2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s2-explicit.tot 2>&1)
m7a_d2=$?
m7a_h3=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s4-holed.tot 2>&1)
m7a_c3=$?
m7a_e3=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s4-explicit.tot 2>&1)
m7a_d3=$?
m7a_h4=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s5-holed.tot 2>&1)
m7a_c4=$?
m7a_e4=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s5-explicit.tot 2>&1)
m7a_d4=$?
m7a_h5=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s6-holed.tot 2>&1)
m7a_c5=$?
m7a_e5=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s6-explicit.tot 2>&1)
m7a_d5=$?
m7a_h6=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s7-holed.tot 2>&1)
m7a_c6=$?
m7a_e6=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s7-explicit.tot 2>&1)
m7a_d6=$?
m7a_ex=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/arg-exhausted.tot 2>&1)
m7a_excode=$?
m7a_amb=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/arg-ambiguous.tot 2>&1)
m7a_ambcode=$?
{ [ "$m7a_c1" -eq 0 ] && [ "$m7a_d1" -eq 0 ] && [ "$m7a_h1" = "$m7a_e1" ] && [ -n "$m7a_h1" ] \
    && [ "$m7a_c2" -eq 0 ] && [ "$m7a_d2" -eq 0 ] && [ "$m7a_h2" = "$m7a_e2" ] && [ -n "$m7a_h2" ] \
    && [ "$m7a_c3" -eq 0 ] && [ "$m7a_d3" -eq 0 ] && [ "$m7a_h3" = "$m7a_e3" ] && [ -n "$m7a_h3" ] \
    && [ "$m7a_c4" -eq 0 ] && [ "$m7a_d4" -eq 0 ] && [ "$m7a_h4" = "$m7a_e4" ] && [ -n "$m7a_h4" ] \
    && [ "$m7a_c5" -eq 0 ] && [ "$m7a_d5" -eq 0 ] && [ "$m7a_h5" = "$m7a_e5" ] && [ -n "$m7a_h5" ] \
    && [ "$m7a_c6" -eq 0 ] && [ "$m7a_d6" -eq 0 ] && [ "$m7a_h6" = "$m7a_e6" ] && [ -n "$m7a_h6" ] \
    && printf '%s\n' "$m7a_h1" | rg -qx 'def main : \(IO Verdict\)' \
    && printf '%s\n' "$m7a_h6" | rg -qx 'def myListEqBy : \(0 A : Type 0\) -> \(w _ : \(w _ : A\) -> \(w _ : A\) -> Bool\) -> \(w _ : \(List A\)\) -> \(w _ : \(List A\)\) -> Bool' \
    && [ "$m7a_excode" -eq 1 ] \
    && printf '%s\n' "$m7a_ex" | rg -q '^\S*/arg-exhausted\.tot:2:8: hole: expected Type 0$' \
    && [ "$m7a_ambcode" -eq 1 ] \
    && printf '%s\n' "$m7a_amb" \
       | rg -q 'type mismatch: expected \(List Nat\), found \(List String\)'; } \
  && echo PASS-M7A-ARGHOLE-RESOLVES \
  || {
    printf '%s\n---\n%s\n---\n%s\n---\n%s\n' "$m7a_h1" "$m7a_e1" "$m7a_ex" "$m7a_amb"
    echo "FAIL-M7A-ARGHOLE-RESOLVES (exit=$m7a_c1/$m7a_d1 $m7a_c2/$m7a_d2 $m7a_c3/$m7a_d3 $m7a_c4/$m7a_d4 $m7a_c5/$m7a_d5 $m7a_c6/$m7a_d6 ex=$m7a_excode amb=$m7a_ambcode)"
    exit 1
  }

# Gate M7A (iii), PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE (pin 2).  Three
# refusals that must NOT move, each for a different reason, paired with
# a control that must move.  `m6c-hole-n-infer.tot` is a bare `eval _`,
# which is no argument of any spine.  `infer-fenced.tot` has a class
# former at the head, so the fence keeps the settle off; its explicit
# twin exits 0, which proves the fence and not a missing capture is the
# reason.  `infer-undetermined.tot` holds every later argument as a
# hole.  Each stderr line is pinned whole, so a new column or a new
# message is a FAIL.  MUTATION: relax the fence; leg (b) moves.
#
# M7 Stage C (pin 7, C-C1): 2026-09-04.  The `infer-undetermined.tot`
# sub-leg moves to the pin 7 shape.  That file holds two term-position
# holes in one item (1:14 and 1:16), so nc.err now has two lines.  Line
# 1 keeps the pinned line, with no change.  Line 2 is pinned byte for
# byte to the tail the binary prints.  The na.err and nb.err sub-legs
# keep one line each.  The leg name, the marker, the exit codes and the
# empty-stdout checks do not move.
[ -f "$ROOT"/dev/m7a/infer-fenced.tot ] && [ -f "$ROOT"/dev/m7a/infer-fenced-explicit.tot ] \
  && [ -f "$ROOT"/dev/m7a/infer-undetermined.tot ] \
  || { echo "FAIL-M7A-ARGHOLE-REFUSES-NONINFERABLE (MISSING-FIXTURE under dev/m7a)"; exit 1; }
m7a_na=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-infer.tot 2> "$m7a_scratch"/na.err)
m7a_nacode=$?
m7a_nb=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/infer-fenced.tot 2> "$m7a_scratch"/nb.err)
m7a_nbcode=$?
m7a_nc=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/infer-undetermined.tot 2> "$m7a_scratch"/nc.err)
m7a_nccode=$?
m7a_nd=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/infer-fenced-explicit.tot 2>&1)
m7a_ndcode=$?
{ [ "$m7a_nacode" -eq 1 ] && [ "$m7a_nbcode" -eq 1 ] && [ "$m7a_nccode" -eq 1 ] \
    && [ -z "$m7a_na" ] && [ -z "$m7a_nb" ] && [ -z "$m7a_nc" ] \
    && [ "$(wc -l < "$m7a_scratch"/na.err)" -eq 1 ] \
    && [ "$(wc -l < "$m7a_scratch"/nb.err)" -eq 1 ] \
    && [ "$(wc -l < "$m7a_scratch"/nc.err)" -eq 2 ] \
    && [ "$(awk 'NR==2' "$m7a_scratch"/nc.err)" = '1 more hole(s) at 1:16' ] \
    && rg -q '^\S*/m6c-hole-n-infer\.tot:1:6: hole: no expected type at this position$' \
       "$m7a_scratch"/na.err \
    && rg -q '^\S*/infer-fenced\.tot:1:13: hole: no expected type at this position$' \
       "$m7a_scratch"/nb.err \
    && rg -q '^\S*/infer-undetermined\.tot:1:14: hole: no expected type at this position$' \
       "$m7a_scratch"/nc.err \
    && [ "$m7a_ndcode" -eq 0 ] \
    && printf '%s\n' "$m7a_nd" | rg -qx 'eval : \(EqD Bool\)'; } \
  && echo PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE \
  || {
    cat "$m7a_scratch"/na.err "$m7a_scratch"/nb.err "$m7a_scratch"/nc.err
    printf '%s\n' "$m7a_nd"
    echo "FAIL-M7A-ARGHOLE-REFUSES-NONINFERABLE (exit=$m7a_nacode/$m7a_nbcode/$m7a_nccode/$m7a_ndcode)"
    exit 1
  }

# Gate M7A (iv), PASS-M7A-CONSERVATIVITY (pin 4).  The five green
# example files keep byte-identical stdout, which is the whole
# conservativity claim, and every one of them keeps an EMPTY stderr, so
# a file that starts failing cannot pass by printing nothing.
# MEASUREMENT RECIPE: concatenate the five stdout captures in the order
# below and take `md5 -q`; the line count is `wc -l` over the same
# concatenation.  The transcript leg is the one number that MUST move:
# 9 `hole:` lines at HEAD, 8 after the stage, because m6c-hole-a.tot
# stops reporting a hole (plan A7, A8).  Stage D owns the next
# re-derivation of the md5 and the 55, because it deletes twelve helper
# defs from the two guards.
"$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/examples/church.tot \
  > "$m7a_scratch"/e1.out 2> "$m7a_scratch"/e1.err
"$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/examples/guard-classes.tot \
  > "$m7a_scratch"/e2.out 2> "$m7a_scratch"/e2.err
"$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/examples/guard-rewrap.tot \
  > "$m7a_scratch"/e3.out 2> "$m7a_scratch"/e3.err
"$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/examples/guard.tot \
  > "$m7a_scratch"/e4.out 2> "$m7a_scratch"/e4.err
"$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/examples/literals.tot \
  > "$m7a_scratch"/e5.out 2> "$m7a_scratch"/e5.err
m7a_cons=$(cat "$m7a_scratch"/e1.out "$m7a_scratch"/e2.out "$m7a_scratch"/e3.out \
  "$m7a_scratch"/e4.out "$m7a_scratch"/e5.out | md5 -q)
m7a_conslines=$(cat "$m7a_scratch"/e1.out "$m7a_scratch"/e2.out "$m7a_scratch"/e3.out \
  "$m7a_scratch"/e4.out "$m7a_scratch"/e5.out | wc -l | tr -d ' ')
m7a_conserr=$(cat "$m7a_scratch"/e1.err "$m7a_scratch"/e2.err "$m7a_scratch"/e3.err \
  "$m7a_scratch"/e4.err "$m7a_scratch"/e5.err | wc -c | tr -d ' ')
m7a_holes=$(rg -c 'hole:' "$ROOT"/dev/m5e-default-transcript.txt)
{ [ "$m7a_cons" = 99c23b4b74c722735d17e1dc49524e58 ] && [ "$m7a_conslines" -eq 55 ] \
    && [ "$m7a_conserr" -eq 0 ] && [ "$m7a_holes" -eq 8 ]; } \
  && echo PASS-M7A-CONSERVATIVITY \
  || {
    cat "$m7a_scratch"/e1.err "$m7a_scratch"/e2.err "$m7a_scratch"/e3.err \
      "$m7a_scratch"/e4.err "$m7a_scratch"/e5.err
    echo "FAIL-M7A-CONSERVATIVITY (md5=$m7a_cons lines=$m7a_conslines errbytes=$m7a_conserr holes=$m7a_holes)"
    exit 1
  }

# Gate M7A (v), PASS-M7A-SPINE-COMMENT (debt item j).  The `spine` doc
# comment states the new rule.  The M6 sentence is gone, the word
# `argument-driven` is present (it occurs nowhere in surface/elab.ml at
# HEAD), and the descent sentence is still there, so a comment that was
# deleted instead of rewritten fails.  The fourth leg holds the side
# effect inside the re-spelled test/fixtures/m6c-hole-run.tot, so the
# plan A7 repair cannot pass by removing the effect that
# PASS-M6C-HOLE-NEVER-RUNS exists to watch.
rg -q -F 'a hole takes its capture or reports the' "$ROOT"/surface/elab.ml
m7a_stale=$?
m7a_descent=$(rg -c -F 'then argument descent through' "$ROOT"/surface/elab.ml)
m7a_m7=$(rg -c -F 'argument-driven' "$ROOT"/surface/elab.ml)
m7a_side=$(rg -c -F 'SIDE-EFFECT' "$ROOT"/test/fixtures/m6c-hole-run.tot)
{ [ "$m7a_stale" -eq 1 ] && [ "$m7a_descent" -eq 1 ] && [ "$m7a_m7" -eq 1 ] \
    && [ "$m7a_side" -eq 1 ]; } \
  && echo PASS-M7A-SPINE-COMMENT \
  || {
    echo "FAIL-M7A-SPINE-COMMENT (stale=$m7a_stale descent=$m7a_descent m7=$m7a_m7 run=$m7a_side)"
    exit 1
  }

# Gate M7A (vi), PASS-M7A-INFER-SETTLE (pins 2, 3, 5).  The infer path
# settles four shapes that HEAD refuses with
# `hole: no expected type at this position`, and each one is compared
# against its explicit twin, byte for byte and non-empty.  s3-holed is
# pin 5 anchor 3, the anchor the 2026-09-04 amendment exists for: it
# sits under a class former, so the fence branch hands it to `term` and
# only the infer settle reaches it.  The two negatives repeat here with
# their whole HEAD lines, so a settle that fires too often fails on the
# same leg that a settle that never fires fails on.
[ -f "$ROOT"/dev/m7a/s3-holed.tot ] && [ -f "$ROOT"/dev/m7a/infer-lift-holed.tot ] \
  && [ -f "$ROOT"/dev/m7a/infer-listeqby-holed.tot ] \
  && [ -f "$ROOT"/dev/m7a/arg-infer-holed.tot ] \
  || { echo "FAIL-M7A-INFER-SETTLE (MISSING-FIXTURE under dev/m7a)"; exit 1; }
m7a_i1=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s3-holed.tot 2>&1)
m7a_j1=$?
m7a_k1=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/s3-explicit.tot 2>&1)
m7a_l1=$?
m7a_i2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/infer-lift-holed.tot 2>&1)
m7a_j2=$?
m7a_k2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/infer-lift-explicit.tot 2>&1)
m7a_l2=$?
m7a_i3=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/infer-listeqby-holed.tot 2>&1)
m7a_j3=$?
m7a_k3=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/infer-listeqby-explicit.tot 2>&1)
m7a_l3=$?
m7a_i4=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/arg-infer-holed.tot 2>&1)
m7a_j4=$?
m7a_k4=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/m7a/arg-infer-explicit.tot 2>&1)
m7a_l4=$?
{ [ "$m7a_j1" -eq 0 ] && [ "$m7a_l1" -eq 0 ] && [ "$m7a_i1" = "$m7a_k1" ] && [ -n "$m7a_i1" ] \
    && [ "$m7a_j2" -eq 0 ] && [ "$m7a_l2" -eq 0 ] && [ "$m7a_i2" = "$m7a_k2" ] && [ -n "$m7a_i2" ] \
    && [ "$m7a_j3" -eq 0 ] && [ "$m7a_l3" -eq 0 ] && [ "$m7a_i3" = "$m7a_k3" ] && [ -n "$m7a_i3" ] \
    && [ "$m7a_j4" -eq 0 ] && [ "$m7a_l4" -eq 0 ] && [ "$m7a_i4" = "$m7a_k4" ] && [ -n "$m7a_i4" ] \
    && printf '%s\n' "$m7a_i1" \
       | rg -qx 'def myEqList : \(0 A : Type 0\) -> \(w _ : \(EqD A\)\) -> \(EqD \(List A\)\)' \
    && printf '%s\n' "$m7a_i2" | rg -qx 'eval : \(IO \(Option Json\)\)' \
    && printf '%s\n' "$m7a_i4" | rg -qx 'def probeI : \(List Nat\)' \
    && rg -q '^\S*/infer-fenced\.tot:1:13: hole: no expected type at this position$' \
       "$m7a_scratch"/nb.err \
    && rg -q '^\S*/infer-undetermined\.tot:1:14: hole: no expected type at this position$' \
       "$m7a_scratch"/nc.err; } \
  && echo PASS-M7A-INFER-SETTLE \
  || {
    printf '%s\n---\n%s\n' "$m7a_i1" "$m7a_k1"
    printf '%s\n---\n%s\n' "$m7a_i2" "$m7a_k2"
    echo "FAIL-M7A-INFER-SETTLE (exit=$m7a_j1/$m7a_l1 $m7a_j2/$m7a_l2 $m7a_j3/$m7a_l3 $m7a_j4/$m7a_l4)"
    exit 1
  }

# Gate M7A (vii), PASS-M7A-INFER-SETTLE-BUDGET (pin 2).  The
# conservativity BUDGET: one record per corpus file, `name|exit|md5 of
# the whole output`, over stdlib, examples and test/fixtures at depth
# 1, minus the two files plan A7 licenses to move.  61 green records
# must keep their stdout and 39 red records must keep their error text,
# including m6c-hole-n-infer.tot, the one corpus file that reports
# `hole: no expected type at this position` at HEAD.  MEASUREMENT
# RECIPE: the command below, whose three fields are pinned as the
# literals `100`, `61` and the md5.  `--max-depth 1` holds the corpus
# to the set dev/gen-m5e-transcript.sh walks, so a later stage that
# adds test/fixtures/m7/*.tot does not break this literal.  The
# `files` field refuses a digest that shrank because `fd` matched
# nothing; the `green` field refuses a digest that stayed stable
# because every file started failing.  Stage D and Stage E each own a
# re-derivation of all three literals.
m7a_exe="$ROOT"/_build/default/bin/tot.exe
export m7a_exe
m7a_recs=$(fd -e tot --max-depth 1 . "$ROOT"/stdlib "$ROOT"/examples "$ROOT"/test/fixtures \
  | rg -v '/(m6c-hole-a|m6c-hole-run)\.tot$' | sort \
  | xargs -n 1 "$watchdog" "$MED" zsh -c 'o=$("$m7a_exe" check "$0" 2>&1); e=$?; printf "%s|%d|%s\n" "${0##*/}" "$e" "$(printf %s "$o" | md5 -q)"')
m7a_files=$(printf '%s\n' "$m7a_recs" | wc -l | tr -d ' ')
m7a_green=$(printf '%s\n' "$m7a_recs" | rg -c '\|0\|')
m7a_digest=$(printf '%s\n' "$m7a_recs" | md5 -q)
# Review round 2026-09-04, conflict note C-A13.  Rule 3 of the five the
# plan lists at PLAN:1535-1549 says an unsettled hole keeps HEAD's error
# VALUE.  The 100-file digest alone cannot watch that rule.  No corpus
# file holds an infer-position SPINE with a holed LEADING slot, so a
# settle that stamps the slot universe on such a hole leaves all three
# digest fields at rest.  Measured: the mutation
# `expected = None` to `expected = Some (scope, dom)` at the settle site
# kept files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2.  The
# three legs below close that gap.  They re-run the three pin-2
# negatives of PLAN:1501-1506 and pin the whole line of each.  `eval _`
# is the corpus hole with no spine.  `eval (mkEqD _ boolEq)` is a spine
# under the family fence, which is rule 2.  `eval (liftIO _ _)` is a
# spine that reaches the settle fold, which is rule 3, and its line
# moves under the mutation above.
m7a_b1=$("$watchdog" "$FAST" "$m7a_exe" check \
  "$ROOT"/test/fixtures/m6c-hole-n-infer.tot 2>&1)
m7a_c1=$?
m7a_b2=$("$watchdog" "$FAST" "$m7a_exe" check "$ROOT"/dev/m7a/infer-fenced.tot 2>&1)
m7a_c2=$?
m7a_b3=$("$watchdog" "$FAST" "$m7a_exe" check "$ROOT"/dev/m7a/infer-undetermined.tot 2>&1)
m7a_c3=$?
{ [ "$m7a_files" -eq 100 ] && [ "$m7a_green" -eq 61 ] \
    && [ "$m7a_digest" = 9b416b949964a50c4f7633eab478b5c2 ] \
    && [ "$m7a_c1" -eq 1 ] && [ "$m7a_c2" -eq 1 ] && [ "$m7a_c3" -eq 1 ] \
    && printf '%s\n' "$m7a_b1" \
       | rg -qx '\S*/m6c-hole-n-infer\.tot:1:6: hole: no expected type at this position' \
    && printf '%s\n' "$m7a_b2" \
       | rg -qx '\S*/infer-fenced\.tot:1:13: hole: no expected type at this position' \
    && printf '%s\n' "$m7a_b3" \
       | rg -qx '\S*/infer-undetermined\.tot:1:14: hole: no expected type at this position'; } \
  && echo PASS-M7A-INFER-SETTLE-BUDGET \
  || {
    printf '%s\n' "$m7a_recs" | head -10
    printf '%s\n%s\n%s\n' "$m7a_b1" "$m7a_b2" "$m7a_b3"
    echo "FAIL-M7A-INFER-SETTLE-BUDGET (files=$m7a_files green=$m7a_green md5=$m7a_digest neg=$m7a_c1$m7a_c2$m7a_c3)"
    exit 1
  }

# ---------------------------------------------------------------------
# M7 Stage B (verdict pins 5, 6, 11): all FOUR guard A slots are
# re-spelled as holes.  Pin 6 pinned two of them as explicit-forever
# negatives, on the recorded reason that the informative later
# argument is itself the holed `liftIO _ (...)` which
# surface/elab.ml:287-291 refuses at the infer entry.  Stage A's
# infer settle elaborates that argument, so the recorded reason is no
# longer true and the two negatives are RETIRED (Ratification
# amendment 2026-09-04: a slot stays a negative only with a true
# reason).  Measured at 66b444f, before Stage A: each slot alone,
# re-spelled in its own file, exits 1 at `134:8` and `265:8` with
# `hole: expected Type 0` (plan B2 P4, P6).  At 37c0bb2, the commit
# this stage lands on, the settle closes all four slots.  The refusal
# obligation moves to m7b-arg-slot-undetermined.tot, whose every
# later argument is a hole, so nothing determines the slot.  Deleting
# that negative leg is forbidden; re-opening its design is the M6
# rule.  Mutation proofs in dev/M7-BUILD-LOG.md.
# ---------------------------------------------------------------------

# PASS-M7B-GUARD-ARG-HOLES (pins 5, 11).  Five assertions: both
# guards still check at exit 0; the classifier's site list shows all
# FOUR A slots HOLED (guard.tot:133-134 and guard-rewrap.tot:264-265,
# bucket A, which an un-respelled tree cannot show); the corpus
# holed-anchor literal is 26 (22 at HEAD, plan B2 P7/P8); and the deny
# envelope on the M3 payload is byte-identical to the pre-respell
# envelope, so the re-spell changed no behaviour.
m7b_g1=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard.tot 2>&1); m7b_c1=$?
m7b_g2=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard-rewrap.tot 2>&1); m7b_c2=$?
m7b_slots=$(rg -c 'SITE examples/guard(-rewrap)?\.tot:(133|134|264|265) head=bindIO arg=0 anchor=\[_\] pos=check bucket=A' "$m5d_scratch/hole-sites.txt")
m7b_holed=$(rg -c 'anchor=\[_\]' "$m5d_scratch/hole-sites.txt")
m7b_env=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard.tot \
  < "$fx"/deny.json); m7b_c3=$?
m7b_wantenv='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo /tmp/x)"}}'
{ [ "$m7b_c1" -eq 0 ] && [ "$m7b_c2" -eq 0 ] \
  && [ "$m7b_slots" -eq 4 ] && [ "$m7b_holed" -eq 26 ] \
  && [ "$m7b_c3" -eq 2 ] && [ "$m7b_env" = "$m7b_wantenv" ]; } \
  && echo PASS-M7B-GUARD-ARG-HOLES \
  || { printf '%s\n%s\n%s\n' "$m7b_g1" "$m7b_g2" "$m7b_env"; \
       echo "FAIL-M7B-GUARD-ARG-HOLES (c=$m7b_c1/$m7b_c2 slots=$m7b_slots holed=$m7b_holed env=$m7b_c3)"; exit 1; }

# PASS-M7B-LIFTIO-SLOT-CLOSES (pin 6, amended).  The retired negative
# and its replacement.  The two positives pin the WHOLE stdout line,
# and the negative pins the WHOLE message line, so a fixture that goes
# missing (exit 1 with `no such file`) reads as red here instead of
# green.  m7b-liftio-slot.tot is the pin 6 shape with the FIRST slot
# left explicit: it isolates the slot the verdict called unreachable,
# which is what makes the retirement executable rather than an
# opinion.
m7b_p1=$("$watchdog" "$FAST" "$m5d_bin" check \
  "$ROOT"/test/fixtures/m7/m7b-guard-arg-slots.tot 2>&1); m7b_c4=$?
m7b_p2=$("$watchdog" "$FAST" "$m5d_bin" check \
  "$ROOT"/test/fixtures/m7/m7b-liftio-slot.tot 2>&1); m7b_c5=$?
m7b_n1=$("$watchdog" "$FAST" "$m5d_bin" check \
  "$ROOT"/test/fixtures/m7/m7b-arg-slot-undetermined.tot 2>&1); m7b_c6=$?
# M7 Stage C (pin 7, C-C1): 2026-09-04.  The negative moves to the pin
# 7 shape.  m7b-arg-slot-undetermined.tot holds three term-position
# holes in one item (7:8, 7:35, 7:37), so the binary prints two stderr
# lines.  The whole-output compare keeps line 1 unchanged and pins line
# 2 byte for byte to the tail the binary prints.  The two positives,
# the leg name, the marker and the exit codes do not move.
m7b_wn="$ROOT/test/fixtures/m7/m7b-arg-slot-undetermined.tot:7:8: hole: expected Type 0
2 more hole(s) at 7:35, 7:37"
{ [ "$m7b_c4" -eq 0 ] && [ "$m7b_p1" = 'def main : (IO Verdict)' ] \
  && [ "$m7b_c5" -eq 0 ] && [ "$m7b_p2" = 'def main : (IO Verdict)' ] \
  && [ "$m7b_c6" -eq 1 ] && [ "$m7b_n1" = "$m7b_wn" ]; } \
  && echo PASS-M7B-LIFTIO-SLOT-CLOSES \
  || { printf '%s\n%s\n%s\n' "$m7b_p1" "$m7b_p2" "$m7b_n1"; \
       echo "FAIL-M7B-LIFTIO-SLOT-CLOSES (c=$m7b_c4/$m7b_c5/$m7b_c6)"; exit 1; }

# ---------------------------------------------------------------------
# M7 Stage C: multi-hole tail reporting (verdict pins 7 and 8).  Two
# markers.  All three fixtures live under dev/fixtures/, OUTSIDE the
# transcript glob (dev/gen-m5e-transcript.sh:13) and outside the
# anchor corpus (dev/hole-anchors.py:86-87), because pin 4 holds the
# reseal for Stage D and pin 10 fixes the ANCHORS literal there.
# ---------------------------------------------------------------------
m7c_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m7c.XXXXXX")

# Gate C9 (i), PASS-M7C-MULTI-HOLE-TAIL (pins 7 and 8).  Five legs.
# (a) check: exit 1, stdout EMPTY, stderr EXACTLY two lines, the M6
# line first and the pin-7 tail second.  (b) the same tail on the run
# path and under --serror-exit 0, so the mapping moves the code and
# never the report.  (c) the tail names NO position of the green
# definition above it.  (d) the backtrack fixture: one position, once.
# (e) pin 8: the two constructor counts, derived from the type blocks,
# not from a line number.
m7c_out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/fixtures/m7c-multi-hole.tot 2> "$m7c_scratch"/multi.err); m7c_c1=$?
m7c_twin=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/fixtures/m7c-multi-hole-explicit.tot 2> "$m7c_scratch"/twin.err); m7c_c2=$?
m7c_run=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe run \
  "$ROOT"/dev/fixtures/m7c-multi-hole.tot 2> "$m7c_scratch"/run.err); m7c_c3=$?
m7c_se0=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check --serror-exit 0 \
  "$ROOT"/dev/fixtures/m7c-multi-hole.tot 2> "$m7c_scratch"/se0.err); m7c_c4=$?
m7c_bck=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/fixtures/m7c-backtrack.tot 2> "$m7c_scratch"/back.err); m7c_c5=$?
m7c_sctors=$(awk '/^type t =/,/^let to_string/' "$ROOT"/surface/serror.ml | rg -c '^  \| [A-Z]')
m7c_tctors=$(awk '/^type t =/,/^\(\*\*/' "$ROOT"/lib/term.ml | rg -c '^  \| [A-Z]')
{ [ "$m7c_c1" -eq 1 ] && [ "$m7c_c2" -eq 0 ] && [ "$m7c_c3" -eq 1 ] && [ "$m7c_c4" -eq 0 ] \
    && [ "$m7c_c5" -eq 1 ] \
    && [ -z "$m7c_out" ] && [ -z "$m7c_run" ] && [ -z "$m7c_se0" ] \
    && [ "$(wc -l < "$m7c_scratch"/multi.err | tr -d ' ')" -eq 2 ] \
    && [ "$(wc -l < "$m7c_scratch"/run.err | tr -d ' ')" -eq 2 ] \
    && [ "$(wc -l < "$m7c_scratch"/se0.err | tr -d ' ')" -eq 2 ] \
    && [ "$(wc -l < "$m7c_scratch"/back.err | tr -d ' ')" -eq 2 ] \
    && [ "$(wc -l < "$m7c_scratch"/twin.err | tr -d ' ')" -eq 0 ] \
    && rg -q '^\S*/m7c-multi-hole\.tot:7:14: hole: no expected type at this position$' \
         "$m7c_scratch"/multi.err \
    && [ "$(awk 'NR==2' "$m7c_scratch"/multi.err)" = "2 more hole(s) at 7:24, 7:38" ] \
    && [ "$(awk 'NR==2' "$m7c_scratch"/run.err)" = "2 more hole(s) at 7:24, 7:38" ] \
    && [ "$(awk 'NR==2' "$m7c_scratch"/se0.err)" = "2 more hole(s) at 7:24, 7:38" ] \
    && rg -q '^\S*/m7c-backtrack\.tot:5:14: hole: no expected type at this position$' \
         "$m7c_scratch"/back.err \
    && [ "$(awk 'NR==2' "$m7c_scratch"/back.err)" = "1 more hole(s) at 5:31" ] \
    && { rg -q '6:35|6:49' "$m7c_scratch"/multi.err; [ $? -eq 1 ]; } \
    && [ "$m7c_sctors" -eq 10 ] && [ "$m7c_tctors" -eq 11 ]; } \
  && echo PASS-M7C-MULTI-HOLE-TAIL \
  || {
    cat "$m7c_scratch"/multi.err "$m7c_scratch"/back.err
    echo "FAIL-M7C-MULTI-HOLE-TAIL (exit=$m7c_c1/$m7c_c2/$m7c_c3/$m7c_c4/$m7c_c5 ctors=$m7c_sctors/$m7c_tctors)"
    exit 1
  }

# Gate C9 (ii), PASS-M7C-SINGLE-HOLE-UNCHANGED (pin 7).  A one-hole
# item must keep the M6 one-line report, byte for byte, so the stage
# cannot buy its tail by printing a tail everywhere.  Both fixtures
# are pin-stable: infer position (pin 2) and the proof fence.
m7c_i=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-infer.tot 2> "$m7c_scratch"/i.err); m7c_c6=$?
m7c_p=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-proof.tot 2> "$m7c_scratch"/p.err); m7c_c7=$?
{ [ "$m7c_c6" -eq 1 ] && [ "$m7c_c7" -eq 1 ] \
    && [ "$(wc -l < "$m7c_scratch"/i.err | tr -d ' ')" -eq 1 ] \
    && [ "$(wc -l < "$m7c_scratch"/p.err | tr -d ' ')" -eq 1 ] \
    && rg -q '^\S*/m6c-hole-n-infer\.tot:1:6: hole: no expected type at this position$' \
         "$m7c_scratch"/i.err \
    && rg -q '^\S*/m6c-hole-n-proof\.tot:1:38: hole: expected Type 0$' "$m7c_scratch"/p.err \
    && { rg -q 'more hole' "$m7c_scratch"/i.err "$m7c_scratch"/p.err; [ $? -eq 1 ]; }; } \
  && echo PASS-M7C-SINGLE-HOLE-UNCHANGED \
  || {
    cat "$m7c_scratch"/i.err "$m7c_scratch"/p.err
    echo "FAIL-M7C-SINGLE-HOLE-UNCHANGED (exit=$m7c_c6/$m7c_c7)"
    exit 1
  }

# ctxcat id 5: an instance with TWO dictionary binders on the SAME type
# variable. Round 1's fuel bounded the depth of one resolution PATH,
# never the total number of resolutions, so this branching shape
# performed 2^n identical sub-resolutions while fuel grew only linearly
# in the depth: the belt could not fire and the file took 32.82s at
# n = 20 (7.43s at 18, 0.41s at 14). With fuel threaded as a BUDGET the
# whole walk is bounded by inst_fuel. The round-2 oracle was "resolve or
# report Inst_depth, never hang", accepting either exact outcome so that
# adding a (class, key) memo would flip this gate DELIBERATELY rather
# than silently.
#
# M4 fixes round 3 (opus R3-1): the memo landed, so this is that
# deliberate flip. The oracle is now RESOLUTION: exit 0 and the value.
# An Inst_depth here is a FAIL, because with the memo the budget must
# not fire on any legitimate input.
#
# M4 fixes round 4 (opus R4-1), an AUTHORIZED oracle re-scope plus a
# move. At nesting 20 the resolved dictionary is a binary tree of 2^20
# nodes that the mandatory candidate re-check walks as a TREE (Term.t
# has no sharing), so the leg cost 20.5s idle and 58 to 90s under load:
# two of three gate-shaped runs hit the 60s watchdog at exit 124. The
# fixture drops to nesting 16, which still over-pins the nesting-4-to-6
# regression boundary by an order of magnitude while the term shrinks
# 16x (measured after the change: 0.97s, so 60s is now about 60x
# headroom rather than 2.9x). The depth-20 number is kept in the
# fixture's own header as the M5 hash-consing motivation.
#
# M4 fixes round 5 (opus R5-4): this is the LAST leg in the file, so no
# marker at all sits downstream of it and the round-4 claim is now true
# as stated. It is the most expensive and the most timing-sensitive leg
# here, which is exactly why nothing cheap may depend on it.
out=$(gate_timed "$SLOW" M4FIX-INST-BRANCHING "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-branching.tot)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true'; } \
  && echo PASS-M4FIX-INST-BRANCHING \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-BRANCHING (exit=$code)"; exit 1; }

# PASS-M5B-BRANCHING-20 (pin 1, the perf leg).  M5 Stage B: the depth
# the M4 round-4 re-scope retreated from, restored.  MEASUREMENT
# RECIPE (preamble 6.3): `time _build/default/bin/tot.exe run
# test/fixtures/m5b-inst-branching-20.tot`; on the M4 HEAD binary this
# file took 30.188s to run and 31.570s to check (plan B0, P9/P10),
# and with the Stage B let-nest it measured 0.034s on 2026-09-02, so
# the 10s budget is about 300x the measured cost: a hang detector, not
# a performance gate.  MUTATION PROOF: inline islot_term's ISlot arm
# (the SHARE-SIZE mutation, the M4 tree); this leg times out at exit
# 124 with no `true` line.  M4 round-5 lesson: this is the most
# timing-sensitive leg in the file, so it is the LAST leg, with no
# marker downstream of it.
out=$(gate_timed "$FAST" M5B-BRANCHING-20 "$ROOT"/_build/default/bin/tot.exe run \
  "$ROOT"/test/fixtures/m5b-inst-branching-20.tot)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true'; } \
  && echo PASS-M5B-BRANCHING-20 \
  || { printf '%s\n' "$out" | tail -n 3; echo "FAIL-M5B-BRANCHING-20 (exit=$code)"; exit 1; }

# scratch dir removal now rides the EXIT trap installed at Gate D's top
# M5 Stage D (plan D2): where the per-leg measurements landed; the
# operator reads it after a green run, next to the caller's GATE-EXIT
# line.
echo "GATE-LOG=$GATE_LOG"
exit 0
