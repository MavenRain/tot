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
    [Tot_surface.Source.read] makes every unusable target a clean exit 1
    on stderr; M4 fixes round 2 (opus R2) closed the three sibling paths
    the M0/M1 existence guard alone left raising or blocking, and M4
    fixes round 3 (opus R3-2) closed the fourth, the PRELUDE read, by
    moving the classifier into [surface/source.ml] and prechecking the
    prelude path with it here. *)

let run_file ~(exec : bool) ~(policy : Tot_surface.Run.policy) ~(serror_exit : int)
    ~(st : Tot_surface.Run.state) (path : string) : int =
  Tot_surface.Source.read path
  |> Result.fold
       ~error:(fun (e : Tot_surface.Source.error) ->
         (* M4 fixes round 1 (audit F2), widened by round 2 (opus R2): an
            unusable script is a DRIVER error, not a script-level
            [Serror]. It goes to stderr (stdout is the hook protocol's
            channel and must carry only a rendered decision), and its
            exit code stays the literal 1, OUTSIDE the [--serror-exit]
            mapping: a fail-open install (`--serror-exit 0`) must not
            turn a renamed, misdirected or unreadable guard script into
            a silent exit 0 with a junk line on the decision channel. *)
         prerr_endline (path ^ ": " ^ Tot_surface.Source.message e);
         1)
       ~ok:(fun (src : string) ->
         Tot_surface.Run.script ~st ~policy ~exec src
         |> Result.fold
              ~ok:(fun (lines, exit_code) ->
                List.iter print_endline lines;
                (* M3 Stage B: a script's `main : IO Unit` epilogue (or,
                   M3 Stage D, `IO Verdict`) may request an exit code via
                   `exitWith`; absent that (or absent a `main` at all,
                   every M2 script), 0. *)
                Option.value exit_code ~default:0)
              ~error:(fun e ->
                (* M3 fixes, B4: a runtime script error's message goes to
                   STDERR (stdout is the hook protocol's channel and must
                   carry only a rendered decision). M4 Stage D, D5.1: the
                   exit code is `--serror-exit`'s configured value,
                   default 1 (user decision 4; the flip to 3 is a later,
                   separate change). *)
                prerr_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
                serror_exit))

(** The prelude-auto-loaded path: classify the prelude PATH, bootstrap
    once from the bytes that precheck already read, report a bootstrap
    failure (a hand-broken `stdlib/prelude.tot`, ...) the same way any
    other script error is reported (M3 fixes round 2: on STDERR, the B4
    channel rule; stdout carries only a rendered decision), then run the
    target file against that state.

    M4 fixes round 3 (opus R3-2): an unusable prelude PATH is a
    DRIVER-level verdict about the installation, exactly like an
    unusable target path, so it takes the target's contract and not the
    script-error one: one line on stderr, stdout untouched, and the
    literal exit 1, OUTSIDE the [--serror-exit] mapping. Round 2 routed
    all four cases through [serror_exit], so a fail-open install
    (`--serror-exit 0`) turned a misdirected [TOT_PRELUDE] into a silent
    allow -- the very failure round 2's own log argued must not happen.
    A directory and an unreadable file additionally escaped as an OCaml
    crash dump at exit 2, and a FIFO did not exit at all. The precheck
    also hands its bytes to [cached_state_of_src], so the prelude is
    still read exactly ONCE per invocation. A prelude whose CONTENT is
    broken is a different verdict and keeps the [serror_exit] mapping,
    unchanged.

    M4 fixes round 4 (opus R4-2): the "exactly ONCE" sentence above was
    FALSE on every cache miss until round 4. Round 3's split reached
    the cache KEY only; the miss branch called [Bootstrap.state ()],
    which read the path a second time, and that second read's failure
    is a [Serror] INSIDE the [--serror-exit] mapping. A prelude removed
    between the two reads therefore exited 0 under [--serror-exit 0],
    reproduced 12 times out of 12, which is the very fail-open this
    docstring claims to have closed. [Bootstrap.state_of_src] now
    elaborates the precheck's own bytes, so the sentence holds and the
    prelude cache cannot be keyed on bytes other than the ones
    elaborated. PASS-D-PRELUDE-VANISH pins the driver contract for a
    prelude that disappears mid-run. *)
