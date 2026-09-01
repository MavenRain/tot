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

(* M2 data-declaration fixtures *)
let bool_data : string = "data Bool : Type 0 := | true : Bool | false : Bool"

let bool_lines : string list =
  [ "data Bool : Type 0"; "ctor true : Bool"; "ctor false : Bool" ]

let nat_data : string = "data Nat : Type 0 := | zero : Nat | succ : Nat -> Nat"

let nat_lines : string list =
  [ "data Nat : Type 0"; "ctor zero : Nat"; "ctor succ : (w _ : Nat) -> Nat" ]

let not_def : string =
  "def not : Bool -> Bool := fun b => match b with | true => false | false => true end"

let with_lines (items : string list) : string = String.concat "\n" items

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
    ( "lex numeric literal cap",
      expect_err "def x : Type 0 := Type 1234567890123456789" "Lex" );
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
    (* Stage C: data / match / def rec *)
    ( "data Bool, match in a def, ctor eval",
      expect_lines
        (with_lines [ bool_data; not_def; "eval not true" ])
        (bool_lines @ [ "def not : (w _ : Bool) -> Bool"; "false" ]) );
    ( "def rec add computes on Nat",
      expect_lines
        (with_lines
           [
             nat_data;
             "def rec add : Nat -> Nat -> Nat := fun m n => match m with | zero => n \
              | succ p => succ (add p n) end";
             "eval add (succ zero) (succ (succ zero))";
           ])
        (nat_lines
        @ [
            "def add : (w _ : Nat) -> (w _ : Nat) -> Nat"; "(succ (succ (succ zero)))";
          ]) );
    ( "parameters erase from runtime ctor values",
      expect_lines
        (with_lines
           [
             nat_data;
             "data Box (0 A : Type 0) : Type 0 := | box : A -> Box A";
             "def unbox : (0 A : Type 0) -> Box A -> A := fun A b => match b with \
              | box x => x end";
             "eval unbox Nat (box Nat (succ zero))";
           ])
        (nat_lines
        @ [
            "data Box : (0 A : Type 0) -> Type 0";
            "ctor box : (0 A : Type 0) -> (w _ : A) -> (Box A)";
            "def unbox : (0 A : Type 0) -> (w _ : (Box A)) -> A";
            "(succ zero)";
          ]) );
    ( "match with as/return in infer position",
      expect_lines
        (with_lines
           [
             nat_data;
             "eval (match zero as n return Nat with | zero => zero | succ p => p end)";
           ])
        (nat_lines @ [ "zero" ]) );
    ( "check mode prints data, ctor, and eval-type lines",
      expect_lines_check
        (with_lines [ bool_data; "data Void : Type 0 :="; not_def; "eval not true" ])
        (bool_lines
        @ [ "data Void : Type 0"; "def not : (w _ : Bool) -> Bool"; "eval : Bool" ]) );
    ( "missing branch is a branch mismatch",
      expect_err
        (with_lines
           [ bool_data; "def bad : Bool -> Bool := fun b => match b with | true => false end" ])
        "Kernel.Branch_mismatch" );
    ( "branches out of declaration order are a branch mismatch",
      expect_err
        (with_lines
           [
             bool_data;
             "def bad : Bool -> Bool := fun b => match b with | false => true \
              | true => false end";
           ])
        "Kernel.Branch_mismatch" );
    ( "unknown ctor name in a pattern is a branch mismatch",
      expect_err
        (with_lines
           [ bool_data; "def bad : Bool -> Bool := fun b => match b with | maybe => true end" ])
        "Kernel.Branch_mismatch" );
    ( "negative ctor occurrence is rejected",
      expect_err "data Bad : Type 0 := | mk : (Bad -> Bad) -> Bad" "Kernel.Bad_ctor" );
    ( "non-structural def rec is rejected",
      expect_err
        (with_lines [ nat_data; "def rec loop : Nat -> Nat := fun n => loop n" ])
        "Kernel.Termination" );
    ( "match on a function is not inductive",
      expect_err
        (with_lines
           [
             nat_data;
             "def f : Nat -> Nat := fun n => n";
             "eval match f as x return Nat with | zero => zero | succ p => p end";
           ])
        "Kernel.Not_inductive" );
    ( "data parameter without the 0 marker",
      expect_err "data Box (A : Type 0) : Type 0 := | box : A -> Box A" "Parse" );
    ( "data parameter with a w marker",
      expect_err "data Box (w A : Type 0) : Type 0 := | box : A -> Box A" "Parse" );
    ( "infer-position match without as/return",
      expect_err
        (with_lines [ nat_data; "eval match zero with | zero => zero | succ p => p end" ])
        "Kernel.Cannot_infer" );
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
