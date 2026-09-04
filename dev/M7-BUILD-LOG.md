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
branch pattern, which is kernel work and is out of M7 scope.

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
