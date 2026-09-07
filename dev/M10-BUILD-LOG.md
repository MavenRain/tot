# M10 build log

## Stage A: strict-positive container nesting

### Entry

The canonical repository was clean at `3525a43`, M9 Stage C.
Implementation and validation use the isolated checkout
`/Users/oobi/Documents/gpt1/tot-m10-stage-a`.

The M9 restored closing battery, whose source is the entry commit,
records 450 slice PASS lines and 454 wrapper PASS lines, 105 kernel
cases and 161 surface cases. Its raw evidence is
`/Users/oobi/Documents/gpt1/tot-m9c-close.log`; its parsed evidence is
`/Users/oobi/Documents/gpt1/tot-m9c-validation.json` under `close`.

A fresh Stage A entry battery was also attempted before source edits:

```sh
zsh -f /Users/oobi/Documents/gpt1/tot-m9b-battery.sh /Users/oobi/Documents/gpt1/tot-m10a-entry.log /Users/oobi/Documents/gpt1/tot-m10-stage-a
```

Build and both standalone suites exited 0. The gate run stopped at
`FAIL-B-DIV-MEMO (exit=0 elapsed=10s)`, with `GATE-EXIT=1`. This is
recorded as a failed timing check, not a green entry measurement.
The subsequent host reading was load average 58.46 with 34 users.
The implementation does not change this gate or its bound.

### Design decisions

The design was written in `dev/M10-PLAN.md` before the checker edit.
It resolves the double-flip obligation with an absorbing forbidden
classification, implemented as strict-positive admission plus
occurrence-free function domains. Certificates inspect every field,
including erased fields, and fail closed on foreign dependency cycles.
Uniform recursive container applications terminate directly.

This first slice limits foreign containers to completed, unindexed
inductives with erased plain universe parameters. Certificate state is
local, with no Global or Term schema change. The format version stays
10. The existing executable-digest cache key handles the changed
checker binary.

The covariant gate is deliberately reopened and retains its marker
with an admission assertion. The contravariant gate retains its
refusal. This corrects the M6 Stage A prediction at SPEC.md:1164-1168
that both must turn red together. The M9 demand-count record stays at
its historical value of two, while its nested-Rule subprobe now
asserts admission.
The wordEnd structural-guard refusal remains in force.

Nested erased recursive families may now be inhabited by empty
containers. The SPEC records an explicit `sx (nil SX)` example and
does not extend the earlier blanket emptiness argument. Syntactic
recursive metadata and the subsingleton restriction remain necessary.
No interpreter or structural-guard rule is changed, and no reachability
proof for Frozen is claimed.

### Review correction: completed container dependencies

The initial suites passed at 109 kernel and 173 surface cases. An
independent review then identified a missing dependency condition at
the public kernel API. It is possible to declare Self provisionally,
complete a phantom-parameter container whose field is `Self -> Nat`,
then attempt to complete Self with a field `Container Self`. Checking
only the container's parameter occurrences missed its closed reference
to Self. The source parser does not offer these forward declarations,
but the public Check API does.

The new K5 regression first completes all setup declarations, then
requires only the final Self declaration to fail. It covers the direct
container, a second completed wrapper and a closed definition alias.
Before the correction, the rebuilt kernel suite exits 1 at K5:
`/Users/oobi/Documents/gpt1/tot-m10a-dependency-red.log`. The checker
correction requires a separate budgeted global-dependency traversal
before a container certificate can be used, with a fresh visited-name
set and explicit refusal of pending families and missing globals.

The old surface C6 control was also corrected: its constructor ended
in Json while declaring Bad, so its refusal tested the result-head
rule rather than recursive nesting. The replacement declares and
returns JsonTree consistently and tests the intended admission.

### Re-derived pins

The corpus membership stays fixed. The default transcript still has
106 file blocks; only `nested-pos.tot` changes from its refusal to four
declaration lines. The settle-budget subset stays at 105 records and
its green count changes from 63 to 64. Its recipe hashes absolute
diagnostic paths, so the isolated and canonical checkouts require
different measured literals:

| Pin | Entry | M10 Stage A |
| --- | --- | --- |
| Canonical settle digest | `7aed51dddf358f0bb1742838b5616717` | `927f270fc883687cfbe63c86e5785db8` |
| Isolated-checkout settle digest | Not used at entry | `269778247a114ac7cb8a2100fab3b518` |
| Tiered watchdog call count | 247 | 250 |
| self_rec source citation | 2066 | 2262 |
| Kernel implementation digest | `e49ff916b7235f223e8dcaa498fc3aee` | `cc8dac9594520f4831d31bc43d7b4e89` |

