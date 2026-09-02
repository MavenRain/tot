(** M1 surface tests, end to end through Run.script. Positives pin the
    EXACT full output-line list; negatives pin the EXACT error tag, so a
    vacuous pass is impossible. *)

let ( let* ) = Result.bind

let show_lines (lines : string list) : string = String.concat " | " lines

let expect_with ?st ~(exec : bool) (src : string) (want : string list) () :
    (unit, string) result =
  Tot_surface.Run.script ?st ~exec src
  |> Result.fold
       ~ok:(fun (got, _exit_code) ->
         if List.equal String.equal got want then Ok ()
         else
           Error
             (Printf.sprintf "got  [%s]\n  want [%s]" (show_lines got) (show_lines want)))
       ~error:(fun e -> Error ("error: " ^ Tot_surface.Serror.to_string e))

let expect_lines ?st (src : string) (want : string list) () : (unit, string) result =
  expect_with ?st ~exec:true src want ()

let expect_lines_check ?st (src : string) (want : string list) () : (unit, string) result =
  expect_with ?st ~exec:false src want ()

(* M3 Stage D: like [expect_with ~exec:true], but ALSO pins the process
   exit code [Run.script]'s epilogue computed -- [expect_lines] itself
   discards it. Needed for the D4 main-epilogue tests, since the whole
   point of the IO Verdict priority rule is what exit code comes out,
   not just what gets printed. *)
let expect_run ?st (src : string) ~(want_lines : string list) ~(want_exit : int option) () :
    (unit, string) result =
  Tot_surface.Run.script ?st ~exec:true src
  |> Result.fold
       ~ok:(fun (got_lines, got_exit) ->
         if List.equal String.equal got_lines want_lines && Option.equal Int.equal got_exit want_exit
         then Ok ()
         else
           Error
             (Printf.sprintf "got [%s] exit=%s, want [%s] exit=%s" (show_lines got_lines)
                (Option.fold ~none:"None" ~some:string_of_int got_exit)
                (show_lines want_lines)
                (Option.fold ~none:"None" ~some:string_of_int want_exit)))
       ~error:(fun e -> Error ("error: " ^ Tot_surface.Serror.to_string e))

