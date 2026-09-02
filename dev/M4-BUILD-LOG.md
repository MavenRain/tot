# M4 build log

## Stage A: indexed inductive families, subsingleton elimination, positivity

Baseline before this stage (verified 2026-09-02, before any edit, clean
working tree at commit b01b3eb):

    dunecho build                      OK build: 0 errors, 0 warnings
    dune exec test/main.exe            53 "PASS " lines, "M0 kernel: all tests green"
    dune exec test/surface.exe         69 "PASS " lines, "M1 surface: all tests green"
    zsh dev/gates.sh                   GATE-EXIT=0, 167 "^PASS" lines, 0 "^FAIL" lines

Matches the plan's stated baseline exactly (53 + 69 + 44 + 1 = 167).
The red belonged to nobody: green before any edit, so this report is
the first stage's own work, absorbing nothing.

### What changed

`Term.t` gained `Auto` (a total dead end in every kernel pass this
stage;  Stage D gives it a real rule) and `Match`'s payload gained a
`scrut_q : Quantity.t` stamp plus a `motive` record
(`m_ind`/`m_idx`/`m_self`/`m_body`) replacing the bare `(string * t)
option`.  `Value.stuck_match`'s motive changed the same way.
`Global.ind_entry` gained an `indices` telescope and its `ctor_names`
became the three-state `ctors : ctor_status` (`Provisional` / `Builtin`
/ `Complete names`).  `Global.ctor_entry` gained `res_idx`, `full_arity`
and `self_rec`.  `Check.declare_ind` takes the new index telescope;
`Check.declare_builtin` (new) installs a type former that will never be
`define_ind`'d, marked `Builtin`.  `Check.define_ind`'s result-head rule
generalizes to `n_params + n_indices` applied arguments, with a
generalized `is_applied` and a new `index_expr_clean` predicate for
index-position arguments;  both are TOP-LEVEL functions (not nested in
`define_ind`) so kernel test A6 can call `index_expr_clean` directly.
`Check.match_scrut` is a deterministic two-pass: infer the scrutinee at
mode `Zero` first (always sound), then stamp `scrut_q = Zero` when
`Check.zero_eliminable` holds (at most one constructor, every argument
binder quantity 0, not self-recursive) or re-infer at the ambient mode
and stamp `Many` otherwise.  `Erase.term` gained the subsingleton arm:
`scrut_q = Zero` drops the scrutinee entirely (one branch: erase its
body directly;  zero branches: `EErased`;  two or more: the
`Erased_use "match"` backstop, provably unreachable given the checker's
own stamp).  Surface: `Syntax.IData` gained an `indices` telescope,
`Syntax.smotive` (new) carries the optional `in I y1 .. ym` clause,
`parser.ml`'s `parse_data` now parses the codomain as ONE term and
peels it (`peel_data_codomain`, retiring `parse_data_level`) so
`Nat -> Type 0` parses as one Nat-typed index via the existing arrow
sugar, and `parse_match` gained the `as x in I y1 .. ym return P` arm.
`Elab.term`'s `SMatch` case runs the motive's index-arity check (the
G2 check) since it already has `globals`.  `Bootstrap.phase1` switches
`String`/`Int`/`Div`/`IO` to `declare_builtin`.  `Cache.format_version`
bumped 5 -> 6.

### A plan-detail fill-in, recorded per the plan's own instruction

A6.3 replaces `is_applied` but does not say where in `define_ind`'s
ctor loop it runs relative to `infer_univ`.  The PRE-Stage-A (and
therefore unmodified-by-this-stage) architecture calls `infer_univ` on
the whole declared constructor type FIRST, then `strip_pis` +
`is_applied` on the result.  Building `m4a-vec-badindex.tot`'s fixture
(`vbnil : VecB A`, omitting the index) against that ordering produced
`Kernel.Not_a_universe` (`"not a universe: (0 n : Nat) -> Type 0"`),
not the plan-predicted `Bad_ctor`: an under-applied type former's own
type is a further Pi, never `Univ _`, so `infer_univ` on the whole
malformed type fails one layer before `is_applied`'s arity check is
ever reached.  Proof this is not an isolated fixture quirk: given the
current architecture, `is_applied`'s ARITY-mismatch branch specifically
is unreachable for ANY constructor whose declared type also
kind-checks (under-application always fails `infer_univ` first;
over-application applied further always fails `Not_a_function` first,
since the family reaches `Univ l` exactly at full saturation and
`App`'s infer rule requires a `VPi` head).  The existing M2/M3 negative
`Bad_ctor` tests (`case_positivity`, `case_universe`) never hit this
because they use 0-param families, whose codomain is a bare `Global`
reference, trivially `Univ`-kinded regardless of shape.

Fix: `define_ind`'s ctor loop now runs `strip_pis` + `is_applied` on
the RAW (pre-`infer_univ`) constructor type FIRST, giving the precise
index-count-aware `Bad_ctor` diagnosis immediately, and reuses `args`/
`cod` from the STAMPED type (via a second, post-`infer_univ`
`strip_pis`) for the per-argument positivity/universe walk.  This is
sound without exception: `is_applied`/`strip_pis` are pure structural
walks over `Var`/`Global`/`App`/`Pi` shape, and `infer` never changes a
`Var`'s index, a `Global`'s name, or a `Pi`'s own quantity, so the
raw-vs-stamped split is identical for any well-formed input;  the fix
touches only WHEN the check runs, not what it checks.  Verified: the
whole existing 122-test M2/M3 suite (kernel + surface) stayed green
through this change, `m4a-vec-badindex.tot` now pins the plan's own
predicted message exactly, and kernel test A5 (a DIFFERENT scenario:
a fully-saturated but non-uniform Fording codomain) already exercised
`is_applied`'s POSITION-mismatch branch correctly before this fix, so
only the arity branch was affected.

Also recorded: two plan cross-references in the Stage A test list
("the `Box` source of A16", "the `Vec` source of A16" for tests A13/A20)
do not match A16 itself (a parse-error test unrelated to Box or Vec);
read as pointing at section A15's fixtures (`m4a-box.tot`, the `Vec`
declaration inside `m4a-vec.tot`) instead, which is the only reading
that produces a coherent test.

### Files touched

Edited: `lib/term.ml`, `lib/value.ml`, `lib/global.ml`, `lib/error.ml`,
`lib/eval.ml`, `lib/check.ml`, `lib/totality.ml`, `lib/erase.ml`,
`lib/pp.ml`, `surface/syntax.ml`, `surface/parser.ml`, `surface/elab.ml`,
`surface/bootstrap.ml`, `surface/run.ml`, `surface/cache.ml`,
`test/main.ml`, `test/surface.ml`, `dev/gates.sh`, `SPEC.md`.

Not touched (no change needed): `surface/token.ml`, `surface/lexer.ml`
(the `in` keyword already existed and was already in the
application-stopping set), `bin/tot.ml` (Stage B/D work).

New: `test/fixtures/m4a-vec.tot`, `test/fixtures/m4a-vec-badindex.tot`,
`test/fixtures/m4a-box.tot`, `test/fixtures/m4a-sx.tot`,
`test/fixtures/m4a-ese-neg.tot`, `test/fixtures/m4a-fording.tot`,
`dev/M4-BUILD-LOG.md` (this file).

### New `Error.t` variants

- `Index_not_zero of string` -- an index binder marked quantity `w`.
- `Index_above_universe of { ind : string;  index : string }` -- an
  index TYPE lives above the inductive's declared universe.
- `Motive_index_arity of { ind : string;  expected : int;  found : int }`
  -- the motive's `in I y1 .. ym` clause binds the wrong index count.
- `Motive_wrong_ind of { expected : string;  found : string }` -- the
  motive names a different family than the scrutinee's own.
- `Builtin_not_eliminable of string` -- a match reached a builtin type
  former (declared via `declare_builtin`), which has no constructors
  and never will;  replaces the reused-but-wrong `Ind_incomplete`
  wording for this case (SPEC.md section 6 debt, now retired).

