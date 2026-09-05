# M7 build log

## Stage A (2026-09-04): argument-driven holes, the infer-path settle, conservativity

Plan: `dev/M7-PLAN.md`, section "STAGE A", parts A1-A6.  Verdict pins 1,
2, 3 and 4, plus the Ratification amendment of 2026-09-04 (Q1, the
infer-path settle).  This entry covers PART 1 only: the elaborator.
Part 2 owns `test/surface.ml`, `dev/gates.sh`, `dev/m7a/*.tot`,
`test/fixtures/m6c-hole-run.tot` and `dev/m5e-default-transcript.txt`.

Rollback ruling (user, 2026-09-04): part A3b stays in Stage A.  No
rollback step of PLAN:2473-2500 was taken.  A3b reaches its target
shape;  the proof is probe A3b-1 below.

### 1. Entry state

- `git -C /Users/oobi/Documents/tot log -1 --oneline` = `12d6bae M7 plan
  amendment: infer-path settle in Stage A, strict single-traversal Stage
  C`, which is doc-only over `66b444f`, so every `file:line` the plan
  cites resolves unchanged.
- `git status --porcelain` at entry listed 2 lines, `dev/M6-PLAN.md` and
  `dev/M7-PLAN.md`.  Another agent owns both.  Part 1 never touched
  them.
- Entry battery (runner `/Users/oobi/Documents/tot-m7-probes/stageA/battery.sh`,
  log `/Users/oobi/Documents/tot-m7-stageA-entry-gate.log`, gate slice
  `...entry-gate.log.gate`): `BUILD-EXIT=0`, `GATE-EXIT=0`, `PASS=371`,
  `FAIL=0`.  The battery ran twice.  The first run read `PASS=375` and
  `FAIL=` (empty), which is conflict note C-A1, not a repo defect.  The
  second run, with the counting repaired, read 371 and 0.
- Entry residue, re-derived from the entry gate slice, with the command
  beside each number (graft G8):
  - `rg -c '^PASS-' ...entry-gate.log.gate` = `147` marker lines.
  - `rg -c '^PASS ' ...entry-gate.log.gate` = `224` suite cases.
  - `/Users/oobi/Documents/tot/_build/default/test/main.exe | rg -c '^PASS'` = `105`.
  - `/Users/oobi/Documents/tot/_build/default/test/surface.exe | rg -c '^PASS'` = `119`.
  - 105 + 119 = 224, and 224 + 147 = 371.  The residue is CLOSED: the
    plan's third term is 146 `echo PASS-` SITES but the gate prints 147
    marker LINES.  The extra line is `PASS-C-PRIMLINT`, which comes from
    a site the literal `echo PASS-` does not match.  Read conflict note
    C-A2.
- `PASS-M7A-INFER-SETTLE-BUDGET` at HEAD, before the first edit, by the
  marker block's own command (runner
  `/Users/oobi/Documents/tot-m7-probes/stageA/measure.sh`):

      files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2

  This is the literal the plan pins at PLAN:2344.
- Frozen `lib/` set md5, same runner:

      cat lib/totality.ml lib/term.ml lib/eval.ml lib/value.ml \
          lib/erase.ml lib/interp.ml lib/error.ml | md5 -q
      f446f043e1ad6c7b85ddedb7736bd8a1

  This is the literal the plan pins at PLAN:1191.  It is unchanged at
  exit, because the one `lib/` edit of Stage A is in `lib/check.ml`,
  which is not in the frozen set.

### 2. What changed

`git status --porcelain` at exit, part 1 only:

    M dev/M6-PLAN.md      (another agent)
    M dev/M7-PLAN.md      (another agent)
    M lib/check.ml
    M surface/elab.ml

`git diff --stat` for the two files part 1 owns: `lib/check.ml` 12 lines
touched, `surface/elab.ml` 553 lines touched.  `surface/elab.ml` grows
from 536 lines to 981.

#### A1.  Typed locals

`term` (elab.ml:517), `term_at` (elab.ml:700) and `spine` (elab.ml:797)
each gain `?(locals : Term.t option list = [])`, threaded beside
`scope`.  The default keeps `surface/run.ml` unchanged: no external call
site names the new argument.  `local_ty` is at elab.ml:308.

Binder arms that push a type: `term`'s SPi arm pushes the elaborated
domain, `term`'s SLet arm and `term_at`'s SLet arm push `ty_t`,
`term_at`'s SLam arm pushes the expected Pi domain, and both match arms
push the constructor field types of A2.  Every other arm that adds a
name to `scope` pushes `None`, so the two lists stay aligned by
construction.  `local_ty` shifts what it reads;  read conflict note
C-A4.

Probe A1-1, the alignment oracle, is probe A4-1 below: the slot in
`myEqL _ f t1 t2` fills from the branch binder `t1`, which is only
reachable when `locals` is aligned AND shifted.  Before the C-A4 fix the
same probe reported

    p-a4-prelude159.tot:1:1: type mismatch: expected Type 0, found #7

which is the misaligned read arriving as a kernel error, never as a
silent accept.

#### A2.  The total type synthesizer

`synth` is at elab.ml:397, over `spine_head` (elab.ml:313),
`inst_applied` (elab.ml:380) and `has_auto` (elab.ml:323).  It answers
for a local `Term.Var` and for a spine headed by a global, and `None`
everywhere else.  `inst_applied` reuses `peel_domains` and
`inst_domain`, so Stage A adds no new de Bruijn arithmetic;  read
conflict note C-A7.  Head-normal form is `rigid_or_whnf`
(elab.ml:417), which retries the match once on
`Eval.quote globals 0 (Eval.eval globals [] ity)` and only for a closed
`ity` (`is_closed`, elab.ml:371).

#### A3.  The argument-driven capture pass in `spine`

`arg_caps` is at elab.ml:964.  The activation guard
`holed_leading_slot_unsettled` (elab.ml:291) sits in `spine` right after
the expected-type `caps`, so the pass runs only where the settle fold
reports `Serror.Hole` today.  `settles_all` (elab.ml:298) stops the walk
at the first fit.  The declared domain is shifted by `m - i` before the
match, as PLAN:1370-1380 requires.

Probe A3-1, the check-position oracle, `test/fixtures/m6c-hole-a.tot`,
which binds `readStdin : IO String` in a `let*` A slot:

    HEAD:  test/fixtures/m6c-hole-a.tot:2:8: hole: expected Type 0   exit=1
    now:   def main : (IO Verdict)                                   exit=0

Probe A3-2, `test/fixtures/m6c-hole-run.tot`, the second file A7
licenses to move:

    HEAD:  test/fixtures/m6c-hole-run.tot:1:28: hole: expected Type 0  exit=1
    now:   def main : (IO Unit)                                        exit=0

Both files are outside the `PASS-M7A-INFER-SETTLE-BUDGET` digest by A7,
and both are the resolutions the plan predicts at PLAN:1511-1518.

#### A3b.  The infer-path settle

`term`'s SApp arm (elab.ml:534) now uncurries and calls `spine_infer`
(elab.ml:880), with `app_infer` (elab.ml:946) as the fallback.
`app_infer` is HEAD's own two lines, so the fallback builds the same
`Term.App (Quantity.Many, f_t, a_t)` node elab.ml:270 built.  Read
conflict note C-A3 for the two places where `spine_infer` is stricter
than the plan sketch.

Probe A3b-1, the pin 5 anchor 3 shape, which is `stdlib/prelude.tot:173`
as Stage D will re-spell it.  Sources
`/Users/oobi/Documents/tot-m7-probes/stageA/p-a3b-prelude173.tot` and
`p-a3b-prelude173-explicit.tot`:

    holed:     def myEqList : (0 A : Type 0) -> (w _ : (EqD A)) -> (EqD (List A))   exit=0
    explicit:  def myEqList : (0 A : Type 0) -> (w _ : (EqD A)) -> (EqD (List A))   exit=0

The two lines are byte-identical, and the explicit line is the literal
the plan pins at PLAN:2332.  The holed source is
`fun A d => mkEqD (List A) (listEqBy _ (eqf A d))`.  The head `mkEqD` is
fenced, so its argument descends through `term`, which is infer
position, which is why only A3b closes this anchor.  This is the answer
to the rollback ruling: A3b reaches its target and stays.

Probe A3b-2, a plain infer settle,
`p-infer-settle.tot` = `eval (pureIO _ allow)` against
`p-infer-explicit.tot` = `eval (pureIO Verdict allow)`:

    holed:     eval : (IO Verdict)   exit=0
    explicit:  eval : (IO Verdict)   exit=0

Probe A3b-3, the three pin 2 negatives, which must keep their exact HEAD
line:

    eval _                   1:6:  hole: no expected type at this position  exit=1
    eval (liftIO _ _)        1:14: hole: no expected type at this position  exit=1
    eval (mkEqD _ boolEq)    1:13: hole: no expected type at this position  exit=1

All three read as PLAN:1477-1478 records them at HEAD.
`test/fixtures/m6c-hole-n-infer.tot`, the one corpus file inside the
budget digest that reports this message, also keeps its line:

    test/fixtures/m6c-hole-n-infer.tot:1:6: hole: no expected type at this position  exit=1

Probe A3b-4, the fence is not vacuous.  `eval (mkEqD _ boolEq)` refuses,
while the explicit twin `eval (mkEqD Bool boolEq)` prints
`eval : (EqD Bool)` with exit 0.  The slot IS determined by first-order
matching, so the fence, not a missing capture, is what refuses it.

#### A4.  Constant-motive branch descent

`branch_body_has_hole` is at elab.ml:434 and `branch_expected` is at
elab.ml:502.  `term`'s SMatch branch fold descends with `term_at` only
when BOTH preconditions hold: the motive body mentions neither its `as`
binder nor an index binder (`min_free_var`, elab.ml:347), and the branch
body holds a `Syntax.SHole`.  A hole-free body keeps `term`, keeps
HEAD's node, and pays no constructor lookup.

Probe A4-1, the `stdlib/prelude.tot` `listEqBy` shape, two nested
constant-motive matches.  Sources `p-a4-prelude159.tot` and
`p-a4-prelude159-explicit.tot`, the spine `myEqL _ f t1 t2` against
`myEqL A f t1 t2`:

    holed:     def myEqL : (0 A : Type 0) -> (w _ : (w _ : A) -> (w _ : A) -> Bool) -> (w _ : (List A)) -> (w _ : (List A)) -> Bool   exit=0
    explicit:  def myEqL : (0 A : Type 0) -> (w _ : (w _ : A) -> (w _ : A) -> Bool) -> (w _ : (List A)) -> (w _ : (List A)) -> Bool   exit=0

The two lines are byte-identical.  The slot fills from the branch binder
`t1`, which sits two constant-motive matches deep.

Probe A4-2, the conservativity half.  `stdlib/prelude.tot` is green at
HEAD, has the constant-motive shape at its `listEqBy` body, and stays
green with byte-identical output: it is one of the 61 green records of
the budget digest, whose md5 did not move.

#### A5.  The check-position `Term.App` arm in the kernel

`lib/check.ml:1208` now carries a named `Term.App (_, _, _)` arm whose
body is `check_via_infer globals ctx mode tm expected_v`, the body of
the catch-all it left.  The catch-all keeps its remaining six
constructors, `Term.Var`, `Term.Univ`, `Term.Pi`, `Term.Ann`,
`Term.Global` and `Term.Lit`, and has no wildcard arm.  `define`'s
signature and `type rule = Structural` are untouched, and the frozen md5
above proves `lib/totality.ml` did not move.

#### A6.  The `spine` doc comment (debt j)

The comment above `spine` is rewritten.  It now states, in order: the
activation test, the k leading formals, the family fence, the rigid
match against the expected type, the argument-driven capture pass with
its first-fit and no-backtracking rule, the settle fold, and the
argument descent.  Machine-checkable witness, which the plan asks for at
PLAN:1655-1657:

    rg -c -F 'argument-driven' /Users/oobi/Documents/tot/surface/elab.ml
    1

The one match is `surface/elab.ml:785`, inside the rewritten `spine`
comment.  At HEAD the same command printed nothing and exited 1.
Probe 5 pins the same count of 1 at dev/gates.sh:3381.  The count and
the match site were corrected in the review round;  see conflict note
C-A12.

### 3. Conflict notes

**Conflict note C-A1 (2026-09-04): the battery's PASS count is the gate
run's count, not the log-wide count.**  The battery spec counts
`rg -c '^PASS' <LOGPATH>`, and the log also carries the four `PASS`
lines that `dune exec test/main.exe | tail -3` and
`dune exec test/surface.exe | tail -3` repeat, plus the `PASS=` line
itself.  The first entry run therefore read `PASS=375` where
`dev/gates.sh` printed 371.  The same run read `FAIL=` empty, because
`rg -c` prints nothing and exits 1 on a zero match, which graft G8 warns
about.  Resolution: the battery tees the gate output to `<LOGPATH>.gate`
and counts `PASS` and `FAIL` there, with `|| echo 0` on both, and it
records the log-wide number beside them as `PASS-LOGWIDE`.  No gate leg
and no count in the plan changes.

**Conflict note C-A2 (2026-09-04): the marker-site command in the plan's
entry state prints 1, not 146.**  PLAN:1156 cites
`rg -c '^echo PASS-' /Users/oobi/Documents/tot/dev/gates.sh` for 146
marker sites.  Measured at HEAD, that anchored command prints `1`,
because nearly every site is indented or compound.  The unanchored
`rg -c 'echo PASS-' /Users/oobi/Documents/tot/dev/gates.sh` prints
`146`, and `rg -o 'echo PASS-' ... | wc -l` also prints `146`.
Resolution: the plan's NUMBER is right and its command is wrong;  this
log uses the unanchored command.  The plan's residue is then closed, not
merely recorded: the gate prints 147 marker LINES, and
`comm -23` of the emitted marker names against the `echo PASS-` literals
names the one extra, `PASS-C-PRIMLINT`.  105 + 119 + 147 = 371.

**Conflict note C-A3 (2026-09-04): `spine_infer` stands down completely
when no leading slot is a hole, and it keeps HEAD's error value at every
hole.**  PLAN:1438-1443 puts the `holed_leading_slot` guard around
`caps` only, but PLAN:1468-1472 states the property that "a HEAD-green
file therefore takes no new code path and does no extra work".  The
weaker guard cannot deliver that property: the settle fold elaborates
non-leading arguments with `term_at` and an instantiated domain, where
HEAD's SApp arm uses `term`.  Resolution: `spine_infer` returns `None`
when `holed_leading_slot ~k args` is false, so the caller takes
`app_infer`, which is HEAD.  The pin's intent, an infer-path settle that
moves only programs that fail at HEAD with the hole error, survives and
is strengthened.  Second half of the same note: a hole at a NON-leading
position inside `spine_infer` returns
`Serror.Hole { loc; expected = None }`, HEAD's value, where `spine`
would return `Some (scope, dom')`.  PLAN:1473-1478 binds the error value
of "an unsettled hole" without restricting it to a leading slot, and the
budget digest freezes the text of every red record, so the stricter
reading is the safe one.

