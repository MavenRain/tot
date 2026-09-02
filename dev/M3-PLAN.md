# M3 build plan: the effect ladder, literals, stdlib breadth, real hooks

Authoritative spec for the M3 implementation agents. Read this WHOLE file
before touching code. The repo is /Users/oobi/Documents/tot (OCaml, dune).
Four sequential stages (A, B, C, D), one agent per stage, each stage green
on its own gate before the next one starts.

Design authority: /Users/oobi/Documents/tot-m3-design-verdict.md (M3-SYNTH,
the judged synthesis of the three M3 design proposals). This plan
transcribes that verdict into file-by-file work. Where this plan fills in a
detail the verdict left open, the paragraph says so and names the
alternative it rejected. Do NOT redesign anything else. If you believe a
verdict decision is wrong, record the argument in dev/M3-BUILD-LOG.md and
build it as written.

Background reading, in this order, only if a detail here is ambiguous:
1. /Users/oobi/Documents/tot-m3-design-verdict.md (sections 3.1 to 6)
2. /Users/oobi/Documents/tot/SPEC.md (M2 plus the M2 fix batch)
3. /Users/oobi/Documents/tot-m3-design-monadic.md (the winning proposal)
4. /Users/oobi/Documents/tot-m3-design-items.md and
   /Users/oobi/Documents/tot-m3-design-graded.md (the grafted-from
   proposals)

## Confirmed user decisions (2026-09-01, final, not reopenable)

1. **Effect model: monadic reified IO.** `Div` and `IO` are opaque
   zero-constructor type formers. `Prim` is a fourth `Global.entry` kind
   with no `def` field and no `reducible` field. Div prims fire inline. IO
   is reified as an action tree that only `run_io` walks. Hooks write
   `main : IO Verdict` with `let*` sugar and an explicit `liftIO` at every
   Div to IO step.
2. **Json: self-recursive `data Json` with its own cons cells** in the
   prelude. No builtin opaque Json. No nested inductives.
3. **Hook protocol: driver-rendered `Verdict`.** `allow` exits 0, `ask`
   exits 1, `deny` exits 2, and the driver renders the JSON envelope.
   `main : IO Unit` plus an explicit `exitWith` stays legal as a second
   accepted shape.

## Baseline you start from

M2 is committed (3807637). The M2 fix batch is present in the working tree
as STAGED, uncommitted edits. Do not revert them, do not commit them, and
do not stage anything of your own. The fix batch already changed these
things, so build on top of them:

- `Global.ind_entry.ctor_names` is `string list option`. `None` means
  declared but not yet defined. Eliminating such an inductive is
  `Error.Ind_incomplete`. A second `define_ind` is `Error.Ind_redefined`.
- A `def rec` whose body has no occurrence of its own name stores
  `rec_arg = None` and behaves as a plain def.
- `Eval.is_canonical` requires a FULLY applied constructor (kept arity read
  from the `Ctor` entry).
- `Eval.run_match` has an arity backstop.
- Check-position matches materialize the constant motive, so `motive` is
  always `Some` in checker output.
- `lib/interp.ml` has runtime guarded unfolding: `gentry` records carry
  `grec_arg` and `gctor_arity`, `VNeut` heads are `EHVar`/`EHGlobal`, and a
  rec global freezes until its principal argument is a fully applied
  constructor.
- `Interp.define` takes `~rec_arg`. `Interp.add_ctor` takes `~arity`.

Baseline shapes you will extend (verified 2026-09-01):

    lib/dune:      (library (name tot_kernel))
    surface/dune:  (library (name tot_surface) (libraries tot_kernel))
    bin/dune:      (executable (name tot) (libraries tot_kernel tot_surface))
    test/dune:     (tests (names main surface) (libraries tot_kernel tot_surface))

    Global.entry   = Def of def_entry | Ind of ind_entry | Ctor of ctor_entry
    Term.t         = Var | Univ | Pi | Lam | App | Let | Ann | Global | Match
    Value.t        = VUniv | VPi | VLam | VInd | VCtor | VNeutral
    Eterm.t        = EVar | ELam | EApp | ELet | EGlobal | EErased | EMatch
    Interp.v       = VClos | VCon | VNeut | VErased
    Interp.gentry  = { gval; grec_arg; gctor_arity }
    Token.kind     = LParen RParen Colon ColonEq Arrow DArrow KType KFun KLet
                     KIn KDef KReducible KEval KCheck KData KMatch KWith KAs
                     KReturn KRec KEnd Pipe Ident Nat Eof
    Run.state      = { globals; eglobals; lines }
    Run.script     : exec:bool -> string -> (string list, Serror.t) result
    test/main.ml   34 cases, prints "M0 kernel: all tests green"
    test/surface.ml 35 cases, prints "M1 surface: all tests green"

Neither `unix` nor `str` is linked anywhere today.

## 0. Ground rules (house style, enforced by hooks)

- NO exceptions anywhere: no raise/failwith/assert. Every failure is a
  Result value. The two documented host-boundary exceptions this milestone
  adds are named explicitly in Stage B (`Effect.dispatch`) and Stage D
  (`Cache.load`); nowhere else.
- NO match on Option/Result where a combinator does the job
  (Option.fold/map/to_result, Result.bind, let*). A PreToolUse hook
  DENIES edits that add such matches.
- NO loop keywords (for/while); recursion + List.fold/map/filteri only.
- Exhaustive matches, NO catch-all `_ ->` arms on variant types you can
  enumerate. Use `match () with | () when ...` ladders, not if/else-if.
  This milestone adds constructors to `Value.t`, `Eterm.t`, `Interp.v` and
  `Global.entry`; the compiler will point at every site, and every site
  gets a spelled-out arm.
- Comments: match existing density; doc comments on new top-level items.
- No em-dashes in any text you write. In prose, write "locate", never the
  f-word verb that a hook pattern-matches.
- Shell: `rg` not grep, `sd` not sed. Append a trailing ` # [skip-disk]`
  comment to EVERY Bash command (disk-floor interlock bypass; bare, it
  gets zsh-globbed).
- Never `cd`: use `dune build --root /Users/oobi/Documents/tot`,
  `git -C ...`, absolute paths. Your cwd RESETS between Bash calls.
- Do NOT run `git add` or `git commit`. Leave working-tree edits only.
- `dev/gates.sh` must not use `set -u` (a chpwd hook breaks under it).

Gate command battery (all must be green before you report):

    dune build --root /Users/oobi/Documents/tot 2>&1 | tail -20 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -5 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -5 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot 2>&1 | tail -3 # [skip-disk]

Plus your own stage gate (Gate A to Gate D below), which is mechanical and
belongs in `dev/gates.sh` so later stages keep running it.

RUN THE BATTERY BEFORE YOU EDIT ANYTHING and record the tails in your
report. A red at baseline belongs to the previous stage, not to yours, and
you must say so instead of absorbing it.

`dev/gates.sh` line 4 calls `dunecho`, a user shell wrapper that is not
defined in this repo and may not resolve in a non-interactive shell. Keep
the line, and also run the four explicit commands above.

Append a stage report to /Users/oobi/Documents/tot/dev/M3-BUILD-LOG.md when
your stage is green: what changed, files touched, new `Error.t` variants,
new prims with their ladder classification, test names added, and the gate
output tails.

Every feature ships WITH its regression test. ORACLE RULE: every negative
test must be shown to REJECT for the intended reason (print the error tag
and the message), never to pass vacuously. Every positive test must pin an
exact value, an exact line, or an exact exit code, never just "no error".

Marshal-format checklist (Stage D depends on it, every stage maintains it):
any change to `Term.t`, `Value.t`, `Eterm.t`, `Global.entry`, `Interp.v` or
`Prim.t` bumps the cache format version constant. Keep a comment naming
that constant beside each of those type definitions.

