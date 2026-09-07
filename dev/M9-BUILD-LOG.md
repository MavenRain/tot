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


## Stage B (2026-09-06): the demand instrument and the cd-prefix-guard port

### 1. Entry state

The source checkout was clean at `8356c38`, with subject beginning
`M9 Stage A:`.  Its parent is the separate M9 plan commit.  The plan
has md5 `513d75ef2304d94f24309e733dccfbaf`.  Stage B was developed in
`/Users/oobi/Documents/gpt1/tot-m9-stage-b`, a local clone at that HEAD.
The original checkout was unchanged during implementation and review.

Entry readings: 178 gate echoes, 241 watchdog calls, 105 corpus files,
105 transcript blocks, settle files 104, green 62, and digest
`9278f6b7034f2f65b6d789e9e1d74a90`.  The Stage B namespace was empty.
The existing Stage A close log records a green slice of 442 PASS lines.

The first fresh run built successfully and both suites exited 0.
The battery then failed its existing Div memo timing check at 14s,
while the machine reported a one-minute load average of 142.72.
The log is `/Users/oobi/Documents/gpt1/tot-m9b-entry.log`.
Reversible development continued in the clone.  This run is not a
green entry result, and no timing threshold was changed.

### 2. What changed

forced-rewrite-count: 2

The two byte-identical negative oracles preserve the rejected index
walk and nested Rule declaration.  The port uses structural fuel and
flat classification tags.  The diagnostic preserves the recorded Str
table.  Two inline surface cases accompany the three new gate legs.

The subsequent canonical-checkout entry battery passed before any
Stage B source was installed there.  Its log is
`/Users/oobi/Documents/gpt1/tot-m9b-canonical-entry.log`: build,
kernel, surface and gates exit 0, slice 442, wrapper 446, no FAIL.
The initial clone timing failure above is retained as an environment
measurement, not a code regression or a substituted green result.

The three new Command blocks are byte-identical to the accepted plan.
The existing gate comparisons that move are the tier count, the
settle-budget triple and the four corpus-census pins in C-B9.  The transcript generator adds one 29-line
block, for guard-cd.tot.  Its corpus and transcript counts are both 106.
No kernel, surface implementation, prelude, interface or plan changes.

The scoped evidence is
`/Users/oobi/Documents/gpt1/tot-m9b-port-evidence/`.
The 68-case differential reports `CASES=68 FAILURES=0`.  It covers
quoted paths, all source separator forms, empty tails, script-cd,
assignments, non-Bash and malformed fields, extra Python whitespace,
UTF-8 echoes, and the character cap.  The largest recorded command
has 100000 characters and 399967 bytes and completes in 7.118s.
That is a measurement, not a new timing threshold.

### 3. Conflict notes

**Conflict note C-B1 (2026-09-06): the predicted port does not elaborate.**

1. Predicted. M9-PLAN.md:1627 spells `let e := wordEnd (stringLength cmd) cmd 0 in`; :1625 places `| false => "none"` before the true arm. :1757 predicts exit 0 for the shipped check.
2. Measured. The verbatim sketch fails parsing at 54:13. Adding the let annotation exposes a declaration-order refusal at 49:1. Reordering the Bool arms then exposes `type mismatch: expected Nat, found Int` at 49:1.
3. Command and output. From `/Users/oobi/Documents/gpt1/tot-m9-stage-b`, run `python3 -P /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/probe-predictions.py`. Relevant output:

   ```text
   PROBE=predicted-sketch
   COMMAND=/Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/test/surface.exe gate-check /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/predicted-sketch.tot
   EXIT=1
   /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/predicted-sketch.tot: 54:13: parse error: expected 'NAME : TYPE := TERM in BODY' after 'let', found identifier e
   PROBE=annotated-sketch
   COMMAND=/Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/test/surface.exe gate-check /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/annotated-sketch.tot
   EXIT=1
   /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/annotated-sketch.tot: 49:1: match branches do not fit the declaration: expected true, found false
   PROBE=ordered-sketch
   COMMAND=/Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/test/surface.exe gate-check /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/ordered-sketch.tot
   EXIT=1
   /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/ordered-sketch.tot: 49:1: type mismatch: expected Nat, found Int
   ```

4. Cited lines. `/Users/oobi/Documents/gpt1/tot-m9-stage-b/surface/parser.ml:183` requires the let type annotation. `lib/check.ml:1395`, :1406 and :1412 require all match arms in declaration order; `stdlib/prelude.tot:2` declares true before false. `surface/bootstrap.ml:101` gives stringLength type String -> Int. The actual local structural fuel builder is `examples/guard-cd.tot:77`, its command-sized entry is :89, and wordEnd is :122.
5. The smallest reading that fits. Three independent surface errors invalidate this particular predicted classifier spelling; they do not invalidate the ratified Nat-fuel port.
6. The decision. Re-measure and book the note under section 3.2. Supply explicit let annotations, declaration-ordered arms, and Nat fuel built by a bounded doubling recursion, preserving the same port target and structural rewrite.

**Conflict note C-B2 (2026-09-06): the predicted word boundary is not chained-cd classification.**

1. Predicted. M9-PLAN.md:1760-1764 says a lone `cd /tmp` has nothing past the first word and wordEnd consumes the whole string, returning allow. The code at :1627 actually starts the word walk at index 0, where the first word is only `cd`. :1675-1677 requires only chained-cd to deny.
2. Measured. After the three elaboration repairs above, a Nat fuel of three suffices to stop at index 2. The lone-cd witness exits 2 with a deny envelope. A separate actual-source differential confirms script-cd must also allow.
3. Command and output. From `/Users/oobi/Documents/gpt1/tot-m9-stage-b`, run `python3 -P /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/probe-predictions.py`. Relevant output:

   ```text
   PROBE=typed-sketch
   COMMAND=/Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/test/surface.exe gate-run /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/typed-sketch.tot
   EXIT=2
   {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"cd-prefix-guard: use an absolute path instead of a leading cd (command: cd /tmp)"}}
   ```

   The script feeds `{"tool_name":"Bash","tool_input":{"command":"cd /tmp"}}` to that exact command. The corrected-source command is `python3 -P /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/differential.py`, whose complete log is adjacent as `differential-output.txt` and ends `CASES=68 FAILURES=0`.
