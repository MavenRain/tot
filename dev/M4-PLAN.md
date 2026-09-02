# M4 build plan: propositional equality, indexed families, subsingleton erasure, and deterministic classes

Authoritative spec for the M4 implementation agents.  Read this WHOLE file
before touching code.  The repo is /Users/oobi/Documents/tot (OCaml, dune).
Four sequential stages (A, B, C, D), one agent per stage, each stage green
on its own gate before the next one starts.

This document is self-contained.  Every design decision it needs is
written out here.  Do NOT go looking for a design document, a verdict, or
a proposal;  none of them are inputs to the build.  Where this plan fills
in a detail, the paragraph says so and names the alternative it rejected.
If you believe a decision here is wrong, record the argument in
`dev/M4-BUILD-LOG.md` and build it as written.

Background reading, in this order, only if a detail here is ambiguous:
1. `/Users/oobi/Documents/tot/SPEC.md` (sections 2, 3 and 4)
2. `/Users/oobi/Documents/tot/dev/M3-PLAN.md` (the house plan format)
3. `/Users/oobi/Documents/tot/dev/M2-FIXES-LOG.md` "## Round 4" (the
   erased-guard soundness argument that Stage A relaxes and Stage C
   makes executable)

## Confirmed user decisions (2026-09-02, final, not reopenable)

1. **Subsingleton elimination with a three-part fence.**  A match whose
   scrutinee is an erased hypothesis may run at quantity mode `w` exactly
   when its inductive carries no runtime bits.  The criterion has THREE
   parts, all required: at most one constructor, every constructor
   argument binder at quantity 0, and the constructor is NOT
   self-recursive.  An executable backstop (`Eterm.mentions` on the
   erased body, plus a three-state runtime guard whose `Frozen` state
   degrades a missed case to a permanent neutral) ships in its own
   revertible stage.
2. **Class resolution lives in `Check`.**  `auto` is resolved from the
   EXPECTED type, `Term.Auto` is a core constructor that is invalid in
   checker output, and `inst C T` is the explicit escape hatch for
   positions where the expected type is not a class applied to a
   concrete head.  Coherence is `Duplicate_global` on a mangled name.
   Resolution is fuel bounded with an `Inst_depth` error.
3. **General recursive indexed families now.**  `Vec` and `Fin` are
   admitted this milestone.  There is no non-recursive fence.  Fording
   (encoding the index as a parameter plus equations) is PROVEN
   unavailable as a fallback, so a fence would have had no escape route.
4. **`--serror-exit N` ships with default 1.**  Flipping the default to
   3 is a later, separate change, made only after installed guards are
   migrated.
5. **A new `axiom` entry kind, usable only at mode 0**, plus a
   `--no-axioms` driver flag.  The monad laws land as `Eq` axioms.
6. **Equality's permanent shape.**  `Eq` is homogeneous
   Paulin-Mohring, an ordinary `data`, with parameters `(0 A)` and the
   left endpoint, ONE index, sole constructor `refl`, at `Type 0` only,
   `J` is an ordinary match reducing by ordinary iota, there is NO K and
   NO UIP, and there is NO `rewrite` surface form.  Rewriting is the
   prelude defs `subst0`, `sym0`, `trans0` and `cong0`.  This shape is
   permanent;  it is the hardest decision in M4 to reverse later.

## Baseline you start from

M3 is committed (b01b3eb).  The working tree is clean at that commit.
The suite baseline, verified 2026-09-02 on a green build:

    dunecho build                      OK build: 0 errors, 0 warnings
    dune exec test/main.exe            53 "PASS " lines, "M0 kernel: all tests green"
    dune exec test/surface.exe         69 "PASS " lines, "M1 surface: all tests green"
    zsh dev/gates.sh                   GATE-EXIT=0, 44 own "PASS-" markers
    dev/prim-lint.sh                   1 "PASS-" marker, replayed by gates.sh

    TOTAL BASELINE: 53 + 69 + 44 + 1 = 167 PASS, 0 FAIL

Every stage gate runs ON TOP of that number.  A stage that ends with
fewer than 167 + (its own additions) has broken something.  Never delete
or weaken an existing case to make a stage green.

Baseline shapes you will extend (verified 2026-09-02):

    lib/dune       (library (name tot_kernel) (libraries str))
    surface/dune   (library (name tot_surface) (libraries tot_kernel unix))
    bin/dune       (executable (name tot) (libraries tot_kernel tot_surface))
    test/dune      (tests (names main surface) (libraries tot_kernel tot_surface unix))

    Term.t         Var | Univ | Pi | Lam | App | Let | Ann | Global | Lit | Match
    Term.Match     { scrut; motive : (string * t) option; branches }
    Value.t        VUniv | VPi | VLam | VInd | VCtor | VNeutral | VLit
    Value.stuck_match { motive : (string * Term.t) option; branches; menv }
    Eterm.t        EVar | ELam | EApp | ELet | EGlobal | EErased | EMatch | ELit
    Global.entry   Def | Ind | Ctor | Prim
    Global.ind_entry  { ind_ty; params; level; ctor_names : string list option }
    Global.ctor_entry { ctor_ty; ind; args }
    Interp.v       VClos | VCon | VNeut | VErased | VLit | VPrim | VIOAction
    Interp.gentry  { gval : gbody ref; grec_arg : int option; gctor_arity : int option }
    Interp.define  globals -> name:string -> rec_arg:int option -> Eterm.t -> globals
    Token.kind     ... KLetStar | KLetStarDiv | KPartial | Pipe | Ident | Nat | Str | Eof
    Syntax.item    IDef of { loc; name; reducible; rec_; partial; ty; def }
                 | IData of { loc; name; params; level; ctors }
                 | ICheck | IEval
    Serror.t       Lex | Parse | Unknown_name | Bad_level | Kernel | Main_bad_type
    Cache.format_version = 5   (surface/cache.ml line 93, also lines 109 and 180)
    Run.script     ?st:state -> exec:bool -> string -> (string list * int option, Serror.t) result
    Run.item       exec:bool -> state -> Syntax.item -> (state, Serror.t) result

Facts about the CURRENT binary that this plan relies on, each confirmed
by running it on 2026-09-02:

- `data Vec (0 A : Type 0) : Nat -> Type 0 := ...` is a PARSE error,
  "expected 'Type', found identifier Nat".  Indices do not parse yet.
- `data Eq (0 A : Type 0) (0 a : A) : Type 0 := | refl : Eq A a a` is
  rejected with "not a function type: Type 0", because `Eq A a a`
  applies a two-parameter former to three arguments.
- Every match on a quantity-0 binder is `Erased_use` today, whatever the
  family: `Empty` (zero constructors), a one-constructor no-argument
  family, `Box` (one constructor with a `w` argument), and `Bool` (two
  constructors) all fail the same way.  Stage A must flip exactly the
  first two and leave the last two failing.
- `data SX : Type 0 := | wrap : (0 s : SX) -> SX` is ACCEPTED today by
  M2 positivity.  Only the def that eliminates it fails.
- The Fording route is blocked today with two distinct messages:
  `| vpnil : VecP A zero` gives "invalid constructor vpnil: constructor
  must end in VecP applied to its parameters", and
  `| vpcons : (0 m : Nat) -> A -> VecP A m -> VecP A n` gives "invalid
  constructor vpcons: negative or non-uniform occurrence of VecP".
- `auto`, `instance`, `axiom` and `class` are ordinary identifiers
  today.  Making them keywords is a breaking lexer change.  No file in
  `stdlib/`, `examples/` or `test/fixtures/` uses any of the four as a
  name, so the blast radius inside this repo is zero.
- The whole class DICTIONARY layer already typechecks and runs today
  with explicit dictionary arguments (see D3).  Only `class`,
  `instance` and `auto` are new surface.

## 0. Ground rules (house style, enforced by hooks)

- NO exceptions anywhere: no `raise`, no `failwith`, no `assert`.  Every
  failure is a `Result` value.  This milestone adds no new host-boundary
  exception site.
- NO `match` on `Option`/`Result` where a combinator does the job
  (`Option.fold`, `Option.map`, `Option.bind`, `Option.to_result`,
  `Result.bind`, `Result.fold`, `let*`).  A PreToolUse hook DENIES edits
  that add such matches.
- NO loop keywords (`for`, `while`).  Recursion plus `List.fold_left`,
  `List.map`, `List.filteri`, `List.init` only.
- NO mutation of a list or an array.  The one existing mutable cell,
  `Interp.gentry.gval`, stays exactly as it is.
- Exhaustive matches, NO catch-all `_ ->` arms on variant types you can
  enumerate.  Use `match () with | () when ...` ladders, not `if`/`else
  if` chains, and not a nested `if a then (if b then ..) else c`.  This
  milestone adds constructors to `Term.t`, `Global.entry`,
  `Syntax.item`, `Serror.t` and `Interp`'s guard type;  the compiler
  will point at every site, and EVERY site gets a spelled-out arm.
- No `arr.(i)` and no `List.nth`.  Use `List.nth_opt` with
  `Option.fold` or `Option.to_result`.
- Comments: match existing density;  doc comments on every new top-level
  item.
- No em-dashes in any text you write.  ASCII punctuation only.  Two
  spaces after a sentence-ending "." or ";" in prose.
- Shell: `rg` not grep, `sd` not sed.
- Never `cd`.  Use absolute paths.  Your cwd RESETS between Bash calls.
- Do NOT run `git add` and do NOT run `git commit`.  Leave working-tree
  edits only.
- `dev/gates.sh` must not use `set -u` (a chpwd hook breaks under it).

Gate command battery (all must be green before you report):

    dunecho build -- --root /Users/oobi/Documents/tot
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -3
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -3
    zsh /Users/oobi/Documents/tot/dev/gates.sh > "$TMPDIR/tot-gate.out" 2>&1; echo "GATE-EXIT=$?"
    rg -c '^PASS' "$TMPDIR/tot-gate.out"
    rg -c '^FAIL' "$TMPDIR/tot-gate.out"

The `rg -c '^PASS'` count is the milestone's one arithmetic gate.  It
reads 167 at baseline.  Report your stage's number and its decomposition.

RUN THE BATTERY BEFORE YOU EDIT ANYTHING and record the tails in your
report.  A red at baseline belongs to the previous stage, not to yours,
and you must say so instead of absorbing it.

Append a stage report to `/Users/oobi/Documents/tot/dev/M4-BUILD-LOG.md`
when your stage is green: what changed, files touched, new `Error.t` and
`Serror.t` variants, test names added, gate markers added, the new PASS
count with its decomposition, and the gate output tails.

Every feature ships WITH its regression test.  ORACLE RULE: every
negative test must be shown to REJECT for the intended reason (print the
error tag and the message), never to pass vacuously.  Every positive test
must pin an exact value, an exact line, or an exact exit code, never just
"no error".

Marshal-format checklist: any change to `Term.t`, `Value.t`, `Eterm.t`,
`Global.entry`, `Interp.v`, `Interp.gentry` or `Prim.t` bumps
`Cache.format_version` (surface/cache.ml line 93, with the header field
at line 109 and the key at line 180).  The bumps this milestone owns:

    Stage A   5 -> 6   Term.t, Value.stuck_match, Global.ind_entry, Global.ctor_entry
    Stage B   6 -> 7   Global.entry gains Axiom
    Stage C   7 -> 8   Interp.gentry's guard field widens
    Stage D   8 -> 9   Cache's exe-identity header field changes meaning

Keep the comment naming that constant beside each of those type
definitions.

---

## STAGE A: indexed inductive families, subsingleton elimination, positivity

Goal: the kernel accepts indexed inductive families with a Coq-style
`match .. as .. in .. return ..` rule and no unification, stamps the
subsingleton elimination quantity on every match, and generalizes strict
positivity to an index tail.  `Eq` itself is Stage B;  Stage A ships the
machinery `Eq` needs and proves it on `Vec`, `Fin` and the erasure gates.

Files: `lib/term.ml`, `lib/value.ml`, `lib/global.ml`, `lib/error.ml`,
`lib/eval.ml`, `lib/check.ml`, `lib/totality.ml`, `lib/erase.ml`,
`lib/pp.ml`, `surface/token.ml`, `surface/lexer.ml`, `surface/syntax.ml`,
`surface/parser.ml`, `surface/elab.ml`, `surface/bootstrap.ml`,
`surface/run.ml`, `surface/cache.ml`, `test/main.ml`, `test/surface.ml`,
`test/fixtures/` (new files), `dev/gates.sh`, `SPEC.md`.

### A1. lib/term.ml

```ocaml
type t =
  | Var of int
  | Univ of Level.t
  | Pi of Quantity.t * string * t * t
  | Lam of Quantity.t * string * t
  | App of Quantity.t * t * t
  | Let of string * t * t * t
  | Ann of t * t
  | Global of string
  | Lit of Literal.t
  | Auto
      (** M4: an instance request.  CHECK position only.  The checker
          REPLACES it with the resolved instance application, so [Auto]
          never appears in checker output, in erasure, or at runtime.
          Every other kernel pass carries an explicit total backstop
          arm for it. *)
  | Match of {
      scrut : t;
      scrut_q : Quantity.t;
          (** M4: the elimination quantity.  Elaboration writes [Many];
              the checker OVERWRITES it, stamping [Zero] exactly when
              the subsingleton rule of A6 fires.  Kernel evaluation
              ignores it;  only [Erase] consults it. *)
      motive : motive option;
      branches : (string * (Quantity.t * string) list * t) list;
    }

and motive = {
  m_ind : string option;
      (** the family the motive names, from the surface "in I .." clause;
          [None] for an M2/M3 motive and for a materialized constant
          motive.  Diagnostic only: conversion IGNORES it. *)
  m_idx : string list;  (** index binders, outermost first;  [] = M2/M3 *)
  m_self : string;      (** the scrutinee binder *)
  m_body : t;           (** scoped under m_idx (outermost first) then m_self *)
}
```

The old `(string * t) option` motive is exactly the
`{ m_ind = None; m_idx = []; m_self = x; m_body = t }` case, so every
M2/M3 term round-trips.  `Auto` lands in Stage A, not in Stage D, for
two reasons: `Term.t` then changes once instead of twice (one cache
bump), and every kernel walk gets its backstop arm in one pass.  Stage D
adds only the `Check` rule and the surface syntax.  The alternative
rejected: adding `Auto` in Stage D, which costs a second cache bump and
a second sweep of every exhaustive `Term.t` match.

