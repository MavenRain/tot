(** M8 Stage D: the kernel environment's storage, private to tot_kernel
    (lib/dune [private_modules]).  The type is ABSTRACT here, so the map
    representation stays inside this module;  [Global] keeps the type
    identity through a manifest alias, which is what lets [Check] use
    this storage API without a public general insertion function.  This
    is the PRIVATE interface, so it exports the general insertion the
    public [Global] interface withholds.

    Review round (2026-09-05), finding BD-1.  The [private_modules] field
    keeps this module out of reach of a client that consumes tot_kernel
    through the normal library dependency.  It is a dependency boundary,
    not a sandbox against a client that chooses its own compiler flags,
    and [test/main.ml] is the one sanctioned white-box client, which
    names [Tot_kernel__Global_store] through the private cmi that the
    [-I lib/.tot_kernel.objs/byte] flag at test/dune:32 puts on its
    include path.  The header of lib/global_store.ml states the same
    boundary without that qualifier;  it stays as measured, because that
    file is inside the frozen PASS-M8A-KERNEL-UNCHANGED digest and this
    round does not re-pin a frozen literal. *)
type 'a t

(** The empty store. *)
val empty : 'a t

(** [find name store] is the binding of [name], or [None]. *)
val find : string -> 'a t -> 'a option

(** [add name value store] binds [name] to [value], replacing any
    earlier binding.  Kernel-internal: the sound ways to extend the
    environment are [Check.define], [Check.declare_ind] and
    [Check.define_ind], which typecheck first. *)
val add : string -> 'a -> 'a t -> 'a t

(** [fold f store init] folds [f] over the bindings in increasing key
    order, the same order the underlying map walks. *)
val fold : (string -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
