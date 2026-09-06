(** Global environment.  M8 Stage D: the environment's storage is
    [Global_store], which lib/dune keeps private to tot_kernel, so this
    interface exports no general insertion and a client outside the
    kernel cannot extend the environment by hand.  The only sound ways
    to extend it are [Check.define], [Check.declare_ind] and
    [Check.define_ind], which typecheck first.  The namespace is flat: an
    inductive's name and its constructor names live in the same map. *)

(** The runtime-globals map, and [Check]'s separate class-name set, use
    this module directly;  it is neither hidden nor renamed. *)
module StringMap : Map.S with type key = string

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

(** M8 Stage D: the manifest alias onto the private storage.  It is
    manifest on purpose: [Global_store.t] is abstract, and the identity
    is what lets the kernel's own modules use the private storage API
    without this interface exposing the map representation or a general
    insertion function. *)
type t = entry Global_store.t

(** The empty environment. *)
val empty : t

(** [find name globals] is the entry bound to [name], or [None]. *)
val find : string -> t -> entry option

(** M8 Stage D: [add_rec_self name ty globals] adds the provisional,
    opaque, unchecked self-entry a rec body is elaborated against.  It
    is the one public way to extend the environment outside the kernel,
    and it is narrow by construction: the caller chooses the name and
    the type alone.  [Check.define] still re-adds its own self-entry and
    still rejects duplicates against the ORIGINAL globals. *)
val add_rec_self : string -> Term.t -> t -> t

(** The closed type every entry kind stores. *)
val entry_ty : entry -> Term.t

(** Payload views; Option-returning so callers stay total. *)
val def_of : entry -> def_entry option

val ind_of : entry -> ind_entry option
val ctor_of : entry -> ctor_entry option
val prim_of : entry -> prim_entry option

(** M4 Stage B: view onto the [Axiom] payload, beside the other four. *)
val axiom_of : entry -> axiom_entry option

val find_def : string -> t -> def_entry option
val find_ind : string -> t -> ind_entry option
val find_ctor : string -> t -> ctor_entry option
val find_prim : string -> t -> prim_entry option
val find_axiom : string -> t -> axiom_entry option

(** M4 Stage A: [(n_params, n_indices)] for a declared inductive; retires
    two separate [List.length] calls at every caller that needs both. *)
val find_ind_arity : string -> t -> (int * int) option
