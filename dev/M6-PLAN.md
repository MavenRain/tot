# M6 build plan: holes, the blocking Unit posture, and the WF deletion

Authoritative spec for the M6 implementation agents.  Read this WHOLE
file before you read your own stage section, and read it before you
touch code.  The repo is `/Users/oobi/Documents/tot` (OCaml, dune),
entered at HEAD `8d5a839`.  Five sequential stages (A, B, C, D, E), one
agent per stage, each stage green on its own gate before the next one
starts.

This document is self-contained.  Every design decision M6 needs is
written out in this preamble or in a stage section.  Do NOT go looking
for the design brief, the panel proposals, or the verdict;  none of them
are inputs to the build.  The verdict at
`/Users/oobi/Documents/tot-m6-design-verdict.md` was RATIFIED BY USER on
2026-09-03, all five open questions AS STATED (rulings R1 to R5,
restated in section 1.1 below).  Its 18 pins are restated across this
preamble and the stage sections.  A stage section may add detail to a
pin.  A stage section may NOT reinterpret a pin, soften it, or trade it
for a different one.  If you believe a pin is wrong, record the argument
in `dev/M6-BUILD-LOG.md` and build it as written, unless the section 5
protocol applies.

Background reading, in this order, only if a detail here is ambiguous:

1. `/Users/oobi/Documents/tot/SPEC.md` sections 2 and 6
2. `/Users/oobi/Documents/tot/dev/M5-PLAN.md` (the house plan format)
3. `/Users/oobi/Documents/tot/dev/M5-BUILD-LOG.md` (the mutation-proof
   template at 1549-1593 and the exit criteria at 1669-1677)

## 1. Purpose and entry state

M6 builds the ratified winner: the DOGFOOD proposal, repaired, with
grafts from both losers.  It puts a hole pass where the operator's
fingers are, closes the fail-open gap for `IO Unit` guards, deletes the
well-founded-recursion flag while preserving every oracle the spike
earned, and pins the two costs M5 left unpinned.  It adds no kernel
typing power (pin 1): every program accepted after M6 is a program the
HEAD rules accept when spelled explicitly, and `Term.t` gains no Hole
constructor.

### 1.1 Goal recap from the ratified verdict

The verdict scored dogfood 28/40 over perf 22/40 and semantics 20/40
and took three kinds of grafts:

- From semantics: the positivity-fence tripwire gates, the WF
  negative-oracle idea extended with the crossformal and depth-2
  witnesses, and the discipline of recording the per-candidate seed
  invariant (lib/totality.ml:184-186) as a dated SPEC entry so future
  WF work inherits an executable oracle, not a memory.
- From perf: bad2 promoted into test/fixtures as a flag-free negative,
  the survival rule stated on exit status, the cold-store entry-count
  anti-vacuity assertion, and the honest non-vacuity framing "the
  oracle fails today and passes only after the change".
- From the attacks: the >1024-node mutation target for the budget leg,
  and the rule that every rg-derived count ships with its exact
  command (pin 17).

Eight items are IN scope: (1) expected-type-only holes with `_`
reserved in term position, check position only, sized by the anchor
corpus (E = 59 is a ceiling);  (2) the blocking `--strict-json` posture
for `IO Unit` scripts (exit 1 becomes exit 2, same stderr line);
(3) delete `--experimental-wf` across its full perimeter, the
residual's delete arm;  (4) WF negative-oracle preservation plus fence
tripwires;  (5) two cost legs, memo-HIT ratio and cold-bootstrap
window, with anti-vacuity assertions and honest constants;  (6) one
structured hole-error slice, the error constructor carrying the
expected type as a structured value;  (7) guard corpus growth, the
rewrap scrubber ported and the anchor classifier re-run;  (8) the
example-file E anchors re-spelled with holes at Stage E, with a
reviewed transcript reseal.

The five user rulings of 2026-09-03, binding on every stage:

- **R1 (WF flag): DELETE.**  The panel majority and judge disposition
  stands.  M7 re-entry is a rebuild of the App arm, not a flag flip.
  The WF negative oracles survive as flag-free fixtures per pin 9.
- **R2 (underscore): HARD RESERVATION** of `_` as the hole and
  anonymous-binder token.  The three synthetic shapes break by design;
  the shipped corpus has zero term-position uses and stays green
  (probes P1 and P7 below).
- **R3 (Unit strict-json): the exit migration 1 -> 2 lands as a DIRECT
  breaking change.**  The SPEC migration note is the sole mitigation.
  No new opt-in flag.
- **R4 (HIT-ratio threshold): the constant is 4.0**, re-derived from
  live measurements (healthy 1.28 median-of-9, mutated near 8).
- **R5 (guard re-spell timing): guard.tot and the example E anchors
  are re-spelled INSIDE M6.**  PASS-M6E-GUARD-HOLES and the second
  reseal stay in scope.

### 1.2 Baseline

M5 is committed at `8d5a839`.  The battery at entry, recorded by the
M5 close-out (dev/M5-BUILD-LOG.md:1671-1674, read 2026-09-03):

    dunecho build                      OK build: 0 errors, 0 warnings
    dune exec test/main.exe            106 PASS  (104 + E1 + E2)
    dune exec test/surface.exe         107 PASS
    zsh dev/gates.sh                   GATE-EXIT=0, 121 gate markers

    TOTAL BASELINE: 106 + 107 + 121 = 334 PASS, 0 FAIL

The M5 walk that produced it: 278 -> 301 -> 312 -> 323 -> 329 -> 334
(dev/M5-BUILD-LOG.md:1713-1716).  Every M6 stage gate runs ON TOP of
334.  A stage that ends with fewer than 334 plus its own net additions
has broken something.  Never delete or weaken an existing case to make
a stage green, except where a stage section names the retirement
explicitly (Stage A retires PASS-M5E-ACC-CHECKS and kernel test E1;
nothing else retires anything).

Gate command battery (all must be green before you report):

    dunecho build -- --root /Users/oobi/Documents/tot
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -3
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -3
    zsh /Users/oobi/Documents/tot/dev/gates.sh > "$TMPDIR/tot-gate.out" 2>&1; echo "GATE-EXIT=$?"
    rg -c '^PASS' "$TMPDIR/tot-gate.out"
    rg -c '^FAIL' "$TMPDIR/tot-gate.out"

Run the battery BEFORE you edit anything.  Record the tails in your
report.  A red at baseline belongs to the previous stage, not to
yours, and you must say so instead of absorbing it.

### 1.3 Facts about the CURRENT binary

Each transcript below was produced on 2026-09-03 against
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe` at `8d5a839`
with `TOT_PRELUDE=/Users/oobi/Documents/tot/stdlib/prelude.tot`.  The
runner is `/Users/oobi/Documents/tot-m6-probes/plan-preamble/`
`run-probes.zsh`;  fixtures sit beside it, never in the repo.  Do NOT
restate any of these from memory.  Re-run the probe if your stage
depends on the exact bytes.

**P1.  The three pin-2 underscore shapes CHECK at HEAD.**  `_` is an
ordinary identifier-start character (surface/lexer.ml:9-12), so all
three fixtures pass today and all three must FAIL after Stage C:

    tot.exe check underscore-lam.tot      # def f : Nat -> Nat := fun _ => _
    def f : (w _ : Nat) -> Nat
    underscore-lam exit=0
    tot.exe check underscore-def.tot      # def _ : Nat := succ zero ; def g : Nat := _
    def _ : Nat
    def g : Nat
    underscore-def exit=0
    tot.exe check underscore-match.tot    # ... match n with | zero => zero | succ _ => _ end
    def h : (w _ : Nat) -> Nat
    underscore-match exit=0

**P2.  The Unit strict-json refusal exits 1 today (pin 5 baseline).**
The fixture is a minimal `IO Unit` main that performs one `readStdin`:

    printf 'not json' | tot.exe run --strict-json unit-guard.tot
    unit-guard.tot:stdin is not a single well-formed JSON value, and this installation runs with --strict-json
    strict exit=1
    printf 'not json' | tot.exe run --strict-json --serror-exit 7 unit-guard.tot
    unit-guard.tot:stdin is not a single well-formed JSON value, and this installation runs with --strict-json
    strict serror7 exit=1

After Stage B both invocations exit 2 with the SAME single stderr line
and nothing on stdout, outside the `--serror-exit` mapping (R3).  The
driver arm that classifies `Serror.Json_strict_reject` today is
bin/tot.ml:106-108 (`driver_exit` -> 1).

**P3.  The flag M6 deletes is LIVE at HEAD.**  The usage line still
carries it, and test/surface.ml:412-415 pins that line verbatim:

    tot.exe check
    usage: tot (check|run) [--no-prelude] [--no-axioms] [--serror-exit N] [--check-budget-ms N] [--require-main] [--experimental-wf] [--strict-json] FILE | tot prims
    usage exit=2

**P4.  The hole-anchor classifier baseline (pin 4).**

    python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | wc -l
    148
    python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | tail -1
    ANCHORS total=98 expected-type-only=59 argument-driven=9 neither=30

Per-file decomposition, each with its exact command:
`python3 dev/hole-anchors.py | rg -c '^SITE .*bucket=E$'` = 59;
`python3 dev/hole-anchors.py | rg -c '^SITE stdlib/prelude\.tot.*bucket=E$'`
= 40;  `python3 dev/hole-anchors.py | rg -c '^SITE examples/guard\.tot'`
= 9 (seven bucket=E, two bucket=A;  the rows at guard.tot:48 head=nil
and guard.tot:49 head=append are both bucket=E, confirming pin 4's
NINE-site accounting).

**P5.  The PASS-M6 namespace is free (pin 16).**  Transcript in
section 4.2.

**P6.  The M5 watchdog-literal oracle stays green at HEAD.**

    rg -c '"\$watchdog" [0-9]+' /Users/oobi/Documents/tot/dev/gates.sh
    (no output)
    rg exit=1

**P7.  The shipped corpus has no live `_` to break (R2).**  Over
stdlib/prelude.tot plus all six examples/*.tot (530 lines total,
`wc -l stdlib/prelude.tot examples/*.tot`):

    rg -n "(^|[^A-Za-z0-9_'])_($|[^A-Za-z0-9_'])" stdlib/prelude.tot examples/*.tot
    examples/guard-rewrap.tot:7:-- next tokens, the `Ok(_)` as a block TAIL, and the bound name
    examples/guard-rewrap.tot:8:-- genuinely used inside the `Ok(_)`.  It scrubs comments and strings,
    rg exit=0

Both hits are COMMENT lines.  Zero `_`-named globals
(`rg -n '^def (rec )?_[^A-Za-z0-9]' stdlib/prelude.tot examples/*.tot`
exits 1, no output), zero term-position uses, zero binder uses in
shipped code.  The hard reservation changes no shipped file's meaning.

**P8.  Corpus and transcript constants (pin 14).**
`ls examples/*.tot test/fixtures/*.tot | wc -l` = 80;
`wc -l -c dev/m5e-default-transcript.txt` = 9660 lines, 653286 bytes.
Stage A grows the corpus 80 -> 85 and MUST regenerate the transcript
in the same commit.

**P9.  Marker inventory (pin 16).**
`rg -o 'PASS-M[45][A-Z]*-[A-Z0-9-]+' dev/gates.sh | sort -u | wc -l`
= 69 distinct PASS-M4*/PASS-M5* markers;
`rg -o 'PASS-M4FIX-[A-Z0-9-]+' dev/gates.sh | sort -u | wc -l` = 23,
which is why the often-quoted 46 undercounts.  None collide with
PASS-M6.

**P10.  The .mli debt count (M7 debts list).**
`ls lib/*.ml | wc -l` = 17;  `ls lib/*.mli` = budget.mli, level.mli.
17 modules, 2 done, matching SPEC.md:1351-1352.

### 1.4 Verified anchors

Every file:line below was read at `8d5a839` on 2026-09-03 by this
plan's writer.  Use these anchors, not remembered ones.

| Anchor | Content |
| --- | --- |
| surface/lexer.ml:9-12 | `is_ident_start` treats `_` as an ordinary identifier-start character |
| surface/cache.ml:118 | `let format_version : int = 10` |
| surface/cache.ml:154-161 | `cache_dir_opt`: `TOT_CACHE_DIR` override, then `HOME/.cache/tot` |
| lib/totality.ml:13-15 | `type rule = Structural \| Structural_wf` |
| lib/totality.ml:184-186 | the per-candidate `Principal` seed: `List.init formals (fun ix -> if Int.equal ix (formals - 1 - k) then Principal else Other)` |
| lib/check.ml:770-773 | the memo HIT returns the slot and the CACHED value, no re-derive |
| lib/check.ml:1208-1211 | `check` has no `App` arm: `Term.App` falls through to `check_via_infer` |
| lib/check.ml:1464-1466 | `Check.define` with REQUIRED named `~rule` argument |
| lib/check.ml:1762-1773 | `define_instance` passes `~rule:Totality.Structural` but no `~rec_` (call at 1772-1773), so the guard never runs on instance bodies |
| bin/tot.ml:42-47 | the budget poll: deadline read only when `!ticks land 1023` is 0, the 1024-poll throttle |
| bin/tot.ml:106-108 | the `driver_exit` arm: `Json_strict_reject` prints one line, exits 1 today |
| bin/tot.ml:257 | the `--experimental-wf` parse arm |
| bin/tot.ml:277-278 | the unknown-flag contract: one stderr line `unknown flag: <a>`, exit 2 |
| bin/tot.ml:287-289 | the policy mapping `wf_rule = if opts.experimental_wf then Structural_wf else Structural` |
| test/main.ml:2827, 2837 | E1/E2, the direct `~rule:Totality.Structural_wf` guard calls |
| test/main.ml:3072-3073 | E1/E2 registration lines |
| test/surface.ml:412-415 | the usage-line pin containing `[--experimental-wf]` |
| dev/gates.sh:26-48 | the tier block: FAST=10 MED=30 SLOW=120 SUITE=300 BITE_S=1;  "A tier is a HANG ceiling, not a performance budget" at line 30 |
| dev/M5-BUILD-LOG.md:1549-1593 | the mutation-proof template (flip, replacement on refutation, md5-identical restore) |
| dev/M5-BUILD-LOG.md:1671-1674 | the 334 = 106 + 107 + 121 decomposition |
| dev/M5-BUILD-LOG.md:1713-1716 | the M5 PASS walk 278 -> 334 |
| SPEC.md:851-853 | nesting keeps `self_rec`;  the `Frozen` emptiness claim stays UNPROVEN, "this oracle rather than a memory" |
| SPEC.md:1062-1063 | the spike "exists to be measured, not to be relied on, and M6 either promotes it or deletes it" |
| SPEC.md:1092-1101 | the indexed-relation quantity gap, exact mismatch line, "is M6 work" |
| SPEC.md:1111-1112 | erased `Acc` elimination and the fence are "COUPLED: M6 must size them together or neither" |
| SPEC.md:1351-1352 | the .mli debt: only `Level` and `Budget` done |
| SPEC.md:1355 | the Apache license vendoring debt |
| SPEC.md:1356-1358 | errors carry pre-rendered strings, "revisit when the elaborator wants error recovery" |
| SPEC.md:1603-1610 | `Eq` monomorphic at `Type 0`;  a `Type 1` equation needs a hand-written `Eq1` layer |
| SPEC.md:1615-1619 | the `Frozen` emptiness claim restated;  mutual or nested inductives "could open a gap the current fence does not cover" |
| SPEC.md:1626-1639 | the holes debt with the measured ANCHORS line and the two structural reasons |
| examples/guard-rewrap.tot:24-29 | the tokenizer duplication recorded as a SPEC section 6 debt |

## 2. Build ground rules

- The build happens in the WORKING TREE only.  Do NOT run `git add`,
  `git commit`, `git checkout` or any other history or index
  operation.  This binds EVERY stage agent, with no exception for
  "staging my own stage".  Staging is DEFERRED to build completion:
  the MAIN LOOP alone runs `git add -A` after the final battery and
  the review rounds, and the USER commits.  A stage exit criterion
  that asks for a staged tree is a drafting error.
- Report `git status --porcelain` in your stage report so the diff
  surface is visible while it is still unstaged.
- Run the section 1.2 battery before your first edit and before your
  report.  Append a stage report to
  `/Users/oobi/Documents/tot/dev/M6-BUILD-LOG.md` when your stage is
  green: what changed, files touched, new `Error.t` and `Serror.t`
  variants, test names added, gate markers added, every mutation
  proof, every count WITH its command (pin 17), the new PASS count
  with its decomposition, and the gate output tails.
- Never `cd` in a Bash tool CALL;  your cwd RESETS between calls.  Use
  absolute paths, and put a multi-step probe in ONE runner script that
  fixes its own cwd on its first line.
- Shell: `rg` not grep, `sd` not sed.  No em-dashes in any text you
  write;  ASCII punctuation only;  two spaces after a sentence-ending
  "." or ";" in prose.
- NEW gate legs and dev scripts are LOOP-FREE: no `for`, no `while`,
  in zsh legs included.  This TIGHTENS the M5 rule that tolerated
  small shell loops.  The one legacy `while` (mm_nest, M4) stays as it
  is;  do not add a second.
- OCaml house rules, unchanged from M5 and hook-enforced: no
  exceptions (`raise`/`failwith`/`assert`);  no `match` on
  Option/Result where a combinator does the job;  no loop keywords;
  no list or array mutation;  exhaustive matches with no catch-all
  `_ ->` arms on enumerable variants;  `match () with | () when ...`
  ladders over `if`/`else if` chains;  no `arr.(i)`, no `List.nth`;
  doc comments on every new top-level item.  These bind `lib/`,
  `surface/`, `bin/` and `test/`;  they do not bind `dev/*.sh` or
  `dev/*.py` except for the loop-free rule above.
- `dev/gates.sh` must not use `set -u`.
- Every feature ships WITH its regression test.  ORACLE RULE: every
  negative test must be shown to REJECT for the intended reason
  (print the error tag and the message), and every positive test must
  pin an exact value, an exact line, or an exact exit code.  Never
  assert on absent output where an exit status is available.
- Marshal-format checklist: any change to `Term.t`, `Value.t`,
  `Eterm.t`, `Global.entry`, `Interp.v`, `Interp.gentry` or `Prim.t`
  bumps `Cache.format_version`.  Pin 15 says M6 owns NO bump.  A stage
  that believes it needs one has found a conflict;  section 5 applies.

## 3. The stage chain and the exit arithmetic

Five stages, strictly ordered, each exiting at GATE-EXIT=0, 0 FAIL,
with a stated PASS target chaining from 334 (pin 18).  The per-stage
numbers below are copied from the verdict's STAGE ALLOCATION section
and recomputed by this plan's writer;  both computations agree.

| Stage | Contents (pins) | Retires | Adds | Exit arithmetic |
| --- | --- | --- | --- | --- |
| A | WF deletion, full perimeter;  WF oracle preservation;  fence tripwires (pins 7-10);  corpus 80 -> 85, transcript resealed (pin 14) | PASS-M5E-ACC-CHECKS (-1 marker);  kernel E1 (-1 test;  E2 converts to a Structural rejection, count neutral) | 7 markers | 334 - 1 - 1 + 7 = 339 |
| B | blocking Unit posture (pins 5-6), driver and serror change only | nothing | 4 markers, 2 surface tests | 339 + 4 + 2 = 345 |
| C | holes core (pins 1-4), `_` reservation with its three before-picture negatives | nothing | 5 markers, about 10 suite tests | 345 + 5 + 10 = 360 |
| D | the two cost legs (pins 11-13), PASS-M5D-MEASURE-LOG literal extended in the same commit | nothing | 5 markers | 360 + 5 = 365 |
| E | corpus growth and reseal (pins 4, 14, scope items 7-8):  rewrap scrubber port, example E anchors re-spelled, classifier re-run, second reseal | nothing | 5 markers | 365 + 5 = 370 |

Cross-check: 26 new markers + 12 new tests - 2 retirements = +36;
334 + 36 = 370.  Kernel suite: 106 -> 105 at Stage A (E1 retires, E2
converts) and 105 thereafter, plus Stage C's suite additions where
that stage's section places them.  Target at M6 exit: about 370 PASS,
0 FAIL.  Counts may drift by one or two per stage;  the monotone walk,
the marker names and GATE-EXIT=0 at every boundary are the binding
part.

Reserved markers, 26, one namespace letter per stage (pin 16).  A
stage ships exactly its reserved names;  a stage that needs one more
adds it under its own letter and records the addition in
`dev/M6-BUILD-LOG.md`.

- Stage A (7): PASS-M6A-WF-FLAG-UNKNOWN, PASS-M6A-ACC-GUARD-REJECTED,
  PASS-M6A-INFINITARY-REJECTED, PASS-M6A-CROSSFORMAL-REJECTED,
  PASS-M6A-DEEP2-REJECTED, PASS-M6A-FENCE-COVARIANT,
  PASS-M6A-FENCE-CONTRAVARIANT.  Stage A also REWRITES
  PASS-M5E-WITNESS-REJECTED flag-free (its leg (a) dies with the
  flag;  count neutral) and keeps PASS-M5E-DEFAULT-IDENTITY on the
  resealed transcript.
- Stage B (4): PASS-M6B-UNIT-STRICT-EXIT2, PASS-M6B-UNIT-STRICT-NOMAP,
  PASS-M6B-VERDICT-STRICT-IDENTITY, PASS-M6B-OPEN-IDENTITY.
- Stage C (5): PASS-M6C-HOLE-RESOLVES, PASS-M6C-HOLE-REPORTS,
  PASS-M6C-HOLE-NEVER-RUNS, PASS-M6C-UNDERSCORE-RESERVED,
  PASS-M6C-DEFAULT-IDENTITY.
- Stage D (5): PASS-M6D-HIT-BASELINE, PASS-M6D-HIT-RATIO,
  PASS-M6D-COLD-WINDOW, PASS-M6D-COLD-STORE,
  PASS-M6D-COLD-OUTSIDE-BUDGET.
- Stage E (5): PASS-M6E-REWRAP-SCRUB, PASS-M6E-REWRAP-OPEN,
  PASS-M6E-ANCHORS, PASS-M6E-GUARD-HOLES,
  PASS-M6E-TRANSCRIPT-RESEALED.

Transcript discipline across the chain (pin 14):
`dev/gen-m5e-transcript.sh` globs examples/*.tot and
test/fixtures/*.tot (80 files at HEAD, probe P8), so EVERY stage that
adds or edits a file in either directory regenerates
`dev/m5e-default-transcript.txt` in the same commit, diffs old against
new, reviews the diff (added files and enumerated verdict changes
only), and records the file count in its SPEC entry.
PASS-M5E-DEFAULT-IDENTITY stays the enforcement point between stages.
This is the discipline whose absence broke two of the three panel
walks on paper;  it is not optional.

## 4. Standing rules: cross-cutting pins 15 to 18

### 4.1 Pin 15: cache discipline

`Cache.format_version` stays 10 (surface/cache.ml:118, read at HEAD)
for the WHOLE milestone.  Holes never enter kernel terms (pin 1),
driver policy never enters the cache key, and no prelude source edit
ships.  Any change that would touch a cached shape is REDESIGNED, not
version-bumped.  A stage that believes it needs a bump has found a
conflict;  section 5 applies and the answer is expected to be no.

### 4.2 Pin 16: marker namespace

All M6 markers live under `PASS-M6[A-E]-*`.  The namespace is free at
HEAD, probed 2026-09-03:

    rg -c "PASS-M6" /Users/oobi/Documents/tot/dev/gates.sh
    (no output)
    rg exit=1

The oracle is asserted on EXIT STATUS 1 (zero matches), not on a
printed 0:  `rg -c` prints nothing at all when there is no match (see
conflict note C-P1).  For the record, the existing namespace holds 69
distinct PASS-M4*/PASS-M5* markers (probe P9;  the often-quoted 46
excludes the 23 PASS-M4FIX-* markers), plus legacy PASS-A/B/C/D-*;
none collide with PASS-M6.  Do not reuse or edit an existing marker
name except where Stage A's section explicitly rewrites or retires an
M5E leg.

### 4.3 Pin 17: count honesty

Every rg- or script-derived count in M6 documents and gate comments
ships WITH the exact command that produced it, and re-running the
command must reproduce the number.  The M6 panel caught four dead
counts in one proposal (a 169-line classifier output that is 148;  six
serror matches that are seven;  46 markers that are 69;  a citation 86
lines adrift);  the M5 panel killed a pin the same way.
`dev/M6-BUILD-LOG.md` records each count as command plus output,
verbatim.  This preamble practices the rule: every count above carries
its command.

### 4.4 Pin 18: walk discipline

Every stage exits GATE-EXIT=0, 0 FAIL, at a stated PASS target
chaining from 334 (section 3 table).  Mutation proofs flip then
restore md5-identical, on the dev/M5-BUILD-LOG.md:1549-1593 template
(section 6).  Every design decision becomes a dated SPEC section 2
entry.  The user commits;  nothing lands committed, or even staged,
by a stage agent (section 2).

## 5. Conflict-resolution protocol

A stage section may find that a pin disagrees with the repo.  When
that happens, follow this protocol exactly.

1. Re-run the claim against the built binary or read the cited lines.
   Do not resolve a conflict from memory or from the verdict text.
2. Record a DATED conflict note in the stage section itself, in the
   form `Conflict note C<n> (YYYY-MM-DD): <pin> says X;  the repo at
   <file:line> shows Y;  resolution: Z`.
3. Report the note in the stage's return value and in
   `dev/M6-BUILD-LOG.md`.
4. The pin list WINS, unless the repo PROVES the pin impossible.
   "Impossible" means an executed probe, a compiler error, or a cited
   line, and never an opinion about design.  Where the repo proves the
   pin impossible, the pin's INTENT survives and only its mechanism
   changes.  Record both halves.
5. A conflict never silently shrinks a gate.  If a mutation proof
   cannot be built as written, replace the mutation, prove the flip,
   and say so.  Do not drop the leg.

Two conflicts are already resolved here.  A stage section inherits
these resolutions and does not re-litigate them.

**Conflict note C-P1 (2026-09-03): the no-collision oracle cannot
print 0.**  The stage-walk ground rule was circulated as
"`rg -c "PASS-M6" dev/gates.sh` must be 0 at HEAD".  Probed:  on zero
matches `rg -c` prints NOTHING and exits 1 (section 4.2 transcript).
The verdict's own pin 16 already states the exit-1 form.  Resolution:
the oracle is the COMMAND above asserted on exit status 1;  the pin's
intent (the namespace is free) is kept whole.  Any gate leg that
guards the namespace asserts on exit status, never on a printed
count.

**Conflict note C-P2 (2026-09-03): one verdict citation is one line
adrift.**  The verdict cites "A tier is a HANG ceiling, not a
performance budget" at dev/gates.sh:31;  at `8d5a839` the sentence
sits at dev/gates.sh:30 (read this session;  section 1.4).  Resolution:
this plan cites dev/gates.sh:30;  the content is byte-identical and no
pin moves.

## 6. The mutation-proof protocol

Every new gate leg ships with a MUTATION PROOF.  A leg with no proof
is not a gate, and the stage is not green.  The template is
dev/M5-BUILD-LOG.md:1549-1593, and the proof has three parts, all
required, all recorded in `dev/M6-BUILD-LOG.md`:

1. The exact mutation, as a file, a line and the replacement text.
2. The observed flip: the leg's marker before the mutation, and the
   FAIL marker with its exit code after it, arriving by the PREDICTED
   route.
3. The restore: the source md5 before and after, proving the tree
   returned to its pre-mutation bytes.

A mutation that does not flip the leg REFUTES the leg.  When that
happens, replace the mutation or replace the leg, and record which.
Do not report a leg as proved because a DIFFERENT mutation flipped
it.  A mutation that does not COMPILE proves nothing;  replace it with
one that builds, as M5's WITNESS-REJECTED M3 record shows.

Each stage section pins its own mutations in the table format below.
Two mutations are pinned at milestone level by the verdict, both
Stage D, because each one closes a vacuity the panel caught:

| Mutation | Predicted flip route | Restore proof |
| --- | --- | --- |
| lib/check.ml:770-773: the memo HIT re-derives instead of returning the cached `e_val` (the M5 M9 mutation re-run against the new leg) | PASS-M6D-HIT-RATIO goes RED: median(t_many)/median(t_one) rises from the healthy 1.28 to near 8, over the 4.0 oracle (R4);  PASS-M6D-HIT-BASELINE and every FAST leg stay green, proving the ratio leg and not a crash carries the detection | md5 of lib/check.ml identical before and after;  rebuild;  leg PASS |
| bin/tot.ml:42-47: start the budget clock before prelude bootstrap (the C-C6 deadline-hoist), run against a >1024-node target at `--check-budget-ms 1` | PASS-M6D-COLD-OUTSIDE-BUDGET goes RED: the cold run exits 3 with the budget line instead of 0.  The target MUST exceed 1024 kernel nodes:  the throttle at bin/tot.ml:46 reads the deadline every 1024th poll, so a trivial target never observes the hoist (C-C6, dev/M5-BUILD-LOG.md:833-846, did not flip 5 of 5), and the attack probed that bigcheck.tot flips to exit 3 at budget 1 | md5 of bin/tot.ml identical before and after;  rebuild;  leg PASS |

