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
  | Syntax.IDef { loc; name; reducible; rec_; ty; def } ->
      let* ty_t = Elab.term st.globals [] ty in
      (* a rec body mentions its own name: elaborate it against a
         provisional self-entry (the kernel re-adds its own opaque one
         inside [Check.define], which also rejects duplicates against
         the ORIGINAL globals) *)
      let elab_globals =
        if rec_ then
          Global.add name
            (Global.Def
               {
                 Global.ty = ty_t;
                 def = Term.Global name;
                 reducible = false;
                 rec_arg = None;
               })
            st.globals
        else st.globals
      in
      let* def_t = Elab.term elab_globals [] def in
      let* globals =
        kernel loc (Check.define ~rec_ st.globals ~name ~reducible ~ty:ty_t ~def:def_t)
      in
      (* fetch the entry back: its def carries the checker's quantity
         stamps, which structural erasure relies on *)
      let* dentry =
        kernel loc
          (Global.find_def name globals
          |> Option.to_result ~none:(Error.Unbound_global name))
      in
      let* def_e = kernel loc (Erase.closed dentry.Global.def) in
      let* eglobals = kernel loc (Interp.define st.eglobals ~name def_e) in
      let line = Printf.sprintf "def %s : %s" name (Pp.term [] ty_t) in
      Ok { globals; eglobals; lines = line :: st.lines }
  | Syntax.IData { loc; name; params; level; ctors } ->
      (* params telescope, left to right: each type is elaborated in the
         scope of the names before it; the parser forced quantity 0 *)
      let* pscope, rev_params =
        List.fold_left
          (fun acc (x, ty) ->
            let* scope, rev_tele = acc in
            let* ty_t = Elab.term st.globals scope ty in
            Ok (x :: scope, (Quantity.Zero, x, ty_t) :: rev_tele))
          (Ok ([], []))
          params
      in
      let* level_l =
        Level.of_int level |> Option.to_result ~none:(Serror.Bad_level { loc; level })
      in
      (* declare first so the ctor types can mention the inductive *)
      let* provisional =
        kernel loc
          (Check.declare_ind st.globals ~name ~params:(List.rev rev_params)
             ~level:level_l)
      in
      let* rev_ctors =
        List.fold_left
          (fun acc (cname, cty) ->
            let* rev = acc in
            let* cty_t = Elab.term provisional pscope cty in
            Ok ((cname, cty_t) :: rev))
          (Ok []) ctors
      in
      let* globals =
        kernel loc (Check.define_ind provisional ~name ~ctors:(List.rev rev_ctors))
      in
      (* runtime seeds: the type constructor is inert, data constructors
         accumulate their kept arguments *)
      let eglobals =
        List.fold_left
          (fun eg (cname, _cty) -> Interp.add_ctor eg ~name:cname)
          (Interp.add_erased st.eglobals ~name)
          ctors
      in
      (* print the CLOSED kernel types fetched back from the new entries *)
      let* ind =
        kernel loc
          (Global.find_ind name globals
          |> Option.to_result ~none:(Error.Unbound_global name))
      in
      let data_line = Printf.sprintf "data %s : %s" name (Pp.term [] ind.Global.ind_ty) in
      let* rev_ctor_lines =
        List.fold_left
          (fun acc (cname, _cty) ->
            let* rev = acc in
            let* centry =
              kernel loc
                (Global.find_ctor cname globals
                |> Option.to_result ~none:(Error.Unbound_global cname))
            in
            Ok
              (Printf.sprintf "ctor %s : %s" cname (Pp.term [] centry.Global.ctor_ty)
              :: rev))
          (Ok []) ctors
      in
      Ok { globals; eglobals; lines = rev_ctor_lines @ data_line :: st.lines }
  | Syntax.ICheck (loc, s) ->
      let* tm = Elab.term st.globals [] s in
      let* tm', ty_v =
        kernel loc (Check.infer st.globals Check.empty_ctx Quantity.Zero tm)
      in
      let line =
        Printf.sprintf "%s : %s" (Pp.term [] tm') (Check.pp_value st.globals 0 ty_v)
      in
      Ok { st with lines = line :: st.lines }
  | Syntax.IEval (loc, s) ->
      let* tm = Elab.term st.globals [] s in
      let* tm', ty_v =
        kernel loc (Check.infer st.globals Check.empty_ctx Quantity.Many tm)
      in
      let* e = kernel loc (Erase.closed tm') in
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