`lib/` imports no `Unix` and no `Sys`. Stage C adds `str` to `lib/dune` for
the regex prims only, with the justification written in `lib/prim.ml`.

---

## STAGE A: literals, builtin base types, the `Prim` entry kind

Goal: `Term.Lit` end to end (parse, check, erase, execute, quote, print),
`String` and `Int` as builtin type formers, and `Prim` as a fourth
`Global.entry` kind that conversion can never step into. The catalog starts
with the string and int prims only. No effects exist yet.

Files: `lib/literal.ml` (new), `lib/prim.ml` (new), `lib/term.ml`,
`lib/value.ml`, `lib/eval.ml`, `lib/global.ml`, `lib/check.ml`,
`lib/erase.ml`, `lib/eterm.ml`, `lib/interp.ml`, `lib/pp.ml`,
`lib/error.ml`, `surface/token.ml`, `surface/lexer.ml`,
`surface/parser.ml`, `surface/elab.ml`, `surface/bootstrap.ml` (new),
`surface/run.ml`, `test/main.ml`, `test/surface.ml`, `dev/gates.sh`.

### A1. lib/literal.ml (new)

    type t = LString of string | LInt of int
    val equal : t -> t -> bool

No dependency on any other kernel module. `equal` is structural and total.

### A2. lib/prim.ml (new)

A closed enum, no OCaml closures inside, so `Global.t` and
`Interp.globals` stay marshalable (decision 3 of verdict 3.10).

    type ladder = Tot | Div | Io
    type t =
      | String_concat | String_length | String_eq | String_contains
      | Int_add | Int_sub | Int_eq | Int_to_string

    val name : t -> string
    val arity : t -> int          (** KEPT (quantity-w) arguments only *)
    val classification : t -> ladder
    val justification : t -> string  (** one line, why this ladder rung *)
    val catalog : t list             (** every constructor, declaration order *)
    val of_name : string -> t option

Names and arities for Stage A (arity counts kept args, so the erased type
arguments never count; decision 4):

    stringConcat   2  Tot  "OCaml string concatenation is total"
    stringLength   1  Tot  "byte length of a finite string is total"
    stringEq       2  Tot  "byte equality is total"
    stringContains 2  Tot  "substring scan is O(n*m) and total"
    intAdd         2  Tot  "OCaml int addition wraps, never diverges"
    intSub         2  Tot  "OCaml int subtraction wraps, never diverges"
    intEq          2  Tot  "int equality is total"
    intToString    1  Tot  "decimal rendering of an int is total"

Later stages EXTEND this enum. Every extension extends `name`, `arity`,
`classification`, `justification` and `catalog` together; the exhaustive
matches make the compiler enforce the first four, and a Stage A test
enforces `catalog`.

### A3. lib/term.ml

One new leaf, nothing else:

    | Lit of Literal.t

`Pi`, `Lam` and `App` keep their M2 arity (decision 1). No existing
construction site changes, in `lib/`, in `surface/`, or in `test/`.

### A4. lib/value.ml

One new canonical value:

    | VLit of Literal.t   (** canonical, like VCtor *)

`head` and `frame` are unchanged. A `Prim` global reuses `HGlobal`.

### A5. lib/eval.ml

- `eval`: `| Term.Lit l -> Ok (Value.VLit l)`.
- `eval`'s `Term.Global` arm (currently lines 65 to 79) gains
  `| Global.Prim _ -> Ok (Value.VNeutral (Value.HGlobal name, []))`, the
  same shape the existing opaque `Def` case already returns. This one arm
  is the entire kernel-level argument that checking cannot perform an
  effect: a `Prim` entry has no `def` to unfold to and no `reducible` flag
  to set.
- `apply`: `VLit` in function position is `Error (Not_a_function ...)`,
  spelled out beside the existing `VUniv`/`VPi` arms.
- `run_match`: a `VLit` scrutinee is `Error (Not_inductive ...)`, a total
  backstop (a checked program cannot reach it, because `String` and `Int`
  are not eliminable; see A16).
- `quote`: `| Value.VLit l -> Ok (Term.Lit l)`.
- `conv`: `VLit a, VLit b -> Ok (Literal.equal a b)`, plus one explicit
  `Ok false` arm for `VLit` against each of `VUniv`, `VPi`, `VLam`,
  `VInd`, `VCtor` and `VNeutral`, in BOTH directions, matching the
  existing spelled-out style at lines 257 to 285. No catch-all.
- `is_canonical` is unchanged: a `VLit` is NOT canonical for guarded
  unfolding. Structural recursion is over constructors, and there is no
  structurally smaller literal. Say this in a comment.

### A6. lib/global.ml

    | Prim of prim_entry

    and prim_entry = {
      prim_ty : Term.t;  (** closed *)
      prim : Prim.t;     (** which native operation *)
    }

No `def` field and no `reducible` field exists on it (decision 2).
`entry_ty` gains `| Prim p -> p.prim_ty`. `def_of`, `ind_of` and `ctor_of`
list `Prim` explicitly and return `None`. Add `prim_of : entry ->
prim_entry option` and `find_prim : string -> t -> prim_entry option`
beside the existing accessors.

### A7. lib/check.ml

- `infer` gains one arm:

      | Term.Lit (Literal.LString _) -> ... type is the value of Global "String"
      | Term.Lit (Literal.LInt _)    -> ... type is the value of Global "Int"

  Obtain the type by `Eval.eval globals [] (Term.Global "String")`, so an
  environment without the bootstrap reports `Unbound_global "String"`
  honestly. Output term is the input `Term.Lit` unchanged.
- New public entry point, the only way to grow the environment with a prim:

      val define_prim : Global.t -> name:string -> ty:Term.t -> prim:Prim.t
                     -> (Global.t, Error.t) result

  It rejects a duplicate name (`Duplicate_global`, same guard as `define`),
  runs `infer_univ` on `ty` to validate and stamp it, and stores
  `Prim { prim_ty = stamped; prim }`. It does NOT check that `Prim.arity
  prim` agrees with the type; A17 test 8 does that at the catalog level.
- The `Term.Global` arm needs no change: it already reads
  `Global.entry_ty`.

### A8. lib/eterm.ml and lib/erase.ml

    Eterm.t gains  | ELit of Literal.t
    Erase.term     | Term.Lit l -> Ok (Eterm.ELit l)

A prim global erases as an ordinary `EGlobal name`. Erasure stays
structural and consults no types.

### A9. lib/interp.ml

    type v =
      | VClos ... | VCon ... | VNeut ... | VErased
      | VLit of Literal.t          (* NEW *)
      | VPrim of Prim.t * v list   (* NEW: accumulates args toward arity *)

- `exec`: `| Eterm.ELit l -> Ok (VLit l)`.
- `apply`: new arm for `VPrim (p, args)`. Append the argument. When
  `List.length args + 1 < Prim.arity p`, return `VPrim (p, args @ [a])`.
  When it equals the arity, FIRE. When it exceeds the arity, return
  `Error (Error.Prim_arity { prim = Prim.name p; expected = Prim.arity p;
  found = List.length args + 1 })`; that state is unreachable because
  firing happens exactly at the arity, so it is a total backstop.
- Firing in Stage A: all eight prims are `Tot`, so they compute inline and
  return an ordinary value. Argument shapes are checked: a
  `stringConcat` whose argument is not `VLit (LString _)` is
  `Error (Mismatch { expected = "String"; actual = "..." })`, a total
  backstop that a well-typed program cannot reach. Results:
  `stringConcat`, `intToString` return `VLit (LString ...)`; `intAdd`,
  `intSub` return `VLit (LInt ...)`; `stringLength` returns
  `VLit (LInt ...)`; `stringEq`, `stringContains`, `intEq` return
  `VCon ("true", [])` or `VCon ("false", [])` by name. Building `Bool` by
  constructor NAME is deliberate: the prelude owns `Bool`, and A16's
  `required_ctors` check proves the name resolves before any script runs.
