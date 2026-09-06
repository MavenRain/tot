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

## Stage B (2026-09-05): prelude:94 takes the hole spelling

Plan: `dev/M8-PLAN.md`, section "STAGE B", lines 1013 to 1479.  Rulings
covered: R-Q7 (the stop condition, accepted branch), R11 (the
`PASS-M8B-` namespace), C-A14 (the wrapper offset), C-C1 and C-D2 (no
assertion is weakened or deleted), plan section 3.2 (the substitution
move).  Conflict C-D3 of M7 is overturned by measurement and the walk
is booked below.

The stage ran in two halves.  Build-1 owned `stdlib/prelude.tot` and
the four literal measurements.  Build-2 owned `dev/gates.sh`, the two
`test/surface.ml` cases and this file.  No file under `lib/` moved, and
no file under `surface/`, `bin/`, `examples/`, `test/fixtures/`,
`dev/m8a/` or `dev/m7a/` moved.

### 1. Entry state

- `git -C /Users/oobi/Documents/tot rev-parse --short HEAD` = `cf6a4a1`,
  the M8 Stage A exit commit.
- `git status --porcelain -uall` at stage entry was EMPTY.  Stage B has
  no staged-plan tolerance, so an empty porcelain is the entry
  condition and it held.
- Entry battery, through the wrapper
  `zsh /Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh
  /Users/oobi/Documents/tot-m8-stageB-entry-gate.log 12 3600`:
  `BUILD-EXIT=0`, `GATE-EXIT=0`, `PASS=432`, `FAIL=` (empty),
  `RUNNER-EXIT=0`.  The wrapper reads the gate slice plus 4 (C-A14), so
  the entry slice is 428.
- Entry probes, each with the command that printed it:
  - `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh | wc -l` = `170`.
  - `rg -c 'PASS-M8' dev/gates.sh` = `10`.
  - `rg -c 'PASS-M8B-' dev/gates.sh` printed nothing and exited 1, so
    the `PASS-M8B-` namespace was free before this stage (R11).
  - `dev/gates.sh` md5 `2fef3ae2b771b5f0153c21113bbd07f6`, 4248 lines.
  - `test/surface.ml` md5 `9ae5b497d8350ec30dc3a26fdf1de2c5`, 2456
    lines.
  - `stdlib/prelude.tot` md5 `98178e9fb909a88b5651ee4b99f57ecc`, 230
    lines.
  - `dev/M8-BUILD-LOG.md` 602 lines, Stage A at line 3 and its closing
    round at line 556.  Stage B appends only.
- Entry values of the four Stage B literals, measured by Build-1 before
  the payload landed: `m6e_holes` 68, `m7d_ph` 46, `m7d_pa` 5, and the
  new `m8b_p94` 0.  The classifier summary line read `ANCHORS total=99
  expected-type-only=60 argument-driven=9 neither=30`.

### 2. What changed

`git status --porcelain -uall` at exit:

     M dev/M8-BUILD-LOG.md
     M dev/gates.sh
     M stdlib/prelude.tot
     M test/surface.ml

- `stdlib/prelude.tot:94` (Build-1, one token).  The cong0 motive reads
  `Eq _ (f a) (f z)` where it read `Eq B (f a) (f z)`.  No other token
  on that line moved, and line 93 and the `refl B (f a)` spelling are
  untouched.
- `dev/gates.sh:3193`, inside `PASS-M6E-GUARD-HOLES`.  The `m6e_holes`
  literal reads 69 where it read 68.  The leg is not restructured and
  the `m6e_pz` floor assertion is unchanged.
- `dev/gates.sh:3826`, inside `PASS-M7D-PRELUDE-HOLES`.  The `m7d_ph`
  literal reads 47 where it read 46.  `m7d_pa` was re-measured and
  stays 5, so it is left as written.  The leg is not restructured.
- `dev/gates.sh:3666`, inside `PASS-M7B-GUARD-ARG-HOLES`.  The
  `m7b_holed` literal reads 69 where it read 68.  That leg shares the
  corpus recipe with `PASS-M6E-GUARD-HOLES`, so the payload moves both
  by one.  The exit battery found it, and conflict note C-D10 holds the
  walk.  The leg is not restructured and its other four assertions are
  byte-identical to `cf6a4a1`.
- `dev/gates.sh:3178-3184`, `dev/gates.sh:3654-3657` and
  `dev/gates.sh:3809-3822`, comment text only.  The first two record
  the 68 to 69 walk in each of the two legs that share the corpus
  recipe.  The third records the 46 to 47 walk and retires the stale
  sentence that said `stdlib/prelude.tot:94` refuses the `_` spelling.
  No assertion moved with a comment.
- `dev/gates.sh:4201-4208`, the new leg `PASS-M8B-PRELUDE-94`.  It sits
  after `PASS-M8A-KERNEL-UNCHANGED` and before the ctxcat id 5 block
  that carries `PASS-M4FIX-INST-BRANCHING`.
- `test/surface.ml:2328-2355`, two new `cases` entries, M8B-1 and
  M8B-2, both with inline `~src` strings.  No file was added under
  `test/fixtures/` or `examples/`.
- `dev/M8-BUILD-LOG.md`, this section.  The Stage A section and its
  closing round are untouched.

The two ANCHORS want literals, `dev/gates.sh:3837`
(PASS-M7D-ANCHORS) and its copy at `dev/gates.sh:3216`
(PASS-M6E-ANCHORS), were NOT edited.  Build-1 measured the summary
line before and after the payload and it did not move, and the exit
battery measured it again.

### 3. Conflict notes

Each note keeps the C-D3 shape of `dev/M7-BUILD-LOG.md:2311-2341`: what
the plan says, what the tree says, what the build did, and the ruling
it acted under.  No note edits `dev/M8-PLAN.md`.

**C-D5, the line numbers of the two literal walks.**  The plan says, at
`dev/M8-PLAN.md:1235` and `:1238`, that `m6e_holes` is "pinned at
dev/gates.sh:3167 (current tree)" and, at `:1245`, that `m7d_ph` is
"asserted at dev/gates.sh:3792";  `dev/M8-PLAN.md:1115` and `:1118`
cite `dev/gates.sh:3161` and `dev/gates.sh:3792` for the same two
assertions.  The tree at `cf6a4a1` puts the `m6e_holes` assignment at
`dev/gates.sh:3181` and its assertion at `dev/gates.sh:3187`, and it
puts `m7d_ph` and `m7d_pa` at `dev/gates.sh:3809` and `:3810` with the
assertion at `dev/gates.sh:3812`.  What the build did: Build-1 measured
the true line numbers and reported them, and Build-2 edited those
lines, not the plan's.  After the comment edits and the new leg the two
assertions read at `dev/gates.sh:3193` and `dev/gates.sh:3826`.  Ruling
id: C-D4 precedent, the recipe in the tree is the authority over a plan
line number.

**C-D6, the M8B-1 source.**  The plan writes the case source, at
`dev/M8-PLAN.md:1392-1393`, as:

    def transported : Eq Nat (add 1 2) (add 2 1) :=
      cong0 Nat Nat (add 1 2) (add 2 1) (fun x => x) (refl Nat 3)

The tree refuses it.  Measured on the live tree on 2026-09-05 with the
re-spelled prelude in place, `_build/default/bin/tot.exe check` on that
exact source exits 1 and prints, verbatim:

    type mismatch: expected Nat, found Int

A bare numeral elaborates as `Int` while `add` is `Nat -> Nat -> Nat`,
so the refusal is about numeral literals and not about the re-spelled
motive.  What the build did: it wrote the plan source first, measured
the refusal, and then substituted the pre-probed source that carries
the same claim in the same shape:

    def transported : Eq Nat (add (succ zero) (succ (succ zero))) (add (succ (succ zero)) (succ zero)) :=
      cong0 Nat Nat (add (succ zero) (succ (succ zero))) (add (succ (succ zero)) (succ zero)) (fun x => x)
        (refl Nat (succ (succ (succ zero))))

That source exits 0 on the live tree.  It is a checklist-field
substitution, not a payload change, and the claim "cong0 still
elaborates and evaluates under the re-spelled motive" is unchanged.
Ruling id: plan section 3.2 (`dev/M8-PLAN.md:460`), first move, the
same move ruling C-A1 took in Stage A.

**C-D7, the trailing unit argument on a case entry.**  The plan says,
at `dev/M8-PLAN.md:1455-1457`, that both new `cases` entries take "the
trailing `()` the helper signature ends on".  The tree says otherwise
in two places.  The plan's own code blocks at `dev/M8-PLAN.md:1388-1395`
and `:1415-1422` end at `|tot} );` and at
`~want_suffix:"..." );`, with no `()`.  Every M8A entry in the tree,
`test/surface.ml:2320` to `:2327`, stores the partial application
without `()`, because `cases` holds thunks of type
`unit -> (unit, string) result`.  What the build did: it copied the
tree shape and the plan's code shape, so both new entries are partial
applications with no trailing `()`.  Case 2 uses `~want_suffix:`, never
`~contains:`.  Ruling id: C-D4 precedent, the code in the tree is the
authority over a checklist sentence.

