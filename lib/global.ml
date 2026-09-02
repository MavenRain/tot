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

(** M4 Stage A: an inductive's constructor list, three-state.
    [Provisional] is the window between [declare_ind] and [define_ind]
    (M2's [ctor_names = None]). [Builtin] is a type former that will
    NEVER be defined (String, Int, Div, IO), which needs its own
    elimination message. [Complete] is M2's [Some names]. *)
type ctor_status =
  | Provisional
  | Builtin
  | Complete of string list

(** An inductive type constructor. *)
type ind_entry = {
  ind_ty : Term.t;  (** closed: params -> indices -> Type level *)
  params : telescope;
  indices : telescope;
      (** M4 Stage A: scoped under [params]; every binder [Quantity.Zero] *)
  level : Level.t;
  ctors : ctor_status;  (** RENAMED from [ctor_names], three-state *)
}

(** A data constructor of one inductive. *)
type ctor_entry = {
  ctor_ty : Term.t;  (** closed: 0-params -> args -> I params indices *)
  ind : string;
  args : telescope;  (** scoped under params + earlier args *)
  res_idx : Term.t list;
      (** M4 Stage A: the constructor's result index expressions, scoped
          under params ++ args; [] for an M2/M3 data declaration *)
  full_arity : int;
      (** M4 Stage A: [n_params + List.length args]. Retires
          [Eval.is_canonical]'s second [find_ind] lookup on the guarded-
          unfolding hot path. *)
  self_rec : bool;
      (** M4 Stage A: some argument type mentions the owning inductive.
          Consulted by [Check]'s subsingleton criterion and by nothing
          else. *)
}

(** A native primitive operation (M3 Stage A). No [def] field and no
    [reducible] field: this is exactly what makes conversion unable to
    ever step into it (decision 1/2 of the M3 design verdict). *)
type prim_entry = {
  prim_ty : Term.t;  (** closed *)
  prim : Prim.t;  (** which native operation *)
}

(** M4 Stage B: a postulated statement. An [Axiom] is a [Prim] without a
    native operation: no [def], no [reducible], so conversion can never
    step into it, by the same argument SPEC section 3 makes for prims.
    [Check] additionally refuses it at quantity mode w, so an axiom can
    never reach erased output and [tot run] never meets one. *)
type axiom_entry = { ax_ty : Term.t }  (** closed *)

(** Marshal-format checklist (M3 Stage D): [surface/cache.ml] marshals a
    whole [Global.t] (this type, keyed by name), so any change to
    [entry] or to any entry-payload record above it bumps
    [Cache.format_version]. *)
type entry =
  | Def of def_entry
  | Ind of ind_entry
  | Ctor of ctor_entry
  | Prim of prim_entry
  | Axiom of axiom_entry  (** M4 Stage B *)

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
  | Axiom a -> a.ax_ty

(** Payload views; Option-returning so callers stay total. *)
let def_of (e : entry) : def_entry option =
  match e with
  | Def d -> Some d
  | Ind _ | Ctor _ | Prim _ | Axiom _ -> None

let ind_of (e : entry) : ind_entry option =
  match e with
  | Ind i -> Some i
  | Def _ | Ctor _ | Prim _ | Axiom _ -> None

let ctor_of (e : entry) : ctor_entry option =
  match e with
  | Ctor c -> Some c
  | Def _ | Ind _ | Prim _ | Axiom _ -> None

let prim_of (e : entry) : prim_entry option =
  match e with
  | Prim p -> Some p
  | Def _ | Ind _ | Ctor _ | Axiom _ -> None

(** M4 Stage B: view onto the [Axiom] payload, beside the other four. *)
let axiom_of (e : entry) : axiom_entry option =
  match e with
  | Axiom a -> Some a
  | Def _ | Ind _ | Ctor _ | Prim _ -> None

let find_def (name : string) (globals : t) : def_entry option =
  Option.bind (find name globals) def_of

let find_ind (name : string) (globals : t) : ind_entry option =
  Option.bind (find name globals) ind_of

let find_ctor (name : string) (globals : t) : ctor_entry option =
  Option.bind (find name globals) ctor_of

let find_prim (name : string) (globals : t) : prim_entry option =
  Option.bind (find name globals) prim_of

let find_axiom (name : string) (globals : t) : axiom_entry option =
  Option.bind (find name globals) axiom_of

(** M4 Stage A: [(n_params, n_indices)] for a declared inductive; retires
    two separate [List.length] calls at every caller that needs both. *)
let find_ind_arity (name : string) (globals : t) : (int * int) option =
  find_ind name globals
  |> Option.map (fun (ind : ind_entry) -> (List.length ind.params, List.length ind.indices))
