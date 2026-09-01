(** M1 surface tests, end to end through Run.script. Positives pin the
    EXACT full output-line list; negatives pin the EXACT error tag, so a
    vacuous pass is impossible. *)

let show_lines (lines : string list) : string = String.concat " | " lines

let expect_with ~(exec : bool) (src : string) (want : string list) () :
    (unit, string) result =
  Tot_surface.Run.script ~exec src
  |> Result.fold
       ~ok:(fun got ->
         if List.equal String.equal got want then Ok ()
         else
           Error
             (Printf.sprintf "got  [%s]\n  want [%s]" (show_lines got) (show_lines want)))
       ~error:(fun e -> Error ("error: " ^ Tot_surface.Serror.to_string e))

let expect_lines (src : string) (want : string list) () : (unit, string) result =
  expect_with ~exec:true src want ()

let expect_lines_check (src : string) (want : string list) () : (unit, string) result =
  expect_with ~exec:false src want ()

let expect_err (src : string) (want_tag : string) () : (unit, string) result =
  Tot_surface.Run.script ~exec:true src
  |> Result.fold
       ~ok:(fun lines ->
         Error
           (Printf.sprintf "expected %s, but the script ran: [%s]" want_tag
              (show_lines lines)))
       ~error:(fun e ->
         let tag = Tot_surface.Serror.tag e in
         if String.equal tag want_tag then Ok ()
         else
           Error
             (Printf.sprintf "expected %s, got %s (%s)" want_tag tag
                (Tot_surface.Serror.to_string e)))

let prelude : string =
  String.concat "\n"
    [
      "reducible def cnat : Type 1 := (0 a : Type 0) -> (a -> a) -> a -> a";
      "reducible def czero : cnat := fun a f z => z";
      "reducible def csucc : cnat -> cnat := fun n a f z => f (n a f z)";
      "reducible def cadd : cnat -> cnat -> cnat := fun m n a f z => m a f (n a f z)";
    ]

let prelude_lines : string list =
  [
    "def cnat : Type 1";
    "def czero : cnat";
    "def csucc : (w _ : cnat) -> cnat";
    "def cadd : (w _ : cnat) -> (w _ : cnat) -> cnat";
  ]

let church4 : string = "fun f => fun z => (f (f (f (f z))))"
let church0 : string = "fun f => fun z => z"
let with_prelude (rest : string list) : string = String.concat "\n" (prelude :: rest)

let cases : (string * (unit -> (unit, string) result)) list =
  [
    ( "cadd two two runs to church four",
      expect_lines
        (with_prelude [ "def two : cnat := csucc (csucc czero)"; "eval cadd two two" ])
        (prelude_lines @ [ "def two : cnat"; church4 ]) );
    ( "erased id: check prints, eval drops the type argument",
      expect_lines
        (with_prelude
           [
             "def id : (0 A : Type 1) -> A -> A := fun A x => x";
             "check id";
             "eval id cnat czero";
           ])
        (prelude_lines
        @ [
            "def id : (0 A : Type 1) -> (w _ : A) -> A";
            "id : (0 A : Type 1) -> (w _ : A) -> A";
            church0;
          ]) );
    ( "let-bound definition runs",
      expect_lines
        (with_prelude
           [
             "def four : cnat := let t : cnat := csucc (csucc czero) in cadd t t";
             "eval four";
           ])
        (prelude_lines @ [ "def four : cnat"; church4 ]) );
    ( "multi-name erased binder group",
      expect_lines
        (with_prelude
           [
             "def k : (0 A B : Type 1) -> A -> B -> A := fun A B x y => x";
             "eval k cnat cnat czero (csucc czero)";
           ])
        (prelude_lines
        @ [ "def k : (0 A : Type 1) -> (0 B : Type 1) -> (w _ : A) -> (w _ : B) -> A"; church0 ])
    );
    ( "binder named w; runtime type argument is inert",
      expect_lines
        (with_prelude
           [ "def wbind : (w : Type 1) -> Type 1 := fun x => x"; "eval wbind cnat" ])
        (prelude_lines @ [ "def wbind : (w w : Type 1) -> Type 1"; "<erased>" ]) );
    ( "explicit (w x :) quantity marker",
      expect_lines
        (with_prelude
           [ "def wid : (w x : cnat) -> cnat := fun x => x"; "eval wid czero" ])
        (prelude_lines @ [ "def wid : (w x : cnat) -> cnat"; church0 ]) );
    ( "annotation atom",
      expect_lines
        (with_prelude [ "eval (czero : cnat)" ])
        (prelude_lines @ [ church0 ]) );
    ( "check mode prints the eval type",
      expect_lines_check
        (with_prelude [ "eval cadd czero czero" ])
        (prelude_lines
        @ [ "eval : (0 a : Type 0) -> (w _ : (w _ : a) -> a) -> (w _ : a) -> a" ]) );
    ("lex error", expect_err "def @" "Lex");
    ("parse error", expect_err "def x cnat" "Parse");
    ("unknown name", expect_err "eval nope" "Unknown_name");
    ( "erased use is a kernel error",
      expect_err
        (with_prelude
           [ "def bad : (0 A : Type 1) -> A -> Type 1 := fun A x => A" ])
        "Kernel.Erased_use" );
    ( "duplicate def is a kernel error",
      expect_err "def x : Type 1 := Type 0\ndef x : Type 1 := Type 0"
        "Kernel.Duplicate_global" );
    ( "no cumulativity",
      expect_err "def m : Type 0 := Type 0" "Kernel.Mismatch" );
    ( "bare lambda cannot be inferred",
      expect_err "eval fun x => x" "Kernel.Cannot_infer" );
  ]

let () =
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
      0 cases
  in
  (match () with
  | () when Int.equal failures 0 -> print_endline "M1 surface: all tests green"
  | () -> Printf.printf "%d test(s) failed\n" failures);
  Stdlib.exit (Int.min failures 1)