**Conflict note C-A4 (2026-09-04): `local_ty` must shift what it
reads.**  PLAN:1223-1224 gives
`local_ty locals ix = List.nth_opt locals ix |> Option.join`.  The repo
proves that wrong by an executed probe.  Entry `i` of `locals` is scoped
over the scope its own binder was added to, so reading it `ix` binders
later needs `Term.shift ~cutoff:0 ~by:(ix + 1)`.  Without the shift,
probe A4-1 captured the wrong term and the kernel reported

    p-a4-prelude159.tot:1:1: type mismatch: expected Type 0, found #7

Resolution: `local_ty` shifts by `ix + 1` (elab.ml:308), and
`ctor_field_types` shifts field `i` by `i` (elab.ml:462), because the
fields of one branch are pushed together but each is instantiated in the
pre-branch scope.  The pin's intent, that the pass reads the type of a
later argument, survives;  only the mechanism gains the shift.  This is
the same class of correction PLAN:1370-1380 already makes for the
declared domain.

**Conflict note C-A5 (2026-09-04): `rigid` blocked a repeat formal met
under a binder.**  PLAN:1361-1363 says "`rigid` already refuses a
conflicting capture for the same formal through its `same_term` test".
Read at `surface/elab.ml:153-188`, the `same_term` test runs only in the
`d = 0` arm;  a formal `p < k` met at depth `d > 0` falls to the final
arm and returns `None`, which blocks the WHOLE match.  A declared domain
such as `A -> A -> Bool` holds the formal at depth 0 and at depth 1, so
it refused itself, and probe A3b-1 reported

    p-a3b-prelude173.tot:2:39: hole: no expected type at this position

with exit 1 where the plan requires exit 0.  Resolution: a repeat
occurrence of an ALREADY CAPTURED formal at `d > 0` now confirms against
that capture shifted by `d`, and blocks when the two do not print
identically.  No capture is ever made under a binder, no slot is
widened, and the change can only turn a `None` match into a `Some`,
which is a state where `caps` was empty and every holed leading slot was
an error at HEAD.  Conservativity is unaffected, and the budget digest
proves it.

**Conflict note C-A6 (2026-09-04): the new pure helpers are top-level
`let` bindings, not `and` members of the `term` group.**  PLAN:1223,
PLAN:1265 and PLAN:1331 write `and local_ty`, `and synth` and
`and arg_caps`.  Only `arg_caps`, `spine_infer` and `app_infer` call
`term`, so only those three need the recursive group.  Resolution: the
other helpers are defined before `term`, which lets the compiler check
them on their own.  Names, types and semantics are the plan's.

**Conflict note C-A7 (2026-09-04): there is no `Term.subst`.**
PLAN:1288-1291 offers "`Term.subst` (or the existing instantiation
helper used by `inst_domain`)".  `lib/term.ml` has exactly one top-level
function, `shift` at lib/term.ml:114, so the first spelling does not
exist.  Resolution: `inst_applied` takes the second spelling.  It peels
`n` domains with `peel_domains` and calls
`inst_domain ~j:n ~k:n applied ~d:0 rest`, which substitutes the actual
argument for every formal of the peeled telescope.  No new de Bruijn
arithmetic is added, which is what the plan sentence asks for.

**Conflict note C-A8 (2026-09-04): part 1 alone cannot reach PASS=371,
and the plan says so.**  The part 1 brief expects the exit battery to
read 371 with the elaborator alone.  PLAN:1505-1518 (A7) states the
opposite: the new rule RESOLVES two committed M6 negatives, so three
legs must be re-opened in the same commit.  Measured at exit, the exit
battery reads `GATE-EXIT=1`, `PASS=223`, `FAIL=1`, and the one FAIL is

    FAIL M6C-5 m6c_refuse_a: the let* A slot is argument-driven, so its
    hole reports the slot's declared universe on one line
      expected [2:8: hole: expected Type 0], but the script ran:
      [def main : (IO Verdict)]

which is A7 item 3 word for word.  `dev/gates.sh` stops at `TEST-FAIL`,
so the marker legs after the suites did not run and `PASS=223` is a
partial count, not a regression count.  Every file that repairs this
belongs to part 2.  Resolution: part 1 does not touch them, and it
proves conservativity by the two oracles that do not depend on part 2.
Read section 4.

**Conflict note C-A16 (2026-09-04): review round 2, adjudicated by hand.**
Round 2 ran 12 shard finders and one black-box probe pass over the
working diff.  A session limit stopped the seven refuters, so the seven
capped findings were adjudicated by hand from the cited lines.

1. `arg_caps` (surface/elab.ml:974) elaborates each non-leading
   argument once in infer position to read its type, and `spine` then
   elaborates the same argument again in check position.  A nested
   spine whose leading slot is a hole runs its own capture pass inside
   both, so the cost grows as 2^depth in the nesting depth of holed
   spines.  The probe pass measured the growth at six timing points.
   Pin 3 prescribes the infer-position elaboration, and a reuse of that
   result would turn a check-position elaboration into an infer-position
   one, so the fix is not local to Stage A.  CARRIED to M8 as a debt:
   memoize the infer-position result per syntax node, or bound the
   depth.  No corpus program nests a holed spine (the budget digest is
   unmoved), so no shipped program pays the cost.
2. The `arg_caps` doc comment said the first matching argument keeps
   its captures.  The code merges captures across later arguments for
   slots still open and never replaces one.  The comment now says so
   (surface/elab.ml:957-959).  No code change.
3. The two negative conjuncts of PASS-M7A-INFER-SETTLE
   (dev/gates.sh:3440-3443) re-read the stderr files that
   PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE wrote earlier in the same run,
   and the three error-value legs of C-A13 re-run the same three
   negatives as marker (iii).  Both are redundant by design, not
   vacuous: the scratch directory is created per run, and every marker
   flips under its own mutation (10 of 10 in the mutations log).  Kept.
   A fresh run inside marker (vi) would add two tier calls and move the
   TIERS literal again for no detection power.
4. The A9 reach claim for the two Stage B guard slots, and the twins
   `arg-map-explicit.tot` and `arg-ambiguous-explicit.tot`, are build
   log measurements by plan A9 and A11 (M7-PLAN.md:1821-1823, 1981,
   2003), not gate legs.  Not defects.
5. Probe results that are not findings: the fence holds in check and
   infer position and through both family formers; both hole exits keep
   `expected = None`; error ordering moves only for a spine whose first
   failure is the hole (plan rule 5, M7-PLAN.md:1509-1515); the shifts
   in `local_ty`, `ctor_field_types`, `branch_expected` and `arg_caps`
   compose correctly (six probes over List, Pair, Result and Json);
   `spine` and `spine_infer` stay in lockstep.  Two defensive gaps with
   no failure scenario: `ctor_field_types` ignores the spine head at
   elab.ml:476, and the `Term.Var` path of `synth` skips the `has_auto`
   guard at elab.ml:401.  Both CARRIED to M8 with the debt of item 1.

### 4. Exit state and the conservativity proof

- Exit battery: runner
  `/Users/oobi/Documents/tot-m7-probes/stageA/battery.sh`, log
  `/Users/oobi/Documents/tot-m7-stageA-gate.log`, gate slice
  `...gate.log.gate`.  `BUILD-EXIT=0`, `GATE-EXIT=1`, `PASS=223`,
  `FAIL=1`.  The single FAIL is `M6C-5`, quoted in C-A8.
- Kernel suite: `M0 kernel: all tests green`, 105 PASS, unchanged.
- Surface suite: 118 PASS and 1 FAIL, against 119 PASS at entry.  The
  one case that moved is `M6C-5`, which A7 item 3 re-points.
- `PASS-M7A-INFER-SETTLE-BUDGET` after the elaborator edits, same
  command as the entry run:

      files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2

  Identical to the HEAD line, character for character.  This is the
  pin 2 oracle: 100 corpus files, 61 green records whose stdout did not
  move and 39 red records whose error text did not move, with the two
  files A7 licenses excluded.
- Frozen `lib/` set md5 after the edits:
  `f446f043e1ad6c7b85ddedb7736bd8a1`, identical to the entry line.
- Transcript drift, measured read-only into
  `/Users/oobi/Documents/tot-m7-probes/stageA/transcript-new.txt`, with
  `dev/m5e-default-transcript.txt` left untouched:
  - `rg -c '^### '` prints 101 on both the old file and the new one, so
    no block was added or lost.
  - `diff` reports 8 changed lines inside exactly TWO blocks,
    `test/fixtures/m6c-hole-a.tot` and
    `test/fixtures/m6c-hole-run.tot`, each an `#exit 1` turning into
    `#exit 0` with the hole line replaced by the definition line.
  - This is A8 exactly: two blocks reseal, and nothing else moves.
    Part 2 owns the reseal.

### 5. PART 1 HANDOFF

What changed, and where.

- `surface/elab.ml`, 536 lines at HEAD, 981 lines now.
  - elab.ml:153-200 `rigid`, one new arm, conflict note C-A5.
  - elab.ml:265-515 the new helper block: `take` 267, `is_hole` 273,
    `holed_leading_slot` 284, `holed_leading_slot_unsettled` 291,
    `settles_all` 298, `local_ty` 308, `spine_head` 313, `has_auto` 323,
    `min_opt` 340, `min_free_var` 347, `is_closed` 371, `inst_applied`
    380, `synth` 397, `rigid_or_whnf` 417, `branch_body_has_hole` 434,
    `ctor_field_types` 462, `branch_expected` 502.
  - elab.ml:517 `term` gains `?locals`;  its SApp arm at elab.ml:534 is
    the A3b entry point;  its SMatch branch fold at elab.ml:661 is A4.
  - elab.ml:700 `term_at` gains `?locals`;  every arm threads it and the
    SLam, SLet and SMatch arms extend it.
  - elab.ml:797 `spine` gains `?locals`, a rewritten doc comment (A6)
    and the A3 capture pass;  the settle fold below it is unchanged
    apart from the threading.
  - elab.ml:880 `spine_infer`, elab.ml:946 `app_infer`, elab.ml:964
    `arg_caps`, all new.
- `lib/check.ml`, one named `Term.App` arm at lib/check.ml:1208 with the
  catch-all's body, and the catch-all reduced to its other six
  constructors.  No signature and no behaviour changed.

Per-part probe results: A1 through the A4-1 oracle;  A2 and A3 through
`m6c-hole-a.tot` exit 0 and `m6c-hole-run.tot` exit 0;  A3b through the
prelude:173 shape matching its explicit twin byte for byte, plus the
three pin 2 negatives keeping their exact HEAD lines;  A4 through the
nested constant-motive shape matching its explicit twin byte for byte;
A5 through the frozen md5 and the unchanged kernel suite;  A6 through
`rg -c 'argument-driven' surface/elab.ml` = 4, which printed nothing at
HEAD.  The probe sources and the runners live in
`/Users/oobi/Documents/tot-m7-probes/stageA/`, outside every corpus
glob, so they add no transcript block and enter no digest.

Open notes for part 2.

1. Three legs must be re-opened, all in part 2's files, and the tree is
   RED until they are.  Surface case `M6C-5` (A7 item 3), the
   `PASS-M6C-HOLE-REPORTS` leg (a) at dev/gates.sh:2668-2669 and 2686
   (A7 item 1), and the `m6c-hole-run.tot` leg (A7 item 2).  Both
   fixtures now check with exit 0;  the exact new lines are in section 3
   under C-A8 and in section 2 under A3.
2. The transcript reseal is two blocks and no block-count change.  The
   regenerated file is at
   `/Users/oobi/Documents/tot-m7-probes/stageA/transcript-new.txt` and
   part 2 may diff against it before it reseals
   `dev/m5e-default-transcript.txt`.
3. The two frozen literals are unmoved and must stay unmoved through
   part 2:  `files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2`
   and `f446f043e1ad6c7b85ddedb7736bd8a1`.  Part 2 adds fixtures under
   `dev/m7a/`, which is outside the digest's `--max-depth 1` corpus, so
   neither literal may move.  A move means a part 2 fixture landed in
   `stdlib/`, `examples/` or `test/fixtures/` at depth 1.
4. Conflict notes C-A1 and C-A2 are counting corrections and part 2
   inherits them.  The battery counts PASS and FAIL over the gate slice,
   and the marker-site command is the unanchored `rg -c 'echo PASS-'`.
5. Conflict notes C-A3, C-A4 and C-A5 changed a mechanism, never an
   intent.  A reviewer reads C-A5 first, because it edits the M6
   `rigid`, and the argument that no HEAD-green program can reach the
   new arm is in the note.

### 6. PART 2 (2026-09-04): fixtures, suite cases, the gate block, the
### three M6C re-opens, the transcript reseal, the tier literal

Part 2 owns plan parts A7, A8, A9, A10 and A11, the Stage A gate
additions, and review checklist items 9, 10, 11, 15 and 16.  It touched
no elaborator logic.  The one edit inside `surface/elab.ml` is a doc
comment reword, recorded below as conflict note C-A10.

#### Entry state for part 2

- `git status --porcelain` at entry: 4 lines (`dev/M6-PLAN.md`,
  `dev/M7-PLAN.md`, `lib/check.ml`, `surface/elab.ml`), plus the
  untracked `dev/M7-BUILD-LOG.md`.  The two plan files belong to
  another agent in this run and part 2 never touched them.
- Entry battery: `/Users/oobi/Documents/tot-m7-stageA-close-gate.log`,
  `GATE-EXIT=1`, whole-log `PASS=227`, `FAIL=1`.  Over the gate slice
  alone the same run reads 223.  The single red leg was surface case
  `M6C-5 m6c_refuse_a`:

      FAIL M6C-5 m6c_refuse_a: ...
        expected [2:8: hole: expected Type 0], but the script ran:
        [def main : (IO Verdict)]

  That red is the collateral plan A7 predicts, not a part-1 defect.
  Part 1 resolves the hole that the M6 leg pinned as refused.  A7 item
  3 re-points the case;  the stage reads 390 after A7 and A8 land.

#### A10 and A11.  29 fixtures under `dev/m7a/`

Every file is the plan's bytes.  Where A10 and A11 disagree, A11 wins:
`arg-exhausted.tot` carries the A11 `liftIO _ _` spelling, and
`arg-infer.tot` is not created at all, because A11 renames it to
`arg-infer-holed.tot` and adds `arg-infer-explicit.tot`.  `ls
/Users/oobi/Documents/tot/dev/m7a | wc -l` prints 29.

Measured after the stage with
`_build/default/bin/tot.exe check`, path prefix stripped.  The twelve
twin pairs print byte-identical stdout at exit 0.

