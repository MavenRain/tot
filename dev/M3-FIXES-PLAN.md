# M3 fix batch: review round-1 corrections

Authoritative spec for the M3-fix implementation agents.  Read this WHOLE
file before touching code.  The repo is /Users/oobi/Documents/tot (OCaml,
dune).  The M3 build is staged; the working tree equals the staged batch
on top of commit a65321f.  Evidence files (read the entries your stage
cites BEFORE coding):

- /Users/oobi/Documents/tot-m3-review-r1-survivors.json  (ctxcat round 1,
  19 survivors; ids cited below as C0..C19)
- /Users/oobi/Documents/tot-m3-opus-r1-report.md  (opus logic pass;
  findings cited below as O1..O7; every O finding was EXECUTED against
  the built binary, with repro snippets in the report)

## 0. Ground rules (house style, enforced by hooks)

- NO exceptions anywhere in OUR code: no raise/failwith/assert.  Every
  failure is a Result value.  Wrapping a HOST library call that raises
  (Str, Marshal, Unix) in a `match ... with exception` handler is the
  one sanctioned pattern; the handler must be exhaustive over the
  exceptions the fix below names.
- NO match on Option/Result where a combinator does the job
  (Option.fold/map/to_result, Result.bind, let*).  A PreToolUse hook
  DENIES edits that add such matches.
- NO loop keywords (for/while); recursion + List.fold/map/filteri only.
- Exhaustive matches, NO catch-all `_ ->` arms on variant types you can
  enumerate.  Use `match () with | () when ...` ladders, not if/else-if.
- Comments: match existing density; doc comments on new top-level items.
- No em-dashes in any text you write.  In prose, write "locate", never
  the f-word verb that a hook pattern-matches.  In .md prose put TWO
  spaces after every sentence-ending period and semicolon.
- Shell: `rg` not grep, `sd` not sed.  Append a trailing ` # [skip-disk]`
  comment to EVERY Bash command.
- Never `cd`: use `dunecho build -- --root /Users/oobi/Documents/tot`
  for builds (raw `dune build` is hook-blocked; `dune exec` is fine),
  `git -C ...` for git reads, absolute paths.  Your cwd RESETS between
  Bash calls.
- Do NOT run `git add`, `git commit`, or any other index mutation.
  Leave working-tree edits only.

Gate command battery (all must be green before your stage reports):

    dunecho build -- --root /Users/oobi/Documents/tot # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -3 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -3 # [skip-disk]
    zsh /Users/oobi/Documents/tot/dev/gates.sh > /tmp/claude/m3fix-gates.log 2>&1; echo "exit=$?"; tail -5 /tmp/claude/m3fix-gates.log # [skip-disk]

Append a stage report to /Users/oobi/Documents/tot/dev/M3-FIXES-LOG.md
(create it in stage A): what changed, files touched, new Error/Serror
variants, test names added, gate tails.  Every fix ships WITH its
regression test, and every negative test must be shown to REJECT for the
intended reason (print the error), not to pass vacuously.  Do not edit
dev/M3-BUILD-LOG.md history; it is a frozen record.

## STAGE A: check-mode semantics (O1 CRITICAL, C14, C17, O5, C15, C18)

### A1 (O1 + C14): check mode must never execute user def bodies

Today surface/run.ml defers Interp.define only when the def's stamped
type HEAD is Div or IO, so `def boom : Option (Div Nat) := some (Div
Nat) (spin zero)` executes (and can diverge) under `tot check`.

Decision: in CHECK mode, run.ml does not call Interp.define for
user-file defs AT ALL.  Kernel elaboration and type checking are
unchanged; the runtime environment is simply not built for the user
file.  Elaboration only ever consults kernel globals (lib/eval.ml NbE),
never Interp values, so nothing downstream needs them; verify this
claim against the suite rather than assuming it.  Bootstrap and the
prelude path stay as they are.  RUN mode keeps today's semantics for
every def (eager for pure heads, deferred for Div/IO heads); a Div
value nested under a pure head executing at definition time in RUN mode
is BY DESIGN.  Record that decision in SPEC.md section 2 (dated
2026-09-01, M3 fixes) and rewrite SPEC.md lines 322-329 and 472-475 to
describe the new mechanism (check builds no runtime environment for the
user file; deferral in run mode is unchanged).

Tests:
1. New fixture test/fixtures/x1-nested-div.tot holding exactly the O1
   repro (spin + boom).  Gate PASS-CHECK-NESTED-DIV in dev/gates.sh:
   `timeout 5 tot check` on it must exit 0.  Mutation-confirm: before
   the fix this same command exits 124 (record the pre-fix run in the
   log).
