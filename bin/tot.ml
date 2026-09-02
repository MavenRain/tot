(** The tot CLI: check a script (elaborate and type-check, executing
    nothing from the user file, though a check MAY still write the
    prelude cache: hooks need warm-cache check latency; M3 fixes,
    B2/O7) or run it (execute eval items).
    M3 Stage D, D1: `check`/`run` auto-load the prelude
    ([Tot_surface.Bootstrap.cached_state ()], cache-backed by
    [surface/cache.ml]) before folding the target script, so a script
    can use every prelude name (Bool, Nat, List, Json, the whole prim
    catalog, ...) without redeclaring it. `--no-prelude` keeps the bare
    M2-only environment ([Run.initial]) instead, decision 14 of the M3
    design verdict: kernel-test-style scripts that declare their OWN
    names already present in the prelude (e.g. `examples/nat.tot`'s own
    `data Nat`) would otherwise collide with it (`Duplicate_global`).
    The existence guard makes the common missing-file case a clean
    exit 1; the residual raise-on-permission-race inside
    [In_channel.with_open_text] is a documented SPEC debt (unchanged
    from M0/M1). *)

let run_file ~(exec : bool) ~(st : Tot_surface.Run.state) (path : string) : int =
  match () with
  | () when not (Sys.file_exists path) ->
      print_endline (path ^ ": no such file");
      1
  | () ->
      let src = In_channel.with_open_text path In_channel.input_all in
      Tot_surface.Run.script ~st ~exec src
      |> Result.fold
           ~ok:(fun (lines, exit_code) ->
             List.iter print_endline lines;
             (* M3 Stage B: a script's `main : IO Unit` epilogue (or, M3
                Stage D, `IO Verdict`) may request an exit code via
                `exitWith`; absent that (or absent a `main` at all,
                every M2 script), 0. *)
             Option.value exit_code ~default:0)
           ~error:(fun e ->
             (* M3 fixes, B4: a runtime script error's message goes to
                STDERR (stdout is the hook protocol's channel and must
                carry only a rendered decision), exit 1. *)
             prerr_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
             1)

(** The prelude-auto-loaded path: bootstrap once, report a bootstrap
    failure (a hand-broken `stdlib/prelude.tot`, a missing prelude file
    with no `TOT_PRELUDE` override, ...) the same way any other script
    error is reported (M3 fixes round 2: on STDERR, the B4 channel
    rule; stdout carries only a rendered decision), then run the
    target file against that state. *)
let run_with_prelude ~(exec : bool) (path : string) : int =
  Tot_surface.Bootstrap.cached_state ()
  |> Result.fold
       ~ok:(fun st -> run_file ~exec ~st path)
       ~error:(fun e ->
         prerr_endline ("prelude: " ^ Tot_surface.Serror.to_string e);
         1)

let run_no_prelude ~(exec : bool) (path : string) : int =
  run_file ~exec ~st:Tot_surface.Run.initial path

(** M3 Stage C, C6: "tot prims" prints one line per [Prim.catalog]
    entry ("NAME  ARITY  CLASS  justification text"), the review
    surface dev/prim-lint.sh's own PASS-C-PRIMLINT check reads. Needs
    no bootstrapped environment at all: [Prim.catalog]/[Prim.name]/
    [Prim.arity]/[Prim.classification]/[Prim.justification] are pure
    lib/prim.ml functions, independent of [Global]/[Interp]. *)
let ladder_string (l : Tot_kernel.Prim.ladder) : string =
  match l with
  | Tot_kernel.Prim.Tot -> "Tot"
  | Tot_kernel.Prim.Div -> "Div"
  | Tot_kernel.Prim.Io -> "Io"

let print_prims () : int =
  List.iter
    (fun p ->
      Printf.printf "%s  %d  %s  %s\n" (Tot_kernel.Prim.name p) (Tot_kernel.Prim.arity p)
        (ladder_string (Tot_kernel.Prim.classification p))
        (Tot_kernel.Prim.justification p))
    Tot_kernel.Prim.catalog;
  0

let () =
  match Array.to_list Sys.argv with
  | _exe :: "check" :: "--no-prelude" :: [ path ] -> Stdlib.exit (run_no_prelude ~exec:false path)
  | _exe :: "run" :: "--no-prelude" :: [ path ] -> Stdlib.exit (run_no_prelude ~exec:true path)
  | _exe :: "check" :: [ path ] -> Stdlib.exit (run_with_prelude ~exec:false path)
  | _exe :: "run" :: [ path ] -> Stdlib.exit (run_with_prelude ~exec:true path)
  | _exe :: "prims" :: [] -> Stdlib.exit (print_prims ())
  | [] | [ _ ] | _ :: _ :: _ ->
      print_endline "usage: tot (check|run) [--no-prelude] FILE | tot prims";
      Stdlib.exit 2