- `apply` on `VLit`: `Error (Not_a_function ...)`.
- `run_match` on a `VLit` or `VPrim` scrutinee: `Error (Not_inductive ...)`,
  total backstops beside the existing `VClos`/`VErased` arms.
- `quote`: `VLit l -> Ok (Eterm.ELit l)`; `VPrim (p, args)` rebuilds the
  spine, `EApp` folded over `EGlobal (Prim.name p)` in argument order
  (decision 8).
- `is_canonical`: `VLit` and `VPrim` are not canonical.
- New seeding helper beside `add_ctor` and `add_erased`:

      val add_prim : globals -> name:string -> prim:Prim.t -> (globals, Error.t) result

  It stores `{ gval; grec_arg = None; gctor_arity = None }` where `gval` is
  `VPrim (p, [])` for a prim of arity 1 or more. TRAP: a prim of arity 0
  can never fire on application, so `add_prim` must fire it at seed time
  and store the RESULT. No Stage A prim has arity 0; Stage B adds
  `readStdin` and `argv`, which do, so write `add_prim` to handle arity 0
  now and add the Stage B test that covers it.

### A10. lib/error.ml

New variants (house shape: constructor name is the tag):

    | Prim_arity of { prim : string; expected : int; found : int }
    | Not_quotable of string

Extend `to_string` and `tag` for both. `Not_quotable` lands in Stage A so
the `quote` signature is stable; Stage B is its first real user
(`VIOAction`).

### A11. lib/pp.ml

- `term`: `Lit (LString s)` prints the source form, double-quoted, with
  `\\`, `\"`, `\n` and `\t` escaped. `Lit (LInt n)` prints the decimal.
- `eterm`: the same for `ELit`.
- Factor the escaper into one function; Stage C's `jsonSerialize` and
  Stage D's verdict rendering reuse it, so put it where both can reach it
  (`lib/pp.ml` is reachable from `surface/`).

### A12. surface/token.ml

One new kind: `| Str of string`.

Integer literals reuse the existing `Nat of int` token, which the lexer
already produces for a digit run and which `Type L` and `data ... : Type L`
already consume in their own positions. There is no ambiguity: the level
positions consume their `Nat` before the atom parser ever sees it. This
also keeps the M1 numeric-literal overflow cap (and its surface test)
working unchanged, at the price that a huge int literal is a Lex error, not
an Int overflow. Record that in the Stage D SPEC entry.

### A13. surface/lexer.ml

Add a string-literal rule before the identifier scanner: on `'"'`, scan to
the closing `'"'`, honoring `\\`, `\"`, `\n`, `\t` escapes; an unterminated
literal or an unknown escape is `Serror.Lex { loc; msg = ... }`. Keep the
existing `--` comment rule untouched. No other lexer change in Stage A.

### A14. surface/parser.ml

- Atom position gains `| Token.Str s -> Syntax.SStr (loc, s)` and
  `| Token.Nat n -> Syntax.SInt (loc, n)`.
- Expose the existing internal term parser as a public entry point:

      val term_only : Token.t list -> (Syntax.t, Serror.t) result

  It parses one term and requires `Eof`. `surface/bootstrap.ml` uses it to
  elaborate prim types from source text instead of hand-building Pi
  telescopes in OCaml. `parse` is unchanged.

### A15. surface/syntax.ml and surface/elab.ml

    Syntax.t gains  | SStr of Loc.t * string
                    | SInt of Loc.t * int
    loc_of          two new arms
    Elab.term       SStr -> Term.Lit (LString s)
                    SInt -> Term.Lit (LInt n)

### A16. surface/bootstrap.ml (new)

This module owns the builtin environment. It lives in `surface/` because it
elaborates types from source text, and because `lib/`'s new-file budget in
the verdict is exactly `literal.ml` plus `prim.ml`.

    val builtin_types : string list   (** ["String"; "Int"] in Stage A *)
    val phase1 : unit -> (Run.state, Serror.t) result
    val phase2 : Run.state -> (Run.state, Serror.t) result
    val required_ctors : string list  (** ctor names the prims build by name *)
    val state : unit -> (Run.state, Serror.t) result

TWO PHASES, because a prim type may mention a prelude data type and those
types do not exist until the prelude has been folded. This split is a
plan-level fill-in; the verdict states the seed-then-fold order in 3.7 and
the post-fold constructor check in 3.5, and the split is what makes both
true at once.

`phase1`:
1. Start from `Run.initial`.
2. For each builtin type former, call `Check.declare_ind ~name ~params:[]
   ~level:(Level.of_int 0)` and `Interp.add_erased ~name`. DO NOT call
   `define_ind`.
3. For each phase-1 prim, lex and `Parser.term_only` its type source, run
   `Elab.term globals []`, then `Check.define_prim` and `Interp.add_prim`.

`phase2` does step 3 for the phase-2 prims, then verifies that every name
in `required_ctors` resolves in BOTH `Global.t` and `Interp.globals`,
reporting `Error.Missing_prelude_ctor name` otherwise. In Stage A
`required_ctors` is `["true"; "false"]`.

`state ()` runs `phase1`, folds `stdlib/prelude.tot` through `Run.item`,
resets `lines` to `[]`, then runs `phase2`. Tests use it from Stage A on.
`bin/tot.ml` starts using it in Stage D.

Phase-1 prim types (they mention only builtins):

    stringConcat   "String -> String -> String"
    stringLength   "String -> Int"
    intAdd         "Int -> Int -> Int"
    intSub         "Int -> Int -> Int"
    intToString    "Int -> String"

Phase-2 prim types (they mention `Bool`, which the prelude owns):

    stringEq       "String -> String -> Bool"
    stringContains "String -> String -> Bool"
    intEq          "Int -> Int -> Bool"

WHY `declare_ind` WITHOUT `define_ind`: an inductive whose `ctor_names` is
`None` cannot be eliminated (`Error.Ind_incomplete`, from the M2 fix
batch). That is exactly the property the builtin type formers need.
`define_ind ~ctors:[]` would instead store `Some []`, and then
`match (s : String) with end` would be vacuously exhaustive and would
inhabit any type, with `eval` hitting its `Not_inductive` backstop on a
CHECKED program. That is the same class of hole the M2 fix batch closed for
provisional inductives. This plan therefore reads verdict 3.2's
"zero-constructor `Ind` entries" as declared-only entries. The wording of
`Ind_incomplete` is slightly off for a builtin, which is acceptable; Stage
D's SPEC entry records the reading.

### A17. surface/run.ml

`script` gains an optional starting state so tests and later stages can
begin from a seeded environment:

    val script : ?st:state -> exec:bool -> string -> (string list, Serror.t) result

Default is `initial`, so every existing caller and every existing surface
test is unchanged. `initial` itself stays `Global.empty`.

### A18. Stage A tests

test/main.ml (kernel, append to `cases`; keep all 34):
1. `Term.Lit (LString "hi")` infers `String` against a hand-seeded globals
   holding a declared-only `String` Ind. Pin the printed type.
2. The same literal infers `Unbound_global` when `String` is absent; print
   the error.
3. `conv` on `VLit (LString "a")` against `VLit (LString "a")` is true;
   against `VLit (LString "b")` is false; against `VLit (LInt 1)` is false;
   against a `VCtor` is false.
4. Opacity: with a `Prim` entry `p : String -> String -> String`, the terms
   `p "a" "b"` and `p "a" "c"` are NOT convertible, `p "a" "b"` and itself
   ARE convertible, and `p "a" "b"` and `q "a" "b"` (a second prim of equal
   arity) are NOT convertible. This is the test that proves a prim never
   reduces during conversion.
