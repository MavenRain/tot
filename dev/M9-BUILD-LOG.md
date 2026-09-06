# M9 build log

## Stage A (2026-09-06): the M8 exit stamp and the SPEC repair

Plan: `dev/M9-PLAN.md:970-1429`, subsections Goal to Rollback.  Rulings
covered: R10, R11, R-Q6, A3-F5, A3-F6, and the pre-rulings SA-Q1 to
SA-Q7.  The whole content diff is prose in `SPEC.md` and one gate leg in
`dev/gates.sh`.  No OCaml file moved.  No suite case was added.

### 1. Entry state

- `git -C /Users/oobi/Documents/tot rev-parse --short HEAD` = `5538927`,
  the M8 Stage D commit.
- `git -C /Users/oobi/Documents/tot log -1 --format=%s` = `M8 Stage D:
  lib/ takes its interfaces, the kernel environment moves behind a
  private store, gate battery 437 to 441`.
- `git -C /Users/oobi/Documents/tot status --porcelain` at entry carried
  exactly one line, `A  dev/M9-PLAN.md`.  This is launch state (a).  The
  plan is staged by the user.  No agent edited it or unstaged it.
- Entry battery baseline, the M8 Stage D close log
  `/Users/oobi/Documents/tot-m8-stageD-close-gate.log`: `GATE-EXIT=0`
  (line 554), `PASS=445` (line 555), `FAIL=` (line 556).  The slice
  recipe on that log printed `SLICE=441` and `SLICE-BOUNDS=41,554`.  The
  wrapper number is the slice plus the M8 C-A14 offset of 4.
- Entry probes, each with the command that printed it:
  - `rg -o 'PASS-M9[A-Z0-9-]*' dev/gates.sh` printed nothing and exited
    1, so the PASS-M9 namespace was free before this stage (R11).
  - `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh | wc -l` = `177`.
  - `rg -n 'entering M9' SPEC.md` printed nothing and exited 1.
  - `rg -c '^- M8 \(done\)' SPEC.md` printed nothing and exited 1.
  - `rg -c 'kernel-internal\.$' SPEC.md` = `1`, the stale bullet's last
    line at `SPEC.md:2045`.
  - `fd -e ml --max-depth 1 . lib | wc -l` = `18`;  the same with
    `-e mli` = `18`.
  - `awk 'NR==1932' SPEC.md` = ``lib/` holds 18 `.ml` files and 18
    `.mli` files, and a module with no`.
  - `ls dev/M9-BUILD-LOG.md` printed `No such file or directory`.  This
    stage creates the file.
- Entry values of the at-risk recipes, each re-run standalone before the
  first edit:
  - `PASS-M5D-TIERS` tier literal, `rg -c '"$watchdog"
    "$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` = `241`.
  - `rg -c 'PASS-M8' dev/gates.sh` = `31`.
  - `rg -n 'lib/check\.ml:1964-1976' SPEC.md` printed TWO lines, `1712`
    and `2646`.
  - `rg -n 'applied-ness test at lib/check\.ml:1964-1976' SPEC.md`
    printed ONE line, `2646`.
- Entry file measures: `SPEC.md` md5
  `119f4b94cc0c8d86328c7145a70d60ee`, 2715 lines;  `dev/gates.sh` md5
  `1cbd158359a3761bf6ac5e0176d486b2`, 4587 lines.
- The insertion slot for the new leg, `awk 'NR>=4523 && NR<=4527'
  dev/gates.sh`: `exit 1` at 4523, the M8D closing brace `}` at 4524, an
  EMPTY line at 4525, and the `# ctxcat id 5` comment at 4526.  The slot
  is where the plan says it is.
- `dev/M9-BUILD-LOG.md` did not exist.  This stage creates it.

### 2. What changed

#### 2.1 `SPEC.md` (Build)

Four edits, all at or after line 2022.  `SPEC.md:1932`, the file-count
sentence, keeps its line number and its bytes.

- Edit A1, section 5, the milestone bullet.  The whole `M8 candidate
  list` bullet, four sub-bullets included, is replaced by the plan's
  `- M8 (done): four stages.` bullet, copied byte for byte from
  `dev/M9-PLAN.md:1155-1167`.  The site was located by
  `rg -n '^- M8 candidate list' SPEC.md`, one hit.  The bullet shrank
  from 19 lines to 11.