### A2. lib/value.ml

```ocaml
and stuck_match = {
  motive : Term.motive option;   (** CHANGED payload, same option *)
  branches : (string * (Quantity.t * string) list * Term.t) list;
  menv : t list;
}
```

No other `Value` change.  `VInd (name, args)` now carries params
followed by indices in one applied-args list, which `apply` already
produces by appending.  `VCtor` payloads are UNCHANGED, because an index
is never a constructor argument (indices occur only in a constructor's
RESULT type).  So runtime constructor representation, `run_match`'s
params slice and the whole Interp freeze machinery keep their exact
M2/M3 shapes.

### A3. lib/global.ml

```ocaml
(** M4: an inductive's constructor list, three-state.  [Provisional] is
    M2's [ctor_names = None] window between [declare_ind] and
    [define_ind].  [Builtin] is a type former that will NEVER be
    defined (String, Int, Div, IO), which needs its own elimination
    message.  [Complete] is M2's [Some names]. *)
type ctor_status =
  | Provisional
  | Builtin
  | Complete of string list

type ind_entry = {
  ind_ty : Term.t;      (** closed: params -> indices -> Univ level *)
  params : telescope;
  indices : telescope;  (** NEW: scoped under params;  every binder Zero *)
  level : Level.t;
  ctors : ctor_status;  (** RENAMED from ctor_names, three-state *)
}

type ctor_entry = {
  ctor_ty : Term.t;
  ind : string;
  args : telescope;
  res_idx : Term.t list;
      (** NEW: the constructor's result index expressions, scoped under
          params ++ args;  [] for an M2/M3 data declaration *)
  full_arity : int;
      (** NEW: n_params + List.length args.  Retires [Eval.is_canonical]'s
          second [find_ind] lookup on the guarded-unfolding hot path. *)
  self_rec : bool;
      (** NEW: some argument type mentions the owning inductive.
          Consulted by the subsingleton criterion of A6 and by nothing
          else. *)
}
```

Add `find_ind_arity : string -> t -> (int * int) option`, returning
`(n_params, n_indices)`, so callers stop recomputing two `List.length`s.

`entry_ty`, `def_of`, `ind_of`, `ctor_of` and `prim_of` are unchanged in
shape;  `ind_entry`'s field rename touches every reader.

### A4. lib/error.ml

New variants (house shape: the constructor name is the tag).  Add every
one to `to_string` and to `tag`.

```ocaml
| Index_not_zero of string
    (** an index binder of an inductive declaration carries quantity w *)
| Index_above_universe of {
    ind : string;
    index : string;
  }  (** an index TYPE lives above the inductive's declared universe *)
| Motive_index_arity of {
    ind : string;
    expected : int;
    found : int;
  }  (** the motive binds the wrong number of index names *)
| Motive_wrong_ind of {
    expected : string;
    found : string;
  }  (** the motive's "in I .." clause names a different family *)
| Builtin_not_eliminable of string
    (** a match reached a builtin type former, which has no constructors
        and never will *)
```

Exact `to_string` wording, to be reproduced verbatim:

```ocaml
| Index_not_zero n ->
    Printf.sprintf "inductive %s: every index binder must be marked 0" n
| Index_above_universe { ind; index } ->
    Printf.sprintf "inductive %s: index %s lives above the declared universe" ind index
| Motive_index_arity { ind; expected; found } ->
    Printf.sprintf "match motive for %s binds %d index name(s), expected %d" ind found
      expected
| Motive_wrong_ind { expected; found } ->
    Printf.sprintf "match motive names inductive %s, but the scrutinee is a %s" found
      expected
| Builtin_not_eliminable n ->
    Printf.sprintf "cannot eliminate %s: it is a builtin type former with no constructors" n
```

`Ind_incomplete` keeps its M2 wording and now fires ONLY for the
`Provisional` window.  That split is the "builtin marker plus honest
message" debt, discharged here rather than in Stage D, because
`ctor_status`'s exhaustive match forces the decision the moment the
three-state type exists.

### A5. lib/eval.ml

- `is_canonical`: one `Global.find_ctor` lookup, comparing
  `List.length args` against `ctor.Global.full_arity`.  The chained
  `find_ind` lookup is DELETED.  This is the "ctor-arity cache" debt,
  discharged here for the same reason as A4's builtin marker: the field
  arrives with this record change.
- `eval` on `Term.Auto`: `Error (Error.Cannot_infer "auto")`, a total
  backstop, unreachable on checker output.
- `run_match`: UNCHANGED mechanics.  `scrut_q` is an erasure-time
  stamp;  the kernel keeps full semantics, which is what subject
  reduction needs.  Its `n_params` slice still reads
  `List.length ind.Global.params`, which is correct because indices are
  not constructor arguments.
- `quote` of an `FMatch` whose motive is
  `Some { m_ind; m_idx; m_self; m_body }` with `m = List.length m_idx`:

```ocaml
let idx_env = List.init m (fun i -> Value.var (size + m - 1 - i)) in
let menv' = Value.var (size + m) :: (idx_env @ sm.Value.menv) in
let* mot_v = eval globals menv' m_body in
let* mot_t = quote globals (size + m + 1) mot_v in
Ok (Some { Term.m_ind; m_idx; m_self; m_body = mot_t })
```

  Read the environment as: index 0 is the scrutinee binder (the newest
  level, `size + m`), index 1 is `y_m`, and index `m` is `y_1`.  That is
  exactly "scoped under m_idx then m_self".
- `conv_stuck_match`: motives compare under the same `m + 1` fresh
  variables.  Differing `m_idx` LENGTHS are `Ok false`.  `m_ind` is
  IGNORED: a materialized constant motive writes `None` while an
  explicit one writes `Some "Vec"`, and those two must still compare
  equal, exactly as M2 fixes made `None` and `Some` motives compare
  equal by materializing the constant one.
- `conv`: unchanged.  There is no new `Value.t` constructor.

### A6. lib/check.ml

This is the stage's centre of gravity.  Four pieces.

**A6.1 `declare_ind` grows an index telescope.**

```ocaml
val declare_ind :
  Global.t -> name:string -> params:Global.telescope ->
  indices:Global.telescope -> level:Level.t -> (Global.t, Error.t) result
```

`indices` is REQUIRED, not optional with a `[]` default, so that every
existing call site is visited by the compiler.  Behavior: check the
params exactly as today, then fold the index telescope under the params
context.  Per index binder `(q, x, ty)`:

- `Quantity.equal q Quantity.Zero`, else `Index_not_zero name`.
- `infer_univ` gives a level `l`;  require `Level.le l level`, else
  `Index_above_universe { ind = name; index = x }`.

`ind_ty` is the params telescope, then the index telescope, then
`Univ level`.  Status is `Provisional`.

The `Level.le` bound on index TYPES is conservative.  Agda exempts index
types from the predicative bound, and that exemption is probably sound
here too because no constructor field ever stores an index.  The bound
costs `Eq`, `Vec` and `Fin` nothing and keeps the soundness argument one
sentence long, so it ships.  The alternative rejected: the Agda-style
exemption, which buys nothing this milestone and lengthens the argument.
Record the bound as a debt (see A15).

**A6.2 `declare_builtin`, the bootstrap-only entry point.**

```ocaml
val declare_builtin :
  Global.t -> name:string -> params:Global.telescope -> (Global.t, Error.t) result
```

Same as `declare_ind ~indices:[]`, except the stored status is
`Builtin`.  `define_ind` on a `Builtin` inductive is `Ind_redefined`.
`surface/bootstrap.ml`'s `builtin_types` fold switches to this call.

**A6.3 `define_ind` generalizes the result head and positivity.**

Let `n = List.length ind.params` and `m = List.length ind.indices`.
Replace the current `is_applied` with:

```ocaml
(** [name] applied to exactly its parameter variables in order, then to
    [m] index expressions none of which mention [name].  Seen under
    [depth] binders below the parameters. *)
let is_applied (depth : int) (t : Term.t) : bool =
  let head, sp = Totality.spine t [] in
  let head_ok =
    match head with
    | Term.Global g -> String.equal g name
    | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto
    | Term.Pi (_, _, _, _)
    | Term.Lam (_, _, _)
    | Term.App (_, _, _)
    | Term.Let (_, _, _, _)
    | Term.Ann (_, _)
    | Term.Match _ ->
        false
  in
  head_ok
  && Int.equal (List.length sp) (n_params + n_indices)
  && List.mapi (fun j arg -> (j, arg)) sp
     |> List.for_all (fun (j, arg) ->
            match () with
            | () when j >= n_params -> index_expr_clean arg
            | () ->
                (match arg with
                | Term.Var ix -> Int.equal ix (depth + n_params - 1 - j)
                | Term.Univ _ | Term.Lit _ | Term.Auto
                | Term.Pi (_, _, _, _)
                | Term.Lam (_, _, _)
                | Term.App (_, _, _)
                | Term.Let (_, _, _, _)
                | Term.Ann (_, _)
                | Term.Global _ | Term.Match _ ->
                    false))
```

with `index_expr_clean` a NAMED top-level-in-`define_ind` function:

```ocaml
(** An index expression may be any term that does not mention the
    inductive being defined.  Named and separated from [is_applied] so a
    kernel test can exercise it directly;  see A13 test 6 and the
    reachability note in A15. *)
let index_expr_clean (e : Term.t) : bool = no_occur e
```

`strict_pos` for constructor ARGUMENT types is unchanged in shape and
inherits the generalized `is_applied`: an occurrence of `I` must be
`I p1 .. pn e1 .. em` with the params uniform and every `ej`
`no_occur`-clean, possibly as the codomain of a Pi telescope whose
domains never mention `I`.

The Bad_ctor reason strings change to name the index count:

```ocaml
reason = "constructor must end in " ^ name ^ " applied to its parameters and "
         ^ string_of_int n_indices ^ " index expression(s)"
```

and the positivity reason string stays exactly
`"negative or non-uniform occurrence of " ^ name`, because the Fording
negative fixture pins it verbatim.

Also computed at install time, per constructor:

- `res_idx` = the codomain spine dropped of its first `n_params`
  entries, i.e. `List.filteri (fun j _a -> j >= n_params) sp`.  Scoped
  under params ++ args.
- `full_arity` = `n_params + List.length args`.
- `self_rec` = `List.exists (fun (_q, _x, ty) -> Totality.mentions name ty) args`.
  Reuse `Totality.mentions`;  do not write a second walk.

Status transitions: `Provisional -> Complete names`.  `define_ind` on
`Builtin` or on `Complete` is `Ind_redefined`.

**A6.4 The indexed match rule, exact.**

`match_scrut` changes signature:

```ocaml
and match_scrut (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (scrut : Term.t) :
    ( Term.t * Quantity.t * string * Value.t list * Value.t list * string list,
      Error.t )
    result
```

returning the stamped scrutinee, the stamped elimination quantity, the
inductive's name, its PARAMETER values, its INDEX values, and its
declared constructor names.

Body, in order:

1. `infer globals ctx Quantity.Zero scrut` gives `s0` and `s_ty`.
   Inferring at mode `Zero` first is what lets an erased hypothesis be
   the scrutinee at all;  it is always sound because mode `Zero` is the
   weakest mode.
2. `s_ty` must be `Value.VInd (iname, avals)`, else `Not_inductive`.
3. Look up `iname`.  Require
   `List.length avals = n_params + n_indices`, else `Not_inductive`
   (a value whose applied arity disagrees with the former's own
   telescope is not a well-formed value of that type, whatever the
   constructor status;  this is M2 fixes Round 3's S3 rule, widened by
   the index count).
4. `pvals = List.filteri (fun j _v -> j < n_params) avals` and
   `ivals = List.filteri (fun j _v -> j >= n_params) avals`.
5. Constructor status: `Provisional` is `Ind_incomplete iname`,
   `Builtin` is `Builtin_not_eliminable iname`, `Complete names` carries
   on.
6. Elimination quantity, a deterministic two-pass with no error-driven
   retry:

```ocaml
(** The three-part subsingleton criterion (user decision 1).  [true]
    iff eliminating a value of this family can never observe a runtime
    bit: at most one constructor, every constructor argument binder at
    quantity 0, and the constructor NOT self-recursive. *)
let zero_eliminable (globals : Global.t) (ind : Global.ind_entry) : bool =
  match ind.Global.ctors with
  | Global.Provisional -> false
  | Global.Builtin -> false
  | Global.Complete [] -> true
  | Global.Complete [ c ] ->
      Global.find_ctor c globals
      |> Option.fold ~none:false ~some:(fun (ctor : Global.ctor_entry) ->
             List.for_all
               (fun (q, _x, _ty) -> Quantity.equal q Quantity.Zero)
               ctor.Global.args
             && not ctor.Global.self_rec)
  | Global.Complete (_ :: _ :: _) -> false
```

   If `zero_eliminable` holds, return `s0` with `scrut_q = Quantity.Zero`.
   Otherwise re-run `infer globals ctx mode scrut` and return that
   stamped scrutinee with `scrut_q = Quantity.Many`.

   Two fill-ins here, both deliberate.  First, the second pass costs one
   extra inference on non-subsingleton scrutinees;  scrutinees are small
   (usually a variable), and the alternative (inferring at the ambient
   mode first and RETRYING on `Erased_use`) makes the rule
   error-driven, which is not acceptable in a kernel.  Second, the
   non-subsingleton stamp is `Many`, NOT the ambient mode.  Erasure only
   distinguishes `Zero` from `Many`, and restricting the `Zero` stamp to
   the subsingleton case is what makes `Erase`'s two-or-more-branch
   backstop provably unreachable.  The alternative rejected: stamping
   the ambient mode, which would let a mode-`Zero` match on a
   two-constructor family carry `scrut_q = Zero` and reach the `Zero`
   erasure arm through a `Lam Zero` walk.

**Infer position** (an explicit motive is required, as in M2):

- If `m_ind = Some n` and `n <> iname`, then
  `Motive_wrong_ind { expected = iname; found = n }`.