5. `Eval.eval` of a `Match` whose scrutinee is a `VLit` returns
   `Not_inductive`; print the tag (total backstop test, built by hand,
   bypassing `Check` on purpose).
6. Round trip: check a literal, `Erase.closed` it, `Interp.exec` it,
   `Interp.quote` it, `Pp.eterm` it, and pin the printed source form,
   including one escaped quote and one newline escape.
7. `Check.define_prim` rejects a duplicate name; print the tag.
8. Catalog integrity: `List.map Prim.name Prim.catalog` has no duplicates,
   `Prim.of_name (Prim.name p) = Some p` for every `p` in `Prim.catalog`,
   and every `Prim.justification p` is non-empty.

test/surface.ml (append to `cases`; keep all 35):
9. `eval` of `stringConcat "a" "b"` under a bootstrapped state prints
   `"ab"`. Use `Run.script ~st:(Bootstrap.state ()) ~exec:true`.
10. `eval` of `intAdd 2 3` prints `5`.
11. `check` mode on the same script prints `eval : String` and
    `eval : Int`.
12. `eval` of `stringConcat "a"` (partial application) prints the frozen
    spine, pinning `Interp.quote` on `VPrim`.
13. Negative: `def x : String := 3` is a `Kernel.Mismatch`; print it.
14. Negative: `match s with end` on a `String` scrutinee is
    `Kernel.Ind_incomplete`; print it. This is the A16 hole test.
15. The M1 numeric cap test still passes unchanged.

### Gate A

    (i)   The kernel and surface suites stay green with NO edits to any
          existing test term (34 + 35 at baseline, plus your additions).
    (ii)  A literal round-trips parse, check, erase, exec, quote (test 6).
    (iii) Two distinct prim spines of equal arity are not convertible
          unless syntactically identical (test 4).
    (iv)  `stringConcat` and `intAdd` compute correctly under `tot run`
          (tests 9, 10).

Add a `PASS-A-LITERALS` marker to `dev/gates.sh` covering (iv) through a
small script file under `examples/`.

---

## STAGE B: the ladder end to end, minimally

Goal: `Div` and `IO` exist, the five ladder prims and four IO prims exist,
`Interp` reifies IO as an inert action tree, `surface/effect.ml` is the one
place that performs an effect, and `main : IO Unit` runs with a real OS
exit code. The load-bearing property is hard constraint 1: `tot check` on a
script whose `main` writes a file performs NO I/O.

Files: `lib/prim.ml`, `lib/interp.ml`, `lib/error.ml`, `lib/check.ml`,
`surface/bootstrap.ml`, `surface/effect.ml` (new), `surface/run.ml`,
`surface/dune`, `bin/tot.ml`, `stdlib/prelude.tot`, `test/main.ml`,
`test/surface.ml`, `dev/gates.sh`.

### B1. The ladder, exactly (verdict 3.2)

Bootstrapped as declared-only `Ind` entries, joining `String` and `Int`:
`Div` and `IO`. They are non-eliminable for the A16 reason, and that is
also what makes `bindIO` and `bindDiv` the unique elimination forms at zero
extra rule cost.

    Div     : (0 A : Type 0) -> Type 0
    IO      : (0 A : Type 0) -> Type 0
    pureDiv : (0 A : Type 0) -> A -> Div A
    bindDiv : (0 A : Type 0) -> (0 B : Type 0) -> Div A -> (A -> Div B) -> Div B
    pureIO  : (0 A : Type 0) -> A -> IO A
    bindIO  : (0 A : Type 0) -> (0 B : Type 0) -> IO A -> (A -> IO B) -> IO B
    liftIO  : (0 A : Type 0) -> Div A -> IO A

`Div` and `IO` are declared with `params = []` and `level = 0`, and their
`(0 A : Type 0) -> Type 0` shape comes from the declared arity, so declare
them with one quantity-0 param in the telescope and no constructors.

There is NO `liftDiv` and NO `runDiv` (decision 6). `Div` is absorbing: any
def that touches a Div prim has a Div-headed type. That fact carries the
deferred rule in B6.

Kept arities (the erased type arguments never count):

    pureDiv 1   bindDiv 2   pureIO 1   bindIO 2   liftIO 1

Note the correction: the monadic proposal's arity table listed `pureIO` as
2. That contradicts verdict decision 4, which counts kept arguments only.
The declared type is authoritative. Add the B9 test that pins every prim's
`Prim.arity` against the kept-argument count of its declared type, and make
the bootstrap fail with `Prim_arity` when they disagree.

IO prims for Stage B:

    readStdin : IO String                 arity 0  Io
    printLine : String -> IO Unit         arity 1  Io
    exitWith  : Int -> IO Unit            arity 1  Io
    getEnv    : String -> IO (Option String)  arity 1  Io

Their types mention `Unit` and `Option`, which the prelude owns, so they
belong to the phase-2 table (B5).

### B2. lib/prim.ml

Extend the enum with `Pure_div | Bind_div | Pure_io | Bind_io | Lift_io |
Read_stdin | Print_line | Exit_with | Get_env`, plus their names, arities,
classifications and one-line justifications. Ladder classification:
`pureDiv`/`bindDiv` are `Div`; `pureIO`/`bindIO`/`liftIO` and the four OS
prims are `Io`. Justification lines say what the operation observes, for
example `readStdin` "consumes the process stdin, an observable effect that
must not run at definition time".

### B3. lib/interp.ml

    type v = ... | VIOAction of io_action     (* NEW: inert, first class *)

    and io_action =
      | IOPure of v
      | IOBind of v * v              (** inner action value, continuation *)
      | IONative of Prim.t * v list  (** fully applied effect prim, undischarged *)

Firing rules in `apply`, the crux of the design:

- Div family and pure prims fire inline and return an ordinary value:
  `pureDiv x = x`; `bindDiv m k = apply eglobals k m`. A `Div` value has
  already computed by the time it is an argument, under call by value, so
  `Div` is a marker at the type level and costs nothing at runtime.
- IO family and effect prims never perform an OCaml effect inside `apply`:
  `pureIO x = VIOAction (IOPure x)`;
  `bindIO m k = VIOAction (IOBind (m, k))`;
  `liftIO dv = VIOAction (IOPure dv)`;
  `readStdin`, `printLine`, `exitWith`, `getEnv` return
  `VIOAction (IONative (p, args))`.
- `quote` on `VIOAction` returns
  `Error (Not_quotable "io action")` (decision 8). An `eval` item over an
  IO expression therefore reports that error rather than printing a
  half-value; B9 test 6 pins it.
- `apply` on `VIOAction`: `Not_a_function`. `run_match` on `VIOAction`:
  `Not_inductive`. Both total backstops.
- `add_prim` fires arity-0 prims at seed time, so `readStdin`'s stored
  `gval` is already `VIOAction (IONative (Read_stdin, []))`. Building that
  value performs nothing, which is the whole point.

### B4. lib/check.ml and lib/error.ml

- `Error.t` gains `| Effect_def_reducible of string` and
  `| Missing_prelude_ctor of string`, with `to_string` and `tag` arms.
- `Check.define` refuses `reducible` on a def whose type head is `Div` or
  `IO` (decision 9). Implement as: evaluate the stamped type, peel nothing,
  test for `Value.VInd ("Div", _)` or `Value.VInd ("IO", _)` at the head.
  On a hit with `reducible = true`, return
  `Error (Effect_def_reducible name)`. A def of type `String -> IO Unit`
  has head `VPi`, so it is unaffected; that is intended, because building
  an action is inert.

### B5. surface/bootstrap.ml

Extend the A16 module, keeping its two-phase shape.

