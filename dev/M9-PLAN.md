# M9 build plan: the SPEC repair, the demand instrument, and the twelve surface interfaces

## 1. Purpose and entry state

M9 pays the M8 exit stamp M8's own plan owed and did not write, builds
one demand instrument for the three candidates M8 deferred, and sweeps
the twelve `surface/*.mli` interfaces last.  M9 adds no admission rule to
`lib/`, lands no well-founded descent, and flips no polarity rule: C1 and
C2 stay deferred, to M10, and C7 is rejected outright.  This document
plans a plan commit, P0, followed by three stages, A through C, against
M8's four stages and M7's five.

The reference state for every citation and every probe in this plan is
the tot working tree at HEAD `5538927`, the commit that closes M8 Stage
D.  `git -C /Users/oobi/Documents/tot status --porcelain` printed 0 lines
against this HEAD and `git -C /Users/oobi/Documents/tot diff` is empty,
so a plain read agrees with `git show HEAD:<path>` everywhere in this
plan.  This plan does not build, does not run `dune`, `dunecho`, `make`
or `opam`, and does not run any binary under
`/Users/oobi/Documents/tot/_build`.  Every number about the gate battery
is measured with `rg` or `fd` against the tracked tree, or is marked
ESTIMATE.

### 1.1 Ratification

The user ratified the M9 design verdict in
/Users/oobi/Documents/tot-m9-ratifications.md.  The seven rulings below
outrank the verdict, proposal 3, and all three attacks.  Each is quoted
verbatim, with the one consequence it carries for this plan.

**R-Q1**, verbatim: "Stage B ports
/Users/oobi/.claude/hooks/cd-prefix-guard.py (382 lines), not
map-over-rewrap-guard.py.  The port ships as ONE new .tot file under
examples/.  The smaller port still yields a non-zero instrument reading
and does not make M9 depend on the machinery it measures demand for."
Consequence: Stage B ports exactly one hook into exactly one new `.tot`
file under `examples/`; no second port, and no port of
map-over-rewrap-guard.py, lands anywhere in M9.

**R-Q2**, verbatim: "the demand instrument is the count of rewrites the
kernel FORCED during the port, 2 at HEAD (the two pre-rewrite spellings
refused by `wordEnd failed the structural termination guard` and
`invalid constructor mkRule: negative or non-uniform occurrence of
Rule`), recorded in dev/M9-BUILD-LOG.md and pinned by
PASS-M9B-DEMAND-ORACLE.  A reading of 0 leaves a candidate UNRANKED for
M10, never retired; no instrument in one milestone retires a debt SPEC
records."  Consequence: the pinned reading this plan predicts is 2, not
0; dev/M9-BUILD-LOG.md must record it, and no M9 leg may treat a zero
reading, had one occurred, as a retirement of C1, C2 or C7.

**R-Q3**, verbatim: "in M10, C2's polarity rule lands FIRST and soaks (M8
R-Q2 wording), then C1.  The M10 brief answers the double-flip sign
lattice of finding A2-F1 before any rule is costed.  M9 records this
order in dev/M9-PLAN.md and edits no kernel rule."  Consequence: this
plan records the M10 stage order as a fact for the next milestone's
brief; no stage in M9 edits a kernel rule to test or enforce that order.

**R-Q4**, verbatim: "Stage B COMMITS its example under examples/ (tracked
corpus).  It reseals dev/m5e-default-transcript.txt through
dev/gen-m5e-transcript.sh so the two diff legs at dev/gates.sh:2486 and
:3259 return to green, and it re-runs the settle-budget leg's own recipe
(dev/gates.sh:3614-3621) to rewrite whichever of the three literals moved
(m7a_files 104, m7a_green 62, the digest).  Neither chore adds a marker.
A dogfood port that is not in the corpus is not dogfood."  Consequence:
Stage B's example is a committed fixture under `examples/`, not a
scratch file; the transcript reseal and the settle-budget literal
rewrite land in the same commit as the example, and neither chore may
carry a marker of its own.

**R-Q5**, verbatim: "Stage C covers all twelve surface/*.mli in one
stage.  If it overruns, surface/elab.ml ALONE splits into a Stage D; the
coverage leg asserts 12 and 12 with gap 0 wherever it lands and is never
weakened below 12."  Consequence: the Stage C coverage leg's count is
fixed at 12 and 12, gap 0; if a Stage D is opened, only surface/elab.ml
moves to it, and the count in whichever stage carries the coverage leg is
never weakened below 12.

**R-Q6**, verbatim: "C5 is the SPEC two-horn record only, no code half
and no new marker.  lib/interp.ml:92-95 and surface/run.ml:117-120 are
untouched; PASS-M7E-SPEC-CITATIONS (dev/gates.sh:3930-3931) already
counts both sites."  Consequence: C5 contributes no code and no new
marker to any M9 stage; `lib/interp.ml:92-95` and `surface/run.ml:117-120`
stay untouched through M9, and PASS-M7E-SPEC-CITATIONS remains the only
leg that counts either site.

**R-Q7**, verbatim: "C7 keeps SPEC debt entry 11 (SPEC.md:2668, "No
measured demand") with an annotation that the M9 instrument adds a
measured reading, not a repeal.  Cumulativity is not re-opened until a
hook port or example produces a `Type 1` equation the tree actually
needs."  Consequence: C7 keeps SPEC debt entry 11 with an added
annotation only; no M9 stage repeals or re-opens cumulativity, and no M9
leg may read the instrument's non-zero result as grounds to do so.

Carried rulings, also binding.  A3-F7 fixes the exit-arithmetic model as
a DELTA model only: exit equals entry plus new markers plus new suite
cases in EITHER suite, the absolute term is never re-derived, and every
stage names which suite a case lands in.  A3-F6 and A3-F5 fold proposal
3's two Stage A legs into one leg carrying a tree-side conjunct, and
forbid a third absolute `awk 'NR=='` pin beyond the two already at
dev/gates.sh:3927-3928.  A3-F3 fixes the demand instrument's counted
quantity as kernel-FORCED rewrites, never shipped refusals, which are 0
by construction.  A3-F4 requires surface/cache.mli to export
`format_version` plus the five internals test/surface.ml reads at
surface/cache.ml:129, :130, :131, :133 and :170, and to hide the three
filesystem mutators.  R11 requires the PASS-M9 namespace to be unused
before this scope; measured, `rg -o 'PASS-M9[A-Z0-9-]*'
/Users/oobi/Documents/tot/dev/gates.sh` prints nothing at HEAD.  C-A14 is
the standing offset: the gate wrapper's `PASS=` line reads the gate slice
plus 4.  R10 gives each mutation proof exactly one edit, and no two legs
in this plan share a mutation proof.  C-D3 is the conflict-note shape a
stage uses when the repo refuses a predicted mutation.  M8 R-Q2 keeps
both fence legs green through M9: measured at HEAD, PASS-M6A-FENCE-
COVARIANT's echo sits at dev/gates.sh:2587, not at dev/gates.sh:2531-2535
as the ratification's own carried text cites, because M8 Stage D's edits
moved the site (the same R-S1 line-drift dev/M8-PLAN.md:38-41 records for
this exact leg); no nested-inductive rule lands in M9.  M8 R-Q6 keeps
`Cache.format_version` at 10 and admits no jarr migration in M9.

### 1.2 Baseline

M9 opens after M8 Stage D, HEAD `5538927`.  `git -C
/Users/oobi/Documents/tot log --oneline -1` prints "5538927 M8 Stage D:
lib/ takes its interfaces, the kernel environment moves behind a private
store, gate battery 437 to 441".

Gate command battery (all four must be green before any stage report),
unchanged from M8 (dev/M8-PLAN.md:104-109):

    dune build --root /Users/oobi/Documents/tot
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -3
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -3
    zsh /Users/oobi/Documents/tot/dev/gates.sh > "$TMPDIR/tot-gate.out" 2>&1; echo "GATE-EXIT=$?"

A bare shell has no dune on PATH; every dune command needs
`eval "$(opam env)"` first, in the same shell invocation.  Never delete
or weaken an existing marker or an existing test to make a stage green;
M9 retires no existing marker and no existing test.

Entry facts.  The gate slice is 441 PASS, 0 FAIL, and the wrapper prints
445 under C-A14's plus-4 offset (dev/M8-BUILD-LOG.md:2229 and :2981, the
row "| the battery slice | 437 | 441 |"; this plan does not re-run the
battery to reproduce 441, since the tree is read-only here and no dune
runs in this slice, so the two counts are carried forward from the M8
closing record, not re-measured by this plan).  `rg -o 'echo
PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | wc -l` prints
177 (measured).
`fd -e ml --max-depth 1 . /Users/oobi/Documents/tot/lib | wc -l` and the
same command with `-e mli` both print 18 (measured).  `fd -e ml
--max-depth 1 . /Users/oobi/Documents/tot/surface | wc -l` prints 12 and
the same command with `-e mli` prints 0 (measured).  `git -C
/Users/oobi/Documents/tot ls-tree -r HEAD --name-only | rg -c
'^test/fixtures/'` prints 124 (measured).  `wc -l
/Users/oobi/Documents/tot/SPEC.md` prints 2715 (measured).  `wc -l
/Users/oobi/Documents/tot/dev/gates.sh` prints 4587 (measured).  The
surface suite stands at 158 cases and the kernel suite at 105
(dev/M8-BUILD-LOG.md:2225 and :337-339), both carried forward from the
M8 closing record and not re-run here.

Marker collision check (R11).  `rg -o 'PASS-M9[A-Z0-9-]*'
/Users/oobi/Documents/tot/dev/gates.sh` prints nothing at HEAD (measured),
so the PASS-M9 namespace is free against the 177 existing sites.

The arithmetic model is a DELTA model only, per A3-F7.  177 `echo PASS-`
sites plus 158 surface cases plus 105 kernel cases is 440, one short of
the measured entry slice of 441, so no stage in this plan re-derives the
absolute 441; every stage states its own delta against the entry it
re-measures at stage-open time, and names which suite a new case lands
in.

### 1.3 Scope in and scope out

Quoted, the verdict's scope statement (design-verdict.md:12-23):

