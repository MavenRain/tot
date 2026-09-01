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

let czero_def : Term.t = Term.Lam ("a", Term.Lam ("f", Term.Lam ("z", Term.Var 0)))

(* fun n a f z => f (n a f z) *)
let csucc_def : Term.t =
  Term.Lam
    ( "n",
      Term.Lam
        ( "a",
          Term.Lam
            ( "f",
              Term.Lam
                ( "z",
                  Term.App
                    ( Term.Var 1,
                      Term.App
                        (Term.App (Term.App (Term.Var 3, Term.Var 2), Term.Var 1), Term.Var 0)
                    ) ) ) ) )

let csucc_ty : Term.t = Term.Pi (qw, "n", cnat, cnat)

(* fun m n a f z => m a f (n a f z) *)
let cadd_def : Term.t =
  Term.Lam
    ( "m",
      Term.Lam
        ( "n",
          Term.Lam
            ( "a",
              Term.Lam
                ( "f",
                  Term.Lam
                    ( "z",
                      Term.App
                        ( Term.App (Term.App (Term.Var 4, Term.Var 2), Term.Var 1),
                          Term.App
                            ( Term.App (Term.App (Term.Var 3, Term.Var 2), Term.Var 1),
                              Term.Var 0 ) ) ) ) ) ) )

let cadd_ty : Term.t = Term.Pi (qw, "m", cnat, Term.Pi (qw, "n", cnat, cnat))

let church (n : int) : Term.t =
  List.init n (fun _i -> ())
  |> List.fold_left (fun acc () -> Term.App (Term.Global "csucc", acc)) (Term.Global "czero")

let idt_ty : Term.t = Term.Pi (q0, "a", ty1, Term.Pi (qw, "x", Term.Var 0, Term.Var 1))
let idt_def : Term.t = Term.Lam ("a", Term.Lam ("x", Term.Var 0))

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
      ~def:(Term.Lam ("x", Term.Var 0))
  in
  Check.define g ~name:"idT" ~reducible:false ~ty:idt_ty ~def:idt_def

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
       ~ok:(fun _ty -> Ok ())
       ~error:(fun e -> Error (label ^ ": " ^ Error.to_string e))

let expect_infer_err (globals : Global.t) (label : string) (want_tag : string)
    (tm : Term.t) () : (unit, string) result =
  Check.infer globals Check.empty_ctx Quantity.Many tm
  |> Result.fold
       ~ok:(fun _ty -> Error (label ^ ": expected " ^ want_tag ^ ", but it typechecked"))
       ~error:(fun e ->
         if String.equal (Error.tag e) want_tag then Ok ()
         else Error (Printf.sprintf "%s: expected %s, got %s" label want_tag (Error.to_string e)))

let case_id_result_type (globals : Global.t) () : (unit, string) result =
  let attempt =
    let* ty =
      Check.infer globals Check.empty_ctx Quantity.Many
        (Term.App (Term.App (Term.Global "idT", cnat), Term.Global "czero"))
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

let erased_use_bad : Term.t =
  Term.Ann
    ( Term.Lam ("a", Term.Lam ("x", Term.Var 1)),
      Term.Pi (q0, "a", ty0, Term.Pi (qw, "x", Term.Var 0, ty0)) )

let erased_use_good : Term.t =
  Term.Ann
    ( Term.Lam ("a", Term.Lam ("x", Term.Var 1)),
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
        (Term.App (Term.Lam ("x", Term.Var 0), ty0))
        ty0 );
    ( "cadd two two = four",
      expect_conv globals "cadd" ~want:true
        (Term.App (Term.App (Term.Global "cadd", Term.Global "ctwo"), Term.Global "ctwo"))
        (Term.Global "cfour") );
    ( "cadd two two <> two",
      expect_conv globals "cadd-neg" ~want:false
        (Term.App (Term.App (Term.Global "cadd", Term.Global "ctwo"), Term.Global "ctwo"))
        (Term.Global "ctwo") );
    ( "eta: fun y => g y = g",
      expect_conv globals "eta" ~want:true
        (Term.Lam ("y", Term.App (Term.Global "g_fun", Term.Var 0)))
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
             Term.App (Term.App (Term.Global "cadd", Term.Var 0), Term.Var 0) ))
        (Term.Global "cfour") );
    ( "let typechecks",
      expect_infer_ok globals "let-infer"
        (Term.Let
           ( "n",
             cnat,
             church 2,
             Term.App (Term.App (Term.Global "cadd", Term.Var 0), Term.Var 0) )) );
    ("type-in-type rejected", expect_infer_err globals "type-in-type" "Mismatch" (Term.Ann (ty0, ty0)));
    ("erased use rejected", expect_infer_err globals "erased-use" "Erased_use" erased_use_bad);
    ("runtime type binder allowed", expect_infer_ok globals "runtime-binder" erased_use_good);
    ("unbound var reported", expect_infer_err globals "unbound" "Unbound_var" (Term.Var 0));
    ( "app of non-function rejected",
      expect_infer_err globals "not-a-function" "Not_a_function" (Term.App (ty0, ty0)) );
    ( "bare lambda needs annotation",
      expect_infer_err globals "bare-lambda" "Cannot_infer" (Term.Lam ("x", Term.Var 0)) );
    ("dependent application result type", case_id_result_type globals);
    ("duplicate global rejected", case_duplicate globals);
    ("quote and print round-trip", case_quote_pp globals);
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