- `builtin_types` gains `"Div"` and `"IO"`, declared with ONE quantity-0
  param in the telescope and no constructors, so their stored type is
  `(0 A : Type 0) -> Type 0` and they stay non-eliminable.
- Phase 1 gains the five ladder prims, whose types mention only builtins.
- Phase 2 gains `readStdin`, `printLine`, `exitWith` and `getEnv`, whose
  types mention `Unit` and `Option`.
- `required_ctors` grows to `["true"; "false"; "unit"; "none"; "some"]`.
  Stage C extends it again.

`state ()` is unchanged in shape: phase1, fold the prelude, reset `lines`,
phase2. `bin/tot.ml` starts using it in Stage D.

`stdlib/prelude.tot` gains one line in Stage B:

    data Unit : Type 0 := | unit : Unit

### B6. surface/run.ml

Three changes.

**Deferred definition-time execution (verdict 3.7).** `Run.item`'s `IDef`
case calls `Interp.define` today for every def, under `tot check` as well
as `tot run`. Change it to DEFER when the def's stored type head is `Div`
or `IO`: evaluate the entry's stamped `ty` with `Eval.eval globals []` and
test for `VInd ("Div", _)` or `VInd ("IO", _)`. On a hit, record the closed
erased term without executing it, and force it only when something
executes it. Keys on the type head, not on a new attribute (decision 11).
Implement the deferral inside `Interp` as a lazy `gentry` variant, or in
`Run` as a table of unforced defs; pick ONE and document it in the log. For
`IO` this also gives the correct re-run-per-reference semantics; for `Div`
it removes the one path by which `tot check` could run an unbounded host
computation.

**The `main` epilogue.** After folding the items, `Run.script` looks up a
global literally named `main`. Compare its stored type with the existing
conversion machinery against `IO Unit`. In `check` mode, print
`main : IO Unit` and NEVER call `run_io`. In `run` mode, take the
already-built action value from `eglobals`, require `VIOAction`, and call
`Effect.run_io` exactly once. Stage C extends the epilogue with the
`IO Verdict` shape, which is tried FIRST.

**Signature.** `script` returns
`(string list * int option, Serror.t) result` (verdict 3.7). Keep the
`?st` parameter from A17.

### B7. surface/effect.ml (new)

The only place in the whole tree that calls `read_line`, `open_in`,
`Unix.create_process`, `Sys.getenv_opt` or the OS. Add `unix` to
`surface/dune`'s libraries.

    type outcome = Done of Interp.v | Exited of int

    val run_io : Interp.globals -> Interp.io_action -> (outcome, Error.t) result
    val dispatch : Interp.globals -> Prim.t -> Interp.v list -> (outcome, Error.t) result

    let rec run_io eglobals action =
      match action with
      | Interp.IOPure v -> Ok (Done v)
      | Interp.IOBind (m, k) ->
          let* mv = require_action m in
          let* inner = run_io eglobals mv in
          (match inner with
           | Exited c -> Ok (Exited c)     (* short circuit: k never runs *)
           | Done rv ->
               let* kv = Interp.apply eglobals k rv in
               let* kv_action = require_action kv in
               run_io eglobals kv_action)
      | Interp.IONative (prim, args) -> dispatch eglobals prim args

`exitWith n` dispatches to `Ok (Exited n)`. It does NOT call `Stdlib.exit`.
This is a plan-level refinement of verdict 3.3, which lists `exit` among
`dispatch`'s calls: verdict 3.7 already gives `Run.script` an
`int option` return and gives `bin/tot.ml` the single exit call, and
threading the code keeps `run_io` testable in process. The rejected
alternative is calling `Stdlib.exit` inside `dispatch`, which would make
every exit-code test a subprocess test.

`dispatch` cases for Stage B: `Read_stdin` reads all of stdin;
`Print_line` prints a line and returns `Done (VCon ("unit", []))`;
`Get_env` returns `Done (VCon ("some", [VLit (LString v)]))` or
`Done (VCon ("none", []))`; `Exit_with` returns `Exited n`.

ONE documented `try ... with _ -> ...` fence per raw OS call converts host
failures into tot-level values. This is the same host-boundary posture the
SPEC already records for the CLI file-open race. It never crosses into
`Check`, `Eval`, `Erase` or `Totality`.

### B8. bin/tot.ml

`run_file` becomes `Option.value exit_code ~default:0` on success instead
of a fixed `0`. The two `Stdlib.exit` calls stay exactly where they are.

### B9. Stage B tests

test/main.ml:
1. Arity agreement: for every `p` in `Prim.catalog`, `Prim.arity p` equals
   the number of quantity-`w` binders in its declared type (parse the type
   from the bootstrap table and count). Print the offender on failure.
2. `Check.define ~reducible:true` on a def of type `Div String` returns
   `Effect_def_reducible`; print it. The same def with
   `reducible = false` succeeds. A def of type `String -> IO Unit` with
   `reducible = true` succeeds (the head is `VPi`).
3. `Interp.quote` on a `VIOAction` returns `Not_quotable`; print it.
4. `add_prim` on `readStdin` stores a `VIOAction`, not a `VPrim`
   (the arity-0 trap).

test/surface.ml:
5. `eval (bindIO String Unit readStdin (fun s => printLine s))` in CHECK
   mode prints the type and executes nothing.
6. `eval` of an IO expression in RUN mode reports `Kernel.Not_quotable`;
   print it. Sequencing goes through `main`, not through `eval`.
7. A `def` whose type is `Div String` and whose body applies a prim is
   accepted, and `tot check` on the script does not compute it (pair with
   gate item iii).

dev/gates.sh (process level, because these are OS-observed):
8. Gate B item (i): a script whose `main` chains three `bindIO` steps over
   a stdin fixture exits with the asserted code. Feed the fixture with a
   here-doc redirect, capture `$?`, compare exactly.
9. Gate B item (ii), the constraint-1 test: a script whose `main` writes a
   sentinel file passes `tot check` and the sentinel does NOT appear;
   `tot run` then creates it. Remove the sentinel first, assert absence
   after check, assert presence after run.
10. Gate B item (iii): a top-level `def` of Div-headed type built from a
    deliberately expensive prim (for example a long `stringConcat` fold)
    leaves `tot check` fast. Assert a wall-clock bound with a coarse
    threshold, and say in a comment that the assertion is about the
    deferred rule, not about performance tuning.

### Gate B

    (i)   A script chaining three bindIO steps over a stdin fixture exits
          with the asserted OS-observed code.
    (ii)  Constraint 1: `tot check` on a sentinel-writing `main` creates no
          sentinel; `tot run` creates it.
    (iii) A Div-headed def built from an expensive prim leaves `tot check`
          fast, proving the deferred rule.
    (iv)  The M2 guarded-unfolding conversion tests are unchanged and
          green.

Markers: `PASS-B-EXITCODE`, `PASS-B-NOEFFECT`, `PASS-B-DEFERRED`.

---

## STAGE C: stdlib breadth and surface sugar

Goal: the full prim catalog, `data Json` with its accessors, process and
regex, the `let*` family with the bounded hole pass, and the `partial`
keyword end to end.

Files: `lib/prim.ml`, `lib/interp.ml`, `lib/check.ml`, `lib/global.ml`,
`lib/error.ml`, `lib/dune`, `surface/token.ml`, `surface/lexer.ml`,
`surface/syntax.ml`, `surface/parser.ml`, `surface/elab.ml`,
`surface/bootstrap.ml`, `surface/effect.ml`, `surface/run.ml`,
`stdlib/prelude.tot`, `bin/tot.ml`, `test/main.ml`, `test/surface.ml`,
`dev/gates.sh`, `dev/prim-lint.sh` (new).

