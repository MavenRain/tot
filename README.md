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
no catch-all match arms.  Errors are values.  See `SPEC.md` for the design
record and the milestone plan.

## Status

M4: on top of M3's kernel and effect ladder, general recursive indexed
inductive families (`Vec`, `Fin`) with a Coq-style `match .. as .. in
.. return ..` rule;  subsingleton elimination for erased hypotheses;
homogeneous Paulin-Mohring propositional equality (`Eq`/`refl`/`J0`,
plus `subst0`/`sym0`/`trans0`/`cong0`);  a postulated `axiom` entry kind
with `--no-axioms`;  and deterministic single-parameter type classes
(`class`/`instance`/`auto`/`inst`, resolved from the expected type with
no search, coherent by `Duplicate_global` on a mangled name).  Also:
`--serror-exit N`, `--require-main`, and a stat-identity cache fast
path.  `tot` can run a `#!/usr/bin/env -S tot run` hook script directly:
`examples/guard.tot` ports the house `rg`/`sd` PreToolUse rule end to
end, reading a JSON tool-call payload on stdin and rendering an
`allow`/`ask`/`deny` verdict;  `examples/guard-classes.tot` reruns it
with the flagged command list behind a type class and two `Eq` proofs.

## Build and run

```
dune build
dune exec test/main.exe
dune exec test/surface.exe
```

or `dev/gates.sh` for the gate markers (BUILD-OK, TEST-OK, PASS-* per
script gate, SCRIPTS-OK).  The script gates check AND run
`stdlib/prelude.tot`, `examples/church.tot`, and `examples/nat.tot`.

The CLI takes a script and either typechecks it or runs it:

```
dune exec bin/tot.exe -- check examples/church.tot
dune exec bin/tot.exe -- run examples/church.tot
```

The script argument must be a REGULAR file, deliberately: process
substitution and a PIPE-backed `/dev/stdin` are rejected with `<path>:
not a regular file`, because a target that can block the checker forever
is the worse failure for a hook, so generated source goes through a real
temporary file.  The check reads the true stat, so it rejects the pipe
rather than the spelling: `tot check /dev/stdin < script.tot` redirects
from a regular file and is accepted.  The same rule applies to
`TOT_PRELUDE`.

`examples/church.tot` defines Church numerals and evaluates `cadd two
two`.  Its `run` output ends with the readback of church four:

```
def cnat : Type 1
def czero : cnat
def csucc : (w _ : cnat) -> cnat
def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
def two : cnat
fun f => fun z => (f (f (f (f z))))
```

`check` prints the same `def` lines but reports each `eval` item's type
instead of executing it.  Quantity-0 binders and arguments are erased
before execution: a runtime type argument prints as `<erased>`.

## License

MIT (LICENSE-MIT).  Dual MIT OR Apache-2.0 intended;  the Apache text is not
yet vendored.
