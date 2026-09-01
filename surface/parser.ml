(** Recursive-descent parser over the token list. Backtracking is free on
    immutable lists: [try_binder_group] speculatively parses "(q x .. : T)"
    and commits only when ") ->" follows; any inner failure falls back to
    the application/arrow-sugar path. Error arms bind named token/list
    variables and report via [Token.describe]. *)

open Tot_kernel

let ( let* ) = Result.bind

let parse_err (loc : Loc.t) (msg : string) : ('a, Serror.t) result =
  Error (Serror.Parse { loc; msg })

let eof_err : ('a, Serror.t) result =
  (* unreachable: the lexer always materializes an Eof token *)
  parse_err Loc.start "unexpected end of input"

let kind_starts_atom (k : Token.kind) : bool =
  match k with
  | Token.Ident _ | Token.KType | Token.LParen -> true
  | Token.RParen | Token.Colon | Token.ColonEq | Token.Arrow | Token.DArrow
  | Token.KFun | Token.KLet | Token.KIn | Token.KDef | Token.KReducible | Token.KEval
  | Token.KCheck | Token.KData | Token.KMatch | Token.KWith | Token.KAs | Token.KReturn
  | Token.KRec | Token.KEnd | Token.Pipe | Token.Nat _ | Token.Eof ->
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
  | ({ Token.kind = _; loc = _ } :: _ | []) as same -> ([], same)

(** First name that occurs twice in the list, if any. Total. *)
let rec find_dup (xs : string list) : string option =
  match xs with
  | [] -> None
  | x :: rest ->
      if List.exists (String.equal x) rest then Some x else find_dup rest

(** The optional quantity marker at the head of a binder group. "0" means
    Zero. "w" is a Many marker ONLY when another identifier follows it;
    otherwise "w" is the binder's own name and the default (Many)
    applies. *)
let quantity_prefix (ts : Token.t list) : Quantity.t * Token.t list =
  match ts with
  | { Token.kind = Token.Nat 0; loc = _ } :: rest -> (Quantity.Zero, rest)
  | { Token.kind = Token.Ident "w"; loc = _ }
    :: ({ Token.kind = Token.Ident _; loc = _ } :: _rest2 as rest) ->
      (Quantity.Many, rest)
  | ({ Token.kind = _; loc = _ } :: _ | []) as same -> (Quantity.Many, same)

let rec parse_term (ts : Token.t list) : (Syntax.t * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.KFun; loc } :: rest -> parse_fun loc rest
  | { Token.kind = Token.KLet; loc } :: rest -> parse_let loc rest
  | { Token.kind = Token.KMatch; loc } :: rest -> parse_match loc rest
  | ({ Token.kind = _; loc = _ } :: _ | []) -> parse_arrow ts

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
  | { Token.kind = Token.Ident x; loc = _ }
    :: { Token.kind = Token.Colon; loc = _ }
    :: rest ->
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
  | { Token.kind = Token.KAs; loc = _ }
    :: { Token.kind = Token.Ident x; loc = _ }
    :: { Token.kind = Token.KReturn; loc = _ }
    :: rest2 ->
      let* motive, rest3 = parse_term rest2 in
      (match rest3 with
      | { Token.kind = Token.KWith; loc = _ } :: rest4 ->
          let* branches, rest5 = parse_branches rest4 [] in
          Ok (Syntax.SMatch (loc, scrut, Some (x, motive), branches), rest5)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected 'with', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind = Token.KAs; loc = bad_loc } :: _rest ->
      parse_err bad_loc "expected 'NAME return TYPE' after 'as'"
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
  | { Token.kind = Token.KType; loc } :: { Token.kind = Token.Nat n; loc = _ } :: rest ->
      Ok (Syntax.SType (loc, n), rest)
  | { Token.kind = Token.KType; loc } :: rest -> Ok (Syntax.SType (loc, 0), rest)
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
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected 'def', 'reducible', 'data', 'eval', or 'check', found "
        ^ Token.describe kind)
  | [] -> eof_err

(** "[reducible] def [rec] NAME : TYPE := TERM". *)
and parse_def ~(loc : Loc.t) ~(reducible : bool) (ts : Token.t list) :
    (Syntax.item * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.KRec; loc = _ } :: rest ->
      parse_def_body ~loc ~reducible ~rec_:true rest
  | ({ Token.kind = _; loc = _ } :: _ | []) ->
      parse_def_body ~loc ~reducible ~rec_:false ts

and parse_def_body ~(loc : Loc.t) ~(reducible : bool) ~(rec_ : bool)
    (ts : Token.t list) : (Syntax.item * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Ident name; loc = _ }
    :: { Token.kind = Token.Colon; loc = _ }
    :: rest ->
      let* ty, rest2 = parse_term rest in
      (match rest2 with
      | { Token.kind = Token.ColonEq; loc = _ } :: rest3 ->
          let* def, rest4 = parse_term rest3 in
          Ok (Syntax.IDef { loc; name; reducible; rec_; ty; def }, rest4)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected ':=', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected 'NAME : TYPE := TERM' after 'def', found " ^ Token.describe kind)
  | [] -> eof_err

(** "data NAME (0 p : T) .. : Type L := | c : CT ..". Parameters are
    single-binder groups that MUST carry the literal 0 marker; the level
    defaults to 0; a data declaration may have zero constructors. *)
and parse_data ~(loc : Loc.t) (ts : Token.t list) :
    (Syntax.item * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.Ident name; loc = _ } :: rest ->
      let* params, rest2 = parse_data_params rest [] in
      (match rest2 with
      | { Token.kind = Token.Colon; loc = _ } :: rest3 ->
          let* level, rest4 = parse_data_level rest3 in
          (match rest4 with
          | { Token.kind = Token.ColonEq; loc = _ } :: rest5 ->
              let* ctors, rest6 = parse_ctors rest5 [] in
              Ok (Syntax.IData { loc; name; params; level; ctors }, rest6)
          | { Token.kind; loc = bad_loc } :: _rest ->
              parse_err bad_loc ("expected ':=', found " ^ Token.describe kind)
          | [] -> eof_err)
      | { Token.kind; loc = bad_loc } :: _rest ->
          parse_err bad_loc ("expected ':', found " ^ Token.describe kind)
      | [] -> eof_err)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc ("expected a name after 'data', found " ^ Token.describe kind)
  | [] -> eof_err

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

(** "Type [L]" in a data header; the level defaults to 0. *)
and parse_data_level (ts : Token.t list) : (int * Token.t list, Serror.t) result =
  match ts with
  | { Token.kind = Token.KType; loc = _ } :: { Token.kind = Token.Nat n; loc = _ } :: rest
    ->
      Ok (n, rest)
  | { Token.kind = Token.KType; loc = _ } :: rest -> Ok (0, rest)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc ("expected 'Type', found " ^ Token.describe kind)
  | [] -> eof_err

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
  | { Token.kind = Token.Eof; loc = _ } :: _rest ->
      Ok (List.rev acc, ts)
  | { Token.kind; loc = bad_loc } :: _rest ->
      parse_err bad_loc
        ("expected '|' or the next item, found " ^ Token.describe kind)
  | [] -> eof_err

let parse (ts : Token.t list) : (Syntax.item list, Serror.t) result = parse_items ts []
