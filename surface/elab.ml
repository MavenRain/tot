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
      let* tm_t = term globals scope tm in
      let* ty_t = term globals scope ty in
      Ok (Term.Ann (tm_t, ty_t))
  | Syntax.SStr (_loc, s) -> Ok (Term.Lit (Literal.LString s))
  | Syntax.SInt (_loc, n) -> Ok (Term.Lit (Literal.LInt n))
  | Syntax.SAuto _loc -> Ok Term.Auto
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
         in [body]). *)
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
