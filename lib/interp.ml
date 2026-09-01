(** Call-by-value interpreter over erased terms. Reducibility never
    reaches this module (that is a conversion-time notion); every
    non-rec global still unfolds unconditionally at application time,
    exactly as before. A rec global, however, carries its kernel
    [rec_arg] into the runtime global table and unfolds only when its
    principal argument is a canonical (fully applied) constructor value:
    applying it before that starts (or extends) a neutral application
    under the new [EHGlobal] head, mirroring the kernel's [Value.HGlobal]
    guarded-unfolding discipline (see [Eval]). Without this a rec
    global's cached closure would unfold eagerly under [quote]'s fresh
    neutral binders, re-freezing one level deeper on every peel and
    diverging; readback of a rec function value is now total. [VNeut]
    also still serves its original role: [quote] applies closures to
    fresh neutral variables to reach under binders, and a match stuck on
    such a variable freezes its branches as an [FEMatch] frame. *)

let ( let* ) = Result.bind

type v =
  | VClos of string * v list * Eterm.t
  | VCon of string * v list  (** data ctor applied; KEPT args only, in order *)
  | VNeut of ehead * eframe list  (** head + frames, newest first *)
  | VErased

and ehead =
  | EHVar of int  (** readback: a fresh binder introduced by [quote] *)
  | EHGlobal of string
      (** a rec global whose principal argument is not yet known
          canonical; frames accumulate here until the guard is met *)

and eframe =
  | FEApp of v
  | FEMatch of (string * string list * Eterm.t) list * v list
      (** frozen branches + the env their bodies close over *)

(** One runtime global binding. [gval] is the value [EGlobal] resolves to
    when the guard does not apply (a non-rec def's cached closure, a
    ctor's growing [VCon], or [VErased] for an inert type constructor);
    for a rec def it also doubles as the closure [replay] unfolds onto
    once the guard is satisfied. [grec_arg]: [Some k] marks a rec def
    guarded on argument [k]; [None] covers every other kind of entry,
    including a plain (non-rec) def. [gctor_arity]: [Some n] marks a
    data constructor whose KEPT (quantity-`w`) arity is [n], the runtime
    analogue of [Eval.is_canonical]'s full-arity check (erased args and
    params never reach a runtime [VCon]). *)
type gentry = {
  gval : v;
  grec_arg : int option;
  gctor_arity : int option;
}

type globals = gentry Global.StringMap.t

let empty_globals : globals = Global.StringMap.empty

(** The leading (oldest-first) run of [FEApp] argument values of a frame
    list ALREADY reversed to oldest-first order. Mirrors
    [Eval.leading_fapp_args]. *)
let rec leading_fapp_args (frames : eframe list) : v list =
  match frames with
  | [] -> []
  | FEApp v :: rest -> v :: leading_fapp_args rest
  | FEMatch (_, _) :: _rest -> []

(** Canonical means: a data constructor fully applied, counting only its
    KEPT args (erasure already dropped quantity-0 args and every param
    before an [Eterm] value exists at all). An unknown ctor name cannot
    occur on a checked, erased program; total via [Option.fold], no
    error path needed here (mirrors [Eval.is_canonical]). *)
let is_canonical (eglobals : globals) (v : v) : bool =
  match v with
  | VCon (c, args) ->
      Global.StringMap.find_opt c eglobals
      |> Fun.flip Option.bind (fun (g : gentry) -> g.gctor_arity)
      |> Option.fold ~none:false ~some:(fun arity -> Int.equal (List.length args) arity)
  | VClos (_, _, _) | VNeut (_, _) | VErased -> false

let rec exec (eglobals : globals) (env : v list) (e : Eterm.t) : (v, Error.t) result =
  match e with
  | Eterm.EVar ix -> List.nth_opt env ix |> Option.to_result ~none:(Error.Unbound_var ix)
  | Eterm.ELam (x, body) -> Ok (VClos (x, env, body))
  | Eterm.EApp (f, a) ->
      let* f_v = exec eglobals env f in
      let* a_v = exec eglobals env a in
      apply eglobals f_v a_v
  | Eterm.ELet (_x, def, body) ->
      let* def_v = exec eglobals env def in
      exec eglobals (def_v :: env) body
  | Eterm.EGlobal name ->
      Global.StringMap.find_opt name eglobals
      |> Option.to_result ~none:(Error.Unbound_global name)
      |> Result.map (fun (g : gentry) ->
             g.grec_arg |> Option.fold ~none:g.gval ~some:(fun _k -> VNeut (EHGlobal name, [])))
  | Eterm.EErased -> Ok VErased
  | Eterm.EMatch (scrut, branches) ->
      let* scrut_v = exec eglobals env scrut in
      run_match eglobals env scrut_v branches