| fixture | exit | first line of output |
| --- | --- | --- |
| s1-explicit.tot | 0 | `def main : (IO Verdict)` |
| s2-holed.tot, s2-explicit.tot | 0, 0 | `def probeRW : (IO String)` |
| s3-holed.tot, s3-explicit.tot | 0, 0 | `def myEqList : (0 A : Type 0) -> (w _ : (EqD A)) -> (EqD (List A))` |
| s4-holed.tot, s4-explicit.tot | 0, 0 | `def myMember : (0 A : Type 0) -> (w _ : (EqD A)) -> (w _ : A) -> (w _ : (List A)) -> Bool` |
| s5-holed.tot, s5-explicit.tot | 0, 0 | `def myMap : (0 A : Type 0) -> (0 B : Type 0) -> (w _ : (w _ : A) -> B) -> (w _ : (List A)) -> (List B)` |
| s6-holed.tot, s6-explicit.tot | 0, 0 | `def myAnyList : (0 A : Type 0) -> (w _ : (w _ : A) -> Bool) -> (w _ : (List A)) -> Bool` |
| s7-holed.tot, s7-explicit.tot | 0, 0 | `def myListEqBy : (0 A : Type 0) -> (w _ : (w _ : A) -> (w _ : A) -> Bool) -> (w _ : (List A)) -> (w _ : (List A)) -> Bool` |
| arg-map.tot, arg-map-explicit.tot | 0, 0 | `def probeF : (List Nat)` |
| arg-ambiguous.tot, arg-ambiguous-explicit.tot | 1, 1 | `arg-ambiguous.tot:2:1: type mismatch: expected (List Nat), found (List String)` |
| arg-exhausted.tot | 1 | `arg-exhausted.tot:2:8: hole: expected Type 0` |
| infer-lift-holed.tot, infer-lift-explicit.tot | 0, 0 | `eval : (IO (Option Json))` |
| infer-listeqby-holed.tot, infer-listeqby-explicit.tot | 0, 0 | `eval : (w _ : (List Bool)) -> (w _ : (List Bool)) -> Bool` |
| infer-fenced.tot | 1 | `infer-fenced.tot:1:13: hole: no expected type at this position` |
| infer-fenced-explicit.tot | 0 | `eval : (EqD Bool)` |
| infer-undetermined.tot | 1 | `infer-undetermined.tot:1:14: hole: no expected type at this position` |
| arg-infer-holed.tot, arg-infer-explicit.tot | 0, 0 | `def probeI : (List Nat)` |
| guard-slot-holed.tot, guard-slot-explicit.tot | 0, 0 | `def main : (IO Verdict)` |

The A9 reach claim is now measured on the shipped binary, not
predicted:  all seven pin 5 anchor shapes check at exit 0 and match
their explicit twins, and `guard-slot-holed.tot` (the A9 mirror of
`examples/guard.tot:134` and `examples/guard-rewrap.tot:265`) checks at
exit 0 with the line its explicit twin prints.  The settle therefore
REACHES both Stage B guard slots.  Stage A changed neither example
file, and it does not decide pin 6.

#### A7.  Three M6C legs re-opened, none deleted

1. `PASS-M6C-HOLE-REPORTS` leg (a) now reads
   `dev/m7a/arg-exhausted.tot` instead of
   `test/fixtures/m6c-hole-a.tot`, and its pinned line is
   `^\S*/arg-exhausted\.tot:2:8: hole: expected Type 0$`.  The leg keeps
   its name, its four sub-legs, its four exit-code tests, its four
   empty-stdout tests and its four one-line stderr tests.  The column
   and the message do not move.
2. `test/fixtures/m6c-hole-run.tot` is re-spelled in place to
   `def main : IO Unit := let* Unit Unit x := printLine "SIDE-EFFECT" in pureIO Unit _`.
   Measured: exit 1, empty stdout, one stderr line,
   `m6c-hole-run.tot:1:82: hole: expected Unit`, and no `SIDE-EFFECT`
   in the output.  `PASS-M6C-HOLE-NEVER-RUNS` keeps every assertion and
   changes one pinned string, `1:28: hole: expected Type 0` to
   `1:82: hole: expected Unit`.
3. Surface case `M6C-5 m6c_refuse_a` now runs the A11 exhausted source
   string.  It keeps its name, its helper `m6c_expect_err_line` and its
   pinned message `2:8: hole: expected Type 0`.

#### Suite.  12 new cases, `test/surface.ml`

`M7A-1` to `M7A-10` reuse `m6c_twins` and `M7A-11` and `M7A-12` reuse
`m6c_expect_err_line`, as the plan states.  Every source is a string
constant that holds the bytes of the matching `dev/m7a/` fixture, so a
case and its fixture cannot drift apart, and no case adds a transcript
block.  `dune exec test/surface.exe | rg -c '^PASS '` prints 131, up
from 119, which is exactly 12.

#### Gate additions.  7 markers

The block sits after `PASS-M6E-TRANSCRIPT-RESEALED` and before the two
timing-sensitive tail legs, in the plan's probe order.  Its scratch dir
is `m7a_scratch`, and the EXIT trap at dev/gates.sh:434 now removes it.

| marker | asserts | measured after the stage |
| --- | --- | --- |
| PASS-M7A-KERNEL-UNCHANGED | `rule=1`, `define=1`, frozen kernel md5, and `arg-map.tot` at exit 0 | `f446f043e1ad6c7b85ddedb7736bd8a1`, exit 0 |
| PASS-M7A-ARGHOLE-RESOLVES | six twin pairs equal and non-empty, exhausted still exit 1, ambiguous at the kernel mismatch | all 14 runs as tabled above |
| PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE | three whole stderr lines unmoved, one control that flips, one explicit control at exit 0 | `1:6`, `1:13`, `1:14`, control exit 0 |
| PASS-M7A-CONSERVATIVITY | five green examples byte-identical, every stderr empty, transcript `hole:` count | `99c23b4b74c722735d17e1dc49524e58`, 55 lines, 0 stderr bytes, 8 |
| PASS-M7A-SPINE-COMMENT | the stale sentence gone, the descent sentence held, `argument-driven` present, the side effect held | `stale= descent=1 m7=1 run=1` |
| PASS-M7A-INFER-SETTLE | four infer-path twins equal and non-empty, two negatives unmoved | `holed=0000`, `neg=11` with both HEAD lines |
| PASS-M7A-INFER-SETTLE-BUDGET | the whole-corpus digest | `files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2` |

Marker lines: `rg -c 'echo PASS-' /Users/oobi/Documents/tot/dev/gates.sh`
prints 153, up from 146, which is exactly 7 (conflict note C-A2 owns the
unanchored spelling).  The gate emits 154 marker lines, because
`PASS-C-PRIMLINT` has no `echo PASS-` literal (conflict note C-A1).

#### The `PASS-M5D-TIERS` literal, re-derived

Command, run after the block landed:

    rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' /Users/oobi/Documents/tot/dev/gates.sh

printed **202**.  At HEAD the same command printed 169.  The literal at
dev/gates.sh inside `PASS-M5D-TIERS` is now 202.  The 33 new tier-call
lines are: 1 in leg (i), 14 in leg (ii), 4 in leg (iii), 5 in leg (iv),
0 in leg (v), 8 in leg (vi) and 1 in leg (vii).  The plan predicted 180
from an 11-line estimate.  The estimate assumed the `for` loops of the
plan's own probe commands;  the build ground rule keeps every new leg
loop-free, so each fixture run is its own tier line.  See conflict note
C-A9.  `rg -q '"\$watchdog" [0-9]'` still exits 1, so the no-numeric-
literal oracle holds.

#### A8.  The transcript reseal

`dev/gen-m5e-transcript.sh` regenerated the file, and the result
replaced `dev/m5e-default-transcript.txt`.

- Block count before: 101.  Block count after: 101.  No block was added
  or removed, so `PASS-M6E-TRANSCRIPT-RESEALED` holds unchanged, and
  `PASS-M5E-DEFAULT-IDENTITY` passes against a fresh generation.
- `rg -c 'hole:'` before: 9.  After: 8.
- md5 before: `a27d9e06814822884b1821148d9c0fc4`.  After:
  `e0943042fd0ef721b54e26f975fa2f03`.
- `diff` is 12 lines and touches exactly two blocks, the two that A8
  names.  No third block moves:

      9606c9606
      < #exit 1
      ---
      > #exit 0
      9607a9608
      > def main : (IO Verdict)
      9609d9609
      < test/fixtures/m6c-hole-a.tot:2:8: hole: expected Type 0
      9647c9647
      < test/fixtures/m6c-hole-run.tot:1:28: hole: expected Type 0
      ---
      > test/fixtures/m6c-hole-run.tot:1:82: hole: expected Unit

  Block `test/fixtures/m6c-hole-a.tot` goes green: its `#exit` line
  moves from 1 to 0, its `#out` gains the def line, and its `#err`
  loses the hole line.  Block `test/fixtures/m6c-hole-run.tot` keeps
  the word `hole:` with a new column and a new expected type.  The
  other seven `hole:` lines do not move.

#### The budget line, three times

Review checklist item 15.  The command is the plan's probe 7 spelling.

    part 1, before the elaborator edits: files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2
    part 1, after the elaborator edits:  files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2
    part 2, after every edit of this part: files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2

The frozen kernel digest is unmoved as well:
`f446f043e1ad6c7b85ddedb7736bd8a1`.

#### Conflict notes

**Conflict note C-A9 (2026-09-04): the plan's gate commands use `for`
loops, and build ground rule 2 forbids a loop in a new leg.**
PLAN:2145-2443 spells probes 2, 3, 4, 6 and 7 as one-line shell
commands with `for f in ...; do ... done`.  PLAN:625-675 says "NEW gate
legs and dev scripts are LOOP-FREE: no `for`, no `while`, in zsh legs
included".  Resolution: the assertions are the plan's, and the shape is
the file's own capture-then-assert idiom.  Legs (i) to (vi) unroll
their fixture runs, one named variable per run.  Leg (vii) keeps the
plan's 100-file digest and drops the loop for
`fd | rg -v | sort | xargs -n 1`, which visits the same paths in the
same order.  PROOF that the digest did not change: both spellings were
run side by side on the same tree
(`/Users/oobi/Documents/tot-m7-probes/stageA/p2-values.sh`), and both
printed `files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2`.  The
only visible cost is the tier count, 202 instead of the predicted 180,
and that literal is re-derived by measurement anyway.

**Conflict note C-A10 (2026-09-04): probe 5 wants the phrase `then
argument descent through`, and part 1 wrote it in capitals.**
PLAN:2318-2320 pins `descent=1` from
`rg -c -F 'then argument descent through' surface/elab.ml`, whose job is
to refuse a doc comment that was deleted instead of rewritten.  Measured
on the part-1 tree, that command printed nothing, because the rewritten
comment reads `Then ARGUMENT DESCENT through [inst_domain]`, and `rg -F`
is case-sensitive.  Two repairs were possible: soften the leg to `-i`,
or restore the phrase.  Resolution: the phrase is restored, so the gate
keeps the plan's literal.  The last sentence of the `spine` doc comment
now reads "The fold walks the arguments in that same order, and then
argument descent through [inst_domain] (or [term] when the fence is up,
or when a domain keeps a telescope Var) elaborates each one."  This is a
comment edit.  No code, no name and no semantics moved.  After it,
probe 5 prints `stale= descent=1 m7=1 run=1`, byte for byte the plan's
after-stage line.

#### Exit state

- `git status --porcelain`: 10 lines.  Tracked and modified:
  `dev/M6-PLAN.md`, `dev/M7-PLAN.md` (both owned by another agent in
  this run), `dev/gates.sh`, `dev/m5e-default-transcript.txt`,
  `lib/check.ml`, `surface/elab.ml`, `test/fixtures/m6c-hole-run.tot`,
  `test/surface.ml`.  Untracked: `dev/M7-BUILD-LOG.md`, `dev/m7a/`.
- Battery: `/Users/oobi/Documents/tot-m7-stageA-gate.log`,
  `BUILD-EXIT=0`, `GATE-EXIT=0`, `GATE-PASS=390`, `GATE-FAIL=0`.
- Decomposition of 390: 154 gate markers + 105 kernel suite cases + 131
  surface suite cases.  Chain: 371 at HEAD, plus 7 markers, plus 12
  surface cases, equals 390.
- That log reads `PASS=394` on its own `PASS=` line, four higher than
  the gate slice, because the runner also tails the last three lines of
  each suite executable before the gate runs the suites again.  The
  review-round runner prints the gate slice as `PASS=` and the log-wide
  number as `PASS-LOGWIDE=`, so the `PASS=` line is the number the plan
  chains on (conflict notes C-A1 and C-A14).
- Review checklist items 9, 10, 11, 15 and 16 are all met: no leg was
  deleted and all three re-opened legs keep their names and their
  assertion counts (item 9);  the transcript shows two changed blocks
  and the same block count, with both transcript markers green (item
  10);  the tier literal was re-derived by measurement and the printed
  value 202 is recorded above (item 11);  the budget line is recorded
  three times and never moved (item 15);  and the full gate run prints
  390 PASS lines and no FAIL line (item 16).

### Review-round fixes (2026-09-04)

The review handed Stage A five findings on 2026-09-04.  Four are fixed
here.  One is skipped, because the plan prescribes what the tree does.
Each note gives the value observed before the fix and the value observed
after it.  The round changed two comment lines in `surface/elab.ml`,
three legs and one literal in `dev/gates.sh`, and this log.  No
elaborator code, no kernel code, no fixture and no suite case moved.

**Conflict note C-A11 (2026-09-04): the A4 occurs test also refuses an
INDEX binder, and the plan text names only the `as` binder.**
PLAN:1582-1597 states one motive precondition, "the elaborated motive
body does not mention its own `as` binder", and calls `expected'` "the
motive body with the `as` slot dropped".  The code is stricter.
`branch_expected` (surface/elab.ml:502-514) computes
`depth = 1 + List.length mo.Term.m_idx`, returns `None` when
`min_free_var ~d:0 mo.Term.m_body` is `Some i` with `i < depth`, and
drops all `depth` slots with `Term.shift ~by:(-depth)`.  So a motive
body that mentions ANY index binder also keeps `term`.  Observed before:
the rule sits in the code and in prose at section 2 A4, with no numbered
note, unlike the six other mechanism deviations.  Observed after: this
note.  No code moved.  The stricter test is the safe direction, for two
reasons.  It sends strictly FEWER branch bodies down the check-position
path, so conservativity can only improve, and no HEAD-green file can
take a path it did not take before.  The guard also fires before the
negative shift, so `Term.shift ~by:(-depth)` cannot underflow.  The
reason is the reason PLAN:1593-1597 gives for the `as` binder: a motive
that mentions an index binder needs the dependent instantiation at the
branch pattern, which is kernel work and sits outside M7 scope.

**Conflict note C-A12 (2026-09-04): the A6 witness count was wrong, and
the witness matched the wrong comment.**  Observed before: this log
recorded `rg -c 'argument-driven' surface/elab.ml` printing 4.  The
command printed 1.  The one case-sensitive match sat at
surface/elab.ml:878, inside the `spine_infer` doc comment, and NOT
inside the rewritten `spine` comment, which spelled the phrase
`ARGUMENT-DRIVEN` and so did not match the case-sensitive gate literal.
The three other occurrences of the phrase were capitals.  So probe 5
held the rewrite only through its `stale` leg, and a build that added
`spine_infer` and left the `spine` comment alone would still print
`m7=1`.  Fix: the `spine` comment now spells the phrase
`argument-driven` (surface/elab.ml:785) and the `spine_infer` comment
spells it `ARGUMENT-DRIVEN` (surface/elab.ml:878).  Observed after:
`rg -c -F 'argument-driven' /Users/oobi/Documents/tot/surface/elab.ml`
prints 1, and `rg -n -F` reports the one line as 785, inside the
rewritten `spine` comment, which is the comment PLAN:1655-1657 names.
The gate literal at dev/gates.sh:3381 is unchanged and still asserts 1.
The capitals at PLAN:1653 are the plan's own emphasis;  the witness the
plan asks for is the WORD, and it now lives where the plan puts it.
PASS-M7A-SPINE-COMMENT prints `stale= descent=1 m7=1 run=1` after the
fix, which is the plan's after-stage line.