- Edit A2, section 6, the stale `.mli` bullet.  The two lines are
  replaced by the plan's block at `dev/M9-PLAN.md:1188-1198`.  The
  original stale sentence is KEPT and annotated `CLOSED 2026-09-05 (M8
  Stage D)`, in the shape of the Apache-licence bullet below it.  The
  annotation opens on the same line as `kernel-internal.`, so
  `rg -c 'kernel-internal\.$' SPEC.md` moved 1 to 0.
- Edit A3, debt entry 6's citation.  ONE `sd` call on the ONE line that
  `rg -n 'applied-ness test at lib/check\.ml:1964-1976' SPEC.md`
  matched, `SPEC.md:2646` before the stage.  The call was
  `sd 'applied-ness test at lib/check\.ml:1964-1976' 'applied-ness test
  at lib/check.ml:1913' SPEC.md`.  No absolute `awk 'NR=='` pin was used
  (A3-F5).  The line is `SPEC.md:2645` after the stage, because A1 lost
  8 lines and A2 gained 7.
- Edit A4, the new `Known debts entering M9` paragraph.  Appended at the
  file end after ONE blank line, copied byte for byte from
  `dev/M9-PLAN.md:1240-1278`.  It carries the C1 debt with one reason,
  the C2 debt with one reason, and the C5 two-horn record, which names
  the two refused probes and states horn one as UNPROVED.  It lands at
  `SPEC.md:2716-2752`.

`SPEC.md` moved 2715 lines to 2752 lines.

#### 2.2 `dev/gates.sh` (Build)

One new leg, `PASS-M9A-EXIT-STAMP`, inserted at the MEASURED empty slot.
`awk 'NR>=4523 && NR<=4527' dev/gates.sh` printed `exit 1` at 4523, the
M8D closing brace at 4524, an empty line at 4525 and `# ctxcat id 5` at
4526, so the slot was where the plan predicted.  The 10-line comment
header lands at 4526-4535 and the Command block lands at 4536-4548, both
copied byte for byte from `dev/M9-PLAN.md:1296-1310` through the prep.
One blank line follows at 4549, so `# ctxcat id 5` keeps a blank line
above it at 4550.  The file moved 4587 lines to 4611 lines, a growth of
24 lines.
The header names NO `PASS-M9A-` literal, under pre-ruling SA-Q1 (a), so
exactly one line of the file carries the marker string, the `&& echo`
line at 4547.  `rg -c 'PASS-M9A-' dev/gates.sh` = `1`, which is review
checklist item 7.  The leg keeps all seven conjuncts.  No existing
literal moved.

#### 2.3 `dev/M9-BUILD-LOG.md` (Build)

This file.  It did not exist at HEAD.  Stage A created it first, before
the first `SPEC.md` edit, and dated it 2026-09-06.  Sections 1 to 3 are
the builder's.  The Mutations agent appends section 3d, the reviewer
appends the review-round fixes and the closer appends sections 4 to 6
and the closing round.

### 3. Conflict notes

None.  Every plan citation into the tree resolved at the line the plan
named, and every re-measured literal held its predicted value.  The
three items that could read as notes are measurements, not divergences:

- The file-count pattern ``[0-9]+ `.ml` files and [0-9]+ `.mli` files``
  matched ONE line at entry, `SPEC.md:1932`, and TWO after A2 landed,
  `SPEC.md:1932` and `SPEC.md:2039`.  The A2 AFTER block states the
  counts a second time.  The leg, since the review round in section 7,
  reads every matched line and requires one value per count.  This is the
  outcome the plan predicts at `dev/M9-PLAN.md:1324-1343`, so it is a
  MEASUREMENT and not a note.
- `rg -n 'lib/check\.ml:1964-1976' SPEC.md` matched TWO lines at entry,
  `1712` and `2646`.  Stage A repoints ONLY the entry-6 hit, located by
  the phrase `applied-ness test at lib/check.ml:1964-1976`, and
  `SPEC.md:1712` survives untouched as the sole remaining hit.  The plan
  states both hits at `dev/M9-PLAN.md:1079-1084`, so this is the plan's
  own reading and no note is owed.
- `rg -n 'lib/check\.ml:1913' SPEC.md` matches entry 6 AND the C1 reason
  inside the new paragraph.  Review checklist item 4 asks only that the
  pattern matches INSIDE entry 6, and it does, at `SPEC.md:2645`.  The
  whole-file count of that pattern is not a plan claim.