### C1. The rest of the catalog

    stringSlice  : String -> Int -> Int -> Option String   3  Tot
    stringSplit  : String -> String -> List String         2  Tot
    stringToInt  : String -> Option Int                    1  Tot
    intCompare   : Int -> Int -> Ordering                  2  Tot
    readFile     : String -> IO (Result String String)     1  Io
    writeFile    : String -> String -> IO (Result Unit String)  2  Io
    argv         : IO (List String)                        0  Io
    procRun      : String -> List String -> IO ProcessResult    2  Io
    jsonParse    : String -> Div (Option Json)             1  Div
    jsonSerialize: Json -> String                          1  Tot
    regexTest    : String -> String -> Div Bool            2  Div
    regexMatch   : String -> String -> Div (Option (List String))  2  Div

`intCompare`'s result type is a plan-level fill-in: the verdict names the
prim but not its type. `Ordering` (a three-constructor prelude data type)
is chosen over an `Int` sentinel because sum types over flags is a house
rule. Record it in the Stage D SPEC entry.

Classifications, one line each in `lib/prim.ml`:

- `jsonParse` is `Div`, not `Tot`: the parser is host code with no
  structural proof, and the flagship caller feeds it attacker-shaped
  payloads.
- `jsonSerialize` is `Tot`: it walks a finite value.
- `regexTest` and `regexMatch` are `Div`: backtracking engines have
  catastrophic input-and-pattern pairs, and a PreToolUse guard adjudicates
  attacker-influenced text. Typing gives provenance and composition
  discipline, NOT an operational termination proof. Say exactly that in the
  prelude comment beside them.
- `procRun` is `Io`: spawning a process is an observable, ordered effect
  that must not run merely because a value was constructed.

Regex engine: add `str` to `lib/dune`'s libraries. The Div regex prims fire
inline inside `Interp.apply`, so their implementation lives in `lib/`. `Str`
is not `Unix` and not `Sys`, so the "no `Unix`, no `Sys` in `lib/`" rule
holds; write a comment in `lib/prim.ml` and `lib/interp.ml` recording that
the dependency is deliberate and confined to two prims, and that the
pattern dialect is OCaml's `Str`, not PCRE. Record the dialect in SPEC.

### C2. stdlib/prelude.tot

Add, in this order (data before the defs that use it):

    data Ordering : Type 0 := | lt : Ordering | eq : Ordering | gt : Ordering
    data Verdict : Type 0 := | allow : Verdict | ask : String -> Verdict | deny : String -> Verdict
    data ProcessResult : Type 0 := | mkProcessResult : Int -> String -> String -> ProcessResult
    data Json : Type 0 :=
      | jnull : Json
      | jbool : Bool -> Json
      | jnum : Int -> Json
      | jstr : String -> Json
      | jarrNil : Json
      | jarrCons : Json -> Json -> Json
      | jobjNil : Json
      | jobjCons : String -> Json -> Json -> Json

Every constructor argument mentions `Json` only as `Json`, so M2 positivity
accepts it unchanged and no nested-inductive work is touched (decision 2 of
the confirmed user decisions). The price is duplicated array and object
combinators plus the `jsonToList` bridge into the generic `List`
combinators. `List Json` is legal as a RETURN type, which is why the bridge
works. M4 migrates to `jarr : List Json -> Json` behind the same accessor
names.

Accessors and helpers (all ordinary `def`, `def rec` where recursive):

    def headOr : (0 A : Type 0) -> A -> List A -> A
    def rec jsonGet : Json -> String -> Option Json     -- walks the jobjCons spine
    def jsonAsString : Json -> Option String
    def jsonAsInt : Json -> Option Int
    def jsonGetString : Json -> String -> Option String
    def jsonGetStringOr : Json -> String -> String -> String
    def rec jsonToList : Json -> List Json              -- walks the jarrCons spine

`jsonGet` and `jsonToList` recurse on the tail binder bound by the match on
their principal argument, so the M2 structural guard accepts them with
`rec_arg = 0`. If a line does not check, FIX THE LINE (add `as ... return`,
or reorder), not the kernel, and note it in the log.

`required_ctors` in `surface/bootstrap.ml` grows to include the eight Json
constructors, `mkProcessResult`, `allow`, `ask`, `deny`, `lt`, `eq`, `gt`,
`ok`, `err`, `nil` and `cons`. The bootstrap reports
`Missing_prelude_ctor` when any is absent, which is what keeps the
interpreter's build-by-name prim results honest.

### C3. Surface sugar: `let*`, `let*!`, holes

- `surface/token.ml` gains `KLetStar` and `KLetStarDiv`.
- `surface/lexer.ml`: `*` is not an identifier character, so the keyword
  table cannot carry these. Add an explicit rule BEFORE the identifier
  scanner that matches the literal sequences `let*!` and then `let*`, in
  that order (longest first). The bare `let` keyword is unaffected.
- `surface/syntax.ml`: `| SLetStar of Loc.t * bool * string * t * t`, where
  the bool selects `bindDiv` (true) over `bindIO` (false), and
  `| SHole of Loc.t`.
- `surface/parser.ml`: `let* x := e in body` and `let*! x := e in body`.
  In atom position, the identifier `_` becomes `SHole`. Binder positions
  named `_` are unaffected, because they are parsed as binders, not atoms.
- `surface/elab.ml`: desugar purely syntactically, before any typechecking,
  to `bindIO _ _ e (fun x => body)` or `bindDiv _ _ e (fun x => body)`.
  `Elab` never picks the monad; one bind per keyword, so there is no
  inference question about WHICH bind is meant.
- `lib/term.ml` gains ONE payload-free leaf, `| Hole`. Do NOT encode a hole
  as a reserved `Term.Global` name: a global name is looked up, and a
  lookup failure would report `Unbound_global` instead of the honest
  "unresolved hole". Every reader of `Term.t` gains an explicit `Hole` arm.
  `eval`, `erase` and `quote` reject it with
  `Cannot_infer "a hole outside check position"`, because checker output
  never contains one: the pass below substitutes it, or checking fails.
  Record the new leaf in the Marshal-format checklist.
- `lib/check.ml`: the bounded hole pass, in `check` ONLY, never in `infer`.
  When checking an application against a known expected type, and the Pi
  domain variable occurs exactly once and rigidly in the codomain, resolve
  that hole by one structural walk. No search, no backtracking, no new
  failure mode beyond the existing `Cannot_infer`. It never touches
  `Eval.conv`, so it cannot affect conversion's totality.
- FALLBACK, allowed and pre-approved: if the hole pass slips out of the
  stage budget, drop `SHole` and make `let*` require explicit type
  arguments, exactly as `stdlib/prelude.tot` already does for `map`. Then
  the Stage D guard writes `bindIO String Verdict readStdin (fun raw => ...)`
  by hand. Say clearly in the log which of the two shipped.

### C4. The `partial` keyword

Surface: `[reducible] def rec partial NAME : T := BODY` (keyword form, not
a silent downgrade).

- `surface/token.ml`: `KPartial`. `surface/lexer.ml`: keyword `partial`.
- `surface/syntax.ml`: `IDef` gains `partial : bool`.
- `surface/parser.ml`: `partial` follows `rec`.
- `lib/global.ml`: `def_entry` gains `partial : bool`. Every construction
  site sets it; the compiler lists them.
- `lib/check.ml`: `define` gains `~partial:bool`. When set it skips
  `Totality.guard`, forces `reducible = false` and `rec_arg = None`, and
  records `partial = true`. `reducible` together with `partial` is
  `Error.Partial_reducible_conflict name` (new variant, with `to_string`
  and `tag`). A partial def MUST have a `Div`-headed codomain: peel the
  leading `Term.Pi`s of the stamped type, evaluate the codomain, and
  require `VInd ("Div", _)`. A codomain with any other head is
  `Error.Partial_not_div name`, a second new variant beside
  `Partial_reducible_conflict`, both with `to_string` and `tag` arms.
