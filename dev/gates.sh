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
main_out=$("$watchdog" 300 dune exec --root "$ROOT" test/main.exe); t1=$?
printf '%s\n' "$main_out"
surface_out=$("$watchdog" 120 dune exec --root "$ROOT" test/surface.exe); t2=$?
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
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- bootstrap-only 2>&1)
[ $? -eq 0 ] && echo PASS-CHECK-PRELUDE \
  || { printf '%s\n' "$out"; echo FAIL-CHECK-PRELUDE; exit 1; }
# M3 fixes round 3 (ctxcat id 17): stdout is captured ALONE and the
# pinned line is matched per-line (rg -qx), so a benign stderr byte (a
# dune notice, the R1 cache-disabled line) cannot turn a semantically
# green run red; stderr goes to a temp file for the failure replay.
prelude_err=$(mktemp "${TMPDIR:-/tmp}/tot-gate-prelude-run-err.XXXXXX")
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x2-prelude-run.tot 2> "$prelude_err")
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
bout=$(TOT_PRELUDE="$ROOT/nonexistent-prelude.tot" "$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/examples/church.tot 2> "$berr_file")
bcode=$?
berr=$(cat "$berr_file")
rm -f "$berr_file"
{ [ "$bcode" -eq 1 ] && [ -z "$bout" ] && printf '%s\n' "$berr" | rg -q '^prelude: '; } \
  && echo PASS-PRELUDE-ERR-STDERR \
  || { printf '%s\n' "$berr"; echo "FAIL-PRELUDE-ERR-STDERR (exit=$bcode stdout=[$bout])"; exit 1; }
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/examples/church.tot 2>&1)
[ $? -eq 0 ] && echo PASS-CHECK-CHURCH || { printf '%s\n' "$out"; echo FAIL-CHECK-CHURCH; exit 1; }
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/examples/church.tot 2>&1)
[ $? -eq 0 ] && echo PASS-RUN-CHURCH || { printf '%s\n' "$out"; echo FAIL-RUN-CHURCH; exit 1; }
# M3 Stage D, D1: bin/tot.exe now auto-loads the prelude by default
# (Bootstrap.cached_state ()); examples/nat.tot is a kernel-test-style
# script that declares its OWN "data Nat" from scratch, which would
# otherwise collide with the prelude's own "Nat" (Duplicate_global).
# --no-prelude (decision 14) keeps it on the bare M2-only environment,
# exactly as before this stage.
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check --no-prelude "$ROOT"/examples/nat.tot 2>&1)
[ $? -eq 0 ] && echo PASS-CHECK-NAT || { printf '%s\n' "$out"; echo FAIL-CHECK-NAT; exit 1; }
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- run --no-prelude "$ROOT"/examples/nat.tot 2>&1)
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
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/b-stdin-chain.tot <<'EOF'
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
"$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/b-sentinel.tot > "$sentinel" 2>&1
c1=$?
{ [ "$c1" -eq 0 ] && ! rg -q 'SENTINEL-WRITTEN' "$sentinel"; } \
  || { cat "$sentinel"; echo FAIL-B-NOEFFECT; rm -f "$sentinel"; exit 1; }
"$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/b-sentinel.tot > "$sentinel" 2>&1
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
"$watchdog" 10 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/b-deferred-div.tot > /dev/null 2>&1
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
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x3-div-chain.tot 2>&1)
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
"$watchdog" 5 dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/x1-nested-div.tot > /dev/null 2>&1
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
out=$("$watchdog" 5 dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/test/fixtures/x12-dead-abort.tot 2> /dev/null)
cda=$?
{ [ "$cda" -eq 0 ] && [ -z "$out" ]; } && echo PASS-RUN-DEADCODE-ABORT \
  || { printf '%s\n' "$out"; echo "FAIL-RUN-DEADCODE-ABORT (exit=$cda)"; exit 1; }
out=$("$watchdog" 5 dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/test/fixtures/x13-dead-hang.tot 2> /dev/null)
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
out=$("$watchdog" 15 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/x8-proc-bigstderr.tot 2>&1)
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
"$watchdog" 5 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/c-regex-pathological.tot > /dev/null 2>&1
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
"$watchdog" 5 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/c-regex-pathological.tot > /dev/null 2>&1
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
trap 'rm -rf "$tot_scratch" "$cache_scratch"' EXIT
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
want='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed"}}'
{ [ "$code" -eq 2 ] && [ "$out" = "$want" ]; } && echo PASS-D-GUARD-DENY \
  || { printf '%s\n' "$out"; echo "FAIL-D-GUARD-DENY (exit=$code)"; exit 1; }

