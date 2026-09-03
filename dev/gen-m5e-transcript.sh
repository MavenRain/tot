#!/bin/zsh
ROOT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)" || exit 9
cd "$ROOT" || exit 9
export LC_ALL=C
# Conflict note C-E1 (2026-09-02): the plan pins a bare `mktemp -d`,
# which on this machine resolves to the Darwin per-user temp dir and
# fails under the build sandbox (mkdtemp: Operation not permitted).
# Every scratch in dev/gates.sh uses the TMPDIR-template form instead,
# so this script keeps the pinned intent (a self-cleaning scratch) via
# the file's sibling idiom.
scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-m5e-transcript.XXXXXX") || exit 9
trap 'rm -rf "$scratch"' EXIT
for f in examples/*.tot test/fixtures/*.tot; do
  printf '### %s\n' "$f"
  _build/default/bin/tot.exe check "$f" > "$scratch/o" 2> "$scratch/e"
  printf '#exit %d\n#out\n' $?
  cat "$scratch/o"
  printf '#err\n'
  cat "$scratch/e"
done
