(** Evaluation, readback, and conversion. NbE with closures; syntax uses
    indices, values use levels. Everything returns [Result]: a scope bug
    surfaces as an error value, never as an exception.

    Inductives: type and data constructors evaluate to canonical [VInd] /
    [VCtor] values that swallow applications. A rec global ([rec_arg =
    Some k]) ALWAYS starts neutral and unfolds only at application time,
    when argument [k] is a canonical constructor value, so conversion
    cannot diverge on open recursive calls. *)

let ( let* ) = Result.bind

(** The leading (oldest-first) run of [FApp] argument values of a frame
    list ALREADY reversed to oldest-first order. *)
let rec leading_fapp_args (frames : Value.frame list) : Value.t list =
  match frames with
  | [] -> []
  | Value.FApp v :: rest -> v :: leading_fapp_args rest
  | Value.FMatch _ :: _rest -> []

(** Canonical means: a data constructor FULLY applied. The kernel value
    domain does not erase, so a [VCtor]'s args list carries every
    argument the ctor was applied to, params first (see [run_match]'s
    own [n_params] slice) then its own args telescope in order,
    regardless of quantity; full arity is the sum of the two. A ctor
    looked up but shy of that count is a partial application, not
    canonical (unknown ctor names cannot occur on checked terms; total
    via [Option.fold], no error path needed here). *)
let is_canonical (globals : Global.t) (v : Value.t) : bool =
  match v with
  | Value.VCtor (c, args) ->
      Global.find_ctor c globals
      |> Option.fold ~none:false ~some:(fun (ctor : Global.ctor_entry) ->
             (* M4 Stage A: the chained [find_ind] lookup is DELETED; the
                ctor entry now carries its own [full_arity] (A4/A5's
                ctor-arity-cache debt, discharged in Stage A). *)
             Int.equal (List.length args) ctor.Global.full_arity)
  | Value.VUniv _ | Value.VPi (_, _, _, _) | Value.VLam (_, _) | Value.VInd (_, _)
  | Value.VNeutral (_, _)
  (* a VLit is NOT canonical for guarded unfolding: structural recursion
     is over constructors, and there is no structurally smaller literal
     (M3 Stage A). *)
  | Value.VLit _ ->
      false

