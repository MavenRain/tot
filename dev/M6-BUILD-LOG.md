# M6 build log

Companion to dev/M6-PLAN.md.  One section per stage, in the M5 shape
(dev/M5-BUILD-LOG.md):  entry state, what changed, tests, markers,
conflicts, mutation proofs, exit criteria, counts with their commands.
Working-tree only:  nothing here was staged or committed by the
builder.

## Stage A (2026-09-03): delete `--experimental-wf`, keep the WF oracles flag-free, fence tripwires, transcript reseal

Plan: dev/M6-PLAN.md section "Stage A" (A0-A14), verdict pins 7-10
and 14, ruling R1.  Chain: MEASURED 334 -> TARGET 339 -> MEASURED 339.

### 1. Entry state

- `git log -1 --oneline` = `18b7ab6 dev/M6-PLAN.md: staged plan for
  M6 (holes, blocking Unit posture, WF deletion)` (M5 commit 8d5a839
  plus the plan);  `git status --porcelain` empty at entry.
- Entry battery (runner /Users/oobi/Documents/tot-m6-stageA-gate.sh,
  log /Users/oobi/Documents/tot-m6-stageA-entry-gate.log):
  `rg -c '^PASS'` = 334, `rg -c '^PASS-'` = 121 (markers),
  `rg -c '^PASS[^-]'` = 213 (suite cases: kernel 106 + surface 107),
  `rg -c FAIL` = 0, last line `GATE-EXIT=0`.  The PASS lines are
  byte-identical to the main loop's baseline
  /Users/oobi/Documents/tot-m6-baseline-gate.log (diff of the two
  `rg '^PASS'` extracts empty).
- A0 probes P1-P15 reproduced before the first edit (script
  /Users/oobi/Documents/tot-m6-probes/stage-a-build/run-a0-probes.sh,
  log a0-probes.log in the same directory), byte for byte against
  the plan's recorded outputs.  A0 counts at HEAD, each reproduced:
  `rg -c '~rule:Totality\.Structural' test/main.ml` = 32 (prefix
  count), `rg -c '~rule:Totality\.Structural\b' test/main.ml` = 30,
  `rg -c '~rule:Totality\.Structural_wf' test/main.ml` = 2, 33
  `~rule` lines in total (30 + 2 + 1 bare pass-through);
  `rg -c 'wf_rule' test/surface.ml` = 3;  `rg -c 'PASS-M6' dev/gates.sh`
  exit 1;  `rg -c 'PASS-M5E' dev/gates.sh` = 6;  `rg -c 'Structural_wf'`
  = 5 (lib/totality.ml), 1 (lib/check.ml), 1 (surface/run.ml), 1
  (bin/tot.ml), 6 lines in test/main.ml;  `rg -c 'experimental'
  bin/tot.ml` = 5;  transcript 80 `### ` blocks / 9660 lines;  corpus
  6 examples + 74 fixtures = 80;  tiers 122;  `rg -c '"\$watchdog"
  [0-9]+' dev/gates.sh` exit 1;  118 `echo PASS-` sites.
- Entry md5 (`md5 -q`): lib/totality.ml ed48fc4fa37879f6a744a26b150996c4,
  bin/tot.ml 9c56093da1a221a4480e2dcba460a1f1, surface/run.ml
  72ecaed635b43c16d5a6bb3f0889873c, lib/check.ml
  8f219eaf9f316b69fee4e6f096e741b1, test/main.ml
  e379b3deb23cb43569e1a20b3fc13968, test/surface.ml
  016518e37e60059b1cec060ec0ee8ef9, dev/gates.sh
  5bc85ab97530440cb869b8e8bdbb791c, test/fixtures/m5e-acc.tot
  6c2a79f5dcf6a3ea78820c59634d6355, test/fixtures/m5e-witness.tot
  5d87bc3be73415d3923a0055dcd304d8.

### 2. What changed

Files (`git status --porcelain` at exit, section 8):  modified
SPEC.md, bin/tot.ml, dev/gates.sh, dev/m5e-default-transcript.txt,
lib/check.ml, lib/totality.ml, surface/run.ml, test/main.ml,
test/surface.ml;  new test/fixtures/bad2.tot, crossformal-t.tot,
deep2.tot, nested-neg.tot, nested-pos.tot, and this log.
`git diff --stat`: 9 files changed, 245 insertions(+), 114
deletions(-) before this log and the fixtures (untracked).

- A1 bin/tot.ml: the `experimental_wf` record field and its doc, the
  `experimental_wf = false` default, the `"--experimental-wf"` parse
  arm and the three-line `wf_rule = (if ... Structural_wf else
  Structural)` policy line in `dispatch` are deleted;  the usage
  string loses `[--experimental-wf] ` and is now the three-line
  literal the plan pins.  The unknown-flag arm is untouched and now
  owns the deleted spelling.  `rg -c 'experimental' bin/tot.ml` exit 1.
- A2 surface/run.ml: the `wf_rule : Totality.rule` field and its doc
  are deleted;  `default_policy = { no_axioms = false; require_main =
  false; strict_json = false }`;  the `Check.define` call names
  `~rule:Totality.Structural` literally, under the pinned pin-8
  comment.  `rg -c 'wf_rule' surface test bin` exit 1.
- A3 lib/totality.ml: the totality rule collapses from
  `type rule = | Structural | Structural_wf` to the single-constructor
  `type rule = Structural` under the pinned pin-8 doc block;  the
  `Term.App` arm of `guarded_call` loses the accessibility clause and
  is now `match rule with | Structural -> false` under the pinned
  comment (the match on `rule` is kept as the M7 re-entry point);
  `guard`'s doc is one sentence on the single rule plus the re-entry
  pointer.  `spine`, `smaller_at` and `principal_or_smaller_at` all
  keep callers (the `ok` App arm and `scrut_special`).
- A4 lib/check.ml: the `[rule]` doc on `define` and the
  `define_instance` comment are rewritten to the pin-8 posture (REQUIRED
  `~rule`, single constructor, the instance dead spot recorded).  Zero
  code changes;  `define ~rule:Totality.Structural` in
  `define_instance` is byte-unchanged.
- A5 test/main.ml: kernel case E1 (`case_m5e_wf_accepts_acc_rec`)
  deleted;  E2 becomes `case_m5e_shipped_rule_rejects`, two
  `m5e_expect_termination` calls ("E2 (accRec)" on `m5e_acc_rec_body`,
  "E2 (witness)" on `m5e_bad_body`, both `~rule:Totality.Structural`)
  under the pinned comment;  the registration is the single line
  `("E2: the shipped rule rejects accRec and the panel witness",
  case_m5e_shipped_rule_rejects)`.  `m5e_acc_rec_body`, `m5e_bad_body`
  and `m5e_expect_termination` are unchanged.
- A6 test/surface.ml: the usage pin loses `[--experimental-wf] `
  (byte-match with A1);  the case comment gains the pinned M6 sentence;
  the three `wf_rule = Tot_kernel.Totality.Structural;` lines (HEAD
  442, 756, 1625) are deleted (conflict note C-A2 honored).
- A7 five fixtures written verbatim from the plan (declarations
  first, the comment block below):  bad2.tot (bad2 at 2:1),
  crossformal-t.tot (bad at 2:1), deep2.tot (deep2 at 2:1),
  nested-pos.tot (mkt2 at 2:1), nested-neg.tot (mkt3 at 2:1).
  test/fixtures/m5e-acc.tot and m5e-witness.tot are byte-identical
  (md5 above, re-verified at exit).
- A8 transcript reseal: `zsh dev/gen-m5e-transcript.sh >
  dev/m5e-default-transcript.txt` after the rebuild (script
  unchanged);  section 3 has the diff.
- A9 dev/gates.sh: the TIERS literal `-eq 122` -> `-eq 126` with the
  dated M6 Stage A sentence appended after the M5E sentence;  the
  DEFAULT-IDENTITY comment now names the M6 Stage A reseal over 85
  files;  PASS-M5E-ACC-CHECKS (HEAD 2436-2446) deleted;
  PASS-M5E-WITNESS-REJECTED (HEAD 2448-2471) replaced by the plan's
  verbatim block (M6 header comment, the flag-free WITNESS leg with
  `wantw`, then the seven PASS-M6A legs with `wanta`, `wantb`, `wantx`,
  `wantd`, `wantp`, `wantn`), spliced by anchor between the blank line
  after Gate E (i) and the blank line before `# ctxcat id 5:`
  (2539 -> 2603 lines).  The M5 Stage E header comment (now
  2409-2419) is left as history: a non-change.  `zsh -n dev/gates.sh`
  exit 0;  the block has no `for`/`while` (the only loop keywords in
  the file are the pre-existing M5-era legs at 1394, 1785, 1973, 2080,
  2083), no `set -u` (the only hit is the line-2 comment forbidding
  it), no numeric watchdog literal.
- A11 SPEC.md: four `- 2026-09-03 (M6, Stage A): ...` bullets at the
  end of section 2 (now lines 1115-1173, before `## 3.`):  the
  deletion with the re-homed cache sentence and the `define_instance`
  dead spot;  the seed invariant;  the fence tripwires;  the
  transcript reseal.  The section 6 residual bullet gains its
  `DELETED by M6 Stage A (ruling R1, 2026-09-03)` discharge (line
  1757);  M5 history untouched.
- Error.t / Serror.t: no variant added, none removed.  Stage A adds
  no error and no message;  every new oracle pins a message that
  already existed at M5 exit.
- `Cache.format_version` stays 10 (`rg -o 'let format_version : int
  = [0-9]+' surface/cache.ml` = `let format_version : int = 10`);  no
  rule ever entered the cache key, so nothing forced a bump (pin 15).
- Hook denials: none.  No plan-pinned spelling was refused.

### 3. Tests added and retired, transcript

- Kernel suite 106 -> 105: E1 retired, E2 converted (count neutral).
  `dune exec --root . test/main.exe | rg -c '^PASS '` = 105.
- Surface suite 107 -> 107 (`... test/surface.exe | rg -c '^PASS '`).
- Transcript: old 9660 lines / 80 blocks, new 9685 lines / 85 blocks
  (`wc -l`, `rg -c '^### '`).  `diff old new`: 0 deletions, 25
  additions, exactly five 5-line blocks, each `#exit 1`, empty `#out`,
  one stderr line:
  `84a85,89` test/fixtures/bad2.tot:2:1: recursive definition bad2
  failed the structural termination guard;  `107a113,122`
  crossformal-t.tot:2:1 ... bad ... and deep2.tot:2:1 ... deep2 ...
  (same message);  `9576a9592,9601` nested-neg.tot:2:1: invalid
  constructor mkt3: negative or non-uniform occurrence of T3 and
  nested-pos.tot:2:1: invalid constructor mkt2: negative or
  non-uniform occurrence of T2.  Every line matches the A7 expected
  line for its fixture.  Old and new copies:
  /Users/oobi/Documents/tot-m6-probes/stage-a-build/transcript-old.txt,
  transcript-new.txt, transcript.diff.

### 4. Markers

- Retired (1): PASS-M5E-ACC-CHECKS (leg deleted;  the only remaining
  mention in dev/gates.sh is the plan's verbatim Gate A (ii) comment
  naming what it replaces).  `rg -c 'PASS-M5E-ACC-CHECKS'
  /Users/oobi/Documents/tot-m6-stageA-gate.log` exit 1.
- Rewritten flag-free (name kept): PASS-M5E-WITNESS-REJECTED.
- Added (7): PASS-M6A-WF-FLAG-UNKNOWN, PASS-M6A-ACC-GUARD-REJECTED,
  PASS-M6A-INFINITARY-REJECTED, PASS-M6A-CROSSFORMAL-REJECTED,
  PASS-M6A-DEEP2-REJECTED, PASS-M6A-FENCE-COVARIANT,
  PASS-M6A-FENCE-CONTRAVARIANT.  `rg -o 'PASS-M6[A-E]-[A-Z0-9-]+'
  dev/gates.sh | sort -u | wc -l` = 7;  `rg -c 'PASS-M6A' dev/gates.sh`
  = 13 (7 echo sites + 6 comment mentions).
- Markers 121 -> 127 (`rg -c '^PASS-'` on the entry and final logs).
- TIERS coordination (pin 17): `rg -c '"\$watchdog"
  "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` = 122 before the gates.sh
  edit, 126 after (net +4: -1 ACC-CHECKS, -2 WITNESS 3 -> 1, +7 FAST);
  literal edited 122 -> 126 in the same edit.  `echo PASS-` sites
  118 -> 126.  No new gate_timed leg;  PASS-M5D-MEASURE-LOG untouched.

### 5. Conflicts

Inherited from plan A12, honored:

- C-A1 (count precision):  both commands and both numbers carried
  (section 1).  Recount after A5: `rg -c '~rule:Totality\.Structural\b'
  test/main.ml` = 30 (E1's no-flag literal left, the converted E2
  carries two;  the other 28 are byte-unchanged);  the two
  `Structural_wf` literals are gone;  the bare pass-through inside
  `m5e_expect_termination` stays.
- C-A2 (verdict wording versus the type checker):  the three
  test/surface.ml `wf_rule` lines are DELETED, the test/main.ml
  `~rule:` literals name the sole constructor;  a missed literal would
  have failed the build (it built clean first time, 0 errors, 0
  warnings).

