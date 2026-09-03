(** Structural totality guard for top-level [def rec]. Runs on the STAMPED
    body the checker returns. The body's leading lambdas are the formals;
    the guard searches for a principal argument position [k] (first fit
    wins) such that every occurrence of the recursive global is a call
    whose argument [k] is a variable made structurally smaller by a match
    on the principal (or on something already smaller). *)

(** M6 Stage A (verdict pin 8, ruling R1): the totality rule [guard]
    runs.  A single-constructor type ON PURPOSE.  [Check.define]
    keeps its REQUIRED named [~rule] argument, every call site names
    [Structural], and every match on [rule] is exhaustive with no
    wildcard, so an M7 admission rule (the WF package) re-enters by
    compiler error at every consumer.  The M5 [Structural_wf] spike
    is DELETED, not dark: re-entry is a rebuild of the [Term.App] arm
    of [guarded_call] below, against the pin-9 oracle fixtures
    (test/fixtures/bad2.tot, crossformal-t.tot, deep2.tot), and any
    such rule must carry a PROVENANCE side condition tying the
    Smaller head to the candidate position (the seed invariant, SPEC
    section 2 entry dated 2026-09-03). *)
type rule = Structural

(** Status of one binder, tracked newest first alongside de Bruijn use. *)
type status =
  | Principal  (** the candidate formal itself *)
  | Smaller  (** bound by a match branch over a Principal/Smaller var *)
  | Other

