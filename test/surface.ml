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

(* like [expect_err], but prints the actual error text on a PASS too, so
   a rejection is shown to fire for the intended reason and not just an
   accidental tag match *)
let expect_err_printed (src : string) (want_tag : string) () : (unit, string) result =
  Tot_surface.Run.script ~exec:true src
  |> Result.fold
       ~ok:(fun lines ->
         Error
           (Printf.sprintf "expected %s, but the script ran: [%s]" want_tag
              (show_lines lines)))
       ~error:(fun e ->
         let tag = Tot_surface.Serror.tag e in
         Printf.printf "  expected error (%s): %s\n" want_tag (Tot_surface.Serror.to_string e);
         if String.equal tag want_tag then Ok ()
         else
           Error
             (Printf.sprintf "expected %s, got %s (%s)" want_tag tag
                (Tot_surface.Serror.to_string e)))

(* dune build-time tripwire (S1 fix, M2-fixes Round 3; see test/dune):
   referencing this forces dune to rebuild ../bin/tot.exe before
   test/surface.exe can even compile, so a stale CLI binary from a prior
   build can never be exercised by [expect_cli_run_lines] below. *)
let () = Tot_exe_dep.tot_built

(* This test binary's own installed location, e.g.
   <root>/_build/default/test/surface.exe: [Sys.executable_name] always
   resolves to the real absolute path of the running executable (unlike
   [Sys.argv.(0)] or the process cwd), so peeling directory components
   off it lands on known sibling locations regardless of how this binary
   was invoked (`dune exec`, a direct path, a different cwd, ...). Both
   the built CLI's path and the source-tree fixture path (S1 fix:
   neither was previously RELATIVE to anything, both were
   machine-absolute literals) are derived from here. *)
let build_default : string = Sys.executable_name |> Filename.dirname |> Filename.dirname
(* build_default = <root>/_build/default *)

let tot_exe : string = Filename.concat build_default "bin/tot.exe"
let repo_root : string = build_default |> Filename.dirname |> Filename.dirname
(* strip "_build/default" back off to reach <root> *)

let f1_witness_fixture : string = Filename.concat repo_root "test/fixtures/f1-witness.tot"

(* M2-fixes batch (Round 3 S0, reworked Round 5 review T0): the same
   "shell out under a watchdog" discipline as F1's bare-eval case, for
   the same reason (this exercises [remap_rec_arg]'s ERASED-formal
   branch, a place a regression could in principle hang rather than fail
   fast, even though that branch is eager-unfold as of Round 4). *)
let s0_erased_guard_fixture : string =
  Filename.concat repo_root "test/fixtures/s0-erased-guard.tot"

