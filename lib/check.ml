(** Bidirectional typechecking with 0/omega quantity modes. Every pass
    RETURNS a stamped term: [Lam]/[App] quantities in checker output come
    from the Pi checked against, never from the input placeholder, [Ann]
    is dropped from output (annotations steer checking only), and match
    branch binders are stamped from the constructor telescope. This makes
    checker output the one authority erasure needs. [define],
    [declare_ind] and [define_ind] are the only public ways to extend the
    global environment. *)

let ( let* ) = Result.bind

type ctx = {
  env : Value.t list;
  locals : (string * Quantity.t * Value.t) list;
  size : int;
}

let empty_ctx : ctx = { env = []; locals = []; size = 0 }

let bind (x : string) (q : Quantity.t) (ty : Value.t) (ctx : ctx) : ctx =
  { env = Value.var ctx.size :: ctx.env; locals = (x, q, ty) :: ctx.locals; size = ctx.size + 1 }

let bind_def (x : string) (ty : Value.t) (v : Value.t) (ctx : ctx) : ctx =
  { env = v :: ctx.env; locals = (x, Quantity.Many, ty) :: ctx.locals; size = ctx.size + 1 }

let pp_value (globals : Global.t) (size : int) (v : Value.t) : string =
  Eval.quote globals size v
  |> Result.fold ~ok:(Pp.term []) ~error:(fun _e -> "<unprintable>")

