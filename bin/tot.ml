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

(** M5 Stage C (pin 8): the driver's half of the budget.  CPU seconds,
    from [Sys.time], not wall clock: a checker that is descheduled has
    not spent its budget, and CPU time cannot walk backwards when the
    system clock is set.

    The counter is why the poll is driver-supplied.  A clock read per
    kernel node would show up in the default path's own timing, and the
    default path must stay byte-identical AND fast (PASS-M5C-DETERMINISM).
    One read per 1024 polls bounds the overshoot at 1024 nodes, which is
    far inside the granularity this cutoff promises.  The mutable cell
    is legal here and is not legal in `lib/`, which is pin 8's whole
    point.

    [ms = 0] returns [Budget.unlimited], so the default configuration
    never allocates a counter, never reads a clock and never changes a
    verdict. *)
let budget_of_ms (ms : int) : Tot_kernel.Budget.t =
  match () with
  | () when ms <= 0 -> Tot_kernel.Budget.unlimited
  | () ->
      let deadline = Sys.time () +. (float_of_int ms /. 1000.0) in
      let ticks = ref 0 in
      Tot_kernel.Budget.of_poll (fun () ->
          ticks := !ticks + 1;
          match () with
          | () when not (Int.equal (!ticks land 1023) 0) -> false
          | () -> Float.compare (Sys.time ()) deadline > 0)

let run_file ~(exec : bool) ~(policy : Tot_surface.Run.policy) ~(serror_exit : int)
    ~(budget : Tot_kernel.Budget.t) ~(budget_ms : int) ~(st : Tot_surface.Run.state)
    (path : string) : int =
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
         Tot_surface.Run.script ~st ~policy ~budget ~exec src
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
                   separate change). M5 Stage A (pin 20): the one
                   [Serror.driver_exit] error, a strict-json refusal on
                   an IO Unit script, takes the DRIVER contract's
                   literal 1 instead, OUTSIDE the mapping, so a
                   fail-open install (--serror-exit 0) cannot turn the
                   refusal into a silent allow. M5 Stage C: two more
                   arms OUTSIDE the mapping. Budget exhaustion (pins 10
                   and 19) exits the reserved 3 with ONE exact stderr
                   line naming the CONFIGURED milliseconds; the LINE,
                   not the code, is the discriminator, because a script
                   can exit any 0..255 via exitWith and --serror-exit 3
                   is a shipped configuration. A mainless target under
                   --require-main (pin 21, amendment A3) takes the
                   missing-file contract: the UNCHANGED Serror text
                   with the tight ":" separator and the literal exit 1,
                   so a fail-open install cannot read a mainless guard
                   as allow. *)
                match () with
                | () when Tot_surface.Serror.is_check_budget e ->
                    prerr_endline
                      (path ^ ": check budget exhausted (" ^ string_of_int budget_ms ^ " ms)");
                    3
                | () when Tot_surface.Serror.is_missing_main e ->
                    prerr_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
                    1
                | () when Tot_surface.Serror.driver_exit e ->
                    prerr_endline (path ^ ":" ^ Tot_surface.Serror.to_string e);
                    1
                | () ->
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
    ~(check_budget_ms : int) (path : string) : int =
  Tot_surface.Bootstrap.prelude_source ()
  |> Result.fold
       ~error:(fun ((ppath, e) : string * Tot_surface.Source.error) ->
         prerr_endline ("prelude: " ^ ppath ^ ": " ^ Tot_surface.Source.message e);
         1)
       ~ok:(fun (src : string) ->
         Tot_surface.Bootstrap.cached_state_of_src src
         |> Result.fold
              ~ok:(fun st ->
                (* M5 Stage C: the deadline is captured HERE, after
                   [cached_state_of_src] returned, never at process
                   start.  A warm bootstrap costs about 10 ms of CPU on
                   the measured machine, so a deadline captured earlier
                   would be spent before the target's first node under
                   any budget under 10 ms (PASS-M5C-BUDGET-QUIET leg
                   (b) pins it). *)
                run_file ~exec ~policy ~serror_exit
                  ~budget:(budget_of_ms check_budget_ms) ~budget_ms:check_budget_ms ~st
                  path)
              ~error:(fun e ->
                prerr_endline ("prelude: " ^ Tot_surface.Serror.to_string e);
                serror_exit))