A mutation hook that cannot fire is a vacuous oracle.  The
>1024-node rule above is the standing example;  apply the same test
(can this mutation reach this leg's code path at all?) to every
mutation you pin.

## 7. Watchdog tier discipline

Every gate leg names a tier: FAST=10, MED=30, SLOW=120, SUITE=300
(dev/gates.sh:44-48, read at HEAD).  No numeric watchdog literal may
appear in a leg;  the M5 oracle
`rg -c '"\$watchdog" [0-9]+' dev/gates.sh`, asserted on exit status,
is green at HEAD (probe P6) and must stay green through every M6
stage.  BITE_S is the calibration constant for PASS-M5D-TIER-BITES
and nothing else may use it.  "A tier is a HANG ceiling, not a
performance budget" (dev/gates.sh:30):  a leg that creeps in cost
stays green at its tier and shows up in the measurement log.  M6
ships exactly two purpose-built ratio/schema legs (Stage D) and NO
general perf-regression tier.

Every new gate_timed leg is placed DOWNSTREAM of PASS-M5D-MEASURE-LOG,
and in the same commit that gate's literal line count and name set are
extended to cover the new legs, keeping the two branching legs the
file's tail (pin 13).  No M6 leg re-derives the count from call
sites.

New legs are written in the file's capture-then-assert idiom, exactly
as at HEAD (the model is PASS-M5E-ACC-CHECKS, dev/gates.sh:2440-2446):
capture output and exit code under a named tier, assert on exact
values, echo the PASS marker on success, and have the FAIL branch
replay the captured output and exit 1.  The M6 house template, binding
for every new leg (loop-free, tier named, marker echoed by the leg's
final compound statement):

    # Gate <letter> (<n>), PASS-M6<letter>-<NAME>. <One-sentence oracle
    # statement; the measurement recipe when a number is asserted;
    # the mutation that proves the leg, by name>.
    out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
      "$ROOT"/test/fixtures/m6x-example.tot 2>&1)
    code=$?
    want='m6x-example.tot:3:7: hole: expected Nat'
    { [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$want"; } \
      && echo PASS-M6X-EXAMPLE \
      || { printf '%s\n' "$out"; echo "FAIL-M6X-EXAMPLE (exit=$code)"; exit 1; }

Never assert on "no error", and never assert on absent output where
an exit status is available:  an oracle that matches nothing passes
for the wrong reason.

## 8. Known debts entering M7

Copied from the ratified verdict and verified line by line against
SPEC at HEAD on 2026-09-03 (anchors in section 1.4).  Stage D/E write
these into SPEC section 6 as the M7 debts list;  none of them is M6
scope.

- The WF package, sized together as ONE unit: a sound admission rule
  whose side condition carries PROVENANCE (the pin-9 seed invariant,
  lib/totality.ml:184-186), the erased elimination form for `Acc`
  plus `Frozen_rec` (SPEC.md:1111-1112 couples them), and the
  indexed-relation quantity story (SPEC.md:1092-1101), all against
  the pin-9 oracle fixtures.
- Argument-driven holes: bidirectional application checking in
  `check` for the 9 A anchors, 4 of them in the guards themselves;
  `check` has no App arm today (lib/check.ml:1208-1211).
- Prelude re-spelling: the 40 prelude E anchors (probe P4), after a
  milestone of hole soak.
- Nested and mutual inductives over the UNPROVEN `Frozen` emptiness
  claim (SPEC.md:851-853, 1615-1619), entered through the pin-10
  fence tripwires, which are DESIGNED to go red the day nesting
  lands.
- The lib/ .mli sweep (17 modules, 2 done: `Level`, `Budget`;  probe
  P10, SPEC.md:1351-1352) and then surface/.
- Multi-hole reporting and elaborator error recovery beyond the M6
  structured-error slice (SPEC.md:1356-1358 names the revisit
  trigger).
- Cumulativity or an `Eq1` layer, on first measured demand
  (SPEC.md:1603-1610).
- The guard tokenizer duplication (examples/guard-rewrap.tot:24-29)
  and vendoring the Apache license text (SPEC.md:1355).
- The instance-body dead threading: `define_instance` passes `~rule`
  but no `~rec_` (lib/check.ml:1762-1773), so the guard never runs on
  instance bodies;  M7 decides whether instances gain a real `rec_`
  story or the threading is simplified.

The "4 in the guards themselves" figure is verified at HEAD:
`python3 dev/hole-anchors.py | rg '^SITE examples/guard.*bucket=A$'`
prints exactly four rows, guard.tot:133 and :134 plus
guard-rewrap.tot:162 and :163, all `head=bindIO arg=0`.  Stage E
re-runs the classifier after the corpus grows and records the new
split with its command.

## 9. Deliberate non-changes

Stated once so no stage carves its own exceptions.  Each item is OUT
of M6 scope by ratified verdict, and a stage that touches one has
found a conflict (section 5).

1. WF promotion.  The one drafted side condition checks the wrong
   endpoint;  the sound version is coupled to three unsized items
   (SPEC.md:1111-1112, 1092-1101).  M7 takes it as a package against
   the pin-9 oracles.  M6 DELETES the flag (R1).
2. Nested and mutual inductives.  Sits over the UNPROVEN `Frozen`
   emptiness claim (SPEC.md:851-853, 1615-1619);  the pin-10 tripwires
   force a conscious re-open.
3. Universe polymorphism and cumulativity.  No measured demand
   (SPEC.md:1603-1610).
4. Argument-driven holes (the 9 A anchors).  Need bidirectional
   application checking;  `check` has no App arm
   (lib/check.ml:1208-1211).
5. Prelude re-spelling (the 40 prelude E anchors).  Bootstrap and
   cache blast radius;  M7 after a milestone of soak.  NO prelude
   source edit ships in M6 (pin 15).
6. A general perf-regression tier.  "A tier is a HANG ceiling, not a
   performance budget" (dev/gates.sh:30) stands;  M6 ships two
   purpose-built legs only.
7. The lib/ .mli sweep.  Freezing kernel signatures in the same
   milestone that adds elaborator surface invites double churn;  M7.
8. A second budget for the cold bootstrap.  The external timeout belt
   owns the window.
9. The Verdict envelope shapes and the default fail-open posture:
   untouched BYTE-IDENTICALLY (pin 6).  Both before-pictures become
   identity markers in Stage B.
10. `Cache.format_version` stays 10;  `Term.t` gains no constructor;
    `type rule` survives single-constructor with `Check.define`'s
    REQUIRED `~rule` argument (lib/check.ml:1464-1466), so an M7 rule
    re-enters by compiler error at every call site (pin 8).

## 10. Completion checklist

The MAIN LOOP walks this list at build completion, in order.  Nothing
here is a stage agent's job except handing over a green tree.

- [ ] Stages A..E each exited GATE-EXIT=0, 0 FAIL, and the recorded
      walk chains 334 -> 339 -> 345 -> 360 -> 365 -> 370 within the
      allowed one-or-two drift per stage, monotone.
- [ ] Final full battery on the finished tree (section 1.2 commands):
      GATE-EXIT=0;  `rg -c '^PASS' "$TMPDIR/tot-gate.out"` at the
      recorded final total;  `rg -c '^FAIL' "$TMPDIR/tot-gate.out"`
      exits 1 with no output.
- [ ] All 26 reserved markers present:
      `rg -o 'PASS-M6[A-E]-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | sort -u | wc -l`
      = 26, and the per-stage names match section 3 exactly.
- [ ] The M5 oracles still green: the watchdog-literal oracle (probe
      P6) and PASS-M5E-DEFAULT-IDENTITY on the final resealed
      transcript.
- [ ] PASS-M5D-MEASURE-LOG's literal count and name set cover every
      new gate_timed leg, extended in the same commits that added
      them (pin 13).
- [ ] Every pin has its dated 2026-09-0X SPEC section 2 entry;  SPEC
      section 6 is rewritten with post-M6 numbers;  the debts list
      matches section 8 of this preamble.
- [ ] `dev/M6-BUILD-LOG.md` holds every stage report, every mutation
      proof with flip and md5-identical restore, every count with its
      command, and every conflict note.
- [ ] The tree is COMPLETE and UNSTAGED;  `git status --porcelain`
      output recorded.  Only now the MAIN LOOP runs
      `git add -A` in `/Users/oobi/Documents/tot`.
- [ ] Review rounds run over the STAGED diff (ctxcat-review with a
      precomputed index, plus one logic-lens pass), repeated to
      convergence as in the M5 close-out;  fixes land, restage, rerun
      the battery if any fix touched lib/, surface/, bin/, test/ or a
      gate oracle.
- [ ] The USER commits.  No agent commits, ever.

## STAGE A: WF deletion plus WF oracle preservation (pins 7-10)

Goal: delete `--experimental-wf` and the `Structural_wf` prototype
across the whole pin-7 perimeter, in one stage, per ruling R1 of the
ratification block (2026-09-03).  Nothing on the default path changes
by one byte.  The WF negative oracles survive the flag as flag-free
fixtures (pin 9), extended by three new negatives (bad2,
crossformal-t, deep2) and two positivity-fence tripwires (pin 10), so
the M7 WF package inherits executable oracles, not memories.  `type
rule` collapses to a single-constructor type and every `~rule`
threading stays, so the M7 rule re-enters by compiler error (pin 8).

Entry: M5 HEAD 8d5a839, 334 PASS / 0 FAIL, decomposed 106 kernel +
107 surface + 121 gate markers (dev/M5-BUILD-LOG.md:1671-1674).
Cache `format_version` 10 (surface/cache.ml:118).  Stage A goes first
for two reasons.  It is pure deletion plus oracle work, independent
of stages B through E.  And pin 14's transcript discipline makes the
five new fixtures a same-commit reseal, which every later stage that
touches examples/ or test/fixtures/ then inherits as settled
procedure rather than as its own first attempt.

Rationale for the stage boundary: every change below deletes driver
or kernel-policy plumbing, converts tests, or adds fixtures and gate
legs.  No change touches `Term.t`, no change touches a `Global` entry
shape, no change touches elaboration output, and the prelude
bootstrap already folds with `default_policy`
(surface/run.ml:44-47), so no flag ever entered the cache key.
`Cache.format_version` stays 10 (pin 15).

Files: `bin/tot.ml`, `surface/run.ml`, `lib/totality.ml`,
`lib/check.ml` (doc text plus one comment), `test/main.ml`,
`test/surface.ml`, `test/fixtures/` (five NEW files),
`dev/m5e-default-transcript.txt` (REGENERATED),
`dev/gates.sh`, `SPEC.md`.  NOT touched: `dev/gen-m5e-transcript.sh`
(the glob picks the new fixtures up), `stdlib/prelude.tot`,
`examples/`, `surface/cache.ml`.

---

### A0. Entry state, measured against the built binary

Every row below is a PROBE result, not a reading.  The runner is
`/Users/oobi/Documents/tot-m6-probes/plan-stage-a/run-probes.sh`
(loop-free zsh), the binary is
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe` at HEAD
8d5a839 with `TOT_PRELUDE=stdlib/prelude.tot`, run 2026-09-03.  Rows
are numbered `P1` and so on; they are probe IDs local to this
section, never pins.  Stage A implements pins 7, 8, 9, 10 and obeys
pins 14, 15, 16, 17, 18.

| # | Probe | Command | Measured 2026-09-03 |
|---|---|---|---|
| P1 | acc fixture, no flag | `tot.exe check test/fixtures/m5e-acc.tot` | exit 1, one line `m5e-acc.tot:5:1: recursive definition accRec failed the structural termination guard` |
| P2 | acc fixture, flagged | `tot.exe check --experimental-wf test/fixtures/m5e-acc.tot` | exit 0, five pinned lines (`data Acc ...` through `def accZero ...`) |
| P3 | witness, no flag | `tot.exe check test/fixtures/m5e-witness.tot` | exit 1, `m5e-witness.tot:2:1: recursive definition bad failed the structural termination guard` |
| P4 | witness, flagged | same, `--experimental-wf` | exit 1, stderr byte-identical to P3 (`cmp` clean) |
| P5 | bad2, no flag | `tot.exe check bad2.tot` | exit 1, `bad2.tot:2:1: recursive definition bad2 failed the structural termination guard` |
| P6 | bad2, flagged | same, `--experimental-wf` | **exit 0**, three lines `data T` / `ctor mk : (w _ : (w _ : Nat) -> T) -> T` / `def bad2 : (w _ : T) -> Nat` |
| P7 | crossformal-t, no flag | `tot.exe check crossformal-t.tot` | exit 1, `crossformal-t.tot:2:1: recursive definition bad failed the structural termination guard` |
| P8 | crossformal-t, flagged | same, `--experimental-wf` | exit 1, same line: the prototype clause alone does NOT admit it |
| P9 | deep2, no flag | `tot.exe check deep2.tot` | exit 1, `deep2.tot:2:1: recursive definition deep2 failed the structural termination guard` |
| P10 | deep2, flagged | same, `--experimental-wf` | exit 1, same line: depth-2 field application stays out even under the flag |
| P11 | nested-pos | `tot.exe check nested-pos.tot` | exit 1, `nested-pos.tot:2:1: invalid constructor mkt2: negative or non-uniform occurrence of T2` |
| P12 | nested-neg | `tot.exe check nested-neg.tot` | exit 1, `nested-neg.tot:2:1: invalid constructor mkt3: negative or non-uniform occurrence of T3` |
| P13 | unknown-flag contract | `tot.exe check --experimental-wfz test/fixtures/m5e-acc.tot` | exit 2, one stderr line `unknown flag: --experimental-wfz`, stdout empty |
| P14 | transcript identity | `zsh dev/gen-m5e-transcript.sh > now.txt; diff dev/m5e-default-transcript.txt now.txt` | gen exit 0, diff exit 0 (byte-identical), 9660 lines |
| P15 | corpus size | `ls examples/*.tot \| wc -l` and `ls test/fixtures/*.tot \| wc -l` | 6 and 74, total 80 |

Probe transcript excerpts, verbatim from the runner:

    == P6 bad2 under flag ==
    data T : Type 0
    ctor mk : (w _ : (w _ : Nat) -> T) -> T
    def bad2 : (w _ : T) -> Nat
    exit=0
    == P8 crossformal-t under flag ==
    /Users/oobi/Documents/tot-m6-probes/plan-stage-a/crossformal-t.tot:2:1: recursive definition bad failed the structural termination guard
    exit=1
    == P13 unknown-flag contract (stderr, exit) ==
    unknown flag: --experimental-wfz
    exit=2

P6 is the stage's motivation in one probe: the flag admits infinitary
structural recursion TODAY, exactly as SPEC.md:1062-1063 records
("The prototype is KNOWN to be too permissive; it exists to be
measured, not to be relied on, and M6 either promotes it or deletes
it").  P8 and P10 are the differential that makes the crossformal and
deep2 gates worth their legs: both files are rejected even UNDER the
flag, so those two markers pin invariants STRONGER than flag
deletion, namely the per-candidate seed (lib/totality.ml:184-187)
and the Var-only scrutinee rule (lib/totality.ml:153-165).  P13 pins
the contract the deleted spelling inherits (bin/tot.ml:277-278).
P14 proves the committed transcript is green at entry, so any Stage A
diff against it is attributable to Stage A alone.

Counts, each with its exact reproducing command (pin 17), all run
2026-09-03 at HEAD:

    rg -c '~rule:Totality\.Structural' test/main.ml        # 32 (lines)
    rg -c '~rule:Totality\.Structural\b' test/main.ml      # 30
    rg -c '~rule:Totality\.Structural_wf' test/main.ml     # 2
    rg -c '~rule' test/main.ml                             # 33
    rg -c 'wf_rule' test/surface.ml                        # 3
    rg -c 'PASS-M6' dev/gates.sh                           # no match, exit 1 (pin 16 clean)
    rg -c 'PASS-M5E' dev/gates.sh                          # 6 (3 comment + 3 echo lines)
    rg -c 'Structural_wf' lib/totality.ml lib/check.ml surface/run.ml bin/tot.ml
                                                           # 5, 1, 1, 1
    rg -n 'Structural_wf' test/main.ml                     # 6 lines: 2827, 2831, 2832, 2837, 3072, 3073
    wc -l dev/m5e-default-transcript.txt                   # 9660
    rg -c '^### ' dev/m5e-default-transcript.txt           # 80

See conflict note C-A1 for the 32-versus-30 decomposition.

---

### A1. bin/tot.ml: the flag dies

Four deletions and one shrink, all in the driver.  The unknown-flag
arm at bin/tot.ml:277-278 is NOT touched; after the deletions the
spelling `--experimental-wf` falls through to it and takes the pinned
contract (probe P13): one stderr line, exit 2, stdout empty.

Step 1.  Delete the `experimental_wf` field of `opts`
(bin/tot.ml:224-228, the field plus its doc comment) and its default
(bin/tot.ml:239, `experimental_wf = false;`).

Step 2.  The usage string (bin/tot.ml:242-245) loses
`[--experimental-wf] `.  After the edit:

```ocaml
let usage : string =
  "usage: tot (check|run) [--no-prelude] [--no-axioms] [--serror-exit N] \
   [--check-budget-ms N] [--require-main] [--strict-json] FILE | tot \
   prims"
```

The exact-line pin at test/surface.ml:412-415 moves WITH it in the
same commit (A6 step 1), the same discipline every M5 flag followed
(test/surface.ml:405-411 records the chain).

Step 3.  Delete the parse arm (bin/tot.ml:257):

```ocaml
  | "--experimental-wf" :: rest -> parse_flags { opts with experimental_wf = true } rest
```

Step 4.  `dispatch` (bin/tot.ml:281-291) loses the `wf_rule`
computation (287-289) because `Run.policy` loses the field (A2).
After the edit:

```ocaml
let dispatch ~(exec : bool) (opts : opts) (path : string) : int =
  let policy : Tot_surface.Run.policy =
    {
      Tot_surface.Run.no_axioms = opts.no_axioms;
      require_main = opts.require_main;
      strict_json = opts.strict_json;
    }
  in
```

After this file's edits, `rg -c 'experimental' bin/tot.ml` (5 lines
at HEAD) must print no match and exit 1.

---

### A2. surface/run.ml: the policy loses `wf_rule`

Step 1.  Delete the `wf_rule` field and its doc comment
(surface/run.ml:40-47).  The doc's one load-bearing sentence ("The
prelude bootstrap folds with [default_policy], so a prelude [def rec]
is never checked under the prototype and no flag can enter the cache
key") is re-homed into the SPEC entry (A11 entry 1), because it is
the reason pin 15 holds trivially for this stage.

Step 2.  `default_policy` (surface/run.ml:50-51) drops the field:

```ocaml
let default_policy : policy =
  { no_axioms = false; require_main = false; strict_json = false }
```

Step 3.  The one user-def `Check.define` call site
(surface/run.ml:243) names the shipped rule literally, exactly as
`define_instance` already does at lib/check.ml:1772:

```ocaml
      let* globals =
        kernel loc
          (* M6 Stage A (pin 8): the single shipped rule, named
             literally.  [Check.define]'s REQUIRED [~rule] stays, so
             an M7 rule re-enters by compiler error at this site. *)
          (Check.define ~rec_ ~partial ~budget ~rule:Totality.Structural st.globals ~name
             ~reducible ~ty:ty_t ~def:def_t)
      in
```

---

### A3. lib/totality.ml: `type rule` collapses, the App arm returns to M2

Step 1.  The type (lib/totality.ml:8-15) collapses to a
single-constructor type.  This is the pin-8 decision, stated in the
code where the M7 author will meet it:

```ocaml
(** M6 Stage A (verdict pin 8, ruling R1): the totality rule [guard]
    runs.  A single-constructor type ON PURPOSE.  [Check.define]
    keeps its REQUIRED named [~rule] argument, every call site names
    [Structural], and every match on [rule] is exhaustive with no
    wildcard, so an M7 admission rule (the WF package) re-enters by
    compiler error at every consumer.  The M5 [Structural_wf] spike
    is DELETED, not dark: re-entry is a rebuild of the [Term.App] arm
    of [guarded_call] below, against the pin-9 oracle fixtures
    (test/fixtures/bad2.tot, crossformal-t.tot, deep2.tot), and any
    such rule must carry a PROVENANCE side condition tying the
    Smaller head to the candidate position (the seed invariant, SPEC
    section 2 entry dated 2026-09-03). *)
type rule = Structural
```

Step 2.  The `Term.App` arm of `guarded_call`
(lib/totality.ml:97-115) collapses.  The match on `rule` is KEPT so
the collapse cannot orphan the parameter (the M5 mutation record
proved an orphaned computation is a compile error, not a flip:
dev/M5-BUILD-LOG.md:1574-1578) and so the M7 rule lands exactly here
by non-exhaustiveness:

```ocaml
           | Term.App (_, _, _) -> (
               (* M6 Stage A: the M5 spike's accessibility clause is
                  deleted (ruling R1).  A call whose argument [k] is
                  an APPLICATION is never guarded, which is the M2
                  rule byte for byte.  The match on [rule] is kept so
                  the M7 rule re-enters HERE by non-exhaustiveness. *)
               match rule with
               | Structural -> false)
```

Step 3.  Rewrite the two doc comments that name the flag: the type's
header (covered by step 1) and `guard`'s (lib/totality.ml:189-193),
which becomes a one-sentence description of the single rule plus a
pointer to the pin-8 re-entry story.

NOT touched, and load-bearing for the identity oracle: `peel`,
`spine`, `mentions`, `status_at`, the whole `ok` walk including the
Var-only `scrut_special` (lib/totality.ml:153-165), and the seed
(lib/totality.ml:184-187).  The `Structural` path of `passes` is
byte-identical before and after; PASS-M5E-DEFAULT-IDENTITY is the
oracle that proves it (A9).

After this file's edits, `rg -c 'Structural_wf' lib/totality.ml` (5
at HEAD) must print no match and exit 1, and `spine` keeps exactly
one caller inside `passes` (the `ok` App arm at
lib/totality.ml:133).

---

### A4. lib/check.ml: two doc rewrites, zero code changes

Step 1.  The `[rule]` doc block above `define`
(lib/check.ml:1459-1463) drops the flag sentence and states the
pin-8 posture: `~rule` is REQUIRED so the compiler enumerates every
call site; the single constructor is the shipped rule; M7 re-enters
by adding a constructor.

Step 2.  The `define_instance` comment (lib/check.ml:1769-1771,
"M5 Stage E: an instance body is never a [def rec] ...") is
rewritten as the pin-8 dead-spot record: instance bodies pass
`~rule` but no `~rec_` (lib/check.ml:1762-1773 passes neither
`~rec_` nor could the guard run), so the threading there is inert
plumbing, not a live gate; M7 decides whether instances gain a real
`rec_` story or the threading simplifies (verdict, Known debts).

NOT touched: the `define` signature (lib/check.ml:1464-1467) with
its required `~(rule : Totality.rule)`; the guard call under `rec_`
(lib/check.ml:1546-1550, `Totality.guard ~rule ~recname:name def'`);
the literal `~rule:Totality.Structural` at lib/check.ml:1772.

---

### A5. test/main.ml: E1 retires, E2 converts (kernel 106 -> 105)

The kernel suite carries two direct `Structural_wf` cases, E1 and E2
(bodies at test/main.ml:2825-2834 and 2836-2838, registered at
3072-3073).  The constructor is gone, so both must change; the
verdict retires E1 and converts E2 (stage allocation, "E1 retires,
E2 converts (106 -> 105, -1)").

Step 1.  Delete `case_m5e_wf_accepts_acc_rec`
(test/main.ml:2825-2834) and its registration (test/main.ml:3072).

Step 2.  Convert `case_m5e_wf_still_rejects_witness`
(test/main.ml:2836-2838) into the shipped-rule rejection case.  E1's
no-flag half (Structural rejects accRec) moves in, so the term
builder `m5e_acc_rec_body` (test/main.ml:2740) stays consumed and no
unused-value warning appears:

```ocaml
(* M6 Stage A (verdict pin 9): E1 (Structural_wf accepts accRec)
   retired with the deleted constructor.  Its no-flag half moved
   here, so [m5e_acc_rec_body] stays a live negative: the shipped
   rule must reject BOTH prototype-era shapes, pinned by tag and by
   rendered message via [m5e_expect_termination]. *)
let case_m5e_shipped_rule_rejects () : (unit, string) result =
  let* () =
    m5e_expect_termination "E2 (accRec)" ~rule:Totality.Structural "accRec" m5e_acc_rec_body
  in
  m5e_expect_termination "E2 (witness)" ~rule:Totality.Structural "bad" m5e_bad_body
```

Registration (replaces test/main.ml:3072-3073, two lines become
one):

```ocaml
    ("E2: the shipped rule rejects accRec and the panel witness", case_m5e_shipped_rule_rejects);
```

Step 3.  `m5e_expect_termination` (test/main.ml:2808-2823) keeps its
`~rule` parameter unchanged; it now ranges over the one constructor.
The 30 word-bounded `~rule:Totality.Structural` literals elsewhere
in the file (command in A0) are byte-unchanged; they now name the
single constructor.

Kernel suite: 106 -> 105.  After the edits,
`rg -c 'Structural_wf' test/main.ml` (6 lines at HEAD) must print no
match and exit 1.

---

### A6. test/surface.ml: the usage pin and three policy literals

Step 1.  The usage-line pin (test/surface.ml:412-415) loses
`[--experimental-wf] `, matching A1 step 2 byte for byte, and the
case comment (test/surface.ml:405-411) gains one line: "M6 Stage A:
it LOST [--experimental-wf] (ruling R1), same discipline."

Step 2.  The three `Run.policy` record literals at
test/surface.ml:442, 756 and 1625 each delete their one line
`wf_rule = Tot_kernel.Totality.Structural;`.  The field is gone from
the record type (A2 step 1), so a missed literal is a compile error,
which is the pin-8 enumeration working in miniature.  See conflict
note C-A2 for the verdict wording this resolves.

Surface suite count unchanged: 107.  After the edits,
`rg -c 'wf_rule' test/surface.ml` (3 at HEAD) must print no match
and exit 1, and `rg -c 'experimental' test/surface.ml` likewise.

---

### A7. Stage A fixtures (complete list)

Five NEW files in test/fixtures/, named exactly as the verdict names
them (stage allocation: "lands bad2.tot, crossformal-t.tot,
deep2.tot, nested-pos.tot, nested-neg.tot in test/fixtures").
Corpus 80 -> 85.  Every file keeps its declarations FIRST and its
comment block BELOW them, the m5e fixture convention
(test/fixtures/m5e-acc.tot:16-21 states why): the gate legs pin
`file:LINE:COL` prefixes, so the error-bearing declaration must hold
its line.  Every expected line below is probed (A0), not predicted.

**test/fixtures/bad2.tot** (probes P5, P6):

```
data T : Type 0 := | mk : (Nat -> T) -> T
def rec bad2 : T -> Nat := fun t => match t with | mk g => bad2 (g zero) end
-- M6 Stage A fixture (verdict pin 9): infinitary structural
-- recursion over a VARIABLE scrutinee, the row the M5 panel did not
-- state (dev/M5-BUILD-LOG.md:1513-1516).  At M5 HEAD this file was
-- ACCEPTED under --experimental-wf (probe P6: exit 0) because the
-- prototype clause inspected the head's status, never the field's
-- type.  Flag-free it is rejected at bad2.tot:2:1, and after the M6
-- deletion that rejection is the only behaviour.  Gate
-- PASS-M6A-INFINITARY-REJECTED pins it; bad2 must stay at line 2
-- column 1.
```

Expected: exit 1, line
`bad2.tot:2:1: recursive definition bad2 failed the structural termination guard`.

**test/fixtures/crossformal-t.tot** (probes P7, P8):

```
data T : Type 0 := | tleaf : T | mkT : (Nat -> T) -> T
def rec bad : T -> T -> Nat :=
  fun a b => match b with | tleaf => zero | mkT g => bad (g zero) b end
-- M6 Stage A fixture (verdict pin 9): the wrong-endpoint witness
-- from the M6 panel.  Candidate formal a : T; g is a field of the
-- NON-candidate b : T; the call descends on nothing.  Rejected at
-- HEAD in BOTH modes (probes P7/P8), so what keeps it out is the
-- per-candidate Principal seed in Totality.passes, not the deleted
-- flag.  Any future admission rule (lexicographic descent included)
-- must carry a provenance side condition tying the Smaller head to
-- the candidate position; this file is that rule's executable
-- tripwire.  Gate PASS-M6A-CROSSFORMAL-REJECTED pins it; bad must
-- stay at line 2 column 1.
```

Expected: exit 1, line
`crossformal-t.tot:2:1: recursive definition bad failed the structural termination guard`.

**test/fixtures/deep2.tot** (probes P9, P10):

```
data W : Type 0 := | leaf : W | node : (Nat -> W) -> W
def rec deep2 : W -> Nat := fun w => match w with | leaf => zero | node g => match g zero with | leaf => zero | node h => deep2 (h zero) end end
-- M6 Stage A fixture (verdict pin 9): the judge's depth-2 witness.
-- The inner match scrutinizes the APPLICATION g zero, so h never
-- becomes Smaller: rejected at HEAD even under the deleted flag
-- (probes P9/P10, exit 1 both modes).  The oracle pins the Var-only
-- scrutinee rule in Totality.passes.  Gate PASS-M6A-DEEP2-REJECTED;
-- deep2 must stay at line 2 column 1.
```

Expected: exit 1, line
`deep2.tot:2:1: recursive definition deep2 failed the structural termination guard`.

**test/fixtures/nested-pos.tot** (probe P11):

```
data U (0 A : Type 0) : Type 0 := | mku : (Nat -> A) -> U A
data T2 : Type 0 := | mkt2 : U T2 -> T2
-- M6 Stage A fixture (verdict pin 10, graft from the semantics
-- panel): a COVARIANT nested occurrence under a foreign
-- parameterized head.  The strict-positivity fence rejects it today
-- with the exact message below.  Gate PASS-M6A-FENCE-COVARIANT is
-- DESIGNED to fail the day C3 lands nesting, forcing the guard and
-- Frozen-emptiness questions (SPEC.md:851-852) open on purpose;
-- mkt2 must stay at line 2 column 1.
```

Expected: exit 1, line
`nested-pos.tot:2:1: invalid constructor mkt2: negative or non-uniform occurrence of T2`.

**test/fixtures/nested-neg.tot** (probe P12):

```
data N (0 A : Type 0) : Type 0 := | mkn : (A -> Nat) -> N A
data T3 : Type 0 := | mkt3 : N T3 -> T3
-- M6 Stage A fixture (verdict pin 10): the CONTRAVARIANT smuggle.
-- T3 sits in N's parameter in a negative position inside mkn's
-- field.  Same fence, same exact-message pin, same tripwire intent
-- as nested-pos.tot.  Gate PASS-M6A-FENCE-CONTRAVARIANT; mkt3 must
-- stay at line 2 column 1.
```

Expected: exit 1, line
`nested-neg.tot:2:1: invalid constructor mkt3: negative or non-uniform occurrence of T3`.

NOT landed, stated so nobody re-adds them here: the three pin-2
underscore fixtures belong to Stage C, and the M5 shapes `bad` and
`bad3` already live inside test/fixtures/m5e-witness.tot and the
kernel suite.  m5e-acc.tot and m5e-witness.tot stay BYTE-IDENTICAL
(pin 9); their comments mention `--experimental-wf` as history, and
rewriting history in fixtures whose line numbers are pinned buys
nothing (deliberate non-change 9 in A13).

---

### A8. The transcript reseal (pin 14)

dev/gen-m5e-transcript.sh globs `examples/*.tot test/fixtures/*.tot`
(dev/gen-m5e-transcript.sh:13) and the glob picks up the five new
fixtures with NO script edit.  The script is not renamed and not
edited (deliberate non-change 1 in A13).

Procedure, same commit as the fixtures:

1. Regenerate: `zsh dev/gen-m5e-transcript.sh > dev/m5e-default-transcript.txt`.
2. Diff old against new.  The diff must be ADDITIONS ONLY: five new
   `### ` blocks, one per new fixture, each exactly 5 lines
   (`### path`, `#exit 1`, `#out`, `#err`, the one stderr line; the
   committed m5e-witness block at transcript lines 9572-9576 is the
   shape template).  Predicted totals: 9660 -> 9685 lines, 80 -> 85
   blocks (`rg -c '^### '`).  Any deleted or changed line in the
   diff is a Stage A FAILURE: the deletion must not move one default
   -path byte (pin 7 plus the A3 identity claim).
3. Review the diff against the A7 expected lines, block by block.
4. Record the file count (85) and the diff shape in the SPEC entry
   (A11 entry 4) and in dev/M6-BUILD-LOG.md.

PASS-M5E-DEFAULT-IDENTITY stays the enforcement point between stages
(pin 14): it re-runs the generator and diffs against the committed
transcript on every battery run.

---

### A9. Gate A

All edits sit in the M5 Stage E block of dev/gates.sh (2403-2471)
plus new legs directly after it, plus the one-line PASS-M5D-TIERS
literal raise at dev/gates.sh:2260 (the coordination paragraph
below), BEFORE the two branching tail legs
(PASS-M4FIX-INST-BRANCHING at 2504-2508 and PASS-M5B-BRANCHING-20 at
2522-2527), which stay the file's timing-sensitive tail exactly as
recorded (dev/gates.sh:2406-2412, 2500-2503).  No new leg uses
`gate_timed`, so PASS-M5D-MEASURE-LOG's literal count of 18 and its
name set (dev/gates.sh:2371-2401) are untouched; pin 13 is not
triggered (deliberate non-change 10).  All legs use named tiers; no
numeric watchdog literal.

Leg-by-leg disposition of the M5E block:

- PASS-M5E-DEFAULT-IDENTITY (2416-2434): KEPT, comment updated.  The
  committed transcript it diffs against is the resealed 85-file one.
  The leg body is unchanged (it already checks `code2 -eq 1` for
  m5e-acc.tot flag-free).
- PASS-M5E-ACC-CHECKS (2436-2446): DELETED with the flag (its leg
  runs `--experimental-wf` and pins the exit-0 five-liner).  Marker
  count -1.  The fixture itself stays and is re-covered flag-free by
  PASS-M6A-ACC-GUARD-REJECTED.
- PASS-M5E-WITNESS-REJECTED (2448-2471): REWRITTEN flag-free (its
  legs (a) and (b) hard-require the flag at 2452-2457; the perf
  proposal's unbuildable Stage A died on exactly this, verdict
  adjudication, perf finding 1).  Marker count neutral, name kept.
  Direct tier calls drop 3 to 1 (HEAD:2452, 2455, 2458 become the
  single call below); the TIERS coordination counts this.

**The PASS-M5D-TIERS coordination (added 2026-09-03).**  The TIERS
leg pins the direct watchdog-plus-tier population with a LIVE literal
(`-eq 122` at dev/gates.sh:2260), and its comment obliges any stage
that changes that population to raise the literal in the same edit,
measured before and after (dev/gates.sh:2244-2250).  Stage A changes
the population by NET +4: the ACC-CHECKS deletion removes one direct
call (HEAD:2440), the WITNESS-REJECTED rewrite removes two (three at
HEAD:2452-2458 become one), and the seven PASS-M6A-* legs add seven
FAST calls.  In the SAME commit: run
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before
the gates.sh edit (122 at HEAD, probe reproduced 2026-09-03) and
after (expect 126); edit `-eq 122` to `-eq 126` at dev/gates.sh:2260;
append a dated sentence to the TIERS comment mirroring the M5E
sentence at 2248-2250; record both numbers in dev/M6-BUILD-LOG.md
(pin 17).  If the measured entry differs, raise by EXACTLY four from
the measured value.  Without this edit the battery cannot reach
GATE-EXIT=0 at the Stage A boundary (FAIL-M5D-TIERS with tiers=126
against the stale 122), which breaks the pin-18 walk.

The rewritten and new legs, verbatim:

```zsh
# ---------------------------------------------------------------------
# M6 Stage A (verdict pins 7-10, ruling R1): --experimental-wf and the
# Structural_wf prototype are DELETED.  The WF negative oracles below
# are flag-free on purpose: they are what M7's admission rule is
# rebuilt against.  Gate E (i) keeps its M5 name and remains the
# pin-14 transcript enforcement point over the resealed 85-file
# corpus.  Mutation proofs in dev/M6-BUILD-LOG.md (plan A10).
# ---------------------------------------------------------------------

# Gate E (iii), PASS-M5E-WITNESS-REJECTED, REWRITTEN flag-free (M6
# Stage A, pin 9).  The M5 leg (a) proved the flag live and leg (b)
# probed it; both died with the flag.  What remains is amendment A4's
# pinned negative on the shipped rule.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m5e-witness.tot 2>&1)
code=$?
wantw='m5e-witness.tot:2:1: recursive definition bad failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantw"; } \
  && echo PASS-M5E-WITNESS-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M5E-WITNESS-REJECTED (exit=$code)"; exit 1; }

# Gate A (i), PASS-M6A-WF-FLAG-UNKNOWN (pin 7).  The deleted spelling
# takes the unknown-flag contract (bin/tot.ml unknown-flag arm): one
# stderr line, exit 2, nothing on stdout.  Exact-string match, not a
# substring: a resurrected accept-and-ignore arm would exit 1 with the
# guard line instead, and this leg must see that as red.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  --experimental-wf "$ROOT"/test/fixtures/m5e-acc.tot 2>&1)
code=$?
{ [ "$code" -eq 2 ] && [ "$out" = "unknown flag: --experimental-wf" ]; } \
  && echo PASS-M6A-WF-FLAG-UNKNOWN \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-WF-FLAG-UNKNOWN (exit=$code)"; exit 1; }

# Gate A (ii), PASS-M6A-ACC-GUARD-REJECTED (pin 9).  m5e-acc.tot is
# byte-identical to M5 and now rejects in the ONLY mode there is.
# This is the flag-free replacement for the deleted PASS-M5E-ACC-CHECKS.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m5e-acc.tot 2>&1)
code=$?
wanta='m5e-acc.tot:5:1: recursive definition accRec failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wanta"; } \
  && echo PASS-M6A-ACC-GUARD-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-ACC-GUARD-REJECTED (exit=$code)"; exit 1; }

# Gate A (iii), PASS-M6A-INFINITARY-REJECTED (pin 9).  bad2 was
# ACCEPTED under the M5 flag (plan A0 probe P6); after deletion its
# rejection is the only behaviour, and this leg is what makes the
# deletion irreversible by accident.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/bad2.tot 2>&1)
code=$?
wantb='bad2.tot:2:1: recursive definition bad2 failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantb"; } \
  && echo PASS-M6A-INFINITARY-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-INFINITARY-REJECTED (exit=$code)"; exit 1; }

# Gate A (iv), PASS-M6A-CROSSFORMAL-REJECTED (pin 9).  Rejected at M5
# HEAD in BOTH modes (plan A0 probes P7/P8): what this leg pins is the
# per-candidate Principal seed, not the deleted flag.  It is the
# executable tripwire for any M7 admission rule without a provenance
# side condition (SPEC section 2 entry, 2026-09-03).
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/crossformal-t.tot 2>&1)
code=$?
wantx='crossformal-t.tot:2:1: recursive definition bad failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantx"; } \
  && echo PASS-M6A-CROSSFORMAL-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-CROSSFORMAL-REJECTED (exit=$code)"; exit 1; }

# Gate A (v), PASS-M6A-DEEP2-REJECTED (pin 9).  The depth-2 field
# application, rejected at M5 HEAD even under the flag (probes
# P9/P10): pins the Var-only scrutinee rule.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/deep2.tot 2>&1)
code=$?
wantd='deep2.tot:2:1: recursive definition deep2 failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantd"; } \
  && echo PASS-M6A-DEEP2-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-DEEP2-REJECTED (exit=$code)"; exit 1; }

# Gate A (vi)+(vii), the positivity-fence tripwires (pin 10).  These
# two legs are DESIGNED to go red the day C3 lands nested inductives,
# forcing the Frozen-emptiness and guard questions open on purpose
# (SPEC.md:851-852).  Do not "fix" them by deleting them; re-open the
# design instead.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/nested-pos.tot 2>&1)
code=$?
wantp='nested-pos.tot:2:1: invalid constructor mkt2: negative or non-uniform occurrence of T2'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantp"; } \
  && echo PASS-M6A-FENCE-COVARIANT \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-FENCE-COVARIANT (exit=$code)"; exit 1; }

out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/nested-neg.tot 2>&1)
code=$?
wantn='nested-neg.tot:2:1: invalid constructor mkt3: negative or non-uniform occurrence of T3'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantn"; } \
  && echo PASS-M6A-FENCE-CONTRAVARIANT \
  || { printf '%s\n' "$out"; echo "FAIL-M6A-FENCE-CONTRAVARIANT (exit=$code)"; exit 1; }
```

The PASS-M5E-DEFAULT-IDENTITY leg keeps its `"$SLOW"` tier for the
transcript run and `"$FAST"` for the direct check, unchanged.  Its
comment (dev/gates.sh:2416-2418) is updated to say the transcript is
the M6 Stage A reseal over 85 files.

Marker namespace: `rg -c 'PASS-M6' dev/gates.sh` exits 1 (no match)
at HEAD, probed 2026-09-03 (pin 16).  The seven new markers all live
under PASS-M6A-*.

---

### A10. Mutation proofs

Discipline per pin 18, template dev/M5-BUILD-LOG.md:1549-1593: every
mutation is an OCaml mutation (dev/gates.sh is never mutated), each
flip is observed with its predicted route, and each restore is
proved by `md5 -q` against the pre-mutation digest, recorded in
dev/M6-BUILD-LOG.md with the digests.  Run the flips either through
the full battery (route stated below) or through an extracted-leg
runner in the legx-e.sh style (awk range over the Gate A block,
emptiness-guarded); record which.

The battery runs the two suites FIRST (dev/gates.sh:93-97), so any
mutation that also flips a suite case reports TEST-FAIL before a
marker can print; the per-leg columns below therefore state BOTH the
battery-level first red and the extracted-leg flips.

| # | Mutation (one edit, then rebuild) | Predicted flip route | Restore proof |
|---|---|---|---|
| MA-1 | bin/tot.ml: re-add an accept-and-ignore arm `\| "--experimental-wf" :: rest -> parse_flags opts rest` | Battery: first red is PASS-M6A-WF-FLAG-UNKNOWN, `FAIL-M6A-WF-FLAG-UNKNOWN (exit=1)`, `$out` is the 5:1 guard line, not the unknown-flag line (suites untouched: the usage literal and F2-flag probe `--bogus-flag` do not see this arm) | `md5 -q bin/tot.ml` matches; rebuild; leg PASS |
| MA-2 | lib/totality.ml: `guarded_call`'s App arm returns the spike body unconditionally (spine head Var, `smaller_at`) | Battery: SUITE-KERNEL red at converted E2, `E2 (accRec): guard accepted at k=5, want Termination`, TEST-FAIL before any marker.  Extracted legs: PASS-M5E-DEFAULT-IDENTITY red (m5e-acc.tot and bad2.tot transcript blocks flip to exit 0), PASS-M6A-ACC-GUARD-REJECTED red (exit=0, five lines), PASS-M6A-INFINITARY-REJECTED red (exit=0, three lines, probe P6's output).  PASS-M6A-CROSSFORMAL-REJECTED and PASS-M6A-DEEP2-REJECTED stay GREEN (probes P8/P10: the clause alone admits neither) | `md5 -q lib/totality.ml` matches; rebuild; battery 339 PASS |
| MA-3 | MA-2 plus seed widening: `List.init formals (fun _ -> Principal)` at the seed (lib/totality.ml:184-187) | Battery: SUITE-KERNEL red first (E2 accRec, as MA-2).  Extracted legs: PASS-M6A-CROSSFORMAL-REJECTED red (crossformal-t.tot exits 0: match on non-candidate b now mints Smaller, the M7 hazard replayed); PASS-M6A-DEEP2-REJECTED stays GREEN (inner scrutinee is an application, h stays Other); PASS-M5E-WITNESS-REJECTED stays GREEN (built scrutinee) | `md5 -q lib/totality.ml` matches; rebuild; battery 339 PASS |
| MA-4 | MA-2 plus scrutinee widening: `scrut_special` also true when the scrutinee's spine head is a Var with `principal_or_smaller_at` status | Battery: SUITE-KERNEL red first (E2 accRec, as MA-2).  Extracted legs: PASS-M6A-DEEP2-REJECTED red (deep2.tot exits 0: `g zero` now mints Smaller for h); PASS-M6A-CROSSFORMAL-REJECTED stays GREEN (per-candidate seed intact); PASS-M5E-WITNESS-REJECTED stays GREEN (spine head is `Global mk`, not a Var) | `md5 -q lib/totality.ml` matches; rebuild; battery 339 PASS |
| MA-5 | lib/check.ml: `strict_pos`'s non-Pi arm gains a nested-admission clause: accept `is_applied` OR a foreign `Global` head whose spine args are each `no_occur` or `is_applied` (the C3 shape, simulated) | Battery: SUITE-KERNEL red at the json positivity case (test/main.ml:1134 asserts `List JsonBadK -> JsonBadK` nesting is REJECTED, test/main.ml:1169); SUITE-SURFACE would follow at test/surface.ml:1146.  Extracted legs: PASS-M6A-FENCE-COVARIANT red (nested-pos.tot exits 0) and PASS-M6A-FENCE-CONTRAVARIANT red (nested-neg.tot exits 0).  This differential is the pin-10 story: real C3 work will re-oracle the suite cases, and the two gate markers remain the conscious re-open tripwire | `md5 -q lib/check.ml` matches; rebuild; battery 339 PASS |
| MA-6 | MA-2 plus the M5 M3-replacement: `if scrut_special then Smaller else Smaller` (precondition dropped, computation still consumed, dev/M5-BUILD-LOG.md:1579-1589) | Battery: SUITE-KERNEL red first (E2, BOTH halves: accRec and the witness accepted).  Extracted legs: PASS-M5E-WITNESS-REJECTED red (m5e-witness.tot exits 0 printing `data T` / `ctor mk` / `def bad`), proving the rewritten leg still bites on the scrut-special precondition | `md5 -q lib/totality.ml` matches; rebuild; battery 339 PASS |

Do not pin the ORIGINAL M5 M3 mutation ("scrut_special deleted"):
the M5 record proves it does not compile (unused-var, the mutated
binary never exists, dev/M5-BUILD-LOG.md:1574-1578).  MA-6 pins the
recorded replacement.

---

### A11. SPEC.md decision-log entries for Stage A

Four dated section 2 entries plus one section 6 discharge, all
2026-09-03, all in the Stage A commit.

1. **The deletion (ruling R1, pins 7-8).**  `--experimental-wf` is
   deleted across driver, policy, kernel, tests and gates; the
   spelling now takes the unknown-flag contract (one stderr line,
   exit 2).  `Totality.rule` survives as a single-constructor type;
   `Check.define`'s `~rule` stays REQUIRED; M7 re-entry is a rebuild
   of `guarded_call`'s App arm by non-exhaustiveness, against the
   pin-9 oracles.  Record the re-homed cache sentence: the prelude
   bootstrap folds with `default_policy`, so no policy ever entered
   the cache key and `format_version` stays 10.  Record the pin-8
   dead spot: instance bodies pass `~rule` but never `~rec_`
   (lib/check.ml:1762-1773), inert plumbing, M7 decides.
2. **The seed invariant (pin 9).**  Smaller status chains only from
   the per-candidate Principal seed (the seed fold in
   `Totality.passes`; lib/totality.ml:184-187 at M5 HEAD).  Any
   future admission rule, lexicographic descent included, must carry
   a provenance side condition tying the Smaller head to the
   candidate position, not just a type-family condition.
   crossformal-t.tot is the executable tripwire; deep2.tot pins the
   Var-only scrutinee rule beside it.
3. **The fence tripwires (pin 10).**  nested-pos.tot and
   nested-neg.tot pin the exact fence messages;
   PASS-M6A-FENCE-COVARIANT and PASS-M6A-FENCE-CONTRAVARIANT are
   designed to fail the day C3 lands nesting, over the UNPROVEN
   Frozen emptiness claim (SPEC.md:851-852, 1615-1619).
4. **The transcript reseal (pin 14).**  Corpus 80 -> 85 files;
   transcript 9660 -> 9685 lines, 80 -> 85 blocks; diff reviewed
   additions-only (five 5-line blocks, enumerated).
5. **Section 6 discharge.**  The M5 residual sentence "M6 either
   promotes the prototype behind a sound side condition or deletes
   the flag" (SPEC.md:1062-1063; restated at SPEC.md:1698) is
   discharged: the delete arm is taken, dated, with a pointer to
   entry 1.  The M5 Stage E history entries stay as written; history
   is not rewritten.

---

### A12. Conflicts resolved in this section (2026-09-03)

**C-A1 (count precision, pin 17; no pin intent moves).**  The
verdict and the dogfood attack both say "32 `~rule:Totality.Structural`
literals in test/main.ml".  Recounted at HEAD:
`rg -c '~rule:Totality\.Structural' test/main.ml` = 32, but that
pattern is a PREFIX and its 32 lines include the two
`~rule:Totality.Structural_wf` lines (2827, 2837);  the word-bounded
count `rg -c '~rule:Totality\.Structural\b' test/main.ml` = 30, and
the full decomposition is 33 `~rule` lines = 30 Structural + 2
Structural_wf + 1 bare pass-through (`Totality.guard ~rule` inside
`m5e_expect_termination`, test/main.ml:2810).  The perimeter is the
same set of lines either way; the plan records the decomposition so
the build log's own recount cannot look like drift.  RESOLUTION:
carry both commands and both numbers (A0); no code consequence.

**C-A2 (verdict wording versus the type checker; pin 7 wins as
written).**  The verdict's pin 7 sentence groups "the 32 ... literals
in test/main.ml and 3 `wf_rule` literals in test/surface.ml (442,
756, 1625) which now name the single constructor".  A record literal
cannot "name" a field its record type no longer has: pin 7 itself
deletes `wf_rule` at surface/run.ml:40, 51, 243, so the three
test/surface.ml literals must DELETE their `wf_rule` lines, while
"name the single constructor" lands on test/main.ml's `~rule:`
literals (which are byte-unchanged and now name the sole
constructor).  RESOLUTION: A6 step 2 deletes the three lines; A5
step 3 keeps the 30 literals unchanged.  Pin intent (full perimeter,
threading kept) is unchanged; the compiler enforces the reading
(a missed literal fails the build).

No probe refuted any verdict claim this section relies on: all 15
probe rows in A0 match the verdict's stated baselines, and the Stage
A exit arithmetic recount agrees with the verdict's number (A14).

---

### A13. Deliberate non-changes

1. dev/gen-m5e-transcript.sh: not edited, not renamed.  Its glob
   already covers the new fixtures; its `m5e` name is history, and
   renaming would churn dev/gates.sh:2419 plus pin 14's procedure
   for zero behaviour.  (Its `for` loop predates the loop-free rule
   for NEW gate code; not editing it also keeps that rule's scope
   clean.)
2. dev/m5e-default-transcript.txt: regenerated, not renamed, for the
   same reason.
3. Marker names PASS-M5E-DEFAULT-IDENTITY and
   PASS-M5E-WITNESS-REJECTED: kept.  Pin 16 scopes PASS-M6A-* to NEW
   M6 markers; these are surviving M5 markers, count-neutral, and
   the verdict's stage allocation keeps their names explicitly.
4. `Check.define`'s REQUIRED `~rule` argument and the guard call at
   lib/check.ml:1546-1550: unchanged (pin 8).
5. The literal `~rule:Totality.Structural` at lib/check.ml:1772
   (`define_instance`): unchanged; the dead spot is recorded in SPEC
   entry 1, and M7 decides its fate (verdict, Known debts).
6. `Totality.peel`, `spine`, `mentions`, the `ok` walk, the Var-only
   `scrut_special` and the per-candidate seed: byte-untouched.  The
   `Structural` path is the shipped M2 rule before and after;
   PASS-M5E-DEFAULT-IDENTITY is its oracle.
7. bin/tot.ml:277-278 (unknown-flag arm): untouched; it IS the
   deleted spelling's new contract (probe P13).
8. The 30 `~rule:Totality.Structural` literals in test/main.ml:
   byte-unchanged.
9. test/fixtures/m5e-acc.tot and m5e-witness.tot: byte-identical
   (pin 9), historical flag mentions in their comments included;
   their pinned `5:1` / `2:1` anchors must not move.
10. No new `gate_timed` leg, so PASS-M5D-MEASURE-LOG's literal line
    count (18) and name set are untouched; pin 13 is not triggered
    at Stage A.
11. Watchdog tiers FAST/MED/SLOW/SUITE and BITE_S
    (dev/gates.sh:44-48): untouched.
12. `surface/cache.ml`: untouched; `format_version` stays 10
    (pin 15).
13. SPEC.md M5 history (the Stage E entries naming the flag,
    SPEC.md:1043, 1059) and dev/M5-* logs: untouched; the new dated
    entries supersede without rewriting.
14. examples/ and stdlib/prelude.tot: untouched; their transcript
    blocks must be byte-identical in the A8 diff.

---

### A14. Exit criteria and arithmetic

1. `dunecho build` green; then the full battery from a clean run:
   GATE-EXIT=0, 0 FAIL.
2. PASS arithmetic, chaining from 334 (pin 18):
   kernel suite 106 - 1 = 105 (E1 retires, E2 converts, A5);
   surface suite 107 + 0 = 107 (A6 changes content, not count);
   gate markers 121 - 1 + 7 = 127 (PASS-M5E-ACC-CHECKS retires;
   seven PASS-M6A-* legs land, A9).
   Total: 334 - 1 - 1 + 7 = **339 PASS**, which matches the verdict
   Stage A paragraph's own "334 - 1 - 1 + 7 = 339" exactly; no
   conflict note needed on the number.
3. Deletion sweeps, each must print no match and exit 1:
   `rg -c 'Structural_wf' bin lib surface test`;
   `rg -c 'experimental' bin/tot.ml test/surface.ml`;
   `rg -c 'wf_rule' surface test`.
   Historical mentions in SPEC.md and dev/ logs remain and are NOT
   failures (A13 items 13, 1).
4. Transcript resealed and reviewed per A8: 85 blocks, 9685 lines,
   additions-only diff, counts recorded.
5. The six mutation proofs of A10 run, each flipping on its
   predicted route, each restored `md5 -q`-identical, digests logged
   in dev/M6-BUILD-LOG.md.
6. The five SPEC entries of A11 landed, dated 2026-09-03.
7. Marker namespace: `rg -c 'PASS-M6A' dev/gates.sh` counts exactly
   the seven new markers' echo lines plus their comments; no
   PASS-M6[B-E]-* exists yet.
8. PASS-M5D-TIERS is green with `-eq 126` (entry value plus exactly
   4, the A9 coordination); the before/after `rg -c` numbers are in
   the build log.
9. The user commits.  Nothing lands committed by an agent (pin 18).

Handoffs out of Stage A: Stage B inherits a battery at 339 with the
transcript discipline exercised once; Stage C's underscore fixtures
land into a fixtures directory whose reseal procedure is now
routine; M7 inherits the pin-9/10 oracles as executable files plus
the SPEC seed-invariant entry, and re-enters the WF package through
the `type rule` compiler error (A3).

## STAGE B: the blocking Unit strict-json posture (verdict pins 5-6, ruling R3)

Verdict Stage B, ruling R3: the strict-json refusal on an `IO Unit`
script migrates from exit 1 to exit 2 as a DIRECT breaking change.
The SPEC migration note is the sole mitigation.  No new flag lands.
Entry: Stage A green at its measured count (target 339).  Exit: the
Stage A battery stays green, four new markers print, two surface
cases land.  Target 345.

This stage changes ONE executable thing: the exit-code literal in the
driver's `Serror.driver_exit` classification arm
(`bin/tot.ml:106-108`).  Everything else the stage touches is a doc
comment, a test, a gate leg or a SPEC entry.  `surface/effect.ml`
does not change by one byte.  `surface/run.ml` and
`surface/serror.ml` change only in comments.  The stderr line, the
channel split and the fail-open default are all byte-identical to
HEAD, and the identity legs prove it (pin 6).

The stage is deliberately small because the M5 build already put the
seam in the right place: `Serror.driver_exit`
(`surface/serror.ml:94-99`) exists precisely so that "which exit code
does a strict-json refusal take" is one arm in one function in the
driver, decided away from the `--serror-exit` mapping.  Stage B turns
that dial from 1 to 2 and pins every surface that could drift.

---

### B0. Entry state, measured against the built binary

Every claim below was probed on 2026-09-03 against
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe` at HEAD
8d5a839.  Probe fixtures live outside the repo under
`/Users/oobi/Documents/tot-m6-probes/plan-stage-b/`.  The `P<n>`
labels are PROBE ids local to this section: P1 to P11 are binary
probes, P12 to P16 are rg/hash probes.  This numbering is not the
preamble's pin numbering, and `R<n>` in this plan always means a
ratification ruling (preamble section 1.1), never a probe.

The one probe fixture, `unit-echo.tot` (one line, same shape as the
verdict's `unit-guard.tot` and as the suite's own stdin case at
`test/surface.ml:1151`):

    def main : IO Unit := let* String Unit raw := readStdin in printLine raw

**P1.  Unit + flag + garbage: exit 1, one stderr line, empty stdout.**

    $ printf 'not json' | tot.exe run --strict-json unit-echo.tot
    exit=1
    stdout=[]
    stderr=[unit-echo.tot:stdin is not a single well-formed JSON value, and this installation runs with --strict-json]

The separator after the path is the tight `:`, no space
(`bin/tot.ml:107`, `path ^ ":" ^ ...`).  This is the exact pin-5
baseline transcript, reproduced.

**P2.  The refusal sits OUTSIDE the mapping today: `--serror-exit 7`.**

    $ printf 'not json' | tot.exe run --serror-exit 7 --strict-json unit-echo.tot
    exit=1    stdout=[]    stderr=[the P1 line]

**P3.  And under a fail-open install: `--serror-exit 0`.**

    $ printf 'not json' | tot.exe run --serror-exit 0 --strict-json unit-echo.tot
    exit=1    stdout=[]    stderr=[the P1 line]

**P4.  Unit, NO flag, garbage: fail-open, exit 0, echo on stdout.**

    $ printf 'not json' | tot.exe run unit-echo.tot
    exit=0
    stdout=[not json
    def main : (IO Unit)]

The `printLine` echo PRECEDES the per-item `def` line: `printLine`
writes to fd 1 at effect time, while the accumulated item lines are
printed by the driver afterwards (`bin/tot.ml:69`).  The identity leg
pins this order.

**P5.  Unit + flag + WELL-FORMED payload: unaffected, exit 0.**

    $ printf '{"a":1}' | tot.exe run --strict-json unit-echo.tot
    exit=0
    stdout=[{"a":1}
    def main : (IO Unit)]

**P6.  Verdict + flag + garbage: deny envelope on stdout, exit 2.**

    $ printf 'not json' | tot.exe run --strict-json examples/guard.tot
    exit=2
    stdout=[{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"strict-json: stdin is not a single well-formed JSON value"}}]
    stderr=[]

**P7.  Verdict + flag + `--serror-exit 7`: still exit 2.**

    $ printf 'not json' | tot.exe run --serror-exit 7 --strict-json examples/guard.tot
    exit=2

**P8.  Verdict, NO flag, garbage: fail-open, exit 0, empty stdout.**

    $ printf 'not json' | tot.exe run examples/guard.tot
    exit=0    stdout=[]

**P9.  `check` never fires the flag (no epilogue, no `readStdin`).**

    $ printf 'not json' | tot.exe check --strict-json unit-echo.tot
    exit=0    stdout=[def main : (IO Unit)]

**P10.  The gate's own payload file, captured the way the leg will
capture it.**  `test/fixtures/garbage.json` holds
`not json at all\n`.  Feeding it to `unit-echo.tot` without the flag
and capturing stdout through `$(...)`:

    $ out=$(tot.exe run unit-echo.tot < test/fixtures/garbage.json); rc=$?
    rc=0, and [ "$out" = $'not json at all\n\ndef main : (IO Unit)' ] holds
    (probed: capture-matches-want=yes)

The interior blank line is real: `printLine` appends a newline to a
payload that already ends in one.  The OPEN-IDENTITY leg pins these
exact bytes.

**P11.  P1 repeated with the gate payload bytes** (`not json at
all\n` instead of `not json`): exit=1, same stderr line, empty
stdout.  The refusal does not depend on which malformed bytes arrive.

**P12.  The seven `Json_strict_reject` lines of `surface/serror.ml`
(pin 5's enumerated perimeter).**

    $ rg -n 'Json_strict_reject' surface/serror.ml
    44:  | Json_strict_reject
    72:  | Json_strict_reject ->
    86:  | Json_strict_reject -> "Json_strict_reject"
    90:    [Json_strict_reject] today: a fail-open install ([--serror-exit 0])
    96:  | Json_strict_reject -> true
    108:  | Axioms_disabled _ | Missing_main | Json_strict_reject ->
    120:  | Axioms_disabled _ | Json_strict_reject ->

Seven lines: 44, 72, 86, 90, 96, 108, 120.  Exactly the verdict's
list.  B3 dispositions each one.

**P13.  The constructor's whole-tree footprint.**

    $ rg -c 'Json_strict_reject' surface bin lib test
    surface/serror.ml:7
    surface/run.ml:2

Nine lines total, all in `surface/`.  Zero in `bin/` (the driver
reaches it only through the `Serror.driver_exit` predicate), zero in
`lib/`, zero in `test/`.

**P14.  No marker collision (pin 16).**

    $ rg -c 'PASS-M6' dev/gates.sh
    (exits 1, no matches)

**P15.  NOTHING at HEAD pins the Unit exit-1 route.**

    $ rg -n 'Json_strict|and this installation runs with --strict-json' \
        dev/gates.sh test/surface.ml test/main.ml
    (exits 1, no matches)

The two M5A gate legs (`PASS-M5A-STRICT-DENY` at `dev/gates.sh:1844`,
`PASS-M5A-STRICT-ALLOW` at `dev/gates.sh:1864`) run the VERDICT guard
only, and the two M5A suite cases (`M5A-14`/`M5A-15`,
`test/surface.ml:1710-1716`) run a Verdict `main` only.  The exit-1
route this stage deletes is exercised by NO existing leg and NO
existing test.  Consequence: the migration turns nothing red, and the
route needs NEW coverage in both directions, which B7 and B8 add.

**P16.  Entry hashes for the restore proofs and the non-change proof.**

    $ md5 -q surface/serror.ml surface/run.ml bin/tot.ml surface/effect.ml
    93df16a30dfda9016ca5773c9777958c   surface/serror.ml
    72ecaed635b43c16d5a6bb3f0889873c   surface/run.ml
    9c56093da1a221a4480e2dcba460a1f1   bin/tot.ml
    b50915fdb47b92d2f117fc83ca0ff6e3   surface/effect.ml

These are HEAD hashes.  Stage A edits `surface/run.ml` and
`bin/tot.ml` (pin 7), so Stage B re-records its OWN entry hashes at
build time; the `surface/effect.ml` hash is the one this stage's exit
criteria can hold to only if Stage A left the file untouched (pin 7's
perimeter does not name it), so item 6 of B12 phrases it against the
Stage-B-entry value.

**Conflict check (2026-09-03).**  Every pin-5 and pin-6 claim was
re-probed this session and every cited line was re-read at HEAD: the
arm is at `bin/tot.ml:106-108`, the constructor sits on the seven
serror lines listed in P12, the P1/P2 transcripts match the verdict's
baseline verbatim, and both identity postures (P6/P7, P4/P8) hold.
NO conflict between the verdict and the code was found.  This section
records no conflict note.

---

### B1. The route today, file by file (read at HEAD)

The refusal is born in one place and dies in one place.  The chain,
every link read this session:

1. `surface/effect.ml:238-239`.  `Effect.dispatch`'s
   `Prim.Read_stdin` arm, the one raw stdin read in the tree.  Under
   the flag, a payload `Interp.json_parse_top` refuses becomes
   `Ok (Rejected strict_json_reason)`.  The reason constant is
   `surface/effect.ml:31`.
2. `surface/effect.ml:171`.  `run_io` short-circuits `Rejected`
   exactly like `Exited`: `| Rejected reason -> Ok (Rejected reason)`.
   The script never sees the bytes.
3. The fork.  `Run.main_epilogue` (`surface/run.ml:597-627`) tries
   `IO Verdict` first, `IO Unit` second:
   - VERDICT shape, `run_verdict_main` (`surface/run.ml:530-541`).
     The `Rejected` arm at `surface/run.ml:538` is
     `Ok ([ Effect.deny_envelope reason ], 2)`.  Note the mechanism:
     the exit 2 travels through the OK half of the result, as the
     script's computed exit code, delivered by `bin/tot.ml:68-74`
     (`Option.value exit_code ~default:0`).  It never enters the
     error fold, so it is outside the `--serror-exit` mapping BY
     CONSTRUCTION, not by an exemption arm.  P7 confirms.
   - UNIT shape, `run_unit_main` (`surface/run.ml:551-560`).  The
     `Rejected` arm at `surface/run.ml:559` is
     `Error Serror.Json_strict_reject`.  A Unit script has no verdict
     channel, so the refusal crosses into the driver as a script
     error.
4. `bin/tot.ml:98-111`.  `run_file`'s error fold classifies the
   `Serror` with a `match ()` ladder: check-budget first (exit 3,
   line 99-102), missing-main second (exit 1, 103-105), then

       | () when Tot_surface.Serror.driver_exit e ->
           prerr_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
           1

   at `bin/tot.ml:106-108`, and finally the catch-all `serror_exit`
   arm at 109-111.  `Serror.driver_exit` (`surface/serror.ml:94-99`)
   answers `true` for `Json_strict_reject` ALONE, with the
   enumerated-no-catch-all match the file's own comment demands, so
   the literal `1` on `bin/tot.ml:108` is reached by exactly one
   error value in the whole language.  P1/P2/P3 confirm the literal
   and its independence from the mapping.

That literal is the stage.

---

### B2. The change: one literal in one arm

Edit `bin/tot.ml:106-108`:

```ocaml
| () when Tot_surface.Serror.driver_exit e ->
    prerr_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
    2
```

`1` becomes `2`.  That is the whole executable delta of Stage B.

Why this is the right seam and not `run_unit_main`:

- SYMMETRY WITH THE VERDICT SHAPE (the pin's "read how Verdict-mode
  strict-json does it and pin symmetry").  The Verdict route delivers
  a LITERAL 2 that no `--serror-exit` value can touch, because it
  rides the ok half (B1 item 3).  Moving the Unit route to a literal
  2 inside the SAME `driver_exit` arm gives the identical guarantee
  through the error half: the literal sits before the mapping arm and
  under every configured value.  Both shapes now answer "malformed
  stdin under the flag" with the blocking code 2, and neither can be
  remapped to 0 by a fail-open install nor demoted to a non-blocking
  1 by any configuration.  The refusal stays OUTSIDE the
  `--serror-exit` mapping in both shapes; the two mechanisms differ
  (stdout envelope vs stderr line) because the two shapes' channels
  differ, and that difference is pinned, not accidental.
- ONE CONSTRUCTION SITE, ONE CONSUMPTION SITE.  P13 shows the
  constructor is built only at `surface/run.ml:559` and classified
  only through `driver_exit` at `bin/tot.ml:106`.  Changing the arm's
  literal retires the exit-1 route with no survivor path: after the
  edit, NO code path can produce exit 1 from `Json_strict_reject`.
  The B8 negative proves it from the outside.
- THE SERROR STAYS AN SERROR.  `run_unit_main` still returns
  `Error Serror.Json_strict_reject` (`surface/run.ml:559`,
  unchanged).  The surface API, the constructor, its `to_string`
  bytes, its `tag`, and the `driver_exit` predicate all keep their
  M5 shapes.  An alternative that returned a synthetic
  `Ok (Some 2)` from `run_unit_main` would fake a successful run,
  print the accumulated item lines on stdout (P4 shows the driver
  prints them on the ok path), and violate the pinned
  empty-stdout/stderr-line contract.  Rejected.
- NO NEW FLAG (ruling R3).  The rejected deferral alternative (a new
  opt-in posture flag) is recorded in the verdict's open question 3
  and was ruled out by the user.  Do not add one.

What the refusal looks like after the edit, predicted (the B8 legs
assert exactly this):

    $ printf 'not json' | tot.exe run --strict-json unit-echo.tot
    exit=2
    stdout=[]
    stderr=[unit-echo.tot:stdin is not a single well-formed JSON value, and this installation runs with --strict-json]

Same line, same channels, same everything, exit 2.  And under
`--serror-exit 0`, `--serror-exit 1`, `--serror-exit 7`: exit 2, all
three (the literal under every value).

---

### B3. The comment perimeter: the seven serror lines, dispositioned

Pin 5: "the classification change must visit the predicates at
96-120, not six."  Here is the visit, one disposition per line of P12,
plus the three out-of-file comment sites that state the old exit.
CODE changes: none in this file.  COMMENT changes: two.

| serror.ml line | what it is | disposition |
|---|---|---|
| 44 | the constructor | UNCHANGED (the doc block under it, 45-51, is EDITED: "the literal exit 1" becomes "the literal exit 2"; the sentence contrasting the Verdict envelope stays, now reading as symmetry, both exits 2) |
| 72 | `to_string` arm | UNCHANGED, byte-identical; the stderr line must not move (pin 5) |
| 86 | `tag` arm | UNCHANGED |
| 90 | `driver_exit` doc | EDITED: the block at 88-93 becomes "the DRIVER exit contract (the literal exit 2, OUTSIDE the [--serror-exit] mapping)... a fail-open install must not turn a strict-json refusal into a silent exit 0, and no configuration can demote it to a non-blocking 1" |
| 96 | `driver_exit` arm | UNCHANGED: `Json_strict_reject -> true`.  The predicate still answers "takes the driver contract"; only the driver's literal moved |
| 108 | `is_check_budget` false-branch enumeration | UNCHANGED; the constructor stays enumerated `false`, so a strict-json refusal never takes the budget exit 3 |
| 120 | `is_missing_main` false-branch enumeration | UNCHANGED; the constructor stays enumerated `false`, so it never takes the missing-main arm |

Because both enumerations at 108 and 120 are exhaustive with no
catch-all, the builder VERIFIES them by re-reading after the edit;
the compiler enforces nothing here since nothing in the type moved.

The out-of-file comment sites that state exit 1 for THIS route (found
by `rg -n 'exit 1|literal 1' bin/tot.ml surface/run.ml`, then read
one by one; only the strict-json mentions qualify):

1. `surface/run.ml:31-39`, the `policy.strict_json` doc:
   "`([Serror.Json_strict_reject], exit 1)`" becomes
   "`([Serror.Json_strict_reject], exit 2 since M6 Stage B)`".
2. `surface/run.ml:554-558`, the `run_unit_main` `Rejected`-arm
   comment: "one stderr line, exit 1, outside the --serror-exit
   mapping" becomes "one stderr line, exit 2 (M6 Stage B, ruling R3;
   exit 1 through M5), outside the --serror-exit mapping".  Drop the
   trailing "the same posture --require-main takes": after this stage
   it no longer is (missing-main stays exit 1), and a stale symmetry
   claim is exactly the kind of comment drift M5 spent a fixes round
   deleting.
3. `bin/tot.ml:75-97`, the classification comment above the ladder:
   the sentence "takes the DRIVER contract's literal 1 instead,
   OUTSIDE the mapping, so a fail-open install (--serror-exit 0)
   cannot turn the refusal into a silent allow" (81-86) becomes
   "takes the DRIVER contract's literal 2 instead (M6 Stage B,
   ruling R3), OUTSIDE the mapping, so a fail-open install
   (--serror-exit 0) cannot turn the refusal into a silent allow,
   and a harness that blocks only on exit 2 now sees the Unit-shape
   refusal too".

NOT edited, verified one by one as belonging to OTHER contracts:
`bin/tot.ml:14` and `bin/tot.ml:59` (unusable-target exit 1),
`bin/tot.ml:92-96` (missing-main literal 1, stays), `bin/tot.ml:124`
(prelude classification), `surface/effect.ml:400` (`render_verdict`'s
ask/deny codes).  Missing-main and the unusable-target contract stay
at exit 1 ON PURPOSE: those are driver errors about the INSTALLATION
(a missing file, a mainless guard), not a blocking security decision
about a payload, and no verdict pin moves them.

---

### B4. The stderr line and the channels, pinned

The line after this stage, byte for byte, is the line P1 measured:

    <path>:stdin is not a single well-formed JSON value, and this installation runs with --strict-json

- `<path>` is argv's spelling of the target, tight `:` separator, no
  space (`bin/tot.ml:107`).  The gate leg builds its expected string
  from the same path it passes on argv.
- The message half is `Serror.to_string Json_strict_reject`
  (`surface/serror.ml:72-74`), UNCHANGED.  Any edit to those bytes is
  out of scope for this stage and would be a pin-5 violation.
- stdout carries NOTHING on the refusal.  The error path discards the
  accumulated item lines (P1, P11: `stdout=[]`), and that stays: the
  hook protocol owns stdout, and a refusal must not put junk on the
  decision channel (`bin/tot.ml:55-62` states the channel rule).
- stderr carries exactly the ONE line.  No second line, no usage
  text.

Distinguishing the refusal from other exit-2 paths: the CODE is
shared (the Verdict deny envelope exits 2, the unknown-flag contract
exits 2 per `bin/tot.ml:277-278`), the LINE is the discriminator, the
same convention SPEC states for the budget exit 3 (SPEC.md:888-896).
The migration note (B10) says so explicitly.

---

### B5. `--serror-exit` interaction, pinned symmetry

The contract after this stage, stated once:

| shape | flag | payload | exit | channel | `--serror-exit N` effect |
|---|---|---|---|---|---|
| `IO Verdict` | on | malformed | 2 | deny envelope, stdout | none (ok-path literal; P6/P7) |
| `IO Unit` | on | malformed | 2 | one line, stderr | none (driver-arm literal; was 1 at HEAD, P1-P3) |
| either | on | one JSON value | script's own | script's own | normal mapping for real Serrors |
| either | off | anything | script's own | script's own | normal mapping |

The Unit refusal is OUTSIDE the mapping the same way the Verdict
refusal is: a literal 2 reached before the `serror_exit` arm, under
every configured value including 0 and 1.  `PASS-M6B-UNIT-STRICT-NOMAP`
asserts all three of 0, 1, 7; the value 1 is the sharp one, because it
distinguishes "the literal 2" from BOTH dead alternatives at once (the
old literal 1 and a route through the default mapping, which is also
1).

`--serror-exit` itself does not change: default 1
(`bin/tot.ml:235`), range check 0..255 (`bin/tot.ml:259-267`), and
every non-driver `Serror` still takes it (`bin/tot.ml:109-111`).

---

### B6. Fixtures

ONE new script fixture, GENERATED by the gate into the Gate D scratch
directory, never committed to the tree:

    m6b-unit-echo.tot
    def main : IO Unit := let* String Unit raw := readStdin in printLine raw

Why generated and not a `test/fixtures/` file: pin 14.
`dev/gen-m5e-transcript.sh` globs `examples/*.tot` and
`test/fixtures/*.tot`, so a new `.tot` in either directory forces a
transcript reseal in the same commit.  Stage B needs no reseal
(verdict: "Driver and serror change only"), and the cheapest sound
way to keep it that way is to keep the fixture out of both globbed
directories.  The file precedent is `PASS-M5A-ENVELOPE-VALID`, which
generates `m5a-envelope.tot` into the gate scratch the same way.  The
`printf` line in B8 IS the fixture; its bytes are pinned there.

Payload fixtures: REUSED, not added.  `test/fixtures/garbage.json`
(`not json at all\n`, P10) is the malformed payload, and it is
already outside the transcript glob (the glob takes `*.tot` only).
No new `.json` lands either.

The suite cases (B7) inline their script source as OCaml strings,
following `m5a_stdin_allow_src` (`test/surface.ml:739-742`), so they
add no fixture files at all.

---

### B7. Stage B tests (+2 surface)

Both cases land in `test/surface.ml`, registered next to
M5A-14/M5A-15 (`test/surface.ml:1710-1716` at HEAD).  Both are
written against the POST-Stage-A `Run.policy` record, which has lost
`wf_rule` (pin 7): the record literal is
`{ no_axioms = false; require_main = false; strict_json = ... }`.  If
Stage A also rewrote `m5a_run_with_policy`'s record, follow the shape
Stage A left.

The shared script source, module level:

```ocaml
(* M6 Stage B: the one IO Unit main the strict-json Unit cases run;
   it reads stdin and echoes, so every behaviour difference below is
   the FLAG's, never the script's (the m5a_stdin_allow_src
   discipline). *)
let m6b_unit_echo_src : string =
  "def main : IO Unit :=\n\
  \  let* String Unit raw := readStdin in\n\
  \  printLine raw\n"
```

**M6B-1.  The Unit refusal is the pinned Serror.**  The surface half
of the route (`run_unit_main`'s `Rejected` arm) does NOT change this
stage; this case pins it so the driver-side migration cannot drift
into `surface/` unnoticed.  Reuses `m5a_with_stdin_bytes`
(`test/surface.ml:702`), the fd-0 swap helper, because
`Effect.dispatch` reads the real stdin:

```ocaml
( "M6B-1: Run.script under strict_json=true turns a garbage stdin payload on an \
   IO Unit script into Serror.Json_strict_reject (the surface half; the driver \
   maps it to the literal exit 2, M6 Stage B)",
  fun () ->
    m6b_with_unit_policy ~strict_json:true
    |> Result.fold
         ~ok:(fun () -> Ok ())
         ~error:(fun e -> Error e) );
```

with the helper (local to the M6B block; combinators, no match on
Result, the house rules):

```ocaml
let m6b_with_unit_policy ~(strict_json : bool) : (unit, string) result =
  m5a_with_stdin_bytes "not json at all\n" (fun () ->
      Tot_surface.Run.script ~st:bst
        ~policy:{ Tot_surface.Run.no_axioms = false; require_main = false; strict_json }
        ~exec:true m6b_unit_echo_src
      |> Result.fold
           ~ok:(fun (_lines, _exit) ->
             Error "expected Serror.Json_strict_reject, got an Ok run")
           ~error:(fun e ->
             let t = Tot_surface.Serror.tag e in
             match () with
             | () when String.equal t "Json_strict_reject" -> Ok ()
             | () -> Error (Printf.sprintf "expected Json_strict_reject, got %s" t)))
```

**M6B-2.  The classification inputs are pinned.**  The driver arm's
correctness rests on two facts of `surface/serror.ml` that no gate
leg can see from outside: `driver_exit Json_strict_reject = true`
(else the refusal falls into the `--serror-exit` mapping) and the
`to_string` bytes (else the stderr line moves).  Pin both:

```ocaml
( "M6B-2: Serror.driver_exit stays true on Json_strict_reject and its rendered \
   line is byte-identical (the two inputs of the driver's literal-2 arm)",
  fun () ->
    let want =
      "stdin is not a single well-formed JSON value, and this installation runs \
       with --strict-json"
    in
    let got = Tot_surface.Serror.to_string Tot_surface.Serror.Json_strict_reject in
    match () with
    | ()
      when Tot_surface.Serror.driver_exit Tot_surface.Serror.Json_strict_reject
           && String.equal got want ->
        Ok ()
    | () -> Error (Printf.sprintf "driver_exit or line drifted: [%s]" got) );
```

Surface suite count: 107 + 2 = 109 (decomposition per
`dev/M5-BUILD-LOG.md:1671-1674`; Stage A leaves surface at 107).

No kernel test moves: `lib/` is untouched and P13 shows the
constructor never appears in `test/main.ml`.

---

### B8. Gate B: the four legs, verbatim

Placement: a new `M6 Stage B` block, inserted immediately AFTER the
M6 Stage A gate block (which Stage A appends after the last M5E leg),
and UPSTREAM of the file's final two legs, which remain
`PASS-M4FIX-INST-BRANCHING` and `PASS-M5B-BRANCHING-20` (the round-5
tail placement pin 13 preserves).  None of the four legs is
`gate_timed`, so the `PASS-M5D-MEASURE-LOG` literal (line count 18
and the pinned name set, `dev/gates.sh:2371-2401`) does not move;
pin 13 binds `gate_timed` legs only.  Watchdog tier: `"$MED"`, the
tier the M5A strict legs use; no numeric literal.  Variables
available at this point in the file and reused: `$ROOT`, `$watchdog`,
`$guard` (`dev/gates.sh:443`), `$fx` (`dev/gates.sh:444`),
`$tot_scratch` (`dev/gates.sh:425`, cleaned by the EXIT trap at 434).
No loops anywhere below.

**The PASS-M5D-TIERS coordination (added 2026-09-03).**  The four
legs below add EIGHT direct watchdog-plus-tier calls (all `"$MED"`)
and delete none.  The TIERS live-literal rule (dev/gates.sh:2244-2250
at HEAD) binds this stage.  In the SAME commit: run
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before
the gates.sh edit (predicted 126, Stage A's exit; 122 at HEAD) and
after (expect entry + 8 = 134); raise the `-eq` literal in the TIERS
leg (HEAD:2260) by EXACTLY eight from the measured entry value;
append a dated sentence to the TIERS comment; record both numbers in
dev/M6-BUILD-LOG.md (pin 17).  Without this edit the battery cannot
reach GATE-EXIT=0 at the Stage B boundary (exit criterion 1).

```zsh
# ---- M6 Stage B (plan B8): the blocking Unit strict-json posture
# (verdict pins 5-6, ruling R3).  Four legs.  None is gate_timed, so
# the PASS-M5D-MEASURE-LOG literal (count 18, pinned name set) does
# not move.  The IO Unit fixture is GENERATED into the Gate D scratch
# dir on purpose (the m5a-envelope.tot precedent): a new
# test/fixtures/*.tot would enter the gen-m5e-transcript.sh glob and
# force a transcript reseal this stage does not need (pin 14).
printf 'def main : IO Unit := let* String Unit raw := readStdin in printLine raw\n' \
  > "$tot_scratch"/m6b-unit-echo.tot
m6b_uerr="$tot_scratch/m6b-unit-echo.tot:stdin is not a single well-formed JSON value, and this installation runs with --strict-json"
m6b_env='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"strict-json: stdin is not a single well-formed JSON value"}}'
m6b_err_f=$(mktemp "${TMPDIR:-/tmp}/tot-gate-m6b-err.XXXXXX")

# PASS-M6B-UNIT-STRICT-EXIT2 (pin 5, ruling R3).  Under --strict-json
# a malformed stdin payload on an IO Unit script exits 2 with the
# SAME single stderr line M5 printed at exit 1 (tight ":" after the
# argv path), and NOTHING on stdout.  The explicit -ne 1 is the
# NEGATIVE of the migration: it states in the leg's own text that the
# OLD exit-1 route is gone (at HEAD this run measured exit=1, plan
# B0 P1/P11).  MUTATION PROOF: plan B9 rows M-B1, M-B2, M-B3.
m6b_x1=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --strict-json \
  "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json 2>"$m6b_err_f"); m6b_x1c=$?
m6b_x1e=$(cat "$m6b_err_f")
{ [ "$m6b_x1c" -eq 2 ] && [ "$m6b_x1c" -ne 1 ] && [ -z "$m6b_x1" ] \
    && [ "$m6b_x1e" = "$m6b_uerr" ]; } \
  && echo PASS-M6B-UNIT-STRICT-EXIT2 \
  || {
    printf '%s\n%s\n' "$m6b_x1" "$m6b_x1e"
    echo "FAIL-M6B-UNIT-STRICT-EXIT2 (exit=$m6b_x1c)"
    exit 1
  }

# PASS-M6B-UNIT-STRICT-NOMAP (pin 5).  The refusal is the literal 2
# under EVERY --serror-exit value: 0 (a fail-open install cannot
# remap it to a silent allow), 1 (the sharp one: it distinguishes
# the literal 2 from BOTH dead routes at once, the old literal 1 and
# a route through the default mapping, which is also 1), and 7 (the
# mapping value plainly not taken; at HEAD this run measured exit=1,
# plan B0 P2).  Same stderr line, empty stdout, all three.
# MUTATION PROOF: plan B9 row M-B2.
m6b_n0=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --serror-exit 0 \
  --strict-json "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json \
  2>"$m6b_err_f"); m6b_n0c=$?
m6b_n0e=$(cat "$m6b_err_f")
m6b_n1=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --serror-exit 1 \
  --strict-json "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json \
  2>"$m6b_err_f"); m6b_n1c=$?
m6b_n1e=$(cat "$m6b_err_f")
m6b_n7=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --serror-exit 7 \
  --strict-json "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json \
  2>"$m6b_err_f"); m6b_n7c=$?
m6b_n7e=$(cat "$m6b_err_f")
{ [ "$m6b_n0c" -eq 2 ] && [ "$m6b_n1c" -eq 2 ] && [ "$m6b_n7c" -eq 2 ] \
    && [ -z "$m6b_n0" ] && [ -z "$m6b_n1" ] && [ -z "$m6b_n7" ] \
    && [ "$m6b_n0e" = "$m6b_uerr" ] && [ "$m6b_n1e" = "$m6b_uerr" ] \
    && [ "$m6b_n7e" = "$m6b_uerr" ]; } \
  && echo PASS-M6B-UNIT-STRICT-NOMAP \
  || {
    printf '%s\n%s\n%s\n' "$m6b_n0e" "$m6b_n1e" "$m6b_n7e"
    echo "FAIL-M6B-UNIT-STRICT-NOMAP (exit=$m6b_n0c/$m6b_n1c/$m6b_n7c)"
    exit 1
  }

# PASS-M6B-VERDICT-STRICT-IDENTITY (pin 6).  The IO Verdict half of
# the strict posture does not move: deny envelope on stdout, nothing
# on stderr, exit 2, and --serror-exit 7 cannot touch it (the
# ok-path literal, surface/run.ml Rejected arm).  Byte-identical to
# the HEAD before-picture (plan B0 P6/P7).  MUTATION PROOF: plan B9
# row M-B5.
m6b_v1=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --strict-json \
  "$guard" < "$fx"/garbage.json 2>"$m6b_err_f"); m6b_v1c=$?
m6b_v1e=$(cat "$m6b_err_f")
m6b_v2=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run --serror-exit 7 \
  --strict-json "$guard" < "$fx"/garbage.json); m6b_v2c=$?
{ [ "$m6b_v1c" -eq 2 ] && [ "$m6b_v1" = "$m6b_env" ] && [ -z "$m6b_v1e" ] \
    && [ "$m6b_v2c" -eq 2 ] && [ "$m6b_v2" = "$m6b_env" ]; } \
  && echo PASS-M6B-VERDICT-STRICT-IDENTITY \
  || {
    printf '%s\n%s\n' "$m6b_v1" "$m6b_v2"
    echo "FAIL-M6B-VERDICT-STRICT-IDENTITY (exit=$m6b_v1c/$m6b_v2c)"
    exit 1
  }

# PASS-M6B-OPEN-IDENTITY (pin 6).  WITHOUT the flag both shapes keep
# the fail-open posture byte-identical to HEAD: the Unit script
# echoes the garbage and exits 0 (the printLine echo PRECEDES the
# per-item def line, and the payload's own trailing newline yields
# the interior blank line: plan B0 P4/P10 measured these exact
# bytes), and the Verdict guard allows at exit 0 with empty stdout
# (plan B0 P8).  This is the leg that keeps "default off" honest for
# the UNIT shape, which no M5 leg covered (plan B0 P15).
# MUTATION PROOF: plan B9 row M-B4.
m6b_owant=$'not json at all\n\ndef main : (IO Unit)'
m6b_o1=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run \
  "$tot_scratch"/m6b-unit-echo.tot < "$fx"/garbage.json 2>"$m6b_err_f"); m6b_o1c=$?
m6b_o1e=$(cat "$m6b_err_f")
m6b_o2=$("$watchdog" "$MED" "$ROOT"/_build/default/bin/tot.exe run \
  "$guard" < "$fx"/garbage.json); m6b_o2c=$?
{ [ "$m6b_o1c" -eq 0 ] && [ "$m6b_o1" = "$m6b_owant" ] && [ -z "$m6b_o1e" ] \
    && [ "$m6b_o2c" -eq 0 ] && [ -z "$m6b_o2" ]; } \
  && echo PASS-M6B-OPEN-IDENTITY \
  || {
    printf '%s\n%s\n' "$m6b_o1" "$m6b_o2"
    echo "FAIL-M6B-OPEN-IDENTITY (exit=$m6b_o1c/$m6b_o2c)"
    exit 1
  }
rm -f "$m6b_err_f"
# ---- end of the M6 Stage B section
```

Gate criteria restated as the M5 sections state theirs:

    (i)    Both suites stay green with the two B7 additions; no
           existing test term is edited.
    (ii)   The Unit refusal exits 2 with the unchanged stderr line
           and an empty stdout, and the OLD exit-1 route is provably
           gone.
    (iii)  No --serror-exit value can move the refusal: 0, 1 and 7
           all yield the literal 2.
    (iv)   The Verdict strict posture and BOTH fail-open postures are
           byte-identical to the Stage A battery's binary.

---

### B9. Mutation table

Every mutation is applied to the Stage-B-complete tree, flipped RED,
then restored; the restore proof is `md5 -q` equality against the
hash captured immediately before the mutation, per the
`dev/M5-BUILD-LOG.md:1549-1593` template.  Where the predicted first
red is an UPSTREAM M5 leg (the battery exits at its first FAIL, and
the M5A strict legs sit at `dev/gates.sh:1844-1886`, far upstream of
the M6B block), the proof additionally REPLAYS the M6B leg's own
commands against the mutated binary by hand and records the replayed
transcript in the build log, so the stage's own leg is proven
non-vacuous and never certified by an upstream leg's flip alone.

| mutation | predicted flip route | restore proof |
|---|---|---|
| M-B1: `bin/tot.ml` driver arm literal `2` back to `1` (the HEAD posture) | battery reddens at `FAIL-M6B-UNIT-STRICT-EXIT2 (exit=1)`, the `-eq 2`/`-ne 1` pair; nothing upstream can flip first because NO earlier leg runs a Unit script under the flag (B0 P15) | revert; `md5 -q bin/tot.ml` equals the pre-mutation capture |
| M-B2: driver arm returns `serror_exit` instead of the literal `2` (routes the refusal INTO the mapping) | first red `FAIL-M6B-UNIT-STRICT-EXIT2 (exit=1)` (default mapping value); hand-replay of the NOMAP leg's three runs records exit 0/1/7 under `--serror-exit 0/1/7`, the exact remap the leg exists to refuse | revert; `md5 -q bin/tot.ml` equals the capture |
| M-B3: `prerr_endline` becomes `print_endline` in the driver arm (channel swap) | `FAIL-M6B-UNIT-STRICT-EXIT2`: exit stays 2 but `[ -z "$m6b_x1" ]` fails (line lands on stdout) and `[ "$m6b_x1e" = "$m6b_uerr" ]` fails (stderr empty); proves the channel assertions are live, not decoration | revert; `md5 -q bin/tot.ml` equals the capture |
| M-B4: `bin/tot.ml:237` default `strict_json = false` becomes `true` | first red UPSTREAM at `FAIL-M5A-STRICT-ALLOW` (assertion (c), the unflagged garbage guard run exits 2, `dev/gates.sh:1864-1886`); hand-replay of the OPEN-IDENTITY leg records the Unit half at exit 2 with the stderr line (not exit 0 with the echo) and the guard half at exit 2 with the envelope (not exit 0 empty) | revert; `md5 -q bin/tot.ml` equals the capture |
| M-B5: `surface/run.ml:538` Verdict deny literal `2` becomes `1` | first red UPSTREAM at `FAIL-M5A-STRICT-DENY (exit=1/1)` (`dev/gates.sh:1844-1862`); hand-replay of the VERDICT-STRICT-IDENTITY leg records exit 1 on both runs with the envelope bytes intact, flipping the leg's `-eq 2` pair | revert; `md5 -q surface/run.ml` equals the capture |

Record each row in `dev/M6-BUILD-LOG.md` as: the exact edit, the
battery's first FAIL line, the replayed transcript where the table
calls for one, the restore command, and the two md5 values.

---

### B10. SPEC edits

Three edits, one file.  The M5 Stage A entry at SPEC.md:783-798 is
NOT touched: the decision log is append-only history, and its exit-1
sentence stays true OF M5.  The new entry supersedes it by date.

**1.  Section 2, new dated entry** (append in date order; the text
below is the pinned wording, the migration note included; adjust only
the marker cross-references if Stage A renumbered anything):

    - 2026-09-03 (M6, Stage B): the blocking Unit strict-json posture
      (M6 verdict pins 5-6, ruling R3).  Under `--strict-json` a stdin
      payload that is not one well-formed JSON value on an `IO Unit`
      script now exits 2;  it was exit 1 from M5 Stage A through M6
      Stage A.  The single stderr line is unchanged byte for byte
      (`<path>:stdin is not a single well-formed JSON value, and this
      installation runs with --strict-json`, tight `:` after the argv
      path), stdout stays empty, and the refusal stays OUTSIDE the
      `--serror-exit` mapping: the literal 2 under every configured
      value, so a fail-open install (`--serror-exit 0`) cannot remap
      the refusal to a silent allow and no configuration can demote it
      to a non-blocking 1.  This closes the disclosed
      `IO Verdict`-only gap in the fail-closed story: the PreToolUse
      harness treats exit codes other than 0 and 2 as non-blocking
      (the M5 Stage C budget entry records the same harness rule), so
      the old exit-1 route was non-blocking by construction.  The
      delta is one literal in the driver's `Serror.driver_exit`
      classification arm;  `Serror.Json_strict_reject`, its stderr
      text, `Effect.dispatch`'s `readStdin` guard and the Verdict
      deny envelope are all byte-identical
      (`PASS-M6B-VERDICT-STRICT-IDENTITY`, `PASS-M6B-OPEN-IDENTITY`
      pin the unchanged postures;  `PASS-M6B-UNIT-STRICT-EXIT2`,
      `PASS-M6B-UNIT-STRICT-NOMAP` pin the new one).  MIGRATION NOTE
      (the sole mitigation, ruling R3): an installation whose harness
      distinguished exit 1 from exit 2 on `tot run --strict-json`
      over an `IO Unit` guard must treat the refusal as BLOCKING from
      this version on;  that is the point of the change.  No flag
      restores the exit-1 route and no new opt-in flag exists.  To
      tell a strict-json refusal from any other exit-2 path (the
      Verdict deny, the unknown-flag contract), match the stderr
      LINE, not the code, the same discrimination rule the budget
      exit 3 already documents.

**2.  Section 3, the fail-closed sentence** (SPEC.md:1188-1190).
After "the flag is enforced by the driver at the `readStdin`
boundary, so the guard script itself needs no edit", append one
sentence:

    Since M6 Stage B the fail-closed spelling covers both driver
    shapes: an `IO Unit` guard's strict-json refusal also exits 2
    (one stderr line, stdout empty), so a harness that blocks on
    exit 2 blocks on it.

**3.  Section 5, the candidate bullet** (SPEC.md:1345-1347).  Delete
the bullet "A blocking `--strict-json` posture for `IO Unit`
scripts. ..." from the future-work list: it is shipped, and the new
section 2 entry is its record.  Leave the rest of the list exactly as
Stage A left it.

---

### B11. Deliberate non-changes

1. `surface/effect.ml`: ZERO bytes.  The `Rejected` constructor
   (line 23), `strict_json_reason` (31), `deny_envelope` (48), the
   `run_io` short circuit (171) and the `Read_stdin` guard (238-239)
   all stay.  The stage-exit md5 must equal the Stage-B-entry value
   (at HEAD: `b50915fdb47b92d2f117fc83ca0ff6e3`; re-capture at entry
   if Stage A moved the file, which pin 7 gives no reason for).
2. `surface/run.ml` CODE: `run_unit_main` still returns
   `Error Serror.Json_strict_reject` (line 559) and
   `run_verdict_main`'s arm still reads
   `Ok ([ Effect.deny_envelope reason ], 2)` (line 538).  Comments
   only (B3).
3. `surface/serror.ml` CODE: all three predicates keep their arms;
   `driver_exit Json_strict_reject` stays `true`; the constructor
   stays enumerated `false` at lines 108 and 120; `to_string` and
   `tag` are byte-identical.  Comments only (B3).
4. The `--serror-exit` mapping arm (`bin/tot.ml:109-111`), the
   default `serror_exit = 1` (`bin/tot.ml:235`) and the 0..255 range
   check: untouched.
5. The missing-main and unusable-target driver contracts stay at
   exit 1 (`bin/tot.ml:103-105`, `bin/tot.ml:63-64`); the budget
   contract stays at exit 3 (`bin/tot.ml:99-102`).  No verdict pin
   moves them, and exit 1 remains correct for installation errors
   that are not payload decisions.
6. NO new flag and no opt-in deferral (ruling R3: the direct change).
7. NO new file in `test/fixtures/` or `examples/`: the gate generates
   its Unit fixture into scratch (B6), so `gen-m5e-transcript.sh`'s
   corpus and `dev/m5e-default-transcript.txt` do not move and pin 14
   is not triggered.  `PASS-M5E-DEFAULT-IDENTITY` must stay green
   with an UNCHANGED transcript file.
8. No `gate_timed` leg, so the `PASS-M5D-MEASURE-LOG` literal (count
   18, pinned name set) is untouched (pin 13 binds `gate_timed` legs
   only).
9. `Cache.format_version` stays 10 (pin 15); nothing in this stage is
   within reach of the cache.
10. The M5A strict legs (`PASS-M5A-STRICT-DENY`,
    `PASS-M5A-STRICT-ALLOW`) and suite cases M5A-14/15: unchanged.
    They pin the Verdict and flag-off postures, which do not move.
11. `check` mode stays inert under the flag (P9): no epilogue, no
    `readStdin`, no change.
12. The SPEC section 2 M5 Stage A entry (SPEC.md:783-798): not
    edited (append-only log; see B10).
13. The usage string: unchanged this stage (Stage A already rewrote
    it for the flag deletion; `--strict-json` stays listed).

---

### B12. Stage B exit criteria

1. `dev/gates.sh` runs to completion with GATE-EXIT=0 and 0 FAIL.
2. The walk chains from Stage A's MEASURED exit number (target 339),
   not from 334.  The arithmetic is 339 + 4 + 2 = 345: B8 adds 4 gate
   markers, B7 adds 2 surface cases, and the battery replays both
   suites into its own stdout (`dev/gates.sh:93` and
   `dev/gates.sh:95`, the SUITE-KERNEL and SUITE-SURFACE wrappers),
   so every suite case counts once.  Decomposition at target: 105 kernel + 109 surface +
   131 gate markers = 345.  Report the measured number with this
   decomposition and hand it to Stage C; Stage C chains from the
   MEASURED number.
3. All four `PASS-M6B-*` markers print, and they are exactly the four
   the verdict allocates: `PASS-M6B-UNIT-STRICT-EXIT2`,
   `PASS-M6B-UNIT-STRICT-NOMAP`, `PASS-M6B-VERDICT-STRICT-IDENTITY`,
   `PASS-M6B-OPEN-IDENTITY`.  No pre-existing marker is missing or
   renamed; the single pre-existing leg edit is the B8 TIERS literal
   raise, and `PASS-M5D-TIERS` still prints green with the literal at
   entry + 8 (predicted 134), the before/after `rg -c` numbers in the
   build log.
4. Every B9 mutation ran, flipped RED on its predicted route (with
   the leg-level replay recorded wherever the predicted first red is
   an upstream M5A leg), and was restored md5-identical.
   `dev/M6-BUILD-LOG.md` records each per the M5 template.
5. The migration is externally visible EXACTLY once: re-running the
   B0 probe set against the Stage B binary reproduces every transcript
   byte-identically EXCEPT P1/P2/P3/P11, which now report exit=2 with
   the same stderr line and the same empty stdout.  P4 through P10
   are byte-identical, exit codes included.  Record the re-run in the
   build log.
6. `md5 -q surface/effect.ml` equals the value captured at Stage B
   entry (B11 item 1), and `diff` on `dev/m5e-default-transcript.txt`
   against Stage A's sealed copy is empty (B11 item 7).
7. The three SPEC edits of B10 are in, the section 2 entry carries
   the migration note verbatim, and the section 5 bullet is gone.
8. `git status --porcelain` shows the edits UNSTAGED and NOTHING
   committed.  The preamble's ground rule binds this stage: do not
   run `git add`, do not run `git commit`.  Print the porcelain
   output in the stage report; the user stages and commits.

Do not start Stage C until every item above holds.

## STAGE C: holes core (pins 1 to 4) and the underscore reservation

Goal: `_` becomes a reserved token, and an expected-type-only hole
pass fills the leading erased Type arguments the corpus spells by
hand today. Stage C implements verdict pins 1, 2, 3 and 4 and ruling
R2 (HARD reservation). The whole implementation lives in `surface/`.
No file under `lib/` changes. That is not a convenience; it is how
pin 1 is discharged by construction: the kernel cannot gain typing
power from a milestone that never touches it.

The stage adds five gate markers and about ten surface-suite tests.
It adds no kernel test, because it adds no kernel behavior. Entry
count is 345 (Stage B exit). Exit target is 360.

Probe discipline for this section: every current-behaviour claim
below was executed on 2026-09-03 against the prebuilt HEAD binary
`_build/default/bin/tot.exe` at 8d5a839. Probe fixtures live in
`/Users/oobi/Documents/tot-m6-probes/plan-stage-c/`. Each probe
names its command. Per pin 17, every rg- or script-derived count
ships with the exact command that produced it.

### C0. Entry state, measured

The classifier baseline (pin 4), re-run this session:

    $ python3 dev/hole-anchors.py | wc -l
    148
    $ python3 dev/hole-anchors.py | tail -1
    ANCHORS total=98 expected-type-only=59 argument-driven=9 neither=30
    $ python3 dev/hole-anchors.py --count-sites
    98

Bucket splits used by this stage and Stage E, with commands:

    $ python3 dev/hole-anchors.py | rg 'bucket=E' | rg -c 'prelude'
    40
    $ python3 dev/hole-anchors.py | rg 'bucket=E' | rg -c 'examples/'
    19
    $ python3 dev/hole-anchors.py | rg 'bucket=E' | rg -c 'guard\.tot'
    7

So E = 59 decomposes as 40 prelude anchors (M7 debt, untouched) plus
19 example anchors (Stage E re-spells them). guard.tot carries 7 E
sites plus 2 A sites (the arg=0 anchors at guard.tot:133 and 134),
which is pin 4's "NINE sites".

The underscore token at HEAD is an ordinary identifier character and
an ordinary identifier start (surface/lexer.ml:9-12, read at HEAD:
`is_ident_start` accepts `'_'`, `is_ident_char` adds digits and
`'\''`). The three pin-2 shapes therefore CHECK today. Probed:

    $ tot.exe check underscore-def.tot        # def _ : Nat := succ zero
                                              # def g : Nat := _
    def _ : Nat
    def g : Nat
    exit=0
    $ tot.exe check underscore-lam.tot        # def f : Nat -> Nat := fun _ => _
    def f : (w _ : Nat) -> Nat
    exit=0
    $ tot.exe check underscore-match.tot      # succ _ => _ branch
    def h : (w _ : Nat) -> Nat
    exit=0

An UNBOUND `_` in term position is an unknown name, and it rides the
ordinary `--serror-exit` mapping. Probed:

    $ tot.exe check hole-unbound.tot          # def g : Nat := _
    hole-unbound.tot:1:16: unknown name _
    exit=1
    $ tot.exe check --serror-exit 0 hole-unbound.tot
    hole-unbound.tot:1:16: unknown name _
    exit=0

The corpus is clean. Zero bare `_` tokens outside comments, zero
`_`-named globals:

    $ rg -n "(^|[^A-Za-z0-9_'])_($|[^A-Za-z0-9_'])" stdlib/prelude.tot examples/*.tot
    examples/guard-rewrap.tot:7:-- next tokens, the `Ok(_)` as a block TAIL, and the bound name
    examples/guard-rewrap.tot:8:-- genuinely used inside the `Ok(_)`.  It scrubs comments and strings,
    (exit 0; both hits sit inside -- comments, which the lexer strips)
    $ rg -n '^\s*(reducible\s+)?(def(\s+rec)?(\s+partial)?|data|axiom|class)\s+_([^A-Za-z0-9_]|$)' stdlib/prelude.tot examples/*.tot
    (no output, exit 1)

This re-verifies the judge's sweep and strengthens it: the shipped
corpus has zero `_` uses in ANY position, binder positions included.

Four more HEAD behaviours this stage changes or must preserve, all
probed:

    $ tot.exe check w-underscore-pi.tot       # def k : (w _ : Nat) -> Nat := fun n => n
    def k : (w _ : Nat) -> Nat
    exit=0
    $ tot.exe check dup-underscore-pattern.tot  # | cons _ _ => zero branch
    dup-underscore-pattern.tot:1:68: parse error: duplicate binder _ in pattern
    exit=1
    $ tot.exe check leading-underscore-ident.tot  # def _foo : Nat := zero; def useIt : Nat := _foo
    def _foo : Nat
    def useIt : Nat
    exit=0
    $ tot.exe check anon-binder.tot           # def c : Nat -> Nat := fun _ => zero
    def c : (w _ : Nat) -> Nat
    exit=0

The conservativity oracle's vehicle, probed (a `check` item prints
the STAMPED elaborated term, so a fill is visible in output):

    $ tot.exe check check-print.tot   # check (cons String "x" (nil String) : List String)
    (((cons String) "x") (nil String)) : (List String)
    exit=0

The marker namespace is free (pin 16):

    $ rg -c "PASS-M6" dev/gates.sh
    (no output, exit 1 = zero matches)

Cold and warm bootstrap agree byte for byte at HEAD, which Gate C (v)
leg (b) turns into a pinned identity:

    $ tot.exe check examples/guard.tot > warm.out          # exit 0, stderr empty
    $ TOT_CACHE_DIR=<fresh dir> tot.exe check examples/guard.tot > cold.out   # exit 0
    $ cmp warm.out cold.out
    (identical; the fresh dir gains one prelude-*.bin and one exeid-*.txt)

Corpus size at Stage C entry: Stage A moved test/fixtures from 74
`.tot` files (`ls test/fixtures/*.tot | wc -l` = 74 at HEAD) to 79,
so the transcript corpus is 85 (6 examples + 79 fixtures). One HEAD
wrinkle the identity legs must respect: `examples/nat.tot` exits 1
at HEAD (`tot.exe check examples/nat.tot` prints
`examples/nat.tot:2:1: duplicate global Nat`, probed). The
transcript pins that failure as the file's recorded output.
"Corpus zero-break" therefore means BYTE-IDENTITY TO THE TRANSCRIPT,
never "all examples exit 0".

### C1. Scope fences, stated as fences

1. No `lib/` file changes. `Term.t` gains no constructor (pin 1).
   The kernel checker, evaluator, eraser and printer are byte-
   identical to Stage B.
2. Resolution is expected-type-only and rigid (pin 3). No
   metavariables, no constraint store, no postponement, no guessing
   from later arguments, no defaults. A hole the rule cannot fill is
   an error, never a guess.
3. The reservation is the exact token `_`. Identifiers that merely
   START with `_` (probe: `_foo` above) stay ordinary identifiers.
4. The hole error is an ordinary `Serror` inside the `--serror-exit`
   mapping, exactly like `unknown name` today (probed above at
   exit 0 under `--serror-exit 0`). Pin 3 pins the line and the
   default exit 1; it does not exempt the mapping.
5. `Cache.format_version` stays 10 (surface/cache.ml:118, read at
   HEAD: `let format_version : int = 10`). Nothing this stage
   marshals changes shape: the cache stores kernel `Global.t`
   entries, and `Term.t` does not change. Pin 15.
6. Stage C touches no shipped `.tot` file. stdlib/prelude.tot and
   examples/*.tot are byte-identical at Stage C exit. The example
   re-spell is Stage E's (ruling R5).
7. Stage C adds no `gate_timed` leg, so PASS-M5D-MEASURE-LOG's
   literal count and name set (dev/gates.sh:2371-2401) are
   untouched. Pin 13 binds Stage D, not Stage C.

### C2. surface/token.ml and surface/lexer.ml: the reservation

`Token.kind` gains one constructor:

```ocaml
  | Underscore
      (** M6 Stage C (verdict pin 2, ruling R2): the reserved token
          [_].  Term position: a hole ([Syntax.SHole]).  Binder
          position: the anonymous binder, the same display name "_"
          the printer already uses.  Never a definable or
          referencable name.  Reserved as the EXACT token: [_foo],
          [_1] and [_'] stay ordinary identifiers. *)
```

`Token.describe` gains `| Underscore -> "'_'"`. The compiler then
names every other `Token.kind` match; the full list is in C3.

The lexer change is ONE data row. `keywords`
(surface/lexer.ml:14-37) gains:

```ocaml
    ("_", Token.Underscore);  (** M6 Stage C, ruling R2 *)
```

That is the entire lexer delta. The identifier scanner
(surface/lexer.ml:128-131) is untouched: it still scans the maximal
identifier and asks `ident_kind` for the kind, and `ident_kind`
already routes exact keyword strings through the table. `_` alone
maps to `Underscore`; `_foo` misses the table and stays
`Ident "_foo"`. `is_ident_start`/`is_ident_char` keep `'_'`, so
mid-identifier underscores are untouched. This is also why the
un-reserve mutation (C11, MUT-C1) is one deleted line.

### C3. surface/parser.ml: hole atom, binder positions, name positions

Three kinds of position, three rules.

TERM position: `parse_atom` (surface/parser.ml:329-355) gains one
arm, mirroring the `KAuto` arm at 332:

```ocaml
  | { Token.kind = Token.Underscore; loc } :: rest -> Ok (Syntax.SHole loc, rest)
```

and `kind_starts_atom` (surface/parser.ml:39-49) returns `true` for
`Underscore`, so a hole can stand as an application argument, a
`let*` type-argument atom (parse_let_star parses two atoms,
surface/parser.ml:151-154), and an `inst` argument.

BINDER position: `_` is accepted everywhere a binder name is bound,
and produces the name `"_"`, which the reservation itself makes
unreferencable (an SVar can never be `_` again, so anonymity is a
theorem of the grammar, not a scope-table trick). The touched
consumers, each read at HEAD:

- `collect_idents` (surface/parser.ml:57-62) gains an `Underscore`
  arm yielding `"_"`. This one change covers `fun` binders
  (parse_fun:104), Pi binder groups (try_binder_group:274), match
  branch patterns (parse_branches:244) and motive index binders
  (parse_match:191).
- `parse_let` (:122) and `parse_let_star` (:156): the bound-name
  pattern accepts `Underscore` as `"_"` next to `Ident x`.
- `parse_match`'s two `as x` patterns (:187, :214): same.
- `quantity_prefix` (surface/parser.ml:75-81): the lookahead that
  keeps `w` a marker only when a binder follows must also accept
  `Underscore` as that follower. Without this, `(w _ : Nat) -> Nat`
  silently reparses as TWO binders `w` and `_` over the same
  domain. The shape is legal and meaningful at HEAD (probe
  `w-underscore-pi.tot` above prints `def k : (w _ : Nat) -> Nat`),
  and it is the exact spelling the printer emits, so the printed
  types in the M5E transcript remain round-trippable. Gate C (iv)
  leg (d) pins it; MUT-C6 flips it.
- `parse_branches`' duplicate-binder fence (:245-251): `find_dup`
  skips `"_"` entries. See design note C13-N4: two anonymous
  binders collide only if `_` can be referenced, and it no longer
  can. Probed HEAD behavior being changed:
  `dup-underscore-pattern.tot:1:68: parse error: duplicate binder _
  in pattern`, exit 1. After Stage C the same file checks at
  exit 0.

NAME position (definable names): no new code at all. `parse_def_body`
(:419), `parse_data` (:446), `parse_data_params` (:504),
`parse_ctors` (:529), `parse_class` (:559), `parse_class_methods`
(:583) and the `axiom` item arm (parse_items:381) all pattern-match
on `Token.Ident`. An `Underscore` token falls through to each
site's existing "expected NAME ... found" error with
`Token.describe` rendering `'_'`. The pinned shape for pin 2's
`def _` fixture:

    m6c-underscore-def.tot:1:5: parse error: expected 'NAME : TYPE := TERM' after 'def', found '_'

The plan pins that exact line in Gate C (iv); the same fall-through
covers `data _`, `axiom _`, `class _`, ctor and method names, and a
suite test asserts the `def` and `data` cases.

### C4. surface/syntax.ml: SHole, revived

`Syntax.t` gains:

```ocaml
  | SHole of Loc.t
      (** M6 Stage C (verdict pins 1-3): a term-position [_].  Lives
          ONLY in surface syntax: [Elab] either fills it from the
          expected type or fails with [Serror.Hole], so no kernel
          term ever contains one and [Term.t] has no counterpart.
          Revives the M3-C3 [SHole] that the FALLBACK SHAPE dropped;
          [SLetStar]'s two explicit type-argument slots may now hold
          one. *)
```

The compiler then names every exhaustive `Syntax.t` match. Complete
list at HEAD (command: `rg -n 'SAuto' surface/*.ml`, taking the
match sites; `SAuto` appears in every `Syntax.t` match because the
codebase bans catch-all arms):

- surface/syntax.ml:110 `loc_of`: `| SHole loc -> loc`.
- surface/parser.ml:32 `describe_syntax`: `| SHole _ -> "'_'"`.
- surface/parser.ml:491 `peel_data_codomain`: `SHole` joins the
  reject arm ("expected 'Type'"), so a data codomain hole is a
  parse-shaped error.
- surface/elab.ml:23 `term`: the infer-position arm, C6.
- surface/bootstrap.ml:90: prim-type elaboration rejects it with
  the existing arm (a prim type with a hole is a build bug, not a
  user state).
- surface/run.ml:148 `peel_syntax_codomain`, :158 `syntax_spine`,
  :173/:178 `instance_key`, :376 the `IClass` param check: `SHole`
  joins each existing reject/no-op arm.

Doc-comment maintenance in the same commit, so no stale "no SHole"
claim survives: `Syntax.SLetStar`'s comment (surface/syntax.ml:27-35),
`parse_let_star`'s comment (surface/parser.ml:144-150) and `Elab`'s
`SLetStar` comment (surface/elab.ml:66-76) each gain one M6 sentence
noting the slots may now hold holes.

### C5. surface/serror.ml: the hole error, structured

One new constructor, the scope-in 6 slice of the SPEC.md:1356-1358
debt ("errors carry mostly pre-rendered strings, not structured
values"):

```ocaml
  | Hole of {
      loc : Loc.t;
      expected : (string list * Tot_kernel.Term.t) option;
    }
      (** M6 Stage C (verdict pin 3): an unresolved hole.
          [expected = Some (names, ty)] carries the expected type as
          a STRUCTURED kernel term plus the binder-name stack it is
          scoped under (innermost first, the same convention
          [Pp.term] consumes), rendered only at print time.
          [None]: the hole sits in a position no expected type
          reaches (infer position).  An ordinary mapped Serror: the
          [--serror-exit] contract applies, exactly as for
          [Unknown_name]. *)
```

`to_string` gains:

```ocaml
  | Hole { loc; expected = Some (names, ty) } ->
      Printf.sprintf "%s: hole: expected %s" (Loc.to_string loc)
        (Tot_kernel.Pp.term names ty)
  | Hole { loc; expected = None } ->
      Printf.sprintf "%s: hole: no expected type at this position" (Loc.to_string loc)
```

The driver prints `path ^ ":" ^ Serror.to_string e`
(bin/tot.ml:104-110, read at HEAD), which yields exactly pin 3's two
shapes:

    <file>:<line>:<col>: hole: expected <TYPE>
    <file>:<line>:<col>: hole: no expected type at this position

`<TYPE>` is rendered by the EXISTING printer `Pp.term`
(lib/pp.ml:29), the same one the transcript's `def` lines already
exercise, so `Nat` prints `Nat`, `List String` prints
`(List String)`, and a function type prints `(w _ : Nat) -> Nat`.
No new printer is written.

`tag` gains `| Hole _ -> "Hole"`. The constructor-exhaustive
predicates (`is_missing_main`, `is_check_budget`, and the other
`Serror` classifiers) each list the new constructor on their false
side; the compiler names all of them. `bin/tot.ml` itself does not
change: `Hole` takes the default Serror path (stderr line, exit 1,
`--serror-exit` applies).

First-error discipline is inherited, not implemented: elaboration is
a `Result` fold, so the first unresolved hole in elaboration order
(left to right in the source) aborts the item, and the driver prints
one line. Gate C (ii) pins one-line stderr on every negative.

### C6. surface/elab.ml: the check-position twin

`Elab.term` stays what it is: scope resolution for INFER positions.
It gains exactly one arm:

```ocaml
  | Syntax.SHole loc -> Error (Serror.Hole { loc; expected = None })
```

The new entry point is the check-position twin:

```ocaml
val term_at :
  Global.t -> string list -> expected:Term.t -> Syntax.t ->
  (Term.t, Serror.t) result
```

INVARIANTS, stated once and relied on everywhere:

1. `expected` is a PRE-TERM (elaborator output, `Many` stamps)
   scoped over exactly the same binder stack as `scope`.
2. On hole-free input, `term_at` returns byte-for-byte what `term`
   returns. Each `term_at` arm builds the same node its `term`
   sibling builds; only `SHole` handling and the descent threading
   differ. This is the conservativity argument's first half.
3. `term_at` never invents a term. A fill is always a sub-term of
   `expected` or of a declared global type instantiated with such
   sub-terms, spliced into the pre-term and then checked by the
   UNCHANGED kernel. A wrong fill is a kernel error downstream,
   never a silent acceptance. This is the second half: the checker
   re-derives every consequence, so the elaborator cannot smuggle
   typing power (pin 1).

Activation sites, in surface/run.ml (both currently plain
`Elab.term` calls, read at HEAD):

- `IDef` bodies, run.ml:240: `Elab.term_at elab_globals []
  ~expected:ty_t def`. The declared type `ty_t` (elaborated at :221)
  is the root expected type. Both `def` and `def rec` (the
  provisional-self-entry globals at :226-239 are unchanged).
- `IInstance` bodies, run.ml:446: `Elab.term_at st.globals []
  ~expected:ty_t def`.

Everything else stays `Elab.term`: `ICheck`/`IEval` items
(run.ml:468, 477) are infer positions; declared types, data
parameter/index/ctor types, axiom types and class method types are
type positions with no expected type. A hole in any of those is the
`expected = None` error. The classifier never counted such sites,
so nothing in E = 59 is lost.

THE DESCENT SET. `term_at globals scope ~expected s` matches `s`:

- `SHole loc`: a bare hole in check position never resolves (it is
  not a spine slot). Error:
  `Hole { loc; expected = Some (scope, expected) }`. This is the
  dogfood message: `def g : Nat := _` reports
  `hole: expected Nat`.
- `SLam (loc, x, body)` when `expected` is syntactically
  `Term.Pi (_q, _y, _dom, cod)`: recurse `term_at` on `body` under
  `x :: scope` with expected `cod`. No shift: the Pi codomain is
  scoped under its binder, which lands on the same de Bruijn slot
  the lambda binder occupies (invariant 1 is preserved
  definitionally). Output node identical to `term`'s SLam arm.
  When `expected` is not a syntactic Pi (an alias, a Var): fall
  back to `term` on the whole SLam; holes inside then report
  `expected = None`. Rigid means rigid; no evaluation in the
  elaborator, ever.
- `SLet (loc, x, ty, def, body)`: `ty` via `term` (type position);
  `def` via `term_at` with expected = elaborated `ty` (the
  annotation is the def's expected type); `body` via `term_at`
  under `x :: scope` with expected
  `Term.shift ~cutoff:0 ~by:1 expected` (M5's `Term.shift`,
  lib/term.ml:110, is exactly the tool; invariant 1 forces the
  shift under every binder the expected type did not itself bind).
- `SAnn (loc, tm, ty)`: `ty` via `term`; `tm` via `term_at` with
  expected = elaborated `ty`. Output `Term.Ann`, same as `term`.
- `SLetStar (loc, is_div, ty_a, ty_b, x, rhs, body)`: the desugar
  target is the spine
  `bind{IO,Div} ty_a ty_b rhs (fun x => body)`, so the spine rule
  below applies with head `bindIO`/`bindDiv` and the leading slots
  `(ty_a, ty_b)`. Operationally: attempt the rigid match of the
  head's declared result type (`IO B` resp. `Div B`, from
  `Global.entry_ty` of the prim, declared at
  surface/bootstrap.ml:104-108 with the M3 spellings, read at
  HEAD: `bindIO : (0 A : Type 0) -> (0 B : Type 0) -> IO A ->
  (A -> IO B) -> IO B`) against `expected`; that can fill a `ty_b`
  hole and can never fill a `ty_a` hole (the result type does not
  mention `A`, which is exactly why the classifier buckets `let*`
  arg 0 as A and arg 1 as E). Then, left to right: an unfilled
  hole among the two slots errors at its own loc with
  `expected = Some (scope, Term.Univ Level.zero)` (the slot's
  declared domain, see the spine rule); `rhs` via `term_at` with
  expected `App (Many, Global "IO"|"Div", A_t)` built from the
  (explicit or filled) first slot; `body` via `term_at` under
  `x :: scope` with the shifted outer expected. The built output
  spine is byte-identical to `term`'s SLetStar arm
  (surface/elab.ml:65-86) on hole-free input.
- `SMatch (loc, scrut, None, branches)` (no explicit motive):
  `scrut` via `term` (infer position, matching the kernel's
  constant-motive rule that checks every branch at the expected
  type, lib/check.ml:1150-1183); each branch body via `term_at`
  under its pattern binders with expected shifted by the binder
  count. With an explicit motive (`Some sm`): fall back to `term`
  entirely; the kernel routes explicit-motive check-position
  matches through infer (check_node:1146-1149), so no expected
  type reaches the branches without evaluation, which the rigid
  slice refuses to do.
- `SApp`: the spine rule below.
- Everything else (`SVar`, `SType`, `SPi`, `SStr`, `SInt`, `SAuto`,
  `SInst`): delegate to `term`. A hole nested in one of those is
  an `expected = None` error, matching the classifier (such sites
  are bucket N).

THE SPINE RULE, the classifier's E rule made operational (pin 3;
the classifier's own statement of the rule is SPEC.md:1022-1023 and
dev/hole-anchors.py steps 1-3):

Uncurry the `SApp` chain to `(head, args)`. The rule activates only
when `head` is `SVar (_, g)`, `g` is NOT bound in `scope` (locals
shadow globals, surface/elab.ml:24-29; a shadowed head has no
declared type), and `Global.find g` yields an entry. Let `gty =
Global.entry_ty entry` (closed, checked, lib/global.ml:105).

1. k := the count of leading `(0 X : Type L)` binders of `gty`, by
   syntactic peel (a `leading_type_binders` helper on `Term.t`
   mirroring dev/hole-anchors.py:170-184). For a data former the
   declared `ind_ty` opens with its 0-marked params; for a ctor the
   declared `ctor_ty` opens with the family's params
   (lib/global.ml:55: `ctor_ty` is closed over
   `0-params -> args -> I params indices`); prims carry their
   bootstrap types. No special cases: `entry_ty` covers all five
   entry kinds.
2. THE FAMILY FENCE. If `g` is a class former, or `gty` mentions a
   proof family or a class former, no hole in this spine resolves;
   the first `SHole` among the leading k args errors with
   `expected = Some (scope, <its declared Type-L domain>)`, and the
   remaining args elaborate via `term`. "Mentions" is
   `Totality.mentions` (lib/totality.ml:47-70, already exported,
   walks `Term.Global` occurrences through every arm). Proof
   families are the literal set {Eq, Dec, Empty}, the same
   PROOF_TOKENS the classifier hard-codes at dev/hole-anchors.py:69,
   cross-cited in a comment. Class formers: see the detector below.
   The fence exists because pin 4 BINDS the N bucket to failure:
   without it, `refl _ zero` against expected `Eq Nat zero zero`
   would resolve by rigid matching (the codomain `Eq A a a`
   mentions the leading formal), and the pass would exceed its
   ratified perimeter.
3. FILL. Rigid first-order match of `gty`'s final codomain (peel
   ALL Pi domains, k leading and the rest) against `expected`,
   ignoring quantity stamps (the declared side carries checked
   stamps, the expected side carries `Many` pre-term stamps; the
   kernel re-stamps output, so stamps carry no information here).
   Match rules: a Var referring to one of the k leading formals
   captures the aligned sub-term of `expected`; two captures of the
   same formal must be syntactically equal terms; a Var referring
   to any OTHER telescope binder blocks the whole match; all other
   node pairs must agree constructor-wise. On success, each
   captured sub-term is the fill for its formal's slot. A hole in
   slot i takes fill i; an EXPLICIT leading arg keeps its own
   spelling (the kernel checks agreement downstream). Left to
   right, a leading `SHole` with no capture errors with
   `expected = Some (scope, dom_i)` where `dom_i` is the slot's
   declared domain, always a `Term.Univ` (`hole: expected Type 0`);
   truthful, deterministic, and exactly the pin-3 first shape.
4. ARGUMENT DESCENT. After the leading slots are settled, each
   remaining argument position j gets `term_at` with expected =
   the declared domain `dom_j` instantiated by substituting the
   settled leading args (fills and explicit spellings, elaborated)
   for their formals, PROVIDED `dom_j` mentions no other telescope
   binder; otherwise that argument elaborates via `term`. The
   instantiation helper (`inst_domain`, in elab.ml, about forty
   lines) substitutes the k leading formals and refuses on any
   surviving telescope Var, with `Term.shift` handling binder
   crossings inside the domain. This is what lets
   `cons _ "grep" (cons _ "sed" (nil _))` resolve all three holes:
   the outer fill String closes `cons`'s later domains
   (`A`, `List A` become `String`, `List String`), and the inner
   spines see those as their expected types. Leading slots
   themselves descend with expected `dom_i = Type L`, so a hole
   INSIDE a leading type argument (e.g. `nil (Option _)`) reports
   `hole: expected Type 0` rather than resolving; a type-former's
   codomain (`Option : (0 A : Type 0) -> Type 0`) captures nothing.

CLASS-FORMER DETECTION, cache-proof by construction. The prelude
DECLARES classes (`class EqD/OrdD/ShowD`, stdlib/prelude.tot:163-165,
read at HEAD), and a warm bootstrap restores `Global.t` from the
cache WITHOUT re-folding items, so no per-run "I saw an IClass"
registry can be sound. `Global.t` carries no class flag, and giving
it one is a marshaled-shape change that pin 15 forbids this
milestone. The detector is therefore structural, matching exactly
what the desugar builds (surface/run.ml:363-391, read at HEAD: one
`IData` with one param, no indices, single ctor `"mk" ^ name`):

```ocaml
(* [g] is (shaped like) a class former: one 0-marked param, no
   indices, exactly one ctor named "mk" ^ g.  Mirrors the [IClass]
   desugar at surface/run.ml:379.  Over-approximation is SAFE: a
   fenced head refuses holes, it never mis-fills one. *)
```

Over-approximation audit, probed: the only shipped `mk`-named
sole-ctor family is `ProcessResult`
(`rg -n '\| mk' stdlib/prelude.tot examples/*.tot` yields exactly
`stdlib/prelude.tot:22: ... | mkProcessResult : ...`), and it has
ZERO params, so it does not match the detector. Zero false
positives in the shipped corpus; the over-approximation note is
C13-N3.

### C7. What resolves, what refuses: the ceiling, kept honest

Pin 4 verbatim: E = 59 is a ceiling, not a promise. The measuring
stick is `dev/hole-anchors.py`, which is UNTOUCHED by this stage
(deliberate non-change, C12). The classifier is static and does not
run the checker; the implementation above additionally refuses
where rigidity or the descent set stops short (aliased expected
types, explicit-motive branches, dependent later domains). The
count the pass ACTUALLY solves is measured at Stage E against the
re-spelled examples and recorded in a dated SPEC entry
(PASS-M6E-ANCHORS owns it). Stage C promises only:

- every fixture shape in C8's positive twin resolves (gate-pinned);
- the 9 A anchors and 30 N anchors, re-spelled with `_`, fail with
  a pin-3 line (gate- and suite-pinned on representatives of each
  bucket; Stage E's re-spell keeps them explicit, so the shipped
  corpus never tests the refusal accidentally);
- nothing resolves through a proof-family or class-family head.

The two buckets map to the two message shapes deterministically:
check-position refusals (A anchors, fenced N anchors, bare holes)
carry `hole: expected <TYPE>`; infer-position holes (the N
anchors' infer share, `eval _`, scrutinees, arguments of local
heads) carry `hole: no expected type at this position`.

### C8. Stage C fixtures, complete list

Eleven new files in test/fixtures/. Corpus arithmetic: 85 at entry,
96 at exit (6 examples + 90 fixtures). Per pin 14 the transcript is
regenerated IN THE SAME COMMIT (`dev/gen-m5e-transcript.sh` globs
both directories, read at HEAD), the old/new diff is reviewed and
must be ADDITIONS-ONLY (eleven new `### test/fixtures/m6c-*` blocks,
zero changed lines in the 85 pre-existing blocks), and the count 96
is recorded in the Stage C SPEC entry and build log.

Positives (twins; identical def names, differ only at `_`):

1. `m6c-hole-e.tot`:

```
-- M6 Stage C (pin 1): every hole below is expected-type-only.
-- Twin: m6c-hole-e-explicit.tot.  Byte-identical check output is
-- PASS-M6C-HOLE-RESOLVES.
def flagged : List String := cons _ "grep" (cons _ "sed" (nil _))
def idList : (0 A : Type 0) -> List A -> List A :=
  fun A xs => match xs with | nil => nil _ | cons h t => cons _ h t end
def main : IO Verdict :=
  let* String _ raw := readStdin in
  pureIO _ (deny raw)
check (cons _ "x" (nil _) : List String)
check ((fun xs => idList _ xs) : List Nat -> List Nat)
```

   Coverage by construction: def-root spine fill (`flagged`),
   nested argument descent (the inner `cons` and `nil`), LOCAL
   binder fill under pattern binders (`idList`'s branches fill
   `Var`s pointing at the `fun A` binder, through one and two
   pattern binders, which is what MUT-C4's shift-drop flips),
   `let*` B-slot fill from the def root, body descent
   (`pureIO _`), SAnn root fill (first `check`), and SLam peel
   under SAnn (second `check`). `deny : String -> Verdict` and
   `readStdin : IO String` per stdlib/prelude.tot:21 and
   surface/bootstrap.ml:121.

2. `m6c-hole-e-explicit.tot`: the same file with `String`,
   `String`, `String`, `A`, `A`, `Verdict`, `Verdict`, `String`,
   `String`, `Nat` written out. Its check output at HEAD semantics
   is derivable today; the twins' equality is asserted by the gate,
   not by a committed golden.

3. `m6c-underscore-binders.tot`:

```
-- M6 Stage C (ruling R2): binder-position underscores stay legal,
-- a leading-underscore identifier is not reserved, and two
-- anonymous pattern binders do not collide.
def k : (w _ : Nat) -> Nat := fun _ => zero
def two2 : List Nat -> Nat := fun xs => match xs with | nil => zero | cons _ _ => succ zero end
def _foo : Nat := succ zero
def useIt : Nat := _foo
```

   Predicted output (confirmed against the built binary before the
   gate is committed, the M5E discipline):

```
def k : (w _ : Nat) -> Nat
def two2 : (w _ : (List Nat)) -> Nat
def _foo : Nat
def useIt : Nat
```

Negatives (each fails with ONE pinned line; predicted lines below
carry hand-computed columns and are confirmed against the built
binary before the gates are committed):

4. `m6c-underscore-def.tot` (pin 2 fixture, byte-identical to the
   judge's probe): `def _ : Nat := succ zero` then
   `def g : Nat := _`. Before (probed above): exit 0. After:

       m6c-underscore-def.tot:1:5: parse error: expected 'NAME : TYPE := TERM' after 'def', found '_'

5. `m6c-underscore-lam.tot` (pin 2): `def f : Nat -> Nat := fun _
   => _`. Before: exit 0. After, the binder `_` is anonymous and
   LEGAL; the body `_` is a bare hole in check position, so this
   fixture now exercises the hole path, exactly as the verdict's
   pin 2 text says ("each term-position `_` takes the hole path"):

       m6c-underscore-lam.tot:1:32: hole: expected Nat

6. `m6c-underscore-match.tot` (pin 2): the `succ _ => _` shape.
   Before: exit 0. After (pattern `_` legal, branch-body `_` is a
   hole checked at the constant-motive expected type):

       m6c-underscore-match.tot:1:72: hole: expected Nat

7. `m6c-hole-a.tot`, the A-bucket representative:

```
def main : IO Verdict :=
  let* _ Verdict raw := readStdin in
  pureIO Verdict allow
```

       m6c-hole-a.tot:2:8: hole: expected Type 0

8. `m6c-hole-n-infer.tot`, the N-bucket infer-position
   representative: `eval _`.

       m6c-hole-n-infer.tot:1:6: hole: no expected type at this position

9. `m6c-hole-n-proof.tot`, the proof-family fence:
   `def agree : Eq Nat zero zero := refl _ zero`.

       m6c-hole-n-proof.tot:1:38: hole: expected Type 0

10. `m6c-hole-n-class.tot`, the class-family fence:
    `def isFlagged : String -> Bool := fun c => member _ auto c
    (cons String "grep" (nil String))` (`member`'s declared type
    mentions `EqD`, stdlib/prelude.tot:175).

        m6c-hole-n-class.tot:1:51: hole: expected Type 0

11. `m6c-hole-run.tot`, the never-runs witness:

```
def main : IO Unit := let* _ Unit x := printLine "SIDE-EFFECT" in pureIO Unit x
```

        m6c-hole-run.tot:1:28: hole: expected Type 0

    The string "SIDE-EFFECT" must never appear on stdout in either
    driver mode; `printLine : String -> IO Unit`
    (surface/bootstrap.ml:122).

### C9. Stage C surface tests (test/main.ml untouched)

Ten cases appended to `Tot_surface_test`'s `cases` list
(test/surface.ml:773), each through `Run.script` or the suite's
existing expect-error helper, no new helper kinds:

1. `m6c_fill_root`: the `flagged` def from fixture 1 as an inline
   script; its lines equal the explicit twin's lines.
2. `m6c_fill_branch_local`: the `idList` def; lines equal the
   explicit twin's. This is the under-binder local-Var fill.
3. `m6c_fill_letstar`: the `main` def from fixture 1; lines equal
   the twin's.
4. `m6c_fill_nested_arg`: `check (cons _ "x" (nil _) : List
   String)` produces exactly
   `(((cons String) "x") (nil String)) : (List String)` (the HEAD
   spelling, probed in C0).
5. `m6c_refuse_a`: fixture 7's body; error text contains
   `2:8: hole: expected Type 0` and nothing after the first line.
6. `m6c_refuse_infer`: `eval _` reports
   `1:6: hole: no expected type at this position`; second assert in
   the same case: `def g : Nat := let x : _ := zero in x` reports
   the no-expected line at the annotation hole (annotation holes
   are out of scope by design, C6).
7. `m6c_refuse_proof_fence`: fixture 9's body; the pinned line.
8. `m6c_refuse_class_fence`: fixture 10's body; the pinned line.
9. `m6c_reserved_names`: `def _ : Nat := zero` and
   `data _ : Type 0 :=` each produce their C3 fall-through parse
   error naming `'_'`.
10. `m6c_binder_positions`: fixture 3's four lines, byte-exact,
    plus a def whose body is `let* Unit Unit _ := printLine "x" in
    pureIO Unit unit` checking at exit 0 (the discarded `let*`
    binder is the one binder position fixture 3 cannot carry, and
    the types are spelled so the def checks clean:
    `printLine "x" : IO Unit`).

Kernel suite: ZERO new tests, stated as a deliberate non-change:
Stage C adds no kernel behavior to test, and an accidental
kernel-test addition would falsify the "lib/ untouched" fence.

Suite arithmetic: surface 109 at entry (107 at HEAD, +2 in
Stage B), 119 at exit. Kernel stays 105 (Stage A's retirement).

### C10. Gate C, verbatim

Five markers. Namespace collision-free at HEAD (pin 16, probed in
C0: `rg -c "PASS-M6" dev/gates.sh` prints nothing, exit 1; zero
matches is the required state, shown by the empty output, not by a
printed 0). Placement: after the Stage B block, BEFORE the two
branching legs, which stay the file's tail (the round-5 placement
that pin 13 records). The scratch joins the shared EXIT trap: the
trap line dev/gates.sh:434 gains `"$m6c_scratch"`. Every leg runs
under a named tier; no numeric watchdog literal appears
(PASS-M5D-TIERS keeps asserting that on exit status). No leg below
is `gate_timed` (C1 fence 7). All want-lines below are confirmed
against the built binary before the gate is committed, the M5E
discipline.

**The PASS-M5D-TIERS coordination (added 2026-09-03).**  The block
below adds SEVENTEEN direct watchdog-plus-tier calls (14 FAST, 2 MED,
1 SLOW) and deletes none.  The TIERS live-literal rule
(dev/gates.sh:2244-2250 at HEAD) binds this stage.  In the SAME
commit: run
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before
the gates.sh edit (predicted 134, Stage B's exit; 122 at HEAD) and
after (expect entry + 17 = 151); raise the `-eq` literal in the TIERS
leg (HEAD:2260) by EXACTLY seventeen from the measured entry value;
append a dated sentence to the TIERS comment; record both numbers in
dev/M6-BUILD-LOG.md (pin 17).  Without this edit the battery cannot
reach GATE-EXIT=0 at the Stage C boundary (C15 item 1).

```zsh
# ---------------------------------------------------------------------
# M6 Stage C: holes core (verdict pins 1-4), underscore reservation
# (ruling R2).  Five markers.  All fixtures committed under
# test/fixtures/, so the transcript corpus grew 85 -> 96 in this
# stage's own commit (pin 14) and Gate C (v) leg (a) holds the reseal.
# ---------------------------------------------------------------------
m6c_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m6c.XXXXXX")

# Gate C (i), PASS-M6C-HOLE-RESOLVES.  The conservativity oracle
# (pin 1): the holed fixture and its explicit twin check at exit 0
# with byte-identical output.  The sentinel rg kills the both-empty
# vacuous pass.  MUT-C3 and MUT-C4 must flip this leg.
outh=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-e.tot 2>&1)
codeh=$?
oute=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-e-explicit.tot 2>&1)
codee=$?
{ [ "$codeh" -eq 0 ] && [ "$codee" -eq 0 ] && [ "$outh" = "$oute" ] \
    && printf '%s\n' "$outh" | rg -q 'def flagged : \(List String\)'; } \
  && echo PASS-M6C-HOLE-RESOLVES \
  || {
    printf '%s\n---\n%s\n' "$outh" "$oute"
    echo "FAIL-M6C-HOLE-RESOLVES (exit=$codeh/$codee)"
    exit 1
  }

# Gate C (ii), PASS-M6C-HOLE-REPORTS.  One A-shaped and three
# N-shaped refusals, each exit 1, stdout EMPTY, stderr exactly one
# pinned pin-3 line.  MUT-C2 flips legs (c)/(d); MUT-C3 flips (a).
outa=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-a.tot 2> "$m6c_scratch"/a.err)
codea=$?
outb=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-infer.tot 2> "$m6c_scratch"/b.err)
codeb=$?
outc=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-proof.tot 2> "$m6c_scratch"/c.err)
codec=$?
outd=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-class.tot 2> "$m6c_scratch"/d.err)
coded=$?
{ [ "$codea" -eq 1 ] && [ "$codeb" -eq 1 ] && [ "$codec" -eq 1 ] && [ "$coded" -eq 1 ] \
    && [ -z "$outa" ] && [ -z "$outb" ] && [ -z "$outc" ] && [ -z "$outd" ] \
    && [ "$(wc -l < "$m6c_scratch"/a.err)" -eq 1 ] \
    && rg -q 'm6c-hole-a\.tot:2:8: hole: expected Type 0' "$m6c_scratch"/a.err \
    && rg -q 'm6c-hole-n-infer\.tot:1:6: hole: no expected type at this position' "$m6c_scratch"/b.err \
    && rg -q 'm6c-hole-n-proof\.tot:1:38: hole: expected Type 0' "$m6c_scratch"/c.err \
    && rg -q 'm6c-hole-n-class\.tot:1:51: hole: expected Type 0' "$m6c_scratch"/d.err; } \
  && echo PASS-M6C-HOLE-REPORTS \
  || {
    cat "$m6c_scratch"/a.err "$m6c_scratch"/b.err "$m6c_scratch"/c.err "$m6c_scratch"/d.err
    echo "FAIL-M6C-HOLE-REPORTS (exit=$codea/$codeb/$codec/$coded)"
    exit 1
  }

# Gate C (iii), PASS-M6C-HOLE-NEVER-RUNS.  A holed file never
# reaches eval: run refuses BEFORE main, stdout stays empty, and the
# serror mapping moves only the exit code, never the effects.
outr=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe run \
  "$ROOT"/test/fixtures/m6c-hole-run.tot 2> "$m6c_scratch"/r.err)
coder=$?
outs=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe run \
  --serror-exit 0 "$ROOT"/test/fixtures/m6c-hole-run.tot 2> "$m6c_scratch"/s.err)
codes=$?
{ [ "$coder" -eq 1 ] && [ "$codes" -eq 0 ] \
    && [ -z "$outr" ] && [ -z "$outs" ] \
    && rg -q 'm6c-hole-run\.tot:1:28: hole: expected Type 0' "$m6c_scratch"/r.err \
    && rg -q 'm6c-hole-run\.tot:1:28: hole: expected Type 0' "$m6c_scratch"/s.err \
    && { rg -q 'SIDE-EFFECT' "$m6c_scratch"/r.err; [ $? -eq 1 ]; }; } \
  && echo PASS-M6C-HOLE-NEVER-RUNS \
  || {
    cat "$m6c_scratch"/r.err "$m6c_scratch"/s.err
    echo "FAIL-M6C-HOLE-NEVER-RUNS (exit=$coder/$codes)"
    exit 1
  }

# Gate C (iv), PASS-M6C-UNDERSCORE-RESERVED.  The three pin-2
# fixtures fail with their pinned lines (legs a-c), and the binder
# positions stay green with the exact four-line output (leg d).
# MUT-C1 flips leg (a); MUT-C5 and MUT-C6 flip leg (d).
outud=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-underscore-def.tot 2> "$m6c_scratch"/ud.err)
codeud=$?
outul=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-underscore-lam.tot 2> "$m6c_scratch"/ul.err)
codeul=$?
outum=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-underscore-match.tot 2> "$m6c_scratch"/um.err)
codeum=$?
outub=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-underscore-binders.tot 2>&1)
codeub=$?
wantub=$'def k : (w _ : Nat) -> Nat\ndef two2 : (w _ : (List Nat)) -> Nat\ndef _foo : Nat\ndef useIt : Nat'
{ [ "$codeud" -eq 1 ] && [ "$codeul" -eq 1 ] && [ "$codeum" -eq 1 ] && [ "$codeub" -eq 0 ] \
    && [ -z "$outud" ] && [ -z "$outul" ] && [ -z "$outum" ] \
    && rg -q "m6c-underscore-def\.tot:1:5: parse error: expected 'NAME : TYPE := TERM' after 'def', found '_'" "$m6c_scratch"/ud.err \
    && rg -q 'm6c-underscore-lam\.tot:1:32: hole: expected Nat' "$m6c_scratch"/ul.err \
    && rg -q 'm6c-underscore-match\.tot:1:72: hole: expected Nat' "$m6c_scratch"/um.err \
    && [ "$outub" = "$wantub" ]; } \
  && echo PASS-M6C-UNDERSCORE-RESERVED \
  || {
    cat "$m6c_scratch"/ud.err "$m6c_scratch"/ul.err "$m6c_scratch"/um.err
    printf '%s\n' "$outub"
    echo "FAIL-M6C-UNDERSCORE-RESERVED (exit=$codeud/$codeul/$codeum/$codeub)"
    exit 1
  }

# Gate C (v), PASS-M6C-DEFAULT-IDENTITY.  Two legs.  Leg (a): the
# whole 96-file corpus is byte-identical to the transcript resealed
# in this stage's commit; the reseal diff was reviewed
# additions-only (pin 14).  Leg (b): a COLD bootstrap under a fresh
# private cache re-lexes and re-checks the prelude through the
# reserved lexer and agrees byte for byte with the warm run; this is
# the stdlib half of the corpus-zero-break proof, which the
# transcript (examples + fixtures only) cannot see.  Probed green at
# HEAD in the plan's C0.
"$watchdog" "$SLOW" "$ROOT"/dev/gen-m5e-transcript.sh > "$m6c_scratch"/now.txt 2>&1
codet=$?
outw=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/examples/guard.tot 2>&1)
codew=$?
outcold=$(TOT_CACHE_DIR="$m6c_scratch"/cold "$watchdog" "$MED" \
  "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/examples/guard.tot 2>&1)
codecold=$?
outw2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/examples/guard-classes.tot 2>&1)
codew2=$?
outcold2=$(TOT_CACHE_DIR="$m6c_scratch"/cold2 "$watchdog" "$MED" \
  "$ROOT"/_build/default/bin/tot.exe check "$ROOT"/examples/guard-classes.tot 2>&1)
codecold2=$?
{ [ "$codet" -eq 0 ] \
    && diff -q "$ROOT"/dev/m5e-default-transcript.txt "$m6c_scratch"/now.txt > /dev/null \
    && [ "$codew" -eq 0 ] && [ "$codecold" -eq 0 ] && [ "$outw" = "$outcold" ] \
    && [ "$codew2" -eq 0 ] && [ "$codecold2" -eq 0 ] && [ "$outw2" = "$outcold2" ]; } \
  && echo PASS-M6C-DEFAULT-IDENTITY \
  || {
    diff "$ROOT"/dev/m5e-default-transcript.txt "$m6c_scratch"/now.txt | head -40
    echo "FAIL-M6C-DEFAULT-IDENTITY (exit=$codet/$codew/$codecold/$codew2/$codecold2)"
    exit 1
  }
```

Notes on the legs, for the reviewer:

- Gate C (i) compares the binary against ITSELF, the
  PASS-M5C-DETERMINISM idiom, so it cannot rot when an unrelated
  stage changes a printed type.
- Gate C (ii)'s `wc -l = 1` on the first stderr file pins
  first-error discipline once; the other three files are pinned by
  content, and the suite pins their one-line property again.
- Gate C (iii)'s final clause asserts the ABSENCE of the fixture's
  side-effect string on the error channel too; the empty-stdout
  checks assert it for the effect channel. Note `rg -q PAT FILE;
  [ $? -eq 1 ]` is the loop-free absence idiom already used in
  spirit by the M5 legs ("NO occurrence of fuel").
- Gate C (v) leg (b) uses `MED` for the cold runs (they write a
  fresh cache; probed at HEAD in C0 as sub-second, and MED is the
  tier for a leg that runs the CLI more than once in spirit).
- The cold cache dirs need no mkdir: the binary creates a missing
  `TOT_CACHE_DIR` itself. Probed at HEAD this session: pointing
  `TOT_CACHE_DIR` at a nonexistent path, `check examples/guard.tot`
  exits 0 with empty stderr, output byte-identical to the warm run,
  and the directory afterward holds one `prelude-*.bin` plus one
  `exeid-*.txt`.
- The cold cache dirs live under the stage scratch and die with the
  EXIT trap.

### C11. Mutation proofs

Each mutation is applied alone, the battery run, the predicted leg
observed RED with the predicted route, the file restored, and the
restore proven md5-identical (`md5 -q <file>` recorded before the
mutation and after the restore; dev/M5-BUILD-LOG.md:1549-1593 is the
template). Every flip is recorded in dev/M6-BUILD-LOG.md with the
command and observed exit.

| id | mutation | predicted flip route | restore proof |
| --- | --- | --- | --- |
| MUT-C1 | delete the `("_", Token.Underscore)` row from `keywords` (surface/lexer.ml) | `_` lexes as `Ident "_"` again. The battery stops at the first red leg in file order: Gate C (i), because the holed fixture dies as `unknown name _` at exit 1 against the twin's 0. Run alone, Gate C (iv) leg (a) shows the reservation loss directly: `m6c-underscore-def.tot` reverts to the probed HEAD behavior (exit 0, `def _ : Nat`), missing the pinned parse-error line. Both observations are recorded | `md5 -q surface/lexer.ml` identical before/after |
| MUT-C2 | delete the family fence in the spine rule (elab.ml: treat every head as plain) | `refl _ zero` and `member _ ...` resolve by rigid match; `m6c-hole-n-proof.tot` and `m6c-hole-n-class.tot` check at exit 0; Gate C (ii) fails on `codec`/`coded` | `md5 -q surface/elab.ml` |
| MUT-C3 | make an unresolved leading hole FILL with its slot domain (`Term.Univ Level.zero`) instead of erroring, the pin-3 "never a default" violation made flesh | `m6c-hole-a.tot`'s stderr changes from the pinned hole line to a kernel mismatch (readStdin : IO String against IO (Type 0)); Gate C (ii) fails on the (a) line match; `m6c-hole-run.tot`'s stderr changes the same way, so Gate C (iii) fails its line match too | `md5 -q surface/elab.ml` |
| MUT-C4 | drop the `Term.shift` in the branch-body descent (shift `~by:0`) | `idList`'s branch fills capture the WRONG de Bruijn slot (the expected `List A` still names Var 0, which is a pattern binder inside the branch); the spliced fill mis-types and the holed twin exits 1 while the explicit twin stays 0; Gate C (i) fails on `codeh` | `md5 -q surface/elab.ml` |
| MUT-C5 | restore `_` participation in `find_dup` (parser.ml) | `m6c-underscore-binders.tot`'s `cons _ _` pattern is rejected as `duplicate binder _ in pattern` (the probed HEAD line); Gate C (iv) fails on `codeub` | `md5 -q surface/parser.ml` |
| MUT-C6 | drop the `Underscore` lookahead case from `quantity_prefix` (parser.ml) | `(w _ : Nat) -> Nat` reparses as TWO binders; `m6c-underscore-binders.tot` line 1 no longer prints `def k : (w _ : Nat) -> Nat` (the def either mis-checks or prints a two-binder Pi), so leg (d)'s byte-equality fails | `md5 -q surface/parser.ml` |

Reach note, stated honestly: Gate C (iii)'s "run never executes a
holed file" is STRUCTURAL at HEAD (Run.item elaborates and checks
each item before install, and stdout is suppressed on any failing
item; probed in C0 via examples/nat.tot, whose first item succeeds,
second fails, and stdout is empty). No cheap mutation makes eval
run FIRST without rewriting the driver loop; MUT-C3 is the leg's
mutation on the message half, and the structural half is carried by
the leg's assertions themselves, not by a mutation.

### C12. SPEC.md edits

Section 2 gains one dated `2026-09-03 (M6, Stage C)` block with four
entries:

1. **`_` is reserved (ruling R2).** The exact token, term position
   = hole, binder position = anonymous binder, never definable or
   referencable. The BEFORE picture recorded verbatim: the three
   probe lines of pin 2 (all exit 0 at 8d5a839), the
   duplicate-binder probe (`duplicate binder _ in pattern`, now
   legal), and the corpus sweep command from C0 with its two
   comment-only hits. The three fixtures land as pinned negatives.
2. **Expected-type-only holes (pins 1, 3).** The descent set, the
   spine rule, the family fence with its structural class-former
   detector and the {Eq, Dec, Empty} proof set cross-cited to
   dev/hole-anchors.py:69, the two error lines with their bucket
   mapping, conservativity (surface-only; `Term.t` unchanged;
   fills re-checked by the unchanged kernel), and the
   `--serror-exit` posture (ordinary mapped Serror).
3. **E = 59 stays a ceiling (pin 4).** The classifier command and
   its 148-line output recorded; the measured solve count is OWED
   BY STAGE E against the re-spelled examples (40 prelude anchors
   remain M7 debt).
4. **Structured hole error (scope-in 6).** `Serror.Hole` carries
   the expected type as a kernel term plus name stack; the
   SPEC.md:1356-1358 debt line is REWRITTEN to record the slice as
   partially paid (one constructor structured; the rest of the
   error surface unchanged).

Section 6 edits in the same commit: the "No holes, again"
residual (SPEC.md:1626-1643) is rewritten: holes EXIST for the
E slice; the line now carries the two structural reasons argument-
driven anchors still refuse (infer's one-argument App arm,
lib/check.ml:960-969, and check's absent App arm,
lib/check.ml:1208-1211, both cited at their HEAD locations), the
Stage C refusal semantics, and the A/N counts with the classifier
command.

### C13. Conflict and design notes, dated 2026-09-03

- **N1 (probe semantics, no drift).** Pin 16's collision oracle:
  `rg -c "PASS-M6" dev/gates.sh` prints NOTHING and exits 1 at
  HEAD (probed). The stage-walk instruction "must be 0" is
  satisfied as zero matches, evidenced by empty output and exit 1;
  `rg -c` never prints a literal 0 for a zero-match file. Recorded
  so nobody "fixes" the leg to expect a printed zero.
- **N2 (the fence is load-bearing, reading of pin 3 recorded).**
  Rigid matching ALONE would resolve proof-family and class-family
  anchors (`refl`'s codomain mentions its leading formal), which
  pin 4 forbids: the N bucket must FAIL. Pin 3's phrase "the
  classifier's E rule made operational" is therefore read as
  including the classifier's family split (its N rule takes
  precedence over E, dev/hole-anchors.py step 3), and the fence is
  implemented explicitly. Without this reading the two pins
  contradict; with it they compose. No pin text is altered.
- **N3 (class-former detection is structural).** `Global.t` has no
  class registry; adding one is a marshaled-shape change pin 15
  forbids, and a surface-side "saw IClass" set is unsound under a
  warm cache (the prelude declares EqD/OrdD/ShowD at
  stdlib/prelude.tot:163-165 and a cache HIT restores globals
  without re-folding items). The detector mirrors the desugar
  (one 0-param, no indices, sole ctor `"mk" ^ name`,
  surface/run.ml:379). It over-approximates on look-alike data;
  over-approximation REFUSES holes and can never mis-fill.
  Shipped-corpus audit: `rg -n '\| mk' stdlib/prelude.tot
  examples/*.tot` yields only `mkProcessResult` (zero params, not
  matched). M7 may carry a real registry when the `.mli` sweep
  reshapes `Global`.
- **N4 (a fourth behavior change, implied by R2).** HEAD rejects
  two `_` binders in one pattern (`duplicate binder _ in pattern`,
  probed). The reservation exempts `_` from the duplicate fence:
  the fence exists to keep pattern binders referencable without
  ambiguity, and `_` is no longer referencable at all. Pin 2 lists
  three breaking shapes; this fourth shape breaks in the OTHER
  direction (an error becomes legal), so no shipped file can be
  affected (the corpus has zero `_` binders, C0). Pinned by Gate C
  (iv) leg (d) and MUT-C5.
- **N5 (`(w _ : A)` must keep parsing as one binder).** The
  printer emits this shape today and the parser accepts it (probe
  `w-underscore-pi.tot`). The reservation changes the token kind
  under `quantity_prefix`'s lookahead, so the lookahead is extended
  or the shape silently becomes two binders. Pinned by leg (d) and
  MUT-C6.
- **N6 (the conservativity oracle needs `check` items to bite).**
  `tot check` prints only `def NAME : TYPE` for a def, so a
  def-body fill is invisible in def lines. A `check` ITEM prints
  the STAMPED term (probed:
  `(((cons String) "x") (nil String)) : (List String)`), so the
  twin fixtures carry check items exposing fills, and the def-body
  fill paths are additionally pinned by the suite through
  `Run.script` line comparison. Recorded so the byte-equality leg
  is never weakened to def-lines-only.
- **N7 (corpus zero-break means transcript identity).**
  `examples/nat.tot` exits 1 at HEAD (`duplicate global Nat`,
  probed), and the prelude is not user-checkable in either mode
  (probed: default exits 1 `duplicate global Bool`; `--no-prelude`
  exits 1 `unknown name String` at the first prim use). The
  zero-break proof is therefore (a) transcript byte-identity over
  examples + fixtures and (b) cold-bootstrap byte-identity for the
  prelude path, Gate C (v). Neither claims "everything exits 0".

### C14. Deliberate non-changes

1. `lib/` entirely: term.ml, check.ml, error.ml, eval.ml, pp.ml,
   totality.ml, global.ml, budget.ml, erase.ml, interp.ml,
   eterm.ml, level.ml, literal.ml, prim.ml, quantity.ml, value.ml,
   json_escape.ml. The stage consumes `Term.shift`,
   `Totality.mentions`, `Global.entry_ty` and `Pp.term` as they
   are.
2. `bin/tot.ml`: no flag, no exit-code change, no usage-string
   change. `Serror.Hole` rides the existing mapping.
3. `surface/cache.ml`: `format_version` stays 10. The cache key
   already carries the binary digest (SPEC.md:862-863), so the
   first post-build run re-lexes the prelude under the reserved
   lexer by construction; Gate C (v) leg (b) forces it
   deterministically besides.
4. `dev/hole-anchors.py`: byte-identical. The classifier is the
   measuring stick; Stage E re-runs it and re-records the ANCHORS
   line (pin 4). Changing the stick in the stage that ships the
   feature would let the feature grade itself.
5. `stdlib/prelude.tot`, `examples/*.tot`: byte-identical (ruling
   R5 puts the re-spell in Stage E; prelude re-spell is M7 debt).
6. `test/main.ml`: untouched; kernel count stays 105.
7. `dev/gen-m5e-transcript.sh`: untouched; it already globs the
   fixture directory, so the new fixtures enter the corpus with no
   script change.
8. The `--serror-exit` posture of hole errors: deliberately INSIDE
   the mapping (C1 fence 4); a fail-open install maps a hole to
   exit 0 exactly as it maps `unknown name` today, and Gate C
   (iii) pins that even then nothing executes.
9. Explicit-motive match branches, annotation holes, `SPi` domain
   holes, argument-driven (A) and N anchors: all REFUSE, by
   design, with the pin-3 lines; they are the M7 lanes the verdict
   names (bidirectional application checking; multi-hole
   reporting).

### C15. Exit criteria and arithmetic

1. Full battery green: GATE-EXIT=0, `rg -c '^PASS'` = 360, 0 FAIL
   (`rg -c '^FAIL'` matches nothing, exit 1).
   Decomposition: kernel suite 105 (unchanged from Stage A exit),
   surface suite 119 (109 + the ten C9 cases), gate markers 136
   (131 + the five C10 markers). 345 + 5 + 10 = 360, chaining
   334 -> 339 (A) -> 345 (B) -> 360 (C). Per the verdict's walk
   clause, a one-or-two count drift is tolerable; the marker
   names, the monotone walk and GATE-EXIT=0 are binding.
2. All five PASS-M6C-* markers present; no pre-existing marker
   lost by name (whole-output diff against the Stage B gate log,
   the M5 exit-criteria idiom).
3. Every MUT-C1..C6 flip observed with its predicted route and
   recorded in dev/M6-BUILD-LOG.md; every mutated file restored
   md5-identical.
4. The transcript reseal reviewed additions-only: eleven new
   sections, 85 old sections byte-identical, corpus count 96
   recorded in the SPEC entry (pin 14).
5. `PASS-M5E-DEFAULT-IDENTITY`, `PASS-M5D-HOLE-ANCHORS`,
   `PASS-M5D-MEASURE-LOG` and the two SUITE legs are green and
   unedited: these are the gates Stage C's edits pass closest to.
   `PASS-M5D-TIERS` is green with its literal raised by exactly 17
   (the C10 coordination; predicted 151), the before/after `rg -c`
   numbers in the build log.
6. The four SPEC entries of C12 are in, dated, with the C0 probe
   lines quoted verbatim and every count carrying its command
   (pin 17).
7. Handoffs recorded in the build log: Stage D inherits an
   untouched MEASURE-LOG literal; Stage E OWES the measured solve
   count (PASS-M6E-ANCHORS), the example re-spell (7 E sites in
   guard.tot re-spelled, its 2 A sites kept explicit), and the
   second reseal.

## STAGE D: the two cost legs (pins 11-13)

Owner of verdict scope item 5 and of design pins 11, 12 and 13, under
ruling R4 (the HIT-ratio threshold is 4.0).  Stage D ships NO change to
lib/, surface/ or bin/.  It ships three fixtures, five gate legs, two
gate-coordination edits, one transcript reseal and the SPEC entries.
Every leg goes green against the entry binary; the non-vacuity lives in
the mutation proofs and in the pre-count assertions, not in a
red-to-green flip (see D0-4).

### Entry state

Stages A, B and C are green.  Do not assume a number for the entry
count.  Run the battery once before you start, record
`dev/gates.sh 2>&1 | rg -c '^PASS'`, and use that number as the Stage D
baseline.  The verdict's walk expects 360 at Stage C exit and 365 at
Stage D exit; the monotone walk, the marker names and GATE-EXIT=0 are
the binding part, the exact count may drift by one or two.

Facts pinned against the built HEAD binary
`_build/default/bin/tot.exe` on 2026-09-03.  Every number below comes
from a run, not from a reading.  Probe fixtures and runner scripts live
in `/Users/oobi/Documents/tot-m6-probes/plan-stage-d/`.  The `P<n>`
labels are PROBE IDs, local to this section; they are not the verdict's
pins.  Cite a row here as `probe P<n>` and a verdict pin as `pin <n>`.

| Probe | Command | Result |
|---|---|---|
| P1 | `rg -c 'PASS-M6' dev/gates.sh` | no output, exit 1 (pin 16: no marker collision at HEAD) |
| P2 | `zsh -c 'print -l examples/*.tot test/fixtures/*.tot \| rg -c "\.tot$"'` | `80` (the pin-14 corpus at HEAD) |
| P3 | `tot.exe check m6d-hit-one.tot` (private warm `TOT_CACHE_DIR`) | stdout exactly `def flagged : (List String)` then `def u1 : Bool`, exit 0 |
| P4 | `tot.exe check m6d-hit-many.tot \| rg -c '^def '` | `65`, exit 0 |
| P5 | `runner-ratio.zsh` (median-of-9, bare runs) | `med_one=0.005 med_many=0.007`, ratio `1.40`, 9 of 9 exit 0 on each fixture |
| P6 | zsh float sanity: `(( 0.120 <= 4.0 * 0.030 ))` and `(( 0.121 <= 4.0 * 0.030 ))` | `1` then `0` (the leg's comparison form works) |
| P7 | `runner-overhead.zsh` (median-of-9, hit-one) | wrapped in `timeout 120`: 0.010; bare: 0.006 (wrapper cost about 4 ms) |
| P8 | cold run, fresh private `TOT_CACHE_DIR` | exit 0, elapsed 0.017; dir holds ONE `prelude-*.bin` plus one `exeid-*.txt`; warm rerun 0.006, stdout byte-identical, both stderr 0 bytes |
| P9 | three more cold samples, one warm | cold 0.024 / 0.018 / 0.014, warm 0.009 (cold window about 5 to 15 ms wall on this machine) |
| P10 | fresh dir, `check --check-budget-ms 5 m6d-hit-one.tot` | exit 0, empty stderr (pin 12's kept trivial-target probe, green at HEAD) |
| P11 | `m6d-bigcheck` shape (600 defs), warm | plain check exit 0; `--check-budget-ms 1` exit 3, EMPTY stdout, stderr exactly `<path>/big600.tot: check budget exhausted (1 ms)`; budgets 5, 10, 20 all exit 0; COLD dir at budget 5 exit 0, empty stderr |
| P12 | sizing sweep | 1100 defs: budgets 1 and 5 exit 3, 10 exit 0.  1500 defs: 5 exit 3, 10 to 60 exit 0.  3000-auto-def shape: warm 0.133 s, budget 1 exit 3 |
| P13 | header-comment invariance | a leading `--` comment line changes neither stdout nor any budget exit (hdr copies of hit-one and big600 reproduce P3 and P11 exactly) |
| P14 | `rg -c '"\$watchdog" "\$(FAST\|MED\|SLOW\|SUITE)"' dev/gates.sh` | `122`, matching the live literal `-eq 122` at dev/gates.sh:2260 |
| P15 | `rg -c 'gate_timed "\$' dev/gates.sh` | `18` call sites (rows and call sites differ by design; the gate refuses call-site derivation) |
| P16 | `rg -n 'trap ' dev/gates.sh` | line 434: one EXIT trap removes the five named scratches |
| P17 | `wc -l dev/m5e-default-transcript.txt` | `9660`; `dev/gen-m5e-transcript.sh:13` globs `examples/*.tot test/fixtures/*.tot` |
| P18 | `rg -n 'let save\|let load' surface/cache.ml` | `load` at 393, `save` at 432 |
| P19 | SPEC anchors read at HEAD | the cold-bootstrap debt sits at SPEC.md:873-879, the pin-5 cost-half debt opens at SPEC.md:1359 |
| P20 | build-log anchors read at HEAD | M9 re-derive record at dev/M5-BUILD-LOG.md:517-522 (6.212 s vs 0.034 s, 183x, no flip); C-C6 throttle record at 833-846 |
| P21 | full dry-run of the five legs of D3 to D7, verbatim, against the probe fixtures (`dryrun-legs.zsh`) | all five markers PASS; the log gains exactly `MEASURE M6D-HIT-BASELINE tier=10 elapsed=0.031 exit=0`, `MEASURE M6D-HIT-ONE tier=120 elapsed=0.010 exit=0`, `MEASURE M6D-HIT-MANY tier=120 elapsed=0.013 exit=0`, `MEASURE M6D-COLD-WINDOW tier=120 elapsed=0.028 exit=0`, each matching the D8 schema regex |

Code anchors, each verified by reading the file at HEAD 8d5a839:

- lib/check.ml:766-773: the instance-memo HIT path.  `InstMemo.find_opt
  mkey st.memo` at 766, `Result.fold ~ok:` arm at 769-773, the pin-5
  comment at 770-771 ("a HIT returns the slot and the CACHED value.  No
  lookup of the instance, no telescope peel, no eval"), `entry_val` at
  772.  The verdict's citation "770-773" is the `~ok` arm inside this
  span.  The mangled instance name `"inst$" ^ cls ^ "$" ^ k` sits at
  758.
- bin/tot.ml:37-47: `budget_of_ms`.  `Sys.time ()` (CPU seconds) at 41
  and 47; the 1024-poll throttle at 46
  (`not (Int.equal (!ticks land 1023) 0) -> false`), so the clock is
  read only at every 1024th poll.
- bin/tot.ml:98-102: the exit-3 arm and the exact stderr line
  `<path>: check budget exhausted (<ms> ms)`.
- bin/tot.ml:147-167: `run_with_prelude`.  The deadline is captured at
  165-166, after `cached_state_of_src` returns, with the M5C comment at
  158-164; this is the hoist mutation's target.
- surface/cache.ml:118: `format_version = 10`.  154-170:
  `cache_dir_opt`, `TOT_CACHE_DIR` read at 157 (pin 12 cites 154-160;
  the construct spans 154-170 at HEAD).  335: the store entry name,
  `"prelude-" ^ key ^ ".bin"`.  393 `load`, 432 `save`.
- dev/gates.sh:26-48: the tier block.  "A tier is a HANG ceiling, not a
  performance budget" at 30 (the brief's citation "31" drifted by one
  during M5E); `FAST=10 MED=30 SLOW=120 SUITE=300 BITE_S=1` at 44-48.
- dev/gates.sh:67-82: `gate_timed` (merges `2>&1`, appends one
  `MEASURE <name> tier=<n> elapsed=<f> exit=<d>` row to `$GATE_LOG`).
- dev/gates.sh:434: the EXIT trap over the five scratch dirs.
- dev/gates.sh:2237-2263: PASS-M5D-TIERS; the live literal `-eq 122` at
  2260 and its raise-by-what-you-add obligation at 2244-2250.
- dev/gates.sh:2371-2401: PASS-M5D-MEASURE-LOG; schema regex and
  `-eq 18` twice at 2390-2396, the literal name set at 2393, the
  refuses-count-derivation comment at 2373-2377.
- dev/gates.sh:2403-2471: the M5E legs (no gate_timed calls inside).
- dev/gates.sh:2473-2527: the two branching legs, the file's tail
  (M4FIX-INST-BRANCHING at 2504, M5B-BRANCHING-20 at 2522), then the
  GATE-LOG echo and `exit 0` at 2529-2534.

### D0. Conflict and interpretation notes (dated, binding on this section)

**D0-1 (2026-09-03).  Pin 13's placement clause, read literally, breaks
the gate it protects.**  Pin 13 places every new `gate_timed` leg
DOWNSTREAM of PASS-M5D-MEASURE-LOG and, in the same commit, extends
that gate's literal count and name set "to cover the new legs".  A leg
that logs after the gate asserts cannot be covered by the gate's count:
the extended `-eq` would read rows that do not exist yet and the gate
would go red.  Resolution, keeping the pin's intent (literal extension,
no call-site derivation, branching pair stays the tail): the M6D legs
land after the M5E block, and the whole PASS-M5D-MEASURE-LOG block MOVES
below them, still before the two branching legs.  The branching pair
stays the file's timing-sensitive tail exactly as round 5 placed it,
and the gate's "two DOWNSTREAM wrapped legs" comment stays true.

**D0-2 (2026-09-03).  The 18 timed runs go bare; the wrapper cost is
measured, not assumed.**  The house rule runs every leg under a named
watchdog tier.  Probe P7: the wrapper costs about 4 ms per spawn
(median 0.010 wrapped vs 0.006 bare), which is 80 percent of the
healthy hit-one signal on this machine and dilutes the mutated ratio
toward the 4.0 threshold (an additive constant on both sides pulls the
quotient toward 1).  Resolution: the ratio leg first proves each
fixture terminates under a WRAPPED run at SLOW in the same leg, then
times 9 bare runs per fixture.  `check` is deterministic (no IO, no
clock without a budget flag), so a computation that just exited 0
cannot hang on an identical rerun; the operator's external belt (M5
pin 9) still covers the battery as a whole.  Every other new run in
this stage is wrapped normally.

**D0-3 (2026-09-03).  Pin 11's healthy constants are machine-relative;
the ratio reproduces, the milliseconds do not.**  The judge measured
median-of-9 30.4 ms vs 39.0 ms, ratio 1.28.  This session, same
protocol, same fixtures shapes: 0.005 s vs 0.007 s, ratio 1.40 (P5).
The absolute times differ by 6x; both ratios sit far under 4.0.  The
leg therefore asserts ONLY the ratio and a positivity floor, never an
absolute time, and the SPEC entry records both measurement pairs with
their dates.  Threshold 4.0 is R4-ratified and does not move.

**D0-4 (2026-09-03).  The cold oracle is green on arrival; the perf
graft's "fails today" framing does not transfer.**  Probed (P8, P10):
at HEAD a fresh-dir run exits 0, matches the warm run byte for byte,
leaves exactly one `prelude-*.bin`, and a cold run under
`--check-budget-ms 5` exits 0.  Pin 12 demands presence, schema and the
entry-count assertion; it does not demand a red-first oracle, and Stage
D changes no binary behaviour that could turn one red.  Non-vacuity
comes from the mutation proofs (D12) and from the pre-count assertion
in D5.  Recorded so nobody hunts for a missing red state.

---

### D1. The three fixtures

All three land in `test/fixtures/`, so the pin-14 corpus grows 3 and
the transcript reseal in D10 is mandatory in the same commit.  None of
them enters the hole-anchor corpus (that corpus is prelude plus
examples only, test fixtures excluded on purpose), so the ANCHORS line
and PASS-M5D-HOLE-ANCHORS need no coordination.  A leading `--` header
comment changes neither stdout nor any budget exit (P13), so each file
carries one.

**`test/fixtures/m6d-hit-one.tot`** (pin 11), written literally:

    -- M6 Stage D (pin 11): ONE `member String auto` resolution.
    -- PASS-M6D-HIT-BASELINE pins this file's stdout; the ratio leg
    -- uses it as the denominator fixture.
    def flagged : List String := cons String "grep" (cons String "sed" (nil String))
    def u1 : Bool := member String auto "x" flagged

Checker stdout, pinned by P3 (do not paraphrase):

    def flagged : (List String)
    def u1 : Bool

**`test/fixtures/m6d-hit-many.tot`** (pin 11): the same `flagged` line
followed by 64 `member String auto` resolutions, `u1` to `u64`.
Generate the body loop-free and append it under the header:

    printf 'def u%s : Bool := member String auto "x" flagged\n' {1..64}

65 non-comment lines; `tot.exe check` prints 65 `def` lines and exits 0
(P4).  Resolutions 2 to 64 are memo HITs on the (class, key) slot the
first resolution records (lib/check.ml:766-773): the measured marginal
cost per extra resolution is about 0.03 ms (P5: 2 ms of spread over 63
extra resolutions plus 63 extra defs), against a full re-derive worth
of work each without the memo.

**`test/fixtures/m6d-bigcheck.tot`** (pin 12's >1024-node mutation
target): 600 trivial defs, generated loop-free under the header:

    printf 'def b%s : Nat := zero\n' {1..600}

Probed behaviour (P11), the whole reason this file exists:

- plain `check`: exit 0, 600 `def` lines.
- `--check-budget-ms 1`: exit 3, EMPTY stdout, stderr exactly
  `<path>/m6d-bigcheck.tot: check budget exhausted (1 ms)`.  Exit 3 at
  budget 1 proves the file reaches a clock-reading poll: the throttle
  at bin/tot.ml:46 reads the clock only at every 1024th poll, so this
  file crosses 1024 polls AND spends more than 1 ms of CPU by the time
  a read happens.  This is the verdict's "bigcheck flips at budget 1"
  property, held continuously by leg (c) of D7.
- budgets 5, 10 and 20: exit 0, and COLD (fresh `TOT_CACHE_DIR`) at
  budget 5: exit 0 with empty stderr, because the deadline is captured
  after `cached_state_of_src` returns (bin/tot.ml:158-166).

Sizing record (P11, P12), so nobody resizes it blind: 600 defs sits in
the bracket where budget 1 fires and budget 5 passes; 1100 defs moves
the pass boundary to 10 ms; 1500 to between 5 and 10; the 3000-auto-def
shape costs 0.133 s.  600 maximizes the healthy margin at budget 5
while keeping the clock-read property.  If a future machine breaks the
bracket, re-derive the size from the same sweep and record it.

---

### D2. `dev/gates.sh`: the M6D block, scratch and placement

Placement (D0-1): the whole M6D block is inserted AFTER the
PASS-M5E-WITNESS-REJECTED leg (after dev/gates.sh:2471 at HEAD) and
BEFORE the M4FIX-INST-BRANCHING comment block (2473).  The moved
PASS-M5D-MEASURE-LOG gate follows the M6D block (D8).  The branching
pair stays last; nothing new sits downstream of it.

Extend the one EXIT trap instead of adding a second.  Edit line 434:

    trap 'rm -rf "$tot_scratch" "$cache_scratch" "$m5c_scratch" "$m5d_scratch" "$m5e_scratch" "$m6d_scratch"' EXIT

The trap body is single-quoted, so `$m6d_scratch` expands when the trap
fires; an empty value expands to nothing harmful.

The block opens with its scratch and one helper:

    # ---------------------------------------------------------------------
    # M6 Stage D: the two cost legs (verdict pins 11-13, ruling R4).
    # Five legs, no binary change. m6d_scratch rides the one EXIT trap
    # at the top of the file (line 434 lists it).
    # ---------------------------------------------------------------------
    m6d_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m6d.XXXXXX")
    mkdir -p "$m6d_scratch/warm" "$m6d_scratch/cold" "$m6d_scratch/cb1" "$m6d_scratch/cb2"
    : > "$m6d_scratch/ratio.log"
    # One BARE timed run (conflict note D0-2: the watchdog spawn costs
    # about 4 ms, measured, which is 80 percent of the healthy signal;
    # both fixtures are proven terminating under a WRAPPED run in
    # PASS-M6D-HIT-RATIO before any bare run happens, and check is
    # deterministic). Appends one RATIO row to the leg-local log.
    m6d_time() {
      local m6d_t0=$SECONDS
      env TOT_CACHE_DIR="$m6d_scratch/warm" "$ROOT"/_build/default/bin/tot.exe \
        check "$2" > /dev/null 2>&1
      local m6d_c=$?
      printf 'RATIO %s elapsed=%.3f exit=%d\n' "$1" "$((SECONDS - m6d_t0))" "$m6d_c" \
        >> "$m6d_scratch/ratio.log"
    }

`typeset -F SECONDS` is already global (dev/gates.sh:67), so the float
subtraction works here exactly as it does inside `gate_timed`.  Every
run in this block sets a PRIVATE `TOT_CACHE_DIR` under `$m6d_scratch`
(the same isolation shape as dev/gates.sh:544 and 664), so no leg ever
touches the operator's real cache.

---

### D3. `PASS-M6D-HIT-BASELINE` (pin 11, anti-vacuity)

One wrapped run of the one-resolution fixture.  It pins the fixture's
stdout byte for byte, so a fixture that stops resolving instances fails
HERE, before the ratio can lie (pin 11's own words).  The run also
warms `$m6d_scratch/warm`, so its MEASURE row carries the private
cache's one cold write; that is a measurement, never a ceiling.

    # PASS-M6D-HIT-BASELINE (pin 11).  The one-resolution fixture checks
    # at exit 0 with the EXACT two-line stdout probed on 2026-09-03. A
    # checker that stops resolving `member String auto` exits 1 (the
    # unresolved-instance error), and a checker that prints anything
    # else breaks the byte pin, so the ratio leg below never runs
    # against a fixture that is not doing the work. This wrapped run
    # also warms the block's private cache dir.
    m6d_base=$(gate_timed "$FAST" M6D-HIT-BASELINE env \
      TOT_CACHE_DIR="$m6d_scratch/warm" "$ROOT"/_build/default/bin/tot.exe \
      check "$ROOT"/test/fixtures/m6d-hit-one.tot); m6d_bc=$?
    m6d_wantbase=$'def flagged : (List String)\ndef u1 : Bool'
    { [ "$m6d_bc" -eq 0 ] && [ "$m6d_base" = "$m6d_wantbase" ]; } \
      && echo PASS-M6D-HIT-BASELINE \
      || { printf '%s\n' "$m6d_base"; echo "FAIL-M6D-HIT-BASELINE (exit=$m6d_bc)"; exit 1; }

`gate_timed` merges stderr into stdout; both channels are empty of
noise on this fixture (P8: 0 stderr bytes warm and cold), so the byte
pin is stable.  Tier FAST: one CLI run, milliseconds of work, matching
the M5E precedent at dev/gates.sh:2440.

Mutation hooks: D12 rows M5 and M6.

### D4. `PASS-M6D-HIT-RATIO` (pin 11, ruling R4)

Median-of-9 per fixture, bare timed runs after wrapped termination
proofs, threshold 4.0, SLOW tier.  The leg appends the two median rows
to `$GATE_LOG` in `gate_timed`'s exact schema, which D8's moved gate
then counts and names.

    # PASS-M6D-HIT-RATIO (pin 11; ruling R4: threshold 4.0). Protocol:
    # two WRAPPED termination proofs, then 9 bare timed runs per
    # fixture (conflict note D0-2), medians compared multiplicatively
    # so no division can blow up. Honest constants, both measured
    # median-of-9: judge 2026-09-03 healthy 30.4 ms vs 39.0 ms = 1.28;
    # this machine 2026-09-03 healthy 0.005 s vs 0.007 s = 1.40; the
    # attack's probe-bounded mutated ratio is near 8. 4.0 sits above
    # measured noise and below the measured failure. The floor
    # m6d_one > 0 refuses a timer that cannot resolve the signal.
    # The two MEASURE rows below are DERIVED medians: their exit=0 is
    # asserted first over all 18 underlying runs (m6d_ok), then
    # written literally.
    m6d_w1=$("$watchdog" "$SLOW" env TOT_CACHE_DIR="$m6d_scratch/warm" \
      "$ROOT"/_build/default/bin/tot.exe check \
      "$ROOT"/test/fixtures/m6d-hit-one.tot 2>&1); m6d_wc1=$?
    m6d_w2=$("$watchdog" "$SLOW" env TOT_CACHE_DIR="$m6d_scratch/warm" \
      "$ROOT"/_build/default/bin/tot.exe check \
      "$ROOT"/test/fixtures/m6d-hit-many.tot 2>&1); m6d_wc2=$?
    { [ "$m6d_wc1" -eq 0 ] && [ "$m6d_wc2" -eq 0 ]; } \
      || { printf '%s\n%s\n' "$m6d_w1" "$m6d_w2"; \
           echo "FAIL-M6D-HIT-RATIO (warmup exit=$m6d_wc1/$m6d_wc2)"; exit 1; }
    m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
    m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
    m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
    m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
    m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
    m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
    m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
    m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
    m6d_time ONE "$ROOT"/test/fixtures/m6d-hit-one.tot
    m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
    m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
    m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
    m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
    m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
    m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
    m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
    m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
    m6d_time MANY "$ROOT"/test/fixtures/m6d-hit-many.tot
    m6d_one=$(rg '^RATIO ONE ' "$m6d_scratch/ratio.log" \
      | rg -o 'elapsed=[0-9]+\.[0-9]{3}' | rg -o '[0-9]+\.[0-9]{3}' \
      | sort -n | head -n 5 | tail -n 1)
    m6d_many=$(rg '^RATIO MANY ' "$m6d_scratch/ratio.log" \
      | rg -o 'elapsed=[0-9]+\.[0-9]{3}' | rg -o '[0-9]+\.[0-9]{3}' \
      | sort -n | head -n 5 | tail -n 1)
    m6d_ok=$(rg -c '^RATIO (ONE|MANY) elapsed=[0-9]+\.[0-9]{3} exit=0$' "$m6d_scratch/ratio.log")
    { [ "$m6d_ok" -eq 18 ] && [ "$(( m6d_one > 0 ))" -eq 1 ] \
        && [ "$(( m6d_many <= 4.0 * m6d_one ))" -eq 1 ]; } \
      && { printf 'MEASURE M6D-HIT-ONE tier=%s elapsed=%.3f exit=0\n' "$SLOW" "$m6d_one" >> "$GATE_LOG"; \
           printf 'MEASURE M6D-HIT-MANY tier=%s elapsed=%.3f exit=0\n' "$SLOW" "$m6d_many" >> "$GATE_LOG"; \
           echo PASS-M6D-HIT-RATIO; } \
      || { cat "$m6d_scratch/ratio.log"; \
           echo "FAIL-M6D-HIT-RATIO (one=$m6d_one many=$m6d_many ok=$m6d_ok)"; exit 1; }

Four things are asserted at once.  All 18 timed runs exited 0, counted
against the leg-local schema (a hung or failing run cannot contribute a
time).  The denominator is positive, so a sub-resolution timer fails
loudly instead of dividing the leg into nonsense.  The median ratio is
at most 4.0, in multiplicative form (`many <= 4.0 * one`), the exact
comparison P6 sanity-checked in zsh float arithmetic.  And the two
median rows land in `$GATE_LOG` only on the green path, carrying a
literal `exit=0` that the 18 underlying asserted exits justify.

The medians damp single-run wobble (the judge recorded 21 to 52 ms
single-run spread on the panel machine; P5's raw log shows 0.005 to
0.019 here).  Headroom, stated once: healthy 1.40 sits 2.9x under the
threshold; the mutated ratio near 8 sits 2x over it.

Mutation hooks: D12 rows M1 (the pin-11 re-derive, the leg's reason to
exist) and M5.

### D5. `PASS-M6D-COLD-WINDOW` (pin 12)

A run under a fresh private `TOT_CACHE_DIR` exits 0 and its output is
byte-identical to the warm rerun.  The cold run goes through
`gate_timed`, so the cold time lands in the MEASURE log; presence and
schema are pinned by D8, never a ceiling (pin 12's exact posture).  The
pre-count assertion makes the coldness a checked fact, not a hope.

    # PASS-M6D-COLD-WINDOW (pin 12).  (pre) The scratch cache dir holds
    # ZERO prelude-*.bin entries before the run, so a reused dir (a
    # warm leg wearing a cold name) fails here, not silently. (a) The
    # cold run bootstraps the prelude from source, exits 0, and its
    # MEASURE row records the cold window; the row is a measurement,
    # never a ceiling ("A tier is a HANG ceiling, not a performance
    # budget", the line this file pins at its top). (b) The warm rerun
    # in the SAME dir loads the store and must produce byte-identical
    # output. Probed green at HEAD on 2026-09-03: cold 0.017 s, warm
    # 0.006 s, identical bytes, empty stderr both sides (D0-4).
    m6d_pre_a=( "$m6d_scratch/cold"/prelude-*.bin(N) )
    m6d_pre=${#m6d_pre_a}
    m6d_coldout=$(gate_timed "$SLOW" M6D-COLD-WINDOW env \
      TOT_CACHE_DIR="$m6d_scratch/cold" "$ROOT"/_build/default/bin/tot.exe \
      check "$ROOT"/test/fixtures/m6d-hit-one.tot); m6d_cc=$?
    m6d_warmout=$("$watchdog" "$FAST" env TOT_CACHE_DIR="$m6d_scratch/cold" \
      "$ROOT"/_build/default/bin/tot.exe check \
      "$ROOT"/test/fixtures/m6d-hit-one.tot 2>&1); m6d_wc=$?
    { [ "$m6d_pre" -eq 0 ] && [ "$m6d_cc" -eq 0 ] && [ "$m6d_wc" -eq 0 ] \
        && [ -n "$m6d_coldout" ] && [ "$m6d_coldout" = "$m6d_warmout" ]; } \
      && echo PASS-M6D-COLD-WINDOW \
      || { printf '%s\n%s\n' "$m6d_coldout" "$m6d_warmout"; \
           echo "FAIL-M6D-COLD-WINDOW (pre=$m6d_pre exit=$m6d_cc/$m6d_wc)"; exit 1; }

Both runs merge stderr (the cold side inside `gate_timed`, the warm
side with an explicit `2>&1`), and both channels are byte-empty on this
fixture at HEAD (P8), so the identity compare is over the same channel
set on both sides.  Tier SLOW on the cold run: it is a perf leg with a
measured runtime in SPEC section 6, the file's own taxonomy.

Mutation hooks: D12 rows M3 and M4.

### D6. `PASS-M6D-COLD-STORE` (pin 12, the anti-vacuity graft)

Exactly one `prelude-*.bin` entry after the cold-window pair.

    # PASS-M6D-COLD-STORE (pin 12, the entry-count graft). After the
    # WINDOW pair the scratch store holds EXACTLY ONE prelude-*.bin
    # (surface/cache.ml:335 names the entries). Zero means the save
    # path died and the "warm" identity above compared two cold runs;
    # more than one means the key wobbled between two invocations of
    # the same binary over the same prelude. The exeid-*.txt stat-memo
    # sidecar also lives in this dir (probed 2026-09-03) and is NOT
    # counted; the pattern is prelude-*.bin on purpose.
    m6d_store_a=( "$m6d_scratch/cold"/prelude-*.bin(N) )
    m6d_store=${#m6d_store_a}
    [ "$m6d_store" -eq 1 ] \
      && echo PASS-M6D-COLD-STORE \
      || { ls -l "$m6d_scratch/cold"; \
           echo "FAIL-M6D-COLD-STORE (store=$m6d_store)"; exit 1; }

The counts use zsh `(N)`-qualified globs (the file's own dialect, its
shebang is `#!/bin/zsh`; `(N)` makes a no-match expand to an empty
array instead of an error), so the leg needs no `find` and no loop.  No
tier: the leg lists a scratch dir and runs no CLI, the same shape as
the file-assertion halves of PASS-M5D-TIERS.

Mutation hook: D12 row M3.

### D7. `PASS-M6D-COLD-OUTSIDE-BUDGET` (pin 12, the repaired mutation hook)

Three runs.  (a) is pin 12's kept trivial-target probe.  (b) is the
run the hoist mutation flips, on a >1024-node target, closing the
vacuous hook C-C6 exposed (dev/M5-BUILD-LOG.md:833-846: the identical
hoist did not flip on a trivial target, 5 of 5, because a sub-1024-node
target never reads the clock past the throttle at bin/tot.ml:46).  (c)
holds the target's clock-read property continuously, so the hook can
never rot back into vacuity.

    # PASS-M6D-COLD-OUTSIDE-BUDGET (pin 12).  The deadline is captured
    # AFTER cached_state_of_src returns (bin/tot.ml:165-166), so a cold
    # bootstrap is outside the budget by construction.
    # (a) cold + trivial + 5 ms: exit 0, empty stderr. Kept from pin
    #     12; the hoist mutation CANNOT flip this run (C-C6, 5 of 5:
    #     under 1024 polls the clock is never read), which is exactly
    #     why (b) exists.
    # (b) cold + m6d-bigcheck + 5 ms: exit 0, empty stderr. Healthy
    #     bracket probed 2026-09-03: the file fires at budget 1 and
    #     passes at budget 5 warm AND cold. Under the hoist mutation
    #     the deadline predates the bootstrap, the cold window (5 to
    #     15 ms wall probed, 2026-09-03) spends the 5 ms budget before
    #     the target's first clock read, and the read at poll 1024
    #     fires: exit 3, `m6d-bigcheck.tot: check budget exhausted
    #     (5 ms)`. FLAKE CONTROL: run (b) 20 times before committing
    #     this marker and record 20 of 20 exit 0 (the M5C leg-(b)
    #     precedent).
    # (c) warm + m6d-bigcheck + 1 ms: exit 3, EMPTY stdout, stderr
    #     exactly the exit-3 line naming 1 ms. This pins the target's
    #     >1024-poll, >1 ms-CPU property, so (b)'s mutation hook stays
    #     fireable; a shrunken target fails HERE first.
    m6d_ba=$("$watchdog" "$MED" env TOT_CACHE_DIR="$m6d_scratch/cb1" \
      "$ROOT"/_build/default/bin/tot.exe check --check-budget-ms 5 \
      "$ROOT"/test/fixtures/m6d-hit-one.tot 2> "$m6d_scratch/ba.err"); m6d_ca=$?
    m6d_bb=$("$watchdog" "$MED" env TOT_CACHE_DIR="$m6d_scratch/cb2" \
      "$ROOT"/_build/default/bin/tot.exe check --check-budget-ms 5 \
      "$ROOT"/test/fixtures/m6d-bigcheck.tot 2> "$m6d_scratch/bb.err"); m6d_cb=$?
    m6d_bcout=$("$watchdog" "$MED" env TOT_CACHE_DIR="$m6d_scratch/warm" \
      "$ROOT"/_build/default/bin/tot.exe check --check-budget-ms 1 \
      "$ROOT"/test/fixtures/m6d-bigcheck.tot 2> "$m6d_scratch/bc.err"); m6d_cc3=$?
    { [ "$m6d_ca" -eq 0 ] && [ ! -s "$m6d_scratch/ba.err" ] \
        && [ "$m6d_cb" -eq 0 ] && [ ! -s "$m6d_scratch/bb.err" ] \
        && [ "$m6d_cc3" -eq 3 ] && [ -z "$m6d_bcout" ] \
        && rg -q 'm6d-bigcheck\.tot: check budget exhausted \(1 ms\)$' "$m6d_scratch/bc.err"; } \
      && echo PASS-M6D-COLD-OUTSIDE-BUDGET \
      || { cat "$m6d_scratch/ba.err" "$m6d_scratch/bb.err" "$m6d_scratch/bc.err"; \
           echo "FAIL-M6D-COLD-OUTSIDE-BUDGET (exit=$m6d_ca/$m6d_cb/$m6d_cc3)"; exit 1; }

The budget stderr stays on its own channel (the M5C byte-exact stderr
discipline, dev/gates.sh:62-66), so none of the three runs is wrapped
in `gate_timed`.  Tier MED: several CLI runs over fixtures, the M5C
budget-leg precedent at dev/gates.sh:2051-2057.

Margins, stated so nobody trims them silently: run (b) is the tight
one.  Healthy, the target spends between 1 and 5 ms of CPU (P11
bracket); mutated, the spent budget at the first clock read is the cold
window plus the target's lead-in, 5 to 15 ms wall probed (P9), against
a 5 ms deadline.  Both sides carry about 2x, not the house 10x, and the
window CANNOT be widened: the separation equals the cold bootstrap
cost, which pin 15 forbids growing (no prelude edit).  That is why the
20-of-20 flake control is mandatory, and why (c) exists.  If the flip
or the flake control fails on the build machine, re-derive the target
size from the P12 sweep (the bracket rule in D1) and record the change
as a dated build-log conflict; do not touch the tiers, the throttle or
the deadline capture.

Mutation hooks: D12 row M2, with (a)'s predicted survival part of the
proof.

---

### D8. The pin-13 edit: `PASS-M5D-MEASURE-LOG` moves and extends

One commit, three coordinated changes, per pin 13 as read under D0-1.

**Move.**  Cut the whole PASS-M5D-MEASURE-LOG block (comment plus leg,
dev/gates.sh:2371-2401 at HEAD) and paste it immediately AFTER the M6D
block of D2-D7, still BEFORE the M4FIX-INST-BRANCHING comment block.
The two branching legs remain the last two legs in the file, exactly as
the round-5 placement note in the gate's own comment records.

**Extend the literals.**  In the pasted block:

- both `-eq 18` occurrences (the schema count and the exit-0 count, one
  line at HEAD:2396) become `-eq 22`;
- the `m5d_wantnames` literal (HEAD:2393) gains four names, inserted at
  their LC_ALL=C sort positions between `M5C-LEAF-MARGIN ` and
  `SUITE-KERNEL `:

      M6D-COLD-WINDOW M6D-HIT-BASELINE M6D-HIT-MANY M6D-HIT-ONE 

  The full replacement literal, trailing space preserved:

      m5d_wantnames='M4FIX-INST-BINDERS M4FIX-INST-CHAINS M4FIX-INST-CLASSES M4FIX-INST-MEMO-KEY M4FIX-INST-SMALL-REACH M4FIX-INST-SPEC16 M4FIX-INST-TWOCLASS M4FIX-INST-WIDE M5B-FUEL-REACHABLE-LEAF M5B-FUEL-REACHABLE-UNDER M5B-RUNTIME-IDENTITY-m4fix-inst-memo-key M5B-RUNTIME-IDENTITY-m5b-inst-branching-20 M5B-RUNTIME-IDENTITY-m5b-inst-chains-8-40 M5B-RUNTIME-IDENTITY-m5b-inst-zero-dict M5C-CLASSES-61 M5C-LEAF-MARGIN M6D-COLD-WINDOW M6D-HIT-BASELINE M6D-HIT-MANY M6D-HIT-ONE SUITE-KERNEL SUITE-SURFACE '

**Amend the comment, do not rewrite it.**  Keep every existing sentence
(the literal-on-purpose rationale, the downstream-branching note, the
mutation proofs).  Append one dated paragraph:

    # M6 Stage D (pin 13): count 18 -> 22 and the gate moved below the
    # M6D legs so it still runs after every wrapped leg it counts; the
    # two branching legs stay the file's tail. The four new rows:
    # M6D-HIT-BASELINE and M6D-COLD-WINDOW from gate_timed, plus
    # M6D-HIT-ONE and M6D-HIT-MANY, DERIVED median rows the ratio leg
    # writes only after asserting all 18 underlying exits are 0. The
    # count stays a literal; never re-derive it from call sites.

The arithmetic is 18 + 4 = 22, and the four names are exactly the rows
D3, D4 and D5 add.  If Stages A to C changed the entry count (they are
not expected to: no allocation line gives them a `gate_timed` leg),
measure it first with `rg -c '^MEASURE ' "$GATE_LOG"` on a fresh green
run, extend from the measured value, and record both numbers in the
build log; never infer it.  At battery END the log now holds 24 rows:
the 22 the gate counts plus the two downstream branching rows.

**Why the count is honest.**  The verdict's stated mutation for this
gate (delete one wrapper) still flips: the log loses one row and one
name while the literal stays 22 (D12 row M4).  Extending by call-site
counting would drop both together, the exact vacuity the gate's own
comment refuses; the refusal sentence stays verbatim.

### D9. The second coordination: `PASS-M5D-TIERS` raises N by 6

Not named by pin 13, but hard-required by the gate's own live-literal
obligation (dev/gates.sh:2244-2250: "any stage that adds a direct
watchdog-plus-tier use raises N by the number it added, measured with
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before
and after").  Stage D adds exactly six direct tier uses:

| Leg | Direct uses | Tier |
|---|---|---|
| PASS-M6D-HIT-RATIO warmups | 2 | SLOW |
| PASS-M6D-COLD-WINDOW warm rerun | 1 | FAST |
| PASS-M6D-COLD-OUTSIDE-BUDGET (a) (b) (c) | 3 | MED |

`gate_timed` call sites do not count (no `"$watchdog"` adjacency in the
call text; the wrapped rows are pinned by D8's name list instead, as the
TIERS comment already states).  Edit the TIERS `-eq` literal
(HEAD:2260): raise the measured Stage D entry value by EXACTLY six.
Stages A to C raise the literal as they land (+4, +8, +17: the
coordination paragraphs in plans A9, B8, C10; 122 at HEAD, probe
P14), so the predicted edit is `-eq 151` becomes `-eq 157`.  Append
to the comment, mirroring the M5E sentence at 2248-2250, with the
MEASURED numbers in place of the predicted 151/157:

    # M6 Stage D raised it 151 -> 157: its legs add six direct tier
    # uses (2 SLOW + 1 FAST + 3 MED), measured with the recipe above
    # before and after the edit.

Run the recipe before the edit (predicted 151 at Stage D entry) and
after (predicted 157), and record both outputs verbatim in the build
log (pin 17).  The measured entry value wins over the prediction;
raise by EXACTLY six from it.

### D10. The pin-14 reseal

Stage D adds three files to `test/fixtures/`, so in the SAME commit:

1. Run `dev/gen-m5e-transcript.sh` (its glob at line 13 covers
   `examples/*.tot test/fixtures/*.tot`) and write the output over
   `dev/m5e-default-transcript.txt`.
2. Diff old against new.  The review standard is ADDITIONS ONLY: the
   three new files' blocks (m6d-bigcheck contributes 600 `def` lines,
   m6d-hit-many 65, m6d-hit-one 2, plus each block's framing) and not
   one changed byte in any pre-existing block.  Any non-addition is a
   stop-the-stage conflict.
3. Record the new corpus count in the stage's SPEC entry with the
   exact command (pin 17):
   `zsh -c 'print -l examples/*.tot test/fixtures/*.tot | rg -c "\.tot$"'`.
   At HEAD it prints 80 (P2); at Stage D entry it prints whatever A and
   C left (the allocation says A adds 5 and C adds its holes fixtures);
   Stage D raises it by exactly 3.
4. PASS-M5E-DEFAULT-IDENTITY (dev/gates.sh:2416-2434) is the
   enforcement point and must be green against the resealed file in the
   same battery run.  The transcript was 9660 lines at HEAD (P17); the
   growth is the reviewed additions.

### D11. SPEC.md edits

**Section 2, dated entries (pin 18), in the `2026-09-03 (M6, Stage D)`
block:**

1. **The memo-HIT ratio leg (pin 11, ruling R4).**  Fixtures, the
   median-of-9 protocol, bare-run rationale with the measured 4 ms
   wrapper cost, and the margin arithmetic with BOTH measurement
   pairs: judge 30.4/39.0 ms ratio 1.28, build machine 0.005/0.007 s
   ratio 1.40, mutated near 8, threshold 4.0 between them (2.9x under,
   2x over).  State that the leg pins a RATIO and a stdout byte pin,
   never an absolute time.
2. **The cold-bootstrap window leg (pin 12).**  Fresh private
   `TOT_CACHE_DIR`, byte-identity against the warm rerun, the
   exactly-one `prelude-*.bin` assertion (name shape from
   surface/cache.ml:335, the `exeid-*.txt` sidecar excluded on
   purpose), the cold time recorded per battery run as presence and
   schema, never a ceiling, and the survival rule: exit status and
   output are the contract, the window is bounded only by decision
   13's external belt (scope-out 8).
3. **The measurement-log coordination (pin 13).**  The move-and-extend
   edit, 18 to 22, the four names, the branching pair still the tail,
   and the D9 tier-count raise by exactly 6 (predicted 151 to 157),
   both with their before and after commands (pin 17).

**Section 6:**

4. **Retire the pin-5 cost-half debt.**  The entry opening at
   SPEC.md:1359 ("Pin 5's cost half is unpinned ... The `gate_timed`
   MEASURE line is the manual instrument until a leg pins it") is
   discharged: rewrite it to open with `Retired (M6 Stage D)`, name
   PASS-M6D-HIT-RATIO and PASS-M6D-HIT-BASELINE, and keep the 183x
   history (dev/M5-BUILD-LOG.md:517-522) as the sizing record with its
   BRANCHING-20 attribution intact (the 183x is that leg's, not this
   one's).
5. **Restate the cold-bootstrap debt.**  The entry at SPEC.md:873-879
   keeps its mechanism sentences (cache key carries the binary digest;
   no `--check-budget-ms` value cuts the window; the external belt
   owns it) and gains one sentence: the window is now MEASURED on
   every battery run and its store is pinned (PASS-M6D-COLD-WINDOW,
   PASS-M6D-COLD-STORE, PASS-M6D-COLD-OUTSIDE-BUDGET), still without a
   ceiling and still without a second budget.

---

### D12. Mutation table

Every mutation flips, is observed RED with the predicted route, and is
restored md5-identical (`md5 -q <file>` before and after; the
dev/M5-BUILD-LOG.md:1549-1593 template).  Rebuild before the RED run
and after the restore; a mutation in gates.sh needs no rebuild.

| # | Mutation | Predicted flip route | Restore proof |
|---|---|---|---|
| M1 | lib/check.ml:766: `InstMemo.find_opt mkey st.memo` becomes `(Option.bind (InstMemo.find_opt mkey st.memo) (fun _ -> None))`, so every lookup MISSES and re-derives (the pin-11 re-derive; `mkey` stays used, no warning) | `FAIL-M6D-HIT-RATIO`: `m6d_many` inflates by 63 re-derives (attack probe: ratio near 8; predicted here about 7 from the 0.03 ms HIT vs about 0.5 ms re-derive marginal costs) while `m6d_one` holds, so `many <= 4.0 * one` reads 0.  PASS-M6D-HIT-BASELINE, both suites and every FAST leg stay GREEN (the M5 M9 record: 6.212 s stayed inside the 10 s ceiling; this file's cost is far smaller) | md5 lib/check.ml, rebuild |
| M2 | bin/tot.ml: hoist the `budget_of_ms` deadline capture above `Bootstrap.prelude_source ()` (the C-C6 mutation, against the capture at 165-166) | `FAIL-M6D-COLD-OUTSIDE-BUDGET (exit=0/3/3)`: run (b) exits 3 with `m6d-bigcheck.tot: check budget exhausted (5 ms)` because the cold window spends the budget before the first clock read; run (a) SURVIVES (exit 0, C-C6: sub-1024 polls never read the clock), and that survival is part of the proof; run (c) stays exit 3 | md5 bin/tot.ml, rebuild |
| M3 | surface/cache.ml:432: `save` body becomes `()` (keep the signature, ignore the arguments) | `FAIL-M6D-COLD-STORE (store=0)`: no `prelude-*.bin` lands.  PASS-M6D-COLD-WINDOW is predicted GREEN (two cold elaborations of the same source are byte-identical), which is exactly why STORE is its own marker.  Upstream PASS-CACHE-* legs go red earlier in the battery; run the M6D legs directly for this row's RED evidence | md5 surface/cache.ml, rebuild |
| M4 | dev/gates.sh: replace D5's `gate_timed "$SLOW" M6D-COLD-WINDOW env ...` with a bare `"$watchdog" "$SLOW" env ... 2>&1` run | FIRST red is `FAIL-M5D-TIERS` (tiers = literal + 1): the bare call joins the direct-tier count, and the TIERS leg greps the whole file from its position upstream of the M6D block (2026-09-03 route correction).  For the MEASURE-LOG half, replay with the TIERS literal ALSO raised by one (recorded as the two-line variant): the battery then reaches the relocated gate and prints `FAIL-M5D-MEASURE-LOG (lines=21 ...)`, the log one row short and the name set lacking `M6D-COLD-WINDOW` while the literal stays 22.  Both reds recorded; the second proves the D8 extension is live and literal (the verdict's stated wrapper-deletion mutation, on the new row) | md5 dev/gates.sh (both lines restored) |
| M5 | dev/gates.sh: point D2's helper and D4's warmups at a PRE-WARMED shared dir and D5's cold run at `$m6d_scratch/warm` (the reuse mutation: a warm leg wearing a cold name) | `FAIL-M6D-COLD-WINDOW (pre=1 ...)`: the pre-count reads 1 before the "cold" run.  Proves coldness is asserted, not assumed | md5 dev/gates.sh |
| M6 | lib/check.ml:758: the mangled instance prefix `"inst$"` becomes `"inst%"`, so `Global.find_def` misses on the miss path and resolution reports unresolved | `FAIL-M6D-HIT-BASELINE (exit=1)`: the check exits 1 with the unresolved-instance error on stderr and stdout loses `def u1 : Bool`, breaking the byte pin.  Suite collateral is expected and recorded; this row's evidence is the leg's own RED | md5 lib/check.ml, rebuild |

M1 and M6 also predict COLLATERAL green/red patterns; record
observed-vs-predicted for each, the M5 discipline.  If a predicted
route does not fire, stop, record a dated conflict, and re-derive per
the C-C6 attribution ladder (mutation, replacement, control) before
touching any leg.

### D13. Deliberate non-changes

1. **No binary change.**  lib/, surface/ and bin/ are untouched.  The
   deadline capture (bin/tot.ml:165-166), the 1024-poll throttle
   (bin/tot.ml:46) and the memo HIT path (lib/check.ml:766-773) are
   measured and pinned, not edited.
2. **No new tier, no numeric watchdog literal, no tier value change.**
   FAST/MED/SLOW/SUITE/BITE_S (dev/gates.sh:44-48) stand; every new
   run names a tier or rides `gate_timed`; PASS-M5D-TIERS's `nolit`
   oracle stays green by construction.
3. **No general perf-regression tier** (scope-out 6).  "A tier is a
   HANG ceiling, not a performance budget" (dev/gates.sh:30) stands;
   M6 ships exactly the two purpose-built legs.
4. **No second budget for the cold bootstrap** (scope-out 8).  The
   window is measured and its store pinned; decision 13's external
   belt keeps owning the bound.
5. **No ceiling on any MEASURE value.**  The gate pins count, names,
   schema and exit fields; elapsed values stay unasserted (pin 12:
   "presence and schema, never a ceiling").
6. **PASS-M5C-BUDGET-QUIET is untouched.**  Its trivial-target leg (b)
   keeps its 1 ms probe; the M6 hook lives in a NEW leg on a >1024-node
   target instead of editing the old one.
7. **The count-derivation refusal stays verbatim** in the moved
   MEASURE-LOG comment, and the name list stays a literal.
8. **The branching pair stays the file's tail**; nothing new sits
   downstream of M5B-BRANCHING-20 except the existing GATE-LOG echo
   and `exit 0`.
9. **No prelude, cache-format or examples/ edit.**  `format_version`
   stays 10 (surface/cache.ml:118, pin 15); the anchor corpus
   (prelude plus examples) is untouched, so the ANCHORS line and
   PASS-M5D-HOLE-ANCHORS need no coordination.
10. **The kernel and surface suites gain no tests in this stage.**  The
    five markers are the whole PASS delta.

### D14. Worked examples

**W1.  The measurement log after a green Stage D battery** (elapsed
values are machine-dependent and are NOT asserted):

    MEASURE SUITE-KERNEL tier=300 elapsed=17.412 exit=0
    ...
    MEASURE M6D-HIT-BASELINE tier=10 elapsed=0.017 exit=0
    MEASURE M6D-HIT-ONE tier=120 elapsed=0.005 exit=0
    MEASURE M6D-HIT-MANY tier=120 elapsed=0.007 exit=0
    MEASURE M6D-COLD-WINDOW tier=120 elapsed=0.017 exit=0
    MEASURE M4FIX-INST-BRANCHING tier=120 elapsed=0.970 exit=0
    MEASURE M5B-BRANCHING-20 tier=10 elapsed=0.034 exit=0
    ANCHORS total=<T> expected-type-only=<E> argument-driven=<A> neither=<N>

The gate counts 22 rows at its (moved) position; the two branching rows
land after it, 24 at battery end.

**W2.  The ratio leg's local log, healthy** (P5's shape):

    RATIO ONE elapsed=0.005 exit=0
    ... (9 ONE rows, 9 MANY rows)
    RATIO MANY elapsed=0.007 exit=0

medians 0.005 and 0.007, `(( 0.007 <= 4.0 * 0.005 ))` is 1, PASS.

**W3.  The ratio leg under mutation M1** (predicted): MANY medians near
`0.005 + 63 * 0.0005 = 0.037`, `(( 0.037 <= 4.0 * 0.005 ))` is 0,
`FAIL-M6D-HIT-RATIO (one=0.005 many=0.037 ok=18)`.

**W4.  The budget line, both directions** (P11):

    $ tot.exe check --check-budget-ms 1 test/fixtures/m6d-bigcheck.tot
    <ROOT>/test/fixtures/m6d-bigcheck.tot: check budget exhausted (1 ms)   [stderr]
    exit 3, stdout empty
    $ tot.exe check --check-budget-ms 5 test/fixtures/m6d-bigcheck.tot
    600 def lines on stdout, exit 0, stderr empty

**W5.  The cold store** (P8): after one cold run the scratch holds
exactly `prelude-40a6ea73527ee157039133378712a5d7.bin` (the key hex is
input-dependent) and one `exeid-*.txt` sidecar; the count of
`prelude-*.bin` is 1.

### D15. Stage D exit checklist

1. The five markers appear, exactly the five the verdict reserves:
   `PASS-M6D-HIT-BASELINE`, `PASS-M6D-HIT-RATIO`,
   `PASS-M6D-COLD-WINDOW`, `PASS-M6D-COLD-STORE`,
   `PASS-M6D-COLD-OUTSIDE-BUDGET`.
2. `rg -c '^PASS'` equals the Stage D entry baseline plus 5 (the
   verdict's walk: 360 + 5 = 365), 0 FAIL, GATE-EXIT=0.  Report the
   decomposition against the entry baseline.
3. PASS-M5D-MEASURE-LOG is green at its NEW position with `-eq 22`
   twice and the 22-name literal; `rg -c '^MEASURE '` on the log of a
   green run prints 24.
4. PASS-M5D-TIERS is green with its literal at the entry value plus
   exactly 6 (predicted `-eq 157`, chaining 122 +4 +8 +17 +6; D9),
   and the before/after counts are in the build log.
5. The three fixtures are committed with their headers;
   `check --check-budget-ms 1` on m6d-bigcheck exits 3 with the exact
   stderr line; the 20-of-20 flake record for D7 run (b) is in the
   build log.
6. The transcript is resealed, its diff reviewed additions-only, the
   corpus count recorded with its command, and
   PASS-M5E-DEFAULT-IDENTITY is green in the same run.
7. The six mutations are recorded flip-by-flip with md5-identical
   restores and observed-vs-predicted notes.
8. The SPEC entries of D11 are written and dated; the pin-5 cost-half
   debt opens with `Retired (M6 Stage D)`.
9. M4FIX-INST-BRANCHING and M5B-BRANCHING-20 are still the last two
   legs in the file.
10. Do not commit.  Do not stage.  Report `git status --porcelain`
    with the edits UNSTAGED, and edit nothing outside
    `/Users/oobi/Documents/tot`.

## STAGE E: corpus growth and reseal (pins 4, 14, scope-in 7-8)

The last stage grows the corpus that sizes everything else, then seals
it.  Three deliverables, all from the ratified verdict (stage
allocation, verdict lines 398-406; ruling R5 confirms the scope):

1. Port rewrap criterion 3, the scrubber, into
   `examples/guard-rewrap.tot` (SCOPE IN 7).
2. Re-spell the example-file E anchors with holes: the 19 bucket-E
   sites the classifier reports in `examples/guard.tot`,
   `examples/guard-rewrap.tot` and `examples/guard-classes.tot`
   (SCOPE IN 8, ruling R5).
3. Re-run `dev/hole-anchors.py`, record the new ANCHORS line and the
   measured solve count (pin 4), and reseal
   `dev/m5e-default-transcript.txt` once more with a reviewed diff
   (pin 14).

Goal: the operator's own guards use the M6 feature the milestone
shipped, the anchor measurement that justified holes is re-measured on
the grown corpus, and the byte-identity oracle ends the milestone
sealed against the tree it describes.

Non-goal: no prelude edit (SCOPE OUT 5: the 40 prelude E anchors are
M7 work), no A-anchor resolution (SCOPE OUT 4: the 9 argument-driven
anchors need an App arm in `check` that does not exist), no kernel or
surface OCaml change at all.  Stage E touches `.tot` files, two JSON
fixtures, the gate file, the sealed transcript and the documents.

Entry: Stages A, B, C and D green, battery at 365 PASS, 0 FAIL
(preamble arithmetic: 334 -> 339 -> 345 -> 360 -> 365).  Stage C's
hole resolution (pins 1-3) and the `_` reservation (pin 2) are live;
Stage E consumes them and adds no typing behaviour of its own.

Files: `examples/guard.tot`, `examples/guard-rewrap.tot`,
`examples/guard-classes.tot`, `test/fixtures/m6e-rewrap-scrub-comment.json`,
`test/fixtures/m6e-rewrap-scrub-string.json` (both NEW),
`dev/m5e-default-transcript.txt`, `dev/gates.sh`, `SPEC.md`,
`dev/M6-BUILD-LOG.md`.

Not touched: `stdlib/prelude.tot` (a gate leg enforces this, E7 leg
iii), `dev/hole-anchors.py` (the measuring stick does not move while
the corpus it measures moves; probe P20 shows it needs no change),
`dev/gen-m5e-transcript.sh` (the glob stays `examples/*.tot
test/fixtures/*.tot`; its `for` loop is pre-existing repo code under
the preamble's LANGUAGE SCOPE rule, and Stage E authors no new loop
anywhere), `surface/cache.ml` (pin 15; `Cache.format_version` stays
10; example files are not the prelude and no cache surface is near
this stage), `lib/`, `surface/`, `bin/`, `test/*.ml`.

### E0. Probe log (HEAD binary 8d5a839, 2026-09-03)

Every claim below about CURRENT behaviour comes from
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe` at HEAD.  23
probes ran; fixtures live under
`/Users/oobi/Documents/tot-m6-probes/plan-stage-e/`.  The load-bearing
results:

| Probe | Command | Result |
| --- | --- | --- |
| P1 | `tot.exe check examples/guard.tot` | exit 0, 10 `def` lines (block pinned in E7 leg v) |
| P2 | `python3 dev/hole-anchors.py \| wc -l` and `\| tail -1` | 148 lines; `ANCHORS total=98 expected-type-only=59 argument-driven=9 neither=30` |
| P3 | `python3 dev/hole-anchors.py --count-sites` | `98` |
| P4 | `rg -n '_' examples/guard*.tot` | matches only in comments and in the string literals `"tool_name"`/`"tool_input"`; zero term-position `_`, zero `_`-named globals |
| P5 | `ls examples/*.tot test/fixtures/*.tot \| wc -l` | `80` |
| P6 | `rg -c 'PASS-M6' dev/gates.sh; echo EXIT=$?` | no output, `EXIT=1` (zero matches: the pin-16 namespace is free) |
| P7 | `wc -l -c dev/m5e-default-transcript.txt` | `9660  653286` |
| P8 | `rg -c '"\$watchdog" "\$(FAST\|MED\|SLOW\|SUITE)"' dev/gates.sh` | `122` (the PASS-M5D-TIERS literal at HEAD, gates.sh:2260) |
| P9 | `rg -n 'expected-type-only=' SPEC.md` | exactly ONE match, SPEC.md:1633 (load-bearing for conflict C2) |
| P10 | `tot.exe run examples/guard-rewrap.tot < test/fixtures/m5d-rewrap-deny.json` | deny envelope echoing `let a = h()?;`, exit 2 |
| P11 | same, `m5d-rewrap-allow.json` | empty stdout, exit 0 |
| P12 | same, probe fixture `m6e-rewrap-scrub-comment.json` (pair inside `/* ... */`) | deny envelope, exit 2: the FALSE DENY the scrubber removes |
| P13 | same, probe fixture `m6e-rewrap-scrub-string.json` (pair inside a multi-line `"..."`) | deny envelope, exit 2: the second false deny |
| P14 | `tot.exe check examples/guard-rewrap.tot` | exit 0, 14 `def` lines |
| P15 | `tot.exe check examples/guard-classes.tot` | exit 0, 10 output lines (two `eval : Bool`) |
| P16 | `tot.exe run examples/guard.tot < test/fixtures/deny.json` | exit 2, envelope `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo /tmp/x)"}}` |
| P17 | `tot.exe run examples/guard-rewrap.tot < test/fixtures/garbage.json` | empty stdout, exit 0 (fail-open) |
| P18 | same, `test/fixtures/other.json` (tool_name Read) | empty stdout, exit 0 |
| P19 | `tot.exe check hole-at-head.tot` (`cons _ "grep" ... (nil _)`) | `hole-at-head.tot:1:35: unknown name _`, exit 1: the re-spell CANNOT land before Stage C |
| P20 | copy corpus + classifier to scratch, re-spell guard-classes.tot:26 with `_`, re-run | `ANCHORS total=98 expected-type-only=59 argument-driven=9 neither=30` unchanged; the three rows print `anchor=[_] pos=check bucket=E`; `--count-sites` still `98` |
| P21 | `tot.exe run quote-prims.tot` (`"\""` with stringContains/stringSplit/headOr) | exit 0, `true`/`true`/`false`: the quote escape lexes and the split-on-quote idiom works |
| P22 | `rg -c '^### ' dev/m5e-default-transcript.txt` | `80` (one block per corpus file) |
| P23 | `rg -A 13 -x -F '### examples/guard.tot' dev/m5e-default-transcript.txt` | the 14-line guard.tot block, verbatim in E7 leg v |

Probe P20 is the stage's keystone: the classifier is INVARIANT under
the re-spell.  Its bucket rules read the head and the position, never
the anchor's spelling (`dev/hole-anchors.py:31-46`), so a re-spelled
site keeps its bucket and the totals move ONLY when the scrubber adds
sites.  Probe P19 is the ordering fence: at HEAD a `_` anchor is
`unknown name _` at exit 1, so every edit in this stage lands after
Stage C or not at all.

The `P<n>` labels are probe ids local to this section.  Cite a verdict
pin as `pin <n>` and a row here as `probe P<n>`.

### E1. What SCOPE IN 7 and 8 say, verbatim

From the verdict's SCOPE IN list:

> 7.  Guard corpus growth: port rewrap criterion 3 (the scrubber),
>   re-run the anchor classifier, record the new ANCHORS line.
> 8.  Re-spell the example-file E anchors with holes at stage E, with a
>   reviewed transcript reseal.

And ruling R5:

> guard.tot and the example E anchors are re-spelled INSIDE M6, the
> verdict default. PASS-M6E-GUARD-HOLES and the second reseal stay in
> scope.

Item 7 is section E2.  Item 8 is sections E3 to E5.  The "new ANCHORS
line" lands in SPEC (E8) and is pinned by gate leg iv (E7).

### E2. The scrubber port (criterion 3)

**What "criterion 3" names.**  The house Python guard
(`~/.claude/hooks/map-over-rewrap-bash-guard.py`) reconstructs the
file a shell command would write and runs a scrubbed net-new rewrap
check: the lexical scrubber blanks comment / string / char /
raw-string spans before any pattern runs, "so a match inside a
comment/string is ignored" (the sibling module's own comment).  The M5
port carried criteria 1 and 2 on raw text and states its unported
remainder in its header: "The scrubber, the block-tail test, the
used-name test and the net-new comparison are NOT ported"
(guard-rewrap.tot:17-19).  The verdict's parenthesis names the
scrubber directly, so that is what this stage ports; conflict note C1
records the numbering wrinkle.

**The two false denies it removes, measured.**  Probes P12 and P13:
at HEAD a payload whose `let ...?;` / `Ok(` line pair sits entirely
inside a Rust block comment, or entirely inside a multi-line string
literal, DENIES at exit 2, because `hasRewrapPair` reads raw lines
(guard-rewrap.tot:98-113).  Both payloads must ALLOW after the port.
The genuine pair (probe P10) must keep denying.

**Scope the port honestly, again.**  The port stays line-based and
narrow, and it fails open in every direction it cannot classify:

- `//` cuts the rest of a line.
- An unmatched `/*` on a line cuts the rest of that line and enters
  comment state; comment state drops whole lines until a line
  containing `*/`, which is dropped whole (code after `*/` on that
  line is LOST: under-block, fail-open).
- A line with `/*` AND `*/` keeps only the text before the `/*` (code
  after the `*/` is lost the same way).
- An odd count of `"` on a line cuts the line at the first `"` and
  enters string state; string state drops whole lines until a line
  containing `"`, which is dropped whole.  A BALANCED pair of quotes
  on one line is left in place: inline string contents are not
  blanked (recorded miss).
- Escapes (`\"`), char literals and raw strings are not modelled
  (recorded misses; the Python scrubber models all three).
- A code-state line keeps its trailing whitespace after a `//` cut,
  so `let a = h()?; // note` still tokenizes with a final EMPTY token
  and the pair is still MISSED, exactly as guard-rewrap.tot:56-59
  records for raw text today.  The scrubber removes false denies; it
  does not promise new catches.

Every one of these goes into the file header (replacing the "NOT
ported" list's first item) and into the SPEC section 2 entry.

**The code.**  New declarations in `examples/guard-rewrap.tot`, above
`rewrapVerdict`, authored WITH holes at their own E-shaped sites
(they land after Stage C, and dogfood is the stage's point).  Every
match on `Scrub` lists arms in declaration order (the M5 lesson:
tot pins match arms to declaration order).

```
-- M6 Stage E: criterion 3, the scrubber.  Line-based, narrow,
-- fail-open; the recorded misses are listed above.
data Scrub : Type 0 :=
  | sCode : Scrub
  | sComment : Scrub
  | sString : Scrub

def quoteTok : String := "\""

-- text before the first occurrence of sep (the whole string when
-- sep is absent: stringSplit then yields the one-piece list)
def beforeFirst : String -> String -> String :=
  fun sep s => headOr _ s (stringSplit s sep)

def rec evenPieces : List String -> Bool :=
  fun xs =>
    match xs with
    | nil => true
    | cons h t => boolEq (evenPieces t) false
    end

-- odd count of '"' in s  <=>  stringSplit s quoteTok has even length
def oddQuotes : String -> Bool :=
  fun s => evenPieces (stringSplit s quoteTok)

def cutSlash : String -> String := fun l => beforeFirst "//" l

def cutBlock : String -> String :=
  fun l =>
    match stringContains (cutSlash l) "/*" with
    | true => beforeFirst "/*" (cutSlash l)
    | false => cutSlash l
    end

-- the kept text of a code-state line
def scrubCode : String -> String :=
  fun l =>
    match oddQuotes (cutBlock l) with
    | true => beforeFirst quoteTok (cutBlock l)
    | false => cutBlock l
    end

-- the state AFTER a code-state line.  An unmatched /* wins over a
-- quote: a quote inside an opened comment is comment text.
def nextState : String -> Scrub :=
  fun l =>
    match andb (stringContains (cutSlash l) "/*")
               (boolEq (stringContains (cutSlash l) "*/") false) with
    | true => sComment
    | false =>
        match oddQuotes (cutBlock l) with
        | true => sString
        | false => sCode
        end
    end

def rec scrubLines : Scrub -> List String -> List String :=
  fun st ls =>
    match ls with
    | nil => nil _
    | cons l t =>
        match st with
        | sCode => cons _ (scrubCode l) (scrubLines (nextState l) t)
        | sComment =>
            match stringContains l "*/" with
            | true => scrubLines sCode t
            | false => scrubLines sComment t
            end
        | sString =>
            match stringContains l quoteTok with
            | true => scrubLines sCode t
            | false => scrubLines sString t
            end
        end
    end
```

`scrubLines` recurses on the LIST in every arm while the state
argument varies, the same shape as `lastOr` (constant first argument,
shrinking second): `rec_arg` first-fit rejects position 0 and picks
the list, so the shipped guard accepts it.  Confirm with the built
binary before committing; gate leg iii holds `check` at exit 0 either
way.  `andb`, `boolEq` and `headOr` are prelude
(stdlib/prelude.tot:10, 39, 146); `stringContains`, `stringSplit` are
prims already used by this file; probe P21 pins that `"\""` lexes and
splits as expected.

**The one edited line of `rewrapVerdict`** (guard-rewrap.tot:133
today):

```
        match hasRewrapPair (dropEmpty (stringSplit cmd "\n")) with
```

becomes

```
        match hasRewrapPair (dropEmpty (scrubLines sCode (stringSplit cmd "\n"))) with
```

`dropEmpty` runs AFTER the scrubber, so a line scrubbed down to
whitespace vanishes before the pair test, and the existing
blank-line rule (guard-rewrap.tot:82-84) needs no change.

**Walkthrough against the fixtures** (design check, re-verified live
at build time):

- P12's payload: `/*` line enters comment state with an empty kept
  prefix; the `let` and `Ok(` lines are dropped in comment state;
  `*/` restores code state.  Remaining lines carry no pair: ALLOW.
- P13's payload: `let example = "` has one quote, keeps
  `let example = ` (last token `=`: no pair) and enters string state;
  the pair lines are dropped; `";` closes.  ALLOW.
- P10's payload: no `//`, no `/*`, no `"` (the heredoc quotes are
  single quotes), so every line passes through unchanged: DENY with
  the same echoed `let a = h()?;` line.

**New anchor sites.**  The scrubber adds exactly three table-head
applications: `headOr` in `beforeFirst`, `nil` and `cons` in
`scrubLines`.  All three sit in check position with the formal in the
result type, so the D5 bucket rules make them E, and they are
authored as `_` from the start.  Predicted classifier delta:
`total=101 expected-type-only=62 argument-driven=9 neither=30`.  The
prediction is derivation, not a pin: the build re-runs the classifier
and pins the ACTUAL line (E4, gate leg iv, pin 17).

### E3. The re-spell: 19 sites, listed

The classifier's example-file rows at HEAD, complete (probe P2's site
list; reproduce with `python3 dev/hole-anchors.py | rg 'SITE examples/'`):
27 sites, of which 19 are bucket E, 4 bucket A, 4 bucket N.  A reading
note on pin 4's wording: "guard.tot carries NINE sites (the seven
let*-adjacent ones plus guard.tot:48 head=nil and guard.tot:49
head=append, both bucket E)" counts SITES; of the nine, seven are E
and the two `let*` arg-0 anchors are A.  The rows agree with the pin;
only the nineteen E rows are re-spelled.

