#!/bin/zsh
# M3 Stage C, C6: the prim catalog review surface (decision 12 of the
# M3 design verdict: "a review can read every classification in one
# place"). "tot prims" prints one line per Prim.catalog entry; this
# script asserts every line carries a non-empty justification and
# that the catalog's size agrees with the number of prim entries
# surface/bootstrap.ml actually seeds (via test/surface.exe's own
# prim-bootstrap-count argv mode, the same "reuse an already-Files-
# listed binary" discipline dev/gates.sh's Gate B checks already use).
# no set -u: the user's chpwd hook reads CARGO_TARGET_DIR unguarded
# M3 fixes round 2 (ctxcat id 4): the repo root derives from this
# script's own location, so the script works from any checkout path
# and any cwd. M3 fixes round 3 (ctxcat id 1): a symlinked $0
# resolves to its REAL path first (readlink -f, plain-$0 fallback
# where readlink -f is unavailable), matching dev/gates.sh.
ROOT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)" || exit 9
cd "$ROOT" || exit 9

out=$(dune exec --root "$ROOT" bin/tot.exe -- prims 2>&1)
code=$?
if [ "$code" -ne 0 ]; then
  printf '%s\n' "$out"
  echo FAIL-C-PRIMLINT
  exit 1
fi

# M3 fixes, C3' (C1): line discipline. Every NON-EMPTY line of "tot
# prims" must match the strict catalog-row shape; any line that does
# not (a header, an info line, a row missing its justification) is
# printed by NAME and fails the lint, instead of the old wc -l
# arithmetic that both failed spuriously on a benign header and
# undercounted on missing-trailing-newline output. n_total is then
# the strict-row count itself, so the size agreement below shares one
# line shape with the discipline check.
offenders=$(printf '%s\n' "$out" | rg --invert-match '^\S+  [0-9]+  (Tot|Div|Io)  \S' | rg '\S')
if [ -n "$offenders" ]; then
  printf '%s\n' "$offenders"
  echo "FAIL-C-PRIMLINT (lines outside the strict 'name  arity  ladder  justification' shape)"
  exit 1
fi
n_total=$(printf '%s\n' "$out" | rg -c '^\S+  [0-9]+  (Tot|Div|Io)  \S')
n_total=${n_total:-0}
if [ "$n_total" -eq 0 ]; then
  printf '%s\n' "$out"
  echo "FAIL-C-PRIMLINT (empty catalog output)"
  exit 1
fi

n_bootstrap=$(dune exec --root "$ROOT" test/surface.exe -- prim-bootstrap-count 2>/dev/null | tr -d ' ')
if [ "$n_total" != "$n_bootstrap" ]; then
  echo "FAIL-C-PRIMLINT (catalog=$n_total bootstrap=$n_bootstrap)"
  exit 1
fi

echo PASS-C-PRIMLINT
exit 0