let run_no_prelude ~(exec : bool) ~(policy : Tot_surface.Run.policy) ~(serror_exit : int)
    ~(check_budget_ms : int) (path : string) : int =
  run_file ~exec ~policy ~serror_exit ~budget:(budget_of_ms check_budget_ms)
    ~budget_ms:check_budget_ms ~st:Tot_surface.Run.initial path

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
  strict_json : bool;
      (** M5 Stage A (pin 20): deny a stdin payload that is not one
          well-formed JSON value instead of falling open to allow.
          Travels as [Run.policy.strict_json], enforced at
          [Effect.dispatch]'s [readStdin] arm. *)
  check_budget_ms : int;
      (** M5 Stage C (pins 8, 11): the check budget in CPU
          milliseconds.  Default 0, which is OFF: no counter, no clock
          read, verdicts byte-identical.  Applies to `check` and to
          `run`, covering elaboration and type-checking only, never
          [Interp] execution (decision 13's external `timeout` stays
          the belt there). *)
  experimental_wf : bool;
      (** M5 Stage E (SPIKE): run the PROTOTYPE accessibility clause in
          [Totality] instead of the shipped structural rule.  Default
          false.  The prototype is known to be too permissive; it exists
          to be measured, not to be relied on. *)
}

let default_opts : opts =
  {
    no_prelude = false;
    no_axioms = false;
    serror_exit = 1;
    require_main = false;
    strict_json = false;
    check_budget_ms = 0;
    experimental_wf = false;
  }

let usage : string =
  "usage: tot (check|run) [--no-prelude] [--no-axioms] [--serror-exit N] \
   [--check-budget-ms N] [--require-main] [--experimental-wf] [--strict-json] FILE | tot \
   prims"

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
  | "--experimental-wf" :: rest -> parse_flags { opts with experimental_wf = true } rest
  | "--strict-json" :: rest -> parse_flags { opts with strict_json = true } rest
  | "--serror-exit" :: n :: rest ->
      int_of_string_opt n
      |> Option.fold
           ~none:(Error ("--serror-exit expects an integer 0..255, got " ^ n))
           ~some:(fun v ->
             match () with
             | () when v < 0 || v > 255 -> Error ("--serror-exit out of range 0..255: " ^ n)
             | () -> parse_flags { opts with serror_exit = v } rest)
  | [ "--serror-exit" ] -> Error "--serror-exit expects an integer argument"
  | "--check-budget-ms" :: n :: rest ->
      int_of_string_opt n
      |> Option.fold
           ~none:(Error ("--check-budget-ms expects a non-negative integer, got " ^ n))
           ~some:(fun v ->
             match () with
             | () when v < 0 -> Error ("--check-budget-ms must be 0 or greater, got " ^ n)
             | () -> parse_flags { opts with check_budget_ms = v } rest)
  | [ "--check-budget-ms" ] -> Error "--check-budget-ms expects an integer argument"
  | a :: _rest when String.length a >= 2 && String.equal (String.sub a 0 2) "--" (* @total-accessor *) ->
      Error ("unknown flag: " ^ a)
  | ([] | _ :: _) -> Ok (opts, args)

let dispatch ~(exec : bool) (opts : opts) (path : string) : int =
  let policy : Tot_surface.Run.policy =
    {
      Tot_surface.Run.no_axioms = opts.no_axioms;
      require_main = opts.require_main;
      strict_json = opts.strict_json;
      wf_rule =
        (if opts.experimental_wf then Tot_kernel.Totality.Structural_wf
         else Tot_kernel.Totality.Structural);
    }
  in
  if opts.no_prelude then
    run_no_prelude ~exec ~policy ~serror_exit:opts.serror_exit
      ~check_budget_ms:opts.check_budget_ms path
  else
    run_with_prelude ~exec ~policy ~serror_exit:opts.serror_exit
      ~check_budget_ms:opts.check_budget_ms path

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