`examples/guard.tot`, 7 E sites (rows: 48 nil, 49 append, 133 bindIO
arg 1, 134 bindIO arg 1, 134 liftIO arg 0, 136 pureIO, 137 pureIO):

```
    | nil => nil String                                        -- :48
    | cons h t => append String (stringSplit h sep) (splitEach sep t)   -- :49
  let* String Verdict raw := readStdin in                      -- :133
  let* (Option Json) Verdict parsed := liftIO (Option Json) (jsonParse raw) in  -- :134
  | none => pureIO Verdict allow                               -- :136
  | some payload => pureIO Verdict (decide payload)            -- :137
```

becomes

```
    | nil => nil _
    | cons h t => append _ (stringSplit h sep) (splitEach sep t)
  let* String _ raw := readStdin in
  let* (Option Json) _ parsed := liftIO _ (jsonParse raw) in
  | none => pureIO _ allow
  | some payload => pureIO _ (decide payload)
```

The `let*` arg-0 anchors (`String` at :133, `(Option Json)` at :134)
are bucket A and STAY EXPLICIT: `bindIO`'s result type `IO B` does not
mention `A`, so only the bound expression's inferred type could fix
it, and that is the M7 App-arm debt.  Note the split on :134: the
`let*` arg 0 stays `(Option Json)` while `liftIO`'s own arg 0 becomes
`_`, because `liftIO`'s result `IO A` lands rigidly in the expected
`IO (Option Json)` flowing from the same `let*`.

