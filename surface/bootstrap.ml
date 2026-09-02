(** The builtin environment (M3 Stages A-C). Declares the base type
    formers ([String], [Int], and as of Stage B [Div]/[IO]) and seeds
    the prim catalog, in THREE phases because a prim's type may
    mention a prelude data type ([Bool], [Unit], [Option], and as of
    Stage C [List], [Result], [Ordering], [Json], [ProcessResult])
    that does not exist until (part of) the prelude has folded, and
    (M3 Stage C) the prelude's OWN later content may itself call an
    earlier phase's prim ([jsonGet] calls [stringEq]). [state ()]
    interleaves all three phases with THREE prelude-fold segments
    accordingly; see its own doc comment for the exact ordering
    argument. Tests can start from a fully seeded environment from
    Stage A on; [bin/tot.ml] starts using it in Stage D. *)

open Tot_kernel

let ( let* ) = Result.bind

(** Builtin type formers, each with its OWN params telescope. Declared-
    only (never [define_ind]'d), so nothing can eliminate them:
    [String]/[Int]/[Div]/[IO] stay zero-constructor forever, the same
    shape the M2 fix batch made illegal to eliminate ([Ind_incomplete])
    for a mid-declaration inductive. [Div] and [IO] (M3 Stage B) each
    carry ONE quantity-0 param, so their stored type is
    [(0 A : Type 0) -> Type 0]. *)
let builtin_types : (string * Global.telescope) list =
  [
    ("String", []);
    ("Int", []);
    ("Div", [ (Quantity.Zero, "A", Term.Univ Level.zero) ]);
    ("IO", [ (Quantity.Zero, "A", Term.Univ Level.zero) ]);
  ]

(** Ctor names a prim builds by hand (see [Interp.fire_prim] and
    [Effect.dispatch]), PLUS (M3 Stage C, C2) every ctor a Stage C
    prelude data declaration ([Ordering], [Verdict], [ProcessResult],
    [Json]) introduces, whether or not a Stage C prim happens to build
    it by hand yet: verified to resolve in BOTH environments once the
    prelude has folded, catching a prelude typo/ordering bug at
    bootstrap time rather than at first use. M3 Stage B added [unit]
    (printLine/exitWith's [Unit] result) and [none]/[some] (getEnv's
    [Option String] result). M3 Stage C adds: [lt]/[eq]/[gt]
    ([intCompare]'s hand-built [Ordering] result), [ok]/[err]
    ([readFile]/[writeFile]'s hand-built [Result] results),
    [nil]/[cons] ([stringSplit]/[jsonParse]/[regexMatch]'s hand-built
    [List] spines), [mkProcessResult] ([procRun]'s hand-built
    result), the eight [Json] constructors ([jsonParse]'s hand-built
    tree), and [allow]/[ask]/[deny] ([Verdict]'s constructors; no
    Stage C prim builds one yet, but this bootstrap-time check is
    exactly the early-typo guard Stage D's hook protocol will lean
    on). *)
let required_ctors : string list =
  [
    "true";
    "false";
    "unit";
    "none";
    "some";
    "lt";
    "eq";
    "gt";
    "ok";
    "err";
    "nil";
    "cons";
    "mkProcessResult";
    "jnull";
    "jbool";
    "jnum";
    "jstr";
    "jarrNil";
    "jarrCons";
    "jobjNil";
    "jobjCons";
    "allow";
    "ask";
    "deny";
  ]

(** The number of quantity-[Many] (KEPT) [Pi] binders in a parsed source
    type, following the arrow chain outermost first. Exported so
    test/main.ml can pin every catalog prim's [Prim.arity] against its
    OWN declared type (M3 Stage B, B9 test 1). *)
let rec kept_pi_count (s : Syntax.t) : int =
  match s with
  | Syntax.SPi (_, Quantity.Many, _, _, cod) -> 1 + kept_pi_count cod
  | Syntax.SPi (_, Quantity.Zero, _, _, cod) -> kept_pi_count cod
  | Syntax.SVar (_, _) | Syntax.SType (_, _) | Syntax.SLam (_, _, _)
  | Syntax.SApp (_, _, _) | Syntax.SLet (_, _, _, _, _) | Syntax.SAnn (_, _, _)
  | Syntax.SMatch (_, _, _, _) | Syntax.SStr (_, _) | Syntax.SInt (_, _)
  | Syntax.SLetStar (_, _, _, _, _, _, _) ->
      0

(** Phase-1 prims: their source-text type mentions only builtins. M3
    Stage B adds the five ladder prims (verdict 3.2); [pureIO]'s KEPT
    arity is 1, NOT 2 (the plan's own correction to the monadic
    proposal's arity table, decision 4). *)
let phase1_prims : (string * string * Prim.t) list =
  [
    ("stringConcat", "String -> String -> String", Prim.String_concat);
    ("stringLength", "String -> Int", Prim.String_length);
    ("intAdd", "Int -> Int -> Int", Prim.Int_add);
    ("intSub", "Int -> Int -> Int", Prim.Int_sub);
    ("intToString", "Int -> String", Prim.Int_to_string);
    ("pureDiv", "(0 A : Type 0) -> A -> Div A", Prim.Pure_div);
    ("bindDiv", "(0 A : Type 0) -> (0 B : Type 0) -> Div A -> (A -> Div B) -> Div B", Prim.Bind_div);
    ("pureIO", "(0 A : Type 0) -> A -> IO A", Prim.Pure_io);
    ("bindIO", "(0 A : Type 0) -> (0 B : Type 0) -> IO A -> (A -> IO B) -> IO B", Prim.Bind_io);
    ("liftIO", "(0 A : Type 0) -> Div A -> IO A", Prim.Lift_io);
  ]

(** Phase-2 prims: their source-text type mentions [Bool], [Unit] or
    [Option], which the ORIGINAL (M2-carried) prelude content declares
    (everything through "foldNat"; see [state ()]'s own doc comment
    for why this stage needs a THIRD prelude-fold segment, not just a
    third phase). M3 Stage B adds the four native IO prims. *)
let phase2_prims : (string * string * Prim.t) list =
  [
    ("stringEq", "String -> String -> Bool", Prim.String_eq);
    ("stringContains", "String -> String -> Bool", Prim.String_contains);
    ("intEq", "Int -> Int -> Bool", Prim.Int_eq);
    ("readStdin", "IO String", Prim.Read_stdin);
    ("printLine", "String -> IO Unit", Prim.Print_line);
    ("exitWith", "Int -> IO Unit", Prim.Exit_with);
    ("getEnv", "String -> IO (Option String)", Prim.Get_env);
  ]

(** Phase-3 prims (M3 Stage C, C1): the rest of the catalog. Every one
    of these twelve mentions [List]/[Result]/[Ordering]/[Json]/
    [ProcessResult], so all twelve wait for the prelude's Stage C DATA
    segment (Ordering/Verdict/ProcessResult/Json) to fold first, which
    is why [state ()] runs this phase strictly BETWEEN that data
    segment and the prelude's Stage C DEF segment ([jsonGet] and
    friends, which in turn need phase-2's [stringEq] to already be
    seeded: this is the ordering conflict this stage's [state ()]
    restructuring exists to resolve). *)
let phase3_prims : (string * string * Prim.t) list =
  [
    ("stringSlice", "String -> Int -> Int -> Option String", Prim.String_slice);
    ("stringSplit", "String -> String -> List String", Prim.String_split);
    ("stringToInt", "String -> Option Int", Prim.String_to_int);
    ("intCompare", "Int -> Int -> Ordering", Prim.Int_compare);
    ("readFile", "String -> IO (Result String String)", Prim.Read_file);
    ("writeFile", "String -> String -> IO (Result Unit String)", Prim.Write_file);
    ("argv", "IO (List String)", Prim.Argv);
    ("procRun", "String -> List String -> IO ProcessResult", Prim.Proc_run);
    ("jsonParse", "String -> Div (Option Json)", Prim.Json_parse);
    ("jsonSerialize", "Json -> String", Prim.Json_serialize);
    ("regexTest", "String -> String -> Div Bool", Prim.Regex_test);
    ("regexMatch", "String -> String -> Div (Option (List String))", Prim.Regex_match);
  ]

(** Elaborate and check one prim's type from source text, then install
    it in both environments. B9 test 1's own correction, enforced HERE
    too (M3 Stage B, decision 4 / B1): [Prim.arity prim] must equal the
    KEPT-Pi count of the type this very function parses, or the
    bootstrap itself fails with [Error.Prim_arity] rather than silently
    installing a prim whose runtime accumulation arity disagrees with
    its declared type. *)
let seed_prim (st : Run.state) ((name, ty_src, prim) : string * string * Prim.t) :
    (Run.state, Serror.t) result =
  let* tokens = Lexer.lex ty_src in
  let* syn = Parser.term_only tokens in
  let* () =
    let want = Prim.arity prim in
    let got = kept_pi_count syn in
    if Int.equal want got then Ok ()
    else
      Error
        (Serror.Kernel
           { loc = Loc.start; err = Error.Prim_arity { prim = name; expected = want; found = got } })
  in
  let* ty_t = Elab.term st.Run.globals [] syn in
  let* globals = Run.kernel Loc.start (Check.define_prim st.Run.globals ~name ~ty:ty_t ~prim) in
  let* eglobals = Run.kernel Loc.start (Interp.add_prim st.Run.eglobals ~name ~prim) in
  Ok { st with Run.globals; eglobals }

(** Seed every prim in [table], in order. Shared by every phase below
    (M3 Stage C factors this out of what used to be phase1's and
    phase2's own inline folds, once a THIRD prim-seeding phase needed
    the identical fold). *)
let seed_prims (st : Run.state) (table : (string * string * Prim.t) list) :
    (Run.state, Serror.t) result =
  List.fold_left (fun acc p -> let* s = acc in seed_prim s p) (Ok st) table

(** Declare every builtin type former (with its own params telescope),
    then seed every phase-1 prim. *)
let phase1 () : (Run.state, Serror.t) result =
  let* seeded =
    List.fold_left
      (fun acc (name, params) ->
        let* st = acc in
        let* globals =
          Run.kernel Loc.start
            (Check.declare_ind st.Run.globals ~name ~params ~level:Level.zero)
        in
        let eglobals = Interp.add_erased st.Run.eglobals ~name in
        Ok { st with Run.globals; eglobals })
      (Ok Run.initial) builtin_types
  in
  seed_prims seeded phase1_prims

(** Seed every phase-2 prim ([stringEq] and its six siblings). No
    ctor-verification tail any more (M3 Stage C): [required_ctors] now
    names ctors that only exist after the prelude's Stage C DATA
    segment folds too, so that check moves to [verify_required_ctors],
    run once at the very end of [state ()]. *)
let phase2 (st : Run.state) : (Run.state, Serror.t) result = seed_prims st phase2_prims

(** Seed every phase-3 prim (M3 Stage C, C1: the rest of the catalog).
    See [phase3_prims]'s own doc comment for why this runs where it
    does in [state ()]. *)
let phase3 (st : Run.state) : (Run.state, Serror.t) result = seed_prims st phase3_prims

(** Verify every [required_ctors] name resolves in BOTH environments.
    Split out of the old [phase2] (M3 Stage C): now runs once, at the
    very end of [state ()], after every prelude segment has folded and
    every phase has seeded, since [required_ctors] names ctors from
    both the M2-carried prelude content and its Stage C DATA
    segment. *)
let verify_required_ctors (st : Run.state) : (Run.state, Serror.t) result =
  let* () =
    List.fold_left
      (fun acc name ->
        let* () = acc in
        if
          Option.is_some (Global.find name st.Run.globals)
          && Option.is_some (Global.StringMap.find_opt name st.Run.eglobals)
        then Ok ()
        else Error (Serror.Kernel { loc = Loc.start; err = Error.Missing_prelude_ctor name }))
      (Ok ()) required_ctors
  in
  Ok st

(** The prelude source path this executable resolves by default: two
    directories up from the running binary (e.g.
    [<root>/_build/default/bin/tot.exe] or
    [<root>/_build/default/test/surface.exe], both one level under
    [_build/default]) lands on [_build/default]; two more strip
    [_build/default] back off, landing on the repo root. *)
let default_prelude_path () : string =
  let build_default = Sys.executable_name |> Filename.dirname |> Filename.dirname in
  let repo_root = build_default |> Filename.dirname |> Filename.dirname in
  Filename.concat repo_root "stdlib/prelude.tot"

(** [TOT_PRELUDE], when set, overrides [default_prelude_path]. *)
let prelude_path () : string =
  Sys.getenv_opt "TOT_PRELUDE" |> Option.value ~default:(default_prelude_path ())

(** Read the prelude source. [Sys.file_exists] turns the common
    missing-file case into a clean [Result] error; the residual
    raise-on-permission-race inside [In_channel.with_open_text] is the
    SAME documented SPEC debt [bin/tot.ml]'s own file read already
    accepts (an unguarded read, not a caught host-boundary exception),
    not a new one this milestone adds. *)
let read_prelude_src (path : string) : (string, Serror.t) result =
  if Sys.file_exists path then Ok (In_channel.with_open_text path In_channel.input_all)
  else Error (Serror.Lex { loc = Loc.start; msg = "prelude not found: " ^ path })

(** The [Syntax.item]'s own declared name, when it has one; used only
    to locate [state ()]'s two prelude-fold split points by NAME
    (robust to future line-editing of stdlib/prelude.tot, unlike a
    magic item-index would be). *)
let item_name (it : Syntax.item) : string option =
  match it with
  | Syntax.IDef { name; _ } -> Some name
  | Syntax.IData { name; _ } -> Some name
  | Syntax.ICheck (_, _) | Syntax.IEval (_, _) -> None

(** Split [items] right after the FIRST item named [target]: [Some
    (through_and_including_target, after)]; [None] if no item is named
    [target]. Tail-recursive over an accumulator (M3 fixes round 3,
    ctxcat id 8: the old [Option.map]-after-the-call shape stacked one
    frame per item). *)
let split_after_name (target : string) (items : Syntax.item list) :
    (Syntax.item list * Syntax.item list) option =
  let rec go (rev_before : Syntax.item list) (rest : Syntax.item list) :
      (Syntax.item list * Syntax.item list) option =
    match rest with
    | [] -> None
    | it :: rest' ->
        if item_name it |> Option.fold ~none:false ~some:(String.equal target) then
          Some (List.rev (it :: rev_before), rest')
        else go (it :: rev_before) rest'
  in
  go [] items

let fold_items (st : Run.state) (items : Syntax.item list) : (Run.state, Serror.t) result =
  List.fold_left (fun acc it -> let* s = acc in Run.item ~exec:true s it) (Ok st) items

(** Run [phase1], then fold [stdlib/prelude.tot] and seed the
    remaining phases TOGETHER, interleaved (M3 Stage C): the prelude's
    Stage C DEF segment ([jsonGet] and friends, added after the [Json]
    data declaration) calls [stringEq], a phase-2 prim, so phase-2
    must seed BEFORE that segment folds; but phase-2's own type
    ([String -> String -> Bool]) only needs [Bool], available already
    from the prelude's ORIGINAL (M2-carried) content ending at
    "foldNat". Symmetrically, phase-3's twelve prims need [Ordering]/
    [Json]/[ProcessResult] (the prelude's Stage C DATA segment, ending
    at "Json"), so phase-3 must seed AFTER that segment folds but
    (like phase-2) can run BEFORE the Stage C DEF segment that follows
    it, since no accessor def actually calls a phase-3 prim. The
    three prelude segments this splits on, in file order: (1) the
    ORIGINAL M2 prelude content through "foldNat"; (2) the Stage C
    DATA segment (Ordering/Verdict/ProcessResult/Json) through "Json";
    (3) the Stage C DEF segment (headOr and the Json accessors). Trace
    lines reset ONCE, at the very end, so the prelude's own output
    never leaks into a script's; [verify_required_ctors] runs last,
    once every phase has seeded and every segment has folded. Tests
    use this from Stage A on. *)
let state () : (Run.state, Serror.t) result =
  let* st1 = phase1 () in
  let* src = read_prelude_src (prelude_path ()) in
  let* tokens = Lexer.lex src in
  let* syn_items = Parser.parse tokens in
  let not_found (marker : string) : Serror.t =
    Serror.Lex
      { loc = Loc.start; msg = "prelude: \"" ^ marker ^ "\" marker not found (Stage C phase split)" }
  in
  let* seg1, rest1 =
    split_after_name "foldNat" syn_items |> Option.to_result ~none:(not_found "foldNat")
  in
  let* seg2, seg3 = split_after_name "Json" rest1 |> Option.to_result ~none:(not_found "Json") in
  let* st_a = fold_items st1 seg1 in
  let* st_b = phase2 st_a in
  let* st_c = fold_items st_b seg2 in
  let* st_d = phase3 st_c in
  let* st_e = fold_items st_d seg3 in
  verify_required_ctors { st_e with Run.lines = [] }

(** [TOT_CACHE_VERIFY=1] recomputes [state ()] on every cache HIT too,
    purely to COMPARE against the cached blob, never to replace the
    fast path's own result (M3 Stage D, D2). Prints one line on
    stderr; dev/gates.sh's Gate D (ii) reads exactly this line. *)
let cache_verify_flag () : bool =
  Sys.getenv_opt "TOT_CACHE_VERIFY" |> Option.fold ~none:false ~some:(String.equal "1")

(** M3 Stage D, D1+D2: the bootstrapped starting state, cache-backed.
    A cache HIT (keyed on the prelude's own source bytes, [Cache.key])
    rebuilds [Run.state] directly from the stored [(Global.t,
    Interp.globals)] pair -- no re-lexing, no re-elaborating, no
    re-checking. A MISS falls back to [state ()] (the full cold path)
    and opportunistically writes the result back for next time. See
    [Cache]'s own module doc comment for the full correctness argument
    ("the same key always implies byte-identical output"). [bin/tot.ml]
    calls this once per invocation; test/surface.ml's own tests call
    [state ()] directly, exercising the COLD path on every run (a
    cache hit would only make the SAME assertions faster, never
    different, given that correctness argument). *)
let cached_state () : (Run.state, Serror.t) result =
  let* src = read_prelude_src (prelude_path ()) in
  let cache_key = Cache.key src in
  (* M3 fixes round 2 (ctxcat id 12): dispatch on the load result
     directly ([Option.to_result] + [Result.fold], both branches a
     closure, so the expensive cold path never evaluates on a hit)
     instead of the old is_some check followed by a throwaway-default
     re-unwrap of the same option. *)
  Cache.load cache_key
  |> Option.to_result ~none:()
  |> Result.fold
       ~ok:(fun (globals, eglobals) ->
         let () =
           if cache_verify_flag () then
             state ()
             |> Result.fold
                  ~ok:(fun fresh ->
                    let cold_bytes = Marshal.to_string (fresh.Run.globals, fresh.Run.eglobals) [] in
                    let cached_bytes = Marshal.to_string (globals, eglobals) [] in
                    if String.equal cold_bytes cached_bytes then
                      prerr_endline "TOT-CACHE-VERIFY-OK"
                    else prerr_endline "TOT-CACHE-VERIFY-MISMATCH")
                  ~error:(fun e -> prerr_endline ("TOT-CACHE-VERIFY-ERROR: " ^ Serror.to_string e))
           else ()
         in
         Ok { Run.globals; eglobals; lines = [] })
       ~error:(fun () ->
         let* st = state () in
         let () = Cache.save cache_key st.Run.globals st.Run.eglobals in
         Ok st)
