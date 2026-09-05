# M8 build log

## Stage A (2026-09-05): the local-aware capture source

Plan: `dev/M8-PLAN.md`, section "STAGE A", subsections Goal to Rollback.
Rulings covered: R10, R11, C-A14, C-D3 (carried).  Attack findings
A1-F1 and A1-F2, both accepted.

The stage ran in two halves.  Build-1 owned `surface/elab.ml` and the
three `dev/m8a` fixtures.  Build-2 owned `dev/gates.sh`, the four
`test/surface.ml` cases and this file.  No file under `lib/` moved.

### 1. Entry state

- `git -C /Users/oobi/Documents/tot rev-parse --short HEAD` = `6bcc1b7`,
  the M7 exit commit.
- `git status --porcelain` at entry carried exactly one line,
  `A  dev/M8-PLAN.md`.  The plan is staged by the user.  No agent
  edited it, unstaged it or committed it.
- Entry battery, through the wrapper
  `zsh /Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh
  /Users/oobi/Documents/tot-m8-stageA-entry-gate.log 12 3600`:
  `BUILD-EXIT=0`, `GATE-EXIT=0`, `PASS=424`, `FAIL=` (empty),
  `RUNNER-EXIT=0`, `STATUS_LINES=1`.  The wrapper reads the gate slice
  plus 4 (C-A14), so the entry slice is 420.
- Entry probes, each with the command that printed it:
  - `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh | wc -l` = `166`.
  - `rg -c 'PASS-M8' dev/gates.sh` printed nothing and exited 1, so the
    PASS-M8 namespace was free before this scope (R11).
  - `rg -n 'PASS-M7E' dev/gates.sh` listed the five Stage E markers at
    3889, 3911, 3936, 3958 and 3975.
  - The 17-file `lib/*.ml` digest read
    `ec077852495cdc0ac9a7abd4eb2fe786`.
- Entry values of the three at-risk recipes, each re-run standalone
  before the first edit:
  - `PASS-M5D-TIERS` (recipe at dev/gates.sh:2282): `nolit=1 tiers=228
    bites=2`.
  - `PASS-M7A-INFER-SETTLE-BUDGET` (derive at dev/gates.sh:3546):
    `files=104 green=62 md5=9278f6b7034f2f65b6d789e9e1d74a90`.
  - `PASS-M7A-CONSERVATIVITY` (recipe at dev/gates.sh:3402):
    `cons_md5=f1450de0006de4b7339b2f39ec2e2e50 lines=43 errbytes=0
    holes=8`.
- Entry file measures: `surface/elab.ml` md5
  `1721177ff1fdba227333fbab26281b62`, 984 lines;  `dev/gates.sh` md5
  `dcbcfbef0f19ab0a7ca0aab036e225e0`, 4039 lines;  `test/surface.ml`
  md5 `df1aee71371bbe7b8c5021ace83ac47e`, 2402 lines;  `lib/check.ml`
  md5 `c9853e62da66f995cd210900e72530f5`, 2082 lines.
- `dev/M8-BUILD-LOG.md` did not exist.  This stage creates it.
- `dev/m8a/` did not exist.  This stage creates it with three fixtures,
  on the `dev/m7a/sN-holed.tot` and `dev/m7a/sN-explicit.tot` twin
  convention.

### 2. What changed

`git status --porcelain` at exit:

    A  dev/M8-PLAN.md      (staged by the user, untouched)
     M dev/gates.sh
     M surface/elab.ml
     M test/surface.ml
    ?? dev/M8-BUILD-LOG.md
    ?? dev/m8a/

#### 2.1 `surface/elab.ml` (Build-1)

`inst_domain` takes a new labelled parameter,
`~(escape : int -> Term.t option)`, threaded through every recursive
call in every arm.  Its free-variable arm answers `escape i` where it
answered `None`.  `inst_applied` is now a thin wrapper that pins
`~escape:(fun _ -> None)`, so the GLOBAL arm keeps its behaviour byte
for byte.  `inst_applied_local` is new and pins
`~escape:(fun i -> Some (Term.Var (i - n)))`, where `n` is the number
of PEELED arguments.  `synth`'s local arm keeps
`[] -> local_ty locals ix` character for character and gains the
non-empty arm that calls `inst_applied_local`.

Addresses, measured with `rg -n` on the edited file, not copied from
the plan: `inst_domain` header 212, its escape answer 219,
`local_ty` 314, `inst_applied` 389, its escape pin 395,
`inst_applied_local` 411, its escape pin 418, `synth` 432, the local
arm head 436, the zero-argument branch 438, the only call to
`inst_applied_local` 441, `spine_infer` 922, its fenced call 933, its
`caps = []` arm 939.  Four further `inst_domain` call sites take the
new parameter and pin `~escape:(fun _ -> None)`: 528, 887, 897 and 967.
The file grows from 984 lines to 1025 and its md5 walks
`1721177ff1fdba227333fbab26281b62` to
`1df9909b6296bf60828326984d822f85`.