`examples/guard-rewrap.tot`, 9 E sites at HEAD (rows: 48 nil, 49
append, 87 nil, 91 cons, 162 bindIO arg 1, 163 bindIO arg 1, 163
liftIO arg 0, 165 pureIO, 166 pureIO).  Lines 48-49 and 162-166 are
the guard.tot shapes above, copied (the deliberate duplication), and
take the same edits; the two dropEmpty sites:

```
    | nil => nil String                                        -- :87
    | false => cons String h (dropEmpty t)                     -- :91
```

becomes

```
    | nil => nil _
    | false => cons _ h (dropEmpty t)
```

The A rows at :162/:163 (bindIO arg 0) stay explicit, as in guard.tot.

`examples/guard-classes.tot`, 3 E sites (rows: 26 cons, 26 cons, 26
nil), verified end to end by probe P20 on a corpus copy:

```
def flagged : List String := cons String "grep" (cons String "sed" (nil String))
```

becomes

```
def flagged : List String := cons _ "grep" (cons _ "sed" (nil _))
```

The N rows stay explicit: `refl Verdict` (:15) and
`cong0 String Verdict` (:23) are proof heads, `member String` (:27)
is a class key; pin 3 refuses all three shapes and Stage C's
PASS-M6C-HOLE-REPORTS pins the refusal line on fixtures.