(* S2 fix (M2-fixes Round 3): GNU coreutils' `timeout` ships under the
   name `gtimeout` on stock macOS (Homebrew installs it prefixed to
   avoid shadowing BSD's own tools); probe `timeout` first, then
   `gtimeout`, and use whichever this machine actually has. [Sys.command]
   never raises, so this stays total and exception-free even if the
   shell probe itself fails oddly. *)
let watchdog : string option =
  let has (cmd : string) : bool =
    Int.equal (Sys.command (Printf.sprintf "command -v %s > /dev/null 2>&1" cmd)) 0
  in
  match () with
  | () when has "timeout" -> Some "timeout"
  | () when has "gtimeout" -> Some "gtimeout"
  | () -> None

(* M2-fixes batch (Round 2), R2: a divergence REGRESSION on a script run
   in-process (a plain [Tot_surface.Run.script] call, no timeout) would
   hang the whole test binary forever rather than failing it, since
   [Interp.exec]'s recursion has no fuel of its own. Running the [tot]
   CLI as a CHILD process under an external watchdog turns that hang
   into an ordinary red assertion: a regression exits 124 (SIGTERM from
   the watchdog), which this helper reports as an [Error], instead of
   wedging the parent test process. Captures stdout+stderr to a scratch
   file and compares the exact line list on a clean exit, same
   discipline as [expect_lines]. *)
let expect_cli_run_lines (path : string) (want : string list) () : (unit, string) result =
  watchdog
  |> Option.fold
       ~none:
         (Error
            "no watchdog binary on PATH: neither `timeout` nor `gtimeout` was found (install \
             GNU coreutils, e.g. `brew install coreutils` on macOS, for `gtimeout`); refusing \
             to run the F1 CLI regression unguarded rather than risk a silent hang")
       ~some:(fun watchdog_cmd ->
         let out_path = Filename.temp_file "tot-cli-witness" ".out" in
         let cmd =
           Printf.sprintf "%s 10 %s run %s > %s 2>&1" watchdog_cmd (Filename.quote tot_exe)
             (Filename.quote path) (Filename.quote out_path)
         in
         let code = Sys.command cmd in
         (* if reading [out_path] here raises, the [Sys.remove] below is
            skipped and the scratch file leaks; accepted for a test harness,
            not restructured. *)
         let got = In_channel.with_open_text out_path In_channel.input_lines in
         Sys.remove out_path;
         match () with
         | () when Int.equal code 124 ->
             Error
               (Printf.sprintf
                  "regression: %s hit the external 10s timeout (exit 124), got so far [%s]" path
                  (show_lines got))
         | () when Int.equal code 0 ->
             if List.equal String.equal got want then Ok ()
             else
               Error (Printf.sprintf "got  [%s]\n  want [%s]" (show_lines got) (show_lines want))
         | () -> Error (Printf.sprintf "tot run %s exited %d: [%s]" path code (show_lines got)))

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

(* M2 fix batch (Stage A), F3: a [def rec] body with NO occurrence of its
   own name skips the totality guard entirely (previously vacuously
   satisfied at the first formal, which is a TYPE here and never
   canonical, so the def never unfolded). *)
let idty_def : string =
  "reducible def rec idty : (0 A : Type 0) -> Type 0 -> Type 0 := fun A t => t"

(* M2 fix batch (Stage B), F1: `def rec add`, reused by the bare-global and
   fully-applied readback tests below. *)
let add_def : string =
  "reducible def rec add : Nat -> Nat -> Nat := fun m n => match m with | zero => n \
   | succ p => succ (add p n) end"

let add_line : string = "def add : (w _ : Nat) -> (w _ : Nat) -> Nat"

(* M2-fixes batch (Round 2), R0: the kernel's [rec_arg] counts UNERASED
   formals ([Totality.peel] walks every [Term.Lam]), but [Interp]'s
   application spine is ERASED ([Erase.term] drops every [Quantity.Zero]
   [Lam] binder and [Quantity.Zero] [App] argument): a rec def with an
   erased formal before its principal argument shifted the runtime guard
   onto the wrong (or an out-of-range) spine position and never unfolded.
   [foldNat] and [map] are the stdlib prelude's own definitions
   (`stdlib/prelude.tot`), reused verbatim. *)
let list_data : string =
  "data List (0 A : Type 0) : Type 0 := | nil : List A | cons : A -> List A -> List A"

let list_lines : string list =
  [
    "data List : (0 A : Type 0) -> Type 0";
    "ctor nil : (0 A : Type 0) -> (List A)";
    "ctor cons : (0 A : Type 0) -> (w _ : A) -> (w _ : (List A)) -> (List A)";
  ]

let fold_nat_def : string =
  "def rec foldNat : (0 A : Type 0) -> A -> (A -> A) -> Nat -> A := fun A z s n => match n \
   with | zero => z | succ p => s (foldNat A z s p) end"

let map_def : string =
  "def rec map : (0 A : Type 0) -> (0 B : Type 0) -> (A -> B) -> List A -> List B := fun A \
   B f xs => match xs with | nil => nil B | cons h t => cons B (f h) (map A B f t) end"

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
    (* Stage A, F3: vacuous first-fit rec_arg *)
    ( "F3: no-occurrence rec def unfolds like a plain reducible def (idty)",
      expect_lines_check
        (with_lines [ nat_data; idty_def; "def x : idty Nat Nat := zero" ])
        (nat_lines
        @ [
            "def idty : (0 A : Type 0) -> (w _ : Type 0) -> Type 0";
            "def x : ((idty Nat) Nat)";
          ]) );
    ( "F3: zero-formal rec def with no self-occurrence checks as a plain def",
      expect_lines_check
        (with_lines [ nat_data; "def rec x : Nat := zero" ])
        (nat_lines @ [ "def x : Nat" ]) );
    ( "F3: genuinely non-structural rec is still rejected (Termination)",
      expect_err_printed
        (with_lines [ nat_data; "def rec bad : Nat -> Nat := fun n => bad n" ])
        "Kernel.Termination" );
    (* Stage B, F1: runtime guarded neutrals for rec globals. This is the
       ONE divergence-sensitive regression case (bare, unapplied "eval
       add": every other F1/F3 case above either never reaches the
       guarded path or only ever sees a canonical principal argument, so
       a regression there fails fast rather than hanging). Round 2, R2:
       runs the built CLI as a child process under an external `timeout`
       (see [expect_cli_run_lines]) instead of calling [Run.script]
       in-process, so a regression here shows up as a red assertion
       (exit 124) instead of hanging the test binary itself. *)
    ( "F1: bare eval of a rec global terminates, reading back as the \
       frozen global (previously diverged: quote re-executed frozen \
       match branches one binder deeper per level)",
      expect_cli_run_lines f1_witness_fixture (nat_lines @ [ add_line; "add" ]) );
    ( "F1: a rec global applied to canonical (closed) data still computes \
       exactly as before the guard",
      expect_lines
        (with_lines
           [
             nat_data;
             add_def;
             "def two : Nat := succ (succ zero)";
             "def three : Nat := succ two";
             "eval add two three";
           ])
        (nat_lines
        @ [
            add_line;
            "def two : Nat";
            "def three : Nat";
            "(succ (succ (succ (succ (succ zero)))))";
          ]) );
    (* M2-fixes batch (Round 2), R0: rec_arg unerased-vs-erased index
       mismatch *)
    ( "R0: foldNat (leading erased formal before the principal argument) \
       no longer freezes as a stuck neutral",
      expect_lines
        (with_lines
           [ nat_data; fold_nat_def; "def two : Nat := succ (succ zero)";
             "eval foldNat Nat zero succ two" ])
        (nat_lines
        @ [
            "def foldNat : (0 A : Type 0) -> (w _ : A) -> (w _ : (w _ : A) -> A) -> \
             (w _ : Nat) -> A";
            "def two : Nat";
            "(succ (succ zero))";
          ]) );
    ( "R0: map (polymorphic prelude fn) over a closed two-element List Nat",
      expect_lines
        (with_lines
           [
             nat_data; list_data; map_def;
             "def xs : List Nat := cons Nat zero (cons Nat (succ zero) (nil Nat))";
             "eval map Nat Nat succ xs";
           ])
        (nat_lines @ list_lines
        @ [
            "def map : (0 A : Type 0) -> (0 B : Type 0) -> (w _ : (w _ : A) -> B) -> \
             (w _ : (List A)) -> (List B)";
            "def xs : (List Nat)";
            "((cons (succ zero)) ((cons (succ (succ zero))) nil))";
          ]) );
    (* M2-fixes batch (Round 5 review), T0: a def rec whose KERNEL
       rec_arg lands on an ERASED (quantity-0) formal. [ghost]'s guarded
       formal is [j] (0-quantity): [dropErased]'s own first parameter is
       ALSO quantity-0, so the recursive call `ghost jp n` inside `match
       j with | succ jp => ...` type-checks (matching an erased var is
       only legal at the checker's Quantity.Zero mode, which an erased
       argument position provides) without ever needing to touch `j` at
       runtime mode. [Totality.guard] picks candidate k=0 (j) first-fit,
       so the KERNEL records `rec_arg = Some 0` on an erased formal.

       Round 3 had `remap_rec_arg` FREEZE this shape forever, on the
       claim that eager unfolding would re-arm Stage B's readback
       divergence. Round 5 review found that claim unfounded: no
       divergence witness existed for it, and a fresh over-application
       variant of the same claim was killed on verify. The load-bearing
       fact (mechanically confirmed by test/main.ml's "T0: rec def
       guarded on an erased formal has no self-reference after erasure",
       an [Eterm.t] walk over the checked-and-erased [ghost] body): a
       recursive call whose principal argument is a smaller variable
       bound by a match on an ERASED scrutinee necessarily sits inside
       that match's branches, which check at quantity-0 mode and are
       therefore erased away wholesale at their use site
       ([Erase.term]'s `App (Quantity.Zero, f, _a) -> term ctx f` never
       even walks `_a`). The erased body of a rec def guarded on an
       erased formal contains NO self-reference, so eager unfolding
       cannot loop, and it computes the definitionally correct value:
       bare `eval ghost` reads back as the unfolded identity function on
       its one KEPT argument (`dropErased` erases to the identity too,
       so quote's beta-reduction collapses straight through it), and
       applied `eval ghost zero (succ zero)` reads back as the computed
       result. `remap_rec_arg`'s erased-formal arm is reverted to `None`
       (eager unfold, M2-FIXES-LOG.md "## Round 4"). The CLI-plus-
       watchdog harness (`expect_cli_run_lines`) stays: a future
       regression that re-introduces a real self-reference through this
       path still fails red (watchdog timeout), not hangs. *)
    ( "T0: rec def guarded on an erased formal eagerly unfolds to the \
       correct value, both bare and applied",
      expect_cli_run_lines s0_erased_guard_fixture
        (nat_lines
        @ [
            "def dropErased : (0 j : Nat) -> (w _ : Nat) -> Nat";
            "def ghost : (0 j : Nat) -> (w _ : Nat) -> Nat";
            "fun n => n";
            "(succ zero)";
          ]) );
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