4. Cited lines. `/Users/oobi/.claude/hooks/cd-prefix-guard.py:83` defines the directory-and-separator regex; :275 distinguishes a nonempty chained suffix; :278 excludes scripts with three statements. The corrected port uses `examples/guard-cd.tot:211` for the bounded statement count and :274 for classify. `pythonSpaces` at :32 supplies the additional whitespace used by the source regex and strip, and `characterCount` at :64 preserves the source's character-count cap for valid UTF-8.
5. The smallest reading that fits. Advancing past the keyword cannot establish a directory, separator, nonempty tail, or fewer-than-three statement count, so the predicted ninety-line implementation does not implement the ratified source shape.
6. The decision. Re-measure and book the note. Implement those exact classifier checks, including source whitespace and UTF-8 character-count behavior, while retaining only the chained-cd deny result and flat String tag. The completed source has 357 physical newline lines instead of the predicted ninety, measured with `wc -l examples/guard-cd.tot`.

**Conflict note C-B3 (2026-09-06): deleting the true arm is not an allow mutation.**

1. Predicted. M9-PLAN.md:1766-1771 deletes the true arm and predicts unconditional allow, empty deny output, and FAIL-M9B-CD-PORT.
2. Measured. Removing that arm causes a static refusal, before the command can run: `match branches do not fit the declaration: expected true, found false`.
3. Command and output. From `/Users/oobi/Documents/gpt1/tot-m9-stage-b`, run `python3 -P /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/probe-predictions.py`. Relevant output:

   ```text
   PROBE=deleted-bool-arm
   COMMAND=/Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/test/surface.exe gate-check /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/deleted-bool-arm.tot
   EXIT=1
   /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/deleted-bool-arm.tot: 327:1: match branches do not fit the declaration: expected true, found false
   ```

4. Cited lines. `lib/check.ml:1406` and :1412 enforce complete declaration-ordered branches. The actual deny expression is `examples/guard-cd.tot:341`, under the retained true arm at :340.
5. The smallest reading that fits. The proposed branch deletion tests exhaustiveness, not the command's deny behavior.
6. The decision. Re-measure and book the note. The smallest type-correct behavior mutation replaces only the deny expression at :341-343 with allow, retaining both branches. The main builder owns its live marker mutation run and any earlier transcript interaction.

**Conflict note C-B4 (2026-09-06): printLine is not in Run.script's returned line list.**

1. Predicted. M9-PLAN.md:1869-1872 proposes a helper mirroring m7e_expect_source_checks while capturing the program's printed lines and checking the final line.
2. Measured. The executed diagnostic prints the expected line directly to stdout, but Run.script returns an empty line list and `Some 0` because this is an allowing IO Verdict main.
3. Command and output. From `/Users/oobi/Documents/gpt1/tot-m9-stage-b`, run:

   ```text
   env PATH=/Users/oobi/.opam/zxcaml-p1/bin:/Users/oobi/.cargo/bin:/opt/homebrew/bin:/usr/bin:/bin OPAMSWITCH=zxcaml-p1 TOT_PRELUDE=/Users/oobi/Documents/gpt1/tot-m9-stage-b/stdlib/prelude.tot ocaml -I +unix -I +str -I /Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/lib/.tot_kernel.objs/byte -I /Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/surface/.tot_surface.objs/byte unix.cma str.cma /Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/lib/tot_kernel.cma /Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/surface/tot_surface.cma /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/returned-lines.ml
   ASSIGN_WORD=TRUE NOT_A_PROGRAM=FALSE
   RETURNED_LINES=[] EXIT=Some 0
   ```

4. Cited lines. `surface/effect.ml:253` calls print_endline directly. `surface/run.ml:527` renders the verdict and :528 returns only that optional envelope line. The completed helper is `test/surface.ml:733`; its two inline sources start at :764 and :1123, and the exactly two cases are at :2913 and :2915.
5. The smallest reading that fits. An IO Verdict script's returned lines cannot capture printLine effects, even when the effect visibly prints the ratified diagnostic line.
6. The decision. Re-measure and book the note. Capture fd 1 during the same in-process Run.script call, restore it through Fun.protect, and assert both the captured final line and exit Some 0. Only captured output touches a scratch file; both program sources remain inline and byte-identical to their corresponding source files.

**Conflict note C-B5 (2026-09-06): the predicted echo can split a UTF-8 scalar.**

1. Predicted. M9-PLAN.md:1649 uses `elideAt 2000` for the command inside a JSON deny reason.
2. Measured. A chained command consisting of `cd /tmp && ` plus 1000 copies of U+00E9 exits 2, but the byte-2000 cut leaves an incomplete C3 lead byte in stdout, so the resulting JSON transport is invalid UTF-8.
3. Command and output. From `/Users/oobi/Documents/gpt1/tot-m9-stage-b`, run `python3 -P /Users/oobi/Documents/gpt1/tot-m9b-port-evidence/old-echo.py`:

   ```text
   EXIT=2
   UTF8=INVALID byte=2179 value=c3 reason=invalid continuation byte
   ```

   This writes an isolated copy with only the commandEcho call replaced by the plan's elideAt call and runs the exact payload above. The shipped-source 68-case differential decodes every output as UTF-8 successfully, including long accented and four-byte scalar commands.
4. Cited lines. `stdlib/prelude.tot:224` defines elideAt using a byte slice; `surface/bootstrap.ml:101` gives the byte-oriented stringLength primitive and `lib/interp.ml:811` uses OCaml String.length. The local replacement is `examples/guard-cd.tot:306` (at most three bytes of backup) and :317 (same 2000-byte bound).
5. The smallest reading that fits. The prescribed echo boundary is unsafe only when it falls inside a multibyte UTF-8 scalar; the classifier itself is not at fault.
6. The decision. Re-measure and book the note. Use a local UTF-8 boundary adjustment for this example, preserving the same byte cap, elision suffix, command echo, and prelude/API scope.


**Conflict note C-B6 (2026-09-06): the Python regex reading differs.**

1. Predicted. Plan lines 1729-1732 and 1835 say Python agrees with
   Str's FALSE reading for `2>/dev/null`.
2. Measured. Python prints `ASSIGN_WORD=TRUE NOT_A_PROGRAM=TRUE`.
   The tot diagnostic prints `ASSIGN_WORD=TRUE NOT_A_PROGRAM=FALSE`.
