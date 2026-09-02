# M3 fix batch, round 2

Authoritative spec for the round-2 fix agents.  Read this WHOLE file,
then section 0 of /Users/oobi/Documents/tot/dev/M3-FIXES-PLAN.md (the
ground rules; they apply verbatim, including the gate battery, the
two-space prose rule, and the ban on git index mutation).  The repo is
/Users/oobi/Documents/tot; the working tree equals the staged batch on
top of a65321f.  Evidence:

- Opus re-probe report: the three numbered findings and the survivor
  list are summarized inline below; probe artifacts live under
  /Users/oobi/Documents/tot-adv2/ (drift binary totcopy, driver
  run-drift2.sh, forge.ml, cache_attack.py, o1k.tot, divergence/).
- ctxcat round-2 survivors (22, mostly polish): parse the JSON at
  /private/tmp/claude-501/-Users-oobi-Documents-claude1/b65178bd-a7bd-4fcf-a33a-abe16813e434/tasks/w3qf4a362.output
  with `python3 -P` (top-level object, field .result.survivors).  If
  that tmp file is gone, the reduced set is restated in STAGE B below;
  the restated set is authoritative enough to proceed.

Append reports to dev/M3-FIXES-LOG.md under a `## Round 2` heading.

## STAGE A: the three re-probe findings

### R1 (HIGH): cache layout drift is undetectable by construction

Executed proof: two binaries sharing format_version 4 but differing in
one marshaled payload type produced, over a shared TOT_CACHE_DIR and
the same key, a SILENTLY WRONG prelude one way (exit 0) and SIGSEGV
the other (exit 139).  Root cause: format_version is folded into the
cache KEY (surface/cache.ml:107-108), so the file a mismatched binary
opens always carries a matching version field; the digest is computed
by the writer, so any self-consistent blob reaches Marshal.

Fix: bind the cache to the exact executable.
- Compute once (lazily) the MD5 digest of the running binary's own
  contents (Digest.file Sys.executable_name, wrapped in the house
  Result style; on any read failure DISABLE the cache for the run,
  loud on stderr in a single line, never crash).
- Fold that digest into the cache KEY derivation AND write it as an
  additional header field; load verifies it before the body digest.
  Only the exact binary that wrote a blob ever reads it, so a
  forgotten format_version bump can no longer feed a foreign-shape
  blob to Marshal by accident.  Bump format_version to 5.
- SPEC.md: rewrite lines 561-563 (the claim the re-probe falsified)
  to state the new mechanism; keep the section 6 residual for an
  attacker with write access to the cache dir (that trust boundary is
  unchanged, and such an attacker can also read the binary digest).
- Module doc updated to match.

Mutation confirmation (artifacts exist already): with the fix, the
two-binary drift scenario from /Users/oobi/Documents/tot-adv2/
run-drift2.sh must become two independent cold caches (both orders
print the correct numeral, exit 0, no segfault).  Record the post-fix
transcript next to the pre-fix one in the log.  Also re-run the
forged-blob attack (oracle/forge.ml writes correct magic + version +
digest over a foreign body AT THE OLD KEY): post-fix the forged file
is simply never opened (different key) or rejected on the header
field; exit 0, fresh elaboration.

Tests: extend the cache suite with a wrong-binary-digest header case
(construct by patching the header bytes of a valid blob) expecting a
silent miss; existing PASS-D-CACHE-* gates stay green.

### R2 (MEDIUM): run mode evaluates defs lazily, so dead code cannot
abort or hang a guard

Executed proof: a def main never mentions, with a Div computation
nested under a pure head, makes `tot run` abort (regex error, exit 1
= ask) or hang forever, while `tot check` reports clean.

