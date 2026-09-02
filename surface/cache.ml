(** M3 Stage D, D2: an on-disk cache for the bootstrapped prelude
    environment, so `tot`'s startup does not re-lex, re-parse,
    re-elaborate and re-check `stdlib/prelude.tot` on every invocation.

    Key: [Digest.string] (MD5; total, never raises) of the prelude
    SOURCE BYTES concatenated with this module's own compiled-in
    [format_version] AND the MD5 digest of the RUNNING BINARY's own
    contents ([exe_digest_hex]; M3 fixes round 2, R1;  restored in M4
    fixes round 1 after Stage D's D5.3 had weakened it to a [Unix.stat]
    digest, which is metadata and therefore forgeable: an audit produced
    two byte-different binaries sharing one inode, size and mtime, and
    the second one LOADED the first one's blob.  The stat fields survive
    only as the memo KEY of a fast path that skips re-hashing, never as
    the identity itself;  see [exe_digest_hex]).  The binary
    digest is the load-bearing fence: the round-2 re-probe proved that
    [format_version] alone cannot detect layout drift (two binaries
    sharing a version but differing in one marshaled payload type
    produced a silently wrong prelude one way and a SIGSEGV the other),
    because the version is part of the KEY, so the file a mismatched
    binary opens always carries a matching version field, and the body
    digest is computed by the WRITER, so any self-consistent blob
    reaches [Marshal].  Folding the executable's digest into the key
    (and re-asserting it in the header, which [load] verifies) means
    only the EXACT binary that wrote a blob ever reads it; a forgotten
    [format_version] bump degrades to two independent cold caches, not
    a foreign-shape blob fed to [Marshal].  The checklist beside
    [Term.t], [Value.t], [Eterm.t], [Global.entry], [Interp.v] and
    [Prim.t] stays as documentation of WHEN a bump is polite (it
    orphans stale files eagerly), no longer as the only fence.

    Value: [Marshal] of the pair [(Global.t, Interp.globals)], both
    plain data end to end: [Prim.t] is a closed enum with no closures
    (the M3 design verdict's decision 3), and every runtime value
    carries an [Eterm.t] syntax tree rather than an OCaml function, so
    nothing in either type can defeat [Marshal].

    Correctness rests on one argument: elaboration and checking are a
    PURE, deterministic function of the prelude's source bytes plus the
    fixed builtin environment ([Bootstrap.phase1]/[phase2]/[phase3]
    read no external state and no clock), so the SAME key always
    implies byte-identical [Global.t] and [Interp.globals]. Gate D (ii)
    pins this directly: [TOT_CACHE_VERIFY=1] recomputes the cold path on
    a hit and compares its [Marshal.to_string] bytes against the
    cached blob's.

    Every failure on the read OR write path (missing file, wrong
    magic or version, a truncated or corrupted body, a stale/foreign
    [Marshal] shape, a missing or unwritable cache directory) degrades
    to a MISS (on read) or a silent no-op (on write), never a crash
    FOR ANY CONTENT PRODUCED WITHOUT WRITE ACCESS TO THE CACHE
    DIRECTORY (M3 fixes round 3, O3: an attacker WITH write access can
    forge a self-consistent blob whose decoded shape is arbitrary; the
    trust-class paragraph below and SPEC.md section 6 record that
    residual).  What backs the corruption half (M3 fixes, B2/O3;
    pre-fix it was FALSE: a bit-flipped body segfaulted and a
    truncated one died on an uncaught [Invalid_argument]): the blob
    carries a magic string, the fixed-width [format_version], an MD5
    digest of the body, and the writing binary's own digest (round 2,
    R1), and [load] verifies all FOUR before the bytes ever reach
    [Marshal.from_string]; [decode_body]'s fence over [Failure] and
    [Invalid_argument] stays as a backstop only. Each individual
    raising call is still guarded RIGHT THERE, by a NAMED exception
    where the raising function documents one ([Sys_error] for a
    channel open/rename/unlink, [Unix.Unix_error] for [mkdir]), never
    one blanket fence around a whole function body.

    Trust class: the cache directory ([TOT_CACHE_DIR], or
    [~/.cache/tot]) is a TRUSTED input, the same trust class as the
    tot binary itself. The digests defend against CORRUPTION (torn
    writes, disk faults, truncation) and against ACCIDENTAL layout
    drift across binaries (round 2, R1), not against an attacker with
    write access to the directory: such an attacker could re-digest a
    forged body, and can also read the binary and compute its digest,
    and a cache hit replaces the entire checked prelude. SPEC.md
    section 6 records that residual. Deleting the cache directory is
    always safe: the next run just re-elaborates and re-writes it. *)

