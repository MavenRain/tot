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
              motive = Some ("_m", nat);
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
  let* g = Check.declare_ind g ~name:"Nat" ~params:[] ~level:Level.zero in
  let* g =
    Check.define_ind g ~name:"Nat"
      ~ctors:[ ("zero", nat); ("succ", Term.Pi (qw, "n", nat, nat)) ]
  in
  let* g = Check.declare_ind g ~name:"Opt" ~params:[ (q0, "A", ty0) ] ~level:Level.zero in
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
      motive = Some ("_m", nat);
      branches = [ ("zero", [], nzero); ("succ", [ (qw, "n") ], Term.Var 0) ];
    }

(* match some Nat (succ zero) with .. | some x => x end  ==>  succ zero;
   pins that the erased param value is dropped before branch entry *)
let match_opt_payload : Term.t =
  Term.Match
    {
      scrut = Term.App (qw, Term.App (qw, Term.Global "some", nat), nsucc nzero);
      motive = Some ("_o", nat);
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
      motive =
        Some
          ( "n",
            Term.Match
              {
                scrut = Term.Var 0;
                motive = Some ("_", ty0);
                branches = [ ("zero", [], nat); ("succ", [ (qw, "p") ], opt_nat) ];
              } );
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
  Term.Match { scrut = nzero; motive = Some ("_m", nat); branches }

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
    let* g = Check.declare_ind globals ~name:"BadPos" ~params:[] ~level:Level.zero in
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
    let* g = Check.declare_ind globals ~name:"BadUniv" ~params:[] ~level:Level.zero in
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
      motive = Some ("_m", nat);
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
    let* g = Check.declare_ind globals ~name:"Pin" ~params:[] ~level:Level.zero in
    Check.define_ind g ~name:"Pin"
      ~ctors:
        [
          ("pa", Term.Global "Pin");
          ( "pb",
            Term.Pi
              ( qw,
                "_",
                Term.Match
                  { scrut = Term.Global "pa"; motive = Some ("_", ty0); branches = [] },
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
    let* g = Check.declare_ind globals ~name:"Bit" ~params:[] ~level:Level.zero in
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
      Check.declare_ind globals ~name:"Pin3" ~params:[ (q0, "A", ty0) ] ~level:Level.zero
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
         { scrut = Term.Global "bad_scrut"; motive = Some ("_", ty0); branches = [] })
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
      motive = Some ("_m", nat);
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
      motive = None;
      branches = [ ("true", [], Term.Global "false"); ("false", [], Term.Global "true") ];
    }

let not_body_explicit_motive : Term.t =
  Term.Match
    {
      scrut = Term.Var 0;
      motive = Some ("x", bool_ty);
      branches = [ ("true", [], Term.Global "false"); ("false", [], Term.Global "true") ];
    }

let not_ty : Term.t = Term.Pi (qw, "b", bool_ty, bool_ty)

let case_uniform_motive (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* g = Check.declare_ind globals ~name:"Bool" ~params:[] ~level:Level.zero in
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

(* Total, exhaustive walk over every [Eterm.t] arm: does [name] occur
   anywhere in [e]? *)
let rec eterm_mentions (name : string) (e : Eterm.t) : bool =
  match e with
  | Eterm.EVar _ -> false
  | Eterm.ELam (_x, body) -> eterm_mentions name body
  | Eterm.EApp (f, a) -> eterm_mentions name f || eterm_mentions name a
  | Eterm.ELet (_x, def, body) -> eterm_mentions name def || eterm_mentions name body
  | Eterm.EGlobal g -> String.equal g name
  | Eterm.ELit _ -> false
  | Eterm.EErased -> false
  | Eterm.EMatch (scrut, branches) ->
      eterm_mentions name scrut
      || List.exists (fun (_c, _binders, body) -> eterm_mentions name body) branches

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
         if eterm_mentions "ghost" erased then
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
  Check.declare_ind Global.empty ~name:"String" ~params:[] ~level:Level.zero

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
    (Term.Match { scrut = Term.Lit (Literal.LString "x"); motive = Some ("_", ty0); branches = [] })
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
           let* g1 = Check.declare_ind g ~name:"JsonK" ~params:[] ~level:Level.zero in
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
                  let* g2 = Check.declare_ind g ~name:"JsonBadK" ~params:[] ~level:Level.zero in
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
        (Term.Match { scrut = ty0; motive = Some ("_m", nat); branches = [] }) );
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