New, found while building (pin list wins unless the repo proves the
pin impossible;  here two pins of the plan itself are mutually
impossible, and the verbatim TEXT pin wins over the SWEEP pin because
the sweep's own wording exempts historical mentions):

- Conflict note C-A3 (2026-09-03): A3 (plan line 907), A5 (plan line
  981) and A14 item 3 (plan line 1476) say `rg -c 'Structural_wf'` over
  lib/totality.ml, test/main.ml and `bin lib surface test` must print
  no match and exit 1;  the repo shows three hits that the plan itself
  pins:  lib/totality.ml:13 is the plan's verbatim pin-8 doc block
  (plan line 867, "The M5 [Structural_wf] spike is DELETED, not
  dark"), test/main.ml:2825 is the plan's verbatim E2 comment (plan
  line 955, "E1 (Structural_wf accepts accRec) retired"), and
  test/fixtures/m5e-witness.tot:10 is a comment inside a fixture the
  plan pins byte-identical (pin 14, A7).  Resolution: the verbatim
  text and byte-identity pins win;  the sweep is refined to its code
  forms, which is at least as strong for the sweep's intent and is
  backed by the compiler (with `type rule = Structural` any code use
  of the deleted constructor is an unbound-constructor error, and
  the build is clean):  `rg -c '~rule:Totality\.Structural_wf|\|
  Structural_wf|Structural_wf ->' bin lib surface test` exit 1;
  `rg -n 'Structural_wf' bin lib surface test` prints exactly the
  three comment lines above.  Not silently shrunk:  recorded here and
  in the A14 walk.
- Conflict note C-A4 (2026-09-03): A6 step 1 (plan lines 988-991)
  pins the test/surface.ml case comment to GAIN the sentence "M6
  Stage A: it LOST [--experimental-wf] (ruling R1), same discipline."
  while A6 (plan line 1002) and A14 item 3 say `rg -c 'experimental'
  test/surface.ml` must exit 1;  the repo at test/surface.ml:410-411
  shows the M5 history sentence and the pinned M6 sentence, both
  containing the literal, so the two pins cannot both hold.
  Resolution: the verbatim comment pin wins;  the sweep is refined to
  the code forms:  `rg -c 'experimental' bin/tot.ml` exit 1,
  `rg -c 'experimental_wf' bin lib surface test` exit 1,
  `rg -c 'require-main\] \[--experimental' test/surface.ml bin/tot.ml`
  exit 1 (the usage literals lost the flag), and `rg -n
  'experimental' test/surface.ml` prints exactly lines 410-411 of the
  comment.

- Conflict note C-A5 (2026-09-03): the Stage A task statement and plan
  A0 say the tree is CLEAN at 18b7ab6 when the stage starts;  the repo
  at the second run's entry (05:17) showed the complete Stage A working
  set already in place and unstaged (the porcelain list of section 8,
  this log included;  mtimes 04:51:39 for the earliest edit,
  surface/run.ml, to 05:15:54 for this log), left by the first run of
  this same stage, which wrote this log but returned no result.
  Resolution: nothing is discarded and nothing is re-derived from
  memory.  The second run verifies every artifact of the first run on
  disk (section 9), re-runs the final battery on the unchanged tree,
  and keeps the first run's entry measurement because its log predates
  the first edit (entry log 04:49:42 versus surface/run.ml 04:51:39).
  No gate shrinks:  the exit criteria cite the second run's battery.

Observations that are not conflicts (recorded so they cannot look
like drift):

- MA-5 was predicted to also flip the surface case at
  test/surface.ml:1146 (C6);  observed surface PASS 107 under the
  mutation.  C6's constructor `jarr : List Json -> Json` fails the
  result-head check before positivity runs, so no positivity mutation
  can reach it.  The kernel cases C4 and A5 and both FENCE legs (the
  proof targets) flipped as predicted.
- MA-6 was described as "kernel E2 both halves red";  the `let*`
  chain in `case_m5e_shipped_rule_rejects` reports the first failing
  half (accRec).  The witness half is observed through the
  PASS-M5E-WITNESS-REJECTED leg going red (exit 0, three lines).

### 6. Mutation proofs (plan A10)

Discipline: OCaml mutations only (dev/gates.sh never mutated);  every
mutation applied with `sd -s` from a pristine copy, `md5 -q` before,
rebuild, observation through the suites (`dune exec --root . test/main.exe`,
`test/surface.exe`) and the extracted legs, restore by copying the
pristine bytes back, `md5 -q` identical, rebuild, legs green again.
Driver /Users/oobi/Documents/tot-m6-probes/stage-a-build/mut.sh
(mutation texts inline), leg runner legx-a.sh (extracts Gate E (i)
through `# ctxcat id 5:` from dev/gates.sh as written and runs each leg
in its own subshell so every verdict is seen), full record in
/Users/oobi/Documents/tot-m6-stageA-mutations.log (1327 lines: MA-1
once, MA-2..MA-6 in two rounds, the second round adding the suite
failure lines and the full DEFAULT-IDENTITY diff that the first
round's head-cut hid).  On the unmutated tree all nine extracted legs
are green (exit 0 each).

| # | Mutation (file, md5 mutated) | Observed RED | Restore |
|---|---|---|---|
| MA-1 | bin/tot.ml: accept-and-ignore arm `\| "--experimental-wf" :: rest -> parse_flags opts rest` after the `--strict-json` arm (11c753d65f4480e63fc3ab23c5b2fa82) | Leg A (i): `/Users/oobi/Documents/tot/test/fixtures/m5e-acc.tot:5:1: recursive definition accRec failed the structural termination guard` then `FAIL-M6A-WF-FLAG-UNKNOWN (exit=1)`.  Kernel 105 PASS, surface 107 PASS (suites untouched).  Other eight legs green | md5 889fa8f6efa21c83a1c341d392cefa67 restored;  rebuild OK;  9 legs green |
| MA-2 | lib/totality.ml: the `Term.App` arm's `\| Structural -> false` becomes the M5 spike body (`spine a []`, head `Term.Var ix -> smaller_at st ix`, else false) (637720a483a57c9aee095b7887ad06e7) | Kernel: `FAIL E2: the shipped rule rejects accRec and the panel witness` / `E2 (accRec): guard accepted at k=5, want Termination` / `1 test(s) failed` (104 PASS).  Legs: DEFAULT-IDENTITY red, `FAIL-M5E-DEFAULT-IDENTITY (exit=0/0)`, transcript diff flips bad2.tot and m5e-acc.tot blocks to `#exit 0`;  `FAIL-M6A-ACC-GUARD-REJECTED (exit=0)` after five lines (data Acc, ctor acc, def LtNat, def accRec, def accZero);  `FAIL-M6A-INFINITARY-REJECTED (exit=0)` after three lines (data T, ctor mk, def bad2).  CROSSFORMAL, DEEP2, WITNESS, WF-FLAG, both FENCE legs green | md5 6a3758fedc2aed928943afe05b7b6bfa restored;  rebuild OK;  kernel 105;  9 legs green |
| MA-3 | MA-2 plus seed widening `List.init formals (fun _ -> Principal)` (87e2d7cc5317a4aac26b810ae0af41e2) | Kernel: same E2 line (104 PASS).  Legs: DEFAULT-IDENTITY red (bad2, crossformal-t, m5e-acc blocks flip);  CROSSFORMAL red, leg exit 1 after four lines (data T, ctor tleaf, ctor mkT, def bad: crossformal-t.tot accepted, exit 0);  ACC-GUARD and INFINITARY red as MA-2;  DEEP2 green;  WITNESS green | md5 6a3758fe... restored;  rebuild OK;  kernel 105;  9 legs green |
| MA-4 | MA-2 plus scrutinee widening: `scrut_special` also true when the scrutinee is an application whose spine head is a `Term.Var` with `principal_or_smaller_at` status (ec2ae6948f54eaba01608687b0b1d71c) | Kernel: same E2 line (104 PASS).  Legs: DEFAULT-IDENTITY red (bad2, deep2, m5e-acc blocks flip);  DEEP2 red, leg exit 1 after four lines (data W, ctor leaf, ctor node, def deep2: deep2.tot accepted);  CROSSFORMAL green (leg exit 0);  WITNESS green;  ACC-GUARD and INFINITARY red as MA-2 | md5 6a3758fe... restored;  rebuild OK;  kernel 105;  9 legs green |
| MA-5 | lib/check.ml: `strict_pos` non-Pi arm gains the nested-admission clause `\| Term.App (_, _, _) -> true` (8a9bc8bbdbd65c6f0508011a7734a355) | Kernel (103 PASS): `FAIL C4: Json-shaped self-recursive ctors pass positivity; List T -> T nesting is Bad_ctor` and `FAIL A5: the Fording route stays blocked (result head, then positivity)`, `2 test(s) failed`.  Surface 107 (see section 5).  Legs: FENCE-COVARIANT red, exit 1 after four lines (data U, ctor mku, data T2, ctor mkt2: nested-pos.tot accepted);  FENCE-CONTRAVARIANT red after four lines (data N, ctor mkn, data T3, ctor mkt3);  DEFAULT-IDENTITY red `(exit=0/1)` (nested blocks flip, m5e-acc still exit 1);  the six WF legs green | md5 c394d0d34f013e767f9ff7ff04dc2cd6 restored;  rebuild OK;  kernel 105;  9 legs green |
| MA-6 | MA-2 plus `let binder_status = if scrut_special then Smaller else Smaller in` (bc22f7e7231ca6d5e63314e8131407ee) | Kernel: same E2 line, accRec half (104 PASS).  Legs: `FAIL-M5E-WITNESS-REJECTED (exit=0)` after three lines (data T, ctor mk, def bad);  DEFAULT-IDENTITY red (bad2, crossformal-t, deep2 and the m5e blocks flip);  ACC-GUARD, INFINITARY, CROSSFORMAL, DEEP2 red (each exit 0 with its declaration echo);  WF-FLAG and both FENCE legs green | md5 6a3758fe... restored;  rebuild OK;  kernel 105;  9 legs green |

Every mutation compiled (0 errors, 0 warnings) and flipped its
predicted leg(s);  none needed the section 6.2 replacement.  At exit
`md5 -q bin/tot.ml lib/totality.ml lib/check.ml` =
889fa8f6efa21c83a1c341d392cefa67, 6a3758fedc2aed928943afe05b7b6bfa,
c394d0d34f013e767f9ff7ff04dc2cd6 (the pristine post-edit values);  no
mutation is left in the tree.

### 7. A14 exit criteria, walked

1. Final battery /Users/oobi/Documents/tot-m6-stageA-gate.log (runner
   /Users/oobi/Documents/tot-m6-stageA-gate.sh):  last line
   `GATE-EXIT=0`;  `rg -c FAIL` = 0;  406 lines.
2. `rg -c '^PASS'` = 339 = 105 (kernel, `rg -c '^PASS[^-]'` split by
   suite) + 107 (surface) + 127 (`rg -c '^PASS-'`).  Arithmetic from
   334:  -1 (PASS-M5E-ACC-CHECKS) -1 (kernel E1;  E2 converted, count
   neutral) +7 (PASS-M6A-*) = 339.
3. Seven markers present (section 4);  PASS-M5E-ACC-CHECKS absent
   from the final log (exit 1 on `rg -c`).
4. No other pre-existing marker lost:  `diff` of the `rg '^PASS'`
   extracts of the baseline and final logs is exactly `105,106c105`
   (`< PASS E1: Structural_wf accepts the accRec call shape`, `< PASS
   E2: Structural_wf still rejects the panel witness`, `> PASS E2: the
   shipped rule rejects accRec and the panel witness`), `331d329` (`<
   PASS-M5E-ACC-CHECKS`), `332a331,337` (the seven `> PASS-M6A-*`
   lines).  The whole-output diff has 14 changed lines;  filtering out
   the PASS lines leaves only `> GATE-EXIT=0` (the runner's own trailer,
   absent from the main loop's baseline log).
5. Deletion sweeps:  `rg -c 'experimental' bin/tot.ml` exit 1;
   `rg -c 'wf_rule' surface test bin` exit 1;  `rg -c 'experimental_wf'
   bin lib surface test` exit 1;  the `Structural_wf` and
   test/surface.ml `experimental` sweeps per C-A3 and C-A4 (code forms
   exit 1;  the only hits are the three plan-pinned comment lines and
   the byte-pinned fixture comment).
6. Corpus 85:  `ls examples/*.tot | wc -l` = 6, `ls test/fixtures/*.tot
   | wc -l` = 79;  transcript 9685 lines / 85 blocks.
7. TIERS 126, `rg -c '"\$watchdog" [0-9]+' dev/gates.sh` exit 1.
8. `Cache.format_version` = 10;  m5e fixtures md5 unchanged (section 1
   values re-read at exit).
9. `git status --porcelain` (section 8) shows only the expected
   modified and untracked files, nothing staged;  `git log -1
   --oneline` still `18b7ab6 ...`.

### 8. Porcelain and gate tails

```
 M SPEC.md
 M bin/tot.ml
 M dev/gates.sh
 M dev/m5e-default-transcript.txt
 M lib/check.ml
 M lib/totality.ml
 M surface/run.ml
 M test/main.ml
 M test/surface.ml
?? dev/M6-BUILD-LOG.md
?? test/fixtures/bad2.tot
?? test/fixtures/crossformal-t.tot
?? test/fixtures/deep2.tot
?? test/fixtures/nested-neg.tot
?? test/fixtures/nested-pos.tot
```

Final gate log tail (/Users/oobi/Documents/tot-m6-stageA-gate.log):

```
PASS-M5B-BRANCHING-20
GATE-LOG=/tmp/claude-501/tot-gate-measure.log
GATE-EXIT=0
```

Entry gate log tail (/Users/oobi/Documents/tot-m6-stageA-entry-gate.log):
same three lines, 334 PASS.  Pre-mutation battery on the edited tree
before any mutation (/Users/oobi/Documents/tot-m6-stageA-pre-mutation-gate.log):
339 PASS, 0 FAIL, `GATE-EXIT=0`.

### 9. Second run (2026-09-03, 05:17 to 05:36): re-verification

Context: conflict note C-A5.  The second run edited no repo file except
this log (C-A5 in section 5 and this section).  Its runner scripts sit
beside the first run's: /Users/oobi/Documents/tot-m6-stageA-gate.sh
(battery runner, `GATE-EXIT=` trailer), tot-m6-stageA-verify.sh,
tot-m6-stageA-final-measure.sh, tot-m6-stageA-round3.sh;  their
extracts live under /Users/oobi/Documents/tot-m6-stageA-verify/.

Verified on disk (command, observation):

- Entry battery predates the first edit.  `stat -f '%Sm %N' -t
  '%H:%M:%S'`: tot-m6-stageA-entry-gate.log 04:49:42;  surface/run.ml
  04:51:39 (earliest edit), test/main.ml 04:52:05, test/surface.ml
  04:52:12, the five fixtures 04:52:16, dev/m5e-default-transcript.txt
  04:58:02, dev/gates.sh 04:59:13, bin/tot.ml 05:04:39 (MA-1 restore),
  SPEC.md 05:05:49, lib/check.ml 05:10:05 and lib/totality.ml 05:10:25
  (last restores), this log 05:15:54.
- Entry log: `rg -c '^PASS'` = 334, `rg -c '^FAIL'` exit 1, last line
  `GATE-EXIT=0`;  `diff` of its `rg '^PASS'` extract against the main
  loop's baseline log (/Users/oobi/Documents/tot-m6-baseline-gate.log)
  is empty (exit 0).
- A0 probes (/Users/oobi/Documents/tot-m6-probes/stage-a-build/
  a0-probes.log, 04:48, HEAD binary): P1..P15 match plan lines 708-722
  row by row (P2 exit 0 with the five `data Acc` .. `def accZero`
  lines;  P6 exit 0 with the three lines;  P4 stderr byte-identical
  to P3;  P8 and P10 exit 1;  P13 exit 2, `unknown flag:
  --experimental-wfz`, 0 stdout bytes;  P14 gen exit 0, diff exit 0,
  9660;  P15 6 and 74).  No divergence.
- Mutation log (/Users/oobi/Documents/tot-m6-stageA-mutations.log):
  every `md5 before` equals its `md5 after restore` (MA-1 889fa8f6...,
  MA-2/3/4/6 6a3758fe..., MA-5 c394d0d3...), and the current files
  carry those digests (`md5 -q bin/tot.ml lib/totality.ml
  lib/check.ml`, taken after the second run's battery and again after
  round 3).  The first round's leg runner printed four lines per leg,
  so for MA-3, MA-4 and MA-5 the accepted fixture's stdout filled the
  head and the `FAIL-M6A-*` marker line was cut;  the flips were on
  record as `leg l5 (CROSSFORMAL-REJECTED) exit=1` (MA-3), `leg l6
  (DEEP2-REJECTED) exit=1` (MA-4), `leg l7 (FENCE-COVARIANT) exit=1`
  and `leg l8 (FENCE-CONTRAVARIANT) exit=1` (MA-5), each `exit=0` with
  its `PASS-M6A-*` line after the restore.  Round 3 (05:33:25 to
  05:34, driver copy mut-r3.sh with leg runner copy legx-a-r3.sh,
  12-line heads, log lines 1328-1678) re-ran those three and put the
  lines on record: MA-3 `FAIL-M6A-CROSSFORMAL-REJECTED (exit=0)`, leg
  exit 1, DEEP2 and WITNESS exit 0, kernel 104 with `FAIL E2 ...`;
  MA-4 `FAIL-M6A-DEEP2-REJECTED (exit=0)`, leg exit 1, CROSSFORMAL and
  WITNESS exit 0, kernel 104;  MA-5 kernel 103 (`FAIL C4 ...`, `FAIL
  A5 ...`), surface 107, `FAIL-M6A-FENCE-COVARIANT (exit=0)`,
  `FAIL-M6A-FENCE-CONTRAVARIANT (exit=0)`, DEFAULT-IDENTITY exit 1;
  each restored md5-identical, `REBUILD-EXIT=0`, kernel 105, all nine
  legs exit 0.  Mutation runs on record: 6 (round 1) + 5 (round 2) +
  3 (round 3) = 14 over the six pinned mutations.
- Sweeps re-run (section 5, C-A3 and C-A4): `rg -n 'Structural_wf' bin
  lib surface test` prints exactly lib/totality.ml:13,
  test/fixtures/m5e-witness.tot:10, test/main.ml:2825 (comments);
  `rg -n 'experimental' test/surface.ml bin/tot.ml` prints exactly
  test/surface.ml:410-411 (the pinned comment);  the three code-form
  sweeps exit 1;  `rg -c 'wf_rule' surface test` exit 1.
- Transcript: the first run's transcript-new.txt is byte-identical to
  dev/m5e-default-transcript.txt (diff exit 0);  its diff against
  transcript-old.txt has 0 `<` lines (rg exit 1) and 25 `>` lines at
  `84a85,89`, `107a113,122`, `9576a9592,9601`;  `wc -l` 9685, `rg -c
  '^### '` 85;  corpus `ls examples/*.tot test/fixtures/*.tot | wc -l`
  = 85 (6 + 79).
- Counts: `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh`
  = 126;  `rg -c '"\$watchdog" [0-9]+' dev/gates.sh` exit 1;  `rg -c
  'echo PASS-' dev/gates.sh` = 126;  `rg -o 'PASS-M6[A-E]-[A-Z0-9-]+'
  dev/gates.sh | sort -u` lists the seven markers, `rg -c
  'PASS-M6[B-E]'` exit 1;  `rg -c 'PASS-M5E-ACC-CHECKS' dev/gates.sh`
  = 1 (the replacement comment);  `rg -c '~rule:Totality\.Structural\b'
  test/main.ml` = 30, `rg -c '~rule' test/main.ml` = 31;  `let
  format_version : int = 10`;  no `set -u` in dev/gates.sh (exit 1);
  the M6A block (dev/gates.sh 2441-2545) has no `for`/`while` line
  (the three hits of `\b(for|while)\b` are prose inside comments).

Final battery of the second run (the one the exit criteria cite): the
first run's final log was preserved as
/Users/oobi/Documents/tot-m6-stageA-gate.run1.log, then `timeout 580
zsh /Users/oobi/Documents/tot-m6-stageA-gate.sh
/Users/oobi/Documents/tot-m6-stageA-gate.log` ran 05:29:47 to 05:30:43
on the unchanged tree: last line `GATE-EXIT=0`;  `rg -c '^PASS'` = 339
= 212 suite lines (`rg -c '^PASS[^-]'`: 105 kernel + 107 surface) + 127
markers (`rg -c '^PASS-'`);  `rg -c '^FAIL'` exit 1;  `rg -c
'PASS-M5E-ACC-CHECKS'` exit 1;  `rg -c '^PASS-M6A-'` = 7;
PASS-M5D-TIERS, PASS-M5D-MEASURE-LOG, PASS-M5E-DEFAULT-IDENTITY and
PASS-M5E-WITNESS-REJECTED present (lines 388, 393, 394, 395).  `diff` of
the `rg '^PASS'` extracts: against the first run's final log, empty
(exit 0);  against the baseline log, exactly `105,106c105`, `331d329`,
`332a331,337` as in section 7 item 4;  the whole-output diff minus PASS
lines is only `> GATE-EXIT=0`.  Measure log tail: `MEASURE
M5B-BRANCHING-20 tier=10 elapsed=0.019 exit=0`;  no timed leg was
flaky, so no isolated re-run was needed.

Second-run observations (not conflicts):

- The disk-floor interlock hook (29.4 GiB free, 30 GiB floor) held the
  verify script and the battery;  both ran with the hook's own
  `[skip-disk]` tag, since this stage writes only a 21 KB log and an
  incremental `_build`.
- `diff <(...) <(...)` fails under the build sandbox (`/dev/fd:
  Operation not permitted`);  the extracts were diffed through files
  under /Users/oobi/Documents/tot-m6-stageA-verify/.
- A read-only HEAD export runner was written for a second entry
  measurement and deleted unused: the first run's entry log predates
  the first edit, and the main loop's baseline log is a third
  measurement of the same 334.

Porcelain at exit (`git status --porcelain`): unchanged from section 8
(nine ` M`, six `??`);  `git log -1 --oneline`: `18b7ab6 dev/M6-PLAN.md:
staged plan for M6 (holes, blocking Unit posture, WF deletion)`;
nothing staged (`git diff --cached --stat` empty).

## Stage B (2026-09-03): the blocking Unit strict-json posture (pins 5-6, ruling R3)

Plan: `dev/M6-PLAN.md` B0-B12 (lines 1502-2361).  Chain: 339 -> 345
(+2 surface tests, +4 markers).  Driver and serror change only;  the
`--strict-json` refusal on an `IO Unit` script now exits 2 (was 1),
outside the `--serror-exit` mapping, so both driver shapes answer a
malformed payload with the blocking code 2.

### 1.  Entry state

- `git log -1 --oneline`: `18b7ab6 dev/M6-PLAN.md: staged plan for M6
  (holes, blocking Unit posture, WF deletion)`;  nothing staged.
- `git status --porcelain`: nine ` M` (SPEC.md, bin/tot.ml,
  dev/gates.sh, dev/m5e-default-transcript.txt, lib/check.ml,
  lib/totality.ml, surface/run.ml, test/main.ml, test/surface.ml) and
  six `??` (dev/M6-BUILD-LOG.md, test/fixtures/{bad2,crossformal-t,
  deep2,nested-neg,nested-pos}.tot), all Stage A's unstaged edits.
- Entry battery (`~/Documents/tot-m6-stageB-entry-gate.log`, 08:02):
  `GATE-EXIT=0`;  `rg -c '^PASS' <log>` = 339 (`^PASS-` 127, `^PASS[^-]`
  212);  `rg -c '^FAIL' <log>` exits 1.  `rg '^PASS'` extract diffs
  empty against `~/Documents/tot-m6-stageA-verify.log`.
- Entry md5s: bin/tot.ml 889fa8f6efa21c83a1c341d392cefa67,
  surface/serror.ml 93df16a30dfda9016ca5773c9777958c, surface/run.ml
  9770d6e136818b1754f96a9450c7dd73 (Stage A's value, as the plan
  predicts), surface/effect.ml b50915fdb47b92d2f117fc83ca0ff6e3,
  test/surface.ml 892a0333d59118f6c36cc6e224b24476, dev/gates.sh
  8e0fd37126bec9bfb95fc9c294878f08, SPEC.md
  cf528fac62876ac1236ac1602dcc08e2, tot.exe
  9c0a0cc07d5225e7d79241852d235914.
- B0 probes P1-P16 reproduced BEFORE the first edit
  (`~/Documents/tot-m6-probes/stage-b-build/b0-probes-entry.log`,
  runner `run-b0-probes.sh`, fixture `unit-echo.tot` beside it):
  P1/P2/P3/P11 exit 1, stdout empty, stderr
  `<path>:stdin is not a single well-formed JSON value, and this
  installation runs with --strict-json`;  P4 exit 0 (`not json` then
  `def main : (IO Unit)`);  P5 exit 0;  P6/P7 exit 2 with the deny
  envelope, stderr empty;  P8 exit 0 empty;  P9 exit 0;  P10 rc 0 and
  the capture matches;  P12 seven `Json_strict_reject` lines in
  serror.ml (44,72,86,90,96,108,120);  P13 serror.ml:7 run.ml:2;  P14
  13 `PASS-M6` hits (all Stage A's `PASS-M6A`), `rg -c 'PASS-M6B'`
  exits 1;  P15 exits 1;  P16 the four md5s above.  Every probe agrees
  with plan B0 except the line-number drift noted in section 5.

### 2.  What changed

Files touched (six in the repo plus this log):

- `bin/tot.ml` (md5 50500a2378298eb9aa4df540459f7602): the ONE
  executable delta of the stage, plan B2, at line 109-111: the
  `driver_exit` arm of the `run_file` error fold returns the literal
  `2` (was `1`).  The fold comment (lines 82-88) now names M6 Stage B,
  ruling R3, and the exit-1-through-M5 history.  `default_opts`
  (`strict_json = false`), `serror_exit = 1`, the usage string, the
  unknown-flag, missing-main (exit 1) and budget (exit 3) arms are
  byte-unchanged.
- `surface/serror.ml` (md5 960927c568ef81f5676920f77411a47b): comments
  only, plan B3.  The `Json_strict_reject` constructor doc (44-51) and
  the `driver_exit` doc (91-96) say exit 2, M6 Stage B, ruling R3,
  exit 1 through M5.  `to_string`, `tag`, `driver_exit`,
  `is_check_budget`, `is_missing_main` arms byte-unchanged.
  `Json_strict_reject` now appears on lines 44,75,89,94,101,113,125
  (still seven;  `rg -c Json_strict_reject surface/serror.ml` = 7).
- `surface/run.ml` (md5 322ce25dfa22be55a7fb83de7fa226cc): comments
  only, plan B3 out-of-file sites: the policy doc (line 37) and the
  `run_unit_main` Rejected-arm comment (550-553).  Both Rejected arms
  byte-unchanged (`Ok ([ Effect.deny_envelope reason ], 2)` line 533;
  `Error Serror.Json_strict_reject` line 554).
- `surface/effect.ml`: ZERO bytes changed (md5
  b50915fdb47b92d2f117fc83ca0ff6e3 at entry and exit).
- `test/surface.ml` (md5 ad0a53fc83a9ab0f8cfae339cddf82b9): plan B7,
  section 3 below.
- `dev/gates.sh` (md5 c06a1b24ed262ff7046ae819ec1d5041, 2603 -> 2715
  lines): plan B8 block inserted VERBATIM at lines 2545-2652 (legs at
  2558, 2577, 2608, 2628;  `rm -f "$m6b_err_f"` at 2651), after the
  PASS-M6A-FENCE-CONTRAVARIANT leg and before `# ctxcat id 5:`;
  PASS-M5D-TIERS literal 126 -> 134 (line 2268) with its comment
  (2256).  PASS-M5D-MEASURE-LOG literal untouched (no `gate_timed` leg
  added).
- `SPEC.md` (md5 ef643e9d3b716e4c12b5ffff7b13274d): plan B10: (1) the
  verbatim `- 2026-09-03 (M6, Stage B): the blocking Unit strict-json
  posture` decision-log entry with its MIGRATION NOTE at line 1173,
  appended after the Stage A transcript-reseal entry, before `## 3.`;
  (2) the section 3 fail-closed paragraph gained the "Since M6 Stage B
  the fail-closed spelling covers both driver shapes" sentence
  (1280-1283);  (3) the section 5 bullet "A blocking `--strict-json`
  posture for `IO Unit` scripts" deleted (`rg -n 'IO Unit. scripts'
  SPEC.md` finds nothing).  The M5 Stage A entry untouched.
- `Error.t` / `Serror.t` variants added or removed: none.
- `Cache.format_version` stays 10 (`rg -n 'format_version : int'
  surface/cache.ml` -> `118:let format_version : int = 10`).
- `dev/m5e-default-transcript.txt` untouched, md5
  a9b76c9be91b7e9e2223993ef420d392;  no examples/ or test/fixtures/
  file added, so no reseal (pin 14);  corpus stays 85 files
  (`ls examples test/fixtures | rg -c '\.tot$'` = 85).

Build: `dunecho build` 0 errors, 0 warnings after every edit and
every restore;  tot.exe at exit md5 2cbe7fb6b5f4a380c007fb6ca462ecd0.

### 3.  Tests added (surface suite 107 -> 109)

`test/surface.ml`: helper `m6b_unit_echo_src` (776) and
`m6b_with_unit_policy` (786, takes `bst` like `m5a_run_with_policy`,
see conflict C-B1), and two cases after M5A-15 (1746, 1752):

- `M6B-1: Run.script under strict_json=true turns a garbage stdin
  payload on an IO Unit script into Serror.Json_strict_reject (the
  surface half; the driver maps it to the literal exit 2, M6 Stage B)`
- `M6B-2: Serror.driver_exit stays true on Json_strict_reject and its
  rendered line is byte-identical (the two inputs of the driver's
  literal-2 arm)`

`dune exec test/surface.exe | rg -c '^PASS '` = 109;  kernel
`test/main.exe` = 105 (untouched).

### 4.  Gate markers added (127 -> 131)

PASS-M6B-UNIT-STRICT-EXIT2, PASS-M6B-UNIT-STRICT-NOMAP,
PASS-M6B-VERDICT-STRICT-IDENTITY, PASS-M6B-OPEN-IDENTITY (final log
lines 405-408).  Static checks on `dev/gates.sh`: `zsh -n` exit 0;
`rg -c 'echo PASS-'` = 130;  `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"'`
= 134 (was 126: eight MED calls added, none deleted);
`rg -c '"\$watchdog" [0-9]+'` exits 1;  `rg -c 'set -u'` = 1 (the
line-2 comment forbidding it, as at Stage A);  no for/while inside the
block (the only hit is the word "for" in prose at line 2634).

### 5.  Conflicts (section 5 protocol)

- Conflict note C-B1 (2026-09-03): plan B7 says the M6B-1 helper
  `m6b_with_unit_policy ~strict_json` calls `Run.script ~st:bst` with
  `bst` free at module level;  the repo at test/surface.ml:772 (entry)
  shows `bst` scoped as the parameter of `let cases (bst :
  Tot_surface.Run.state)`, so the verbatim helper does not compile;
  resolution: the helper takes `(bst : Tot_surface.Run.state)` as its
  first parameter exactly like `m5a_run_with_policy` (test/surface.ml:
  747 at entry) and the case calls `m6b_with_unit_policy bst
  ~strict_json:true`.  The pinned assertion (Json_strict_reject by
  `Serror.tag`, an Ok run rejected) is unchanged.
- Conflict note C-B2 (2026-09-03): plan B9 row M-B4 says the first red
  is UPSTREAM at `FAIL-M5A-STRICT-ALLOW`;  the repo's fail-fast battery
  under the mutation shows the first red EARLIER upstream at
  `317:FAIL-D-GUARD-OTHER (exit=0/2)` (the M3 guard leg sees the same
  route: an unflagged garbage guard run exits 2), and stops there, so
  the M5A leg is never reached;  resolution: the hand-replay the row
  requires was run and records the OPEN-IDENTITY leg red
  (`FAIL-M6B-OPEN-IDENTITY (exit=2/2)`, the Unit half at 2 with the
  stderr line and the guard half at 2 with the envelope), so the pin's
  evidence is on record;  no gate text changed.
- Conflict note C-B3 (2026-09-03): plan B9 row M-B5 says the first red
  is UPSTREAM at `FAIL-M5A-STRICT-DENY (exit=1/1)`;  the repo shows the
  first red EARLIER, in the replayed surface suite at `272:FAIL M5A-14:
  Run.script under strict_json=true turns a garbage stdin payload into
  the strict deny envelope and exit 2` (the suite runs before the M5A
  markers in the battery), and the fail-fast battery stops there;
  resolution: the required hand-replay records the
  VERDICT-STRICT-IDENTITY leg red (`FAIL-M6B-VERDICT-STRICT-IDENTITY
  (exit=1/1)`, envelope bytes intact), the exact flip the row pins.
- Non-conflict observations (content unchanged, line drift only): plan
  cites run.ml Verdict Rejected arm 538 -> now 533, Unit Rejected arm
  559 -> 554, its comment 554-558 -> 550-553;  serror.ml
  `Json_strict_reject` lines after the comment edits
  44/75/89/94/101/113/125 (plan: 44/72/86/90/96/108/120);  P14 shows
  13 `PASS-M6` hits from Stage A while the `PASS-M6B` namespace was
  free;  P16 run.ml/tot.ml hashes are Stage A's values as the plan
  predicts.  No hook denied any plan-pinned spelling.

### 6.  Mutation proofs (plan B9)

Driver `~/Documents/tot-m6-probes/stage-b-build/mut.sh <id>`;  full
transcript `~/Documents/tot-m6-stageB-mutations.log` (M-B1 lines
11-91, M-B2 92-174, M-B3 175-259, M-B4 260-337, M-B5 338-418);  each
run: `sd -s` from a pristine copy, md5 before/mutated, `git diff` of
the mutated lines, `dunecho build`, the FULL battery to
`mut-<id>-gate.log`, surface suite, the four M6B legs replayed one per
subshell (`legx-b.sh`), `cp` restore, md5 after, rebuild, legs green.
Baseline replay before M-B1: all four legs exit 0.

| id | mutation | build | first red (battery) | M6B leg replay | restore |
|---|---|---|---|---|---|
| M-B1 | bin/tot.ml arm `2` -> `1` (md5 31c1adad811c6631e5deee1f1c811300) | 0 | `407:FAIL-M6B-UNIT-STRICT-EXIT2 (exit=1)`, PASS 339 | EXIT2 red `(exit=1)`, NOMAP red `(exit=1/1/1)`, VERDICT/OPEN green | md5 50500a23... identical, rebuild 0, 4 legs green |
| M-B2 | arm `2` -> `serror_exit` (md5 7e9423f921761306f6d8dac18a482e7e) | 0 | `407:FAIL-M6B-UNIT-STRICT-EXIT2 (exit=1)`, PASS 339 | EXIT2 red `(exit=1)`, NOMAP red `(exit=0/1/7)` (the remap the leg refuses) | identical, 4 legs green |
| M-B3 | arm `prerr_endline` -> `print_endline` (md5 eed0a850b57f8880044dffed74b9ec75) | 0 | `407:FAIL-M6B-UNIT-STRICT-EXIT2 (exit=2)`, PASS 339 (line on stdout) | EXIT2 red `(exit=2)`, NOMAP red `(exit=2/2/2)` | identical, 4 legs green |
| M-B4 | `default_opts` `strict_json = false` -> `true` (md5 c0d4c27c61eb39ec675c2ee02d89dc62) | 0 | `317:FAIL-D-GUARD-OTHER (exit=0/2)`, PASS 249 (upstream, see C-B2) | OPEN-IDENTITY red `(exit=2/2)`, other three green | identical, 4 legs green |
| M-B5 | surface/run.ml Verdict deny `, 2)` -> `, 1)` (md5 3246411104559d13585a1a3a21a8d2ae) | 0 | `272:FAIL M5A-14: ...` , PASS 213, surface 108 (upstream, see C-B3) | VERDICT-STRICT-IDENTITY red `(exit=1/1)`, other three green | md5 322ce25d... identical, 4 legs green |

Every mutation compiled and flipped;  none needed replacement under
section 6.2.  After M-B5: `git diff` shows no residual mutation
(bin/tot.ml 50500a2378298eb9aa4df540459f7602, surface/run.ml
322ce25dfa22be55a7fb83de7fa226cc), tot.exe back to
2cbe7fb6b5f4a380c007fb6ca462ecd0.

### 7.  Exit criteria (plan B12) walked

1. Final battery `~/Documents/tot-m6-stageB-gate.log` (runner
   `~/Documents/tot-m6-stageB-gate.sh`): last line `GATE-EXIT=0`;
   `rg -c '^FAIL' <log>` exits 1.
2. `rg -c '^PASS' <log>` = 345 = 131 markers (`^PASS-`) + 214 suite
   (`^PASS[^-]`) = 105 kernel + 109 surface + 131;  chained 339 + 2 + 4.
3. All four reserved markers present (lines 405-408, section 4);
   `rg -c 'PASS-M6[A-E]-' dev/gates.sh` distinct names = 11 (7 A + 4 B).
4. No pre-existing marker or test lost: `diff
   ~/Documents/tot-m6-stageA-verify.log ~/Documents/tot-m6-stageB-gate.log`
   shows ONLY six added lines (`> PASS M6B-1`, `> PASS M6B-2`, and the
   four `> PASS-M6B-*`);  the `rg '^PASS'` extract diff shows the same
   six.
5. Post-edit B0 probes (`b0-probes-post-edit.log`): P1/P2/P3/P11 exit
   2, same stderr line, stdout empty;  P4-P10 byte-identical to entry;
   the probe-log diff shows only those exit lines, the drifted serror
   line numbers, the new test/surface.ml count, P14/P15 matching the
   new block and tests, and the three edited-file hashes.
6. surface/effect.ml zero bytes;  transcript md5
   a9b76c9be91b7e9e2223993ef420d392;  corpus 85;  format_version 10;
   em-dash sweep over the six touched files exits 1.
7. Every mutation in B9 run, flipped, restored md5-identical (section 6).
8. `git status --porcelain` unchanged from entry (nine ` M`, six `??`);
   `git log -1 --oneline` still `18b7ab6 ...`;  `git diff --cached --stat`
   empty;  dev/M6-PLAN.md not edited.

### 8.  Porcelain and gate tails

```
 M SPEC.md
 M bin/tot.ml
 M dev/gates.sh
 M dev/m5e-default-transcript.txt
 M lib/check.ml
 M lib/totality.ml
 M surface/run.ml
 M surface/serror.ml
 M test/main.ml
 M test/surface.ml
?? dev/M6-BUILD-LOG.md
?? test/fixtures/bad2.tot
?? test/fixtures/crossformal-t.tot
?? test/fixtures/deep2.tot
?? test/fixtures/nested-neg.tot
?? test/fixtures/nested-pos.tot
```

Final battery tail (`~/Documents/tot-m6-stageB-gate.log`):

```
PASS-M6B-UNIT-STRICT-EXIT2
PASS-M6B-UNIT-STRICT-NOMAP
PASS-M6B-VERDICT-STRICT-IDENTITY
PASS-M6B-OPEN-IDENTITY
PASS-M4FIX-INST-BRANCHING
PASS-M5B-BRANCHING-20
GATE-LOG=/tmp/claude-501/tot-gate-measure.log
GATE-EXIT=0
```

Handoff to Stage C: chain starts at 345 (105 + 109 + 131);  tiers
literal 134;  `echo PASS-` sites 130.

## Stage C (2026-09-03): expected-type-only holes and the `_` reservation (pins 1-4, ruling R2)

Plan: `dev/M6-PLAN.md` C0-C15 (lines 2362-3510).  Chain: 345 -> 360
(+10 surface tests, +5 markers).  Surface-only change: `_` becomes a
reserved token (hole in term position, anonymous binder in binder
position), `Elab.term_at` carries an expected kernel type down a
fixed descent set and fills leading erased `Type` slots by a rigid
first-order match against the head's codomain, fenced off the proof
and class families;  every fill is re-checked by the untouched kernel.

### 1.  Entry state

- `git log -1 --oneline`: `18b7ab6 dev/M6-PLAN.md: staged plan for M6
  (holes, blocking Unit posture, WF deletion)`;  nothing staged.
- `git status --porcelain`: eleven ` M` (SPEC.md, bin/tot.ml,
  dev/gates.sh, dev/m5e-default-transcript.txt, lib/check.ml,
  lib/totality.ml, surface/run.ml, surface/serror.ml, test/main.ml,
  test/surface.ml and Stage A's surface edits) and six `??`
  (dev/M6-BUILD-LOG.md, test/fixtures/{bad2,crossformal-t,deep2,
  nested-neg,nested-pos}.tot): Stage A + B's unstaged edits.
- C0 entry probes (`~/Documents/tot-m6-stageC-c0-probes.log`, 79
  lines): classifier `python3 dev/hole-anchors.py | wc -l` = 148, last
  line `ANCHORS total=98 expected-type-only=59 argument-driven=9
  neither=30`;  the three pin-2 probes exit 0 (`underscore-def.tot ::
  def _ : Nat|def g : Nat| exit=0`, `underscore-lam.tot :: def f :
  (w _ : Nat) -> Nat| exit=0`, `underscore-match.tot :: def h :
  (w _ : Nat) -> Nat| exit=0`);  `dup-underscore-pattern.tot ::
  1:68: parse error: duplicate binder _ in pattern| exit=1`;
  `w-underscore-pi.tot :: def k : (w _ : Nat) -> Nat| exit=0`;  corpus
  sweep `rg -n "(^|[^A-Za-z0-9_'])_($|[^A-Za-z0-9_'])" stdlib/prelude.tot
  examples/*.tot` = two comment-only hits (examples/guard-rewrap.tot:7-8);
  `rg -n '^(def|data|axiom|class)\s+_\s' ...` exit 1;  `rg -c 'PASS-M6C'
  dev/gates.sh` exit 1 (zero matches, note N1);  tiers literal
  `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` = 134,
  `rg -c 'echo PASS-' dev/gates.sh` = 130;  `examples/nat.tot` exits 1
  (`duplicate global Nat`, note N7).  All matched the plan's C0 table.
- Entry battery (`~/Documents/tot-m6-stageC-entry-gate.log`):
  `GATE-EXIT=0`;  `rg -c '^PASS' <log>` = 345;  `rg -c '^FAIL' <log>`
  exits 1;  `rg '^PASS'` extract identical to
  `~/Documents/tot-m6-stageB-verify.log`.

### 2.  What changed

- `surface/token.ml`: `Token.Underscore` (after `KInst`), `describe`
  arm `"'_'"`.
- `surface/lexer.ml`: keywords row `("_", Token.Underscore)`;  no
  other lexer change (identifiers such as `_foo` still lex as
  `Ident`).
- `surface/syntax.ml`: `SHole of Loc.t`;  `loc_of` arm.
- `surface/parser.ml`: `parse_atom` yields `SHole` for `Underscore`;
  `binder_name` (total, every `Token.kind` enumerated) maps
  `Underscore` to the binder name `"_"` in `fun`, `let`, `let*` and
  match patterns;  `quantity_prefix`'s lookahead accepts `Underscore`
  so `(w _ : A)` stays ONE binder (note N5);  `find_dup` exempts `"_"`
  (note N4);  `collect_idents`, `kind_starts_atom`, `describe_syntax`
  and `peel_data_codomain` gained the new arms;  name positions
  (`def _`, `data _`) fall through to the existing "expected NAME"
  errors.
- `surface/bootstrap.ml`, `surface/run.ml`: `SHole` arms in every
  syntax traversal (`peel_syntax_codomain`, `syntax_spine`,
  `instance_key`, the `IClass` param check, bootstrap's arm).  ACTIVATION:
  `IDef` bodies elaborate via `Elab.term_at elab_globals [] ~expected:ty_t`,
  `IInstance` bodies via `Elab.term_at st.globals [] ~expected:ty_t`;
  `ICheck` and `IEval` still call `Elab.term`.
- `surface/serror.ml`, ONE variant added: `Hole of { loc : Loc.t;
  expected : (string list * Tot_kernel.Term.t) option }`.  `to_string`:
  `<loc>: hole: expected <Pp.term names ty>` / `<loc>: hole: no
  expected type at this position`;  tag `"Hole"`;  on the false side of
  `driver_exit`'s special cases, `is_check_budget` and `is_missing_main`,
  so it rides `--serror-exit` exactly as `Unknown_name` does.
- `surface/elab.ml`: `term_at globals scope ~expected` (descent set:
  `SHole` -> `Hole (Some (scope, expected))`;  `SLam` under `Term.Pi`;
  `SLet` body shifted by 1;  `SAnn`;  `SLetStar` as a `bind` spine;
  motive-free `SMatch` branch bodies shifted by their binder count via
  `Term.shift`;  `SApp` with a global head -> `spine`;  everything else
  `term`);  `spine` (uncurry, `k = min(leading (0 X : Type L) formals,
  m)`, `fenced` = the head's declared type mentions `Eq`/`Dec`/`Empty`
  or a structural class former, `rigid` captures at depth 0, then a
  left-to-right fold settles each slot: a leading hole fills from its
  capture or reports `Hole (Some (scope, dom))`, later slots descend
  through `inst_domain` when unfenced);  helpers `proof_families`,
  `is_class_former`, `exists_global`, `fenced`, `is_univ`,
  `leading_type_binders`, `peel_domains`, `zip` (total), `same_term`,
  `lit_equal`, `rigid`, `inst_domain`, `uncurry`.  `term`'s `SHole`
  arm reports `Hole { expected = None }`;  `term`'s `SAnn` arm now
  elaborates the annotation first and the subject through `term_at`
  (conflict C-C1 below).
- `test/fixtures/`: eleven new files (m6c-hole-e, m6c-hole-e-explicit,
  m6c-hole-a, m6c-hole-n-infer, m6c-hole-n-proof, m6c-hole-n-class,
  m6c-hole-run, m6c-underscore-binders, m6c-underscore-def,
  m6c-underscore-lam, m6c-underscore-match).
- `dev/gates.sh`: the Gate C block (plan lines 3146-3286, 141 lines
  verbatim) before `# ctxcat id 5:`;  `m6c_scratch` in the trap;
  `PASS-M5D-TIERS` literal 134 -> 151 with a dated sentence.
- `dev/m5e-default-transcript.txt`: resealed (section 7, criterion 4).
- `SPEC.md`: four dated section-2 entries, the section-6 "No holes,
  again" residual rewritten, the section-6 "errors are strings" debt
  line rewritten as partially paid.
- Untouched: every `lib/` file, `Cache.format_version` (10),
  `test/main.ml`, `dev/M6-PLAN.md`, `dev/hole-anchors.py`,
  `dev/m5d-measure.log`.

Fixture outputs (built binary, `tot check` unless noted;  all pinned
by Gate C and the suite):

```
m6c-hole-e.tot == m6c-hole-e-explicit.tot (byte-identical, exit 0):
def flagged : (List String)
def idList : (0 A : Type 0) -> (w _ : (List A)) -> (List A)
def main : (IO Verdict)
(((cons String) "x") (nil String)) : (List String)
fun xs => ((idList Nat) xs) : (w _ : (List Nat)) -> (List Nat)
m6c-hole-a.tot:2:8: hole: expected Type 0                       exit 1
m6c-hole-n-infer.tot:1:6: hole: no expected type at this position exit 1
m6c-hole-n-proof.tot:1:38: hole: expected Type 0                exit 1
m6c-hole-n-class.tot:1:51: hole: expected Type 0                exit 1
m6c-hole-run.tot:1:28: hole: expected Type 0   (run: exit 1; --serror-exit 0: exit 0; no stdout, no SIDE-EFFECT)
m6c-underscore-def.tot:1:5: parse error: expected 'NAME : TYPE := TERM' after 'def', found '_'  exit 1
m6c-underscore-lam.tot:1:32: hole: expected Nat                 exit 1
m6c-underscore-match.tot:1:72: hole: expected Nat               exit 1
m6c-underscore-binders.tot (exit 0):
def k : (w _ : Nat) -> Nat
def two2 : (w _ : (List Nat)) -> Nat
def _foo : Nat
def useIt : Nat
```

### 3.  Tests added (surface suite 109 -> 119)

Ten cases appended to `Tot_surface_test`'s `cases` list after
`M5C-S1`, through `Run.script` (two local helpers over it, no new
helper kinds: `m6c_twins` compares the holed and explicit scripts'
check-mode lines and requires them non-empty;  `m6c_expect_err_line`
pins the EXACT rendered `Serror.to_string` line and its one-line
property): M6C-1 fill_root, M6C-2 fill_branch_local, M6C-3
fill_letstar, M6C-4 fill_nested_arg, M6C-5 refuse_a, M6C-6
refuse_infer (two asserts: `eval _` and `let x : _ := zero`),
M6C-7 refuse_proof_fence, M6C-8 refuse_class_fence, M6C-9
reserved_names (`def _`, `data _`), M6C-10 binder_positions (the four
fixture-3 lines plus `let* Unit Unit _ := printLine "x" in ...`).
`_build/default/test/surface.exe | rg -c '^PASS'` = 119;
`_build/default/test/main.exe | rg -c '^PASS'` = 105 (unchanged).

### 4.  Gate markers added (131 -> 136)

`PASS-M6C-HOLE-RESOLVES`, `PASS-M6C-HOLE-REPORTS`,
`PASS-M6C-HOLE-NEVER-RUNS`, `PASS-M6C-UNDERSCORE-RESERVED`,
`PASS-M6C-DEFAULT-IDENTITY`.  `rg -c '^PASS-' <final log>` = 136;
`rg -c 'echo PASS-' dev/gates.sh` = 135 (130 + 5;  the log's 136th
`^PASS-` line is the pre-existing printf-emitted marker, as at Stage
B: 130 sites, 131 lines).  Tiers: `rg -c '"\$watchdog"
"\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` = 151 (134 + 17: 14 FAST,
2 MED, 1 SLOW in the Gate C block).  Loop-free: the block has no
`for`/`while`;  `set -u` absent.

### 5.  Conflicts (section 5 protocol)

- C-C1 (plan C6 vs C8 fixture 1).  Plan C6 keeps `ICheck` on
  `Elab.term` (infer position), but C8's twin fixtures carry
  `check (cons _ "x" (nil _) : List String)` and pin the stamped
  output, and note N6 says the check items are the conservativity
  oracle.  Resolution: `run.ml`'s `ICheck`/`IEval` stay on
  `Elab.term`;  `Elab.term`'s `SAnn` arm elaborates the annotation
  first and routes the subject through `term_at ~expected:ty_t`.
  Effect: an annotation is a hole root everywhere (`eval (_ : T)`
  included), and for a malformed `(tm : ty)` the FIRST error may now
  come from `ty` rather than `tm`.  No shipped file changes output
  (transcript identity, section 7).
- C-C2 (rigid's non-leading telescope binders, found by MUT-C2).  The
  first `rigid` blocked the match on any Var naming a non-leading
  telescope binder (`refl`'s `x`), so with the fence deleted
  `refl _ zero` STILL refused and MUT-C2 did not flip (first run in
  `~/Documents/tot-m6-stageC-mutations.log`).  Note N2 states the
  fence is load-bearing precisely because rigid matching alone
  resolves `refl _ zero`, so the plan's rigid treats such binders as
  wildcards (the kernel re-checks the actual argument).  Fixed:
  `| () when p >= k && p < m -> Some caps`;  doc updated;  suite,
  Gate C legs and the transcript unchanged;  MUT-C2 re-run flips.
- C-C3 (MUT-C2's predicted route, partial).  With the fence deleted,
  `m6c-hole-n-proof.tot` resolves (exit 0, `def agree : (((Eq Nat)
  zero) zero)`) and Gate C (ii) fails on `codec` as predicted, but
  `m6c-hole-n-class.tot` STILL refuses: `member`'s codomain is
  `Bool`, which never mentions `A`, so no rigid match can fill it
  with or without the fence (it is an argument-driven shape that the
  classifier files under N by precedence).  The leg flips on `codec`
  alone;  `coded` is carried by the A-shape, not the fence.
- C-C4 (MUT-C3's predicted stderr).  The filled `Type 0` is refused
  by the kernel as `type mismatch: expected Type 0, found Type 1`
  at `<file>:1:1` (the slot `(0 A : Type 0)` cannot take `Type 0`),
  not as the plan's `IO String` vs `IO (Type 0)` mismatch.  The flip
  route is the same (Gate C (ii) line (a) and Gate C (iii) both lose
  their pinned line).
- C-C5 (SPEC pin-4 entry vs `PASS-M5D-MEASURE-LOG`).  The first
  spelling of the C12 item-3 entry quoted the ANCHORS line verbatim,
  which put a SECOND `expected-type-only=59` into SPEC.md;  the
  unedited MEASURE-LOG leg extracts that literal with `rg -o` and
  compares the whole extract to the measure log, so it printed two
  values and went red (`~/Documents/tot-m6-stageC-gate-run2-measurelog-red.log`,
  `FAIL-M5D-MEASURE-LOG ... specE=expected-type-only=59
  expected-type-only=59`).  Resolution: the entry spells the counts
  as words (E 59, A 9, N 30, with the classifier command) and says
  why the literal stays unique;  `rg -c 'expected-type-only=[0-9]+'
  SPEC.md` = 1 again;  the leg is NOT edited.
- Hook denials (mechanical): `List.combine` (raises) was replaced by
  a total `zip`;  raw `dune build` is hook-denied, `dunecho build --
  --root <abs>` used throughout.
- N1 honored: `rg -c 'PASS-M6C' dev/gates.sh` printed nothing and
  exited 1 at entry.

### 6.  Mutation proofs (plan C11)

Runner: `python3 ~/Documents/tot-m6-probes/stage-c-build/mutations.py`
(applies one edit, rebuilds, runs the direct observation and the
standalone Gate C leg runner `gate-c-legs.sh` = dev/gates.sh lines
2663-2797 verbatim under the battery preamble, restores, md5-checks,
rebuilds, re-runs the legs).  Full transcript:
`~/Documents/tot-m6-stageC-mutations.log`.

| id | mutation | observed (mutated) | leg | restore |
| --- | --- | --- | --- | --- |
| MUT-C1 | delete `("_", Token.Underscore)` from lexer.ml | `tot check m6c-underscore-def.tot` exit 0, `def _ : Nat` / `def g : Nat` (the HEAD picture) | `FAIL-M6C-HOLE-RESOLVES (exit=1/0)`, first red in file order | lexer.ml md5 6ef50a618f175546cb2b379c0d19418a before and after |
| MUT-C2 | `let fence = fenced globals g gty && false` (elab.ml) | `m6c-hole-n-proof.tot` exit 0 `def agree : (((Eq Nat) zero) zero)`;  `m6c-hole-n-class.tot` still exit 1 (C-C3) | `FAIL-M6C-HOLE-REPORTS (exit=1/1/0/1)` on `codec` | elab.ml md5 df6a259e11f452f73931a75b809186b5 before and after |
| MUT-C3 | unresolved leading hole fills `Term.Univ Level.zero` (elab.ml) | `m6c-hole-a.tot:1:1: type mismatch: expected Type 0, found Type 1` exit 1;  `run m6c-hole-run.tot` the same line (C-C4) | `FAIL-M6C-HOLE-REPORTS (exit=1/1/1/1)` on line (a);  (iii)'s line lost | elab.ml md5 df6a259e11f452f73931a75b809186b5 before and after |
| MUT-C4 | `Term.shift ~by:0` in branch-body descent (elab.ml) | `m6c-hole-e.tot:5:1: type mismatch: expected Type 0, found #3` exit 1;  explicit twin exit 0 | `FAIL-M6C-HOLE-RESOLVES (exit=1/0)` on `codeh` | elab.ml md5 99446124cc2e9e52aafa0f3b65faffb2 before and after (pre-C-C2 value) |
| MUT-C5 | `find_dup` counts `_` again (parser.ml) | `m6c-underscore-binders.tot:5:71: parse error: duplicate binder _ in pattern` exit 1 | `FAIL-M6C-UNDERSCORE-RESERVED (exit=1/1/1/1)` on `codeub` | parser.ml md5 1b85e97fbb8b01f1b7d6bc752ad16bdf before and after |
| MUT-C6 | drop `Underscore` from `quantity_prefix`'s lookahead (parser.ml) | `m6c-underscore-binders.tot:4:1: type mismatch: expected (w _ : Nat) -> Nat, found Nat` exit 1 (two binders parsed) | `FAIL-M6C-UNDERSCORE-RESERVED (exit=1/1/1/1)` on leg (d) | parser.ml md5 1b85e97fbb8b01f1b7d6bc752ad16bdf before and after |

After every restore: `OK build: 0 errors, 0 warnings` and
`GATE-C-LEGS-EXIT=0` (all five markers).  All mutations reverted;
exit md5s in section 8.

### 7.  Exit criteria (plan C15) walked

1. Full battery green: `~/Documents/tot-m6-stageC-gate.log` ends
   `GATE-EXIT=0`;  `rg -c '^PASS' <log>` = 360 (`^PASS-` 136,
   `^PASS ` 224 = 105 kernel + 119 surface);  `rg -c '^FAIL' <log>`
   exits 1.  Chain 334 -> 339 -> 345 -> 360, exact.
2. All five `PASS-M6C-*` present;  `rg -o '^PASS\S*' <log> | sort`
   diffed against the Stage B verify log's extract: additions only
   (the ten suite `PASS` lines and the five markers), nothing lost.
3. MUT-C1..C6 all flipped (section 6;  C2's and C3's routes deviate as
   C-C3/C-C4 record);  every mutated file restored md5-identical.
4. Transcript reseal: `diff old new` = 66 added lines, 0 removed
   (`rg -c '^<' <diff>` exits 1), eleven `> ### test/fixtures/m6c-*`
   sections, `rg -c '^### ' dev/m5e-default-transcript.txt` = 96
   (was 85);  recorded in the SPEC entry;  old copy at
   `~/Documents/tot-m6-stageC-transcript-old.txt`, diff at
   `~/Documents/tot-m6-stageC-transcript.diff`.
5. `PASS-M5E-DEFAULT-IDENTITY`, `PASS-M5D-HOLE-ANCHORS`,
   `PASS-M5D-MEASURE-LOG` and the two SUITE legs (`TEST-OK`, with
   `MEASURE SUITE-KERNEL ... exit=0` and `MEASURE SUITE-SURFACE ...
   exit=0`) green in the final log;  their gate text unedited (`git diff dev/gates.sh` touches only the Gate C block,
   the trap and the TIERS literal + sentence).  `PASS-M5D-TIERS` green
   at 151 (134 + 17).
6. Four SPEC entries in (`rg -n '2026-09-03 (M6, Stage C)' SPEC.md` =
   4), C0 probe lines quoted verbatim, counts with commands.
7. Handoffs: Stage D inherits the untouched `PASS-M5D-MEASURE-LOG`
   literal;  Stage E OWES the measured solve count
   (`PASS-M6E-ANCHORS`), the example re-spell (7 E sites in
   guard.tot, its 2 A sites kept explicit) and the second reseal.

### 8.  Porcelain and gate tails

Exit md5s (`md5 -q`): surface/token.ml 98277e19ae81f8f690456cfaf3d881a4,
surface/lexer.ml 6ef50a618f175546cb2b379c0d19418a, surface/syntax.ml
86d4a1a18c332c0d4bdefd04c340b7d2, surface/parser.ml
1b85e97fbb8b01f1b7d6bc752ad16bdf, surface/bootstrap.ml
0a9e452969f41c077c940526b75e08d3, surface/run.ml
8af79e38a4736a1c5c591357fe50788f, surface/serror.ml
7e3f80e4cf5e5955c3659b73226c1b4e, surface/elab.ml
df6a259e11f452f73931a75b809186b5, dev/gates.sh
86b7d036c0f3d9a50d58b7fe71c2e5b5, test/surface.ml
8b104392f63380db19d9e26cd7cab20c.

`git log -1 --oneline`: `18b7ab6 ...` (unchanged);  nothing staged.

Battery runs, in order: (1) `~/Documents/tot-m6-stageC-gate-pre-mutation.log`,
GATE-EXIT=0, 360 PASS, before the mutation proofs and before
conflict C-C2's rigid fix;  (2) `~/Documents/tot-m6-stageC-gate-run2-measurelog-red.log`,
GATE-EXIT=1 at `FAIL-M5D-MEASURE-LOG` (conflict C-C5, 339 PASS before
the stop);  (3) `~/Documents/tot-m6-stageC-gate.log`, the FINAL run
on the shipped tree, GATE-EXIT=0, 360 PASS.

`git status --porcelain` (33 lines, all unstaged):

```
 M SPEC.md
 M bin/tot.ml
 M dev/gates.sh
 M dev/m5e-default-transcript.txt
 M lib/check.ml
 M lib/totality.ml
 M surface/bootstrap.ml
 M surface/elab.ml
 M surface/lexer.ml
 M surface/parser.ml
 M surface/run.ml
 M surface/serror.ml
 M surface/syntax.ml
 M surface/token.ml
 M test/main.ml
 M test/surface.ml
?? dev/M6-BUILD-LOG.md
?? test/fixtures/bad2.tot
?? test/fixtures/crossformal-t.tot
?? test/fixtures/deep2.tot
?? test/fixtures/m6c-hole-a.tot
?? test/fixtures/m6c-hole-e-explicit.tot
?? test/fixtures/m6c-hole-e.tot
?? test/fixtures/m6c-hole-n-class.tot
?? test/fixtures/m6c-hole-n-infer.tot
?? test/fixtures/m6c-hole-n-proof.tot
?? test/fixtures/m6c-hole-run.tot
?? test/fixtures/m6c-underscore-binders.tot
?? test/fixtures/m6c-underscore-def.tot
?? test/fixtures/m6c-underscore-lam.tot
?? test/fixtures/m6c-underscore-match.tot
?? test/fixtures/nested-neg.tot
?? test/fixtures/nested-pos.tot
```

Final battery tail (`~/Documents/tot-m6-stageC-gate.log`):

```
PASS-M6C-HOLE-REPORTS
PASS-M6C-HOLE-NEVER-RUNS
PASS-M6C-UNDERSCORE-RESERVED
PASS-M6C-DEFAULT-IDENTITY
PASS-M4FIX-INST-BRANCHING
PASS-M5B-BRANCHING-20
GATE-LOG=/tmp/claude-501/tot-gate-measure.log
GATE-EXIT=0
```

Handoff to Stage D: chain starts at 360 (105 + 119 + 136);  tiers
literal 151;  `echo PASS-` sites 135;  transcript corpus 96;
`PASS-M5D-MEASURE-LOG` literal untouched;  `expected-type-only=NN`
must stay spelled ONCE in SPEC.md (C-C5).

## Stage D (2026-09-03): the two cost legs (pins 11-13, ruling R4)

Builder: subagent on the Stage D workflow.  HEAD `18b7ab6` (plan
commit;  code byte-identical to M5 `8d5a839`), Stages A, B, C present
UNSTAGED in the working tree.  Chain 360 -> 365 (+5 markers, no new
suite tests, no binary change).  Every edit stays unstaged;  nothing
was run through the index.  Evidence outside the repo:
`~/Documents/tot-m6-stageD-entry-gate.log`,
`~/Documents/tot-m6-stageD-gate-pre-mutation.log`,
`~/Documents/tot-m6-stageD-gate.log` (the final battery),
`~/Documents/tot-m6-stageD-measure.log` (its MEASURE rows),
`~/Documents/tot-m6-stageD-mutations.log` (every mutation run, 329
lines), `~/Documents/tot-m6-stageD-mut-M{1,4,4b}-{RED,GREEN}.log`
(full batteries under mutation), `~/Documents/tot-m6-stageD-transcript-old.txt`
plus `~/Documents/tot-m6-stageD-transcript.diff` (reseal), and the
probe/helper directory `~/Documents/tot-m6-probes/stage-d-build/`
(`run-d0-probes.zsh` + `d0-probes.log`, `splice-gates.py`,
`gate-d-legs.sh`, `mutations.py`, `ratio-samples.py`, `hit-probe.py`,
`flake20.py` + `flake20.log`).

### 1.  Entry state

Entry battery (before the first edit):
`timeout 580 zsh ~/Documents/tot-m6-stageD-gate.sh ~/Documents/tot-m6-stageD-entry-gate.log`:
`rg -c '^PASS'` = 360 (`rg -c '^PASS[^-]'` = 224 = 105 kernel + 119
surface;  `rg -c '^PASS-'` = 136 markers), `rg -c '^FAIL'` exits 1,
last line `GATE-EXIT=0`;  the `^PASS` extract diffed empty against
`~/Documents/tot-m6-stageC-verify.log`;  `rg -c '^MEASURE '` on the
measure log = 20.  D0 probes P1..P18 reproduced at HEAD
(`d0-probes.log`): `rg -c 'PASS-M6D' dev/gates.sh` no output exit 1;
corpus `zsh -c 'print -l examples/*.tot test/fixtures/*.tot | rg -c "\.tot$"'`
= 96;  probe hit-one exact two lines exit 0;  hit-many 65 `def`
lines;  zsh float `1 0`;  cold private dir exit 0 with one
`exeid-*.txt` + one `prelude-8fea7b39...bin`, warm rerun identical
stdout, 0 stderr bytes both;  big600 budget 1 exit 3
`m6d-bigcheck.tot: check budget exhausted (1 ms)` with empty stdout,
budget 5/10/20 exit 0, cold budget 5 exit 0;  tiers recipe
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` = 151;
`rg -c 'gate_timed "\$' dev/gates.sh` = 18;  trap at line 434;
transcript 9751 lines / 96 `### ` blocks;  `-eq 151` at gates.sh:2271,
`-eq 18` at 2407;  `rg -c '"\$watchdog" [0-9]+' dev/gates.sh` exit 1;
`rg -c 'expected-type-only=[0-9]+' SPEC.md` = 1.  Entry md5s:
dev/gates.sh 86b7d036c0f3d9a50d58b7fe71c2e5b5, lib/check.ml
c394d0d34f013e767f9ff7ff04dc2cd6, bin/tot.ml
50500a2378298eb9aa4df540459f7602, surface/cache.ml
b185d98432e9d2a02b7cbc7ff25aead3, SPEC.md
5c21253070e5d0dd3d922a58af70f163, transcript
4a482f6573c0146bf447d10187402504, tot.exe
b69a429508f3072b156045799479cf57.  Machine note: the box carried a
load average of 20 to 36 for the whole stage (sibling sessions
building);  every timed number below is under that load.

### 2.  What changed

1. Fixtures (D1), all three new, headers verbatim from the plan:
   `test/fixtures/m6d-hit-one.tot` (5 lines: 3 header + `flagged` +
   `u1`), `test/fixtures/m6d-hit-many.tot` (71 lines: 6 header +
   `flagged` + u1..u64), `test/fixtures/m6d-bigcheck.tot` (607 lines:
   7 header + b1..b600).  Probed as pinned (section 1).
2. `dev/gates.sh` 2860 -> 3038 lines.  Trap line 434 gained
   `"$m6d_scratch"` (the plan's trap text lacks `"$m6c_scratch"`
   because Stage C added it;  both kept).  The M6D block (D2 header,
   scratch + `m6d_time` helper, legs D3..D7) is spliced from the
   plan's pinned text byte-for-byte (`splice-gates.py` strips the
   plan's 4-space indent, no retyping) at lines 2770-2936, right
   after the Gate C block and before `# ctxcat id 5:` (line 2977),
   the same slot Stages A-C used, so the branching pair stays the
   tail.  The PASS-M5D-MEASURE-LOG block (was 2382-2412) moved to
   2938-2975 with `-eq 22` twice, the 22-name literal (D8) and the
   dated pin-13 paragraph.  PASS-M5D-TIERS: `-eq 151` -> `-eq 157`
   at 2274 plus the D9 sentence after the Stage C sentence.
   `zsh -n dev/gates.sh` exit 0;  no `for`/`while` in the new region
   (`awk 'NR>=2770 && NR<=2975' dev/gates.sh | rg -c '^\s*(for|while) '`
   exits 1);  no `set -u`;  `rg -c '"\$watchdog" [0-9]+'` still
   exit 1;  `rg -c 'echo PASS-' dev/gates.sh` 135 -> 140;
   `rg -c 'gate_timed "\$'` 18 -> 20;  tiers recipe 151 -> 157
   (measured before and after: exactly +6 = 2 SLOW + 1 FAST + 3 MED).
3. Transcript reseal (D10): `zsh dev/gen-m5e-transcript.sh > dev/m5e-default-transcript.txt`
   from the repo root;  9751 -> 10430 lines, `rg -c '^### '` 96 -> 99;
   `diff old new` is ONE hunk `9657a9658,10336`, 679 `>` lines, zero
   `<` lines (additions only): `### test/fixtures/m6d-bigcheck.tot`,
   `### test/fixtures/m6d-hit-many.tot`, `### test/fixtures/m6d-hit-one.tot`,
   each `#exit 0`.  Corpus command = 99.  New transcript md5
   46906fc571c9aca9c8760bf29f2059ce.
4. SPEC.md (D11) 2014 -> 2091 lines: three `- 2026-09-03 (M6, Stage D)`
   section-2 entries before `## 3.` (ratio leg with the judge, plan
   writer and this build's measured pairs and the C-D1 outcome;
   cold-bootstrap window leg;  measurement-log coordination with the
   tiers before/after command);  section 6 pin-5 cost-half bullet
   now opens `Retired (M6 Stage D)`, keeping the 183x history with
   the BRANCHING-20 attribution (dev/M5-BUILD-LOG.md:517-522);  the
   M5 Stage C cold-bootstrap sentence gained one sentence naming the
   three cold markers, still no ceiling, no second budget.
   `rg -c 'expected-type-only=[0-9]+' SPEC.md` = 1 (C-C5 kept);  no
   em-dash, ASCII only.
5. No change to lib/, surface/, bin/ (md5s at exit equal entry:
   check.ml c394d0d3..., tot.ml 50500a23..., cache.ml b185d984...,
   tot.exe b69a4295...).  dev/M6-PLAN.md untouched.

### 3.  Tests

No suite test added (Stage D is gate-only).  Kernel 105, surface 119
unchanged, both green in every battery.

### 4.  Markers (136 -> 141)

`PASS-M6D-HIT-BASELINE`, `PASS-M6D-HIT-RATIO`, `PASS-M6D-COLD-WINDOW`,
`PASS-M6D-COLD-STORE`, `PASS-M6D-COLD-OUTSIDE-BUDGET`, in that order
at final log lines 423-427, then `PASS-M5D-MEASURE-LOG` (428, its new
position), `PASS-M4FIX-INST-BRANCHING` (429), `PASS-M5B-BRANCHING-20`
(430, last).  Measured numbers, final battery
(`~/Documents/tot-m6-stageD-measure.log`): `M6D-HIT-BASELINE tier=10
elapsed=0.033`, `M6D-HIT-ONE tier=120 elapsed=0.013`, `M6D-HIT-MANY
tier=120 elapsed=0.014` (ratio 1.08), `M6D-COLD-WINDOW tier=120
elapsed=0.029`;  pre-mutation battery 0.039 / 0.015 / 0.018 (1.20) /
0.041;  first dry run 0.049 / 0.024 / 0.021 / 0.055.  D7 flake
control (`flake20.py`, healthy binary, isolated): 20 of 20 runs of
(b) exit 0 with empty stderr, 600 defs, store=1, wall 0.023-0.030 s.
Bare-vs-wrapped cost on this loaded box: about 6 ms per watchdog
spawn (plan measured 4 ms), the D0-2 reason for bare timed runs.

### 5.  Conflicts (section 5 protocol)

Conflict note C-D1 (2026-09-03): pin 11 / plan D12 M1 says the memo
HIT path at lib/check.ml:766-773 cut to a miss re-derives 63 times
and flips `PASS-M6D-HIT-RATIO` (ratio near 8, BASELINE and both
suites green);  the repo shows (a) the instance memo is created
fresh and EMPTY per `Term.Auto` (lib/check.ml:653-655 `inst_start`,
1193-1196 "nothing carries across two [Term.Auto]s"), so the 64 uses
in m6d-hit-many.tot are 64 independent single-miss resolutions and
NEVER reach the HIT arm: the reach probe M1X (HIT arm replaced by
`Error (unresolved ())`) leaves m6d-hit-one exit 0 / 2 lines and
m6d-hit-many exit 0 / 65 lines while m5b-inst-branching-20 exits 1
`no instance found for (SC Bool)`;  (b) M1 as pinned does not flip:
legs run ratio 2.85 (0.037/0.013), three ratio samples 1.61, 1.04,
0.99 against healthy 1.45, 1.00, 1.13, all 18/18 exit 0;  (c) the
full battery under M1 dies UPSTREAM instead of staying green:
SUITE-KERNEL runs past its 300 s ceiling (`TEST-FAIL`, GATE-EXIT=1
at 302 s, `tot-m6-stageD-mut-M1-RED.log`), because the memo is what
bounds the recursive derivations inside one Auto;  (d) the "near 8"
constant is the attack's UPPER-BOUND ESTIMATE
(`~/Documents/tot-m6-probes/attack-perf/hitcost.py`: t_many + 63 x
(t_one - t_zero)), never a measured mutant.  Attribution ladder:
mutation M1 (no flip, above);  replacement M1R (HIT arm pays 2000
and then 200000 re-quotes of the key per HIT): no flip, ratios
1.22/1.14 and 0.90/0.96, since the arm is never entered;  control
M1C (the same cost in the MISS arm): legs green, ratio 1.0, so the
per-use cost of a leaf resolution is below the timer's resolution.
Resolution: NO leg, fixture or constant was touched (R4 binds 4.0;
D1 pins the fixtures;  D4 pins the leg text).  The five legs ship
green and honestly measured;  the pin-11 mutation proof is OPEN and
needs a ratified re-target (candidates: a fixture whose 64 uses sit
inside ONE Auto, or re-pinning the proof onto the branching legs
that the memo does bound).  Recorded in SPEC.md's Stage D ratio
entry.  D15 item 7 is therefore satisfied for M2-M6 and refuted for
M1.  Stage status reported to the orchestrator as BLOCKED on C-D1,
tree green at 365.

Placement note (not a conflict): the plan anchors the M6D block
"before the M4FIX-INST-BRANCHING comment block";  Stages A-C put
their blocks between the M5E legs and that comment, so the M6D block
follows the Gate C block, the branching pair stays the tail (D15
item 9 holds).

Process note: the first mutation batch restored a HALF-mutated
bin/tot.ml after M2 (the helper backed a file up per substitution,
so the second substitution overwrote the backup);  the void M3/M6/M1
runs that followed are marked VOID in the mutations log at 09:38,
bin/tot.ml was restored by hand to its entry md5, the helper fixed
to back up once per file, and every proof rerun from 09:40.

### 6.  Mutation proofs (plan D12)

All in `~/Documents/tot-m6-stageD-mutations.log` with md5 before,
mutated, and after (identical=True for every row);  OCaml rows
rebuilt with `dunecho build -- --root /Users/oobi/Documents/tot`
before RED and after restore.  Oracle = `gate-d-legs.sh` (the M6D
block with the battery preamble) unless a full battery is named.

| # | Mutation | Predicted | Observed |
|---|---|---|---|
| M1 | check.ml:766 `find_opt` bound to `None` | FAIL-M6D-HIT-RATIO, ratio ~7-8 | REFUTED: legs all PASS, ratio 2.85 then 1.61/1.04/0.99;  full battery dies at SUITE-KERNEL 300 s (C-D1) |
| M2 | tot.ml deadline hoisted above `prelude_source ()` | `FAIL-M6D-COLD-OUTSIDE-BUDGET (exit=0/3/3)` | AS PREDICTED: `FAIL-M6D-COLD-OUTSIDE-BUDGET (exit=0/3/3)`, four legs before it PASS;  restore GREEN 5/5 |
| M3 | cache.ml:432 `save` body `()` | `FAIL-M6D-COLD-STORE (store=0)`, WINDOW green | AS PREDICTED: BASELINE, RATIO, COLD-WINDOW PASS then `FAIL-M6D-COLD-STORE (store=0)`;  restore GREEN 5/5 |
| M4 | gates.sh D5 bare watchdog instead of gate_timed | first red `FAIL-M5D-TIERS` tiers=158 | AS PREDICTED, full battery: `FAIL-M5D-TIERS (nolit=1 tiers=158 bites=2)` after 334 PASS;  restore battery 365 GATE-EXIT=0 |
| M4b | M4 plus `-eq 157` -> `-eq 158` | `FAIL-M5D-MEASURE-LOG (lines=21 ...)` | AS PREDICTED, full battery: `FAIL-M5D-MEASURE-LOG (lines=21 ok=21 names=[... M6D-HIT-BASELINE M6D-HIT-MANY M6D-HIT-ONE SUITE-KERNEL SUITE-SURFACE ] ...)` after 362 PASS;  restore 365 GATE-EXIT=0 |
| M5 | gates.sh pre-count glob and D5 cold run at `$m6d_scratch/warm` | `FAIL-M6D-COLD-WINDOW (pre=1 ...)` | AS PREDICTED: `FAIL-M6D-COLD-WINDOW (pre=1 exit=0/0)` after BASELINE and RATIO PASS;  restore GREEN 5/5 |
| M6 | check.ml:758 `"inst$"` -> `"inst%"` | `FAIL-M6D-HIT-BASELINE (exit=1)` | AS PREDICTED: first line `FAIL-M6D-HIT-BASELINE (exit=1)`;  restore GREEN 5/5 |
| M1X | reach probe: HIT arm -> `Error (unresolved ())` | (C-D1 ladder) | hit-one exit 0, hit-many exit 0 (65 lines), m5b-inst-branching-20 exit 1 |
| M1R | replacement: 2000 / 200000 re-quotes per HIT | flip if the arm is reached | no flip (1.22, 1.14 / 0.90, 0.96) |
| M1C | control: the same cost in the MISS arm | green | green, ratio 1.0 |

### 7.  Exit criteria (plan D15) walked

1. Five markers present, exactly the reserved names (final log
   423-427).
2. `rg -c '^PASS' ~/Documents/tot-m6-stageD-gate.log` = 365 = 360 + 5
   (224 non-marker = 105 kernel + 119 surface, 141 markers = 136 + 5);
   `rg -c '^FAIL'` exits 1;  last line `GATE-EXIT=0`.  Whole-output
   `diff stageC-verify stageD-gate`: `405d404 < PASS-M5D-MEASURE-LOG`
   (the marker MOVED, pin 13) and `423a423,428` (the five new markers
   plus the moved one);  the sorted `^PASS` multiset diff is
   `354a355,359` with the five `PASS-M6D-*` lines and no `<` line.
3. PASS-M5D-MEASURE-LOG green at line 428 (after the M6D legs) with
   `-eq 22` twice and the 22-name literal;  `rg -c '^MEASURE '` on
   the final measure log = 24.
4. PASS-M5D-TIERS green, literal `-eq 157` = 151 + 6;  recipe counts
   before 151 / after 157 (section 2.2).
5. Fixtures present with headers (unstaged `??`);  budget-1 on
   m6d-bigcheck exits 3 with the exact stderr line;  flake record 20
   of 20 (section 4).
6. Transcript resealed additions-only (section 2.3), corpus 99 with
   its command, PASS-M5E-DEFAULT-IDENTITY at final line 405.
7. Six mutations recorded with md5-identical restores (section 6);
   M1 refuted and ladder-walked, OPEN under C-D1 (resolved 2026-09-03, see section Stage F: C-D1 RESOLVED by ruling (a)).
8. SPEC entries dated 2026-09-03;  pin-5 bullet opens
   `Retired (M6 Stage D)`.
9. M4FIX-INST-BRANCHING (gates.sh 3008-3012) and M5B-BRANCHING-20
   (3026-3031) are the last two legs;  `exit 0` at 3038.
10. Nothing staged or committed;  `git log -1 --oneline` = `18b7ab6`;
    only files under /Users/oobi/Documents/tot edited (evidence files
    live in ~/Documents outside the repo).

### 8.  Porcelain and gate tails

`git status --porcelain` (Stage D adds ` M SPEC.md`, ` M dev/gates.sh`,
` M dev/m5e-default-transcript.txt`, `?? test/fixtures/m6d-*.tot` x3
to the Stage A-C set):

```
 M SPEC.md
 M bin/tot.ml
 M dev/gates.sh
 M dev/m5e-default-transcript.txt
 M lib/check.ml
 M lib/totality.ml
 M surface/bootstrap.ml
 M surface/elab.ml
 M surface/lexer.ml
 M surface/parser.ml
 M surface/run.ml
 M surface/serror.ml
 M surface/syntax.ml
 M surface/token.ml
 M test/main.ml
 M test/surface.ml
?? dev/M6-BUILD-LOG.md
?? test/fixtures/bad2.tot
?? test/fixtures/crossformal-t.tot
?? test/fixtures/deep2.tot
?? test/fixtures/m6c-hole-a.tot
?? test/fixtures/m6c-hole-e-explicit.tot
?? test/fixtures/m6c-hole-e.tot
?? test/fixtures/m6c-hole-n-class.tot
?? test/fixtures/m6c-hole-n-infer.tot
?? test/fixtures/m6c-hole-n-proof.tot
?? test/fixtures/m6c-hole-run.tot
?? test/fixtures/m6c-underscore-binders.tot
?? test/fixtures/m6c-underscore-def.tot
?? test/fixtures/m6c-underscore-lam.tot
?? test/fixtures/m6c-underscore-match.tot
?? test/fixtures/m6d-bigcheck.tot
?? test/fixtures/m6d-hit-many.tot
?? test/fixtures/m6d-hit-one.tot
?? test/fixtures/nested-neg.tot
?? test/fixtures/nested-pos.tot
```

Final battery tail (`~/Documents/tot-m6-stageD-gate.log`):

```
PASS-M6D-HIT-BASELINE
PASS-M6D-HIT-RATIO
PASS-M6D-COLD-WINDOW
PASS-M6D-COLD-STORE
PASS-M6D-COLD-OUTSIDE-BUDGET
PASS-M5D-MEASURE-LOG
PASS-M4FIX-INST-BRANCHING
PASS-M5B-BRANCHING-20
GATE-LOG=/tmp/claude-501/tot-gate-measure.log
GATE-EXIT=0
```

Handoff to Stage E: chain starts at 365 (105 + 119 + 141);  tiers
literal 157;  `echo PASS-` sites 140;  transcript corpus 99;
PASS-M5D-MEASURE-LOG literal 22 at its new position (24 rows at
battery end);  `expected-type-only=NN` still spelled ONCE in SPEC.md
(C-C5);  C-D1 (pin-11 mutation proof) OPEN for the user's ruling (resolved 2026-09-03, see section Stage F: C-D1 RESOLVED by ruling (a)).

## Stage E (2026-09-03): corpus growth and reseal (verdict pins 4, 14, scope-in 7-8)

Built from the verified post-D snapshot restored at 12:22 (tree
md5s at entry matched Stage D's exit values byte for byte;  the
earlier partial Stage E attempt was neither extracted nor consulted).
Binary md5 b69a429508f3072b156045799479cf57 after
`dunecho build -- --root /Users/oobi/Documents/tot` (0 errors, 0
warnings).  Every Bash call ran under the disk-floor interlock's
sanctioned per-command override (`# [skip-disk]`, 24-27 GiB free);
no disk was reclaimed.

### 1.  Entry state (E0 probes, before the first edit)

Probe log: `/Users/oobi/Documents/tot-m6-probes/stage-e-build-1222/e0-probes.log`
(runner `run-e0-probes.sh` and `run-e0-exits.sh` beside it).  Every
probe matched the plan:

- P1 `tot.exe check examples/guard.tot`: exit 0, the 10 def lines of
  probe P23's block.
- P2 `python3 dev/hole-anchors.py | wc -l` = 148;  `| tail -1` =
  `ANCHORS total=98 expected-type-only=59 argument-driven=9 neither=30`.
- P3 `--count-sites` = 98.  P5 corpus `ls examples/*.tot
  test/fixtures/*.tot | wc -l` = 99.
- P8 tiers `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh`
  = 157;  `rg -c 'echo PASS-'` = 140.
- P9 `rg -n 'expected-type-only=[0-9]+' SPEC.md` = one line, 1903.
- P10 rewrap deny fixture: exit 2, envelope echoing `let a = h()?;`.
  P11 allow fixture: empty stdout, exit 0.
- P12/P13 (the E6 payloads, block comment and multi-line string):
  BOTH DENIED at exit 2 with the full echoed heredoc (the two
  before-pictures, now in SPEC.md section 2 verbatim).
- P14 `check examples/guard-rewrap.tot` exit 0, 14 def lines.  P15
  `check examples/guard-classes.tot` exit 0, 10 lines.
- P16 `run examples/guard.tot < test/fixtures/deny.json`: exit 2,
  envelope byte-identical to the plan's `m6e_wantenv` literal.  P17
  garbage.json and P18 other.json: empty stdout, exit 0.
- P19 `hole-at-head.tot` (the `cons _ ... (nil _)` list) checks at
  exit 0 on the post-C binary (the plan's HEAD run refused it with
  `unknown name _`;  Stage C resolved it, as expected).
- P21 `quote-prims.tot`: `"\""` lexes;  `stringContains "ab\"c" q`
  true, `headOr` of the split "a", no-quote string false.
- P23 transcript guard.tot block: 14 lines, byte-equal to the
  plan's literal.  Transcript at entry: 10430 lines, 665829 bytes,
  99 blocks, md5 46906fc571c9aca9c8760bf29f2059ce.

Entry battery `/Users/oobi/Documents/tot-m6-stageE-entry-gate.log`:
365 PASS, 0 FAIL, `GATE-EXIT=0`;  the `^PASS` extract is
byte-identical to `/Users/oobi/Documents/tot-m6-stageD-verify.log`'s.

### 2.  What changed

- `examples/guard-rewrap.tot` (md5 7809cb7c -> 7a94d4cd): header
  lines 17-22 replaced by the scrubber rules and recorded misses
  (`//` cuts the rest of the line;  unmatched `/*` cuts the line and
  opens comment state, the `*/` line is dropped whole;  a line with
  both `/*` and `*/` keeps only the text before `/*`;  odd `"` count
  cuts at the first `"` and opens string state, the closing-`"` line
  is dropped whole;  balanced inline quotes not blanked;  no
  escapes, char or raw strings;  lastToken's trailing-whitespace miss
  carried over);  the unported remainder is now the block-tail test,
  the used-name test and the net-new comparison.  The E2 scrubber
  block (`data Scrub` with `sCode | sComment | sString`, `quoteTok`,
  `beforeFirst`, `evenPieces`, `oddQuotes`, `cutSlash`, `cutBlock`,
  `scrubCode`, `nextState`, `scrubLines`) inserted verbatim above
  `rewrapVerdict`;  the pair test now reads
  `hasRewrapPair (dropEmpty (scrubLines sCode (stringSplit cmd "\n")))`.
  Nine E anchors re-spelled `_` (splitEach :63-64, dropEmpty
  :102/:106, main :253-257).
- `examples/guard.tot` (md5 2950e1a6 -> 5fb546f8): seven E anchors
  re-spelled (`nil _` :48, `append _` :49, `let* String _ raw`,
  `let* (Option Json) _ parsed := liftIO _ (jsonParse raw)`,
  `pureIO _ allow`, `pureIO _ (decide payload)`).  The two A anchors
  (`String` and `(Option Json)` at arg 0 of the `let*` lines) stay
  explicit.
- `examples/guard-classes.tot` (md5 4de7521a -> 47b39068): line 26
  `cons _ "grep" (cons _ "sed" (nil _))`;  the three N rows (`refl
  Verdict`, `cong0 String Verdict`, `member String`) stay explicit.
- `test/fixtures/m6e-rewrap-scrub-comment.json` (105 bytes) and
  `test/fixtures/m6e-rewrap-scrub-string.json` (120 bytes): the E6
  payloads, one line plus trailing newline each.
- `dev/gates.sh` (md5 7f6aee1b -> f6989cbd, 3038 -> 3154 lines):
  `| tail -n 1` spliced into `m5d_specE` (now line 2976) with a
  dated comment;  `PASS-M5D-TIERS` literal 157 -> 166 with a dated
  sentence;  the M6E block (lines 2984-3091) inserted after the
  relocated `PASS-M5D-MEASURE-LOG` block and before `# ctxcat id 5:`
  (now 3093), so the two branching legs stay the tail.  Literals
  filled from the build-time rerun: `<H>` = 22, `<T>` = 101, `<E>` =
  62, `<A>` = 9, `<N>` = 30.  Loop-free, no `set -u`, no numeric
  watchdog literal, no process substitution (C-E4), `zsh -n` clean.
- `dev/m5e-default-transcript.txt`: FINAL reseal (section 3).
- `SPEC.md` (md5 d01522f2 -> 7bf63bab): five section 2 entries dated
  2026-09-03 (M6, Stage E) before `## 3.`;  the 2026-09-02 Stage D
  narrow-port entry and the section 6 rewrap debt drop the scrubber
  from their unported lists;  the section 6 holes residual rewritten
  to carry the M5 baseline line, the CURRENT line (the file's last
  `expected-type-only=` spelling, line 1996) and the three remaining
  debts (9 A anchors needing an App arm, 4 in the guards;  40 prelude
  E anchors awaiting soak;  one-error-at-a-time hole reporting).
  The tokenizer-duplication debt stays and now covers the scrubber
  helpers by implication (they live in guard-rewrap.tot only).
- Not touched: stdlib/prelude.tot (md5 6998340c unchanged),
  dev/hole-anchors.py (bffa355a), dev/gen-m5e-transcript.sh
  (f3651eeb), surface/cache.ml (b185d984, `format_version` still 10,
  pin 15), lib/, surface/, bin/, test/*.ml, dev/M6-PLAN.md
  (cce114bb).

Post-edit probe reruns (`e3-verify.log`): all three guards check at
exit 0 (guard-rewrap.tot now prints 27 lines: 14 old defs plus `data
Scrub : Type 0`, 3 ctors, 9 defs);  P10 still denies at exit 2 with
the same envelope;  P11, P12, P13 print nothing at exit 0 (the two
false denies are gone);  P16 envelope byte-identical, exit 2;  P17,
P18 and guard-rewrap on garbage/other: empty, exit 0.

E4 classifier rerun, verbatim:

    $ python3 dev/hole-anchors.py | tail -1
    ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30
    $ python3 dev/hole-anchors.py --count-sites
    101

151 lines of output (was 148);  `rg -c 'anchor=\[_\]'` over the site
list = 22 (7 guard.tot, 12 guard-rewrap.tot including the scrubber's
`headOr` :156, `nil` :203, `cons` :206, 3 guard-classes.tot);  zero
`SITE stdlib/prelude.tot:...anchor=[_]` rows;  every `anchor=[_]`
row is `pos=check bucket=E` (probe P20 bucket-stability holds: the
classifier is invariant under the re-spell, 98 + 3 new sites).

Measured solve count (plan C3): 19 of the 19 example-file E anchors
resolve (7 + 9 + 3), 0 of the 40 prelude E anchors (out of scope),
0 of A and N by design;  no ceiling shortfall, the leg-iii literal
stays 22.  A-site probe (build-time, not a gate): a scratch copy of
guard.tot with line 133's arg 0 spelled `_`
(`let* _ _ raw := readStdin in`) refuses with
`guard-asite.tot:133:8: hole: expected Type 0`, exit 1 (pin 3).

### 3.  Transcript reseal (pin 14, E5)

Regenerated ONCE into scratch by `dev/gen-m5e-transcript.sh` (exit
0), diffed against the Stage D seal: one hunk `38a39,51`, 13 added
lines, all inside the `### examples/guard-rewrap.tot` block (which
starts at line 25):
`data Scrub : Type 0`, `ctor sCode : Scrub`, `ctor sComment : Scrub`,
`ctor sString : Scrub`, and the def lines for quoteTok, beforeFirst,
evenPieces, oddQuotes, cutSlash, cutBlock, scrubCode, nextState,
scrubLines.  No `### ` line in the diff (no block added or removed);
the guard.tot and guard-classes.tot blocks are absent from the diff.
Copied over the seal: `wc -l -c` = 10443 666314 (was 10430 665829),
`rg -c '^### '` = 99 (unchanged), md5
c8d25850ac963922e70f436383aa975e.  Byte-diffed twice: once here for
review, and on every battery by PASS-M5E-DEFAULT-IDENTITY (and
PASS-M6C-DEFAULT-IDENTITY) thereafter.

### 4.  Markers

Final battery `/Users/oobi/Documents/tot-m6-stageE-gate.log`:
`rg -c '^PASS' /Users/oobi/Documents/tot-m6-stageE-gate.log` = 370,
`rg -c '^FAIL'` exits 1 (no match), last lines `PASS-M5B-BRANCHING-20`,
`GATE-LOG=/tmp/claude-501/tot-gate-measure.log`, `GATE-EXIT=0`.
The five new markers print at log lines 429-433, in order:
PASS-M6E-REWRAP-SCRUB, PASS-M6E-REWRAP-OPEN, PASS-M6E-GUARD-HOLES,
PASS-M6E-ANCHORS, PASS-M6E-TRANSCRIPT-RESEALED.  Chain: 334 -> 339
-> 345 -> 360 -> 365 -> 370 (105 kernel + 119 surface + 146
markers;  `echo PASS-` sites 140 -> 145).  Tiers literal 157 -> 166
(`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before
157, after 166: nine FAST uses, 3 + 2 + 4).  Measure log at battery
end: 24 rows (22 counted by MEASURE-LOG plus the two branching
legs), ANCHORS line `total=101 expected-type-only=62
argument-driven=9 neither=30`.

### 5.  Conflicts

- Conflict note C-E1 (2026-09-03): verdict pin 4 says "criterion 3"
  of the rewrap guard is ported;  the repo at
  examples/guard-rewrap.tot:2-9 (the header's description of the
  Python guard) shows four criteria plus a scrubber and a net-new
  comparison, with no numbering that makes "criterion 3" unique;
  resolution: the plan's E12 C1 ruling, criterion 3 = the scrubber
  (comments and strings), and the block-tail test, the used-name test
  and the net-new comparison stay recorded debt in SPEC.md section 6.
- Conflict note C-E2 (2026-09-03): PASS-M5D-MEASURE-LOG's oracle
  (dev/gates.sh, `m5d_specE`) says SPEC's expected-type-only number
  is the ONE `rg -o` match (Stage C conflict C-C5);  the repo after
  this stage shows three spellings (SPEC.md:1403 section 2 entry,
  :1990 M5 baseline, :1996 current);  resolution: the plan's E4
  splice, `| tail -n 1` reads the newest record, the dated comment
  above the line records the retirement of C-C5.
- Conflict note C-E3 (2026-09-03): pin 4 as first read says the
  solve count is measured "against the 59";  the repo at
  stdlib/prelude.tot shows 40 of those 59 in a file Stage E may not
  touch (scope-out 5);  resolution: the plan's E12 C3 ruling, the
  SPEC entry reports solved-of-19 (19 of 19) with the 40 prelude
  anchors named as out of scope and 59 named as a ceiling, never a
  target.
- Conflict note C-E4 (2026-09-03): the plan's E7 block (M6-PLAN.md
  lines 4924-4925) says the TRANSCRIPT-RESEALED FAIL branch diffs
  through `diff <(printf ...) <(printf ...)`;  the repo's build log
  (Stage A-D notes in this file) shows process substitution failing
  under the build sandbox, and Stage E's battery runs under that
  sandbox;  resolution: the FAIL branch writes the two strings to
  `$m5d_scratch/m6e-wantg.txt` and `m6e-gblock.txt` (no NEW scratch,
  the Gate D directory and its EXIT trap) and diffs the files;  the
  PASS path and every assertion are the plan's verbatim.
- Conflict note C-E5 (2026-09-03): plan E4 says `| tail -n 1` reads
  the NEWEST SPEC record and plan E8 puts the new ANCHORS line in the
  section 2 Stage E entry;  the repo shows the M5 baseline line in
  section 6 (SPEC.md:1903 at entry), textually AFTER section 2, so a
  section-2-only spelling would leave `tail -n 1` on 59 and turn
  MEASURE-LOG red;  resolution: the section 6 holes residual (which
  E8 rewrites anyway) carries the M5 baseline line and then the
  CURRENT line as the file's last spelling, with a sentence saying it
  must stay last;  the section 2 entry spells the same current line
  and points at C-E5.  Verified: `rg -o ... SPEC.md | tail -n 1` =
  `expected-type-only=62`, and M-E5 flips only when the LAST spelling
  moves.
- Observations, not conflicts: (a) the M6E block sits after the
  relocated MEASURE-LOG block (Stage D's tail move) rather than
  directly after the M5E block, which E7 rule 4 allows ("after
  PASS-M5E-WITNESS-REJECTED and before the ctxcat id 5 comment");
  the block header comment says so;  the consequence is that under
  M-E5 the fail-fast battery stops at MEASURE-LOG and PASS-M6E-ANCHORS
  is shown green by hand replay (section 6).  (b) The plan's probe
  directory names its `//` line-comment payload
  `m6e-rewrap-scrub-comment.json` (allows at entry) and the E6
  block-comment payload `m6e-scrub-comment.json` (denies at entry);
  the E6 bytes are what shipped under the repo name
  `test/fixtures/m6e-rewrap-scrub-comment.json`, and the P12
  before-picture in SPEC.md is that payload's deny.  (c) The plan
  names HEAD 8d5a839;  the repo's `git log -1 --oneline` is 18b7ab6
  with Stages A-E unstaged, as Stage D recorded.  (d) C-D1 (Stage D,
  pin-11 mutation proof) stays OPEN (resolved 2026-09-03, see section Stage F: C-D1 RESOLVED by ruling (a)) and is not Stage E's to resolve
  (driver args acceptBlocked:'D').

### 6.  Mutation proofs (E9)

Log: `/Users/oobi/Documents/tot-m6-stageE-mutations.log` (driver
`stage-e-build-1222/mut.sh`, per-mutation battery logs `mut-<n>.log`
beside it).  Each row: apply, battery, restore from a pristine copy,
md5 compared.  All seven restores md5-identical.

| id | mutation | predicted flip | observed (first red, PASS count) | restore |
|---|---|---|---|---|
| M-E1 | scrubLines sCode arm keeps `l` and stays sCode (never scrubs) | REWRAP-SCRUB red, c1/c2 0 -> 2 | `FAIL-M6E-REWRAP-SCRUB (c1=2 c2=2 c3=2)`, 363, exit 1 | 7a94d4cd identical |
| M-E2 | scrubLines sCode arm returns `nil _` | first red upstream at M5D-REWRAP-GUARD; leg (c) pins the same | `FAIL-M5D-REWRAP-GUARD (rd=0 ra=0 rc=0)`, 337, exit 1;  hand replay of leg (c): exit 0, empty stdout (red) | 7a94d4cd identical |
| M-E3 | main parse-failure arm `pureIO _ (deny "bad payload")` | REWRAP-OPEN red, c4 0 -> 2 | `FAIL-M6E-REWRAP-OPEN (c4=2 c5=0)`, 364, exit 1 | 7a94d4cd identical |
| M-E4 | guard.tot:136 back to `pureIO Verdict allow` | GUARD-HOLES red, holes 21 | `FAIL-M6E-GUARD-HOLES (c=0/0/0 holes=21 pz=1 env=2)`, 365, exit 1 | 5fb546f8 identical |
| M-E5 | SPEC.md:1996 (the LAST spelling) 62 -> 63 | MEASURE-LOG red, M6E-ANCHORS green | `FAIL-M5D-MEASURE-LOG (... logE=expected-type-only=62 specE=expected-type-only=63)`, 362, exit 1;  hand replay of PASS-M6E-ANCHORS against that run's GATE_LOG: GREEN | 7bf63bab identical |
| M-E6 | hole-anchors.py:417 `bucket = "A"` -> `"N"` (classifier only) | HOLE-ANCHORS and MEASURE-LOG green, M6E-ANCHORS red | `FAIL-M6E-ANCHORS (tot=101)`, 366, exit 1 (both upstream legs green in the log) | bffa355a identical |
| M-E7 | gen-m5e-transcript.sh glob narrowed to `examples/*.tot`, seal regenerated (6 blocks) | DEFAULT-IDENTITY green, TRANSCRIPT-RESEALED red at blocks vs files | `FAIL-M6E-TRANSCRIPT-RESEALED (blocks=6 files=99 scrub=1)`, 367, exit 1;  both DEFAULT-IDENTITY rows green | f3651eeb identical;  seal c8d25850 identical |

The PASS counts are the fail-fast prefix lengths (370 minus the red
leg and everything after it), consistent with the block order.

### 7.  Exit criteria walked (plan E11)

1. `GATE-EXIT=0`, 0 FAIL: yes (section 4).
2. Chain 334 -> 339 -> 345 -> 360 -> 365 -> 370, 105 + 119 + 146:
   yes.
3. The five markers print in the final log: yes, lines 429-433.
4. `rg -c '^PASS' /Users/oobi/Documents/tot-m6-stageE-gate.log` =
   370: recorded with the command.
5. TIERS literal 157 -> 166 with before/after `rg -c`: yes (section
   4).
6. Seven mutations, each pinned, RED, reverted, GREEN, md5-identical:
   yes (section 6).
7. SPEC entry + section 6 edits + MEASURE-LOG splice in the same
   working tree, ready for one commit: yes (all unstaged, the user
   commits).
8. Build log records the classifier outputs, the solve count, the
   hunk list and the probe reruns: yes (sections 1-3).
9. Whole-output diff of the final log against
   `/Users/oobi/Documents/tot-m6-stageD-verify.log`: exactly the
   five added `> PASS-M6E-*` lines (`363a364,368`), nothing else
   moved;  `git log -1 --oneline` = `18b7ab6 dev/M6-PLAN.md: staged
   plan for M6 (holes, blocking Unit posture, WF deletion)`.

### 8.  Porcelain and gate tails

`git status --porcelain`: 19 ` M` (Stage D's 16 plus
examples/guard.tot, examples/guard-rewrap.tot,
examples/guard-classes.tot) and 22 `??` (Stage D's 20 plus
test/fixtures/m6e-rewrap-scrub-comment.json,
test/fixtures/m6e-rewrap-scrub-string.json).  Nothing staged, no
index or history operation performed.  Stage E's own set: SPEC.md,
dev/gates.sh, dev/m5e-default-transcript.txt, the three guards, the
two fixtures, dev/M6-BUILD-LOG.md.

Entry log tail: `PASS-M5B-BRANCHING-20` /
`GATE-LOG=/tmp/claude-501/tot-gate-measure.log` / `GATE-EXIT=0`
(365 PASS).  Final log tail: the same three lines (370 PASS).

Handoff: M6 Stages A-E built and green at 370 (105 + 119 + 146);
tiers literal 166;  `echo PASS-` sites 145;  transcript corpus 99,
FINAL seal 10443 lines / 666314 bytes;  PASS-M5D-MEASURE-LOG reads
the LAST `expected-type-only=` spelling (SPEC.md:1996, keep it last);
C-D1 (pin-11 mutation proof) still OPEN (resolved 2026-09-03, see section Stage F: C-D1 RESOLVED by ruling (a)) for the user's ruling;  all
edits unstaged, the user commits.

## Stage F (2026-09-03): C-D1 RESOLVED by ruling (a), 2026-09-03

Ruling.  The user ruled on C-D1 (Stage D, section "Conflict note
C-D1") in ~/Documents/tot-m6-c-d1-option-a-brief.md: "Let's do
option A".  Option (a) is the fixture re-target: 64 uses of ONE
instance key inside ONE `Term.Auto`, fixture plus docs plus reseal
only.  The OCaml sources (bin/, lib/, surface/, test/*.ml) end
byte-identical to the post-E snapshot: lib/check.ml md5
c394d0d34f013e767f9ff7ff04dc2cd6, bin/tot.ml md5
50500a2378298eb9aa4df540459f7602, before and after every step below.
No `git add`, `git stash`, `git checkout --` or `git restore` was
run;  no fixture was deleted or moved;  corpus stays 99.

### 1.  Fixture design (F1)

test/fixtures/m6d-hit-many.tot was re-authored in place (22 lines,
2256 bytes, md5 d19fcc784a4ebc55e79d20144e48fa0e;  post-E md5
190398ffba3b06b543ec31282b078386).  It is generated by
~/Documents/tot-m6-probes/stage-f-build/gen-hit-many.py with
arguments `32 64` (chain depth, binder count);  the file header says
so.  One class `HC (0 A : Type 0) := { hc : Bool }`;  data `HBox`
and `HTop`, one constructor each;  a leaf instance `HC Bool`;  a
chain instance `(0 A : Type 0) -> HC A -> HC (HBox A)`;  a top
instance with 64 dictionary binders `HC A -> HC A -> ... -> HC (HTop
A)` on ONE type variable;  and one definition `def hits : Bool := hc
(HTop (HBox^32 Bool)) auto`.  The single `auto` is one `Term.Auto`.
`build_instance` (lib/check.ml) peels the top instance's telescope
and recurses into `resolve_auto` once per binder, so the memo key
`HC (HBox^32 Bool)` is asked 64 times inside one `inst_state.memo`:
ask 1 derives the 33-level chain and records the slot, asks 2 to 64
take the HIT arm (lib/check.ml:766-773).  Under plan D12 M1 (the HIT
cut to a miss) each of the 64 asks re-derives the chain.
m6d-hit-one.tot is unchanged (md5 f5a9d6254aacc95d1432ffb8d42859d1);
its two-line stdout pin (PASS-M6D-HIT-BASELINE) still holds.
`tot.exe check` on the new fixture exits 0 with 11 stdout lines
(data HC, ctor mkHC, def hc, data HBox, ctor hbox, data HTop, ctor
htop, def inst$HC$Bool, def inst$HC$HBox, def inst$HC$HTop, `def
hits : Bool`).

Why depth 32.  A leaf key cannot flip M1 (Stage D evidence: a leaf
derive costs about what a HIT costs).  The healthy many side pays
ONE chain derive and that cost grows about quadratically with depth
(healthy medians one / many, seconds: depth 16 0.014 / 0.012;  24
0.012 / 0.014;  32 0.014 / 0.022, later 0.009 / 0.012;  40 0.017 /
0.032;  48 0.013 / 0.032;  64 0.013 / 0.030;  128 0.010 / 0.130;
256 0.030 / 1.231), so a deep chain would push the HEALTHY ratio
over R4.  Under M1 the many side pays 64 derives (mutant medians:
depth 16 0.008 / 0.046, 5.75x;  24 0.008 / 0.095, 11.9x;  32 0.010 /
0.222, 22.2x).  Depth 32 keeps the healthy ratio near 1.5 and the
mutant ratio above 14 on this machine (load average above 20).  The
design probe applied M1 with `sd -s`, exactly the plan D12 text, one
mutation at a time: md5 before c394d0d3..., mutated
034fc6082fc9c28898d0a4c97a6fa577, `dunecho build` 0, probes, inverse
`sd -s`, md5 after c394d0d3... identical, rebuild 0
(~/Documents/tot-m6-probes/stage-f-build/m1-probe.zsh,
probe-mutant-1.log).

### 2.  Healthy runs (F2)

Five isolated runs of the M6D block (gate-f-legs.sh, the Stage D
block runner, all five legs PASS each time;  logs
legs-healthy-{1..5}.log):

| run | one | many | ratio |
|---|---|---|---|
| 1 | 0.011 | 0.015 | 1.36 |
| 2 | 0.012 | 0.015 | 1.25 |
| 3 | 0.013 | 0.016 | 1.23 |
| 4 | 0.010 | 0.015 | 1.50 |
| 5 | 0.008 | 0.013 | 1.63 |

Run 1 nine-run pairs (all `exit=0`): ONE 0.010 0.011 0.010 0.010
0.011 0.011 0.010 0.011 0.012;  MANY 0.016 0.015 0.013 0.013 0.015
0.016 0.012 0.015 0.016.

### 3.  Mutation proofs (F3)

Discipline per mutation: md5 before, `sd -s` with the plan D12 exact
text, md5 mutated, `dunecho build`, N isolated M6D block runs (RED
expected), inverse `sd -s`, md5 after identical, rebuild, one GREEN
run (mut-proof.zsh;  logs F3-M1-proof.log, F3-M2-proof.log,
legs-M1-red-{1..5}.log, legs-M1-green-1.log, legs-M2-red-1.log,
legs-M2-green-1.log).  One mutation at a time, M1 fully restored
before M2 began.

| mutation | file (md5 before / mutated) | build | RED (verbatim) | restore |
|---|---|---|---|---|
| M1 (13:18:42): `InstMemo.find_opt mkey st.memo` -> `(Option.bind (InstMemo.find_opt mkey st.memo) (fun _ -> None))` | lib/check.ml c394d0d34f013e767f9ff7ff04dc2cd6 / 034fc6082fc9c28898d0a4c97a6fa577 | 0 | `FAIL-M6D-HIT-RATIO (one=0.011 many=0.233 ok=18)`, `FAIL-M6D-HIT-RATIO (one=0.014 many=0.204 ok=18)`, `FAIL-M6D-HIT-RATIO (one=0.010 many=0.215 ok=18)`, `FAIL-M6D-HIT-RATIO (one=0.014 many=0.215 ok=18)`, `FAIL-M6D-HIT-RATIO (one=0.009 many=0.244 ok=18)` (21.2x, 14.6x, 21.5x, 15.4x, 27.1x;  PASS-M6D-HIT-BASELINE green before each) | md5 c394d0d3... identical, rebuild 0, GREEN run PASS-M6D-HIT-RATIO one=0.012 many=0.018 |
| M2 (13:22:16): `budget_of_ms check_budget_ms` hoisted above `prelude_source ()` (two substitutions, plan D12) | bin/tot.ml 50500a2378298eb9aa4df540459f7602 / f73df22716795b5fa20d243c1986e895 | 0 | BASELINE, RATIO, COLD-WINDOW, COLD-STORE PASS then `FAIL-M6D-COLD-OUTSIDE-BUDGET (exit=0/3/3)` (AS PREDICTED, plan W3) | md5 50500a23... identical, rebuild 0, GREEN run PASS-M6D-HIT-RATIO one=0.007 many=0.011 |

M1 run-1 nine-run pairs under the mutation: ONE 0.010 0.011 0.012
0.010 0.012 0.011 0.011 0.009 0.009;  MANY 0.239 0.261 0.307 0.195
0.170 0.182 0.190 0.508 0.233 (all `exit=0`, ok=18).  Pin 11 now
has a flipping mutation proof.  The M1 row of the Stage D table
("REFUTED") is history and stays as written.

Full battery after the M1 restore, BEFORE the reseal
(~/Documents/tot-m6-stageF-m1-green.log): 339 PASS,
`446:FAIL-M5E-DEFAULT-IDENTITY (exit=0/1)`, GATE-EXIT=1 (see C-F1).
After the reseal (~/Documents/tot-m6-stageF-m1-green-2.log): 370
PASS, 0 FAIL, GATE-EXIT=0, lines 423-424 PASS-M6D-HIT-BASELINE /
PASS-M6D-HIT-RATIO.

### 4.  Reseal (F4)

`zsh dev/gen-m5e-transcript.sh` resealed dev/m5e-default-transcript.txt;
a second regeneration to scratch (transcript-second.txt) is
byte-identical.  Old seal: md5 c8d25850ac963922e70f436383aa975e,
10443 lines, 666314 bytes.  New seal: md5
2da162428641f61008255d2c3d366b39, 10389 lines, 666968 bytes, 99
`### ` blocks.  Diff against the post-E seal: one hunk
`10278,10342c10278,10288` (65 `<` lines, 11 `>` lines) inside the
`### test/fixtures/m6d-hit-many.tot` block (block header at line
10275), nothing else.  Literals: PASS-M5D-TIERS `-eq 166` (dev/gates.sh:2277,
gates.sh untouched, count unchanged 166);  corpus 99 -> 99;
transcript blocks 99;  PASS-M6E-TRANSCRIPT-RESEALED blocks == files
holds;  PASS-M5D-MEASURE-LOG still reads the LAST
`expected-type-only=` spelling (SPEC.md, unchanged position).

### 5.  Conflicts

Conflict note C-F1 (2026-09-03): the brief's F3 says "full battery
GREEN" after the M1 restore, and F4 (the reseal) comes after F3;
the repo at dev/gates.sh PASS-M5E-DEFAULT-IDENTITY regenerates the
transcript and compares it with the seal, so with the new fixture
and the old seal the battery is red by construction
(`446:FAIL-M5E-DEFAULT-IDENTITY (exit=0/1)`, 339 PASS,
~/Documents/tot-m6-stageF-m1-green.log);  resolution: F4 was
performed first and the F3 battery rerun (370 PASS, GATE-EXIT=0,
~/Documents/tot-m6-stageF-m1-green-2.log);  nothing was tuned.

The brief cites line 1585 for a Stage E OPEN mention;  the word is on
line 1586 (the sentence starts on 1585).  Annotated 1586, recorded
here, no other change.

### 6.  Final battery (F6)

Run at 13:34 from the clean tree (no mutation applied, no scratch
file inside the repo;  `dunecho build` first: `OK build: 0 errors, 0
warnings`, lib/check.ml md5 c394d0d34f013e767f9ff7ff04dc2cd6):

    zsh /Users/oobi/Documents/tot/dev/gates.sh 2>&1 | tee ~/Documents/tot-m6-stageF-gate.log
    echo GATE-EXIT=$pipestatus[1] | tee -a ~/Documents/tot-m6-stageF-gate.log

`rg -c '^PASS'` = 370 (105 + 119 + 146, the Stage E count, no
delta);  `rg -c '^FAIL'` prints nothing and exits 1;  the log is 437
lines, last line `GATE-EXIT=0`.  Markers at their Stage E positions:
400 PASS-M5D-TIERS, 405 PASS-M5E-DEFAULT-IDENTITY, 423
PASS-M6D-HIT-BASELINE, 424 PASS-M6D-HIT-RATIO, 428
PASS-M5D-MEASURE-LOG.  Measurement log rows this run:
`MEASURE M6D-HIT-ONE tier=120 elapsed=0.010 exit=0` and
`MEASURE M6D-HIT-MANY tier=120 elapsed=0.013 exit=0` (1.30x, load
average 31).  Log tail:

```
PASS-M6E-ANCHORS
PASS-M6E-TRANSCRIPT-RESEALED
PASS-M4FIX-INST-BRANCHING
PASS-M5B-BRANCHING-20
GATE-LOG=/tmp/claude-501/tot-gate-measure.log
GATE-EXIT=0
```

Process note: the build sandbox shell has no `dune` on PATH
(`dunecho: could not run dune`);  the battery and the pre-build ran
after `eval "$(opam env)"` (switch zxcaml-p1, dune 3.24.2) in the
same shell call.  No file changed.

### 7.  Porcelain

Stage F's own set: test/fixtures/m6d-hit-many.tot,
dev/m5e-default-transcript.txt, SPEC.md, dev/M6-BUILD-LOG.md.
Nothing staged.  Evidence outside the repo:
~/Documents/tot-m6-probes/stage-f-build/ and
~/Documents/tot-m6-stageF-*.log.

## Stage G (2026-09-03): review-round fixes

Two review lanes read the unstaged M6 diff: the ctxcat-review lane
(7 survivors, ~/Documents/tot-m6-ctxcat-result.json) and the opus
adversarial lane (5 findings,
~/Documents/tot-m6-opus-logic-pass.md).  The adjudicator merged
ctxcat 1 and 3 into one defect, so eleven verdicts stand: four REAL,
five REFUTED, two USER.  This stage implements the four REAL
verdicts, proves every strengthened gate the section 6 way, and
records the two USER verdicts as conflicts C-G1 and C-G2.  Nothing
was staged.  HEAD stays 18b7ab6.

Files touched: surface/elab.ml, examples/guard-rewrap.tot,
dev/gates.sh, test/fixtures/m6g-rewrap-deny-slash.json (new),
SPEC.md, dev/M6-BUILD-LOG.md.  Every other file under bin/, lib/,
surface/, test/ and dev/ is byte-identical to the post-F snapshot
~/Documents/tot-m6-postF-snapshot.tgz.  `diff -rq` over bin/, lib/,
surface/, test/ and examples/, plus dev/gates.sh and
dev/m5e-default-transcript.txt, reports exactly three changed files
and one new one: surface/elab.ml, examples/guard-rewrap.tot,
dev/gates.sh and test/fixtures/m6g-rewrap-deny-slash.json.  SPEC.md
and dev/M6-BUILD-LOG.md carry this stage's documentation and nothing
else.  The transcript seal did NOT move: md5
2da162428641f61008255d2c3d366b39 before and after, and
PASS-M5E-DEFAULT-IDENTITY holds with no reseal.

| file | md5 post-F | md5 post-G |
|---|---|---|
| surface/elab.ml | df6a259e11f452f73931a75b809186b5 | 25f429ca375f93b80d6253c231f197da |
| dev/gates.sh | f6989cbd4a9e76f7d40bf12e46e1b225 | adea43dfdc73fa0403196fde3407ab1b |
| examples/guard-rewrap.tot | 7a94d4cd1a23d847e58cba54f9324b79 | 8bdd0ffb3ece33361022a553194bf4c2 |
| SPEC.md | 19a29b662098c28a0572b3ee1a0a38e6 | fc55cafa1ba689f85075bed908e9f45b |
| dev/m5e-default-transcript.txt | 2da162428641f61008255d2c3d366b39 | 2da162428641f61008255d2c3d366b39 |

### 1.  Verdicts

| lane | id | verdict | evidence | action |
|---|---|---|---|---|
| ctxcat | 1+3 (one defect) | REAL | `Option.value ~default:(term globals scope s)` at surface/elab.ml:421 and 448 and `Option.fold ~none:(term globals scope arg)` at 507-509 build the fallback before the combinator looks at the option, because OCaml is strict.  The file states the rule at line 17-19 for `or_else`.  Every check-position `let*` node and every var-headed application was elaborated twice | fixed, surface/elab.ml:24-25, 428, 455, 513-515 |
| ctxcat | 2 | REFUTED | the negative `caps` key is harmless: the capture uses `List.assoc_opt`, total on any key (surface/elab.ml:153-157), and the one consumer at 496 runs under `\| () when j < k ->` with `j` from `List.mapi`, so `0 <= j < k`.  Nothing iterates `caps` | no change |
| ctxcat | 4 | USER | the `_` reservation restates the pinned Stage C decision.  The residual is the migration note and the exit class, both pinned | conflict C-G1 |
| ctxcat | 5 | REAL | the block says "stderr exactly one pinned pin-3 line" for four legs, and only leg (a) counted lines (`[ "$(wc -l < "$m6c_scratch"/a.err)" -eq 1 ]`).  Legs (b), (c) and (d) were unanchored substring matches | fixed, dev/gates.sh:2679-2685 |
| ctxcat | 6 | REFUTED | the SIDE-EFFECT clause reads r.err and is dead weight, but the leg still goes red for the property it names: `printLine` writes stdout and both runs assert `[ -z "$outr" ]` and `[ -z "$outs" ]` | no change |
| ctxcat | 7 | REFUTED | faster hardware shrinks both medians together, so the ratio stays near 1.4;  each sample is a median of nine, `[ "$(( m6d_one > 0 ))" -eq 1 ]` refuses an unresolved timer, and 4.0 is ruling R4 | no change |
| opus | 1 | REAL | ran the shipped guard on two payloads that differ in one line: with `let url = 1;` it denies at exit 2, with `let url = "https://example.com";` it allows at exit 0.  `cutSlash` cut at `//` before `oddQuotes` counted, so the cut prefix held one `"` and opened a phantom string state | fixed, examples/guard-rewrap.tot:172-180 |
| opus | 2 | REAL | legs (a) and (b) of PASS-M6E-REWRAP-SCRUB assert the ALLOW shape, and the only deny control (test/fixtures/m5d-rewrap-deny.json) carries no `//`, no `/*` and no quote, so a selective over-scrub could not turn the gate red | fixed, dev/gates.sh:3017-3027 plus test/fixtures/m6g-rewrap-deny-slash.json |
| opus | 3 | REAL | `if p < k then List.nth_opt settled p` bounds only the upper end, and the stdlib raises `invalid_arg "List.nth"` on a negative index, which the driver's `Serror.t` plumbing cannot catch | fixed, surface/elab.ml:202-203 |
| opus | 4 | USER | the fence arm `\| () when fence -> term globals scope arg` reports "no expected type at this position" where the settled domain is known.  The fence is pinned Stage C behaviour (C-C2) and the wording feeds the pinned hole-anchor class counts | conflict C-G2 |
| opus | 5 | REFUTED | the SAnn order is the ratified C-C1 resolution and the arm's own comment says so (surface/elab.ml:269-276) | no change |

### 2.  Fixes (G1)

surface/elab.ml gains one helper, the lazy sibling of `or_else`:

    (** Lazy default for Option: [Option.value ~default] is eager, this is
        not.  The [some] arm returns a thunk that ignores its unit, so the
        fallback runs only on the [None] path (M6 Stage G). *)
    let unwrap_or (fallback : unit -> 'a) (o : 'a option) : 'a =
      Option.fold ~none:fallback ~some:(fun v () -> v) o ()

It stays inside the plan's combinator rules: no `match` on an
option, one total combinator, and the laziness comes from the arm
types, not from a branch.  The three call sites become
`|> unwrap_or (fun () -> term globals scope s)` (the check-position
`let*` arm and the var-headed application arm) and, at the argument
fold, `|> Option.map (fun dom' -> term_at globals scope ~expected:dom' arg)
|> unwrap_or (fun () -> term globals scope arg)`.  The elaborated
term is the same on every path;  only the discarded work goes away.
The fourth fix is one guard: `if p >= 0 && p < k then ...` at
surface/elab.ml:202.  Behaviour is unchanged on every input reachable
today, and the non-total call disappears.

examples/guard-rewrap.tot makes the comment cut quote aware in one
arm:

    def cutSlash : String -> String :=
      fun l =>
        match oddQuotes (beforeFirst "//" l) with
        | true => l
        | false => beforeFirst "//" l
        end

A `//` whose prefix holds an odd count of `"` sits inside a string,
so the line is kept whole.  The file header and SPEC.md record the
narrowed rule.  The two M6E scrub fixtures and the M5D deny fixture
carry no `//`, so their verdicts do not move, and the corpus stays 99
files with no new `anchor=[_]` site (PASS-M6E-GUARD-HOLES and
PASS-M6E-ANCHORS both green).

dev/gates.sh gains three `wc -l` clauses and four whole-line anchors
in PASS-M6C-HOLE-REPORTS, and one leg in PASS-M6E-REWRAP-SCRUB that
runs the new fixture test/fixtures/m6g-rewrap-deny-slash.json:

    {"tool_name":"Bash","tool_input":{"command":"cat > f.rs <<'EOF'\nlet url = \"https://example.com\";\n// a plain comment\nfn g() -> Result<u8, E> {\n  let a = h()?;\n  Ok(k(a))\n}\nEOF"}}

The new leg adds one direct FAST use, so the PASS-M5D-TIERS literal
goes 166 -> 167 (dev/gates.sh:2280;  measured with
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before
and after the edit, 166 then 167).  The comment above the literal
records the bump next to the Stage E one.

### 3.  Mutation proofs (G2)

Runner: ~/Documents/tot-m6-probes/stage-g-build/mut.sh, which applies
ONE `sd -s` mutation, builds, observes, runs the leg runner
gate-g-legs.sh (the two blocks copied verbatim from the post-G
dev/gates.sh), then restores with the inverse `sd -s`, rebuilds and
re-runs the leg runner.  dev/gates.sh is never edited for a mutation
run.  Logs: ~/Documents/tot-m6-stageG-launch1-mut-G1.log and
~/Documents/tot-m6-stageG-launch1-mut-G2G3G4.log (14:42 to 14:44).

| mutation | file (md5 before / after) | RED (verbatim) | restore |
|---|---|---|---|
| MUT-G1: `"%s: hole: no expected type at this position"` gains `\nhint: annotate the position` | surface/serror.ml 7e3f80e4cf5e5955c3659b73226c1b4e / 7e3f80e4cf5e5955c3659b73226c1b4e | `FAIL-M6C-HOLE-REPORTS (exit=1/1/1/1)`, leg (b) at two stderr lines | md5 identical, rebuild 0, `PASS-M6C-HOLE-REPORTS` |
| MUT-G2: `"%s: hole: expected %s"` gains ` (hint)` | surface/serror.ml, same md5 both sides | `FAIL-M6C-HOLE-REPORTS (exit=1/1/1/1)`, the whole-line anchors reject the suffix on a, c and d | md5 identical, rebuild 0, `PASS-M6C-HOLE-REPORTS` |
| MUT-G3: `"%s: hole: expected %s"` gains `\nhint: fill the hole` | surface/serror.ml, same md5 both sides | `FAIL-M6C-HOLE-REPORTS (exit=1/1/1/1)`, legs (a), (c) and (d) at two stderr lines | md5 identical, rebuild 0, `PASS-M6C-HOLE-REPORTS` |
| MUT-G4: `\| true => l` becomes `\| true => beforeFirst "//" l` in `cutSlash` (the pre-G behaviour) | examples/guard-rewrap.tot 8bdd0ffb3ece33361022a553194bf4c2 / 8bdd0ffb3ece33361022a553194bf4c2 | `FAIL-M6E-REWRAP-SCRUB (c1=0 c2=0 c3=2 cg=0)`, and the new fixture allowed at exit 0 with empty stdout (`OBS m6g-rewrap-deny-slash exit=0 stdout=[]`) | md5 identical, rebuild 0, `PASS-M6E-REWRAP-SCRUB`, the fixture denies again at exit 2 with the echoed `let a = h()?;` |

Vacuity check for ctxcat finding 5
(~/Documents/tot-m6-stageG-launch1-vacuity-G1.log, 14:43).  The
PRE-Stage-G conjunction was copied verbatim into
~/Documents/tot-m6-probes/stage-g-build/gate-preG-m6c-leg.sh and run
under MUT-G1 alongside the post-G one:

    --- pre-G leg under MUT-G1:
    PASS-M6C-HOLE-REPORTS-PREG
    PREG-EXIT=0
    --- post-G leg under MUT-G1:
    FAIL-M6C-HOLE-REPORTS (exit=1/1/1/1)
    POSTG-EXIT=1

So the old leg could not go red for the property it names, and the
three new `wc -l` clauses are what detects the second stderr line.
MUT-G4 is the same kind of evidence for opus finding 1: it restores
the pre-G `cutSlash` and the new leg goes red at once.

Full-battery reds under the same two mutations (produced by the
earlier Stage G build at 14:28 and 14:30, same tree bytes, logs
~/Documents/tot-m6-probes/stage-g-build/battery-G1-red.log and
battery-G4-red.log): MUT-G1 stops earlier, at
`282:FAIL M6C-6 m6c_refuse_infer: an eval hole and a let-annotation hole both report no expected type`
with `GATE-EXIT=1` and 223 PASS, because the unit suite reads the
same message;  MUT-G4 reaches the leg and prints
`433:FAIL-M6E-REWRAP-SCRUB (c1=0 c2=0 c3=2 cg=0)` with `GATE-EXIT=1`
and 363 PASS.  The isolated leg runner is therefore the instrument
for the M6C leg, and the battery confirms the M6E leg end to end.

### 4.  Battery (G3)

Four runs from the clean tree, `dunecho build` first each time
(`OK build: 0 errors, 0 warnings`), logs
~/Documents/tot-m6-stageG-gate.log,
~/Documents/tot-m6-stageG-gate-cost2.log and
~/Documents/tot-m6-stageG-gate-cost3.log.  Run 4 is the last one, made
after the SPEC.md and build-log edits, and it overwrote
~/Documents/tot-m6-stageG-gate.log, so that log is the final tree
state:

    zsh /Users/oobi/Documents/tot/dev/gates.sh 2>&1 | tee ~/Documents/tot-m6-stageG-gate.log
    echo GATE-EXIT=$pipestatus[1] | tee -a ~/Documents/tot-m6-stageG-gate.log

Each run: `rg -c '^PASS'` = 370, `rg -c '^FAIL'` prints nothing and
exits 1, last line `GATE-EXIT=0`, 437 log lines, wall 60 s to 75 s.
The PASS-line set is byte-identical to
~/Documents/tot-m6-stageF-gate.log (`diff` of the two `^PASS`
listings, no output).  Markers: 400 PASS-M5D-TIERS, 405
PASS-M5E-DEFAULT-IDENTITY, 419 PASS-M6C-HOLE-REPORTS, 424
PASS-M6D-HIT-RATIO, 429 PASS-M6E-REWRAP-SCRUB.  No count delta, so
no conflict is owed here.  Log tail:

```
PASS-M5B-BRANCHING-20
GATE-LOG=/tmp/claude-501/tot-gate-measure.log
GATE-EXIT=0
```

### 5.  Cost check (G4)

M6D healthy legs, the four battery runs above, all
PASS-M6D-HIT-RATIO:

| run | one | many | ratio |
|---|---|---|---|
| 1 | 0.016 | 0.019 | 1.19 |
| 2 | 0.012 | 0.016 | 1.33 |
| 3 | 0.013 | 0.022 | 1.69 |
| 4 | 0.010 | 0.019 | 1.90 |

Runs 1 and 2 sit inside the Stage F healthy band (1.23 to 1.63) and
runs 3 and 4 sit just above it, on a machine under load.  All four
are far under R4 = 4.0, and far under the 14x to 27x the M1 mutant
reads (Stage F).  The elab fix does not move this leg: it touches
surface/elab.ml, and the leg measures the instance memo in
lib/check.ml, which is byte-identical to post-F.

`tot.exe check examples/guard-rewrap.tot`, before and after the elab
fix.  The measurement builds the post-F elab.ml in place, times it,
restores the post-G bytes and rebuilds
(~/Documents/tot-m6-probes/stage-g-build/cost-ab2.sh, log
~/Documents/tot-m6-stageG-launch1-cost-ab2.log).  Three blocks of 15
runs per side, seconds:

| side | min | median |
|---|---|---|
| before (post-F, eager) | 0.0196 / 0.0181 / 0.0165 | 0.0228 / 0.0230 / 0.0194 |
| after (post-G, lazy) | 0.0156 / 0.0165 / 0.0171 | 0.0235 / 0.0219 / 0.0213 |

The two sides overlap, so on this file the win is BELOW the noise of
a 20 ms process (about 7 ms of that is start-up).  The earlier
three-run pass agrees (medians 0.0222 before, 0.0232 after,
~/Documents/tot-m6-probes/stage-g-build/time-before.txt and
time-after.txt).  The claim this fix carries is asymptotic, not a
measured speed-up: the discarded `term` call re-elaborates the whole
subtree, so the cost was O(depth x size) on a long `let*` spine.  The
honest reading of the numbers is that nothing regressed and this
corpus is too small to show the difference.  The elab.ml md5 returned
to 25f429ca375f93b80d6253c231f197da after the measurement.

An A/B run with the two binaries COPIED to $TMPDIR was discarded:
both copies exit 1 on every target
(~/Documents/tot-m6-stageG-launch1-cost-ab.log), so tot.exe resolves
something by its own path and a copied binary does not measure a
check.  The in-place method above is the one that reports exit 0.

### 6.  Conflicts

Conflict note C-G1 (2026-09-03): ctxcat finding 4 asks for a
migration note on the `_` reservation, or for `Serror.Hole` to join
the blocking exit-2 class;  SPEC.md 1190-1214 records the pinned
Stage C decision (`_` is reserved, ruling R2) and states the harness
rule that "the PreToolUse harness treats exit codes other than 0 and
2 as non-blocking", and ruling R3 answered the same shape for
strict-json with a MIGRATION NOTE;  resolution: both halves change a
pinned exit mapping or a migration policy, which section 5 reserves
for the user.  Nothing was implemented.  The user chooses (a) a
MIGRATION NOTE in ruling R3's shape, or (b) routing `Serror.Hole` to
exit 2, which needs its own gate legs.

Conflict note C-G2 (2026-09-03): opus finding 4 asks a fenced
argument slot to report its instantiated declared domain instead of
"no expected type at this position";  the repo at
surface/elab.ml:504 shows `| () when fence -> term globals scope arg`
and `term`'s hole arm returns `Error (Serror.Hole { loc; expected =
None })` (surface/elab.ml:284, 393), and a probe on
`def agree : Eq Nat zero zero := refl Nat _` prints
`hole: no expected type at this position` at 1:42 while the settled
domain is `Nat`;  resolution: the fence is pinned Stage C behaviour
(note N2, conflict C-C2) and the wording feeds the pinned
hole-anchor class counts that dev/hole-anchors.py and SPEC.md pin, so
the choice is the user's.  Nothing was implemented.  Either choice
needs a new fixture with a hole at a fenced slot above 0 and a
recount of the anchor classes.

### 7.  Docs and porcelain

SPEC.md: the Stage E scrubber entry now says `//` cuts the rest of
its line "(narrowed at M6 Stage G, see the Stage G entry below)" and
that PASS-M6E-REWRAP-SCRUB gains leg (d);  a new dated entry
"2026-09-03 (M6, Stage G): review-round fixes" records the four real
fixes, the two gate strengthenings and the TIERS bump 166 -> 167.  No
other SPEC sentence moved, and the LAST `expected-type-only=`
spelling stays where PASS-M5D-MEASURE-LOG expects it (section 6
residual).

Porcelain after this stage: 42 paths, 19 ` M` and 23 `??`, nothing
staged (Stage F's 41 plus the new fixture
test/fixtures/m6g-rewrap-deny-slash.json).  Stage G's own paths:
surface/elab.ml, examples/guard-rewrap.tot, dev/gates.sh, SPEC.md,
dev/M6-BUILD-LOG.md and test/fixtures/m6g-rewrap-deny-slash.json.
Evidence outside the repo: ~/Documents/tot-m6-probes/stage-g-build/
and ~/Documents/tot-m6-stageG-*.log.