- If `List.length m_idx <> n_indices`, then
  `Motive_index_arity { ind = iname; expected = n_indices; found = List.length m_idx }`.
- Build `ctx_m`: bind each index binder `y_j` at the j-th index
  telescope type, evaluated under `pvals` followed by the previously
  bound fresh index variables, at quantity `Many`;  then bind `m_self`
  at `Value.VInd (iname, pvals @ fresh_index_vars)`, at quantity `Many`.
- `infer_univ` the motive body in `ctx_m`.
- Per branch for constructor `c`: `walk_telescope` yields `fresh_args`
  AND (new) the final `tele_env`.  Evaluate each stored `res_idx` term
  of `c` in `tele_env` to get `ivals_c`.  The branch body's expected
  type is `Eval.eval globals (Value.VCtor (c, pvals @ fresh_args) :: (List.rev ivals_c @ ctx.env)) m_body`.
- The match's own type is
  `Eval.eval globals (scrut_v :: (List.rev ivals @ ctx.env)) m_body`.

`walk_telescope` must therefore return a fourth component, the final
`tele_env`.  That is the only signature change it needs;  its binder
logic is untouched, because indices add no branch binders.

**Check position, no motive**: every branch checks at the expected type.
This is M2 fixes' constant-motive rule.  It is index-invariant and
therefore sound: it factors through the dependent rule with a motive
that ignores all `m + 1` of its binders.  The MATERIALIZED output motive
is

```ocaml
{ Term.m_ind = None;
  m_idx = List.init n_indices (fun _i -> "_");
  m_self = "_";
  m_body = <quote globals (ctx.size + n_indices + 1) expected_v> }
```

so that a motive-free match and an equivalent explicit-motive match
still compare equal in conversion.

**Check position with an explicit motive**: `check_via_infer`, as today.

There is NO index unification anywhere.  Branch binders see exactly the
constructor telescope: no equations, no rewriting of the context.  This
is the Coq `match .. as .. in .. return` rule.  It needs no metavariable
engine, keeps branches in declaration order, keeps exhaustiveness flat,
and degenerates VERBATIM to the M2/M3 rule when `n_indices = 0`.  Empty
types still eliminate by a zero-branch match, indexed or not, because
the rule imposes no per-branch obligation.

Subject reduction: iota on `VCtor (c, pvals @ own)` picks branch `c`,
whose expected type was computed at `c`'s own `res_idx`.  The scrutinee
value's type at that moment IS `I pvals (res_idx c own)` by the
constructor's type, so the reduct's type is the motive at exactly those
indices.  The rule is the standard eliminator typing, specialized per
constructor.  Guarded unfolding is untouched: no new eliminator exists,
and `J` (Stage B) is a plain reducible NON-recursive prelude def whose
body is a single match, so conversion unfolds it freely and stops at a
neutral scrutinee.

**A6.5 `Term.Auto` arms in `Check`.**

- `infer` on `Term.Auto`: `Error (Error.Cannot_infer "auto")`.
- `check` on `(Term.Auto, expected)`: `Error (Error.Cannot_infer "auto")`
  in Stage A, replaced by the real rule in Stage D.  Write it as its own
  match arm, not folded into the `check_via_infer` catch-all group, so
  Stage D edits one arm.

**A6.6 Soundness note to carry into the code as a comment.**

M2 fixes Round 4 proved its erased-guard rule sound through the
invariant "a quantity-0 formal can only be eliminated while checking at
mode `Zero`".  The subsingleton rule DELETES that invariant on purpose.
The repaired argument, which must be written as a comment above
`zero_eliminable`: a recursive call guarded on an erased principal
argument now requires a `Smaller` binder whose type is the principal's
own family `F`, and `Smaller` binders arise only through subsingleton
matches on NON-self-recursive families.  Chasing that chain, an
`F`-typed `Smaller` binder forces `F` to occur (through erased fields)
strictly inside itself, and any such family is empty by induction on
term size.  So an erased body that still mentions its own global name
can only be forced through an inhabitant of an empty type, which a total
language never produces.  The `self_rec = false` clause is the syntactic
fence that keeps that chain from starting.  Stage C makes the invariant
EXECUTABLE instead of assumed.  The emptiness claim itself stays
UNPROVEN;  nothing load-bearing rests on it, because the fence is
syntactic and the backstop is executable.

### A7. lib/totality.ml

- `peel`, `spine`, `mentions` and `passes`'s inner `ok` each gain a
  `Term.Auto` arm.  `Auto` is a leaf: `peel` and `spine` stop at it,
  `mentions` returns `false`, `ok` returns `true`.  All four are
  unreachable on checked bodies;  say so in one comment.
- `mentions` and `ok` walk the new motive record.  The motive body is
  walked under `m + 1` binders of status `Other`:

```ocaml
let motive_ok =
  motive
  |> Option.fold ~none:true ~some:(fun (mo : Term.motive) ->
         let st_m =
           List.fold_left (fun acc _y -> Other :: acc) (Other :: st) mo.Term.m_idx
         in
         ok st_m mo.Term.m_body)
```

- Branch binder status logic is UNCHANGED.  Indices add no branch
  binders, so the `Smaller` propagation rule is byte-for-byte M2's.

### A8. lib/erase.ml

```ocaml
| Term.Match { scrut = _; scrut_q = Quantity.Zero; motive = _; branches } ->
    (* subsingleton elimination: the family carries no runtime bits, so
       the scrutinee is dropped entirely.  Dropping it is sound because
       the language is total: the scrutinee is a pure, terminating
       computation whose value the branch cannot inspect. *)
    (match branches with
    | [] -> Ok Eterm.EErased
    | [ (_c, binders, body) ] ->
        let ctx' =
          List.fold_left (fun cacc (_q, x) -> (x, false) :: cacc) ctx binders
        in
        term ctx' body
    | _ :: _ :: _ -> Error (Error.Erased_use "match"))
| Term.Match { scrut; scrut_q = Quantity.Many; motive = _; branches } ->
    (* the M3 code, verbatim *)
| Term.Auto -> Error (Error.Cannot_infer "auto")
```

The checker stamps `scrut_q = Zero` only for a zero-constructor family
or for one all-erased non-self-recursive constructor, so the one-branch
arm binds only dropped binders and the two-or-more arm is genuinely
unreachable.  Both backstops stay.

### A9. lib/pp.ml

- `term` on `Term.Auto` prints `auto`.
- `term` on a `Match` motive prints the full surface form:
  `match S as x return P with` when `m_idx = []` and `m_ind = None`,
  and `match S as x in I y1 .. ym return P with` otherwise.  When
  `m_ind = None` but `m_idx` is non-empty (a materialized constant
  motive over an indexed family), print `in _ y1 .. ym`.
- No `Eterm` change: erasure never emits a motive.

### A10. surface/token.ml and surface/lexer.ml

One new keyword this stage: none.  `in` reuses the existing `KIn`, which
is already in the application-stopping keyword set (parser.ml line 22),
so the optional `in` clause needs no lexer change at all.

Stage B adds `KAxiom`, Stage D adds `KAuto`, `KClass`, `KInstance` and
`KInst`.  Do NOT add them early;  each is a breaking change for scripts
that use the word as an identifier, and each stage owns its own
breakage.

### A11. surface/syntax.ml, surface/parser.ml, surface/elab.ml

**Syntax.**

```ocaml
type smotive = {
  sm_self : string;
  sm_ind : string option;
  sm_idx : string list;
  sm_body : t;
}
```

`SMatch` becomes `SMatch of Loc.t * t * smotive option * (string * string list * t) list`.

`IData` gains `indices : (Quantity.t * string * t) list`, outermost
first.

**Parser: the data index telescope.**

`parse_data` currently calls `parse_data_level` right after the `:`.
Replace that with: parse ONE term with `parse_term`, then peel it.

```
data NAME PARAMS ":" CODOMAIN ":=" CTORS
CODOMAIN peels as a chain of SPi binders ending in SType.
```

Peel rules, applied left to right:

- `Syntax.SType (_, level)` ends the peel and gives the level.
- `Syntax.SPi (_, Quantity.Zero, x, dom, cod)` contributes an index
  binder `(Quantity.Zero, x, dom)` and continues on `cod`.
- `Syntax.SPi (loc, Quantity.Many, "_", dom, cod)` is the `T ->` arrow
  sugar (SPEC pins `A -> B` as `(w _ : A) -> B`).  It contributes
  `(Quantity.Zero, "_", dom)` and continues.
- `Syntax.SPi (loc, Quantity.Many, x, _dom, _cod)` with `x <> "_"` is
  `Serror.Parse { loc; msg = "data indices must be marked 0" }`.
- Anything else is
  `Serror.Parse { loc; msg = "expected 'Type', found ..." }`, keeping
  the current message shape so the existing negative surface test still
  matches.

This reuses `parse_term` whole instead of writing a second telescope
parser, and it is why `parse_data_level` disappears.  Residual, recorded
on purpose: an explicitly written `(w _ : Nat) -> Type 0` index is
silently forced to quantity 0 rather than rejected, because the arrow
sugar and an explicit anonymous `w` binder produce the identical surface
node.  The alternative rejected: threading a "came from arrow sugar" bit
through `Syntax.SPi`, which pollutes every term for one error message.

**Parser: the match motive.**

`parse_match` gains one arm, between the existing `KAs`-with-motive arm
and the `KAs`-error arm:

```
match S with ...                                  -- motive = None
match S as x return P with ...                    -- sm_ind = None,  sm_idx = []
match S as x in I y1 .. ym return P with ...      -- sm_ind = Some I, sm_idx = [y1;..;ym]
```

Implementation: after `KAs :: Ident x`, look at the next token.  On
`KIn :: Ident iname :: rest`, run the existing `collect_idents` on
`rest` to take `y1 .. ym`, then require `KReturn`.  On `KReturn`, take
the M2 path.  Anything else keeps the current
`"expected 'NAME return TYPE' after 'as'"` error, widened to
`"expected 'NAME [in FAMILY IDX..] return TYPE' after 'as'"`.

The index binders sit INSIDE the motive clause, after `as`, on purpose.
That placement is unambiguous against a `let .. in ..` scrutinee: the
`in` clause can only appear after `as x`, and `parse_term` has already
consumed the whole `let` by then.  The alternative rejected: putting the
index clause immediately after the scrutinee (`match S in I y .. as x
return P`), which collides with a `let`-bound scrutinee and would have
forced parentheses plus a documented footgun.

**Elab.**

- `SMatch` motive: scope the body under the index names in order, then
  the self name:

```ocaml
let scope' = sm.sm_self :: List.fold_left (fun s y -> y :: s) scope sm.sm_idx in
```

- The G2 arity check lives here, because `Elab.term` already receives
  `globals`.  When `sm_ind = Some iname`, look up
  `Global.find_ind iname globals`.  Absent is
  `Serror.Unknown_name { loc; name = iname }`.  Present with an index
  count `m` different from `List.length sm_idx` is
  `Serror.Kernel { loc; err = Error.Motive_index_arity { ind = iname; expected = m; found = List.length sm_idx } }`.
  Reusing the kernel error keeps `Serror.t` unchanged and makes the
  surface and kernel diagnostics identical.
- `Elab` writes `scrut_q = Quantity.Many` as the placeholder, exactly as
  it writes `Quantity.Many` on every `SApp` and `SLam`.  The checker
  overwrites it.
- No `Auto` elaboration yet;  Stage D adds `SAuto` and `SInst`.

**Bootstrap.kept_pi_count** enumerates every `Syntax.t` constructor by
name in its fallthrough pattern.  `SMatch`'s payload changes shape, so
that pattern needs its arm updated even though the behavior is the same.

### A12. surface/run.ml and surface/bootstrap.ml

- `Run.item`'s `IData` arm passes the new `indices` through to
  `Check.declare_ind`.  Its constructor-arity fold for
  `Interp.add_ctor` is UNCHANGED: it counts `Quantity.Many` entries of
  `centry.Global.args`, and indices are not args.
- `Run.item`'s `IData` arm reads `ind.Global.ctors` instead of
  `ind.Global.ctor_names` wherever it does today.
- `Bootstrap.builtin_types` fold calls `Check.declare_builtin` instead
  of `Check.declare_ind`.
- No other `surface/` behavior changes in Stage A.

### A13. surface/cache.ml

Bump `format_version` from 5 to 6 (line 93).  Append one entry to the
bump-checklist comment above the definition, naming `Term.t`'s
`scrut_q` plus motive record, `Value.stuck_match`'s motive payload, and
`Global.ind_entry` / `Global.ctor_entry`.

### A14. Stage A tests

`test/main.ml` (kernel;  append to `cases`, keep all 53).  Labels use the
`A<n>:` prefix family, matching the house convention.

1. `A1: an indexed family declares, defines, and reports its arity`.
   Build `Vec` by hand through `declare_ind ~params ~indices` and
   `define_ind`, then assert `Global.find_ind_arity "Vec" g = Some (1, 1)`
   and that `find_ctor "vcons"` reports `full_arity = 4`,
   `self_rec = true`, and `res_idx` of length 1.
2. `A2: an index binder marked w is Index_not_zero`.  Call
   `declare_ind` with an index telescope entry at `Quantity.Many`.  Pin
   the tag and print the message.
3. `A3: an index type above the declared universe is Index_above_universe`.
   Declare at level 0 with an index of type `Type 0`.  Pin the tag and
   print the message.
4. `A4: a constructor with the wrong index count is Bad_ctor`.  Give
   `Vec` a constructor ending in `Vec A` (no index).  Pin the tag and
   print the message.
5. `A5: the Fording route stays blocked`.  Build `VecP` with the length
   as a second PARAMETER and a `vpnil : VecP A zero` constructor.  Pin
   `Bad_ctor` and print the message, which must contain
   `"applied to its parameters"`.  Then build the non-uniform variant
   and pin `Bad_ctor` with `"negative or non-uniform occurrence of"`.
6. `A6: index_expr_clean rejects an index expression mentioning its own
   family`.  Call the extracted predicate directly on
   `Term.App (Quantity.Many, Term.Global "I", Term.Var 0)` for
   `name = "I"` and assert `false`, then on `Term.Var 0` and assert
   `true`.  This is a UNIT test on purpose;  see the reachability note
   in A15.
