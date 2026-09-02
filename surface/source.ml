(** Reading a path as SOURCE text, totally.

    M4 fixes round 3 (opus R3-2): the classification, the messages and
    the read used to live in [bin/tot.ml] and covered the TARGET file
    only, so [surface/bootstrap.ml]'s prelude read (reached on every
    ordinary check/run, and pointed anywhere the operator likes by
    [TOT_PRELUDE]) kept the pre-round-2 behaviour: an OCaml crash dump
    and exit 2 for a directory or an unreadable file, no exit at all for
    a FIFO, and a fail-open exit 0 for a missing path under
    [--serror-exit 0]. This module is that precheck, lifted to a place
    BOTH readers can use, so the two paths cannot drift again.

    Nothing here raises and nothing here blocks. *)

(** Why a path yields no source. Every one of these is reachable by an
    install that points a flag or [TOT_PRELUDE] at the wrong path; none
    of them is a race. *)
type error = Missing | Not_regular | Unreadable

let message (e : error) : string =
  match e with
  | Missing -> "no such file"
  | Not_regular -> "not a regular file"
  | Unreadable -> "cannot be read"

(** [Sys.is_regular_file] raises [Sys_error] when the path vanishes
    between the existence test and this one, so the exception pattern
    (the same total-wrapper idiom as [surface/effect.ml]'s
    [Unix.openfile] guards) turns that race into "not a regular file",
    which routes to the same clean exit 1. It stats, never opens, so a
    FIFO is classified without blocking on a writer.

    M4 fixes round 3 (opus R3-4): rejecting every non-regular file, not
    only a writer-less FIFO, is DELIBERATE and is now a documented
    contract (SPEC.md section 5, README.md): a hook is handed real
    files, and a target that can block the checker forever is the worse
    failure. It does cost [tot check <(gen)] and a PIPE-backed
    [tot check /dev/stdin], which round 1 read correctly. [message]
    names the requirement ("not a regular file") so the rejection is
    self-explaining.

    M4 fixes round 4 (opus R4-4): the sentence above used to say
    [/dev/stdin] outright, which overstates what this does. The
    classification follows the TRUE stat, so it rejects the PIPE and
    not the spelling: [tot check /dev/stdin < script.tot] has fd 0
    pointing at a regular file, [Sys.is_regular_file] follows through
    to it, and the check is ACCEPTED (executed: exit 0 with the normal
    rendered decision, against exit 1 and "not a regular file" for
    [cat script.tot | tot check /dev/stdin] and for
    [tot check <(cat script.tot)]). That is the same reason a symlink
    to a regular file is accepted, and it is the behaviour we want; the
    code is right and only the two documentation sentences (SPEC.md
    section 5, README.md) were wrong. *)
let is_regular_file (path : string) : bool =
  match Sys.is_regular_file path with exception Sys_error _ -> false | b -> b

(** Total: every failure to obtain the source is an [error], never a
    raise and never a block. Classifies BEFORE opening, so the FIFO
    case never reaches a blocking [open]; the single residual raise (a
    file that loses its read bit between the stat and the open) is
    converted at that one stdlib boundary and becomes [Unreadable]. *)
let read (path : string) : (string, error) result =
  match () with
  | () when not (Sys.file_exists path) -> Error Missing
  | () when not (is_regular_file path) -> Error Not_regular
  | () -> (
      match In_channel.with_open_text path In_channel.input_all with
      | exception Sys_error _ -> Error Unreadable
      | src -> Ok src)
