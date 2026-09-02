(** M3 Stage B: the one module in the whole tree that calls [In_channel]
    stdin reads, [print_endline], [Sys.getenv_opt] or any other OS
    primitive. Every raw host call gets ONE documented fence matching
    NAMED exceptions only (never a bare [with _], which would also
    swallow [Out_of_memory]/[Stack_overflow]/[Sys.Break]; M3 fixes
    round 2, ctxcat id 13) converting a host failure into a tot-level
    value; this is the same host-boundary posture the SPEC already
    records for the CLI's own (unguarded) file-open race, not a new
    kind of debt. This module never crosses into [Check], [Eval],
    [Erase] or [Totality]: those stay pure, exactly as before this
    stage. *)

open Tot_kernel

let ( let* ) = Result.bind

(** The result of walking one [Interp.io_action] to completion: either
    it produced an ordinary value, or an [exitWith] inside it short
    circuited the whole walk with a process exit code. *)
type outcome =
  | Done of Interp.v
  | Exited of int

(* ---- procRun host helpers (M3 fixes, B3: C8 + C16 + C9) ---- *)

(** Close a descriptor, tolerating a host refusal: a double close or a
    stale fd must never cross the boundary as an exception. *)
let close_quiet (fd : Unix.file_descr) : unit =
  match Unix.close fd with exception Unix.Unix_error (_, _, _) -> () | () -> ()

(** Best-effort unlink for a capture temp file. *)
let remove_quiet (path : string) : unit =
  match Sys.remove path with exception Sys_error _ -> () | () -> ()

(** One capture temp file; [Error ()] is the caller's cannot-exec
    sentinel, never an exception. *)
let temp_capture (tag : string) : (string, unit) result =
  match Filename.temp_file ("tot-proc-" ^ tag) ".cap" with
  | exception Sys_error _ -> Error ()
  | path -> Ok path

let open_write (path : string) : (Unix.file_descr, unit) result =
  match Unix.openfile path [ Unix.O_WRONLY; Unix.O_TRUNC ] 0o600 with
  | exception Unix.Unix_error (_, _, _) -> Error ()
  | fd -> Ok fd

let open_dev_null () : (Unix.file_descr, unit) result =
  match Unix.openfile "/dev/null" [ Unix.O_RDONLY ] 0 with
  | exception Unix.Unix_error (_, _, _) -> Error ()
  | fd -> Ok fd

(** Read a capture file back whole; a read failure degrades to "". *)
let read_back (path : string) : string =
  match In_channel.with_open_bin path In_channel.input_all with
  | exception Sys_error _ -> ""
  | s -> s

(** [Unix.WSIGNALED]'s payload uses OCaml's own signal encoding (the
    negative [Sys.sig*] constants) for the signals OCaml knows; map
    those back to the HOST numbers (Darwin's, the numbering the
    calling shell's own `kill -l` and `128+signo` convention use on
    this machine) and pass an already-positive unknown signal number
    through unchanged. The final arm is a total backstop for a
    negative encoding outside the [Sys] constants (unreachable). *)
let host_signal_number (n : int) : int =
  match () with
  | () when n > 0 -> n
  | () when Int.equal n Sys.sighup -> 1
  | () when Int.equal n Sys.sigint -> 2
  | () when Int.equal n Sys.sigquit -> 3
  | () when Int.equal n Sys.sigill -> 4
  | () when Int.equal n Sys.sigtrap -> 5
  | () when Int.equal n Sys.sigabrt -> 6
  | () when Int.equal n Sys.sigfpe -> 8
  | () when Int.equal n Sys.sigkill -> 9
  | () when Int.equal n Sys.sigbus -> 10
  | () when Int.equal n Sys.sigsegv -> 11
  | () when Int.equal n Sys.sigsys -> 12
  | () when Int.equal n Sys.sigpipe -> 13
  | () when Int.equal n Sys.sigalrm -> 14
  | () when Int.equal n Sys.sigterm -> 15
  | () when Int.equal n Sys.sigurg -> 16
  | () when Int.equal n Sys.sigstop -> 17
  | () when Int.equal n Sys.sigtstp -> 18
  | () when Int.equal n Sys.sigcont -> 19
  | () when Int.equal n Sys.sigchld -> 20
  | () when Int.equal n Sys.sigttin -> 21
  | () when Int.equal n Sys.sigttou -> 22
  | () when Int.equal n Sys.sigpoll -> 23
  | () when Int.equal n Sys.sigxcpu -> 24
  | () when Int.equal n Sys.sigxfsz -> 25
  | () when Int.equal n Sys.sigvtalrm -> 26
  | () when Int.equal n Sys.sigprof -> 27
  | () when Int.equal n Sys.sigusr1 -> 30
  | () when Int.equal n Sys.sigusr2 -> 31
  | () -> 0

