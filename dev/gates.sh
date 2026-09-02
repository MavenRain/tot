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
main_out=$("$watchdog" 120 dune exec --root "$ROOT" test/main.exe); t1=$?
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

unset TOT_CACHE_DIR TOT_CACHE_VERIFY TOT_PRELUDE
# scratch dir removal now rides the EXIT trap installed at Gate D's top
exit 0