and run_match (eglobals : globals) (env : v list) (scrut_v : v)
    (branches : (string * string list * Eterm.t) list) : (v, Error.t) result =
  match scrut_v with
  | VCon (c, args) ->
      (* a miss is unreachable on checked programs; total backstop *)
      let* _c, binders, body =
        List.find_opt (fun (b, _bs, _body) -> String.equal b c) branches
        |> Option.to_result ~none:(Error.Branch_mismatch { expected = c; found = "<none>" })
      in
      if Int.equal (List.length binders) (List.length args) then
        exec eglobals (List.rev_append args env) body
      else
        Error (Error.Branch_mismatch { expected = c; found = c ^ " (wrong runtime arity)" })
  | VNeut (h, frames) -> Ok (VNeut (h, FEMatch (branches, env) :: frames))
  | VClos (_, _, _) | VErased ->
      Error (Error.Not_inductive "<runtime match on a non-constructor>")

and apply (eglobals : globals) (f : v) (a : v) : (v, Error.t) result =
  match f with
  | VClos (_x, env, body) -> exec eglobals (a :: env) body
  | VCon (c, args) -> Ok (VCon (c, args @ [ a ]))
  | VNeut (EHGlobal name, frames) ->
      let frames' = FEApp a :: frames in
      let stuck = VNeut (EHGlobal name, frames') in
      Global.StringMap.find_opt name eglobals
      |> Fun.flip Option.bind (fun (g : gentry) ->
             Option.map (fun k -> (g.gval, k)) g.grec_arg)
      |> Option.fold ~none:(Ok stuck) ~some:(fun (gval, k) ->
             let oldest = List.rev frames' in
             let guarded =
               List.nth_opt (leading_fapp_args oldest) k
               |> Option.fold ~none:false ~some:(is_canonical eglobals)
             in
             if guarded then replay eglobals gval oldest else Ok stuck)
  | VNeut ((EHVar _ as h), frames) -> Ok (VNeut (h, FEApp a :: frames))
  | VErased -> Error (Error.Not_a_function "<erased>")

(** Replay a frame list (oldest first) on top of an unfolded head. Mirrors
    [Eval.replay]. *)
and replay (eglobals : globals) (head : v) (frames_oldest : eframe list) : (v, Error.t) result
    =
  List.fold_left
    (fun acc fr ->
      let* v = acc in
      match fr with
      | FEApp a -> apply eglobals v a
      | FEMatch (branches, menv) -> run_match eglobals menv v branches)
    (Ok head) frames_oldest

let define (eglobals : globals) ~(name : string) ~(rec_arg : int option) (def : Eterm.t) :
    (globals, Error.t) result =
  let* v = exec eglobals [] def in
  Ok (Global.StringMap.add name { gval = v; grec_arg = rec_arg; gctor_arity = None } eglobals)

(** Seed a data constructor: it accumulates its runtime (KEPT) arguments
    up to [arity]. *)
let add_ctor (eglobals : globals) ~(name : string) ~(arity : int) : globals =
  Global.StringMap.add name
    { gval = VCon (name, []); grec_arg = None; gctor_arity = Some arity }
    eglobals

(** Seed a type constructor: types are inert at runtime. *)
let add_erased (eglobals : globals) ~(name : string) : globals =
  Global.StringMap.add name { gval = VErased; grec_arg = None; gctor_arity = None } eglobals

let rec quote (eglobals : globals) (size : int) (v : v) : (Eterm.t, Error.t) result =
  match v with
  | VClos (x, _env, _body) as clo ->
      let* body_v = apply eglobals clo (VNeut (EHVar size, [])) in
      let* body_e = quote eglobals (size + 1) body_v in
      Ok (Eterm.ELam (x, body_e))
  | VCon (c, args) ->
      List.fold_left
        (fun acc arg ->
          let* f = acc in
          let* arg_e = quote eglobals size arg in
          Ok (Eterm.EApp (f, arg_e)))
        (Ok (Eterm.EGlobal c)) args
  | VNeut (h, frames) ->
      let* head_e =
        match h with
        | EHVar lvl ->
            let ix = size - lvl - 1 in
            if ix >= 0 then Ok (Eterm.EVar ix) else Error (Error.Bad_level lvl)
        | EHGlobal name -> Ok (Eterm.EGlobal name)
      in
      List.fold_left
        (fun acc fr ->
          let* f = acc in
          match fr with
          | FEApp arg ->
              let* arg_e = quote eglobals size arg in
              Ok (Eterm.EApp (f, arg_e))
          | FEMatch (branches, menv) ->
              let* branches_e =
                List.fold_left
                  (fun bacc (c, binders, body) ->
                    let* done_ = bacc in
                    let arity = List.length binders in
                    let fresh_env =
                      List.init arity (fun i -> VNeut (EHVar (size + arity - 1 - i), []))
                    in
                    let* body_v = exec eglobals (fresh_env @ menv) body in
                    let* body_e = quote eglobals (size + arity) body_v in
                    Ok ((c, binders, body_e) :: done_))
                  (Ok []) branches
                |> Result.map List.rev
              in
              Ok (Eterm.EMatch (f, branches_e)))
        (Ok head_e) (List.rev frames)
  | VErased -> Ok Eterm.EErased