#### 2.2 `dev/m8a/` (Build-1)

Three fixtures.  `local-spine-holed.tot` holds a hole whose only
informative later argument is the local-headed spine `f x`.
`local-spine-explicit.tot` is the same definition with the slot written
out, and it prints the identical type.  `bare-lambda-holed.tot` holds a
bare lambda in callee position, which the kernel refuses at
lib/check.ml:959.

#### 2.3 `dev/gates.sh` (Build-2)

One block of four legs, inserted between the M7E block's last line
(3976 at the entry state) and the next comment (3978 at the entry
state).  The four markers are `PASS-M8A-LOCAL-SPINE-SYNTH`,
`PASS-M8A-ZERO-ARG-UNCHANGED`, `PASS-M8A-BARE-LAMBDA-REFUSES` and
`PASS-M8A-KERNEL-UNCHANGED`.  Four legs, no more.  The fifth,
corpus-digest leg the plan lists is dropped under R-F3, because
`PASS-M7A-CONSERVATIVITY` already pins the identical digest over the
identical five example files.  No leg name from a later stage was
added.

Exit addresses in the edited file, each printed by `rg -n` after the
edit landed: the block header comment 3992, the
`PASS-M8A-LOCAL-SPINE-SYNTH` echo 4019, the
`PASS-M8A-ZERO-ARG-UNCHANGED` echo 4049, the
`PASS-M8A-BARE-LAMBDA-REFUSES` echo 4074, the
`PASS-M8A-KERNEL-UNCHANGED` echo 4103.  The `PASS-M5D-TIERS` literal
sits at 2331 after the edit.  The file grows from 4039 lines to 4170.

Each leg carries its own observable, which is R10: leg (i) watches the
exit code and the printed def name, leg (ii) the `church` and `local`
fields, leg (iii) the `bare` and `local` fields, leg (iv) the lib
digest.  Two legs name the same `lib/check.ml` line in their mutation
text.  That is allowed because their mutation texts and their
observables differ: leg (iii) replaces the refusal with an inference
and watches `bare`, leg (iv) edits the message string and watches
`lib_md5`.

#### 2.4 `test/surface.ml` (Build-2)

Four cases, M8A-1 to M8A-4, appended after the last M7E case and inside
the `cases` list.  Four source-string constants sit above `let cases`.
The cases reuse the existing helpers.  No new helper was written.  The
file grows from 2402 lines to 2456 and the surface suite walks 148 PASS
to 152 PASS with 0 FAIL.

Case addresses after the edit: the four source-string constants start at
1130, `let cases` at 1145, and the four cases at 2304, 2320, 2323 and
2326.

M8A-1 is the local-spine positive.  It checks the explicit twin with
`m7e_expect_source_checks`, reads the twin's printed lines from
`Run.script ~st:bst ~exec:false`, refuses an empty line list, and then
pins the holed source against those lines with `expect_lines_check`.
M8A-2 is the bare-lambda negative through `m7e_expect_source_error`,
with the suffix `cannot infer a type for the bare lambda (binder x)`.
M8A-3 is the class-former fence control, the source `eval (mkEqD _
boolEq)` through the same helper, with the suffix `hole: no expected
type at this position`.  M8A-4 drives the open captured type into
`Check.define` through `m7e_expect_source_checks`.

No case duplicates its gate leg.  The legs read the CLI's external text
over files on disk.  The cases drive `Bootstrap.state ()` and
`Run.script ~st:bst ~exec:false` over source strings, which is the path
`Check.define` (surface/run.ml:241) sits on.  A change to how output is
FORMATTED cannot make a case pass while its leg fails, or the reverse.

#### 2.5 `dev/M8-BUILD-LOG.md` (Build-2)

This file.  It did not exist at entry.

### 3. Conflict notes

**Conflict note C-A1 (2026-09-05): the plan's `prelude` field is dead,
so leg (ii) watches `church`.**

1. Predicted.  The plan's leg 2 command (dev/M8-PLAN.md:846-848) prints
   `prelude=0 local=1` before the stage and `prelude=0 local=0` after
   it, on the recorded reason "the prelude bootstraps clean at HEAD".
2. Measured.  The `prelude` field reads 1 at every state, before the
   elaborator diff and after it.  The `local` field moves 1 to 0 as
   predicted.  `examples/church.tot` reads 0 at both states.