3. Command and output. The exact Python command is:

   ```text
   python3 -I -c 'import re; print("ASSIGN_WORD=" + str(bool(re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", "FOO=1"))).upper() + " NOT_A_PROGRAM=" + str(bool(re.match(r"^(?:#|&?[0-9]*[<>])", "2>/dev/null"))).upper())'
   ASSIGN_WORD=TRUE NOT_A_PROGRAM=TRUE
   ```

   The tot command is
   `/Users/oobi/Documents/gpt1/tot-m9-stage-b/_build/default/test/surface.exe gate-run /Users/oobi/Documents/gpt1/tot-m9-stage-b/dev/m9b/regex-fidelity.tot`.
   It exits 0 and prints `ASSIGN_WORD=TRUE NOT_A_PROGRAM=FALSE`.
4. Cited lines. The source pattern is cd-prefix-guard.py:100.
   dev/m9b/regex-fidelity.tot:16 applies it through regexTest;
   lib/interp.ml:541-542 uses Str.regexp.
5. The smallest reading that fits. The recorded subject already
   exhibits the regex dialect difference; the plan's agreement claim
   is false for that subject.
6. The decision. Retain the ratified fixture, output and exact gate
   bytes.  Record the observed difference instead of repeating the
   agreement claim.  The demand reading remains two forced rewrites.

**Conflict note C-B7 (2026-09-06): the new corpus changes its own pins.**

1. Predicted. Plan 1509-1512 and 1881-1883 require the transcript
   reseal, settle-budget re-derivation and watchdog recount.  The old
   settle triple is 104, 62, 9278f6b7034f2f65b6d789e9e1d74a90.
2. Measured. The corpus is 106 files and 106 transcript blocks;
   the settle walk is 105 files, 63 green.  Watchdog calls rise from
   241 to 247 and echo sites from 178 to 181.
3. Command and output. The generator ran once:

   ```text
   zsh -f /Users/oobi/Documents/gpt1/tot-m9-stage-b/dev/gen-m5e-transcript.sh > /Users/oobi/Documents/gpt1/tot-m9-stage-b/dev/m5e-default-transcript.txt
   ```

   The recount is `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' /Users/oobi/Documents/gpt1/tot-m9-stage-b/dev/gates.sh`:
   `247`.  The canonical settle recipe and its complete records are
   saved during finalization in `tot-m9b-canonical-corpus.json`, under
   `/Users/oobi/Documents/gpt1/`.  The actual digest is recorded in
   the closing section below, after the canonical recipe runs.
4. Cited lines. dev/gates.sh:3587-3592 owns the settle recipe;
   dev/gen-m5e-transcript.sh:13-20 owns transcript generation.
5. The smallest reading that fits. One new positive example increases
   corpus and settle counts by one.  Absolute paths in negative
   diagnostics also make the settle digest checkout-dependent.
6. The decision. Re-derive the pins without adding or deleting calls
   to hit a target.  The finalization check runs the actual recipe in
   the canonical checkout and requires it to equal the proposed pin.

**Conflict note C-B8 (2026-09-06): entry prose and citations have drifted.**

1. Predicted. Plan 1497 says the whole M9 namespace is empty at Stage
   B entry; plan 1515 cites debt entry 11 at SPEC.md:2668.  The prep
   also retains the old claim that the Stage A close log is absent.
   The same stale address is also at plan 1492 and plan 1884, and
   the rollback line carried it too; conflict note C-B10 books all
   four sites, so this note no longer records plan 1515 alone.
2. Measured. The committed Stage A marker is present, the Stage B
   namespace is empty, and debt entry 11 was at line 2667.  The fresh
   canonical entry battery passes at 442, as recorded above.
3. Command and output. Before edits, `rg -o 'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh`
   prints `PASS-M9A-EXIT-STAMP`.  The same command with `PASS-M9B`
   prints nothing and exits 1.  `rg -n '^11\. Cumulativity' /Users/oobi/Documents/tot/SPEC.md`
   prints `2667:11. Cumulativity or an `Eq1` layer.  CARRIED.  No measured demand.`
4. Cited lines. Plan 3.6 item 5 and the current Stage B checklist
   already require the per-letter namespace.  The SPEC debt clause
   was located by its heading, not by the stale numeric address.
5. The smallest reading that fits. These are stale entry facts and
   addresses, not changes to the Stage B payload.
6. The decision. Keep the accepted plan unchanged.  Use the measured
   entry and current neighbor text.  Apply the OCaml checklist to
   test/surface.ml, which is the only OCaml file this stage edits.

**Conflict note C-B9 (2026-09-06): the new main adds seven anchors.**

1. Predicted. Stage B's Files touched names only the settle-budget
   triple and tier count among existing gate literals.  The old census
   is total 99, expected-type 60, argument-driven 9, neither 30, with
   69 holed anchors.
2. Measured. The full battery reaches the census reader and fails at
   slice 404 with `logE=expected-type-only=65 specE=expected-type-only=60`.
   The new census is total 106, expected-type 65, argument-driven 11,
   neither 30, with 76 holed anchors.  Removing only guard-cd from the
   source-only census recovers all old sites byte-for-byte.
3. Command and output. Run
   `python3 -P /Users/oobi/Documents/tot/dev/hole-anchors.py`.
   The added sites and final line are:

```text
SITE examples/guard-cd.tot:352 head=bindIO arg=0 anchor=[_] pos=check bucket=A
SITE examples/guard-cd.tot:352 head=bindIO arg=1 anchor=[_] pos=check bucket=E
SITE examples/guard-cd.tot:353 head=bindIO arg=0 anchor=[_] pos=check bucket=A
SITE examples/guard-cd.tot:353 head=bindIO arg=1 anchor=[_] pos=check bucket=E
SITE examples/guard-cd.tot:353 head=liftIO arg=0 anchor=[_] pos=check bucket=E
SITE examples/guard-cd.tot:355 head=pureIO arg=0 anchor=[_] pos=check bucket=E
SITE examples/guard-cd.tot:356 head=pureIO arg=0 anchor=[_] pos=check bucket=E
ANCHORS total=106 expected-type-only=65 argument-driven=11 neither=30
```

   The failed full log is preserved as
   `/Users/oobi/Documents/gpt1/tot-m9b-build-census-failure.log`.
4. Cited lines. The recipe runs at dev/gates.sh:2234-2236.
   The SPEC comparison is at :3111; holed-corpus literals are at
   :3208 and :3681; full census literals are at :3231 and :3852.
   The added source sites are examples/guard-cd.tot:352-356.