let rec infer (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (tm : Term.t) :
    (Term.t * Value.t, Error.t) result =
  match tm with
  | Term.Var ix ->
      let* x, q, ty =
        List.nth_opt ctx.locals ix |> Option.to_result ~none:(Error.Unbound_var ix)
      in
      (match () with
      | () when Quantity.equal mode Quantity.Zero -> Ok (Term.Var ix, ty)
      | () when Quantity.equal q Quantity.Many -> Ok (Term.Var ix, ty)
      | () -> Error (Error.Erased_use x))
  | Term.Univ l -> Ok (tm, Value.VUniv (Level.succ l))
  | Term.Pi (q, x, dom, cod) ->
      let* dom', dom_l = infer_univ globals ctx dom in
      let* dom_v = Eval.eval globals ctx.env dom' in
      let* cod', cod_l = infer_univ globals (bind x q dom_v ctx) cod in
      Ok (Term.Pi (q, x, dom', cod'), Value.VUniv (Level.max dom_l cod_l))
  | Term.Lam (_q, x, _body) ->
      Error (Error.Cannot_infer (Printf.sprintf "the bare lambda (binder %s)" x))
  | Term.App (_q, f, a) ->
      let* f', f_ty = infer globals ctx mode f in
      (match f_ty with
      | Value.VPi (q, _x, dom, clo) ->
          let* a' = check globals ctx (Quantity.mul mode q) a dom in
          (* instantiate the codomain with the STAMPED argument so every
             downstream value is built from checker output *)
          let* a_v = Eval.eval globals ctx.env a' in
          let* res_ty = Eval.app_closure globals clo a_v in
          Ok (Term.App (q, f', a'), res_ty)
      | Value.VUniv _
      | Value.VLam (_, _)
      | Value.VInd (_, _)
      | Value.VCtor (_, _)
      | Value.VNeutral (_, _) ->
          Error (Error.Not_a_function (pp_value globals ctx.size f_ty)))
  | Term.Let (x, ty, def, body) ->
      let* ty', _ty_l = infer_univ globals ctx ty in
      let* ty_v = Eval.eval globals ctx.env ty' in
      let* def' = check globals ctx mode def ty_v in
      let* def_v = Eval.eval globals ctx.env def' in
      let* body', body_ty = infer globals (bind_def x ty_v def_v ctx) mode body in
      Ok (Term.Let (x, ty', def', body'), body_ty)
  | Term.Ann (tm', ty) ->
      let* ty', _ty_l = infer_univ globals ctx ty in
      let* ty_v = Eval.eval globals ctx.env ty' in
      let* tm'' = check globals ctx mode tm' ty_v in
      Ok (tm'', ty_v)
  | Term.Match { scrut; motive; branches } ->
      let* scrut', iname, p_vals, ctor_names = match_scrut globals ctx mode scrut in
      let* x, mot =
        motive
        |> Option.to_result ~none:(Error.Cannot_infer "a match without 'as .. return'")
      in
      let ctx_m = bind x Quantity.Many (Value.VInd (iname, p_vals)) ctx in
      let* mot', _mot_l = infer_univ globals ctx_m mot in
      let expected_of (c : string) (fresh_args : Value.t list) :
          (Value.t, Error.t) result =
        Eval.eval globals (Value.VCtor (c, p_vals @ fresh_args) :: ctx.env) mot'
      in
      let* branches' =
        check_branches globals ctx mode ~p_vals ~expected_of ctor_names branches
      in
      let* scrut_v = Eval.eval globals ctx.env scrut' in
      let* res_ty = Eval.eval globals (scrut_v :: ctx.env) mot' in
      Ok (Term.Match { scrut = scrut'; motive = Some (x, mot'); branches = branches' }, res_ty)
  | Term.Global name ->
      let* entry =
        Global.find name globals |> Option.to_result ~none:(Error.Unbound_global name)
      in
      let* ty_v = Eval.eval globals [] (Global.entry_ty entry) in
      Ok (Term.Global name, ty_v)

and infer_univ (globals : Global.t) (ctx : ctx) (tm : Term.t) :
    (Term.t * Level.t, Error.t) result =
  let* tm', ty = infer globals ctx Quantity.Zero tm in
  match ty with
  | Value.VUniv l -> Ok (tm', l)
  | Value.VPi (_, _, _, _)
  | Value.VLam (_, _)
  | Value.VInd (_, _)
  | Value.VCtor (_, _)
  | Value.VNeutral (_, _) ->
      Error (Error.Not_a_universe (pp_value globals ctx.size ty))

and check (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (tm : Term.t)
    (expected : Value.t) : (Term.t, Error.t) result =
  match (tm, expected) with
  | Term.Lam (_q, x, body), Value.VPi (q, _y, dom, clo) ->
      (* the Pi's quantity is authoritative; the input stamp is discarded *)
      let* cod = Eval.app_closure globals clo (Value.var ctx.size) in
      let* body' = check globals (bind x q dom ctx) mode body cod in
      Ok (Term.Lam (q, x, body'))
  | ( Term.Lam (_q, _x, _body),
      ( Value.VUniv _
      | Value.VLam (_, _)
      | Value.VInd (_, _)
      | Value.VCtor (_, _)
      | Value.VNeutral (_, _) ) ) ->
      Error
        (Error.Mismatch
           { expected = pp_value globals ctx.size expected; actual = "a function" })
  | Term.Let (x, ty, def, body), expected_v ->
      let* ty', _ty_l = infer_univ globals ctx ty in
      let* ty_v = Eval.eval globals ctx.env ty' in
      let* def' = check globals ctx mode def ty_v in
      let* def_v = Eval.eval globals ctx.env def' in
      let* body' = check globals (bind_def x ty_v def_v ctx) mode body expected_v in
      Ok (Term.Let (x, ty', def', body'))
  | Term.Match { scrut; motive; branches }, expected_v ->
      (match () with
      | () when Option.is_some motive ->
          (* explicit motive: infer, then converse against the expectation *)
          check_via_infer globals ctx mode tm expected_v
      | () ->
          (* constant motive: every branch checks at the expected type *)
          let* scrut', _iname, p_vals, ctor_names = match_scrut globals ctx mode scrut in
          let expected_of (_c : string) (_fresh_args : Value.t list) :
              (Value.t, Error.t) result =
            Ok expected_v
          in
          let* branches' =
            check_branches globals ctx mode ~p_vals ~expected_of ctor_names branches
          in
          Ok (Term.Match { scrut = scrut'; motive = None; branches = branches' }))
  | ( (Term.Var _ | Term.Univ _ | Term.Pi (_, _, _, _) | Term.App (_, _, _)
      | Term.Ann (_, _) | Term.Global _),
      expected_v ) ->
      check_via_infer globals ctx mode tm expected_v

and check_via_infer (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (tm : Term.t)
    (expected_v : Value.t) : (Term.t, Error.t) result =
  let* tm', actual = infer globals ctx mode tm in
  let* ok = Eval.conv globals ctx.size actual expected_v in
  if ok then Ok tm'
  else
    Error
      (Error.Mismatch
         {
           expected = pp_value globals ctx.size expected_v;
           actual = pp_value globals ctx.size actual;
         })

(** Infer the scrutinee and demand a fully applied inductive type; returns
    the stamped scrutinee, the inductive's name, its parameter values and
    its declared constructor names. *)
and match_scrut (globals : Global.t) (ctx : ctx) (mode : Quantity.t) (scrut : Term.t) :
    (Term.t * string * Value.t list * string list, Error.t) result =
  let* scrut', s_ty = infer globals ctx mode scrut in
  match s_ty with
  | Value.VInd (iname, p_vals) ->
      let* ind =
        Global.find_ind iname globals
        |> Option.to_result ~none:(Error.Not_inductive (pp_value globals ctx.size s_ty))
      in
      if Int.equal (List.length p_vals) (List.length ind.Global.params) then
        Ok (scrut', iname, p_vals, ind.Global.ctor_names)
      else Error (Error.Not_inductive (pp_value globals ctx.size s_ty))
  | Value.VUniv _
  | Value.VPi (_, _, _, _)
  | Value.VLam (_, _)
  | Value.VCtor (_, _)
  | Value.VNeutral (_, _) ->
      Error (Error.Not_inductive (pp_value globals ctx.size s_ty))

(** Walk the declared ctor names and the user's branches together, in
    declaration order. [expected_of] gives each branch body's expected
    type from the ctor name and its fresh argument values. Branch binder
    names come from the user's pattern; quantities from the telescope. *)
and check_branches (globals : Global.t) (ctx : ctx) (mode : Quantity.t)
    ~(p_vals : Value.t list)
    ~(expected_of : string -> Value.t list -> (Value.t, Error.t) result)
    (ctor_names : string list)
    (branches : (string * (Quantity.t * string) list * Term.t) list) :
    ((string * (Quantity.t * string) list * Term.t) list, Error.t) result =
  match (ctor_names, branches) with
  | [], [] -> Ok []
  | c :: _, [] -> Error (Error.Branch_mismatch { expected = c; found = "<none>" })
  | [], (b, _binders, _body) :: _ ->
      Error (Error.Branch_mismatch { expected = "<none>"; found = b })
  | c :: cs, (b, pat_binders, body) :: bs ->
      (match () with
      | () when not (String.equal c b) ->
          Error (Error.Branch_mismatch { expected = c; found = b })
      | () ->
          let* ctor =
            Global.find_ctor c globals |> Option.to_result ~none:(Error.Unbound_global c)
          in
          let* bctx, rev_fresh, rev_binders =
            walk_telescope globals ctx c (List.rev p_vals) [] [] ctor.Global.args
              pat_binders
          in
          let fresh_args = List.rev rev_fresh in
          let binders' = List.rev rev_binders in
          let* expected_body = expected_of c fresh_args in
          let* body' = check globals bctx mode body expected_body in
          let* rest = check_branches globals ctx mode ~p_vals ~expected_of cs bs in
          Ok ((c, binders', body') :: rest))

(** Bind one branch's pattern variables at the ctor telescope's types.
    [tele_env] evaluates each telescope type: it starts at the reversed
    parameter values and grows one fresh var per binder. Accumulators are
    newest first. *)
and walk_telescope (globals : Global.t) (bctx : ctx) (cname : string)
    (tele_env : Value.t list) (rev_fresh : Value.t list)
    (rev_binders : (Quantity.t * string) list) (tele : Global.telescope)
    (pats : (Quantity.t * string) list) :
    (ctx * Value.t list * (Quantity.t * string) list, Error.t) result =
  match (tele, pats) with
  | [], [] -> Ok (bctx, rev_fresh, rev_binders)
  | _ :: _, [] | [], _ :: _ ->
      Error
        (Error.Branch_mismatch { expected = cname; found = cname ^ " (wrong pattern arity)" })
  | (q, _tname, ty) :: tele', (_uq, u) :: pats' ->
      let* ty_v = Eval.eval globals tele_env ty in
      let fresh = Value.var bctx.size in
      walk_telescope globals (bind u q ty_v bctx) cname (fresh :: tele_env)
        (fresh :: rev_fresh) ((q, u) :: rev_binders) tele' pats'

let define ?(rec_ = false) (globals : Global.t) ~(name : string) ~(reducible : bool)
    ~(ty : Term.t) ~(def : Term.t) : (Global.t, Error.t) result =
  match Option.to_list (Global.find name globals) with
  | _entry :: _ -> Error (Error.Duplicate_global name)
  | [] ->
      let* ty', _ty_l = infer_univ globals empty_ctx ty in
      let* ty_v = Eval.eval globals [] ty' in
      if rec_ then
        (* the recursive global is opaque while its own body is checked:
           the provisional entry never unfolds, so recursive calls stay
           neutral during checking *)
        let provisional =
          Global.add name
            (Global.Def
               { Global.ty = ty'; def = Term.Global name; reducible = false; rec_arg = None })
            globals
        in
        let* def' = check provisional empty_ctx Quantity.Many def ty_v in
        let* k = Totality.guard ~recname:name def' in
        Ok
          (Global.add name
             (Global.Def { Global.ty = ty'; def = def'; reducible; rec_arg = Some k })
             globals)
      else
        let* def' = check globals empty_ctx Quantity.Many def ty_v in
        (* the entry stores the STAMPED type and definition *)
        Ok
          (Global.add name
             (Global.Def { Global.ty = ty'; def = def'; reducible; rec_arg = None })
             globals)

(** Declare an inductive's name, parameters and level. Constructors arrive
    separately via [define_ind] so their types can mention the inductive. *)
let declare_ind (globals : Global.t) ~(name : string) ~(params : Global.telescope)
    ~(level : Level.t) : (Global.t, Error.t) result =
  match Option.to_list (Global.find name globals) with
  | _entry :: _ -> Error (Error.Duplicate_global name)
  | [] ->
      let* _pctx, rev_stamped =
        List.fold_left
          (fun acc (q, x, ty) ->
            let* ctx, rev_acc = acc in
            let* ty', _l = infer_univ globals ctx ty in
            let* ty_v = Eval.eval globals ctx.env ty' in
            Ok (bind x q ty_v ctx, (q, x, ty') :: rev_acc))
          (Ok (empty_ctx, []))
          params
      in
      let stamped = List.rev rev_stamped in
      let closed =
        List.fold_right
          (fun (q, x, ty) acc -> Term.Pi (q, x, ty, acc))
          stamped (Term.Univ level)
      in
      Ok
        (Global.add name
           (Global.Ind { Global.ind_ty = closed; params = stamped; level; ctor_names = [] })
           globals)

(** Check and install the constructors of an already-declared inductive.
    Enforces the result-head rule, strict positivity with uniform
    parameters, and the predicative universe bound. On any error the
    caller keeps its pre-declaration globals. *)
let define_ind (globals : Global.t) ~(name : string) ~(ctors : (string * Term.t) list) :
    (Global.t, Error.t) result =
  let* ind =
    Global.find_ind name globals |> Option.to_result ~none:(Error.Unbound_global name)
  in
  let n_params = List.length ind.Global.params in
  (* the params ctx every ctor type was elaborated in *)
  let* pctx =
    List.fold_left
      (fun acc (q, x, ty) ->
        let* ctx = acc in
        let* ty_v = Eval.eval globals ctx.env ty in
        Ok (bind x q ty_v ctx))
      (Ok empty_ctx) ind.Global.params
  in
  (* [name] applied to exactly its parameter variables, in order, seen
     under [depth] binders below the parameters *)
  let is_applied (depth : int) (t : Term.t) : bool =
    let head, sp = Totality.spine t [] in
    let head_ok =
      match head with
      | Term.Global g -> String.equal g name
      | Term.Var _ | Term.Univ _
      | Term.Pi (_, _, _, _)
      | Term.Lam (_, _, _)
      | Term.App (_, _, _)
      | Term.Let (_, _, _, _)
      | Term.Ann (_, _)
      | Term.Match _ ->
          false
    in
    head_ok
    && Int.equal (List.length sp) n_params
    && List.mapi (fun j arg -> (j, arg)) sp
       |> List.for_all (fun (j, arg) ->
              match arg with
              | Term.Var ix -> Int.equal ix (depth + n_params - 1 - j)
              | Term.Univ _
              | Term.Pi (_, _, _, _)
              | Term.Lam (_, _, _)
              | Term.App (_, _, _)
              | Term.Let (_, _, _, _)
              | Term.Ann (_, _)
              | Term.Global _ | Term.Match _ ->
                  false)
  in
  let rec no_occur (t : Term.t) : bool =
    match t with
    | Term.Var _ | Term.Univ _ -> true
    | Term.Global g -> not (String.equal g name)
    | Term.Pi (_q, _x, dom, cod) -> no_occur dom && no_occur cod
    | Term.Lam (_q, _x, b) -> no_occur b
    | Term.App (_q, f, a) -> no_occur f && no_occur a
    | Term.Let (_x, ty, def, b) -> no_occur ty && no_occur def && no_occur b
    | Term.Ann (tm, ty) -> no_occur tm && no_occur ty
    | Term.Match { scrut; motive; branches } ->
        no_occur scrut
        && (motive |> Option.fold ~none:true ~some:(fun (_x, m) -> no_occur m))
        && List.for_all (fun (_c, _bs, b) -> no_occur b) branches
  in
  (* strict positivity: no occurrence at all, or exactly the applied form,
     possibly as the codomain of a Pi telescope whose domains never
     mention the name *)
  let rec strict_pos (depth : int) (t : Term.t) : bool =
    match () with
    | () when no_occur t -> true
    | () ->
        (match t with
        | Term.Pi (_q, _x, dom, cod) -> no_occur dom && strict_pos (depth + 1) cod
        | Term.Var _ | Term.Univ _
        | Term.Lam (_, _, _)
        | Term.App (_, _, _)
        | Term.Let (_, _, _, _)
        | Term.Ann (_, _)
        | Term.Global _ | Term.Match _ ->
            is_applied depth t)
  in
  let rec strip_pis (acc : Global.telescope) (t : Term.t) : Global.telescope * Term.t =
    match t with
    | Term.Pi (q, x, dom, cod) -> strip_pis ((q, x, dom) :: acc) cod
    | Term.Var _ | Term.Univ _
    | Term.Lam (_, _, _)
    | Term.App (_, _, _)
    | Term.Let (_, _, _, _)
    | Term.Ann (_, _)
    | Term.Global _ | Term.Match _ ->
        (List.rev acc, t)
  in
  let* globals' =
    List.fold_left
      (fun acc (cname, cty) ->
        let* gacc = acc in
        let* () =
          match Option.to_list (Global.find cname gacc) with
          | _e :: _ -> Error (Error.Duplicate_global cname)
          | [] -> Ok ()
        in
        let* cty', _cty_l = infer_univ gacc pctx cty in
        let args, cod = strip_pis [] cty' in
        let* () =
          if is_applied (List.length args) cod then Ok ()
          else
            Error
              (Error.Bad_ctor
                 {
                   ctor = cname;
                   reason = "constructor must end in " ^ name ^ " applied to its parameters";
                 })
        in
        (* per argument: positivity at its own base depth, then the
           predicative universe bound *)
        let* _actx, _n_args =
          List.fold_left
            (fun aacc (q, x, ty) ->
              let* actx, i = aacc in
              let* () =
                if strict_pos i ty then Ok ()
                else
                  Error
                    (Error.Bad_ctor
                       { ctor = cname; reason = "negative or non-uniform occurrence of " ^ name })
              in
              let* ty2, l = infer_univ gacc actx ty in
              let* () =
                if Level.le l ind.Global.level then Ok ()
                else
                  Error
                    (Error.Bad_ctor
                       {
                         ctor = cname;
                         reason = "constructor argument lives above the declared universe";
                       })
              in
              let* ty_v = Eval.eval gacc actx.env ty2 in
              Ok (bind x q ty_v actx, i + 1))
            (Ok (pctx, 0))
            args
        in
        (* parameters are ALWAYS quantity-0 in the closed constructor type:
           at applications the param args erase *)
        let closed =
          List.fold_right
            (fun (_q, x, ty) acc2 -> Term.Pi (Quantity.Zero, x, ty, acc2))
            ind.Global.params
            (List.fold_right (fun (q, x, ty) acc2 -> Term.Pi (q, x, ty, acc2)) args cod)
        in
        Ok (Global.add cname (Global.Ctor { Global.ctor_ty = closed; ind = name; args }) gacc))
      (Ok globals) ctors
  in
  let ctor_names = List.map (fun (c, _cty) -> c) ctors in
  Ok (Global.add name (Global.Ind { ind with Global.ctor_names }) globals')