3. Command and output.  Run from the repo root:

       /Users/oobi/Documents/tot/_build/default/bin/tot.exe check \
         /Users/oobi/Documents/tot/stdlib/prelude.tot; echo $?

   prints

       /Users/oobi/Documents/tot/stdlib/prelude.tot:2:1: duplicate global Bool
       1

   The Stage A baseline recorder holds the same reading on both sides
   of the diff: `/Users/oobi/Documents/tot-m8-probes/stage-a/baseline/leg2.txt`
   reads `prelude=1 local=1` and
   `/Users/oobi/Documents/tot-m8-probes/stage-a/after/leg2.txt` reads
   `prelude=1 local=0`.
4. Cited lines.  `bin/tot.ml:158-166`, `run_with_prelude` reads
   `Bootstrap.prelude_source ()` and builds the state with
   `Bootstrap.cached_state_of_src src` BEFORE it checks the named file.
   `stdlib/prelude.tot:2` is `data Bool : Type 0 := | true : Bool |
   false : Bool`, so the named file re-declares a global the bootstrap
   state already holds.  `lib/error.ml:171` prints the refusal,
   `duplicate global %s`.
5. The smallest reading that fits.  The refusal is a property of the
   CLI's own bootstrap order, not of the elaborator, and it fires for
   any file that repeats a prelude declaration.  It cannot move under
   any Stage A edit, so `prelude` is a constant field and not an
   observable.
6. The decision.  Section 3.2 applies.  The refused prediction is the
   OBSERVABLE of leg (ii), not the ratified payload, so the note is
   booked and the payload stays as Build-1 left it.  Orchestrator ruling
   C-A1 (2026-09-05) writes the leg with the field `church`, measured 0
   at the entry state and 0 after the diff, and keeps the `local` field
   as the plan writes it.  The leg passes only when `church=0` and
   `local=0`.  `prelude=1` is not pinned.  The plan text is not edited.

**Conflict note C-A2 (2026-09-05): the tier literal walks 228 to 234.**

1. Predicted.  The Stage A brief predicts 0 new watchdog uses, from a
   regex count over the plan's block bytes.  The plan writes its four
   leg commands standalone, with the spelling `timeout 10`.
2. Measured.  `tiers` reads 234 after the block lands.  `nolit` stays 1
   and `bites` stays 2.
3. Command and output.  The leg's own recipe, dev/gates.sh:2282, run
   standalone:

       rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh

   printed `228` before the edit and `234` after it.  The first reading
   of the edited file was `235`.
4. Cited lines.  The six new tier calls sit at dev/gates.sh:4015, 4042,
   4045, 4066, 4069 and 4098 in the edited file, one per CLI run: one in
   leg (i), two in leg (ii), two in leg (iii), one in leg (iv).  The
   literal the leg asserts is at dev/gates.sh:2331.
5. The smallest reading that fits.  The four legs are folded into the
   shared machinery, so each `timeout 10` of the plan becomes one
   FAST-tier call, and FAST is 10 (dev/gates.sh:44).  The prediction
   counted the plan's standalone spelling, which the recipe does not
   match.  The 235 reading came from the new block's header comment,
   which quoted the tier-call spelling in prose;  the prose now names
   the tier in words.  No watchdog call was added or removed to reach
   any number (precedent C-D4).
6. The decision.  Re-measure and book the note.  The refused prediction
   is a NUMBER, so section 3.2's first move applies.  The literal at
   dev/gates.sh:2331 walks 228 to 234, and the walk is recorded in the
   leg's own comment block, next to the M7 Stage B to Stage E walks.

### 4. Decisions

1. D-A1.  The four leg commands are folded into the shared machinery.
   Each `timeout 10` becomes one FAST-tier watchdog call, and FAST is
   10, so no predicted exit code and no predicted substring moves.  The
   block declares no scratch directory, so the EXIT trap at
   dev/gates.sh:434 is unchanged.
2. D-A2.  Leg (iv) adds one conjunct the plan does not write, the count
   of `lib/*.ml` files, pinned at 17.  The digest walks a FIXED file
   list, so a new kernel file would join `lib/` without moving the
   digest.  The count refuses that.  This adds an assertion;  it
   weakens none.
3. D-A3.  The fifth, corpus-digest leg the plan lists is dropped under
   R-F3.  `PASS-M7A-CONSERVATIVITY` at dev/gates.sh:3448 already pins
   the identical digest over the identical five example files, and it
   is green at exit with its literal unchanged.
4. D-A4.  The suite cases reuse the file's existing helpers,
   `m7e_expect_source_checks`, `m7e_expect_source_error` and
   `expect_lines_check`.  No new helper was written.  M8A-1 needs the
   two-half claim of dev/M8-PLAN.md:905-912, `Ok` plus the twin's
   printed type, so it composes two existing helpers with the file's
   own `let*` binder and a `match () with` guard.
