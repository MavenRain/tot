# M5 build plan: pay the measured debts

Authoritative spec for the M5 implementation agents.  Read this WHOLE
file before you read your own stage section, and read it before you
touch code.  The repo is `/Users/oobi/Documents/tot` (OCaml, dune).
Five sequential stages (A, B, C, D, E), one agent per stage, each stage
green on its own gate before the next one starts.

This document is self-contained.  Every design decision M5 needs is
written out in this preamble or in a stage section.  Do NOT go looking
for the design brief, the panel JSON, or the verdict;  none of them are
inputs to the build.  The verdict at
`/Users/oobi/Documents/tot-m5-design-verdict.md` was ratified on
2026-09-02 with five amendments, and section 4 below restates it as one
renumbered, normative pin list.  Section 4 is the authority, and
section 5 is the protocol for a pin that disagrees with the repo.  A stage
section may add detail to a pin.  A stage section may NOT reinterpret a
pin, soften it, or trade it for a different one.  If you believe a pin
is wrong, record the argument in `dev/M5-BUILD-LOG.md` and build it as
written.

Background reading, in this order, only if a detail here is ambiguous:

1. `/Users/oobi/Documents/tot/SPEC.md` sections 2, 4 and 6
2. `/Users/oobi/Documents/tot/dev/M4-PLAN.md` (the house plan format)
3. `/Users/oobi/Documents/tot/dev/M4-FIXES-LOG.md` rounds 3 to 6 (the
   instance memo, the term-size measurement, and the fuel leaf)

## 1. Purpose and entry state

M5 pays debts that M4 MEASURED.  It adds no kernel typing rule.  It
opens no door over the `Frozen` emptiness claim, which SPEC records as
UNPROVEN.  Four things ship: instance term sharing, a driver check
budget, JSON conformance in the parser and the serializer, and a gate
system that reports its own cost.  One thing is a spike only: a
well-founded recursion prototype behind an experimental flag.

### 1.1 Baseline

M4 is committed at `34ea009`.  The working tree is clean at that
commit, verified 2026-09-02 with `git -C /Users/oobi/Documents/tot
status --porcelain` (empty output).

The suite baseline, recorded by the M4 close-out round and carried here
as the arithmetic gate:

    dunecho build                      OK build: 0 errors, 0 warnings
    dune exec test/main.exe            86 "PASS " lines
    dune exec test/surface.exe        100 "PASS " lines
    zsh dev/gates.sh                   GATE-EXIT=0, 92 gate markers
                                       (91 own `echo PASS-` sites plus
                                        the replayed prim-lint marker)

    TOTAL BASELINE: 86 + 100 + 92 = 278 PASS, 0 FAIL, 0 SKIP

Every stage gate runs ON TOP of that number.  A stage that ends with
fewer than 278 plus its own additions has broken something.  Never
delete or weaken an existing case to make a stage green.

Gate command battery (all must be green before you report):

    dunecho build -- --root /Users/oobi/Documents/tot
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -3
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -3
    zsh /Users/oobi/Documents/tot/dev/gates.sh > "$TMPDIR/tot-gate.out" 2>&1; echo "GATE-EXIT=$?"
    rg -c '^PASS' "$TMPDIR/tot-gate.out"
    rg -c '^FAIL' "$TMPDIR/tot-gate.out"

Run the battery BEFORE you edit anything.  Record the tails in your
report.  A red at baseline belongs to the previous stage, not to yours,
and you must say so instead of absorbing it.

### 1.2 Facts about the CURRENT binary

Each line below was produced by running
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe` on 2026-09-02
with `TOT_PRELUDE=/Users/oobi/Documents/tot/stdlib/prelude.tot`.  The
probe scripts are `/Users/oobi/Documents/tot-m5-plan-sections/probes/`
`p3-spec.sh`, `p5-binary.sh`, `p7-fence2.sh`, `p8-entry.sh`,
`p10-argv.sh` and `p11-wf.sh`.  Fixtures live beside them, never in the
repo.  Do NOT restate any of these from memory.  Re-run the probe if
your stage depends on the exact bytes.

- LIVE BYPASS.  The payload
  `{"tool_name":"Bash","tool_input":{"command":"grep foo"}}` piped
  to `tot run examples/guard.tot` prints NOTHING on stdout and stderr
  and exits 0 (allow).  The literal spelling `grep foo` prints the deny
  envelope on one line and exits 2:
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed"}}`
- `"\ud800"` in the same payload position also exits 0 (allow), by the
  same route: the parser rejects the escape, `jsonParse` returns
  `none`, and `guard.tot` maps `none` to `allow`.
- `jsonSerialize (jstr "a\rb")` prints a RAW carriage return inside the
  JSON string.  `od -c` on the driver's stdout reads
  `" a \r b "`.  That text is not valid JSON.
- The `Acc` shape checks at exit 0 and prints two lines:
  `data Acc : (0 A : Type 0) -> (0 R : (w _ : A) -> (w _ : A) -> Type 0) -> (0 _ : A) -> Type 0`
  and the matching `ctor acc : ...` line.
- A constructor argument above the declared universe is rejected with
  `invalid constructor badc: constructor argument lives above the declared universe`, exit 1.
- An index type above the declared universe is rejected with
  `inductive BadIx: index i lives above the declared universe`, exit 1.
- A self-occurrence in a Pi DOMAIN is not declarable at all.  Both
  `(0 f : (0 s : SPn) -> Nat) -> SPn` and the doubly nested
  `(0 f : (0 g : (0 s : SPd) -> Nat) -> Nat) -> SPd` are rejected with
  `negative or non-uniform occurrence of <name>`, exit 1.
- The all-erased self-recursive-under-Pi family
  `data SP : Type 0 := | node : (0 f : (0 n : Nat) -> SP) -> SP` is
  declarable, and eliminating an erased `SP` at mode `w` fails with
  `erased variable s used at runtime`, exit 1.  The same elimination on
  the non-recursive control `data Uni := | mkUni : (0 n : Nat) -> Uni`
  checks at exit 0.
- `tot check --require-main ok.tot` on a mainless file writes
  `<path>:this file must define a driver main, and it does not` to
  stderr and exits 1.  With `--serror-exit 0` the SAME line appears and
  the exit is 0.
- A missing file writes `<path>: no such file` and exits 1 both bare
  and under `--serror-exit 0`.
- `--strict-json` and `--check-budget-ms` do not exist.  Each gives
  `unknown flag: --strict-json` on stderr and exit 2.
- Exit code 3 is ALREADY reachable from a script.  A `main` of
  `let* Unit Verdict u := exitWith 3 in pureIO Verdict allow` exits 3
  with empty stdout and empty stderr.
- `exitWith` takes ONE argument and produces `IO Unit`.
  `exitWith Verdict 3` is a type error.
- The driver accepts exactly ONE positional path.  `parse_flags`
  (bin/tot.ml:157-173) consumes leading flags only, an unknown `--`
  argument is `unknown flag`, and `check_or_run` (bin/tot.ml:186-200)
  prints the usage line and exits 2 for zero paths or two.  A guard
  script therefore has NO argv channel of its own.
- The panel's divergence witness rejects on the guard alone.
  `data TT : Type 0 := | mk : (w f : Nat -> TT) -> TT` declares at
  exit 0 with `data TT : Type 0` and
  `ctor mk : (w f : (w _ : Nat) -> TT) -> TT` on stdout, and the
  recursive def over it fails with
  `recursive definition bad failed the structural termination guard`,
  exit 1.  The universe annotation `: Type 0` is MANDATORY on the
  `data` header.  The verdict's own spelling
  (`data T := | mk : (Nat -> T) -> T`, verdict line 54) omits it and is
  therefore elliptical, not runnable: re-run on 2026-09-02 it gives
  `parse error: expected ':', found ':='` and exit 1, so the witness
  never reaches the guard.  Use the annotated spelling in every
  fixture, and do not copy the verdict's text into a file.

### 1.3 Verified anchors

Every file and line a pin cites was read at `34ea009` on 2026-09-02.
Use these anchors, not the ones in the verdict text, where the table
says CORRECTED.

| Anchor | Content | Status |
| --- | --- | --- |
| lib/interp.ml:286-287 | `[ '\\' ] -> None` and `'\\' :: _ :: _ -> None`, the arms that reject every unknown escape | CORRECTED from `:288`, which is the ordinary-character arm |
| lib/interp.ml:375-380 | the doc-comment claim that `Pp.escape_string` is a valid JSON quoter | CORRECTED from `:375-381`; line 381 is `let rec json_serialize` |
| lib/totality.ml:43-61 | `Totality.mentions` | exact |
| lib/totality.ml:50 | the Pi arm, `mentions name dom \|\| mentions name cod` | added, the mutation site for P15 |
| lib/totality.ml:52 | the App arm, both halves | exact |
| lib/check.ml:212-222 | `zero_eliminable`, the three-part fence | added |
| lib/check.ml:221 | the `not ctor.Global.self_rec` conjunct | added |
| lib/check.ml:1000 | `resolve_auto ... (inst_start (inst_fuel globals expected_t) expected_v)`, the production call site of `inst_fuel` | exact |
| lib/check.ml:1002 | `check globals ctx mode candidate expected_v`, the `Auto` site re-check | exact |
| lib/check.ml:1578 | `infer_univ` in the parameter fold, whose level is DISCARDED (`let* ty', _l`) | exact |
| lib/check.ml:1591-1594 | the `Level.le l level` bound on index types | exact |
| lib/check.ml:1799-1803 | the strict-positivity rejection | added |
| lib/check.ml:1806-1813 | the `Level.le l ind.Global.level` bound on constructor arguments | exact |
| lib/check.ml:1828 | `self_rec = List.exists (fun (_q,_x,ty) -> Totality.mentions name ty) args`, over ARGUMENT types only | added |
| lib/error.ml:169-170 | `Exit_code_out_of_range`, the `0..255` range message | CORRECTED from `:170` alone |
| bin/tot.ml:157-173 | `parse_flags` | added |
| bin/tot.ml:186-200 | `check_or_run`, exactly one positional path | added |
| surface/cache.ml:118 | `let format_version : int = 10` | added |
| SPEC.md:1220-1221 | the JSON conformance debt | added |
| SPEC.md:1222-1223 | the check-budget debt | added |
| SPEC.md:1230-1243 | the `--require-main` advisory debt | added |
| SPEC.md:1267-1286 | the TERM SIZE measured entry | added |
| SPEC.md:1287-1312 | the `inst_fuel` measured entry, reach half and time half | added |

## 2. Scope

### 2.1 IN

| # | Item | Stage | Why it is in |
| --- | --- | --- | --- |
| 1 | Instance term sharing as a local `let`-nest at the `Term.Auto` site, plus `Term.shift` and cached instance VALUES | B | pays the measured term-size debt (SPEC.md:1267-1286) with no `Term.t` change and no cache-format change |
| 2 | `--check-budget-ms N`, default off, CPU milliseconds, opaque `Budget.t` poll supplied by the driver | C | pays the measured time debt: a linear 800-box chain today exceeds 60s with NO verdict at all |
| 3 | `inst_fuel` multiplied by the registered class count, with the K leaf RE-BISECTED and the gate re-pinned 20 percent under the new leaf | C | pays the measured reach debt: K = 60 resolves and K = 61 reports `Inst_depth` |
| 4 | JSON conformance ON THE PARSER: `\uXXXX` with surrogate pairs, `none` on a lone surrogate or a short escape, and a JSON-specific serializer escaper covering all of C0 | A | the only LIVE exploit in the panel, reproduced in 1.2 |
| 5 | `--strict-json`: a payload the parser REJECTS denies (exit 2) instead of falling open to allow | A | amendment A2; a parse failure must not stay a silent allow |
| 6 | Gate-leg consolidation into named tiers plus `gate_timed` | D | 89 numeric watchdog literals across 8 values hide the battery's real cost |
| 7 | Fence pin: the all-erased self-recursive-under-Pi shape keeps `self_rec = true` and stays NOT `zero_eliminable` | A | amendment A5; nothing gates today that `mentions` walks under a Pi |
| 8 | A dated SPEC entry plus one positive and one negative gate for the parameter-level predicativity exemption at lib/check.ml:1578 | A | amendment A5; the exemption is what makes `Acc` check, and it is unstated and ungated |
| 9 | `--require-main` becomes a DRIVER failure: one stderr line, exit 1, outside the `--serror-exit` mapping | C | amendment A3; a mainless target is a verdict about the target, like a missing file |
| 10 | Dogfood: `examples/guard.tot` echoes the offending command, the map-over-rewrap PreToolUse guard is ported as a third real hook, and the escape-bypass fixture is the milestone's headline regression test | D | the guard is the deliverable the milestone is measured on |
| 11 | Hole-anchor MEASUREMENT: count the dogfood anchors solvable by expected-type-only matching | D | M6 sizes holes from a real corpus, not from taste |
| 12 | SPEC section 2 dated entries for every pin, and section 6 rewritten with post-M5 numbers | D | pin P18 |
| 13 | A well-founded recursion SPIKE behind an experimental flag | E | amendment A4; the deliverable is measurements and SPEC notes, not a shipped feature |

### 2.2 OUT

| Item | Why it is out |
| --- | --- |
| Nested and mutual inductives, and the `jarr : List Json -> Json` migration | the MUTUAL gap: `Totality.mentions` tests only the family's OWN name (lib/check.ml:1828), so a recursive PAIR reads as non-self-recursive over an emptiness claim SPEC records as UNPROVEN.  The nesting argument is FALSE and must not be repeated: `mentions` recurses into both halves of `App` (lib/totality.ml:52), so a nested `jarr` still gives `self_rec = true` |
| Holes | `infer`'s App arm (lib/check.ml:770-779) consumes one argument at a time and evaluates the stamped argument to instantiate the codomain, and `check` has NO dedicated App arm: it routes App through `check_via_infer` (lib/check.ml:1003-1006).  So every dogfood anchor needs postponement or bidirectional application checking.  That is a milestone, not a slot.  M5 owes item 11's measurement instead |
| Well-founded recursion as a SHIPPED feature | its kernel delta sits in `Totality.guard`, the most soundness-critical function, and the panel's own witness (1.2) shows the typed rule is one missing precondition away from admitting divergence.  Stage E spikes it behind a flag and ships no default-path change |
| `Frozen_rec` as a definition-time error | TIED to well-founded recursion.  On every def M5 can construct, `Frozen` is already dead code, so the change buys nothing until `Acc` values appear at erased quantity |
| Universe polymorphism | no shipped guard needs a `Type 1` equation, and `Acc` needs none either (1.2).  It reshapes `Level.t`, `Term.Univ`, `conv`, `ind_entry`, the parser and the cache |
| Global hash-consing | physical identity does not survive `Marshal`, so hash-consing crosses the cache boundary that item 1 avoids |
| Bounded regex engine | its own mini-milestone.  `Str` stays single-threaded-safe |
| The prim catalog trust boundary | restated unchanged.  `dev/prim-lint.sh` stays the mitigation |
| `Div` provenance | restated unchanged.  `Div` gives provenance, not a termination proof |

One scope-out line of the verdict is SUPERSEDED.  The verdict deferred
`--require-main`'s advisory mapping as CODE.  Amendment A3 overrides
that and moves it IN as item 9.  Where the two disagree, A3 wins.

## 3. Stage overview

Each stage has ONE entry condition and ONE exit condition, and both are
arithmetic.  A stage reports the `rg -c '^PASS'` number with its
decomposition, or it is not done.

### Stage A. JSON conformance, the strict-JSON posture, and the two fence pins

Entry: M4 HEAD `34ea009`, clean tree, 278 PASS / 0 FAIL / 0 SKIP,
GATE-EXIT=0.

Contents: `\uXXXX` with surrogate PAIRS in `Interp`'s JSON parser;
`none` on a lone surrogate and on a short escape; a new JSON escaper
covering `\b`, `\f`, `\r` and `\u00XX` for all of C0, with
`Pp.escape_string` left as the SOURCE escaper and its false reuse claim
(lib/interp.ml:375-380) corrected in the same commit; `--strict-json`
in `parse_flags` (bin/tot.ml:157-173), carried as a `Run.policy` field
and enforced at `Effect.dispatch`'s `Prim.Read_stdin` arm, so the guard
script needs no edit and no argv read (Stage A section A4 records the
repo evidence and the dated conflict note); pin P15's fence pin; pin
P16's predicativity pin.

Exit: 278 plus the Stage A markers, 0 FAIL, GATE-EXIT=0, every new gate
mutation-proved by the recorded mutation and the observed flip.
Reserved markers, eight, and Stage A's section A10 ships exactly these
eight: `PASS-M5A-BYPASS`, `PASS-M5A-FIXTURE-BYTES`,
`PASS-M5A-ENVELOPE-VALID`, `PASS-M5A-LONE-SURROGATE`,
`PASS-M5A-STRICT-DENY`, `PASS-M5A-STRICT-ALLOW`, `PASS-M5A-FENCE-PI`,
`PASS-M5A-PARAM-LEVEL`.  `PASS-M5A-STRICT-ALLOW` carries the
default-off half that an earlier draft called `PASS-M5A-STRICT-OFF`;
the name moved, the assertion did not.  `PASS-M5A-FIXTURE-BYTES` guards
the bypass fixture's own escape bytes and has no earlier name.

Stage A goes FIRST for one reason: it is the only live exploit, it is
independent of every other item, and the two riskiest items must not be
able to strand it.

### Stage B. Instance term sharing

Entry: Stage A green.

Contents: `Term.shift ~cutoff ~by`, total and exhaustive over all
eleven constructors; the `islot` accumulator and its materializer;
`inst_state.memo : int InstMemo.t` plus `entries`; cached instance
VALUES beside cached terms; a physical-equality shortcut in
`Eval.conv`; NEW generators `dev/gen-inst-branching.py` and a chain
generator, because the committed fixtures stop at nesting 16 and k=8
n=40 and no committed generator produces depth 20 or 800 boxes.

Exit: Stage A's number plus the Stage B markers, 0 FAIL, GATE-EXIT=0.
Reserved markers: `PASS-M5B-SHIFT`, `PASS-M5B-SHARE-SIZE`,
`PASS-M5B-BRANCHING-20`, `PASS-M5B-FUEL-REACHABLE`,
`PASS-M5B-RUNTIME-IDENTITY`.  `PASS-M5B-FUEL-REACHABLE` must exercise
the production call site at lib/check.ml:1000.  A leg at `inst_start 1`
stays green for ANY bound and duplicates three existing cases, so it
does not count.  chains-800 is explicitly NOT a Stage B gate: that
shape has no duplicate `(class, key)` pairs, so sharing cannot help it,
and P4's per-slot type annotation may make it slower.  Chains is Stage
C's evidence.

### Stage C. Check budget, fuel, and the driver contract

Entry: Stage B green.

Contents: `lib/budget.ml` with an opaque driver-supplied poll;
`ctx.budget` defaulting to `Budget.unlimited`; polls in `infer`, `check`
and each `build_instance` step; `Error.Check_budget`;
`--check-budget-ms`; exit 3 with one exact stderr line, outside the
`--serror-exit` mapping; the class-count factor in `inst_fuel`; the
leaf RE-BISECTION with a stated upper bound and a stated stopping rule;
`--require-main` moved to the driver contract.

Exit: Stage B's number plus the Stage C markers, 0 FAIL, GATE-EXIT=0.
Reserved markers, seven, and Stage C ships exactly these seven:
`PASS-M5C-BUDGET-FIRES`, `PASS-M5C-BUDGET-QUIET`,
`PASS-M5C-DETERMINISM`, `PASS-M5C-CLASSES-61`, `PASS-M5C-LEAF-MARGIN`,
`PASS-M5C-REQUIRE-MAIN-DRIVER`, `PASS-M5C-REQUIRE-MAIN-OK`.
`PASS-M5C-REQUIRE-MAIN-OK` is the positive half of the driver contract,
and it keeps the DRIVER leg from passing on a binary that rejects every
file.  `PASS-M5C-DETERMINISM` compares stdout
and stderr byte for byte against Stage B's output with NO flag.

### Stage D. Gate tiers, measurement, dogfood, and SPEC

Entry: Stages A, B and C green.

Contents: tiers FAST=10, MED=30, SLOW=120, SUITE=300; `gate_timed` and
the measurement log; `examples/guard.tot` extended to echo the
offending command; the map-over-rewrap guard ported from
`~/.claude/hooks/map-over-rewrap-bash-guard.py` as a third real hook;
the hole-anchor measurement; SPEC section 2 entries for every pin; SPEC
section 6 rewritten with post-M5 numbers.

Exit: Stage C's number plus the Stage D markers, 0 FAIL, GATE-EXIT=0,
and `rg -c '"\$watchdog" [0-9]+' dev/gates.sh` EXITS 1.  Reserved
markers, six, and Stage D ships all six: `PASS-M5D-TIERS`,
`PASS-M5D-MEASURE-LOG`, `PASS-M5D-TIER-BITES`, `PASS-M5D-GUARD-ECHO`,
`PASS-M5D-REWRAP-GUARD`, `PASS-M5D-HOLE-ANCHORS`.  Scope item 10's
third hook and scope item 11's measurement each carry their OWN marker.
Neither may ship gated only by another leg, because a gate that covers
two deliverables cannot say which one broke.

### Stage E. Well-founded recursion SPIKE

Entry: Stages A, B, C and D green.

Contents: an experimental flag; a prototype `Acc`-driven recursor
behind it; the panel divergence witness of 1.2 pinned as a NEGATIVE
under the flag; measurements and SPEC notes that size M6.

Exit: Stage D's number plus the Stage E markers, 0 FAIL, GATE-EXIT=0,
and the default path byte-identical to Stage D's.  Reserved markers,
three, and Stage E ships exactly these three:
`PASS-M5E-DEFAULT-IDENTITY`, `PASS-M5E-ACC-CHECKS`,
`PASS-M5E-WITNESS-REJECTED`.  `PASS-M5E-DEFAULT-IDENTITY` carries the
flag-off assertion an earlier draft called `PASS-M5E-WF-FLAG-OFF`, and
`PASS-M5E-WITNESS-REJECTED` carries the pinned negative that draft
called `PASS-M5E-WF-DIVERGENCE-WITNESS`.  Both names moved and neither
assertion did.  `PASS-M5E-ACC-CHECKS` is new: it proves the flag is
LIVE, so a dead flag cannot make the other two pass by accident.
Stage E
ships NO default-path behavior change.  If the spike cannot be built
without one, Stage E stops and records why.

## 4. Normative pins

The verdict's 18 pins and the 5 ratification amendments, renumbered as
one list.  P1 to P18 carry the verdict numbering.  P19 to P23 carry
amendments A1 to A5 and TIGHTEN the earlier pins they name.  Every pin
below is binding on every stage.  There are 23 pins and five stages.

**Citation rule, because `P<n>` is overloaded.**  Always put the WORD
in front of the number.  A pin is `pin P17` or `pin 17`.  A probe row
is `probe P17`.  Never write a bare `P17` outside this section, where
the pin list itself is the context.  Each stage section opens with a
PROBE table whose rows are labelled `P1`, `P2` and so on;  those are
probe IDs, they are local to their own section, and they carry NO
relation to the pin of the same number.  Probe P13 in Stage B is a
zero-quantity dictionary binder;  pin P13 is the JSON escaper rule.
Every stage cites the pins it implements: Stage A owns pins P13, P14,
P15, P16, P20 and P23, Stage B owns P1 to P7, Stage C owns P8 to P12,
P19 and P21, Stage D owns P17 and P18 and audits the whole set, and
Stage E owns P22.  The five
amendment pins P19 to P23 are therefore each cited by the stage that
implements them.

**P1. Sharing is local.**  Instance term sharing is a LOCAL `let`-nest
at the `Term.Auto` site.  It is not global hash-consing.  `Term.t` is
unchanged.  `Cache.format_version` (surface/cache.ml:118, currently 10)
does NOT move, so an older cache holds unshared but valid terms and
stays readable.

**P2. `Term.shift` is total and exhaustive.**  `Term.shift ~cutoff ~by`
covers all eleven `Term.t` constructors with a spelled-out arm each.
No catch-all arm.  `m_body` uses `cutoff + List.length m_idx + 1`.  A
branch body uses `cutoff + List.length binders`.

**P3. The instance state shape is fixed.**  `inst_state =
{ fuel; memo : int InstMemo.t; entries : inst_entry list; goal }` with
`inst_entry = { e_ty; e_def : islot; e_val : Value.t }`.  `entries` is
in REVERSE definition order, which is dependency order.

**P4. The slot representation is fixed.**  `islot = IHead of string |
IApp of Quantity.t * islot * iarg` and `iarg = IType of Term.t | ISlot
of int`.  Entry `i` under `i` enclosing lets sends `IType t` to
`Term.shift ~cutoff:0 ~by:i t` and `ISlot j` to `Term.Var (i - 1 - j)`.
Each let type is the shifted `App (q_cls, Global cls, key_t)`, with
`q_cls` taken from the class's OWN `ind_entry`.

**P5. A memo HIT is a slot reference.**  A hit returns `ISlot j` and the
cached `e_val`.  `build_instance` NEVER re-evaluates a cached term.

**P6. Sharing is a performance change under an unchanged kernel rule.**
The `Auto` site re-checks its candidate at lib/check.ml:1002, so a
mis-shifted nest is a loud failure and never a wrong dictionary.  Do
not weaken that re-check to buy speed.

**P7. Key-type sharing is a measured option.**  Whether to share key
TYPES as well is decided by Stage B's exit measurement, with the same
materializer and no new design.  It is not a design question inside
Stage B.

**P8. `Budget.t` is opaque and driver-supplied.**  It holds a
`poll : unit -> bool` supplied by the driver.  `lib/` reads no clock,
holds no mutable state, and raises nothing.  `ctx.budget` defaults to
`Budget.unlimited`, so no existing call site changes.

**P9. The budget is a cutoff, not a guarantee.**  It fires at kernel
NODE granularity.  It is not a real-time guarantee.  Decision 13's
external `timeout` stays the belt for one pathological `Eval` or `Conv`
call, and the hook install keeps it.  The claim that installs may drop
`timeout` is RETRACTED and must not reappear.

**P10. Budget exhaustion is one code plus one exact line.**  It exits a
reserved code OUTSIDE the `--serror-exit` mapping and writes one exact
stderr line.  The stderr LINE, not the code alone, is the discriminator
a hook matches, because a script can already exit any code in 0..255
(`exitWith`, range message at lib/error.ml:169-170; probe R1 exits 3
today with empty stderr).  P19 fixes the number.

**P11. `--check-budget-ms N` defaults to 0, meaning off.**  It applies
to `check` and to `run`.  With no flag, verdicts stay byte-identical
and deterministic.

**P12. The fuel bound is measured, not proved.**  `inst_fuel` keeps the
round-5 shape and multiplies by `1 + class_count globals`.  The leaf is
RE-BISECTED, with an upper search bound and a stopping rule written in
the gate comment.  The gate is pinned 20 percent UNDER the measured
leaf.  The claim that the factor removes the leaf "by construction" is
dropped.  If no leaf is found inside the bound, the gate records the
bound reached and does not invent a margin.

**P13. Two escapers, one parser rule.**  `Pp.escape_string` stays the
SOURCE escaper.  The JSON serializer gets its OWN escaper.  The parser
accepts `\uXXXX` and surrogate PAIRS and returns `none` on a lone
surrogate and on a short escape.

**P14. The positivity door stays SHUT.**  The recorded reason is the
MUTUAL gap in `Totality.mentions`, which tests only the family's own
name (lib/check.ml:1828).  It is NOT a nesting gap.  The SPEC entry
corrects the nesting claim explicitly.

**P15. The subsingleton fence gains one executable pin.**  A
self-recursive occurrence under a Pi keeps `self_rec = true`, so the
family stays outside `zero_eliminable` (lib/check.ml:212-222).  The pin
is mutation-proved against a `mentions` that drops the Pi CODOMAIN
half at lib/totality.ml:50.  See conflict note C1: the verdict's
"skip Pi domains" mutation is vacuous at M4 HEAD.

**P16. The predicativity exemption gets written down.**  The
parameter-level exemption at lib/check.ml:1578 becomes a dated SPEC
section 2 entry with ONE positive gate and ONE negative gate.  The
positive is the `Acc` shape at exit 0.  The negative is a constructor
argument at the same level, still rejected at lib/check.ml:1806.  No
milestone spends this exemption as evidence again until it is written
down.

**P17. Gate budgets are named tiers.**  No numeric watchdog literal
survives in `dev/gates.sh`.  The oracle is
`rg -c '"\$watchdog" [0-9]+' dev/gates.sh` asserted on EXIT STATUS, not
on absent output.  See conflict note C2 for the measured corpus.

**P18. Every pin becomes a dated SPEC entry.**  Every pin in this list
becomes a dated SPEC section 2 entry.  SPEC section 6's measured claims
are rewritten with post-M5 numbers.  See conflict note C3 and the
checklist in section 7.

**P19 (was A1). The reserved code is 3.**  Budget exhaustion exits 3,
the smallest code outside the shipped verdict set 0/1/2.  It stays
outside the `--serror-exit` mapping.  It pairs with one exact stderr
line, which remains the load-bearing discriminator because `exitWith`
lets a script emit any code in 0..255.  The PreToolUse harness treats
codes other than 0 and 2 as non-blocking, so the default posture on
budget exhaustion matches the current external-timeout posture.  An
installation that wants fail-closed wraps the driver.  P19 fixes the
open number in P10.

**P20 (was A2). The parse-failure posture is `--strict-json`.**  Under
the flag an unparseable or non-conforming payload DENIES with exit 2
instead of falling open to allow.  Without the flag the fail-open
posture is unchanged, so no installed guard changes behavior on
upgrade.  The flag lives in the DRIVER flag list (bin/tot.ml:157-173).
Amendment A2 itself delegates the rest: "Where the flag lives (driver
vs guard argv) is resolved in the plan against the repo."  Stage A
section A4 performs that resolution and it is BINDING: the flag travels
as a `Run.policy` field and is ENFORCED at `Effect.dispatch`'s
`Prim.Read_stdin` arm, the one raw stdin read in the tree, so `lib/` is
untouched and the guard script needs no edit and no argv read.
`Prim.Argv` exists and is wired (lib/prim.ml:44,
surface/bootstrap.ml:144, surface/effect.ml:276), so the argv route is
POSSIBLE.  It is rejected on coverage, not on feasibility: a script
that ignores the flag still falls open, so the flag would guarantee
nothing.  Section 5 rule 4 therefore does not apply, because the pin's
INTENT is kept whole and only a mechanism this pin never had to fix has
moved.  `check_or_run` accepts exactly one positional path
(bin/tot.ml:186-200), so a script has no argv channel of its own either
way.  An operator turns the flag on by spelling the hook command
`tot run --strict-json <guard>`, not by editing the shebang.

**P21 (was A3). `--require-main` is a DRIVER failure.**  A mainless
target takes the driver contract: one stderr line, exit 1, outside the
`--serror-exit` mapping, exactly like a missing file.  Today the same
file under `--serror-exit 0` exits 0 (probe P10), which a hook reads as
allow.  That is the behavior P21 removes.  The stderr TEXT stays
`<path>:this file must define a driver main, and it does not`, so only
the exit mapping moves.

**P22 (was A4). M5 spikes well-founded recursion behind an
experimental flag.**  The default path stays byte-identical.  The panel
divergence witness is a pinned NEGATIVE under the flag.  The
deliverable is measurements and SPEC notes that size M6.  It is not a
shipped feature, and no stage may promote it to one.

**P23 (was A5). Both Stage A fence pins are ACCEPTED.**  The
mentions-under-Pi `self_rec` pin (P15) and the dated SPEC entry plus
two gates for the parameter-level predicativity exemption (P16) are in
scope for Stage A.  They are additions to the winning proposal, and the
user ratified them.

## 5. Conflict-resolution protocol

A stage section may find that a pin disagrees with the repo.  When that
happens, follow this protocol exactly.

1. Re-run the claim against the built binary or read the cited lines.
   Do not resolve a conflict from memory or from the verdict text.
2. Record a DATED conflict note in the stage section itself, in the
   form `Conflict note C<n> (YYYY-MM-DD): <pin> says X;  the repo at
   <file:line> shows Y;  resolution: Z`.
3. Report the note in the stage's return value and in
   `dev/M5-BUILD-LOG.md`.
4. This preamble's pin list WINS, unless the repo PROVES the pin
   impossible.  "Impossible" means an executed probe, a compiler error,
   or a cited line, and never an opinion about design.  Where the repo
   proves the pin impossible, the pin's INTENT survives and only its
   mechanism changes.  Record both halves.
5. A conflict never silently shrinks a gate.  If a mutation proof
   cannot be built as written, replace the mutation, prove the flip,
   and say so.  Do not drop the leg.

Four conflicts are already resolved here.  A stage section inherits
these resolutions and does not re-litigate them.

**Conflict note C1 (2026-09-02): P15's mutation as written is
VACUOUS.**  The verdict specifies the mutation "make `mentions` skip Pi
domains".  `self_rec` is computed over the constructor's ARGUMENT types
only (lib/check.ml:1828), and strict positivity rejects every
declaration whose self-occurrence sits in a Pi DOMAIN: probes Q1 and Q2
both exit 1 with `negative or non-uniform occurrence of <name>`, at one
and at two levels of nesting.  So no admissible declaration has a
domain occurrence, and dropping the domain half of lib/totality.ml:50
cannot flip any leg.  Resolution: the pinned SHAPE and the pinned
OUTCOME are unchanged, and the MUTATION becomes the CODOMAIN half.
Mutate lib/totality.ml:50 to `| Term.Pi (_q, _x, dom, _cod) -> mentions
name dom`.  Observed today without the mutation: the fixture exits 1
with `erased variable s used at runtime`.  Under the mutation
`self_rec` goes false, the family enters `zero_eliminable`
(lib/check.ml:212-222), and the leg flips to exit 0.  Stage A records
both runs.

**Conflict note C2 (2026-09-02): P17's corpus count is 89, not 91.**
`rg -c '"\$watchdog" [0-9]+' dev/gates.sh` prints 89 and exits 0 at
`34ea009`.  The 89 sites carry 8 distinct values: 30 (46 sites), 15
(26), 5 (8), 10 (4), 60 (2), 300 (1), 20 (1), 120 (1).  The verdict's
own refutation of the losing oracle reproduces: `rg -c '\$watchdog
[0-9]' dev/gates.sh` matches nothing and exits 1 at M4 HEAD, so that
spelling is green before any work and must not be used.  Resolution:
the oracle text is exactly `rg -c '"\$watchdog" [0-9]+' dev/gates.sh`
asserted on EXIT STATUS, the corpus is 89 sites, and Stage D counts the
suite invocations at gates.sh lines 36 and 38 among them.

