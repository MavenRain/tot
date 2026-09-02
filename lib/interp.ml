(** Call-by-value interpreter over erased terms. Reducibility never
    reaches this module (that is a conversion-time notion); every
    non-rec global still unfolds unconditionally at application time,
    exactly as before. A rec global, however, carries its kernel
    [rec_arg] into the runtime global table and unfolds only when its
    principal argument is a canonical (fully applied) constructor value:
    applying it before that starts (or extends) a neutral application
    under the new [EHGlobal] head, mirroring the kernel's [Value.HGlobal]
    guarded-unfolding discipline (see [Eval]). Without this a rec
    global's cached closure would unfold eagerly under [quote]'s fresh
    neutral binders, re-freezing one level deeper on every peel and
    diverging; readback of a rec function value is now total. [VNeut]
    also still serves its original role: [quote] applies closures to
    fresh neutral variables to reach under binders, and a match stuck on
    such a variable freezes its branches as an [FEMatch] frame. *)

let ( let* ) = Result.bind

(** Marshal-format checklist (M3 Stage D): [surface/cache.ml] marshals a
    whole [Interp.globals] (every stored [gval] is a [gbody ref] over
    [v]), so any change to this type, to [gbody]/[gentry], or to
    [io_action] below bumps [Cache.format_version]. *)
type v =
  | VClos of string * v list * Eterm.t
  | VCon of string * v list  (** data ctor applied; KEPT args only, in order *)
  | VNeut of ehead * eframe list  (** head + frames, newest first *)
  | VErased
  | VLit of Literal.t  (** M3 Stage A *)
  | VPrim of Prim.t * v list
      (** M3 Stage A: a prim accumulating args toward its catalog
          arity.  Stored NEWEST FIRST since the M3 fixes (C4'):
          [apply] reverses into argument order at fire time, [quote]
          at readback. *)
  | VIOAction of io_action
      (** M3 Stage B: an inert, first-class reified IO action tree.
          Building one performs no OCaml effect; only
          [surface/effect.ml]'s [run_io] ever walks it. *)

and io_action =
  | IOPure of v  (** [pureIO x] / [liftIO dv]: a already-computed value *)
  | IOBind of v * v
      (** [bindIO m k]: the inner action VALUE (expected to itself be a
          [VIOAction], coerced lazily by [Effect.require_action]) and
          the continuation closure *)
  | IONative of Prim.t * v list
      (** a fully-applied native effect prim, undischarged; only
          [Effect.dispatch] performs the actual host call *)

and ehead =
  | EHVar of int  (** readback: a fresh binder introduced by [quote] *)
  | EHGlobal of string
      (** a rec global whose principal argument is not yet known
          canonical; frames accumulate here until the guard is met *)

and eframe =
  | FEApp of v
  | FEMatch of (string * string list * Eterm.t) list * v list
      (** frozen branches + the env their bodies close over *)

(** M3 Stage B: a global's runtime body is forced immediately
    ([GForced]) or recorded as a closed erased term and forced lazily
    ([GDeferred]) whenever [EGlobal] resolves it or a guarded rec
    global unfolds it. [surface/run.ml]'s [IDef] handling (RUN mode
    only, M3 fixes A1) chooses [GDeferred] exactly when the def's
    STAMPED type head is [Div] or [IO] (keyed on the type, not a new
    attribute; decision 11 of the M3 design verdict). M3 fixes, A2
    (C17, 2026-09-01): forcing MEMOIZES. The entry holds a [gbody ref];
    the first force [exec]s the deferred term once and writes the
    computed value back as [GForced], so a chain of n Div-headed defs
    each referencing the previous twice costs n forces, not 2^n
    (Div computation is pure modulo divergence, and an IO-headed body
    only ever BUILDS an inert action tree, identical on every rebuild,
    so storing it changes no observable behavior; [Effect.run_io]
    still fires effects once per WALK of the tree, not per build).
    Every other entry kind (ctor, erased type, prim, ordinary def)
    stays [GForced] from birth, exactly as before this stage. *)
type gbody =
  | GForced of v
  | GDeferred of Eterm.t

(** One runtime global binding. [gval] is the body [EGlobal] resolves to
    when the guard does not apply (a non-rec def's cached closure or
    deferred term, a ctor's growing [VCon], or [VErased] for an inert
    type constructor); for a rec def it also doubles as the closure
    [replay] unfolds onto once the guard is satisfied. It is a [ref]
    cell so [force] can memoize a deferred body's computed value in
    place (M3 fixes, A2); map copies threaded through [Run.state]
    share the cell, so one force pays for every later reference.
    [grec_arg]:
    [Some k] marks a rec def guarded on argument [k]; [None] covers
    every other kind of entry, including a plain (non-rec) def.
    [gctor_arity]: [Some n] marks a data constructor whose KEPT
    (quantity-`w`) arity is [n], the runtime analogue of
    [Eval.is_canonical]'s full-arity check (erased args and params
    never reach a runtime [VCon]). *)
type gentry = {
  gval : gbody ref;
  grec_arg : int option;
  gctor_arity : int option;
}

type globals = gentry Global.StringMap.t

let empty_globals : globals = Global.StringMap.empty

(** The leading (oldest-first) run of [FEApp] argument values of a frame
    list ALREADY reversed to oldest-first order. Mirrors
    [Eval.leading_fapp_args]. *)
let rec leading_fapp_args (frames : eframe list) : v list =
  match frames with
  | [] -> []
  | FEApp v :: rest -> v :: leading_fapp_args rest
  | FEMatch (_, _) :: _rest -> []

(** Canonical means: a data constructor fully applied, counting only its
    KEPT args (erasure already dropped quantity-0 args and every param
    before an [Eterm] value exists at all). An unknown ctor name cannot
    occur on a checked, erased program; total via [Option.fold], no
    error path needed here (mirrors [Eval.is_canonical]). *)