**The ceiling rule (pin 4).**  E = 59 is a ceiling because the
classifier does not run the checker.  If any of the 19 sites fails to
resolve at build time (exit 1 with the pin-3 line), LEAVE THAT SITE
EXPLICIT, record the site and the refusal line in
`dev/M6-BUILD-LOG.md`, and lower the E7 leg-iii literal accordingly.
The SPEC entry then records the measured count as solved-of-19; no
gate may be weakened to make 19 come true.

**Build-time probe, not a gate.**  After the re-spell, spell ONE
A site as `_` in a scratch copy (guard.tot:133 arg 0) and run
`check`: it must fail with the pin-3 line
(`<file>:<line>:<col>: hole: ...`).  Record command and output in the
build log next to the solve count.  This is pin 4's "A-bucket
anchors, re-spelled with `_`, must fail" demonstrated on the real
corpus; the committed fixtures for the rule live in Stage C.

### E4. The classifier rerun and the MEASURE-LOG splice

Rerun, after both edits land:

```
python3 dev/hole-anchors.py | tail -1
python3 dev/hole-anchors.py --count-sites
```

Record both outputs verbatim in `dev/M6-BUILD-LOG.md` and the ANCHORS
line in the SPEC entry (E8).  Predicted:
`ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30`
with count-sites `101`; the actuals win (pin 17).  The re-spelled rows
print `anchor=[_]` and keep their buckets (probe P20), so the
per-bucket movement comes from the three scrubber sites alone.