(** Wait until the child actually TERMINATES (M3 fixes, B3/C9). A
    signaled child maps to the shell convention 128+signo (host
    numbering, [host_signal_number]); a STOPPED child is waited on
    again rather than misread as an exit ([Unix.WSTOPPED] is
    unreachable with no [WUNTRACED] flag, but the arm is honest now);
    an interrupted wait retries; any other [waitpid] host failure
    degrades to the cannot-tell sentinel -1, matching the spawn
    sentinel below. *)
let rec wait_exit_code (pid : int) : int =
  match Unix.waitpid [] pid with
  | exception Unix.Unix_error (Unix.EINTR, _, _) -> wait_exit_code pid
  | exception Unix.Unix_error (_, _, _) -> -1
  | _pid, Unix.WEXITED n -> n
  | _pid, Unix.WSIGNALED n -> 128 + host_signal_number n
  | _pid, Unix.WSTOPPED _ -> wait_exit_code pid

(** Coerce a runtime value EXPECTED to be a reified IO action (an
    [IOBind]'s inner action value, or the already-forced top-level value
    [surface/run.ml]'s [main] epilogue hands in) into its [io_action]
    payload. A checked program of type [IO _] always evaluates to a
    [Interp.VIOAction]; a mismatch here is a total backstop, never
    reachable on a checked program. *)
let require_action (v : Interp.v) : (Interp.io_action, Error.t) result =
  match v with
  | Interp.VIOAction a -> Ok a
  | Interp.VClos (_, _, _) | Interp.VCon (_, _) | Interp.VNeut (_, _) | Interp.VErased
  | Interp.VLit _ | Interp.VPrim (_, _) ->
      Error (Error.Mismatch { expected = "IO action"; actual = "<not an io action>" })

(** Walk a reified action tree, firing each native step through
    [dispatch] in order. [IOBind]'s continuation [k] runs only when the
    inner action produced an ordinary value; an [Exited] short circuits
    the whole walk, so [k] never runs after an [exitWith] (matching the
    epilogue's own "explicit exitWith wins" rule, Stage D D4). *)
let rec run_io (eglobals : Interp.globals) (action : Interp.io_action) :
    (outcome, Error.t) result =
  match action with
  | Interp.IOPure v -> Ok (Done v)
  | Interp.IOBind (m, k) ->
      let* mv = require_action m in
      let* inner = run_io eglobals mv in
      (match inner with
      | Exited c -> Ok (Exited c)
      | Done rv ->
          let* kv = Interp.apply eglobals k rv in
          let* kv_action = require_action kv in
          run_io eglobals kv_action)
  | Interp.IONative (prim, args) -> dispatch eglobals prim args

(** Fire one native effect prim on its (already fully applied) argument
    values. [eglobals] is unused by every Stage B case (none of the
    four OS prims needs to look anything up); kept in the signature so
    later stages' natives (e.g. [procRun]) can use it without a
    signature change. *)
and dispatch (_eglobals : Interp.globals) (prim : Prim.t) (args : Interp.v list) :
    (outcome, Error.t) result =
  let describe (a : Interp.v) : string =
    match a with
    | Interp.VLit (Literal.LString _) -> "String"
    | Interp.VLit (Literal.LInt _) -> "Int"
    | Interp.VClos (_, _, _) -> "<function>"
    | Interp.VCon (c, _) -> c
    | Interp.VNeut (_, _) -> "<neutral>"
    | Interp.VErased -> "<erased>"
    | Interp.VPrim (p, _) -> Prim.name p
    | Interp.VIOAction _ -> "<io action>"
  in
  let str_arg (a : Interp.v) : (string, Error.t) result =
    match a with
    | Interp.VLit (Literal.LString s) -> Ok s
    | Interp.VLit (Literal.LInt _) | Interp.VClos (_, _, _) | Interp.VCon (_, _)
    | Interp.VNeut (_, _) | Interp.VErased | Interp.VPrim (_, _) | Interp.VIOAction _ ->
        Error (Error.Mismatch { expected = "String"; actual = describe a })
  in
  let int_arg (a : Interp.v) : (int, Error.t) result =
    match a with
    | Interp.VLit (Literal.LInt n) -> Ok n
    | Interp.VLit (Literal.LString _) | Interp.VClos (_, _, _) | Interp.VCon (_, _)
    | Interp.VNeut (_, _) | Interp.VErased | Interp.VPrim (_, _) | Interp.VIOAction _ ->
        Error (Error.Mismatch { expected = "Int"; actual = describe a })
  in
  (* M3 Stage C: [procRun]'s second argument, a runtime [List String]
     spine. Total: an unknown ctor name (["cons"]/["nil"] are the
     prelude's own) cannot occur on a checked program; a total
     backstop only. *)
  let rec str_list_arg (a : Interp.v) : (string list, Error.t) result =
    match a with
    | Interp.VCon ("nil", []) -> Ok []
    | Interp.VCon ("cons", [ hd; tl ]) ->
        let* h = str_arg hd in
        let* t = str_list_arg tl in
        Ok (h :: t)
    | ( Interp.VCon (_, _) | Interp.VClos (_, _, _) | Interp.VNeut (_, _) | Interp.VErased
      | Interp.VLit _ | Interp.VPrim (_, _) | Interp.VIOAction _ ) ->
        Error (Error.Mismatch { expected = "List String"; actual = describe a })
  in
  match (prim, args) with
  | Prim.Read_stdin, [] ->
      (* the one raw stdin read in the tree; a host failure ([Sys_error],
         the one exception [In_channel.input_all] is documented to
         raise) reads as the empty string rather than crossing into a
         tot-level error (M3 fixes round 2, ctxcat id 13: named, never
         a bare [with _]) *)
      let s = match In_channel.input_all stdin with exception Sys_error _ -> "" | s -> s in
      Ok (Done (Interp.VLit (Literal.LString s)))
  | Prim.Print_line, [ a ] ->
      let* s = str_arg a in
      (* the one raw stdout write; a host failure ([Sys_error], e.g. a
         broken pipe) is swallowed, since IO Unit has no channel to
         report it on (M3 fixes round 2, ctxcat id 13: named, never a
         bare [with _]). The [flush] rides INSIDE the fence (round 3,
         ctxcat id 11): [print_endline] alone only buffers, so a
         broken-pipe [Sys_error] would otherwise surface at the
         at_exit flush, OUTSIDE any handler, and crash the process --
         the exact outcome this fence exists to prevent. *)
      let () =
        match
          print_endline s;
          flush stdout
        with
        | exception Sys_error _ -> ()
        | () -> ()
      in
      Ok (Done (Interp.VCon ("unit", [])))
  | Prim.Exit_with, [ a ] ->
      let* n = int_arg a in
      (* M3 fixes, B4 (C10): the OS truncates an exit code to its low
         8 bits, and the exit code is the hook protocol's whole
         vocabulary, so a code outside 0..255 is a runtime script
         error, never a silent wrap. *)
      if n >= 0 && n <= 255 then Ok (Exited n) else Error (Error.Exit_code_out_of_range n)
  | Prim.Get_env, [ a ] ->
      let* name = str_arg a in
      (* [Sys.getenv_opt] is documented total (it never raises), so no
         try/with fence is needed here; the other three natives above
         each carry their own *)
      Sys.getenv_opt name
      |> Option.fold
           ~none:(Ok (Done (Interp.VCon ("none", []))))
           ~some:(fun v -> Ok (Done (Interp.VCon ("some", [ Interp.VLit (Literal.LString v) ]))))
  (* M3 Stage C: readFile/writeFile/procRun each guard their raw host
     call with ONE documented try/with, matching NAMED exceptions
     only (never a bare `with _`), converting a host failure into a
     tot-level value rather than crossing the boundary as an
     exception -- the same posture this module already takes above. *)
  | Prim.Read_file, [ a ] ->
      let* path = str_arg a in
      let outcome =
        match In_channel.with_open_text path In_channel.input_all with
        | exception Sys_error _ -> Error ()
        | content -> Ok content
      in
      let result_v =
        outcome
        |> Result.fold
             ~ok:(fun content -> Interp.VCon ("ok", [ Interp.VLit (Literal.LString content) ]))
             ~error:(fun () ->
               Interp.VCon
                 ("err", [ Interp.VLit (Literal.LString ("cannot read file: " ^ path)) ]))
      in
      Ok (Done result_v)
  | Prim.Write_file, [ a; b ] ->
      let* path = str_arg a in
      let* content = str_arg b in
      let outcome =
        match Out_channel.with_open_text path (fun oc -> Out_channel.output_string oc content) with
        | exception Sys_error _ -> Error ()
        | () -> Ok ()
      in
      let result_v =
        outcome
        |> Result.fold
             ~ok:(fun () -> Interp.VCon ("ok", [ Interp.VCon ("unit", []) ]))
             ~error:(fun () ->
               Interp.VCon
                 ("err", [ Interp.VLit (Literal.LString ("cannot write file: " ^ path)) ]))
      in
      Ok (Done result_v)
  | Prim.Argv, [] ->
      let list_v =
        List.fold_right
          (fun a acc -> Interp.VCon ("cons", [ Interp.VLit (Literal.LString a); acc ]))
          (Array.to_list Sys.argv) (Interp.VCon ("nil", []))
      in
      Ok (Done list_v)
  | Prim.Proc_run, [ cmd_v; args_v ] ->
      let* cmd = str_arg cmd_v in
      let* cmd_args = str_list_arg args_v in
      (* M3 fixes, B3 (C8 + C16 + C9): temp-FILE capture, not pipes.
         The child writes stdout and stderr into two temp files, so a
         child that emits more than any OS pipe buffer can never
         deadlock a sequential drain (C16), and EVERY parent-held
         descriptor is closed immediately after the spawn decision,
         on the success AND failure paths alike (C8), with both
         capture files unlinked on both paths too. Each raising host
         call is fenced by name in the helpers above; [Error ()] all
         the way down here means the cannot-exec sentinel triple. *)
      let spawn_in (tmp_out : string) (tmp_err : string) : (int, unit) result =
        let* out_fd = open_write tmp_out in
        let* err_fd = open_write tmp_err |> Result.map_error (fun () -> close_quiet out_fd) in
        let* dev_null =
          open_dev_null ()
          |> Result.map_error (fun () ->
                 close_quiet out_fd;
                 close_quiet err_fd)
        in
        let child_argv = Array.of_list (cmd :: cmd_args) in
        let pid_r =
          match Unix.create_process cmd child_argv dev_null out_fd err_fd with
          | exception Unix.Unix_error (_, _, _) -> Error ()
          | pid -> Ok pid
        in
        let () = close_quiet out_fd in
        let () = close_quiet err_fd in
        let () = close_quiet dev_null in
        Result.map wait_exit_code pid_r
      in
      let captured : (int * string * string, unit) result =
        let* tmp_out = temp_capture "out" in
        let* tmp_err = temp_capture "err" |> Result.map_error (fun () -> remove_quiet tmp_out) in
        let code_r = spawn_in tmp_out tmp_err in
        let out = read_back tmp_out in
        let err = read_back tmp_err in
        let () = remove_quiet tmp_out in
        let () = remove_quiet tmp_err in
        Result.map (fun code -> (code, out, err)) code_r
      in
      let code, out, err =
        captured
        |> Result.fold ~ok:Fun.id ~error:(fun () ->
               (-1, "", Printf.sprintf "tot: cannot exec %s" cmd))
      in
      Ok
        (Done
           (Interp.VCon
              ( "mkProcessResult",
                [
                  Interp.VLit (Literal.LInt code);
                  Interp.VLit (Literal.LString out);
                  Interp.VLit (Literal.LString err);
                ] )))
  | ( ( Prim.String_concat | Prim.String_length | Prim.String_eq | Prim.String_contains
      | Prim.Int_add | Prim.Int_sub | Prim.Int_eq | Prim.Int_to_string | Prim.Pure_div
      | Prim.Bind_div | Prim.Pure_io | Prim.Bind_io | Prim.Lift_io | Prim.Read_stdin
      | Prim.Print_line | Prim.Exit_with | Prim.Get_env | Prim.String_slice
      | Prim.String_split | Prim.String_to_int | Prim.Int_compare | Prim.Read_file
      | Prim.Write_file | Prim.Argv | Prim.Proc_run | Prim.Json_parse | Prim.Json_serialize
      | Prim.Regex_test | Prim.Regex_match ),
      _ ) ->
      (* unreachable on a checked program: the Tot/Div prims and
         pureIO/bindIO/liftIO never reach dispatch at all (Interp's
         fire_prim handles them inline, never building an IONative
         node for them), and the four native prims' arg list SHAPE was
         already fixed to their catalog arity when fire_prim built this
         IONative node; a total backstop only. *)
      Error
        (Error.Prim_arity
           { prim = Prim.name prim; expected = Prim.arity prim; found = List.length args })

(** M3 Stage D, D4: render a checked [main : IO Verdict]'s already-
    computed outcome VALUE (never called on an unevaluated action) into
    the driver's envelope line and OS exit code, confirmed user
    decision 3: [allow] is exit 0 with nothing printed; [ask msg] and
    [deny msg] each print ONE line, the JSON envelope below, with no
    trailing spaces, and exit 1 or 2 respectively. [surface/run.ml]'s
    epilogue calls this ONLY on the [Done] half of a [run_io] outcome:
    an [Exited] outcome (an explicit [exitWith] reached first) short
    circuits before ever reaching a [Verdict] value at all, so it never
    calls this function -- see [Run.run_verdict_main]. [Pp.escape_string]
    (Stage A's shared string escaper, reused here exactly as its own
    doc comment anticipates) both quotes and escapes [msg]. A [VCon]
    head other than these three is a total backstop: a checked
    [IO Verdict] program cannot reach it. *)
let render_verdict (v : Interp.v) : (string option * int, Error.t) result =
  let envelope (decision : string) (msg : string) : string =
    Printf.sprintf
      "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"%s\",\"permissionDecisionReason\":%s}}"
      decision (Pp.escape_string msg)
  in
  match v with
  | Interp.VCon ("allow", []) -> Ok (None, 0)
  | Interp.VCon ("ask", [ Interp.VLit (Literal.LString msg) ]) -> Ok (Some (envelope "ask" msg), 1)
  | Interp.VCon ("deny", [ Interp.VLit (Literal.LString msg) ]) ->
      Ok (Some (envelope "deny" msg), 2)
  | ( Interp.VCon (_, _) | Interp.VClos (_, _, _) | Interp.VNeut (_, _) | Interp.VErased
    | Interp.VLit _ | Interp.VPrim (_, _) | Interp.VIOAction _ ) ->
      Error (Error.Mismatch { expected = "Verdict"; actual = "<not a checked Verdict value>" })