> HYBRID on proposal 3's spine: measure first, then consolidate.  Three
> stages plus a plan commit.  C3 (the M8 exit stamp and the SPEC repair)
> lands first, C6 (one dogfood hook port as the demand instrument) is the
> middle stage, C4 (the twelve surface/*.mli interfaces) lands last.  C1
> and C2 are DEFERRED to M10, C5 is kept open with its cheap SPEC half
> only, C7 is REJECTED for M9.

Scope out, quoted, C1 taken deep (design-verdict.md:26-41): "Proposal 1
(C1 deep) is holed at the battery, not at the design... That leg sits at
dev/gates.sh:2477 in a 4587-line file whose FAIL arm ends `exit 1`
(dev/gates.sh:2494), so Stages A, B and C cannot report a green battery
and their exit slices are unreachable... C1 is a good milestone, but not
this one and not at this price."

Scope out, quoted, C2 taken deep (design-verdict.md:43-55): "Proposal 2
(C2 deep) is holed at soundness.  Its polarity arm 2 admits an occurrence
in a Pi domain at the flipped sign, so two flips return to `Pos` and the
rule accepts a family the shipped fence refuses... A milestone whose
headline rule can weaken the positivity fence in a total language
(README.md:1-4) is not a milestone to take on a first pass."

Scope in, quoted, C4's deferral condition met (design-verdict.md:61-69):
"Its stages also clear C4's own stated blocker.  dev/M8-PLAN.md:2892-2900
defers the surface sweep because three of the twelve files,
surface/elab.ml, surface/run.ml and surface/bootstrap.ml, are files M8's
own stages edit.  No stage in this scope edits any surface/*.ml body...
The condition dev/M8-PLAN.md:2899-2900 names, 'a milestone whose stages
do not touch those three files', is met by this scope and by no other
proposal on the table."

### 1.4 The candidate table

One row per candidate.  Stage letters and marker names are the
ratification's stage table (tot-m9-ratifications.md:7) and the verdict's
per-candidate disposition (design-verdict.md:82-165); the stage slices
own their internals, not this section.

| Candidate | Stage | Markers | Verdict line that allocates it |
| --- | --- | --- | --- |
| C3, the M8 exit stamp and the SPEC repair | A | PASS-M9A-EXIT-STAMP | "C3, the M8 exit stamp and the SPEC repair: IN, and it lands FIRST." (design-verdict.md:112) |
| C6, a second dogfood hook port as the demand instrument | B | PASS-M9B-CD-PORT, PASS-M9B-DEMAND-ORACLE, PASS-M9B-REGEX-FIDELITY | "C6, a second dogfood hook port as the demand instrument: IN, middle stage." (design-verdict.md:142) |
| C4, the twelve surface/*.mli interfaces | C | PASS-M9C-SURFACE-MLI-COVERAGE, PASS-M9C-SURFACE-INTERNAL | "C4, the twelve surface/*.mli interfaces: IN, last stage." (design-verdict.md:123) |
| C5, the Frozen emptiness obligation | A (SPEC record only) | none | "C5, the Frozen emptiness obligation: DEFERRED, SPEC half only." (design-verdict.md:131); R-Q6 keeps it a SPEC entry, no code half and no new marker |
| C7, cumulativity or an Eq1 layer | none, rejected for M9 | none | "C7, cumulativity or an Eq1 layer: REJECTED for M9." (design-verdict.md:154); the only demand anyone produced is a hand-written probe, and its own mutation proof is refuted by probe (design-verdict.md:157-162) |
| C1, the WF package behind an accessibility-shape selector | none, deferred to M10 | none in M9 | "C1, the WF package behind an accessibility-shape selector: DEFERRED to M10." (design-verdict.md:84-85); deferred because the selector needs data the kernel entry point does not receive (design-verdict.md:89-94) |
| C2, nested inductives and the polarity rule | none, deferred to M10 | none in M9 | "C2, nested inductives and the polarity rule: DEFERRED to M10." (design-verdict.md:100); deferred because the rule as sketched is unsound in one arm, admitting a doubly flipped shape the shipped fence refuses (design-verdict.md:100-105) |

Six markers across three stages: one in Stage A, three in Stage B, two in
Stage C, matching the ratification's stage-table total.  R-Q3 records,
but does not build, the M10 order this table's C1 and C2 rows carry
forward: C2's polarity rule lands first in M10 and soaks, then C1.

Section 1 ends.

## 2. Gate arithmetic and the marker namespace

This section is cross-cutting.  It carries no stage's payload and it
adds no `PASS-M9` leg of its own.  It states the numbers every stage
section quotes, the rule that keeps the wrapper and the slice from
mixing (C-A14), the proof that the `PASS-M9` namespace is free (R11),
the marker naming rule every later section must follow, and the two
carried protocols, mutation proof (R10) and cache discipline (the
carried M8 R-Q6, distinct from M9's own R-Q6), in the form the stage
sections use.

Citation rule for this section.  Every citation is read from the
committed blob at HEAD 5538927.  `git -C /Users/oobi/Documents/tot
status --porcelain` prints 0 lines, so the working tree equals HEAD and
a plain read agrees with `git show HEAD:<path>`.  No file under
`/Users/oobi/Documents/tot` is written, moved or built by this plan or
by the drafting of it.

### 2.1 Entry and the stage chain

Entry is 441 for the gate slice and 445 as the wrapper prints it,
MEASURED at the M8 close, not re-derived here: `dev/M8-BUILD-LOG.md:2981`
states "the battery slice | `slice.sh` on the closing log | 441 | 441",
`dev/M8-BUILD-LOG.md:2982` states "the wrapper number | `rg -n '^PASS='
<log> \| tail -1` | 445 | 445", and `dev/M8-BUILD-LOG.md:3026-3027`
closes with "SLICE 441, FAIL 0, GATE-EXIT 0, BUILD-EXIT 0, with the
wrapper number 445 as a note."  The slice's own terms are also carried
from section 1.2's entry-state measurement, not re-measured fresh in
this section: `rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh
| wc -l` prints 177, the surface suite reads 158 cases
(`dev/M8-BUILD-LOG.md:2225`, "`test/surface.ml` case count, the suite's
own PASS total | 157 | 158", confirmed again at `dev/M8-BUILD-LOG.md:2302`),
and the kernel suite reads 105 cases (`dev/M8-BUILD-LOG.md:337`,
"`dune exec --root . test/main.exe` reads 105 PASS 0 FAIL").  177 plus
158 plus 105 is 440, one short of the measured 441, so the model this
section uses is a DELTA model only: exit equals entry plus new markers
plus new suite cases in EITHER suite, and the absolute term is never
re-derived.  This is A3-F7, carried from the verdict
(`/Users/oobi/Documents/tot-m9-design-verdict.md`, finding 21, ACCEPT),
and it binds every stage section that follows: each one names which
suite, kernel or surface, a new case lands in.

Chain, ESTIMATE: 441 -> 441 (P0) -> 442 -> 447 -> 450 slice, wrapper +4: 445 -> 445 -> 446 -> 451 -> 454

| Stage | Theme | Markers | Suite cases | Entry | Exit slice | Exit wrapper |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | plan commit, dev/M9-PLAN.md only | 0 | 0 | 441 | 441 | 445 |
| A | the M8 exit stamp, the SPEC repair and the C5 record | 1 | 0 | 441 | 442 | 446 |
| B | the demand instrument, the cd-prefix-guard.py port | 3 | 2 | 442 | 447 | 451 |
| C | the twelve surface/*.mli interfaces | 2 | 1 | 447 | 450 | 454 |

This table is taken from the ratified stage table paragraph
(`/Users/oobi/Documents/tot-m9-ratifications.md`, the "Stage table (gate
slice, wrapper in parentheses)" paragraph) and reproduces the same
entry, marker and suite-case counts as
`/Users/oobi/Documents/tot-m9-design-verdict.md` section 3 ("Stage
sketch, with exit-battery estimates in the M8 form"), P0 through Stage
C, columns unchanged in order.  Every cell above is ESTIMATE.  None of
it is measurable with `rg -c` on `dev/gates.sh` today, because none of
the `PASS-M9` legs exist yet; a stage section re-measures its own row
at close and books a difference as a conflict note, the C-D3 shape, not
a silent edit of this table.

### 2.2 The arithmetic that ties the rows together

Row by row, each column reconciles against its left neighbour:
441 + 0 + 0 = 441 (P0), 441 + 1 + 0 = 442 (A), 442 + 3 + 2 = 447 (B),
447 + 2 + 1 = 450 (C).  Column totals: 0 + 1 + 3 + 2 = 6 markers,
0 + 0 + 2 + 1 = 3 suite cases.  Six markers plus three suite cases is
+9, and 441 + 9 = 450 slice.  The wrapper carries the same +9 from its
own entry, 445 + 9 = 454, which is also 450 + 4, so the two ways of
reaching 454 agree, and this is the milestone total the ratification
states: "Milestone: entry 441, six markers, three suite cases, exit
450" (`/Users/oobi/Documents/tot-m9-ratifications.md`, stage table
paragraph), matched by the verdict's own line "Milestone total: entry
441, six markers, three suite cases, exit 450"
(`/Users/oobi/Documents/tot-m9-design-verdict.md`, end of section 3).

The M8 comparison, verbatim: "Eleven markers plus ten suite cases is
+21, and 420 + 21 = 441 slice" (`dev/M8-PLAN.md:251-252`, verified at
that line at HEAD).  M9's +9 is under half of M8's +21, on three stages
plus a plan commit against M8's four stages, which matches the shrink
the spine itself names: "the shrink is deliberate: Stage A is a
document stage the M6 precedent 2aa189c shows can stand alone, and
Stage C is a chore stage" (`/Users/oobi/Documents/tot-m9-proposal-3.md`,
section 1).

### 2.3 C-A14: the wrapper never mixes with the slice

Rule.  The wrapper prints 4 more than the gate slice at every entry and
every exit, in every stage, with no exception.  A stage section states
both numbers side by side, `NNN slice (MMM wrapper)`, and never
substitutes one for the other.  A review checklist item that quotes a
bare integer without saying which of the two it is has not honoured
C-A14.

Proof this holds across the table in section 2.1: 445 - 441 = 4 (P0),
446 - 442 = 4 (A), 451 - 447 = 4 (B), 454 - 450 = 4 (C).  The offset is
invariant because every stage adds the same delta to both columns;
C-A14 does not depend on the size of a stage, only on the constant
carried from M8 close and restated in the carried-rulings list:
"C-A14 (the wrapper `PASS=` count reads four higher than the gate
slice)" (`/Users/oobi/Documents/tot-m9-ratifications.md`, carried
rulings paragraph), itself the M8 form of the rule
(`dev/M8-PLAN.md:265-281`).  The mechanism behind the offset is
`battery.sh` piping the two suite runs through `tail -3`
(`dev/M8-BUILD-LOG.md:2561-2563`, "the wrapper `PASS=` line reads 445 ...
because `battery.sh` pipes the two suite runs").

### 2.4 R11: the marker namespace is clear, proved

R11 requires the `PASS-M9` namespace to be unused before this scope
opens.  Two commands prove it, both run over `dev/gates.sh`, both
MEASURED for this plan, not estimated.

Command: `rg -o "PASS-M9[A-Z0-9-]*" /Users/oobi/Documents/tot/dev/gates.sh`
Output: no line printed, exit 1 (`rg` prints nothing and exits 1 when a
pattern has zero matches).  Zero `PASS-M9` occurrences in the committed
blob at HEAD 5538927.

Command: `rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | wc -l`
Output: `177`.  All 177 existing `echo PASS-` sites carry a name other
than `PASS-M9*`, so the six names this plan reserves,
`PASS-M9A-EXIT-STAMP`, `PASS-M9B-CD-PORT`, `PASS-M9B-DEMAND-ORACLE`,
`PASS-M9B-REGEX-FIDELITY`, `PASS-M9C-SURFACE-MLI-COVERAGE` and
`PASS-M9C-SURFACE-INTERNAL`, are free against every one of the 177.

This reading matches the design verdict's own claim exactly
(`/Users/oobi/Documents/tot-m9-design-verdict.md` section 3, "Marker
collision check (R11): `rg -o 'PASS-M9[A-Z0-9-]*' dev/gates.sh` prints
nothing at HEAD, so all six names below are free against the 177
existing sites").  No difference to report on R11 itself.  The stage
sections that mint these six names each re-run the single-name form of
this check, `rg -c 'PASS-M9<stage>-<NAME>' dev/gates.sh`, against its
own name before claiming the slot (section 2.5, condition 2).

### 2.5 The marker namespace rule for M9

Every new gate marker this milestone adds is named `PASS-M9<stage>-
<NAME>`, where `<stage>` is one capital letter, `A`, `B` or `C`, and
`<NAME>` is the leg's own name in the same all-capitals,
hyphen-separated style the surviving `PASS-M7*` and `PASS-M8*` legs
already use, for example `PASS-M7D-CACHE-KEY`
(`dev/gates.sh:3857`, `rg -n 'PASS-M7D-CACHE-KEY'
/Users/oobi/Documents/tot/dev/gates.sh` prints five lines, its
definition comment at `:3857`, its own `echo` at `:3887` and three later
comment references at `:4249`, `:4253` and `:4326`).  Three conditions
bind every stage section that follows this one:

1. Unique across the whole plan.  No two stage sections mint the same
   `PASS-M9<stage>-<NAME>`, and no stage section reuses a name from
   another stage's letter.
2. Absent from `dev/gates.sh` in the reference state, HEAD 5538927, at
   the moment the stage section is written.  Section 2.4 proves this
   holds for the whole `PASS-M9` prefix today; a later stage section
   that adds a name re-runs the same `rg -c` check against its own name
   before claiming the slot.
3. Never collides with a surviving `PASS-M6*`, `PASS-M7*` or `PASS-M8*`
   name, because those legs stay in the battery through M9.  The two
   fence legs the carried rulings name explicitly stay green:
   `PASS-M6A-FENCE-COVARIANT` (verified at `dev/gates.sh:2587`, inside
   the tripwire comment block opening at `dev/gates.sh:2578`, "Gate A
   (vi)+(vii), the positivity-fence tripwires") and
   `PASS-M6A-FENCE-CONTRAVARIANT` (`dev/gates.sh:2595`), plus the
   `PASS-M7E-WF-PROVENANCE-ORACLE` shape (`dev/gates.sh:3942-3960`), per
   the carried M8 R-Q2 wording, "both fence legs ... stay green through
   M9; no nested-inductive rule lands in M9"
   (`/Users/oobi/Documents/tot-m9-ratifications.md`, carried rulings
   paragraph).  Note: the ratification's own line for this leg,
   `dev/gates.sh:2531-2535`, is stale; that span reads as the
   `PASS-M6A-ACC-GUARD-REJECTED` leg's body at HEAD, not the fence leg.
   The verified span is `dev/gates.sh:2578-2596`, which matches the
   design verdict's own citation for the same two mutations
   (`/Users/oobi/Documents/tot-m9-design-verdict.md` section 3, Stage B,
   "pinned earlier at dev/gates.sh:2545-2551 and dev/gates.sh:2578-2596").
   Booked as a difference in notes, not silently corrected in the
   ratification's own text.

A stage section that cannot satisfy all three has found a namespace
conflict, not a design, the same standard M8's own section 2.5 set
(`dev/M8-PLAN.md:345-347`).

### 2.6 R10: the mutation-proof protocol, carried

Every gate leg this milestone adds carries a mutation proof: the one
edit, cited as `<path>:<line>`, that turns the leg from green to red
after its stage lands.  R10 states the consequence plainly: a leg with
no mutation proof is presumed vacuous.  No two legs may share a
mutation proof, because a shared proof means one leg is redundant with
the other and the pair proves nothing that one leg alone would not.
This is the carried ruling "R10 (one edit per mutation proof)"
(`/Users/oobi/Documents/tot-m9-ratifications.md`, carried rulings
paragraph).

The leg shape every mutation proof sits inside is fixed at
`dev/gates.sh:2507-2529`, verified at HEAD: one `echo PASS-<NAME>` line
on the success arm, a matching `FAIL-<NAME>` arm on the same
conjunction that prints the measured values, and `exit 1` on that
failure arm.  The verified span reads, in full:

```
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m5e-witness.tot 2>&1)
code=$?
wantw='m5e-witness.tot:2:1: recursive definition bad failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantw"; } \
  && echo PASS-M5E-WITNESS-REJECTED \
  || { printf '%s\n' "$out"; echo "FAIL-M5E-WITNESS-REJECTED (exit=$code)"; exit 1; }
```

No stage section may spell a leg any other way: a run of the binary or
a fixture read, a code capture, a conjunction of predicates on the exit
code and the output, an `echo PASS-<NAME>` on success, and a `FAIL-<NAME>`
arm that prints the captured values and exits 1 on failure.

The battery discipline that binds every stage, stated once here and not
repeated per stage: one `echo PASS-<NAME>` per leg, a matching FAIL arm
that prints the measured values, and `exit 1`, the shape just quoted.
Every leg carries a mutation proof, a leg with no mutation proof is
presumed vacuous, and no two legs share a mutation proof.  This
restates, for M9, the discipline the design verdict itself names for
the demand-instrument leg: "the leg's unique in-battery observable is
the two probe fixtures, which no earlier leg runs"
(`/Users/oobi/Documents/tot-m9-design-verdict.md` section 3, Stage B,
`PASS-M9B-DEMAND-ORACLE`).  Every integer any stage section states is
an ESTIMATE and is re-measured at that stage's close, per section 2.1
above.

Three shapes of broken mutation proof are excluded by this rule and
every stage section that follows must avoid all three, carried from the
M8 attack phase (`dev/M8-PLAN.md:377-386`): a proof that names an edit
the target function's own signature cannot accept; a proof that is
really two edits, so the leg does not say which half it observes; and a
proof that mutates the document the same stage writes rather than the
repo's behaviour.  The last shape binds Stage A hardest in M9, since
its own leg touches `SPEC.md`: a mutation proof for a Stage A leg must
edit a line Stage A does NOT itself write (for example a pre-existing
literal such as `SPEC.md:1932`'s `18`, not the new "Known debts entering
M9" paragraph Stage A adds), the same standard the verdict's own Stage A
mutation proof already meets.

### 2.7 The carried M8 R-Q6: cache discipline

This is the carried M8 ruling, distinct from M9's own R-Q6 (the C5
two-horn SPEC record, owned by Stage A).  No stage bumps
`Cache.format_version` from 10.  The constant is
`surface/cache.ml:118`, `let format_version : int = 10`, verified at
that line at HEAD.  The leg that measures it is `PASS-M7D-CACHE-KEY`, a
surviving M7 leg (`dev/gates.sh:3857-3887`), not a new M9 marker.  This
is the carried M8 R-Q6 wording restated for M9: "no stage bumps
`Cache.format_version` from 10; no jarr migration in M9"
(`/Users/oobi/Documents/tot-m9-ratifications.md`, carried rulings
paragraph, "M8 R-Q6").  No M9 stage section may touch `surface/cache.ml:118`
except to re-read it; Stage C's own interface work
(`PASS-M9C-SURFACE-INTERNAL`) exports `format_version` from
`surface/cache.mli` without changing the value it names, per the
carried finding A3-F4 (`surface/cache.mli` must export
`format_version` plus the five internals `test/surface.ml` reads at
`surface/cache.ml:129`, `:130`, `:131`, `:133` and `:170`, and must hide
the three filesystem mutators).  There is no jarr migration to cite
against, because none is scheduled anywhere in this plan; the clause
carries forward only as a negative constraint, unowned by any stage
section, the same way the design verdict frames C2's jarr migration as
deferred whole to M10 ("M9 does not have the room to settle a sign
lattice, a visited-set fixpoint and the jarr migration in one
milestone", `/Users/oobi/Documents/tot-m9-design-verdict.md` section 2,
C2 disposition).

Section 2 ends.



## 3. The conflict-note protocol

This section binds every M9 stage.  A stage predicts a source edit, a
literal, or a refusal message before it runs anything against the tree.
When the repo answers with something else, the stage does not guess and
does not retreat.  It re-measures, cites the lines that explain the
refusal, and books a conflict note in the shape this section names.  The
shape is C-D3, the note M7 Stage D wrote when stdlib/prelude.tot:94
refused its re-spell (dev/M7-BUILD-LOG.md:2311-2341).  Graft G8, the
count-honesty rule this section restates, is dev/M7-PLAN.md:793.  M8
Section 3 (dev/M8-PLAN.md:408-613) already restated this protocol once
without inventing a second shape;  M9 restates it a second time, for the
same reason M8 gave: the ratifications file names C-D3 as a carried
ruling (/Users/oobi/Documents/tot-m9-ratifications.md, "Carried rulings
from the verdict and from M8: ... C-D3 (the conflict-note shape when the
repo refuses a predicted mutation)").

Section 3 adds no PASS-M9 marker of its own.  It is the rule a stage
follows when one of ITS markers, defined in that stage's own section,
comes back red or half-red against a predicted reading.  Stage B's reseal
of dev/m5e-default-transcript.txt, owned by the Stage B slice, is the
worked case this protocol is written for (3.3).

### 3.1 The note shape, the template a stage fills in

Every conflict note has six numbered parts.  A builder fills all six
before moving past the stage that raised the conflict.

1. Predicted.  The exact reading the plan wrote before anything ran:
   the source spelling, the literal, or the exit code and message, each
   quoted from the stage's own design section, never from memory.
2. Measured.  What the repo did instead: the same three shapes (source
   state, literal, exit and message), each quoted from a real run, not
   summarized.
3. Command and output.  The one shell command that produced part 2,
   absolute paths, run from the repo root, and its output verbatim,
   trimmed only of surrounding noise.  A note with a described command
   and no printed output is not a note.
4. Cited lines.  The path:line pair or pairs in the tree that explain
   WHY the repo refused, read with rg -n or awk NR== at the time the
   note is written, not carried over from an earlier stage's citation.
5. The smallest reading that fits.  One sentence stating the narrowest
   correct description of the refusal: which site, which recipe, which
   literal, and whether the refusal is local to one site or reaches a
   class of sites.  C-D3's own smallest reading is the precedent: the
   refusal was specific to one congruence motive's infer-position use of
   its argument, not to Eq in general (dev/M7-BUILD-LOG.md:2324-2330);
   the same narrowing discipline, not the same subject, is what an M9
   note owes.
6. The decision.  Which of the two moves in 3.2 the builder takes, and
   why the repo's proof (not the builder's preference) selects it.

A note with fewer than six parts is not booked.  Part 3's command is
the part a later build workflow re-runs to check the note still holds;
a note that cannot be re-run is not trusted past its own stage.

### 3.2 The decision boundary

A builder has exactly two moves once a prediction is refused.

- Re-measure and book the note.  The builder records the six parts of
  3.1 in dev/M9-BUILD-LOG.md as C-<stage letter><n>, keeps the payload
  the ratification fixed, and lets the stage's exit numbers move by the
  measured amount, not the predicted one.  This is the only move a
  builder takes without asking anyone.
- Stop and report.  When the refused prediction IS the ratified payload
  itself, not a literal that moves around it, the builder stops the
  stage, books the note, and leaves the retreat decision to the user.

A builder never retreats from a ratified payload on its own reading of
the refusal.  Retreat from a ratified re-spell was named, by the plan M8
inherited, as a user ruling and not a builder decision: "Plan D8
(5037-5047) makes any retreat from the re-spell a user ruling and not a
builder decision, so this note stops at the record" (dev/M7-BUILD-LOG.md:2340-2341).
The same boundary holds for every ratified payload M9 carries: R-Q1's
named port target (Stage B ports cd-prefix-guard.py, 382 lines, and no
other hook), R-Q2's counting rule (the instrument counts kernel-FORCED
rewrites, never shipped refusals, and a reading of 0 leaves a candidate
UNRANKED, it never retires the candidate), R-Q4's corpus commitment
(Stage B's example lands under examples/, tracked, not a scratch
directory), R-Q5's coverage floor (the Stage C leg asserts 12 and 12
with gap 0 and is never weakened below 12, even if elab.ml splits into a
Stage D), and R-Q6's SPEC-only scope for C5 (no code half, lib/interp.ml:92-95
and surface/run.ml:117-120 stay untouched).  A stage that meets a
refusal on one of these books the note, stops, and waits;  it does not
choose a different payload and call the battery green.

### 3.3 R-Q4, the worked example

R-Q4 states the boundary in the concrete case this milestone already
expects to meet: Stage B commits its cd-prefix-guard.py port under
examples/ as tracked corpus, then reseals dev/m5e-default-transcript.txt
through dev/gen-m5e-transcript.sh and re-runs the settle-budget leg's own
recipe (dev/gates.sh:3614-3621) so the two diff legs at dev/gates.sh:2486
and dev/gates.sh:3259 return to green.  Filling the template against the
prediction Stage B carries into its own run:

1. Predicted.  Adding one new example under examples/ changes the
   transcript dev/gen-m5e-transcript.sh regenerates (it walks
   `examples/*.tot test/fixtures/*.tot` in a for loop and prints one
   `### <path>` block per file), so the checked-in
   dev/m5e-default-transcript.txt goes stale against a fresh run until
   Stage B reseals it;  after the reseal, PASS-M5E-DEFAULT-IDENTITY's
   `diff -q` at dev/gates.sh:2486 and PASS-M6E-TRANSCRIPT-RESEALED's
   block-count and named-block checks at dev/gates.sh:3259 both exit 0
   again, and the settle-budget recipe at dev/gates.sh:3614-3621
   (`m7a_files`, `m7a_green`, `m7a_digest`, derived at dev/gates.sh:3590-3592)
   reads whichever of its three literals the new file moves.
2. Measured.  What the reseal script and the recipe print once Stage B
   runs them: the new transcript byte content, the new `m7a_files`,
   `m7a_green` and `m7a_digest` values, and the exit codes of the two
   diff legs.  A note is booked only if one of these differs from the
   predicted shape above, for example if the new example's checked
   output is not what the reseal predicted, or if `m7a_green` moves by
   more than one (the new file is a POSITIVE fixture where R-Q1 and
   R-Q2 predict it must check with exit 0, so it must NOT join the
   green-count denominator the same way a negative fixture would).
3. Command and output.  `dev/gen-m5e-transcript.sh` run from the repo
   root, its stdout redirected to replace dev/m5e-default-transcript.txt;
   then `dev/gates.sh` itself, whose PASS-M5E-DEFAULT-IDENTITY and
   PASS-M6E-TRANSCRIPT-RESEALED legs print PASS or the FAIL arm's
   `diff`/counts on refusal.  The builder quotes the FAIL arm's printed
   `blocks=`, `files=`, `scrub=` values verbatim (dev/gates.sh:3262,
   the FAIL-M6E-TRANSCRIPT-RESEALED line) if either leg refuses.
4. Cited lines.  dev/gates.sh:2477-2494 for the PASS-M5E-DEFAULT-IDENTITY
   leg and its `diff -q` conjunct at dev/gates.sh:2486;  dev/gates.sh:3254-3262
   for the PASS-M6E-TRANSCRIPT-RESEALED leg and its combined assertion at
   dev/gates.sh:3259;  dev/gates.sh:3590-3592 for the three literals'
   derivation and dev/gates.sh:3614-3621 for the pinned values a prior
   stage (M7 Stage E) already had to move once under the same recipe.
5. Smallest reading.  If a refusal lands, it is scoped to whichever of
   the three sites disagrees: the transcript body (a byte mismatch the
   `diff -q` at :2486 reports), the block/name count (the equality
   checks at :3259), or one of the three settle-budget literals (a count
   mismatch the FAIL arm at dev/gates.sh:3614-3621's neighbourhood
   prints);  it is not read as a failure of the port itself unless the
   port's own PASS-M9B-CD-PORT leg is the one that refuses.
6. Decision.  A moved transcript byte, block count, or settle-budget
   literal is re-measured and booked per 3.2's first move: the reseal
   and the recipe are the RATIFIED mechanism (R-Q4), not the specific
   numbers they print, so a literal moving is not a retreat from the
   ratified payload and the builder re-measures and proceeds without
   asking.  Only a refusal that would mean Stage B's example itself
   cannot check at exit 0 (the payload R-Q1 and PASS-M9B-CD-PORT ratify)
   is a stop-and-report case.

This worked example is the exact sequence the build workflow re-runs
when Stage B opens: reseal, then re-run the settle-budget recipe, then
re-run PASS-M5E-DEFAULT-IDENTITY and PASS-M6E-TRANSCRIPT-RESEALED, before
Stage B's own new legs are added.

### 3.4 Count honesty

A predicted literal that the repo refuses is re-measured, and the new
value REPLACES the estimate everywhere the estimate was written, with
the derivation shown next to the replacement.  Graft G8 states the rule
this milestone inherits verbatim: "Every rg-derived or script-derived
count in [the] documents and gate comments ships WITH the exact command
that produced it, the command must actually PRINT the number, and
re-running it must reproduce the number" (dev/M7-PLAN.md:793).  A
literal is never edited to match a wish.  M7 Stage E already moved the
three settle-budget literals once under this exact rule, `m7a_files`
101 to 104, `m7a_digest` from one MD5 to another, green held at 62
(dev/gates.sh:3614-3621), and Stage B's port is expected to move some or
all three of these again in the same honest direction: measured, not
guessed, with the command shown.  R-Q2 extends the same discipline to
the demand instrument itself: 2 rewrites at HEAD is a measured reading
(`wordEnd failed the structural termination guard` and `invalid
constructor mkRule: negative or non-uniform occurrence of Rule`,
recorded in dev/M9-BUILD-LOG.md and pinned by PASS-M9B-DEMAND-ORACLE),
not a target Stage B edits the port to hit.  A stage that finds a
gate-battery count moving where a ratification pins it flat (R-Q5's
floor of 12 and 12, R-Q6's untouched two files) treats that as a
conflict in the 3.1 shape, not as a green literal edited quietly to hide
the move.

### 3.5 Walk discipline, reused by every stage

Every stage exits GATE-EXIT=0, 0 FAIL, at the stage table's stated exit
count, re-measured per 3.4 where a note applies.  Every mutation proof
this milestone ships flips its leg red by the named edit and then
restores the source to its pre-mutation bytes, md5-identical, before the
next leg runs (R10, one edit per mutation proof, no two legs sharing
one).  Every design decision a stage makes, including every conflict
note this section produces, becomes a dated entry in SPEC.md's decision
log, the same place M7 and M8 recorded their own stage decisions.  The
user commits; no stage agent commits.  Each stage stages its own paths
and leaves dev/M9-BUILD-LOG.md inside the repo at its own return.  A
stage that cannot reach GATE-EXIT=0 without silently dropping a leg has
found a conflict, not a design, and takes it through 3.1 and 3.2 rather
than shrinking the battery.

### 3.6 Review checklist shape, reused by every stage

Every stage's own review checklist, in its own section, restates these
items against that stage's files, in this order:

1. Every new gate leg matches the shape dev/gates.sh:2507-2529 already
   ships: one `echo PASS-<NAME>` on the pass route, a matching
   `FAIL-<NAME>` arm that prints the measured `out` and `code` values,
   and `exit 1` on the fail route.  No leg is checked by eye only; each
   one is read against this shape.
2. Every new marker's mutation proof is named, is a single edit cited
   as path:line, and is confirmed to flip the leg red and then restore
   the source md5-identical (R10, the same shape M7 and M8 shipped).
3. Every count the stage reports is measured, not guessed, with the
   command that produced it shown beside the number (3.4).  A number
   that a prediction refused is checked against a booked note, not left
   as the old prediction with a new comment.
4. Every conflict this stage met is booked under 3.1 in
   dev/M9-BUILD-LOG.md as C-<stage letter><n>, with all six parts
   present, before the stage is reported closed.
5. The incoming stage's PASS-M9<L> namespace stays collision-free:
   `rg -c 'PASS-M9<L>-'` over dev/gates.sh, with `<L>` replaced by the
   incoming stage letter, exits 1 with no output before its markers are
   added.  Earlier stages' markers remain present and green.  R11's
   whole-namespace absence check (`rg -c 'PASS-M9' dev/gates.sh` exits 1
   with no output at HEAD) runs once, before Stage A opens.
6. No new OCaml code the stage ships uses an exception, a partial
   index, a bool match, or a wildcard arm on an exhaustive match; the
   stage's own review checklist names the exact files it touches and
   confirms each one against this list, the same shape M7's and M8's
   own checklists used.

Section 3 ends.

# M9 plan slice: STAGE P0

Scope note.  This file is one slice of dev/M9-PLAN.md.  It covers only
STAGE P0, the plan commit that creates dev/M9-PLAN.md itself.  It is the
first stage in the M9 stage table (dev/M9-PLAN.md, Section 3 as ratified
in tot-m9-ratifications.md:7) and it precedes Stage A, the SPEC repair
and the C5 record.  Every citation below is read from the working tree
at HEAD `5538927` (M8 Stage D, closed 2026-09-06).  `git -C
/Users/oobi/Documents/tot diff` prints nothing at the time this slice is
drafted, so HEAD and the working tree agree and no citation below needs
a "current tree" qualifier.  This slice does not build, does not run
dune, and does not run any binary under /Users/oobi/Documents/tot/_build.
Every gate-battery number is measured with `rg` against dev/gates.sh or
is marked ESTIMATE, per the tree rules.

## STAGE P0: plan commit dev/M9-PLAN.md only, on the 2aa189c precedent

### Goal

Commit the M9 plan document, dev/M9-PLAN.md, as a single new file, on
the shape of commit 2aa189c ("M6 plan: repoint the stale SPEC anchors in
the debt list").  2aa189c touched exactly one file, dev/M6-PLAN.md, and
its message named, one line per repair, the old SPEC address a debt-list
bullet cited and the new SPEC address that bullet must cite instead,
because SPEC.md had moved out from under the bullet since the M6 plan
was written.  Stage P0 follows the same shape: it touches exactly one
file, dev/M9-PLAN.md, and its commit message names, per repointed
citation, the old address and the new address the plan text records.
dev/M9-PLAN.md does not exist in the tree today (`test -f
/Users/oobi/Documents/tot/dev/M9-PLAN.md` fails), so this is the file's
first commit, not a later repair of it; the repointed citation the
message names is one the plan text itself is the first place in the repo
to write down, the same way 2aa189c's SPEC-to-SPEC repoints were the
first place M6-PLAN.md wrote its corrected addresses. Stage P0 also
records, inside dev/M9-PLAN.md, the M10 stage order R-Q3 fixes: C2's
polarity rule lands first and soaks, then C1.  Stage P0 ships no leg,
edits no kernel rule, and edits no file other than dev/M9-PLAN.md.

### Rulings covered

- R-Q3.  "In M10, C2's polarity rule lands FIRST and soaks (M8 R-Q2
  wording), then C1.  The M10 brief answers the double-flip sign lattice
  of finding A2-F1 before any rule is costed.  M9 records this order in
  dev/M9-PLAN.md and edits no kernel rule."  Stage P0 is where this
  record lands: the plan's forward-reference section for M10 candidates
  states the order and cites A2-F1 by name.  No kernel rule is edited by
  this stage; `git -C /Users/oobi/Documents/tot diff HEAD -- lib/`
  printed nothing at the time this slice was drafted, and no edit in
  this stage's Files touched list names a path under lib/.
- A3-F7 (carried).  "The battery model is a DELTA model only, exit
  equals entry plus new markers plus new suite cases in EITHER suite,
  the absolute term is never re-derived, every stage names which suite a
  case lands in."  Stage P0 adds 0 markers and 0 suite cases in either
  suite, so its exit equals its entry under the same delta model the
  later stages use.
- R11 (carried).  "The PASS-M9 namespace is unused at HEAD."  Measured:
  `rg -o 'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh`
  prints nothing (0 lines).  Stage P0 adds no marker, so this namespace
  stays free for Stage A.
- C-A14 (carried).  "The wrapper `PASS=` count reads four higher than
  the gate slice."  Entry and exit are both given as slice figure and
  wrapper figure (slice + 4) below.
- R10 and C-D3 do not apply to this stage.  R10 requires one edit per
  mutation proof, and this stage ships no gate leg, so it owes no
  mutation proof.  C-D3 governs the conflict-note shape when the repo
  refuses a predicted mutation; this stage predicts no mutation.

### Entry state

Measured at the reference state, HEAD `5538927`:

- `rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | wc -l`
  prints 177.
- `rg -o 'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh | wc
  -l` prints 0: the PASS-M9 namespace is free (R11 satisfied).
- Entry slice 441 (wrapper 445) is the design verdict's own measured
  entry term (dev/M8-BUILD-LOG.md:2561-2563: "four numbers: SLICE=441,
  SLICE-BOUNDS=41,554, GATE-EXIT=0, BUILD-EXIT=0 and no `FAIL` line ...
  the wrapper `PASS=` line reads 445"), carried forward because M8
  Stage D is the last stage to close before this one opens and no gate
  leg or suite case has landed since.  It is not independently
  re-derivable from the 177-site count without running the suite (the
  arithmetic 177 gate echoes plus 158 surface cases plus 105 kernel
  cases sums to 440, one short of 441, per the verdict's own A3-F7
  finding), so 441 slice (445 wrapper) is carried as the entry term and
  marked ESTIMATE for this slice, matching the ratification's own stage
  table (tot-m9-ratifications.md:7, "P0 plan commit ... 441 to 441
  (445)").
- `test -f /Users/oobi/Documents/tot/dev/M9-PLAN.md` fails: the file
  this stage commits does not exist yet at the reference state.
- `git -C /Users/oobi/Documents/tot diff` printed nothing when this
  slice was read, confirming the working tree equals HEAD `5538927`, M8
  Stage D closed, with no unstaged carry-forward diff (unlike the M7 to
  M8 hand-off, which carried an unstaged Stage E diff).

### Files touched

- `dev/M9-PLAN.md`.  New file.  This commit's only path.  It carries the
  whole M9 plan (this stage plus Stage A, Stage B and Stage C, each
  assembled from its own slice), the same way dev/M8-PLAN.md carries all
  of M8's four stages in one file.  No other path changes: no gate
  file, no test file, no source file under lib/ or surface/, and no SPEC
  edit.  `git -C /Users/oobi/Documents/tot diff HEAD -- lib/ surface/
  test/ SPEC.md dev/gates.sh` must print nothing once this stage's
  commit lands; a non-empty result there means a later stage's edit
  leaked into this commit.

### Design

Stage P0 changes no OCaml function and no shell leg.  Its payload is the
plan text in dev/M9-PLAN.md, which this design section specifies in
full, since there is no code diff to describe instead.

The document opens with a purpose paragraph mirroring
dev/M8-PLAN.md:1-16 in shape: the milestone name, the HYBRID scope
(measure first, then consolidate), the reference commit (HEAD
`5538927`, M8 Stage D), and the four-stage list (P0, A, B, C) with one
clause each, matching the stage table already ratified
(tot-m9-ratifications.md:7).  This paragraph names no marker and edits
no file; it is prose only.

The document's forward-reference section for the two candidates
deferred to M10, C1 and C2, states R-Q3's order as a dated paragraph:
in M10, C2's polarity rule (lib/check.ml:1969, `no_occur dom` with no
sign, the arm the design verdict's finding A2-F1 (HIGH, ACCEPT) showed
admits a doubly flipped occurrence the shipped fence refuses today)
lands first and soaks before C1 is costed, and the M10 brief must answer
the double-flip sign lattice A2-F1 names before any rule lands.  This
paragraph is a plan record, not a code change: it names lib/check.ml:1969
as the site the M10 brief must revisit, but Stage P0 itself edits no
file under lib/, matching R-Q3's own closing clause, "M9 ... edits no
kernel rule."

The document's own text carries two address corrections found during
assembly, in the same one-line-per-repair shape 2aa189c used for its
six SPEC-to-SPEC repoints.  An earlier slice draft cited
PASS-M6A-FENCE-COVARIANT's echo at dev/gates.sh:2531-2535; at HEAD
`5538927` the echo sits at dev/gates.sh:2587, with the two fence legs
spanning dev/gates.sh:2578-2596 (contravariant echo at :2595).  An
earlier slice draft also cited the "Known debts entering M7" heading at
SPEC.md:2554; at HEAD `5538927` the heading sits at SPEC.md:2594.
dev/M9-PLAN.md, as P0 commits it, carries both addresses corrected
throughout the assembled document; the commit message names each
repoint, old address then new address, in the 2aa189c line shape:
`dev/gates.sh:2531-2535 (PASS-M6A-FENCE-COVARIANT, stale draft address)
-> dev/gates.sh:2578-2596 (the two fence legs, echo at :2587)` and
`SPEC.md:2554 ("Known debts entering M7" heading, stale draft address)
-> SPEC.md:2594`, followed by the Signed-off-by trailer 2aa189c itself
carries.

The debt-entry-6 repoint (SPEC.md's citation of lib/check.ml:1964-1976
to lib/check.ml:1913) is not named in the P0 commit message.  Stage A
performs that SPEC.md text change and names the repoint in its own
commit message when that stage lands; P0 touches no file under SPEC.md.
The SPEC.md repairs Stage A performs (the debt-entry-6 repoint, the
"M8 (done)" bullet, the dated "Known debts entering M9" heading, the
SPEC.md:2044-2045 repair against SPEC.md:1931-1933, and the C5 two-horn
record) are Stage A's own edits to SPEC.md, not citations the plan text
itself repoints, so none of them are named in the P0 commit message.

### Gate additions

None.  Stage P0 ships no leg.  It defines no PASS-M9P0-* marker, because
the verdict names no marker for this stage
(tot-m9-design-verdict.md:184-187, "Plan commit P0, dev/M9-PLAN.md.
Entry 441, markers 0, suite cases 0, exit 441 ... No leg, so no mutation
proof is owed") and the ratification's stage table agrees ("P0 plan
commit dev/M9-PLAN.md only, on the 2aa189c precedent, 441 to 441 (445),
no leg, no mutation proof").  dev/gates.sh is not touched by this stage's
commit: `rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | wc
-l` must still print 177 after this stage lands, and `rg -o
'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh` must still
print nothing, leaving the whole PASS-M9 namespace free for Stage A.

### Suite cases

None.  Stage P0 adds no case to test/main.ml or test/surface.ml.  A plan
commit that touches only dev/M9-PLAN.md has no OCaml surface to exercise
a suite case against; inventing one here would test the plan file's
prose, which is not what test/main.ml or test/surface.ml are for.

### Review checklist

1. Confirm `git -C /Users/oobi/Documents/tot diff --stat` for this
   commit lists exactly one path, dev/M9-PLAN.md.
2. Confirm the commit message names both the fence-covariant repoint
   and the "Known debts entering M7" repoint in the 2aa189c shape, one
   line each, old address then new address, and carries the
   Signed-off-by trailer.
3. Confirm `rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh |
   wc -l` still prints 177 after the commit, unchanged from Entry state.
4. Confirm `rg -o 'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh`
   still prints nothing after the commit, so Stage A opens onto a free
   namespace.
5. Confirm `git -C /Users/oobi/Documents/tot diff HEAD -- lib/ surface/
   test/ SPEC.md dev/gates.sh` is empty for this commit: no code file,
   test file, gate file or SPEC file moved.
6. Confirm the M10-order paragraph names C2 before C1, cites
   lib/check.ml:1969 and finding A2-F1, and edits no file under lib/.
7. Confirm the two repoints the plan records match the tree's current
   addresses: PASS-M6A-FENCE-COVARIANT's echo at dev/gates.sh:2587 with
   the two fence legs spanning dev/gates.sh:2578-2596, and the "Known
   debts entering M7" heading at SPEC.md:2594.

### Rollback

1. Delete dev/M9-PLAN.md.  It is this commit's only path, so deleting it
   fully reverts the stage.
2. Confirm `git -C /Users/oobi/Documents/tot status --porcelain` reports
   the deletion and nothing else pending under dev/, lib/, surface/,
   test/ or SPEC.md.
3. Re-run `rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh |
   wc -l` and confirm it still reads 177, and `rg -o
   'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh` still
   prints nothing, confirming the tree is clean for a later attempt at
   this stage.

Gate markers added: 0 (ESTIMATE)
Suite cases added: 0 (ESTIMATE)
Exit PASS count: 441 slice (ESTIMATE), 445 wrapper (ESTIMATE)

# M9 plan slice: STAGE A

Scope note.  This file is one slice of dev/M9-PLAN.md.  It covers only
STAGE A, the SPEC repair and the C5 two-horn record.  It assumes the
plan commit P0 (dev/M9-PLAN.md alone, on the 2aa189c precedent) has
already landed.  Every citation below is read from the working tree at
HEAD 5538927, the commit that closes M8 Stage D, which
tot-m9-ratifications.md and the M9 design verdict both use as the
reference state.  `git -C /Users/oobi/Documents/tot diff` prints
nothing, so the working tree equals HEAD and every line number below
is a HEAD line number.  No file under /Users/oobi/Documents/tot is
written by this slice; every edit named below is a plan for the later
build workflow to apply, and every probe is a command that workflow
runs, never a command run here.  Entry is 441 slice (445 wrapper), the
design verdict's own stated entry for this stage
(tot-m9-design-verdict.md:189), carried as ESTIMATE per the wrapper's
own +4 offset (C-A14) and the DELTA model (A3-F7): `rg -o 'echo
PASS-[A-Z0-9-]+' dev/gates.sh | wc -l` prints 177, the surface suite
reads 158 cases and
the kernel suite reads 105, and 177 plus 158 plus 105 is 440, one short
of the measured 441, so the model adds new markers and new suite cases
to the measured entry rather than re-deriving the absolute term.

## STAGE A: the SPEC repair and the C5 two-horn record

### Goal

Pay the debt dev/M8-PLAN.md:2445-2449 states and M8's own four stages
never landed.  At HEAD, `rg -n 'entering M9' SPEC.md` prints nothing,
SPEC.md:2022 still carries a forward-looking "M8 candidate list"
bullet, and SPEC.md:2044-2045 still reads "No `.mli` interfaces yet
except `Level` and `Budget`" against SPEC.md:1931-1933, which records
the M8 Stage D sweep at 18 `.ml` and 18 `.mli` files.  Stage A closes
this gap in one edit to SPEC.md: it stamps M8 as done, records the two
debts M9 hands to M10 (C1, the accessibility-shape selector, and C2,
the polarity rule for nested inductives, each with one measured
reason), repairs the stale `.mli` sentence, repoints debt entry 6's
citation from `strict_pos` (lib/check.ml:1964-1976) to `is_applied`
(lib/check.ml:1913), and adds the C5 two-horn record naming the two
refused probes that keep the `Frozen` emptiness claim open.  Stage A
touches no kernel file, no surface file and no example; the whole
content diff lives in SPEC.md, plus one new gate leg in dev/gates.sh
that pins it.  Per R-Q6, C5 gets no code half: lib/interp.ml:92-95 and
surface/run.ml:117-120 stay untouched, and PASS-M7E-SPEC-CITATIONS
(dev/gates.sh:3930-3931) already counts both sites, so no new marker is
owed for C5.

### Rulings covered

- C3 (ratified in the M9 design verdict, tot-m9-design-verdict.md:112-121
  and :189-194), the M8 exit stamp and the SPEC repair, IN and landing
  FIRST after the plan commit P0.  Honoured: this stage's whole payload
  is C3's execution, the dated "Known debts entering M9" paragraph
  named in Files touched and confirmed in Review checklist item 2;
  R-Q7's entry-11 clause is a separate SPEC obligation that Stage B
  owns, not C3, so it is named below rather than folded into this
  bullet (R-F1).
- R-Q6 (ratified), verbatim: "C5 is the SPEC two-horn record only, no
  code half and no new marker.  lib/interp.ml:92-95 and
  surface/run.ml:117-120 are untouched;  PASS-M7E-SPEC-CITATIONS
  (dev/gates.sh:3930-3931) already counts both sites."  Honoured
  exactly: the C5 edit is prose inside the new "Known debts entering
  M9" paragraph, no lib/ or surface/ file is touched, and no new marker
  is added for it.
- R-Q3 (ratified), verbatim: "in M10, C2's polarity rule lands FIRST
  and soaks (M8 R-Q2 wording), then C1.  The M10 brief answers the
  double-flip sign lattice of finding A2-F1 before any rule is costed.
  M9 records this order in dev/M9-PLAN.md and edits no kernel rule."
  This slice records the order in the new SPEC paragraph's C2 reason
  (below) and in this plan file; it edits no rule in lib/.
- A3-F6 (carried finding, ACCEPTED), verbatim summary
  (tot-m9-design-verdict.md:394-399): "Stage A's first leg is the
  authorship test R10 names ... one leg with a tree-side conjunct and a
  mutation aimed at SPEC.md:1932, text no M9 stage writes."  Honoured:
  PASS-M9A-EXIT-STAMP is the ONE leg below, with a tree-side conjunct
  (the fd-derived module counts) and a mutation on SPEC.md:1932, a
  sentence M8 Stage D wrote.
- A3-F5 (carried finding, ACCEPTED, tempered), verbatim summary
  (tot-m9-design-verdict.md:388-393): the proposal's second leg pinned
  `awk 'NR==1913' lib/check.ml` as an absolute line, which "would make
  three such pins in one file pair"; this verdict "drops the third pin
  rather than pay it."  Honoured: the debt-entry-6 repoint below is
  located by content (`rg -n` on the citation text), not by a new
  `awk 'NR=='` pin, so M9 adds no third absolute pin to the two already
  at dev/gates.sh:3927-3928.
- R10 (carried), "one edit per mutation proof."  PASS-M9A-EXIT-STAMP
  names exactly one edit (SPEC.md:1932, 18 to 19).
- R11 (carried), verbatim: "the PASS-M9 namespace is unused at HEAD,
  `rg -o 'PASS-M9[A-Z0-9-]*' dev/gates.sh` prints nothing."  Measured
  below (Entry state); PASS-M9A-EXIT-STAMP is free against it.
- C-A14 (carried), "the wrapper `PASS=` count reads four higher than
  the gate slice."  Every count in this slice is given as slice figure
  and wrapper figure (slice + 4).
- M8 R-Q2 and M8 R-Q6 (carried).  Both govern kernel files and the
  cache format version; Stage A touches neither, so both stay satisfied
  by construction and neither is re-tested by this stage's own leg.

R-Q7 is not covered by this slice.  Stage B owns the R-Q7 entry-11
clause: it keeps SPEC debt entry 11 (the cumulativity debt, C7) with an
annotation naming the M9 instrument's measured reading, and that
reading is Stage B's own demand-instrument count, not anything Stage A
produces.  Stage A's new paragraph names only C1 and C2, per the
verdict's own Stage A payload (tot-m9-design-verdict.md:189-194); the
entry-11 clause lands in Stage B's own Files touched, Rulings covered
and Review checklist (R-F1).

### Entry state

Measured at the reference state, HEAD 5538927, working tree equal to
HEAD (`git -C /Users/oobi/Documents/tot diff` prints nothing):

- `rg -o 'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh`
  prints nothing (R11 satisfied, namespace free).
- `rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh
  | wc -l` prints 177.
- `rg -n 'entering M9' /Users/oobi/Documents/tot/SPEC.md` prints
  nothing.
- `rg -c '^- M8 \(done\)' /Users/oobi/Documents/tot/SPEC.md` prints
  nothing (exit 1): the bullet does not exist yet.
- `rg -c 'kernel-internal\.$' /Users/oobi/Documents/tot/SPEC.md`
  prints 1: the stale bullet is still there, its last line ending in
  the original "kernel-internal." wording at SPEC.md:2045.
- `fd -e ml --max-depth 1 . /Users/oobi/Documents/tot/lib | wc -l`
  prints 18; `fd -e mli --max-depth 1 . /Users/oobi/Documents/tot/lib
  | wc -l` prints 18.
- `awk 'NR==1932' /Users/oobi/Documents/tot/SPEC.md` prints "`lib/`
  holds 18 `.ml` files and 18 `.mli` files, and a module with no".
- `awk 'NR==1913' /Users/oobi/Documents/tot/lib/check.ml` prints "let
  is_applied (depth : int) (t : Term.t) : bool =".
- `awk 'NR==1969' /Users/oobi/Documents/tot/lib/check.ml` prints
  "        | Term.Pi (_q, _x, dom, cod) -> no_occur dom && strict_pos
  (depth + 1) cod".
- `rg -n 'lib/check\.ml:1964-1976' /Users/oobi/Documents/tot/SPEC.md`
  matches two lines at HEAD, /Users/oobi/Documents/tot/SPEC.md:1712 in
  section 2's dated log and :2646 inside debt entry 6 of the "Known
  debts entering M7" numbered list.  Stage A repoints ONLY the entry-6
  hit, located by the phrase "applied-ness test at
  lib/check.ml:1964-1976", and leaves SPEC.md:1712 untouched.
- Entry 441 slice (445 wrapper) is carried as ESTIMATE per the Scope
  note's DELTA-model caveat; it is not independently re-derivable from
  the 177 gate-echo count without running the suite.

### Files touched

- `SPEC.md`.  Four edits, all prose, none touching a line before 1932:
  the section 5 milestone bullet (SPEC.md:2022-2040, replaced), the
  section 6 stale `.mli` bullet (SPEC.md:2044-2045, annotated closed),
  debt entry 6's citation inside the "Known debts entering M7" list
  (the phrase "applied-ness test at lib/check.ml:1964-1976", which is
  the entry-6 hit alone and not the section 2 log hit at SPEC.md:1712,
  repointed by content, named in Stage A's own commit message rather
  than P0's, since it sits in Stage A's SPEC.md edit list and not in
  P0's single-file payload (R-F9)), and one new paragraph appended at
  the file's end (after SPEC.md:2715 at HEAD), "Known debts entering
  M9", which carries the C1 and C2 debt entries and the C5 two-horn
  record together.  This whole edit set is C3's payload, the M8 exit
  stamp and the SPEC repair (verdict
  tot-m9-design-verdict.md:112-121), landing FIRST after the plan
  commit P0 (R-F1).
- `dev/gates.sh`.  One new leg, PASS-M9A-EXIT-STAMP, inserted
  immediately after PASS-M8D-NO-BEHAVIOUR-CHANGE's closing brace
  (dev/gates.sh:4524), before the fixed-last M4FIX-INST-BRANCHING /
  PASS-M5B-BRANCHING-20 block (comment at dev/gates.sh:4526, the "LAST
  leg in the file" discipline restated at dev/gates.sh:4553-4556), so
  the two timing-sensitive legs stay the file's last two.
- `dev/M9-BUILD-LOG.md` (NEW or appended: the file does not exist at
  HEAD, so a first attempt creates it, and a re-attempt after a
  rollback that left a sibling stage's entries appends to it; holds
  Stage A's own stage report, written unconditionally, with the MA-1
  mutation proof's flip and its md5-identical restore, plus any
  conflict this stage meets booked as C-A<n> under section 3.1).

No `lib/`, `surface/`, `test/` or `examples/` file is touched by this
stage.

### Design

Four prose edits, all in SPEC.md, the fourth an appended paragraph.  No OCaml
file changes; every claim below is text, so the house rules on
exceptions, bool matches and wildcard arms do not apply to this stage.

**1.  Section 5, the milestone bullet (SPEC.md:2022-2040 replaced).**
BEFORE, verbatim at HEAD:

```
- M8 candidate list (M7 Stage E rewrote the former `M6 candidate list`
  bullet;  measure and decide the next tradeoff):
  - Well-founded recursion.  Leading candidate.  `Acc` checks today and
    the whole kernel delta sits in `Totality.guard`.  M7 ships two
    oracle fixtures and no rule, and any rule must carry the provenance
    side condition that section 6 states, so a descent from a NON-seed
    formal stays rejected.
  - Holes.  Sized by the Stage D hole-anchor count, not by taste: 99
    anchors over the prelude-plus-examples corpus, of which 60 are
    solvable from the expected type alone, 9 are argument-driven and 30
    are neither.  Section 6's holes debt bullet carries the machine
    record.  Section 2's dated Stage D entry states the same walk in
    prose and keeps the literal out of itself (pin 12).
  - Nested and mutual inductives (would unblock the `Json` cons-cell
    migration to `jarr : List Json -> Json`).  Blocked on the MUTUAL
    gap in `Totality.mentions`, which tests only the family's own
    name, over an emptiness claim SPEC still records as UNPROVEN.
  - Universe polymorphism (`Eq` is currently `Type 0`-monomorphic).
    Not needed by `Acc` (M5 Stage E probe P1).
```

AFTER:

```
- M8 (done): four stages.  Stage A gives the argument-driven hole
  capture a local-aware instantiation for a LOCAL head, generalizing
  `inst_domain` with an `~escape` parameter and leaving the kernel
  untouched.  Stage B spends that rule on `stdlib/prelude.tot:94`'s
  `cong0` motive, re-spelling `Eq B` to `Eq _` and re-measuring the
  three literals that move with it.  Stage C closes three M7 hand-off
  reporting debts: a pinned decision, a new gate leg, a driver fix,
  with no new rule.  Stage D sweeps every module in `lib/` to carry an
  interface, adds a private `Global_store` module behind `lib/dune`'s
  `private_modules` field, and narrows the public `Global` interface to
  hide general insertion.
```

The holes debt and the universe-polymorphism debt are not lost: the
holes machine record stays in section 6's numbered list (entry 10,
"Multi-hole reporting"), and the cumulativity debt stays in section
6's older bulleted list (SPEC.md:2046, R-Q7's entry 11).  Nested
inductives and well-founded recursion move into the new "Known debts
entering M9" paragraph below, under their M9 panel names, C2 and C1.

**2.  Section 6, the stale `.mli` bullet (SPEC.md:2044-2045 annotated).**
BEFORE, verbatim at HEAD:

```
- No `.mli` interfaces yet except `Level` and `Budget`;  `Global.add`
  is public but documented as kernel-internal.
```

AFTER, following the Apache-licence bullet's own CLOSED shape
(SPEC.md:2048-2051, "PAID 2026-09-04 (M7 Stage E, verdict scope-in
5): ... `PASS-M7E-DEBT-H` pins the pair."):

```
- No `.mli` interfaces yet except `Level` and `Budget`;  `Global.add`
  is public but documented as kernel-internal.  CLOSED 2026-09-05
  (M8 Stage D): every module in `lib/` now carries an interface
  (SPEC.md:1931-1933, 18 `.ml` files and 18 `.mli` files), pinned by
  `PASS-M8D-MLI-COVERAGE` and `PASS-M8D-KERNEL-INTERNAL`
  (dev/gates.sh:4370, dev/gates.sh:4406).  The public `Global`
  interface exports no general insertion: `val add` does not appear in
  `lib/global.mli`, and a client reaches the environment only through
  `Check` or the narrow `add_rec_self`.
```

The original sentence is kept, not deleted, matching the Apache
precedent: a reader sees both what M8 recorded as a debt and what
closed it.

**3.  Debt entry 6, the citation repoint.**  Inside the numbered "Known
debts entering M7" list, entry 6 reads, verbatim at HEAD
(SPEC.md:2645-2650):

```
6. Nested inductives and the strict positivity fence.  CARRIED.  The
   applied-ness test at lib/check.ml:1964-1976 is one level deep and
   the message names no layer, so a two-layer launder and a one-layer
   control are refused with the same wording.  M7 ships the oracle
   `test/fixtures/m7e-launder.tot` against the shipped control
   `test/fixtures/nested-neg.tot` and owes no rule.
```

At HEAD, lib/check.ml:1964-1976 is `strict_pos`
(`let rec strict_pos (depth : int) (t : Term.t) : bool = ...`), not the
applied-ness test the entry describes; `is_applied`, the function that
actually tests whether a term is the family applied to exactly its own
parameters, is lib/check.ml:1913.  The one-word edit changes
"lib/check.ml:1964-1976" to "lib/check.ml:1913" in that sentence, and
nothing else in entry 6 moves.  Because the two edits above (1 and 2)
land earlier in the file and change its line count, entry 6's absolute
line number shifts; the build workflow locates the sentence by content,
per A3-F5, not by a new `awk 'NR=='` pin.  The bare citation string has
TWO hits in SPEC.md at HEAD, SPEC.md:1712 in section 2's dated log and
SPEC.md:2646 in this entry, so the locator is the longer phrase
"applied-ness test at lib/check.ml:1964-1976", which matches entry 6
alone; SPEC.md:1712 is not Stage A's to touch.

**4.  The new "Known debts entering M9" paragraph, appended at the
file's end (after SPEC.md:2715 at HEAD, the end of Obligation 2).**
This is the dated hand-off dev/M8-PLAN.md:2445-2449 asked for, in the
shape of "Known debts entering M7" (SPEC.md:2594-2603 at HEAD; the
M8-PLAN's own predicted address for that paragraph, SPEC.md:2554, is
itself stale by 40 lines, the same drift PASS-M7E-SPEC-CITATIONS was
built to catch rather than trust).  Full text:

```
Known debts entering M9 (M9 Stage A, 2026-09-06, written at the M9
Stage A exit commit).  Two debts M9 carries forward to M10, each with
the one reason the M9 design panel measured, and the `Frozen`
emptiness claim stays open with the reason unchanged since M7.

1. Well-founded recursion, the accessibility-shape selector (design
   panel name C1).  DEFERRED.  The selector needs data
   `Totality.guard` does not receive: `lib/totality.mli:43` hands it a
   bare `Term.t` with no domain slot on `Lam` (`lib/term.ml:15`), so
   reading a formal's stamped type needs both `guard` and `passes`
   (`lib/totality.ml:80-81`) widened, an `.mli` break M9 does not
   price.  A second reason stands unchallenged: C1's soundness
   argument is a loan against the one-level fence now at
   `lib/check.ml:1913` (`is_applied`), and C2 is the candidate that
   moves that fence, so C1 after C2 is cheaper than C1 before it.
2. Nested inductives and the polarity rule (design panel name C2).
   DEFERRED.  The rule as sketched is unsound in one arm:
   `lib/check.ml:1969` is `Term.Pi (_q, _x, dom, cod) -> no_occur dom
   && strict_pos (depth + 1) cod`, a domain with NO occurrence at all,
   and a signed rule that admits a flipped occurrence there accepts a
   doubly flipped shape the tree refuses today.  C2 lands FIRST in M10
   and soaks, before C1 is costed.

`Frozen` emptiness (obligation 1, `lib/interp.ml:85-91`): stays open
with both horns stated and neither asserted.  Two probes tried the two
spellings that could reach the `Quantity.Zero` arm of
`Run.compute_guard` (`surface/run.ml:117-120`) from a source program,
an erased `Nat` principal eliminated into `Unit` and the same formal
eliminated into a type, and both are refused earlier, by the erasure
rule and not by the guard ("erased variable n used at runtime", exit
1).  That is not a proof of horn one: absence over two spellings is
not absence over all spellings, and tot has no channel that could tell
a reader which guard a definition received.  `lib/interp.ml:92-95` and
`surface/run.ml:117-120` are untouched by this or any M9 stage, and
`PASS-M7E-SPEC-CITATIONS` (dev/gates.sh:3930-3931) keeps counting both
sites, so no later M9 stage can tidy the emptiness story into code
without turning that leg red.
```

### Gate additions

One block, following the leg shape dev/gates.sh:2507-2529 and the
PASS-M7E-SPEC-CITATIONS content-pin style (dev/gates.sh:3901-3939):
one `echo PASS-<NAME>` on the pass route, a matching `FAIL-<NAME>` arm
that prints the measured values, and `exit 1` on the fail route.  The
block is inserted at dev/gates.sh:4525, immediately after
PASS-M8D-NO-BEHAVIOUR-CHANGE's closing brace and before the "ctxcat id
5" comment that opens the fixed-last M4FIX / M5B block
(dev/gates.sh:4526).

Marker: PASS-M9A-EXIT-STAMP
Ruling: A3-F6 (one leg, not two), R-Q6 (C5, no new marker, folded into
this leg's tree-side conjunct set as prose only, not as a fifth
conjunct), R10 (one edit, one mutation proof).
Command:
```
m9a_sec6=$(rg -c '^Known debts entering M9' "$ROOT"/SPEC.md 2>/dev/null); m9a_sec6=${m9a_sec6:-0}
m9a_sec5=$(rg -c '^- M8 \(done\)' "$ROOT"/SPEC.md 2>/dev/null); m9a_sec5=${m9a_sec5:-0}
m9a_stale=$(rg -c 'kernel-internal\.$' "$ROOT"/SPEC.md 2>/dev/null); m9a_stale=${m9a_stale:-0}
m9a_fd_ml=$(fd -e ml --max-depth 1 . "$ROOT"/lib | wc -l | tr -d ' ')
m9a_fd_mli=$(fd -e mli --max-depth 1 . "$ROOT"/lib | wc -l | tr -d ' ')
m9a_spec_sent=$(rg -o '[0-9]+ `\.ml` files and [0-9]+ `\.mli` files' "$ROOT"/SPEC.md)
m9a_spec_ml=$(printf '%s\n' "$m9a_spec_sent" | rg -o '^[0-9]+' | sort -u | tr -d ' \n')
m9a_spec_mli=$(printf '%s\n' "$m9a_spec_sent" | rg -o 'and [0-9]+' | rg -o '[0-9]+' | sort -u | tr -d ' \n')
{ [ "$m9a_sec6" -eq 1 ] && [ "$m9a_sec5" -eq 1 ] && [ "$m9a_stale" -eq 0 ] \
  && [ "$m9a_fd_ml" = 18 ] && [ "$m9a_fd_mli" = 18 ] \
  && [ "$m9a_spec_ml" = "$m9a_fd_ml" ] && [ "$m9a_spec_mli" = "$m9a_fd_mli" ]; } \
  && echo PASS-M9A-EXIT-STAMP \
  || { echo "FAIL-M9A-EXIT-STAMP (sec6=$m9a_sec6 sec5=$m9a_sec5 stale=$m9a_stale fd_ml=$m9a_fd_ml fd_mli=$m9a_fd_mli spec_ml=$m9a_spec_ml spec_mli=$m9a_spec_mli)"; exit 1; }
```
Before the stage: exit 1, output contains "FAIL-M9A-EXIT-STAMP
(sec6=0 sec5=0 stale=1 fd_ml=18 fd_mli=18 spec_ml=18 spec_mli=18)"
(PREDICTED: measured directly above in Entry state, `sec6` and `sec5`
are both 0 because neither string exists yet, `stale` is 1 because the
conjunct counts lines that END in `kernel-internal.`, the original
wording of the stale claim, and SPEC.md:2045 still carries it, and the
fd/spec counts already agree at 18 since SPEC.md:1932 and the tree
both predate this stage).
After the stage: exit 0, output contains "PASS-M9A-EXIT-STAMP"
(PREDICTED: `sec6` and `sec5` become 1, `stale` becomes 0 because edit
2 KEEPS that sentence and re-wraps its last line with the dated CLOSED
correction, so no line ends in `kernel-internal.` any more, and the
fd/spec counts still agree at 18 since this stage adds no lib/ file).
MUTATION: SPEC.md:1932, one edit to the count sentence, the
sentence that states the `.ml` and `.mli` file counts, substituting
"holds 18" with "holds 19" on that one line and nowhere else.  The
narrow pattern is the one MA-1 uses: after edit 2 lands, the leg's own
`m9a_spec_sent` regex matches TWO lines, SPEC.md:1932 and the new
citation line inside the CLOSED annotation, so a substitution on that
regex would move two lines and break R10's one-edit rule, while "holds
18" matches the count sentence alone (MEASURED on the post-edit copy:
a two-line diff, one line moved).  The sentence sits at SPEC.md:1932
today and the leg still locates it by content, not by that line
number, per A3-F5.  `m9a_spec_ml` becomes 1819 while `m9a_fd_ml` stays
18, the sixth conjunct fails, and the leg reddens with
`FAIL-M9A-EXIT-STAMP` naming `spec_ml=1819 fd_ml=18`.  Restore the byte
to 18 before the next leg runs, md5-identical to pre-mutation SPEC.md.
Non-vacuous because: before the stage, `sec6` and `sec5` are both 0 (
the strings do not exist), so the first two conjuncts alone keep the
leg red until the SPEC edits land; the tree-side conjunct is a
SEPARATE observable that a content-only authorship test cannot
satisfy by accident, since it reads lib/ with `fd`, not SPEC.md, and
compares the two counts against the number SPEC.md itself claims.

### Suite cases

None.  Stage A writes no code: test/surface.ml exercises the
elaborator and test/main.ml exercises the kernel, and this stage edits
neither.  A suite case here would test SPEC.md's own string content,
which PASS-M9A-EXIT-STAMP already does with a tree-side conjunct that
a pure string test cannot supply; adding one would duplicate the leg
without a distinct observable, the same authorship trap A3-F6 flags
against a second content-only leg.

### Review checklist

1. Confirm the diff touches only SPEC.md, dev/gates.sh and
   dev/M9-BUILD-LOG.md; no `lib/`, `surface/`, `test/` or `examples/`
   path appears in `git -C /Users/oobi/Documents/tot diff --stat` once
   the build workflow stages the edit.
2. Confirm the "M8 (done)" bullet replaces the WHOLE "M8 candidate
   list" bullet, including its four sub-bullets (SPEC.md:2022-2040 at
   HEAD), not merely its first line, and confirm the holes and
   cumulativity debts still appear elsewhere in section 6 (entry 10 and
   entry 11 of the numbered list, and the older bulleted list's
   cumulativity line respectively).  Confirm this whole edit set is
   C3's payload, per the verdict's own Stage A assignment, and that
   R-Q7's entry-11 clause is Stage B's own obligation, not Stage A's
   (R-F1).
3. Confirm the section 6 repair KEEPS the original stale sentence and
   annotates it CLOSED with a date, a stage and a marker citation, the
   same shape the Apache-licence bullet uses (SPEC.md:2048-2051),
   rather than deleting the sentence outright, and confirm the CLOSED
   annotation opens on the same line as "kernel-internal.", so
   `rg -c 'kernel-internal\.$' SPEC.md` reads 1 before the edit and 0
   after it, which is what the leg's `m9a_stale` conjunct counts
   (SA-Q6).
4. Confirm the debt-entry-6 repoint is located by CONTENT, by the
   phrase "applied-ness test at lib/check.ml:1964-1976", not by a new
   absolute `awk 'NR=='` pin (A3-F5).  `rg -n
   'lib/check\.ml:1964-1976' SPEC.md` prints TWO lines at ENTRY state,
   SPEC.md:1712 and SPEC.md:2646; after edits 1 and 2 the second hit has
   moved and only its CONTENT is trusted, and exactly ONE line after it,
   SPEC.md:1712, section 2's dated log, which this stage leaves alone;
   `rg -n 'lib/check\.ml:1913' SPEC.md` then matches inside entry 6.
5. Confirm the new "Known debts entering M9" paragraph names C1 and C2
   each with exactly one reason (C1's second reason folds into the
   first sentence rather than adding a third bullet), and states horn
   one of the `Frozen` claim as still UNPROVED, never as proved.
6. Re-run PASS-M9A-EXIT-STAMP's MUTATION (SPEC.md:1932, 18 to 19),
   confirm the leg reddens on the `spec_ml`/`fd_ml` conjunct, then
   restore the byte md5-identical to pre-mutation SPEC.md before the
   next leg runs.
7. Confirm `rg -c 'PASS-M9A-' /Users/oobi/Documents/tot/dev/gates.sh`
   reads 0 before this stage's edit lands and exactly 1 after, so no
   duplicate marker enters the namespace R11 measured free.
8. No OCaml file is touched by this stage, so the house rules on
   exceptions, bool matches, wildcard arms and total indexing do not
   apply to it; confirm the diff has zero hunks outside SPEC.md,
   dev/gates.sh and dev/M9-BUILD-LOG.md, closing the one way this stage
   could silently grow.
9. Confirm the commit message for this stage's edit names the
   debt-entry-6 repoint (lib/check.ml:1964-1976 to lib/check.ml:1913)
   as Stage A's own citation fix, not P0's (R-F9).

### Rollback

1. Revert SPEC.md to its pre-Stage-A state: restore the original "M8
   candidate list" bullet at SPEC.md:2022-2040, restore the original
   stale sentence at SPEC.md:2044-2045 with no CLOSED annotation,
   restore the "lib/check.ml:1964-1976" citation inside debt entry 6,
   and delete the appended "Known debts entering M9" paragraph at the
   file's end.
2. Remove the PASS-M9A-EXIT-STAMP leg from dev/gates.sh, the whole
   block between the comment introducing it and its own closing brace,
   at dev/gates.sh:4525 (post-insertion numbering).
3. Revert dev/M9-BUILD-LOG.md's Stage A entry, or delete the file if
   this stage created it and no later stage has appended to it.
4. Re-run `rg -o 'PASS-M9[A-Z0-9-]*' dev/gates.sh` and confirm it
   prints nothing again.
5. Re-run `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh | wc -l` and
   confirm it reads 177 again, and `rg -n 'entering M9' SPEC.md` again
   prints nothing and `rg -n 'Stage A' dev/M9-BUILD-LOG.md 2>/dev/null`
   prints nothing, whether the file was deleted or only its Stage A
   entry reverted, confirming the tree is clean for a later attempt.

Gate markers added: 1 (ESTIMATE)
Suite cases added: 0 (ESTIMATE)
Exit PASS count: 442 slice (ESTIMATE), 446 wrapper (ESTIMATE)


# M9 plan slice: STAGE B

All line citations below were checked against tot HEAD commit
5538927 ("M8 Stage D: lib/ takes its interfaces, the kernel
environment moves behind a private store, gate battery 437 to 441").
`git -C /Users/oobi/Documents/tot diff --stat` returned nothing, so
every citation is from HEAD, not from an uncommitted diff. The tree
at `/Users/oobi/Documents/tot` was never written to while drafting
this slice.

## STAGE B: the demand instrument, the cd-prefix-guard.py port under examples/

### Goal

Port `/Users/oobi/.claude/hooks/cd-prefix-guard.py` (382 lines) into
ONE new tracked file, `examples/guard-cd.tot`, narrowly (R-Q1): the
port takes on only the "chained cd" shape the source hook's
`classify` names (cd-prefix-guard.py:265-281), because that shape is
the one whose word-boundary walk is the whole demand this stage
measures. The port is a real PreToolUse guard (JSON in on stdin, a
`Verdict` JSON envelope out), matching the examples/guard.tot and
examples/guard-rewrap.tot shape already in the corpus, not a
standalone script.

While drafting the port, the kernel FORCES two rewrites away from
the literal Python transcription (R-Q2): a fuel-free word-boundary
walk fails the structural termination guard, and a self-nesting
"Rule" family for the classify table fails the strict-positivity
fence. Both refused spellings are pinned forever as tracked negative
oracles under `dev/m9b/`, so the demand reading survives after the
shipped port itself no longer contains either shape (A3-F3: the
instrument counts kernel-FORCED rewrites, never shipped refusals,
which are 0 by construction on the file that ships). A third small
file, `dev/m9b/regex-fidelity.tot`, gives the second reading this
stage records: the Str-backed `regexTest` prim agrees with Python's
`re` on the two anchored patterns `_ASSIGN_WORD`
(cd-prefix-guard.py:91) and `_NOT_A_PROGRAM` (cd-prefix-guard.py:100)
on one recorded pair of subjects, even though `Str` does not
understand PCRE's `(?:...)` non-capturing group the way Python's `re`
does (lib/interp.ml:541-542, `regex_compile`).

Stage B commits its new file under `examples/` (R-Q4): the corpus
walks from 105 files to 106 (`ls
examples/*.tot test/fixtures/*.tot | wc -l` reads 105 at HEAD,
measured directly, not estimated), so `dev/m5e-default-transcript.txt`
reseals through `dev/gen-m5e-transcript.sh`, and the settle-budget
leg's own recipe rewrites whichever of its three literals moved.
Neither chore adds a marker.

### Rulings covered

- R-Q1 (Stage B ports cd-prefix-guard.py, not map-over-rewrap-guard.py; one new file under examples/; the smaller port still yields a non-zero reading and does not make M9 depend on the machinery it measures demand for).
- R-Q2 (the demand instrument is the count of kernel-FORCED rewrites, 2 at HEAD, recorded in dev/M9-BUILD-LOG.md, pinned by PASS-M9B-DEMAND-ORACLE; a reading of 0 would leave the candidate unranked for M10, never retired).
- R-Q4 (Stage B commits its example under examples/, reseals the transcript, re-runs the settle-budget recipe; neither chore adds a marker).
- A3-F3 (the instrument counts kernel-FORCED rewrites, never shipped refusals, which are 0 by construction).
- A3-F1, A3-F2 (attack-3: the two kernel-file mutation proofs proposal 3 first offered for PASS-M9B-DEMAND-ORACLE, lib/totality.ml:109 and lib/check.ml:1969, are DROPPED; both are already pinned earlier, at dev/gates.sh:2545-2551 and :2578-2596, so mutating either one reddens an EARLIER leg first, not this one, which is a LEG-1 vacuity under R10).
- R10 (one edit per mutation proof; no two legs share a mutation proof).
- R11 (the PASS-M9 namespace is unused at HEAD: `rg -o 'PASS-M9[A-Z0-9-]*' dev/gates.sh` prints nothing and exits 1, checked directly above, not assumed).
- M8 R-Q2 (both fence legs, including PASS-M6A-FENCE-COVARIANT at dev/gates.sh:2587, the two fence legs spanning dev/gates.sh:2578-2596, stay green through this stage; this stage lands no nested-inductive rule change).
- A3-F7 (delta model: exit equals entry plus new markers plus new suite cases; this stage's own suite cases both land in the surface suite).
- R-Q7 (Stage B's SPEC.md edit gives debt entry 11, SPEC.md:2668, the annotation that the PASS-M9B-DEMAND-ORACLE reading of 2 is a measured reading, not a repeal; Cumulativity stays CARRIED).

### Entry state

Gate slice 442, wrapper 446 (C-A14: wrapper reads four higher than
the slice). `rg -o 'PASS-M9[A-Z0-9-]*' dev/gates.sh` prints nothing,
confirming R11 at entry. The corpus (`examples/*.tot
test/fixtures/*.tot`) holds 105 files, six of them under examples/:
church.tot, guard-classes.tot, guard-rewrap.tot, guard.tot,
literals.tot, nat.tot. `dev/m9b/` does not exist yet. No file named
`PASS-M9B-*` exists in dev/gates.sh, dev/M9-BUILD-LOG.md, or
test/surface.ml.

### Files touched

- `examples/guard-cd.tot` (NEW, tracked corpus file, ships the port).
- `dev/m9b/wordend-index.tot` (NEW, tracked negative oracle; byte-identical to the panel's own vetted probe fixture, the fuel-free word-boundary walk).
- `dev/m9b/rule-table-nested.tot` (NEW, tracked negative oracle; byte-identical to the panel's own vetted probe fixture, the self-nesting Rule family).
- `dev/m9b/regex-fidelity.tot` (NEW, tracked diagnostic that carries the port's own `assignHead` two-pattern check, since the shipped guard does not classify assignments).
- `dev/m5e-default-transcript.txt` (RESEALED via dev/gen-m5e-transcript.sh; R-Q4 chore, no marker).
- `dev/gates.sh` (three new `echo PASS-M9B-*` legs, anchored after the last PASS-M9 leg's closing brace (PASS-M9A-EXIT-STAMP's, dev/gates.sh:4548 after Stage A) and before the "ctxcat id 5" comment (dev/gates.sh:4550 after Stage A), both re-measured at entry; the settle-budget leg's three literals at dev/gates.sh:3614-3621 rewritten to whichever values the reseal produces; the PASS-M5D-TIERS literal at dev/gates.sh:2353 rewritten from 241 to whatever `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` prints after this stage's six watchdog-wrapped CLI calls land, both readings recorded in dev/M9-BUILD-LOG.md, the recipe as the authority per precedent C-D4 (R-F3); no other existing leg's body edited).
- `dev/M9-BUILD-LOG.md` (NEW or appended; records the forced-rewrite count as the literal `2`, plus the two refused messages verbatim, per R-Q2).
- `test/surface.ml` (two new cases appended to the `cases` list, test/surface.ml:1239-2487 at entry, both IN PROCESS, following the M8 Stage C precedent comment at test/surface.ml:2460-2461 that no suite case duplicates a gate leg's CLI-driven record).
- `SPEC.md` (debt entry 11, SPEC.md:2668, gains one clause naming Stage B's PASS-M9B-DEMAND-ORACLE reading of 2 forced rewrites: the M9 instrument adds a measured reading, not a repeal; the entry keeps its heading and its "CARRIED" disposition, per R-Q7 and R-F1).

### Design

**The two tracked negative oracles.** Both files are copied
byte-for-byte from the panel's own vetted probes
(`/Users/oobi/Documents/tot-m9-probes/proposal-3/p1-word-end-index.tot`
and `p4-rule-table-nested.tot`), so the refusal messages and their
line:column positions are already known, not re-derived:

`dev/m9b/wordend-index.tot` (17 lines):
```
-- cd-prefix-guard.py:144-177, _word_end: advance an INDEX past one shell
-- word.  The Python walk has no cap: it stops only at n = len(command).
-- This is the smallest fragment of the hook that has no fuel formal.
def charAt : String -> Int -> String :=
  fun s i => orEmpty (stringSlice s i 1)

def rec wordEnd : String -> Int -> Int :=
  fun s i =>
    match intCompare i (stringLength s) with
    | lt =>
        match stringEq (charAt s i) " " with
        | true => i
        | false => wordEnd s (intAdd i 1)
        end
    | eq => i
    | gt => i
    end
```
`tot check dev/m9b/wordend-index.tot` refuses at line 7, column 1,
the `def rec wordEnd` site, with the whole line "wordEnd failed the
structural termination guard" (R-Q2's first recorded message): the
recursive call `wordEnd s (intAdd i 1)` walks `i` upward with no
formal that decreases structurally, since `s` (the actual shrinking
witness, in spirit) is untouched and `i` is an `Int`, not a
structurally recursive argument.

`dev/m9b/rule-table-nested.tot` (2 lines):
```
-- The classify table as a family that mentions itself under List.
data Rule : Type 0 := | mkRule : List Rule -> Rule
```
`tot check dev/m9b/rule-table-nested.tot` refuses at line 2, column
1, with the whole line "invalid constructor mkRule: negative or
non-uniform occurrence of Rule" (R-Q2's second recorded message):
`Rule` appears under the APPLIED foreign parameterized type `List`,
which lib/check.ml's `strict_pos` fence (lib/check.ml:1964-1976)
refuses one level deep, per SPEC.md's own documented scope for that
fence.

**The shipped port, `examples/guard-cd.tot`.** Ninety lines,
following examples/guard.tot's `decide : Json -> Verdict` /
`main : IO Verdict` shape. The word-boundary walk ships with a `Nat`
FUEL formal instead of the refused fuel-free spelling above; the
classify result is a flat `String` tag, never a `Rule` family, so the
second refusal never recurs on the shipped file either:

```
#!/usr/bin/env -S tot run
-- M9 Stage B: a NARROW port of the house cd-prefix-guard
-- (~/.claude/hooks/cd-prefix-guard.py, 382 lines).  The Python hook
-- classifies a Bash command into six shapes and NUDGES on four of
-- them (`reason_for`, cd-prefix-guard.py:284-346); it never denies
-- (cd-prefix-guard.py:43, "NUDGE, never deny").  THIS port takes on
-- ONE shape only, the leading `cd <dir> &&` / `cd <dir>` + `;`/`|`/
-- NEWLINE chain (`_LEAD_CD`, cd-prefix-guard.py:83-87, and the
-- "chained-cd" result of `classify`, cd-prefix-guard.py:265-281),
-- because that is the shape whose word-boundary walk (`_word_end`,
-- cd-prefix-guard.py:144-176) is the whole C1 demand this stage
-- measures.  Every other shape (script-cd, lone-cd, the two
-- assignment shapes) ALLOWS, matching the guard-rewrap.tot
-- precedent's own scoping note (examples/guard-rewrap.tot:11-17).
--
-- The word-boundary walk ships with a Nat FUEL formal (wordEnd
-- below), not the literal index-only transcription of _word_end:
-- the fuel-free spelling is refused by the shipped structural
-- termination guard (dev/m9b/wordend-index.tot, the tracked
-- negative oracle PASS-M9B-DEMAND-ORACLE pins), and the fuel
-- spelling is the one the kernel accepts (A3-F3: the demand
-- instrument counts THIS forced rewrite).  The classify result is a
-- flat String tag, not a Rule family: a self-nesting spelling of the
-- classify table is refused the same way (dev/m9b/
-- rule-table-nested.tot), so the shipped table never nests.

def charAt : String -> Int -> String :=
  fun s i => orEmpty (stringSlice s i 1)

def rec wordEnd : Nat -> String -> Int -> Int :=
  fun fuel s i =>
    match fuel with
    | zero => i
    | succ f =>
        match intCompare i (stringLength s) with
        | lt =>
            match stringEq (charAt s i) " " with
            | true => i
            | false => wordEnd f s (intAdd i 1)
            end
        | eq => i
        | gt => i
        end
    end

def isCdKw : String -> Bool :=
  fun tok => orb (stringEq tok "cd") (stringEq tok "pushd")

def classify : String -> String :=
  fun cmd =>
    match isCdKw (firstToken cmd) with
    | false => "none"
    | true =>
        let e := wordEnd (stringLength cmd) cmd 0 in
        match intCompare e (stringLength cmd) with
        | lt => "chained-cd"
        | eq => "none"
        | gt => "none"
        end
    end

def decide : Json -> Verdict :=
  fun payload =>
    match jsonGetString payload "tool_name" with
    | none => allow
    | some name =>
        match stringEq name "Bash" with
        | true =>
            match jsonGet payload "tool_input" with
            | none => allow
            | some ti =>
                match stringEq (classify (jsonGetStringOr ti "command" "")) "chained-cd" with
                | true =>
                    deny (stringConcat
                            "cd-prefix-guard: use an absolute path instead of a leading cd (command: "
                            (stringConcat (elideAt 2000 (jsonGetStringOr ti "command" "")) ")"))
                | false => allow
                end
            end
        | false => allow
        end
    end

def main : IO Verdict :=
  let* _ _ raw := readStdin in
  let* _ _ parsed := liftIO _ (jsonParse raw) in
  match parsed with
  | none => pureIO _ allow
  | some payload => pureIO _ (decide payload)
  end
```
`def rec wordEnd` sits at line 30, `def decide` at line 62, the
`deny` arm at line 74, `def main` at line 84 (all confirmed by `rg
-n` against the drafted file, not counted by eye). This ninety-line
listing is a PREDICTED sketch; the Stage B builder re-measures every
address with `rg -n` against the file it actually writes before
recording any Gate additions mutation proof (R-F2). Every helper
(`firstToken`, `jsonGetStringOr`, `jsonGet`, `stringConcat`,
`elideAt`, `orEmpty`) is an existing stdlib/prelude.tot function
(prelude.tot:39, 42, 46, 206, 224), the same helpers examples/
guard.tot and examples/guard-rewrap.tot already call, so the port
adds no new prelude surface. Only the "chained-cd" shape denies;
every other classify result, and every non-Bash or non-command tool
call, ALLOWS, matching examples/guard-rewrap.tot's own documented
narrowing (it implements two of its source hook's criteria, not all
of them, and everything else allows).

**The regex-fidelity diagnostic, `dev/m9b/regex-fidelity.tot`.** The
shipped guard above never classifies an assignment, so it carries no
`assignHead` of its own (R-Q1's narrow scope). The one place "the
port's assignHead" lives is this file, which ports the two anchored
patterns verbatim and prints their verdict on one recorded pair of
subjects:

```
-- dev/m9b/regex-fidelity.tot: the demand instrument's one non-zero
-- reading beyond R-Q2's rewrite count (A3-F3).  Ports the two
-- anchored patterns cd-prefix-guard.py:91 (_ASSIGN_WORD) and :100
-- (_NOT_A_PROGRAM) through tot's Str-backed regexTest, on the same
-- recorded pair of subjects proposal-3's own P10 probe used.  The
-- shipped examples/guard-cd.tot does not classify assignments
-- (R-Q1: narrow port), so this file is the only place "the port's
-- assignHead" lives; PASS-M9B-REGEX-FIDELITY reads it, not
-- examples/guard-cd.tot.
def assignHead : String -> String -> Div (Pair Bool Bool) :=
  fun assignSubject notAProgramSubject =>
    bindDiv Bool (Pair Bool Bool)
      (regexTest "^[A-Za-z_][A-Za-z0-9_]*=" assignSubject)
      (fun aw =>
        bindDiv Bool (Pair Bool Bool)
          (regexTest "^(?:#|&?[0-9]*[<>])" notAProgramSubject)
          (fun nap => pureDiv (Pair Bool Bool) (pair Bool Bool aw nap)))

def showBool : Bool -> String :=
  fun b => match b with | true => "TRUE" | false => "FALSE" end

def main : IO Verdict :=
  let* _ _ r := liftIO _ (assignHead "FOO=1" "2>/dev/null") in
  match r with
  | pair aw nap =>
      let* _ _ u := printLine (stringConcat
          (stringConcat "ASSIGN_WORD=" (showBool aw))
          (stringConcat " NOT_A_PROGRAM=" (showBool nap))) in
      pureIO _ allow
  end
```
`def assignHead` sits at line 10, its first `regexTest` call at line
13, its second at line 16, `def main` at line 22 (confirmed by `rg
-n` against the drafted file). `regexTest "FOO=1"` against
`^[A-Za-z_][A-Za-z0-9_]*=` reports TRUE (both regex engines agree an
identifier assignment leads the string); this is R-Q2's baseline, not
a fidelity gap. The documented gap (lib/interp.ml:541-542, `Str` does
not read `(?:...)`) sits in the SECOND pattern, which this fixture
carries but does not assert past "the recorded table, at minimum
ASSIGN_WORD=TRUE NOT_A_PROGRAM=FALSE" (R-Q2's own minimum): `Str`
compiles `(?:#|&?[0-9]*[<>])` as literal characters `(`, `?`, `:`,
etc. rather than a non-capturing group, so it does not match the
literal input "2>/dev/null" at position 0, reporting FALSE, which
happens to be the SAME verdict Python's `re` reports for that
subject, so the recorded line is silent about the gap. This stage
records the gap's existence in prose (lib/interp.ml:541-542) rather
than manufacturing a subject that would flip the two engines apart,
since R-Q2's own ratified minimum only asks for the two-value table
above.

### Gate additions

Marker: PASS-M9B-CD-PORT
Ruling: R-Q1 (the shipped port), R10 (one edit, one mutation proof).
Command:
```
m9b_cd_check=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/examples/guard-cd.tot 2>&1); m9b_cd_check_rc=$?
m9b_cd_deny=$(echo '{"tool_name":"Bash","tool_input":{"command":"cd /tmp && rm -rf x"}}' | "$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/examples/guard-cd.tot 2>&1)
m9b_cd_allow=$(echo '{"tool_name":"Bash","tool_input":{"command":"cd /tmp"}}' | "$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/examples/guard-cd.tot 2>&1)
{ [ "$m9b_cd_check_rc" -eq 0 ] \
  && echo "$m9b_cd_deny" | rg -qF '"permissionDecision":"deny"' \
  && [ -z "$m9b_cd_allow" ]; } \
  && echo PASS-M9B-CD-PORT \
  || { echo "FAIL-M9B-CD-PORT (check_rc=$m9b_cd_check_rc deny=$m9b_cd_deny allow=$m9b_cd_allow)"; exit 1; }
```
Before the stage: exit 1, output contains "FAIL-M9B-CD-PORT" (
PREDICTED: examples/guard-cd.tot does not exist yet, so `gate-check`
fails to open the file and `check_rc` is non-zero).
After the stage: exit 0, output contains "PASS-M9B-CD-PORT" (
PREDICTED: the chained-cd payload's `command` field triggers
`classify`'s "chained-cd" tag, so `decide` returns `deny`, and the
JSON envelope prints `"permissionDecision":"deny"`; the lone-cd
payload's command has nothing past the first word, so `wordEnd`
consumes the whole string, `classify` returns "none", and `decide`
returns `allow`, which examples/guard.tot's own `main` shape prints
as empty stdout, matching the PASS-M5D-REWRAP-GUARD precedent at
dev/gates.sh:2411-2437 that an allow verdict is silent).
MUTATION: examples/guard-cd.tot:74, delete the `true` arm's `deny
(...)` and its `| true =>` line, leaving `decide`'s inner match with
only `| false => allow`, unconditionally allowing (one edit). The
recorded deny payload now prints nothing, `rg -qF
'"permissionDecision":"deny"'` fails against an empty string, and the
leg reddens with `FAIL-M9B-CD-PORT` naming `deny=` (empty).
Non-vacuous because: the deny payload and the allow payload are two
different recorded commands read through the SAME `decide`; deleting
only the deny arm collapses the deny reading to empty while leaving
the allow reading untouched, so the leg's failure is attributable to
exactly the deleted arm, not to a change shared with any other leg.

Marker: PASS-M9B-DEMAND-ORACLE
Ruling: R-Q2 (the recorded count of 2), A3-F1, A3-F2 (the two kernel
mutation proofs proposal 3 first offered are dropped; both would
redden an earlier-pinned leg first, not this one), R10.
Command:
```
m9b_word_msg=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/dev/m9b/wordend-index.tot 2>&1); m9b_word_rc=$?
m9b_rule_msg=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/dev/m9b/rule-table-nested.tot 2>&1); m9b_rule_rc=$?
m9b_log_count=$(rg -o 'forced.rewrite.count[^0-9]*([0-9]+)' -r '$1' "$ROOT"/dev/M9-BUILD-LOG.md 2>/dev/null | head -1)
{ [ "$m9b_word_rc" -ne 0 ] && echo "$m9b_word_msg" | rg -qF 'wordEnd failed the structural termination guard' \
  && [ "$m9b_rule_rc" -ne 0 ] && echo "$m9b_rule_msg" | rg -qF 'invalid constructor mkRule: negative or non-uniform occurrence of Rule' \
  && [ "$m9b_log_count" = "2" ]; } \
  && echo PASS-M9B-DEMAND-ORACLE \
  || { echo "FAIL-M9B-DEMAND-ORACLE (word_rc=$m9b_word_rc rule_rc=$m9b_rule_rc log_count=$m9b_log_count)"; exit 1; }
```
Before the stage: exit 1, output contains "FAIL-M9B-DEMAND-ORACLE" (
PREDICTED: dev/m9b/ does not exist yet, so both `gate-check` calls
fail to open their file and `m9b_log_count` reads empty, matching
neither the two message checks nor the count check).
After the stage: exit 0, output contains "PASS-M9B-DEMAND-ORACLE" (
PREDICTED: both fixtures are refused with their recorded whole lines,
by construction, since they are byte-identical to the panel's already
-vetted probes; dev/M9-BUILD-LOG.md records the literal "2").
MUTATION: dev/M9-BUILD-LOG.md, change the recorded forced-rewrite
count from "2" to "3" (one edit, no kernel edit at all). `m9b_log_count`
reads "3", the last conjunct fails, and the leg reddens with
`FAIL-M9B-DEMAND-ORACLE` naming `log_count=3`. This replaces
proposal 3's original two kernel-file mutation proofs
(lib/totality.ml:109, lib/check.ml:1969): both are already pinned
earlier, at dev/gates.sh:2545-2551 (PASS-M6A-INFINITARY-REJECTED) and
:2578-2596 (the M6A fence legs), so either edit would redden one of
those EARLIER legs first, leaving this leg's own failure unattributable
(a LEG-1 vacuity under R10); attack-3 findings A3-F1 and A3-F2 rule
both out, and the C7 prelude mutation proposal 3's fixes round also
floated is dropped outright per A3-F1's wider refusal of any
kernel-side mutation for this leg.
Non-vacuous because: a textual BUILD-LOG count that does not match
the two independently-observed refusal messages is a genuine
authorship error this leg alone catches; no other leg reads
dev/M9-BUILD-LOG.md's count.

Marker: PASS-M9B-REGEX-FIDELITY
Ruling: R-Q2 (the recorded regex table), R10.
Command:
```
m9b_regex_out=$("$watchdog" "$MED" dune exec --root "$ROOT" test/surface.exe -- gate-run "$ROOT"/dev/m9b/regex-fidelity.tot 2>&1)
{ echo "$m9b_regex_out" | rg -qF 'ASSIGN_WORD=TRUE'; } \
  && { echo "$m9b_regex_out" | rg -qF 'NOT_A_PROGRAM=FALSE'; } \
  && echo PASS-M9B-REGEX-FIDELITY \
  || { echo "FAIL-M9B-REGEX-FIDELITY (out=$m9b_regex_out)"; exit 1; }
```
Before the stage: exit 1, output contains "FAIL-M9B-REGEX-FIDELITY" (
PREDICTED: dev/m9b/regex-fidelity.tot does not exist yet, so
`gate-run` fails to open the file and `m9b_regex_out` is empty).
After the stage: exit 0, output contains "PASS-M9B-REGEX-FIDELITY" (
PREDICTED: "FOO=1" matches `^[A-Za-z_][A-Za-z0-9_]*=` under
Str, printing TRUE; "2>/dev/null" does not match
`^(?:#|&?[0-9]*[<>])` under Str's literal reading of `(?:`,
printing FALSE, the same verdict Python's `re` gives that subject).
MUTATION: dev/m9b/regex-fidelity.tot:13, swap the two `regexTest`
arguments, from `(regexTest "^[A-Za-z_][A-Za-z0-9_]*="
assignSubject)` to `(regexTest assignSubject
"^[A-Za-z_][A-Za-z0-9_]*=")` (one edit). `Str` now compiles
"FOO=1" as the pattern and searches it for the literal text
"^[A-Za-z_][A-Za-z0-9_]*=", which is absent, so `aw` becomes FALSE,
the recorded line reads "ASSIGN_WORD=FALSE", the first `rg -qF`
check fails, and the leg reddens with `FAIL-M9B-REGEX-FIDELITY`
naming the flipped line.
Non-vacuous because: the mutated line is read by no other leg;
PASS-M9B-CD-PORT never calls `regexTest` at all (R-Q1: the shipped
guard classifies only "chained-cd", never an assignment), so this is
the sole leg the edit can redden.

### Suite cases

Both land in the surface suite (test/surface.ml), following the M8
Stage C precedent (test/surface.ml:2460-2461) that an in-process case
proves elaborator-level behaviour a CLI-driven gate leg does not
duplicate, and the M7E precedent (test/surface.ml:697-702) that
in-process source arrives as an inline string, not a fixture path, so
neither case perturbs the transcript glob.

("M9B-1 m9b_cd_port_checks: the shipped port's fuel-based wordEnd
type-checks in process, the same acceptance PASS-M9B-CD-PORT already
pins from the CLI", `m7e_expect_source_checks bst
~label:"m9b_cd_port_checks" ~src:<examples/guard-cd.tot's source,
inlined verbatim>`).

("M9B-2 m9b_regex_fidelity_line: the regex-fidelity diagnostic's
printed line reads exactly ASSIGN_WORD=TRUE NOT_A_PROGRAM=FALSE, read
through Run.script's own exec path, not by shelling out",
`m9b_expect_source_prints` (a small new helper mirroring
`m7e_expect_source_checks`'s shape but capturing the executed
program's printed lines and asserting the tail line equals the
recorded string), on `dev/m9b/regex-fidelity.tot`'s source inlined
verbatim).

### Review checklist

- `git -C /Users/oobi/Documents/tot diff --stat` is empty before the stage starts building (no stray edits from an earlier stage).
- `rg -o 'PASS-M9B[A-Z0-9-]*' dev/gates.sh` prints nothing before this stage's legs are appended; Stage A's PASS-M9A-EXIT-STAMP is the one PASS-M9 hit (R11 holds at entry).
- The two dev/m9b/ fixtures are byte-identical to the panel's own vetted probe files; a byte diff against `/Users/oobi/Documents/tot-m9-probes/proposal-3/p1-word-end-index.tot` and `p4-rule-table-nested.tot` is empty.
- examples/guard-cd.tot denies only the "chained-cd" classify result; every other tool call and every other classify result allows, matching examples/guard-rewrap.tot's own narrowing precedent.
- dev/m5e-default-transcript.txt is resealed through dev/gen-m5e-transcript.sh, not hand-edited; the two diff legs at dev/gates.sh:2486 and :3259 return to green.
- The settle-budget leg's three literals (dev/gates.sh:3614-3621: m7a_files, m7a_green, the digest) are rewritten by re-running that leg's own recipe, not guessed.
- The PASS-M5D-TIERS literal at dev/gates.sh:2353 is rewritten by re-running its own recipe (`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh`), not guessed, and both the before and after readings are recorded in dev/M9-BUILD-LOG.md.
- SPEC.md debt entry 11 (SPEC.md:2668) carries its R-Q7 clause naming the PASS-M9B-DEMAND-ORACLE reading of 2, and keeps its heading and its "CARRIED" disposition.
- No existing PASS-M6A fence leg (dev/gates.sh:2578-2596, echoes at :2587 and :2595) changes; no nested-inductive rule lands in lib/check.ml or lib/totality.ml.
- dev/M9-BUILD-LOG.md records the forced-rewrite count as the bare literal `2`, plus both refused messages verbatim, so PASS-M9B-DEMAND-ORACLE's `rg -o` extraction is exact.
- Neither new suite case reads a file from disk; both carry their source inline, so `examples/*.tot test/fixtures/*.tot`'s glob count (105 to 106) is the only corpus-count change this stage makes.

### Rollback

Delete examples/guard-cd.tot, dev/m9b/wordend-index.tot,
dev/m9b/rule-table-nested.tot, dev/m9b/regex-fidelity.tot, and the
dev/m9b/ directory if now empty. Revert dev/gates.sh's three new
`PASS-M9B-*` legs and the settle-budget leg's three literals and the
five further literals listed in dev/M9-BUILD-LOG.md section 5
(m5d_tiers 247 -> 241 at :2353, m6e_holes 76 -> 69 at :3208, m6e_want
and m7d_want back to `ANCHORS total=99 expected-type-only=60
argument-driven=9 neither=30` at :3231 and :3852, m7b_holed 76 -> 69
at :3681) to their pre-stage values. Revert SPEC.md debt entry 11
(SPEC.md:2678) to its pre-Stage-B state: remove the R-Q7 clause naming
the PASS-M9B-DEMAND-ORACLE reading of 2 forced rewrites, and restore
the entry's heading and its "CARRIED" disposition byte-for-byte
(R1-F2).
Revert dev/M9-BUILD-LOG.md's Stage B entry (or
delete the file if this stage created it). Regenerate
dev/m5e-default-transcript.txt through dev/gen-m5e-transcript.sh
against the reverted corpus so the two diff legs read green again.
Remove the two new cases from test/surface.ml's `cases` list.
`rg -o 'PASS-M9B[A-Z0-9-]*' dev/gates.sh` should again print nothing.

Gate markers added: 3 (ESTIMATE)
Suite cases added: 2 (ESTIMATE)
Exit PASS count: 447 slice (ESTIMATE), 451 wrapper (ESTIMATE)

# M9 plan slice: STAGE C

Scope note. This file is one slice of dev/M9-PLAN.md. It covers only
STAGE C, the twelve surface interfaces, last. It assumes Stage A (the
M8 exit stamp, the SPEC repair and the C5 two-horn record) and Stage B
(the demand instrument, the cd-prefix-guard.py port) have already
landed and closed green, entry 447 slice (451 wrapper), per the ratified
stage table (/Users/oobi/Documents/tot-m9-ratifications.md line 7) and
the design verdict's own Stage C entry
(/Users/oobi/Documents/tot-m9-design-verdict.md:247-249). Every citation
below into the tot tree was read at HEAD 5538927
(/Users/oobi/Documents/tot, `git -C /Users/oobi/Documents/tot diff`
prints nothing, the tree equals HEAD, M8 Stage D's own closing commit).
No file under /Users/oobi/Documents/tot was written while drafting this
slice.

## STAGE C: the twelve surface interfaces, last

### Goal

Write one `.mli` for each of the twelve `surface/*.ml` modules, so
`surface/` reaches the same interface coverage `lib/` reached at M8
Stage D (SPEC.md:1931-1933). No `surface/*.ml` body changes. No `lib/`
file changes. The stage adds two gate markers and one suite case and
closes the sweep M8's own Stage D deferred: "it waits for a milestone
whose stages do not touch those three files", surface/elab.ml,
surface/run.ml and surface/bootstrap.ml (dev/M8-PLAN.md:2892-2900,
restated at tot-m9-design-verdict.md:123-129). Stage C lands LAST in
this milestone
because it is the only candidate in scope with no dependency on the
Stage A or Stage B answer (tot-m9-proposal-3.md:408-411, carried
unchallenged into the verdict).

### Rulings covered

- R-Q5 (binding). "Stage C covers all twelve surface/*.mli in one
  stage. If it overruns, surface/elab.ml ALONE splits into a Stage D;
  the coverage leg asserts 12 and 12 with gap 0 wherever it lands and is
  never weakened below 12." This slice covers all twelve in one stage;
  see Entry state and Files touched for the measured sizes that support
  landing all twelve without a split, and Review checklist item 1 for
  the fallback this ruling names if elab.ml alone overruns during the
  actual build.
- Carried A3-F4 (attack-3 finding 4, ACCEPTED, restated as ratification
  binding text). "surface/cache.mli must EXPORT format_version plus the
  five internals test/surface.ml reads at surface/cache.ml:129, :130,
  :131, :133, :170, and must hide the three filesystem mutators." This
  is PASS-M9C-SURFACE-INTERNAL below, verbatim to the finding: hiding
  any of the five internals turns the 158-case surface suite into a
  COMPILE error, not a gate red, so the leg is written to REQUIRE their
  export rather than merely tolerate it.
- Carried M8 R-Q6. "No stage bumps Cache.format_version from 10; no
  jarr migration in M9." Stage C is the only M9 stage that touches
  surface/cache at all (it adds cache.mli; it does not touch cache.ml),
  so this ruling binds here directly. Suite case M9C-1 is the leg that
  reads `Cache.format_version` by name through the newly sealed
  interface and asserts it is still 10.
- Carried A3-F7 (ACCEPTED). "The battery model is a DELTA model only,
  exit equals entry plus new markers plus new suite cases in EITHER
  suite, the absolute term is never re-derived, every stage names which
  suite a case lands in." M9C-1 lands in the SURFACE suite
  (test/surface.ml); see Suite cases.
- Carried R11. "The PASS-M9 namespace is unused at HEAD." Re-checked
  for this slice: `rg -o 'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh`
  prints nothing at HEAD (0 lines), so `PASS-M9C-SURFACE-MLI-COVERAGE`
  and `PASS-M9C-SURFACE-INTERNAL` are free names, and remain free against
  whatever Stage A and Stage B reserve, since this slice adds no name
  that collides with the six names the verdict's stage table lists
  (tot-m9-ratifications.md:7).
- Carried R10. "One edit per mutation proof." The two markers below name
  two distinct mutations (delete surface/loc.mli; add one forbidden
  `val` to surface/cache.mli); `rg -o '^\s*MUTATION:.*'` over this
  slice's own Gate additions block, run after assembly, must print two
  distinct lines.
- Carried C-A14. "The wrapper `PASS=` count reads four higher than the
  gate slice." Every count below is given as slice figure and wrapper
  figure (slice + 4).
- R-F1 (ACCEPT). "If the exit criteria also demand a `Known debts
  entering M10` paragraph, Stage C owns it as the milestone's own exit
  stamp, written in its last SPEC edit, naming C1 and C2 with the Stage
  B reading, so M9 does not repeat the M8 debt that became C3." Stage C
  is the last stage in this milestone (Goal, above), so this SPEC.md
  paragraph is its own closing act, added to Files touched and Review
  checklist; it adds no gate marker and no suite case.

### Entry state

Measured at HEAD (before any M9 stage lands):

- `ls /Users/oobi/Documents/tot/surface/*.ml | wc -l` prints 12:
  bootstrap.ml, cache.ml, effect.ml, elab.ml, lexer.ml, loc.ml,
  parser.ml, run.ml, serror.ml, source.ml, syntax.ml, token.ml.
- `ls /Users/oobi/Documents/tot/surface/*.mli` finds no match: zero
  interfaces exist under surface/ at HEAD.
- `wc -l /Users/oobi/Documents/tot/surface/*.ml` totals 4479 lines, with
  elab.ml the largest at 1025 lines and 36 top-level `let`/`type`
  declarations (`rg -n '^(let|type|module|exception)\s'
  surface/elab.ml | wc -l` prints 36), run.ml second at 683 lines,
  bootstrap.ml third at 550 lines, and loc.ml the smallest at 17 lines
  with 6 top-level declarations.
- `comm -23 <(fd -e ml --max-depth 1 . /Users/oobi/Documents/tot/surface -x basename | rg -o '^[^.]+' | sort -u) <(fd -e mli --max-depth 1 . /Users/oobi/Documents/tot/surface -x basename | rg -o '^[^.]+' | sort -u) | wc -l | tr -d ' '`
  prints 12: the comm gap over surface/ is 12 at HEAD, matching the
  12/0 file counts above.
- `rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | wc -l`
  prints 177 at HEAD (before any M9 stage).
- `rg -o 'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh`
  prints nothing at HEAD (R11 measured).
- The kernel suite (`test/main.ml`) reads 105 PASS, 0 FAIL
  (dev/M8-BUILD-LOG.md:337, :1620, :1692, :1783). The surface suite
  (`test/surface.ml`) reads 158 PASS, 0 FAIL (dev/M8-BUILD-LOG.md:2225,
  :2302, :2609).
- Entry to Stage C, ESTIMATE per the ratified stage table
  (tot-m9-ratifications.md line 7) and the verdict's own Stage C entry
  (tot-m9-design-verdict.md:247-249): 447 slice (451 wrapper), 160
  surface-suite cases (158 plus Stage B's two), after Stage A adds one
  SPEC-only marker with no code and no suite case, and Stage B adds
  three markers plus two surface-suite cases plus the demand-instrument
  example under examples/. No M9 stage before Stage C touches a
  `surface/*.ml` or a `lib/` file: Stage A edits SPEC.md and
  dev/gates.sh, and Stage B adds examples/guard-cd.tot, the dev/m9b/
  fixtures, gate legs and two suite cases (per R-Q1 and R-Q4) and the
  SPEC debt-entry-11 clause (per R-Q7).  This is what makes the comm
  gap and file-count literals above (12 and 0, 12 and 12 target) still
  accurate entering Stage C: nothing upstream of this slice moves them.
- `surface/cache.ml` at HEAD: `format_version` is `let format_version :
  int = 10` at surface/cache.ml:118; `magic_width` at :129, `version_width`
  at :130, `digest_width` at :131, `exe_width` at :132 (not read by
  test/surface.ml and not part of the five internals A3-F4 names),
  `header_width` at :133, and `cache_dir` at surface/cache.ml:170,
  `let cache_dir () : string option = Lazy.force cache_dir_opt`. The
  three filesystem mutators are `mkdir_one` at surface/cache.ml:177,
  `ensure_dir` at surface/cache.ml:187 and `write_exe_memo` at
  surface/cache.ml:257. `rg -n 'ensure_dir|mkdir_one|write_exe_memo'
  /Users/oobi/Documents/tot/lib /Users/oobi/Documents/tot/surface
  /Users/oobi/Documents/tot/bin /Users/oobi/Documents/tot/test -g '*.ml'
  -g '*.mli' | rg -v 'surface/cache.ml'` prints nothing: no file outside
  surface/cache.ml names any of the three, so hiding them costs nothing
  downstream.
- `test/surface.ml` reads five of the six via qualified name:
  `Tot_surface.Cache.cache_dir` at test/surface.ml:1727,
  `Tot_surface.Cache.magic_width` and `Tot_surface.Cache.version_width`
  at test/surface.ml:1767-1768, `Tot_surface.Cache.digest_width` at
  test/surface.ml:1768, `Tot_surface.Cache.header_width` at
  test/surface.ml:1756 and :1782. `rg -n 'Cache\.format_version'
  /Users/oobi/Documents/tot/test/surface.ml` prints nothing: no existing
  case names `format_version` by qualified path, which is why suite case
  M9C-1 below is a new observable and not a restatement of an existing
  one.

### Files touched

- `surface/bootstrap.ml.mli` is not a real path; the twelve new files
  are, one per existing module, each named `surface/<module>.mli`:
  `surface/bootstrap.mli`, `surface/cache.mli`, `surface/effect.mli`,
  `surface/elab.mli`, `surface/lexer.mli`, `surface/loc.mli`,
  `surface/parser.mli`, `surface/run.mli`, `surface/serror.mli`,
  `surface/source.mli`, `surface/syntax.mli`, `surface/token.mli`. Every
  one restates the module's own currently-used public surface; none adds
  a function, a type or a behaviour. `surface/cache.mli` is the one
  interface with a narrow-export obligation (Design, below); the other
  eleven each export exactly the names their own callers already reach
  by qualified path, discovered per module by `rg -n 'Tot_surface\.<Mod>\.'`
  over bin/, surface/ and test/, the same discovery method M8 Stage D's
  D3 used for lib/ (dev/M8-PLAN.md:2120-2136).
- No `surface/*.ml` file changes. No `lib/*.ml` or `lib/*.mli` file
  changes.
- `dev/gates.sh`: two new legs appended, in the PASS-M8D-MLI-COVERAGE /
  PASS-M8D-KERNEL-INTERNAL pattern (dev/gates.sh:4370-4404 and
  dev/gates.sh:4406-4462 at HEAD), inserted after Stage A's and Stage
  B's own legs, all of which sit after PASS-M8D-NO-BEHAVIOUR-CHANGE's
  closing brace (dev/gates.sh:4519-4524 at HEAD) and before the
  `ctxcat id 5` comment (dev/gates.sh:4526 at HEAD) that opens the two
  fixed-last performance legs the file itself pins as always-last
  (dev/gates.sh:4361).
- `test/surface.ml`: one new case, M9C-1, inserted immediately after the
  cache round-trip tuple's own closing `);` at test/surface.ml:1804, and
  before the `(* M3 Stage D, D4 *)` comment at test/surface.ml:1805-1806.
- `dev/M9-BUILD-LOG.md`: records the measured comm gap before and after
  (12 to 0), the nine cache.mli export literals (`format_version`,
  `magic_width`, `version_width`, `digest_width`, `header_width`,
  `cache_dir` plus `key`, `save` and `load`, F4), naming which six of
  them PASS-M9C-SURFACE-INTERNAL pins (`format_version`, `magic_width`,
  `version_width`, `digest_width`, `header_width`, `cache_dir`), and the
  closing chain 447 to 450 (451 to 454 wrapper).
- `SPEC.md`: one edit, appended to section 6, "Known debts (deliberate)"
  (SPEC.md:2042). Stage C lands last in this milestone (Goal, above), so
  it owns the milestone's own exit stamp (R-F1): a dated "Known debts
  entering M10" paragraph, in the shape of Stage A's own "Known debts
  entering M9" paragraph, naming C1 and C2 as the two debts M9 carries
  forward, recording the R-Q3 order (C2 first and soaks, then C1), and
  stating the Stage B reading, the demand instrument's measured 2 forced
  rewrites (R-Q2, PASS-M9B-DEMAND-ORACLE), which is not itself demand
  for either debt and shrinks neither, so M9 does not repeat the M8 debt
  that became C3.

### Design

The sweep is the M8 Stage D method (dev/M8-PLAN.md:2120-2136, "D3.
Preserve the other modules' actual public types") retargeted at
surface/. Restate each module's inferred signature, including module
declarations a `^let|^type` scan misses; keep every constructor a caller
matches on; validate by full compilation of bin/ and both suites, not
only by the interface-file count. No new function or type is written in
any `surface/*.ml` file. Every `.mli` is a narrowing or an exact
restatement of what already compiles today; if any restatement is
narrower than a real caller needs, the build fails at `dune build`
before the gate ever runs, the same trap D3 named for lib/.

Ten of the twelve are exact restatements with no narrowing decision to
make: `surface/loc.mli`, `surface/token.mli`, `surface/source.mli`,
`surface/syntax.mli`, `surface/serror.mli`, `surface/lexer.mli`,
`surface/effect.mli`, `surface/parser.mli`, `surface/elab.mli`,
`surface/run.mli` and `surface/bootstrap.mli` (that is eleven; the
twelfth, cache, is the one with a real decision, below). The smallest,
`surface/loc.mli`, restates surface/loc.ml:1-17 byte for byte in
signature form:

```ocaml
type t = {
  line : int;
  col : int;
}

val start : t
val next_col : t -> t
val advance : t -> int -> t
val next_line : t -> t
val to_string : t -> string
```

All six of loc.ml's top-level declarations are exported; `Loc.t`'s
fields stay named and public because callers construct and pattern-match
the record directly (for example `{ l with col = l.col + n }` inside
loc.ml itself, and callers elsewhere read `.line` and `.col`), so an
abstract `type t` here would not compile, the same trap D3 named for
`Quantity.t` (dev/M8-PLAN.md:2124-2136). This is also the smallest
interface in the sweep, which is why its mutation proof (Gate additions,
below) is cheap to state precisely: deleting the whole six-value file is
one edit with an unambiguous before/after.

The other nine exact restatements (excluding elab.ml and run.ml, sized
separately below) follow the same rule: `surface/token.mli` restates
token.ml's 3 declarations, `surface/source.mli` and `surface/syntax.mli`
restate their 4 each, `surface/serror.mli` its 6, `surface/lexer.mli` its
12, `surface/effect.mli` its 16, and `surface/parser.mli` its 17,
discovered by `rg -n 'Tot_surface\.<Mod>\.'` over bin/, the other
surface/*.ml files and test/surface.ml, the same per-module discovery
D3 used for lib/. None of these nine is touched by any earlier M9 stage
(Stage A edits SPEC.md and dev/gates.sh; Stage B adds
examples/guard-cd.tot, the dev/m9b/ fixtures, gate legs and two suite
cases (per R-Q1 and R-Q4) and the SPEC debt-entry-11 clause (per R-Q7);
no M9 stage before Stage C touches a `surface/*.ml` or a `lib/` file),
so each restatement is read against the identical HEAD source Stage C
started from.

`surface/elab.ml` (1025 lines, 36 top-level declarations) and
`surface/run.ml` (683 lines, 25 top-level declarations) are the two
modules R-Q5 names by size. Both get the same D3 treatment: restate,
do not narrow past what bin/ and the other eleven modules already call.
Because M8's own Stage A through D never touched these two files' public
surface (only their bodies, in earlier milestones), and because Stage C
itself edits no body, the interface each gets is the signature the
compiler already infers today; the sweep adds a wall around existing
behaviour, not a new contract. If assembling and compiling these two
`.mli` files against every caller in bin/, surface/ and test/ overruns
this stage's own budget, R-Q5 names the fallback precisely: split
`surface/elab.mli` alone into a Stage D, leaving the coverage leg's
target at 12 and 12 with gap 0 wherever it lands, never weakened below
12 (Review checklist item 1 restates this as a stop condition, not a
design change).

`surface/bootstrap.ml` (550 lines, 28 top-level declarations) is the
third file M8's own Stage A residual named as a reason the sweep waited
(dev/M8-PLAN.md:2892-2900). The same rule applies: `surface/
bootstrap.mli` restates the prim table and the loader entry points bin/
already calls by qualified name, with no change to surface/bootstrap.ml
itself.

`surface/cache.mli` is the twelfth and the one the ratification names
directly (carried A3-F4, amended by R-F4). Its export list is the six
A3-F4 values plus every other Cache value an external module reaches by
qualified name, and nothing that names a filesystem mutator:

```ocaml
val format_version : int
val magic_width : int
val version_width : int
val digest_width : int
val header_width : int
val cache_dir : unit -> string option
val key : string -> string
val load : string -> (Global.t * Interp.globals) option
val save : string -> Global.t -> Interp.globals -> unit
```

`format_version` (surface/cache.ml:118), `magic_width` (:129),
`version_width` (:130), `digest_width` (:131) and `header_width` (:133)
are the five plain `int` constants the on-disk header packs; `cache_dir`
(:170) is the function that resolves `TOT_CACHE_DIR` or `$HOME/.cache/tot`
lazily. `key` (surface/cache.ml:343), `load` (:393) and `save` (:432)
are the three entry points surface/bootstrap.ml calls by qualified name
(Cache.key at :519, Cache.load at :525, Cache.save at :545, each also
named in bootstrap.ml's own doc comments at :365, :485, :505 and :516)
and test/surface.ml's D2 case exercises directly (test/surface.ml:1086-
1087, :1708-1800); a six-value `.mli` that omitted them would stop
`dune build` at surface/bootstrap.ml:519 with an unbound-value error
before any gate leg runs, the fault F4 names. `exe_width`
(surface/cache.ml:132) is deliberately NOT exported:
it feeds `header_width`'s own computation but no caller outside
cache.ml reads it by name, so exporting it would widen the interface
past what A3-F4 measured. `ensure_dir` (surface/cache.ml:187),
`mkdir_one` (surface/cache.ml:177) and `write_exe_memo`
(surface/cache.ml:257) are the three filesystem mutators the ratification
requires hidden; none is read by any file outside surface/cache.ml
(Entry state, above), so hiding them changes nothing any caller compiles
against. This is the A3-F4 repair stated as code: an `.mli` that hides
any of the five plain constants or `cache_dir` turns every one of the
158 surface-suite cases that reach them (test/surface.ml:1727, :1756,
:1767, :1768, :1782) into a `dune build` failure, not a gate red, which
is exactly why PASS-M9C-SURFACE-INTERNAL is written to REQUIRE their
export rather than merely tolerate it (Gate additions, below).

Every other value `surface/cache.ml` defines (the `cache_dir_opt` lazy
thunk, `version_field`, `magic`, `exe_digest_hex`, `file_path` and the
header/decode helpers) either already has a narrow public use bin/ and
the suite reach through some other name, or is a private helper no file
outside cache.ml mentions, confirmed by the same `rg` sweep over
surface/ and test/ that surfaced `key`, `save` and `load`; `surface/
cache.mli` restates whichever of these bin/ and test/surface.ml already
call, following the same D3 discovery rule as the other eleven modules,
with the nine-value export above, the six A3-F4 constants and functions
plus `key`, `save` and `load`, as the part the ratification and F4 fix
exactly.

### Gate additions

Both legs are written to run standalone, from the repo root, with no
reliance on `dev/gates.sh`'s own `$ROOT` variable, per the plan's own
tree rules. The build workflow folds each into that shared machinery
when it appends the real leg; the predicted exit codes and substrings
do not depend on which shell scaffold carries them.

1. Marker: PASS-M9C-SURFACE-MLI-COVERAGE
   Ruling: R-Q5, all twelve `surface/*.mli` land, coverage asserts 12
   and 12 with gap 0.
   Command: `comm -23 <(fd -e ml --max-depth 1 . /Users/oobi/Documents/tot/surface -x basename | rg -o '^[^.]+' | sort -u) <(fd -e mli --max-depth 1 . /Users/oobi/Documents/tot/surface -x basename | rg -o '^[^.]+' | sort -u) | wc -l | tr -d ' '`
   Before the stage: exit 0, output contains "12" (MEASURED at HEAD:
   twelve `.ml` files, zero `.mli` files, comm gap 12).
   After the stage: exit 0, output contains "0" (PREDICTED: twelve
   `.mli` files land, one per module, comm gap 0).
   MUTATION: `surface/loc.mli`, delete the file Stage C creates (the
   six-value restatement of surface/loc.ml:1-17 in Design, above); the
   comm gap moves from 0 to 1, the same non-vacuity argument
   PASS-M8D-MLI-COVERAGE uses at dev/gates.sh:4370-4404 (there: delete
   lib/totality.mli, gap 0 to 1).
   Non-vacuous because: before the stage the gap is 12, never 0, so the
   leg cannot pass until every one of the twelve files exists; deleting
   any one afterward, loc.mli included, moves the count off 0 again.

   Gates.sh insertion. Appended after Stage A's and Stage B's own legs,
   all of which land after PASS-M8D-NO-BEHAVIOUR-CHANGE's closing brace
   (dev/gates.sh:4519-4524 at HEAD) and before the `ctxcat id 5` comment
   (dev/gates.sh:4526 at HEAD), retaining the two fixed-last performance
   legs (dev/gates.sh:4361) as the file's own final two legs. The PASS
   line is emitted in the PASS-M8D-MLI-COVERAGE shape (dev/gates.sh:4390-
   4404), retargeted at `"$ROOT"/surface`:

   ```
   m9c_gap=$(comm -23 \
     <(fd -e ml --max-depth 1 . "$ROOT"/surface -x basename | rg -o '^[^.]+' | sort -u) \
     <(fd -e mli --max-depth 1 . "$ROOT"/surface -x basename | rg -o '^[^.]+' | sort -u))
   m9c_gap_code=$?
   m9c_missing=$(printf '%s\n' "$m9c_gap" | rg -c '^\S' || echo 0)
   m9c_ml=$(fd -e ml --max-depth 1 . "$ROOT"/surface | wc -l | tr -d ' ')
   m9c_mli=$(fd -e mli --max-depth 1 . "$ROOT"/surface | wc -l | tr -d ' ')
   { [ "$m9c_gap_code" -eq 0 ] && [ "$m9c_missing" = 0 ] && [ -z "$m9c_gap" ] \
       && [ "$m9c_ml" -eq 12 ] && [ "$m9c_mli" -eq 12 ]; } \
     && echo PASS-M9C-SURFACE-MLI-COVERAGE \
     || {
       printf '%s\n' "$m9c_gap"
       echo "FAIL-M9C-SURFACE-MLI-COVERAGE (missing=$m9c_missing comm=$m9c_gap_code ml=$m9c_ml mli=$m9c_mli)"
       exit 1
     }
   ```

2. Marker: PASS-M9C-SURFACE-INTERNAL
   Ruling: carried A3-F4, surface/cache.mli exports format_version plus
   the five internals test/surface.ml reads and hides the three
   filesystem mutators.
   Command: `add=$(rg -n '^\s*val (ensure_dir|mkdir_one|write_exe_memo)\b' /Users/oobi/Documents/tot/surface/cache.mli); addcode=$?; fmt=$(rg -c '^val format_version : int$' /Users/oobi/Documents/tot/surface/cache.mli 2>/dev/null || echo 0); magic=$(rg -c '^val magic_width : int$' /Users/oobi/Documents/tot/surface/cache.mli 2>/dev/null || echo 0); ver=$(rg -c '^val version_width : int$' /Users/oobi/Documents/tot/surface/cache.mli 2>/dev/null || echo 0); dig=$(rg -c '^val digest_width : int$' /Users/oobi/Documents/tot/surface/cache.mli 2>/dev/null || echo 0); hdr=$(rg -c '^val header_width : int$' /Users/oobi/Documents/tot/surface/cache.mli 2>/dev/null || echo 0); dir=$(rg -c '^val cache_dir : unit -> string option$' /Users/oobi/Documents/tot/surface/cache.mli 2>/dev/null || echo 0); printf 'add_code=%s fmt=%s magic=%s ver=%s dig=%s hdr=%s dir=%s\n' "$addcode" "$fmt" "$magic" "$ver" "$dig" "$hdr" "$dir"`
   Before the stage: exit 2 on the forbidden-name check (surface/cache.mli
   does not exist at HEAD, PREDICTED: `rg` reports code 2, "No such file
   or directory"), and every positive count falls back to 0, so the
   pinned conjunction is false.
   After the stage: the forbidden-name check exits 1 with empty output
   (no match, PREDICTED, none of the three mutators is exported) and all
   six positive counts read 1: "add_code=1 fmt=1 magic=1 ver=1 dig=1
   hdr=1 dir=1".
   MUTATION: `surface/cache.mli`, add `val ensure_dir : string -> unit`
   immediately below `val format_version : int` (the file Stage C
   creates, Design above); the forbidden-name check now exits 0 and
   prints the forbidden line, and the leg reddens.
   Non-vacuous because: at HEAD there is no surface/cache.mli, so every
   positive conjunct is false and the forbidden-name check cannot even
   run against a real file; the leg cannot pass before Stage C writes
   the interface, and it cannot stay green if the interface widens past
   the six values afterward.

   Gates.sh insertion. Appended immediately after leg 1, in the
   PASS-M8D-KERNEL-INTERNAL shape (dev/gates.sh:4406-4462 at HEAD, the
   "code 1 means absent, codes 0 and 2 both fail" discipline):

   ```
   m9c_add=$(rg -n '^\s*val (ensure_dir|mkdir_one|write_exe_memo)\b' "$ROOT"/surface/cache.mli)
   m9c_add_code=$?
   m9c_fmt=$(rg -c '^val format_version : int$' "$ROOT"/surface/cache.mli)
   m9c_magic=$(rg -c '^val magic_width : int$' "$ROOT"/surface/cache.mli)
   m9c_ver=$(rg -c '^val version_width : int$' "$ROOT"/surface/cache.mli)
   m9c_dig=$(rg -c '^val digest_width : int$' "$ROOT"/surface/cache.mli)
   m9c_hdr=$(rg -c '^val header_width : int$' "$ROOT"/surface/cache.mli)
   m9c_dir=$(rg -c '^val cache_dir : unit -> string option$' "$ROOT"/surface/cache.mli)
   { [ "$m9c_add_code" -eq 1 ] && [ -z "$m9c_add" ] \
       && [ "$m9c_fmt" = 1 ] && [ "$m9c_magic" = 1 ] && [ "$m9c_ver" = 1 ] \
       && [ "$m9c_dig" = 1 ] && [ "$m9c_hdr" = 1 ] && [ "$m9c_dir" = 1 ]; } \
     && echo PASS-M9C-SURFACE-INTERNAL \
     || {
       printf '%s\n' "$m9c_add"
       echo "FAIL-M9C-SURFACE-INTERNAL (add_code=$m9c_add_code add=$m9c_add fmt=$m9c_fmt magic=$m9c_magic ver=$m9c_ver dig=$m9c_dig hdr=$m9c_hdr dir=$m9c_dir)"
       exit 1
     }
   ```

Conservativity. The sweep is a refactor, and the five-example digest
`f1450de0006de4b7339b2f39ec2e2e50` at 43 lines (dev/gates.sh:3443-3482,
PASS-M7A-CONSERVATIVITY, and dev/gates.sh:4464-4524,
PASS-M8D-NO-BEHAVIOUR-CHANGE, both MEASURED at HEAD) must not move.
Stage C adds no third leg for that digest: the two existing legs already
enumerate the same five explicit example paths rather than a glob, so a
third copy could never be the first red in a battery run
(tot-m9-proposal-3.md:311-318, the LEG-1 finding
dev/gates.sh:4477-4487). A stage that added one anyway would have
written a vacuous leg.

### Suite cases

- File: `test/surface.ml`. Inserted immediately after the cache
  round-trip tuple's own closing `);` at test/surface.ml:1804, before
  the `(* M3 Stage D, D4 *)` comment at test/surface.ml:1805-1806.
  Assertion, byte for byte:

  ```ocaml
  ( "M9C-1: surface/cache.mli seals format_version at 10, the invariant \
     carried M8 R-Q6 and this ratification both forbid moving",
    fun () ->
      if Int.equal Tot_surface.Cache.format_version 10 then Ok ()
      else
        Error
          (Printf.sprintf "Cache.format_version through the sealed interface is %d, want 10"
             Tot_surface.Cache.format_version) );
  ```

  Why it is not a duplicate of either gate leg. Both
  PASS-M9C-SURFACE-MLI-COVERAGE and PASS-M9C-SURFACE-INTERNAL are static
  `rg` scans of `surface/cache.mli`'s TEXT; neither compiles anything and
  neither reads `surface/cache.ml`'s actual VALUE. A gate leg that only
  matches the text `val format_version : int` stays green even if a
  future edit to `cache.ml` moved the number itself away from 10, so
  long as the `.mli` line is untouched. M9C-1 is the one observable in
  the whole battery that resolves `Cache.format_version` through the
  sealed module at RUN TIME and checks the number itself, which is what
  carried M8 R-Q6 actually forbids moving. `rg -n
  'Cache\.format_version' test/surface.ml` prints nothing at HEAD
  (Entry state, above), so this is a genuinely new assertion, not a
  restatement of one of the 158 existing cases. It lands in the SURFACE
  suite (A3-F7): 158 to 159 surface-suite cases, kernel suite unchanged
  at 105.

### Review checklist

1. If assembling and compiling `surface/elab.mli` and its eleven
   siblings against every caller in bin/, surface/ and test/ overruns
   this stage's budget, split `surface/elab.mli` alone into a Stage D
   (R-Q5). The coverage leg's target stays 12 and 12 with gap 0 wherever
   it lands; do not weaken it below 12 in either stage.
2. Confirm every one of the twelve new `.mli` files restates its
   module's own currently-used public surface with no narrowing beyond
   what D3's discovery method finds and no widening beyond it either:
   `dune build` of bin/, the kernel suite and the surface suite must
   succeed with zero new warnings against each touched file's own HEAD
   baseline.
3. Confirm `surface/cache.mli` exports the six A3-F4 names in Design
   (`format_version`, `magic_width`, `version_width`, `digest_width`,
   `header_width`, `cache_dir`) plus `key`, `save` and `load` (F4), and
   none of `exe_width`, `ensure_dir`, `mkdir_one` or `write_exe_memo`.
   Re-run the six positive `rg -c` checks and the one forbidden-name
   `rg -n` check in Gate additions leg 2 by hand and confirm each reads
   the value the Before/After lines predict; `key`, `save` and `load`
   are confirmed by the one `rg` sweep over surface/ and test/ that
   Design runs, not by a new gate-leg conjunct.
4. Confirm no `surface/*.ml` file's bytes moved: `md5 -q` every one of
   the twelve `.ml` files before and after the stage and confirm all
   twelve are unchanged. Only twelve new `.mli` files exist in the diff.
5. Confirm no `lib/*.ml` or `lib/*.mli` file is touched: `git -C
   /Users/oobi/Documents/tot diff --stat -- lib/` (once this stage is a
   real diff, not this read-only plan) must print nothing.
6. Re-run both gate commands in Gate additions and confirm each
   MUTATION turns its own named leg red and no other leg's mutation
   proof: `rg -o '^\s*MUTATION:.*'` over this slice's own two marker
   blocks, `sort | uniq -d`, must print nothing (R10).
7. Confirm the M9C-1 suite case fails to compile, not merely fails at
   run time, if `surface/cache.mli` omits `format_version`: this is the
   COMPILE-error trap A3-F4 names, and it is the reason the case is
   worth adding rather than folded into a gate leg.
8. Confirm `PASS-M7A-CONSERVATIVITY`'s digest and line-count pins
   (dev/gates.sh:3443-3482) and `PASS-M8D-NO-BEHAVIOUR-CHANGE`'s
   (dev/gates.sh:4464-4524) both still read
   `f1450de0006de4b7339b2f39ec2e2e50` at 43 lines after the stage lands.
   A mismatch here stops the stage; an interface-only sweep must not
   move either.
9. Book a conflict note in `dev/M9-BUILD-LOG.md` for any literal this
   stage measured and found different from its ESTIMATE (447 to 450
   slice, 451 to 454 wrapper, 160 to 161 surface-suite cases), per the
   conflict-note protocol M8 Stage D's own gate names
   (dev/M8-PLAN.md:2328-2335). A stage that measured no difference books
   no note and says so.
10. Confirm the "Known debts entering M10" paragraph appended to
    SPEC.md section 6 names both C1 and C2, records the R-Q3 order (C2
    first and soaks, then C1), and states the Stage B reading of 2
    forced rewrites without shrinking either debt (R-F1).

### Rollback

1. Delete all twelve new `.mli` files under `surface/`: `bootstrap.mli`,
   `cache.mli`, `effect.mli`, `elab.mli`, `lexer.mli`, `loc.mli`,
   `parser.mli`, `run.mli`, `serror.mli`, `source.mli`, `syntax.mli`,
   `token.mli`.
2. Remove the two new gate legs from `dev/gates.sh`, in reverse order of
   insertion (`PASS-M9C-SURFACE-INTERNAL` first, then
   `PASS-M9C-SURFACE-MLI-COVERAGE`), so a partial revert never leaves a
   later leg referencing a marker an earlier revert step already
   removed.
3. Remove the one new `test/surface.ml` case, `M9C-1`, restoring the
   cache round-trip tuple's closing `);` at test/surface.ml:1804 as the
   line immediately before the `(* M3 Stage D, D4 *)` comment.
4. Re-run `comm -23 <(fd -e ml --max-depth 1 . /Users/oobi/Documents/tot/surface -x basename | rg -o '^[^.]+' | sort -u) <(fd -e mli --max-depth 1 . /Users/oobi/Documents/tot/surface -x basename | rg -o '^[^.]+' | sort -u) | wc -l | tr -d ' '`
   and confirm it reads 12 again, and `rg -o 'PASS-M9C[A-Z0-9-]*'
   /Users/oobi/Documents/tot/dev/gates.sh` prints nothing, confirming
   the stage left no trace for a later attempt.
5. No `lib/` or `surface/*.ml` rollback step is needed: neither was
   ever touched by the real stage (Files touched, above).
6. Remove the appended "Known debts entering M10" paragraph from
   SPEC.md section 6 (R-F1), restoring the "Known debts entering M9"
   paragraph Stage A wrote as section 6's last entry.

Gate markers added: 2 (ESTIMATE)
Suite cases added: 1 (ESTIMATE)
Exit PASS count: 450 slice (ESTIMATE), 454 wrapper (ESTIMATE)

## 8. Exit criteria and completion checklist

This section is cross-cutting. It carries no stage's payload and it adds
no `PASS-M9` leg of its own. It states the gate a stage closes at, the
gate the whole milestone closes at, the one acceptance test that proves
the milestone's theme, the rule that shrinks the milestone if it must
shrink, and the changes this milestone deliberately does not make. The
MAIN LOOP walks this section at build completion, the way it walked
`dev/M8-PLAN.md`'s own section 8 (`dev/M8-PLAN.md:2249-2257`).

Citation rule for this section: reference state HEAD `5538927`, the
commit that closes M8 Stage D. `git -C /Users/oobi/Documents/tot diff`
returns nothing against this state, so every citation below is a plain
HEAD citation with no working-tree caveat; M9 does not inherit an
unstaged parent diff the way M8 Stage E inherited one from M7.

### 8.1 The per-stage exit gate

Every stage, P0, A, B and C, closes only when all five of the following
hold, adjusted for P0's shape (a plan commit with no gate leg, stated
below). A stage that reports itself closed without measuring all five
has not closed; it has stopped early.

1. **The four battery commands are green.** Run from the repo root, no
   `cd`, absolute paths:

       dune build --root /Users/oobi/Documents/tot
       dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -3
       dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -3
       zsh /Users/oobi/Documents/tot/dev/gates.sh > "$TMPDIR/tot-gate.out" 2>&1; echo "GATE-EXIT=$?"

   `GATE-EXIT=0` and `rg -c '^FAIL' "$TMPDIR/tot-gate.out"` prints
   nothing and exits 1 (zero FAIL lines). This is the M7 battery,
   unchanged (`dev/M8-PLAN.md:2273-2283`). P0 touches one file,
   `dev/M9-PLAN.md`, and adds no gate leg and no test, on the `2aa189c`
   precedent; its own battery run is the same four commands, and a green
   run at P0 confirms the plan commit moved no code and no gate line,
   not that P0 raised the PASS count.

2. **The exit PASS count is reached, non-vacuously.** `rg -c '^PASS'
   "$TMPDIR/tot-gate.out"` equals the stage's own exit slice count, and
   the wrapper's own `PASS=` line, when the build workflow's wrapper
   runs the same battery, equals the slice plus 4 (carried ruling
   C-A14). The chain, all counts ESTIMATE and re-measured per stage: P0
   441 to 441 (wrapper 445 to 445, no leg, so the delta is 0 by
   construction and is not itself a failure); Stage A 441 to 442
   (wrapper 445 to 446), delta 1, which is 1 marker plus 0 suite cases;
   Stage B 442 to 447 (wrapper 446 to 451), delta 5, which is 3 markers
   plus 2 suite cases, both landing in the surface suite; Stage C 447 to
   450 (wrapper 451 to 454), delta 3, which is 2 markers plus 1 suite
   case, landing in whichever suite that stage's own interface case
   lands in. Non-vacuous means the delta matches that stage's own
   markers-plus-cases total, not just the raw count, and that stage's
   own new marker names are present and are the only new `PASS-M9<L>`
   names for that stage's letter `<L>`, checked with `rg -o
   'PASS-M9<L>-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | sort
   -u | wc -l` equal to the count that stage's own section reserves. A
   PASS count that moved by the right total but under the wrong names
   has not closed the stage; it has closed a different one.

3. **Every new leg carries its mutation proof, and no two share one
   (R10).** For a stage with legs (A, B, C; not P0, which has none):
   `rg -c 'Marker: PASS-M9<L>-' /Users/oobi/Documents/tot/dev/M9-PLAN.md`
   equals `rg -c '^\s*MUTATION:' /Users/oobi/Documents/tot/dev/M9-PLAN.md`
   for that stage's own marker block, and `rg -o '^\s*MUTATION:.*'
   /Users/oobi/Documents/tot/dev/M9-PLAN.md | sort | uniq -d` prints
   nothing for that stage's block, so no single edit proves two
   markers. Each proof is confirmed live: the named edit turns the
   leg's `echo PASS-<NAME>` line into its `FAIL-<NAME>` arm, and
   restoring the edit returns an md5-identical file, `md5 -q <path>`
   equal before and after (the R10 shape, `dev/M7-PLAN.md:846-872`,
   carried unchanged into M9).

4. **The stage review checklist is clean.** The stage's own section
   states the exact files it touches; this gate re-reads those files
   against the house conventions this plan inherits: no `raise`,
   `failwith`, `assert` or `Option.get`; no `match` on an `Option` or a
   `Result` value, a combinator used instead; every `match` on a
   `Term.t` or a `Syntax.t` lists every constructor, no wildcard arm; no
   `match` on a bool, a `match () with | () when ... -> ...` guard used
   instead; total indexing only, no bare division; no loop keyword, a
   fold, map or filter used instead. P0 touches only `dev/M9-PLAN.md`
   and Stage A touches only `SPEC.md`, `dev/gates.sh` and
   `dev/M9-BUILD-LOG.md`, prose and shell files the OCaml checklist does
   not reach. Stage C's twelve `surface/*.mli` files carry signatures,
   not executable bodies, so the `raise`/`failwith`/`match`-shape items
   apply vacuously there and the substantive check is that every
   exported value's type is total and every export is a value already
   defined at its cited `surface/cache.ml` line, never a new
   constructor. Stage B's one new `.tot` file is not OCaml and the
   checklist does not reach it either; the file that does carry OCaml
   changes, `dev/gates.sh`, is a shell script and is checked instead
   against the leg shape at `dev/gates.sh:2507-2529` (below).

5. **Conflict notes are booked.** For every literal that stage measured
   and found different from its ESTIMATE, `dev/M9-BUILD-LOG.md` carries
   a `**Conflict note C-<L><n> (date): ...**` paragraph with all six
   parts the conflict-note protocol names, checked with `rg -c
   '^\*\*Conflict note C-<L>' /Users/oobi/Documents/tot/dev/M9-BUILD-LOG.md`
   at least 1 for that stage's letter. A stage that measured no
   difference from its ESTIMATE books no note and says so; a stage that
   measured a difference and booked no note has not closed. Stage B's
   own three literals named in R-Q4, `m7a_files` (104), `m7a_green`
   (62) and the transcript digest, are the likeliest source of a
   conflict note in this milestone, since R-Q4 itself predicts they may
   move when the new example lands.

### 8.2 The M9 exit gate

M9 closes only when every one of the following holds, on top of every
stage's own 8.1 gate. This is the whole-milestone version of
`dev/M8-PLAN.md`'s own section 8.2 (`dev/M8-PLAN.md:2337-2461`), read
against a plan commit plus three stages instead of four stages, and with
no early-stop branch: no ruling in this milestone shrinks it mid-run the
way M8's own R-Q7 could, so P0 and all three stages close in order or the
milestone has not closed. Each stage's own 8.1 gate is satisfied before
the next stage opens; no stage opens on a red predecessor.

- **P0 and all three stages closed.** P0 lands the plan commit alone;
  Stage A, Stage B and Stage C each close under 8.1 in that order. The
  one ruling that can change stage boundaries mid-run is R-Q5's overrun
  rule (8.4 below), which can turn Stage C into Stage C plus a Stage D;
  it never removes a stage.

- **The chain is reconciled against the measured wrapper count.** The
  ESTIMATE chain, recounted against the stage slices as fixed, is 441 to
  441 to 442 to 447 to 450 slice, wrapper +4 at every boundary, 445 to
  445 to 446 to 451 to 454 (the stage table this plan states in its own
  earlier section, which matches `/Users/oobi/Documents/tot-m9-ratifications.md:7`
  verbatim). One marker plus zero suite cases at Stage A, three markers
  plus two suite cases at Stage B, two markers plus one suite case at
  Stage C: six markers plus three suite cases is +9, and 441 + 9 = 450
  slice, 454 wrapper. At M9 close, every cell in that row is replaced by
  its measured value, with the command that produced it, the same
  count-honesty rule M7's graft G8 states (`dev/M7-PLAN.md:793-797`), and
  `dev/M9-BUILD-LOG.md` carries the final chain the way
  `dev/M8-BUILD-LOG.md` carries M8's (`dev/M8-BUILD-LOG.md:2561-2563`).
  The wrapper offset of 4 (C-A14) is checked at the final boundary the
  same way it is checked at every stage boundary: the wrapper's own
  `PASS=` line minus `rg -c '^PASS' "$TMPDIR/tot-gate.out"` equals 4.

- **The `PASS-M9` marker list is unique and complete.** The six reserved
  names, recounted from the stage slices' own `Marker:` lines, are
  `PASS-M9A-EXIT-STAMP`, `PASS-M9B-CD-PORT`, `PASS-M9B-DEMAND-ORACLE`,
  `PASS-M9B-REGEX-FIDELITY`, `PASS-M9C-SURFACE-MLI-COVERAGE`,
  `PASS-M9C-SURFACE-INTERNAL` (one plus three plus two). Comments may
  repeat these names, so extract only success echoes and use that output
  for both the count and the uniqueness check:

      rg --no-filename -o '^\s*(?:&&\s*)?echo (PASS-M9[A-C]-[A-Z0-9-]+)\b' -r '$1' /Users/oobi/Documents/tot/dev/gates.sh

  Pipe that output through `sort -u | wc -l` for the total (6), and
  separately through `sort | uniq -d` for duplicates (empty). Compare
  the sorted unique names with the six reserved names above; a different
  name with the same count is a failure. Before M9 opens, `rg -o
  'PASS-M9[A-Z0-9-]*' /Users/oobi/Documents/tot/dev/gates.sh` prints
  nothing, measured in the working tree at HEAD `5538927` (carried
  ruling R11), so the count above starts from zero and not from a
  collision. The plan-side count is stated separately from the built-
  tree count: the stage slices themselves name six distinct `PASS-M9`
  identifiers, scoped to each slice's own `Marker:` line (`rg -o
  --no-filename '^\s*(?:[0-9]+\. )?Marker: (PASS-M9[A-C]-[A-Z0-9-]+)' -r
  '$1' /Users/oobi/Documents/tot-m9-plan/slices/*.md | sort -u | wc -l`,
  never `-oh`, because `-h` is `--help` in ripgrep 15.1.0 and that flag
  prints the ripgrep usage text instead of a count). The value 6 is the
  same total the six-name list above carries, scoped to the plan's own
  slice text, not to `dev/gates.sh`.

- **No leg is without a proof.** Across the whole assembled plan, `rg -c
  '^\s*(?:[0-9]+\. )?Marker: PASS-M9' /Users/oobi/Documents/tot/dev/M9-PLAN.md`
  equals `rg -c '^\s*MUTATION:' /Users/oobi/Documents/tot/dev/M9-PLAN.md`,
  both anchored at the head of the line so a mechanical count cannot
  miss a numbered list item or a mid-line echo of the word, and both
  print 6, not a hard-coded number carried over from M8's eleven. The
  companion edit-site check, `rg -o -r '$1' '^\s*MUTATION: ([A-Za-z0-9_/.:-]+),'
  /Users/oobi/Documents/tot/dev/M9-PLAN.md | sort | uniq -d`, prints
  nothing: unlike M8's `surface/elab.ml:401` repeat (R4-2b), no M9 leg
  names a shared edit site, because R-Q2's repair drops the two kernel
  mutations proposal 3 offered for Stage B in favour of the two probe
  fixtures, and the M8-precedent overlap at `lib/check.ml:958-959` versus
  `:959` does not recur here. The old text-equality line stays as a
  second, weaker check, head-anchored the same way: `rg -o
  '^\s*MUTATION:.*' /Users/oobi/Documents/tot/dev/M9-PLAN.md | sort |
  uniq -d` prints nothing, so no mutation proof is reused verbatim
  across markers either, and no marker in the plan lacks one (R10).

- **No em dash character (Unicode U+2014) in the plan or the log.** `rg
  -c $'\u2014' /Users/oobi/Documents/tot/dev/M9-PLAN.md` prints nothing
  and exits 1; the same command against
  `/Users/oobi/Documents/tot/dev/M9-BUILD-LOG.md` prints nothing and
  exits 1. This is the M7 and M8 precedent, re-run: the same pattern
  against `dev/M8-PLAN.md` and `dev/M8-BUILD-LOG.md` prints nothing and
  exits 1 in the working tree today (`rg -c $'\u2014'
  /Users/oobi/Documents/tot/dev/M8-PLAN.md` measured 0), confirming the
  house rule already holds for the files M9 extends.

- **SPEC.md and dev/M9-BUILD-LOG.md are updated.** `SPEC.md` section 6,
  "Known debts (deliberate)" (`SPEC.md:2042`), gains a dated "Known debts
  entering M10" paragraph in the shape of the "Known debts entering M9"
  paragraph Stage A itself writes, naming C1 and C2 as the two debts M9
  carries forward, each with the one-line reason 8.5 states below, and
  recording the R-Q3 order (C2 first and soaks, then C1) for the M10
  brief to answer. Debt entry 11 (`SPEC.md:2668`, "Cumulativity or an
  `Eq1` layer. CARRIED. No measured demand.") keeps its heading and its
  "CARRIED" disposition and gains one clause: the M9 instrument produced
  a measured reading of 2, which is not itself demand for entry 11 and
  is not a repeal (R-Q7). `SPEC.md`'s decision log carries one dated
  entry per stage. `dev/M9-BUILD-LOG.md` holds one stage report per
  closed stage, every mutation proof with its flip and its md5-identical
  restore, the forced-rewrite count of 2 that Stage B measures (R-Q2),
  and the final measured chain in the shape the wrapper-offset item
  above names.

### 8.3 The acceptance test: the demand instrument

The demand instrument of Stage B is what proves the milestone. Every
other stage repairs a debt or closes a gap the tree already carries;
Stage B alone produces evidence M10 did not have before, which is why
the design verdict calls it "the only candidate that produces evidence
for M10 rather than consuming it" (`/Users/oobi/Documents/tot-m9-design-verdict.md:142-143`).
`PASS-M9B-DEMAND-ORACLE` pins the forced-rewrite reading at 2, recorded
in `dev/M9-BUILD-LOG.md`: the two pre-rewrite spellings the port's
history contains are still refused at HEAD by exit code and by whole
line, `wordEnd failed the structural termination guard` and `invalid
constructor mkRule: negative or non-uniform occurrence of Rule` (R-Q2).

Under R-Q2 a reading of 0 leaves C1 and C2 UNRANKED for M10; it retires
neither. No instrument in one milestone retires a debt SPEC records, so
a 0 reading does not shrink the "Known debts entering M10" paragraph
8.2 names, and it does not remove C1 or C2 from that paragraph either.
The exit gate records the reading Stage B measured and never the
reading a stage author wanted: if the port's build turns up a third
forced rewrite, or only one, `PASS-M9B-DEMAND-ORACLE`'s own value and
`dev/M9-BUILD-LOG.md`'s recorded count both take the measured number,
a conflict note is booked under 8.1 item 5 for the literal that moved,
and the M10 brief inherits the measured ranking consequence, not the 2
this plan predicts. This plan's own reading of 2 is PREDICTED, not
measured; the build workflow is what turns it into a measured one.

### 8.4 The overrun rule

Stage C covers all twelve `surface/*.mli` interfaces in one stage
(R-Q5). `fd -e ml --max-depth 1 . /Users/oobi/Documents/tot/surface | wc
-l` and `fd -e mli --max-depth 1 . /Users/oobi/Documents/tot/surface |
wc -l` read 12 and 0 at HEAD, measured, so the stage opens against a
gap of 12. If Stage C overruns, `surface/elab.ml` alone splits into a
Stage D; no other one of the twelve files is named as a candidate for a
split, because `surface/elab.ml` is the file the design verdict itself
sizes as the largest, 1025 lines and 36 top-level lets
(`/Users/oobi/Documents/tot-m9-design-verdict.md:449-451`). Wherever the
coverage leg lands, in Stage C alone or split across Stage C and Stage
D, it asserts 12 and 0 gap moved to 12 and 12 files with gap 0, and it is
never weakened below 12: an overrun does not shrink the count of
interfaces the milestone commits to writing, it only moves the boundary
of the stage that finishes writing them.

### 8.5 Deliberate non-changes

Five changes this milestone does not make, each with the one-line reason
the exit gate checks against.

- **No kernel rule lands.** Reason: R-Q3 defers both C1 and C2 to M10,
  in the order C2 first and soaks, then C1, so no M9 stage edits
  `lib/check.ml:1969`'s `no_occur dom` conjunct or `lib/totality.ml`'s
  rule enumeration. The M10 brief answers the double-flip sign lattice
  of finding A2-F1 before either rule is costed; M9 records this order
  in `dev/M9-PLAN.md` and edits neither file.

- **`lib/interp.ml:92-95` and `surface/run.ml:117-120` stay untouched.**
  Reason: R-Q6 keeps C5 to its SPEC two-horn record with no code half.
  `lib/interp.ml:92-95` carries the `guard` type's `Frozen` arm and
  `surface/run.ml:117-120` carries the `Quantity.Zero` match-guard arm
  that reads it; `PASS-M7E-SPEC-CITATIONS`
  (`dev/gates.sh:3930-3931`) already counts both sites, so no new marker
  is owed and no M9 stage adds one.

- **`Cache.format_version` stays 10, and no jarr migration lands.**
  Reason: carried M8 R-Q6. `surface/cache.ml:118` is `let format_version
  : int = 10` at HEAD, and the cache key already folds the prelude
  source into its digest (`surface/cache.ml:343-346`, `key`), so no M9
  stage, including Stage C's interface sweep, needs the version constant
  to move.

- **Both fence legs stay green, including `PASS-M6A-FENCE-COVARIANT`.**
  Reason: carried M8 R-Q2, since R-Q3 above keeps C2 out of M9 and no
  nested-inductive rule lands. At HEAD `5538927` the fence pair's comment
  header sits at `dev/gates.sh:2577-2581` ("Gate A (vi)+(vii), the
  positivity-fence tripwires"), with `echo PASS-M6A-FENCE-COVARIANT` at
  `dev/gates.sh:2587` and `echo PASS-M6A-FENCE-CONTRAVARIANT` at
  `dev/gates.sh:2595`; the address `dev/gates.sh:2531-2535` that the
  ratification and the M8 plan's own R-S1 note once used for this pair
  is stale at this reference state, because M8 Stage D's own legs shifted
  every line after it forward, and at HEAD `5538927` that span instead
  falls inside the body of `PASS-M6A-ACC-GUARD-REJECTED`. Both legs keep
  asserting the exact rejection message for `test/fixtures/nested-pos.tot`
  and `test/fixtures/nested-neg.tot` through every stage of this
  milestone; the per-stage review checklist in 8.1 item 4 re-confirms
  this pair is still in the `^PASS` set at every stage's own battery run.

- **No third absolute `awk 'NR=='` pin is added.** Reason: A3-F5. The
  two pins already shipped, `awk 'NR==66' lib/totality.ml` and `awk
  'NR==2066' lib/check.ml` at `dev/gates.sh:3927-3928`, stay the only
  two; Stage A's own SPEC-repair leg reads its module counts with a
  tree-side `fd` conjunct instead of a third line-number pin, which is
  the A3-F6 repair the design verdict adopts.

Section 8 ends.

# 9. Risks and the M10 hand-off

Citation rule for this section: every `<path>:<line>` below is read from
the reference state, HEAD 5538927, with `awk NR==` or `rg -n` against the
working tree at /Users/oobi/Documents/tot.  `git -C /Users/oobi/Documents/tot
status --porcelain` and `git -C /Users/oobi/Documents/tot diff --stat`
both printed nothing, so the tree equals HEAD and every citation below is
HEAD behaviour, not a diff hunk.  This section adds no new PASS-M9
marker.  Its early signals name markers Stage A, Stage B and Stage C
define; the marker names below are read from the ratified stage table
(dev/M9-PLAN.md sections 4 through 7) and are not redefined here.

## 9.1 Risks

Each block names the risk, the reading that makes it live, the early
signal a build should watch, and the rollback.

### Risk 1: Stage B's port forces a rewrite count other than 2

Reading that makes it live.  R-Q2 pins the demand instrument's reading to
2 at HEAD: the two pre-rewrite spellings of the cd-prefix-guard.py port
are refused by `wordEnd failed the structural termination guard` and by
`invalid constructor mkRule: negative or non-uniform occurrence of Rule`,
both exit 1, under a kernel Stage B does not edit (`type rule =
Structural` at lib/totality.ml:20, `strict_pos` at lib/check.ml:1964-1977,
unchanged).  Stage B's builder re-derives a 382-line Python source into
tot syntax by hand.  Any structural difference in how the word-end walk
or the rule table is spelled, one extra nested match arm, a differently
shaped accumulator, a table laid out flat instead of nested, can raise or
lower the count of spellings the kernel actually refuses before the
shipped, checking file is reached.  A reading of 0 or of 3 is live the
moment the builder's first draft diverges in shape from the two probes
R-Q2 quotes.

Early signal.  dev/M9-BUILD-LOG.md's own count paragraph disagreeing with
PASS-M9B-DEMAND-ORACLE's two exact asserted message lines, or that
marker's FAIL arm printing a measured count other than 2.

Rollback.  Revert the Stage B commit.  The conflict note, in the C-D3
shape, records the predicted reading (2) against the measured one, and
names which pre-rewrite spelling produced the different count.

Answers ruling: R-Q2.

### Risk 2: the corpus chore misses a literal the reseal moves

Reading that makes it live.  R-Q4 commits Stage B's example under
examples/, tracked corpus, so it enters dev/gen-m5e-transcript.sh:13's
glob (`for f in examples/*.tot test/fixtures/*.tot`) unconditionally.
Until the reseal lands in the same commit, the whole-file diff at
dev/gates.sh:2486 (`diff -q "$ROOT"/dev/m5e-default-transcript.txt
"$m5e_scratch"/m5e-now.txt`) and the block-count check at
dev/gates.sh:3259 (`[ "$m6e_blocks" -eq "$m6e_files" ]`) both go red, and
the settle-budget leg's own recipe at dev/gates.sh:3614-3621 (`[
"$m7a_files" -eq 104 ] && [ "$m7a_green" -eq 62 ] && [ "$m7a_digest" =
9278f6b7034f2f65b6d789e9e1d74a90 ]`) may need one or more of its three
literals rewritten.  dev/gates.sh:3614-3617's own comment already records
these exact three literals walking once before, when the M7 Stage E
oracle fixtures joined the depth-1 corpus (101 to 104 files, digest
9cb630c7ccdc6c30b335b7355dc83a82 to 9278f6b7034f2f65b6d789e9e1d74a90), so
a fourth walk on the same leg is precedented, not a new failure mode.

Early signal.  The block-count leg at dev/gates.sh:3259 red, the
whole-file diff at dev/gates.sh:2486 non-empty, or the settle-budget
leg's FAIL arm printing measured files, green or digest values that
disagree with 104, 62 and 9278f6b7034f2f65b6d789e9e1d74a90.

Rollback.  Revert the Stage B commit; the example and its reseal land
together, so a rollback removes both in one revert.  The conflict note
names which of the three literals moved and the value each printed.

Answers ruling: R-Q4.

### Risk 3: Stage C's narrow-export leg hides a Cache internal the surface suite reads

Reading that makes it live.  test/surface.ml reaches into five
surface/cache.ml internals directly, `Tot_surface.Cache.cache_dir` at
test/surface.ml:1727, `Tot_surface.Cache.magic_width` and
`.version_width` at test/surface.ml:1767, `Tot_surface.Cache.digest_width`
at test/surface.ml:1768, and `Tot_surface.Cache.header_width` at
test/surface.ml:1782, reading the definitions at
surface/cache.ml:129 (`magic_width`), :130 (`version_width`), :131
(`digest_width`), :133 (`header_width`) and :170 (`cache_dir`).  If
Stage C's surface/cache.mli omits any one of the five, the omission is
not a gate red: it is a `dune build` compile error across the whole
158-case surface suite, because the missing `val` makes the reference
unbound, before any PASS or FAIL echo can run.

Early signal.  A build failure naming one of magic_width, version_width,
digest_width, header_width or cache_dir as unbound in test/surface.ml, or
PASS-M9C-SURFACE-INTERNAL's own export count reading 5 instead of 6.

Rollback.  Revert the Stage C commit.  The conflict note names which of
the five internals surface/cache.mli omitted and quotes the compiler's
unbound-value line.

Answers finding: A3-F4 (ACCEPT, design-verdict section 4).

### Risk 4: Stage C overruns and the coverage leg is weakened to land it

Reading that makes it live.  The twelve-file surface/*.mli sweep is
uneven: `wc -l surface/*.ml` totals 4479 lines, and surface/elab.ml alone
is 1025 lines with 36 top-level `let` bindings (`rg -c '^let '
surface/elab.ml`), against surface/run.ml's 683 and surface/parser.ml's
720.  A stage sized against eleven small-to-medium files and one large
one can overrun on the large one alone, and the schedule pressure that
follows is what makes shrinking PASS-M9C-SURFACE-MLI-COVERAGE's asserted
count live.

Early signal.  Stage C's review round running long with surface/elab.mli
still undrafted while the other eleven interfaces are done, or a draft of
PASS-M9C-SURFACE-MLI-COVERAGE asserting a count under 12 against either
the surface/*.ml or the surface/*.mli basename set.

Rollback.  Per R-Q5: revert the Stage C commit as drafted, split
surface/elab.mli into its own Stage D commit, and keep
PASS-M9C-SURFACE-MLI-COVERAGE asserting 12 and 12 with gap 0 across the
split, never a smaller number.  The conflict note names surface/elab.ml
as the file that moved to the new stage.

Answers ruling: R-Q5.

### Risk 5: a lib/ file lands mid-Stage A and reddens the tree-side conjunct

Reading that makes it live.  PASS-M9A-EXIT-STAMP's tree-side conjunct
reads `fd -e ml --max-depth 1 . lib | wc -l` and `fd -e mli --max-depth 1
. lib | wc -l`, both measured 18 at HEAD, against the literal
SPEC.md:1932 states.  None of M9's three stages touches any lib/ file
(Stage A edits SPEC.md, dev/gates.sh and dev/M9-BUILD-LOG.md, Stage B
adds examples/guard-cd.tot, the dev/m9b/ fixtures, gate legs and two
suite cases (per R-Q1 and R-Q4) and the SPEC debt-entry-11 clause (per
R-Q7), and Stage C writes surface/*.mli, two gate legs, one suite case,
its dev/M9-BUILD-LOG.md entries and one SPEC.md paragraph), so the
conjunct is a pure external-interference detector.  The reading is live
only if something outside this plan's three stages, a concurrent branch,
a stray generated file, or a manual edit, adds or removes a lib/.ml or
lib/.mli between Stage A's commit and the gate run that checks it.

Early signal.  PASS-M9A-EXIT-STAMP's FAIL arm printing a measured count
other than 18 for either extension, with no Stage A diff touching lib/.

Rollback.  Revert whatever landed the extra or missing lib/ file; Stage
A's own commit needs no revert if the interference came from outside
this plan's three stages.  The conflict note names the intruding lib/
path and whether it was added or removed.

Answers finding: A3-F6 (ACCEPT, the fold that keeps a tree-side conjunct
inside PASS-M9A-EXIT-STAMP instead of a second, authorship-only leg) and
A3-F5 (ACCEPT, tempered: the absolute-line pin A3-F5 flagged, `awk
'NR==1913' lib/check.ml`, is dropped in favour of this content-and-tree
cross-check, so no third `awk 'NR=='` pin joins the two already shipped
at dev/gates.sh:3927-3928).

## 9.2 Rollback discipline

Each stage, A through C, is one commit.  A rollback is a `git revert` of
that one commit, paired with a conflict note in the C-D3 shape that
states what was predicted, what the build measured, and which risk block
above the failure matches.  No stage's rollback touches a sibling
stage's commit.  Stage A touches SPEC.md, dev/gates.sh and
dev/M9-BUILD-LOG.md; Stage B touches examples/guard-cd.tot, the three
dev/m9b/ fixtures, the resealed dev/m5e-default-transcript.txt,
dev/gates.sh, test/surface.ml, dev/M9-BUILD-LOG.md and SPEC.md (the
debt-entry-11 clause, per R-Q7; the port is R-Q1 and the corpus commit
with its reseal is R-Q4); Stage C touches surface/*.mli, dev/gates.sh,
test/surface.ml, dev/M9-BUILD-LOG.md and SPEC.md (the "Known debts
entering M10" paragraph); and none of the three touches lib/.  Four
files are shared between stages, and one separation rule covers all
four: each stage's dev/gates.sh legs are appended after the previous
stage's at the dev/gates.sh:4524 anchor, each stage's SPEC.md edit is
its own hunk (Stage A's four edits at SPEC.md:2022-2040 and :2044-2045,
the entry-6 citation and the file's end, Stage B's one clause at
SPEC.md:2668, Stage C's one paragraph appended to section 6 after Stage
A's), Stage B appends its two test/surface.ml cases at the list's end
while Stage C inserts its one case after the cache round-trip tuple, and
each stage's dev/M9-BUILD-LOG.md entries are its own appended block, so
a revert of one stage's commit removes only that stage's hunks and
leaves its siblings' in place, with the one exception below.  Two hunks
in that enumeration are adjacent rather than separated: Stage A's "Known
debts entering M9" paragraph and Stage C's "Known debts entering M10"
paragraph sit next to each other at the end of SPEC.md, so a Stage A
revert after Stage C has landed is expected to conflict on that tail.
The resolution is mechanical, delete Stage A's paragraph and keep Stage
C's, and it is recorded in the conflict note this rollback already
requires.  A Stage A revert leaves Stage B and Stage C's commits
standing on their own merits if either already landed; a Stage B revert
removes the ported example and its transcript reseal together, per Risk
2, since the two are one commit; a Stage C revert, or a Stage C split
into a Stage D under R-Q5, never touches Stage A or Stage B's gate legs
or suite cases.

## 9.3 M10 hand-off

### C2: nested inductives and the polarity rule, lands FIRST

Ruling: R-Q3.  In M10, C2's polarity rule lands FIRST and soaks (the M8
R-Q2 wording), then C1.  The M10 brief answers the double-flip sign
lattice of finding A2-F1 before any rule is costed.  At HEAD
lib/check.ml:1969 is `| Term.Pi (_q, _x, dom, cod) -> no_occur dom &&
strict_pos (depth + 1) cod`, a domain rule with no sign at all.  A signed
arm that admits a flipped occurrence in the domain returns to `Pos` after
two flips, and the shape it would then accept is refused today:
/Users/oobi/Documents/tot-m9-probes/attack-2/launder-double-neg.tot
prints `invalid constructor mkdl: negative or non-uniform occurrence of
Dl`, exit 1.  Neither surviving fence leg discriminates that shape, since
both are single flips: PASS-M6A-FENCE-COVARIANT (dev/gates.sh:2582-2588,
echo at dev/gates.sh:2587) and PASS-M6A-FENCE-CONTRAVARIANT
(dev/gates.sh:2590-2596, echo at dev/gates.sh:2595) each test one layer,
never a double flip.  Both fence legs, the shared block at
dev/gates.sh:2578-2596, stay green through M9, and M9 edits no kernel
rule (carried M8 R-Q2).  M9's own instrument adds a third tripwire in the
same family: PASS-M9B-DEMAND-ORACLE's nested control,
`p4-rule-table-nested.tot:2:1: invalid constructor mkRule: negative or
non-uniform occurrence of Rule`, is refused today and its stated mutation
is the `strict_pos` widening itself (lib/check.ml:1969), so the day C2
lands, three legs redden together and the design re-opens once.

A polarity walk over foreign heads with no visited set does not
terminate on a self-referential family: `List` mentions itself in its own
`cons` field, `data List (0 A : Type 0) : Type 0 := | nil : List A |
cons : A -> List A -> List A` (stdlib/prelude.tot:6), so the M10 brief
must fix a visited set or a budget from the rule's first line, not as a
repair after a hang.  The rule also needs a reporting channel the kernel
does not have today: every `Sys.getenv_opt` site at HEAD is under
surface/, lib/ has none, so a lib-side polarity walk cannot report
through a `TOT_*` variable without new plumbing through surface/run.ml
and bin/tot.ml.

Answers finding: A2-F1 (ACCEPT, the finding that decides the order) and
A2-F6 (ACCEPT, the fixpoint-iteration mutation-proof gap the M10 brief
must close before any leg pins the rule).

### C1: the WF package behind an accessibility-shape selector, after C2

Ruling: R-Q3 (order) and the carried M8 R-Q1 deferral.  C1 lands after
C2, because the soundness argument for an accessibility-shape selector is
a loan against the one-level fence at lib/check.ml:1964-1977, `strict_pos`,
and C2 is the candidate that moves that fence; C1 before C2 prices a
selector against a fence that is about to change under it.  The
bad2.tot shape question waits with C1.  Whether any wf-spelled descent
may accept the shape at test/fixtures/bad2.tot:1-2 (`data T : Type 0 :=
| mk : (Nat -> T) -> T` and `def rec bad2 : T -> Nat := fun t => match t
with | mk g => bad2 (g zero) end`) is a user ruling, not a panel or
builder ruling, and PASS-M6A-INFINITARY-REJECTED (dev/gates.sh:2545-2551)
exists, in the gate's own comment, to make the M5 deletion "irreversible
by accident" (dev/gates.sh:2541-2544).  M9's own instrument measured no
benefit from opening it now: the demand instrument's C1 number is 0 (the
faithful word-end walk is refused, a `Nat`-fuel spelling is accepted, and
the token-list spelling is accepted), and the blocking gap is a missing
`String` decomposition in the prim table, `("stringLength", "String ->
Int", Prim.String_length)` at surface/bootstrap.ml:101 and
`("stringSlice", ...)` at surface/bootstrap.ml:139, not a missing
admission rule.  Per R-Q2, a reading of 0 leaves C1 UNRANKED for M10, not
retired.

Answers finding: A1-F4 (ACCEPT, the selector needs data `Totality.guard`
does not receive) and A3-F3 tempered (ACCEPT, the demand instrument reads
0 for C1 for the reason stated above, not because C1 is settled).

### C7: cumulativity or an Eq1 layer, rejected for M9

Ruling: R-Q7.  SPEC.md:2668 keeps its debt entry 11, "11. Cumulativity or
an `Eq1` layer.  CARRIED.  No measured demand.", byte for byte, with an
annotation that the M9 instrument adds a measured reading (2, from R-Q2)
rather than a repeal.  Cumulativity is not re-opened until a hook port or
example produces a `Type 1` equation the tree actually needs.  The one
probe that tried to manufacture a cheap tripwire for C7 is itself
refuted: widening stdlib/prelude.tot:55's `Eq` declaration past `Type 0`
does not admit a `Type 1` equation, it breaks the whole prelude load,
`prelude: 55:1: inductive Eq: index b lives above the declared universe`,
exit 1, on a probe file that never mentions `Eq`.  So no cheap gate leg
can watch for C7's demand rising either; the debt stays dated and cited
in SPEC rather than closed, and a real fix is not local to one
declaration, since every derived combinator, `subst0`, `sym0`, `trans0`
and `cong0` at stdlib/prelude.tot:92-94, inherits the `Type 0` carrier.

Answers finding: A3-F1 (ACCEPT, the C7 mutation proof is refuted by
probe) and ruling R-Q7.

### Residual debt M9 does not take

- C5's code half.  lib/interp.ml:92-95, the three-constructor `guard`
  type carrying `Frozen`, and surface/run.ml:117-120, the `Quantity.Zero`
  arm of `Run.compute_guard` (`| () when Eterm.mentions name def_e ->
  Interp.Frozen | () -> Interp.Unguarded`), stay untouched (R-Q6).
  PASS-M7E-SPEC-CITATIONS (dev/gates.sh:3930-3931) already counts both
  sites, `m7e_frozen` against lib/interp.ml and `m7e_zeroarm` against
  surface/run.ml, so the SPEC-only two-horn record M9 Stage A writes adds
  no new marker.  It waits for a milestone that opens lib/interp.ml,
  which is C2's jarr migration.
- The jarr migration.  Eight constructor names are hard-wired at
  surface/bootstrap.ml:66-73 (`jnull`, `jbool`, `jnum`, `jstr`,
  `jarrNil`, `jarrCons`, `jobjNil`, `jobjCons`) and reused as `VCon` tags
  in lib/interp.ml, for example `Some (VCon ("jarrCons", [ hd; tl ]),
  rest3)` at lib/interp.ml:402.  Deferred with C2 and behind it, per
  R-Q3's "lands FIRST and soaks" wording.  Nothing in M9 needs it: the
  duplicated cons-cell spine, `def rec jsonToList : Json -> List Json`
  at stdlib/prelude.tot:49, already serves the one array a hook port
  reads.
- Any `Cache.format_version` bump.  `let format_version : int = 10`
  stays at surface/cache.ml:118, unchanged (carried M8 R-Q6); the two
  pins that read it stay green (dev/gates.sh:3880-3888).  No M9 stage
  moves a prelude-level representation; Stage C's PASS-M9C-SURFACE-INTERNAL
  exports the constant through surface/cache.mli, it does not change it.
  The change that would reopen the question is still C2's jarr
  migration.
- The regex fidelity gap.  PASS-M9B-REGEX-FIDELITY pins a DIVERGENCE, not
  a candidate's demand: the ported classifier and Python's source
  disagree on one anchored pattern, `ASSIGN_WORD=TRUE
  NOT_A_PROGRAM=FALSE`, because `Str.regexp` does not translate `(?:` to
  a non-capturing group (`regex_compile` at lib/interp.ml:541-542).  The
  gap belongs to no candidate, not C1, C2 or C7, and per the ratified
  reading rule it enters the M10 list on its own merits rather than being
  folded into one of the three deferred items above.

Section 9 ends.