**Conflict C2 and its one-line fix.**  `PASS-M5D-MEASURE-LOG` asserts
the log's `expected-type-only=` number equals SPEC's, extracted with
`rg -o 'expected-type-only=[0-9]+' "$ROOT/SPEC.md"`
(HEAD:2395; Stage D's D8 relocates the whole MEASURE-LOG block to
just after the M6D legs before this stage runs, so locate the line by
its content, `rg -n 'm5d_specE=' dev/gates.sh`, not by that line
number).  That extraction assumes ONE match, and probe P9
shows exactly one exists at HEAD (SPEC.md:1633).  The Stage E SPEC
entry adds a second, so the same commit edits the extraction to take
the NEWEST record:

```
m5d_specE=$(rg -o 'expected-type-only=[0-9]+' "$ROOT/SPEC.md" | tail -n 1)
```

with a dated comment naming this section.  Semantics after the edit:
SPEC's newest recorded E equals the E the battery's own classifier
run just produced, which is the drift the gate was built to stop.
The old record at SPEC.md:1633 stays as history.  Mutation M-E5 proves
the spliced extraction is live.

### E5. Transcript regeneration discipline and the FINAL reseal (pin 14)

**The standing rule, restated for every stage.**
`dev/gen-m5e-transcript.sh` globs `examples/*.tot` and
`test/fixtures/*.tot`: 80 files at HEAD (probe P5), 80 blocks in the
sealed oracle (probe P22), 9660 lines, 653286 bytes (probe P7).  Every
M6 stage that adds or edits a file in either directory regenerates
`dev/m5e-default-transcript.txt` IN THE SAME COMMIT, diffs old against
new, reviews the diff (added files and enumerated verdict changes
only), and records the file count in its SPEC entry.  Stages A, B, C
and D each say so in their own sections; PASS-M5E-DEFAULT-IDENTITY
stays the enforcement point between stages, unchanged.  This is the
discipline whose absence broke two of the three panel walks (verdict,
pin 14).

