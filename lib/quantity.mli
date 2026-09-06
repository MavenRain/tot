(** Usage marks for the 0/omega fragment of QTT. [Zero] binders exist only
    at check time (types, proofs) and erase before evaluation. [Many]
    binders are runtime data.

    M8 Stage D: the constructors are PUBLIC on purpose.  [Check], [Erase],
    [Eval] and the surface modules build and match [Zero] and [Many]
    directly, so an abstract [t] here does not compile. *)

type t =
  | Zero
  | Many

(** [mul a b] is the usage of a [b]-use inside an [a]-context: [Zero]
    absorbs, so only [Many] times [Many] is [Many]. *)
val mul : t -> t -> t

(** Structural equality of two usage marks. *)
val equal : t -> t -> bool

(** The rendered mark: ["0"] for [Zero] and ["w"] for [Many]. *)
val to_string : t -> string
