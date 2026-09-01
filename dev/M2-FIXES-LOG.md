# M2 fix batch: implementation log

SINGLE-AUTHORITY RULE (T1, Round 5 review; widened in the Round 5 doc
pass): this log accreted multiple "Final gate battery" sections across
stages and rounds, and more than one was worded as if it were THE
authoritative single-run count for the submitted tree. Only the LAST
"Final gate battery" section in the file is authoritative for gate
counts; every earlier one records a snapshot at the time its own
stage/round was submitted, superseded the moment a later section lands.
This rule is NOT limited to gate counts: it covers every semantic claim
in this log too (fix descriptions, test names, expected outputs). Where
a later round's section conflicts with an earlier one on what the code
actually does (for example "## Round 4"'s T0 reverting "## Round 3"'s S0
freeze back to eager unfolding), the LATER round is authoritative and
the earlier section is a historical snapshot only, annotated in place
with a `[SUPERSEDED by ...]` banner where practical. As of this edit the
last (and authoritative) one is "## Round 4"'s.

## Stage A: kernel fixes (F2, F3, F4, F5, F6, F7)

Status: GREEN. Full gate battery passes (build, kernel tests, surface
tests, church.tot run). Working tree left staged-for-review only; no
`git add`/`git commit` run.

### Files touched

- `lib/global.ml`: `Global.ind_entry.ctor_names` is now
  `string list option` (F2).
- `lib/error.ml`: two new `Error.t` variants, `Ind_redefined of string`
  and `Ind_incomplete of string`, with `to_string`/`tag` arms (F2).
- `lib/check.ml`:
  - `declare_ind` stores `ctor_names = None` (F2).
  - `define_ind` rejects a second call on an already-complete inductive
    with `Ind_redefined` (checked before touching any ctor), and wraps
    the final ctor-name list in `Some` (F2).
  - `match_scrut` unwraps `ind.Global.ctor_names` via
    `Option.to_result`, failing `Ind_incomplete iname` on `None` (F2).
  - `define`'s rec path: calls the new `Totality.mentions` first; only
    calls `Totality.guard` (and only then wraps the result `Some`) when
    the checked body actually mentions its own name; otherwise stores
    `rec_arg = None` directly (F3).
  - the check-position (motive-free) arm of `check` for `Term.Match`
    now materializes `motive = Some ("_", motive_t)` where `motive_t =
    Eval.quote globals (ctx.size + 1) expected_v`, instead of storing
    `motive = None` (F6).
- `lib/totality.ml`: new `mentions : string -> Term.t -> bool`, a small
  total structural walk over every `Term.t` arm (F3).
- `lib/eval.ml`:
  - `is_canonical` now takes `globals` and, for `VCtor (c, args)`, looks
    up the `Ctor`/`Ind` entries to compute the constructor's full arity
    (parameter count plus its own args-telescope length) and requires
    `List.length args` to equal it; a partial application is not
    canonical (F4). Its one call site in `apply`'s guarded-unfolding
    gate is updated to `is_canonical globals`.
  - `run_match`'s `VCtor` arm gained an arity backstop mirroring
    `Interp.run_match`'s existing one: compares `List.length own`
    against the matched branch's binder count and fails
    `Branch_mismatch` (`"<ctor> (wrong arity)"`) before evaluating the
    body (F5).
- `SPEC.md`: one new dated Section 2 block (2026-09-01, M2 fixes, Stage
  A) with five entries for F2/F3/F4/F5/F6/F7 (F5's fix folded into the
  same entry as F4 since both are the guarded-unfolding/arity story);
  Section 6's `rec_arg` first-fit debt line gets the no-occurrence
  clause. The match-in-infer-position motive debt line is unchanged,
  as instructed.
- `test/main.ml`: six new regression cases (see below), appended to the
  shared `cases` list; `build_globals` untouched.
- `test/surface.ml`: `expect_err_printed` helper (like `expect_err` but
  prints the caught error text on a pass) plus three new F3 cases.

### Deviation from the plan's exact wording (F4)

F4's text says the ctor's "KEPT arity" is "the count of non-erased,
quantity-omega entries in its args telescope; params never appear in
VCtor args." That parenthetical does not hold at the KERNEL value
level: `Value.VCtor`'s doc comment and `Eval.apply`/`run_match`
(`n_params` slicing) both show params ARE present in a kernel `VCtor`'s
args list, because the kernel evaluator does not erase — only the
later `Erase` pass (feeding `Interp`'s `VCon`, which genuinely carries
kept args only) does that. Filtering `is_canonical` to "just the
omega-count of `ctor.args`" while ignoring `n_params` would therefore
make `is_canonical` wrongly return `false` for a fully-applied
parameterized constructor (e.g. `Opt`/`Box`), which is worse than the
bug being fixed (over-conservative: blocks legitimate unfolding).
Implemented instead: full arity = `n_params + List.length
ctor.Global.args` (every entry of the ctor's own telescope, regardless
of quantity, since kernel `Value.t` never erases). For every ctor in
the current corpus (Nat, Opt, Box, Bool) the own-args telescope is
already all-omega, so this coincides with the plan's formula wherever
`n_params = 0`; it additionally gets the `n_params > 0` case right.
Noted here for the record per the plan's own transparency expectation;
happy to swap to the literal wording if that was intentional and I'm
missing context.

### New regression tests

`test/main.ml` (kernel level, hand-built `Term.t`, `Check`/`Eval`
called directly):

1. `F2: mid-declaration elimination is Ind_incomplete` — declares `Pin`
   (0 ctors yet), then `define_ind` with ctor `pa : Pin` followed by
   ctor `pb : (match pa as _ return Type 0 with end) -> Pin`. Rejected
   at `define_ind` time (never reaches eval) with `Ind_incomplete`.
   Printed on pass:
   `expected error (Ind_incomplete): cannot eliminate Pin: its
   constructors are declared but not yet defined`
2. `F2: second define_ind is Ind_redefined` — `declare_ind "Bit"`,
   `define_ind` once (ctor `bzero`), `define_ind` again (ctor `bone`).
   Second call rejected. Printed on pass:
   `expected error (Ind_redefined): inductive Bit already has its
   constructors defined`
3. `F4: partially applied ctor is not canonical` — `Eval.eval` (bypasses
   `Check`) on `add succ zero` where `succ` is the BARE, 0-of-1-arg
   constructor. Asserts the result stays `Value.VNeutral` (guarded rec
   `add` did not unfold).
4. `F4: fully applied ctor still unfolds` — same shape with `succ zero`
   (fully applied) in the principal position; asserts `Eval.conv`
   equality with `succ zero`, confirming the fix does not regress the
   always-worked case.
5. `F5: run_match arity backstop` — `Eval.eval` (bypasses `Check`) on a
   hand-built `Match` over `succ zero` whose `succ` branch declares 2
   binders (`n`, `extra`) against 1 kept arg. Rejected. Printed on pass:
   `expected error (arity backstop): match branches do not fit the
   declaration: expected succ, found succ (wrong arity)`
6. `F6: motive-free and explicit-motive matches convert equal` — builds
   `Bool`, then two reducible defs `not_a`/`not_b` with the SAME
   negation match, one via `Check.check` in check position
   (motive-free input), one with an explicit `as x return Bool`. Both
   applied to a shared opaque neutral `bo : Bool`; asserts
   `Eval.conv` judges the two resulting stuck applications equal.
   (Verified this test is fix-sensitive: reverting the F6 check.ml edit
   makes `not_a`'s stored motive stay `None` while `not_b`'s stays
   `Some`, so `conv_stuck_match`'s outer `Option.fold` short-circuits to
   `false` and the assertion fails — confirmed by tracing the code path,
   not by re-running against the old source.)

`test/surface.ml` (end to end through `Run.script`):