5. D-A5.  Prep ruling PREP-2 answer A stands.  The M8A-3 and M8A-4
   source strings are implemented as the prep wrote them.  Both were
   measured before they landed:  `eval (mkEqD _ boolEq)` exits 1 with
   `1:13: hole: no expected type at this position`, and the M8A-4
   source exits 0 and prints `def probeH : (0 A : Type 0) -> (w _ : (w
   _ : A) -> (List A)) -> (w _ : A) -> (List A)`, the same line its
   explicit twin prints.  Neither string needed the SA-Q6 escape hatch.
6. D-A6.  Prep ruling PREP-1 answer A stands.  Leg (iv) cats the 17
   `lib/*.ml` files in sorted name order and keeps the literal
   `ec077852495cdc0ac9a7abd4eb2fe786`.

### 5. Re-derivations, old value then new value

Every number below came from a live recipe run on the edited tree.  No
number was carried from a prediction (precedent C-D4).

| what | recipe | old | new |
|---|---|---|---|
| tier calls | `rg -c '"\$watchdog" "\$(FAST\|MED\|SLOW\|SUITE)"' dev/gates.sh` | 228 | 234 |
| numeric watchdog literals | `rg -q '"\$watchdog" [0-9]' dev/gates.sh` | exit 1 | exit 1 |
| calibration bites | `rg -c '"\$watchdog" "\$BITE_S"' dev/gates.sh` | 2 | 2 |
| gate echo sites | `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh \| wc -l` | 166 | 170 |
| corpus walk | dev/gates.sh:3546 derive | files=104 green=62 md5=9278f6b7034f2f65b6d789e9e1d74a90 | files=104 green=62 md5=9278f6b7034f2f65b6d789e9e1d74a90 |
| conservativity | dev/gates.sh:3402 recipe | cons_md5=f1450de0006de4b7339b2f39ec2e2e50 lines=43 errbytes=0 holes=8 | the same four values |
| lib digest | `cat` the 17 `lib/*.ml` files, `md5 -q` | ec077852495cdc0ac9a7abd4eb2fe786 | ec077852495cdc0ac9a7abd4eb2fe786 |

`PASS-M7A-INFER-SETTLE-BUDGET` keeps all three literals, and the line
that decides it is the derive's own walk:

    fd -e tot --max-depth 1 . "$ROOT"/stdlib "$ROOT"/examples "$ROOT"/test/fixtures

The walk names three directories, `stdlib`, `examples` and
`test/fixtures`, and `--max-depth 1` holds it to their own level.
`dev/m8a` is in none of them, so the three new fixtures cannot enter
the walk.  Measured: the same command piped to `rg -c 'm8a'` matched
nothing and exited 1.  The three literals at dev/gates.sh:3592 and
dev/gates.sh:3593 are unchanged and were not edited.

`PASS-M7A-CONSERVATIVITY` stays green with its digest unchanged, which
is the reason the fifth leg is dropped.  Its literal at
dev/gates.sh:3448 was not edited.

Address note.  Section 1 gives the three at-risk recipes at their ENTRY
addresses, dev/gates.sh:2282, 3546 and 3402, which are the addresses
the Stage A brief names.  The `PASS-M5D-TIERS` recipe is above this
stage's own edits and stays at 2282.  The other two sit below the
fourteen comment lines the tier walk added, so they move down by 14:
the corpus derive is at dev/gates.sh:3559 after the edit and the
conservativity recipe block starts at dev/gates.sh:3415, with its
`md5 -q` at 3441.  Every address in this section was printed by `rg -n`
on the edited file.

The PASS-M8 namespace holds exactly four names.  `rg -o 'PASS-M8[A-Z0-9-]*'
dev/gates.sh | sort -u` prints `PASS-M8A-BARE-LAMBDA-REFUSES`,
`PASS-M8A-KERNEL-UNCHANGED`, `PASS-M8A-LOCAL-SPINE-SYNTH` and
`PASS-M8A-ZERO-ARG-UNCHANGED`, and nothing else.  `rg -c 'PASS-M8'`
reads 10 LINES, which is the four echo lines plus six comment lines
that name their own marker, the same comment convention the M7E block
uses (`rg -n 'PASS-M7E'` reads 12 lines for five markers).

### 6. Exit state

- Exit battery, through the same wrapper into
  `/Users/oobi/Documents/tot-m8-stageA-gate.log`: `BUILD-EXIT=0`,
  `GATE-EXIT=0`, `PASS=432`, `FAIL=` (empty), `RUNNER-EXIT=0`,
  `STATUS_LINES=6`.  The wrapper reads the gate slice plus 4 (C-A14),
  so the exit slice is 428.  The plan's estimate is 428 slice and 432
  wrapper.  The measured numbers equal the estimate, so no count
  conflict note is booked.  The arithmetic: entry 420 slice plus four
  new markers plus four new suite cases is 428 slice, and 428 plus the
  wrapper's own 4 is 432.
