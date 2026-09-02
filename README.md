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

M3: the M2 kernel (terms, NbE evaluation, conversion, bidirectional
checker, quantity checking, parameterized `data`, dependent `match`,
structurally recursive `def rec`) plus an effect ladder (`Div` for
provenance-tracked host divergence, `IO` reified as an inert action
tree), `String`/`Int` literals and a closed native-prim catalog
(string, int, JSON, process, regex), `let*`/`let*!`/`partial` surface
sugar, and a prelude (`stdlib/prelude.tot`: Bool, Nat, Option, Result,
List, Pair, Json, ProcessResult, Ordering, Verdict, ...) that `tot`
auto-loads and caches on disk. `tot` can now run a `#!/usr/bin/env -S
tot run` hook script directly: `examples/guard.tot` ports the house
`rg`/`sd` PreToolUse rule end to end, reading a JSON tool-call payload
on stdin and rendering an `allow`/`ask`/`deny` verdict.

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