**Conflict note C-A13 (2026-09-04): the budget could not see rule 3, so
leg (vii) gained three error-value legs.**  PLAN:1535-1551 lists five
things the infer settle must not do and says "The probe for all five is
PASS-M7A-INFER-SETTLE-BUDGET".  Rule 3 is "It must not change the error
VALUE of an unsettled hole".  Observed before: the 100-file digest
cannot see rule 3.  No corpus file holds an infer-position SPINE with a
holed LEADING slot.  `test/fixtures/m6c-hole-n-infer.tot` is the bare
command `eval _`, whose hole is not an `SApp` argument and never reaches
`spine_infer`.  Measured proof
(`/Users/oobi/Documents/tot-m7-probes/stageA/mut-budget.sh`): with the
settle site mutated from `expected = None` to
`expected = Some (scope, dom)` and the tree rebuilt at `BUILD-EXIT=0`,
the three digest fields stayed at `files=100 green=61
md5=9b416b949964a50c4f7633eab478b5c2`, byte for byte the pinned
literals, while `dev/m7a/infer-undetermined.tot` moved from
`1:14: hole: no expected type at this position` to
`1:14: hole: expected Type 0`.  Fix: leg (vii) now also runs the three
pin-2 negatives of PLAN:1501-1506 and pins the whole line and the exit
code of each.  `eval _` is the corpus hole with no spine,
`eval (mkEqD _ boolEq)` is a spine under the family fence, which is rule
2, and `eval (liftIO _ _)` is a spine that reaches the settle fold,
which is rule 3.  Observed after, same mutation, same script: the digest
fields still do not move, and the two spine legs both move, so the
marker fails.  On the restored tree
(`md5 8e80299e01f1cda34395c4cb4f4ddf37` for surface/elab.ml) all three
negatives print their HEAD lines at exit 1 and the marker is green.  The
plan's sentence at PLAN:1551 is true of the gate after this fix.  No
corpus file was added, so the digest literals, the transcript block
count and the two transcript markers are untouched.

**Conflict note C-A14 (2026-09-04): the battery's `PASS=` line is now
the gate slice.**  Observed before:
`/Users/oobi/Documents/tot-m7-stageA-verify.log:481` reads `PASS=394`,
while PLAN:2534 calls for 390.  The four extra lines are the `PASS`
lines that `dune exec test/main.exe | tail -3` and
`dune exec test/surface.exe | tail -3` write into the same log before
`dev/gates.sh` runs the suites again.  The battery spec counts
`rg -c '^PASS'` over the whole log, which cannot equal 390 by
construction, so a reader who chains the M7 exit arithmetic on the
`PASS=` line reads the wrong number.  Fix, the shape conflict note C-A1
already describes and the entry log already uses: the runner tees the
gate output to `<LOGPATH>.gate`, counts `PASS` and `FAIL` there, prints
that count as `PASS=` and `FAIL=`, and prints the log-wide number beside
it as `PASS-LOGWIDE=`.  `GATE-PASS` and `GATE-FAIL` stay, so no earlier
reader breaks.  Observed after, in
`/Users/oobi/Documents/tot-m7-stageA-review-gate.log`: `PASS=390`,
`FAIL=0`, `PASS-LOGWIDE=394`, `GATE-PASS=390`, `GATE-FAIL=0`,
`GATE-EXIT=0`.  No gate leg and no count in the plan changed.

**Conflict note C-A15 (2026-09-04): the transcript diff is a CHANGED
diff, not an additions-only diff.  SKIPPED, no repair.**  The review
check asks that the git diff of `dev/m5e-default-transcript.txt` be
additions only.  Observed:
`git diff --numstat -- dev/m5e-default-transcript.txt` prints `3 3`,
three insertions and three deletions.  The plan prescribes exactly that.
PLAN:1699-1730 (part A8) says the review "must show exactly two changed
blocks and no third" and that "The block COUNT does not change, so
PASS-M6E-TRANSCRIPT-RESEALED holds unchanged".  A changed line is a
deletion plus an insertion, so two changed blocks cannot be
additions-only.  The two blocks are the ones A8 names:
`m6c-hole-a.tot`, now green, and `m6c-hole-run.tot`, re-spelled from
`1:28: hole: expected Type 0` to `1:82: hole: expected Unit`.  Both
transcript markers are green in the review-round battery.  Nothing was
changed, because a repair here would move a file the plan does not
license to move.  The predicate to use in a later review is "exactly two
changed blocks and an unchanged block count".

#### The `PASS-M5D-TIERS` literal, re-derived again

The three new legs of C-A13 are three more direct tier calls, so the
literal moved.  Command:

    rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' /Users/oobi/Documents/tot/dev/gates.sh

Observed before the review round: 202.  Observed after: 205.  The
literal inside `PASS-M5D-TIERS` (dev/gates.sh:2291) is now 205, with a
dated sentence above it, the form every earlier stage uses.
`rg -q '"\$watchdog" [0-9]'` still exits 1 and `bites` is still 2, so
the other two oracles of that marker hold.

#### Review-round exit state

- Battery: `/Users/oobi/Documents/tot-m7-stageA-review-gate.log`,
  `STATUS-LINES=10`, `BUILD-EXIT=0`, `GATE-EXIT=0`, `PASS=390`,
  `FAIL=0`, `PASS-LOGWIDE=394`, `GATE-PASS=390`, `GATE-FAIL=0`.
- The exit arithmetic is unmoved: 371 at HEAD, plus 7 markers, plus 12
  surface suite cases, equals 390.  The round added no marker and no
  suite case.
- `git status --porcelain` still reads 10 lines, the same set as the
  part-2 exit state.
- Files this round touched: `surface/elab.ml` (two comment lines),
  `dev/gates.sh` (three legs in the M7A (vii) block, one comment block,
  the `PASS-M5D-TIERS` literal and its dated sentence) and this log.

## Stage B (2026-09-04): the four guard A slots close, pin 6 negatives retired (pins 5, 6, 11)

Plan: `dev/M7-PLAN.md` B0-B7 (lines 2536-3269, verified with `rg -n` on
2026-09-04 against the tree at HEAD `37c0bb2`).  Chain: 390 -> 395
(+3 surface tests, +2 markers).  Corpus, fixtures, suite cases, gate
legs, one SPEC entry and this log only; no file under `lib/`,
`surface/` or `bin/` touched.

### 1. Entry state

- `git log -1 --oneline`: `37c0bb2` (Stage A committed); tree clean,
  `git status --porcelain -uall` empty at entry.
- Entry battery
  (`/Users/oobi/Documents/tot-m7-stageB-entry-gate.log`): `GATE-EXIT=0`;
  the wrapper's own `PASS=394` line counts the `dune exec ... | tail -3`
  preview twice for four already-printed lines (2 kernel + 2 surface),
  so the true suite total is `PASS=394 - 4 = 390`, verified directly:
  105 kernel PASS lines (offset 15-158 of the log) + 131 surface PASS
  lines (offset 159-311) + 154 `PASS-` marker lines = 390.  `FAIL=`
  (empty, i.e. 0).  `M7A-MARKERS=7`.  No `LOAD-RED` (the wrapper never
  entered its retry branch).
- Entry measurements, before any edit:
  - Tiers: `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh`
    = 205.
  - Holed anchors: `python3 dev/hole-anchors.py | rg -c 'anchor=\[_\]'`
    = 22.
  - `python3 dev/hole-anchors.py | tail -1` =
    `ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30`.
  - `ls examples/*.tot test/fixtures/*.tot | wc -l` = 101;
    `rg -c '^### ' dev/m5e-default-transcript.txt` = 101.
  - `md5 -q dev/m5e-default-transcript.txt` =
    `e0943042fd0ef721b54e26f975fa2f03`.

### 2. What changed

- `examples/guard.tot` lines 133-134: `let* String _ raw := readStdin
  in` -> `let* _ _ raw := readStdin in`; `let* (Option Json) _ parsed
  := liftIO _ (jsonParse raw) in` -> `let* _ _ parsed := liftIO _
  (jsonParse raw) in`.
- `examples/guard-rewrap.tot` lines 264-265: the same two edits.
  Verified: `awk 'NR==133 || NR==134'` and `NR==264 || NR==265` print
  the re-spelled pair for both files.  `tot.exe check` on both edited
  files exits 0 and prints the same line sets as scratch copies of the
  HEAD bytes (`git show 37c0bb2:<path>`), confirmed by direct
  side-by-side comparison (the sandbox refuses `/dev/fd` process
  substitution for `diff`, the same limit `dev/gates.sh`'s
  `PASS-M6E-TRANSCRIPT-RESEALED` conflict note C-E4 records, so the two
  outputs were compared by eye and are byte-identical).
  `tot.exe run examples/guard.tot < test/fixtures/deny.json` exits 2
  and prints the deny envelope pinned at `dev/gates.sh:3120`
  (`m6e_wantenv`), byte-identical to the pre-edit envelope.
- `test/fixtures/m7/` (new directory): three fixtures landed byte for
  byte from plan B4.3 (`m7b-guard-arg-slots.tot`, `m7b-liftio-slot.tot`,
  `m7b-arg-slot-undetermined.tot`), with the amendment fix of conflict
  note C-B1 below.  Observed with the HEAD-plus-Stage-A binary:
  - `m7b-guard-arg-slots.tot`: exit 0, stdout `def main : (IO
    Verdict)`.
  - `m7b-liftio-slot.tot`: exit 0, stdout `def main : (IO Verdict)`.
  - `m7b-arg-slot-undetermined.tot`: exit 1, stderr
    `/Users/oobi/Documents/tot/test/fixtures/m7/m7b-arg-slot-undetermined.tot:7:8: hole: expected Type 0`.
  All three match the plan's pinned lines and columns.  The B7 risk
  fallback was NOT needed: every slot closed on the first try.
- `test/surface.ml`: three source strings (`m7b_both_src`,
  `m7b_lift_src`, `m7b_none_src`) added after `m7a_exhausted_src`, and
  three `cases` entries (M7B-1, M7B-2, M7B-3) appended after M7A-12,
  before the closing `]` of the case list, plan B4.4 verbatim.