- The four new markers print at
  `/Users/oobi/Documents/tot-m8-stageA-gate.log:513-516`.  The battery
  ran twice on the same code state.  The first run read `PASS=432` with
  `STATUS_LINES=5`, before this file existed;  the second read the same
  `PASS=432` with `STATUS_LINES=6`, with this file on disk.  No gate leg
  reads a `dev/*.md` file other than the M5E transcript, so the new file
  moves no count.  The second reading is the exit measurement.
- Suites: `dune exec --root . test/main.exe` reads 105 PASS 0 FAIL,
  `dune exec --root . test/surface.exe` reads 152 PASS 0 FAIL.  The
  surface suite walks 148 to 152, which is the four new cases.
- The 17-file `lib/*.ml` digest reads
  `ec077852495cdc0ac9a7abd4eb2fe786` at exit, the same value it read at
  entry.  No file under `lib/` was edited at any point of this stage.
- `synth`'s zero-argument branch is unchanged character for character.
  `rg -n -F '[] -> local_ty locals ix' surface/elab.ml` prints one hit,
  at surface/elab.ml:438.
- Exit file measures: `dev/gates.sh` md5
  `472e1586ce3dc27dbc65a6006f059783`, 4170 lines;  `test/surface.ml` md5
  `9ae5b497d8350ec30dc3a26fdf1de2c5`, 2456 lines;  `surface/elab.ml` md5
  `1df9909b6296bf60828326984d822f85`, 1025 lines;  `lib/check.ml` md5
  `c9853e62da66f995cd210900e72530f5`, unchanged.
- The baseline recorder was re-run into
  `/Users/oobi/Documents/tot-m8-probes/stage-a/after` and diffed against
  `/Users/oobi/Documents/tot-m8-probes/stage-a/baseline`.  Every
  difference is named by the edit that caused it: the four leg files
  (the fixtures now exist and the local control moves 1 to 0), the tier
  count 228 to 234, the gate echo count 166 to 170, the PASS-M8 probe
  from absent to 10 lines, the M7E line numbers shifted by the inserted
  block, the three touched-file digests, the three new fixtures, the
  rebuilt `tot.exe`, and the four new porcelain lines.  `probes.txt`
  part (d), `lib-digest.txt`, `settle-budget.txt` and
  `conservativity.txt` are byte-identical on both sides.
- Nothing was staged, committed, stashed or checked out by any agent of
  this stage.  `dev/M8-PLAN.md` keeps its staged entry, untouched.

### Review-round fixes (2026-09-05)

Two confirmed review findings landed after the stage first closed green.
VER-F1 and M8A-R1 name one cause: the four legs did not own separate
fields, so one leg's mutation reddened legs it does not belong to, and
plan review-checklist item 6 (dev/M8-PLAN.md:960-962) could not be
answered PASS.  VER-F2 names a second cause: `dev/m8a/local-spine-
explicit.tot` was dead on disk, and no leg compared a fixture with the
source string the suite elaborates.  No predicate was weakened to make a
number fit.  The marker count stays 4, the suite case count stays 4, and
`test/surface.ml`, `surface/elab.ml` and every file under `lib/` keep the
bytes the stage closed with.  The review round touched `dev/gates.sh` and
this file, and nothing else.

**What changed.  Every address below was printed by `rg -n` on the
edited file, after the edit landed.**

1. Leg (i) `PASS-M8A-LOCAL-SPINE-SYNTH` (dev/gates.sh:4085) now reads the
   explicit twin as well (dev/gates.sh:4068).  It asserts both files exit
   0, that the two runs print one and the same line, that the line is not
   empty, and it pins that line (dev/gates.sh:4081).  This is the M7 twin
   shape at dev/gates.sh:3300-3345, which every `dev/m7a/*-explicit.tot`
   already carries.  VER-F2's "dead on disk" reading is closed: the file
   is now read by a gate leg.
2. Legs (i) and (iii) compare each fixture with the source string the
   suite elaborates.  The renderer is the shell function `m8a_lit`
   (dev/gates.sh:4037).  It prints the bytes of one
   `let <name> : string =` literal of `test/surface.ml`, reading the
   OCaml line continuation and the `\n` and `\ ` escapes.  The conjuncts
   sit at dev/gates.sh:4073-4076 and dev/gates.sh:4145-4146.  Each leg
   first asserts its own fixtures hold no backslash and no double quote,
   so no other escape can reach the renderer unseen.  A file and its
   string can no longer drift apart.
