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
    across.  [None] on any surviving telescope Var (that argument then
    elaborates via [term]) and, conservatively, on a [Match] node. *)
let rec inst_domain ~(j : int) ~(k : int) (settled : Term.t list) ~(d : int) (t : Term.t) :
    Term.t option =
  match t with
  | Term.Var i when i >= d ->
      let p = j - 1 - (i - d) in
      if p >= 0 && p < k then List.nth_opt settled p |> Option.map (Term.shift ~cutoff:0 ~by:d)
      else None
  | Term.Var i -> Some (Term.Var i)
  | Term.Univ l -> Some (Term.Univ l)
  | Term.Global g -> Some (Term.Global g)
  | Term.Lit l -> Some (Term.Lit l)
  | Term.Auto -> Some Term.Auto
  | Term.Pi (q, x, dom, cod) ->
      inst_domain ~j ~k settled ~d dom
      |> Option.map (fun dom' ->
             inst_domain ~j ~k settled ~d:(d + 1) cod
             |> Option.map (fun cod' -> Term.Pi (q, x, dom', cod')))
      |> Option.join
  | Term.Lam (q, x, body) ->
      inst_domain ~j ~k settled ~d:(d + 1) body |> Option.map (fun body' -> Term.Lam (q, x, body'))
  | Term.App (q, f, a) ->
      inst_domain ~j ~k settled ~d f
      |> Option.map (fun f' ->
             inst_domain ~j ~k settled ~d a |> Option.map (fun a' -> Term.App (q, f', a')))
      |> Option.join
  | Term.Let (x, ty, def, body) ->
      inst_domain ~j ~k settled ~d ty
      |> Option.map (fun ty' ->
             inst_domain ~j ~k settled ~d def
             |> Option.map (fun def' ->
                    inst_domain ~j ~k settled ~d:(d + 1) body
                    |> Option.map (fun body' -> Term.Let (x, ty', def', body')))
             |> Option.join)
      |> Option.join
  | Term.Ann (tm, ty) ->
      inst_domain ~j ~k settled ~d tm
      |> Option.map (fun tm' ->
             inst_domain ~j ~k settled ~d ty |> Option.map (fun ty' -> Term.Ann (tm', ty')))
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

let rec term (globals : Global.t) (scope : string list) (s : Syntax.t) :
    (Term.t, Serror.t) result =
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
      let* dom_t = term globals scope dom in
      let* cod_t = term globals (x :: scope) cod in
      Ok (Term.Pi (q, x, dom_t, cod_t))
  | Syntax.SLam (_loc, x, body) ->
      let* body_t = term globals (x :: scope) body in
      Ok (Term.Lam (Quantity.Many, x, body_t))
  | Syntax.SApp (_loc, f, a) ->
      let* f_t = term globals scope f in
      let* a_t = term globals scope a in
      Ok (Term.App (Quantity.Many, f_t, a_t))
  | Syntax.SLet (_loc, x, ty, def, body) ->
      let* ty_t = term globals scope ty in
      let* def_t = term globals scope def in
      let* body_t = term globals (x :: scope) body in
      Ok (Term.Let (x, ty_t, def_t, body_t))
  | Syntax.SAnn (_loc, tm, ty) ->
      (* M6 Stage C (conflict C-C1): an annotation IS an expected type
         wherever it sits, so the subject descends through [term_at]
         even from infer position (a `check (t : T)` item);  the
         annotation elaborates first because the subject needs it. *)
      let* ty_t = term globals scope ty in
      let* tm_t = term_at globals scope ~expected:ty_t tm in
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
      let* c_t = term globals scope c in
      let* t_t = term globals scope t in
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
      let* ty_a_t = term globals scope ty_a in
      let* ty_b_t = term globals scope ty_b in
      let* rhs_t = term globals scope rhs in
      let* body_t = term globals (x :: scope) body in
      let bind_name = if is_div then "bindDiv" else "bindIO" in
      let app (f : Term.t) (a : Term.t) : Term.t = Term.App (Quantity.Many, f, a) in
      Ok
        (app
           (app (app (app (Term.Global bind_name) ty_a_t) ty_b_t) rhs_t)
           (Term.Lam (Quantity.Many, x, body_t)))
  | Syntax.SMatch (loc, scrut, motive, branches) ->
      (* the ctor name in a pattern is NOT resolved here: the kernel
         checks it against the inductive's declared constructors *)
      let* scrut_t = term globals scope scrut in
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
               let* body_t = term globals scope' sm.Syntax.sm_body in
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
            let* body_t = term globals scope' body in
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
and term_at (globals : Global.t) (scope : string list) ~(expected : Term.t) (s : Syntax.t) :
    (Term.t, Serror.t) result =
  match s with
  | Syntax.SHole loc -> Error (Serror.Hole { loc; expected = Some (scope, expected) })
  | Syntax.SLam (_loc, x, body) -> (
      match expected with
      | Term.Pi (_q, _y, _dom, cod) ->
          (* no shift: the Pi codomain and the lambda body sit under the
             same de Bruijn slot *)
          let* body_t = term_at globals (x :: scope) ~expected:cod body in
          Ok (Term.Lam (Quantity.Many, x, body_t))
      | Term.Var _ | Term.Univ _ | Term.Lam _ | Term.App _ | Term.Let _ | Term.Ann _
      | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
          term globals scope s)
  | Syntax.SLet (_loc, x, ty, def, body) ->
      let* ty_t = term globals scope ty in
      let* def_t = term_at globals scope ~expected:ty_t def in
      let* body_t =
        term_at globals (x :: scope) ~expected:(Term.shift ~cutoff:0 ~by:1 expected) body
      in
      Ok (Term.Let (x, ty_t, def_t, body_t))
  | Syntax.SAnn (_loc, tm, ty) ->
      let* ty_t = term globals scope ty in
      let* tm_t = term_at globals scope ~expected:ty_t tm in
      Ok (Term.Ann (tm_t, ty_t))
  | Syntax.SLetStar (loc, is_div, ty_a, ty_b, x, rhs, body) ->
      (* the desugar target IS a spine headed by the bind prim, so the
         spine rule applies with leading slots (ty_a, ty_b);  the built
         output is byte-identical to [term]'s SLetStar arm *)
      let bind_name = if is_div then "bindDiv" else "bindIO" in
      spine globals scope ~expected bind_name [ ty_a; ty_b; rhs; Syntax.SLam (loc, x, body) ]
      |> unwrap_or (fun () -> term globals scope s)
  | Syntax.SMatch (_loc, scrut, None, branches) ->
      (* the kernel's constant-motive rule checks every branch at the
         expected type (lib/check.ml), so each branch body descends
         under its binders with the expected type shifted past them *)
      let* scrut_t = term globals scope scrut in
      let* rev_branches =
        List.fold_left
          (fun acc (c, binders, body) ->
            let* rev = acc in
            let scope' = List.fold_left (fun sc y -> y :: sc) scope binders in
            let expected' = Term.shift ~cutoff:0 ~by:(List.length binders) expected in
            let* body_t = term_at globals scope' ~expected:expected' body in
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
          spine globals scope ~expected g args |> unwrap_or (fun () -> term globals scope s)
      | ( ( Syntax.SType _ | Syntax.SPi _ | Syntax.SLam _ | Syntax.SApp _ | Syntax.SLet _
          | Syntax.SAnn _ | Syntax.SMatch _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SLetStar _
          | Syntax.SAuto _ | Syntax.SInst _ | Syntax.SHole _ ),
          _args ) ->
          term globals scope s)
  | Syntax.SMatch (_, _, Some _, _)
  | Syntax.SVar _ | Syntax.SType _ | Syntax.SPi _ | Syntax.SStr _ | Syntax.SInt _ | Syntax.SAuto _
  | Syntax.SInst _ ->
      term globals scope s

(** THE SPINE RULE (pin 3), the classifier's E rule made operational.
    [None] when it does not activate ([g] is bound in [scope], is not a
    global, or its declared type has fewer Pis than [args]);  the caller
    then delegates the whole node to [term].  Otherwise: k leading
    [(0 X : Type L)] formals, the family fence, the rigid match of the
    remaining declared type against [expected], the leading slots
    settled left to right (a hole takes its capture or reports the
    slot's declared universe), then argument descent through
    [inst_domain] (or [term] when the fence is up or a domain keeps a
    telescope Var).  The output spine is the same nested [Term.App]
    chain [term]'s SApp arm builds. *)
and spine (globals : Global.t) (scope : string list) ~(expected : Term.t) (g : string)
    (args : Syntax.t list) : (Term.t, Serror.t) result option =
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
                         term_at globals scope ~expected:dom arg)
                 | () when fence -> term globals scope arg
                 | () ->
                     inst_domain ~j ~k (List.rev settled) ~d:0 dom
                     |> Option.map (fun dom' -> term_at globals scope ~expected:dom' arg)
                     |> unwrap_or (fun () -> term globals scope arg)
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