(** Count the leading lambdas and return the inner body. *)
let rec peel (n : int) (t : Term.t) : int * Term.t =
  match t with
  | Term.Lam (_q, _x, b) -> peel (n + 1) b
  | Term.Var _ | Term.Univ _ | Term.Auto
  | Term.Pi (_, _, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Match _ | Term.Lit _ ->
      (n, t)

(** Collect an application spine: head plus args oldest first. *)
let rec spine (t : Term.t) (args : Term.t list) : Term.t * Term.t list =
  match t with
  | Term.App (_q, f, a) -> spine f (a :: args)
  | Term.Var _ | Term.Univ _ | Term.Auto
  | Term.Pi (_, _, _, _)
  | Term.Lam (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Match _ | Term.Lit _ ->
      (t, args)

(** Does [name] occur anywhere in [t] as a [Term.Global]? Structural,
    total, exhaustive over every [Term.t] arm; used to tell a genuinely
    recursive [def rec] body from one that merely carries the [rec]
    keyword (in which case the totality guard is skipped entirely rather
    than vacuously satisfied at the first formal). *)
let rec mentions (name : string) (t : Term.t) : bool =
  match t with
  | Term.Var _ -> false
  | Term.Univ _ -> false
  | Term.Lit _ -> false
  | Term.Auto -> false
  | Term.Global g -> String.equal g name
  | Term.Pi (_q, _x, dom, cod) -> mentions name dom || mentions name cod
  | Term.Lam (_q, _x, body) -> mentions name body
  | Term.App (_q, f, a) -> mentions name f || mentions name a
  | Term.Let (_x, ty, def, body) ->
      mentions name ty || mentions name def || mentions name body
  | Term.Ann (tm, ty) -> mentions name tm || mentions name ty
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      mentions name scrut
      || (motive
         |> Option.fold ~none:false ~some:(fun (mo : Term.motive) ->
                mentions name mo.Term.m_body))
      || List.exists (fun (_c, _binders, body) -> mentions name body) branches

let status_at (st : status list) (ix : int) : status option = List.nth_opt st ix

(** Does candidate position [k] guard every recursive occurrence? *)
let passes ~(rule : rule) ~(recname : string) (k : int) (formals : int) (body : Term.t) :
    bool =
  let smaller_at (st : status list) (ix : int) : bool =
    status_at st ix
    |> Option.fold ~none:false ~some:(fun s ->
           match s with
           | Smaller -> true
           | Principal | Other -> false)
  in
  let principal_or_smaller_at (st : status list) (ix : int) : bool =
    status_at st ix
    |> Option.fold ~none:false ~some:(fun s ->
           match s with
           | Principal | Smaller -> true
           | Other -> false)
  in
  (* the recursive call's argument [k] must be a var with status Smaller *)
  let guarded_call (st : status list) (args : Term.t list) : bool =
    List.nth_opt args k
    |> Option.fold ~none:false ~some:(fun a ->
           match a with
           | Term.Var ix -> smaller_at st ix
           | Term.App (_, _, _) -> (
               (* M6 Stage A: the M5 spike's accessibility clause is
                  deleted (ruling R1).  A call whose argument [k] is
                  an APPLICATION is never guarded, which is the M2
                  rule byte for byte.  The match on [rule] is kept so
                  the M7 rule re-enters HERE by non-exhaustiveness. *)
               match rule with
               | Structural -> false)
           | Term.Univ _ | Term.Auto
           | Term.Pi (_, _, _, _)
           | Term.Lam (_, _, _)
           | Term.Let (_, _, _, _)
           | Term.Ann (_, _)
           | Term.Global _ | Term.Match _ | Term.Lit _ ->
               false)
  in
  let rec ok (st : status list) (t : Term.t) : bool =
    match t with
    | Term.Var _ -> true
    | Term.Univ _ -> true
    | Term.Lit _ -> true
    | Term.Auto -> true
    (* a bare (unapplied) occurrence of the rec global always fails *)
    | Term.Global g -> not (String.equal g recname)
    | Term.App (_q, _f, _a) ->
        let head, args = spine t [] in
        let head_ok =
          match head with
          | Term.Global g when String.equal g recname -> guarded_call st args
          | Term.Global _ -> true
          | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Auto -> true
          | Term.Pi (_, _, _, _)
          | Term.Lam (_, _, _)
          | Term.App (_, _, _) (* unreachable: [spine] never returns an App head *)
          | Term.Let (_, _, _, _)
          | Term.Ann (_, _)
          | Term.Match _ ->
              ok st head
        in
        head_ok && List.for_all (ok st) args
    | Term.Pi (_q, _x, dom, cod) -> ok st dom && ok (Other :: st) cod
    | Term.Lam (_q, _x, b) -> ok (Other :: st) b
    | Term.Let (_x, ty, def, b) -> ok st ty && ok st def && ok (Other :: st) b
    | Term.Ann (tm, ty) -> ok st tm && ok st ty
    | Term.Match { scrut; scrut_q = _; motive; branches } ->
        let scrut_special =
          match scrut with
          | Term.Var ix -> principal_or_smaller_at st ix
          | Term.Univ _ | Term.Auto
          | Term.Pi (_, _, _, _)
          | Term.Lam (_, _, _)
          | Term.App (_, _, _)
          | Term.Let (_, _, _, _)
          | Term.Ann (_, _)
          | Term.Global _ | Term.Match _ | Term.Lit _ ->
              false
        in
        let binder_status = if scrut_special then Smaller else Other in
        (* M4 Stage A: the motive body is walked under [m + 1] binders of
           status [Other] (one per index binder, plus the scrutinee
           binder); indices add no branch binders, so [branch_ok] below
           stays byte-for-byte M2's. *)
        let motive_ok =
          motive
          |> Option.fold ~none:true ~some:(fun (mo : Term.motive) ->
                 let st_m =
                   List.fold_left (fun acc _y -> Other :: acc) (Other :: st) mo.Term.m_idx
                 in
                 ok st_m mo.Term.m_body)
        in
        let branch_ok (_c, binders, bbody) =
          let st' = List.fold_left (fun acc _b -> binder_status :: acc) st binders in
          ok st' bbody
        in
        ok st scrut && motive_ok && List.for_all branch_ok branches
  in
  let seed =
    List.init formals (fun ix -> if Int.equal ix (formals - 1 - k) then Principal else Other)
  in
  ok seed body

(** Find the first formal position (0-based, outermost first) on which the
    stamped body of [def rec recname] is structurally recursive under
    [Structural], the single shipped rule (M6 Stage A, pin 8: an M7
    admission rule re-enters through [type rule] and the [Term.App] arm
    of [guarded_call], never through a driver flag). *)
let guard ~(rule : rule) ~(recname : string) (body : Term.t) : (int, Error.t) result =
  let formals, inner = peel 0 body in
  let rec first_fit (k : int) : (int, Error.t) result =
    match () with
    | () when k >= formals -> Error (Error.Termination recname)
    | () when passes ~rule ~recname k formals inner -> Ok k
    | () -> first_fit (k + 1)
  in
  first_fit 0