7. `A7: the subsingleton criterion, all four shapes`.  Assert
   `zero_eliminable` is `true` for a zero-constructor family and for a
   one-constructor family whose single argument is quantity 0 and
   non-self-recursive, and `false` for `Box`
   (`| mkBox : (w x : Nat) -> Box`) and for `SX`
   (`| wrap : (0 s : SX) -> SX`).  The `SX` row is the fence: it must
   be `false` because `self_rec` is `true`, NOT because of a quantity.
   Assert `self_rec` on `wrap` is `true` in the same case.
8. `A8: subst-shaped erasure is the identity`.  Hand-build a
   one-constructor erased family `Sing`, a def
   `fun (0 A) (0 s) (px : Nat) => match s with | mk => px end`, check
   it, `Erase.closed` it, and pin the printed erased term as exactly
   `fun px => px`.
9. `A9: a zero-branch subsingleton match erases to the erased residue`.
   Same shape over a zero-constructor family;  pin the printed erased
   term as `<erased>` (whatever `Pp.eterm` already prints for
   `EErased`;  read it, do not guess).
10. `A10: additivity, a materialized constant motive still converts`.
    Two stuck matches on the same `Bool` neutral, one written with an
    explicit `as x return Bool` motive and one motive-free, are
    convertible.  This is the M2 fixes materialization test re-run
    against the motive RECORD.
11. `A11: Term.Auto is rejected by every kernel pass`.  `Eval.eval` on
    `Term.Auto` is `Cannot_infer`, `Erase.closed` on `Term.Auto` is
    `Cannot_infer`, and `Check.infer` on `Term.Auto` is `Cannot_infer`.
    Print all three tags.
12. `A12: a builtin type former reports Builtin_not_eliminable`.
    Declare `String` with `declare_builtin`, then try to match on a
    `String`-typed neutral.  Pin the tag and print the message.  A
    `Provisional` inductive still reports `Ind_incomplete`;  pin that
    too, in the same case, so the split is shown to be a split.

`test/surface.ml` (append to `cases`, keep all 69):

13. `A13: Vec declares and its constructors print`.  `expect_lines_check`
    on the `Vec` source of A16 below, pinning the exact `data` and
    `ctor` echo lines.
14. `A14: Fin declares`.  Same, for `Fin`.
15. `A15: a vector value builds and runs`.  `expect_lines` on
    `eval vcons Nat zero (succ zero) (vnil Nat)`, pinning the readback.
16. `A16: an index binder marked w is a parse error`.
    `expect_err "data B : (w n : Nat) -> Type 0 :=" "Parse"`.
17. `A17: a motive naming the wrong family is Motive_wrong_ind`.
    `expect_err_printed` on a match over a `Vec` with `in Fin y`.
18. `A18: a motive with the wrong index arity is Motive_index_arity`.
    `expect_err_printed` on `in Vec` with zero binders over a
    one-index family.
19. `A19: the ESE negative, a two-constructor family stays Erased_use`.
    `expect_err_printed` on
    `def f : (0 b : Bool) -> Nat := fun b => match b with | true => zero | false => zero end`
    with tag `Kernel.Erased_use`.
20. `A20: the Box negative, a w-carrying single constructor stays Erased_use`.
    `expect_err_printed` on the `Box` source of A16 with tag
    `Kernel.Erased_use`.
21. `A21: the SX negative, a self-recursive erased singleton stays Erased_use`.
    `expect_err_printed` on the `SX` source with tag
    `Kernel.Erased_use`.
22. `A22: a one-constructor erased family now eliminates`.
    `expect_lines_check` on
    `data U1 : Type 0 := | u1 : U1` plus
    `def useU1 : (0 u : U1) -> Nat := fun u => match u with | u1 => zero end`,
    pinning the exact echo lines.  This is the flip that A19 to A21 fence.
23. `A23: an empty family now eliminates`.  `expect_lines_check` on
    `data Empty : Type 0 :=` plus
    `def exfalso : (0 A : Type 0) -> (0 e : Empty) -> A := fun A e => match e with end`.
    Today this is `Erased_use`;  after Stage A it must check.

### A15. Stage A fixtures

New files under `test/fixtures/`, each opening with the house
`--` comment block naming the stage, the gate marker that consumes it,
and what a regression would look like.

- `m4a-vec.tot` (positive, gate `PASS-M4A-VEC`):

```
data Vec (0 A : Type 0) : Nat -> Type 0 :=
  | vnil : Vec A zero
  | vcons : (0 n : Nat) -> A -> Vec A n -> Vec A (succ n)
data Fin : Nat -> Type 0 :=
  | fzero : (0 n : Nat) -> Fin (succ n)
  | fsucc : (0 n : Nat) -> Fin n -> Fin (succ n)
def twoNats : Vec Nat (succ (succ zero)) :=
  vcons Nat (succ zero) zero (vcons Nat zero (succ zero) (vnil Nat))
eval twoNats
```

  Expected to check and run after Stage A.  Every part of this file uses
  new M4 syntax, so it cannot be checked before the stage lands;  the
  gate is its first execution.

- `m4a-vec-badindex.tot` (negative, gate `PASS-M4A-VEC-BADIX`):

```
data VecB (0 A : Type 0) : Nat -> Type 0 :=
  | vbnil : VecB A
```

  Expected `Kernel.Bad_ctor`, message containing
  `"applied to its parameters and 1 index expression(s)"`.

- `m4a-box.tot` (negative, gate `PASS-M4A-BOX`):

```
data Box : Type 0 := | mkBox : (w x : Nat) -> Box
def unbox : (0 b : Box) -> Nat := fun b => match b with | mkBox x => x end
```

  Expected `Kernel.Erased_use`, message
  `"erased variable b used at runtime"`.  VERIFIED against the current
  binary: this is exactly what it prints today, and Stage A must not
  change it.

- `m4a-sx.tot` (negative, gate `PASS-M4A-SX`):

```
data SX : Type 0 := | wrap : (0 s : SX) -> SX
def rec sxLoop : (0 s : SX) -> Nat := fun s => match s with | wrap s2 => sxLoop s2 end
```

  Expected `Kernel.Erased_use`, message
  `"erased variable s used at runtime"`.  VERIFIED against the current
  binary.  Note that `data SX` itself is ACCEPTED, today and after
  Stage A;  only the eliminating def is rejected, and it is rejected at
  the STAMP (the family fails `zero_eliminable` on `self_rec`), not by
  any runtime mechanism.  Kernel test 7 is what proves the reason.

- `m4a-ese-neg.tot` (negative, gate `PASS-M4A-ESE-NEG`):

```
def eseNeg : (0 b : Bool) -> Nat := fun b => match b with | true => zero | false => zero end
```

  Expected `Kernel.Erased_use`.  VERIFIED against the current binary.

- `m4a-fording.tot` (negative, gate `PASS-M4A-FORDING`):

```
data VecP (0 A : Type 0) (0 n : Nat) : Type 0 :=
  | vpnil : VecP A zero
  | vpcons : (0 m : Nat) -> A -> VecP A m -> VecP A (succ m)
```

  Expected `Kernel.Bad_ctor`, message
  `"invalid constructor vpnil: constructor must end in VecP applied to its parameters and 0 index expression(s)"`.
  VERIFIED against the current binary except for the index-count
  suffix, which A6.3's new reason string adds.

REACHABILITY NOTE, to be carried into the SPEC entry: the
`index_expr_clean` check on index EXPRESSIONS cannot be witnessed from
source.  An index expression `e_j` must have the index telescope's own
type `T_j`.  For `e_j` to mention the family `I`, it would have to be an
application of `I`, whose type is `Univ level`;  so `T_j` would have to
be `Univ level`, whose own level is `level + 1`, which A6.1's
`Level.le l_idx level` bound rejects at declaration time.  The check is
therefore a total backstop, and kernel test 6 is its only non-vacuous
oracle.  Do NOT try to write a source fixture for it, and do NOT delete
the check.

### A16. Gate A

    (i)   The kernel and surface suites stay green with NO edits to any
          existing test term.  Baseline 167, plus your additions.
    (ii)  A recursive indexed family declares, builds a value, and runs
          (m4a-vec.tot).
    (iii) A wrong-index constructor is Bad_ctor (m4a-vec-badindex.tot).
    (iv)  The three erasure negatives still reject, each with its own
          reason: Box (w argument), SX (self-recursive), Bool (two
          constructors).
    (v)   The two subsingleton positives now check: a one-constructor
          erased family and a zero-constructor family (surface tests 22
          and 23).
    (vi)  Fording is still blocked (m4a-fording.tot).
    (vii) Additivity: every M2 and M3 match round-trips, differing only
          by the motive record wrapper (kernel test 10, plus the whole
          unchanged suite).

Markers to add to `dev/gates.sh`: `PASS-M4A-VEC`, `PASS-M4A-VEC-BADIX`,
`PASS-M4A-BOX`, `PASS-M4A-SX`, `PASS-M4A-ESE-NEG`, `PASS-M4A-FORDING`.
Write each in the file's existing capture-then-assert idiom, wrapped in
`"$watchdog" 30`, with the FAIL branch replaying the captured output and
exiting 1.  Drive the fixtures through
`dune exec --root "$ROOT" test/surface.exe -- gate-check "$ROOT"/test/fixtures/<name>`.

### A17. SPEC.md decision-log entries for Stage A

Append a dated `2026-09-02 (M4, Stage A)` block to section 2 with these
entries, each written out in full:

1. **Indexed inductive families.**  `declare_ind` takes an index
   telescope, every index binder is forced to quantity 0, and each index
   TYPE is bounded by `Level.le` against the declared level (the
   conservative bound;  the Agda-style exemption is not taken).  A
   constructor codomain must be `I p1 .. pn e1 .. em` with the `pi` the
   constructor's own parameter variables in order and each `ej` free of
   `I`.  Strict positivity generalizes the same way for argument types.
2. **The motive record.**  `Term.Match`'s motive becomes
   `{ m_ind; m_idx; m_self; m_body }`, the surface form is
   `match S as x in I y1 .. ym return P with`, index binders are scoped
   outermost first and the scrutinee binder innermost, `m_ind` is
   diagnostic only and conversion ignores it, and the M2/M3 motive is
   exactly the `m_ind = None, m_idx = []` case.  The index clause sits
   after `as x` so that a `let .. in ..` scrutinee cannot collide with
   it.
3. **The subsingleton elimination rule, with its Round-4 relaxation
   story.**  Write the three-part criterion, the two-pass stamp, and the
   full repaired soundness argument of A6.6, naming M2 fixes Round 4
   explicitly as the invariant being relaxed and Stage C as the
   executable backstop.  Record that the emptiness claim behind the
   argument is UNPROVEN and that the fence is syntactic.
4. **The Fording blockage.**  Encoding an index as a uniform parameter
   is unavailable: `vpnil : VecP A zero` fails the result-head rule and
   `vpcons : .. -> VecP A n` fails uniform positivity.  Both messages
   are pinned by `test/fixtures/m4a-fording.tot` and gate
   `PASS-M4A-FORDING`.  This is why decision 3 admits general recursive
   indexed families now rather than fencing them.
5. **The index-expression backstop is unreachable from source.**  Record
   the A15 reachability argument, and that kernel test 6 is its oracle.
