# M2 fix batch: post-review corrections

Authoritative spec for the M2-fix implementation agents. Read this WHOLE
file before touching code. The repo is /Users/oobi/Documents/tot (OCaml,
dune). M2 is committed (3807637); the working tree is clean. Findings
come from the post-commit review (ctxcat + deep logic pass, 2026-09-01).

## 0. Ground rules (house style, enforced by hooks)

- NO exceptions anywhere: no raise/failwith/assert. Every failure is a
  Result value.
- NO match on Option/Result where a combinator does the job
  (Option.fold/map/to_result, Result.bind, let*). A PreToolUse hook
  DENIES edits that add such matches.
- NO loop keywords (for/while); recursion + List.fold/map/filteri only.
- Exhaustive matches, NO catch-all `_ ->` arms on variant types you can
  enumerate. Use `match () with | () when ...` ladders, not if/else-if.
- Comments: match existing density; doc comments on new top-level items.
- No em-dashes in any text you write. In prose, write "locate", never
  the f-word verb that a hook pattern-matches.
- Shell: `rg` not grep, `sd` not sed. Append a trailing ` # [skip-disk]`
  comment to EVERY Bash command (disk-floor interlock bypass; bare, it
  gets zsh-globbed).
- Never `cd`: use `dune build --root /Users/oobi/Documents/tot`,
  `git -C ...`, absolute paths. Your cwd RESETS between Bash calls.
- Do NOT run `git add` or `git commit`. Leave working-tree edits only.

Gate command battery (all must be green before you report):

    dune build --root /Users/oobi/Documents/tot 2>&1 | tail -20 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -5 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -5 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot 2>&1 | tail -3 # [skip-disk]

Append a short stage report (what changed, gate output tails) to
/Users/oobi/Documents/tot/dev/M2-FIXES-LOG.md when your stage is green.

Every fix ships WITH its regression test, and every negative test must
be shown to REJECT for the intended reason (print the error), not to
pass vacuously.

## STAGE A: kernel fixes (F2..F6)

### F2 (medium x2, one joint fix): provisional inductive window

`Global.Ind.ctor_names : string list` becomes `string list option`.
Semantics: `None` means declared but not yet defined; `Some names` means
complete.

- `Check.declare_ind` stores `None` (today: `[]`).
- `Check.define_ind` REQUIRES the current entry to hold `None`; if it is
  already `Some _`, fail with a new `Error.t` variant (follow error.ml
  house shape, e.g. `Ind_redefined of string`). On success write
  `Some names` with exactly this call's ctor names.