Fix: in RUN mode, Interp.define stores EVERY user def as a memoized
thunk (the A2 memo machinery generalizes): erasure and closedness
checking stay EAGER at definition time (so malformed defs are still
caught), evaluation happens on first force by an eval item or by
main, and the memo keeps single-execution.  Div carries no host
effects and IO is reified, so laziness is observationally invisible
except that unforced defs never run, which is the point.  Check mode
is unchanged (no runtime environment at all).
- SPEC.md: replace the "executes at definition time in run mode by
  design" decision entry from round 1 with the lazy-memoized rule,
  dated; note that check therefore over-approximates run's
  definition-time failure set again for dead code, and that a LIVE
  def's definition-time abort still surfaces only at force time.
- Keep the b-deferred-div and x3-div-chain gates green (they force
  through eval/main, so timings are unchanged).

Tests and gates: move the two probe fixtures in as
test/fixtures/x12-dead-abort.tot and x13-dead-hang.tot (shapes: a
dead def whose body is a failing regexTest under Option; a dead def
applying a spinning partial under Option; main returns allow).  New
gates PASS-RUN-DEADCODE-ABORT and PASS-RUN-DEADCODE-HANG: `tot run`
on each, under the watchdog, exits 0 with an empty stdout envelope
(allow prints nothing).  Record the pre-fix exits (1 and 124) as the
mutation confirmation.

### R3 (doc): scope hard constraint 1 honestly

Executed proof: eight lines of `reducible` defs drive `tot check` past
300 s of kernel conversion (no interpreter involved); opacity is the
only guard.  This is inherent to dependent checking (Coq and Lean
share it) and is NOT to be fixed in code this round.
- SPEC.md: tighten the hard-constraint-1 paragraph (lines 414-427
  area) to claim exactly: check performs no host effects and never
  executes the interpreter; kernel CONVERSION can be driven to
  unbounded compute by reducible definitions, same as any dependent
  checker; opaque-by-default is the mitigation.
- Section 6 debt: a driver-level fuel or wall-clock budget flag for
  check mode is M4 work; hook installations should wrap `tot` in an
  external timeout until then.
- dev/M3-PLAN.md line 521-522 stays frozen (historical plan text; do
  not edit it).

## STAGE B: ctxcat round-2 survivor sweep (22, polish grade)

Parse the survivors JSON (path above).  For each, FIX or ADJUDICATE
with one logged line.  Decisions already made for the notable ones:

- bin/tot.ml bootstrap error via print_endline: switch to stderr,
  matching the B4 channel rule.  Add a pinned test (bootstrap failure
  path leaves stdout empty) only if cheap; else gate-level check.
- gates.sh Gate B(iii) missing "$watchdog" wrapper: add it.
- prim-lint.sh invocation in gates.sh: capture output, print on
  failure; the PASS-C-PRIMLINT marker already exists, keep exactly one
  emission point.
- Hardcoded /Users/oobi/Documents/tot paths in dev/gates.sh and
  dev/prim-lint.sh: derive a ROOT from the script's own location
  (cd "$(dirname "$0")/.." pattern or a ROOT= variable) and use it
  throughout.  Keep behavior identical from any cwd.
- examples/guard.tot fail-open on malformed payload: BY DESIGN (the
  user-confirmed driver protocol fails open on unparseable hook
  input).  Do not change behavior; add a short comment in the guard
  above main citing SPEC's fail-open decision, and log the finding as
  adjudicated no-change.
- lib/check.ml provisional self-reference entry hard-codes
  partial = false: thread the def's real partial flag into the
  provisional entry.  Audit (rg) every reader of the partial field to
  say in the log whether the wrong value was reachable during body
  checking; add a regression test only if a reachable consumer
  exists, else log the audit result.
- Everything else in the survivor list: apply the suggestion when it
  is mechanical and local; adjudicate no-change with a reason when it
  conflicts with house style or the design decisions above.  Do not
  invent scope beyond the listed items.

## Reporting

Each stage appends to dev/M3-FIXES-LOG.md under `## Round 2`: fix
list, files touched, adjudications with reasons, new variants, test
names, gate tails, mutation transcripts.  The full battery from the
round-1 ground rules must be green, including every marker added this
round, before a stage reports green.
