# M2 build plan: inductives, match, totality, stdlib

Authoritative spec for the M2 implementation agents. Read this WHOLE file
before touching code. The repo is ~/Documents/tot (OCaml, dune). M1 is
committed (9153ba5); the working tree additionally has term.ml and
erase.ml ALREADY REWRITTEN for Stage A (do not revert them).

## 0. Ground rules (house style, enforced by hooks)

- NO exceptions anywhere: no raise/failwith/assert/exit paths besides the
  existing test runners' Stdlib.exit. Every failure is a Result value.
- NO match on Option/Result where a combinator does the job
  (Option.fold/map/to_result, Result.bind/fold, let*). A PreToolUse hook
  DENIES edits that add such matches.
- NO loop keywords (for/while); recursion + List.fold/map/filteri only.
- Exhaustive matches, NO catch-all `_ ->` arms on variant types you can
  enumerate (existing code style: spell the variants; `match () with
  | () when ...` ladders instead of if/else-if chains).
- Comments: match the existing density; doc comments on every new
  top-level type/function.
- Shell: use `rg` not grep, `sd` not sed. Append ` # [skip-disk]` (as a
  trailing comment) to every Bash command: a disk-floor interlock is
  active and that suffix is the approved bypass; putting it bare (not in
  a #-comment) gets zsh-globbed.
- Never `cd`: use `dune build --root /Users/oobi/Documents/tot`,
  `git -C ...`, absolute paths. Your cwd RESETS between Bash calls.
- Do NOT run `git add` or `git commit`. Leave everything as working-tree
  edits.
- gates.sh must not use `set -u` (a chpwd hook breaks under it).

Gate command (run after every stage; all must be green):

    dune build --root /Users/oobi/Documents/tot 2>&1 | tail -20 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot test/main.exe 2>&1 | tail -5 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot test/surface.exe 2>&1 | tail -5 # [skip-disk]
    dune exec --root /Users/oobi/Documents/tot bin/tot.exe -- run /Users/oobi/Documents/tot/examples/church.tot 2>&1 | tail -3 # [skip-disk]

Append a short stage report (what changed, gate output tails) to
/Users/oobi/Documents/tot/dev/M2-BUILD-LOG.md when your stage is green.

## Stage A: quantity-stamped core terms

Goal: retire the two M1 debts "Erase mirrors Check" and "eval items are
re-inferred during erasure". Term.Lam and Term.App now carry a
Quantity.t (ALREADY DONE in lib/term.ml). Elaboration and hand-built
terms write a Many placeholder; Check OVERWRITES stamps from the Pi it
checks against and returns the stamped term. Erasure (ALREADY DONE in
lib/erase.ml) is purely structural over stamped terms.

Files to update:

1. lib/eval.ml — pattern arities only. `Lam (_q, x, body)`,
   `App (_q, f, a)`: quantities are IGNORED by evaluation and
   conversion (values carry quantities only on VPi, unchanged).
   quote of VLam rebuilds `Term.Lam (Quantity.Many, x, body)` (quoted
   terms feed display and conversion only, never erasure — say so in a
   comment). quote neutral spine rebuilds `Term.App (Quantity.Many, ...)`.

2. lib/check.ml — bidirectional passes now RETURN stamped terms:
     infer : Global.t -> ctx -> Quantity.t -> Term.t
             -> (Term.t * Value.t, Error.t) result
     infer_univ : Global.t -> ctx -> Term.t
             -> (Term.t * Level.t, Error.t) result
     check : Global.t -> ctx -> Quantity.t -> Term.t -> Value.t
             -> (Term.t, Error.t) result
   Rules (same logic as M1, plus stamping):
   - Var: unchanged logic; output `Term.Var ix`.
   - Univ: output as-is.
   - Pi: recurse via infer_univ on dom and cod; rebuild stamped Pi.
   - Lam in infer: Cannot_infer (unchanged). Lam in check against
     VPi(q,..): bind with q; output `Lam (q, x, body')` — q FROM THE PI,
     input stamp discarded.
   - App in infer: infer f; f_ty must be VPi(q,...); check arg at mode
     `Quantity.mul mode q`; output `App (q, f', a')` — q from the Pi.
     IMPORTANT: evaluate the STAMPED a' (not the input a) for the
     codomain instantiation; stamps do not change eval results but be
     consistent.
   - Let: infer_univ ty; check def; bind_def with STAMPED def's value;
     rebuild `Let (x, ty', def', body')` in both infer and check modes.
   - Ann: check inner against the type, then RETURN THE INNER stamped
     term and the type — Ann is DROPPED from checker output (record in
     SPEC; annotations steer checking only).
   - Global: unchanged; output `Global name`.
   - check fallback arm: call infer, conv against expected (unchanged),
     return the stamped term from infer.
   define: store the STAMPED ty and def in the Global entry.

3. lib/pp.ml — arities: print Lam as before ignoring q; App ignoring q.

4. surface/elab.ml — SLam elaborates to `Term.Lam (Quantity.Many, x, b)`;
   SApp to `Term.App (Quantity.Many, f, a)` (placeholders).

5. surface/run.ml — IDef: after Check.define, fetch the entry back
   (Global.find name |> Option.to_result) and erase its stamped def via
   `Erase.closed entry.def` (Erase no longer needs ty/globals). The
   printed line still uses the elaborated ty (display identical).
   ICheck: `let* tm', ty_v = Check.infer ... Quantity.Zero tm` — print
   Pp.term of tm'. IEval: infer at Many gives (tm', ty_v); erase tm'.