The M8 wrapper-offset note is cited here as `M8 C-A14`, from
`dev/M8-BUILD-LOG.md`, never as `C-A14` in this file's own namespace.

#### 3d. Mutation proof, MA-1

R10 asks for one mutation proof for each new leg.  Stage A adds one leg,
so this stage runs one mutation.  The prover ran MA-1 and no other
mutation.

- Target: `SPEC.md:1932`, the sentence that states the `lib/` file
  counts.  Plan `dev/M9-PLAN.md:1324-1343`.
- Edit: ONE `sd` call with the NARROW pattern,
  `sd 'holds 18' 'holds 19' SPEC.md`.  The narrow pattern matches the
  count sentence alone.  The leg's own sentence regex matches TWO lines
  after edit A2 landed, so a substitution on that regex would move two
  lines and break R10.
- `rg -n 'holds 18' SPEC.md` printed one line before the edit, `1932`.
  `rg -n 'holds 19' SPEC.md` printed one line after the edit, `1932`.
- Diff against the pre-mutation copy, `git diff --no-index --numstat`
  between `tot-m9-probes/stage-a/mut/SPEC.md.orig` and `SPEC.md`:
  `1` in the added column and `1` in the removed column.  That is the
  two-line diff with one line moved that the plan measured.
- `md5 -q SPEC.md` before the edit:
  `9164fde88d8a312e3cd6c70c5c22316f`.  The same command on the mutated
  file: `913479d0ce2a04864c0118479c6b079e`.

- Control on the clean tree, before the edit.  The leg Command block,
  `dev/gates.sh:4536-4548`, was extracted line for line into
  `tot-m9-probes/stage-a/mut/legrun.sh`, with `ROOT` set to the repo
  root inside that script.  It printed `PASS-M9A-EXIT-STAMP` at exit 0.
- The same script on the MUTATED tree exited 1 and printed this one
  line:

```
FAIL-M9A-EXIT-STAMP (sec6=1 sec5=1 stale=0 fd_ml=18 fd_mli=18 spec_ml=19 spec_mli=18)
```

That line is byte equal to the red line the prep predicts for MA-1
(`/Users/oobi/Documents/tot-m9-stage-a-prep.md:506`).  `spec_ml=19`
sits beside `fd_ml=18`, so the sixth conjunct is the one that fails.
The other six conjuncts hold, which keeps the proof narrow.

- Battery on the mutated tree, through the wrapper, into
  `/Users/oobi/Documents/tot-m9-stageA-mutations.log`: `BUILD-EXIT=0`
  (line 8), the red line at line 528, `GATE-EXIT=1` (line 529),
  `PASS=443` (line 530) and `FAIL=1` (line 531).  The slice recipe on
  that log printed `SLICE=439` and `SLICE-BOUNDS=18,529`.
- Mechanical check on that same log, `rg -cF` with the whole predicted
  red line as the pattern: it printed `1` and exited 0.

- Collateral, PREDICTED before the log was read: exactly one red leg,
  `FAIL-M9A-EXIT-STAMP`;  every leg ahead of the new leg stays green;
  the two legs after it, `PASS-M4FIX-INST-BRANCHING` at
  `dev/gates.sh:4584` and `PASS-M5B-BRANCHING-20` at `dev/gates.sh:4603`,
  never run at all.  The battery exits 1 at the first red leg, so the
  absence of those two markers is NOT evidence about them.  Predicted
  slice 439, which is 442 less the M9A marker and less those two
  markers.
- Collateral, MEASURED: `rg -n '^FAIL'` on the mutation log printed the
  M9A red line at 528 and the wrapper `FAIL=1` line at 531, and nothing
  else.  Every leg ahead of the new leg printed its marker, which
  includes `PASS-M5D-TIERS` (462), `PASS-M7E-SPEC-CITATIONS` (512),
  `PASS-M8A-KERNEL-UNCHANGED` (520) and the three M8D markers (525, 526
  and 527).  `rg -c` over the two later markers exited 1 with no output.
  The measurement equals the prediction, and the slice is 439.