5. The smallest reading that fits. The required main's two bindIO
   calls, liftIO call and two pureIO calls grow the corpus census;
   no old site's classification changed.
6. The decision. Apply the count-honesty rule in plan 3.4.  Keep the
   ratified port, all gate equalities, the >98 floor and independent
   recount.  Re-derive the four active corpus literals and append the
   latest SPEC census.  Do not erase holes to preserve stale counts.
   The prelude-only counts and old guard slot count remain unchanged.

**Conflict note C-B10 (2026-09-06): the plan's rollback is incomplete.**

1. The rollback at M9-PLAN.md:1889-1909 named three of the eight moved
   gate literals: the three `PASS-M9B-*` legs and the settle-budget
   leg's triple.  Section 5 below lists all eight.  Executed as
   written, it left five pins on a corpus that no longer exists and
   turned PASS-M5D-TIERS, PASS-M6E-GUARD-HOLES, PASS-M6E-ANCHORS,
   PASS-M7B-GUARD-ARG-HOLES and PASS-M7D-ANCHORS red.  The rollback
   now names the five further literals.
2. The rollback named one of the four staged SPEC.md blocks.  The other
   three are the changelog bullet at SPEC.md:1759-1768, the M7 record
   reword at :2390-2392 and the M9 census block at :2766-2774.
3. The address `SPEC.md:2668` is stale in four places: M9-PLAN.md:1492,
   :1515, :1884 and the rollback line, staged at :1895 and now at
   :1900.  Debt entry 11 sat at 2667 before this stage and sits at 2678
   after it.  This round repairs the rollback line only; the three
   earlier sites are historical plan prose and stay as written.

**Conflict note C-B11 (2026-09-06): four documented differences from the source hook.**

1. Predicted. The port's header at examples/guard-cd.tot:2-11 scopes it
   to the chained-cd classifier and records the nudge kinds and the
   throttle as deliberate omissions.
2. Measured. The port also diverges from cd-prefix-guard.py on four
   inputs.  All four reproduce against the prebuilt binary, no dune:

```text
(a) env bypass. cd-prefix-guard.py:49 documents it and :351-352 checks it FIRST:
    `if os.environ.get("CLAUDE_ALLOW_CD_PREFIX"): return 0`
  $ env CLAUDE_ALLOW_CD_PREFIX=1 python3 -P ~/.claude/hooks/cd-prefix-guard.py < p1.json  -> py_exit=0, no output
  $ env CLAUDE_ALLOW_CD_PREFIX=1 _build/default/bin/tot.exe run examples/guard-cd.tot < p1.json
    {"hookSpecificOutput":{...,"permissionDecision":"deny",...}}  tot_exit=2
(b) non-UTF-8 echo. payload command `cd /tmp && \xff\xfe`:
    python -> py_exit=0 (json.load raises UnicodeDecodeError, caught at :377-378, allow)
    tot -> tot_exit=2, 198 bytes, and `json.loads(out.decode('utf-8'))` -> INVALID: UnicodeDecodeError
      'utf-8' codec can't decode byte 0xff in position 191
(c) duplicate JSON key. `{"tool_name":"Bash","tool_input":{"command":"ls","command":"cd /x && pwd"}}`:
    python (last-wins) -> nudges, prints an additionalContext envelope; tot (first-wins) -> tot_exit=0, allow.
(d) lone surrogate `\ud800`: jsonParse returns none, tot allows; python decodes and classifies chained-cd.
```

3. Why each difference is accepted, not repaired.  (a) `getEnv : String
   -> IO (Option String)` is available to a .tot program
   (surface/bootstrap.ml:125), so the port could read the variable with
   no kernel edit.  The bypass is a `main()` branch, not part of the
   chained-cd classifier this port ships, and it belongs with the
   throttle and the nudge kinds, already out of scope in the header.  A
   port of it would add a `def`, which regenerates the
   `### examples/guard-cd.tot` block of dev/m5e-default-transcript.txt,
   25 def lines today, and forces a transcript reseal for a branch this
   stage never intended to ship.  (b), (c) and (d) come from the shared
   prelude reader `jsonParse` and from lib/json_escape.ml:32, both
   outside this slice and both barred from edit.  (b) is the only one
   that makes a wrong artifact rather than a fail-open, and it is
   unreachable from Claude Code, whose payloads come from
   `JSON.stringify` and are always valid UTF-8.  (c) and (d) fail open,
   the safe direction for a deny guard.
4. Oracles. dev/gates.sh:4552 runs the deny probe with
   CLAUDE_ALLOW_CD_PREFIX=1 set, so PASS-M9B-CD-PORT asserts that the
   port ignores the bypass variable.  There is no oracle for (b): a raw
   byte that is not valid UTF-8 cannot live in a gates.sh literal
   without breaking that file's own UTF-8 cleanliness, so the recorded
   reproduction command above is the pin.  There is no oracle for (c)
   or (d): both are prelude-reader behaviour, outside this slice.
5. The decision. Document all four, in the example header at
   examples/guard-cd.tot:12-20, in the inline copy at
   test/surface.ml:775-783, in the changelog bullet at SPEC.md:1763 and
   in this note.

### 4. Mutation proofs and closing verification

The finalizer records three independent live mutations below.  MB-1
uses the type-correct replacement from C-B3.  Each run must first
pass its own standalone leg, fail at its named marker in its own
full battery log, pass its standalone red check, and restore both
the source bytes and its green standalone leg.  No kernel mutation,
gate deletion or timing-threshold change is part of this protocol.

#### MB-1

- One edit: `examples/guard-cd.tot:341`.  The exact diff is
  `/Users/oobi/Documents/gpt1/tot-m9b-mutations/MB-1/MB-1.patch`.
- Full battery: exit 1, with the named FAIL in
  `/Users/oobi/Documents/gpt1/tot-m9b-mutations/MB-1/MB-1-battery.log`.  No earlier leg stopped it.
- Standalone red result, exit 1:

```text
FAIL-M9B-CD-PORT (check_rc=0 deny= allow=)
```

- Before md5 `8051d1bd92b2482007f058b4f5405605`; restored md5
  `8051d1bd92b2482007f058b4f5405605`.  The restored standalone leg exits 0.
  Both digests name the pre-review revision of
  examples/guard-cd.tot, which is the bytes this run used.  The
  review round adds a header comment to that file and moves it to
  md5 `80d17c08e454c6c038d5431dfa82de94`; the mutation, its red
  result and its restore are unaffected.