**Stage E owns the FINAL reseal: regenerate once, byte-diff twice.**
The stage's two `.tot`-visible edits (E2, E3) both live in
`examples/`, and its two new fixtures are `.json`, OUTSIDE the glob,
so the corpus file COUNT does not move at Stage E; only content does.
The reseal procedure, in order:

1. Regenerate ONCE: run `dev/gen-m5e-transcript.sh` into a scratch
   file, after the E2 and E3 edits are final.
2. Byte-diff ONE, the review: `diff` the Stage-D-exit seal against
   the regeneration.  The diff must touch ONLY the
   `### examples/guard-rewrap.tot` block, and inside it only
   additions: `data Scrub : Type 0`, the three ctor lines, and the
   `def` lines for `quoteTok`, `beforeFirst`, `evenPieces`,
   `oddQuotes`, `cutSlash`, `cutBlock`, `scrubCode`, `nextState`,
   `scrubLines`.  The `### examples/guard.tot` and
   `### examples/guard-classes.tot` blocks must be ABSENT from the
   diff: holes resolve to the terms the explicit spellings named, so
   their checker output is byte-identical (pin 1's conservativity,
   enforced in-gate by E7 leg v).  Any other hunk is a defect; stop
   and diagnose.  Record the reviewed hunk list in
   `dev/M6-BUILD-LOG.md`.
