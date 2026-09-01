(** Structural totality guard for top-level [def rec]. Runs on the STAMPED
    body the checker returns. The body's leading lambdas are the formals;
    the guard searches for a principal argument position [k] (first fit
    wins) such that every occurrence of the recursive global is a call
    whose argument [k] is a variable made structurally smaller by a match
    on the principal (or on something already smaller). *)

(** Status of one binder, tracked newest first alongside de Bruijn use. *)
type status =
  | Principal  (** the candidate formal itself *)
  | Smaller  (** bound by a match branch over a Principal/Smaller var *)
  | Other

(** Count the leading lambdas and return the inner body. *)
let rec peel (n : int) (t : Term.t) : int * Term.t =
  match t with
  | Term.Lam (_q, _x, b) -> peel (n + 1) b
  | Term.Var _ | Term.Univ _
  | Term.Pi (_, _, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Match _ ->
      (n, t)

(** Collect an application spine: head plus args oldest first. *)
let rec spine (t : Term.t) (args : Term.t list) : Term.t * Term.t list =
  match t with
  | Term.App (_q, f, a) -> spine f (a :: args)
  | Term.Var _ | Term.Univ _
  | Term.Pi (_, _, _, _)
  | Term.Lam (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Match _ ->
      (t, args)

let status_at (st : status list) (ix : int) : status option = List.nth_opt st ix

(** Does candidate position [k] guard every recursive occurrence? *)
let passes ~(recname : string) (k : int) (formals : int) (body : Term.t) : bool =
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
           | Term.Univ _
           | Term.Pi (_, _, _, _)
           | Term.Lam (_, _, _)
           | Term.App (_, _, _)
           | Term.Let (_, _, _, _)
           | Term.Ann (_, _)
           | Term.Global _ | Term.Match _ ->
               false)
  in
  let rec ok (st : status list) (t : Term.t) : bool =
    match t with
    | Term.Var _ -> true
    | Term.Univ _ -> true
    (* a bare (unapplied) occurrence of the rec global always fails *)
    | Term.Global g -> not (String.equal g recname)
    | Term.App (_q, _f, _a) ->
        let head, args = spine t [] in
        let head_ok =
          match head with
          | Term.Global g when String.equal g recname -> guarded_call st args
          | Term.Global _ -> true
          | Term.Var _ | Term.Univ _ -> true
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
    | Term.Match { scrut; motive; branches } ->
        let scrut_special =
          match scrut with
          | Term.Var ix -> principal_or_smaller_at st ix
          | Term.Univ _
          | Term.Pi (_, _, _, _)
          | Term.Lam (_, _, _)
          | Term.App (_, _, _)
          | Term.Let (_, _, _, _)
          | Term.Ann (_, _)
          | Term.Global _ | Term.Match _ ->
              false
        in
        let binder_status = if scrut_special then Smaller else Other in
        let motive_ok =
          motive |> Option.fold ~none:true ~some:(fun (_x, mot) -> ok (Other :: st) mot)
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
    stamped body of [def rec recname] is structurally recursive. *)
let guard ~(recname : string) (body : Term.t) : (int, Error.t) result =
  let formals, inner = peel 0 body in
  let rec first_fit (k : int) : (int, Error.t) result =
    match () with
    | () when k >= formals -> Error (Error.Termination recname)
    | () when passes ~recname k formals inner -> Ok k
    | () -> first_fit (k + 1)
  in
  first_fit 0