3. Leg (iii) `PASS-M8A-BARE-LAMBDA-REFUSES` (dev/gates.sh:4153) drops the
   `local` control leg (i) owns, and drops the moving half of the kernel
   message, `the bare lambda`, which is exactly the text leg (iv)'s own
   mutation rewrites.  It gains the part of the message that mutation
   cannot move: the position and the refusal prefix (dev/gates.sh:4149)
   and the binder name (dev/gates.sh:4150).  No assertion is lost.  The
   plan assigns the whole string to the suite, not to the leg
   (dev/M8-PLAN.md:911-917), and suite case M8A-2 pins the suffix
   `cannot infer a type for the bare lambda (binder x)` in process.
4. Leg (iv) `PASS-M8A-KERNEL-UNCHANGED` (dev/gates.sh:4181) drops the
   `local` control as well.  It now watches the two fields its own
   comment always named, the 17-file digest and the file count
   (dev/gates.sh:4180).
5. Leg (ii) `PASS-M8A-ZERO-ARG-UNCHANGED` (dev/gates.sh:4115) is
   unchanged.  Orchestrator ruling C-A1 fixes its two fields, `church`
   and `local`, so a builder cannot drop the shared control there.  The
   consequence is measured below and left for the user.
6. `PASS-M5D-TIERS` walks its literal 234 to 233 (dev/gates.sh:2338).
   Leg (i) gains one CLI run and legs (iii) and (iv) each drop one, so
   the M8A block runs the CLI five times.  The recipe is the authority
   (precedent C-D4).

**Conflict note C-A3 (2026-09-05): the four legs did not own separate
fields, so item 6 could not be answered.**

1. Predicted.  Plan review-checklist item 6 (dev/M8-PLAN.md:960-962)
   states that each MUTATION "turns exactly its own leg red and leaves
   the other three green".  The block comment the build wrote restated
   it: "Every leg owns its own observable, so no two legs watch the same
   field (R10)".
2. Measured.  At the build state legs (ii), (iii) and (iv) all read one
   field, the exit code of `tot.exe check dev/m8a/local-spine-holed.tot`,
   which leg (i) owns.  MA-1 turned all four legs red.  MA-4, the
   message-text edit leg (iv) names, turned leg (iii) red too, and
   because each leg exits on its own failure arm, a real battery run
   stopped at leg (iii) and never printed leg (iv)'s own state.  The
   build's own mutation run recorded one leg per row, so the "leaves the
   other three green" half was never measured for any row.  After the
   review fix, all four legs are measured on every row:

   | mutation | leg (i) | leg (ii) | leg (iii) | leg (iv) |
   |---|---|---|---|---|
   | MA-1 `surface/elab.ml`, restore `\| _ :: _ -> None` | RED, its own | RED | green | green |
   | MA-2 `surface/elab.ml`, `[] -> Some (Term.Var ix)` | RED | RED, its own | RED | green |
   | MA-3 `lib/check.ml:959`, `Ok (tm, Value.VUniv Level.zero)` | green | green | RED, its own | RED |
   | MA-4 `lib/check.ml:959`, message text `a lambda` | green | green | green | RED, its own |

   Every row reddens its own leg, so no leg is vacuous.  MA-4 is now
   isolated, where before the fix it reddened leg (iii) first and left
   leg (iv) unobserved.  MA-1 reddens two legs, where before the fix it
   reddened four.
3. Command and output.  Run from the repo root:

       zsh /Users/oobi/Documents/tot-m8-probes/stage-a/review-mutations.sh

   Its log is
   `/Users/oobi/Documents/tot-m8-probes/stage-a/review-mutrun/matrix.log`.
   The three collateral rows read, verbatim:

       --- MA-1 (surface/elab.ml, restore | _ :: _ -> None) ---
         leg1=FAIL (code=1 twin=0 out=/Users/oobi/Documents/tot/dev/m8a/local-spine-holed.tot:2:28: hole: no expected type at this position)
         leg2=FAIL (church=0 local=1)
         leg3=PASS (bare=1 text=/Users/oobi/Documents/tot/dev/m8a/bare-lambda-holed.tot:1:1: cannot infer a type for the bare lambda (binder x))
         leg4=PASS (lib_md5=ec077852495cdc0ac9a7abd4eb2fe786 files=17)
       --- MA-2 (surface/elab.ml, [] -> Some (Term.Var ix)) ---
         leg1=FAIL (code=1 twin=1 out=prelude: 17:160: hole: expected Type 0)
         leg2=FAIL (church=1 local=1)
         leg3=FAIL (bare=1 text=prelude: 17:160: hole: expected Type 0)
         leg4=PASS (lib_md5=ec077852495cdc0ac9a7abd4eb2fe786 files=17)
       --- MA-3 (lib/check.ml:959, Ok (tm, Value.VUniv Level.zero)) ---
         leg1=PASS (code=0 twin=0 out=def probeH : (0 A : Type 0) -> (w _ : (w _ : A) -> A) -> (w _ : A) -> (Option A))
         leg2=PASS (church=0 local=0)
         leg3=FAIL (bare=1 text=/Users/oobi/Documents/tot/dev/m8a/bare-lambda-holed.tot:1:1: not a function type: Type 0)
         leg4=FAIL (lib_md5=4c9a43f401ba9f8fee5186dbabb177e8 files=17)

   MA-4 reads `leg1=PASS leg2=PASS leg3=PASS leg4=FAIL
   (lib_md5=db3bb126a5c68ddd867faca0808300ac files=17)`.  Under MA-4 the
   suite reads `FAIL M8A-2` and the other three M8A cases PASS, which is
   the string pin doing its work in the place the plan puts it.  Every
   source file was restored after every row: `surface/elab.ml` reads
   `1df9909b6296bf60828326984d822f85` and `lib/check.ml` reads
   `c9853e62da66f995cd210900e72530f5`, the values they held before the
   run, and the RESTORED row reads all four legs green.
