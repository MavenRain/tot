(** Script state, installation policy, and execution entry points. *)

type state = {
  globals : Tot_kernel.Global.t;
  eglobals : Tot_kernel.Interp.globals;
  lines : string list;  (** newest first *)
}

val initial : state

type policy = {
  no_axioms : bool;
  require_main : bool;
  strict_json : bool;
}

val default_policy : policy

val kernel : Loc.t -> ('a, Tot_kernel.Error.t) result -> ('a, Serror.t) result

val compute_guard :
  name:string ->
  Tot_kernel.Term.t ->
  int option ->
  Tot_kernel.Eterm.t ->
  Tot_kernel.Interp.guard

val instance_key : Syntax.t -> (string * string) option

val item :
  ?budget:Tot_kernel.Budget.t ->
  exec:bool ->
  policy:policy ->
  state ->
  Syntax.item ->
  (state, Serror.t) result

val hole_tail : holes:Loc.t list -> Serror.t -> string option

val script_tailed :
  ?st:state ->
  ?policy:policy ->
  ?budget:Tot_kernel.Budget.t ->
  exec:bool ->
  string ->
  (string list * int option, Serror.t * string option) result

val script :
  ?st:state ->
  ?policy:policy ->
  ?budget:Tot_kernel.Budget.t ->
  exec:bool ->
  string ->
  (string list * int option, Serror.t) result
