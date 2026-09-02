(** M0 kernel tests. Church numerals exercise closures and spines; the
    negative cases pin the exact error constructor so a vacuous pass is
    impossible. *)

open Tot_kernel

let ( let* ) = Result.bind

let q0 = Quantity.Zero
let qw = Quantity.Many
let ty0 = Term.Univ Level.zero
let ty1 = Term.Univ Level.one
let cnat = Term.Global "cnat"

(* M4 Stage A: the M2/M3-shaped motive, a bare binder over the scrutinee
   with no index clause; every hand-built M2/M3 match term uses exactly
   this shape (Term.t's own doc comment: "the old (string * t) option
   motive is exactly the { m_ind = None; m_idx = []; m_self = x; m_body =
   t } case"). *)
let m2_motive (self : string) (body : Term.t) : Term.motive =
  { Term.m_ind = None; m_idx = []; m_self = self; m_body = body }

(* (0 a : Type 0) -> (w f : (w x : a) -> a) -> (w z : a) -> a *)
let cnat_def : Term.t =
  Term.Pi
    ( q0,
      "a",
      ty0,
      Term.Pi
        ( qw,
          "f",
          Term.Pi (qw, "x", Term.Var 0, Term.Var 1),
          Term.Pi (qw, "z", Term.Var 1, Term.Var 2) ) )

let czero_def : Term.t = Term.Lam (qw, "a", Term.Lam (qw, "f", Term.Lam (qw, "z", Term.Var 0)))

(* fun n a f z => f (n a f z) *)
let csucc_def : Term.t =
  Term.Lam
    (qw, "n",
      Term.Lam
        (qw, "a",
          Term.Lam
            (qw, "f",
              Term.Lam
                (qw, "z",
                  Term.App
                    (qw, Term.Var 1,
                      Term.App
                        (qw, Term.App (qw, Term.App (qw, Term.Var 3, Term.Var 2), Term.Var 1), Term.Var 0)
                    ) ) ) ) )

let csucc_ty : Term.t = Term.Pi (qw, "n", cnat, cnat)

(* fun m n a f z => m a f (n a f z) *)
let cadd_def : Term.t =
  Term.Lam
    (qw, "m",
      Term.Lam
        (qw, "n",
          Term.Lam
            (qw, "a",
              Term.Lam
                (qw, "f",
                  Term.Lam
                    (qw, "z",
                      Term.App
                        (qw, Term.App (qw, Term.App (qw, Term.Var 4, Term.Var 2), Term.Var 1),
                          Term.App
                            (qw, Term.App (qw, Term.App (qw, Term.Var 3, Term.Var 2), Term.Var 1),
                              Term.Var 0 ) ) ) ) ) ) )

let cadd_ty : Term.t = Term.Pi (qw, "m", cnat, Term.Pi (qw, "n", cnat, cnat))

let church (n : int) : Term.t =
  List.init n (fun _i -> ())
  |> List.fold_left (fun acc () -> Term.App (qw, Term.Global "csucc", acc)) (Term.Global "czero")

let idt_ty : Term.t = Term.Pi (q0, "a", ty1, Term.Pi (qw, "x", Term.Var 0, Term.Var 1))
let idt_def : Term.t = Term.Lam (qw, "a", Term.Lam (qw, "x", Term.Var 0))

(* --- M2: a hand-built Nat and a parameterized Opt --- *)

let nat = Term.Global "Nat"
let nzero = Term.Global "zero"
let nsucc (t : Term.t) : Term.t = Term.App (qw, Term.Global "succ", t)
let opt_nat : Term.t = Term.App (qw, Term.Global "Opt", nat)
let add_ty : Term.t = Term.Pi (qw, "m", nat, Term.Pi (qw, "n", nat, nat))

(* fun m n => match m as _m return Nat with
   | zero => n | succ p => succ (add p n) end *)
let add_def : Term.t =
  Term.Lam
    ( qw,
      "m",
      Term.Lam
        ( qw,
          "n",
          Term.Match
            {
              scrut = Term.Var 1;
              scrut_q = qw;
              motive = Some (m2_motive "_m" nat);
              branches =
                [
                  ("zero", [], Term.Var 0);
                  ( "succ",
                    [ (qw, "p") ],
                    nsucc
                      (Term.App (qw, Term.App (qw, Term.Global "add", Term.Var 0), Term.Var 1))
                  );
                ];
            } ) )

let build_globals () : (Global.t, Error.t) result =
  let* g = Check.define Global.empty ~name:"cnat" ~reducible:true ~ty:ty1 ~def:cnat_def in
  let* g = Check.define g ~name:"czero" ~reducible:true ~ty:cnat ~def:czero_def in
  let* g = Check.define g ~name:"csucc" ~reducible:true ~ty:csucc_ty ~def:csucc_def in
  let* g = Check.define g ~name:"cadd" ~reducible:true ~ty:cadd_ty ~def:cadd_def in
  let* g = Check.define g ~name:"ctwo" ~reducible:true ~ty:cnat ~def:(church 2) in
  let* g = Check.define g ~name:"cfour" ~reducible:true ~ty:cnat ~def:(church 4) in
  let* g = Check.define g ~name:"czero_opaque" ~reducible:false ~ty:cnat ~def:czero_def in
  let* g =
    Check.define g ~name:"g_fun" ~reducible:false
      ~ty:(Term.Pi (qw, "x", cnat, cnat))
      ~def:(Term.Lam (qw, "x", Term.Var 0))
  in
  let* g = Check.define g ~name:"idT" ~reducible:false ~ty:idt_ty ~def:idt_def in
  (* M2: inductives, a guarded rec def, and an opaque Nat *)
  let* g = Check.declare_ind g ~name:"Nat" ~params:[] ~indices:[] ~level:Level.zero in
  let* g =
    Check.define_ind g ~name:"Nat"
      ~ctors:[ ("zero", nat); ("succ", Term.Pi (qw, "n", nat, nat)) ]
  in
  let* g = Check.declare_ind g ~name:"Opt" ~params:[ (q0, "A", ty0) ] ~indices:[] ~level:Level.zero in
  let* g =
    Check.define_ind g ~name:"Opt"
      ~ctors:
        [
          ("none", Term.App (qw, Term.Global "Opt", Term.Var 0));
          ("some", Term.Pi (qw, "x", Term.Var 0, Term.App (qw, Term.Global "Opt", Term.Var 1)));
        ]
  in
  let* g = Check.define ~rec_:true g ~name:"add" ~reducible:true ~ty:add_ty ~def:add_def in
  Check.define g ~name:"x_opaque" ~reducible:false ~ty:nat ~def:nzero

let expect_conv (globals : Global.t) (label : string) ~(want : bool) (t1 : Term.t)
    (t2 : Term.t) () : (unit, string) result =
  let attempt =
    let* v1 = Eval.eval globals [] t1 in
    let* v2 = Eval.eval globals [] t2 in
    Eval.conv globals 0 v1 v2
  in
  attempt
  |> Result.fold
       ~ok:(fun got ->
         if Bool.equal got want then Ok ()
         else Error (Printf.sprintf "%s: conv returned %b, expected %b" label got want))
       ~error:(fun e -> Error (label ^ ": " ^ Error.to_string e))

let expect_infer_ok (globals : Global.t) (label : string) (tm : Term.t) () :
    (unit, string) result =
  Check.infer globals Check.empty_ctx Quantity.Many tm
  |> Result.fold
       ~ok:(fun (_tm, _ty) -> Ok ())
       ~error:(fun e -> Error (label ^ ": " ^ Error.to_string e))

let expect_infer_err (globals : Global.t) (label : string) (want_tag : string)
    (tm : Term.t) () : (unit, string) result =
  Check.infer globals Check.empty_ctx Quantity.Many tm
  |> Result.fold
       ~ok:(fun (_tm, _ty) ->
         Error (label ^ ": expected " ^ want_tag ^ ", but it typechecked"))
       ~error:(fun e ->
         if String.equal (Error.tag e) want_tag then Ok ()
         else Error (Printf.sprintf "%s: expected %s, got %s" label want_tag (Error.to_string e)))

let case_id_result_type (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* _tm, ty =
      Check.infer globals Check.empty_ctx Quantity.Many
        (Term.App (qw, Term.App (qw, Term.Global "idT", cnat), Term.Global "czero"))
    in
    let* want = Eval.eval globals [] cnat in
    Eval.conv globals 0 ty want
  in
  attempt
  |> Result.fold
       ~ok:(fun ok ->
         if ok then Ok () else Error "idT: inferred type of (idT cnat czero) is not cnat")
       ~error:(fun e -> Error ("idT: " ^ Error.to_string e))

let case_duplicate (globals : Global.t) () : (unit, string) result =
  Check.define globals ~name:"czero" ~reducible:true ~ty:cnat ~def:czero_def
  |> Result.fold
       ~ok:(fun _g -> Error "duplicate: redefining czero was accepted")
       ~error:(fun e ->
         if String.equal (Error.tag e) "Duplicate_global" then Ok ()
         else Error ("duplicate: wrong error: " ^ Error.to_string e))

let case_quote_pp (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* v = Eval.eval globals [] cnat in
    Eval.quote globals 0 v
  in
  attempt
  |> Result.fold
       ~ok:(fun t ->
         let got = Pp.term [] t in
         let want = "(0 a : Type 0) -> (w f : (w x : a) -> a) -> (w z : a) -> a" in
         if String.equal got want then Ok ()
         else Error (Printf.sprintf "quote/pp: got %s" got))
       ~error:(fun e -> Error ("quote/pp: " ^ Error.to_string e))

(* --- M2 cases --- *)

(* match succ (succ zero) with .. | succ n => n end  ==>  succ zero *)
let match_nat_pred : Term.t =
  Term.Match
    {
      scrut = nsucc (nsucc nzero);
      scrut_q = qw;
      motive = Some (m2_motive "_m" nat);
      branches = [ ("zero", [], nzero); ("succ", [ (qw, "n") ], Term.Var 0) ];
    }

(* match some Nat (succ zero) with .. | some x => x end  ==>  succ zero;
   pins that the erased param value is dropped before branch entry *)
let match_opt_payload : Term.t =
  Term.Match
    {
      scrut = Term.App (qw, Term.App (qw, Term.Global "some", nat), nsucc nzero);
      scrut_q = qw;
      motive = Some (m2_motive "_o" nat);
      branches = [ ("none", [], nzero); ("some", [ (qw, "x") ], Term.Var 0) ];
    }

let case_match_eval (globals : Global.t) () : (unit, string) result =
  let* () = expect_conv globals "match-eval-nat" ~want:true match_nat_pred (nsucc nzero) () in
  expect_conv globals "match-eval-opt" ~want:true match_opt_payload (nsucc nzero) ()

(* the motive returns a DIFFERENT type per constructor: Nat for zero,
   Opt Nat for succ *)
let dep_motive_term : Term.t =
  Term.Match
    {
      scrut = nsucc nzero;
      scrut_q = qw;
      motive =
        Some
          (m2_motive "n"
             (Term.Match
                {
                  scrut = Term.Var 0;
                  scrut_q = qw;
                  motive = Some (m2_motive "_" ty0);
                  branches = [ ("zero", [], nat); ("succ", [ (qw, "p") ], opt_nat) ];
                }));
      branches =
        [
          ("zero", [], nzero);
          ( "succ",
            [ (qw, "p") ],
            Term.App (qw, Term.App (qw, Term.Global "some", nat), Term.Var 0) );
        ];
    }

let case_dependent_motive (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* _tm, ty = Check.infer globals Check.empty_ctx Quantity.Many dep_motive_term in
    let* _tm2, ty2 =
      Check.infer globals Check.empty_ctx Quantity.Many
        (Term.App (qw, Term.App (qw, Term.Global "some", nat), nsucc nzero))
    in
    let* want = Eval.eval globals [] opt_nat in
    let* ok1 = Eval.conv globals 0 ty want in
    let* ok2 = Eval.conv globals 0 ty2 want in
    Ok (ok1 && ok2)
  in
  attempt
  |> Result.fold
       ~ok:(fun ok ->
         if ok then Ok () else Error "dep-motive: a result type is not Opt Nat")
       ~error:(fun e -> Error ("dep-motive: " ^ Error.to_string e))

let nat_match_with (branches : (string * (Quantity.t * string) list * Term.t) list) :
    Term.t =
  Term.Match { scrut = nzero; scrut_q = qw; motive = Some (m2_motive "_m" nat); branches }

let case_branch_shape (globals : Global.t) () : (unit, string) result =
  let* () =
    expect_infer_err globals "branch-order" "Branch_mismatch"
      (nat_match_with [ ("succ", [ (qw, "n") ], nzero); ("zero", [], nzero) ])
      ()
  in
  let* () =
    expect_infer_err globals "branch-missing" "Branch_mismatch"
      (nat_match_with [ ("zero", [], nzero) ])
      ()
  in
  expect_infer_err globals "branch-arity" "Branch_mismatch"
    (nat_match_with [ ("zero", [], nzero); ("succ", [], nzero) ])
    ()

let case_positivity (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = Check.declare_ind globals ~name:"BadPos" ~params:[] ~indices:[] ~level:Level.zero in
    Check.define_ind g ~name:"BadPos"
      ~ctors:
        [
          ( "mk",
            Term.Pi
              ( qw,
                "f",
                Term.Pi (qw, "x", Term.Global "BadPos", nat),
                Term.Global "BadPos" ) );
        ]
  in
  attempt
  |> Result.fold
       ~ok:(fun _g -> Error "positivity: negative ctor was accepted")
       ~error:(fun e ->
         if String.equal (Error.tag e) "Bad_ctor" then Ok ()
         else Error ("positivity: wrong error: " ^ Error.to_string e))

let case_universe (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = Check.declare_ind globals ~name:"BadUniv" ~params:[] ~indices:[] ~level:Level.zero in
    Check.define_ind g ~name:"BadUniv"
      ~ctors:[ ("mkU", Term.Pi (qw, "t", ty0, Term.Global "BadUniv")) ]
  in
  attempt
  |> Result.fold
       ~ok:(fun _g -> Error "universe: oversized ctor arg was accepted")
       ~error:(fun e ->
         if String.equal (Error.tag e) "Bad_ctor" then Ok ()
         else Error ("universe: wrong error: " ^ Error.to_string e))

let stuck_add : Term.t =
  Term.App (qw, Term.App (qw, Term.Global "add", Term.Global "x_opaque"), nsucc nzero)

let case_guarded_stuck (globals : Global.t) () : (unit, string) result =
  let* () = expect_conv globals "stuck-self" ~want:true stuck_add stuck_add () in
  expect_conv globals "stuck-not-succ" ~want:false stuck_add (nsucc (nsucc nzero)) ()

let case_termination (globals : Global.t) () : (unit, string) result =
  Check.define ~rec_:true globals ~name:"loop" ~reducible:true
    ~ty:(Term.Pi (qw, "n", nat, nat))
    ~def:(Term.Lam (qw, "n", Term.App (qw, Term.Global "loop", Term.Var 0)))
  |> Result.fold
       ~ok:(fun _g -> Error "termination: loop was accepted")
       ~error:(fun e ->
         if String.equal (Error.tag e) "Termination" then Ok ()
         else Error ("termination: wrong error: " ^ Error.to_string e))

let stuck_match_over (zero_body : Term.t) : Term.t =
  Term.Match
    {
      scrut = Term.Global "x_opaque";
      scrut_q = qw;
      motive = Some (m2_motive "_m" nat);
      branches = [ ("zero", [], zero_body); ("succ", [ (qw, "n") ], Term.Var 0) ];
    }

let case_stuck_match_conv (globals : Global.t) () : (unit, string) result =
  let* () =
    expect_conv globals "stuck-match-self" ~want:true (stuck_match_over nzero)
      (stuck_match_over nzero) ()
  in
  expect_conv globals "stuck-match-diff" ~want:false (stuck_match_over nzero)
    (stuck_match_over (nsucc nzero)) ()

(* --- M2 fix batch, Stage A --- *)

(* F2: the provisional inductive window. A second constructor whose type
   eliminates the FIRST constructor of its own still-declaring inductive
   must be rejected with Ind_incomplete (checked entirely at
   [define_ind] time, never reaching eval's exhaustiveness backstop). *)
let case_ind_incomplete (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = Check.declare_ind globals ~name:"Pin" ~params:[] ~indices:[] ~level:Level.zero in
    Check.define_ind g ~name:"Pin"
      ~ctors:
        [
          ("pa", Term.Global "Pin");
          ( "pb",
            Term.Pi
              ( qw,
                "_",
                Term.Match
                  {
                    scrut = Term.Global "pa";
                    scrut_q = qw;
                    motive = Some (m2_motive "_" ty0);
                    branches = [];
                  },
                Term.Global "Pin" ) );
        ]
  in
  attempt
  |> Result.fold
       ~ok:(fun _g -> Error "ind-incomplete: mid-declaration elimination was accepted")
       ~error:(fun e ->
         Printf.printf "  expected error (Ind_incomplete): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Ind_incomplete" then Ok ()
         else Error ("ind-incomplete: wrong error: " ^ Error.to_string e))

(* F2: a second [define_ind] call on an already-complete inductive is
   rejected with Ind_redefined instead of silently overwriting
   ctor_names. *)
let case_ind_redefined (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = Check.declare_ind globals ~name:"Bit" ~params:[] ~indices:[] ~level:Level.zero in
    let* g = Check.define_ind g ~name:"Bit" ~ctors:[ ("bzero", Term.Global "Bit") ] in
    Check.define_ind g ~name:"Bit" ~ctors:[ ("bone", Term.Global "Bit") ]
  in
  attempt
  |> Result.fold
       ~ok:(fun _g -> Error "ind-redefined: second define_ind was accepted")
       ~error:(fun e ->
         Printf.printf "  expected error (Ind_redefined): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Ind_redefined" then Ok ()
         else Error ("ind-redefined: wrong error: " ^ Error.to_string e))

(* --- M2 fix batch (Round 3), S3 --- *)

(* S3: match_scrut error precedence. A scrutinee whose param count
   disagrees with its inductive's declared telescope must be diagnosed
   as Not_inductive, even when the same inductive is ALSO still
   mid-declaration (would otherwise qualify for Ind_incomplete): the
   arity defect is checked FIRST. [bad_scrut] is a [Global.add]-built
   opaque global (bypassing [Check.define] on purpose, mirroring the F5
   backstop style): its declared type is the bare, unapplied inductive
   name [Pin3], and evaluating a bare [Term.Global] whose entry is
   [Global.Ind] always yields [Value.VInd (name, [])] regardless of how
   many params that inductive actually declares (see [Eval.eval]'s
   [Global.Ind] arm) - so a 1-param Pin3 gives a scrutinee whose p_vals
   length (0) disagrees with [ind.Global.params]'s length (1), while
   Pin3 itself is left declared-but-undefined (ctor_names = None). *)
let case_match_scrut_precedence (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g =
      Check.declare_ind globals ~name:"Pin3" ~params:[ (q0, "A", ty0) ] ~indices:[] ~level:Level.zero
    in
    let g' =
      Global.add "bad_scrut"
        (Global.Def
           {
             Global.ty = Term.Global "Pin3";
             def = Term.Univ Level.zero;
             reducible = false;
             rec_arg = None;
             partial = false;
           })
        g
    in
    Check.infer g' Check.empty_ctx Quantity.Many
      (Term.Match
         {
           scrut = Term.Global "bad_scrut";
           scrut_q = qw;
           motive = Some (m2_motive "_" ty0);
           branches = [];
         })
  in
  attempt
  |> Result.fold
       ~ok:(fun (_tm, _ty) ->
         Error
           "match-scrut-precedence: wrong-arity scrutinee on an incomplete inductive was \
            accepted")
       ~error:(fun e ->
         Printf.printf "  expected error (Not_inductive, not Ind_incomplete): %s\n"
           (Error.to_string e);
         if String.equal (Error.tag e) "Not_inductive" then Ok ()
         else Error ("match-scrut-precedence: wrong error: " ^ Error.to_string e))

(* F4: guarded unfolding's canonical check must mean FULLY applied. A
   partially applied [succ] (0 of its 1 kept args) in the principal
   position must NOT unlock unfolding; a fully applied one still does. *)
let partial_succ_add : Term.t =
  Term.App (qw, Term.App (qw, Term.Global "add", Term.Global "succ"), nzero)

let full_succ_add : Term.t =
  Term.App (qw, Term.App (qw, Term.Global "add", nsucc nzero), nzero)

let case_partial_ctor_not_canonical (globals : Global.t) () : (unit, string) result =
  Eval.eval globals [] partial_succ_add
  |> Result.fold
       ~ok:(fun v ->
         match v with
         | Value.VNeutral (_, _) -> Ok ()
         | Value.VUniv _ | Value.VPi (_, _, _, _) | Value.VLam (_, _) | Value.VInd (_, _)
         | Value.VCtor (_, _) | Value.VLit _ ->
             Error "partial-ctor: add wrongly unfolded on a partially applied succ")
       ~error:(fun e -> Error ("partial-ctor: " ^ Error.to_string e))

let case_full_ctor_unfolds (globals : Global.t) () : (unit, string) result =
  expect_conv globals "full-ctor" ~want:true full_succ_add (nsucc nzero) ()

(* F5: run_match's arity backstop. Hand-built term, bypassing Check on
   purpose: a branch whose binder count disagrees with the scrutinee's
   kept ctor args must not silently misalign the branch env. *)
let arity_mismatch_match : Term.t =
  Term.Match
    {
      scrut = nsucc nzero;
      scrut_q = qw;
      motive = Some (m2_motive "_m" nat);
      branches = [ ("zero", [], nzero); ("succ", [ (qw, "n"); (qw, "extra") ], Term.Var 0) ];
    }

let case_run_match_arity_backstop (globals : Global.t) () : (unit, string) result =
  Eval.eval globals [] arity_mismatch_match
  |> Result.fold
       ~ok:(fun _v -> Error "arity-backstop: mismatched branch arity was accepted")
       ~error:(fun e ->
         Printf.printf "  expected error (arity backstop): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Branch_mismatch" then Ok ()
         else Error ("arity-backstop: wrong error: " ^ Error.to_string e))

(* F6: uniform motive representation. The same Bool-negation match
   checked once motive-free (check position) and once with an explicit
   constant motive must produce checker output whose stuck applications
   (over a shared OPAQUE neutral) compare EQUAL, not merely
   equal-by-accident of spelling. *)
let bool_ty : Term.t = Term.Global "Bool"

let not_body_no_motive : Term.t =
  Term.Match
    {
      scrut = Term.Var 0;
      scrut_q = qw;
      motive = None;
      branches = [ ("true", [], Term.Global "false"); ("false", [], Term.Global "true") ];
    }

let not_body_explicit_motive : Term.t =
  Term.Match
    {
      scrut = Term.Var 0;
      scrut_q = qw;
      motive = Some (m2_motive "x" bool_ty);
      branches = [ ("true", [], Term.Global "false"); ("false", [], Term.Global "true") ];
    }

let not_ty : Term.t = Term.Pi (qw, "b", bool_ty, bool_ty)

let case_uniform_motive (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = Check.declare_ind globals ~name:"Bool" ~params:[] ~indices:[] ~level:Level.zero in
    let* g =
      Check.define_ind g ~name:"Bool" ~ctors:[ ("true", bool_ty); ("false", bool_ty) ]
    in
    let* g =
      Check.define g ~name:"not_a" ~reducible:true ~ty:not_ty
        ~def:(Term.Lam (qw, "b", not_body_no_motive))
    in
    let* g =
      Check.define g ~name:"not_b" ~reducible:true ~ty:not_ty
        ~def:(Term.Lam (qw, "b", not_body_explicit_motive))
    in
    let* g =
      Check.define g ~name:"bo" ~reducible:false ~ty:bool_ty ~def:(Term.Global "true")
    in
    let* v1 = Eval.eval g [] (Term.App (qw, Term.Global "not_a", Term.Global "bo")) in
    let* v2 = Eval.eval g [] (Term.App (qw, Term.Global "not_b", Term.Global "bo")) in
    Eval.conv g 0 v1 v2
  in
  attempt
  |> Result.fold
       ~ok:(fun ok ->
         if ok then Ok ()
         else Error "uniform-motive: motive-free and explicit-motive stuck matches differ")
       ~error:(fun e -> Error ("uniform-motive: " ^ Error.to_string e))

(* --- M2 fix batch (Round 5 review), T0 --- *)

(* T0: the mechanical check the eager-unfold reversion of
   [Surface.Run.remap_rec_arg]'s erased-formal arm rests on. Mirrors
   test/fixtures/s0-erased-guard.tot's [dropErased]/[ghost] pair as
   hand-built [Term.t] (same shape [Elab.term] would produce: [App]/[Lam]
   quantity placeholders are [qw], [Check] restamps them). [ghost]'s
   guarded formal is [j] (quantity 0): the recursive call [ghost jp n]
   sits inside a match on [j], which only checks at [Quantity.Zero] mode
   (matching an erased scrutinee is illegal at mode [Many], per
   [Check.infer]'s [Var] arm), and the whole match is itself passed as
   [dropErased]'s own quantity-0 first argument. *)
let drop_erased_ty : Term.t = Term.Pi (q0, "j", nat, Term.Pi (qw, "n", nat, nat))
let drop_erased_def : Term.t = Term.Lam (qw, "j", Term.Lam (qw, "n", Term.Var 0))

(* fun j n => dropErased (match j with | zero => zero | succ jp => ghost jp n end) n *)
let ghost_ty : Term.t = Term.Pi (q0, "j", nat, Term.Pi (qw, "n", nat, nat))

let ghost_def : Term.t =
  Term.Lam
    ( qw,
      "j",
      Term.Lam
        ( qw,
          "n",
          Term.App
            ( qw,
              Term.App
                ( qw,
                  Term.Global "dropErased",
                  Term.Match
                    {
                      scrut = Term.Var 1;
                      scrut_q = qw;
                      motive = None;
                      branches =
                        [
                          ("zero", [], nzero);
                          ( "succ",
                            [ (qw, "jp") ],
                            Term.App
                              (qw, Term.App (qw, Term.Global "ghost", Term.Var 0), Term.Var 1) );
                        ];
                    } ),
              Term.Var 0 ) ) )

let case_erased_guard_no_self_ref (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g =
      Check.define globals ~name:"dropErased" ~reducible:false ~ty:drop_erased_ty
        ~def:drop_erased_def
    in
    let* g =
      Check.define ~rec_:true g ~name:"ghost" ~reducible:false ~ty:ghost_ty ~def:ghost_def
    in
    let* dentry =
      Global.find_def "ghost" g |> Option.to_result ~none:(Error.Unbound_global "ghost")
    in
    Erase.closed dentry.Global.def
  in
  attempt
  |> Result.fold
       ~ok:(fun erased ->
         (* M4 Stage C, C2: calls the PROMOTED [Eterm.mentions] instead
            of a test-private copy, so this test proves the promotion
            rather than merely asserting the two walks agree. *)
         if Eterm.mentions "ghost" erased then
           Error
             (Printf.sprintf "erased-guard-no-self-ref: self-reference survived erasure: %s"
                (Pp.eterm [] erased))
         else (
           Printf.printf "  erased ghost body: %s\n" (Pp.eterm [] erased);
           Ok ()))
       ~error:(fun e -> Error ("erased-guard-no-self-ref: " ^ Error.to_string e))

let erased_use_bad : Term.t =
  Term.Ann
    ( Term.Lam (qw, "a", Term.Lam (qw, "x", Term.Var 1)),
      Term.Pi (q0, "a", ty0, Term.Pi (qw, "x", Term.Var 0, ty0)) )

let erased_use_good : Term.t =
  Term.Ann
    ( Term.Lam (qw, "a", Term.Lam (qw, "x", Term.Var 1)),
      Term.Pi (qw, "a", ty0, Term.Pi (qw, "x", Term.Var 0, ty0)) )

let cnat_variant_many : Term.t =
  Term.Pi
    ( qw,
      "a",
      ty0,
      Term.Pi
        ( qw,
          "f",
          Term.Pi (qw, "x", Term.Var 0, Term.Var 1),
          Term.Pi (qw, "z", Term.Var 1, Term.Var 2) ) )

(* --- M3 Stage A: literals, builtin base types, the Prim entry kind --- *)

(** A hand-seeded globals holding only a declared-only [String] Ind
    (declared, never [define_ind]'d, so nothing can eliminate it). *)
let string_globals : (Global.t, Error.t) result =
  Check.declare_ind Global.empty ~name:"String" ~params:[] ~indices:[] ~level:Level.zero

(* A1: a string literal infers String against a globals that declares
   it; pin the printed type. *)
let case_lit_infer_string () : (unit, string) result =
  let attempt =
    let* sg = string_globals in
    let* _tm, ty =
      Check.infer sg Check.empty_ctx Quantity.Many (Term.Lit (Literal.LString "hi"))
    in
    Ok (Check.pp_value sg 0 ty)
  in
  attempt
  |> Result.fold
       ~ok:(fun got ->
         if String.equal got "String" then Ok ()
         else Error (Printf.sprintf "lit-infer-string: got type %s, want String" got))
       ~error:(fun e -> Error ("lit-infer-string: " ^ Error.to_string e))

(* A2: the same literal is Unbound_global when String is not declared
   (the shared kernel [globals], built without a String Ind). *)
let case_lit_infer_unbound (globals : Global.t) () : (unit, string) result =
  Check.infer globals Check.empty_ctx Quantity.Many (Term.Lit (Literal.LString "hi"))
  |> Result.fold
       ~ok:(fun (_tm, _ty) -> Error "lit-infer-unbound: String-less globals wrongly typed a literal")
       ~error:(fun e ->
         Printf.printf "  expected error (Unbound_global): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Unbound_global" then Ok ()
         else Error ("lit-infer-unbound: wrong error: " ^ Error.to_string e))

(* A3: conv on VLit is structural equality, never cross-kind. *)
let case_lit_conv (globals : Global.t) () : (unit, string) result =
  let a = Value.VLit (Literal.LString "a") in
  let a2 = Value.VLit (Literal.LString "a") in
  let b = Value.VLit (Literal.LString "b") in
  let one = Value.VLit (Literal.LInt 1) in
  let attempt =
    let* eq_same = Eval.conv globals 0 a a2 in
    let* eq_diff_str = Eval.conv globals 0 a b in
    let* eq_diff_kind = Eval.conv globals 0 a one in
    let* zero_ctor = Eval.eval globals [] nzero in
    let* eq_vs_ctor = Eval.conv globals 0 a zero_ctor in
    Ok (eq_same, eq_diff_str, eq_diff_kind, eq_vs_ctor)
  in
  attempt
  |> Result.fold
       ~ok:(fun (same, diff_str, diff_kind, vs_ctor) ->
         match () with
         | () when not same -> Error "lit-conv: equal string literals were not convertible"
         | () when diff_str -> Error "lit-conv: different string literals were convertible"
         | () when diff_kind -> Error "lit-conv: a string and an int literal were convertible"
         | () when vs_ctor -> Error "lit-conv: a literal and a ctor value were convertible"
         | () -> Ok ())
       ~error:(fun e -> Error ("lit-conv: " ^ Error.to_string e))

(* A4: prim opacity. Two prims of equal arity never reduce during
   conversion: a prim spine only compares equal to itself, syntactically. *)
let opacity_string_ty : Term.t =
  Term.Pi (qw, "_", Term.Global "String", Term.Pi (qw, "_", Term.Global "String", Term.Global "String"))

let opacity_globals : (Global.t, Error.t) result =
  let* sg = string_globals in
  let* sg = Check.define_prim sg ~name:"p" ~ty:opacity_string_ty ~prim:Prim.String_concat in
  Check.define_prim sg ~name:"q" ~ty:opacity_string_ty ~prim:Prim.String_concat

let papp (fn : string) (s1 : string) (s2 : string) : Term.t =
  Term.App
    (qw, Term.App (qw, Term.Global fn, Term.Lit (Literal.LString s1)), Term.Lit (Literal.LString s2))

let case_prim_opacity () : (unit, string) result =
  let attempt =
    let* og = opacity_globals in
    let* v_pab1 = Eval.eval og [] (papp "p" "a" "b") in
    let* v_pab2 = Eval.eval og [] (papp "p" "a" "b") in
    let* v_pac = Eval.eval og [] (papp "p" "a" "c") in
    let* v_qab = Eval.eval og [] (papp "q" "a" "b") in
    let* self_eq = Eval.conv og 0 v_pab1 v_pab2 in
    let* diff_arg = Eval.conv og 0 v_pab1 v_pac in
    let* diff_prim = Eval.conv og 0 v_pab1 v_qab in
    Ok (self_eq, diff_arg, diff_prim)
  in
  attempt
  |> Result.fold
       ~ok:(fun (self_eq, diff_arg, diff_prim) ->
         match () with
         | () when not self_eq -> Error "prim-opacity: p \"a\" \"b\" was not convertible with itself"
         | () when diff_arg -> Error "prim-opacity: p \"a\" \"b\" and p \"a\" \"c\" were convertible"
         | () when diff_prim -> Error "prim-opacity: p \"a\" \"b\" and q \"a\" \"b\" were convertible"
         | () -> Ok ())
       ~error:(fun e -> Error ("prim-opacity: " ^ Error.to_string e))

(* A5: Eval.eval's total backstop. Hand-built, bypassing Check on
   purpose: a match whose scrutinee is a VLit is Not_inductive. *)
let case_lit_match_backstop (globals : Global.t) () : (unit, string) result =
  Eval.eval globals []
    (Term.Match
       {
         scrut = Term.Lit (Literal.LString "x");
         scrut_q = qw;
         motive = Some (m2_motive "_" ty0);
         branches = [];
       })
  |> Result.fold
       ~ok:(fun _v -> Error "lit-match-backstop: match on a VLit scrutinee wrongly succeeded")
       ~error:(fun e ->
         Printf.printf "  expected error (Not_inductive): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Not_inductive" then Ok ()
         else Error ("lit-match-backstop: wrong error: " ^ Error.to_string e))

(* A6: round trip. A literal with one escaped quote and one newline
   check/erase/exec/quote/pp, pinning the printed source form. *)
let lit_roundtrip_str : string = "a" ^ "\"" ^ "b" ^ "\n" ^ "c"
let lit_roundtrip_want : string = "\"" ^ "a" ^ "\\" ^ "\"" ^ "b" ^ "\\" ^ "n" ^ "c" ^ "\""

let case_lit_roundtrip () : (unit, string) result =
  let attempt =
    let* sg = string_globals in
    let* tm', _ty =
      Check.infer sg Check.empty_ctx Quantity.Many (Term.Lit (Literal.LString lit_roundtrip_str))
    in
    let* e = Erase.closed tm' in
    let* v = Interp.exec Interp.empty_globals [] e in
    let* e' = Interp.quote Interp.empty_globals 0 v in
    Ok (Pp.eterm [] e')
  in
  attempt
  |> Result.fold
       ~ok:(fun got ->
         if String.equal got lit_roundtrip_want then Ok ()
         else Error (Printf.sprintf "lit-roundtrip: got %s, want %s" got lit_roundtrip_want))
       ~error:(fun e -> Error ("lit-roundtrip: " ^ Error.to_string e))

(* A7: Check.define_prim rejects a duplicate name. *)
let case_define_prim_duplicate () : (unit, string) result =
  let attempt =
    let* sg = string_globals in
    let ty = Term.Pi (qw, "_", Term.Global "String", Term.Global "String") in
    let* sg2 = Check.define_prim sg ~name:"p" ~ty ~prim:Prim.String_length in
    Check.define_prim sg2 ~name:"p" ~ty ~prim:Prim.String_length
  in
  attempt
  |> Result.fold
       ~ok:(fun _g -> Error "define-prim-duplicate: redefining p was accepted")
       ~error:(fun e ->
         Printf.printf "  expected error (Duplicate_global): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Duplicate_global" then Ok ()
         else Error ("define-prim-duplicate: wrong error: " ^ Error.to_string e))

(* A8: catalog integrity. *)
let case_prim_catalog_integrity () : (unit, string) result =
  let names = List.map Prim.name Prim.catalog in
  let no_dups = Int.equal (List.length names) (List.length (List.sort_uniq String.compare names)) in
  let roundtrips =
    List.for_all
      (fun p ->
        Prim.of_name (Prim.name p)
        |> Option.fold ~none:false ~some:(fun p' -> String.equal (Prim.name p) (Prim.name p')))
      Prim.catalog
  in
  let justified = List.for_all (fun p -> String.length (Prim.justification p) > 0) Prim.catalog in
  match () with
  | () when not no_dups -> Error "prim-catalog: Prim.catalog has duplicate names"
  | () when not roundtrips -> Error "prim-catalog: Prim.of_name does not round-trip every catalog entry"
  | () when not justified -> Error "prim-catalog: some catalog entry has an empty justification"
  | () -> Ok ()

(* M3 Stage B, B1: every catalog prim's [Prim.arity] matches the
   KEPT-Pi-binder count of its OWN declared bootstrap type, across all
   THREE seeding phases since the M3 fixes' C2'/O6 extension (the
   plan's own correction: pureIO's kept arity is 1, not 2). *)
let check_prim_arity_one ((name, ty_src, prim) : string * string * Prim.t) :
    (string * string) option =
  let attempt =
    let* toks = Tot_surface.Lexer.lex ty_src in
    Tot_surface.Parser.term_only toks
  in
  attempt
  |> Result.fold
       ~error:(fun _e -> Some (name, "its declared type source failed to lex/parse"))
       ~ok:(fun syn ->
         let want = Prim.arity prim in
         let got = Tot_surface.Bootstrap.kept_pi_count syn in
         if Int.equal want got then None
         else
           Some
             ( name,
               Printf.sprintf "Prim.arity is %d but its declared type has %d kept binders" want
                 got ))

(* M3 fixes, B1 (O2): the group counter is a state machine agreeing
   with Str's own dialect. Pins the rules the fix names: `\(` counts
   ONLY when its backslash is read in the normal state (an escaped
   backslash consumes both chars, so it can never lend its backslash
   to a following `(`); a backslash inside a `[...]` class is an
   ORDINARY member; `]` is literal as a class's first member (`[]a]`,
   `[^]a]`). Pre-fix, each 0-expected class pin below counted one
   phantom group, and that phantom killed the process at
   Str.matched_group. *)
let case_regex_group_count () : (unit, string) result =
  let pins : (string * int) list =
    [
      ("\\(a\\)@\\(b\\)", 2);
      ("[\\(]x", 0);
      ("\\\\(", 0);
      ("\\\\\\(", 1);
      ("[]a]\\(b\\)", 1);
      ("[^]a]\\(b\\)", 1);
      ("[]\\(]", 0);
    ]
  in
  List.fold_left
    (fun acc (pattern, want) ->
      let* () = acc in
      let got = Interp.regex_group_count pattern in
      if Int.equal got want then Ok ()
      else Error (Printf.sprintf "regex_group_count %S: want %d, got %d" pattern want got))
    (Ok ()) pins

let case_prim_arity_agreement () : (unit, string) result =
  (* M3 fixes, C2' (O6): ALL THREE seeding phases, so every catalog
     entry (the 12 Stage C prims included) sits under this pin, not
     only the live [seed_prim] bootstrap check. *)
  let table =
    Tot_surface.Bootstrap.phase1_prims @ Tot_surface.Bootstrap.phase2_prims
    @ Tot_surface.Bootstrap.phase3_prims
  in
  let offenders = List.filter_map check_prim_arity_one table in
  match offenders with
  | [] -> Ok ()
  | (name, msg) :: _rest ->
      Printf.printf "  offender: %s: %s\n" name msg;
      Error (Printf.sprintf "prim-arity-agreement: %s: %s" name msg)

(* M3 Stage B, B2: [Check.define ~reducible:true] refuses a Div-headed
   def (decision 9); the same def with [reducible = false] succeeds,
   and a FUNCTION-typed (VPi-headed) reducible def of type
   [String -> IO Unit] is unaffected, since building a function that
   RETURNS an action is inert. *)
let case_effect_def_reducible () : (unit, string) result =
  Tot_surface.Bootstrap.state ()
  |> Result.map_error (fun e -> "bootstrap failed: " ^ Tot_surface.Serror.to_string e)
  |> Result.fold ~error:(fun msg -> Error msg) ~ok:(fun bst ->
         let globals = bst.Tot_surface.Run.globals in
         let div_string_ty = Term.App (qw, Term.Global "Div", Term.Global "String") in
         let body =
           Term.App
             ( qw,
               Term.App (qw, Term.Global "pureDiv", Term.Global "String"),
               Term.Lit (Literal.LString "x") )
         in
         let bad =
           Check.define globals ~name:"tB4bad" ~reducible:true ~ty:div_string_ty ~def:body
         in
         let good =
           Check.define globals ~name:"tB4good" ~reducible:false ~ty:div_string_ty ~def:body
         in
         let io_unit_ty =
           Term.Pi
             (qw, "_", Term.Global "String", Term.App (qw, Term.Global "IO", Term.Global "Unit"))
         in
         let fn_body =
           Term.Lam
             ( qw,
               "_",
               Term.App
                 (qw, Term.App (qw, Term.Global "pureIO", Term.Global "Unit"), Term.Global "unit")
             )
         in
         let fn_ok =
           Check.define globals ~name:"tB4fn" ~reducible:true ~ty:io_unit_ty ~def:fn_body
         in
         let bad_tag = bad |> Result.fold ~ok:(fun _ -> "") ~error:Error.tag in
         let bad_msg = bad |> Result.fold ~ok:(fun _ -> "") ~error:Error.to_string in
         let good_msg = good |> Result.fold ~ok:(fun _ -> "") ~error:Error.to_string in
         let fn_msg = fn_ok |> Result.fold ~ok:(fun _ -> "") ~error:Error.to_string in
         match () with
         | () when Result.is_ok bad ->
             Error "effect-def-reducible: reducible Div-headed def was ACCEPTED"
         | () when not (String.equal bad_tag "Effect_def_reducible") ->
             Error ("effect-def-reducible: wrong error on bad: " ^ bad_msg)
         | () when Result.is_error good ->
             Error ("effect-def-reducible: plain Div-headed def was REJECTED: " ^ good_msg)
         | () when Result.is_error fn_ok ->
             Error ("effect-def-reducible: reducible fn-typed def was REJECTED: " ^ fn_msg)
         | () ->
             Printf.printf "  expected error (Effect_def_reducible): %s\n" bad_msg;
             Ok ())

(* M3 Stage B, B3: [Interp.quote] on a [VIOAction] returns
   [Not_quotable] (decision 8); readback has no syntax for a reified IO
   action. *)
let case_ioaction_not_quotable () : (unit, string) result =
  let action = Interp.VIOAction (Interp.IOPure (Interp.VCon ("unit", []))) in
  Interp.quote Interp.empty_globals 0 action
  |> Result.fold
       ~ok:(fun _e -> Error "ioaction-not-quotable: quote succeeded on a VIOAction")
       ~error:(fun e ->
         Printf.printf "  expected error (Not_quotable): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Not_quotable" then Ok ()
         else Error ("ioaction-not-quotable: wrong error: " ^ Error.to_string e))

(* M3 Stage B, B4 (test list numbering per B9): [Interp.add_prim] on an
   arity-0 prim (readStdin) stores its FIRED result, a [VIOAction], not
   an un-fired [VPrim] spine (the arity-0 trap A16/A-stage already
   handled for Tot prims; B extends it to Io prims). Proven INDIRECTLY
   through [Interp.quote]: nothing but a [VIOAction] reports
   [Not_quotable], so a [Not_quotable] result here is exhaustive proof
   of the stored shape without matching over every [Interp.v]
   constructor by hand. *)
let case_add_prim_arity0_ioaction () : (unit, string) result =
  Interp.add_prim Interp.empty_globals ~name:"readStdin" ~prim:Prim.Read_stdin
  |> Result.fold
       ~error:(fun e -> Error ("add-prim-arity0: " ^ Error.to_string e))
       ~ok:(fun eglobals ->
         Global.StringMap.find_opt "readStdin" eglobals
         |> Option.to_result ~none:"add-prim-arity0: readStdin not found"
         |> Result.map (fun (g : Interp.gentry) -> !(g.Interp.gval))
         |> Result.fold
              ~error:(fun msg -> Error msg)
              ~ok:(fun gb ->
                match gb with
                | Interp.GForced v ->
                    Interp.quote eglobals 0 v
                    |> Result.fold
                         ~ok:(fun _e ->
                           Error
                             "add-prim-arity0: readStdin's stored value quotes (expected a \
                              VIOAction, which is Not_quotable)")
                         ~error:(fun e ->
                           if String.equal (Error.tag e) "Not_quotable" then Ok ()
                           else Error ("add-prim-arity0: wrong error: " ^ Error.to_string e))
                | Interp.GDeferred _ ->
                    Error "add-prim-arity0: readStdin was stored as GDeferred, not GForced"))

(* M3 Stage C, C7 test 1: [Check.define ~partial:true ~reducible:true]
   is [Partial_reducible_conflict], checked before [ty] is even
   touched. *)
let case_partial_reducible_conflict () : (unit, string) result =
  Tot_surface.Bootstrap.state ()
  |> Result.map_error (fun e -> "bootstrap failed: " ^ Tot_surface.Serror.to_string e)
  |> Result.fold ~error:(fun msg -> Error msg) ~ok:(fun bst ->
         let g = bst.Tot_surface.Run.globals in
         let ty =
           Term.Pi (qw, "n", Term.Global "Int", Term.App (qw, Term.Global "Div", Term.Global "Int"))
         in
         let def = Term.Lam (qw, "n", Term.Var 0) in
         let r = Check.define g ~rec_:true ~partial:true ~name:"tC1" ~reducible:true ~ty ~def in
         let tag = r |> Result.fold ~ok:(fun _ -> "") ~error:Error.tag in
         let msg = r |> Result.fold ~ok:(fun _ -> "") ~error:Error.to_string in
         if Result.is_ok r then
           Error "partial-reducible-conflict: reducible+partial def was ACCEPTED"
         else if String.equal tag "Partial_reducible_conflict" then (
           Printf.printf "  expected error (Partial_reducible_conflict): %s\n" msg;
           Ok ())
         else Error ("partial-reducible-conflict: wrong error: " ^ msg))

(* M3 Stage C, C7 test 2: [partial] on a def whose codomain (after
   peeling its Pi telescope) is not Div-headed is [Partial_not_div],
   fired before the body is even checked (a plain, non-recursive body
   is enough to isolate this check). *)
let case_partial_not_div () : (unit, string) result =
  Tot_surface.Bootstrap.state ()
  |> Result.map_error (fun e -> "bootstrap failed: " ^ Tot_surface.Serror.to_string e)
  |> Result.fold ~error:(fun msg -> Error msg) ~ok:(fun bst ->
         let g = bst.Tot_surface.Run.globals in
         let ty = Term.Pi (qw, "n", Term.Global "Int", Term.Global "Int") in
         let def = Term.Lam (qw, "n", Term.Var 0) in
         let r = Check.define g ~rec_:true ~partial:true ~name:"tC2" ~reducible:false ~ty ~def in
         let tag = r |> Result.fold ~ok:(fun _ -> "") ~error:Error.tag in
         let msg = r |> Result.fold ~ok:(fun _ -> "") ~error:Error.to_string in
         if Result.is_ok r then Error "partial-not-div: non-Div-headed partial def was ACCEPTED"
         else if String.equal tag "Partial_not_div" then (
           Printf.printf "  expected error (Partial_not_div): %s\n" msg;
           Ok ())
         else Error ("partial-not-div: wrong error: " ^ msg))

(* [countdown]'s body: `fun n => match intEq n 0 with | true => pureDiv
   Int 0 | false => countdown n end`. Its ONLY recursive call,
   `countdown n`, passes the UNCHANGED formal, not a structurally
   smaller one, so [Totality.guard] finds no fitting position: a hard
   [Termination] error without [partial], accepted only with it. *)
let countdown_ty : Term.t =
  Term.Pi (qw, "n", Term.Global "Int", Term.App (qw, Term.Global "Div", Term.Global "Int"))

let countdown_body : Term.t =
  Term.Lam
    ( qw,
      "n",
      Term.Match
        {
          scrut = Term.App (qw, Term.App (qw, Term.Global "intEq", Term.Var 0), Term.Lit (Literal.LInt 0));
          scrut_q = qw;
          motive = None;
          branches =
            [
              ( "true",
                [],
                Term.App (qw, Term.App (qw, Term.Global "pureDiv", Term.Global "Int"), Term.Lit (Literal.LInt 0))
              );
              ("false", [], Term.App (qw, Term.Global "countdown", Term.Var 0));
            ];
        } )

(* M3 Stage C, C7 test 3: the guard rejects [countdown] without
   [partial] (Termination), and accepts it WITH [partial] plus a
   Div-headed codomain, storing [reducible = false] and
   [rec_arg = None] on the resulting entry. *)
let case_partial_guard_skip () : (unit, string) result =
  Tot_surface.Bootstrap.state ()
  |> Result.map_error (fun e -> "bootstrap failed: " ^ Tot_surface.Serror.to_string e)
  |> Result.fold ~error:(fun msg -> Error msg) ~ok:(fun bst ->
         let g = bst.Tot_surface.Run.globals in
         let rejected =
           Check.define g ~rec_:true ~partial:false ~name:"countdown" ~reducible:false
             ~ty:countdown_ty ~def:countdown_body
         in
         let rejected_tag = rejected |> Result.fold ~ok:(fun _ -> "") ~error:Error.tag in
         if not (String.equal rejected_tag "Termination") then
           Error
             (Printf.sprintf "partial-guard-skip: expected Termination without partial, got %s"
                (rejected |> Result.fold ~ok:(fun _ -> "<accepted>") ~error:Error.to_string))
         else (
           Printf.printf "  expected error (Termination, no partial): %s\n"
             (rejected |> Result.fold ~ok:(fun _ -> "") ~error:Error.to_string);
           let accepted =
             Check.define g ~rec_:true ~partial:true ~name:"countdown" ~reducible:false
               ~ty:countdown_ty ~def:countdown_body
           in
           accepted
           |> Result.fold
                ~error:(fun e ->
                  Error ("partial-guard-skip: partial def rec was REJECTED: " ^ Error.to_string e))
                ~ok:(fun g' ->
                  Global.find_def "countdown" g'
                  |> Option.to_result ~none:"partial-guard-skip: countdown not found after define"
                  |> Result.fold
                       ~error:(fun msg -> Error msg)
                       ~ok:(fun d ->
                         if (not d.Global.reducible) && Option.is_none d.Global.rec_arg && d.Global.partial
                         then Ok ()
                         else
                           Error
                             (Printf.sprintf
                                "partial-guard-skip: stored entry wrong shape (reducible=%b \
                                 rec_arg=%b partial=%b)"
                                d.Global.reducible (Option.is_some d.Global.rec_arg)
                                d.Global.partial)))))

(* M3 Stage C, C7 (replaces the plan's item 4, "the hole pass": this
   stage shipped the PRE-APPROVED FALLBACK instead, see
   dev/M3-BUILD-LOG.md "Stage C"). A kernel-level counterpart to
   test/surface.ml's positivity control test: [Json]'s self-recursive
   ctors (mentioning the inductive only as itself) are accepted by
   [Check.define_ind] directly, while a "jarr : List T -> T"-style
   nesting is STILL rejected, pinning that the self-recursive encoding
   is load-bearing and no nested-inductive support crept in. *)
let case_json_positivity_kernel () : (unit, string) result =
  Tot_surface.Bootstrap.state ()
  |> Result.map_error (fun e -> "bootstrap failed: " ^ Tot_surface.Serror.to_string e)
  |> Result.fold ~error:(fun msg -> Error msg) ~ok:(fun bst ->
         let g = bst.Tot_surface.Run.globals in
         let good =
           let* g1 = Check.declare_ind g ~name:"JsonK" ~params:[] ~indices:[] ~level:Level.zero in
           Check.define_ind g1 ~name:"JsonK"
             ~ctors:
               [
                 ("jnullK", Term.Global "JsonK");
                 ( "jconsK",
                   Term.Pi
                     ( qw, "_", Term.Global "JsonK",
                       Term.Pi (qw, "_", Term.Global "JsonK", Term.Global "JsonK") ) );
               ]
         in
         good
         |> Result.fold
              ~error:(fun e -> Error ("json-positivity-kernel: self-recursive ctor REJECTED: " ^ Error.to_string e))
              ~ok:(fun _ ->
                let bad =
                  let* g2 = Check.declare_ind g ~name:"JsonBadK" ~params:[] ~indices:[] ~level:Level.zero in
                  Check.define_ind g2 ~name:"JsonBadK"
                    ~ctors:
                      [
                        ( "jarrK",
                          Term.Pi
                            ( qw, "_",
                              Term.App (qw, Term.Global "List", Term.Global "JsonBadK"),
                              Term.Global "JsonBadK" ) );
                      ]
                in
                bad
                |> Result.fold
                     ~ok:(fun _ -> Error "json-positivity-kernel: List JsonBadK -> JsonBadK nesting was ACCEPTED")
                     ~error:(fun e ->
                       Printf.printf "  expected error (Bad_ctor): %s\n" (Error.to_string e);
                       if String.equal (Error.tag e) "Bad_ctor" then Ok ()
                       else Error ("json-positivity-kernel: wrong error: " ^ Error.to_string e))))

(* --- M4 Stage A: indexed inductive families, subsingleton elimination,
   positivity --- *)

(* M4 Stage A: total substring scan (no loop keyword), for error-message
   reason-string assertions where only a SUBSTRING is pinned (the
   Fording positivity/result-head reasons). *)
let rec contains_substring_from (hay : string) (needle : string) (i : int) : bool =
  let hlen = String.length hay in
  let nlen = String.length needle in
  match () with
  | () when i + nlen > hlen -> false
  | () when String.equal (String.sub hay i nlen (* @total-accessor: i + nlen <= hlen guarded above *)) needle -> true
  | () -> contains_substring_from hay needle (i + 1)

let contains_substring (hay : string) (needle : string) : bool =
  if Int.equal (String.length needle) 0 then true else contains_substring_from hay needle 0

(* A1: an indexed family declares, defines, and reports its arity. *)
let a1_vec_params : Global.telescope = [ (q0, "A", ty0) ]
let a1_vec_indices : Global.telescope = [ (q0, "n", nat) ]
let a1_vnil_ty : Term.t = Term.App (qw, Term.App (qw, Term.Global "A1Vec", Term.Var 0), nzero)

let a1_vcons_ty : Term.t =
  Term.Pi
    ( q0, "n", nat,
      Term.Pi
        ( qw, "elem", Term.Var 1,
          Term.Pi
            ( qw, "sub",
              Term.App (qw, Term.App (qw, Term.Global "A1Vec", Term.Var 2), Term.Var 1),
              Term.App (qw, Term.App (qw, Term.Global "A1Vec", Term.Var 3), nsucc (Term.Var 2)) )
        ) )

let a1_declare_vec (g : Global.t) : (Global.t, Error.t) result =
  let* g =
    Check.declare_ind g ~name:"A1Vec" ~params:a1_vec_params ~indices:a1_vec_indices
      ~level:Level.zero
  in
  Check.define_ind g ~name:"A1Vec" ~ctors:[ ("a1vnil", a1_vnil_ty); ("a1vcons", a1_vcons_ty) ]

let case_indexed_family_arity (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = a1_declare_vec globals in
    let* arity =
      Global.find_ind_arity "A1Vec" g |> Option.to_result ~none:(Error.Unbound_global "A1Vec")
    in
    let* ctor =
      Global.find_ctor "a1vcons" g |> Option.to_result ~none:(Error.Unbound_global "a1vcons")
    in
    Ok (arity, ctor)
  in
  attempt
  |> Result.fold
       ~ok:(fun ((n_params, n_indices), (ctor : Global.ctor_entry)) ->
         match () with
         | () when not (Int.equal n_params 1 && Int.equal n_indices 1) ->
             Error (Printf.sprintf "A1: arity got (%d, %d), want (1, 1)" n_params n_indices)
         | () when not (Int.equal ctor.Global.full_arity 4) ->
             Error (Printf.sprintf "A1: full_arity got %d, want 4" ctor.Global.full_arity)
         | () when not ctor.Global.self_rec -> Error "A1: self_rec got false, want true"
         | () when not (Int.equal (List.length ctor.Global.res_idx) 1) ->
             Error
               (Printf.sprintf "A1: res_idx length got %d, want 1"
                  (List.length ctor.Global.res_idx))
         | () -> Ok ())
       ~error:(fun e -> Error ("A1: " ^ Error.to_string e))

(* A2: an index binder marked w is Index_not_zero. *)
let case_index_not_zero (globals : Global.t) () : (unit, string) result =
  Check.declare_ind globals ~name:"A2BadIdxQ" ~params:[] ~indices:[ (qw, "n", nat) ]
    ~level:Level.zero
  |> Result.fold
       ~ok:(fun _g -> Error "A2: an index binder marked w was accepted")
       ~error:(fun e ->
         Printf.printf "  expected error (Index_not_zero): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Index_not_zero" then Ok ()
         else Error ("A2: wrong error: " ^ Error.to_string e))

(* A3: an index type above the declared universe is Index_above_universe. *)
let case_index_above_universe (globals : Global.t) () : (unit, string) result =
  Check.declare_ind globals ~name:"A3BadIdxU" ~params:[] ~indices:[ (q0, "T", ty0) ]
    ~level:Level.zero
  |> Result.fold
       ~ok:(fun _g -> Error "A3: an index type above the declared universe was accepted")
       ~error:(fun e ->
         Printf.printf "  expected error (Index_above_universe): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Index_above_universe" then Ok ()
         else Error ("A3: wrong error: " ^ Error.to_string e))

(* A4: a constructor with the wrong index count is Bad_ctor. *)
let case_bad_ctor_wrong_index_count (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g =
      Check.declare_ind globals ~name:"A4VecB" ~params:[ (q0, "A", ty0) ]
        ~indices:[ (q0, "n", nat) ] ~level:Level.zero
    in
    Check.define_ind g ~name:"A4VecB"
      ~ctors:[ ("a4vbnil", Term.App (qw, Term.Global "A4VecB", Term.Var 0)) ]
  in
  attempt
  |> Result.fold
       ~ok:(fun _g -> Error "A4: a wrong-index-count constructor was accepted")
       ~error:(fun e ->
         Printf.printf "  expected error (Bad_ctor): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Bad_ctor" then Ok ()
         else Error ("A4: wrong error: " ^ Error.to_string e))

(* A5: the Fording route stays blocked. VecP1 isolates the result-head
   rule (vpnil alone); VecP2 isolates strict positivity (vpcons alone,
   with a uniform result codomain "VecP2 A n" so the result-head rule
   passes and only the "sub : VecP2 A m" argument's non-uniform "m" in
   place of the parameter "n" trips positivity). *)
let a5_vecp_params : Global.telescope = [ (q0, "A", ty0); (q0, "n", nat) ]

let case_fording_blocked (globals : Global.t) () : (unit, string) result =
  let attempt1 =
    let* g =
      Check.declare_ind globals ~name:"A5VecP1" ~params:a5_vecp_params ~indices:[]
        ~level:Level.zero
    in
    Check.define_ind g ~name:"A5VecP1"
      ~ctors:[ ("a5vpnil", Term.App (qw, Term.App (qw, Term.Global "A5VecP1", Term.Var 1), nzero)) ]
  in
  let r1 =
    attempt1
    |> Result.fold
         ~ok:(fun _g -> Error "A5: vpnil (Fording result head) was wrongly accepted")
         ~error:(fun e ->
           Printf.printf "  expected error (Bad_ctor, result head): %s\n" (Error.to_string e);
           if not (String.equal (Error.tag e) "Bad_ctor") then
             Error ("A5: wrong error tag: " ^ Error.to_string e)
           else if contains_substring (Error.to_string e) "applied to its parameters" then Ok ()
           else Error ("A5: wrong reason: " ^ Error.to_string e))
  in
  let* () = r1 in
  let attempt2 =
    let* g =
      Check.declare_ind globals ~name:"A5VecP2" ~params:a5_vecp_params ~indices:[]
        ~level:Level.zero
    in
    Check.define_ind g ~name:"A5VecP2"
      ~ctors:
        [
          ( "a5vpcons",
            Term.Pi
              ( q0, "m", nat,
                Term.Pi
                  ( qw, "elem", Term.Var 2,
                    Term.Pi
                      ( qw, "sub",
                        Term.App (qw, Term.App (qw, Term.Global "A5VecP2", Term.Var 3), Term.Var 1),
                        Term.App (qw, Term.App (qw, Term.Global "A5VecP2", Term.Var 4), Term.Var 3)
                      ) ) ) );
        ]
  in
  attempt2
  |> Result.fold
       ~ok:(fun _g -> Error "A5: vpcons (Fording positivity) was wrongly accepted")
       ~error:(fun e ->
         Printf.printf "  expected error (Bad_ctor, positivity): %s\n" (Error.to_string e);
         if not (String.equal (Error.tag e) "Bad_ctor") then
           Error ("A5: wrong error tag: " ^ Error.to_string e)
         else if contains_substring (Error.to_string e) "negative or non-uniform occurrence of"
         then Ok ()
         else Error ("A5: wrong reason: " ^ Error.to_string e))

(* A6: index_expr_clean rejects an index expression mentioning its own
   family. A UNIT test on purpose: the check is a total backstop that no
   source fixture can witness (see its own doc comment in lib/check.ml). *)
let case_index_expr_clean_unit () : (unit, string) result =
  let mentions_self =
    Check.index_expr_clean "I6" (Term.App (qw, Term.Global "I6", Term.Var 0))
  in
  let clean_var = Check.index_expr_clean "I6" (Term.Var 0) in
  match () with
  | () when mentions_self ->
      Error "A6: index_expr_clean accepted an expression mentioning its own family"
  | () when not clean_var -> Error "A6: index_expr_clean rejected a clean Var expression"
  | () -> Ok ()

(* A6b (M4 fixes round 1, audit F3): the index-cleanliness ban is not
   skippable through [auto]. [index_expr_clean] must answer FALSE for an
   unresolved [Term.Auto], bare or nested, because it runs on the RAW
   pre-elaboration constructor type where [auto] stands for a spine the
   resolver has not produced yet and that spine may mention the family.
   The staged Stage A code accepted [Auto] unconditionally, which let
   `data AI : Nat -> Type 0 := | ai : AI auto` past the ban entirely. *)
let case_index_expr_clean_rejects_auto () : (unit, string) result =
  let bare_auto = Check.index_expr_clean "I6b" Term.Auto in
  let nested_auto =
    Check.index_expr_clean "I6b" (Term.App (qw, Term.Global "succ", Term.Auto))
  in
  let clean_global =
    Check.index_expr_clean "I6b" (Term.App (qw, Term.Global "succ", Term.Global "zero"))
  in
  match () with
  | () when bare_auto -> Error "A6b: index_expr_clean accepted a bare auto index expression"
  | () when nested_auto -> Error "A6b: index_expr_clean accepted an auto nested under an App"
  | () when not clean_global ->
      Error "A6b: index_expr_clean rejected an auto-free index expression"
  | () -> Ok ()

(* A6c (M4 fixes round 1, ctxcat id 8): [strip_ann] removes exactly the
   node [infer] itself deletes, so the RAW result-head check sees what
   the stamped one would. Nested annotations collapse; every other head
   is returned unchanged, including one whose ARGUMENT is annotated
   (stripping is a head walk, not a deep rewrite). *)
let case_strip_ann_head () : (unit, string) result =
  let univ = Term.Univ Level.zero in
  let inner = Term.App (qw, Term.Global "F", Term.Var 0) in
  let doubly = Term.Ann (Term.Ann (inner, univ), univ) in
  let arg_annotated = Term.App (qw, Term.Global "F", Term.Ann (Term.Var 0, univ)) in
  let shown (t : Term.t) : string = Pp.term [] t in
  match () with
  | () when not (String.equal (shown (Check.strip_ann doubly)) (shown inner)) ->
      Error
        ("A6c: strip_ann did not collapse nested Ann wrappers to the head term: "
       ^ shown (Check.strip_ann doubly))
  | () when not (String.equal (shown (Check.strip_ann inner)) (shown inner)) ->
      Error "A6c: strip_ann changed an unannotated term"
  | () when not (String.equal (shown (Check.strip_ann arg_annotated)) (shown arg_annotated)) ->
      Error "A6c: strip_ann rewrote an annotated ARGUMENT (it must only strip the head)"
  | () -> Ok ()

(* A7: the subsingleton criterion, all four shapes. The SX row is the
   fence: false because self_rec is true, NOT because of a quantity. *)
let case_zero_eliminable_shapes (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = Check.declare_ind globals ~name:"A7Empty" ~params:[] ~indices:[] ~level:Level.zero in
    let* g = Check.define_ind g ~name:"A7Empty" ~ctors:[] in
    let* empty_ind =
      Global.find_ind "A7Empty" g |> Option.to_result ~none:(Error.Unbound_global "A7Empty")
    in
    let* g = Check.declare_ind g ~name:"A7Sing" ~params:[] ~indices:[] ~level:Level.zero in
    let* g =
      Check.define_ind g ~name:"A7Sing"
        ~ctors:[ ("a7mkSing", Term.Pi (q0, "x", nat, Term.Global "A7Sing")) ]
    in
    let* sing_ind =
      Global.find_ind "A7Sing" g |> Option.to_result ~none:(Error.Unbound_global "A7Sing")
    in
    let* g = Check.declare_ind g ~name:"A7Box" ~params:[] ~indices:[] ~level:Level.zero in
    let* g =
      Check.define_ind g ~name:"A7Box"
        ~ctors:[ ("a7mkBox", Term.Pi (qw, "x", nat, Term.Global "A7Box")) ]
    in
    let* box_ind =
      Global.find_ind "A7Box" g |> Option.to_result ~none:(Error.Unbound_global "A7Box")
    in
    let* g = Check.declare_ind g ~name:"A7SX" ~params:[] ~indices:[] ~level:Level.zero in
    let* g =
      Check.define_ind g ~name:"A7SX"
        ~ctors:[ ("a7wrap", Term.Pi (q0, "s", Term.Global "A7SX", Term.Global "A7SX")) ]
    in
    let* sx_ind =
      Global.find_ind "A7SX" g |> Option.to_result ~none:(Error.Unbound_global "A7SX")
    in
    let* sx_ctor =
      Global.find_ctor "a7wrap" g |> Option.to_result ~none:(Error.Unbound_global "a7wrap")
    in
    Ok (g, empty_ind, sing_ind, box_ind, sx_ind, sx_ctor)
  in
  attempt
  |> Result.fold
       ~ok:(fun (g, empty_ind, sing_ind, box_ind, sx_ind, (sx_ctor : Global.ctor_entry)) ->
         match () with
         | () when not (Check.zero_eliminable g empty_ind) ->
             Error "A7: Empty should be zero_eliminable"
         | () when not (Check.zero_eliminable g sing_ind) ->
             Error "A7: Sing should be zero_eliminable"
         | () when Check.zero_eliminable g box_ind -> Error "A7: Box should NOT be zero_eliminable"
         | () when Check.zero_eliminable g sx_ind -> Error "A7: SX should NOT be zero_eliminable"
         | () when not sx_ctor.Global.self_rec ->
             Error "A7: SX's wrap ctor should have self_rec = true"
         | () -> Ok ())
       ~error:(fun e -> Error ("A7: " ^ Error.to_string e))

(* A8: subst-shaped erasure is the identity. *)
let a8_sing_params : Global.telescope = [ (q0, "A", ty0) ]

let a8_declare_sing (g : Global.t) : (Global.t, Error.t) result =
  let* g = Check.declare_ind g ~name:"A8Sing" ~params:a8_sing_params ~indices:[] ~level:Level.zero in
  Check.define_ind g ~name:"A8Sing"
    ~ctors:[ ("a8mk", Term.App (qw, Term.Global "A8Sing", Term.Var 0)) ]

let a8_elim_ty : Term.t =
  Term.Pi
    ( q0, "A", ty0,
      Term.Pi
        (q0, "s", Term.App (qw, Term.Global "A8Sing", Term.Var 0), Term.Pi (qw, "px", nat, nat))
    )

let a8_elim_def : Term.t =
  Term.Lam
    ( q0, "A",
      Term.Lam
        ( q0, "s",
          Term.Lam
            ( qw, "px",
              Term.Match
                {
                  scrut = Term.Var 1;
                  scrut_q = qw;
                  motive = None;
                  branches = [ ("a8mk", [], Term.Var 0) ];
                } ) ) )

let case_subst_shaped_erasure_identity (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = a8_declare_sing globals in
    let* ty_v = Eval.eval g [] a8_elim_ty in
    let* def' = Check.check g Check.empty_ctx Quantity.Many a8_elim_def ty_v in
    Erase.closed def'
  in
  attempt
  |> Result.fold
       ~ok:(fun e ->
         let got = Pp.eterm [] e in
         if String.equal got "fun px => px" then Ok ()
         else Error (Printf.sprintf "A8: got %s, want \"fun px => px\"" got))
       ~error:(fun e -> Error ("A8: " ^ Error.to_string e))

(* A9: a zero-branch subsingleton match erases to the erased residue.
   Both the scrutinee's OWN binder and the whole match are erased away
   (scrut_q = Zero, zero branches), so the pretty-printed result is
   exactly whatever Pp.eterm prints for EErased -- read from pp.ml, not
   guessed. *)
let a9_declare_empty (g : Global.t) : (Global.t, Error.t) result =
  let* g = Check.declare_ind g ~name:"A9Empty" ~params:[] ~indices:[] ~level:Level.zero in
  Check.define_ind g ~name:"A9Empty" ~ctors:[]

let a9_elim_ty : Term.t = Term.Pi (q0, "e", Term.Global "A9Empty", nat)

let a9_elim_def : Term.t =
  Term.Lam
    (q0, "e", Term.Match { scrut = Term.Var 0; scrut_q = qw; motive = None; branches = [] })

let case_zero_branch_erasure_residue (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = a9_declare_empty globals in
    let* ty_v = Eval.eval g [] a9_elim_ty in
    let* def' = Check.check g Check.empty_ctx Quantity.Many a9_elim_def ty_v in
    Erase.closed def'
  in
  attempt
  |> Result.fold
       ~ok:(fun e ->
         let got = Pp.eterm [] e in
         if String.equal got "<erased>" then Ok ()
         else Error (Printf.sprintf "A9: got %s, want \"<erased>\"" got))
       ~error:(fun e -> Error ("A9: " ^ Error.to_string e))

(* A10: additivity, a materialized constant motive still converts. This
   is the M2 fixes materialization test (F6, "case_uniform_motive" above)
   re-run against the motive RECORD: Term.t's motive changed shape under
   it, and F6 still passes, so this is that same assertion given its own
   Stage A label per the plan's kernel test list. *)

(* A11: Term.Auto is rejected by every kernel pass. *)
let case_auto_rejected_everywhere (globals : Global.t) () : (unit, string) result =
  let check_one : 'a. string -> ('a, Error.t) result -> (unit, string) result =
   fun label r ->
    r
    |> Result.fold
         ~ok:(fun _ -> Error (Printf.sprintf "A11: %s accepted Term.Auto" label))
         ~error:(fun e ->
           Printf.printf "  expected error (Cannot_infer, %s): %s\n" label (Error.to_string e);
           if String.equal (Error.tag e) "Cannot_infer" then Ok ()
           else Error (Printf.sprintf "A11: %s wrong error: %s" label (Error.to_string e)))
  in
  let* () = check_one "Eval.eval" (Eval.eval globals [] Term.Auto) in
  let* () = check_one "Erase.closed" (Erase.closed Term.Auto) in
  check_one "Check.infer" (Check.infer globals Check.empty_ctx Quantity.Many Term.Auto)

(* A12: a builtin type former reports Builtin_not_eliminable; a
   Provisional inductive still reports Ind_incomplete, in the same case,
   so the split is shown to be a split. *)
let a12_opaque_of_type (name : string) (ty_name : string) (g : Global.t) : Global.t =
  Global.add name
    (Global.Def
       {
         Global.ty = Term.Global ty_name;
         def = Term.Univ Level.zero;
         reducible = false;
         rec_arg = None;
         partial = false;
       })
    g

let a12_match_on (scrut_name : string) : Term.t =
  Term.Match { scrut = Term.Global scrut_name; scrut_q = qw; motive = None; branches = [] }

let case_builtin_vs_provisional (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = Check.declare_builtin globals ~name:"A12String" ~params:[] in
    let* g =
      Check.declare_ind g ~name:"A12Prov" ~params:[] ~indices:[] ~level:Level.zero
    in
    let g = a12_opaque_of_type "a12sbad" "A12String" g in
    let g = a12_opaque_of_type "a12pbad" "A12Prov" g in
    Ok g
  in
  attempt
  |> Result.fold
       ~ok:(fun g ->
         let builtin_result = Check.infer g Check.empty_ctx Quantity.Many (a12_match_on "a12sbad") in
         let prov_result = Check.infer g Check.empty_ctx Quantity.Many (a12_match_on "a12pbad") in
         builtin_result
         |> Result.fold
              ~ok:(fun _ -> Error "A12: match on a builtin-typed neutral was accepted")
              ~error:(fun e1 ->
                Printf.printf "  expected error (Builtin_not_eliminable): %s\n" (Error.to_string e1);
                if not (String.equal (Error.tag e1) "Builtin_not_eliminable") then
                  Error ("A12: builtin case wrong error: " ^ Error.to_string e1)
                else
                  prov_result
                  |> Result.fold
                       ~ok:(fun _ -> Error "A12: match on a provisional-typed neutral was accepted")
                       ~error:(fun e2 ->
                         Printf.printf "  expected error (Ind_incomplete): %s\n"
                           (Error.to_string e2);
                         if String.equal (Error.tag e2) "Ind_incomplete" then Ok ()
                         else Error ("A12: provisional case wrong error: " ^ Error.to_string e2))))
       ~error:(fun e -> Error ("A12: " ^ Error.to_string e))

(* M4 Stage B: the axiom entry kind. *)

(* B1: define_axiom installs an opaque global: it evaluates to a bare
   neutral over its own name (no [def] to unfold to, exactly like a
   Prim), and is not convertible with an unrelated canonical value. *)
let case_define_axiom_opaque (globals : Global.t) () : (unit, string) result =
  let* g = Check.define_axiom globals ~name:"ax_b1" ~ty:nat |> Result.map_error Error.to_string in
  let* v = Eval.eval g [] (Term.Global "ax_b1") |> Result.map_error Error.to_string in
  let* zv = Eval.eval g [] nzero |> Result.map_error Error.to_string in
  let* conv_to_zero = Eval.conv g 0 v zv |> Result.map_error Error.to_string in
  match v with
  | Value.VNeutral (Value.HGlobal "ax_b1", []) ->
      if conv_to_zero then Error "B1: ax_b1 is wrongly convertible with zero" else Ok ()
  | Value.VNeutral (_, _) -> Error "B1: ax_b1 evaluated to the wrong neutral shape"
  | Value.VUniv _ | Value.VPi (_, _, _, _) | Value.VLam (_, _) | Value.VInd (_, _)
  | Value.VCtor (_, _) | Value.VLit _ ->
      Error "B1: define_axiom did not install an opaque neutral global"

(* B2: an axiom used at quantity mode w is Axiom_runtime_use; the same
   global at mode 0 succeeds, with its stored type. *)
let case_axiom_runtime_use (globals : Global.t) () : (unit, string) result =
  let* g = Check.define_axiom globals ~name:"ax_b2" ~ty:nat |> Result.map_error Error.to_string in
  let* () =
    Check.infer g Check.empty_ctx Quantity.Many (Term.Global "ax_b2")
    |> Result.fold
         ~ok:(fun _ -> Error "B2: axiom accepted at quantity Many")
         ~error:(fun e ->
           Printf.printf "  expected error (Axiom_runtime_use): %s\n" (Error.to_string e);
           if String.equal (Error.tag e) "Axiom_runtime_use" then Ok ()
           else Error ("B2: wrong error: " ^ Error.to_string e))
  in
  let* _tm, ty_v =
    Check.infer g Check.empty_ctx Quantity.Zero (Term.Global "ax_b2")
    |> Result.map_error Error.to_string
  in
  let* want_v = Eval.eval g [] nat |> Result.map_error Error.to_string in
  let* ok = Eval.conv g 0 ty_v want_v |> Result.map_error Error.to_string in
  if ok then Ok () else Error "B2: axiom's stored type at mode 0 is not Nat"

(* B3: define_axiom rejects a duplicate name, exactly like [define]. *)
let case_axiom_duplicate (globals : Global.t) () : (unit, string) result =
  Check.define_axiom globals ~name:"Nat" ~ty:ty0
  |> Result.fold
       ~ok:(fun _g -> Error "B3: define_axiom accepted a duplicate name (Nat)")
       ~error:(fun e ->
         if String.equal (Error.tag e) "Duplicate_global" then Ok ()
         else Error ("B3: wrong error: " ^ Error.to_string e))

(* B4: an axiom is not a def, an ind, a ctor, or a prim; [entry_ty]
   still returns its stored type. *)
let case_axiom_not_other_kinds (globals : Global.t) () : (unit, string) result =
  let* g = Check.define_axiom globals ~name:"ax_b4" ~ty:nat |> Result.map_error Error.to_string in
  let* entry =
    Global.find "ax_b4" g |> Option.to_result ~none:"B4: ax_b4 not found after define_axiom"
  in
  let* () =
    if Option.is_some (Global.def_of entry) then Error "B4: def_of returned Some for an axiom"
    else Ok ()
  in
  let* () =
    if Option.is_some (Global.ind_of entry) then Error "B4: ind_of returned Some for an axiom"
    else Ok ()
  in
  let* () =
    if Option.is_some (Global.ctor_of entry) then Error "B4: ctor_of returned Some for an axiom"
    else Ok ()
  in
  let* () =
    if Option.is_some (Global.prim_of entry) then Error "B4: prim_of returned Some for an axiom"
    else Ok ()
  in
  let* got_ty = Eval.eval g [] (Global.entry_ty entry) |> Result.map_error Error.to_string in
  let* want_ty = Eval.eval g [] nat |> Result.map_error Error.to_string in
  let* ok = Eval.conv g 0 got_ty want_ty |> Result.map_error Error.to_string in
  if ok then Ok () else Error "B4: entry_ty did not return the stored type"

(* --- M4 Stage C: the executable erasure backstop --- *)

(* C1: [Eterm.mentions] is exhaustive and correct. A single probe shape
   buries an [EGlobal] under [ELam], [EApp], [ELet] and an [EMatch]
   branch; asserting [true] on the buried name and [false] on a
   different name of the same shape rules out both a missed arm and a
   name-blind walk. *)
let case_eterm_mentions_exhaustive () : (unit, string) result =
  let probe (target : string) : Eterm.t =
    Eterm.ELam
      ( "x",
        Eterm.EApp
          ( Eterm.EErased,
            Eterm.ELet
              ( "y",
                Eterm.EVar 0,
                Eterm.EMatch (Eterm.EVar 0, [ ("ctorA", [ "p" ], Eterm.EGlobal target) ]) ) ) )
  in
  match () with
  | () when not (Eterm.mentions "needle" (probe "needle")) ->
      Error "C1: Eterm.mentions missed an EGlobal buried under ELam/EApp/ELet/EMatch"
  | () when Eterm.mentions "needle" (probe "other") ->
      Error "C1: Eterm.mentions false-matched a differently named EGlobal"
  | () -> Ok ()

(* C3: a [Frozen] global stays neutral under application, and does not
   even try to force its body. [loopy]'s stored body is
   [EApp (EGlobal "loopy", EGlobal "loopy")]: forcing it would recurse
   through [exec]'s [EGlobal] arm onto the SAME still-[GDeferred] cell
   before ever writing back a memoized value, diverging. Seeding it with
   [~guard:Interp.Frozen] means [exec]'s [EGlobal] arm never calls
   [force] at all (see [Interp.exec]'s three-way match), so applying the
   resulting neutral to a canonical constructor value cannot loop; this
   case's own assertion is simply that it RETURNS the exact frozen
   spine, not a hang the suite's gate-level watchdog would have to
   catch. *)
let case_frozen_stays_neutral () : (unit, string) result =
  let loopy_body : Eterm.t = Eterm.EApp (Eterm.EGlobal "loopy", Eterm.EGlobal "loopy") in
  let eglobals_with_ctor = Interp.add_ctor Interp.empty_globals ~name:"unit0" ~arity:0 in
  let eglobals = Interp.define eglobals_with_ctor ~name:"loopy" ~guard:Interp.Frozen loopy_body in
  let attempt =
    let* v = Interp.exec eglobals [] (Eterm.EApp (Eterm.EGlobal "loopy", Eterm.EGlobal "unit0")) in
    Interp.quote eglobals 0 v
  in
  attempt
  |> Result.fold
       ~ok:(fun e ->
         let got = Pp.eterm [] e in
         if String.equal got "(loopy unit0)" then Ok ()
         else Error (Printf.sprintf "C3: got %s, want (loopy unit0)" got))
       ~error:(fun e -> Error ("C3: " ^ Error.to_string e))

(* --- M4 Stage D: deterministic type classes --- *)

(* A single-parameter class [Cls] over a nullary key [Key], hand-built
   exactly like [Nat]/[Opt] above: [Cls : (0 A : Type 0) -> Type 0] with
   sole constructor [mkCls : (x : A) -> Cls A], and [Key : Type 0] with
   sole constructor [mkKey : Key]. *)
let d_cls_ctor_ty : Term.t =
  Term.Pi (qw, "x", Term.Var 0, Term.App (qw, Term.Global "Cls", Term.Var 1))

let d_build_cls_key (g : Global.t) : (Global.t, Error.t) result =
  let* g =
    Check.declare_ind g ~name:"Cls" ~params:[ (q0, "A", ty0) ] ~indices:[] ~level:Level.zero
  in
  let* g = Check.define_ind g ~name:"Cls" ~ctors:[ ("mkCls", d_cls_ctor_ty) ] in
  let* g = Check.declare_ind g ~name:"Key" ~params:[] ~indices:[] ~level:Level.zero in
  Check.define_ind g ~name:"Key" ~ctors:[ ("mkKey", Term.Global "Key") ]

let d_inst_ty : Term.t = Term.App (qw, Term.Global "Cls", Term.Global "Key")
let d_inst_def : Term.t = Term.App (qw, Term.App (qw, Term.Global "mkCls", Term.Global "Key"), Term.Global "mkKey")

let d_build_inst_cls_key (g : Global.t) : (Global.t, Error.t) result =
  let* g = d_build_cls_key g in
  Check.define g ~name:"inst$Cls$Key" ~reducible:true ~ty:d_inst_ty ~def:d_inst_def

let d_build_wrap (g : Global.t) : (Global.t, Error.t) result =
  Check.declare_ind g ~name:"Wrap" ~params:[ (q0, "A", ty0) ] ~indices:[] ~level:Level.zero

(* D1: Auto resolves from the expected type: the resolved term prints as
   exactly the mangled instance global, no App wrapping (the instance is
   ground, its own type has no leading Pi). *)
let case_auto_resolves_from_expected (globals : Global.t) () : (unit, string) result =
  let* g = d_build_inst_cls_key globals |> Result.map_error Error.to_string in
  let expected_v = Value.VInd ("Cls", [ Value.VInd ("Key", []) ]) in
  let* tm =
    Check.check g Check.empty_ctx qw Term.Auto expected_v |> Result.map_error Error.to_string
  in
  let got = Pp.term [] tm in
  if String.equal got "inst$Cls$Key" then Ok ()
  else Error (Printf.sprintf "D1: got %s, want inst$Cls$Key" got)

(* D2: Auto against a non-class expected type is Inst_unresolved. *)
let case_auto_non_class_unresolved (globals : Global.t) () : (unit, string) result =
  let* g = d_build_inst_cls_key globals |> Result.map_error Error.to_string in
  Check.check g Check.empty_ctx qw Term.Auto (Value.VUniv Level.zero)
  |> Result.fold
       ~ok:(fun _ -> Error "D2: Auto against Type 0 unexpectedly resolved")
       ~error:(fun e ->
         Printf.printf "  expected error (Inst_unresolved): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Inst_unresolved" then Ok ()
         else Error ("D2: wrong error: " ^ Error.to_string e))

(* D3: Auto against a class applied to a variable is Inst_unresolved:
   there is no instance for a type VARIABLE, only for a concrete head. *)
let case_auto_class_var_unresolved (globals : Global.t) () : (unit, string) result =
  let* g = d_build_inst_cls_key globals |> Result.map_error Error.to_string in
  let ctx = Check.bind "x" q0 (Value.VUniv Level.zero) Check.empty_ctx in
  let expected_v = Value.VInd ("Cls", [ Value.VNeutral (Value.HVar 0, []) ]) in
  Check.check g ctx qw Term.Auto expected_v
  |> Result.fold
       ~ok:(fun _ -> Error "D3: Auto against (Cls x) unexpectedly resolved")
       ~error:(fun e ->
         Printf.printf "  expected error (Inst_unresolved): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Inst_unresolved" then Ok ()
         else Error ("D3: wrong error: " ^ Error.to_string e))

(* D4: a missing instance (Cls and Key both exist, but no inst$Cls$Key)
   is Inst_unresolved. *)
let case_auto_missing_instance_unresolved (globals : Global.t) () : (unit, string) result =
  let* g = d_build_cls_key globals |> Result.map_error Error.to_string in
  let expected_v = Value.VInd ("Cls", [ Value.VInd ("Key", []) ]) in
  Check.check g Check.empty_ctx qw Term.Auto expected_v
  |> Result.fold
       ~ok:(fun _ -> Error "D4: Auto against a missing instance unexpectedly resolved")
       ~error:(fun e ->
         Printf.printf "  expected error (Inst_unresolved): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Inst_unresolved" then Ok ()
         else Error ("D4: wrong error: " ^ Error.to_string e))

(* D5: a duplicate instance key is Duplicate_global, with "inst$" in the
   message. *)
let case_duplicate_instance_is_duplicate_global (globals : Global.t) () : (unit, string) result =
  let* g = d_build_cls_key globals |> Result.map_error Error.to_string in
  let* g2 =
    Check.define_instance g ~name:"inst$Cls$Key" ~ty:d_inst_ty ~def:d_inst_def
    |> Result.map_error Error.to_string
  in
  Check.define_instance g2 ~name:"inst$Cls$Key" ~ty:d_inst_ty ~def:d_inst_def
  |> Result.fold
       ~ok:(fun _ -> Error "D5: a duplicate instance key unexpectedly registered")
       ~error:(fun e ->
         Printf.printf "  expected error (Duplicate_global): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Duplicate_global" && contains_substring (Error.to_string e) "inst$"
         then Ok ()
         else Error ("D5: wrong error: " ^ Error.to_string e))

(* D6: a ground instance at an applied key (Cls (Wrap Key), no type
   binder) is Inst_bad_shape: [Wrap] declared (params known, no ctors
   needed for a TYPE-level check) so [Cls (Wrap Key)] kind-checks, but
   the key is applied to one argument against zero recorded type
   binders. *)
let case_ground_applied_key_is_bad_shape (globals : Global.t) () : (unit, string) result =
  let* g = d_build_cls_key globals |> Result.map_error Error.to_string in
  let* g = d_build_wrap g |> Result.map_error Error.to_string in
  let ty =
    Term.App (qw, Term.Global "Cls", Term.App (qw, Term.Global "Wrap", Term.Global "Key"))
  in
  Check.define_instance g ~name:"inst$Cls$Wrap" ~ty ~def:(Term.Global "Key")
  |> Result.fold
       ~ok:(fun _ -> Error "D6: a ground instance at an applied key unexpectedly registered")
       ~error:(fun e ->
         Printf.printf "  expected error (Inst_bad_shape): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Inst_bad_shape" then Ok ()
         else Error ("D6: wrong error: " ^ Error.to_string e))

(* D7: instance resolution is fuel bounded: [build_instance] called
   directly with fuel 0 is Inst_depth, whatever [ity] is. M4 fixes
   round 3 (opus R3-1): the bare fuel int is now an [inst_state] (fuel
   plus the memo plus the goal the error names), so the call spells
   [Check.inst_start 0 ity]. The assertion is unchanged: fuel 0 is
   Inst_depth, and the memo starts EMPTY so it cannot answer instead. *)
let case_instance_resolution_fuel_bounded (globals : Global.t) () : (unit, string) result =
  let* g = d_build_inst_cls_key globals |> Result.map_error Error.to_string in
  let ity = Value.VInd ("Cls", [ Value.VInd ("Key", []) ]) in
  Check.build_instance g Check.empty_ctx (Check.inst_start 0 ity) ity []
    (Term.Global "inst$Cls$Key")
  |> Result.fold
       ~ok:(fun _ -> Error "D7: build_instance with fuel 0 unexpectedly resolved")
       ~error:(fun e ->
         Printf.printf "  expected error (Inst_depth): %s\n" (Error.to_string e);
         if String.equal (Error.tag e) "Inst_depth" then Ok ()
         else Error ("D7: wrong error: " ^ Error.to_string e))

(* D7b: M4 fixes round 3 (opus R3-6). [Inst_depth]'s payload names the
   ORIGINAL query, not the partially peeled instance type the call
   happens to be holding when the budget runs out. Round 2 rendered
   [ity], so a query at nesting 20 was reported as a four-level Pi
   telescope naming neither the user's goal nor an unresolvable one.
   Built the same way the failure reaches it: [goal] is a class
   application, [ity] is a Pi, and they are DIFFERENT values, so the
   message can only be right for one reason. *)
let case_inst_depth_names_the_query (globals : Global.t) () : (unit, string) result =
  let* g = d_build_inst_cls_key globals |> Result.map_error Error.to_string in
  let* g = d_build_wrap g |> Result.map_error Error.to_string in
  let cls_key = Term.App (qw, Term.Global "Cls", Term.Global "Key") in
  let* ity =
    Eval.eval g [] (Term.Pi (qw, "_", cls_key, cls_key)) |> Result.map_error Error.to_string
  in
  let goal = Value.VInd ("Cls", [ Value.VInd ("Wrap", [ Value.VInd ("Key", []) ]) ]) in
  Check.build_instance g Check.empty_ctx (Check.inst_start 0 goal) ity []
    (Term.Global "inst$Cls$Wrap")
  |> Result.fold
       ~ok:(fun _ -> Error "D7b: build_instance with fuel 0 unexpectedly resolved")
       ~error:(fun e ->
         let msg = Error.to_string e in
         Printf.printf "  expected error (Inst_depth): %s\n" msg;
         let names_goal = contains_substring msg "(Cls (Wrap Key))" in
         let names_ity = contains_substring msg "->" in
         match () with
         | () when not (String.equal (Error.tag e) "Inst_depth") ->
             Error ("D7b: wrong error: " ^ msg)
         | () when not names_goal -> Error ("D7b: message does not name the query: " ^ msg)
         | () when names_ity -> Error ("D7b: message still names the peeled Pi: " ^ msg)
         | () -> Ok ())

(* D8: checker output never contains Auto. A small exhaustive [Term.t]
   walk, written fresh here (not reused from [lib/check.ml]) so the test
   is an independent witness. *)
let rec d_contains_auto (t : Term.t) : bool =
  match t with
  | Term.Auto -> true
  | Term.Var _ | Term.Univ _ | Term.Lit _ | Term.Global _ -> false
  | Term.Pi (_, _, dom, cod) -> d_contains_auto dom || d_contains_auto cod
  | Term.Lam (_, _, body) -> d_contains_auto body
  | Term.App (_, f, a) -> d_contains_auto f || d_contains_auto a
  | Term.Let (_, ty, def, body) ->
      d_contains_auto ty || d_contains_auto def || d_contains_auto body
  | Term.Ann (tm, ty) -> d_contains_auto tm || d_contains_auto ty
  | Term.Match { scrut; scrut_q = _; motive; branches } ->
      d_contains_auto scrut
      || (motive
         |> Option.fold ~none:false ~some:(fun (mo : Term.motive) -> d_contains_auto mo.Term.m_body))
      || List.exists (fun (_c, _bs, b) -> d_contains_auto b) branches

let case_checker_output_never_contains_auto (globals : Global.t) () : (unit, string) result =
  let* g = d_build_inst_cls_key globals |> Result.map_error Error.to_string in
  let expected_v = Value.VInd ("Cls", [ Value.VInd ("Key", []) ]) in
  let* tm =
    Check.check g Check.empty_ctx qw Term.Auto expected_v |> Result.map_error Error.to_string
  in
  if d_contains_auto tm then
    Error (Printf.sprintf "D8: checker output still contains Auto: %s" (Pp.term [] tm))
  else Ok ()

(* A13: M4 fixes round 4 (ctxcat r4 id 0). The motive's index binders on
   a family with TWO indices, which is the smallest family that can tell
   the two candidate conventions apart (Vec has one, and one index is
   symmetric under any reordering). The convention, stated once on
   [Term.motive]: [m_idx] is in DECLARATION order (outermost first),
   while inside [m_body] de Bruijn 0 is [m_self], de Bruijn 1 is the LAST
   element of [m_idx] and de Bruijn [m] is its FIRST. Both halves are
   asserted here, and each of the three modules that reads the field is
   on the hook for one of them:

   - Check.infer BINDS them, and it binds by list order, so with
     [m_idx = ["i"; "c"]] and indices declared [Nat] then [Bool] the
     motive body [Var 1] is [c], the SECOND index, whose value at this
     scrutinee is [Bool]. The branch body is [true], so the whole match
     type-checks only under that reading: reverse the order anywhere in
     the binding walk and [Var 1] becomes [Nat], which [true] fails.
   - Eval.quote round-trips it: evaluating and quoting the checked term
     must reproduce the same motive, indices included.
   - Pp.term prints the "in" clause in LIST order, so the round-tripped
     term must read "in A13Tw i c", not "in A13Tw c i".

   The finding that prompted this read the eval.ml comment's "index" as
   a position in [m_idx] rather than a de Bruijn index and concluded the
   three comments contradicted each other. They did not; the comments
   are now explicit about which axis they mean, and this case is the
   executable statement of the convention.

   M4 fixes round 5 (opus R5-1): round 4's version of this case pinned
   NEITHER of the two mechanisms [Term.motive]'s comment names. Executed
   in a scratch copy, both of these mutations kept the whole battery at
   274 PASS / 0 FAIL:

   - lib/pp.ml, [mo.Term.m_self :: List.rev mo.Term.m_idx @ names]
     with the [List.rev] DROPPED. The printed motive body silently
     flipped from the second index to the first, and every assertion
     here read the "in" clause, which the mutation does not touch.
   - lib/eval.ml, [List.init m (fun i -> Value.var (size + m - 1 - i))]
     replaced by [size + i]. [Eval.quote] copies [m_idx] verbatim, so
     the "in" clause survives any level arithmetic; only [m_body]
     moves, and round 4 never asserted the round-tripped body.

   Both are pinned now, on the two axes independently:

   - the motive BODY is [a13snd i c], which names BOTH index binders in
     ORDER, on a family whose two indices are DIFFERENT types at this
     scrutinee ([Nat] and [Bool]). So the printed checked term reads
     "return ((a13snd i) c)" and a dropped [List.rev] prints
     "((a13snd c) i)" instead: a textual FAIL, not a silent flip.
   - the ROUND-TRIPPED motive body is asserted STRUCTURALLY, as
     [Term.Var 1], which is [Pp]-independent, so a skewed level in
     [Eval.quote] ([Term.Var 2], the FIRST index) fails here even if
     the printer is broken in the same run.
   - the inferred TYPE is still asserted exactly ("Bool"), which is the
     evaluated result and the pin on [Check.infer]'s binding walk:
     [a13snd] is reducible and returns its SECOND argument, so a flip
     anywhere in the binding walk makes the motive [Nat] and the
     branch body [true] stops checking. *)

(* [a13snd a b = b], reducible, so the motive body [a13snd i c] both
   NAMES the two index binders in order (for the printed pin) and
   REDUCES to the second one (for the type pin). An opaque selector
   would leave the motive a neutral type that [true] cannot check
   against. *)
let a13_snd (g : Global.t) : Global.t =
  Global.add "a13snd"
    (Global.Def
       {
         Global.ty = Term.Pi (qw, "a", ty0, Term.Pi (qw, "b", ty0, ty0));
         def = Term.Lam (qw, "a", Term.Lam (qw, "b", Term.Var 0));
         reducible = true;
         rec_arg = None;
         partial = false;
       })
    g

(* The motive of an already-quoted term, or [None] for every shape
   [Eval.quote]'s FMatch arm cannot have produced. [None] is a FAIL at
   the call site, never a silently skipped assertion. *)
let a13_motive_of (tm : Term.t) : Term.motive option =
  match tm with
  | Term.Match { scrut = _; scrut_q = _; motive; branches = _ } -> motive
  | Term.Var _ | Term.Univ _
  | Term.Pi (_, _, _, _)
  | Term.Lam (_, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Lit _ | Term.Auto ->
      None

(* De Bruijn 1 inside [m_body] is the LAST element of [m_idx], which is
   [c], the Bool index. Read structurally so this assertion survives a
   broken printer. *)
let a13_body_is_second_index (mo : Term.motive) : bool =
  match mo.Term.m_body with
  | Term.Var 1 -> true
  | Term.Var _ | Term.Univ _
  | Term.Pi (_, _, _, _)
  | Term.Lam (_, _, _)
  | Term.App (_, _, _)
  | Term.Let (_, _, _, _)
  | Term.Ann (_, _)
  | Term.Global _ | Term.Lit _ | Term.Auto | Term.Match _ ->
      false

let a13_declare (g : Global.t) : (Global.t, Error.t) result =
  (* [Bool] is not in the shared kernel globals (the M0 fixture set is
     Church-encoded), so this case declares its own, exactly as the
     uniform-motive case above does. *)
  let* g = Check.declare_ind g ~name:"Bool" ~params:[] ~indices:[] ~level:Level.zero in
  let* g = Check.define_ind g ~name:"Bool" ~ctors:[ ("true", bool_ty); ("false", bool_ty) ] in
  let* g =
    Check.declare_ind g ~name:"A13Tw" ~params:[]
      ~indices:[ (q0, "p", ty0); (q0, "q", ty0) ]
      ~level:Level.one
  in
  Check.define_ind g ~name:"A13Tw"
    ~ctors:[ ("a13tw", Term.App (qw, Term.App (qw, Term.Global "A13Tw", nat), bool_ty)) ]

(* [m_body] is [a13snd i c]: de Bruijn 2 is [i] (the FIRST element of
   [m_idx]) and de Bruijn 1 is [c] (the LAST), so the body names both
   binders in declaration order and reduces to [c]. *)
let a13_motive : Term.motive =
  {
    Term.m_ind = Some "A13Tw";
    m_idx = [ "i"; "c" ];
    m_self = "x";
    m_body = Term.App (qw, Term.App (qw, Term.Global "a13snd", Term.Var 2), Term.Var 1);
  }

(* The scrutinee is an OPAQUE neutral of type [A13Tw Nat Bool], not the
   constructor: a canonical scrutinee makes the match REDUCE, and a
   reduced term has no motive left for [Eval.quote]'s FMatch arm (the
   arm this case exists to exercise) to round-trip. *)
let a13_opaque (g : Global.t) : Global.t =
  Global.add "a13op"
    (Global.Def
       {
         Global.ty = Term.App (qw, Term.App (qw, Term.Global "A13Tw", nat), bool_ty);
         def = Term.Global "a13tw";
         reducible = false;
         rec_arg = None;
         partial = false;
       })
    g

let a13_match : Term.t =
  Term.Match
    {
      scrut = Term.Global "a13op";
      scrut_q = qw;
      motive = Some a13_motive;
      branches = [ ("a13tw", [], Term.Global "true") ];
    }

let case_motive_index_binder_order (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = a13_declare globals in
    let g = a13_opaque g in
    let g = a13_snd g in
    let* tm, ty = Check.infer g Check.empty_ctx qw a13_match in
    let* ty_t = Eval.quote g 0 ty in
    let* tm_v = Eval.eval g [] tm in
    let* tm_rt = Eval.quote g 0 tm_v in
    Ok (Pp.term [] tm, Pp.term [] ty_t, Pp.term [] tm_rt, a13_motive_of tm_rt)
  in
  attempt
  |> Result.fold
       ~ok:(fun (printed, ty_s, round_tripped, rt_motive) ->
         Printf.printf "  A13 motive: %s\n" printed;
         Printf.printf "  A13 round trip: %s\n" round_tripped;
         let rt_body_ok =
           rt_motive |> Option.fold ~none:false ~some:a13_body_is_second_index
         in
         match () with
         | () when not (String.equal ty_s "Bool") ->
             Error (Printf.sprintf "A13: result type got %s, want Bool (de Bruijn 1 is the LAST index)" ty_s)
         | () when not (contains_substring printed "in A13Tw i c") ->
             Error (Printf.sprintf "A13: printed motive is not in list order: %s" printed)
         | () when contains_substring printed "in A13Tw c i" ->
             Error (Printf.sprintf "A13: printed motive is reversed: %s" printed)
         (* M4 fixes round 5 (opus R5-1): the printed BODY, not only the
            "in" clause. Dropping [Pp.term]'s [List.rev m_idx] leaves the
            "in" clause untouched and flips exactly this. *)
         | () when not (contains_substring printed "return ((a13snd i) c)") ->
             Error (Printf.sprintf "A13: printed motive body is not in de Bruijn order: %s" printed)
         | () when contains_substring printed "((a13snd c) i)" ->
             Error (Printf.sprintf "A13: printed motive body is reversed: %s" printed)
         | () when not (contains_substring round_tripped "in A13Tw i c") ->
             Error (Printf.sprintf "A13: quote lost the index order: %s" round_tripped)
         (* M4 fixes round 5 (opus R5-1): [Eval.quote] copies [m_idx]
            verbatim, so the "in" clause above cannot see its level
            arithmetic. The round-tripped BODY can, and is read
            STRUCTURALLY so a broken printer cannot mask it. *)
         | () when not rt_body_ok ->
             Error
               (Printf.sprintf
                  "A13: round-tripped motive body is not de Bruijn 1 (the LAST index): %s"
                  round_tripped)
         | () when not (contains_substring round_tripped "return c with") ->
             Error (Printf.sprintf "A13: round-tripped motive body prints wrong: %s" round_tripped)
         | () -> Ok ())
       ~error:(fun e -> Error ("A13: " ^ Error.to_string e))

(* D7c: M4 fixes round 4 (opus R4-5). [Inst_depth]'s payload is ELIDED,
   so the one stderr line the driver contract promises is a BOUNDED
   line. Round 3 made the payload name the original query, which is the
   right payload, but [pp_value] then rendered the whole query on the
   failure path: measured on a wide query, one line of 31,748 bytes. The
   goal here is a deep [Wrap] nest whose printed form is far past the
   cap, so the assertion is on the LENGTH: the message must stay under a
   bound that does not move with the input. D7b above pins that a SHORT
   goal is still named in full, so the cap cannot be satisfied by
   dropping the payload. *)
let rec d7c_nest (n : int) (v : Value.t) : Value.t =
  match () with
  | () when n <= 0 -> v
  | () -> d7c_nest (n - 1) (Value.VInd ("Wrap", [ v ]))

let case_inst_depth_message_is_bounded (globals : Global.t) () : (unit, string) result =
  let* g = d_build_inst_cls_key globals |> Result.map_error Error.to_string in
  let* g = d_build_wrap g |> Result.map_error Error.to_string in
  let cls_key = Term.App (qw, Term.Global "Cls", Term.Global "Key") in
  let* ity =
    Eval.eval g [] (Term.Pi (qw, "_", cls_key, cls_key)) |> Result.map_error Error.to_string
  in
  let goal = Value.VInd ("Cls", [ d7c_nest 400 (Value.VInd ("Key", [])) ]) in
  Check.build_instance g Check.empty_ctx (Check.inst_start 0 goal) ity []
    (Term.Global "inst$Cls$Wrap")
  |> Result.fold
       ~ok:(fun _ -> Error "D7c: build_instance with fuel 0 unexpectedly resolved")
       ~error:(fun e ->
         let msg = Error.to_string e in
         let n = String.length msg in
         Printf.printf "  expected error (Inst_depth), %d bytes\n" n;
         let bare = Error.to_string (Error.Inst_depth "") in
         let budget = String.length bare + Check.goal_print_cap + 3 in
         match () with
         | () when not (String.equal (Error.tag e) "Inst_depth") ->
             Error ("D7c: wrong error: " ^ Error.to_string e)
         | () when n > budget ->
             Error (Printf.sprintf "D7c: message is %d bytes, budget %d" n budget)
         | () when not (contains_substring msg "...") ->
             Error "D7c: an over-cap goal was not marked elided"
         | () -> Ok ())

(* D7d: M4 fixes round 5 (opus R5-5, ctxcat r5 id 15). D7c pins ONE
   constructor; the payload is shared by a FAMILY. Measured on the
   round-4 binary, worst single stderr line per file: Inst_depth 503
   bytes (capped), Inst_unresolved 32,122, Mismatch 800,162 (two
   uncapped payloads). [Inst_unresolved] is also the far more reachable
   of the two instance errors: it fires on any missing or misspelled
   instance, while [Inst_depth] is documented as a backstop that must
   not fire on legitimate input.

   The strongest available oracle is INDEPENDENCE, not a constant: the
   same shape is built at two very different sizes and the two messages
   must have the SAME length. That is the property the cap exists to
   deliver ("a diagnostic's size is a property of the DIAGNOSTIC and
   never of the input"), and unlike a magic number it cannot be
   satisfied by moving [goal_print_cap]. The short-message half is
   asserted too, so the cap cannot be met by dropping the payload. *)
let d7d_nest_t (n : int) (t : Term.t) : Term.t =
  List.fold_left (fun acc _i -> Term.App (qw, Term.Global "Wrap", acc)) t (List.init n Fun.id)

let d7d_opaque (name : string) (ty : Term.t) (g : Global.t) : Global.t =
  Global.add name
    (Global.Def { Global.ty; def = Term.Global "mkKey"; reducible = false; rec_arg = None; partial = false })
    g

(* The [Mismatch] message for a [Wrap^n Key]-typed global checked against
   [Wrap^(n + 1) Key]: BOTH payloads are printed types. *)
let d7d_mismatch_msg (g : Global.t) (n : int) : (string, string) result =
  let g = d7d_opaque (Printf.sprintf "d7dA%d" n) (d7d_nest_t n (Term.Global "Key")) g in
  let* expected_v =
    Eval.eval g [] (d7d_nest_t (n + 1) (Term.Global "Key")) |> Result.map_error Error.to_string
  in
  Check.check g Check.empty_ctx qw (Term.Global (Printf.sprintf "d7dA%d" n)) expected_v
  |> Result.fold
       ~ok:(fun _ -> Error (Printf.sprintf "D7d: Wrap^%d checked against Wrap^%d" n (n + 1)))
       ~error:(fun e ->
         if String.equal (Error.tag e) "Mismatch" then Ok (Error.to_string e)
         else Error ("D7d: wrong error: " ^ Error.to_string e))

let case_error_payloads_are_bounded (globals : Global.t) () : (unit, string) result =
  let* g = d_build_inst_cls_key globals |> Result.map_error Error.to_string in
  let* g = d_build_wrap g |> Result.map_error Error.to_string in
  let* small = d7d_mismatch_msg g 300 in
  let* large = d7d_mismatch_msg g 900 in
  let* short_msg = d7d_mismatch_msg g 1 in
  (* [Cls] has an instance for [Key] only, so a [Wrap] nest under it is
     Inst_unresolved on the ORDINARY path, with the whole query printed. *)
  let unres_goal (n : int) : Value.t = Value.VInd ("Cls", [ d7c_nest n (Value.VInd ("Wrap", [])) ]) in
  let unres (n : int) : (string, string) result =
    Check.check g Check.empty_ctx qw Term.Auto (unres_goal n)
    |> Result.fold
         ~ok:(fun _ -> Error (Printf.sprintf "D7d: a Wrap^%d query unexpectedly resolved" n))
         ~error:(fun e ->
           if String.equal (Error.tag e) "Inst_unresolved" then Ok (Error.to_string e)
           else Error ("D7d: wrong error: " ^ Error.to_string e))
  in
  let* u_small = unres 300 in
  let* u_large = unres 900 in
  Printf.printf "  D7d Mismatch %d/%d bytes at 300/900, Inst_unresolved %d/%d\n"
    (String.length small) (String.length large) (String.length u_small) (String.length u_large);
  match () with
  | () when not (Int.equal (String.length small) (String.length large)) ->
      Error
        (Printf.sprintf "D7d: Mismatch length tracks the input (%d at 300, %d at 900)"
           (String.length small) (String.length large))
  | () when not (contains_substring small "...") ->
      Error "D7d: an over-cap Mismatch payload was not marked elided"
  | () when not (Int.equal (String.length u_small) (String.length u_large)) ->
      Error
        (Printf.sprintf "D7d: Inst_unresolved length tracks the input (%d at 300, %d at 900)"
           (String.length u_small) (String.length u_large))
  | () when not (contains_substring u_small "...") ->
      Error "D7d: an over-cap Inst_unresolved payload was not marked elided"
  (* the short half: a small Mismatch still prints BOTH types in full,
     so the bound cannot be met by dropping the payload. *)
  (* M4 fixes round 5 (opus R5-6a): the cut lands on a CHARACTER
     boundary. [ascii] is exactly at the cap and keeps every byte;
     [straddle] puts the two-byte U+00E9 across it, so a raw byte cut
     would keep a lone 0xC3 (executed on the round-4 binary: a UTF-8
     decode of the stderr line fails at that byte) and the boundary cut
     drops it. Asserted on [Check.elide] directly, because the exact cut
     offset is the property, not the message that carries it. *)
  | () when
      not
        (String.equal
           (Check.elide (String.make Check.goal_print_cap 'x'))
           (String.make Check.goal_print_cap 'x')) ->
      Error "D7d: a string exactly at the cap was elided"
  | () when
      not
        (String.equal
           (Check.elide (String.make (Check.goal_print_cap - 1) 'x' ^ "\xc3\xa9\xc3\xa9"))
           (String.make (Check.goal_print_cap - 1) 'x' ^ "..."))
    ->
      Error "D7d: the cut did not back up to a UTF-8 character boundary"
  | () when contains_substring short_msg "..." ->
      Error ("D7d: a short Mismatch was elided: " ^ short_msg)
  | () when not (String.equal short_msg "type mismatch: expected (Wrap (Wrap Key)), found (Wrap Key)")
    ->
      Error ("D7d: short Mismatch text changed: " ^ short_msg)
  | () -> Ok ()

(* D9f: M4 fixes round 5 (ctxcat r5 id 16). The PER-KEY-COST dimension of
   [Check.inst_fuel]. Round 4 took the MAX of a depth-scaled term and a
   width-scaled term while the walk charges their PRODUCT, so the width
   term (8 * term_size, with no per-key factor) was calibrated for the
   shipped two-type-binder two-dictionary-binder instance alone.

   ctxcat 16's construction exactly: three classes and an EIGHT-binder
   instance per class ([(0 A) (0 B) -> C A -> C B -> D A -> D B ->
   E A -> E B -> C (WPair A B)], which [validate_instance_shape]
   accepts), against a balanced [D9fWPair] tree over 256 pairwise
   distinct leaf types. Each internal key charges 2 for the type
   binders plus 12 for the six dictionary binders, and there are three
   classes over 255 internal nodes, so the walk charges about
   42 (L - 1) = 10710 while the round-4 bound sat at its flat 10000
   floor (its width term, 8 * term_size = 8184 here, carried no per-key
   factor, and its depth term is 16 * 9 * 18 = 2592). A finite, well
   formed, resolvable query therefore reported Inst_depth, which is
   exactly what this number's own contract forbids. Executed as a
   DIFFERENTIAL: with [inst_fuel] reverted to the round-4 MAX this case
   FAILS.

   Sized deliberately. The charge must clear 10000 with THIS instance
   shape, which fixes L at 240 or more, and [Eval.eval] re-walks each
   resolved dictionary once per occurrence (six per level, two
   distinct), so the cost is 6^depth and L must stay at 256 or below to
   keep the depth at 8. 256 is the only value that satisfies both, so
   the margin over the round-4 bound is 7 percent: a hard boolean for a
   fixed formula, but a number to re-measure if the charge accounting
   in [build_instance] ever changes.

   Kernel-level on purpose. The same shape as a surface fixture also
   pays the mandatory candidate re-check, which walks the resolved
   dictionary as a TREE ([Term.t] has no sharing): measured, 15 to 20s
   for L = 256 and 47s for L = 320, an M5 hash-consing debt that has
   nothing to do with the fuel bound under test here. *)
let d9f_leaves : int = 256
let d9f_classes : string list = [ "D9fPA"; "D9fPB"; "D9fPC" ]

let rec d9f_tree (lo : int) (hi : int) : Value.t =
  match () with
  | () when hi - lo <= 1 -> Value.VInd (Printf.sprintf "D9fW%d" lo, [])
  | () ->
      let mid = (lo + hi) / 2 in
      Value.VInd ("D9fWPair", [ d9f_tree lo mid; d9f_tree mid hi ])

(* [(0 A : Type 0) -> (0 B : Type 0) -> D9fPA A -> D9fPA B -> D9fPB A ->
   D9fPB B -> D9fPC A -> D9fPC B -> C (D9fWPair A B)]. Under [k] dictionary
   binders the type binder [A] is de Bruijn [k + 1] and [B] is [k]. *)
let d9f_pair_ty (c : string) : Term.t =
  let doms = List.concat_map (fun cls -> [ (cls, 1); (cls, 0) ]) d9f_classes in
  let n = List.length doms in
  let cod =
    Term.App
      ( qw,
        Term.Global c,
        Term.App (qw, Term.App (qw, Term.Global "D9fWPair", Term.Var (n + 1)), Term.Var n) )
  in
  let wrap, _k =
    List.fold_left
      (fun ((acc : Term.t -> Term.t), (k : int)) ((cls : string), (which : int)) ->
        ( (fun inner ->
            acc (Term.Pi (qw, "_", Term.App (qw, Term.Global cls, Term.Var (which + k)), inner))),
          k + 1 ))
      ((fun inner -> inner), 0) doms
  in
  Term.Pi (q0, "A", ty0, Term.Pi (q0, "B", ty0, wrap cod))

let d9f_build (g : Global.t) : (Global.t, Error.t) result =
  let* g =
    List.fold_left
      (fun acc c ->
        let* g = acc in
        Check.declare_ind g ~name:c ~params:[ (q0, "A", ty0) ] ~indices:[] ~level:Level.zero)
      (Ok g) d9f_classes
  in
  let* g =
    Check.declare_ind g ~name:"D9fWPair"
      ~params:[ (q0, "A", ty0); (q0, "B", ty0) ]
      ~indices:[] ~level:Level.zero
  in
  let* g =
    List.fold_left
      (fun acc i ->
        let* g = acc in
        Check.declare_ind g ~name:(Printf.sprintf "D9fW%d" i) ~params:[] ~indices:[]
          ~level:Level.zero)
      (Ok g)
      (List.init d9f_leaves Fun.id)
  in
  let leaf_insts =
    List.concat_map
      (fun c -> List.init d9f_leaves (fun i -> (c, Printf.sprintf "D9fW%d" i)))
      d9f_classes
  in
  let g =
    List.fold_left
      (fun g (c, w) ->
        d7d_opaque ("inst$" ^ c ^ "$" ^ w) (Term.App (qw, Term.Global c, Term.Global w)) g)
      g leaf_insts
  in
  Ok
    (List.fold_left
       (fun g c -> d7d_opaque ("inst$" ^ c ^ "$D9fWPair") (d9f_pair_ty c) g)
       g d9f_classes)

let case_wide_query_with_wide_instance_resolves (globals : Global.t) () : (unit, string) result =
  let* g = d9f_build globals |> Result.map_error Error.to_string in
  let goal = Value.VInd ("D9fPA", [ d9f_tree 0 d9f_leaves ]) in
  let* goal_t = Eval.quote g 0 goal |> Result.map_error Error.to_string in
  let fuel = Check.inst_fuel g goal_t in
  Printf.printf "  D9f term_size=%d fuel=%d\n" (Check.term_size goal_t) fuel;
  Check.check g Check.empty_ctx qw Term.Auto goal
  |> Result.fold
       ~ok:(fun _tm -> Ok ())
       ~error:(fun e ->
         Error
           (Printf.sprintf "D9f: an 8-binder instance over %d leaves did not resolve (fuel %d): %s"
              d9f_leaves fuel (Error.to_string e)))

let cases (globals : Global.t) : (string * (unit -> (unit, string) result)) list =
  [
    ( "beta reduction",
      expect_conv globals "beta" ~want:true
        (Term.App (qw, Term.Lam (qw, "x", Term.Var 0), ty0))
        ty0 );
    ( "cadd two two = four",
      expect_conv globals "cadd" ~want:true
        (Term.App (qw, Term.App (qw, Term.Global "cadd", Term.Global "ctwo"), Term.Global "ctwo"))
        (Term.Global "cfour") );
    ( "cadd two two <> two",
      expect_conv globals "cadd-neg" ~want:false
        (Term.App (qw, Term.App (qw, Term.Global "cadd", Term.Global "ctwo"), Term.Global "ctwo"))
        (Term.Global "ctwo") );
    ( "eta: fun y => g y = g",
      expect_conv globals "eta" ~want:true
        (Term.Lam (qw, "y", Term.App (qw, Term.Global "g_fun", Term.Var 0)))
        (Term.Global "g_fun") );
    ( "opaque global stays opaque",
      expect_conv globals "opaque" ~want:false (Term.Global "czero_opaque") czero_def );
    ( "reducible global unfolds",
      expect_conv globals "reducible" ~want:true (Term.Global "czero") czero_def );
    ( "pi quantity is part of equality",
      expect_conv globals "pi-quantity" ~want:false cnat_def cnat_variant_many );
    ( "let evaluates",
      expect_conv globals "let" ~want:true
        (Term.Let
           ( "n",
             cnat,
             church 2,
             Term.App (qw, Term.App (qw, Term.Global "cadd", Term.Var 0), Term.Var 0) ))
        (Term.Global "cfour") );
    ( "let typechecks",
      expect_infer_ok globals "let-infer"
        (Term.Let
           ( "n",
             cnat,
             church 2,
             Term.App (qw, Term.App (qw, Term.Global "cadd", Term.Var 0), Term.Var 0) )) );
    ("type-in-type rejected", expect_infer_err globals "type-in-type" "Mismatch" (Term.Ann (ty0, ty0)));
    ("erased use rejected", expect_infer_err globals "erased-use" "Erased_use" erased_use_bad);
    ("runtime type binder allowed", expect_infer_ok globals "runtime-binder" erased_use_good);
    ("unbound var reported", expect_infer_err globals "unbound" "Unbound_var" (Term.Var 0));
    ( "app of non-function rejected",
      expect_infer_err globals "not-a-function" "Not_a_function" (Term.App (qw, ty0, ty0)) );
    ( "bare lambda needs annotation",
      expect_infer_err globals "bare-lambda" "Cannot_infer" (Term.Lam (qw, "x", Term.Var 0)) );
    ("dependent application result type", case_id_result_type globals);
    ("duplicate global rejected", case_duplicate globals);
    ("quote and print round-trip", case_quote_pp globals);
    ("match eval on canonical scrutinees", case_match_eval globals);
    ("dependent motive per constructor", case_dependent_motive globals);
    ("branch order, count, arity pinned", case_branch_shape globals);
    ( "match on a non-inductive",
      expect_infer_err globals "not-inductive" "Not_inductive"
        (Term.Match { scrut = ty0; scrut_q = qw; motive = Some (m2_motive "_m" nat); branches = [] }) );
    ("positivity rejected", case_positivity globals);
    ("ctor universe bound rejected", case_universe globals);
    ( "rec global unfolds on canonical arg",
      expect_conv globals "rec-unfold" ~want:true
        (Term.App (qw, Term.App (qw, Term.Global "add", nsucc nzero), nsucc nzero))
        (nsucc (nsucc nzero)) );
    ("guarded rec stays stuck", case_guarded_stuck globals);
    ("termination guard rejects loop", case_termination globals);
    ("stuck match conversion", case_stuck_match_conv globals);
    ("F2: mid-declaration elimination is Ind_incomplete", case_ind_incomplete globals);
    ("F2: second define_ind is Ind_redefined", case_ind_redefined globals);
    ("S3: params-length mismatch outranks Ind_incomplete", case_match_scrut_precedence globals);
    ("F4: partially applied ctor is not canonical", case_partial_ctor_not_canonical globals);
    ("F4: fully applied ctor still unfolds", case_full_ctor_unfolds globals);
    ("F5: run_match arity backstop", case_run_match_arity_backstop globals);
    ("F6: motive-free and explicit-motive matches convert equal", case_uniform_motive globals);
    ( "T0: rec def guarded on an erased formal has no self-reference after erasure",
      case_erased_guard_no_self_ref globals );
    ("A1: literal Term.Lit infers its declared builtin type", case_lit_infer_string);
    ("A2: literal infer is Unbound_global without String declared", case_lit_infer_unbound globals);
    ("A3: VLit conv is structural equality, not cross-kind", case_lit_conv globals);
    ("A4: two prim spines of equal arity are opaque under conv", case_prim_opacity);
    ( "A5: Eval.eval backstop on a VLit match scrutinee is Not_inductive",
      case_lit_match_backstop globals );
    ("A6: literal round-trips check/erase/exec/quote/pp with escapes", case_lit_roundtrip);
    ("A7: Check.define_prim rejects a duplicate name", case_define_prim_duplicate);
    ( "A8: Prim.catalog is duplicate-free, round-trips, and is justified",
      case_prim_catalog_integrity );
    ( "B1: every catalog prim's Prim.arity matches its declared type's kept-binder count",
      case_prim_arity_agreement );
    ( "B2: Check.define refuses reducible on a Div-headed def; plain and fn-typed accepted",
      case_effect_def_reducible );
    ("B3: Interp.quote on a VIOAction is Not_quotable", case_ioaction_not_quotable);
    ( "B4: add_prim on readStdin (arity 0) stores a fired VIOAction, not a VPrim",
      case_add_prim_arity0_ioaction );
    ( "B5: regex_group_count agrees with the Str dialect on classes and escaped backslashes",
      case_regex_group_count );
    ( "C1: Check.define ~partial:true ~reducible:true is Partial_reducible_conflict",
      case_partial_reducible_conflict );
    ("C2: partial on a non-Div-headed codomain is Partial_not_div", case_partial_not_div);
    ( "C3: def rec failing the guard is Termination without partial, ACCEPTED with it",
      case_partial_guard_skip );
    ( "C4: Json-shaped self-recursive ctors pass positivity; List T -> T nesting is Bad_ctor",
      case_json_positivity_kernel );
    ("A1: an indexed family declares, defines, and reports its arity", case_indexed_family_arity globals);
    ("A2: an index binder marked w is Index_not_zero", case_index_not_zero globals);
    ("A3: an index type above the declared universe is Index_above_universe", case_index_above_universe globals);
    ("A4: a constructor with the wrong index count is Bad_ctor", case_bad_ctor_wrong_index_count globals);
    ("A5: the Fording route stays blocked (result head, then positivity)", case_fording_blocked globals);
    ("A6: index_expr_clean rejects an index expression mentioning its own family", case_index_expr_clean_unit);
    ("A6b: index_expr_clean rejects auto in an index position (bare and nested)", case_index_expr_clean_rejects_auto);
    ("A6c: strip_ann collapses head annotations and touches nothing else", case_strip_ann_head);
    ("A7: the subsingleton criterion, all four shapes", case_zero_eliminable_shapes globals);
    ("A8: subst-shaped erasure is the identity", case_subst_shaped_erasure_identity globals);
    ("A9: a zero-branch subsingleton match erases to the erased residue", case_zero_branch_erasure_residue globals);
    ("A10: additivity, a materialized constant motive still converts (motive record)", case_uniform_motive globals);
    ("A11: Term.Auto is rejected by every kernel pass", case_auto_rejected_everywhere globals);
    ("A12: a builtin type former reports Builtin_not_eliminable, split from Ind_incomplete", case_builtin_vs_provisional globals);
    ("B1: define_axiom installs an opaque global", case_define_axiom_opaque globals);
    ("B2: an axiom at mode w is Axiom_runtime_use, mode 0 succeeds", case_axiom_runtime_use globals);
    ("B3: define_axiom rejects a duplicate name", case_axiom_duplicate globals);
    ("B4: an axiom is not a def, an ind, a ctor, or a prim", case_axiom_not_other_kinds globals);
    ("C1: Eterm.mentions is exhaustive and correct", case_eterm_mentions_exhaustive);
    ("C3: a Frozen global stays neutral under application", case_frozen_stays_neutral);
    ("D1: Auto resolves from the expected type", case_auto_resolves_from_expected globals);
    ( "D2: Auto against a non-class expected type is Inst_unresolved",
      case_auto_non_class_unresolved globals );
    ( "D3: Auto against a class applied to a variable is Inst_unresolved",
      case_auto_class_var_unresolved globals );
    ("D4: a missing instance is Inst_unresolved", case_auto_missing_instance_unresolved globals);
    ( "D5: a duplicate instance key is Duplicate_global",
      case_duplicate_instance_is_duplicate_global globals );
    ( "D6: a ground instance at an applied key is Inst_bad_shape",
      case_ground_applied_key_is_bad_shape globals );
    ("D7: instance resolution is fuel bounded", case_instance_resolution_fuel_bounded globals);
    ( "D7b: Inst_depth names the query, not the peeled Pi",
      case_inst_depth_names_the_query globals );
    ( "D7c: Inst_depth's message is bounded, whatever the query's size",
      case_inst_depth_message_is_bounded globals );
    ( "A13: the motive's two index binders keep declaration order",
      case_motive_index_binder_order globals );
    ( "D7d: every printed-type error payload is bounded, not just Inst_depth",
      case_error_payloads_are_bounded globals );
    ( "D9f: a wide query against an 8-binder instance resolves",
      case_wide_query_with_wide_instance_resolves globals );
    ("D8: checker output never contains Auto", case_checker_output_never_contains_auto globals);
  ]

let () =
  build_globals ()
  |> Result.fold
       ~error:(fun e ->
         print_endline ("global setup failed: " ^ Error.to_string e);
         Stdlib.exit 1)
       ~ok:(fun globals ->
         let failures =
           List.fold_left
             (fun acc (name, run) ->
               run ()
               |> Result.fold
                    ~ok:(fun () ->
                      Printf.printf "PASS %s\n" name;
                      acc)
                    ~error:(fun msg ->
                      Printf.printf "FAIL %s\n  %s\n" name msg;
                      acc + 1))
             0 (cases globals)
         in
         (match () with
         | () when Int.equal failures 0 -> print_endline "M0 kernel: all tests green"
         | () -> Printf.printf "%d test(s) failed\n" failures);
         Stdlib.exit (Int.min failures 1))
