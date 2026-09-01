# tot

A total, dependently typed scripting language for everyday tooling: hooks,
gate scripts, and small CLIs.

Design goals, in priority order:

1. Type strength at the Lean 4 level: full dependent types, quantities for
   erasure, totality by default.
2. Script-grade startup: check once, cache the elaborated core, start in
   milliseconds.
3. OCaml-grade expressiveness on the ML fragment, with tracked effects
   instead of ambient ones.

The language has no exceptions, no loop keywords, no partial indexing, and
no catch-all match arms. Errors are values. See `SPEC.md` for the design
record and the milestone plan.

## Status

M2: the kernel (terms, NbE evaluation, conversion, bidirectional checker,
quantity checking) plus surface syntax, an elaborator, structural
erasure, a call-by-value interpreter, and the `tot` CLI — now with
parameterized inductive types (`data`), dependent `match`, structurally
recursive `def rec` (totality-checked, guarded unfolding), and a core
prelude (`stdlib/prelude.tot`: Bool, Nat, Option, Result, List, Pair).

## Build and run

```
dune build
dune exec test/main.exe
dune exec test/surface.exe
```

or `dev/gates.sh` for the gate markers (BUILD-OK, TEST-OK, PASS-* per
script gate, SCRIPTS-OK). The script gates check AND run
`stdlib/prelude.tot`, `examples/church.tot`, and `examples/nat.tot`.

The CLI takes a script and either typechecks it or runs it:

```
dune exec bin/tot.exe -- check examples/church.tot
dune exec bin/tot.exe -- run examples/church.tot
```

`examples/church.tot` defines Church numerals and evaluates `cadd two
two`. Its `run` output ends with the readback of church four:

```
def cnat : Type 1
def czero : cnat
def csucc : (w _ : cnat) -> cnat
def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
def two : cnat
fun f => fun z => (f (f (f (f z))))
```

`check` prints the same `def` lines but reports each `eval` item's type
instead of executing it. Quantity-0 binders and arguments are erased
before execution: a runtime type argument prints as `<erased>`.

## License

MIT (LICENSE-MIT). Dual MIT OR Apache-2.0 intended; the Apache text is not
yet vendored.