#### MB-2

- One edit: `dev/M9-BUILD-LOG.md:445`.  The exact diff is
  `/Users/oobi/Documents/gpt1/tot-m9b-mutations/MB-2-retry-1/MB-2.patch`.
- Full battery: exit 1, with the named FAIL in
  `/Users/oobi/Documents/gpt1/tot-m9b-mutations/MB-2-retry-1/MB-2-battery.log`.  No earlier leg stopped it.
- Standalone red result, exit 1:

```text
FAIL-M9B-DEMAND-ORACLE (word_rc=1 rule_rc=1 log_count=3)
```

- Before md5 `398f09996c6e38ae2f0e0d26cbf30a43`; restored md5
  `398f09996c6e38ae2f0e0d26cbf30a43`.  The restored standalone leg exits 0.

#### MB-3

- One edit: `dev/m9b/regex-fidelity.tot:13`.  The exact diff is
  `/Users/oobi/Documents/gpt1/tot-m9b-mutations/MB-3/MB-3.patch`.
- Full battery: exit 1, with the named FAIL in
  `/Users/oobi/Documents/gpt1/tot-m9b-mutations/MB-3/MB-3-battery.log`.  No earlier leg stopped it.
- Standalone red result, exit 1:

```text
FAIL-M9B-REGEX-FIDELITY (out=ASSIGN_WORD=FALSE NOT_A_PROGRAM=FALSE)
```

- Before md5 `3e038f72df963f961c3e2d8f6fba5a23`; restored md5
  `3e038f72df963f961c3e2d8f6fba5a23`.  The restored standalone leg exits 0.
  This battery also ran against that same pre-review revision of
  examples/guard-cd.tot, md5 `8051d1bd92b2482007f058b4f5405605`.
  dev/m9b/regex-fidelity.tot does not move in the review round, so
  its two digests above still name the shipped bytes.

### 5. Re-derivations, old value then new value

The stage moves eight gate comparisons over six legs.  Each pair gives
the leg name, the address in dev/gates.sh, the old value, the new value
and the recipe that re-derives it.

- `PASS-M5D-TIERS (dev/gates.sh:2353): m5d_tiers 241 -> 247, recipe rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh`
- `PASS-M6E-GUARD-HOLES (dev/gates.sh:3208): m6e_holes 69 -> 76, recipe python3 dev/hole-anchors.py then rg -c 'anchor=\[_\]'`
- `PASS-M6E-ANCHORS (dev/gates.sh:3231): m6e_want ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30 -> total=106 expected-type-only=65 argument-driven=11 neither=30`
- `PASS-M7A-SETTLE (dev/gates.sh:3620-3621): m7a_files 104 -> 105, m7a_green 62 -> 63, m7a_digest 9278f6b7034f2f65b6d789e9e1d74a90 -> 7aed51dddf358f0bb1742838b5616717`
- `PASS-M7B-GUARD-ARG-HOLES (dev/gates.sh:3681): m7b_holed 69 -> 76`
- `PASS-M7D-ANCHORS (dev/gates.sh:3852): m7d_want, same census move as M6E`

Both PASS-M5D-TIERS readings, 241 before the stage and 247 after it,
come from the leg's own recipe, which answers the plan bullet at
M9-PLAN.md:1883.  The rollback at M9-PLAN.md:1889 reverts these
literals through this section.

### 6. Exit state

The fresh build and restored closing batteries both exit 0.  Each has
447 PASS lines in the gate slice and 451 in the wrapper.  The build,
kernel suite and surface suite also exit 0.  There are zero FAIL lines.
The closing log is `/Users/oobi/Documents/gpt1/tot-m9b-close.log`.

The continued validation runner waits for load below 20 for at most
120 seconds per remaining run, then runs at the observed load.
Timing assertions are unchanged. Successful results require completed
green batteries. Recorded scheduling evidence:

- `MB-2-retry-1`: waited 120.034s, load 47.51 to 240.35, `bounded-wait-expired`.
- `MB-3`: waited 120.003s, load 93.82 to 70.67, `bounded-wait-expired`.
- `tot-m9b-close`: waited 120.005s, load 46.75 to 29.02, `bounded-wait-expired`.

The complete records are in `/Users/oobi/Documents/gpt1/tot-m9b-load-waits.jsonl`.

Earlier attempt logs are preserved without replacement:

- `/Users/oobi/Documents/gpt1/tot-m9b-build-census-failure.log`: `GATE-EXIT=1`, `FAIL-M5D-MEASURE-LOG`.
- `/Users/oobi/Documents/gpt1/tot-m9b-build-runner-failure.log`: `BUILD-EXIT=127`, `no FAIL marker recorded`.
- `/Users/oobi/Documents/gpt1/tot-m9b-mutations/MB-2/MB-2-battery.log`: `GATE-EXIT=1`, `FAIL-B-DIV-MEMO`.

Completed build and mutation results are reused only after checking
the matching restored source bytes. Failed or incomplete attempts do
not count as successful proofs.

The PASS multiset gains exactly three gate markers and two suite
cases, and loses nothing:

```text
PASS M9B-1 m9b_cd_port_checks: the shipped fuel-based wordEnd checks in process
PASS M9B-2 m9b_regex_fidelity_line: the in-process diagnostic prints the recorded line
PASS-M9B-CD-PORT
PASS-M9B-DEMAND-ORACLE
PASS-M9B-REGEX-FIDELITY
```

Canonical settle recipe: files=105, green=63,
digest=`7aed51dddf358f0bb1742838b5616717`.  This is measured in the original checkout
and agrees with the proposed literal.  Its complete per-file records
are in `/Users/oobi/Documents/gpt1/tot-m9b-canonical-corpus.json`.  The old triple is 104, 62,
`9278f6b7034f2f65b6d789e9e1d74a90`.  The clone-only digest was
`6101678893d29155f80e82f5feaaf91e`; it is not the production pin.
The actual gate recipe independently passes in both green batteries.

The two refused messages, captured verbatim at exit 1:

```text
/Users/oobi/Documents/tot/dev/m9b/wordend-index.tot: 7:1: recursive definition wordEnd failed the structural termination guard
/Users/oobi/Documents/tot/dev/m9b/rule-table-nested.tot: 2:1: invalid constructor mkRule: negative or non-uniform occurrence of Rule
```

