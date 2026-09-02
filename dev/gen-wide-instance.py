#!/usr/bin/env python3
"""Generate test/fixtures/m4fix-inst-wide.tot (M4 fixes round 4, opus R4-3).

A WIDE, SHALLOW instance query: a balanced WPair tree over L pairwise
distinct leaf types.  After the round-3 (class, key) memo the resolution
peels one telescope per DISTINCT pair, and the two-type-binder
two-dictionary-binder instance below charges exactly 6 fuel per key, so
the tree charges 6 * (L - 1) while its DEPTH is only log2 L.  The
round-3 fuel formula was a depth formula floored at a flat 10000, so it
sat at that floor and rejected the query from L = 1668 up.

Reproduce the committed fixture exactly:

    python3 dev/gen-wide-instance.py 2500 > test/fixtures/m4fix-inst-wide.tot

Usage: gen-wide-instance.py L
"""

import sys

HEADER = """\
-- M4 fixes round 4 (opus R4-3): a WIDE, SHALLOW instance query.
-- GENERATED (dev/gen-wide-instance.py, L = {L}); edit the generator,
-- not this file.  After the round-3 memo the resolution peels one
-- telescope per DISTINCT (class, key) pair and a two-type-binder
-- two-dictionary-binder instance charges exactly 6 per key, so a
-- balanced WPair tree over L pairwise distinct leaf types charges
-- 6 (L - 1) = {charge} here.  Its DEPTH is only log2 L, so the round-3
-- fuel formula sat at its flat 10000 floor and REJECTED this query
-- with Inst_depth (bisected to the leaf: L = 1667 resolves at charge
-- 9996, L = 1668 fails at 10002).  The query is finite, well formed
-- and resolvable, so that was a reachable rejection of legitimate
-- input, which is exactly what the fuel backstop's own contract
-- forbids.  inst_fuel now also scales with term_size, which sees the
-- width dimension term_depth cannot.  Exact value pinned."""


def tree(lo: int, hi: int) -> str:
    """The balanced WPair spine over leaf types [lo, hi)."""
    if hi - lo == 1:
        return f"W{lo}"
    mid = (lo + hi) // 2
    return f"(WPair {tree(lo, mid)} {tree(mid, hi)})"


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("usage: gen-wide-instance.py L\n")
        return 2
    length = int(sys.argv[1])
    sys.setrecursionlimit(100000)
    lines = (
        [HEADER.format(L=length, charge=6 * (length - 1))]
        + [
            "class WC (0 A : Type 0) := { wc : Nat }",
            "data WPair (0 A : Type 0) (0 B : Type 0) : Type 0 :="
            " | wpr : A -> B -> WPair A B",
        ]
        + [f"data W{i} : Type 0 := | w{i} : W{i}" for i in range(length)]
        + [f"instance : WC W{i} := mkWC W{i} zero" for i in range(length)]
        + [
            "instance : (0 A : Type 0) -> (0 B : Type 0) -> WC A -> WC B"
            " -> WC (WPair A B) :=",
            "  fun A B da db => mkWC (WPair A B) (wc B db)",
            f"def wq : Nat := wc {tree(0, length)} auto",
            "eval wq",
        ]
    )
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
