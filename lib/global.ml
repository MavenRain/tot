(** Global environment. [add] is kernel-internal: the only sound way to
    extend the environment is [Check.define], which typechecks first. *)

module StringMap = Map.Make (String)

type entry = {
  ty : Term.t;  (** closed *)
  def : Term.t;  (** closed *)
  reducible : bool;
      (** opaque by default: evaluation unfolds only when this is set,
          and conversion never unfolds on its own *)
}

type t = entry StringMap.t

let empty : t = StringMap.empty
let find (name : string) (globals : t) : entry option = StringMap.find_opt name globals
let add (name : string) (entry : entry) (globals : t) : t = StringMap.add name entry globals