2. Existing B5/B6/B7 surface tests stay green (eval in check mode
   prints types only; that path must keep working with no Interp table
   for the user file).

### A2 (C17): memoize deferred forcing

Forcing a deferred (Div/IO-headed) global re-executes its body on every
use; a chain of n Div defs each referencing the previous twice costs
2^n evaluations.  Div computation is pure modulo divergence, so
memoization is sound.  Make the deferred slot a mutable memo: first
force stores the computed value, later forces return it.  Keep the
change inside lib/interp.ml's global-entry representation.

Test: kernel or surface test with a chain of 8 Div-headed defs, each
body using the previous def twice, over a body expensive enough to
observe (a modest regexTest call); a time-bound assertion in the same
style as the existing PASS-B-DEFERRED gate (memoized completes well
under the bound; unmemoized would not).  Mutation-confirm by reverting
the memo once and recording the timeout.

### A3 (O5 + C18 + C15): make the deferral gates able to fail

- PASS-C-REGEX-PATHOLOGICAL currently accepts exit 0 AND exit 124, so
  it cannot fail.  After A1, `tot check` on the pathological fixture
  must exit 0 FAST: assert exit 0 under `timeout 5`, and treat 124 as
  FAIL.  Keep a separate run-mode line if the fixture is also run, with
  the watchdog acceptance documented there only.
- PASS-CHECK-PRELUDE and PASS-RUN-PRELUDE both derive from one
  bootstrap-only exit code (C15).  Restore genuine run-mode coverage:
  the RUN line must execute a script that exercises prelude defs in run
  mode (an eval of a prelude rec applied to data) and pin its output.

## STAGE B: runtime robustness (O2, O3, C8, C16, C9, C10, C19, C7, O7)

### B1 (O2 + C3 + C19): regex group counting and error channel

- Rewrite regex_group_count as a small state machine with explicit
  states: normal, after-backslash, in-class, in-class-after-backslash.
  Count a group only on backslash-then-open-paren read in the normal
  state.  Honor the Str dialect rules for classes: `[` opens a class in
  normal state; inside a class a backslash is an ordinary character;
  `]` closes the class except when it is the first member (`[]a]` and
  `[^]a]` keep the literal `]`).
- Widen str_opt's handler to also catch Invalid_argument (backstop for
  the no-exceptions promise; with the counter fixed it should never
  fire, but the process must not die if it does).
- Distinguish malformed pattern from no-match (C19): Str.regexp raises
  Failure on a bad pattern; catch it at the compile site and route it
  to a NEW Error.t variant (Regex_bad_pattern of string) through the
  interpreter's existing Result channel, instead of returning the same
  None a no-match returns.
- Replace the wrong comment at lib/interp.ml:409-412 (it claims a SPEC
  debt that does not exist and understates a crash as imprecision) and
  add a real SPEC.md section 2 entry for the Str dialect caveats plus
  the new error variant.

Tests: `eval regexMatch "[\\(]x" "(x"` returns cleanly (no fatal
error; pin the printed value); the 32-escaped-backslash variant from
the report likewise; a genuinely malformed pattern prints the
Regex_bad_pattern error; existing benign and pathological gates stay
green.

### B2 (O3 + C6 + C7 + O7): cache integrity

- New on-disk format: magic string, format_version, MD5 digest of the
  body, then the body.  load verifies magic, version, AND digest before
  Marshal.from_string; any mismatch is a silent miss.  Wrap the Marshal
  call in an exhaustive `match ... with exception` handler over Failure
  and Invalid_argument as a backstop.  Bump format_version.
- save: on a rename failure, best-effort unlink the .tmp file (C7).
- Update the module doc so its never-crash claim matches the code, and
  add a SPEC.md section 2 entry: the cache directory is a TRUSTED input
  (same trust class as the tot binary itself); the digest defends
  against corruption, not against an attacker with write access to
  $TOT_CACHE_DIR; that residual is recorded in section 6 as a debt.
- O7 decision: `tot check` KEEPS writing the prelude cache (hooks need
  warm-cache check latency); fix the stale "types only" framing at
  bin/tot.ml line 1 to say check may write the prelude cache.

Tests: truncated body = miss (exit 0, fresh elaboration); bit-flipped
body = miss (this previously SEGFAULTED; record pre-fix exit 139 in the
log as the mutation confirmation); wrong magic = miss; the existing
PASS-D-CACHE-HIT / PASS-D-CACHE-MISS gates updated to the new format
and green.

