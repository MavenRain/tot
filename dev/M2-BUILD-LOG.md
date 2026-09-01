# M2 build log

## Stage A: quantity-stamped core terms (2026-09-01)

What changed (term.ml and erase.ml were already rewritten on disk; the
rest was built around them):

- lib/eval.ml: `Lam`/`App` patterns take the new leading quantity and
  ignore it. `quote` rebuilds `Lam`/`App` with `Quantity.Many`
  placeholders; a comment records that quoted terms feed display and
  conversion only, never erasure.
- lib/check.ml: `infer` returns `(Term.t * Value.t)`, `infer_univ`
  returns `(Term.t * Level.t)`, `check` returns the stamped `Term.t`.
  Lam-in-check and App-in-infer stamp from the Pi; the input stamp is
  discarded. App instantiates the codomain with the stamped argument.
  `Ann` is dropped from checker output. `define` stores the stamped ty
  and def in the global entry.
- lib/pp.ml: `Lam`/`App` arity only; quantity ignored in display.
- surface/elab.ml: `SLam`/`SApp` emit `Quantity.Many` placeholders.
- surface/run.ml: IDef fetches the entry back after `Check.define` and
  erases `entry.def` via `Erase.closed` (no ty/globals needed). ICheck
  prints the stamped term. IEval erases the stamped term from `infer`
  at `Many`.
- test/main.ml: all `Term.Lam`/`Term.App` constructions carry a leading
  `qw` placeholder; `expect_infer_ok`/`expect_infer_err`/
  `case_id_result_type` bind the new `(_tm, ty)` pair.
- test/surface.ml: new negative "lex numeric literal cap" pins the
  19-digit literal overflow guard (`Lex` tag).

Gate tails:

    $ dunecho build -- --root /Users/oobi/Documents/tot
    OK build: 0 errors, 0 warnings

    $ dune exec --root /Users/oobi/Documents/tot test/main.exe | tail -5
    PASS bare lambda needs annotation
    PASS dependent application result type
    PASS duplicate global rejected
    PASS quote and print round-trip
    M0 kernel: all tests green        (18 PASS)

    $ dune exec --root /Users/oobi/Documents/tot test/surface.exe | tail -5
    PASS erased use is a kernel error
    PASS duplicate def is a kernel error
    PASS no cumulativity
    PASS bare lambda cannot be inferred
    M1 surface: all tests green       (16 PASS, incl. "lex numeric literal cap")

    $ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run examples/church.tot | tail -3
    def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
    def two : cnat
    fun f => fun z => (f (f (f (f z))))

    $ zsh dev/gates.sh | tail -1
    TEST-OK

## Stage B: kernel inductives, dependent match, rec globals, totality (2026-09-01)

What changed:

- lib/level.ml(.mli): added `Level.le`.
- lib/error.ml: new variants `Not_inductive`, `Bad_ctor {ctor; reason}`,
  `Branch_mismatch {expected; found}`, `Termination`; `Cannot_infer`'s
  message generalized to "cannot infer a type for %s" (payloads now name
  the construct: "the bare lambda (binder x)", "a match without 'as ..
  return'").
- lib/term.ml: added `Match {scrut; motive; branches}` with the motive an
  option (None survives checking only in check mode = constant motive)
  and branch binders carrying checker-stamped quantities.
- lib/value.ml: `VInd`/`VCtor` canonical values; neutral spines became
  `frame list` (newest first) with `FApp` and `FMatch` (stuck match =
  motive + branch TERMS + their `menv`).
- lib/global.ml: entry became a variant `Def | Ind | Ctor` over three
  NAMED payload records (`def_entry` with `rec_arg : int option`,
  `ind_entry` {ind_ty; params; level; ctor_names}, `ctor_entry`
  {ctor_ty; ind; args}) plus a `telescope` type and total accessors
  (`entry_ty`, `find_def/find_ind/find_ctor`). Deviation from the plan's
  inline-record sketch: named records so the accessors can return the
  payloads; field names `ind_ty`/`ctor_ty` avoid cross-record clashes.
- lib/eval.ml: `run_match` (canonical ctor drops the n_params leading
  args, branch body evals in `List.rev_append own env`; neutral
  scrutinee pushes `FMatch`; other shapes are a total `Not_inductive`
  backstop). Globals: Ind/Ctor evaluate to empty-applied canonicals;
  rec defs (`rec_arg = Some k`) ALWAYS start neutral. `apply` appends to
  VInd/VCtor and does guarded unfolding on reducible-rec HGlobal
  neutrals: only when the oldest FApp run has a canonical VCtor at
  position k does it eval the def closed and `replay` all frames
  oldest-first. quote rebuilds VInd/VCtor as Many-stamped App chains and
  FMatch frames as Term.Match (motive/branch bodies evaluated under
  fresh vars, quoted at size+arity). conv: VInd/VCtor compare name +
  args pointwise; frames compare pairwise (FApp/FApp, FMatch/FMatch
  with motive-option agreement and per-branch fresh-var body conv); all
  cross-shape pairs spelled out false (no eta for inductives); the
  lam/neutral eta rules push `FApp fresh`.
- lib/check.ml: `infer` Match (scrutinee at the ambient mode, type must
  be a fully applied VInd, explicit motive required, branches walked
  against ctor_names in declaration order with Branch_mismatch/"<none>"
  payloads, binder quantities stamped FROM the ctor telescope, expected
  body types = motive at `VCtor (c, p_vals @ fresh_args)`, result type =
  motive at the scrutinee value). `check` Match with motive None =
  constant-motive rule (every branch checks at the expected type);
  Some-motive routes through the new `check_via_infer`. `declare_ind`
  (stamped params telescope, closed `params -> Type l` entry) and
  `define_ind` (per ctor: duplicate check incl. within the declaration,
  infer_univ stamping, result-head check `I` applied to exactly the
  param vars, strict positivity with uniform params, per-arg
  `Level.le` universe bound, params FORCED Quantity.Zero in the closed
  ctor type; the Ind entry is rewritten with ctor_names last).
  `define ?(rec_ = false)` keeps the M1 call shape; the rec path checks
  the body against a provisional OPAQUE self-entry, then
  `Totality.guard` picks `rec_arg` (first fit).
- lib/totality.ml (new): `guard ~recname` peels the leading lambdas and
  tries each formal as principal; a status walk (Principal/Smaller/
  Other, newest first) demands every occurrence of the rec global be an
  App spine whose arg k is a Smaller var; a match on a Principal/Smaller
  var makes branch binders Smaller (motive binder Other); all other
  binders push Other.
- lib/eterm.ml/erase.ml: `EMatch` (kept binder names only); erasure
  drops the motive and the Zero-stamped branch binders structurally.
- lib/interp.ml: `VCon` + `eframe` (FEApp/FEMatch); EMatch execution
  (VCon dispatch by name with a total backstop, VNeut freezes the
  branches + env), apply appends to VCon, quote rebuilds VCon as EApp
  chains and FEMatch frames as EMatch mirroring the kernel; new seeds
  `add_ctor` (VCon) and `add_erased` (VErased) for Run (used in
  Stage C).
- lib/pp.ml: `match S with | c x y => B end` / `as x return P` forms for
  Term.Match and Eterm.EMatch.
- surface/run.ml: IDef fetches the stamped def via `Global.find_def`.
- test/main.ml: build_globals now declares Nat (zero/succ), Opt
  (0-param, none/some), reducible `def rec add` (guard picks k=0), and
  an opaque `x_opaque : Nat`; ten new cases: match eval (Nat pred + Opt
  payload extraction incl. param drop), dependent motive returning a
  different type per ctor (+ `some Nat (succ zero) : Opt Nat`), branch
  order/count/arity all Branch_mismatch, match on Type 0 =
  Not_inductive, negative ctor = Bad_ctor, ctor arg above the declared
  universe = Bad_ctor, `add (succ zero) (succ zero)` conv `succ (succ
  zero)` (guarded unfold), `add x_opaque (succ zero)` stuck (self-conv
  true, succ-form false), `def rec loop` = Termination, stuck-match
  conv (identical true, differing branch body false).

Latent note (out of Stage B gate scope, recorded for honesty): the
interpreter readback claim "stuck scrutinees freeze branch bodies, so
readback cannot diverge" holds for every M2 pipeline path (closed eval
results and the gate programs), but quoting a FUNCTION value whose body
applies a recursive global to a bound variable re-executes the frozen
branches one binder deeper per level (the interp has no guarded-neutral
notion for globals). No M2 surface path reaches it; worth a debt line if
M3 adds function readback of such defs.