let rec eval (globals : Global.t) (env : Value.t list) (tm : Term.t) :
    (Value.t, Error.t) result =
  match tm with
  | Term.Var ix -> List.nth_opt env ix |> Option.to_result ~none:(Error.Unbound_var ix)
  | Term.Univ l -> Ok (Value.VUniv l)
  | Term.Lit l -> Ok (Value.VLit l)
  | Term.Pi (q, x, dom, cod) ->
      let* dom_v = eval globals env dom in
      Ok (Value.VPi (q, x, dom_v, { Value.env; body = cod }))
  | Term.Lam (_q, x, body) -> Ok (Value.VLam (x, { Value.env; body }))
  | Term.App (_q, f, a) ->
      let* f_v = eval globals env f in
      let* a_v = eval globals env a in
      apply globals f_v a_v
  | Term.Let (_x, _ty, def, body) ->
      let* def_v = eval globals env def in
      eval globals (def_v :: env) body
  | Term.Ann (tm', _ty) -> eval globals env tm'
  | Term.Auto ->
      (* M4 Stage A: unreachable on checker output; [Auto] never survives
         [Check]. Total backstop. *)
      Error (Error.Cannot_infer "auto")
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      (* M4 Stage A: [scrut_q] is an erasure-time stamp only; kernel
         evaluation keeps full semantics, which subject reduction needs. *)
      let* scrut_v = eval globals env scrut in
      run_match globals env scrut_v motive branches
  | Term.Global name ->
      let* entry =
        Global.find name globals |> Option.to_result ~none:(Error.Unbound_global name)
      in
      (match entry with
      | Global.Ind _ -> Ok (Value.VInd (name, []))
      | Global.Ctor _ -> Ok (Value.VCtor (name, []))
      (* a Prim entry has no [def] to unfold to and no [reducible] flag
         to set: this arm IS the entire kernel-level argument that
         checking can never perform an effect (M3 Stage A). *)
      | Global.Prim _ -> Ok (Value.VNeutral (Value.HGlobal name, []))
      (* M4 Stage B: an [Axiom] has no [def] either, the same opaque
         shape as a [Prim]; [Check] is what forbids it at runtime, not
         [Eval] (this arm is reached only at mode 0). *)
      | Global.Axiom _ -> Ok (Value.VNeutral (Value.HGlobal name, []))
      | Global.Def d ->
          (match () with
          | () when Option.is_some d.Global.rec_arg ->
              (* rec defs start neutral even when reducible: unfolding is
                 decided at application time (guarded) *)
              Ok (Value.VNeutral (Value.HGlobal name, []))
          | () when d.Global.reducible -> eval globals [] d.Global.def
          | () -> Ok (Value.VNeutral (Value.HGlobal name, []))))

(** Reduce a match whose scrutinee value is known. A neutral scrutinee
    freezes the whole match as an [FMatch] frame closing over [env]. *)
and run_match (globals : Global.t) (env : Value.t list) (scrut_v : Value.t)
    (motive : Term.motive option)
    (branches : (string * (Quantity.t * string) list * Term.t) list) :
    (Value.t, Error.t) result =
  match scrut_v with
  | Value.VCtor (cname, args) ->
      let* ctor =
        Global.find_ctor cname globals
        |> Option.to_result ~none:(Error.Unbound_global cname)
      in
      let* ind =
        Global.find_ind ctor.Global.ind globals
        |> Option.to_result ~none:(Error.Unbound_global ctor.Global.ind)
      in
      let n_params = List.length ind.Global.params in
      (* a miss is unreachable on checked terms; total backstop *)
      let* _c, binders, body =
        List.find_opt (fun (b, _bs, _body) -> String.equal b cname) branches
        |> Option.to_result
             ~none:(Error.Branch_mismatch { expected = cname; found = "<none>" })
      in
      let own = List.filteri (fun i _v -> i >= n_params) args in
      (* arity backstop mirroring Interp.run_match: unreachable on
         checked terms, but hand-built or bypassed-Check terms must not
         silently misalign the branch env *)
      let* () =
        if Int.equal (List.length own) (List.length binders) then Ok ()
        else
          Error
            (Error.Branch_mismatch { expected = cname; found = cname ^ " (wrong arity)" })
      in
      eval globals (List.rev_append own env) body
  | Value.VNeutral (h, frames) ->
      Ok (Value.VNeutral (h, Value.FMatch { Value.motive; branches; menv = env } :: frames))
  | Value.VUniv _ | Value.VPi (_, _, _, _) | Value.VLam (_, _) | Value.VInd (_, _)
  (* a checked program cannot reach a VLit scrutinee here: String and
     Int are not eliminable (M3 Stage A). Total backstop. *)
  | Value.VLit _ ->
      Error (Error.Not_inductive "<match on a non-constructor value>")

and apply (globals : Global.t) (f : Value.t) (a : Value.t) : (Value.t, Error.t) result =
  match f with
  | Value.VLam (_x, clo) -> app_closure globals clo a
  | Value.VInd (n, args) -> Ok (Value.VInd (n, args @ [ a ]))
  | Value.VCtor (c, args) -> Ok (Value.VCtor (c, args @ [ a ]))
  | Value.VNeutral (Value.HGlobal n, frames) ->
      let frames' = Value.FApp a :: frames in
      let stuck = Value.VNeutral (Value.HGlobal n, frames') in
      Global.find_def n globals
      |> Fun.flip Option.bind (fun d ->
             if d.Global.reducible then
               Option.map (fun k -> (d.Global.def, k)) d.Global.rec_arg
             else None)
      |> Option.fold ~none:(Ok stuck) ~some:(fun (def, k) ->
             let oldest = List.rev frames' in
             let guarded =
               List.nth_opt (leading_fapp_args oldest) k
               |> Option.fold ~none:false ~some:(is_canonical globals)
             in
             if guarded then
               let* f0 = eval globals [] def in
               replay globals f0 oldest
             else Ok stuck)
  | Value.VNeutral ((Value.HVar _ as h), frames) ->
      Ok (Value.VNeutral (h, Value.FApp a :: frames))
  | Value.VPi (_, _, _, _) -> Error (Error.Not_a_function "<pi value>")
  | Value.VUniv l -> Error (Error.Not_a_function ("Type " ^ Level.to_string l))
  | Value.VLit _ -> Error (Error.Not_a_function "<literal value>")

(** Replay a frame list (oldest first) on top of an unfolded head. *)
and replay (globals : Global.t) (head : Value.t) (frames_oldest : Value.frame list) :
    (Value.t, Error.t) result =
  List.fold_left
    (fun acc fr ->
      let* v = acc in
      match fr with
      | Value.FApp a -> apply globals v a
      | Value.FMatch sm -> run_match globals sm.Value.menv v sm.Value.motive sm.Value.branches)
    (Ok head) frames_oldest

and app_closure (globals : Global.t) (clo : Value.closure) (arg : Value.t) :
    (Value.t, Error.t) result =
  eval globals (arg :: clo.Value.env) clo.Value.body

and quote (globals : Global.t) (size : int) (v : Value.t) : (Term.t, Error.t) result =
  match v with
  | Value.VUniv l -> Ok (Term.Univ l)
  | Value.VLit l -> Ok (Term.Lit l)
  | Value.VPi (q, x, dom, clo) ->
      let* dom_t = quote globals size dom in
      let* cod_v = app_closure globals clo (Value.var size) in
      let* cod_t = quote globals (size + 1) cod_v in
      Ok (Term.Pi (q, x, dom_t, cod_t))
  | Value.VLam (x, clo) ->
      let* body_v = app_closure globals clo (Value.var size) in
      let* body_t = quote globals (size + 1) body_v in
      (* quoted terms feed display and conversion only, never erasure, so
         a [Many] placeholder stamp is fine here *)
      Ok (Term.Lam (Quantity.Many, x, body_t))
  | Value.VInd (n, args) | Value.VCtor (n, args) ->
      List.fold_left
        (fun acc arg ->
          let* f = acc in
          let* arg_t = quote globals size arg in
          Ok (Term.App (Quantity.Many, f, arg_t)))
        (Ok (Term.Global n)) args
  | Value.VNeutral (h, frames) ->
      let* head_t =
        match h with
        | Value.HVar lvl ->
            let ix = size - lvl - 1 in
            if ix >= 0 then Ok (Term.Var ix) else Error (Error.Bad_level lvl)
        | Value.HGlobal n -> Ok (Term.Global n)
      in
      List.fold_left
        (fun acc fr ->
          let* f = acc in
          match fr with
          | Value.FApp arg ->
              let* arg_t = quote globals size arg in
              Ok (Term.App (Quantity.Many, f, arg_t))
          | Value.FMatch sm ->
              (* M4 Stage A: a motive now closes over [m + 1] binders;
                 [m = 0] degenerates exactly to the M2/M3 single-binder
                 shape.  M4 fixes round 4 (ctxcat r4 id 0): "index"
                 below means DE BRUIJN index, not a position in
                 [m_idx].  [m_idx] itself is in DECLARATION order
                 (outermost first, see [Term.motive]); inside [m_body]
                 de Bruijn 0 is the scrutinee and de Bruijn [1..m] are
                 the index binders in the REVERSE of [m_idx], which is
                 what [idx_env] builds: its k-th element (de Bruijn
                 [k + 1]) is the level [size + m - 1 - k], so the FIRST
                 element of [m_idx] gets the LOWEST level [size] and
                 the last gets [size + m - 1].  This is the same
                 reversal [Pp.term] performs with [List.rev m_idx]. *)
              let* motive_t =
                sm.Value.motive
                |> Option.fold ~none:(Ok None) ~some:(fun (mo : Term.motive) ->
                       let m = List.length mo.Term.m_idx in
                       let idx_env = List.init m (fun i -> Value.var (size + m - 1 - i)) in
                       let menv' = Value.var (size + m) :: (idx_env @ sm.Value.menv) in
                       let* mot_v = eval globals menv' mo.Term.m_body in
                       let* mot_t = quote globals (size + m + 1) mot_v in
                       Ok
                         (Some
                            {
                              Term.m_ind = mo.Term.m_ind;
                              m_idx = mo.Term.m_idx;
                              m_self = mo.Term.m_self;
                              m_body = mot_t;
                            }))
              in
              let* branches_t =
                List.fold_left
                  (fun bacc (c, binders, body) ->
                    let* done_ = bacc in
                    let arity = List.length binders in
                    let fresh_env =
                      List.init arity (fun i -> Value.var (size + arity - 1 - i))
                    in
                    let* body_v = eval globals (fresh_env @ sm.Value.menv) body in
                    let* body_t = quote globals (size + arity) body_v in
                    Ok ((c, binders, body_t) :: done_))
                  (Ok []) sm.Value.branches
                |> Result.map List.rev
              in
              (* quoted terms feed display and conversion only, never
                 erasure, so a [Many] placeholder [scrut_q] is fine here
                 (same convention as [Term.Lam]'s quoted stamp above). *)
              Ok
                (Term.Match
                   { scrut = f; scrut_q = Quantity.Many; motive = motive_t; branches = branches_t }))
        (Ok head_t) (List.rev frames)

and conv (globals : Global.t) (size : int) (a : Value.t) (b : Value.t) :
    (bool, Error.t) result =
  match (a, b) with
  | Value.VUniv l1, Value.VUniv l2 -> Ok (Level.equal l1 l2)
  | Value.VPi (q1, _x1, dom1, clo1), Value.VPi (q2, _x2, dom2, clo2) ->
      let* dom_eq = conv globals size dom1 dom2 in
      (match () with
      | () when not (Quantity.equal q1 q2) -> Ok false
      | () when not dom_eq -> Ok false
      | () ->
          let fresh = Value.var size in
          let* cod1 = app_closure globals clo1 fresh in
          let* cod2 = app_closure globals clo2 fresh in
          conv globals (size + 1) cod1 cod2)
  | Value.VLam (_x1, clo1), Value.VLam (_x2, clo2) ->
      let fresh = Value.var size in
      let* b1 = app_closure globals clo1 fresh in
      let* b2 = app_closure globals clo2 fresh in
      conv globals (size + 1) b1 b2
  | Value.VLam (_x, clo), Value.VNeutral (h, frames) ->
      let fresh = Value.var size in
      let* b1 = app_closure globals clo fresh in
      conv globals (size + 1) b1 (Value.VNeutral (h, Value.FApp fresh :: frames))
  | Value.VNeutral (h, frames), Value.VLam (_x, clo) ->
      let fresh = Value.var size in
      let* b2 = app_closure globals clo fresh in
      conv globals (size + 1) (Value.VNeutral (h, Value.FApp fresh :: frames)) b2
  | Value.VInd (n1, args1), Value.VInd (n2, args2) ->
      if String.equal n1 n2 then conv_args globals size args1 args2 else Ok false
  | Value.VCtor (c1, args1), Value.VCtor (c2, args2) ->
      if String.equal c1 c2 then conv_args globals size args1 args2 else Ok false
  | Value.VNeutral (h1, fs1), Value.VNeutral (h2, fs2) ->
      if conv_head h1 h2 then conv_frames globals size fs1 fs2 else Ok false
  | Value.VLit a1, Value.VLit a2 -> Ok (Literal.equal a1 a2)
  (* a literal is never convertible with any other value shape (M3
     Stage A), in both directions *)
  | ( Value.VLit _,
      ( Value.VUniv _
      | Value.VPi (_, _, _, _)
      | Value.VLam (_, _)
      | Value.VInd (_, _)
      | Value.VCtor (_, _)
      | Value.VNeutral (_, _) ) ) ->
      Ok false
  | ( ( Value.VUniv _
      | Value.VPi (_, _, _, _)
      | Value.VLam (_, _)
      | Value.VInd (_, _)
      | Value.VCtor (_, _)
      | Value.VNeutral (_, _) ),
      Value.VLit _ ) ->
      Ok false
  (* cross-shape pairs are definitionally distinct (no eta for inductives:
     a neutral never equals a ctor value) *)
  | ( Value.VUniv _,
      ( Value.VPi (_, _, _, _)
      | Value.VLam (_, _)
      | Value.VInd (_, _)
      | Value.VCtor (_, _)
      | Value.VNeutral (_, _) ) ) ->
      Ok false
  | ( ( Value.VPi (_, _, _, _)
      | Value.VLam (_, _)
      | Value.VInd (_, _)
      | Value.VCtor (_, _)
      | Value.VNeutral (_, _) ),
      Value.VUniv _ ) ->
      Ok false
  | ( Value.VPi (_, _, _, _),
      (Value.VLam (_, _) | Value.VInd (_, _) | Value.VCtor (_, _) | Value.VNeutral (_, _))
    ) ->
      Ok false
  | ( (Value.VLam (_, _) | Value.VInd (_, _) | Value.VCtor (_, _) | Value.VNeutral (_, _)),
      Value.VPi (_, _, _, _) ) ->
      Ok false
  | Value.VLam (_, _), (Value.VInd (_, _) | Value.VCtor (_, _)) -> Ok false
  | (Value.VInd (_, _) | Value.VCtor (_, _)), Value.VLam (_, _) -> Ok false
  | Value.VInd (_, _), (Value.VCtor (_, _) | Value.VNeutral (_, _)) -> Ok false
  | (Value.VCtor (_, _) | Value.VNeutral (_, _)), Value.VInd (_, _) -> Ok false
  | Value.VCtor (_, _), Value.VNeutral (_, _) -> Ok false
  | Value.VNeutral (_, _), Value.VCtor (_, _) -> Ok false

and conv_head (h1 : Value.head) (h2 : Value.head) : bool =
  match (h1, h2) with
  | Value.HVar l1, Value.HVar l2 -> Int.equal l1 l2
  | Value.HGlobal n1, Value.HGlobal n2 -> String.equal n1 n2
  | Value.HVar _, Value.HGlobal _ -> false
  | Value.HGlobal _, Value.HVar _ -> false

and conv_args (globals : Global.t) (size : int) (a1 : Value.t list) (a2 : Value.t list) :
    (bool, Error.t) result =
  match (a1, a2) with
  | [], [] -> Ok true
  | v1 :: r1, v2 :: r2 ->
      let* head_eq = conv globals size v1 v2 in
      if head_eq then conv_args globals size r1 r2 else Ok false
  | [], _v :: _ -> Ok false
  | _v :: _, [] -> Ok false

and conv_frames (globals : Global.t) (size : int) (fs1 : Value.frame list)
    (fs2 : Value.frame list) : (bool, Error.t) result =
  match (fs1, fs2) with
  | [], [] -> Ok true
  | Value.FApp v1 :: r1, Value.FApp v2 :: r2 ->
      let* head_eq = conv globals size v1 v2 in
      if head_eq then conv_frames globals size r1 r2 else Ok false
  | Value.FMatch m1 :: r1, Value.FMatch m2 :: r2 ->
      let* head_eq = conv_stuck_match globals size m1 m2 in
      if head_eq then conv_frames globals size r1 r2 else Ok false
  | Value.FApp _ :: _, Value.FMatch _ :: _ -> Ok false
  | Value.FMatch _ :: _, Value.FApp _ :: _ -> Ok false
  | [], _f :: _ -> Ok false
  | _f :: _, [] -> Ok false

and conv_stuck_match (globals : Global.t) (size : int) (m1 : Value.stuck_match)
    (m2 : Value.stuck_match) : (bool, Error.t) result =
  (* M4 Stage A: motives compare under the same [m + 1] fresh variables;
     differing [m_idx] LENGTHS are [Ok false]; [m_ind] is IGNORED (a
     materialized constant motive writes [None] while an explicit one
     writes [Some "Vec"], and those two must still compare equal). *)
  let* mot_eq =
    m1.Value.motive
    |> Option.fold
         ~none:(Ok (Option.is_none m2.Value.motive))
         ~some:(fun (mo1 : Term.motive) ->
           m2.Value.motive
           |> Option.fold ~none:(Ok false) ~some:(fun (mo2 : Term.motive) ->
                  let m1_idx = List.length mo1.Term.m_idx in
                  let m2_idx = List.length mo2.Term.m_idx in
                  match () with
                  | () when not (Int.equal m1_idx m2_idx) -> Ok false
                  | () ->
                      let idx_env =
                        List.init m1_idx (fun i -> Value.var (size + m1_idx - 1 - i))
                      in
                      let self_v = Value.var (size + m1_idx) in
                      let env1 = self_v :: (idx_env @ m1.Value.menv) in
                      let env2 = self_v :: (idx_env @ m2.Value.menv) in
                      let* v1 = eval globals env1 mo1.Term.m_body in
                      let* v2 = eval globals env2 mo2.Term.m_body in
                      conv globals (size + m1_idx + 1) v1 v2))
  in
  if mot_eq then
    conv_match_branches globals size m1.Value.menv m2.Value.menv m1.Value.branches
      m2.Value.branches
  else Ok false

and conv_match_branches (globals : Global.t) (size : int) (menv1 : Value.t list)
    (menv2 : Value.t list) (bs1 : (string * (Quantity.t * string) list * Term.t) list)
    (bs2 : (string * (Quantity.t * string) list * Term.t) list) : (bool, Error.t) result
    =
  match (bs1, bs2) with
  | [], [] -> Ok true
  | (c1, binders1, b1) :: r1, (c2, binders2, b2) :: r2 ->
      let arity = List.length binders1 in
      (match () with
      | () when not (String.equal c1 c2) -> Ok false
      | () when not (Int.equal arity (List.length binders2)) -> Ok false
      | () ->
          let fresh_env = List.init arity (fun i -> Value.var (size + arity - 1 - i)) in
          let* v1 = eval globals (fresh_env @ menv1) b1 in
          let* v2 = eval globals (fresh_env @ menv2) b2 in
          let* head_eq = conv globals (size + arity) v1 v2 in
          if head_eq then conv_match_branches globals size menv1 menv2 r1 r2 else Ok false)
  | [], _b :: _ -> Ok false
  | _b :: _, [] -> Ok false
