# M3 build log

## Stage A: literals, builtin base types, the `Prim` entry kind

Baseline before this stage (verified 2026-09-01, before any edit): `dune
build`, `test/main.exe`, `test/surface.exe` and
`bin/tot.exe -- run examples/church.tot` all green, 36 kernel + 38
surface tests. Built directly on top of the STAGED, uncommitted M2 fix
batch already in the tree; nothing in that batch was reverted (only the
`Edit` tool was used against pre-existing files, never a full-file
`Write`; the three genuinely new files are `lib/literal.ml`,
`lib/prim.ml`, `surface/bootstrap.ml`).

### What changed

`Term.Lit`, `Value.VLit`, `Eterm.ELit` end to end: parse (a new
double-quoted string-literal lexer rule plus the existing `Nat` token
reused for int literals), elaborate (`Syntax.SStr`/`SInt`), check
(infers `String`/`Int` by evaluating `Term.Global "String"`/`"Int"`),
erase (structural, unchanged shape), execute (`Interp.VLit`), quote, and
print (a shared `Pp.escape_string`, `\\`/`\"`/`\n`/`\t` escaped).
`Global.entry` gained a fourth kind, `Prim`, with no `def` field and no
`reducible` field, so `Eval.eval`'s `Term.Global` arm has no way to
unfold it: opacity is structural, not policy. `Interp.v` gained
`VPrim of Prim.t * v list`, accumulating KEPT arguments toward the
catalog arity and firing inline once full (`Interp.fire_prim`, all
eight Stage A prims are `Tot`). `surface/bootstrap.ml` (new) owns the
builtin environment: two phases (`phase1` seeds `String`/`Int` as
declared-only inductives plus the five prims that mention only
builtins; `phase2` seeds the three `Bool`-mentioning prims after the
prelude has folded, then verifies `required_ctors = ["true"; "false"]`
resolves in both `Global.t` and `Interp.globals`). `bin/tot.ml` is
untouched (Stage D wires it to `Bootstrap.state ()`); Stage A tests
reach the bootstrapped environment directly via
`Run.script ~st:(Bootstrap.state ()) ...`, using the new optional `?st`
parameter on `Run.script` (default `initial`, so every existing caller
is unchanged).

### Files touched

New: `lib/literal.ml`, `lib/prim.ml`, `surface/bootstrap.ml`,
`examples/literals.tot`.

Edited: `lib/term.ml`, `lib/value.ml`, `lib/eval.ml`, `lib/global.ml`,
`lib/check.ml`, `lib/erase.ml`, `lib/eterm.ml`, `lib/interp.ml`,
`lib/pp.ml`, `lib/error.ml`, `surface/token.ml`, `surface/lexer.ml`,
`surface/parser.ml`, `surface/syntax.ml`, `surface/elab.ml`,
`surface/run.ml`, `test/main.ml`, `test/surface.ml`, `dev/gates.sh`.