# M3 fixes round 3 (ctxcat id 3): a PATH-QUALIFIED banned binary
# behind a LEADING SPACE (" /usr/bin/grep foo /tmp/x") is still
# denied: the guard compares the BASENAME of the first NON-EMPTY
# token. Pre-fix this payload was ALLOWED, exit 0 (both bypass shapes
# recorded in dev/M3-FIXES-LOG.md).
out=$("$guard" < "$fx/deny-path.json"); code=$?
{ [ "$code" -eq 2 ] && [ "$out" = "$want" ]; } && echo PASS-D-GUARD-DENY-PATH \
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
{ [ "$code" -eq 2 ] && [ "$out" = "$want" ] \
  && [ "$code_nl" -eq 2 ] && [ "$out_nl" = "$want" ] \
  && [ "$code_ts" -eq 2 ] && [ "$out_ts" = "$want" ] \
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
out=$("$watchdog" 5 "$tot_scratch/tot" check "$fx/x10-main-bad-type.tot" 2>&1); mc1=$?
out2=$("$watchdog" 5 "$tot_scratch/tot" run "$fx/x10-main-bad-type.tot" 2>&1); mc2=$?
{ [ "$mc1" -eq 1 ] && [ "$mc2" -eq 1 ] \
  && printf '%s\n' "$out" | rg -q 'main is a reserved driver name' \
  && printf '%s\n' "$out2" | rg -q 'main is a reserved driver name' \
  && ! { printf '%s\n' "$out2" | rg -q 'THIS EFFECT NEVER HAPPENS'; }; } \
  && echo PASS-D-MAIN-BADTYPE \
  || { printf '%s\n%s\n' "$out" "$out2"; echo "FAIL-D-MAIN-BADTYPE (exit=$mc1/$mc2)"; exit 1; }

out=$("$watchdog" 5 "$tot_scratch/tot" run "$fx/x11-main-misspelled.tot" 2>&1); mc3=$?
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
      "$watchdog" 15 "$tot_scratch/tot" run "$ROOT"/test/fixtures/x2-prelude-run.tot \
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
  "$watchdog" 15 "$noexe_scratch/tot-noread" run "$ROOT"/test/fixtures/x2-prelude-run.tot \
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
  "$watchdog" 15 "$exeid_scratch/tot" run "$ROOT"/test/fixtures/x2-prelude-run.tot \
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
  "$watchdog" 15 "$exeid_scratch/tot" check "$exeid_scratch/absent.tot" 2>&1)
env TOT_CACHE_DIR="$exeid_scratch/cache" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
  "$watchdog" 15 "$exeid_scratch/tot" run "$ROOT"/test/fixtures/x2-prelude-run.tot \
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
    TOT_CACHE_VERIFY=1 "$watchdog" 15 "$exeid_scratch/v1" run \
    "$ROOT"/test/fixtures/x2-prelude-run.tot 2>&1 1> /dev/null)
m1code=$?
memo2=$(env TOT_CACHE_DIR="$exeid_scratch/cache2" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
    TOT_CACHE_VERIFY=1 "$watchdog" 15 "$exeid_scratch/v1" run \
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
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/m4a-vec.tot 2> "$m4a_vec_err")
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx '\(\(vcons zero\) \(\(vcons \(succ zero\)\) vnil\)\)'; } \
  && { rm -f "$m4a_vec_err"; echo PASS-M4A-VEC; } \
  || { printf '%s\n' "$out"; cat "$m4a_vec_err"; rm -f "$m4a_vec_err"; echo "FAIL-M4A-VEC (exit=$code)"; exit 1; }

# M4 Stage A gate (iii): a wrong-index constructor (VecB A, omitting the
# index) is Bad_ctor, naming the expected index count.
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-vec-badindex.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'applied to its parameters and 1 index expression'; } \
  && echo PASS-M4A-VEC-BADIX \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-VEC-BADIX (exit=$code)"; exit 1; }