1. `F3: no-occurrence rec def unfolds like a plain reducible def
   (idty)` — `reducible def rec idty : (0 A : Type 0) -> Type 0 -> Type
   0 := fun A t => t` (no self-reference) followed by `def x : idty Nat
   Nat := zero`, in CHECK mode. Green: `idty` gets `rec_arg = None`
   (plain-def behavior) so it unfolds unconditionally in conversion,
   letting `idty Nat Nat` convert against `Nat`.
2. `F3: zero-formal rec def with no self-occurrence checks as a plain
   def` — `def rec x : Nat := zero`, CHECK mode. Green (previously a
   wrongly-worded `Termination` error, since `peel` would find 0
   formals and `first_fit` fails immediately at `k >= formals`).
3. `F3: genuinely non-structural rec is still rejected (Termination)` —
   `def rec bad : Nat -> Nat := fun n => bad n`. Rejected. Printed on
   pass:
   `expected error (Kernel.Termination): 2:1: recursive definition bad
   failed the structural termination guard`

### Gate battery (final run, all green)

```
$ dunecho build -- --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -5
  expected error (arity backstop): match branches do not fit the declaration: expected succ, found succ (wrong arity)
PASS F5: run_match arity backstop
PASS F6: motive-free and explicit-motive matches convert equal
M0 kernel: all tests green
(33/33 cases pass, including the 6 new Stage A cases) [R1: this count is
STALE against the submitted tree, off by one against Stage B's own
"unchanged from Stage A" 34/34 claim below; see the single-authority
rule at the top of this file and the LAST "Final gate battery" section
in this file for the one authoritative re-run]

$ dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -5
PASS F3: no-occurrence rec def unfolds like a plain reducible def (idty)
PASS F3: zero-formal rec def with no self-occurrence checks as a plain def
  expected error (Kernel.Termination): 2:1: recursive definition bad failed the structural termination guard
PASS F3: genuinely non-structural rec is still rejected (Termination)
M1 surface: all tests green
(32/32 cases pass, including the 3 new Stage A cases) [R1: STALE, see
the single-authority rule at the top of this file and the LAST "Final
gate battery" section in this file]

$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot 2>&1 | tail -3
def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
def two : cnat
fun f => fun z => (f (f (f (f z))))
```

Every negative test's actual error text was observed at least once
during this implementation (printed above and echoed in each test's own
Printf on a pass), confirming rejection for the intended reason rather
than a vacuous tag match.

Stage B (F1, runtime guarded neutrals) ships in this SAME batch; see the
"## Stage B" section directly below for its own fix, tests, and gate
report.

## Stage B: runtime guarded neutrals (F1)

Status: GREEN. Full gate battery passes (build, kernel tests, surface
tests, church.tot run). The divergence witness was run with a shell
timeout BEFORE the fix (timed out, confirming the bug) and AFTER the
fix (terminated cleanly, stable output on repeat runs). Working tree
left staged-for-review only; no `git add`/`git commit` run.

### The bug