No new `Serror.t` variant this stage (the motive index-arity check
reuses `Serror.Kernel { err = Error.Motive_index_arity ... }`, per
A11's own instruction to keep `Serror.t` unchanged).

### Tests added

`test/main.ml` (kernel, labels `A1`-`A12`, +12, 53 -> 65):

- A1: an indexed family (`A1Vec`) declares, defines, and reports its
  arity (`Global.find_ind_arity` = `(1, 1)`, `full_arity` = 4,
  `self_rec` = true, `res_idx` length 1).
- A2: an index binder marked `w` is `Index_not_zero`.
- A3: an index type above the declared universe is
  `Index_above_universe`.
- A4: a constructor with the wrong index count is `Bad_ctor` (the
  reordering fix's own oracle).
- A5: the Fording route stays blocked -- `VecP1`'s `vpnil` isolates the
  result-head rule ("applied to its parameters");  `VecP2`'s `vpcons`
  alone (uniform codomain `VecP2 A n`, non-uniform argument
  `VecP2 A m`) isolates strict positivity ("negative or non-uniform
  occurrence of").
- A6: `index_expr_clean` rejects an index expression mentioning its
  own family (a direct unit-test call;  the check is a total backstop
  no source fixture can reach).
- A7: the subsingleton criterion, all four shapes -- zero-constructor
  and one-constructor-all-erased-non-self-recursive are
  `zero_eliminable`;  a `w`-carrying single constructor (Box) and a
  self-recursive erased singleton (SX) are not, and SX's `self_rec` is
  independently asserted `true` (the fence is self-recursion, not
  quantity).
- A8: subst-shaped erasure is the identity -- a one-constructor erased
  family's eliminating def erases to exactly `fun px => px`.
- A9: a zero-branch subsingleton match erases to `<erased>` (read from
  `pp.ml`, not guessed;  both the scrutinee's own binder and the whole
  match erase away).
- A10: additivity, a materialized constant motive still converts --
  reuses `case_uniform_motive` (F6), which already exercises the new
  motive record.
- A11: `Term.Auto` is `Cannot_infer` in `Eval.eval`, `Erase.closed` and
  `Check.infer` alike.
- A12: a builtin type former (`declare_builtin`) is
  `Builtin_not_eliminable`;  a `Provisional` inductive (mid-`declare_ind`
  window) is still `Ind_incomplete`, in the same test, so the split is
  shown to be a split.

`test/surface.ml` (labels `A13`-`A23`, +11, 69 -> 80), every exact
string below READ from the built binary via `gate-check`/`gate-run`,
never guessed:

- A13/A14: `Vec`/`Fin` declare and their constructors print the exact
  echo lines.
- A15: `eval vcons Nat zero (succ zero) (vnil Nat)` builds and its
  readback is `((vcons (succ zero)) vnil)` (params and the index
  erase;  only the two runtime-kept args per `vcons` survive).
- A16: `data B : (w n : Nat) -> Type 0 :=` is a `Parse` error ("data
  indices must be marked 0").
- A17: a motive naming the wrong family (`in Fin` over a `Vec`
  scrutinee) is `Kernel.Motive_wrong_ind`.
- A18: a motive with zero index binders over a one-index family is
  `Kernel.Motive_index_arity`.
- A19/A20/A21: the three erasure negatives (Bool two-constructor, Box
  `w`-carrying, SX self-recursive) each stay `Kernel.Erased_use`.
- A22/A23: a one-constructor erased family (`U1`) and a zero-
  constructor family (`Empty`) now eliminate and check.

One pre-existing M3 surface test updated to the plan's OWN intended
behavior change, not weakened: `A14: match on a String scrutinee
cannot eliminate` now pins `Kernel.Builtin_not_eliminable` (was
`Kernel.Ind_incomplete`), since `String` is now installed via
`declare_builtin` (A6.2);  the split this discharges is exactly SPEC.md
section 6's retired debt.  Every other existing case is byte-for-byte
unchanged.

Gate markers added to `dev/gates.sh`: `PASS-M4A-VEC`,
`PASS-M4A-VEC-BADIX`, `PASS-M4A-BOX`, `PASS-M4A-SX`,
`PASS-M4A-ESE-NEG`, `PASS-M4A-FORDING`, each wrapped in `"$watchdog" 30`
with a captured-output FAIL replay, driving the six new fixtures
through `test/surface.exe -- gate-run` (the one positive fixture,
pinning the exact readback via `rg -qx`) or `gate-check` (the five
negatives, pinning the exact reason substring via `rg -q`).

### PASS count, final

    dunecho build                OK build: 0 errors, 0 warnings
    dune exec test/main.exe      65 "PASS " lines (53 + 12), "M0 kernel: all tests green"
    dune exec test/surface.exe   80 "PASS " lines (69 + 11), "M1 surface: all tests green"
    zsh dev/gates.sh              GATE-EXIT=0
    rg -c '^PASS' gate.out        196
    rg -c '^FAIL' gate.out        (no matches, i.e.  0)

Decomposition: 65 kernel + 80 surface + 44 dev/gates.sh's own
pre-existing markers + 1 prim-lint (replayed) + 6 new M4 Stage A
markers = 196.  Baseline 167 plus this stage's 29 additions (12 + 11 +
6).  Every M2/M3 case still passes unedited;  nothing was deleted or
weakened, one case's expectation was corrected to the plan's own
intended new behavior (A14, above) and printed alongside its reasoning.

### Gate output tail (dev/gates.sh, full run)

    ...
    PASS-D-CACHE-HIT
    PASS-D-CACHE-MISS
    PASS-D-CACHE-BODYTRUNC
    PASS-D-CACHE-CORRUPT
    PASS-D-CACHE-MAGIC
    PASS-CACHE-NOHOME
    PASS-CACHE-NOEXEDIGEST
    PASS-M4A-VEC
    PASS-M4A-VEC-BADIX
    PASS-M4A-BOX
    PASS-M4A-SX
    PASS-M4A-ESE-NEG
    PASS-M4A-FORDING

### SPEC.md

Section 2: seven dated `2026-09-02 (M4, Stage A)` entries appended
(indexed inductive families incl.  the raw-vs-stamped `is_applied`
ordering argument, the motive record, the subsingleton rule with its
full Round-4 relaxation argument, the Fording blockage, the
index-expression backstop's unreachability, debts discharged, the
cache bump).  Section 3: the core grammar gained `scrut_q` and the
motive's `in I y1 .. ym` clause;  the surface `data` grammar gained the
`IDXTELE` form with its arrow-sugar residual noted inline.  Section 4:
`Term`/`Value`/`Global`/`Check` module descriptions updated for the new
fields and `declare_builtin`.  Section 6: removed "No indexed ...
inductives" (narrowed to nested/mutual/local-fixpoint, still open),
retired the `Eval.is_canonical` second-lookup debt and the builtin-
former/`Ind_incomplete` debt (both discharged this stage), and added
three new debts: the conservative `Level.le` bound on index types, the
unreachable `index_expr_clean` backstop, and the arrow-sugar
quantity-forcing residual on data index binders.

### Concerns for the next stage (Stage B)

- The `is_applied`-ordering fix (raw-term check before `infer_univ`) is
  new territory this stage discovered;  Stage B's `Eq` declaration and
  its constructors should be watched for the same class of issue,
  though `Eq`'s own shape (homogeneous, one index) is exactly the
  `Vec`/`Fin` shape already proven to work.
- `zero_eliminable`'s reachability depends on `Global.ctor_status` and
  `Global.ctor_entry.self_rec` exactly as installed by `define_ind`;
  Stage B's `axiom` entry kind must not be mistaken for an `Ind` by any
  future reader of `ctors`/`self_rec` (axioms have neither field).

## Stage B: propositional equality, the proof prelude, and axioms

Baseline before this stage (verified 2026-09-02, before any edit, on
the Stage A working tree exactly as handed off, uncommitted):

    dunecho build                      OK build: 0 errors, 0 warnings
    dune exec test/main.exe            65 "PASS " lines, "M0 kernel: all tests green"
    dune exec test/surface.exe         80 "PASS " lines, "M1 surface: all tests green"
    zsh dev/gates.sh                   GATE-EXIT=0, 196 "^PASS" lines, 0 "^FAIL" lines

Matches the hand-off exactly (167 baseline plus Stage A's 29 own
additions).  Green before any edit, so this report is this stage's own
work, absorbing nothing from Stage A.

### What changed

`Global.entry` gained a fifth kind, `Axiom of axiom_entry` (`{ ax_ty :
Term.t }`): no `def` field and no `reducible` flag, the same shape as
`Prim`.  `Global.entry_ty`/`def_of`/`ind_of`/`ctor_of`/`prim_of` all
gained the new arm;  `axiom_of` and `find_axiom` are new accessors,
symmetric with the other four.  `Check.define_axiom` (new, beside
`define_prim`) is the only public way to install one:
`ensure_fresh` then `infer_univ` to validate and stamp `ax_ty`.
`Check.infer`'s `Term.Global` arm gained ONE guard, a `match () with`
ladder beside the existing lookup (`is_axiom`, new, mirrors
`is_effect_headed`'s shape): an `Axiom` entry at mode `Many` is
`Error.Axiom_runtime_use`, at mode `Zero` it is the ordinary neutral
with its stored type.  `Eval.eval`'s `Term.Global` arm gained
`Global.Axiom _ -> VNeutral (HGlobal name, [])`, the same opaque shape
as `Prim`.  `Error.t` gained `Axiom_runtime_use of string`.

Surface: `Token.KAxiom` ("axiom", one new keyword).  `Syntax.item`
gained `IAxiom of { loc;  name;  ty }`.  `Parser.parse_items` gained the
`axiom NAME : TYPE` arm (and its own "expected 'NAME : TYPE' after
axiom" error for a malformed one);  `Parser.kind_starts_atom` and
`Parser.parse_ctors`'s stop set both gained `KAxiom`.
`Run.policy` (new: `{ no_axioms : bool }`, default `{ no_axioms =
false }`) is now threaded through `Run.item` (a new REQUIRED `~policy`
label;  its only direct caller, `Bootstrap.fold_items`, passes
`~policy:Run.default_policy` explicitly, matching the plan's own
emphasis that this is load-bearing, not a filled-in default) and
through `Run.script` (a new OPTIONAL `?policy` label defaulting to
`Run.default_policy`, so every pre-Stage-B call site is unchanged).
`Run.item`'s new `IAxiom` arm elaborates the type, then either errors
`Serror.Axioms_disabled` (under `policy.no_axioms`) or calls
`Check.define_axiom` and prints `"axiom NAME : TYPE"`;  it never calls
`Interp.define`, so an axiom has no runtime entry to reach at all.
`Bootstrap.item_name` gained an `IAxiom` arm (`Some name`).
`Serror.t` gained `Axioms_disabled of { loc;  name }`, tag
`"Axioms_disabled"`.  `bin/tot.ml` replaced its literal positional argv
match with a small total flag parser (`opts`, `default_opts`,
`parse_flags`, matching the plan's own given shape byte for byte) so
`--no-prelude` and the new `--no-axioms` compose in any order;  the
usage string is now `"usage: tot (check|run) [--no-prelude]
[--no-axioms] FILE | tot prims"`.  `Cache.format_version` bumped 6 -> 7.

`stdlib/prelude.tot` gained, in order, appended at the file's end
(after `jsonToList`, per the plan, keeping both phase-split markers
untouched): the B1 equality layer (`Empty`, `Eq`, `Dec`, `exfalso`,
`subst0`, `J0`, `sym0`, `trans0`, `cong0`), the B2 decidable-equality
layer on `Nat` (`pred`, `natFamZero`, `zeroNotSucc`, `succInj`,
`natDecEq`), and the B6 monad-law axioms (`ioBindPure`, `ioBindRet`,
`ioBindAssoc`), copied from the plan verbatim (B1/B2/B6 are exact
source blocks, not paraphrases).

### Plan-detail fill-ins, recorded per the plan's own instruction

1.  **A Stage A/Stage B name collision the plan did not anticipate.**
   Stage A's own surface test A23 ("an empty family now eliminates")
   declares `data Empty : Type 0 :=` and `def exfalso : ...` INLINE
   against the bootstrapped prelude state `bst`.  Stage B's B1 prelude
   block ALSO declares `Empty` and `exfalso`, in the SAME prelude, so
   A23 started failing with `Duplicate_global "Empty"` the moment the
   prelude folded.  Fix: renamed A23's own local declarations to
   `EmptyA23`/`exfalsoA23` (source string and expected-lines list both
   updated);  the assertion under test (a zero-constructor family
   eliminates) is byte-for-byte unchanged, only the two names are, and
   a comment at the test site records why.  Verified this is the ONLY
   collision: `rg` across `test/surface.ml`, `test/fixtures/` and
   `examples/` for every name the Stage B prelude newly introduces
   (`Empty`, `Eq`, `Dec`, `yes`, `no`, `refl`, `subst0`, `J0`, `sym0`,
   `trans0`, `cong0`, `natDecEq`, `pred`, `natFamZero`, `zeroNotSucc`,
   `succInj`, the three `ioBind*` axioms, `exfalso`) turned up nothing
   else.
2.  **`surface/serror.ml` is missing from Stage B's own "Files:" header
   list** (line ~1157) even though section B4's body explicitly gives
   `Serror.t`'s new `Axioms_disabled` variant with full `to_string`/
   `tag` text.  Read as an omission, not a boundary: edited it anyway,
   since the body text is unambiguous and the file demonstrably needs
   the variant for `IAxiom`'s `policy.no_axioms` arm to typecheck.
3.  **B6's fixture cannot run under `expect_cli_run_lines` AS WRITTEN.**
   The plan says test B6 uses "the CLI path with `expect_cli_run_lines`
   over `test/fixtures/m4b-subst-erases.tot`", but that helper
   (pre-Stage-B) hard-codes `tot run --no-prelude PATH` in its shelled-
   out command, while `m4b-subst-erases.tot` (B9's own fixture content)
   uses the prelude's `Nat`/`Eq`/`subst0`/`refl` without declaring any
   of them itself.  Fix: gave `expect_cli_run_lines` an
   `?(no_prelude = true)` parameter (default preserves both pre-
   existing callers, F1's witness fixture and T0's erased-guard
   fixture, byte for byte) and B6 passes `~no_prelude:false`, relying
   on `bin/tot.ml` auto-loading the prelude by default (M3 Stage D,
   D1) exactly as the bare `dune exec ... test/surface.exe --
   gate-check` path already does for the SAME fixture under gate
   `PASS-M4B-SUBST`.  Verified both paths print byte-identical output.
4.  **B9's schematic printed value is not the literal printer output.**
   The plan's prose writes `axiom myAx : (Eq Nat zero zero)` as the
   expected echo line, but `Pp.term`'s `Term.App` arm wraps EVERY
   application in its own parens regardless of nesting depth
   (`"(%s %s)"`, unconditionally), so the actual printed line, READ
   from the built binary via `gate-check` and via the CLI directly, is
   `axiom myAx : (((Eq Nat) zero) zero)`.  Every pinned string in this
   stage's tests and gates (subst0/trans0/symNat/castNat's printed
   types, the axiom echo lines, the natDecEq readbacks `yes`/`no`, the
   `--no-axioms` message) was read from the built binary this way, per
   the plan's own "read what the binary prints;  do not guess the
   spelling" instruction (B7) applied uniformly to every pin in this
   stage, not just the one it names.
5.  **`PASS-M4B-AXIOM` has no named fixture.** B9's fixture list names
   only `m4b-subst-erases.tot`, `m4b-deceq-runs.tot` and
   `m4b-noaxioms.tot`, but B10's own marker list requires
   `PASS-M4B-AXIOM` (Gate B (iv): "an axiom is rejected at mode w and
   accepted at mode 0").  One script cannot show both an OK fold's
   printed lines and a LATER hard error's message in the same stdout
   capture (a fold error short-circuits `Run.script` before any
   earlier line is returned), so two small fixtures were added:
   `m4b-axiom.tot` (`axiom myAx : Eq Nat zero zero` then `check myAx`,
   accepted, pins the two lines) and `m4b-axiom-runtime.tot` (the same
   axiom then `eval myAx`, rejected, pins `Kernel.Axiom_runtime_use`'s
   message substring).  Both driven under ONE `PASS-M4B-AXIOM` marker,
   matching the file's own "both halves asserted" idiom already used
   for `PASS-M4B-NOAXIOMS`.
6.  **B5's own `PASS-C-ARGV-USAGE` cross-reference does not name what it
   thinks it names.** B5 says "Keep the exit-2 usage path and its
   existing gate `PASS-C-ARGV-USAGE` green", but that gate exercises
   `test/surface.exe -- gate-check` (a MISSING-path usage error,
   `"unknown subcommand: gate-check"`), not `bin/tot.ml`'s own argv at
   all;  `bin/tot.ml`'s usage message has no dedicated gate marker in
   `dev/gates.sh` before or after this stage.  Read as the same class of
   imprecise cross-reference Stage A recorded for its own A13/A16/A20
   labels: built the flag parser as specified regardless, verified
   `PASS-C-ARGV-USAGE` stays green (it is untouched by any Stage B
   file), and additionally hand-verified `bin/tot.exe`'s own usage/bad-
   flag/prims paths still behave correctly (`tot check` alone,
   `tot check --bogus FILE`, `tot prims`) since no gate marker does.

### Stage B tests

`test/main.ml` (kernel), labels `B1`-`B4` (the numbers repeat M3
Stage A's own `B1`-`B5` prim-catalog labels, exactly the precedent
Stage A itself set reusing `A1`-`A8`'s numbers for indexed-family
tests;  every PASS line is a distinct full string, so nothing collides
mechanically):

- B1: `define_axiom` installs an opaque global (`VNeutral (HGlobal
  "ax_b1", [])`, not convertible with `zero`).
- B2: an axiom at mode `w` is `Axiom_runtime_use`;  the same global at
  mode `0` succeeds with its stored type (`Eval.conv`-checked against
  `Nat`).
- B3: `define_axiom` rejects a duplicate name (`"Nat"`),
  `Duplicate_global`.
- B4: an axiom is not a def, an ind, a ctor, or a prim (all four
  `_of` accessors `None`);  `entry_ty` still returns the stored type.

`test/surface.ml`, labels `B5`-`B11` continuing the same numbering:

- B5: `check subst0` and `check trans0` under `bst`, pinning the exact
  printed types (parenthesization read from the binary, see fill-in 4).
- B6: `m4b-subst-erases.tot` (symNat/castNat) through the real CLI
  binary with the prelude auto-loaded (see fill-in 3).
- B7: `natDecEq` computes both a `yes` and a `no` (bare constructor
  tags: both ctor args are quantity 0, so erasure drops them).
- B8: a `Dec` scrutinee (`sameArity`, matching `natDecEq`'s result)
  drives a `Bool`, pinning `"true"`.
- B9: an axiom item echoes (`"axiom myAx : (((Eq Nat) zero) zero)"`)
  and checks at mode 0, then `eval myAx` is `Kernel.Axiom_runtime_use`.
- B10: the same shape under `~policy:{ no_axioms = true }` (called via
  `Tot_surface.Run.script` directly, matching the file's own D4g-style
  direct-call idiom) is `Axioms_disabled`.
- B11: the broken single-match `trans0` spelling
  (`subst0 A b c (fun z => Eq A a z) h2 h1`, forwarding the 0-bound
  `h1` to a `w` position) is `Kernel.Erased_use` ("erased variable h1
  used at runtime");  this is the regression oracle that keeps
  `trans0`'s nested double match from ever being "simplified" back to
  the broken shape.

### Stage B fixtures

`m4b-subst-erases.tot` (`PASS-M4B-SUBST`), `m4b-deceq-runs.tot`
(`PASS-M4B-DECEQ`), `m4b-noaxioms.tot` (`PASS-M4B-NOAXIOMS`) are the
plan's B9 content verbatim.  `m4b-axiom.tot` and
`m4b-axiom-runtime.tot` (both `PASS-M4B-AXIOM`) are this stage's own
fill-in, fill-in 5 above.

Gate markers added to `dev/gates.sh`, each in the file's own capture-
then-assert idiom wrapped in `"$watchdog" 30`, FAIL branch replaying
captured output and exiting 1: `PASS-M4B-SUBST` and `PASS-M4B-DECEQ`
(via `test/surface.exe -- gate-check`/`gate-run`, exact multi-line
`$'...'` string equality), `PASS-M4B-AXIOM` (two `gate-check` calls,
one accept one reject, both asserted under one marker) and
`PASS-M4B-NOAXIOMS` (two `bin/tot.exe -- check`/`check --no-axioms`
calls, since the driver flag lives only in `bin/tot.ml`, not in
`test/surface.exe`'s gate subcommands).

### PASS count, final

    dunecho build                OK build: 0 errors, 0 warnings
    dune exec test/main.exe      69 "PASS " lines (65 + 4), "M0 kernel: all tests green"
    dune exec test/surface.exe   87 "PASS " lines (80 + 7), "M1 surface: all tests green"
    zsh dev/gates.sh              GATE-EXIT=0
    rg -c '^PASS' gate.out        211
    rg -c '^FAIL' gate.out        (no matches, i.e.  0)

Decomposition: 69 kernel + 87 surface + 44 dev/gates.sh's own
pre-existing markers + 6 Stage A markers + 4 new Stage B markers + 1
prim-lint (replayed) = 211.  Baseline 196 plus this stage's 15
additions (4 + 7 + 4).  Every M2/M3/Stage-A case still passes;  the one
existing case touched (A23) had its OWN two local names renamed to
dodge a Stage-B-introduced collision, not its assertion weakened
(fill-in 1 above);  nothing else was deleted, weakened, or renamed.

### Gate output tail (dev/gates.sh, full run)

    ...
    PASS-M4A-VEC
    PASS-M4A-VEC-BADIX
    PASS-M4A-BOX
    PASS-M4A-SX
    PASS-M4A-ESE-NEG
    PASS-M4A-FORDING
    PASS-M4B-SUBST
    PASS-M4B-DECEQ
    PASS-M4B-AXIOM
    PASS-M4B-NOAXIOMS

### SPEC.md

Section 2: four dated `2026-09-02 (M4, Stage B)` entries appended
(equality's permanent shape written out in full incl.  the `Dec`/
`natDecEq` rationale, the `trans0` nested-double-match reasoning with
its regression oracle named, the `axiom` entry kind with its full
confinement argument and the monad-law consistency argument, the
cache bump).  Section 3: added the `axiom NAME : t` surface item.
Section 4: added `Axiom` to the `Global` entry-kind list and
`define_axiom` to `Check`'s public-growth list.  Section 6: the monad-
law debt is marked `Retired (M4 Stage B)` in place (matching the
file's own existing convention for `Eval.is_canonical`'s and the
Interp-readback debt's retirements, rather than deleting the entry
outright), and a new debt is appended: `Eq`'s monomorphism at `Type 0`
(a `Type 1` equation needs its own hand-written `Eq1`/`subst1`/...
layer).

### Concerns for the next stage (Stage C)

- Stage C's own gate should walk `subst0`'s ERASED body directly (it
  must be the bare identity, `EApp`/`ELam` down to a plain `fun px =>
  px` shape once `EErased`/quantity-0 binders are dropped) rather than
  only observing that `check` succeeds, since this stage's B6/B9
  fixtures only exercise the CHECK side of the equality layer;  nothing
  in this stage's suite reads back `subst0`'s erased term directly.
- The three `ioBind*` axioms are never USED by anything in this
  stage's tests (no proof cites them);  Stage C's erasure-backstop work
  should confirm an axiom-headed proof term used only at quantity 0
  erases to `EErased` cleanly wherever it is embedded, since no
  existing fixture currently forces that path.
- `Run.policy`'s `{ no_axioms : bool }` shape is Stage B's alone;  the
  plan's Stage D section separately extends `bin/tot.ml`'s `opts`
  with `require_main` and a `Run.policy`-adjacent
  `Serror.Missing_main`, but does NOT (per the plan) add a
  `require_main` field to `Run.policy` itself, only to `opts` and a
  new `Run.main_epilogue` parameter;  Stage D should re-read `opts`'s
  current two-field shape and `check_or_run`'s dispatch exactly before
  extending either, since a careless third `opts` field could silently
  stop composing with `parse_flags`'s existing two `"--no-*"` arms if
  the new flag is not added the same way.

## Stage C: the executable erasure backstop

Baseline before this stage (verified 2026-09-02, before any edit, on
the Stage A + Stage B working tree exactly as handed off, uncommitted):

    dunecho build                      OK build: 0 errors, 0 warnings
    dune exec test/main.exe            "M0 kernel: all tests green"
    dune exec test/surface.exe         "M1 surface: all tests green"
    zsh dev/gates.sh                   GATE-EXIT=0, 211 "^PASS" lines, 0 "^FAIL" lines

Matches the hand-off exactly (167 baseline plus Stage A's 29 plus Stage
B's 15 own additions).  Green before any edit, so this report is this
stage's own work, absorbing nothing from Stage A or Stage B.

### What changed

`lib/eterm.ml`: `Eterm.mentions` (new), promoted verbatim from
`test/main.ml`'s private `eterm_mentions` walk named in the plan's C1 --
structural, total, exhaustive over every `Eterm.t` arm, answering "does
`name` occur anywhere in `e` as an `EGlobal`".

`lib/interp.ml`: `Interp.guard` (new), the three-state runtime
unfolding guard `Unguarded | GuardedAt of int | Frozen`.  `gentry`'s
`grec_arg : int option` field is replaced by `gguard : guard`.
`exec`'s `EGlobal` arm and `apply`'s `EHGlobal` arm both become a plain
exhaustive `match g.gguard with` (three arms;  `Unguarded` forces the
body / falls to the guarded canonicity test as before, `GuardedAt k`
keeps the existing `leading_fapp_args`/`is_canonical` test verbatim,
`Frozen` always returns the stuck neutral without ever calling `force`,
even in `apply`'s otherwise-unreachable `Unguarded` arm, spelled out
because the match must be exhaustive).  `define` takes `~guard:guard`
instead of `~rec_arg:int option`;  `add_ctor`/`add_erased`/`add_prim`
all seed `gguard = Unguarded`.

`surface/run.ml`: `remap_rec_arg` is replaced by `compute_guard
~(name : string) (def : Term.t) (rec_arg : int option) (def_e :
Eterm.t) : Interp.guard`, the plan's C3 code verbatim (the `Many` case
is Round 2's remap unchanged;  the `Zero` case now runs `Eterm.mentions
name def_e` -- no mention gives `Unguarded`, a mention gives `Frozen`).
The `IDef` run-mode call site passes
`~guard:(compute_guard ~name dentry.Global.def dentry.Global.rec_arg
def_e)`.

`surface/cache.ml`: `format_version` bumped 7 -> 8, checklist comment
extended in place.

No `Error.t` or `Serror.t` variant was added: Stage C widens an
existing runtime plumbing type (`Interp.gentry`'s guard field) and adds
one pure structural function;  every new failure mode this stage could
in principle hit (an unknown global name in `apply`'s `EHGlobal` arm,
an out-of-range `rec_arg`) already had a total backstop (`Option.fold`
to a safe default) before this stage and keeps the same shape.

### Stage C tests

`test/main.ml` (kernel), appended after the existing axiom cases:

- C1: `Eterm.mentions` is exhaustive and correct.  One probe shape
  buries an `EGlobal` under `ELam`/`EApp`/`ELet`/an `EMatch` branch;
  `true` on the buried name, `false` on a differently-named probe of
  the identical shape.
- C2 is not a new case: the existing T0 case
  (`case_erased_guard_no_self_ref`) is rewritten to call the promoted
  `Eterm.mentions "ghost" erased` instead of its own now-deleted
  private `eterm_mentions` copy.  Its label is kept byte for byte
  ("T0: rec def guarded on an erased formal has no self-reference
  after erasure");  see the fill-in below on the plan's claim that
  `dev/gates.sh` anchors that label.
- C3: a `Frozen` global stays neutral under application.  A hand-seeded
  `Interp.globals` binds `loopy` with `~guard:Interp.Frozen` over the
  body `EApp (EGlobal "loopy", EGlobal "loopy")` (which would recurse
  through `exec`'s `EGlobal` arm onto its own still-`GDeferred` cell
  and diverge if ever forced) and a zero-arity ctor `unit0`;  applying
  `loopy` to `unit0` through plain `Interp.exec`/`quote` returns
  (not hangs) the exact frozen spine, pinned as `Pp.eterm`'s printed
  `"(loopy unit0)"`.

`test/surface.ml`, appended after B11:

- C4: subst0 erases to the identity and mentions nothing.  Looks up
  `subst0`'s `Global.dentry` in the bootstrapped prelude state `bst`,
  runs `Erase.closed` on its def, and asserts BOTH `Eterm.mentions
  "subst0" erased = false` AND `Pp.eterm [] erased = "fun px => px"`
  exactly (the subsingleton match on the erased hypothesis `h` drops
  out entirely under `lib/erase.ml`'s `scrut_q = Zero` arm, leaving the
  identity function on the sole kept argument `px`).  This is the gate
  the Stage B report's own "concerns for the next stage" flagged
  (walk the erased body directly, not just observe that `check`
  succeeds).
- C5: the s0-erased-guard fixture still runs Unguarded.  A new
  `script_items` helper folds `s0-erased-guard.tot` through
  `Lexer.lex`/`Parser.parse`/`Run.item` in process (mirroring
  `Run.script`'s own fold, minus the epilogue), looks up `ghost`'s
  `Global.dentry`, erases its def, and asserts
  `Run.compute_guard ~name:"ghost" ...` returns exactly
  `Interp.Unguarded` -- the "only live case" claim made falsifiable
  rather than merely exercised end to end by the existing T0 CLI case.

New fixture `test/fixtures/m4c-frozen.tot`:

    eval subst0 Nat zero zero (fun n => Nat) (refl Nat zero) (succ zero)

Run through `test/surface.exe -- gate-run` (prelude auto-loaded by
`Bootstrap.state ()`, per `run_gate`'s existing shape;  trace lines
reset once at the end of bootstrapping, so this is the fixture's ONLY
output line), it exercises `subst0`'s whole pipeline end to end --
parse, elaborate, check, erase, `Interp.exec`, `Interp.quote`, print --
and prints exactly `(succ zero)`.

### Gate markers added

`PASS-M4C-FROZEN`: `m4c-frozen.tot` under `test/surface.exe --
gate-run`, `"$watchdog" 10`, exact stdout equality `(succ zero)`, exit
0;  the FAIL branch replays captured output and exits 1, in the file's
existing capture-then-assert idiom.

`PASS-M4C-SUBST-IDENTITY`: an anchored `rg -q '^PASS C4: subst0 erases
to the identity and mentions nothing$'` against the already-captured
`$surface_out` (the plain `dune exec test/surface.exe` run near the
top of the script), the same derived-marker idiom `PASS-A-LITERALS`
uses for A9/A10 -- proves the C4 claim held in THIS run rather than
merely that the suite as a whole exited 0.

Both markers inserted immediately before the file's final `exit 0`
(the scratch-dir cleanup trap installed at Gate D's top is untouched).

### Plan-detail fill-in: the T0 "anchored pattern" claim

C5.2 of the plan says `test/surface.exe`'s (sic;  kernel-side)
`dev/gates.sh` "matches [T0's label] with an anchored pattern," as the
reason to keep it byte for byte.  `rg` across `dev/gates.sh` for T0's
label text, and for any substring of it, found no such anchor: no
existing gate greps for it.  The instruction was followed anyway (T0's
label is unchanged, byte for byte) since keeping a long-lived
regression label stable costs nothing and the plan's own reachability
discipline (SPEC.md section 2's dated entries) treats a label rename
as exactly the kind of silent-erosion risk this house style guards
against;  only the stated REASON for the instruction does not hold
against the repo as it stands.  Recorded per the plan's own instruction
to log a disagreement rather than silently act on it.

### Out of scope, left for a later stage

The Stage B report's "concerns for the next stage" also asked that
Stage C confirm an axiom-headed proof term used only at quantity 0
erases to `EErased` cleanly wherever embedded.  The plan's own Stage C
section (the only spec for this stage) names no such test, and Stage
C's file list does not include `stdlib/prelude.tot` or any axiom
fixture, so this was left untouched rather than added unilaterally.
Recorded here so the gap is visible rather than silently dropped.

### PASS count, final

    dunecho build                OK build: 0 errors, 0 warnings
    dune exec test/main.exe      "M0 kernel: all tests green" (+2: C1, C3)
    dune exec test/surface.exe   "M1 surface: all tests green" (+2: C4, C5)
    zsh dev/gates.sh              GATE-EXIT=0
    rg -c '^PASS' gate.out        217
    rg -c '^FAIL' gate.out        (no matches, i.e.  0)

Decomposition: 211 Stage-B baseline + 2 new kernel cases (C1, C3) + 2
new surface cases (C4, C5) + 2 new `dev/gates.sh` markers
(`PASS-M4C-FROZEN`, `PASS-M4C-SUBST-IDENTITY`) = 217.  No existing case
was deleted, weakened, or renamed;  T0's label and assertion are
unchanged, only its implementation now calls the promoted
`Eterm.mentions` instead of a private copy (C2).

### Gate output tail (dev/gates.sh, full run)

    ...
    PASS-M4A-VEC
    PASS-M4A-VEC-BADIX
    PASS-M4A-BOX
    PASS-M4A-SX
    PASS-M4A-ESE-NEG
    PASS-M4A-FORDING
    PASS-M4B-SUBST
    PASS-M4B-DECEQ
    PASS-M4B-AXIOM
    PASS-M4B-NOAXIOMS
    PASS-M4C-FROZEN
    PASS-M4C-SUBST-IDENTITY

### SPEC.md

Section 2: four dated `2026-09-02 (M4, Stage C)` entries appended (the
`Frozen` backstop and the Round 4 invariant now being executable, the
emptiness claim recorded as staying unproven with nothing load-bearing
resting on it, `Eterm.mentions`'s promotion, the cache bump).

### Concerns for the next stage (Stage D)

- `Interp.gentry`'s `gguard` field is now a plain three-state sum with
  no smart constructor of its own;  `compute_guard` is the only place
  that builds a `GuardedAt`/`Frozen` value from kernel-level
  information.  Stage D's class resolution work should not need to
  touch either, but if a future stage ever wants a SECOND source of
  `Frozen` (say, a class-coherence-driven opaque global), route it
  through `compute_guard`'s shape rather than constructing
  `Interp.Frozen` ad hoc at a new call site, so the "reachable only
  through a provably empty type" comment on `guard` stays true of
  every `Frozen` value in the codebase, not just this stage's.
- `Frozen` is dead code on every def this milestone can construct (the
  emptiness claim is unproven but nothing currently exercises it
  through a real self-recursive all-erased family reaching runtime,
  since Stage A's fence already rejects `SX`-shaped matches at the
  STAMP before Stage C's guard is ever consulted).  If Stage D or a
  later milestone lands mutual or nested inductives, re-open SPEC.md's
  Stage C "emptiness claim stays UNPROVEN" entry before assuming the
  fence still covers every case `Frozen` was meant to backstop.

## Stage D: deterministic type classes and the driver debts

Baseline before this stage (verified 2026-09-02, before any edit, on
the uncommitted Stage A+B+C working tree):

    dunecho build                      OK build: 0 errors, 0 warnings
    dune exec test/main.exe            "M0 kernel: all tests green"
    dune exec test/surface.exe         "M1 surface: all tests green"
    zsh dev/gates.sh                   GATE-EXIT=0, 217 "^PASS" lines, 0 "^FAIL" lines

Matches the plan's stated Stage-D starting point exactly (the Stage C
report's own final PASS count).  Green before any edit, so this report
absorbs nothing from a previous stage.

### What changed

`lib/error.ml` gained three variants: `Inst_unresolved`, `Inst_bad_shape`
and `Inst_depth` (D1).  `lib/check.ml` is the stage's centre of gravity:
`term_size` (a term's syntactic node count, instance resolution's fuel
budget) and `instance_head_name` (the `Term.Global` at an accumulator
term's spine head) are small total helpers;  `resolve_auto` and
`build_instance` are a mutually recursive pair implementing D2's rule
exactly -- `resolve_auto` requires the expected type to be `VInd (cls,
[av])`, reads the KEY off `av`'s own head, looks up `"inst$" ^ cls ^ "$"
^ key`, and hands the instance's own type value to `build_instance`,
which peels its Pi telescope (a `VUniv` domain consumes the next type
argument from `targs`;  a single-parameter-class domain recurses into
`resolve_auto` for a sub-dictionary;  any other domain, or an empty
`targs` where a type argument was expected, is `Inst_bad_shape`) down
to a non-Pi codomain, returning the built application.  `Check.check`'s
`Term.Auto` arm now quotes the expected type, sizes it for the initial
fuel, resolves, and RE-CHECKS the candidate against the expected type
through the ordinary rule (point 6 of D2: a malformed table entry fails
loudly instead of resolving wrongly) -- `Check.infer`'s own `Auto` arm
is UNCHANGED (`Cannot_infer "auto"`;  resolution needs an expected type,
so it stays check-only).  `single_param_no_index`,
`validate_instance_shape` and `define_instance` implement D2's
registration-time validator: peel the leading Pi telescope classifying
each domain as a type binder or a dictionary binder referencing an
EARLIER type binder (tracked as peel POSITIONS, converted to the de
Bruijn index a binder has at the CURRENT depth via `depth - 1 - p`);
the codomain must be `C (K a1 .. ak)` with `a1 .. ak` the recorded type
binders in declaration order (`positions_match`, hand-rolled rather
than `List.for_all2`, which raises on a length mismatch the caller
already ruled out, per house style);  recompute the mangled name from
the CHECKED `C`/`K` and require it to equal the caller's `name`.  A
ground instance at an applied key (`EqD (List Int)` with no type
binders) fails the key-argument-COUNT check against zero recorded type
binders, so every key has exactly one derivation route, with no
special-casing needed.  `define_instance` validates BEFORE calling
`define ~reducible:true`, which performs the actual `ensure_fresh`
coherence check -- there is no separate class-coherence kernel state.

Surface: `Token.kind` gained `KClass`/`KInstance`/`KAuto`/`KInst` plus
`LBrace`/`RBrace`/`Semi` (the class method list's own delimiters, not
previously lexable at all);  the lexer keyword table and `go`'s
single-char dispatch both grew accordingly.  `Syntax.t` gained
`SAuto`/`SInst`;  `Syntax.item` gained `IClass`/`IInstance`;
`Syntax.defkind` (`DNonRec | DRec | DRecPartial`) replaces `IDef`'s
`(rec_, partial)` bool pair (D5.4), making the illegal `partial = true,
rec_ = false` state unrepresentable.  `Parser.parse_term` dispatches
`KInst` to `parse_inst` (two `parse_atom` calls, mirroring `let*`'s own
explicit-type-argument fallback shape exactly);  `parse_atom` gained
`KAuto` as a plain atom;  `parse_class`/`parse_class_methods` parse
`class NAME (0 A : Type L) := { m1 : T1 ;  .. }`;  `parse_instance`
parses `instance : TY := TERM`;  `parse_def`/`parse_def_body` produce
`Syntax.defkind` directly;  `parse_ctors`'s stop set and `parse_items`'
dispatch both gained `KClass`/`KInstance`.  `Elab.term` gained
`SAuto -> Term.Auto` and `SInst (_, c, t) -> Term.Ann (Term.Auto,
Term.App (Quantity.Many, c_t, t_t))` -- the WHOLE `inst` implementation,
no new core constructor: an annotated `Auto` already routes through
`Check.check`'s existing `Ann` path.  `Run.item` becomes `let rec item`
so `IClass`'s expansion (one `IData` dictionary, ctor uniformly named
`"mk" ^ name`, plus one projection `IDef` per method, matching `xi`
against `x1 .. xn` in a plain `match`) can fold each produced item
through `item` itself;  `IInstance` reads `(C, K)` off the type's own
UNELABORATED codomain spine (`instance_key`, shared with
`Bootstrap.item_name`) to build the mangled name, then elaborates,
calls `Check.define_instance`, and populates `eglobals` exactly like an
ordinary `IDef` (erase, `compute_guard` with `rec_arg = None`, so
always `Unguarded`, `Interp.define`).  `Run.policy` gained
`require_main : bool` (D5.2);  `main_epilogue` gained a `~policy`
parameter and returns `Serror.Missing_main` from its own `~none` branch
when `policy.require_main` holds and no `main` def exists.
`Bootstrap.item_name` gained `IClass`/`IInstance` arms (the latter via
`Run.instance_key`);  `kept_pi_count` gained `SAuto`/`SInst` arms (0
kept, unreachable from a prim's own source-text type, but required for
exhaustiveness).

`bin/tot.ml`'s `opts` gained `serror_exit : int` (default 1) and
`require_main : bool` (D5.1/D5.2);  `parse_flags` grew `--serror-exit
N` (0..255, else a parse error) and `--require-main`;  `run_file`'s
missing-file branch, `Run.script`'s own error branch, and
`run_with_prelude`'s bootstrap-failure branch all return
`opts.serror_exit` instead of the literal `1`.  `surface/cache.ml`
(D5.3): `exe_digest_hex` now hashes a `device:inode:mtime:size`
`Unix.stat` string through `Digest.string` instead of `Digest.file`-ing
the whole executable, with `Digest.file` kept as the fallback for the
one case `Unix.stat` itself cannot cover;  `format_version` bumped 8 ->
9 (the exe-identity header field's MEANING changed;  no marshaled OCaml
type did).  `stdlib/prelude.tot`: appended, after Stage B's axiom
block (no split marker moved), `anyList`/`boolEq`/`listEqBy`, the three
dictionary classes `EqD`/`OrdD`/`ShowD`, six instances, and `member` --
verbatim the plan's own D4 block, already verified on the M3 binary
with hand-written dictionaries.

### A file-tail read bug caught and fixed before it could hide

Appending the D4 block via a single `old_string`/`new_string` match on
`ioBindAssoc`'s TAIL truncated it: the axiom's real type is `Eq (IO C)
LHS RHS` with `RHS` continuing onto a FOURTH physical line (`(bindIO A
C m (fun a => bindIO B C (f a) g))`), which an earlier `Read` at
`offset=120 limit=19` never reached (line 139 of a 139-line file, one
past the read window).  The `old_string` match therefore ended one line
short, splicing new content in before `RHS` and leaving it dangling
after `def member`'s body -- caught immediately by `bootstrap-only`
failing with "not a universe: (0 b : (IO #3)) -> Type 0" (a `VPi`
printed with an out-of-range de Bruijn index, `Pp.term`'s own signal
that a term was quoted out of its intended scope).  Bisected by
truncating a scratch copy of the prelude at successive line counts
(`TOT_PRELUDE=... bootstrap-only`) until the failure persisted with
ZERO Stage D content present, proving the corruption predated the new
block rather than being caused by it.  Fixed by moving the orphaned
line back to `ioBindAssoc`'s own type and re-verifying `bootstrap-only`
exits 0.  Recorded here because it is exactly the failure mode the
plan's own ORACLE RULE guards against: a hidden truncation would have
been silently absorbed by conversion (or produced a confusing,
unrelated error far from its cause) if the diagnostic had not pointed
straight at a scope mismatch.

### Files touched

Edited: `lib/error.ml`, `lib/check.ml`, `surface/serror.ml`,
`surface/token.ml`, `surface/lexer.ml`, `surface/syntax.ml`,
`surface/parser.ml`, `surface/elab.ml`, `surface/run.ml`,
`surface/bootstrap.ml`, `surface/cache.ml`, `bin/tot.ml`,
`stdlib/prelude.tot`, `test/main.ml`, `test/surface.ml`,
`dev/gates.sh`, `SPEC.md`, `README.md`.

Not touched (no change needed this stage): `lib/term.ml` (per the
plan: `Auto` landed in Stage A), `lib/value.ml`, `lib/global.ml`,
`lib/eval.ml`, `lib/erase.ml`, `lib/eterm.ml`, `lib/interp.ml`,
`lib/pp.ml`, `lib/totality.ml` (`Totality.spine`/`Totality.mentions`
are reused, not modified).

New: `examples/guard-classes.tot`, `test/fixtures/m4d-classes.tot`,
`test/fixtures/m4d-dup-instance.tot`, `test/fixtures/m4d-serror-exit.tot`,
`test/fixtures/m4d-nomain.tot`.

### New `Error.t` variants

- `Inst_unresolved of string` -- no instance for the expected type;
  payload is the printed type.
- `Inst_bad_shape of { name : string;  reason : string }` -- an instance
  (or a resolution step) whose type does not fit the registration
  shape.
- `Inst_depth of string` -- instance resolution ran out of fuel;
  payload is the printed type being peeled.

### New `Serror.t` variant

- `Missing_main` -- `--require-main` was given and the script defines
  no `main`.  Message: "this file must define a driver main, and it
  does not".  Tag: `Missing_main`.

### Tests added

`test/main.ml` (kernel, labels `D1`-`D8`, +8, 71 -> 79): a hand-built
`Cls`/`Key` pair (mirroring `Nat`/`Opt`'s own hand-built style) drives
D1 (`Auto` resolves to exactly `Term.Global "inst$Cls$Key"`, string-
compared via `Pp.term`, no `Term.t` pattern match needed), D2 (a
non-class expected type), D3 (a class applied to a bound variable,
`Value.VNeutral (HVar 0, [])`), D4 (`Cls`/`Key` exist, no instance) --
all three `Inst_unresolved` -- D5 (two `define_instance` calls at the
same key, `Duplicate_global` containing `"inst$"`), D6 (`Cls (Wrap
Key)`, `Wrap` declared with one param via `declare_ind` alone since
only its TYPE matters for kind-checking, `Inst_bad_shape`), D7
(`build_instance` called directly with `fuel = 0`, `Inst_depth`), and
D8 (a fresh exhaustive `Term.t` walk, `d_contains_auto`, confirms
checker output for a successful resolution has no `Term.Auto` node).

`test/surface.ml` (labels `D9`-`D16`, +8, 89 -> 97), every string below
READ from the built binary via `dune exec bin/tot.exe -- check`, never
guessed: D9 (`class C1 (0 A : Type 0) := { m1 : A -> Bool }` pins the
exact `data`/`ctor`/`def` echo lines the expansion produces), D10 (the
same class plus an instance pins the `def inst$C1$Bool : (C1 Bool)`
echo line), D11 (`eval member String auto "sed" flagged` against a
freshly defined `flagged`, `true`), D12 (`inst EqD String` in place of
`auto`, same result), D13 (two `instance : EqD Bool := ..` items,
`Kernel.Duplicate_global`), D14 (a NEW `expect_cli_exit` helper drives
the real `bin/tot.exe` CLI twice on a one-line type error, `check zzz`:
bare exits 1, `--serror-exit 3` exits 3), D15 (a NEW
`case_require_main_rejects_mainless`: `check Type 0` under
`{require_main = true}` is `Missing_main`, the SAME script under the
default policy still runs with no exit code), D16 (`def partial f :
Nat := zero`, without `rec`, is still the pre-existing `Parse` error --
the `defkind` refactor is a compile-time property, so the regression
oracle is that the OLD parse error is unchanged, not a new one).

Gate markers added to `dev/gates.sh`: `PASS-M4D-AUTO` (gate-run on
m4d-classes.tot, exact `true`/`false` output), `PASS-M4D-COHERENCE`
(gate-check on m4d-dup-instance.tot, `Duplicate_global` containing
`inst$`), `PASS-M4D-SERROR-EXIT` (bin/tot.exe on m4d-serror-exit.tot,
bare exit 1 vs `--serror-exit 3` exit 3, same stdout both times),
`PASS-M4D-REQUIRE-MAIN` (bin/tot.exe on m4d-nomain.tot, bare exit 0 vs
`--require-main` exit nonzero with the `Missing_main` message),
`PASS-M4D-GUARD-CLASSES` (bin/tot.exe check AND run on
examples/guard-classes.tot, exact full multi-line `run` output pinned).

### `PASS-CACHE-NOEXEDIGEST`, read before editing per the plan's own
instruction, and REROUTED rather than merely preserved

The plan's D5.3 section says this gate "exercises the failure path
this change reroutes" and to read it before editing.  Pre-Stage-D, an
execute-only (chmod 111) copy of the binary made `Digest.file` raise
`Sys_error` (no READ permission on the file), disabling the cache for
the run.  `Unix.stat` needs no permission on the TARGET file at all,
only SEARCH permission on its parent directories (which the gate's own
scratch directory still grants), so under the new mechanism this exact
setup no longer fails: verified by hand (`env TOT_CACHE_DIR=...
tot-noread run ...`) before touching the gate script, giving exit 0,
empty stderr, and a real cache blob written, with a second
`TOT_CACHE_VERIFY=1` invocation printing `TOT-CACHE-VERIFY-OK`.  "The
failure path this change reroutes" reads, against the repo as it
stands, as "this scenario's outcome changes from failure to success",
not "preserve some failure here at all costs" -- so the gate now
asserts the NEW (success) behavior instead: exit 0, exactly one
`prelude-*.bin` blob after the cold run, EMPTY stderr, and
`TOT-CACHE-VERIFY-OK` on the warm run.  The marker name is unchanged
(`PASS-CACHE-NOEXEDIGEST`), it still exercises the SAME scratch-copy
scenario the M3 gate built, and it is not vacuous: it pins a
concretely different, verified-by-hand outcome from the pre-Stage-D
gate, which would have failed loudly (exit 0 but a nonempty stderr, or
zero blobs) had the stat-based fast path secretly still needed read
access.  Recorded here per the plan's own instruction to log this kind
of disagreement rather than silently act on it.

### PASS count, final

    dunecho build                OK build: 0 errors, 0 warnings
    dune exec test/main.exe      79 "PASS " lines (71 + 8), "M0 kernel: all tests green"
    dune exec test/surface.exe   97 "PASS " lines (89 + 8), "M1 surface: all tests green"
    zsh dev/gates.sh              GATE-EXIT=0
    rg -c '^PASS' gate.out        238
    rg -c '^FAIL' gate.out        (no matches, i.e.  0)

Decomposition: 217 Stage-C baseline + 8 new kernel cases (D1-D8) + 8 new
surface cases (D9-D16) + 5 new `dev/gates.sh` markers (`PASS-M4D-AUTO`,
`PASS-M4D-COHERENCE`, `PASS-M4D-SERROR-EXIT`, `PASS-M4D-REQUIRE-MAIN`,
`PASS-M4D-GUARD-CLASSES`) = 238.  No existing case was deleted,
weakened, or renamed;  every M3/Stage-A/B/C gate (including all six
`PASS-D-CACHE-*`/`PASS-CACHE-*` cache gates and every `PASS-D-GUARD-*`
guard gate) stayed green, `PASS-CACHE-NOEXEDIGEST` REROUTED per the
note above rather than deleted.

### Gate output tail (dev/gates.sh, full run, the new markers)

    PASS-M4D-AUTO
    PASS-M4D-COHERENCE
    PASS-M4D-SERROR-EXIT
    PASS-M4D-REQUIRE-MAIN
    PASS-M4D-GUARD-CLASSES

### SPEC.md

Section 2: seven dated `2026-09-02 (M4, Stage D)` entries appended (the
class resolution key and coherence rule;  scope fences;  `--serror-exit`;
`--require-main`;  the stat-identity cache fast path and its chmod-111
observable consequence;  `Syntax.defkind`;  confirmation that Stage A's
debts stay discharged).  Section 3: the "Surface items" paragraph
gained the `class`/`instance` grammar and a pointer to `auto`/`inst`.
Section 5: M4 marked DONE with its actual contents;  M5 restated (well-
founded recursion, holes, nested/mutual inductives, universe
polymorphism).  Section 6: four debts retired in place (the
stat-identity cache, the misspelled-main residual now has a `--require-
main` opt-in, the Serror/ask exit-code collision is now configurable,
the `(rec_, partial)` pair is now `Syntax.defkind`), and a new "Known
debts entering M5" block transcribes the plan's own closing section
verbatim in substance (the `Frozen` emptiness claim, the flat `$`-
mangled namespace, holes, Frozen-guard fixture maintenance, nested
inductives, the regex engine, JSON conformance, the check-budget flag,
the prim catalog trust boundary, `Div` provenance, and well-founded
recursion now unblocked).

### Concerns for later

- The `Frozen` emptiness claim (Stage C) is STILL unproven;  Stage D's
  class layer adds no new `Frozen` source (dictionaries are ordinary
  `w`-quantity constructor values, never erased-guard-driven), so this
  stage neither closes nor deepens that gap.
- `validate_instance_shape`'s dictionary-binder check requires the
  domain to be `Global c_j` applied to EXACTLY a `Var` pointing at an
  earlier type binder (never a more complex expression).  This matches
  the plan's own "positional parametric instances only" scope fence
  literally;  a future milestone that wants a dictionary binder over a
  COMPOUND type argument (e.g.  `EqD (List A)` as a superclass-style
  constraint rather than `EqD A`) needs a new rule here, not a
  workaround.
- `instance_key`/`peel_syntax_codomain`/`syntax_spine` in `surface/
  run.ml` walk UNELABORATED `Syntax.t`, deliberately separate from
  `Totality.spine`'s `Term.t` version;  they exist only so
  `Bootstrap.item_name` can name an `IInstance` item without
  elaborating it first (the same reason `item_name` never elaborates
  any other item either).  Keep them in sync BY EYE if `Syntax.t` ever
  grows a new application-shaped constructor;  there is no shared
  parametrized-over-the-AST-type helper today.

## Final

Full gate battery, one last time, run identically to every stage
before it:

    dunecho build -- --root /Users/oobi/Documents/tot
        OK build: 0 errors, 0 warnings
    dune exec --root /Users/oobi/Documents/tot test/main.exe
        79 "PASS " lines, "M0 kernel: all tests green"
    dune exec --root /Users/oobi/Documents/tot test/surface.exe
        97 "PASS " lines, "M1 surface: all tests green"
    zsh /Users/oobi/Documents/tot/dev/gates.sh
        GATE-EXIT=0
    rg -c '^PASS' gate.out
        238
    rg -c '^FAIL' gate.out
        (no matches, i.e.  0)

Final PASS count: **238**, against the milestone's 167 baseline and the
217 count Stage D started from.

Decomposition (stage by stage, each additive on the last, nothing ever
deleted or weakened):

    167  M3 baseline (53 kernel + 69 surface + 44 gates.sh + 1 prim-lint)
    +12  Stage A kernel (A1-A12)      -> kernel 65
    +11  Stage A surface (A13-A23)    -> surface 80
    + 6  Stage A gates.sh markers     -> 196
    + 4  Stage B kernel (B1-B4)       -> kernel 69
    + 7  Stage B surface (B5-B11)     -> surface 87
    + 4  Stage B gates.sh markers     -> 211
    + 2  Stage C kernel (C1, C3)      -> kernel 71
    + 2  Stage C surface (C4, C5)     -> surface 89
    + 2  Stage C gates.sh markers     -> 217
    + 8  Stage D kernel (D1-D8)       -> kernel 79
    + 8  Stage D surface (D9-D16)     -> surface 97
    + 5  Stage D gates.sh markers     -> 238
    ================================
    238  final: 79 kernel + 97 surface + 61 dev/gates.sh's own markers
         (44 M3 + 6 + 4 + 2 + 5 M4) + 1 prim-lint

Every M4 stage (A, B, C, D) ran its OWN gate battery green before the
next one started, per the plan's halt-on-red discipline;  no stage
absorbed another's red, and no stage's tests, fixtures or gate markers
were touched by a later stage except by strictly ADDING to them (Stage
D's own additions above, and the documented, verified-by-hand
`PASS-CACHE-NOEXEDIGEST` reroute, which changed what the gate ASSERTS,
not whether it runs or what scenario it covers).

Per the plan's own instruction: no `git add`, no `git commit`, no
`git stash`.  The working tree carries Stages A, B, C and D as
uncommitted edits on top of b01b3eb, gate-verified as above.