All three mutation proofs have their own attributable red battery,
standalone red result, byte-identical restore and green restored leg.
The last full battery runs after all restores.  Existing assertions,
timing thresholds and the accepted plan are unchanged except the eight
explicitly re-derived gate comparisons.  Corpus/transcript counts are
106/106, gate echoes 181, and watchdog call sites 247.

The code review found no remaining substantive finding.  The OCaml
helper uses Result and Option combinators, total list access and
Fun.protect for descriptor restoration.  Both source strings are
byte-identical in-process inputs.  The final mechanical inspection
checks the exact nine paths, oracle hashes, inline bytes and old gate
code.  Staging follows the mechanical and whitespace checks.

Stage B is intended for a separate user commit.  Stage C's twelve
surface interfaces remain the next stage, after that commit.  No
commit, push or hook installation was performed.

### 7. Review round (2026-09-06)

An independent review of the staged Stage B set returned seven accepted
findings: three HIGH, three MED and one LOW.  All seven are applied.
This section records each fix, the standalone leg results and every
re-derived value.

1. J1 (HIGH), test/surface.ml:735-777.  `m9b_expect_source_prints`
   called six raising functions with no fence, in a file that fences
   every raising Unix call by name.  The body now fences `Unix.dup`,
   the `Unix.dup2` and `Unix.close` of the restore, the `Unix.dup2`
   onto stdout, `Out_channel.with_open_bin` and
   `In_channel.with_open_text`.  Each fenced arm returns
   `Error (label ^ ": ...")`, so the helper keeps its
   `(unit, string) result` type and no exception escapes.
2. J2 (HIGH), dev/M9-PLAN.md:1893-1903 and this log.  The rollback
   named three of the eight moved gate literals and one of the four
   staged SPEC.md blocks.  Section 5 above lists all eight pairs,
   conflict note C-B10 books the incomplete rollback, and the rollback
   line now names the five further literals and the current address
   SPEC.md:2678.
3. J3 (HIGH), dev/gates.sh:4554, :4558, :4575 and :4577.  CD-PORT
   accepted any deny JSON that contained `"permissionDecision":"deny"`,
   and REGEX-FIDELITY read two substrings with no exit code.  CD-PORT
   now compares the whole envelope with `m9b_cd_wantdeny`, and
   REGEX-FIDELITY pins `m9b_regex_rc` at 0 and compares the whole
   output.  Both FAIL lines echo the wanted value.
4. J4 (MED), dev/gates.sh:4555-4556, :4559, :4573-4574 and :4578.  The
   claim at item 6 of C-B4 above, that both program sources stay inline
   and byte identical to their files, had no gate.  Each leg that runs
   one of the two files now also compares the md5 of the inline
   literal, extracted by awk, with the md5 of the file.  No md5 value
   is pinned as a literal, so the conjunct goes red on divergence only.
5. J5 (MED), SPEC.md:2394.  The line attributed three gates to the
   superseded M7 census one line above it.  It now reads that the three
   gates read that record until M9 Stage B and read the census at the
   end of the section now.  The replacement stays one line, so no SPEC
   address moves.
6. J6 (MED), examples/guard-cd.tot:12-20, test/surface.ml:775-783,
   SPEC.md:1763-1764, dev/gates.sh:4552 and conflict note C-B11 above.
   The four documented differences from the source hook are recorded in
   the example header, in the inline copy of that header, in the
   changelog bullet and in C-B11.  The deny probe runs with
   CLAUDE_ALLOW_CD_PREFIX=1 set, so the leg asserts that the port
   ignores the source hook's bypass variable.
7. J7 (LOW), dev/gates.sh:4566, :4569 and :4571.  The third conjunct of
   DEMAND-ORACLE read an unanchored pattern through `head -1` over this
   growing file, so a later sentence of the same shape above line 445
   turned the leg red with no code change.  The conjunct now counts the
   anchored line and compares that count with 1; `${m9b_log_count:-0}`
   keeps a missing log red, and the FAIL label reads `log_line=`.

The three M9B legs and PASS-M5D-MEASURE-LOG, lifted standalone with
ROOT, the watchdog and the tier variables bound as this file's battery
binds them, print:

```text
PASS-M9B-CD-PORT
PASS-M9B-DEMAND-ORACLE
PASS-M9B-REGEX-FIDELITY
PASS-M5D-MEASURE-LOG
```

PASS-M5D-MEASURE-LOG reads the battery's own measurement log, which no
standalone run writes.  The standalone run reads the recorded
measurement log of the staged slice, cut at the row the leg reads
during the battery: 22 MEASURE rows and the census line.

Both suites exit 0.  The kernel suite tail is `M0 kernel: all tests
green`; the surface suite tail is `M1 surface: all tests green`, with
`PASS M9B-1` and `PASS M9B-2` both present.

Re-derived after the round: watchdog call sites 247; gate echo sites
181; debt entry 11 at SPEC.md:2678; the trailing SPEC census reader
`expected-type-only=65`; the anchored demand line, one match;
dev/m5e-default-transcript.txt md5 `d7431c69f0ce07a9d8047f104e545df0`,
unchanged; examples/guard-cd.tot md5
`8051d1bd92b2482007f058b4f5405605` before the header comment and
`80d17c08e454c6c038d5431dfa82de94` after it; each inline md5 equal to
its file md5, `80d17c08e454c6c038d5431dfa82de94` for the guard and
`3e038f72df963f961c3e2d8f6fba5a23` for the diagnostic.

Four address effects of this round are recorded here rather than by a
rewrite of the earlier records.  The rollback repair grows
dev/M9-PLAN.md from 3091 to 3096 lines, so the Stage A E3 citation of
plan :1904 now reads plan :1909.  The J1 and J6 edits move
test/surface.ml, so item 4 of C-B4 cites pre-round addresses; the
current ones are the helper at :733, the two inline sources at :781 and
:1149, and the two cases at :2939 and :2941.  The MB-2 red text above
was captured with the pre-J7 FAIL label `log_count`, which J7 renames
to `log_line`.  The SPEC.md changelog bullet keeps its ten lines and
wraps wider to hold its new sentence, so debt entry 11 and the census
keep their addresses.

Sixteen further lens findings fold into the seven above, and seven are
dropped: the plan's "whole line" wording for the wordEnd refusal, the
missing inline provenance sentence on the three new legs, the MB-2
digest provenance, the fuel and cap coupling comment in the guard, the
deny rendering in surface/effect.ml, a third CD-PORT payload, and a one
character citation drift in dev/m9b/wordend-index.tot.

