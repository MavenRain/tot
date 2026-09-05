(** Elaboration: pure scope resolution plus sugar. ALL typechecking stays
    in the kernel; this pass only turns names into de Bruijn indices,
    levels into [Level.t], and rejects unknown names. Locals shadow
    globals. *)

open Tot_kernel

let ( let* ) = Result.bind

let rec index_of (name : string) (scope : string list) : int option =
  match scope with
  | [] -> None
  | x :: rest ->
      if String.equal x name then Some 0
      else index_of name rest |> Option.map (fun ix -> ix + 1)

(** Lazy fallback for Option: [Option.fold ~none] is eager, this is not. *)
let or_else (fallback : unit -> 'a option) (o : 'a option) : 'a option =
  if Option.is_some o then o else fallback ()

(** Lazy default for Option: [Option.value ~default] is eager, this is
    not.  The [some] arm returns a thunk that ignores its unit, so the
    fallback runs only on the [None] path (M6 Stage G). *)
let unwrap_or (fallback : unit -> 'a) (o : 'a option) : 'a =
  Option.fold ~none:fallback ~some:(fun v () -> v) o ()

(* ------------------------------------------------------------------ *)
(* M6 Stage C (verdict pins 1-4): the CHECK-position twin of [term].  *)
(* ------------------------------------------------------------------ *)

(** M6 Stage C (pin 4): the proof families the family fence refuses to
    fill through, the literal PROOF_TOKENS set dev/hole-anchors.py:69
    hard-codes. *)
let proof_families : string list = [ "Eq"; "Dec"; "Empty" ]

(** [g] is (shaped like) a class former: one 0-marked param, no
    indices, exactly one ctor named "mk" ^ g.  Mirrors the [IClass]
    desugar at surface/run.ml:379.  Over-approximation is SAFE: a
    fenced head refuses holes, it never mis-fills one.  Structural on
    purpose: a warm bootstrap restores [Global.t] from the cache without
    re-folding items, so no "I saw an IClass" registry can be sound,
    and [Global.t] gains no class flag this milestone (pin 15). *)
let is_class_former (globals : Global.t) (g : string) : bool =
  Global.find_ind g globals
  |> Option.fold ~none:false ~some:(fun (ind : Global.ind_entry) ->
         let one_zero_param =
           match ind.Global.params with
           | [ (Quantity.Zero, _x, _ty) ] -> true
           | [] | [ (Quantity.Many, _, _) ] | _ :: _ :: _ -> false
         in
         let sole_mk_ctor =
           match ind.Global.ctors with
           | Global.Complete cs -> List.equal String.equal cs [ "mk" ^ g ]
           | Global.Provisional | Global.Builtin -> false
         in
         one_zero_param && List.is_empty ind.Global.indices && sole_mk_ctor)

(** Does some [Term.Global] occurrence in [t] satisfy [p]?  Walks every
    arm, including motives and branch bodies, like [Totality.mentions]. *)
let rec exists_global (p : string -> bool) (t : Term.t) : bool =
  match t with
  | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto -> false
  | Term.Global g -> p g
  | Term.Pi (_q, _x, dom, cod) -> exists_global p dom || exists_global p cod
  | Term.Lam (_q, _x, body) -> exists_global p body
  | Term.App (_q, f, a) -> exists_global p f || exists_global p a
  | Term.Let (_x, ty, def, body) ->
      exists_global p ty || exists_global p def || exists_global p body
  | Term.Ann (tm, ty) -> exists_global p tm || exists_global p ty
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      exists_global p scrut
      || Option.fold ~none:false
           ~some:(fun (mo : Term.motive) -> exists_global p mo.Term.m_body)
           motive
      || List.exists (fun (_c, _binders, body) -> exists_global p body) branches

(** THE FAMILY FENCE (pin 4): no hole in a spine headed by [g] resolves
    when [g] is a class former, or its declared type mentions a proof
    family or a class former. *)
let fenced (globals : Global.t) (g : string) (gty : Term.t) : bool =
  is_class_former globals g
  || List.exists (fun fam -> Totality.mentions fam gty) proof_families
  || exists_global (is_class_former globals) gty

(** [true] iff [t] is a universe node. *)
let is_univ (t : Term.t) : bool =
  match t with
  | Term.Univ _ -> true
  | Term.Var _ | Term.Pi _ | Term.Lam _ | Term.App _ | Term.Let _ | Term.Ann _ | Term.Global _
  | Term.Lit _ | Term.Auto | Term.Match _ ->
      false

(** The count of leading [(0 X : Type L)] binders of a closed global
    type, by syntactic peel (mirrors dev/hole-anchors.py:170-184). *)
let rec leading_type_binders (t : Term.t) : int =
  match t with
  | Term.Pi (q, _x, dom, cod) -> (
      match (q, is_univ dom) with
      | Quantity.Zero, true -> 1 + leading_type_binders cod
      | Quantity.Zero, false | Quantity.Many, true | Quantity.Many, false -> 0)
  | Term.Var _ | Term.Univ _ | Term.Lam _ | Term.App _ | Term.Let _ | Term.Ann _ | Term.Global _
  | Term.Lit _ | Term.Auto | Term.Match _ ->
      0

(** Peel exactly [m] Pi domains off [t]: [Some (domains oldest first,
    remainder)], or [None] when [t] has fewer than [m] leading Pis. *)
let rec peel_domains (m : int) (t : Term.t) : (Term.t list * Term.t) option =
  match () with
  | () when m <= 0 -> Some ([], t)
  | () -> (
      match t with
      | Term.Pi (_q, _x, dom, cod) ->
          peel_domains (m - 1) cod |> Option.map (fun (doms, rest) -> (dom :: doms, rest))
      | Term.Var _ | Term.Univ _ | Term.Lam _ | Term.App _ | Term.Let _ | Term.Ann _
      | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
          None)

(** Total zip: pairs up to the shorter list (the callers pass lists
    [peel_domains] already made the same length). *)
let rec zip (xs : 'a list) (ys : 'b list) : ('a * 'b) list =
  match (xs, ys) with
  | x :: xs', y :: ys' -> (x, y) :: zip xs' ys'
  | [], [] | [], _ :: _ | _ :: _, [] -> []

(** Syntactic equality of two pre-terms, through the printer (names are
    de Bruijn placeholders, so binder spellings are the only thing the
    printer adds, and a spelling mismatch merely refuses a capture). *)
let same_term (a : Term.t) (b : Term.t) : bool =
  String.equal (Pp.term [] a) (Pp.term [] b)

