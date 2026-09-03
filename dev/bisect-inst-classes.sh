#!/bin/zsh
# M5 Stage C (pin 12, plan C7): the K-leaf re-bisection for the
# classes-K instance-fuel shape, as an EXECUTABLE rule instead of
# prose.  One line per probe, one VERDICT line, one MARGIN-PIN line.
#
# THE RULE.
#   1. Start at K = 61, the M4 leaf (measured on M4 HEAD: K = 60
#      resolves at exit 0 in 0.32 s, K = 61 reports Inst_depth at
#      exit 1 in 0.16 s).
#   2. DOUBLE: probe 61, 122, 244, 488, in that order (488 = K_max,
#      three doublings from 61; the K = 976 file is about 31 MB and
#      breaches the file ceiling, so 488 is the last doubling that
#      fits).
#   3. Stop the doubling at the FIRST K whose run reports "exceeded
#      its fuel" at exit 1, then BISECT the half-open interval
#      (last resolving K, first rejecting K] by halving until the two
#      differ by 1.  That pair is the leaf.
#   4. Stop the doubling early at the first K that breaches ANY
#      ceiling below, report NOLEAF<=K_reached, and do not bisect.
#   5. Any other exit code (124 from the watchdog, 2, or a signal)
#      aborts the search and is reported as such.  A timeout is not a
#      rejection.
#
# CEILINGS, checked BEFORE each probe runs: generated file at most
# 8 MB; wall clock at most 120 s per probe (timeout).
#
# MARGIN-PIN (the PASS-M5C-LEAF-MARGIN input): the largest probed K
# that RESOLVED, subject to file <= 1 MB and measured run <= 10 s, and
# additionally K <= floor(0.8 * leaf) when a leaf was found.  In the
# NOLEAF case the pin is the largest resolving probe under those two
# affordability ceilings and NO margin is invented (pin 12).
#
# Re-measurement is a STANDING instruction: re-run this script after
# any change to inst_fuel or to build_instance's charge accounting.
ROOT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)" || exit 9
cd "$ROOT" || exit 9
zmodload zsh/datetime || exit 9
BIN="$ROOT/_build/default/bin/tot.exe"
[ -x "$BIN" ] || { echo "ABORT: $BIN not built"; exit 9; }
watchdog=""
if command -v timeout > /dev/null 2>&1; then watchdog=timeout
elif command -v gtimeout > /dev/null 2>&1; then watchdog=gtimeout
fi
[ -n "$watchdog" ] || { echo "ABORT: no timeout/gtimeout on PATH"; exit 9; }
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/tot-bisect.XXXXXX")" || exit 9
trap 'rm -rf "$SCRATCH"' EXIT
FILE_CEIL=$((8 * 1024 * 1024))
PIN_FILE_CEIL=$((1024 * 1024))

# probe K: prints one "PROBE K=..." line; communicates the class back
# through $probe_result (resolve|reject|ceiling|abort) plus
# $probe_bytes and $probe_secs.
probe() {
  local k="$1"
  probe_result=abort
  probe_bytes=0
  probe_secs=0
  python3 "$ROOT/dev/gen-inst-fuel.py" classes "$k" > "$SCRATCH/cls$k.tot" \
    || { echo "PROBE K=$k ABORT: generator failed"; return 1; }
  probe_bytes=$(wc -c < "$SCRATCH/cls$k.tot" | tr -d ' ')
  if [ "$probe_bytes" -gt "$FILE_CEIL" ]; then
    probe_result=ceiling
    echo "PROBE K=$k bytes=$probe_bytes CEILING: file above 8 MB, not run"
    return 0
  fi
  local t0=$EPOCHREALTIME
  local out code
  out=$("$watchdog" 120 "$BIN" run "$SCRATCH/cls$k.tot" 2>&1)
  code=$?
  local t1=$EPOCHREALTIME
  probe_secs=$(printf '%.2f' $((t1 - t0)))
  if [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'zero' \
      && ! printf '%s\n' "$out" | rg -q 'fuel'; then
    probe_result=resolve
    echo "PROBE K=$k bytes=$probe_bytes secs=$probe_secs RESOLVES (exit 0, zero)"
  elif [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q 'exceeded its fuel'; then
    probe_result=reject
    echo "PROBE K=$k bytes=$probe_bytes secs=$probe_secs REJECTS (exit 1, fuel)"
  elif [ "$code" -eq 124 ]; then
    probe_result=abort
    echo "PROBE K=$k bytes=$probe_bytes secs=$probe_secs ABORT: timeout (exit 124 is not a rejection)"
  else
    probe_result=abort
    echo "PROBE K=$k bytes=$probe_bytes secs=$probe_secs ABORT: unexpected exit $code"
    printf '%s\n' "$out" | tail -n 2
  fi
  return 0
}

best_pin_k=0
best_pin_bytes=0
best_pin_secs=0
note_pin() {
  # record the largest resolving probe inside the PIN ceilings
  local k="$1" bytes="$2" secs="$3"
  if [ "$bytes" -le "$PIN_FILE_CEIL" ] \
      && [ "$(printf '%.0f' $((secs * 100)))" -le 1000 ] \
      && [ "$k" -gt "$best_pin_k" ]; then
    best_pin_k="$k"
    best_pin_bytes="$bytes"
    best_pin_secs="$secs"
  fi
}

last_ok=0
first_bad=0
reached=0
for k in 61 122 244 488; do
  probe "$k" || exit 1
  case "$probe_result" in
    resolve) last_ok="$k"; reached="$k"; note_pin "$k" "$probe_bytes" "$probe_secs" ;;
    reject) first_bad="$k"; reached="$k"; break ;;
    ceiling) break ;;
    abort) echo "VERDICT: ABORTED at K=$k"; exit 1 ;;
  esac
done

if [ "$first_bad" -gt 0 ]; then
  lo="$last_ok"
  hi="$first_bad"
  while [ $((hi - lo)) -gt 1 ]; do
    mid=$(((lo + hi) / 2))
    probe "$mid" || exit 1
    case "$probe_result" in
      resolve) lo="$mid"; note_pin "$mid" "$probe_bytes" "$probe_secs" ;;
      reject) hi="$mid" ;;
      ceiling) echo "VERDICT: ABORTED (ceiling inside bisection at K=$mid)"; exit 1 ;;
      abort) echo "VERDICT: ABORTED at K=$mid"; exit 1 ;;
    esac
  done
  echo "VERDICT: leaf K=$lo resolves, K=$hi rejects"
  margin=$((hi * 8 / 10))
  # 2026-09-03 (M5 review round): the 0.8x cap can sit below the
  # largest probed resolving K.  The capped K itself was never probed,
  # so no bytes/secs are claimed for it; the measured pair stays
  # attached to the K it was recorded at.
  if [ "$best_pin_k" -gt "$margin" ]; then
    echo "MARGIN-PIN: K<=$margin (0.8 x leaf; cap is UNPROBED); largest probed resolving K=$best_pin_k (bytes=$best_pin_bytes secs=$best_pin_secs)"
  else
    echo "MARGIN-PIN: K<=$margin (0.8 x leaf); largest affordable probed K=$best_pin_k (bytes=$best_pin_bytes secs=$best_pin_secs)"
  fi
else
  echo "VERDICT: NOLEAF<=$reached (no rejecting K inside the search bound)"
  echo "MARGIN-PIN: K=$best_pin_k (largest resolving probe with file<=1MB and run<=10s; bytes=$best_pin_bytes secs=$best_pin_secs; no margin invented, pin 12)"
fi
exit 0
