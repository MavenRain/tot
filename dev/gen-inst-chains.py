#!/usr/bin/env python3
"""Generate the independent-chains instance fixture (M5 Stage B).

The shape is test/fixtures/m4fix-inst-chains.tot's, parameterized by
the chain count K and the box depth N: K single-dictionary classes
W1..WK, a joiner class WR whose box instance demands one dictionary of
EVERY chain, and a query at (WBox^N Bool).  Resolution performs exactly
K * N + K + 1 sub-resolutions, linear in the input, and every
(class, key) pair is DISTINCT, so the Stage B let-nest shares nothing
here: the file pins that sharing does not DISTURB an unshared shape
(PASS-M5B-RUNTIME-IDENTITY).  The M4 fixture stays byte-identical;
this generator exists because no committed generator produced the
shape at any (K, N).

Reproduce the committed fixture exactly:

    python3 dev/gen-inst-chains.py 8 40 > test/fixtures/m5b-inst-chains-8-40.tot

Deterministic: no randomness, no hashing, no seed, no cwd dependence.
"""

import sys

HEADER = """\
-- M5 Stage B (plan B9): {K} INDEPENDENT dictionary chains over
-- (WBox^{N} Bool).  GENERATED (dev/gen-inst-chains.py {K} {N}); edit
-- the generator, not this file.  Every (class, key) pair here is
-- DISTINCT, so the Stage B let-nest has nothing to share and this file
-- pins the OUTPUT of an unshared shape instead (measured on the M4
-- HEAD binary 2026-09-02: exit 0, `true`, 0.108s; plan B0 probe P11).
-- The 800-box variant is Stage C's check-budget evidence, deliberately
-- NOT generated here (plan B12)."""


def boxes(n: int) -> str:
    """The query type (WBox^n Bool), fully parenthesized."""
    out = "Bool"
    for _i in range(n):
        out = f"(WBox {out})"
    return out


def gen(k: int, n: int) -> list:
    lines = [HEADER.format(K=k, N=n)]
    lines += [f"class W{j} (0 A : Type 0) := {{ w{j} : Bool }}" for j in range(1, k + 1)]
    lines.append("class WR (0 A : Type 0) := { wr : Bool }")
    lines.append("data WBox (0 A : Type 0) : Type 0 := | wbox : A -> WBox A")
    for j in range(1, k + 1):
        lines.append(f"instance : W{j} Bool := mkW{j} Bool true")
        lines.append(
            f"instance : (0 A : Type 0) -> W{j} A -> W{j} (WBox A) := "
            f"fun A d => mkW{j} (WBox A) true"
        )
    lines.append("instance : WR Bool := mkWR Bool true")
    telescope = " -> ".join([f"W{j} A" for j in range(1, k + 1)])
    binders = " ".join([f"d{j}" for j in range(1, k + 1)])
    lines.append(
        f"instance : (0 A : Type 0) -> {telescope} -> WR (WBox A) := "
        f"fun A {binders} => mkWR (WBox A) true"
    )
    lines.append(f"def joinedChains : Bool := wr {boxes(n)} auto")
    lines.append("eval joinedChains")
    return lines


def main() -> int:
    if len(sys.argv) != 3 or not sys.argv[1].isdigit() or not sys.argv[2].isdigit():
        sys.stderr.write("usage: gen-inst-chains.py K N\n")
        return 2
    print("\n".join(gen(int(sys.argv[1]), int(sys.argv[2]))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
