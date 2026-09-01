# tot: design record

Working name: `tot` (total). Rename is a find/replace away.

## 1. Purpose

One language for everyday automation: PreToolUse hooks, gate scripts,
verdict CLIs, small tools. The house rules are the semantics:

- No exceptions. Errors are values (`Option`, `Result`, error variants).
- Total by default. Every hook terminates; the checker proves it.
- No loop keywords. Recursion and combinators only.
- Exhaustive matches. No catch-all arms.
- Partial operations (indexing, division) do not exist. Each one either
  returns an `Option` or demands a proof.
- A hook is a typed value indexed by its JSON schema and its permitted
  exit codes. A guard that typechecks cannot emit garbage.

## 2. Decision log

- 2026-08-31: goal triangle set: Lean-4-strength types, OCaml-speed
  checking on the ML fragment, OCaml-grade expressiveness. Uniform speed
  is impossible (conversion runs user code); pay-as-you-go is the bar.
- 2026-09-01: host language = OCaml (user decision).
- 2026-09-01: kernel-first (user decision). Small dependent kernel now;
  surface language on top; no retrofit.
- 2026-09-01: first dogfood target = a PreToolUse guard (user decision).
- 2026-09-01: weak definitional equality. Globals are opaque by default;
  evaluation unfolds only globals marked reducible; conversion never
  unfolds on its own. Predictable check times; more explicit proofs.
- 2026-09-01: quantities 0/omega (QTT fragment). Quantity-0 binders erase
  before evaluation. Full linearity (quantity 1) is deferred.
- 2026-09-01: predicative universe hierarchy, no cumulativity in v0.
  Revisit at M2 if annotation burden is too high.
- 2026-09-01: execution model = erase, then interpret in-process, with a
  content-addressed cache of elaborated modules. Native codegen is a
  later milestone.

## 3. Core calculus (M0)

Syntax (de Bruijn indices; binder names are display-only):

    t ::= x | Type l | (q x : t) -> t | fun x => t
        | t t | let x : t = t in t | (t : t) | g

Quantities: `0` (erased: types, proofs) and `w` (runtime). The checker
carries a mode. Inside types the mode is `0` and every variable is
usable. At mode `w`, use of a `0`-bound variable is an error. Argument
positions multiply: applying a `(0 x : A) -> B` keeps the argument
erased even at runtime.

Universes: `Type l : Type (l+1)`. Pi takes the max of the two levels.
No cumulativity, no universe polymorphism (yet).

Definitional equality: beta, let, eta for functions, and unfolding of
reducible globals during evaluation. Opaque globals are equal only to
themselves. Conversion is checked by NbE: evaluate, then compare values.

Totality: M0 has no recursion, so everything terminates trivially.
Structural recursion arrives with inductives (M2); well-founded
recursion with measures after that. `partial` will exist, quarantined
from the erased fragment.

## 4. Kernel modules

- `Level`, `Quantity`: newtyped universe levels and usage marks.
- `Term`: core syntax.
- `Value`: NbE semantic domain (closures, neutrals with spines).
- `Eval`: eval / apply / quote / conv. All total, all `Result`.
- `Global`: name -> {ty; def; reducible}. Extend only via `Check.define`.
- `Check`: bidirectional infer/check with quantity modes; `define` is
  the one public way to grow the global environment.
- `Error`: one variant, no exception anywhere in the kernel.
- `Pp`: printer for terms and errors.

## 5. Milestones

- M0 (this commit): kernel + tests. No parser.
- M1: surface syntax, bidirectional elaborator, erasure, interpreter.
  ML-fragment scripts run end to end.
- M2: inductive families, match elaboration, structural totality
  checker, core stdlib (Option, Result, List, String, Json).
- M3: IO ladder (Tot < Div < IO), process/JSON/regex stdlib, shebang
  runner, content-addressed elaboration cache. Port the first
  PreToolUse guard and run it for real.
- M4: propositional equality, rewriting, deterministic type classes,
  proof ergonomics. Then measure and decide the next tradeoff.

## 6. Known debts (deliberate)

- No `.mli` interfaces yet except `Level`; `Global.add` is public but
  documented as kernel-internal.
- No cumulativity: concrete types live one universe up from where
  church-encoded tests want them.
- Apache license text not vendored yet (README notes dual intent).
- Errors carry pre-rendered strings, not structured values. Fine at M0
  scale; revisit when the elaborator wants error recovery.
