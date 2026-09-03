# M5 build log

One section per stage, appended when the stage is green (preamble
section 8).  Commands, observed outputs and mutation proofs are
recorded verbatim;  nothing here is restated from memory.

## Stage A (2026-09-02): JSON conformance, --strict-json, two fence pins

Plan: dev/M5-PLAN.md Stage A (sections A0 to A12).  Pins implemented:
P13, P14, P15, P16, P20, P23.

### Entry state

Baseline re-run BEFORE any edit, at commit 4f75130 (clean tree):

    dunecho build                    OK build: 0 errors, 0 warnings
    dune exec test/main.exe          tail: "M0 kernel: all tests green"
    dune exec test/surface.exe       tail: "M1 surface: all tests green"
    zsh dev/gates.sh                 GATE-EXIT=0
    rg -c '^PASS'                    278
    rg -c '^FAIL'                    no match (exit 1)

Note on the entry commit: the plan's entry line says M4 HEAD 34ea009.
The tree at build start is 4f75130, one commit later (the M5 plan
commit itself;  dev/M5-PLAN.md is in-tree).  The baseline arithmetic
is byte-identical (278 PASS, 0 FAIL, GATE-EXIT=0, 91 `echo PASS-`
sites, format_version 10), so the entry state holds as pinned.

### What changed

1. `lib/json_escape.ml` (NEW): the JSON escaper (`Json_escape.string`),
   RFC 8259 short forms in RFC order, `\u00XX` for the rest of C0, DEL
   and >= 0x80 unescaped (A1).
2. `lib/interp.ml`: `json_hex_val`, `json_hex4`, `json_utf8_bytes`
   above `json_string_body`;  a `\uXXXX` arm with surrogate-PAIR
   decoding placed BEFORE the `'\\' :: _ :: _ -> None` catch;  the
   FALSE reuse docstring on `json_serialize` corrected;  the `jstr`
   value site and the object KEY site rewired to `Json_escape.string`
   (A2, A3).
3. `lib/pp.ml`: docstring only;  `escape_string` is now stated as the
   SOURCE escaper with the split named (A3).
4. `surface/effect.ml`: `outcome` gains `Rejected of string`;
   module-level `strict_json_reason`, `envelope`, `deny_envelope`
   (envelope lifted out of `render_verdict`, now quoting through the
   JSON escaper);  `run_io`/`dispatch` gain `~strict_json`;  the
   `Prim.Read_stdin` arm refuses a non-JSON payload under the flag
   (A4).
5. `surface/run.ml`: `policy` gains `strict_json` (default false);
   `run_main`/`run_verdict_main`/`run_unit_main` thread it;
   `run_verdict_main` renders `Rejected` as the deny envelope at
   exit 2;  `run_unit_main` maps it to `Error Serror.Json_strict_reject`
   (A4).