Both settle digests are measured with the same new binary, once over
isolated paths and once over canonical paths. Corpus source semantics
are identical in those trees; only the nested-positive fixture's
comments change. Canonical installation substitutes exactly one digest
literal. The transcript is generated by `dev/gen-m5e-transcript.sh`.
Detailed records are in
`/Users/oobi/Documents/gpt1/tot-m10a-gates-report.md`.

The first full post-fix clone battery passed both suites and all gates
through M8A's first three checks, then correctly failed the old frozen
kernel digest. Its log is
`/Users/oobi/Documents/gpt1/tot-m10a-clone.log`. Re-derivation confirms
the kernel still has 18 implementations and only `lib/check.ml` differs
from the entry SHA-256 manifest. The other 17 implementations retain
their hashes. The gate now freezes the new literal and still rejects
any subsequent source change. No timing tier or bound changes.

### Restored clone validation and independent review

The final clone battery passes with 469 slice PASS lines and 473
wrapper PASS lines, zero FAIL lines, and all four command exits 0.
Both builds report zero errors and warnings. Its complete suites have
110 kernel cases and 173 surface cases. The raw log is
`/Users/oobi/Documents/gpt1/tot-m10a-clone-close.log`; the parsed
results and exact PASS multiset delta are in
`/Users/oobi/Documents/gpt1/tot-m10a-clone-validation.json`.

The delta from the M9 exit is +19: five kernel cases, twelve surface
cases and two new gate markers. Two old case labels, kernel C4 and
surface C6, are replaced by their explicit nested-admission versions.
Counted over unique labels, the multiset has two intentional
removals and 21 additions, and no other PASS disappears. A raw line
comm shows two further removals and two duplicate additions,
because the battery wrapper echoes the surface suite's last three
lines and the last two surface cases changed. M9B-1 and M9B-2 still
run, at tot-m10a-canonical.log:347-348. All historical gate markers
remain present.

The second independent kernel review reports no correctness findings.
It checks the dependency traversal, parameter indices, uniform
recursive applications, strict domains, per-slot certificate cache,
K5's setup-before-refusal control and the fixed kernel digest
transition. Its evidence is
`/Users/oobi/Documents/gpt1/tot-m10a-final-review.md`.

### Mutation proofs

The final mutation run uses an independent copy of the corrected
checker in `/Users/oobi/Documents/gpt1/tot-m10a-mutations-final`.
Each mutation changes exactly one source line, rebuilds successfully
with zero errors and warnings, and runs the exact gate block extracted
from `dev/gates.sh` by `tot-m10a-gate-legs.py`.

1. Replacing the certified foreign-argument continuation with
   `Ok false` disables nesting. The covariant admission assertion
   reports `FAIL-M6A-FENCE-COVARIANT (exit=1)` and the runner exits 1.
2. Ignoring the Pi-domain occurrence check for a container parameter
   admits the forbidden double-domain and hidden-negative declarations.
   The runnable positive still prints `PASS-M10A-NESTED-RUN`, then
   the refusal assertion reports
   `FAIL-M10A-STRICT-DOMAINS (exit=0/0)` and the runner exits 1.

Original bytes are restored between mutations and at exit. The final
rebuild and both scopes pass all four assertions. The original and
restored checker SHA-256 is
`a01fc08f49e486ccf28d1cebb3fd5c1ecf5787d5cd85fddfb774bf823297e998`,
identical to the reviewed source. Every command, exit, detected marker
and restore digest is recorded in that directory's
`mutation-results.json`. Earlier scratch evidence predating the
dependency correction is superseded by this final run.

### Canonical close (2026-09-07)

All eleven reviewed paths were installed into
`/Users/oobi/Documents/tot`, after checking its clean entry and every
tracked baseline hash. The checkout-specific settle digest was the
only installation substitution. The canonical battery then passed:

- 110 kernel cases and 173 surface cases.
- 469 gate-slice PASS lines and 473 wrapper PASS lines.
- BUILD-EXIT, MAIN-EXIT, SURFACE-EXIT and GATE-EXIT all 0.
- Zero FAIL lines; zero build errors and warnings.

The canonical PASS list is byte-for-byte equal to the validated
clone's PASS list. Raw output is
`/Users/oobi/Documents/gpt1/tot-m10a-canonical.log`; parsed results
and the validated file hashes are in
`/Users/oobi/Documents/gpt1/tot-m10a-canonical-validation.json`.
The per-leg timings are in
`/Users/oobi/Documents/gpt1/tot-m10a-canonical-measure.log`.

This final record is appended after validation. The staging helper
requires every other canonical file to retain its validated hash and
this build log to retain its full validated prefix. It stages all
eleven paths and checks that no unstaged changes remain. No commit
is made. Stage A now leaves C2 to soak before C1 or the Json migration.