- Restore.  The prover copied `tot-m9-probes/stage-a/mut/SPEC.md.orig`
  back over `SPEC.md`.  No `git checkout` was used.  `md5 -q SPEC.md`
  after the restore printed `9164fde88d8a312e3cd6c70c5c22316f`, which
  equals the md5 measured before the mutation.  `git diff --no-index`
  between the backup and the restored file exited 0 with no output.
  `awk 'NR==1932' SPEC.md` printed the original count sentence again.
  `rg -c 'holds 19' SPEC.md` exited 1 with no output.  The leg script
  on the restored tree printed `PASS-M9A-EXIT-STAMP` at exit 0.
  Crash recovery, if a prover dies between the mutation and the
  restore: copy `tot-m9-probes/stage-a/mut/SPEC.md.orig` back over
  `SPEC.md`, confirm `md5 -q SPEC.md` prints the md5 recorded when that
  backup was taken (section 7 records the current one), and never run
  `git checkout -- SPEC.md`, which drops the staged edits.
- Confirming battery after the restore, through the wrapper, into
  `/Users/oobi/Documents/tot-m9-stageA-gate.log`: `BUILD-EXIT=0` (line
  8), `PASS-M9A-EXIT-STAMP` (line 528), `GATE-EXIT=0` (line 532),
  `PASS=446` (line 533) and an empty `FAIL=` (line 534).  The slice
  recipe on that log printed `SLICE=442` and `SLICE-BOUNDS=18,532`.
  The wrapper number 446 is the slice plus the M8 C-A14 offset of 4,
  the predicted value, so no note is owed for it (SA-Q2).
- The two timing legs are still the last two markers of the battery,
  `PASS-M4FIX-INST-BRANCHING` at line 529 and `PASS-M5B-BRANCHING-20`
  at line 530, both green.
- `git status --porcelain -uall` after the restore printed exactly four
  lines, the three Stage A paths and the staged plan: ` M SPEC.md`,
  `A  dev/M9-PLAN.md`, ` M dev/gates.sh` and `?? dev/M9-BUILD-LOG.md`.
- MA-1 owes no conflict note.  The leg reddened as predicted, the red
  line is byte equal to the predicted one, and the restore is byte
  identical.


### 4. Decisions

- The user requested takeover on 2026-09-06.  The remaining checks and
  closing work ran locally in Codex; the earlier workflow was not
  resumed.  No commit or push was performed.
- The exact four SPEC edits and the gate Command were compared with
  the accepted plan by a reconstruction check.  Removing the new gate
  block yields the HEAD gate script byte for byte.  No code, existing
  gate assertion, timing threshold or expected count was changed.
- P0 cleanup removes only the two blank lines after `Section 9 ends.`
  from `dev/M9-PLAN.md`, clearing the staged whitespace diagnostic.
  All content lines and Stage A block bytes remain unchanged.  The
  plan now has 3091 lines and md5 `3810f8b39bb5e56c73fab3c2ff76c9c3`; the previous
  3093 lines and md5 `f708fa501a59280f6a6d37521b6fa8ae` describe
  entry state.  The P0 message and Stage B launch pins were refreshed.
  This is P0 whitespace housekeeping, not a Stage A estimate change.
- The closing runner used the pinned `zxcaml-p1` toolchain and
  `dunecho build`.  It records explicit exit codes for the build,
  kernel suite, surface suite and gate battery.  The battery ran once
  and passed without a load retry or threshold change.
- P0 and Stage A remain separate commits.  The P0 handoff uses
  `git commit --only -- dev/M9-PLAN.md` so Stage A's staged files
  remain in the index for the second commit.

### 5. Re-derivations, old value then new value

| Measure | M8 exit | Stage A exit |
| --- | ---: | ---: |
| Gate-section PASS lines | 441 | 442 |
| Wrapper PASS lines (note) | 445 | 446 |
| Gate echo sites | 177 | 178 |
| Watchdog call sites | 241 | 241 |
| Added surface suite cases | 0 | 0 |

The closing log is `/Users/oobi/Documents/tot-m9-stageA-close-gate.log`.
The independent extraction and byte-check results are in
`/Users/oobi/Documents/gpt1/tot-m9-stageA-verification.json`, generated
by `tot-m9-verify.py` in that same directory.  The sorted PASS multiset
diff against the M8 Stage D closing log gained exactly
`PASS-M9A-EXIT-STAMP` and lost no line.  The at-risk SPEC-citations,
watchdog-tiers and final two timing legs passed.  The trailing
`expected-type-only` reader still yields 60.

No Stage A estimate diverged, so no new conflict note is owed.
The P0 whitespace change above does not alter any gate arithmetic.

### 6. Exit state

- Closing build, kernel suite, surface suite and gate exits: all 0.
  Gate-section PASS count: 442.  Leg failures: 0.  The wrapper's 446
  PASS lines include the existing four-line offset, M8 C-A14.