4. Cited lines.  The shared field was read at dev/gates.sh:4046-4047,
   4069-4071 and 4098-4100 of the build state.  The two conjuncts that
   carried it away are gone;  the surviving copy is leg (ii)'s, now at
   dev/gates.sh:4110-4111, kept by orchestrator ruling C-A1 (this file,
   conflict note C-A1, part 6).  The message text leg (iii) pinned was
   `lib/check.ml:959`, `Printf.sprintf "the bare lambda (binder %s)" x`,
   the same line leg (iv)'s mutation rewrites.  Leg (iii) now pins
   dev/gates.sh:4149-4150 instead, and suite case M8A-2 keeps the whole
   string.
5. The smallest reading that fits.  Three of the four collateral
   reddenings had a field cause, and removing the shared field removed
   them.  Three remain, and each has a structural cause that no field
   choice inside the block can remove.  (a) MA-1 reddens leg (ii),
   because leg (ii) keeps the `local` control ruling C-A1 fixes.  (b)
   MA-2 reddens legs (i) and (iii), because that mutation breaks the
   prelude bootstrap itself: every CLI run under it prints
   `prelude: 17:160: hole: expected Type 0`, so every leg that runs the
   binary goes red, whatever field it reads.  (c) MA-3 reddens leg (iv),
   because leg (iv) pins the digest of all 17 `lib/*.ml` files while the
   plan names a `lib/check.ml` edit as leg (iii)'s mutation;  a whole-lib
   invariant leg reddens for ANY lib edit, which is the leg's purpose.
6. The decision.  Re-measure and book the note.  Section 3.2's first
   move applies: the refused prediction is a checklist item about the
   legs' own fields, not the ratified payload, so the note is booked and
   the payload stays as Build-2 left it.  Item 6 now reads: every
   mutation turns its own leg red, and the three collateral reddenings
   that remain are named above with their causes, measured, not
   asserted.  Item (a) is the one a builder cannot close alone.  Ruling
   C-A1 fixes leg (ii)'s two fields, so dropping the `local` control
   there is a user ruling, and this note stops at the record.

**Re-derivations of the review round, old value then new value.**
Every number came from a live recipe run on the edited tree.

| what | recipe | old | new |
|---|---|---|---|
| tier calls | `rg -c '"\$watchdog" "\$(FAST\|MED\|SLOW\|SUITE)"' dev/gates.sh` | 234 | 233 |
| numeric watchdog literals | `rg -q '"\$watchdog" [0-9]' dev/gates.sh` | exit 1 | exit 1 |
| calibration bites | `rg -c '"\$watchdog" "\$BITE_S"' dev/gates.sh` | 2 | 2 |
| gate echo sites | `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh \| wc -l` | 170 | 170 |
| lib digest | `cat` the 17 `lib/*.ml` files, `md5 -q` | ec077852495cdc0ac9a7abd4eb2fe786 | ec077852495cdc0ac9a7abd4eb2fe786 |
| `dev/gates.sh` | `md5 -q`, `wc -l` | 472e1586ce3dc27dbc65a6006f059783, 4170 | 2fef3ae2b771b5f0153c21113bbd07f6, 4248 |
| `test/surface.ml` | `md5 -q` | 9ae5b497d8350ec30dc3a26fdf1de2c5 | the same value |
| `surface/elab.ml` | `md5 -q` | 1df9909b6296bf60828326984d822f85 | the same value |
| `lib/check.ml` | `md5 -q` | c9853e62da66f995cd210900e72530f5 | the same value |