### Review round (2026-09-07)

An independent four-lens review of the staged slice raised seven
accepted findings, J1 to J7. Six of the eleven staged paths change:
SPEC.md, dev/gates.sh, dev/M10-PLAN.md, this log, lib/check.mli and
test/main.ml. No implementation file under `lib/` changes, so every
kernel pin holds at its staged literal.

- J1 (HIGH), SPEC.md, dev/M10-PLAN.md and lib/check.mli. Record the
  open direct-alias hole. The dependency walk covers a container
  closure only, so a definition alias in a direct constructor field or
  a direct Pi domain still reads as occurrence free. The entry commit
  3525a43 admits the same shape, so this is inherited debt and not a
  Stage A change. M10 Stage B owns the code.
- J2 (HIGH), test/main.ml. Kernel case M10A-K4 was vacuous. An always
  spent budget fails in `infer_univ` on the whole constructor type,
  before any per-field positivity call, so the case stayed green with
  a plain field. The case now counts the caller's polls for a nested
  field and for a plain field, requires the nested count to be
  larger, and derives the exhaustion threshold from that measurement.
  No literal is pinned. The label and its position do not change.
- J3 (HIGH), SPEC.md and dev/gates.sh. SPEC.md:1715 still cited the
  pre-slice `self_rec` address lib/check.ml:2066. It now cites
  lib/check.ml:2262, and the retired address joins the stale set of
  PASS-M7E-SPEC-CITATIONS at dev/gates.sh:3923.
- J4 (MED), SPEC.md. Four more citations into lib/check.ml drifted.
  The applied-ness range 1964-1976 becomes 2170-2174, two `is_applied`
  addresses move from 1913 to 1911, and the quoted `strict_pos` arm at
  1969 keeps its historical sentence with a measured pointer to the
  shipped predicate. dev/M9-PLAN.md:1487 drifted for the same reason
  and stays open: it is a twelfth path.
- J5 (MED), SPEC.md, dev/M10-PLAN.md and this log. The prediction that
  both fences must turn red together is the M6 Stage A entry at
  SPEC.md:1164-1168. The M9 records predict the opposite. Both the
  plan and this log now name the M6 entry, and
  the M6 Stage A entry points forward to this stage.
- J6 (MED), this log. The indexed-container disjunct has no test. The
  paragraph below records the recipe.
- J7 (MED), this log. The PASS multiset claim now states its counting
  basis.

The indexed-container disjunct at lib/check.ml:2133 is a
total backstop with no test. It cannot be reached from a declaration.
`certificate` is called only under the argument-count equality at
lib/check.ml:2103, so an indexed container must be partly applied to
reach it, and a partly applied type former is refused by `infer_univ`
first: `not a universe: (0 n : Nat) -> Type 0`. Deleting the disjunct
in a clone leaves both suites and the gate battery green. The surface
case M10A-S7 pins the argument-count refusal, which is the reachable
rule.

Both suites run from the fixed tree. The build reports `OK build: 0
errors, 0 warnings`. `test/main.exe` exits 0 with 110 PASS lines and
ends `M0 kernel: all tests green`. `test/surface.exe` exits 0 with 173
PASS lines and ends `M1 surface: all tests green`.

Re-derived pins, old value then new value. Tiered watchdog calls 250
then 250. Watchdog bite calls 2 then 2. The M8A kernel digest
cc8dac9594520f4831d31bc43d7b4e89 then the same literal, over the same
18 implementations. The `self_rec` citation line 2262 then 2262, still
holding `let self_rec = List.exists`. SPEC citations of
lib/check.ml:2262 one then two. SPEC citations of lib/check.ml:2066
one then none. SPEC citations of lib/check.ml:1913 and of
lib/check.ml:1964-1976 three then none. Corpus files 106 then 106.
Kernel cases 110 then 110, surface cases 173 then 173. The settle
digest and every gate figure hold, because no implementation byte and
no diagnostic text changes. The changed legs run green standalone:
PASS-M5E-DEFAULT-IDENTITY, PASS-M6A-FENCE-COVARIANT,
PASS-M6A-FENCE-CONTRAVARIANT, PASS-M7E-SPEC-CITATIONS and
PASS-M8A-KERNEL-UNCHANGED.

The round dropped eight items: the code half of the alias hole, which
M10 Stage B owns; a mutual-container regression that cannot show which
guard it reached; the one reason string shared by eight causes, whose
repair moves every pinned message; the refuted indexed-container test
spec, kept as the record above; the twelfth-path citation in
dev/M9-PLAN.md; and three LOW prose or style items.