let expect_err ?st (src : string) (want_tag : string) () : (unit, string) result =
  Tot_surface.Run.script ?st ~exec:true src
  |> Result.fold
       ~ok:(fun (lines, _exit_code) ->
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
let expect_err_printed ?st (src : string) (want_tag : string) () : (unit, string) result =
  Tot_surface.Run.script ?st ~exec:true src
  |> Result.fold
       ~ok:(fun (lines, _exit_code) ->
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

(* M3 Stage D, D2: point every in-process [Tot_surface.Cache] call this
   suite makes at a scratch directory, never the real ~/.cache/tot
   ([Cache]'s own module doc comment names this exact override as its
   test-isolation fill-in). [Filename.temp_file] both reserves a
   unique path and creates an (empty) FILE there; removing it and
   reusing the freed name as a DIRECTORY is the standard
   "get a fresh unique path" idiom for a test harness (not
   restructured further, matching this file's own existing
   [Filename.temp_file] usage in [expect_cli_run_lines] above). *)
let () =
  let dir = Filename.temp_file "tot-cache-test" "" in
  let () = Sys.remove dir in
  Unix.putenv "TOT_CACHE_DIR" dir

(* M2-fixes batch (Round 2), R2: a divergence REGRESSION on a script run
   in-process (a plain [Tot_surface.Run.script] call, no timeout) would
   hang the whole test binary forever rather than failing it, since
   [Interp.exec]'s recursion has no fuel of its own. Running the [tot]
   CLI as a CHILD process under an external watchdog turns that hang
   into an ordinary red assertion: a regression exits 124 (SIGTERM from
   the watchdog), which this helper reports as an [Error], instead of
   wedging the parent test process. Captures stdout+stderr to a scratch
   file and compares the exact line list on a clean exit, same
   discipline as [expect_lines].

   M3 Stage D, D1: both fixtures this helper drives (F1's
   f1-witness.tot, T0's s0-erased-guard.tot) are kernel-test-style
   scripts that declare their OWN "data Nat" from scratch, so they run
   with "--no-prelude" (decision 14): [bin/tot.ml] now auto-loads the
   prelude by default, and the prelude's own "Nat" would otherwise
   collide (Duplicate_global). *)
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
           Printf.sprintf "%s 10 %s run --no-prelude %s > %s 2>&1" watchdog_cmd
             (Filename.quote tot_exe) (Filename.quote path) (Filename.quote out_path)
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

let cases (bst : Tot_surface.Run.state) : (string * (unit -> (unit, string) result)) list =
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
    (* M3 Stage A: literals, builtin base types, the Prim entry kind.
       [bst] is the bootstrapped state (Bootstrap.state ()), computed
       once below and threaded in here. *)
    ( "A9: eval stringConcat computes",
      expect_lines ~st:bst "eval stringConcat \"a\" \"b\"" [ "\"ab\"" ] );
    ("A10: eval intAdd computes", expect_lines ~st:bst "eval intAdd 2 3" [ "5" ]);
    ( "A11: check mode prints the String and Int result types",
      expect_lines_check ~st:bst "eval stringConcat \"a\" \"b\"\neval intAdd 2 3"
        [ "eval : String"; "eval : Int" ] );
    ( "A12: partial stringConcat quotes as a frozen prim spine",
      expect_lines ~st:bst "eval stringConcat \"a\"" [ "(stringConcat \"a\")" ] );
    ( "A13: literal type mismatch is a kernel error",
      expect_err_printed ~st:bst "def x : String := 3" "Kernel.Mismatch" );
    ( "A14: match on a String scrutinee cannot eliminate (declared-only ind)",
      expect_err_printed ~st:bst "def f : String -> String := fun s => match s with end"
        "Kernel.Ind_incomplete" );
    (* M3 Stage B: the ladder end to end. [bst] carries Div/IO and the
       nine new prims (B1-B7 above cover the kernel-level half; B8-B10,
       the OS-observed half, live in dev/gates.sh via this binary's
       own [gate-check]/[gate-run] argv mode below). *)
    ( "B5: eval bindIO ... in check mode prints the type and executes nothing",
      expect_lines_check ~st:bst "eval bindIO String Unit readStdin (fun s => printLine s)"
        [ "eval : (IO Unit)" ] );
    ( "B6: eval of an IO expression in run mode is Kernel.Not_quotable (sequencing goes \
       through main, not eval)",
      expect_err_printed ~st:bst "eval bindIO String Unit readStdin (fun s => printLine s)"
        "Kernel.Not_quotable" );
    ( "B7: a Div-headed def whose body applies a prim is accepted, and check does not \
       compute it (paired with the heavier dev/gates.sh PASS-B-DEFERRED timing fixture)",
      expect_lines_check ~st:bst
        "def slowish : Div String := pureDiv String (stringConcat \"a\" \"b\")"
        [ "def slowish : (Div String)" ] );
    (* M3 Stage C, C7 test 5: a real JSON fixture round-trips (parse,
       project fields by match, re-serialize, compare against the
       exact source payload). jsonParse is Div, so the whole check
       stays Div-typed via let*! until pureDiv closes it. *)
    ( "C5: JSON fixture round-trips: parse, project by match, re-serialize, compare",
      expect_lines ~st:bst
        (with_lines
           [
             "def payload : String := \"{\\\"name\\\":\\\"tot\\\",\\\"count\\\":3}\"";
             "def checkAll : Div Bool :=";
             "  let*! (Option Json) Bool mj := jsonParse payload in";
             "  pureDiv Bool";
             "    (match mj with";
             "     | none => false";
             "     | some j =>";
             "         match jsonGetString j \"name\" with";
             "         | none => false";
             "         | some nm =>";
             "             match stringEq nm \"tot\" with";
             "             | true =>";
             "                 match jsonGet j \"count\" with";
             "                 | none => false";
             "                 | some cv =>";
             "                     match jsonAsInt cv with";
             "                     | none => false";
             "                     | some n =>";
             "                         match intEq n 3 with";
             "                         | true => stringEq (jsonSerialize j) payload";
             "                         | false => false";
             "                         end";
             "                     end";
             "                 end";
             "             | false => false";
             "             end";
             "         end";
             "     end)";
             "eval checkAll";
           ])
        [
          "def payload : String";
          "def checkAll : (Div Bool)";
          "true";
        ] );
    (* M3 Stage C, C7 test 6: the surface-level positivity control (a
       kernel-level counterpart lives in test/main.ml's C4): a
       "jarr : List Json -> Json"-style nesting is STILL rejected. *)
    ( "C6: control test, List Json -> Json nesting is still rejected by positivity",
      expect_err_printed ~st:bst
        "data Bad : Type 0 := | jarr : List Json -> Json" "Kernel.Bad_ctor" );
    (* M3 Stage C, C7 test 7: let*/let*! desugar and check; a let* over
       a Div action without liftIO is a Kernel.Mismatch. *)
    ( "C7a: let* desugars to bindIO and checks",
      expect_lines_check ~st:bst
        "def main : IO Unit := let* String Unit raw := readStdin in printLine raw"
        [ "def main : (IO Unit)" ] );
    ( "C7b: let*! desugars to bindDiv and checks",
      expect_lines_check ~st:bst
        "def y : Div Int := let*! String Int s := pureDiv String \"abc\" in pureDiv Int \
         (stringLength s)"
        [ "def y : (Div Int)" ] );
    ( "C7c: let* over a Div action without liftIO is Kernel.Mismatch",
      expect_err_printed ~st:bst
        "def bad : IO Int := let* String Int s := pureDiv String \"a\" in pureDiv Int \
         (stringLength s)"
        "Kernel.Mismatch" );
    (* M3 Stage C, C7 test 8: stringSplit/stringSlice/stringToInt/
       intCompare each compute one pinned value under `tot run`. *)
    ( "C8: stringSplit/stringSlice/stringToInt/intCompare each compute a pinned value",
      expect_lines ~st:bst
        (with_lines
           [
             "eval stringSplit \"a,b,c\" \",\"";
             "eval stringSlice \"hello world\" 6 5";
             "eval stringToInt \"42\"";
             "eval intCompare 2 5";
           ])
        [
          "((cons \"a\") ((cons \"b\") ((cons \"c\") nil)))";
          "(some \"world\")";
          "(some 42)";
          "lt";
        ] );
    (* M3 fixes round 2, ctxcat id 9: stringToInt is decimal-only
       (optional '-', digits), never OCaml's wider int_of_string
       syntax. Pre-fix (recorded in dev/M3-FIXES-LOG.md): "0x1A"
       parsed to (some 26) and "1_000" to (some 1000). *)
    ( "C8b: stringToInt rejects hex/underscore/sign-only/space forms, keeps plain decimals",
      expect_lines ~st:bst
        (with_lines
           [
             "eval stringToInt \"0x1A\"";
             "eval stringToInt \"1_000\"";
             "eval stringToInt \"-42\"";
             "eval stringToInt \"-\"";
             "eval stringToInt \" 7\"";
           ])
        [ "none"; "none"; "(some -42)"; "none"; "none" ] );
    (* M3 fixes round 3 (ctxcat id 5): stringSlice bounds arithmetic
       is overflow-safe. 999999999999999999 (18 nines, ~1e18) is the
       largest literal shape the lexer admits; intAdd builds ~3e18,
       and ~3e18 + ~3e18 wraps NEGATIVE in OCaml's 63-bit int, so the
       pre-fix additive guard admitted an out-of-range String.sub and
       the process died on an uncaught Invalid_argument (recorded in
       dev/M3-FIXES-LOG.md). Both calls now return none cleanly; the
       huge-start case pins the non-overflow out-of-range path
       beside it. *)
    ( "C8d: stringSlice with overflow-scale start/len returns none, never a crash",
      expect_lines ~st:bst
        (with_lines
           [
             "eval stringSlice \"abc\" (intAdd 999999999999999999 (intAdd 999999999999999999 \
              999999999999999999)) (intAdd 999999999999999999 (intAdd 999999999999999999 \
              999999999999999999))";
             "eval stringSlice \"abc\" 999999999999999999 1";
           ])
        [ "none"; "none" ] );
    (* M3 fixes round 2, ctxcat id 14: a raw newline inside a string
       literal is a Lex error (write \n instead); pre-fix the lexer
       silently absorbed it, so a missing close quote swallowed the
       rest of the file. expect_err_printed shows the exact message. *)
    ( "C8c: a raw newline inside a string literal is a lex error, never silent absorption",
      expect_err_printed ~st:bst "eval stringLength \"a\nb\"" "Lex" );
    (* M3 fixes round 4 (sign-off finding): the \r escape lexes to a
       carriage-return character, usable as a stringSplit separator
       (the guard's IFS tokenizer needs it). Pre-fix: "unknown escape
       \r" (recorded in dev/M3-FIXES-LOG.md). *)
    ( "C8e: the backslash-r escape lexes to a carriage-return split separator",
      expect_lines ~st:bst "eval stringSplit \"a\\rb\" \"\\r\""
        [ "((cons \"a\") ((cons \"b\") nil))" ] );
    (* M3 Stage D, D3: shebang stripping. Only a literal "#!" at column
       0, line 1 strips; anything else falls through to the ordinary
       lexer, where a bare '#' is unexpected (there is no comment
       marker other than "--"). *)
    ( "D1a: a leading shebang line strips before lexing; the rest runs unchanged",
      expect_lines ~st:bst "#!/usr/bin/env -S tot run\neval intAdd 2 3" [ "5" ] );
    ( "D1b: \"#!\" NOT at column 0 line 1 is left alone (a bare '#' is a lex error)",
      expect_err ~st:bst " #!/x\neval intAdd 2 3" "Lex" );
    (* M3 Stage D, D2: the on-disk prelude cache. TOT_CACHE_DIR (set
       once above) keeps this off the real ~/.cache/tot. *)
    ( "D2: Cache.save/load round-trips byte-for-byte and degrades to a miss, never a crash, \
       on a missing key, a truncated header or body, a bit-flipped body, a wrong binary \
       digest, or a wrong magic",
      fun () ->
        let open Tot_kernel in
        let cache_key = Tot_surface.Cache.key "-- D2 test prelude bytes\n" in
        let missing = Tot_surface.Cache.load (cache_key ^ "-missing") in
        if Option.is_some missing then Error "expected a miss on a never-saved key, got a hit"
        else
          let () = Tot_surface.Cache.save cache_key bst.Tot_surface.Run.globals bst.Tot_surface.Run.eglobals in
          let loaded = Tot_surface.Cache.load cache_key in
          loaded
          |> Option.fold
               ~none:(Error "expected a hit right after save, got a miss")
               ~some:(fun (g, e) ->
                 let want_bytes = Marshal.to_string (bst.Tot_surface.Run.globals, bst.Tot_surface.Run.eglobals) [] in
                 let got_bytes = Marshal.to_string (g, e) [] in
                 if not (String.equal want_bytes got_bytes) then
                   Error "loaded (Global.t, Interp.globals) is not byte-identical to what was saved"
                 else
                   (* M3 fixes round 3 (O1): [cache_dir] is an option
                      now (None disables the cache); TOT_CACHE_DIR is
                      set once above, so None here is a test-env bug. *)
                   let* dir =
                     Tot_surface.Cache.cache_dir ()
                     |> Option.to_result
                          ~none:"cache_dir returned None (TOT_CACHE_DIR unset in the test env?)"
                   in
                   let path = Filename.concat dir ("prelude-" ^ cache_key ^ ".bin") in
                   let content = In_channel.with_open_bin path In_channel.input_all in
                   let rewrite (bytes : string) : unit =
                     Out_channel.with_open_bin path (fun oc ->
                         Out_channel.output_string oc bytes)
                   in
                   let expect_miss (label : string) (bytes : string) : (unit, string) result =
                     let () = rewrite bytes in
                     if Option.is_some (Tot_surface.Cache.load cache_key) then
                       Error ("expected a miss on " ^ label ^ ", got a hit")
                     else Ok ()
                   in
                   (* a GUARANTEED byte change at one index, via a total
                      traversal: whatever the byte was, it becomes a
                      DIFFERENT one *)
                   let corrupt_at (ix : int) (s : string) : string =
                     String.mapi
                       (fun i c ->
                         match () with
                         | () when not (Int.equal i ix) -> c
                         | () when Char.equal c 'A' -> 'B'
                         | () -> 'A')
                       s
                   in
                   (* content is a just-written cache blob: always >= its
                      [Cache.header_width]-byte magic+version+digest+
                      exe-digest header plus a multi-KB Marshal body, so
                      both slices below are total (M3 fixes, B2: pre-fix,
                      the corrupted-body shape SEGFAULTED and the
                      body-truncated one died on an uncaught
                      Invalid_argument). Offsets derive from the named
                      width constants [Cache] itself exposes, never bare
                      literals (M3 fixes round 2, ctxcat id 17: a header
                      resize now shifts these with it instead of silently
                      changing which field the test corrupts). *)
                   let exe_field_off =
                     Tot_surface.Cache.magic_width + Tot_surface.Cache.version_width
                     + Tot_surface.Cache.digest_width
                   in
                   let* () =
                     expect_miss "a header-truncated file"
                       (String.sub content 0 5 (* @total-accessor *))
                   in
                   let* () =
                     expect_miss "a body-truncated file"
                       (String.sub content 0 (String.length content - 1) (* @total-accessor *))
                   in
                   let* () =
                     (* [header_width] + 40 sits past the whole header,
                        inside the Marshal body the digest covers *)
                     expect_miss "a corrupted body byte"
                       (corrupt_at (Tot_surface.Cache.header_width + 40) content)
                   in
                   let* () =
                     (* M3 fixes round 2, R1: an index inside the
                        executable-digest header field (bytes
                        [exe_field_off] .. [header_width - 1]), so this
                        is exactly the wrong-binary-digest header shape
                        a drifted sibling binary would present; the
                        body and its digest stay VALID, proving the exe
                        field check alone forces the miss *)
                     expect_miss "a wrong-binary-digest header field"
                       (corrupt_at (exe_field_off + 12) content)
                   in
                   let* () = expect_miss "a wrong-magic file" (corrupt_at 0 content) in
                   let () =
                     Tot_surface.Cache.save cache_key bst.Tot_surface.Run.globals
                       bst.Tot_surface.Run.eglobals
                   in
                   Tot_surface.Cache.load cache_key
                   |> Option.fold
                        ~none:
                          (Error "expected a hit again after the final re-save, got a miss")
                        ~some:(fun (_g2, _e2) -> Ok ())) );
    (* M3 Stage D, D4: render_verdict and the main : IO Verdict
       epilogue, tried FIRST, ahead of IO Unit. *)
    ( "D4a: render_verdict renders allow/ask/deny exactly and rejects a non-Verdict VCon",
      fun () ->
        let open Tot_kernel in
        let check (v : Interp.v) (want : string option * int) (label : string) :
            (unit, string) result =
          Tot_surface.Effect.render_verdict v
          |> Result.fold
               ~ok:(fun (got_line, got_code) ->
                 if Option.equal String.equal got_line (fst want) && Int.equal got_code (snd want)
                 then Ok ()
                 else Error (label ^ ": rendered value did not match"))
               ~error:(fun e -> Error (label ^ ": " ^ Error.to_string e))
        in
        let* () = check (Interp.VCon ("allow", [])) (None, 0) "allow" in
        let* () =
          check
            (Interp.VCon ("ask", [ Interp.VLit (Literal.LString "why") ]))
            ( Some
                "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"ask\",\"permissionDecisionReason\":\"why\"}}",
              1 )
            "ask"
        in
        let* () =
          check
            (Interp.VCon ("deny", [ Interp.VLit (Literal.LString "msg") ]))
            ( Some
                "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"msg\"}}",
              2 )
            "deny"
        in
        Tot_surface.Effect.render_verdict (Interp.VCon ("mystery", []))
        |> Result.fold
             ~ok:(fun _ -> Error "expected Mismatch on a non-Verdict VCon, got Ok")
             ~error:(fun e ->
               if String.equal (Error.tag e) "Mismatch" then Ok ()
               else Error ("expected Mismatch, got " ^ Error.tag e)) );
    ( "D4b: main : IO Verdict takes priority over IO Unit; deny renders the exact envelope \
       and exit 2",
      expect_run ~st:bst "def main : IO Verdict := pureIO Verdict (deny \"nope\")"
        ~want_lines:
          [
            "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"nope\"}}";
          ]
        ~want_exit:(Some 2) );
    ( "D4c: main : IO Verdict, allow prints nothing and exits 0",
      expect_run ~st:bst "def main : IO Verdict := pureIO Verdict allow" ~want_lines:[]
        ~want_exit:(Some 0) );
    ( "D4d: an explicit exitWith inside an IO Verdict main short-circuits and wins over \
       ever rendering a verdict",
      expect_run ~st:bst
        "def main : IO Verdict := bindIO Unit Verdict (exitWith 7) (fun u => pureIO Verdict \
         allow)"
        ~want_lines:[] ~want_exit:(Some 7) );
    ( "D4e: main : IO Unit still runs when it does not convert to IO Verdict, and honors \
       exitWith (the ordinary per-item echo is unaffected, unlike the Verdict path)",
      expect_run ~st:bst "def main : IO Unit := exitWith 3"
        ~want_lines:[ "def main : (IO Unit)" ] ~want_exit:(Some 3) );
    (* M3 fixes, C1' (O4): main is a RESERVED driver name. A main
       whose type converts to neither IO Verdict nor IO Unit is
       Serror.Main_bad_type in BOTH modes (pre-fix: a silent exit-0
       no-op, the permit-all shape); the misspelled variant stays
       script mode, the documented SPEC section 6 residual. *)
    ( "D4f: main : IO Bool is Main_bad_type in run mode (error printed, the effect never \
       fires)",
      expect_err_printed ~st:bst
        "def main : IO Bool := let* Unit Bool a := printLine \"THIS EFFECT NEVER HAPPENS\" \
         in pureIO Bool true"
        "Main_bad_type" );
    ( "D4g: main : IO Bool is Main_bad_type in CHECK mode too",
      fun () ->
        Tot_surface.Run.script ~st:bst ~exec:false
          "def main : IO Bool := let* Unit Bool a := printLine \"x\" in pureIO Bool true"
        |> Result.fold
             ~ok:(fun (lines, _exit_code) ->
               Error
                 (Printf.sprintf "expected Main_bad_type, but check passed: [%s]"
                    (show_lines lines)))
             ~error:(fun e ->
               let tag = Tot_surface.Serror.tag e in
               Printf.printf "  expected error (Main_bad_type): %s\n"
                 (Tot_surface.Serror.to_string e);
               if String.equal tag "Main_bad_type" then Ok ()
               else Error ("wrong error: " ^ Tot_surface.Serror.to_string e)) );
    ( "D4h: a misspelled main (mian) stays script mode with no driver exit code (the \
       documented residual)",
      expect_run ~st:bst "def mian : IO Verdict := pureIO Verdict (deny \"never reached\")"
        ~want_lines:[ "def mian : (IO Verdict)" ] ~want_exit:None );
    (* M3 fixes, B3 (C8): procRun's spawn-failure path returns the
       cannot-exec sentinel AND closes every parent-held descriptor.
       /dev/fd's entry count is the observable: it is stable across
       calls when nothing leaks (each [Sys.readdir]'s own descriptor is
       closed before it returns), and the pre-fix pipe design held
       descriptors open across the spawn decision. *)
    ( "B3: procRun spawn failure returns the -1 sentinel and leaks no descriptors across 5 \
       attempts",
      fun () ->
        let open Tot_kernel in
        let fd_count () : (int, string) result =
          match Sys.readdir "/dev/fd" with
          | exception Sys_error _ -> Error "cannot read /dev/fd"
          | entries -> Ok (Array.length entries)
        in
        let spawn_once () : (unit, string) result =
          Tot_surface.Effect.dispatch bst.Tot_surface.Run.eglobals Prim.Proc_run
            [ Interp.VLit (Literal.LString "/nonexistent-tot-b3-binary"); Interp.VCon ("nil", []) ]
          |> Result.fold
               ~error:(fun e -> Error ("dispatch errored: " ^ Error.to_string e))
               ~ok:(fun outcome ->
                 match outcome with
                 | Tot_surface.Effect.Exited _ -> Error "unexpected Exited from procRun"
                 | Tot_surface.Effect.Done v -> (
                     match v with
                     | Interp.VCon
                         ( "mkProcessResult",
                           [ Interp.VLit (Literal.LInt code); Interp.VLit _; Interp.VLit _ ] )
                       ->
                         if Int.equal code (-1) then Ok ()
                         else Error (Printf.sprintf "want sentinel code -1, got %d" code)
                     | Interp.VCon (_, _)
                     | Interp.VClos (_, _, _)
                     | Interp.VNeut (_, _)
                     | Interp.VErased | Interp.VLit _
                     | Interp.VPrim (_, _)
                     | Interp.VIOAction _ ->
                         Error "procRun did not produce a mkProcessResult triple"))
        in
        let* before = fd_count () in
        let* () =
          List.fold_left
            (fun acc _i ->
              let* () = acc in
              spawn_once ())
            (Ok ()) [ 1; 2; 3; 4; 5 ]
        in
        let* after = fd_count () in
        if Int.equal before after then Ok ()
        else Error (Printf.sprintf "descriptor growth: %d before, %d after" before after) );
  ]

(** The ordinary in-process suite: bootstrap once, run every [cases]
    entry, print one PASS/FAIL line each, and return an exit code
    (0 green, else 1). This is [dune exec test/surface.exe]'s (and
    `dune runtest`'s) default behavior, UNCHANGED from before M3 Stage
    B: [run_gate] below is reached only through the two argv shapes
    [dispatch] recognizes explicitly. *)
let run_suite () : int =
  Tot_surface.Bootstrap.state ()
  |> Result.fold
       ~error:(fun e ->
         print_endline ("bootstrap failed: " ^ Tot_surface.Serror.to_string e);
         1)
       ~ok:(fun bst ->
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
             0 (cases bst)
         in
         (match () with
         | () when Int.equal failures 0 -> print_endline "M1 surface: all tests green"
         | () -> Printf.printf "%d test(s) failed\n" failures);
         Int.min failures 1)

(** M3 Stage B: a tiny process-level harness for dev/gates.sh's
    OS-observed Gate B checks (a real stdin/exit-code sequence, the
    check-performs-no-I/O constraint, and the deferred-Div timing
    bound). [bin/tot.ml] does not gain [Bootstrap.state ()] wiring
    until Stage D (D1): wiring it in early there would double-define
    every prelude global the moment `stdlib/prelude.tot` itself is
    checked/run as a target script, which is exactly what the FIXED
    Gate command battery's `PASS-CHECK-PRELUDE`/`PASS-RUN-PRELUDE`
    steps (dev/gates.sh) do today. Reusing this ALREADY-Files-listed
    test binary for a second, argv-gated mode avoids adding a new dune
    executable while still giving the gate script a real OS process
    whose own exit code is exactly what the fixture's `main` computed;
    recorded here (not silently absorbed) per the plan's own
    instruction to log a plan-detail fill-in. *)
let run_gate ~(exec : bool) (path : string) : int =
  match () with
  | () when not (Sys.file_exists path) ->
      print_endline (path ^ ": no such file");
      1
  | () ->
      let src = In_channel.with_open_text path In_channel.input_all in
      Tot_surface.Bootstrap.state ()
      |> Result.fold
           ~error:(fun e ->
             print_endline ("bootstrap failed: " ^ Tot_surface.Serror.to_string e);
             1)
           ~ok:(fun st ->
             Tot_surface.Run.script ~st ~exec src
             |> Result.fold
                  ~ok:(fun (lines, exit_code) ->
                    List.iter print_endline lines;
                    Option.value exit_code ~default:0)
                  ~error:(fun e ->
                    print_endline (path ^ ": " ^ Tot_surface.Serror.to_string e);
                    1))

(** M3 Stage C: [stdlib/prelude.tot] is no longer independently
    checkable via a bare, unbootstrapped [tot check/run] (bin/tot.ml
    stays on [Run.initial] until Stage D's D1): the Stage C DATA/DEF
    segments reference the builtin [String]/[Int]/[Div]/[IO] type
    formers and the [stringEq] prim, none of which exist without
    [Bootstrap.phase1]/[phase2] having run first. Folding the prelude
    a SECOND time via [gate-check]/[gate-run] would double-define
    every global (the exact failure mode Stage B's own build log
    documents for a different reason), so this mode instead verifies
    [Bootstrap.state ()] itself -- which folds the prelude internally,
    with every phase interleaved correctly -- succeeds. dev/gates.sh
    derives its [PASS-CHECK-PRELUDE] marker from this exit code
    (checking the prelude and bootstrapping are the same operation;
    since the M3 fixes batch, A3/C15, [PASS-RUN-PRELUDE] instead runs
    a real prelude-exercising script through gate-run). *)
let bootstrap_only () : int =
  Tot_surface.Bootstrap.state ()
  |> Result.fold
       ~ok:(fun _st -> 0)
       ~error:(fun e ->
         print_endline ("bootstrap failed: " ^ Tot_surface.Serror.to_string e);
         1)

(** M3 Stage C, C6: a fourth argv-gated mode, the same "reuse this
    already-Files-listed binary instead of adding a new dune
    executable" discipline [run_gate] documents above. Prints the
    number of prim entries [surface/bootstrap.ml] actually seeds
    ([phase1_prims @ phase2_prims @ phase3_prims]'s length; M3 fixes
    round 2, ctxcat id 16: this doc comment now sits on the function
    it describes and names all THREE phase lists), so
    dev/prim-lint.sh can compare it against [Prim.catalog]'s own size
    (via "tot prims"'s line count) without a full [Bootstrap.state ()]
    fold: counting the source lists needs no prelude at all. *)
let print_bootstrap_prim_count () : int =
  Printf.printf "%d\n"
    (List.length
       (Tot_surface.Bootstrap.phase1_prims @ Tot_surface.Bootstrap.phase2_prims
      @ Tot_surface.Bootstrap.phase3_prims));
  0

let () =
  match Array.to_list Sys.argv with
  | [ _exe; "gate-check"; path ] -> Stdlib.exit (run_gate ~exec:false path)
  | [ _exe; "gate-run"; path ] -> Stdlib.exit (run_gate ~exec:true path)
  | [ _exe; "prim-bootstrap-count" ] -> Stdlib.exit (print_bootstrap_prim_count ())
  | [ _exe; "bootstrap-only" ] -> Stdlib.exit (bootstrap_only ())
  | [] | [ _ ] -> Stdlib.exit (run_suite ())
  (* M3 fixes, C4' (C13, 2026-09-01): a malformed or unknown
     subcommand shape (a typo'd name, gate-check with a missing or
     extra argument) is a USAGE ERROR, exit 2 with a message on
     stderr, never a silent fallback to the full suite: dev/gates.sh
     must see its own broken invocation, not a spurious green suite
     run. Only a BARE argv still runs the ordinary suite. *)
  | _exe :: arg :: rest ->
      Printf.eprintf
        "unknown subcommand: %s\n\
         usage: surface.exe [gate-check FILE | gate-run FILE | prim-bootstrap-count | \
         bootstrap-only]\n"
        (String.concat " " (arg :: rest));
      Stdlib.exit 2