6. **Debts discharged.**  The ctor-arity cache (`full_arity` retires
   `Eval.is_canonical`'s second lookup) and the builtin-former marker
   (`ctor_status.Builtin` plus `Builtin_not_eliminable`) are done here,
   not in Stage D, because the record change forces both.
7. **Cache format version 5 -> 6.**

Section 3: add `scrut_q` and the motive record to the grammar, and the
`data NAME PARAMS : IDXTELE Type L` form.  Section 4: note the
three-state `ctor_status` and the new `ind_entry.indices` /
`ctor_entry.res_idx` / `full_arity` / `self_rec` fields.  Section 6:
remove "No indexed ... inductives" from the debt list, and ADD the
conservative index-type `Level.le` bound as a new debt.

---

## STAGE B: propositional equality, the proof prelude, and axioms

Goal: `Eq` exists in the prelude with its permanent shape, the four
rewriting combinators erase to nothing worth naming, `natDecEq` runs,
and `axiom` is a fourth way to install a global that can never reach
runtime.

Files: `lib/global.ml`, `lib/error.ml`, `lib/eval.ml`, `lib/check.ml`,
`surface/token.ml`, `surface/lexer.ml`, `surface/syntax.ml`,
`surface/parser.ml`, `surface/run.ml`, `surface/bootstrap.ml`,
`surface/cache.ml`, `bin/tot.ml`, `stdlib/prelude.tot`, `test/main.ml`,
`test/surface.ml`, `test/fixtures/`, `dev/gates.sh`, `SPEC.md`.

### B1. stdlib/prelude.tot: the equality layer

APPEND these items to the END of `stdlib/prelude.tot`, after
`jsonToList`.  Appending at the end keeps `surface/bootstrap.ml`'s two
prelude split markers (`"foldNat"` and `"Json"`) valid and unmoved, and
everything below needs only `Nat`, `Bool` and `Unit`, all of which live
in segment 1.  The alternative rejected: inserting the layer in the
middle, which would move a marker and re-order the prim seeding phases
for no gain.

```
-- M4 Stage B: propositional equality.  Homogeneous Paulin-Mohring:
-- parameters are the type and the LEFT endpoint, the right endpoint is
-- the single index, and refl is the sole constructor.  Type 0 only;  a
-- Type 1 need duplicates the def.  There is no K and no UIP.
data Empty : Type 0 :=
data Eq (0 A : Type 0) (0 a : A) : (0 b : A) -> Type 0 := | refl : Eq A a a
data Dec (0 P : Type 0) : Type 0 :=
  | yes : (0 p : P) -> Dec P
  | no : (0 np : P -> Empty) -> Dec P

def exfalso : (0 A : Type 0) -> (0 e : Empty) -> A :=
  fun A e => match e with end

reducible def subst0 : (0 A : Type 0) -> (0 a : A) -> (0 b : A) ->
    (0 P : A -> Type 0) -> (0 h : Eq A a b) -> P a -> P b :=
  fun A a b P h px => match h as x in Eq y return P y with | refl => px end

reducible def J0 : (0 A : Type 0) -> (0 a : A) ->
    (0 P : (y : A) -> Eq A a y -> Type 0) ->
    P a (refl A a) -> (0 b : A) -> (0 h : Eq A a b) -> P b h :=
  fun A a P pr b h => match h as x in Eq y return P y x with | refl => pr end

reducible def sym0 : (0 A : Type 0) -> (0 a : A) -> (0 b : A) ->
    (0 h : Eq A a b) -> Eq A b a :=
  fun A a b h => subst0 A a b (fun z => Eq A z a) h (refl A a)

-- TRAP, do NOT "simplify" this to subst0 A b c (fun z => Eq A a z) h2 h1.
-- A def body checks at quantity mode w, and subst0's last argument sits
-- at a w position, so forwarding the 0-bound proof h1 there is
-- Erased_use.  The nested double match eliminates h1 INSIDE h2's refl
-- branch and returns a freshly built refl instead of forwarding a
-- binder.
reducible def trans0 : (0 A : Type 0) -> (0 a : A) -> (0 b : A) -> (0 c : A) ->
    (0 h1 : Eq A a b) -> (0 h2 : Eq A b c) -> Eq A a c :=
  fun A a b c h1 h2 =>
    match h2 as x2 in Eq y2 return Eq A a y2 with
    | refl =>
        match h1 as x1 in Eq y1 return Eq A a y1 with
        | refl => refl A a
        end
    end

reducible def cong0 : (0 A : Type 0) -> (0 B : Type 0) -> (0 a : A) -> (0 b : A) ->
    (0 f : A -> B) -> (0 h : Eq A a b) -> Eq B (f a) (f b) :=
  fun A B a b f h => subst0 A a b (fun z => Eq B (f a) (f z)) h (refl B (f a))
```

Why each of these typechecks, spelled out so a build agent can debug a
failure instead of guessing:

- `subst0`: the scrutinee `h : Eq A a b` has parameters `(A, a)` and one
  index `b`.  The motive binds the index as `y` and the scrutinee as
  `x`, and its body is `P y`.  At `refl`, the stored `res_idx` is the
  parameter `a`, so the branch body is checked at `P a`, which is
  exactly `px`'s type.  The match's own type is `P b`.
- `J0`: same, with motive body `P y x`;  at `refl` that is
  `P a (refl A a)`, which is `pr`'s type.
- `sym0` and `cong0` pass a freshly built `refl` at `subst0`'s `w`
  position, never a bound proof, so they do not trip `Erased_use`.  In
  `cong0`, `f` is a 0-binder used inside `refl B (f a)`;  `refl`'s
  second argument is a 0-parameter, so `f a` is checked at mode 0.
- `trans0`'s outer match has type `Eq A a c` and its `refl` branch is
  checked at `Eq A a b`;  the inner match supplies exactly that, with
  its own `refl` branch checked at `Eq A a a`.

Erasure consequences, which Stage C's gate walks: `subst0` erases to
`fun px => px`, the identity, so casting along an equality costs zero at
runtime.  `exfalso` erases to the erased residue.  `trans0` erases to
the bare constructor `refl`, because all six of its formals are
quantity 0.

### B2. stdlib/prelude.tot: decidable equality on Nat

APPEND after B1's block.

```
reducible def pred : Nat -> Nat :=
  fun n => match n with | zero => zero | succ p => p end
reducible def natFamZero : Nat -> Type 0 :=
  fun n => match n with | zero => Unit | succ p => Empty end
def zeroNotSucc : (0 n : Nat) -> (0 h : Eq Nat zero (succ n)) -> Empty :=
  fun n h => subst0 Nat zero (succ n) natFamZero h unit
def succInj : (0 m : Nat) -> (0 n : Nat) ->
    (0 h : Eq Nat (succ m) (succ n)) -> Eq Nat m n :=
  fun m n h => cong0 Nat Nat (succ m) (succ n) pred h

def rec natDecEq : (m : Nat) -> (n : Nat) -> Dec (Eq Nat m n) :=
  fun m n =>
    match m as mm return Dec (Eq Nat mm n) with
    | zero =>
        match n as nn return Dec (Eq Nat zero nn) with
        | zero => yes (Eq Nat zero zero) (refl Nat zero)
        | succ p => no (Eq Nat zero (succ p)) (fun h => zeroNotSucc p h)
        end
    | succ q =>
        match n as nn return Dec (Eq Nat (succ q) nn) with
        | zero => no (Eq Nat (succ q) zero)
            (fun h => zeroNotSucc q (sym0 Nat (succ q) zero h))
        | succ r =>
            match natDecEq q r as d return Dec (Eq Nat (succ q) (succ r)) with
            | yes p => yes (Eq Nat (succ q) (succ r)) (cong0 Nat Nat q r succ p)
            | no np => no (Eq Nat (succ q) (succ r)) (fun h => np (succInj q r h))
            end
        end
    end
```

Notes for the build agent:

- `zeroNotSucc` works by computation: `natFamZero zero` reduces to
  `Unit` and `natFamZero (succ n)` reduces to `Empty`, because
  `natFamZero` is `reducible` and both scrutinees are canonical.  This
  mechanism was VERIFIED on the M3 binary with a `Verdict`-shaped
  analogue, so a failure here is a Stage A or Stage B regression, not a
  design error.
- `succInj` works because `pred (succ m)` reduces to `m`.
- The totality guard accepts `natDecEq` with principal argument `m`
  (position 0): `q` is bound by the match on `m`, so it is `Smaller`,
  and the sole recursive call passes `q` at position 0.
- `Dec` has two constructors, so the match on `natDecEq q r` keeps
  `scrut_q = Many` and erases normally.  `yes` and `no` carry only
  quantity-0 arguments, so the erased body is the familiar boolean
  recursion over tags.

### B3. The axiom entry kind

**lib/global.ml.**

```ocaml
(** M4 Stage B: a postulated statement.  An [Axiom] is a [Prim] without
    a native operation: no [def], no [reducible], so conversion can
    never step into it, by the same argument SPEC section 3 makes for
    prims.  [Check] additionally refuses it at quantity mode w, so an
    axiom can never reach erased output and [tot run] never meets one. *)
type axiom_entry = { ax_ty : Term.t }  (** closed *)

type entry =
  | Def of def_entry
  | Ind of ind_entry
  | Ctor of ctor_entry
  | Prim of prim_entry
  | Axiom of axiom_entry
```

`entry_ty` gains `| Axiom a -> a.ax_ty`.  `def_of`, `ind_of`, `ctor_of`
and `prim_of` list `Axiom` explicitly and return `None`.  Add
`axiom_of` and `find_axiom` beside the existing accessors.

**lib/error.ml.**

```ocaml
| Axiom_runtime_use of string
    (** an axiom was used at quantity mode w;  axioms are proof-only *)
```

```ocaml
| Axiom_runtime_use n ->
    Printf.sprintf "axiom %s used at runtime: axioms are usable only at quantity 0" n
```

**lib/eval.ml.**  `eval`'s `Term.Global` arm gains
`| Global.Axiom _ -> Ok (Value.VNeutral (Value.HGlobal name, []))`,
the same shape as the opaque `Def` and the `Prim` arms.

**lib/check.ml.**

```ocaml
val define_axiom : Global.t -> name:string -> ty:Term.t -> (Global.t, Error.t) result
```

It runs `ensure_fresh`, then `infer_univ` on `ty` to validate and stamp
it, then stores `Axiom { ax_ty = stamped }`.

`infer`'s `Term.Global` arm gains one guard, spelled as a `match ()`
ladder beside the existing lookup: when the entry is `Global.Axiom _`
and `Quantity.equal mode Quantity.Many`, the result is
`Error (Error.Axiom_runtime_use name)`.  At mode `Zero` it is the
ordinary neutral with its stored type.

That single guard is the whole confinement.  Axioms can never flow into
erased output, so a stuck axiom at runtime is unrepresentable rather
than merely unlikely.

### B4. The `axiom` surface item

**surface/token.ml and lexer.ml**: one new keyword, `KAxiom`, described
as `"'axiom'"`.

The keyword is `axiom`, not `postulate`, so that the surface form, the
`Global.Axiom` entry kind, the `Axiom_runtime_use` error and the
`--no-axioms` flag all use one word.  The alternative rejected: a
`postulate` keyword paired with an `Axiom` entry and a `--no-axioms`
flag, which is a three-way naming split for no benefit.

**surface/syntax.ml**:

```ocaml
| IAxiom of {
    loc : Loc.t;
    name : string;
    ty : t;
  }
```

**surface/parser.ml**: `parse_items` gains an arm for
`Token.KAxiom :: Ident name :: Colon :: rest`, parsing one term as the
type.  `parse_ctors`'s "next item keyword" stop set gains `KAxiom`.

**surface/run.ml**: a `policy` record and an `IAxiom` arm.

```ocaml
type policy = { no_axioms : bool }

let default_policy : policy = { no_axioms = false }
```

`Run.item` becomes `exec:bool -> policy:policy -> state -> Syntax.item -> ...`
and `Run.script` becomes
`?st:state -> ?policy:policy -> exec:bool -> string -> ...` with
`default_policy` as the default, so every existing test call site is
unchanged.  `Bootstrap.fold_items` passes `~policy:default_policy`.

The `IAxiom` arm elaborates the type, then:

- when `policy.no_axioms` is set, `Error (Serror.Axioms_disabled { loc; name })`;
- otherwise `Check.define_axiom`, and the echo line
  `Printf.sprintf "axiom %s : %s" name (Pp.term [] ty_t)`.

It NEVER calls `Interp.define`.  An axiom has no runtime entry at all;
if one ever reached `Interp.exec`, the existing `Unbound_global`
backstop fires, and test B9 pins that.

**surface/serror.ml**:

```ocaml
| Axioms_disabled of {
    loc : Loc.t;
    name : string;
  }  (** an axiom item under --no-axioms *)
```

```ocaml
| Axioms_disabled { loc; name } ->
    Printf.sprintf "%s: axiom %s rejected: this installation runs with --no-axioms"
      (Loc.to_string loc) name
```

tag `"Axioms_disabled"`.  Installation POLICY lives in `Serror`, not in
the kernel `Error`, because the kernel has no notion of an installation.
The alternative rejected: a kernel error variant, which would put a
driver flag inside the trusted base.

### B5. bin/tot.ml: a real flag parser

The current argv handling is a literal positional match, which cannot
absorb a second optional flag without a combinatorial blow-up.  Replace
it with a small total parser.

```ocaml
type opts = {
  no_prelude : bool;
  no_axioms : bool;
}

let default_opts : opts = { no_prelude = false; no_axioms = false }

(** Consume leading flags;  the first non-flag argument ends the scan.
    A leading "--" that is not a known flag is an error, so a typo can
    never be read as a file name. *)
let rec parse_flags (opts : opts) (args : string list) :
    (opts * string list, string) result =
  match args with
  | "--no-prelude" :: rest -> parse_flags { opts with no_prelude = true } rest
  | "--no-axioms" :: rest -> parse_flags { opts with no_axioms = true } rest
  | a :: _rest when String.length a >= 2 && String.equal (String.sub a 0 2) "--" ->
      Error ("unknown flag: " ^ a)
  | ([] | _ :: _) -> Ok (opts, args)
```

`let ()` becomes: match on `_exe :: verb :: rest`, run `parse_flags` on
`rest`, require exactly one remaining positional path, and dispatch on
the verb (`"check"`, `"run"`, `"prims"`).  Usage text becomes
`usage: tot (check|run) [--no-prelude] [--no-axioms] FILE | tot prims`.
Keep the exit-2 usage path and its existing gate `PASS-C-ARGV-USAGE`
green;  that gate asserts the exit code and the message shape, so read
it before you edit and keep both.

Stage D EXTENDS `opts` with `require_main` and `serror_exit`.  Do not
add them now.

### B6. Monad-law axioms

APPEND to `stdlib/prelude.tot`, after B2's block.

```
-- M4 Stage B: the monad laws are invisible to conversion by design
-- (liftIO (pureDiv x) and pureIO x are different neutrals), so they are
-- POSTULATED.  Consistency argument: IO and Div are declared-only,
-- zero-constructor type formers, so no internal predicate can
-- eliminate an IO or Div value and therefore none can distinguish the
-- action trees these axioms equate.  Every use sits under an erased
-- application and is dropped wholesale by erasure.
axiom ioBindPure : (0 A : Type 0) -> (0 B : Type 0) -> (0 a : A) ->
  (0 f : A -> IO B) -> Eq (IO B) (bindIO A B (pureIO A a) f) (f a)
axiom ioBindRet : (0 A : Type 0) -> (0 m : IO A) ->
  Eq (IO A) (bindIO A A m (fun a => pureIO A a)) m
axiom ioBindAssoc : (0 A : Type 0) -> (0 B : Type 0) -> (0 C : Type 0) ->
  (0 m : IO A) -> (0 f : A -> IO B) -> (0 g : B -> IO C) ->
  Eq (IO C) (bindIO B C (bindIO A B m f) g)
            (bindIO A C m (fun a => bindIO B C (f a) g))
```

TRAP: `Eq` is at `Type 0` only, and `IO B : Type 0`, so these
statements are well formed.  If a level error appears, the cause is
`Eq`'s parameter `(0 A : Type 0)`, not the axiom.

TRAP: `--no-axioms` must NOT reject the PRELUDE's own axioms, or every
hook installation loses its prelude.  `Bootstrap.fold_items` passes
`default_policy`, so the flag applies to the USER file only.  Say this
in the `IAxiom` arm's comment and pin it with gate
`PASS-M4B-NOAXIOMS`.

### B7. surface/cache.ml

Bump `format_version` from 6 to 7.  Append the checklist entry naming
`Global.entry`'s new `Axiom` constructor.

### B8. Stage B tests

`test/main.ml` (kernel), labels `B<n>:`:

1. `B1: define_axiom installs an opaque global`.  Install
   `ax : Nat` and assert `Eval.eval` of `Term.Global "ax"` is a
   `VNeutral (HGlobal "ax", [])`, and that `ax` is not convertible with
   `zero`.
2. `B2: an axiom at mode w is Axiom_runtime_use`.  `Check.infer` at
   `Quantity.Many` on `Term.Global "ax"`.  Pin the tag and print the
   message.  Then infer the same term at `Quantity.Zero` and assert it
   succeeds with the stored type.
3. `B3: define_axiom rejects a duplicate name`.  Pin
   `Duplicate_global`.
4. `B4: an axiom is not a def, an ind, a ctor, or a prim`.  Assert all
   four accessors return `None` and `entry_ty` returns the stored type.

`test/surface.ml`, labels `B<n>:` continuing the same numbering:

5. `B5: the Eq layer checks under the bootstrapped prelude`.
   `expect_lines_check ~st:bst` on `check subst0` and `check trans0`,
   pinning the exact printed types.
6. `B6: subst0 erases to the identity`.  Use the CLI path with
   `expect_cli_run_lines` over `test/fixtures/m4b-subst-erases.tot`.
7. `B7: natDecEq computes`.  `expect_lines ~st:bst` on
   `eval natDecEq (succ (succ zero)) (succ (succ zero))` and on
   `eval natDecEq (succ zero) (succ (succ zero))`, pinning the two
   readbacks exactly (read what the binary prints for a `yes`/`no`
   value;  do not guess the spelling).
8. `B8: a Dec scrutinee drives a Bool`.  `expect_lines ~st:bst` on the
   `sameArity` def of `m4b-deceq-runs.tot`, pinning `true`.
9. `B9: an axiom item echoes and never enters the runtime`.
   `expect_lines_check` on
   `axiom myAx : Eq Nat zero zero` pinning
   `axiom myAx : (Eq Nat zero zero)`, then `expect_err` on
   `eval myAx` with tag `Kernel.Axiom_runtime_use`.
10. `B10: an axiom under --no-axioms is Axioms_disabled`.  Call
    `Run.script ~policy:{ no_axioms = true }` on the same source and pin
    the tag.
11. `B11: trans0 must not regress to the single-match shape`.  Feed the
    BROKEN spelling
    `fun A a b c h1 h2 => subst0 A b c (fun z => Eq A a z) h2 h1`
    as a user def and pin `Kernel.Erased_use`.  This is the oracle that
    keeps the nested double match from being "simplified" away.

### B9. Stage B fixtures

- `m4b-subst-erases.tot` (positive, gate `PASS-M4B-SUBST`):

```
def symNat : (0 m : Nat) -> (0 n : Nat) -> (0 h : Eq Nat m n) -> Eq Nat n m :=
  fun m n h => subst0 Nat m n (fun z => Eq Nat z m) h (refl Nat m)
check symNat
def castNat : (0 P : Nat -> Type 0) -> (0 a : Nat) -> (0 b : Nat) ->
    (0 h : Eq Nat a b) -> P a -> P b :=
  fun P a b h px => subst0 Nat a b P h px
check castNat
```

- `m4b-deceq-runs.tot` (positive, gate `PASS-M4B-DECEQ`):

```
def sameArity : Bool :=
  match natDecEq (succ zero) (succ zero) with
  | yes p => true
  | no np => false
  end
eval sameArity
```

  Pins the exact output line `true`.

- `m4b-noaxioms.tot` (negative, gate `PASS-M4B-NOAXIOMS`):

```
axiom bogus : Eq Nat zero (succ zero)
check bogus
```

  Run twice: without the flag it checks and exits 0;  with
  `--no-axioms` it exits 1 with `Axioms_disabled` on stderr.  Both
  halves are asserted, because the flag's whole point is the
  difference.

### B10. Gate B

    (i)   The prelude folds with the Eq layer, the Nat decidable
          equality layer and the three monad-law axioms present, cold
          and warm cache alike.
    (ii)  subst0 erases to the identity and castNat checks
          (m4b-subst-erases.tot).
    (iii) natDecEq computes both a yes and a no, and sameArity runs
          (m4b-deceq-runs.tot).
    (iv)  An axiom is rejected at mode w and accepted at mode 0
          (kernel test 2, surface test 9).
    (v)   --no-axioms rejects a user axiom and still folds the prelude
          (m4b-noaxioms.tot).
    (vi)  The broken single-match trans0 is still Erased_use (surface
          test 11).

Markers: `PASS-M4B-SUBST`, `PASS-M4B-DECEQ`, `PASS-M4B-AXIOM`,
`PASS-M4B-NOAXIOMS`.

### B11. SPEC.md decision-log entries for Stage B

Append a dated `2026-09-02 (M4, Stage B)` block:

1. **Equality's permanent shape (user decision 6), written out in
   full**: homogeneous Paulin-Mohring, an ordinary `data`, parameters
   `(0 A)` and the left endpoint, ONE index, sole constructor `refl`,
   `Type 0` only with per-level duplicates when needed, `J` is the match
   itself reducing by ordinary iota, K and UIP deliberately absent, and
   no `rewrite` surface form because motive selection needs a
   metavariable engine that tot does not have.  Rewriting is `subst0`,
   `sym0`, `trans0` and `cong0`.
2. **`trans0` uses a nested double match.**  Record the reason: a def
   body checks at quantity mode `w`, `subst0`'s transported argument
   sits at a `w` position, so forwarding a 0-bound proof there is
   `Erased_use`.  Name surface test 11 as the regression oracle.
3. **The `axiom` entry kind and its consistency note.**  A fifth
   `Global.entry` kind with no `def` and no `reducible`, usable only at
   quantity mode 0, installed by `Check.define_axiom`, never given an
   `Interp` entry.  Consistency argument: `IO` and `Div` are
   declared-only zero-constructor formers, so no internal predicate can
   eliminate their values and none can distinguish the action trees the
   monad-law axioms equate.  Add the `--no-axioms` installation flag and
   record that it applies to the USER file only, never to the prelude.
4. **Cache format version 6 -> 7.**

Section 3: add the `axiom NAME : TYPE` item to the surface-items list.
Section 4: add `Axiom` to the `Global` entry-kind list.  Section 6:
remove the monad-law debt ("M4 propositional equality can postulate
them"), and ADD the `Eq`-at-`Type 0` monomorphism debt (a `Type 1` need
duplicates `subst0`).

---

## STAGE C: the executable erasure backstop

Goal: the Round-4 invariant that Stage A relaxed becomes executable
rather than assumed.  This stage is deliberately small and deliberately
REVERTIBLE on its own: if the analysis is wrong, reverting Stage C
leaves proofs correct and costs `subst0` one nullary match instead of
zero.

Files: `lib/eterm.ml`, `lib/interp.ml`, `surface/run.ml`,
`surface/cache.ml`, `test/main.ml`, `test/surface.ml`,
`test/fixtures/`, `dev/gates.sh`, `SPEC.md`.

### C1. lib/eterm.ml

Promote the walk that `test/main.ml`'s `T0` case currently keeps
private:

```ocaml
(** Does [name] occur anywhere in [e] as an [EGlobal]?  Structural,
    total, exhaustive over every [Eterm.t] arm.  [surface/run.ml] runs
    it on an erased body to decide the runtime guard (M4 Stage C). *)
let rec mentions (name : string) (e : t) : bool =
  match e with
  | EVar _ -> false
  | ELit _ -> false
  | EErased -> false
  | EGlobal g -> String.equal g name
  | ELam (_x, b) -> mentions name b
  | EApp (f, a) -> mentions name f || mentions name a
  | ELet (_x, d, b) -> mentions name d || mentions name b
  | EMatch (s, branches) ->
      mentions name s || List.exists (fun (_c, _bs, b) -> mentions name b) branches
```

`test/main.ml`'s `T0` case must then CALL `Eterm.mentions` instead of
its private copy, so the promotion is proven by the existing test rather
than merely asserted.

### C2. lib/interp.ml

```ocaml
(** M4 Stage C: the runtime unfolding guard, three-state.
    [Unguarded] and [GuardedAt] are the M2-fixes behaviors.  [Frozen]
    NEVER unfolds: the global stays an [EHGlobal] neutral under any
    application.  [Frozen] is reachable only through an inhabitant of a
    provably empty type, so it is dead code by the Stage A soundness
    argument;  it exists so that a missed case degrades to a permanent
    neutral instead of a loop. *)
type guard =
  | Unguarded
  | GuardedAt of int
  | Frozen
```

`gentry` replaces `grec_arg : int option` with `gguard : guard`.
`Interp.define` replaces `~rec_arg:int option` with `~guard:guard`.
`add_ctor`, `add_erased` and `add_prim` store `gguard = Unguarded`.

`exec`'s `EGlobal` arm:

```ocaml
      (match g.gguard with
      | Unguarded -> force eglobals g.gval
      | GuardedAt _k -> Ok (VNeut (EHGlobal name, []))
      | Frozen -> Ok (VNeut (EHGlobal name, [])))
```

`apply`'s `EHGlobal` arm keeps its structure and dispatches on the
guard:

- `GuardedAt k`: the existing `leading_fapp_args` / `is_canonical`
  test, verbatim.
- `Frozen`: `Ok stuck`, always.  One comment naming the emptiness
  argument.
- `Unguarded`: `Ok stuck`, a total backstop.  An `Unguarded` entry is
  forced at `exec` time and therefore never births an `EHGlobal`
  neutral, so this arm is unreachable;  spell it out anyway, because
  the match must be exhaustive.

`quote` and `run_match` are untouched: a `Frozen` global reads back as
its neutral application, which is exactly the M2-fixes readback the rec
guard already produces.

### C3. surface/run.ml

Replace `remap_rec_arg` with `compute_guard`, keeping the old function's
doc comment and extending it.

```ocaml
(** Turn the kernel's [rec_arg] (an index into the UNERASED formal
    telescope) into the runtime guard (an index into the ERASED spine).
    The [Many] case is M2 fixes Round 2's remap, verbatim.  The [Zero]
    case is M2 fixes Round 4's rule made EXECUTABLE: when the guarded
    formal is erased the runtime spine never carries it, so there is no
    principal position left to test.  Round 4 argued that such a def's
    erased body cannot mention its own name, and therefore unfolds
    eagerly without looping.  M4 Stage A relaxed the invariant that
    argument rested on, so we no longer assume it: we RUN
    [Eterm.mentions] on the erased body.  No mention gives [Unguarded],
    the Round 4 behavior and the only live case.  A mention gives
    [Frozen], a permanent neutral, dead code by the emptiness argument
    in SPEC's Stage A entry. *)
let compute_guard ~(name : string) (def : Term.t) (rec_arg : int option)
    (def_e : Eterm.t) : Interp.guard =
  let qs = lam_quantities def in
  rec_arg
  |> Option.fold ~none:Interp.Unguarded ~some:(fun k ->
         List.nth_opt qs k
         |> Option.fold ~none:Interp.Unguarded ~some:(fun q ->
                match q with
                | Quantity.Many ->
                    Interp.GuardedAt
                      (List.length
                         (List.filteri
                            (fun ix q' -> ix < k && Quantity.equal q' Quantity.Many)
                            qs))
                | Quantity.Zero ->
                    (match () with
                    | () when Eterm.mentions name def_e -> Interp.Frozen
                    | () -> Interp.Unguarded)))
```

An out-of-range `k` still falls to `Unguarded` through `List.nth_opt`,
exactly as it fell to `None` before.  The single `Interp.define` call
site (the `IDef` arm's run-mode branch) passes
`~guard:(compute_guard ~name dentry.Global.def dentry.Global.rec_arg def_e)`.

### C4. surface/cache.ml

Bump `format_version` from 7 to 8.  Checklist entry: `Interp.gentry`'s
`grec_arg` becomes `gguard`, a three-state sum.

### C5. Stage C tests and fixtures

`test/main.ml`, labels `C<n>:`:

1. `C1: Eterm.mentions is exhaustive and correct`.  Assert `true` on an
   `EGlobal` buried under `ELam`, `EApp`, `ELet` and an `EMatch` branch,
   and `false` on a term of the same shape with a different name.
2. `C2: the existing T0 case now calls Eterm.mentions`.  Rewrite the
   T0 case to use the promoted function.  Keep its label byte-for-byte,
   because `dev/gates.sh` matches it with an anchored pattern.
3. `C3: a Frozen global stays neutral under application`.  Seed an
   `Interp.globals` by hand with `~guard:Interp.Frozen` over a body that
   would loop if unfolded, apply it to a canonical constructor value,
   and assert the result quotes back to the frozen spine rather than
   diverging.  Run it under the suite's own watchdog-free path;  the
   assertion is that it RETURNS, and the gate's watchdog is the
   fail-safe.

`test/surface.ml`, labels `C<n>:`:

4. `C4: subst0's erased body has no self-reference`.  Erase the prelude's
   `subst0` and assert `Eterm.mentions "subst0"` is `false`, and that
   its printed erased form is exactly `fun px => px`.
5. `C5: the s0-erased-guard fixture still runs Unguarded`.  The existing
   `s0-erased-guard.tot` case must still pass unchanged, and a new
   assertion pins that `compute_guard` returns `Unguarded` for its
   `ghost` def.  This is the "only live case" claim, made falsifiable.

New fixture `m4c-frozen.tot` (gate `PASS-M4C-FROZEN`): a script that
exercises the `subst0` erasure path end to end under `tot run` and
prints one pinned line.  The gate wraps it in `"$watchdog" 10` and
requires exit 0;  a regression that reintroduces the divergence shows up
as exit 124.

### C6. Gate C

    (i)   The full suite is green at the Stage B number plus Stage C's
          additions.
    (ii)  subst0 erases to `fun px => px` and mentions nothing
          (surface test 4).
    (iii) A Frozen global applied to a canonical argument returns a
          neutral instead of looping (kernel test 3).
    (iv)  The erased-guard fixture still runs, and its guard is proven
          to be Unguarded (surface test 5).
    (v)   m4c-frozen.tot runs to completion under a 10 second watchdog.

Markers: `PASS-M4C-FROZEN`, `PASS-M4C-SUBST-IDENTITY`.

### C7. SPEC.md decision-log entries for Stage C

Append a dated `2026-09-02 (M4, Stage C)` block:

1. **The `Frozen` backstop.**  `Interp`'s runtime guard becomes
   `Unguarded | GuardedAt of int | Frozen`.  `surface/run.ml` runs
   `Eterm.mentions` on the erased body when the guarded formal is
   erased: no mention gives `Unguarded` (M2 fixes Round 4's behavior,
   the only live case), a mention gives `Frozen`, a permanent neutral.
   The Round 4 invariant is now EXECUTABLE, not assumed.
2. **The emptiness claim stays UNPROVEN.**  Record it plainly: the
   fence is syntactic (`self_rec = false`), the backstop is executable,
   and the claim that a self-recursive all-erased family is empty is not
   proved.  Nothing load-bearing rests on it.  Revisit if mutual or
   nested inductives ever land.
3. **`Eterm.mentions` is promoted** from a test-private walk to a kernel
   function, and the T0 test now calls it.
4. **Cache format version 7 -> 8.**

---

## STAGE D: deterministic type classes and the driver debts

Goal: `member String auto cmd flagged` typechecks, resolves, and runs;
the class layer replaces the `intCompare` special case;  and the four
remaining M3 driver debts close.

Files: `lib/term.ml` (no change, `Auto` landed in Stage A),
`lib/check.ml`, `lib/error.ml`, `surface/token.ml`, `surface/lexer.ml`,
`surface/syntax.ml`, `surface/parser.ml`, `surface/elab.ml`,
`surface/run.ml`, `surface/cache.ml`, `bin/tot.ml`,
`stdlib/prelude.tot`, `examples/`, `test/main.ml`, `test/surface.ml`,
`test/fixtures/`, `dev/gates.sh`, `SPEC.md`, `README.md`.

### D1. lib/error.ml

```ocaml
| Inst_unresolved of string
    (** no instance for this expected type;  payload is the printed type *)
| Inst_bad_shape of {
    name : string;
    reason : string;
  }  (** an instance whose type does not fit the registration shape *)
| Inst_depth of string
    (** instance resolution ran out of fuel;  payload is the printed type *)
```

```ocaml
| Inst_unresolved s -> Printf.sprintf "no instance found for %s" s
| Inst_bad_shape { name; reason } -> Printf.sprintf "instance %s: %s" name reason
| Inst_depth s -> Printf.sprintf "instance resolution for %s exceeded its fuel" s
```

The registration head-shape check reports through `Inst_bad_shape`
rather than through a separate variant, because both fire at the same
site with the same payload and the reason string carries the detail.
The alternative rejected: a fourth `Instance_head_shape` variant, which
adds a tag with no diagnostic value.

### D2. lib/check.ml: `Auto` resolution and `define_instance`

**The rule.**  `check globals ctx mode Term.Auto expected`:

1. `expected` must be `Value.VInd (cls, [ av ])`, a class applied to
   exactly one type.  Any other shape is `Inst_unresolved` with the
   printed expected type.
2. The KEY is the head symbol of `av`: `Value.VInd (k, _ts)` gives `k`.
   Every other value shape (`VPi`, `VUniv`, `VNeutral`, `VLam`,
   `VCtor`, `VLit`) is `Inst_unresolved`.  There are no instances for
   type variables and none for function types;  polymorphic code takes
   the dictionary as an explicit argument, which is the standard move
   and the reason G4's `inst` escape hatch exists.
3. Look up the def named `"inst$" ^ cls ^ "$" ^ k`.  Absent is
   `Inst_unresolved`.  The `$` character is unlexable, so a user can
   never collide with the mangled namespace.
4. Build a candidate TERM by peeling the instance's stored type:

```ocaml
(** Peel the instance's Pi telescope, filling type arguments
    positionally from the key's own arguments and recursing on
    dictionary domains.  [fuel] is a belt over the structural
    termination argument: each dictionary recursion descends into a
    strict subvalue of the query, so the walk terminates anyway. *)
let rec build_instance (globals : Global.t) (ctx : ctx) (fuel : int)
    (ity : Value.t) (targs : Value.t list) (acc : Term.t) :
    (Term.t, Error.t) result
```

   Arms, in order:
   - `fuel <= 0` gives `Inst_depth` with the printed expected type.
   - `ity = Value.VPi (q, _x, Value.VUniv _, clo)`: consume the next
     `t_i` from `targs`, `arg_t = Eval.quote globals ctx.size t_i`,
     `acc' = Term.App (q, acc, arg_t)`, recurse on
     `Eval.app_closure globals clo t_i` with the tail of `targs`.  An
     empty `targs` here is `Inst_bad_shape`.
   - `ity = Value.VPi (q, _x, Value.VInd (cls_j, [ dv ]), clo)`:
     recursively resolve a sub-instance for `cls_j` at `dv` (which is a
     strict subvalue of `av`, so the recursion is structural and
     total), giving `sub : Term.t`;  set
     `acc' = Term.App (q, acc, sub)`, evaluate `sub` and recurse on
     `Eval.app_closure globals clo sub_v`.
   - any other `Value.VPi` domain is `Inst_bad_shape`.
   - a non-`VPi` `ity` is the codomain: `Ok acc`.
5. Initial fuel is the syntactic node count of the quoted expected type.
   Write `term_size : Term.t -> int` as a small total function in
   `check.ml`.
6. `check globals ctx mode candidate expected`.  The checker stamps and
   conv-verifies the candidate, so a malformed table entry fails loudly
   instead of resolving wrongly.

Resolution is a total function of the expected type VALUE: no search, no
backtracking, no user-visible nondeterminism.  It lives in `Check`
because only the checker knows the expected type;  `Elab` has no types
by design, so resolution in `Elab` was never on the table.

**`define_instance`.**

```ocaml
val define_instance :
  Global.t -> name:string -> ty:Term.t -> def:Term.t -> (Global.t, Error.t) result
```

It runs `define ~reducible:true globals ~name ~ty ~def` and, BEFORE
that, validates the shape of the STAMPED type:

- Peel the leading Pi binders.  Each domain is either `Univ _` (a type
  binder) or `C_j [Var j]` where `C_j` is an inductive with exactly one
  parameter and no indices and `Var j` points at an earlier type binder.
- The codomain is `C (K a1 .. ak)`, where `C` is an inductive with one
  parameter and no indices, `K` is an inductive with exactly `k`
  parameters and no indices, and `a1 .. ak` are the type binders in
  order.
- The ground case is `k = 0`: the codomain is `C K` with `K` a nullary
  inductive.  A ground instance at an APPLIED key (for example
  `EqD (List Int)` with no type binders) is `Inst_bad_shape`, so every
  key has exactly ONE derivation route.
- Recompute `"inst$" ^ C ^ "$" ^ K` from the CHECKED type and require it
  to equal `~name`, else `Inst_bad_shape`.  This closes the gap between
  a name computed from the surface spelling and the real type.

Instances are forced `reducible = true`: they are small constructor
values, and proofs about method calls want them to compute.

Coherence is `ensure_fresh` inside `define`: a second instance at the
same key is `Duplicate_global "inst$EqD$Int"`, deterministically, at
definition time.  There is NO new kernel state for classes.  The
instance table IS the flat global namespace.

**Quantities and erasure.**  Dictionaries are quantity-`w` constructor
values carrying the method functions.  Type arguments in the resolved
application are 0-stamped by the instance's own Pi.  `Auto` itself never
reaches erasure, because checker output contains only the resolved
application.  Nothing in `Eval`, `Erase`, `Eterm` or `Interp` knows that
classes exist.

### D3. Surface: `class`, `instance`, `auto`, `inst`

**New keywords**: `KClass`, `KInstance`, `KAuto`, `KInst`, described as
`"'class'"`, `"'instance'"`, `"'auto'"`, `"'inst'"`.

**`auto`** is an atom: `Syntax.SAuto of Loc.t`, elaborating to
`Term.Auto`.

**`inst C T`** is pure sugar, and this is the whole implementation:

```ocaml
| Syntax.SInst (_loc, c, t) ->
    let* c_t = term globals scope c in
    let* t_t = term globals scope t in
    Ok (Term.Ann (Term.Auto, Term.App (Quantity.Many, c_t, t_t)))
```

An annotated `Auto` IS the escape hatch: `Ann` steers checking and is
dropped from checker output, and `check`'s existing `Ann` path already
routes to `check globals ctx mode Auto ty_v`.  No new kernel rule, no
new core constructor.  Record this as a plan-level simplification;  the
alternative rejected was a dedicated `Term.Inst` constructor, which
would have added a second dead arm to every kernel walk for no gain.

**`class`**:

```
class NAME (0 A : Type L) := { m1 : T1 ; .. ; mn : Tn }
```

`Syntax.IClass of { loc; name; param : string * t; methods : (string * t) list }`.

`Run.item` (which becomes `let rec item`) expands an `IClass` into
these `Syntax.item` values and folds them through `Run.item` itself:

- `IData { name; params = [ (A, Type L) ]; level = L; ctors = [ ("mk" ^ name, T1 -> .. -> Tn -> name A) ] }`
- for each `i`, an `IDef` named `mi` with type
  `(0 A : Type L) -> name A -> Ti` and body
  `fun A d => match d with | mk<name> x1 .. xn => xi end`.

The constructor name is `"mk" ^ name`, uniformly.  That gives `mkEqD`,
`mkOrdD` and `mkShowD`.  Item-level sugar lives in `Run.item`, not in
`Elab`, because `Elab` is term-level by design and the expansion needs
to produce several ITEMS.  The alternative rejected: making
`Parser.parse` return a flattened item list, which spreads the
desugaring across the parser's recursion.

**`instance`**:

```
instance : TY := TERM
```

`Syntax.IInstance of { loc; ty : t; def : t }`.  `Run.item` walks the
parsed codomain spine of `TY`, requires the shape `C (K ..)` or `C K`
with `C` and `K` identifiers, builds the mangled name, elaborates `ty`
and `def`, and calls `Check.define_instance`.  A codomain that is not of
that shape is
`Serror.Parse { loc; msg = "instance type must end in CLASS (KEY ..)" }`.

The instance body is an ORDINARY term, not a record literal.  A
parametric instance is a function, and a record literal cannot express
one without a second form.  The alternative rejected: shipping two
instance body forms, one record and one term.

`Bootstrap.item_name` gains arms for `IClass` (the class name),
`IInstance` (the mangled name) and `IAxiom` (the axiom name).
`parse_ctors`'s stop set gains `KClass` and `KInstance`.

### D4. stdlib/prelude.tot: the class layer

APPEND at the END of the prelude, after Stage B's blocks.  Every prim
these defs use (`stringEq`, `intEq`, `intCompare`, `intToString`) is
seeded by phase 2 or phase 3, and the tail of the prelude is folded
after phase 3, so no split marker moves.

```
-- M4 Stage D: deterministic single-parameter type classes.  A class is
-- a single-constructor dictionary data type plus projection defs;  an
-- instance is an ordinary global under a mangled name, and coherence is
-- Duplicate_global on that name.  Daily call sites write "auto".
def rec anyList : (0 A : Type 0) -> (A -> Bool) -> List A -> Bool :=
  fun A p xs => match xs with | nil => false | cons h t => orb (p h) (anyList A p t) end
reducible def boolEq : Bool -> Bool -> Bool :=
  fun a b =>
    match a as x return Bool with
    | true => match b as y return Bool with | true => true | false => false end
    | false => match b as y return Bool with | true => false | false => true end
    end
def rec listEqBy : (0 A : Type 0) -> (A -> A -> Bool) -> List A -> List A -> Bool :=
  fun A f xs ys =>
    match xs as xx return Bool with
    | nil => match ys as yy return Bool with | nil => true | cons h2 t2 => false end
    | cons h1 t1 =>
        match ys as yy return Bool with
        | nil => false
        | cons h2 t2 => andb (f h1 h2) (listEqBy A f t1 t2)
        end
    end

class EqD (0 A : Type 0) := { eqf : A -> A -> Bool }
class OrdD (0 A : Type 0) := { cmpf : A -> A -> Ordering }
class ShowD (0 A : Type 0) := { showf : A -> String }

instance : EqD Int := mkEqD Int intEq
instance : EqD String := mkEqD String stringEq
instance : EqD Bool := mkEqD Bool boolEq
instance : OrdD Int := mkOrdD Int intCompare
instance : ShowD Int := mkShowD Int intToString
instance : (0 A : Type 0) -> EqD A -> EqD (List A) :=
  fun A d => mkEqD (List A) (listEqBy A (eqf A d))

def member : (0 A : Type 0) -> EqD A -> A -> List A -> Bool :=
  fun A d x xs => anyList A (eqf A d x) xs
```

VERIFIED on the M3 binary: `anyList`, `boolEq`, `listEqBy`, `member`,
the three dictionary data types, the three projections and all six
instance bodies typecheck and run TODAY with the dictionaries written by
hand and passed explicitly.  `eval` of `member String <dict> "sed"
flagged` printed `true` and `member String <dict> "rg" flagged` printed
`false`, and the `List` instance resolved a nested `EqD (List String)`
query by hand.  So a Stage D failure in this block is a failure of the
`class` / `instance` / `auto` sugar, not of the underlying defs.

`boolEq` is written as a nested match rather than as `not b` on purpose:
`not` is opaque, so a `not`-based `boolEq` would not compute during
conversion.  VERIFIED: the nested form does compute
(`famB (boolEq true true)` converts to `Nat`).

### D5. The driver debts

**D5.1 `--serror-exit N` (user decision 4).**  Extend `bin/tot.ml`'s
`opts` with `serror_exit : int`, default 1, and `parse_flags` with

```ocaml
  | "--serror-exit" :: n :: rest ->
      int_of_string_opt n
      |> Option.fold
           ~none:(Error ("--serror-exit expects an integer 0..255, got " ^ n))
           ~some:(fun v ->
             match () with
             | () when v < 0 || v > 255 ->
                 Error ("--serror-exit out of range 0..255: " ^ n)
             | () -> parse_flags { opts with serror_exit = v } rest)
```

Every script-level `Serror` exit site in `bin/tot.ml` returns
`opts.serror_exit` instead of the literal 1: the missing-file branch,
the `Run.script` error branch, and the bootstrap-failure branch.  The
DEFAULT stays 1 this milestone.  Flipping it to 3 is a separate,
later change, made only after installed guards are migrated;  an
unconditional flip now would change the production behavior of every
deployed guard the day it is rebuilt.

**D5.2 `--require-main`.**  Extend `opts` with `require_main : bool` and
`Run.policy` with the same field.  In `Run.main_epilogue`, when
`policy.require_main` is set and `Global.find "main" final.globals` is
`None`, the result is `Error (Serror.Missing_main)`.  New `Serror.t`
variant:

```ocaml
| Missing_main
    (** --require-main was given and the script defines no main *)
```

```ocaml
| Missing_main -> "this file must define a driver main, and it does not"
```

tag `"Missing_main"`.  This closes the "misspelled main is a silent
permit-all" residual: a hook installation adds `--require-main` to its
shebang wrapper and a typo becomes an error instead of an exit 0.  The
existing `PASS-D-MAIN-MISSPELLED` gate keeps pinning the WITHOUT-flag
behavior;  add a twin gate for the WITH-flag behavior.

**D5.3 The stat-identity cache fast path.**  `surface/cache.ml` computes
`Digest.file Sys.executable_name` once per process, which measured
~3.3ms of an ~8ms warm-hit startup.  Replace the exe identity with a
`Unix.stat`-derived string,

```ocaml
Printf.sprintf "%d:%d:%.6f:%d" st.Unix.st_dev st.Unix.st_ino st.Unix.st_mtime
  st.Unix.st_size
```

hashed to the existing fixed header width with `Digest.string`, and keep
`Digest.file` as the fallback when `Unix.stat` fails.  `unix` is already
in `surface/dune`, so no dune change is needed.  The correctness fence
is unchanged in kind: only a binary with the same device, inode, mtime
and size ever reads a blob, and dune writes a NEW inode on every build.
Bump `format_version` from 8 to 9, because the header field changes
MEANING.  The existing cache gates (`PASS-D-CACHE-HIT`,
`PASS-D-CACHE-MISS`, `PASS-D-CACHE-BODYTRUNC`, `PASS-D-CACHE-CORRUPT`,
`PASS-D-CACHE-MAGIC`, `PASS-CACHE-NOEXEDIGEST`) must all stay green;
read `PASS-CACHE-NOEXEDIGEST` before editing, since it exercises the
failure path this change reroutes.

**D5.4 The flag-pair sum type.**  `Syntax.IDef`'s `(rec_, partial)` bool
pair becomes

```ocaml
type defkind =
  | DNonRec
  | DRec
  | DRecPartial
```

making the illegal `partial = true, rec_ = false` state
unrepresentable.  `parse_def` produces the sum directly, and
`Run.item`'s `IDef` arm consumes it with an exhaustive match, passing
`~rec_` and `~partial` on to `Check.define` (whose optional-argument
signature is unchanged;  the kernel keeps its two booleans, because
`Global.def_entry.partial` is marshaled and this stage must not touch
the cache shape twice).

**D5.5 Debts discharged in Stage A.**  The ctor-arity cache and the
builtin-former marker are already done (A4, A5).  Do not look for them
here;  confirm them in the SPEC entry instead.

### D6. The dogfood example

New `examples/guard-classes.tot`, a shebang script in the shape of
`examples/guard.tot`, using the class layer and a proof.

```
#!/usr/bin/env -S tot run
-- M4 Stage D: the house rg/sd rule again, this time with the flagged
-- command list behind a type class and with two guard predicates proven
-- to agree on the true case.
reducible def verdictOfDanger : Bool -> Verdict :=
  fun b => match b with | true => deny "use rg / sd" | false => allow end
reducible def verdictOfDanger2 : Bool -> Verdict :=
  fun b => match b with | true => deny "use rg / sd" | false => allow end

-- the two guards agree on the [true] constructor case, by computation
def agreeOnTrue : Eq Verdict (verdictOfDanger true) (verdictOfDanger2 true) :=
  refl Verdict (deny "use rg / sd")
check agreeOnTrue

-- congruence carries a command-name equality through a guard
def denyStable : (cmd : String) -> (0 h : Eq String cmd "grep") ->
    (0 flag : String -> Bool) ->
    Eq Verdict (verdictOfDanger (flag cmd)) (verdictOfDanger (flag "grep")) :=
  fun cmd h flag =>
    cong0 String Verdict cmd "grep" (fun c => verdictOfDanger (flag c)) h
check denyStable

def flagged : List String := cons String "grep" (cons String "sed" (nil String))
def isFlagged : String -> Bool := fun c => member String auto c flagged
eval isFlagged "sed"
eval isFlagged "rg"
```

VERIFIED on the M3 binary: `verdictOfDanger`, `verdictOfDanger2` and the
`flagged` / `isFlagged` pair (with an explicit dictionary in place of
`auto`) check and run today, and the conversion that makes
`agreeOnTrue` work was verified with a `famV`-shaped analogue.  The
`Eq`-typed defs are expected to check after Stage B, and the `auto` call
site after Stage D.

`agreeOnTrue` computes because both defs are `reducible` and the `deny`
payloads are literals, which convert structurally as `VLit`.
`denyStable` computes nothing;  it is pure congruence.  Both proofs
erase to nothing that any runtime path forces.

### D7. surface/cache.ml

Bump `format_version` from 8 to 9 (D5.3).  Note in the checklist that
Stage D changes NO marshaled kernel type: the classes are ordinary
`Ind`, `Ctor` and `Def` entries, and `Syntax.defkind` is not marshaled.
The bump is for the cache HEADER's exe-identity field alone.

### D8. Stage D tests

`test/main.ml`, labels `D<n>:`:

1. `D1: Auto resolves from the expected type`.  Hand-build a class
   `Cls`, a key `Key`, an instance `inst$Cls$Key`, then
   `Check.check ... Term.Auto (VInd ("Cls", [ VInd ("Key", []) ]))` and
   assert the output term is the resolved `Global "inst$Cls$Key"`
   application, not an `Auto`.
2. `D2: Auto against a non-class expected type is Inst_unresolved`.
   Pin the tag and print the message.
3. `D3: Auto against a class applied to a variable is Inst_unresolved`.
   Same.
4. `D4: a missing instance is Inst_unresolved`.  Same.
5. `D5: a duplicate instance key is Duplicate_global`.  Two
   `define_instance` calls at the same key.  Pin the tag and print the
   message, which must contain `inst$`.
6. `D6: a ground instance at an applied key is Inst_bad_shape`.  Pin the
   tag and print the reason.
7. `D7: instance resolution is fuel bounded`.  Call `build_instance`
   with fuel 0 and pin `Inst_depth`.
8. `D8: checker output never contains Auto`.  After D1's successful
   resolution, walk the returned term and assert no `Term.Auto` node
   survives.  Write the walk as a small exhaustive `Term.t` recursion in
   the test.

`test/surface.ml`, labels `D<n>:`:

9. `D9: the class sugar expands`.  `expect_lines_check` on
   `class C1 (0 A : Type 0) := { m1 : A -> Bool }`, pinning the exact
   `data`, `ctor` and `def` echo lines the expansion produces.
10. `D10: an instance registers under its mangled name`.
    `expect_lines_check` on a `class` plus an `instance`, pinning the
    `def inst$C1$Bool : ...` echo line.
11. `D11: auto resolves at a call site`.  `expect_lines ~st:bst` on
    `eval member String auto "sed" flagged`, pinning `true`.
12. `D12: inst C T resolves the same way`.  `expect_lines ~st:bst` on
    `eval member String (inst EqD String) "sed" flagged`, pinning
    `true`.
13. `D13: a second instance at the same key is Duplicate_global`.
    `expect_err_printed` on two `instance : EqD Bool := ..` items.
14. `D14: --serror-exit changes the exit code`.  Run a type-error
    script through the CLI twice, once bare (exit 1) and once with
    `--serror-exit 3` (exit 3).
15. `D15: --require-main rejects a mainless script`.  `expect_err` with
    tag `Missing_main`;  and the same script without the flag still
    exits 0.
16. `D16: defkind admits no illegal state`.  A compile-time property, so
    the test instead pins that `def partial f : ...` without `rec` is
    still the existing parse error.

### D9. Stage D fixtures

- `m4d-classes.tot` (positive, gate `PASS-M4D-AUTO`): the `flagged` /
  `isFlagged` pair with `auto`, plus one `inst EqD String` call site.
  Pins two output lines, `true` and `false`.
- `m4d-dup-instance.tot` (negative, gate `PASS-M4D-COHERENCE`): two
  instances at the same key.  Expects `Kernel.Duplicate_global` with a
  message containing `inst$`.
- `m4d-serror-exit.tot` (negative, gate `PASS-M4D-SERROR-EXIT`): a
  one-line type error, run with and without `--serror-exit 3`.
- `m4d-nomain.tot` (negative, gate `PASS-M4D-REQUIRE-MAIN`): a script
  with a def named `mian`, run with and without `--require-main`.

### D10. SPEC.md

Append a dated `2026-09-02 (M4, Stage D)` block:

1. **The class resolution key and the coherence rule.**  A class is a
   convention, not a kernel notion: a single-parameter,
   single-constructor `data` (the dictionary), plain projection defs,
   and instances as ordinary globals under `inst$CLASS$KEY`.  The one
   new checking rule is `Auto`: the expected type must be a class
   applied to one type, the KEY is that type's head symbol, and
   resolution is a total function of the expected type value with no
   search and no backtracking.  Coherence is `Duplicate_global` on the
   mangled name, at definition time.  Registration validates the head
   shape, and a ground instance at an applied key is rejected so that
   every key has exactly one derivation route.  Resolution is fuel
   bounded with `Inst_depth`, as a belt over the structural termination
   argument.  `inst C T` is `Term.Ann (Term.Auto, C T)`, pure sugar.
   `Term.Auto` is invalid in checker output;  `Eval`, `Erase` and
   `Interp` each carry an explicit total backstop arm for it.
2. **Scope fences, stated as fences and not as accidents**:
   single-parameter classes, positional parametric instances only, no
   multi-parameter classes, no superclass constraints beyond dictionary
   binders, no overlapping instances, no instances keyed on functions or
   on variables.
3. **`--serror-exit N` ships with default 1** (user decision 4).  The
   flip to 3 is scheduled as a separate change after installed guards
   migrate.  This retires the "Serror exits 1, colliding with ask"
   residual as a CONFIGURABLE collision rather than a fixed one.
4. **`--require-main`** retires the misspelled-main residual for
   installations that opt in.
5. **The stat-identity cache fast path** replaces the executable's MD5
   with a device/inode/mtime/size identity, with the MD5 as the
   fallback.  Cache format version 8 -> 9.
6. **`Syntax.defkind`** replaces the `(rec_, partial)` bool pair.
7. **Debts discharged in Stage A**: the ctor-arity cache and the
   builtin-former marker.

Section 3: add `class`, `instance`, `auto` and `inst` to the surface
grammar.  Section 4: add nothing (no new kernel module).  Section 5:
mark M4 DONE with its actual contents, and restate M5.  Section 6:
carry the debts below.

### D11. README.md

Bump the milestone line to M4 if it states one;  otherwise leave it.

### D12. Gate D

    (i)   `member String auto cmd flagged` typechecks, resolves and runs
          (m4d-classes.tot).
    (ii)  Coherence: a duplicate instance key is rejected at definition
          time (m4d-dup-instance.tot).
    (iii) `--serror-exit 3` changes the exit code and the default stays
          1 (m4d-serror-exit.tot).
    (iv)  `--require-main` rejects a mainless script and the default
          behavior is unchanged (m4d-nomain.tot).
    (v)   Every M3 cache gate stays green after the exe-identity change.
    (vi)  examples/guard.tot still runs through its own shebang against
          the allow, deny and other fixtures with the exact M3 exit
          codes and stdout.
    (vii) examples/guard-classes.tot checks and runs end to end.
    (viii) SPEC.md carries every M4 decision-log entry from all four
          stages.

Markers: `PASS-M4D-AUTO`, `PASS-M4D-COHERENCE`, `PASS-M4D-SERROR-EXIT`,
`PASS-M4D-REQUIRE-MAIN`, `PASS-M4D-GUARD-CLASSES`.

---

## Final

Run the full gate battery one last time, including every `PASS-` marker
from Gates A to D.  Report the final `rg -c '^PASS'` number with its
decomposition against the 167 baseline.  Append the final tails to
`dev/M4-BUILD-LOG.md`.  Do not commit, do not stage.

## Known debts entering M5 (transcribe into SPEC section 6)

Created by this milestone:

- The conservative `Level.le` bound on index TYPES.  Agda exempts index
  types from the predicative bound;  the exemption is probably sound
  here because no constructor field stores an index.  Revisit if
  somebody needs a `Type 1`-indexed telescope.
- `Eq` is `Type 0`-monomorphic, so a `Type 1` need duplicates `subst0`
  and friends.  This prices in universe-polymorphism pressure.
- The `index_expr_clean` backstop is unreachable from source under that
  bound, so only a kernel unit test exercises it.
- The `Frozen` emptiness claim stays UNPROVEN.  The fence is syntactic
  and the backstop is executable.  Revisit if mutual or nested
  inductives ever land.
- The `$`-mangled instance namespace is flat, matching the flat global
  namespace.  There are no per-module instances because there are no
  modules.
- An explicitly written `(w _ : T) ->` index binder is silently forced
  to quantity 0 rather than rejected, because the arrow sugar produces
  the identical surface node.  A named `w` binder IS rejected.
- No holes, again.  Every proof names its type arguments.  Measure after
  M4;  holes stay an M5 candidate.
- Frozen-guard fixtures must be maintained as the erasure story evolves.

Carried forward, unchanged:

- Nested inductives and the `Json` cons-cell migration to
  `jarr : List Json -> Json`.  Waits for the M5 positivity door.
- The bounded regex engine.  `Str` stays single-threaded-safe;  the
  replacement is its own mini-milestone.
- The JSON conformance suite (no `\uXXXX` escapes, partial serializer
  escaping).
- The check-budget flag.  A driver wrapper `timeout` suffices for hooks
  today.
- The prim catalog's unverified trust boundary.
- `Div` typing gives provenance, not a termination proof.
- Well-founded recursion, now unblocked by indexed families.
