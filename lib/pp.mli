(** Display-only printer. Free variables print as [#n]. *)

(** Render a string literal's SOURCE form: double-quoted, with
    backslash, double-quote, newline and tab escaped (M3 Stage A).
    This is the SOURCE escaper only.  JSON output (the serializer and
    the verdict envelope) uses [Json_escape.string] instead; see M5
    Stage A, pin 13, which split the two escape sets after M4's
    subset claim was measured false. *)
val escape_string : string -> string

(** [term names tm] renders [tm], resolving de Bruijn indices against
    [names] (newest binder first).  An index with no name prints as
    [#n]. *)
val term : string list -> Term.t -> string

(** [eterm names e] renders an erased term, with the same free-variable
    convention as [term]. *)
val eterm : string list -> Eterm.t -> string
