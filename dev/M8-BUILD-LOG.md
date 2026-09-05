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