3. Seal: copy the regeneration over `dev/m5e-default-transcript.txt`
   and record the new `wc -l -c` and the file count (unchanged from
   Stage D's) in the SPEC entry.
4. Byte-diff TWO, the standing one: the battery's
   PASS-M5E-DEFAULT-IDENTITY leg regenerates fresh and diffs against
   the new seal on every run from now on (dev/gates.sh:2419-2434,
   untouched).  Run the full battery and verify GATE-EXIT=0.

The reseal is a COMMIT-DISCIPLINE step, not a new script: no
regeneration loop is authored, and the one regeneration in step 1 is
the same script invocation the gate already makes.

### E6. Stage E fixtures (complete list)

Two NEW files, both payload JSON, both outside the transcript glob.
Byte content, one line each plus trailing newline:

`test/fixtures/m6e-rewrap-scrub-comment.json` (probe P12's payload):

```
{"tool_name":"Bash","tool_input":{"command":"cat > demo.rs <<'EOF'\n/*\nlet a = h()?;\nOk(a)\n*/\nEOF"}}
```

`test/fixtures/m6e-rewrap-scrub-string.json` (probe P13's payload):

```
{"tool_name":"Bash","tool_input":{"command":"cat > demo.rs <<'EOF'\nlet example = \"\nlet a = h()?;\nOk(a)\n\";\nEOF"}}
```

Both false-deny at HEAD (P12, P13: exit 2 with the envelope), which is
the recorded before-picture; both must allow after E2.  NO new `.tot`
fixture lands in Stage E: the corpus file count stays what Stage D
left, which is what makes the E5 review criterion ("one block only")
sharp.  Reused fixtures: `m5d-rewrap-deny.json`,
`m5d-rewrap-allow.json`, `garbage.json`, `other.json`, `deny.json`,
all present at HEAD and probed (P10, P11, P16, P17, P18).

### E7. Gates

Five markers, the five the verdict allocates to Stage E.
`rg -c 'PASS-M6' dev/gates.sh` prints nothing and exits 1 at HEAD
(probe P6; `rg -c` reports no line when the count is zero), so the
namespace is free (pin 16); Stages A-D claim only PASS-M6[A-D]-*.

Shell facts this block depends on, each checked against the file:

1. Tier variables are `FAST`, `MED`, `SLOW`, `SUITE` (gates.sh:44-47);
   no numeric watchdog literal may appear (PASS-M5D-TIERS asserts it
   on exit status, gates.sh:2257-2263).
2. This block adds NINE direct tier uses (3 + 2 + 4 + 0 + 0 below).
   PASS-M5D-TIERS pins the count with `-eq` against a live literal
   (122 at HEAD, probe P8; Stages A to D each raise it as they land
   per their own coordination paragraphs, +4, +8, +17, +6: predicted
   126 -> 134 -> 151 -> 157; plans A9, B8, C10, D9).  Stage E raises
   the value Stage D left by EXACTLY NINE in the same edit (predicted
   157 -> 166), measured before and after with
   `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh`,
   and records both numbers in `dev/M6-BUILD-LOG.md`.
3. No new scratch dir and no new `gate_timed` wrapper: the block
   reads `$m5d_bin` (gates.sh:2226), `$m5d_scratch/hole-sites.txt`
   (written by the classifier run at gates.sh:2233-2235, cleaned by
   the single EXIT trap at gates.sh:434) and `$GATE_LOG`
   (gates.sh:68).  Zero gate_timed calls means the
   PASS-M5D-MEASURE-LOG count and name set do NOT move for Stage E
   (pin 13 concerns Stage D's legs, not these).
4. Placement: the whole block sits AFTER Gate E (iii)
   PASS-M5E-WITNESS-REJECTED (gates.sh:2466-2471) and BEFORE the
   `ctxcat id 5` comment block (gates.sh:2473), so the two branching
   legs stay the file's timing-sensitive tail (the round-5 rule).

The block, verbatim; `<H>`, `<T>`, `<E>`, `<A>`, `<N>` are literals
filled at build time (predicted 22, 101, 62, 9, 30) and pinned in
`dev/M6-BUILD-LOG.md` with the command that produced each (pin 17).
Do NOT weaken any `=` comparison to a substring match.

```sh
# ---------------------------------------------------------------------
# M6 Stage E: corpus growth and reseal (M6 plan, Stage E section E7).
# Five legs, each with a mutation proof in dev/M6-BUILD-LOG.md.
# Placement: after the M5E block, before the two branching legs, which
# stay the file's tail.  No new scratch, no gate_timed: these legs
# reuse $m5d_bin, $m5d_scratch/hole-sites.txt and $GATE_LOG from
# Gate D, and the EXIT trap at the top of the file already owns the
# cleanup.
# ---------------------------------------------------------------------

# PASS-M6E-REWRAP-SCRUB (scope-in 7).  Criterion 3 is live: a rewrap
# pair inside a Rust block comment (a) or a multi-line string (b) no
# longer false-denies (both denied at HEAD, probes P12/P13,
# 2026-09-03), and the genuine pair (c) still denies with the echoed
# let line, so a scrub-everything mutation cannot pass.
m6e_sc=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/m6e-rewrap-scrub-comment.json); m6e_c1=$?
m6e_ss=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/m6e-rewrap-scrub-string.json); m6e_c2=$?
m6e_sd=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/m5d-rewrap-deny.json); m6e_c3=$?
{ [ "$m6e_c1" -eq 0 ] && [ -z "$m6e_sc" ] \
  && [ "$m6e_c2" -eq 0 ] && [ -z "$m6e_ss" ] \
  && [ "$m6e_c3" -eq 2 ] \
  && printf '%s' "$m6e_sd" | rg -q 'let a = h\(\)\?;'; } \
  && echo PASS-M6E-REWRAP-SCRUB \
  || { printf '%s\n%s\n%s\n' "$m6e_sc" "$m6e_ss" "$m6e_sd"; \
       echo "FAIL-M6E-REWRAP-SCRUB (c1=$m6e_c1 c2=$m6e_c2 c3=$m6e_c3)"; exit 1; }

# PASS-M6E-REWRAP-OPEN.  The fail-open posture survives the port: a
# non-JSON payload and a non-Bash payload both allow at exit 0 with
# empty stdout (HEAD behaviour, probes P17/P18, re-pinned so the
# scrubber commit cannot flip the posture).
m6e_og=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/garbage.json); m6e_c4=$?
m6e_oo=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard-rewrap.tot \
  < "$ROOT"/test/fixtures/other.json); m6e_c5=$?
{ [ "$m6e_c4" -eq 0 ] && [ -z "$m6e_og" ] \
  && [ "$m6e_c5" -eq 0 ] && [ -z "$m6e_oo" ]; } \
  && echo PASS-M6E-REWRAP-OPEN \
  || { printf '%s\n%s\n' "$m6e_og" "$m6e_oo"; \
       echo "FAIL-M6E-REWRAP-OPEN (c4=$m6e_c4 c5=$m6e_c5)"; exit 1; }

# PASS-M6E-GUARD-HOLES (scope-in 8, ruling R5).  Six assertions: the
# three re-spelled guards check at exit 0; the site list Gate D's
# classifier run wrote carries exactly <H> holed example anchors
# (anchor=[_]), so an un-respelled tree cannot pass; the prelude
# carries ZERO holed anchors (scope-out 5 enforced); and guard.tot's
# deny envelope on the M3 payload is byte-identical to the
# pre-respell envelope (probe P16), so holes changed no behaviour.
m6e_g1=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard.tot 2>&1); m6e_c6=$?
m6e_g2=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard-rewrap.tot 2>&1); m6e_c7=$?
m6e_g3=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard-classes.tot 2>&1); m6e_c8=$?
m6e_holes=$(rg -c 'anchor=\[_\]' "$m5d_scratch/hole-sites.txt")
rg -q 'SITE stdlib/prelude\.tot:.*anchor=\[_\]' "$m5d_scratch/hole-sites.txt"; m6e_pz=$?
m6e_env=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard.tot \
  < "$ROOT"/test/fixtures/deny.json); m6e_c9=$?
m6e_wantenv='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo /tmp/x)"}}'
{ [ "$m6e_c6" -eq 0 ] && [ "$m6e_c7" -eq 0 ] && [ "$m6e_c8" -eq 0 ] \
  && [ "$m6e_holes" -eq <H> ] && [ "$m6e_pz" -eq 1 ] \
  && [ "$m6e_c9" -eq 2 ] && [ "$m6e_env" = "$m6e_wantenv" ]; } \
  && echo PASS-M6E-GUARD-HOLES \
  || { printf '%s\n%s\n%s\n%s\n' "$m6e_g1" "$m6e_g2" "$m6e_g3" "$m6e_env"; \
       echo "FAIL-M6E-GUARD-HOLES (c=$m6e_c6/$m6e_c7/$m6e_c8 holes=$m6e_holes pz=$m6e_pz env=$m6e_c9)"; exit 1; }

# PASS-M6E-ANCHORS (scope-in 7; pins 4 and 17).  The grown corpus was
# re-measured: the ANCHORS line the classifier wrote into $GATE_LOG
# this run equals the literal recorded from the build-time rerun, and
# the total grew past the HEAD baseline 98 (the scrubber's list
# rebuild adds headOr/cons/nil sites).  Schema, bucket sum and the
# independent --count-sites recount stay owned by
# PASS-M5D-HOLE-ANCHORS upstream; SPEC-vs-log stays owned by the
# spliced PASS-M5D-MEASURE-LOG (plan E4).
m6e_line=$(rg -o '^ANCHORS total=[0-9]+ expected-type-only=[0-9]+ argument-driven=[0-9]+ neither=[0-9]+$' "$GATE_LOG")
m6e_want='ANCHORS total=<T> expected-type-only=<E> argument-driven=<A> neither=<N>'
m6e_tot=$(printf '%s' "$m6e_line" | rg -o 'total=[0-9]+' | rg -o '[0-9]+')
{ [ "$m6e_line" = "$m6e_want" ] && [ "$m6e_tot" -gt 98 ]; } \
  && echo PASS-M6E-ANCHORS \
  || { printf '%s\n' "$m6e_line"; echo "FAIL-M6E-ANCHORS (tot=$m6e_tot)"; exit 1; }

# PASS-M6E-TRANSCRIPT-RESEALED (pin 14, ruling R5).  The FINAL reseal
# is real and complete: the sealed oracle's block count equals the
# LIVE glob count (a corpus or glob change without a reseal cannot
# pass, and PASS-M5E-DEFAULT-IDENTITY alone cannot see a glob
# narrowed in the generator, mutation M-E7); the guard.tot block is
# byte-identical to the pre-respell block (probe P23: pin-1
# conservativity, holes changed no output byte); and the
# guard-rewrap.tot block carries the scrubber (a stale pre-port seal
# cannot pass).  Whole-file identity against a fresh regeneration
# stays owned by PASS-M5E-DEFAULT-IDENTITY above.
m6e_blocks=$(rg -c '^### ' "$ROOT"/dev/m5e-default-transcript.txt)
m6e_files=$(ls "$ROOT"/examples/*.tot "$ROOT"/test/fixtures/*.tot | wc -l | tr -d ' ')
m6e_gblock=$(rg -A 13 -x -F '### examples/guard.tot' "$ROOT"/dev/m5e-default-transcript.txt)
m6e_wantg=$'### examples/guard.tot\n#exit 0\n#out\ndef firstNonEmpty : (w _ : (List String)) -> String\ndef lastOr : (w _ : String) -> (w _ : (List String)) -> String\ndef splitEach : (w _ : String) -> (w _ : (List String)) -> (List String)\ndef firstToken : (w _ : String) -> String\ndef baseName : (w _ : String) -> String\ndef usesBanned : (w _ : String) -> Bool\ndef orEmpty : (w _ : (Option String)) -> String\ndef elideAt : (w _ : Int) -> (w _ : String) -> String\ndef decide : (w _ : Json) -> Verdict\ndef main : (IO Verdict)\n#err'
m6e_srub=$(rg -c '^def scrubLines : ' "$ROOT"/dev/m5e-default-transcript.txt)
{ [ "$m6e_blocks" -eq "$m6e_files" ] && [ "$m6e_gblock" = "$m6e_wantg" ] \
  && [ "$m6e_srub" -eq 1 ]; } \
  && echo PASS-M6E-TRANSCRIPT-RESEALED \
  || { echo "FAIL-M6E-TRANSCRIPT-RESEALED (blocks=$m6e_blocks files=$m6e_files scrub=$m6e_srub)"; \
       diff <(printf '%s\n' "$m6e_wantg") <(printf '%s\n' "$m6e_gblock") | head -20; exit 1; }
```

The `m6e_wantg` literal is probe P23's block, byte for byte, and it
must survive the whole milestone: no stage before E touches
`examples/guard.tot`, the E3 re-spell may not change one output byte,
and the leg proves it.  If the built binary ever prints the block
differently, that is a Stage C conservativity defect, not a reason to
re-pin.

### E8. SPEC.md

Append to section 2 a dated entry, `2026-09-03 (M6, Stage E)`:

1. **Criterion 3 is ported; the port stays narrow.**  One paragraph
   naming the scrubber's rules and every recorded miss from E2 (the
   comment-tail loss, the inline balanced-quote miss, no escapes, no
   char or raw strings, the trailing-whitespace miss carried over
   from guard-rewrap.tot:56-59).  The unported remainder is now:
   the block-tail test, the used-name test, the net-new comparison.
2. **The two before-pictures.**  The P12 and P13 payloads denied at
   exit 2 at 8d5a839 and allow after this stage; the P10 payload
   denies unchanged.  Commands and envelopes verbatim.
3. **The new ANCHORS line**, verbatim, with both commands
   (`python3 dev/hole-anchors.py | tail -1`, `--count-sites`) and the
   note that the old line (SPEC.md:1633's record) remains the M5
   baseline.  State the bucket-stability fact probe P20 measured: a
   re-spelled anchor keeps its bucket, so the delta is the scrubber's
   three sites.
4. **The measured solve count (pin 4).**  "Of the 98-anchor HEAD
   corpus the expected-type-only pass solves <n> anchors: <n> of the
   19 example-file E anchors re-spelled here (7 guard.tot,
   9 guard-rewrap.tot, 3 guard-classes.tot), 0 of the 40 prelude E
   anchors (out of scope), 0 of A and N by design."  Record the
   honesty clause again: E was a ceiling; <n> is the measurement.
   List any site left explicit under the E3 ceiling rule with its
   refusal line.
5. **The reseal record.**  File count (unchanged), new `wc -l -c`,
   the reviewed hunk list ("guard-rewrap.tot block only: data Scrub,
   three ctors, nine defs"), and the sentence "regenerated once,
   byte-diffed twice: once against the Stage-D seal for review, and
   on every battery run by PASS-M5E-DEFAULT-IDENTITY thereafter."

Section 6 edits in the same commit: the guard-rewrap debt line drops
the scrubber from its unported list (guard-rewrap.tot's header
changes with it); the holes debt is rewritten to name what remains
(9 A anchors needing the App arm, 4 of them in the guards; 40 prelude
E anchors awaiting soak; multi-hole reporting), each already in the
verdict's M7 list.  The tokenizer-duplication debt STAYS, now
covering the scrubber helpers too (still one file copying from the
other, still no modules).

### E9. Mutation proofs

Run each mutation, observe the stated flip, restore, and prove the
restore md5-identical (the dev/M5-BUILD-LOG.md:1549-1593 template).
Record every flip in `dev/M6-BUILD-LOG.md`.  Watchdogs stay at the
named tiers; no numeric literal enters any leg.

| # | Mutation | Predicted flip route | Restore proof |
| --- | --- | --- | --- |
| M-E1 | `scrubLines` returns `ls` unchanged (identity body) | PASS-M6E-REWRAP-SCRUB red: c1 and c2 go 0 to 2, both envelopes non-empty (the HEAD false denies return) | `md5 examples/guard-rewrap.tot` equals the sealed value; battery green |
| M-E2 | `scrubLines` returns `nil _` for every input (scrub everything) | battery's FIRST red is upstream: PASS-M5D-REWRAP-GUARD (rd 2 to 0, deny empties).  Leg (c) of PASS-M6E-REWRAP-SCRUB pins the same fact in-block so the M6E leg stays sound if the M5D leg is ever reordered or retired | same |
| M-E3 | `main`'s parse-failure arm flips to `pureIO _ (deny "bad payload")` | PASS-M6E-REWRAP-OPEN red: c4 goes 0 to 2 on garbage.json (no upstream leg runs guard-rewrap on a non-JSON payload; probe P17 is the baseline) | same |
| M-E4 | revert ONE re-spelled site: guard.tot:136 back to `pureIO Verdict allow` | PASS-M6E-GUARD-HOLES red: `m6e_holes` drops to `<H>`-1 and the `-eq` literal bites (checks stay green, envelope stays identical: only the count sees it) | `md5 examples/guard.tot`; battery green |
| M-E5 | move the Stage E SPEC entry's `expected-type-only` literal by one | PASS-M5D-MEASURE-LOG red: `logE` differs from the tail -1 `specE`, proving the E4 splice is live; PASS-M6E-ANCHORS stays green (its literal is its own), showing the two ties are independent | `md5 SPEC.md`; battery green |
| M-E6 | in `dev/hole-anchors.py`'s CLASSIFIER only, reroute bucket A to N (one line; total, sum and --count-sites all unchanged) | PASS-M6E-ANCHORS red: the log line reads `argument-driven=0`, `[ "$m6e_line" = "$m6e_want" ]` fails while PASS-M5D-HOLE-ANCHORS and PASS-M5D-MEASURE-LOG stay green (E untouched): the only leg that pins A and N is this one | `md5 dev/hole-anchors.py`; battery green |
| M-E7 | TRANSCRIPT STALENESS: narrow `dev/gen-m5e-transcript.sh`'s glob to `examples/*.tot` and reseal with the narrowed output | PASS-M6E-TRANSCRIPT-RESEALED red at blocks-vs-files (blocks about 6, files 80+): PASS-M5E-DEFAULT-IDENTITY stays GREEN because the fresh regeneration uses the same narrowed glob and diffs empty.  This is the vacuity the reseal leg exists to catch, and this row is the required staleness mutation | `md5 dev/gen-m5e-transcript.sh` and `md5 dev/m5e-default-transcript.txt`; battery green |

One more staleness route is already owned upstream and is recorded,
not re-proved: sealing a STALE transcript with an honest generator
(restore the Stage-D seal, keep the sources) flips
PASS-M5E-DEFAULT-IDENTITY at the diff, which is pin 14's enforcement
point doing its job; leg v's scrubLines assertion would also go red
if reached.

### E10. Deliberate non-changes

1. `stdlib/prelude.tot`: zero bytes.  The 40 prelude E anchors stay
   explicit (SCOPE OUT 5); leg iii's prelude-zero assertion turns the
   promise into a gate.
2. `dev/hole-anchors.py`: zero bytes on the shipped walk (mutation M-E6
   touches it and restores md5-identical).  Probe P20 proves the
   classifier needs no `_` handling: a hole is one anchor token.
3. `dev/gen-m5e-transcript.sh`: zero bytes on the shipped walk
   (mutation M-E7 restores md5-identical).  Its glob and its
   pre-existing `for` loop stand; Stage E authors no loop in any file
   it touches, gates included.
4. The `PASS-M5E-DEFAULT-IDENTITY` leg: unchanged text, unchanged
   place, still the between-stages enforcement point (pin 14).
5. The `PASS-M5D-REWRAP-GUARD` leg and its two fixtures: unchanged;
   probes P10/P11 pin the behaviour the scrubber must preserve.
6. The A anchors (guard.tot:133/:134 arg 0, guard-rewrap.tot
   :162/:163 arg 0) and the N anchors (guard-classes.tot:15/:23/:27):
   explicit, by pin 3 and SCOPE OUT 4.
7. `examples/guard.tot` and `examples/guard-classes.tot` checker
   OUTPUT: byte-identical through the re-spell (pin 1 conservativity;
   leg v pins guard.tot's block verbatim, the E5 review covers
   guard-classes).
8. The tokenizer duplication between guard.tot and guard-rewrap.tot:
   stays, and the scrubber compounds it knowingly (no modules, flat
   namespace, prelude edits out of scope); the SPEC section 6 debt is
   restated, not paid.
9. `Cache.format_version` stays 10 (pin 15): nothing in this stage is
   on a cached path.
10. `--serror-exit`, the strict-json postures, the budget, the WF
    deletion: Stage A-D surfaces, not revisited here; their markers
    must still pass in the exit battery unchanged.

### E11. Exit criteria

1. Battery: `dev/gates.sh` prints `GATE-EXIT=0`, 0 FAIL.
2. Arithmetic, chained from 334 (pin 18; verdict stage allocation):
   334 (M5 exit) -> 339 (Stage A: -1 kernel, -1 marker, +7 markers)
   -> 345 (Stage B: +2 surface, +4 markers) -> 360 (Stage C: about
   +10 suite, +5 markers) -> 365 (Stage D: +5 markers) -> 370
   (Stage E: +5 markers, nothing retired, no suite change).
   Recomputed by suite: kernel 105, surface about 119, markers 146;
   105 + 119 + 146 = 370.  The verdict's tolerance stands: counts may
   drift by one or two per stage; the monotone walk, the marker names
   and GATE-EXIT=0 at every boundary are binding.
3. The five markers print: PASS-M6E-REWRAP-SCRUB,
   PASS-M6E-REWRAP-OPEN, PASS-M6E-GUARD-HOLES, PASS-M6E-ANCHORS,
   PASS-M6E-TRANSCRIPT-RESEALED.
4. `rg -c '^PASS'` on the battery output = the stage target (about
   370), recorded with the command in `dev/M6-BUILD-LOG.md`.
5. PASS-M5D-TIERS literal raised by exactly 9 (predicted 166,
   chaining 122 +4 +8 +17 +6 +9) with the before/after `rg -c`
   numbers recorded.
6. The seven mutation rows executed, flips observed on the predicted
   routes, restores proved md5-identical.
7. The SPEC entry (E8) and section 6 edits landed; the MEASURE-LOG
   splice (E4) landed in the same commit as the SPEC entry.
8. The build log records: the classifier rerun outputs (both
   commands), the solve count with any ceiling shortfall, the
   reviewed reseal hunk list, and the P-series probe commands rerun
   against the built binary where this section marks them.
9. The user commits.  Nothing lands committed by an agent (pin 18).

### E12. Conflict notes (dated 2026-09-03)

C1.  "Criterion 3" naming.  The house Python guard states FOUR
criteria (bare `let ... ?;`, `Ok(` next, block tail, bound name used)
and treats the scrubber as machinery besides them; under that
numbering criterion 3 is the block-tail test.  The verdict's SCOPE
IN 7 writes "port rewrap criterion 3 (the scrubber)": the parenthesis
is the pin's own definition and wins.  RESOLUTION: this stage ports
the scrubber; the block-tail test, the used-name test and the net-new
comparison stay unported and are restated as the remaining debt (E8).
No behaviour intended by the pin is lost.

C2.  `PASS-M5D-MEASURE-LOG` assumes one `expected-type-only=` match
in SPEC.md (probe P9: exactly one at HEAD, SPEC.md:1633).  Recording
the new ANCHORS line in SPEC, as pin 4 and SCOPE IN 7 require, makes
the extraction multi-line and the leg red on a fully correct tree.
RESOLUTION (E4): the same commit splices `| tail -n 1` into the
extraction so the gate compares the NEWEST SPEC record against the
battery's own classifier output; mutation M-E5 proves the splice bites.
The pin's intent (SPEC and log cannot drift) is kept; the gate's
scope sharpens from "the one number" to "the current number".

C3.  The verdict's stage allocation says Stage E "records the
measured solve count", and pin 4 says E = 59 is a ceiling.  At HEAD
40 of the 59 are prelude anchors that SCOPE OUT 5 forbids touching,
so the count this stage can measure tops out at 19, not 59.  This is
consistent once read together (the prelude 40 are M7's measurement),
but the plan states it plainly so nobody reads 59 as the Stage E
target: RESOLUTION: the SPEC entry reports solved-of-19 for this
stage, names the 40 as deferred with the debt, and leaves pin 4's
ceiling arithmetic intact.