**Conflict note C3 (2026-09-02): SPEC section 6 holds THREE measured
CLAIMS in TWO entries.**  P18 says "section 6's three measured
entries".  The repo has SPEC.md:1267-1286 (the TERM SIZE entry, 19.6s
at nesting 20, 1.03s at 16, 0.064s at 12) and SPEC.md:1287-1312 (the
`inst_fuel` entry, which carries BOTH the reach half, K = 60 resolves
and K = 61 rejects, AND the time half, 41.4s at depth 18 and the
800-box chain at exit 124).  Resolution: Stage D rewrites the three
CLAIMS across those two entries, and additionally RETIRES the JSON
conformance debt (SPEC.md:1220-1221) and the check-budget debt
(SPEC.md:1222-1223).  Nothing in section 6 keeps a pre-M5 number that
M5 changed.

**Conflict note C4 (2026-09-02): three cited line numbers drifted.**
The verdict cites lib/interp.ml:288 for the unknown-escape rejection,
lib/interp.ml:375-381 for the false reuse claim, and lib/error.ml:170
for the `exitWith` range.  The rejecting arms are lib/interp.ml:286-287
(288 is the ordinary-character arm), the reuse claim is
lib/interp.ml:375-380 with `json_serialize` starting at 381, and the
range message is lib/error.ml:169-170.  Resolution: the anchors in
section 1.3 replace the cited ones.  Every other cited anchor was read
and holds exactly.

## 6. Gate namespace and mutation proofs

### 6.1 Namespace

Every new gate marker uses the `PASS-M5<stage-letter>-*` namespace:
`PASS-M5A-*`, `PASS-M5B-*`, `PASS-M5C-*`, `PASS-M5D-*`, `PASS-M5E-*`.
`dev/gates.sh` at `34ea009` holds 91 `echo PASS-` sites and no name
starting with `PASS-M5`, verified 2026-09-02, so the namespace is free.
Do not reuse or edit an existing marker name.  Do not add a marker
outside your stage's letter.  Section 3 reserves the names per stage.
A stage that needs a marker not reserved there adds it under its own
letter and records the addition in `dev/M5-BUILD-LOG.md`.

Write each leg in the file's existing capture-then-assert idiom.  The
FAIL branch replays the captured output and exits 1.  Assert on an
exact exit code, an exact line, or an exact value.  Never assert on
"no error", and never assert on absent output where an exit status is
available: an oracle that matches nothing passes for the wrong reason.

### 6.2 The mutation-proof requirement

Every new gate leg ships with a MUTATION PROOF.  A leg with no proof is
not a gate, and the stage is not green.  The proof has three parts, all
required, all recorded in `dev/M5-BUILD-LOG.md`:

1. The exact mutation, as a file, a line and the replacement text.
2. The observed flip: the leg's marker before the mutation, and the
   FAIL marker with its exit code after it.
3. The restore: the source digest before and after, proving the tree
   returned to its pre-mutation bytes.

A mutation that does not flip the leg REFUTES the leg.  When that
happens, replace the mutation or replace the leg, and record which.  Do
not report a leg as proved because a DIFFERENT mutation flipped it.
Two traps this milestone will meet, both already met in M4:

- A leg whose oracle matches ABSENT output is green before any work.
  P17's oracle is the live example, and C2 records it.
- A leg that never reaches the code under test is green for any bound.
  `PASS-M5B-FUEL-REACHABLE` is the live example: it must drive the
  production call site at lib/check.ml:1000, not `inst_start 1`.

### 6.3 Timing legs

A timing leg is a HANG detector, not a performance gate, unless the
pin says otherwise.  Give a timing leg a tier at least 10 times the
measured cost.  `PASS-M5B-BRANCHING-20` and `PASS-M5C-LEAF-MARGIN` are
the two legs whose NUMBER is the assertion, and each one carries its
measurement recipe in the gate comment so a later reader can re-measure
it.

## 7. SPEC checklist

### 7.1 Section 2 dated entries

Stage D appends a dated `2026-09-02 (M5)` block to SPEC section 2.  One
entry per line below, each written out in full, each naming the gate
that pins it.  Tick every line before the milestone closes.

- [ ] Instance term sharing: the `let`-nest at the `Term.Auto` site,
      `Term.shift`, the `islot` representation, the memo-hit rule, and
      the UNCHANGED `Cache.format_version = 10` (P1 to P5, P7).
- [ ] The re-check invariant: sharing is a performance change under an
      unchanged kernel rule, and lib/check.ml:1002 is what makes a
      mis-shifted nest loud (P6).
- [ ] The check budget: opaque `Budget.t`, driver-supplied poll, node
      granularity, `ctx.budget = Budget.unlimited` by default, and the
      RETRACTED claim that installs may drop `timeout` (P8, P9, P11).
- [ ] The budget contract: exit 3, outside the `--serror-exit` mapping,
      one exact stderr line, and the reason the LINE is the
      discriminator (P10, P19).
- [ ] The fuel bound: the class-count factor, the re-bisected leaf, the
      stopping rule, and the dropped "by construction" claim (P12).
- [ ] JSON conformance: two escapers, `\uXXXX` with surrogate pairs,
      `none` on a lone surrogate and a short escape, and the corrected
      reuse claim at lib/interp.ml:375-380 (P13).
- [ ] The strict-JSON posture: what `--strict-json` denies, where the
      flag lives, and why a guard has no argv channel (P20).
- [ ] The positivity door: the MUTUAL gap in `Totality.mentions`, and
      the explicit correction of the nesting claim (P14).
- [ ] The fence pin: self-recursive under a Pi keeps `self_rec = true`,
      with C1's corrected mutation recorded (P15).
- [ ] The predicativity exemption at lib/check.ml:1578, with the
      positive `Acc` shape and the negative constructor argument (P16).
- [ ] The `--require-main` driver contract, replacing the advisory
      entry at SPEC.md:1230-1243 (P21).
- [ ] Gate tiers and `gate_timed`, with the oracle spelled exactly and
      C2's corpus count (P17).
- [ ] The hole-anchor measurement, with the counted number and the
      corpus it was counted over (item 11).
- [ ] The well-founded recursion spike: what was measured, what the
      divergence witness shows, and what M6 would still owe (P22).

### 7.2 Section 6 rewrite

- [ ] SPEC.md:1220-1221, the JSON conformance debt: RETIRE.
- [ ] SPEC.md:1222-1223, the check-budget debt: RETIRE.
- [ ] SPEC.md:1230-1243, the `--require-main` advisory debt: RETIRE and
      replace with the driver contract.
- [ ] SPEC.md:1267-1286, the TERM SIZE entry: rewrite with post-M5
      numbers at the SAME shapes, so the before and after compare.
- [ ] SPEC.md:1287-1312, the `inst_fuel` entry: rewrite BOTH halves,
      the reach half with the re-bisected leaf and the new margin, the
      time half with the budget verdict that replaces exit 124.
- [ ] ADD: the sharing debt that remains, if Stage B's exit measurement
      leaves key-type sharing unspent (P7).
- [ ] ADD: what the well-founded spike measured and what it did not
      close (P22).
- [ ] Carry forward unchanged: nested and mutual inductives, the
      bounded regex engine, the prim trust boundary, `Div` provenance.

## 8. Ground rules (house style, enforced by hooks)

- NO exceptions anywhere: no `raise`, no `failwith`, no `assert`.
  Every failure is a `Result` value.  M5 adds no new host-boundary
  exception site.
- NO `match` on `Option` or `Result` where a combinator does the job
  (`Option.fold`, `Option.map`, `Option.bind`, `Option.to_result`,
  `Result.bind`, `Result.fold`, `let*`).  A PreToolUse hook DENIES
  edits that add such matches.
- NO loop keywords (`for`, `while`).  Use recursion, `List.fold_left`,
  `List.map`, `List.filteri` and `List.init`.
- NO mutation of a list or an array.  The one existing mutable cell,
  `Interp.gentry.gval`, stays exactly as it is.
- Exhaustive matches, NO catch-all `_ ->` arms on variant types you can
  enumerate.  Use `match () with | () when ...` ladders, not `if`/`else
  if` chains, and not a nested `if a then (if b then ..) else c`.
- No `arr.(i)` and no `List.nth`.  Use `List.nth_opt` with
  `Option.fold` or `Option.to_result`.
- LANGUAGE SCOPE, stated once so no stage has to carve its own.  The
  four rules above (no loop keywords, no mutation, no catch-all arm, no
  unchecked indexing) and the combinator rule bind the OCaml sources
  under `lib/`, `surface/`, `bin/` and `test/`.  They do NOT bind
  `dev/*.sh`, `dev/*.py` or a gate leg.  Shell has no combinator
  library, and `dev/gates.sh` already carries a `while` loop at
  `dev/gates.sh:1318` (`mm_nest`, M4 fixes round 5), so a shell loop is
  neither new nor an exception.  Keep shell loops small, bounded and
  quoted, and never write one to work around a missing OCaml
  combinator.
- Doc comments on every new top-level item.  Match the existing comment
  density.
- No em-dashes in any text you write.  ASCII punctuation only.  Two
  spaces after a sentence-ending "." or ";" in prose.
- Shell: `rg` not grep, `sd` not sed.
- Never `cd` in a Bash tool CALL.  Use absolute paths.  Your cwd RESETS
  between Bash calls, so put a multi-step probe in ONE runner script.
  A committed script that computes its own `ROOT` and then does
  `cd "$ROOT" || exit 9` on its FIRST line is different and is allowed,
  because it fixes its own cwd instead of depending on the caller's.
- Do NOT run `git add` and do NOT run `git commit`.  Leave working-tree
  edits only.  This binds EVERY stage, and a stage exit criterion that
  asks for a staged tree is a drafting error, not an exception.  Report
  `git status --porcelain` showing your edits UNSTAGED, and let the
  user stage and commit.
- `dev/gates.sh` must not use `set -u` (a chpwd hook breaks under it).
- Every feature ships WITH its regression test.  ORACLE RULE: every
  negative test must be shown to REJECT for the intended reason (print
  the error tag and the message), and every positive test must pin an
  exact value, an exact line, or an exact exit code.
- Marshal-format checklist: any change to `Term.t`, `Value.t`,
  `Eterm.t`, `Global.entry`, `Interp.v`, `Interp.gentry` or `Prim.t`
  bumps `Cache.format_version` (surface/cache.ml:118, currently 10).
  P1 says M5 owns NO bump.  A stage that believes it needs one has
  found a conflict, and section 5 applies.
- Append a stage report to `/Users/oobi/Documents/tot/dev/M5-BUILD-LOG.md`
  when your stage is green: what changed, files touched, new `Error.t`
  and `Serror.t` variants, test names added, gate markers added, every
  mutation proof, the new PASS count with its decomposition, and the
  gate output tails.
## STAGE A: JSON conformance, the strict-json posture, and the fence pins

Goal: close the one LIVE exploit the design panel found, and make the
two unstated kernel invariants executable.  The JSON parser accepts
`\uXXXX` and surrogate PAIRS.  It returns `none` on a lone surrogate and
on a short escape.  A new JSON escaper covers all of C0 on the
serializer and on the verdict envelope.  `Pp.escape_string` stays the
SOURCE escaper, and the false reuse claim beside it is corrected in the
same commit.  A new `--strict-json` driver flag turns an unparseable
payload into a DENY instead of an allow.  Two fence pins become gates:
`self_rec` under a Pi, and the parameter-level predicativity exemption.

Entry: M4 HEAD 34ea009, 278 PASS / 0 FAIL, cache `format_version` 10.
Stage A goes first for three reasons.  It is the only live exploit in
the panel.  It is independent of Stages B, C and D.  The two riskiest
items (sharing and the budget) must not be able to strand it.

Rationale for the stage boundary: every change below is a RUNTIME
behaviour change or a new gate.  No change touches `Term.t`, no change
touches a `Global` entry shape, and no change touches elaboration
output.  `Cache.format_version` therefore stays 10.  See A9.

Files: `lib/json_escape.ml` (NEW), `lib/interp.ml`, `lib/pp.ml`
(comment only), `surface/effect.ml`, `surface/run.ml`,
`surface/serror.ml`, `bin/tot.ml`, `examples/guard.tot` (comment only),
`test/main.ml`, `test/surface.ml`, `test/fixtures/` (new files),
`dev/gates.sh`, `SPEC.md`.

---

### A0. Entry state, measured against the built binary

Every line below is a PROBE result, not a reading.  The runner is
`/Users/oobi/Documents/tot-m5-plan-sections/probes/run.sh` and its
siblings `run2.sh` through `run7.sh`.  The binary is
`_build/default/bin/tot.exe` at M4 HEAD with
`TOT_PRELUDE=stdlib/prelude.tot`.  67 binary invocations produced these
results.

Naming, because `P<n>` is overloaded across the document set.  The rows
below are numbered `1`, `2` and so on, and the other runners label
their rows `P<n>`, `Q<n>`, `R<n>` and `S<n>`.  All of those are PROBE
IDs, local to this section.  None of them is a pin.  Cite a probe as
`probe P8` or `probe A0 row 23`, and cite a normative pin as `pin P20`
or `pin 20`, never as a bare `P20`.  Stage A implements pins P13, P14,
P15, P16, P20 and P23.

| # | Probe | Command | Measured today |
|---|---|---|---|
| 1 | escaped-payload bypass | `tot run examples/guard.tot < v-bypass.json` | **exit 0**, stdout EMPTY |
| 2 | literal spelling | `tot run examples/guard.tot < literal.json` | **exit 2**, deny envelope |
| 3 | lone high surrogate | `command` is `\ud800` | exit 0, stdout empty |
| 4 | lone low surrogate | `command` is `\udc00` | exit 0, stdout empty |
| 5 | short escape | `command` is `\u12` | exit 0, stdout empty |
| 6 | non-hex escape | `command` is `\uZZZZ` | exit 0, stdout empty |
| 7 | high surrogate, no low | `command` is `\ud83dx` | exit 0, stdout empty |
| 8 | high then non-low | `command` is `\ud83d\u0041` | exit 0, stdout empty |
| 9 | surrogate PAIR | `command` is `grep \ud83d\ude00` | exit 0, stdout empty |
| 10 | BMP escape | `command` is `grep \u00e9` | exit 0, stdout empty |
| 11 | NUL escape | `command` is `\u0000grep foo` | exit 0, stdout empty |
| 12 | escaped tool_name | `tool_name` is `\u0042ash` | exit 0, stdout empty |
| 13 | `jsonParse` on `\u0041` | `eval` prints the branch tag | prints `"NONE"`, exit 0 |
| 14 | serializer on a CR string | `jsonSerialize` of `{"a":"x\rb"}` | emits a RAW `\r` byte |
| 15 | deny envelope with CR + 0x01 | `python3 json.loads` on stdout | `json.decoder.JSONDecodeError: Invalid control character at: line 1 column 110 (char 109)` |
| 16 | `Acc` (verdict spelling) | `tot check` | exit 1, `parse error: data parameters must be marked 0` |
| 17 | `Acc` (params 0-marked) | `tot check` | exit 1, `invalid constructor acc: constructor must end in Acc applied to its parameters and 0 index expressions` |
| 18 | `Acc` (accessibility as INDEX) | `tot check` | **exit 0** |
| 19 | parameter-level minimum | `data PBox (0 A : Type 0) : Type 0` | **exit 0** |
| 20 | ctor arg above the universe | `kmk : (0 a : Type 0) -> KBad` | exit 1, `invalid constructor kmk: constructor argument lives above the declared universe` |
| 21 | index above the universe | `data IBad : (0 t : Type 0) -> Type 0` | exit 1, `inductive IBad: index t lives above the declared universe` |
| 22 | self-rec under a Pi CODOMAIN | `pxwrap : (0 f : (0 n : Nat) -> PXf) -> PXf` | exit 1, `erased variable px used at runtime` |
| 23 | self-rec under a Pi DOMAIN | `pywrap : (0 f : (0 s : PY) -> Nat) -> PY` | exit 1, `invalid constructor pywrap: negative or non-uniform occurrence of PY` |
| 24 | non-self-rec control | `pzwrap : (0 f : (0 n : Nat) -> Nat) -> PZ` | **exit 0** |
| 25 | `--strict-json` today | `tot run --strict-json ...` | exit 2, `unknown flag: --strict-json` |
| 26 | garbage payload | `tot run examples/guard.tot < garbage.json` | exit 0, stdout empty |
| 27 | C0 bytes in tracked fixtures | `rg -l` over `test/fixtures`, `stdlib`, `examples` | NO match, exit 1 |

Probe 27 discharges the verdict's own Risks entry ("an `rg` sweep for
bytes below 0x20 in fixtures before the change").  The sweep is CLEAN,
so no pinned error text can shift through `Pp.literal`.  Repeat the
sweep at Stage A exit and record it in the build log.

Probe 1 is the milestone's headline regression test.  The exact payload
bytes are:

    {"tool_name":"Bash","tool_input":{"command":"\u0067rep foo"}}

`0x67` is `g`.  `lib/interp.ml:287` rejects every unknown escape, so
`json_parse_top` returns `None`, `jsonParse` returns `none`, and
`examples/guard.tot:98` turns that into `allow`.  A banned binary
therefore runs.

---

### A1. lib/json_escape.ml (NEW)

A new kernel module.  `lib/dune` declares no `(modules ...)` field, so
dune picks the file up with no build edit.

```ocaml
(** M5 Stage A: the JSON escaper.  DISTINCT from [Pp.escape_string],
    which stays the SOURCE escaper for tot string literals.  The two
    escape sets are not the same and never were: JSON forbids every
    unescaped byte below 0x20, while tot source only needs backslash,
    quote, newline and tab.  [Pp.escape_string]'s own docstring and
    [Interp.json_serialize]'s claimed that the source set was a
    sufficient SUBSET.  It is not, and A3 corrects both texts.

    Covers the RFC 8259 short forms in the order the RFC lists them
    (quote, reverse solidus, backspace, formfeed, newline, carriage
    return, tab), then \u00XX for every remaining byte below 0x20.
    DEL (0x7f) is legal unescaped and is NOT escaped.  Bytes at or
    above 0x80 pass through unchanged, so a UTF-8 payload round trips
    byte for byte. *)
let string (s : string) : string =
  let buf = Buffer.create (String.length s + 2) in
  Buffer.add_char buf '"';
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | '\b' -> Buffer.add_string buf "\\b"
      | '\012' -> Buffer.add_string buf "\\f"
      | '\n' -> Buffer.add_string buf "\\n"
      | '\r' -> Buffer.add_string buf "\\r"
      | '\t' -> Buffer.add_string buf "\\t"
      | _ -> (
          match () with
          | () when Char.code c < 0x20 ->
              Buffer.add_string buf (Printf.sprintf "\\u%04x" (Char.code c))
          | () -> Buffer.add_char buf c))
    s;
  Buffer.add_char buf '"';
  Buffer.contents buf
```

House-rule notes.  `char` is a HOST type, not a domain sum type, so the
`_` arm is permitted; the domain-type ban does not reach it.  The `match
() with` guard ladder is the repo's own idiom for a numeric range test
(see `lib/interp.ml:215` and `bin/tot.ml:167`).  No loop keyword, no
exception, no mutation of a caller's value.

Do NOT put this function in `lib/pp.ml`.  `Pp` is the display printer
and its `literal` entry point feeds pinned kernel error text.  A shared
module would re-couple exactly what pin 13 separates.

---

### A2. lib/interp.ml: the parser gains `\uXXXX`

Three new helpers land immediately above `json_string_body`
(`lib/interp.ml:275`).

```ocaml
(** M5 Stage A.  One hex digit's value, or [None].  Same guard-ladder
    shape as [json_is_digit] above. *)
let json_hex_val (c : char) : int option =
  match () with
  | () when c >= '0' && c <= '9' -> Some (Char.code c - Char.code '0')
  | () when c >= 'a' && c <= 'f' -> Some (Char.code c - Char.code 'a' + 10)
  | () when c >= 'A' && c <= 'F' -> Some (Char.code c - Char.code 'A' + 10)
  | () -> None

(** EXACTLY four hex digits.  Fewer than four characters left, or any
    non-hex character, returns [None], and the caller fails the WHOLE
    parse.  A SHORT escape is therefore a parse failure, never a
    partial decode. *)
let json_hex4 (cs : char list) : (int * char list) option =
  let ( let* ) = Option.bind in
  match cs with
  | a :: b :: c :: d :: rest ->
      let* va = json_hex_val a in
      let* vb = json_hex_val b in
      let* vc = json_hex_val c in
      let* vd = json_hex_val d in
      Some ((((((va * 16) + vb) * 16) + vc) * 16) + vd, rest)
  | [] | [ _ ] | [ _; _ ] | [ _; _; _ ] -> None

(** UTF-8 encode one scalar value, OLDEST BYTE FIRST.  [cp] is always
    in 0 .. 0x10FFFF at every call site (the four-hex-digit bound gives
    0 .. 0xFFFF, and the surrogate-pair arm gives 0x10000 .. 0x10FFFF),
    so the [land 0xff] mask makes [Char.chr] total. *)
let json_utf8_bytes (cp : int) : char list =
  let byte (n : int) : char = Char.chr (n land 0xff) (* @total-accessor: masked to 0..255 *) in
  match () with
  | () when cp < 0x80 -> [ byte cp ]
  | () when cp < 0x800 -> [ byte (0xc0 lor (cp lsr 6)); byte (0x80 lor (cp land 0x3f)) ]
  | () when cp < 0x10000 ->
      [
        byte (0xe0 lor (cp lsr 12));
        byte (0x80 lor ((cp lsr 6) land 0x3f));
        byte (0x80 lor (cp land 0x3f));
      ]
  | () ->
      [
        byte (0xf0 lor (cp lsr 18));
        byte (0x80 lor ((cp lsr 12) land 0x3f));
        byte (0x80 lor ((cp lsr 6) land 0x3f));
        byte (0x80 lor (cp land 0x3f));
      ]
```

`json_string_body` gains ONE arm.  Put it with the other escape arms,
BEFORE the `'\\' :: _ :: _ -> None` catch at `lib/interp.ml:287`.  OCaml
matches top to bottom, so arm order decides whether `\u` reaches the
decoder or the rejection.

```ocaml
  | '\\' :: 'u' :: rest -> (
      match json_hex4 rest with
      | None -> None
      | Some (hi, rest2) -> (
          match () with
          | () when hi >= 0xd800 && hi <= 0xdbff -> (
              (* a HIGH surrogate is only valid as the first half of a
                 PAIR; the second half must be \uDC00 .. \uDFFF *)
              match rest2 with
              | '\\' :: 'u' :: rest3 -> (
                  match json_hex4 rest3 with
                  | None -> None
                  | Some (lo, rest4) -> (
                      match () with
                      | () when lo >= 0xdc00 && lo <= 0xdfff ->
                          let cp = 0x10000 + ((hi - 0xd800) * 0x400) + (lo - 0xdc00) in
                          json_string_body rest4 (List.rev_append (json_utf8_bytes cp) acc)
                      | () -> None))
              | [] | _ :: _ -> None)
          | () when hi >= 0xdc00 && hi <= 0xdfff -> None
          | () -> json_string_body rest2 (List.rev_append (json_utf8_bytes hi) acc)))
```

`acc` is built NEWEST FIRST and the `'"'` arm reverses it once
(`lib/interp.ml:277`).  `List.rev_append` pushes the encoded bytes onto
`acc` in reverse, so the final `List.rev` restores source order.  Write
that sentence into the arm's comment; a plain `acc @ bytes` would be
both quadratic and wrong.

Deliberate NON-changes, each recorded in the SPEC entry of A10:

1. A RAW byte below 0x20 inside a string body still parses.  RFC 8259
   forbids it, but tightening the parser here would move payloads
   between paths for no exploit the panel found, and the guard's own
   deny set does not read control bytes.  Probe 11 pins that a decoded
   NUL still yields `allow`, because `firstToken` then sees
   `"\x00grep"` whose basename is not `grep`.  This is the honest
   result, not a regression.
2. `\u0000` decodes to a NUL byte.  OCaml strings are byte arrays, so
   the value is carried, not truncated.
3. The parser stays `Div` (`lib/prim.ml:140`).  The new arms add no
   unbounded recursion: each consumes at least two input characters.

---

### A3. lib/interp.ml: the serializer, and the FALSE reuse claim

`lib/interp.ml:375-380` currently reads, in part (conflict note C4 of
the preamble corrects the verdict's `:375-381`;  line 381 is
`let rec json_serialize`):

    [Pp.escape_string] is reused for JSON string quoting (M3 Stage A's
    own escape set (backslash, quote, newline, tab) is a subset of
    JSON's, so it produces valid JSON text for every string this
    parser can itself have produced ...)

That claim is FALSE at M4 HEAD, and probe 14 measures it: the parser
itself accepts `\r` (`lib/interp.ml:280`), so it CAN produce a string
carrying a carriage return, and `Pp.escape_string` then emits that byte
raw.  Correct the docstring in the SAME commit as the rewire.  The
replacement text names the escaper, the split, and the reason:

    [Json_escape.string] quotes every JSON string this serializer
    emits.  [Pp.escape_string] is the SOURCE escaper and is NOT reused
    here.  M4's claim that the source escape set is a SUBSET of JSON's
    was false: the parser accepts \r, \b and \f (lib/interp.ml:280-282)
    and the source escaper leaves all three raw, so a parsed-then-
    serialized payload could carry an unescaped control byte.  M5
    Stage A, pin 13.

Rewire exactly three call sites.  Probe R9 enumerated every consumer, so
the list is complete:

| Site | Before | After |
|---|---|---|
| `lib/interp.ml:388` (`jstr` value) | `Pp.escape_string s` | `Json_escape.string s` |
| `lib/interp.ml:401` (object KEY) | `Pp.escape_string k` | `Json_escape.string k` |
| `surface/effect.ml:375` (verdict envelope) | `Pp.escape_string msg` | `Json_escape.string msg` |
| `lib/pp.ml:24` (`Pp.literal`) | `escape_string s` | UNCHANGED |

`lib/pp.ml:3-6`'s own docstring claims reuse by Stage C's serializer and
Stage D's verdict renderer.  After the rewire that sentence is stale.
Replace it with one that states the split:

    Render a string literal's SOURCE form ... This is the SOURCE
    escaper only.  JSON output uses [Json_escape.string]; see M5
    Stage A pin 13.

The envelope site matters as much as the serializer site.  Probe 15
shows a deny message carrying `\r` and `0x01` produces stdout that
`python3 -c json.loads` REJECTS, with the exact text
`json.decoder.JSONDecodeError: Invalid control character at: line 1
column 110 (char 109)`.  A hook that cannot decode a guard's own deny
envelope falls back to its decode-error posture, which is fail-open.
The deny becomes an allow.  Gate `PASS-M5A-ENVELOPE-VALID` pins the fix.

---

### A4. The `--strict-json` posture: WHERE the flag lives

Amendment A2 fixes the POLICY and delegates the PLACEMENT: "an
unparseable or non-conforming payload DENIES (exit 2) instead of falling
open to allow.  Where the flag lives (driver vs guard argv) is resolved
in the plan against the repo."  Here is the resolution, with the repo
evidence that decides it.

Evidence 1.  The parse happens in `Interp.json_parse_top`, called from
`fire_prim` (`lib/interp.ml:806`).  `fire_prim`'s only context argument
is `eglobals : globals`, and `globals` is a BARE map
(`lib/interp.ml:118`: `type globals = gentry Global.StringMap.t`).  It
carries no policy field and cannot gain one without reshaping every
`globals` producer.  A labelled `~strict_json` argument instead threads
through the `exec` / `apply` / `force` / `fire_prim` mutual group: 17
in-file recursive call sites (probe R6) plus 6 external call sites in
`surface/` and `test/` (probe R5).

Evidence 2.  The repo has a settled precedent for installation POLICY.
`--no-axioms` and `--require-main` both live in `bin/tot.ml`'s `opts`,
travel as `Run.policy` fields (`surface/run.ml:28-33`), and are enforced
in `surface/`.  `surface/serror.ml:36` states the rule in the repo's own
words: "Installation POLICY, not a kernel notion".  Neither flag reaches
`lib/`.

Evidence 3.  `Effect.dispatch` already owns the one raw stdin read in
the tree (`surface/effect.ml:195-201`), and it is in `surface/`.  It is
the exact point where attacker-shaped bytes enter the process.

**Resolution: `--strict-json` is a DRIVER flag, enforced at
`Effect.dispatch`'s `Prim.Read_stdin` arm.  `lib/` is untouched.**  The
guard script needs no edit and no argv read.  The flag validates the
payload at the boundary, not at the parse.

Concretely:

1. `bin/tot.ml`.  `opts` gains `strict_json : bool`, default `false`.
   `parse_flags` gains one arm, `| "--strict-json" :: rest ->
   parse_flags { opts with strict_json = true } rest`, placed with the
   other boolean flags.  `usage` becomes
   `"usage: tot (check|run) [--no-prelude] [--no-axioms] [--serror-exit N] [--require-main] [--strict-json] FILE | tot prims"`.
   `dispatch` copies the field into the policy record.
2. `surface/run.ml`.  `policy` gains `strict_json : bool`.
   `default_policy` sets it `false`, so no existing call site changes.
3. `surface/effect.ml`.  `type outcome` gains ONE constructor:

   ```ocaml
   type outcome =
     | Done of Interp.v
     | Exited of int
     | Rejected of string
         (** M5 Stage A: [--strict-json] refused the payload at the
             [readStdin] boundary.  The payload is the DENY reason the
             driver renders.  Reached only under the flag. *)
   ```

   `run_io` and `dispatch` gain `~(strict_json : bool)`.  The
   `Prim.Read_stdin` arm becomes:

   ```ocaml
   | Prim.Read_stdin, [] ->
       let s = match In_channel.input_all stdin with exception Sys_error _ -> "" | s -> s in
       (* M5 Stage A: under --strict-json the payload must parse as one
          JSON value BEFORE the script sees it.  Interp.json_parse_top
          is the same parser jsonParse fires, so the flag can never
          admit bytes the script would then reject, or the reverse. *)
       (match () with
       | () when strict_json && Option.is_none (Interp.json_parse_top s) ->
           Ok (Rejected strict_json_reason)
       | () -> Ok (Done (Interp.VLit (Literal.LString s))))
   ```

   with `let strict_json_reason : string = "strict-json: stdin is not a
   single well-formed JSON value"` as a module-level constant, so the
   gate and the code share one spelling.
4. `surface/run.ml`, `run_verdict_main` (`surface/run.ml:502`) gains the
   third arm and renders the DENY envelope:

   ```ocaml
   | Effect.Rejected reason -> Ok ([ Effect.deny_envelope reason ], 2)
   ```

   `Effect.deny_envelope` is `render_verdict`'s existing `envelope`
   local, lifted to a module-level function so both callers share it.
   Exit 2 is the literal deny code, OUTSIDE the `--serror-exit`
   mapping, exactly like the driver contract at `bin/tot.ml:34`.
5. `surface/run.ml`, `run_unit_main` (`surface/run.ml:518`) gains the
   matching arm.  An `IO Unit` script has no verdict channel, so the
   refusal takes the DRIVER contract instead: one stderr line, exit 1,
   outside the `--serror-exit` mapping.  This is the same posture A3
   gives `--require-main`.  The arm returns
   `Error Serror.Json_strict_reject`, and `bin/tot.ml` maps that ONE
   `Serror` to the literal 1.
6. `surface/serror.ml` gains `| Json_strict_reject`, its `to_string`
   line `"stdin is not a single well-formed JSON value, and this \
   installation runs with --strict-json"`, and its `tag`
   `"Json_strict_reject"`.  Both matches in that file are exhaustive
   over the domain type and both gain the arm.

Contract, stated once and written into SPEC:

- The flag applies to `run` only.  `check` never runs the epilogue
  (`surface/run.ml:582`, `| () when not exec -> Ok (None, None)`), so
  `readStdin` never fires.  Probe S8 confirms `tot check` on the guard
  reaches `def main : (IO Verdict)` and stops.
- The flag fires only at a `readStdin` dispatch.  A script that never
  reads stdin is unaffected.
- Default OFF.  With the flag absent, stdout, stderr and the exit code
  are byte-identical to M4 HEAD.  `PASS-M5A-STRICT-ALLOW` pins the
  default half.
- Under the flag the WHOLE stdin payload must be one JSON value.  A
  script that reads non-JSON stdin under the flag is refused.  That is
  the flag's meaning, not a bug.

Rejected alternatives, with the reason each fails:

- Threading `~strict_json` into `fire_prim`.  Puts installation policy
  in `lib/`, which contradicts the repo's own stated rule
  (`surface/serror.ml:36`), and costs 23 call sites for no extra
  coverage.
- Changing `jsonParse`'s posture directly.  Its type is
  `String -> Div (Option Json)` (`surface/bootstrap.ml:146`).  A strict
  mode that cannot return `none` needs a different type, so the prelude
  and every caller move.
- Editing only `examples/guard.tot` to deny on `none`.  The posture
  then belongs to one file, and the amendment's "under the flag" has no
  referent.  Stage D still extends the guard, and that work is
  compatible; this stage owns the FLAG.
- Passing the flag through to script argv.  `Prim.Argv` exists and is
  fully wired (`lib/prim.ml:44`, `lib/prim.ml:125` arity 0,
  `surface/bootstrap.ml:144` `("argv", "IO (List String)",
  Prim.Argv)`, `surface/effect.ml:276`), so this route is POSSIBLE.  It
  is rejected because a script that ignores the flag still falls open,
  so the flag would guarantee nothing.

**Conflict note (2026-09-02, Stage A, conflict 1).**  Pin P20 as first
drafted said the flag "lives in the DRIVER flag list
(bin/tot.ml:157-173) and the guard reads it through the existing `argv`
prim".  This section keeps the first half and drops the second.  The
repo does NOT prove the argv half impossible: `Prim.Argv` is wired at
the four sites listed just above, and probe P10 runs it.  Section 5
rule 4 therefore does not license a mechanism change on impossibility
grounds, and this section does not claim one.  The resolution rests on
amendment A2's own delegation instead: A2 says "Where the flag lives
(driver vs guard argv) is resolved in the plan against the repo", so
placement is the plan's to decide and P20's argv clause was an early
answer to a question A2 left open.  RESOLUTION: the flag travels as a
`Run.policy` field and is enforced at `Effect.dispatch`'s
`Prim.Read_stdin` arm.  P20's INTENT is unchanged and fully kept: under
the flag an unparseable or non-conforming payload denies with exit 2,
and without it the fail-open posture is byte-identical.  The preamble's
P20 and its Stage A contents line were amended to match on 2026-09-02.
Record this note in `dev/M5-BUILD-LOG.md`.  Do not re-litigate the
placement.

---

### A5. Fence pin 1: `self_rec` under a Pi

`Global.ctor_entry.self_rec` is computed at `lib/check.ml:1828`:

```ocaml
let self_rec = List.exists (fun (_q, _x, ty) -> Totality.mentions name ty) args in
```

`Check.zero_eliminable` (`lib/check.ml:212-222`) reads it: a family is
subsingleton-eliminable only when it has at most one constructor, every
constructor argument binder is quantity 0, AND the constructor is not
self-recursive.  `Totality.mentions` (`lib/totality.ml:50`) walks BOTH
halves of a `Pi`:

```ocaml
  | Term.Pi (_q, _x, dom, cod) -> mentions name dom || mentions name cod
```

Nothing at M4 HEAD gates that walk.  Add the fixture and the gate.

**Fixture `test/fixtures/m5a-fence-pi.tot`** (probed; see A0 row 22):

```
-- M5 Stage A, gate PASS-M5A-FENCE-PI (design pin 15).  PXf's single
-- constructor takes ONE argument, at quantity 0, whose type is a Pi
-- whose CODOMAIN is PXf itself.  The subsingleton criterion's first
-- two clauses (one constructor, every argument erased) both hold, so
-- self_rec is the ONLY thing that keeps zero_eliminable false, and
-- Totality.mentions finds PXf only because it walks under a Pi.  A
-- mentions that stopped at the Pi node would flip self_rec to false,
-- zero_eliminable to true, and this file to exit 0.
data PXf : Type 0 := | pxwrap : (0 f : (0 n : Nat) -> PXf) -> PXf
def rec pxfLoop : (0 px : PXf) -> Nat := fun px => match px with | pxwrap g => pxfLoop (g zero) end
```

Expected: exit 1, and the message ends
`erased variable px used at runtime`.  Probed at M4 HEAD, so the
fixture is green on arrival and the gate protects it from Stage B, C
and D.

**Control fixture `test/fixtures/m5a-fence-pi-ctl.tot`** (probed; A0 row
24):

```
-- The SAME shape with the self-recursive occurrence removed.  PZf is
-- one constructor, one erased argument, no self recursion, so
-- zero_eliminable IS true and the match erases.  This file pins the
-- FLIP TARGET: it is exactly what m5a-fence-pi.tot becomes if
-- Totality.mentions stops walking under a Pi.
data PZf : Type 0 := | pzwrap : (0 f : (0 n : Nat) -> Nat) -> PZf
def pzfLoop : (0 s : PZf) -> Nat := fun s => match s with | pzwrap g => zero end
```

Expected: exit 0.

Do NOT name the scrutinee binder `s` in `m5a-fence-pi.tot`.
`test/fixtures/m4a-sx.tot` already produces
`erased variable s used at runtime` (probe P8), so a shared binder name
would let `PASS-M5A-FENCE-PI` pass on the WRONG file's output.  The
binder is `px`, which is unique in the fixture tree.

**Conflict note (2026-09-02, Stage A, conflict 2).**  The verdict states
the mutation as "make `mentions` skip Pi DOMAINS" (verdict item 7, pin
15, and the Stage A gate line).  Against this repo that mutation is
VACUOUS.  `Check.strict_pos` (`lib/check.ml:1731`) reads
`| Term.Pi (_q, _x, dom, cod) -> no_occur dom && strict_pos (depth + 1) cod`,
so a constructor argument may never mention the family in a Pi DOMAIN.
Probe A0 row 23 confirms it: `pywrap : (0 f : (0 s : PY) -> Nat) -> PY`
is rejected with
`invalid constructor pywrap: negative or non-uniform occurrence of PY`.
No source-constructible fixture can witness a domain occurrence, so the
domain mutation can never flip any leg.  RESOLUTION: the live mutation
for `PASS-M5A-FENCE-PI` is the CODOMAIN half, stated in A10.  The
domain half is recorded in SPEC as refuted-by-positivity, with this
probe as its evidence, so no later milestone re-proposes it.  The pin's
INTENT is unchanged and fully met: `mentions` must keep walking under a
Pi, and the gate now proves the half that positivity leaves reachable.

---

### A6. Fence pin 2: the parameter-level predicativity exemption

`declare_ind_status` treats three telescopes differently:

| Site | Code | Level bound |
|---|---|---|
| `lib/check.ml:1578` | `let* ty', _l = infer_univ globals ctx ty in` | NONE, the level is DISCARDED |
| `lib/check.ml:1591` | `if Level.le l level then Ok () else Error (Error.Index_above_universe ...)` | bounded |
| `lib/check.ml:1806` | `if Level.le l ind.Global.level then Ok () else Error (Error.Bad_ctor ...)` | bounded |

So a PARAMETER may live above the family's declared universe, while an
INDEX and a CONSTRUCTOR ARGUMENT may not.  This exemption is what makes
`Acc` check.  It is unstated in SPEC and ungated at M4 HEAD.  Pin 16
closes both halves.

**Positive fixture `test/fixtures/m5a-param-level.tot`** (probed; A0
rows 18 and 19):

```
-- M5 Stage A, gate PASS-M5A-PARAM-LEVEL (design pin 16).  Both
-- families put a PARAMETER whose type is "Type 0" (level 1) on a
-- family declared at level 0.  lib/check.ml:1578 discards the inferred
-- parameter level, so both check.  Bounding that fold rejects both,
-- and Acc (the M6 well-founded-recursion candidate) stops checking.
data PBox (0 A : Type 0) : Type 0 := | pbox : (0 a : A) -> PBox A
data Acc (0 A : Type 0) (0 R : A -> A -> Type 0) : (0 x : A) -> Type 0 :=
  | acc : (x : A) -> ((y : A) -> R y x -> Acc A R y) -> Acc A R x
```

Expected: exit 0.  Probed output includes
`ctor acc : (0 A : Type 0) -> (0 R : (w _ : A) -> (w _ : A) -> Type 0) -> (w x : A) -> (w _ : (w y : A) -> (w _ : ((R y) x)) -> (((Acc A) R) y)) -> (((Acc A) R) x)`.

**Negative fixture `test/fixtures/m5a-param-level-neg.tot`** (probed; A0
rows 20 and 21):

```
-- The OTHER two telescopes stay bounded.  A ctor argument at "Type 0"
-- on a level-0 family is Bad_ctor (lib/check.ml:1806); an INDEX at
-- "Type 0" is Index_above_universe (lib/check.ml:1591).  The exemption
-- is parameter-only, and this file is the fence that says so.
data KBad : Type 0 := | kmk : (0 a : Type 0) -> KBad
```

Expected: exit 1, message ends
`invalid constructor kmk: constructor argument lives above the declared universe`.

**Second negative `test/fixtures/m5a-index-level-neg.tot`:**

```
data IBad : (0 t : Type 0) -> Type 0 := | imk : IBad Nat
```

Expected: exit 1, message ends
`inductive IBad: index t lives above the declared universe`.

**Conflict note (2026-09-02, Stage A, conflict 3).**  The verdict's
`Acc` spelling
(`data Acc ... := | acc : (x : A) -> ((y : A) -> R y x -> Acc A R y) -> Acc A R x`)
does NOT check on this repo, and the judge's "checks at exit 0 today"
claim holds only for a different spelling.  Two independent repo rules
reject the literal text.  First, `data` parameters must carry an
explicit `0` marker; probe A0 row 16 gives
`parse error: data parameters must be marked 0`.  Second, the
accessibility argument must be an INDEX, not a parameter, because the
constructor codomain `Acc A R x` applies the family to more arguments
than its parameter telescope has; probe A0 row 17 gives
`invalid constructor acc: constructor must end in Acc applied to its
parameters and 0 index expressions`.  RESOLUTION: the fixture uses the
probed spelling above, with `(0 A : Type 0) (0 R : ...)` as parameters
and `(0 x : A)` as an index.  That spelling exits 0 (A0 row 18).  SPEC
records the working spelling verbatim, so the M6 well-founded-recursion
work inherits a form that compiles rather than one that does not.

---

### A7. Stage A fixtures (complete list)

New files under `test/fixtures/`.  Payload fixtures carry NO trailing
newline where the byte matters; probe U6 confirms the parser accepts a
payload both with and without one, so the choice is about byte-exactness
in the gate, not about tolerance.

| File | Purpose | Expected |
|---|---|---|
| `m5a-bypass.json` | `{"tool_name":"Bash","tool_input":{"command":"\u0067rep foo"}}` | deny envelope, exit 2 |
| `m5a-pair.json` | `command` is `grep \ud83d\ude00` | deny envelope, exit 2 |
| `m5a-bmp.json` | `command` is `grep \u00e9` | deny envelope, exit 2 |
| `m5a-name-esc.json` | `tool_name` is `\u0042ash`, `command` is `grep foo` | deny envelope, exit 2 |
| `m5a-lone-hi.json` | `command` is `\ud800` | allow, exit 0 |
| `m5a-lone-lo.json` | `command` is `\udc00` | allow, exit 0 |
| `m5a-short.json` | `command` is `\u12` | allow, exit 0 |
| `m5a-nonhex.json` | `command` is `\uZZZZ` | allow, exit 0 |
| `m5a-hi-plain.json` | `command` is `\ud83dx` | allow, exit 0 |
| `m5a-hi-nonlow.json` | `command` is `\ud83d\u0041` | allow, exit 0 |
| `m5a-nul.json` | `command` is `\u0000grep foo` | allow, exit 0, decoded |
| `m5a-envelope.tot` | `def main : IO Verdict := pureIO Verdict (deny "a\rb<0x01>c")` | envelope parses under `json.loads` |
| `m5a-fence-pi.tot` | A5 | exit 1, `erased variable px used at runtime` |
| `m5a-fence-pi-ctl.tot` | A5 | exit 0 |
| `m5a-param-level.tot` | A6 | exit 0 |
| `m5a-param-level-neg.tot` | A6 | exit 1, ctor text above |
| `m5a-index-level-neg.tot` | A6 | exit 1, index text above |

Build every `.json` fixture with a programmatically produced backslash,
not a typed one.  During planning a typed `\u0067` was silently
normalised twice by the authoring path, which produced a fixture reading
`grep foo` and a FALSE exit-2 result (probe batches U and T).  The
`run7.sh` idiom is the one that survives:

```sh
BS=$(printf '\\')
printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "${BS}u0067rep foo" > out.json
od -c out.json | tail -3    # verify the bytes BEFORE trusting the run
```

Every gate leg that consumes a `.json` fixture asserts the fixture's own
bytes first.  Add one leg, `PASS-M5A-FIXTURE-BYTES`, that runs
`rg -c '\\u0067rep' test/fixtures/m5a-bypass.json` and asserts exit
status 0.  Without it a re-normalised fixture turns
`PASS-M5A-BYPASS` into a vacuous pass on the ALREADY-denying literal
spelling.

`m5a-envelope.tot` needs a literal `0x01` byte in its source.  The
lexer accepts one (probe Q4).  Generate the file in the gate with
`printf 'def main : IO Verdict := pureIO Verdict (deny "a\\rb\001c")\n'`
into a scratch directory, exactly as gates.sh already generates its
cache scratch, so no tracked file carries a control byte.  Probe 27's
clean sweep then stays clean.

---

### A8. Stage A tests

`test/main.ml` (kernel suite), new cases:

1. `Json_escape.string` on `"a\rb"` returns `"a\\rb"` with the CR
   escaped.  Assert the exact 7-character result.
2. `Json_escape.string` on a string carrying `0x01` returns `\u0001`.
3. `Json_escape.string` on `"\xc3\xa9"` (UTF-8 e-acute) passes both
   bytes through unchanged.  This pins that the escaper is byte-clean
   above 0x7f.
4. `Json_escape.string` on `"\x7f"` leaves DEL unescaped.
5. `Interp.json_parse_top "\"\\u0041\""` yields `jstr "A"`.
6. `Interp.json_parse_top` on the surrogate pair `\ud83d\ude00` yields
   `jstr` carrying the four UTF-8 bytes `f0 9f 98 80`.
7. `Interp.json_parse_top` returns `None` on each of: `"\ud800"`,
   `"\udc00"`, `"\u12"`, `"\uZZZZ"`, `"\ud83dx"`, `"\ud83d\u0041"`.
   Six assertions, one per shape.
8. Round trip: parse `{"a":"x\ry"}`, serialize, re-parse, and compare
   the two `jstr` payloads.  At M4 HEAD the re-parse FAILS, because the
   serializer emitted a raw CR (probe 14).
9. `Json_escape.string` and `Pp.escape_string` DIFFER on `"a\rb"`.  A
   negative test.  It fails the moment someone re-aliases one to the
   other.

`test/surface.ml` (surface suite), new cases:

10. `gate-check` on `m5a-fence-pi.tot` exits non-zero with
    `erased variable px used at runtime`.
11. `gate-check` on `m5a-fence-pi-ctl.tot` exits 0.
12. `gate-check` on `m5a-param-level.tot` exits 0.
13. `gate-check` on `m5a-param-level-neg.tot` and
    `m5a-index-level-neg.tot` exit non-zero with their pinned texts.
14. `Run.script` with `policy.strict_json = true` and a garbage stdin
    payload yields the `Rejected` outcome and exit 2.
15. `Run.script` with `policy.strict_json = false` and the same payload
    yields exit 0, byte-identical to M4 HEAD.

Additivity requirement: no existing test term changes.  The 278 PASS
walk stays green at Stage A exit.  Any leg that moves is a Stage A
DEFECT, not an accepted update.  Two legs are expected to change their
INPUT-to-OUTPUT relation and must be checked by hand before the walk is
trusted:

- `PASS-D-GUARD-OTHER` runs `garbage.json` and expects exit 0.  The
  default posture is unchanged, so this leg stays green with no edit.
  Confirm it, do not edit it.
- `PASS-C-JSON` round-trips `c-json-roundtrip.tot`, whose payload is
  `{"name":"tot","count":3}`.  No control byte, no escape, so
  `Json_escape.string` and `Pp.escape_string` agree on it and the leg
  stays green with no edit.  Confirm it.

---

### A9. surface/cache.ml: NO format bump

`Cache.format_version` stays 10.  The reasons, each checkable:

1. `Term.t` is unchanged.  Stage A adds no constructor and no field.
2. `Global` entry shapes are unchanged.  `self_rec` already exists.
3. The cache stores ELABORATED terms.  A tot string literal is lexed by
   `surface/lexer.ml`, which Stage A does not touch, so the same source
   elaborates to the same term.
4. `Json_escape.string` and the parser's `\u` arm are RUNTIME
   behaviour.  Neither runs during elaboration.
5. `Run.policy` is a driver value, never serialized.

The cache key also carries the MD5 digest of the running binary
(`surface/cache.ml:7`), so a Stage A rebuild invalidates existing
entries anyway.  That is a belt, not the argument.  Record the
no-bump decision in the SPEC entry so a later reviewer does not read
the missing bump as an oversight.

---

### A10. Gate A

Eight new markers, the eight the preamble reserves for Stage A.  Probe
Q12 confirms `rg -c 'PASS-M5A' dev/gates.sh`
exits 1 at M4 HEAD, so no name collides.  Write each leg in the file's
existing capture-then-assert idiom, with the FAIL branch replaying the
captured output and exiting 1.

The watchdog value.  Stage D replaces every numeric watchdog literal in
the file with a named tier (pin P17).  Its corpus is 89 sites, not 91:
conflict note C2 of the preamble measures
`rg -c '"\$watchdog" [0-9]+' dev/gates.sh` at 89 and exits 0 at M4
HEAD, while 91 is the count of lines that merely MENTION `$watchdog`
and is never an oracle.  The tier names do not exist until Stage D
lands, so Stage A cannot use one.  Wrap each Stage A leg in
`"$watchdog" 30`, which is the MED value Stage D maps 30 to, so no leg
changes its ceiling at conversion.  Add the eight new sites to Stage
D's conversion list and to `dev/M5-BUILD-LOG.md`, and expect Stage D's
corpus to be 89 plus what Stages A, B and C recorded.  Adding a
RECORDED literal here is the plan;  adding an unrecorded one, or a
value outside the tier ladder 10, 30, 120, 300, is the debt.

    (i)    The kernel and surface suites stay green with NO edits to
           any existing test term.  Baseline 278, plus the additions
           of A8.
    (ii)   The escaped-payload bypass now DENIES.
    (iii)  Every emitted JSON envelope is decodable by a conforming
           parser.
    (iv)   A lone surrogate and a short escape still fail the parse.
    (v)    The subsingleton fence still sees a self-recursive
           occurrence under a Pi.
    (vi)   The parameter-level exemption holds, and the index and
           constructor-argument bounds still bite.
    (vii)  `--strict-json` turns a parse failure into a deny, and its
           absence changes nothing.

**PASS-M5A-BYPASS.**  Pipe `test/fixtures/m5a-bypass.json` into
`examples/guard.tot` through the guard's own shebang.  Assert exit 2 AND
stdout byte-equal to

    {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed"}}

Add the three sibling payloads to the same leg: `m5a-pair.json`,
`m5a-bmp.json`, `m5a-name-esc.json`.  All four assert exit 2 and the
same envelope.
MUTATION: delete the `'\\' :: 'u' :: rest` arm from `json_string_body`,
so `lib/interp.ml:287` catches `\u` again.
OBSERVED FLIP: exit 0 with EMPTY stdout, on all four payloads.  That is
the state measured at M4 HEAD (A0 rows 1, 9, 10, 12), so the flip target
is a measurement, not a prediction.

**PASS-M5A-FIXTURE-BYTES.**  `rg -c '\\u0067rep' test/fixtures/m5a-bypass.json`,
asserted on EXIT STATUS.
MUTATION: rewrite the fixture with a decoded `g` in place of the escape.
OBSERVED FLIP: `rg` exits 1 and the leg fails.  Without this leg a
re-normalised fixture makes `PASS-M5A-BYPASS` pass against the plain
literal spelling, which already denies at M4 HEAD (A0 row 2).  That is
the exact vacuous-pass shape this gate exists to refuse.

**PASS-M5A-ENVELOPE-VALID.**  Generate `m5a-envelope.tot` into the gate
scratch directory with a `\r` byte and a `0x01` byte in the deny
message.  Run it.  Assert exit 2, then pipe stdout through
`python3 -c 'import json,sys; json.loads(sys.stdin.read())'` and assert
that command's exit status 0.  Assert additionally that stdout contains
the literal text `\r` and `\u0001`, so the leg fails if the escaper
drops the bytes rather than escaping them.
MUTATION: revert `surface/effect.ml:375` to `Pp.escape_string msg`.
OBSERVED FLIP: `json.loads` exits 1 with
`json.decoder.JSONDecodeError: Invalid control character at: line 1
column 110 (char 109)`.  Measured at M4 HEAD (A0 row 15).
SECOND MUTATION: revert `lib/interp.ml:388` to `Pp.escape_string s`, and
extend the leg with a serializer round trip
(`jsonParse` then `jsonSerialize` then `jsonParse`) over `{"a":"x\ry"}`.
OBSERVED FLIP: the second `jsonParse` returns `none`, so the leg prints
`NONE` instead of the round-tripped value.  Both mutations are needed,
because the envelope and the serializer are two different call sites and
one leg must not certify the other.

**PASS-M5A-LONE-SURROGATE.**  Run all six negative payloads through the
guard: `m5a-lone-hi.json`, `m5a-lone-lo.json`, `m5a-short.json`,
`m5a-nonhex.json`, `m5a-hi-plain.json`, `m5a-hi-nonlow.json`.  Assert
exit 0 and EMPTY stdout for each, which is the fail-open path a failed
parse still takes with the flag OFF.  Then assert the parse result
DIRECTLY through the surface suite (A8 case 7), so the leg distinguishes
"the parse failed" from "the parse succeeded and the guard allowed".
MUTATION: accept a lone surrogate by deleting the
`| () when hi >= 0xdc00 && hi <= 0xdfff -> None` arm and dropping the
pair requirement on the high half.
OBSERVED FLIP: A8 case 7's assertions fail, because
`json_parse_top "\"\\ud800\""` returns `Some` instead of `None`.  The
guard half alone does NOT flip, which is precisely why the leg carries
the direct parse assertion.  A leg built only on the guard's exit code
would stay green under this mutation and would be VACUOUS.

**PASS-M5A-FENCE-PI.**  `gate-check` on `test/fixtures/m5a-fence-pi.tot`.
Assert exit non-zero AND
`rg -q 'erased variable px used at runtime'`.  In the SAME leg,
`gate-check` on `test/fixtures/m5a-fence-pi-ctl.tot` and assert exit 0.
MUTATION: in `lib/totality.ml:50`, change
`| Term.Pi (_q, _x, dom, cod) -> mentions name dom || mentions name cod`
to `| Term.Pi (_q, _x, dom, _cod) -> mentions name dom`.
OBSERVED FLIP: `self_rec` becomes false for `pxwrap`,
`zero_eliminable` becomes true, and `m5a-fence-pi.tot` exits 0.  The
control fixture is the flip target measured at M4 HEAD: A0 row 24 shows
the same shape without self recursion already exits 0, so the mutated
run reproduces exactly that output.
NOT A MUTATION: skipping Pi DOMAINS.  See the conflict note in A5.
`Check.strict_pos` forbids a family occurrence in a constructor
argument's Pi domain (A0 row 23), so that mutation cannot flip any leg
and must not be written down as a proof.

**PASS-M5A-PARAM-LEVEL.**  Three `gate-check` runs in one leg.
`m5a-param-level.tot` exits 0.  `m5a-param-level-neg.tot` exits non-zero
with
`rg -q 'invalid constructor kmk: constructor argument lives above the declared universe'`.
`m5a-index-level-neg.tot` exits non-zero with
`rg -q 'inductive IBad: index t lives above the declared universe'`.
MUTATION 1: bound the parameter fold, by changing `lib/check.ml:1578`
from `let* ty', _l = infer_univ globals ctx ty in` to a bound copying
the index fold's `Level.le l level` check.
OBSERVED FLIP: the POSITIVE leg fails.  Both `PBox` and `Acc` are
rejected, because each declares a parameter at `Type 0` (level 1) on a
level-0 family.
MUTATION 2: drop the constructor-argument bound at `lib/check.ml:1806`.
OBSERVED FLIP: the FIRST negative leg fails.  `KBad` checks at exit 0
and the pinned `Bad_ctor` text disappears.
MUTATION 3: drop the index bound at `lib/check.ml:1591`.
OBSERVED FLIP: the SECOND negative leg fails.  `IBad` checks at exit 0.
Three mutations, three distinct legs, no leg certifying another.

**PASS-M5A-STRICT-DENY.**  `tot run --strict-json examples/guard.tot`
with `test/fixtures/garbage.json` on stdin.  Assert exit 2 AND stdout
byte-equal to

    {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"strict-json: stdin is not a single well-formed JSON value"}}

Repeat with `m5a-lone-hi.json`, which the parser refuses even after the
`\u` work, and assert the same two facts.  That second payload proves
the flag covers a NON-CONFORMING payload, not only obvious garbage.
MUTATION: make `Effect.dispatch`'s strict guard unconditional by
replacing `strict_json && Option.is_none ...` with `false`.
OBSERVED FLIP: exit 0, EMPTY stdout, on both payloads.  That is the
state measured at M4 HEAD (A0 rows 26 and 3).

**PASS-M5A-STRICT-ALLOW.**  Three assertions in one leg.
(a) `tot run --strict-json examples/guard.tot` with
`test/fixtures/allow.json` exits 0 with empty stdout.
(b) The same command with `test/fixtures/deny.json` exits 2 with the
house-rule envelope, so the flag does not disturb a real verdict.
(c) WITHOUT the flag, `garbage.json` still exits 0 with empty stdout,
which pins the default posture byte-for-byte against M4 HEAD.
MUTATION: default `opts.strict_json` to `true` in `bin/tot.ml`.
OBSERVED FLIP: assertion (c) fails, because the unflagged garbage run
now prints the strict-json deny envelope and exits 2.  This is the leg
that keeps "default off" honest; the deny legs alone cannot see a
changed default.

**Marker list for `dev/gates.sh`:** `PASS-M5A-BYPASS`,
`PASS-M5A-FIXTURE-BYTES`, `PASS-M5A-ENVELOPE-VALID`,
`PASS-M5A-LONE-SURROGATE`, `PASS-M5A-FENCE-PI`, `PASS-M5A-PARAM-LEVEL`,
`PASS-M5A-STRICT-DENY`, `PASS-M5A-STRICT-ALLOW`.

Drive the `.tot` fixtures with
`dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/<name>`.
Drive the `.json` payloads through the guard's own shebang, using the
existing `$tot_scratch` PATH shim at `dev/gates.sh:375-383`, so the
prelude auto-load and the elaboration cache stay on the tested path.

Run every mutation, one at a time, and record the observed output in
`dev/M5-BUILD-LOG.md`.  A mutation that does not flip its leg is a
DEFECT in the leg, not an accepted result.  Revert each mutation before
the next.

---

### A11. SPEC.md decision-log entries for Stage A

Append a dated `2026-09-02 (M5, Stage A)` block to section 2, with these
entries written out in full:

1. **The JSON parser accepts `\uXXXX` and surrogate PAIRS.**  A high
   surrogate is valid only as the first half of a pair whose second
   half is `\uDC00` to `\uDFFF`.  A lone high surrogate, a lone low
   surrogate, a short escape, and a non-hex escape each return `none`
   and fail the WHOLE parse.  Record the exploit this closes, with the
   exact payload and the measured M4-HEAD exit code 0.
2. **`Pp.escape_string` is the SOURCE escaper; `Json_escape.string` is
   the JSON escaper.**  Record that M4's subset claim at
   `lib/interp.ml:375-380` was FALSE, name the three bytes that break
   it (`\r`, `\b`, `\f`), and record the three rewired call sites.
3. **Raw C0 bytes inside a parsed string body are still accepted.**  A
   deliberate non-change, with the reason: the guard's deny set does
   not read control bytes, and tightening the parser moves payloads
   between paths for no exploit found.  Record `\u0000`'s decode
   behaviour and that the resulting token still yields `allow`.
4. **`--strict-json`.**  Default off, `run` only, enforced at
   `Effect.dispatch`'s `readStdin` arm, `lib/` untouched.  Under the
   flag a payload that is not one well-formed JSON value DENIES with
   exit 2 and the fixed reason string.  An `IO Unit` script takes the
   DRIVER contract instead: one stderr line, exit 1, outside the
   `--serror-exit` mapping.  Record the three rejected alternatives of
   A4 and why each fails.
5. **The subsingleton fence walks under a Pi.**  `Totality.mentions`
   recurses into both halves of `Pi`, so a self-recursive occurrence in
   a constructor argument's Pi CODOMAIN keeps `self_rec = true` and
   `zero_eliminable = false`.  Record the CODOMAIN mutation as the
   executable proof.  Record the DOMAIN mutation as refuted by
   `Check.strict_pos` (`lib/check.ml:1731`), with the measured
   rejection text
   `invalid constructor pywrap: negative or non-uniform occurrence of PY`,
   so no later milestone proposes it again.
6. **The parameter-level predicativity exemption.**
   `lib/check.ml:1578` DISCARDS the inferred parameter level, while
   `lib/check.ml:1591` bounds every index type and `lib/check.ml:1806`
   bounds every constructor argument.  State that this exemption is
   what makes `Acc` check.  Record the WORKING `Acc` spelling verbatim,
   with `(0 A : Type 0)` and `(0 R : ...)` as parameters and
   `(0 x : A)` as an INDEX, and record that the verdict's own spelling
   fails at the parser.  Note that no milestone may cite this
   exemption as evidence again without this entry.
7. **The positivity door stays SHUT, and the reason is the MUTUAL
   gap.**  `Totality.mentions` tests only the family's OWN name, so a
   recursive PAIR reads as non-self-recursive.  Correct the losing
   proposal's nesting claim explicitly: nesting does NOT lose
   `self_rec`, because `mentions` recurses into both halves of `App`
   (`lib/totality.ml:52`), so `jarr : List Json -> Json` gives
   `self_rec = true`.  Record that the emptiness claim behind the
   subsingleton soundness argument stays UNPROVEN, and that M5 leaves
   M6 this oracle rather than a memory.
8. **Cache `format_version` stays 10.**  Record the five reasons of A9.

Section 3: add `--strict-json` to the driver grammar.  Section 4: no
change; no entry shape moves.  Section 6: leave the measured debts
alone at this stage.  Stage D rewrites section 6 with post-M5 numbers
(pin 18), and Stage A only ADDS the two non-changes of entries 3 and 8
to the residual list.

---

### A12. Stage A exit criteria

1. `dev/gates.sh` runs to completion with GATE-EXIT=0.
2. The walk shows 278 PASS from M4 plus the A8 and A10 additions, and
   0 FAIL.  No pre-existing marker is missing, renamed or edited.  The
   arithmetic is 278 + 15 + 8 = 301: A8 adds 15 suite cases (9 kernel,
   6 surface) and A10 adds 8 gate markers.  Every suite case counts,
   because `dev/gates.sh:36-39` replays both suites into its OWN
   stdout, which is what `rg -c '^PASS'` reads.  Report the measured
   number with this decomposition and hand it to Stage B;  Stage B
   chains from the MEASURED number, not from 278.
3. All eight `PASS-M5A-*` markers appear, and they are exactly the
   eight the preamble reserves.
4. Every mutation in A10 was run, flipped its own leg, and was
   reverted.  The build log records the mutation, the command, and the
   observed output for each.
5. `rg -l` for bytes below 0x20 over `test/fixtures/`, `stdlib/` and
   `examples/` still returns NOTHING (probe 27 repeated).
6. The escaper split is complete.  `rg -c 'Json_escape.string'
   lib/interp.ml` returns 2 and `rg -c 'Json_escape.string'
   surface/effect.ml` returns 1.  `rg -n 'Pp\.escape_string'
   lib/interp.ml surface/effect.ml` returns only COMMENT lines, and a
   reviewer confirms each one by eye.  The only remaining CALL sites of
   `Pp.escape_string` are its definition at `lib/pp.ml:7` and its one
   consumer `Pp.literal` at `lib/pp.ml:24`.
7. `git status --porcelain` shows your edits UNSTAGED and NOTHING
   committed.  The preamble's ground rule binds this stage: do not run
   `git add` and do not run `git commit`.  Print the porcelain output
   in the stage report;  the user stages and commits.

Do not start Stage B until every item above holds.
## STAGE B: instance term sharing

Verdict item 1, design pins 1 to 7. Entry: Stage A green. Exit: the
Stage A battery stays green and five new markers print.

This stage changes ONE thing: the SHAPE of the term the `Term.Auto` site
emits. It emits a local `let`-nest instead of a tree. No kernel typing
rule moves. No `Term.t` constructor is added. `Cache.format_version`
does not move (pin 1). The candidate is still re-checked at
`lib/check.ml:1002`, so a mis-shifted nest is a loud failure and never a
wrong dictionary (pin 6).

---

### B0. Entry state, measured on the M4 HEAD binary

Every number below comes from a run of
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe` on 2026-09-02.
Fixtures for the generated rows live outside the repo, under
`/Users/oobi/Documents/tot-m5-plan-sections/probes/fixtures/`. Copy the
generator, not the fixture, into the repo at B8.

The `P<n>` labels below are PROBE IDs, local to this section. They are
NOT the preamble's pins, and the two numberings are unrelated: probe
P13 is a zero-quantity dictionary binder, while pin P13 is the JSON
escaper rule. Cite a row here as `probe P<n>` and a normative pin as
`pin P<n>` or `pin <n>`. Stage B implements pins P1 to P7.

| Probe | Command | Exit | Elapsed | Last stdout line |
| --- | --- | --- | --- | --- |
| P1 | `check` a one-def file | 0 | 0.022s | `eval : Bool` |
| P2 | `run test/fixtures/m4fix-inst-branching.tot` (nesting 16) | 0 | 1.623s | `true` |
| P3 | `run test/fixtures/m4fix-inst-spec16.tot` (nesting 16) | 0 | 1.962s | `true` |
| P4 | `run test/fixtures/m4fix-inst-memo-key.tot` | 0 | 0.020s | `(succ zero)` |
| P5 | `run test/fixtures/m4fix-inst-chains.tot` (k=8, n=40) | 0 | 0.072s | `true` |
| P6 | `check` generated branching, nesting 16 | 0 | 2.183s | `eval : Bool` |
| P7 | `run` generated branching, nesting 16 | 0 | 1.718s | `true` |
| P8 | `run` generated branching, nesting 18 | 0 | 6.914s | `true` |
| P9 | `check` generated branching, nesting 20 | 0 | 31.570s | `eval : Bool` |
| P10 | `run` generated branching, nesting 20 | 0 | 30.188s | `true` |
| P11 | `run` generated chains, k=8 n=40 | 0 | 0.108s | `true` |
| P12 | `check` generated chains, k=8 n=800 | 124 | 30.013s (killed) | none |
| P13 | `run` an instance with a 0-quantity dictionary binder | 0 | 0.018s | `true` |
| P14 | `run` `gen-inst-fuel.py classes 60` | 0 | 0.269s | `zero` |
| P15 | `run` `gen-inst-fuel.py classes 61` | 1 | 0.138s | none (stderr below) |

P15 stderr, one line, verbatim after the `PATH:LINE:COL:` prefix:

```
instance resolution for (C0 ((WPair ((WPair Waaaa) Wbbbb)) ((WPair Wcccc) Wdddd))) exceeded its fuel
```

Three facts follow from the table and they size the whole stage.

1. The cost before this change is `2^n` in the nesting. P7, P8 and P10
   are 1.718s, 6.914s and 30.188s: 4.02x and 4.37x per two levels. The
   resolution itself is already linear (the M4 memo, `lib/check.ml:643`).
   What is exponential is the EMITTED term, which the mandatory re-check
   at `lib/check.ml:1002` walks as a tree.
2. The emitted tree size follows the `build_instance` recurrence.
   Each level adds one type application and two dictionary
   applications, so with `key(n) = 2(n - 1) + 1` for `SBox^(n-1) Bool`:

   ```
   T(0) = 1                              (Term.Global "inst$SC$Bool")
   T(n) = 2 * T(n - 1) + 2n + 2
   T(16) = 458714      T(20) = 7339986
   ```

   This is DERIVED from the code path, not measured. The Stage B
   kernel case at B10 prints the measured number, exactly as D9f
   prints `term_size` today (`test/main.ml:2378`).
3. A 0-quantity dictionary binder is accepted from source (P13:
   `inst$ZC$ZBox : (0 A : Type 0) -> (0 d : (ZC A)) -> (ZC (ZBox A))`).
   That shape is what makes the eager-`ELet` risk reachable, so it gets
   a fixture in the identity gate at B11.

The nest replaces `T(n)` with one `let` per DISTINCT (class, key) pair.
For the branching shape with `n + 1` distinct pairs the closed form is

```
S(n) = 2n^2 + 9n + 6        S(16) = 662      S(20) = 986
```

so the nest is 693x smaller than the tree at nesting 16. Below nesting
4 the nest is LARGER (S(3) = 51, T(3) = 44). That is expected and it is
not a defect. The gate at B11 is pinned at nesting 16 and 20, where the
margin is three orders of magnitude.

---

### B1. lib/term.ml: `Term.shift`

`lib/term.ml` holds the type only today (11 constructors at
`lib/term.ml:11-44`, the `motive` record at `lib/term.ml:88-102`).
Append `shift` after `lib/term.ml:102`.

```ocaml
(** M5 Stage B (pin 2): weaken a term by [by] under [cutoff] binders.
    Total and exhaustive over all eleven constructors, with no
    catch-all arm, so a twelfth constructor is a compile error here
    before it is a scope bug in a materialized instance nest.

    The two non-obvious cutoffs are the [Match] ones, and both follow
    the ONE convention this file states at [motive]: [m_body] is scoped
    under [m_idx] and then under [m_self], so it sits under
    [List.length m_idx + 1] binders; a branch body sits under its own
    ctor args, so it sits under [List.length binders] binders. *)
