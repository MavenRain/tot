(** Recursive-descent parser over the token list. Backtracking is free on
    immutable lists: [try_binder_group] speculatively parses "(q x .. : T)"
    and commits only when ") ->" follows; any inner failure falls back to
    the application/arrow-sugar path. Error arms bind named token/list
    variables and report via [Token.describe]. *)

open Tot_kernel

let ( let* ) = Result.bind

let parse_err (loc : Loc.t) (msg : string) : ('a, Serror.t) result =
  Error (Serror.Parse { loc; msg })

(** M4 Stage A: a short, human-readable description of a parsed term's
    outermost shape, for the data-codomain peel's "expected 'Type',
    found ..." error (the codomain is peeled from an already-parsed
    [Syntax.t], not from raw tokens, so [Token.describe] is unavailable
    there). *)
let describe_syntax (s : Syntax.t) : string =
  match s with
  | Syntax.SVar (_, x) -> "identifier " ^ x
  | Syntax.SType (_, _) -> "'Type'"
  | Syntax.SPi (_, _, _, _, _) -> "a function type"
  | Syntax.SLam (_, _, _) -> "a function"
  | Syntax.SApp (_, _, _) -> "an application"
  | Syntax.SLet (_, _, _, _, _) -> "a let expression"
  | Syntax.SAnn (_, _, _) -> "an annotated term"
  | Syntax.SMatch (_, _, _, _) -> "a match expression"
  | Syntax.SStr (_, _) -> "a string literal"
  | Syntax.SInt (_, n) -> "number " ^ string_of_int n
  | Syntax.SLetStar (_, _, _, _, _, _, _) -> "a let* expression"
  | Syntax.SAuto _ -> "'auto'"
  | Syntax.SInst (_, _, _) -> "an 'inst' expression"
  | Syntax.SHole _ -> "'_'"