- Divergence stays visible in types and the ladder does real work; the tax
  is that such a body sequences with `bindDiv`.
- `def rec` that fails the guard stays a hard error. `partial` is the only
  way to `Div` from tot source (decision 10).

### C5. surface/effect.ml

`dispatch` gains `Read_file`, `Write_file`, `Argv` and `Proc_run`.
`procRun` uses `Unix.create_process` plus pipes and returns
`Done (VCon ("mkProcessResult", [VLit (LInt code); VLit (LString out);
VLit (LString err)]))`. One documented `try ... with _ ->` fence per raw
call, converting host failures into tot-level `Result` values.

### C6. dev/prim-lint.sh (new) and `tot prims`

`bin/tot.ml` gains a third subcommand, `tot prims`, which prints one line
per `Prim.catalog` entry:

    NAME  ARITY  CLASS  justification text

`dev/prim-lint.sh` runs it, asserts every line carries a non-empty
justification, asserts the catalog size equals the number of `Prim` entries
that the bootstrap seeded, and prints `PASS-C-PRIMLINT`. This is decision
12's lint: a review can read every classification in one place.

### C7. Stage C tests

test/main.ml:
1. `Check.define ~partial:true ~reducible:true` is
   `Partial_reducible_conflict`; print it.
2. `partial` on a def whose codomain is not `Div`-headed is
   `Partial_not_div`; print it.
3. A `def rec` body that fails the structural guard is `Termination`
   without `partial` and is ACCEPTED with `partial` plus a `Div` codomain.
   Assert the stored entry has `reducible = false` and `rec_arg = None`.
4. The hole pass resolves one hole in check position and reports
   `Cannot_infer` for a hole in infer position; print the second.

test/surface.ml:
5. A JSON fixture round trip: `jsonParse` a real payload, project a field
   by `match`, re-serialize with `jsonSerialize`, and compare against the
   expected string exactly.
6. Control test: `data Bad : Type 0 := | jarr : List Json -> Json` style
   nesting, that is a constructor argument of type `List Json`, is STILL
   rejected by positivity; print `Kernel.Bad_ctor`. This pins that the
   self-recursive encoding is load-bearing and that nested inductives did
   not sneak in.
7. `let*` and `let*!` desugar and check; a `let*` over a `Div` action
   without `liftIO` is a `Kernel.Mismatch`; print it.
8. `stringSplit`, `stringSlice`, `stringToInt` and `intCompare` each
   compute one pinned value under `tot run`.

dev/gates.sh:
9. `procRun` on `/bin/echo` populates all three `ProcessResult` fields;
   pin the exit code 0, the stdout text, and the empty stderr.
10. `regexMatch` runs a benign fixture (pinned captures) and a bounded
    pathological fixture. The pathological case runs under an external
    `timeout` and its comment records that the `Div` classification is
    provenance, not a termination proof. Do NOT assert that the
    pathological case completes.
11. `dev/prim-lint.sh` prints `PASS-C-PRIMLINT`.

### Gate C

    (i)   A real JSON fixture round-trips: parse, project by `match`,
          re-serialize, compare.
    (ii)  A control test confirms `jarr : List Json -> Json` is still
          rejected by positivity.
    (iii) `procRun` on `/bin/echo` populates all three `ProcessResult`
          fields.
    (iv)  `regexMatch` runs a benign and a bounded pathological fixture,
          and the pathological one documents the `Div` classification.
    (v)   A `partial def rec` whose body fails the structural guard is
          admitted only with the keyword and only with a Div-headed
          codomain, and `reducible partial` is a checked error.
    (vi)  The prim lint lists every classification.

Markers: `PASS-C-JSON`, `PASS-C-POSITIVITY`, `PASS-C-PROC`, `PASS-C-REGEX`,
`PASS-C-PARTIAL`, `PASS-C-PRIMLINT`.

---

## STAGE D: prelude auto-load, shebang, cache, a real guard

Goal: `tot` becomes a hook runner. The prelude loads itself, a script can
carry a shebang, the prelude cost is amortized by a cache, and one real
PreToolUse guard runs against captured payloads.

Files: `bin/tot.ml`, `surface/cache.ml` (new), `surface/bootstrap.ml`,
`surface/run.ml`, `surface/effect.ml`, `surface/lexer.ml`,
`examples/guard.tot` (new), `test/fixtures/*.json` (new),
`test/surface.ml`, `dev/gates.sh`, `SPEC.md`, `README.md`,
`dev/M3-BUILD-LOG.md`.

### D1. Prelude auto-load

`Run.initial` stops being the CLI's starting point. `bin/tot.ml` computes
the bootstrap state once: `Bootstrap.phase1`, fold `stdlib/prelude.tot`
through the ordinary pipeline, reset `lines` to `[]` so prelude traces
never leak into a script's output, then `Bootstrap.phase2`. `tot run
--no-prelude FILE` and `tot check --no-prelude FILE` keep the empty
environment for kernel tests (decision 14). Locate the prelude relative to
the executable, with an override environment variable `TOT_PRELUDE`;
document the resolution order in the log and in SPEC.

### D2. surface/cache.ml (new)

Key: a digest of the prelude bytes plus a compiled-in cache format version
constant. Value: `Marshal` of `Global.t` and `Interp.globals`, both plain
data because `Prim.t` is a closed enum with no closures.

Read the fixed-width version header PLAINLY before any `Marshal` call. Any
failure at any point (missing file, version mismatch, truncation) is a
MISS, never a crash, through ONE documented `try ... with _ -> None`.
Location `~/.cache/tot/prelude-<hash>.bin`, created lazily. Deleting the
cache directory is always safe. A debug flag (`TOT_CACHE_VERIFY=1`)
recomputes and compares on a hit.

Correctness rests on one argument: elaboration and checking are a pure,
deterministic function of source bytes plus the fixed builtin environment,
so the same key implies identical `Global.t` and `Interp.globals`.

### D3. Shebang

`Lexer.lex` strips ONE leading line when the source starts with `#!` at
column 0, line 1. `--` stays the only comment marker. A hook script then
starts with `#!/usr/bin/env -S tot run`.

### D4. The `main` epilogue completes

`Run.script` compares `main`'s stored type against `IO Verdict` FIRST, then
`IO Unit`, using the existing conversion machinery. Rendering (confirmed
user decision 3):

- `allow`: exit 0, print nothing.
- `ask msg`: print the envelope with `permissionDecision` `"ask"`, exit 1.
- `deny msg`: print the envelope with `permissionDecision` `"deny"`, exit 2.
- `IO Unit`: exit with whatever `exitWith` supplied, or 0.
- An explicit `exitWith` inside an `IO Verdict` action short circuits and
  wins, because `run_io` returns `Exited` and never reaches the verdict.

The envelope, rendered by the driver on ONE line with no trailing spaces:

    {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"MSG"}}

`MSG` is escaped with the Stage A escaper. Put `render_verdict` in
`surface/effect.ml` beside `dispatch`.

In `check` mode the epilogue only prints the type and never calls
`run_io`, so `tot check` on a script that mentions `readFile`, `procRun` or
`exitWith` performs no I/O.

### D5. The ported guard

