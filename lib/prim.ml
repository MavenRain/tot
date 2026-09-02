(** The native primitive catalog (M3 Stage A). A closed enum with no
    OCaml closures inside, so [Global.t] and [Interp.globals] stay
    marshalable (decision 3 of the M3 design verdict, section 3.10).
    Later stages EXTEND this enum; every extension extends [name],
    [arity], [classification], [justification] and [catalog] together. *)

(** Where a prim sits on the effect ladder. Stage A carries only [Tot]:
    every catalog entry fires inline at runtime, never during
    conversion (a [Prim] entry is always opaque to [Eval.conv], see
    [Global.prim_entry]). [Div] and [Io] arrive in later stages. *)
type ladder =
  | Tot
  | Div
  | Io

(** Marshal-format checklist (M3 Stage D): a [Prim.t] value is the
    payload of every [Interp.v] [VPrim]/[VIOAction] spine and every
    [Global.prim_entry], and [surface/cache.ml] marshals those whole.
    Any change here bumps [Cache.format_version]. *)
type t =
  | String_concat
  | String_length
  | String_eq
  | String_contains
  | Int_add
  | Int_sub
  | Int_eq
  | Int_to_string
  | Pure_div  (** M3 Stage B: the ladder, [Div]'s unit *)
  | Bind_div  (** M3 Stage B: the ladder, [Div]'s bind *)
  | Pure_io  (** M3 Stage B: the ladder, [IO]'s unit *)
  | Bind_io  (** M3 Stage B: the ladder, [IO]'s bind *)
  | Lift_io  (** M3 Stage B: the one [Div] -> [IO] bridge *)
  | Read_stdin  (** M3 Stage B: native IO, arity 0 *)
  | Print_line  (** M3 Stage B: native IO *)
  | Exit_with  (** M3 Stage B: native IO *)
  | Get_env  (** M3 Stage B: native IO *)
  | String_slice  (** M3 Stage C: bounds-checked substring, Tot *)
  | String_split  (** M3 Stage C: split on a separator, Tot *)
  | String_to_int  (** M3 Stage C: decimal parse, Tot *)
  | Int_compare  (** M3 Stage C: three-way compare, Tot *)
  | Read_file  (** M3 Stage C: native IO *)
  | Write_file  (** M3 Stage C: native IO *)
  | Argv  (** M3 Stage C: native IO, arity 0 *)
  | Proc_run  (** M3 Stage C: native IO, spawns a child process *)
  | Json_parse
      (** M3 Stage C: Div, not Tot. The parser is host code with no
          structural termination proof, and its flagship caller
          (hook payload parsing) feeds it attacker-shaped text. *)
  | Json_serialize  (** M3 Stage C: Tot, walks a finite value *)
  | Regex_test
      (** M3 Stage C: Div. Backtracking engines have catastrophic
          input/pattern pairs; the [Div] classification is provenance
          and a composition discipline, NOT an operational
          termination proof (a PreToolUse guard is expected to
          adjudicate attacker-influenced pattern/text pairs). *)
  | Regex_match  (** M3 Stage C: Div, same rationale as [Regex_test] *)

let name (p : t) : string =
  match p with
  | String_concat -> "stringConcat"
  | String_length -> "stringLength"
  | String_eq -> "stringEq"
  | String_contains -> "stringContains"
  | Int_add -> "intAdd"
  | Int_sub -> "intSub"
  | Int_eq -> "intEq"
  | Int_to_string -> "intToString"
  | Pure_div -> "pureDiv"
  | Bind_div -> "bindDiv"
  | Pure_io -> "pureIO"
  | Bind_io -> "bindIO"
  | Lift_io -> "liftIO"
  | Read_stdin -> "readStdin"
  | Print_line -> "printLine"
  | Exit_with -> "exitWith"
  | Get_env -> "getEnv"
  | String_slice -> "stringSlice"
  | String_split -> "stringSplit"
  | String_to_int -> "stringToInt"
  | Int_compare -> "intCompare"
  | Read_file -> "readFile"
  | Write_file -> "writeFile"
  | Argv -> "argv"
  | Proc_run -> "procRun"
  | Json_parse -> "jsonParse"
  | Json_serialize -> "jsonSerialize"
  | Regex_test -> "regexTest"
  | Regex_match -> "regexMatch"

(** KEPT (quantity-w) arguments only: the erased type arguments a prim's
    Pi telescope may carry never count. Note the M3 Stage B correction:
    [pureIO]'s kept arity is 1 (the value argument only), not 2; the
    monadic design proposal's arity table listed 2, which contradicted
    the verdict's own decision 4. The declared bootstrap type is
    authoritative; [surface/bootstrap.ml]'s [seed_prim] checks every
    catalog entry against it, and test/main.ml's
    [case_prim_arity_agreement] pins the agreement over all three
    seeding phases (M3 fixes, C2'). *)
let arity (p : t) : int =
  match p with
  | String_concat -> 2
  | String_length -> 1
  | String_eq -> 2
  | String_contains -> 2
  | Int_add -> 2
  | Int_sub -> 2
  | Int_eq -> 2
  | Int_to_string -> 1
  | Pure_div -> 1
  | Bind_div -> 2
  | Pure_io -> 1
  | Bind_io -> 2
  | Lift_io -> 1
  | Read_stdin -> 0
  | Print_line -> 1
  | Exit_with -> 1
  | Get_env -> 1
  | String_slice -> 3
  | String_split -> 2
  | String_to_int -> 1
  | Int_compare -> 2
  | Read_file -> 1
  | Write_file -> 2
  | Argv -> 0
  | Proc_run -> 2
  | Json_parse -> 1
  | Json_serialize -> 1
  | Regex_test -> 2
  | Regex_match -> 2

let classification (p : t) : ladder =
  (* one arm per rung (M3 fixes round 3, ctxcat id 7: the Stage A and
     Stage C constructors used to sit in separate same-rung arms) *)
  match p with
  | String_concat | String_length | String_eq | String_contains | Int_add | Int_sub
  | Int_eq | Int_to_string | String_slice | String_split | String_to_int | Int_compare
  | Json_serialize ->
      Tot
  | Pure_div | Bind_div | Json_parse | Regex_test | Regex_match -> Div
  | Pure_io | Bind_io | Lift_io | Read_stdin | Print_line | Exit_with | Get_env
  | Read_file | Write_file | Argv | Proc_run ->
      Io

let justification (p : t) : string =
  match p with
  | String_concat -> "OCaml string concatenation is total"
  | String_length -> "byte length of a finite string is total"
  | String_eq -> "byte equality is total"
  | String_contains -> "substring scan is O(n*m) and total"
  | Int_add -> "OCaml int addition wraps, never diverges"
  | Int_sub -> "OCaml int subtraction wraps, never diverges"
  | Int_eq -> "int equality is total"
  | Int_to_string -> "decimal rendering of an int is total"
  | Pure_div ->
      "wrapping a value as Div computes nothing of its own, but the Div marker propagates \
       absorbingly to whatever definition touches it"
  | Bind_div ->
      "sequencing Div actions inherits whatever divergence the sequenced computation carries"
  | Pure_io -> "building an IO action is inert; firing it is run_io's job alone"
  | Bind_io ->
      "sequencing IO actions defers to whatever the sequenced action observes when it is \
       finally run"
  | Lift_io -> "embedding a Div result into IO is the one bridge the ladder allows"
  | Read_stdin -> "consumes the process stdin, an observable effect that must not run at \
                   definition time"
  | Print_line -> "writes to the process stdout, an observable, ordered effect"
  | Exit_with -> "terminates the process with a caller-chosen code, an observable effect"
  | Get_env -> "reads process environment state, which can change between two reads of the \
                same name"
  | String_slice -> "bounds-checked substring extraction over a finite string is total"
  | String_split ->
      "splitting a finite string on a finite separator by repeated scan-and-shrink recursion \
       terminates: the tail strictly shrinks each step"
  | String_to_int ->
      "a decimal-only (optional '-', digits) validation plus OCaml's total \
       int_of_string_opt never raises"
  | Int_compare -> "three-way int comparison is total"
  | Read_file -> "reads a file from the filesystem, an observable effect that must not run at \
                  definition time"
  | Write_file -> "writes a file to the filesystem, an observable, ordered effect"
  | Argv -> "reads the process's own argv, which is fixed per-process but is still \
             environment-provided state, not a pure computation"
  | Proc_run -> "spawning a process is an observable, ordered effect that must not run merely \
                 because a value was constructed"
  | Json_parse -> "the parser is host code with no structural termination proof, and its \
                   flagship caller feeds it attacker-shaped payloads"
  | Json_serialize -> "serialization walks a finite Json value structurally"
  (* M3 fixes round 2 (ctxcat id 10): one shared arm, so the two regex
     prims' identical rationale can never drift apart *)
  | Regex_test | Regex_match ->
      "backtracking engines have catastrophic input-and-pattern pairs; typing gives \
       provenance and composition discipline, not an operational termination proof"

(** Every constructor, in declaration order. A Stage A test enforces
    that this list, [name] and [of_name] agree. *)
let catalog : t list =
  [
    String_concat;
    String_length;
    String_eq;
    String_contains;
    Int_add;
    Int_sub;
    Int_eq;
    Int_to_string;
    Pure_div;
    Bind_div;
    Pure_io;
    Bind_io;
    Lift_io;
    Read_stdin;
    Print_line;
    Exit_with;
    Get_env;
    String_slice;
    String_split;
    String_to_int;
    Int_compare;
    Read_file;
    Write_file;
    Argv;
    Proc_run;
    Json_parse;
    Json_serialize;
    Regex_test;
    Regex_match;
  ]

let of_name (s : string) : t option =
  List.find_opt (fun p -> String.equal (name p) s) catalog
