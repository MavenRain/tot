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
  partial : bool;
      (** M3 Stage C: [true] for a [def rec partial] that skipped
          [Totality.guard] (decision 10 of the M3 design verdict): its
          codomain is Div-headed and it is forced [reducible = false],
          [rec_arg = None] (never a Check.define-internal error to see
          [partial = true] with a non-None [rec_arg]; [Check.define]
          never builds one). Consulted only for record-keeping /
          tooling; runtime and conversion behavior are fully
          determined by [reducible] and [rec_arg] alone, exactly as
          for any other opaque non-rec-guarded def. *)
}

(** An inductive type constructor. *)
type ind_entry = {
  ind_ty : Term.t;  (** closed: params -> Type level *)
  params : telescope;
  level : Level.t;
  ctor_names : string list option;
      (** [None]: declared but not yet defined (the provisional window
          between [declare_ind] and [define_ind]); nothing may eliminate
          it yet. [Some names]: complete, in declaration order. *)
}

(** A data constructor of one inductive. *)
type ctor_entry = {
  ctor_ty : Term.t;  (** closed: 0-params -> args -> I params *)
  ind : string;
  args : telescope;  (** scoped under params + earlier args *)
}

(** A native primitive operation (M3 Stage A). No [def] field and no
    [reducible] field: this is exactly what makes conversion unable to
    ever step into it (decision 1/2 of the M3 design verdict). *)
type prim_entry = {
  prim_ty : Term.t;  (** closed *)
  prim : Prim.t;  (** which native operation *)
}

(** Marshal-format checklist (M3 Stage D): [surface/cache.ml] marshals a
    whole [Global.t] (this type, keyed by name), so any change to
    [entry] or to any entry-payload record above it bumps
    [Cache.format_version]. *)
type entry =
  | Def of def_entry
  | Ind of ind_entry
  | Ctor of ctor_entry
  | Prim of prim_entry

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
  | Prim p -> p.prim_ty

(** Payload views; Option-returning so callers stay total. *)
let def_of (e : entry) : def_entry option =
  match e with
  | Def d -> Some d
  | Ind _ | Ctor _ | Prim _ -> None

let ind_of (e : entry) : ind_entry option =
  match e with
  | Ind i -> Some i
  | Def _ | Ctor _ | Prim _ -> None

let ctor_of (e : entry) : ctor_entry option =
  match e with
  | Ctor c -> Some c
  | Def _ | Ind _ | Prim _ -> None

let prim_of (e : entry) : prim_entry option =
  match e with
  | Prim p -> Some p
  | Def _ | Ind _ | Ctor _ -> None

let find_def (name : string) (globals : t) : def_entry option =
  Option.bind (find name globals) def_of

let find_ind (name : string) (globals : t) : ind_entry option =
  Option.bind (find name globals) ind_of

let find_ctor (name : string) (globals : t) : ctor_entry option =
  Option.bind (find name globals) ctor_of

let find_prim (name : string) (globals : t) : prim_entry option =
  Option.bind (find name globals) prim_of