# M4 Stage A gate (iv), first fence: a w-carrying single constructor
# (Box) stays Erased_use -- the subsingleton criterion's "every
# constructor argument at quantity 0" clause.
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-box.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'erased variable b used at runtime'; } \
  && echo PASS-M4A-BOX \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-BOX (exit=$code)"; exit 1; }

# M4 Stage A gate (iv), second fence: a self-recursive erased singleton
# (SX) stays Erased_use -- the subsingleton criterion's "not self-
# recursive" clause, not a quantity; SX itself is still ACCEPTED (only
# the eliminating def sxLoop is rejected).
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-sx.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'erased variable s used at runtime'; } \
  && echo PASS-M4A-SX \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-SX (exit=$code)"; exit 1; }

# M4 Stage A gate (iv), third fence: a two-constructor family (Bool)
# stays Erased_use -- the subsingleton criterion's "at most one
# constructor" clause; this is the "leave failing" half Gate A pairs
# against m4a-box.tot's and m4a-sx.tot's own flips.
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-ese-neg.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'erased variable b used at runtime'; } \
  && echo PASS-M4A-ESE-NEG \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-ESE-NEG (exit=$code)"; exit 1; }

# M4 Stage A gate (vi): Fording (encoding an index as a uniform
# parameter) stays blocked; vpnil fails the result-head rule before
# define_ind's ctor fold ever reaches vpcons.
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4a-fording.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'applied to its parameters and 0 index expressions'; } \
  && echo PASS-M4A-FORDING \
  || { printf '%s\n' "$out"; echo "FAIL-M4A-FORDING (exit=$code)"; exit 1; }

# M4 Stage B gate (ii): subst0/castNat check end to end under the
# bootstrapped prelude, pinning the exact printed lines Stage C's own
# erasure gate later relies on (subst0 erases to the identity).
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4b-subst-erases.tot 2>&1)
code=$?
want=$'def symNat : (0 m : Nat) -> (0 n : Nat) -> (0 h : (((Eq Nat) m) n)) -> (((Eq Nat) n) m)\nsymNat : (0 m : Nat) -> (0 n : Nat) -> (0 h : (((Eq Nat) m) n)) -> (((Eq Nat) n) m)\ndef castNat : (0 P : (w _ : Nat) -> Type 0) -> (0 a : Nat) -> (0 b : Nat) -> (0 h : (((Eq Nat) a) b)) -> (w _ : (P a)) -> (P b)\ncastNat : (0 P : (w _ : Nat) -> Type 0) -> (0 a : Nat) -> (0 b : Nat) -> (0 h : (((Eq Nat) a) b)) -> (w _ : (P a)) -> (P b)'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4B-SUBST \
  || { printf '%s\n' "$out"; echo "FAIL-M4B-SUBST (exit=$code)"; exit 1; }

# M4 Stage B gate (iii): natDecEq computes both a yes and a no; a Dec
# scrutinee drives a Bool (sameArity), exact readback "true".
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/m4b-deceq-runs.tot 2>&1)
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
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4b-axiom.tot 2>&1)
code=$?
want=$'axiom myAx : (((Eq Nat) zero) zero)\nmyAx : (((Eq Nat) zero) zero)'
out2=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4b-axiom-runtime.tot 2>&1)
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
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/m4b-noaxioms.tot 2>&1)
code=$?
want=$'axiom bogus : (((Eq Nat) zero) (succ zero))\nbogus : (((Eq Nat) zero) (succ zero))'
out2=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check --no-axioms "$ROOT"/test/fixtures/m4b-noaxioms.tot 2>&1)
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
out=$("$watchdog" 10 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/m4c-frozen.tot 2>&1)
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
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/test/fixtures/m4d-classes.tot 2>&1)
code=$?
want=$'def flagged : (List String)\ndef isFlagged : (w _ : String) -> Bool\ntrue\nfalse'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4D-AUTO \
  || { printf '%s\n' "$out"; echo "FAIL-M4D-AUTO (exit=$code)"; exit 1; }

# M4 Stage D, Gate D (ii): coherence. A duplicate instance key is
# Duplicate_global at definition time, message containing "inst$".
out=$("$watchdog" 30 dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/m4d-dup-instance.tot 2>&1)
code=$?
{ [ "$code" -ne 0 ] && printf '%s\n' "$out" | rg -q 'duplicate global inst\$'; } \
  && echo PASS-M4D-COHERENCE \
  || { printf '%s\n' "$out"; echo "FAIL-M4D-COHERENCE (exit=$code)"; exit 1; }