## Stage C (2026-09-06): the twelve surface interfaces

### 1. Entry state

Stage B is committed as d48a81c96c848e3db0fda0a7bce9985751081187.
The canonical working tree and index were clean.  The fresh entry run
used the same four-command battery as Stage B:

```sh
zsh -f /Users/oobi/Documents/gpt1/tot-m9b-battery.sh /Users/oobi/Documents/gpt1/tot-m9c-entry.log /Users/oobi/Documents/tot
```

The measured entry is 447 slice, 451 wrapper, with 105 kernel cases
and 160 surface cases.  BUILD-EXIT, MAIN-EXIT, SURFACE-EXIT and
GATE-EXIT are all 0; there are zero FAIL lines.  The baseline manifest
is /Users/oobi/Documents/gpt1/tot-m9c-baseline.json, and the parsed
counts are /Users/oobi/Documents/gpt1/tot-m9c-entry-summary.json.
Surface has twelve implementations, zero interfaces and a basename
gap of twelve.  The existing gate file has 181 echo sites; the M9C
marker namespace is empty.  Stage A and B markers are already present.

### 2. What changed

Exactly sixteen paths belong to Stage C: twelve new surface interfaces,
dev/gates.sh, test/surface.ml, SPEC.md and this log.  All twelve
surface implementation files retain their original MD5s.  No lib file,
prelude, corpus fixture, transcript, plan or build configuration changes.

The interface discovery includes unqualified calls between surface
modules and Tot_surface-qualified calls in bin and both suites.  It
includes mutually recursive declarations, such as Effect.dispatch.
The new interfaces retain every public constructor and record field
their callers need, kernel type equalities, polymorphism and optional
arguments.  Loc retains the full signature explicitly printed in the
plan.  The export inventory is:

| Module | Exported values |
| --- | --- |
| Bootstrap | kept_pi_count, phase1_prims, phase2_prims, phase3_prims, prelude_source, state, state_of_src_tailed, cached_state_of_src |
| Cache | format_version, magic_width, version_width, digest_width, header_width, cache_dir, key, load, save |
| Effect | deny_envelope, require_action, run_io, dispatch, render_verdict |
| Elab | term, term_at |
| Lexer | lex |
| Loc | start, next_col, advance, next_line, to_string |
| Parser | parse_with_holes, parse, term_only |
| Run | initial, default_policy, kernel, compute_guard, instance_key, item, hole_tail, script_tailed, script |
| Serror | to_string, tag, driver_exit, is_check_budget, is_missing_main |
| Source | message, read |
| Syntax | loc_of |
| Token | describe |

Cache exports exactly nine values.  The internal gate pins the first
six positive declarations, through cache_dir, and requires the scan for
ensure_dir, mkdir_one and write_exe_memo to exit 1 with no output.
exe_width is also absent from the signature.  key, load and save are
used by Bootstrap and the existing cache tests.

The coverage gate requires successful comm, an empty missing-name set,
twelve implementations and twelve interfaces.  Both new gates precede
the two fixed-last timing legs.  They add no watchdog call.  M9C-1 is
the only new suite case and reads Cache.format_version through the
interface, asserting 10.  SPEC's appended milestone record carries
C2 first and soaks, then C1, with Stage B's reading of two and neither
debt reduced.

### 3. Conflict notes

**C-C1: Stage C's suite paragraph repeats the pre-B count.**

1. Predicted.  dev/M9-PLAN.md:2388-2390 says the surface suite moves
   from 158 to 159.  Its stage entry and review checklist instead say
   160 to 161 after Stage B.
2. Measured.  The fresh entry battery contains 105 kernel PASS lines
   and 160 surface PASS lines, with all four command exits 0.
3. Command and output.  The absolute battery command in section 1
   produced `M0 kernel: all tests green`, `M1 surface: all tests green`
   and `GATE-EXIT=0`.  Counting PASS lines between each suite's bounds
   produces `main=105 surface=160`; the entry-summary JSON records
   those bounds' results and `slice=447 wrapper=451`.
4. Cited lines.  dev/M9-PLAN.md:2026-2031 includes Stage B's two
   cases.  test/surface.ml:2947 and :2949 are those preserved cases
   after Stage C's eight-line insertion.
5. The smallest reading that fits.  The suite paragraph retained a
   pre-B estimate; Stage C still adds exactly one surface case.
6. The decision.  Use the measured post-B entry and the consistent
   stage-table delta, 160 to 161, leaving the accepted plan unchanged.

**C-C2: full inferred signatures versus the used public API.**

1. Predicted.  dev/M9-PLAN.md:2072-2078 requires each interface to
   export exactly its currently used public names, while :2123-2128
   calls the other eleven modules exact restatements.  Its top-level
   declaration counts omit recursive `and` bindings.
2. Measured.  Effect.dispatch is declared with `and` at
   surface/effect.ml:183 and called by test/surface.ml.  Bootstrap's
   cached_state has no live external caller.  The selected interfaces
   compile without exposing that helper.
3. Command and output.  From the writable checkout,
   `dunecho --warn build -- --root /Users/oobi/Documents/gpt1/tot-m9-stage-c`
   printed `OK build: 0 errors, 0 warnings`.  Each of the five larger
   modules was also checked with ocamlc -i against the baseline CMIs;
   all five commands exited 0 and matched the selected signatures.
4. Cited lines.  surface/effect.mli exports dispatch;
   surface/bootstrap.mli exports the eight live-client values listed
   above.  dev/M9-PLAN.md:2399-2404 requires no widening past the
   discovery result and a warning-free build.
5. The smallest reading that fits.  Restate the types of used names,
   including recursive declarations, without publishing unused helpers.
6. The decision.  Follow the explicit used-API and no-widening rules,
   with the full Loc signature separately mandated at plan :2132-2143.
   Public sum types and records remain concrete.  No warning suppression
   or implementation change is needed.

**C-C3: insertion addresses and marker absence are reference-state facts.**

1. Predicted.  dev/M9-PLAN.md:2089-2091 names the D4 insertion boundary
   at test/surface.ml:1804-1806; :2085-2087 names ctxcat id 5 at
   dev/gates.sh:4526; :1977-1982 says the M9 prefix is unused at the
   pre-M9 reference HEAD.
