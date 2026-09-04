# M7 build plan: argument-driven holes, the prelude re-spell, and the M8 tripwires

Authoritative spec for the M7 implementation agents.  Read this WHOLE
preamble before you read your own stage section, and read it before you
touch code.  The repo is `/Users/oobi/Documents/tot` (OCaml, dune),
entered at HEAD `66b444f`.  Five sequential stages (A, B, C, D, E), one
agent per stage, each stage green on its own gate before the next one
starts.

This document is self-contained.  Every design decision M7 needs is
written out in this preamble or in a stage section.  Do NOT go looking
for the design brief, the panel proposals or the verdict;  none of them
is an input to the build.  The verdict at
`/Users/oobi/Documents/tot-m7-design-verdict.md` was RATIFIED BY USER on
2026-09-03, all five open questions answered (section 1.1), and AMENDED
BY USER on 2026-09-04 at questions 1 and 2 (section 1.1a).  The
amendment overrides the ratification where the two differ.  Its 18 pins
are restated in the pin table of section 1.4 and again in the stage
sections.  Four pins are read as amended: 2, 5, 6 and 11 (section 1.4).
A stage section may add detail to a pin.  A stage section may NOT
reinterpret a pin, soften it, or trade it for a different one.  If
you believe a pin is wrong, record the argument in
`dev/M7-BUILD-LOG.md` and build it as written, unless the section 5
protocol applies.

Background reading, in this order, only if a detail here is ambiguous:

1. `/Users/oobi/Documents/tot/SPEC.md` sections 2 and 6
2. `/Users/oobi/Documents/tot/dev/M6-PLAN.md` (the house plan format)
3. `/Users/oobi/Documents/tot/dev/M6-BUILD-LOG.md` (the stage report and
   mutation-proof shape M7 reuses)

## 1. Purpose and entry state

M7 builds the ratified winner: the DOGFOOD proposal, repaired, with
grafts from both losers.  The panel scored dogfood 27 of 40, hardening
20 of 40 and semantics 18 of 40.  M7 puts argument-driven hole
resolution into the elaborator at check position and, under the
amendment of 2026-09-04, at infer position too.  It closes the seven
pinned anchor sites and the two the verdict pinned as unreachable, so
all nine measured A-bucket sites carry a hole at exit.  It moves the
six duplicated guard helpers into the prelude, re-spells the prelude
anchors, and lands three negative fixtures that M8 inherits as working
tripwires.  M7 adds NO admission
rule to `lib/` (pin 1): `type rule = Structural` gains no constructor
(lib/totality.ml:20) and `Check.define` keeps its REQUIRED `~rule`
(lib/check.ml:1465-1466), so a future rule still re-enters by compiler
error at every call site.

### 1.1 Ratification of the five open questions

The user ratified the verdict on 2026-09-03.  The five answers below are
binding on every stage.  Each answer carries its consequence for this
plan.

- **Q1 guard slot posture: DEFAULT.**  Two of four guard slots close in
  M7.  The other two slots are pinned as explicit-forever negatives,
  each with a fixture and the reason recorded in the plan and in the
  gate text.  The infer-path settle extension stays out of M7.
  Consequence: pin 5 fixes the honest reach at seven of nine anchor
  sites, pin 6 owns the two refused slots, and Stage A grows by no
  infer-path work.  AMENDED on 2026-09-04, section 1.1a: the last
  sentence of the answer and the last clause of the consequence are
  withdrawn.  The infer-path settle is IN, it is built in Stage A, and
  Stage B re-derives pin 6.
- **Q2 multi-hole shape: DEFAULT.**  Pin 7 lands in the position-only
  tail shape.  No second traversal.  No change to the Serror error type.
  Consequence: Stage C reports positions only, `Serror.t` keeps its
  constructor set (pin 8), and full per-hole expected types move to the
  M8 debts list (section 8, item 8).  CLARIFIED on 2026-09-04, section
  1.1a: "no second traversal" takes the STRICT reading, so Stage C may
  not add a pass of any kind over parsed items or terms.

  Ruled on 2026-09-04 (round 3):  (a) Pin 11's corpus literal is 69, not
  67, because Stage B closes all four guard slots and
  PASS-M6E-GUARD-HOLES moves from 22 to 26.  (b) Pin 5's reach at M7 exit
  is nine of nine A-bucket anchors; the words "exactly seven" are
  retired.  Fallback B7 still reverts examples/guard.tot:134 and
  examples/guard-rewrap.tot:265, for exit 394 and literal 24.  (c) Part
  A3b, the infer-path settle that reaches the inner liftIO hole at
  stdlib/prelude.tot:173, stays in Stage A.  Rollback step 2, reverting
  A3b alone for the D8 retreat literals 46 and 66, is a user decision,
  never a builder decision.  (d) The Stage C prelude-arm carve-out moves
  to M8; bin/tot.ml:171-173 keeps its one-line report on a cache hit in
  M7 (section 8, item 10).  (e) Pin 7's position-only tail may name a
  hole that elaboration would have filled had elaboration reached it;
  that is the intended reading.  (f) The stale SPEC anchors at
  dev/M6-PLAN.md:540-581 get their own doc-only fix, in their own
  commit, outside this plan and outside Stage E.  (g) The PASS-M5D-TIERS
  literal moves 200 to 204 across the stages by the count in the gate
  paragraphs, not by a measurement; each stage builder re-derives the
  value it writes.
- **Q3 prelude re-spell timing: DEFAULT.**  The prelude is re-spelled in
  M7 as scoped.  Stage D flips the prelude-carries-zero-holes assertion
  and moves the two pinned gate literals.  The arithmetic in the verdict
  is binding: 99 total sites, 60 expected-type-only, 67 holed anchors at
  exit.  Consequence: pins 9, 10 and 11 all land in Stage D, and
  PASS-M6E-GUARD-HOLES has its `m6e_pz` assertion re-designed, never
  deleted (dev/gates.sh:3089, 3094).
- **Q4 oracle spending: DEFAULT.**  Pins 14 and 15 land in Stage E as
  negative fixtures for rules that M7 does not build.  Consequence:
  Stage E budget pays for PASS-M7E-WF-PROVENANCE-ORACLE and
  PASS-M7E-POSITIVITY-LAUNDER-ORACLE, and both fixtures exit 1 at HEAD
  and at M7 exit.
- **Q5 quantity posture for relation formals: WIDE RELATION FORMAL.**  An
  eventual Acc-style family takes a wide relation formal and pays at
  erasure.  The quantity discipline does not widen for relation
  positions.  M8 explores this direction.  M7 builds nothing for it.
  Consequence: the direction appears ONLY in the M8 hand-off list
  (section 8, item 1).  A stage that writes quantity code for relation
  formals has found a conflict (section 5).

### 1.1a Ratification amendment (2026-09-04)

The user amended two of the five answers on 2026-09-04, after reading the
plan authoring notes.  The amendment block sits at the end of
`/Users/oobi/Documents/tot-m7-design-verdict.md` and it OVERRIDES the
2026-09-03 ratification block where the two differ.  The rest of the
verdict stays binding.  Both amended answers are quoted verbatim below,
each with its consequence for this plan.

Q1, verbatim:

> Q1 amended: the infer-path settle extension IS authorised as scoped elaborator surface, built in Stage A. Reason: the Stage A writer measured only six of nine A anchors reachable at HEAD; stdlib/prelude.tot:173 sits behind the class-former fence (surface/elab.ml:511-522) and closes only with the settle. Consequences: pin 5 keeps its seven anchors; pin 2 (conservativity) stays binding, so the settle may change only programs that fail at HEAD with the hole error, and the Stage A probes must show that; Stage B re-derives whether the two guard slots pinned as explicit-forever negatives now close under the settle, and pins a slot as a negative only with a true reason.

Consequence, in five parts:

1. Stage A builds the settle on the INFER path as well as the check
   path.  It is elaborator surface only.  It ships two more markers,
   PASS-M7A-INFER-SETTLE and PASS-M7A-INFER-SETTLE-BUDGET, so Stage A
   carries 7 markers and 12 suite cases (section 3).
2. The fence is real and it is cited.  The check-position hole arm at
   surface/elab.ml:511-522 fills a holed argument only when `fence` is
   true;  every other argument goes to `term`, the INFER entry, whose
   hole arm at surface/elab.ml:287-291 has no expected type to offer.
   `stdlib/prelude.tot:173` is `fun A d => mkEqD (List A) (listEqBy A
   (eqf A d))`, a nested spine under a class former, so it reaches the
   infer entry and closes only with the settle.
3. Pin 2 keeps its conservativity half.  A program that is GREEN at HEAD
   keeps its exit code and its stdout byte for byte, and a program that
   FAILS at HEAD keeps its exact error line unless that line is the hole
   error.  PASS-M7A-INFER-SETTLE-BUDGET digests the whole corpus and is
   the leg that shows it.  Pin 2's first sentence, "CHECK position
   only", is the part the amendment withdraws.
4. Pin 5 keeps its seven anchors.  The amendment buys the seventh, not
   an eighth.  Stage A measured six of the nine A anchors reachable at
   HEAD, and the settle adds `stdlib/prelude.tot:173`, which is pin 5's
   seventh site.  The two guard slots that Stage B then closes are pin
   6's, not pin 5's, so pin 5's number does not move.
5. Pin 6 is re-derived, not assumed.  Stage B measured both slots at
   HEAD and found the settle reaches both, so the recorded reason for
   their negative status stops being true.  Stage B retires both
   negatives, closes all four guard A slots, and replaces the retired
   refusal obligation with one new negative whose every later argument
   is itself a hole.  Its marker is PASS-M7B-LIFTIO-SLOT-CLOSES, which
   replaces the reserved name PASS-M7B-ARG-SLOT-EXPLICIT.

Q2, verbatim:

> Q2 clarified: "no second traversal" takes the strict reading. Stage C may not add any pass over parsed items or terms, not even a syntactic fold on the failed path. Hole positions for the position-only tail must be collected inside a traversal that already exists at HEAD (the parse or the elaboration walk), and the Serror type stays unchanged. If no such design exists, Stage C records the block with the reason and the user decides between dropping multi-hole reporting from M7 and changing Serror.

Consequence, in three parts:

1. A syntactic fold over `Syntax.item` on the failed path is BARRED,
   even though it adds no cost to a green run.  Stage C's earlier design
   rested on that fold and it is deleted.
2. Stage C collects hole positions inside the PARSE walk that already
   runs at HEAD, at the one place that builds a hole node.  `Serror.t`
   is unchanged, no partial term is built, and the exit code stays 1.
3. The escape hatch is not used.  A compliant design exists, so Stage C
   records NO blocked paragraph and the user has nothing further to
   rule on for open question 2.  A later stage that finds the parse-walk
   design impossible has a section 5 conflict, and the ruling it needs
   is the user's, not a stage's.

The two amended answers do not move Q3, Q4 or Q5.  The arithmetic of Q3
(99 total sites, 60 expected-type-only) is untouched, because a re-spell
changes which sites are holed and never how many sites exist.  The
holed-anchor literal DOES move, because Stage B now re-spells four guard
slots and not two (pin 11 as amended, section 1.4).

### 1.2 Baseline

M6 is committed at `66b444f` and the tree is clean
(`git -C /Users/oobi/Documents/tot status --porcelain | wc -l` printed
`0`, run 2026-09-03).  The battery at entry is recorded in
`/Users/oobi/Documents/tot-m7-baseline-gate.log`, written 2026-09-03
17:04:45 to 17:05:43:

    HEAD=66b444f
    BUILD-EXIT=0
    GATE-EXIT=0
    PASS=371
    FAIL=0

`rg -n '^PASS=' /Users/oobi/Documents/tot-m7-baseline-gate.log` printed
`11:PASS=371`.  That 371 is the entry number for the whole chain.

Entry commit note, measured 2026-09-04.  The branch `main` now points at
`d028a2a`, "M7 plan: argument-driven holes, multi-hole tail, prelude
re-spell, SPEC repair", and the tree is still clean
(`git -C /Users/oobi/Documents/tot status --porcelain | wc -l` printed
`0`).  `git -C /Users/oobi/Documents/tot diff --name-only 66b444f
d028a2a` printed one path, `dev/M7-PLAN.md`, and `--shortstat` printed
`1 file changed, 4385 insertions(+)`.  The CODE tree at `d028a2a` is
therefore byte-identical to `66b444f`, so every file:line citation in
this plan holds at the entry commit and the 371 stands.  A stage that
sees a second commit on `main` re-runs the battery before it trusts any
number here.

Gate command battery (all four must be green before you report):

    dune build --root /Users/oobi/Documents/tot
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -3
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -3
    zsh /Users/oobi/Documents/tot/dev/gates.sh > "$TMPDIR/tot-gate.out" 2>&1; echo "GATE-EXIT=$?"
    rg -c '^PASS' "$TMPDIR/tot-gate.out"
    rg -c '^FAIL' "$TMPDIR/tot-gate.out"

Opam switch note.  A bare shell has no dune on PATH:
`which dune` printed nothing and exited 1 (run 2026-09-03).  Every dune
command needs `eval "$(opam env)"` FIRST, in the SAME shell invocation.
The prebuilt binary `/Users/oobi/Documents/tot/_build/default/bin/tot.exe`
needs no opam env and every probe in section 1.5 ran against it.

Run the battery BEFORE your first edit and again before your report.
Record the tails in your report.  A red at baseline belongs to the
previous stage, not to yours, and you must say so instead of absorbing
it.  Never delete or weaken an existing case to make a stage green.  M7
retires NO existing marker and NO existing test.  Two existing legs have
their LITERALS edited, at Stage B and Stage D, and both stay green at
every stage boundary (pin 11).

### 1.3 Scope

SCOPE IN, quoted from the verdict:

> 1.  Argument-driven hole resolution in the elaborator, check position only, reaching the seven
>     reachable A-bucket anchor sites.  Reason: the only classifier-measured demand on the M7 list.
> 2.  The two unreachable A slots stay EXPLICIT and become pinned negatives with the reason recorded
>     in SPEC.md.  Reason: an honest milestone states the shape of its own incompleteness.
> 3.  Multi-hole reporting in the position-only tail shape of pin 7.  Reason: reachable without a
>     partial term and without a Serror signature change.
> 4.  The six-helper move into stdlib/prelude.tot and the prelude anchor re-spell, with re-derived
>     gate literals.  Reason: retires the duplicated-helper debt and the 40-anchor prelude debt in one
>     stage, and the arithmetic is now exact.
> 5.  Small debts (h), (i) and (j).  Reason: cheap, and (i) settles a question two proposals got
>     wrong.
> 6.  SPEC.md sections 5 and 6 repair plus the five citation fixes.
> 7.  Oracle preservation and extension for M8: the grafted fixtures G2, G3 and G6.

SCOPE OUT, quoted from the verdict:

> 1.  The whole well-founded recursion package.  Reason: no stated activation channel, a vacuous
>     oracle, and the headline probe shows the erased-domain workaround does not exist.
> 2.  Nested inductives and the jarr migration.  Reason: the polarity rule as proposed launders, and
>     the migration needs .ml edits in two modules the proposal excluded.
> 3.  The .mli sweep.  Reason: hygiene, no measured demand, and it collides with every other stage's
>     diff.
> 4.  Any format_version bump.  Reason: the cache key already folds the prelude source, so the Stage
>     D edit invalidates the cache without one.
> 5.  Cumulativity and Eq1.  Reason: untouched by all three proposals' measured demand.
> 6.  Perf work against the tier ceilings.  Reason: the tiers are HANG ceilings, not budgets.
> 7.  Error recovery beyond reporting.  No partial terms, no continued elaboration after an error.
> 8.  Extending the settle pass into the INFER path, unless the user rules otherwise at open
>     question 1.

Scope-out item 8 named its own escape clause, "unless the user rules
otherwise at open question 1", and the user did rule otherwise on
2026-09-04.  Item 8 is therefore WITHDRAWN: the settle pass extends into
the infer path, in Stage A, as scoped elaborator surface (section 1.1a).
The other seven scope-out items stand as written.

Two scope-in items read as amended.  Item 1 covers the infer path as
well as check position, at the same seven pin 5 anchor sites.  Item 2's
"stay EXPLICIT" is withdrawn: Stage B measured that the settle reaches
both slots, so both close, and the pinned negative that item 2 asked for
is replaced by one whose every later argument is a hole.  Section 1.1a
gives the reason and Stage B gives the measurement.

The three small debts named by scope-in item 5 are (h) the guard
tokenizer duplication plus the Apache licence text, (i) the
instance-body dead threading at lib/check.ml:1770-1776, and (j) the
stale `spine` doc comment at surface/elab.ml:470-476.

### 1.4 The pin table

Eighteen pins, each with exactly one owning stage.  The pin text is
quoted from the verdict's PINS section.  The marker column names the
gate leg that makes the pin testable.

| # | Pin text (verbatim) | Stage | Marker(s) |
| --- | --- | --- | --- |
| 1 | "M7 changes no admission rule in lib/.  `type rule = Structural` gains no constructor and `Check.define`'s `~rule` stays REQUIRED, so the compiler keeps enumerating every call site." | A | PASS-M7A-KERNEL-UNCHANGED |
| 2 | "Argument-driven resolution is CHECK position only.  A hole in infer position keeps its exact current message." | A | PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE, PASS-M7A-INFER-SETTLE, PASS-M7A-INFER-SETTLE-BUDGET (read as amended) |
| 3 | "The rule.  In an application whose head is a global with leading erased Type formals, a hole in a leading erased slot resolves if and only if some LATER explicit argument of the same spine infers a type whose head-normal form determines that slot by first-order matching against the head's declared formal type.  No metavariable escapes the spine.  No backtracking.  No unification across definitions." | A | PASS-M7A-ARGHOLE-RESOLVES |
| 4 | "Conservativity at the Stage A boundary: every fixture green at HEAD stays green with byte-identical stdout." | A | PASS-M7A-CONSERVATIVITY |
| 5 | "Honest reach, as a number: exactly seven of the nine A-bucket anchor sites resolve after Stage B.  The seven are stdlib/prelude.tot:17, :145, :159, :173, :176, examples/guard.tot:133 and examples/guard-rewrap.tot:264." | B | PASS-M7B-GUARD-ARG-HOLES, its seventh site bought by PASS-M7A-INFER-SETTLE, and its prelude half re-checked by PASS-M7D-PRELUDE-HOLES |
| 6 | "The two unreachable slots, examples/guard.tot:134 and examples/guard-rewrap.tot:265, stay explicit, and a holed copy of each must fail at exit 1 with `hole: expected Type 0`." | B | PASS-M7B-LIFTIO-SLOT-CLOSES (read as amended) |
| 7 | "Multi-hole reporting shape.  The first hole keeps its exact current line;  further holes in the same definition are reported on one following line of the form `N more hole(s) at L:C[, L:C]*`, positions only, no expected types.  `Serror.t` stays a single-error variant, no partial term is constructed, and the exit code stays 1." | C | PASS-M7C-MULTI-HOLE-TAIL, PASS-M7C-SINGLE-HOLE-UNCHANGED |
| 8 | "No constructor is added to or removed from `Term.t` or `Serror.t` in M7." | C | PASS-M7C-SINGLE-HOLE-UNCHANGED, which carries the constructor-count assertion |
| 9 | "The six shared helpers firstNonEmpty, lastOr, splitEach, firstToken, orEmpty and elideAt move to stdlib/prelude.tot exactly once, and the guards reference them." | D | PASS-M7D-HELPERS-SHARED |
| 10 | "Post-move classifier literal, exact and binding: `ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30`" | D | PASS-M7D-ANCHORS |
| 11 | "The corpus holed-anchor literal walks 22 at HEAD, 24 after Stage B, 22 after the Stage D move, and the Stage D landed number after the prelude re-spell, which is 67 if all forty expected-type-only and all five argument-driven prelude anchors are re-spelled." | D | PASS-M7D-PRELUDE-HOLES, plus the literal edits inside PASS-M6E-GUARD-HOLES at Stage B and Stage D (walk read as amended) |
| 12 | "PASS-M5D-MEASURE-LOG's live literal is 22 lines at dev/gates.sh:3016.  The \"count 18\" at dev/gates.sh:2531 is a stale comment and Stage E fixes the comment only." | E | PASS-M5D-MEASURE-LOG stays green with no literal change |
| 13 | "Marker namespace.  PASS-M7A-*, PASS-M7B-*, PASS-M7C-*, PASS-M7D-* and PASS-M7E-* are free." | A | every PASS-M7 marker;  section 4.2 makes it a standing rule for B to E |
| 14 | "Grafted WF oracle.  Stage E lands a negative fixture whose descent is accessibility-shaped over a family with the right parameter count, relation formal and index, but whose recursive call descends on a formal that is NOT the candidate's principal seed.  It must exit 1 at HEAD and at M7 exit." | E | PASS-M7E-WF-PROVENANCE-ORACLE |
| 15 | "Grafted positivity oracle.  Stage E lands the two-layer launder and its one-layer control as negative fixtures, both at exit 1, with the transcripts recorded above." | E | PASS-M7E-POSITIVITY-LAUNDER-ORACLE |
| 16 | "Interp.Frozen and the `Quantity.Zero` arm of `Run.compute_guard` are unchanged in M7.  The emptiness claim at lib/interp.ml:85-91 is recorded in SPEC.md as an OPEN obligation with both horns named and is not asserted as proved." | E | PASS-M7E-SPEC-CITATIONS |
| 17 | "Debt (i), instance rule threading.  `Check.define_instance` keeps passing `~rule:Totality.Structural` and keeps passing no `~rec_`;  the decision is recorded as a comment and pinned by a test." | E | PASS-M7E-INSTANCE-RULE |
| 18 | "No format_version bump.  surface/cache.ml keeps `format_version = 10`." | D | PASS-M7D-CACHE-KEY |

Amended pin readings, 2026-09-04.  Five rows read differently after the
amendment.  The pin TEXT above stays verbatim, because it is the
verdict's;  the reading below is what a stage builds.

- **Pin 2.**  The first sentence, "CHECK position only", is withdrawn.
  Resolution runs at check position and at infer position, both in
  Stage A.  The second sentence survives in a sharper form: a hole that
  no later argument of its own spine determines keeps its exact current
  message, and so does a hole under a class-former fence.  Stage A pins
  three such holes and one control (PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE)
  and digests the whole corpus for the conservativity half
  (PASS-M7A-INFER-SETTLE-BUDGET).
- **Pin 5.**  The number does not move.  Seven of nine anchor sites, the
  same seven sites, and the seventh one, `stdlib/prelude.tot:173`,
  arrives only through the Stage A infer settle.
- **Pin 6.**  The mechanism is replaced, the intent survives.  Both
  slots at `examples/guard.tot:134` and `examples/guard-rewrap.tot:265`
  now CLOSE, because the settle elaborates the `liftIO _ (...)`
  argument that HEAD refused at surface/elab.ml:287-291.  The refusal
  obligation moves to one new fixture whose every later argument is a
  hole, which exits 1 with `hole: expected Type 0` at HEAD and at M7
  exit.  Its marker is PASS-M7B-LIFTIO-SLOT-CLOSES.  A slot stays a
  negative only with a true reason, which is the amendment's own words.
- **Pin 11.**  The walk grows by two at Stage B, because four guard
  slots are re-spelled and not two.  As amended: 22 at HEAD, 26 after
  Stage B, 24 after the Stage D helper move, and 69 after the Stage D
  prelude re-spell.  The prelude half is unchanged at 47.  Arithmetic:
  22 + 4 = 26, 26 - 4 + 2 = 24, and 24 + 45 = 69.  The HEAD 22 is
  measured in section 1.5;  the 26, the 24 and the 69 are measured by
  Stage B (probe P8) and Stage D (probes P16 and P17) on rehearsal
  trees.
- **Pin 13.**  The namespace claim is unchanged and still holds:
  `rg -c 'PASS-M7' /Users/oobi/Documents/tot/dev/gates.sh` printed
  nothing and exited 1 on 2026-09-04.  The RESERVED SET grows from 18
  names to 20, because Stage A adds two (section 3).

Two marker names in the verdict's stage allocation carry no pin of their
own: PASS-M7A-SPINE-COMMENT (debt (j)) and PASS-M7E-DEBT-H (debt (h)).
Both are scope-in item 5.

Coverage convention, stated once here and binding on every stage section.
The Stage column above names the ONE owning stage of each pin.  A stage
section header lists the pins that stage OWNS, and no others.  Two pins
also carry evidence in a second stage.  That second stage names them in
its own "Pins re-checked here, owned elsewhere" list, never in its
header, and it adds no work item for them.  A DEPENDENCY is a third
thing and it is not a re-check: a stage that needs an earlier stage's
code to be present records the need in its own entry state, names no
pin, and adds no leg.  The amendment creates two dependencies, both on
the Stage A infer settle, and both are entry-state facts of the
depending stage:  Stage B needs it for the two `liftIO _ (...)` guard
slots, and Stage D needs it for `stdlib/prelude.tot:173`.  Pin 2 stays
Stage A's alone.  The re-checks are these two:

- Pin 5.  Stage B owns it and ships PASS-M7B-GUARD-ARG-HOLES.  Stage D
  re-checks the prelude half with PASS-M7D-PRELUDE-HOLES, because the
  Stage D re-spell rewrites those five prelude sites.
- Pin 12.  Stage E owns it and fixes the stale comment at
  dev/gates.sh:2531.  Stage D holds PASS-M5D-MEASURE-LOG green with no
  literal change, because the Stage D move changes the value the leg
  reads at dev/gates.sh:3015.

### 1.5 Facts about the current binary, in probe form

Every probe below was RE-RUN on 2026-09-04 against
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe`, through the
runners `/Users/oobi/Documents/tot-m7-probes/plan/run-final.zsh` and
`/Users/oobi/Documents/tot-m7-probes/amend/pre/r2.sh`, and every "At
HEAD" line below is what the re-run printed.  The binary is the one
built from `66b444f`, and the code tree at `d028a2a` is identical to it
(section 1.2).  Probe fixtures sit beside the runners, never in the
repo;  section 1.6 gives their bytes and names the stage section that
creates the repo copy.  Do NOT restate a transcript from memory.  Re-run
the probe if your stage depends on the exact bytes.

Eight probes, one per marker whose HEAD behaviour this plan asserts.
The other twelve reserved markers are probed in their own stage
sections.

Marker: PASS-M7A-ARGHOLE-RESOLVES
Pin: 3, 5
Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot-m7-probes/plan/m7a-map-arghole.tot
At HEAD: exit 1, output contains "m7a-map-arghole.tot:1:30: hole: expected Type 0"
After stage: exit 0, output contains "def probeE : (List Nat)"
Non-vacuous because: the fourth argument `(nil Nat)` determines the holed slot by first-order matching, and HEAD still refuses the line, so the probe fails at HEAD for exactly the reason Stage A removes.

Marker: PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE
Pin: 2
Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/test/fixtures/m6c-hole-n-infer.tot
At HEAD: exit 1, output contains "m6c-hole-n-infer.tot:1:6: hole: no expected type at this position"
After stage: exit 1, the same line byte for byte
Non-vacuous because: this fixture ships at HEAD, its hole is the whole argument of a bare `eval`, so no later argument of any spine determines it, and pin 2 as amended freezes exactly this message;  the leg is a differential against PASS-M7A-ARGHOLE-RESOLVES, whose probe must flip at the same stage, so a settle that fires everywhere fails here and a settle that fires nowhere fails there.

Marker: PASS-M7A-INFER-SETTLE
Pin: 2, 3, 5
Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot-m7-probes/plan/s3-holed.tot
At HEAD: exit 1, output contains "s3-holed.tot:2:39: hole: no expected type at this position"
After stage: exit 0, output contains "def myEqList : (0 A : Type 0) -> (w _ : (EqD A)) -> (EqD (List A))"
Non-vacuous because: this is the `stdlib/prelude.tot:173` shape, `fun A d => mkEqD (List A) (listEqBy _ (eqf A d))`, and it is the site the amendment exists for;  the fence arm at surface/elab.ml:511-522 fills only a top-level `SHole` and hands this nested `SApp` to `term`, whose hole arm at surface/elab.ml:287-291 has no expected type, so HEAD refuses it at the INFER entry;  the explicit twin `s3-explicit.tot` printed the after-stage line and exited 0 at HEAD, so the after value is a measured value and not a guess.

Marker: PASS-M7B-GUARD-ARG-HOLES
Pin: 5, 11
Command: /bin/zsh -c 'H=$(python3 /Users/oobi/Documents/tot/dev/hole-anchors.py); printf "HOLED=%s ASLOTS=%s\n" "$(printf "%s\n" "$H" | rg -c "anchor=\[_\]")" "$(printf "%s\n" "$H" | rg -c "SITE examples/guard(-rewrap)?\.tot:(133|134|264|265) head=bindIO arg=0 anchor=\[_\] pos=check bucket=A"; true)"'
At HEAD: exit 0, output contains "HOLED=22 ASLOTS="
After stage: exit 0, output contains "HOLED=26 ASLOTS=4"
Non-vacuous because: all four A slots are spelled `String` or `(Option Json)` at HEAD (`awk 'NR==133 || NR==134' examples/guard.tot` printed `let* String _ raw := readStdin in` and `let* (Option Json) _ parsed := liftIO _ (jsonParse raw) in`, and lines 264 and 265 of examples/guard-rewrap.tot are the same two lines), so the classifier writes no holed A anchor at any of the four and the second field is EMPTY, not zero;  Stage B measured `HOLED=26 ASLOTS=4` over a tree copy with only those four lines re-spelled, so both fields move together.

Marker: PASS-M7B-LIFTIO-SLOT-CLOSES
Pin: 6
Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot-m7-probes/amend/b/m7b-liftio-slot.tot
At HEAD: exit 1, output contains "m7b-liftio-slot.tot:8:8: hole: expected Type 0"
After stage: exit 0, output contains "def main : (IO Verdict)"
Non-vacuous because: this is the `examples/guard.tot:134` shape that pin 6 called unreachable, and HEAD still refuses it, so the flip measures the settle and nothing else;  Stage B's gate leg runs the refusal half in the same command, on `m7b-arg-slot-undetermined.tot`, whose every later argument is a hole and which printed `m7b-arg-slot-undetermined.tot:7:8: hole: expected Type 0` at exit 1 on 2026-09-04 and must print it again at M7 exit.

Marker: PASS-M7D-ANCHORS
Pin: 10
Command: /usr/bin/python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | tail -1
At HEAD: exit 0, output contains "ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30"
After stage: exit 0, output contains "ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30"
Non-vacuous because: the helper move removes four splitEach sites and adds two, so the classifier line changes bytes;  the exact-string leg at dev/gates.sh:3109-3112 goes red the moment the move lands without the literal edit.

Marker: PASS-M7D-PRELUDE-HOLES
Pin: 5, 11
Command: /usr/bin/python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | rg -c '^SITE stdlib/prelude\.tot:.*anchor=\[_\]'
At HEAD: exit 1, output empty
After stage: exit 0, output contains "47"
Non-vacuous because: the prelude carries zero holed anchors at HEAD, which the M6 leg asserts at dev/gates.sh:3089 and 3094, and which the command above re-measured (it printed nothing and exited 1).  The Stage D move then carries the two splitEach anchor sites into the prelude, both already holed and both bucket=E, so the prelude reads 2 before the re-spell.  The re-spell adds 45, the forty expected-type-only plus the five argument-driven prelude anchors.  2 + 45 = 47 in the prelude.  The corpus number is 24 + 45 = 69, not 67: Stage B re-spells four guard slots under the amendment, so the walk reads 26 after Stage B and 24 after the move, and pin 11's landed literal is 69 (section 1.4, amended pin readings).  Stage D section D3.3 walks both readings and names 69 the one that lands.  The prelude half does not move either way.

Marker: PASS-M7E-POSITIVITY-LAUNDER-ORACLE
Pin: 15
Command: rg -c 'PASS-M7E-POSITIVITY-LAUNDER-ORACLE' /Users/oobi/Documents/tot/dev/gates.sh
At HEAD: exit 1, output empty
After stage: exit 0, output contains "1"
Non-vacuous because: both fixtures already exit 1 at HEAD, the launder at `m7e-launder.tot:3:1: invalid constructor mkt: negative or non-uniform occurrence of Tl` and the one-layer control at `nested-neg.tot:2:1: invalid constructor mkt3: negative or non-uniform occurrence of T3` (both re-run 2026-09-04, the control against the shipped `test/fixtures/nested-neg.tot`), so the graft buys a leg and not a behaviour change;  the fixtures reach the fence at lib/check.ml:1949-1961, which is what makes them a tripwire for M8.

Gate literals, each with the command that derives it at HEAD and the
value it printed (graft G8: the command must actually print the number).
All eight were re-run on 2026-09-04 and every one printed the same value
as on 2026-09-03:

- `/usr/bin/python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | tail -1` printed
  `ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30`.
- `/usr/bin/python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | wc -l` printed `151`.
- `/usr/bin/python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | rg -c 'anchor=\[_\]'`
  printed `22`, the live PASS-M6E-GUARD-HOLES literal (dev/gates.sh:3088, 3094).
- `/usr/bin/python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | rg -c '^SITE stdlib/prelude\.tot.*bucket=E$'`
  printed `40`.
- `/usr/bin/python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | rg '^SITE .*bucket=A$'`
  printed nine rows: stdlib/prelude.tot:17, :145, :159, :173, :176,
  examples/guard-rewrap.tot:264, :265, examples/guard.tot:133, :134.
- `rg -c 'PASS-M7' /Users/oobi/Documents/tot/dev/gates.sh` printed nothing and exited 1.
- `rg -o 'PASS-M[0-9][A-Z]+' /Users/oobi/Documents/tot/dev/gates.sh | sort -u | wc -l`
  printed `16` (see conflict note C-P1 in section 5).
- `ls /Users/oobi/Documents/tot/lib/*.ml | wc -l` printed `17`, and
  `ls /Users/oobi/Documents/tot/lib/*.mli` printed budget.mli and level.mli.

### 1.6 Fixture bytes

These are the exact bytes of the fixtures section 1.5 runs.  They are
PLAN-LEVEL probe copies and they sit beside the runners, under
`/Users/oobi/Documents/tot-m7-probes/`.  A stage section owns the repo
fixture and its repo path.  Where a stage section gives bytes for the
same shape, the STAGE SECTION wins, on both path and bytes, and the copy
here is the measurement record.  Assert on the path-free substring,
never on the full first field.

Placement rule, and the reason for it.  A new `test/fixtures/*.tot` file
enters the glob at `dev/gen-m5e-transcript.sh:13` and forces a
transcript reseal, and pin 4 allows the reseal at Stage D only.  So
Stage A lands its fixtures under `dev/m7a/`, Stage B under
`test/fixtures/m7/`, which is a subdirectory and outside the glob, Stage
C under `dev/fixtures/`, and Stage E lands `test/fixtures/m7e-launder.tot`
with the reseal that Stage E owns.  No stage creates a fixture at the
plan-level basenames below except where the entry says so.

`/Users/oobi/Documents/tot-m7-probes/plan/m7a-map-arghole.tot`, the
argument-driven shape in miniature.  Stage A ships the same shape as
`dev/m7a/arg-map.tot`, which names its definition `probeF`:

```
def probeE : List Nat := map _ Nat (fun n => n) (nil Nat)
```

`/Users/oobi/Documents/tot-m7-probes/plan/m7a-map-explicit.tot`, the
explicit control that checks clean at HEAD (`def probeF : (List Nat)`,
exit 0):

```
def probeF : List Nat := map Nat Nat (fun n => n) (nil Nat)
```

`/Users/oobi/Documents/tot-m7-probes/plan/s3-holed.tot`, the
`stdlib/prelude.tot:173` shape and the site the amendment exists for.
Stage A ships these bytes at `dev/m7a/s3-holed.tot`:

```
def myEqList : (0 A : Type 0) -> EqD A -> EqD (List A) :=
  fun A d => mkEqD (List A) (listEqBy _ (eqf A d))
```

`/Users/oobi/Documents/tot-m7-probes/plan/s3-explicit.tot`, its explicit
twin, `dev/m7a/s3-explicit.tot` at Stage A:

```
def myEqList : (0 A : Type 0) -> EqD A -> EqD (List A) :=
  fun A d => mkEqD (List A) (listEqBy A (eqf A d))
```

`/Users/oobi/Documents/tot-m7-probes/amend/b/m7b-liftio-slot.tot`, the
slot pin 6 called unreachable, holed alone.  Stage B ships these bytes
at `test/fixtures/m7/m7b-liftio-slot.tot`.  The five comment lines are
part of the fixture and they carry the retirement record, so the hole
sits at line 8:

```
-- M7 Stage B (pin 6, amended): the slot the verdict pinned as an
-- explicit-forever negative.  The Stage A infer settle reaches it, so
-- the negative is RETIRED and this file records the flip: exit 1 at
-- HEAD, exit 0 after the stage.  The first slot stays explicit, so
-- this file isolates the second slot alone.
def main : IO Verdict :=
  let* String _ raw := readStdin in
  let* _ _ parsed := liftIO _ (jsonParse raw) in
  match parsed with
  | none => pureIO _ allow
  | some payload => pureIO _ allow
  end
```

`/Users/oobi/Documents/tot-m7-probes/amend/b/m7b-arg-slot-undetermined.tot`,
the negative that replaces the two retired ones.  Stage B ships these
bytes at `test/fixtures/m7/m7b-arg-slot-undetermined.tot`:

```
-- M7 Stage B (pin 6, amended): the tripwire that replaces the two
-- retired negatives.  Every later argument of the bind is itself a
-- hole, so no later argument determines the leading slot and the
-- Stage A rule must leave it alone.  Exit 1 at HEAD and exit 1 after
-- the stage, with the same message.
def probeG : IO Verdict :=
  let* _ Verdict parsed := liftIO _ _ in
  pureIO Verdict allow
```

`/Users/oobi/Documents/tot-m7-probes/plan/m7e-launder.tot`, the
two-layer launder (graft G6).  Stage E ships these bytes at
`test/fixtures/m7e-launder.tot`:

```
data U (0 A : Type 0) : Type 0 := | mku : (A -> Nat) -> U A
data V (0 A : Type 0) : Type 0 := | mkv : U A -> V A
data Tl : Type 0 := | mkt : V Tl -> Tl
```

The one-layer control needs no new file.  It SHIPS at HEAD as
`test/fixtures/nested-neg.tot`, and Stage E's leg runs the repo copy.
Its two data lines carry an M6 comment block below them, which is why
`mkt3` is at line 2:

```
data N (0 A : Type 0) : Type 0 := | mkn : (A -> Nat) -> N A
data T3 : Type 0 := | mkt3 : N T3 -> T3
```

The pin 2 negative also needs no new file.  It ships at HEAD as
`test/fixtures/m6c-hole-n-infer.tot` and section 1.5 runs the repo copy.
The earlier plan-level fixtures `m7a-hole-infer-scrutinee.tot`,
`m7b-guard-first-holed.tot` and `m7b-guard-second-holed.tot` are
SUPERSEDED by the amendment and no stage creates them.  Do not build
those three paths.

### 1.7 Verified anchors

Every file:line below was read at `66b444f` on 2026-09-03 by this plan's
writer.  The four anchors the amendment turns on were re-read on
2026-09-04 with `awk NR==` at `d028a2a`, whose code tree is identical to
`66b444f` (section 1.2): lib/totality.ml:20, lib/check.ml:1465-1466,
surface/elab.ml:287-291 and surface/elab.ml:511-522.  Use these anchors,
not remembered ones.

| Anchor | Content |
| --- | --- |
| lib/totality.ml:20 | `type rule = Structural`, one constructor |
| lib/check.ml:1460-1464 | the doc comment: `~rule` is "REQUIRED, not optional, so the compiler enumerates every call site" |
| lib/check.ml:1465-1466 | `let define ... ~(rule : Totality.rule) (globals : Global.t)` |
| lib/check.ml:958-959 | the bare lambda infers nothing: `Error (Error.Cannot_infer ...)` |
| lib/check.ml:1208-1211 | `check` has no App arm;  `Term.App` falls through to `check_via_infer` |
| lib/check.ml:1763-1776 | `define_instance` passes `~rule:Totality.Structural` and no `~rec_`, with the M6 dead-spot comment |
| lib/check.ml:1949-1961 | `strict_pos` tests applied-ness one level deep, over a `match () with` ladder |
| lib/interp.ml:85-91 | the `Frozen` doc comment: "dead code by the Stage A soundness argument", it "degrades to a permanent neutral instead of a loop" |
| surface/elab.ml:287-291 | the INFER-position `SHole` arm: `Error (Serror.Hole { loc; expected = None })` |
| surface/elab.ml:400 | the check-position twin: `Error (Serror.Hole { loc; expected = Some (scope, expected) })` |
| surface/elab.ml:511-522 | the class-former fence: under `\| () when fence`, an `SHole` argument is filled from the instantiated domain and EVERY other argument goes to `term`, the infer entry.  This is why `stdlib/prelude.tot:173` needs the settle |
| surface/parser.ml:369 | the one place a hole node is built: `\| { Token.kind = Token.Underscore; loc } :: rest -> Ok (Syntax.SHole loc, rest)`.  Stage C collects tail positions here, inside the parse walk that already runs |
| dev/gen-m5e-transcript.sh:13 | the transcript glob: `for f in examples/*.tot test/fixtures/*.tot; do` |
| stdlib/prelude.tot:173 | `fun A d => mkEqD (List A) (listEqBy A (eqf A d))`, pin 5's seventh anchor |
| test/fixtures/nested-neg.tot | the shipped one-layer positivity control, `mkt3` at line 2 |
| surface/elab.ml:470-476 | the stale `spine` doc comment, debt (j) |
| surface/cache.ml:118 | `let format_version : int = 10` |
| surface/cache.ml:343-346 | `key` folds the prelude source, the format version and the executable digest |
| surface/bootstrap.ml:66-73 | the eight hard-wired Json constructor names, jnull to jobjCons |
| dev/gates.sh:30 | "A tier is a HANG ceiling, not a performance budget" |
| dev/gates.sh:44-48 | FAST=10, MED=30, SLOW=120, SUITE=300, BITE_S=1 |
| dev/gates.sh:2531 | the stale `count 18` comment, debt fixed at Stage E (pin 12) |
| dev/gates.sh:3016 | the live literal `[ "$m5d_lines" -eq 22 ]` |
| dev/gates.sh:3088-3094 | PASS-M6E-GUARD-HOLES: the 22-hole literal and the prelude-zero assertion `m6e_pz` |
| dev/gates.sh:3109-3112 | PASS-M6E-ANCHORS: the exact-string compare and the `-gt 98` floor |
| SPEC.md:2123 | the last `expected-type-only=` line, which PASS-M5D-MEASURE-LOG reads |
| SPEC.md:2141, SPEC.md:2145 | the two in-SPEC citation errors folded into Stage E (graft G7) |
| test/surface.ml:110 | the only driver of test/fixtures/s0-erased-guard.tot |
| test/main.ml:581 | the prose mention of the same fixture |

## 2. Build ground rules

- The build happens in the WORKING TREE only.  Do NOT run `git add`,
  `git commit`, `git checkout` or any other history or index operation.
  This binds EVERY stage agent, with no exception for "staging my own
  stage".  Staging is DEFERRED to build completion: the MAIN LOOP alone
  runs `git add -A` after the final battery and the review rounds, and
  the USER commits.  A stage exit criterion that asks for a staged tree
  is a drafting error.
- Report `git status --porcelain` in your stage report so the diff
  surface is visible while it is still unstaged.
- Run the section 1.2 battery before your first edit and before your
  report.  Append a stage report to
  `/Users/oobi/Documents/tot/dev/M7-BUILD-LOG.md` when your stage is
  green: what changed, files touched, test names added, gate markers
  added, every mutation proof, every count WITH its command, the new
  PASS count with its decomposition, and the gate output tails.
- Never `cd` in a Bash tool CALL;  your cwd RESETS between calls.  Use
  absolute paths, and put a multi-step probe in ONE runner script that
  fixes its own cwd on its first line.
- Every dune command needs `eval "$(opam env)"` first, in the same shell
  invocation (section 1.2).
- Shell: `rg` not grep, `sd` not sed, `fd` not find.  No em-dashes in any
  text you write;  ASCII punctuation only;  two spaces after a
  sentence-ending "." or ";" in prose.
- NEW gate legs and dev scripts are LOOP-FREE: no `for`, no `while`, in
  zsh legs included.  The one legacy `while` (mm_nest, M4) stays as it
  is;  do not add a second.
- OCaml house rules, unchanged from M6 and hook-enforced: no exceptions
  (`raise`, `failwith`, `assert`);  no `match` on Option or Result where
  a combinator does the job;  no loop keywords;  no list or array
  mutation;  exhaustive matches with no catch-all `_ ->` arms on
  enumerable variants;  `match () with | () when ...` ladders over `if`
  and `else if` chains;  no `arr.(i)`, no `List.nth`;  doc comments on
  every new top-level item.  These bind `lib/`, `surface/`, `bin/` and
  `test/`;  they do not bind `dev/*.sh` or `dev/*.py` except for the
  loop-free rule above.
- `dev/gates.sh` must not use `set -u`.
- Every feature ships WITH its regression test.  ORACLE RULE: every
  negative test must be shown to REJECT for the intended reason (print
  the error tag and the message), and every positive test must pin an
  exact value, an exact line, or an exact exit code.  Never assert on
  absent output where an exit status is available.
- Marshal-format checklist: any change to `Term.t`, `Value.t`,
  `Eterm.t`, `Global.entry`, `Interp.v`, `Interp.gentry` or `Prim.t`
  bumps `Cache.format_version`.  Pin 18 says M7 owns NO bump, and pin 8
  says no constructor moves, so the checklist must never fire.  A stage
  that believes it needs a bump has found a conflict;  section 5
  applies.

## 3. The stage chain and the exit arithmetic

Five stages, strictly ordered, each exiting at GATE-EXIT=0, 0 FAIL, with
a stated PASS target chaining from 371.  The verdict's STAGE ALLOCATION
gave 5, 2, 2, 4 and 5 markers and about 413 at exit.  The amendment of
2026-09-04 moves two stages, so the numbers below are taken from the
AMENDED stage section footers, read on 2026-09-04, and the chain is
composed from them.

Chain: 371 -> 390 -> 395 -> 402 -> 410 -> 420

| Stage | Gate markers | Suite cases | PASS delta | Exit PASS |
| --- | --- | --- | --- | --- |
| A | 7 | 12 | 19 | 390 |
| B | 2 | 3 | 5 | 395 |
| C | 2 | 5 | 7 | 402 |
| D | 4 | 4 | 8 | 410 |
| E | 5 | 5 | 10 | 420 |

What the amendment moved: Stage A grew by 2 markers and 4 suite cases
for the infer settle, and Stage B grew by 1 suite case for the third
guard fixture.  Stages C, D and E kept their own deltas and only their
absolute numbers move.

The "PASS delta" column is the stage's whole PASS delta, gate markers
plus decomposed suite cases, counted the way the M6 walk counted them.
It is the sum of the two columns to its left.  Each stage section closes
with three lines and nothing after them: `Gate markers added: N`,
`Suite cases added: M` and `Exit PASS count: X`, where N and M are that
stage's two count columns here and X is the previous stage's exit plus N
plus M.  Cross-check: 20 gate markers plus 29 suite cases is +49, and
371 + 49 = 420.  Target at M7 exit: about 420 PASS, 0 FAIL.

Reconciliation is done, and the sections carry the result.  The Stage C,
Stage D and Stage E sections held pre-amendment absolute numbers when
they were read at 01:03 on 2026-09-04 (Stage C exit 395, Stage D entry
395 and exit 403, Stage E entry 403 and exit 413).  Those numbers were
re-chained from this table on 2026-09-04 and the sections now read Stage
C entry 395 and exit 402, Stage D entry 402 and exit 410, and Stage E
entry 410 and exit 420.  Every stage footer, every entry-state paragraph
and every rollback sentence in C, D and E states the re-chained number,
so no reconciliation is left for the closer.  A stage agent that finds
its section's entry number disagreeing with this table trusts the table
and records the difference in `dev/M7-BUILD-LOG.md`.  Counts may drift by
one or two per stage;  the monotone walk, the marker names and
GATE-EXIT=0 at every boundary are the binding part.  The one count that
gets NO drift tolerance is pin 10's exact ANCHORS literal, which the
classifier arithmetic determines fully.

Reserved markers, 20, one namespace letter per stage (pin 13).  The
verdict reserved 18;  the amendment adds two to Stage A and renames one
of Stage B's.  A stage ships exactly its reserved names;  a stage that
needs one more adds it under its own letter and records the addition in
`dev/M7-BUILD-LOG.md`.

- Stage A (7): PASS-M7A-KERNEL-UNCHANGED, PASS-M7A-ARGHOLE-RESOLVES,
  PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE, PASS-M7A-CONSERVATIVITY,
  PASS-M7A-SPINE-COMMENT, PASS-M7A-INFER-SETTLE,
  PASS-M7A-INFER-SETTLE-BUDGET.
- Stage B (2): PASS-M7B-GUARD-ARG-HOLES, PASS-M7B-LIFTIO-SLOT-CLOSES.
  PASS-M7B-ARG-SLOT-EXPLICIT is RETIRED before it ships, because the
  slot it named now closes;  no gate leg, no fixture and no suite case
  carries that name.
- Stage C (2): PASS-M7C-MULTI-HOLE-TAIL, PASS-M7C-SINGLE-HOLE-UNCHANGED.
- Stage D (4): PASS-M7D-HELPERS-SHARED, PASS-M7D-PRELUDE-HOLES,
  PASS-M7D-ANCHORS, PASS-M7D-CACHE-KEY.
- Stage E (5): PASS-M7E-SPEC-CITATIONS, PASS-M7E-WF-PROVENANCE-ORACLE,
  PASS-M7E-POSITIVITY-LAUNDER-ORACLE, PASS-M7E-INSTANCE-RULE,
  PASS-M7E-DEBT-H.

Two existing legs move their literals and neither loses a leg.
PASS-M6E-GUARD-HOLES walks its holed-anchor literal 22 at HEAD, 26 after
Stage B, 24 after the Stage D helper move and 69 after the Stage D
re-spell (pin 11 as amended, section 1.4), and its prelude-zero
assertion at dev/gates.sh:3089 is
RE-DESIGNED into a prelude-holed floor at Stage D, never deleted.
PASS-M6E-ANCHORS edits its exact-string literal at Stage D only.
Re-opening a tripwire's design is allowed;  deleting a leg is forbidden.

Transcript discipline across the chain: `dev/gen-m5e-transcript.sh`
globs examples/*.tot and test/fixtures/*.tot, so EVERY stage that adds
or edits a file in either directory regenerates
`dev/m5e-default-transcript.txt` in the same commit, diffs old against
new, reviews the diff, and records the file count in its SPEC entry.
Pin 4 holds the reseal back: the transcript stays byte-identical through
Stage A, and the reseal lands at Stage D with the helper move.  Of the
fixtures in section 1.6, exactly one lands inside the glob,
`test/fixtures/m7e-launder.tot` at Stage E, so Stage E owns that reseal
and no other stage pays one for a fixture (section 1.6, placement
rule).

## 4. Standing rules: cross-cutting pins

### 4.1 Pin 18: cache discipline

`Cache.format_version` stays 10 (surface/cache.ml:118, read at HEAD) for
the WHOLE milestone.  Holes never enter kernel terms (pin 1), no
constructor moves (pin 8), and the Stage D prelude edit needs no bump:
`key` at surface/cache.ml:343-346 already folds the prelude source into
the digest, while `load` verifies magic, format version, executable
digest and body digest, none of which is a function of the prelude
source.  Any change that would touch a cached shape is REDESIGNED, not
version-bumped.

### 4.2 Pin 13: marker namespace

All M7 markers live under `PASS-M7[A-E]-*`.  The namespace is free at
HEAD, probed 2026-09-03 and re-probed 2026-09-04 with the same result:

    rg -c 'PASS-M7' /Users/oobi/Documents/tot/dev/gates.sh
    (no output)
    rg exit=1

The oracle is asserted on EXIT STATUS 1 (zero matches), never on a
printed 0:  `rg -c` prints nothing at all when there is no match.  Do not
reuse or edit an existing marker name.  Two existing legs have their
LITERALS edited (section 3) and keep their names.

### 4.3 Graft G8: count honesty

Every rg-derived or script-derived count in M7 documents and gate
comments ships WITH the exact command that produced it, the command must
actually PRINT the number, and re-running it must reproduce the number.
`rg -c` on a zero match prints nothing and exits 1, which a careless
reader takes for a zero;  where the honest answer is zero, assert the
exit status and say so.  `dev/M7-BUILD-LOG.md` records each count as
command plus output, verbatim.  This preamble practices the rule:  every
count in section 1.5 carries its command.

### 4.4 Walk discipline

Every stage exits GATE-EXIT=0, 0 FAIL, at the stated PASS target of the
section 3 chain.  Mutation proofs flip then restore md5-identical
(section 6).  Every design decision becomes a dated SPEC section 2 entry.
The user commits;  nothing lands committed, or even staged, by a stage
agent (section 2).

## 5. Conflict-resolution protocol

A stage section may find that a pin disagrees with the repo.  When that
happens, follow this protocol exactly.

1. Re-run the claim against the built binary or read the cited lines.
   Do not resolve a conflict from memory or from the verdict text.
2. Record a DATED conflict note in the stage section itself, in the form
   `Conflict note C<n> (YYYY-MM-DD): <pin> says X;  the repo at
   <file:line> shows Y;  resolution: Z`.
3. Report the note in the stage's return value and in
   `dev/M7-BUILD-LOG.md`.
4. The pin list WINS, unless the repo PROVES the pin impossible.
   "Impossible" means an executed probe, a compiler error, or a cited
   line, and never an opinion about design.  Where the repo proves the
   pin impossible, the pin's INTENT survives and only its mechanism
   changes.  Record both halves.
5. A conflict never silently shrinks a gate.  If a mutation proof cannot
   be built as written, replace the mutation, prove the flip, and say so.
   Do not drop the leg.

One conflict is already resolved here.  A stage section inherits this
resolution and does not re-litigate it.

**Conflict note C-P1 (2026-09-03): the existing marker prefix count is
16, not 15.**  Pin 13 states "The existing prefix count is 15: M4A
through M4D, M5A through M5E, M6A through M6E, and M6H".  At `66b444f`,
`rg -o 'PASS-M[0-9][A-Z]+' /Users/oobi/Documents/tot/dev/gates.sh | sort -u | wc -l`
printed `16`, because the 23 PASS-M4FIX-* markers contribute a sixteenth
prefix, PASS-M4F.  Resolution: the pin's claim that matters, that no
PASS-M7 marker exists, is verified separately and holds;  this plan
records 16 as the live prefix count and any leg that guards the
namespace asserts on exit status, never on a printed count.

## 6. The mutation-proof protocol

Every new gate leg ships with a MUTATION PROOF.  A leg with no proof is
not a gate, and the stage is not green.  The proof has three parts, all
required, all recorded in `dev/M7-BUILD-LOG.md`:

1. The exact mutation, as a file, a line and the replacement text.
2. The observed flip: the leg's marker before the mutation, and the FAIL
   marker with its exit code after it, arriving by the PREDICTED route.
3. The restore: the source md5 before and after, proving the tree
   returned to its pre-mutation bytes.

A mutation that does not flip the leg REFUTES the leg.  When that
happens, replace the mutation or replace the leg, and record which.  Do
not report a leg as proved because a DIFFERENT mutation flipped it.  A
mutation that does not COMPILE proves nothing;  replace it with one that
builds.

Ask of every mutation you pin: can this mutation reach this leg's code
path at all?  A mutation hook that cannot fire is a vacuous oracle.  Two
M7 shapes carry that risk and each stage that owns one must answer it in
writing.  First, the two grafted oracles of pins 14 and 15 refuse at HEAD
and at exit, so their mutation must attack the LEG (delete the fixture,
weaken the exit-code assertion), not the binary.  Second, a mutation
aimed at the new settle path must use a fixture whose holed slot is
argument-determined;  an expected-type-only fixture resolves through the
M6 path (surface/elab.ml:400) and proves nothing about M7 code.

## 7. Watchdog tier discipline

Every gate leg names a tier: FAST=10, MED=30, SLOW=120, SUITE=300
(dev/gates.sh:44-47, read at HEAD).  No numeric watchdog literal may
appear in a leg;  the M5 oracle `rg -c '"\$watchdog" [0-9]+' dev/gates.sh`,
asserted on exit status, must stay green through every M7 stage.  BITE_S
(dev/gates.sh:48) is the calibration constant for PASS-M5D-TIER-BITES and
nothing else may use it.  "A tier is a HANG ceiling, not a performance
budget" (dev/gates.sh:30):  a leg that creeps in cost stays green at its
tier and shows up in the measurement log.  M7 ships NO perf leg at all
(scope-out 6).

PASS-M5D-MEASURE-LOG keeps its live literal of 22 lines
(dev/gates.sh:3016) because M7 adds no `gate_timed` leg (pin 12).  Stage E
fixes only the stale `count 18` comment at dev/gates.sh:2531.  Any newer
anchors line spliced into SPEC.md goes BELOW SPEC.md:2123, because the leg
reads the LAST `expected-type-only=` spelling in the file.

New legs are written in the file's capture-then-assert idiom, exactly as
at HEAD: capture output and exit code under a named tier, assert on exact
values, echo the PASS marker on success, and have the FAIL branch replay
the captured output and exit 1.  The M7 house template, binding for every
new leg (loop-free, tier named, marker echoed by the leg's final compound
statement):

    # Gate <letter> (<n>), PASS-M7<letter>-<NAME>. <One-sentence oracle
    # statement; the measurement recipe when a number is asserted;
    # the mutation that proves the leg, by name>.
    out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
      "$ROOT"/test/fixtures/m7x-example.tot 2>&1)
    code=$?
    want='m7x-example.tot:1:30: hole: expected Type 0'
    { [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$want"; } \
      && echo PASS-M7X-EXAMPLE \
      || { printf '%s\n' "$out"; echo "FAIL-M7X-EXAMPLE (exit=$code)"; exit 1; }

Never assert on "no error", and never assert on absent output where an
exit status is available:  an oracle that matches nothing passes for the
wrong reason.

## 8. Known debts entering M8

This is the M8 hand-off.  Copied from the ratified verdict and verified
against the repo at `66b444f` (anchors in section 1.7).  Stage E writes
this list into SPEC section 6.  None of it is M7 scope.

1. **Well-founded recursion, with a ratified direction.**  The
   erased-domain relation rewrite does not exist for a relation defined
   by pattern matching:  the judge's probe got `erased variable n used at
   runtime` for the erased spelling and a type mismatch for the wide one.
   Ruling Q5 settles the direction: an Acc-style family takes a WIDE
   relation formal and PAYS AT ERASURE, and the quantity discipline does
   NOT widen for relation positions.  M7 builds nothing for this.  M8
   inherits the recognizer shape as a dated SPEC entry (graft G1), a
   renamed-Acc positive control (graft G2, pin 14's neighbour) and a
   non-vacuous provenance negative (graft G3, pin 14).
2. **The activation channel for any second admission rule.**
   `type rule = Structural` (lib/totality.ml:20) and the required
   `~rule` (lib/check.ml:1465-1466) are the re-entry channel.  No
   proposal on the panel said what would SELECT a second constructor.
   M8 must state the selector in the same breath as the rule.
3. **Nested inductives and the strict positivity fence.**  The
   applied-ness test at lib/check.ml:1949-1961 is one level deep and is
   not a polarity analysis, and HEAD's message does not distinguish a
   direct negative occurrence from a laundered one.  M7 lands the
   negative fixtures (graft G6, pin 15);  M8 owes the rule and a message
   that names the layer.
4. **The Json cons-cell family and the jarr migration.**  Eight
   constructor names are hard-wired in lib/interp.ml and again at
   surface/bootstrap.ml:66-73.  `jarr : List Json -> Json` stays on the
   list, and its blast radius is now measured: at least two .ml modules
   plus the prelude.
5. **The Frozen emptiness claim.**  lib/interp.ml:85-91 states the
   intent;  nothing proves it.  Stage E records it in SPEC.md as an open
   obligation with both horns named (grafts G4 and G5, pin 16).
6. **Holes whose informative argument is a bare lambda.**  The two
   guard slots at examples/guard.tot:134 and
   examples/guard-rewrap.tot:265 are NO LONGER a debt: the amendment of
   2026-09-04 authorised the infer settle, the settle elaborates their
   `liftIO _ (...)` argument, and Stage B closes both.  What survives is
   the other half of the old reason.  A bare lambda still infers nothing
   (lib/check.ml:958-959), so a spine whose only later argument is a
   bare lambda determines no leading slot, and no M7 rule reaches it.
   M7 hands M8 the tripwire for the neighbouring shape,
   `test/fixtures/m7/m7b-arg-slot-undetermined.tot`, whose every later
   argument is itself a hole and which exits 1 with
   `hole: expected Type 0` at M7 exit.  A bare-lambda fixture is not in
   M7 scope, so M8 writes that one.
7. **The .mli surface.**  Fifteen modules without interfaces:
   `ls lib/*.ml | wc -l` printed 17 and only budget.mli and level.mli
   exist.  No measured demand, still real.  It stayed out of M7 because
   it collides with every other stage's diff.
8. **Multi-hole expected types.**  Pin 7 reports positions only for the
   tail.  Full per-hole expected types need a second traversal or a
   `Serror.t` signature change.  The amendment of 2026-09-04 BARS the
   traversal in Stage C, the only M7 stage that touches hole reporting,
   so the choice M8 inherits is narrower than it looks: change
   `Serror.t`, or keep positions only.  M7 takes neither and leaves the
   decision to the user.
9. **test/fixtures/s0-erased-guard.tot cannot run under the default
   driver**, because it redeclares Nat.  It works only through
   test/surface.ml:110.  A future gate leg that wants it as a positive
   control must reach it the way the suite does, or the fixture must be
   re-spelled.
10. **The prelude arm multi-hole tail.**  bin/tot.ml:171-173 keeps the M6
    one-line report on a cache hit.  On a hit no parse walk runs:
    surface/bootstrap.ml:384 parses the prelude only on a cache miss, so
    no record exists to report a position from.  A re-parse on a hit is
    exactly the second pass the amendment of 2026-09-04 bars, and a tail
    that reports cold and vanishes warm would also break pin 18's
    miss-then-hit leg.  M8 chooses between recording positions in the
    prelude cache, or a re-parse limited to the error path only.

The three grafted oracles are the tripwire half of this hand-off: G2 the
renamed-Acc positive control, G3 the provenance negative, G6 the
two-layer launder negative.  All three refuse or accept for their stated
reason at M7 exit, so M8 starts with working tests instead of a memory.

## 9. Deliberate non-changes

Stated once so no stage carves its own exceptions.  Each item is OUT of
M7 scope by ratified verdict, with the verdict's own reason, and a stage
that touches one has found a conflict (section 5).

1. The whole well-founded recursion package.  Reason: no stated
   activation channel, a vacuous oracle, and the headline probe shows the
   erased-domain workaround does not exist.
2. Nested inductives and the jarr migration.  Reason: the polarity rule
   as proposed launders, and the migration needs .ml edits in two modules
   the proposal excluded.
3. The .mli sweep.  Reason: hygiene, no measured demand, and it collides
   with every other stage's diff.
4. Any format_version bump.  Reason: the cache key already folds the
   prelude source, so the Stage D edit invalidates the cache without one.
5. Cumulativity and Eq1.  Reason: untouched by all three proposals'
   measured demand.
6. Perf work against the tier ceilings.  Reason: the tiers are HANG
   ceilings, not budgets.
7. Error recovery beyond reporting.  Reason: no partial terms, no
   continued elaboration after an error.
8. A second pass over parsed items or terms in Stage C, of any kind,
   including a syntactic fold that runs only on the failed path.
   Reason: the amendment of 2026-09-04 takes the strict reading of "no
   second traversal".  Stage C collects hole positions inside the parse
   walk that already runs (surface/parser.ml:369), and `Serror.t` stays
   unchanged.

Item 8 REPLACES the verdict's scope-out item 8, "Extending the settle
pass into the INFER path".  That item carried its own escape clause and
the user used it on 2026-09-04, so the infer settle is IN, it is Stage A
work, and it is no longer a non-change (section 1.1a).  A stage that
reads an older copy of this list has an out-of-date file.

## 10. Completion checklist

The MAIN LOOP walks this list at build completion, in order.  Nothing
here is a stage agent's job except handing over a green tree.

- [ ] Stages A to E each exited GATE-EXIT=0, 0 FAIL, and the recorded
      walk chains 371 -> 390 -> 395 -> 402 -> 410 -> 420 within the
      allowed one-or-two drift per stage, monotone.
- [ ] Final full battery on the finished tree (section 1.2 commands):
      GATE-EXIT=0;  `rg -c '^PASS' "$TMPDIR/tot-gate.out"` at the
      recorded final total;  `rg -c '^FAIL' "$TMPDIR/tot-gate.out"`
      exits 1 with no output.
- [ ] All 20 reserved markers present:
      `rg -o 'PASS-M7[A-E]-[A-Z0-9-]+' /Users/oobi/Documents/tot/dev/gates.sh | sort -u | wc -l`
      = 20, and the per-stage names match section 3 exactly.  The
      retired name PASS-M7B-ARG-SLOT-EXPLICIT appears nowhere:
      `rg -c 'PASS-M7B-ARG-SLOT-EXPLICIT' /Users/oobi/Documents/tot/dev/gates.sh`
      exits 1 with no output.
- [ ] Pin 10's literal is exact:
      `/usr/bin/python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | tail -1`
      prints `ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30`,
      and PASS-M6E-ANCHORS carries the same string.
- [ ] Pin 11's landed literal holds:
      `/usr/bin/python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | rg -c 'anchor=\[_\]'`
      prints 69, and the prelude-holed floor inside PASS-M6E-GUARD-HOLES
      replaced the prelude-zero assertion rather than deleting it.  69
      is the amended landed number (section 1.4);  a 67 means Stage B
      re-spelled two guard slots and not four, which is a section 5
      conflict and not a drift.
- [ ] The inherited M5 and M6 oracles are still green, the watchdog
      literal oracle included, and PASS-M5D-MEASURE-LOG needed no literal
      change (pin 12).
- [ ] Every pin has its dated 2026-09-0X SPEC section 2 entry;  SPEC
      section 6 is rewritten with post-M7 numbers;  the debts list matches
      section 8 of this preamble.
- [ ] `dev/M7-BUILD-LOG.md` holds every stage report, every mutation proof
      with flip and md5-identical restore, every count with its command,
      and every conflict note.
- [ ] The tree is COMPLETE and UNSTAGED;  `git status --porcelain` output
      recorded.  Only now the MAIN LOOP runs `git add -A` in
      `/Users/oobi/Documents/tot`.
- [ ] Review rounds run over the STAGED diff (ctxcat-review with a
      precomputed index, plus one logic-lens pass), repeated to
      convergence;  fixes land, restage, rerun the battery if any fix
      touched lib/, surface/, bin/, test/ or a gate oracle.
- [ ] The USER commits.  No agent commits, ever.

Preamble ends.

## STAGE A: elaborator rule and conservativity (pins 1, 2, 3, 4)

### Goal

Give the elaborator the argument-driven capture rule in check position AND
in infer position, and prove that it buys the M7 corpus edits without moving
one byte of kernel admission or one byte of green output.

The infer half is new work, authorised by the Ratification amendment of
2026-09-04. It is elaborator surface only: it chooses which pre-term goes in
an argument slot and it changes no file under `lib/` except the named arm of
A5, which keeps the body it was lifted out of. Read "Design, A3b" for the
rule and "Design, A9" for the ruling record it answers.

Stage A ships the RULE and its gates. Stage A edits no corpus file. The
prelude and the examples keep their explicit spellings until Stage B and
Stage D re-spell them. The Stage A fixtures live under `dev/m7a/`, which
sits outside the transcript generator glob `examples/*.tot
test/fixtures/*.tot` (`dev/gen-m5e-transcript.sh`), so the new fixtures add
no transcript block.

### Pins covered

Pin 1, verbatim from the verdict:

> M7 changes no admission rule in lib/. `type rule = Structural` gains no
> constructor and `Check.define`'s `~rule` stays REQUIRED, so the compiler
> keeps enumerating every call site. Testable: PASS-M7A-KERNEL-UNCHANGED
> asserts one occurrence of `type rule = Structural` in lib/totality.ml and
> that lib/check.ml's `define` signature still carries a required `~rule`.

Pin 2, verbatim:

> Argument-driven resolution is CHECK position only. A hole in infer
> position keeps its exact current message. Testable:
> PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE.

Pin 2 is OVERRIDDEN in its first sentence by the Ratification amendment of
2026-09-04, quoted verbatim:

> Q1 amended: the infer-path settle extension IS authorised as scoped
> elaborator surface, built in Stage A. Reason: the Stage A writer measured
> only six of nine A anchors reachable at HEAD; stdlib/prelude.tot:173 sits
> behind the class-former fence (surface/elab.ml:511-522) and closes only
> with the settle. Consequences: pin 5 keeps its seven anchors; pin 2
> (conservativity) stays binding, so the settle may change only programs
> that fail at HEAD with the hole error, and the Stage A probes must show
> that; Stage B re-derives whether the two guard slots pinned as
> explicit-forever negatives now close under the settle, and pins a slot as
> a negative only with a true reason.

Pin 2 as Stage A builds it, therefore, in two clauses:

1. A program that is GREEN at HEAD keeps its exit code and its stdout byte
   for byte. Testable: PASS-M7A-CONSERVATIVITY and
   PASS-M7A-INFER-SETTLE-BUDGET.
2. A program that FAILS at HEAD keeps its exact error line, unless that
   line is the hole error. Only a program whose HEAD error is
   `hole: no expected type at this position` or `hole: expected <type>` at
   a leading erased slot may change. Testable:
   PASS-M7A-INFER-SETTLE-BUDGET, which digests every corpus file except the
   two this stage licenses to move, `test/fixtures/m6c-hole-a.tot` (A7 item
   1) and `test/fixtures/m6c-hole-run.tot` (A7 item 2), and
   PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE, which pins three infer-position
   holes that must keep their exact HEAD line.

Pin 3, verbatim:

> The rule. In an application whose head is a global with leading erased
> Type formals, a hole in a leading erased slot resolves if and only if
> some LATER explicit argument of the same spine infers a type whose
> head-normal form determines that slot by first-order matching against
> the head's declared formal type. No metavariable escapes the spine. No
> backtracking. No unification across definitions. Testable:
> PASS-M7A-ARGHOLE-RESOLVES over a fixture set that covers determined,
> undetermined and ambiguous slots.

The infer half of the rule has its own marker, PASS-M7A-INFER-SETTLE. The
rule text is the same text. Only the capture SOURCE differs, because infer
position has no expected type to match against. Read "Design, A3b".

Pin 4, verbatim:

> Conservativity at the Stage A boundary: every fixture green at HEAD stays
> green with byte-identical stdout. Testable: PASS-M7A-CONSERVATIVITY plus
> PASS-M5E-TRANSCRIPT unchanged at Stage A. The transcript reseals at Stage
> D and not before.

Debt item (j) from the verdict's debt list: the `spine` doc comment at
`surface/elab.ml:466-476` still describes the M6 rule only. Stage A pays it
under PASS-M7A-SPINE-COMMENT. The verdict gives (j) no pin number, so the
marker carries the debt id, not a pin id.

Pin 5 (seven of nine A anchors) and pin 6 (the two slots Stage B re-derives)
are tested at Stages B and D. Stage A owns the rule those pins depend on, so
the Stage A gate carries one fixture per anchor SHAPE. All seven pin 5
anchors are reachable once the infer settle lands. Read "Design, A9" for the
per-anchor measurement and for the ruling record.

### Entry state

HEAD is `66b444f`, tree clean, battery PASS count 371.

Measured at HEAD, all read-only, using the binary already built at
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe`:

- `/Users/oobi/Documents/tot/_build/default/test/main.exe` prints 105 PASS.
- `/Users/oobi/Documents/tot/_build/default/test/surface.exe` prints 119 PASS.
- `rg -c '^echo PASS-' /Users/oobi/Documents/tot/dev/gates.sh` and the
  compound-line variants give 146 distinct `echo PASS-` marker sites.

105 + 119 + 146 = 370 against the battery's 371. One PASS line in the
battery is not accounted for by those three counts. The residue does not
change Stage A arithmetic, which is 371 plus 7 markers plus 12 surface tests
= 390. The builder re-derives the residue at entry with one full
`dev/gates.sh` run and records it in `dev/M7-BUILD-LOG.md`.

Namespace check at HEAD: `rg -c 'PASS-M7' /Users/oobi/Documents/tot/dev/gates.sh`
printed nothing and exited 1, so the whole `PASS-M7A-*` namespace is free
(verdict pin 13).

### Files touched

- `surface/elab.ml`: typed locals, the type synthesizer, the argument-driven
  capture pass, the infer-path settle, the constant-motive branch descent,
  the `spine` doc comment.
- `lib/check.ml`: one named check-position `Term.App` arm, no behaviour
  change.
- `test/surface.ml`: 12 new cases in the `cases` registry.
- `dev/gates.sh`: one new gate block, 7 markers, plus the two re-opened M6C
  legs and the `PASS-M5D-TIERS` literal.
- `test/fixtures/m6c-hole-run.tot`: re-spelled so it stays unresolvable.
- `dev/m7a/*.tot`: 29 new fixtures, 19 listed in A10 and 11 in A11, minus
  the one A11 renames (bytes given below). Two A10 fixtures change under the
  amendment: `arg-exhausted.tot` is re-spelled, and `arg-infer.tot` is
  renamed to `arg-infer-holed.tot` and gains an explicit twin. The A11 bytes
  win where the two lists disagree.
- `dev/m5e-default-transcript.txt`: two blocks reseal (see A8).
- `dev/M7-BUILD-LOG.md`: new file, Stage A entry.

No file under `lib/` other than `lib/check.ml` is touched. The frozen set
`lib/totality.ml lib/term.ml lib/eval.ml lib/value.ml lib/erase.ml
lib/interp.ml lib/error.ml` keeps its concatenated md5
`f446f043e1ad6c7b85ddedb7736bd8a1`, measured at HEAD.

### Design

The elaborator today resolves a leading erased slot only from the EXPECTED
type. `spine` (surface/elab.ml:477-536) peels `m` declared domains, counts
`k` leading `(0 X : Type L)` formals (`leading_type_binders`, elab.ml:95-103),
raises the family fence (`fenced`, elab.ml:80-83), and builds `caps` by a
rigid first-order match of the residual declared type against the expected
pre-term (elab.ml:489-491, `rigid` at elab.ml:153-188). The settle fold
(elab.ml:494-531) then walks the arguments left to right. A hole in a
leading slot takes `List.assoc_opt j caps` or fails with
`Serror.Hole { loc; expected = Some (scope, dom) }` (elab.ml:502-505).

Stage A adds a second source of captures: the LATER arguments. It then adds
one entry point, so that the same capture pass also runs where there is no
expected type at all. Seven parts.

#### A1. Typed locals in check position

`term`, `term_at` and `spine` carry `scope : string list` only, so the
elaborator knows the NAME of every local and the TYPE of none. Pin 3 needs
the type of a later argument, and five of the seven anchor sites name a
local variable there.

Add one optional labelled argument, threaded beside `scope`:

```ocaml
(* [locals] is aligned with [scope], newest binder first.  [None] marks a
   binder whose type the elaborator did not learn.  Entries past the end
   of the list read as [None], so the two lists never have to agree in
   length. *)
and local_ty (locals : Term.t option list) (ix : int) : Term.t option =
  List.nth_opt locals ix |> Option.join
```

`term`, `term_at` and `spine` each gain `?(locals : Term.t option list = [])`.
The default keeps every external call site unchanged
(`surface/run.ml:208-242` and `surface/run.ml:465-473` call `Elab.term_at`
and `Elab.term` with no extra argument). Each recursive call inside
`elab.ml` threads `~locals`, and the binder arms extend it:

- `term_at`'s SLam arm (elab.ml:401-407) already holds the domain in
  `Term.Pi (_q, _y, _dom, cod)`. It descends with
  `~locals:(Some _dom :: locals)`.
- `term_at`'s SLet arm (elab.ml:411-) holds `ty_t`. It descends with
  `~locals:(Some ty_t :: locals)`.
- `spine`'s argument descent (elab.ml:523-526) descends into `arg` with the
  same `locals`, because an argument sits under no new binder.
- the branch arms extend `locals` with the constructor field types from A2.
- every arm that adds a name to `scope` but learns no type pushes `None`,
  so the two lists stay aligned by construction.

`locals` is read by the new pass only. No existing arm changes its output.

#### A2. A total type synthesizer for elaborated arguments

Pin 3 says the later argument "infers a type". The elaborator must not call
the kernel's `Check.infer` here: `Check.infer` needs a kernel `ctx`, and
building one inside the elaborator would duplicate kernel state and would
make elaboration depend on evaluation order. Stage A adds a small total
synthesizer over PRE-TERMS instead. It answers for exactly two shapes and
returns `None` for everything else:

```ocaml
(* The type of an already-elaborated argument, when the elaborator can
   read it off without typechecking.  Two shapes only:
   (1) a local Var whose type [locals] carries;
   (2) a spine headed by a GLOBAL, whose declared type loses one domain
       per applied argument, each domain instantiated with the actual
       argument terms.
   [None] everywhere else, including under a hole, a lambda and a match.
   The kernel re-checks the finished definition (surface/run.ml:241), so a
   wrong answer here is a kernel Mismatch, never a silent accept. *)
and synth (globals : Global.t) (locals : Term.t option list) (t : Term.t) :
    Term.t option =
  spine_head t []
  |> Option.map (fun (head, applied) ->
         match head with
         | Term.Var ix ->
             (match applied with
              | [] -> local_ty locals ix
              | _ :: _ -> None)
         | Term.Global g ->
             Global.find g globals
             |> Option.map Global.entry_ty
             |> Option.map (fun gty -> inst_applied gty applied)
             |> Option.join
         | Term.Univ _ | Term.Pi _ | Term.Lam _ | Term.App _ | Term.Let _
         | Term.Ann _ | Term.Lit _ | Term.Auto | Term.Match _ -> None)
  |> Option.join
```

`spine_head` peels `Term.App` nodes into a head plus the argument list in
declared order. `inst_applied` folds over the applied arguments: at each
step it reads one `Term.Pi (_q, _x, _dom, cod)` and substitutes the actual
argument term into `cod`, and it stops with `None` if the type runs out of
Pis or if any argument contains a hole marker. Both are total: no `raise`,
no `failwith`, no partial index. `Term.subst` (or the existing instantiation
helper used by `inst_domain`, elab.ml:197-) does the substitution, so
Stage A adds no new de Bruijn arithmetic.

Head-normal form (pin 3): when `synth` returns a CLOSED type and the rigid
match against the declared domain fails, the pass retries once on
`Eval.quote globals 0 (Eval.eval globals [] ty)`. The retry is skipped for
an open type, because there is no environment to evaluate it in. This is
the only place Stage A calls the evaluator, and it runs only on a path that
is an error at HEAD.

#### A3. The argument-driven capture pass in `spine`

Inside `spine`, after `caps` is built (elab.ml:489-491) and before the settle
fold (elab.ml:494), add:

```ocaml
(* pin 3: a leading slot the expected type left open may still be
   determined by a LATER explicit argument of the SAME spine.  Walk the
   non-leading positions in declared order, take the FIRST argument whose
   synthesized type rigid-matches its declared domain, and keep its
   captures.  First fit wins:  no backtracking, no metavariable escapes
   this spine, no unification across definitions. *)
let caps =
  match () with
  | () when fence -> caps
  | () when not (holed_leading_slot_unsettled ~k caps args) -> caps
  | () -> arg_caps globals scope locals ~m ~k doms args caps
```

`holed_leading_slot_unsettled ~k caps args` is true when some argument at
position `j < k` is `Syntax.SHole` and `List.assoc_opt j caps` is `None`.
This guard is the conservativity lemma of A3 in one line: the A3 pass runs
only on inputs that are an ERROR at HEAD (elab.ml:502-505 raises
`Serror.Hole` for exactly that state), so no HEAD-green file can reach the
A3 pass. The lemma is scoped to A3. A4 changes a second code path and it
carries its own hole precondition, stated in A4.

`arg_caps` folds over the positions `i` with `k <= i < m`, in declared
order:

```ocaml
and arg_caps globals scope locals ~m ~k doms args caps : (int * Term.t) list =
  List.fold_left
    (fun acc (i, (dom, arg)) ->
      match () with
      | () when i < k -> acc
      | () when settles_all ~k acc args -> acc
      | () ->
          term globals scope ~locals arg
          |> Result.to_option
          |> Option.map (fun arg_t -> synth globals locals arg_t)
          |> Option.join
          |> Option.map (fun ity ->
                 rigid_or_whnf globals ~m ~k ~d:0
                   (Term.shift ~cutoff:0 ~by:(m - i) dom)
                   ity acc)
          |> Option.join
          |> Option.value ~default:acc)
    caps
    (List.mapi (fun i da -> (i, da)) (zip doms args))
```

Five properties, each forced by a pin:

1. The argument is elaborated with `term` (infer position) purely to get a
   pre-term to synthesize from. `Result.to_option` drops the failure, so a
   bare lambda (the kernel refuses it at `lib/check.ml:958-959`) and an
   argument that mentions an unknown local (`lib/check.ml:940`) both fall
   through to the next argument instead of failing the spine.
2. `rigid_or_whnf` calls the existing `rigid ~m ~k ~d:0 dom ity acc`
   (elab.ml:153-188), then retries once on the head-normal form of a closed
   `ity` (A2). `rigid` already refuses a conflicting capture for the same
   formal through its `same_term` test (elab.ml:128-129), so the pass cannot
   widen a slot it already settled.
3. `settles_all` stops the walk as soon as every holed leading slot has a
   capture. First fit wins, no backtracking.
4. The result is a `caps` list of the same shape the expected-type match
   builds, so the settle fold (elab.ml:494-531) is unchanged. The hole at
   `j < k` takes `List.assoc_opt j caps` exactly as it does today. No new
   term shape leaves `spine`, and no metavariable exists at any point.
5. The declared domain is SHIFTED before the match. `doms` comes from
   `peel_domains` (elab.ml:107-116), so `dom` at telescope position `i` is
   scoped under `i` binders and a Var pointing at formal `p` reads
   `p = i - 1 - index`, the arithmetic `inst_domain` uses at elab.ml:201.
   `rigid` reads its argument in the RESIDUAL scope, under `m` binders,
   where `p = m - 1 - index` (elab.ml:157). The two disagree by `m - i`.
   `Term.shift ~cutoff:0 ~by:(m - i) dom` closes the gap, and it is the
   shift `inst_domain` already uses at elab.ml:202. Without it a capture
   lands on the wrong formal whenever `i < m`, which is every interesting
   case. Probe 2 and probe 6 both fail if the shift is dropped, because
   both compare the filled output against the explicit twin.

Ambiguity is decided by declared order, not by search: `widen _ (nil Nat)
(nil String)` takes `A := Nat` from argument 1 and then the kernel rejects
argument 2 with `type mismatch: expected (List Nat), found (List String)`.
That is pin 1 doing its job. The elaborator gained no typing power.

#### A3b. The infer-path settle (Ratification amendment, 2026-09-04)

The infer-path function is `term` (surface/elab.ml:247-386). Its application
arm is `Syntax.SApp` at `surface/elab.ml:267-270`. That arm elaborates the
function and the argument with `term`, so neither carries an expected type.
A hole in an argument therefore reaches the `Syntax.SHole` arm at
`surface/elab.ml:287-291`, which returns
`Error (Serror.Hole { loc; expected = None })` (elab.ml:291) and prints
`hole: no expected type at this position` (surface/serror.ml:95). Line
`surface/elab.ml:269` is the HEAD line where an argument with no expected
type is elaborated today, and it is the line where an argument hole gets
settled from the inferred function type after this stage.

The change gives `term`'s SApp arm the shape `term_at`'s SApp arm already
has at `surface/elab.ml:452-460`:

```ocaml
  | Syntax.SApp (_loc, f, a) -> (
      (* M7 Stage A (Q1 amendment).  Infer position has no expected type,
         so the ONLY capture source is the later arguments of this same
         spine.  [uncurry] is the existing helper;  no new traversal. *)
      match uncurry s [] with
      | Syntax.SVar (_hloc, g), args ->
          spine_infer globals scope ~locals g args
          |> unwrap_or (fun () -> app_infer globals scope ~locals f a)
      | ( ( Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SApp _
          | Syntax.SLet _ | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _
          | Syntax.SInt _ | Syntax.SLetStar _ | Syntax.SAuto _
          | Syntax.SInst _ | Syntax.SHole _ ),
          _args ) ->
          app_infer globals scope ~locals f a)
```

`app_infer` is HEAD's own two lines (elab.ml:268-270) lifted into a named
function, so the fallback path builds the identical node with the identical
`Quantity.Many` stamp. `uncurry` is the existing helper at
`surface/elab.ml:239-245`.

`spine_infer` is `spine` with the expected type removed:

```ocaml
(* M7 Stage A (Q1 amendment): the INFER-position twin of [spine].  Same
   activation test, same family fence, same settle fold.  Two
   differences, both forced by pin 2: [caps] starts EMPTY, because there
   is no expected type to match against;  and an unsettled leading hole
   returns HEAD's own error value, [Serror.Hole { loc; expected = None }],
   at HEAD's own [loc]. *)
and spine_infer (globals : Global.t) (scope : string list)
    ~(locals : Term.t option list) (g : string) (args : Syntax.t list) :
    (Term.t, Serror.t) result option =
  ...
  let caps =
    match () with
    | () when fence -> []
    | () when not (holed_leading_slot ~k args) -> []
    | () -> arg_caps globals scope locals ~m ~k doms args []
  in
  ...
      | Syntax.SHole loc ->
          List.assoc_opt j caps
          |> Option.to_result ~none:(Serror.Hole { loc; expected = None })
```

Six rules, each forced:

1. The activation test is `spine`'s, character for character
   (elab.ml:479-484): `g` must not be in `scope`, `Global.find g globals`
   must be `Some`, and `peel_domains m gty` must be `Some`. `None` sends
   the caller to `app_infer`, which is HEAD.
2. The family fence still governs. `fenced globals g gty` (elab.ml:80-83)
   is read the same way, and a fenced head produces no captures. Measured
   at HEAD: `eval (mkEqD _ boolEq)` reports
   `1:13: hole: no expected type at this position` and exits 1, while the
   explicit twin `eval (mkEqD Bool boolEq)` exits 0 and prints
   `eval : (EqD Bool)`. The slot IS determined by first-order matching, so
   the fence, not a missing capture, is what refuses it. The negative is
   not vacuous.
3. `caps` starts empty. `rigid` needs an expected pre-term (elab.ml:153-154)
   and infer position has none, so the expected-type source is simply
   absent. `arg_caps` (A3) is the only source, with its shift, its first-fit
   walk and its `same_term` conflict test.
4. The pass runs only when a LEADING slot is a hole. `holed_leading_slot ~k
   args` is true when some `args` element at position `j < k` is
   `Syntax.SHole`. Every such spine is an ERROR at HEAD, because the SHole
   arm at elab.ml:287-291 has no other outcome. A HEAD-green file therefore
   takes no new code path and does no extra work.
5. An unsettled hole keeps HEAD's error VALUE, not a lookalike:
   `Serror.Hole { loc; expected = None }` with the hole's own `loc`. So the
   line, the column and the wording are HEAD's. Measured at HEAD, all three
   pin 2 negatives print the message this arm re-emits:
   `eval _` gives `1:6`, `eval (liftIO _ _)` gives `1:14`, and
   `eval (mkEqD _ boolEq)` gives `1:13`.
6. Non-leading positions and the output node are `spine`'s, so the built
   term is the same nested `Term.App` chain `term`'s SApp arm builds
   (elab.ml:270 and elab.ml:533-536 stamp the same `Quantity.Many`).

Order of errors. `term`'s SApp arm reports the FIRST failure, left to
right, through `let*` (elab.ml:268-269). `spine_infer` keeps that order:
`arg_caps` drops its own failures with `Result.to_option` and reports
nothing, then the settle fold elaborates every position left to right and
returns the first `Error`. So a spine whose first failure sits BEFORE the
hole keeps that failure, unchanged, and a spine whose first failure IS the
hole is the only shape that can move. That is pin 2 clause 2 in one
paragraph, and PASS-M7A-INFER-SETTLE-BUDGET is its oracle.

Why this is elaborator surface only, so PASS-M7A-KERNEL-UNCHANGED still
holds. The settle chooses which pre-term goes in an argument slot. It runs
before any kernel term is admitted, it adds no `Term.t` constructor, and it
calls nothing in `lib/` except the pure helpers `Term.shift`, `Global.find`
and `Global.entry_ty` that HEAD's elaborator already calls (elab.ml:202,
elab.ml:480, elab.ml:483). The finished definition is re-checked by the
UNCHANGED kernel at `surface/run.ml:241`, so a wrong fill is a kernel
error, never a silent accept. `type rule = Structural` (lib/totality.ml)
gains no constructor, `Check.define`'s `~rule` stays required
(surface/run.ml:241 passes it literally), and the seven frozen `lib/` files
keep the md5 `f446f043e1ad6c7b85ddedb7736bd8a1`. The only `lib/` edit in
Stage A is A5, which moves `Term.App` out of the catch-all at
`lib/check.ml:1208-1211` into a named arm with the same body. Probe 1
asserts all three invariants and pairs them with a behavioural leg.

What the settle must NOT do, so pin 2 survives:

1. It must not run when no leading slot is a hole. Any wider trigger reads
   a HEAD-green spine and can only cost time or change output.
2. It must not run under the fence, and it must not relax the fence for a
   nested argument.
3. It must not change the error VALUE of an unsettled hole. `expected` stays
   `None` in infer position. A settle that reported the slot's universe here
   would turn `eval (liftIO _ _)` from
   `1:14: hole: no expected type at this position` into
   `1:14: hole: expected Type 0`, which is a changed message on a file the
   stage does not license to move.
4. It must not evaluate, except on the A2 retry path that is already an
   error at HEAD, and it must not backtrack or unify across definitions.
5. It must not re-order or swallow an error from a non-hole argument.

The probe for all five is PASS-M7A-INFER-SETTLE-BUDGET. The corpus is
`stdlib/`, `examples/` and `test/fixtures/`. Measured at HEAD,
`fd -e tot . /Users/oobi/Documents/tot/stdlib
/Users/oobi/Documents/tot/examples /Users/oobi/Documents/tot/test/fixtures`
lists 102 files, and exactly ONE of them reports
`hole: no expected type at this position`:
`test/fixtures/m6c-hole-n-infer.tot` at `1:6`. That file must NOT move. It
is the pin 2 negative, and it stays inside the digest.

Two files are licensed to move in this stage, and no others:
`test/fixtures/m6c-hole-a.tot` (A7 item 1) and
`test/fixtures/m6c-hole-run.tot` (A7 item 2). The remaining 100 files are
digested one record per file, `basename|exit code|md5 of the combined
stdout and stderr`. Measured at HEAD: 100 records, 61 of them at exit 0,
and the digest of the whole body is
`9b416b949964a50c4f7633eab478b5c2`. All three numbers must be identical
after the stage. The probe command is in "Gate additions", probe 7.

#### A4. Constant-motive match branches descend in check position

`term_at` handles a motive-free match (elab.ml:429-451) and hands a
motive-carrying match to `term` (elab.ml:461). `term`'s SMatch arm
elaborates every branch body with `term globals scope' body`
(surface/elab.ml:375), that is in INFER position. Measured consequence at
HEAD: a hole in a leading slot inside `match xs as xx return Bool with ...`
reports `hole: no expected type at this position`, not the slot's universe.
`stdlib/prelude.tot:154-159` sits in exactly that shape. Its match header
is `match xs as xx return Bool with` at stdlib/prelude.tot:154, read at
HEAD, and the branch body at stdlib/prelude.tot:159 is the spine that holds
the slot Stage D re-spells. Without this part the rule cannot reach it.

Change, at elab.ml:370-377 only, under TWO preconditions that must both
hold: the elaborated motive body does not mention its own `as` binder, AND
the branch body holds a `Syntax.SHole`. When both hold, elaborate that
branch body with

```ocaml
term_at globals scope' ~locals:locals' ~expected:expected' body
```

where `expected'` is the motive body with the `as` slot dropped and shifted
past the branch binders, the same shift the motive-free arm already applies
(elab.ml:439). When the motive body DOES mention the `as` binder, the arm
keeps `term`, because the branch's expected type would then need the
dependent instantiation at the branch pattern, which is kernel work and is
out of scope for M7. When the branch body holds no hole, the arm also keeps
`term`.

The second precondition is the conservativity lemma of A4, and it is the A4
counterpart of A3's guard. `branch_body_has_hole` is a total fold over
`Syntax.t` that returns true when some subterm is `Syntax.SHole`. It is a
syntactic test on the parsed body, so it runs before any elaboration of the
branch. A branch body with no hole therefore keeps `term` and keeps HEAD's
exact node, and no HEAD-green file takes the A4 path. Without the
precondition a HEAD-green file WOULD take it: stdlib/prelude.tot:154-159 is
green at HEAD and has the constant-motive shape, so the motive test alone
lets it through. The precondition costs the rule nothing on its target,
because the argument Stage D re-spells at that site IS the hole, so the
test is true exactly when the rule has work to do.

The occurs test on the motive is a total fold over the term as well. For a
hole-free branch body `term_at` builds the same node `term` builds, because
every `term_at` arm either special-cases holes and spines or delegates to
`term` (elab.ml:400-464). That claim is a second line of defence and it is
no longer load-bearing, because the hole precondition keeps hole-free
bodies off the path. PASS-M7A-CONSERVATIVITY is the oracle for both.

#### A5. The check-position `Term.App` arm in the kernel

Verified at HEAD, both sites the design brief names:

- `infer` has an App arm at `lib/check.ml:960-969`. It consumes one
  argument, evaluates the stamped argument and instantiates the codomain.
- `check_node` has NO App arm. `Term.App (_, _, _)` falls into the
  catch-all at `lib/check.ml:1208-1211`, which routes to `check_via_infer`
  (`lib/check.ml:1213-1220`).

Stage A lifts `Term.App` out of that catch-all into its own named arm:

```ocaml
(* M7 Stage A (pin 1).  An application in CHECK position stays
   infer-then-convert.  Solving a spine here would be new admission
   power in lib/, which pin 1 forbids:  argument-driven resolution is an
   ELABORATOR abbreviation and every hole is gone before this arm sees a
   [Term.t].  The arm is named so the M7 reader finds the decision at the
   site instead of inside a seven-constructor catch-all. *)
| Term.App (_, _, _), expected_v -> check_via_infer globals ctx mode tm expected_v
```

The remaining catch-all keeps its other six constructors and its exhaustive
shape, with no wildcard arm. Behaviour is identical by construction: the
new arm's body is the catch-all's body. `define`'s signature at
`lib/check.ml:1459-1468` is untouched and `~rule` stays required.
`type rule = Structural` at `lib/totality.ml:8-20` is untouched.

#### A6. The `spine` doc comment (debt j)

`surface/elab.ml:466-476` still describes the M6 rule. The phrase "a hole
takes its capture or reports the" (elab.ml:472-473) and the phrase "then
argument descent through" (elab.ml:473-476) describe the settle fold and
the descent, and neither mentions the new capture source. Rewrite the
comment so it states, in order: the activation test, the k leading formals,
the family fence, the rigid match against the expected type, THE
ARGUMENT-DRIVEN capture pass with its first-fit and no-backtracking rule,
the settle fold, and the argument descent. The word `argument-driven` does
not occur in `surface/elab.ml` at HEAD, so its presence is a machine-checkable
witness that the comment was rewritten.

#### A7. Collateral: three M6C legs must be re-opened

The M6 rule "re-open a tripwire's design, never delete a leg" applies. The
new rule resolves two COMMITTED M6 negatives, because their later argument
is a closed global spine:

1. `test/fixtures/m6c-hole-a.tot` binds `readStdin : IO String`, which
   determines `bindIO`'s slot 0. At HEAD it reports
   `:2:8: hole: expected Type 0` with exit 1. After Stage A it checks with
   exit 0. `PASS-M6C-HOLE-REPORTS` leg (a) (dev/gates.sh:2668-2669 and the
   assertion at dev/gates.sh:2686) must point at an A-shaped negative that
   the M7 rule still refuses. Re-point it at `dev/m7a/arg-exhausted.tot`,
   whose informative argument is itself a bare hole, so nothing determines
   the slot in either position. Its HEAD line is
   `:2:8: hole: expected Type 0`, the same column and the same message, so
   the leg keeps its exact shape.
   The amendment re-spells this fixture. Its first spelling read
   `liftIO _ (jsonParse "{}")`, whose own hole the infer settle now fills
   from `jsonParse : String -> Div (Option Json)`
   (surface/bootstrap.ml:147), which would make the whole file green and
   the leg vacuous. The A11 spelling is `liftIO _ _`. Measured at HEAD, both
   spellings print `:2:8: hole: expected Type 0` and exit 1, so the swap
   costs the leg nothing.
2. `test/fixtures/m6c-hole-run.tot` binds `printLine "SIDE-EFFECT" : IO
   Unit`, which determines `bindIO`'s slot 0. After Stage A the file would
   CHECK and then RUN, and `PASS-M6C-HOLE-NEVER-RUNS`
   (dev/gates.sh:2697-2716) would assert on a file that no longer refuses.
   Re-spell the fixture so its hole is unresolvable, keeping the side
   effect in place (bytes in A10). Measured at HEAD, the re-spelled file
   reports `:1:82: hole: expected Unit` with exit 1, empty stdout, one
   stderr line, and no `SIDE-EFFECT` anywhere. The leg keeps every
   assertion and changes one pinned string.
3. Surface suite case `M6C-5 m6c_refuse_a` (test/surface.ml:1847-1851) pins
   the same A-shaped source string and the same
   `2:8: hole: expected Type 0`. Re-point it at the A11 exhausted source
   string, the `liftIO _ _` spelling, which keeps the message and the
   column.

No leg is deleted. Each keeps its name, its arity and its message shape.

#### A8. Transcript: two blocks reseal inside the Stage A commit

Pin 4 says the transcript reseals at Stage D and not before, and it names a
marker `PASS-M5E-TRANSCRIPT`. That marker does not exist. The live markers
are `PASS-M5E-DEFAULT-IDENTITY` (a fresh generation must diff clean) and
`PASS-M6E-TRANSCRIPT-RESEALED` (block count equals file count,
dev/gates.sh:3120-3139).

Because `dev/gen-m5e-transcript.sh` globs `examples/*.tot
test/fixtures/*.tot`, the two A7 repairs move two committed blocks:
`m6c-hole-a.tot` (now green) and `m6c-hole-run.tot` (re-spelled). At HEAD
`rg -c 'hole:' /Users/oobi/Documents/tot/dev/m5e-default-transcript.txt`
prints 9. After Stage A it prints 8: the `m6c-hole-a` line is gone and the
`m6c-hole-run` line keeps the word `hole:` with a new column and a new
expected type. The other seven `hole:` lines do not move, because they are
fenced holes, infer-position holes, or holes that are not leading slots.
Measured at HEAD, those seven lines are `m6c-hole-n-class.tot:1:51`,
`m6c-hole-n-infer.tot:1:6`, `m6c-hole-n-proof.tot:1:38`,
`m6c-underscore-lam.tot:1:32`, `m6c-underscore-match.tot:1:72`,
`m6h-hole-n-fence-class.tot:1:65` and `m6h-hole-n-fence-proof.tot:1:42`, and
each one is inside the PASS-M7A-INFER-SETTLE-BUDGET digest.

This is a conflict with pin 4 as written. Ruling for the plan, dated
2026-09-03: Stage A regenerates the transcript, the diff is reviewed line by
line, and the review must show exactly two changed blocks and no third.
The block COUNT does not change, so `PASS-M6E-TRANSCRIPT-RESEALED` holds
unchanged. Stage D still reseals the corpus blocks it edits. The Stage A
commit message carries the two-block diff. If the ratifier prefers pin 4
read literally, the fallback is to move both fixtures out of
`test/fixtures/` into `dev/m7a/` in the same commit, which costs the
transcript two blocks instead of two block bodies, and which the same
review catches.

#### A9. Reach against pin 5, measured

One fixture per anchor SHAPE, each spelled with the anchor holed and each
run at HEAD:

| shape | anchor it mirrors | later argument that determines the slot | source | resolves |
| --- | --- | --- | --- | --- |
| s1 | examples/guard.tot:133 | `readStdin`, closed global | A2 (2) | yes |
| s2 | examples/guard-rewrap.tot:264 | `readStdin`, closed global | A2 (2) | yes |
| s3 | stdlib/prelude.tot:173 | `listEqBy _ (eqf A d)` under `mkEqD` | A3b | yes |
| s4 | stdlib/prelude.tot:176 | `xs`, a lambda binder | A1 | yes |
| s5 | stdlib/prelude.tot:17 | `t`, a match binder | A1 | yes |
| s6 | stdlib/prelude.tot:145 | `t`, a match binder | A1 | yes |
| s7 | stdlib/prelude.tot:159 | `t1`, a match binder under a motive | A1 + A4 | yes |

RULING RECORD. An earlier draft of this stage measured s3 and reported six
of the nine A anchors, not seven. It asked for a ratification. The
ratification amendment of 2026-09-04 answers it. The amendment keeps pin 5
at seven anchors and adds the infer-path settle to Stage A as the mechanism
that reaches the seventh. The conflict is therefore closed in favour of
seven. `stdlib/prelude.tot:173` stays an A anchor. It does NOT join the pin
6 list. Stage D re-spells it like the other six. The reason the earlier
draft gave was correct on its own terms: the family fence sends the nested
argument to `term globals scope arg` (elab.ml:522), and at HEAD `term` has
no settle. A3b puts the settle in `term`, so the fence branch keeps its
meaning and the nested call still resolves.

The seven pin 5 anchors, each with its HEAD line and the message that line
gives at HEAD when the pinned slot is spelled `_`. Each message comes from
the matching mirror fixture under
`/Users/oobi/Documents/tot-m7-probes/amend/`, run against
`_build/default/bin/tot.exe` at 66b444f. The mirror path prefix is stripped
and the mirror line number is the mirror's own.

| # | HEAD line | HEAD source text of the slot | mirror | HEAD message when holed | part that fills it |
| --- | --- | --- | --- | --- | --- |
| 1 | examples/guard.tot:133 | `let* String _ raw := readStdin in` | s1-holed | `2:8: hole: expected Type 0` | A3 |
| 2 | examples/guard-rewrap.tot:264 | `let* String _ raw := readStdin in` | s2-holed | `2:8: hole: expected Type 0` | A3 |
| 3 | stdlib/prelude.tot:173 | `fun A d => mkEqD (List A) (listEqBy A (eqf A d))` | s3-holed | `2:39: hole: no expected type at this position` | A3b |
| 4 | stdlib/prelude.tot:176 | `fun A d x xs => anyList A (eqf A d x) xs` | s4-holed | `2:27: hole: expected Type 0` | A3 + A1 |
| 5 | stdlib/prelude.tot:17 | `map` recursive call, `cons B (f h) (map A B f t)` | s5-holed | `2:82: hole: expected Type 0` | A3 + A1 |
| 6 | stdlib/prelude.tot:145 | `anyList` recursive call, `orb (p h) (anyList A p t)` | s6-holed | `2:81: hole: expected Type 0` | A3 + A1 |
| 7 | stdlib/prelude.tot:159 | `listEqBy` inner call, `andb (f h1 h2) (listEqBy A f t1 t2)` | s7-holed | `8:52: hole: no expected type at this position` | A4 + A1 + A3 |

Two of the seven print the infer message at HEAD, not the check message:
anchor 3 and anchor 7. Each sits under an arm that hands the sub-term to
`term`, the fence branch at elab.ml:522 for anchor 3 and the match branch
body at elab.ml:375 for anchor 7. The two need different parts. Anchor 7
has a constant motive, so A4 moves its branch body into check position and
A3 then fills the slot. Anchor 3 sits under a class former, so the fence
branch must stay as it is, and only A3b reaches it. The other five print
`hole: expected Type 0`, the check-position message, and A3 alone fills
them. Anchor 3 is the single anchor that the amendment adds, and it is the
reason the amendment is needed.

REACH AGAINST THE TWO STAGE B GUARD SLOTS. Pin 6 pins
`examples/guard.tot:134` and `examples/guard-rewrap.tot:265` as negatives.
At HEAD both lines are the same bytes:

```
  let* (Option Json) _ parsed := liftIO _ (jsonParse raw) in
```

The pinned slot is the first `let*` type, the one spelled `(Option Json)`.
The verdict records the reason for the two negatives as "the informative
later argument is itself holed". Measured at HEAD, that recorded reason is
no longer true once A3b lands. The statement Stage B may rely on has two
halves, and each half has its own HEAD measurement.

Half one, the settle REACHES both slots. One HEAD measurement per slot,
each taken on a whole-file copy of the example with only the pinned slot
re-spelled `_`, so the measurement carries the real context and the real
line number. Both copies live under
`/Users/oobi/Documents/tot-m7-probes/amend/`.

| slot | copy | HEAD holed | HEAD explicit |
| --- | --- | --- | --- |
| examples/guard.tot:134 | guard-134-holed.tot | exit 1, `134:8: hole: expected Type 0` | exit 0, last line `def main : (IO Verdict)` |
| examples/guard-rewrap.tot:265 | guard-rewrap-265-holed.tot | exit 1, `265:8: hole: expected Type 0` | exit 0, last line `def main : (IO Verdict)` |

Both slots therefore fail at HEAD with the CHECK-position hole message, at
the same column, for the same reason. The message is A3's, but A3 alone
cannot fill either slot. The argument that determines the slot is
`liftIO _ (jsonParse raw)`, which is itself a holed spine, and `arg_caps`
elaborates a later argument with `term` (A3, property 1). At HEAD `term`
refuses that argument at elab.ml:287-291, so `Result.to_option` drops it and
the walk moves on with no capture. A3b is what makes that argument
elaborate. Both parts are needed, in this order: A3b settles the inner
`liftIO` hole, then A3 reads the resulting type and fills the pinned slot.
The small mirror `guard-slot-holed.tot` reproduces the
same message at its own line, `3:8: hole: expected Type 0`, exit 1, and its
twin `guard-slot-explicit.tot` exits 0 and prints
`def main : (IO Verdict)`. The chain that determines the slot runs through
the second `let*` value, not through the first `_` after `liftIO`:

1. `liftIO : (0 A : Type 0) -> Div A -> IO A` (surface/bootstrap.ml:109).
2. `jsonParse : String -> Div (Option Json)` (surface/bootstrap.ml:147). The
   codomain is closed, so the local `raw` cannot change it.
3. `eval (liftIO _ (jsonParse "{}"))` is the HEAD wall. At HEAD it prints
   `1:14: hole: no expected type at this position`, exit 1. With A3b the
   settle matches `Div A0` against `Div (Option Json)` and fills `A0`.
4. The fill is UNIQUE at HEAD, not a guess. `eval (liftIO Json (jsonParse
   "{}"))` prints `type mismatch: expected (Div Json), found (Div (Option
   Json))`, exit 1. `eval (liftIO (Option Json) (jsonParse "{}"))` exits 0
   and prints `eval : (IO (Option Json))`.
5. `bindIO : (0 A : Type 0) -> (0 B : Type 0) -> IO A -> (A -> IO B) -> IO
   B` (surface/bootstrap.ml:108). The `let*` desugars to `bindIO`, so the
   position 3 domain `IO A0` matches `IO (Option Json)` and the pinned slot
   settles to `(Option Json)`.

Half two, Stage B must still re-derive the two slots itself and must not
copy this paragraph as a verdict. Two things can hold the slots as
negatives even with the settle in place: a Stage B decision to keep pin 6 as
written, and the second half of each line, the bare lambda `_` that the
verdict also names. That second half is NOT load-bearing here, because the
pinned slot is the first `let*` type and the measurements above cover it.
So the sentence Stage B may rely on is exactly this: THE SETTLE REACHES
BOTH SLOTS, the recorded reason for their negative status stops being true,
and any decision to keep them negative needs a fresh reason. Stage A does
not change either line and does not change pin 6.

#### A10. Fixture bytes

All fixtures go under `/Users/oobi/Documents/tot/dev/m7a/`. Each block is
the exact file content.

`dev/m7a/s1-explicit.tot` (twin of the committed `test/fixtures/m6c-hole-a.tot`):

```
def main : IO Verdict :=
  let* String Verdict raw := readStdin in
  pureIO Verdict allow
```

`dev/m7a/s2-holed.tot`:

```
def probeRW : IO String :=
  let* _ String raw := readStdin in
  pureIO String raw
```

`dev/m7a/s2-explicit.tot`:

```
def probeRW : IO String :=
  let* String String raw := readStdin in
  pureIO String raw
```

`dev/m7a/s3-holed.tot`:

```
def myEqList : (0 A : Type 0) -> EqD A -> EqD (List A) :=
  fun A d => mkEqD (List A) (listEqBy _ (eqf A d))
```

`dev/m7a/s3-explicit.tot`:

```
def myEqList : (0 A : Type 0) -> EqD A -> EqD (List A) :=
  fun A d => mkEqD (List A) (listEqBy A (eqf A d))
```

`dev/m7a/s4-holed.tot`:

```
def myMember : (0 A : Type 0) -> EqD A -> A -> List A -> Bool :=
  fun A d x xs => anyList _ (eqf A d x) xs
```

`dev/m7a/s4-explicit.tot`:

```
def myMember : (0 A : Type 0) -> EqD A -> A -> List A -> Bool :=
  fun A d x xs => anyList A (eqf A d x) xs
```

`dev/m7a/s5-holed.tot`:

```
def rec myMap : (0 A : Type 0) -> (0 B : Type 0) -> (A -> B) -> List A -> List B :=
  fun A B f xs => match xs with | nil => nil B | cons h t => cons B (f h) (myMap _ B f t) end
```

`dev/m7a/s5-explicit.tot`:

```
def rec myMap : (0 A : Type 0) -> (0 B : Type 0) -> (A -> B) -> List A -> List B :=
  fun A B f xs => match xs with | nil => nil B | cons h t => cons B (f h) (myMap A B f t) end
```

`dev/m7a/s6-holed.tot`:

```
def rec myAnyList : (0 A : Type 0) -> (A -> Bool) -> List A -> Bool :=
  fun A p xs => match xs with | nil => false | cons h t => orb (p h) (myAnyList _ p t) end
```

`dev/m7a/s6-explicit.tot`:

```
def rec myAnyList : (0 A : Type 0) -> (A -> Bool) -> List A -> Bool :=
  fun A p xs => match xs with | nil => false | cons h t => orb (p h) (myAnyList A p t) end
```

`dev/m7a/s7-holed.tot`:

```
def rec myListEqBy : (0 A : Type 0) -> (A -> A -> Bool) -> List A -> List A -> Bool :=
  fun A f xs ys =>
    match xs as xx return Bool with
    | nil => match ys as yy return Bool with | nil => true | cons h2 t2 => false end
    | cons h1 t1 =>
        match ys as yy return Bool with
        | nil => false
        | cons h2 t2 => andb (f h1 h2) (myListEqBy _ f t1 t2)
        end
    end
```

`dev/m7a/s7-explicit.tot` (the same file with `myListEqBy A f t1 t2` on the
inner `cons h2 t2` line):

```
def rec myListEqBy : (0 A : Type 0) -> (A -> A -> Bool) -> List A -> List A -> Bool :=
  fun A f xs ys =>
    match xs as xx return Bool with
    | nil => match ys as yy return Bool with | nil => true | cons h2 t2 => false end
    | cons h1 t1 =>
        match ys as yy return Bool with
        | nil => false
        | cons h2 t2 => andb (f h1 h2) (myListEqBy A f t1 t2)
        end
    end
```

These bytes were checked at HEAD from the copy at
`/Users/oobi/Documents/tot-m7-probes/plan/s7-explicit.tot`.  The run exited
0 and printed
`def myListEqBy : (0 A : Type 0) -> (w _ : (w _ : A) -> (w _ : A) -> Bool) -> (w _ : (List A)) -> (w _ : (List A)) -> Bool`,
which is the explicit output Probe 2 compares the holed twin against.

`dev/m7a/arg-map.tot`:

```
def probeF : List Nat := map _ Nat (fun n => n) (nil Nat)
```

`dev/m7a/arg-map-explicit.tot`:

```
def probeF : List Nat := map Nat Nat (fun n => n) (nil Nat)
```

`dev/m7a/arg-exhausted.tot`, SUPERSEDED by A11. Do not create these bytes.
The settle now fills this hole. A11 gives the spelling the builder writes.

```
def probeG : IO Verdict :=
  let* _ Verdict parsed := liftIO _ (jsonParse "{}") in
  pureIO Verdict allow
```

`dev/m7a/arg-ambiguous.tot`:

```
def widen : (0 A : Type 0) -> List A -> List A -> Nat := fun A xs ys => zero
def probeH : Nat := widen _ (nil Nat) (nil String)
```

`dev/m7a/arg-ambiguous-explicit.tot`:

```
def widen : (0 A : Type 0) -> List A -> List A -> Nat := fun A xs ys => zero
def probeH : Nat := widen Nat (nil Nat) (nil String)
```

`dev/m7a/arg-infer.tot`, SUPERSEDED by A11. Do not create this path. The
same bytes land at `dev/m7a/arg-infer-holed.tot`, with an explicit twin,
because the settle turns this negative into a positive.

```
def probeI : List Nat := match (map _ Nat (fun n => n) (nil Nat)) with | nil => nil Nat | cons h t => t end
```

`test/fixtures/m6c-hole-run.tot`, re-spelled in place (A7 item 2):

```
def main : IO Unit := let* Unit Unit x := printLine "SIDE-EFFECT" in pureIO Unit _
```

#### A11. New fixture bytes for the infer settle

The amendment of 2026-09-04 adds eleven fixtures and re-spells one of the
A10 fixtures. Where A10 and A11 disagree, the A11 bytes win. All paths are
under `/Users/oobi/Documents/tot/dev/m7a/`. Every message quoted here was
measured at HEAD 66b444f with
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe check` on the mirror
copy in `/Users/oobi/Documents/tot-m7-probes/amend/`, with the path prefix
stripped from the output.

`dev/m7a/infer-lift-holed.tot`. HEAD: exit 1, `1:14: hole: no expected type
at this position`.

```
eval (liftIO _ (jsonParse "{}"))
```

`dev/m7a/infer-lift-explicit.tot`. HEAD: exit 0, `eval : (IO (Option
Json))`. This is the twin the settle must reproduce.

```
eval (liftIO (Option Json) (jsonParse "{}"))
```

`dev/m7a/infer-listeqby-holed.tot`. HEAD: exit 1, `1:16: hole: no expected
type at this position`.

```
eval (listEqBy _ boolEq)
```

`dev/m7a/infer-listeqby-explicit.tot`. HEAD: exit 0.

```
eval (listEqBy Bool boolEq)
```

`dev/m7a/infer-fenced.tot`. A NEGATIVE. `mkEqD` is a class former, so
`fenced` is true (elab.ml:80-83) and rule 2 of A3b keeps the settle off.
HEAD: exit 1, `1:13: hole: no expected type at this position`. After the
stage the exit code and the message stay the same.

```
eval (mkEqD _ boolEq)
```

`dev/m7a/infer-fenced-explicit.tot`. The control that proves the fenced
program is otherwise well typed. HEAD: exit 0.

```
eval (mkEqD Bool boolEq)
```

`dev/m7a/infer-undetermined.tot`. A NEGATIVE. Every later argument is
itself a hole, so no rigid match fires and rule 5 of A3b re-emits HEAD's
error value. HEAD: exit 1, `1:14: hole: no expected type at this position`.
After the stage the exit code and the message stay the same.

```
eval (liftIO _ _)
```

`dev/m7a/arg-infer-holed.tot`. This file replaces `dev/m7a/arg-infer.tot`
from A10. A10 used it as a negative. The settle turns it into a positive,
so it moves to the twin pattern and takes an explicit partner. The hole
sits in a match SCRUTINEE, which A4 does not touch, so only A3b reaches it.
HEAD: exit 1, `1:37: hole: no expected type at this position`.

```
def probeI : List Nat := match (map _ Nat (fun n => n) (nil Nat)) with | nil => nil Nat | cons h t => t end
```

`dev/m7a/arg-infer-explicit.tot`. HEAD: exit 0.

```
def probeI : List Nat := match (map Nat Nat (fun n => n) (nil Nat)) with | nil => nil Nat | cons h t => t end
```

`dev/m7a/guard-slot-holed.tot`. The A9 mirror of `examples/guard.tot:134`
and `examples/guard-rewrap.tot:265`, with the pinned slot spelled `_`. It
lives in `dev/m7a/` only. Stage A does NOT edit either example. HEAD: exit
1, `3:8: hole: expected Type 0`.

```
def main : IO Verdict :=
  let* String _ raw := readStdin in
  let* _ _ parsed := liftIO _ (jsonParse raw) in
  match parsed with
  | none => pureIO _ allow
  | some payload => pureIO _ allow
  end
```

`dev/m7a/guard-slot-explicit.tot`. HEAD: exit 0, `def main : (IO
Verdict)`.

```
def main : IO Verdict :=
  let* String _ raw := readStdin in
  let* (Option Json) _ parsed := liftIO _ (jsonParse raw) in
  match parsed with
  | none => pureIO _ allow
  | some payload => pureIO _ allow
  end
```

`dev/m7a/arg-exhausted.tot`, RE-SPELLED. The A10 spelling used `liftIO _
(jsonParse "{}")`, and the settle now fills that hole from `jsonParse :
String -> Div (Option Json)` (surface/bootstrap.ml:147). The A10 spelling
would therefore stop refusing and would make probe 2 vacuous. The new
spelling holds every later argument as a hole, so nothing can determine the
slot. Both spellings print the same message and the same column at HEAD,
`2:8: hole: expected Type 0`, exit 1, so the A10 role of the file is
preserved.

```
def probeG : IO Verdict :=
  let* _ Verdict parsed := liftIO _ _ in
  pureIO Verdict allow
```

### Gate additions

The new block goes into `dev/gates.sh` after the
`PASS-M6E-TRANSCRIPT-RESEALED` block, which ends at `dev/gates.sh:3139`,
and before the two timing-sensitive tail legs at `dev/gates.sh:3172` and
`dev/gates.sh:3190`. Every leg follows the M6C shape at
`dev/gates.sh:2646-2716`: run under `"$watchdog" "$FAST"`, capture the exit
code, assert, then `&& echo PASS-<marker>` or `|| { diagnostic; echo
"FAIL-<marker> (exit=...)"; exit 1; }`. The block opens with
`m7a_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m7a.XXXXXX")`, mirroring
`dev/gates.sh:2644`.

Gate literal, derived at HEAD:

```
rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' /Users/oobi/Documents/tot/dev/gates.sh
```

printed `169`, and `dev/gates.sh:2284` asserts `[ "$m5d_tiers" -eq 169 ]`
inside `PASS-M5D-TIERS` (dev/gates.sh:2281-2287). The seven blocks below add
11 direct tier-call LINES (1 + 2 + 3 + 2 + 0 + 2 + 1), so the literal
becomes 180. The builder re-runs the same `rg` after writing the block and
sets the literal to the printed value.

Where the At HEAD lines below were measured. `dev/m7a/` does not exist at
HEAD; this stage creates it. `ls -d /Users/oobi/Documents/tot/dev/m7a`
printed `No such file or directory` at HEAD 66b444f. A `tot.exe check` on
a missing path prints `<path>: no such file` and exits 1, which looks like
a refusal in an exit-code summary and is not one. So every At HEAD number
below that depends on a `dev/m7a/` fixture was measured against
byte-identical copies, and the copy path and the exact message are recorded
with the number. The A10 fixtures were measured under
`/Users/oobi/Documents/tot-m7-probes/plan/`. The A11 fixtures, which the
amendment of 2026-09-04 adds, were measured under
`/Users/oobi/Documents/tot-m7-probes/amend/`. The Command lines stay written
against the repo paths, because that is where the gate runs after the stage.

Probe 1.

- Marker: `PASS-M7A-KERNEL-UNCHANGED`
- Pin: 1
- Command (post-stage): `printf 'rule=%s define=%s frozen=%s ' "$(rg -c '^type rule = Structural$' /Users/oobi/Documents/tot/lib/totality.ml)" "$(rg -c '~\(rule : Totality\.rule\)' /Users/oobi/Documents/tot/lib/check.ml)" "$(cat /Users/oobi/Documents/tot/lib/totality.ml /Users/oobi/Documents/tot/lib/term.ml /Users/oobi/Documents/tot/lib/eval.ml /Users/oobi/Documents/tot/lib/value.ml /Users/oobi/Documents/tot/lib/erase.ml /Users/oobi/Documents/tot/lib/interp.ml /Users/oobi/Documents/tot/lib/error.ml | md5 -q)"; f=/Users/oobi/Documents/tot/dev/m7a/arg-map.tot; [ -f "$f" ] || { echo MISSING-FIXTURE; exit 9; }; /Users/oobi/Documents/tot/_build/default/bin/tot.exe check "$f" >/dev/null 2>&1; printf 'argmap=%d\n' $?`
- Command measured at HEAD: the same line with
  `f=/Users/oobi/Documents/tot-m7-probes/plan/a-arg-map.tot`, the copy that
  holds the A10 `dev/m7a/arg-map.tot` bytes, because `dev/m7a/` does not
  exist at HEAD.
- At HEAD: exit 0, output `rule=1 define=1 frozen=f446f043e1ad6c7b85ddedb7736bd8a1 argmap=1`,
  run 2026-09-04. The three invariant legs read the repo files. The
  `argmap` leg read the copy, which printed
  `a-arg-map.tot:1:30: hole: expected Type 0` and exited 1, so `argmap=1` is
  a real hole refusal at the leading erased slot.
- Existence assertion: `[ -f "$f" ]` runs before the check, and a missing
  file prints `MISSING-FIXTURE` and exits 9. A deleted fixture or a typo in
  the path therefore cannot produce `argmap=1`, which is the value a hole
  refusal also produces.
- After stage: exit 0, output contains `rule=1 define=1 frozen=f446f043e1ad6c7b85ddedb7736bd8a1 argmap=0`
- Non-vacuous because: the three invariant legs cannot flip on their own, so
  the marker pairs them with a behavioural leg that MUST flip. A build that
  forgot the elaborator change leaves `argmap=1` and fails. A build that
  bought the resolution by touching a frozen kernel file changes the digest
  and fails. Deleting the rule from `lib/totality.ml` drops `rule` to 0 and
  fails. The HEAD baseline for `argmap=1` names the message
  `1:30: hole: expected Type 0`, so a deleted fixture or a typo in the path
  cannot stand in for the refusal.

Probe 2.

- Marker: `PASS-M7A-ARGHOLE-RESOLVES`
- Pin: 3, and pin 5 by shape
- Command (post-stage): `S=/Users/oobi/Documents/tot; for f in $S/test/fixtures/m6c-hole-a.tot $S/dev/m7a/s2-holed.tot $S/dev/m7a/s4-holed.tot $S/dev/m7a/s5-holed.tot $S/dev/m7a/s6-holed.tot $S/dev/m7a/s7-holed.tot $S/dev/m7a/arg-exhausted.tot $S/dev/m7a/arg-ambiguous.tot; do [ -f "$f" ] || { echo MISSING-FIXTURE; exit 9; }; done; for f in $S/test/fixtures/m6c-hole-a.tot $S/dev/m7a/s2-holed.tot $S/dev/m7a/s4-holed.tot $S/dev/m7a/s5-holed.tot $S/dev/m7a/s6-holed.tot $S/dev/m7a/s7-holed.tot; do $S/_build/default/bin/tot.exe check "$f" >/dev/null 2>&1; printf '%d' $?; done; printf ' '; $S/_build/default/bin/tot.exe check $S/dev/m7a/arg-exhausted.tot >/dev/null 2>&1; printf 'exhausted=%d ' $?; $S/_build/default/bin/tot.exe check $S/dev/m7a/arg-ambiguous.tot 2>&1 | rg -c 'type mismatch: expected \(List Nat\), found \(List String\)'`
- Command measured at HEAD: the same line with the six `dev/m7a/` paths
  replaced by the copies
  `/Users/oobi/Documents/tot-m7-probes/plan/s{2,4,5,6,7}-holed.tot`,
  `/Users/oobi/Documents/tot-m7-probes/plan/a-arg-exhausted.tot` and
  `/Users/oobi/Documents/tot-m7-probes/plan/a-arg-ambiguous.tot`, which hold
  the A10 bytes, because `dev/m7a/` does not exist at HEAD.
  `test/fixtures/m6c-hole-a.tot` stays the repo path; it is in the repo at
  HEAD.
- Existence assertion: every one of the eight paths passes `[ -f "$f" ]`
  before any check runs, and a missing file prints `MISSING-FIXTURE` and
  exits 9. Without it the HEAD value `111111 exhausted=1` is also what a
  missing file prints, so the baseline would prove nothing.
- At HEAD: exit 1, output `111111 exhausted=1`, run 2026-09-04. There is no
  trailing `0`: the last stage is `rg -c`, which prints nothing and exits 1
  when it finds no match, and that exit 1 is the whole command's exit 1.
  Each copy printed a real hole refusal at exit 1:
  `s2-holed.tot:2:8`, `s4-holed.tot:2:27`, `s5-holed.tot:2:82`,
  `s6-holed.tot:2:81` and `a-arg-exhausted.tot:2:8`, all
  `hole: expected Type 0`; `s7-holed.tot:8:52: hole: no expected type at
  this position`; `a-arg-ambiguous.tot:2:27: hole: expected Type 0`.
  `test/fixtures/m6c-hole-a.tot` is in the repo at HEAD and exits 1 there.
- After stage: exit 0, output contains `000000 exhausted=1 1`
- Non-vacuous because: the six determined shapes flip from exit 1 to exit 0,
  the undetermined shape holds at exit 1, and the ambiguous shape moves from
  a hole error to the kernel mismatch that its explicit twin already
  produces. The final `rg -c` exits 1 at HEAD, which is why the whole
  command exits 1 at HEAD. In the gate the leg is a full comparison against
  the explicit twins: for each shape the holed output must equal the
  explicit output and must be non-empty, the same anti-vacuity sentinel
  `PASS-M6C-HOLE-RESOLVES` uses (dev/gates.sh:2656-2657). Measured explicit
  outputs at HEAD, all exit 0: `def main : (IO Verdict)`,
  `def probeRW : (IO String)`,
  `def myMember : (0 A : Type 0) -> (w _ : (EqD A)) -> (w _ : A) -> (w _ : (List A)) -> Bool`,
  `def myMap : (0 A : Type 0) -> (0 B : Type 0) -> (w _ : (w _ : A) -> B) -> (w _ : (List A)) -> (List B)`,
  `def myAnyList : (0 A : Type 0) -> (w _ : (w _ : A) -> Bool) -> (w _ : (List A)) -> Bool`,
  `def myListEqBy : (0 A : Type 0) -> (w _ : (w _ : A) -> (w _ : A) -> Bool) -> (w _ : (List A)) -> (w _ : (List A)) -> Bool`.

Probe 3.

- Marker: `PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE`
- Pin: 2
- Command (post-stage): `S=/Users/oobi/Documents/tot; X=$S/_build/default/bin/tot.exe; for f in $S/test/fixtures/m6c-hole-n-infer.tot $S/dev/m7a/infer-fenced.tot $S/dev/m7a/infer-undetermined.tot $S/dev/m7a/arg-map.tot; do [ -f "$f" ] || { echo MISSING-FIXTURE; exit 9; }; done; $X check $S/test/fixtures/m6c-hole-n-infer.tot 2>&1 | sd '^\S*/' '' ; $X check $S/dev/m7a/infer-fenced.tot 2>&1 | sd '^\S*/' '' ; $X check $S/dev/m7a/infer-undetermined.tot 2>&1 | sd '^\S*/' '' ; $X check $S/dev/m7a/arg-map.tot >/dev/null 2>&1; printf 'control=%d\n' $?`
- Command measured at HEAD: the same line with the three `dev/m7a/` paths
  replaced by the A11 copies
  `/Users/oobi/Documents/tot-m7-probes/amend/infer-fenced.tot`,
  `/Users/oobi/Documents/tot-m7-probes/amend/infer-undetermined.tot` and
  `/Users/oobi/Documents/tot-m7-probes/amend/arg-map.tot`, because `dev/m7a/`
  does not exist at HEAD. `test/fixtures/m6c-hole-n-infer.tot` stays the repo
  path.
- At HEAD: exit 0, and that command printed exactly these four lines on
  2026-09-04:
  `m6c-hole-n-infer.tot:1:6: hole: no expected type at this position`,
  `infer-fenced.tot:1:13: hole: no expected type at this position`,
  `infer-undetermined.tot:1:14: hole: no expected type at this position` and
  `control=1`. The control copy printed
  `arg-map.tot:1:30: hole: expected Type 0` on its own, which is the message
  behind `control=1`. After the stage the post-stage command reads the same
  lines and the same columns under the repo file names.
- After stage: exit 0, the same three infer-position lines byte for byte, and `control=0`
- Non-vacuous because: three refusal legs that must NOT move are paired with
  a control that must move. Each negative names a different reason. The bare
  `eval _` hole in `m6c-hole-n-infer.tot` is not an argument of a global
  spine, so no spine can settle it. `infer-fenced.tot` is a spine whose head
  is a class former, so rule 2 of A3b keeps the settle off, and its explicit
  twin exits 0, which proves the fence and not a missing capture is what
  refuses it. `infer-undetermined.tot` holds every later argument as a hole,
  so rule 5 of A3b re-emits HEAD's error value. If a builder drops the
  activation test, relaxes the fence or reports a different error value for
  an unsettled hole, one of the three lines changes and the leg fails. If a
  builder ships nothing at all, `control` stays 1 and the leg fails.

Probe 4.

- Marker: `PASS-M7A-CONSERVATIVITY`
- Pin: 4
- Command: `for f in church guard-classes guard-rewrap guard literals; do /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/examples/$f.tot 2>/dev/null; done | tee /dev/stderr | md5 -q; for f in church guard-classes guard-rewrap guard literals; do /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/examples/$f.tot 2>/dev/null; done | wc -l; rg -c 'hole:' /Users/oobi/Documents/tot/dev/m5e-default-transcript.txt`
- At HEAD: exit 0, output contains `99c23b4b74c722735d17e1dc49524e58`, `55` and `9`
- After stage: exit 0, output contains `99c23b4b74c722735d17e1dc49524e58`, `55` and `8`
- Non-vacuous because: the digest and the line count are the conservativity
  claim itself (every green corpus file keeps byte-identical stdout, and all
  five files are green at HEAD, measured), and the transcript count is the
  leg that MUST move, from 9 to 8, because `m6c-hole-a.tot` stops reporting
  a hole (A7, A8). A build that changed a green file's output changes the
  digest. A build that resealed the wrong blocks, or resealed none, misses
  the 8. In the gate the `tee /dev/stderr` is dropped and the stderr of each
  run is checked empty, so a file that starts failing cannot pass by
  printing nothing.
- Who re-derives the literal later, and it is Stage D. Two of the five files
  in the digest are the guards, and Stage D deletes six helper defs from each
  of them (D-stage-d.md, section D2). Measured at HEAD on 2026-09-04:
  `tot.exe check examples/guard.tot | rg -c '^def (firstNonEmpty|lastOr|splitEach|firstToken|orEmpty|elideAt) '`
  prints 6, and the same command on `examples/guard-rewrap.tot` prints 6.
  Those twelve lines sit inside the digested stdout, so after Stage D the
  count falls from 55 to 43 and the md5 moves. Stage D owns both literals and
  names this marker in its own literal-edit list. Stage A freezes
  `99c23b4b74c722735d17e1dc49524e58` and `55` for Stage A, Stage B and Stage
  C only, because neither of those stages edits any of the five files.

Probe 5.

- Marker: `PASS-M7A-SPINE-COMMENT`
- Pin: debt item (j)
- Command: `printf 'stale=%s descent=%s m7=%s run=%s\n' "$(rg -c -F 'a hole takes its capture or reports the' /Users/oobi/Documents/tot/surface/elab.ml)" "$(rg -c -F 'then argument descent through' /Users/oobi/Documents/tot/surface/elab.ml)" "$(rg -c -F 'argument-driven' /Users/oobi/Documents/tot/surface/elab.ml)" "$(rg -c -F 'SIDE-EFFECT' /Users/oobi/Documents/tot/test/fixtures/m6c-hole-run.tot)"`
- At HEAD: exit 0, output contains `stale=1 descent=1 m7= run=1`
- After stage: exit 0, output contains `stale= descent=1 m7=1 run=1`
- Non-vacuous because: the stale sentence must disappear and the phrase
  `argument-driven` must appear, and both counts are measured at HEAD in the
  opposite state (`rg -c -F 'argument-driven'` exits 1 and prints nothing at
  HEAD). `descent=1` holds the rest of the comment in place, so the marker
  refuses a comment that was deleted instead of rewritten. `run=1` holds the
  side effect inside the re-spelled `m6c-hole-run.tot`, so the A7 repair
  cannot pass by removing the effect the M6C leg exists to watch.

Probe 6.

- Marker: `PASS-M7A-INFER-SETTLE`
- Pin: 2, 3, 5
- Command (post-stage): `D=/Users/oobi/Documents/tot/dev/m7a; X=/Users/oobi/Documents/tot/_build/default/bin/tot.exe; for f in s3-holed infer-lift-holed infer-listeqby-holed arg-infer-holed infer-fenced infer-undetermined; do [ -f $D/$f.tot ] || { echo MISSING-FIXTURE; exit 9; }; done; printf 'holed='; for f in s3-holed infer-lift-holed infer-listeqby-holed arg-infer-holed; do $X check $D/$f.tot >/dev/null 2>&1; printf '%d' $?; done; printf ' neg='; for f in infer-fenced infer-undetermined; do $X check $D/$f.tot >/dev/null 2>&1; printf '%d' $?; done; printf ' fence=%s undet=%s\n' "$($X check $D/infer-fenced.tot 2>&1 | sd '^\S*/' '')" "$($X check $D/infer-undetermined.tot 2>&1 | sd '^\S*/' '')"`
- Command measured at HEAD: the same line with
  `D=/Users/oobi/Documents/tot-m7-probes/amend`, the directory that holds the
  six A11 copies, because `dev/m7a/` does not exist at HEAD.
- Existence assertion: all six paths pass `[ -f ]` before any check runs, and
  a missing file prints `MISSING-FIXTURE` and exits 9. Without it the HEAD
  values `holed=1111` and `neg=11` are also what six missing files print, so
  the exit-code half of the baseline would prove nothing. The `fence` and
  `undet` fields carry the message, which is the second guard on the same
  point.
- At HEAD: exit 0, and that command printed
  `holed=1111 neg=11 fence=infer-fenced.tot:1:13: hole: no expected type at this position undet=infer-undetermined.tot:1:14: hole: no expected type at this position`
  on 2026-09-04. Each of the four `holed` copies printed a real hole refusal
  on its own: `s3-holed.tot:2:39`, `infer-lift-holed.tot:1:14`,
  `infer-listeqby-holed.tot:1:16` and `arg-infer-holed.tot:1:37`, all
  `hole: no expected type at this position`.
- After stage: exit 0, output contains
  `holed=0000 neg=11 fence=infer-fenced.tot:1:13: hole: no expected type at this position undet=infer-undetermined.tot:1:14: hole: no expected type at this position`
- Non-vacuous because: the four settled legs must flip from 1 to 0 and the
  two negatives must hold at 1 with their exact HEAD text, so a build that
  ships nothing fails on `holed` and a build that settles too much fails on
  `fence` or `undet`. `s3-holed` is the pin 5 anchor 3 shape, the one the
  amendment exists for, and it can only pass through A3b, because HEAD hands
  the nested argument to `term` at elab.ml:522. In the gate each `holed` leg
  is a full `m6c_twins`-style comparison against its explicit twin
  (dev/gates.sh:2656-2657): the holed stdout must equal the explicit stdout
  and must be non-empty. Measured explicit twins at HEAD, all exit 0:
  `s3-explicit.tot` prints
  `def myEqList : (0 A : Type 0) -> (w _ : (EqD A)) -> (EqD (List A))`,
  `infer-lift-explicit.tot` prints `eval : (IO (Option Json))`,
  `infer-listeqby-explicit.tot` prints
  `eval : (w _ : (List Bool)) -> (w _ : (List Bool)) -> Bool`, and
  `arg-infer-explicit.tot` prints `def probeI : (List Nat)`.

Probe 7.

- Marker: `PASS-M7A-INFER-SETTLE-BUDGET`
- Pin: 2
- Command: `out=$(for f in $(fd -e tot --max-depth 1 . /Users/oobi/Documents/tot/stdlib /Users/oobi/Documents/tot/examples /Users/oobi/Documents/tot/test/fixtures | sort); do case "$f" in (*m6c-hole-a.tot|*m6c-hole-run.tot) continue ;; esac; o=$(/Users/oobi/Documents/tot/_build/default/bin/tot.exe check "$f" 2>&1); e=$?; printf '%s|%d|%s\n' "${f##*/}" "$e" "$(printf '%s' "$o" | md5 -q)"; done); printf 'files=%s green=%s md5=%s\n' "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "$(printf '%s\n' "$out" | rg -c '\|0\|')" "$(printf '%s\n' "$out" | md5 -q)"`
- At HEAD: exit 0, output contains
  `files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2`
- After stage: exit 0, output contains
  `files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2`
- Non-vacuous because: this is the conservativity budget of pin 2, and the
  digest is the whole corpus minus the two files A7 licenses to move. The
  body holds 61 green records whose stdout must not move and 39 red records
  whose error text must not move, including
  `m6c-hole-n-infer.tot|1|80a36316762aad9221e323a43fcd4c81`, the one corpus
  file that reports `hole: no expected type at this position` at HEAD. A
  settle that fires without a holed leading slot, that relaxes the fence,
  that changes the error value of an unsettled hole or that re-orders a
  non-hole failure moves at least one record and flips the md5. The `files`
  leg refuses a digest that shrank because `fd` matched nothing, and the
  `green` leg refuses a digest that stayed stable because every file started
  failing. The leg is written with the `|| exit 1` shape of the M6C block, so
  a changed md5 is a FAIL and not a warning.

  Corpus scope, and it is the reason for `--max-depth 1`. `fd` recurses by
  default, so the bare form would also read the subdirectory fixtures a later
  stage adds. Stage B places three fixtures at `test/fixtures/m7/<name>.tot`
  (B-stage-b.md, section B5), and a recursive walk would pull those three
  into the digest and break this frozen literal one stage after it lands.
  `--max-depth 1` holds the corpus to the set the transcript generator walks,
  `examples/*.tot test/fixtures/*.tot` at dev/gen-m5e-transcript.sh:13, so
  Stage B adds nothing to it. Measured at HEAD on 2026-09-04: the recursive
  form and the `--max-depth 1` form both print
  `files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2`, and
  `fd -t d . /Users/oobi/Documents/tot/stdlib /Users/oobi/Documents/tot/examples /Users/oobi/Documents/tot/test/fixtures`
  prints nothing, so the two forms name the same corpus at HEAD and the scope
  change moves no number.

  Who re-derives the literal later. Stage D adds
  `test/fixtures/m7d-prelude-splitEach.tot` at depth 1 and re-spells the
  prelude and both guards; Stage E adds three more depth-1 fixtures under
  `test/fixtures/`. Both stages move `files`, `green` and the md5 of this
  leg. Stage D and Stage E each own the re-derivation and each names this
  marker in its own literal-edit list. Stage A freezes the literal for Stage
  A, Stage B and Stage C only.

Surface suite, 12 new cases in the `cases` registry of `test/surface.ml`
(the registry starts at test/surface.ml:862 and ends at test/surface.ml:1892).
Each case is a source STRING, so no case adds a transcript block. Ten reuse
`m6c_twins` (test/surface.ml:804-815) and two reuse `m6c_expect_err_line`
(test/surface.ml:820-830):

1. `M7A-1 m7a_arg_global`: the `let*` A slot fills from `readStdin`.
2. `M7A-2 m7a_arg_global_str`: the s2 shape, `IO String`.
3. `M7A-3 m7a_arg_lambda_binder`: the s4 shape, the slot fills from `xs`.
4. `M7A-4 m7a_arg_match_binder`: the s5 shape, the slot fills from `t`.
5. `M7A-5 m7a_arg_match_binder_pred`: the s6 shape.
6. `M7A-6 m7a_arg_motive_branch`: the s7 shape, which also pins A4.
7. `M7A-7 m7a_infer_fence_arg`: the s3 shape, holed against explicit. This is
   pin 5 anchor 3 and it passes only through A3b.
8. `M7A-8 m7a_infer_lift`: the `infer-lift-holed` source against
   `infer-lift-explicit`, whose HEAD output is `eval : (IO (Option Json))`.
9. `M7A-9 m7a_infer_listeqby`: the `infer-listeqby-holed` source against
   `infer-listeqby-explicit`.
10. `M7A-10 m7a_infer_scrutinee`: the `arg-infer-holed` source against
    `arg-infer-explicit`. The hole sits in a match SCRUTINEE, which stays
    infer position after A4, so this case pins the settle and not A4.
11. `M7A-11 m7a_refuse_fence`: `m6c_expect_err_line` on the `infer-fenced`
    source with `1:13: hole: no expected type at this position`.
12. `M7A-12 m7a_refuse_undetermined`: `m6c_expect_err_line` on the
    `infer-undetermined` source with
    `1:14: hole: no expected type at this position`.

Case `M6C-5` is re-pointed at the exhausted source string in the same commit
(A7 item 3). It keeps its name, its helper and its pinned message
`2:8: hole: expected Type 0`, so the suite count moves by exactly 12, from
119 to 131.

### Review checklist

1. `surface/elab.ml` adds no exception: no `raise`, no `failwith`, no
   `assert`, and no `Option.get`. `rg -n 'raise|failwith|assert|Option\.get'
   /Users/oobi/Documents/tot/surface/elab.ml` prints nothing new.
2. No new `match` on an `Option` or a `Result` value. The new code uses
   `Option.map`, `Option.join`, `Option.value`, `Result.to_option`,
   `or_else` (elab.ml:17-19) and `unwrap_or` (elab.ml:23-25). Guard ladders
   use `match ()` with `when` arms, the shape the settle fold already uses
   (elab.ml:499-526).
3. Every new `match` on a `Syntax.t` or a `Term.t` lists its constructors.
   No wildcard arm anywhere, including the new `lib/check.ml` arm and the
   catch-all it was lifted out of (lib/check.ml:1208-1211).
4. No indexing operator and no `List.nth`. `local_ty` uses `List.nth_opt`,
   the shape `infer`'s Var arm already uses (lib/check.ml:940).
5. `locals` and `scope` are extended at the same sites, so the two lists
   stay aligned. Read each new binder arm and confirm one push per name.
6. The A3 guard `holed_leading_slot_unsettled` runs before any elaboration
   of a later argument, so on the A3 path a HEAD-green file performs no
   extra work and takes no new code path. The claim is scoped to A3, and
   item 7 carries the same claim for A4. Confirm by reading the guard, then
   by probe 4.
7. A4 changes branch bodies only when BOTH of its preconditions hold: the
   motive body ignores its `as` binder AND the branch body holds a
   `Syntax.SHole`. The hole precondition is what keeps a HEAD-green file off
   the A4 path, so read it as well as the occurs test.
   stdlib/prelude.tot:154-159 is green at HEAD and has the constant-motive
   shape, so the motive test alone would admit it. Confirm the dependent
   case still calls `term`, and confirm the hole-free case still calls
   `term`.
8. `lib/check.ml`'s new arm has the same body as the catch-all it left.
   Diff the two by eye. `define`'s `~rule` is still required and
   `type rule = Structural` still has one occurrence (probe 1).
9. The two re-opened gate legs and the re-pointed surface case (A7) keep
   their names and their assertion count. No leg was deleted.
10. The transcript diff shows exactly two changed blocks and the same block
    count (A8). `PASS-M6E-TRANSCRIPT-RESEALED` and
    `PASS-M5E-DEFAULT-IDENTITY` both pass.
11. `PASS-M5D-TIERS` literal was re-derived, not guessed, and the printed
    value is recorded in `dev/M7-BUILD-LOG.md`.
12. A3b adds ONE entry point and no traversal. `spine_infer` is reached
    only from `term`'s SApp arm, and `uncurry` (elab.ml:239-245) is the
    existing helper. Read the arm and confirm that the fallback
    `app_infer` builds `Term.App (Quantity.Many, f_t, a_t)`, the same node
    elab.ml:270 builds today.
13. A3b's activation test and family fence read the same way `spine` reads
    them (elab.ml:479-484 and elab.ml:80-83). Confirm by eye, then by probe
    3, whose `infer-fenced` leg must keep its HEAD line.
14. An unsettled hole in infer position still returns
    `Serror.Hole { loc; expected = None }` at the hole's own `loc`. Search
    the new code for `expected = Some` inside `spine_infer` and confirm
    there is none. Probe 3 and probe 7 both fail if the value changed.
15. `PASS-M7A-INFER-SETTLE-BUDGET` was run before and after the elaborator
    commit, and both runs printed
    `files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2`. Record both
    lines in `dev/M7-BUILD-LOG.md`.
16. Full `dev/gates.sh` run prints PASS 390 and no FAIL.

### Rollback

The stage is five independent reverts, in this order:

1. Revert the `dev/gates.sh` block, the `PASS-M5D-TIERS` literal, the three
   A7 leg repairs, the transcript reseal and the 12 suite cases. The tree is
   then back to 371 with the elaborator change still in place, which is a
   useful bisect point.
2. Revert A3b alone (the infer-path settle). `term`'s SApp arm goes back to
   the two lines at elab.ml:268-270, and `spine_infer` and `app_infer`
   leave with it. The rule then reaches six of the seven pin 5 anchors.
   `stdlib/prelude.tot:173` returns to
   `hole: no expected type at this position` and joins the explicit list,
   and probe 6 fails on its `s3-holed` leg. Nothing in check position
   moves, because A3b adds no code to `spine`. This is the cheapest partial
   rollback, and taking it re-opens the ruling the amendment of 2026-09-04
   closed, so it needs a new user ruling and not a builder decision.
3. Revert A4 alone (the constant-motive branch descent). The rule then
   reaches five shapes instead of six in check position, s7 returns to
   `hole: no expected type at this position`, and `stdlib/prelude.tot:159`
   joins the explicit list. Nothing else moves. Take this one if A4's
   occurs test proves unsound.
4. Revert A3, A2 and A1 together. `locals` is dead once A3 is gone, so all
   three must leave in one commit. A3b must already be gone, because
   `arg_caps` is its only capture source.
5. Revert A5 and A6, which are comment-level and arm-naming changes with no
   behaviour.

Steps 2, 3, 4 and 5 each leave the tree green at 371 after step 1, because
none of them changes a HEAD-green output.

Gate markers added: 7
Suite cases added: 12
Exit PASS count: 390

## STAGE B: the four guard A slots close and the retired negatives keep a tripwire (pins 5, 6, 11)

Verdict STAGE ALLOCATION, Stage B: "the two reachable guard slots and
the two pinned-explicit negatives.  New markers PASS-M7B-GUARD-ARG-HOLES
and PASS-M7B-ARG-SLOT-EXPLICIT, plus about 2 suite tests.
PASS-M6E-GUARD-HOLES has its literal edited from 22 to 24, which adds no
marker.  384 + 2 + 2 = 388."

That allocation is AMENDED by the Ratification amendment of 2026-09-04
and by the Stage A measurement it authorises.  The amended allocation:
all four guard A slots close, the second marker is renamed
PASS-M7B-LIFTIO-SLOT-CLOSES, the suite grows by three cases, and the
PASS-M6E-GUARD-HOLES literal walks 22 to 26.  Entry: Stage A green at
390.  Exit: 395.  Section B5.3 lists every number that moves and the
stage that owns it.

### B0. Goal

Stage A builds the argument-driven rule in check position and the settle
in infer position.  Stage B spends both on the operator's own files.  All
four guard type slots in `examples/guard.tot` and
`examples/guard-rewrap.tot` lose their explicit spelling and become
holes.

The verdict pinned two of those four slots as explicit-forever negatives.
The Stage A writer measured the two slots at HEAD, one measurement per
slot, and found that the settle reaches both.  The recorded reason for
their negative status stops being true.  Under the amendment a slot stays
a negative only with a true reason, so this stage retires both negatives
and records the retirement as an executable flip: each slot gets a
fixture that fails at HEAD and checks after the stage.

A retired negative leaves a hole in the oracle, so the stage replaces it.
One new negative fixture pins the shape the rule must NOT fill: a bind
whose every later argument is itself a hole.  That file refuses at HEAD
and refuses after the stage, with the same message, and it is what M8
inherits.

Stage B changes no kernel file and no elaborator file.  It edits four
corpus lines, lands three fixtures, adds three surface suite cases, adds
two gate legs and moves two gate literals.

### B1. Pins covered

Pin 5, verbatim from the verdict:

> Pin 5.  Honest reach, as a number: exactly seven of the nine A-bucket
> anchor sites resolve after Stage B.  The seven are stdlib/prelude.tot:17,
> :145, :159, :173, :176, examples/guard.tot:133 and
> examples/guard-rewrap.tot:264.  Testable: PASS-M7B-GUARD-ARG-HOLES and
> PASS-M7D-PRELUDE-HOLES.

Pin 6, verbatim from the verdict:

> Pin 6.  The two unreachable slots, examples/guard.tot:134 and
> examples/guard-rewrap.tot:265, stay explicit, and a holed copy of each
> must fail at exit 1 with `hole: expected Type 0`.  HEAD transcripts,
> which are the before picture for this pin:
>
>     $ tot.exe check j3b-guard-second-holed.tot
>     j3b-guard-second-holed.tot:3:8: hole: expected Type 0
>     exit=1
>
>     $ tot.exe check j3c-guard-first-holed.tot
>     j3c-guard-first-holed.tot:2:8: hole: expected Type 0
>     exit=1
>
> After Stage B the j3c shape must resolve and the j3b shape must keep the
> message above verbatim.  Testable: PASS-M7B-ARG-SLOT-EXPLICIT.

The Ratification amendment of 2026-09-04, verbatim, the clause that
governs this stage:

> Stage B re-derives whether the two guard slots pinned as
> explicit-forever negatives now close under the settle, and pins a slot as
> a negative only with a true reason.

RULING RECORD, pin 6.  The re-derivation is done and both slots close.
The evidence is the Stage A section, subsection A9, "REACH AGAINST THE
TWO STAGE B GUARD SLOTS", plus the six probes of B2 below, which this
section ran again at HEAD on 2026-09-04.  The reason the verdict recorded
for the two negatives was that the informative later argument is itself a
holed `liftIO _ (...)` that `surface/elab.ml:287-291` refuses at the
infer entry.  Stage A's A3b puts the settle in `term`, so that argument
now elaborates, and the chain that determines the slot is closed and
unique: `liftIO : (0 A : Type 0) -> Div A -> IO A`
(surface/bootstrap.ml:109), `jsonParse : String -> Div (Option Json)`
(surface/bootstrap.ml:147) with a closed codomain, and
`bindIO : (0 A : Type 0) -> (0 B : Type 0) -> IO A -> (A -> IO B) -> IO B`
(surface/bootstrap.ml:108), whose position 3 domain `IO A0` matches
`IO (Option Json)`.  No true reason remains, so pin 6's negative half is
RETIRED.  The pin is not deleted: its two slots move into
PASS-M7B-LIFTIO-SLOT-CLOSES, which pins the flip, and its refusal
obligation moves to the new undetermined fixture, which pins a shape the
rule must never fill.  Re-opening a tripwire's design is the M6 rule and
this is that move, not a deletion.

RULING RECORD, pin 6, the second wall.  The verdict also names the bare
lambda that `lib/check.ml:958-959` refuses with `Cannot_infer`.  That
wall is real at HEAD and is unchanged by M7.  It is not load-bearing for
these two slots, because the pinned slot is the FIRST `let*` type and the
measurements in B2 cover it with the continuation in place: probe P4 runs
the whole example file, lambda and all, and reports the hole at the
pinned slot alone.

RULING RECORD, pin 5.  Pin 5's list of seven anchors stands, and the
amendment says so in its own words: "pin 5 keeps its seven anchors".  Pin
5's word "exactly" does not stand.  Stage B closes FOUR of the nine
A-bucket anchor sites, the two named in pin 5 plus the two named in pin
6.  Stage D closes the remaining five, all in the prelude.  The reach at
the end of M7 is nine of nine, not seven of nine.  The number is
measured, not forecast: B2 probe P8 runs the classifier over a tree copy
with all four example slots re-spelled and prints 4 matching A sites and
26 holed anchors.

Pin 11, verbatim from the verdict, Stage B half:

> Pin 11.  The corpus holed-anchor literal walks 22 at HEAD, 24 after Stage
> B, 22 after the Stage D move, and the Stage D landed number after the
> prelude re-spell, which is 67 if all forty expected-type-only and all
> five argument-driven prelude anchors are re-spelled.  The
> prelude-carries-zero-holes assertion inside PASS-M6E-GUARD-HOLES flips at
> Stage D and is REPLACED by a prelude-holed floor, never deleted.
> Re-opening a tripwire's design is the M6 rule;  deleting a leg is
> forbidden.  Testable: PASS-M7B and PASS-M7D each edit the literal and the
> gate stays green at every stage boundary.

RULING RECORD, pin 11.  The walk is 22 at HEAD and 26 after Stage B, not
24, because four slots close here instead of two.  Every later number in
pin 11 moves by the same two.  B5.3 states the arithmetic and names Stage
D as its owner.  The flip of the prelude-carries-zero-holes assertion
stays at Stage D.  Stage B touches one literal only.

Stage B also obeys pin 1 (no kernel typing power; this stage touches no
file under lib/), pin 4 (the transcript reseals at Stage D and not
before), pin 12 (no new `gate_timed` leg, so PASS-M5D-MEASURE-LOG's
literal of 22 does not move) and pin 13 (the PASS-M7B-* namespace).

### B2. Entry state

Stage A leaves the tree with the argument-driven rule and the infer
settle live in the elaborator, the Stage A fixtures under `dev/m7a/`,
PASS-M7A-* green and the battery at 390.  Stage A makes no corpus edit,
so every row below still describes the tree Stage B starts from, except
that the rule now resolves the shapes marked "refused at HEAD".

Every row is a PROBE result, not a reading.  The runner is
`/Users/oobi/Documents/tot-m7-probes/amend/b-runner2.sh` through
`b-runner5.sh`, the binary is
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe` at HEAD 66b444f,
run 2026-09-04.  Rows are probe IDs local to this section, never pins.
Repo paths below are relative to `/Users/oobi/Documents/tot`.

| # | Probe | Command | Measured 2026-09-04 |
|---|---|---|---|
| P1 | the guard A slots at HEAD | `awk 'NR==133 || NR==134' examples/guard.tot` | `  let* String _ raw := readStdin in` and `  let* (Option Json) _ parsed := liftIO _ (jsonParse raw) in` |
| P2 | the rewrap A slots at HEAD | `awk 'NR==264 || NR==265' examples/guard-rewrap.tot` | the same two lines, byte for byte |
| P3 | HEAD on the re-spelled guard bytes | `tot.exe check <copy of guard.tot with :133 and :134 holed>` | exit 1, `guard-4holed.tot:133:8: hole: expected Type 0` |
| P4 | HEAD on the second guard slot ALONE | `tot.exe check <copy of guard.tot with :134 holed>` | exit 1, `guard-134-only.tot:134:8: hole: expected Type 0` |
| P5 | HEAD on the re-spelled rewrap bytes | `tot.exe check <copy of guard-rewrap.tot with :264 and :265 holed>` | exit 1, `guard-rewrap-4holed.tot:264:8: hole: expected Type 0` |
| P6 | HEAD on the second rewrap slot ALONE | `tot.exe check <copy of guard-rewrap.tot with :265 holed>` | exit 1, `guard-rewrap-265-only.tot:265:8: hole: expected Type 0` |
| P7 | holed anchors at HEAD | `python3 dev/hole-anchors.py \| rg -c 'anchor=\[_\]'` | 22 |
| P8 | holed anchors over the re-spelled tree copy | same, against the copy | 26 |
| P9 | the ANCHORS line over the re-spelled tree copy | `python3 dev/hole-anchors.py \| tail -1` | `ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30`, unchanged |
| P10 | the four A sites after the re-spell | `rg -c 'SITE examples/guard(-rewrap)?\.tot:(133\|134\|264\|265) head=bindIO arg=0 anchor=\[_\] pos=check bucket=A'` | 4 over the copy, no match and exit 1 at HEAD |
| P11 | the bucket of the two pin 6 sites at HEAD | `python3 dev/hole-anchors.py \| rg 'guard\.tot:134 head=bindIO arg=0'` | `anchor=[Option Json] pos=check bucket=A`, so both are A anchors and not E |
| P12 | the both-slots fixture | `tot.exe check m7b-guard-arg-slots.tot` | exit 1, `:8:8: hole: expected Type 0` |
| P13 | the liftIO-slot fixture | `tot.exe check m7b-liftio-slot.tot` | exit 1, `:8:8: hole: expected Type 0` |
| P14 | the undetermined negative fixture | `tot.exe check m7b-arg-slot-undetermined.tot` | exit 1, `:7:8: hole: expected Type 0` |
| P15 | corpus files against transcript blocks | `ls examples/*.tot test/fixtures/*.tot \| wc -l` and `rg -c '^### ' dev/m5e-default-transcript.txt` | 101 and 101 |
| P16 | a fixtures SUBDIRECTORY against the same glob | `ls <scratch>/fixtures/*.tot \| wc -l` with `a.tot` beside `m7/b.tot` | 1 |
| P17 | direct watchdog tier calls | `rg -c '"\$watchdog" "\$(FAST\|MED\|SLOW\|SUITE)"' dev/gates.sh` | 169 |
| P18 | the M7 marker namespace | `rg -c 'PASS-M7' dev/gates.sh` | no match, exit 1 |
| P19 | the guard deny envelope | `tot.exe run examples/guard.tot < test/fixtures/deny.json` | exit 2, the one-line deny envelope pinned at dev/gates.sh:3092 |
| P20 | the guard stdout at HEAD | `tot.exe check examples/guard.tot \| wc -l` and `\| tail -1` | 10 and `def main : (IO Verdict)` |

P3 through P6 are the stage's own before picture: the HEAD binary REFUSES
the exact bytes this stage lands, at the exact line and column of each
edit.  P4 and P6 are the two measurements the amendment asks for, one per
pinned-negative slot, each taken on the whole example file so the
continuation and the match arms are present.  P8 is pin 11's number
derived before the stage rather than asserted.

Counts, each with its reproducing command (graft G8: the command must
print the number), all run 2026-09-04 at HEAD:

    python3 dev/hole-anchors.py | rg -c 'anchor=\[_\]'        # 22
    ls examples/*.tot test/fixtures/*.tot | wc -l             # 101
    rg -c '^### ' dev/m5e-default-transcript.txt              # 101
    rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh  # 169
    rg -c 'PASS-M7' dev/gates.sh                              # no match, exit 1

The two gate literals this stage edits, each with the command that
derives it at HEAD and the value that command printed:

    rg -n 'm6e_holes" -eq' dev/gates.sh
    # 3094:  && [ "$m6e_holes" -eq 22 ] && [ "$m6e_pz" -eq 1 ] \
    rg -n 'm5d_tiers" -eq' dev/gates.sh
    # 2284:{ [ "$m5d_nolit" -eq 1 ] && [ "$m5d_tiers" -eq 169 ] && [ "$m5d_bites" -eq 2 ] \

### B3. Files touched

| Path | What changes |
|---|---|
| `examples/guard.tot` | lines 133 and 134: the A slot of each `let*` becomes `_` |
| `examples/guard-rewrap.tot` | lines 264 and 265: the same two edits |
| `test/fixtures/m7/m7b-guard-arg-slots.tot` | NEW, the both-slots positive for the corpus shape |
| `test/fixtures/m7/m7b-liftio-slot.tot` | NEW, the retired pin 6 slot, alone |
| `test/fixtures/m7/m7b-arg-slot-undetermined.tot` | NEW, the negative that replaces the retired ones |
| `test/surface.ml` | three source strings and three `cases` entries, M7B-1, M7B-2 and M7B-3 |
| `dev/gates.sh` | one new M7 Stage B block with two legs; PASS-M6E-GUARD-HOLES literal 22 to 26 at line 3094 plus a dated comment sentence; PASS-M5D-TIERS literal raised by exactly 6 at line 2284 |
| `SPEC.md` | one dated decision-log entry at the end of section 2, before the section 3 heading at SPEC.md:1578 |
| `dev/M7-BUILD-LOG.md` | the Stage B record, in the subsection shape of dev/M6-BUILD-LOG.md:475-728 |

Nothing under `lib/`, nothing under `surface/`, nothing under `bin/`.

The three fixtures land in a SUBDIRECTORY, `test/fixtures/m7/`, and this
is a deliberate placement.  `dev/gen-m5e-transcript.sh:13` walks
`examples/*.tot test/fixtures/*.tot`, and `dev/gates.sh:3129` counts the
same glob against the sealed transcript's block count.  A new
`test/fixtures/*.tot` file therefore forces a transcript reseal, which is
what M6 Stage H paid when its two fence fixtures moved the block count 99
to 101 (SPEC.md:1565-1570).  Pin 4 reseals the transcript at Stage D and
not before, so Stage B keeps its fixtures out of the glob.  P16 measures
that a subdirectory does not enter it.  The M6 Stage B alternative,
generating the fixture into the gate scratch dir (dev/gates.sh:2529-2537),
was rejected here for one reason: the undetermined negative is what M8
inherits, and an inherited tripwire must be a file on disk.
`dev/hole-anchors.py` excludes test fixtures from its corpus (its lines
13-15), so the new files move no anchor count.

### B4. Design

#### B4.1  The four slots that close

`examples/guard.tot:132-134` at HEAD reads:

```
def main : IO Verdict :=
  let* String _ raw := readStdin in
  let* (Option Json) _ parsed := liftIO _ (jsonParse raw) in
```

Lines 133 and 134 become:

```
  let* _ _ raw := readStdin in
  let* _ _ parsed := liftIO _ (jsonParse raw) in
```

`examples/guard-rewrap.tot:263-265` carries the same three lines and
takes the same two edits at lines 264 and 265.  The B slot of each bind
is already a hole at HEAD, filled by the M6 expected-type rule;  the
classifier writes it as `head=bindIO arg=1 anchor=[_] pos=check
bucket=E`.  The `liftIO _` slot is already a hole too, written as
`head=liftIO arg=0 anchor=[_] pos=check bucket=E`.  What moves is the
`arg=0` slot of each bind, which the classifier writes as bucket A (P11).

Why the first A slot resolves.  `bindIO`'s third argument on line 133 is
`readStdin`, which infers `IO String`.  Pin 3's rule matches that
head-normal form against the declared formal type of `bindIO`
(surface/bootstrap.ml:108) by first-order matching and determines the
leading erased slot as `String`.  This is the same shape as the judge's
smallest case, `map _ Nat (fun n => n) (nil Nat)`, and Stage A builds it.

Why the second A slot resolves.  `bindIO`'s third argument on line 134 is
`liftIO _ (jsonParse raw)`.  At HEAD that argument is refused at the
infer entry, `surface/elab.ml:287-291`, which returns
`Error (Serror.Hole { loc; expected = None })`, so the capture walk gets
nothing to match.  Stage A's A3b settles that inner hole from
`jsonParse : String -> Div (Option Json)` (surface/bootstrap.ml:147),
whose codomain is closed, so the local `raw` cannot change it.  The
argument then infers `IO (Option Json)`, position 3 of `bindIO` matches
`IO A0`, and the pinned slot settles to `(Option Json)`.  Both parts are
needed and in this order: A3b first, then the argument-driven rule.

Stage B adds no elaborator code.  The four edits are source, and the
rules that read them are already in the binary at Stage B entry.

Why the edits are observable.  P3 through P6 ran the HEAD binary over
byte copies of exactly these edited files.  The four-slot copies fail at
the FIRST holed slot, `guard.tot:133:8` and `guard-rewrap.tot:264:8`, and
the single-slot copies fail at `guard.tot:134:8` and
`guard-rewrap.tot:265:8`, all exit 1.  So the edits are not cosmetic: at
HEAD they break the corpus, and only the Stage A rules make it check.

Why the edits are invisible in output.  Pin 2 is conservativity: a hole
is elaborator abbreviation, resolved before any kernel term is built, so
`tot.exe check examples/guard.tot` prints the same ten lines it printed
at HEAD (P20) and the guard's deny envelope stays byte-identical (P19).
The sealed transcript block for `examples/guard.tot`
(dev/gates.sh:3130-3131) is the enforcement point, and it must NOT move
at this stage.  PASS-M5E-DEFAULT-IDENTITY is the leg that sees a drift.

#### B4.2  The negative that replaces the two retired ones

The verdict's oracle spent two fixtures on the claim that
`examples/guard.tot:134` and `examples/guard-rewrap.tot:265` can never
resolve.  That claim is false after Stage A, so the two fixtures would
pin nothing.  The budget moves to the claim that survives: the rule fills
a slot only when a later argument DETERMINES it.

`test/fixtures/m7/m7b-arg-slot-undetermined.tot` is that fixture.  Its
bind reads `let* _ Verdict parsed := liftIO _ _ in`.  Every later
argument is itself a hole, so no rigid match fires, no settle fires, and
the leading slot keeps HEAD's error.  It is the twin of Stage A's
`dev/m7a/arg-exhausted.tot`, and the duplication is deliberate: the Stage
A copy proves the rule, the Stage B copy is the one on disk under
`test/fixtures/`, which is what M8 inherits.

At HEAD the file exits 1 with `7:8: hole: expected Type 0` (P14).  After
the stage it exits 1 with the same message.  Its explicit twin, the same
bind with `(Option Json)` in the slot and `liftIO (Option Json)
(jsonParse "{}")` as the value, exits 0 at HEAD and prints
`def probeGuardNone : (IO Verdict)`, which proves the program is
otherwise well typed and that the refusal is the hole and not the shape.

The reason text for the RETIREMENT appears in three places, in these
words: the header of `m7b-liftio-slot.tot`, the comment above the
PASS-M7B-LIFTIO-SLOT-CLOSES leg in dev/gates.sh, and the SPEC.md
decision-log entry of B4.5.  Each names the Ratification amendment of
2026-09-04 and the Stage A measurement, and none of them says "the settle
is out of M7".

#### B4.3  The three fixtures, exact bytes

`test/fixtures/m7/m7b-guard-arg-slots.tot`:

```
-- M7 Stage B (pins 5, 6, 11): the POSITIVE control for the corpus
-- shape this stage lands.  Both let-star A slots are holes.  The
-- first reads its type from readStdin.  The second reads its type
-- from liftIO _ (jsonParse raw), which the Stage A infer settle
-- fills from jsonParse : String -> Div (Option Json)
-- (surface/bootstrap.ml:147).  This file exits 1 at HEAD.
def main : IO Verdict :=
  let* _ _ raw := readStdin in
  let* _ _ parsed := liftIO _ (jsonParse raw) in
  match parsed with
  | none => pureIO _ allow
  | some payload => pureIO _ allow
  end
```

`test/fixtures/m7/m7b-liftio-slot.tot`:

```
-- M7 Stage B (pin 6, amended): the slot the verdict pinned as an
-- explicit-forever negative.  The Stage A infer settle reaches it, so
-- the negative is RETIRED and this file records the flip: exit 1 at
-- HEAD, exit 0 after the stage.  The first slot stays explicit, so
-- this file isolates the second slot alone.
def main : IO Verdict :=
  let* String _ raw := readStdin in
  let* _ _ parsed := liftIO _ (jsonParse raw) in
  match parsed with
  | none => pureIO _ allow
  | some payload => pureIO _ allow
  end
```

`test/fixtures/m7/m7b-arg-slot-undetermined.tot`:

```
-- M7 Stage B (pin 6, amended): the tripwire that replaces the two
-- retired negatives.  Every later argument of the bind is itself a
-- hole, so no later argument determines the leading slot and the
-- Stage A rule must leave it alone.  Exit 1 at HEAD and exit 1 after
-- the stage, with the same message.
def probeG : IO Verdict :=
  let* _ Verdict parsed := liftIO _ _ in
  pureIO Verdict allow
```

The header lengths fix the reported positions.  The two positives report
at `8:8` and the negative at `7:8`, all measured at HEAD (P12, P13, P14).
The two positives carry the guard's own let-star shape and its match
arms, not a reduced one, so each reaches the same `bindIO` spine the
corpus lines reach.

#### B4.4  The three surface suite cases

`test/surface.ml` gains three source strings next to the M6C block
(`m6c_expect_err_line` at test/surface.ml:820-830, `m6c_flagged_holed` at
test/surface.ml:832) and three `cases` entries appended to the list that
opens at test/surface.ml:862 and closes at test/surface.ml:1892.  The
suite prints one `PASS <name>` line per entry (test/surface.ml:1913),
which is how the battery counts them, so the three entries are worth
exactly three PASS lines.

The in-process sources carry no file prefix, so the wanted error line is
`L:C: ...` alone, and each source names its own definition so that two
entries never declare the same global:

```ocaml
(* M7 Stage B (plan B4.4): the guard let-star A slots, the three
   shapes the milestone separates.  [m7b_both_src] is
   examples/guard.tot:133-134 after the re-spell.  [m7b_lift_src] is
   the slot pin 6 called explicit-forever, alone;  the Stage A infer
   settle reaches it (Ratification amendment 2026-09-04), so it
   resolves.  [m7b_none_src] is the shape the rule must NOT fill. *)
let m7b_both_src : string =
  "def probeGuardBoth : IO Verdict :=\n\
  \  let* _ _ raw := readStdin in\n\
  \  let* _ _ parsed := liftIO _ (jsonParse raw) in\n\
  \  match parsed with\n\
  \  | none => pureIO _ allow\n\
  \  | some payload => pureIO _ allow\n\
  \  end\n"

let m7b_lift_src : string =
  "def probeGuardLift : IO Verdict :=\n\
  \  let* String _ raw := readStdin in\n\
  \  let* _ _ parsed := liftIO _ (jsonParse raw) in\n\
  \  match parsed with\n\
  \  | none => pureIO _ allow\n\
  \  | some payload => pureIO _ allow\n\
  \  end\n"

let m7b_none_src : string =
  "def probeGuardNone : IO Verdict :=\n\
  \  let* _ Verdict parsed := liftIO _ _ in\n\
  \  pureIO Verdict allow\n"
```

The three entries, appended before the closing bracket at
test/surface.ml:1892:

```ocaml
    (* M7 Stage B (plan B4.4): pins 5 and 6, the guard slot posture
       after the 2026-09-04 amendment, in the suite that runs in
       process. *)
    ( "M7B-1 m7b_guard_arg_slots: both guard let* A slots read their types from the later \
       argument, so the re-spelled pair checks and prints the guard's own line",
      expect_lines_check ~st:bst m7b_both_src [ "def probeGuardBoth : (IO Verdict)" ] );
    ( "M7B-2 m7b_liftio_slot: the second guard slot, which pin 6 pinned as explicit-forever, \
       closes under the infer settle and prints its line",
      expect_lines_check ~st:bst m7b_lift_src [ "def probeGuardLift : (IO Verdict)" ] );
    ( "M7B-3 m7b_arg_slot_undetermined: every later argument is itself a hole, so the leading \
       slot keeps the HEAD message and the rule fills nothing",
      m6c_expect_err_line bst m7b_none_src "2:8: hole: expected Type 0" );
```

Both helpers exist at HEAD: `expect_lines_check` (test/surface.ml:23) and
`m6c_expect_err_line` (test/surface.ml:820-830), which folds the
`Run.script` result with `Result.fold` and guards its comparison with a
`match ()` arm.  No new helper, no exception, no match on an Option or a
Result, so the house style needs nothing from this stage.

The three literals are measured, not copied.  Run as files at HEAD, the
three sources report `2:8: hole: expected Type 0`, `3:8: hole: expected
Type 0` and `2:8: hole: expected Type 0`, all exit 1.  Their explicit
twins exit 0 at HEAD and print `def probeGuardBoth : (IO Verdict)`,
`def probeGuardLift : (IO Verdict)` and `def probeGuardNone : (IO
Verdict)`.  M7B-1 and M7B-2 therefore flip from red to green at this
stage, and M7B-3 is green at HEAD and stays green.

#### B4.5  The SPEC.md decision-log entry

One dated entry, appended at the end of section 2, immediately before the
section 3 heading at SPEC.md:1578, in the shape of the entry that ends at
SPEC.md:1556-1577.  It states: all four example A slots are re-spelled;
pin 6's two negatives are RETIRED with the Stage A measurement that
retires them; the replacement negative and what it pins; the two walls
that remain real at HEAD but no longer hold these slots
(surface/elab.ml:287-291 for the infer entry, lib/check.ml:958-959 for
the bare lambda); the Ratification amendment of 2026-09-04; and the holed
literal walking 22 to 26.

The entry carries NO `ANCHORS` line and does not spell
`expected-type-only=`.  PASS-M5D-MEASURE-LOG compares the gate log's
spelling with the textually LAST spelling in SPEC.md, which it reads
through `| tail -n 1` at dev/gates.sh:3015, and that spelling sits at
SPEC.md:2123.  A new entry in section 2 is textually above it, and Stage
B emits no anchors line at all, so the leg stays green with no literal
change.  P9 confirms the ANCHORS numbers do not move.

SPEC.md:2127-2130 says the four guard A anchors are "kept explicit".
Stage B makes that sentence false.  Stage B does NOT edit it, because
Stage E already owns that passage for its citation repair (the same
sentence spells the rewrap slots as `253-254`, which is wrong at HEAD;
the lines are 264 and 265).  Stage B's SPEC entry names the passage and
says it is superseded, and B5.3 records the repair as Stage E's, so no
two stages edit the same lines.

### B5. Gate additions

Two probes, one per new marker.  Both run against
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe`, absolute paths,
no cd.

    Marker: PASS-M7B-GUARD-ARG-HOLES
    Pin: 5, 11
    Command: /bin/zsh -c 'H=$(python3 /Users/oobi/Documents/tot/dev/hole-anchors.py); printf "HOLED=%s ASLOTS=%s\n" "$(printf "%s\n" "$H" | rg -c "anchor=\[_\]")" "$(printf "%s\n" "$H" | rg -c "SITE examples/guard(-rewrap)?\.tot:(133|134|264|265) head=bindIO arg=0 anchor=\[_\] pos=check bucket=A"; true)"'
    At HEAD: exit 0, output contains "HOLED=22 ASLOTS="
    After stage: exit 0, output contains "HOLED=26 ASLOTS=4"
    Non-vacuous because: at HEAD all four A slots are spelled `String` or
      `(Option Json)` (P1, P2), so the classifier writes no holed A anchor
      at any of the four lines and the second count is EMPTY, not zero;
      the same command over a tree copy with only those four lines
      re-spelled printed `HOLED=26 ASLOTS=4` (P8, P10), so both halves of
      the assertion move together and only these four edits move them.

    Marker: PASS-M7B-LIFTIO-SLOT-CLOSES
    Pin: 6
    Command: /bin/zsh -c 'T=/Users/oobi/Documents/tot; X=$T/_build/default/bin/tot.exe; for f in m7b-guard-arg-slots m7b-liftio-slot m7b-arg-slot-undetermined; do o=$($X check $T/test/fixtures/m7/$f.tot 2>&1); printf "%s exit=%d %s\n" $f $? "${o##*/}"; done'
    At HEAD: exit 0, output contains "m7b-liftio-slot exit=1 m7b-liftio-slot.tot: no such file"
    After stage: exit 0, output contains "m7b-liftio-slot exit=0 def main : (IO Verdict)" and "m7b-arg-slot-undetermined exit=1 m7b-arg-slot-undetermined.tot:7:8: hole: expected Type 0"
    Non-vacuous because: the three repo paths do not exist at HEAD, so the
      exact command prints `no such file` on all three, and the same
      command over byte-identical copies at
      /Users/oobi/Documents/tot-m7-probes/amend/b/ printed
      `exit=1 <name>.tot:8:8: hole: expected Type 0` twice and
      `exit=1 <name>.tot:7:8: hole: expected Type 0` once (P12, P13, P14);
      the leg prints the MESSAGE next to each exit code, so a fixture that
      goes missing reads red instead of green, and the negative must hold
      its message while the two positives flip.

#### B5.1  The gates.sh block, verbatim

Placement: a new block after the M6 Stage E block's last leg,
PASS-M6E-TRANSCRIPT-RESEALED (dev/gates.sh:3116-3139), and BEFORE the
ctxcat id 5 comment at dev/gates.sh:3141 and the two timing-sensitive
branching legs (PASS-M4FIX-INST-BRANCHING at 3172-3176 and
PASS-M5B-BRANCHING-20 at 3190-3195), which stay the file's tail.  The
block adds no scratch and no `gate_timed` call: it reuses `$m5d_bin`,
`$m5d_scratch/hole-sites.txt` and `$fx` (dev/gates.sh:444, 2225-2226,
2233-2235), and the EXIT trap at the top of the file already owns the
cleanup.  Every leg names a tier, and each marker is emitted by an `echo
PASS-...` on the success arm with a `FAIL-...` replay plus `exit 1` on the
other, which is the file's convention (dev/gates.sh:3093-3098).

```zsh
# ---------------------------------------------------------------------
# M7 Stage B (verdict pins 5, 6, 11): all FOUR guard A slots are
# re-spelled as holes.  Pin 6 pinned two of them as explicit-forever
# negatives, on the recorded reason that the informative later
# argument is itself the holed `liftIO _ (...)` which
# surface/elab.ml:287-291 refuses at the infer entry.  Stage A's
# infer settle elaborates that argument, so the recorded reason is no
# longer true and the two negatives are RETIRED (Ratification
# amendment 2026-09-04: a slot stays a negative only with a true
# reason).  Measured at HEAD before the stage: each slot alone,
# re-spelled in its own file, exits 1 at `134:8` and `265:8` with
# `hole: expected Type 0` (plan B2 P4, P6).  The refusal obligation
# moves to m7b-arg-slot-undetermined.tot, whose every later argument
# is a hole, so nothing determines the slot.  Deleting that negative
# leg is forbidden; re-opening its design is the M6 rule.  Mutation
# proofs in dev/M7-BUILD-LOG.md.
# ---------------------------------------------------------------------

# PASS-M7B-GUARD-ARG-HOLES (pins 5, 11).  Five assertions: both
# guards still check at exit 0; the classifier's site list shows all
# FOUR A slots HOLED (guard.tot:133-134 and guard-rewrap.tot:264-265,
# bucket A, which an un-respelled tree cannot show); the corpus
# holed-anchor literal is 26 (22 at HEAD, plan B2 P7/P8); and the deny
# envelope on the M3 payload is byte-identical to the pre-respell
# envelope, so the re-spell changed no behaviour.
m7b_g1=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard.tot 2>&1); m7b_c1=$?
m7b_g2=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard-rewrap.tot 2>&1); m7b_c2=$?
m7b_slots=$(rg -c 'SITE examples/guard(-rewrap)?\.tot:(133|134|264|265) head=bindIO arg=0 anchor=\[_\] pos=check bucket=A' "$m5d_scratch/hole-sites.txt")
m7b_holed=$(rg -c 'anchor=\[_\]' "$m5d_scratch/hole-sites.txt")
m7b_env=$("$watchdog" "$FAST" "$m5d_bin" run "$ROOT"/examples/guard.tot \
  < "$fx"/deny.json); m7b_c3=$?
m7b_wantenv='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo /tmp/x)"}}'
{ [ "$m7b_c1" -eq 0 ] && [ "$m7b_c2" -eq 0 ] \
  && [ "$m7b_slots" -eq 4 ] && [ "$m7b_holed" -eq 26 ] \
  && [ "$m7b_c3" -eq 2 ] && [ "$m7b_env" = "$m7b_wantenv" ]; } \
  && echo PASS-M7B-GUARD-ARG-HOLES \
  || { printf '%s\n%s\n%s\n' "$m7b_g1" "$m7b_g2" "$m7b_env"; \
       echo "FAIL-M7B-GUARD-ARG-HOLES (c=$m7b_c1/$m7b_c2 slots=$m7b_slots holed=$m7b_holed env=$m7b_c3)"; exit 1; }

# PASS-M7B-LIFTIO-SLOT-CLOSES (pin 6, amended).  The retired negative
# and its replacement.  The two positives pin the WHOLE stdout line,
# and the negative pins the WHOLE message line, so a fixture that goes
# missing (exit 1 with `no such file`) reads as red here instead of
# green.  m7b-liftio-slot.tot is the pin 6 shape with the FIRST slot
# left explicit: it isolates the slot the verdict called unreachable,
# which is what makes the retirement executable rather than an
# opinion.
m7b_p1=$("$watchdog" "$FAST" "$m5d_bin" check \
  "$ROOT"/test/fixtures/m7/m7b-guard-arg-slots.tot 2>&1); m7b_c4=$?
m7b_p2=$("$watchdog" "$FAST" "$m5d_bin" check \
  "$ROOT"/test/fixtures/m7/m7b-liftio-slot.tot 2>&1); m7b_c5=$?
m7b_n1=$("$watchdog" "$FAST" "$m5d_bin" check \
  "$ROOT"/test/fixtures/m7/m7b-arg-slot-undetermined.tot 2>&1); m7b_c6=$?
m7b_wn="$ROOT/test/fixtures/m7/m7b-arg-slot-undetermined.tot:7:8: hole: expected Type 0"
{ [ "$m7b_c4" -eq 0 ] && [ "$m7b_p1" = 'def main : (IO Verdict)' ] \
  && [ "$m7b_c5" -eq 0 ] && [ "$m7b_p2" = 'def main : (IO Verdict)' ] \
  && [ "$m7b_c6" -eq 1 ] && [ "$m7b_n1" = "$m7b_wn" ]; } \
  && echo PASS-M7B-LIFTIO-SLOT-CLOSES \
  || { printf '%s\n%s\n%s\n' "$m7b_p1" "$m7b_p2" "$m7b_n1"; \
       echo "FAIL-M7B-LIFTIO-SLOT-CLOSES (c=$m7b_c4/$m7b_c5/$m7b_c6)"; exit 1; }
```

`rg -c` prints nothing and exits 1 when it finds no match, so an
un-respelled tree leaves `$m7b_slots` EMPTY and the `[ ... -eq 4 ]` test
falls to the FAIL arm.  That is the M6E leg's own behaviour at
dev/gates.sh:3088 and the file runs without `set -e`, so the FAIL arm is
reached and the marker is not printed.

#### B5.2  The two literal edits

PASS-M6E-GUARD-HOLES, dev/gates.sh:3094: `[ "$m6e_holes" -eq 22 ]` becomes
`[ "$m6e_holes" -eq 26 ]`.  Its comment (dev/gates.sh:3076-3084) gains one
dated sentence naming the four new holed sites and re-stating the
arithmetic the comment already spells: 19 re-spelled M6 sites, plus the
scrubber's three, plus the four A slots of this stage.  The
prelude-carries-zero-holes assertion at dev/gates.sh:3089 stays exactly as
it is: pin 11 flips it at Stage D, not here.  The two markers now assert
the same holed literal from two angles, which is deliberate: the M6E leg
owns the corpus total, the M7B leg owns which sites carry it.

PASS-M5D-TIERS, dev/gates.sh:2284: the block adds SIX direct
watchdog-plus-tier uses (three per leg).  In the SAME commit, run
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before the
gates.sh edit and after, and raise the literal by EXACTLY six from the
measured entry value.  At HEAD the count is 169 (P17);  Stage A raises it
by its own legs, so the entry value for Stage B is whatever Stage A left,
and the arithmetic is entry plus six.  Both numbers go into
dev/M7-BUILD-LOG.md.  Without this edit the battery cannot reach
GATE-EXIT=0 at the Stage B boundary and the monotone walk breaks.

No leg in this block uses `gate_timed`, so PASS-M5D-MEASURE-LOG's literal
of 22 lines (dev/gates.sh:3016) and its pinned name set
(dev/gates.sh:3009) do not move.

#### B5.3  Deltas this amendment creates, and who owns each

| Delta | Old value | New value | Owner |
|---|---|---|---|
| corpus lines edited in Stage B | 2 | 4 | Stage B |
| PASS-M6E-GUARD-HOLES literal after Stage B | 24 | 26 | Stage B, dev/gates.sh:3094 |
| second Stage B marker | PASS-M7B-ARG-SLOT-EXPLICIT | PASS-M7B-LIFTIO-SLOT-CLOSES | Stage B |
| Stage B suite cases | 2 | 3 | Stage B |
| Stage B entry and exit PASS | 384 and 388 | 390 and 395 | Stage B |
| A-bucket sites closed by the end of M7 | 7 of 9 | 9 of 9 | Stage B and Stage D |
| pin 11's landed holed-anchor number at the M7 exit | 67 | 69 | Stage D re-derives it from a classifier run |
| SPEC.md:2127-2130 "kept explicit" clause | stale line numbers only | stale line numbers AND a false claim | Stage E, with its citation repair |

The pin 11 exit number is the only delta Stage B cannot measure itself,
because it depends on the prelude re-spell.  Stage B therefore states the
rule and not the number: the M7 exit literal is the Stage B literal plus
the prelude sites Stage D re-spells, and Stage D derives it with
`python3 dev/hole-anchors.py | rg -c 'anchor=\[_\]'` on the re-spelled
tree before it writes the literal.  Stage B's own contribution to that
sum is 26, measured (P8).

### B6. Review checklist

1. `dunecho build` green, then the full battery from a clean run:
   GATE-EXIT=0, 0 FAIL, PASS at the Stage B target of 395.
2. The diff touches the nine paths of B3 and nothing else.  `git status
   --porcelain` shows no stray file, and no path under `lib/`,
   `surface/` or `bin/` appears.
3. `awk 'NR==133 || NR==134' examples/guard.tot` prints
   `  let* _ _ raw := readStdin in` and
   `  let* _ _ parsed := liftIO _ (jsonParse raw) in`, and
   `awk 'NR==264 || NR==265' examples/guard-rewrap.tot` prints the same
   two lines.
4. `python3 dev/hole-anchors.py | rg -c 'anchor=\[_\]'` prints 26, and
   `python3 dev/hole-anchors.py | tail -1` prints the HEAD line
   unchanged: `ANCHORS total=101 expected-type-only=62 argument-driven=9
   neither=30`.  Stage B moves no bucket.
5. `ls examples/*.tot test/fixtures/*.tot | wc -l` still prints 101 and
   `rg -c '^### ' dev/m5e-default-transcript.txt` still prints 101.  The
   transcript is NOT resealed at this stage (pin 4), and
   PASS-M5E-DEFAULT-IDENTITY is green, which is the proof that the
   re-spell changed no printed byte.
6. `tot.exe check examples/guard.tot | wc -l` prints 10 and its last line
   is `def main : (IO Verdict)`, the same as at HEAD (P20).
7. Both new markers appear exactly once as an `echo PASS-...` line, and
   `rg -c 'PASS-M7B' dev/gates.sh` counts those two echoes plus their
   comment mentions.  `rg -c 'PASS-M7B-ARG-SLOT-EXPLICIT' dev/gates.sh`
   finds nothing: the retired name lands nowhere.
8. The surface suite grows by exactly three PASS lines, M7B-1, M7B-2 and
   M7B-3, and the kernel suite count does not move.
9. PASS-M5D-TIERS is green at entry plus six, with both measured numbers
   in dev/M7-BUILD-LOG.md.  PASS-M5D-MEASURE-LOG is green with no literal
   change.
10. Three mutation proofs run and are logged, each restored `md5 -q`
    identical:
    (a) revert `examples/guard.tot:134` to `(Option Json)`.  Expect
    PASS-M6E-GUARD-HOLES red on the holed literal (25, not 26) and
    PASS-M7B-GUARD-ARG-HOLES red with `slots=3 holed=25`.  This is the
    proof that the retired negative's slot is really carried by the leg.
    (b) revert `examples/guard.tot:133` to `String`.  Expect
    PASS-M7B-GUARD-ARG-HOLES red with `slots=3 holed=25` and every other
    leg green, which proves the leg bites on the SITE, not on the total.
    (c) re-spell the undetermined fixture's value to
    `liftIO _ (jsonParse "{}")`.  Expect PASS-M7B-LIFTIO-SLOT-CLOSES red
    with `c=0/0/0`, because the settle then fills the slot.  This is the
    proof that the replacement negative is a real wall and not a shape
    the rule happens to ignore.
11. The retirement sentence for pin 6 reads the same in the
    `m7b-liftio-slot.tot` header, in the gates.sh block comment and in
    the SPEC.md entry, and names the Ratification amendment of
    2026-09-04.  No file says the settle is out of M7.
12. The user commits.  Nothing lands committed by an agent.

### B7. Risk, and rollback

RISK.  Stage B rests on a Stage A property that no binary can show
before Stage A is built: that the settle plus the argument-driven rule
close `examples/guard.tot:134` and `examples/guard-rewrap.tot:265`.  The
HEAD evidence is one-sided by construction.  It shows the slots fail at
HEAD for the recorded reason, and it shows the determining chain is
closed and unique (B4.1, steps from surface/bootstrap.ml:108, :109 and
:147).  If the built rule does not close them, the response is recorded
here and needs no new ruling: revert the `:134` and `:265` edits, keep
the `:133` and `:264` edits, restore pin 6 with the reason the failed
build measures, rename the second marker back to
PASS-M7B-ARG-SLOT-EXPLICIT with the two negative fixtures, and set the
PASS-M6E-GUARD-HOLES literal to 24.  The stage then exits at 394 with two
suite cases and the same two markers.  Record the fallback in
dev/M7-BUILD-LOG.md with the message the build printed.

ROLLBACK.  Stage B is one commit and reverts as one.  From a clean tree:

    git -C /Users/oobi/Documents/tot checkout -- examples/guard.tot \
      examples/guard-rewrap.tot test/surface.ml dev/gates.sh SPEC.md
    rm -rf /Users/oobi/Documents/tot/test/fixtures/m7

Then rebuild and run the battery: it returns to the Stage A count of 390,
with PASS-M6E-GUARD-HOLES back on its literal of 22 and PASS-M5D-TIERS
back on its entry value.  No other stage depends on Stage B's artifacts
except Stage D, which edits the same two gate literals again;  a Stage B
rollback after Stage D lands is not a revert of this commit alone and
must re-derive both literals from a fresh classifier run.  The transcript
is untouched by this stage, so no reseal has to be undone.

Gate markers added: 2
Suite cases added: 3
Exit PASS count: 395

## STAGE C: multi-hole tail reporting (pins 7, 8)

Goal: report every other hole position of a failing definition on one
extra stderr line, in the position-only tail shape the user ratified
at open question 2.  The first hole keeps its M6 line byte for byte.
`Serror.t` does not change.  No partial term is built.  No new pass
over parsed items or terms runs, not even a syntactic fold on the
failed path.  The exit code does not move.  The stage adds two gate
markers and five surface suite cases, and it changes no output of any
file that checks green today.

Entry: 395 PASS / 0 FAIL, GATE-EXIT=0, at the Stage B boundary.
These are the numbers of the Ratification amendment of 2026-09-04.
Stage A landed the argument-driven settle pass on the check path and on
the infer path, with seven PASS-M7A-* markers and twelve surface suite
cases (371 + 7 + 12 = 390).  Stage B re-spelled all four guard A slots
at examples/guard.tot:133-134 and examples/guard-rewrap.tot:264-265
under the amended pin 6, edited PASS-M6E-GUARD-HOLES's holed literal
from 22 to 26, and added two markers with three suite cases
(390 + 2 + 3 = 395).  Stage C adds two markers and five suite cases, so
its own exit is 395 + 2 + 5 = 402.  Stage C touches neither the settle
pass nor the corpus that Stage B re-spelled.

Stage C goes third for one reason.  Stage A and Stage B multiply the
number of holes a guard file carries, and a one-at-a-time report turns
a multi-hole edit into one run per hole.  The debt is named at
SPEC.md:2132-2134 and this stage retires it.

Files: `surface/parser.ml`, `surface/run.ml`, `bin/tot.ml`,
`dev/fixtures/m7c-multi-hole.tot` (NEW),
`dev/fixtures/m7c-multi-hole-explicit.tot` (NEW),
`dev/fixtures/m7c-backtrack.tot` (NEW), `test/surface.ml`,
`dev/gates.sh`, `SPEC.md`.  NOT touched: `surface/serror.ml`,
`surface/syntax.ml`, `surface/elab.ml`, `surface/bootstrap.ml`,
`surface/cache.ml`, `lib/`, `stdlib/prelude.tot`, `examples/`,
`test/fixtures/`, `dev/gen-m5e-transcript.sh`,
`dev/m5e-default-transcript.txt`, `dev/hole-anchors.py`.

---

### C0. Pins covered, verbatim from the verdict

Pin 7.  "Multi-hole reporting shape.  The first hole keeps its exact
current line;  further holes in the same definition are reported on
one following line of the form `N more hole(s) at L:C[, L:C]*`,
positions only, no expected types.  `Serror.t` stays a single-error
variant, no partial term is constructed, and the exit code stays 1.
Testable: PASS-M7C-MULTI-HOLE-TAIL and PASS-M7C-SINGLE-HOLE-UNCHANGED.
Amend this pin before Stage C if the user answers open question 2
differently."

Pin 8.  "No constructor is added to or removed from `Term.t` or
`Serror.t` in M7.  Testable: a constructor-count assertion in
PASS-M7C."

The user clarified open question 2 in the ratification amendment of
2026-09-04: "no second traversal" takes the STRICT reading.  Stage C
may not add any pass over parsed items or terms, not even a syntactic
fold on the failed path.  Hole positions must be collected inside a
traversal that already exists at HEAD, the parse walk or the
elaboration walk, and `Serror.t` stays unchanged.

This section meets the strict reading.  It collects the positions
inside the PARSE walk, at the one place that builds a hole node
(surface/parser.ml:369).  The earlier design of this section rested on
a syntactic fold over `Syntax.item`, which the amendment bars, and it
is deleted.  No BLOCKED paragraph is needed: a compliant design
exists, and C3 states why the parse walk is the only candidate.

Pin 8's assertion rides inside PASS-M7C-MULTI-HOLE-TAIL as two
conjuncts.  It adds no marker of its own, which is what keeps the
stage arithmetic at the verdict's 2 + 5.

---

### C1. Entry state, measured against the built binary

Every row is a probe result, not a reading.  The runner is
`/Users/oobi/Documents/tot-m7-probes/amend/run11.sh`, which writes the
three C7 fixtures byte for byte into
`/Users/oobi/Documents/tot-m7-probes/amend/v2/` and then runs every
row against them.  The binary is
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe` at HEAD
66b444f, run 2026-09-04.  HEAD carries one later commit, d028a2a,
which adds `dev/M7-PLAN.md` and no source file, so every citation
below holds at the working HEAD too.  Rows are probe IDs local to this
section, never pins.

| # | Probe | Command | Measured 2026-09-04 |
|---|---|---|---|
| P1 | the multi-hole fixture | `tot.exe check .../m7c-multi-hole.tot` | exit 1, stdout empty, stderr ONE line `...:7:14: hole: no expected type at this position` |
| P2 | its explicit twin | `tot.exe check .../m7c-multi-hole-explicit.tot` | exit 0, two stdout lines `def flagged : (List String)` and `def h : (List String)`, stderr empty |
| P3 | infer-position hole | `tot.exe check test/fixtures/m6c-hole-n-infer.tot` | exit 1, ONE line `...:1:6: hole: no expected type at this position` |
| P4 | fenced hole | `tot.exe check test/fixtures/m6c-hole-n-proof.tot` | exit 1, ONE line `...:1:38: hole: expected Type 0` |
| P5 | run mode | `tot.exe run .../m7c-multi-hole.tot` | exit 1, same one line, stdout empty |
| P6 | fail-open mapping | `tot.exe check --serror-exit 0 .../m7c-multi-hole.tot` | exit 0, same one line |
| P7 | hole columns in the multi-hole fixture | `awk` scan for `_` | 6:35, 6:49, 7:14, 7:24, 7:38 |
| P8 | corpus hole errors | every `examples/*.tot` and `test/fixtures/*.tot` checked | 9 files answer with a `hole:` line, each with a ONE-line stderr |
| P9 | the backtrack fixture | `tot.exe check .../m7c-backtrack.tot` | exit 1, stdout empty, stderr ONE line `...:5:14: hole: no expected type at this position`; `_` columns 5:14 and 5:31 |

P1 and P9 report the def's own TYPE, which is why they are stable
across Stage A and Stage B.  The reported hole is the argument of
`List _`, and that spine holds no later argument, so pin 3's rule
cannot determine it in check position and the Stage A settle cannot
determine it in infer position either.  Stage A freezes this exact
message under PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE.  P3's hole sits
in infer position under the same message.  P4's hole sits under the
proof-family fence.

P8 is the row that lets Stage C ship without a transcript reseal.  The
nine files are m6c-hole-a, m6c-hole-n-class, m6c-hole-n-infer,
m6c-hole-n-proof, m6c-hole-run, m6c-underscore-lam,
m6c-underscore-match, m6h-hole-n-fence-class and
m6h-hole-n-fence-proof.  Seven carry one `_` character.  The other two
carry two, and in both the extra one is a BINDER, not a hole:
`test/fixtures/m6c-underscore-lam.tot:1` is `fun _ => _` and
`test/fixtures/m6c-underscore-match.tot:1` has `succ _` in a pattern.
The parse walk turns a binder-position `_` into the name `"_"`
(surface/parser.ml:65-68), and only a term-position `_` becomes
`Syntax.SHole` (surface/parser.ml:369, surface/token.ml:34-40).  So
every one of the nine files keeps a one-line stderr after this stage,
and `dev/m5e-default-transcript.txt` stays byte-identical.  Pin 4
holds the reseal for Stage D and Stage C does not spend it.

Gate literals derived at HEAD, each with the command that printed it:

- `rg -c 'PASS-M7' /Users/oobi/Documents/tot/dev/gates.sh` printed
  nothing and exited 1.  The marker namespace is free (pin 13).
- `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' /Users/oobi/Documents/tot/dev/gates.sh`
  printed 169.  That is PASS-M5D-TIERS's live literal at
  dev/gates.sh:2284.
- `awk '/^type t =/,/^let to_string/' /Users/oobi/Documents/tot/surface/serror.ml | rg -c '^  \| [A-Z]'`
  printed 10.  That is `Serror.t`'s constructor count.
- `awk '/^type t =/,/^\(\*\*/' /Users/oobi/Documents/tot/lib/term.ml | rg -c '^  \| [A-Z]'`
  printed 11.  That is `Term.t`'s constructor count.
- `rg -c 'Tot_surface\.Run\.script ' /Users/oobi/Documents/tot/test/surface.ml`
  printed 17.  Those seventeen call sites keep compiling, because
  `Run.script`'s signature does not move.
- `rg -c 'Ok \(Syntax\.SHole' /Users/oobi/Documents/tot/surface/parser.ml`
  printed 1.  The parse walk builds a hole node in exactly one place.

---

### C2. Files touched

- `surface/parser.ml`: one module-level position record, one write in
  the existing `Underscore` arm of `parse_atom`, one rollback wrapper
  at the file's single speculation point, one per-item reset in
  `parse_items`, and one new exported function `parse_with_holes`.
  `parse` keeps its signature.  No type in the file changes.
- `surface/run.ml`: three new private helpers and one exported
  function `script_tailed`.  `script` keeps its signature and becomes
  a projection of `script_tailed`.
- `bin/tot.ml`: `run_file` calls `script_tailed`, binds the tail in
  the existing error fold, and prints it in the last arm.  No exit
  code moves.
- `dev/fixtures/m7c-multi-hole.tot`,
  `dev/fixtures/m7c-multi-hole-explicit.tot` and
  `dev/fixtures/m7c-backtrack.tot` (all NEW).  They live under `dev/`
  because the transcript glob covers `examples/*.tot` and
  `test/fixtures/*.tot` only (dev/gen-m5e-transcript.sh:13), and the
  anchor classifier reads the prelude plus `examples/` only
  (dev/hole-anchors.py:86-87).  A fixture under `dev/fixtures/`
  therefore moves no pinned literal.
- `test/surface.ml`: one helper and five cases, +5 PASS lines.
- `dev/gates.sh`: the M7C block, the EXIT trap at dev/gates.sh:434,
  and the PASS-M5D-TIERS literal at dev/gates.sh:2284.
- `SPEC.md`: clause (3) at SPEC.md:2132-2134 is rewritten, and one
  dated entry lands at the end of the section 2 decision log (after
  SPEC.md:1576, before the `## 3.` heading at SPEC.md:1578).

---

### C3. Design note: why the parse walk, and only the parse walk

The strict reading leaves three candidate traversals.  Two of them
fail, and the reasons are mechanical.

A NEW fold over `Syntax.item`, the design this section carried before
the amendment, is barred in one sentence: it is a new pass over parsed
items and terms.  It is deleted, and with it the two functions it
would have added to `surface/syntax.ml`.  That file is now untouched.

The ELABORATION walk is barred by arithmetic, not by the amendment.
It stops at the first hole it cannot fill.  Every hole it has already
met is a hole it RESOLVED, and every hole it has not met yet is a hole
it never visits, so the walk holds no record of the positions pin 7
asks for.  Reaching them means continuing after an error, which
scope-out item 7 of the verdict forbids, or building a partial term,
which pin 7 forbids.

The PARSE walk meets every term-position hole exactly once, and it
meets it at one place.  `parse_atom` answers `Ok (Syntax.SHole loc,
rest)` for an `Underscore` token at surface/parser.ml:369, and that
line is the file's only hole construction (`rg -c 'Ok \(Syntax\.SHole'`
printed 1).  A binder-position `_` never reaches it: `collect_idents`
consumes the token as the name `"_"` at surface/parser.ml:65-68.  So
the walk that already runs at HEAD sees exactly the set pin 7 names,
and Stage C records the position where the walk already stands.

The line says what it can prove.  `N more hole(s) at L:C` counts the
OTHER term-position holes of the failing item, in source order.  It
does not claim they are unresolvable.  Deciding which of them would
resolve is a second elaboration, which the pin bars.  The wording of
pin 7 is chosen for this reason, and the design keeps it.

Tail semantics, exactly:

1. The tail exists only for a `Serror.Hole` error.  Every other
   constructor answers `None`.
2. The unit is the ITEM the parse walk was inside, which is pin 7's
   "same definition".  A hole of any other item never appears.
3. The tail names every term-position hole the walk recorded for that
   item, minus every position equal to the reported one.  Holes the
   elaborator would have filled are included, because the parse walk
   knows positions and nothing else.
4. The order is source order, by line then by column.
5. An item whose only hole is the reported one has an empty tail, and
   an empty tail prints no line.

---

### C4. `surface/parser.ml`: the record inside the existing walk

Three edits, all inside the walk.

Edit 1, the record.  One module-level list, written only by the arm at
surface/parser.ml:369.

```ocaml
(** M7 Stage C (pin 7): the term-position hole positions the CURRENT
    item's parse walk has met, newest first.  This is a record kept
    INSIDE the walk that already runs, not a second pass: the only
    writer is the [Underscore] arm of [parse_atom], the only reader is
    [with_item_holes], and [parse_items] clears it at every item
    boundary.  The parser runs in one thread and finishes before any
    elaboration starts, so no caller interleaves two parses;
    [term_only] may leave entries behind and the next item clears
    them. *)
let holes : Loc.t list ref = ref []
```

The arm at surface/parser.ml:369, before and after:

```ocaml
  (* HEAD *)
  | { Token.kind = Token.Underscore; loc } :: rest -> Ok (Syntax.SHole loc, rest)

  (* Stage C *)
  | { Token.kind = Token.Underscore; loc } :: rest ->
      (* M7 Stage C (pin 7): the position, recorded where the walk
         already stands.  The node is unchanged. *)
      let () = holes := loc :: !holes in
      Ok (Syntax.SHole loc, rest)
```

Edit 2, the rollback.  The file has ONE speculative site.  Its own
header says so at surface/parser.ml:1-5, and the code agrees:
`try_binder_group` at surface/parser.ml:305-325 is the only function
that parses a term and then discards it, its `None` exits are at
surface/parser.ml:311, :322, :323, :324 and :325, and `parse_arrow` at
surface/parser.ml:327-334 is its only caller.  A rejected group
re-parses the same tokens through `parse_atom`, so without a rollback
one source hole records twice.  The existing function is renamed to
`binder_group_attempt`, with its body unchanged, and the name
`try_binder_group` becomes the wrapper:

```ocaml
(** M7 Stage C (pin 7): the speculation's hole record is transactional.
    A rejected group is re-parsed by the application path, which
    records the same positions again, so the attempt's records are
    dropped.  This is the file's ONLY backtracking site
    (surface/parser.ml:1-5), so this is the only rollback. *)
and try_binder_group (ts : Token.t list) :
    (Loc.t * Quantity.t * string list * Syntax.t * Token.t list) option =
  let saved = !holes in
  let attempt = binder_group_attempt ts in
  let () =
    match () with
    | () when Option.is_none attempt -> holes := saved
    | () -> ()
  in
  attempt
```

Edit 3, the item boundary.  `parse_items` at surface/parser.ml:394-436
is the walk's own item loop.  Eight of its arms parse an item.  Each
one runs through one helper, defined just above the loop:

```ocaml
(** M7 Stage C (pin 7): parse ONE item with a fresh record, then pair
    the item with the positions the walk met, oldest first.  The reset
    is per item because pin 7's unit is "the same definition". *)
let with_item_holes (f : unit -> (Syntax.item * Token.t list, Serror.t) result) :
    ((Syntax.item * Loc.t list) * Token.t list, Serror.t) result =
  let () = holes := [] in
  Result.map (fun (it, rest) -> ((it, List.rev !holes), rest)) (f ())
```

The loop's accumulator becomes a pair list.  Two arms, one that parses
an item and one that parses a term, show the whole edit:

```ocaml
let rec parse_items (ts : Token.t list) (acc : (Syntax.item * Loc.t list) list) :
    ((Syntax.item * Loc.t list) list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Eof; loc = _ } :: _rest -> Ok (List.rev acc)
  | { Token.kind = Token.KDef; loc } :: rest ->
      let* pair, rest2 = with_item_holes (fun () -> parse_def ~loc ~reducible:false rest) in
      parse_items rest2 (pair :: acc)
  | { Token.kind = Token.KEval; loc } :: rest ->
      let* pair, rest2 =
        with_item_holes (fun () ->
            Result.map (fun (tm, rest2) -> (Syntax.IEval (loc, tm), rest2)) (parse_term rest))
      in
      parse_items rest2 (pair :: acc)
  (* the six remaining item arms take the same shape;  the error arms
     are unchanged *)
```

The two entry points at surface/parser.ml:652.  `parse` keeps its
type, so test/surface.ml:588 and surface/bootstrap.ml:384 compile
untouched:

```ocaml
(** M7 Stage C (pin 7): the items, each with the hole positions the
    walk recorded for it. *)
let parse_with_holes (ts : Token.t list) :
    ((Syntax.item * Loc.t list) list, Serror.t) result =
  parse_items ts []

let parse (ts : Token.t list) : (Syntax.item list, Serror.t) result =
  Result.map (List.map fst) (parse_with_holes ts)
```

`term_only` at surface/parser.ml:657-663 is unchanged.

---

### C5. `surface/run.ml`: the tail string, from the same run

`script` is at surface/run.ml:635-650.  It lexes at surface/run.ml:638,
parses at surface/run.ml:639, folds the items at surface/run.ml:640-646
through `item` (surface/run.ml:208), and answers at surface/run.ml:650.
The `let*` at surface/run.ml:8 is `Result.bind`.

Stage C keeps that function and adds `script_tailed` beside it.  The
new function runs the SAME pipeline once.  It carries the failing
item's recorded positions in hand while it folds, so the tail needs no
re-lex and no re-parse.  `Serror.t` is unchanged: the tail travels
next to the error, in the result's error component, and never inside
it.

```ocaml
(** M7 Stage C (pin 7): the reported hole's own position, [None] for
    every other error.  Enumerated with no catch-all, so a future
    [Serror] constructor must decide its posture here. *)
let reported_hole (e : Serror.t) : Loc.t option =
  match e with
  | Serror.Hole { loc; expected = _expected } -> Some loc
  | Serror.Lex _ | Serror.Parse _ | Serror.Unknown_name _ | Serror.Bad_level _
  | Serror.Kernel _ | Serror.Main_bad_type _ | Serror.Axioms_disabled _
  | Serror.Missing_main | Serror.Json_strict_reject ->
      None

(** Source order for two positions. *)
let loc_order (a : Loc.t) (b : Loc.t) : int =
  match () with
  | () when a.Loc.line <> b.Loc.line -> Int.compare a.Loc.line b.Loc.line
  | () -> Int.compare a.Loc.col b.Loc.col

let loc_equal (a : Loc.t) (b : Loc.t) : bool =
  Int.equal a.Loc.line b.Loc.line && Int.equal a.Loc.col b.Loc.col

(** M7 Stage C (pin 7): the tail LINE for one item, positions only, no
    expected types.  [holes] is what the PARSE walk recorded for the
    item that failed (surface/parser.ml:369).  [None] when the error is
    not a hole, and [None] when the item carries no other hole, so a
    one-hole file keeps its one-line stderr byte for byte.  The sort is
    defensive and there is NO dedup: a lost rollback in the parser must
    show up as a repeated position, not disappear. *)
let hole_tail ~(holes : Loc.t list) (e : Serror.t) : string option =
  Option.bind (reported_hole e) (fun loc ->
      match holes |> List.filter (fun l -> not (loc_equal loc l)) |> List.sort loc_order with
      | [] -> None
      | _ :: _ as locs ->
          Some
            (Printf.sprintf "%d more hole(s) at %s" (List.length locs)
               (String.concat ", " (List.map Loc.to_string locs))))

(** M7 Stage C (pin 7): [script] with the position-only tail beside the
    error.  ONE pass: the positions ride out of [Parser.parse_with_holes]
    with the item that carries them, so nothing is re-lexed, re-parsed
    or re-folded.  A lex error, a parse error and an epilogue error
    carry no tail. *)
let script_tailed ?(st : state = initial) ?(policy : policy = default_policy)
    ?(budget : Budget.t = Budget.unlimited) ~(exec : bool) (src : string) :
    (string list * int option, Serror.t * string option) result =
  let untailed (r : ('a, Serror.t) result) : ('a, Serror.t * string option) result =
    Result.map_error (fun e -> (e, None)) r
  in
  let* tokens = untailed (Lexer.lex src) in
  let* items = untailed (Parser.parse_with_holes tokens) in
  let* final =
    List.fold_left
      (fun acc (it, holes) ->
        let* st = acc in
        item ~budget ~exec ~policy st it
        |> Result.map_error (fun e -> (e, hole_tail ~holes e)))
      (Ok st) items
  in
  let* replacement_lines, exit_code = untailed (main_epilogue final ~exec ~policy) in
  let base_lines = List.rev final.lines in
  let out_lines = replacement_lines |> Option.fold ~none:base_lines ~some:Fun.id in
  Ok (out_lines, exit_code)

(** Unchanged signature (M3 Stage B).  M7 Stage C: the tail is dropped
    here, so every existing caller keeps its type. *)
let script ?(st : state = initial) ?(policy : policy = default_policy)
    ?(budget : Budget.t = Budget.unlimited) ~(exec : bool) (src : string) :
    (string list * int option, Serror.t) result =
  Result.map_error fst (script_tailed ~st ~policy ~budget ~exec src)
```

`Loc.to_string` at surface/loc.ml:17 renders `%d:%d`, so the tail reads
`2 more hole(s) at 7:24, 7:38` for the Stage C fixture.  The `(s)` is
literal in every case, singular included, because pin 7 spells it that
way.

Two properties the shape buys.  The item lookup is by CONSTRUCTION,
because the fold holds the failing item's own record, so no item span
is guessed.  The filter drops the reported position only, so the first
line and the tail never name the same place twice.

Why the filter always removes exactly one entry.  `Serror.Hole` is
built at four places, and every one of them takes its `loc` from a
`Syntax.SHole loc` node: surface/elab.ml:287-291 (infer position),
surface/elab.ml:400 (check position), surface/elab.ml:502-505 (the
capped argument slot) and surface/elab.ml:513-516 (the fenced slot).
Every `SHole` node carries the `Loc.t` the parse walk recorded at
surface/parser.ml:369, so the reported position is a member of the
item's record.  A hole of the PRELUDE cannot reach this fold either:
the prelude is elaborated before `script_tailed` runs, and a broken
prelude is reported by the driver's own arm at bin/tot.ml:171-173.

---

### C6. `bin/tot.ml`: the second stderr line

`run_file` binds the source at bin/tot.ml:65 and calls `Run.script` at
bin/tot.ml:66.  Its error fold opens at bin/tot.ml:75.  Four arms
decide the exit code.  A hole error takes the last arm, because
`Serror.is_check_budget`, `Serror.is_missing_main` and
`Serror.driver_exit` are all false for `Hole`, so the arms at
bin/tot.ml:102, :106 and :109 do not fire.  Three edits, and nothing
else in the driver moves.

Edit 1, bin/tot.ml:66:

```ocaml
         Tot_surface.Run.script_tailed ~st ~policy ~budget ~exec src
```

Edit 2, bin/tot.ml:75.  The error component is now a pair:

```ocaml
              ~error:(fun ((e : Tot_surface.Serror.t), (tail : string option)) ->
```

Edit 3, the last arm at bin/tot.ml:112-114, which reads today:

```ocaml
                | () ->
                    prerr_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
                    serror_exit))
```

After the edit:

```ocaml
                | () ->
                    prerr_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
                    (* M7 Stage C (pin 7): the position-only tail, one
                       line, on the SAME channel as the error it
                       extends.  No path prefix: the line above already
                       named the file, and pin 7 fixes these bytes.
                       [None] for every non-hole error and for a
                       one-hole item, so no existing transcript
                       moves. *)
                    Option.iter prerr_endline tail;
                    serror_exit))
```

The exit code stays `serror_exit` in check and run mode, which P5 and
P6 measured as 1 and, under `--serror-exit 0`, as 0.

The PRELUDE arm at bin/tot.ml:171-173 keeps its one-line report, and
the reason is the strict reading itself.  That arm reports a failure
of `Bootstrap.cached_state_of_src` (surface/bootstrap.ml:443), which
parses the prelude at surface/bootstrap.ml:384 only on a cache MISS.
On a cache hit no parse walk runs, so no record exists to report from,
and a re-parse is exactly the second pass the amendment bars.  A tail
that appeared on a cold cache and vanished on a warm one would also
break pin 18's miss-then-hit leg.  A hand-broken prelude therefore
keeps the M6 report.  M8 inherits it as debt 10 of section 8, by the
ruling of 2026-09-04.

---

### C7. The Stage C fixtures, complete bytes

`dev/fixtures/m7c-multi-hole.tot`, written literally:

```
-- M7 Stage C (pin 7): the reported hole is the def's own TYPE, so no
-- later argument of the spine can determine it and no Stage A or
-- Stage B rule moves it.  The two later holes of the SAME definition
-- are the tail.  The two holes on line 6 belong to another
-- definition, which checks green, and must never appear in the tail.
def flagged : List String := cons _ "grep" (nil _)
def h : List _ := cons _ "flag" (nil _)
```

Why the reported hole stays red through Stage A and Stage B.  The slot
at 7:14 is the argument of `List` in `h`'s declared type.  That spine
carries no later explicit argument, so pin 3's rule has nothing to
match against, in check position or, after the amended Stage A, in
infer position.  HEAD answers
`7:14: hole: no expected type at this position` (P1), which is the
message pin 2 freezes and PASS-M7A-ARGHOLE-REFUSES-NONINFERABLE pins.
Line 6 checks green at HEAD, which P1 proves by failing at line 7.

Hole positions, measured by P7: 6:35 and 6:49 in `flagged`, then 7:14,
7:24 and 7:38 in `h`.  The tail is `2 more hole(s) at 7:24, 7:38`.
The two positions on line 6 are the anti-vacuity property of the
fixture: a whole-file record would report four, and the gate rejects
any line that names 6:35 or 6:49.

`dev/fixtures/m7c-multi-hole-explicit.tot`, written literally:

```
-- M7 Stage C: the explicit twin of m7c-multi-hole.tot.  It checks at
-- exit 0, which proves the holed file fails for its holes and for no
-- other reason.
def flagged : List String := cons String "grep" (nil String)
def h : List String := cons String "flag" (nil String)
```

Measured at HEAD (P2): exit 0, and stdout is exactly

```
def flagged : (List String)
def h : (List String)
```

`dev/fixtures/m7c-backtrack.tot`, written literally:

```
-- M7 Stage C (pin 7): the parse walk speculates a binder group at the
-- parenthesized annotation, rejects it, and re-parses the same
-- tokens.  The tail must name the second hole exactly once, which is
-- what the rollback buys.
def h : List _ := (nil : List _)
```

This fixture gates edit 2 of C4 and nothing else.  The body starts at
`(`, so `parse_arrow` (surface/parser.ml:327-334) calls the
speculation first.  The speculation reads the names, meets the colon,
parses `List _` and records 5:31.  The token after `)` is not `->`, so
it answers `None` (surface/parser.ml:322) and the application path
re-parses the same annotation, which records 5:31 again.  With the
rollback the tail is `1 more hole(s) at 5:31`.  Without it the tail is
`2 more hole(s) at 5:31, 5:31`, which the gate rejects by exact match.
Measured at HEAD (P9): exit 1, one stderr line
`5:14: hole: no expected type at this position`, `_` at 5:14 and 5:31.

The exact report bytes.  The driver prints `path ^ ":" ^
Serror.to_string e` (bin/tot.ml:113), where `path` is the operand as
the caller spelled it, so the prefix below is written `<path>`.  After
the stage `tot.exe check dev/fixtures/m7c-multi-hole.tot` writes
nothing to stdout and exactly these two stderr lines:

```
<path>:7:14: hole: no expected type at this position
2 more hole(s) at 7:24, 7:38
```

`tot.exe check dev/fixtures/m7c-backtrack.tot` writes nothing to
stdout and exactly these two stderr lines:

```
<path>:5:14: hole: no expected type at this position
1 more hole(s) at 5:31
```

At HEAD both commands write the FIRST line of their block and nothing
else, which P1 and P9 measured.  The tail line carries no path prefix,
no expected type and no trailing space.  `run` mode and
`--serror-exit 0` print the same two lines and move only the exit
code, which is leg (b) of gate C9 (i).

---

### C8. Stage C suite tests (+5 surface)

All five sit in `test/surface.ml`'s `cases` list, next to the M6C
block that starts at test/surface.ml:1832.  `run_suite` prints
`PASS <name>` per green case (test/surface.ml:1913), so each case is
one PASS line in the battery.  All five call the new `Run.script_tailed`
in process.  None of them runs the CLI and none adds a fixture file.

One helper, next to `m6c_expect_err_line` (test/surface.ml:817-820).
`show_lines` is at test/surface.ml:7:

```ocaml
(* M7 Stage C (pin 7): the rendered first line and the rendered tail
   of one source, both taken from the SAME [Run.script_tailed]
   failure, which is the pair the driver prints. *)
let m7c_expect_tail (bst : Tot_surface.Run.state) (src : string) ~(want_line : string)
    ~(want_tail : string option) () : (unit, string) result =
  Tot_surface.Run.script_tailed ~st:bst ~exec:false src
  |> Result.fold
       ~ok:(fun (lines, _exit) ->
         Error
           (Printf.sprintf "expected [%s], but the script ran: [%s]" want_line
              (show_lines lines)))
       ~error:(fun (e, tail) ->
         let got = Tot_surface.Serror.to_string e in
         match () with
         | () when String.equal got want_line && Option.equal String.equal tail want_tail -> Ok ()
         | () ->
             Error
               (Printf.sprintf "got [%s] tail [%s], want [%s] tail [%s]" got
                  (Option.value tail ~default:"None") want_line
                  (Option.value want_tail ~default:"None")))
```

The five cases.  Every first line below was measured at HEAD on the
same bytes, so only the tail is new behaviour.

1. `M7C-1 m7c_tail_reports`: the three-hole source
   `"def h : List _ := cons _ \"flag\" (nil _)\n"` gives line
   `1:14: hole: no expected type at this position` and tail
   `Some "2 more hole(s) at 1:24, 1:38"`.
2. `M7C-2 m7c_tail_single`: `"def h : List _ := cons String \"flag\" (nil String)\n"`
   gives the same first line and tail `None`.  A one-hole item gains
   nothing.
3. `M7C-3 m7c_tail_scoped`: the source of case 1 with
   `"def flagged : List String := cons _ \"grep\" (nil _)\n"` prepended
   gives line `2:14: hole: no expected type at this position` and tail
   `Some "2 more hole(s) at 2:24, 2:38"`.  It never names a position
   on line 1, which is pin 7's "same definition" clause.  The
   prepended item checks green, which is what makes the exclusion a
   real test and not an artefact of an early failure.
4. `M7C-4 m7c_tail_non_hole`: `"def g : List Nat := cons _ zero nosuch\n"`
   fails with `1:33: unknown name nosuch` (measured at HEAD) and tail
   `None`.  A non-hole error carries no tail even when its item holds
   a hole at 1:26.
5. `M7C-5 m7c_tail_backtrack`: `"def h : List _ := (nil : List _)\n"`
   gives line `1:14: hole: no expected type at this position` and tail
   `Some "1 more hole(s) at 1:31"`.  The case is the in-process twin of
   the C7 backtrack fixture: it turns red if the rollback of C4 edit 2
   is dropped, because the tail then reads
   `2 more hole(s) at 1:31, 1:31`.

Case 3's positions shift by one line against case 1 because of the
prepended definition.  All five pin whole strings, so none can drift
silently.

---

### C9. Gate additions

Placement.  The whole M7C block goes AFTER the Stage B M7B block, and
the Stage B block itself sits after PASS-M6E-TRANSCRIPT-RESEALED
(dev/gates.sh:3116-3139) and before the `ctxcat id 5` comment at
dev/gates.sh:3141.  The two branching legs stay the file's tail, per
the M6 Stage E placement note at dev/gates.sh:3023-3026.  The block
opens its own scratch with the TMPDIR template form, and the scratch
variable joins the EXIT trap at dev/gates.sh:434.  PASS lines are
emitted the way every leg in the file emits them: a single `{ ... }`
conjunction, then `&& echo PASS-<marker>`, then a `||` branch that
replays the captured output, prints `FAIL-<marker> (...)` with the
measured values, and exits 1.

The block header, in the file's own style:

```sh
# ---------------------------------------------------------------------
# M7 Stage C: multi-hole tail reporting (verdict pins 7 and 8).  Two
# markers.  All three fixtures live under dev/fixtures/, OUTSIDE the
# transcript glob (dev/gen-m5e-transcript.sh:13) and outside the
# anchor corpus (dev/hole-anchors.py:86-87), because pin 4 holds the
# reseal for Stage D and pin 10 fixes the ANCHORS literal there.
# ---------------------------------------------------------------------
m7c_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-m7c.XXXXXX")
```

Two literal edits ride with the block.  `dev/gates.sh:434` gains
`"$m7c_scratch"` inside the EXIT trap.  `dev/gates.sh:2284`'s
PASS-M5D-TIERS literal rises by 7, which is the number of direct tier
uses these two legs add (7 FAST), measured with
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before
and after the edit, both numbers recorded in dev/M7-BUILD-LOG.md.  The
value at HEAD is 169; the value at the Stage C boundary is 169 plus
what Stage A and Stage B added, plus 7.

#### Probe 1

  Marker: PASS-M7C-MULTI-HOLE-TAIL
  Pin: 7, 8
  Command (post-stage): D=/Users/oobi/Documents/tot/dev/fixtures; X=/Users/oobi/Documents/tot/_build/default/bin/tot.exe; for f in m7c-multi-hole m7c-backtrack; do [ -f $D/$f.tot ] || { echo MISSING-FIXTURE; exit 9; }; done; $X check $D/m7c-multi-hole.tot 2>&1; $X check $D/m7c-backtrack.tot 2>&1
  Command measured at HEAD: the same line with D=/Users/oobi/Documents/tot-m7-probes/amend/v2, which holds the identical bytes, because dev/fixtures/ does not exist at HEAD.
  At HEAD: exit 1, and that command printed exactly two lines on 2026-09-04, "/Users/oobi/Documents/tot-m7-probes/amend/v2/m7c-multi-hole.tot:7:14: hole: no expected type at this position" and "/Users/oobi/Documents/tot-m7-probes/amend/v2/m7c-backtrack.tot:5:14: hole: no expected type at this position", with no "more hole(s)" in either.  After the stage the post-stage command prints the same columns under the repo file names.
  After stage: exit 1, output contains "2 more hole(s) at 7:24, 7:38" and "1 more hole(s) at 5:31", with both first lines unchanged.
  Non-vacuous because: at HEAD the driver prints one line per failure and never a second, so neither substring can appear; the twin fixture checks at exit 0 (P2), which proves the holed file fails for its holes; the leg also rejects any tail naming 6:35 or 6:49, so a whole-file record cannot pass it, and the backtrack file rejects "2 more hole(s) at 5:31, 5:31", so a lost rollback cannot pass it.

#### Probe 2

  Marker: PASS-M7C-SINGLE-HOLE-UNCHANGED
  Pin: 7
  Command (post-stage): T=/Users/oobi/Documents/tot; X=$T/_build/default/bin/tot.exe; M=$T/dev/fixtures/m7c-multi-hole.tot; for f in $T/test/fixtures/m6c-hole-n-infer.tot $T/test/fixtures/m6c-hole-n-proof.tot $M; do [ -f "$f" ] || { echo MISSING-FIXTURE; exit 9; }; done; printf '%s/%s/%s\n' "$($X check $T/test/fixtures/m6c-hole-n-infer.tot 2>&1 | wc -l | tr -d ' ')" "$($X check $T/test/fixtures/m6c-hole-n-proof.tot 2>&1 | wc -l | tr -d ' ')" "$($X check $M 2>&1 | wc -l | tr -d ' ')"
  Command measured at HEAD: the same line with M=/Users/oobi/Documents/tot-m7-probes/amend/v2/m7c-multi-hole.tot, the identical bytes, because dev/fixtures/ does not exist at HEAD.
  At HEAD: exit 0, and that command printed "1/1/1" on 2026-09-04.
  Existence assertion: all three paths pass [ -f ] before any check runs, and a missing file prints MISSING-FIXTURE and exits 9.  Without it the third field 1 is also what a missing file prints, because a "no such file" refusal is one stderr line, so that field of the baseline would prove nothing.
  After stage: exit 0, output contains "1/1/2".
  Non-vacuous because: the leg is a differential.  The two single-hole files must stay at one line while the multi-hole file moves to two, so a change that prints a tail everywhere fails the first two fields and a change that prints no tail fails the third.

Both fixtures for probe 2 are stable across Stage A and Stage B by
pin: m6c-hole-n-infer.tot sits in infer position with no later spine
argument, which pin 2 keeps at its exact current message, and
m6c-hole-n-proof.tot sits under the proof-family fence, where the
spine rule does not activate.  The gate deliberately does NOT use
test/fixtures/m6c-hole-a.tot here: its hole is the `readStdin` A slot,
which is the shape Stage A resolves.

The two legs, written out.  Second lines are picked with
`awk 'NR==2'`, because the assertion is byte equality of the SECOND
line of stderr:

```sh
# Gate C9 (i), PASS-M7C-MULTI-HOLE-TAIL (pins 7 and 8).  Five legs.
# (a) check: exit 1, stdout EMPTY, stderr EXACTLY two lines, the M6
# line first and the pin-7 tail second.  (b) the same tail on the run
# path and under --serror-exit 0, so the mapping moves the code and
# never the report.  (c) the tail names NO position of the green
# definition above it.  (d) the backtrack fixture: one position, once.
# (e) pin 8: the two constructor counts, derived from the type blocks,
# not from a line number.
m7c_out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/fixtures/m7c-multi-hole.tot 2> "$m7c_scratch"/multi.err); m7c_c1=$?
m7c_twin=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/fixtures/m7c-multi-hole-explicit.tot 2> "$m7c_scratch"/twin.err); m7c_c2=$?
m7c_run=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe run \
  "$ROOT"/dev/fixtures/m7c-multi-hole.tot 2> "$m7c_scratch"/run.err); m7c_c3=$?
m7c_se0=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check --serror-exit 0 \
  "$ROOT"/dev/fixtures/m7c-multi-hole.tot 2> "$m7c_scratch"/se0.err); m7c_c4=$?
m7c_bck=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/dev/fixtures/m7c-backtrack.tot 2> "$m7c_scratch"/back.err); m7c_c5=$?
m7c_sctors=$(awk '/^type t =/,/^let to_string/' "$ROOT"/surface/serror.ml | rg -c '^  \| [A-Z]')
m7c_tctors=$(awk '/^type t =/,/^\(\*\*/' "$ROOT"/lib/term.ml | rg -c '^  \| [A-Z]')
{ [ "$m7c_c1" -eq 1 ] && [ "$m7c_c2" -eq 0 ] && [ "$m7c_c3" -eq 1 ] && [ "$m7c_c4" -eq 0 ] \
    && [ "$m7c_c5" -eq 1 ] \
    && [ -z "$m7c_out" ] && [ -z "$m7c_run" ] && [ -z "$m7c_se0" ] \
    && [ "$(wc -l < "$m7c_scratch"/multi.err | tr -d ' ')" -eq 2 ] \
    && [ "$(wc -l < "$m7c_scratch"/run.err | tr -d ' ')" -eq 2 ] \
    && [ "$(wc -l < "$m7c_scratch"/se0.err | tr -d ' ')" -eq 2 ] \
    && [ "$(wc -l < "$m7c_scratch"/back.err | tr -d ' ')" -eq 2 ] \
    && [ "$(wc -l < "$m7c_scratch"/twin.err | tr -d ' ')" -eq 0 ] \
    && rg -q '^\S*/m7c-multi-hole\.tot:7:14: hole: no expected type at this position$' \
         "$m7c_scratch"/multi.err \
    && [ "$(awk 'NR==2' "$m7c_scratch"/multi.err)" = "2 more hole(s) at 7:24, 7:38" ] \
    && [ "$(awk 'NR==2' "$m7c_scratch"/run.err)" = "2 more hole(s) at 7:24, 7:38" ] \
    && [ "$(awk 'NR==2' "$m7c_scratch"/se0.err)" = "2 more hole(s) at 7:24, 7:38" ] \
    && rg -q '^\S*/m7c-backtrack\.tot:5:14: hole: no expected type at this position$' \
         "$m7c_scratch"/back.err \
    && [ "$(awk 'NR==2' "$m7c_scratch"/back.err)" = "1 more hole(s) at 5:31" ] \
    && { rg -q '6:35|6:49' "$m7c_scratch"/multi.err; [ $? -eq 1 ]; } \
    && [ "$m7c_sctors" -eq 10 ] && [ "$m7c_tctors" -eq 11 ]; } \
  && echo PASS-M7C-MULTI-HOLE-TAIL \
  || {
    cat "$m7c_scratch"/multi.err "$m7c_scratch"/back.err
    echo "FAIL-M7C-MULTI-HOLE-TAIL (exit=$m7c_c1/$m7c_c2/$m7c_c3/$m7c_c4/$m7c_c5 ctors=$m7c_sctors/$m7c_tctors)"
    exit 1
  }
```

```sh
# Gate C9 (ii), PASS-M7C-SINGLE-HOLE-UNCHANGED (pin 7).  A one-hole
# item must keep the M6 one-line report, byte for byte, so the stage
# cannot buy its tail by printing a tail everywhere.  Both fixtures
# are pin-stable: infer position (pin 2) and the proof fence.
m7c_i=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-infer.tot 2> "$m7c_scratch"/i.err); m7c_c6=$?
m7c_p=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m6c-hole-n-proof.tot 2> "$m7c_scratch"/p.err); m7c_c7=$?
{ [ "$m7c_c6" -eq 1 ] && [ "$m7c_c7" -eq 1 ] \
    && [ "$(wc -l < "$m7c_scratch"/i.err | tr -d ' ')" -eq 1 ] \
    && [ "$(wc -l < "$m7c_scratch"/p.err | tr -d ' ')" -eq 1 ] \
    && rg -q '^\S*/m6c-hole-n-infer\.tot:1:6: hole: no expected type at this position$' \
         "$m7c_scratch"/i.err \
    && rg -q '^\S*/m6c-hole-n-proof\.tot:1:38: hole: expected Type 0$' "$m7c_scratch"/p.err \
    && { rg -q 'more hole' "$m7c_scratch"/i.err "$m7c_scratch"/p.err; [ $? -eq 1 ]; }; } \
  && echo PASS-M7C-SINGLE-HOLE-UNCHANGED \
  || {
    cat "$m7c_scratch"/i.err "$m7c_scratch"/p.err
    echo "FAIL-M7C-SINGLE-HOLE-UNCHANGED (exit=$m7c_c6/$m7c_c7)"
    exit 1
  }
```

Mutation proofs for the two legs, to be recorded in
dev/M7-BUILD-LOG.md with their transcripts:

- MUT-C1: drop the `List.filter` in `hole_tail`.  The reported
  position 7:14 joins the tail, the count reads 3, and leg (i)'s
  second-line equality fails.
- MUT-C2: drop the rollback wrapper of C4 edit 2.  The backtrack
  fixture's tail reads `2 more hole(s) at 5:31, 5:31` and leg (i)'s
  backtrack equality fails.  The multi-hole fixture alone would NOT
  catch this, which is why the third fixture exists.
- MUT-C3: move the `holes := []` reset out of `with_item_holes`, so
  the record accumulates across items.  The tail names 6:35 and 6:49
  and leg (i)'s exclusion clause fails.
- MUT-C4: return `Some` for the empty tail.  A one-hole file gains a
  `0 more hole(s) at ` line, and leg (ii)'s line counts fail.
- MUT-C5: print the tail in the `run` path only.  Leg (i)'s check and
  `--serror-exit 0` line counts fail, which is why leg (i) runs all
  three modes.

---

### C10. SPEC.md edits

Edit 1.  SPEC.md:2132-2134 today reads
"(3) the checker reports one error and stops, so a file with several
unresolvable holes surfaces them one at a time."  It becomes:

```
  `PASS-M6E-GUARD-HOLES` pins zero prelude holes);  (3) the checker
  reports one error and stops, and since M7 Stage C it appends one
  position-only tail line naming the OTHER holes of the same item,
  recorded by the parse walk, so per-hole EXPECTED TYPES are still one
  at a time.
```

Edit 2.  One dated entry at the end of the section 2 decision log,
after SPEC.md:1576 and before the `## 3.` heading at SPEC.md:1578, in
the shape of the M6 Stage H entry above it.  The entry states the
pin-7 shape, the strict reading of "no second traversal" and where the
positions come from, the two markers, the `Serror.t` and `Term.t`
counts that pin 8 froze (10 and 11), the prelude arm's exception and
its reason, the PASS-M5D-TIERS move, and the battery count 395 to 402.

Constraint on both edits, from pin 12: no `expected-type-only=`
spelling may enter SPEC.md in this stage.  PASS-M5D-MEASURE-LOG reads
the LAST such spelling in the file through `tail -n 1`
(dev/gates.sh:3015-3016), and SPEC.md:2123 must stay that line until
Stage D moves it.

---

### C11. Review checklist

1. `rg -n 'raise|failwith|assert' surface/parser.ml surface/run.ml bin/tot.ml`
   over the diff shows no new hit.
2. `reported_hole` lists all ten `Serror.t` constructors with no `_`
   arm.  `parse_atom`'s arm list is unchanged.
3. No `match` on an `option` or a `result` in the new code.  The
   helpers use `Option.bind`, `Option.is_none`, `Option.iter`,
   `Option.value`, `Option.equal`, `Option.fold`, `Result.map`,
   `Result.map_error` and `Result.fold`.  The one `match` on a LIST in
   `hole_tail` is exhaustive, and the two `match ()` guards follow the
   house form.
4. No indexing and no division in the new code.
5. `surface/serror.ml`, `surface/syntax.ml` and `surface/elab.ml` are
   untouched.  `git diff --stat` names no file under `lib/`.
6. `Run.script`'s signature is unchanged, so test/surface.ml's
   seventeen `Tot_surface.Run.script` lines, surface/bootstrap.ml:384
   and test/surface.ml:588 are untouched by the type checker.
7. The tail line carries no path prefix and no expected type.  The
   bytes match pin 7's form exactly.
8. The record has exactly one writer.  `rg -n 'holes :=' surface/parser.ml`
   returns three hits and no more: the write in `parse_atom`, the
   rollback in `try_binder_group`, and the reset in
   `with_item_holes`.
9. `dev/m5e-default-transcript.txt` is byte-identical after the stage:
   run `zsh dev/gen-m5e-transcript.sh > "$TMPDIR"/now.txt` and
   `diff dev/m5e-default-transcript.txt "$TMPDIR"/now.txt` exits 0.
   The P8 row is the reason to expect this, and this check is the
   proof.
10. `python3 dev/hole-anchors.py | tail -1` still prints
    `ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30`
    at the Stage C boundary.  Stage C adds no file the classifier
    reads.
11. The battery prints 402 PASS, 0 FAIL, GATE-EXIT=0, and the two new
    markers appear exactly once each.

---

### C12. Rollback

The stage is four independent reverts, in this order.

1. Revert `bin/tot.ml`.  The tail stops printing and the battery
   returns to the Stage B report shape.  This alone turns
   PASS-M7C-MULTI-HOLE-TAIL red and leaves every other leg green,
   which is the smallest safe backout.
2. Revert `surface/run.ml`.  `script_tailed` disappears, so the five
   suite cases fail to compile; revert `test/surface.ml` with it.
3. Revert `surface/parser.ml`.  `parse` is already the HEAD function
   and no other module calls `parse_with_holes` after step 2, so
   nothing else moves.
4. Revert the `dev/gates.sh` block, the trap edit at dev/gates.sh:434,
   the PASS-M5D-TIERS literal at dev/gates.sh:2284, the three files
   under `dev/fixtures/`, and the two SPEC.md edits.

After a full revert the battery reads 395 PASS, 0 FAIL, GATE-EXIT=0,
which is the Stage B exit state, the number the Stage B footer states.
No later stage depends on Stage C:
Stage D edits the prelude, the helpers and the literals, and Stage E
edits SPEC and lands the grafted oracles.  A Stage C rollback costs
those stages nothing except the SPEC clause, which Stage E rewrites
anyway.

Gate markers added: 2
Suite cases added: 5
Exit PASS count: 402

## STAGE D: the helper move, the prelude re-spell, the literal re-arithmetic and the transcript reseal (pins 9, 10, 11, 18)

Goal: retire two measured debts in one stage.  The six duplicated
guard helpers become prelude globals, spelled once.  The prelude
stops carrying zero holes and starts carrying 47 holed anchors, which
is the first time the corpus dogfoods the hole slice inside the file
every program loads.  The two gate literals that this move invalidates
are re-derived in the same commit, and the sealed transcript is
regenerated.  No .ml file outside test/surface.ml changes.  No
admission rule changes.  `format_version` stays 10.

---

### D0. Pins owned, verbatim

Pin 9.  "The six shared helpers firstNonEmpty, lastOr, splitEach,
firstToken, orEmpty and elideAt move to stdlib/prelude.tot exactly
once, and the guards reference them.  Only splitEach carries anchor
sites;  the classifier shows guard.tot:48, :49 and guard-rewrap.tot:66,
:67 and no others in shared helper bodies.  Testable:
PASS-M7D-HELPERS-SHARED."

Pin 10.  "Post-move classifier literal, exact and binding:
`ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30`.
Derivation: 101 - 4 + 2 = 99 and 62 - 4 + 2 = 60;  the A and N buckets
do not move.  PASS-M6E-ANCHORS keeps its exact-string comparison and
its `-gt 98` floor still holds at 99.  Testable: PASS-M7D-ANCHORS."

Pin 11.  "The corpus holed-anchor literal walks 22 at HEAD, 24 after
Stage B, 22 after the Stage D move, and the Stage D landed number
after the prelude re-spell, which is 67 if all forty expected-type-only
and all five argument-driven prelude anchors are re-spelled.  The
prelude-carries-zero-holes assertion inside PASS-M6E-GUARD-HOLES flips
at Stage D and is REPLACED by a prelude-holed floor, never deleted.
Re-opening a tripwire's design is the M6 rule;  deleting a leg is
forbidden.  Testable: PASS-M7B and PASS-M7D each edit the literal and
the gate stays green at every stage boundary."

Pin 18.  "No format_version bump.  surface/cache.ml keeps
`format_version = 10`.  The key at cache.ml:343-346 already folds the
prelude source, so the Stage D prelude edit invalidates the cache by
itself;  `load` verifies magic, version, executable digest and body
digest, none of which is a function of the prelude source.  Testable:
PASS-M7D-CACHE-KEY, a miss then a hit across the Stage D prelude
edit."

### D0.1 Pins re-checked here, owned elsewhere

The preamble's coverage convention (preamble section 1.4) lets a pin
carry evidence in a second stage.  Stage D re-checks two pins that it
does not own.  Stage D adds no work item for either one.

Pin 5, owned by Stage B.  "Honest reach, as a number: exactly seven of
the nine A-bucket anchor sites resolve after Stage B.  The seven are
stdlib/prelude.tot:17, :145, :159, :173, :176, examples/guard.tot:133
and examples/guard-rewrap.tot:264.  Testable:
PASS-M7B-GUARD-ARG-HOLES and PASS-M7D-PRELUDE-HOLES."

The Ratification amendment of 2026-09-04 keeps pin 5 at seven anchors
and authorises the infer-path settle in Stage A, part A3b, as the part
that reaches the seventh.  stdlib/prelude.tot:173 is that seventh
anchor.  Stage D re-spells all five prelude members of the list, so
PASS-M7D-PRELUDE-HOLES re-checks the prelude half of the pin.  Stage B
owns the pin, the reach number and PASS-M7B-GUARD-ARG-HOLES.

Two of the five prelude anchors need more than the check-position rule.
Measured at HEAD, one holed prelude copy per anchor, each copy
byte-identical to stdlib/prelude.tot except for the named slot, each
run as `env TOT_PRELUDE=<copy> tot.exe check
/Users/oobi/Documents/tot/examples/church.tot`:

    :17   exit 1   prelude: 17:160: hole: expected Type 0
    :145  exit 1   prelude: 145:79: hole: expected Type 0
    :159  exit 1   prelude: 159:50: hole: no expected type at this position
    :173  exit 1   prelude: 173:39: hole: no expected type at this position
    :176  exit 1   prelude: 176:27: hole: expected Type 0

The three that print `hole: expected Type 0` need Stage A part A3.
:159 needs part A4 as well.  :173 needs part A3b, the infer-path
settle, which Stage A section A9 measures and which the amendment of
2026-09-04 authorises.  Stage D therefore depends on A3b for one anchor
of its 45.  Section D8 carries the retreat if A3b is rolled back.
The copies live under
/Users/oobi/Documents/tot-m7-probes/amend/dsec/var/ as p-a17.tot,
p-a145.tot, p-a159.tot, p-a173.tot and p-a176.tot.

Pin 12, owned by Stage E.  "PASS-M5D-MEASURE-LOG's live literal is 22
lines at dev/gates.sh:3016.  The "count 18" at dev/gates.sh:2531 is a
stale comment and Stage E fixes the comment only.  Any newer anchors
line emitted into SPEC.md goes BELOW SPEC.md:2123, because the leg
reads the LAST `expected-type-only=` spelling in the file.  Testable:
the leg stays green with no literal change."

Stage E fixes the stale comment.  Stage D's only obligation is to leave
PASS-M5D-MEASURE-LOG green with no literal change, because the Stage D
SPEC.md record changes the value that leg reads.

Both of pin 12's citations were re-read at HEAD 66b444f.
`[ "$m5d_lines" -eq 22 ]` sits at dev/gates.sh:3016, as the pin says.
The reader whose VALUE this stage moves is one line above it, at
dev/gates.sh:3015.  The stale "count 18" comment sits at
dev/gates.sh:2531 and Stage E owns it.

---

### D1. Entry state

Entry PASS count: 402, the exit count the Stage C section states in its
own footer.  GATE-EXIT=0 and 0 FAIL at the Stage C boundary is the
precondition;  Stage D starts on a red battery never.  The chain behind
that number is the amended one of 2026-09-04: 371 at HEAD, 390 after
Stage A, 395 after Stage B and 402 after Stage C.  Stage D adds 4 gate
markers and 4 suite cases, so its own exit is 402 + 4 + 4 = 410.

What the earlier stages left in the tree:

- Stage A left the argument-driven settle pass in the elaborator, on
  the check path (part A3) and, under the amendment of 2026-09-04, on
  the infer path too (part A3b).  Stage D spells five prelude anchors
  as `_` and depends on both parts.  Without A3 the prelude does not
  bootstrap.  Without A3b stdlib/prelude.tot:173 does not bootstrap.
  Probes P6, P6b and P6c below are the measurement.
- Stage A's own fixtures sit in dev/m7a/, outside the transcript glob
  at dev/gen-m5e-transcript.sh:13, so the corpus is still 101 files and
  the transcript still 101 blocks at the Stage D entry.
- Stage B left examples/guard.tot:133 and examples/guard-rewrap.tot:264
  re-spelled with `_` and PASS-M6E-GUARD-HOLES's holed literal moved
  from 22 to 24 (dev/gates.sh:3094 at HEAD).  Stage A section A9
  measured that the settle also reaches the two slots at :134 and :265,
  so Stage B re-derives their status.  D3.3 carries the arithmetic for
  either Stage B outcome.
- Stage C left the multi-hole position-only tail in the reporter.  It
  changes no anchor count and reseals no transcript block.
- Stage A, Stage B and Stage C raised the PASS-M5D-TIERS literal by 11,
  6 and 7, each section says so in its own gate paragraph, so the Stage
  D entry value is 169 + 24 = 193 and not 169.
- No earlier stage writes an `expected-type-only=` spelling into
  SPEC.md, so SPEC.md:2123 is still the line PASS-M5D-MEASURE-LOG reads
  at the Stage D entry.
- Stage A resealed two blocks of dev/m5e-default-transcript.txt, so the
  reseal procedure is routine by Stage D.

Measured entry facts at HEAD 66b444f, each with the command that
printed it:

| # | Probe | Command | Measured at HEAD 66b444f, re-run 2026-09-04 |
|---|---|---|---|
| P1 | corpus anchors | `python3 /Users/oobi/Documents/tot/dev/hole-anchors.py \| tail -1` | `ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30` |
| P2 | holed anchors | `python3 .../hole-anchors.py \| rg -c 'anchor=\[_\]'` | 22 |
| P3 | prelude holed anchors | `python3 .../hole-anchors.py \| rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\]'` | no match, rg exit 1, so 0 |
| P4 | prelude sites and buckets | `python3 .../hole-anchors.py \| rg '^SITE stdlib/prelude\.tot:' \| rg -o 'bucket=[A-Z]' \| sort \| uniq -c` | 71 sites: 5 A, 40 E, 26 N |
| P5 | helper lines in the guard transcript | `tot.exe check /Users/oobi/Documents/tot/examples/guard.tot \| rg -c '^def (firstNonEmpty\|lastOr\|splitEach\|firstToken\|orEmpty\|elideAt) '` | 6, and 6 again for guard-rewrap.tot |
| P6 | a check-position A anchor holed in the prelude | `env TOT_PRELUDE=/Users/oobi/Documents/tot-m7-probes/amend/dsec/var/p-a145.tot tot.exe check /Users/oobi/Documents/tot/examples/church.tot` | exit 1, `prelude: 145:79: hole: expected Type 0` |
| P6b | the amendment anchor :173 holed | `env TOT_PRELUDE=/Users/oobi/Documents/tot-m7-probes/amend/dsec/var/p-a173.tot tot.exe check /Users/oobi/Documents/tot/examples/church.tot` | exit 1, `prelude: 173:39: hole: no expected type at this position` |
| P6c | the motive anchor :159 holed | `env TOT_PRELUDE=/Users/oobi/Documents/tot-m7-probes/amend/dsec/var/p-a159.tot tot.exe check /Users/oobi/Documents/tot/examples/church.tot` | exit 1, `prelude: 159:50: hole: no expected type at this position` |
| P7 | E anchors holed in the prelude | `env TOT_PRELUDE=/Users/oobi/Documents/tot-m7-probes/amend/dsec/var/p-e.tot tot.exe check /Users/oobi/Documents/tot/examples/church.tot` (the copy holes `none Json` at :42, `none String` at :43, `none Int` at :44 and `nil Json` at :49) | exit 0, `def cnat : Type 1` |
| P8 | tier population | `rg -c '"\$watchdog" "\$(FAST\|MED\|SLOW\|SUITE)"' /Users/oobi/Documents/tot/dev/gates.sh` | 169 |
| P9 | SPEC anchors reader | `rg -o 'expected-type-only=[0-9]+' /Users/oobi/Documents/tot/SPEC.md \| tail -n 1` | `expected-type-only=62` |
| P10 | cache format version | `rg -c 'let format_version : int = 10' /Users/oobi/Documents/tot/surface/cache.ml` | 1 |
| P11 | corpus size and seal | `ls /Users/oobi/Documents/tot/examples/*.tot /Users/oobi/Documents/tot/test/fixtures/*.tot \| wc -l` and `rg -c '^### ' /Users/oobi/Documents/tot/dev/m5e-default-transcript.txt` | 101 and 101 |

P6, P6b, P6c and P7 together fix the stage order.  The forty
expected-type-only prelude anchors can be re-spelled at HEAD and the
prelude still bootstraps, which P7 shows at exit 0.  None of the five
argument-driven ones can.  Three of the five print the check-position
message and need Stage A part A3.  :159 needs part A4 as well.  :173
needs part A3b.  Stage D therefore runs after Stage A, and its
PRELUDE-HOLES leg is the first live proof that the settle pass reaches
the prelude bootstrap.

The move and the re-spell were both rehearsed at HEAD on copies of the
tree, because dev/hole-anchors.py derives its root from its own path
(dev/hole-anchors.py:66) and reads stdlib/prelude.tot plus examples/*.tot
(dev/hole-anchors.py:86-87).  The move-only tree is
/Users/oobi/Documents/tot-m7-probes/plan/sim/tree.  The full rehearsal,
which is the move plus the two Stage B guard re-spells plus the 45
prelude re-spells, is
/Users/oobi/Documents/tot-m7-probes/amend/dsec/sim2/tree, built by
/Users/oobi/Documents/tot-m7-probes/amend/dsec/respell.py.  The
measurements appear as P12 to P17 in D3.  Nothing under
/Users/oobi/Documents/tot was written.

---

### D2. Files touched

- `stdlib/prelude.tot`.  Gains the six helper definitions with their
  comments, appended after `member` (stdlib/prelude.tot:176).  Loses
  no line.  Then 45 anchors are re-spelled as `_`: the 40
  expected-type-only sites of P4 and the five argument-driven sites at
  :17, :145, :159, :173 and :176.
- `examples/guard.tot`.  Loses six definitions: firstNonEmpty
  (examples/guard.tot:29), lastOr (:36), splitEach (:45), firstToken
  (:54), orEmpty (:80) and elideAt (:89), each with the comment block
  that introduces it.  Keeps baseName (:60) and usesBanned (:63),
  which are guard-specific.
- `examples/guard-rewrap.tot`.  Loses the same six: firstNonEmpty
  (examples/guard-rewrap.tot:49), lastOr (:56), splitEach (:63),
  firstToken (:70), orEmpty (:136) and elideAt (:139).  Keeps
  lastToken (examples/guard-rewrap.tot:78), which calls the moved
  lastOr and splitEach and resolves them from the prelude after the
  move, and the scrubber (examples/guard-rewrap.tot:211), which calls
  none of the six.
- `test/fixtures/m7d-prelude-splitEach.tot`.  NEW, bytes in D6.
- `test/surface.ml`.  Four new cases, registered in the `cases` list
  (test/surface.ml:862).
- `dev/gates.sh`.  One new block of four legs, placed after the Stage C
  block, which itself sits after the Stage A and Stage B blocks that
  follow the M6E block (the M6E block ends at dev/gates.sh:3139 at
  HEAD).  Plus the literal edits at dev/gates.sh:2284, :3088-3089,
  :3094, :3110 and :3131.  Every dev/gates.sh line number in this
  section is a HEAD number.  Stages A, B and C insert lines above them,
  so the builder locates each literal by its marker name and its
  variable name, then records the found line number in
  dev/M7-BUILD-LOG.md.
  Plus TWO Stage A literals that this stage's own edits move.  They have
  no HEAD line number, because Stage A writes their block, so the builder
  finds each by its marker name.
  1. PASS-M7A-CONSERVATIVITY.  The digest covers examples/church.tot,
     guard-classes.tot, guard-rewrap.tot, guard.tot and literals.tot, and
     this stage deletes six helper defs from each of the two guards, so
     twelve `def` lines leave the digested stdout.  Re-derive both
     literals with the leg's own command:
     `for f in church guard-classes guard-rewrap guard literals; do "$X" check "$ROOT"/examples/$f.tot 2>/dev/null; done | md5 -q`
     and the same loop piped to `wc -l`.  At HEAD the pair is
     `99c23b4b74c722735d17e1dc49524e58` and 55, measured 2026-09-04, and
     the line count after this stage is 43.  Record both pairs in
     dev/M7-BUILD-LOG.md and edit the leg to the new pair.
  2. PASS-M7A-INFER-SETTLE-BUDGET.  This stage adds
     test/fixtures/m7d-prelude-splitEach.tot at depth 1 and re-spells the
     prelude and both guards, so `files`, `green` and the md5 all move.
     Re-derive them with the leg's own command, the
     `fd -e tot --max-depth 1` form.  At HEAD the triple is
     `files=100 green=61 md5=9b416b949964a50c4f7633eab478b5c2`, measured
     2026-09-04.  Record the before and after triples in
     dev/M7-BUILD-LOG.md and edit the leg to the new triple.
  Both re-derivations run AFTER the corpus edits of this stage and before
  the gate run, and a re-derived value that the stage cannot explain from
  its own diff stops the stage.
- `dev/m5e-default-transcript.txt`.  REGENERATED by
  dev/gen-m5e-transcript.sh in the same commit.
- `SPEC.md`.  One new dated anchors record BELOW SPEC.md:2123, plus
  one dated Stage D decision entry.
- `dev/M7-BUILD-LOG.md`.  Mutation proofs and the before and after
  numbers of every literal.

NOT touched: `surface/cache.ml` (pin 18), `lib/`, `surface/elab.ml`,
`surface/bootstrap.ml`, `dev/hole-anchors.py`,
`dev/gen-m5e-transcript.sh` (its glob at line 13 picks the new fixture
up by itself), `examples/guard-classes.tot`.

---

### D3. Design

**D3.1 The move.**  The six helper bodies are byte-identical between
the two guards apart from comments.  Measured at HEAD: `diff` of
examples/guard.tot:29-59 against examples/guard-rewrap.tot:49-72 exits
1 with three hunks, seven deleted lines and no added line.  Six of the
seven are comment lines and one is blank, re-measured 2026-09-04.  The
bodies themselves agree.  The prelude therefore takes one copy.  Take
the guard.tot spelling, because it carries the fuller comments.

The appended text is exactly examples/guard.tot:29-56 (firstNonEmpty,
lastOr, splitEach, firstToken, with their comments) and
examples/guard.tot:75-95 (orEmpty and elideAt, with their comments),
under one new dated header comment.  splitEach keeps its two holed
anchors, `nil _` at examples/guard.tot:48 and `append _` at :49.

The two guards then reference the prelude globals.  Nothing else in
either file changes.  `baseName` at examples/guard.tot:60 calls
`lastOr`, `firstToken` at :54 calls `splitEach` and `firstNonEmpty`,
and all three resolve as prelude globals after the move.

**D3.2 The prelude re-spell.**  45 anchors become `_`.  The 40
expected-type-only sites are the P4 E bucket.  The five
argument-driven sites are:

    SITE stdlib/prelude.tot:17 head=map arg=0 anchor=[A] pos=check bucket=A
    SITE stdlib/prelude.tot:145 head=anyList arg=0 anchor=[A] pos=check bucket=A
    SITE stdlib/prelude.tot:159 head=listEqBy arg=0 anchor=[A] pos=check bucket=A
    SITE stdlib/prelude.tot:173 head=listEqBy arg=0 anchor=[A] pos=check bucket=A
    SITE stdlib/prelude.tot:176 head=anyList arg=0 anchor=[A] pos=check bucket=A

Those five lines are the classifier's own output, re-run 2026-09-04.
The classifier's `pos=check` records where the SITE sits in the source,
not what the elaborator does with it;  P6b shows that
stdlib/prelude.tot:173 still reaches the elaborator in infer position.

Before and after for the recursive call at stdlib/prelude.tot:145:

    before:  fun A p xs => match xs with | nil => false | cons h t => orb (p h) (anyList A p t) end
    after:   fun A p xs => match xs with | nil => false | cons h t => orb (p h) (anyList _ p t) end

The later explicit argument `t` infers `List A`, which determines the
holed slot by first-order matching against `anyList`'s declared
formal.  That is the Stage A rule, and pin 3 states it.  At HEAD the
same edit is refused: probe P6 printed
`prelude: 145:79: hole: expected Type 0` at exit 1.

Before and after for the class former at stdlib/prelude.tot:173, the
anchor the amendment of 2026-09-04 adds:

    before:  fun A d => mkEqD (List A) (listEqBy A (eqf A d))
    after:   fun A d => mkEqD (List A) (listEqBy _ (eqf A d))

This one slot needs Stage A part A3b.  The class-former fence hands the
nested argument to `term` (surface/elab.ml:511-522), and `term` carries
no settle at HEAD, so the hole reaches the elaborator with no expected
type.  Probe P6b printed
`prelude: 173:39: hole: no expected type at this position` at exit 1.
Stage A section A9 records the same result for its own mirror fixture.

The 45 re-spells are 21 distinct rewrites, because one line can carry
many sites with the same head and the same anchor: stdlib/prelude.tot:42
carries seven `none Json` sites, :43 seven `none String`, :44 seven
`none Int` and :49 seven `nil Json`.  The rehearsal script
/Users/oobi/Documents/tot-m7-probes/amend/dsec/respell.py prints one
line per rewrite with its replacement count, and the builder can read
that list as the edit plan.

The bucket of a site is computed from the head table and the formal
index, never from the anchor text, so re-spelling moves no site
between buckets.  The totals of pin 10 are therefore a property of the
MOVE alone, not of the re-spell.

**D3.3 The arithmetic, measured at HEAD and on the rehearsal trees.**

Total sites.  101 at HEAD (P1).  The move deletes four splitEach sites
(examples/guard.tot:48, :49 and examples/guard-rewrap.tot:66, :67) and
adds two back inside the prelude copy.  101 - 4 + 2 = 99.

Expected-type-only.  62 at HEAD (P1).  All four deleted sites and both
re-added sites are bucket E.  62 - 4 + 2 = 60.

Measured on the rehearsal trees, not only derived.  `<sim>` is
/Users/oobi/Documents/tot-m7-probes/plan/sim and `<sim2>` is
/Users/oobi/Documents/tot-m7-probes/amend/dsec/sim2:

| # | Probe | Command | Measured |
|---|---|---|---|
| P12 | rehearsal fidelity | `python3 <sim>/tree/dev/hole-anchors.py \| tail -1` on an unmodified copy | 2026-09-03: `ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30` |
| P13 | anchors after the move | same command after the move | 2026-09-03, re-run 2026-09-04: `ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30` |
| P14 | holed after the move | `rg -c 'anchor=\[_\]' <sim>/out/sites-after.txt` | 2026-09-03, re-run 2026-09-04: 20, which is 22 at HEAD minus the four deleted guard sites plus the two the prelude copy carries |
| P15 | prelude after the move | `rg -c '^SITE stdlib/prelude\.tot:' ...` and the bucket count | 2026-09-03, re-run 2026-09-04: 73 sites: 5 A, 42 E, 26 N, of which 2 are already holed |
| P16 | move plus the two Stage B re-spells | `python3 <sim2>/tree/dev/hole-anchors.py`, counted by respell.py | 2026-09-04: `ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30`, holed 22, prelude holed 2, prelude holed with bucket=A 0 |
| P17 | after the 45 prelude re-spells | the same command on the same tree | 2026-09-04: the same ANCHORS line, holed 67, prelude holed 47, prelude holed with bucket=A 5 |

Holed anchors at Stage D exit.  22 on the moved tree with Stage B's two
re-spells present, measured (P16), which is pin 11's walk of 22 at
HEAD, 24 after Stage B and 22 after the move.  The re-spell adds 45.
22 + 45 = 67, measured (P17).

Prelude holed anchors at Stage D exit.  2 after the move (P15, P16),
plus 45.  2 + 45 = 47, measured (P17), five of them bucket=A.  The
examples keep the other 20.  47 + 20 = 67, which agrees with the corpus
number above.  P16 and P17 also show the ANCHORS line unchanged by the
re-spell, which is pin 10's claim that the totals belong to the move.

Contingency, one literal only.  Stage A section A9 measured that the
settle reaches the two guard slots at examples/guard.tot:134 and
examples/guard-rewrap.tot:265, and the amendment tells Stage B to
re-derive their negative status.  If Stage B re-spells those two as
well, its holed literal is 26 and the Stage D corpus literal becomes
26 - 4 + 2 + 45 = 69.  The prelude literal stays 47, because neither
slot is a prelude site.  The builder reads the Stage B exit number from
dev/M7-BUILD-LOG.md and re-runs the classifier.  It does not guess.

**D3.4 The two pinned gate literals that move.**

Literal 1, PASS-M5D-TIERS.  The leg pins the direct watchdog-plus-tier
population with a live literal, `[ "$m5d_tiers" -eq 169 ]` at
dev/gates.sh:2284, derived by the recipe at dev/gates.sh:2282.  At HEAD
the recipe prints 169 (P8).  Stage D adds seven direct tier calls: two
in HELPERS-SHARED, one in PRELUDE-HOLES and four in CACHE-KEY.  ANCHORS
adds none, because it reads `$GATE_LOG`.

The literal walks 169 at HEAD, 180 after Stage A, which adds 11, 186
after Stage B, which adds 6, and 193 after Stage C, which adds 7.  The
Stage D entry value is therefore 193 and the Stage D exit value is 200.
Each of those three numbers is the number that stage's own gate
paragraph states.  In the SAME commit: run the recipe before the
gates.sh edit, run it after, check that the two printed numbers differ
by exactly seven, write the second one into the literal, and record
both in dev/M7-BUILD-LOG.md.  The 193 and the 200 are predictions from
the earlier sections;  the recipe output is the authority, and a
mismatch stops the stage until the earlier stage's log explains it.
Without this edit the battery cannot reach GATE-EXIT=0 at the Stage D
boundary.

Literal 2, PASS-M5D-MEASURE-LOG.  The leg compares the anchors line the
classifier wrote into `$GATE_LOG` this run against the LAST
`expected-type-only=` spelling in SPEC.md, read by
`m5d_specE=$(rg -o 'expected-type-only=[0-9]+' "$ROOT/SPEC.md" | tail -n 1)`
at dev/gates.sh:3015.  At HEAD that read returns
`expected-type-only=62` (P9), and SPEC.md:2123 carries the record it
reads.  After Stage D the classifier writes `expected-type-only=60`, so
SPEC.md gains a new dated record BELOW SPEC.md:2123 spelling
`ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30`.
The comparison literal `[ "$m5d_lines" -eq 22 ]` at dev/gates.sh:3016
does NOT change, because Stage D adds no `gate_timed` call, and neither
do Stages A, B and C.  It is therefore still 22 at the Stage D entry.
The value the leg reads moves from 62 to 60;  the leg text moves not at
all.  Stage B and Stage C each write a dated SPEC.md section 2 entry
and neither spells `expected-type-only=`, and Stage A writes no SPEC.md
entry, so the Stage D record is the first new spelling and SPEC.md:2123
is still the line the leg reads at the Stage D entry.  This is pin 12
honoured, and SPEC.md:2120-2122 already states the ordering rule in
the file itself.

**D3.5 Two more literals that this stage must edit, which the verdict
does not name in its Stage D paragraph.**

The verdict's Stage D paragraph says "PASS-M6E-ANCHORS and
PASS-M6E-GUARD-HOLES have their literals edited" and "PASS-M5E-TRANSCRIPT
reseals in place".  Read at HEAD, that names four edits, not two, and
the transcript marker has two live names:

- `m6e_want` at dev/gates.sh:3110 becomes
  `ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30`.
  The `-gt 98` floor at dev/gates.sh:3112 still holds at 99.
- `m6e_holes` at dev/gates.sh:3088 is compared against 22 at
  dev/gates.sh:3094.  Stage B moved it to 24.  Stage D moves it to 67,
  or to 69 under the D3.3 contingency.  The builder writes the number
  the classifier printed in this run, and PASS-M7D-PRELUDE-HOLES pins
  the prelude half at 47 either way.
- `m6e_pz` at dev/gates.sh:3089 is today the exit status of
  `rg -q 'SITE stdlib/prelude\.tot:.*anchor=\[_\]'`, asserted equal to 1
  at dev/gates.sh:3094.  Pin 11 forbids deleting the leg, so it is
  RE-SPELLED as a floor:

```zsh
m6e_pz=$(rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\]' "$m5d_scratch/hole-sites.txt" || echo 0)
```

  and the assertion becomes `[ "$m6e_pz" -gt 0 ]`.  The exact prelude
  number stays in PASS-M7D-PRELUDE-HOLES, so the two legs do not pin
  the same literal twice.

- `m6e_wantg` at dev/gates.sh:3131 pins examples/guard.tot's transcript
  block byte for byte, and six of its ten `def` lines are the helpers
  this stage moves.  The literal drops those six lines and keeps
  `def baseName`, `def usesBanned`, `def decide` and `def main`.  The
  `rg -A 13` window at dev/gates.sh:3130 shrinks to `rg -A 7`.  The
  marker the verdict calls PASS-M5E-TRANSCRIPT is
  PASS-M5E-DEFAULT-IDENTITY (dev/gates.sh:2420) for the whole-file
  identity and PASS-M6E-TRANSCRIPT-RESEALED (dev/gates.sh:3135) for the
  block pin.  Both reseal in place;  neither gains a marker.

Measured at HEAD on the rehearsal tree, the moved guard prints four
lines and keeps its behaviour:

    $ env TOT_PRELUDE=<moved prelude> tot.exe check <moved guard.tot>
    def baseName : (w _ : String) -> String
    def usesBanned : (w _ : String) -> Bool
    def decide : (w _ : Json) -> Verdict
    def main : (IO Verdict)
    exit=0

    $ env TOT_PRELUDE=<moved prelude> tot.exe run <moved guard.tot> < test/fixtures/deny.json
    {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo /tmp/x)"}}
    exit=2

That envelope is byte-identical to `m6e_wantenv` at dev/gates.sh:3092,
and the exit 2 matches `[ "$m6e_c9" -eq 2 ]` at dev/gates.sh:3095, so
the four behaviour assertions of PASS-M6E-GUARD-HOLES stay green
through the move.

**D3.6 Line numbers move.**  The move deletes 49 lines from
examples/guard.tot and 36 from examples/guard-rewrap.tot in the
rehearsal spelling, so the A slots shift: examples/guard.tot:133 and
:134 became :84 and :85, and examples/guard-rewrap.tot:264 and :265
became :228 and :229.  The exact shift depends on how many comment
lines the builder keeps.  Re-run the classifier after the edit and
record the new site list in dev/M7-BUILD-LOG.md.  Pin 5's site list is
a HEAD list;  it is not re-written by this stage, and Stage E's SPEC
entry carries the post-move numbers.

**D3.7 The four new suite cases (test/surface.ml).**  House style:
no exceptions, no match on an option or a result, exhaustive matches,
`match ()` guards instead of else-if ladders.

```ocaml
(* M7 Stage D, case 1: the six helpers are prelude globals. *)
let case_prelude_defines_the_shared_helpers (bst : Tot_surface.Run.state) () :
    (unit, string) result =
  let found (name : string) : (unit, string) result =
    Tot_kernel.Global.find_def name bst.Tot_surface.Run.globals
    |> Option.to_result ~none:("M7D: " ^ name ^ " is not a prelude global")
    |> Result.map (fun _ -> ())
  in
  [ "firstNonEmpty"; "lastOr"; "splitEach"; "firstToken"; "orEmpty"; "elideAt" ]
  |> List.fold_left (fun acc name -> Result.bind acc (fun () -> found name)) (Ok ())
```

```ocaml
(* M7 Stage D, case 2: the re-spelled prelude bootstraps, and the
   migrated splitEach erases. *)
let case_holed_prelude_bootstraps () : (unit, string) result =
  Tot_surface.Bootstrap.state ()
  |> Result.map_error Tot_surface.Serror.to_string
  |> Result.bind (fun (bst : Tot_surface.Run.state) ->
         Tot_kernel.Global.find_def "splitEach" bst.Tot_surface.Run.globals
         |> Option.to_result ~none:"M7D: splitEach missing after bootstrap"
         |> Result.bind (fun d ->
                Tot_kernel.Erase.closed d.Tot_kernel.Global.def
                |> Result.map_error Tot_kernel.Error.to_string
                |> Result.map (fun _ -> ())))
```

```ocaml
(* M7 Stage D, case 3: the cache key folds the prelude source, so the
   Stage D edit re-keys without a format_version bump (pin 18). *)
let case_cache_key_folds_the_prelude_source () : (unit, string) result =
  let k1 = Tot_surface.Cache.key "-- prelude one" in
  let k2 = Tot_surface.Cache.key "-- prelude two" in
  match () with
  | () when String.equal k1 k2 ->
      Error "M7D: two prelude sources produced one cache key"
  | () when Int.equal (String.length k1) 0 ->
      Error "M7D: the cache key is empty"
  | () -> Ok ()
```

```ocaml
(* M7 Stage D, case 4: neither guard example defines a helper any
   more.  A source assertion, because the duplication was a source
   fact. *)
let case_guards_define_no_shared_helper () : (unit, string) result =
  let names =
    [ "firstNonEmpty"; "lastOr"; "splitEach"; "firstToken"; "orEmpty"; "elideAt" ]
  in
  let defines (src : string) (name : string) : bool =
    src |> String.split_on_char '\n'
        |> List.exists (fun line ->
               String.starts_with ~prefix:("def " ^ name ^ " ") line
               || String.starts_with ~prefix:("def rec " ^ name ^ " ") line)
  in
  [ "examples/guard.tot"; "examples/guard-rewrap.tot" ]
  |> List.fold_left
       (fun acc rel ->
         let src = In_channel.with_open_text (Filename.concat repo_root rel) In_channel.input_all in
         names
         |> List.fold_left
              (fun acc name ->
                match () with
                | () when defines src name ->
                    Error ("M7D: " ^ rel ^ " still defines " ^ name)
                | () -> acc)
              acc)
       (Ok ())
```

Registration: four `( "name", fn )` entries appended to the `cases`
list at test/surface.ml:862, in the shape every entry there already
uses.  Case 1 and case 2 take the bootstrapped state the list already
threads.  Four cases print four `PASS <name>` lines
(test/surface.ml:1913), which is the +4 of the stage arithmetic.

---

### D4. Gate additions

Placement: one new block after the Stage C block.  Stages A, B and C
each put their block after the M6E block, which ends at
dev/gates.sh:3139 at HEAD, and before the ctxcat id 5 comment at
dev/gates.sh:3141.  Stage D's block goes last of the four, and still
above the two timing-sensitive tail legs at dev/gates.sh:3172 and
dev/gates.sh:3190, which stay the file's tail.  The block reuses `$m5d_bin`
(dev/gates.sh:2226), `$m5d_scratch/hole-sites.txt` (dev/gates.sh:2225),
`$GATE_LOG` (dev/gates.sh:68) and the `FAST` tier (dev/gates.sh:44),
the way the M6E block does.  Every leg emits its PASS line with the
house shape: `{ assertions; } && echo PASS-NAME || { diagnostics; echo
"FAIL-NAME (...)"; exit 1; }`.  No leg uses `gate_timed`, so
PASS-M5D-MEASURE-LOG's count of 22 is untouched.  No leg spells a
numeric watchdog literal, so `m5d_nolit` at dev/gates.sh:2284 stays 1.

    Marker: PASS-M7D-HELPERS-SHARED
    Pin: 9
    Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/examples/guard.tot | rg -c '^def (firstNonEmpty|lastOr|splitEach|firstToken|orEmpty|elideAt) ' || echo 0
    At HEAD: exit 0, output contains "6"
    After stage: exit 0, output contains "0"
    Non-vacuous because: at HEAD both guards define all six helpers, so the checker prints six helper lines per guard; a move that edits only one file, or that leaves one copy behind, keeps a non-zero count.

The leg runs the same command on examples/guard-rewrap.tot (6 at HEAD,
0 after), asserts both guards exit 0, and asserts each helper name
occurs exactly once as a definition in stdlib/prelude.tot:

```zsh
# PASS-M7D-HELPERS-SHARED (pin 9).  Four assertions: neither guard
# defines a shared helper any more, both guards still check at exit 0,
# and stdlib/prelude.tot defines each of the six exactly once.  The
# six-lines-per-guard count is the HEAD picture (plan D1 probe P5).
m7d_g1=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard.tot 2>&1); m7d_c1=$?
m7d_g2=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard-rewrap.tot 2>&1); m7d_c2=$?
m7d_hre='^def (rec )?(firstNonEmpty|lastOr|splitEach|firstToken|orEmpty|elideAt) '
m7d_dup=$(printf '%s\n%s\n' "$m7d_g1" "$m7d_g2" | rg -c "$m7d_hre" || echo 0)
m7d_pre=$(rg -c "$m7d_hre" "$ROOT"/stdlib/prelude.tot || echo 0)
{ [ "$m7d_c1" -eq 0 ] && [ "$m7d_c2" -eq 0 ] \
  && [ "$m7d_dup" -eq 0 ] && [ "$m7d_pre" -eq 6 ]; } \
  && echo PASS-M7D-HELPERS-SHARED \
  || { printf '%s\n%s\n' "$m7d_g1" "$m7d_g2"; \
       echo "FAIL-M7D-HELPERS-SHARED (c=$m7d_c1/$m7d_c2 dup=$m7d_dup pre=$m7d_pre)"; exit 1; }
```

    Marker: PASS-M7D-PRELUDE-HOLES
    Pin: 11, and pin 5's prelude half (pin 5 is owned by Stage B, section D0.1)
    Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/examples/guard-classes.tot > /dev/null && { python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\]' || echo 0; }
    At HEAD: exit 0, output contains "0"
    After stage: exit 0, output contains "47"
    Non-vacuous because: at HEAD stdlib/prelude.tot carries zero holed anchors, which PASS-M6E-GUARD-HOLES asserts today at dev/gates.sh:3089, and the five argument-driven prelude anchors cannot even be spelled at HEAD (P6 printed `prelude: 145:79: hole: expected Type 0` and P6b printed `prelude: 173:39: hole: no expected type at this position`, both at exit 1).  The 47 is 2 + 40 + 5: the two migrated splitEach sites the move carries in already holed, plus the 40 expected-type-only and 5 argument-driven prelude sites the re-spell rewrites.  Both migrated sites are bucket=E, so pin 10's A and N buckets still do not move.  The 47 and the 5 were measured on the full rehearsal tree, not derived: probe P17 printed prelude holed 47 with 5 of them bucket=A.  Re-measured at HEAD 2026-09-04: the command above printed 0, `rg '^SITE stdlib/prelude\.tot' | rg -o 'bucket=[A-Z]' | sort | uniq -c` printed 5 A, 40 E and 26 N, and `rg -c '^SITE stdlib/prelude\.tot:.*anchor=\[_\]'` printed nothing at exit 1.  The leg also depends on Stage A part A3b for the single anchor at stdlib/prelude.tot:173;  if A3b is rolled back the literal is 46 and 4, which section D8 spells out.

The leg reads the site list Gate D already wrote, so it adds one tier
call, not a classifier run:

```zsh
# PASS-M7D-PRELUDE-HOLES (pin 11, and pin 5's prelude half).  Three
# assertions: the prelude carries exactly 47 holed anchors (45
# re-spelled plus the two the migrated splitEach body brings), the five
# argument-driven prelude sites are among them, and a prelude consumer
# still checks at exit 0.  47 = 2 + 40 + 5.  The two migrated sites are
# bucket=E, so pin 10's "the A and N buckets do not move" holds and the
# A count below stays 5.  The walk is in dev/M7-BUILD-LOG.md.
m7d_ph=$(rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\]' "$m5d_scratch/hole-sites.txt" || echo 0)
m7d_pa=$(rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\].*bucket=A' "$m5d_scratch/hole-sites.txt" || echo 0)
m7d_cls=$("$watchdog" "$FAST" "$m5d_bin" check "$ROOT"/examples/guard-classes.tot 2>&1); m7d_c3=$?
{ [ "$m7d_ph" -eq 47 ] && [ "$m7d_pa" -eq 5 ] && [ "$m7d_c3" -eq 0 ]; } \
  && echo PASS-M7D-PRELUDE-HOLES \
  || { printf '%s\n' "$m7d_cls"; \
       echo "FAIL-M7D-PRELUDE-HOLES (holed=$m7d_ph argdriven=$m7d_pa check=$m7d_c3)"; exit 1; }
```

    Marker: PASS-M7D-ANCHORS
    Pin: 10
    Command: python3 /Users/oobi/Documents/tot/dev/hole-anchors.py | tail -1
    At HEAD: exit 0, output contains "ANCHORS total=101 expected-type-only=62 argument-driven=9 neither=30"
    After stage: exit 0, output contains "ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30"
    Non-vacuous because: the move deletes four anchor sites and re-adds two, so the exact-string comparison at HEAD reads 101 and 62 and cannot match the post-move literal; the rehearsal run of the same command on the moved tree printed the post-move line (probe P13).

```zsh
# PASS-M7D-ANCHORS (pin 10).  The classifier line this run wrote into
# $GATE_LOG equals pin 10's exact literal.  Derivation:
# 101 - 4 + 2 = 99 and 62 - 4 + 2 = 60 (the four splitEach sites in the
# two guards become two in the prelude);  A and N do not move.  Schema
# and bucket-sum stay owned by PASS-M5D-HOLE-ANCHORS upstream.
m7d_line=$(rg -o '^ANCHORS total=[0-9]+ expected-type-only=[0-9]+ argument-driven=[0-9]+ neither=[0-9]+$' "$GATE_LOG")
m7d_want='ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30'
{ [ "$m7d_line" = "$m7d_want" ]; } \
  && echo PASS-M7D-ANCHORS \
  || { printf '%s\n' "$m7d_line"; echo "FAIL-M7D-ANCHORS (line=$m7d_line)"; exit 1; }
```

PASS-M6E-ANCHORS keeps its own exact-string leg at dev/gates.sh:3110
with the same new literal.  The two legs read the same line for
different reasons: M6E pins the M6 corpus growth, M7D pins pin 10's
arithmetic.  Both are edited in this commit.

    Marker: PASS-M7D-CACHE-KEY
    Pin: 18
    Command (post-stage): T=/Users/oobi/Documents/tot; X=$T/_build/default/bin/tot.exe; FX=$T/test/fixtures/m7d-prelude-splitEach.tot; CK=$T/_build/m7d-ck; ALT=$T/_build/m7d-prelude-alt.tot; [ -f "$FX" ] || { echo MISSING-FIXTURE; exit 9; }; rm -rf "$CK"; mkdir -p "$CK"; cp $T/stdlib/prelude.tot "$ALT"; printf -- '-- M7 Stage D cache leg: one added comment line, one new key.\n' >> "$ALT"; c=$(env TOT_CACHE_DIR="$CK" TOT_PRELUDE=$T/stdlib/prelude.tot $X check "$FX" 2>&1); e1=$?; n1=$(command ls "$CK"/prelude-*.bin 2>/dev/null | wc -l | tr -d ' '); w=$(env TOT_CACHE_DIR="$CK" TOT_PRELUDE=$T/stdlib/prelude.tot $X check "$FX" 2>&1); e2=$?; n2=$(command ls "$CK"/prelude-*.bin 2>/dev/null | wc -l | tr -d ' '); r=$(env TOT_CACHE_DIR="$CK" TOT_PRELUDE="$ALT" $X check "$FX" 2>&1); e3=$?; n3=$(command ls "$CK"/prelude-*.bin 2>/dev/null | wc -l | tr -d ' '); printf 'exits=%d/%d/%d entries=%d/%d/%d fv=%s\n' $e1 $e2 $e3 $n1 $n2 $n3 "$(rg -c 'let format_version : int = 10' $T/surface/cache.ml)"; printf '%s\n%s\n%s\n' "${c##*/}" "${w##*/}" "${r##*/}"
    Command measured at HEAD: the same line with FX=/Users/oobi/Documents/tot-m7-probes/amend/dsec/fx/m7d-prelude-splitEach.tot, the identical bytes, and CK and ALT under /Users/oobi/Documents/tot-m7-probes/amend/dsec/, because the fixture lands in this stage.
    At HEAD: exit 0, and that command printed "exits=1/1/1 entries=1/1/2 fv=1" on 2026-09-04, with all three message lines reading "m7d-prelude-splitEach.tot:2:17: unknown name splitEach".
    After stage: exit 0, output contains "exits=0/0/0 entries=1/1/2 fv=1" and all three message lines read "def probeSplit : (w _ : String) -> (w _ : (List String)) -> (List String)"
    Non-vacuous because: the command is the cold, warm and re-keyed recipe the shipping leg runs, not a single check, so it observes the cache key that pin 18 names and not only the signature.  splitEach is not a prelude global at HEAD, so all three runs fail there and the `exits` field must flip 1/1/1 to 0/0/0.  The `entries` field is the key evidence: it reads 1 after the cold run, still 1 after the warm run, which is the hit, and 2 after the run with the altered prelude source, which is the re-key, and it reads 1/1/2 both at HEAD and after the stage, so a build that dropped `prelude_src` from the key would print 1/1/1 and fail.  `fv=1` holds format_version at 10 (surface/cache.ml:118).  A leg that ran one check and asserted the signature only would pass on any build that carries splitEach in the prelude, whatever its keying.

Rehearsal transcript at HEAD, one private cache dir, four runs, all
against the fixture bytes of D6.  The alt prelude is the HEAD prelude
plus one appended comment line, which is the smallest byte change that
can re-key:

    cold, HEAD prelude -> exit 1, "unknown name splitEach", entries 1
    warm, HEAD prelude -> exit 1, same line, entries 1        (the hit)
    same dir, alt prelude -> exit 1, same line, entries 2     (the re-key)
    warm, alt prelude  -> exit 1, same line, entries 2        (the hit)

The dir then held prelude-6108d20e15e36f8811356bb000bf20d4.bin,
prelude-78bb210d6b11fb9443a9cc4984fe7795.bin and one exeid file.  The
entry count going 1 to 2 with no `format_version` bump is pin 18's
claim, measured.  All four runs exit 1 at HEAD, because the fixture
needs the moved helper.  A fifth run, same fixture, `TOT_PRELUDE` set
to the moved prelude of the rehearsal tree, printed
`def probeSplit : (w _ : String) -> (w _ : (List String)) -> (List String)`
at exit 0.  That is the line the leg asserts, and it is why the leg
compares ELABORATION and not two file names, which is the attack's F4
finding honoured.

One more measured fact, which fixes the stage order a second time.  The
same fixture against the fully re-spelled prelude of the sim2 rehearsal
tree exits 1 at HEAD with `prelude: 17:160: hole: expected Type 0`, the
first re-spelled anchor in file order.  Stage D cannot land before
Stage A.

```zsh
# PASS-M7D-CACHE-KEY (pin 18).  Five assertions in one private cache
# dir: (a) a cold run stores exactly one prelude entry; (b) the warm
# re-run is a hit with byte-identical stdout and still one entry;
# (c) the fixture that USES the moved helper checks at exit 0, which is
# the observable that flips in this stage; (d) a run with the old
# prelude source in the SAME dir stores a SECOND entry, so the key
# folds the prelude source (surface/cache.ml:343-346); (e)
# format_version is still 10 (surface/cache.ml:118).  Mutation proof in
# dev/M7-BUILD-LOG.md: delete the six helpers from the prelude copy and
# (c) goes red at "unknown name splitEach".
m7d_ck="$m5d_scratch/ck"
m7d_alt="$m5d_scratch/prelude-alt.tot"
cp "$ROOT"/stdlib/prelude.tot "$m7d_alt"
printf -- '-- M7 Stage D cache leg: one added comment line, one new key.\n' >> "$m7d_alt"
m7d_cold=$("$watchdog" "$FAST" env TOT_CACHE_DIR="$m7d_ck" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
  "$m5d_bin" check "$ROOT"/test/fixtures/m7d-prelude-splitEach.tot 2>&1); m7d_c4=$?
m7d_n1=$(command ls "$m7d_ck"/prelude-*.bin 2> /dev/null | wc -l | tr -d ' ')
m7d_warm=$("$watchdog" "$FAST" env TOT_CACHE_DIR="$m7d_ck" TOT_PRELUDE="$ROOT"/stdlib/prelude.tot \
  "$m5d_bin" check "$ROOT"/test/fixtures/m7d-prelude-splitEach.tot 2>&1); m7d_c5=$?
m7d_n2=$(command ls "$m7d_ck"/prelude-*.bin 2> /dev/null | wc -l | tr -d ' ')
m7d_re=$("$watchdog" "$FAST" env TOT_CACHE_DIR="$m7d_ck" TOT_PRELUDE="$m7d_alt" \
  "$m5d_bin" check "$ROOT"/test/fixtures/m7d-prelude-splitEach.tot 2>&1); m7d_c6=$?
m7d_n3=$(command ls "$m7d_ck"/prelude-*.bin 2> /dev/null | wc -l | tr -d ' ')
m7d_fv=$(rg -c 'let format_version : int = 10' "$ROOT"/surface/cache.ml)
m7d_wantsig='def probeSplit : (w _ : String) -> (w _ : (List String)) -> (List String)'
{ [ "$m7d_c4" -eq 0 ] && [ "$m7d_c5" -eq 0 ] && [ "$m7d_c6" -eq 0 ] \
  && [ "$m7d_cold" = "$m7d_wantsig" ] && [ "$m7d_warm" = "$m7d_wantsig" ] \
  && [ "$m7d_re" = "$m7d_wantsig" ] \
  && [ "$m7d_n1" -eq 1 ] && [ "$m7d_n2" -eq 1 ] && [ "$m7d_n3" -eq 2 ] \
  && [ "$m7d_fv" -eq 1 ]; } \
  && echo PASS-M7D-CACHE-KEY \
  || { printf '%s\n%s\n%s\n' "$m7d_cold" "$m7d_warm" "$m7d_re"; \
       echo "FAIL-M7D-CACHE-KEY (exits=$m7d_c4/$m7d_c5/$m7d_c6 entries=$m7d_n1/$m7d_n2/$m7d_n3 fv=$m7d_fv)"; exit 1; }
```

Leg (d) changes the prelude source by one appended comment line, which
is the smallest byte change that can re-key.  Measured at HEAD with
that exact recipe: entries went 1, 1, 2 across cold, warm and re-keyed.
All three runs exited 1 at HEAD, at `unknown name splitEach`, and all
three exit 0 after the stage.  A leg that asserted only two
different file names would pass at HEAD before any edit, which is the
attack's F4 finding;  this leg asserts the printed signature too, and
that line only exists after the move.  The four watchdog calls of this
block are four of the seven the PASS-M5D-TIERS coordination in D3.4
counts.

---

### D5. The transcript reseal

dev/gen-m5e-transcript.sh globs `examples/*.tot test/fixtures/*.tot`,
so this stage regenerates dev/m5e-default-transcript.txt in the same
commit, diffs the old file against the new one, and reviews the diff.
Expected diff content, and nothing else:

1. examples/guard.tot's block loses six `def` lines.
2. examples/guard-rewrap.tot's block loses six `def` lines.
3. One new `### test/fixtures/m7d-prelude-splitEach.tot` block with
   `#exit 0` and one `def probeSplit` line.

Block count and file count both rise by one, from 101 to 102.  At HEAD
both are 101 (probe P11), and no earlier M7 stage adds a file inside
the glob: Stage A's fixtures sit in dev/m7a/, Stage B adds none and
Stage C's sit outside the glob as well.  Stage A reseals two blocks in
place and adds none.  Record the two numbers in dev/M7-BUILD-LOG.md and
in the SPEC entry.  Any other diff hunk is a behaviour change and stops
the stage.

---

### D6. Fixture bytes

Target path: `test/fixtures/m7d-prelude-splitEach.tot`

```
def probeSplit : String -> List String -> List String :=
  fun sep xs => splitEach sep xs
```

At HEAD these bytes fail with
`m7d-prelude-splitEach.tot:2:17: unknown name splitEach` at exit 1.
After Stage D they check at exit 0 and print
`def probeSplit : (w _ : String) -> (w _ : (List String)) -> (List String)`.
The file adds no anchor site, because dev/hole-anchors.py reads
stdlib/prelude.tot and examples/*.tot only (dev/hole-anchors.py:86-87),
so pin 10's literal is unaffected by it.

---

### D7. Review checklist

1. `dunecho build` green, then the whole battery from a clean run:
   GATE-EXIT=0, 0 FAIL.
2. `python3 dev/hole-anchors.py | tail -1` prints
   `ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30`.
3. `python3 dev/hole-anchors.py | rg -c 'anchor=\[_\]'` prints 67, or
   prints 69 if Stage B re-spelled the two slots at
   examples/guard.tot:134 and examples/guard-rewrap.tot:265 (D3.3).
   The number in dev/gates.sh:3094 is the number this command printed.
4. `python3 dev/hole-anchors.py | rg -c 'SITE stdlib/prelude\.tot:.*anchor=\[_\]'`
   prints 47, of which five carry `bucket=A`.
5. Each of the six helper names occurs exactly once as a definition in
   stdlib/prelude.tot and zero times in examples/.
6. `rg -o 'expected-type-only=[0-9]+' SPEC.md | tail -n 1` prints
   `expected-type-only=60`, and the new record sits BELOW SPEC.md:2123.
7. `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` equals
   the Stage D entry value plus exactly 7, which the D3.4 chain predicts
   as 193 before the edit and 200 after it, and dev/gates.sh:2284 carries
   the printed number.  Both numbers are in dev/M7-BUILD-LOG.md.
8. `rg -c 'let format_version : int = 10' surface/cache.ml` prints 1,
   and `git diff --stat` shows no change under surface/ or lib/.
9. The transcript diff carries only the three hunks of D5, the block
   count and the file count both read 102, and the guard block literal
   at dev/gates.sh:3131 matches the new block.
10. examples/guard.tot's deny envelope on test/fixtures/deny.json is
    byte-identical to `m6e_wantenv` at dev/gates.sh:3092, at exit 2.
11. Mutation proofs run and logged: (a) leave one helper copy in
    examples/guard-rewrap.tot, PASS-M7D-HELPERS-SHARED goes red;
    (b) restore one prelude anchor to its explicit spelling,
    PASS-M7D-PRELUDE-HOLES reads 46 and goes red; (c) revert the move
    only, PASS-M7D-ANCHORS reads 101 and goes red; (d) delete the six
    helper definitions from stdlib/prelude.tot, PASS-M7D-CACHE-KEY goes
    red on the signature assertion with `unknown name splitEach`.  Each mutation restored and
    the file digest logged.
12. The four suite cases print four `PASS` lines and the suite count
    rises by exactly four.
13. `env TOT_PRELUDE=<the new prelude> tot.exe check <any corpus file>`
    exits 0, which proves the re-spelled prelude still bootstraps.  At
    HEAD the same command exits 1 at
    `prelude: 17:160: hole: expected Type 0`, so this check also proves
    that Stage A landed first.
14. The user commits.  No agent commits (the M6 rule).

---

### D8. Rollback

The stage is one commit.  Roll back with `git revert` of that commit,
which restores stdlib/prelude.tot, both guards, the fixture, the four
gates.sh literals, the gates.sh block, the transcript and the SPEC
record together.  Partial rollback is forbidden: the gate literals and
the corpus are one unit, and any half-state leaves
PASS-M6E-ANCHORS or PASS-M6E-GUARD-HOLES red.

One retreat belongs to Stage A and lands here.  Stage A's rollback step
2 reverts part A3b, the infer-path settle, on its own.  Without A3b the
anchor at stdlib/prelude.tot:173 returns to
`hole: no expected type at this position`, measured as P6b, so Stage D
re-spells 44 anchors and not 45.  Every derived number then moves by
one: PASS-M7D-PRELUDE-HOLES reads 46 with 4 bucket=A entries, and
`m6e_holes` reads 66, or 68 under the D3.3 contingency.  Pin 10's
literal stays at 99 and 60, because the totals belong to the move.
Taking that step re-opens the ruling the amendment of 2026-09-04
closed, so it needs a new user ruling and not a builder decision, and
the same sentence appears in Stage A.

If only the prelude re-spell is in doubt and the move is sound, the
smaller retreat is to restore the 45 anchors to their explicit
spelling and to move PASS-M7D-PRELUDE-HOLES's literal from 47 to 2,
`m6e_holes` from 67 to 22 and the `m6e_pz` floor from `-gt 0` to
`-gt 1`.  Pin 10's literal stays at 99 and 60 in that retreat, because
the totals belong to the move.  Record the retreat in SPEC.md as a
dated entry, with the reason, and hand the re-spell to M8.

Stale caches are not a rollback hazard: the key folds the prelude
source (surface/cache.ml:343-346), so a reverted prelude re-keys to
its old entry by itself.

Gate markers added: 4
Suite cases added: 4
Exit PASS count: 410

## STAGE E: SPEC repair, the grafted oracles, debts (h) and (i), and the exit (pins 12, 14, 15, 16, 17)

Goal: pay the paper debts M7 opened and hand M8 working tripwires.  Three
things land.  SPEC.md sections 5 and 6 stop lying about where M7 is and
what it measured, and five citations are corrected against HEAD.  Three
fixtures land in test/fixtures/ as oracles for rules M7 does NOT build:
one accessibility-shaped descent from a non-seed formal, one renamed
accessibility control, and the two-layer polarity launder.  Debt (h)'s
licence half and debt (i)'s instance decision are closed and pinned.  No
.ml file changes except one comment in lib/check.ml, so the binary's
behaviour on every existing file is unchanged and the reseal this stage
pays is an additions-only reseal.

Debt (j) is NOT Stage E work.  The stale `spine` doc comment at
surface/elab.ml:473-476 belongs to Stage A under PASS-M7A-SPINE-COMMENT,
because Stage A rewrites the function that comment heads.  Stage E's
review checklist verifies the Stage A landing rather than repeating it.

---

### Pins covered (verbatim pin text from the verdict)

Pin 12.  "PASS-M5D-MEASURE-LOG's live literal is 22 lines at
dev/gates.sh:3016.  The "count 18" at dev/gates.sh:2531 is a stale
comment and Stage E fixes the comment only.  Any newer anchors line
emitted into SPEC.md goes BELOW SPEC.md:2123, because the leg reads the
LAST `expected-type-only=` spelling in the file.  Testable: the leg stays
green with no literal change."

Pin 14.  "Grafted WF oracle.  Stage E lands a negative fixture whose
descent is accessibility-shaped over a family with the right parameter
count, relation formal and index, but whose recursive call descends on a
formal that is NOT the candidate's principal seed.  It must exit 1 at
HEAD and at M7 exit.  Reason: bad2, crossformal-t and deep2 are
parameterless, relationless and indexless, so they cannot discriminate a
recognizer-based rule, and M8 must not inherit a vacuous oracle.
Testable: PASS-M7E-WF-PROVENANCE-ORACLE."

Pin 15.  "Grafted positivity oracle.  Stage E lands the two-layer launder
and its one-layer control as negative fixtures, both at exit 1, with the
transcripts recorded above.  M8's nesting work must keep both rejected,
or state in SPEC.md, in those words, which one it admits and why.
Testable: PASS-M7E-POSITIVITY-LAUNDER-ORACLE."

Pin 16.  "Interp.Frozen and the `Quantity.Zero` arm of `Run.compute_guard`
are unchanged in M7.  The emptiness claim at lib/interp.ml:85-91 is
recorded in SPEC.md as an OPEN obligation with both horns named and is
not asserted as proved.  Testable: PASS-M7E-SPEC-CITATIONS includes the
obligation text and a no-diff assertion on the two code sites."

Pin 17.  "Debt (i), instance rule threading.  `Check.define_instance`
keeps passing `~rule:Totality.Structural` and keeps passing no `~rec_`;
the decision is recorded as a comment and pinned by a test.  Neither the
semantics proposal's pin 13 nor the hardening proposal's pin 11 is taken:
both spell a change that does not compile, because `define`'s `~rule` is
required and neither supplies a default.  Testable:
PASS-M7E-INSTANCE-RULE."

Stage E also obeys pin 13 (marker namespace) and pin 1 (no admission rule
in lib/ changes).  It touches no admission rule, no `Term.t` arm and no
driver flag.

The Ratification amendment of 2026-09-04 reaches Stage E through the
SPEC text and nowhere else.  It authorises the infer-path settle as
Stage A work, so the verdict's scope-out 8 is retired and pin 6's two
explicit-forever slots are re-derived in Stage B.  Stage E records those
outcomes.  It re-derives nothing itself, and it adds no marker for them,
because Stage A and Stage B already pin them.

---

### Entry state

Entry PASS count: 410, 0 FAIL, GATE-EXIT=0.  That is the exit count the
Stage D section states in its own footer.  The amended section footers
run 371 at HEAD, 390 after Stage A, 395 after Stage B, 402 after Stage C
and 410 after Stage D.  Every step of that chain is the previous exit
plus the stage's own markers and suite cases, and it matches the Chain
line of the preamble.  Stage E is the last stage, so every number below
is a delta on the Stage D exit tree and not a number of its own.  Stage
E adds 5 markers and 5 suite cases, so its exit is 410 + 5 + 5 = 420.

What the earlier stages leave in the tree that Stage E depends on:

- Stage A leaves the argument-driven settle pass in surface/elab.ml on
  BOTH the check path and the infer path, the seven Stage A markers,
  including PASS-M7A-INFER-SETTLE and PASS-M7A-INFER-SETTLE-BUDGET, and
  debt (j)'s corrected `spine` doc comment.  The infer half is Stage A
  work under the Ratification amendment of 2026-09-04, which authorises
  the infer-path settle and retires the verdict's scope-out 8.  Pin 2
  still holds: the settle may change only programs that fail at HEAD
  with the hole error.
- Stage B leaves all FOUR guard A slots re-spelled as holes.  The Stage
  A infer settle elaborates the holed `liftIO _ (...)` argument that pin
  6's reason rested on (surface/elab.ml:287-291 is the infer entry that
  refused it at HEAD), so Stage B retires the two explicit-forever
  negatives and moves the refusal obligation to
  test/fixtures/m7/m7b-arg-slot-undetermined.tot, whose every later
  argument is a hole.  PASS-M7B-LIFTIO-SLOT-CLOSES pins the close and
  PASS-M7B-GUARD-ARG-HOLES pins the four holed slots.
- Stage C leaves the multi-hole position-only tail, collected inside a
  traversal that exists at HEAD, with the `Serror` type unchanged.  That
  is the strict reading of "no second traversal" the Ratification
  amendment fixed at Q2.
- Stage D leaves the six shared helpers in stdlib/prelude.tot, the
  re-spelled prelude, the re-derived literals
  (`ANCHORS total=99 expected-type-only=60 argument-driven=9 neither=30`,
  pin 10) and a resealed transcript.

Measured at HEAD 66b444f, for the arithmetic Stage E does on top of the
Stage D exit values:

    /Users/oobi/.cargo/bin/rg -c '^### ' /Users/oobi/Documents/tot/dev/m5e-default-transcript.txt
                                                        # 101
    /bin/ls /Users/oobi/Documents/tot/examples/*.tot /Users/oobi/Documents/tot/test/fixtures/*.tot | /usr/bin/wc -l
                                                        # 101
    /Users/oobi/.cargo/bin/rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' /Users/oobi/Documents/tot/dev/gates.sh
                                                        # 169
    /Users/oobi/.cargo/bin/rg -o 'expected-type-only=[0-9]+' /Users/oobi/Documents/tot/SPEC.md | /usr/bin/tail -n 1
                                                        # expected-type-only=62
    /Users/oobi/.cargo/bin/rg -c 'PASS-M7' /Users/oobi/Documents/tot/dev/gates.sh
                                                        # no match, exit 1

The PASS-M5D-TIERS literal is `[ "$m5d_tiers" -eq 169 ]` at
dev/gates.sh:2284 and is derived at dev/gates.sh:2282 by the same rg
command.  The M6 Stage H comment at dev/gates.sh:2271-2274 records the
last raise (167 to 169) and states the obligation Stage E inherits.

169 is the HEAD value, not the Stage E entry value.  Stage A adds 11
direct tier calls, Stage B adds 6, Stage C adds 7 and Stage D adds 7,
and each of those four sections states its own number in its own gate
paragraph.  So the Stage E entry value is 169 + 31 = 200 and the Stage E
exit value is 204.  The recipe at dev/gates.sh:2282 is the authority.
The builder runs it before the gates.sh edit and after it, and a printed
entry value other than 200 stops the stage until the earlier stage's
build-log entry explains the difference.

The classifier does not move.  dev/hole-anchors.py walks
stdlib/prelude.tot plus examples/ only (dev/hole-anchors.py:86-87), so the
three new test/fixtures/ files leave PASS-M6E-ANCHORS and
PASS-M7D-ANCHORS untouched.

One Stage A literal DOES move here, and this stage owns the re-derivation.
PASS-M7A-INFER-SETTLE-BUDGET digests every `.tot` file at depth 1 under
stdlib/, examples/ and test/fixtures/, so the three new depth-1 fixtures
under test/fixtures/ raise its `files` count by three and change its md5.
The `green` count rises by the number of the three that check at exit 0.
Re-derive all three values with the leg's own command, the
`fd -e tot --max-depth 1` form of the Stage A block, run before the fixture
additions and after them, and record both triples in dev/M7-BUILD-LOG.md.
The literal has no HEAD line number, because Stage A writes its block, so
the builder finds it by its marker name.  Stage D re-derived the same
triple for its own corpus edits, so the Stage E entry triple is Stage D's
exit triple and not the Stage A one.  A re-derived value that this stage
cannot explain from its own three fixtures stops the stage.

---

### Files touched

- `SPEC.md`: section 5 milestone bullets and the M7 candidate list;
  section 6 gains "Known debts entering M7"; five citation fixes; the
  Frozen two-horn obligation; the name-independent accessibility-shape
  recognizer (graft G1).
- `test/fixtures/m7e-wf-provenance.tot`: NEW.  Graft G3, pin 14.
- `test/fixtures/m7e-wf-renamed.tot`: NEW.  Graft G2, pin 14 control.
- `test/fixtures/m7e-launder.tot`: NEW.  Graft G6, pin 15.
- `dev/m5e-default-transcript.txt`: REGENERATED.  Three added blocks.
- `lib/check.ml`: the `define_instance` dead-spot comment at
  lib/check.ml:1770-1774 becomes a decision.  Comment only, no code.
- `test/surface.ml`: two new helpers plus five new `cases` entries.
- `dev/gates.sh`: the Stage E block, plus the PASS-M5D-TIERS literal
  raise, plus the stale "count 18" comment at dev/gates.sh:2531, plus the
  PASS-M7A-INFER-SETTLE-BUDGET triple that this stage's three new depth-1
  fixtures move.
- `LICENSE-APACHE`: NEW.  Vendored Apache-2.0 text, debt (h) half two.
- `README.md`: the licence sentence at README.md:96-97.
- `dev/M7-BUILD-LOG.md`: the stage record and the derived counts.

NOT touched: `lib/interp.ml`, `surface/run.ml`, `lib/totality.ml`,
`surface/cache.ml`, `stdlib/prelude.tot`, `examples/`, `bin/tot.ml`,
`dev/gen-m5e-transcript.sh` (its glob at dev/gen-m5e-transcript.sh:13
picks the three new fixtures up with no script edit).

---

### Design

#### E1.  SPEC section 5: the milestone bullets

Section 5 opens at SPEC.md:1762 and ends at SPEC.md:1809, immediately
before section 6 at SPEC.md:1811.  Its last bullet, SPEC.md:1794-1809, is
the "M6 candidate list" written during M5.  Its holes sub-bullet at
SPEC.md:1801-1803 still reads "98 anchors over the 530-line
prelude-plus-examples corpus: 59 expected-type-only, 9 argument-driven,
30 neither", which SPEC.md:2123 superseded at M6 Stage E.

The whole bullet at SPEC.md:1794-1809 is replaced by three bullets.

1. `- M5 (done):` one sentence per shipped item, in the shape of the M2
   and M3 bullets above it (SPEC.md:1767-1791).
2. `- M6 (done):` the same shape, naming the `--experimental-wf`
   deletion, the blocking Unit strict-json posture, the hole slice and
   the scrubber port.
3. `- M7 candidate list (M7 Stage E rewrote the M6 bullet; measure and
   decide the next tradeoff):` carrying the post-Stage-D numbers in
   PROSE: 99 anchors, 60 expected-type-only, 9 argument-driven, 30
   neither.

The prose spelling is deliberate.  PASS-M5D-MEASURE-LOG reads the
textually LAST `expected-type-only=` spelling in SPEC.md through
`| tail -n 1` (dev/gates.sh:3015), and section 5 sits far above the last
record.  A machine spelling here would be legal but pointless, and a
machine spelling that ever moves BELOW the last record turns the leg red.
Rule for this stage, stated once: Stage E writes no
`expected-type-only=` string anywhere in SPEC.md.  Stage D's record stays
the last one.  This is pin 12's second clause.

At HEAD there are three `expected-type-only=` spellings, at SPEC.md:1452,
SPEC.md:2117 and SPEC.md:2123, and the last is SPEC.md:2123.  After Stage
D there is a fourth, below SPEC.md:2123, and it stays last.

#### E2.  SPEC section 6: the debts list and the two obligations

Section 6 opens at SPEC.md:1811.  It carries "Known debts entering M5" at
SPEC.md:2083 and "Known debts entering M4" at SPEC.md:1902, but the
string "M7" does not occur anywhere from SPEC.md:1811 to the end of the
file:

    /Users/oobi/.cargo/bin/rg -n 'M7' /Users/oobi/Documents/tot/SPEC.md | /usr/bin/awk -F: '$1>=1811'
                                                        # no output

So dev/M6-PLAN.md:540-581 is the only authoritative debt list today.
Stage E adds one subsection, `Known debts entering M7`, in the shape of
SPEC.md:2083.  Each item carries a HEAD-verified address and one
disposition word, CLOSED or CARRIED.  The CARRIED items ARE the M8
hand-off list, so the file gets one list and not two.  Ratification
answer Q5 lands here as one sentence: an eventual Acc-style family takes
a WIDE relation formal and pays at erasure, the quantity discipline does
not widen for relation positions, and M7 builds nothing for it.

The subsection carries these entries.  Each address was re-read at HEAD.

1. Well-founded recursion, sized as ONE unit.  CARRIED.  A sound
   admission rule whose side condition carries provenance
   (lib/totality.ml:183-187 states the seed invariant), the erased
   elimination form, and the indexed-relation quantity story
   (SPEC.md:1092-1093 for the `Acc` shape, SPEC.md:1111-1112 for the
   coupling).  M7 leaves M8 the recognizer shape of graft G1 and the two
   fixtures of E4, not a memory.  Q5's wide-relation direction rides
   here.
2. The activation channel for a second admission rule.  CARRIED.
   `Totality.rule` has one constructor and `Check.define`'s `~rule` is
   required (lib/check.ml:1459-1466), which is the re-entry channel.  M8
   states the selector in the same breath as the rule.
3. Argument-driven holes.  CLOSED by M7.  Stage A settles the leading
   erased slot in check position, and, under the Ratification amendment
   of 2026-09-04, in infer position too.  `check` still has no App arm
   of its own (lib/check.ml:1208-1211 routes those forms through
   `check_via_infer`), so the settle lives in the elaborator, not the
   kernel.  Pin 5's seven anchors and the four guard A slots are pinned
   by the Stage A and Stage B markers.
4. The two explicit guard slots.  RETIRED, not carried.  The verdict
   listed examples/guard.tot:134 and examples/guard-rewrap.tot:265 as
   M8 debt 6 with the reason "closing them needs the infer path to
   settle, which M7 scopes out".  The amendment authorised that settle,
   Stage B re-derived both slots and closed them, so the debt does not
   enter M8.  The refusal obligation moves to
   test/fixtures/m7/m7b-arg-slot-undetermined.tot.
5. Prelude re-spelling.  CLOSED by Stage D, with the re-derived anchors
   literal `ANCHORS total=99 expected-type-only=60 argument-driven=9
   neither=30` and PASS-M7D-ANCHORS.
6. Nested inductives and the strict positivity fence.  CARRIED.  The
   applied-ness test at lib/check.ml:1949-1961 is one level deep and the
   message names no layer.  M7 ships the two-layer oracle of E4 and owes
   no rule.
7. The Frozen emptiness claim.  CARRIED as an OPEN obligation, stated
   below with both horns.  lib/interp.ml:85-91 is the claim and
   SPEC.md:851-853 already records it as UNPROVEN.
8. The Json cons-cell family.  CARRIED.  Eight constructor names are
   hard-wired in lib/interp.ml (the array reader starts at
   lib/interp.ml:395) and in surface/bootstrap.ml:66-73.  The `jarr`
   migration touches at least two .ml modules plus the prelude.
9. The .mli surface.  CARRIED.  Measured at HEAD: 15 modules in lib/
   have no .mli (2 do, `Level` and `Budget`) and all 12 modules in
   surface/ have none.
10. Multi-hole reporting.  PART CLOSED.  Stage C ships the position-only
    tail.  Per-hole expected types stay carried, because the strict
    reading of "no second traversal" at Q2 of the amendment forbids a
    new pass and the `Serror` type does not change in M7.  The prelude
    arm's one-line report on a cache hit is CARRIED to M8 as debt 10.
11. Cumulativity or an `Eq1` layer.  CARRIED.  No measured demand.
12. The guard tokenizer duplication.  CLOSED by Stage D, at
    examples/guard-rewrap.tot:42-47, pinned by PASS-M7D-HELPERS-SHARED.
13. The Apache licence text.  CLOSED by Stage E, SPEC.md:1817, pinned by
    PASS-M7E-DEBT-H.
14. The instance-body dead threading.  CLOSED as a DECISION by Stage E,
    at lib/check.ml:1763-1776, pinned by PASS-M7E-INSTANCE-RULE.
15. test/fixtures/s0-erased-guard.tot.  CARRIED.  It redeclares Nat, so
    it runs only through test/surface.ml.  A gate leg that wants it as a
    positive control reaches it the way the suite does, or the fixture is
    re-spelled.

Three anchors that dev/M6-PLAN.md:556-570 carries do not hold at HEAD.
SPEC.md:1351-1352 is the M5 HIT md5 record, SPEC.md:1355 is a depth
timing sentence, and SPEC.md:1603-1610 is the class and instance
desugaring.  Entries 9, 11 and 13 above therefore carry the address
verified in E3, or a measured count, and no stale SPEC anchor.  This is
not a sixth citation repair: those three addresses live in a plan file,
not in SPEC.md, and Stage E writes none of them into SPEC.md.

Two obligations land in the same subsection.

Graft G5, pin 16, the Frozen emptiness claim.  lib/interp.ml:85-91 says
`Frozen` "is reachable only through an inhabitant of a provably empty
type, so it is dead code by the Stage A soundness argument; it exists so
that a missed case degrades to a permanent neutral instead of a loop".
SPEC records this as an OPEN obligation with both horns named and asserts
neither: horn one, the empty type is genuinely empty and `Frozen` is dead
code; horn two, the fence admits an inhabitant and `Frozen` is the
backstop that keeps a missed case a permanent neutral.  Nothing proves
horn one.  The words "not asserted as proved" appear in the entry.

Graft G1, the accessibility-shape recognizer, stated NAME
INDEPENDENTLY.  A family `F` is accessibility-shaped when (i) its `Ind`
entry has two parameters stamped `(0 A : Type L)` and `(0 R : ...)` with
`R`'s type a two-domain arrow into `Type L` over `A`, (ii) it has exactly
one index of type `A`, and (iii) it has exactly one constructor, whose
stamped type is `(x : A) -> ((y : A) -> R y x -> F A R y) -> F A R x` up
to binder names.  M7 builds no rule from this.  M8 inherits the shape
definition and the two fixtures of E4 rather than re-deriving both.

#### E3.  The five citation fixes

Every file:line citation in SPEC.md was re-read at HEAD.  There are
eleven:

    /Users/oobi/.cargo/bin/rg -c '\.(ml|tot|sh|py):[0-9]+' /Users/oobi/Documents/tot/SPEC.md
                                                        # 11

Six are correct and stay: SPEC.md:1265 (dev/hole-anchors.py:69 is
`PROOF_TOKENS = {"Eq", "Dec", "Empty"}`), SPEC.md:1331
(lib/check.ml:653-655 is `inst_start` with `memo = InstMemo.empty`, and
lib/check.ml:1193-1196 is the fresh-state comment), SPEC.md:1344
(lib/check.ml:766-773 is the HIT branch), SPEC.md:1475 (guard.tot:133 is
`let* String _ raw := readStdin in`), SPEC.md:2106 (lib/check.ml:960-969)
and SPEC.md:2107 (lib/check.ml:1208-1211).

Five are repaired.

(a) SPEC.md:2129 reads "lines in guard.tot:133-134 and
guard-rewrap.tot:253-254, kept".  At HEAD examples/guard-rewrap.tot:253
is `| none => allow` and :254 is
`| some ti => rewrapVerdict (jsonGetStringOr ti "command" "")`.  The two
`let*` lines are examples/guard-rewrap.tot:264-265.  The address becomes
`guard-rewrap.tot:264-265`.  The same edit re-records BOTH slots, :264
and :265, as SOLVED by Stage B, and the neighbouring "kept explicit"
wording at SPEC.md:2129 goes with it.

Pin 6's reason for keeping :265 explicit was that its informative later
argument is itself a holed `liftIO _ (...)`, which surface/elab.ml:287-291
refuses at the infer entry.  The Ratification amendment of 2026-09-04
authorises the infer-path settle and builds it in Stage A, so that
reason is no longer true, and the amendment says a slot stays a negative
only with a true reason.  Stage B re-derived the two slots and retired
them.  The SPEC sentence therefore names three things: the retirement,
the Stage B marker PASS-M7B-LIFTIO-SLOT-CLOSES that pins the close, and
the refusal that survives.  The surviving refusal is the slot whose
every later argument is a hole, which still answers
`hole: expected Type 0` and is pinned by
test/fixtures/m7/m7b-arg-slot-undetermined.tot.

The corrected sentence states no anchor count of its own.  It points at
PASS-M7B-GUARD-ARG-HOLES's holed literal, which Stage B derives from a
fresh classifier run, so SPEC states no number that no command prints.
Stage E writes the disposition Stage B measured.  If Stage B's
re-derivation lands the other way and a slot stays explicit with a true
reason, the SPEC sentence takes that outcome instead.  The address
repair from :253-254 to :264-265 is the same under either outcome, and
PASS-M7E-SPEC-CITATIONS asserts the address, not the disposition.

(b) SPEC.md:2141 cites `Totality.mentions` tests as lib/check.ml:1828.  At
HEAD lib/check.ml:1828 is `(Term.Univ level))` inside the
`declare_ind_status` fold.  The `self_rec` computation is
lib/check.ml:2051:
`let self_rec = List.exists (fun (_q, _x, ty) -> Totality.mentions name ty) args in`.
The address becomes `lib/check.ml:2051`.  Graft G7.

(c) SPEC.md:2145 cites `Totality.mentions`' App arm as lib/totality.ml:52.
At HEAD lib/totality.ml:52 is the doc comment header
`(** Does [name] occur anywhere in [t] as a [Term.Global]? Structural,`.
The App arm is lib/totality.ml:66:
`| Term.App (_q, f, a) -> mentions name f || mentions name a`.  The
address becomes `lib/totality.ml:66`.  Graft G7.

(d) The instance-threading debt address.  dev/M6-PLAN.md:572 cites
lib/check.ml:1762-1773.  At HEAD lib/check.ml:1762 is the closing `*)` of
the preceding doc comment, `define_instance` runs lib/check.ml:1763-1776
and the dead-spot comment is lib/check.ml:1770-1774.  The new section 6
entry for debt (i) carries `lib/check.ml:1763-1776`.

(e) The guard-helper duplication address.  dev/M6-PLAN.md:569 cites
examples/guard-rewrap.tot:24-29.  At HEAD the duplication note is
examples/guard-rewrap.tot:42-47 ("The tokenizer helpers ... are COPIED
from examples/guard.tot on purpose").  The new section 6 entry for debt
(h) carries `examples/guard-rewrap.tot:42-47`, and marks the helper half
CLOSED by Stage D.

The same edit corrects one live claim beside (e).  SPEC.md:2317-2318 says
of the helper move that "the move is a cache-format change, so it waits".
That is false and the verdict adjudicated it so: surface/cache.ml's key at
surface/cache.ml:343-346 folds the prelude source into the digest, so a
prelude edit invalidates the cache with no `format_version` bump.  The
sentence is replaced by the correct reason and a pointer to pin 18.

One count fix rides with the citations, pin 12's first clause.
dev/gates.sh:2531 reads "the PASS-M5D-MEASURE-LOG literal (count 18,
pinned name set) does".  The live literal is `[ "$m5d_lines" -eq 22 ]` at
dev/gates.sh:3016.  Stage E edits the COMMENT to say 22.  No leg literal
moves.

#### E4.  The three fixtures

All three land in test/fixtures/.  Every file keeps its declarations
FIRST and its comment block BELOW them, the fixture convention the gate
legs depend on: the legs pin `file:LINE:COL` prefixes, so the
error-bearing declaration holds its line.  Every expected line below was
produced by running the exact bytes at HEAD through
/Users/oobi/Documents/tot/_build/default/bin/tot.exe.

**test/fixtures/m7e-wf-provenance.tot** (pin 14, graft G3):

```
data Acc (0 A : Type 0) (0 R : A -> A -> Type 0) : A -> Type 0 :=
  | acc : (x : A) -> ((y : A) -> R y x -> Acc A R y) -> Acc A R x
data Box (0 A : Type 0) (0 R : A -> A -> Type 0) (0 x : A) : Type 0 :=
  | mkBox : Acc A R x -> Box A R x
def rec accCross : (0 A : Type 0) -> (0 R : A -> A -> Type 0) -> (0 x : A) ->
    Acc A R x -> Box A R x -> Nat :=
  fun A R x a t => match t with | mkBox a2 => accCross A R x a2 t end
-- M7 Stage E fixture (verdict pin 14, graft G3): an accessibility
-- descent whose PROVENANCE is the wrong formal.  Acc has the shape a
-- recognizer fires on: two erased parameters, a relation formal, one
-- index, one constructor.  The recursive call feeds the Acc slot with
-- a2, which is a FIELD OF t, and passes t itself unchanged.  So under
-- the a candidacy the Acc argument is smaller by way of t, not by way
-- of a's own seed, and under the t candidacy the t argument does not
-- descend at all.  bad2.tot, crossformal-t.tot and deep2.tot declare
-- parameterless, relationless, indexless types, so a recognizer-based
-- rule never reaches them and they cannot discriminate it; this file
-- can.  It must stay REJECTED under any M8 rule that carries the
-- provenance side condition of SPEC section 2's seed-invariant entry.
-- Gate PASS-M7E-WF-PROVENANCE-ORACLE pins it; accCross must stay at
-- line 5 column 1.
```

Expected: exit 1, line
`m7e-wf-provenance.tot:5:1: recursive definition accCross failed the structural termination guard`.

The file elaborates.  The refusal comes from the totality guard and not
from a type error, which is what makes it reach the code under test.

**test/fixtures/m7e-wf-renamed.tot** (pin 14 control, graft G2):

```
data Wf (0 A : Type 0) (0 R : A -> A -> Type 0) : A -> Type 0 :=
  | wfin : (x : A) -> ((y : A) -> R y x -> Wf A R y) -> Wf A R x
def rec wfRec : (0 A : Type 0) -> (0 R : A -> A -> Type 0) ->
    (0 P : A -> Type 0) ->
    ((x : A) -> ((y : A) -> R y x -> P y) -> P x) ->
    (x : A) -> Wf A R x -> P x :=
  fun A R P f x a =>
    match a as aa in Wf z return P z with
    | wfin x0 h => f x0 (fun y r => wfRec A R P f y (h y r))
    end
-- M7 Stage E fixture (verdict pin 14, graft G2): the SAME
-- accessibility shape under different names.  Nothing here is called
-- Acc or acc.  M7 builds no rule, so the shipped structural guard
-- refuses this file exactly as it refuses the Acc-named spelling, and
-- the gate pins that message.  The control's job is to stop M8 from
-- writing the recognizer name-dependently by accident: an M8 rule that
-- admits the Acc-named recursor and still refuses this file has read
-- the name, not the shape.  Gate PASS-M7E-WF-PROVENANCE-ORACLE leg (b)
-- pins it; wfRec must stay at line 3 column 1.
```

Expected: exit 1, line
`m7e-wf-renamed.tot:3:1: recursive definition wfRec failed the structural termination guard`.

**test/fixtures/m7e-launder.tot** (pin 15, graft G6):

```
data U (0 A : Type 0) : Type 0 := | mku : (A -> Nat) -> U A
data V (0 A : Type 0) : Type 0 := | mkv : U A -> V A
data Tl : Type 0 := | mkt : V Tl -> Tl
-- M7 Stage E fixture (verdict pin 15, graft G6): a negative
-- occurrence LAUNDERED through one intermediate family.  Tl sits in
-- V's parameter, V's field is U, and U's field is (A -> Nat), so the
-- occurrence is negative two layers down.  The applied-ness test at
-- lib/check.ml:1949-1961 is one level deep, so what refuses this file
-- today is not a polarity analysis, and the message does not say which
-- layer tripped.  test/fixtures/nested-neg.tot is the ONE-LAYER
-- control and already ships (M6 Stage A, pin 10).  M8's nesting work
-- must keep both rejected, or state in SPEC.md, in those words, which
-- one it admits and why.  Gate PASS-M7E-POSITIVITY-LAUNDER-ORACLE;
-- mkt must stay at line 3 column 1.
```

Expected: exit 1, line
`m7e-launder.tot:3:1: invalid constructor mkt: negative or non-uniform occurrence of Tl`.

Pin 15 asks for the launder and its one-layer control as negative
fixtures.  The control already exists as test/fixtures/nested-neg.tot,
whose two declarations are byte-identical to the judge's j4b probe, and
whose HEAD line is
`nested-neg.tot:2:1: invalid constructor mkt3: negative or non-uniform occurrence of T3`.
Stage E adds no second copy.  It asserts BOTH files inside the one
marker, so the pin's "both at exit 1" is one leg's business and the
duplicate fixture never enters the corpus.

#### E5.  lib/check.ml: debt (i) becomes a decision

At HEAD lib/check.ml:1770-1774 reads:

```ocaml
  (* M6 Stage A (verdict pin 8), the dead-spot record: an instance body
     passes [~rule] but never [~rec_], so [define]'s guard cannot run on
     it and the threading here is inert plumbing, not a live gate.  M7
     decides whether instances gain a real [rec_] story or the
     threading simplifies (verdict, Known debts). *)
```

M7 decides.  The comment becomes the decision, and no code moves:

```ocaml
  (* M7 Stage E (verdict pin 17): DECIDED.  Instance bodies are NEVER
     guarded.  The surface has no channel to ask for one: `instance rec`
     is a parse error ("expected ': TYPE := TERM' after 'instance'"), so
     [~rec_] can only ever take [define]'s [false] default
     (lib/check.ml:1465) and the guard cannot run on an instance body.
     The threading stays as written.  [~rule] is passed EXPLICITLY, and
     [define]'s [~rule] stays REQUIRED (lib/check.ml:1466), so an M8
     admission rule still arrives here as a compiler error.  Two panel
     proposals spelled the opposite (drop [~rule] from this call, or
     drop it from [define_instance]);  both need a DEFAULT on [define]'s
     [~rule], which destroys the enumeration channel the doc comment at
     lib/check.ml:1459-1464 exists to protect, so neither is taken. *)
```

The call under the comment is unchanged, byte for byte:

```ocaml
  define ~reducible:true ~stamped_ty:ty' ~budget ~rule:Totality.Structural globals ~name
    ~ty ~def
```

This is a comment change.  `Check.define_instance`'s signature, its
`let*` chain (lib/check.ml:1765-1766) and its result type do not move, so
no caller changes and no exhaustive match is re-opened.

#### E6.  Debt (h), the licence half

`ls LICENSE*` at HEAD prints only LICENSE-MIT.  SPEC.md:1817 records the
debt as "Apache license text not vendored yet (README notes dual intent)"
and README.md:96-97 reads "MIT (LICENSE-MIT).  Dual MIT OR Apache-2.0
intended;  the Apache text is not / yet vendored."

Stage E adds LICENSE-APACHE with the verbatim Apache-2.0 text, rewrites
README.md:96-97 to name both files, and marks the SPEC.md:1817 entry
PAID with the date.  No code and no gate literal moves.  The helper half
of debt (h) is Stage D's and is marked CLOSED in the E2 list with the
corrected address from E3(e).

#### E7.  The transcript reseal

dev/gen-m5e-transcript.sh globs `examples/*.tot test/fixtures/*.tot`
(dev/gen-m5e-transcript.sh:13), so the three new fixtures enter with no
script edit.  PASS-M6E-TRANSCRIPT-RESEALED asserts that the sealed block
count equals the LIVE glob count (dev/gates.sh:3128-3133), so landing
fixtures without a reseal turns that leg red in the same run.

Procedure, same commit as the fixtures:

1. Regenerate:
   `/bin/zsh /Users/oobi/Documents/tot/dev/gen-m5e-transcript.sh > /Users/oobi/Documents/tot/dev/m5e-default-transcript.txt`.
2. Diff old against new.  The diff must be ADDITIONS ONLY: three new
   `### ` blocks, one per new fixture, each exactly 5 lines
   (`### path`, `#exit 1`, `#out`, `#err`, the one stderr line).
   Predicted totals: Stage D exit blocks + 3, Stage D exit lines + 15.
   At HEAD the baseline is 101 blocks and 10399 lines, so the same three
   fixtures on HEAD would give 104 and 10414;  Stage D's own reseal moves
   the base, and the DELTA is the binding part.
3. Any deleted or changed line in the diff is a Stage E failure.  Stage E
   changes one comment in lib/check.ml and no elaboration byte, so no
   existing block may move.
4. Record the block count, the line count and the diff shape in
   dev/M7-BUILD-LOG.md.

#### E8.  test/surface.ml: five suite tests

Two helpers already do most of the work: `m5a_expect_fixture_check_error`
(test/surface.ml:671-684) checks a fixture in process through
`Run.script ~exec:false` and requires a rejection whose message ends with
a given suffix, printing the message on a pass too;
`m5a_expect_fixture_checks` (test/surface.ml:687-694) requires a clean
check.  Three of the five cases use them as they stand.

Two new helpers take SOURCE TEXT rather than a fixture path, because the
instance cases must not add files to the transcript glob:

```ocaml
(* M7 Stage E (plan E8): check one source string in process and require
   a rejection whose message ENDS with [want_suffix].  Same oracle rule
   as [m5a_expect_fixture_check_error]: the message prints on a pass, so
   the rejection is shown to fire for the intended reason. *)
let m7e_expect_source_error (bst : Tot_surface.Run.state) ~(label : string)
    ~(src : string) ~(want_suffix : string) () : (unit, string) result =
  Tot_surface.Run.script ~st:bst ~exec:false src
  |> Result.fold
       ~ok:(fun (lines, _exit_code) ->
         Error
           (Printf.sprintf "%s: expected a rejection, but the source checked: [%s]" label
              (show_lines lines)))
       ~error:(fun e ->
         let msg = Tot_surface.Serror.to_string e in
         Printf.printf "  expected error (%s): %s\n" label msg;
         match () with
         | () when String.ends_with ~suffix:want_suffix msg -> Ok ()
         | () -> Error (Printf.sprintf "%s: got %S, want a message ending %S" label msg want_suffix))

(* M7 Stage E (plan E8): check one source string in process and require
   it to CHECK clean. *)
let m7e_expect_source_checks (bst : Tot_surface.Run.state) ~(label : string)
    ~(src : string) () : (unit, string) result =
  Tot_surface.Run.script ~st:bst ~exec:false src
  |> Result.fold
       ~ok:(fun (_lines, _exit_code) -> Ok ())
       ~error:(fun e ->
         Error
           (Printf.sprintf "%s: expected exit 0, got %s" label
              (Tot_surface.Serror.to_string e)))
```

Both helpers are total.  No exception is raised, no `match` on an
`option` or a `result` appears, the `Result.fold` combinator carries both
arms, and the one two-way choice uses a `match ()` guard, per the house
rules the file already follows (test/surface.ml:1920-1922 is the
in-repo precedent).

The five `cases` entries, appended to the list that opens at
test/surface.ml:862, in the tuple shape of test/surface.ml:1781-1797:

```ocaml
    (* M7 Stage E (plan E8, cases M7E-1 to M7E-5). *)
    ( "M7E-1: the accessibility descent from a NON-seed formal stays rejected (pin 14)",
      m5a_expect_fixture_check_error bst "m7e-wf-provenance.tot"
        ~want_suffix:
          "recursive definition accCross failed the structural termination guard" );
    ( "M7E-2: the renamed accessibility shape is refused exactly like the Acc-named one (G2)",
      m5a_expect_fixture_check_error bst "m7e-wf-renamed.tot"
        ~want_suffix:"recursive definition wfRec failed the structural termination guard" );
    ( "M7E-3: the two-layer polarity launder and its one-layer control both stay rejected (pin 15)",
      fun () ->
        let* () =
          m5a_expect_fixture_check_error bst "m7e-launder.tot"
            ~want_suffix:"invalid constructor mkt: negative or non-uniform occurrence of Tl" ()
        in
        m5a_expect_fixture_check_error bst "nested-neg.tot"
          ~want_suffix:"invalid constructor mkt3: negative or non-uniform occurrence of T3" () );
    ( "M7E-4: the surface has no channel to ask for a guarded instance body (pin 17)",
      m7e_expect_source_error bst ~label:"instance rec"
        ~src:
          "class Sized (0 A : Type 0) := { szf : A -> Nat }\n\
           instance rec : Sized Nat := mkSized Nat (fun n => n)"
        ~want_suffix:"parse error: expected ': TYPE := TERM' after 'instance', found 'rec'" );
    ( "M7E-5: an ordinary instance still checks clean under the Structural rule (pin 17)",
      m7e_expect_source_checks bst ~label:"instance"
        ~src:
          "class Sized (0 A : Type 0) := { szf : A -> Nat }\n\
           instance : Sized Nat := mkSized Nat (fun n => n)" );
```

Case M7E-4's want suffix comes from a live run at HEAD.  The driver
prints the message with a file prefix and the suite reads it without one,
so the comparison is a suffix comparison, which both spellings satisfy.
Suite count: surface suite + 5.  The kernel suite does not change:
`Check.define_instance` cannot observe its own label from OCaml, so the
pin-17 evidence is a surface fact and a source fact, not a kernel
assertion.

---

### Gate additions

Placement.  The whole Stage E block goes into dev/gates.sh directly AFTER
the PASS-M6E-TRANSCRIPT-RESEALED leg, which ends at dev/gates.sh:3139 at
HEAD, and BEFORE the two timing-sensitive tail legs,
PASS-M4FIX-INST-BRANCHING at dev/gates.sh:3172 and PASS-M5B-BRANCHING-20
at dev/gates.sh:3190.  The tail stays the tail: the M4 round-5 rule at
dev/gates.sh:3168-3171 says no marker may sit downstream of
PASS-M5B-BRANCHING-20.  Stages A to D shift these numbers, so the builder
anchors on the MARKER NAMES, not on the line numbers.

Emission.  Every leg follows the file's shape: run, capture `$out` and
`$code`, then

    { <conditions>; } \
      && echo PASS-<MARKER> \
      || { printf '%s\n' "$out"; echo "FAIL-<MARKER> (exit=$code)"; exit 1; }

Watchdog coordination.  Four legs use a direct named tier and no leg uses
`gate_timed`.  So PASS-M5D-MEASURE-LOG's literal (22 lines at
dev/gates.sh:3016) and its pinned name set do not move, and
PASS-M5D-TIERS's literal moves by EXACTLY four.  In the same commit: run
`/Users/oobi/.cargo/bin/rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' /Users/oobi/Documents/tot/dev/gates.sh`
before the edit and after it, edit the literal at dev/gates.sh:2284,
append a dated sentence to the TIERS comment in the shape of the M6
Stage H sentence at dev/gates.sh:2271-2274, and record both numbers in
dev/M7-BUILD-LOG.md.  The predicted numbers are 200 before and 204
after: 169 at HEAD plus 11 from Stage A, 6 from Stage B, 7 from Stage C
and 7 from Stage D.  The recipe output is the authority.  A before value
other than 200, or an after value that does not exceed it by four, stops
the stage.
Without this edit the battery cannot reach GATE-EXIT=0 at the Stage E
boundary.

---

    Marker: PASS-M7E-SPEC-CITATIONS
    Pin: 12, 16
    Command: /Users/oobi/.cargo/bin/rg -c 'guard-rewrap\.tot:264-265' /Users/oobi/Documents/tot/SPEC.md
    At HEAD: exit 1, output empty (rg prints nothing and exits 1 on no match)
    After stage: exit 0, output contains "1"
    Non-vacuous because: SPEC.md:2129 today spells the two let* slots as guard-rewrap.tot:253-254, and those two lines at HEAD are `| none => allow` and `| some ti => rewrapVerdict (jsonGetStringOr ti "command" "")`, so the corrected address cannot appear in the file until the stage writes it.

The leg is source-only and runs no binary, like PASS-M5D-MEASURE-LOG
(dev/gates.sh:3006-3020).  It carries six conditions:

```zsh
# PASS-M7E-SPEC-CITATIONS (pins 12, 16, grafts G1, G5, G7).  SPEC
# sections 5 and 6 are repaired and the five drifted citations are
# corrected.  The two code-site conditions are pin 16's no-diff
# assertion: Interp.Frozen and the Quantity.Zero arm of
# Run.compute_guard are untouched by M7, so a stage that "tidies" the
# emptiness story into code turns this leg red.
m7e_cit_ok=$(rg -c 'guard-rewrap\.tot:264-265' "$ROOT"/SPEC.md)
m7e_cit_stale=$(rg -c 'guard-rewrap\.tot:253-254' "$ROOT"/SPEC.md; true)
m7e_sec5=$(rg -c '^- M6 \(done\)' "$ROOT"/SPEC.md)
m7e_sec6=$(rg -c '^Known debts entering M7' "$ROOT"/SPEC.md)
m7e_horns=$(rg -c 'not asserted as proved' "$ROOT"/SPEC.md)
m7e_tot66=$(rg -c 'lib/totality\.ml:66' "$ROOT"/SPEC.md)
m7e_chk2051=$(rg -c 'lib/check\.ml:2051' "$ROOT"/SPEC.md)
m7e_frozen=$(rg -cF 'Frozen' "$ROOT"/lib/interp.ml)
m7e_zeroarm=$(rg -cF -- '() when Eterm.mentions name def_e -> Interp.Frozen' "$ROOT"/surface/run.ml)
{ [ "$m7e_cit_ok" -ge 1 ] && [ -z "$m7e_cit_stale" ] \
  && [ "$m7e_sec5" -eq 1 ] && [ "$m7e_sec6" -eq 1 ] && [ "$m7e_horns" -ge 1 ] \
  && [ "$m7e_tot66" -ge 1 ] && [ "$m7e_chk2051" -ge 1 ] \
  && [ "$m7e_frozen" -eq 5 ] && [ "$m7e_zeroarm" -eq 1 ]; } \
  && echo PASS-M7E-SPEC-CITATIONS \
  || { echo "FAIL-M7E-SPEC-CITATIONS (ok=$m7e_cit_ok stale=$m7e_cit_stale sec5=$m7e_sec5 sec6=$m7e_sec6 horns=$m7e_horns t66=$m7e_tot66 c2051=$m7e_chk2051 frozen=$m7e_frozen zero=$m7e_zeroarm)"; exit 1; }
```

Literals derived at HEAD, with the command that printed each:

    rg -cF 'Frozen' /Users/oobi/Documents/tot/lib/interp.ml                     # 5
    rg -cF -- '() when Eterm.mentions name def_e -> Interp.Frozen' .../surface/run.ml
                                                                               # 1
    rg -c 'guard-rewrap\.tot:253-254' /Users/oobi/Documents/tot/SPEC.md         # 1, the stale citation this stage removes
    rg -c 'guard-rewrap\.tot:264-265' /Users/oobi/Documents/tot/SPEC.md         # no match, exit 1
    rg -c 'not asserted as proved' /Users/oobi/Documents/tot/SPEC.md            # no match, exit 1
    rg -c 'lib/totality\.ml:66' /Users/oobi/Documents/tot/SPEC.md               # no match, exit 1
    rg -c 'lib/check\.ml:2051' /Users/oobi/Documents/tot/SPEC.md                # no match, exit 1
    rg -c '^- M6 \(done\)' /Users/oobi/Documents/tot/SPEC.md                    # no match, exit 1
    rg -c '^Known debts entering M7' /Users/oobi/Documents/tot/SPEC.md          # no match, exit 1

Every literal in the block has its command above.  The block holds nine
assertions.  Six of them read zero at HEAD, and those six zero counts are
the leg's own proof that it bites at HEAD.  The stale `253-254` citation
reads 1 at HEAD and must read empty after the stage.  The two code-site
counts, 5 and 1, must not move at all.  The
`Frozen` count of 5 covers lib/interp.ml:87, :88, :95, :636 and :680, and
the constructor itself is lib/interp.ml:95.

---

    Marker: PASS-M7E-WF-PROVENANCE-ORACLE
    Pin: 14
    Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/test/fixtures/m7e-wf-provenance.tot
    At HEAD: exit 1, output contains "test/fixtures/m7e-wf-provenance.tot: no such file"
    After stage: exit 1, output contains "m7e-wf-provenance.tot:5:1: recursive definition accCross failed the structural termination guard"
    Non-vacuous because: the fixture bytes run at HEAD from /Users/oobi/Documents/tot-m7-probes/plan/f1.tot elaborate and are then refused by the totality guard, which prints `f1.tot:5:1: recursive definition accCross failed the structural termination guard` at exit 1, so the file reaches lib/totality.ml's guard rather than dying at a type error.

Leg (b), the renamed control:

    Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/test/fixtures/m7e-wf-renamed.tot
    At HEAD: exit 1, output contains "test/fixtures/m7e-wf-renamed.tot: no such file"
    After stage: exit 1, output contains "m7e-wf-renamed.tot:3:1: recursive definition wfRec failed the structural termination guard"
    Non-vacuous because: the same bytes at /Users/oobi/Documents/tot-m7-probes/plan/f2.tot are refused at HEAD with `f2.tot:3:1: recursive definition wfRec failed the structural termination guard`, so the control reaches the same guard under names that contain no Acc.

```zsh
# PASS-M7E-WF-PROVENANCE-ORACLE (pin 14, grafts G2 and G3).  Two legs,
# both NEGATIVE today.  Leg (a) is the descent whose provenance is the
# wrong formal: Acc has the recognizer shape, the Acc slot receives a
# field of t, and t itself does not descend.  Leg (b) is the SAME
# accessibility shape under names that contain no Acc.  M7 builds no WF
# rule, so both are refused by the shipped structural guard.  An M8
# rule that flips leg (a) has dropped the provenance side condition; an
# M8 rule that flips leg (b) alone has read the NAME, not the shape.
# Do not "fix" either by deleting it; re-open the design instead.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m7e-wf-provenance.tot 2>&1)
code=$?
wantpv='m7e-wf-provenance.tot:5:1: recursive definition accCross failed the structural termination guard'
out2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m7e-wf-renamed.tot 2>&1)
code2=$?
wantrn='m7e-wf-renamed.tot:3:1: recursive definition wfRec failed the structural termination guard'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantpv" \
  && [ "$code2" -eq 1 ] && printf '%s\n' "$out2" | rg -q -- "$wantrn"; } \
  && echo PASS-M7E-WF-PROVENANCE-ORACLE \
  || { printf '%s\n' "$out"; printf '%s\n' "$out2"; \
       echo "FAIL-M7E-WF-PROVENANCE-ORACLE (exit=$code/$code2)"; exit 1; }
```

---

    Marker: PASS-M7E-POSITIVITY-LAUNDER-ORACLE
    Pin: 15
    Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/test/fixtures/m7e-launder.tot
    At HEAD: exit 1, output contains "test/fixtures/m7e-launder.tot: no such file"
    After stage: exit 1, output contains "m7e-launder.tot:3:1: invalid constructor mkt: negative or non-uniform occurrence of Tl"
    Non-vacuous because: the same bytes at /Users/oobi/Documents/tot-m7-probes/plan/f3.tot are refused at HEAD with `f3.tot:3:1: invalid constructor mkt: negative or non-uniform occurrence of Tl`, so the fixture reaches the strict-positivity fence in lib/check.ml and is not a parse or scope failure.

Leg (b), the one-layer control that already ships:

    Command: /Users/oobi/Documents/tot/_build/default/bin/tot.exe check /Users/oobi/Documents/tot/test/fixtures/nested-neg.tot
    At HEAD: exit 1, output contains "nested-neg.tot:2:1: invalid constructor mkt3: negative or non-uniform occurrence of T3"
    After stage: exit 1, same line, now also asserted by this marker
    Non-vacuous because: this leg's job is the COMPARISON.  The two messages are identical except for the constructor and family names, which is the recorded evidence that HEAD's wording carries no information about which layer tripped the fence.  PASS-M6A-FENCE-CONTRAVARIANT keeps its own claim on this file; the duplicate run here is four hundredths of a second and makes pin 15's "both at exit 1" one leg's business.

```zsh
# PASS-M7E-POSITIVITY-LAUNDER-ORACLE (pin 15, graft G6).  Leg (a) is
# the two-layer launder: Tl in V's parameter, V's field a U, U's field
# a function INTO Nat, so the negative occurrence is two families down.
# Leg (b) is the one-layer control, which already ships from M6 Stage
# A.  The applied-ness test at lib/check.ml:1949-1961 is one level
# deep, so the fence refuses both with the SAME wording and says
# nothing about the layer.  M8's nesting work must keep both rejected,
# or state in SPEC.md, in those words, which one it admits and why.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m7e-launder.tot 2>&1)
code=$?
wantl='m7e-launder\.tot:3:1: invalid constructor mkt: negative or non-uniform occurrence of Tl'
out2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/nested-neg.tot 2>&1)
code2=$?
wantc='nested-neg\.tot:2:1: invalid constructor mkt3: negative or non-uniform occurrence of T3'
{ [ "$code" -eq 1 ] && printf '%s\n' "$out" | rg -q -- "$wantl" \
  && [ "$code2" -eq 1 ] && printf '%s\n' "$out2" | rg -q -- "$wantc"; } \
  && echo PASS-M7E-POSITIVITY-LAUNDER-ORACLE \
  || { printf '%s\n' "$out"; printf '%s\n' "$out2"; \
       echo "FAIL-M7E-POSITIVITY-LAUNDER-ORACLE (exit=$code/$code2)"; exit 1; }
```

---

    Marker: PASS-M7E-INSTANCE-RULE
    Pin: 17
    Command: /Users/oobi/.cargo/bin/rg -c 'instance bodies are NEVER guarded' /Users/oobi/Documents/tot/lib/check.ml
    At HEAD: exit 1, output empty
    After stage: exit 0, output contains "1"
    Non-vacuous because: lib/check.ml:1770-1774 today says "M7 decides whether instances gain a real [rec_] story or the threading simplifies", which is the open question, not the decision, so the decided sentence cannot be in the file until the stage writes it.

The leg also pins the call that the decision is about, with an exact
two-line string comparison in the `m6e_gblock` idiom
(dev/gates.sh:3130-3133).  The extraction was run at HEAD and matches:

```zsh
# PASS-M7E-INSTANCE-RULE (pin 17, debt (i)).  The decision is recorded
# and the call it decides is pinned byte for byte.  The two-line want
# string proves BOTH halves at once: [~rule:Totality.Structural] is
# passed explicitly, and no [~rec_] is passed, so [define]'s false
# default (lib/check.ml:1465) applies and the guard cannot run on an
# instance body.  Dropping [~rule] here, or from [define_instance],
# needs a DEFAULT on [define]'s required [~rule], which would destroy
# the enumeration channel of lib/check.ml:1459-1464.  Suite cases M7E-4
# and M7E-5 carry the behavioural half.
m7e_inst_note=$(rg -c 'instance bodies are NEVER guarded' "$ROOT"/lib/check.ml)
m7e_inst=$(rg -A 1 -x -F -- "  define ~reducible:true ~stamped_ty:ty' ~budget ~rule:Totality.Structural globals ~name" "$ROOT"/lib/check.ml)
m7e_inst_want=$'  define ~reducible:true ~stamped_ty:ty\' ~budget ~rule:Totality.Structural globals ~name\n    ~ty ~def'
m7e_rulereq=$(rg -cF -- '~(rule : Totality.rule)' "$ROOT"/lib/check.ml)
{ [ "$m7e_inst_note" -eq 1 ] && [ "$m7e_inst" = "$m7e_inst_want" ] \
  && [ "$m7e_rulereq" -eq 1 ]; } \
  && echo PASS-M7E-INSTANCE-RULE \
  || { printf '%s\n' "$m7e_inst"; \
       echo "FAIL-M7E-INSTANCE-RULE (note=$m7e_inst_note rulereq=$m7e_rulereq)"; exit 1; }
```

Literal derived at HEAD: the two-line extraction above returns
`  define ~reducible:true ~stamped_ty:ty' ~budget ~rule:Totality.Structural globals ~name`
followed by `    ~ty ~def`, and the string comparison against
`m7e_inst_want` printed MATCH.  `rg -cF -- '~(rule : Totality.rule)'
lib/check.ml` prints 1, which is `define`'s required binding at
lib/check.ml:1466.

---

    Marker: PASS-M7E-DEBT-H
    Pin: none (verdict scope-in 5, small debt (h), licence half)
    Command: /bin/ls /Users/oobi/Documents/tot/LICENSE-APACHE
    At HEAD: exit 1, output contains "No such file or directory"
    After stage: exit 0, output contains "LICENSE-APACHE"
    Non-vacuous because: `ls LICENSE*` at HEAD prints only LICENSE-MIT, so the file does not exist and the leg cannot pass before the stage vendors it.

```zsh
# PASS-M7E-DEBT-H (verdict scope-in 5, small debt (h), licence half).
# The Apache text is vendored and README stops saying it is not.  The
# helper half of debt (h) is Stage D's and is pinned by
# PASS-M7D-HELPERS-SHARED.  SPEC.md:1817 carries the PAID date.
m7e_apache=0
[ -f "$ROOT"/LICENSE-APACHE ] && m7e_apache=1
m7e_apache_body=$(rg -c 'Apache License' "$ROOT"/LICENSE-APACHE; true)
m7e_readme_stale=$(rg -c 'the Apache text is not' "$ROOT"/README.md; true)
m7e_readme_ok=$(rg -c 'LICENSE-APACHE' "$ROOT"/README.md)
{ [ "$m7e_apache" -eq 1 ] && [ -n "$m7e_apache_body" ] \
  && [ -z "$m7e_readme_stale" ] && [ "$m7e_readme_ok" -ge 1 ]; } \
  && echo PASS-M7E-DEBT-H \
  || { echo "FAIL-M7E-DEBT-H (file=$m7e_apache body=$m7e_apache_body stale=$m7e_readme_stale ok=$m7e_readme_ok)"; exit 1; }
```

Literals derived at HEAD:

    /bin/ls /Users/oobi/Documents/tot/LICENSE-APACHE     # No such file or directory, exit 1
    rg -c 'the Apache text is not' /Users/oobi/Documents/tot/README.md
                                                        # 1, exit 0

Both flip.  The stale README sentence is at README.md:96-97 and the
`ls LICENSE*` sweep prints only LICENSE-MIT.

---

### Review checklist

1. GATE-EXIT=0, 0 FAIL, 420 PASS.  Arithmetic:
   410 entry + 5 markers + 5 surface suite cases = 420.  The five markers
   are PASS-M7E-SPEC-CITATIONS, PASS-M7E-WF-PROVENANCE-ORACLE,
   PASS-M7E-POSITIVITY-LAUNDER-ORACLE, PASS-M7E-INSTANCE-RULE and
   PASS-M7E-DEBT-H.  The five cases are M7E-1 through M7E-5 of E8.
2. Namespace: `rg -c 'PASS-M7E' dev/gates.sh` counts the five echo lines
   plus their comments, and nothing outside PASS-M7E-* is added.  At HEAD
   `rg -c 'PASS-M7' dev/gates.sh` printed nothing and exited 1.
3. Every SPEC citation the stage writes is re-read at HEAD before the
   edit, and the six correct ones of E3 are left alone.
4. `rg -c 'expected-type-only=' SPEC.md` counts one more spelling than at
   Stage D entry only if Stage D added it.  Stage E adds none, and
   `rg -o 'expected-type-only=[0-9]+' SPEC.md | tail -n 1` still equals
   the gate log's value, so PASS-M5D-MEASURE-LOG is green with no literal
   change (pin 12).
5. dev/gates.sh:2531's comment says 22, and the leg literal at
   dev/gates.sh:3016 is untouched.
6. PASS-M5D-TIERS: measured before and after, raised by exactly four,
   predicted 200 to 204, both measured numbers in dev/M7-BUILD-LOG.md.
7. Transcript resealed per E7.  The diff is additions only, three blocks
   of five lines.  PASS-M5E-DEFAULT-IDENTITY and
   PASS-M6E-TRANSCRIPT-RESEALED are both green after the reseal.
8. PASS-M6E-ANCHORS and PASS-M7D-ANCHORS are unchanged.  The classifier
   corpus is prelude plus examples (dev/hole-anchors.py:86-87), so the
   three new fixtures cannot move it.  Re-run
   `python3 -P dev/hole-anchors.py` and confirm the Stage D literal.
9. Debt (j) verification, not repetition: confirm Stage A landed
   PASS-M7A-SPINE-COMMENT and that surface/elab.ml's `spine` doc comment
   describes the settle pass.
9b. Amendment verification, also not repetition: confirm the battery
    carries PASS-M7A-INFER-SETTLE and PASS-M7B-LIFTIO-SLOT-CLOSES, and
    that the SPEC sentence of E3(a) states the disposition those two
    legs measured.  A SPEC sentence that says a slot stays explicit
    while PASS-M7B-LIFTIO-SLOT-CLOSES is green is a Stage E failure.
10. Mutation proofs, each restored `md5 -q`-identical and logged:
    - ME-1: revert one SPEC citation to `guard-rewrap.tot:253-254`.
      PASS-M7E-SPEC-CITATIONS red on `stale`.
    - ME-2: delete the "Known debts entering M7" heading.
      PASS-M7E-SPEC-CITATIONS red on `sec6`.
    - ME-3: rename the provenance fixture's `accCross` to `accRec`.
      PASS-M7E-WF-PROVENANCE-ORACLE red on the exact message, which
      proves the leg reads the message and not the exit code.
    - ME-4: replace m7e-launder.tot's `V Tl` field with `U Tl`, one
      layer.  PASS-M7E-POSITIVITY-LAUNDER-ORACLE red on the wording,
      which proves leg (a) is the TWO-layer shape.
    - ME-5: add `~rec_:true` to the `define` call in `define_instance`.
      PASS-M7E-INSTANCE-RULE red on the exact two-line comparison.
    - ME-6: `rm LICENSE-APACHE`.  PASS-M7E-DEBT-H red on `file`.
11. The user commits.  Nothing lands committed by an agent.

Handoffs out of Stage E: M8 inherits three executable oracles rather than
memories, a SPEC section 6 list whose addresses are true at the M7 exit
commit, the name-independent recognizer definition, the Frozen obligation
with both horns named and unproved, and the wide-relation-formal
direction ratified at open question 5.

---

### Rollback

Stage E is the cheapest stage to unwind, because it changes no code.

1. `git checkout -- SPEC.md README.md lib/check.ml dev/gates.sh test/surface.ml dev/m5e-default-transcript.txt`.
2. `rm test/fixtures/m7e-wf-provenance.tot test/fixtures/m7e-wf-renamed.tot test/fixtures/m7e-launder.tot LICENSE-APACHE`.
3. Rebuild.  The only .ml edits are one comment block in lib/check.ml and
   the additions in test/surface.ml, so the reverted tree gives a
   byte-identical binary and the battery returns to the Stage D exit
   value of 410 PASS, 0 FAIL.
4. Partial rollback is safe in either direction.  The oracle fixtures and
   the SPEC edit share no literal, and the licence half shares nothing
   with either.  Dropping the three fixtures needs the transcript reseal
   reverted in the same step, because PASS-M6E-TRANSCRIPT-RESEALED
   compares the sealed block count against the live glob count.

Gate markers added: 5
Suite cases added: 5
Exit PASS count: 420
