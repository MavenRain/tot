(** Script driver: lex, parse, elaborate, kernel-check, erase, and (in
    run mode) execute, threading both global environments through the
    items. Output lines accumulate newest-first and are reversed at the
    end. *)

open Tot_kernel

let ( let* ) = Result.bind

type state = {
  globals : Global.t;
  eglobals : Interp.globals;
  lines : string list;  (** newest first *)
}

let initial : state = { globals = Global.empty; eglobals = Interp.empty_globals; lines = [] }

let kernel (loc : Loc.t) (r : ('a, Error.t) result) : ('a, Serror.t) result =
  Result.map_error (fun err -> Serror.Kernel { loc; err }) r

let item ~(exec : bool) (st : state) (it : Syntax.item) : (state, Serror.t) result =
  match it with
  | Syntax.IDef { loc; name; reducible; ty; def } ->
      let* ty_t = Elab.term st.globals [] ty in
      let* def_t = Elab.term st.globals [] def in
      let* globals =
        kernel loc (Check.define st.globals ~name ~reducible ~ty:ty_t ~def:def_t)
      in
      let* ty_v = kernel loc (Eval.eval globals [] ty_t) in
      let* def_e = kernel loc (Erase.closed globals ~ty:ty_v ~def:def_t) in
      let* eglobals = kernel loc (Interp.define st.eglobals ~name def_e) in
      let line = Printf.sprintf "def %s : %s" name (Pp.term [] ty_t) in
      Ok { globals; eglobals; lines = line :: st.lines }
  | Syntax.ICheck (loc, s) ->
      let* tm = Elab.term st.globals [] s in
      let* ty_v = kernel loc (Check.infer st.globals Check.empty_ctx Quantity.Zero tm) in
      let line =
        Printf.sprintf "%s : %s" (Pp.term [] tm) (Check.pp_value st.globals 0 ty_v)
      in
      Ok { st with lines = line :: st.lines }
  | Syntax.IEval (loc, s) ->
      let* tm = Elab.term st.globals [] s in
      let* ty_v = kernel loc (Check.infer st.globals Check.empty_ctx Quantity.Many tm) in
      let* e, _e_ty = kernel loc (Erase.infer st.globals Erase.empty_ctx tm) in
      if exec then
        let* v = kernel loc (Interp.exec st.eglobals [] e) in
        let* e' = kernel loc (Interp.quote st.eglobals 0 v) in
        Ok { st with lines = Pp.eterm [] e' :: st.lines }
      else
        Ok { st with lines = ("eval : " ^ Check.pp_value st.globals 0 ty_v) :: st.lines }

let script ~(exec : bool) (src : string) : (string list, Serror.t) result =
  let* tokens = Lexer.lex src in
  let* items = Parser.parse tokens in
  let* final =
    List.fold_left
      (fun acc it ->
        let* st = acc in
        item ~exec st it)
      (Ok initial) items
  in
  Ok (List.rev final.lines)