### B3 (C8 + C16 + C9): procRun via temp files

Replace pipe-based capture with temp-file redirection: create two temp
files (stdout, stderr), spawn the child with its fds redirected to
them, close every parent-held descriptor immediately after the spawn
decision (success AND failure paths), waitpid, read both files back,
delete them.  This closes the descriptor leak on spawn failure (C8)
and the sequential-drain deadlock when a child fills the stderr pipe
buffer (C16) in one move.  While here, split the WSIGNALED and
WSTOPPED arms (C9): a signaled child maps to exit 128+signo (shell
convention); a stopped child is waited on again (WSTOPPED is
unreachable without WUNTRACED, but the arm must be honest).  Record
the 128+signo convention in SPEC.md section 2.

Tests: gate PASS-C-PROC-BIGSTDERR: a child that writes at least 256
KiB to stderr and exits 0; procRun must return the full stderr and not
hang (run under timeout; pre-fix this deadlocks, record it).  Existing
PASS-C-PROC stays green.  A spawn of a nonexistent binary returns the
error value cleanly with no descriptor growth.

### B4 (C10): exitWith range

Valid domain 0..255.  Out of range is a runtime script error through
the standard error channel (message on stderr, process exit 1), never
a silent wrap.  New Error or Serror variant (Exit_code_out_of_range of
int).  SPEC.md section 2 entry.  Test: `exitWith 300` prints the error
and exits 1 (not 44).

## STAGE C: driver, tests, docs (O4, O6, C1, C2, C11, C12, C13, C0, C4)

### C1' (O4): main is a reserved name

If the user file defines `main` and its type converts to neither
IO Verdict nor IO Unit, fail with a new Serror variant (Main_bad_type,
carrying the printed type) in BOTH check and run modes.  No `main` at
all stays script mode, unchanged.  Record two residuals in SPEC.md
section 6: a misspelled main is still silent (a strict driver flag is
M4 work), and a script-level Serror exits 1, which collides with the
ask verdict's exit code in the hook protocol.

Tests: the two O4 repro scripts; the IO Bool one now errors in check
AND run (print the error); the misspelled one stays exit 0 (pinned as
the documented residual); guard fixtures allow/deny/other stay green.

### C2' (O6): full prim-arity pin

Extend case_prim_arity_agreement in test/main.ml to
phase1 @ phase2 @ phase3.  The claim at lib/prim.ml:96 becomes true;
reword it if the test name differs.

### C3' (C1): prim-lint line discipline

Compute n_total from the same line shape n_justified uses (non-empty
lines), or better: assert every non-empty line matches the strict
pattern and FAIL listing the offending lines.  Keep the catalog-size
agreement against prim-bootstrap-count.

### C4' (small fixes, one commit-worthy pass)

- C2: in lib/check.ml, when a partial def's type has no leading Pi,
  reuse the already-computed ty_v instead of re-evaluating through
  peel_codomain.
- C11: in surface/run.ml main_epilogue, evaluate main's type once and
  reuse it for both the IO Verdict and IO Unit conversion attempts.
- C13: in test/surface.ml argv dispatch, an unknown subcommand is an
  error exit with a message, not a silent fallback to the full suite.
- C0: dev/gates.sh chmods ONLY the scratch copy of the binary; set the
  executable bit on examples/guard.tot once in the working tree (plain
  chmod +x on the file, no git commands) so the mode rides the next
  staging, and delete the tracked-file chmod from the script.
- C4: VPrim application accumulates with cons and reverses once at
  fire time.
- C12: partial-flag invariant (syntax carries partial only on rec
  defs) is not type-enforced; add the doc comment on the syntax type
  and a SPEC.md section 6 debt line.

### C5' (doc truth sweep)

After the code lands: lib/prim.ml:96 claim (C2' makes it true),
lib/interp.ml regex comment (B1 replaces it), surface/cache.ml module
doc (B2 rewrites it), bin/tot.ml line 1 (B2 rewords it), SPEC.md
section 2 dated entries for A1, B1, B2, B3, B4, C1' and section 6
debts named above, and the log appended per stage.  README.md gets no
change unless a claim it makes became false; check and say so in the
log either way.

## Reporting

Each stage: append to dev/M3-FIXES-LOG.md the fix list, files touched,
new variants, test names, the four gate tails, and every
mutation-confirmation transcript the stage performed.  Return status
green only when the ENTIRE battery passes.