let is_canonical (eglobals : globals) (v : v) : bool =
  match v with
  | VCon (c, args) ->
      Global.StringMap.find_opt c eglobals
      |> Fun.flip Option.bind (fun (g : gentry) -> g.gctor_arity)
      |> Option.fold ~none:false ~some:(fun arity -> Int.equal (List.length args) arity)
  | VClos (_, _, _) | VNeut (_, _) | VErased | VLit _ | VPrim (_, _) | VIOAction _ -> false

(* ------------------------------------------------------------------ *)
(* M3 Stage C: stdlib breadth. Every function below is a pure helper
   [fire_prim] calls for one Tot or Div prim; none of them touches
   [eglobals], [exec], [apply] or any OS resource, so none needs to
   join the mutually-recursive [exec]/.../[fire_prim] group below. *)
(* ------------------------------------------------------------------ *)

let chars_of_string (s : string) : char list = String.to_seq s |> List.of_seq

(** M3 Stage C ([jsonSlice]'s cousin [stringSlice]): a bounds-checked
    substring. Mirrors [fire_prim]'s own "@total-accessor" discipline
    (see [contains_from] below): the bound is checked FIRST, so the
    [String.sub] that follows is always in range.  M3 fixes round 3
    (ctxcat id 5): [start] and [len] are USER-CONTROLLED ints, so the
    old additive guard [start + len <= String.length s] could WRAP
    negative on huge operands and admit an out-of-range [String.sub]
    (an uncaught [Invalid_argument], recorded in dev/M3-FIXES-LOG.md).
    Every comparison below either tests one operand alone or subtracts
    bounded nonnegatives ([String.length s - start] after [start <=
    String.length s]), which cannot overflow; together they imply the
    mathematical [start + len <= String.length s]. *)
let string_slice_opt (s : string) (start : int) (len : int) : string option =
  if start >= 0 && len >= 0 && start <= String.length s && len <= String.length s - start
  then Some (String.sub s start len (* @total-accessor: bounds checked above *))
  else None

(** M3 Stage C: [stringSplit s sep], total by well-founded recursion on
    a strictly shrinking tail (each step consumes at least
    [String.length sep] bytes, and an empty separator is a documented
    no-split base case, avoiding the degenerate infinite-split
    reading). *)
let string_split_on (s : string) (sep : string) : string list =
  let rec go (s : string) : string list =
    let slen = String.length s in
    let seplen = String.length sep in
    if Int.equal seplen 0 then [ s ]
    else
      let rec find_from (i : int) : int option =
        match () with
        | () when i + seplen > slen -> None
        | () when String.equal (String.sub s i seplen (* @total-accessor: guarded above *)) sep
          ->
            Some i
        | () -> find_from (i + 1)
      in
      find_from 0
      |> Option.fold ~none:[ s ] ~some:(fun i ->
             let head = String.sub s 0 i (* @total-accessor: 0 <= i <= slen from find_from *) in
             let tail =
               String.sub s (i + seplen)
                 (slen - i - seplen) (* @total-accessor: i + seplen <= slen from find_from *)
             in
             head :: go tail)
  in
  go s

(** M3 fixes round 2 (ctxcat id 9): [stringToInt] accepts EXACTLY an
    optional leading '-' followed by decimal digits, never OCaml's
    wider [int_of_string] syntax (0x/0o/0b prefixes, '_' digit-group
    separators, a leading '+'), matching the decimal-only shape
    [json_number] parses and [Int_to_string] prints. Overflow (a
    digit run outside the native int range) still yields [None] via
    [int_of_string_opt] on the validated string. *)
let decimal_int_opt (s : string) : int option =
  let is_digit (c : char) : bool = Char.code c >= Char.code '0' && Char.code c <= Char.code '9' in
  let body =
    if String.starts_with ~prefix:"-" s then
      String.sub s 1 (String.length s - 1) (* @total-accessor: prefix checked above *)
    else s
  in
  match () with
  | () when String.length body > 0 && String.for_all is_digit body -> int_of_string_opt s
  | () -> None

(** M3 Stage C, C2 ([jsonParse]): a small, hand-rolled, total JSON
    parser. A malformed payload, or a JSON number outside [Json]'s
    Int-only numeric type (no floats: [jnum : Int -> Json]), simply
    yields [None]; never a crash. Builds runtime [VCon] trees directly
    with the prelude's own [Json] constructor names, the same
    hand-by-name construction style [fire_prim]'s [bool_of] below
    already uses for [true]/[false]. Div, not Tot ([Prim.classification
    Json_parse]): this parser is host-adjacent code with no structural
    termination proof, and its input is attacker-shaped text.
    Documented SPEC debt: no `\uXXXX` unicode escape support (a
    conformance suite is out of scope for this stage). *)
let json_is_ws (c : char) : bool =
  Char.equal c ' ' || Char.equal c '\t' || Char.equal c '\n' || Char.equal c '\r'

let rec json_skip_ws (cs : char list) : char list =
  match cs with
  | c :: rest when json_is_ws c -> json_skip_ws rest
  | ([] | _ :: _) as rest -> rest

(** Match a literal keyword suffix (e.g. the "ull" after a leading
    'n'); total, every call site's [want] is a fixed literal. *)
let rec json_lit (want : char list) (cs : char list) : char list option =
  match want with
  | [] -> Some cs
  | w :: ws -> (
      match cs with
      | c :: rest when Char.equal c w -> json_lit ws rest
      | ([] | _ :: _) -> None)

let json_is_digit (c : char) : bool = c >= '0' && c <= '9'

let rec json_digits (cs : char list) (acc : char list) : char list * char list =
  match cs with
  | c :: rest when json_is_digit c -> json_digits rest (c :: acc)
  | ([] | _ :: _) as rest -> (List.rev acc, rest)

(** [Json]'s numbers are Int-only: no fractional/exponent syntax. *)
let json_number (cs : char list) : (int * char list) option =
  match cs with
  | '-' :: rest ->
      let digits, rest' = json_digits rest [] in
      (match digits with
      | [] -> None
      | _ :: _ ->
          digits |> List.to_seq |> String.of_seq |> int_of_string_opt
          |> Option.map (fun n -> (-n, rest')))
  | c :: _ when json_is_digit c ->
      let digits, rest' = json_digits cs [] in
      digits |> List.to_seq |> String.of_seq |> int_of_string_opt
      |> Option.map (fun n -> (n, rest'))
  | ([] | _ :: _) -> None

(** A JSON string body's escapes (backslash-quote, backslash-backslash,
    backslash-slash, and the backslash letter forms b/f/n/r/t); mirrors
    [surface/lexer.ml]'s own [scan_string] shape (an unterminated
    literal or an unknown escape fails the WHOLE parse, never partial
    output). *)
let rec json_string_body (cs : char list) (acc : char list) : (string * char list) option =
  match cs with
  | '"' :: rest -> Some (List.rev acc |> List.to_seq |> String.of_seq, rest)
  | '\\' :: 'n' :: rest -> json_string_body rest ('\n' :: acc)
  | '\\' :: 't' :: rest -> json_string_body rest ('\t' :: acc)
  | '\\' :: 'r' :: rest -> json_string_body rest ('\r' :: acc)
  | '\\' :: 'b' :: rest -> json_string_body rest ('\b' :: acc)
  | '\\' :: 'f' :: rest -> json_string_body rest ('\012' :: acc)
  | '\\' :: '"' :: rest -> json_string_body rest ('"' :: acc)
  | '\\' :: '\\' :: rest -> json_string_body rest ('\\' :: acc)
  | '\\' :: '/' :: rest -> json_string_body rest ('/' :: acc)
  | [ '\\' ] -> None
  | '\\' :: _ :: _ -> None
  | c :: rest -> json_string_body rest (c :: acc)
  | [] -> None

(** The whole payload must parse as exactly one JSON value (trailing
    non-whitespace garbage rejects the whole parse); [None] on any
    failure. *)
let json_parse_top (s : string) : v option =
  let ( let* ) = Option.bind in
  let rec json_value (cs : char list) : (v * char list) option =
    match json_skip_ws cs with
    | 'n' :: rest ->
        json_lit [ 'u'; 'l'; 'l' ] rest |> Option.map (fun r -> (VCon ("jnull", []), r))
    | 't' :: rest ->
        json_lit [ 'r'; 'u'; 'e' ] rest
        |> Option.map (fun r -> (VCon ("jbool", [ VCon ("true", []) ]), r))
    | 'f' :: rest ->
        json_lit [ 'a'; 'l'; 's'; 'e' ] rest
        |> Option.map (fun r -> (VCon ("jbool", [ VCon ("false", []) ]), r))
    | '"' :: rest ->
        json_string_body rest []
        |> Option.map (fun (str, r) -> (VCon ("jstr", [ VLit (Literal.LString str) ]), r))
    | '[' :: rest -> json_array rest
    | '{' :: rest -> json_object rest
    | ('-' :: _ as num_cs) -> json_num_value num_cs
    | (c :: _ as num_cs) when json_is_digit c -> json_num_value num_cs
    | ([] | _ :: _) -> None
  and json_num_value (cs : char list) : (v * char list) option =
    json_number cs |> Option.map (fun (n, r) -> (VCon ("jnum", [ VLit (Literal.LInt n) ]), r))
  and json_array (cs : char list) : (v * char list) option =
    match json_skip_ws cs with
    | ']' :: rest -> Some (VCon ("jarrNil", []), rest)
    | ([] | _ :: _) as rest -> json_array_more rest
  and json_array_more (cs : char list) : (v * char list) option =
    let* hd, rest = json_value cs in
    match json_skip_ws rest with
    | ',' :: rest2 ->
        let* tl, rest3 = json_array_more rest2 in
        Some (VCon ("jarrCons", [ hd; tl ]), rest3)
    | ']' :: rest2 -> Some (VCon ("jarrCons", [ hd; VCon ("jarrNil", []) ]), rest2)
    | ([] | _ :: _) -> None
  and json_object (cs : char list) : (v * char list) option =
    match json_skip_ws cs with
    | '}' :: rest -> Some (VCon ("jobjNil", []), rest)
    | ([] | _ :: _) as rest -> json_object_more rest
  and json_object_more (cs : char list) : (v * char list) option =
    match json_skip_ws cs with
    | '"' :: rest -> (
        let* key, rest2 = json_string_body rest [] in
        match json_skip_ws rest2 with
        | ':' :: rest3 -> (
            let* value, rest4 = json_value rest3 in
            match json_skip_ws rest4 with
            | ',' :: rest5 ->
                let* tl, rest6 = json_object_more rest5 in
                Some (VCon ("jobjCons", [ VLit (Literal.LString key); value; tl ]), rest6)
            | '}' :: rest5 ->
                Some
                  ( VCon ("jobjCons", [ VLit (Literal.LString key); value; VCon ("jobjNil", []) ]),
                    rest5 )
            | ([] | _ :: _) -> None)
        | ([] | _ :: _) -> None)
    | ([] | _ :: _) -> None
  in
  let* result_v, rest = json_value (chars_of_string s) in
  match json_skip_ws rest with
  | [] -> Some result_v
  | _ :: _ -> None

(** A total left-to-right traversal: the first failure short circuits,
    same discipline as [Result.bind]-chained code elsewhere in this
    file, packaged once for [json_serialize]'s two spine walkers. *)
let result_traverse (f : 'a -> ('b, Error.t) result) (xs : 'a list) : ('b list, Error.t) result
    =
  let ( let* ) = Result.bind in
  List.fold_left
    (fun acc x ->
      let* done_ = acc in
      let* y = f x in
      Ok (y :: done_))
    (Ok []) xs
  |> Result.map List.rev

(** M3 Stage C, C1 ([jsonSerialize], Tot: walks a finite value). A
    shape the prelude's own [data Json] declaration cannot produce
    (e.g. a [jnum] whose argument is not a [VLit (LInt _)]) is
    unreachable on a checked program; the fallback arms are total
    backstops only, mirroring [fire_prim]'s own shape-mismatch style.
    [Pp.escape_string] is reused for JSON string quoting (M3 Stage A's
    own escape set — backslash, quote, newline, tab — is a subset of
    JSON's, so it produces valid JSON text for every string this
    parser can itself have produced; a string containing OTHER control
    characters this parser cannot itself construct is a documented
    SPEC debt, same posture as the parser's own unicode-escape gap). *)
let rec json_serialize (jv : v) : (string, Error.t) result =
  let ( let* ) = Result.bind in
  match jv with
  | VCon ("jnull", []) -> Ok "null"
  | VCon ("jbool", [ VCon ("true", []) ]) -> Ok "true"
  | VCon ("jbool", [ VCon ("false", []) ]) -> Ok "false"
  | VCon ("jnum", [ VLit (Literal.LInt n) ]) -> Ok (string_of_int n)
  | VCon ("jstr", [ VLit (Literal.LString s) ]) -> Ok (Pp.escape_string s)
  | VCon ("jarrNil", []) -> Ok "[]"
  | VCon ("jarrCons", [ hd; tl ]) ->
      let* elems = json_array_spine tl [ hd ] in
      let* strs = result_traverse json_serialize elems in
      Ok ("[" ^ String.concat "," strs ^ "]")
  | VCon ("jobjNil", []) -> Ok "{}"
  | VCon ("jobjCons", [ VLit (Literal.LString k0); v0; tl0 ]) ->
      let* pairs = json_object_spine tl0 [ (k0, v0) ] in
      let* strs =
        result_traverse
          (fun (k, pv) ->
            let* s = json_serialize pv in
            Ok (Pp.escape_string k ^ ":" ^ s))
          pairs
      in
      Ok ("{" ^ String.concat "," strs ^ "}")
  | ( VCon (_, _) | VClos (_, _, _) | VNeut (_, _) | VErased | VLit _ | VPrim (_, _)
    | VIOAction _ ) ->
      Error (Error.Mismatch { expected = "Json"; actual = "<not a well-formed Json value>" })

(* Walk a [jarrCons] tail spine; [acc] accumulates OLDEST FIRST
   (reversed relative to source order), so every caller passes its own
   already-seen head as the seed and the base case reverses once. *)
and json_array_spine (jv : v) (acc : v list) : (v list, Error.t) result =
  match jv with
  | VCon ("jarrNil", []) -> Ok (List.rev acc)
  | VCon ("jarrCons", [ hd; tl ]) -> json_array_spine tl (hd :: acc)
  | ( VCon (_, _) | VClos (_, _, _) | VNeut (_, _) | VErased | VLit _ | VPrim (_, _)
    | VIOAction _ ) ->
      Error (Error.Mismatch { expected = "Json array spine"; actual = "<malformed>" })

and json_object_spine (jv : v) (acc : (string * v) list) : ((string * v) list, Error.t) result
    =
  match jv with
  | VCon ("jobjNil", []) -> Ok (List.rev acc)
  | VCon ("jobjCons", [ VLit (Literal.LString k); pv; tl ]) -> json_object_spine tl ((k, pv) :: acc)
  | ( VCon (_, _) | VClos (_, _, _) | VNeut (_, _) | VErased | VLit _ | VPrim (_, _)
    | VIOAction _ ) ->
      Error (Error.Mismatch { expected = "Json object spine"; actual = "<malformed>" })

(* -------------------------- regex engine --------------------------- *)
(* M3 Stage C, C1: regexTest/regexMatch use OCaml's Str module (added
   to lib/dune's libraries; not Unix, not Sys, so the "no Unix, no Sys
   in lib/" rule holds), whose pattern dialect is Str's own (NOT
   PCRE). Div, not Tot: backtracking engines have catastrophic
   input/pattern pairs, so typing gives provenance and a composition
   discipline, never an operational termination proof; a hang here is
   an ACCEPTED, expected Div outcome (see dev/gates.sh's own external
   `timeout`-guarded pathological fixture), not a bug this engine
   tries to prevent.

   Error channels (M3 fixes, B1): Str signals three distinct things by
   exception, and they route differently here. A malformed PATTERN
   (Failure, at Str.regexp) is a real runtime error, routed by
   [regex_compile] to [Error.Regex_bad_pattern] through the ordinary
   Result channel, so a typo'd pattern in a guard errors instead of
   reading as a silent no-match (C19's fail-open shape). "No match" /
   "group did not participate" (Not_found, at Str.search_forward /
   Str.matched_group) is an ORDINARY outcome, fenced to [None] by
   [str_opt]. Invalid_argument (Str.matched_group past the compiled
   pattern's real group count) is unreachable with [regex_group_count]
   agreeing with Str's parser, but [str_opt] fences it too as a
   backstop: the no-exceptions promise says the process must not die
   even if the counter is ever wrong again (pre-fix it WAS wrong for
   classes and escaped backslashes, and the phantom group killed the
   whole process; O2). Never a bare `with _`: only the NAMED
   exceptions are caught, so Stack_overflow/Out_of_memory/Sys.Break
   still propagate, exactly as the house style's own try/with guidance
   requires. *)

(** Compile a pattern, routing [Str.regexp]'s own malformed-pattern
    channel ([Failure]) to a distinct error value (M3 fixes, B1/C19):
    a bad pattern is NEVER the same [None]/[false] a benign no-match
    produces. The payload carries the pattern and Str's reason. *)
let regex_compile (pattern : string) : (Str.regexp, Error.t) result =
  match Str.regexp pattern with
  | exception Failure msg -> Error (Error.Regex_bad_pattern (pattern ^ " (" ^ msg ^ ")"))
  | re -> Ok re

(** The no-match fence: [None] for [Not_found] (Str's designed "no
    match" / "group did not participate" signal), plus, as pure
    backstops, [Invalid_argument] (a group index past the compiled
    pattern's real count) and [Failure] (compile errors are caught
    earlier, at [regex_compile]). *)
let str_opt (f : unit -> 'a) : 'a option =
  match f () with
  | exception (Failure _ | Not_found | Invalid_argument _) -> None
  | v -> Some v

(** [regex_group_count]'s scanner state (M3 fixes, B1/O2). The Str
    dialect rules the transitions honor: `\(` opens a group ONLY when
    the backslash is read in [Scan_normal] (an escaped backslash `\\`
    consumes both chars, so it can never lend its backslash to a
    following `(`); `[` opens a character class, inside which a
    backslash is an ORDINARY member (Str classes have no escapes); `]`
    closes the class EXCEPT as its first member (`[]a]` and `[^]a]`
    keep the literal `]`, with `^` immediately after `[` preserving
    that first-member position). *)
type group_scan =
  | Scan_normal
  | Scan_backslash  (** just read `\` in [Scan_normal] *)
  | Scan_class_open  (** just read `[`: `^` complements, `]` is literal *)
  | Scan_class_neg  (** just read `[^`: `]` is still literal here *)
  | Scan_class_body  (** inside a class, past its first-member position *)

(** Count of `\(` group openers in [pattern], as Str's own parser
    reads it: a small state machine over [group_scan], agreeing with
    [Str.regexp]'s group numbering so [Str.matched_group] is never
    asked for a group the compiled pattern does not have (pre-fix, a
    two-char scan counted `\(` inside classes and after escaped
    backslashes too, and the resulting phantom group killed the
    process with an uncaught [Invalid_argument]; O2). *)
let regex_group_count (pattern : string) : int =
  let step ((st, n) : group_scan * int) (c : char) : group_scan * int =
    match st with
    | Scan_normal -> (
        match () with
        | () when Char.equal c '\\' -> (Scan_backslash, n)
        | () when Char.equal c '[' -> (Scan_class_open, n)
        | () -> (Scan_normal, n))
    | Scan_backslash -> if Char.equal c '(' then (Scan_normal, n + 1) else (Scan_normal, n)
    | Scan_class_open -> if Char.equal c '^' then (Scan_class_neg, n) else (Scan_class_body, n)
    | Scan_class_neg -> (Scan_class_body, n)
    | Scan_class_body -> if Char.equal c ']' then (Scan_normal, n) else (Scan_class_body, n)
  in
  let _st, n = List.fold_left step (Scan_normal, 0) (chars_of_string pattern) in
  n

let regex_test_run (pattern : string) (text : string) : (bool, Error.t) result =
  let* re = regex_compile pattern in
  Ok (str_opt (fun () -> Str.search_forward re text 0) |> Option.is_some)

(** [Ok None] on no match; [Ok (Some (whole :: groups))] on a match,
    one string per `\(...\)` group in the pattern's own left-to-right
    order, "" for a group that legitimately did not participate (an
    alternation's untaken side); [Error Regex_bad_pattern] when
    [Str.regexp] rejects the pattern itself (M3 fixes, B1/C19). *)
let regex_match_run (pattern : string) (text : string) : (string list option, Error.t) result
    =
  let* re = regex_compile pattern in
  str_opt (fun () -> Str.search_forward re text 0)
  |> Option.fold ~none:(Ok None) ~some:(fun (_pos : int) ->
         let whole = Str.matched_string text in
         let n_groups = regex_group_count pattern in
         let group_strs =
           List.init n_groups (fun i ->
               str_opt (fun () -> Str.matched_group (i + 1) text) |> Option.value ~default:"")
         in
         Ok (Some (whole :: group_strs)))

let rec exec (eglobals : globals) (env : v list) (e : Eterm.t) : (v, Error.t) result =
  match e with
  | Eterm.EVar ix -> List.nth_opt env ix |> Option.to_result ~none:(Error.Unbound_var ix)
  | Eterm.ELam (x, body) -> Ok (VClos (x, env, body))
  | Eterm.EApp (f, a) ->
      let* f_v = exec eglobals env f in
      let* a_v = exec eglobals env a in
      apply eglobals f_v a_v
  | Eterm.ELet (_x, def, body) ->
      let* def_v = exec eglobals env def in
      exec eglobals (def_v :: env) body
  | Eterm.EGlobal name ->
      let* g =
        Global.StringMap.find_opt name eglobals
        |> Option.to_result ~none:(Error.Unbound_global name)
      in
      g.grec_arg
      |> Option.fold ~none:(force eglobals g.gval) ~some:(fun _k ->
             Ok (VNeut (EHGlobal name, [])))
  | Eterm.EErased -> Ok VErased
  | Eterm.ELit l -> Ok (VLit l)
  | Eterm.EMatch (scrut, branches) ->
      let* scrut_v = exec eglobals env scrut in
      run_match eglobals env scrut_v branches

and run_match (eglobals : globals) (env : v list) (scrut_v : v)
    (branches : (string * string list * Eterm.t) list) : (v, Error.t) result =
  match scrut_v with
  | VCon (c, args) ->
      (* a miss is unreachable on checked programs; total backstop *)
      let* _c, binders, body =
        List.find_opt (fun (b, _bs, _body) -> String.equal b c) branches
        |> Option.to_result ~none:(Error.Branch_mismatch { expected = c; found = "<none>" })
      in
      if Int.equal (List.length binders) (List.length args) then
        exec eglobals (List.rev_append args env) body
      else
        Error (Error.Branch_mismatch { expected = c; found = c ^ " (wrong runtime arity)" })
  | VNeut (h, frames) -> Ok (VNeut (h, FEMatch (branches, env) :: frames))
  | VClos (_, _, _) | VErased | VLit _ | VPrim (_, _) | VIOAction _ ->
      Error (Error.Not_inductive "<runtime match on a non-constructor>")

and apply (eglobals : globals) (f : v) (a : v) : (v, Error.t) result =
  match f with
  | VClos (_x, env, body) -> exec eglobals (a :: env) body
  | VCon (c, args) -> Ok (VCon (c, args @ [ a ]))
  | VNeut (EHGlobal name, frames) ->
      let frames' = FEApp a :: frames in
      let stuck = VNeut (EHGlobal name, frames') in
      Global.StringMap.find_opt name eglobals
      |> Fun.flip Option.bind (fun (g : gentry) ->
             Option.map (fun k -> (g.gval, k)) g.grec_arg)
      |> Option.fold ~none:(Ok stuck) ~some:(fun (gbody, k) ->
             let oldest = List.rev frames' in
             let guarded =
               List.nth_opt (leading_fapp_args oldest) k
               |> Option.fold ~none:false ~some:(is_canonical eglobals)
             in
             if guarded then
               let* head_v = force eglobals gbody in
               replay eglobals head_v oldest
             else Ok stuck)
  | VNeut ((EHVar _ as h), frames) -> Ok (VNeut (h, FEApp a :: frames))
  | VErased -> Error (Error.Not_a_function "<erased>")
  | VLit _ -> Error (Error.Not_a_function "<literal value>")
  | VIOAction _ -> Error (Error.Not_a_function "<io action>")
  | VPrim (p, args) ->
      (* M3 fixes, C4' (C4, 2026-09-01): the spine accumulates NEWEST
         FIRST (cons, O(1) per application, the same convention as
         [VNeut]'s frames) and is reversed into argument order exactly
         once, at fire time; [quote] reverses at readback. *)
      let args' = a :: args in
      let n = List.length args' in
      (match () with
      | () when n < Prim.arity p -> Ok (VPrim (p, args'))
      | () when Int.equal n (Prim.arity p) -> fire_prim eglobals p (List.rev args')
      | () ->
          (* unreachable: an application past a prim's arity is a total
             backstop, since firing happens exactly at the arity. *)
          Error (Error.Prim_arity { prim = Prim.name p; expected = Prim.arity p; found = n }))

(** Force a [gbody] cell: an already-computed value is returned as is;
    a deferred closed erased term is [exec]'d ONCE, and the computed
    value is written back into the cell as [GForced], so every later
    force returns it without re-executing (M3 fixes, A2/C17,
    2026-09-01; since round 2, R2, EVERY user def arrives here
    deferred, not just the Div/IO-headed ones). Sound for every
    deferred kind: a pure body is a pure computation, a Div-headed
    body is pure modulo divergence, and an IO-headed body only BUILDS
    an inert action tree (identical on every rebuild; effects fire
    only when [Effect.run_io] walks it, once per walk). The pre-memo
    exponential re-execution of chained Div-headed defs is pinned by
    dev/gates.sh's PASS-B-DIV-MEMO gate over
    test/fixtures/x3-div-chain.tot. *)
and force (eglobals : globals) (gb : gbody ref) : (v, Error.t) result =
  match !gb with
  | GForced v -> Ok v
  | GDeferred e ->
      let* v = exec eglobals [] e in
      let () = gb := GForced v in
      Ok v

(** Replay a frame list (oldest first) on top of an unfolded head. Mirrors
    [Eval.replay]. *)
and replay (eglobals : globals) (head : v) (frames_oldest : eframe list) : (v, Error.t) result
    =
  List.fold_left
    (fun acc fr ->
      let* v = acc in
      match fr with
      | FEApp a -> apply eglobals v a
      | FEMatch (branches, menv) -> run_match eglobals menv v branches)
    (Ok head) frames_oldest

(** Fire a fully-applied prim on its accumulated (oldest-first) argument
    values. [Tot] and [Div] prims (M3 Stage A catalog, plus [pureDiv]
    and [bindDiv]) compute an ordinary value inline: under call-by-value
    a [Div]-typed argument has already been computed by the time it is
    one, so [Div] is a marker at the type level and costs nothing at
    runtime (M3 Stage B, verdict 3.2). [Io] prims never perform an
    OCaml effect here: they wrap their (undischarged) arguments as an
    inert [VIOAction]; only [surface/effect.ml]'s [run_io] ever walks
    one. Argument shapes are checked: a well-typed program can only
    reach the intended shape per prim, so a mismatch here is a total
    backstop, never reachable on a checked program. [eglobals] is used
    only by [Bind_div] (it applies the continuation to the already-
    computed inner value). *)
and fire_prim (eglobals : globals) (p : Prim.t) (args : v list) : (v, Error.t) result =
  let describe_shape (a : v) : string =
    match a with
    | VLit (Literal.LString _) -> "String"
    | VLit (Literal.LInt _) -> "Int"
    | VClos (_, _, _) -> "<function>"
    | VCon (c, _) -> c
    | VNeut (_, _) -> "<neutral>"
    | VErased -> "<erased>"
    | VPrim (q, _) -> Prim.name q
    | VIOAction _ -> "<io action>"
  in
  let str_arg (a : v) : (string, Error.t) result =
    match a with
    | VLit (Literal.LString s) -> Ok s
    | VLit (Literal.LInt _) | VClos (_, _, _) | VCon (_, _) | VNeut (_, _) | VErased
    | VPrim (_, _) | VIOAction _ ->
        Error (Error.Mismatch { expected = "String"; actual = describe_shape a })
  in
  let int_arg (a : v) : (int, Error.t) result =
    match a with
    | VLit (Literal.LInt n) -> Ok n
    | VLit (Literal.LString _) | VClos (_, _, _) | VCon (_, _) | VNeut (_, _) | VErased
    | VPrim (_, _) | VIOAction _ ->
        Error (Error.Mismatch { expected = "Int"; actual = describe_shape a })
  in
  let bool_of (b : bool) : v = if b then VCon ("true", []) else VCon ("false", []) in
  (* substring scan: total, no loop keyword, byte-wise. The [i + nlen >
     hlen] guard fires first, so the fallthrough arm's [String.sub] is
     always in range. *)
  let rec contains_from (hay : string) (needle : string) (i : int) : bool =
    let hlen = String.length hay in
    let nlen = String.length needle in
    match () with
    | () when i + nlen > hlen -> false
    | () when String.equal (String.sub hay i nlen (* @total-accessor: i + nlen <= hlen guarded above *)) needle -> true
    | () -> contains_from hay needle (i + 1)
  in
  let contains (hay : string) (needle : string) : bool =
    if Int.equal (String.length needle) 0 then true else contains_from hay needle 0
  in
  let* () =
    if Int.equal (List.length args) (Prim.arity p) then Ok ()
    else
      Error
        (Error.Prim_arity
           { prim = Prim.name p; expected = Prim.arity p; found = List.length args })
  in
  match (p, args) with
  | Prim.String_concat, [ a; b ] ->
      let* s1 = str_arg a in
      let* s2 = str_arg b in
      Ok (VLit (Literal.LString (s1 ^ s2)))
  | Prim.String_length, [ a ] ->
      let* s = str_arg a in
      Ok (VLit (Literal.LInt (String.length s)))
  | Prim.String_eq, [ a; b ] ->
      let* s1 = str_arg a in
      let* s2 = str_arg b in
      Ok (bool_of (String.equal s1 s2))
  | Prim.String_contains, [ a; b ] ->
      let* s1 = str_arg a in
      let* s2 = str_arg b in
      Ok (bool_of (contains s1 s2))
  | Prim.Int_add, [ a; b ] ->
      let* n1 = int_arg a in
      let* n2 = int_arg b in
      Ok (VLit (Literal.LInt (n1 + n2)))
  | Prim.Int_sub, [ a; b ] ->
      let* n1 = int_arg a in
      let* n2 = int_arg b in
      Ok (VLit (Literal.LInt (n1 - n2)))
  | Prim.Int_eq, [ a; b ] ->
      let* n1 = int_arg a in
      let* n2 = int_arg b in
      Ok (bool_of (Int.equal n1 n2))
  | Prim.Int_to_string, [ a ] ->
      let* n = int_arg a in
      Ok (VLit (Literal.LString (string_of_int n)))
  (* the ladder (M3 Stage B): pureDiv/bindDiv fire inline; pureIO,
     bindIO, liftIO and the four native IO prims only ever BUILD an
     action tree node, never perform the host effect it describes. *)
  | Prim.Pure_div, [ x ] -> Ok x
  | Prim.Bind_div, [ m; k ] -> apply eglobals k m
  | Prim.Pure_io, [ x ] -> Ok (VIOAction (IOPure x))
  | Prim.Bind_io, [ m; k ] -> Ok (VIOAction (IOBind (m, k)))
  | Prim.Lift_io, [ dv ] -> Ok (VIOAction (IOPure dv))
  | Prim.Read_stdin, [] -> Ok (VIOAction (IONative (Prim.Read_stdin, [])))
  | Prim.Print_line, [ s ] -> Ok (VIOAction (IONative (Prim.Print_line, [ s ])))
  | Prim.Exit_with, [ n ] -> Ok (VIOAction (IONative (Prim.Exit_with, [ n ])))
  | Prim.Get_env, [ s ] -> Ok (VIOAction (IONative (Prim.Get_env, [ s ])))
  (* M3 Stage C: the rest of the catalog. String_slice/String_split/
     String_to_int/Int_compare/Json_serialize are Tot; Json_parse/
     Regex_test/Regex_match are Div (fire inline, exactly like Tot,
     under call-by-value: see this function's own doc comment); the
     four native IO prims below only ever BUILD an action tree node,
     same as Stage B's four. *)
  | Prim.String_slice, [ a; b; c ] ->
      let* s = str_arg a in
      let* start = int_arg b in
      let* len = int_arg c in
      Ok
        (string_slice_opt s start len
        |> Option.fold ~none:(VCon ("none", [])) ~some:(fun sl ->
               VCon ("some", [ VLit (Literal.LString sl) ])))
  | Prim.String_split, [ a; b ] ->
      let* s = str_arg a in
      let* sep = str_arg b in
      Ok
        (List.fold_right
           (fun part acc -> VCon ("cons", [ VLit (Literal.LString part); acc ]))
           (string_split_on s sep) (VCon ("nil", [])))
  | Prim.String_to_int, [ a ] ->
      let* s = str_arg a in
      Ok
        (decimal_int_opt s
        |> Option.fold ~none:(VCon ("none", [])) ~some:(fun n ->
               VCon ("some", [ VLit (Literal.LInt n) ])))
  | Prim.Int_compare, [ a; b ] ->
      let* n1 = int_arg a in
      let* n2 = int_arg b in
      let tag =
        match () with
        | () when n1 < n2 -> "lt"
        | () when Int.equal n1 n2 -> "eq"
        | () -> "gt"
      in
      Ok (VCon (tag, []))
  | Prim.Json_parse, [ a ] ->
      let* s = str_arg a in
      Ok
        (json_parse_top s
        |> Option.fold ~none:(VCon ("none", [])) ~some:(fun jv -> VCon ("some", [ jv ])))
  | Prim.Json_serialize, [ a ] ->
      let* s = json_serialize a in
      Ok (VLit (Literal.LString s))
  | Prim.Regex_test, [ a; b ] ->
      let* pat = str_arg a in
      let* txt = str_arg b in
      let* hit = regex_test_run pat txt in
      Ok (bool_of hit)
  | Prim.Regex_match, [ a; b ] ->
      let* pat = str_arg a in
      let* txt = str_arg b in
      let list_of (strs : string list) : v =
        List.fold_right
          (fun s acc -> VCon ("cons", [ VLit (Literal.LString s); acc ]))
          strs (VCon ("nil", []))
      in
      let* matched = regex_match_run pat txt in
      Ok
        (matched
        |> Option.fold ~none:(VCon ("none", [])) ~some:(fun strs ->
               VCon ("some", [ list_of strs ])))
  | Prim.Read_file, [ path ] -> Ok (VIOAction (IONative (Prim.Read_file, [ path ])))
  | Prim.Write_file, [ path; content ] ->
      Ok (VIOAction (IONative (Prim.Write_file, [ path; content ])))
  | Prim.Argv, [] -> Ok (VIOAction (IONative (Prim.Argv, [])))
  | Prim.Proc_run, [ cmd; cmd_args ] ->
      Ok (VIOAction (IONative (Prim.Proc_run, [ cmd; cmd_args ])))
  | ( ( Prim.String_concat | Prim.String_length | Prim.String_eq | Prim.String_contains
      | Prim.Int_add | Prim.Int_sub | Prim.Int_eq | Prim.Int_to_string | Prim.Pure_div
      | Prim.Bind_div | Prim.Pure_io | Prim.Bind_io | Prim.Lift_io | Prim.Read_stdin
      | Prim.Print_line | Prim.Exit_with | Prim.Get_env | Prim.String_slice
      | Prim.String_split | Prim.String_to_int | Prim.Int_compare | Prim.Read_file
      | Prim.Write_file | Prim.Argv | Prim.Proc_run | Prim.Json_parse | Prim.Json_serialize
      | Prim.Regex_test | Prim.Regex_match ),
      _ ) ->
      (* unreachable: the length check above already fixed [List.length
         args] to [Prim.arity p], so every prim's own arm above matches
         its exact arity; total backstop only. *)
      Error
        (Error.Prim_arity
           { prim = Prim.name p; expected = Prim.arity p; found = List.length args })

(** Record a user def as a lazy MEMOIZED thunk (M3 fixes round 2, R2:
    every def, not just the Div/IO-headed ones the M3 Stage B rule
    deferred).  Nothing executes here: the body runs on first [force]
    (an eval item or [main] reaching it) and the memo cell keeps
    single-execution, so DEAD code (a def [main] never mentions) can
    neither abort nor hang a run.  Sound because laziness is
    observationally invisible: [Div] carries no host effects and an
    [IO] body only builds an inert action tree.  Erasure and
    closedness are the caller's eager duty ([def] is already a closed
    [Eterm.t]); the one observable shift is that a LIVE def's
    definition-time abort now surfaces at force time.  Total: no body
    execution means no error path, hence no [result]. *)
let define (eglobals : globals) ~(name : string) ~(rec_arg : int option) (def : Eterm.t) :
    globals =
  Global.StringMap.add name
    { gval = ref (GDeferred def); grec_arg = rec_arg; gctor_arity = None }
    eglobals

(** Seed a data constructor: it accumulates its runtime (KEPT) arguments
    up to [arity]. *)
let add_ctor (eglobals : globals) ~(name : string) ~(arity : int) : globals =
  Global.StringMap.add name
    { gval = ref (GForced (VCon (name, []))); grec_arg = None; gctor_arity = Some arity }
    eglobals

(** Seed a type constructor: types are inert at runtime. *)
let add_erased (eglobals : globals) ~(name : string) : globals =
  Global.StringMap.add name
    { gval = ref (GForced VErased); grec_arg = None; gctor_arity = None }
    eglobals

(** Seed a native prim (M3 Stage A). TRAP: a prim of arity 0 can never
    fire on application (there is no application to trigger it), so it
    is fired right here at seed time and the RESULT is stored; every
    other prim starts as an empty [VPrim] spine. [readStdin] (M3 Stage
    B) is the first arity-0 prim this hits: its stored [gval] is
    already [GForced (VIOAction (IONative (Read_stdin, [])))], which
    performs nothing (that is the whole point). *)
let add_prim (eglobals : globals) ~(name : string) ~(prim : Prim.t) :
    (globals, Error.t) result =
  let* v =
    if Int.equal (Prim.arity prim) 0 then fire_prim eglobals prim [] else Ok (VPrim (prim, []))
  in
  Ok
    (Global.StringMap.add name
       { gval = ref (GForced v); grec_arg = None; gctor_arity = None }
       eglobals)

let rec quote (eglobals : globals) (size : int) (v : v) : (Eterm.t, Error.t) result =
  match v with
  | VClos (x, _env, _body) as clo ->
      let* body_v = apply eglobals clo (VNeut (EHVar size, [])) in
      let* body_e = quote eglobals (size + 1) body_v in
      Ok (Eterm.ELam (x, body_e))
  | VCon (c, args) ->
      List.fold_left
        (fun acc arg ->
          let* f = acc in
          let* arg_e = quote eglobals size arg in
          Ok (Eterm.EApp (f, arg_e)))
        (Ok (Eterm.EGlobal c)) args
  | VNeut (h, frames) ->
      let* head_e =
        match h with
        | EHVar lvl ->
            let ix = size - lvl - 1 in
            if ix >= 0 then Ok (Eterm.EVar ix) else Error (Error.Bad_level lvl)
        | EHGlobal name -> Ok (Eterm.EGlobal name)
      in
      List.fold_left
        (fun acc fr ->
          let* f = acc in
          match fr with
          | FEApp arg ->
              let* arg_e = quote eglobals size arg in
              Ok (Eterm.EApp (f, arg_e))
          | FEMatch (branches, menv) ->
              let* branches_e =
                List.fold_left
                  (fun bacc (c, binders, body) ->
                    let* done_ = bacc in
                    let arity = List.length binders in
                    let fresh_env =
                      List.init arity (fun i -> VNeut (EHVar (size + arity - 1 - i), []))
                    in
                    let* body_v = exec eglobals (fresh_env @ menv) body in
                    let* body_e = quote eglobals (size + arity) body_v in
                    Ok ((c, binders, body_e) :: done_))
                  (Ok []) branches
                |> Result.map List.rev
              in
              Ok (Eterm.EMatch (f, branches_e)))
        (Ok head_e) (List.rev frames)
  | VErased -> Ok Eterm.EErased
  | VLit l -> Ok (Eterm.ELit l)
  | VPrim (p, args) ->
      (* rebuilds the frozen spine: EApp folded over EGlobal (Prim.name
         p) in argument order (decision 8 of the M3 design verdict).
         The stored spine is newest first (M3 fixes, C4'), so reverse
         before folding. *)
      List.fold_left
        (fun acc arg ->
          let* f = acc in
          let* arg_e = quote eglobals size arg in
          Ok (Eterm.EApp (f, arg_e)))
        (Ok (Eterm.EGlobal (Prim.name p)))
        (List.rev args)
  | VIOAction _ ->
      (* M3 Stage B, decision 8: readback has no syntax for a reified IO
         action; an [eval] item over an IO expression therefore reports
         this error rather than printing a half-value. Sequencing an IO
         script goes through [main] (surface/run.ml's epilogue), which
         calls [Effect.run_io] directly and never quotes the result. *)
      Error (Error.Not_quotable "io action")