# M4 Stage D, Gate D (iii): --serror-exit 3 changes the exit code on a
# one-line type error, and the default stays 1. Driven through the real
# bin/tot.exe CLI (the flag lives there), matching PASS-M4B-NOAXIOMS'
# own precedent.
# M4 fixes round 2 (ctxcat id 6): under "$watchdog" 30, like every other
# CLI gate in this block. The checker can be driven to unbounded work,
# so an unguarded invocation turns a hang into an indefinite stall with
# no FAIL marker instead of a loud exit 124.
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/m4d-serror-exit.tot 2>&1)
code=$?
out2=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check --serror-exit 3 "$ROOT"/test/fixtures/m4d-serror-exit.tot 2>&1)
code2=$?
{ [ "$code" -eq 1 ] && [ "$code2" -eq 3 ] && [ "$out" = "$out2" ]; } \
  && echo PASS-M4D-SERROR-EXIT \
  || { printf '%s\n%s\n' "$out" "$out2"; echo "FAIL-M4D-SERROR-EXIT (exit=$code/$code2)"; exit 1; }

# M4 Stage D, Gate D (iv): --require-main rejects a mainless script
# (m4d-nomain.tot defines "mian", not "main") and the default behavior
# is unchanged (SPEC's misspelled-main residual, PASS-D-MAIN-MISSPELLED,
# stays a twin of this gate: unflagged, this exact fixture shape exits
# 0). M4 fixes round 2 (ctxcat id 6): under "$watchdog" 30.
# M4 fixes round 3 (ctxcat r3 id 3): the CHECK-mode leg is pinned too.
# --require-main is a verdict about the file's CONTENT, so it fires
# uniformly in both verbs by design (surface/run.ml's main_epilogue
# doc comment says so now); the finding read the flag's motivating
# consumer, a shebang wrapper, as its scope. Without this leg nothing
# stopped a later "gate it on exec" change from passing the battery.
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/test/fixtures/m4d-nomain.tot 2>&1)
code=$?
out2=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- run --require-main "$ROOT"/test/fixtures/m4d-nomain.tot 2>&1)
code2=$?
out3=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check --require-main "$ROOT"/test/fixtures/m4d-nomain.tot 2>&1)
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
# M4 fixes round 2 (ctxcat id 6): under "$watchdog" 30.
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/examples/guard-classes.tot 2>&1)
code=$?
out2=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/examples/guard-classes.tot 2>&1)
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
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/m4fix-ann-ctor.tot 2>&1)
code=$?
want=$'data AnnFoo : Type 0\nctor annMk : AnnFoo\ndata AnnBox : (0 A : Type 0) -> Type 0\nctor annBox : (0 A : Type 0) -> (w _ : A) -> (AnnBox A)'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4FIX-ANN-CTOR \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-ANN-CTOR (exit=$code)"; exit 1; }

# audit F3: `auto` in a result-index position hits the index-cleanliness
# ban ITSELF (Bad_ctor, naming the index expressions), instead of
# slipping past the raw check into elaboration, where the error used to
# arrive as an unrelated "no instance found for Nat".
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- check "$ROOT"/test/fixtures/m4fix-auto-index.tot 2>&1)
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
out=$("$watchdog" 30 dune exec --root "$ROOT" bin/tot.exe -- run "$ROOT"/test/fixtures/m4fix-inst-binders.tot 2>&1)
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
out=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-nest26.tot 2>&1)
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
out=$("$watchdog" 10 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-nest26-ill.tot 2>&1)
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
out=$("$watchdog" 10 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-nest30-nomotive.tot 2>&1)
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
out=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-twoclass.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true'; } \
  && echo PASS-M4FIX-INST-TWOCLASS \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-TWOCLASS (exit=$code)"; exit 1; }