6. test/main.ml — Term.Lam/App constructors gain a leading quantity:
   use `qw` everywhere (placeholders; the checker overwrites). infer
   now returns a pair: adapt expect_infer_ok/expect_infer_err/
   case_id_result_type (bind `_tm, ty`).

7. test/surface.ml — add one negative:
     ("lex numeric literal cap",
      expect_err "def x : Type 0 := Type 1234567890123456789" "Lex")
   (19 digits; pins the M1 overflow guard).

Run the gate. All 18 M0 + 16 surface cases green before Stage B.

## Stage B: kernel inductives, dependent match, rec globals, totality

Design pins (add to SPEC decision log at Stage D):
- Parameterized inductives only; INDICES DEFERRED to M4 (arrive with
  Eq). The Match motive already abstracts the scrutinee, so indices
  are additive later.
- Flat namespace: the inductive name and every constructor name are
  globals (same map, new entry kinds).
- Parameters are ALWAYS quantity-0 (types/type-like data): at ctor
  applications the param args erase; runtime ctor values carry kept
  (w) args only.
- Strict positivity, uniform parameters: a ctor argument type may
  mention the inductive I ONLY as `I p1..pn` (its own params, in
  order) — either as the whole arg type or as the codomain of a Pi
  telescope whose domains never mention I. No nested (I inside another
  inductive's params), no mutual, no local fix in v0.
- Universe rule: each ctor argument type's level <= the declared level
  of the inductive (predicative). Add `Level.le : t -> t -> bool`
  (and to level.mli).
- Recursion: TOP-LEVEL `def rec` only. The recursive global is opaque
  while its own body is checked (recursive calls do not unfold).
  A structural totality guard (below) must accept the stamped body.
  Evaluation unfolds a REDUCIBLE rec global only when its principal
  argument is a canonical constructor value (guarded unfolding), so
  conversion cannot diverge; opaque rec globals never unfold in
  conversion. The runtime interpreter is unaffected (call-by-value on
  erased terms; recursive EGlobal references resolve through the
  runtime global map at each application, and stuck scrutinees freeze
  branch bodies, so readback cannot diverge either).
- No eta for inductives (a neutral never equals a ctor value).
- Checker output stamps branch binders with the ctor telescope's
  quantities so erasure stays structural.

### lib/global.ml

    type telescope = (Quantity.t * string * Term.t) list
      (** binder telescope, outermost first; each type is scoped under
          the binders before it *)

    type entry =
      | Def of { ty : Term.t; def : Term.t; reducible : bool;
                 rec_arg : int option
                 (** [Some k]: guarded-unfold on canonical arg #k *) }
      | Ind of { ty : Term.t (* closed: params -> Type level *);
                 params : telescope; level : Level.t;
                 ctor_names : string list (* declaration order *) }
      | Ctor of { ty : Term.t (* closed: 0-params -> args -> I params *);
                  ind : string;
                  args : telescope (* scoped under params + earlier args *) }

Keep the existing lookup/add; small Option-returning accessors for the
Ind and Ctor payloads are welcome. Existing M1 call sites that read
entry.ty / entry.def / entry.reducible must match on Def and treat
Ind/Ctor appropriately (see eval/check below).

### lib/error.ml — new variants (tags = constructor names)

    | Not_inductive of string        (* match scrutinee type; payload = printed type *)
    | Bad_ctor of { ctor : string; reason : string }
                                     (* result-head / positivity / universe *)
    | Branch_mismatch of { expected : string; found : string }
                                     (* exhaustiveness + declaration order;
                                        use "<none>" for a missing side *)
    | Termination of string          (* rec def failed the structural guard *)

Also generalize Cannot_infer's message to "cannot infer a type for %s"
(payload examples: "the bare lambda (binder x)", "a match without 'as
.. return'") — tests pin TAGS, not messages.

### lib/term.ml — add

    | Match of {
        scrut : t;
        motive : (string * t) option;
            (** binder over the scrutinee; None only survives checking
                in check-mode (constant motive = expected type) *)
        branches : (string * (Quantity.t * string) list * t) list;
            (** ctor name, OWN args (binder quantities stamped by the
                checker; elaboration writes Many placeholders), body *)
      }

### lib/value.ml — canonical inductive values + neutral frames

    type t =
      | VUniv | VPi | VLam (as now)
      | VInd of string * t list    (** type ctor applied; args in order *)
      | VCtor of string * t list   (** data ctor applied; args in order,
                                       params included *)
      | VNeutral of head * frame list  (** frames newest first *)

    and head = HVar of int | HGlobal of string

    and frame =
      | FApp of t
      | FMatch of stuck_match

    and stuck_match = {
      motive : (string * Term.t) option;
      branches : (string * (Quantity.t * string) list * Term.t) list;
      menv : t list;  (** env for motive and branch bodies alike *)
    }

### lib/eval.ml

- eval Match: evaluate scrut.
  * VCtor (cname, args): look up the ctor entry -> its ind -> n_params;
    locate the branch whose name is cname (a miss is an internal
    error — return Branch_mismatch as a total backstop, it is
    unreachable on checked terms); own = args minus the first n_params
    (List.filteri); eval the branch body in `List.rev_append own env`.
    Factor this as `run_match globals env scrut_v m` so the
    frame-replay path (below) reuses it.
  * VNeutral (h, frames): push an FMatch frame capturing {motive;
    branches; menv = env}.
  * VUniv/VPi/VLam/VInd: Error (Not_inductive ...) — total backstop.
- eval Global: entry Ind -> Ok (VInd (name, [])); entry Ctor ->
  Ok (VCtor (name, [])); entry Def as now (reducible -> unfold, else
  neutral) EXCEPT rec defs (rec_arg = Some k): ALWAYS start neutral
  (VNeutral (HGlobal n, [])) even when reducible — unfolding is
  decided at application time (guarded).
- apply:
  * VInd (n, args) -> Ok (VInd (n, args @ [a]))    (args are tiny)
  * VCtor (c, args) -> Ok (VCtor (c, args @ [a]))
  * VNeutral (HGlobal n, frames) with entry Def{reducible=true;
    rec_arg=Some k; def}: push FApp a; collect the LEADING (oldest)
    run of FApp frames as the argument list (List.rev frames, take
    while FApp); if it has an element at position k (List.nth_opt) and
    that value is canonical (VCtor _), unfold: eval def in [] and
    replay ALL frames oldest-first (FApp -> apply; FMatch sm ->
    run_match using sm.menv/sm fields). Otherwise stay neutral.
  * VNeutral (other): push FApp (as now).
  * VPi/VUniv: Not_a_function (as now); VLam: closure (as now).
- quote: VInd/VCtor -> fold Term.App (Quantity.Many, ...) over
  Term.Global; neutral frames: rebuild oldest-first — FApp as App;
  FMatch: rebuild Term.Match { scrut = acc; motive = quote the motive
  body by evaluating it in (fresh :: menv) at size+1; branches:
  evaluate each body in menv extended with fresh vars for its binders
  (levels size..size+arity-1) and quote at size+arity }.
- conv: VInd/VInd and VCtor/VCtor: name equal + args pointwise;
  ALL cross-shape pairs false (spell them out, no catch-all).
  Neutral frames: heads equal, frame lists pairwise: FApp/FApp conv;
  FMatch/FMatch: motives (both None -> true; both Some -> conv their
  bodies evaluated at a fresh var; mixed -> false) AND branches
  pairwise (same ctor name; bodies conv under fresh vars for the
  binders); FApp/FMatch mixed -> false.
- The eta rules VLam-vs-neutral push `FApp fresh` now.

### lib/check.ml

- infer Match {scrut; motive; branches}:
  * `let* scrut', s_ty = infer globals ctx mode scrut` (scrutinee is
    consumed at the ambient mode).
  * s_ty must be VInd (iname, p_vals) with List.length p_vals =
    n_params (otherwise Not_inductive of the printed type).
  * motive None -> Error (Cannot_infer "a match without 'as .. return'").
  * motive Some (x, mot): ctx_m = bind x Quantity.Many
    (VInd (iname, p_vals)) ctx; `let* mot', _l = infer_univ globals
    ctx_m mot`.
  * Branches must match the ind's ctor_names EXACTLY in declaration
    order and count (walk both lists together; mismatch ->
    Branch_mismatch {expected; found} with "<none>" for the short
    side). For each ctor c with telescope `args` (scoped params +
    earlier args): walk the telescope keeping BOTH a value env
    `tele_env` (starts `List.rev p_vals`) and the growing checker ctx:
    at step i, ty_v = Eval.eval globals tele_env ty_i; record the
    fresh var `Value.var ctx.size`; ctx := bind name_i q_i ty_v ctx;
    tele_env := fresh :: tele_env. Branch binder names come from the
    USER's pattern (arity must equal telescope length, else
    Branch_mismatch with a payload naming c); quantities come from the
    TELESCOPE (stamp them into the output branch).
  * Expected body type: eval mot' in (VCtor (c, p_vals @ fresh_args)
    :: ctx.env); check the body at the ambient mode against it.
  * Result type: eval mot' in (scrut_value :: ctx.env) where
    scrut_value = Eval.eval globals ctx.env scrut'. Output stamped
    Match with motive Some.
- check Match against expected: motive None -> same branch walk with
  every expected body type = `expected` and result = Ok stamped
  (motive stays None). motive Some -> do the infer path then conv the
  result type against expected (the generic fallback arm does this if
  you route Match through infer there — but the None case MUST be
  handled in check before the fallback).
- declare_ind globals ~name ~params ~level:
  duplicate-name check; walk the params telescope with infer_univ
  (growing ctx) returning the STAMPED telescope; build the closed ty
  (right-fold Pi over params ending in Univ level); add entry Ind
  {ty; params = stamped; level; ctor_names = []}.
- define_ind globals ~name ~ctors:(string * Term.t) list  — globals
  ALREADY contains the declare_ind entry; each ctor type was
  elaborated in scope [params]. For each (cname, cty):
  * duplicate-name check (Duplicate_global cname) — also between the
    ctors of this very declaration.
  * infer_univ the whole cty in the params ctx (this stamps it and
    validates well-formedness); no level constraint on the WHOLE cty,
    the per-arg constraint is below.
  * Decompose the STAMPED cty: strip leading Pis into an args
    telescope; the final codomain must be Global name applied (via
    App spine) to EXACTLY the param variables in order: with d = the
    number of stripped Pis, param j (outermost = 0) must appear as
    Var (d + n_params - 1 - j). Otherwise Bad_ctor {ctor; reason =
    "constructor must end in <name> applied to its parameters"}.
  * Positivity per arg type T at position i (base depth = i): scan
    for Global name occurrences. Allowed: T itself (or the codomain
    of a Pi telescope within T whose DOMAINS never mention the name)
    being exactly the applied form above (with the depth adjusted by
    the Pis crossed). Any other occurrence -> Bad_ctor {ctor; reason
    = "negative or non-uniform occurrence of <name>"}.
  * Universe: infer_univ of each arg TYPE (in the ctx of params +
    earlier args) gives a level; require Level.le l ind_level, else
    Bad_ctor {ctor; reason = "constructor argument lives above the
    declared universe"}.
  * Build the closed ctor ty: right-fold Pi over (params FORCED to
    Quantity.Zero) then the args telescope, ending in the applied-
    params codomain. Entry Ctor {ty; ind = name; args}.
  Finally rewrite the Ind entry with the ctor_names list. On ANY
  error return the error (the caller keeps its pre-declare globals).
- define gains ~rec_:bool (default false at call sites via a labelled
  arg, or a separate define_rec — pick ONE public shape and keep
  define's M1 signature working for existing callers by adding the
  label with a default). rec path: after infer_univ ty and eval ty_v,
  ADD a provisional entry Def {ty = stamped ty; def = Term.Global
  name; reducible = false; rec_arg = None} (opaque self-reference;
  never evaluated while checking), check the body against ty_v in
  THOSE globals, then run Totality.guard (below) on the STAMPED body
  to obtain rec_arg k; store the final entry (with the caller's
  reducible flag and rec_arg = Some k) into the ORIGINAL globals.

### lib/totality.ml (new)

    val guard : recname:string -> Term.t -> (int, Error.t) result

On the stamped body of `def rec`: peel the leading Lams to a formals
list (arity n). For each candidate k in 0..n-1 (first success wins):
walk the body with a status list (newest binder first) of
  Principal | Smaller | Other
seeded so formal k is Principal and the rest Other. Rules:
- Global recname encountered ANYWHERE except as the head of an App
  spine with > k arguments whose (k+1)-th (0-based k) argument is
  `Term.Var ix` with status Smaller -> this candidate FAILS.
  (Collect App spines: App (_, App (_, Global f, a0), a1) ... — head
  plus args oldest-first.) Also walk INTO all the args.
- Match on `Term.Var ix` whose status is Principal or Smaller: every
  branch binder gets status Smaller; the motive binder (when present)
  gets Other. Match on anything else: branch binders get Other; also
  walk the scrutinee.
- Lam/Pi/Let binders push Other (walk all subterms: dom+cod, ty+def+
  body). Ann: walk both (checker output has none; total anyway).
- Var/Univ/Global(other) are fine.
If no candidate passes: Error (Termination recname).

### lib/eterm.ml / lib/erase.ml / lib/interp.ml / lib/pp.ml

- Eterm: `| EMatch of t * (string * string list * t) list` (branch
  binder names = KEPT args only).
- Erase Match: erase scrut; drop the motive; per branch keep only the
  Many-stamped binders ((x, true) pushes, Zero binders push (x,
  false)) and erase the body.
- Interp values:
      type v = VClos ... | VCon of string * v list
             | VNeut of int * eframe list | VErased
      and eframe = FEApp of v
                 | FEMatch of (branches as in Eterm) * (v list) env
  exec EMatch: scrut VCon (c, args) -> locate the branch named c (a
  miss is a total-backstop error), arity must equal args length, exec
  body in List.rev_append args env; VNeut -> push FEMatch; VClos/
  VErased -> Not_inductive backstop. apply: VCon appends. quote: VCon
  -> EApp chain over EGlobal; VNeut frames rebuilt oldest-first
  (FEMatch -> EMatch with bodies quoted under fresh vars, mirroring
  the kernel). define: unchanged (rec defs erase to lambdas — the
  guard forces every recursive call under the principal binder — so
  the closed eval at definition time cannot recurse).
  NEW seed helpers for Run: add_ctor seeding VCon (name, []) and
  add_erased seeding VErased (for the type constructor itself, which
  is inert at runtime like every type).
- Pp.term Match:
      match S with | c x y => B | .. end
  and with a motive: `match S as x return P with .. end`.
  Pp.eterm EMatch likewise (no motive). Exact spacing as shown:
  "match " then the scrutinee, optional " as x return P", " with",
  then for each branch " | c x y => body", finally " end".

### Stage B kernel tests (append to test/main.ml; keep every M0 case)

Hand-build via declare_ind/define_ind: Nat (zero, succ) at Type 0 and
Opt (0 A : Type 0) (none / some (w _ : A)) at Type 1? NO — keep Opt at
Type 0 with a Type 0 param (its args live at level 0; the PARAM's own
type Type 0 lives at level 1 but params are unconstrained). Payload for
tests: Nat. Then pin:
1. match eval: `match succ (succ zero) with | zero => zero | succ n =>
   n end` (motive `_ => Nat`) converts to `succ zero`.
2. Dependent motive: a motive returning a DIFFERENT type per ctor over
   a 2-ctor inductive (branches typecheck; infer succeeds).
3. Branch order wrong -> Branch_mismatch; missing branch ->
   Branch_mismatch; wrong pattern arity -> Branch_mismatch.
4. Match on a non-inductive -> Not_inductive.
5. Positivity: a ctor of shape mk : (Bad -> Nat) -> Bad -> Bad_ctor.
6. Universe: ctor arg at Type 1 in a Type 0 inductive -> Bad_ctor.
7. def rec add (structural on arg 0) via the rec define path: conv
   `add (succ zero) (succ zero)` = `succ (succ zero)` (reducible rec +
   canonical arg unfolds).
8. Guarded: with x an OPAQUE global of type Nat, `add x (succ zero)`
   stays stuck: conv against itself true, against any succ-form false.
9. Termination negative: `def rec loop : Nat -> Nat := fun n => loop
   n` -> Termination.
10. Stuck-match conv: two identical matches on an opaque scrutinee
    convert; differing branch bodies do not.
Use the existing expect_conv/expect_infer_* helpers; pin exact error
TAGS. Opt usage: check `some Nat (succ zero) : Opt Nat` infers, and a
match over it extracts the payload.

## Stage C: surface syntax

New tokens (token.ml + lexer keywords + describe): KData "data",
KMatch "match", KWith "with", KAs "as", KReturn "return", KRec "rec",
KEnd "end", Pipe '|'. Lexer: '|' is a single-char token (add before
the catch-all error arm).

Surface pins (record in SPEC at Stage D):
- data declaration:
      data NAME (0 p : T) .. : Type L := | c1 : CT1 | c2 : CT2 ..
  Zero or more parenthesized single-binder groups, each REQUIRED to
  carry the literal 0 marker (bare or w -> Parse error "data
  parameters must be marked 0"); one param name per group. `: Type L`
  is required (L optional, defaults 0 as everywhere). Zero ctors is
  LEGAL (empty type): `data Void : Type 0 :=` followed by no pipes —
  the next item keyword or Eof ends the list. Each CTi is an ordinary
  term elaborated in scope of the params (and of the freshly declared
  NAME via the provisional global).
- match term:
      match S with | c x y => B .. end
      match S as x return P with | .. end
  Branch patterns are FLAT: a ctor name followed by zero or more
  distinct binder names. `end` is required. Zero branches is legal
  syntax (matching an empty type in check position).
- def rec:  [reducible] def rec NAME : TY := BODY

Syntax.ml: add
    | SMatch of Loc.t * t * (string * t) option
              * (string * string list * t) list
items: IData { loc; name; params : (string * t) list; level : int;
               ctors : (string * t) list }
and add a `rec_ : bool` field to IDef.

Parser: data params: LParen, expect Nat 0 marker, one Ident, Colon,
term, RParen (reuse/parallel the binder-group machinery; here NO
backtracking is needed — after `data NAME` a LParen can only open a
param). After params: Colon, then `Type` [Nat] (level), ColonEq, then
zero+ of: Pipe, Ident (ctor name), Colon, term. Stop at any of KDef/
KReducible/KData/KEval/KCheck/Eof. match: after KMatch parse a term;
optional KAs Ident KReturn term; KWith; branches: Pipe Ident idents*
DArrow term; KEnd. def rec: KRec after KDef sets rec_.

Elab: SMatch -> Term.Match with Many-placeholder branch binder
quantities; motive binder scopes the motive term; branch binders scope
their bodies; the ctor NAME in a pattern is passed through as a string
(the kernel resolves it against the inductive's ctor list; it is NOT
looked up in the elaboration scope). IData/ctor types: elaborate each
ctor type in scope [param names] against the provisional globals.

Run.item IData:
  1. elaborate the params telescope left-to-right (scope grows;
     quantity forced Zero by the parser).
  2. Level.of_int the declared level (Bad_level via Serror on
     failure, as elsewhere).
  3. Check.declare_ind -> provisional globals.
  4. elaborate each ctor type in scope [params] against those.
  5. Check.define_ind -> final globals (on error the item fails; state
     keeps the OLD globals).
  6. eglobals: add_erased NAME; add_ctor each ctor name.
  7. Output lines: "data NAME : <Pp of the Ind entry ty>" then one
     "ctor c : <Pp of the ctor entry ty>" per ctor, in order.
IDef with rec_: route to the rec define path; output line unchanged
("def NAME : TY").

Serror: nothing new needed (kernel errors arrive tagged Kernel.*).

### Stage C surface tests (append to test/surface.ml)

Positives (pin EXACT output lines, running both exec and check modes
where illuminating):
1. Bool + not:  data Bool : Type 0 := | true : Bool | false : Bool
   then def not : Bool -> Bool := fun b => match b with | true =>
   false | false => true end; eval not true  ==> lines: "data Bool :
   Type 0", "ctor true : Bool", "ctor false : Bool", "def not : (w _
   : Bool) -> Bool", "false".
2. Nat + rec add: data Nat : Type 0 := | zero : Nat | succ : Nat ->
   Nat; def rec add : Nat -> Nat -> Nat := fun m n => match m with
   | zero => n | succ p => succ (add p n) end; eval add (succ zero)
   (succ (succ zero)) ==> final line "(succ (succ (succ zero)))".
3. Parameterized + erasure: data Box (0 A : Type 0) : Type 0 := |
   box : A -> Box A;  def unbox : (0 A : Type 0) -> Box A -> A :=
   fun A b => match b with | box x => x end; eval unbox Nat (box Nat
   (succ zero)) ==> "(succ zero)" — pins that params erase from
   runtime ctor values (box carries ONE runtime arg).
4. match with as/return in infer position: eval (match zero as n
   return Nat with | zero => zero | succ p => p end) ==> "zero".
5. check mode on a data script prints the data/ctor lines and eval's
   type.
Negatives (pin tags):
6. missing branch -> "Kernel.Branch_mismatch"; wrong order ->
   "Kernel.Branch_mismatch"; unknown ctor name in a pattern ->
   "Kernel.Branch_mismatch".
7. positivity: data Bad : Type 0 := | mk : (Bad -> Bad) -> Bad ->
   "Kernel.Bad_ctor".
8. def rec loop : Nat -> Nat := fun n => loop n -> "Kernel.Termination".
9. match on a function -> "Kernel.Not_inductive".
10. data param without the 0 marker -> "Parse"; `w` marker -> "Parse".
11. infer-position match WITHOUT as/return (eval match zero with ..
    end) -> "Kernel.Cannot_infer".
12. duplicate ctor name across two data decls -> "Kernel.
    Duplicate_global".

## Stage D: stdlib, examples, docs

1. stdlib/prelude.tot — exactly this program (it must check AND run):

    -- tot prelude (M2): core data types and functions.
    data Bool : Type 0 := | true : Bool | false : Bool
    data Nat : Type 0 := | zero : Nat | succ : Nat -> Nat
    data Option (0 A : Type 0) : Type 0 := | none : Option A | some : A -> Option A
    data Result (0 A : Type 0) (0 E : Type 0) : Type 0 := | ok : A -> Result A E | err : E -> Result A E
    data List (0 A : Type 0) : Type 0 := | nil : List A | cons : A -> List A -> List A
    data Pair (0 A : Type 0) (0 B : Type 0) : Type 0 := | pair : A -> B -> Pair A B
    def not : Bool -> Bool := fun b => match b with | true => false | false => true end
    def andb : Bool -> Bool -> Bool := fun a b => match a as x return Bool with | true => b | false => false end
    def orb : Bool -> Bool -> Bool := fun a b => match a as x return Bool with | true => true | false => b end
    reducible def rec add : Nat -> Nat -> Nat := fun m n => match m with | zero => n | succ p => succ (add p n) end
    reducible def rec mul : Nat -> Nat -> Nat := fun m n => match m with | zero => zero | succ p => add n (mul p n) end
    def isZero : Nat -> Bool := fun n => match n with | zero => true | succ p => false end
    def fromOption : (0 A : Type 0) -> A -> Option A -> A := fun A d o => match o with | none => d | some x => x end
    def rec append : (0 A : Type 0) -> List A -> List A -> List A := fun A xs ys => match xs with | nil => ys | cons h t => cons A h (append A t ys) end
    def rec map : (0 A : Type 0) -> (0 B : Type 0) -> (A -> B) -> List A -> List B := fun A B f xs => match xs with | nil => nil B | cons h t => cons B (f h) (map A B f t) end
    def rec foldNat : (0 A : Type 0) -> A -> (A -> A) -> Nat -> A := fun A z s n => match n with | zero => z | succ p => s (foldNat A z s p) end

   NOTE the check-position matches without as/return in not/isZero/
   fromOption/add/... rely on the constant-motive rule; andb/orb show
   the explicit form. If any line fails to check, FIX THE LINE (e.g.
   add as/return) rather than the kernel, and note it in the log.
   Mind that ctor applications take their erased param explicitly at
   the TERM level? NO — params are 0-quantity Pi binders, so `cons A
   h t` is the correct saturated form and A erases at runtime; `nil`
   alone is `nil : (0 A : Type 0) -> List A`, so branches building
   lists must write `nil B` etc. The prelude above already does.
2. examples/nat.tot — a small demo: Nat data decl + add + eval of a
   sum (self-contained; do NOT depend on the prelude).
3. dev/gates.sh — keep the two test exes; add `tot check` AND `tot
   run` over stdlib/prelude.tot and both examples (church.tot,
   nat.tot) via dune exec with --root, echoing PASS markers; no
   `set -u`; no loop keywords in NEW shell code if avoidable (existing
   style: straight-line commands + && chains).
4. SPEC.md: append the Stage B "Design pins" above (plus: stamped
   Lam/App quantities with checker-authoritative output and Ann
   dropped from output; structural erasure; data/match/def-rec surface
   pins from Stage C; literals, String, Json, prelude AUTO-loading all
   deferred to M3) to the decision log dated 2026-09-01 (M2). Update
   section 3 grammar with match and data items, section 4 module list
   (Totality; Global entry kinds; Value frames), section 5: mark M2
   DONE with its actual contents (note Json/String moved to M3),
   section 6 debts: REMOVE the erase-mirrors-check and re-inference
   debts (resolved by stamping); keep/adjust the rest; ADD: no
   indices/nested/mutual/local-fix (M4), rec_arg auto-selection is
   first-fit, match-in-infer needs an explicit motive, prelude is a
   file not an auto-import, guarded unfolding requires `reducible`.
5. README.md: if it states milestone status, bump it to M2; otherwise
   leave it.

## Final

Run the full gate battery one last time; append the final tails to
dev/M2-BUILD-LOG.md. Do not commit, do not stage.