6. `surface/serror.ml`: `Json_strict_reject` variant, its `to_string`
   line ("stdin is not a single well-formed JSON value, and this
   installation runs with --strict-json") and `tag`;  NEW
   `driver_exit : t -> bool` (enumerated, no catch-all) so bin/tot.ml
   can map that ONE Serror to the literal exit 1 outside the
   `--serror-exit` mapping (A4 step 5).
7. `bin/tot.ml`: `opts.strict_json` (default false), the
   `--strict-json` parse_flags arm, the usage line, the policy copy,
   and the `driver_exit` mapping in `run_file`'s error fold (A4).
8. `examples/guard.tot`: comment only, pointing fail-closed installs
   at `tot run --strict-json`.
9. `test/main.ml`: 9 kernel cases (A8 items 1 to 9).
10. `test/surface.ml`: 6 surface cases (A8 items 10 to 15) plus
    helpers, and three compiler/oracle-forced touch-ups recorded under
    "Conflicts" below.
11. `test/fixtures/`: 11 payload `.json` fixtures (programmatic
    backslash, no trailing newline) and 5 `.tot` fixtures, all probed
    against the built binary before the gates were written.
12. `dev/gates.sh`: the M5 Stage A section, 8 legs, inserted BEFORE
    the PASS-M4FIX-INST-BRANCHING block so that leg stays the last in
    the file;  the section re-exports TOT_PRELUDE (the cache legs
    unset it mid-file) and unsets it again at section end.
13. `SPEC.md`: the dated `2026-09-02 (M5, Stage A)` section 2 block
    (8 entries per A11), the driver grammar with `--strict-json` in
    section 3, and two ADDED section 6 residual bullets (raw-C0
    acceptance;  the format_version no-bump).  Nothing else in
    section 6 moved (Stage D owns the rewrite).

New `Error.t` variants: NONE.  New `Serror.t` variants:
`Json_strict_reject` (plus the `driver_exit` helper).
`Cache.format_version`: UNCHANGED at 10 (pin P1;  A9 reasons recorded
in the SPEC entry).

### Tests added

Kernel (test/main.ml), 9 cases:
M5A-J1 (CR escapes to \r, exact bytes), M5A-J2 (0x01 to \u0001),
M5A-J3 (UTF-8 e-acute byte-clean), M5A-J4 (DEL unescaped),
M5A-J5 (\u0041 decodes to jstr A), M5A-J6 (surrogate pair to
f0 9f 98 80), M5A-J7 (six negative escape shapes each fail the WHOLE
parse), M5A-J8 (parse-serialize-reparse round trip over a raw-CR
payload), M5A-J9 (the two escapers DIFFER on "a\rb").

Note on A8 case 1's prose: the plan says "the exact 7-character
result";  the exact escaped form of the 3-byte input is the 6-byte
string `"a\rb"` (quote, a, backslash, r, b, quote).  The test pins
exact bytes, which is the stronger oracle;  the count in the plan
prose is off by one.

Surface (test/surface.ml), 6 cases:
M5A-10 (fence-pi fixture rejected, message printed and pinned by
suffix "erased variable px used at runtime"), M5A-11 (control checks
clean), M5A-12 (PBox and Acc check), M5A-13 (both level negatives
with pinned texts), M5A-14 (Run.script, strict_json=true, garbage
stdin via a real fd swap: strict deny envelope + exit 2),
M5A-15 (same payload, strict_json=false: allow, exit 0).

Confirmed unchanged per A8: PASS-D-GUARD-OTHER (garbage still exits 0
under the default posture) and PASS-C-JSON (no control byte in its
payload) are both green with NO edit.

### Gate markers added (dev/gates.sh)

PASS-M5A-BYPASS, PASS-M5A-FIXTURE-BYTES, PASS-M5A-ENVELOPE-VALID,
PASS-M5A-LONE-SURROGATE, PASS-M5A-FENCE-PI, PASS-M5A-PARAM-LEVEL,
PASS-M5A-STRICT-DENY, PASS-M5A-STRICT-ALLOW.  Exactly the eight the
preamble reserves;  marker inventory diff against the baseline run
shows 92 -> 100 with ONLY those additions (no pre-existing marker
missing, renamed or edited).  All eight legs wear `"$watchdog" 30`
(the MED tier value);  Stage D's tier-conversion corpus gains these
sites: 89 baseline sites plus Stage A's 18 `"$watchdog" 30` sites
(4 bypass, 1 fixture rg, 2 envelope, 1 lone-surrogate loop body,
2 fence, 3 param, 2 strict-deny, 3 strict-allow), MEASURED at Stage A
exit: `rg -c '"\$watchdog" [0-9]+' dev/gates.sh` prints 107.

### Mutation proofs (11 runs, every one flipped its own leg, all reverted)

Runner: a standalone replica of each leg's exact commands and oracles
(/Users/oobi/Documents/tot-m5-stageA-leg.sh), used because the full
battery short-circuits at its first red, so the LEG's own flip must be
shown directly.  Full transcript:
/Users/oobi/Documents/tot-m5-stageA-mutations.log.  Digests are md5 of
the target file before mutation and after restore (identical in every
row).

1. M1, PASS-M5A-BYPASS.  lib/interp.ml (md5 edd0886f3ef6a05198955565
   ea55a963): the `\u` arm neutralized so every `\u` escape fails the
   whole parse (deletion-equivalent;  see conflict 5c).  RED:
   `FAIL-M5A-BYPASS (exit=0/0/0/0)`, empty stdout on all four
   payloads, the measured M4 state (A0 rows 1, 9, 10, 12).  Reverted,
   md5 identical, leg PASS.
2. M2, PASS-M5A-FIXTURE-BYTES.  test/fixtures/m5a-bypass.json (md5
   aebd832b84c2de47a64f2f0c3d1a9a36) rewritten with a decoded `g`.
   RED: `FAIL-M5A-FIXTURE-BYTES` (rg exit 1).  Restored byte-identical,
   leg PASS.
3. M3a, PASS-M5A-ENVELOPE-VALID (envelope site).  surface/effect.ml
   (md5 b50915fdb47b92d2f117fc83ca0ff6e3): `envelope` reverted to
   `Pp.escape_string`.  RED: the envelope carried a raw 0x0D and a raw
   0x01, `json.loads` exit 1;  `FAIL-M5A-ENVELOPE-VALID (exit=2 py=1
   ser=0 serpy=0)`.  The serializer half stayed green, proving site
   independence.  Reverted, leg PASS.
4. M3b, PASS-M5A-ENVELOPE-VALID (serializer jstr site).  lib/interp.ml
   (md5 edd0886f...): the `jstr` value site reverted to
   `Pp.escape_string`.  RED: the serializer line printed `"x<0x0D>y"`
   (raw CR, no literal `\r`), `json.loads` exit 1;
   `FAIL-M5A-ENVELOPE-VALID (exit=2 py=0 ser=0 serpy=1)`.  The
   envelope half stayed green.  Reverted, leg PASS.  (Oracle note:
   conflict 4 below.)
5. M4, PASS-M5A-LONE-SURROGATE.  lib/interp.ml (md5 edd0886f...):
   both surrogate guards dropped, every 4-hex escape decodes directly.
   RED: suite replay shows `FAIL M5A-J7` (json_parse_top "\"\\ud800\""
   returns Some) and `FAIL M5A-J6`;  the six guard runs still exited
   0 with empty stdout, exactly the vacuity the direct parse assertion
   exists to refuse (plan A10).  Reverted, leg PASS.
6. M5, PASS-M5A-FENCE-PI.  lib/totality.ml (md5
   d90ec278df691c3829ef843bbfa5a266): the Pi arm walks the DOMAIN only
   (conflict note C1's corrected mutation).  RED: the pinned message
   disappears;  observed error is `recursive definition pxfLoop failed
   the structural termination guard` (exit 1), control still exit 0;
   `FAIL-M5A-FENCE-PI (exit=1/0)`.  OBSERVED-vs-PREDICTED: the plan
   predicted exit 0 via zero_eliminable;  in this tree
   `Totality.guard` also consumes `mentions`, and its smaller-variable
   analysis fails FIRST, so the fixture dies earlier on the mutated
   walk.  The leg flips either way (its oracle requires the exact
   Erased_use message), so the pin is proved non-vacuous;  recorded
   rather than absorbed.  Reverted, leg PASS.
7. M6a, PASS-M5A-PARAM-LEVEL (positive half).  lib/check.ml (md5
   33b25676445613c91e0e89eab8a1d341): the parameter fold bounded with
   the index fold's `Level.le l level` check.  RED: the prelude itself
   stops bootstrapping (`inductive Div: index A lives above the
   declared universe`) and the direct `--no-prelude` probe shows
   `inductive PBox: index A lives above the declared universe`;
   `FAIL-M5A-PARAM-LEVEL (exit=1/1/1)`.  The exemption is what makes
   the whole stdlib check, not just Acc.  Reverted, leg PASS.
8. M6b, PASS-M5A-PARAM-LEVEL (first negative).  lib/check.ml: the
   constructor-argument bound made vacuous (`Level.le l l`).  RED:
   KBad CHECKS (`ctor kmk : (0 a : Type 0) -> KBad`, exit 0), the
   pinned Bad_ctor text disappears;  `FAIL-M5A-PARAM-LEVEL
   (exit=0/0/1)`.  Only the first negative flipped.  Reverted, PASS.
9. M6c, PASS-M5A-PARAM-LEVEL (second negative).  lib/check.ml: the
   index bound made vacuous.  RED: IBad CHECKS (`ctor imk : (IBad
   Nat)`, exit 0);  `FAIL-M5A-PARAM-LEVEL (exit=0/1/0)`.  Only the
   second negative flipped.  Three mutations, three distinct halves,
   no half certifying another.  Reverted, PASS.
10. M7, PASS-M5A-STRICT-DENY.  surface/effect.ml: the strict guard
    goes unconditionally false (`strict_json && false`;  conflict 5d).
    RED: exit 0, empty stdout, on garbage.json AND m5a-lone-hi.json,
    the measured M4 posture (A0 rows 26 and 3);  `FAIL-M5A-STRICT-DENY
    (exit=0/0)`.  Reverted, PASS.
11. M8, PASS-M5A-STRICT-ALLOW.  bin/tot.ml (md5
    566a486389f160c76192e61bd2f05f60): default `strict_json = true`.
    RED: assertion (c) fails, the UNFLAGGED garbage run prints the
    strict-json envelope and exits 2 (`exit=0/2/2`);  (a) and (b)
    unchanged, so only the default-off half flipped.  Reverted, PASS.

Tree state after the final revert: every md5 matched its pre-mutation
value, no `.m5a-orig` backup remains, and the final full battery below
ran on the restored tree.

### Conflicts (section 5 protocol)

Inherited from the plan, recorded as instructed, not re-litigated:

- Stage A conflict 1 (A4): pin P20's argv clause dropped;
  `--strict-json` travels as `Run.policy.strict_json` and is enforced
  at `Effect.dispatch`'s `Read_stdin` arm.  Built as the plan
  resolves.
- Stage A conflict 2 (A5, preamble C1): the fence-pin mutation is the
  Pi CODOMAIN half;  the domain half is refuted by strict positivity
  and is recorded in SPEC as refuted, not proved here.
- Stage A conflict 3 (A6): the `Acc` fixture uses the probed spelling
  (0-marked parameters, accessibility as an INDEX);  the verdict's
  spelling does not parse.

New, found during this build:

- Conflict note C4-A (2026-09-02): plan A10's ENVELOPE-VALID second
  mutation pins the flip "the second jsonParse returns none".  The
  repo proves that oracle impossible: a raw C0 byte inside a JSON
  string body still PARSES, by the plan's own deliberate non-change 1
  (A2), re-probed on 2026-09-02 (a raw-CR payload parses to SOME), so
  a serializer that emits a raw CR still round-trips through OUR
  parser and only the emitted BYTES discriminate.  Resolution per
  section 5 rule 5: the mutation is UNCHANGED, the oracle half is
  replaced (the serialized line must carry the literal two-character
  `\r` and satisfy `python3 json.loads`), and the flip was proved
  (mutation M3b).  The leg was not shrunk.
- Conflict note C5-A (2026-09-02): four pinned spellings are denied or
  uncompilable in this environment;  intent kept, mechanism moved,
  per section 5 rule 4 (a hook denial and a compiler error are the
  proof):
  (a) A2's `Char.chr (n land 0xff) (* @total-accessor *)` is DENIED by
  the house panicscan hook (the marker does not exempt a partial Char
  accessor).  `json_utf8_bytes` emits bytes through
  `Buffer.add_uint8` (total, masked) instead;  same signature, same
  bytes.
  (b) A2's pinned `\u` arm matches on `Option`;  the house
  combinators-over-match hook DENIES new option matches.  The arm uses
  `Option.bind` with the same guard ladder;  behaviour identical.
  (c) A10's BYPASS mutation "delete the arm" does not compile: dune's
  dev profile makes unused-value warnings errors, and deletion orphans
  `json_hex4`/`json_utf8_bytes`.  The proof mutation neutralizes the
  arm body instead (every `\u` escape returns None), which is
  behaviour-identical to deletion (the fall-through catch also returns
  None) and compiles.
  (d) A10's STRICT-DENY mutation "replace the condition with false"
  does not compile (the labeled `strict_json` becomes unused, warning
  27 as error);  the proof uses `strict_json && false`, the same
  always-false guard.
- Conflict note C6-A (2026-09-02): A8's additivity requirement ("no
  existing test term changes") meets A4 step 1's mandated usage-line
  change and OCaml's record/match totality.  Four existing test sites
  moved, each FORCED by the compiler or by the new usage bytes, none
  a weakening:  (1) `case_usage_channel`'s pinned usage line now
  carries `[--strict-json]`, staying byte-exact against the driver's
  own string;  (2, 3) the two `Run.policy` record literals gained
  `strict_json = false` (OCaml record literals must be complete);
  (4) the B3 procRun case gained `~strict_json:false` and a `Rejected`
  arm (exhaustiveness).  Every pre-existing assertion is unchanged in
  meaning;  the 278-walk arithmetic held (no pre-existing case moved
  its verdict).
- Entry-commit note: baseline commit is 4f75130 (the M5 plan commit),
  one ahead of the pinned 34ea009;  baseline numbers identical.
- Gate-file detail (recorded, not a conflict): dev/gates.sh unsets
  TOT_PRELUDE after its cache legs, so the M5A section re-exports it
  and unsets it again at section end, leaving downstream legs the
  environment they had.

### Exit criteria (A12), measured

1. `zsh dev/gates.sh` GATE-EXIT=0
   (full log: /Users/oobi/Documents/tot-m5-stageA-gate.log).
2. `rg -c '^PASS'` = 301 = 278 + 15 + 8 (A8: 9 kernel + 6 surface;
   A10: 8 markers).  Decomposed: kernel suite 95 PASS lines, surface
   suite 106, gate markers 100 (92 baseline + 8).  `rg -c '^FAIL'`
   matches nothing (exit 1).  STAGE B CHAINS FROM 301.
3. All eight PASS-M5A-* markers present;  marker-inventory diff vs the
   baseline run shows additions only.
4. Every A10 mutation run, flipped, reverted (table above;  transcript
   in /Users/oobi/Documents/tot-m5-stageA-mutations.log).
5. C0 sweep `rg -l '[\x00-\x08\x0B-\x1F]' test/fixtures/ stdlib/
   examples/` returns NOTHING, exit 1 (probe 27 repeated;  also run
   over every file this stage touched, likewise clean).
6. Escaper split: `rg -c 'Json_escape.string' lib/interp.ml` = 2,
   `rg -c 'Json_escape.string' surface/effect.ml` = 1;
   `rg -n 'Pp\.escape_string' lib/interp.ml surface/effect.ml` returns
   exactly two lines, both inside doc comments (interp.ml's corrected
   serializer docstring, effect.ml's render_verdict docstring),
   confirmed by eye.  Remaining call sites of `Pp.escape_string`: its
   definition and `Pp.literal`, both in lib/pp.ml.
7. `git status --porcelain` (UNSTAGED, nothing committed):

        M SPEC.md
        M bin/tot.ml
        M dev/gates.sh
        M examples/guard.tot
        M lib/interp.ml
        M lib/pp.ml
        M surface/effect.ml
        M surface/run.ml
        M surface/serror.ml
        M test/main.ml
        M test/surface.ml
       ?? lib/json_escape.ml
       ?? test/fixtures/m5a-bmp.json
       ?? test/fixtures/m5a-bypass.json
       ?? test/fixtures/m5a-fence-pi-ctl.tot
       ?? test/fixtures/m5a-fence-pi.tot
       ?? test/fixtures/m5a-hi-nonlow.json
       ?? test/fixtures/m5a-hi-plain.json
       ?? test/fixtures/m5a-index-level-neg.tot
       ?? test/fixtures/m5a-lone-hi.json
       ?? test/fixtures/m5a-lone-lo.json
       ?? test/fixtures/m5a-name-esc.json
       ?? test/fixtures/m5a-nonhex.json
       ?? test/fixtures/m5a-nul.json
       ?? test/fixtures/m5a-pair.json
       ?? test/fixtures/m5a-param-level-neg.tot
       ?? test/fixtures/m5a-param-level.tot
       ?? test/fixtures/m5a-short.json

### Gate output tails

    dune exec test/main.exe | tail -3
      PASS M5A-J8: parse-serialize-reparse round-trips a payload carrying a raw CR
      PASS M5A-J9: Json_escape.string and Pp.escape_string DIFFER on a CR-carrying string
      M0 kernel: all tests green

    dune exec test/surface.exe | tail -3
      PASS M5A-14: Run.script under strict_json=true turns a garbage stdin payload into the strict deny envelope and exit 2
      PASS M5A-15: Run.script under strict_json=false keeps the fail-open posture on the same payload (allow, exit 0)
      M1 surface: all tests green

    zsh dev/gates.sh | tail (final battery)
      PASS-M5A-BYPASS
      PASS-M5A-FIXTURE-BYTES
      PASS-M5A-ENVELOPE-VALID
      PASS-M5A-LONE-SURROGATE
      PASS-M5A-FENCE-PI
      PASS-M5A-PARAM-LEVEL
      PASS-M5A-STRICT-DENY
      PASS-M5A-STRICT-ALLOW
      PASS-M4FIX-INST-BRANCHING
      GATE-EXIT=0

## Stage B (2026-09-02): instance term sharing

Plan: dev/M5-PLAN.md Stage B (sections B0 to B15).  Pins implemented:
P1, P2, P3, P4, P5, P6 (P7 stays a measured option, decided by the
M5B4 number below and Stage D's log, per the pin itself).

### Entry state

Battery re-run BEFORE any edit, on commit 4f75130 plus Stage A's
UNSTAGED working-tree edits (log:
/Users/oobi/Documents/tot-m5-stageB-entry-gate.log):

    dunecho build                    OK build: 0 errors, 0 warnings
    dune exec test/main.exe          tail: "M0 kernel: all tests green"
    dune exec test/surface.exe       tail: "M1 surface: all tests green"
    zsh dev/gates.sh                 GATE-EXIT=0
    rg -c '^PASS'                    301
    rg -c '^FAIL'                    no match (exit 1)

The measured Stage A number is 301, exactly the expected chain
(278 + 15 + 8), so Stage B chains from 301 and exits at 312.

### What changed

1. `lib/term.ml`: `Term.shift ~cutoff ~by` appended after the
   [motive] record, total and exhaustive over all eleven constructors,
   no catch-all arm; the two Match cutoffs follow the file's ONE
   binder convention (`m_body` at `cutoff + |m_idx| + 1`, a branch
   body at `cutoff + |binders|`) (B1, pin 2).
2. `lib/check.ml`:
   - `instance_head_name` DELETED; `islot_head` replaces it (C-B1).
     The two `Inst_bad_shape` reason strings are unchanged.
   - NEW `islot`/`iarg` (pin 4), `islot_term` (IType shifts by the
     entry's own index, ISlot j is `Term.Var (i - 1 - j)`),
     `inst_entry { e_ty; e_def : islot; e_val : Value.t }` (pin 3),
     `entry_val` (total, `List.nth_opt`, a miss is a reported
     `Unbound_var`), and `materialize` (pin 1: one fold over the
     reverse-definition-order entries, inside out).
   - `inst_state.memo` retyped to `int InstMemo.t`; `entries` added;
     `fuel` and `goal` unchanged; `inst_start` seeds both empty.
   - `resolve_auto` returns `(slot, value, state)`; a memo HIT returns
     the slot and the CACHED `e_val` (pin 5); a MISS builds the entry,
     reads `q_cls` from the class's own `ind_entry` (pin 4), and
     records the slot in the memo.
   - `build_instance` accumulates an `islot` plus a VALUE accumulator
     `acc_v` advanced with `Eval.apply`; the M4 per-argument
     `Eval.eval globals ctx.env sub` (old lib/check.ml:725) is DELETED
     (C-B3).  Fuel arms, decrement sites, `inst_fuel`,
     `inst_memo_key` and `inst_key_enc` are unchanged.
   - The `Term.Auto` site materializes the nest and re-checks it
     unchanged (pin 6): `materialize st_end.entries ~top` then
     `check globals ctx mode candidate expected_v` (B5).
3. `lib/eval.ml`: `conv` split into the physical-equality shortcut
   (`a == b -> Ok true`) plus `conv_shapes`, the existing arms byte
   for byte; every recursive call inside `conv_shapes` still goes
   through `conv`, so the shortcut applies at every depth (B6).
4. `surface/cache.ml`: NO change; `format_version` stays 10 (pin 1,
   B7): `Term.t` gained a FUNCTION and no constructor, an old cache
   holds unshared but valid terms, and the binary-MD5 cache key
   already invalidates on rebuild.
5. `dev/gen-inst-branching.py` (NEW) and `dev/gen-inst-chains.py`
   (NEW): deterministic generators for the branching and chains
   shapes; neither overwrites an M4 fixture (B8).
6. `test/fixtures/`: 5 new fixtures (B9): m5b-inst-branching-20.tot
   (gen-inst-branching.py 20), m5b-inst-chains-8-40.tot
   (gen-inst-chains.py 8 40), m5b-inst-zero-dict.tot (hand written,
   the plan's 6 lines verbatim), m5b-inst-fuel-under.tot
   (gen-inst-fuel.py classes 60), m5b-inst-fuel-leaf.tot
   (gen-inst-fuel.py classes 61).  All probed against the built
   binary before the gates were written.
7. `test/main.ml`: the three mandated call-site updates (D7, D7b, D7c
   now pass `Check.IHead` plus a seed value; assertions unchanged),
   the D1 oracle re-pin (conflict C-B4 below), and six new cases
   M5B1 to M5B6 with their helpers (B10).
8. `dev/gates.sh`: the M5 Stage B section (5 legs).  SHIFT and
   SHARE-SIZE replay the captured kernel-suite output;
   FUEL-REACHABLE and RUNTIME-IDENTITY sit after the Stage A section;
   BRANCHING-20 is the new LAST leg in the file, after
   PASS-M4FIX-INST-BRANCHING (the round-5 lesson, per B11's
   placement).  The C-B2 Stage C handoff sentence and the B12
   chains-800 note are in the leg comments.
9. SPEC.md: NO Stage B edit (Stage D owns the entries, B15).

New `Error.t` variants: NONE.  New `Serror.t` variants: NONE.
`Cache.format_version`: UNCHANGED at 10.

### Tests added

Kernel (test/main.ml), 6 cases:
M5B1 (Term.shift over all eleven constructors at ~cutoff:1 ~by:2,
whole-term encoding-exact via Check.inst_key_enc), M5B2 (motive body
shifts at cutoff + |m_idx| + 1: bound Var 2 stays, free Var 3 -> 8),
M5B3 (branch body shifts at cutoff + |binders|: bound Var 1 stays,
free Var 2 -> 7), M5B4 (the nesting-16 branching nest through the
production Auto site prints term_size and asserts < 4000),
M5B5 (the plan B2 nesting-2 worked example end to end, compared
encoding-exact against the hand-spelled nest), M5B6 (the nesting-2
nest binds exactly 3 spine lets, so the second SC sub-goal was a memo
HIT).

### Gate markers added (dev/gates.sh)

PASS-M5B-SHIFT, PASS-M5B-SHARE-SIZE, PASS-M5B-BRANCHING-20,
PASS-M5B-FUEL-REACHABLE, PASS-M5B-RUNTIME-IDENTITY.  Exactly the five
the preamble reserves; the whole-output diff of the final gate run
against the entry run shows 12 added lines (6 suite PASS lines, the
`M5B4 term_size=694` print, 5 markers) and ZERO removed or changed
lines, so every pre-existing marker and error text is byte-identical
(the B6 conv-shortcut check).  Watchdog-literal corpus for Stage D:
`rg -c '"\$watchdog" [0-9]+' dev/gates.sh` prints 112 = 107 (Stage A
exit) + 5 (this stage: 10, 30, 30, 30, 30; B15's handoff numbers).

### Measured numbers (B14 criterion 6, beside the B0 numbers they replace)

- M5B4 `term_size` = 694 at nesting 16 (B0's derived closed form said
  S(16) = 662; B0 itself says the closed form is DERIVED and the
  kernel case prints the MEASURED number, which wins; the un-shared
  M4 tree at the same nesting is T(16) = 458714, so the nest is 661x
  smaller measured).  Under the inlining mutation the same print read
  1048518.
- PASS-M5B-BRANCHING-20: measured 0.034s (exit 0, `true`) against the
  10s budget, about 300x headroom; the SAME file on the M4 HEAD
  binary measured 30.188s to run and 31.570s to check (B0 P9/P10).
- Fuel pair on this binary: classes 60 exit 0 (`zero`, 0.176s, no
  fuel message), classes 61 exit 1 with the exact pinned message
  (B0 P14/P15 unchanged, so the leaf did not move).

### Mutation proofs (11 runs; every leg flipped by its own mutation, all reverted)

Runner: /Users/oobi/Documents/tot-m5-stageB-leg.sh (standalone leg
replicas, the Stage A pattern).  Full transcript with verbatim
outputs: /Users/oobi/Documents/tot-m5-stageB-mutations.log.  Digests:
lib/term.ml c4ee74826b8a6bd726743baf21045613, lib/check.ml
7bc5bb7af4611e6627247d59591a1705, identical before mutation and after
restore in every row.

1. M1 motive cutoff drops the + 1: FAIL M5B2, FAIL-M5B-SHIFT.  PASS
   after revert.
2. M2 branch cutoff becomes cutoff + 1: FAIL M5B3, FAIL-M5B-SHIFT.
3. M3 Var arm shifts unconditionally: FAIL M5B1 (M5B2/M5B3 flip too),
   FAIL-M5B-SHIFT.
4. M4 the inlining mutation (ISlot arm materializes the entry's term;
   local copy inside materialize, see transcript for the compile-order
   note): term_size 1048518, FAIL-M5B-SHARE-SIZE, AND
   FAIL-M5B-BRANCHING-20 (exit=124).  One mutation, both pinned legs,
   as the plan specifies.
5. M5 a memo HIT charges fuel: the POSITIVE fuel leg exits 1 with the
   exceeded-its-fuel line, FAIL-M5B-FUEL-REACHABLE (exit=1/1);
   BRANCHING-20 stayed green.
6. M6 the pinned floor doubling DID NOT FLIP (refuted; conflict C-B7);
   M6b replacement (width coefficient 8 -> 16) flips: the NEGATIVE
   leg exits 0 and resolves, FAIL-M5B-FUEL-REACHABLE (exit=0/0).
7. M7 ISlot j materialized as Var (i - 1): all four runtime files
   exit 1 at the re-check (memo-key: `type mismatch: expected
   (PC Nat), found (PC Bool)`), FAIL-M5B-RUNTIME-IDENTITY.
8. M8 the pinned shift-ignores-by mutation DID NOT FLIP (refuted;
   conflict C-B8); M8b replacement (slot arithmetic Var (i - j)):
   all four exit 1 with `unbound variable (index 1)`,
   FAIL-M5B-RUNTIME-IDENTITY.
9. M9 re-derive on a HIT (documented no-flip): RUNTIME-IDENTITY
   stayed green as designed.  OBSERVED-vs-PREDICTED: the plan's
   secondary claim that BRANCHING-20 fails on M9's cost is refuted;
   measured 6.212s, inside the 10s hang budget (183x the healthy
   0.034s).  Recorded: no Stage B timing leg pins the e_val cache's
   cost; Stage D's measurement log owns the cost half (B15).

### Conflicts (section 5 protocol)

Inherited from the plan, built as resolved there, not re-litigated:
C-B1 (instance_head_name deleted, islot_head added, payload text
unchanged), C-B2 (the fuel-leaf handoff to Stage C, written into the
FUEL-REACHABLE leg comment beside the K = 60 / K = 61 pair and the
2026-09-02 measurement date), C-B3 (the acc_v value accumulator;
old lib/check.ml:725 deleted).

New, found during this build:

- Conflict note C-B4 (2026-09-02): pin 1 (the Auto site emits the
  materialized nest for EVERY resolution) meets test/main.ml's D1,
  which pinned the M4 spelling `inst$Cls$Key` (no wrapping) as the
  exact printed resolution.  The two cannot both hold: a ground
  instance now materializes as a one-entry nest.  Resolution: the pin
  wins; D1's oracle is RE-PINNED to the new exact whole-term print
  `let dict$0 : (Cls Key) = inst$Cls$Key in dict$0` (still an
  exact-string assertion, not a weakening), with the note written at
  the case.  B10 listed only D7/D7b/D7c as changing call sites; D1 is
  a fourth, forced by pin 1 itself.
- Conflict note C-B5 (2026-09-02): plan B11's pinned FUEL-REACHABLE
  leg chains `&& out2=$(...)` on the NEGATIVE fixture, and a shell
  assignment's exit status is the substituted command's status, so
  the pinned spelling turns the fixture's correct exit 1 into a leg
  FAIL (a false red, verified against zsh semantics).  Resolution per
  section 5 rule 4: intent kept whole (same two runs, same oracles,
  same exit and message assertions), mechanism moved (both captures
  hoisted out of the && chain).  The leg was not shrunk.
- Conflict note C-B7 (2026-09-02): B11's pinned fuel mutation 2
  ("double inst_fuel's floor, Int.max 10000 -> 20000") does not flip
  at K = 61: the width term 8 * term_size * per_key = 26000 exceeds
  the doubled floor, so inst_fuel is unchanged and the leg stays
  green.  Per preamble 6.2 the mutation is REPLACED (width
  coefficient 8 -> 16), and the flip was proved (M6b: the negative
  leg resolves at exit 0).
- Conflict note C-B8 (2026-09-02): B11's pinned runtime-identity
  mutation 2 ("make Term.shift's Var arm ignore by") does not flip:
  both production shift call sites act on CLOSED terms in all four
  fixtures, so the mutation is behaviourally the identity there
  (M8 run recorded).  Per preamble 6.2 the mutation is REPLACED by
  the off-by-one slot arithmetic Var (i - j), which mis-scopes every
  nest, and the flip was proved (M8b: all four files exit 1 with
  Unbound_var).  The Var arm itself stays pinned by the SHIFT leg
  (M3), where open terms exist.
- Observed-vs-predicted (not a conflict): M5B4 prints term_size 694
  where B0's derived closed form said 662; B0 pins the MEASURED
  number as the authority and the assertion (< 4000) is unmoved.
  Likewise M9's secondary BRANCHING-20 claim, recorded under the
  mutation table.

### Exit criteria (B14), measured

1. `zsh dev/gates.sh` runs to exit 0 with BUILD-OK and TEST-OK
   (full log: /Users/oobi/Documents/tot-m5-stageB-gate.log).
2. Whole-output diff against the Stage A entry run: 12 added lines,
   0 removed, 0 changed; every Stage A marker green with no text
   change.
3. All five PASS-M5B-* markers print.
4. `rg -c '^PASS'` = 312 = 301 + 11.  Decomposed: kernel suite 101
   PASS lines (95 + 6), surface suite 106, gate markers 105
   (100 + 5).  `rg -c '^FAIL'` matches nothing (exit 1).  STAGE C
   CHAINS FROM 312.
5. Every B11 mutation RUN with its observed flip recorded above
   (11 runs; two pinned mutations refuted and replaced per 6.2, both
   replacements proved; transcript in
   /Users/oobi/Documents/tot-m5-stageB-mutations.log).
6. The measured term_size (694) and the measured BRANCHING-20 elapsed
   (0.034s) are recorded above beside the B0 numbers they replace.
7. `git status --porcelain` (UNSTAGED, nothing committed) shows Stage
   A's files plus Stage B's:

        M SPEC.md
        M bin/tot.ml
        M dev/gates.sh
        M examples/guard.tot
        M lib/check.ml
        M lib/eval.ml
        M lib/interp.ml
        M lib/pp.ml
        M lib/term.ml
        M surface/effect.ml
        M surface/run.ml
        M surface/serror.ml
        M test/main.ml
        M test/surface.ml
       ?? dev/M5-BUILD-LOG.md
       ?? dev/gen-inst-branching.py
       ?? dev/gen-inst-chains.py
       ?? lib/json_escape.ml
       ?? test/fixtures/m5a-*.json, m5a-*.tot (17 Stage A fixtures)
       ?? test/fixtures/m5b-inst-branching-20.tot
       ?? test/fixtures/m5b-inst-chains-8-40.tot
       ?? test/fixtures/m5b-inst-fuel-leaf.tot
       ?? test/fixtures/m5b-inst-fuel-under.tot
       ?? test/fixtures/m5b-inst-zero-dict.tot

### Gate output tails

    dune exec test/main.exe | tail -3
      PASS M5B5: a slot is materialized at i - 1 - j
      PASS M5B6: a memo HIT re-uses the cached value
      M0 kernel: all tests green

    dune exec test/surface.exe | tail -3
      PASS M5A-14: Run.script under strict_json=true turns a garbage stdin payload into the strict deny envelope and exit 2
      PASS M5A-15: Run.script under strict_json=false keeps the fail-open posture on the same payload (allow, exit 0)
      M1 surface: all tests green

    zsh dev/gates.sh | tail (final battery)
      PASS-M5A-STRICT-DENY
      PASS-M5A-STRICT-ALLOW
      PASS-M5B-SHIFT
      PASS-M5B-SHARE-SIZE
      PASS-M5B-FUEL-REACHABLE
      PASS-M5B-RUNTIME-IDENTITY
      PASS-M4FIX-INST-BRANCHING
      PASS-M5B-BRANCHING-20
      GATE-EXIT=0

## Stage C (2026-09-02): check budget, class-count fuel factor, driver contract

Plan: dev/M5-PLAN.md Stage C (sections C0 to C12).  Pins implemented:
P8, P9, P10, P11, P12, P19 (amendment A1), P21 (amendment A3).

### Entry state

Battery re-run BEFORE any edit, on commit 4f75130 plus Stage A's and
Stage B's UNSTAGED working-tree edits (log:
/Users/oobi/Documents/tot-m5-stageC-entry-gate.log):

    zsh dev/gates.sh                 GATE-EXIT=0 (BUILD-OK, TEST-OK)
    rg -c '^PASS'                    312
    rg -c '^FAIL'                    no match (exit 1)

The measured Stage B number is 312, exactly the recorded chain
(301 + 11), so Stage C chains from 312 and exits at 323.

### What changed

1. `lib/budget.ml` (NEW) and `lib/budget.mli` (NEW, the second
   interface file after lib/level.mli): opaque `Budget.t` holding one
   driver-supplied `poll : unit -> bool`;  `unlimited`, `of_poll`,
   `exhausted`.  `lib/` reads no clock, holds no mutable state, raises
   nothing (C1, pin 8).  `lib/dune` untouched.
2. `lib/error.ml`: nullary `Check_budget` variant;  `is_erased_use`'s
   false arm gains it (the round-4 clamp: the Zero fallback can never
   launder a budget cutoff);  `to_string` ("check budget exhausted")
   and `tag` ("Check_budget");  NEW exhaustive `is_check_budget`, no
   catch-all (C2).
3. `lib/check.ml`:
   - `ctx` gains `budget : Budget.t`;  `empty_ctx` seeds
     `Budget.unlimited`;  NEW `root_ctx`;  `bind`/`bind_def` become
     `{ ctx with .. }` updates so the budget propagates into every
     binder (C3.1).
   - `check` and `infer` are now polling WRAPPERS around the M4 bodies
     (`check_node`/`infer_node`, same `let rec .. and ..` group), so
     every kernel node polls;  `build_instance` polls in its own
     `match () with` guard, budget arm FIRST, before the fuel arm
     (C3.2).
   - The seven public entry points (`define`, `define_prim`,
     `define_axiom`, `define_instance`, `declare_ind`,
     `declare_ind_status`, `define_ind`) each gain
     `?(budget = Budget.unlimited)` and build their root context with
     `root_ctx budget`;  every existing call site compiles and behaves
     unchanged (C3.3).
   - NEW `instance_class_of` (the class half of an `inst$` mangled
     name, total) and `inst_table_stats` (ONE fold for max_binders AND
     the distinct-class count);  `inst_fuel` keeps the round-5 shape
     and multiplies by `1 + class_count` (C4, pin 12).
4. `surface/run.ml`: `item` and `script` gain
   `?(budget = Budget.unlimited)` (NOT a policy field;  three policy
   literals exist and an optional argument breaks none);  `item`
   passes `~budget` into all five `Check.*` entries it calls, the two
   `Check.empty_ctx` uses (ICheck at run.ml:451, IEval at :460, the
   plan's :442/:451 after Stage A/B drift) become
   `Check.root_ctx budget`, and the IClass recursive `item` calls
   thread `~budget` so class expansion stays budgeted (C5).
5. `surface/serror.ml`: NEW exhaustive predicates `is_check_budget`
   and `is_missing_main`, no catch-all (C6.2, C6.3).
6. `bin/tot.ml`: `opts.check_budget_ms` (default 0 = off);  the two
   `--check-budget-ms` parse arms (N4/N5/N6 negatives byte-exact);
   the usage line gains `[--check-budget-ms N]` (twin edited in
   test/surface.ml, same commit);  `budget_of_ms` (Sys.time CPU
   deadline, 1024-poll throttle, ms <= 0 -> unlimited);
   `run_with_prelude` builds the budget AFTER `cached_state_of_src`
   returns and `run_no_prelude`/`run_file` thread
   `~budget`/`~budget_ms`;  `run_file`'s error branch is now a
   four-arm `match () with` ladder: budget -> pinned line + literal 3,
   missing-main -> unchanged text + literal 1, Stage A's
   `driver_exit` -> literal 1, else `serror_exit` (C6).
7. `dev/bisect-inst-classes.sh` (NEW): the C7 stopping rule as an
   executable script (doublings 61/122/244/488, ceilings checked
   before each probe, bisection on first rejection, NOLEAF verdict,
   MARGIN-PIN line).
8. `dev/gates.sh`: the M5 Stage C section (7 legs) between the Stage B
   RUNTIME-IDENTITY leg and the M4FIX-INST-BRANCHING block
   (BRANCHING-20 stays the file's last leg);  the Gate D EXIT trap
   gains `$m5c_scratch`;  the FUEL-REACHABLE negative half re-pinned
   per conflict C-C3 below;  PASS-M4FIX-INST-CLASSES' comment gains
   the dated staleness sentence (C7).
9. `test/main.ml`: 3 kernel cases M5C1 to M5C3.  `test/surface.ml`:
   1 case M5C-S1 plus the case_usage_channel line edit;
   `case_require_main_rejects_mainless` untouched.
10. `SPEC.md`: the dated `2026-09-02 (M5, Stage C)` section 2 block
    (6 entries per C11);  section 6: the `--require-main` advisory
    entry REWRITTEN as retired with the new exit-1 repro, the
    `Check.inst_fuel` entry updated in BOTH halves (reach: factor +
    NOLEAF<=488;  time: the budget verdict replaces exit 124), the
    `.mli` debt line now reads "except `Level` and `Budget`", and the
    deferred check-budget line REMOVED (paid).

New `Error.t` variants: `Check_budget` (plus the `is_check_budget`
helper).  New `Serror.t` variants: NONE (two predicates added).
`Cache.format_version`: UNCHANGED at 10 (pin P1;  no marshaled shape
moved: `ctx` is not serialized, `Budget.t` is a driver value, and
`Term.t`/`Global.entry` are untouched this stage).

### Tests added

Kernel (test/main.ml), 3 cases:
M5C1 (an always-spent deterministic poll turns a trivial define into
Check_budget at its first node;  the omitted budget leaves the same
define green), M5C2 (in build_instance the budget arm outranks the
fuel arm: fuel 0 + spent budget = Check_budget, fuel 0 + unlimited =
Inst_depth), M5C3 (Check_budget's to_string, tag, is_check_budget and
its exclusion from is_erased_use, pinned).

Surface (test/surface.ml), 1 case:
M5C-S1 (Run.script ~budget with an always-spent poll returns
Kernel.Check_budget;  Serror.is_check_budget/is_missing_main pinned on
the live value and on Missing_main;  the no-budget default stays
green).  Edited: case_usage_channel's pinned line gained
`[--check-budget-ms N]`, byte-exact against the driver's own string.

### Gate markers added (dev/gates.sh)

PASS-M5C-BUDGET-FIRES, PASS-M5C-BUDGET-QUIET, PASS-M5C-DETERMINISM,
PASS-M5C-CLASSES-61, PASS-M5C-LEAF-MARGIN,
PASS-M5C-REQUIRE-MAIN-DRIVER, PASS-M5C-REQUIRE-MAIN-OK.  Exactly the
seven the preamble reserves.  Whole-output diff of the final battery
against the entry run: 11 added lines (3 kernel PASS, 1 surface PASS,
7 markers), 0 removed, and exactly ONE changed line, the
INFORMATIONAL D9f print `fuel=147312` -> `fuel=589248` (= x4 =
1 + class_count with D9f's 3 registered classes;  D9f's own assertion
is resolution and it still passes), so every pre-existing marker and
error text is otherwise byte-identical and no marker was lost.

Watchdog-literal corpus for Stage D:
`rg -c '"\$watchdog" [0-9]+' dev/gates.sh` prints 128 = 112 (Stage B
exit) + 16 (this stage: BUDGET-FIRES 2 x 30, QUIET 3 x 30,
DETERMINISM 3 x 30 inside the corpus loop, CLASSES-61 1 x 60,
LEAF-MARGIN 1 x 60, REQUIRE-MAIN-DRIVER 4 x 30,
REQUIRE-MAIN-OK 2 x 30).

### Measured numbers

- Budget fires (this binary): `check --check-budget-ms 1` on the
  8x800 chain exits 3, stdout 0 bytes, stderr exactly
  `<path>: check budget exhausted (1 ms)`;  identical line and exit
  under `--serror-exit 0`.
- Quiet: the trivial one-def target under a 1 ms budget ran 20 of 20
  at exit 0 (flake control, recorded in the gate comment;  ambient
  build load);  chains100 stdout byte-identical with and without a
  60000 ms budget.
- The re-bisection (zsh dev/bisect-inst-classes.sh, full log
  /Users/oobi/Documents/tot-m5c-scratch/bisect-run1.log):
      PROBE K=61  bytes=121645  secs=0.74  RESOLVES
      PROBE K=122 bytes=461560  secs=1.17  RESOLVES
      PROBE K=244 bytes=1875784 secs=10.60 RESOLVES
      PROBE K=488 bytes=7561960 secs=97.58 RESOLVES
      VERDICT: NOLEAF<=488
      MARGIN-PIN: K=122 (file<=1MB and run<=10s;  no margin invented)
  The LEAF-MARGIN pin is K = 122, bound by the 1 MB file ceiling
  (K = 244 breaches both ceilings).
- classes-61 on this binary: exit 0, `zero`, no fuel line, 0.16s user
  (the M4 leaf, paid;  on M4 HEAD this exact command exited 1 in
  0.16s with the N1 line).

### Mutation proofs (11 runs; every leg flipped by its own mutation, all reverted)

Runner: /Users/oobi/Documents/tot-m5-stageC-leg.sh (standalone leg
replicas, the Stage A/B pattern).  Full transcript:
/Users/oobi/Documents/tot-m5-stageC-mutations.log.  Digests (md5),
identical before mutation and after final restore:
bin/tot.ml 8457fc62e7d20fad1e30f11c491ca53e, lib/check.ml
6b56aa111dc470500824be8b6cb62398.

1. M1, PASS-M5C-BUDGET-FIRES.  bin/tot.ml: the is_check_budget arm
   neutralized (guard `&& false`;  DELETING the arm orphans
   `budget_ms`, warning-as-error, the C5-A precedent, so the
   deletion-equivalent neutralization is the mechanism).  RED: both
   legs, `FAIL-M5C-BUDGET-FIRES (exit=1/0)`, stderr took the
   `<path>:37:1: check budget exhausted` script-error shape, exactly
   the plan's predicted fall-through.  Reverted, leg PASS.
2. M2, PASS-M5C-BUDGET-FIRES.  bin/tot.ml: the budget arm returns
   `serror_exit` instead of the literal 3.  RED:
   `FAIL-M5C-BUDGET-FIRES (exit=1/0)`;  leg 2 exits 0 as pinned
   (exactly why the --serror-exit 0 leg exists).
   OBSERVED-vs-PREDICTED: the plan says "Leg 1 still passes";
   observed, leg 1 exits 1 (bare serror_exit defaults to 1, and the
   leg asserts exit 3), so BOTH legs flip;  the stderr LINE stayed
   byte-identical on both, which is the plan's real point.  Recorded,
   not absorbed.  Reverted, leg PASS.
3. M3, PASS-M5C-BUDGET-QUIET mutation 1.  bin/tot.ml: the deadline
   test replaced by an always-true compare past the throttle (a bare
   `true` orphans `deadline`, warning 26 as error).  RED: leg (a)
   exits 3 with `chains100.tot: check budget exhausted (60000 ms)`,
   `FAIL-M5C-BUDGET-QUIET (exit=3/0/0)`.  Reverted, leg PASS.
4. M4, PASS-M5C-BUDGET-QUIET mutation 2 AS PINNED (build the budget
   before the bootstrap): DID NOT FLIP (refuted;  conflict C-C6).
   The budget was hoisted above `Bootstrap.prelude_source ()` and leg
   (b) stayed green, 5 of 5 runs exit 0: the 1024-poll throttle means
   a sub-1024-node target never reads the clock at all, so even a
   pre-bootstrap deadline cannot fire on the trivial target.
5. M4b, the 6.2 REPLACEMENT: hoist kept AND throttle removed (every
   poll reads the clock).  RED: leg (b) exits 3 with
   `trivial.tot: check budget exhausted (1 ms)`,
   `FAIL-M5C-BUDGET-QUIET (exit=0/0/3)`;  leg (a) unaffected.
6. M4c, CONTROL: hoist reverted, unthrottled poll kept.  GREEN
   (PASS-M5C-BUDGET-QUIET), attributing M4b's flip to the EARLY
   CAPTURE and not to the throttle removal.  Reverted, md5 identical,
   leg PASS.
7. M5, PASS-M5C-DETERMINISM mutation 1.  bin/tot.ml: default
   `check_budget_ms = 1`.  RED: the no-flag runs of
   m4fix-inst-chains and chains100 exit 3 in both verbs while the 0
   and 60000 runs behave per flag (`exit=3/0/0` per member),
   `FAIL-M5C-DETERMINISM`.  The three small corpus members stayed
   green under the mutation (sub-1024 polls, throttle);  the corpus's
   chains members carry the flip.  Reverted, leg PASS.
8. M6, PASS-M5C-DETERMINISM mutation 2.  bin/tot.ml: `ms <= 0` ->
   `ms < 0`, so 0 becomes a zero-millisecond deadline.  RED: the
   no-flag AND --check-budget-ms 0 runs of both chains members exit 3
   (`exit=3/3/0`), `FAIL-M5C-DETERMINISM`.  This is the pin-11 "zero
   means off" leg.  Reverted, leg PASS.
9. M7, PASS-M5C-CLASSES-61 + PASS-M5C-LEAF-MARGIN mutation 2 +
   PASS-M5B-FUEL-REACHABLE (C-C3's replacement proof), one mutation,
   three flips.  lib/check.ml: the factor dropped, spelled
   `(1 + (0 * class_count))` (a bare drop orphans `class_count`,
   warning as error).  RED x3: CLASSES-61 exits 1 with the exact N1
   line (`cls61.tot:446:1: instance resolution for (C0 ((WPair
   ((WPair Waaaa) Wbbbb)) ((WPair Wcccc) Wdddd))) exceeded its
   fuel`), the measured M4 HEAD behavior byte for byte;  LEAF-MARGIN
   exits 1 with the same fuel line at `cls122.tot:873:1`;
   FUEL-REACHABLE's K = 61 half exits 1 with the N1 line
   (`exit=0/1`).  Reverted, all three PASS.
10. M8, PASS-M5C-REQUIRE-MAIN-DRIVER.  bin/tot.ml: `serror_exit`
    restored in the missing-main arm.  RED: the two --serror-exit 0
    legs exit 0, `FAIL-M5C-REQUIRE-MAIN-DRIVER (exit=1/0/1/0)`, the
    measured M4 mapping.  Reverted, leg PASS.
11. M9, PASS-M5C-REQUIRE-MAIN-OK.  bin/tot.ml: the driver arm widened
    from `is_missing_main e` to `true`.  RED: the ordinary-error leg
    exits 1 instead of 0, `FAIL-M5C-REQUIRE-MAIN-OK (exit=0/1)`;
    without this leg nothing stops A3 from being over-applied to the
    whole error channel.  Reverted, leg PASS.

Not executable, recorded per 6.2 (conflict C-C7): LEAF-MARGIN's
pinned mutation 1, "pin the gate at the leaf itself instead of 20
percent under it", has no executable form in the NOLEAF case (there
is no leaf to pin at;  the pin is an affordability pin, not a margin
pin).  The leg's proof burden is carried by mutation M7, which was
run and flipped it.

Tree state after the final revert: both md5s matched their
pre-mutation values and the full leg-replica battery ran green on the
restored tree (transcript tail).

### Conflicts (section 5 protocol)

Inherited from the plan, built as resolved there, not re-litigated:
C12.1 (no class registry;  class_count reads the instance table via
instance_class_of), C12.2 (exit 3 reserved by convention, the stderr
LINE is the discriminator, both budget gates assert it), C12.3 (the
QUIET leg runs the n=100 chain, not the unaffordable n=800 file).

New, found during this build:

- Conflict note C-C1 (2026-09-02): plan C6.1 pins the new usage line
  WITHOUT `[--strict-json]`;  the repo's line (Stage A, plan A4
  step 1) carries it, and dropping it would regress Stage A.  The C6.1
  text predates Stage A's edit.  Resolution: `[--check-budget-ms N]`
  is inserted at C6.1's position (after `[--serror-exit N]`, before
  `[--require-main]`) and `[--strict-json]` stays at Stage A's
  position;  both relative orders hold, both pins' intents kept:
  `usage: tot (check|run) [--no-prelude] [--no-axioms]
  [--serror-exit N] [--check-budget-ms N] [--require-main]
  [--strict-json] FILE | tot prims`.  Twin edited in the same commit.
- Conflict note C-C2 (2026-09-02): plan C6.2's ladder SNIPPET spells
  the missing-main print `path ^ ": " ^ ...` (wide separator);  pin
  P21, C0 item 5 and C6.3 all pin the TIGHT `":"` verbatim and C6.3
  explicitly says to write `path ^ ":" ^ ...`.  The snippet
  contradicts its own section's pin.  Resolution: the pin wins;  built
  with the tight separator, and PASS-M5C-REQUIRE-MAIN-DRIVER
  byte-asserts it.
- Conflict note C-C3 (2026-09-02): the C-B2 handoff (Stage B's
  FUEL-REACHABLE comment) says Stage C re-bisects and REGENERATES
  both m5b-inst-fuel fixtures at the new leaf with the leg's oracle
  unchanged.  The measurement proves that impossible: with the factor
  in, dev/bisect-inst-classes.sh reports NOLEAF<=488, charge and
  bound are both about quadratic in K on this shape (plan C4 predicts
  exactly this possibility), so NO affordable K rejects and an exit-1
  fuel-line oracle exists for no committed input.  Resolution per
  section 5 rule 4: the INTENT (the Inst_depth arm stays live and
  reachable at the production call site, proved by a flip) survives,
  the mechanism moves: both fixtures keep their committed bytes,
  the K = 61 negative half's oracle becomes RESOLUTION (exit 0,
  `zero`, no fuel), and the exact-fuel-line coverage is carried by
  mutation M7, which flips CLASSES-61, LEAF-MARGIN AND this leg with
  the N1 line observed.  The leg was not shrunk: same two fixtures,
  same production path, still mutation-flippable.
- Conflict note C-C4 (2026-09-02): plan entry state says the chain
  generator "takes the nesting as its one argument" and C8 example 2
  spells `gen-inst-chains.py 800`;  the committed Stage B generator
  takes TWO arguments (`gen-inst-chains.py K N`, its usage line) and
  the 800-box shape is `8 800` (the Stage B gate comment's own
  spelling).  Resolution: the committed generator wins (the plan's
  own instruction: follow Stage B's naming and change nothing);  the
  8x800 file is 7747 bytes against the plan probe copy's 7232, a
  header-comment-only delta the plan entry state itself anticipates.
- Conflict note C-C5 (2026-09-02): prose counts in C2 ("The false arm
  lists all 33 other constructors") are off by one: `Error.t` has 32
  constructors before `Check_budget` and 33 after, so each predicate's
  false arm lists 32 others.  The compiler's exhaustiveness check is
  the oracle;  recorded like Stage A's "7-character" note.
- Conflict note C-C6 (2026-09-02): QUIET's pinned mutation 2 refuted
  and replaced (mutation table rows 4 to 6;  the 1024-poll throttle
  masks a pre-bootstrap deadline from any sub-1024-node target, so
  the pinned hoist alone cannot flip leg (b);  replacement = hoist
  plus unthrottled poll, flip proved, control run attributing the
  flip recorded).
- Conflict note C-C7 (2026-09-02): LEAF-MARGIN's pinned mutation 1
  not executable under NOLEAF;  replaced by the factor-drop mutation
  per 6.2 (mutation table, row 9 and the note after it).
- Ladder note (compiler/behavior-forced, the C6-A precedent): plan
  C6.2's three-arm ladder predates Stage A and omits the shipped
  `Serror.driver_exit` arm (Json_strict_reject -> literal 1);
  dropping it would regress Stage A's pin 20 contract, so the built
  ladder has four arms, the two new ones first, Stage A's arm third,
  the mapping arm last.  No pre-existing assertion changed.

### Exit criteria (plan "Stage C exit criteria"), measured

1. `zsh dev/gates.sh` runs to exit 0 with BUILD-OK and TEST-OK (full
   log: /Users/oobi/Documents/tot-m5-stageC-gate.log);
   `rg -c '^PASS'` = 323 = 312 + 11.  Decomposed: kernel suite 104
   PASS lines (101 + 3), surface suite 107 (106 + 1), gate markers
   112 (105 + 7).  `rg -c '^FAIL'` matches nothing (exit 1).
   STAGE D CHAINS FROM 323.
2. test/main.exe and test/surface.exe both exit 0, including the
   edited case_usage_channel and the untouched
   case_require_main_rejects_mainless.
3. Every Stage C marker passed at least once with its stated mutation
   applied and observed to flip (table above;  transcript in
   /Users/oobi/Documents/tot-m5-stageC-mutations.log).
4. PASS-M4D-REQUIRE-MAIN, PASS-M4D-SERROR-EXIT,
   PASS-D-MISSING-FILE-CHANNEL, PASS-D-USAGE-CHANNEL,
   PASS-M4FIX-INST-CLASSES and PASS-M4FIX-INST-WIDE are all present
   in the final battery output (the six gates Stage C's edits pass
   closest to), and the whole-output diff shows no pre-existing
   marker lost or renamed.
5. `git status --porcelain` (UNSTAGED, nothing committed) shows Stage
   A's and Stage B's files plus Stage C's:

        M SPEC.md
        M bin/tot.ml
        M dev/gates.sh
        M examples/guard.tot
        M lib/check.ml
        M lib/error.ml
        M lib/eval.ml
        M lib/interp.ml
        M lib/pp.ml
        M lib/term.ml
        M surface/effect.ml
        M surface/run.ml
        M surface/serror.ml
        M test/main.ml
        M test/surface.ml
       ?? dev/M5-BUILD-LOG.md
       ?? dev/bisect-inst-classes.sh
       ?? dev/gen-inst-branching.py
       ?? dev/gen-inst-chains.py
       ?? lib/budget.ml
       ?? lib/budget.mli
       ?? lib/json_escape.ml
       ?? test/fixtures/m5a-* (17 Stage A fixtures)
       ?? test/fixtures/m5b-* (5 Stage B fixtures)

   Stage C commits NO new fixtures: the gate legs and the bisection
   generate theirs into watched scratch dirs at run time.

Arithmetic cross-check on criterion 1, measured on the final log:
`rg -c '^PASS '` (suite lines) = 211 = 104 + 107, and
`rg -c '^PASS-'` (gate markers) = 112;  211 + 112 = 323.

### Gate output tails

    dune exec test/main.exe | tail -4
      PASS M5C1: a deterministic always-spent poll stops a define at its first node
      PASS M5C2: the budget arm outranks the fuel arm in build_instance
      PASS M5C3: the Check_budget error surface is pinned
      M0 kernel: all tests green

    dune exec test/surface.exe | tail -2
      PASS M5C-S1: Run.script under an always-spent budget reports Kernel.Check_budget, and the default stays green
      M1 surface: all tests green

    zsh dev/gates.sh | tail (final battery)
      PASS-M5C-BUDGET-FIRES
      PASS-M5C-BUDGET-QUIET
      PASS-M5C-DETERMINISM
      PASS-M5C-CLASSES-61
      PASS-M5C-LEAF-MARGIN
      PASS-M5C-REQUIRE-MAIN-DRIVER
      PASS-M5C-REQUIRE-MAIN-OK
      PASS-M4FIX-INST-BRANCHING
      PASS-M5B-BRANCHING-20
      GATE-EXIT=0

## Stage D (2026-09-02): gate tiers, measurement log, dogfood, SPEC rewrite

Plan: dev/M5-PLAN.md Stage D (sections D0 to D12).  Pins implemented:
P17, P18; the whole pin set audited; Stage B's SPEC section 2 entries
written here per its B15 handoff.

### Entry state

Battery re-run BEFORE any edit, on commit 4f75130 plus Stages A, B and
C's UNSTAGED working-tree edits (log:
/Users/oobi/Documents/tot-m5-stageD-entry-gate.log):

    zsh dev/gates.sh                 GATE-EXIT=0
    rg -c '^PASS'                    323 (211 suite + 112 markers)
    rg -c '^FAIL'                    no match (exit 1)

The measured Stage C number is 323, exactly the recorded chain
(312 + 11), so Stage D chains from 323 and exits at 329.

### D0 corpus re-measurement (D0-1's own model, at Stage D entry)

Plan-time (M4 HEAD) numbers in parens:

    rg -c '\$watchdog' dev/gates.sh                 130  (91)
    rg -c '"\$watchdog" [0-9]+' dev/gates.sh        128  (89)
    rg -c '"\$watchdog" [0-9]+ ' dev/gates.sh       125  (86)
    rg -c '"\$watchdog" [0-9]+$' dev/gates.sh       no match, exit 1 (same)

Delta = the 39 executable sites Stages A to C added (A: 18 x 30;
B: 4 x 30 + 1 x 10; C: 14 x 30 + 2 x 60), exactly the build-log
handoffs; the 3 comment mentions and 2 numeral-free lines are the
D0-1 accounting unchanged.  Value histogram at entry: 5:8, 10:5,
15:26, 20:1, 30:82 (79 legs + 3 comments), 60:4, 120:1, 300:1.

Mapping-rule outcome, MEASURED: 125 executable legs -> FAST 13,
MED 106, SLOW 5, SUITE 1;  39 legs got a larger ceiling (8 moved
5->10, 26 moved 15->30, 1 moved 20->30, 4 moved 60->120), 86 kept
the same one, none shrank.  (Plan-time: 37 of 86.)

### What changed

1. `dev/gates.sh`:
   - The D1 tier block (FAST=10, MED=30, SLOW=120, SUITE=300,
     BITE_S=1) and the D2 `gate_timed` + `GATE_LOG` block, inserted
     between the watchdog probe and the suite legs.
   - All 125 executable watchdog literals rewritten to tier names;
     the 3 comment mentions now read "under the MED tier".
   - 18 perf call sites wrapped in `gate_timed` (2 suites, 9
     M4FIX-INST legs, FUEL-REACHABLE x2, RUNTIME-IDENTITY x4 via
     marker-prefixed per-run names, M5C-CLASSES-61, M5C-LEAF-MARGIN,
     M4FIX-INST-BRANCHING, M5B-BRANCHING-20).  The three M5C budget
     legs are perf legs by the fixture rule but split stderr on
     purpose (byte-exact stderr oracles), so per D2's channel rule
     they stay unwrapped.
   - The five Gate D deny `want` strings and the three M5A bypass
     wants rewritten per-payload for the D3 echo (plus
     `m5a_want_deny`, because `want` is a REUSED shell name
     upstream).
   - The M5 Stage D section (classifier run + six legs) inserted
     BEFORE the M4FIX-INST-BRANCHING block (D0-3);  the Gate D EXIT
     trap gains `$m5d_scratch`;  the battery now ends with a
     `GATE-LOG=<path>` line beside the caller's GATE-EXIT.
2. `examples/guard.tot`: `orEmpty` + `elideAt`, and the deny reason
   now echoes the blocked command, bounded at 2000 bytes (D3).
3. `examples/guard-rewrap.tot` (NEW, executable): the narrow port of
   the map-over-rewrap Bash guard (D4), helpers copied from
   guard.tot by design, fail-open posture.
4. `dev/hole-anchors.py` (NEW): the D5 static classifier plus the
   deliberately duplicated `--count-sites` walk.
5. `test/fixtures/`: m5d-echo-readback.tot, m5d-rewrap-deny.json,
   m5d-rewrap-allow.json (D8);  TIER-BITES reuses Stage C's
   run-time-generated chains800, no second copy.
6. `README.md`: the guard-rewrap paragraph and the PreToolUse
   install snippet (installation stays the operator's step).
7. `SPEC.md`: section 2 gains the 7-entry Stage D block (Stage B's
   sharing + re-check entries per B15, tiers P17, echo, rewrap port,
   hole anchors, the P18 audit entry);  section 6 rewritten per D7
   (retired: both JSON-conformance debts and the no-compute-budget
   debt;  restated with post-M5 numbers: TERM SIZE at the same
   shapes, holes with the measured anchors, WF spike ownership,
   nested-inductives reason corrected to the MUTUAL gap, Frozen tied
   to the spike;  regex/prim-trust/Div carried verbatim;  five new
   Stage D debts appended incl. pin 7's unspent key-type sharing).
   The require-main and inst_fuel entries were already Stage C's.

New `Error.t`/`Serror.t` variants: NONE.  OCaml sources: UNTOUCHED
(mutation M1's escaper revert was applied and reverted, md5-proved).
`Cache.format_version`: UNCHANGED at 10 (pin P1).

### Measured numbers

- PASS-M5D-TIERS population: nolit exit 1;  116 direct tier uses
  (125 legs - 18 wrapped call sites + 9 Stage D uses: TIER-BITES 2,
  GUARD-ECHO 2, REWRAP 3, HOLE-ANCHORS 1, classifier run 1);
  2 BITE_S calibration uses.  N = 116 is the LIVE literal.
- Measurement log at MEASURE-LOG leg time: 18 MEASURE lines, all
  exit=0, plus the ANCHORS line;  after the full battery: 20 MEASURE
  lines (M4FIX-INST-BRANCHING and M5B-BRANCHING-20 log downstream,
  0.027s and 0.028s on the final run).
- Hole anchors (dev/hole-anchors.py, corpus = stdlib/prelude.tot 176
  lines + examples/*.tot 354 lines = 530;  plan-time corpus was 325
  before the Stage A comments, D3, and the new third guard):
  ANCHORS total=98 E=59 A=9 N=30;  --count-sites prints 98
  independently;  full site list re-emitted by running the script
  bare.  The three plan archetypes reproduce (nil String -> E,
  none Json -> E, pureIO Verdict allow -> E).
- Post-M5 branching timings at the SAME shapes (SPEC 6 item 4;  M4
  numbers in parens): nesting 20 check 0.07s / run 0.15s (19.6s);
  nesting 16 about 0.08s (1.03s);  nesting 12 about 0.02s (0.064s).
- TIER-BITES leg cost about 15s as stated in its comment (a=124 cut
  at FAST on chains800, BITE_S cuts the 3s sleeper and the tail -f
  hang, FAST passes the sleeper).
- Envelopes: deny.json now ends `(command: grep foo /tmp/x)`;  the
  tab/newline payloads carry the two-character escapes on the wire;
  the pair/bmp fixtures echo raw UTF-8 (>= 0x80 unescaped).

### Gate markers added (dev/gates.sh)

PASS-M5D-TIERS, PASS-M5D-TIER-BITES, PASS-M5D-GUARD-ECHO,
PASS-M5D-REWRAP-GUARD, PASS-M5D-HOLE-ANCHORS, PASS-M5D-MEASURE-LOG.
Exactly the six the preamble reserves.  Whole-output diff of the
final battery against the entry run: 8 added lines (6 markers, the
GATE-LOG path line, the GATE-EXIT line this stage's logging appends
into the file), 0 removed, 0 changed, so every pre-existing marker
and error text is byte-identical and no marker was lost.

### Mutation proofs (18 runs + 1 documented non-mutation; all reverted)

Runners: /Users/oobi/Documents/tot-m5-stageD-leg.sh (replicas),
/Users/oobi/Documents/tot-m5-stageD-legx.sh (runs a leg EXTRACTED
from dev/gates.sh as written, so a gates.sh mutation is observed on
the mutated bytes themselves), plus two full-battery runs where the
battery itself shows the red.  Full transcript with verbatim outputs
and per-row md5s: /Users/oobi/Documents/tot-m5-stageD-mutations.log.
Baseline digests, identical before mutation and after every restore:
dev/gates.sh 37f1ae9beaacedf8d208e026cfa8f6c2, examples/guard.tot
2950e1a67114857192762c626d973aba, examples/guard-rewrap.tot
7809cb7ca7466d43b6eabdb016b93abe, dev/hole-anchors.py
bffa355a5f1590daaf68d3062376ae9e, surface/effect.ml
b50915fdb47b92d2f117fc83ca0ff6e3, test/fixtures/m5d-echo-readback.tot
e836359c662b756eefbdb34e549d262d, SPEC.md
21d46a473ad8852f8d40a516b22c9732.

1. TIERS M1, a numeric literal restored at the M5A-FIXTURE-BYTES
   leg: FAIL-M5D-TIERS (nolit=0 tiers=115).  Reverted, PASS.
2. TIERS M2, that whole leg deleted (3 lines): FAIL-M5D-TIERS
   (nolit=1 tiers=115) -- the delete-only signal M1 cannot see,
   exactly why -eq stays.  Restored, PASS.
3. TIERS M3, BITE_S renamed to the numeral 1 in both calibration
   legs: FAIL-M5D-TIERS (nolit=0, bites empty), the double flip as
   pinned.  Reverted, PASS.
4. TIER-BITES M1, sleeper calibration raised BITE_S -> FAST:
   extracted leg FAIL-M5D-TIER-BITES (a=124 b=0 b2=124 c=0);  ALSO
   observed at file level, PASS-M5D-TIERS red (tiers=117 bites=1),
   so the battery catches the same edit twice.  Reverted, PASS.
   (Revert note: the first revert sd hit the FAST control line too;
   repaired to baseline md5, recorded in the transcript.)
5. TIER-BITES M2, BITE_S=5 in the tier block: extracted leg
   FAIL-M5D-TIER-BITES (b=0).  Reverted, PASS.  (Revert note: the
   revert sd also touched the leg comment's BITE_S=5 mention;
   repaired to baseline md5, recorded.)
6. TIER-BITES M3, stated NON-mutation per plan D9: raising leg (a)
   FAST -> SLOW keeps a=124 and only slows the leg;  not run,
   recorded as the reason leg (b) exists.
7. GUARD-ECHO M1, envelope escaper reverted to Pp.escape_string
   (surface/effect.ml, rebuilt): FAIL-M5D-GUARD-ECHO (c1=2 c2=2
   raw=0), the raw byte on the wire.  OBSERVED-vs-PREDICTED: the
   plan said c2 flips to 0 via jsonParse rejecting the raw byte;
   observed c2=2, because a raw C0 inside a parsed string body still
   PARSES (Stage A deliberate non-change 1, the conflict C4-A repo
   fact).  The leg flipped on raw and on the missing escape either
   way;  not shrunk.  Reverted, rebuilt, PASS.
8. GUARD-ECHO M2, the (command: ...) echo dropped from guard.tot:
   FAIL-M5D-GUARD-ECHO (c1=2 c2=2 raw=1, u0001 assertion failed).
   Restored byte-identical, PASS.
9. GUARD-ECHO M3, readback returns allow on a successful parse:
   FAIL-M5D-GUARD-ECHO (c2=0, e2 empty).  Reverted, PASS.
10. REWRAP M1, rewrapVerdict's pair-true arm returns allow:
    FAIL-M5D-REWRAP-GUARD (rd=0, deny empty).  Restored, PASS.
11. REWRAP M2 AS PINNED, the .rs test dropped (made always-true):
    DID NOT FLIP, leg stayed green -- REFUTED per preamble 6.2: BOTH
    committed fixtures' commands mention .rs (each heredoc writes
    f.rs), so widening the test changes neither verdict.
12. REWRAP M2b REPLACEMENT, the PAIR test forced always-true:
    FAIL-M5D-REWRAP-GUARD (rd=2 ra=2, allow non-empty), the
    deny-everything regression the ALLOW leg exists to catch.
    Reverted, PASS.
13. REWRAP M3, echo dropped from the deny reason (deny kept):
    FAIL-M5D-REWRAP-GUARD (the let-line assertion failed).
    Restored, PASS.
14. HOLE-ANCHORS M1, the ANCHORS line no longer written to the log:
    FAIL-M5D-HOLE-ANCHORS (anchors empty).  Reverted, PASS.
15. HOLE-ANCHORS M2, liftIO anchors bucketed as bogus X with total
    untouched: FAIL-M5D-HOLE-ANCHORS (t=98, e+a+n=96, sum check).
    Reverted, PASS.
16. HOLE-ANCHORS M3, liftIO sites dropped from the CLASSIFIER walk
    only (2 anchors on this corpus;  the plan says one site, same
    flip class): buckets and total move TOGETHER (t=96 = sum), and
    the INDEPENDENT count catches it (sites=98).  Reverted, PASS.
17. MEASURE-LOG M1, one gate_timed wrapper deleted (BINDERS runs
    bare): full battery exits 1 at FAIL-M5D-TIERS (tiers=117), the
    population count catching the same edit first;  the leg's OWN
    flip shown on the log that mutated battery produced:
    FAIL-M5D-MEASURE-LOG (lines=17, name set missing
    M4FIX-INST-BINDERS).  Reverted, PASS.
18. MEASURE-LOG M2, SPEC's expected-type-only moved 59 -> 60:
    FAIL-M5D-MEASURE-LOG (logE=59 specE=60).  Reverted, PASS.
19. MEASURE-LOG M3, gate_timed prints elapsed=%d: full battery runs
    every upstream leg green and exits 1 at FAIL-M5D-MEASURE-LOG
    with the schema count empty (zsh %d truncates the float, no .3
    fraction).  Reverted, PASS.

Tree state after the final revert: every digest above matched its
pre-mutation value, no .m5dorig backup remains, and the final full
battery below ran on the restored tree.

### Conflicts (section 5 protocol)

- Conflict note C-D1 (2026-09-02): plan D1's pinned sd recipe
  (`sd '"\$watchdog" 300 ' '"$watchdog" "$SUITE" ' dev/gates.sh`,
  eight rows) is proved wrong by execution: in sd a `$NAME` in the
  REPLACEMENT is a capture-group reference, so `$watchdog`/`$SUITE`
  expanded to EMPTY and every executable site briefly read `"" ""`.
  Resolution per section 5 rule 4: the intent (rewrite every literal
  to its tier name by the smallest-tier-not-below rule) was kept
  whole and the mechanism moved to a scripted per-line rewrite;  the
  within-tier information the mangling lost is recoverable because
  the MAPPING is tier-lossy anyway (5/10 -> FAST, 15/20/30 -> MED,
  60/120 -> SLOW, 300 -> SUITE): each line's tier was reconstructed
  from the M4 file in git (`git show 4f75130:dev/gates.sh`) plus the
  A/B/C build-log handoffs (cls61/cls122 -> SLOW,
  m5b-inst-branching-20 -> FAST, all other additions MED), zero
  unresolved, and the post-repair histogram (FAST 13, MED 106,
  SLOW 5, SUITE 1) equals the entry-state mapping table exactly.
- Conflict note C-D2 (2026-09-02): plan D1/D12 pin
  `rg -c '"\$watchdog" "\$BITE_S"'` = 2, but the pinned TIER-BITES
  snippet carries exactly ONE such use (the 3s sleeper;  the gate's
  own assertion line does not self-match, by the D1 backslash
  argument).  Resolution: a SECOND calibration use was added, the
  probe P26 shape itself ("$watchdog" "$BITE_S" tail -f /dev/null,
  a never-terminating hang, asserted 124), which can only strengthen
  the leg;  both pins hold as written.
- Conflict note C-D3 (2026-09-02): plan D3's `elideAt` spells the
  Ordering match gt/eq/lt;  the built binary rejects it
  (`match branches do not fit the declaration: expected lt, found
  gt`, exit 1): tot pins match arms to declaration order.
  Resolution: same three named arms in declaration order lt/eq/gt;
  behaviour identical, compiler-proved.
- Conflict note C-D4 (2026-09-02): plan D9 says MEASURE-LOG runs
  "after every perf leg" and worked example W4 shows the ANCHORS
  line after M4FIX-INST-BRANCHING's MEASURE line;  plan D0-3 forbids
  any Stage D leg after the branching block, and the branching pair
  are perf legs.  Both cannot hold.  Resolution: D0-3 wins (it
  defends a dated repo claim);  the leg asserts the 18 UPSTREAM
  MEASURE lines and the two downstream wrapped legs log after it,
  for the operator via the battery-end GATE-LOG line;  W4's line
  order is a worked example, not an oracle, and the divergence is
  stated in the leg comment.
- Conflict note C-D5 (2026-09-02): plan D3's blast radius ("exactly
  one line pins the old reason string", gates.sh:393) is stale on
  the Stage D entry tree: Stage A added a second pin (m5a_want, four
  bypass payload comparisons plus STRICT-ALLOW's reuse), and the
  echo makes the expected envelope PER-PAYLOAD.  Resolution: the
  Gate D want split into want/want_path/want_tab/want_nl/want_ts,
  the M5A wants into m5a_want/m5a_want_pair/m5a_want_bmp plus
  m5a_want_deny (the deny.json envelope re-spelled locally, because
  `want` is a reused shell name whose Gate D value does not survive
  to the M5A section -- caught as a live red in build iteration 2).
  No assertion was weakened: every comparison is still a whole-line
  byte equality against the measured envelope.
- Conflict note C-D6 (2026-09-02): plan D12 item 7 expects
  `rg -l` on the rg/sd house-rule reason prefix to list exactly
  three files;  measured on this tree it lists FOUR:
  dev/gates.sh, examples/guard.tot, dev/M3-PLAN.md and
  dev/M5-PLAN.md, the last being the in-tree plan text itself
  (committed at 4f75130, after the pin was drafted), which quotes
  the envelope in its own D3/W2 sections and must not be edited.
  Resolution: the pin's intent holds (no stale executable pin of
  the OLD constant envelope survives anywhere;  both live pins were
  updated);  the fourth file is frozen history, recorded here.
- Conflict note C-D7 (2026-09-02): REWRAP M2 refuted and replaced
  (mutation rows 11 and 12): the pinned "drop the .rs test" cannot
  flip because both committed fixtures mention .rs;  the replacement
  forces the PAIR test true and flips the allow leg, proving the
  deny-everything regression is caught.  The fixtures keep the plan
  D8 bytes (the .rs mention in the allow payload is what makes the
  allow leg test the PAIR criterion rather than the cheap .rs one).
- Build note (not a conflict): the first wrap pass missed the
  M4FIX-INST-MEMO-KEY leg (its call line is a twin of the
  RUNTIME-IDENTITY fourth run;  caught by PASS-M5D-MEASURE-LOG going
  red at lines=17 in build iteration 3, the gate doing its job
  before any mutation was run).  Wrapping it moved one direct tier
  use into gate_timed, so N was re-pinned 117 -> 116 in the same
  edit, with the arithmetic in the gate comment and above.

### SPEC audit (D6, a check, not a gate)

`rg -c '^- 2026-09-02 \(M5' SPEC.md` = 21 (8 Stage A + 6 Stage C +
7 Stage D).  Pin coverage read entry by entry: pins 1 to 5 and 7
(sharing entry), 6 (re-check entry), 8 to 12 and 19, 21 (Stage C
entries), 13 to 16, 20, 23 (Stage A entries, amendment A5 cited
twice), 17 and 18 (Stage D entries).  Pin 22 is OWED BY STAGE E and
recorded as such inside the P18 entry, not missing.  The
`expected-type-only=59` token appears exactly once in SPEC.md (the
section 6 holes entry), which PASS-M5D-MEASURE-LOG requires.

### Exit criteria (D12), measured

1. `rg -q '"\$watchdog" [0-9]' dev/gates.sh` exits 1.
2. Tier uses 116 (the pinned live N, recipe in the gate comment) and
   BITE_S uses 2.
3. FAST/MED/SLOW/SUITE/BITE_S each defined exactly once.
4. The measurement log holds 18 MEASURE lines at leg time (20 after
   the battery) plus one ANCHORS line, and its expected-type-only
   number equals SPEC's (pinned by the leg itself).
5. All SIX PASS-M5D-* markers present, exactly the reserved six;
   scope items 10 and 11 each carry their own marker.
6. guard.tot, guard-classes.tot and guard-rewrap.tot each check
   (exit 0) and run through their own shebang (exec bits set;
   guard-rewrap.tot's bit set this stage).
7. The Gate D want block carries the new per-payload envelopes;  the
   reason-prefix file list is FOUR files (conflict note C-D6).
8. SPEC audit above: P1 to P21 and P23 present, P22 recorded as owed
   by Stage E.
9. Section 6 carries the D7 retire-or-restate edits (including the
   M3-era conformance twin and the no-compute-budget entry, both
   stale post-M5) and the five new debts.
10. Full battery green: GATE-EXIT=0,
    `rg -c '^PASS'` = 329 = 323 + 6.  Decomposed: kernel suite 104,
    surface suite 107, gate markers 118 (112 + 6);
    `rg -c '^FAIL'` matches nothing (exit 1).  Whole-output diff vs
    the entry run: 8 added lines (6 markers + GATE-LOG + GATE-EXIT),
    0 removed, 0 changed, so all 278 M4 markers and every A/B/C
    marker are present by name.  Logs:
    /Users/oobi/Documents/tot-m5-stageD-gate.log and
    -gate-run2.log (independent second run).
    STAGE E CHAINS FROM 329.
11. PASS-M4FIX-INST-BRANCHING still sits after every Stage D leg;
    only its round-5 sibling PASS-M5B-BRANCHING-20 follows it, the
    Stage B placement, unchanged.
12. Nothing staged, nothing committed;  porcelain shows all edits
    unstaged (M) and new files untracked (??);  nothing outside
    /Users/oobi/Documents/tot was edited (the guard install snippet
    is PRINTED in README.md, ~/.claude/settings.json untouched).

### Stage E handoff

- The watchdog corpus is now NAMED TIERS ONLY: 116 direct tier uses,
  2 BITE_S calibration uses, 20 gate_timed perf runs.  Any Stage E
  leg wears `"$watchdog" "$FAST|MED|SLOW|SUITE"` and RAISES the
  PASS-M5D-TIERS literal N=116 by the number of uses added (recipe
  in the gate comment), measured before and after, both numbers
  recorded in this log.  A Stage E perf leg that merges 2>&1 may
  wrap in gate_timed instead;  that instead raises the
  PASS-M5D-MEASURE-LOG count (18) and its sorted name-list literal,
  IF the wrap sits upstream of that leg.
- The SPEC token `expected-type-only=59` must stay single-occurrence
  in SPEC.md;  quote the E number in prose elsewhere.
- The measurement log path is `${TOT_GATE_LOG:-$TMPDIR/tot-gate-measure.log}`,
  truncated at battery start, echoed at battery end.
- Stage E owes pin P22's dated SPEC section 2 block (the section 6
  WF entry already points at it) and, per the audit, nothing else.

## Stage E (2026-09-02, closed 2026-09-03): well-founded recursion SPIKE behind --experimental-wf

Plan: dev/M5-PLAN.md Stage E (sections E0 to E10).  Pin implemented:
P22 (amendment A4).  The calendar rolled over mid-stage;  the SPEC
entries keep the milestone's pinned `2026-09-02` dating per plan E9,
and this heading records the rollover.

### Entry state

Battery re-run BEFORE any edit, on commit 4f75130 plus Stages A to D's
UNSTAGED working-tree edits (log:
/Users/oobi/Documents/tot-m5-stageE-entry-gate.log):

    zsh dev/gates.sh                 GATE-EXIT=0
    rg -c '^PASS'                    329 (211 suite + 118 markers)
    rg -c '^FAIL'                    no match (exit 1)

The measured Stage D number is 329, exactly the recorded chain
(323 + 6), so Stage E chains from 329 and exits at 334.

### What changed

1. `test/fixtures/m5e-acc.tot` (NEW) and `test/fixtures/m5e-witness.tot`
   (NEW), byte for byte the plan E3 declarations, with the header
   comments placed BELOW the pinned items so `accRec` stays at 5:1 and
   `bad` at 2:1.  Both pins reproduced on the Stage D binary before any
   code landed (exit 1, empty stdout, the exact guard line on stderr).
2. `dev/gen-m5e-transcript.sh` (NEW, executable): the E6.1 corpus
   transcript generator (conflict note C-E1 below on its one changed
   line).  Run at Stage D exit and committed as
   `dev/m5e-default-transcript.txt`: 9660 lines, 653286 bytes, 80
   corpus files (`examples/*.tot` + `test/fixtures/*.tot`, LC_ALL=C
   sorted), including both new fixtures at their exit-1 verdicts.
   Generated twice at Stage D exit: byte-identical, so the oracle is
   deterministic.
3. `lib/totality.ml`: `type rule = Structural | Structural_wf`;
   `guard`/`passes` take a required `~rule`;  `guarded_call`'s
   argument match gains the flag-gated `App` arm (spine head must be a
   variable already `Smaller`).  The `scrut_special` precondition is
   UNTOUCHED.  Nothing else in the module changed.
4. `lib/check.ml`: `define` gains REQUIRED `~rule` and threads it to
   `Totality.guard`;  `define_instance`'s internal call passes
   `~rule:Totality.Structural` literally.
5. `surface/run.ml`: `policy` gains `wf_rule : Totality.rule`;
   `default_policy` sets `Totality.Structural` (the prelude bootstrap
   folds with `default_policy`, so no flag can enter the cache key);
   the `IDef` arm passes `~rule:policy.wf_rule`.
6. `bin/tot.ml`: `opts.experimental_wf` (default false), the
   `--experimental-wf` parse arm, the usage line, and the one
   `dispatch` mapping to `Totality.Structural_wf`/`Structural`.
7. `test/main.ml`: the 28 plain `Check.define` call sites gain
   `~rule:Totality.Structural` (the required argument made the
   compiler enumerate them);  cases E1 and E2 added (below).
8. `test/surface.ml`: the three `Run.policy` literals gain
   `wf_rule = Tot_kernel.Totality.Structural`;  the byte-exact usage
   pin moves WITH the usage string per its own comment.
9. `dev/gates.sh`: the Stage E section (scratch + three legs) inserted
   AFTER the Stage D section and BEFORE the two branching legs;  the
   Gate D EXIT trap gains `$m5e_scratch`;  the `PASS-M5D-TIERS`
   literal raised 116 -> 122 in the same edit (six new direct tier
   uses: 1 SLOW + 5 FAST;  recipe run before and after: 116, 122).
10. `SPEC.md`: section 2 gains the seven-entry
    `2026-09-02 (M5, Stage E, SPIKE)` block (pin P22 paid;  total M5
    dated entries 21 -> 28);  section 5's `M5:` bullet became the M6
    candidate list carrying the spike's numbers;  section 6's WF entry
    updated in place from "Stage E will carry" to DELIVERED, with the
    measured/not-closed residual (text below).  The
    `expected-type-only=` token stays single-occurrence (verified: 1).

New `Error.t`/`Serror.t` variants: NONE.  `Cache.format_version`:
UNCHANGED at 10 (pin P1);  `surface/cache.ml` untouched.  No default
path behavior change: the whole check corpus is byte-identical (gate
E (i), plus two direct regenerate-and-diff runs).

### Tests added

- `E1: Structural_wf accepts the accRec call shape` (test/main.ml).
  The stamped accRec body built by hand;  `Totality.guard
  ~rule:Structural_wf` returns `Ok 5` and `~rule:Structural` returns
  `Error (Error.Termination "accRec")`, pinned by tag AND rendered
  message.
- `E2: Structural_wf still rejects the panel witness` (test/main.ml).
  The witness body under BOTH rules gives
  `Error (Error.Termination "bad")`, same double pin.

### Gate markers added (dev/gates.sh)

PASS-M5E-DEFAULT-IDENTITY, PASS-M5E-ACC-CHECKS,
PASS-M5E-WITNESS-REJECTED.  Exactly the three the preamble reserves.
Whole-output diff of the final battery against the entry run: 5 added
lines (2 suite PASS lines + 3 markers), 0 removed, 0 changed, so every
pre-existing marker and error text is byte-identical and no marker was
lost.  The branching pair stayed quiet on all three battery runs (no
timing flake, no isolation re-run needed).

### Measured numbers

M1, WHICH GUARD SHAPES THE CLAUSE UNLOCKS (runner
/Users/oobi/Documents/tot-m5e-probes/run-probes.sh, scratch fixtures
outside the repo):

    shape   no flag                          under --experimental-wf
    accRec  exit 1 (5:1 guard line)          exit 0 (five pinned lines)
    bad2    exit 1 (2:1 guard line)          exit 0
    bad     exit 1 (2:1 guard line)          exit 1, byte-identical output
    bad3    exit 1 (2:1 guard line)          exit 1

TWO of the four rows flip.  The clause is NOT specific to
accessibility: `bad2` (infinitary structural recursion over a
variable scrutinee) is unlocked at the same time as `accRec`, exactly
the row the panel did not state.  M6 must decide one feature or two.

M2, COST IN THE CHECKER (runner run-timings.sh, three runs each at
Stage E exit, all three values recorded, medians named):

    suite-kernel    0.198 / 0.245 / 0.129   median 0.198s
    suite-surface   0.607 / 0.862 / 1.175   median 0.862s
    gen-transcript  9.722 / 5.039 / 5.547   median 5.547s
    acc-flagged     0.025 / 0.024 / 0.018   median 0.024s

Stage D exit comparison (deviation, recorded in conflict note C-E2):
the flagged command did not EXIST at Stage D exit (`unknown flag`,
exit 2, probe P8), and the Stage D binary was rebuilt in place before
the plan's D-exit medians could be taken, so the D-exit observations
are the salvaged entry-battery gate_timed lines (single runs under
battery load, /Users/oobi/Documents/tot-m5-stageE-entry-measure.log):
SUITE-KERNEL 0.686s, SUITE-SURFACE 1.517s;  final-battery E-exit
lines: 1.177s and 2.623s (same harness, ambient-load noise;  the bare
three-run medians above show the suites themselves did not slow).
The two D-exit transcript generations completed un-timed in the same
session;  byte-identity is the load-bearing D-vs-E comparison and it
is exact.  Not tuned;  Stage E does not optimize.

M3, DOES `Frozen_rec` BECOME LOAD-BEARING.  No.  The `(0 a : Acc A R
x)` variant under the flag fails `erased variable a used at runtime`
at 5:1, exit 1 (probe E5.4), before any totality question: `acc`
carries two runtime fields, so `Acc` is not zero-eliminable under the
M4 fence.  The three plan sentences (Frozen stays dead code for every
Acc shape M5 can build;  Frozen_rec buys nothing until Acc gains an
erased elimination form, a subsingleton-fence change;  the two are
COUPLED and M6 sizes them together or neither) are recorded in the
SPEC entry.

### Mutation proofs (4 runs: 3 flips + 1 compile refutation; all reverted)

Runner: /Users/oobi/Documents/tot-m5e-probes/legx-e.sh, which extracts
gate legs E(i)..E(iii) from dev/gates.sh AS WRITTEN (awk range from
`# Gate E (i)` to `# ctxcat id 5:`, emptiness-guarded) and executes
them against the current build.  All three mutations are OCaml
mutations;  dev/gates.sh was never mutated in this stage.  Baseline
digests, identical before mutation and after every restore:
bin/tot.ml 9c56093da1a221a4480e2dcba460a1f1, lib/totality.ml
ed48fc4fa37879f6a744a26b150996c4.

1. DEFAULT-IDENTITY M1: `dispatch` sets
   `wf_rule = Tot_kernel.Totality.Structural_wf` unconditionally.
   Observed flip: the m5e-acc.tot transcript block goes from the
   one-line guard message at exit 1 to the five-line success at
   exit 0, the diff is non-empty, `code2` goes 0, and the leg prints
   `FAIL-M5E-DEFAULT-IDENTITY (exit=0/0)`.  BOTH halves failed, so the
   transcript half and the direct half are each proved live.
   Reverted, rebuilt, all three legs PASS.
2. ACC-CHECKS M2: the new `App` arm returns `false` for
   `Structural_wf` too.  Observed flip: gate E (i) stays green (the
   default path is untouched), accRec returns to exit 1 with the
   `... failed the structural termination guard` line, `$out` stops
   matching `$want`, `FAIL-M5E-ACC-CHECKS (exit=1)`.  Reverted,
   rebuilt, PASS.
3. WITNESS-REJECTED M3 AS PINNED ("scrut_special deleted",
   `binder_status = Smaller` unconditionally): DOES NOT COMPILE --
   REFUTED per preamble 6.2: deleting the computation orphans
   `principal_or_smaller_at` and the build fails
   `E lib/totality.ml:84:6 unused-var`, so the mutated binary never
   exists and no leg can flip.  REPLACEMENT, same semantics: keep the
   `scrut_special` computation, mutate only the conditional to
   `if scrut_special then Smaller else Smaller` (the precondition
   dropped, the computation still consumed).  Observed flip: leg (b)
   goes exit 0 (the witness CHECKS under the flag: `data T / ctor mk /
   def bad` print), `codeb` stops being 1,
   `FAIL-M5E-WITNESS-REJECTED (exit=0/0/1)`;  leg (c) stays exit 1
   with the guard line, because without the flag `guarded_call` still
   demands a bare `Term.Var` and `bad` supplies the application
   `g zero`.  The mutation therefore proves the PRECONDITION, not the
   flag;  leg (a) proves the flag.  Reverted, rebuilt, PASS.

Tree state after the final revert: both digests matched their
pre-mutation values and the final full battery below ran on the
restored tree.  All mutations reverted;  none remains.

### Conflicts (section 5 protocol)

- Conflict note C-E1 (2026-09-03): plan E6.1 pins the transcript
  script line `scratch=$(mktemp -d) || exit 9`;  executed on this
  machine the bare `mktemp -d` resolves to the Darwin per-user temp
  dir and fails under the build sandbox (`mkdtemp ... Operation not
  permitted`, script exit 9), while every scratch in dev/gates.sh
  uses the `"${TMPDIR:-/tmp}/name.XXXXXX"` template form and works.
  Resolution: the pinned INTENT (a self-cleaning scratch) survives,
  the mechanism becomes the file's sibling idiom
  (`mktemp -d "${TMPDIR:-/tmp}/tot-m5e-transcript.XXXXXX"`), and the
  note is recorded in the script itself.  Nothing else in the pinned
  script changed.
- Conflict note C-E2 (2026-09-03): plan E7 M2 asks for three-run
  medians "at Stage D exit and at Stage E exit" for four commands,
  but the fourth (`tot check --experimental-wf ...`) is `unknown
  flag` exit 2 at Stage D exit (probe P8), and the D-exit binary was
  rebuilt in place before separate D-exit medians were taken.
  Resolution: the D-exit observations are the entry battery's own
  gate_timed MEASURE lines (salvaged before truncation) plus the
  byte-identity of the transcript, which is the load-bearing
  default-path comparison;  all numbers and the harness difference
  are recorded under M2 above, none invented.
- Conflict note C-E3 (2026-09-03), the Stage D handoff's disclosed
  ordering caveat, adjudicated: plan D12 item 11 says
  `PASS-M4FIX-INST-BRANCHING` is still the last leg in the file, but
  `PASS-M5B-BRANCHING-20` has sat after it since Stage B, whose own
  leg comment carries the dated claim "it is the LAST leg, with no
  marker downstream of it" (the M4 round-5 lesson applied to the more
  timing-sensitive sibling: FAST tier, 10s over 0.034s measured).
  Either ordering falsifies exactly ONE of the two dated LAST-leg
  comments, so a swap buys no assertion strength, would rewrite
  finished Stage B bytes, and would churn the whole-output diff.
  D0-3's operative intent -- nothing cheap depends on the expensive
  branching legs, and they close the file -- holds under the current
  order: the only marker downstream of M4FIX-INST-BRANCHING is its
  own timing sibling.  RESOLUTION: reasoned NO-CHANGE.  The Stage E
  legs are inserted BEFORE the branching pair (mirroring Stage D's
  D0-3 placement), the adjudication is recorded here and in the
  Stage E section comment in dev/gates.sh, and the caveat is no
  longer silently unresolved.  PASS-M5D-MEASURE-LOG's "the file's
  last two" accounting stays true.
- Plan-internal conflicts C1 to C3 of section E10 (the Acc header
  spelling, the indexed-family relation mismatch, the liveness leg
  against a dead flag) were resolved IN-PLAN and are inherited, not
  re-litigated;  the C2 mismatch text is recorded in the SPEC entry
  and the C3 resolution is gate E (iii) leg (a).

### Pin P22 paid (the SPEC residual entry)

Section 2 gains the seven dated `2026-09-02 (M5, Stage E, SPIKE)`
entries (flag + cost, the one-sentence rule, the precondition, the
non-specificity with the M1 table, Acc needs no universe polymorphism,
the indexed-family gap with the exact mismatch text, the Frozen_rec
coupling).  Section 6's well-founded bullet now reads, in the part
this stage owns (the residual the preamble's checklist reserves for
P22):

    DELIVERED by Stage E (design pin 22): what the spike MEASURED is
    in the dated section 2 Stage E block (the M1 shape table, 2 of 4
    rows flip;  the M2 cost medians with the byte-identical default
    transcript;  the M3 `Frozen_rec` coupling), and what it did NOT
    close is: a sound admission rule (the prototype clause inspects
    the head's status, never the field's type, so it admits
    infinitary structural recursion `bad2` alongside `accRec`);  the
    indexed-family relation gap (`R` demands `w`-quantity domains, an
    indexed family stamps `0`);  and the erased elimination form for
    `Acc` (coupled to the subsingleton fence).  M6 either promotes
    the prototype behind a sound side condition or deletes the flag;
    no stage may promote the spike to a shipped feature.

Section 6 gains no NEW debt line: `--experimental-wf` is a
measurement instrument, not a debt.

### Exit criteria, measured

1. Full battery green: GATE-EXIT=0, `rg -c '^PASS'` = 334 = 329 + 5.
   Decomposed: kernel suite 106 (104 + E1 + E2), surface suite 107,
   gate markers 121 (118 + 3);  `rg -c '^FAIL'` matches nothing
   (exit 1).  Log: /Users/oobi/Documents/tot-m5-stageE-gate.log
   (final run;  first green run preserved at
   /Users/oobi/Documents/tmp-e-gate-run1.log with identical counts).
2. All THREE PASS-M5E-* markers present, exactly the reserved three.
3. Whole-output diff vs the entry run: 5 added lines, 0 removed, 0
   changed;  every pre-existing marker present by name.
4. Default path byte-identical: gate E (i) green on every run, plus
   two direct regenerations diffed empty against the committed
   transcript (one at Stage D exit, one at Stage E exit).
5. accRec still fails the shipped guard without the flag (gate E (i)
   second half, and E5.3: exit 1 at 5:1);  the witness fails
   identically with and without the flag (gate E (iii), outputs
   byte-compared equal).
6. Tier discipline: no numeric watchdog literal (nolit exit 1), tier
   uses 116 -> 122 measured with the pinned recipe before and after,
   BITE_S uses still 2, PASS-M5D-TIERS green at the raised literal.
7. `Cache.format_version` = 10, `surface/cache.ml` untouched;  no
   `Term.t` change;  no Marshal bump needed (the spike fit behind the
   flag as planned).
8. Nothing staged, nothing committed: porcelain shows all edits
   unstaged (M) and new files untracked (??);  nothing outside
   /Users/oobi/Documents/tot was edited (probe scratch and logs live
   in ~/Documents, outside the repo).

### Gate output tails

    PASS-M5E-DEFAULT-IDENTITY
    PASS-M5E-ACC-CHECKS
    PASS-M5E-WITNESS-REJECTED
    PASS-M4FIX-INST-BRANCHING
    PASS-M5B-BRANCHING-20
    GATE-LOG=/tmp/claude-501/tot-gate-measure.log
    GATE-EXIT=0

    test/main.exe   ... M0 kernel: all tests green   (106 PASS)
    test/surface.exe ... M1 surface: all tests green (107 PASS)

### Milestone hand-off to close-out

M5 build COMPLETE: the PASS walk chained
278 (M4 baseline) -> 301 (Stage A) -> 312 (Stage B) -> 323 (Stage C)
-> 329 (Stage D) -> 334 (Stage E), 0 FAIL at every stage exit, all 23
pins paid (P22 last, this stage), 29 M5 gate markers shipped (the 118 markers at Stage D exit are the
92 M4 markers plus 26 from Stages A to D;  Stage E adds the reserved
three for 121), format_version still 10, every mutation proof recorded
with md5-identical restores, and the default path proved
byte-identical to Stage D exit over the whole 80-file check corpus.
Close-out owns: commit (the user commits;  nothing is staged), plus
any milestone-level review rounds.

## M5 review round 1 (2026-09-03)

R1 shape: ctxcat-review workflow wf_8853b547-0e5 over the STAGED
54-file diff (precomputed index, 13 per-file finder shards, deep-logic
opus pass, batched verify, 2 adversarial escalations; 16 agents, 0
errors) plus one independent opus seed adjudicator over the five
close-out seeds.  Raw 9 -> upheld 9 -> survivors 8; seeds: 3 HOLD,
2 findings.  Dispositions, in finder order:

- R1-0 (high, dev/bisect-inst-classes.sh MARGIN-PIN): CONFIRMED by
  escalation.  The 0.8x cap assigned best_pin_k=margin, a K the run
  never probed, then printed bytes/secs recorded at the last probed
  resolving K.  FIXED: the capped branch now prints the cap as
  UNPROBED and keeps the measured pair attached to the probed K.
  No leg parses the MARGIN-PIN line (the gates.sh mention is a
  human recipe comment), so the battery is unaffected.
- R1-1 (medium, gates.sh typeset -F SECONDS): REFUTED.  The finder
  assumed bash.  gates.sh is `#!/bin/zsh` and every recorded battery
  invocation is `zsh dev/gates.sh`; in zsh `typeset -F SECONDS` is
  the documented float-seconds idiom, so MEASURE elapsed keeps
  sub-second precision.  NO CHANGE.
- R1-2 (medium, SUITE legs gained 2>&1 via gate_timed): CONFIRMED as
  a real behavior change, ADJUDICATED ACCEPTED: suite PASS oracles
  match whole lines, dune writes no stderr on a warm build, and the
  Stage D whole-output diff was adjudicated additions-only with the
  merge in place.  Documented with a dated exception note above the
  wrap rule in gates.sh.
- R1-3 / R1-4 (nit, dev/gen-inst-*.py argv): FIXED with isdigit()
  guards; a non-numeric argument now prints usage and exits 2
  instead of a traceback.  main()-only change; generated fixture
  bytes are untouched.
- R1-6 (medium, --strict-json fails open for IO Unit): the exit-1
  route is PLAN-PINNED (plan A4 item 5 gives the Unit shape the
  driver contract, same posture as --require-main), so the build is
  faithful and behavior stands.  FIXED as disclosure: the SPEC
  Stage A entry now states the consequence (exit 1 is non-blocking
  in a 0/2 harness; fail-closed is Verdict-only) and a blocking
  Unit posture is listed as an M6 candidate.
- R1-7 (low, budget cannot bound a cold-cache bootstrap): CONFIRMED
  as a disclosure gap.  FIXED: the SPEC budget entry now records the
  cold window (binary-digest cache key, first run after a rebuild is
  outside the budget; decision 13's timeout belt owns it).
- R1-8 (low, echo-readback is one-oracle-deep on conformance):
  CONFIRMED as an overstated comment.  FIXED: the fixture header now
  says the readback pins reason transport only and names
  PASS-M5A-ENVELOPE-VALID as the conformance pin.
- SEED-2 (memo-HIT cost): CONFIRMED.  FIXED: SPEC section 6 gains a
  known-debt bullet for pin 5's unpinned cost half (0.034 s healthy,
  6.212 s re-derive, 183x, FAST ceiling 10 s, MEASURE line as the
  manual instrument).
- SEED-EXTRA (FENCE-PI stale prediction prose): CONFIRMED.  FIXED:
  the gates.sh mutation-proof comment and both fixture headers now
  record the OBSERVED termination-guard route (the adjudicator
  re-proved the flip 2026-09-03: mutated tree exits 1 with the
  guard message, the leg flips on the missing 'erased variable px'
  text).  Seeds 1, 3, 4, 5 HOLD with independent re-probes (the
  fuel-factor drop was re-run and turned three legs red; the Stage E
  leg ordering shares no mutable state; the x4 fuel print is one
  site, a value ratio; FENCE-PI non-vacuity confirmed).

Fix surface: comments and docs plus two dev-script argv guards and
one dev-script report format.  No lib/, surface/, bin/, test/*.ml or
gate-oracle change.  Battery re-run follows this entry.