- `dev/gates.sh`: the plan B5.1 block landed VERBATIM (diffed by eye
  against the plan's own fenced block) between the closing `}` of the
  `PASS-M7A-INFER-SETTLE-BUDGET` fail arm (line 3511 at entry) and the
  `# ctxcat id 5:` comment (line 3513 at entry), one blank line on each
  side, per the placement ruling.  `PASS-M6E-GUARD-HOLES`'s literal
  moved 22 -> 26 with a dated sentence above it (19 re-spelled M6 sites
  + the scrubber's three + these four Stage B A slots = 26).
  `PASS-M5D-TIERS`'s literal moved 205 -> 211 (measured: the block adds
  six direct `"$watchdog" "$FAST"` calls, three per leg) with a dated
  sentence above it giving both numbers.  `PASS-M5D-MEASURE-LOG`'s
  literal (22) and pinned name set did not move: no leg in the new
  block uses `gate_timed`.  `zsh -n dev/gates.sh` exits 0 after every
  edit.
- `SPEC.md`: one dated decision-log entry appended at the end of
  section 2 (after line 1576, before the `## 3.` heading at line
  1578), in the shape of the M6 Stage H entry.  It carries no
  `ANCHORS` line and does not spell `expected-type-only=` (verified:
  `rg` over the new entry's span finds neither), names
  `surface/elab.ml:287-291` and `lib/check.ml:958-959`, the
  Ratification amendment of 2026-09-04, the 22 to 26 move, and states
  that `SPEC.md:2127-2130` is superseded without editing it (Stage E's
  citation repair owns that passage).
- `Error.t` / `Serror.t` variants added or removed: none.  No file
  under `lib/`, `surface/` or `bin/` touched (`git status --porcelain`
  confirms: `SPEC.md`, `dev/gates.sh`, `examples/guard-rewrap.tot`,
  `examples/guard.tot`, `test/surface.ml` all ` M`, and
  `test/fixtures/m7/` the only `??`).

Build: `dune build` 0 errors, 0 warnings after every edit.

### 3. Tests added (surface suite 131 -> 134)

`test/surface.ml`: `M7B-1 m7b_guard_arg_slots`, `M7B-2
m7b_liftio_slot`, `M7B-3 m7b_arg_slot_undetermined`, plan B4.4
verbatim.  `dune exec test/surface.exe | rg -c '^PASS'` = 134; all
three M7B names print `PASS M7B-<n> ...`.  Kernel `test/main.exe` PASS
count stays 105, unchanged.

### 4. Gate markers added (154 -> 156)

`PASS-M7B-GUARD-ARG-HOLES` (pins 5, 11) and `PASS-M7B-LIFTIO-SLOT-CLOSES`
(pin 6, amended; the plan's originally allocated name
`PASS-M7B-ARG-SLOT-EXPLICIT` lands nowhere in the tree, confirmed:
`rg -c 'PASS-M7B-ARG-SLOT-EXPLICIT' dev/gates.sh` exits 1).
`rg -c 'PASS-M7B' dev/gates.sh` = 4 (the two `echo` lines plus their
two comment mentions).  `zsh -n dev/gates.sh` exits 0.
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` = 211
(was 205: six FAST calls added, three per leg, none deleted).

### 5. Conflicts (section 5 protocol)

- Conflict note C-B1 (2026-09-04): plan B4.3 gives the
  `m7b-liftio-slot.tot` header verbatim, and that verbatim text does
  not name the Ratification amendment of 2026-09-04.  Plan B4.2 and
  the B6 checklist item 11 both require the retirement sentence to
  name the amendment in all three places: the fixture header, the
  `dev/gates.sh` block comment, and the SPEC.md entry.  The repo
  proves the verbatim fixture text insufficient for item 11 by
  inspection, not by opinion: `rg -n 'Ratification' <the three files>`
  found the phrase only in `dev/gates.sh` and would have found it
  nowhere in the fixture, had the header stayed as given.  Resolution:
  the fixture header's second sentence gained the parenthetical
  `(Ratification amendment of 2026-09-04)`, which does not change the
  fixture's exit code, its single stdout line, or its line count in a
  way that affects any pinned column (the file is a positive control
  that exits 0, so no error line or column depends on the header's
  byte count).  The `dev/gates.sh` block comment stays byte-identical
  to the plan's B5.1 verbatim text (that block's bytes win per the
  build brief), so its wording reads "Ratification amendment
  2026-09-04" without "of", split across two comment lines; the
  fixture header and the SPEC.md entry both read "Ratification
  amendment of 2026-09-04".  All three name the amendment and the
  Stage A measurement, and none of them says that the settle falls
  outside M7 (a sweep for that claim over all three finds nothing),
  which is the substantive property item 11 pins.  Full byte identity
  across all three was not attempted, because the plan pins the
  `dev/gates.sh` block's bytes verbatim and the fixture header and the
  SPEC.md entry serve different prose shapes (a file header, a script
  comment, a decision-log entry).

  SUPERSEDED by conflict note C-B3 (2026-09-04) in the review-round
  subsection below.  The review round holds the three retirement
  sentences to the literal reading of item 11, and they now read the
  same.

### 6. Mutation proofs

Six mutation proofs run, each restored, each `md5 -q` identical before
and after.  Full rows in
`/Users/oobi/Documents/tot-m7-stageB-mutations.log`.

(a) `examples/guard.tot:134` reverted to HEAD's own spelling,
`  let* (Option Json) _ parsed := liftIO _ (jsonParse raw) in`.  Both
`PASS-M6E-GUARD-HOLES` and `PASS-M7B-GUARD-ARG-HOLES` flip red, each
with `holed=25`, not 26 (the fourth A slot is explicit again, so the
corpus count drops by one).  The two observed lines are
`FAIL-M6E-GUARD-HOLES (c=0/0/0 holes=25 pz=1 env=2)` and
`FAIL-M7B-GUARD-ARG-HOLES (c=0/0 slots=3 holed=25 env=2)`.  That is
the plan B6 item 10(a) prediction of `slots=3 holed=25`.  Both guards
still check at exit 0, so this leg bites on the SITE count alone,
which is what the row exists to prove.  `md5 -q` before and after:
`876d62cb35ae31e8650e3b1cf732de79`.  The first pass of this row
applied a different edit and is corrected by conflict note C-B2 in the
review-round subsection below.

(b) `examples/guard.tot:133` reverted to `String`.  Both
`PASS-M7B-GUARD-ARG-HOLES` (`slots=3 holed=25`) and
`PASS-M6E-GUARD-HOLES` (`holes=25`) flip red.  Both `guard.tot` checks
still exit 0 (`c=0/0`); the deny-payload env probe reads exit 2, which
does not match the `wantenv` comparison, so both markers still read
FAIL on the same AND chain.  M7-PLAN.md:3222-3224's older text says
"every other leg green" for this mutation; this run's own task text
already predicted `PASS-M6E-GUARD-HOLES` red as well, and that is what
happened.  The difference from the older plan text is confined to
this one leg (`PASS-M6E-GUARD-HOLES`); recorded here as a note, not a
defect.  `md5 -q` before and after:
`876d62cb35ae31e8650e3b1cf732de79`.

(c) `test/fixtures/m7/m7b-arg-slot-undetermined.tot`'s value re-spelled
to `liftIO _ (jsonParse "{}")`.  `PASS-M7B-LIFTIO-SLOT-CLOSES` flips
red with `c=0/0/0`: the settle now fills the slot, so the retired
negative checks at exit 0 like the two positives, and the leg's third
AND-chain assertion (the negative's exit code and message) fails.
`md5 -q` before and after: `9cc6feaaaa7a18e6d6bb3c21ba2d5bd3`.

(d) One row per suite case, each mutated by changing the expected line
inside the case in `test/surface.ml`, never the source string, then
restored:

- M7B-1 (`m7b_guard_arg_slots`): expected line changed to
  `def probeGuardBoth : WRONG`.  Observed: `FAIL M7B-1
  m7b_guard_arg_slots: ...` / `got  [def probeGuardBoth : (IO
  Verdict)]` / `want [def probeGuardBoth : WRONG]`.
- M7B-2 (`m7b_liftio_slot`): expected line changed to
  `def probeGuardLift : WRONG`.  Observed: `FAIL M7B-2
  m7b_liftio_slot: ...` / `got  [def probeGuardLift : (IO Verdict)]` /
  `want [def probeGuardLift : WRONG]`.
- M7B-3 (`m7b_arg_slot_undetermined`): expected line changed to
  `2:8: hole: WRONG`.  Observed: `FAIL M7B-3
  m7b_arg_slot_undetermined: ...` / `expected [2:8: hole: WRONG], got
  [2:8: hole: expected Type 0]`.

`md5 -q` on `test/surface.ml` before and after each of the three:
`f14e5f89e969478a6cc7127eb1e61b07`.

(e) The `PASS-M5D-TIERS` literal.  `dev/gates.sh`'s assertion changed
from `-eq 211` to `-eq 210`.  Observed: `FAIL-M5D-TIERS (nolit=1
tiers=211 bites=2)` (the true corpus count stays 211; the assertion no
longer matches it).  `md5 -q` on `dev/gates.sh` before and after:
`18a11122f03ebecb985a8c1a4b7d2d47`.

No unkilled leg.  Every mutation flipped its own marker by the
predicted route.

A full battery run after every mutation was reverted: `GATE-EXIT=0`,
true `FAIL=0` (the wrapper's own `PASS=399` line double-counts the
tail-3 preview and the M7B suite preview lines the same way earlier
Stage B runs did; true totals: markers 156, kernel 105, surface 134,
total PASS 395).  `git status --porcelain -uall` read the same nine
paths before the mutation stage and after it.

### 7. Exit criteria (plan B6 checklist) walked

1. `dune build` green; full battery
   (`/Users/oobi/Documents/tot-m7-stageB-gate.log`): `GATE-EXIT=0`; the
   wrapper's own `PASS=399` line again double-counts the `tail -3`
   preview (four lines) plus, this run, the two preview-included M7B
   suite lines, so the true totals are: markers 156 (`rg -c '^PASS-'`
   on the gate log), kernel 105, surface 134, total PASS 395; true
   `FAIL` 0 (the log's lone `^FAIL` hit is the `FAIL=` summary line
   itself, printed empty).  Green.
2. `git status --porcelain` (post-edit) shows exactly the nine B3
   paths: six ` M` (`SPEC.md`, `dev/M7-BUILD-LOG.md`, `dev/gates.sh`,
   `examples/guard-rewrap.tot`, `examples/guard.tot`, `test/surface.ml`)
   and one `??` (`test/fixtures/m7/`, the directory that holds the
   three new fixtures; `-uall` lists them one per line).  No path under
   `lib/`, `surface/` or `bin/` appears.  Section 8 below carries the
   same six-plus-one shape.
3. `awk 'NR==133 || NR==134' examples/guard.tot` and `awk 'NR==264 ||
   NR==265' examples/guard-rewrap.tot` both print `  let* _ _ raw :=
   readStdin in` and `  let* _ _ parsed := liftIO _ (jsonParse raw)
   in`.  Green.
4. `python3 dev/hole-anchors.py | rg -c 'anchor=\[_\]'` = 26.
   `python3 dev/hole-anchors.py | tail -1` =
   `ANCHORS total=101 expected-type-only=62 argument-driven=9
   neither=30`, unchanged.  Green.
5. `ls examples/*.tot test/fixtures/*.tot | wc -l` = 101 still (the
   three new fixtures sit under `test/fixtures/m7/`, a subdirectory the
   glob does not enter).  `rg -c '^### ' dev/m5e-default-transcript.txt`
   = 101 still.  `md5 -q dev/m5e-default-transcript.txt` unchanged at
   `e0943042fd0ef721b54e26f975fa2f03`; no reseal.  Green.
6. `tot.exe check examples/guard.tot | wc -l` = 10; last line `def
   main : (IO Verdict)`, unchanged from HEAD.  Green.
7. Both new markers appear exactly once as an `echo PASS-...` line;
   `rg -c 'PASS-M7B' dev/gates.sh` = 4 (two echoes, two comment
   mentions).  `rg -c 'PASS-M7B-ARG-SLOT-EXPLICIT' dev/gates.sh` finds
   nothing. Green.
8. The surface suite grew by exactly three PASS lines (M7B-1, M7B-2,
   M7B-3); kernel suite count (105) did not move. Green.
9. `PASS-M5D-TIERS` is green in the exit battery (present in the gate
   log); both measured tier numbers (205, 211) are recorded above in
   section 2. `PASS-M5D-MEASURE-LOG` is green with no literal change.
   Green.
11. The retirement sentence for pin 6 reads the same in all three
    places (fixture header, `dev/gates.sh` block comment, SPEC.md
    entry), names the Ratification amendment, and none of the three
    says that the settle falls outside M7.  The review round replaced
    the two divergent prose forms with the plan-pinned `dev/gates.sh`
    sentence; see conflict notes C-B1 (superseded) and C-B3. Green.

Item 10 (mutation proofs) is the mutation stage's; item 12 (the user
commits) is the user's.

### 8. Porcelain and gate tails

`git -C /Users/oobi/Documents/tot status --porcelain` with this log
saved.  The log is one of the nine B3 paths, so it carries its own
` M` line:

```
 M SPEC.md
 M dev/M7-BUILD-LOG.md
 M dev/gates.sh
 M examples/guard-rewrap.tot
 M examples/guard.tot
 M test/surface.ml
?? test/fixtures/m7/
```

`-uall` expands the one `??` directory line into the three fixture
paths: `test/fixtures/m7/m7b-arg-slot-undetermined.tot`,
`test/fixtures/m7/m7b-guard-arg-slots.tot` and
`test/fixtures/m7/m7b-liftio-slot.tot`.

Final battery tail (`/Users/oobi/Documents/tot-m7-stageB-gate.log`):

```
PASS-M7A-INFER-SETTLE-BUDGET
PASS-M7B-GUARD-ARG-HOLES
PASS-M7B-LIFTIO-SLOT-CLOSES
PASS-M4FIX-INST-BRANCHING
PASS-M5B-BRANCHING-20
GATE-LOG=/tmp/claude-501/tot-gate-measure.log
GATE-EXIT=0
PASS=399
FAIL=
DONE Fri  4 Sep 2026 11:01:58 PDT
```

Handoff to the mutation stage: chain stands at 395 (105 kernel + 134
surface + 156 markers); tiers literal 211; holed-anchor literal 26.
Three mutation proofs remain, per plan B6 item 10 and B4's mutation
list (revert `guard.tot:134` to `(Option Json)`; revert
`guard.tot:133` to `String`; re-spell
`m7b-arg-slot-undetermined.tot`'s value to `liftIO _ (jsonParse
"{}")`), each logged with source md5 before/after and the predicted
FAIL route.

### Review-round fixes (2026-09-04)

The Stage B review round raised five findings.  Each fix repairs the
cause.  No expectation was lowered.  Each note gives the observed text
or measurement before the fix and after it.

**Conflict note C-B2 (2026-09-04): mutation row (a) applied a
different edit from the one plan B6 item 10(a) names.**  Observed
before: `/Users/oobi/Documents/tot-m7-stageB-mutations.log` row (a)
recorded the mutation as
`  let* _ (Option Json) parsed := liftIO _ (jsonParse raw) in` and the
result as
`FAIL-M7B-GUARD-ARG-HOLES (c=1/0 slots=4 holed=25 env=1)`.  That
spelling holes the FIRST slot and makes the SECOND explicit, the
mirror image of HEAD's line 134,
`  let* (Option Json) _ parsed := liftIO _ (jsonParse raw) in`
(`git show 37c0bb2:examples/guard.tot`).  Because slot `arg=0` stayed
a hole, the SITE count stayed at 4 and never dropped to the 3 that
plan M7-PLAN.md:3218-3221 predicts, so the row did not exercise the
assertion it exists to prove.  The edit also drove `guard.tot` to a
type mismatch (`c=1`), not to a count flip.  Cause: the mutation
script wrote the two slot positions in the wrong order.  Fix: row (a)
was re-run with HEAD's own spelling.  The runner is
`/Users/oobi/Documents/tot-m7-probes/stageB/rowa-rerun.sh`.  Observed
after, on 2026-09-04:

```
--- BEFORE (unmutated Stage B tree) ---
PASS-M6E-GUARD-HOLES
PASS-M7B-GUARD-ARG-HOLES
--- MUTATION (a): guard.tot:134 back to the true HEAD spelling ---
  let* _ _ raw := readStdin in
  let* (Option Json) _ parsed := liftIO _ (jsonParse raw) in
FAIL-M6E-GUARD-HOLES (c=0/0/0 holes=25 pz=1 env=2)
FAIL-M7B-GUARD-ARG-HOLES (c=0/0 slots=3 holed=25 env=2)
--- RESTORE ---
ROWA-MD5-BEFORE=876d62cb35ae31e8650e3b1cf732de79
ROWA-MD5-AFTER=876d62cb35ae31e8650e3b1cf732de79
RESTORE-IDENTICAL
```

`slots=3 holed=25` is the plan's prediction exactly.  Both guards
still check at exit 0, so the leg bites on the site count and not on a
build error.  Section 6 (a) above now carries this run.  The
mutations log row (a) and its NOTE a were replaced with the same
text.  The gate leg itself was never at fault: only the recorded proof
was.

**Conflict note C-B3 (2026-09-04): the three retirement sentences did
not read the same, which plan B6 item 11 requires.**  Observed before:
three prose forms of one claim, no two alike.  The fixture header read
"Stage A's infer settle reaches it (Ratification amendment of
2026-09-04), so the negative is RETIRED".  The `dev/gates.sh` block
comment read "Stage A's infer settle elaborates that argument, so the
recorded reason is no longer true and the two negatives are RETIRED
(Ratification amendment 2026-09-04: a slot stays a negative only with
a true reason)".  The SPEC.md entry read "Under the Ratification
amendment of 2026-09-04, a slot stays a negative only with a true
reason, so both halves of pin 6's negative retire."  C-B1 declined
byte identity and read item 11 for its substance.  The review round
holds item 11 to its literal words.  Cause: two of the three places
were written in their own voice instead of the plan's.  Fix: the
`dev/gates.sh` sentence is the plan-pinned one (plan B5.1, verbatim),
so it stays and the other two adopt it.  Observed after, the same
sentence in all three places, modulo the line wrapping and the comment
marker each file needs:

```
Stage A's infer settle elaborates that argument, so the recorded
reason is no longer true and the two negatives are RETIRED
(Ratification amendment 2026-09-04: a slot stays a negative only with
a true reason).
```

Each of the three now carries the antecedent sentence too, so "that
argument" resolves in place: the informative later argument is itself
the holed `liftIO _ (...)` which `surface/elab.ml:287-291` refuses at
the infer entry.  The check is
`/Users/oobi/Documents/tot-m7-probes/stageB/item11.sh`, which strips
the comment markers and collapses the runs of blanks, then compares
the three.  The amendment keeps the plan's own spelling, "Ratification
amendment 2026-09-04" without "of", in all three places.  Item 11 asks
the sentence to name the amendment, and this spelling names it.  The
fixture header grew by four lines.  No assertion depends on that
file's line numbers: `m7b-liftio-slot.tot` exits 0 and the gate pins
only its one stdout line, `def main : (IO Verdict)`.  The surface
suite case M7B-2 uses its own inline source, not the file.
`dev/hole-anchors.py` excludes test fixtures (its lines 13-15), so no
anchor count moves.

**Conflict note C-B4 (2026-09-04): a blunt sweep for the banned
M7-scope phrase over the nine B3 paths returned three hits.**  Plan B6
item 11 bans one claim: that the settle falls outside M7.  A reviewer
ran the blunt form of that sweep, four words with no subject, over the
nine paths.  Observed before: three hits, all in this log, at lines
765, 1022 and 1144.  None of the three made the banned claim.  Line
765 was about a dependent instantiation at a branch pattern, line 1022
quoted the narrow sweep itself inside C-B1, and line 1144 said that no
file makes the claim.  The narrow sweep, the one with the subject,
matched only the C-B1 self-quote.  Cause: the log used the banned
words to talk about the ban, so the blunt sweep read its own prose as
a hit.  Fix: the three places were reworded, so the blunt sweep and
the narrow one now agree.  Observed after: line 765 reads "which is
kernel work and sits outside M7 scope", the C-B1 sentence reads "none
of them says that the settle falls outside M7 (a sweep for that claim
over all three finds nothing)", and the item 11 line reads "none of
the three says that the settle falls outside M7".  Both sweeps over
the nine B3 paths now find nothing outside this note, which names the
phrase only by description.

**Conflict note C-B5 (2026-09-04): the section 8 porcelain block
omitted this log and undercounted the modified paths.**  Observed
before: the fenced block listed five ` M` lines plus one `??` line,
and `dev/M7-BUILD-LOG.md` was absent, while the live
`git status --porcelain` returned six ` M` entries.  Section 7 item 2
said "five ` M`" and hedged the gap in prose with "plus this log
itself once saved".  The pasted block is the artifact a reviewer
diffs, and it carried no such hedge.  Cause: the block was pasted
before the log was saved.  Fix: the block was re-pasted from a run
that counts this log, and the block now says so.  Section 7 item 2
now reads "six ` M`" and names `dev/M7-BUILD-LOG.md`.  Observed after:
the six ` M` lines are `SPEC.md`, `dev/M7-BUILD-LOG.md`,
`dev/gates.sh`, `examples/guard-rewrap.tot`, `examples/guard.tot` and
`test/surface.ml`, and the one `??` line is `test/fixtures/m7/`, which
`-uall` expands to the three fixture paths.

**Conflict note C-B6 (2026-09-04): "exits 1 at HEAD" named the wrong
commit.**  Observed before: `dev/gates.sh` read "Measured at HEAD
before the stage: each slot alone, re-spelled in its own file, exits 1
at `134:8` and `265:8`".  The fixture header of
`m7b-guard-arg-slots.tot` read "This file exits 1 at HEAD", and the
header of `m7b-liftio-slot.tot` read "exit 1 at HEAD, exit 0 after the
stage".  Stage B lands on 37c0bb2, where Stage A is already built, and
at 37c0bb2 those shapes exit 0.  The refusal belongs to 66b444f, which
is the commit plan B2:2685 names for its own probe binary.  Cause: the
plan wrote those bytes at 66b444f and this stage copied them onto a
later tree.  This is a deviation from plan B4.3 and plan B5.1
verbatim text, taken under the section 5 protocol, because the plan's
own B2 attribution rules the sentence false on the tree it lands on.
Fix: each place names its commit.  Observed after, `dev/gates.sh`:
"Measured at 66b444f, before Stage A: each slot alone, re-spelled in
its own file, exits 1 at `134:8` and `265:8` with `hole: expected
Type 0` (plan B2 P4, P6).  At 37c0bb2, the commit this stage lands on,
the settle closes all four slots."  `m7b-guard-arg-slots.tot`: "This
file exits 1 at 66b444f, before Stage A, and exits 0 at 37c0bb2, the
commit this stage lands on."  `m7b-liftio-slot.tot`: "This file
records the flip: exit 1 at 66b444f, before Stage A, and exit 0 at
37c0bb2."  `m7b-arg-slot-undetermined.tot` keeps "Exit 1 at HEAD and
exit 1 after the stage": that file exits 1 at 37c0bb2 and exits 1
after the stage, so its sentence is true as written.  The edits touch
comment bytes only.  The two positives report no position now, because
they exit 0, so plan B4.3's "the header lengths fix the reported
positions" binds only the negative fixture, whose header is unchanged
at five lines and whose pinned position stays `7:8`.

**Review-round re-measures and the exit battery.**  Every fix above
edits comment bytes, prose or fixture headers.  None adds or removes a
watchdog tier line, so `PASS-M5D-TIERS` does not move:
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` printed
211 before the review round and 211 after it, and the assertion at
`dev/gates.sh:2298` keeps its literal of 211.  `zsh -n dev/gates.sh`
exits 0.  `rg -c` for the em-dash character finds none in any of the
nine paths.  The B6 checklist was walked again after the fixes:
`awk 'NR==133 || NR==134' examples/guard.tot` and the rewrap pair
still print the two holed lines (item 3); holed anchors 26 and
`ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30`
(item 4); 101 and 101 (item 5); `tot.exe check examples/guard.tot`
prints 10 lines ending `def main : (IO Verdict)` (item 6);
`rg -c 'PASS-M7B' dev/gates.sh` = 4 and the retired name lands nowhere
(item 7); surface 134 and kernel 105 (item 8);
`/Users/oobi/Documents/tot-m7-probes/stageB/item11.py` prints
`ITEM11-SAME=yes` (item 11).  The three fixtures still read exit 0,
exit 0 and exit 1 with `:7:8: hole: expected Type 0`.

Exit battery after the review round
(`/Users/oobi/Documents/tot-m7-stageB-review-gate.log`):

```
PASS-M7A-INFER-SETTLE-BUDGET
PASS-M7B-GUARD-ARG-HOLES
PASS-M7B-LIFTIO-SLOT-CLOSES
PASS-M4FIX-INST-BRANCHING
PASS-M5B-BRANCHING-20
GATE-LOG=/tmp/claude-501/tot-gate-measure.log
GATE-EXIT=0
PASS=399
FAIL=
DONE Fri  4 Sep 2026 11:52:58 PDT
```

The wrapper's `PASS=399` line double-counts the preview lines, as
conflict note C-A14 records.  The true totals are unchanged: markers
156 (`rg -c '^PASS-'` on the gate log), kernel 105, surface 134, total
PASS 395.  The log's one `^FAIL` hit is the empty `FAIL=` summary
line, so the true FAIL count is 0.  No load artefact: the wrapper
printed no `LOAD-RED` line.

## Stage C (2026-09-04): multi-hole tail reporting, the position-only tail recorded inside the parse walk (pins 7, 8)

Plan: `dev/M7-PLAN.md` C0-C12 (lines 3271-4199).  Chain: 395 -> 402
(+2 markers, +5 surface tests).

### 1.  Entry state

- `git log -1 --oneline`: `71edbc8` (Stage A and Stage B committed);
  tree not clean.  `git status --porcelain -uall` showed a PARTIAL
  Stage C attempt already in the tree: `surface/parser.ml`,
  `surface/run.ml`, `bin/tot.ml`, `test/surface.ml` and the
  `dev/gates.sh` M7C block (the two legs, no trap edit, no tiers move)
  edited, plus the three `dev/fixtures/m7c-*.tot` files, all matching
  plan C4-C9 byte for byte on inspection (state-handling rule: keep
  what matches, redo what does not).  `SPEC.md` and this build log were
  untouched.  This section reports the state AS FOUND, then the work
  this pass completed: the `dev/gates.sh:434` trap edit, the
  `PASS-M5D-TIERS` literal move, the two `SPEC.md` edits and this log.
- Because the parser, run and driver edits pre-date this pass, C1's
  entry probes are read against the FIXTURE bytes and against the
  Stage B (unedited) parts of `dev/gates.sh` and `SPEC.md`, not
  against a from-scratch pre-edit binary.  `git show 71edbc8:dev/gates.sh`
  line 434 carries no `m7c_scratch`, and
  `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"'` on that blob prints
  211, confirming the literal had not yet moved.  `SPEC.md` at 71edbc8
  and at entry both print `expected-type-only=` six times, the last at
  SPEC.md:2158 (a line that shifts only with inserted lines above it).
- `dune build` at entry (with the partial edits already in place):
  green, 0 errors, 0 warnings.
- Fixture md5s at entry, already matching the C7 map:
  `af86fd51bd955c9a020a81b8f2c291f6` (427 bytes) m7c-multi-hole.tot,
  `dbc10e01f45d55c5796f971b187a6f4d` (273 bytes)
  m7c-multi-hole-explicit.tot, `cf0c418bb281afb2509afa388b6af4fa`
  (265 bytes) m7c-backtrack.tot.
- `rg -c 'holes :=' surface/parser.ml` = 3 (the arm, the rollback, the
  reset), matching C11 item 8.
- P8 re-measure with the built binary, `fd -d 1 -e tot` over
  `examples/` and `test/fixtures/` (top level only), filtered to files
  whose check stderr carries `hole:`: 8 files, not the plan's 9
  (`m6c-underscore-lam`, `m6c-hole-n-class`, `m6h-hole-n-fence-class`,
  `m6c-hole-run`, `m6c-underscore-match`, `m6c-hole-n-proof`,
  `m6h-hole-n-fence-proof`, `m6c-hole-n-infer`).  `m6c-hole-a.tot` is
  absent from the list because Stage A re-pointed it to green, exactly
  as the plan's own P8 note predicts ("Stage A re-pointed
  test/fixtures/m6c-hole-a.tot to green ... so the list may differ
  from nine").  This is not a conflict.  Every one of the 8 files has
  exactly ONE term-position hole in its failing item, read by eye:
  `fun _ => _` and `succ _ ... => _` each contribute one BINDER `_`
  (consumed by `collect_idents`) and one term hole;  every other file
  has one bare `_`.  No file has two or more term-position holes in
  its failing item, so pin 4's transcript reseal is not spent here.

### 2.  What changed

- `surface/parser.ml`: a module-level `holes : Loc.t list ref`
  (plan fence 3500-3511);  the `Underscore` arm of `parse_atom` records
  the position (3515-3525);  `try_binder_group` renamed to
  `binder_group_attempt` with its body unchanged, and a new
  `try_binder_group` wraps it with a transactional rollback
  (3538-3554);  `with_item_holes` resets the record per item and pairs
  the item with its positions, oldest first (3560-3568);  `parse_items`
  carries `(Syntax.item * Loc.t list) list` through all eight item arms
  (3573-3589);  `parse_with_holes` is the new export, and `parse`
  becomes its projection (3595-3604).  `term_only` is unchanged.
- `surface/run.ml`: `reported_hole` (all ten `Serror.t` constructors,
  no catch-all), `loc_order`, `loc_equal`, `hole_tail` (no dedup, the
  sort is defensive) and `script_tailed`, which threads the tail
  beside the error through one `Result.map_error` per fold step.
  `script` keeps its signature and becomes
  `Result.map_error fst` of `script_tailed`.
- `bin/tot.ml`: `run_file` calls `Run.script_tailed`;  the `~error`
  binder destructures `(e, tail)`;  the last arm prints `tail` with
  `Option.iter prerr_endline` after the M6 line and before
  `serror_exit`.  The three earlier arms and the prelude-load arm
  (`bin/tot.ml:171-173`, `Run.script`) are unchanged: the prelude path
  reports an internal error with no user-facing tail, so it has no
  reason to move to `script_tailed`.
- `dev/fixtures/m7c-multi-hole.tot`, `m7c-multi-hole-explicit.tot`,
  `m7c-backtrack.tot` (all NEW, plan C7 bytes, md5s in section 1).
- `test/surface.ml`: the `m7c_expect_tail` helper next to
  `m6c_expect_err_line`, and five cases (M7C-1..M7C-5) after M7B-3.
- `dev/gates.sh`: the M7C block (header, `m7c_scratch` mktemp, leg (i)
  `PASS-M7C-MULTI-HOLE-TAIL`, leg (ii) `PASS-M7C-SINGLE-HOLE-UNCHANGED`)
  inserted after the M7B block's last line and before the `ctxcat id 5`
  comment, one blank line on each side;  `"$m7c_scratch"` added to the
  EXIT trap at line 434;  the `PASS-M5D-TIERS` literal moved 211 -> 218
  with a dated sentence recording both numbers.  Repair round 1 added
  the three pin 7 assertion edits the C-C1 ruling authorises, in
  `PASS-M6C-HOLE-REPORTS`, `PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE` and
  `PASS-M7B-LIFTIO-SLOT-CLOSES` (section 5).
- `SPEC.md`: clause (3) rewritten to name the tail;  one dated entry
  appended to the section 2 decision log, after the Stage B entry and
  before the `## 3.` heading.
- Untouched (verified with `git diff --stat`, empty for the list):
  `surface/serror.ml`, `surface/syntax.ml`, `surface/elab.ml`,
  `surface/bootstrap.ml`, `surface/cache.ml`, `lib/`,
  `stdlib/prelude.tot`, `examples/`, `test/fixtures/`,
  `dev/gen-m5e-transcript.sh`, `dev/m5e-default-transcript.txt`,
  `dev/hole-anchors.py`.

Fixture outputs (built binary, `tot check` unless noted; pinned by
Gate C9 and the suite):

```
m7c-multi-hole.tot:7:14: hole: no expected type at this position
2 more hole(s) at 7:24, 7:38                                      exit 1
m7c-multi-hole-explicit.tot (exit 0):
def flagged : (List String)
def h : (List String)
m7c-backtrack.tot:5:14: hole: no expected type at this position
1 more hole(s) at 5:31                                            exit 1
run mode and --serror-exit 0 on m7c-multi-hole.tot: same two lines,
exit 1 and exit 0
test/fixtures/m6c-hole-n-infer.tot:1:6: hole: no expected type at this
position                                                          exit 1, ONE line
test/fixtures/m6c-hole-n-proof.tot:1:38: hole: expected Type 0       exit 1, ONE line
```

### 3.  Tests added (surface suite 134 -> 139)

Five cases appended to `cases` after M7B-3, all through the new
`m7c_expect_tail` helper over `Run.script_tailed`: M7C-1
`m7c_tail_reports` (three-hole source, tail
`Some "2 more hole(s) at 1:24, 1:38"`), M7C-2 `m7c_tail_single`
(one-hole source, tail `None`), M7C-3 `m7c_tail_scoped` (an earlier
green item's holes never appear), M7C-4 `m7c_tail_non_hole` (an
`unknown name` error carries no tail even though its item holds a
hole), M7C-5 `m7c_tail_backtrack` (the rollback keeps the backtracked
position out of the tail exactly once).  `dune exec test/surface.exe`:
`rg -c '^PASS'` = 139;  `rg -c '^PASS M7C-'` = 5.  Kernel suite
unchanged: `dune exec test/main.exe | rg -c '^PASS'` = 105.

### 4.  Gate markers added (156 -> 158)

`PASS-M7C-MULTI-HOLE-TAIL`, `PASS-M7C-SINGLE-HOLE-UNCHANGED`.
`rg -c 'echo PASS-M7C-' dev/gates.sh` = 2.  Tiers:
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` = 218
(211 + 7: the two legs' seven direct FAST uses).  Loop-free: the block
has no `for`/`while`;  `set -u` remains absent.  The gates.sh block
was proved byte-identical to the plan's own concatenation
(header 3959-3966, leg (i) 4012-4055, leg (ii) 4059-4079, one blank
line between each and around the whole) with
`diff` against an `awk` extraction of both the plan and the tree; the
only difference is the required trailing blank line before the
`ctxcat id 5` comment.  Repair round 1 added three assertion edits to
EARLIER legs under the C-C1 ruling (section 5).  Those edits add no
marker, delete no leg and add no watchdog use, so the marker count
stays 158 and the tiers literal stays 218, both re-measured after the
round.

### 5.  Conflicts (section 5 protocol)

The P8 file count (8, not 9) is not a conflict: the plan's own C1 P8
paragraph names the reason (Stage A re-pointed `m6c-hole-a.tot` to
green) and predicts the list "may differ from nine".

**Conflict note C-C1 (2026-09-04): pin 7's tail collides with the
pre-existing `PASS-M6C-HOLE-REPORTS` leg's one-line assertion on
`dev/m7a/arg-exhausted.tot`.**  That leg (`dev/gates.sh:2682-2721`,
unedited by this stage) checks four fixtures and asserts `wc -l` of
each stderr equals 1.  `dev/m7a/arg-exhausted.tot`, crafted by Stage A
to have "every later argument itself a hole" (comment at
`dev/gates.sh:2686-2693`), holds THREE term-position holes in its one
item (`2:8`, `2:35`, `2:37`).  Under pin 7 the parse walk now reports
all three, so `tot.exe check dev/m7a/arg-exhausted.tot` prints
`2:8: hole: expected Type 0` and a second line
`2 more hole(s) at 2:35, 2:37`, and leg (a)'s `wc -l == 1` assertion
fails.  Re-run against the built binary, 2026-09-04 (this pass):
confirmed, two lines, `FAIL-M6C-HOLE-REPORTS (exit=1/1/1/1)`,
`GATE-EXIT=1` at `PASS=377 FAIL=1`, before any `PASS-M7A-*`,
`PASS-M7B-*` or `PASS-M7C-*` marker runs (M6C precedes M7 in file
order).  The plan's own P8 corpus check (`dev/M7-PLAN.md` C1, step 1
of this stage's instructions) is scoped to the transcript glob
(`examples/*.tot`, `test/fixtures/*.tot` top level only) and does not
cover `dev/m7a/*.tot`, so this file was never inventoried against the
"two or more term-position holes" rule before Stage A created it,
after the plan was frozen.  The OTHER site that reads this fixture
(`dev/gates.sh:3276-3291`, the `PASS-M7A-ARGHOLE-*` leg) uses `rg -q`
substring matching, not a line count, so it is unaffected and still
passes with the extra line present.
Resolution per section 5 point 4: pin 7's design is not impossible and
is not changed;  the STALE leg is what needs an edit (either re-point
leg (a) to a one-hole fixture, the way Stage A re-pointed it away from
`m6c-hole-a.tot`, or relax its line-count assertion to accept the
tail).  That edit is OUTSIDE Stage C's authorized file list: Stage C
may add only the one `dev/gates.sh` block and the two named literal
edits (the trap, `PASS-M5D-TIERS`), and `dev/m7a/` is not one of
Stage C's three named new fixtures.  This stage does NOT edit
`dev/m7a/arg-exhausted.tot` or the `PASS-M6C-HOLE-REPORTS` leg, and
reports the conflict as a blocker instead, per the state-handling and
conflict-resolution rules.  Every other measured count, byte and
placement in this stage matched the plan text.  (The two sentences
above record the FIRST pass only.  The orchestrator ruling of
2026-09-04 widened the touch list;  see the C-C1 resolution below.)

**C-C1 resolution (2026-09-04, repair round 1).**  The orchestrator
ruled that pin 7 is the intended behaviour and that the stale legs move
to the pin 7 shape.  Five fixtures hold more than one term-position
hole in ONE item, so five files print the position-only tail as their
SECOND stderr line: `dev/fixtures/m7c-multi-hole.tot` and
`dev/fixtures/m7c-backtrack.tot` (Stage C, already pinned by the M7C
block), `dev/m7a/arg-exhausted.tot` and `dev/m7a/infer-undetermined.tot`
(Stage A), and `test/fixtures/m7/m7b-arg-slot-undetermined.tot`
(Stage B).  The last three sit outside the transcript glob, so the
transcript stays byte-identical (md5
`e0943042fd0ef721b54e26f975fa2f03`, re-measured after this round), but
their gate output DOES move.  The ruling authorised one extra edit
class in `dev/gates.sh`: each leg whose assertion on one of those five
files needs exactly one stderr line, or compares the whole captured
output with the one pinned line, moves to two lines, line 1 unchanged
and line 2 pinned byte for byte to the tail the binary prints.  The
tails were READ from the built binary, never guessed:
`./_build/default/bin/tot.exe check <fixture> 2> err.txt`.  No fixture,
no `surface/` file and no `bin/` file was edited for this resolution.
Leg names, markers, exit-code checks, stdout checks and the untouched
sub-legs did not move.  Three legs qualified.

1.  `PASS-M6C-HOLE-REPORTS`, sub-leg (a), on
    `dev/m7a/arg-exhausted.tot` (`dev/gates.sh` near 2694-2730 after
    the edit).  Assertion before:
    `[ "$(wc -l < "$m6c_scratch"/a.err)" -eq 1 ]`.  Assertion after:
    the same test with `-eq 2`, plus one new line
    `[ "$(awk 'NR==2' "$m6c_scratch"/a.err)" = '2 more hole(s) at 2:35, 2:37' ]`.
    The pinned pin-3 line 1 `rg -q` test is unchanged.  Observed
    before: `FAIL-M6C-HOLE-REPORTS (exit=1/1/1/1)`, a.err two lines.
    Observed after: `PASS-M6C-HOLE-REPORTS` in the battery log.
2.  `PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE`, the `nc.err` sub-leg, on
    `dev/m7a/infer-undetermined.tot` (two holes in one item, 1:14 and
    1:16).  Assertion before:
    `[ "$(wc -l < "$m7a_scratch"/nc.err)" -eq 1 ]`.  Assertion after:
    `-eq 2`, plus
    `[ "$(awk 'NR==2' "$m7a_scratch"/nc.err)" = '1 more hole(s) at 1:16' ]`.
    The `na.err` and `nb.err` sub-legs keep one line each.  Observed
    before: the first battery stopped at M6C and never reached this
    leg;  by hand the leg was red, nc.err two lines.  Observed after:
    `PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE` in the battery log.
3.  `PASS-M7B-LIFTIO-SLOT-CLOSES`, the negative on
    `test/fixtures/m7/m7b-arg-slot-undetermined.tot` (three holes in
    one item, 7:8, 7:35, 7:37).  That leg compares the WHOLE captured
    output with `$m7b_wn`.  Before, `m7b_wn` held one line,
    `$ROOT/test/fixtures/m7/m7b-arg-slot-undetermined.tot:7:8: hole: expected Type 0`.
    After, it holds that line and a second line
    `2 more hole(s) at 7:35, 7:37`.  Observed before: not reached by
    the first battery;  by hand the compare was red.  Observed after:
    `PASS-M7B-LIFTIO-SLOT-CLOSES` in the battery log.

Each of the three legs carries a dated comment that starts
`# M7 Stage C (pin 7, C-C1):` and states what moved and why.

Legs that read the same five fixtures and did NOT move, with the
reason: `PASS-M7A-ARGHOLE-RESOLVES` (`dev/gates.sh` near 3286-3300)
matches with `rg -q` on a line pattern, so the extra line does not
disturb it;  `PASS-M7A-INFER-SETTLE` and
`PASS-M7A-INFER-SETTLE-BUDGET` match with `rg -q` and `rg -qx` through
a pipe, which test one line at a time.  All three are green in the
battery log.  The 100-file conservativity digest is also at rest:
re-measured after this round, `files=100 green=61`, md5
`9b416b949964a50c4f7633eab478b5c2`, because `--max-depth 1` holds it to
`stdlib`, `examples` and `test/fixtures` at depth 1, and no file there
holds two term-position holes in one item.

Mutation rule under C-C1: because the tail is now pinned in earlier
legs as well, a mutation is KILLED when the battery goes red at ANY
marker.  The mutation stage records the FIRST `FAIL` marker of each
row;  a kill by `FAIL-M6C-HOLE-REPORTS` or by an M7A or M7B marker is a
kill, not a miss.

Battery line after this round:
`GATE-EXIT=0`, `PASS=406`, `FAIL=` (no `^FAIL` line in the log).

### 6.  Mutation proofs (plan C9 MUT-C1 to MUT-C5)

Full rows, each with the exact mutation, the observed flip and the
before/after md5, are in
`/Users/oobi/Documents/tot-m7-stageC-mutations.log`.  Every mutation
compiled and every restore is proved by an identical md5 pair.  Under
the C-C1 mutation rule, a kill is recorded at the FIRST `FAIL` marker;
all five source mutations killed at `FAIL-M7C-MULTI-HOLE-TAIL` or
`FAIL-M7C-SINGLE-HOLE-UNCHANGED`, so none needed the widened M6C/M7A/
M7B route.  Summary:

- MUT-C1 (`surface/run.ml:655`, drop the `List.filter` in
  `hole_tail`): leg (i) red, second stderr line
  `2 more hole(s) at 7:24, 7:38` -> `3 more hole(s) at 7:14, 7:24,
  7:38`, `FAIL-M7C-MULTI-HOLE-TAIL`.  Restore proved,
  md5 `daa8abb21f36d48ffab11379f901cd5f` before and after.
- MUT-C2 (`surface/parser.ml:343-352`, drop the rollback wrapper of
  `try_binder_group`): leg (i) red, `m7c-backtrack.tot`'s second line
  reads `2 more hole(s) at 5:31, 5:31`, `FAIL-M7C-MULTI-HOLE-TAIL`.
  Restore proved, md5 `653f1ada544ed6d363fc349950ca7615` before and
  after.
- MUT-C3 (`surface/parser.ml:428-431`, move the `holes := []` reset
  out of `with_item_holes`): leg (i) red, `m7c-multi-hole.tot`'s second
  line names the earlier item's positions, `4 more hole(s) at 6:35,
  6:49, 7:24, 7:38`, `FAIL-M7C-MULTI-HOLE-TAIL`.  Restore proved, md5
  `653f1ada544ed6d363fc349950ca7615` before and after.
- MUT-C4 (`surface/run.ml:656`, answer `Some "0 more hole(s) at "` for
  the empty tail): leg (ii) red, both one-hole fixtures gain a spurious
  second line, `FAIL-M7C-SINGLE-HOLE-UNCHANGED`.  Restore proved, md5
  `daa8abb21f36d48ffab11379f901cd5f` before and after.
- MUT-C5 (`bin/tot.ml:121`, guard the tail print behind `exec`): leg
  (i) red, the check-mode captures (`multi.err`, `se0.err`) drop to one
  line, `FAIL-M7C-MULTI-HOLE-TAIL`.  Restore proved, md5
  `c902e72b66732def7e6f4af36af4359d` before and after.

Suite-case rows (the expected literal moved inside the case, never the
source string), run with `dune exec test/surface.exe`: M7C-1 through
M7C-5 each print `FAIL M7C-<n> ...` with the mutated `want` literal
against the unmoved `got` value.  `test/surface.ml` md5
`e98211ecae2b8f1fe5945c6f94bd444f` before and after every case.

Two extra rows the plan's own text and pin 8 require:  (g) the
`PASS-M5D-TIERS` literal 218 -> 217 in `dev/gates.sh` prints
`FAIL-M5D-TIERS (nolit=1 tiers=218 bites=2)`;  (h) leg (i)'s pin 8
conjunct `-eq 10` -> `-eq 9` on `$m7c_sctors` prints
`FAIL-M7C-MULTI-HOLE-TAIL (exit=1/0/1/0/1 ctors=10/11)`, the printed
count mismatching the mutated expectation.  Both restored, md5
`0db41cb80aa127c1278fee85fb64dab9` before and after.

No unkilled leg.

### 7.  Exit criteria (plan C11) walked

1. `rg -n 'raise|failwith|assert' surface/parser.ml surface/run.ml bin/tot.ml`
   over the new code: no hit.
2. `reported_hole` lists all ten `Serror.t` constructors, no `_` arm;
   `parse_atom`'s arm list unchanged (confirmed by reading the diff).
3. No `match` on an `option` or a `result` in the new code: the
   helpers use `Option.bind`, `Option.iter`, `Option.value`,
   `Option.equal`, `Option.fold`, `Result.map`, `Result.map_error`,
   `Result.fold`;  the one `match` on a LIST in `hole_tail` is
   exhaustive (`[]` / `_ :: _`);  the two `match () with | () when ...`
   guards (`try_binder_group`'s rollback, `loc_order`) follow the house
   form.
4. No indexing and no division in the new code (checked by reading the
   diff and by `rg -n '/ '`, whose one hit predates this stage).
5. `surface/serror.ml`, `surface/syntax.ml`, `surface/elab.ml`
   untouched; `git diff --stat` names no file under `lib/`.
6. `Run.script`'s signature is unchanged;  the eighteen
   `Tot_surface.Run.script` sites in `test/surface.ml`,
   `surface/bootstrap.ml:384` and `test/surface.ml:588` compile
   untouched (`dune build` green).  The count is EIGHTEEN, measured
   here and not copied from the plan, which prints "seventeen"
   (`dev/M7-PLAN.md:4148-4150`).  Commands:
   `git show 71edbc8:test/surface.ml | rg -c 'Tot_surface\.Run\.script'`
   prints 18 at HEAD, and
   `rg -c 'Tot_surface\.Run\.script[^_]' test/surface.ml` prints 18 in
   the live tree, beside the one new `Run.script_tailed` call in the
   `m7c_expect_tail` helper.  See conflict note C-C3.
7. The tail line carries no path prefix, no expected type, no trailing
   space: confirmed against the fixture outputs in section 2.
8. `rg -n 'holes :=' surface/parser.ml` returns exactly three hits.
9. `dev/m5e-default-transcript.txt` byte-identical:
   `zsh dev/gen-m5e-transcript.sh > "$now.txt"; diff dev/m5e-default-transcript.txt "$now.txt"`
   exits 0;  md5 `e0943042fd0ef721b54e26f975fa2f03` before and after.
10. `python3 dev/hole-anchors.py | tail -1` still prints
    `ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30`.
11. Full battery: GREEN after repair round 1 (the C-C1 resolution in
    section 5).  The log reads `BUILD-EXIT=0`, `GATE-EXIT=0`,
    `PASS=406`, `FAIL=` and `DONE Fri  4 Sep 2026 13:26:16 PDT`.  The
    gate slice is 402;  the wrapper line reads 406 because the two
    suite tails add four `PASS` lines (conflict note C-A14).  The first
    pass of this stage was NOT green: `dev/gates.sh` died at the
    pre-existing `PASS-M6C-HOLE-REPORTS` leg (conflict C-C1) before any
    `PASS-M7A-*`, `PASS-M7B-*` or `PASS-M7C-*` marker ran.

### 8.  Porcelain and gate tails

`git status --porcelain -uall` at the end of repair round 1:

```
 M SPEC.md
 M bin/tot.ml
 M dev/M7-BUILD-LOG.md
 M dev/gates.sh
 M surface/parser.ml
 M surface/run.ml
 M test/surface.ml
?? dev/fixtures/m7c-backtrack.tot
?? dev/fixtures/m7c-multi-hole-explicit.tot
?? dev/fixtures/m7c-multi-hole.tot
```

Nothing is staged and nothing is committed.  No `git checkout`,
`git restore` or `git stash` ran on any path.

FIRST PASS (before the C-C1 resolution), for the record:
`BUILD-EXIT=0`, `FAIL-M6C-HOLE-REPORTS (exit=1/1/1/1)`, `GATE-EXIT=1`,
`PASS=377`, `FAIL=1`, and no `LOAD-RED` line, so that run was a tree
conflict and not a load artefact.  The script stopped in the M6C block,
which runs before every M7 block in file order, so no `PASS-M7A-*`,
`PASS-M7B-*` or `PASS-M7C-*` marker ran.

REPAIR ROUND 1 (2026-09-04), same wrapper,
`zsh /Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh /Users/oobi/Documents/tot-m7-stageC-gate.log`.
The gate legs went green at 13:21:28 PDT;  the run recorded here is the
re-run at 13:26:16 PDT, over the final tree with this build log and the
`SPEC.md` entry in place.  Both runs read the same numbers.
Wrapper header: `WAITED=0 LOAD=4.85`, `RUNNER-EXIT=0`,
`STATUS_LINES=8`, `BUILD-EXIT=0`, `M7A-MARKERS=7`, `M7B-MARKERS=2`,
`M7B-SUITE=3`.  No `LOAD-RED` line.  Log tail:

```
PASS-M7A-KERNEL-UNCHANGED
PASS-M7A-ARGHOLE-RESOLVES
PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE
PASS-M7A-CONSERVATIVITY
PASS-M7A-SPINE-COMMENT
PASS-M7A-INFER-SETTLE
PASS-M7A-INFER-SETTLE-BUDGET
PASS-M7B-GUARD-ARG-HOLES
PASS-M7B-LIFTIO-SLOT-CLOSES
PASS-M7C-MULTI-HOLE-TAIL
PASS-M7C-SINGLE-HOLE-UNCHANGED
PASS-M4FIX-INST-BRANCHING
PASS-M5B-BRANCHING-20
GATE-EXIT=0
PASS=406
FAIL=
DONE Fri  4 Sep 2026 13:26:16 PDT
```

`FAIL=` is empty because the runner fills it with `rg -c '^FAIL'`,
which prints nothing when the log holds no `FAIL` line: the count is
zero.  Stage C counts on this log: `rg -c '^PASS-M7C-'` prints 2 (the
two gate markers) and the five `PASS M7C-*` suite lines run inside the
gate slice at log lines 322-326.  `rg -c '^PASS M7C-'` prints 7 over
the whole log, because `battery.sh` also prints the last three lines of
the pre-gate `dune exec test/surface.exe` run, which are `M7C-4`,
`M7C-5` and the suite footer.  That duplication is the same wrapper
offset C-A14 records for the `PASS=` line: gate slice 402, wrapper 406.

Post-round re-measurements, all at rest:
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` prints
218 and the `PASS-M5D-TIERS` literal reads 218;
`python3 dev/hole-anchors.py | tail -1` prints
`ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30`
with 26 `anchor=[_]` lines;  the transcript diff is empty and its md5
is `e0943042fd0ef721b54e26f975fa2f03`;  the `Serror.t` and `Term.t`
constructor counts are 10 and 11;  `rg -c '\x{2014}'` finds no em-dash
in any file this stage touched.

### Review-round fixes (2026-09-04)

The Stage C review round raised five findings.  All five are fixed
here.  None is skipped.  Each note gives the value observed before the
fix and the value observed after it.  The round changed one doc comment
in `surface/run.ml`, two sentences in `SPEC.md`, item 6 of section 7
above, and the NAME of one battery log outside the repository.  No
OCaml code moved, no gate leg moved, no fixture moved and no suite case
moved.  `dune build` stayed green.  The transcript stayed
byte-identical (md5 `e0943042fd0ef721b54e26f975fa2f03`, `diff` exit 0).
`PASS-M5D-TIERS` stayed 218, `rg -c 'holes :=' surface/parser.ml`
stayed 3, and `python3 dev/hole-anchors.py | tail -1` still prints
`ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30`
with 26 `anchor=[_]` lines.

**Conflict note C-C2 (2026-09-04): the plan C5 `untailed` fence does
not typecheck, so the tree carries an explicit polymorphic
annotation.**  Observed before: `dev/M7-PLAN.md:3669-3670` prescribes
`let untailed (r : ('a, Serror.t) result) : ('a, Serror.t * string option) result =`
and `Result.map_error (fun e -> (e, None)) r`.  The tree writes
`let untailed : 'a. ('a, Serror.t) result -> ('a, Serror.t * string option) result =`
and `fun r -> Result.map_error (fun e -> (e, None)) r`.  This is the
ONLY difference between plan 3624-3693 and the `script_tailed` region
of `surface/run.ml` (a `diff` of the two `awk` extractions reports
`46,47c42,43` and nothing else), and this log carried no dated entry
for it.  The deviation is FORCED, not a choice.  Probe of 2026-09-04,
`/Users/oobi/Documents/tot-m7-probes/stageC/cc2-probe.sh`: the plan's
two lines were substituted into the file and `dune build` exited 1 with

```
File "surface/run.ml", line 675, characters 24-56:
675 |   let* items = untailed (Parser.parse_with_holes tokens) in
Error: This expression has type
         "((Syntax.item * Loc.t list) list, Serror.t) result"
       but an expression was expected of type "(Token.t list, Serror.t) result"
       Type "Syntax.item * Loc.t list" is not compatible with type "Token.t"
```

OCaml makes a `let` with a plain `'a` annotation MONOMORPHIC, and
`untailed` is applied at three types: `surface/run.ml:674` (a token
list), `:675` (an item list) and `:684` (the epilogue pair).  The
explicit `'a.` quantifier is a one-line adaptation.  No logic, no
identifier and no comment moved.  The file was restored from a copy
taken before the probe, never with `git checkout`, `git restore` or
`git stash`: `MD5-BEFORE` and `MD5-AFTER` both read
`fe854ef622cade1475f27d05b18fa8df`, the `diff` exits 0, and the rebuild
is green.  Observed after: this note, with `untailed` at
`surface/run.ml:671` unchanged.  Erratum for Stage D: do not copy the
C5 fence bytes for this binding.  The plan line `dev/M7-PLAN.md:3669`
needs the `'a.` quantifier.  The plan file is committed at `37c0bb2`
and this stage does not edit it, so the erratum lives here.

**Conflict note C-C3 (2026-09-04): the plan counts seventeen
`Tot_surface.Run.script` sites in `test/surface.ml`, and the count is
eighteen.**  Observed before: section 7 item 6 copied the plan's word
"seventeen" (`dev/M7-PLAN.md:4148-4150`) without a measurement.
Observed after: item 6 reads "eighteen" and carries both commands.
`git show 71edbc8:test/surface.ml | rg -c 'Tot_surface\.Run\.script'`
prints 18, so the figure was already wrong at HEAD, and
`rg -c 'Tot_surface\.Run\.script[^_]' test/surface.ml` prints 18 in the
live tree.  The new `m7c_expect_tail` helper adds one
`Run.script_tailed` call, which the second pattern excludes;  a plain
count prints 19.  The invariant that item 6 protects still holds:
`git diff -U0 test/surface.ml` has two hunks only (the helper and the
five cases), `Run.script` keeps its HEAD signature, and `dune build` is
green.  Only the printed number was wrong.

**Conflict note C-C4 (2026-09-04): the log named
`tot-m7-stageC-entry-gate.log` held the RED first pass, not an entry
baseline.**  Observed before:
`/Users/oobi/Documents/tot-m7-stageC-entry-gate.log` read
`GATE-EXIT=1`, `PASS=377`, `FAIL=1` and
`FAIL-M6C-HOLE-REPORTS (exit=1/1/1/1)`, and its own header listed the
Stage C source edits as already in the tree (` M bin/tot.ml`,
` M surface/parser.ml`, ` M surface/run.ml`, ` M test/surface.ml`,
`?? dev/fixtures/`, `STATUS_LINES=5`).  The gate stopped in the M6C
block, which runs before every M7 block, so 29 later `PASS` lines never
ran, and a PASS-line diff of that log against the verify log reports 29
verify-only lines, not 7.  The name invited a reader to take a red
mid-stage run as the pre-stage state.  Observed after: the first pass
now lives at
`/Users/oobi/Documents/tot-m7-stageC-firstpass-gate.log` (the same
25882 bytes, `GATE-EXIT=1`, `PASS=377`, `FAIL=1`), and the old path
holds a short stub.  The stub says the file is not a battery log, gives
the first-pass numbers, and names the TRUE Stage C entry baseline,
`/Users/oobi/Documents/tot-m7-stageB-close-gate.log` (`GATE-EXIT=0`,
`PASS=399`, over the clean committed Stage B tree).  Against that
baseline the Stage C delta is the two markers plus the five suite
cases, with the pin 7 wording of two M7B suite lines moved by the C-C1
resolution.  No file in the repository names the old path
(`rg -n 'stageC-entry-gate'` over the tree returns nothing).  The stage
driver `/Users/oobi/Documents/tot-m7-stage-c-build-wf.js` names it at
`:45` and `:283`;  that file belongs to another owner, and its entry
check needs the `stageB-close-gate.log` baseline.  This is a defect in
the artefact names, not in the tree.

**Conflict note C-C5 (2026-09-04): `surface/parser.ml:369` no longer
names the hole-node site.**  Observed before: `SPEC.md:1620` read "the
one place that builds a hole node, `surface/parser.ml:369`", and the
`hole_tail` doc comment at `surface/run.ml:648` read
"(surface/parser.ml:369)".  Both numbers are HEAD numbers.  The stage's
own 23-line `holes` block moved the arm down by 31 lines, so
`awk 'NR==369' surface/parser.ml` prints
`parse_err bad_loc ("expected '->', found " ^ Token.describe kind)`,
an unrelated error arm inside `parse_group_arrow`.  Observed after:
both citations read `surface/parser.ml:400`, and
`awk 'NR==400' surface/parser.ml` prints
`      Ok (Syntax.SHole loc, rest)`.  The `run.ml` comment also names
the arm, "the [Underscore] arm of [parse_atom]", so a later shift
leaves a searchable anchor.  `rg -n 'parser\.ml:369'` over `SPEC.md`,
`surface/run.ml`, `bin/tot.ml` and this log now returns nothing.  The
`surface/parser.ml` module docstring carries the same statement with no
number and did not move.  Comment and prose only: `dune build` green,
transcript `diff` exit 0.

**Conflict note C-C6 (2026-09-04): the SPEC entry said the prelude arm
calls `Run.script`, and no `Run.script` call is left in `bin/tot.ml`.**
Observed before: `SPEC.md:1628-1632` read "`bin/tot.ml`'s prelude-load
arm keeps calling `Run.script`, not `Run.script_tailed`: a prelude-load
failure is an internal error with no user-facing tail to print, and the
exception would be a needless second code path for a call site pin 7
does not reach."  `rg -n 'Run\.script' bin/tot.ml` prints ONE line, 66,
and that line is `Tot_surface.Run.script_tailed`.  The prelude arm
(`run_with_prelude`, bin/tot.ml:158-181) calls
`Bootstrap.cached_state_of_src` and prints at bin/tot.ml:180.  It never
called `Run.script`.  The reason given was not the plan's reason
either.  Observed after: the entry states the plan's own reason (C6,
`dev/M7-PLAN.md:3767-3776`).  The arm keeps its one-line report and
calls no `Run` entry point, because it reports a failure of
`Bootstrap.cached_state_of_src`, which parses the prelude only on a
cache MISS.  On a cache hit no parse walk runs, so no record exists to
report from, and a re-parse is the second pass the ratification
amendment bars.  The BEHAVIOUR is unchanged and correct: a hand-broken
prelude prints one stderr line at exit 1 on a cold cache and on a warm
one.  Pin 12 holds: `rg -c 'expected-type-only=' SPEC.md` prints 6, the
same count as `git show 71edbc8:SPEC.md`, and the last such spelling is
still the `ANCHORS` line, now `SPEC.md:2192`, moved only by lines
inserted above it.

Behaviour probe for C-C6, 2026-09-04
(`/Users/oobi/Documents/tot-m7-probes/stageC/cc6-prelude-probe.sh`): a
copy of `stdlib/prelude.tot` with one bad name appended, pointed at by
`TOT_PRELUDE`, with `TOT_CACHE_DIR` in the scratch tree.  Cold cache:
exit 1, one stderr line, `prelude: 178:25: unknown name notAName`,
zero stdout lines.  Warm cache, same directory: exit 1, the same one
line, `diff` exit 0.  No repository file was touched by the probe.

Review-round battery, 2026-09-04, same wrapper as round 1:
`zsh /Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh /Users/oobi/Documents/tot-m7-stageC-review-gate.log`.
Wrapper header: `WAITED=0 LOAD=11.05`, `RUNNER-EXIT=0`,
`STATUS_LINES=8`, `BUILD-EXIT=0`, `M7A-MARKERS=7`, `M7B-MARKERS=2`,
`M7B-SUITE=3`.  No `LOAD-RED` line: `rg -c 'LOAD-RED'` finds nothing in
the log and nothing in the wrapper output, so this run is not a load
artefact.  Log tail: `GATE-EXIT=0`, `PASS=406`, `FAIL=`, and
`DONE Fri  4 Sep 2026 16:52:59 PDT`.  The runner fills `FAIL=` with
`rg -c '^FAIL'`, which prints nothing when the log holds no `FAIL`
line, so the count is zero.  The gate slice is 402;  the wrapper line
reads 406 because the two suite tails add four `PASS` lines (conflict
note C-A14).  Stage C counts on this log: `rg -c '^PASS-M7C-'` prints
2 (the two markers) and `rg -c '^PASS M7C-'` prints 7 over the whole
log, the five gate-slice cases plus the two suite-tail lines the round
1 record explains.

Re-run over the FINAL tree, with this section in place, into the same
path: `WAITED=0 LOAD=9.61`, `RUNNER-EXIT=0`, `STATUS_LINES=8`,
`BUILD-EXIT=0`, `GATE-EXIT=0`, `PASS=406`, `FAIL=`,
`DONE Fri  4 Sep 2026 17:04:49 PDT`, `M7A-MARKERS=7`,
`M7B-MARKERS=2`, `M7B-SUITE=3`, no `LOAD-RED` line,
`rg -c '^PASS-M7C-'` 2 and `rg -c '^PASS M7C-'` 7.  Both runs read the
same numbers.  This paragraph is the only edit after that run, and it
adds prose to this log alone.  Nothing is staged and nothing is
committed.  No `git checkout`, `git restore` or `git stash` ran on any
path in this round.