let rec shift ~(cutoff : int) ~(by : int) (t : t) : t =
  match t with
  | Var i -> if i >= cutoff then Var (i + by) else Var i
  | Univ l -> Univ l
  | Pi (q, x, dom, cod) ->
      Pi (q, x, shift ~cutoff ~by dom, shift ~cutoff:(cutoff + 1) ~by cod)
  | Lam (q, x, body) -> Lam (q, x, shift ~cutoff:(cutoff + 1) ~by body)
  | App (q, f, a) -> App (q, shift ~cutoff ~by f, shift ~cutoff ~by a)
  | Let (x, ty, def, body) ->
      Let
        ( x,
          shift ~cutoff ~by ty,
          shift ~cutoff ~by def,
          shift ~cutoff:(cutoff + 1) ~by body )
  | Ann (tm, ty) -> Ann (shift ~cutoff ~by tm, shift ~cutoff ~by ty)
  | Global g -> Global g
  | Lit l -> Lit l
  | Auto -> Auto
  | Match { scrut; scrut_q; motive; branches } ->
      Match
        {
          scrut = shift ~cutoff ~by scrut;
          scrut_q;
          motive =
            motive
            |> Option.map (fun (mo : motive) ->
                   {
                     mo with
                     m_body =
                       shift
                         ~cutoff:(cutoff + List.length mo.m_idx + 1)
                         ~by mo.m_body;
                   });
          branches =
            List.map
              (fun ((c : string), (binders : (Quantity.t * string) list), (body : t)) ->
                (c, binders, shift ~cutoff:(cutoff + List.length binders) ~by body))
              branches;
        }
```

Notes that the reviewer will ask about.

- `Auto` is a real arm, not a backstop comment. `Auto` binds nothing
  and holds no index, so it is its own shift.
- `Let`'s `def` shifts at `cutoff`, not `cutoff + 1`. `Check.check`
  binds the definition for the BODY only (`lib/check.ml:944`), and
  `Eval.eval` extends the env only for the body
  (`lib/eval.ml:60-62`). The def is outside its own binder.
- The `motive` update uses `{ mo with m_body = ... }`, so `m_ind`,
  `m_idx` and `m_self` cannot drift.
- The type does not change, so the marshal checklist at
  `lib/term.ml:1-9` is satisfied without a version bump. See B7.

---

### B2. lib/check.ml: the `islot` accumulator and its materializer

`build_instance` accumulates a `Term.t` today (`lib/check.ml:692`,
parameter `acc`). It cannot accumulate a `Term.t` any more, because a
dictionary argument must become a de Bruijn reference whose INDEX
depends on how many lets finally enclose it, and that number is not
known until the walk ends. The accumulator becomes an `islot`: an
instance application whose dictionary arguments are SLOT NUMBERS, which
are stable, plus type arguments in the ambient scope.

Insert after `inst_start` (new code following `lib/check.ml:561`).

```ocaml
(** M5 Stage B (pin 4): one instance application, with its dictionary
    arguments named by SLOT NUMBER instead of by de Bruijn index. A
    slot number is an index into [inst_state.entries] in DEFINITION
    order, and it never changes as the walk proceeds; a de Bruijn index
    for the same slot depends on how many lets finally enclose the use
    site, which the walk does not know until it ends. [islot_term]
    converts one to the other, once, at materialization. *)
type islot = IHead of string | IApp of Quantity.t * islot * iarg
and iarg = IType of Term.t | ISlot of int

(** The instance name at the head of an [islot] spine. This REPLACES
    [instance_head_name] (M4, lib/check.ml:448), whose argument was the
    [Term.t] accumulator this stage retypes. The [Inst_bad_shape]
    payload text is unchanged, so no pinned error string moves. *)
let rec islot_head (s : islot) : string =
  match s with IHead g -> g | IApp (_q, f, _a) -> islot_head f

(** M5 Stage B (pin 4): entry [i] is materialized under [i] enclosing
    lets, so an ambient-scoped type travels [i] binders inward and a
    slot [j] is [i - 1 - j] binders back. Both formulas are the same
    formula: the body of the whole nest is entry [n] with no [Let] of
    its own. *)
let rec islot_term (i : int) (s : islot) : Term.t =
  match s with
  | IHead g -> Term.Global g
  | IApp (q, f, a) ->
      let a_t =
        match a with
        | IType t -> Term.shift ~cutoff:0 ~by:i t
        | ISlot j -> Term.Var (i - 1 - j)
      in
      Term.App (q, islot_term i f, a_t)
```

The materializer builds the nest inside out with ONE fold over
`entries`, which is already in reverse definition order, so the fold
index counts DOWN from `n - 1` and every entry meets its own `i`.

```ocaml
(** M5 Stage B (pin 1): the local [let]-nest, the whole of the sharing
    change. [entries] is in REVERSE definition order (pin 3), which is
    reverse dependency order, so folding it left builds

      let dict$0 : T0 = d0 in .. let dict$(n-1) : T(n-1) = d(n-1) in
      dict$top

    from the inside out. [top] is the slot the query itself resolved
    to; it is [n - 1] for every resolution [resolve_auto] can return,
    because the last entry created is the one the query asked for.
    An out-of-range [top] would emit an unbound [Term.Var], which the
    re-check at lib/check.ml:1002 reports as [Unbound_var]; the
    function stays total either way and raises nothing. *)
let materialize (entries : inst_entry list) ~(top : int) : Term.t =
  let n = List.length entries in
  let nest, _i =
    List.fold_left
      (fun ((acc : Term.t), (i : int)) (e : inst_entry) ->
        ( Term.Let
            ( "dict$" ^ string_of_int i,
              Term.shift ~cutoff:0 ~by:i e.e_ty,
              islot_term i e.e_def,
              acc ),
          i - 1 ))
      (Term.Var (n - 1 - top), n - 1)
      entries
  in
  nest
```

**Worked example (kernel-level, nesting 2).** Source:

```
class SC (0 A : Type 0) := { sc : Bool }
data SBox (0 A : Type 0) : Type 0 := | sbox : A -> SBox A
instance : SC Bool := mkSC Bool true
instance : (0 A : Type 0) -> SC A -> SC A -> SC (SBox A) :=
  fun A d1 d2 => mkSC (SBox A) true
def d2 : Bool := sc (SBox (SBox Bool)) auto
```

The walk creates three entries, in this order:

| Slot | `e_ty` | `e_def` |
| --- | --- | --- |
| 0 | `SC Bool` | `IHead "inst$SC$Bool"` |
| 1 | `SC (SBox Bool)` | `IApp (w, IApp (w, IApp (0, IHead "inst$SC$SBox", IType Bool), ISlot 0), ISlot 0)` |
| 2 | `SC (SBox (SBox Bool))` | `IApp (w, IApp (w, IApp (0, IHead "inst$SC$SBox", IType (SBox Bool)), ISlot 1), ISlot 1)` |

Slot 0 is created once and used twice, because the second
`SC Bool` sub-goal is a memo HIT. `materialize ~top:2` gives, in
`Pp.term` spelling (`lib/pp.ml:36-38`):

```
let dict$0 : (SC Bool) = inst$SC$Bool in
let dict$1 : (SC (SBox Bool)) = ((inst$SC$SBox Bool) dict$0) dict$0 in
let dict$2 : (SC ((SBox (SBox Bool)))) = ((inst$SC$SBox (SBox Bool)) dict$1) dict$1 in
dict$2
```

The arithmetic, spelled once so the gate at B11 can mutate it:

- entry 1 is under 1 let, so `ISlot 0` is `Term.Var (1 - 1 - 0) = Var 0`;
- entry 2 is under 2 lets, so `ISlot 1` is `Term.Var (2 - 1 - 1) = Var 0`;
- the body is under 3 lets, so `ISlot 2` is `Term.Var (3 - 1 - 2) = Var 0`;
- every `e_ty` here is closed, so its shift is the identity. A goal
  under a local binder is not closed, and that is what `Term.shift`
  exists for.

---

### B3. lib/check.ml: `inst_state`, `entries`, and cached instance values

Replace `lib/check.ml:557` and `lib/check.ml:560-561`.

```ocaml
(** M5 Stage B (pin 3): one entry of the local [let]-nest.
    - [e_ty] is the entry's own type, [App (q_cls, Global cls, key_t)],
      in the AMBIENT scope. [materialize] shifts it.
    - [e_def] is the instance application with slot numbers (pin 4).
    - [e_val] is the entry's VALUE, built while the walk runs. It is
      what makes a memo HIT free: pin 5 says [build_instance] never
      re-evaluates a cached term, and this field is where the value it
      would have re-derived already lives. *)
type inst_entry = { e_ty : Term.t; e_def : islot; e_val : Value.t }

(** M4 fixes round 3 (opus R3-1) built this record; M5 Stage B changes
    two fields and adds one.
    - [memo] now maps an [inst_memo_key] to a SLOT NUMBER, not to a
      term. The soundness argument is M4's, unchanged: [globals] and
      [ctx] are invariant across one resolution, so a key that resolved
      once resolves identically again.
    - [entries] is in REVERSE definition order, which is dependency
      order: an entry can only reference slots that already existed
      when it was created.
    - [fuel] and [goal] are unchanged, and fuel accounting is
      unchanged: a HIT still charges nothing. *)
type inst_state = {
  fuel : int;
  memo : int InstMemo.t;
  entries : inst_entry list;
  goal : Value.t;
}

let inst_start (fuel : int) (goal : Value.t) : inst_state =
  { fuel; memo = InstMemo.empty; entries = []; goal }

(** The value already computed for slot [j]. [entries] is in reverse
    definition order, so slot [j] sits at list position
    [List.length entries - 1 - j]. [List.nth_opt] is the total
    combinator (the same one lib/eval.ml:49 and the [m_idx] walk use);
    a miss is unreachable, because every slot number this function ever
    receives was returned by [resolve_auto] for an entry it had just
    put in the list, and it is reported rather than raised. *)
let entry_val (entries : inst_entry list) (j : int) : (Value.t, Error.t) result =
  List.nth_opt entries (List.length entries - 1 - j)
  |> Option.map (fun (e : inst_entry) -> e.e_val)
  |> Option.to_result ~none:(Error.Unbound_var j)
```

`entry_val` is O(number of entries) per HIT, so a resolution with `m`
entries costs O(m^2) list steps in the worst case. Record the number,
do not guess it: the widest committed shape is `m4fix-inst-wide.tot`
with about 2500 leaves, and Stage D's measurement log (verdict Stage D)
carries the elapsed line. If that ever dominates, the fix is an
`int`-keyed map beside `entries`, which changes no formula in this
section. Do NOT add it speculatively; pin 3 fixes the record to four
fields.

---

### B4. lib/check.ml: `resolve_auto` and `build_instance`

Rewrite `lib/check.ml:615-672` and `lib/check.ml:691-743`. The
structure is M4's. Three things change.

**Signatures.** Both functions return a SLOT plus a VALUE now, not a
term.

```ocaml
let rec resolve_auto (globals : Global.t) (ctx : ctx) (st : inst_state)
    (expected : Value.t) : (int * Value.t * inst_state, Error.t) result

and build_instance (globals : Global.t) (ctx : ctx) (st : inst_state)
    (ity : Value.t) (targs : Value.t list) (acc : islot) (acc_v : Value.t) :
    (islot * Value.t * inst_state, Error.t) result
```

**`resolve_auto`, the memo arms** (replacing `lib/check.ml:643-664`).
The `Result.fold` shape stays, because both arms must stay functions
(the eagerness trap of M4 fixes round 1, ctxcat id 2).

```ocaml
InstMemo.find_opt mkey st.memo
|> Option.to_result ~none:()
|> Result.fold
     ~ok:(fun (j : int) ->
       (* pin 5: a HIT returns the slot and the CACHED value. No
          lookup of the instance, no telescope peel, no eval. *)
       let* v = entry_val st.entries j in
       Ok (j, v, st))
     ~error:(fun () ->
       let* d = Global.find_def mangled globals |> ... in
       let* ity = Eval.eval globals [] d.Global.ty in
       let* head_v = Eval.eval globals [] (Term.Global mangled) in
       let targs = ... (* unchanged, lib/check.ml:654-662 *) in
       let* slot_def, def_v, st' =
         build_instance globals ctx st ity targs (IHead mangled) head_v
       in
       let q_cls =
         Global.find_ind cls globals
         |> Option.map (fun (ind : Global.ind_entry) -> ind.Global.params)
         |> Option.map (fun (ps : Global.telescope) -> List.nth_opt ps 0)
         |> Option.join
         |> Option.fold ~none:Quantity.Many ~some:(fun ((q, _x, _t) :
              Quantity.t * string * Term.t) -> q)
       in
       let entry =
         {
           e_ty = Term.App (q_cls, Term.Global cls, key_t);
           e_def = slot_def;
           e_val = def_v;
         }
       in
       let j = List.length st'.entries in
       Ok
         ( j,
           def_v,
           {
             st' with
             memo = InstMemo.add mkey j st'.memo;
             entries = entry :: st'.entries;
           } ))
```

`q_cls` comes from the class's own `ind_entry` (pin 4). For every class
the M4 surface can declare it is `Quantity.Zero`, because `class C (0 A
: Type 0)` puts the parameter at 0 (see P14's echo,
`(0 A : Type 0) -> ..`). The `~none:Quantity.Many` default is
unreachable, because `resolve_auto` reached this line only by matching
`Value.VInd (cls, [ av ])`, and it is a stamp the re-check overwrites
anyway (`infer`'s App arm takes the quantity from the Pi,
`lib/check.ml:770-779`). Do not spend an error on it.

**`build_instance`, the two peeling arms** (replacing
`lib/check.ml:697-728`). The `Error.Inst_bad_shape` payloads keep the
same two reason strings and take their name from `islot_head acc`.

```ocaml
| Value.VUniv _ -> (
    match targs with
    | [] -> Error (Error.Inst_bad_shape { name = islot_head acc; reason = ".." })
    | t_i :: rest ->
        let* arg_t = Eval.quote globals ctx.size t_i in
        let acc' = IApp (q, acc, IType arg_t) in
        (* the VALUE half applies the ORIGINAL value, never the
           quoted-then-re-evaluated one *)
        let* acc_v' = Eval.apply globals acc_v t_i in
        let* next_ity = Eval.app_closure globals clo t_i in
        build_instance globals ctx { st with fuel = st.fuel - 1 } next_ity rest acc'
          acc_v')
| Value.VInd (cls_j, [ dv ]) ->
    let* j, sub_v, st' =
      resolve_auto globals ctx { st with fuel = st.fuel - 1 } (Value.VInd (cls_j, [ dv ]))
    in
    let acc' = IApp (q, acc, ISlot j) in
    let* acc_v' = Eval.apply globals acc_v sub_v in
    let* next_ity = Eval.app_closure globals clo sub_v in
    build_instance globals ctx { st' with fuel = st'.fuel - 1 } next_ity targs acc'
      acc_v'
```

**What is DELETED**: `lib/check.ml:725`,
`let* sub_v = Eval.eval globals ctx.env sub in`. That single line is
the M4 cost this stage removes from the walk itself. It evaluated the
whole resolved sub-tree once per dictionary argument. The value now
arrives from `acc_v`, built one application at a time with
`Eval.apply` (`lib/eval.ml:139`).

The value half is the same value by NbE's own equation: `Eval.eval`
implements `App` as `apply (eval f) (eval a)` (`lib/eval.ml:56-59`),
and a `Term.Global` evaluates the same in every env
(`lib/eval.ml:73-95`), so seeding `acc_v` with
`Eval.eval globals [] (Term.Global mangled)` and applying arguments
left to right reproduces `Eval.eval globals ctx.env <the spine>`
exactly. For a type argument it is strictly better: M4 quoted `t_i` and
then re-evaluated the quotation, while this applies `t_i` itself.

**Unchanged, and say so in the commit**: the fuel arm
(`lib/check.ml:694`), the decrement sites, `inst_fuel`
(`lib/check.ml:428-441`), `inst_memo_key` (`lib/check.ml:536-537`) and
`inst_key_enc` (`lib/check.ml:483-528`). A memo HIT still charges
nothing. PASS-M5B-FUEL-REACHABLE at B11 is the executable proof that
the leaf did not move.

---

### B5. lib/check.ml: the `Term.Auto` site

Replace `lib/check.ml:998-1002`. This is the only place a nest is
built, and it is also the production call site the reach gate must
exercise.

```ocaml
let* expected_t = Eval.quote globals ctx.size expected_v in
let* top, _top_v, st_end =
  resolve_auto globals ctx (inst_start (inst_fuel globals expected_t) expected_v)
    expected_v
in
let candidate = materialize st_end.entries ~top in
check globals ctx mode candidate expected_v
```

Four properties hold here and each one is load bearing.

1. The state is FRESH per `Term.Auto` (M4 fixes round 3). Nothing
   carries across two `Auto` sites, so no slot number is ever
   interpreted in the wrong nest.
2. The re-check is unchanged (pin 6). A wrong shift is a `Mismatch` or
   an `Unbound_var` at this line, never a silently wrong dictionary.
3. Every entry is reachable from the body. An entry exists only because
   some `build_instance` step asked for it, and that step put `ISlot j`
   into ITS accumulator, which becomes an entry in turn. Induction ends
   at `top`, which is the body. The nest therefore binds no dead slot
   at the TERM level.
4. Erasure is not touched. `Erase` maps `Term.Let` to `Eterm.ELet`
   (`lib/erase.ml:38-41`) and `Interp` executes an `ELet` eagerly
   (`lib/interp.ml:547`). Property 3 is about the term, not about the
   erased term: a slot used ONLY at a 0-quantity dictionary binder
   loses its use site in erasure while its `ELet` survives, so the
   nest can add runtime work that the tree did not have. P13 proves
   that shape is accepted from source. Stage B pins the OUTPUT half of
   it (PASS-M5B-RUNTIME-IDENTITY, B11) and hands the COST half to
   Stage D's measurement log. Do not add a dead-slot elimination here:
   it needs an index-level occurrence test on `Eterm.t`, and
   `Eterm.mentions` (`lib/eterm.ml:40`) matches NAMES, so the change is
   a new function in `Erase` and it is out of this stage's contents.

---

### B6. lib/eval.ml: the physical-equality shortcut in `conv`

The nest binds one value per entry and `Eval.eval` extends the env with
that one value (`lib/eval.ml:60-62`), so two uses of the same
dictionary are now the SAME pointer. Give `conv` the shortcut that
turns into.

Split `lib/eval.ml:273-274`. Keep the whole existing shape match, and
rename it. Add no catch-all arm to it.

```ocaml
and conv (globals : Global.t) (size : int) (a : Value.t) (b : Value.t) :
    (bool, Error.t) result =
  (* M5 Stage B: physical identity implies structural identity implies
     convertibility, so this arm is sound for every value shape. It
     pays for the let-nest: the nest binds one value per entry, so two
     uses of one dictionary are one pointer and the deep comparison is
     skipped whole. *)
  match () with
  | () when a == b -> Ok true
  | () -> conv_shapes globals size a b

and conv_shapes (globals : Global.t) (size : int) (a : Value.t) (b : Value.t) :
    (bool, Error.t) result =
  match (a, b) with
  | Value.VUniv l1, Value.VUniv l2 -> Ok (Level.equal l1 l2)
  (* .. the existing 20 arms, byte for byte, lib/eval.ml:275-353 .. *)
```

Every recursive call inside `conv_shapes` keeps calling `conv`, not
`conv_shapes`, so the shortcut applies at every depth.

One consequence, stated rather than discovered later: if `a == b` and
the shared value contains a closure whose forcing would fail, M4
returned that `Error` and M5 returns `Ok true`. The verdict is not
wrong (identical values are convertible), but it is a CHANGE. The whole
278-marker walk pins the error texts that could move, so run it before
and after this edit and diff the two outputs, not just the exit code.

---

### B7. surface/cache.ml: no change (pin 1)

`Cache.format_version` stays at 10 (`surface/cache.ml:118`). Write the
reason in the commit message, because a reviewer will ask.

- `Term.t` is unchanged, so the marshal layout is unchanged. The
  checklist that demands a bump lives at `lib/term.ml:1-9` and it is
  about the TYPE.
- A cache written before this stage holds unshared but perfectly valid
  terms. They check, they erase and they run.
- The cache key already includes the MD5 of the running binary
  (`surface/cache.ml:346`), so a rebuilt `tot.exe` invalidates the
  cache on its own. A version bump would buy nothing that the digest
  does not already buy.

---

### B8. New generators

The committed instance fixtures stop at nesting 16
(`test/fixtures/m4fix-inst-branching.tot`) and at k=8 n=40
(`test/fixtures/m4fix-inst-chains.tot`), and no committed generator
produces either shape. `dev/gen-inst-fuel.py` makes the classes and
binders shapes; `dev/gen-wide-instance.py` makes the wide shape.

**`dev/gen-inst-branching.py N`**. Emits the two-dictionary-binders
shape at nesting `N`, the shape whose emitted term is `T(N)`:

```
class SC (0 A : Type 0) := { sc : Bool }
data SBox (0 A : Type 0) : Type 0 := | sbox : A -> SBox A
instance : SC Bool := mkSC Bool true
instance : (0 A : Type 0) -> SC A -> SC A -> SC (SBox A) :=
  fun A d1 d2 => mkSC (SBox A) true
def deepBranching : Bool := sc (SBox (.. N deep .. Bool)) auto
eval deepBranching
```

**`dev/gen-inst-chains.py K N`**. Emits `K` independent chains over `N`
boxes plus the `WR` joiner, the shape `m4fix-inst-chains.tot` holds at
K=8 N=40.

Both generators follow `dev/gen-inst-fuel.py`'s own rules: a header
comment naming the generator and its arguments, no randomness, no
hashing, no seed and no cwd dependence, and the exact reproduction
command in the docstring. Neither generator OVERWRITES a committed M4
fixture. The M4 files stay byte-identical, so PASS-M4FIX-INST-BRANCHING
and PASS-M4FIX-INST-CHAINS keep testing what they tested.

---

### B9. Stage B fixtures

Five files, all generated, all with the generator command in their own
header.

| File | Generator | Purpose |
| --- | --- | --- |
| `test/fixtures/m5b-inst-branching-20.tot` | `gen-inst-branching.py 20` | PASS-M5B-BRANCHING-20 |
| `test/fixtures/m5b-inst-chains-8-40.tot` | `gen-inst-chains.py 8 40` | PASS-M5B-RUNTIME-IDENTITY |
| `test/fixtures/m5b-inst-zero-dict.tot` | hand written, 6 lines | the 0-quantity dictionary binder (P13) |
| `test/fixtures/m5b-inst-fuel-under.tot` | `gen-inst-fuel.py classes 60` | PASS-M5B-FUEL-REACHABLE, positive |
| `test/fixtures/m5b-inst-fuel-leaf.tot` | `gen-inst-fuel.py classes 61` | PASS-M5B-FUEL-REACHABLE, negative |

`m5b-inst-zero-dict.tot`, verbatim, is the P13 file:

```
class ZC (0 A : Type 0) := { zc : Bool }
data ZBox (0 A : Type 0) : Type 0 := | zbox : A -> ZBox A
instance : ZC Bool := mkZC Bool true
instance : (0 A : Type 0) -> (0 d : ZC A) -> ZC (ZBox A) := fun A d => mkZC (ZBox A) true
def zq : Bool := zc (ZBox (ZBox Bool)) auto
eval zq
```

---

### B10. Stage B kernel tests (test/main.ml)

**Three call sites must change**, because `build_instance`'s
accumulator is an `islot` now: `test/main.ml:1851-1852` (D7),
`test/main.ml:1876-1877` (D7b) and `test/main.ml:2148-2149` (D7c). Each
`(Term.Global "inst$Cls$Key")` becomes `(Check.IHead "inst$Cls$Key")`
and each gains the seed value argument. Their assertions do not change:
fuel 0 is still `Inst_depth`, the payload still names the query, and
the message is still elided. These three are exactly the cases the
verdict warns the reach gate must not duplicate.

**Six new cases.** Compare terms through `Check.inst_key_enc`
(`lib/check.ml:483`), which is already the repo's injective total
encoding of a `Term.t`. That avoids polymorphic compare for the same
reason `inst_key_enc` exists.

- `M5B1: Term.shift is exhaustive and cutoff correct`. One term that
  uses all eleven constructors, shifted `~cutoff:1 ~by:2`. Assert
  `Var 0` is unmoved, `Var 1` becomes `Var 3`, the `Pi` codomain's
  `Var 1` (its own binder) is unmoved and its `Var 2` becomes `Var 4`,
  the `Let` def shifts at the outer cutoff and the `Let` body at
  `cutoff + 1`, and `Univ`, `Global`, `Lit` and `Auto` are identities.
- `M5B2: a motive body shifts at cutoff + |m_idx| + 1`. Motive with
  `m_idx = [ "i"; "c" ]`, so the body sits under 3 binders. Body
  mentions `Var 2` (the OUTERMOST index binder, bound) and `Var 3` (the
  first free index). Shift `~cutoff:0 ~by:5`. Assert `Var 2` stays and
  `Var 3` becomes `Var 8`.
- `M5B3: a branch body shifts at cutoff + |binders|`. One branch with
  two ctor args, body mentions `Var 1` (bound) and `Var 2` (free).
  Shift `~cutoff:0 ~by:5`. Assert `Var 1` stays and `Var 2` becomes
  `Var 7`.
- `M5B4: the branching nest at nesting 16 is small`. Build the class,
  the box and the two instances with `Check.declare_ind` and the D9f
  opaque-instance helper (`test/main.ml:2335-2371` is the model),
  build the goal `SC (SBox^16 Bool)` as a `Value.t`, call
  `Check.check g Check.empty_ctx qw Term.Auto goal`, print
  `M5B4 term_size=%d` for the returned term, and assert
  `term_size < 4000`. No clock is read, so the case is
  machine-independent. Expected print: `662` by the closed form at B0.
- `M5B5: a slot is materialized at i - 1 - j`. Build the nesting-2
  worked example of B2 through `Check.check`, then assert the checker
  output's `inst_key_enc` equals the encoding of the nest spelled out
  by hand in B2. This is the case that fails on an off-by-one that the
  size case cannot see.
- `M5B6: a memo HIT re-uses the cached value`. Resolve the nesting-2
  goal and assert the returned nest binds exactly 3 lets, so the second
  `SC Bool` sub-goal produced no fourth entry.

---

### B11. Gate B

Five markers, none of which collides with a name in `dev/gates.sh`
(`rg 'PASS-M5' dev/gates.sh` matches nothing at M4 HEAD). Watchdog
literals are written as literals here because the named tiers are Stage
D's contents; Stage D's PASS-M5D-TIERS rewrites all five to `$FAST`,
`$MED` or `$SLOW`.

**PASS-M5B-SHIFT.** Assert the three kernel PASS lines inside the
captured `$main_out` (the pattern `dev/gates.sh:48-50` already uses for
PASS-A-LITERALS).

```sh
{ printf '%s\n' "$main_out" | rg -q '^PASS M5B1: ' \
    && printf '%s\n' "$main_out" | rg -q '^PASS M5B2: ' \
    && printf '%s\n' "$main_out" | rg -q '^PASS M5B3: '; } \
  && echo PASS-M5B-SHIFT \
  || { echo "FAIL-M5B-SHIFT"; exit 1; }
```

- Mutation 1: in `Term.shift`, change the motive cutoff from
  `cutoff + List.length mo.m_idx + 1` to `cutoff + List.length
  mo.m_idx`. Observed flip: M5B2's bound `Var 2` becomes `Var 7`, the
  case prints `FAIL M5B2`, the suite exits 1 and this marker never
  prints. This is the verdict's named mutation.
- Mutation 2: change the branch cutoff to `cutoff + 1`. Observed flip:
  M5B3's bound `Var 1` becomes `Var 6` and M5B3 fails.
- Mutation 3: make the `Var` arm return `Var (i + by)` unconditionally.
  Observed flip: M5B1's `Var 0` becomes `Var 2` and M5B1 fails.

**PASS-M5B-SHARE-SIZE.** Machine-independent, from the same capture.

```sh
printf '%s\n' "$main_out" | rg -q '^PASS M5B4: ' \
  && echo PASS-M5B-SHARE-SIZE \
  || { printf '%s\n' "$main_out" | rg 'M5B4'; echo "FAIL-M5B-SHARE-SIZE"; exit 1; }
```

- Mutation: replace `islot_term`'s `ISlot j` arm with the entry's own
  materialized term (inline the slot instead of referencing it), which
  is exactly the M4 tree. Observed flip: the printed `term_size` goes
  from 662 to 458714, the `< 4000` assertion fails, and the marker
  never prints. The two numbers are the closed forms at B0; record the
  measured pair in `dev/M5-BUILD-LOG.md`.

**PASS-M5B-BRANCHING-20.** The perf leg, in the FAST budget.

```sh
out=$("$watchdog" 10 "$ROOT"/_build/default/bin/tot.exe run \
  "$ROOT"/test/fixtures/m5b-inst-branching-20.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] && printf '%s\n' "$out" | rg -qx 'true'; } \
  && echo PASS-M5B-BRANCHING-20 \
  || { printf '%s\n' "$out" | tail -n 3; echo "FAIL-M5B-BRANCHING-20 (exit=$code)"; exit 1; }