(** Literal equality, per constructor. *)
let lit_equal (a : Literal.t) (b : Literal.t) : bool =
  match (a, b) with
  | Literal.LString x, Literal.LString y -> String.equal x y
  | Literal.LInt x, Literal.LInt y -> Int.equal x y
  | Literal.LString _, Literal.LInt _ | Literal.LInt _, Literal.LString _ -> false

(** THE RIGID MATCH (pin 3, step 3).  [decl] is the head's remaining
    declared type after [m] telescope domains were peeled (so it is
    scoped under those [m] binders); [exp] is the expected pre-term,
    scoped over the outer scope; [d] counts the binders crossed inside
    both.  Quantity stamps are ignored.  A [decl] Var naming one of the
    [k] leading formals captures the aligned [exp] sub-term (at depth 0
    only: a capture under a binder is not scoped over the outer scope,
    so it is refused);  a Var naming any other telescope binder (a
    non-leading argument such as [refl]'s [x]) is a WILDCARD: the
    actual argument is elaborated and re-checked by the kernel, so the
    match need not inspect it (plan note N2: rigid matching alone
    resolves [refl _ zero], which is why the family fence is
    load-bearing);  a second capture of the same formal must print
    identically.  [None] blocks; [Some caps] is the capture list
    (formal index, fill). *)
let rec rigid ~(m : int) ~(k : int) ~(d : int) (decl : Term.t) (exp : Term.t)
    (caps : (int * Term.t) list) : (int * Term.t) list option =
  match (decl, exp) with
  | Term.Var i, e when i >= d -> (
      let p = m - 1 - (i - d) in
      match () with
      | () when p < k && Int.equal d 0 ->
          List.assoc_opt p caps
          |> Option.fold
               ~none:(Some ((p, e) :: caps))
               ~some:(fun prev -> if same_term prev e then Some caps else None)
      | () when p < k ->
          (* M7 Stage A (conflict note C-A5).  A REPEAT occurrence of an
             already captured formal, met under [d] binders, CONFIRMS
             the capture instead of blocking the whole match.  The
             occurrence must print identically to the capture shifted
             past those binders, so this makes no new capture and widens
             no slot;  it only stops a declared domain such as
             [A -> A -> Bool] from refusing itself. *)
          List.assoc_opt p caps
          |> Option.fold ~none:None ~some:(fun prev ->
                 if same_term (Term.shift ~cutoff:0 ~by:d prev) e then Some caps else None)
      | () when p >= k && p < m -> Some caps
      | () -> None)
  | Term.Var i, Term.Var j -> if Int.equal i j then Some caps else None
  | Term.Univ l, Term.Univ l' -> if Level.equal l l' then Some caps else None
  | Term.Pi (_q, _x, dom, cod), Term.Pi (_q', _x', dom', cod') ->
      rigid ~m ~k ~d dom dom' caps |> Option.map (rigid ~m ~k ~d:(d + 1) cod cod') |> Option.join
  | Term.Lam (_q, _x, body), Term.Lam (_q', _x', body') -> rigid ~m ~k ~d:(d + 1) body body' caps
  | Term.App (_q, f, a), Term.App (_q', f', a') ->
      rigid ~m ~k ~d f f' caps |> Option.map (rigid ~m ~k ~d a a') |> Option.join
  | Term.Let (_x, ty, def, body), Term.Let (_x', ty', def', body') ->
      rigid ~m ~k ~d ty ty' caps
      |> Option.map (rigid ~m ~k ~d def def')
      |> Option.join
      |> Option.map (rigid ~m ~k ~d:(d + 1) body body')
      |> Option.join
  | Term.Ann (tm, ty), Term.Ann (tm', ty') ->
      rigid ~m ~k ~d tm tm' caps |> Option.map (rigid ~m ~k ~d ty ty') |> Option.join
  | Term.Global g, Term.Global g' -> if String.equal g g' then Some caps else None
  | Term.Lit l, Term.Lit l' -> if lit_equal l l' then Some caps else None
  | Term.Auto, Term.Auto -> Some caps
  | ( ( Term.Var _ | Term.Univ _ | Term.Pi _ | Term.Lam _ | Term.App _ | Term.Let _ | Term.Ann _
      | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ),
      ( Term.Var _ | Term.Univ _ | Term.Pi _ | Term.Lam _ | Term.App _ | Term.Let _ | Term.Ann _
      | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ) ) ->
      None

(** ARGUMENT DESCENT's instantiation (pin 3, step 4): the declared
    domain [t] of telescope position [j] (scoped under [j] binders) with
    the [k] SETTLED leading args (formal order, each scoped over the
    outer scope) substituted for their formals;  [d] counts binders
    crossed inside [t], which [Term.shift] carries the settled args
    across.  [escape] answers a free variable that falls OUTSIDE the [k]
    settled args (M8 Stage A).  Such a variable names a binder of the
    ENCLOSING scope, which a GLOBAL head never has and a LOCAL head has
    by construction, so the caller supplies the reading.  [None] on any
    surviving telescope Var that [escape] declines (that argument then
    elaborates via [term]) and, conservatively, on a [Match] node. *)
let rec inst_domain ~(escape : int -> Term.t option) ~(j : int) ~(k : int)
    (settled : Term.t list) ~(d : int) (t : Term.t) : Term.t option =
  match t with
  | Term.Var i when i >= d ->
      let p = j - 1 - (i - d) in
      (match () with
       | () when p >= 0 && p < k -> List.nth_opt settled p |> Option.map (Term.shift ~cutoff:0 ~by:d)
       | () -> escape i)
  | Term.Var i -> Some (Term.Var i)
  | Term.Univ l -> Some (Term.Univ l)
  | Term.Global g -> Some (Term.Global g)
  | Term.Lit l -> Some (Term.Lit l)
  | Term.Auto -> Some Term.Auto
  | Term.Pi (q, x, dom, cod) ->
      inst_domain ~escape ~j ~k settled ~d dom
      |> Option.map (fun dom' ->
             inst_domain ~escape ~j ~k settled ~d:(d + 1) cod
             |> Option.map (fun cod' -> Term.Pi (q, x, dom', cod')))
      |> Option.join
  | Term.Lam (q, x, body) ->
      inst_domain ~escape ~j ~k settled ~d:(d + 1) body
      |> Option.map (fun body' -> Term.Lam (q, x, body'))
  | Term.App (q, f, a) ->
      inst_domain ~escape ~j ~k settled ~d f
      |> Option.map (fun f' ->
             inst_domain ~escape ~j ~k settled ~d a |> Option.map (fun a' -> Term.App (q, f', a')))
      |> Option.join
  | Term.Let (x, ty, def, body) ->
      inst_domain ~escape ~j ~k settled ~d ty
      |> Option.map (fun ty' ->
             inst_domain ~escape ~j ~k settled ~d def
             |> Option.map (fun def' ->
                    inst_domain ~escape ~j ~k settled ~d:(d + 1) body
                    |> Option.map (fun body' -> Term.Let (x, ty', def', body')))
             |> Option.join)
      |> Option.join
  | Term.Ann (tm, ty) ->
      inst_domain ~escape ~j ~k settled ~d tm
      |> Option.map (fun tm' ->
             inst_domain ~escape ~j ~k settled ~d ty |> Option.map (fun ty' -> Term.Ann (tm', ty')))
      |> Option.join
  | Term.Match _ -> None

(** Uncurry an application chain: head plus args oldest first. *)
let rec uncurry (s : Syntax.t) (args : Syntax.t list) : Syntax.t * Syntax.t list =
  match s with
  | Syntax.SApp (_loc, f, a) -> uncurry f (a :: args)
  | Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SLet _ | Syntax.SAnn _
  | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _ | Syntax.SAuto _
  | Syntax.SInst _ | Syntax.SHole _ ->
      (s, args)

(* ------------------------------------------------------------------ *)
(* M7 Stage A (pins 2, 3): the ARGUMENT-DRIVEN capture source.  The M6 *)
(* rule reads a leading erased slot off the EXPECTED type only.  These *)
(* helpers read it off a LATER argument of the same spine instead, so  *)
(* the rule also works where there is no expected type at all.  Every  *)
(* one of them is total: no exception, no partial index.               *)
(* ------------------------------------------------------------------ *)

(** The first [n] elements of [xs], or all of them when [xs] is shorter. *)
let rec take (n : int) (xs : 'a list) : 'a list =
  match () with
  | () when n <= 0 -> []
  | () -> ( match xs with [] -> [] | x :: rest -> x :: take (n - 1) rest)

(** [true] iff [s] is a hole. *)
let is_hole (s : Syntax.t) : bool =
  match s with
  | Syntax.SHole _ -> true
  | Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SApp _ | Syntax.SLet _
  | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _
  | Syntax.SAuto _ | Syntax.SInst _ ->
      false

(** [true] when some argument at a LEADING position [j < k] is a hole.
    Every such spine is an ERROR at HEAD, so this test is the infer-path
    activation guard AND its conservativity lemma. *)
let holed_leading_slot ~(k : int) (args : Syntax.t list) : bool =
  List.mapi (fun j a -> (j, a)) args |> List.exists (fun (j, a) -> j < k && is_hole a)

(** [true] when some holed leading slot has NO capture yet.  The
    check-path activation guard:  the settle fold reports
    [Serror.Hole] for exactly this state, so a HEAD-green file never
    reaches the pass. *)
let holed_leading_slot_unsettled ~(k : int) (caps : (int * Term.t) list) (args : Syntax.t list) :
    bool =
  List.mapi (fun j a -> (j, a)) args
  |> List.exists (fun (j, a) -> j < k && is_hole a && Option.is_none (List.assoc_opt j caps))

(** [true] when every holed leading slot has a capture.  First fit
    wins:  the walk stops here and never backtracks. *)
let settles_all ~(k : int) (caps : (int * Term.t) list) (args : Syntax.t list) : bool =
  not (holed_leading_slot_unsettled ~k caps args)

(** The type of the local at de Bruijn index [ix], read in the scope of
    the USE site.  [locals] is aligned with [scope], newest binder
    first, and entry [i] is scoped over the scope its own binder was
    added to, so reading it [ix] binders later shifts it past those
    [ix + 1] binders (conflict note C-A4).  [None] marks a binder whose
    type the elaborator did not learn.  Entries past the end of the list
    read as [None], so the two lists never have to agree in length. *)
let local_ty (locals : Term.t option list) (ix : int) : Term.t option =
  List.nth_opt locals ix |> Option.join |> Option.map (Term.shift ~cutoff:0 ~by:(ix + 1))

(** Peel [Term.App] nodes into a head plus its arguments in declared
    order. *)
let rec spine_head (t : Term.t) (acc : Term.t list) : (Term.t * Term.t list) option =
  match t with
  | Term.App (_q, f, a) -> spine_head f (a :: acc)
  | Term.Var _ | Term.Univ _ | Term.Pi _ | Term.Lam _ | Term.Let _ | Term.Ann _ | Term.Global _
  | Term.Lit _ | Term.Auto | Term.Match _ ->
      Some (t, acc)

(** Does [t] hold a [Term.Auto]?  [Term.Auto] is the one placeholder an
    elaborated pre-term still carries, and a type read off an argument
    that holds one is not a type this pass may match against. *)
let rec has_auto (t : Term.t) : bool =
  match t with
  | Term.Auto -> true
  | Term.Var _ | Term.Univ _ | Term.Global _ | Term.Lit _ -> false
  | Term.Pi (_q, _x, dom, cod) -> has_auto dom || has_auto cod
  | Term.Lam (_q, _x, body) -> has_auto body
  | Term.App (_q, f, a) -> has_auto f || has_auto a
  | Term.Let (_x, ty, def, body) -> has_auto ty || has_auto def || has_auto body
  | Term.Ann (tm, ty) -> has_auto tm || has_auto ty
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      has_auto scrut
      || Option.fold ~none:false
           ~some:(fun (mo : Term.motive) -> has_auto mo.Term.m_body)
           motive
      || List.exists (fun (_c, _binders, body) -> has_auto body) branches

(** The smaller of two optional indices. *)
let min_opt (a : int option) (b : int option) : int option =
  a |> Option.map (fun x -> Option.fold ~none:x ~some:(Int.min x) b) |> or_else (fun () -> b)

(** The SMALLEST free de Bruijn index of [t], read at the top level.
    [d] counts binders crossed inside [t].  [None] when [t] is closed.
    Two readers:  the closedness test below, and A4's occurs test on a
    match motive. *)
let rec min_free_var ~(d : int) (t : Term.t) : int option =
  match t with
  | Term.Var i -> if i >= d then Some (i - d) else None
  | Term.Univ _ | Term.Global _ | Term.Lit _ | Term.Auto -> None
  | Term.Pi (_q, _x, dom, cod) -> min_opt (min_free_var ~d dom) (min_free_var ~d:(d + 1) cod)
  | Term.Lam (_q, _x, body) -> min_free_var ~d:(d + 1) body
  | Term.App (_q, f, a) -> min_opt (min_free_var ~d f) (min_free_var ~d a)
  | Term.Let (_x, ty, def, body) ->
      min_opt (min_free_var ~d ty)
        (min_opt (min_free_var ~d def) (min_free_var ~d:(d + 1) body))
  | Term.Ann (tm, ty) -> min_opt (min_free_var ~d tm) (min_free_var ~d ty)
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      min_opt (min_free_var ~d scrut)
        (min_opt
           (motive
           |> Option.map (fun (mo : Term.motive) ->
                  min_free_var ~d:(d + 1 + List.length mo.Term.m_idx) mo.Term.m_body)
           |> Option.join)
           (List.fold_left
              (fun acc (_c, binders, body) ->
                min_opt acc (min_free_var ~d:(d + List.length binders) body))
              None branches))

(** [true] iff [t] has no free variable. *)
let is_closed (t : Term.t) : bool = Option.is_none (min_free_var ~d:0 t)

(** The type of a head applied to [applied], read off the head's
    declared type [gty]:  one declared domain leaves per applied
    argument, and every leading formal is instantiated with the ACTUAL
    argument term.  [None] when the declared type runs out of Pis, when
    an argument holds a placeholder, or when the residual type keeps a
    telescope variable.  [inst_domain] does the substitution, so this
    adds no new de Bruijn arithmetic.  The head is a GLOBAL, whose
    declared type is read at top level, so no free variable escapes the
    peeled telescope on a well-formed program:  [escape] answers [None]
    and this function keeps its M7 behaviour exactly. *)
let inst_applied (gty : Term.t) (applied : Term.t list) : Term.t option =
  let n = List.length applied in
  match () with
  | () when List.exists has_auto applied -> None
  | () ->
      peel_domains n gty
      |> Option.map (fun (_doms, rest) ->
             inst_domain ~escape:(fun _ -> None) ~j:n ~k:n applied ~d:0 rest)
      |> Option.join

(** M8 Stage A:  the LOCAL-head twin of [inst_applied].  A local's
    declared type, shifted to the use site by [local_ty], mentions the
    binders of the ENCLOSING scope as free variables, so the residual
    left by [peel_domains] keeps them.  The residual is read under the
    [n] peeled binders, and an escaping index names a binder [n] frames
    further out, so [Term.Var (i - n)] is that same binder read one
    frame shallower.  Everything else matches [inst_applied]:  [None]
    when the declared type runs out of Pis and [None] when an argument
    holds a placeholder.  The captured type stays OPEN, which the
    downstream rigid match accepts (the whnf RETRY step alone is
    closed-only), and the kernel re-checks the finished definition
    (surface/run.ml:241). *)
let inst_applied_local (lty : Term.t) (applied : Term.t list) : Term.t option =
  let n = List.length applied in
  match () with
  | () when List.exists has_auto applied -> None
  | () ->
      peel_domains n lty
      |> Option.map (fun (_doms, rest) ->
             inst_domain ~escape:(fun i -> Some (Term.Var (i - n))) ~j:n ~k:n applied ~d:0 rest)
      |> Option.join

(** The type of an already-elaborated argument, when the elaborator can
    read it off without typechecking.  Three shapes only:
    (1) a local [Term.Var] whose type [locals] carries;
    (2) a spine headed by a GLOBAL, whose declared type loses one domain
    per applied argument;
    (3) a spine headed by a LOCAL, whose type [locals] carries and which
    loses one declared domain per applied argument, keeping the free
    locals of the residual (M8 Stage A).  [None] everywhere else,
    including under a hole, a lambda and a match.  The kernel re-checks the finished
    definition (surface/run.ml:241), so a wrong answer here is a kernel
    [Mismatch], never a silent accept. *)
let synth (globals : Global.t) (locals : Term.t option list) (t : Term.t) : Term.t option =
  spine_head t []
  |> Option.map (fun (head, applied) ->
         match head with
         | Term.Var ix -> (
             match applied with
             | [] -> local_ty locals ix
             | _ :: _ ->
                 local_ty locals ix
                 |> Option.map (fun lty -> inst_applied_local lty applied)
                 |> Option.join)
         | Term.Global g ->
             Global.find g globals
             |> Option.map Global.entry_ty
             |> Option.map (fun gty -> inst_applied gty applied)
             |> Option.join
         | Term.Univ _ | Term.Pi _ | Term.Lam _ | Term.App _ | Term.Let _ | Term.Ann _ | Term.Lit _
         | Term.Auto | Term.Match _ ->
             None)
  |> Option.join

(** The rigid match of [decl] against a synthesized type [ity], retried
    ONCE on the head-normal form of [ity] (pin 3).  The retry runs only
    for a CLOSED [ity]:  an open type has no environment to evaluate it
    in.  This is the one evaluator call in the elaborator and it runs
    only on a path that is an error at HEAD. *)
let rigid_or_whnf (globals : Global.t) ~(m : int) ~(k : int) ~(d : int) (decl : Term.t)
    (ity : Term.t) (caps : (int * Term.t) list) : (int * Term.t) list option =
  rigid ~m ~k ~d decl ity caps
  |> or_else (fun () ->
         match () with
         | () when not (is_closed ity) -> None
         | () ->
             Eval.eval globals [] ity |> Result.to_option
             |> Option.map (fun v -> Eval.quote globals 0 v |> Result.to_option)
             |> Option.join
             |> Option.map (fun ity' -> rigid ~m ~k ~d decl ity' caps)
             |> Option.join)

(** M7 Stage A (A4): does some subterm of [s] hold a hole?  A total
    syntactic fold on the PARSED body, so it runs before any
    elaboration.  It is A4's conservativity lemma:  a branch body with
    no hole keeps [term] and keeps HEAD's exact node. *)
let rec branch_body_has_hole (s : Syntax.t) : bool =
  match s with
  | Syntax.SHole _ -> true
  | Syntax.SVar _ | Syntax.SType _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SAuto _ -> false
  | Syntax.SPi (_loc, _q, _x, dom, cod) -> branch_body_has_hole dom || branch_body_has_hole cod
  | Syntax.SLam (_loc, _x, body) -> branch_body_has_hole body
  | Syntax.SApp (_loc, f, a) -> branch_body_has_hole f || branch_body_has_hole a
  | Syntax.SLet (_loc, _x, ty, def, body) ->
      branch_body_has_hole ty || branch_body_has_hole def || branch_body_has_hole body
  | Syntax.SAnn (_loc, tm, ty) -> branch_body_has_hole tm || branch_body_has_hole ty
  | Syntax.SInst (_loc, c, t) -> branch_body_has_hole c || branch_body_has_hole t
  | Syntax.SLetStar (_loc, _is_div, ty_a, ty_b, _x, rhs, body) ->
      branch_body_has_hole ty_a || branch_body_has_hole ty_b || branch_body_has_hole rhs
      || branch_body_has_hole body
  | Syntax.SMatch (_loc, scrut, motive, branches) ->
      branch_body_has_hole scrut
      || Option.fold ~none:false
           ~some:(fun (sm : Syntax.smotive) -> branch_body_has_hole sm.Syntax.sm_body)
           motive
      || List.exists (fun (_c, _binders, body) -> branch_body_has_hole body) branches

(** M7 Stage A (A1, A2): the declared field types of constructor [c],
    aligned with the branch [binders], oldest field first.  The
    inductive's parameters come from [scrut_ty], the synthesized type of
    the scrutinee, so the field types are scoped over the OUTER scope
    like every other [locals] entry.  [None] marks a field the
    elaborator could not instantiate, which includes every field whose
    type mentions an earlier field. *)
let ctor_field_types (globals : Global.t) (c : string) (scrut_ty : Term.t option)
    (binders : string list) : Term.t option list =
  let unknown = List.map (fun _b -> None) binders in
  Global.find c globals
  |> Option.map (fun (e : Global.entry) ->
         match e with
         | Global.Ctor ce -> Some ce
         | Global.Def _ | Global.Ind _ | Global.Prim _ | Global.Axiom _ -> None)
  |> Option.join
  |> Option.map (fun (ce : Global.ctor_entry) ->
         let np = ce.Global.full_arity - List.length ce.Global.args in
         scrut_ty
         |> Option.map (fun sty -> spine_head sty [])
         |> Option.join
         |> Option.map (fun (_head, sargs) ->
                let ps = take np sargs in
                match () with
                | () when not (Int.equal (List.length ps) np) -> unknown
                | () when not (Int.equal (List.length binders) (List.length ce.Global.args)) ->
                    unknown
                | () ->
                    (* Each field type is instantiated in the PRE-branch
                       scope, but field [i] is pushed after [i] earlier
                       binders, so it shifts past them to keep the
                       [local_ty] convention (conflict note C-A4). *)
                    List.mapi
                      (fun i (_q, _x, fty) ->
                        inst_domain ~escape:(fun _ -> None) ~j:(np + i) ~k:np ps ~d:0 fty
                        |> Option.map (Term.shift ~cutoff:0 ~by:i))
                      ce.Global.args))
  |> Option.join
  |> Option.value ~default:unknown

(** M7 Stage A (A4): the expected type of a branch body under a CONSTANT
    motive.  [None] when there is no motive, and [None] when the motive
    body mentions its own [as] binder or one of its index binders:  the
    branch would then need the dependent instantiation at the pattern,
    which is kernel work and is out of scope.  Otherwise the motive body
    with those binders dropped and shifted past the branch binders, the
    shift the motive-free arm of [term_at] already applies. *)
let branch_expected (motive : Term.motive option) ~(binders : string list) : Term.t option =
  motive
  |> Option.map (fun (mo : Term.motive) ->
         let depth = 1 + List.length mo.Term.m_idx in
         match () with
         | ()
           when min_free_var ~d:0 mo.Term.m_body
                |> Option.fold ~none:false ~some:(fun i -> i < depth) ->
             None
         | () ->
             Some
               (Term.shift ~cutoff:0 ~by:(List.length binders)
                  (Term.shift ~cutoff:0 ~by:(-depth) mo.Term.m_body)))
  |> Option.join

let rec term (globals : Global.t) (scope : string list) ?(locals : Term.t option list = [])
    (s : Syntax.t) : (Term.t, Serror.t) result =
  match s with
  | Syntax.SVar (loc, x) ->
      index_of x scope
      |> Option.map (fun ix -> Term.Var ix)
      |> or_else (fun () ->
             Global.find x globals |> Option.map (fun _entry -> Term.Global x))
      |> Option.to_result ~none:(Serror.Unknown_name { loc; name = x })
  | Syntax.SType (loc, n) ->
      Level.of_int n
      |> Option.map (fun l -> Term.Univ l)
      |> Option.to_result ~none:(Serror.Bad_level { loc; level = n })
  | Syntax.SPi (_loc, q, x, dom, cod) ->
      let* dom_t = term globals scope ~locals dom in
      let* cod_t = term globals (x :: scope) ~locals:(Some dom_t :: locals) cod in
      Ok (Term.Pi (q, x, dom_t, cod_t))
  | Syntax.SLam (_loc, x, body) ->
      let* body_t = term globals (x :: scope) ~locals:(None :: locals) body in
      Ok (Term.Lam (Quantity.Many, x, body_t))
  | Syntax.SApp (_loc, f, a) -> (
      (* M7 Stage A (Q1 amendment).  Infer position has no expected
         type, so the ONLY capture source is the later arguments of this
         same spine.  [uncurry] is the existing helper;  no new
         traversal.  [app_infer] is HEAD's own two lines, so the
         fallback builds the identical node. *)
      match uncurry s [] with
      | Syntax.SVar (_hloc, g), args ->
          spine_infer globals scope ~locals g args
          |> unwrap_or (fun () -> app_infer globals scope ~locals f a)
      | ( ( Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SApp _ | Syntax.SLet _
          | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _
          | Syntax.SAuto _ | Syntax.SInst _ | Syntax.SHole _ ),
          _args ) ->
          app_infer globals scope ~locals f a)
  | Syntax.SLet (_loc, x, ty, def, body) ->
      let* ty_t = term globals scope ~locals ty in
      let* def_t = term globals scope ~locals def in
      let* body_t = term globals (x :: scope) ~locals:(Some ty_t :: locals) body in
      Ok (Term.Let (x, ty_t, def_t, body_t))
  | Syntax.SAnn (_loc, tm, ty) ->
      (* M6 Stage C (conflict C-C1): an annotation IS an expected type
         wherever it sits, so the subject descends through [term_at]
         even from infer position (a `check (t : T)` item);  the
         annotation elaborates first because the subject needs it. *)
      let* ty_t = term globals scope ~locals ty in
      let* tm_t = term_at globals scope ~locals ~expected:ty_t tm in
      Ok (Term.Ann (tm_t, ty_t))
  | Syntax.SStr (_loc, s) -> Ok (Term.Lit (Literal.LString s))
  | Syntax.SInt (_loc, n) -> Ok (Term.Lit (Literal.LInt n))
  | Syntax.SAuto _loc -> Ok Term.Auto
  | Syntax.SHole loc ->
      (* M6 Stage C (verdict pin 3): [term] is the INFER-position
         entry, so no expected type reaches a hole here;  [term_at]
         below is the check-position twin that fills them. *)
      Error (Serror.Hole { loc; expected = None })
  | Syntax.SInst (_loc, c, t) ->
      (* M4 Stage D (D3): the whole implementation.  An annotated [Auto]
         IS the escape hatch: [Ann] steers checking and is dropped from
         checker output, and [Check.check]'s existing [Ann] path already
         routes to [check ... Auto ty_v]. *)
      let* c_t = term globals scope ~locals c in
      let* t_t = term globals scope ~locals t in
      Ok (Term.Ann (Term.Auto, Term.App (Quantity.Many, c_t, t_t)))
  | Syntax.SLetStar (_loc, is_div, ty_a, ty_b, x, rhs, body) ->
      (* M3 Stage C, C3: purely syntactic desugar to
         [bindIO A B e (fun x => body)] / [bindDiv A B e (fun x =>
         body)], BEFORE any typechecking (this function only resolves
         names to indices; [Check] alone assigns the real Pi
         quantities, which is why every [Term.App] stamp below is the
         same [Quantity.Many] placeholder [SApp] itself always writes).
         FALLBACK SHAPE (no [SHole]; see [Syntax.SLetStar]'s own doc
         comment): [ty_a]/[ty_b] are the sugar's own EXPLICIT type
         arguments, elaborated in the OUTER scope like the
         right-hand-side (neither can mention [x], which is bound only
         in [body]).  M6 Stage C: in CHECK position ([term_at]) either
         slot may be a hole;  here, in infer position, a hole in a
         slot is the [SHole] arm's error. *)
      let* ty_a_t = term globals scope ~locals ty_a in
      let* ty_b_t = term globals scope ~locals ty_b in
      let* rhs_t = term globals scope ~locals rhs in
      let* body_t = term globals (x :: scope) ~locals:(None :: locals) body in
      let bind_name = if is_div then "bindDiv" else "bindIO" in
      let app (f : Term.t) (a : Term.t) : Term.t = Term.App (Quantity.Many, f, a) in
      Ok
        (app
           (app (app (app (Term.Global bind_name) ty_a_t) ty_b_t) rhs_t)
           (Term.Lam (Quantity.Many, x, body_t)))
  | Syntax.SMatch (loc, scrut, motive, branches) ->
      (* the ctor name in a pattern is NOT resolved here: the kernel
         checks it against the inductive's declared constructors *)
      let* scrut_t = term globals scope ~locals scrut in
      (* M4 Stage A, the G2 arity check: [Elab.term] already receives
         [globals], so the motive's "in I .." index-arity check lives
         here rather than duplicating a family lookup in [Check]. *)
      let* motive_t =
        motive
        |> Option.fold ~none:(Ok None) ~some:(fun (sm : Syntax.smotive) ->
               let* () =
                 sm.Syntax.sm_ind
                 |> Option.fold ~none:(Ok ()) ~some:(fun iname ->
                        let* ind =
                          Global.find_ind iname globals
                          |> Option.to_result ~none:(Serror.Unknown_name { loc; name = iname })
                        in
                        let m = List.length ind.Global.indices in
                        if Int.equal m (List.length sm.Syntax.sm_idx) then Ok ()
                        else
                          Error
                            (Serror.Kernel
                               {
                                 loc;
                                 err =
                                   Error.Motive_index_arity
                                     {
                                       ind = iname;
                                       expected = m;
                                       found = List.length sm.Syntax.sm_idx;
                                     };
                               }))
               in
               let scope' =
                 sm.Syntax.sm_self :: List.fold_left (fun s y -> y :: s) scope sm.Syntax.sm_idx
               in
               let locals' =
                 None :: List.fold_left (fun l _y -> None :: l) locals sm.Syntax.sm_idx
               in
               let* body_t = term globals scope' ~locals:locals' sm.Syntax.sm_body in
               Ok
                 (Some
                    {
                      Term.m_ind = sm.Syntax.sm_ind;
                      m_idx = sm.Syntax.sm_idx;
                      m_self = sm.Syntax.sm_self;
                      m_body = body_t;
                    }))
      in
      let* rev_branches =
        List.fold_left
          (fun acc (c, binders, body) ->
            let* rev = acc in
            let scope' = List.fold_left (fun s x -> x :: s) scope binders in
            (* M7 Stage A (A4).  A branch body with NO hole keeps [term]
               and keeps HEAD's exact node, and it also costs no field
               lookup.  A holed body under a CONSTANT motive descends in
               check position instead, so a leading erased slot in it
               reads the slot's declared universe. *)
            let holed = branch_body_has_hole body in
            let field_tys =
              match () with
              | () when not holed -> List.map (fun _y -> None) binders
              | () -> ctor_field_types globals c (synth globals locals scrut_t) binders
            in
            let locals' = List.fold_left (fun l ty -> ty :: l) locals field_tys in
            let* body_t =
              (match () with
              | () when not holed -> None
              | () -> branch_expected motive_t ~binders)
              |> Option.map (fun expected' ->
                     term_at globals scope' ~locals:locals' ~expected:expected' body)
              |> unwrap_or (fun () -> term globals scope' ~locals:locals' body)
            in
            Ok ((c, List.map (fun x -> (Quantity.Many, x)) binders, body_t) :: rev))
          (Ok []) branches
      in
      Ok
        (Term.Match
           {
             scrut = scrut_t;
             scrut_q = Quantity.Many;
             motive = motive_t;
             branches = List.rev rev_branches;
           })

(** The check-position twin of [term] (M6 Stage C, pins 1-3).
    INVARIANTS: (1) [expected] is a PRE-TERM scoped over exactly
    [scope];  (2) on hole-free input the result is byte-for-byte what
    [term] returns (every arm builds the node its [term] sibling
    builds);  (3) a fill is always a sub-term of [expected] or of a
    declared global type instantiated with such sub-terms, and the
    UNCHANGED kernel re-checks it, so a wrong fill is a kernel error
    downstream, never a silent acceptance.  Rigid means rigid: no
    evaluation in the elaborator, ever. *)
and term_at (globals : Global.t) (scope : string list) ~(expected : Term.t)
    ?(locals : Term.t option list = []) (s : Syntax.t) : (Term.t, Serror.t) result =
  match s with
  | Syntax.SHole loc -> Error (Serror.Hole { loc; expected = Some (scope, expected) })
  | Syntax.SLam (_loc, x, body) -> (
      match expected with
      | Term.Pi (_q, _y, dom, cod) ->
          (* no shift: the Pi codomain and the lambda body sit under the
             same de Bruijn slot *)
          let* body_t = term_at globals (x :: scope) ~locals:(Some dom :: locals) ~expected:cod body in
          Ok (Term.Lam (Quantity.Many, x, body_t))
      | Term.Var _ | Term.Univ _ | Term.Lam _ | Term.App _ | Term.Let _ | Term.Ann _
      | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
          term globals scope ~locals s)
  | Syntax.SLet (_loc, x, ty, def, body) ->
      let* ty_t = term globals scope ~locals ty in
      let* def_t = term_at globals scope ~locals ~expected:ty_t def in
      let* body_t =
        term_at globals (x :: scope) ~locals:(Some ty_t :: locals)
          ~expected:(Term.shift ~cutoff:0 ~by:1 expected) body
      in
      Ok (Term.Let (x, ty_t, def_t, body_t))
  | Syntax.SAnn (_loc, tm, ty) ->
      let* ty_t = term globals scope ~locals ty in
      let* tm_t = term_at globals scope ~locals ~expected:ty_t tm in
      Ok (Term.Ann (tm_t, ty_t))
  | Syntax.SLetStar (loc, is_div, ty_a, ty_b, x, rhs, body) ->
      (* the desugar target IS a spine headed by the bind prim, so the
         spine rule applies with leading slots (ty_a, ty_b);  the built
         output is byte-identical to [term]'s SLetStar arm *)
      let bind_name = if is_div then "bindDiv" else "bindIO" in
      spine globals scope ~expected ~locals bind_name
        [ ty_a; ty_b; rhs; Syntax.SLam (loc, x, body) ]
      |> unwrap_or (fun () -> term globals scope ~locals s)
  | Syntax.SMatch (_loc, scrut, None, branches) ->
      (* the kernel's constant-motive rule checks every branch at the
         expected type (lib/check.ml), so each branch body descends
         under its binders with the expected type shifted past them *)
      let* scrut_t = term globals scope ~locals scrut in
      let* rev_branches =
        List.fold_left
          (fun acc (c, binders, body) ->
            let* rev = acc in
            let scope' = List.fold_left (fun sc y -> y :: sc) scope binders in
            let expected' = Term.shift ~cutoff:0 ~by:(List.length binders) expected in
            let field_tys =
              match () with
              | () when not (branch_body_has_hole body) -> List.map (fun _y -> None) binders
              | () -> ctor_field_types globals c (synth globals locals scrut_t) binders
            in
            let locals' = List.fold_left (fun l ty -> ty :: l) locals field_tys in
            let* body_t = term_at globals scope' ~locals:locals' ~expected:expected' body in
            Ok ((c, List.map (fun y -> (Quantity.Many, y)) binders, body_t) :: rev))
          (Ok []) branches
      in
      Ok
        (Term.Match
           {
             scrut = scrut_t;
             scrut_q = Quantity.Many;
             motive = None;
             branches = List.rev rev_branches;
           })
  | Syntax.SApp (_loc, _f, _a) -> (
      match uncurry s [] with
      | Syntax.SVar (_hloc, g), args ->
          spine globals scope ~expected ~locals g args
          |> unwrap_or (fun () -> term globals scope ~locals s)
      | ( ( Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SApp _ | Syntax.SLet _
          | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _
          | Syntax.SAuto _ | Syntax.SInst _ | Syntax.SHole _ ),
          _args ) ->
          term globals scope ~locals s)
  | Syntax.SMatch (_, _, Some _, _)
  | Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SAuto _
  | Syntax.SInst _ ->
      term globals scope ~locals s

(** THE SPINE RULE (pin 3), the classifier's E rule made operational.
    The steps run in this order.  ACTIVATION: [None] when [g] is bound
    in [scope], is not a global, or has fewer declared Pis than [args];
    the caller then delegates the whole node to [term].  Then the k
    leading [(0 X : Type L)] formals.  Then the FAMILY FENCE, which
    refuses every fill under a proof family or a class former.  Then the
    rigid match of the remaining declared type against [expected], which
    is the M6 capture source.  Then the argument-driven capture pass
    (M7 Stage A, pin 3):  when a leading slot is a hole that the
    expected type left open, walk the LATER explicit arguments in
    declared order, synthesize the type of each, and keep the captures
    of the FIRST one whose type rigid-matches its declared domain.
    First fit wins:  no backtracking, no metavariable leaves this spine,
    no unification across definitions.  Then the SETTLE FOLD, left to
    right:  a hole in a leading slot takes its capture or reports the
    slot's declared universe.  The fold walks the arguments in that same
    order, and then argument descent through [inst_domain] (or [term]
    when the fence is up, or when a domain keeps a telescope Var)
    elaborates each one.  The output spine is the same nested [Term.App]
    chain [term]'s SApp arm builds. *)
and spine (globals : Global.t) (scope : string list) ~(expected : Term.t)
    ?(locals : Term.t option list = []) (g : string) (args : Syntax.t list) :
    (Term.t, Serror.t) result option =
  let m = List.length args in
  let entry = if Option.is_some (index_of g scope) then None else Global.find g globals in
  entry
  |> Option.map (fun e ->
         let gty = Global.entry_ty e in
         peel_domains m gty |> Option.map (fun (doms, rest) -> (gty, doms, rest)))
  |> Option.join
  |> Option.map (fun (gty, doms, rest) ->
         let k = Int.min (leading_type_binders gty) m in
         let fence = fenced globals g gty in
         let caps =
           if fence then [] else rigid ~m ~k ~d:0 rest expected [] |> Option.value ~default:[]
         in
         (* M7 Stage A, pin 3: a leading slot the expected type left
            open may still be determined by a LATER explicit argument of
            the SAME spine.  The guard is the conservativity lemma:  the
            settle fold below reports [Serror.Hole] for exactly this
            state, so the pass runs only on input that is an ERROR at
            HEAD and no HEAD-green file reaches it. *)
         let caps =
           match () with
           | () when fence -> caps
           | () when not (holed_leading_slot_unsettled ~k caps args) -> caps
           | () -> arg_caps globals scope locals ~m ~k doms args caps
         in
         (* settle every position left to right, threading the settled
            leading args (formal order) into the later domains *)
         let* _settled, rev_args =
           List.fold_left
             (fun acc (j, (dom, arg)) ->
               let* settled, rev = acc in
               let* arg_t =
                 match () with
                 | () when j < k -> (
                     match arg with
                     | Syntax.SHole loc ->
                         List.assoc_opt j caps
                         |> Option.to_result
                              ~none:(Serror.Hole { loc; expected = Some (scope, dom) })
                     | Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _
                     | Syntax.SApp _ | Syntax.SLet _ | Syntax.SAnn _ | Syntax.SMatch _
                     | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _ | Syntax.SAuto _
                     | Syntax.SInst _ ->
                         term_at globals scope ~locals ~expected:dom arg)
                 | () when fence -> (
                     match arg with
                     | Syntax.SHole loc ->
                         inst_domain ~escape:(fun _ -> None) ~j ~k (List.rev settled) ~d:0 dom
                         |> Option.map (fun dom' ->
                                Error (Serror.Hole { loc; expected = Some (scope, dom') }))
                         |> unwrap_or (fun () -> term globals scope ~locals arg)
                     | Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _
                     | Syntax.SApp _ | Syntax.SLet _ | Syntax.SAnn _ | Syntax.SMatch _
                     | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _ | Syntax.SAuto _
                     | Syntax.SInst _ ->
                         term globals scope ~locals arg)
                 | () ->
                     inst_domain ~escape:(fun _ -> None) ~j ~k (List.rev settled) ~d:0 dom
                     |> Option.map (fun dom' -> term_at globals scope ~locals ~expected:dom' arg)
                     |> unwrap_or (fun () -> term globals scope ~locals arg)
               in
               let settled' = if j < k then arg_t :: settled else settled in
               Ok (settled', arg_t :: rev))
             (Ok ([], []))
             (List.mapi (fun j da -> (j, da)) (zip doms args))
         in
         Ok
           (List.fold_left
              (fun f a -> Term.App (Quantity.Many, f, a))
              (Term.Global g) (List.rev rev_args)))

(** M7 Stage A (Q1 amendment): the INFER-position twin of [spine].  Same
    activation test, same family fence, same settle fold, same output
    node.  Three differences, all forced by pin 2.  (1) The whole
    function stands down unless a LEADING slot is a hole, so a spine
    that is green at HEAD returns [None] and the caller takes HEAD's own
    path.  (2) [caps] starts EMPTY, because there is no expected type to
    match against, so the ARGUMENT-DRIVEN pass is the only source.
    (3) An unsettled hole returns HEAD's own error value,
    [Serror.Hole { loc; expected = None }], at the hole's own [loc]. *)
and spine_infer (globals : Global.t) (scope : string list) ~(locals : Term.t option list)
    (g : string) (args : Syntax.t list) : (Term.t, Serror.t) result option =
  let m = List.length args in
  let entry = if Option.is_some (index_of g scope) then None else Global.find g globals in
  entry
  |> Option.map (fun e ->
         let gty = Global.entry_ty e in
         peel_domains m gty |> Option.map (fun (doms, _rest) -> (gty, doms)))
  |> Option.join
  |> Option.map (fun (gty, doms) ->
         let k = Int.min (leading_type_binders gty) m in
         let fence = fenced globals g gty in
         match () with
         | () when not (holed_leading_slot ~k args) -> None
         | () ->
             let caps =
               match () with
               | () when fence -> []
               | () -> arg_caps globals scope locals ~m ~k doms args []
             in
             let settled_args =
               let* _settled, rev_args =
                 List.fold_left
                   (fun acc (j, (dom, arg)) ->
                     let* settled, rev = acc in
                     let* arg_t =
                       match () with
                       | () when j < k -> (
                           match arg with
                           | Syntax.SHole loc ->
                               List.assoc_opt j caps
                               |> Option.to_result ~none:(Serror.Hole { loc; expected = None })
                           | Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _
                           | Syntax.SApp _ | Syntax.SLet _ | Syntax.SAnn _ | Syntax.SMatch _
                           | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _ | Syntax.SAuto _
                           | Syntax.SInst _ ->
                               term_at globals scope ~locals ~expected:dom arg)
                       | () when fence -> term globals scope ~locals arg
                       | () -> (
                           match arg with
                           | Syntax.SHole loc -> Error (Serror.Hole { loc; expected = None })
                           | Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _
                           | Syntax.SApp _ | Syntax.SLet _ | Syntax.SAnn _ | Syntax.SMatch _
                           | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _ | Syntax.SAuto _
                           | Syntax.SInst _ ->
                               inst_domain ~escape:(fun _ -> None) ~j ~k (List.rev settled) ~d:0 dom
                               |> Option.map (fun dom' ->
                                      term_at globals scope ~locals ~expected:dom' arg)
                               |> unwrap_or (fun () -> term globals scope ~locals arg))
                     in
                     let settled' = if j < k then arg_t :: settled else settled in
                     Ok (settled', arg_t :: rev))
                   (Ok ([], []))
                   (List.mapi (fun j da -> (j, da)) (zip doms args))
               in
               Ok
                 (List.fold_left
                    (fun f a -> Term.App (Quantity.Many, f, a))
                    (Term.Global g) (List.rev rev_args))
             in
             Some settled_args)
  |> Option.join

(** M7 Stage A (Q1 amendment): HEAD's own infer-position application,
    lifted into a named function so the [spine_infer] fallback builds
    the identical node with the identical [Quantity.Many] stamp. *)
and app_infer (globals : Global.t) (scope : string list) ~(locals : Term.t option list)
    (f : Syntax.t) (a : Syntax.t) : (Term.t, Serror.t) result =
  let* f_t = term globals scope ~locals f in
  let* a_t = term globals scope ~locals a in
  Ok (Term.App (Quantity.Many, f_t, a_t))

(** M7 Stage A (pin 3): the ARGUMENT-DRIVEN capture pass.  Walk the
    non-leading positions [k <= i < m] in declared order.  Elaborate the
    argument in infer position, read its type off with [synth], and
    rigid-match that type against the argument's declared domain.  The
    first argument that matches a still-open slot supplies that slot's
    capture; later arguments add captures only for slots still open and
    never replace one.  [Result.to_option]
    drops a failed argument, so a bare lambda or an argument that names
    an unknown local falls through to the next position instead of
    failing the spine.  The declared domain is SHIFTED by [m - i] first:
    [doms] holds position [i] under [i] binders and [rigid] reads its
    argument under [m] binders, the same gap [inst_domain] closes.
    [settles_all] stops the walk as soon as every holed leading slot has
    a capture, so first fit wins and nothing backtracks. *)
and arg_caps (globals : Global.t) (scope : string list) (locals : Term.t option list) ~(m : int)
    ~(k : int) (doms : Term.t list) (args : Syntax.t list) (caps : (int * Term.t) list) :
    (int * Term.t) list =
  List.fold_left
    (fun acc (i, (dom, arg)) ->
      match () with
      | () when i < k -> acc
      | () when settles_all ~k acc args -> acc
      | () ->
          term globals scope ~locals arg |> Result.to_option
          |> Option.map (fun arg_t -> synth globals locals arg_t)
          |> Option.join
          |> Option.map (fun ity ->
                 rigid_or_whnf globals ~m ~k ~d:0 (Term.shift ~cutoff:0 ~by:(m - i) dom) ity acc)
          |> Option.join
          |> Option.value ~default:acc)
    caps
    (List.mapi (fun i da -> (i, da)) (zip doms args))