- Verification: all 17 checks in the Stage A workflow checklist were
  completed locally.  The three review lenses, plan conformance,
  gate arithmetic, and verbatim bytes plus untouched paths, found no
  remaining Stage A defect.  The P0 whitespace finding was repaired.
- MA-1: the earlier live mutation and full restored-tree battery are
  recorded in section 3d.  During takeover, an isolated SPEC copy
  passed the unmodified leg, then exited 1 with `spec_ml=19` and
  `fd_ml=18` after the narrow mutation.  The source SPEC remained
  md5 `9164fde88d8a312e3cd6c70c5c22316f` throughout.
- Stage A paths: `SPEC.md`, `dev/gates.sh`, `dev/M9-BUILD-LOG.md`.
  P0's `dev/M9-PLAN.md` is staged separately in scope, in the same
  index.  No lib, surface, test, examples or cache-format file moved.
- The Stage A message is
  `/Users/oobi/Documents/tot-m9-stageA-commit-msg.txt`; the source
  snapshot is `/Users/oobi/Documents/tot-m9-postA-snapshot.tgz`, with
  `.git` and `_build` excluded.  The snapshot numbers and paths are
  recorded in `/Users/oobi/Documents/tot-m9-stageA-close-summary.json`.
- Stage B still requires the user's Stage A commit and a clean tree.
  Its prepared kit has refreshed plan pins; its separate draft review
  is not declared complete by this Stage A close.

### 7. Review round (2026-09-06)

An independent review of the staged P0 and Stage A set returned seven
findings.  All of them are applied.  Every edit is line neutral, so
`SPEC.md` still holds 2752 lines, `dev/M9-PLAN.md` 3091 lines and
`dev/gates.sh` 4611 lines.  This log is the only file that grew.

1. E1 (HIGH), SPEC.md:2028-2029 and dev/M9-PLAN.md:1162-1163.  The M8
   summary said Stage C closed three reporting debts "with no new
   code", but commit 6d0d48d changed `surface/bootstrap.ml` and
   `bin/tot.ml` and added a gate leg.  Both sites now read "a pinned
   decision, a new gate leg, a driver fix, with no new rule".  The two
   sites stay byte identical to each other.
2. E2 (HIGH), dev/gates.sh:4542-4543 and dev/M9-PLAN.md:1303-1304.  The
   leg read `head -1` and `tail -1` over the digits of TWO matched
   sentences, `SPEC.md:1932` and `SPEC.md:2039`, so the `.mli` count of
   the first sentence and the `.ml` count of the second were never
   checked.  Both sites now read every matched line, take `^[0-9]+` for
   the `.ml` count and `and [0-9]+` for the `.mli` count, and join the
   sorted unique values.  Every stated count is pinned, and a divergent
   pair gives a joined value such as `1819` that no tree count equals.
3. E3 (MED), dev/M9-PLAN.md:1878 and :1904.  The Stage B entry probe
   and rollback probe read the whole `PASS-M9` namespace, which cannot
   print nothing after Stage A landed `PASS-M9A-EXIT-STAMP`.  Both are
   narrowed to `PASS-M9B`, and the entry probe names Stage A's marker
   as the one expected `PASS-M9` hit.  Three further sites of the same
   pattern, dev/M9-PLAN.md:1973, :2015 and :2623, were inspected and
   LEFT: each states a measurement at HEAD `5538927` or the whole-M9
   namespace count at close, and each stays true after Stage A lands.
4. E4 (LOW), dev/M9-PLAN.md:1512.  The Stage B gate slot pin named the
   M8D addresses dev/gates.sh:4524 and :4526.  It now names the last
   `PASS-M9` leg's closing brace, dev/gates.sh:4548 after Stage A, and
   the "ctxcat id 5" comment, dev/gates.sh:4550 after Stage A, with
   both addresses re-measured at entry.
5. E5 (LOW), dev/M9-PLAN.md:686-687.  Walk discipline 3.5 forbade a
   stage to stage its paths or to leave this log in the repo, which
   contradicts the closer pattern every stage uses.  It now forbids
   only the commit: each stage stages its own paths and leaves
   `dev/M9-BUILD-LOG.md` in the repo at its own return.
6. E6 (MED), section 3d of this log.  The restore bullet gave no crash
   recovery for the SPEC mutation.  It now states the recovery: copy
   the backup back, confirm the md5, and never use `git checkout`,
   which drops the staged edits.