**Exit state of the review round.**

- Exit battery, through the same wrapper into
  `/Users/oobi/Documents/tot-m8-stageA-review-gate.log`: `BUILD-EXIT=0`,
  `GATE-EXIT=0`, `PASS=432`, `FAIL=` (empty), `RUNNER-EXIT=0`,
  `STATUS_LINES=6`, `WAITED=0 LOAD=11.46`.  The wrapper reads the gate
  slice plus 4 (C-A14), so the exit slice is 428.  The stage closed at
  428 slice and 432 wrapper, and the review round holds both numbers.
  No marker and no suite case was added or removed.
- The four markers print at
  `/Users/oobi/Documents/tot-m8-stageA-review-gate.log:513-516`.  The
  four suite cases print at lines 339, 341, 343 and 344 of the same log.
- The at-risk legs all print PASS in the same run: `PASS-M5D-TIERS` at
  line 458 with its literal re-derived to 233, `PASS-M7A-CONSERVATIVITY`
  at line 496 with its digest untouched, and
  `PASS-M7A-INFER-SETTLE-BUDGET` at line 499 with its three literals
  untouched.
- `synth`'s zero-argument branch is unchanged character for character.
  `rg -n -F '[] -> local_ty locals ix' surface/elab.ml` prints one hit,
  at surface/elab.ml:438.  No file under `lib/` and no file under
  `surface/` was edited by the review round.
- Open for the user, from conflict note C-A3 part 5, item (a): leg (ii)
  keeps the `local` control that orchestrator ruling C-A1 fixes, so
  MA-1 reddens leg (ii) as well as leg (i).  Closing that one needs a
  ruling on whether leg (ii) may drop the `local` field, which would
  leave it watching `church` alone.
- Nothing was staged, committed, stashed or checked out by the review
  round.  `dev/M8-PLAN.md` keeps its staged entry, untouched.

## Closing round, 2026-09-05

**Final battery.**  The closer ran the wrapper into
`/Users/oobi/Documents/tot-m8-stageA-close-gate.log`.  It read
`BUILD-EXIT=0`, `GATE-EXIT=0`, `PASS=432`, `FAIL=` (empty),
`RUNNER-EXIT=0`, `STATUS_LINES=6`, `WAITED=240 LOAD=9.52`.  The wrapper
reads the gate slice plus 4 (C-A14), so the exit slice is 428.  Both
numbers match the ESTIMATE of 428 slice and 432 wrapper.  No conflict
note is needed for the closing round.

**Four markers, confirmed present in dev/gates.sh.**

1. PASS-M8A-LOCAL-SPINE-SYNTH (gates.sh:4085)
2. PASS-M8A-ZERO-ARG-UNCHANGED (gates.sh:4115)
3. PASS-M8A-BARE-LAMBDA-REFUSES (gates.sh:4153)
4. PASS-M8A-KERNEL-UNCHANGED (gates.sh:4181)

**Four suite cases, confirmed present in test/surface.ml.**

1. M8A-1: a hole whose only informative later argument is a
   local-headed spine resolves (test/surface.ml:2304).
2. M8A-2: the kernel still refuses a bare lambda in callee position
   (test/surface.ml:2320).
3. M8A-3: a fenced GLOBAL head with a holed leading slot keeps its
   refusal (test/surface.ml:2323).
4. M8A-4: an OPEN captured type reaches the kernel and Check.define
   accepts it (test/surface.ml:2326).

**Re-derived literals, closing round, old value then new value.**

| what | recipe | old | new |
|---|---|---|---|
| gate echo sites | `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh \| wc -l` | 166 | 170 |
| PASS-M8 namespace | `rg -c 'PASS-M8' dev/gates.sh` | exit 1 (none) | 10 |
| lib digest, 17 files | `cat` in plan order, `md5` | ec077852495cdc0ac9a7abd4eb2fe786 | ec077852495cdc0ac9a7abd4eb2fe786 (unchanged) |

**Conflict notes carried from the build and review rounds.**  C-A1
(orchestrator ruling, prelude field dead, church substituted, booked by
Build-2).  C-A3 part 5 (review round, MA-1/MA-2/MA-3 mutation
collateral, item (a) left open for the user on leg (ii)'s `local`
field).  No new conflict note opens in the closing round.

**Exit.**  Battery measured PASS=432, FAIL=0, GATE-EXIT=0 against the
ESTIMATE of 428 slice and 432 wrapper.  The measured numbers match the
estimate.  Lib digest ec077852495cdc0ac9a7abd4eb2fe786 unchanged.
Nothing was staged, committed, stashed or checked out by the closing
round beyond the closer's own staging step, recorded separately.