open Tot_kernel

(** Bump on ANY change to [Term.t], [Value.t], [Eterm.t],
    [Global.entry], [Interp.v] (including [Interp.gbody]/
    [Interp.gentry]) or [Prim.t] (the Marshal-format checklist).
    Folded into the cache KEY (see the module doc comment) AND
    re-asserted inside the file's own fixed-width header, so a foreign
    or rolled-back file that happens to land at the same path is
    rejected PLAINLY, without ever handing its bytes to
    [Marshal.from_string]. Bumped 1 -> 2 (M3 fixes, A2): [gval]
    became a [gbody ref] memo cell, a layout change. Bumped 2 -> 3
    (M3 fixes, B2): the on-disk layout grew the magic string and the
    body digest. Bumped 3 -> 4 (M3 fixes, C4'): a [VPrim] spine's
    stored argument order INVERTED (newest first); same OCaml type,
    but an old-order blob read by a new binary would fire prims with
    reversed arguments, so the version fences it out. Bumped 4 -> 5
    (M3 fixes round 2, R1 + R2): the header grew the executable's own
    digest, and run mode now stores every prelude def as a
    [GDeferred] thunk, so the marshaled [gval] contents changed.
    Since R1 the version bump is belt-and-suspenders only: the
    executable digest already keys and fences every blob. Bumped 5 -> 6
    (M4 Stage A): [Term.t] gained [Auto] and [Match]'s payload gained
    [scrut_q] plus the [motive] record (was a bare binder tuple);
    [Value.stuck_match]'s motive payload changed the same way;
    [Global.ind_entry] gained [indices] and its [ctor_names] became the
    three-state [ctors : ctor_status]; [Global.ctor_entry] gained
    [res_idx], [full_arity] and [self_rec]. Bumped 6 -> 7 (M4 Stage B):
    [Global.entry] gained the [Axiom] constructor. Bumped 7 -> 8 (M4
    Stage C): [Interp.gentry]'s [grec_arg : int option] became
    [gguard : Interp.guard], the three-state [Unguarded | GuardedAt of
    int | Frozen] runtime unfolding guard. Bumped 8 -> 9 (M4 Stage D,
    D5.3): no marshaled OCaml type changed (classes are ordinary [Ind],
    [Ctor] and [Def] entries, and [Syntax.defkind] is not marshaled);
    the bump is for the cache HEADER's exe-identity field, whose MEANING
    changed from a full-file MD5 to a device/inode/mtime/size stat
    digest (see [exe_digest_hex]).  Bumped 9 -> 10 (M4 fixes round 1,
    audit F1): no marshaled OCaml type changed and the header SHAPE is
    the same 32 hex chars, but the exe-identity field's meaning returns
    to the full-file MD5, so every stat-identity blob a version-9 binary
    wrote must be orphaned rather than read. *)
let format_version : int = 10

(** On-disk layout (M3 fixes, B2; round 2, R1): [magic] (8 ASCII
    bytes), the fixed-width [format_version] (8 ASCII decimal digits,
    zero-padded), the MD5 digest of the body (32 hex chars,
    [Digest.to_hex]), the MD5 digest of the WRITING BINARY's own
    contents (32 hex chars), then the body. Every field is fixed-width
    so plain length-checked [String.sub] calls (no [Marshal] involved)
    can split them off the front of a whole-file read. *)
let magic : string = "TOTCACHE"

let magic_width : int = 8
let version_width : int = 8
let digest_width : int = 32
let exe_width : int = 32
let header_width : int = magic_width + version_width + digest_width + exe_width
let version_field : string = Printf.sprintf "%0*d" version_width format_version

(** [~/.cache/tot], or [TOT_CACHE_DIR] when set. A Stage D test-
    isolation fill-in this module's own doc comment names: the plan
    fixes the location at [~/.cache/tot], and an override lets
    dev/gates.sh (and test/surface.ml's in-process cache tests) exercise
    a hit/miss/truncation sequence against a scratch directory without
    ever touching the real user cache -- the same override shape
    [Bootstrap.prelude_path]'s [TOT_PRELUDE] already established for
    the analogous "point the CLI at a test fixture instead of the real
    thing" need. *)
(** M3 fixes round 3 (O1): with NEITHER [TOT_CACHE_DIR] nor [HOME] set
    there is no trustworthy cache location, so the cache is DISABLED
    for the whole run ([load] misses, [save] no-ops), with a single
    loud stderr line -- the exact posture [exe_digest_hex] above takes
    on an unreadable binary.  The old fallback silently wrote
    [./.cache/tot] into whatever the current directory happened to be
    (recorded in dev/M3-FIXES-LOG.md); gate PASS-CACHE-NOHOME pins the
    new behavior.  Computed once per process (lazy), so the stderr
    line cannot repeat. *)
let cache_dir_opt : string option Lazy.t =
  lazy
    (let dir =
       Sys.getenv_opt "TOT_CACHE_DIR"
       |> Option.fold
            ~none:
              (Sys.getenv_opt "HOME" |> Option.map (fun home -> Filename.concat home ".cache/tot"))
            ~some:Option.some
     in
     let () =
       if Option.is_none dir then
         prerr_endline
           "tot: prelude cache disabled for this run: neither TOT_CACHE_DIR nor HOME is set"
     in
     dir)

let cache_dir () : string option = Lazy.force cache_dir_opt

(** ONE raw call: [mkdir] a single path component. Tolerates "already
    exists" (the expected steady state after the first-ever run) and
    every other host failure alike, by degrading to a no-op rather than
    raising: a genuinely unwritable parent directory just means [save]
    below also degrades to a no-op, never a crash. *)
let mkdir_one (path : string) : unit =
  match Unix.mkdir path 0o755 with exception Unix.Unix_error (_, _, _) -> () | () -> ()

(** Create [dir] and every missing ancestor, parents first (M3 fixes
    round 3, ctxcat id 10: the old fixed two-level unroll silently
    no-opped on a [TOT_CACHE_DIR] override nested more than one level
    under an existing directory).  Terminates: [Filename.dirname]
    strictly shortens every path except its own fixpoints ("/", ".",
    a bare name's parent), and a fixpoint that does not exist just
    gets the one [mkdir_one] attempt, degrading to a no-op. *)
let rec ensure_dir (dir : string) : unit =
  match () with
  | () when Sys.file_exists dir -> ()
  | () when String.equal (Filename.dirname dir) dir -> mkdir_one dir
  | () ->
      let () = ensure_dir (Filename.dirname dir) in
      mkdir_one dir

(** M4 fixes round 1 (audit F1): the running binary's stat SIGNATURE,
    the memo key of [exe_digest_hex]'s fast path.  FIVE fields, not the
    four Stage D's D5.3 hashed AS the identity: [st_ctime] joins them
    because it is the one field userspace cannot restore.  [utimes]
    (what `touch -r` and a reproducible-build install step call) resets
    mtime but BUMPS ctime, so overwriting one inode in place, the
    audit's own recipe for two byte-different binaries sharing a blob,
    misses the memo and re-hashes the content.  A signature is only ever
    a reason to SKIP work that a previous run already did;  it is never
    the identity, and the ONE way it can serve a wrong answer is a memo
    HIT on a binary whose bytes changed while all five fields stayed
    equal, which is the residual SPEC.md section 6 records and
    dev/gates.sh's PASS-CACHE-EXEID-MEMO comment argues has no
    unprivileged construction on this platform.

    M4 fixes round 5 (ctxcat r5 id 9): the timestamps are rendered
    LOSSLESSLY ([%.17g]), not to six decimals.  [%.6f] is microsecond
    resolution, and [st_mtime]/[st_ctime] are floats carrying whatever
    the filesystem provides: APFS and ext4 both provide NANOSECONDS, so
    two writes less than a microsecond apart produced two DISTINCT
    floats that [%.6f] rendered as the same string.  That was real
    information the kernel gave us and the rendering threw away.
    [%.17g] round-trips a float exactly, so the signature now
    distinguishes every pair of timestamps the OS itself distinguishes.
    It does NOT close the residual above, and no rendering can: on a
    filesystem or mount whose observed ctime does not move on an
    in-place overwrite, the two timestamps are genuinely EQUAL and
    there is nothing left to render.  That exposure is a property of
    the clock, not of this format string. *)
let exe_stat_signature () : string option =
  match Unix.stat Sys.executable_name with
  | st ->
      Some
        (Printf.sprintf "%d:%d:%.17g:%.17g:%d" st.Unix.st_dev st.Unix.st_ino st.Unix.st_mtime
           st.Unix.st_ctime st.Unix.st_size)
  | exception Unix.Unix_error (_, _, _) -> None

(** Where the memo for THIS executable path lives.  Keyed by the path so
    two installs sharing one cache directory keep separate memos, and
    named with a prefix no blob can collide with ([file_path]'s files are
    "prelude-*.bin"). *)
let exe_memo_path (dir : string) : string =
  Filename.concat dir ("exeid-" ^ Digest.to_hex (Digest.string Sys.executable_name) ^ ".txt")

(** The memoized CONTENT digest for [signature], or [None] when there is
    no memo, it is unreadable, it is malformed, or it was written for a
    different signature.  Every one of those degrades to a re-hash. *)
let read_exe_memo (dir : string) (signature : string) : string option =
  let path = exe_memo_path dir in
  if not (Sys.file_exists path) then None
  else
    match In_channel.with_open_text path In_channel.input_lines with
    | exception Sys_error _ -> None
    | [ got_sig; got_hex ]
      when String.equal got_sig signature && Int.equal (String.length got_hex) digest_width ->
        Some got_hex
    | [] | _ :: _ -> None

(** Record "this signature was content-verified to have this digest".
    Best effort, exactly like [save]: write to a temp file in the same
    directory and rename it into place, unlink the temp file on either
    failure, never raise. *)
let write_exe_memo (dir : string) (signature : string) (hex : string) : unit =
  let () = ensure_dir dir in
  let path = exe_memo_path dir in
  let tmp = path ^ ".tmp" ^ string_of_int (Unix.getpid ()) in
  let remove_tmp () : unit = match Sys.remove tmp with exception Sys_error _ -> () | () -> () in
  match
    Out_channel.with_open_text tmp (fun oc ->
        Out_channel.output_string oc (signature ^ "\n" ^ hex ^ "\n"))
  with
  | exception Sys_error _ -> remove_tmp ()
  | () -> (
      match Sys.rename tmp path with exception Sys_error _ -> remove_tmp () | () -> ())

(** [TOT_CACHE_VERIFY=1] also makes the identity path announce WHICH
    branch produced the digest, so dev/gates.sh can pin the fast path
    itself instead of inferring it from a timing.  Quiet otherwise. *)
let exe_verify_flag : bool Lazy.t =
  lazy (Sys.getenv_opt "TOT_CACHE_VERIFY" |> Option.fold ~none:false ~some:(String.equal "1"))

let exe_marker (line : string) : unit =
  if Lazy.force exe_verify_flag then prerr_endline line else ()

(** Hash the executable's own bytes, the TRUE identity, and record the
    result in the memo for the next run.  Fail CLOSED: when the bytes
    cannot be read (an execute-only install, M3 fixes round 3, O4) the
    cache is DISABLED for the whole run ([load] misses, [save] no-ops)
    with a single loud stderr line, never a crash and never a blob whose
    identity field was derived without reading the binary. *)
let exe_content_digest () : string option =
  match Digest.file Sys.executable_name with
  | d ->
      let hex = Digest.to_hex d in
      let () = exe_marker "TOT-CACHE-EXEID-CONTENT" in
      let () =
        cache_dir ()
        |> Option.iter (fun dir ->
               exe_stat_signature () |> Option.iter (fun s -> write_exe_memo dir s hex))
      in
      Some hex
  | exception Sys_error _ ->
      let () =
        prerr_endline
          ("tot: prelude cache disabled for this run: cannot read the executable at "
         ^ Sys.executable_name)
      in
      None

(** The running binary's own IDENTITY digest (hex), computed once per
    process on first use (M3 fixes round 2, R1;  M4 fixes round 1, audit
    F1): the fence that binds every cache blob to the EXACT executable,
    folded into the key by [key] and verified against the header field by
    [load].  The identity IS [Digest.file]'s content hash.  The
    [Unix.stat] signature is a MEMO key only: when it matches what a
    previous, content-verified run recorded, the ~3.3ms re-hash is
    skipped;  an absent, unreadable, malformed or mismatched memo, or an
    unavailable cache directory, re-hashes the content.  So two
    byte-different binaries can never share a blob (their content
    digests differ, and only the re-hash can produce the recorded one),
    which is precisely the property D5.3's stat-AS-identity shape lost.
    Each raising call is guarded RIGHT THERE, by its own named exception,
    per the module's own house style. *)
let exe_digest_hex : string option Lazy.t =
  lazy
    (let memoed =
       cache_dir ()
       |> Option.fold ~none:None ~some:(fun dir ->
              exe_stat_signature ()
              |> Option.fold ~none:None ~some:(fun signature -> read_exe_memo dir signature))
     in
     (memoed
     |> Option.fold
          ~none:(fun () -> exe_content_digest ())
          ~some:(fun (hex : string) () ->
            let () = exe_marker "TOT-CACHE-EXEID-MEMO" in
            Some hex))
       ())

let file_path (dir : string) (key : string) : string =
  Filename.concat dir ("prelude-" ^ key ^ ".bin")

(** The cache key: prelude source bytes plus [format_version] plus the
    running binary's own digest (M3 fixes round 2, R1), folded through
    one [Digest.string] call (MD5; a total function, it never raises).
    When [exe_digest_hex] is unavailable the cache is disabled anyway
    ([load]/[save] below), so the placeholder key never names a file
    that gets read or written. *)
let key (prelude_src : string) : string =
  let exe = Lazy.force exe_digest_hex |> Option.value ~default:"exe-digest-unavailable" in
  Digest.to_hex
    (Digest.string (prelude_src ^ "\x00" ^ string_of_int format_version ^ "\x00" ^ exe))

(** Split a whole-file read into its four fixed-width header fields
    and the body after them. [None] when the file is shorter than
    [header_width] itself (a truncated cache file). Every slice below
    carries its own length precondition ON THE SAME LINE, so no
    [String.sub] call can raise: the outer [if] already established
    [header_width <= String.length content], and [body_len] is exactly
    [String.length content - header_width] (never negative, by that
    same outer [if]). *)
let split_header (content : string) : (string * string * string * string * string) option =
  if String.length content < header_width then None
  else
    let got_magic = String.sub content 0 magic_width (* @total-accessor *) in
    let got_version = String.sub content magic_width version_width (* @total-accessor *) in
    let got_digest =
      String.sub content (magic_width + version_width) digest_width (* @total-accessor *)
    in
    let exe_off = magic_width + version_width + digest_width in
    let got_exe = String.sub content exe_off exe_width (* @total-accessor *) in
    let body_len = String.length content - header_width in
    let body = String.sub content header_width body_len (* @total-accessor *) in
    Some (got_magic, got_version, got_digest, got_exe, body)

(** Decode a cache blob's body. The digest check in [load] means a
    body that reaches this point is byte-identical to what [save]
    wrote, so the fence here is a pure BACKSTOP for the never-crash
    promise (M3 fixes, B2), exhaustive over the two exceptions
    [Marshal.from_string] can raise on malformed input ([Failure] and
    [Invalid_argument]): [None], a miss, on either. *)
let decode_body (body : string) : (Global.t * Interp.globals) option =
  match Marshal.from_string body 0 with
  | exception (Failure _ | Invalid_argument _) -> None
  | (globals, eglobals) -> Some (globals, eglobals)

(** Read a cache entry back. See the module doc comment for the full
    correctness and failure-handling argument. The one raw file call
    ([In_channel.with_open_bin]/[input_all], which together can raise
    [Sys_error] on a permission race or a directory where a file was
    expected) is guarded right where it happens, matching
    [surface/effect.ml]'s own [Read_file] precedent exactly. The
    magic, version, EXECUTABLE-digest AND body-digest fields must all
    verify BEFORE [decode_body] hands the bytes to [Marshal]; any
    mismatch is a silent miss (M3 fixes, B2/O3; round 2, R1: the
    executable field is checked before the body digest, and an
    unavailable executable digest disables the cache, a miss; round 3,
    O1: an unavailable cache directory likewise). *)
let load (key : string) : (Global.t * Interp.globals) option =
  Lazy.force exe_digest_hex
  |> Option.fold ~none:None ~some:(fun exe_hex ->
         cache_dir ()
         |> Option.fold ~none:None ~some:(fun dir ->
         let path = file_path dir key in
         if not (Sys.file_exists path) then None
         else
           match In_channel.with_open_bin path In_channel.input_all with
           | exception Sys_error _ -> None
           | content ->
               split_header content
               |> Option.fold ~none:None
                    ~some:(fun (got_magic, got_version, got_digest, got_exe, body) ->
                      let intact =
                        String.equal got_magic magic
                        && String.equal got_version version_field
                        && String.equal got_exe exe_hex
                        && String.equal got_digest (Digest.to_hex (Digest.string body))
                      in
                      if intact then decode_body body else None)))

(** Write a cache entry. Best effort: a write failure (an unwritable
    directory, a full disk, a concurrent writer) degrades to a silent
    no-op, never a crash, matching [load]'s own "never a crash" posture
    on the read side. Writes to a fresh temp file in the same directory
    first and renames it into place, so a concurrent reader never
    observes a partially-written blob (the rename is atomic on the same
    filesystem, the standard safe-publish idiom); the write and the
    rename are each guarded right where [Sys_error] can reach them,
    and a FAILED write or rename best-effort unlinks the temp file
    rather than stranding it in the cache directory (M3 fixes, B2/C7;
    round 3, ctxcat id 9: the write path -- disk full mid-write, a
    permission race on open or close -- now unlinks too, not just the
    rename path). An unavailable executable digest (round 2, R1) or an
    unavailable cache directory (round 3, O1: neither [TOT_CACHE_DIR]
    nor [HOME]) makes the whole save a no-op: no blob is ever written
    without the binary-binding header field, and never into the
    current directory. *)
let save (key : string) (globals : Global.t) (eglobals : Interp.globals) : unit =
  Lazy.force exe_digest_hex
  |> Option.fold ~none:() ~some:(fun exe_hex ->
         cache_dir ()
         |> Option.fold ~none:() ~some:(fun dir ->
         let () = ensure_dir dir in
         let path = file_path dir key in
         let tmp = path ^ ".tmp" ^ string_of_int (Unix.getpid ()) in
         let body = Marshal.to_string (globals, eglobals) [] in
         let digest_hex = Digest.to_hex (Digest.string body) in
         let remove_tmp () : unit =
           match Sys.remove tmp with exception Sys_error _ -> () | () -> ()
         in
         match
           Out_channel.with_open_bin tmp (fun oc ->
               Out_channel.output_string oc magic;
               Out_channel.output_string oc version_field;
               Out_channel.output_string oc digest_hex;
               Out_channel.output_string oc exe_hex;
               Out_channel.output_string oc body)
         with
         | exception Sys_error _ -> remove_tmp ()
         | () -> (
             match Sys.rename tmp path with
             | exception Sys_error _ -> remove_tmp ()
             | () -> ())))