7. E7 (LOW), dev/M9-PLAN.md:1335, dev/gates.sh:4535 and line 180 of
   this log.  All three named the seventh or the last conjunct as the
   one MA-1 reddens.  The `spec_ml` comparison is the SIXTH conjunct,
   and all three sites now say so.

RULING, no edit: the literal `18` tree pins inside the leg
(`[ "$m9a_fd_ml" = 18 ]` and its `.mli` twin) follow the M8D precedent
at dev/gates.sh:4398 and are ratified in the plan.  They stay.

- Standalone legs, each extracted line for line from `dev/gates.sh` with
  `ROOT` set to the repo root.  The M9A leg, dev/gates.sh:4536-4548,
  printed `PASS-M9A-EXIT-STAMP` at exit 0.  The M7E leg,
  dev/gates.sh:3916-3939, printed `PASS-M7E-SPEC-CITATIONS` at exit 0.
  The full battery was not re-run in this round, because the machine
  load was high and both legs are source-only readers.
- MA-1 re-proof after the leg change, run on a SCRATCH root that
  carries a copy of `SPEC.md` and a symbolic link to `lib/`, never on
  the repo.  Each of the three mutations is one edit on a fresh copy, a
  two-line diff, and each exited 1 with one line:

```
FAIL-M9A-EXIT-STAMP (sec6=1 sec5=1 stale=0 fd_ml=18 fd_mli=18 spec_ml=1819 spec_mli=18)
FAIL-M9A-EXIT-STAMP (sec6=1 sec5=1 stale=0 fd_ml=18 fd_mli=18 spec_ml=18 spec_mli=1819)
FAIL-M9A-EXIT-STAMP (sec6=1 sec5=1 stale=0 fd_ml=18 fd_mli=18 spec_ml=1825 spec_mli=18)
```

  The first line is MA-1 itself, `holds 18` to `holds 19` at
  SPEC.md:1932.  The second moves the `.mli` count of that same
  sentence to 19.  The third moves the `.ml` count of the citation
  sentence at SPEC.md:2039 to 25, which the old `head -1` and `tail -1`
  reader could not see at all.  The red line recorded in section 3d at
  line 175, `spec_ml=19 spec_mli=18`, is the PRE-review measurement of
  the old reader;  this section supersedes it, and the same holds for
  the `spec_ml=19` reading quoted in section 6.
- Verbatim blocks re-checked after every edit, all four byte identical:
  plan 1156-1166 against SPEC 2022-2032, plan 1189-1197 against SPEC
  2036-2044, plan 1241-1277 against SPEC 2716-2752, and plan 1297-1309
  against dev/gates.sh 4536-4548.  `rg -c 'PASS-M9A-' dev/gates.sh`
  still prints 1, and no file of the four carries an em dash.
- File measures after the round: `SPEC.md` 2752 lines, md5
  `8d72de1694747ae96173c7451f6daf60`;  `dev/gates.sh` 4611 lines, md5
  `de5cc825ec0ab9b61dfa0650175b8e32`;  `dev/M9-PLAN.md` 3091 lines, md5
  `513d75ef2304d94f24309e733dccfbaf`.  The plan md5 supersedes the one
  recorded at line 250 of this log,
  `3810f8b39bb5e56c73fab3c2ff76c9c3`, which the plan carried before
  this round.
- The mutation backup `tot-m9-probes/stage-a/mut/SPEC.md.orig` was
  refreshed from the post-review `SPEC.md` and equals it byte for byte,
  md5 `8d72de1694747ae96173c7451f6daf60`.
- Out-of-repo pins refreshed to the new plan md5:
  `/Users/oobi/Documents/tot-m9-plan-commit-msg.txt`,
  `/Users/oobi/Documents/tot-m9-stageA-close-summary.json`,
  `/Users/oobi/Documents/tot-m9-stage-b-prep.md`,
  `/Users/oobi/Documents/tot-m9-stage-b-drafter-brief.md` and
  `/Users/oobi/Documents/tot-m9-stage-b-build-wf.js`.  The close summary
  also carries the new `spec_md5` and `gates_md5`.  Neither commit
  message quotes the old red line or the old reader, so neither was
  changed.
- The index after this round holds four paths and nothing else:

```
M  SPEC.md
A  dev/M9-BUILD-LOG.md
A  dev/M9-PLAN.md
M  dev/gates.sh
```