2. Measured.  At Stage B HEAD the D4 comment is at test/surface.ml:2257
   and ctxcat id 5 is at dev/gates.sh:4583.  The M9A and M9B markers
   exist, and M9C is absent.
3. Command and output.  Before inserting the blocks,
   `rg -n 'M3 Stage D, D4' /Users/oobi/Documents/tot/test/surface.ml`
   printed `2257:    (* M3 Stage D, D4: render_verdict and the main : IO Verdict`;
   `rg -n '^# ctxcat id 5:' /Users/oobi/Documents/tot/dev/gates.sh`
   printed `4583:# ctxcat id 5: an instance with TWO dictionary binders on the SAME type`.
4. Cited lines.  The final additions begin at test/surface.ml:2257
   and dev/gates.sh:4583; the preserved anchors move to :2265 and
   :4622 respectively.  The earlier C-B4 record now resolves to helper
   :733, inline sources :781 and :1149, and cases :2947 and :2949.
5. The smallest reading that fits.  Earlier stage additions shifted
   addresses and occupied their own marker letters.
6. The decision.  Locate insertion boundaries by content and check
   absence only for M9C.  Removing the new blocks reproduces both
   original files byte for byte, including every old gate comparison.

### 4. Validation and mutation proofs

The writable-checkout build compiled bin and both suites with zero
errors and zero warnings.  Both suites passed.  Removing only the
format_version declaration from cache.mli produced this compiler error:

```text
File "test/surface.ml", line 2260, characters 21-53:
Error: Unbound value "Tot_surface.Cache.format_version"
```

The raw diagnostic is
/Users/oobi/Documents/gpt1/tot-m9c-compile-negative.log.  Its first
capture script expected an unquoted identifier, so its diagnostic-text
assertion failed after the compiler had produced the intended error.
The finally block restored cache.mli to MD5
539206f860c1368552a2e7b055204a8d; the subsequent suite builds passed.
This compile-negative check is separate from the two gate mutations.

The exact static gate bodies were extracted into scratch fixtures.
Both passed with all interfaces present.  Deleting loc.mli produced
`FAIL-M9C-SURFACE-MLI-COVERAGE (missing=1 comm=0 ml=12 mli=11)`.
After restoring it, adding only `val ensure_dir : string -> unit`
below format_version produced FAIL-M9C-SURFACE-INTERNAL with add_code=0
and all six positive counts still 1.  Both restorations were
MD5-identical.  Missing cache.mli, missing format_version and duplicate
format_version controls also failed.  Full captured results are in
/Users/oobi/Documents/gpt1/tot-m9c-static-gates.json.

An independent review found no defects in the five larger interfaces
or the gates and suite diff.  Exported values have live callers;
records, constructors, type equalities and optional argument order
match their implementations.  The remaining seven interfaces' type
declarations were compared to their implementations with comments and
whitespace removed.  Shell syntax and git diff --check passed.

### 5. Re-derivations

The only intended count changes are the interface count 0 to 12,
basename gap 12 to 0, gate echo sites 181 to 183 and surface cases
160 to 161.  The gate slice therefore moves 447 to 450 and the wrapper
451 to 454.  These exit predictions are checked against the actual
canonical run in section 6.  Kernel cases remain 105.

All existing gate code is byte-identical after removing the two new
legs.  In particular, conservativity stays
f1450de0006de4b7339b2f39ec2e2e50 at 43 lines, both existing digest
legs remain, watchdog call sites remain 247, and all Stage B census,
settle-budget and transcript comparisons stay fixed.  Corpus membership
and all twelve surface implementation MD5s match the entry manifest.

### 6. Exit state

The canonical initial and restored closing batteries both pass at
450 slice and 454 wrapper.  Both contain 105 kernel cases and 161
surface cases, with zero FAIL lines and all four command exits 0.
All four canonical validation builds report zero errors and zero
warnings.  The entry and exit
multiset comparison removes no old PASS and adds exactly these three:

```text
PASS-M9C-SURFACE-MLI-COVERAGE
PASS-M9C-SURFACE-INTERNAL
PASS M9C-1: surface/cache.mli seals format_version at 10, the invariant carried M8 R-Q6 and this ratification both forbid moving
```

All runs use the section 1 battery command, changing only its output
path.  Raw logs under /Users/oobi/Documents/gpt1 are:

| Log | Slice | Wrapper | Gate exit | Result |
| --- | --- | --- | --- | --- |
| tot-m9c-entry.log | 447 | 451 | 0 | Stage B baseline |
| tot-m9c-build.log | 450 | 454 | 0 | Complete Stage C tree |
| tot-m9c-mc1.log | 446 | 450 | 1 | Only the missing-interface gate fails |
| tot-m9c-mc2.log | 447 | 451 | 1 | Only the cache-internal gate fails |
| tot-m9c-close.log | 450 | 454 | 0 | All mutations restored |

Each mutation's build and both standalone suites exit 0.  Its full
gate run reaches the intended new leg before failing, with exactly
one FAIL line.  MC1 deletes only surface/loc.mli and reports
missing=1, comm=0, ml=12, mli=11.  MC2 adds only the ensure_dir
declaration and reports add_code=0 while all six required export counts
remain 1.  MC2 first passes the coverage leg.  The two original files
are restored before the next run, with MD5s:

```text
surface/loc.mli   fca08142c574161210ddefb07a395b39
surface/cache.mli 539206f860c1368552a2e7b055204a8d
```

The complete machine-readable results, including captured PASS lists,
all command exits, failures and restore hashes, are in
/Users/oobi/Documents/gpt1/tot-m9c-validation.json.  The four Stage C
validation runs each have a sibling measure log.  No gate, comparison, timing tier or budget
was waived or weakened.  The measured entry and exit totals match the
stage table, so they require no further count correction.

The final metadata is appended after the restored battery.  SPEC stays
byte-identical to the validated version.  The staging helper requires
this log to retain the entire validated prefix and rechecks its only
gate input, the anchored demand-count line, at exactly one match before
and after copying.  All other staged files must match the validated
install manifest.  Persistent mutation originals are retained in
/Users/oobi/Documents/gpt1/tot-m9c-restore/ for interrupted-run recovery.

Stage C completes M9's interface sweep.  The next milestone retains
the ratified C2-first order and its sign-lattice design obligation;
no M10 kernel rule is part of this stage.
