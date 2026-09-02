(** Surface-pipeline errors: lexing, parsing, scope resolution, and
    kernel errors wrapped with the location of the item that caused
    them. *)

type t =
  | Lex of {
      loc : Loc.t;
      msg : string;
    }
  | Parse of {
      loc : Loc.t;
      msg : string;
    }
  | Unknown_name of {
      loc : Loc.t;
      name : string;
    }
  | Bad_level of {
      loc : Loc.t;
      level : int;
    }
  | Kernel of {
      loc : Loc.t;
      err : Tot_kernel.Error.t;
    }
  | Main_bad_type of { ty : string }
      (** M3 fixes, C1' (O4, 2026-09-01): [main] is a RESERVED driver
          name.  A user-file def literally named "main" whose type
          converts to neither [IO Verdict] nor [IO Unit] is this error,
          in BOTH check and run modes, carrying the printed type.  A
          MISSPELLED main stays silent (documented SPEC section 6
          residual; a strict driver flag is M4 work). *)

let to_string (e : t) : string =
  match e with
  | Lex { loc; msg } -> Printf.sprintf "%s: lex error: %s" (Loc.to_string loc) msg
  | Parse { loc; msg } -> Printf.sprintf "%s: parse error: %s" (Loc.to_string loc) msg
  | Unknown_name { loc; name } ->
      Printf.sprintf "%s: unknown name %s" (Loc.to_string loc) name
  | Bad_level { loc; level } ->
      Printf.sprintf "%s: bad universe level %d" (Loc.to_string loc) level
  | Kernel { loc; err } ->
      Printf.sprintf "%s: %s" (Loc.to_string loc) (Tot_kernel.Error.to_string err)
  | Main_bad_type { ty } ->
      Printf.sprintf
        "main is a reserved driver name: its type must convert to IO Verdict or IO Unit, \
         got %s"
        ty

let tag (e : t) : string =
  match e with
  | Lex _ -> "Lex"
  | Parse _ -> "Parse"
  | Unknown_name _ -> "Unknown_name"
  | Bad_level _ -> "Bad_level"
  | Kernel { loc = _loc; err } -> "Kernel." ^ Tot_kernel.Error.tag err
  | Main_bad_type _ -> "Main_bad_type"