The M2 debt note claiming Interp function readback is unreachable was
wrong: `eval add` on Peano `add` (bare, unapplied) diverges under
`tot run`. `Interp.define` cached every global's value EAGERLY
(`exec eglobals [] def`, always a `VClos` for a `def rec`'s erased
lambda), and `Interp.apply`'s `VClos` arm unfolded unconditionally on
every application, with no notion of a rec global's guard at runtime
(that discipline existed only in the kernel's `Eval`). `Interp.quote`
reaches under a `VClos`'s binders by applying it to fresh `VNeut`
variables to read back a function value. For `add`, peeling both
binders reaches `match m with ...` with `m` now a fresh neutral; the
scrutinee is neutral, so `run_match` freezes the match as an `FEMatch`
frame. `quote`'s own `FEMatch` handling then evaluates each frozen
branch body under one more layer of fresh neutral binders (to read
back the branch's own free variables) — and the `succ` branch's body
calls `add p n` where `p` is now itself a fresh neutral. Since `add`
still unfolded eagerly, this re-entered the same match on a
*new* neutral `m`, freezing one level deeper, forever: divergence, not
a real "unreachable" dead path.

### Fix

Gave the RUNTIME the kernel's guarded-unfolding discipline for rec
globals, mirroring `Eval` (`lib/eval.ml`) structurally in `Interp`
(`lib/interp.ml`):

- `Interp.globals` changed from `v Global.StringMap.t` to
  `gentry Global.StringMap.t`, where `gentry = { gval : v; grec_arg :
  int option; gctor_arity : int option }`. `gval` is the value
  `EGlobal` resolves to when the guard does not apply (a non-rec def's
  cached closure, a ctor's growing `VCon`, or `VErased`) and, for a rec
  def, also the closure `replay` unfolds onto once the guard is met.
  `grec_arg = Some k` marks a rec def guarded on argument `k`.
  `gctor_arity = Some n` marks a data constructor's KEPT (quantity-`w`)
  arity, the runtime analogue of F4's canonical check (erasure already
  dropped params and quantity-0 args before an `Eterm` exists, so the
  runtime arity target is the Many-only count, not the kernel's full
  unerased arity).
- `Interp.v` gained a head type mirroring the kernel's `Value.head`:
  `ehead = EHVar of int | EHGlobal of string`; `VNeut` is now
  `ehead * eframe list` instead of `int * eframe list`.
- `Interp.exec`'s `EGlobal` case: a non-rec global (`grec_arg = None`)
  still resolves to its cached `gval` directly (today's eager
  behavior, unchanged). A rec global resolves to a FRESH
  `VNeut (EHGlobal name, [])` instead of its cached closure — it starts
  neutral, exactly like the kernel's `Global` case for a rec def.
- `Interp.apply`'s new `VNeut (EHGlobal name, frames)` arm: extends the
  frame list, then looks up the global's `grec_arg`; if guarded and the
  leading application-frame argument at that position
  (`leading_fapp_args`, ported verbatim from `Eval`) is canonical
  (`is_canonical`, the KEPT-arity check above), it replays the
  accumulated frames (`replay`, ported verbatim from `Eval`) onto the
  cached `gval`; otherwise the application stays a frozen neutral.
  `VNeut (EHVar _, frames)` keeps today's plain frame-accumulation
  behavior (readback only, unaffected).
- `Interp.quote`'s `VNeut` arm now dispatches on the head: `EHVar lvl`
  keeps the existing de-Bruijn-level-to-index math; `EHGlobal name`
  renders as `Eterm.EGlobal name`, then both replay the same frame list
  (`FEApp`/`FEMatch`) as before. The two `VNeut (size, [])`
  fresh-binder construction sites (peeling a `VClos`, and seeding a
  frozen match branch's own binders) now build `VNeut (EHVar size, [])`.
- `Interp.define` gained a `~rec_arg:int option` parameter, stored into
  the new `gentry`. `Interp.add_ctor` gained an `~arity:int` parameter
  (the KEPT arity), stored into `gctor_arity`.
- `surface/run.ml` wiring: the `IDef` item already fetches `dentry`
  (the kernel's `Global.def_entry`, carrying `rec_arg`) right before
  calling `Interp.define`; that call now passes
  `~rec_arg:dentry.Global.rec_arg`. The `IData` item's ctor-seeding fold
  now looks up each constructor's kernel `Global.ctor_entry` (via
  `Global.find_ctor`, Result-threaded through the existing `kernel`
  helper, mirroring the identical lookup the same function already does
  a few lines later to print `ctor` lines) and counts its
  `Quantity.Many`-stamped `args` telescope entries to get the KEPT
  arity passed to `Interp.add_ctor`.
- No new `Error.t` variants: the guard is total (`Option.fold`, no
  error path), matching `Eval.is_canonical`'s own totality.

Closed, fully-canonical computations are unaffected: a terminating
call-by-value run only ever passes concrete constructor data in the
principal position, so the guard is always satisfied by the time a
recursive call's principal argument matters, and `replay` reduces to
the same sequence of `apply`/`run_match` steps as the old eager
unfolding. The neutral state is now transient (exists only between
"global looked up" and "guard satisfied") rather than absent, closing
exactly the divergence path above without changing any closed result.

### Divergence witness

`/Users/oobi/Documents/tot-f1-witness.tot`:

```
data Nat : Type 0 := | zero : Nat | succ : Nat -> Nat
reducible def rec add : Nat -> Nat -> Nat := fun m n => match m with | zero => n | succ p => succ (add p n) end
eval add
```

BEFORE the fix (`git stash`-equivalent state, i.e. the working tree as
Stage A left it):

```
$ timeout 10 dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot-f1-witness.tot
EXIT=124
```

Timed out (10s), confirming the divergence.

AFTER the fix, run twice to confirm stable output:

```
$ timeout 10 dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot-f1-witness.tot
data Nat : Type 0
ctor zero : Nat
ctor succ : (w _ : Nat) -> Nat
def add : (w _ : Nat) -> (w _ : Nat) -> Nat
add
EXIT=0
```

`add` (unapplied) reads back as the frozen global itself: `EGlobal
"add"` with zero frames, exactly the kernel's own behavior for a
looked-up-but-unapplied rec global (`Value.VNeutral (HGlobal "add",
[])`).

### Files touched

- `lib/interp.ml`: guarded-unfolding runtime as described above
  (`gentry`, `ehead`, `is_canonical`, `leading_fapp_args`, `replay`,
  updated `exec`/`apply`/`quote`/`define`/`add_ctor`/`add_erased`); top
  doc comment rewritten to describe the new discipline.
- `surface/run.ml`: `Interp.define` call passes `~rec_arg`; `IData`'s
  ctor-seeding fold passes each ctor's KEPT arity to `Interp.add_ctor`.
- `SPEC.md`: one new dated Section 2 entry (2026-09-01, M2 fixes, Stage
  B) describing the runtime guarded-unfolding rule; the Section 6
  interp-readback debt paragraph is replaced with a retirement note
  pointing back at the Section 2 entry.
- `test/surface.ml`: `add_def`/`add_line` constants (the Peano `add`
  script fragment and its printed `def` line, shared by both new
  cases) plus two new run-mode cases.

### New regression tests

`test/surface.ml` (end to end through `Run.script`, run mode):

1. `F1: bare eval of a rec global terminates, reading back as the
   frozen global` — Peano `Nat` + `def rec add`, then bare `eval add`
   (the witness script, inline). Green: prints `add`. Before the fix
   this input diverged (see witness run above); this test is the same
   shape run through the in-process test harness rather than the CLI
   with an external timeout, so a regression here hangs the test binary
   rather than failing cleanly — the external-timeout witness run above
   is the authoritative termination proof.
2. `F1: a rec global applied to canonical (closed) data still computes
   exactly as before the guard` — same `add`, `def two := succ (succ
   zero)`, `def three := succ two`, `eval add two three`. Green: prints
   `(succ (succ (succ (succ (succ zero)))))` (5 succs, 2 + 3), matching
   `examples/nat.tot`'s existing 1 + 2 = 3 case's shape and confirming
   guarded unfolding does not change a closed result.

### Gate battery (final run, all green)

```
$ dunecho build -- --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -6
PASS F4: partially applied ctor is not canonical
PASS F4: fully applied ctor still unfolds
  expected error (arity backstop): match branches do not fit the declaration: expected succ, found succ (wrong arity)
PASS F5: run_match arity backstop
PASS F6: motive-free and explicit-motive matches convert equal
M0 kernel: all tests green
(34/34 cases pass; unchanged from Stage A, Stage B touches no kernel
module) [R1: "unchanged from Stage A" does not square with Stage A's own
recorded 33/33 above (off by one); see the single-authority rule at the
top of this file and the LAST "Final gate battery" section in this file
for the one authoritative re-run]

$ dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -6
PASS F3: zero-formal rec def with no self-occurrence checks as a plain def
  expected error (Kernel.Termination): 2:1: recursive definition bad failed the structural termination guard
PASS F3: genuinely non-structural rec is still rejected (Termination)
PASS F1: bare eval of a rec global terminates, reading back as the frozen global (previously diverged: quote re-executed frozen match branches one binder deeper per level)
PASS F1: a rec global applied to canonical (closed) data still computes exactly as before the guard
M1 surface: all tests green
(35/35 cases pass, including the 2 new Stage B cases) [R1: arithmetic
does not check out against Stage A's own recorded 32/32 above (32 + 2 =
34, not 35); see the single-authority rule at the top of this file and
the LAST "Final gate battery" section in this file for the one
authoritative re-run]

$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot 2>&1 | tail -3
def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
def two : cnat
fun f => fun z => (f (f (f (f z))))
```

Divergence witness, before and after (see "Divergence witness" above
for the full transcript): before, `timeout 10 ... run
/Users/oobi/Documents/tot-f1-witness.tot` exits 124 (timed out); after,
it exits 0 and prints `add`, run twice with identical output both
times.

`examples/nat.tot` (`eval add two three`, 2 + 3) also re-verified by
hand outside the automated suite: prints `(succ (succ (succ (succ
(succ zero)))))`, matching the new surface test's independently-built
`two`/`three`.

## Round 2: post-review corrections (R0-R5)

Status: GREEN. Full gate battery passes on the final tree (build, kernel
tests, surface tests, church.tot run, `dev/gates.sh`). Working tree left
staged-for-review only; no `git add`/`git commit` run.

### R0 (HIGH, blocker): rec_arg unerased-vs-erased index mismatch

The bug: the kernel's `rec_arg` counts formals over the STAMPED,
UNERASED `Term.Lam` telescope (`Totality.peel` walks every `Lam`
regardless of quantity), but `Interp.apply`'s guard walks the ERASED
application spine (`Erase.term` drops every `Quantity.Zero` `Lam` binder
and `Quantity.Zero` `App` argument entirely). `surface/run.ml` passed
`dentry.Global.rec_arg` straight through to `Interp.define`. Any rec def
with an erased formal (a leading `(0 A : Type 0)`, the common
polymorphic shape) before its principal argument therefore indexed the
wrong position in the runtime spine, or an out-of-range one, and either
froze forever or (see below) got lucky.

Confirmed BEFORE the fix, `stdlib/prelude.tot`'s own `foldNat` (formals
`A`(0) `z`(w) `s`(w) `n`(w), `rec_arg = 3` over 4 unerased formals):

```
$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /path/to/foldNat-witness.tot
data Nat : Type 0
ctor zero : Nat
ctor succ : (w _ : Nat) -> Nat
def foldNat : (0 A : Type 0) -> (w _ : A) -> (w _ : (w _ : A) -> A) -> (w _ : Nat) -> A
def two : Nat
(((foldNat zero) succ) (succ (succ zero)))
```

Stuck neutral, exactly as the finding predicted, instead of
`(succ (succ zero))`. A second probe with `append` (`rec_arg = 1`, one
erased formal before it) happened to compute the RIGHT answer anyway,
because the wrong spine position it checked (`ys`, a bare `nil`) was
itself trivially canonical — a reminder that this class of bug is not
even reliably visibly wrong; `map` (`rec_arg = 3` over 4 unerased
formals, only 2 kept) is the cleaner discriminator: the buggy code reads
position 3 of a 2-element erased spine, `List.nth_opt` returns `None`,
and the global freezes unconditionally:

```
$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /path/to/map-witness.tot
...
((map succ) ((cons zero) ((cons (succ zero)) nil)))
```

Fix: `surface/run.ml` gains `lam_quantities` (peels a stamped def body's
`Lam` telescope, same walk shape as `Totality.peel`, keeping each
binder's quantity) and `remap_rec_arg` (counts the `Quantity.Many`
formals strictly before the kernel's `rec_arg` position in that list;
`None` if the guarded formal is itself `Quantity.Zero`, since a
type-level rec def's runtime applications are already fully erased and
eager unfolding is safe there; total via `Option.bind`/`Option.fold`, no
partial indexing). The `IDef` item's `Interp.define` call now passes
`~rec_arg:(remap_rec_arg dentry.Global.def dentry.Global.rec_arg)`
instead of the kernel value verbatim.

AFTER the fix, both witnesses compute correctly:

```
$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /path/to/foldNat-witness.tot
...
(succ (succ zero))

$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /path/to/map-witness.tot
...
((cons (succ zero)) ((cons (succ (succ zero))) nil))
```

Files touched: `surface/run.ml` (`lam_quantities`, `remap_rec_arg`, the
`Interp.define` call site); `SPEC.md` (one sentence appended to the
existing 2026-09-01 M2-fixes Stage B decision-log entry, recording the
remap rule); `test/surface.ml` (two new regression cases, below).

New regression tests (`test/surface.ml`, run mode, exact-output),
confirmed to FAIL before the `run.ml` fix (transcripts above) and PASS
after:

1. `R0: foldNat (leading erased formal before the principal argument)
   no longer freezes as a stuck neutral` — `data Nat` + the stdlib
   prelude's own `foldNat` def (verbatim) + `def two := succ (succ
   zero)` + `eval foldNat Nat zero succ two`. Green: prints
   `(succ (succ zero))`.
2. `R0: map (polymorphic prelude fn) over a closed two-element List Nat`
   — `data Nat` + `data List` + the stdlib prelude's own `map` def
   (verbatim) + a two-element `List Nat` + `eval map Nat Nat succ xs`.
   Green: prints `((cons (succ zero)) ((cons (succ (succ zero))) nil))`.

### R1 (MEDIUM): inconsistent gate counts

Stage A and Stage B recorded gate counts that do not square with each
other (Stage A: 33/33 kernel, 32/32 surface; Stage B: 34/34 kernel
"unchanged from Stage A" — a different number than Stage A's own 33 —
and 35/35 surface, where Stage A's 32 plus Stage B's stated 2 new cases
is 34, not 35). Rather than guess which historical number was the typo,
each stale count above is now annotated in place pointing at this
section, and this section carries the one authoritative re-run on the
FINAL tree (below), taken after every Round 2 edit, R0's two new cases
included. See "### Final gate battery" below for the real counts.

### R2 (MEDIUM): F1 divergence regression test could hang the suite

The only automated regression test for the F1 divergence bug ("F1: bare
eval of a rec global terminates...") called `Tot_surface.Run.script`
in-process with no bound on recursion: a REGRESSION of the guard would
hang that call forever, which hangs the whole `test/surface.exe`
process, not just fail one case. Picked the smaller clean change: run
the built `tot` CLI as a child process under an external `timeout`
rather than adding a fuel counter to `Interp.exec`'s recursion (fuel
would touch the production interpreter's hot path just to serve one
test). New helper `expect_cli_run_lines` in `test/surface.ml` runs
`timeout 10 _build/default/bin/tot.exe run <fixture>`, captures
stdout+stderr to a scratch file, and asserts exit 0 with the exact
expected line list; exit 124 (the `timeout` kill) is reported as an
ordinary `Error`, not a hang. The divergence-sensitive case ("F1: bare
eval...") now points at a new checked-in fixture,
`test/fixtures/f1-witness.tot` (the same Peano `Nat` + `def rec add` +
bare `eval add` script used for the original divergence witness).

Mutation-confirm (temporary, reverted immediately after): reverted
`Interp.exec`'s `EGlobal` case to always resolve to the cached closure
regardless of `grec_arg` (the pre-Stage-B behavior), reproducing the
original divergence, then ran the FULL surface suite under an outer
45s-generous wrapper to prove the mechanism actually turns a hang into
a clean fail rather than freezing the test binary:

```
$ timeout 40 dune exec --root /Users/oobi/Documents/tot test/surface.exe
...
FAIL F1: bare eval of a rec global terminates, reading back as the frozen global (previously diverged: quote re-executed frozen match branches one binder deeper per level)
  regression: /Users/oobi/Documents/tot/test/fixtures/f1-witness.tot hit the external 10s timeout (exit 124), got so far []
PASS F1: a rec global applied to canonical (closed) data still computes exactly as before the guard
PASS R0: foldNat (leading erased formal before the principal argument) no longer freezes as a stuck neutral
PASS R0: map (polymorphic prelude fn) over a closed two-element List Nat
1 test(s) failed
```

The test binary completed (every later case still ran and printed) and
exited nonzero instead of hanging; the divergence-sensitive case failed
for the intended reason (exit 124), not vacuously. `lib/interp.ml`
restored to its Stage B state immediately after; rebuilt and reran green
(see "### Final gate battery" below).

### R3 (LOW): F6 mutation-confirm by actual revert, not tracing only

The Stage A log claimed F6's regression test was fix-sensitive based on
code tracing, not an actual revert-and-rerun. Did the real mutation
confirm: reverted `lib/check.ml`'s check-position `Term.Match` arm to
store `motive = None` again (undoing the F6 constant-motive
materialization), ran `test/main.exe`, observed the failure, restored
the edit, reran green.

```
$ dune exec --root /Users/oobi/Documents/tot test/main.exe
...
FAIL F6: motive-free and explicit-motive matches convert equal
  uniform-motive: motive-free and explicit-motive stuck matches differ
1 test(s) failed
```

Restored `lib/check.ml`'s `motive_t` materialization immediately after;
rebuilt and reran green (see "### Final gate battery" below).

### R4 (LOW): Stage A's closing sentence contradicted Stage B

The Stage A section ended with "Stage B (F1...) is NOT included in this
batch; left for a follow-up pass", directly contradicted by the "##
Stage B" section immediately below it (which is present, GREEN, and
part of the same working tree). Fixed the sentence to state Stage B
ships in the same batch and points at its own section.

### R5 (nit): Stage A transcript pasted the blocked raw command

The Stage A gate transcript showed `$ dune build --root
/Users/oobi/Documents/tot` (the raw form a PreToolUse hook blocks) with
a parenthetical explaining `dunecho` was actually used. Replaced the
prompt line with the `dunecho build -- --root /Users/oobi/Documents/tot`
invocation actually executed and dropped the parenthetical, matching the
style Stage B's own transcript already used.

### Files touched (Round 2)

- `surface/run.ml`: R0, `lam_quantities`/`remap_rec_arg` + the
  `Interp.define` call site.
- `test/surface.ml`: R0 (two new cases, `list_data`/`list_lines`/
  `fold_nat_def`/`map_def` fixtures); R2 (`expect_cli_run_lines`,
  `tot_exe`, and the rewired "F1: bare eval..." case).
- `test/fixtures/f1-witness.tot`: new, R2's checked-in CLI fixture.
- `SPEC.md`: R0, one sentence appended to the Stage B decision-log
  entry.
- `dev/M2-FIXES-LOG.md`: R1 (stale-count annotations + this section),
  R4, R5.
- `lib/check.ml`, `lib/interp.ml`: touched ONLY for the R3/R2
  mutation-confirms, each reverted byte-for-byte immediately after (`git
  diff --stat` against the staged tree shows no residual change to
  either file).

### Final gate battery (single run, final tree, all green)

[SUPERSEDED by "## Round 3"'s own "Final gate battery" section below,
which is in turn superseded by "## Round 4"'s; see the single-authority
rule at the top of this file. Kept verbatim as a historical snapshot.]

```
$ dunecho build -- --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -6
PASS F4: partially applied ctor is not canonical
PASS F4: fully applied ctor still unfolds
  expected error (arity backstop): match branches do not fit the declaration: expected succ, found succ (wrong arity)
PASS F5: run_match arity backstop
PASS F6: motive-free and explicit-motive matches convert equal
M0 kernel: all tests green
(34/34 cases pass)

$ dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -8
PASS F1: bare eval of a rec global terminates, reading back as the frozen global (previously diverged: quote re-executed frozen match branches one binder deeper per level)
PASS F1: a rec global applied to canonical (closed) data still computes exactly as before the guard
PASS R0: foldNat (leading erased formal before the principal argument) no longer freezes as a stuck neutral
PASS R0: map (polymorphic prelude fn) over a closed two-element List Nat
M1 surface: all tests green
(37/37 cases pass, including R0's 2 new Round 2 cases)

$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot 2>&1 | tail -3
def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
def two : cnat
fun f => fun z => (f (f (f (f z))))

$ zsh /Users/oobi/Documents/tot/dev/gates.sh
BUILD-OK
TEST-OK
PASS-CHECK-PRELUDE
PASS-RUN-PRELUDE
PASS-CHECK-CHURCH
PASS-RUN-CHURCH
PASS-CHECK-NAT
PASS-RUN-NAT
SCRIPTS-OK
```

These were the real, single-run counts for the tree submitted at the end
of Round 2: kernel 34/34, surface 37/37. SUPERSEDED (see banner above):
Round 3 added one kernel case (S3) without touching this section, so
"the real, single-run counts for the submitted tree" was never true of
Round 2's own numbers past that point; Round 3's final battery below is
the count that actually matches ITS submitted tree, and Round 4's below
that is the one that matches the CURRENT tree.

## Round 3: post-review corrections (S0-S3)

Status: GREEN. Full gate battery passes on the final tree (build, kernel
tests, surface tests, church.tot run, `dev/gates.sh`). Working tree left
staged-for-review only; no `git add`/`git commit` run.

### S0 (medium, semantic blocker): re-armed divergence on an erased
guarded formal

[SUPERSEDED by "## Round 4" (T0): the freeze was reverted to eager
unfolding, proven safe by the erasure argument. Kept verbatim below as a
historical snapshot of the Round 3 reasoning; see the single-authority
rule at the top of this file, now widened to cover semantic sections
such as this one, not just gate counts.]

The bug: `surface/run.ml`'s `remap_rec_arg` returned `None` (the
"non-recursive, unfold eagerly" signal `Interp.define` uses) whenever
the kernel-chosen guarded formal's quantity was `Quantity.Zero`. That
silently downgrades a def the KERNEL marked `rec` (guarded, must stay
frozen until its principal argument is canonical) to a plain def at
runtime, re-arming the class of bug Stage B's F1 fix closed (kernel and
runtime disagreeing about whether a def is allowed to unfold).

The fix (`surface/run.ml`, `remap_rec_arg`): when the guarded formal is
itself erased, the runtime application spine (post-`Erase.term`) never
carries that argument at all, so there is no principal position left to
test. FREEZE, never eager-unfold: remap to `Some (count of ALL
Quantity.Many formals in the telescope)`, an index one PAST the end of
the runtime spine. `Interp.apply`'s guard does
`List.nth_opt (leading_fapp_args oldest) k`, so an out-of-range `k`
always misses, `guarded` always folds to `false`, and the def stays a
frozen neutral (`VNeut (EHGlobal name, frames)`) forever, no matter how
many arguments arrive. Remapping to the first KEPT formal instead (the
other tempting fix) would be UNSOUND: unfolding gated on a position that
does not itself structurally decrease can diverge on its own. One-line
comment added at the site stating this intent.

`SPEC.md`: the Stage B decision-log entry (Section 2, 2026-09-01, "R0"
sub-entry) previously closed with "its runtime applications are already
erased, so eager unfolding is safe there" - that sentence was WRONG
(exactly the bug this fix closes). Replaced with the freeze rule and an
explicit note that eager unfolding there was not safe.

REGRESSION TEST SHAPE CHOSEN: surface (test/surface.ml, run mode), NOT
kernel-level. A def rec whose kernel `rec_arg` lands on an erased formal
IS expressible in surface syntax, via one indirection: matching an
erased variable directly at the top-level (Many) mode is rejected with
`Erased_use` (confirmed: a direct `def rec ghost : (0 j : Nat) -> Nat ->
Nat := fun j n => match j with ... end` was REJECTED with
`Kernel.Erased_use` when tried by hand during construction, as expected
- this is the "matching an erased formal at runtime mode is rejected"
the plan warned about, and is NOT the shape that ships). The shape that
DOES check: give the def a helper (`dropErased : (0 j : Nat) -> Nat ->
Nat := fun j n => n`) whose OWN first parameter is also quantity-0, and
pass the `match j with ...` expression as THAT parameter's argument.
Checking an argument against a Pi of quantity 0 multiplies the checking
mode by zero (`Quantity.mul mode Quantity.Zero = Quantity.Zero`)
REGARDLESS of the outer mode, so the nested match - and everything
inside it, including the recursive call `ghost jp n` in its `succ`
branch - is checked at Quantity.Zero, where matching an erased variable
is legal. `Totality.guard`'s first-fit then picks candidate k=0 (`j`)
immediately, since every occurrence of the recursive call satisfies its
`guarded_call` check (`jp` is `Smaller`, tracked from matching the
`Principal` `j`). This gives a real, surface-syntax-expressible def
whose kernel `rec_arg = Some 0` lands on an erased formal - exactly
S0's target shape. Fixture: `test/fixtures/s0-erased-guard.tot`
(new); test case: "S0: def rec guarded on an erased formal freezes
(never eagerly unfolds) both bare and applied" in `test/surface.ml`,
using the same `expect_cli_run_lines` CLI-plus-watchdog helper F1's
bare-eval case uses (S1/S2-hardened this round, see below), checking
BOTH `eval ghost` (bare) and `eval ghost zero (succ zero)` (applied) in
one script. Both print frozen readbacks (`ghost` and `(ghost (succ
zero))` respectively - the erased `zero` argument for `j` does not
appear, since erasure drops it from the runtime spine) and terminate.

[Round 4 (T0) NOTE: the test name and the two expected outputs named in
the paragraph just above are STALE and no longer exist in the shipped
tree. "## Round 4" renamed the case to "T0: rec def guarded on an erased
formal eagerly unfolds to the correct value, both bare and applied" and
rewrote its expected outputs to the eager-unfolded values `fun n => n`
(bare) and `(succ zero)` (applied); `ghost` and `(ghost (succ zero))` as
frozen readbacks are gone. See "## Round 4"'s own "New regression tests"
and `test/surface.ml` for the current test.]

One honest note on the "divergence" framing: by hand-tracing
`Totality.passes` and confirming with `Erase.term`'s source
(`Term.App (Quantity.Zero, f, _a) -> term ctx f` - the erased argument
is dropped WHOLESALE, never even walked), it follows that ANY recursive
occurrence that satisfies `guarded_call` for an erased candidate `k`
must itself live entirely inside a Quantity.Zero-checked position (the
same mode-propagation chain that made matching `j` legal), and is
therefore ALWAYS erased away before `Interp` ever sees it. So for
`ghost` specifically, the OLD buggy behavior (eager unfold) does not
actually loop forever; it computes a wrong-but-terminating answer.
Mutation-confirmed directly: reverted `remap_rec_arg`'s erased-formal
arm to the old `None`, rebuilt, and reran both evals by hand
(`dune exec ... bin/tot.exe -- run ...` under an external `timeout`) -
bare `eval ghost` printed `fun n => n` (wrongly unfolded to the
identity function) and applied `eval ghost zero (succ zero)` printed
`(succ zero)` (wrongly computed), both terminating but WRONG; restored
the fix, rebuilt, reran - both went back to the frozen readbacks above.
This is still the right regression shape per the plan's own acceptance
test ("must terminate and print frozen readbacks"), and still catches
the real defect (kernel/runtime guardedness disagreement), even though
a genuine infinite loop was not reachable for this particular witness.

### S1 (medium, vacuous-gate hazard): hardcoded stale CLI binary + fixture path

The bug: `test/surface.ml`'s `expect_cli_run_lines` (the F1 CLI
regression helper) shelled out to a hardcoded
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe`, which dune's
build graph had no path back to from `test/surface.exe` (the two
executables share no library), so nothing forced a rebuild before the
test ran a possibly-stale binary; the fixture path was also a
machine-absolute literal.

The fix:
- `test/dune`: added a `(rule (targets tot_exe_dep.ml) (deps
  ../bin/tot.exe) (action (write-file ...)))` that generates an inert
  module depending on `../bin/tot.exe`. `test/surface.ml` references
  `Tot_exe_dep.tot_built` (a dune build-time tripwire), which forces
  dune to LINK that module into `surface.exe`, which forces the rule to
  run first, which forces `../bin/tot.exe` to be rebuilt first. This was
  the dune-idiomatic mechanism that actually bites (see the dependency
  verification note below for why the more obvious `(deps ...)` field on
  the `tests` stanza does NOT).
- `test/surface.ml`: both the exe path and the fixture path are now
  resolved from `Sys.executable_name` (this test binary's own resolved
  absolute path, e.g. `<root>/_build/default/test/surface.exe`), which
  is always correct regardless of invocation cwd. `build_default =
  Filename.dirname (Filename.dirname Sys.executable_name)` gives
  `<root>/_build/default`; `tot_exe = build_default/bin/tot.exe`;
  `repo_root = Filename.dirname (Filename.dirname build_default)`
  strips `_build/default` back off, and `f1_witness_fixture` /
  `s0_erased_guard_fixture` are both `repo_root/test/fixtures/*.tot` (the
  SOURCE tree, not `_build`). No hardcoded absolute path remains in
  either file.

DEPENDENCY VERIFICATION (the "does it actually bite" check the plan
asked for): the naive approach - a bare `(deps ../bin/tot.exe)` field on
the `tests` stanza - was tried FIRST and found NOT to work: added the
field, edited `lib/interp.ml`, ran ONLY `dune exec --root ...
test/surface.exe` (the exact gate command, no separate `dune build`
step), and `bin/tot.exe`'s mtime did not change. That field only feeds
dune's generated `runtest`-alias action, not a `dune exec`/`dune build`
of the exe target itself. Reverted, switched to the generated-module
tripwire above, and re-verified FUNCTIONALLY (more convincing than
mtime, which turned out to have its own timing/shared-cache quirks
under raw `dune build` args unrelated to this fix): temporarily changed
`lib/interp.ml`'s `quote`'s `EHGlobal` readback to print
`"STALE_" ^ name`, ran ONLY `dune exec --root ... test/surface.exe`
(clean-built baseline first, no intervening build step after the
edit), and the F1 CLI test correctly FAILED with `STALE_add` in its
`got` output - proving `bin/tot.exe` WAS rebuilt with the regression as
a direct, unassisted consequence of running the surface suite. Reverted
the marker, rebuilt, reran green (see final gate battery below).

### S2 (medium, portability): GNU `timeout` dependency

The bug: `expect_cli_run_lines` invoked the watchdog as a hardcoded
`timeout`, GNU coreutils' name; stock macOS ships no such binary (only
BSD tools), so the helper would either fail with "command not found" or
(worse) silently run unguarded if `timeout` happened to resolve to
something else on `$PATH`.

The fix (`test/surface.ml`): a `watchdog : string option` probe, `match
() with | () when has "timeout" -> ... | () when has "gtimeout" -> ...
| () -> None`, where `has cmd` runs `command -v cmd` via `Sys.command`
(never raises, so the probe stays total and exception-free per the
finding's requirement). `expect_cli_run_lines` folds on `watchdog`:
`None` now FAILS the test loudly with a message naming both tool names
and a `brew install coreutils` hint, rather than hanging or spuriously
exiting 127. This machine has both `timeout` and `gtimeout` on `$PATH`
(Homebrew coreutils installed both prefixed and unprefixed), so
`"timeout"` is what actually gets used here; the `gtimeout` fallback
path was exercised by temporarily shadowing `command -v timeout` to
fail during development and confirming the helper picked `gtimeout`
instead.

### S3 (low, error precedence): match_scrut check ordering

The bug: `lib/check.ml`'s `match_scrut` unwrapped `ind.Global.ctor_names`
(the F2 `Ind_incomplete` check) BEFORE the pre-existing params-length
check, so a wrong-param-count scrutinee on a still-declaring inductive
reported `Ind_incomplete` instead of the more fundamental
`Not_inductive` (a malformed scrutinee is not a well-formed value of
the type it claims to be at all, independent of whether that
inductive's constructors happen to be defined yet).

The fix (`lib/check.ml`, `match_scrut`): reordered so the params-length
`if not (Int.equal ...) then Error Not_inductive else ...` check runs
FIRST (same `if`/`else` shape the code already used for this check
before F2 existed - no Option/Result match introduced), with the
`Ind_incomplete` unwrap only reached once params line up.

Test (`test/main.ml`, `case_match_scrut_precedence`, kernel level): a
1-param inductive `Pin3` declared but left undefined (`ctor_names =
None`), plus a `Global.add`-built opaque `bad_scrut : Pin3` (bypassing
`Check.define` on purpose, mirroring the F5 backstop style - evaluating
a bare `Term.Global` whose entry is `Global.Ind` always yields
`Value.VInd (name, [])` regardless of the inductive's declared param
count, per `Eval.eval`'s `Global.Ind` arm, so this gives a scrutinee
whose `p_vals` length (0) disagrees with `Pin3`'s declared params
length (1)). `Check.infer` on `match bad_scrut with end` now reports
`Not_inductive`, not `Ind_incomplete`. Mutation-confirmed: reverted the
reorder, rebuilt, reran - the test failed with the expected/got mismatch
(`wrong error: cannot eliminate Pin3: its constructors are declared but
not yet defined`, i.e. `Ind_incomplete`); restored the fix, rebuilt,
reran green.

### Files touched (Round 3)

- `surface/run.ml`: S0, `remap_rec_arg`'s doc comment and its
  `Quantity.Zero` arm.
- `SPEC.md`: S0, corrected the Stage B / R0 decision-log sentence.
- `lib/check.ml`: S3, reordered `match_scrut`'s two checks.
- `test/dune`: S1, new `(rule ...)` generating `tot_exe_dep.ml`.
- `test/surface.ml`: S0 (fixture binding + new case), S1
  (`Sys.executable_name`-relative `tot_exe`/`repo_root`/fixture paths,
  `Tot_exe_dep.tot_built` reference), S2 (`watchdog` probe + the
  `expect_cli_run_lines` rewrite to fold on it).
- `test/main.ml`: S3, new `case_match_scrut_precedence` case.
- `test/fixtures/s0-erased-guard.tot`: new, S0's CLI fixture.
- `lib/interp.ml`: touched ONLY for the S1 mutation-confirm (the
  `"STALE_" ^ name` marker in `quote`'s `EHGlobal` arm), reverted
  byte-for-byte immediately after (`git diff --stat` against the staged
  tree shows no residual change).

### Final gate battery (single run, final tree, all green)

[SUPERSEDED by "## Round 4"'s own "Final gate battery" section; see the
single-authority rule at the top of this file. Kept verbatim as a
historical snapshot: this WAS the authoritative section for the tree as
Round 3 submitted it.]

```
$ dunecho build -- --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -6
PASS F4: partially applied ctor is not canonical
PASS F4: fully applied ctor still unfolds
  expected error (arity backstop): match branches do not fit the declaration: expected succ, found succ (wrong arity)
PASS F5: run_match arity backstop
PASS F6: motive-free and explicit-motive matches convert equal
M0 kernel: all tests green
(35/35 cases pass: 34 from Round 2 + 1 new, S3; 0 FAIL lines)

$ dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -6
PASS F1: bare eval of a rec global terminates, reading back as the frozen global (previously diverged: quote re-executed frozen match branches one binder deeper per level)
PASS F1: a rec global applied to canonical (closed) data still computes exactly as before the guard
PASS R0: foldNat (leading erased formal before the principal argument) no longer freezes as a stuck neutral
PASS R0: map (polymorphic prelude fn) over a closed two-element List Nat
PASS S0: def rec guarded on an erased formal freezes (never eagerly unfolds) both bare and applied
M1 surface: all tests green
(38/38 cases pass: 37 from Round 2 + 1 new, S0; 0 FAIL lines)

$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot 2>&1 | tail -3
def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
def two : cnat
fun f => fun z => (f (f (f (f z))))

$ zsh /Users/oobi/Documents/tot/dev/gates.sh
BUILD-OK
TEST-OK
PASS-CHECK-PRELUDE
PASS-RUN-PRELUDE
PASS-CHECK-CHURCH
PASS-RUN-CHURCH
PASS-CHECK-NAT
PASS-RUN-NAT
SCRIPTS-OK
```

These were the real, single-run counts for the tree submitted at the end
of Round 3: kernel 35/35, surface 38/38. SUPERSEDED (see banner above):
Round 4 (T0) reverted the S0 fix's freeze back to eager unfolding, added
one new kernel case, and rewrote the S0 surface case's expected output
in place (same case count, new expectations); its own "Final gate
battery" below is the one that matches the CURRENT tree.

## Round 4: post-review corrections (T0-T2, Round 5 review)

Status: GREEN. Full gate battery passes on the final tree (build, kernel
tests, surface tests, church.tot run, `dev/gates.sh`). Working tree left
staged-for-review only; no `git add`/`git commit` run.

### T0 (medium, semantic): revert the erased-guard freeze to eager unfold

The bug: Round 3's S0 fix made `surface/run.ml`'s `remap_rec_arg` FREEZE
a rec def forever whenever its kernel `rec_arg` landed on a
`Quantity.Zero` (erased) formal, on the claim that eager unfolding there
would re-arm Stage B's readback divergence. Round 5 review found that
claim unfounded: no divergence witness existed for the erased-guard
shape (the S0 mutation-confirm's own transcript shows both evals
TERMINATING with the freeze reverted, just with the "wrong" answer it
never actually re-derived from first principles), and re-verification
killed a fresh over-application variant of the same claim.

MECHANICAL VERIFICATION FIRST (the plan's own gate before shipping
eager unfold): a new kernel test, test/main.ml's "T0: rec def guarded on
an erased formal has no self-reference after erasure", hand-builds the
`dropErased`/`ghost` pair from test/fixtures/s0-erased-guard.tot as
`Term.t`, runs them through `Check.define` (rec path included) to get
the checker-stamped `ghost` body, erases it with `Erase.closed`, and
walks the resulting `Eterm.t` with a new total, exhaustive
`eterm_mentions : string -> Eterm.t -> bool` (one arm per `Eterm.t`
constructor, no catch-all) looking for `EGlobal "ghost"`. Result:
**no occurrence** (`eterm_mentions "ghost" erased = false`; printed on
pass: `erased ghost body: fun n => (dropErased n)`). VERDICT:
no-self-reference CONFIRMED. Per the plan's own stop condition this
green result is what authorizes shipping eager unfold below; had it come
back `true` this section would instead report RED with the offending
`Eterm.t` printed, and the freeze would stay.

THE ARGUMENT (why this is general, not an accident of this one witness):
`ghost`'s guarded formal is `j` (quantity 0). A quantity-0 binder can
only be USED (including as a match scrutinee) while checking at
`Quantity.Zero` mode: `Check.infer`'s `Var` arm only permits using a
0-bound variable when `Quantity.equal mode Quantity.Zero`, otherwise
`Erased_use`. So the `match j with ...` that gives `ghost`'s recursive
call its structurally-smaller argument is itself only well-typed at mode
`Zero`, which means every branch body of that match - including the
`succ` branch's `ghost jp n` - is ALSO checked at mode `Zero`
(`check_branches` threads the same `mode` through). Downstream, wherever
that quantity-0 match term is consumed, it is consumed as a quantity-0
argument or binder (attenuation is transitive: nothing turns a `Zero`
subterm into a `Many` one without re-crossing a `Pi`'s own quantity, and
here it is consumed directly as `dropErased`'s own quantity-0 first
argument). `Erase.term`'s `App (Quantity.Zero, f, _a) -> term ctx f` arm
drops such an argument WHOLESALE, `_a` unused, never walked - so nothing
inside it, including the self-reference, is ever emitted into the
`Eterm`. This generalizes past `ghost`'s specific shape: any `def rec`
whose kernel guard lands on an erased formal has this property, because
`Totality.guard`'s `passes` only accepts candidate `k` when EVERY
occurrence of the recursive call has argument `k` at `Smaller` status,
and `Smaller` status is only produced by matching on the `Principal`
formal (or something already `Smaller`) - the same erased-scrutinee
match that forces the whole enclosing subterm to quantity 0.

THE FIX (`surface/run.ml`, `remap_rec_arg`): the `Quantity.Zero` arm now
returns `None` (eager unfold, the def is treated as non-recursive at
runtime) instead of an out-of-range index. Doc comment rewritten to
carry the argument above and point at the new test. `many_count` (only
consumer was the old freeze arm) removed as dead code.

REGRESSION TEST: test/surface.ml's S0 case (renamed "T0: rec def guarded
on an erased formal eagerly unfolds to the correct value, both bare and
applied") keeps the exact same `expect_cli_run_lines` CLI-plus-watchdog
harness - a future regression that reintroduces a real self-reference
through this path still fails red (10s watchdog timeout), not hangs.
Only the expected output lines change, to the COMPUTED values: bare
`eval ghost` now prints `fun n => n` (peeling `ghost`'s one kept binder
during readback and eagerly unfolding both `ghost` and `dropErased`,
whose erased bodies both reduce to the identity on their one kept
argument, collapses straight through to that argument); applied
`eval ghost zero (succ zero)` now prints `(succ zero)` (the actual
computed result: `dropErased`'s branches on `j = zero` return `zero`,
`dropErased` ignores its own erased argument and returns its `n`
unchanged, so `ghost zero (succ zero) = (succ zero)`). Both are exactly
the "wrong, non-frozen answer" the Round 3 log's own mutation-confirm
observed and mislabeled as wrong - they are the definitionally correct
values.

STDLIB SWEEP (T0's last requirement): every `def rec` in
`stdlib/prelude.tot` was checked to confirm none lands the kernel guard
on an erased formal (temporary instrumentation, `surface/run.ml`'s
`IDef` arm, printed each def's kernel `rec_arg` index and the formal's
quantity via `Printf.eprintf`; ran `tot check stdlib/prelude.tot`
once; reverted byte-for-byte immediately after, `git diff --stat`
against the staged tree shows no residual change to `surface/run.ml`
beyond the T0 fix itself). Result, all five `def rec`s land on a KEPT
(quantity `w`) formal:

```
REC_ARG_SWEEP add: k=0 q=w
REC_ARG_SWEEP mul: k=0 q=w
REC_ARG_SWEEP append: k=1 q=w
REC_ARG_SWEEP map: k=3 q=w
REC_ARG_SWEEP foldNat: k=3 q=w
```

`add`/`mul` guard on their first (only structurally-matched) `Nat`
formal; `append`/`map`/`foldNat` all skip their leading erased type
parameter(s) - `Totality.guard`'s first-fit rejects a formal whose
self-call argument is the SAME variable passed through unchanged (never
derived from a match), which is exactly what a type parameter or an
unmatched function argument looks like - and land on the `List`/`Nat`
formal actually matched on. None falls in the erased-guard class; the
stdlib was never exposed to Round 3's freeze bug in the first place.

`SPEC.md`: the Stage B decision-log entry's Round 3/S0 sentence (Section
2, dated block) is replaced with the eager rule and the erasure argument
above as its proof, dated "M2 fixes Round 4, revising Round 3's S0",
with a note that Round 3's freeze text is superseded and why.

### T1 (low): single-authority rule for this log's gate-battery counts

The bug: this log accreted a "Final gate battery" section per stage/
round (Stage A, Stage B, Round 2, Round 3), and both Round 2's and Round
3's were worded as "the real, single-run counts for the submitted tree"
- true only at the moment each was written, false the instant a later
section landed, with no annotation saying so. Separately, three earlier
`[R1: ...]` inline markers (Stage A's kernel and surface counts, Stage
B's kernel count) pointed at `"## Round 2"` specifically, which was
itself about to go stale the same way.

The fix: a single-authority statement added right after this file's
title (see the top): only the LAST "Final gate battery" section in the
file is authoritative. Round 2's and Round 3's own "Final gate battery"
sections each got a `[SUPERSEDED by ...]` banner immediately under their
heading, plus a rewritten closing sentence explaining what superseded
them and why ("the real, single-run counts" language removed - replaced
with "were... at the end of Round N"). The three `[R1: ...]` markers now
point at "the single-authority rule at the top of this file and its LAST
'Final gate battery' section" instead of a specific, eventually-stale
round name.

### T2 (low, debt only): is_canonical's redundant Global lookup

`lib/eval.ml`'s `is_canonical` (the guarded-unfolding canonicity check,
called on every application of a rec global) does `Global.find_ctor`
then a SECOND lookup, `Global.find_ind`, to get the constructor's owning
inductive's param count. Not restructured now, per the plan's own scope
line (`Global` stays as-is this round): recorded as a debt in SPEC.md
Section 6, with the suggested cleanup (fold `n_params` into
`Global.ctor_entry` at `define_ind` time, a ctor-entry arity cache) noted
for M3 or later. No code change in `lib/eval.ml`.

### Files touched (Round 4)

- `surface/run.ml`: T0, `remap_rec_arg`'s doc comment and its
  `Quantity.Zero` arm (`Some many_count` -> `None`); `many_count` removed
  as dead code. Temporarily instrumented and reverted for the stdlib
  sweep (see above).
- `SPEC.md`: T0, the Stage B / Round 3 S0 decision-log sentence rewritten
  with the eager rule and erasure argument; T2, one new Section 6 debt
  line.
- `dev/M2-FIXES-LOG.md`: T1 (single-authority statement, superseded
  banners on Round 2's and Round 3's final-battery sections, repointed
  `[R1: ...]` markers), this section.
- `test/main.ml`: T0, new `drop_erased_ty`/`drop_erased_def`/`ghost_ty`/
  `ghost_def` (hand-built mirrors of the s0 fixture), `eterm_mentions`,
  and `case_erased_guard_no_self_ref`, appended to the shared `cases`
  list.
- `test/surface.ml`: T0, the S0 case's comment and expected-output lines
  rewritten in place (same fixture, same harness, new computed
  expectations); the fixture-binding comment above it updated to note
  the branch is eager-unfold as of this round.

### New regression tests

`test/main.ml` (kernel level):

1. `T0: rec def guarded on an erased formal has no self-reference after
   erasure` - see MECHANICAL VERIFICATION above. Printed on pass:
   `erased ghost body: fun n => (dropErased n)`.

`test/surface.ml` (end to end through the CLI, run mode, unchanged
watchdog harness):

1. `T0: rec def guarded on an erased formal eagerly unfolds to the
   correct value, both bare and applied` (formerly S0) - same fixture,
   new expected output: `fun n => n` (bare), `(succ zero)` (applied).

### Final gate battery (single run, final tree, all green)

```
$ dunecho build -- --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -6
  expected error (arity backstop): match branches do not fit the declaration: expected succ, found succ (wrong arity)
PASS F5: run_match arity backstop
PASS F6: motive-free and explicit-motive matches convert equal
  erased ghost body: fun n => (dropErased n)
PASS T0: rec def guarded on an erased formal has no self-reference after erasure
M0 kernel: all tests green
(36/36 cases pass: 35 from Round 3 + 1 new, T0)

$ dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -8
  expected error (Kernel.Termination): 2:1: recursive definition bad failed the structural termination guard
PASS F3: genuinely non-structural rec is still rejected (Termination)
PASS F1: bare eval of a rec global terminates, reading back as the frozen global (previously diverged: quote re-executed frozen match branches one binder deeper per level)
PASS F1: a rec global applied to canonical (closed) data still computes exactly as before the guard
PASS R0: foldNat (leading erased formal before the principal argument) no longer freezes as a stuck neutral
PASS R0: map (polymorphic prelude fn) over a closed two-element List Nat
PASS T0: rec def guarded on an erased formal eagerly unfolds to the correct value, both bare and applied
M1 surface: all tests green
(38/38 cases pass: same 38 cases as Round 3, T0/S0's expectations rewritten in place)

$ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot 2>&1 | tail -3
def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
def two : cnat
fun f => fun z => (f (f (f (f z))))

$ zsh /Users/oobi/Documents/tot/dev/gates.sh
BUILD-OK
TEST-OK
PASS-CHECK-PRELUDE
PASS-RUN-PRELUDE
PASS-CHECK-CHURCH
PASS-RUN-CHURCH
PASS-CHECK-NAT
PASS-RUN-NAT
SCRIPTS-OK
```

These are the real, single-run counts for the submitted tree: kernel
36/36, surface 38/38. `dev/gates.sh` exits 0 (`BUILD-OK`/`TEST-OK`/
`SCRIPTS-OK` all present). Status: GREEN. This is the LAST "Final gate
battery" section in this file as of this edit; per the single-authority
rule at the top, it is the one to trust.

## Round 5 (doc hygiene): five documentation-only edits, no code change

Status: GREEN. Doc-only pass over `dev/M2-FIXES-LOG.md`,
`dev/M2-FIXES-PLAN.md`, and `test/surface.ml` comments; zero lines of
executable OCaml changed. Working tree left staged-for-review only; no
`git add`/`git commit` run.

1. `dev/M2-FIXES-LOG.md`, "## Round 3"'s S0 section: added a
   `[SUPERSEDED by "## Round 4" (T0): ...]` banner directly under the S0
   heading, and a `[Round 4 (T0) NOTE: ...]` annotation on the paragraph
   naming the now-nonexistent `ghost` / `(ghost (succ zero))` frozen-
   readback test name and outputs.
2. `dev/M2-FIXES-PLAN.md`, F4: rewrote the "params never appear in VCtor
   args" / "quantity-omega entries only" paragraph to match the shipped
   `lib/eval.ml` `is_canonical` (full arity = `n_params + List.length
   ctor.Global.args`; kernel `Value.t` is unerased, so params come first
   in a `VCtor`'s args list).
3. `dev/M2-FIXES-LOG.md`: reworded all four `[R1: ...]` markers to point
   at "the LAST 'Final gate battery' section in this file" with no
   hardcoded round name, and widened the top-of-file single-authority
   rule to cover semantic sections (later rounds supersede earlier ones
   on conflict), not just gate counts.
4. `test/surface.ml`: moved the "M2-fixes batch (Round 2), R2: ..." doc
   comment from about 60 lines above `expect_cli_run_lines` to directly
   above its definition. Comment relocation only, no wording change.
5. `test/surface.ml`, `expect_cli_run_lines`: added one comment line
   noting the accepted temp-file leak on the error path (if reading
   `out_path` raises, the `Sys.remove` call right below it is skipped).
   No restructuring.

### Verification (counts unchanged)

```
$ dunecho build -- --root /Users/oobi/Documents/tot
OK build: 0 errors, 0 warnings

$ dune exec --root /Users/oobi/Documents/tot test/main.exe
exit 0, 36 PASS lines, "M0 kernel: all tests green" (36/36, unchanged
from "## Round 4")

$ dune exec --root /Users/oobi/Documents/tot test/surface.exe
exit 0, 38 PASS lines, "M1 surface: all tests green" (38/38, unchanged
from "## Round 4")
```

No code behavior changed this round; the counts match "## Round 4"'s own
"Final gate battery" section exactly, as expected for a comments and
markdown only pass. That section remains the LAST "Final gate battery"
section in this file and stays authoritative per the single-authority
rule at the top; this Round 5 section is deliberately NOT titled "Final
gate battery" so it does not compete with that pointer.