- `match_scrut` (and any other reader that walks ctor_names, locate them
  all with rg) REQUIRES `Some`; on `None` fail with a new variant, e.g.
  `Ind_incomplete of string` ("cannot eliminate an inductive whose
  constructors are not yet defined"). Use Option combinators, not match.
- `Pp` renders both new error variants.

Why: today the inductive is live with an empty ctor list while its own
constructor types are checked, so `match x with end` on it is vacuously
exhaustive and a CHECKED program reaches eval's "unreachable on checked
terms" Branch_mismatch backstop. Separately, a second `define_ind` call
silently overwrites ctor_names and breaks canonicity through the kernel
API.

Tests (test/main.ml):
1. Constructor type that eliminates its own inductive mid-declaration is
   REJECTED: build via declare_ind + define_ind a type T with ctor `a :
   T` and ctor `b : (match-on-a-with-zero-branches) -> T`; expect the
   Ind_incomplete error, and print it.
2. Second define_ind on the same inductive name errors (Ind_redefined).
3. Existing prelude/church/nat paths stay green (covered by gates).

### F3 (medium): vacuous first-fit rec_arg

If a `def rec` body contains NO occurrence of its own name, `define`
must store `rec_arg = None` and skip the totality guard entirely; the
definition behaves exactly like a plain def (unfolds in conversion when
reducible, no guarded-unfolding gate). Add the occurrence walk in
lib/totality.ml (a small total recursive `mentions : string -> Term.t ->
bool`, structural over Term.t, exhaustive arms).

Why: today first-fit is vacuously satisfied at k = 0 when there is no
recursive spine, so `reducible def rec idty : (0 A : Type 0) -> Type 0
-> Type 0 := fun A t => t` gets rec_arg = Some 0 and NEVER unfolds
(argument 0 is a type, never a canonical ctor), producing spurious
Mismatch on `def x : idty Nat Nat := zero`. The same change makes a
zero-formal `def rec x : Nat := zero` acceptable as a plain def
(previously a wrongly-worded Termination error).

Tests:
1. surface (test/surface.ml): the idty script above followed by
   `def x : idty Nat Nat := zero` CHECKS green.
2. surface: `def rec x : Nat := zero` (no self-occurrence, no formals)
   now checks green.
3. surface: a genuinely non-structural rec, e.g.
   `def rec bad : Nat -> Nat := fun n => bad n`, is STILL rejected with
   Termination; print the error.

### F4 (low): is_canonical must mean fully applied

In lib/eval.ml, the guarded-unfolding gate currently treats any
`VCtor (c, _)` as canonical. Strengthen: look up the `Ctor` entry for c
in globals and require `List.length args` to equal the ctor's FULL arity
at the kernel value level: `n_params + List.length ctor.Global.args`
(the inductive's own parameter count plus every entry of the
constructor's own args telescope, regardless of quantity). Kernel
`Value.t` is UNERASED, so a kernel `VCtor`'s args list carries the
inductive's params FIRST, then the constructor's own args telescope in
order; only the later `Erase` pass drops erased entries, for `Interp`'s
already-kept-only `VCon`. A partially applied ctor (by this full-arity
count) is NOT canonical. Keep the function total: an unknown ctor name
is simply not canonical (Option.fold, no error path needed at this
site).

Test (test/main.ml): hand-build globals where a rec def's principal
argument receives a partially applied `succ` (a VCtor with 0 of 1 kept
args) and assert the global does NOT unfold (conversion leaves it
neutral); with a fully applied `succ zero` it DOES unfold.

### F5 (low): run_match arity backstop in eval.ml

lib/eval.ml run_match feeds `own` (kept ctor args) into the branch body
with no arity check; lib/interp.ml's counterpart guards this loudly.
Add the same backstop: compare `List.length own` against the branch's
binder-list length and fail with `Error.Branch_mismatch` on mismatch
before evaluating the body.

Test: exercised by F2 test 1's pre-fix path; after F2 the window is
closed, so add a direct unit test in test/main.ml that calls Eval.eval
on a hand-built Match whose branch binder count disagrees with the ctor
value's kept args and expects Branch_mismatch (bypass Check on purpose;
this is a backstop test).

### F6 (low): uniform motive representation in checker output

Check-position matches without `as/return` currently store `motive =
None` while explicit-motive matches store `Some`, and FMatch frame
conversion compares the option, so two identically-reducing stuck
matches fail conversion purely by spelling. Fix by MATERIALIZING the
constant motive in checker output: in the check-position no-motive path,
store `Some (binder, motive_term)` where motive_term is the quote of the
expected type value, weakened so it is well-scoped under the one extra
scrutinee binder (derive the exact de Bruijn shift from the existing
infer-position instantiation discipline; the requirement is behavioral,
test 1 below pins it). Infer position and explicit `as/return` are
unchanged. Erasure and run_match already ignore motives; confirm and
leave them structural.

Tests (test/main.ml):
1. Build the same Bool-negation match twice via Check.check against
   expected `Bool -> Bool`: once motive-free (check position), once with
   an explicit constant motive `as x return Bool`. Apply both (as
   reducible defs) to a shared OPAQUE neutral `bo : Bool`; assert
   Eval.conv judges the two stuck applications EQUAL.
2. A motive-free match still checks and runs as before (covered by
   existing tests plus gates).

### F7 (doc only): parameter universe levels

SPEC.md updates, no code:
- Section 2, dated 2026-09-01 (M2 fixes): inductive parameters may live
  at ANY universe; the declared level bounds constructor ARGUMENTS only.
  This follows the Coq/Lean precedent (parameters are not fields).
- Section 6 debt/pin: VInd conversion compares parameters pointwise
  (definitional, standard NbE). M4 must NOT generate propositional
  injectivity for type formers; with large parameters over small
  targets, that would be a paradox source. Record it now so the M4
  design inherits the constraint.

Also add Section 2 entries (same dated block) for F2, F3, F4, F6
semantics, and delete/adjust any Section 6 debt line these fixes retire
(the match-in-infer motive debt line stays; the first-fit line gets the
no-occurrence clause).

## STAGE B: runtime guarded neutrals (F1, high)

The M2 debt note claiming Interp function readback is unreachable is
WRONG: `eval add` on Peano add diverges under `tot run`. Interp.quote's
FEMatch arm executes frozen branch bodies under fresh VNeut binders, the
branch body applies the rec global (a plain VClos that unfolds eagerly),
the match re-freezes one binder deeper, and quote recurses forever.

Fix: give the RUNTIME the kernel's guarded-unfolding discipline for rec
globals.

- Thread rec-arg knowledge into Interp's global table: whatever shape
  surface/run.ml uses to register globals with Interp gains the def's
  `rec_arg : int option` (locate the wiring and extend it; keep the
  change minimal).
- Interp values gain a neutral-GLOBAL head alongside the existing level
  head (mirror the kernel's HGlobal): applying a rec global whose
  principal argument (position rec_arg, counting the leading application
  spine exactly as lib/eval.ml does) is not a canonical ctor value must
  FREEZE as a neutral application instead of entering the closure.
  Canonical here means fully applied ctor, same rule as F4.
- quote renders the new neutral head as the global's name applied to its
  quoted frames (match interp.ml's existing frame-quoting style).
- Non-rec globals (rec_arg = None) keep today's behavior: unfold at
  application time, always. Closed first-order programs are unaffected:
  a terminating call-by-value run only ever passes canonical data in the
  principal position.

SPEC.md: replace the Section 6 interp-readback debt paragraph with the
new runtime rule, and add the Section 2 dated entry (runtime guarded
unfolding for rec globals; readback of rec function values is now total
and prints frozen applications).

Tests (test/surface.ml, run mode):
1. Peano Nat + `def rec add` (the witness), then `eval add`: `tot run`
   must TERMINATE and print a stable readback. Wrap the run in a timeout
   at the test level if the harness has one; otherwise rely on
   termination (the fix makes it total).
2. `eval add two three` (or church.tot equivalent) still prints the
   expected numeral, proving closed applications are unchanged.
3. Kernel tests (test/main.ml) from Stage A all stay green.

## Reporting

Each stage: append to dev/M2-FIXES-LOG.md a report with the fix list,
files touched, new Error variants, test names added, and the four gate
tails. Return (StructuredOutput) status green only when the ENTIRE gate
battery passes.
