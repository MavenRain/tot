# M8 build plan: the local-aware capture source, the prelude re-spell, reporting, and the lib/ .mli sweep

## 1. Purpose and entry state

M8 closes the M7 elaborator hand-off.  It builds a local-aware capture
source for the argument-driven hole pass, uses the stdlib/prelude.tot:94
congruence motive as the acceptance test of that source, reports three
residual debts M7 left open, and sweeps lib/ interface files last.  M8
adds no admission rule to lib/ and does not touch the well-founded
recursion package or the nested-inductive fence.  This document plans
four stages, A through D, against M7's five.

The reference state for every citation and every probe in this plan is
the tot working tree at HEAD `8cf0b8b`, M7 Stage D, PLUS the unstaged M7
Stage E diff that a peer session lands before M8 opens.  A citation from
a line the Stage E diff touches is marked "unstaged Stage E"; every other
citation is read at HEAD through `git -C /Users/oobi/Documents/tot show
HEAD:<path>`.  This plan does not build, run dune, or run any binary
under /Users/oobi/Documents/tot/_build.  Every number about the gate
battery is measured with rg against dev/gates.sh or is marked ESTIMATE.

### 1.1 Ratification

The user ratified the M8 design verdict on 2026-09-05
(/Users/oobi/Documents/tot-m8-ratifications.md).  The seven rulings below
outrank the verdict, the proposal, and all three attacks.  Each is quoted
verbatim, with the one consequence it carries for this plan.

**R-Q1**, verbatim: "DEFERRED to the M9 panel.  No wf descent may accept
the shape of test/fixtures/bad2.tot in M8; C1 is out of M8."
Consequence: this plan carries no Stage and no marker for the
well-founded recursion package, and no fixture in M8 may be a
`wf`-spelled copy of test/fixtures/bad2.tot.

**R-Q2**, verbatim: "C2 is deferred to M9.  When taken, the
nested-inductive rule lands FIRST and soaks (the M6 pattern); both fence
legs, including PASS-M6A-FENCE-COVARIANT (dev/gates.sh:2531-2535), stay
green through M8."  The line number is the ratified quote as written,
citing HEAD; per R-S1, in the staged tree the same leg's comment header
sits at dev/gates.sh:2542-2546, its echo at dev/gates.sh:2552, and the
staged dev/gates.sh:2531-2535 now holds PASS-M6A-DEEP2-REJECTED.
Consequence: no stage in this plan touches the nested-inductive fence,
and PASS-M6A-FENCE-COVARIANT is a standing tripwire every stage's
battery run must keep green.

**R-Q3**, verbatim: "the lib/ .mli sweep is in M8 as Stage D, last and
lib-only.  It is the cut if M8 must shrink."  Consequence: the sweep is
Stage D, the interface sweep covers lib/ only, and it is the first stage
a shrinking build drops. The reviewed D1-D2 boundary repair also owns the
necessary caller and white-box test rewires outside lib/.

**R-Q4**, verbatim: "Stage D adds a NEW narrow kernel entry point in
lib/global.ml for the def rec provisional self-entry and re-points
surface/run.ml:218-230 at it.  Global.add (lib/global.ml:102) stays
unexported.  The PASS-M8D-KERNEL-INTERNAL leg asserts that
lib/global.mli has no val add."  Consequence: Stage D's boundary repair
is fixed by this ruling, not left to the Stage D builder, and the
PASS-M8D-KERNEL-INTERNAL marker name is binding.

**R-Q5**, verbatim: "item 8 is Option A.  Report hole POSITIONS only,
never a synthesized type.  This closes /Users/oobi/Documents/tot/dev/M7-PLAN.md:966-972."
Consequence: Stage C's item-8 leg reports positions only; `Serror.t`
gains no per-hole expected-type field.

**R-Q6**, verbatim: "no stage bumps Cache.format_version from 10
(dev/gates.sh:3814 and :3820).  Stage C changes reported text only."
The line numbers are the ratified quote as written, citing HEAD; per
R-S1, the same measurement and assertion sit at dev/gates.sh:3831 and
:3837 in the staged tree.  Consequence: no stage in this plan edits the
cache format version, and Stage C's item-10 leg is a text-reporting
change only.

**R-Q7**, verbatim: "if stdlib/prelude.tot:94 still refuses its
re-spell after Stage A lands green, Stage B STOPS and books a conflict
note in the C-D3 shape.  A retreat from the re-spell is a user ruling
only (dev/M7-BUILD-LOG.md:2340-2341)."  Consequence: Stage B has a
recorded stop condition, and the builder may not retreat from the
re-spell on its own authority.

Carried rulings, also binding.  C-D3 is the conflict-note shape a stage
uses when the repo refuses a predicted mutation
(/Users/oobi/Documents/tot/dev/M7-BUILD-LOG.md:2311-2341).  R10 gives
each mutation proof exactly one edit, and no two legs in this plan share
a mutation proof.  R11 requires the PASS-M8 namespace to be unused
before this scope.  C-A14 is the standing offset: the gate wrapper's
`PASS=` line reads the gate slice plus 4.

### 1.2 Baseline

M8 opens only after M7 Stage E is committed.  The entry PASS count is
420 for the gate slice and 424 as the wrapper prints it
(dev/M7-PLAN.md:6008-6009, arithmetic 410 entry + 5 markers + 5 surface
suite cases = 420; wrapper offset dev/M7-BUILD-LOG.md:819, C-A14).  Both
counts are ESTIMATE: this plan measured neither number against a live
tree, because Stage E is unstaged at the time this plan is written.
Every stage in this plan re-measures its own entry count before it edits
anything, per graft G8 (dev/M7-PLAN.md:793).

The whole PASS-M8 namespace is confirmed unused, satisfying R11:
`rg -c 'PASS-M8' /Users/oobi/Documents/tot/dev/gates.sh` printed no match
and exited 1 (measured 2026-09-05, HEAD 8cf0b8b).

Gate command battery (all four must be green before any stage report),
in the M7 shape (dev/M7-PLAN.md:211-218):

    dune build --root /Users/oobi/Documents/tot
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -3
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -3
    zsh /Users/oobi/Documents/tot/dev/gates.sh > "$TMPDIR/tot-gate.out" 2>&1; echo "GATE-EXIT=$?"

A bare shell has no dune on PATH; every dune command needs
`eval "$(opam env)"` first, in the same shell invocation
(dev/M7-PLAN.md:220-222).  Never delete or weaken an existing marker or
an existing test to make a stage green; M8 retires no existing marker
and no existing test, in the M7 discipline (dev/M7-PLAN.md:229-231).

### 1.3 Scope in and scope out

Quoted from section 1 of the design verdict
(/Users/oobi/Documents/tot-m8-design-verdict.md:21-25):

> M8 is proposal 1's theme, C5 with C4 as its acceptance test, taken as a
> HYBRID: proposal 1's four-stage spine with three repairs the attack
> phase and the judge's own probes force, plus C3 narrowed to lib/ and
> taken last.  C1 and C2 are DEFERRED, each behind one user ruling this
> panel deliberately did not make.

Quoted, the verdict's one-line scope statement
(design-verdict.md:79-81):

> Scope in one line: M8 closes the M7 elaborator hand-off.  The capture
> source, the prelude:94 re-spell, the three reporting debts, and the
> lib/ interface sweep last.

Scope out, quoted, C1 (design-verdict.md:29-42): "C1 cannot be planned
yet.  Its flagship stage needs a wf descent that RUNS, and the corpus
can build no accessibility inhabitant past `accZero`... Worse, the
admission clause on offer accepts a `wf`-spelled copy of
test/fixtures/bad2.tot... That is a user ruling, not a panel ruling."