Gate tails:

    $ dunecho build -- --root /Users/oobi/Documents/tot
    OK build: 0 errors, 0 warnings

    $ dune exec --root /Users/oobi/Documents/tot test/main.exe | tail -5
    PASS rec global unfolds on canonical arg
    PASS guarded rec stays stuck
    PASS termination guard rejects loop
    PASS stuck match conversion
    M0 kernel: all tests green        (28 PASS = 18 M0 + 10 M2)

    $ dune exec --root /Users/oobi/Documents/tot test/surface.exe | tail -5
    PASS erased use is a kernel error
    PASS duplicate def is a kernel error
    PASS no cumulativity
    PASS bare lambda cannot be inferred
    M1 surface: all tests green       (16 PASS)

    $ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run examples/church.tot | tail -3
    def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
    def two : cnat
    fun f => fun z => (f (f (f (f z))))

    $ zsh dev/gates.sh | tail -1
    TEST-OK

## Stage C: surface syntax (2026-09-01)

What changed:

- surface/token.ml: new kinds `KData`/`KMatch`/`KWith`/`KAs`/`KReturn`/
  `KRec`/`KEnd`/`Pipe` plus their `describe` strings.
- surface/lexer.ml: keywords data/match/with/as/return/rec/end; `'|'`
  lexes as the single-char `Pipe` token (arm sits before the catch-all
  error arm).
- surface/syntax.ml: `SMatch of Loc.t * t * (string * t) option *
  (string * string list * t) list`; `IData {loc; name; params; level;
  ctors}`; `IDef` gained `rec_ : bool`. `loc_of` covers `SMatch`.
