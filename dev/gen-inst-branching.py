#!/usr/bin/env python3
"""Generate the two-dictionary-binder branching instance fixture (M5 Stage B).

The shape is test/fixtures/m4fix-inst-branching.tot's, parameterized by
the nesting: one class SC, one box SBox, a ground instance at Bool and
a box instance demanding TWO dictionaries of the SAME sub-goal, so the
un-shared emitted term follows the plan B0 recurrence

    T(0) = 1        T(n) = 2 * T(n - 1) + 2n + 2
    T(16) = 458714  T(20) = 7339986

while the shared let-nest is S(n) = 2n^2 + 9n + 6 (S(20) = 986).  The
M4 fixture stays byte-identical at nesting 16; this generator exists
because no committed generator produced depth 20.

Reproduce the committed fixture exactly:

    python3 dev/gen-inst-branching.py 20 > test/fixtures/m5b-inst-branching-20.tot

Deterministic: no randomness, no hashing, no seed, no cwd dependence.
"""

import sys

HEADER = """\
-- M5 Stage B (plan B9): the branching shape at nesting {N}.  GENERATED
-- (dev/gen-inst-branching.py {N}); edit the generator, not this file.
-- One instance with TWO dictionary binders on the SAME type variable,
-- so the un-shared M4 emission is a binary tree of 2^n nodes that the
-- mandatory candidate re-check walks whole: measured on the M4 HEAD
-- binary 2026-09-02, `run` at nesting 20 takes 30.188s and `check`
-- 31.570s (plan B0, probes P9/P10).  With the Stage B let-nest the
-- emitted term is S({N}) nodes and the file runs in milliseconds;
-- PASS-M5B-BRANCHING-20 pins that inside a 10s watchdog."""


def boxes(n: int) -> str:
    """The query type (SBox^n Bool), fully parenthesized."""
    out = "Bool"
    for _i in range(n):
        out = f"(SBox {out})"
    return out


def gen(n: int) -> list:
    return [
        HEADER.format(N=n),
        "class SC (0 A : Type 0) := { sc : Bool }",
        "data SBox (0 A : Type 0) : Type 0 := | sbox : A -> SBox A",
        "instance : SC Bool := mkSC Bool true",
        "instance : (0 A : Type 0) -> SC A -> SC A -> SC (SBox A) :=",
        "  fun A d1 d2 => mkSC (SBox A) true",
        f"def deepBranching : Bool := sc {boxes(n)} auto",
        "eval deepBranching",
    ]


def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1].isdigit():
        sys.stderr.write("usage: gen-inst-branching.py N\n")
        return 2
    print("\n".join(gen(int(sys.argv[1]))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
