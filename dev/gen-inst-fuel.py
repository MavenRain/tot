#!/usr/bin/env python3
"""Generate the two round-5 instance-fuel fixtures (M4 fixes round 5).

Round 4 sized inst_fuel as a MAX of a depth-scaled term and a
width-scaled term, and the resolution walk charges their PRODUCT: after
the (class, key) memo it peels one telescope per DISTINCT (class, key)
pair, so the total is (number of distinct keys) x (per-key cost), and
the per-key cost is 1 per type binder plus 2 per dictionary binder of
the widest registered instance.  A MAX bounds a product only up to the
smaller factor, so both dimensions were reachable:

  classes   dev/gen-inst-fuel.py classes K  ->  m4fix-inst-classes.tot
    K single-field classes and one WPair instance per class demanding
    every class on BOTH parameters, so each instance carries 2 K
    dictionary binders and the walk charges about K^2 per query node
    while every round-4 term was linear in K.  Bisected on the round-4
    binary over a four-leaf query: K = 56 resolves, K = 57 reports
    Inst_depth.

  binders   dev/gen-inst-fuel.py binders L   (NOT a committed fixture)
    Three classes and an EIGHT-binder instance (2 type binders, 6
    dictionary binders), which validate_instance_shape accepts, against
    the same balanced WPair tree the width fixture uses.  Round 4's
    width term was 8 * term_size with NO per-key factor, so it was
    calibrated for the shipped 2-type-binder 2-dictionary-binder shape
    (charge 6 per key) alone;  this instance charges about 14 per key
    for each of 3 classes.

    This mode reproduces a MEASUREMENT, not a committed fixture.  As a
    surface file the shape also pays the mandatory candidate re-check,
    which walks the resolved dictionary as a tree (Term.t has no
    sharing): measured, the round-4 binary rejects L = 256 in 1s while
    the round-5 binary resolves it in 20s, and L = 320 takes 47s.  A
    20s gate leg buys nothing the same shape does not buy in-kernel, so
    the pin lives in test/main.ml as D9f and this mode stays here as
    the recipe for re-measuring the surface cost.

Reproduce the committed fixture exactly:

    python3 dev/gen-inst-fuel.py classes 57 > test/fixtures/m4fix-inst-classes.tot

Deterministic: no randomness, no hashing, no seed, no cwd dependence.
"""

import sys

CLASSES_HEADER = """\
-- M4 fixes round 5 (opus R5-2): the CLASS-COUNT dimension of the
-- instance-fuel bound.  GENERATED (dev/gen-inst-fuel.py classes {K});
-- edit the generator, not this file.  {K} single-field classes, one
-- WPair instance per class demanding every class on BOTH parameters
-- (so every instance carries 2 * {K} dictionary binders), and a query
-- four leaves deep.  The walk charges about K^2 per query node, while
-- every term of the round-4 fuel formula was LINEAR in K, so the
-- backstop fired on a finite, well formed, resolvable query.  Bisected
-- on the round-4 binary to the leaf: K = 56 resolves at exit 0, K = 57
-- reports "instance resolution for (C0 ((WPair ((WPair Waaaa) Wbbbb))
-- ((WPair Wcccc) Wdddd))) exceeded its fuel" at exit 1.  inst_fuel is
-- now the PRODUCT of a key-count bound and the per-key cost, and the
-- per-key cost is where the class count enters.  Exact value pinned."""

BINDERS_HEADER = """\
-- M4 fixes round 5 (ctxcat r5 id 16): the PER-KEY-COST dimension of the
-- instance-fuel bound.  GENERATED (dev/gen-inst-fuel.py binders {L});
-- edit the generator, not this file.  Round 4's width term was
-- 8 * term_size with no per-key factor, so it was calibrated for the
-- shipped two-type-binder two-dictionary-binder instance (charge 6 per
-- key) alone.  The three instances below each carry EIGHT binders (2
-- type, 6 dictionary), a shape validate_instance_shape accepts, so the
-- same balanced WPair tree over {L} pairwise distinct leaf types
-- charges about 14 per key for each of 3 classes instead of 6 for one.
-- The round-4 binary reports Inst_depth on this file;  the round-5
-- product bound resolves it with room to spare.  Exact value pinned."""


def tree(lo: int, hi: int) -> str:
    """The balanced WPair spine over leaf types [lo, hi)."""
    if hi - lo == 1:
        return f"W{lo}"
    mid = (lo + hi) // 2
    return f"(WPair {tree(lo, mid)} {tree(mid, hi)})"


def gen_classes(k: int) -> list:
    leaves = ["Waaaa", "Wbbbb", "Wcccc", "Wdddd"]
    telescope = " -> ".join(
        [f"C{j} A -> C{j} B" for j in range(k)]
    )
    binders = " ".join([f"da{j} db{j}" for j in range(k)])
    lines = [CLASSES_HEADER.format(K=k)]
    lines += [f"class C{j} (0 A : Type 0) := {{ f{j} : Nat }}" for j in range(k)]
    lines += [f"data {name} : Type 0 := | mk{name} : {name}" for name in leaves]
    lines += [
        "data WPair (0 A : Type 0) (0 B : Type 0) : Type 0 :="
        " | wpr : A -> B -> WPair A B"
    ]
    for j in range(k):
        for name in leaves:
            lines.append(f"instance : C{j} {name} := mkC{j} {name} zero")
    for j in range(k):
        lines.append(
            "instance : (0 A : Type 0) -> (0 B : Type 0) -> "
            + telescope
            + f" -> C{j} (WPair A B) :="
        )
        lines.append(f"  fun A B {binders} => mkC{j} (WPair A B) zero")
    query = "(WPair (WPair Waaaa Wbbbb) (WPair Wcccc Wdddd))"
    lines.append(f"def q : Nat := f0 {query} auto")
    lines.append("eval q")
    return lines


def gen_binders(length: int) -> list:
    classes = ["PA", "PB", "PC"]
    telescope = " -> ".join([f"{c} A -> {c} B" for c in classes])
    binders = " ".join([f"d{c.lower()}a d{c.lower()}b" for c in classes])
    lines = [BINDERS_HEADER.format(L=length)]
    lines += [f"class {c} (0 A : Type 0) := {{ {c.lower()} : Nat }}" for c in classes]
    lines += [
        "data WPair (0 A : Type 0) (0 B : Type 0) : Type 0 :="
        " | wpr : A -> B -> WPair A B"
    ]
    lines += [f"data W{i} : Type 0 := | w{i} : W{i}" for i in range(length)]
    for c in classes:
        lines += [f"instance : {c} W{i} := mk{c} W{i} zero" for i in range(length)]
    for c in classes:
        lines.append(
            "instance : (0 A : Type 0) -> (0 B : Type 0) -> "
            + telescope
            + f" -> {c} (WPair A B) :="
        )
        lines.append(f"  fun A B {binders} => mk{c} (WPair A B) zero")
    lines.append(f"def bq : Nat := pa {tree(0, length)} auto")
    lines.append("eval bq")
    return lines


def main() -> int:
    if len(sys.argv) != 3 or sys.argv[1] not in ("classes", "binders"):
        sys.stderr.write("usage: gen-inst-fuel.py classes K | binders L\n")
        return 2
    sys.setrecursionlimit(100000)
    n = int(sys.argv[2])
    lines = gen_classes(n) if sys.argv[1] == "classes" else gen_binders(n)
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