- surface/parser.ml: `parse_match` (scrutinee term, optional `as x
  return P`, `with`, flat `| c xs => body` branches with a
  duplicate-binder Parse check, required `end`); `parse_data` +
  `parse_data_params` (each group MUST open with the literal `0` marker,
  anything else is the pinned Parse error "data parameters must be
  marked 0") + `parse_data_level` (`Type [L]`, default 0) + `parse_ctors`
  (zero+ `| c : CT`, list ends at KDef/KReducible/KData/KEval/KCheck/
  Eof, so zero-ctor data is legal); `parse_def` peels an optional `KRec`
  into `rec_`; `kind_starts_atom` enumerates the new kinds as false, so
  scrutinee/motive/branch-body terms stop at with/as/Pipe/end on their
  own; the item-level error message now names 'data'.
- surface/elab.ml: `SMatch` elaborates scrutinee in place, motive under
  its binder, each branch body under its binders (outermost first,
  Many-placeholder quantities); the pattern's ctor NAME passes through
  as a string for the kernel to resolve.
- surface/run.ml: `IDef` routes `~rec_` to `Check.define`; a rec body is
  elaborated against a provisional self-entry so the name resolves
  (Check.define still rejects duplicates against the ORIGINAL globals
  and re-adds its own opaque provisional). New `IData` item: params
  telescope elaborated left-to-right (quantity forced Zero),
  `Level.of_int` -> Serror.Bad_level, `Check.declare_ind` -> provisional
  globals, ctor types elaborated in param scope against those,
  `Check.define_ind` -> final globals, `Interp.add_erased` for the type
  ctor + `Interp.add_ctor` per data ctor, output "data NAME : <ty>" then
  "ctor c : <ty>" per ctor (closed types fetched back from the entries).
- test/surface.ml: fourteen new cases (the plan's 5 positives + 9
  negative scenarios). Positives pin EXACT line lists: Bool+not eval
  ("false"), def rec add on Nat ("(succ (succ (succ zero)))"),
  parameterized Box with param erasure ("(succ zero)" from a one-runtime-
  arg box), as/return match in infer position ("zero"), check-mode data
  script incl. zero-ctor `data Void : Type 0 :=` ("data Void : Type 0",
  "eval : Bool"). Negatives pin tags: Kernel.Branch_mismatch (missing
  branch / wrong order / unknown ctor), Kernel.Bad_ctor (negative
  occurrence), Kernel.Termination (`def rec loop`),
  Kernel.Not_inductive (match on a function), Parse (bare and `w` data
  param markers), Kernel.Cannot_infer (infer-position match without
  as/return).

Gate tails:

    $ dunecho build -- --root /Users/oobi/Documents/tot
    OK build: 0 errors, 0 warnings

    $ dune exec --root /Users/oobi/Documents/tot test/main.exe | tail -5
    PASS rec global unfolds on canonical arg
    PASS guarded rec stays stuck
    PASS termination guard rejects loop
    PASS stuck match conversion
    M0 kernel: all tests green        (28 PASS)

    $ dune exec --root /Users/oobi/Documents/tot test/surface.exe | tail -5
    PASS match on a function is not inductive
    PASS data parameter without the 0 marker
    PASS data parameter with a w marker
    PASS infer-position match without as/return
    M1 surface: all tests green       (30 PASS = 16 prior + 14 Stage C)

    $ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run examples/church.tot | tail -3
    def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
    def two : cnat
    fun f => fun z => (f (f (f (f z))))

    $ zsh dev/gates.sh | tail -1
    TEST-OK
## Stage D: stdlib, examples, docs (2026-09-01)

What changed:

- stdlib/prelude.tot (new): the plan's program VERBATIM — no line
  needed fixing; every check-position match rides the constant-motive
  rule and every ctor application saturates its 0-quantity params
  (`cons A h t`, `nil B`). Checks AND runs (exit 0 both modes).
- examples/nat.tot (new): self-contained Nat demo (data Nat, reducible
  def rec add, two + three); run prints
  "(succ (succ (succ (succ (succ zero)))))".
- dev/gates.sh: kept BUILD-OK + the two test exes + TEST-OK; added six
  script gates — `tot check` AND `tot run` over stdlib/prelude.tot,
  examples/church.tot, examples/nat.tot via dune exec --root. Success
  prints PASS-{CHECK,RUN}-{PRELUDE,CHURCH,NAT} only; a failure replays
  the captured CLI output (errors go to stdout) then FAIL-* + exit 1;
  all green ends in SCRIPTS-OK. No set -u, no loops, straight-line
  && chains.
- SPEC.md: decision log gained five 2026-09-01 (M2) entries (stamped
  quantities + Ann dropped + structural erasure; inductives:
  params-only/flat namespace/0-params/strict positivity/predicative
  bound; recursion: def rec + guard + guarded unfolding + no eta;
  data/match/def-rec surface pins; String/Json/literals/prelude
  auto-load deferred to M3). Section 3: match in the term grammar,
  data + def rec in a new surface-items note, totality paragraph now
  states the structural guard. Section 4: Term/Value/Global/Check
  bullets updated (entry kinds, frames, declare_ind/define_ind) +
  Totality module. Section 5: M2 marked done with actual contents
  (String/Json moved to M3; M3 gains literals + prelude auto-loading;
  M4 gains indexed inductives). Section 6: the erase-mirrors-check and
  eval-re-inference debts REMOVED (resolved by stamping); errors-line
  adjusted (M2 variants add records); six debts ADDED: no indices/
  nested/mutual/local-fix (M4), first-fit rec_arg, explicit motive in
  infer position, prelude-is-a-file, guarded unfolding requires
  reducible, and the Stage B interp function-readback latent.
- README.md: Status bumped to M2 (data/match/def rec/prelude); gates
  line now lists the PASS-*/SCRIPTS-OK markers and the three gated
  scripts.

Final gate battery (all green):

    $ dunecho build -- --root /Users/oobi/Documents/tot
    OK build: 0 errors, 0 warnings

    $ dune exec --root /Users/oobi/Documents/tot test/main.exe | tail -5
    PASS rec global unfolds on canonical arg
    PASS guarded rec stays stuck
    PASS termination guard rejects loop
    PASS stuck match conversion
    M0 kernel: all tests green        (28 PASS)

    $ dune exec --root /Users/oobi/Documents/tot test/surface.exe | tail -5
    PASS match on a function is not inductive
    PASS data parameter without the 0 marker
    PASS data parameter with a w marker
    PASS infer-position match without as/return
    M1 surface: all tests green       (30 PASS)

    $ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run examples/church.tot | tail -3
    def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat
    def two : cnat
    fun f => fun z => (f (f (f (f z))))

    $ dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run examples/nat.tot | tail -1
    (succ (succ (succ (succ (succ zero)))))

    $ zsh dev/gates.sh; echo EXIT=$?   (unpiped exit verified separately)
    ...
    TEST-OK
    PASS-CHECK-PRELUDE
    PASS-RUN-PRELUDE
    PASS-CHECK-CHURCH
    PASS-RUN-CHURCH
    PASS-CHECK-NAT
    PASS-RUN-NAT
    SCRIPTS-OK
    EXIT=0

M2 is complete. Nothing staged, nothing committed.