# The SPEC's own branching shape (same class twice), nesting 16: 2^16
# identical sub-resolutions without the memo, one derivation per
# distinct sub-goal with it. Round 2 rejected this from nesting 4 up.
# Measured after the memo: 1.03s, of which the resolution itself is a
# small fraction (the rest is the 65k-node emitted dictionary).
out=$("$watchdog" 20 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-spec16.tot 2>&1)
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
out=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-chains.tot 2>&1)
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
out=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-small-reach.tot 2>&1)
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
out=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-memo-key.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx '\(succ zero\)'; } \
  && echo PASS-M4FIX-INST-MEMO-KEY \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-MEMO-KEY (exit=$code)"; exit 1; }

# opus R3: an annotation on the spine's own HEAD, in a constructor
# codomain and in a constructor PARAMETER argument. Totality.spine
# unwinds App without stripping, so round 1's outer strip_ann never
# reached the head and head_ok was false: a Bad_ctor on a term the
# elaborator accepts in every other position. Exact output pinned.
out=$("$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-ann-head.tot 2>&1)
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
out=$("$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-ann-head-neg.tot 2>&1)
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
out=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-axiom-empty.tot 2>&1)
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
out=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-absurd.tot 2>&1)
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
out=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-scrut-notfun.tot 2>&1)
code=$?
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q 'not a function type: Nat'; } \
  && echo PASS-M4FIX-SCRUT-NOTFUN \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-SCRUT-NOTFUN (exit=$code)"; exit 1; }

# ctxcat r4 id 4: an annotation wrapping the ENTIRE constructor type.
# The finding predicted a false Bad_ctor; strip_pis calls strip_ann at
# every level (round 1, ctxcat id 8), so all three spellings already
# checked and the finding is refuted on behaviour. This is the missing
# regression pin. Exact output.
out=$("$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-ann-whole.tot 2>&1)
code=$?
want=$'data WFoo : (0 A : Type 0) -> (0 _ : Nat) -> Type 0\nctor wmk : (0 A : Type 0) -> (0 x : Nat) -> ((WFoo A) x)\ndata XFoo : (0 A : Type 0) -> (0 _ : Nat) -> Type 0\nctor xmk : (0 A : Type 0) -> (0 x : Nat) -> ((XFoo A) x)\ndata YFoo : (0 A : Type 0) -> (0 _ : Nat) -> Type 0\nctor ymk : (0 A : Type 0) -> (0 x : Nat) -> ((YFoo A) x)\nWFoo : (0 A : Type 0) -> (0 _ : Nat) -> Type 0'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M4FIX-ANN-WHOLE \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-ANN-WHOLE (exit=$code)"; exit 1; }

# ctxcat r4 id 4, the NEGATIVE half: a genuinely wrong codomain under
# the SAME whole-type annotation still fails Bad_ctor, so the positive
# above is not passing because the shape stopped being checked.
out=$("$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-ann-whole-neg.tot 2>&1)
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
out=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-motive-order.tot 2>&1)
code=$?
outn=$("$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/test/fixtures/m4fix-motive-order-neg.tot 2>&1)
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
out=$("$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-wide.tot 2>&1)
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
out=$("$watchdog" 60 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-classes.tot 2>&1)
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
"$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe check "$mm_scratch/small.tot" \
  > "$mm_scratch/o1" 2> "$mm_scratch/e1"
mm_c1=$?
"$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe check "$mm_scratch/large.tot" \
  > "$mm_scratch/o2" 2> "$mm_scratch/e2"
mm_c2=$?
"$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe check "$mm_scratch/short.tot" \
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
  "$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check --serror-exit 0 \
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
"$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check --serror-exit 0 "$f2_missing" \
  > "$f2_scratch/out1" 2> "$f2_scratch/err1"
f2c1=$?
"$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check "$f2_missing" \
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
  "$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check "$@" "$f2_path" \
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
# "$watchdog" 15 so a re-blocking open is a loud 124 rather than a
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
  env TOT_PRELUDE="$pre_path" "$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check "$@" \
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
"$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check --bogus-flag /dev/null \
  > "$f2_scratch/out3" 2> "$f2_scratch/err3"
f2c3=$?
"$watchdog" 15 "$ROOT"/_build/default/bin/tot.exe check \
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
out=$("$watchdog" 60 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/m4fix-inst-branching.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true'; } \
  && echo PASS-M4FIX-INST-BRANCHING \
  || { printf '%s\n' "$out"; echo "FAIL-M4FIX-INST-BRANCHING (exit=$code)"; exit 1; }

# scratch dir removal now rides the EXIT trap installed at Gate D's top
exit 0
