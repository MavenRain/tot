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