Also edited, NOT in the plan's Stage A file list but required by the
ground rules' own exhaustiveness discipline (adding `Value.VLit` /
`Term.Lit` forced the compiler to point at every existing match over
those types): `lib/totality.ml` (7 sites: `peel`, `spine`, `mentions`,
`guarded_call`'s arg match, `ok`'s outer match, `ok`'s `head_ok` match,
`ok`'s `scrut_special` match) and two pre-existing test-only matches in
`test/main.ml` (`case_partial_ctor_not_canonical`'s `Value.t` match,
`eterm_mentions`'s `Eterm.t` match). Recorded here per the plan's own
instruction to log an argument when filling a gap rather than silently
absorbing it.

### New `Error.t` variants

- `Prim_arity of { prim : string; expected : int; found : int }` —
  total backstop, unreachable on a checked program (an application
  spine grown past a prim's catalog arity).
- `Not_quotable of string` — the `quote` signature is stabilized now;
  Stage B's `VIOAction` is its first real user.
- `Missing_prelude_ctor of string` — named in the plan's A16 prose
  (`Bootstrap.phase2`) but not listed in A10's variant bullets; added
  here since `phase2` needs it. Fires if a name in `required_ctors`
  fails to resolve in either environment after the prelude folds.

### New prims (Stage A catalog, all `Tot`)

| name | arity | justification |
|---|---|---|
| `stringConcat` | 2 | OCaml string concatenation is total |
| `stringLength` | 1 | byte length of a finite string is total |
| `stringEq` | 2 | byte equality is total |
| `stringContains` | 2 | substring scan is O(n*m) and total |
| `intAdd` | 2 | OCaml int addition wraps, never diverges |
| `intSub` | 2 | OCaml int subtraction wraps, never diverges |
| `intEq` | 2 | int equality is total |
| `intToString` | 1 | decimal rendering of an int is total |

### Tests added

`test/main.ml` (kernel, 36 -> 44): `A1: literal Term.Lit infers its
declared builtin type`, `A2: literal infer is Unbound_global without
String declared`, `A3: VLit conv is structural equality, not
cross-kind`, `A4: two prim spines of equal arity are opaque under
conv`, `A5: Eval.eval backstop on a VLit match scrutinee is
Not_inductive`, `A6: literal round-trips check/erase/exec/quote/pp with
escapes`, `A7: Check.define_prim rejects a duplicate name`, `A8:
Prim.catalog is duplicate-free, round-trips, and is justified`.

`test/surface.ml` (surface, 38 -> 44): `A9: eval stringConcat
computes`, `A10: eval intAdd computes`, `A11: check mode prints the
String and Int result types`, `A12: partial stringConcat quotes as a
frozen prim spine`, `A13: literal type mismatch is a kernel error`,
`A14: match on a String scrutinee cannot eliminate (declared-only
ind)`. Test 15 (M1 numeric literal cap) already existed
("lex numeric literal cap") and still passes unchanged.

`dev/gates.sh`: new `PASS-A-LITERALS` marker. `bin/tot.ml` has no
prelude/bootstrap auto-load until Stage D (D1), so
`examples/literals.tot` cannot run through the plain `tot run` CLI yet;
the marker instead greps `test/surface.exe`'s own captured output for
the exact `PASS A9`/`PASS A10` lines, which pin exact computed values
(`"ab"`, `5`) through `Run.script` seeded by `Bootstrap.state ()` — the
same computation `examples/literals.tot` illustrates, documented as
forward-compatible for Stage D in the fixture's own header comment.

### Gate output tails

```
$ dune build --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dune exec --root /Users/oobi/Documents/tot test/main.exe | tail -5
PASS A6: literal round-trips check/erase/exec/quote/pp with escapes
  expected error (Duplicate_global): duplicate global p
PASS A7: Check.define_prim rejects a duplicate name
PASS A8: Prim.catalog is duplicate-free, round-trips, and is justified
M0 kernel: all tests green

$ dune exec --root /Users/oobi/Documents/tot test/surface.exe | tail -5
  expected error (Kernel.Mismatch): 1:1: type mismatch: expected String, found Int
PASS A13: literal type mismatch is a kernel error
  expected error (Kernel.Ind_incomplete): 1:1: cannot eliminate String: its constructors are declared but not yet defined
PASS A14: match on a String scrutinee cannot eliminate (declared-only ind)
M1 surface: all tests green

$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run examples/church.tot | tail -3
def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
def two : cnat
fun f => fun z => (f (f (f (f z))))

$ dev/gates.sh
BUILD-OK
... (44 kernel PASS lines) ...
M0 kernel: all tests green
... (44 surface PASS lines) ...
M1 surface: all tests green
TEST-OK
PASS-A-LITERALS
PASS-CHECK-PRELUDE
PASS-RUN-PRELUDE
PASS-CHECK-CHURCH
PASS-RUN-CHURCH
PASS-CHECK-NAT
PASS-RUN-NAT
SCRIPTS-OK
exit=0
```

Gate A (i)-(iv), all confirmed above: (i) 36+8 kernel and 38+6 surface,
no edits to any existing test term; (ii) test A6 round-trips a literal
through parse/check/erase/exec/quote; (iii) test A4 pins that two
distinct prim spines of equal arity are convertible only when
syntactically identical; (iv) tests A9/A10 (and the `PASS-A-LITERALS`
gate) pin `stringConcat`/`intAdd` computing correctly in run mode.

Stage A green. Next: Stage B (the ladder end to end, minimally).

## Stage B: the ladder end to end, minimally

Baseline before this stage (verified 2026-09-01, before any edit): `dune
build --root /Users/oobi/Documents/tot` (via `dunecho`) OK, 0 errors, 0
warnings; `test/main.exe` 44 PASS, "M0 kernel: all tests green";
`test/surface.exe` 44 PASS, "M1 surface: all tests green"; `bin/tot.exe --
run examples/church.tot` prints the four expected lines; `dev/gates.sh`
green end to end (`BUILD-OK`, `TEST-OK`, `PASS-A-LITERALS`,
`PASS-CHECK-PRELUDE`/`PASS-RUN-PRELUDE`/`PASS-CHECK-CHURCH`/
`PASS-RUN-CHURCH`/`PASS-CHECK-NAT`/`PASS-RUN-NAT`, `SCRIPTS-OK`, exit 0).
All of the above stayed green throughout this stage; every new test is
additive.

`Div` and `IO` exist as declared-only, zero-constructor `Ind` bootstrap
entries (each with ONE quantity-0 param, `(0 A : Type 0) -> Type 0`,
joining `String`/`Int`), non-eliminable for the same A16 reason. The five
ladder prims (`pureDiv`, `bindDiv`, `pureIO`, `bindIO`, `liftIO`) and the
four native IO prims (`readStdin`, `printLine`, `exitWith`, `getEnv`) round
the catalog out to 17. `Interp.v` gained `VIOAction of io_action`
(`IOPure`/`IOBind`/`IONative`), an inert, first-class reified action tree:
`Interp.fire_prim` (now part of `exec`'s mutually-recursive group, since
`bindDiv` needs `apply`) fires `Tot`/`Div` prims inline exactly as before,
but for `Io` prims it only ever BUILDS an action-tree node, never touching
the OS; `surface/effect.ml` (new) is the one module that does, walking a
built tree via `run_io`/`dispatch` and converting every raw host call
through one documented `try ... with _ -> ...` fence. `Interp.gentry`'s
`gval` is now a `gbody` (`GForced of v | GDeferred of Eterm.t`):
`surface/run.ml`'s `IDef` handling records a def's closed erased body
WITHOUT executing it exactly when the def's STAMPED type head is `Div` or
`IO` (keyed on the type alone, decision 11), forcing it only when an
`EGlobal` lookup or a guarded rec-global unfold reaches it; this is the
whole enforcement of hard constraint 1 (`tot check` never performs the
host computation, or the host effect, a Div/IO-headed def's body may
carry). `Check.define` separately refuses `reducible` on a Div/IO-headed
def (`Effect_def_reducible`), since conversion must never be able to step
into an effect even though building one is inert. `Run.script` gained a
`main` epilogue: absent a global literally named `main` (every M2 script,
and every non-bootstrapped script `bin/tot.exe` still runs until Stage
D's D1), it is a no-op; present and of type `IO Unit` (proven by
`Eval.conv`, not just a head test, and guarded first by `IO`/`Unit`
actually resolving so an unrelated `main` in a non-bootstrapped
environment never trips `Unbound_global`), CHECK mode still never calls
`run_io` at all, and RUN mode forces it once and calls `Effect.run_io`
exactly once, mapping `Exited n` to exit code `Some n` and everything else
to `None` (`bin/tot.ml` defaults that to 0).

### Files touched

New: `surface/effect.ml`, `test/fixtures/b-stdin-chain.tot`,
`test/fixtures/b-sentinel.tot`, `test/fixtures/b-deferred-div.tot`.

Edited: `lib/prim.ml`, `lib/interp.ml`, `lib/error.ml`, `lib/check.ml`,
`surface/bootstrap.ml`, `surface/run.ml`, `surface/dune` (added `unix`,
used only by `surface/effect.ml`), `bin/tot.ml`, `stdlib/prelude.tot`
(one line, `data Unit : Type 0 := | unit : Unit`), `test/main.ml`,
`test/surface.ml`, `dev/gates.sh`.

### Plan-detail fill-ins (recorded per the plan's own instruction)

- **Deferral mechanism (B6's "pick ONE"): a lazy `Interp.gbody` variant**,
  not a `Run`-side table of unforced defs. `Interp.define` gained
  `~defer:bool`; `Run.item`'s `IDef` case computes it by evaluating the
  checker-stamped `ty` and calling the same `Check.is_effect_headed` head
  test `Check.define`'s own `reducible` refusal uses (shared helper, one
  argument, two call sites). No memoization on force: a `GDeferred` IO
  def re-execs (never re-fires an effect; building an action is inert) on
  every reference, which is exactly the correct re-run-per-reference
  semantics D-era code will rely on for something like `argv`.
- **The Gate B (i)/(ii)/(iii) OS-observed checks needed a real, bootstrapped
  OS process, and `bin/tot.ml` explicitly stays on `Run.initial` until
  Stage D's D1** (D1's own prose: "`Run.initial` stops being the CLI's
  starting point" describes a Stage D event). Confirmed this is not
  optional: `dev/gates.sh`'s own fixed `PASS-CHECK-PRELUDE`/
  `PASS-RUN-PRELUDE` steps run `bin/tot.exe` directly against
  `stdlib/prelude.tot` as the TARGET script; if `bin/tot.ml` pre-loaded
  `Bootstrap.state ()` (which itself folds that exact file), that
  specific fixed gate command would double-define every prelude global
  and go red. Rather than add a new dune executable (not in the plan's
  Stage B Files list), `test/surface.ml` (already listed) grew a second,
  argv-gated mode: `test/surface.exe -- gate-check|gate-run PATH` bypasses
  the ordinary in-process suite, computes `Bootstrap.state ()`, runs
  `Run.script` in the requested mode, and exits with
  `Option.value exit_code ~default:0` (mirroring `bin/tot.ml`'s own
  `run_file`). A bare invocation (what `dune exec`/`dune runtest` already
  does) is unaffected: the argv dispatch's fallback arm is the ordinary
  suite, unchanged.
- **Gate B (ii)'s "sentinel file"**: Stage B's prim catalog has no
  `writeFile` yet (Stage C's C1 adds one), so the fixture's `main` writes
  its sentinel to stdout via `printLine`, and `dev/gates.sh` redirects
  BOTH the check and the run invocation to the SAME real file path,
  checking for the exact line's absence/presence there. This is a real
  file on disk, just written via shell redirection of the process's own
  stdout rather than a tot-level file-write prim.
- **Gate B (iii)'s expense**: chosen empirically, not estimated. The
  kernel's OWN evaluator never fires prims (confirmed: `Eval.eval`'s
  `Term.Global` arm for a `Prim` entry is always neutral, so
  `Check.define`'s type-checking of the fixture is cheap regardless of
  what the body computes), so the cost lives entirely in
  `Interp.fire_prim`'s `stringContains`, gated solely by the deferred
  rule. A 3,000,000-byte haystack against a 5,001-byte non-matching
  needle measured at ~1s deferred (dominated by lexing the two literals)
  vs. ~66s forced (verified by temporarily appending an `eval
  stringContains haystack needle` line to a scratch copy and timing `tot
  run`); `dev/gates.sh` asserts a 5s coarse bound, an enormous margin
  either way that stays robust to machine noise without needing a
  multi-minute regression wait to fail loud.

### New `Error.t` variant

- `Effect_def_reducible of string` -- `Check.define` refuses `reducible`
  on a def whose STAMPED type head is `Div` or `IO`; a def of type
  `String -> IO Unit` has head `VPi`, so it is unaffected.

### New prims (Stage B catalog additions)

| name | arity | ladder | justification |
|---|---|---|---|
| `pureDiv` | 1 | Div | wrapping a value as Div computes nothing of its own, but the Div marker propagates absorbingly |
| `bindDiv` | 2 | Div | sequencing Div actions inherits whatever divergence the sequenced computation carries |
| `pureIO` | 1 | Io | building an IO action is inert; firing it is run_io's job alone |
| `bindIO` | 2 | Io | sequencing IO actions defers to whatever the sequenced action observes when it is finally run |
| `liftIO` | 1 | Io | embedding a Div result into IO is the one bridge the ladder allows |
| `readStdin` | 0 | Io | consumes the process stdin, an observable effect that must not run at definition time |
| `printLine` | 1 | Io | writes to the process stdout, an observable, ordered effect |
| `exitWith` | 1 | Io | terminates the process with a caller-chosen code, an observable effect |
| `getEnv` | 1 | Io | reads process environment state, which can change between two reads of the same name |

Note the plan's own correction (B1): `pureIO`'s KEPT arity is 1 (the
value argument only), not 2 as an earlier design proposal's table had it;
`Prim.arity Pure_io = 1` matches the declared bootstrap type
`(0 A : Type 0) -> A -> IO A`, and `surface/bootstrap.ml`'s `seed_prim`
now checks every catalog entry's arity against its own declared type at
bootstrap time (`Error.Prim_arity` on a mismatch), not just in a test.

### Tests added

`test/main.ml` (kernel, 44 -> 48): `B1: every catalog prim's Prim.arity
matches its declared type's kept-binder count` (all 17, both bootstrap
phases), `B2: Check.define refuses reducible on a Div-headed def; plain
and fn-typed accepted` (three sub-checks: `reducible` on `Div String`
rejected as `Effect_def_reducible`, the same def `reducible = false`
accepted, and a `reducible` `String -> IO Unit` def accepted since its
head is `VPi`), `B3: Interp.quote on a VIOAction is Not_quotable`, `B4:
add_prim on readStdin (arity 0) stores a fired VIOAction, not a VPrim`
(proven indirectly: `Interp.quote` on the stored value is `Not_quotable`,
which only a `VIOAction` ever produces, so the shape is pinned exactly
without hand-matching every `Interp.v` constructor).

`test/surface.ml` (surface, 44 -> 47): `B5: eval bindIO ... in check mode
prints the type and executes nothing`, `B6: eval of an IO expression in
run mode is Kernel.Not_quotable (sequencing goes through main, not eval)`,
`B7: a Div-headed def whose body applies a prim is accepted, and check
does not compute it` (a light in-process companion to the heavier
`dev/gates.sh` timing fixture).

`dev/gates.sh` (process level, OS-observed, via `test/surface.exe -- \
gate-check|gate-run`): `PASS-B-EXITCODE` (three chained `bindIO` steps
over a stdin fixture, `"hello\n"`, exit exactly 6 = `stringLength`),
`PASS-B-NOEFFECT` (constraint 1: `tot check` on
`test/fixtures/b-sentinel.tot` writes nothing where `tot run` writes
`SENTINEL-WRITTEN`), `PASS-B-DEFERRED` (`test/fixtures/b-deferred-div.tot`
completes `tot check` in <=5s; the same body, forced, measured ~66s).

### Gate output tails

```
$ dunecho build -- --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dune exec --root /Users/oobi/Documents/tot test/main.exe | tail -8
PASS B1: every catalog prim's Prim.arity matches its declared type's kept-binder count
  expected error (Effect_def_reducible): def tB4bad: reducible on a Div- or IO-headed def is not allowed
PASS B2: Check.define refuses reducible on a Div-headed def; plain and fn-typed accepted
  expected error (Not_quotable): cannot read back a io action value
PASS B3: Interp.quote on a VIOAction is Not_quotable
PASS B4: add_prim on readStdin (arity 0) stores a fired VIOAction, not a VPrim
M0 kernel: all tests green

$ dune exec --root /Users/oobi/Documents/tot test/surface.exe | tail -5
PASS B5: eval bindIO ... in check mode prints the type and executes nothing
  expected error (Kernel.Not_quotable): 1:1: cannot read back a io action value
PASS B6: eval of an IO expression in run mode is Kernel.Not_quotable (sequencing goes through main, not eval)
PASS B7: a Div-headed def whose body applies a prim is accepted, and check does not compute it (paired with the heavier dev/gates.sh PASS-B-DEFERRED timing fixture)
M1 surface: all tests green

$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run examples/church.tot | tail -3
def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
def two : cnat
fun f => fun z => (f (f (f (f z))))

$ dev/gates.sh
BUILD-OK
... (48 kernel PASS lines) ...
M0 kernel: all tests green
... (47 surface PASS lines) ...
M1 surface: all tests green
TEST-OK
PASS-A-LITERALS
PASS-CHECK-PRELUDE
PASS-RUN-PRELUDE
PASS-CHECK-CHURCH
PASS-RUN-CHURCH
PASS-CHECK-NAT
PASS-RUN-NAT
SCRIPTS-OK
PASS-B-EXITCODE
PASS-B-NOEFFECT
PASS-B-DEFERRED
exit=0
```

Gate B (i)-(iv), all confirmed above: (i) `PASS-B-EXITCODE`, a real
three-step `bindIO` sequence over stdin exits with the value it computed,
not a hardcoded one; (ii) `PASS-B-NOEFFECT`, `tot check` on a
sentinel-writing `main` writes nothing, `tot run` writes it for real;
(iii) `PASS-B-DEFERRED`, a Div-headed def built from a prim expensive
enough (empirically ~66s if forced) that a 5s coarse bound is an
unambiguous signal, leaves `tot check` fast; (iv) every M2
guarded-unfolding conversion test (F1/F3/F4/F5/F6/R0/T0/S3 and the plain
church/Nat cases) is unmodified and still green, both in `test/main.exe`
and via `bin/tot.exe -- run examples/{church,nat}.tot`.

Stage B green. Next: Stage C (stdlib breadth and surface sugar).

## Stage C: stdlib breadth and surface sugar

Baseline before this stage (verified 2026-09-01, before any edit): `dune
build` OK, 0/0; `test/main.exe` 48 PASS, "M0 kernel: all tests green";
`test/surface.exe` 47 PASS, "M1 surface: all tests green"; `bin/tot.exe --
run examples/church.tot` prints the four expected lines; `dev/gates.sh`
green end to end. All of the above stayed green throughout this stage
except `PASS-CHECK-PRELUDE`/`PASS-RUN-PRELUDE`, whose IMPLEMENTATION
changed for a real architectural reason recorded below (the markers
themselves still print, unconditionally on success).

The catalog grows 17 -> 29 (`lib/prim.ml`): `stringSlice`(3,Tot),
`stringSplit`(2,Tot), `stringToInt`(1,Tot), `intCompare`(2,Tot),
`readFile`(1,Io), `writeFile`(2,Io), `argv`(0,Io), `procRun`(2,Io),
`jsonParse`(1,Div), `jsonSerialize`(1,Tot), `regexTest`(2,Div),
`regexMatch`(2,Div) — exactly the plan's C1 table, arities and
classifications as specified. `stdlib/prelude.tot` gains `Ordering`,
`Verdict`, `ProcessResult`, the self-recursive `Json` (eight ctors, each
mentioning `Json` only as `Json`, per decision 2), and the accessor defs
`headOr`/`jsonGet`/`jsonAsString`/`jsonAsInt`/`jsonGetString`/
`jsonGetStringOr`/`jsonToList`, all as C2 specifies. `partial` (C4) is
end to end: lexer keyword, parser (`rec` then `partial`), `Syntax.IDef`,
`Global.def_entry`, `Check.define ~partial`, two new `Error.t` variants.
`let*`/`let*!` (C3) lex, parse, and desugar in `Elab.term`. `tot prims`
(C6) and `dev/prim-lint.sh` (new) exist.

### Files touched

New: `test/fixtures/c-json-roundtrip.tot`, `test/fixtures/c-procrun.tot`,
`test/fixtures/c-regex-benign.tot`, `test/fixtures/c-regex-pathological.tot`,
`dev/prim-lint.sh`.

Edited: `lib/prim.ml`, `lib/interp.ml`, `lib/check.ml`, `lib/global.ml`,
`lib/error.ml`, `lib/dune` (added `str`), `surface/token.ml`,
`surface/lexer.ml`, `surface/syntax.ml`, `surface/parser.ml`,
`surface/elab.ml`, `surface/bootstrap.ml`, `surface/effect.ml`,
`stdlib/prelude.tot`, `bin/tot.ml`, `test/main.ml`, `test/surface.ml`,
`dev/gates.sh`. `surface/run.ml` unmodified except threading `~partial`
through to `Check.define` and adding the field to its own provisional
self-entry record literal.

### Plan-detail fill-ins (recorded per the plan's own instruction)

- **The `let*` family shipped the PRE-APPROVED FALLBACK (C3's own
  "allowed and pre-approved" clause), not the bounded hole pass.** No
  `SHole`, no `Term.Hole`. `Syntax.SLetStar` carries the two explicit
  type-argument atoms the plan's `SHole`-based design would otherwise
  have synthesized: concrete grammar `let* A B x := e in body` /
  `let*! A B x := e in body`, where `A`/`B` parse the same way an
  ordinary application argument does (one `parse_atom` each; a compound
  type needs parens, e.g. `let* (Option String) Verdict x := ...`).
  `Elab.term`'s `SLetStar` arm desugars purely syntactically (no
  typechecking touched) to `bindIO A B e (fun x => body)` /
  `bindDiv A B e (fun x => body)`. test/main.ml's plan item 4 ("the hole
  pass resolves one hole...") is replaced by `case_json_positivity_kernel`
  (C4), a kernel-level counterpart to test/surface.ml's own positivity
  control test, pinning the SAME self-recursive-encoding invariant the
  hole pass would not have touched anyway. Rationale: implementing a
  bounded-but-real unification/occurrence-check pass inside `Check.check`
  is a materially bigger, higher-risk piece of work than the rest of
  Stage C combined (full prim catalog + self-recursive Json + procRun +
  regex + partial), and the plan explicitly pre-approved dropping it.
- **`surface/bootstrap.ml`'s two-phase seeding became THREE phases,
  interleaved with THREE prelude-fold segments, not two.** Discovered
  empirically: the prelude's new `jsonGet` (a `def`, in the Stage C DEF
  segment) calls `stringEq`, an EXISTING phase-2 prim, but phase-2
  historically ran only AFTER the ENTIRE prelude had folded once. `Bool`
  (which `stringEq`'s own type needs) is available much earlier, right
  after the prelude's ORIGINAL (M2-carried) content ending at `foldNat`;
  the NEW Stage C prims (`stringSlice` and its eleven siblings) need
  `Ordering`/`Json`/`ProcessResult`/etc, available only after the Stage C
  DATA segment ending at `Json`. Fix: `state ()` now splits
  `stdlib/prelude.tot`'s parsed item list at two NAMED markers
  (`split_after_name "foldNat"`, then `split_after_name "Json"`, robust
  to future line-editing, not a magic index) and interleaves: fold
  segment 1 -> phase2 (`stringEq` and its six siblings, unchanged) ->
  fold segment 2 (the four new data decls) -> phase3 (the twelve new
  prims) -> fold segment 3 (the seven new accessor defs) -> reset trace
  lines once -> `verify_required_ctors` (renamed out of the old phase2,
  since it now needs names from BOTH prelude segments). No stage's
  observable behavior changes for anything already bootstrapped before
  Stage C; `phase1`/`phase2`'s own prim tables and every existing
  `required_ctors` entry are untouched, only APPENDED to.
- **Consequence: `stdlib/prelude.tot` is no longer independently
  checkable via a bare, unbootstrapped `bin/tot.exe check/run`** (it now
  references `String`/`Int`/`Div`/`IO`/`stringEq`, none of which exist
  without `Bootstrap.phase1`/`phase2` having run), and it cannot be
  folded a SECOND time through `test/surface.exe`'s `gate-check`/
  `gate-run` either (`Bootstrap.state ()` already folds it once
  internally; a second fold is `Duplicate_global`, the exact failure
  shape Stage B's own log documents for a different reason). Fix: a new
  `test/surface.exe -- bootstrap-only` argv mode that just verifies
  `Bootstrap.state ()` succeeds; `dev/gates.sh`'s PRE-EXISTING
  `PASS-CHECK-PRELUDE`/`PASS-RUN-PRELUDE` markers now derive from that
  ONE exit code (the check-vs-run distinction collapses once "checking
  the prelude" and "bootstrapping" are the same operation). Both marker
  NAMES are unchanged for backward compatibility; only their
  implementation moved.
- **Regex needs a THIRD host-boundary exception fence beyond the plan's
  two named ones (Stage B's `Effect.dispatch`, Stage D's `Cache.load`).**
  Verified empirically (a throwaway `ocamlfind ocamlopt -package str`
  probe, not committed): `Str.regexp` raises `Failure` on a malformed
  pattern (e.g. `"a\\("`, `"["`), and `Str.search_forward`/
  `Str.matched_group` raise `Not_found` for "no match"/"group did not
  participate" — the library's OWN designed error-signaling mechanism,
  not a bug, and NOT optional to guard against since these are
  attacker-shaped patterns/text by construction (the whole reason these
  two prims are `Div`). `lib/interp.ml`'s `str_opt` is that one
  additional fence: `match f () with | exception (Failure _ | Not_found)
  -> None | v -> Some v`, reused at every `Str` call site, never a bare
  `with _` (Stack_overflow/Out_of_memory/Sys.Break still propagate).
  Documented at length in `str_opt`'s own doc comment.
- **`procRun`'s argument order is `procRun CMD ARGS`** (not documented
  by the plan's type alone); `argv`'s value is the raw, unfiltered
  `Sys.argv` (including the `tot` executable path and subcommand) —
  Stage D's own CLI-arg-plumbing story, if any, is out of this stage's
  scope. `stringSplit`'s argument order is `stringSplit STRING SEP`;
  `stringSlice`'s is `stringSlice STRING START LEN`; `regexTest`/
  `regexMatch`'s pattern comes first, text second.
- **`procRun`'s implementation is a documented, not engineered-around,
  known limitation**: stdout and stderr are drained SEQUENTIALLY via two
  pipes, so a child that fills its stderr buffer while this code is
  still blocked reading all of stdout could in principle deadlock; every
  fixture this stage ships only exercises `/bin/echo` (a small amount of
  stdout, nothing on stderr). A spawn failure (`Unix_error`/`Sys_error`
  from `Unix.create_process` or its pipe/waitpid plumbing) synthesizes a
  sentinel `mkProcessResult (-1) "" "tot: cannot exec CMD"` rather than
  crashing, inside `surface/effect.ml`'s `dispatch` (the already-named
  Stage B exception location, so no new fence is needed there).

### New `Error.t` variants

- `Partial_reducible_conflict of string` -- `reducible` together with
  `partial` on the same def.
- `Partial_not_div of string` -- a `partial` def whose codomain (after
  peeling its Pi telescope) is not `Div`-headed.

### Tests added

`test/main.ml` (kernel, 48 -> 52): `C1: Check.define ~partial:true
~reducible:true is Partial_reducible_conflict`, `C2: partial on a
non-Div-headed codomain is Partial_not_div`, `C3: def rec failing the
guard is Termination without partial, ACCEPTED with it` (also pins the
stored entry's `reducible = false`, `rec_arg = None`, `partial = true`),
`C4: Json-shaped self-recursive ctors pass positivity; List T -> T
nesting is Bad_ctor` (replaces the plan's hole-pass item 4, see above).

`test/surface.ml` (surface, 47 -> 53): `C5: JSON fixture round-trips`
(parse via `jsonParse`, project `name`/`count` by `jsonGetString`/
`jsonGet`+`jsonAsInt`, re-serialize with `jsonSerialize`, compare against
the exact source payload byte for byte), `C6: control test, List Json ->
Json nesting is still rejected by positivity` (`Kernel.Bad_ctor`), `C7a`/
`C7b`: `let*`/`let*!` desugar and check, `C7c`: `let*` over a `Div`
action without `liftIO` is `Kernel.Mismatch`, `C8`: `stringSplit`/
`stringSlice`/`stringToInt`/`intCompare` each compute one pinned value
under `tot run` (`((cons "a") ((cons "b") ((cons "c") nil)))`,
`(some "world")`, `(some 42)`, `lt`).

`dev/gates.sh`: `PASS-C-JSON`/`PASS-C-POSITIVITY` (derived from
`test/surface.exe`'s C5/C6 lines, `PASS-A-LITERALS` style), `PASS-C-PROC`
(procRun on `/bin/echo`, exit code 0 / stdout `tot-gate-c` / empty
stderr, all three pinned exactly), `PASS-C-REGEX-BENIGN` (a real
`\(a\)@\(b\)`-style match, all three captures pinned), `PASS-C-REGEX-
PATHOLOGICAL` (`\(a+\)+b` against 35 `a`s with no trailing `b`, under an
external `timeout`/`gtimeout` wrapper the same way F1's own CLI
regression already discovers one; empirically confirmed to exceed 5s —
exit 124 from the wrapper is an ACCEPTED outcome, not a failure),
`PASS-C-REGEX` (both above), `PASS-C-PARTIAL` (derived from
`test/main.exe`'s C1/C3 lines), `PASS-C-PRIMLINT` (`dev/prim-lint.sh`:
every `tot prims` line carries a non-empty justification, and the
catalog's size agrees with `phase1_prims @ phase2_prims @ phase3_prims`'s
length via a new `test/surface.exe -- prim-bootstrap-count` mode).

### Gate output tail

```
$ dune build --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dev/gates.sh | tail -22
PASS-A-LITERALS
PASS-CHECK-PRELUDE
PASS-RUN-PRELUDE
PASS-CHECK-CHURCH
PASS-RUN-CHURCH
PASS-CHECK-NAT
PASS-RUN-NAT
SCRIPTS-OK
PASS-B-EXITCODE
PASS-B-NOEFFECT
PASS-B-DEFERRED
PASS-C-JSON
PASS-C-POSITIVITY
PASS-C-PROC
PASS-C-REGEX-BENIGN
PASS-C-REGEX-PATHOLOGICAL
PASS-C-REGEX
PASS-C-PARTIAL
PASS-C-PRIMLINT
exit=0
```

Gate C (i)-(vi), all confirmed above: (i) `PASS-C-JSON`, a real payload
parses, projects two fields, re-serializes, and compares byte-for-byte
against the source; (ii) `PASS-C-POSITIVITY`, the `List Json -> Json`
control case is still `Bad_ctor` at both the kernel level (test/main.ml
C4) and the surface level (test/surface.ml C6); (iii) `PASS-C-PROC`,
`procRun` on `/bin/echo` populates all three `ProcessResult` fields,
pinned exactly; (iv) `PASS-C-REGEX`, a benign match's captures are
pinned exactly and a genuinely pathological pattern runs under an
external watchdog without asserting completion; (v) `PASS-C-PARTIAL`,
`partial` is admitted only with the keyword and only with a Div-headed
codomain, and `reducible partial` is `Partial_reducible_conflict`;
(vi) `PASS-C-PRIMLINT`, every one of the 29 catalog entries carries a
non-empty justification and the catalog's size agrees with what
bootstrap actually seeds.

Stage C green. Next: Stage D (prelude auto-load, shebang, cache, a real
guard).

## Stage D: prelude auto-load, shebang, cache, a real guard

Baseline before this stage's own verification pass (2026-09-01): the
working tree already carried a full Stage D implementation (`bin/tot.ml`,
`surface/cache.ml`, `surface/bootstrap.ml`'s D1/D2 additions,
`surface/run.ml`'s D4 epilogue, `surface/lexer.ml`'s D3 shebang strip,
`surface/effect.ml`'s `render_verdict`, `examples/guard.tot`,
`test/fixtures/{allow,deny,other,garbage}.json`, `test/surface.ml`'s D1a/
D1b/D2/D4a-D4e cases, and `dev/gates.sh`'s Gate D block), but
`dev/M3-BUILD-LOG.md` had no Stage D entry and the marshal-format
checklist comments the ground rules require were incomplete. This entry
is a from-scratch verification of that implementation against
`dev/M3-PLAN.md` (every D1-D7 subsection read and checked line by line
against the source), plus the fixes that verification turned up, plus
the closing report the ground rules require. Nothing from Stages A/B/C
was reverted; no `git add`, no `git commit`.

### What changed this pass

Verified against the plan and left as found (all correct, all four
gate-battery commands green before any edit):

- **D1, prelude auto-load** (`bin/tot.ml`): `check`/`run` call
  `Bootstrap.cached_state ()` and fold the target script against it;
  `--no-prelude` keeps `Run.initial` for kernel-shaped scripts that
  declare their own colliding names (`examples/nat.tot`'s own `data
  Nat`). `Bootstrap.default_prelude_path` locates the prelude two
  directories up from `Sys.executable_name` (`_build/default/bin/tot.exe`
  -> repo root -> `stdlib/prelude.tot`); `TOT_PRELUDE` overrides it.
  Resolution order is documented in `Bootstrap.prelude_path`'s own doc
  comment and now in `SPEC.md`.
- **D2, `surface/cache.ml`** (new): key is `Digest.string` (MD5, total,
  never raises) of the prelude source bytes concatenated with
  `format_version`; value is `Marshal.to_string (Global.t,
  Interp.globals)`. `load` reads the fixed-width header plainly with a
  length-checked `String.sub` before ever calling `Marshal.from_string`,
  and every failure path (missing file, `Sys_error` on open, a header
  mismatch, a `Failure` from a malformed `Marshal` body) degrades to
  `None`, never a crash: three separately guarded sites, matching the
  plan's "guard right where the exception happens" posture, not one
  blanket fence. `save` writes to a `.tmp<pid>` file and renames it into
  place (atomic publish), degrading to a silent no-op on any
  `Sys_error`. Location is `~/.cache/tot`, or `TOT_CACHE_DIR` when set (a
  fill-in for test isolation, exercised by Gate D (ii) below).
  `TOT_CACHE_VERIFY=1` recomputes `state ()` on a hit and prints
  `TOT-CACHE-VERIFY-OK` (or a mismatch line) to stderr, without ever
  substituting the recomputed value for the cached one.
- **D3, shebang** (`surface/lexer.ml`): `lex` strips exactly one leading
  line when the source starts with `#!` at column 0, line 1; `--` stays
  the only comment marker everywhere else; a bare `#` NOT in that exact
  position is left alone and lexes as an error (test D1b pins this).
- **D4, the `main` epilogue** (`surface/run.ml`, `surface/effect.ml`):
  `Run.script` tries `main : IO Verdict` first (against the existing
  conversion machinery), falling back to `IO Unit`. `render_verdict`
  (`surface/effect.ml`) renders `allow` as exit 0 with nothing printed,
  `ask`/`deny` as the one-line JSON envelope (via the shared
  `Pp.escape_string` from Stage A) with exit 1/2, and reuses the
  existing `Error.Mismatch` variant as its total backstop for a
  non-`Verdict` `VCon` (no new `Error.t` variant needed). An explicit
  `exitWith` inside an `IO Verdict` action reaches `run_io`'s `Exited`
  outcome first and short-circuits before `render_verdict` is ever
  called (test D4d). `IO Unit` mains are unaffected and keep Stage B's
  per-item echo plus `exitWith` behavior (test D4e).
- **D5, the ported guard** (`examples/guard.tot`, `chmod +x`): a real
  port of the user's own global "`rg` not grep, `sd` not sed" house
  rule, matching first-token, not substring (`ripgrep foo` is allowed).
  Reads `tool_name`/`tool_input.command` off a JSON stdin payload
  (`jsonGetString`/`jsonGet`/`jsonGetStringOr`) and fails OPEN (allow) on
  a missing field or a `jsonParse` decode failure, matching the live
  hooks' posture; the guard's own header comment says so. The C3 bounded
  hole pass did not ship (recorded in the Stage C log entry), so both
  `let*` steps in `main` name their two type arguments explicitly, the
  pre-approved fallback. Fixtures (`test/fixtures/{allow,deny,other,
  garbage}.json`) match the plan's four payloads exactly.
  `dev/gates.sh` installs a standalone `tot` copy into a scratch
  directory (first on `PATH`) and runs the guard through its OWN
  shebang, not `dune exec`, with `TOT_PRELUDE` set explicitly (a flat
  binary copy sits outside `default_prelude_path`'s relative-layout
  heuristic, a fill-in this pass confirms and the log records).
- **D6, `SPEC.md`**: the M3 decision-log block (fourteen verdict
  decisions, the three confirmed user decisions, the plan-level
  fill-ins) was already present in section 2. This pass added the
  missing pieces: marked the milestone line `M3 (done)` in section 5
  (it previously had no `(done)` marker, unlike M0/M1/M2), with its
  contents restated to match what actually shipped, and appended the
  "Known debts entering M4" block to section 6 (the six items carried
  from the design verdict's section 6, plus the three this plan adds:
  builtin-type-former error wording, `Str`'s process-global match state,
  and `tot check` still executing `Tot`-headed defs eagerly) — this
  block was entirely absent before this pass.
- **D7, `README.md`**: the `## Status` line still read `M2: ...`; bumped
  to `M3` with a one-paragraph restatement of the effect ladder, the
  literal/prim catalog, the prelude auto-load/cache, and the shebang
  guard. The `## Build and run` section's CLI examples and pinned
  `church.tot` output were re-checked against the live binary and left
  unchanged (still byte-identical; prelude auto-load does not alter
  `check`/`run` output shape for a script that declares no colliding
  names).
- **Marshal-format checklist** (ground rules, "Stage D depends on it"):
  found incomplete. `lib/prim.ml`'s `Prim.t` and `lib/interp.ml`'s
  `Interp.v` each carried a comment, but worded "bumps that cache's
  format version constant once it exists" — stale now that `surface/
  cache.ml` and `Cache.format_version` exist for real — and
  `lib/term.ml`'s `Term.t`, `lib/value.ml`'s `Value.t`, `lib/eterm.ml`'s
  `Eterm.t`, and `lib/global.ml`'s `Global.entry` carried no such
  comment at all. Fixed all six: each of the six types named in the
  ground rules now carries a comment, beside the type definition, naming
  `Cache.format_version` by name and explaining why a change there
  reaches the cache (added to `term.ml`, `value.ml`, `eterm.ml`,
  `global.ml`; reworded in `interp.ml`, `prim.ml`).

No new `lib/prim.ml` catalog entries in Stage D (the catalog is closed
as of Stage C, 29 entries; `dev/prim-lint.sh` still reports
`PASS-C-PRIMLINT`). No new `Error.t` variants (D4's `render_verdict`
reuses `Error.Mismatch`; D2's `Cache.load`/`save` return `option`/`unit`
directly, never `Error.t`, since a cache miss is not a script error).

### Files touched this pass

Edited (comment-only, no behavior change): `lib/term.ml`, `lib/value.ml`,
`lib/eterm.ml`, `lib/global.ml`, `lib/interp.ml`, `lib/prim.ml`,
`SPEC.md`, `README.md`.

Read and verified, unchanged: `bin/tot.ml`, `surface/cache.ml`,
`surface/bootstrap.ml`, `surface/run.ml`, `surface/effect.ml`,
`surface/lexer.ml`, `examples/guard.tot`, `test/fixtures/allow.json`,
`test/fixtures/deny.json`, `test/fixtures/other.json`,
`test/fixtures/garbage.json`, `test/surface.ml`, `dev/gates.sh`,
`lib/dune`, `surface/dune`, `bin/dune`.

### Tests added this pass

None (Stage D's own test bodies were already present and correct;
D1a/D1b/D2/D4a/D4b/D4c/D4d/D4e in `test/surface.ml` predate this pass).
This pass's own contribution is the six Marshal-format checklist
comments and the SPEC.md/README.md D6/D7 documentation gaps, verified by
re-running the FULL existing suite (kernel + surface + `dev/gates.sh`)
after each edit, never by adding new assertions.

### Gate output tail

```
$ dune build --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dune exec --root /Users/oobi/Documents/tot test/main.exe | tail -5
PASS C4: Json-shaped self-recursive ctors pass positivity; List T -> T nesting is Bad_ctor
M0 kernel: all tests green
(52 PASS lines total)

$ dune exec --root /Users/oobi/Documents/tot test/surface.exe | tail -8
PASS D4c: main : IO Verdict, allow prints nothing and exits 0
PASS D4d: an explicit exitWith inside an IO Verdict main short-circuits and wins over ever rendering a verdict
PASS D4e: main : IO Unit still runs when it does not convert to IO Verdict, and honors exitWith (the ordinary per-item echo is unaffected, unlike the Verdict path)
M1 surface: all tests green
(61 PASS lines total)

$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot | tail -3
def two : cnat
fun f => fun z => (f (f (f (f z))))

$ dev/gates.sh; echo "exit=$?"
... (136 PASS lines, 0 FAIL lines, full transcript in the gate run) ...
PASS-D-GUARD-ALLOW
PASS-D-GUARD-DENY
PASS-D-GUARD-OTHER
PASS-D-CACHE-HIT
PASS-D-CACHE-MISS
exit=0
```

Gate D (i)-(iv), all confirmed above: (i) the guard runs through its own
shebang after `chmod +x` against `allow.json` (exit 0, empty stdout,
`PASS-D-GUARD-ALLOW`), `deny.json` (exit 2, stdout exactly the one-line
envelope pinned verbatim in `dev/gates.sh`, `PASS-D-GUARD-DENY`), and
`other.json`/`garbage.json` together, both fail-open (exit 0, empty
stdout, `PASS-D-GUARD-OTHER`; the plan names no separate garbage marker,
so both fixtures are folded into this one check); (ii) the cache hits on
a second invocation with `TOT_CACHE_VERIFY=1` printing
`TOT-CACHE-VERIFY-OK` (`PASS-D-CACHE-HIT`) and degrades silently to a
miss (exit 0, empty stdout, no crash) on a 5-byte-truncated cache file
(`PASS-D-CACHE-MISS`); (iii) the summed M0 (52), M1 (61), and every
Gate A/B/C/D marker are green in one `dev/gates.sh` run, exit 0; (iv)
`SPEC.md` carries the M3 decision-log entries for items 1-14 plus the
three confirmed user decisions (section 2), and now also the milestone
`(done)` marker and the "Known debts entering M4" block (sections 5-6),
both added this pass.

Stage D green. All of Gates A, B, C, D pass in one `dev/gates.sh` run
(136 PASS, 0 FAIL, exit 0). M3 is complete: the effect ladder, literals,
stdlib breadth, and a real ported PreToolUse guard are all in the tree,
uncommitted, ready for the user's own commit.