let run_with_prelude ~(exec : bool) ~(policy : Tot_surface.Run.policy) ~(serror_exit : int)
    (path : string) : int =
  Tot_surface.Bootstrap.prelude_source ()
  |> Result.fold
       ~error:(fun ((ppath, e) : string * Tot_surface.Source.error) ->
         prerr_endline ("prelude: " ^ ppath ^ ": " ^ Tot_surface.Source.message e);
         1)
       ~ok:(fun (src : string) ->
         Tot_surface.Bootstrap.cached_state_of_src src
         |> Result.fold
              ~ok:(fun st -> run_file ~exec ~policy ~serror_exit ~st path)
              ~error:(fun e ->
                prerr_endline ("prelude: " ^ Tot_surface.Serror.to_string e);
                serror_exit))

let run_no_prelude ~(exec : bool) ~(policy : Tot_surface.Run.policy) ~(serror_exit : int)
    (path : string) : int =
  run_file ~exec ~policy ~serror_exit ~st:Tot_surface.Run.initial path

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

(** M4 Stage B: the driver's flag set. The pre-B5 argv handling was a
    literal positional match, which cannot absorb a second optional
    flag without a combinatorial blow-up (four literal shapes per verb
    for two independent flags); replaced by the small total parser
    below. *)
type opts = {
  no_prelude : bool;
  no_axioms : bool;
  serror_exit : int;
      (** M4 Stage D, D5.1 (user decision 4): the exit code a script-level
          [Serror] returns. Default 1; the flip to 3 is a later, separate
          change made only after installed guards are migrated. *)
  require_main : bool;
      (** M4 Stage D, D5.2: reject a script with no "main" def. *)
}

let default_opts : opts = { no_prelude = false; no_axioms = false; serror_exit = 1; require_main = false }

let usage : string =
  "usage: tot (check|run) [--no-prelude] [--no-axioms] [--serror-exit N] [--require-main] \
   FILE | tot prims"

(** Consume leading flags; the first non-flag argument ends the scan. A
    leading "--" that is not a known flag is an error, so a typo can
    never be read as a file name. The [String.length a >= 2] guard on
    the same line as [String.sub a 0 2] establishes its precondition
    (0 + 2 <= length), so the slice is total. *)
let rec parse_flags (opts : opts) (args : string list) : (opts * string list, string) result =
  match args with
  | "--no-prelude" :: rest -> parse_flags { opts with no_prelude = true } rest
  | "--no-axioms" :: rest -> parse_flags { opts with no_axioms = true } rest
  | "--require-main" :: rest -> parse_flags { opts with require_main = true } rest
  | "--serror-exit" :: n :: rest ->
      int_of_string_opt n
      |> Option.fold
           ~none:(Error ("--serror-exit expects an integer 0..255, got " ^ n))
           ~some:(fun v ->
             match () with
             | () when v < 0 || v > 255 -> Error ("--serror-exit out of range 0..255: " ^ n)
             | () -> parse_flags { opts with serror_exit = v } rest)
  | [ "--serror-exit" ] -> Error "--serror-exit expects an integer argument"
  | a :: _rest when String.length a >= 2 && String.equal (String.sub a 0 2) "--" (* @total-accessor *) ->
      Error ("unknown flag: " ^ a)
  | ([] | _ :: _) -> Ok (opts, args)

let dispatch ~(exec : bool) (opts : opts) (path : string) : int =
  let policy : Tot_surface.Run.policy =
    { Tot_surface.Run.no_axioms = opts.no_axioms; require_main = opts.require_main }
  in
  if opts.no_prelude then run_no_prelude ~exec ~policy ~serror_exit:opts.serror_exit path
  else run_with_prelude ~exec ~policy ~serror_exit:opts.serror_exit path

(** [rest]'s flags, then exactly one positional path; any other shape
    (a stray-flag error, zero paths, or more than one) is the same
    exit-2 usage message the pre-B5 positional match gave for every
    malformed invocation. *)
let check_or_run ~(exec : bool) (rest : string list) : int =
  (* M4 fixes round 1 (audit F2): flag and usage errors are driver
     errors, so they go to STDERR too; stdout carries only a rendered
     decision. *)
  parse_flags default_opts rest
  |> Result.fold
       ~error:(fun msg ->
         prerr_endline msg;
         2)
       ~ok:(fun (opts, paths) ->
         match paths with
         | [ path ] -> dispatch ~exec opts path
         | [] | _ :: _ :: _ ->
             prerr_endline usage;
             2)

let () =
  match Array.to_list Sys.argv with
  | _exe :: "check" :: rest -> Stdlib.exit (check_or_run ~exec:false rest)
  | _exe :: "run" :: rest -> Stdlib.exit (check_or_run ~exec:true rest)
  | _exe :: "prims" :: [] -> Stdlib.exit (print_prims ())
  | [] | [ _ ] | _ :: _ :: _ ->
      prerr_endline usage;
      Stdlib.exit 2