Scope out, quoted, C2 (design-verdict.md:44-52): "C2 is a soundness
fence and it wants a milestone whose only job is the fence... C2 retires
a shipped tripwire marker by design (dev/gates.sh:2531-2535 says the two
fence legs are DESIGNED to go red and says 're-open the design
instead')... A panel should not flip a soundness fence in the same
breath as it answers a scheduling question the user owns."  The line
number is the ratified quote as written, citing HEAD; per R-S1, in the
staged tree the same comment-plus-both-legs span sits at
dev/gates.sh:2542-2561.

Two further non-goals, named in section 2 of the verdict, carry their
own one-line reasons.  The 12 surface/*.ml interfaces stay out of the
Stage D sweep: "three of the twelve are the files Stages A and C edit"
(design-verdict.md:124-126).  Item 5, the Frozen emptiness claim, stays
deferred: "it is a proof obligation about the evaluator's guard
(lib/interp.ml:84-91) with no seam in common with any file this scope
edits" (design-verdict.md:152-154).

### 1.4 The candidate table

One row per candidate.  Stage letters and marker names are the verdict's
stage sketch (design-verdict.md:157-341); the stage slices own their
internals, not this section.

| Candidate | Stage | Markers | Verdict line that allocates it |
| --- | --- | --- | --- |
| C5, the infer-position hole (theme) | A | PASS-M8A-LOCAL-SPINE-SYNTH, PASS-M8A-ZERO-ARG-UNCHANGED, PASS-M8A-BARE-LAMBDA-REFUSES, PASS-M8A-KERNEL-UNCHANGED | "C5. The infer-position hole. IN, and it is the milestone theme." (design-verdict.md:137) |
| C4, the prelude:94 re-spell (acceptance test) | B | PASS-M8B-PRELUDE-94 | "C4. The prelude :94 re-spell (C-D3). IN, as the Stage B acceptance test of C5." (design-verdict.md:128-129) |
| Item 8, per-hole expected types | C | PASS-M8C-HOLE-POSITIONS | "Item 8 is ruled Option A in Stage C, keep positions only, and pinned." (design-verdict.md:148-149) |
| Item 9, the s0-erased-guard driver gap | C | PASS-M8C-S0-DRIVER | "Item 9 rides Stage C as a gate route for test/fixtures/s0-erased-guard.tot." (design-verdict.md:149-150) |
| Item 10, the prelude arm multi-hole tail | C | PASS-M8C-PRELUDE-TAIL | "Item 10 rides Stage C in the cheaper shape the judge probe found." (design-verdict.md:150-151) |
| C3, the .mli sweep, narrowed to lib/ | D | PASS-M8D-MLI-COVERAGE, PASS-M8D-KERNEL-INTERNAL, PASS-M8D-NO-BEHAVIOUR-CHANGE | "C3. The .mli sweep. IN, narrowed to lib/, taken LAST as Stage D." (design-verdict.md:114) |
| C1, the WF package with the wide relation formal | none (deferred to M9) | none in M8 | "C1. The WF package with the wide relation formal (Q5). DEFERRED." (design-verdict.md:85); "C1 is out of M8" (R-Q1) |
| C2, nested inductives and the jarr migration | none (deferred to M9) | none in M8 | "C2. Nested inductives and the jarr migration. DEFERRED to M9, rule first." (design-verdict.md:100-101); "C2 is deferred to M9" (R-Q2) |

R-F2 and R-F3 dropped `PASS-M8A-CONSERVATIVITY` and
`PASS-M8B-RESPELL-COUNT`; R1-F3 dropped `PASS-M8B-ANCHORS`; R3-F3
dropped `PASS-M8C-TRANSCRIPT-RESEAL`, and the reseal stays an item 10
obligation, checked in Stage C's exit checklist.  Section 1 and section
8.2 state the same total, 11 markers.

The Stage D marker name PASS-M8D-KERNEL-INTERNAL is the ratified name
(R-Q4).  R-Q4 settles the self-entry leg as this one marker, and this
plan names no other self-entry leg for the same boundary check.

Section 1 ends.

## 2. Gate arithmetic and the marker namespace

This section is cross-cutting.  It carries no stage's payload and it
adds no `PASS-M8` leg of its own.  It states the numbers every stage
section quotes, the rule that keeps the wrapper and the slice from
mixing, the proof that the `PASS-M8` namespace is free, the marker
naming rule every later section must follow, and the two carried
protocols, mutation proof and cache discipline, in the form the stage
sections use.

Citation rule for this section, the same as the verdict's: a citation is
read from the COMMITTED blob at HEAD 8cf0b8b unless marked "unstaged
Stage E", in which case it is read from the working tree, which is HEAD
plus the Stage E diff that is not yet committed.  The Stage E diff
touches `dev/gates.sh`, so a HEAD line number and a working-tree line
number can differ for that file;  this section states both wherever it
matters.

### 2.1 Entry and the stage chain

Entry is 420 for the gate slice and 424 as the wrapper prints it, once
M7 Stage E is committed (dev/M7-PLAN.md:6008-6009 for the slice
arithmetic, `410 entry + 5 markers + 5 surface suite cases = 420`, and
the wrapper's plus 4 restated at dev/M7-BUILD-LOG.md:819 as conflict
note C-A14).  ESTIMATE: this entry number is not yet real,
because Stage E is unstaged;  it is a working-tree fact, not a HEAD
fact, and it is re-measured the day Stage E commits.

Chain, ESTIMATE, recounted per R3-CHAIN against the stage slices as fixed:
420 -> 428 -> 431 -> 437 -> 441 slice, wrapper +4 (C-A14):
424 -> 432 -> 435 -> 441 -> 445

| Stage | Theme | Markers | Suite cases | Entry | Exit slice | Exit wrapper |
| --- | --- | --- | --- | --- | --- | --- |
| A | the local-aware capture source | 4 | 4 | 420 | 428 | 432 |
| B | prelude:94 and the three literals | 1 | 2 | 428 | 431 | 435 |
| C | reporting: items 8, 9, 10 | 3 | 3 | 431 | 437 | 441 |
| D | the lib/ .mli sweep, LAST | 3 | 1 | 437 | 441 | 445 |

This table replaces the design verdict's own sketch
(/Users/oobi/Documents/tot-m8-design-verdict.md:169-178).  R-F1b found
the sketch already wrong before this round of fixes: the stage slices
defined 18 unique `PASS-M8` markers (A 5, B 3, C 5, D 5) against the
sketch's 5/3/4/3 = 15.  This round's fixers then dropped
`PASS-M8A-CONSERVATIVITY` (R-F2/R-F3) and `PASS-M8B-RESPELL-COUNT`
(R-F3); round 1's fixers then dropped `PASS-M8B-ANCHORS` (R1-F3); round
3's fixer then dropped `PASS-M8C-TRANSCRIPT-RESEAL` (R3-F3), and the
file count read from each stage slice's own `Marker:` lines today is
4/1/3/3 = 11, which is the table above.

(/Users/oobi/Documents/tot-m8-design-verdict.md:169-178 is the table
this one reproduces verbatim, with column order unchanged.)

Every cell above is ESTIMATE.  None of it is measurable with `rg -c` on
`dev/gates.sh` today, because none of the M8 legs exist yet;  a stage
section re-measures its own row at close and books a difference as a
conflict note, the C-D3 shape, not a silent edit of this table.

### 2.2 The arithmetic that ties the rows together

Row by row, each column reconciles against its left neighbour:
420 + 4 + 4 = 428, 428 + 1 + 2 = 431, 431 + 3 + 3 = 437,
437 + 3 + 1 = 441.  Column totals: 4 + 1 + 3 + 3 = 11 markers,
4 + 2 + 3 + 1 = 10 suite cases.  Eleven markers plus ten suite cases
is +21, and 420 + 21 = 441 slice.  The wrapper carries the same +21
from its own entry, 424 + 21 = 445, which is also 441 + 4, so the two
ways of reaching 445 agree.

The M7 comparison, verbatim: "Cross-check: 20 gate markers plus 29
suite cases is +49, and 371 + 49 = 420" (dev/M7-PLAN.md:705-706,
verified at that line in the working tree, unchanged by the Stage E
diff because the Stage E hunks all land after line 2304).  M8's +21 is
about half of M7's +49, on four stages against five, which matches the
design verdict's own framing: M8 closes one hand-off, M7 shipped one
rule and absorbed its corpus consequences (proposal-1 root-cause
section and /Users/oobi/Documents/tot-m8-design-verdict.md:59-63).

### 2.3 C-A14: the wrapper never mixes with the slice

Rule.  The wrapper prints 4 more than the gate slice at every entry and
every exit, in every stage, with no exception.  A stage section states
both numbers side by side, `NNN slice (MMM wrapper)`, and never
substitutes one for the other.  A review checklist item that quotes a
bare integer without saying which of the two it is has not honoured
C-A14.

Proof this holds across the table in section 2.1: 424 - 420 = 4,
432 - 428 = 4, 435 - 431 = 4, 441 - 437 = 4, 445 - 441 = 4.  The offset
is invariant because every stage adds the same delta to both columns;
C-A14 does not depend on the size of a stage, only on the constant
already fixed at M7 Stage E close
(/Users/oobi/Documents/tot-m7-stage-e-prep.md:23-24 and :80, restated at
/Users/oobi/Documents/tot-m8-design-verdict.md:14-17 and
:160-161, and carried into the ratification as C-A14).

### 2.4 R11: the marker namespace is clear, proved

R11 requires the `PASS-M8` namespace to be unused before this scope
opens.  Two commands prove it, both run over `dev/gates.sh`, both
MEASURED, not estimated.

Command: `git -C /Users/oobi/Documents/tot show HEAD:dev/gates.sh | rg -c 'PASS-M8'`
Output: no line printed, exit 1 (`rg -c` prints nothing and exits 1 when
a pattern has zero matches).  Zero `PASS-M8` occurrences in the
committed blob at HEAD 8cf0b8b.

Command: `rg -c 'PASS-M8' /Users/oobi/Documents/tot/dev/gates.sh`
Output: no line printed, exit 1, run against the working tree, which is
HEAD plus the unstaged Stage E diff.  Zero `PASS-M8` occurrences in the
reference state either, so Stage E's own additions do not collide.

Command: `rg -n 'echo PASS-M7E' /Users/oobi/Documents/tot/dev/gates.sh`
Output, five lines, working-tree line numbers: 3889
`echo PASS-M7E-SPEC-CITATIONS`, 3911 `echo PASS-M7E-WF-PROVENANCE-ORACLE`,
3936 `echo PASS-M7E-POSITIVITY-LAUNDER-ORACLE`, 3958
`echo PASS-M7E-INSTANCE-RULE`, 3975 `echo PASS-M7E-DEBT-H`.  All five
Stage E names are `PASS-M7E-*`, none is `PASS-M8*`, which is the second
half of R11.

This reading matches the design verdict's own claim exactly
(/Users/oobi/Documents/tot-m8-design-verdict.md:165-167: "the whole
`PASS-M8*` namespace is free ... and the five Stage E names are all
`PASS-M7E-*`").  No difference to report on R11 itself.

As a cross-check on the surrounding arithmetic, not on R11: the command
`rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | wc -l`
printed 166 in the working tree, one more than the 165 the design
verdict states for the same measurement
(/Users/oobi/Documents/tot-m8-design-verdict.md:166).  MEASURED
difference: a literal re-run today counts 166, not 165.  This does not
touch R11, because the one-line difference sits somewhere in the
surviving `PASS-M6`/`PASS-M7` set, not in `PASS-M8`, which the two
commands above still measure at zero.  Booked as an open doubt in
section 6, not silently corrected in the verdict's own text.

### 2.5 The marker namespace rule for M8

Every new gate marker this milestone adds is named `PASS-M8<stage>-
<NAME>`, where `<stage>` is one capital letter, `A`, `B`, `C` or `D`,
and `<NAME>` is the leg's own name in the same all-capitals,
hyphen-separated style the surviving `PASS-M7*` legs already use (for
example `PASS-M7D-CACHE-KEY`, dev/gates.sh:3814 at HEAD).  Three
conditions bind every stage section that follows this one:

1. Unique across the whole plan.  No two stage sections mint the same
   `PASS-M8<stage>-<NAME>`, and no stage section reuses a name from
   another stage's letter.
2. Absent from `dev/gates.sh` in the reference state, HEAD plus the
   unstaged Stage E diff, at the moment the stage section is written.
   Section 2.4 proves this holds for the whole `PASS-M8` prefix today;
   a later stage section that adds a name re-runs the same `rg -c`
   check against its own name before claiming the slot.
3. Never collides with a surviving `PASS-M6*` or `PASS-M7*` name,
   because those legs stay in the battery through M8 (R-Q2 keeps both
   fence legs green, dev/gates.sh:2531-2535 at HEAD, working-tree
   dev/gates.sh:2542-2553 after the Stage E shift).

A stage section that cannot satisfy all three has found a namespace
conflict, not a design, the same standard pin 13 set for M7
(dev/M7-PLAN.md:779).

### 2.6 R10: the mutation-proof protocol, carried

Every gate leg this milestone adds carries a mutation proof: the one
edit, cited as `<path>:<line>`, that turns the leg from green to red
after its stage lands.  R10 states the consequence plainly: a leg with
no mutation proof is presumed vacuous.  No two legs may share a
mutation proof, because a shared proof means one leg is redundant with
the other and the pair proves nothing that one leg alone would not.

The leg shape every mutation proof sits inside is fixed at
dev/gates.sh:2507-2529 (working tree; this range is inside the Gate A
block that predates the Stage E insertion point at HEAD:2304, so the
same range reads at HEAD too): one `echo PASS-<NAME>` line on the
success arm, a matching `FAIL-<NAME>` arm on the same conjunction that
prints the measured values, and `exit 1` on that failure arm.  No stage
section may spell a leg any other way.

The battery discipline that binds every stage, stated once here and not
repeated per stage: one `echo PASS-<NAME>` per leg, a matching FAIL arm
that prints the measured values, and `exit 1`, the shape just cited.
Every leg carries a mutation proof, a leg with no mutation proof is
presumed vacuous, and no two legs share a mutation proof
(/Users/oobi/Documents/tot-m8-design-verdict.md:343-349, which restates
R10 for this milestone in the M7 form and cites the same
dev/gates.sh:2507-2529 shape).  Every integer any stage section states
is an ESTIMATE and is re-measured at that stage's close, per section
2.1 above.

The attack phase found three shapes of broken mutation proof that this
rule exists to exclude, and every stage section that follows must avoid
all three: a proof that names an edit the function's own signature
cannot accept (attack-1 F5, surface/elab.ml:397's `synth` takes no
expected type to mutate); a proof that is really two edits, so the leg
does not say which half it observes (attack-3 F5, attack-2 F5); and a
proof that mutates the document the same stage writes rather than the
repo's behaviour (attack-2 F5, `PASS-M8C-FROZEN-OBLIGATION` and
`PASS-M8D-SPEC-NESTING`, neither of which is in this milestone's scope,
since C2 and C1 are deferred, but the shape of the mistake generalizes).

### 2.7 R-Q6: cache discipline, carried

No stage bumps `Cache.format_version` from 10.  The constant is
`surface/cache.ml:118`, `let format_version : int = 10`, verified at
that line in the working tree.  The leg that measures it is
`PASS-M7D-CACHE-KEY`, a surviving M7 leg, not a new M8 marker: the
ratification cites its measurement at dev/gates.sh:3814 and its
assertion at dev/gates.sh:3820, both HEAD line numbers.  In the
reference state, HEAD plus the unstaged Stage E diff, the Stage E
insertions ahead of this point (dev/gates.sh:2304 and dev/gates.sh:3559
at HEAD) shift those two lines by +17, so the same measurement and
assertion sit at working-tree dev/gates.sh:3831
(`m7d_fv=$(rg -c 'let format_version : int = 10' "$ROOT"/surface/cache.ml)`)
and dev/gates.sh:3837 (`&& [ "$m7d_fv" -eq 1 ]; } \`).  No M8 stage
section may touch either line except to re-measure it, and Stage C's
own reporting work changes reported text only, never the version
constant (R-Q6).

Section 2 ends.

## 3. The conflict-note protocol

This section binds every M8 stage.  A stage predicts a source edit, a
literal, or a refusal message before it runs anything against the tree.
When the repo answers with something else, the stage does not guess and
does not retreat.  It re-measures, cites the lines that explain the
refusal, and books a conflict note in the shape this section names.  The
shape is C-D3, the note M7 Stage D wrote when stdlib/prelude.tot:94
refused its re-spell (dev/M7-BUILD-LOG.md:2311-2341).  Graft G8, the
count-honesty rule this section restates, is dev/M7-PLAN.md:793.  This
protocol is carried, not invented: the ratifications file names C-D3 as a
carried ruling (the M8 ratifications, /Users/oobi/Documents/tot-m8-ratifications.md:3,
"Carried rulings from the verdict: C-D3").

Section 3 adds no PASS-M8 marker of its own.  It is the rule a stage
follows when one of ITS markers, defined in that stage's own section,
comes back red or half-red against a predicted reading.  Stage B's
PASS-M8B-PRELUDE-94 leg, owned by the Stage B slice, is the leg this
protocol is written for.

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
   correct description of the refusal: which site, which arm, which
   position (infer or check), and whether the refusal is local to one
   site or reaches a class of sites.  C-D3's own smallest reading is
   that stdlib/prelude.tot:94 is a congruence motive consumed in infer
   position while its neighbor at stdlib/prelude.tot:74 is not, so the
   refusal is specific to the motive shape and not to Eq (dev/M7-BUILD-LOG.md:2324-2330).
6. The decision.  Which of the two moves in 3.2 the builder takes, and
   why the repo's proof (not the builder's preference) selects it.

A note with fewer than six parts is not booked.  Part 3's command is
the part a later build workflow re-runs to check the note still holds;
a note that cannot be re-run is not trusted past its own stage.

### 3.2 The decision boundary

A builder has exactly two moves once a prediction is refused.

- Re-measure and book the note.  The builder records the six parts of
  3.1 in dev/M8-BUILD-LOG.md as C-<stage letter><n>, keeps the payload
  the ratification fixed, and lets the stage's exit numbers move by the
  measured amount, not the predicted one.  This is the only move a
  builder takes without asking anyone.
- Stop and report.  When the refused prediction IS the ratified payload
  itself, not a literal that moves around it, the builder stops the
  stage, books the note, and leaves the retreat decision to the user.

A builder never retreats from a ratified payload on its own reading of
the refusal.  Retreat from the stdlib/prelude.tot:94 re-spell is named,
by the plan this milestone inherits, as a user ruling and not a builder
decision: "Plan D8 (5037-5047) makes any retreat from the re-spell a
user ruling and not a builder decision, so this note stops at the
record" (dev/M7-BUILD-LOG.md:2340-2341).  The same boundary holds for
every ratified R-Q payload in this milestone: R-Q4's kernel-internal
entry point, R-Q5's positions-only report, R-Q6's frozen format_version.
A stage that meets a refusal on one of these books the note, stops, and
waits;  it does not choose a different payload and call the battery
green.

### 3.3 R-Q7, the worked example

R-Q7 states the boundary in the concrete case the milestone already
expects to meet: "if stdlib/prelude.tot:94 still refuses its re-spell
after Stage A lands green, Stage B STOPS and books a conflict note in
the C-D3 shape.  A retreat from the re-spell is a user ruling only"
(/Users/oobi/Documents/tot-m8-ratifications.md:13, quoting
dev/M7-BUILD-LOG.md:2340-2341).  Filling the template against the
precedent the repo already produced once:

1. Predicted.  stdlib/prelude.tot:94 re-spells its explicit `Eq B` to
   `Eq _`, and `_build/default/bin/tot.exe check examples/church.tot`
   stays at exit 0.
2. Measured.  With the `_` spelling in place, the same command exits 1
   and prints `prelude: 94:48: hole: no expected type at this position`
   (dev/M7-BUILD-LOG.md:2321-2323).
3. Command and output.  `_build/default/bin/tot.exe check
   examples/church.tot` (run from the repo root, the binary already
   built); output line `prelude: 94:48: hole: no expected type at this
   position` (dev/M7-BUILD-LOG.md:2323).
4. Cited lines.  stdlib/prelude.tot:94, the congruence motive whose
   later arguments are `f a` and `f z`, spines headed by the local `f`
   (tot-m8-proposal-1.md's root-cause section, confirmed at
   surface/elab.ml:401 by the panel).  stdlib/prelude.tot:74, the
   neighboring motive that DOES take `_` and stays green, which is the
   line that narrows the refusal to the congruence shape and not to Eq
   in general (dev/M7-BUILD-LOG.md:2328-2330).
5. Smallest reading.  The refusal is specific to a motive whose later
   informative arguments are local-headed applied spines, reached in
   infer position;  it is not a property of Eq, of subst0, or of the
   file (dev/M7-BUILD-LOG.md:2326-2330).
6. Decision.  If Stage A's new local-aware capture (the payload C5
   scopes IN, per the M8 verdict section 1) still leaves this site
   refusing after Stage A lands green, Stage B STOPS.  The builder books
   the note under this template, keeps the explicit `Eq B` spelling at
   stdlib/prelude.tot:94, and reports the stop;  it does not widen the
   capture further on its own judgment, because that widening is new
   elaborator design outside Stage A's scoped payload, and the retreat
   or the widening is a user ruling either way.

The precedent recorded exactly this outcome once already: Stage D of M7
predicted 45 re-spells, met a refusal at this same line, and closed at
44 with the note recorded as C-D3 rather than by silently keeping the
old spelling or force-fitting a wider rule (dev/M7-BUILD-LOG.md:2311-2341).
Stage B of M8 is not free to assume Stage A's new capture succeeds here;
this worked example is the exact probe the build workflow re-runs after
Stage A closes, before Stage B opens.

### 3.4 Count honesty

A predicted literal that the repo refuses is re-measured, and the new
value REPLACES the estimate everywhere the estimate was written, with
the derivation shown next to the replacement.  Graft G8 states the rule
this milestone inherits verbatim: "Every rg-derived or script-derived
count in [the] documents and gate comments ships WITH the exact command
that produced it, the command must actually PRINT the number, and
re-running it must reproduce the number" (dev/M7-PLAN.md:793-797).  A
literal is never edited to match a wish: the M7 precedent is the three
literals C-D3 itself moved, 45 re-spells becoming 44, `m6e_holes` 69
becoming 68 (the assertion `[ "$m6e_holes" -eq 68 ]` at
dev/gates.sh:3167, unstaged Stage E; M7 Stage D's own record cited this
same pin at dev/gates.sh:3156, its pre-Stage-E line), and the prelude
holed count 47 becoming 46 (the assertion `[ "$m7d_ph" -eq 46 ]` at
dev/gates.sh:3792, unstaged Stage E; M7 Stage D's own record cited
dev/gates.sh:3775), each replacing a plan prediction with a measured
value and a command, never the reverse (dev/M7-BUILD-LOG.md:2336-2338).
R-Q6 extends the same discipline to a literal that must NOT move under
any stage's edit: `Cache.format_version` stays 10.  The ratification
cites this pin at dev/gates.sh:3814 and :3820;  the unstaged Stage E
diff inserts lines ahead of it, so at the current tree the same pin
sits at dev/gates.sh:3831 (`m7d_fv=$(rg -c 'let format_version : int =
10' ...)`) and dev/gates.sh:3837 (`[ "$m7d_fv" -eq 1 ]`).  A stage that
re-derives this literal reads it at the current line, not the
ratification's cited one.  Stage C's item 8
and item 9 reporting changes text only, never that constant.  A stage
that finds a count moving where R-Q6 forbids movement treats that as a
conflict in the 3.1 shape, not as a green literal edited quietly to
hide the move.

### 3.5 Walk discipline, reused by every stage

Every stage exits GATE-EXIT=0, 0 FAIL, at the stage table's stated exit
count, re-measured per 3.4 where a note applies.  Every mutation proof
this milestone ships flips its leg red by the named edit and then
restores the source to its pre-mutation bytes, md5-identical, before the
next leg runs (R10, one edit per mutation proof, no two legs sharing
one).  Every design decision a stage makes, including every conflict
note this section produces, becomes a dated entry in SPEC.md's decision
log (SPEC.md:19, "## 2. Decision log"), the same place M7 recorded its
own stage decisions.  The user commits; no stage agent commits, stages,
or leaves dev/M8-BUILD-LOG.md written to /Users/oobi/Documents/tot
uncommitted past its own return.  A stage that cannot reach GATE-EXIT=0
without silently dropping a leg has found a conflict, not a design, and
takes it through 3.1 and 3.2 rather than shrinking the battery.

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
   the source md5-identical (R10, section 6 of the M7 shape this
   protocol mirrors, dev/M7-PLAN.md:846-872).
3. Every count the stage reports is measured, not guessed, with the
   command that produced it shown beside the number (3.4).  A number
   that a prediction refused is checked against a booked note, not left
   as the old prediction with a new comment.
4. Every conflict this stage met is booked under 3.1 in
   dev/M8-BUILD-LOG.md as C-<stage letter><n>, with all six parts
   present, before the stage is reported closed.
5. The incoming stage's PASS-M8<L> namespace stays collision-free:
   `rg -c 'PASS-M8<L>-'` over dev/gates.sh, with `<L>` replaced by
   the incoming stage letter, exits 1 with no output before its markers
   are added. Earlier stages' markers remain present and green. R11's
   whole-namespace absence check runs once, before Stage A opens.
6. No new OCaml code the stage ships uses an exception, a partial
   index, a bool match, or a wildcard arm on an exhaustive match; the
   stage's own review checklist names the exact files it touches and
   confirms each one against this list, the same shape M7's Stage A
   checklist used (dev/M7-PLAN.md:2445-2456).

Section 3 ends.

## STAGE A: the local-aware capture source

### Goal

Give the argument-driven hole capture a second instantiation for a LOCAL
head.  Today the capture source only reads a declared type off a
GLOBAL head (`inst_applied`, surface/elab.ml:380-387), and a LOCAL head
with any applied argument answers `None` (surface/elab.ml:401).  Stage A
adds a local-aware instantiation that peels one declared domain per
applied argument and keeps the residual's free locals, so a hole whose
only informative later argument is a local-headed spine (for example
`f a` where `f` is a lambda-bound function) resolves instead of
refusing.  The zero-argument case, `local_ty locals ix`
(surface/elab.ml:308-309), stays byte for byte.  The kernel is not
touched.

### Rulings covered

- R10 (carried).  "One edit per mutation proof."  Every marker below
  names exactly one edit, and no two markers name the same edit.
- R11 (carried).  "The PASS-M8 namespace must be unused before this
  scope."  Measured at the reference state: `rg -c 'PASS-M8'
  /Users/oobi/Documents/tot/dev/gates.sh` prints nothing and exits 1.
- C-A14 (carried).  "The wrapper count adds 4 over the gate slice."
  Every count below is given as slice figure and wrapper figure
  (slice + 4).
- C-D3 (carried, forward reference only).  The conflict-note shape for
  a predicted mutation the repo refuses.  Stage A predicts no refusal;
  C-D3 governs Stage B's own stop condition (R-Q7) if
  stdlib/prelude.tot:94 still refuses its re-spell after this stage
  lands, which is Stage B's concern, not this slice's.

R-Q7 is not covered by this slice.  It names the condition under which
Stage B stops after Stage A lands; it does not change anything Stage A
builds or gates.

### Entry state

Measured at the reference state (HEAD of /Users/oobi/Documents/tot plus
the unstaged M7 Stage E diff):

- `rg -o 'echo PASS-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh
  | wc -l` prints 166.
- `rg -c 'PASS-M8' /Users/oobi/Documents/tot/dev/gates.sh` prints
  nothing (exit 1): the PASS-M8 namespace is free (R11 satisfied).
- `rg -n 'PASS-M7E' /Users/oobi/Documents/tot/dev/gates.sh` lists the
  five Stage E markers at lines 3889, 3911, 3936, 3958 and 3975
  (PASS-M7E-SPEC-CITATIONS, PASS-M7E-WF-PROVENANCE-ORACLE,
  PASS-M7E-POSITIVITY-LAUNDER-ORACLE, PASS-M7E-INSTANCE-RULE,
  PASS-M7E-DEBT-H), confirming Stage E's five markers sit in the 166.
- Entry 420 slice (424 wrapper) is the design verdict's own precondition
  for this stage (tot-m8-design-verdict.md:171) and is not independently
  re-derivable from the 166 gate-echo count without running the suite,
  so it is carried as ESTIMATE, matching the verdict and the
  ratifications.

### Files touched

- `surface/elab.ml`.  The one file the real Stage A diff changes:
  `inst_domain` gains a labelled parameter that controls its
  free-variable arm, `inst_applied` passes the HEAD-preserving instance
  of that parameter, a new function reads a local-preserving instance
  of it, and `synth`'s local arm (surface/elab.ml:401) calls the new
  function on a non-empty argument list.
- `dev/m8a/local-spine-holed.tot`, `dev/m8a/local-spine-explicit.tot`,
  `dev/m8a/bare-lambda-holed.tot`.  New fixtures, following the
  `dev/m7a/sN-holed.tot` / `dev/m7a/sN-explicit.tot` pairing convention
  (for example dev/m7a/s5-holed.tot and dev/m7a/s5-explicit.tot).
- `dev/gates.sh`.  Four new gate legs appended, in the M7A pattern
  (dev/gates.sh:3240-3269 for the frozen-digest shape).  A fifth,
  corpus-digest leg, PASS-M8A-CONSERVATIVITY, is dropped per R-F3:
  PASS-M7A-CONSERVATIVITY already pins the identical digest over the
  identical five example files, dev/gates.sh:3402-3443.
- `test/surface.ml`.  Four new suite cases (see Suite cases).
- `lib/check.ml` is NOT touched by the real stage.  Two of the four
  mutation proofs below edit it TEMPORARILY, to prove their gate legs
  are live, and that edit is reverted before the stage is considered
  closed.  This is the mutation-proof protocol, not a stage edit.

### Design

The capture source lives in `synth` (surface/elab.ml:397-410).  Its own
doc comment states the guarantee this stage must keep:  "the kernel
re-checks the finished definition (surface/run.ml:241) ... a wrong
answer here is a kernel `Mismatch`, never a silent accept"
(surface/elab.ml:394-396).  Its local arm today is

```
| Term.Var ix -> ( match applied with [] -> local_ty locals ix | _ :: _ -> None)
```

(surface/elab.ml:401).  The empty case reads the local's recorded type,
shifted to the use site by `local_ty` (surface/elab.ml:308-309).  The
non-empty case refuses outright.

The GLOBAL arm on the same match uses `inst_applied`
(surface/elab.ml:380-387):

```
let inst_applied (gty : Term.t) (applied : Term.t list) : Term.t option =
  let n = List.length applied in
  match () with
  | () when List.exists has_auto applied -> None
  | () ->
      peel_domains n gty
      |> Option.map (fun (_doms, rest) -> inst_domain ~j:n ~k:n applied ~d:0 rest)
      |> Option.join
```

`inst_domain` (surface/elab.ml:208-247) is a structural walk over the
peeled residual.  Its free-variable arm is

```
| Term.Var i when i >= d ->
    let p = j - 1 - (i - d) in
    if p >= 0 && p < k then List.nth_opt settled p |> Option.map (Term.shift ~cutoff:0 ~by:d)
    else None
```

(surface/elab.ml:211-214; the shift call is exact against
surface/elab.ml:213, `if p >= 0 && p < k then List.nth_opt settled p
|> Option.map (Term.shift ~cutoff:0 ~by:d)`, reproduced at
tot-m8-design-verdict.md:185-187).  `p < 0`
answers a free variable that escapes the `n`-wide peeled telescope: it
is a reference to a binder OUTSIDE the arguments just peeled.  For a
GLOBAL head this cannot happen on a well-formed declared type read at
top level with `d:0` (a genuinely free de Bruijn index there is a
malformed program), so hardcoding `None` there is harmless.  For a
LOCAL head it happens BY CONSTRUCTION: a local's declared type, once
shifted by `local_ty`, mentions the outer scope's OWN binders as free
variables (attack findings A1-F1, A1-F2, both accepted).  Reusing
`inst_applied` for a local head therefore reads as "answer nothing"
exactly where an open local type needs an answer.

The fix generalizes `inst_domain` with a new labelled parameter,
`~escape : int -> Term.t option`, that supplies the free-variable arm's
answer once `p < 0`:

```
let rec inst_domain ~(escape : int -> Term.t option) ~(j : int) ~(k : int)
    (settled : Term.t list) ~(d : int) (t : Term.t) : Term.t option =
  match t with
  | Term.Var i when i >= d ->
      let p = j - 1 - (i - d) in
      (match () with
       | () when p >= 0 && p < k -> List.nth_opt settled p |> Option.map (Term.shift ~cutoff:0 ~by:d)
       | () -> escape i)
  | ... (* every other arm threads ~escape unchanged *)
```

`inst_applied` becomes a thin wrapper that pins `~escape:(fun _ -> None)`,
so its behaviour at the GLOBAL arm is unchanged byte for byte:

```
let inst_applied (gty : Term.t) (applied : Term.t list) : Term.t option =
  let n = List.length applied in
  match () with
  | () when List.exists has_auto applied -> None
  | () ->
      peel_domains n gty
      |> Option.map (fun (_doms, rest) ->
             inst_domain ~escape:(fun _ -> None) ~j:n ~k:n applied ~d:0 rest)
      |> Option.join
```

A new function supplies the local-preserving instance.  A free variable
that escapes the peeled telescope is a reference into the ENCLOSING
scope, `n` binders further out than the peeled arguments, so it is
answered by shifting the index down by `n`, the number of arguments
peeled (the residual is read at depth `d`, and the escaping index sits
`n` binders above the peeled span, so `Term.Var (i - n)` names the same
binder one frame shallower):

```
let inst_applied_local (lty : Term.t) (applied : Term.t list) : Term.t option =
  let n = List.length applied in
  match () with
  | () when List.exists has_auto applied -> None
  | () ->
      peel_domains n lty
      |> Option.map (fun (_doms, rest) ->
             inst_domain ~escape:(fun i -> Some (Term.Var (i - n))) ~j:n ~k:n applied ~d:0 rest)
      |> Option.join
```

`synth`'s local arm becomes

```
| Term.Var ix -> (
    match applied with
    | [] -> local_ty locals ix
    | _ :: _ -> local_ty locals ix |> Option.map (fun lty -> inst_applied_local lty applied) |> Option.join)
```

which keeps `[] -> local_ty locals ix` unchanged (marker 2) and adds
the local-aware instance only for the non-empty case (marker 1).

Downstream is already open-tolerant.  The capture matches the shifted
declared domain against the synthesized type with `rigid`
(surface/elab.ml:153-199, entered through `rigid_or_whnf` at
surface/elab.ml:417-428); only the whnf RETRY step is closed-only, the
`is_closed ity` guard at surface/elab.ml:422.  `rigid` itself runs on
open terms.  So a captured type carrying free locals is usable by the
match that resolves the hole, with no further change needed.

Nothing else moves.  `holed_leading_slot` (surface/elab.ml:284-285)
still decides whether a leading slot is even a candidate for capture,
unchanged.  `spine_infer` (surface/elab.ml:881-942), the GLOBAL-headed
caller that reads `fenced globals g gty` (surface/elab.ml:892) and
forces `caps = []` on a fenced global (surface/elab.ml:896-899), is
untouched: fencing is a GLOBAL-head concern and Stage A's new
instantiation is reached only from `synth`'s LOCAL arm.  The kernel
(everything under lib/) is untouched; Stage A is a change to the
elaborator's capture SOURCE only, and `synth`'s own doc comment's
guarantee (surface/elab.ml:394-396) is what makes that safe: any wrong
capture is caught by the kernel re-check at surface/run.ml:241, a
`Mismatch`, never a silent accept.

### Gate additions

Every command below is written to run standalone, from the repo root,
with no reliance on `dev/gates.sh`'s own `$ROOT`, `$watchdog` or `$FAST`
variables, per the plan's own tree rules.  The build workflow that later
appends these as real gate legs may fold them back into that shared
machinery; the predicted exit codes and substrings do not depend on
which shell scaffold carries them.

1. Marker: PASS-M8A-LOCAL-SPINE-SYNTH
   Ruling: carried finding A1-F1/A1-F2 (accepted), the capture source
   must reach a LOCAL head.
   Command: `out=$(timeout 10 /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/dev/m8a/local-spine-holed.tot 2>&1); code=$?; printf 'code=%d out=%s\n' "$code" "$out"; exit "$code"`
   Before the stage: exit 1, output contains "hole: no expected type at this position" (PREDICTED, the message text at surface/serror.ml:94-95).
   After the stage: exit 0, output contains "probeH" (PREDICTED, `tot.exe check` prints `def probeH : ...` on success, and the def name never appears in the failure line, which quotes only the file position).
   MUTATION: surface/elab.ml:401, restore `| _ :: _ -> None` (the pre-Stage-A non-empty arm); the fixture returns to exit 1 with the same hole message.
   Non-vacuous because: the fixture's only informative later argument is the local-headed spine `f a`; only the new instantiation resolves it, so reverting the arm removes exactly this resolution and nothing else.

2. Marker: PASS-M8A-ZERO-ARG-UNCHANGED
   Ruling: accepted finding A1-F1, the proposal-1 arm regressed the
   empty-argument case; this leg is the one that would have caught it.
   Command: `p=$(timeout 10 /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/examples/church.tot 2>&1); pcode=$?; l=$(timeout 10 /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/dev/m8a/local-spine-holed.tot > /dev/null 2>&1); lcode=$?; printf 'church=%d local=%d\n' "$pcode" "$lcode"; exit "$lcode"`
   Before the stage: exit 1, output contains "church=0 local=1" (PREDICTED: the prelude bootstraps clean at HEAD; the local-spine fixture is not yet resolved).
   After the stage: exit 0, output contains "church=0 local=0" (PREDICTED: the prelude still bootstraps clean; the local-spine fixture now resolves).
   MUTATION: surface/elab.ml:401, in the `[] -> local_ty locals ix`
   branch of `synth`'s local arm, replace `local_ty locals ix` with
   the unconditional escape finding 2 names, `Some (Term.Var ix)` with
   no shift.  The prelude's captured `Eq _` slot at
   stdlib/prelude.tot:74 then reads an unshifted, wrong local index.
   `Check.define` (surface/run.ml:241) raises a kernel `Mismatch`, and
   `church=0` becomes `church=1`. The target is church.tot because
   the driver bootstraps the prelude before checking its target. Checking
   prelude.tot itself fails with duplicate global Bool even when bootstrap
   succeeds. This correction agrees with build-log conflict note C-A1.
   Non-vacuous because: the edit changes the zero-argument branch
   itself, so it is reachable at `j = 0`.  `inst_domain`'s own
   free-variable guard is not reachable there: `k = 0` makes `p`
   negative for every free local, so a mutation placed inside that
   guard turns nothing red.  A mutation on the branch dispatch does.

3. Marker: PASS-M8A-BARE-LAMBDA-REFUSES
   Ruling: the M7 hand-off fixture (dev/M7-PLAN.md:957-961: "A
   bare-lambda fixture is not in M7 scope, so M8 writes that one").
   Command: `b=$(timeout 10 /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/dev/m8a/bare-lambda-holed.tot 2>&1); bcode=$?; l=$(timeout 10 /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/dev/m8a/local-spine-holed.tot > /dev/null 2>&1); lcode=$?; printf 'bare=%d local=%d\n' "$bcode" "$lcode"; exit "$lcode"`
   Before the stage: exit 1, output contains "bare=1 local=1" (PREDICTED: the callee of `(fun x => x) zero` is a bare lambda the kernel must infer and refuses).
   After the stage: exit 0, output contains "bare=1 local=0" (PREDICTED: the bare-lambda refusal is pinned; the local-spine fixture now resolves).
   MUTATION: lib/check.ml:958-959, repaired per the verdict (the proposal's own `Term.Lam` arm inside `synth` is unwritable, because `synth` receives only globals, locals and the term, surface/elab.ml:397): infer a Pi domain for a bare lambda instead of `Error (Error.Cannot_infer ...)`; `bare=1` moves.
   Non-vacuous because: lib/check.ml:960-962 infers the callee of an application before checking its argument, so the Cannot_infer arm at lib/check.ml:958-959 is the only refusal `(fun x => x) zero` reaches; no elaborator-side capture change, before or after Stage A, touches a callee position the kernel itself infers, which is what pinning `bare=1` next to the moving `local` field is meant to show.

PASS-M8A-CONSERVATIVITY is dropped (R-F3).  Its recipe, the
concatenated stdout of the five green example files, and its digest,
f1450de0006de4b7339b2f39ec2e2e50, are the recipe and the digest
PASS-M7A-CONSERVATIVITY already pins (dev/gates.sh:3402-3443).  A
Stage A edit that moves this digest reddens PASS-M7A-CONSERVATIVITY
first, so the new leg carried no mutation of its own.
PASS-M7A-CONSERVATIVITY already covers the claim that Stage A's new
instantiation must not move the shipped corpus.

4. Marker: PASS-M8A-KERNEL-UNCHANGED
   Ruling: "the kernel is untouched" (tot-m8-design-verdict.md:196).
   Command: `k=$(cat /Users/oobi/Documents/tot/lib/budget.ml /Users/oobi/Documents/tot/lib/check.ml /Users/oobi/Documents/tot/lib/erase.ml /Users/oobi/Documents/tot/lib/error.ml /Users/oobi/Documents/tot/lib/eterm.ml /Users/oobi/Documents/tot/lib/eval.ml /Users/oobi/Documents/tot/lib/global.ml /Users/oobi/Documents/tot/lib/interp.ml /Users/oobi/Documents/tot/lib/json_escape.ml /Users/oobi/Documents/tot/lib/level.ml /Users/oobi/Documents/tot/lib/literal.ml /Users/oobi/Documents/tot/lib/pp.ml /Users/oobi/Documents/tot/lib/prim.ml /Users/oobi/Documents/tot/lib/quantity.ml /Users/oobi/Documents/tot/lib/term.ml /Users/oobi/Documents/tot/lib/totality.ml /Users/oobi/Documents/tot/lib/value.ml | md5 -q); l=$(timeout 10 /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/dev/m8a/local-spine-holed.tot > /dev/null 2>&1); lcode=$?; printf 'lib_md5=%s local=%d\n' "$k" "$lcode"; exit "$lcode"`
   Before the stage: exit 1, output contains "lib_md5=ec077852495cdc0ac9a7abd4eb2fe786" (MEASURED against the current working tree: 17 files under lib/*.ml, sorted by name).
   After the stage: exit 0, output contains "lib_md5=ec077852495cdc0ac9a7abd4eb2fe786" (PREDICTED: the real Stage A diff touches only surface/elab.ml).
   MUTATION: lib/check.ml:959, change the binder text in the `Cannot_infer` message (for example drop "the bare lambda" from the format string); `lib_md5` moves away from ec077852495cdc0ac9a7abd4eb2fe786.
   Non-vacuous because: Stage A's real diff is confined to surface/elab.ml; pinning the full lib/*.ml digest next to the moving local-spine control proves the kernel stays byte-identical while the new capture path goes live.  This leg's own observable is the `lib_md5` digest, distinct from the `bare=` field PASS-M8A-BARE-LAMBDA-REFUSES pins at the same lib/check.ml:958-959 line, so the two legs mutate one line without sharing a mutation text or an observable.  The pair at surface/elab.ml:401, PASS-M8A-LOCAL-SPINE-SYNTH against PASS-M8A-ZERO-ARG-UNCHANGED, is the same ruled exception under R4-2b: two legs, two different edits, two different observables, the exit code with the hole message against the `church=0 local=0` field.

### Suite cases

Four new entries in test/surface.ml, following the file's own
`expect_cli_run_lines` / in-process-checker pairing style
(test/surface.ml:216-224 for the CLI helper).  None duplicates its
matching gate leg: the gate legs above measure `tot.exe check`'s
external, textual output over files on disk, while these cases call
into `Bootstrap.state ()` and the elaborator's own entry points
in-process, over source strings, so a change to how output is FORMATTED
cannot make a case pass while its file-level gate leg fails, or the
reverse.

1. The local-spine positive.  Elaborate the source string of
   `dev/m8a/local-spine-holed.tot` in-process and assert the result is
   `Ok`, with the resolved definition's printed type equal to the
   explicit twin's.  This is the in-process counterpart of marker 1: the
   gate leg proves the CLI's exit code and message; this case proves the
   elaborator's own `Ok` value carries the right term, not merely a
   passing process exit.

2. The bare-lambda negative.  Elaborate `dev/m8a/bare-lambda-holed.tot`
   in-process and assert the result is `Error`, with the error's printed
   text containing "the bare lambda".  This pins the STRING the kernel's
   `Cannot_infer` arm produces (lib/check.ml:959), independent of the
   process-level plumbing marker 3's leg also exercises, so a change
   that alters only how `bin/tot.ml` prints an error (not the error
   itself) cannot silently pass this case.

3. The class-former fence control.  A fixture with a fenced GLOBAL head
   (a class-former reached through `spine_infer`'s `fenced` check,
   surface/elab.ml:892) and a holed leading slot, asserted `Error` with
   the SAME message before and after Stage A.  This is the in-process
   witness that `fenced globals g gty` (surface/elab.ml:892) and the
   `caps = []` short-circuit (surface/elab.ml:896-899) are GLOBAL-head
   only and untouched by the new LOCAL-head instantiation, closing the
   one path Stage A could have reached by accident.

4. The open-captured-type-reaches-the-kernel case.  Elaborate a fixture
   whose leading hole resolves to an OPEN captured type (the local-spine
   fixture qualifies) and assert that the SAME `Check.define` call the
   CLI drives (surface/run.ml:241) accepts the resulting term, pinning
   in-process the guarantee `synth`'s own doc comment states
   (surface/elab.ml:394-396): an open capture is not a shortcut around
   the kernel, it is re-checked there like every other term.

### Review checklist

1. Confirm `inst_domain`'s new `~escape` parameter is threaded through
   EVERY recursive call in its match (Term.Pi, Term.Lam, Term.App,
   Term.Let, Term.Ann), not only the arms touched by the worked example,
   so no branch silently falls back to a stale positional signature.
2. Confirm `inst_applied`'s call site (surface/elab.ml:386, inside the
   function body reproduced in Design) passes `~escape:(fun _ -> None)`
   and nothing else, so the GLOBAL arm's behaviour is unchanged byte for
   byte.
3. Confirm `inst_applied_local`'s `~escape` closure shifts by exactly
   `n`, the number of PEELED arguments, not by the spine's own arity or
   by `k`, and confirm this against the worked de Bruijn arithmetic in
   Design before trusting any fixture's predicted output.
4. Confirm `synth`'s `[] -> local_ty locals ix` line is untouched in the
   diff, character for character, against surface/elab.ml:401 at the
   reference state.
5. Confirm no new call site reaches `inst_applied_local` from anywhere
   other than `synth`'s local, non-empty-argument arm: `spine_infer`
   (surface/elab.ml:881-942) must keep calling only `arg_caps`, which in
   turn keeps calling `synth`, never the new function directly.
6. Re-run every command in Gate additions and confirm each MUTATION
   turns its named leg red. Record any additional legs that turn red;
   shared control fields and the kernel digest can observe the same edit.
   Distinct mutations are required, not mutually exclusive failures.
7. Re-measure the lib/*.ml digest AFTER the real diff lands. It must
   remain ec077852495cdc0ac9a7abd4eb2fe786, with 17 files, throughout
   Stages A to C. A mismatch here stops the stage; do not re-pin it.
   Stage D alone performs the explicitly scoped baseline transition
   described in D4, preserving this marker and its mutation proof.

### Rollback

1. Revert surface/elab.ml to its pre-Stage-A state (the diff is confined
   to `inst_domain`, `inst_applied` and `synth`'s local arm; no other
   function in the file is touched).
2. Delete `dev/m8a/local-spine-holed.tot`,
   `dev/m8a/local-spine-explicit.tot` and `dev/m8a/bare-lambda-holed.tot`.
3. Remove the four new gate legs from dev/gates.sh, in reverse order of
   insertion (PASS-M8A-KERNEL-UNCHANGED first, PASS-M8A-LOCAL-SPINE-SYNTH
   last), so a partial revert never leaves a later leg referencing a
   fixture or marker an earlier revert step already removed.
4. Remove the four new test/surface.ml cases.
5. Re-run `rg -o 'echo PASS-[A-Z0-9-]+' dev/gates.sh | wc -l` and
   confirm it reads 166 again, and `rg -c 'PASS-M8' dev/gates.sh` again
   prints nothing, confirming the namespace is clean for a later
   attempt.

Gate markers added: 4
Suite cases added: 4
Exit PASS count: 428 slice, 432 wrapper (ESTIMATE)

# M8 plan slice: STAGE B

Scope note.  This file is one slice of dev/M8-PLAN.md.  It covers only
STAGE B, prelude:94 and the three literals.  It assumes STAGE A has
already landed and closed green, at entry 420 to exit 428 slice (424 to
432 wrapper) (ESTIMATE), with the new local-aware instantiation live in
surface/elab.ml and stdlib/prelude.tot still byte-identical to HEAD.
Every citation below is read from the working tree on 2026-09-05, which
is HEAD 8cf0b8b plus the unstaged M7 Stage E diff (`git -C
/Users/oobi/Documents/tot diff`), unless marked otherwise.  stdlib/
prelude.tot, surface/elab.ml and surface/serror.ml are NOT touched by
that diff, so a citation into any of the three is HEAD content at its
current (working-tree) line number.  dev/gates.sh IS touched by the
diff; every dev/gates.sh line cited below was read directly from the
working tree with `awk NR==` or `rg -n` on 2026-09-05, so its line
number already accounts for the diff's four hunks, and is marked
"(current tree)".

## STAGE B: prelude:94 and the three literals

### Goal

Stage A taught `synth`'s local arm to read a type off a local-headed
spine.  Stage B spends that rule on the one site it was built for:
stdlib/prelude.tot:94, the `cong0` congruence motive, whose two
informative later arguments are `f a` and `f z`, spines headed by the
local binder `f` (stdlib/prelude.tot:93).  The stage re-spells the
motive's `Eq B` to `Eq _` and re-measures three literals that move by
one if the re-spell succeeds.  This is the acceptance test of C5, not a
separate change: a C5 that does not re-spell this line has not reached
the class it claims to widen (verdict, /Users/oobi/Documents/tot-m8-design-verdict.md,
section "C5.  The infer-position hole", and section 1, "That is real
elaborator work with an executable acceptance test at
stdlib/prelude.tot:94").

R-Q7 governs the failure path and this stage states it up front: if
Stage A is green and stdlib/prelude.tot:94 still refuses the `_`
spelling, Stage B STOPS.  It does not retry with a different spelling,
does not touch the kernel, and does not keep a half-applied edit in the
tree.  It books a conflict note in the C-D3 shape and waits for a user
ruling, because a retreat from the re-spell is a user ruling only
(dev/M7-BUILD-LOG.md:2340-2341, "Plan D8 ... makes any retreat from the
re-spell a user ruling and not a builder decision").

Stage B changes one source line, edits two gate literals inside
SURVIVING legs, adds one new gate leg, and adds two suite cases.  It
touches no kernel file.  A third leg, PASS-M8B-RESPELL-COUNT, was
dropped per R-F3: it re-ran `rg -c 'anchor=\[_\]'` against the same
hole-sites log PASS-M6E-GUARD-HOLES already reads, asserting the same
corpus-wide count under a new name, so the same one-edit mutation that
reddened it also reddened the surviving M6E leg first.  That count is
now carried by the in-place edit to dev/gates.sh:3167 alone.

### Rulings covered

R-Q7, verbatim (/Users/oobi/Documents/tot-m8-ratifications.md):

> R-Q7: if stdlib/prelude.tot:94 still refuses its re-spell after Stage A
> lands green, Stage B STOPS and books a conflict note in the C-D3
> shape.  A retreat from the re-spell is a user ruling only
> (dev/M7-BUILD-LOG.md:2340-2341).

C-D3, the carried conflict-note shape (/Users/oobi/Documents/tot-m8-ratifications.md,
"Carried rulings"; the shape itself is dev/M7-BUILD-LOG.md:2311-2341):
a predicted count or edit that the repo refuses is recorded as MEASURED,
with the plan's prediction, the measured value, and the resolution,
never silently retried or silently kept.  Stage B is the stage this
carried ruling was written for: it is the exact site C-D3 already fired
on once, in M7 Stage D.

R10, verbatim (/Users/oobi/Documents/tot-m8-ratifications.md, "Carried
rulings"): one edit per mutation proof, and no two legs share a
mutation proof.  Stage B's one gate leg below names a distinct
one-edit mutation.

R11, verbatim: the PASS-M8 namespace must be unused before this scope.
That milestone-wide check belongs to Stage A entry. At Stage B entry,
`rg -c 'PASS-M8B-' /Users/oobi/Documents/tot/dev/gates.sh` must match
nothing, while Stage A's four markers remain present.

C-A14, verbatim: the wrapper count adds 4 over the gate slice.  Stage
B's exit is stated both ways: 431 slice, 435 wrapper (ESTIMATE).

### Entry state

Entry is 428 for the gate slice, 432 as the wrapper prints it
(section 2.1 of this plan, Entry and the stage chain, the recount that
replaces the sketch; design-verdict.md:171, table row A, is the
superseded sketch row and reads 429 / 433; ESTIMATE, re-measured per
stage per the verdict's own count-honesty note).  Stage A leaves the tree with:

- surface/elab.ml's local arm at line 401 replaced by a new,
  local-aware instantiation that keeps free locals (design-verdict.md
  section 1, "the repair is a new local-aware instantiation that
  preserves free locals rather than a reuse of `inst_applied`").  At the
  time this slice was written, Stage A has not yet landed, so the
  working tree still reads, at surface/elab.ml:401 (current tree,
  unmodified by the Stage E diff):

  ```
  | Term.Var ix -> ( match applied with [] -> local_ty locals ix | _ :: _ -> None)
  ```

  Stage A's own slice owns rewriting this line; Stage B's design below
  assumes the rewrite has happened and the local-headed spine `f a` /
  `f z` now resolves a type the way a global-headed spine already does.
- stdlib/prelude.tot unedited: Stage A touches no corpus file
  (design-verdict.md:194-195, "Nothing else moves").  Confirmed at
  stdlib/prelude.tot:92-94 (current tree):

  ```
  reducible def cong0 : (0 A : Type 0) -> (0 B : Type 0) -> (0 a : A) -> (0 b : A) ->
      (0 f : A -> B) -> (0 h : Eq A a b) -> Eq B (f a) (f b) :=
    fun A B a b f h => subst0 A a b (fun z => Eq B (f a) (f z)) h (refl B (f a))
  ```

  Line 94 still carries the explicit `Eq B`, which is Stage B's own
  payload to change.
- dev/gates.sh carries the two SURVIVING legs whose literals Stage B
  edits: `PASS-M6E-GUARD-HOLES` (current tree, assignment at
  dev/gates.sh:3161, assertion `[ "$m6e_holes" -eq 68 ]` at
  dev/gates.sh:3167) and `PASS-M7D-PRELUDE-HOLES` (current tree,
  assignments at dev/gates.sh:3789-3790, assertion
  `[ "$m7d_ph" -eq 46 ] && [ "$m7d_pa" -eq 5 ]` at dev/gates.sh:3792).
  Both literals are pre-C-D3 values: 44 re-spells, 68 corpus-wide holed
  anchors, 46 prelude-holed anchors (dev/M7-BUILD-LOG.md:2336-2338).
- The classifier's summary line is pinned verbatim by `PASS-M7D-ANCHORS`
  (current tree, dev/gates.sh:3802-3806):
  `ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30`.
- test/surface.ml's `cases` list ends, at the current tree, with the M7
  Stage E entries, the last one closing at test/surface.ml:2273 followed
  by the list's closing bracket at test/surface.ml:2274.  Stage B's two
  new cases are inserted there.
- No PASS-M8B-* marker exists yet; Stage A's four markers remain (R11).

### Files touched

- `stdlib/prelude.tot` (line 94): the one source edit, restated in
  Design below.
- `dev/gates.sh`: two literal edits inside the surviving legs
  `PASS-M6E-GUARD-HOLES` and `PASS-M7D-PRELUDE-HOLES`, plus one new
  leg, `PASS-M8B-PRELUDE-94`.
- `dev/M8-BUILD-LOG.md` (new file if Stage A did not already create it):
  Stage B appends either a closing note that C-D3 is now resolved (the
  re-spell succeeded) or a fresh conflict note in the same C-D3 shape
  (the re-spell still refuses), per R-Q7.  This file does not exist yet
  (`ls /Users/oobi/Documents/tot/dev/M8-BUILD-LOG.md` printed "No such
  file or directory" on 2026-09-05), so if Stage A did not create it,
  Stage B creates it.
- `test/surface.ml`: two new entries in the `cases` list
  (test/surface.ml:1122), inserted after the M7E-5 entry at
  test/surface.ml:2269-2273, reusing the `Tot_surface.Run.script
  ~st:bst ~exec:false` in-process shape that `m7e_expect_source_checks`
  and `m7e_expect_source_error` already use (test/surface.ml:702-727), so
  no new tracked fixture file is added under test/fixtures/ and no
  transcript reseal is owed (the M7 Stage D reseal convention,
  dev/gen-m5e-transcript.sh, is keyed to the `examples/*.tot` and
  `test/fixtures/*.tot` glob, which an inline `~src` string never
  enters).

No `lib/` file is touched.  Stage B is elaborator-and-corpus-only, the
same footprint the verdict describes for Stages A to C
(design-verdict.md:117-118, "Stages A to C of this scope edit
surface/elab.ml, stdlib/prelude.tot, surface/run.ml and bin/tot.ml and
touch lib/ not at all").

### Design

The payload is one line.  stdlib/prelude.tot:94 changes from:

```
  fun A B a b f h => subst0 A a b (fun z => Eq B (f a) (f z)) h (refl B (f a))
```

to:

```
  fun A B a b f h => subst0 A a b (fun z => Eq _ (f a) (f z)) h (refl B (f a))
```

The one changed token is the first argument of the motive's `Eq`, at
line 94, inside the `fun z => ...` body.  Nothing else on the line
moves; the two `refl B (f a)` occurrences at the end of the line and
the `Eq B (f a) (f b)` in the signature at line 93 stay spelled out,
because they are already outside the class this stage widens (the
signature's `Eq B` is a declared result type, bucket E already, and
would not gain anything from a hole; `refl`'s `B` argument is
`refl`'s own family, unaffected by `cong0`'s motive).

Why this one hole is the whole payload, and why it needed Stage A
first: `subst0`'s motive argument, `fun z => Eq _ (f a) (f z)`, is a
lambda passed in an ARGUMENT position of `subst0`.  The elaborator
reaches the hole inside that lambda body while checking the lambda,
which is check position for the outer `Eq` application but the inner
`_` itself sits where `synth` must read a type off `f z` to satisfy the
occurs-check pattern-unification that recovers the motive
(surface/elab.ml's higher-order pattern unification for `subst0`,
already present pre-M8).  `f` is a LOCAL (the fifth positional binder
of `cong0`, stdlib/prelude.tot:92), and `f z` is a local head applied to
one argument.  Before Stage A, `synth`'s local arm
(surface/elab.ml:401, current tree) refuses any applied local spine:

```
| Term.Var ix -> ( match applied with [] -> local_ty locals ix | _ :: _ -> None)
```

`None` here is the exact refusal C-D3 recorded: "the motive body
reaches the elaborator in infer position ... and no expected type
arrives" (dev/M7-BUILD-LOG.md:2318-2327).  `surface/serror.ml:94-95`
turns that `None` into the "hole: no expected type at this position"
message a builder sees today if line 94 is hand-edited to `Eq _`
without Stage A.  Stage A's new local-aware instantiation
(design-verdict.md section 1) is built to return `Some` here instead,
by resolving `f`'s local type and instantiating it against the one
supplied argument `z`, the same shape of resolution `inst_applied`
already gives a global head, but done without `inst_applied`'s de
Bruijn arithmetic (`p = j - 1 - (i - d)`, surface/elab.ml:212),
which returns a negative `p`, hence `None`, for a free local index
(the A1-F1/A1-F2 findings, design-verdict.md:366-371).

Stage B's own job is narrow: apply the one-line edit, then RE-MEASURE
(never assume) the three literals the verdict names as the acceptance
signal, plus re-measure the `m7d_pa` literal the surviving leg also
asserts, because the classifier's bucket for this site does not change
even though its raw spelling does (dev/hole-anchors.py:409-418,
`record()`: bucket is `N` if the head's family is "proof" or "class",
or the position is infer; else `E` if the formal appears in the head's
own declared result type; else `A`; none of those three inputs, head
family, position label, or result-type membership, reads the anchor's
literal spelling, so a pure `_`-respelling of one site cannot move the
`ANCHORS total=...` summary line by itself).  The three moving
literals are:

1. Re-spell count, 44 to 45.  This is a corpus-wide count of anchors
   that took the `_` spelling instead of an explicit type, kept in
   dev/M7-BUILD-LOG.md:2336-2338 and re-derived by counting `anchor=[_]`
   lines in the hole-sites log the same way `PASS-M6E-GUARD-HOLES`
   already does (dev/gates.sh:3161, current tree):
   `m6e_holes=$(rg -c 'anchor=\[_\]' "$m5d_scratch/hole-sites.txt")`.
   Stage B edits the literal at dev/gates.sh:3167 (current tree,
   `[ "$m6e_holes" -eq 68 ]`) from 68 to 69, because the corpus-wide
   holed-anchor count and the re-spell count move together: one new
   site takes `_` where it took an explicit spelling before.
2. `m6e_holes`, pinned at dev/gates.sh:3167 (current tree), 68 to 69,
   the same edit as item 1 (the two counts are the same measurement
   read by two different names in the verdict's own list; Stage B
   makes one edit, not two, at this line).
3. Prelude-holed count, pinned inside `PASS-M7D-PRELUDE-HOLES`
   (dev/gates.sh:3789, current tree,
   `m7d_ph=$(rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\]' ...)`),
   asserted at dev/gates.sh:3792 (`[ "$m7d_ph" -eq 46 ] && ...`).  Stage
   B edits 46 to 47, the prelude-only slice of the same one-site move.

Pin 10's classifier literal, `PASS-M7D-ANCHORS`
(dev/gates.sh:3802-3806, current tree, `ANCHORS total=99
expected-type-only=60 argument-driven=9 neither=30`), is NOT edited.
The site's bucket was already E before the respell (design-verdict.md's
own citation of C-D3: "despite the classifier's static
`pos=check bucket=E` label"), and `record()`'s bucket logic
(dev/hole-anchors.py:409-418) never reads the literal spelling, only
the head, argument index, and position, none of which the edit
changes.  Stage B's design keeps this leg green with no edit, since the
classifier's ANCHORS summary line depends only on inputs the re-spell
does not touch.

The surviving `PASS-M7D-PRELUDE-HOLES` leg also asserts `m7d_pa -eq 5`
(dev/gates.sh:3790,3792, current tree,
`m7d_pa=$(rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\].*bucket=A' ...)`).
The re-spelled site is bucket E, not bucket A (line 94's `_` sits in a
position that appears in `cong0`'s own declared result type, `Eq B
(f a) (f b)`, once `B` is fixed by the earlier explicit argument), so
this literal is RE-MEASURED, not assumed, and is expected to stay 5.
If the measured value differs, Stage B records a conflict note in the
C-D3 shape for `m7d_pa` specifically, the same discipline R-Q7 applies
to the headline re-spell.

R-Q7's stop condition is checked before either of the two literal edits
above is made permanent: Stage B first applies the one-line edit
described here, then runs the corpus classifier and the elaborator
test suite.  If stdlib/prelude.tot:94 elaborates cleanly with `Eq _` in
place, the two literal edits proceed and the one new gate leg is
added.  If it still returns the `surface/serror.ml:94-95` "no expected
type" message (or any elaboration error), Stage B reverts the one-line
edit, leaves both literal edits at their pre-Stage-B values, adds no
new gate leg, and writes a conflict note to
dev/M8-BUILD-LOG.md in the C-D3 shape, naming the predicted values (45,
69, 47), the measured values (unchanged at 44, 68, 46), and the
resolution (waiting on a user ruling per R-Q7).  In the STOP branch,
Stage B's exit equals its entry: no PASS count moves, and the stage's
own trailing lines report 0 gate markers and 0 suite cases added, not
the 1/2 the success branch counts (the reconciler recounts the trailer
below).

The rest of this design assumes the success branch, since that is the
branch the verdict's payload, marker names, and counts describe.

### Gate additions

The new leg goes into dev/gates.sh right after the last M7 leg,
`PASS-M7E-DEBT-H` (its echo is the current tree's line 3975, its
closing brace and FAIL line at 3976, current tree), and before the
pre-existing legacy block that starts at line 3978 (current tree,
comment "ctxcat id 5") leading into `PASS-M4FIX-INST-BRANCHING`.  That
legacy block's own comment states it must stay the file's last leg, so
Stage B's insertion point is immediately after 3976 and before 3978,
the same slot Stage E itself used ahead of it.  The leg reuses
the scratch variables `$m5d_bin`, `$m5d_scratch`, `$watchdog`, `$FAST`
and `$GATE_LOG` that earlier legs in the same file already establish
(seen live in `PASS-M6E-GUARD-HOLES` and `PASS-M7D-PRELUDE-HOLES`,
dev/gates.sh:3140-3168 and 3779-3795, current tree), so no new
scaffolding is added.  The leg follows the file's own convention: one
`echo PASS-<NAME>` on success, a `FAIL-<NAME> (...)` line with the
measured values on failure, `exit 1` on failure.

Marker: PASS-M8B-PRELUDE-94
Ruling: R-Q7
Command: `python3 /Users/oobi/Documents/tot/dev/hole-anchors.py --log /Users/oobi/Documents/tot-m8-probes/plan/hole-sites.txt > /dev/null 2>&1; rg -c 'SITE stdlib/prelude\.tot:94.*anchor=\[_\]' /Users/oobi/Documents/tot-m8-probes/plan/hole-sites.txt || echo 0`
Before the stage: exit 0, output contains "0" (PREDICTED)
After the stage: exit 0, output contains "1"
MUTATION: stdlib/prelude.tot:94, restore the explicit spelling,
changing `Eq _ (f a) (f z)` back to `Eq B (f a) (f z)` (R10)
Non-vacuous because: the SITE line for stdlib/prelude.tot:94 only
carries `anchor=[_]` when the re-spell is in the tree; reverting the
one token makes the count fall back to 0 and the leg red.

In dev/gates.sh, this leg reads (new text, added after line 3976,
current tree):

```
# PASS-M8B-PRELUDE-94 (R-Q7).  stdlib/prelude.tot:94's cong0 motive
# takes the `_` spelling now that Stage A's local-aware instantiation
# resolves the local-headed spine `f z`.  One SITE line in the
# classifier's log carries anchor=[_] at that exact source line.
m8b_p94=$(rg -c 'SITE stdlib/prelude\.tot:94.*anchor=\[_\]' "$m5d_scratch/hole-sites.txt" || echo 0)
{ [ "$m8b_p94" -eq 1 ]; } \
  && echo PASS-M8B-PRELUDE-94 \
  || { echo "FAIL-M8B-PRELUDE-94 (p94=$m8b_p94)"; exit 1; }
```

R-F3 drops a third candidate leg here, PASS-M8B-RESPELL-COUNT, which
would have re-run `rg -c 'anchor=\[_\]'` against the same
`$m5d_scratch/hole-sites.txt` log and asserted the same corpus-wide
count of 69 that the in-place edit at dev/gates.sh:3167 already
asserts inside the surviving `PASS-M6E-GUARD-HOLES` leg.  Its
observable was not its own: the one-edit mutation that would turn it
red (hand-holing a further site) reddens `PASS-M6E-GUARD-HOLES` first,
since both legs read the identical count.  The corpus-wide count stays
pinned once, at dev/gates.sh:3167.

PASS-M7D-ANCHORS already owns the anchors summary line, and Stage B
predicts no move in it.

### Suite cases

Both cases use the existing in-process helpers `m7e_expect_source_checks`
and `m7e_expect_source_error` (test/surface.ml:702-716 and 720-727,
current tree), which build a `Tot_surface.Run.script ~st:bst
~exec:false src` and read the result, where `bst` is the suite's
already-bootstrapped state (prelude auto-loaded once for the whole
run, the in-process equivalent of `bin/tot.exe`'s default auto-load,
dev/gates.sh:160).  Per R-F5, each case is written in the tree's own
labelled-pair shape: the `bst` positional argument, the `~label:`
argument, and the trailing `()` the helper's signature ends on, inside
a `(string * (unit -> (unit, string) result))` pair, copied from
test/surface.ml:2270-2273.  The two helper signatures being copied read
(test/surface.ml:702-703 and 720-721, current tree):

```
let m7e_expect_source_error (bst : Tot_surface.Run.state) ~(label : string) ~(src : string)
    ~(want_suffix : string) () : (unit, string) result =
```

```
let m7e_expect_source_checks (bst : Tot_surface.Run.state) ~(label : string) ~(src : string) () :
    (unit, string) result =
```

`m7e_expect_source_error` takes `~want_suffix:`, not `~contains:`; no
helper in the tree declares a `~contains:` label.  Both cases are
inserted into the `cases` list (test/surface.ml:1122) between the
M7E-5 entry (closing at test/surface.ml:2273) and the list's closing
bracket (test/surface.ml:2274), so `cases` gains exactly two elements,
each a `( "label text", <partial application> )` pair whose second
component already has type `unit -> (unit, string) result` once `bst`,
`~label:` and `~src:` (and, for case 2, `~want_suffix:`) are supplied,
so no explicit trailing `()` literal appears at the call site, the same
shape test/surface.ml:2270-2273 uses.  Neither case needs a new tracked
fixture file, since both pass their source inline; this avoids the
transcript-reseal obligation that a new file under test/fixtures/ or
examples/ would carry.

Case 1: cong0 still elaborates and still evaluates.

```
( "M8B-1: cong0 still elaborates and evaluates under the re-spelled motive",
  m7e_expect_source_checks bst ~label:"m8b-cong0-elaborates"
    ~src:{tot|
def transported : Eq Nat (add 1 2) (add 2 1) :=
  cong0 Nat Nat (add 1 2) (add 2 1) (fun x => x) (refl Nat 3)
|tot} );
```

`bst` auto-loads stdlib/prelude.tot for every case in the list, so this
one entry already exercises the changed line 94 twice: once when the
shared prelude is elaborated (proving `cong0`'s own body, including
the re-spelled motive, still type-checks with `Eq _` in place), and
again when `transported`'s declared type is checked against the
application's reduced form.  The second check forces the elaborator's
conversion checker to unfold `cong0` (it is `reducible`,
stdlib/prelude.tot:92) down through `subst0` and the motive body at
line 94, so a wrong or ill-typed motive would show up here as a
conversion failure, not just a load-time success.  This is not a
duplicate of the PASS-M8B-PRELUDE-94 gate leg: that leg reads the
classifier's static log and never runs the elaborator on the changed
body; this case is the only place in the plan that actually elaborates
and reduces `cong0` post-edit.

Case 2: the one-hole message for a genuinely undetermined site is
unchanged.

```
( "M8B-2: the one-hole message for a genuinely undetermined site is unchanged",
  m7e_expect_source_error bst ~label:"m8b-hole-still-refused"
    ~src:{tot|
def stuck : Nat := (fun x => x) _
|tot}
    ~want_suffix:"hole: no expected type at this position" );
```

The hole here is the sole argument of an applied LAMBDA literal, not an
applied local VARIABLE.  Stage A's fix (design-verdict.md section 1)
only widens `synth`'s `Term.Var ix` arm (surface/elab.ml:401); it does
not touch how a hole is checked against an applied `Term.Lam`, so this
site stays genuinely undetermined after both Stage A and Stage B land,
and `surface/serror.ml:94-95` still produces the same message text.
This is not a duplicate of any gate leg: the new leg does not run the
elaborator on a fresh source string, and this case is the only
place in the plan that confirms the error message's wording, not just
a count, survives the stage untouched.

### Review checklist

- stdlib/prelude.tot:94 reads `Eq _ (f a) (f z)` and no other token on
  that line moved.
- stdlib/prelude.tot:93 and the `refl B (f a)` spellings on line 94 are
  untouched.
- dev/gates.sh:3167's `m6e_holes` literal reads 69, not 68.
- dev/gates.sh:3792's `m7d_ph` literal reads 47, not 46, and `m7d_pa`
  was re-measured, not assumed, before being left at 5 or updated.
- dev/gates.sh:3802-3806's `PASS-M7D-ANCHORS` literal is untouched,
  still `ANCHORS total=99 expected-type-only=60 argument-driven=9
  neither=30`.
- The new leg sits after `PASS-M7E-DEBT-H` (dev/gates.sh:3976,
  current tree) and before the legacy `PASS-M4FIX-INST-BRANCHING` block
  (dev/gates.sh:3978, reference tree), and no `PASS-M8B-` marker
  existed before this stage. Stage A's four markers remain present.
- The new leg has a mutation proof.
- test/surface.ml's `cases` list gained exactly two entries, both
  using inline `~src` strings, no new file under test/fixtures/ or
  examples/.
- Both new `cases` entries take the `bst` positional argument, the
  `~label:` argument and the trailing `()` the helper signature ends
  on, and case 2 uses `~want_suffix:`, never `~contains:`.
- If R-Q7's stop path fired, dev/M8-BUILD-LOG.md carries a conflict
  note in the C-D3 shape naming the predicted and measured values, and
  none of stdlib/prelude.tot, dev/gates.sh's two literal edits, or
  test/surface.ml's case list were left half-edited.

### Rollback

Revert stdlib/prelude.tot:94 to `Eq B (f a) (f z)`.  Revert the two
literal edits at dev/gates.sh:3167 and dev/gates.sh:3792 to 68 and 46.
Delete the new gate leg (`PASS-M8B-PRELUDE-94`) between the
`PASS-M7E-DEBT-H` close and the legacy `PASS-M4FIX-INST-BRANCHING`
block.  Remove the two new entries from test/surface.ml's `cases` list.
If a conflict note was written to dev/M8-BUILD-LOG.md, leave it in
place; a conflict note is a record of a measurement, not a change to
roll back, and deleting it would erase the evidence R-Q7's STOP branch
exists to preserve.

Gate markers added: 1
Suite cases added: 2
Exit PASS count: 431 slice, 435 wrapper (ESTIMATE)


## STAGE C: reporting, items 8, 9 and 10

### Goal

Close three M7 hand-off debts about what the driver PRINTS: the shape of
the multi-hole reporting tail (item 8), the missing gate route for
`test/fixtures/s0-erased-guard.tot` (item 9), and the prelude arm's own
multi-hole tail on the miss path (item 10). Stage A has edited the
elaborator; no preceding stage has edited the kernel. Stage C adds no
admission rule and no new elaboration itself. It touches
`stdlib/prelude.tot` not at all: Stage B owns the one prelude edit
(`stdlib/prelude.tot:94`), and Stage C runs only after Stage B lands green, with a FIXED
prelude. If Stage B stops under R-Q7, Stage C does not open (8.3).

### Rulings covered

- R-Q5 (ratified): "item 8 is Option A. Report hole POSITIONS only,
  never a synthesized type. This closes
  `/Users/oobi/Documents/tot/dev/M7-PLAN.md:966-972`." Stage C pins this
  as the closed decision; it changes no code, because
  `surface/run.ml:654-661` (`hole_tail`) already reports positions only
  and never a synthesized type.
- R-Q6 (ratified): "no stage bumps `Cache.format_version` from 10
  (`dev/gates.sh:3814` and `:3820`). Stage C changes reported text
  only." At the current tree (HEAD plus the unstaged Stage E diff) the
  same assertion lives at `dev/gates.sh:3815` (comment) and
  `dev/gates.sh:3831` (`m7d_fv=$(rg -c 'let format_version : int = 10'
  "$ROOT"/surface/cache.ml)`, checked at `dev/gates.sh:3837`, whose
  `echo PASS-M7D-CACHE-KEY` follows at `dev/gates.sh:3838`), a few lines later than the ratification's own
  citation because the unstaged Stage E diff inserts lines earlier in
  the file (hunks at `dev/gates.sh:2307`, `:2565`, `:3573`). Stage C
  touches neither `surface/cache.ml:118` (`let format_version : int =
  10`) nor either gate line; it only changes text a driver PRINTS.
- Carried ruling C-D3 (conflict-note shape): if a stage that precedes
  Stage C left a booked conflict note instead of a landed edit, Stage C
  reads the note and does not retry the refused mutation. Stage C's own
  design books no new conflict note; the shape is inherited from Stage B
  only if Stage B needed it.
- Carried ruling R10 (one edit per mutation proof, no two legs share a
  mutation proof): honoured below; each of the 3 markers names a
  distinct file-and-line target.
- Carried ruling R11 (the PASS-M8 namespace must be unused before this
  milestone): at Stage C entry check `rg -c 'PASS-M8C-'
  /Users/oobi/Documents/tot/dev/gates.sh` exits 1 with no output. The
  four Stage A and one Stage B markers must remain present.
- Carried ruling C-A14 (the wrapper count adds 4 over the gate slice):
  Stage C's own exit line follows this convention.

### Entry state

Entry is 431 for the gate slice, 435 as the wrapper prints it (verdict
stage table, `dev/gates.sh`-derived arithmetic: entry 420/424 at Stage A,
+4 markers +4 cases at A, +1 marker +2 cases at B, landing at 431/435
before Stage C). This plan slice does not itself measure Stage A's and
Stage B's landed counts, since those stages run first; the builder
re-derives the true entry count with one full `dev/gates.sh` run
immediately before Stage C starts and records it in
`dev/M7-BUILD-LOG.md`, the same discipline `dev/M7-PLAN.md`'s own Stage
A entry section uses.

What Stage C finds already in the tree, independent of Stage A and
Stage B: `surface/serror.ml:91-95` (the `Hole` branch of `Serror.to_string`,
unchanged since M6/M7), `surface/run.ml:629-661` (`reported_hole`,
`loc_order`, `loc_equal`, `hole_tail`, all M7 Stage C work), and
`surface/run.ml:668-685` (`script_tailed`), none of which Stage A or
Stage B touches (Stage A's source file is `surface/elab.ml`; its `lib/check.ml`
mutations are temporary proofs. Stage B edits `stdlib/prelude.tot`). This
independence claim is scoped to SOURCE files only: Stage C claims no
independence over `dev/gates.sh` or `test/surface.ml`, since Stage A,
Stage B and Stage C each add their own legs and cases to both of those
files. `bin/tot.ml:179-181`
(`run_with_prelude`'s prelude-error arm) prints one line only, verified
at the current tree. `test/fixtures/s0-erased-guard.tot` exists with 5
lines (below) and reaches the CLI only via `--no-prelude`, and
`dev/gates.sh` has no `s0-erased-guard` leg (`rg -c 's0-erased-guard'
/Users/oobi/Documents/tot/dev/gates.sh` exits 1). `dev/m5e-default-transcript.txt`
carries 105 blocks (`rg -c '^### ' /Users/oobi/Documents/tot/dev/m5e-default-transcript.txt`)
and already has its own block for `test/fixtures/s0-erased-guard.tot`
(`### test/fixtures/s0-erased-guard.tot` at line 10324), because the
generator's `check` mode auto-loads the real, valid prelude and the
fixture's own redeclared `Nat` fails as an ordinary SCRIPT error
(`bin/tot.ml`'s target-path arm, not the prelude arm), which Stage C
does not touch.

The unstaged Stage E diff (`git -C /Users/oobi/Documents/tot diff`)
touches `README.md`, `SPEC.md`, `dev/M7-BUILD-LOG.md`, `dev/gates.sh`,
`dev/m5e-default-transcript.txt`, `lib/check.ml` and `test/surface.ml`,
plus three new untracked fixtures under `test/fixtures/m7e-*.tot`. It
does NOT touch `surface/bootstrap.ml`, `surface/run.ml`,
`surface/serror.ml`, `bin/tot.ml`, `lib/erase.ml`, `lib/eterm.ml` or
`test/fixtures/s0-erased-guard.tot`, so every citation into those seven
files below is HEAD content unchanged by Stage E, and the working tree
equals HEAD for them. Every citation into `dev/gates.sh` and
`test/surface.ml` below is read directly from the working tree (HEAD
plus the Stage E diff applied), which is the correct reference state.

### Files touched

- `surface/bootstrap.ml`: gains one new function, `state_of_src_tailed`,
  built beside `state_of_src` (`surface/bootstrap.ml:381-396`), and
  widens `cached_state_of_src`'s error payload
  (`surface/bootstrap.ml:443-471`) from `Serror.t` to
  `Serror.t * string option`. No prelude phase, no phase split and no
  cache key changes. The existing cached_state wrapper maps the widened
  error with Result.map_error fst to preserve its untailed signature.
- `bin/tot.ml`: `run_with_prelude`'s prelude-error arm
  (`bin/tot.ml:179-181`) destructures the widened error pair and adds
  one `Option.iter prerr_endline tail` call, the exact expression
  `bin/tot.ml:121` already uses for the target-path arm. No other arm of
  `bin/tot.ml` changes.
- `dev/gates.sh`: one new block, 3 markers, placed after the M7 Stage E
  block closes (`PASS-M7E-DEBT-H`'s `FAIL` arm ends at
  `dev/gates.sh:3976`) and after Stage A's and Stage B's own blocks land
  there first, and before the two legs the file's own comments pin as
  LAST with nothing downstream, `PASS-M4FIX-INST-BRANCHING`
  (`dev/gates.sh:4012`) and `PASS-M5B-BRANCHING-20`
  (`dev/gates.sh:4031`).
- `test/surface.ml`: 3 new tuples appended to the `cases` registry
  (closes at `test/surface.ml:2274` in the current tree).
- No file under `lib/` is touched. `surface/serror.ml`,
  `surface/elab.ml`, `stdlib/prelude.tot` and every fixture except the
  new gate-scratch files below are untouched.
- No new fixture under `test/fixtures/` or `examples/`, so
  `dev/m5e-default-transcript.txt`'s glob
  (`examples/*.tot test/fixtures/*.tot`, `dev/gen-m5e-transcript.sh:13`)
  gains no new block from Stage C, and the new gate-only fixture
  `dev/fixtures/m8c-hole-positions.tot` sits outside that glob entirely.
  `dev/m5e-default-transcript.txt` itself is NOT edited by Stage C's
  source changes (see Design, item 10, for why the new code path is
  unreachable by the transcript corpus). R3-F3 MEASURED this against the
  staged tree rather than assuming it: no existing gate leg's transcript
  literal moves either (see item 10's Design paragraph and the exit
  checklist below), so the reseal lands as an item-10 obligation with no
  in-place literal edit anywhere in this file list.

### Design

**Item 8, per-hole expected types, Option A, no code change.**
`Serror.t`'s `Hole` variant carries `loc : Loc.t` and
`expected : (string list * Tot_kernel.Term.t) option`
(`surface/serror.ml:55-58`), and `Serror.to_string`'s `Hole` arm prints
either `hole: expected <type>` from a `Some` payload or
`hole: no expected type at this position` from `None`
(`surface/serror.ml:91-95`). The multi-hole tail is built beside it, in a
different module: `surface/run.ml:629-636` (`reported_hole`) reads the
one `Loc.t` a `Hole` error already carries, and
`surface/run.ml:654-661` (`hole_tail`) folds every OTHER recorded hole
position from the same item into one line,
`"%d more hole(s) at %s"`, positions only, never a second expected type.
Option A is: keep this shape exactly, and never add a per-hole expected
type to the tail or a third field to `Hole`. Stage C makes no edit here;
it adds one gate leg that pins the shape under the M8 namespace, closing
the decision `dev/M7-PLAN.md:966-972` left open, and it exercises a
THREE-hole item (an N greater than the two-hole M7C fixture already
pins), showing the fold is general over the list length and not
hardcoded to two.

**Item 9, the s0-erased-guard driver gap, gate-side only.**
`test/fixtures/s0-erased-guard.tot` is 5 lines:

```
data Nat : Type 0 := | zero : Nat | succ : Nat -> Nat
def dropErased : (0 j : Nat) -> Nat -> Nat := fun j n => n
def rec ghost : (0 j : Nat) -> Nat -> Nat := fun j n => dropErased (match j with | zero => zero | succ jp => ghost jp n end) n
eval ghost
eval ghost zero (succ zero)
```

Because line 1 redeclares `Nat`, the fixture fails under the DEFAULT
(prelude-auto-loading) driver with `Duplicate_global`, and the only
place it runs successfully at HEAD is through
`test/surface.ml:216-224`'s `expect_cli_run_lines`, whose
`?(no_prelude = true)` default appends ` --no-prelude` to the shelled
CLI command, called on this fixture at `test/surface.ml:1401` (the "T0"
case). `rg -c 's0-erased-guard' /Users/oobi/Documents/tot/dev/gates.sh`
exits 1: the battery has never run it. The in-process assertion at
`test/surface.ml:629-641` (`case_ghost_guard_is_unguarded`) folds the
fixture with `Run.script_items`, reads `ghost`'s kernel `rec_arg`, and
asks `Run.compute_guard` (`surface/run.ml:103-121`) what runtime guard
it computes, expecting `Interp.Unguarded`. The comment at
`test/surface.ml:105-108` names the reason this fixture exists at all:
it exercises the ERASED-formal branch of erasure, `Term.App
(Quantity.Zero, f, _a) -> term ctx f` at `lib/erase.ml:33`, which drops
`ghost`'s only self-reference (buried inside the erased first argument
to `dropErased`, the match on `j`) WHOLESALE, so
`Eterm.mentions "ghost" def_e` (`lib/eterm.ml:32-42`) sees no mention
and `compute_guard`'s `Quantity.Zero` arm
(`surface/run.ml:117-120`) answers `Unguarded`.

Stage C adds a gate leg that runs the fixture the way the suite already
does, `tot.exe run --no-prelude`, as a positive control in the battery
itself. Its MUTATION does not touch the leg's own command line (finding
A1-F6): it mutates the ERASED branch in `lib/erase.ml:33` so erasure
walks into the dropped argument instead of skipping it. That argument is
`match j with | zero => zero | succ jp => ghost jp n end`, a TWO-branch
match on the `Quantity.Zero`-quantity scrutinee `j`; `Erase.term`'s own
`scrut_q = Quantity.Zero` arm (`lib/erase.ml:49-64`) accepts zero or one
branch only (`lib/erase.ml:64`, `| _ :: _ :: _ -> Error (Error.Erased_use
"match")`) and is UNREACHABLE today because the caller drops the whole
argument first. Walking into it therefore turns
`Erase.closed dentry.Global.def` (`test/surface.ml:640`) into an
`Error`, which `case_ghost_guard_is_unguarded`'s own fold already turns
red, and the CLI leg goes red the same way because
`run_with_prelude`/`run_no_prelude` calls the identical kernel path.

**Item 10, the prelude arm multi-hole tail, re-scoped to the miss path.**
`Bootstrap.cached_state_of_src` (`surface/bootstrap.ml:443-471`) loads
the cache by `Cache.key src`; on a HIT it returns
`Ok { Run.globals; eglobals; lines = [] }` straight from the stored
pair; on a MISS its `~error` branch is
`let* st = state_of_src src in let () = Cache.save cache_key
st.Run.globals st.Run.eglobals in Ok st` (`surface/bootstrap.ml:468-471`).
`let*` short-circuits, so `Cache.save` runs only after `state_of_src`
SUCCEEDS: bytes that fail to elaborate are never stored under their own
key, so a hand-broken multi-hole prelude is a cache MISS on every run,
never warm. `Bootstrap.state_of_src` (`surface/bootstrap.ml:381-396`)
calls `Parser.parse tokens`, and `Parser.parse` is itself
`Result.map (List.map fst) (parse_with_holes ts)`
(`surface/parser.ml:708-709`): the parse walk that records every hole's
position ALREADY RUNS on every miss; `state_of_src` just throws the
positions away by keeping only `fst` of each pair.

Stage C adds `Bootstrap.state_of_src_tailed`, an OCaml value of type
`string -> (Run.state, Serror.t * string option) result`, built the same
way `Run.script_tailed` (`surface/run.ml:668-685`) is built from
`Run.item`: it calls `Parser.parse_with_holes` directly instead of
`Parser.parse`, keeps `state_of_src`'s existing three-phase split
(`split_after_name`, `surface/bootstrap.ml:308-317`, applied to the item
half of each pair) and folds each phase's items with a new
`Bootstrap.fold_prelude_items_tailed : Run.state -> (Syntax.item *
Loc.t list) list -> (Run.state, Serror.t * string option) result`, the
tailed sibling of `fold_prelude_items` (`surface/bootstrap.ml:333-338`),
whose only difference is mapping a fold error through
`Run.hole_tail ~holes e` (surface/run.ml has no `.mli`, so
`Run.hole_tail` is visible cross-module without a new export) exactly
the way `script_tailed`'s own fold does at `surface/run.ml:678-681`.
`Bootstrap.state_of_src` itself is UNCHANGED, so `Bootstrap.state ()`
(the in-band entry point `test/surface.ml` and `test/main.ml` call
directly) keeps its old signature and its old callers keep compiling
untouched.

`cached_state_of_src`'s error branch changes to call
`state_of_src_tailed` instead of `state_of_src`, and the function's own
return type widens to `(Run.state, Serror.t * string option) result`;
its `Ok` branch is untouched, because a cache HIT has no error to tail.
The wrapper at `surface/bootstrap.ml:473-475` must adapt too: keep
`cached_state () : (Run.state, Serror.t) result` and its existing source
read, then return `cached_state_of_src src |> Result.map_error fst`.
Only this compatibility wrapper discards the tail; the CLI calls the
tailed function directly. This avoids mixing `Source`/`Serror` failures
with the widened pair and preserves every existing untailed caller.
`bin/tot.ml`'s `run_with_prelude` (`bin/tot.ml:158-181`) destructures the
new pair at its `~error` arm, line 179-181, and after the existing
`prerr_endline ("prelude: " ^ Tot_surface.Serror.to_string e)` adds
`Option.iter prerr_endline tail`, the identical expression
`bin/tot.ml:121` already uses on the target-path arm. No cache field, no
`format_version` change (`surface/cache.ml:118` stays `let
format_version : int = 10`, R-Q6), no re-parse anywhere the code did not
already parse: `state_of_src_tailed` calls `Parser.parse_with_holes`
exactly once, in place of `state_of_src`'s one call to `Parser.parse`,
never twice.

Because none of the 105 files dev/gen-m5e-transcript.sh:13 walks (the
top-level `examples/*.tot` and `test/fixtures/*.tot` globs; fixtures in
subdirectories such as `test/fixtures/m7/` are not walked), MEASURED at
6bcc1b7, ever makes the REAL, valid
`stdlib/prelude.tot` fail to elaborate, `cached_state_of_src`'s `~error`
arm and therefore `bin/tot.ml:179-181`'s new tail print are UNREACHABLE
by the whole transcript corpus: every one of those 105 checks takes the
`~ok` branch. The item 10 reseal obligation carries its evidence in the
exit checklist's private one-block diff for
`test/fixtures/s0-erased-guard.tot`, below.

### Gate additions

All three legs go in one new block in `dev/gates.sh`, placed after
`PASS-M7E-DEBT-H`'s FAIL arm (ends at `dev/gates.sh:3976` in the
reference tree) and before the two fixed-last performance legs,
`PASS-M4FIX-INST-BRANCHING` (`dev/gates.sh:4012`, its comment at
`dev/gates.sh:4005` calls it the last leg in the file) and
`PASS-M5B-BRANCHING-20` (`dev/gates.sh:4031`, its comment at
`dev/gates.sh:4025` calls it likewise). Each leg follows the
`dev/gates.sh:2507-2529` shape: one `out=$(...); code=$?`, one `{ assertions; } && echo
PASS-<NAME> || { printf diagnostics; echo "FAIL-<NAME> (...)"; exit
1; }`. `rg -c 'PASS-M8C-' /Users/oobi/Documents/tot/dev/gates.sh`
exits 1 before insertion. Stage A and B markers remain present (R11).

New fixture, `dev/fixtures/m8c-hole-positions.tot` (placed under `dev/`
to match the `dev/fixtures/m7c-*.tot` convention for gate-only hole
probes, since it is not exercised by any suite case):

```
-- M8 Stage C (PASS-M8C-HOLE-POSITIONS): one item, one type hole and
-- three application holes, four holes total.  Item 8 is Option A
-- (R-Q5): report positions only, never a synthesized type.  N=3 in
-- the tail here, one more than M7C's N=2 (dev/fixtures/m7c-multi-hole.tot),
-- so the fold is pinned as general over the list length.
def h : List _ := cons _ "a" (cons _ "b" (nil _))
```

Column count, 1-indexed on the definition line: `List` ends at column
12, its `_` sits at column 14; `cons _` (first) has its `_` at column
24; `cons _` (second) has its `_` at column 36; `nil _` has its `_` at
column 47. With five comment lines above it, the definition is line 6,
so the predicted positions are `6:14` (reported), `6:24`, `6:36`, `6:47`
(tail). Exact column arithmetic, not measured by execution: marked
ESTIMATE.

```
Marker: PASS-M8C-HOLE-POSITIONS
Ruling: R-Q5
Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/dev/fixtures/m8c-hole-positions.tot
Before the stage: exit 1 (from Source.Missing, surface/source.ml:20-23), output contains "no such file" (PREDICTED: the fixture is new in this stage, so the pre-stage tree has no such path)
After the stage: exit 1, output contains "3 more hole(s) at 6:24, 6:36, 6:47" as its second stderr line, first line "6:14: hole: no expected type at this position"
MUTATION: surface/run.ml:654-661, (hole_tail). Change the fold so it keeps only the head of the sorted, filtered list instead of the whole list (List.filteri (fun i _ -> i = 0) in place of the plain filter-and-sort), which turns the printed count from 3 to 1 and the leg's exact-string match red.
Non-vacuous because: the fixture's four `_` tokens make Parser.parse_with_holes (surface/parser.ml:704-706) record four distinct Loc.t values, and only a live fold over the whole list, not a hardcoded pair, can print the three OTHER positions in sorted order.
```

```
Marker: PASS-M8C-S0-DRIVER
Ruling: A1-F6 (item 9), R-F7
Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe run --no-prelude /Users/oobi/Documents/tot/test/fixtures/s0-erased-guard.tot
Before the stage: the CLI command exits 0 and prints ghost's two eval lines unchanged (HEAD already runs this fixture correctly, test/surface.ml:1401-1408); the gate battery never runs this command at all (`rg -c 's0-erased-guard' dev/gates.sh` exits 1, no output)
After the stage: the CLI command is unchanged, exit 0, same two lines; the battery now runs it as a pinned positive control on every gate pass, from inside dev/gates.sh
MUTATION: lib/erase.ml:33, Change `| Term.App (Quantity.Zero, f, _a) -> term ctx f` so it also walks `_a` (for example, `Result.bind (term ctx f) (fun ef -> Result.map (fun _ -> ef) (term ctx _a))`), which makes erasure descend into ghost's dropped self-call argument, a two-branch match on a Quantity.Zero scrutinee, and trip the `_ :: _ :: _ -> Error (Error.Erased_use "match")` arm at lib/erase.ml:64. Erase.closed then returns Error for ghost, and the CLI run in the leg goes non-zero.
Non-vacuous because: the CLI output is identical before and after the stage lands, so the leg's value sits entirely in the pin plus the mutation, not in a before/after delta on the CLI half. The mutation touches only the ERASED branch that ghost's own definition exercises (the reason test/surface.ml:105-108 gives for the fixture), not the leg's own `--no-prelude` invocation, so a red run under mutation proves the leg watches real erasure behaviour and not its own command line (A1-F6).
```

The hand-broken prelude for `PASS-M8C-PRELUDE-TAIL` is a copy of
`stdlib/prelude.tot` patched with two `sd` calls, mirroring the
`cp`-then-patch recipe `PASS-M7D-CACHE-KEY` already uses at
`dev/gates.sh:3819-3821`. It touches only `cong0`
(`stdlib/prelude.tot:92-94` in the reference tree), leaving the
`foldNat`/`Json` split markers `Bootstrap.state_of_src`'s
`split_after_name` calls need (`surface/bootstrap.ml:308-317`)
untouched:

```
m8c_alt="$m8c_scratch/prelude-holed.tot"
cp "$ROOT"/stdlib/prelude.tot "$m8c_alt"
sd -s 'Eq B (f a) (f b) :=' 'Eq B (f a) _ :=' "$m8c_alt"
sd -s '(refl B (f a))' '(refl B _)' "$m8c_alt"
```

After Stage B, cong0 already contains the motive's `Eq _`. These
two substitutions add two holes, giving three parsed positions in the
item: 93:54 (reported), 94:48 and 94:73 (tail). `Run.hole_tail`
reports parsed positions, including the motive hole that could resolve
in an otherwise valid item; it does not filter by elaboration status.

The first `sd` blanks one argument of `cong0`'s own declared codomain
(the M7C rule: a hole inside a top-level type annotation is the
reported hole, since nothing later in the spine can determine it). The
second blanks a VALUE argument in the body, `refl`'s second (quantity
`w`) parameter, deliberately avoiding `refl`'s first (quantity `0`,
type) parameter `B`, which is exactly the class of argument Stage A and
Stage B are rewriting; a value argument has no such capture path and
stays a permanent hole under every reading of Stage A or B. A trivial
probe target, `dev/fixtures/m8c-prelude-tail-probe.tot`:

```
check Type 0
```

```
Marker: PASS-M8C-PRELUDE-TAIL
Ruling: item 10, A1-F4 (miss-path re-scope), R-Q6
Command: env TOT_PRELUDE="$m8c_alt" /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/dev/fixtures/m8c-prelude-tail-probe.tot
Before the stage: exit 1, stderr is exactly one line, "prelude: <path>:...: hole: ..." (surface/bootstrap.ml:443-471 has no tail to give bin/tot.ml:179-181's single-argument error arm)
After the stage: exit 1, stderr is exactly two lines. The first is "prelude: 93:54: hole: no expected type at this position"; the second is "2 more hole(s) at 94:48, 94:73". MEASURED with Parser.parse_with_holes and Run.hole_tail over the Stage B re-spell plus the two substitutions. Re-measure positions if preceding source lines move; retain the count of two.
MUTATION: bin/tot.ml:179-181, Delete the added `Option.iter prerr_endline tail` call from the prelude arm, which drops stderr back to one line and turns the leg's line-count assertion red.
Non-vacuous because: every one of the 105 files dev/gen-m5e-transcript.sh:13 walks (the top-level examples/*.tot and test/fixtures/*.tot globs; fixtures in subdirectories such as test/fixtures/m7/ are not walked), MEASURED at 6bcc1b7, keeps the real prelude valid, so this is the only leg in the whole battery that ever drives cached_state_of_src's miss-with-error arm, proving the new tail plumbing fires on the one path it exists for.
```

R3-F3 dropped `PASS-M8C-TRANSCRIPT-RESEAL`, because the leg had no
observable and no mutation of its own after two rounds: round 1 gave it
a re-pinned literal three older legs already own, and round 2 gave it
the identical single-edit mutation `PASS-M8C-PRELUDE-TAIL` already
names at `bin/tot.ml:179-181`, which R10's one-edit-per-leg rule
forbids two legs from sharing. In its place, Stage C treats the reseal
as an UPDATE to an existing leg's transcript literal, not a new leg:
`PASS-M6E-TRANSCRIPT-RESEALED` (`dev/gates.sh:3213`, asserted at
`:3218`), and, wherever the reseal really moves it, the literal of
`PASS-M5E-DEFAULT-IDENTITY` (`dev/gates.sh:2451`, echo at `:2454`) and
`PASS-M6C-DEFAULT-IDENTITY` (`dev/gates.sh:2863`, echo at `:2866`).
MEASURED against the staged tree: none of the three literals moves. The
checked-in block for `test/fixtures/s0-erased-guard.tot`
(`dev/m5e-default-transcript.txt:10324-10328`) already shows the
fixture failing through the target-path arm ("duplicate global Nat",
exit 1), never through the prelude arm Stage C edits
(`bin/tot.ml:179-181`), and Stage C's new gate-only fixture lives under
`dev/fixtures/`, outside the `examples/*.tot test/fixtures/*.tot` glob
`dev/gen-m5e-transcript.sh:13` walks. So `m6e_blocks`/`m6e_files`
(`dev/gates.sh:3213`/`:3218`) and the two whole-transcript `diff -q`
checks (`dev/gates.sh:2451` and `:2863`) all stay at their pre-Stage-C
values, and no in-place literal edit lands anywhere in the tree. The
reseal stays an item-10 OBLIGATION, checked by measurement in the exit
checklist below, not a gate marker.

### Suite cases

Three new tuples appended to the `cases` list in `test/surface.ml`,
just before its closing `]` at `test/surface.ml:2274`, each run
IN-PROCESS (no subprocess, no `_build/default/bin/tot.exe`), so none
duplicates a gate leg's CLI-driven observation.

```
Case: "M8C-1 m8c_tail_three: a three-hole item's tail names every OTHER hole, not just the M7C pair"
File under test: none; literal source, mirrors dev/fixtures/m8c-hole-positions.tot's shape
Assertion: m7c_expect_tail bst "def h : List _ := cons _ \"a\" (cons _ \"b\" (nil _))\n"
  ~want_line:"1:14: hole: no expected type at this position"
  ~want_tail:(Some "3 more hole(s) at 1:24, 1:36, 1:47")
Why not a duplicate of a gate leg: PASS-M8C-HOLE-POSITIONS shells the built binary
  against a file on disk; this case calls Run.script_tailed (surface/run.ml:668-685)
  directly on a literal string, so it catches a regression in hole_tail's fold before
  a rebuild, the same division of labour test/surface.ml:851 already documents for
  m7c_expect_tail's own M7C cases.
```

```
Case: "M8C-2 m8c_tail_eval_single: Option A holds for an eval-spine hole too, not only a def's own type annotation"
File under test: none; literal source "eval _\n"
Assertion: m7c_expect_tail bst "eval _\n"
  ~want_line:"1:6: hole: no expected type at this position" ~want_tail:None
Why not a duplicate of a gate leg: no gate leg runs this exact one-liner; PASS-M7C-SINGLE-HOLE-UNCHANGED
  and PASS-M8C-HOLE-POSITIONS both use file fixtures with a def's type annotation as the reported
  hole, while this case pins the SAME "positions only, no tail on one hole" rule over an eval spine,
  the position class test/surface.ml:2117 uses for a different point (M6C's own infer position).
```

```
Case: "M8C-3 m8c_prelude_tail_on_miss: a hand-broken multi-hole prelude carries its tail on the miss path, in process"
File under test: stdlib/prelude.tot, read via In_channel.with_open_text (test/surface.ml:2327's pattern)
  and patched with the SAME two literal substitutions PASS-M8C-PRELUDE-TAIL's sd recipe uses:
  "Eq B (f a) (f b) :=" to "Eq B (f a) _ :=", and "(refl B (f a))" to "(refl B _)"
Assertion: Tot_surface.Bootstrap.state_of_src_tailed patched_src, matched against
  Error (e, tail) with Serror.to_string e = "93:54: hole: no expected type at this position"
  and tail = Some "2 more hole(s) at 94:48, 94:73"
Why not a duplicate of a gate leg: PASS-M8C-PRELUDE-TAIL shells the CLI with TOT_PRELUDE pointed at a
  scratch file and a private cache dir, exercising cached_state_of_src's whole miss-branch, including
  Cache.save (surface/bootstrap.ml:468-471); this case calls state_of_src_tailed directly with no
  cache directory at all, isolating the parse-and-fold plumbing from the caching layer so a future
  cache-only regression cannot hide a tail-plumbing regression underneath it.
```

### Review checklist

- Count distinct success echoes for `PASS-M8C-` using the extraction
  command in 8.2: exactly three. Preserve the four Stage A and one Stage B
  markers. Stage D's prefix is absent until Stage D opens (R11).
- No stage line touches `surface/cache.ml:118`; `Cache.format_version` stays 10 (R-Q6).
- `Serror.t`'s `Hole` variant keeps exactly its two fields, `loc` and `expected`; no third field, no
  new constructor (R-Q5, Option A).
- `lib/erase.ml:33`'s mutation for PASS-M8C-S0-DRIVER exists ONLY as a mutation proof; the committed
  tree keeps the wholesale-drop arm, so no other fixture's erasure behaviour moves.
- Item 10's transcript-reseal obligation: the private one-block diff for
  `test/fixtures/s0-erased-guard.tot` (cut from `dev/m5e-default-transcript.txt` against the same
  block regenerated by `dev/gen-m5e-transcript.sh`) stays empty before this stage is called done; a
  non-empty diff means the corpus assumption for that one file (it fails through the target-path arm,
  never the prelude arm) was wrong, and item 10 goes back to design, not a re-pin of the
  whole-transcript block count.
- `Bootstrap.state ()` and `Bootstrap.state_of_src`'s existing callers (`test/surface.ml:1073`,
  `:2283`, `:2328`, `:2359`) compile unchanged; only `cached_state_of_src`'s internals and
  `bin/tot.ml:179-181` plus the compatibility wrapper
  `Bootstrap.cached_state` change signature-adjacent code.
- Every new suite case (`test/surface.ml:2274`) runs with `dune runtest` alongside the untouched
  M7 cases; none of the three depends on `_build/default/bin/tot.exe` existing.

### Rollback

Each of the three items rolls back independently, since none shares a mutation proof (R10) and none
edits the same function.

- Item 8 (`PASS-M8C-HOLE-POSITIONS`, `M8C-1`, `M8C-2`): remove the gate block and the two suite
  tuples, and delete `dev/fixtures/m8c-hole-positions.tot`. No source file changes to revert; item 8
  never edited `surface/run.ml` or `surface/serror.ml`.
- Item 9 (`PASS-M8C-S0-DRIVER`): remove the gate block. No source or suite change to revert; the
  leg only adds a new CLI invocation of an already-passing fixture.
- Item 10 (`PASS-M8C-PRELUDE-TAIL`, `M8C-3`): revert
  `bin/tot.ml:179-181` to its single-argument `~error` arm; delete `Bootstrap.state_of_src_tailed`
  and `Bootstrap.fold_prelude_items_tailed` from `surface/bootstrap.ml`; narrow
  `cached_state_of_src`'s return type back to `(Run.state, Serror.t) result`; remove
  `Result.map_error fst` from `cached_state`'s final call; remove the gate block
  and the one suite tuple; restore `dev/m5e-default-transcript.txt` from the pre-stage commit (no
  content change is expected, since the corpus never reaches the new arm, so this restore is a
  safety net, not a predicted diff).

Gate markers added: 3
Suite cases added: 3
Exit PASS count: 437 slice, 441 wrapper (ESTIMATE)

## STAGE D: the lib/ .mli sweep and the private storage boundary

### Goal and rulings covered

Stage D is last and remains the first cut if M8 must shrink (R-Q3).
The interface sweep covers lib/ only. R-Q4 still requires the new
`Global.add_rec_self` entry point and no `val add` in `lib/global.mli`.
The reviewed repair below also covers the callers that OCaml sealing
affects: an .mli restricts sibling modules in the same library as well
as external callers. Merely removing `val add` breaks Check.

This section supersedes the original Stage D assumption that lib/check.ml
could keep calling a hidden Global.add. It also preserves the existing
kernel tests that intentionally construct invalid environments. These
are necessary boundary repairs, not new admission or evaluation rules.
R10, R11 and C-A14 still apply. There are three new gate markers and one
new suite case; adapting existing tests adds no cases and removes none.

### Entry state and files touched

Entry is 437 slice / 441 wrapper, ESTIMATE, measured after Stage C closes.
Stage D does not open if Stage B stopped under R-Q7 (8.3).
The reference kernel has 17 .ml files, with budget.mli and level.mli
already present. Fifteen original modules need interfaces. The private
store adds one .ml and one .mli, so exit has 18 of each: sixteen new
interfaces in total. This file-count change adds no gate marker or case.

Files owned by this stage:

- `lib/global_store.ml` and `lib/global_store.mli`: new private,
  polymorphic environment storage, abstract outside its implementation.
- `lib/dune`: add `(private_modules global_store)` to tot_kernel.
- `lib/global.ml`: retain the public entry types and StringMap module;
  delegate environment storage to Global_store and add add_rec_self.
- `lib/global.mli`: preserve entry constructors, records, accessors and
  the public StringMap module; omit add. Preserve the internal storage
  type identity as described in D2 so Check can use the private store.
- `lib/check.ml`: redirect exactly eight `Global.add` calls to
  `Global_store.add`, plus the environment fold in inst_table_stats to
  `Global_store.fold`. Its separate StringMap of class names is unchanged.
- `lib/check.mli`, `lib/erase.mli`, `lib/error.mli`, `lib/eterm.mli`,
  `lib/eval.mli`, `lib/interp.mli`, `lib/json_escape.mli`,
  `lib/literal.mli`, `lib/pp.mli`, `lib/prim.mli`, `lib/quantity.mli`,
  `lib/term.mli`, `lib/totality.mli`, `lib/value.mli`: fourteen other
  original-module interfaces. budget.mli and level.mli are unchanged.
- `surface/run.ml`: replace the provisional self-entry construction
  with `Global.add_rec_self name ty_t st.globals`.
- `test/main.ml` and `test/dune`: preserve all adversarial kernel cases
  through the explicit white-box access described in D2. This changes
  five raw insertion call sites, not their test data or assertions.
- `test/surface.ml`: one new structural case, described below.
- `dev/gates.sh`: three new legs inserted before the two fixed-last
  performance legs, plus the explicit Stage A digest transition in D4.
- `dev/M8-BUILD-LOG.md` and SPEC.md: record the boundary, validation,
  entry/output digest, and approved kernel baseline transition.

### D1. The private store and narrow public entry point

Global_store owns a Map.Make(String) environment with the same runtime
representation and ordering as the original map. Its interface is:

```ocaml
type 'a t
val empty : 'a t
val find : string -> 'a t -> 'a option
val add : string -> 'a -> 'a t -> 'a t
val fold : (string -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
```

Its implementation delegates these four values directly to the same
Map.Make(String) operations, with `type 'a t = 'a StringMap.t`. There
is no wrapper record or new runtime constructor. The module is private
in lib/dune, so it is not a `Tot_kernel.Global_store` public alias.

Global retains its existing public `module StringMap = Map.Make(String)`:
Interp, Bootstrap and tests use that module for runtime globals, and
Check uses it for a separate class-name set. Do not hide or rename it.
Change only the kernel environment storage and its three operations:

```ocaml
type t = entry Global_store.t
let empty : t = Global_store.empty
let find (name : string) (globals : t) : entry option =
  Global_store.find name globals
let add (name : string) (entry : entry) (globals : t) : t =
  Global_store.add name entry globals

let add_rec_self (name : string) (ty : Term.t) (globals : t) : t =
  add name
    (Def
       { ty; def = Term.Global name; reducible = false;
         rec_arg = None; partial = false })
    globals
```

Global.add remains an unexported implementation helper used by
add_rec_self. The eight Check insertion sites call Global_store.add
directly; the environment fold uses Global_store.fold. Every entry
record, guard, validation step and ordering remains identical.
The narrow self-entry is provisional, opaque and unchecked, just as
before; Run still passes the completed definition to Check.define.

### D2. The public interface, caller access and test access

Global's interface preserves its existing record and variant definitions,
including all constructors, and all accessors. In addition to those
definitions, its relevant signature is:

```ocaml
module StringMap : Map.S with type key = string
(* Existing telescope, def_entry, ctor_status, ind_entry, ctor_entry,
   prim_entry, axiom_entry and entry definitions go here unchanged. *)
type t = entry Global_store.t
val empty : t
val find : string -> t -> entry option
val add_rec_self : string -> Term.t -> t -> t
(* Existing entry_ty, *_of, find_* and find_ind_arity accessors follow. *)
```

The manifest `t` identity is intentional. Global_store.t is abstract;
the alias lets Check use its private storage API without exposing the
map representation or a public general insertion function. An abstract
`type t` here would lose that identity and break the internal callers.
There is no `val add` in this interface, and callers through the normal
library dependency cannot name Tot_kernel.Global_store or the hidden
Tot_kernel__Global_store module.

Five existing test/main.ml cases use Global.add to construct deliberately
malformed environments. Do not remove them or replace their raw inserts
with checked admission, which would stop testing the intended failure.
For these white-box tests only, replace each call with
`Tot_kernel__Global_store.add`. Split test/dune's current combined tests
stanza into a main test with `(modules main)` and a surface test with
`(modules surface tot_exe_dep)`, retaining the existing libraries and the
tot_exe_dep generation rule. Only main receives:

```lisp
(flags (:standard -I lib/.tot_kernel.objs/byte))
```

This path is relative to Dune's compiler working directory
`_build/default`, as measured with this repo's Dune 3.24 toolchain. It
deliberately gives the white-box main test access to the private cmi;
surface and bin keep the normal dependency boundary. It is not an OCaml
sandbox against clients choosing their own compiler flags. No warning,
test, timeout, dependency or assertion is disabled. Verify that the same
private reference fails to compile in a normal external client and
succeeds only in the explicitly configured white-box test.

### D3. Preserve the other modules' actual public types

Restate each module's inferred signature, including the module declarations
that a `^let|^type` scan misses. Keep constructors wherever clients construct
or match them. In particular quantity.mli must contain:

```ocaml
type t = Zero | Many
val mul : t -> t -> t
val equal : t -> t -> bool
val to_string : t -> string
```

Zero and Many are used throughout Check, Erase, Eval and surface modules;
an abstract Quantity.t does not compile. Do not copy level.mli's abstract
representation indiscriminately. Full compilation of bin and both suites,
not just the interface-file count, validates the exported signature.

### D4. Transition the Stage A kernel baseline explicitly

PASS-M8A-KERNEL-UNCHANGED keeps its original 17-file digest unchanged
through Stages A, B and C. Stage D is the sole planned transition:

1. Before editing, verify the exact 17-file digest
   ec077852495cdc0ac9a7abd4eb2fe786 and record the current gate recipe.
   Also record the five-example output digest for the new behaviour leg.
2. Review the kernel .ml diff: only the new Global_store and the Global
   delegation/self-entry and Check call/fold rewires in D1 may differ.
   Adding .mli files does not justify any other .ml change.
3. Preserve PASS-M8A-KERNEL-UNCHANGED, its failure arm and its mutation.
   Extend its explicit sorted cat list with lib/global_store.ml between
   global.ml and interp.ml, set its file-count assertion to 18, and pin
   the newly measured 18-file digest as a literal. Record old/new digests,
   file lists, commands and the reviewed source diff in the build log.
   Its comment must say that it now freezes the post-Stage-D kernel.
4. The new digest is measured once during this reviewed transition. The
   gate must never derive its expected digest from the live source, nor
   accept either digest opportunistically. Subsequent changes must fail.
5. Re-run the marker's original Cannot_infer-message mutation and confirm
   failure, then restore identical bytes. Check both suites and the full
   battery, and prove the five-example behaviour digest stayed identical.

Cache.format_version remains 10. Compare the marshalled bootstrap payload
before and after the refactor to confirm the unchanged Map representation.
The cache key includes the executable digest, so a rebuilt binary normally
misses entries from the preceding binary. Retain those entries as evidence;
run the new binary twice with TOT_CACHE_VERIFY=1 in a private directory
and require TOT-CACHE-VERIFY-OK on its warm hit. A payload/output mismatch
stops Stage D; do not hide it by bumping the format, clearing the evidence
or changing a transcript expectation.

### Gate additions

Insert all three legs after Stage C and before the fixed-last performance
legs. Follow the existing PASS/FAIL shape with exit 1 on failure. Before
insertion `rg -c 'PASS-M8D-' dev/gates.sh` must find nothing; the eight
Stage A-C markers remain present. No existing leg is retired.

Marker: PASS-M8D-MLI-COVERAGE
Ruling: R-Q3.
Command: comm -23 <(fd -e ml --max-depth 1 . /Users/oobi/Documents/tot/lib -x basename | rg -o '^[^.]+' | sort -u) <(fd -e mli --max-depth 1 . /Users/oobi/Documents/tot/lib -x basename | rg -o '^[^.]+' | sort -u) | wc -l | tr -d ' '
Before the stage: exit 0, output 15 (17 original modules, two interfaces).
After the stage: exit 0, output 0 (18 modules, 18 interfaces).
MUTATION: lib/totality.mli, delete lib/totality.mli.
Non-vacuous because: the missing-interface count moves from 0 to 1.

Marker: PASS-M8D-KERNEL-INTERNAL
Ruling: R-Q4. The sole self-entry boundary marker.
Command: rg -n '^\s*val add\b' /Users/oobi/Documents/tot/lib/global.mli
Before the stage: exit 2, missing interface file.
After the stage: exit 1, no matches in the existing interface.
The gate passes only on code 1; codes 0 and 2 both fail.
MUTATION: lib/global.mli, add `val add : string -> entry -> t -> t` immediately below `val empty : t`.
Non-vacuous because: the command returns 0 and prints the forbidden export.
The private Global_store interface intentionally contains val add; this
marker scans the public Global interface only. The build/client checks
in D2 establish the private-module boundary in addition to this text check.

Marker: PASS-M8D-NO-BEHAVIOUR-CHANGE
Ruling: R-Q3; retain the five-example output comparison.
Command: printf '%s\n' /Users/oobi/Documents/tot/examples/church.tot /Users/oobi/Documents/tot/examples/guard-classes.tot /Users/oobi/Documents/tot/examples/guard-rewrap.tot /Users/oobi/Documents/tot/examples/guard.tot /Users/oobi/Documents/tot/examples/literals.tot | xargs -I{} /Users/oobi/Documents/tot/_build/default/bin/tot.exe check {} 2>&1 | md5 -q
Before the stage: capture the measured output digest in the build log.
After the stage: the identical digest. The gate also checks that every
example command exits 0; a successful md5 pipeline alone is insufficient.
MUTATION: lib/quantity.ml:26, change `| Many -> "w"` to `| Many -> "many"`.
Non-vacuous because: Pp renders Many Pi binders in these examples using
Quantity.to_string, so the output digest changes. Other preserved digest
legs may also fail under this mutation; distinct mutations do not require
mutually exclusive failures.

### Suite case and review checklist

Add one in-process case using test/fixtures/f1-witness.tot, with the
no-prelude initial state because the fixture declares Nat. Assert that
the final globals contain `Global.find_def "add"` with `rec_arg = Some 0`
and `reducible = true`. This observes the final checked entry, not just
the provisional self-entry or CLI formatting. The existing CLI F1 case
and all five raw-environment kernel cases remain intact.

Before closure:

1. Build bin/tot.exe, test/main.exe and test/surface.exe together; run
   both suites and the full battery. Preserve every prior test/assertion.
2. Verify normal external clients can use Global and Check but cannot
   call Global.add or either spelling of the private store module.
3. Confirm the eight Check inserts and one environment fold use the
   private store; retain Global.StringMap's runtime-global and set users.
4. Check interfaces against inferred signatures, including module exports
   and constructors. Both original interfaces remain unchanged.
5. Record D4's 17-to-18-file transition and unchanged output/cache results.
   Mutation-test the transitioned Stage A leg as well as all three new legs.
6. Count success echoes using 8.2: three Stage D names, eleven total,
   no repeated success echo. Earlier markers stay green.

### Rollback

Revert Stage D as a unit: the private store and lib/dune declaration,
Global delegation/interface/self-entry, Check and Run rewires, all new
interfaces, test-only access and insertion rewires, the new surface case,
and the three new gate legs. Restore the Stage A digest recipe, count
17 and original digest together. Preserve the Stage A-C changes and
every existing test. Keep the build log's measurements and conflict notes.
If Stage D is cut before it starts, none of these changes or the baseline
transition lands; M8 closes at Stage C's count instead.

Gate markers added: 3
Suite cases added: 1
Exit PASS count: 441 slice, 445 wrapper (ESTIMATE)

## 8. Exit criteria and completion checklist

This section is cross-cutting.  It carries no stage's payload and it adds
no `PASS-M8` leg of its own.  It states the gate a stage closes at, the
gate the whole milestone closes at, the one acceptance test that proves
the milestone's theme, the rule that shrinks the milestone if it must
shrink, and the changes this milestone deliberately does not make.  The
MAIN LOOP walks this section at build completion, the way it walked
`dev/M7-PLAN.md`'s own section 10 (dev/M7-PLAN.md:1027-1074).

Citation rule, the same as the rest of this plan: a citation is read from
the COMMITTED blob at HEAD `8cf0b8b` unless marked "working tree", in
which case it is read from HEAD plus the unstaged M7 Stage E diff, the
reference state this plan builds against.  `dev/gates.sh` and
`lib/check.ml` both carry unstaged Stage E hunks, so a HEAD line number
and a working-tree line number differ for those two files; this section
states both wherever a probe reads one of them.

### 8.1 The per-stage exit gate

Every stage, A through D, closes only when all five of the following
hold.  A stage that reports itself closed without measuring all five has
not closed; it has stopped early.

1. **The four battery commands are green.**  Run from the repo root, no
   `cd`, absolute paths:

       dune build --root /Users/oobi/Documents/tot
       dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -3
       dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -3
       zsh /Users/oobi/Documents/tot/dev/gates.sh > "$TMPDIR/tot-gate.out" 2>&1; echo "GATE-EXIT=$?"

   `GATE-EXIT=0` and `rg -c '^FAIL' "$TMPDIR/tot-gate.out"` prints
   nothing and exits 1 (zero FAIL lines).  This is the M7 battery,
   unchanged (dev/M7-PLAN.md:211-218).

2. **The exit PASS count is reached, non-vacuously.**  `rg -c '^PASS'
   "$TMPDIR/tot-gate.out"` equals the stage's own exit slice count, and
   the wrapper's own `PASS=` line, when the build workflow's wrapper
   runs the same battery, equals the slice plus 4 (C-A14).  Non-vacuous
   means two further things hold, not just the raw count: the delta from
   the stage's entry count equals that stage's own markers plus suite
   cases (for example Stage A: 428 minus 420 is 8, which is 4 markers
   plus 4 suite cases, ESTIMATE, re-measured per stage, recount per
   R-F1b), and the stage's
   own new marker names are present and are the only new `PASS-M8<stage>`
   names, checked with `rg -o 'PASS-M8<L>-[A-Z0-9-]+'
   /Users/oobi/Documents/tot/dev/gates.sh | sort -u | wc -l`, where `<L>`
   is that stage's letter, equal to the count that stage's own section
   reserves.  A PASS count that moved by the right total but under the
   wrong names has not closed the stage; it has closed a different one.

3. **Every new leg carries its mutation proof, and no two share one
   (R10).** `rg -c 'Marker: PASS-M8<L>-' /Users/oobi/Documents/tot/dev/M8-PLAN.md`
   equals `rg -c '^\s*MUTATION:' /Users/oobi/Documents/tot/dev/M8-PLAN.md` for
   that stage's own marker block, and `rg -o '^\s*MUTATION:.*'
   /Users/oobi/Documents/tot/dev/M8-PLAN.md | sort | uniq -d` prints
   nothing for that stage's block, so no single edit proves two markers.
   Each proof is confirmed live: the named edit turns the leg's `echo
   PASS-<NAME>` line into its `FAIL-<NAME>` arm, and restoring the edit
   returns an md5-identical file, `md5 -q <path>` equal before and after
   (the R10 shape, dev/M7-PLAN.md:846-872).

4. **The stage review checklist is clean.** The stage's own section
   states the exact files it touches; this gate re-reads those files
   against the house style every M8 stage inherits (design brief, "State
   at M7 close", the conventions list): no `raise`, `failwith`, `assert`
   or `Option.get` (`rg -n 'raise|failwith|assert|Option\.get'` on each
   touched file prints nothing new against that file's own HEAD
   baseline); no `match` on an `Option` or a `Result` value, `Option.map`,
   `Option.join`, `Option.value` or a fold used instead; every `match` on
   a `Term.t` or a `Syntax.t` lists every constructor, no wildcard arm;
   no `match` on a bool, the `match () with | () when ... -> ...` guard
   ladder used instead, the shape `strict_pos` already ships at
   `lib/check.ml:1965-1966` (working tree; HEAD `lib/check.ml:1958-1959`,
   shifted by the Stage E diff's `+7` hunk at `lib/check.ml:1775-1792`);
   total indexing only, `List.nth_opt` not `List.nth`, no bare division;
   no loop keyword, fold, map and filter instead.

5. **Conflict notes are booked.** For every literal that stage measured
   and found different from its ESTIMATE, `dev/M8-BUILD-LOG.md` carries a
   `**Conflict note C-<L><n> (date): ...**` paragraph with all six parts
   the conflict-note protocol names, checked with `rg -c '^\*\*Conflict
   note C-<L>' /Users/oobi/Documents/tot/dev/M8-BUILD-LOG.md` at least 1
   for that stage's letter.  A stage that measured no difference from its
   ESTIMATE books no note and says so; a stage that measured a difference
   and booked no note has not closed.

### 8.2 The M8 exit gate

M8 closes only when every one of the following holds, on top of every
stage's own 8.1 gate.  This is the whole-milestone version of
`dev/M7-PLAN.md`'s section 10 (dev/M7-PLAN.md:1027-1074), read against
four stages instead of five.

- **All four stages closed**, or Stage B stopped under R-Q7 and the
  milestone closed early (section 8.3 states which branch and what each
  branch records).  Each stage's own 8.1 gate is satisfied before the
  next stage opens; no stage opens on a red predecessor.

- **The chain is reconciled against the measured wrapper count.** The
  ESTIMATE chain, recounted per R-F1b against the stage slices as
  fixed, is 420 -> 428 -> 431 -> 437 -> 441 slice, wrapper +4 at
  every boundary, 424 -> 432 -> 435 -> 441 -> 445 (section 2.1 of this
  plan, which replaces the design verdict's own sketch table at
  /Users/oobi/Documents/tot-m8-design-verdict.md:169-178).  Eleven
  markers plus ten suite cases is +21, and
  420 + 21 = 441 slice, 445 wrapper.  At M8 close, every cell in that row
  is replaced by its measured value, with the command that produced it,
  the same count-honesty rule graft G8 states (dev/M7-PLAN.md:793-797),
  and `dev/M8-BUILD-LOG.md` carries the final chain the way
  `dev/M7-BUILD-LOG.md` carries M7's.  The wrapper offset of 4 (C-A14)
  is checked at the final boundary the same way it is checked at every
  stage boundary: the wrapper's own `PASS=` line minus `rg -c '^PASS'
  "$TMPDIR/tot-gate.out"` equals 4.

- **The `PASS-M8` marker list is unique and complete.** The eleven
  reserved names, recounted per R-F1b from the stage slices' own
  `Marker:` lines, are `PASS-M8A-LOCAL-SPINE-SYNTH`,
  `PASS-M8A-ZERO-ARG-UNCHANGED`, `PASS-M8A-BARE-LAMBDA-REFUSES`,
  `PASS-M8A-KERNEL-UNCHANGED`,
  `PASS-M8B-PRELUDE-94`,
  `PASS-M8C-HOLE-POSITIONS`, `PASS-M8C-S0-DRIVER`,
  `PASS-M8C-PRELUDE-TAIL`,
  `PASS-M8D-MLI-COVERAGE`, `PASS-M8D-KERNEL-INTERNAL`,
  `PASS-M8D-NO-BEHAVIOUR-CHANGE` (four plus one plus three plus three;
  R-F2/R-F3 dropped `PASS-M8A-CONSERVATIVITY`, R-F3 dropped
  `PASS-M8B-RESPELL-COUNT`, R1-F3 dropped `PASS-M8B-ANCHORS`, and R3-F3
  dropped `PASS-M8C-TRANSCRIPT-RESEAL` from
  the candidate table's original fifteen). Comments may repeat these
  names, so extract only success echoes and use that output for both
  the count and the uniqueness check:

      rg --no-filename -o '^\s*(?:&&\s*)?echo (PASS-M8[A-D]-[A-Z0-9-]+)\b' -r '$1' /Users/oobi/Documents/tot/dev/gates.sh

  Pipe that output through `sort -u | wc -l` for the total (11, or 8
  when Stage D is cut), and separately through `sort | uniq -d` for
  duplicates (empty). Compare the sorted unique names with the eleven
  reserved names above; a different name with the same count is a failure.
  Before M8 opens, `rg -c 'PASS-M8' /Users/oobi/Documents/tot/dev/gates.sh`
  prints nothing and exits 1, measured in the working tree (R11), so the
  count above starts from zero and not from a collision.  The
  plan-side count is stated separately from the built-tree count: the
  stage slices themselves name 11 distinct `PASS-M8` identifiers,
  scoped to each slice's own `Marker:` line (`rg -o --no-filename
  '^\s*(?:[0-9]+\. )?Marker: (PASS-M8[A-D]-[A-Z0-9-]+)' -r '$1'
  /Users/oobi/Documents/tot-m8-plan/slices/4?-stage-*.md | sort -u |
  wc -l`), never `-oh`, because `-h` is `--help` in ripgrep 15.1.0 and
  that flag prints the ripgrep usage text instead of a count.  The
  value 11 is the same total the eleven-name list above carries,
  scoped to the plan's own slice text, not to `dev/gates.sh`.  An
  unscoped name sweep over the same four files, `rg -o
  'PASS-M8[A-D]-[A-Z0-9-]+'
  /Users/oobi/Documents/tot-m8-plan/slices/4?-stage-*.md | sort -u |
  wc -l`, prints 14, because three drop notes still name
  `PASS-M8A-CONSERVATIVITY`, `PASS-M8B-RESPELL-COUNT` and
  `PASS-M8C-TRANSCRIPT-RESEAL`; that count
  is plan-side, and it is not a `dev/gates.sh` count.  Both counts are
  measured on the four stage slices' own text, never against
  `dev/gates.sh`.

- **No leg is without a proof.** Across the whole assembled plan, `rg -c
  '^\s*(?:[0-9]+\. )?Marker: PASS-M8' /Users/oobi/Documents/tot/dev/M8-PLAN.md`
  equals `rg -c '^\s*MUTATION:' /Users/oobi/Documents/tot/dev/M8-PLAN.md`,
  both anchored at the head of the line so a mechanical count cannot miss
  a numbered list item or a mid-line echo of the word, and both print 11,
  the recount total from section 2.1, not a hard-coded 12.  R3-R10
  replaces the old text-equality self-check with a check on the EDIT
  SITE, because a whole-line text compare lets two legs name one
  identical edit in different words and still pass: `rg -o -r '$1'
  '^\s*MUTATION: ([A-Za-z0-9_/.:-]+),' /Users/oobi/Documents/tot/dev/M8-PLAN.md
  | sort | uniq -d` prints exactly one line, `surface/elab.ml:401`
  (R4-2b), and nothing else; any other line is a blocking R10 breach
  that halts the exit gate.  The companion count, `rg -c '^\s*MUTATION:
  [A-Za-z0-9_/.:-]+,' /Users/oobi/Documents/tot/dev/M8-PLAN.md`, prints
  11, so no `MUTATION:` line lacks a site token.  Both pipelines are
  head-anchored and extract one token per line, so no `-m 1` caps the
  stream.  The expected number of distinct edit sites is 9 for 11 legs:
  10 distinct tokens, because `surface/elab.ml:401` appears twice
  (R4-2b), and of those 10, `lib/check.ml:958-959` and
  `lib/check.ml:959` overlap at line 959 (R1-R7) while staying
  textually distinct.  The old text-equality line stays as a second,
  weaker check, head-anchored the same way: `rg -o '^\s*MUTATION:.*'
  /Users/oobi/Documents/tot/dev/M8-PLAN.md | sort | uniq
  -d` prints nothing, so no mutation proof is reused verbatim across
  markers either, and no marker in the plan lacks one (R10).

- **No em dash character (Unicode U+2014) in the plan or the log.** `rg
  -c $'\u2014' /Users/oobi/Documents/tot/dev/M8-PLAN.md` prints
  nothing and exits 1; the same command against
  `/Users/oobi/Documents/tot/dev/M8-BUILD-LOG.md` prints nothing and
  exits 1.  This is the M7 precedent, re-run: the same
  pattern against `dev/M7-PLAN.md` and `dev/M7-BUILD-LOG.md` prints
  nothing and exits 1 in the working tree today, confirming the house
  rule already holds for the files M8 extends.

- **SPEC and the build log are updated.** `SPEC.md` section 6, "Known
  debts (deliberate)" (`SPEC.md:2002`), gains a dated "Known debts
  entering M9" paragraph in the shape of the "Known debts entering M7"
  paragraph already there (`SPEC.md:2554`), naming C1 and C2 as the two
  debts M8 carries forward, each with its own one-line reason (section
  8.5 states the reasons this exit gate checks against).  `SPEC.md`'s
  decision log (`SPEC.md:19`, "## 2. Decision log") carries one dated
  entry per stage.  `dev/M8-BUILD-LOG.md` holds one stage report per
  closed stage, every mutation proof with its flip and its md5-identical
  restore, every measured count with the command that produced it, and
  every conflict note in the six-part shape.  The tree is complete and
  UNSTAGED; `git -C /Users/oobi/Documents/tot status --porcelain` output
  is recorded before the MAIN LOOP runs `git add -A`.  The user commits;
  no stage agent commits, ever (the M7 rule, unchanged,
  dev/M7-PLAN.md:1065-1072).

### 8.3 The acceptance test: C4 proves Stage A's payload

C4, the `stdlib/prelude.tot:94` re-spell, is the executable proof that
Stage A's local-aware capture source reaches the site C5 is built to
widen.  The design verdict states this framing directly: C4 is "IN, as
the Stage B acceptance test of C5"
(/Users/oobi/Documents/tot-m8-design-verdict.md:128-129).  A Stage A that
is green on its own five markers but leaves `stdlib/prelude.tot:94`
refusing has proved conservativity, not the milestone's theme; the theme
closes only when Stage B's own acceptance test closes too.

The acceptance test has two conditions, both required:

1. `stdlib/prelude.tot:94`'s congruence motive reads `Eq _ (f a) (f z)`,
   not the explicit `Eq B (f a) (f z)` it carries today (quoted at
   `stdlib/prelude.tot:94`, read in the working tree).
2. `/Users/oobi/Documents/tot/_build/default/bin/tot.exe check
   /Users/oobi/Documents/tot/examples/church.tot` exits 0, the bootstrap
   check that loads the re-spelled prelude on every run.

When both hold, M8 has closed the headline debt of the M7 hand-off, and
Stage C and Stage D open.

When they do not, R-Q7 fires and this exit gate records the STOP branch
instead of the re-spell.  If Stage A's own battery is green (its 8.1 gate
satisfied) and `stdlib/prelude.tot:94` still prints `prelude: 94:48:
hole: no expected type at this position`
(dev/M7-BUILD-LOG.md:2321-2323, the exact line the repo printed once
already), Stage B does not retry a different spelling on its own
judgment.  It stops, and `dev/M8-BUILD-LOG.md` books a conflict note in
the C-D3 shape naming the predicted re-spell (44 anchors becoming 45,
`m6e_holes` 68 becoming 69, prelude holed 46 becoming 47, all ESTIMATE
against the Stage B section's own prediction) beside the measured
refusal.  In the STOP branch, the M8 exit gate records exactly this
shape and nothing more:

- Stage A closed at its own 8.1 gate, 428 slice / 432 wrapper (ESTIMATE,
  re-measured at Stage A's own close, recount per R-F1b).
- Stage B stopped, not closed: its battery may still read GATE-EXIT=0 on
  the legs that do not depend on the re-spell, but `PASS-M8B-PRELUDE-94`
  is red and stays red, and the stage's own exit count is not claimed.
- Stage C and Stage D do not open in this milestone.  M8 ends at the stop
  and the note, and the SPEC "Known debts entering M9" paragraph (8.2)
  carries the re-spell forward alongside C1 and C2.

A retreat from the re-spell, meaning a permanent decision to keep the
explicit `Eq B` spelling rather than close it later, is a user ruling
only (dev/M7-BUILD-LOG.md:2340-2341).  The exit gate never records that
retreat on a builder's own authority; it records the stop and waits.

### 8.4 The shrink rule

Per R-Q3, Stage D, the `lib/` `.mli` sweep, is the one stage this
milestone can drop whole without touching Stages A to C.  "It is the cut
if M8 must shrink" is the ruling's own wording
(/Users/oobi/Documents/tot-m8-ratifications.md:9).  If the milestone
must shrink, the cut removes Stage D's three markers and one suite case
(`PASS-M8D-MLI-COVERAGE`, `PASS-M8D-KERNEL-INTERNAL`,
`PASS-M8D-NO-BEHAVIOUR-CHANGE`, ESTIMATE) from the total, and the M8 exit
gate of section 8.2 closes at Stage C's own exit, 437 slice / 441 wrapper
(ESTIMATE, re-measured at Stage C's close, recount per R-F1b), instead
of 441 / 445.  The marker-count check in section 8.2 drops its target
from 11 to 8, and
`rg -o 'PASS-M8D-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | rg
-c .` prints nothing and exits 1, confirming the cut left no Stage D
marker half-shipped.

The cut moves the sweep to M9 and touches nothing already closed in
Stages A to C.  `lib/global.mli` is never created; `lib/global.ml:102`'s
`add` stays exported exactly as it is today (there is no `lib/global.mli`
at HEAD or in the working tree to un-export it from, confirmed: `lib/`
carries exactly two `.mli` files, `budget.mli` and `level.mli`); and
`surface/run.ml:218-230` keeps calling `Global.add` unchanged, the same
call the M7 hand-off already ships. Global_store is not created; the
kernel remains at 17 .ml files and the Stage A digest is not transitioned.  The cut is recorded once, in
`dev/M8-BUILD-LOG.md`, as the stage that did not run, not as a conflict
note under section 3's protocol: a shrink is a scope decision the user
or the orchestrator makes, not a refused prediction the repo forced.

### 8.5 Deliberate non-changes

Four things this milestone does not touch, each with the one-line reason
this exit gate checks against.

- **The kernel stays untouched in Stages A to C.**  Reason: the theme is
  elaborator surface work with an executable acceptance test, and it
  "closes four items of the M7 hand-off and touches nothing that can make
  the checker unsound" (/Users/oobi/Documents/tot-m8-design-verdict.md:62-63).
  Stage A's own `PASS-M8A-KERNEL-UNCHANGED` marker pins
  `lib/check.ml:958-959`'s bare-lambda refusal
  (`Error.Cannot_infer (Printf.sprintf "the bare lambda (binder %s)" x)`)
  and `lib/totality.ml:20`'s `type rule = Structural` verbatim across
  Stage A.  Stage D alone, under the reviewed D1-D4 boundary repair, moves
  the environment storage into private Global_store, adds the narrow
  self-entry function, and rewires the eight Check insertions and its
  environment fold. It does not change admission logic or totality.ml.
  D4 explicitly transitions the Stage A digest to cover all 18 .ml files.

- **`Serror.t` does not change.**  Reason: R-Q5 rules item 8 Option A,
  positions only, never a synthesized type
  (/Users/oobi/Documents/tot-m8-ratifications.md:11), the same answer M7
  Stage C already gave its own multi-hole tail: "`Serror.t` does not
  change and the exit code does not move... the `Serror.t` and `Term.t`
  constructor counts stay 10 and 11, so no constructor moved"
  (SPEC.md:1626-1630).  `surface/serror.ml:55-58`'s `Hole` variant, whose
  `expected` field already carries `(string list * Term.t) option` for
  the single-hole case, keeps that exact shape; Stage C's item 8 and item
  10 legs report hole positions from a record built inside a traversal
  that already runs, the same design SPEC.md:1622-1625 already states,
  never a new field or a new constructor.

- **`Cache.format_version` stays 10.**  Reason: R-Q6, and the cache key
  already folds the prelude source into its digest
  (`surface/cache.ml:343-346`, `key`), so Stage B's re-spell and Stage
  C's item-10 reporting change need no version bump.  `PASS-M7D-CACHE-KEY`
  is the surviving leg that measures the constant; its assertion sits at
  `dev/gates.sh:3814` and `:3820` at HEAD, and at `dev/gates.sh:3831` and
  `:3837` in the working tree (the unstaged Stage E diff inserts lines
  ahead of this point, a `+17` shift).  No M8 stage edits either line
  except to re-measure it, and Stage C's own reporting work changes
  reported text only, never the version constant.

- **The M6 fence legs stay green.**  Reason: R-Q2 defers C2 to M9, so no
  stage of M8 widens the strict-positivity fence, `strict_pos` at
  `lib/check.ml:1954-1969` at HEAD (`lib/check.ml:1961-1976` in the
  working tree, the same `+7` shift section 8.1 item 4 names).
  `PASS-M6A-FENCE-COVARIANT` is the leg the ratification names by name
  (/Users/oobi/Documents/tot-m8-ratifications.md:8), its comment header
  sitting at `dev/gates.sh:2531-2535` at HEAD and `dev/gates.sh:2542-2546`
  in the staged tree, with its own `echo PASS-M6A-FENCE-COVARIANT` line
  at `dev/gates.sh:2552` in the staged tree (R-S1: the HEAD range
  2531-2535 now holds `PASS-M6A-DEEP2-REJECTED` in the staged tree, not
  this leg); its neighbor `PASS-M6A-FENCE-CONTRAVARIANT` stays green
  alongside it.  Both keep asserting the exact rejection message for
  `test/fixtures/nested-pos.tot` and `test/fixtures/nested-neg.tot`
  through every stage of this milestone.  The per-stage review checklist
  in 8.1 item 4 re-confirms this pair is still in the `^PASS` set at
  every stage's own battery run, not only at final close.

Section 8 ends.

# 9. Risks and the M9 hand-off

Citation rule for this section: every `<path>:<line>` below is read from
the reference state, HEAD 8cf0b8b plus the unstaged M7 Stage E diff, with
`awk NR==` or `rg -n` against the working tree at
/Users/oobi/Documents/tot.  A check against `git -C
/Users/oobi/Documents/tot diff` confirmed that none of the lines cited in
this section fall inside a Stage E hunk, so every citation below is HEAD
8cf0b8b behaviour, unchanged by the pending Stage E commit.  This section
adds no new PASS-M8 marker.  Its early signals point at markers Stage A
through Stage D already define; the marker names below are read from the
stage sketch and are not redefined here.

## 9.1 Risks

Each block names the risk, the reading that makes it live, the early
signal a build should watch, and the rollback.

### Risk 1: the Stage A instantiation keeps the old refusal it was built to remove

Reading that makes it live.  Stage A replaces the reused `inst_applied`
with a new local-aware instantiation because `inst_applied` cannot serve
a local head: it routes every residual through `inst_domain ~j:n ~k:n`
(surface/elab.ml:385-386), and `inst_domain`'s free-variable arm computes
`p = j - 1 - (i - d)` and answers `None` whenever `p < 0`
(surface/elab.ml:211-214).  For a residual that still carries a free
local, that condition holds by construction, so any new instantiation
that still funnels its residual through `inst_domain`'s closed-type
convention answers `None` again, at the exact site it exists to open.
The witness is stdlib/prelude.tot:92-94, `cong0`'s body, whose later
arguments `f a` and `f z` are spines headed by the local `f` with
recorded type `A -> B`, itself two open locals.

Early signal.  PASS-M8A-LOCAL-SPINE-SYNTH (the new positive fixture)
stays red, or PASS-M7A-CONSERVATIVITY's byte-identical-stdout digest
(dev/gates.sh:3402-3443) moves on a fixture that never touched a hole.
The first marker is Stage A's own battery; the second is the surviving
M7 leg every M8 stage's battery run must keep green; this risk names
why either can fail even after the arm is rewritten.

Rollback.  Revert the Stage A commit.  Book a conflict note in the C-D3
shape recording the predicted "a local-aware instantiation keeps free
locals" against the measured refusal, and name the residual site
(surface/elab.ml:211-214) the note traces to.

Answers finding: A1-F2 (ACCEPT, design-verdict section 4, Attack 1),
which is the finding that forced the proposal-1 Stage A off a reuse of
`inst_applied` and onto a new instantiation.

### Risk 2: the zero-argument case regresses under the new arm

Reading that makes it live.  Stage A must keep the `applied = []` branch
answering exactly `local_ty locals ix`, byte for byte
(surface/elab.ml:308-309), because that is the path stdlib/prelude.tot:74
already depends on: the slot-0 capture of `Eq _` in `sym0`'s motive is
read off the local `a`, applied to nothing.  If the new arm routes the
empty-argument case through the same machinery it uses for a non-empty
spine, rather than special-casing it, the `p = j - 1 - (i - d)` arithmetic
at surface/elab.ml:211-214 sees `j = 0` and every free local index
answers `p < 0`, so the working capture at line 74 disappears and the
bootstrap check on examples/church.tot exits 1 before Stage A's own
positive fixture is ever reached.

Early signal.  A dedicated Stage A marker for this exact case (the stage
sketch names it PASS-M8A-ZERO-ARG-UNCHANGED), measured on
stdlib/prelude.tot:74, and the same bootstrap check
(`tot check examples/church.tot`) that PASS-M7A-CONSERVATIVITY
(dev/gates.sh:3402-3443) already runs.

Rollback.  Revert the Stage A commit.  The conflict note names the exact
line (surface/elab.ml:308-309) and states that the zero-argument branch
was routed through the new instantiation instead of kept as `local_ty`.

Answers finding: A1-F1 (ACCEPT, design-verdict section 4, Attack 1), the
finding that the published Stage A arm "regresses the zero-argument case
and breaks the prelude bootstrap" at exactly this line.

### Risk 3: Stage B's re-spell is refused for a second time (R-Q7)

Reading that makes it live.  At the reference state,
stdlib/prelude.tot:92-94 still carries the explicit spelling
`fun A B a b f h => subst0 A a b (fun z => Eq B (f a) (f z)) h (refl B (f a))`,
not the `Eq _` re-spell: conflict note C-D3
(dev/M7-BUILD-LOG.md:2311-2341) already measured the refusal once,
tracing it to the motive body reaching the elaborator in infer position
with no expected type arriving (dev/M7-BUILD-LOG.md:2318-2327).  Stage A
fixes the capture, but the rigid match that consumes the capture retries
against a head-normal form only when the captured type is CLOSED,
`is_closed ity` at surface/elab.ml:422, inside the whnf retry
(surface/elab.ml:417-428).  The capture Stage A produces for `f a` and
`f z` carries the free locals `A` and `B`, so it is open, and the retry
never fires.  A capture that resolves slot 0 correctly can still leave
the rigid match refusing for this second, independent reason, and the
re-spell fails again.

Early signal.  Stage A lands green (its own markers pass), then the
Stage B assertion `tot check examples/church.tot` on the re-spelled
stdlib/prelude.tot:94 exits 1.

Rollback, per R-Q7.  Stage B STOPS.  It books the refusal as a conflict
note in the C-D3 shape and does not force the re-spell around the second
cause.  A retreat from the re-spell, keeping the explicit `Eq B`
spelling, is a user ruling and not a builder decision
(dev/M7-BUILD-LOG.md:2340-2341).

Answers finding: this is the C4 acceptance-test relationship the
design-verdict states in section 1 ("C4 is an ACCEPTANCE TEST of C5, not
a separable candidate") and finding A1-F2, read forward past the Stage A
repair to the next place the same open-type obstacle can recur.

### Risk 4: Stage C's reporting fix reseals the wrong transcript, or none

Reading that makes it live.  Item 10's fix carries the record the miss
path already holds into the prelude error arm, `prerr_endline ("prelude:
" ^ Serror.to_string e)` at bin/tot.ml:179-181, in the shape
bin/tot.ml:112-122 already uses for the target path.  That arm is default
driver output.  dev/gen-m5e-transcript.sh loops `examples/*.tot` and
`test/fixtures/*.tot` through `tot.exe check` and records every exit
code, stdout and stderr into dev/m5e-default-transcript.txt (10407 lines
at the reference state), with the block count pinned at the last move,
101 to 102 (commit body of 8cf0b8b, M7 Stage D).  If item 8's position
list or item 9's gate route also changes the printed text of any
transcript-covered fixture, and Stage C reseals only for the one prelude
tail line it expected, the transcript drifts silently on the fixtures
nobody re-checked by hand.

Early signal.  PASS-M8C-PRELUDE-TAIL, and a plain diff of
dev/m5e-default-transcript.txt before and after Stage C: any block whose
byte count moves outside the one line Stage C predicts is the signal.

Rollback.  Revert the Stage C commit.  The conflict note names which
fixture's transcript block moved, by how many lines, and whether the
cause was item 8, item 9 or item 10.

Answers finding: A1-F7 (ACCEPT, design-verdict section 4, Attack 1), "a
stage that adds a tail there moves default driver output, so it owes the
reseal that dev/gates.sh:2566-2569 describes," which the Stage C sketch
already books as a marker; this risk is what that marker must actually
catch, not the one line Stage C plans for.

### Risk 5: Stage D hides a required API or changes storage behaviour

Reading that makes it live. Stage D adds interfaces to fifteen original
modules plus the new private Global_store, reaching 18 .ml/.mli pairs.
Hiding Global.add from Check, hiding Quantity's constructors, or omitting
Global.StringMap breaks existing callers. D1-D3 preserve the required
types and provide explicit private access for Check and the white-box
kernel tests. The storage delegation is also a real .ml change: verify
the same entries, map ordering, marshal payload and output, not merely
successful interface compilation. No interface change justifies removing
the existing tests that exercise malformed environments.

Early signal.  PASS-M8D-NO-BEHAVIOUR-CHANGE, the corpus digest taken
before and after Stage D, and the suite case pinning that `def rec` still
elaborates against its own self-entry.

Rollback.  Revert the Stage D commit.  Per R-Q3, Stage D is also the
named cut if M8 must shrink, so a Stage D rollback restores M8 to its
Stage A through C exit rather than stalling the whole milestone.

Answers finding: A1-F3 and review findings 1, 2 and 4. The three Stage D
mutations remain interface deletion, public add export, and Quantity's
rendered Many string, respectively. D4 also re-tests the preserved Stage A
digest mutation after its explicit baseline transition.

## 9.2 Rollback discipline

Each stage, A through D, is one commit.  A rollback is a `git revert` of
that one commit, paired with a conflict note in the C-D3 shape that
states what was predicted, what the build measured, and which risk
block above the failure matches.  No stage's rollback touches a sibling
stage's commit: Stage A through C never touch lib/. Revert Stage D's private store,
interfaces, caller/test rewires and baseline transition together; preserve
the earlier stages' gate legs and cases, and a Stage B stop under R-Q7 leaves Stage A's commit standing on
its own merits, gated by PASS-M7A-CONSERVATIVITY (dev/gates.sh:3402-3443)
and PASS-M8A-KERNEL-UNCHANGED rather than by Stage B's success.

## 9.3 M9 hand-off

### C1: the WF package with the wide relation formal, deferred by R-Q1

The channel stays open on purpose.  `type rule = Structural`
(lib/totality.ml:20) is the whole admission-rule enumeration, and the
`Term.App` arm of `guarded_call` (lib/totality.ml:97-109) is kept, in the
module's own words, "so the M7 rule re-enters HERE by non-exhaustiveness"
(lib/totality.ml:107).  No wf descent may accept the shape of
test/fixtures/bad2.tot in M8, and this hand-off carries the reason
forward rather than closing it.

- No accessibility inhabitant beyond `accZero` exists in the corpus.
  `reducible def LtNat` relates every `m` to every `succ p`, including
  `succ p` to itself (test/fixtures/m5e-acc.tot:3-4), so `Acc Nat LtNat
  (succ p)` is uninhabited and `accZero`
  (test/fixtures/m5e-acc.tot:13-14) is the only witness in the tree.  M9
  cannot cost a wf-descent stage at zero; it must first ship a
  well-founded relation and a total accessibility builder.  Answers
  finding A3-F2 (ACCEPT).
- The known selector for a second admission rule accepts a `wf`-spelled
  copy of the shape test/fixtures/bad2.tot records as wrong.  bad2.tot's
  own comment states the file "was ACCEPTED under --experimental-wf...
  because the prototype clause inspected the head's status, never the
  field's type" (test/fixtures/bad2.tot:6-8), and
  PASS-M6A-INFINITARY-REJECTED exists, in the gate's own words, to make
  "the deletion irreversible by accident" (dev/gates.sh:2508-2509).
  Whether any wf spelling may accept that shape is a user ruling, not a
  panel or builder ruling, and R-Q1 leaves it open for M9.  Answers
  finding A3-F3 (ACCEPT, and named a user ruling).
- The soundness argument for a `Wf_descent`-shaped rule is a loan against
  `strict_pos`, the one-level fence at lib/check.ml:1961-1976, which
  tests "no occurrence at all, or exactly the applied form" and stops at
  one level.  M9 must state, in SPEC, what happens to any `Wf_descent`
  rule the day that fence widens (C2, below), because nothing in the
  present rule pins the dependence.  Answers finding A3-F1 (ACCEPT).
- Q5's premise, a wide relation formal, is refused at the reference
  state: `define_ind` closes parameters at `Quantity.Zero`
  unconditionally, and the shipped family already spells its relation
  formal erased, `data Acc (0 A : Type 0) (0 R : A -> A -> Type 0)`
  (test/fixtures/m5e-acc.tot:1).  M9 opens this as a conflict note in the
  C-D3 shape, not as a silent premise swap.  Answers finding A3-F6
  (ACCEPT).

### C2: nested inductives and the jarr migration, deferred by R-Q2

The nested-inductive rule lands FIRST and soaks for a milestone before
the jarr migration is taken, the M6 pattern the ratification names.
Both fence legs, PASS-M6A-FENCE-COVARIANT (dev/gates.sh:2552) and
PASS-M6A-FENCE-CONTRAVARIANT (dev/gates.sh:2560), stay green through M8;
the comment above them states plainly that they are "DESIGNED to go red
the day C3 lands nested inductives... Do not \"fix\" them by deleting
them; re-open the design instead" (dev/gates.sh:2542-2546).

- A polarity walk that recurses through foreign heads without a visited
  set does not terminate on a self-referential family.  `List`
  references itself in its own `cons` field
  (stdlib/prelude.tot:6), so a walk asking "is this parameter positive"
  re-asks the query already in progress.  M9's rule needs a visited set
  or a budget from the first line, not as a repair after a hang.
  Answers finding A2-F1 (ACCEPT).
- Any nested-inductive fixture tracked under test/fixtures/ enters
  dev/gen-m5e-transcript.sh's glob and forces a transcript reseal;
  dev/gates.sh's own comment on the nested-inductive fixtures says a new
  fixture "would enter the gen-m5e-transcript.sh glob and force a
  transcript reseal this stage does not need," which is exactly why an
  earlier stage generated its fixture into a scratch directory instead.
  M9 budgets the reseal from the start or repeats that scratch-directory
  pattern. Answers finding A2-F3 (ACCEPT).
- The kernel has no reporting channel to lean on.  Every
  `Sys.getenv_opt` site at the reference state is under surface/
  (surface/bootstrap.ml has two, surface/cache.ml has three), lib/ has
  none, and lib/ builds strings with `Printf.sprintf` only
  (lib/error.ml), so a lib-side polarity walk cannot report through an
  env var the way M9's design may want to debug it; the channel needs
  plumbing through surface/run.ml and bin/tot.ml, or a driver-output
  change of its own. Answers finding A2-F4 (ACCEPT).
- The jarr migration hard-wires eight constructor names,
  `jnull`, `jbool`, `jnum`, `jstr`, `jarrNil`, `jarrCons`, `jobjNil`,
  `jobjCons` (surface/bootstrap.ml:66-73), and again in lib/interp.ml
  (for example lib/interp.ml:376 and lib/interp.ml:402-403), so the
  migration is real work in at least two modules plus the prelude, not a
  rider on the polarity rule.
- A gate leg that pins "the reason string stays unchanged" is only a
  real leg if the string is already asserted verbatim by a surviving
  marker; a leg whose mutation edits the same reason string an M9 stage
  writes tests authorship, not behaviour.  Any M9 conservativity leg
  must point its mutation at code the rule stage does not itself touch.
  Answers the ACCEPT half of finding A2-F5.

### Residual debt M8 does not take

- Item 5, the Frozen emptiness claim.  `Frozen` is documented as
  "reachable only through an inhabitant of a provably empty type," dead
  code by the Stage A soundness argument, existing only so a missed case
  degrades to a neutral instead of a loop (lib/interp.ml:84-91).  It is a
  proof obligation about the evaluator's guard with no seam in any file
  M8's four stages edit, and the unstaged Stage E diff already records
  both horns in SPEC.  It waits for a milestone that touches lib/interp.ml
  or the guard itself.
- Cumulativity, Eq1, and perf work against the tier ceilings.  Carried
  forward from M7's own reasons: untouched by any candidate's measured
  demand, and the tiers are hang detectors, not budgets to spend
  (dev/M7-PLAN.md:1008-1011).  Nothing in M8's four stages changes either
  judgement.
- Any `Cache.format_version` bump.  M8 keeps the constant at 10
  (surface/cache.ml:118, asserted by `rg -c 'let format_version : int =
  10'` at dev/gates.sh:3831 and the equality check at dev/gates.sh:3837),
  because the cache key already folds the prelude source and needs no
  bump to invalidate on a source change (dev/M7-PLAN.md:1006-1007).  C2's
  jarr migration, when M9 takes it, is the first change that might
  reopen this question, because it moves prelude-level representations
  rather than just prelude bytes.
- The 12 `surface/*.ml` interfaces.  R-Q3 narrows the M8 sweep to lib/
  only.  Three of the twelve surface files are files Stage A or Stage C
  edits, surface/elab.ml (the `synth` arm at surface/elab.ml:397-410),
  surface/run.ml (the hole-tail helper at surface/run.ml:654-661) and
  surface/bootstrap.ml (the constructor list at
  surface/bootstrap.ml:66-73), so a surface/ sweep in M8 would collide
  with the same diffs the .mli sweep is scheduled last in M8 to avoid.
  It waits for a milestone whose stages do not touch those three files,
  or for M8's own Stage D pattern repeated once M8's diffs have landed.

Section 9 ends.
