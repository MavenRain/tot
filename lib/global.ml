(** Global environment. [add] is kernel-internal: the only sound ways to
    extend the environment are [Check.define], [Check.declare_ind] and
    [Check.define_ind], which typecheck first. The namespace is flat: an
    inductive's name and its constructor names live in the same map. *)

module StringMap = Map.Make (String)

(** Binder telescope, outermost first; each type is scoped under the
    binders before it. *)
type telescope = (Quantity.t * string * Term.t) list

(** An ordinary (possibly recursive) definition. *)
type def_entry = {
  ty : Term.t;  (** closed *)
  def : Term.t;  (** closed *)
  reducible : bool;
      (** opaque by default: evaluation unfolds only when this is set,
          and conversion never unfolds on its own *)
  rec_arg : int option;
      (** [Some k]: a rec def; evaluation unfolds it only when argument
          [k] is a canonical constructor value (guarded unfolding) *)
}

(** An inductive type constructor. *)
type ind_entry = {
  ind_ty : Term.t;  (** closed: params -> Type level *)
  params : telescope;
  level : Level.t;
  ctor_names : string list;  (** declaration order *)
}

(** A data constructor of one inductive. *)
type ctor_entry = {
  ctor_ty : Term.t;  (** closed: 0-params -> args -> I params *)
  ind : string;
  args : telescope;  (** scoped under params + earlier args *)
}

type entry =
  | Def of def_entry
  | Ind of ind_entry
  | Ctor of ctor_entry

type t = entry StringMap.t

let empty : t = StringMap.empty
let find (name : string) (globals : t) : entry option = StringMap.find_opt name globals
let add (name : string) (entry : entry) (globals : t) : t = StringMap.add name entry globals

(** The closed type every entry kind stores. *)
let entry_ty (e : entry) : Term.t =
  match e with
  | Def d -> d.ty
  | Ind i -> i.ind_ty
  | Ctor c -> c.ctor_ty

(** Payload views; Option-returning so callers stay total. *)
let def_of (e : entry) : def_entry option =
  match e with
  | Def d -> Some d
  | Ind _ | Ctor _ -> None

let ind_of (e : entry) : ind_entry option =
  match e with
  | Ind i -> Some i
  | Def _ | Ctor _ -> None

let ctor_of (e : entry) : ctor_entry option =
  match e with
  | Ctor c -> Some c
  | Def _ | Ind _ -> None

let find_def (name : string) (globals : t) : def_entry option =
  Option.bind (find name globals) def_of

let find_ind (name : string) (globals : t) : ind_entry option =
  Option.bind (find name globals) ind_of

let find_ctor (name : string) (globals : t) : ctor_entry option =
  Option.bind (find name globals) ctor_of