`examples/guard.tot`, a real port of the house rule that Bash commands use
`rg` instead of `grep` and `sd` instead of `sed`. It reads a JSON payload
on stdin and returns a `Verdict`.

    #!/usr/bin/env -S tot run
    -- PreToolUse guard: keep grep and sed out of Bash command position.

    def firstToken : String -> String :=
      fun cmd => headOr String "" (stringSplit cmd " ")

    def usesBanned : String -> Bool :=
      fun cmd =>
        orb (stringEq (firstToken cmd) "grep") (stringEq (firstToken cmd) "sed")

    def decide : Json -> Verdict :=
      fun payload =>
        match jsonGetString payload "tool_name" with
        | none => allow
        | some name =>
            match stringEq name "Bash" with
            | false => allow
            | true =>
                match jsonGet payload "tool_input" with
                | none => allow
                | some ti =>
                    match usesBanned (jsonGetStringOr ti "command" "") with
                    | true => deny "house rule: use rg instead of grep and sd instead of sed"
                    | false => allow
                    end
                end
            end
        end

    def main : IO Verdict :=
      let* raw := readStdin in
      let* parsed := liftIO (jsonParse raw) in
      match parsed with
      | none => pureIO Verdict allow
      | some payload => pureIO Verdict (decide payload)
      end

Notes for the builder: the guard matches on the FIRST token, not on a
substring, so `ripgrep foo` is allowed and the guard is honest about what
it detects. A malformed payload allows, matching the live hooks' fail-open
posture; write that in a comment. If the C3 hole pass did not ship, write
the two `bindIO` applications explicitly instead of `let*`.

Fixtures under `/Users/oobi/Documents/tot/test/fixtures/`:

    allow.json     {"tool_name":"Bash","tool_input":{"command":"rg foo /tmp/x"}}
    deny.json      {"tool_name":"Bash","tool_input":{"command":"grep foo /tmp/x"}}
    other.json     {"tool_name":"Read","tool_input":{"file_path":"/tmp/x"}}
    garbage.json   not json at all

Expected results, pinned exactly in `dev/gates.sh`:

    allow.json    exit 0, empty stdout
    deny.json     exit 2, stdout exactly the envelope line from D4
    other.json    exit 0, empty stdout
    garbage.json  exit 0, empty stdout (fail open, documented)

Run the guard through its OWN shebang after `chmod +x`, not through
`dune exec`, so the shebang, the prelude auto-load and the cache are all on
the tested path. That needs a `tot` binary on PATH: install it into a
scratch directory with `dune build` plus a copy, and put that directory
first on PATH inside the gate script.

### D6. SPEC.md

Append a dated block `2026-09-01 (M3)` to section 2's decision log with the
fourteen items of verdict 3.10, transcribed, plus the three confirmed user
decisions, plus the plan-level fill-ins this document names:

1. `Term.Pi`, `Lam` and `App` keep their M2 arity. Effects are types, not
   a stamp.
2. `Prim` is a fourth `Global.entry` kind with no `def` and no `reducible`
   field.
3. `Prim.t` is a closed enum with a name and arity table, no closures, for
   the sake of the `Marshal` cache.
4. `Prim.arity` counts kept arguments only.
5. `String`, `Int`, `Div` and `IO` are zero-constructor `Ind` bootstrap
   entries. `Json`, `ProcessResult`, `Unit`, `Ordering` and `Verdict` are
   ordinary prelude `data` items.
6. No `liftDiv`, no `runDiv`. `Div` is absorbing.
7. One elaboration per literal token; no numeric overloading; `Nat` stays
   Peano and separate from `Int`.
8. `Interp.quote` on `VPrim` rebuilds the spine; on `VIOAction` it returns
   `Not_quotable`.
9. `Check.define` refuses `reducible` on a `Div`-headed or `IO`-headed def.
10. `def rec` that fails the guard stays a hard error; `partial` is the
    only way to `Div`, and it forces a `Div`-headed codomain.
11. Deferred definition-time execution keys on the def's type head, not on
    a new attribute.
12. Every prim carries a one-line comment justifying its ladder
    classification; `dev/prim-lint.sh` lists the catalog.
13. An execution budget for a hung guard is the hook runner's job
    (`timeout` in the shebang wrapper or the calling harness), not M3
    kernel work. Recorded as a risk, not built.
14. `tot run --no-prelude` exists for kernel tests.

Then the three confirmed user decisions, verbatim from this plan's header.

Then the plan-level fill-ins, each with its rationale:

- Builtin type formers are DECLARED and never DEFINED, so `ctor_names`
  stays `None` and any `match` on `String`, `Int`, `Div` or `IO` is
  `Ind_incomplete`. This closes the vacuous empty match that would
  otherwise inhabit any type from a `String` scrutinee.
- Integer literals reuse the existing `Nat` token, so the M1 numeric cap
  now bounds int literals as a Lex error.
- `exitWith` returns an `Exited` outcome through `run_io`; the single
  process exit stays in `bin/tot.ml`.
- `intCompare : Int -> Int -> Ordering`, with `Ordering` a prelude data
  type, chosen over an `Int` sentinel.
- Regex uses OCaml's `Str` dialect, not PCRE, and `str` is linked into
  `tot_kernel` for exactly two prims.
- The prim catalog is seeded in two phases around the prelude fold,
  because prim types mention prelude data types.

Section 3: add `Lit` to the grammar, plus the `let*`, `let*!` and `partial`
surface forms and the shebang line. Section 4: add `Literal`, `Prim`,
`Bootstrap`, `Effect` and `Cache` to the module lists, and note the fourth
`Global.entry` kind. Section 5: mark M3 DONE with its actual contents, and
restate M4. Section 6: carry the debts below.

### D7. README.md

Bump the milestone line to M3 if it states one; otherwise leave it.

### Gate D

    (i)   The guard runs through its own shebang after `chmod +x` against
          an allow fixture, a deny fixture and a non-Bash fixture, with
          exact exit codes and exact stdout.
    (ii)  The cache hits on a second invocation and degrades silently to a
          miss on a truncated file, with `Global.t` byte-identical to a
          cold run (compare with `TOT_CACHE_VERIFY=1`).
    (iii) The summed M0, M2 and M3 suites are green.
    (iv)  SPEC.md gains the M3 decision-log entries for items 1 to 14 plus
          the three confirmed user decisions.

Markers: `PASS-D-GUARD-ALLOW`, `PASS-D-GUARD-DENY`, `PASS-D-GUARD-OTHER`,
`PASS-D-CACHE-HIT`, `PASS-D-CACHE-MISS`.

---

## Final

Run the full gate battery one last time, including every `PASS-` marker
from Gates A to D. Append the final tails to `dev/M3-BUILD-LOG.md`. Do not
commit, do not stage.

## Known debts entering M4 (transcribe into SPEC section 6)

Carried from verdict section 6:

- The prim catalog is an unverified trust boundary: nothing checks that an
  OCaml implementation matches its declared ladder position. The mitigation
  is the one-line justification per prim and `dev/prim-lint.sh`.
- Monad laws are invisible to conversion by design. `liftIO (pureDiv x)`
  and `pureIO x` are different neutrals. M4 propositional equality can
  postulate them; unfolding will never derive them.
- `Div` typing gives provenance, not a termination proof. A guard can still
  hang on a crafted regex, so the calling harness keeps a `timeout`.
- Json cons cells duplicate the `List` combinators until nested inductives
  land. The accessor names are chosen so the migration is a stdlib change.
- `Marshal` cache format fragility: the version constant must be bumped on
  any change to `Term.t`, `Value.t`, `Eterm.t`, `Global.entry`, `Interp.v`
  or `Prim.t`. Keep the checklist beside those definitions.
- Hole resolution fires only in check position, so a bare `eval` of a bind
  chain still needs explicit type arguments.

Added by this plan:

- Builtin type formers are non-eliminable through the `Ind_incomplete`
  path, whose error wording says "not yet defined". M4 should give them
  their own marker and message.
- `Str` is linked into `tot_kernel` for two prims, and its match state is
  global. The regex prims must not be re-entered from within a match; the
  interpreter is single threaded today, so this holds by construction, and
  M4 should replace `Str` with a bounded engine.
- `tot check` still executes `Tot`-headed defs at definition time. Only
  `Div`-headed and `IO`-headed defs defer. A pathological pure computation
  in a `Tot` def can therefore still make checking slow.