let eof_err : ('a, Serror.t) result =
  (* unreachable: the lexer always materializes an Eof token *)
  parse_err Loc.start "unexpected end of input"

let kind_starts_atom (k : Token.kind) : bool =
  match k with
  | Token.Ident _ | Token.KType | Token.LParen | Token.Nat _ | Token.Str _ | Token.KAuto
  | Token.Underscore ->
      true
  | Token.RParen | Token.Colon | Token.ColonEq | Token.Arrow | Token.DArrow
  | Token.KFun | Token.KLet | Token.KIn | Token.KDef | Token.KReducible | Token.KEval
  | Token.KCheck | Token.KData | Token.KMatch | Token.KWith | Token.KAs | Token.KReturn
  | Token.KRec | Token.KEnd | Token.KLetStar | Token.KLetStarDiv | Token.KPartial
  | Token.KAxiom | Token.KClass | Token.KInstance | Token.KInst
  | Token.LBrace | Token.RBrace | Token.Semi
  | Token.Pipe | Token.Eof ->
      false

let starts_atom (ts : Token.t list) : bool =
  match ts with
  | { Token.kind; loc = _ } :: _rest -> kind_starts_atom kind
  | [] -> false

(** Gather zero or more consecutive identifiers. Total: never fails. *)
let rec collect_idents (ts : Token.t list) : string list * Token.t list =
  match ts with
  | { Token.kind = Token.Ident x; loc = _ } :: rest ->
      let names, rest' = collect_idents rest in
      (x :: names, rest')
  | { Token.kind = Token.Underscore; loc = _ } :: rest ->
      (* M6 Stage C (ruling R2): the anonymous binder, named "_" *)
      let names, rest' = collect_idents rest in
      ("_" :: names, rest')
  | ({ Token.kind = _; loc = _ } :: _ | []) as same -> ([], same)

(** First name that occurs twice in the list, if any. Total.  M6 Stage
    C (design note C13-N4): "_" entries are skipped, since two
    anonymous binders collide only if [_] can be referenced, and the
    reservation makes that impossible. *)
let rec find_dup (xs : string list) : string option =
  match xs with
  | [] -> None
  | x :: rest ->
      if (not (String.equal x "_")) && List.exists (String.equal x) rest then Some x
      else find_dup rest

(** M6 Stage C (ruling R2): the name a BINDER-position token binds,
    an identifier's own name or "_" for the anonymous binder.  Total:
    every caller has already matched [Ident _ | Underscore], so the
    "_" fallback for the remaining kinds is never reached. *)
let binder_name (k : Token.kind) : string =
  match k with
  | Token.Ident x -> x
  | Token.Underscore | Token.KType | Token.LParen | Token.Nat _ | Token.Str _ | Token.KAuto
  | Token.RParen | Token.Colon | Token.ColonEq | Token.Arrow | Token.DArrow
  | Token.KFun | Token.KLet | Token.KIn | Token.KDef | Token.KReducible | Token.KEval
  | Token.KCheck | Token.KData | Token.KMatch | Token.KWith | Token.KAs | Token.KReturn
  | Token.KRec | Token.KEnd | Token.KLetStar | Token.KLetStarDiv | Token.KPartial
  | Token.KAxiom | Token.KClass | Token.KInstance | Token.KInst
  | Token.LBrace | Token.RBrace | Token.Semi
  | Token.Pipe | Token.Eof ->
      "_"

(** The optional quantity marker at the head of a binder group. "0" means
    Zero. "w" is a Many marker ONLY when another identifier follows it;
    otherwise "w" is the binder's own name and the default (Many)
    applies. *)
let quantity_prefix (ts : Token.t list) : Quantity.t * Token.t list =
  match ts with
  | { Token.kind = Token.Nat 0; loc = _ } :: rest -> (Quantity.Zero, rest)
  | { Token.kind = Token.Ident "w"; loc = _ }
    :: ({ Token.kind = Token.Ident _ | Token.Underscore; loc = _ } :: _rest2 as rest) ->
      (* M6 Stage C: [_] is a binder follower too, so "(w _ : Nat)" is
         ONE anonymous Many binder, the printer's own spelling *)
      (Quantity.Many, rest)
  | ({ Token.kind = _; loc = _ } :: _ | []) as same -> (Quantity.Many, same)

let rec parse_term (ts : Token.t list) : (Syntax.t * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.KFun; loc } :: rest -> parse_fun loc rest
  | { Token.kind = Token.KLet; loc } :: rest -> parse_let loc rest
  | { Token.kind = Token.KLetStar; loc } :: rest -> parse_let_star loc ~is_div:false rest
  | { Token.kind = Token.KLetStarDiv; loc } :: rest -> parse_let_star loc ~is_div:true rest
  | { Token.kind = Token.KMatch; loc } :: rest -> parse_match loc rest
  | { Token.kind = Token.KInst; loc } :: rest -> parse_inst loc rest
  | ({ Token.kind = _; loc = _ } :: _ | []) -> parse_arrow ts

(** "inst C T", pure sugar (D3): [C] and [T] are each ONE atom, the same
    FALLBACK SHAPE [parse_let_star]'s own two type arguments use (a
    compound type needs parens, e.g. "inst EqD (List Int)").  This is the
    whole implementation;  [Elab] does the rest. *)
and parse_inst (loc : Loc.t) (ts : Token.t list) : (Syntax.t * Token.t list, Serror.t) result =
  let* c, rest = parse_atom ts in
  let* t, rest2 = parse_atom rest in
  Ok (Syntax.SInst (loc, c, t), rest2)

and parse_fun (loc : Loc.t) (ts : Token.t list) :
    (Syntax.t * Token.t list, Serror.t) result =
  match collect_idents ts with
  | [], rest ->
      (match rest with
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected a binder after 'fun', found " ^ Token.describe kind)
      | [] -> eof_err)
  | (_x :: _xs as names), rest ->
      (match rest with
      | { Token.kind = Token.DArrow; loc = _ } :: rest2 ->
          let* body, rest3 = parse_term rest2 in
          Ok (List.fold_right (fun x acc -> Syntax.SLam (loc, x, acc)) names body, rest3)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected '=>', found " ^ Token.describe kind)
      | [] -> eof_err)

and parse_let (loc : Loc.t) (ts : Token.t list) :
    (Syntax.t * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Ident _ | Token.Underscore as k; loc = _ }
    :: { Token.kind = Token.Colon; loc = _ }
    :: rest ->
      let x = binder_name k in
      let* ty, rest2 = parse_term rest in
      (match rest2 with
      | { Token.kind = Token.ColonEq; loc = _ } :: rest3 ->
          let* def, rest4 = parse_term rest3 in
          (match rest4 with
          | { Token.kind = Token.KIn; loc = _ } :: rest5 ->
              let* body, rest6 = parse_term rest5 in
              Ok (Syntax.SLet (loc, x, ty, def, body), rest6)
          | { Token.kind; loc = bad_loc } :: _rest ->
              parse_err bad_loc ("expected 'in', found " ^ Token.describe kind)
          | [] -> eof_err)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected ':=', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected 'NAME : TYPE := TERM in BODY' after 'let', found " ^ Token.describe kind)
  | [] -> eof_err

(** "let* A B x := e in body" / "let*! A B x := e in body" (M3 Stage C,
    C3). FALLBACK SHAPE (see [Syntax.SLetStar]'s doc comment): [A] and
    [B] are the two EXPLICIT type-argument atoms the desugared
    [bindIO]/[bindDiv] application needs, parsed the same way an
    ordinary application argument is (one [parse_atom] each, so a
    compound type needs parens, e.g. "let* (Option String) Verdict x
    := ... in ..."), NOT a bounded hole pass.  M6 Stage C: either atom
    may be the hole [_], filled by [Elab.term_at] from the expected
    type. *)
and parse_let_star (loc : Loc.t) ~(is_div : bool) (ts : Token.t list) :
    (Syntax.t * Token.t list, Serror.t) result =
  let* ty_a, rest = parse_atom ts in
  let* ty_b, rest2 = parse_atom rest in
  match rest2 with
  | { Token.kind = Token.Ident _ | Token.Underscore as k; loc = _ } :: { Token.kind = Token.ColonEq; loc = _ } :: rest3
    ->
      let x = binder_name k in
      let* rhs, rest4 = parse_term rest3 in
      (match rest4 with
      | { Token.kind = Token.KIn; loc = _ } :: rest5 ->
          let* body, rest6 = parse_term rest5 in
          Ok (Syntax.SLetStar (loc, is_div, ty_a, ty_b, x, rhs, body), rest6)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected 'in', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected 'NAME := TERM in BODY' after the let* type arguments, found "
        ^ Token.describe kind)
  | [] -> eof_err

(** "match S [as x return P] with | c xs => B .. end". The scrutinee and
    motive terms stop on their own at 'as'/'with' (neither starts an
    atom); 'end' is required. *)
and parse_match (loc : Loc.t) (ts : Token.t list) :
    (Syntax.t * Token.t list, Serror.t) result =
  let* scrut, rest = parse_term ts in
  match rest with
  | { Token.kind = Token.KWith; loc = _ } :: rest2 ->
      let* branches, rest3 = parse_branches rest2 [] in
      Ok (Syntax.SMatch (loc, scrut, None, branches), rest3)
  (* M4 Stage A: "as x in I y1 .. ym return P". The index clause sits
     INSIDE the motive clause, after "as x", so it cannot collide with a
     "let .. in .." scrutinee (which [parse_term] has already fully
     consumed by the time this arm looks for 'in'). *)
  | { Token.kind = Token.KAs; loc = _ }
    :: { Token.kind = Token.Ident _ | Token.Underscore as k; loc = _ }
    :: { Token.kind = Token.KIn; loc = _ }
    :: { Token.kind = Token.Ident iname; loc = _ }
    :: rest2 ->
      let x = binder_name k in
      let idx_names, rest3 = collect_idents rest2 in
      (match rest3 with
      | { Token.kind = Token.KReturn; loc = _ } :: rest4 ->
          let* motive, rest5 = parse_term rest4 in
          (match rest5 with
          | { Token.kind = Token.KWith; loc = _ } :: rest6 ->
              let* branches, rest7 = parse_branches rest6 [] in
              let sm : Syntax.smotive =
                {
                  Syntax.sm_self = x;
                  sm_ind = Some iname;
                  sm_idx = idx_names;
                  sm_body = motive;
                }
              in
              Ok (Syntax.SMatch (loc, scrut, Some sm, branches), rest7)
          | { Token.kind; loc = bad_loc } :: _rest ->
              parse_err bad_loc ("expected 'with', found " ^ Token.describe kind)
          | [] -> eof_err)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected 'return', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind = Token.KAs; loc = _ }
    :: { Token.kind = Token.Ident _ | Token.Underscore as k; loc = _ }
    :: { Token.kind = Token.KReturn; loc = _ }
    :: rest2 ->
      let x = binder_name k in
      let* motive, rest3 = parse_term rest2 in
      (match rest3 with
      | { Token.kind = Token.KWith; loc = _ } :: rest4 ->
          let* branches, rest5 = parse_branches rest4 [] in
          let sm : Syntax.smotive =
            { Syntax.sm_self = x; sm_ind = None; sm_idx = []; sm_body = motive }
          in
          Ok (Syntax.SMatch (loc, scrut, Some sm, branches), rest5)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected 'with', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind = Token.KAs; loc = bad_loc } :: _rest ->
      parse_err bad_loc "expected 'NAME [in FAMILY IDX..] return TYPE' after 'as'"
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc ("expected 'as' or 'with', found " ^ Token.describe kind)
  | [] -> eof_err

(** Zero or more "| c x y => body" branches, then the required 'end'.
    Branch patterns are flat: a ctor name plus distinct binder names. *)
and parse_branches (ts : Token.t list)
    (acc : (string * string list * Syntax.t) list) :
    ((string * string list * Syntax.t) list * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.KEnd; loc = _ } :: rest -> Ok (List.rev acc, rest)
  | { Token.kind = Token.Pipe; loc = _ }
    :: { Token.kind = Token.Ident c; loc = ploc }
    :: rest -> (
      let binders, rest2 = collect_idents rest in
      let* () =
        find_dup binders
        |> Option.fold
             ~none:(Ok ())
             ~some:(fun x ->
               parse_err ploc (Printf.sprintf "duplicate binder %s in pattern" x))
      in
      match rest2 with
      | { Token.kind = Token.DArrow; loc = _ } :: rest3 ->
          let* body, rest4 = parse_term rest3 in
          parse_branches rest4 ((c, binders, body) :: acc)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected '=>', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind = Token.Pipe; loc = _ } :: { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected a constructor name after '|', found " ^ Token.describe kind)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc ("expected '|' or 'end', found " ^ Token.describe kind)
  | [] -> eof_err

(** Speculative "(q x .. : T)" binder group. Commits only if the token
    after ')' is '->'; the returned rest does NOT consume that arrow. Any
    inner failure (including term-parse errors) yields None. *)
and try_binder_group (ts : Token.t list) :
    (Loc.t * Quantity.t * string list * Syntax.t * Token.t list) option =
  match ts with
  | { Token.kind = Token.LParen; loc } :: rest ->
      let q, rest_q = quantity_prefix rest in
      (match collect_idents rest_q with
      | [], _rest -> None
      | (_x :: _xs as names), rest2 ->
          (match rest2 with
          | { Token.kind = Token.Colon; loc = _ } :: rest3 ->
              parse_term rest3
              |> Result.fold
                   ~ok:(fun (dom, rest4) ->
                     match rest4 with
                     | { Token.kind = Token.RParen; loc = _ }
                       :: ({ Token.kind = Token.Arrow; loc = _ } :: _rest5 as after) ->
                         Some (loc, q, names, dom, after)
                     | ({ Token.kind = _; loc = _ } :: _ | []) -> None)
                   ~error:(fun _e -> None)
          | ({ Token.kind = _; loc = _ } :: _ | []) -> None))
  | ({ Token.kind = _; loc = _ } :: _ | []) -> None

and parse_arrow (ts : Token.t list) : (Syntax.t * Token.t list, Serror.t) result =
  try_binder_group ts
  |> Option.fold
       ~none:parse_arrow_plain
       ~some:(fun (loc, q, names, dom, rest) (_ts : Token.t list) ->
         parse_group_arrow loc q names dom rest)
  |> fun k -> k ts

and parse_group_arrow (loc : Loc.t) (q : Quantity.t) (names : string list)
    (dom : Syntax.t) (ts : Token.t list) : (Syntax.t * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Arrow; loc = _ } :: rest ->
      let* cod, rest2 = parse_term rest in
      Ok (List.fold_right (fun x acc -> Syntax.SPi (loc, q, x, dom, acc)) names cod, rest2)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc ("expected '->', found " ^ Token.describe kind)
  | [] -> eof_err

and parse_arrow_plain (ts : Token.t list) : (Syntax.t * Token.t list, Serror.t) result =
  let* lhs, rest = parse_app ts in
  match rest with
  | { Token.kind = Token.Arrow; loc = _ } :: rest2 ->
      let* rhs, rest3 = parse_term rest2 in
      Ok (Syntax.SPi (Syntax.loc_of lhs, Quantity.Many, "_", lhs, rhs), rest3)
  | ({ Token.kind = _; loc = _ } :: _ | []) -> Ok (lhs, rest)

and parse_app (ts : Token.t list) : (Syntax.t * Token.t list, Serror.t) result =
  let* head, rest = parse_atom ts in
  parse_app_rest head rest

and parse_app_rest (head : Syntax.t) (ts : Token.t list) :
    (Syntax.t * Token.t list, Serror.t) result =
  match () with
  | () when starts_atom ts ->
      let* arg, rest = parse_atom ts in
      parse_app_rest (Syntax.SApp (Syntax.loc_of head, head, arg)) rest
  | () -> Ok (head, ts)

and parse_atom (ts : Token.t list) : (Syntax.t * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Ident x; loc } :: rest -> Ok (Syntax.SVar (loc, x), rest)
  | { Token.kind = Token.KAuto; loc } :: rest -> Ok (Syntax.SAuto loc, rest)
  | { Token.kind = Token.Underscore; loc } :: rest -> Ok (Syntax.SHole loc, rest)
  | { Token.kind = Token.KType; loc } :: { Token.kind = Token.Nat n; loc = _ } :: rest ->
      Ok (Syntax.SType (loc, n), rest)
  | { Token.kind = Token.KType; loc } :: rest -> Ok (Syntax.SType (loc, 0), rest)
  | { Token.kind = Token.Str s; loc } :: rest -> Ok (Syntax.SStr (loc, s), rest)
  | { Token.kind = Token.Nat n; loc } :: rest -> Ok (Syntax.SInt (loc, n), rest)
  | { Token.kind = Token.LParen; loc } :: rest ->
      let* inner, rest2 = parse_term rest in
      (match rest2 with
      | { Token.kind = Token.RParen; loc = _ } :: rest3 -> Ok (inner, rest3)
      | { Token.kind = Token.Colon; loc = _ } :: rest3 ->
          let* ty, rest4 = parse_term rest3 in
          (match rest4 with
          | { Token.kind = Token.RParen; loc = _ } :: rest5 ->
              Ok (Syntax.SAnn (loc, inner, ty), rest5)
          | { Token.kind; loc = bad_loc } :: _rest ->
              parse_err bad_loc ("expected ')', found " ^ Token.describe kind)
          | [] -> eof_err)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected ')' or ':', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc ("expected a term, found " ^ Token.describe kind)
  | [] -> eof_err

let rec parse_items (ts : Token.t list) (acc : Syntax.item list) :
    (Syntax.item list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Eof; loc = _ } :: _rest -> Ok (List.rev acc)
  | { Token.kind = Token.KDef; loc } :: rest ->
      let* item, rest2 = parse_def ~loc ~reducible:false rest in
      parse_items rest2 (item :: acc)
  | { Token.kind = Token.KReducible; loc }
    :: { Token.kind = Token.KDef; loc = _ }
    :: rest ->
      let* item, rest2 = parse_def ~loc ~reducible:true rest in
      parse_items rest2 (item :: acc)
  | { Token.kind = Token.KReducible; loc } :: _rest ->
      parse_err loc "expected 'def' after 'reducible'"
  | { Token.kind = Token.KData; loc } :: rest ->
      let* item, rest2 = parse_data ~loc rest in
      parse_items rest2 (item :: acc)
  | { Token.kind = Token.KEval; loc } :: rest ->
      let* tm, rest2 = parse_term rest in
      parse_items rest2 (Syntax.IEval (loc, tm) :: acc)
  | { Token.kind = Token.KCheck; loc } :: rest ->
      let* tm, rest2 = parse_term rest in
      parse_items rest2 (Syntax.ICheck (loc, tm) :: acc)
  | { Token.kind = Token.KAxiom; loc }
    :: { Token.kind = Token.Ident name; loc = _ }
    :: { Token.kind = Token.Colon; loc = _ }
    :: rest ->
      let* ty, rest2 = parse_term rest in
      parse_items rest2 (Syntax.IAxiom { loc; name; ty } :: acc)
  | { Token.kind = Token.KAxiom; loc = bad_loc } :: _rest ->
      parse_err bad_loc "expected 'NAME : TYPE' after 'axiom'"
  | { Token.kind = Token.KClass; loc } :: rest ->
      let* item, rest2 = parse_class ~loc rest in
      parse_items rest2 (item :: acc)
  | { Token.kind = Token.KInstance; loc } :: rest ->
      let* item, rest2 = parse_instance ~loc rest in
      parse_items rest2 (item :: acc)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected 'def', 'reducible', 'data', 'eval', 'check', 'axiom', 'class', or \
          'instance', found "
        ^ Token.describe kind)
  | [] -> eof_err

(** "[reducible] def [rec [partial]] NAME : TYPE := TERM". [partial] is
    a keyword that only ever follows [rec] (M3 Stage C, C4: "keyword
    form, not a silent downgrade"); [def partial NAME ...] (no [rec])
    falls through to [parse_def_body]'s own "expected NAME" error,
    since the leading [KPartial] token is left unconsumed. *)
and parse_def ~(loc : Loc.t) ~(reducible : bool) (ts : Token.t list) :
    (Syntax.item * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.KRec; loc = _ } :: { Token.kind = Token.KPartial; loc = _ } :: rest ->
      parse_def_body ~loc ~reducible ~kind:Syntax.DRecPartial rest
  | { Token.kind = Token.KRec; loc = _ } :: rest ->
      parse_def_body ~loc ~reducible ~kind:Syntax.DRec rest
  | ({ Token.kind = _; loc = _ } :: _ | []) ->
      parse_def_body ~loc ~reducible ~kind:Syntax.DNonRec ts

and parse_def_body ~(loc : Loc.t) ~(reducible : bool) ~(kind : Syntax.defkind)
    (ts : Token.t list) : (Syntax.item * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Ident name; loc = _ }
    :: { Token.kind = Token.Colon; loc = _ }
    :: rest ->
      let* ty, rest2 = parse_term rest in
      (match rest2 with
      | { Token.kind = Token.ColonEq; loc = _ } :: rest3 ->
          let* def, rest4 = parse_term rest3 in
          Ok (Syntax.IDef { loc; name; reducible; kind; ty; def }, rest4)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected ':=', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected 'NAME : TYPE := TERM' after 'def', found " ^ Token.describe kind)
  | [] -> eof_err

(** "data NAME (0 p : T) .. : IDXTELE Type L := | c : CT ..". Parameters
    are single-binder groups that MUST carry the literal 0 marker; a data
    declaration may have zero constructors. M4 Stage A: the codomain
    (everything between ':' and ':=') is now ONE ordinary term, peeled by
    [peel_data_codomain] into an index telescope plus the level, which is
    what lets "Nat -> Type 0" parse as one Nat-typed index (via the same
    "A -> B" = "(w _ : A) -> B" arrow sugar every other arrow uses) and
    what retires [parse_data_level]. *)
and parse_data ~(loc : Loc.t) (ts : Token.t list) :
    (Syntax.item * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Ident name; loc = _ } :: rest ->
      let* params, rest2 = parse_data_params rest [] in
      (match rest2 with
      | { Token.kind = Token.Colon; loc = _ } :: rest3 ->
          let* codomain, rest4 = parse_term rest3 in
          let* indices, level = peel_data_codomain codomain in
          (match rest4 with
          | { Token.kind = Token.ColonEq; loc = _ } :: rest5 ->
              let* ctors, rest6 = parse_ctors rest5 [] in
              Ok (Syntax.IData { loc; name; params; indices; level; ctors }, rest6)
          | { Token.kind; loc = bad_loc } :: _rest ->
              parse_err bad_loc ("expected ':=', found " ^ Token.describe kind)
          | [] -> eof_err)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected ':', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc ("expected a name after 'data', found " ^ Token.describe kind)
  | [] -> eof_err

(** Peel a data header's codomain: a chain of quantity-0 (or arrow-sugar)
    Pi binders, each one index, ending in [Type L]. Peel rules, applied
    left to right: [SType] ends the peel; [SPi (Zero, x, dom, cod)]
    contributes index [(Zero, x, dom)]; [SPi (Many, "_", dom, cod)] (the
    "A ->" arrow-sugar shape) contributes [(Zero, "_", dom)] too (an
    explicitly written "(w _ : T) ->" index is thus silently forced to
    quantity 0 rather than rejected, a documented SPEC section 6 debt: a
    NAMED [w] binder, below, IS rejected); any other named [Many] Pi is
    "data indices must be marked 0"; anything else is "expected
    'Type'". *)
and peel_data_codomain (t : Syntax.t) :
    ((Quantity.t * string * Syntax.t) list * int, Serror.t) result =
  match t with
  | Syntax.SType (_loc, level) -> Ok ([], level)
  | Syntax.SPi (_loc, Quantity.Zero, x, dom, cod) ->
      let* rest, level = peel_data_codomain cod in
      Ok ((Quantity.Zero, x, dom) :: rest, level)
  | Syntax.SPi (_loc, Quantity.Many, "_", dom, cod) ->
      let* rest, level = peel_data_codomain cod in
      Ok ((Quantity.Zero, "_", dom) :: rest, level)
  | Syntax.SPi (loc, Quantity.Many, _x, _dom, _cod) ->
      parse_err loc "data indices must be marked 0"
  | ( Syntax.SVar (loc, _) | Syntax.SLam (loc, _, _) | Syntax.SApp (loc, _, _)
    | Syntax.SLet (loc, _, _, _, _) | Syntax.SAnn (loc, _, _) | Syntax.SMatch (loc, _, _, _)
    | Syntax.SStr (loc, _) | Syntax.SInt (loc, _) | Syntax.SLetStar (loc, _, _, _, _, _, _)
    | Syntax.SAuto loc | Syntax.SInst (loc, _, _) | Syntax.SHole loc ) as
    s ->
      parse_err loc ("expected 'Type', found " ^ describe_syntax s)

(** Zero or more "(0 x : T)" parameter groups. After "data NAME" a '('
    can only open a parameter, so no backtracking is needed. *)
and parse_data_params (ts : Token.t list) (acc : (string * Syntax.t) list) :
    ((string * Syntax.t) list * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.LParen; loc = _ }
    :: { Token.kind = Token.Nat 0; loc = _ }
    :: rest -> (
      match rest with
      | { Token.kind = Token.Ident x; loc = _ }
        :: { Token.kind = Token.Colon; loc = _ }
        :: rest2 ->
          let* ty, rest3 = parse_term rest2 in
          (match rest3 with
          | { Token.kind = Token.RParen; loc = _ } :: rest4 ->
              parse_data_params rest4 ((x, ty) :: acc)
          | { Token.kind; loc = bad_loc } :: _rest ->
              parse_err bad_loc ("expected ')', found " ^ Token.describe kind)
          | [] -> eof_err)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc
            ("expected 'NAME : TYPE' in a data parameter, found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind = Token.LParen; loc = _ } :: { Token.kind = _; loc = bad_loc } :: _rest
    ->
      parse_err bad_loc "data parameters must be marked 0"
  | ({ Token.kind = _; loc = _ } :: _ | []) -> Ok (List.rev acc, ts)

(** Zero or more "| c : CT" constructor declarations. The list ends at
    the next item keyword or end of input. *)
and parse_ctors (ts : Token.t list) (acc : (string * Syntax.t) list) :
    ((string * Syntax.t) list * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Pipe; loc = _ }
    :: { Token.kind = Token.Ident c; loc = _ }
    :: { Token.kind = Token.Colon; loc = _ }
    :: rest ->
      let* cty, rest2 = parse_term rest in
      parse_ctors rest2 ((c, cty) :: acc)
  | { Token.kind = Token.Pipe; loc = _ } :: { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected 'NAME : TYPE' after '|', found " ^ Token.describe kind)
  | { Token.kind = Token.KDef; loc = _ } :: _rest
  | { Token.kind = Token.KReducible; loc = _ } :: _rest
  | { Token.kind = Token.KData; loc = _ } :: _rest
  | { Token.kind = Token.KEval; loc = _ } :: _rest
  | { Token.kind = Token.KCheck; loc = _ } :: _rest
  | { Token.kind = Token.KAxiom; loc = _ } :: _rest
  | { Token.kind = Token.KClass; loc = _ } :: _rest
  | { Token.kind = Token.KInstance; loc = _ } :: _rest
  | { Token.kind = Token.Eof; loc = _ } :: _rest ->
      Ok (List.rev acc, ts)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected '|' or the next item, found " ^ Token.describe kind)
  | [] -> eof_err

(** "class NAME (0 A : Type L) := { m1 : T1 ; .. ; mn : Tn }" (D3): one
    parameter binder, forced quantity 0 exactly like a [data] parameter,
    then at least one "NAME : TYPE" method separated by ';', closed by
    '}'.  [Run.item] does the whole expansion into an [IData] plus one
    projection [IDef] per method;  the parser only builds [Syntax.IClass]. *)
and parse_class ~(loc : Loc.t) (ts : Token.t list) : (Syntax.item * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Ident name; loc = _ }
    :: { Token.kind = Token.LParen; loc = _ }
    :: { Token.kind = Token.Nat 0; loc = _ }
    :: { Token.kind = Token.Ident a; loc = _ }
    :: { Token.kind = Token.Colon; loc = _ }
    :: rest -> (
      let* ty, rest2 = parse_term rest in
      match rest2 with
      | { Token.kind = Token.RParen; loc = _ } :: { Token.kind = Token.ColonEq; loc = _ }
        :: { Token.kind = Token.LBrace; loc = _ } :: rest3 ->
          let* methods, rest4 = parse_class_methods rest3 [] in
          Ok (Syntax.IClass { loc; name; param = (a, ty); methods }, rest4)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected ') := {', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected 'NAME (0 A : TYPE)' after 'class', found " ^ Token.describe kind)
  | [] -> eof_err

(** At least one "NAME : TYPE" method, ';'-separated, closed by '}'. *)
and parse_class_methods (ts : Token.t list) (acc : (string * Syntax.t) list) :
    ((string * Syntax.t) list * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Ident m; loc = _ } :: { Token.kind = Token.Colon; loc = _ } :: rest ->
      let* ty, rest2 = parse_term rest in
      (match rest2 with
      | { Token.kind = Token.Semi; loc = _ } :: rest3 -> parse_class_methods rest3 ((m, ty) :: acc)
      | { Token.kind = Token.RBrace; loc = _ } :: rest3 -> Ok (List.rev ((m, ty) :: acc), rest3)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected ';' or '}', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc ("expected 'NAME : TYPE' in a class method, found " ^ Token.describe kind)
  | [] -> eof_err

(** "instance : TY := TERM" (D3). [Run.item] walks [ty]'s own parsed
    codomain spine to name the mangled registration target;  the parser
    only builds [Syntax.IInstance]. *)
and parse_instance ~(loc : Loc.t) (ts : Token.t list) :
    (Syntax.item * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Colon; loc = _ } :: rest -> (
      let* ty, rest2 = parse_term rest in
      match rest2 with
      | { Token.kind = Token.ColonEq; loc = _ } :: rest3 ->
          let* def, rest4 = parse_term rest3 in
          Ok (Syntax.IInstance { loc; ty; def }, rest4)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected ':=', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected ': TYPE := TERM' after 'instance', found " ^ Token.describe kind)
  | [] -> eof_err

let parse (ts : Token.t list) : (Syntax.item list, Serror.t) result = parse_items ts []

(** Parse exactly one term and require [Eof] (M3 Stage A). Used by
    [surface/bootstrap.ml] to elaborate a prim's type from source text
    instead of hand-building [Pi] telescopes in OCaml. *)
let term_only (ts : Token.t list) : (Syntax.t, Serror.t) result =
  let* tm, rest = parse_term ts in
  match rest with
  | { Token.kind = Token.Eof; loc = _ } :: _rest -> Ok tm
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc ("expected end of input, found " ^ Token.describe kind)
  | [] -> eof_err