```

- Mutation: revert the nest (mutation of PASS-M5B-SHARE-SIZE, the
  inlining `islot_term`). Observed flip: exit 124, no `true` line, and
  the marker fails. This flip is ALREADY MEASURED, not predicted: the
  same file on the M4 HEAD binary takes 30.188s to run and 31.570s to
  check (P10, P9) against a 10s budget.
- Place this leg where PASS-M4FIX-INST-BRANCHING sits, at the END of
  the file (`dev/gates.sh:1636-1640`). The M4 round-4 lesson holds: the
  most timing-sensitive leg must have no marker downstream of it.
- Expected after sharing: 21 entries and a 986-node term, so tens of
  milliseconds. Record the measured elapsed in the build log. Do not
  lower the budget below 10s; the tier is Stage D's decision.

**PASS-M5B-FUEL-REACHABLE.** Two legs, both through `tot run`, so the
only path into `resolve_auto` is the production call site at
`lib/check.ml:1000` with `inst_start (inst_fuel globals expected_t)`.
An `inst_start 1` unit test cannot see the formula's VALUE, which is
why D7, D7b and D7c do not cover this.

```sh
out=$("$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe run \
  "$ROOT"/test/fixtures/m5b-inst-fuel-under.tot 2>&1)
code=$?
{ [ "$code" -eq 0 ] && [ "$(printf '%s\n' "$out" | rg -cx 'zero')" = "1" ] \
    && ! printf '%s\n' "$out" | rg -q 'fuel'; } \
  && out2=$("$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe run \
       "$ROOT"/test/fixtures/m5b-inst-fuel-leaf.tot 2>&1) \
  && { code2=$?; [ "$code2" -eq 1 ]; } \
  && printf '%s\n' "$out2" | rg -qF \
       'instance resolution for (C0 ((WPair ((WPair Waaaa) Wbbbb)) ((WPair Wcccc) Wdddd))) exceeded its fuel' \
  && echo PASS-M5B-FUEL-REACHABLE \
  || { printf '%s\n' "$out" "$out2" | tail -n 3; echo "FAIL-M5B-FUEL-REACHABLE"; exit 1; }
```

Measured today: the positive is 0.269s at exit 0 with `zero` (P14), and
the negative is 0.138s at exit 1 with that exact line (P15). The
negative's full stderr on the M4 HEAD binary, prefix included, is
`<path>:446:1: instance resolution for (C0 ((WPair ((WPair Waaaa)
Wbbbb)) ((WPair Wcccc) Wdddd))) exceeded its fuel`, which is why the
oracle matches the message with `rg -qF` and not the line and column.

- Mutation 1: charge fuel on a memo HIT (thread
  `{ st with fuel = st.fuel - 1 }` through the `~ok:` arm of
  `resolve_auto`'s `Result.fold`). Observed flip: the POSITIVE leg
  exits 1 and prints the same `exceeded its fuel` message, so the
  marker fails. This is the mutation that proves the leg reads the
  formula and the accounting, not just a file.
- Mutation 2: double `inst_fuel`'s floor (`Int.max 10000` becomes
  `Int.max 20000`). Observed flip: the NEGATIVE leg exits 0 and the
  message is absent, so the marker fails.
- Both mutations leave PASS-M5B-SHIFT, PASS-M5B-SHARE-SIZE and
  PASS-M5B-BRANCHING-20 green, so this leg is not a duplicate of any of
  them.

**PASS-M5B-RUNTIME-IDENTITY.** Four files, each pinned to the exact
runtime line the M4 HEAD binary printed today. The `eval` line IS the
runtime output; the `def ..` echo above it is checker output and other
markers pin that.

```sh
ri_fail=0
for f in m4fix-inst-memo-key m5b-inst-branching-20 m5b-inst-chains-8-40 m5b-inst-zero-dict; do
  out=$("$watchdog" 30 "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/test/fixtures/$f.tot 2>&1)
  code=$?
  [ "$code" -eq 0 ] || { printf '%s\n' "$out" | tail -n 2; ri_fail=1; }
done
# memo-key prints (succ zero); the other three print true
...
```

The pinned lines are `(succ zero)` for `m4fix-inst-memo-key` (P4) and
`true` for the other three (P10, P11, P13).

- Mutation 1: materialize `ISlot j` as `Term.Var (i - 1)`, so every
  slot reads the newest entry. Observed flip: `m4fix-inst-memo-key`
  stops printing `(succ zero)`; it reads the wrong dictionary and
  prints `zero`, or the re-check at `lib/check.ml:1002` rejects the
  candidate and the run exits 1. Either way the marker fails. The
  memo-key file is in this leg precisely because its VALUE depends on
  which dictionary a slot names, while the branching and chains files
  print `true` for every dictionary.
- Mutation 2: make `Term.shift`'s `Var` arm ignore `by`. Observed flip:
  the nest is mis-scoped, the re-check reports a `Mismatch` or an
  `Unbound_var`, and every leg but the memo-key one exits 1.
- Mutation 3: drop the `e_val` cache and re-evaluate on a HIT.
  Observed flip: none, and that is the point. This leg pins OUTPUT, so
  it is honest about not being a performance gate; PASS-M5B-BRANCHING-20
  is the leg that fails on mutation 3's cost.

---

### B12. chains-800 is NOT a Stage B gate

State this in the gate file next to PASS-M5B-RUNTIME-IDENTITY, so a
later reader does not "fix" the omission.

`gen-inst-chains.py 8 800` builds 8 independent chains over 800 boxes.
Every sub-goal in it is a DISTINCT (class, key) pair: chain `Wj` at
depth `d` is asked for exactly once. The M4 memo already answers zero
queries from cache on that shape, and sharing removes duplicate ENTRIES
only, so there is nothing for the nest to share. The nest cannot make
that file faster, and pin 4's per-slot type annotation gives each entry
an extra `App (q_cls, Global cls, key_t)` for the re-check to walk, so
it may make it slightly slower.

The file is measured, not assumed: `tot check` on it does not finish
inside 30s on the M4 HEAD binary (P12, exit 124). It is Stage C's
evidence, where `--check-budget-ms` turns that 124 with no verdict into
the reserved exit code with one exact stderr line. Generate it in
Stage C, not here.

---

### B13. Conflicts resolved in this section (2026-09-02)

**C-B1. Pin 4 versus `instance_head_name` (lib/check.ml:443-458).**
The pin retypes `build_instance`'s accumulator from `Term.t` to
`islot`. `instance_head_name` consumes that accumulator and is called at
`lib/check.ml:705` and `lib/check.ml:738`, its only two callers.
RESOLUTION: delete it and add `islot_head : islot -> string` (B2), a
two-arm exhaustive walk down the spine. The `Totality.spine` call and
the `"<instance>"` fallback go with it, because an `islot` head is a
`string` by construction. The `Inst_bad_shape` payload text does not
change, so no pinned error string moves.

**C-B2. PASS-M5B-FUEL-REACHABLE versus Stage C's PASS-M5C-CLASSES-61.**
Stage B pins `gen-inst-fuel.py classes 61` at exit 1 (P15). Stage C
multiplies `inst_fuel` by `1 + class_count globals` (pin 12) and its
own gate requires that same file to exit 0. The two pins cannot both
hold after Stage C. There is no leaf that survives, because the class
count is exactly the dimension Stage C's factor tracks: the charge on
this shape grows like K squared, Stage B's fuel like K, and Stage C's
fuel like K squared. RESOLUTION: the K lives in exactly one place, the
generator command in the fixture header, and Stage C re-bisects it and
regenerates BOTH `m5b-inst-fuel-under.tot` and `m5b-inst-fuel-leaf.tot`
in the same commit that lands the factor. The gate NAME, its oracle and
its two mutations do not change. Write the handoff sentence into the
leg's own comment in `dev/gates.sh`, next to the K = 60 / K = 61 pair
and the date they were measured.

**C-B3. Pin 5 versus `lib/check.ml:725`.** Pin 5 says `build_instance`
never re-evaluates a cached term, but the repo evaluates every resolved
sub-dictionary at `lib/check.ml:725` and the pin names no replacement
source for the value that `Eval.app_closure` at `lib/check.ml:727`
needs. RESOLUTION: thread a parallel value accumulator `acc_v` through
`build_instance` (B4), seeded with
`Eval.eval globals [] (Term.Global mangled)` and advanced with
`Eval.apply` (`lib/eval.ml:139`), and store the finished value in
`e_val`. The type-argument step applies the ORIGINAL `t_i` value rather
than the quotation of it. Line 725 is deleted. Equality with M4's value
is NbE's own `App` equation (`lib/eval.ml:56-59`), and pin 6's re-check
is the executable backstop.

Two smaller notes, resolved in place and not counted as conflicts.
`lib/term.ml:1-9` demands a `Cache.format_version` bump for any change
to `Term.t`; this stage adds a FUNCTION and no constructor, so pin 1
holds (B7). `Eval.quote` stamps `Quantity.Many` on an inductive
application (`lib/eval.ml:198-204`), so quoting the goal would give a
placeholder stamp where pin 4 asks for the class's own quantity; B4
reads it from `Global.ind_entry` instead.

---

### B14. Exit criteria

1. `dev/gates.sh` runs to `exit 0` with BUILD-OK and TEST-OK.
2. Every marker green at Stage A exit is still green, with no text
   change. Diff the whole captured output against Stage A's, not just
   the exit code (B6 explains why).
3. The five new markers print: PASS-M5B-SHIFT, PASS-M5B-SHARE-SIZE,
   PASS-M5B-BRANCHING-20, PASS-M5B-FUEL-REACHABLE,
   PASS-M5B-RUNTIME-IDENTITY.
4. The PASS count is the Stage A count plus 11: six new kernel cases
   (M5B1 to M5B6) and five new gate markers. Report the decomposition,
   the way M4-PLAN's Final section does. Stage A's section owns its own
   number, and you MEASURE it at entry rather than assume it: run the
   battery before you edit anything and record `rg -c '^PASS'`. The
   expected chain is 278 M4 baseline, plus Stage A's 15 suite cases and
   8 gate markers, which gives 301 at Stage A exit, so Stage B exits at
   312. Every suite case counts because `dev/gates.sh:36-39` replays
   both suites into its own stdout, which is what `rg -c '^PASS'`
   reads. If the measured Stage A number is not 301, the number you
   measured wins and the shortfall belongs to Stage A: say so, and do
   not absorb it.
5. Every mutation in B11 has been RUN, and its observed flip is
   recorded in `dev/M5-BUILD-LOG.md` with the marker that turned red.
   A mutation that does not flip is a defect in the gate, not a
   curiosity: fix the gate before moving to Stage C.
6. The measured `term_size` from M5B4 and the measured elapsed from
   PASS-M5B-BRANCHING-20 are in the build log beside the B0 numbers
   they replace.
7. `git status --porcelain` shows your edits UNSTAGED and NOTHING
   committed. The preamble's ground rule binds this stage: do not run
   `git add` and do not run `git commit`. Print the porcelain output in
   the stage report; the user stages and commits.

---

### B15. Handoffs

- Stage C owns the fuel leaf. See C-B2 for the exact regeneration
  command and the two files to replace.
- Stage C owns chains-800. See B12 for the reason and for P12's
  measured 124.
- Stage D owns the tiers. Five watchdog literals enter the file here
  (10, 30, 30, 30, 30) and PASS-M5D-TIERS must remove all five.
- Stage D owns the cost measurement of the eager `ELet` on a slot used
  only at quantity 0. See B5, property 4, and the
  `m5b-inst-zero-dict.tot` fixture.
- Stage D owns the SPEC entries. Stage B writes none. What Stage D must
  record from here: pin 1 (the format version did not move, and why),
  pin 2 (the two `Match` cutoffs), pins 3 to 5 (the nest, the slot
  numbering and the cached values), pin 6 (the re-check is the safety
  net), and pin 7 (key-type sharing stays a measured option, decided by
  the M5B4 number and the Stage D log, with no new design).
# STAGE C: the check budget, the class-count fuel factor, and one driver decision

Goal: `tot` gives a VERDICT on a query it cannot finish. Today it gives
none. A linear chain of 800 boxes costs more than 60 seconds of wall
clock and returns exit 124 from the caller's own `timeout`, with an
empty stdout and an empty stderr. Stage C adds a driver-supplied check
budget with one exact stderr line and a reserved exit code. It also
pays the second measured debt: the instance fuel bound gains the
class-count factor, and the K leaf is re-bisected under a stated
stopping rule.

Stage C implements verdict items 2 and 3, pins P8 to P12, and the
amendments those two carry into the pin list: A1 is pin P19 and A3 is
pin P21. Cite them by pin number, never by a bare `P<n>`: the probe
tables in this section number their rows `P1`, `P2` and so on, and a
probe ID is local to its own section and has no relation to the pin of
the same number.

This stage adds no kernel typing rule. The budget is a CUTOFF, not a
type. The fuel factor moves a number. `--require-main` moves an exit
code from one contract to another. Nothing here changes what a
well-formed program means.

## Entry state

Stage B is green. The battery is at the M4 count of 278 PASS plus
Stage A's and Stage B's own additions. `Term.shift`, the `islot`
materializer and the cached instance values are in. `dev/gen-inst-chains.py`
exists, because Stage B added it: no committed generator produced a
chain of 800 boxes before Stage B, and both stages need one. Stage C
names that generator `dev/gen-inst-chains.py` throughout. If Stage B
commits it under another name, Stage C follows Stage B's name and
changes nothing else. The generator takes the nesting as its one
argument and writes the file to stdout. At n = 40 its body must
reproduce `test/fixtures/m4fix-inst-chains.tot`, which is how Stage B
proves it makes the shape the committed fixture already pins. A probe
copy of that generator, used only to measure this section's numbers,
is at
`/Users/oobi/Documents/tot-m5-plan-sections/probes/gen-chains.py`. Its
n = 40 output differs from the committed fixture in the six-line header
comment alone.

Every number below was measured on the M4 HEAD binary at
`_build/default/bin/tot.exe` on 2026-09-02, on this machine, with
`TOT_PRELUDE=/Users/oobi/Documents/tot/stdlib/prelude.tot`. Each
measured line names the command that produced it.

Baseline measurements, all executed:

| probe | command | result |
| --- | --- | --- |
| chains, n=100 | `tot run chains100.tot` | exit 0, 0.65 s, 2332 bytes of source |
| chains, n=200 | `tot run chains200.tot` | exit 0, 6.77 s |
| chains, n=200 | `tot check chains200.tot` | exit 0, 6.48 s |
| chains, n=400 | `tot run chains400.tot` | exit 0, 54.34 s |
| chains, n=800 | `timeout 60 tot run chains800.tot` | exit 124, 60.03 s, stdout EMPTY, stderr EMPTY, 7232 bytes of source |
| chains, n=800 | `timeout 60 tot check chains800.tot` | exit 124, 60.02 s, stdout EMPTY, stderr EMPTY |
| classes, K=57 | `tot run cls57.tot` | exit 0, 0.40 s |
| classes, K=60 | `tot run cls60.tot` | exit 0, 0.32 s |
| classes, K=61 | `tot run cls61.tot` | exit 1, 0.16 s, the fuel line below |
| trivial target | `tot check trivial.tot` | exit 0, `user=0.01s sys=0.00s`, warm cache, 3 of 3 runs |
| trivial target | `TOT_CACHE_DIR=<fresh> tot check trivial.tot` | exit 0, `user=0.01s sys=0.00s`, cold cache, 3 of 3 runs |

The chains figure confirms SPEC section 6 exactly. SPEC records "a
plain LINEAR chain of about 800 nested boxes (7.2 KB, the
`m4fix-inst-chains` shape) exceeds a 60s budget with no verdict at
all, exit 124". The generated file is 7232 bytes and both verbs report
exit 124 at a 60 second cap. The 60 second completion time of the
n=800 shape is NOT measured. Growth is about 8x per doubling from the
three measured points, so the true cost is above 400 seconds. The plan
does not claim a number it did not run.

## Files

`lib/budget.ml` (new), `lib/budget.mli` (new), `lib/error.ml`,
`lib/check.ml`, `surface/serror.ml`, `surface/run.ml`, `bin/tot.ml`,
`dev/bisect-inst-classes.sh` (new), `dev/gates.sh`, `test/main.ml`,
`test/surface.ml`, `SPEC.md`.

`lib/dune` is NOT touched. `lib/` gains no library dependency. The
budget reads no clock, so it needs neither `unix` nor `Sys`.

## C0. Scope fences, stated as fences

1. The budget covers ELABORATION and TYPE-CHECKING in both verbs. It
   does not cover `Interp` execution. A `run` whose check finishes and
   whose EXECUTION hangs is still the external `timeout`'s job, exactly
   as SPEC decision 13 prescribes. Pin 9 says so, and the Dogfood claim
   that installs drop `timeout` stays retracted.
2. The budget is a cutoff at kernel-node granularity. It is not a
   real-time guarantee. One pathological `Eval.eval` or `Eval.conv`
   call between two poll sites is unbounded by this feature.
3. The budget never applies to the prelude. `surface/bootstrap.ml`
   folds with `Run.default_policy` and passes no budget, so the
   prelude bootstrap runs unlimited by construction.
4. `--check-budget-ms 0` is OFF, and off is the default. Pin 11.
5. Stage C changes no error TEXT at all. Pin P21 pins the missing-main
   line verbatim, `<path>:this file must define a driver main, and it
   does not`, and says "only the exit mapping moves". An earlier draft
   of this section widened the separator to `<path>: ...` for symmetry
   with the missing-file arm. That is dropped. C6.3 records why.

## C1. lib/budget.ml and lib/budget.mli

`Budget.t` is opaque. It holds one driver-supplied function. `lib/`
reads no clock, holds no mutable state, and raises nothing. Pin 8.

```ocaml
(** M5 Stage C (verdict item 2, pin 8): the check budget, as the kernel
    sees it.

    The kernel never asks what time it is.  It asks ONE question, "is
    my budget spent?", and the DRIVER supplies the function that
    answers it.  That split is the whole design:

    - `lib/` keeps its rule that it uses neither `Unix` nor `Sys`
      (`lib/dune` depends on `str` alone, and `lib/interp.ml`'s regex
      comment states the rule).  A clock in the kernel would break it.
    - The poll may be as cheap or as accurate as the installation
      wants.  `bin/tot.ml` throttles its own clock reads behind a
      counter, which is legal in the driver and would not be legal
      here.
    - A test can drive the kernel with a deterministic poll, with no
      clock and no sleep.  `test/main.ml`'s C1 case does exactly that.

    [poll ()] returns [true] when the budget IS spent.  [unlimited]
    answers [false] forever and allocates nothing per call, so the
    default configuration pays one closure call per kernel node and no
    clock read at all. *)
type t = { poll : unit -> bool }

let unlimited : t = { poll = (fun () -> false) }
let of_poll (poll : unit -> bool) : t = { poll }
let exhausted (b : t) : bool = b.poll ()
```

`lib/budget.mli`:

```ocaml
(** M5 Stage C: see budget.ml.  The type is ABSTRACT here, so no module
    outside this one can read the poll, replace it, or compare two
    budgets. *)
type t

val unlimited : t
val of_poll : (unit -> bool) -> t
val exhausted : t -> bool
```

The `.mli` is what makes "opaque" a fact instead of a comment. It is
the second interface file in the repo after `lib/level.mli`, so
SPEC section 6's `.mli` debt line changes text in the same commit
(C11).

## C2. lib/error.ml: `Check_budget`

One nullary constructor. It carries no payload, because the kernel has
nothing to say about a clock it cannot read, and because a payload on
this arm would be rendered on the one path that must stay cheap.

```ocaml
  | Check_budget
      (** M5 Stage C (verdict item 2, pin 8): the driver's check budget
          is spent.  A CUTOFF, not a verdict about the program: the
          same file with a larger budget, or with none, may check
          clean.  Nullary by design.  The kernel knows only that its
          poll said stop;  the driver owns the number of milliseconds
          and prints it. *)
```

Three sites in `lib/error.ml` change, and the compiler names all three:

1. `is_erased_use`'s false arm gains `Check_budget`. This is the round-4
   clamp working as designed. `Check.match_scrut`'s `Zero` fallback
   forgives `Erased_use` alone, so a budget cutoff can never be
   laundered into a successful check by that fallback.
2. `to_string` gains `| Check_budget -> "check budget exhausted"`.
3. `tag` gains `| Check_budget -> "Check_budget"`.

Plus one new predicate, in the shape `is_erased_use` already sets:

```ocaml
(** M5 Stage C: [true] iff [e] is the budget cutoff.  Spelled as an
    exhaustive match, never as [String.equal (tag e) "Check_budget"],
    so a new constructor is a compile error here too and the driver's
    exit-code decision never depends on a display string. *)
let is_check_budget (e : t) : bool =
  match e with
  | Check_budget -> true
  | Unbound_var _ | Unbound_global _ | ... | Inst_depth _ -> false
```

The false arm lists all 33 other constructors, as `is_erased_use`
does. No catch-all.

## C3. lib/check.ml: `ctx.budget` and the poll sites

### C3.1 The field

```ocaml
type ctx = {
  env : Value.t list;
  locals : (string * Quantity.t * Value.t) list;
  size : int;
  budget : Budget.t;
      (** M5 Stage C (pin 8): the driver's cutoff.  Defaults to
          [Budget.unlimited] in [empty_ctx], so every existing caller
          of [empty_ctx] compiles and behaves unchanged. *)
}

let empty_ctx : ctx = { env = []; locals = []; size = 0; budget = Budget.unlimited }

(** M5 Stage C: the root context for one driver invocation. *)
let root_ctx (budget : Budget.t) : ctx = { empty_ctx with budget }
```

`bind` and `bind_def` currently write a full record literal. They
become `{ ctx with ... }` updates, so the budget propagates into every
binder:

```ocaml
let bind (x : string) (q : Quantity.t) (ty : Value.t) (ctx : ctx) : ctx =
  { ctx with env = Value.var ctx.size :: ctx.env;
             locals = (x, q, ty) :: ctx.locals;
             size = ctx.size + 1 }
```

These are the only two record literals of `ctx` in the repo besides
`empty_ctx` (verified: `rg -n '\{ env =' lib/check.ml surface/*.ml
test/*.ml` returns lines 18, 21 and 24 of `lib/check.ml` and nothing
else). Every other construction goes through `empty_ctx`, `bind` or
`bind_def`, so no other call site changes. That is what pin 8 buys.

### C3.2 The poll sites

`check` and `infer` become polling WRAPPERS around their current
bodies. The bodies keep their code and their doc comments, under the
names `check_node` and `infer_node`, inside the same
`let rec ... and ...` group. Every recursive call keeps calling `check`
and `infer`, so every kernel node polls.

```ocaml
(** M5 Stage C (pin 8): one poll per checked node, then the M4 body
    unchanged.  The wrapper, not the body, is what every recursive call
    reaches, so "node granularity" is a property of the call graph and
    not of a list of hand-picked sites. *)
and check (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (tm : Term.t)
    (expected_v : Value.t) : (Term.t, Error.t) result =
  match Budget.exhausted ctx.budget with
  | true -> Error Error.Check_budget
  | false -> check_node globals ctx mode tm expected_v
```

`infer` takes the same two-line wrapper. `build_instance` polls in its
own guard, beside the fuel guard, keeping the `match () with` ladder:

```ocaml
and build_instance ... =
  match () with
  | () when Budget.exhausted ctx.budget -> Error Error.Check_budget
  | () when st.fuel <= 0 -> Error (Error.Inst_depth (pp_goal globals ctx.size st.goal))
  | () -> ( ... unchanged ... )
```

Order matters and is deliberate. The budget arm runs FIRST. A run that
is out of time reports the cutoff, not a fuel exhaustion it reached
only because the operator waited.

Swallow audit, executed. Two sites in `lib/check.ml` discard an error:
`pp_value` at line 28 (`~error:(fun _e -> "<unprintable>")`, on
`Eval.quote` alone, never on a check) and `match_scrut`'s `Zero`
fallback at line 1130, which is already guarded on
`Error.is_erased_use`. Neither can absorb `Check_budget`. No other
`Result.fold` in the file discards an error value.

### C3.3 The public entry points

`define`, `define_prim`, `define_axiom`, `define_instance`,
`declare_ind`, `declare_ind_status` and `define_ind` build their own
context from `empty_ctx`. Each gains one OPTIONAL labelled argument:

```ocaml
let define ?(rec_ = false) ?(partial = false) ?(stamped_ty : Term.t option)
    ?(budget : Budget.t = Budget.unlimited) ... =
  ... let ctx = root_ctx budget in ...
```

An optional argument with a default keeps every existing call site
compiling and behaving exactly as it does today, including all of
`test/main.ml`. Only `surface/run.ml` passes `~budget`.

## C4. lib/check.ml: the class-count factor in `inst_fuel`

Pin 12. `inst_fuel` keeps the round-5 shape and multiplies it by
`1 + class_count globals`.

The repo has no class registry. A `class` item elaborates to an
ordinary inductive (`surface/run.ml:341`, `surface/cache.ml:109`:
"classes are ordinary `Ind`"), so `Global.t` cannot tell a class
inductive from a data one. See the conflict note C12.1. The count comes
from the INSTANCE TABLE instead, which is where `inst_fuel`'s own
round-5 doc comment already says the class count enters ("the per-key
cost, a property of the instance TABLE, which is where the class count
enters, since a K-class table has `2 K`-binder instances").

```ocaml
(** M5 Stage C: the CLASS half of a mangled instance name,
    ["inst$" ^ cls ^ "$" ^ key] (see [resolve_auto]).  [None] for every
    other global.

    Total, and total for a reason that is checkable: a surface
    identifier is letters, digits, underscore and prime
    (`surface/lexer.ml`'s [is_ident_start] / [is_ident_char]), so it
    can hold no '$'.  A mangled name therefore holds exactly two, and
    the class is what lies between them.  The code does not RELY on
    that count.  It takes the LAST '$', so a name with more separators
    still yields a defined answer instead of an exception. *)
let instance_class_of (name : string) : string option =
  let is_mangled =
    String.length name > 5 && String.equal (String.sub name 0 5 (* @total-accessor *)) "inst$"
  in
  match (is_mangled, String.rindex_opt name '$') with
  | false, (None | Some _) -> None
  | true, None -> None
  | true, Some j -> (
      match () with
      | () when j <= 4 -> None
      | () -> Some (String.sub name 5 (j - 5) (* @total-accessor *)))
```

`String.sub name 5 (j - 5)` is total on the arm that takes it: `j` is
an index into `name`, so `j < String.length name`, and the guard gives
`j > 4`, so `5 + (j - 5) = j` is inside the string.

The table walk merges into the fold `inst_fuel` already runs, so the
cost of the factor is zero extra passes over `globals`:

```ocaml
(** M5 Stage C: ONE pass over the table for BOTH numbers the bound
    needs.  M4 folded the whole table per [Term.Auto] to find
    [max_binders];  the class count rides that same fold rather than
    doubling it. *)
let inst_table_stats (globals : Global.t) : int * int =
  let max_binders, classes =
    Global.StringMap.fold
      (fun (name : string) (entry : Global.entry)
           ((acc : int), (seen : unit Global.StringMap.t)) ->
        instance_class_of name
        |> Option.fold
             ~none:(acc, seen)
             ~some:(fun (cls : string) ->
               ( Int.max acc (pi_arity (Global.entry_ty entry)),
                 Global.StringMap.add cls () seen )))
      globals (0, Global.StringMap.empty)
  in
  (max_binders, Global.StringMap.cardinal classes)

let inst_fuel (globals : Global.t) (expected_t : Term.t) : int =
  let max_binders, class_count = inst_table_stats globals in
  let per_key = (2 * max_binders) + 2 in
  let round5 =
    Int.max
      (Int.max 10000 (16 * ((1 + term_depth expected_t) * per_key)))
      (8 * term_size expected_t * per_key)
  in
  (1 + class_count) * round5
```

Note the behavior change inside `max_binders`. M4 tested the prefix
`"inst$"` inline. `instance_class_of` tests the same prefix plus the
presence of a separator, so a global literally named `inst$x` with no
second `$` no longer contributes to `max_binders`. No such global can
exist: `define_instance` is the only writer of the `inst$` namespace
and it always writes both separators.

Overflow. `class_count` is at most the number of globals, `per_key` is
at most twice the widest registered telescope plus 2, and `term_size`
is at most the node count of the query. On the largest shape this plan
measures, K = 61, the product is about 1.9 million against a 62-bit
`int`. The bound stays a number, not a wrap.

What the factor does NOT buy. On the `dev/gen-inst-fuel.py classes K`
shape both the charge and the bound are now about quadratic in K, so
the ratio is about constant and the leaf may move off the end of the
practical search range. That is a measurement, not a theorem. Pin 12
says exactly this, and C7 re-bisects instead of asserting.

## C5. surface/run.ml: carrying the budget

`Run.script` and `Run.item` gain one optional labelled argument:

```ocaml
let rec item ?(budget : Tot_kernel.Budget.t = Tot_kernel.Budget.unlimited)
    ~(exec : bool) ~(policy : policy) (st : state) (it : Syntax.item) : ...
```

`item` passes `~budget` into every `Check.*` entry it calls, and
replaces the two direct `Check.empty_ctx` uses at `surface/run.ml:442`
and `:451` with `Check.root_ctx budget`.

The budget is NOT a field of `Run.policy`. Two reasons, both checked
against the repo. `policy` is a record of installation BOOLEANS, and
three sites build it as a literal (`bin/tot.ml:177`,
`test/surface.ml:431`, `test/surface.ml:1446`); a new field breaks all
three and every future one silently. An optional argument breaks none,
which is the same property pin 8 asks of `ctx`. The prelude guarantee
survives either way: `surface/bootstrap.ml:335` calls
`Run.item ~exec:true ~policy:Run.default_policy` and passes no
`~budget`, so the prelude fold runs unlimited.

## C6. bin/tot.ml: the flag, the reserved code, and the driver decision

### C6.1 `--check-budget-ms N`

`opts` gains `check_budget_ms : int`, default 0. The parser arm mirrors
`--serror-exit`:

```ocaml
  | "--check-budget-ms" :: n :: rest ->
      int_of_string_opt n
      |> Option.fold
           ~none:(Error ("--check-budget-ms expects a non-negative integer, got " ^ n))
           ~some:(fun v ->
             match () with
             | () when v < 0 -> Error ("--check-budget-ms must be 0 or greater, got " ^ n)
             | () -> parse_flags { opts with check_budget_ms = v } rest)
  | [ "--check-budget-ms" ] -> Error "--check-budget-ms expects an integer argument"
```

The clock, and the throttle, live here:

```ocaml
(** M5 Stage C (pin 8): the driver's half of the budget.  CPU seconds,
    from [Sys.time], not wall clock: a checker that is descheduled has
    not spent its budget, and CPU time cannot walk backwards when the
    system clock is set.

    The counter is why the poll is driver-supplied.  A clock read per
    kernel node would show up in the default path's own timing, and the
    default path must stay byte-identical AND fast (PASS-M5C-DETERMINISM).
    One read per 1024 polls bounds the overshoot at 1024 nodes, which is
    far inside the granularity this cutoff promises.  The mutable cell
    is legal here and is not legal in `lib/`, which is pin 8's whole
    point.

    [ms = 0] returns [Budget.unlimited], so the default configuration
    never allocates a counter, never reads a clock and never changes a
    verdict. *)
let budget_of_ms (ms : int) : Tot_kernel.Budget.t =
  match () with
  | () when ms <= 0 -> Tot_kernel.Budget.unlimited
  | () ->
      let deadline = Sys.time () +. (float_of_int ms /. 1000.0) in
      let ticks = ref 0 in
      Tot_kernel.Budget.of_poll (fun () ->
          ticks := !ticks + 1;
          match () with
          | () when not (Int.equal (!ticks land 1023) 0) -> false
          | () -> Float.compare (Sys.time ()) deadline > 0)
```

`Sys.time` is `Stdlib.Sys`, so `bin/` needs no new library. `lib/` still
touches neither `Sys` nor `Unix` (verified: `rg -n 'Sys\.|Unix\.'
lib/*.ml` returns one comment line in `lib/interp.ml` and no code).

WHERE the budget is built is load-bearing. `run_with_prelude` calls
`budget_of_ms` AFTER `Bootstrap.cached_state_of_src` returns, never
before. A warm bootstrap costs about 10 ms of CPU on this machine and a
cold one costs the same to the resolution of the measurement, so a
deadline captured at process start would be spent before the target's
first node under any budget under 10 ms.
`PASS-M5C-BUDGET-QUIET` leg (b) pins it.

The usage string changes, and its twin in `test/surface.ml:407` changes
in the SAME commit. New text, exact, both sites:

```
usage: tot (check|run) [--no-prelude] [--no-axioms] [--serror-exit N] [--check-budget-ms N] [--require-main] FILE | tot prims
```

`PASS-D-USAGE-CHANNEL` matches `^usage: tot ` and stays green.
`test/surface.ml`'s `case_usage_channel` compares the WHOLE line and
would fail without its edit.

### C6.2 Budget exhaustion: reserved exit 3, outside the mapping

Amendment A1 and pin 10. `surface/serror.ml` gains one predicate,
exhaustive, no catch-all:

```ocaml
(** M5 Stage C: [true] iff [e] is the kernel's check-budget cutoff,
    which the driver reports on its own contract and not through
    [--serror-exit]. *)
let is_check_budget (e : t) : bool =
  match e with
  | Kernel { loc = _loc; err } -> Tot_kernel.Error.is_check_budget err
  | Lex _ | Parse _ | Unknown_name _ | Bad_level _ | Main_bad_type _
  | Axioms_disabled _ | Missing_main ->
      false
```

`run_file`'s error branch becomes a three-arm `match () with` ladder,
the house shape for three or more conditions:

```ocaml
         ~error:(fun e ->
           match () with
           | () when Tot_surface.Serror.is_check_budget e ->
               prerr_endline
                 (path ^ ": check budget exhausted (" ^ string_of_int budget_ms ^ " ms)");
               3
           | () when Tot_surface.Serror.is_missing_main e ->
               prerr_endline (path ^ ": " ^ Tot_surface.Serror.to_string e);
               1
           | () ->
               prerr_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
               serror_exit)
```

THE EXACT STDERR LINE, verbatim, one line, on stderr, with stdout left
empty:

```
<path>: check budget exhausted (<N> ms)
```

`<N>` is the CONFIGURED number of milliseconds, not an elapsed
measurement. The line is therefore deterministic for a given
invocation, which is what makes it matchable by a hook and by a gate.
The line takes the DRIVER separator `": "`, the same one
`<path>: no such file` uses (measured), and not the script-error
separator `":"`. This line is NEW, so no pin fixes its bytes and the
choice is free. The missing-main line is the opposite case: pin P21
fixes its bytes at the tight `":"`, and C6.3 says why it must not be
widened to match this one.

Exit 3 is RESERVED for this verdict, and the stderr line is the
discriminator. See conflict note C12.2: `--serror-exit 3` is a shipped,
tested configuration, so the code alone cannot identify a budget
cutoff.

### C6.3 `--require-main` becomes a driver failure

Amendment A3. A mainless target takes the driver contract: one line on
stderr, stdout untouched, the literal exit 1, outside the
`--serror-exit` mapping, exactly like a missing file.

`surface/serror.ml` gains the twin predicate:

```ocaml
let is_missing_main (e : t) : bool =
  match e with
  | Missing_main -> true
  | Lex _ | Parse _ | Unknown_name _ | Bad_level _ | Kernel _ | Main_bad_type _
  | Axioms_disabled _ ->
      false
```

`Serror.Missing_main` itself does not move, and
`Serror.to_string Missing_main` does not change. The surface stays the
authority on the file's content, and only the DRIVER's exit-code
decision changes. `test/surface.ml`'s
`case_require_main_rejects_mainless` runs `Run.script` in process and
keeps passing untouched.

Measured M4 behavior, both verbs, on
`test/fixtures/m4d-nomain.tot`:

| invocation | M4 exit | Stage C exit |
| --- | --- | --- |
| `check --require-main` | 1 | 1 |
| `run --require-main` | 1 | 1 |
| `check --require-main --serror-exit 0` | 0 | 1 |
| `run --require-main --serror-exit 0` | 0 | 1 |

The stderr text does NOT change. Both before and after, byte for byte:

```
M4:       /abs/m4d-nomain.tot:this file must define a driver main, and it does not
Stage C:  /abs/m4d-nomain.tot:this file must define a driver main, and it does not
```

Pin P21 pins that text and says "only the exit mapping moves", so the
tight separator is binding. Writing the new arm with `path ^ ":" ^ ...`
keeps it, and the repo makes that a one-token choice: `bin/tot.ml`
already picks the separator per arm, `path ^ ": " ^ ...` at
`bin/tot.ml:34` for the missing-FILE arm and `path ^ ":" ^ ...` at
`bin/tot.ml:53` for the script-error arm. Neither arm forces the
other's spelling on a new one. Verified 2026-09-02 against the M4-HEAD
binary: `check --require-main` on a mainless file writes
`<path>:this file must define a driver main, and it does not` and exits
1, and a missing file writes `<path>: no such file` and exits 1. Do not
"harmonise" the two. A changed byte here is a behavior change P21
forbids, and it buys nothing that the exit-code move does not already
buy.

`PASS-M4D-REQUIRE-MAIN` matches
`rg -q 'this file must define a driver main'` and requires a nonzero
exit, so it stays green either way. Its comment gains one sentence
naming the new contract.

## C7. The K-leaf re-bisection

Pin 12 requires a re-bisected leaf, a stated upper search bound, a
stated stopping rule, and a gate pinned 20 percent under the measured
leaf. `dev/bisect-inst-classes.sh` makes the rule executable instead of
prose. It prints one line per probe and one verdict line.

THE RULE.

1. Start at `K = 61`, the M4 leaf. Measured on M4 HEAD: `K = 60`
   resolves at exit 0 in 0.32 s and `K = 61` reports `Inst_depth` at
   exit 1 in 0.16 s.
2. DOUBLE: probe 61, 122, 244, 488, in that order.
3. Stop the doubling at the FIRST K whose run reports
   `exceeded its fuel` at exit 1. Then BISECT the half-open interval
   (last resolving K, first rejecting K] by halving until the two
   differ by 1. That pair is the leaf.
4. Stop the doubling early at the first K that breaches ANY ceiling
   below. Then report `NOLEAF<=K_reached` and do not bisect.
5. Any other exit code (124 from the watchdog, 2, or a signal) aborts
   the search and is reported as such. A timeout is not a rejection.

THE UPPER BOUND, and why these numbers.

- `K_max = 488`, three doublings from 61.
- File ceiling 8 MB. Measured: the generator writes 121,645 bytes at
  K = 61 and 117,989 bytes at K = 60, and the size grows about as K
  squared, so K = 488 is about 7.8 MB and K = 976 is about 31 MB. 488
  is the last doubling that fits.
- Wall-clock ceiling 120 s per probe, enforced with `timeout`.
- Both ceilings are checked BEFORE the probe runs, so the search never
  starts a run it has already decided not to afford.

THE GATE PIN. `PASS-M5C-LEAF-MARGIN` pins the largest K that satisfies
all three of:

- `K <= floor(0.8 * leaf)`, the 20 percent margin pin 12 demands;
- the generated file is at most 1 MB;
- the measured run is at most 10 s.

The gate comment records the measured leaf, the pinned K, and which of
the three conditions bound the choice. In the `NOLEAF` case the gate
pins the largest K that RESOLVED inside the search bound, subject to
the same two affordability ceilings, and the comment records
`no leaf at or below K = <K_reached>`. It invents no margin, which is
the mitigation the verdict's own risk list names.

Re-measurement is a standing instruction, not a one-off: the comment
carries the recipe, and any later change to `inst_fuel` or to
`build_instance`'s charge accounting re-runs
`dev/bisect-inst-classes.sh`.

`PASS-M4FIX-INST-CLASSES` keeps its K = 57 fixture and its marker. Its
comment records the M4 leaf of 60/61, which Stage C makes stale, so the
comment gains one dated sentence pointing at the new bisection and its
result. The fixture is not regenerated. A gate that got CHEAPER to pass
is still a gate, and re-generating it would cost the battery time for
no new information.

## C8. Worked examples

Each example names the command, the expected stdout, the expected
stderr and the expected exit code. Examples 1 and 2 are pinned against
the M4 binary and must not change. Examples 3 to 6 are Stage C exit
expectations.

### Example 1: the default path does not move (executed on M4 HEAD)

```
$ tot check test/fixtures/m4fix-inst-chains.tot
data W1 : (0 A : Type 0) -> Type 0
...
$ echo $?
0
```

Measured: `tot run` on the same file exits 0 in under 0.1 s and its
last stdout line is `true`.

### Example 2: today's non-verdict (executed on M4 HEAD)

```
$ python3 dev/gen-inst-chains.py 800 > /tmp/chains800.tot
$ timeout 60 tot check /tmp/chains800.tot ; echo "exit=$?"
exit=124
```

stdout empty. stderr empty. 60.02 s. The same in `run` mode: exit 124,
60.03 s, both channels empty. This is the state Stage C replaces.

### Example 3: the budget fires, with a verdict

```
$ tot check --check-budget-ms 1 /tmp/chains800.tot ; echo "exit=$?"
exit=3
```

stdout: EMPTY. `Run.script` returns its lines only on success, and
`run_file` prints them only on `Ok`, so an error path leaves stdout
untouched. Measured on M4 HEAD for the fuel error and for the
missing-main error: stdout was 0 bytes in both.

stderr, exactly one line:

```
/tmp/chains800.tot: check budget exhausted (1 ms)
```

### Example 4: the budget stays out of the `--serror-exit` mapping

```
$ tot check --check-budget-ms 1 --serror-exit 0 /tmp/chains800.tot ; echo "exit=$?"
exit=3
```

Same single stderr line. A fail-open install cannot turn a
no-verdict into an allow. This is the missing-file precedent, applied
to the second driver-level verdict.

### Example 5: the class-count factor pays the M4 leaf

```
$ python3 dev/gen-inst-fuel.py classes 61 > /tmp/cls61.tot
$ tot run /tmp/cls61.tot | tail -n 1 ; echo "exit=${pipestatus[1]}"
zero
exit=0
```

On M4 HEAD the same command prints nothing on stdout and exits 1 with
the fuel line in Example 9. The flip is measured, not predicted: the
M4 half of it was executed.

### Example 6: a mainless target takes the driver contract

```
$ tot check --require-main --serror-exit 0 test/fixtures/m4d-nomain.tot ; echo "exit=$?"
exit=1
```

stdout empty, and one stderr line:

```
/abs/tot/test/fixtures/m4d-nomain.tot:this file must define a driver main, and it does not
```

On M4 HEAD this exact command exits 0 with that same line, byte for
byte. Only the exit code moves. Executed.

## C9. Negatives, pinned to exact error text

Nine negatives. Each names the invocation, the exact stderr, and the
exit code. Where a line is quoted from M4 HEAD, it was executed.

N1. Fuel, M4 HEAD, `tot run` on `gen-inst-fuel.py classes 61`, exit 1,
stdout empty, stderr exactly:

```
/abs/cls61.tot:446:1: instance resolution for (C0 ((WPair ((WPair Waaaa) Wbbbb)) ((WPair Wcccc) Wdddd))) exceeded its fuel
```

After Stage C this invocation exits 0. The line survives as the
mutation oracle for `PASS-M5C-CLASSES-61`.

N2. Missing file, unchanged by Stage C, both bare and under
`--serror-exit 0`, exit 1, stdout empty, stderr exactly:

```
/abs/does-not-exist.tot: no such file
```

N3. Unknown flag, M4 HEAD, exit 2, stdout empty, stderr exactly:

```
unknown flag: --check-budget-ms
```

After Stage C the flag parses. The line survives as the negative for a
still-unknown flag, and `PASS-D-USAGE-CHANNEL` keeps pinning
`unknown flag: --bogus-flag`.

N4. `--check-budget-ms` with no argument, Stage C, exit 2, stderr
exactly:

```
--check-budget-ms expects an integer argument
```

N5. `--check-budget-ms abc`, Stage C, exit 2, stderr exactly:

```
--check-budget-ms expects a non-negative integer, got abc
```

N6. `--check-budget-ms -5`, Stage C, exit 2, stderr exactly:

```
--check-budget-ms must be 0 or greater, got -5
```

N7. Budget exhaustion, Stage C, exit 3, stderr exactly:

```
/tmp/chains800.tot: check budget exhausted (1 ms)
```

N8. Mainless target under `--require-main`, Stage C, exit 1 under every
`--serror-exit` value, stderr exactly:

```
/abs/m4d-nomain.tot:this file must define a driver main, and it does not
```

N9. An ordinary script error keeps the mapping. `m4d-serror-exit.tot`
under `check --require-main --serror-exit 0`, exit 0, before and after
Stage C, stderr exactly:

```
/abs/test/fixtures/m4d-serror-exit.tot:1:7: unknown name zzz
```

Executed on M4 HEAD: exit 0 with that line under `--serror-exit 0`, and
exit 1 with the same line bare. N9 is the anti-overreach negative. A3
moves the MAINLESS verdict out of the mapping and nothing else.

## C10. Gate C

Seven new markers. None collides: `rg -c 'PASS-M5' dev/gates.sh`
matches nothing at M4 HEAD. Each gate states its mutation and the
observed flip. Every leg runs under `"$watchdog"`, since an unguarded
leg turns a hang into a stall with no FAIL marker.

### PASS-M5C-BUDGET-FIRES

Generate the 800-box chain into a `mktemp -d` scratch, then two legs on
it, both under `"$watchdog" 30`:

- `check --check-budget-ms 1` exits 3, stdout is EMPTY, and stderr
  equals `<scratch>/chains800.tot: check budget exhausted (1 ms)`
  byte for byte;
- the same plus `--serror-exit 0` exits 3 with the identical line.

MUTATION 1: delete the `is_check_budget` arm from `run_file`, so the
cutoff falls through to the ordinary script-error arm. FLIP: leg 2
exits 0 instead of 3, and leg 1's stderr changes to the
`<path>:<loc>: check budget exhausted` shape. The gate fails on both
legs.

MUTATION 2: return `serror_exit` instead of the literal 3 in the budget
arm. FLIP: leg 2 exits 0. Leg 1 still passes, which is exactly why the
`--serror-exit 0` leg exists.

REACH REQUIREMENT, and the honest risk. The 30 s watchdog is not
decoration. The budget can only cut between poll sites, and pin 9 says
so. If this leg reports 124 at build time, the cost of the chains shape
sits inside a single non-polling call and the poll set is not enough.
The remedy is measured, not guessed: record where the time goes, then
either add a poll at the identified entry or record the shape as an
un-cuttable residual in SPEC section 6 and re-target the gate at a
shape the cutoff does reach. Do not widen the gate's oracle to accept
124. A gate that accepts the M4 posture proves nothing.

### PASS-M5C-BUDGET-QUIET

Two legs.

(a) The 100-box chain from `dev/gen-inst-chains.py 100` (measured: 0.65
s, exit 0 on M4 HEAD) under `check --check-budget-ms 60000`, in a
`"$watchdog" 30` leg. Requires exit 0 and stdout byte-identical to the
no-flag run of the same file.

MUTATION: make the driver poll answer `true` unconditionally, that is,
replace the deadline test with `true`. FLIP: leg (a) exits 3.

(b) A trivial one-def target under `check --check-budget-ms 1`.
Requires exit 0 and an empty stderr.

MUTATION: capture the deadline BEFORE the prelude bootstrap, that is,
build the budget in `check_or_run` instead of after
`cached_state_of_src`. FLIP: leg (b) exits 3. Measured margin: the
warm bootstrap costs `user=0.01s` on 3 of 3 runs and the cold bootstrap
costs the same on 3 of 3 runs, so the bootstrap alone is about ten
times a 1 ms budget.

FLAKE CONTROL for leg (b): before the marker is committed, run leg (b)
20 times and require 20 exit-0 results. Record the count in the gate
comment. If any run flakes, raise the leg to `--check-budget-ms 5`,
which keeps a measured 2x margin under the bootstrap cost, and record
the raise and its reason.

### PASS-M5C-DETERMINISM

Corpus, all committed and all fast: `examples/church.tot`,
`examples/guard-classes.tot`,
`test/fixtures/m4fix-inst-small-reach.tot`,
`test/fixtures/m4fix-inst-chains.tot`, plus the scratch 100-box chain
from leg (a) above.

For each file and for each verb, run three ways: no flag,
`--check-budget-ms 0`, and `--check-budget-ms 60000`. Capture stdout,
stderr and the exit code SEPARATELY, from ONE invocation each. Require
all three triples to be byte-identical.

MUTATION 1: default `check_budget_ms` to 1 instead of 0. FLIP: the
no-flag run of the 100-box chain exits 3 while the 60000 run exits 0,
and the triples differ.

MUTATION 2: make `budget_of_ms` treat `ms = 0` as a zero-millisecond
deadline instead of `Budget.unlimited`, that is, change `ms <= 0` to
`ms < 0`. FLIP: the `--check-budget-ms 0` run exits 3 on every corpus
member. This is the leg that pins "0 means off" from pin 11.

The gate compares only the binary against ITSELF, so it needs no
committed golden bytes and it cannot rot when an unrelated stage
changes a printed type.

### PASS-M5C-CLASSES-61

`python3 dev/gen-inst-fuel.py classes 61` into a scratch, then
`run` it under `"$watchdog" 60`. Requires exit 0, exactly one stdout
line equal to `zero`, and NO occurrence of `fuel` anywhere in the
output. The shape of `PASS-M4FIX-INST-CLASSES`, one class higher.

MUTATION: drop the `(1 + class_count)` factor from `inst_fuel`. FLIP:
exit 1 with the N1 line. This flip is not a prediction. It is the
measured M4 HEAD behavior of this exact command: exit 1 in 0.16 s with
that exact line.

### PASS-M5C-LEAF-MARGIN

Runs `dev/bisect-inst-classes.sh`'s recorded pin, not the search. The
search is a development instrument and is far too slow for the battery.
The gate generates the pinned K, runs it under `"$watchdog" 60`, and
requires exit 0, one `zero` line, and no `fuel` in the output. The
comment carries the measured leaf, the pinned K, the binding
constraint, and the re-measurement recipe.

MUTATION: pin the gate at the leaf itself instead of 20 percent under
it. FLIP: the leg fails on the first charge-accounting change that
moves the leaf down by one class, which is what the margin exists to
absorb. A second, immediately checkable mutation: drop the
`(1 + class_count)` factor and the leg fails at exit 1 with the fuel
line, since the pinned K is above the M4 leaf of 60.

### PASS-M5C-REQUIRE-MAIN-DRIVER

`test/fixtures/m4d-nomain.tot`, four legs, all under `"$watchdog" 30`:
`check` and `run`, each bare and under `--serror-exit 0`. Every leg
requires exit 1, an EMPTY stdout, and stderr equal to
`<path>:this file must define a driver main, and it does not` byte for
byte. The separator is a bare `:`, with NO space, which is pin P21's
verbatim text and the M4-HEAD text. A gate that byte-asserts a widened
separator would pin a change P21 forbids.

MUTATION: restore `serror_exit` in the missing-main arm. FLIP: the two
`--serror-exit 0` legs exit 0. Measured: that is exactly the M4 HEAD
behavior of both commands.

### PASS-M5C-REQUIRE-MAIN-OK

Two anti-overreach legs, both under `--require-main --serror-exit 0`
and `"$watchdog" 30`:

- `check examples/guard.tot` exits 0 with an EMPTY stderr. Measured on
  M4 HEAD: exit 0, 371 bytes of stdout, empty stderr, identical to the
  bare run.
- `check test/fixtures/m4d-serror-exit.tot` exits 0 with stderr equal
  to `<path>:1:7: unknown name zzz`. Measured on M4 HEAD: exit 0 with
  that line.

MUTATION: widen the driver arm from `is_missing_main` to every
`Serror`. FLIP: the second leg exits 1 instead of 0. Without this leg
nothing stops A3 from being over-applied to the whole error channel.

### Stage C exit criteria

1. The full battery is green at the Stage B count plus Stage C's seven
   markers, with `GATE-EXIT=0`.
2. `test/main.exe` and `test/surface.exe` both exit 0, including the
   edited `case_usage_channel` and the untouched
   `case_require_main_rejects_mainless`.
3. Every marker above passed at least once with its stated mutation
   applied and observed to flip. Record each flip in
   `dev/M5-BUILD-LOG.md` with the command and the observed exit code.
4. `PASS-M4D-REQUIRE-MAIN`, `PASS-M4D-SERROR-EXIT`,
   `PASS-D-MISSING-FILE-CHANNEL`, `PASS-D-USAGE-CHANNEL`,
   `PASS-M4FIX-INST-CLASSES` and `PASS-M4FIX-INST-WIDE` are all still
   green. These six are the gates Stage C's edits pass closest to.

## C11. SPEC.md edits

Section 2 gains one dated `2026-09-02 (M5, Stage C)` block:

1. **The check budget.** `Budget.t` is opaque and holds a
   driver-supplied `poll : unit -> bool`. `lib/` reads no clock, holds
   no mutable state and raises nothing. `ctx.budget` defaults to
   `Budget.unlimited`, so no existing call site changed.
   `--check-budget-ms N` defaults to 0, which is off, and applies to
   `check` and `run`. The budget covers elaboration and type-checking
   in both verbs. It does not cover `Interp` execution, where decision
   13's external `timeout` stays the belt.
2. **Exit 3 is reserved for budget exhaustion**, outside the
   `--serror-exit` mapping, with one exact stderr line
   `<path>: check budget exhausted (<N> ms)`. Because `exitWith`
   accepts any 0..255 and `--serror-exit 3` is a shipped configuration,
   the LINE, not the code, is the discriminator a hook matches. The
   PreToolUse harness treats codes other than 0 and 2 as non-blocking,
   so the default posture on exhaustion matches the external-timeout
   posture it replaces. An installation that wants fail-closed wraps
   the driver.
3. **The budget is node-granular.** It is a cutoff, not a real-time
   guarantee. One pathological `Eval` or `Conv` call between two poll
   sites is unbounded by it.
4. **`inst_fuel` gains the class-count factor.** The round-5 shape is
   multiplied by `1 + class_count globals`, where the count is the
   number of DISTINCT class components of `inst$` mangled names in the
   table. A class is not a distinguishable kind of global in this
   design, so the count is a property of the INSTANCE TABLE, which is
   where the round-5 comment already places it. The factor is not a
   proof that the leaf is gone: on the `classes K` shape the charge and
   the bound are both about quadratic in K, so the leaf is
   re-measured, never asserted.
5. **The K leaf, re-bisected.** Record the measured leaf, the search
   bound, the stopping rule and the pinned gate value, with the date
   and the binary they were measured on.
6. **`--require-main` is a DRIVER failure.** A mainless target takes
   the driver contract: one stderr line, exit 1, outside the
   `--serror-exit` mapping, like a missing file.

Section 6 edits, three of them:

- The `--require-main` ADVISORY entry is REWRITTEN as retired. Its
  repro is now false and must not survive as a copyable command. The
  M4 text says
  `tot check --require-main --serror-exit 0 ok.tot; echo $?` prints 0.
  Executed on M4 HEAD, it does print 0. After Stage C the same command
  prints 1. The replacement entry states the old behavior, the date it
  changed, the amendment that decided it (A3), and the new repro:
  `printf 'def x : Bool := true\n' > ok.tot; tot check --require-main
  --serror-exit 0 ok.tot; echo $?` prints 1, with one stderr line.
- The `Check.inst_fuel` entry keeps both halves and updates both. The
  REACH half records the new factor and the re-bisected leaf. The TIME
  half records that the check budget now gives a verdict where exit 124
  and two empty channels used to be, and keeps decision 13's external
  `timeout` as the belt for execution and for un-cuttable calls.
- The `.mli` debt line changes from "except `Level`" to "except
  `Level` and `Budget`".

The check-budget line in the "deferred" list ("A driver wrapper
`timeout` suffices for hooks today") is removed, because it is paid.

## C12. Conflict notes, dated

### C12.1 (2026-09-02) Pin 12 names a class count the repo cannot compute

PIN: `inst_fuel` multiplies by `1 + class_count globals`.

REPO: there is no class registry. `surface/run.ml` elaborates a `class`
item into an ordinary inductive, and `surface/cache.ml:109` records the
fact in one line: "classes are ordinary `Ind`". `Global.t` holds no
flag that separates a class inductive from a data one.

RESOLUTION, in this section: `class_count` is the number of DISTINCT
class components of `inst$` mangled names in `globals`. This is a
property of the INSTANCE TABLE, which is where `inst_fuel`'s own
round-5 doc comment already puts the class count. The split is total
and its precondition is checkable: a surface identifier cannot hold a
`$` (`surface/lexer.ml`'s `is_ident_char`), so a mangled name holds
exactly two separators. A class with NO registered instance does not
count, which is correct for a fuel bound: such a class contributes
nothing to any walk.

### C12.2 (2026-09-02) Exit 3 is reserved, and it is also already configurable

PIN and A1: budget exhaustion exits the RESERVED code 3, "the smallest
code outside the shipped verdict set 0/1/2".

REPO: 3 is not free. `--serror-exit 3` is an exercised configuration.
`dev/gates.sh`'s `PASS-M4D-SERROR-EXIT` runs
`check --serror-exit 3` and requires exit 3, and
`test/surface.ml:422` pins the same. An installation may therefore map
ordinary script errors to 3 today.

RESOLUTION, in this section: the code is reserved by CONVENTION for the
default configuration, and the exact stderr line is the discriminator,
which A1 already states and pin 10 already argues from `exitWith`. Both
budget gates assert the LINE and not the code alone, and
`PASS-M5C-BUDGET-FIRES` carries a `--serror-exit 0` leg so a
fall-through into the mapping fails the gate. The SPEC entry states the
collision plainly rather than implying that 3 identifies a budget
cutoff.

### C12.3 (2026-09-02) The verdict's own QUIET leg cannot afford its file

VERDICT: "PASS-M5C-BUDGET-QUIET, the same file at a large budget exits
0".

REPO and MEASUREMENT: the same file is the 800-box chain. Measured, it
exceeds 60 s in both verbs, and its completion time is unmeasured and
above 400 s by extrapolation. Stage D's tiers are FAST=10, MED=30,
SLOW=120 and SUITE=300. A quiet leg on that file would either exceed
the largest tier or spend most of it to prove a negative.

RESOLUTION, in this section: `PASS-M5C-BUDGET-QUIET` leg (a) runs the
SAME generator and the SAME instance table at n=100, measured at 0.65
s, under a 60000 ms budget. It exercises the same poll sites on the
same shape, and its stated mutation flips it. `PASS-M5C-BUDGET-FIRES`
keeps the 800-box file, where the cost is the point. The verdict's
intent, that no false positive hides behind the FIRES leg, is kept. Its
letter, the same file, is not, and the reason is a measurement.
## STAGE D: gates, measurement, dogfood and SPEC

Owner of verdict items 6, 9 and 10, and of design pins 17 and 18.

### Entry state

Stages A, B and C are green.  The M4 walk of 278 `PASS` markers is
intact, plus every marker Stages A to C added.  Do not assume a number
for the entry count.  Run the battery once before you start, record
`dev/gates.sh 2>&1 | rg -c '^PASS'`, and use that number as the Stage D
baseline.  Stage D adds six gates, the six markers the preamble
reserves for this stage, and must not remove a marker.

Facts pinned against the built M4-HEAD binary
`_build/default/bin/tot.exe` on 2026-09-02.  Every number below comes
from a run, not from a reading:

The `P<n>` labels below are PROBE IDs, local to this section.  They are
NOT the preamble's pins, and the two numberings are unrelated: probe
P13 is the live escape bypass, while pin P13 is the JSON escaper rule.
Cite a row here as `probe P<n>` and a normative pin as `pin P<n>` or
`pin <n>`.  Stage D implements pins P17 and P18 and audits all 23.

| Probe | Command | Result |
|---|---|---|
| P1 | `rg -c '\$watchdog [0-9]' dev/gates.sh` | no output, exit 1 (the losing oracle, vacuous) |
| P2 | `rg -c '"\$watchdog" [0-9]+' dev/gates.sh` | `89`, exit 0 |
| P3 | `rg -o '"\$watchdog" [0-9]+' dev/gates.sh \| sort \| uniq -c` | 30:46, 15:26, 5:8, 10:4, 60:2, 300:1, 20:1, 120:1 |
| P6 | `rg -c '\$watchdog' dev/gates.sh` | `91`, exit 0 |
| P55 | `rg -c '"\$watchdog" [0-9]+$' dev/gates.sh` | no output, exit 1 |
| P56 | `rg -c '"\$watchdog" [0-9]+ ' dev/gates.sh` | `86`, exit 0 |
| P11 | deny payload through `examples/guard.tot` | envelope below, exit 2 |
| P13 | `"command":"\u0067rep foo"` | empty stdout, exit 0 (live bypass) |
| P51 | `"command":"grep \u0001x"` | empty stdout, exit 0 (live bypass) |
| P39 | `deny "a\rb"` | reason bytes `" a \r b "`, a RAW 0x0D inside the JSON string |
| P40 | `deny "a\tb"` | reason bytes `" a \ t b "`, escaped |
| P25/P26 | `timeout` = GNU coreutils 9.11; `timeout 1 tail -f /dev/null` | exit 124 |
| P27 | `typeset -F SECONDS` and `zmodload zsh/datetime` | both work |
| P48 | `stringLength "abcdef"`, `stringSlice "abcdef" 1 3` | `6`, `some "bcd"` |
| P50 | `stringSlice "abc" 0 99` | `none` |
| P52 | `stringSlice "ab" (intSub 2 5) 3` | `none` |
| P54 | `rg -c 'house rule: use rg instead' dev/gates.sh` | `1` |

### D0. Conflict notes (dated, binding on this section)

**D0-1 (2026-09-02).  The corpus is 86 legs, not 91 sites.**  The
verdict says "The real corpus is 91 `"$watchdog" N` sites across 8
distinct values".  The repo disagrees on the count and agrees on the
value set.  The accounting is:

- 91 lines mention `$watchdog` at all (P6).
- 89 of those match the corrected oracle `"\$watchdog" [0-9]+` (P2).
- 2 lines mention `$watchdog` with no numeral: line 22
  (`if [ -z "$watchdog" ]; then`) and line 451 (a comment that reads
  `"$watchdog", never bare timeout`).
- Of the 89, only 86 are EXECUTABLE legs (P56: a numeral followed by a
  space and a command).  The other 3 are comment prose at lines 923,
  939 and 965, each of the form `under "$watchdog" 30,` or
  `under "$watchdog" 30.` (P55 proves none of the 89 sits at
  end of line, so the 3 differ by a following `,` or `.`).

Resolution: this section works on 86 legs plus 3 comment mentions.  The
3 comments become prose ("under the MED tier") because pin 17 forbids
any numeral after `"$watchdog"`, and the pin is verified by a regex
that does not know a comment from a leg.  The 8 distinct values in the
verdict are correct and unchanged.

**D0-2 (2026-09-02).  An exit-status assertion on ABSENCE is
satisfiable by deletion.**  Pin 17 asks for one oracle: no numeric
watchdog literal survives, asserted on exit status.  A gate that only
asserts absence goes green when every leg is deleted, when the file is
truncated, and when `$watchdog` is renamed.  Resolution:
`PASS-M5D-TIERS` keeps pin 17's oracle EXACTLY as pin 17 states it, and
adds two POSITIVE counts beside it, so the gate pins the whole
population and not just the empty half.  The pin is implemented, not
weakened;  the additions can only make it harder to pass.

**D0-3 (2026-09-02).  `PASS-M4FIX-INST-BRANCHING` is documented as the
last leg in the file.**  Its own comment says "this is the LAST leg in
the file, so no marker at all sits downstream of it" (M4 fixes round 5,
opus R5-4), and the reason given is that it is the most expensive and
most timing-sensitive leg, so nothing cheap may depend on it.
Appending Stage D legs after it would falsify a dated claim in the
repo.  Resolution: every Stage D leg is inserted BEFORE the
`PASS-M4FIX-INST-BRANCHING` block.  The branching leg stays last and
its comment stays true.

---

### D1. `dev/gates.sh`: the tier block

Insert immediately after the watchdog probe (after the `fi` that closes
the `if [ -z "$watchdog" ]` guard at line 26) and before the first use
at line 36.  The tiers must exist before any leg names one.

    # M5 Stage D (design pin 17): named watchdog tiers. Every leg names
    # a tier. No numeric watchdog literal survives in this file, which
    # PASS-M5D-TIERS asserts on EXIT STATUS.
    #
    # A tier is a HANG ceiling, not a performance budget. Pin 9 keeps
    # the external timeout as the belt over one pathological Eval or
    # Conv call; the tiers are the same belt inside the battery. A leg
    # that creeps from 1s to 9s stays green at FAST and shows up in the
    # measurement log instead, which is what gate_timed is for.
    #
    #   FAST  a leg that must finish well under a second.
    #   MED   a leg that runs the CLI more than once, or over a fixture.
    #   SLOW  a perf leg with a measured runtime in SPEC section 6.
    #   SUITE one of the two test executables.
    #
    # BITE_S is NOT a leg budget. It is the calibration constant that
    # PASS-M5D-TIER-BITES uses to prove the watchdog machinery still
    # cuts at the value a tier names. Nothing else may use it.
    FAST=10
    MED=30
    SLOW=120
    SUITE=300
    BITE_S=1

**The mapping rule.**  Every leg moves to the SMALLEST tier greater
than or equal to its current literal.  The rule is one line, it is
mechanical, and it has one property that matters: no budget shrinks, so
re-tiering cannot turn a green leg red by squeezing it.  The table,
from P3 minus the 3 comment mentions of D0-1:

| Current | Legs | Tier | New value | Direction |
|---|---|---|---|---|
| 5 | 8 | FAST | 10 | grows |
| 10 | 4 | FAST | 10 | unchanged |
| 15 | 26 | MED | 30 | grows |
| 20 | 1 | MED | 30 | grows |
| 30 | 43 | MED | 30 | unchanged |
| 60 | 2 | SLOW | 120 | grows |
| 120 | 1 | SLOW | 120 | unchanged |
| 300 | 1 | SUITE | 300 | unchanged |

Totals: 86 legs.  FAST 12, MED 70, SLOW 3, SUITE 1.  37 legs get a
larger ceiling, 49 keep the same one, and no leg gets a smaller one.
The surface suite at line 38 carries 120 today and lands in SLOW, which
is the same number;  it needs no exception, and you must not give it
one, because an exception makes the rule unauditable.

**The rewrite recipe.**  Use `sd`, never `sed`.  Include the trailing
space in each pattern, and work in descending numeric order.  Both
belts matter: without the trailing space, `"$watchdog" 30` rewrites the
`30` inside `"$watchdog" 300` and produces `"$watchdog" "$MED"0`.

    sd '"\$watchdog" 300 ' '"$watchdog" "$SUITE" ' dev/gates.sh
    sd '"\$watchdog" 120 ' '"$watchdog" "$SLOW" '  dev/gates.sh
    sd '"\$watchdog" 60 '  '"$watchdog" "$SLOW" '  dev/gates.sh
    sd '"\$watchdog" 30 '  '"$watchdog" "$MED" '   dev/gates.sh
    sd '"\$watchdog" 20 '  '"$watchdog" "$MED" '   dev/gates.sh
    sd '"\$watchdog" 15 '  '"$watchdog" "$MED" '   dev/gates.sh
    sd '"\$watchdog" 10 '  '"$watchdog" "$FAST" '  dev/gates.sh
    sd '"\$watchdog" 5 '   '"$watchdog" "$FAST" '  dev/gates.sh

That covers 86 legs.  Edit the 3 comment mentions by hand (lines 923,
939 and 965 at M4 HEAD).  Replace `under "$watchdog" 30` with
`under the MED tier` in each.  Do not leave a numeral there.

**Verification, immediately after the rewrite.**  Expected output is
stated for each command.

    rg -q '"\$watchdog" [0-9]' dev/gates.sh          # exit 1, no match
    rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh   # 86
    rg -c '"\$watchdog" "\$BITE_S"' dev/gates.sh                  # 2

At M4 HEAD the same three commands print `89` (exit 0), nothing (exit
1) and nothing (exit 1).  That inversion IS the stage's evidence.

**The self-match trap, stated once.**  `PASS-M5D-TIERS` greps the file
it lives in.  Its own pattern text is written inside single quotes with
`\$`, so the bytes on the gate's own line are `"`, `\`, `$`,
`watchdog`.  The regex `"\$watchdog"` needs `"`, `$`, `watchdog`, and
the backslash breaks the match at that offset.  The only other `"` on
the line is followed by ` [`, which matches neither pattern.  So no
assertion line self-matches, and the counts stay honest.  Note the
opposite case: `rg -c '\$watchdog'` DOES match the gate's own pattern
lines, because that regex has no leading `"` to anchor it.  Never use
the bare `$watchdog` count as an oracle.

Note why the losing oracle was vacuous, so nobody re-derives it: the
real sites carry QUOTES, `"$watchdog" 30`, and the pattern
`\$watchdog [0-9]` demands a space straight after `$watchdog`, where
the file has `"`.  It matched nothing at M4 HEAD and it would have
passed on day one.

---

### D2. `dev/gates.sh`: `gate_timed` and the measurement log

Insert directly under the tier block.

    # M5 Stage D (verdict item 6): per-leg measurement. gate_timed runs
    # ONE leg under a named tier, records elapsed wall time, and
    # forwards the leg's own stdout and exit code unchanged. It adds no
    # policy: a leg that was green stays green, and a leg that was red
    # stays red with the same output.
    #
    # Wrap ONLY a leg that already merges stderr into stdout (2>&1).
    # The prelude legs split the two channels on purpose and must stay
    # unwrapped; wrapping one would merge a channel the B4 channel rule
    # keeps apart.
    typeset -F SECONDS
    GATE_LOG="${TOT_GATE_LOG:-${TMPDIR:-/tmp}/tot-gate-measure.log}"
    : > "$GATE_LOG" || exit 9
    gate_timed() {
      local tier="$1"
      local name="$2"
      shift 2
      local t0=$SECONDS
      local out
      out=$("$watchdog" "$tier" "$@" 2>&1)
      local code=$?
      printf 'MEASURE %s tier=%s elapsed=%.3f exit=%d\n' \
        "$name" "$tier" "$((SECONDS - t0))" "$code" >> "$GATE_LOG"
      printf '%s' "$out"
      return $code
    }

`typeset -F SECONDS` and `zmodload zsh/datetime` both work on this
machine (P27).  `SECONDS` is enough;  do not pull in the datetime
module for one subtraction.  BSD `date` has no `%N`, so a `date`-based
timer is not portable here and must not be used.

The log lives outside the repo by default.  It goes to `$TMPDIR`, and
`TOT_GATE_LOG` overrides the path.  Do not write it under `$ROOT`.  A
past round already paid for gate output that polluted the tree.

Echo the path once at the end of the battery, next to the `GATE-EXIT`
line, so the operator can read the measurements after a green run.

**Which legs to wrap.**  A PERF leg is a leg whose tier is SLOW or
SUITE, or a leg that runs an instance-resolution fixture
(`m4fix-inst-*`, and the Stage B and Stage C generators' output).  At
M4 HEAD that floor is 11 legs, verified on 2026-09-02:

- the nine `PASS-M4FIX-INST-*` legs, from
  `rg -o 'PASS-M4FIX-INST[A-Z0-9-]*' dev/gates.sh | sort -u`:
  `BINDERS`, `BRANCHING`, `CHAINS`, `CLASSES`, `MEMO-KEY`,
  `SMALL-REACH`, `SPEC16`, `TWOCLASS`, `WIDE`.
- the two suite legs, at lines 36 and 38 (`SUITE-KERNEL`,
  `SUITE-SURFACE`).

Stages B and C add their own perf legs.  Enumerate the final set with
the rule above once A, B and C have landed, wrap each one, and write
the resulting name list into the gate as a literal array.  The leg NAME
passed to `gate_timed` is the marker name without the `PASS-` prefix.

**The hole-anchor line.**  D5's script appends one more line to the
same log, in the same run:

    ANCHORS total=T expected-type-only=E argument-driven=A neither=N

---

### D3. `examples/guard.tot`: echo the offending command

Today the deny reason is a constant.  P11 pins it exactly:

    {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed"}}

Stage D appends the command that was blocked.  The command is data the
caller controls, so it is bounded before it goes into the message, and
it goes out through the JSON escaper Stage A installed.

Add two helpers above `decide`.  Both are total, both match
exhaustively, and neither uses a catch-all arm:

    -- M5 Stage D: unwrap a bounds-checked slice. stringSlice is
    -- partial by type (Option String) and total by behaviour: it
    -- returns none for any out-of-range window (probe P50: 
    -- stringSlice "abc" 0 99 = none; probe P52: a negative start is
    -- none too), so this default is unreachable for the windows
    -- elideAt builds and is a backstop, not a fallback.
    def orEmpty : Option String -> String :=
      fun o => match o with | none => "" | some s => s end

    -- Bound the echoed command at 2000 bytes, the house elision width
    -- (M4 fixes round 5). intCompare returns Ordering, so all three
    -- arms are named and no arm is a wildcard.
    def elideAt : Int -> String -> String :=
      fun n s =>
        match intCompare (stringLength s) n with
        | gt => stringConcat (orEmpty (stringSlice s 0 n)) "... (elided)"
        | eq => s
        | lt => s
        end

Change the one `deny` in `decide` to:

    | true =>
        deny (stringConcat
                "house rule: use rg instead of grep and sd instead of sed (command: "
                (stringConcat (elideAt 2000 (jsonGetStringOr ti "command" "")) ")"))

Echo the WHOLE command, not the first token.  The first token is
already whitespace-free, so a first-token echo could never carry a
control byte and `PASS-M5D-GUARD-ECHO` would have nothing to prove.
The whole command is also the thing the operator wants to read.

**Blast radius, measured.**  Exactly one line in the repo pins the old
reason string outside the guard itself (P54):
`dev/gates.sh:393`, the `want=` line.  `test/` does not pin it.
`dev/M3-PLAN.md` mentions it as history and must not be edited.  Update
line 393 to the new expected envelope, and check
`rg -l 'house rule: use rg instead'` still lists exactly
`dev/gates.sh`, `examples/guard.tot` and `dev/M3-PLAN.md`.

---

### D4. `examples/guard-rewrap.tot`: the third real hook

The user's own hooks are on disk.  Two files carry this convention:
`/Users/oobi/.claude/hooks/map-over-rewrap-guard.py` (Edit, Write and
MultiEdit) and `/Users/oobi/.claude/hooks/map-over-rewrap-bash-guard.py`
(Bash).  The Bash one is the one to port, because `tot`'s PreToolUse
payload handling already reads `tool_input.command`.

Read the Python guard's own statement of the rule before you write the
port.  It denies a NET-NEW `let x = <expr>?;` whose block immediately
returns `Ok(<uses x>)`, and it takes four conditions together: a bare
`let` binding ending in `?`, `Ok(` as the very next tokens, the `Ok(_)`
as a block TAIL, and the bound name genuinely used inside the `Ok(_)`.
It reconstructs the post-edit file and compares scrubbed occurrence
counts, and it fails open on anything it cannot reconstruct.

**Scope the port honestly.**  `tot` has no Rust lexer, no comment and
string scrubber, and no pre-image reader.  A faithful port is a
milestone, not a slot.  The port implements a NARROW, high-precision
subset and says so in its own header:

- Only `tool_name = "Bash"`.
- Only a command whose text mentions `.rs`.
- Only the LINE-PAIR shape: some line L1 whose first token is `let`
  and whose last token ends with `?;`, immediately followed by a
  non-empty line L2 whose first token starts with `Ok(`.
- Everything else allows.

That is criteria 1 and 2 of the Python guard, on raw text.  Criteria 3
and 4, the scrubber, and the net-new comparison are NOT ported.  The
port is therefore louder than the Python guard on a pre-existing
rewrap tail inside a heredoc, and quieter than it on a single-line
tail.  Record both directions in SPEC section 6.

**The file.**  `examples/guard-rewrap.tot`, with a `tot run` shebang
like the other two guards.  Helpers, all total:

    def startsWith : String -> String -> Bool :=
      fun p s =>
        match stringSlice s 0 (stringLength p) with
        | none => false
        | some pre => stringEq pre p
        end

    def endsWith : String -> String -> Bool :=
      fun q s =>
        match stringSlice s (intSub (stringLength s) (stringLength q))
                            (stringLength q) with
        | none => false
        | some suf => stringEq suf q
        end

`endsWith` needs no length pre-check.  A suffix longer than the string
makes the start negative, and `stringSlice` returns `none` for a
negative start (P52).  The `none` arm is the answer, not an error path.

    def rec dropEmpty : List String -> List String :=
      fun xs =>
        match xs with
        | nil => nil String
        | cons h t =>
            match stringEq (firstToken h) "" with
            | true => dropEmpty t
            | false => cons String h (dropEmpty t)
            end
        end

    def rec hasRewrapPair : List String -> Bool :=
      fun ls =>
        match ls with
        | nil => false
        | cons l1 rest =>
            match rest with
            | nil => false
            | cons l2 t2 =>
                match andb (stringEq (firstToken l1) "let")
                           (andb (endsWith "?;" (lastToken l1))
                                 (startsWith "Ok(" (firstToken l2))) with
                | true => true
                | false => hasRewrapPair rest
                end
            end
        end

Both recursions shrink the list argument, so `rec_arg` first-fit picks
the list and `Totality.guard` accepts them.  `andb` and `orb` are in
the prelude;  `firstNonEmpty`, `lastOr`, `splitEach` and `firstToken`
are copied from `examples/guard.tot`, and `lastToken` is
`lastOr "" (splitEach ...)` over the same four IFS separators.

**The duplication is deliberate.**  There are no modules, and the
global namespace is flat (SPEC section 6).  Moving the tokenizer into
`stdlib/prelude.tot` would change the prelude, the bootstrap and the
cache, which is Stage A or Stage B scope, not Stage D scope.  Copy the
helpers, and record the duplication as a new debt in D7.

**`main`** mirrors `examples/guard.tot`, including the fail-open on a
parse failure, so the two guards keep one posture:

    def decideRewrap : Json -> Verdict :=
      fun payload =>
        match jsonGetString payload "tool_name" with
        | none => allow
        | some name =>
            match stringEq name "Bash" with
            | false => allow
            | true =>
                match jsonGet payload "tool_input" with
                | none => allow
                | some ti => rewrapVerdict (jsonGetStringOr ti "command" "")
                end
            end
        end

where `rewrapVerdict` tests `stringContains cmd ".rs"` first, then
`hasRewrapPair (dropEmpty (stringSplit cmd "\n"))`, and denies with
the echoed, elided command in the same shape D3 gives `guard.tot`.

**Installation is the user's step, not the plan's.**  Do not edit
`~/.claude/settings.json`, and do not edit any file outside the repo.
Print the install snippet in `README.md` next to the other two guards,
and leave the decision to the user.

---

### D5. `dev/hole-anchors.py`: the hole-anchor measurement

The verdict cuts holes and buys a MEASUREMENT instead.  The measurement
must give M6 a number from a real corpus, so the methodology has to be
stated, mechanical and auditable.

**Why the measurement is static.**  There is no hole syntax to test
against.  The counterfactual ("replace this argument with `_` and see
whether it checks") cannot be executed at M5.  So the number is
produced by a classifier over the source, and its honesty rests on the
classifier being reviewable, not on a run.  Say that in SPEC.

**Corpus.**  `stdlib/prelude.tot` (176 lines) and `examples/*.tot`
(149 lines), 325 lines in total on 2026-09-02.  Test fixtures are
excluded: they are written to stress the kernel, not to be read, so
they would bias the ratio.

**Step 1, the head table.**  Parse each declaration in the corpus.  A
head is POLYMORPHIC when its type opens with one or more
`(0 X : Type L) ->` binders, or when it is a `data` or `class` former
with such parameters.  Record `head -> k`, where k is the count of
leading erased `Type` binders.  At M4 HEAD, `rg -c '\(0 [A-Za-z]+ : Type'
stdlib/prelude.tot` matches 27 lines, so the table is small enough to
print in full and read.

**Step 2, the anchors.**  For every application of a head in the table,
the first k arguments are ANCHORS.  A parenthesized argument counts as
one anchor, for example `liftIO (Option Json) ...`.

**Step 3, the classification.**  Every anchor lands in exactly one
bucket:

- **E, expected-type-only.**  The site is in CHECK position under a
  known expected type, and the head's result type applies the former to
  the anchor variables in rigid positions.  First-order matching of the
  expected type against the result type determines the anchor with no
  other information.  Examples in the corpus today: `nil String` where
  `List String` is expected, `none Json`, `pureIO Verdict allow`.
- **A, argument-driven.**  The anchor is fixed only by a later
  explicit argument's inferred type, not by the expected type.
  Example: `append String xs ys`.  These need bidirectional application
  checking, which `infer`'s App arm (lib/check.ml:770-779) does not do:
  it consumes one argument at a time and evaluates the stamped argument
  to instantiate the codomain, and `check` has no App arm at all.
- **N, neither.**  Erased proof arguments, class keys, and anchors at a
  head applied in infer position.

**Step 4, the output.**  One line to the measurement log:

    ANCHORS total=T expected-type-only=E argument-driven=A neither=N

plus the full site list (file, line, head, argument index, bucket) to
stdout, so a reviewer can audit every classification by hand.

**Step 5, the independent count.**  The script also accepts
`--count-sites`.  Under that flag it walks the SAME corpus by the SAME
site rule, prints ONE integer and nothing else, and does no
classification at all.  `PASS-M5D-HOLE-ANCHORS` compares that integer
against the `total=` field.  Write the two walks so that neither can
reuse the other's result: the count path must not call the classifier
and must not read the log.  A count derived from the classification
would agree with it by construction and would prove nothing.

**Where the number lands.**  SPEC section 6's holes debt (D7, item 6)
carries E and T, the date, the exact invocation, and one honesty
clause: E is an UPPER bound on what an expected-type-only hole pass
would solve, because the classifier does not run the checker.
`PASS-M5D-MEASURE-LOG` asserts that the E in the log equals the E
written in SPEC, so the two cannot drift.

---

### D6. `SPEC.md` section 2: a dated entry per pin (pin 18)

Pin P18 requires all 23 pins in section 2 as dated entries.  The
preamble's section 4 renumbers the verdict's 18 pins and its 5
ratification amendments into one list, P1 to P23, across FIVE stages,
so the older "18 pins across the four stages" count is stale and must
not be used as an audit target.  Each stage writes its own pins in its
own commit.  Stage D writes its two and then AUDITS the whole set,
including Stage E's own block, which Stage E appends after Stage D
lands.

Stage D's own entries, in the `2026-09-02 (M5, Stage D)` block:

1. **Named watchdog tiers (pin 17).**  `FAST=10`, `MED=30`, `SLOW=120`,
   `SUITE=300`, plus the non-leg calibration constant `BITE_S=1`.  The
   mapping rule is "smallest tier greater than or equal to the current
   literal", so 37 of 86 legs get a larger ceiling and none gets a
   smaller one.  A tier is a HANG ceiling, not a performance budget;
   pin 9 keeps the external `timeout` as the belt, and the measurement
   log is what detects a leg that creeps.  The oracle is
   `rg -q '"\$watchdog" [0-9]' dev/gates.sh` asserted on EXIT STATUS,
   with two positive counts beside it (86 tier uses, 2 calibration
   uses), because an absence assertion alone is satisfied by deletion.
   The corpus record is corrected here: 91 lines mention `$watchdog`,
   89 match the corrected oracle, and 86 of those are executable legs.
2. **The deny message echoes the blocked command.**  The echo is
   attacker-controlled data inside a JSON string, so it is bounded at
   2000 bytes with `stringSlice` and it depends on Stage A's C0
   escaper.  `PASS-M5D-GUARD-ECHO` is the executable statement of that
   dependency: the emitted envelope must re-parse through the same
   binary to the same bytes.
3. **The third guard is a NARROW port.**  `examples/guard-rewrap.tot`
   implements criteria 1 and 2 of the Python Bash guard on raw text.
   The scrubber, the block-tail test, the used-name test and the
   net-new comparison are not ported.  The guard fails open on
   everything it does not recognise, matching the other two guards.
4. **The hole-anchor measurement.**  Methodology, corpus, the E/A/N
   buckets, and the upper-bound clause from D5.

**The audit.**  After the entries are written, run:

    rg -c '^- 2026-09-02 \(M5' SPEC.md

and check the count against the 23 pins plus the stage headers.  Then
read the Stage A pin entries, the Stage B ones and the Stage C ones,
and confirm each pin number appears once.  Pin P22 is not written yet:
Stage E appends its own dated block after Stage D lands, so record P22
as OWED BY STAGE E rather than as missing.  This is a CHECK, not a
gate.  The preamble reserves six Stage D markers, none of them for a
documentation audit, and inventing a seventh gate to hold one would put
a name in the battery that no mutation can flip.

---

### D7. `SPEC.md` section 6: rewritten with post-M5 numbers (item 10)

Anchor every edit by LEADING TEXT, not by line number.  Stages A to C
add section 2 entries above section 6, so the line numbers below move.
The anchors are as they read at M4 HEAD.

**Retire (rewrite the entry to open with `Retired (M5 Stage X)`):**

1. `The JSON conformance suite (no \uXXXX escapes, partial serializer
   escaping; a pre-M4 debt, restated).`  Retired by Stage A.  Name
   `Json_escape.string`, the surrogate-pair rule, and the `none` on a
   lone surrogate or a short escape.  Name `PASS-M5A-BYPASS` and
   `PASS-M5A-ENVELOPE-VALID`.
2. `The check-budget flag (a pre-M4 debt, restated). A driver wrapper
   timeout suffices for hooks today.`  Retired by Stage C.  State the
   reserved exit 3 (amendment A1), the one exact stderr line as the
   load-bearing discriminator, and pin 9's clause that the external
   `timeout` STAYS.  The old sentence claims the wrapper "suffices";
   the replacement must not repeat that, because the budget is a
   node-granular cutoff and not a real-time guarantee.
3. `--require-main is ADVISORY under a fail-open exit mapping.`
   Retired by amendment A3: a mainless target now takes the driver
   contract, one stderr line and exit 1, outside the `--serror-exit`
   mapping.  Delete the `printf 'def x : Bool := true\n' > ok.tot`
   repro, because it no longer prints 0.  Replace it with the new one.

**Restate with post-M5 numbers:**

4. `What remains after that memo is a TERM SIZE limit, not a resolution
   one.`  Keep the analysis, replace every number.  The M4 numbers are
   nesting 20 at 19.6s (16.8s of it the re-check), nesting 16 at 1.03s,
   nesting 12 at 0.064s.  Put Stage B's measured numbers in their
   place, add the `term_size` figure that `PASS-M5B-SHARE-SIZE` pins,
   and say that the fix is the local `let`-nest and NOT hash-consing
   (pin 1: physical identity does not survive `Marshal`).  Keep the
   sentence that `Term.t` has no sharing only if it is still true after
   Stage B;  pin 1 says `Term.t` is unchanged, so it is.
5. `Check.inst_fuel is a backstop with MEASURED margins, and neither an
   unreachable one nor a time budget.`  Both halves change.  Reach:
   replace the K = 60 resolves / K = 61 rejects leaf with the
   re-bisected leaf from Stage C, state the upper search bound and the
   stopping rule, and pin the gate 20 percent under the new leaf (pin
   12).  Drop nothing about the recipe;  the gate comment still carries
   it.  Time: the 41.4s doubling type and the 800-box chain at exit 124
   are now cut by `--check-budget-ms`, so restate them as the
   MEASUREMENT that sized the budget, with the new exit 3 and the exact
   stderr line.
6. `No holes, again (a pre-M4 debt too): every proof names its type
   arguments. Measure after M4; holes stay an M5 candidate.`  The
   "measure after M4" instruction is discharged here.  Restate with
   D5's E and T, the invocation, the three buckets, and the upper-bound
   clause.  Name the two structural reasons from the verdict:
   `infer`'s App arm consumes one argument at a time
   (lib/check.ml:770-779) and `check` has no App arm.
7. `Well-founded recursion, now UNBLOCKED by indexed families (M4 Stage
   A): an M5 candidate, not scheduled.`  Restate with amendment A4's
   spike: the experimental flag, the pinned divergence witness, the
   measurements, and the statement that the default path is
   byte-identical.  Keep proposal 1's evidence: `Acc` checks today at
   exit 0, and only `Totality.guard` rejects `accRec`.
8. `Nested inductives and the Json cons-cell migration to
   jarr : List Json -> Json (a pre-M4 debt, restated): waits for the M5
   positivity door.`  The door stays SHUT.  Correct the recorded
   REASON (pin 14): it is the MUTUAL gap, because `Totality.mentions`
   tests only the family's own name, so a recursive pair reads as
   non-self-recursive.  It is NOT a nesting gap.  The judge's probe
   refutes the nesting claim: `Totality.mentions` recurses into both
   halves of `App` (lib/totality.ml:52), so `jarr : List Json -> Json`
   gives `self_rec = true`.  Say that the losing text was wrong and
   that this entry corrects it.
9. `The Frozen emptiness claim stays UNPROVEN.`  Restate, and TIE it to
   well-founded recursion: on every def M5 can construct, `Frozen` is
   dead code, so promoting it to a definition-time error buys nothing
   until `Acc` values appear at erased quantity.

**Leave unchanged, restated verbatim** (the verdict cut each one
explicitly, so do not silently reword them): the bounded regex engine,
the prim catalog's unverified trust boundary, and `Div` typing gives
provenance rather than a termination proof.

**New debts created by M5, Stage D:**

10. **Tier slack.**  37 of 86 legs now carry a larger hang ceiling: 8
    move 5 to 10, 26 move 15 to 30, 1 moves 20 to 30, and 2 move 60 to
    120.  A leg that doubles in runtime can stay green where it used to
    go red.  The compensating instrument is the measurement log, which
    records elapsed time per perf leg on every run, and
    `PASS-M5B-SHARE-SIZE`, which is machine-independent and survives
    any later tier relaxation.
11. **The rewrap guard is a narrow port** (D4).  Both directions of the
    difference are recorded: louder on a pre-existing tail in a
    heredoc, quieter on a single-line tail.
12. **The echoed command is bounded at 2000 bytes** and the elision
    marker `... (elided)` is prose, not a machine-readable flag.  A
    consumer cannot tell an elided command from one that ends in that
    literal text.
13. **Guard helper duplication.**  `firstNonEmpty`, `lastOr`,
    `splitEach` and `firstToken` now exist in two example files,
    because there are no modules.  A fix to one is a fix to neither
    until somebody copies it.  The prelude is the natural home and the
    move is a cache-format change, so it waits.

---

### D8. Stage D fixtures

- `test/fixtures/m5d-echo-readback.tot` (gate `PASS-M5D-GUARD-ECHO`).
  Reads one envelope on stdin, parses it with the same `jsonParse` the
  guard uses, extracts `hookSpecificOutput.permissionDecisionReason`,
  and re-emits it as its OWN deny.  Every failure path allows, so a
  broken round trip shows up as exit 0 with empty stdout:

      def main : IO Verdict :=
        let* String Verdict raw := readStdin in
        let* (Option Json) Verdict parsed := liftIO (Option Json) (jsonParse raw) in
        match parsed with
        | none => pureIO Verdict allow
        | some env =>
            match jsonGet env "hookSpecificOutput" with
            | none => pureIO Verdict allow
            | some inner =>
                match jsonGetString inner "permissionDecisionReason" with
                | none => pureIO Verdict allow
                | some reason => pureIO Verdict (deny reason)
                end
            end
        end

- `test/fixtures/m5d-rewrap-deny.json` and `m5d-rewrap-allow.json`,
  driven by `PASS-M5D-REWRAP-GUARD` in D9.  D4 describes the guard;  it
  holds no gate leg, and the fixtures are gated in D9, not in D4.  Two
  PreToolUse payloads, each with `tool_name` `"Bash"` and a
  `tool_input.command` that is a heredoc writing a `.rs` file.  The
  deny one carries `let a = g()?;` followed by `Ok(h(a))`.  The allow
  one carries `g().map(h)`.
- The chains fixture that Stage C commits for `PASS-M5C-BUDGET-FIRES`
  is REUSED by `PASS-M5D-TIER-BITES`.  Do not generate a second copy.
  Read the path out of the Stage C section and use the same file.

---

### D9. Gate D

Insert every leg BEFORE the `PASS-M4FIX-INST-BRANCHING` block (D0-3).

#### PASS-M5D-TIERS

Three assertions on `dev/gates.sh`, all in one leg.

    rg -q '"\$watchdog" [0-9]' "$ROOT/dev/gates.sh"; nolit=$?
    tiers=$(rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' "$ROOT/dev/gates.sh")
    bites=$(rg -c '"\$watchdog" "\$BITE_S"' "$ROOT/dev/gates.sh")
    { [ "$nolit" -eq 1 ] && [ "$tiers" -eq <N> ] && [ "$bites" -eq 2 ] \
      && [ -s "$ROOT/dev/gates.sh" ]; } \
      && echo PASS-M5D-TIERS \
      || { echo "FAIL-M5D-TIERS (nolit=$nolit tiers=$tiers bites=$bites)"; exit 1; }

`<N>` is 86 plus the legs Stages A, B and C added.  Compute it after
those stages land and write it in as a literal, with the recipe in the
gate comment.

`<N>` is a LIVE literal, not a frozen one, because the assertion is
`-eq` and every later tier use raises the true count.  Stage E adds six
tier uses, so Stage E must raise this literal by six in the same edit
that adds its legs.  Write that obligation into the gate comment in
these words, so the next stage cannot miss it: "Any stage that adds a
`"$watchdog" "$FAST|MED|SLOW|SUITE"` use raises N by the number it
added, measured with
`rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before
and after, and records both numbers in `dev/M5-BUILD-LOG.md`."  Do not
soften the assertion to `-ge` instead: `-ge` would stop M2's
delete-one-leg mutation from flipping, and that mutation is the reason
this count exists.

State in the comment: pin 17's oracle is the FIRST assertion, exactly
as the pin words it.  The other two exist because an assertion on
absence is satisfied by an empty file (D0-2).

Mutation proofs.

- M1: restore one `"$watchdog" 30` literal at any leg.  `nolit` goes 0.
  Observed flip: PASS to `FAIL-M5D-TIERS (nolit=0 ...)`.  This is the
  verdict's own stated mutation.
- M2: delete one tier leg.  `tiers` goes to `<N>-1`.  Observed flip:
  PASS to FAIL.  M1 alone cannot catch this, which is why M2 exists.
- M3: rename `BITE_S` to a numeral in the calibration legs.  `bites`
  goes 0 AND `nolit` goes 0.  Observed flip: PASS to FAIL on two
  counts.

Non-vacuity at plan time: at M4 HEAD the first assertion FAILS
(`nolit=0`, 89 matching lines) and the second and third both FAIL
(`tiers` and `bites` are empty).  The gate cannot pass before the work.

#### PASS-M5D-MEASURE-LOG

Four assertions against `$GATE_LOG`, run after every perf leg.

    lines=$(rg -c '^MEASURE [A-Za-z0-9-]+ tier=[0-9]+ elapsed=[0-9]+\.[0-9]{3} exit=[0-9]+$' "$GATE_LOG")
    names=$(rg -o '^MEASURE [A-Za-z0-9-]+' "$GATE_LOG" | rg -o '[A-Za-z0-9-]+$' | sort | tr '\n' ' ')
    logE=$(rg -o 'expected-type-only=[0-9]+' "$GATE_LOG")
    specE=$(rg -o 'expected-type-only=[0-9]+' "$ROOT/SPEC.md")

Assert: `lines` equals the pinned leg count `<M>`;  `names` equals the
pinned, sorted name list;  `logE` is non-empty and equals `specE`;  and
every `exit=` field on a leg that must pass reads `exit=0`.

The name list is a literal in the gate.  Do NOT derive it by counting
`gate_timed` call sites in the same file: deleting one wrapper would
drop both the call-site count and the log count together, and the
assertion would stay green.  That is the vacuity trap this gate is
built to avoid, and the verdict's own stated mutation is exactly the
one it would miss.

Mutation proofs.

- M1: delete one `gate_timed` wrapper, so that leg runs bare.  The log
  loses one line and one name.  Observed flip: `lines` = `<M>-1` and
  the name set differs, PASS to FAIL.  This is the verdict's stated
  mutation, and it flips only because the expected list is a literal.
- M2: change `expected-type-only=E` in SPEC by one.  Observed flip:
  `logE` and `specE` differ, PASS to FAIL.  This is what stops the
  SPEC number drifting away from the script that produced it.
- M3: make `gate_timed` print `elapsed=%d` instead of `%.3f`.  The
  schema regex stops matching, `lines` goes 0.  Observed flip: PASS to
  FAIL.

Non-vacuity at plan time: `$GATE_LOG` does not exist at M4 HEAD, so
`lines` is empty and the leg fails.

#### PASS-M5D-TIER-BITES

Two legs.  Leg (a) proves a REAL tot leg gets cut at a tier value.  Leg
(b) proves the tier ladder is ordered and that the watchdog still bites
at the value a tier names.

    # (a) the Stage C chains fixture under FAST. It exceeds 60s with no
    # verdict (SPEC section 6), so 10s is a certain cut.
    out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
          "$ROOT"/test/fixtures/<stage-c-chains-800>.tot 2>&1); a=$?
    # (b) calibration. BITE_S must cut a 3s sleeper and FAST must not.
    "$watchdog" "$BITE_S" sleep 3; b=$?
    "$watchdog" "$FAST" sleep 3;   c=$?
    { [ "$a" -eq 124 ] && [ "$b" -eq 124 ] && [ "$c" -eq 0 ] \
      && [ "$BITE_S" -lt "$FAST" ] && [ "$FAST" -lt "$MED" ] \
      && [ "$MED" -lt "$SLOW" ] && [ "$SLOW" -le "$SUITE" ]; } \
      && echo PASS-M5D-TIER-BITES \
      || { echo "FAIL-M5D-TIER-BITES (a=$a b=$b c=$c)"; exit 1; }

Exit 124 on expiry is pinned by probe P26 against the `timeout` on this
machine, GNU coreutils 9.11 at `/opt/homebrew/bin/timeout`.  Leg cost
is about 14 seconds: 10 for (a), 1 and 3 for (b).  That cost is the
price of a real cut plus a cheap calibration, and it is stated here so
nobody trims it silently.

Mutation proofs.

- M1: raise the calibration tier from `BITE_S` to `FAST`.  The 3s
  sleeper finishes.  Observed flip: `b` goes 124 to 0, PASS to
  `FAIL-M5D-TIER-BITES (a=124 b=0 c=0)`.  This is the verdict's stated
  mutation ("raise it to SLOW"), applied at the cheapest tier where it
  actually flips.
- M2: set `BITE_S=5`.  Same flip through the ordering assertion as
  well.
- M3, stated because it does NOT flip, so nobody proposes it: raising
  leg (a) from `FAST` to `SLOW` does not change the result.  The chains
  fixture exceeds 120s too, so `a` stays 124 and the leg only gets 110
  seconds slower.  Leg (b) exists precisely because leg (a) cannot be
  mutation-proved on its own.

Non-vacuity at plan time: the Stage C chains fixture does not exist at
M4 HEAD, so this gate cannot run before Stage C.  That is the stated
entry dependency, not a hidden one.

#### PASS-M5D-GUARD-ECHO

The round trip.  The guard emits an envelope, and the SAME binary
parses it back and re-emits it.  Byte identity is the assertion.

    payload='{"tool_name":"Bash","tool_input":{"command":"grep \u0001x"}}'
    e1=$(printf '%s' "$payload" | "$watchdog" "$FAST" \
         "$ROOT"/_build/default/bin/tot.exe run "$ROOT"/examples/guard.tot); c1=$?
    e2=$(printf '%s' "$e1" | "$watchdog" "$FAST" \
         "$ROOT"/_build/default/bin/tot.exe run \
         "$ROOT"/test/fixtures/m5d-echo-readback.tot); c2=$?
    printf '%s' "$e1" | LC_ALL=C rg -q $'\x01'; raw=$?
    { [ "$c1" -eq 2 ] && [ "$c2" -eq 2 ] && [ "$e2" = "$e1" ] \
      && printf '%s' "$e1" | rg -q 'u0001' && [ "$raw" -eq 1 ]; } \
      && echo PASS-M5D-GUARD-ECHO \
      || { printf '%s\n' "$e1"; echo "FAIL-M5D-GUARD-ECHO (c1=$c1 c2=$c2 raw=$raw)"; exit 1; }

Four things are asserted at once.  The guard denies (`c1` = 2).  The
readback denies with the same reason, so the envelope re-parses
(`c2` = 2 and `e2` = `e1`).  The control byte is ESCAPED in the wire
form.  No raw byte 0x01 survives on the wire (`raw` = 1, meaning rg
found nothing).

The escape assertion searches for `u0001`, with no backslash.  The wire
form carries the six bytes `\u0001`, and a backslash inside an rg
pattern inside a shell string is three escaping layers over one
assertion.  The five characters `u0001` could in principle come from
the echoed command instead of from an escape, because the command is
the only variable part of the envelope.  The raw-byte check closes that
hole: the gate fixes the payload, so the only 0x01 in play is the one
the payload carries, and `raw` = 1 says no 0x01 reached the wire.  The
two assertions together say the byte went out escaped and only escaped.
Keep both.  Neither is sufficient alone.

Mutation proofs.

- M1: revert `render_verdict` (surface/effect.ml:375) to
  `Pp.escape_string`.  Probe P39 pins the current behaviour of that
  escaper: `deny "a\rb"` emits a RAW 0x0D inside the JSON string, while
  `deny "a\tb"` emits `\t`.  So `Pp.escape_string` passes C0 bytes
  other than newline and tab straight through.  Observed flip: `raw`
  goes 1 to 0, the `u0001` assertion fails, and the readback's
  `jsonParse` rejects the raw control byte and returns `none`, so
  `c2` goes 2 to 0 and `e2` goes empty.  PASS to FAIL on four counts.
- M2: drop the `(command: ...)` echo from `examples/guard.tot`.  The
  reason no longer carries the byte.  Observed flip: the `u0001`
  assertion fails, PASS to FAIL.
- M3: make `m5d-echo-readback.tot` return `allow` on a successful
  parse.  Observed flip: `c2` goes 2 to 0 and `e2` goes empty, PASS to
  FAIL.

Non-vacuity at plan time, pinned by probe P51: at M4 HEAD the same
payload produces EMPTY stdout and exit 0, because `lib/interp.ml`
rejects the `\u0001` escape, the parse fails, and `guard.tot` fails
open to allow.  So `c1` is 0 today and the gate is red until Stage A
lands the parser and Stage D lands the echo.

#### PASS-M5D-REWRAP-GUARD

Scope item 10's third hook is a DELIVERABLE, so it carries its own
marker.  Do not fold it into `PASS-M5D-GUARD-ECHO`: one marker covering
two guards cannot say which guard broke, and `guard-rewrap.tot` can
regress to allow-everything without moving a single byte of
`guard.tot`'s envelope.

Two payload legs, a deny and an allow, plus one liveness assertion.

    deny=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe run \
           "$ROOT"/examples/guard-rewrap.tot \
           < "$ROOT"/test/fixtures/m5d-rewrap-deny.json); rd=$?
    allow=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe run \
            "$ROOT"/examples/guard-rewrap.tot \
            < "$ROOT"/test/fixtures/m5d-rewrap-allow.json); ra=$?
    chk=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
          "$ROOT"/examples/guard-rewrap.tot 2>&1); rc=$?
    { [ "$rd" -eq 2 ] && [ "$ra" -eq 0 ] && [ -z "$allow" ] && [ "$rc" -eq 0 ] \
      && printf '%s' "$deny" | rg -q '"permissionDecision":"deny"' \
      && printf '%s' "$deny" | rg -q 'let a = h\(\)\?;'; } \
      && echo PASS-M5D-REWRAP-GUARD \
      || { printf '%s\n%s\n%s\n' "$deny" "$allow" "$chk"; \
           echo "FAIL-M5D-REWRAP-GUARD (rd=$rd ra=$ra rc=$rc)"; exit 1; }

Four things are asserted at once.  The rewrap payload DENIES at exit 2
with a deny envelope.  Its echoed reason carries the offending `let`
line, so the leg cannot pass on a guard that denies everything with a
constant reason.  The allow payload allows at exit 0 with EMPTY stdout,
so the leg cannot pass on a guard that denies everything.  The guard
itself still type-checks, so a broken port fails loudly rather than
quietly at run time.

The deny fixture is W5's payload, so the echoed line the assertion
looks for is `let a = h()?;`.  Keep the fixture and the assertion in
step: if the fixture's `let` line changes, the pattern changes with it.

Mutation proofs.

- M1: make `rewrapVerdict` return `allow` unconditionally.  Observed
  flip: `rd` goes 2 to 0 and `deny` goes empty, PASS to FAIL.  This is
  the deliverable's own regression.
- M2: drop the `stringContains cmd ".rs"` test, so every command
  matches.  The deny leg stays green and the ALLOW leg flips: `ra` goes
  0 to 2 and `allow` stops being empty, PASS to FAIL.  M1 alone cannot
  catch this, which is why the allow leg exists.
- M3: drop the echo from the deny reason, keeping the deny.  Observed
  flip: the `let a = h\(\)\?;` assertion fails, PASS to FAIL.

Non-vacuity at plan time: `examples/guard-rewrap.tot` does not exist at
M4 HEAD, so `rc` is 1 and both runs fail.  The gate cannot pass before
the work.

#### PASS-M5D-HOLE-ANCHORS

Scope item 11's measurement is a DELIVERABLE, so it carries its own
marker.  `PASS-M5D-MEASURE-LOG` asserts that the log's `E` equals
SPEC's `E`, which stops the two DRIFTING but says nothing about whether
the measurement RAN or whether its four numbers are consistent.  Both
could be absent together, or wrong together, and that leg would stay
green.

    anchors=$(rg -o '^ANCHORS total=[0-9]+ expected-type-only=[0-9]+ argument-driven=[0-9]+ neither=[0-9]+$' "$GATE_LOG")
    at=$(printf '%s' "$anchors" | rg -o 'total=[0-9]+'              | rg -o '[0-9]+')
    ae=$(printf '%s' "$anchors" | rg -o 'expected-type-only=[0-9]+' | rg -o '[0-9]+')
    aa=$(printf '%s' "$anchors" | rg -o 'argument-driven=[0-9]+'    | rg -o '[0-9]+')
    an=$(printf '%s' "$anchors" | rg -o 'neither=[0-9]+'            | rg -o '[0-9]+')
    sites=$("$watchdog" "$MED" python3 "$ROOT"/dev/hole-anchors.py --count-sites)
    { [ -n "$anchors" ] && [ "$at" -gt 0 ] \
      && [ "$((ae + aa + an))" -eq "$at" ] && [ "$at" -eq "$sites" ]; } \
      && echo PASS-M5D-HOLE-ANCHORS \
      || { printf '%s\n' "$anchors"; \
           echo "FAIL-M5D-HOLE-ANCHORS (t=$at e=$ae a=$aa n=$an sites=$sites)"; exit 1; }

Four things are asserted at once.  The ANCHORS line EXISTS and matches
its schema, so a battery that never reached D5's script fails.  The
corpus is non-empty, so an empty corpus cannot report a vacuous zero.
The three buckets SUM to the total, so a classifier that silently drops
a site fails.  The total equals a site count the classifier produces
independently, so a classifier that drops a site from the buckets AND
the total together still fails.

`dev/hole-anchors.py --count-sites` prints one integer and nothing
else.  It walks the same corpus by the same rule and does NOT classify,
so it is an independent count and not the same number read twice.  That
independence is the point: a single derived number would be exactly the
vacuity trap `PASS-M5D-MEASURE-LOG`'s own note describes.

Mutation proofs.

- M1: drop the ANCHORS line from D5's output.  Observed flip: `anchors`
  is empty, PASS to FAIL.
- M2: classify one site into no bucket, leaving `total` alone.  The sum
  check fails, PASS to FAIL.  M1 cannot catch this.
- M3: drop one site from the corpus walk in the CLASSIFIER only.  The
  sum and the total move together, so M2's check stays green, and the
  `sites` comparison fails.  PASS to FAIL.  This is the leg that makes
  the independent count worth its cost.

Non-vacuity at plan time: `dev/hole-anchors.py` and `$GATE_LOG` do not
exist at M4 HEAD, so `anchors` is empty and the leg fails.

---

### D10. Worked examples

**W1.  The tier oracle inverts.**

Before, at M4 HEAD:

    $ rg -c '"\$watchdog" [0-9]+' dev/gates.sh
    89
    $ echo $?
    0
    $ rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh
    $ echo $?
    1

After Stage D:

    $ rg -c '"\$watchdog" [0-9]+' dev/gates.sh
    $ echo $?
    1
    $ rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh
    86
    $ echo $?
    0

The bare mention count does not move: `rg -c '\$watchdog' dev/gates.sh`
prints 91 before, and more after, because the gate's own assertion
lines mention it.  That is why it is not an oracle (D1).

**W2.  The deny message, before and after.**

Before (probe P11, exit 2):

    {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed"}}

After, for `{"tool_name":"Bash","tool_input":{"command":"grep foo"}}`
(exit 2):

    {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep foo)"}}

**W3.  The round trip with a control byte.**

Input payload, with the six literal bytes `\u0001` inside the JSON
string:

    {"tool_name":"Bash","tool_input":{"command":"grep \u0001x"}}

`e1` (exit 2), where `\u0001` on the wire is again six literal bytes:

    {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"house rule: use rg instead of grep and sd instead of sed (command: grep \u0001x)"}}

`e2` is byte-identical to `e1`, and its exit code is 2.  At M4 HEAD the
same input gives empty stdout and exit 0 (P51).

**W4.  The measurement log after a green battery.**

    MEASURE SUITE-KERNEL tier=300 elapsed=17.412 exit=0
    MEASURE SUITE-SURFACE tier=120 elapsed=1.088 exit=0
    ...
    MEASURE M4FIX-INST-BRANCHING tier=120 elapsed=0.970 exit=0
    ANCHORS total=<T> expected-type-only=<E> argument-driven=<A> neither=<N>

Elapsed values are machine-dependent and are NOT asserted.  The gate
asserts the line count, the name set, the schema and the exit fields.

**W5.  Guard-rewrap on a heredoc payload.**

    {"tool_name":"Bash","tool_input":{"command":"cat > f.rs <<'EOF'\nfn g() -> Result<u8, E> {\n  let a = h()?;\n  Ok(k(a))\n}\nEOF"}}

denies with exit 2 and echoes the command.  The same payload with
`h().map(k)` in place of the two lines allows with empty stdout and
exit 0.

---

### D11. Negatives, pinned to exact error text

Each string below came out of `_build/default/bin/tot.exe` on
2026-09-02.  Do not paraphrase them.

**N1.  `stringSlice` returns `Option String`, not `String`.**  Writing
`stringSlice s 0 n` where a `String` is wanted:

    /path/to/file.tot:1:1: type mismatch: expected String, found (Option String)

exit 1.  This is why `orEmpty` exists in D3.  If the build hits this
line, the fix is to unwrap, never to change the helper's type.

**N2.  A `Verdict` where an `IO Verdict` is wanted.**  Writing
`def main : IO Verdict := match ... with | true => deny "x" | false => allow end`
without `pureIO`:

    /path/to/file.tot:1:1: type mismatch: expected (IO Verdict), found Verdict

exit 1.

**N3.  An unknown source escape.**  The lexer accepts `\n`, `\t`, `\r`,
`\\` and `\"` only (surface/lexer.ml:72-79).  Writing `deny "a\qb"`:

    /path/to/file.tot:1:49: lex error: unknown escape \q

exit 1.  A guard that wants a literal control byte in a source string
must use one of the accepted escapes.  The Stage D fixtures put the
control byte in the JSON PAYLOAD, not in tot source, for exactly this
reason.

**N4.  A bounds-violating slice is `none`, not an error.**
`stringSlice "abc" 0 99` evaluates to `none` (P50) and
`stringSlice "ab" (intSub 2 5) 3` evaluates to `none` (P52).  Neither
raises and neither fails to check.  So `endsWith` needs no length
guard, and a `none` arm is the answer rather than an error path.

**N5.  The losing tier oracle.**  `rg -c '\$watchdog [0-9]' dev/gates.sh`
prints nothing and exits 1 at M4 HEAD (P1).  If the gate ever shows
that pattern, the gate is vacuous and must be rewritten to the quoted
form.

---

### D12. Stage D exit checklist

1. `rg -q '"\$watchdog" [0-9]' dev/gates.sh` exits 1.
2. `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` equals
   the pinned `<N>`, and `rg -c '"\$watchdog" "\$BITE_S"'` equals 2.
3. The four tiers and `BITE_S` are each defined exactly once.
4. `$GATE_LOG` holds `<M>` MEASURE lines plus one ANCHORS line, and its
   `expected-type-only` number equals SPEC's.
5. All SIX `PASS-M5D-*` markers appear, and they are exactly the six
   the preamble reserves: TIERS, MEASURE-LOG, TIER-BITES, GUARD-ECHO,
   REWRAP-GUARD, HOLE-ANCHORS.  Scope items 10 and 11 each ship with
   their own marker;  neither is gated only by another leg.
6. `examples/guard.tot`, `examples/guard-classes.tot` and
   `examples/guard-rewrap.tot` each check and run through their own
   shebang.
7. `dev/gates.sh:393`'s `want=` line carries the new envelope, and
   `rg -l 'house rule: use rg instead'` lists exactly three files.
8. `rg -c '^- 2026-09-02 \(M5' SPEC.md` accounts for all 23 pins, P1 to
   P23.  Stages A to D own 22 of them at this point;  pin P22 lands
   with Stage E's own dated block, so audit P1 to P21 and P23 here and
   record P22 as OWED BY STAGE E rather than as missing.
9. Section 6 carries the nine retire-or-restate edits of D7 and the
   four new debts.
10. The full battery is green.  Report `rg -c '^PASS'` with its
    decomposition against the Stage D entry baseline, and confirm the
    278 M4 markers are all still present by name.
11. `PASS-M4FIX-INST-BRANCHING` is still the last leg in the file.
12. Do not commit.  Do not stage.  This is the preamble's ground rule
    and it binds every stage, Stage A and Stage B included.  Report
    `git status --porcelain` showing your edits UNSTAGED.  Do not edit
    anything outside `/Users/oobi/Documents/tot`, and specifically do
    not edit `~/.claude/settings.json` to install the third guard.
    Print the snippet and let the user install it.
## STAGE E (SPIKE): well-founded recursion behind `--experimental-wf`

Amendment A4 of the ratified M5 design verdict (2026-09-02) adds this
stage.  It is a SPIKE.  It ships MEASUREMENTS and SPEC notes.  It does
not ship a feature.

Goal: put one prototype totality rule behind one experimental driver
flag, run the panel's evidence against it, and write down three numbers
that let M6 size well-founded recursion.  The default path does not
change.  The prototype rule is never reachable without the flag.

Non-goal: a correct well-founded recursion rule.  The prototype below is
KNOWN to be too permissive.  Measuring how permissive it is, on real
shapes, is the deliverable.

Entry: Stages A, B, C and D green.  The M4 walk of 278 PASS plus every
marker Stages A to D add stays green at Stage E exit.  Stage E adds two
kernel test cases and three gate markers.  Stage E removes nothing.

Files: `lib/totality.ml`, `lib/check.ml`, `surface/run.ml`, `bin/tot.ml`,
`test/main.ml`, `test/fixtures/`, `dev/gen-m5e-transcript.sh`,
`dev/m5e-default-transcript.txt`, `dev/gates.sh`, `dev/M5-BUILD-LOG.md`,
`SPEC.md`.

Not touched: `surface/cache.ml`.  `Cache.format_version` does NOT move.
The prelude is folded through `Run.default_policy` (see `surface/run.ml`
line 426 and its comment), so the prelude always elaborates at the
shipped rule, and no flag can enter the cache key.

### E0. Probe log (M4 HEAD binary, 2026-09-02)

Every claim below about CURRENT behavior comes from
`/Users/oobi/Documents/tot/_build/default/bin/tot.exe` at M4 HEAD, with
`TOT_PRELUDE=/Users/oobi/Documents/tot/stdlib/prelude.tot`.  23 probes
ran.  The load-bearing results:

| Probe | Input | Result |
| --- | --- | --- |
| P1 | `Acc` declaration alone, `check` | exit 0, two pinned lines |
| P2 | `Acc` + `accRec`, `check` | exit 1, `... accRec failed the structural termination guard` |
| P3 | panel witness, `check` | exit 1, `... bad failed the structural termination guard` |
| P4 | `data T : Type 0 := \| mk : (Nat -> T) -> T` alone | exit 0 |
| P5 | `bad2` (variable scrutinee, `g zero`) | exit 1, same guard message |
| P6 | `accRec` with `(0 a : Acc A R x)` | exit 1, `erased variable a used at runtime` |
| P7 | `Lt` as an indexed family passed as `R` | exit 1, type mismatch (see conflict C2) |
| P8 | `check --experimental-wf` | exit 2, `unknown flag: --experimental-wf` |
| Q2 | `Acc` + `LtNat` def family + `accZero` | exit 0, four pinned lines |
| Q6 | `bad3` (`bad3 (mk g)`) | exit 1, same guard message |
| R1 | full worked example with `axiom accRec` | exit 0, five pinned lines |
| R2 | full worked example with `def rec accRec` | exit 1, `:5:1:` guard message |
| R4 | witness stderr channel | stdout 0 bytes, stderr 134 bytes, exit 1 |

The verdict's own claim holds exactly: `Acc` checks today, and only
`Totality.guard` rejects `accRec`.

The `P<n>` labels in the table above are PROBE IDs, local to this
section.  They are not the preamble's pins.  Cite a pin as `pin P<n>`
and a row here as `probe P<n>`.

One spelling trap, measured on 2026-09-02.  A `data` header MUST carry
its universe annotation.  The verdict writes the witness as
`data T := | mk : (Nat -> T) -> T` (verdict line 54);  run literally,
that gives `parse error: expected ':', found ':='` and exit 1, so it
never reaches the guard.  Probe P4 above and every fixture in this
section use the annotated spelling `data T : Type 0 := ...`.  Do not
copy the verdict's text into a file.

### E1. The flag

`--experimental-wf`, driver level, default off.  Today the driver rejects
it (probe P8): `unknown flag: --experimental-wf`, exit 2.

`bin/tot.ml`:

1. `opts` gains one field:

```ocaml
  experimental_wf : bool;
      (** M5 Stage E (SPIKE): run the PROTOTYPE accessibility clause in
          [Totality] instead of the shipped structural rule.  Default
          false.  The prototype is known to be too permissive; it exists
          to be measured, not to be relied on. *)
```

2. `default_opts` sets `experimental_wf = false`.
3. `parse_flags` gains one arm, beside `--require-main`:

```ocaml
  | "--experimental-wf" :: rest -> parse_flags { opts with experimental_wf = true } rest
```

4. `usage` gains ` [--experimental-wf]` after ` [--require-main]`.
5. `dispatch` maps the bool to the kernel value ONCE:

```ocaml
    {
      Tot_surface.Run.no_axioms = opts.no_axioms;
      require_main = opts.require_main;
      wf_rule =
        (if opts.experimental_wf then Tot_kernel.Totality.Structural_wf
         else Tot_kernel.Totality.Structural);
    }
```

`surface/run.ml` (`open Tot_kernel` is already at line 6):

6. `policy` gains `wf_rule : Totality.rule`.
7. `default_policy` sets `wf_rule = Totality.Structural`.  The prelude
   bootstrap uses `default_policy`, so a prelude `def rec` is never
   checked under the prototype.
8. The `IDef` arm at line 217 passes it through:

```ocaml
          (Check.define ~rec_ ~partial ~rule:policy.wf_rule st.globals ~name ~reducible
             ~ty:ty_t ~def:def_t)
```

`~rule` is REQUIRED, not optional.  A required labelled argument makes
the compiler enumerate every call site, so no site can pick up a silent
default.  `Check.define_instance`'s internal `define` call passes
`~rule:Totality.Structural` literally: an instance body is never a
`def rec`, so the prototype must not be reachable from it.

### E2. The prototype rule

`lib/totality.ml` gains one sum type and one flag-gated clause.  Nothing
else in the module changes.

```ocaml
(** M5 Stage E (SPIKE): which totality rule [guard] runs.  [Structural]
    is the shipped M2 rule, byte for byte.  [Structural_wf] adds the
    PROTOTYPE accessibility clause and is reachable only through
    --experimental-wf.  The prototype admits shapes the shipped rule
    rejects; SPEC section 2's Stage E entry records which ones. *)
type rule =
  | Structural
  | Structural_wf
```

`guard` becomes `guard ~(rule : rule) ~(recname : string) (body : Term.t)`
and threads `rule` to `passes`.  `passes` changes in exactly one place,
inside `guarded_call` (today at `lib/totality.ml` lines 82 to 94).  The
shipped arm keeps its text:

```ocaml
  let guarded_call (st : status list) (args : Term.t list) : bool =
    List.nth_opt args k
    |> Option.fold ~none:false ~some:(fun a ->
           match a with
           | Term.Var ix -> smaller_at st ix
           | Term.App (_, _, _) -> (
               (* M5 Stage E (SPIKE): the accessibility clause.  A call
                  whose argument k applies a match-bound field of the
                  scrutinee is the accRec shape.  Reachable only at
                  [Structural_wf]. *)
               match rule with
               | Structural -> false
               | Structural_wf -> (
                   let head, _sub = spine a [] in
                   match head with
                   | Term.Var ix -> smaller_at st ix
                   | Term.Univ _ | Term.Auto
                   | Term.Pi (_, _, _, _)
                   | Term.Lam (_, _, _)
                   | Term.App (_, _, _)
                   | Term.Let (_, _, _, _)
                   | Term.Ann (_, _)
                   | Term.Global _ | Term.Match _ | Term.Lit _ ->
                       false))
           | Term.Univ _ | Term.Auto
           | Term.Pi (_, _, _, _)
           | Term.Lam (_, _, _)
           | Term.Let (_, _, _, _)
           | Term.Ann (_, _)
           | Term.Global _ | Term.Match _ | Term.Lit _ ->
               false)
```

Every match stays exhaustive.  No arm is a catch-all.  No exception is
raised.  `spine` is the module's own total walk.  At `Structural` the
`App` arm returns `false` after one constructor comparison, which is the
shipped answer.

THE PRECONDITION THAT STAYS.  `passes` computes `scrut_special` at lines
125 to 136 today.  A match branch binder becomes `Smaller` only when the
scrutinee is a variable already marked `Principal` or `Smaller`.  That
test is what separates `accRec` from the panel witness.  The prototype
does NOT relax it.  Amendment A4 calls the typed rule "one missing
precondition away from admitting divergence"; this is that precondition,
and gate `PASS-M5E-WITNESS-REJECTED` pins it.

### E3. Fixtures

`test/fixtures/m5e-acc.tot`, byte for byte (probe R2 pins its current
verdict at line 5, column 1):

```
data Acc (0 A : Type 0) (0 R : A -> A -> Type 0) : A -> Type 0 :=
  | acc : (x : A) -> ((y : A) -> R y x -> Acc A R y) -> Acc A R x
reducible def LtNat : Nat -> Nat -> Type 0 :=
  fun m n => match n with | zero => Empty | succ p => Unit end
def rec accRec : (0 A : Type 0) -> (0 R : A -> A -> Type 0) ->
    (0 P : A -> Type 0) ->
    ((x : A) -> ((y : A) -> R y x -> P y) -> P x) ->
    (x : A) -> Acc A R x -> P x :=
  fun A R P f x a =>
    match a as aa in Acc z return P z with
    | acc x0 h => f x0 (fun y r => accRec A R P f y (h y r))
    end
def accZero : Acc Nat LtNat zero :=
  acc Nat LtNat zero (fun y r => match r with end)
```

`test/fixtures/m5e-witness.tot`, byte for byte, two lines (probe P3 pins
its verdict at line 2, column 1):

```
data T : Type 0 := | mk : (Nat -> T) -> T
def rec bad : T -> Nat := fun t => match mk (fun n => t) with | mk g => bad (g zero) end
```

Both files carry a header comment in the committed version.  The
comments sit above the shown text and shift the pinned line numbers, so
put the comments BELOW the pinned items or re-pin the numbers against the
built binary before committing the gate.

### E4. Worked example, under the flag

    $ tot check --experimental-wf test/fixtures/m5e-acc.tot

Expected stdout, five lines, exit 0:

```
data Acc : (0 A : Type 0) -> (0 R : (w _ : A) -> (w _ : A) -> Type 0) -> (0 _ : A) -> Type 0
ctor acc : (0 A : Type 0) -> (0 R : (w _ : A) -> (w _ : A) -> Type 0) -> (w x : A) -> (w _ : (w y : A) -> (w _ : ((R y) x)) -> (((Acc A) R) y)) -> (((Acc A) R) x)
def LtNat : (w _ : Nat) -> (w _ : Nat) -> Type 0
def accRec : (0 A : Type 0) -> (0 R : (w _ : A) -> (w _ : A) -> Type 0) -> (0 P : (w _ : A) -> Type 0) -> (w _ : (w x : A) -> (w _ : (w y : A) -> (w _ : ((R y) x)) -> (P y)) -> (P x)) -> (w x : A) -> (w _ : (((Acc A) R) x)) -> (P x)
def accZero : (((Acc Nat) LtNat) zero)
```

Lines 1, 2, 3 and 5 are pinned VERBATIM by probe R1.  Line 4 is DERIVED:
probe R1 pinned that exact type through `axiom accRec`, and probe Q4
pinned the `def NAME : TYPE` prefix shape.  A def's type and an axiom's
type both come from `infer_univ` and print through the same `Pp` path, so
line 4 should differ from R1's only in the leading `axiom ` becoming
`def `.  Confirm line 4 byte for byte against the built binary before you
commit the gate.  Do NOT weaken the gate's `want` to a substring match.

### E5. Negatives, pinned to exact error text

1. The panel divergence witness, UNDER the flag.  This is A4's pinned
   negative:

       $ tot check --experimental-wf test/fixtures/m5e-witness.tot
       test/fixtures/m5e-witness.tot:2:1: recursive definition bad failed the structural termination guard
       exit 1

   stdout is empty.  The message goes to stderr alone (probe R4: 0 bytes
   on stdout, 134 bytes on stderr for the same shape).

2. The same witness with NO flag.  Identical exit code and identical
   text (probe P3).  This equality is the point: the prototype rejects
   the witness for the same reason the shipped rule does.

3. `accRec` with NO flag (probe R2):

       $ tot check test/fixtures/m5e-acc.tot
       test/fixtures/m5e-acc.tot:5:1: recursive definition accRec failed the structural termination guard
       exit 1

4. `accRec` with an ERASED accessibility argument, `(0 a : Acc A R x)`,
   under the flag (probe P6 pins the message at M4 HEAD):

       ...: erased variable a used at runtime
       exit 1

   The prototype does not move this.  `Acc`'s `acc` constructor carries
   two runtime fields, so `Acc` is not zero-eliminable under the M4
   subsingleton fence, and the match on an erased scrutinee is
   `Error.Erased_use` before any totality question is asked.  Section E7
   turns this into measurement M3.

### E6. Byte-identity of the default path

Without `--experimental-wf`, stdout and stderr must be byte-identical to
Stage D exit across the whole check corpus.

E6.1, BEFORE any Stage E code lands.  Add `dev/gen-m5e-transcript.sh`.
It runs `tot check` over a fixed, sorted corpus from `$ROOT`, with
repo-relative paths so the text carries no machine-specific bytes:

```sh
#!/bin/zsh
ROOT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)" || exit 9
cd "$ROOT" || exit 9
export LC_ALL=C
scratch=$(mktemp -d) || exit 9
trap 'rm -rf "$scratch"' EXIT
for f in examples/*.tot test/fixtures/*.tot; do
  printf '### %s\n' "$f"
  _build/default/bin/tot.exe check "$f" > "$scratch/o" 2> "$scratch/e"
  printf '#exit %d\n#out\n' $?
  cat "$scratch/o"
  printf '#err\n'
  cat "$scratch/e"
done
```

The preamble's LANGUAGE SCOPE rule covers this script: the combinator
rule, the loop-keyword rule, the mutation rule, the catch-all-arm rule
and the indexing rule all bind the OCaml sources under `lib/`,
`surface/`, `bin/` and `test/`, and none of them binds `dev/*.sh`.
`dev/gates.sh:1318` already carries a `while` loop, so the `for` above
is neither new nor an exception.  The `cd "$ROOT"` on line 2 is the
same case: the never-`cd` rule binds a Bash tool CALL, whose cwd resets
between calls, and this script fixes its own cwd from its own path
instead of depending on the caller's.

Run it at Stage D exit and commit the output as
`dev/m5e-default-transcript.txt`.  Record its byte count and its line
count in `dev/M5-BUILD-LOG.md`.

E6.2, AFTER Stage E code lands.  Regenerate and `diff`.  The diff must be
empty.

E6.3, the suites.  `test/main.exe` and `test/surface.exe` add two Stage E
cases and lose none.  The 278 PASS walk plus every Stage A to D addition
stays green.  The two new cases run at `Structural` and at
`Structural_wf` explicitly, so neither changes a default-path answer.

`test/main.ml`, labels `E<n>:`:

1. `E1: Structural_wf accepts the accRec call shape`.  Build the stamped
   `accRec` body by hand, call
   `Totality.guard ~rule:Totality.Structural_wf ~recname:"accRec"`, and
   assert `Ok 5`.  Assert that the same body under
   `~rule:Totality.Structural` gives `Error (Error.Termination "accRec")`.
2. `E2: Structural_wf still rejects the panel witness`.  Same two calls
   on the `bad` body.  Both must give `Error (Error.Termination "bad")`.

### E7. What the spike MEASURES

Three measurements.  Each one goes into `dev/M5-BUILD-LOG.md` with its
command line, and into SPEC section 2's Stage E entry as a sentence.

M1, WHICH GUARD SHAPES THE CLAUSE UNLOCKS.  Run each shape twice, with
and without the flag, and tabulate.  The four shapes below are already
pinned at M4 HEAD, so only the flagged column is new work:

| Shape | Argument at position k | No flag | Under the flag |
| --- | --- | --- | --- |
| `accRec` | `h y r`, head is a match-bound field | exit 1 (P2, R2) | expect exit 0 |
| `bad2`, `match t with \| mk g => bad2 (g zero)` | `g zero`, head is a match-bound field, variable scrutinee | exit 1 (P5) | expect exit 0 |
| `bad`, the panel witness | `g zero`, scrutinee is `mk (fun n => t)` | exit 1 (P3) | exit 1, pinned by the gate |
| `bad3`, `match t with \| mk g => bad3 (mk g)` | `mk g`, head is a constructor | exit 1 (Q6) | expect exit 1 |

The `bad2` row is the measurement that matters most, and it is the one
the panel did not state.  The clause is NOT specific to accessibility.
It unlocks infinitary structural recursion at the same time, because
nothing in it inspects the FIELD'S TYPE.  M6 must decide whether it wants
one feature or two.  Report the row count that flips, not a verdict.

M2, COST IN THE CHECKER.  The clause runs only inside `guarded_call`,
which runs only on the argument at candidate position k of a recursive
call spine.  At `Structural` it costs one constructor comparison per such
argument.  Measure three medians of three runs each, at Stage D exit and
at Stage E exit: the two suites, `dev/gen-m5e-transcript.sh`, and
`tot check --experimental-wf test/fixtures/m5e-acc.tot`.  Record every
number.  Do not tune.  Stage E does not optimize.

M3, DOES `Frozen_rec` AT DEFINITION TIME BECOME LOAD-BEARING.  The
question is whether `Acc` values start appearing at erased quantity.
Probe P6 answers it for today: they cannot.  An `(0 a : Acc A R x)`
argument fails with `erased variable a used at runtime` before the guard
runs, because `Acc` has two runtime constructor fields and so is not
zero-eliminable under the M4 fence.  Record the finding as three
sentences:

1. `Frozen` stays dead code for every `Acc` shape M5 can build.  The M4
   Stage C claim in SPEC is unchanged.
2. `Frozen_rec` as a definition-time error buys nothing until `Acc`
   gains an erased elimination form.  That is a subsingleton-fence
   change, not a totality change.
3. The two changes are therefore COUPLED.  M6 must size them together or
   neither.  This confirms the verdict's "Deferred and TIED to
   well-founded recursion" line with an executable reason.

### E8. Gates

Three markers, the three the preamble reserves for Stage E.  All three
are new.  `rg -c 'PASS-M5' dev/gates.sh` at M4 HEAD matches nothing, so
no name collides.  Each leg runs under Stage D's named tiers.  No
numeric watchdog literal is introduced, per pin P17.

Three shell facts this block depends on, each checked against the file
it lands in.

1. The tier variables are spelled `FAST`, `MED`, `SLOW`, `SUITE` and
   `BITE_S`, defined once in Stage D's tier block
   (Stage D, D1).  There is no `TIER_` prefix.  Use
   `"$watchdog" "$SLOW"` and `"$watchdog" "$FAST"`.  `dev/gates.sh`
   must not use `set -u`, so a misspelled tier expands to the EMPTY
   string and `timeout "" ...` runs with no ceiling at all.  A leg that
   silently loses its watchdog is the failure this list exists to stop.
2. There is no `$scratch` in `dev/gates.sh`.  The file defines
   `tot_scratch` (dev/gates.sh:368), `cache_scratch` (:473),
   `nohome_scratch` (:560) and `mm_scratch` (:1312), each from its own
   `mktemp -d`.  This block makes its own the same way, `m5e_scratch`,
   and adds it to the existing `EXIT` trap.  An unset `$scratch` would
   write to `/m5e-now.txt` at the filesystem root.
3. `PASS-M5D-TIERS` asserts the tier-use count with `-eq` against a
   literal `<N>` that Stage D computed over Stages A, B and C
   (Stage D, D1 tier table).  This block adds SIX tier uses, so Stage E
   MUST raise that literal from `<N>` to `<N>+6` in the same edit, and
   record both numbers in `dev/M5-BUILD-LOG.md`.  Skipping that turns a
   green Stage D gate red.  Raising it by more or fewer than the legs
   you actually added is the same defect in the other direction, so
   count them with
   `rg -c '"\$watchdog" "\$(FAST|MED|SLOW|SUITE)"' dev/gates.sh` before
   and after, and use the difference.

Add the scratch directory beside the other three, directly above the
first leg:

```sh
m5e_scratch=$(mktemp -d "${TMPDIR:-/tmp}/tot-gate-e.XXXXXX")
```

and extend the existing `trap ... EXIT` at `dev/gates.sh:374` to remove
it too.  Do not add a second `trap`: a second one REPLACES the first
and leaks `tot_scratch` and `cache_scratch`.

```sh
# ---------------------------------------------------------------------
# M5 Stage E (SPIKE): well-founded recursion behind --experimental-wf
# ---------------------------------------------------------------------

# Gate E (i), PASS-M5E-DEFAULT-IDENTITY. Without the flag the driver's
# whole check corpus is byte-identical to the transcript committed at
# Stage D exit, and accRec still fails the shipped guard.
"$watchdog" "$SLOW" "$ROOT"/dev/gen-m5e-transcript.sh > "$m5e_scratch"/m5e-now.txt 2>&1
code=$?
out2=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m5e-acc.tot 2>&1)
code2=$?
{ [ "$code" -eq 0 ] && [ "$code2" -eq 1 ] \
    && diff -q "$ROOT"/dev/m5e-default-transcript.txt "$m5e_scratch"/m5e-now.txt > /dev/null \
    && printf '%s\n' "$out2" \
       | rg -q 'm5e-acc\.tot:5:1: recursive definition accRec failed the structural termination guard'; } \
  && echo PASS-M5E-DEFAULT-IDENTITY \
  || {
    diff "$ROOT"/dev/m5e-default-transcript.txt "$m5e_scratch"/m5e-now.txt | head -40
    printf '%s\n' "$out2"
    echo "FAIL-M5E-DEFAULT-IDENTITY (exit=$code/$code2)"
    exit 1
  }

# Gate E (ii), PASS-M5E-ACC-CHECKS. The Acc plus accRec worked example
# checks at exit 0 under the flag, with the exact five-line output.
out=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  --experimental-wf "$ROOT"/test/fixtures/m5e-acc.tot 2>&1)
code=$?
want=$'data Acc : ...\nctor acc : ...\ndef LtNat : ...\ndef accRec : ...\ndef accZero : ...'
{ [ "$code" -eq 0 ] && [ "$out" = "$want" ]; } \
  && echo PASS-M5E-ACC-CHECKS \
  || { printf '%s\n' "$out"; echo "FAIL-M5E-ACC-CHECKS (exit=$code)"; exit 1; }

# Gate E (iii), PASS-M5E-WITNESS-REJECTED. Three legs. Leg (a) proves the
# flag is LIVE, so a dead flag cannot make legs (b) and (c) pass by
# accident. Leg (b) is amendment A4's pinned negative. Leg (c) shows the
# prototype changes nothing about this file.
outa=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  --experimental-wf "$ROOT"/test/fixtures/m5e-acc.tot 2>&1)
codea=$?
outb=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  --experimental-wf "$ROOT"/test/fixtures/m5e-witness.tot 2>&1)
codeb=$?
outc=$("$watchdog" "$FAST" "$ROOT"/_build/default/bin/tot.exe check \
  "$ROOT"/test/fixtures/m5e-witness.tot 2>&1)
codec=$?
wantw='m5e-witness.tot:2:1: recursive definition bad failed the structural termination guard'
{ [ "$codea" -eq 0 ] && [ "$codeb" -eq 1 ] && [ "$codec" -eq 1 ] \
    && printf '%s\n' "$outb" | rg -q -- "$wantw" \
    && printf '%s\n' "$outc" | rg -q -- "$wantw" \
    && [ "$outb" = "$outc" ]; } \
  && echo PASS-M5E-WITNESS-REJECTED \
  || {
    printf '%s\n%s\n%s\n' "$outa" "$outb" "$outc"
    echo "FAIL-M5E-WITNESS-REJECTED (exit=$codea/$codeb/$codec)"
    exit 1
  }
```

`want` in Gate E (ii) is abbreviated above.  Fill it with the five lines
of section E4, byte for byte.

MUTATION PROOFS.  Run each mutation, observe the stated flip, then revert
the mutation and re-run the battery green.  Record each observed flip in
`dev/M5-BUILD-LOG.md`.

1. `PASS-M5E-DEFAULT-IDENTITY`.  Mutation: leak the flag-gated branch
   into the default path.  In `bin/tot.ml`'s `dispatch`, set
   `wf_rule = Tot_kernel.Totality.Structural_wf` unconditionally.
   Observed flip: the `test/fixtures/m5e-acc.tot` transcript block changes from the
   one-line guard message at exit 1 to the five-line success at exit 0,
   the `diff` is non-empty, `code2` becomes 0, and the leg prints
   `FAIL-M5E-DEFAULT-IDENTITY`.  Both halves of the leg fail, so the
   transcript half and the direct half are each proved live.

2. `PASS-M5E-ACC-CHECKS`.  Mutation: in `guarded_call`'s new `App` arm,
   return `false` for `Structural_wf` too, which is the shipped answer.
   Observed flip: `accRec` returns to exit 1 with the
   `... accRec failed the structural termination guard` line, `$out`
   stops matching `$want`, and the leg prints `FAIL-M5E-ACC-CHECKS`.

3. `PASS-M5E-WITNESS-REJECTED`.  Mutation: drop the precondition that
   blocks the witness.  In `passes`, set `binder_status = Smaller`
   unconditionally, which is `scrut_special` deleted.  Observed flip:
   leg (b) becomes exit 0, `codeb` stops being 1, and the leg prints
   `FAIL-M5E-WITNESS-REJECTED`.  Leg (c) stays exit 1, because without
   the flag `guarded_call` still demands a bare `Term.Var` and `bad`
   supplies the application `g zero`.  The mutation therefore proves the
   precondition, not the flag.  Leg (a) proves the flag.

### E9. SPEC.md

Append a dated block to section 2, `2026-09-02 (M5, Stage E, SPIKE)`:

1. **`--experimental-wf` exists and is off by default.**  It selects
   `Totality.Structural_wf` in place of `Totality.Structural`.  It is a
   DRIVER flag.  It never reaches the prelude, which folds through
   `Run.default_policy`.  `Cache.format_version` does not move.
2. **The prototype rule, stated in one sentence.**  At
   `Structural_wf`, a recursive call whose argument at the candidate
   position is an APPLICATION is guarded when that application's head is
   a variable already marked `Smaller`.
3. **The precondition that keeps the witness out.**  A branch binder
   becomes `Smaller` only when the match scrutinee is a `Principal` or
   `Smaller` VARIABLE.  The panel witness builds its own scrutinee, so
   its binder stays `Other` and the call stays rejected.  This is the
   missing precondition amendment A4 names, and
   `PASS-M5E-WITNESS-REJECTED` pins it.
4. **The clause is not specific to accessibility.**  It inspects the
   head's status, never the field's TYPE, so it unlocks infinitary
   structural recursion (`bad2`) at the same time as `accRec`.  Record
   the M1 table.
5. **`Acc` needs no universe polymorphism** and no new kernel typing
   rule.  It checks at M4 HEAD (probe P1).  Record the exact declaration
   from section E3.
6. **A relation supplied as an INDEXED FAMILY does not fit `Acc`'s `R`.**
   Record conflict C2 below with the exact mismatch text.
7. **`Frozen_rec` stays un-motivated.**  Record measurement M3's three
   sentences.  The `Frozen` emptiness claim stays UNPROVEN, unchanged
   from the M4 Stage C entry.

Section 5's `M5:` bullet becomes an M6 CANDIDATE LIST carrying the
spike's numbers:

- Well-founded recursion.  Leading candidate.  `Acc` checks today;  the
  whole kernel delta sits in `Totality.guard`;  the prototype clause is
  measured in the Stage E entry and is too permissive as written.
- Holes.  Sized by Stage D's hole-anchor count, not by taste.
- Nested and mutual inductives.  Blocked on the MUTUAL gap in
  `Totality.mentions`, which tests only the family's own name, over an
  emptiness claim SPEC still records as UNPROVEN.
- Universe polymorphism.  Not needed by `Acc` (probe P1).

Section 6 gains no new debt.  `--experimental-wf` is not a debt.  It is a
measurement instrument, and M6 either promotes it or deletes it.

### E10. Conflict notes (dated 2026-09-02)

C1.  The verdict's probe line writes the declaration as
`data Acc ... := | acc : ...`, with the header elided.  The repo requires
an index telescope after the header colon, and `lib/check.ml` line 1589
forces every index binder to `Quantity.Zero` (`Error.Index_not_zero`).
RESOLUTION: this section pins the exact header that checks at exit 0,
`data Acc (0 A : Type 0) (0 R : A -> A -> Type 0) : A -> Type 0 :=`, with
the printed result from probe P1.

C2.  The verdict's `Acc` shape needs `R` at `(w _ : A) -> (w _ : A) ->
Type 0`.  A relation declared as an indexed family gets Zero-quantity
domains instead, and the two do not convert.  Probe P7:

    data Lt : Nat -> Nat -> Type 0 := ...
    def accZero : Acc Nat Lt zero := ...
    ...: type mismatch: expected (w _ : Nat) -> (w _ : Nat) -> Type 0, found (0 _ : Nat) -> (0 _ : Nat) -> Type 0
    exit 1

RESOLUTION: the Stage E worked example supplies the relation as a
`reducible def` family (`LtNat`), which probes Q2 and R1 pin at exit 0.
The gap itself is real and it is M6 work, so it goes into SPEC section
2's Stage E entry as item 6 rather than being fixed here.  A spike does
not change the quantity rules.

C3.  Amendment A4 calls the panel witness "a pinned negative under the
flag".  The prototype keeps the precondition that rejects it, so the
witness produces the SAME message and the SAME exit code with and without
the flag (probes P3 and the E5 pins).  A negative-only gate would
therefore stay green even if the flag were dead.  RESOLUTION:
`PASS-M5E-WITNESS-REJECTED` carries a liveness leg in the same gate body.
Leg (a) requires `accRec` to check at exit 0 under the flag.  A dead flag
fails the gate at leg (a), so the negative can never pass vacuously.