**C-D8, where the new leg sits.**  The plan says, at
`dev/M8-PLAN.md:1447-1450`, that the new leg sits after
`PASS-M7E-DEBT-H` ("dev/gates.sh:3976, current tree") and before the
legacy `PASS-M4FIX-INST-BRANCHING` block ("dev/gates.sh:3978, reference
tree").  The tree says `PASS-M7E-DEBT-H` echoes at `dev/gates.sh:3995`
and `PASS-M4FIX-INST-BRANCHING` echoes at `dev/gates.sh:4221`, with the
four Stage A legs between them, because Stage A landed after the plan
was written.  What the build did: it put the leg at
`dev/gates.sh:4201-4208`, after `PASS-M8A-KERNEL-UNCHANGED` and before
the ctxcat id 5 block that carries `PASS-M4FIX-INST-BRANCHING`, which
holds both halves of the plan's ordering.  The position also holds the
data dependency: `PASS-M5D-HOLE-ANCHORS` writes
`$m5d_scratch/hole-sites.txt` at `dev/gates.sh:2233`, far above, and
`$m5d_scratch` is assigned once at `dev/gates.sh:2225` and removed only
by the EXIT trap at `dev/gates.sh:434`, which Stage B does not change.
Ruling id: C-D4 precedent.

**C-D9, the M7 refusal on record inside dev/gates.sh.**  The tree
carried the M7 refusal as a gate comment at `dev/gates.sh:3804-3806`:
"stdlib/prelude.tot:94 refuses the `_` spelling and keeps its explicit
one, which is conflict C-D3 and the orchestrator ruling of 2026-09-04".
The tree now says otherwise.  With the re-spell in place the classifier
writes `SITE stdlib/prelude.tot:94 head=Eq arg=0 anchor=[_] pos=check
bucket=E`, and `_build/default/bin/tot.exe check examples/church.tot`
exits 0.  Stage A's local-aware instantiation is what changed the
answer.  What the build did: it rewrote that comment to record the M7
measurement, the M8 Stage A cause and the 46 to 47 walk.  Only comment
text moved;  no assertion in the leg was weakened, deleted or moved.
Ruling id: R-Q7, accepted branch, so Stage B continues and no retreat
ruling is needed.

### 4. Decisions

1. **R-Q7 is on its accepted branch.**  Build-1 made the one-token edit
   at `stdlib/prelude.tot:94` and measured acceptance three ways: the
   re-spelled prelude bootstraps, `check examples/church.tot` exits 0,
   and the classifier writes `SITE stdlib/prelude.tot:94 head=Eq arg=0
   anchor=[_] pos=check bucket=E` where it wrote `anchor=[B]` before.
   The stop path did not fire, so Stage B ran to its exit.
2. **The two literal edits are in-place moves inside surviving legs.**
   Neither `PASS-M6E-GUARD-HOLES` nor `PASS-M7D-PRELUDE-HOLES` is
   restructured, split or reordered.  Their other assertions, the three
   guard exits, the `m6e_pz` floor, the deny envelope, `m7d_pa` and the
   `guard-classes.tot` exit, are byte-identical to `cf6a4a1`.  No
   assertion was weakened or deleted (C-C1, C-D2), and none was moved.
3. **`m7d_pa` was re-measured, not assumed.**  Build-1's recipe,
   `rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\].*bucket=A'`, printed
   5 before the payload and 5 after it.  The re-spelled site is
   `bucket=E`, so the A bucket does not move.  The literal is therefore
   left at 5, on a measurement and not on an assumption.
4. **The two ANCHORS want literals were not touched.**  Build-1
   measured the summary line on both sides of the payload and it read
   `ANCHORS total=99 expected-type-only=60 argument-driven=9
   neither=30` both times.  `dev/gates.sh:3837` and `dev/gates.sh:3216`
   carry that string unchanged.
5. **The new leg has a mutation proof.**  The leg asserts
   `[ "$m8b_p94" -eq 1 ]` over
   `rg -c 'SITE stdlib/prelude\.tot:94.*anchor=\[_\]'`.  The same recipe
   over the same classifier output printed 0 at `cf6a4a1`, before the
   one-token payload, and prints 1 after it, so the recipe discriminates
   the two spellings and the leg is not a tautology.  Reverting the
   payload does not print the leg red, because the fail-fast battery
   stops at `PASS-M6E-GUARD-HOLES` first;  the proof of the leg itself is
   the standalone recipe run of MB-1 in section 3d, where the count reads
   0 on the mutated tree.
6. **The two suite cases do not duplicate the leg.**  The leg reads one
   SITE line out of the classifier's file on disk.  The cases drive
   `Tot_surface.Run.script ~st:bst ~exec:false` over source strings, the
   path `Check.define` sits on.  A change to how the classifier formats
   a SITE line cannot make a case pass while the leg fails, or the
   reverse.  M8B-2 is the anti-vacuity half: it holds the one-hole
   refusal in place, so a re-spell that made every hole resolve would
   redden it.
7. **The plan's `{tot|...|tot}` string spelling was kept.**  The file
   carried only escaped OCaml strings at `cf6a4a1`, but a quoted string
   literal compiles on this tree and it satisfies the plan's "inline
   `~src` strings, no new file under test/fixtures/ or examples/"
   checklist item at `dev/M8-PLAN.md:1452-1454`.  The fallback to a
   `let m8b_... : string` binding was not needed.
8. **No new scratch directory.**  The leg reads
   `$m5d_scratch/hole-sites.txt`, which `PASS-M5D-HOLE-ANCHORS` writes
   at `dev/gates.sh:2233`, so the EXIT trap at `dev/gates.sh:434` is
   unchanged.
9. **Nothing outside the four owned paths moved.**  `lib/`, `surface/`,
   `bin/`, `examples/`, `test/fixtures/`, `dev/m8a/`, `dev/m7a/`,
   `dev/hole-anchors.py`, `dev/M8-PLAN.md` and `dev/M7-BUILD-LOG.md`
   are untouched.  Nothing was committed, pushed, checked out, stashed
   or cleaned.

### 3b. Conflict notes opened by the exit battery

**C-D10, a THIRD literal over the corpus holed-anchor count.**  The
plan names two literal walks for Stage B, `m6e_holes` at
`dev/M8-PLAN.md:1235`/`:1238` and `m7d_ph` at `:1245`, and the Stage B
review checklist at `dev/M8-PLAN.md:1441-1443` names the same two.  The
tree carries three literals over these counts, not two.
`PASS-M7B-GUARD-ARG-HOLES` reads the SAME corpus recipe as
`PASS-M6E-GUARD-HOLES`, `m7b_holed=$(rg -c 'anchor=\[_\]'
"$m5d_scratch/hole-sites.txt")`, and pinned it at 68 in its own leg.
The first exit battery after the two planned walks stopped there and
printed, verbatim:

    FAIL-M7B-GUARD-ARG-HOLES (c=0/0 slots=4 holed=69 env=2)

so the four guard exits, the slot count of 4 and the deny envelope all
held and the corpus count alone was stale.  What the build did: it
walked that literal 68 to 69 in place, on the measured value the leg
itself printed, and it recorded the walk in the leg's comment.  This is
the same class of in-place move as the two planned walks and it is the
same number, since the two legs share one recipe over one file.  The
leg keeps its name, its marker and all five assertions.  No assertion
was weakened, deleted or moved, and no red leg was made green by
choosing a number: 69 is what the recipe prints.  Ruling id: C-D4
precedent, the recipe in the tree is the authority, with plan section
3.2 for the record of the adjustment.

**C-D11, a load artefact on the first exit battery.**  The plan and the
brief say the exit battery is the authority on the PASS counts.  The
tree said, on the first run at 2026-09-05 10:22 with a load average of
45.96 and 14 users on the host:

    FAIL-M6D-COLD-OUTSIDE-BUDGET (exit=0/3/3)

with `m6d-bigcheck.tot: check budget exhausted (5 ms)` on stderr.  Leg
(b) of that gate is a 5 ms wall-clock budget over a cold bootstrap, and
its comment at `dev/gates.sh:3030-3039` records a healthy bracket of 5
to 15 ms probed on 2026-09-03, so the budget has no headroom at that
load.  What the build did: it changed nothing, waited for the load to
fall under the wrapper's threshold of 12 and re-ran.  The leg passed on
the next run, which reached `PASS-M6D-COLD-OUTSIDE-BUDGET` and stopped
further down at C-D10's leg instead.  The red is a load artefact of the
host, not a property of this stage's edits.  The red run is kept at
`/Users/oobi/Documents/tot-m8-probes/stage-b/gate-run1-loadred.log`.
Ruling id: measurement authority, the battery is re-run, never edited.

### 3c. Conflict note opened by the exit PASS count

**C-D12, the exit battery reads 434, not 435.**  The plan's ladder at
`dev/M8-PLAN.md:246-264` walks the gate slice `428 + 1 + 2 = 431`, one
new leg and two new suite cases, so the wrapper estimate is 435.  The
tree says `PASS=434` and `FAIL=` (empty) with `GATE-EXIT=0`.  The whole
difference is one line in the build phase, and every added assertion is
present and green:

- the new leg prints `PASS-M8B-PRELUDE-94` in the gate section, which
  is plus one;
- the surface suite prints `PASS M8B-1: ...` and `PASS M8B-2: ...`,
  which is plus two;
- the build phase prints ONE fewer `PASS` line, which is minus one.

The build phase runs `dune exec test/surface.exe 2>&1 | tail -3`
(`/Users/oobi/Documents/tot-m7-probes/stageA/battery.sh:16`), so only
the last three lines of the suite reach the log.  At `cf6a4a1` those
three lines were `PASS M8A-3: ...`, `PASS M8A-4: ...` and `M1 surface:
all tests green`, which is two `PASS` lines.  Now the last case is
M8B-2 and its helper `m7e_expect_source_error` prints the message it
matched (`test/surface.ml:712`), so the three lines are
`  expected error (m8b-hole-still-refused): 2:33: hole: no expected
type at this position`, `PASS M8B-2: ...` and `M1 surface: all tests
green`, which is one `PASS` line.  What the build did: it measured the
count, it booked 434 wrapper and 431 slice as the exit numbers, and it
changed nothing to reach 435.  The wrapper offset is 3 in this run and
not the 4 of C-A14, because one of the three tail lines is now the
expected error echo of M8B-2;  the gate section itself counts 431.  The count is a property of a three-line
tail in the runner, not of the tree's assertion set;  the suite itself
reports every case, and `M1 surface: all tests green` is in the log on
both sides.  Ruling id: measurement authority, the battery is the
authority on the PASS counts and the estimate yields to it.

### 3d. Mutation proofs (orchestrator ruling 4 of 2026-09-05)

Ruling R10 asks for one distinct one-edit mutation per leg.  The mutation
prover ran the three proofs below on the post-build tree, one at a time,
and restored each file byte for byte before the next one.  The baseline
for every run is the exit battery of section 6: wrapper `PASS=434`, `FAIL=`
(empty), `GATE-EXIT=0`.  The battery is fail-fast: the in-process suite
runs before the shell gate section, and the gate section exits at its
first red line, so a target that sits after an earlier red line is
shadowed and is proved by its own recipe instead.

**MB-1, the marker proof.**  Edit: `stdlib/prelude.tot:94`, the motive
`Eq _ (f a) (f z)` put back to the explicit `Eq B (f a) (f z)`.  Target:
`PASS-M8B-PRELUDE-94` (`dev/gates.sh:4201-4209`).  Result:
`FAIL-M6E-GUARD-HOLES (c=0/0/0 holes=68 pz=46 env=2)` at
`dev/gates.sh:3193`, `PASS=404`, `FAIL=1`, `GATE-EXIT=1`.  The corpus
count fell from 69 to 68 because the one holed anchor at line 94 left the
corpus, and the battery stopped there, before it reached the target leg
at line 4201.  The target is shadowed, so its recipe was run standalone
on the mutated tree: a fresh classifier log through
`python3 dev/hole-anchors.py --log` gives an `anchor=[_]` total of 68 and
`rg -c 'SITE stdlib/prelude\.tot:94.*anchor=\[_\]'` reads 0, so the
assertion `[ "$m8b_p94" -eq 1 ]` is false on the mutated tree.  The
ANCHORS summary line did not move (total=99 expected-type-only=60
argument-driven=9 neither=30).  Restore: `stdlib/prelude.tot` md5
`6013fa65389a1220f9a15059294701a0` before the edit and after the restore.

**MB-2, the M8B-1 proof.**  Edit: `test/surface.ml`, inside the M8B-1
source string, the refl argument `(refl Nat (succ (succ (succ zero))))`
changed to `(refl Nat (succ (succ zero)))`.  No other file touched.
Target: suite case M8B-1.  Result: `FAIL M8B-1: cong0 still elaborates
and evaluates under the re-spelled motive`, the only red line, with
`2:1: type mismatch: expected (((Eq Nat) (succ (succ (succ zero))))
(succ (succ (succ zero)))), found (((Eq Nat) (succ (succ zero))) (succ
(succ zero)))`;  every other suite case green, M8B-2 included;
`PASS=261`, `FAIL=1`, `GATE-EXIT=1`, the gate legs not reached.  Restore:
`test/surface.ml` md5 `b5792c2284c17235072227266c8715d4` before and
after, equal to the post-build digest.

**MB-3, the M8B-2 proof.**  The one-hole message has exactly one
production site, `surface/serror.ml:95`, and that file is on the
never-edit list of this stage, so the prover halted and the orchestrator
allowed a temporary one-character edit of that line for this proof only.
Edit: the format string `"%s: hole: no expected type at this position"`
became `"%s: hole: no expected type at this positionx"`.  Target: suite
case M8B-2.  Result: `FAIL M8B-2` red as required, plus the eight cases
that pin the same message text through `want_suffix` (M6C-6, M7A-11,
M7A-12, M7C-1, M7C-2, M7C-3, M7C-5 and M8A-3), nine red cases in all,
`PASS=252`, `FAIL=10`, `GATE-EXIT=1`, the gate legs not reached.  The
siblings are the expected collateral of a message-text mutation and not
a finding.  Restore: `surface/serror.ml` md5
`7e3f80e4cf5e5955c3659b73226c1b4e` before and after, and the file is
absent from `git status --porcelain -uall` after the restore.
### 5. Re-derivations, old value then new value

| what | recipe | old | new |
|---|---|---|---|
| corpus holed anchors, `m6e_holes` (`dev/gates.sh:3193`) | `rg -c 'anchor=\[_\]' "$m5d_scratch/hole-sites.txt"` | 68 | 69 |
| corpus holed anchors, `m7b_holed` (`dev/gates.sh:3666`) | the same recipe, second leg | 68 | 69 |
| prelude holed anchors, `m7d_ph` (`dev/gates.sh:3826`) | `rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\]'` | 46 | 47 |
| prelude argument-driven, `m7d_pa` (`dev/gates.sh:3826`) | `rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\].*bucket=A'` | 5 | 5 (unchanged) |
| prelude:94 hole, `m8b_p94` (`dev/gates.sh:4205`) | `rg -c 'SITE stdlib/prelude\.tot:94.*anchor=\[_\]'` | 0 | 1 |
| ANCHORS summary line | `rg -o '^ANCHORS total=...' "$GATE_LOG"` | `ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30` | the same string |
| gate echo sites | `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh \| wc -l` | 170 | 171 |
| PASS-M8 namespace | `rg -c 'PASS-M8' dev/gates.sh` | 10 | 12 |
| PASS-M8B- namespace | `rg -c 'PASS-M8B-' dev/gates.sh` | exit 1 (none) | 2 |
| lib digest, 17 files | `PASS-M8A-KERNEL-UNCHANGED`, which recomputes it | ec077852495cdc0ac9a7abd4eb2fe786 | ec077852495cdc0ac9a7abd4eb2fe786 (unchanged) |
| M5D watchdog tier count | `PASS-M5D-TIERS` (`dev/gates.sh:2338`) | 233 | 233 (unchanged) |
| M7A conservativity digest | `PASS-M7A-CONSERVATIVITY` (`dev/gates.sh:3461`) | f1450de0006de4b7339b2f39ec2e2e50, 43 lines | the same (unchanged) |
| M7A infer-settle digest | `PASS-M7A-INFER-SETTLE-BUDGET` (`dev/gates.sh:3606`) | 9278f6b7034f2f65b6d789e9e1d74a90 | the same (unchanged) |
| M6E sealed transcript | `PASS-M6E-TRANSCRIPT-RESEALED` | sealed | the same (unchanged) |
| battery wrapper PASS | the wrapper's `PASS=` line | 432 | 434 |
| gate slice | wrapper PASS minus the build-phase `PASS` lines (4 at entry per C-A14, 3 at exit per C-D12) | 428 | 431 |

Every at-risk leg was re-measured by the exit battery, not assumed.
Each of them recomputes its own value and compares it to its pinned
literal, so a green marker in
`/Users/oobi/Documents/tot-m8-stageB-gate.log` is the measurement:
`PASS-M5D-TIERS` (line 457), `PASS-M6E-ANCHORS` (490),
`PASS-M6E-TRANSCRIPT-RESEALED` (491), `PASS-M7A-CONSERVATIVITY` (495),
`PASS-M7A-INFER-SETTLE-BUDGET` (498), `PASS-M7D-ANCHORS` (505) and
`PASS-M8A-KERNEL-UNCHANGED` (515).

### 6. Exit state

**Exit battery.**  The wrapper
`zsh /Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh
/Users/oobi/Documents/tot-m8-stageB-gate.log 12 3600` read
`BUILD-EXIT=0`, `GATE-EXIT=0`, `PASS=434`, `FAIL=` (empty),
`RUNNER-EXIT=0`, `WAITED=0 LOAD=10.95`, `M7A-MARKERS=7`,
`M7B-MARKERS=2` and `M7B-SUITE=3`.  `PASS=434` is the WRAPPER number;
the gate slice is 431, because the build phase of this log holds 3
`PASS` lines and not the 4 of C-A14 (C-D12: the surface tail spends one
of its three lines on the expected error echo of M8B-2).  The ESTIMATE
was 435 wrapper and 431 slice, so the slice matches the estimate, the
wrapper is one line short of it, and conflict note C-D12 holds that
one-line difference.  Two earlier runs are on record: the first stopped at the
wall-clock leg under a load average of 45.96 (C-D11), the second
stopped at the third corpus literal (C-D10).

**One marker added.**  `PASS-M8B-PRELUDE-94` (`dev/gates.sh:4207`), and
no other `PASS-M8B-` name.  None of the dropped names
`PASS-M8B-ANCHORS`, `PASS-M8B-RESPELL-COUNT`, `PASS-M8A-CONSERVATIVITY`,
`PASS-M8D-SELF-ENTRY` or `PASS-M8C-TRANSCRIPT-RESEAL` was added.  Stage
A's four markers are all still present at `dev/gates.sh:4099`, `:4129`,
`:4167` and `:4195`.

**Two suite cases added.**  `M8B-1: cong0 still elaborates and
evaluates under the re-spelled motive` (`test/surface.ml:2342`) and
`M8B-2: the one-hole message for a genuinely undetermined site is
unchanged` (`test/surface.ml:2350`).  Both print a PASS line in the
exit log, at lines 341 and 343.

**Exit file measures.**  `dev/gates.sh` md5
`a83d9933bcbbc4a2f229585c0bf0ba5e`, 4271 lines (`cf6a4a1`:
`2fef3ae2b771b5f0153c21113bbd07f6`, 4248 lines).  `test/surface.ml` md5
`b5792c2284c17235072227266c8715d4`, 2484 lines (`cf6a4a1`:
`9ae5b497d8350ec30dc3a26fdf1de2c5`, 2456 lines).  `stdlib/prelude.tot`
md5 `6013fa65389a1220f9a15059294701a0`, 230 lines (`cf6a4a1`:
`98178e9fb909a88b5651ee4b99f57ecc`).

**An external commit landed on this repo mid-stage.**  At 2026-09-05
10:24:56 -0700, between the second and third exit battery runs, commit
`98e154c682974857b5b3ef60dbb069493ecde80e`, subject `M30: write a
shareable repro for a shrunk divergence`, was created on `main` with
`cf6a4a1` as its parent.  Its stat is `dev/M8-BUILD-LOG.md` 176 lines,
`dev/gates.sh` 37 lines, `stdlib/prelude.tot` 2 lines and
`test/surface.ml` 28 lines, so it swept up the Stage B working tree as
it stood at that minute.  Its subject belongs to another repository's
M30 milestone, so it is not a Stage B commit and no agent of this stage
made it.  No Stage B agent commits, pushes, checks out, stashes or
cleans, and none did.  The consequence for the hand-off: most of Stage
B is now inside `98e154c` and only the last edits are unstaged, so
`git status --porcelain -uall` at exit reads

     M dev/M8-BUILD-LOG.md
     M dev/gates.sh

where the stage would otherwise show four modified paths.  The content
on disk is complete and green, which the exit battery measures.  The
user owns the decision on that commit;  this build does not touch it.

**Exit.**  Battery measured `PASS=434`, `FAIL=0`, `GATE-EXIT=0`, so the
gate slice is 431, equal to the ESTIMATE, with the wrapper one line
below its estimate of 435 (C-D12).  The lib digest
`ec077852495cdc0ac9a7abd4eb2fe786` is unchanged, both ANCHORS want
literals are unchanged, and every at-risk leg is green.  Nothing was
staged, committed, pushed, checked out, stashed or cleaned by Build-2.

### Review-round fixes (2026-09-05)

Five confirmed review findings landed after the stage closed green.
Finding 1 (high) names one cause: the marker `PASS-M8B-PRELUDE-94` read
the file and the source line only, so it did not prove its own claim
about the motive.  Findings 3, 4 and 5 name a second cause: the log
booked the two suite cases and the MB-2 mutation as evidence for the
Stage B edit, which they are not.  Finding 6 names a third: the suite
case M8B-2 pinned the message text only, where its siblings pin the
position too.  No predicate was weakened and no assertion was deleted.
The `PASS-M8B-` marker count stays 1, the suite case count stays 2, the
lib digest is untouched, and both ANCHORS want literals
(`dev/gates.sh:3216` and `dev/gates.sh:3837`) keep their bytes.
`stdlib/prelude.tot` keeps the bytes the stage closed with, md5
`6013fa65389a1220f9a15059294701a0`.  The round touched `dev/gates.sh`,
`test/surface.ml` and this file, and nothing else.

**What changed.  Every address below was printed by `rg -n` on the
edited file, after the edit landed.**

1. Finding 1.  The marker recipe (`dev/gates.sh:4213`) now reads
   `rg -c 'SITE stdlib/prelude\.tot:94 head=Eq arg=0 anchor=\[_\] pos=check bucket=E'`
   where it read `rg -c 'SITE stdlib/prelude\.tot:94.*anchor=\[_\]'`.
   Line 94 emits THREE records, one for each argument slot the
   classifier sees, so the old recipe counted 1 on every tree that put
   the hole in any one of the three.  The new recipe pins head, argument
   index, anchor, position and bucket, which is the record shape
   `PASS-M7B-GUARD-ARG-HOLES` already uses (`dev/gates.sh:3660`).  The
   assertion is unchanged, `[ "$m8b_p94" -eq 1 ]`, and the value on the
   tree is still 1.  Conflict note C-D13 below holds the departure from
   the plan;  proof MB-4 below holds the discrimination.  The section 5
   row for `m8b_p94` books the recipe and the address of the BUILD, not
   of the review round.
2. Finding 6.  Suite case M8B-2 (`test/surface.ml:2360`) now runs
   through `m6c_expect_err_line` (`test/surface.ml:874`), which asserts
   the whole message by equality, with the want string
   `2:33: hole: no expected type at this position`.  It ran through
   `m7e_expect_source_error`, whose `~want_suffix` field held the same
   message text without the position.  That helper reads a SUFFIX
   (`test/surface.ml:714`), so it never sees the position at all.
   The source string is unchanged, byte for byte the plan
   block at `dev/M8-PLAN.md:1415-1422`, and the case title is unchanged.
   The helper is the one M7A-11 and M7A-12 use for the same message
   (`test/surface.ml:2210-2215`), so the case now names the
   applied-lambda site of its own title.  This is a STRONGER assertion,
   not a moved one.  Its measured consequence is in conflict note C-D14.
3. Findings 3 and 4.  The block comment above the two cases
   (`test/surface.ml:2341-2351`) records what the two cases prove.
   Neither WITNESSES the Stage B edit: with the pre-stage prelude in
   place, through the `TOT_PRELUDE` override
   (`surface/bootstrap.ml:245-247`), both cases stay green.  An
   ill-typed motive does not redden M8B-1 either, because the shared
   bootstrap stops first and no case in the list runs.  M8B-1 is booked
   from here on as a REGRESSION GUARD for a consumer of `cong0`, and
   MB-2 as a LIVENESS proof for that case.  The marker
   `PASS-M8B-PRELUDE-94` is the only witness for the spelling of
   `stdlib/prelude.tot:94`.
4. Finding 5.  A fourth mutation proof, MB-4, is recorded below.  It
   keeps the corpus count at 69 and moves the hole off the motive, which
   is the one mutation that separates the new recipe from the old one.

**Conflict note C-D13 (2026-09-05): the marker recipe departs from the
plan's fenced block.**

1. The plan says.  `dev/M8-PLAN.md:1323-1332` gives the leg as a fenced
   block, and its recipe line reads

       m8b_p94=$(rg -c 'SITE stdlib/prelude\.tot:94.*anchor=\[_\]' "$m5d_scratch/hole-sites.txt" || echo 0)

   The block is quoted here verbatim.  The plan text around it says the
   leg holds "One SITE line in the classifier's log carries anchor=[_]
   at that exact source line".
2. The tree says.  The classifier emits three records for line 94, one
   for each argument slot it sees:

       SITE stdlib/prelude.tot:94 head=subst0 arg=0 anchor=[A] pos=check bucket=N
       SITE stdlib/prelude.tot:94 head=Eq arg=0 anchor=[_] pos=check bucket=E
       SITE stdlib/prelude.tot:94 head=refl arg=0 anchor=[B] pos=check bucket=N

   The plan recipe matches on the file, the line and the anchor, so it
   reads 1 for the motive record, for the `subst0` record and for the
   `refl` record alike.  MB-4 measures that: on a tree whose hole sits
   on the `refl` argument the plan recipe still reads 1.
3. What the build did.  The review round pinned the whole record,
   `head=Eq arg=0 anchor=[_] pos=check bucket=E` (`dev/gates.sh:4213`).
   The assertion, the marker name and the failure arm are unchanged.
   The value on the tree is 1, so the leg is green and no literal was
   edited to make it green.
4. The ruling.  Plan section 3.2 allows a checklist-field substitution
   that carries the same claim.  The claim the plan states is that the
   motive at line 94 carries the hole;  the plan recipe does not test
   it, the tree recipe does.  `dev/M8-PLAN.md` is not edited.

**Conflict note C-D14 (2026-09-05): the wrapper offset walks 3 back to
4, and the gate slice does not move.**

1. The record says.  C-D12 books a wrapper offset of 3 and a wrapper
   `PASS=434` for slice 431.  The reason it books is that the wrapper
   runner pipes the suite through `tail -3`
   (`tot-m7-probes/stageA/battery.sh:16`), and one of those three lines
   was the expected-error echo of M8B-2, which is not a `PASS` line.
2. The tree says.  The M8B-2 fix of item 2 replaces
   `m7e_expect_source_error`, which prints that echo, with
   `m6c_expect_err_line`, which prints nothing.  The last three suite
   lines are now `PASS M8B-1`, `PASS M8B-2` and the all-green line, so
   the build phase of the log holds 4 `PASS` lines again, the C-A14
   offset.
3. What the build did.  Nothing.  The offset is an artefact of the
   wrapper's `tail -3`, not a tree measure.  The gate slice, which is
   the number the ladder counts, stays 431.
4. The ruling.  The battery is the authority, so the measured wrapper
   number is booked as it printed, in the exit paragraph below.  The
   estimate of section 2.2 of the plan, 431 for the slice, is met.

**MB-4, the second marker proof (finding 5).**  Edit:
`stdlib/prelude.tot:94`, the motive put back to the explicit
`Eq B (f a) (f z)` AND the hole moved to the `refl` argument, so the
line reads

    fun A B a b f h => subst0 A a b (fun z => Eq B (f a) (f z)) h (refl _ (f a))

Target: `PASS-M8B-PRELUDE-94` (`dev/gates.sh:4201-4216`).  The mutated
tree does not bootstrap: with the file in place through the
`TOT_PRELUDE` override, `test/surface.exe` prints
`bootstrap failed: 94:71: hole: no expected type at this position` and
runs no case, so the battery stops long before the gate section and the
target is shadowed, as it was for MB-1.  Every other spelling of line 94
that moves the hole off the motive stops the bootstrap in the same way,
`subst0 _ a b` with `94:29: hole: expected Type 0` among them, so no
tree exists on which a live battery can carry this mutation to the leg.
The proof is therefore on the leg's own recipe, run standalone on the
mutated tree, which is the channel MB-1 also used.  Measured, with a
fresh classifier log each time
(`python3 dev/hole-anchors.py --log <path>`):

| field | tree | MB-4 tree |
|---|---|---|
| line 94 records | `head=subst0 anchor=[A]`, `head=Eq anchor=[_]`, `head=refl anchor=[B]` | `head=subst0 anchor=[A]`, `head=Eq anchor=[B]`, `head=refl anchor=[_]` |
| plan recipe, `:94.*anchor=\[_\]` | 1 | 1 |
| tree recipe, the whole record | 1 | 0 |
| corpus holed anchors | 69 | 69 |
| prelude holed anchors | 47 | 47 |
| ANCHORS summary line | total=99 expected-type-only=60 argument-driven=9 neither=30 | the same string |

So the mutation leaves `PASS-M6E-GUARD-HOLES`, `PASS-M7B-GUARD-ARG-
HOLES`, `PASS-M7D-PRELUDE-HOLES`, `PASS-M7D-ANCHORS` and
`PASS-M6E-ANCHORS` with their pinned values, and only the marker recipe
falls, from 1 to 0, which makes `[ "$m8b_p94" -eq 1 ]` false.  The plan
recipe does not fall, which is finding 1 measured on the tree.  Restore:
`stdlib/prelude.tot` md5 `6013fa65389a1220f9a15059294701a0` before the
edit and after the restore, and the file is absent from
`git status --porcelain -uall` after the restore.  Runner and logs:
`/Users/oobi/Documents/tot-m8-probes/stage-b/rf-mb4.sh`,
`rf/sites-base.txt` and `rf/sites-mb4.txt`.

**Re-derivations of the review round, old value then new value.**

| what | recipe | old | new |
|---|---|---|---|
| marker recipe, `m8b_p94` (`dev/gates.sh:4213`) | the record match, see C-D13 | `:94.*anchor=\[_\]`, reads 1 | the whole record, reads 1 |
| M8B-2 helper (`test/surface.ml:2361`) | the suite | `m7e_expect_source_error`, suffix only | `m6c_expect_err_line`, whole message |
| suite `PASS` lines | `dune exec test/surface.exe \| rg -c '^PASS '` | 154 | 154 |
| `dev/gates.sh` | `wc -l`, `md5` | 4271, a83d9933bcbbc4a2f229585c0bf0ba5e | 4279, 74c256e305db07dcef24b0a9e90c9bb8 |
| `test/surface.ml` | `wc -l`, `md5` | 2484, b5792c2284c17235072227266c8715d4 | 2494, 834f0a9224e94fec0fb6f47011fe9ca6 |
| `stdlib/prelude.tot` | `md5` | 6013fa65389a1220f9a15059294701a0 | the same (untouched) |
| `PASS-M8B-` names | `rg -c 'PASS-M8B-' dev/gates.sh` | 2 | 2 |
| `PASS-M8` names | `rg -c 'PASS-M8' dev/gates.sh` | 12 | 12 |
| gate echo sites | `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh \| wc -l` | 171 | 171 |
| build-phase `PASS` lines (the wrapper offset) | the wrapper's `tail -3` of the suite | 3 (C-D12) | 4 (C-D14) |

**Review-round battery.**  The wrapper
`zsh /Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh
/Users/oobi/Documents/tot-m8-stageB-review-gate.log 12 3600` read
`BUILD-EXIT=0`, `GATE-EXIT=0`, `PASS=435`, `FAIL=` (empty),
`RUNNER-EXIT=0`, `WAITED=0 LOAD=5.89`, `M7A-MARKERS=7`,
`M7B-MARKERS=2` and `M7B-SUITE=3`, on the first run, with no wall-clock
retry.  `PASS=435` is the WRAPPER number.  The build phase of this log
holds 4 `PASS` lines (lines 9, 10, 13 and 14), the C-A14 offset, so the
GATE SLICE is 431, the same slice the exit battery measured and the
number plan section 2.2 estimates.  C-D14 above holds the walk of the
offset.

`PASS-M8B-PRELUDE-94` is green at line 516 of that log, on the new
recipe.  Both suite cases are green in the gate slice as well, at lines
342 and 343.  Every at-risk leg was re-measured by this battery and each
recomputes its own value: `PASS-M5D-TIERS` (line 457),
`PASS-M6E-ANCHORS` (490), `PASS-M6E-TRANSCRIPT-RESEALED` (491),
`PASS-M7A-CONSERVATIVITY` (495), `PASS-M7A-INFER-SETTLE-BUDGET` (498),
`PASS-M7D-ANCHORS` (505) and `PASS-M8A-KERNEL-UNCHANGED` (515).  The
lib digest is unchanged and neither ANCHORS want literal was edited.

`git status --porcelain -uall` at the end of the round reads

     M dev/M8-BUILD-LOG.md
     M dev/gates.sh
     M test/surface.ml

`test/surface.ml` is modified again because the review round edits it;
commit `98e154c` holds its build-state bytes.  `stdlib/prelude.tot` is
absent, as it was at exit.  Nothing was staged, committed, pushed,
checked out, stashed or cleaned by this round.

## Closing round, 2026-09-05

**Final battery.**  The closer ran the wrapper into
`/Users/oobi/Documents/tot-m8-stageB-close-gate.log`.  It read
`BUILD-EXIT=0`, `GATE-EXIT=0`, `PASS=435`, `FAIL=` (empty),
`RUNNER-EXIT=0`, `WAITED=0 LOAD=4.00`.  `PASS=435` is the WRAPPER
number.  The build phase of this log holds 4 `PASS` lines, the C-A14
offset (C-D14), so the GATE SLICE is 431.  Both numbers match the
ESTIMATE of 435 wrapper and 431 slice, and they match the review-round
battery above, line for line on the count.  No new conflict note is
needed for the closing round.

**One marker, confirmed present in dev/gates.sh.**

1. PASS-M8B-PRELUDE-94 (gates.sh:4201, echo at 4215)

**Two suite cases, confirmed present in test/surface.ml.**

1. M8B-1: cong0 still elaborates and evaluates under the re-spelled
   motive (test/surface.ml:2352).
2. M8B-2: the one-hole message for a genuinely undetermined site is
   unchanged (test/surface.ml:2360).

**Re-derived literals, closing round, old value then new value.**

| what | recipe | old | new |
|---|---|---|---|
| gate echo sites | `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh \| wc -l` | 170 | 171 |
| PASS-M8B- namespace | `rg -c 'PASS-M8B-' dev/gates.sh` | exit 1 (none) | 2 |
| PASS-M8 namespace | `rg -c 'PASS-M8' dev/gates.sh` | 10 | 12 |
| m6e_holes | gates.sh:3193 recipe | 68 | 69 |
| m7d_ph | gates.sh recipe | 46 | 47 |
| m7d_pa | gates.sh recipe | 5 | 5 (unchanged) |
| m8b_p94 | gates.sh:4213, whole-record match (C-D13) | 0 | 1 |
| lib digest, 17 files | `cat` in plan order, `md5` | ec077852495cdc0ac9a7abd4eb2fe786 | ec077852495cdc0ac9a7abd4eb2fe786 (unchanged) |
| ANCHORS summary line | classifier | total=99 expected-type-only=60 argument-driven=9 neither=30 | the same string (unchanged) |
| `dev/gates.sh` | `wc -l`, `md5` | 4248, 2fef3ae2b771b5f0153c21113bbd07f6 | 4279, 74c256e305db07dcef24b0a9e90c9bb8 |
| `test/surface.ml` | `wc -l`, `md5` | 2456, 9ae5b497d8350ec30dc3a26fdf1de2c5 | 2494, 834f0a9224e94fec0fb6f47011fe9ca6 |
| `stdlib/prelude.tot` | `wc -l`, `md5` | 230, 98178e9fb909a88b5651ee4b99f57ecc | 230, 6013fa65389a1220f9a15059294701a0 |

**Conflict notes carried from the build and review rounds.**  C-D3 of
M7 is overturned by measurement (Stage A changed the answer).  C-A1
(prelude field dead, church substituted, precedent for the move made
here).  C-D7 (trailing unit argument, tree shape wins over the plan
sentence).  C-D12 (wrapper offset walked to 3, wrapper read 434 for one
build round).  C-D13 (the marker recipe pins the whole record, not the
plan's file-line-anchor match).  C-D14 (the offset walks back to 4 once
M8B-2 stops printing the expected-error echo, wrapper reads 435 again).
Section 3d (mutation proofs MB-1 through MB-4) stands as recorded; this
round does not duplicate it.  No new conflict note opens in the closing
round.

**Exit.**  Battery measured `PASS=435`, `FAIL=0`, `GATE-EXIT=0`, so the
gate slice is 431, equal to the ESTIMATE and equal to the review-round
measurement.  Lib digest `ec077852495cdc0ac9a7abd4eb2fe786` is
unchanged, both ANCHORS want literals are unchanged, and every at-risk
leg is green.  `git status --porcelain -uall` at this point reads

     M dev/M8-BUILD-LOG.md
     M dev/gates.sh
     M test/surface.ml

`stdlib/prelude.tot` carries no working-tree change because commit
`98e154c` already holds its Stage B content (C-B6, waived).  Nothing
was staged, committed, pushed, checked out, stashed or cleaned by the
closing round beyond the closer's own staging step, recorded
separately.

## Stage C (2026-09-05): the miss path reports every hole

Items 8, 9 and 10 of the M7 hand-off.  Item 8 pins the shape of the
multi-hole reporting tail (ruling R-Q5, Option A: positions only, never
a synthesized type).  Item 9 gives `test/fixtures/s0-erased-guard.tot`
a route through the gate battery.  Item 10 carries the tail onto the
prelude miss path.  The stage adds no admission rule and no new
elaboration.  It does not write `stdlib/prelude.tot`.

### 1. Entry state

Entry commit `d679ab5`, the M8 Stage B exit commit.  `git status
--porcelain -uall` printed NOTHING at entry, so blocker C-C1 did not
fire.  The entry battery, run through the wrapper
(`tot-m7-probes/stageB/battery-wait.sh`) into
`tot-m8-stageC-entry-gate.log`, printed `BUILD-EXIT=0`, `GATE-EXIT=0`,
`PASS=435` at the wrapper and an empty `FAIL=` line; the slice recipe
(`tot-m8-probes/stage-c/draft/slice.sh`) printed `SLICE=431` with
`SLICE-BOUNDS=14,517`.  431 plus the C-A14 offset of 4 is the 435 the
wrapper printed.

Entry sizes and digests, measured:

| path | lines | md5 |
| --- | --- | --- |
| `dev/gates.sh` | 4279 | `74c256e305db07dcef24b0a9e90c9bb8` |
| `test/surface.ml` | 2494 | `834f0a9224e94fec0fb6f47011fe9ca6` |
| `dev/M8-BUILD-LOG.md` | 1344 | `20921e56925f156a6a32db1e1b1d724c` |
| `surface/bootstrap.ml` | 475 | `0a9e452969f41c077c940526b75e08d3` |
| `bin/tot.ml` | 327 | `c902e72b66732def7e6f4af36af4359d` |
| `stdlib/prelude.tot` | 230 | `6013fa65389a1220f9a15059294701a0` |

At entry `rg -c 'PASS-M8C-' dev/gates.sh` exited 1 with no match, and so
did `rg -c 's0-erased-guard' dev/gates.sh`.  `rg -c 'PASS-M8'
dev/gates.sh` printed 12.  Ruling R11 held: the `PASS-M8C-` namespace
was free and every Stage A and Stage B marker was present.

### 2. What changed

#### 2.1 `surface/bootstrap.ml` (Build-1)

Item 10 adds `split_after_name_holed`, `fold_prelude_items_tailed` and
`state_of_src_tailed`.  `Parser.parse_with_holes` is called EXACTLY
once, the three-phase split is applied to the ITEM half of each pair,
and `Run.hole_tail` is attached to the error of the failing item.
`cached_state_of_src` widens to `(Run.state, Serror.t * string option)
result`; its hit branch and its `Cache.save` are untouched.
`cached_state` keeps its signature through `Result.map_error fst`.
`state_of_src` (`:381`) and `state ()` (`:404`) are unchanged in line,
in signature and in behaviour.  Exit size 550 lines, md5
`17deba9637a69ef4be760f3b24fcbffd`.

#### 2.2 `bin/tot.ml` (Build-1)

The prelude-error arm of `run_with_prelude` gains `Option.iter
prerr_endline tail;` after the existing `prerr_endline`, the exact
expression the target-path arm at `:121` already uses.  No other arm
changes.  Exit size 335 lines, md5 `6a964d565ed1f5b59ffedbb0c06f2d32`.

#### 2.3 `dev/fixtures/` (Build-1)

Two new gate-only fixtures.  `dev/fixtures/m8c-hole-positions.tot`, 6
lines, md5 `3410918ea313f630b4e1957a650e8ad8`, is byte-identical to the
plan block at `dev/M8-PLAN.md:1772-1777`.
`dev/fixtures/m8c-prelude-tail-probe.tot`, 1 line, md5
`bd1846b58897a65c7e355367489ef8d0`, is the plan line
`dev/M8-PLAN.md:1841`.  Both live under `dev/fixtures/`, outside the two
globs `dev/gen-m5e-transcript.sh:13` walks, so the sealed transcript
gains no block.

#### 2.4 `dev/gates.sh` (Build-2)

One new block of 114 lines, three legs, in the slot the M8B block left
free.  The block sits between the FAIL arm of `PASS-M8B-PRELUDE-94` and
the legacy `ctxcat id 5` comment, with ONE blank line on each side, so
`PASS-M4FIX-INST-BRANCHING` and `PASS-M5B-BRANCHING-20` stay the last
two legs of the file.

Every leg sends stdout and stderr to SEPARATE files under
`$m5d_scratch`, pins the exact line count of each stream, pins each
expected line as a WHOLE string through `awk 'NR==k'`, and pins the exit
code.  No leg matches a fragment and no leg pins a count alone.  The
record shape is the M7C block's; the private cache dir is the
`PASS-M7D-CACHE-KEY` idiom.

- `PASS-M8C-HOLE-POSITIONS` (item 8, R-Q5).  `check` on
  `dev/fixtures/m8c-hole-positions.tot`: exit 1, stdout 0 lines and
  empty, stderr EXACTLY 2 lines, line 1 the argument path plus
  `:6:14: hole: no expected type at this position`, line 2 the whole
  string `3 more hole(s) at 6:24, 6:36, 6:47`.
- `PASS-M8C-S0-DRIVER` (item 9, A1-F6 and R-F7).  `run --no-prelude` on
  `test/fixtures/s0-erased-guard.tot`: exit 0, stderr 0 lines and empty,
  stdout EXACTLY 7 lines, all seven pinned in order as whole strings
  (ruling SC-Q1, answer (a)).
- `PASS-M8C-PRELUDE-TAIL` (item 10, A1-F4 and R-Q6).  A scratch copy of
  `stdlib/prelude.tot` is patched by two `sd -s` calls, then `check` runs
  under `TOT_CACHE_DIR="$m8c_ck"` and `TOT_PRELUDE="$m8c_alt"`: exit 1,
  stdout 0 lines and empty, stderr EXACTLY 2 lines, `prelude: 93:54:
  hole: no expected type at this position` then `2 more hole(s) at
  94:48, 94:73`.  The leg also pins that each substitution pattern
  occurs EXACTLY ONCE in `stdlib/prelude.tot`, so a silent no-op patch
  cannot make the leg vacuous.

One further line of `dev/gates.sh` changed, at `:1475`, under ruling
SC-H1; see conflict note C-D15.  The tier literal of `PASS-M5D-TIERS`
moved in place; see section 5.  `dev/gates.sh` exits at 4401 lines, md5
`44278c9ade5a25573cb0cea212a1d4c6`.  `zsh -n dev/gates.sh` exits 0.

#### 2.5 `test/surface.ml` (Build-2)

Two helpers above the `cases` list and three tuples just before its
closing bracket, after the two M8B pairs.  Every case runs IN PROCESS.
No case shells `_build/default/bin/tot.exe`.

`m8c_replace_all` makes one literal, non-overlapping substitution over a
source string and returns the substitution COUNT beside the patched
text.  It is written over the index list of the subject with `List.init`,
`List.filter` and `List.fold_left`, so it uses no loop keyword.
`m8c_prelude_tail_on_miss` reads `stdlib/prelude.tot` through
`In_channel.with_open_text`, applies the two substitutions IN MEMORY,
refuses a patch that did not match exactly once on each pattern, then
asserts `Bootstrap.state_of_src_tailed patched` against `Error (e, tail)`
with `Serror.to_string e = "93:54: hole: no expected type at this
position"` and `tail = Some "2 more hole(s) at 94:48, 94:73"`.  It opens
no cache directory, which is what separates it from the gate leg.

M8C-1 and M8C-2 call `m7c_expect_tail` on the plan's ORDINARY OCaml
string literals, stored partially applied with no trailing unit
argument, because the `cases` list holds thunks.  The `{tot|...|tot}`
form was NOT used: it carries a leading newline, which is why M8B-2
reports 2:33 and not 1:33.  Both plan literals compiled as written, so
no `let m8c_... : string` binding was needed.  `test/surface.ml` exits at
2579 lines, md5 `c8e1a1945662b71864b4f34b5112cae5`.

#### 2.6 `dev/M8-BUILD-LOG.md` (Build-2)

This section, appended after line 1344.  The Stage A section at `:3`,
the Stage B section at `:604` and its closing round at `:1278` were not
rewritten.

### 3. Conflict notes

**C-D15.  `PASS-D-PRELUDE-ONEREAD` counts a spelling item 10 renames.**
What the plan says: the AT-RISK list of Stage C names eight legs, and
`PASS-D-PRELUDE-ONEREAD` is not among them; the plan predicts that no
other leg moves.  What the tree says: `dev/gates.sh:1475` counted the
application sites of `state_of_src` to `src` with `rg -c
'[^_]state_of_src src'` and `dev/gates.sh:1484` pins that count at 3.
Item 10 rewrites the cache-MISS branch to `state_of_src_tailed src`,
which the narrow pattern does not match, so the recipe printed 2 and the
fail-fast battery stopped with `FAIL-D-PRELUDE-ONEREAD (calls=0 srcs=2
exit=1)`, `GATE-EXIT=1` and slice 345.  What I did: under orchestrator
ruling SC-H1 I widened ONLY the pattern on `dev/gates.sh:1475` to
`[^_]state_of_src(_tailed)? src`, left every other byte of that line
alone, and KEPT the literal 3 at `:1484`.  The edit is one line in place,
so the file kept its line count and every pinned line number at the time
of the edit.  Measurement chain: 3 before item 10, 2 after item 10 under
the old pattern, 3 after item 10 under the new pattern.  The literal was
NOT moved to 2, because all three sites the comment of the leg names are
still present (`surface/bootstrap.ml:406` inside `state ()`, `:531` the
`TOT_CACHE_VERIFY` recompute, `:544` the cache miss), so dropping the
literal would have weakened the assertion.  Proof of sufficiency ahead of
the tree edit: the probe copy
`tot-m8-probes/stage-c/gates-probe.sh`, carrying that single recipe
patch, printed PASS 431, FAIL 0, GATE-EXIT 0, with a sorted marker set
that diffed EMPTY against the entry baseline, 431 lines on each side.
Ruling id: SC-H1, read with the never-weaken-an-assertion rule.

**C-D16.  The prelude-error arm is at `bin/tot.ml:179-181`, not
`:180-182`.**  What the plan says: `dev/M8-PLAN.md` and the stage brief
both place the prelude-error arm of `run_with_prelude` at
`bin/tot.ml:180-182`.  What the tree says: the arm measured at HEAD sits
at `bin/tot.ml:179-181`; `:179` is `~error:(fun e ->`, `:180` is the
`prerr_endline` of the prelude prefix, `:181` is `serror_exit))`.  What
I did: Build-1 edited the MEASURED arm at 179 to 181 and booked the
one-line drift here as a note, not a halt.  Ruling id: SC-Q2, the
measured HEAD line wins where the plan cites the tree.

**C-D17.  The `Bootstrap.state ()` call sites are not at the plan's
lines, and there are nine of them.**  What the plan says: the existing
callers are `test/surface.ml:1073`, `:2283`, `:2328` and `:2359`.  What
the tree says: the four code call sites in `test/surface.ml` measured at
HEAD are `:1073`, `:2375`, `:2420` and `:2451`; the lines 2283, 2328 and
2359 hold no call.  A full sweep also finds five more code call sites in
`test/main.ml`, at `:917`, `:1016`, `:1039`, `:1086` and `:1135`, which
the plan does not name.  What I did: nothing.  `state ()` keeps its
signature and its behaviour, so all nine sites compile untouched and both
suites are green.  Blocker C-C2 did not fire.  Ruling id: SC-Q2.

**C-D18.  `rg -c 'PASS-M8' dev/gates.sh` reads 20, not the predicted
18.**  What the plan says: step 6 of the brief predicts 18, from 12 at
entry plus 6 lines in the new block (one comment line and one echo line
per leg).  What the tree says: the recipe printed 20.  The two extra
lines are in the re-derivation note of `PASS-M5D-TIERS`, which names the
three new markers in prose to explain the tier delta; the note occupies
two lines that carry a `PASS-M8C-` spelling.  What I did: I measured and
booked 20.  No marker was added or removed to reach a predicted number,
and the distinct-marker check is unaffected: `rg -o 'PASS-M8C-[A-Z0-9-]+'
dev/gates.sh | sort -u` returns EXACTLY three names,
`PASS-M8C-HOLE-POSITIONS`, `PASS-M8C-PRELUDE-TAIL` and
`PASS-M8C-S0-DRIVER`, and `rg -c 'echo PASS-' dev/gates.sh` reads the
predicted 174.  Ruling id: precedent C-D4, the recipe is the authority.

### 4. Decisions

- **SC-R1, branch one, taken.**  `$m5d_scratch` (`dev/gates.sh:2225`) is
  live at the insertion slot, so the PRELUDE-TAIL leg reuses it, with
  `m8c_ck="$m5d_scratch/m8c-ck"` and
  `m8c_alt="$m5d_scratch/prelude-holed.tot"`.  No scratch dir was added
  and the EXIT trap at `dev/gates.sh:434` is unchanged.  The two names
  do not collide with the `ck` and `prelude-alt.tot` of
  `PASS-M7D-CACHE-KEY`.
- **SC-Q1, answer (a).**  `PASS-M8C-S0-DRIVER` pins all SEVEN stdout
  lines as whole strings in order, plus the stdout line count 7 and an
  empty stderr.
- **SC-Q2.**  Where the plan cites a tree line, the measured HEAD line
  wins.  See C-D16 and C-D17.
- **SC-Q3.**  The wrapper `PASS=` line is a NOTE, never a halt.  The
  exit battery read 441, inside the 438 to 441 band the brief books as
  measured, so it needs no note beyond the number.
- **Whole records, not fragments.**  Each leg redirects stdout and
  stderr to two files instead of folding them with `2>&1`, so both
  streams get their own line-count assertion.  This is stricter than the
  M7C precedent, which pins an empty stdout with `[ -z "$out" ]` only.
- **`sd` in the gate.**  The two substitutions of the hand-broken
  prelude use `sd -s`, the spelling of the plan block at
  `dev/M8-PLAN.md:1817-1822`.  `dev/gates.sh` only PREPENDS to `PATH`
  (`:441`), so `sd` stays reachable inside the battery; this was
  verified before the block landed.
- **No literal was edited to make a leg green.**  Every number in
  section 5 came from the recipe printed beside it.

### 5. Re-derivations, old value then new value

| literal | recipe | old | new |
| --- | --- | --- | --- |
| `oneread_srcs` pattern, `dev/gates.sh:1475` | the pattern itself | `[^_]state_of_src src` | `[^_]state_of_src(_tailed)? src` |
| `oneread_srcs` literal, `dev/gates.sh:1484` | `rg -c '[^_]state_of_src(_tailed)? src' surface/bootstrap.ml` | 3 | 3, unchanged |
| `m5d_tiers`, literal in `PASS-M5D-TIERS` | `rg -c '"\$watchdog" "\$(FAST\|MED\|SLOW\|SUITE)"' dev/gates.sh` | 233 | 236 |
| gate echoes | `rg -c 'echo PASS-' dev/gates.sh` | 171 | 174 |
| `PASS-M8` lines | `rg -c 'PASS-M8' dev/gates.sh` | 12 | 20, see C-D18 |
| `PASS-M8C-` lines | `rg -c 'PASS-M8C-' dev/gates.sh` | 0, exit 1 | 8, over three distinct markers |
| `s0-erased-guard` lines | `rg -c 's0-erased-guard' dev/gates.sh` | 0, exit 1 | 2 |

The tier move is recorded IN PLACE inside `PASS-M5D-TIERS`, in the same
comment ladder Stage A and Stage B used, with the old value, the new
value and the reason: the three new legs run the CLI three times, one
tier call per run, and delete none.  The leg was not restructured.

### 6. Exit state

Exit battery, run through the wrapper into `tot-m8-stageC-gate.log`:

- `BUILD-EXIT=0`
- `GATE-EXIT=0`
- `FAIL=` empty, so 0
- wrapper `PASS=441`, a NOTE under SC-Q3
- `SLICE=437`, `SLICE-BOUNDS=21,530`, from
  `tot-m8-probes/stage-c/draft/slice.sh`

437 is the contract number: 431 at entry, plus 3 gate markers, plus 3
suite cases, exactly the arithmetic of plan section 2.2.  Blocker C-C4
did not fire.

**C-D19.  The exit-state bounds pair was booked one line early.**  SC-H2
ruled verify checklist item 12 pass, with the note that this section had
booked `SLICE-BOUNDS=20,529`, one line early on the OK build line rather
than the BUILD-OK line, while `SLICE=437`, `FAIL=` empty, `GATE-EXIT=0`
and `BUILD-EXIT=0` all agreed.  The closer corrects the pair in place to
`SLICE-BOUNDS=21,530`, the same pair the review-fix battery in section
`3e` already measured on `tot-m8-stageC-review-gate.log`.  `SLICE=437`
is unchanged.  No other byte of this section moves.

Suites: `test/surface.exe` 157 PASS, 0 FAIL, exit 0, tail line `M1
surface: all tests green`; `test/main.exe` 105 PASS, 0 FAIL, exit 0,
tail line `M0 kernel: all tests green`.  The three new cases print as
`PASS M8C-1`, `PASS M8C-2` and `PASS M8C-3`.

Every AT-RISK leg was re-measured on the exit log and is GREEN:
`PASS-M5E-DEFAULT-IDENTITY`, `PASS-M6C-DEFAULT-IDENTITY`,
`PASS-M6E-TRANSCRIPT-RESEALED`, `PASS-M8A-KERNEL-UNCHANGED`,
`PASS-M7C-MULTI-HOLE-TAIL`, `PASS-M7C-SINGLE-HOLE-UNCHANGED`,
`PASS-M7D-CACHE-KEY`, `PASS-M5D-TIERS` and `PASS-D-PRELUDE-ONEREAD`.

Pinned constants re-measured at exit, all UNCHANGED: the 17-file `lib/`
digest `ec077852495cdc0ac9a7abd4eb2fe786` over 17 files; the sealed
transcript `dev/m5e-default-transcript.txt` at 10407 lines, md5
`a0f222ff8b70b08d1e1ece6d199c5549`, 105 blocks; `stdlib/prelude.tot` at
230 lines, md5 `6013fa65389a1220f9a15059294701a0`;
`surface/cache.ml`'s `format_version` still 10, count 1 (R-Q6).  The
one-block reseal diff for `test/fixtures/s0-erased-guard.tot` is EMPTY,
`P6-DIFF-EXIT=0`, so blocker C-C5 did not fire.

No dropped name is present: `rg -c
'PASS-M8C-TRANSCRIPT-RESEAL|PASS-M8B-ANCHORS|PASS-M8B-RESPELL-COUNT|PASS-M8A-CONSERVATIVITY|PASS-M8D-SELF-ENTRY'
dev/gates.sh` exits 1 with no match.

Working tree at exit, `git status --porcelain -uall`:

```
 M bin/tot.ml
 M dev/M8-BUILD-LOG.md
 M dev/gates.sh
 M surface/bootstrap.ml
 M test/surface.ml
?? dev/fixtures/m8c-hole-positions.tot
?? dev/fixtures/m8c-prelude-tail-probe.tot
```

Nothing was staged, committed, pushed, checked out, stashed or cleaned
by this stage.  Staging is the closer's own step.

### 3d.  Mutation proofs

Ruling R10 asks for one distinct one-edit mutation per leg.  The prover
ran the three proofs below on the post-build tree, one at a time, and
restored each target file byte for byte before the next one.  Every run
went through `tot-m7-probes/stageB/battery-wait.sh` into its own log,
and every slice came from `tot-m8-probes/stage-c/draft/slice.sh`.  The
baseline is section 6: `BUILD-EXIT=0`, `GATE-EXIT=0`, `FAIL=` empty,
`SLICE=437`.

`dev/gates.sh` runs the two in-process suites FIRST, at `dev/gates.sh:93`
(`SUITE-KERNEL`) and `dev/gates.sh:95` (`SUITE-SURFACE`), and stops at
`TEST-FAIL` (`dev/gates.sh:97`) when either one is red.  A mutation of a
shared code path therefore reddens a suite case before the battery
reaches ANY gate leg, so each proof also re-runs its target leg's own
command STANDALONE on the mutated binary.  That is the MB-1 precedent of
Stage B.

**MC-1, the `PASS-M8C-HOLE-POSITIONS` proof.**  Target file
`surface/run.ml`, the `hole_tail` fold at line 654.  Edit: one step
added to the pipeline of the match scrutinee, `|> List.filteri (fun i _
-> i = 0)` after `|> List.sort loc_order`, so the fold keeps the head of
the sorted, filtered list alone instead of the whole list.  md5 before
the edit `fe854ef622cade1475f27d05b18fa8df`, md5 under the mutation
`988ad460c07a07ba7436b9b9e67bb048`.  Log
`tot-m8-stageC-mc1.log`.

Battery: `BUILD-EXIT=0`, `GATE-EXIT=1`, wrapper `PASS=260`, `FAIL=5`,
`SLICE=258`, `SLICE-BOUNDS=22,358`.  Red cases in `test/surface.exe`,
four of them: M8C-1, the target, with `got [1:14: hole: no expected type
at this position] tail [1 more hole(s) at 1:24], want [1:14: hole: no
expected type at this position] tail [3 more hole(s) at 1:24, 1:36,
1:47]`;  M8C-3, M7C-1 and M7C-3 as collateral, because all four read the
same `hole_tail` fold.  M8C-2 stayed green, since a one-hole item has no
tail to lose.  `test/main.exe` stayed green, 105 PASS, 0 FAIL.

Prediction against measurement: the predicted shadow was
`PASS-M7C-MULTI-HOLE-TAIL` (`dev/gates.sh:3748`).  The measured shadow
sits EARLIER.  The battery stopped at `TEST-FAIL`, so no gate leg ran at
all, the M7C leg included, and the log carries no `PASS-` marker.

Standalone re-run of the leg command on the mutated binary,
`_build/default/bin/tot.exe check dev/fixtures/m8c-hole-positions.tot`:
exit 1, stdout 0 lines, stderr 2 lines.

```
/Users/oobi/Documents/tot/dev/fixtures/m8c-hole-positions.tot:6:14: hole: no expected type at this position
1 more hole(s) at 6:24
```

The leg pins line 2 as the whole string `3 more hole(s) at 6:24, 6:36,
6:47`, so the assertion is false and the leg is
`FAIL-M8C-HOLE-POSITIONS`.  Restore: `surface/run.ml` md5
`fe854ef622cade1475f27d05b18fa8df`, equal to the md5 before the edit,
`dune build` exit 0, and `git status --porcelain -uall` lists the seven
Stage C paths alone, `surface/run.ml` absent.

**MC-2, the `PASS-M8C-S0-DRIVER` proof.**  Target file `lib/erase.ml`,
line 33, `  | Term.App (Quantity.Zero, f, _a) -> term ctx f`.  Edit: the
arm walks the erased argument as well,

```
  | Term.App (Quantity.Zero, f, _a) ->
      Result.bind (term ctx f) (fun ef -> Result.map (fun _ -> ef) (term ctx _a))
```

md5 before the edit `f4b68f9fa3bac75f2c1f217ce46a08c9`, md5 under the
mutation `6ff5648e7865e43a15542f39b4f12865`.  Log
`tot-m8-stageC-mc2.log`.

Battery: `BUILD-EXIT=0`, `GATE-EXIT=1`, wrapper `PASS=101`, `FAIL=6`,
`SLICE=99`, `SLICE-BOUNDS=20,167`.  Red cases in `test/main.exe`, six of
them: T0, the case `surface/run.ml:86` names, with
`erased-guard-no-self-ref: erased variable j used at runtime`, then B2,
C1, C2, C3 and C4, every one of them a `Check.define` case whose def
carries an erased application.  `test/surface.exe` printed one line and
exited 1, `bootstrap failed: 16:1: erased variable A used at runtime`, so
no surface case ran.

Prediction against measurement: the predicted collateral was
`case_ghost_guard_is_unguarded` (`test/surface.ml:629`) and the T0 case
at `test/surface.ml:1424`.  T0 is red as predicted, in `test/main.exe`.
The surface case did NOT run, because the mutation stops the erasure of
`stdlib/prelude.tot:16` and the surface suite cannot bootstrap.  The
kernel suite is the measured shadow, one step before `SUITE-SURFACE`.

Standalone re-run of the leg command on the mutated binary,
`_build/default/bin/tot.exe run --no-prelude test/fixtures/s0-erased-guard.tot`:
exit 1, stdout 0 lines, stderr 1 line.

```
/Users/oobi/Documents/tot/test/fixtures/s0-erased-guard.tot:3:1: erased variable j used at runtime
```

The leg pins exit 0, seven stdout lines and an empty stderr, so the leg
is `FAIL-M8C-S0-DRIVER`.  The message names the erased variable `j`, from
the `Var` arm at `lib/erase.ml:26`, and not the `match` arm at
`lib/erase.ml:64` of the estimate: the walk into the dropped argument
meets the erased variable one arm earlier.  The observable of the leg is
red either way.

Restore: `lib/erase.ml` md5 `f4b68f9fa3bac75f2c1f217ce46a08c9`, equal to
the md5 before the edit.  The 17-file `lib/` digest, by the recipe
`PASS-M8A-KERNEL-UNCHANGED` uses at `dev/gates.sh:4194`, reads
`ec077852495cdc0ac9a7abd4eb2fe786` over 17 files, its pinned value.
`dune build` exit 0, and `git status --porcelain -uall` lists the seven
Stage C paths alone, `lib/erase.ml` absent.

**MC-3, the `PASS-M8C-PRELUDE-TAIL` proof.**  Target file `bin/tot.ml`,
the prelude-error arm at lines 179 to 181 as build-1 left it.  Edit: the
added call `Option.iter prerr_endline tail;` deleted, so the miss path
prints one stderr line instead of two.  md5 before the edit
`6a964d565ed1f5b59ffedbb0c06f2d32`, the build-1 digest, md5 under the
mutation `8cf254f0651ef2653ab40e86bf5be805`.  Log
`tot-m8-stageC-mc3.log`.

Battery: `BUILD-EXIT=0`, `GATE-EXIT=1`, wrapper `PASS=438`, `FAIL=1`,
`SLICE=434`, `SLICE-BOUNDS=21,528`.  The one red line is the target,
`FAIL-M8C-PRELUDE-TAIL (exit=1 pat=1/1)` at log line 527.  The two
substitution counts stayed 1 and 1, so the red comes from the message
and not from a drifted recipe.  The slice is 434 and not 437 because the
battery stops at the red leg and never reaches the legs after it.

No collateral.  `PASS-M8C-HOLE-POSITIONS` and `PASS-M8C-S0-DRIVER` are
green in the same log, at lines 524 and 525.  `test/surface.exe` is
green, 157 PASS, 0 FAIL, and `test/main.exe` is green, 105 PASS, 0 FAIL.

Prediction against measurement: as predicted, suite case M8C-3 stayed
GREEN under the mutation.  M8C-3 calls
`Bootstrap.state_of_src_tailed` in process and never enters `bin/tot.ml`,
so it watches the tail at the state builder, and the gate leg watches the
same tail at the CLI.  That division of labour is the reason the stage
owns BOTH a gate leg and a suite case for one piece of plumbing: the
suite case proves the tail is computed, the gate leg proves the driver
prints it.

Standalone re-run of the leg command on the mutated binary,
`env TOT_CACHE_DIR=<scratch>/m8c-ck TOT_PRELUDE=<scratch>/prelude-holed.tot
_build/default/bin/tot.exe check dev/fixtures/m8c-prelude-tail-probe.tot`,
with the hand-broken prelude built by the leg's own `cp` plus two `sd`
calls in a scratch dir: exit 1, stdout 0 lines, stderr 1 line.

```
prelude: 93:54: hole: no expected type at this position
```

The leg pins the stderr line count at 2 and line 2 as the whole string
`2 more hole(s) at 94:48, 94:73`, so the assertion is false and the leg
is `FAIL-M8C-PRELUDE-TAIL`.  `stdlib/prelude.tot` was not written: its
md5 is `6013fa65389a1220f9a15059294701a0` after the run.

Restore: `bin/tot.ml` md5 `6a964d565ed1f5b59ffedbb0c06f2d32`, equal to
the md5 before the edit and to the build-1 digest, `dune build` exit 0.

After the three proofs, `git status --porcelain -uall` reads:

```
 M bin/tot.ml
 M dev/M8-BUILD-LOG.md
 M dev/gates.sh
 M surface/bootstrap.ml
 M test/surface.ml
?? dev/fixtures/m8c-hole-positions.tot
?? dev/fixtures/m8c-prelude-tail-probe.tot
```

The seven Stage C paths alone, as the Build stage left them plus this
subsection.  No mutation target is listed.  Nothing was staged,
committed, pushed, checked out, stashed or cleaned.

### 3e.  Review fixes

The review stage of Stage C filed five findings against the Build
stage tree.  Two of them are the same defect from two finders, and two
more are a second instance of it.  One is a note.  Ruling SC-H3 owns
the class: each wrong line-number self-citation inside the new M8C
comment block is one LOW finding, and the fix is comment bytes only,
with no recipe, no literal, no marker, no echo and no line-count
change.

**Applied, two comment lines in `dev/gates.sh`.**

Findings `item10-1` and `legs-1` are the same defect.  `dev/gates.sh:4231`
cited the M7C whole-record block as `dev/gates.sh:3710-3748`, which is a
HEAD number.  Conflict note C-D15 widens the PASS-D-PRELUDE-ONEREAD
pattern in place, and step 2 of the tier work inserts 7 lines at
`dev/gates.sh:2338`, so every line after 2338 moves by +7.  The M7C block
is at 3717 to 3755 in the tree that ships.  The line now reads:

```
# block's (dev/gates.sh:3717-3755);  the private cache dir is the
```

Findings `item10-2` and `legs-2` are the second instance.
`dev/gates.sh:4232` cited the PASS-M7D-CACHE-KEY private-cache pair as
`dev/gates.sh:3852-3853`, again a HEAD number under the same +7 shift.
`m7d_ck` is at 3859 and `m7d_alt` is at 3860 in the tree.  The line now
reads:

```
# PASS-M7D-CACHE-KEY idiom (dev/gates.sh:3859-3860).  The scratch dir
```

Both replacements are the same width as the text they replace, 9
characters for 9 characters, so `dev/gates.sh` keeps its 4401 lines.
The three diff hunks against HEAD keep their bounds, `@@ -1475 +1475 @@`,
`@@ -2338 +2338,8 @@` and `@@ -4217,0 +4225,115 @@`.  Every pinned line
number is where it was: the EXIT trap at 434, the widened
PASS-D-PRELUDE-ONEREAD recipe at 1475 with its literal 3 at 1484, the
`m5d_scratch` mktemp at 2225, the M7B slot line at 3667, the M8B echo at
4222 and the M8C block at 4225 to 4339.  The M8B number was booked as
4215 in the first draft of this subsection, which is the M8B prose line,
not the echo: `awk` on the tree reads `# on a tree that carries the hole
in ANY of the three slots of line 94,` at 4215 and
`&& echo PASS-M8B-PRELUDE-94` at 4222.  The other citations of the
block re-measure correct and are untouched: 2225, 434, `lib/erase.ml:33`
and `:64`, `dev/gen-m5e-transcript.sh:13` and
`dev/M8-PLAN.md:1753-1877`.

The fresh md5 of `dev/gates.sh` after the fix is
`15aa6c3a5357571768a8b5117afd2298`, at 4401 lines.  The closer takes it
from here and books conflict note C-D20 under SC-H3.  The id is C-D20,
not C-D17: C-D17 is already taken by the `Bootstrap.state ()` call-site
note at this file's line 1524, and the closer renumbers its own later
note to the next free id so every id appears exactly once.

**Declined, one note and one out-of-scope citation.**

Finding `item10-5` reports that `Bootstrap.state_of_src_tailed` re-spells
the phase-marker message that `Bootstrap.state_of_src` holds, and that
nothing pins the two spellings equal.  The re-spelling is real, at
`surface/bootstrap.ml:387` and `:460`, and no gate and no suite case
breaks a phase marker, so a one-sided edit is silent in the battery.
The fix is declined this round for two reasons.  The finding's first
option lifts the local `not_found` out of `state_of_src`, and
`dev/M8-PLAN.md:1716` reads verbatim "`Bootstrap.state_of_src` itself is
UNCHANGED", so that option is not admissible in Stage C.  The finding's
second option adds a comment, and SC-H3 confines this fix stage to the
citation corrections in `dev/gates.sh` and nothing else.  The finder
itself grades the item as a note to carry, not work for this round.  It
moves no gate number.  Carry it to Stage D; if a comment is ever added,
it goes on the `:456` side alone and it names `surface/bootstrap.ml:387`
as the twin.

`dev/gates.sh:4217` cites `dev/gates.sh:3660` for the `m7b_slots` line,
which the same +7 shift moves to 3667.  That line is a Stage B comment
in the M8B block, not a line of the M8C comment block, and no confirmed
finding covers it.  SC-H3 scopes the finder to the M8C comment block and
scopes this stage to the corrections it filed, so the line is left as it
stands and is reported to the closer instead.

**Exit battery after the fix**, run through the wrapper into
`tot-m8-stageC-review-gate.log`:

- `BUILD-EXIT=0`
- `GATE-EXIT=0`
- `FAIL=` empty, so 0
- wrapper `PASS=441`, a NOTE under SC-Q3
- `SLICE=437`, `SLICE-BOUNDS=21,530`, from
  `tot-m8-probes/stage-c/draft/slice.sh`

437 is the contract number and it did not move, which is what a
comment-bytes fix must show.  No `^FAIL-` line is in the log.

Every at-risk leg re-measured green in the same run:
PASS-D-PRELUDE-ONEREAD at log line 440, PASS-M5D-TIERS at 464,
PASS-M5E-DEFAULT-IDENTITY at 469, PASS-M6C-DEFAULT-IDENTITY at 487,
PASS-M6E-TRANSCRIPT-RESEALED at 498, PASS-M7C-MULTI-HOLE-TAIL at 508,
PASS-M7C-SINGLE-HOLE-UNCHANGED at 509, PASS-M7D-CACHE-KEY at 513 and
PASS-M8A-KERNEL-UNCHANGED at 522.  The three new markers are at 524,
525 and 526.  The three suite cases M8C-1, M8C-2 and M8C-3 pass in both
suite runs.

No re-derivation is booked for this subsection.  A comment line holds no
literal, so no recipe was re-run and no value moved.  C-D15 and the tier
literal keep the values the Build stage booked.

The porcelain is the seven Stage C paths alone:

```
 M bin/tot.ml
 M dev/M8-BUILD-LOG.md
 M dev/gates.sh
 M surface/bootstrap.ml
 M test/surface.ml
?? dev/fixtures/m8c-hole-positions.tot
?? dev/fixtures/m8c-prelude-tail-probe.tot
```

Nothing was staged, committed, pushed, checked out, stashed or cleaned.

## Stage D (2026-09-05): lib/ takes its interfaces

The last stage of M8.  The kernel gets an interface for every module,
and the environment storage moves behind a private module, so a client
outside the library can no longer write an entry into the environment
without going through `Check`.  The stage adds no admission rule, no
elaboration rule and no observable behaviour.  It does not write
`stdlib/prelude.tot` and it does not touch `surface/cache.ml`.

### 1. Entry state

Entry commit `6d0d48d`, the M8 Stage C exit commit, subject "M8 Stage C:
the prelude miss path reports every hole, s0-erased-guard joins the
battery, gate battery 431 to 437".  `git status --porcelain -uall`
printed NOTHING at entry, so blocker D-C0 did not fire.  The entry
battery, run through the wrapper
(`tot-m7-probes/stageB/battery-wait.sh`) into
`/Users/oobi/Documents/tot-m8-stageD-entry-gate.log`, printed
BUILD-EXIT=0, GATE-EXIT=0, PASS=441 and no FAIL line.  The slice recipe
over that log printed SLICE=437 and SLICE-BOUNDS=14,523.

The entry measurements this stage moves, each with the recipe that
printed it:

- `rg -c 'PASS-M8D-' dev/gates.sh` exited 1 with no match, so the
  PASS-M8D- namespace was free.
- `rg -c 'echo PASS-' dev/gates.sh` printed 174.
- `rg -c 'PASS-M8' dev/gates.sh` printed 20.
- `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` printed
  236, which is the live `PASS-M5D-TIERS` literal.
- `fd -e ml --max-depth 1 . lib | wc -l` printed 17, and the same
  recipe over `.mli` printed 2.
- The `comm` gap between the two basename sets printed 15.
- The 17-file kernel digest was `ec077852495cdc0ac9a7abd4eb2fe786`.
- The five-example output digest was `f1450de0006de4b7339b2f39ec2e2e50`
  over 43 lines, with the five per-file exit codes all 0.
- `dev/gates.sh` was 4401 lines, md5 `15aa6c3a5357571768a8b5117afd2298`.
  `test/surface.ml` was 2579 lines, md5
  `c8e1a1945662b71864b4f34b5112cae5`.  `SPEC.md` was 2675 lines, md5
  `c6283c51f4b2ed10dca1e2da3043c18f`.  This log was 1947 lines, md5
  `4a7fbaf915afcdf200a9aef0d07f5009`.

### 2. What changed

#### 2.1 `lib/`, `surface/run.ml`, `test/dune` and `test/main.ml` (Build-1 and Build-2)

Build-1 added `lib/global_store.ml` and `lib/global_store.mli`, the
private `Map.Make (String)` store with the plan's four values, declared
`(private_modules global_store)` in `lib/dune`, rewired `Global` onto
`type t = entry Global_store.t` and added `add_rec_self`, redirected the
eight `Check` insertion sites and the one environment fold in
`inst_table_stats` to the private store, collapsed the twelve-line
provisional self entry at `surface/run.ml:219-230` to the one
`Global.add_rec_self` call, wrote `lib/global.mli` with no general
insertion, split `test/dune` into the two pinned stanzas, and moved the
five white-box insertion sites of `test/main.ml` onto the private store
spelling.  Build-2 added the other fourteen interfaces, every signature
taken from the compiler with `ocamlc -i` and then narrowed to the
members the external and the sibling caller columns name.  `lib/` now
holds 18 `.ml` files and 18 `.mli` files.  Neither build touched
`dev/gates.sh`, `test/surface.ml`, `SPEC.md` or this log.

#### 2.2 `dev/gates.sh` (Build-3)

Three legs land in one block at the slot the prep measured,
`dev/gates.sh:4339` at entry, which is the blank line between the M8C
block and the legacy `# ctxcat id 5` comment (ruling SD-R3).  One blank
line stays on each side, so `PASS-M4FIX-INST-BRANCHING` and
`PASS-M5B-BRANCHING-20` remain the file's last two legs.  The block
opens no scratch dir: it uses `$m5d_scratch` (`dev/gates.sh:2225`) and
`$m5d_bin` (`:2226`), which are both live at that slot, so the EXIT trap
at `dev/gates.sh:434` still names nine dirs.  Each leg quotes its own
plan Marker paragraph verbatim in its comment header.

- `PASS-M8D-MLI-COVERAGE` (plan `dev/M8-PLAN.md:2178-2184`).  The `comm`
  over the two basename sets is captured first and counted second, so
  the captured exit code is `comm`'s and not `tr`'s.  Four whole-record
  assertions: the `comm` exit code 0, the gap count the whole string
  `0`, the gap text empty, and the two file counts 18 `.ml` and 18
  `.mli` pinned SEPARATELY, so a deletion that drops a `.ml` and its
  `.mli` together cannot keep the difference at 0.  The FAIL arm prints
  the gap list itself, so the diagnostic names the modules.
- `PASS-M8D-KERNEL-INTERNAL` (plan `dev/M8-PLAN.md:2186-2196`).  The
  negative half is the plan's own regex `^\s*val add\b` over
  `lib/global.mli`, and the plan's exit discipline is written out: code
  1 is the ONLY pass, code 0 means the forbidden export is back, code 2
  means the interface file is missing, and both are FAIL.  The positive
  half pins the whole line
  `val add_rec_self : string -> Term.t -> t -> t` exactly once, so the
  leg cannot be satisfied by deleting the interface (ruling SD-Q5).
- `PASS-M8D-NO-BEHAVIOUR-CHANGE` (plan `dev/M8-PLAN.md:2198-2208`).  The
  five reference examples run one at a time under `"$watchdog" "$FAST"`,
  each exit code is kept, and every stdout and stderr byte appends to
  one file in the plan's order.  Seven assertions: the five exit codes 0
  each, the digest the whole string `f1450de0006de4b7339b2f39ec2e2e50`,
  and the line count 43.  The plan's own `xargs -I{}` pipeline does not
  stop on a non-zero child, so a per-file exit assertion beside the
  digest is required (plan `:2202-2203`);  the file this leg digests has
  the same md5 as the plan pipeline's output, measured on this tree.

`PASS-M8A-KERNEL-UNCHANGED` takes the D4 transition IN PLACE.  The leg,
its failure arm, its echo and its mutation are preserved.  Three things
move: the sorted `cat` list at the entry `dev/gates.sh:4195` gains
`"$ROOT"/lib/global_store.ml` between `global.ml` and `interp.ml`, the
count assertion moves from 17 to 18, and the digest literal moves from
`ec077852495cdc0ac9a7abd4eb2fe786` to `e49ff916b7235f223e8dcaa498fc3aee`.
The comment header now says that the leg freezes the POST-STAGE-D
kernel, that the digest is a literal measured once during the reviewed
transition, and that the gate never derives it from the live source and
never accepts either digest.

`PASS-M5D-TIERS` keeps its name, its marker, its mutation proofs and all
four assertions, and its live tier literal is re-derived from 236 to
241.  The paragraph above the assertion records the move in the shape
every earlier stage used.

#### 2.3 `test/surface.ml` (Build-3)

One helper, `m8d_f1_witness_entry`, sits with the other case helpers
above `let cases`, and one tuple registers it immediately before the
list's closing `]`.  The case folds `test/fixtures/f1-witness.tot` IN
PROCESS through `script_items`, from the no-prelude initial state,
because the fixture declares `Nat` itself.  It then reads the FINAL
checked entry for `add` through the public `Global` interface and
asserts `rec_arg = Some 0` and `reducible = true`.  It runs no
subprocess and does not read `_build/default/bin/tot.exe`.  The helper
is stored PARTIALLY APPLIED, with no trailing unit argument, because the
cases list holds thunks.  The existing CLI F1 case and the five
raw-environment kernel cases of `test/main.ml` are untouched.

#### 2.4 `SPEC.md` (Build-3)

One paragraph closes section 4, "Kernel modules": every kernel module
carries an interface, `lib/` holds 18 `.ml` and 18 `.mli` files, the
environment lives behind the private `Global_store`, `Global` publishes
`empty`, `find` and `add_rec_self` and no general insertion, the sibling
modules use the private store directly, and the baseline digest covers
the 18 `.ml` files while the interfaces enter neither that digest nor
the file count.  One dated row closes section 2, the decision log, in
the file's own row shape.  Nothing else in `SPEC.md` moves.

### 3. Conflict notes

The ids below are allocated by the closer from the measured maximum over
all `C-D[0-9]+` tokens in this log at closing time (ruling SD-R1).  The
build stage writes the notes in order, (a) to (d), and does not invent
an id.

**Note (a), C-D21.  The `PASS-M8` line count reads 30, not the predicted 26.**
What the plan says: the stage prep predicts `rg -c 'PASS-M8'
dev/gates.sh` at 26 after the stage, up from 20, that is two lines per
new leg, the comment header line and the success echo.  What the tree
says: the recipe prints 30.  Each new leg quotes its own plan Marker
paragraph VERBATIM in its comment header, and the plan's paragraph opens
with a `Marker: PASS-M8D-<NAME>` line, so every new marker name sits on
three lines and not two, which is 29;  the `PASS-M5D-TIERS` re-derivation
paragraph names `PASS-M8D-NO-BEHAVIOUR-CHANGE` as the leg that adds the
five tier calls, which is the thirtieth.  Every earlier `PASS-M8`
name is on three lines for the same reason, so 30 is the value the
file's own convention produces.  What I did: nothing was deleted to
reach 26.  The verbatim quotation is the instruction the build carries,
and a derived count is a NOTE and never a halt.  The load-bearing
numbers are measured and green: `rg -c 'echo PASS-' dev/gates.sh` prints
177, the distinct `PASS-M8[A-D]-` name set is exactly ELEVEN, three of
them Stage D, and `rg -o '&& echo (PASS-M8[A-D]-[A-Z0-9-]+)' -r '$1'
dev/gates.sh | sort | uniq -d` prints NOTHING, so no success echo
repeats (plan section 8.2, plan `:2231-2232`).  The ruling I acted
under: a derived count is a note, precedent C-D18 in the Stage C
section and C-D4.

**Note (b), C-D22.  The behaviour leg runs under the watchdog, so the tier
literal moves 236 to 241.**  What the plan says: the drafted leg in the
stage prep invokes `"$ROOT"/_build/default/bin/tot.exe check` five times
with no watchdog, which would leave the `PASS-M5D-TIERS` literal at 236.
What the tree says: `dev/gates.sh:521-522` records the battery's own
rule, M3 fixes round 2 (ctxcat id 18), that a CLI invocation runs under
`"$watchdog"` and never bare, and design pin 17 requires every leg to
name a tier.  What I did: the five example runs go through `"$watchdog"
"$FAST" "$m5d_bin"`, which is the same binary the prep names, and I
re-derived the tier literal with the leg's own recipe, 236 before and
241 after, and recorded the move in the comment ladder above the
assertion in the shape every earlier stage used.  The digest is
unaffected: the same five runs, bare and under the watchdog, both print
`f1450de0006de4b7339b2f39ec2e2e50` over 43 lines with the five per-file
exit codes 0.  The ruling I acted under: the live recipe is the
authority over a remembered number (C-D4), and no tier call was added or
removed to reach a predicted number.

**Note (c), C-D23.  The suite case carries the name the build brief spells,
not the prep's draft name.**  What the plan says: the stage prep drafts
the tuple as `"M8D-1 m8d_final_rec_entry: the checked f1-witness def
lands in globals with rec_arg = Some 0 and reducible = true"` with the
helper `m8d_final_rec_entry`.  What the tree says: the build brief gives
the case name to use VERBATIM, `"M8D-1 m8d_f1_witness_entry: the FINAL
checked entry for add carries rec_arg = Some 0 and reducible = true,
read through the public Global interface"`.  The two disagree in the
helper name and in the wording of the claim, and they agree in the
tag `M8D-1` and in what is asserted.  What I did: I used the brief's
string verbatim and named the helper `m8d_f1_witness_entry`, so the
name inside the case string is the name of the function the tuple
stores.  The observable is unchanged: the case folds the fixture in
process from the no-prelude initial state and asserts `rec_arg = Some 0`
and `reducible = true` on the final checked entry.  The ruling I acted
under: plan section 3.2's first move, a source-string substitution when
the two texts disagree, with the operative instruction winning and the
drift booked.

**Note (d), C-D24.  The prep's plan-line citations for the three Marker
paragraphs are two lines late.**  What the plan says: the prep cites the
Marker paragraphs as `dev/M8-PLAN.md:2178-2186`, `:2188-2198` and
`:2200-2209`.  What the tree says: `awk` over `dev/M8-PLAN.md` puts
`Marker: PASS-M8D-MLI-COVERAGE` at `:2178` and its last line at `:2184`,
`Marker: PASS-M8D-KERNEL-INTERNAL` at `:2186` with its last line at
`:2196`, and `Marker: PASS-M8D-NO-BEHAVIOUR-CHANGE` at `:2198` with its
last line at `:2208`;  `:2185`, `:2197` and `:2209` are blank.  What I
did: each leg comment cites the MEASURED range, and the quoted paragraph
under it is the plan's own bytes.  The ruling I acted under: where the
plan cites the tree, the measured line wins and the drift is a note,
never a halt.

### 4. Decisions

1. The three legs form ONE block at the entry slot `dev/gates.sh:4339`,
   with one blank line on each side (ruling SD-R3).  The two fixed-last
   performance legs stay last, and the M8C block above is untouched:
   it keeps its `$m5d_scratch` file names, and the M8D block adds none
   that collide with them.
2. The block adds NO scratch dir.  It writes its one capture file into
   `$m5d_scratch`, which the EXIT trap at `dev/gates.sh:434` already
   cleans, so the trap keeps its nine dirs.
3. Every M8D assertion is a whole record.  The coverage leg pins the
   `comm` exit code, the gap count as the whole string `0`, the empty
   gap text and the two file counts separately.  The boundary leg pins
   an exit code, an empty capture and one whole interface line.  The
   behaviour leg pins five exit codes, one digest and one line count.
   No leg matches a substring.
4. `PASS-M8D-KERNEL-INTERNAL` passes on `rg` exit 1 alone.  Exit 0 and
   exit 2 are both FAIL, so a deleted `lib/global.mli` cannot pass, and
   the positive half pins `val add_rec_self` as a whole line so an empty
   interface cannot pass either (ruling SD-Q5).
5. `PASS-M8D-NO-BEHAVIOUR-CHANGE` does not use the plan's `xargs`
   pipeline.  `xargs -I{}` does not stop on a non-zero child, so a
   per-file exit code would hide inside a green digest (plan
   `:2202-2203`).  The five runs are separate and the file they append
   to has the same md5 as the plan pipeline's output.
6. The D4 transition moves three literals IN PLACE and restructures
   nothing.  The digest is the value build-1 measured once, after the
   `.ml` edits landed, and build-3 re-ran the same recipe on the exit
   tree and got the same string before pinning it.
7. `PASS-M5D-TIERS` is re-derived, never guessed, and the leg is not
   restructured.
8. The suite case is IN PROCESS.  It reads the final entry through the
   public interface, so it observes the boundary this stage builds and
   not the CLI's printed lines.

### 5. Re-derivations, old value then new value

Every row is a live recipe.  The old column is the entry measurement of
section 1, and the new column is the exit measurement of section 6.  No
row is a remembered number.

| Recipe | Old | New |
| --- | --- | --- |
| `rg -c 'echo PASS-' dev/gates.sh` | 174 | 177 |
| `rg -c 'PASS-M8' dev/gates.sh` | 20 | 30 |
| `rg -c 'PASS-M8D-' dev/gates.sh` | 0, exit 1 | 10 |
| `rg -c '&& echo PASS-M8D-' dev/gates.sh` | 0, exit 1 | 3 |
| `rg -c '"\$watchdog" "\$(FAST\|MED\|SLOW\|SUITE)"' dev/gates.sh` | 236 | 241 |
| the `PASS-M5D-TIERS` literal | 236 | 241 |
| `fd -e ml --max-depth 1 . lib \| wc -l` | 17 | 18 |
| `fd -e mli --max-depth 1 . lib \| wc -l` | 2 | 18 |
| the `comm` gap between the two basename sets | 15 | 0 |
| the kernel `cat` digest | `ec077852495cdc0ac9a7abd4eb2fe786` | `e49ff916b7235f223e8dcaa498fc3aee` |
| the `PASS-M8A-KERNEL-UNCHANGED` count literal | 17 | 18 |
| the five-example digest | `f1450de0006de4b7339b2f39ec2e2e50` | `f1450de0006de4b7339b2f39ec2e2e50` |
| the five-example line count | 43 | 43 |
| `test/surface.ml` case count, the suite's own PASS total | 157 | 158 |
| `dev/gates.sh` line count | 4401 | 4556 |
| `test/surface.ml` line count | 2579 | 2615 |
| `SPEC.md` line count | 2675 | 2708 |
| the battery slice | 437 | 441 |
| `rg -n 'let format_version' surface/cache.ml` | `118:let format_version : int = 10` | `118:let format_version : int = 10` |
| `rg -c 'TOT-CACHE-VERIFY-OK'` on the warm run's output | 1 | 1 |
| the `prelude-*.bin` blob byte size | 15044 | 15044 |
| the `prelude-*.bin` BODY md5, `tail -c +81 <blob> \| md5 -q` | `0d3ba0d8dc9c63895f2e3a9a584737da` | `0d3ba0d8dc9c63895f2e3a9a584737da` |
| the `prelude-*.bin` whole-file md5, a NOTE and never a pin | `33f4bba03dd2e33218e1626a52415005` | `0145945413c36ee370cd11d5e384d1cb` |

The five-example digest and its line count are the two rows that must
NOT move, and they did not.  That pair is the stage's claim that the
interface sweep is not observable.

The five cache rows are the AFTER capture the plan requires at
`dev/M8-PLAN.md:2162-2169`.  The BODY md5 is the pin and it did not move,
which is the claim that the marshalled Map representation is unchanged.
The whole-file md5 is a NOTE: the blob's last 32 bytes hold the digest of
the binary that wrote it (`surface/cache.ml:127-133`), so that value moves
on every rebuild by construction (ruling RUL-D2).  `format_version` stays
10, the cache entries stay on disk as evidence, and no transcript
expectation was edited.

The `PASS-M8` row reads 30 where the stage prep predicts 26.  See
conflict note (a) of section 3: the count is derived, each leg header
quotes the plan's `Marker:` line verbatim, and the load-bearing numbers,
177 success echoes and eleven distinct `PASS-M8[A-D]-` names with no
duplicate, are green.

### 6. Exit state

The exit battery ran through the wrapper,
`zsh /Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh
/Users/oobi/Documents/tot-m8-stageD-gate.log 12 3600`, and the slice
recipe ran over the same log:

```
RUNNER-EXIT=0
31:BUILD-EXIT=0
554:GATE-EXIT=0
555:PASS=445
556:FAIL=
SLICE=441
SLICE-BOUNDS=41,554
```

The slice is the contract, and 441 is the green number for this stage,
437 at entry plus the three new legs and the M8D suite case that the
surface suite's own count carries into the slice.  `rg -c '^FAIL-'` over
the log printed 0, and the only line that starts with `FAIL` is the
wrapper's own empty `FAIL=` summary at `:556`.  The wrapper `PASS=445`
counts four success lines outside the slice bounds `41,554`, so it is a
NOTE and not the contract.  No dune load artefact appeared: `rg -i
'dune.*load|Error: Dune'` over the log printed nothing, so no rerun was
needed.

The three new markers print in block order, at the end of the run and
before the two fixed-last performance legs' section:

```
548:PASS-M8D-MLI-COVERAGE
549:PASS-M8D-KERNEL-INTERNAL
550:PASS-M8D-NO-BEHAVIOUR-CHANGE
```

The two transitioned legs print green in their own places,
`485:PASS-M5D-TIERS` and `543:PASS-M8A-KERNEL-UNCHANGED`.

In `dev/gates.sh` the success echoes sit at `:2355` for
`PASS-M5D-TIERS`, `:4219` for `PASS-M8A-KERNEL-UNCHANGED`, and `:4399`,
`:4436` and `:4488` for the three Stage D markers.  The M8 echo ladder
now reads `:4114`, `:4144`, `:4182`, `:4219`, `:4239`, `:4275`, `:4310`,
`:4350`, `:4399`, `:4436`, `:4488`.

The two in-process suites, run one at a time under the battery's own
runner: `test/main.ml` printed 105 PASS and 0 FAIL, exit 0, unchanged;
`test/surface.ml` printed 158 PASS and 0 FAIL, exit 0, up one from 157,
with `PASS M8D-1 m8d_f1_witness_entry: the FINAL checked entry for add
carries rec_arg = Some 0 and reducible = true, read through the public
Global interface` on the suite's output line 186.  `zsh -n dev/gates.sh`
printed SYNTAX-OK.

The files this stage owns, at exit:

- `dev/gates.sh`, 4556 lines, md5 `165f9e8529352b86672623bf6d7d0c06`.
- `test/surface.ml`, 2615 lines, md5 `5f6947ec78646518784eed8620e47615`.
- `SPEC.md`, 2708 lines, md5 `06c6ad84cc9e51ae33a82d7b8aa185ed`.
- `dev/M8-BUILD-LOG.md`, 2088 lines before this section landed, md5
  `f9181b92eee6903f8ed68aed049801e6`.

The files the stage must NOT move, re-measured at exit and all
unchanged: `surface/cache.ml:118` still reads `let format_version : int
= 10` (ruling R-Q6), `stdlib/prelude.tot` is md5
`6013fa65389a1220f9a15059294701a0`, the sealed transcript is md5
`a0f222ff8b70b08d1e1ece6d199c5549` over 10407 lines,
`lib/quantity.ml` is md5 `b95cca1ca3d013f2d3599ce6c0e576c6`, and the two
pre-existing interfaces are unchanged, `lib/budget.mli` md5
`9b887ee595dc10b3c918ce15a9261bdc` and `lib/level.mli` md5
`20993fcf096fc8608174f7aa3f486f23`.  The EXIT trap at `dev/gates.sh:434`
still names nine scratch dirs.

`git -C /Users/oobi/Documents/tot status --porcelain -uall` at exit,
HEAD still `6d0d48d`, 27 paths, nothing committed and nothing staged:

```
 M SPEC.md
 M dev/M8-BUILD-LOG.md
 M dev/gates.sh
 M lib/check.ml
 M lib/dune
 M lib/global.ml
 M surface/run.ml
 M test/dune
 M test/main.ml
 M test/surface.ml
?? lib/check.mli
?? lib/erase.mli
?? lib/error.mli
?? lib/eterm.mli
?? lib/eval.mli
?? lib/global.mli
?? lib/global_store.ml
?? lib/global_store.mli
?? lib/interp.mli
?? lib/json_escape.mli
?? lib/literal.mli
?? lib/pp.mli
?? lib/prim.mli
?? lib/quantity.mli
?? lib/term.mli
?? lib/totality.mli
?? lib/value.mli
```

The cache AFTER capture (`dev/M8-PLAN.md:2162-2169`), taken on the
restored exit tree with `TOT_CACHE_VERIFY=1` and a private
`TOT_CACHE_DIR`,
`/Users/oobi/Documents/tot-m8-probes/stage-d/mut-md5/ckafter`.  The recipe
is `zsh /Users/oobi/Documents/tot-m8-probes/stage-d/mut-md5/cache-after.sh`
and the script it checks, cold then warm, is
`/Users/oobi/Documents/tot-m8-probes/stage-d/mut-md5/probe.tot`, one line,
`def twoN : Nat := succ (succ zero)`:

```
BUILD-EXIT=0
118:let format_version : int = 10
COLD-EXIT=0
WARM-EXIT=0
TOT-CACHE-VERIFY-OK=1
BLOB=ckafter/prelude-1ffd6a62274252acffbbc56e7dce4d1f.bin
BYTES=15044
MAGIC=TOTCACHE
VERSION=00000010
BODY=0d3ba0d8dc9c63895f2e3a9a584737da
WHOLE=0145945413c36ee370cd11d5e384d1cb
EXEID=ckafter/exeid-8e7525979a9c12b914a452a308f15f7e.txt
```

The pin is `BODY`, `tail -c +81 <blob> | md5 -q` over the 14964 bytes that
follow the 80-byte header, and it holds at
`0d3ba0d8dc9c63895f2e3a9a584737da`, the entry value.  `WHOLE` travels
beside it as a NOTE and is never a pin, because the header's last 32 bytes
are the writing binary's own digest (`surface/cache.ml:127-133`), so that
value moves on every rebuild by construction (ruling RUL-D2).  The cold
run writes the blob, the warm run reads it back and prints
`TOT-CACHE-VERIFY-OK` exactly once, `rg -c` equal to `1` at exit 0.  Both
runs exit 0.  `format_version` is still 10 at `surface/cache.ml:118`.  The
two cache entries stay on disk as evidence;  nothing was cleared, no
format was bumped and no transcript expectation was edited.

### 3d.  Mutation proofs

Protocol, one mutation at a time and one edit per proof.  The target md5
is recorded before the edit.  The whole battery then runs through
`/Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh` into a log of
that mutation's own, the exact red line is checked with `rg` on that log,
the target leg runs standalone on the mutated tree, and the file is
restored.  The md5 after the restore must equal the md5 before.  The
battery exits 1 at the FIRST red unit, so a later leg does not run and its
absence is not evidence.

The slice of every log below comes from
`zsh /Users/oobi/Documents/tot-m8-probes/stage-d/draft/slice.sh <log>` on
that log.  The standalone leg runner is
`/Users/oobi/Documents/tot-m8-probes/stage-d/legs.sh`, which holds the leg
bodies of `dev/gates.sh` verbatim;  on the restored tree it prints PASS for
all five legs it carries.

| Id | File and line | Target leg | Red | md5 before | md5 after |
| --- | --- | --- | --- | --- | --- |
| MD-1 | `lib/totality.mli`, whole file | PASS-M8D-MLI-COVERAGE | yes, in the battery log | `1983eb1d681943ba5dbd079142ac9bbc` | `1983eb1d681943ba5dbd079142ac9bbc` |
| MD-2 | `lib/global.mli:112` | PASS-M8D-KERNEL-INTERNAL | yes, in the battery log | `d03bae57a697f0a4c7bd62912926ef80` | `d03bae57a697f0a4c7bd62912926ef80` |
| MD-3 | `lib/quantity.ml:26` | PASS-M8D-NO-BEHAVIOUR-CHANGE | yes, in the isolated log | `b95cca1ca3d013f2d3599ce6c0e576c6` | `b95cca1ca3d013f2d3599ce6c0e576c6` |
| MD-4 | `lib/check.ml:959` | PASS-M8A-KERNEL-UNCHANGED | yes, in the isolated log | `2ad653107aeac0c1e3724478eb682fd2` | `2ad653107aeac0c1e3724478eb682fd2` |
| MD-5 | `surface/run.ml:218-220` | the suite case M8D-1 | yes, in the isolated log | `948e9ad14fa32b6b0decf51b2dd3eb02` | `948e9ad14fa32b6b0decf51b2dd3eb02` |
| MD-6 | `lib/dune:8` | PASS-M8D-KERNEL-INTERNAL | yes, in an off-repo leg run | `4d2ab4e1970e875417fdeff75ce6c9a3` | `4d2ab4e1970e875417fdeff75ce6c9a3` |

**MD-1**, `lib/totality.mli`, DELETE the whole file.  Log
`/Users/oobi/Documents/tot-m8-stageD-md1.log`.  md5 before
`1983eb1d681943ba5dbd079142ac9bbc`.

- Battery: BUILD-EXIT=0, GATE-EXIT=1, SLICE=436, SLICE-BOUNDS=40,549,
  wrapper PASS=440, wrapper FAIL=1.
- Red line, `md1.log:548`:
  `FAIL-M8D-MLI-COVERAGE (missing=1 comm=0 ml=18 mli=17)`.  The check
  `rg -c -F "FAIL-M8D-MLI-COVERAGE (missing=1 comm=0 ml=18 mli=17)"` counts
  1 and exits 0.  The FAIL arm also prints the gap list, the single line
  `totality`, above the marker.
- Collateral, PREDICTED: no red before the M8D block;  PASS-M8A-KERNEL-
  UNCHANGED stays green, because the digest cats `lib/*.ml` only and the
  count uses `fd -e ml`, and an `.mli` moves neither;  PASS-M8D-KERNEL-
  INTERNAL, PASS-M8D-NO-BEHAVIOUR-CHANGE, PASS-M4FIX-INST-BRANCHING and
  PASS-M5B-BRANCHING-20 never run.  OBSERVED: exactly that.
  `PASS-M8A-KERNEL-UNCHANGED` is at `md1.log:542`, and the four later
  markers are absent from the log.
- Standalone, `zsh legs.sh mli` on the mutated tree: prints `totality`
  then `FAIL-M8D-MLI-COVERAGE (missing=1 comm=0 ml=18 mli=17)`, LEG-EXIT=1.
- Restore: `cp` back from
  `/Users/oobi/Documents/tot-m8-probes/stage-d/orig/totality.mli.orig`;
  md5 after `1983eb1d681943ba5dbd079142ac9bbc`, equal to md5 before.

**MD-2**, `lib/global.mli`, ADD the line `val add : string -> entry -> t -> t`
immediately below `val empty : t`, which lands at line 112.  Log
`/Users/oobi/Documents/tot-m8-stageD-md2.log`.  md5 before
`d03bae57a697f0a4c7bd62912926ef80`.

- Battery: BUILD-EXIT=0, GATE-EXIT=1, SLICE=437, SLICE-BOUNDS=41,551,
  wrapper PASS=441, wrapper FAIL=1.  The build stays green because
  `lib/global.ml:102` still defines `add`;  the mutation exports it.
- Red line, `md2.log:550`:
  `FAIL-M8D-KERNEL-INTERNAL (add_code=0 add=112:val add : string -> entry -> t -> t self_code=0 self=1)`.
  The prep check `rg -c '^FAIL-M8D-KERNEL-INTERNAL \(add_code=0'` counts 1
  and exits 0, and the `rg -c -F` check on the whole line counts 1 and
  exits 0.
- Collateral, PREDICTED: PASS-M8D-MLI-COVERAGE runs FIRST and stays green,
  since the two file counts are unchanged;  the behaviour leg and the two
  performance legs never run.  OBSERVED: exactly that.
  `PASS-M8A-KERNEL-UNCHANGED` is at `md2.log:543` and
  `PASS-M8D-MLI-COVERAGE` at `md2.log:548`;  PASS-M8D-NO-BEHAVIOUR-CHANGE,
  PASS-M4FIX-INST-BRANCHING and PASS-M5B-BRANCHING-20 are absent.
- Standalone, `zsh legs.sh internal` on the mutated tree: prints
  `112:val add : string -> entry -> t -> t` then
  `FAIL-M8D-KERNEL-INTERNAL (add_code=0 add=112:val add : string -> entry -> t -> t self_code=0 self=1)`,
  LEG-EXIT=1.
- Restore: the added line is deleted;  md5 after
  `d03bae57a697f0a4c7bd62912926ef80`, equal to md5 before.

**MD-3**, `lib/quantity.ml:26`, change `  | Many -> "w"` to
`  | Many -> "many"`.  Logs
`/Users/oobi/Documents/tot-m8-stageD-md3.log` and
`/Users/oobi/Documents/tot-m8-stageD-md3-isolated.log`.  md5 before
`b95cca1ca3d013f2d3599ce6c0e576c6`.

- Battery: BUILD-EXIT=0, GATE-EXIT=1, SLICE=234, SLICE-BOUNDS=42,432,
  wrapper PASS=238, wrapper FAIL=29.
- The battery's first red is the surface suite, 28 cases, and `gates.sh`
  stops at `1 test(s) failed` and `TEST-FAIL` at `md3.log:430-431`.  The
  suite runs BEFORE the M8A and the M8D gate legs, so NO `FAIL-M8` gate
  echo prints in this log.  The prep check
  `rg -c '^FAIL-M8A-KERNEL-UNCHANGED '` on `md3.log` exits 1.  See the
  conflict note below.
- Red line, `md3-isolated.log:6`:
  `FAIL-M8D-NO-BEHAVIOUR-CHANGE (digest=a2bb77b216c531586a92befeca9f317f lines=43 exits=0/0/0/0/0)`.
  The prep check `rg -c '^FAIL-M8D-NO-BEHAVIOUR-CHANGE \(digest='` counts 1
  and exits 0.  The prep check
  `rg -c 'digest=f1450de0006de4b7339b2f39ec2e2e50'` finds nothing and exits
  1, so the digest moved off its pin.  The line count stays 43 and all
  five example exits stay 0, so the digest alone carries the red.
- Collateral, PREDICTED: HEAVY.  The edit moves a `lib/*.ml` byte and it
  moves printed output, so every unit that pins the rendering of a `Many`
  binder reddens;  PASS-M8D-NO-BEHAVIOUR-CHANGE never runs in the battery
  and its absence is not evidence, and the isolated leg re-run is the
  proof.  OBSERVED: 28 suite cases red, `TEST-FAIL`, and no gate leg after
  the suite runs at all.  The battery halted at the SUITE unit, not at a
  gate leg, so this observation says nothing about which gate leg would
  have reddened first (review round 2026-09-05, finding LEG-1).
- Standalone, `zsh legs.sh behaviour` on the mutated tree: the five
  examples print, the tail shows `def usesBanned : (many _ : String) -> Bool`,
  then the FAIL line above, LEG-EXIT=1.  A second standalone,
  `zsh legs.sh kernel`, prints
  `FAIL-M8A-KERNEL-UNCHANGED (lib_md5=71c3e28df9d651953cf7f0e5404e85c7 files=18)`,
  LEG-EXIT=1, so the transitioned leg also detects the edit when it is
  reached.
- Restore: `  | Many -> "many"` back to `  | Many -> "w"`;  md5 after
  `b95cca1ca3d013f2d3599ce6c0e576c6`, equal to md5 before.

**MD-4**, `lib/check.ml:959`, change the binder text in the `Cannot_infer`
message.  The line
`      Error (Error.Cannot_infer (Printf.sprintf "the bare lambda (binder %s)" x))`
becomes
`      Error (Error.Cannot_infer (Printf.sprintf "the bare lambda (binder: %s)" x))`.
Logs `/Users/oobi/Documents/tot-m8-stageD-md4.log` and
`/Users/oobi/Documents/tot-m8-stageD-md4-isolated.log`.  md5 before
`2ad653107aeac0c1e3724478eb682fd2`.

- The edit moves the one part of the message leg (iii) still pins,
  `(binder x)` at the end of the line, and it moves a byte of
  `lib/check.ml`, which is what leg (iv)'s digest watches.  One edit
  therefore reaches both, and neither leg shares an assertion with the
  other: leg (iii) reads the CLI output, leg (iv) reads the 18-file digest.
- Battery: BUILD-EXIT=0, GATE-EXIT=1, SLICE=262, SLICE-BOUNDS=41,375,
  wrapper PASS=266, wrapper FAIL=1.
- The battery's first and only red is the suite case at `md4.log:362`,
  `FAIL M8A-2: the kernel still refuses a bare lambda in callee position`,
  which pins the whole message in process.  `gates.sh` stops at
  `1 test(s) failed` and `TEST-FAIL`, so NO `FAIL-M8` gate echo prints in
  this log and the prep check `rg -c '^FAIL-M8A-BARE-LAMBDA-REFUSES'` on
  `md4.log` exits 1.  See the conflict note below.
- Red line, `md4-isolated.log:1`:
  `FAIL-M8A-KERNEL-UNCHANGED (lib_md5=6db44dc8982dbcb8afe0eaf89bb7e821 files=18)`.
  The prep check `rg -c '^FAIL-M8A-KERNEL-UNCHANGED \(lib_md5='` counts 1
  and exits 0, and `rg -c 'lib_md5=e49ff916b7235f223e8dcaa498fc3aee'` finds
  nothing and exits 1, so the digest is off the pinned literal.  The file
  count stays 18, so the digest alone carries the red.  This is the
  isolated re-run ruling SD-R4 requires for the transitioned leg.
- Collateral, PREDICTED: the surface suite runs before the M8A gate legs
  and case M8A-2 pins the whole refusal message, so the battery stops at
  `TEST-FAIL` and every gate leg from PASS-M8A-BARE-LAMBDA-REFUSES onward
  never runs.  OBSERVED: exactly that, one suite case red and no gate
  `FAIL-M8` echo.
- Standalone, `zsh legs.sh bare` on the mutated tree: prints
  `/Users/oobi/Documents/tot/dev/m8a/bare-lambda-holed.tot:1:1: cannot infer a type for the bare lambda (binder: x)`
  then `FAIL-M8A-BARE-LAMBDA-REFUSES (bare=1 esc= baresrc_len=53)`,
  LEG-EXIT=1.  So leg (iii) does detect this edit;  it is the battery
  order, not the leg, that keeps the echo out of `md4.log`.
- Restore: the message returns to `(binder %s)`;  md5 after
  `2ad653107aeac0c1e3724478eb682fd2`, equal to md5 before.

**State after the four restores.**  The four md5 values are back at their
entry values, listed in the table above.  `git status --porcelain -uall`
prints the same twenty-seven paths as the Stage D entry state, ten
modified and seventeen untracked, and nothing else.  The 18-file kernel
digest, measured with the leg (iv) `cat` list, is
`e49ff916b7235f223e8dcaa498fc3aee`, the pinned literal.  The close battery
`/Users/oobi/Documents/tot-m8-stageD-mutation-close.log` is GREEN on all
four numbers: SLICE=441, SLICE-BOUNDS=41,554, GATE-EXIT=0, BUILD-EXIT=0
and no `FAIL` line.  NOTE: the wrapper `PASS=` line reads 445, which is the
booked 444 to 445 band, because `battery.sh` pipes the two suite runs
through `tail -3`.  The three Stage D markers are at `mutation-close.log`
lines 548, 549 and 550, and the two transitioned Stage A markers at 542
and 543.

**MD-5**, `surface/run.ml:218-220`, DELETE the provisional self entry.  The
three lines
`      let elab_globals =`,
`        if rec_ then Global.add_rec_self name ty_t st.globals else st.globals`
and
`      in`
become the one line
`      let elab_globals = st.globals in`.
Log
`/Users/oobi/Documents/tot-m8-probes/stage-d/mut-md5/md5-isolated.log`.
md5 before `948e9ad14fa32b6b0decf51b2dd3eb02`.

- Line numbers.  The prep row names `surface/run.ml:219-230`.  The block
  sits at `218-220` in the tree.  The edit is the one the row prescribes
  and the result is the one line the row quotes.
- Isolated re-run, the only evidence the prep row admits.  `TOT_PRELUDE`
  (`surface/bootstrap.ml:247`) points at
  `/Users/oobi/Documents/tot-m8-probes/stage-d/mut-md5/mini-prelude.tot`,
  a scratch prelude with NO recursive definition.  It carries the data
  declarations that `required_ctors` (`surface/bootstrap.ml:51-76`) names,
  a non-recursive `foldNat` for the first phase marker and the `Json`
  declaration for the second.  `TOT_CACHE_DIR` points at a private scratch
  dir beside it.  BUILD-EXIT=0, SURFACE-EXIT=1.
- Red line: `FAIL M8D-1 m8d_f1_witness_entry: the FINAL checked entry for
  add carries rec_arg = Some 0 and reducible = true, read through the
  public Global interface`, with the reason line `2:100: unknown name add`.
  `rg -c '^FAIL M8D-1 '` on the log counts `1` and exits 0.
  `rg -c '^PASS M8D-1 '` on the log prints nothing and exits 1, so that
  count is `0`.  Those two counts are the whole of the evidence.
- Collateral, PREDICTED before the run: the shipped prelude declares
  recursive definitions, so on the mutated tree `Bootstrap.state ()`
  fails, `run_suite` (`test/surface.ml:2495-2501`) prints
  `bootstrap failed: ...` and returns 1 with no case run at all;  a plain
  suite run therefore carries no `FAIL M8D-1` line, and every battery leg
  that runs the binary reddens long before the M8D block.  The scratch
  prelude also drops every prelude definition the other cases use, so many
  other cases go red in the isolated run.  OBSERVED: exactly that.  A
  first four-line scratch prelude printed
  `bootstrap failed: 1:1: lex error: prelude: "foldNat" marker not found
  (Stage C phase split)` and ran no case;  the marker-complete scratch
  prelude bootstraps, and the suite then prints 116 PASS and 42 FAIL over
  its 158 cases.  The collateral failures are expected and are not
  evidence.
- Restore: `cp -p` back from
  `/Users/oobi/Documents/tot-m8-probes/stage-d/mut-md5/run.ml.orig`;  md5
  after `948e9ad14fa32b6b0decf51b2dd3eb02`, equal to md5 before.  The
  restored block reads exactly the three lines it read before the edit.

**D2 boundary check, the external-client compile (review round
2026-09-05, findings BD-2 and LEG-2).**  Plan `dev/M8-PLAN.md:2116-2118`
asks to "Verify that the same private reference fails to compile in a
normal external client and succeeds only in the explicitly configured
white-box test", and `dev/gates.sh` leans on that check in the quoted
plan paragraph of PASS-M8D-KERNEL-INTERNAL.  The check ran but was booked
nowhere in this log, so it is booked here as a live recipe.  Runner:
`/Users/oobi/Documents/tot-m8-probes/stage-d/fix/probe.sh`, which repeats
`/Users/oobi/Documents/tot-m8-probes/stage-d/client-probe2.sh` and adds
the exit codes of the second include path.  Three one-line clients live
in `/Users/oobi/Documents/tot-m8-probes/stage-d/client`:  `control.ml`
names `Tot_kernel.Global.empty`, `neg_client.ml` names
`Tot_kernel.Global_store.add`, and `neg_client2.ml` names
`Tot_kernel__Global_store.add`.  The command, run from that directory
with the pinned switch `zxcaml-p1`, is
`ocamlfind ocamlc -package str -I <inc> -I _build/default/lib
_build/default/lib/tot_kernel.cma <f>.ml -o <f>`.

- With `<inc>` = `_build/default/lib/.tot_kernel.objs/public_cmi`, the
  normal external client:  `control` exits 0 with a 0-byte error file;
  `neg_client` exits 2 with `Error: The module "Tot_kernel.Global_store"
  is an alias for module "Tot_kernel__Global_store", which is missing`;
  `neg_client2` exits 2 with `Error: Unbound module
  "Tot_kernel__Global_store"`.  MEASURED 2026-09-05.
- With `<inc>` = `_build/default/lib/.tot_kernel.objs/byte`, the include
  path the white-box test carries at `test/dune:32`, all three exit 0
  with 0-byte error files, `neg_client` and `neg_client2` included.
  MEASURED 2026-09-05.

So the private-module boundary is an INCLUDE-PATH boundary, not a linker
one:  a client that consumes `tot_kernel` through the normal library
dependency cannot name the store, and a client that chooses its own `-I`
flag can.  That is what plan `dev/M8-PLAN.md:2113-2115` already concedes
in the words "It is not an OCaml sandbox against clients choosing their
own compiler flags."  No gate leg runs a compiler on an external client;
the plan quote inside `dev/gates.sh` names this log paragraph, and the
text pin of MD-6 below is the leg-side observer of the field itself.

**MD-6**, `lib/dune:8`, DELETE the line ` (private_modules global_store))`
and close the stanza on the previous line.  md5 before
`4d2ab4e1970e875417fdeff75ce6c9a3`.

- Why the mutation is off-repo:  the amended leg reads two files as TEXT
  and builds nothing, so the proof needs no mutated repo.  The copy is
  `/Users/oobi/Documents/tot-m8-probes/stage-d/fix/md6root/lib`, holding
  `dune` and `global.mli` only, and the runner is
  `/Users/oobi/Documents/tot-m8-probes/stage-d/fix/md6.sh`, which holds
  the amended leg body of `dev/gates.sh` verbatim.  The repo file was
  never edited;  its md5 reads `4d2ab4e1970e875417fdeff75ce6c9a3` before
  and after the run.
- Unmutated copy:  the leg prints `PASS-M8D-KERNEL-INTERNAL`.
- Mutated copy, md5 `cf93fb36f7b31ffb0298668331efd472`:  the leg prints
  `FAIL-M8D-KERNEL-INTERNAL (add_code=1 add= self_code=0 self=1
  priv_code=1 priv=)`.  The two `global.mli` pins stay green, so the new
  `private_modules` pin alone carries the red.
- Restored copy, md5 `4d2ab4e1970e875417fdeff75ce6c9a3`, equal to md5
  before:  the leg prints `PASS-M8D-KERNEL-INTERNAL` again.
- Collateral:  none in this battery.  Before this round no leg of
  `dev/gates.sh` read `lib/dune` at all, so the deletion moved no gate
  input;  the review round measured the same deletion as build-green on
  an off-repo copy of the whole tree.  The text pin is therefore the only
  possible observer, and the field is a declaration of intent, since the
  `-I lib/.tot_kernel.objs/byte` flag at `test/dune:32` reaches the
  private cmi anyway.

**Conflict note C-D25, the prep's `dev/gates.sh` line numbers are stale.**  The
plan-side prep names echo `4202` for PASS-M8A-KERNEL-UNCHANGED, `4339` for
the head of the M8D block and `4374` and `4393` for the two performance
legs.  The tree has `4219`, `4399`, `4529` and `4548`.  The Stage D insert
of the M8D block moved every later echo down.  The TREE wins;  the numbers
above are read from the tree.

**Conflict note C-D26, MD-3 and MD-4 stop at the suite, not at a gate leg.**  The
prep rows predict a gate `FAIL-` echo as the battery's first red, namely
`FAIL-M8A-KERNEL-UNCHANGED` for MD-3 and `FAIL-M8A-BARE-LAMBDA-REFUSES` for
MD-4.  The tree runs the two test suites BEFORE the M8A and M8D gate legs,
so a mutation that moves printed output stops `gates.sh` at `TEST-FAIL` and
no gate echo prints at all.  Both prep checks on `md3.log` and on
`md4.log` exit 1, and that absence is not evidence about the legs.  The
proof is the isolated re-run the same prep rows name and make mandatory:
`md3-isolated.log` carries the red PASS-M8D-NO-BEHAVIOUR-CHANGE with a
moved digest, and `md4-isolated.log` carries the red
PASS-M8A-KERNEL-UNCHANGED with a moved digest.  Both legs are proved
non-vacuous.  Nothing was edited to make a leg green.

**Conflict note C-D27, the V14 recipe shells `ls | sort` and the governing order
is the explicit D4 `cat` list.**  What the prep says: checklist row V14
measured the 18-file kernel digest with `cat $(ls $ROOT/lib/*.ml | sort) |
md5 -q`, and expected `rg -c` of the retired digest
`ec077852495cdc0ac9a7abd4eb2fe786` over `dev/gates.sh` to print `0`.  What
the tree says: `sort` is locale dependent, and in this session's locale
macOS orders `global_store.ml` BEFORE `global.ml`, so the shelled order is
not the order the leg uses.  The order that governs is the D4 explicit
`cat` list of `dev/gates.sh`, and under that list the digest is
`e49ff916b7235f223e8dcaa498fc3aee`, equal to the literal at
`dev/gates.sh:4218`, with the leg's count assertion reading `-eq 18`.  The
retired digest has exactly one hit, the comment at `dev/gates.sh:4203`
that records the 17-to-18 transition the plan asks for.  What was done:
under ruling RUL-D1 the row is SPURIOUS in substance.  The prep row is
amended to name the explicit `cat` order and to expect one commented
occurrence of the retired digest.  The `dev/gates.sh` literal was not
rewritten and the transition comment was not deleted.

**Conflict note C-D28, the V26 whole-file cache pin is unsatisfiable.**  What
the prep says: clause 3 of checklist row V26 pinned the `prelude-*.bin`
payload md5 at `33f4bba03dd2e33218e1626a52415005`, a value taken over the
WHOLE cache blob.  What the tree says: the blob embeds the writing
binary's digest in its last 32 bytes (`surface/cache.ml:127-133`), so the
whole-file value changes on every rebuild by construction and no
whole-file equality can hold across a build.  The before blob and the
after blob are both 15044 bytes, carry the same magic `TOTCACHE` and the
same version field `00000010`, and their body bytes are the same:
`tail -c +81 <blob> | md5 -q` prints `0d3ba0d8dc9c63895f2e3a9a584737da`
for both, over the 14964 bytes that follow the 80-byte header.  What was
done: under ruling RUL-D2 clause 3 is SPURIOUS in substance, and the pin
moves to the body md5 with that recipe.  Clauses 1 and 2 stand unchanged.
`format_version` stays 10, no cache entry was cleared and no transcript
expectation was edited.

**Ruling RUL-D1, checklist row V14.**  The verify stage halted on V14.
The ruling is SPURIOUS in substance: the digest under the governing D4
explicit `cat` list is `e49ff916b7235f223e8dcaa498fc3aee`, equal to the
`dev/gates.sh:4218` literal, with the count assertion `-eq 18`;  the one
hit of the retired digest is the transition comment at
`dev/gates.sh:4203`, which the plan asks for.  The row is amended in the
prep and no tree file moved.

**Ruling RUL-D2, checklist row V26 clause 3.**  The verify stage halted on
clause 3.  The ruling is SPURIOUS in substance: the pin was taken over the
whole cache blob, and the blob's last 32 bytes are the writing binary's
digest, so the whole-file value moves on every rebuild by construction.
The body bytes are stable, body md5 `0d3ba0d8dc9c63895f2e3a9a584737da`
over the 14964 bytes after the 80-byte header.  Clause 3 is re-pinned to
the body md5;  clauses 1 and 2 stand.

**Ruling RUL-D3, checklist row V27.**  The verify stage halted on V27 and
the ruling is that V27 names a REAL gap: the mutation prover ran MD-1 to
MD-4 only, and MD-5 is mandatory.  MD-5 is now performed and booked in
this subsection, one table row and one paragraph, so `### 3d.` carries
five entries with the ids MD-1 to MD-5, each with an md5 before and an md5
after.

### 3e.  Review fixes (2026-09-05)

The review round raised six findings that survived the escalation check.
Four are applied in full, one is applied in a different place than the
finding proposed, and one proposal is declined.  No assertion was
weakened or deleted, and no literal was edited to make a leg go green.

**Applied.**

- Finding BD-5, the quoted plan command of PASS-M8D-MLI-COVERAGE was
  truncated.  `dev/gates.sh:4374` dropped the tail `| wc -l | tr -d ' '`,
  so the quote could not produce the "output 15" and "output 0" counts
  the two lines below it claim.  The tail is restored, byte-identical to
  `dev/M8-PLAN.md:2180`.  The leg body is untouched:  its split pipeline
  is deliberate, so that `$?` is comm's and not tr's.
- Findings BD-3 and LEG-2, the `(private_modules global_store)` field of
  `lib/dune` had no observer.  No leg of the battery read `lib/dune` at
  all, so deleting the field was silent.  PASS-M8D-KERNEL-INTERNAL takes
  a third pin, one whole line plus rg's own exit code, with `$?` captured
  on its own line as in leg (i).  MD-6 above proves the pin non-vacuous.
- Findings BD-2 and LEG-2, the D2 external-client check was performed but
  booked nowhere.  The D2 boundary paragraph above records the runner,
  the command line and both arms with their exit codes, and states that
  the boundary is an include-path boundary.
- Finding LEG-1, PASS-M8D-NO-BEHAVIOUR-CHANGE duplicates
  PASS-M7A-CONSERVATIVITY.  The digest and the line count are pinned by
  M7A about 1010 lines earlier over the same five files with the same
  binary, so in a fail-fast battery those two conjuncts here can never be
  the first red.  The leg header now says so and names the five exit
  codes `m8d_x1` to `m8d_x5` as the leg's unique in-battery observable.
  The digest assertion STAYS;  ruling R-Q3 (`dev/M8-PLAN.md:2199`) asks
  for the five-example comparison, and dropping it was refused.  The MD-3
  collateral paragraph is corrected:  the battery halted at the suite,
  not at a gate leg.
- Finding BD-1, the private-store texts dropped the plan's qualifier.
  `SPEC.md` said an external client "cannot write an unchecked entry" and
  that an `.mli` "permits inside the library and denies outside it".  The
  measured boundary is narrower:  the denial follows the include path,
  and `test/main.ml` names `Tot_kernel__Global_store` from outside the
  library through the flag at `test/dune:32`.  `SPEC.md` now scopes the
  first clause to a client that goes through the public `Global`
  interface, names `lib/dune` as the boundary, calls it a dependency
  boundary and not a compiler sandbox, and names the white-box test as
  the one exception.  `lib/global_store.mli` carries the same qualifier.

**Declined.**

- Finding BD-1, part (a), rewrite the header comment of
  `lib/global_store.ml:2-4`.  That file is one of the 18 `.ml` files
  inside the frozen kernel digest `e49ff916b7235f223e8dcaa498fc3aee`, and
  a comment byte moves the digest and reddens PASS-M8A-KERNEL-UNCHANGED.
  The only way to apply the edit is to re-pin the literal, which the
  leg's own comment forbids in the words "The expected digest is a
  LITERAL measured once during that reviewed transition;  the gate never
  derives it from the live source and never accepts either digest
  opportunistically.  Any later change fails."  A documentation
  correction is not a reviewed kernel transition, so the file stays as
  measured.  The correction is carried by `lib/global_store.mli`, which
  the digest excludes, and that interface names the unqualified `.ml`
  header and says why it stays.
- Finding LEG-2, part (a) as written, a new marker
  `PASS-M8D-PRIVATE-STORE`.  `dev/M8-PLAN.md:2365-2374` reserves exactly
  eleven `PASS-M8` names and `dev/M8-PLAN.md:2247` pins the Stage D exit
  at 441 slice and 445 wrapper.  A fourth Stage D echo adds a PASS line
  and moves both numbers, and the marker census of section 8.2 with it.
  The substance of the finding is applied inside the existing
  PASS-M8D-KERNEL-INTERNAL leg, which already claims the private-module
  boundary in its own header, so the pin exists and the census does not
  move.

**The battery after the fixes.**  Log
`/Users/oobi/Documents/tot-m8-stageD-review-gate.log`, through
`/Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh`.
BUILD-EXIT 0, GATE-EXIT 0, no `^FAIL-` line in the log, and
`zsh /Users/oobi/Documents/tot-m8-probes/stage-d/draft/slice.sh` on that
log prints `SLICE=441` and `SLICE-BOUNDS=41,554`.  The wrapper prints
`PASS=445`, the Stage D exit number, booked as measured.  The three
Stage D markers print at log lines 548, 549 and 550, and
PASS-M8A-KERNEL-UNCHANGED prints at 543, so the frozen kernel digest is
still green after the round.  `git status --porcelain` lists the same 27
paths as before the round.

## Closing round, 2026-09-05

**Final battery.**  The closer ran
`zsh /Users/oobi/Documents/tot-m7-probes/stageB/battery-wait.sh
/Users/oobi/Documents/tot-m8-stageD-close-gate.log 12 3600`, then
`zsh /Users/oobi/Documents/tot-m8-probes/stage-d/draft/slice.sh` over
that same log:

```
WAITED=0 LOAD=5.40
RUNNER-EXIT=0
29:STATUS_LINES=27
31:BUILD-EXIT=0
554:GATE-EXIT=0
555:PASS=445
556:FAIL=
SLICE=441
SLICE-BOUNDS=41,554
```

The four contract numbers are SLICE 441, FAIL 0, GATE-EXIT 0 and
BUILD-EXIT 0, so the closing battery is green.  The slice counts the
`PASS` lines strictly between `BUILD-OK` at `:41` and `GATE-EXIT=` at
`:554`, the bounds the recipe printed on this log.  `FAIL=` is empty
because `rg -c "^FAIL" ` found no match, and `rg -c '^FAIL-'` over the
log also prints 0, so the failure count is 0.  The wrapper `PASS=445`
is a NOTE and never the contract;  it sits in the 444 to 445 band the
stage books as measured, so it opens no conflict note.

The at-risk legs print green in this log:  `PASS-M5D-TIERS` at `:485`,
`PASS-M8A-KERNEL-UNCHANGED` at `:543`, and the three Stage D markers at
`:548`, `:549` and `:550`.  `rg -c '^PASS M8D-1 '` prints 2, one per
suite run, and `rg -c '^FAIL M8D-1 '` prints 0.  `rg -i
'dune.*load|Error: Dune'` over the log prints nothing, so no dune load
artefact appeared and no rerun was needed.

**The plan's six rows before closure, `dev/M8-PLAN.md:2219-2232`.**  Each
row is answered here with evidence measured in the closing round.

1. Build `bin/tot.exe`, `test/main.exe` and `test/surface.exe`
   TOGETHER;  run both suites and the full battery.  Every prior test and
   assertion is preserved.  ANSWERED.  One `dune build` opens the log,
   `OK build: 0 errors, 0 warnings` at `:40` and `BUILD-OK` at `:41`,
   BUILD-EXIT=0 at `:31`.  `test/main.exe` prints 105 `PASS` lines and
   `M0 kernel: all tests green` at `:185`, unchanged from entry.
   `test/surface.exe` prints 158 `PASS` lines and `M1 surface: all tests
   green` at `:372`, up one from 157, and the added line is `M8D-1` at
   `:371`.  No `FAIL` line appears between `:41` and `:372`.
2. Normal external clients can use `Global` and `Check` but cannot call
   `Global.add` or either spelling of the private store module.
   ANSWERED.  The D2 boundary paragraph of section 2.1 books the runner,
   the whole command line and both include paths with their exit codes:
   under the public cmi path `control` exits 0, `neg_client` exits 2 with
   `Error: The module "Tot_kernel.Global_store" is an alias for module
   "Tot_kernel__Global_store", which is missing`, and `neg_client2` exits
   2 with `Error: Unbound module "Tot_kernel__Global_store"`.  In the
   tree, `rg -n '^\s*val add\b' lib/global.mli` prints nothing and exits
   1, `rg -c '^val add_rec_self : string -> Term\.t -> t -> t$'
   lib/global.mli` prints 1, and `rg -c 'private_modules global_store'
   lib/dune` prints 1.  PASS-M8D-KERNEL-INTERNAL carries the three pins
   and is green at `:549`.
3. The eight Check inserts and the one environment fold use the private
   store, and `Global.StringMap`'s runtime-global and set users are
   retained.  ANSWERED.  `rg -c 'Global_store\.add' lib/check.ml` prints
   8, `rg -c 'Global_store\.fold' lib/check.ml` prints 1, `rg -c
   'Global\.add' lib/check.ml` finds no match and exits 1, and `rg -c
   'Global\.StringMap' lib/check.ml` prints 4.  `rg -c 'Global\.add_rec_self name ty_t
   st\.globals' surface/run.ml` prints 1 and `rg -c 'Global\.add '
   surface/run.ml` finds no match.  `rg -c
   'Tot_kernel__Global_store\.add' test/main.ml` prints 5 and `rg -c
   '^\(test$' test/dune` prints 2.
4. Interfaces match the inferred signatures, including module exports
   and constructors.  Both original interfaces, `lib/budget.mli` and
   `lib/level.mli`, remain UNCHANGED, checked by md5 before and after.
   ANSWERED.  `fd -e ml --max-depth 1 . lib | wc -l` prints 18 and the
   same recipe over `.mli` prints 18;  the `comm` gap between the two
   basename sets prints 0 at exit 0, which is the whole assertion of
   PASS-M8D-MLI-COVERAGE, green at `:548`.  Every interface was taken
   from `ocamlc -i` and then narrowed, so the build itself is the match
   proof:  BUILD-EXIT=0 with 0 warnings.  `lib/budget.mli` is md5
   `9b887ee595dc10b3c918ce15a9261bdc` and `lib/level.mli` is md5
   `20993fcf096fc8608174f7aa3f486f23`, both equal to the entry values of
   section 1.
5. D4's 17-to-18-file transition and the unchanged output and cache
   results are recorded.  The transitioned Stage A leg is mutation-tested
   as well as all three new legs.  ANSWERED.  Section 2.2 books the
   transition, the OLD 17-file digest `ec077852495cdc0ac9a7abd4eb2fe786`
   with count 17 and the NEW 18-file digest
   `e49ff916b7235f223e8dcaa498fc3aee` with count 18, both file lists and
   both commands.  The digest re-measured in the closing round over the
   D4 explicit `cat` order prints
   `e49ff916b7235f223e8dcaa498fc3aee`, equal to the literal at
   `dev/gates.sh:4218`.  The cache AFTER capture stands in sections 5 and
   6:  `format_version` 10 at `surface/cache.ml:118`, one
   `TOT-CACHE-VERIFY-OK` on the warm run, blob 15044 bytes, BODY md5
   `0d3ba0d8dc9c63895f2e3a9a584737da` by `tail -c +81 <blob> | md5 -q`,
   with the whole-file md5 travelling as a NOTE.  Section 3d holds five
   mutation rows, MD-1 to MD-5, each with an md5 before and an md5 after,
   and section 3e adds MD-6 for the `lib/dune` pin;  MD-4 is the
   transitioned Stage A leg PASS-M8A-KERNEL-UNCHANGED and MD-1, MD-2 and
   MD-3 are the three new legs.
6. Count success echoes using plan section 8.2:  three Stage D names,
   ELEVEN M8 names in total, no repeated success echo.  Earlier markers
   stay green.  ANSWERED.  `rg -o 'echo PASS-M8D-[A-Z0-9-]+' dev/gates.sh
   | wc -l` prints 3, at `dev/gates.sh:4399`, `:4457` and `:4519`.  `rg
   -o 'echo PASS-M8[A-D]-[A-Z0-9-]+' dev/gates.sh | wc -l` prints 11 and
   the same stream through `sort | uniq -d` prints nothing, so no success
   echo repeats.  `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh | wc -l`
   prints 177.  The eight earlier M8 markers print green in the closing
   log, `PASS-M8A-KERNEL-UNCHANGED` at `:543` among them.  The token
   count `rg -o 'PASS-M8[A-D]-[A-Z0-9-]+' dev/gates.sh | sort | uniq -d`
   is NOT this row's test:  it lists every name twice, once in the quoted
   plan header and once in the echo, which is the derived-count reading
   of note (a), C-D21.

**Conflict note ids, allocated at closing time under ruling SD-R1.**
`rg -o 'C-D[0-9]+' dev/M8-BUILD-LOG.md | sort -V | tail -1` printed
`C-D20` before this round, the measured maximum, so the Stage D ids start
at C-D21.  The eight notes the build, mutation and fix rounds left
unnumbered take these ids, in the order they appear in this section:

| id | note |
| --- | --- |
| C-D21 | note (a), the `PASS-M8` line count reads 30, not the predicted 26 |
| C-D22 | note (b), the behaviour leg runs under the watchdog, so the tier literal moves 236 to 241 |
| C-D23 | note (c), the suite case carries the name the build brief spells, not the prep's draft name |
| C-D24 | note (d), the prep's plan-line citations for the three Marker paragraphs are two lines late |
| C-D25 | the prep's `dev/gates.sh` line numbers are stale |
| C-D26 | MD-3 and MD-4 stop at the suite, not at a gate leg |
| C-D27 | the V14 recipe shells `ls | sort` and the governing order is the explicit D4 `cat` list |
| C-D28 | the V26 whole-file cache pin is unsatisfiable |

No new conflict note opens in the closing round.  The closer numbered
these notes and wrote nothing else into them.

**Re-derived literals, closing round, old value then new value.**  The
old column is the section 6 exit measurement of the build round, the new
column is the closing measurement on the tree that goes to the user.

| what | recipe | old | new |
|---|---|---|---|
| the battery slice | `slice.sh` on the closing log | 441 | 441 |
| the wrapper number | `rg -n '^PASS=' <log> \| tail -1` | 445 | 445 |
| kernel digest, 18 files | the D4 explicit `cat` list, `md5 -q` | `e49ff916b7235f223e8dcaa498fc3aee` | `e49ff916b7235f223e8dcaa498fc3aee` |
| lib file counts | `fd -e ml`, `fd -e mli`, `--max-depth 1` | 18, 18 | 18, 18 |
| the interface gap | the `comm` recipe of leg (i) | 0 | 0 |
| success echoes | `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh \| wc -l` | 177 | 177 |
| M8 success echoes | `rg -o 'echo PASS-M8[A-D]-[A-Z0-9-]+' \| wc -l` | 11 | 11 |
| `PASS-M8` lines | `rg -c 'PASS-M8' dev/gates.sh` | 30 | 31 |
| `PASS-M8D-` lines | `rg -c 'PASS-M8D-' dev/gates.sh` | 10 | 11 |
| `dev/gates.sh` | `wc -l`, `md5 -q` | 4556, `165f9e8529352b86672623bf6d7d0c06` | 4587, `1cbd158359a3761bf6ac5e0176d486b2` |
| `test/surface.ml` | `wc -l`, `md5 -q` | 2615, `5f6947ec78646518784eed8620e47615` | 2615, `5f6947ec78646518784eed8620e47615` |
| `SPEC.md` | `wc -l`, `md5 -q` | 2708, `06c6ad84cc9e51ae33a82d7b8aa185ed` | 2715, `119f4b94cc0c8d86328c7145a70d60ee` |
| `lib/budget.mli` | `md5 -q` | `9b887ee595dc10b3c918ce15a9261bdc` | `9b887ee595dc10b3c918ce15a9261bdc` |
| `lib/level.mli` | `md5 -q` | `20993fcf096fc8608174f7aa3f486f23` | `20993fcf096fc8608174f7aa3f486f23` |
| `stdlib/prelude.tot` | `md5 -q` | `6013fa65389a1220f9a15059294701a0` | `6013fa65389a1220f9a15059294701a0` |
| `Cache.format_version` | `rg -n 'let format_version' surface/cache.ml` | `118:let format_version : int = 10` | `118:let format_version : int = 10` |

Four rows moved and all four move for the same reason:  section 3e, the
review fixes, landed AFTER section 6 was written.  The restored plan
quote in leg (i) and the third `lib/dune` pin in leg (ii) add lines to
`dev/gates.sh` and one more `PASS-M8D-` line to its census, and finding
BD-1 adds the boundary qualifier to `SPEC.md`.  Both `PASS-M8` counts are
derived counts under note (a), C-D21, so they open no new note.  The
load-bearing numbers, 177 success echoes, eleven distinct M8 names, no
repeated success echo and the frozen kernel digest, are unmoved.

**Snapshot.**  The closer wrote
`/Users/oobi/Documents/tot-m8-postD-snapshot.tgz` from the repo tree with
`_build` and `.git` excluded, after this section landed, so the archive
carries this text.  Its byte size travels with the closing hand-off.

**Staging.**  The closer staged the twenty-seven Stage D paths with one
`git add -- <path> ...` over exactly that list, never `git add -A` and
never `git add .`:  `lib/global_store.ml`, `lib/global_store.mli`,
`lib/dune`, `lib/global.ml`, `lib/global.mli`, `lib/check.ml`,
`lib/check.mli`, `lib/erase.mli`, `lib/error.mli`, `lib/eterm.mli`,
`lib/eval.mli`, `lib/interp.mli`, `lib/json_escape.mli`,
`lib/literal.mli`, `lib/pp.mli`, `lib/prim.mli`, `lib/quantity.mli`,
`lib/term.mli`, `lib/totality.mli`, `lib/value.mli`, `surface/run.ml`,
`test/main.ml`, `test/dune`, `test/surface.ml`, `dev/gates.sh`,
`dev/M8-BUILD-LOG.md` and `SPEC.md`.  `git status --porcelain -uall`
after the add lists those twenty-seven paths and nothing else.  The
commit message is written to
`/Users/oobi/Documents/tot-m8-stageD-commit-msg.txt`.

**Exit.**  The closing battery is green on the contract:  SLICE 441,
FAIL 0, GATE-EXIT 0, BUILD-EXIT 0, with the wrapper number 445 as a note.
The stage is ready for the user's commit.  Nothing was committed, pushed,
amended, checked out, stashed or cleaned by the closing round.
