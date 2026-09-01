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

M0: the kernel (terms, NbE evaluation, conversion, bidirectional checker,
quantity checking) with its test suite. There is no parser yet.

## Build

```
dune build
dune exec test/main.exe
```

or `dev/gates.sh` for the gate markers.

## License

MIT (LICENSE-MIT). Dual MIT OR Apache-2.0 intended; the Apache text is not
yet vendored.
