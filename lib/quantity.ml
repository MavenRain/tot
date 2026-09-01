(** Usage marks for the 0/omega fragment of QTT. [Zero] binders exist only
    at check time (types, proofs) and erase before evaluation. [Many]
    binders are runtime data. *)

type t =
  | Zero
  | Many

let mul (a : t) (b : t) : t =
  match (a, b) with
  | Zero, Zero -> Zero
  | Zero, Many -> Zero
  | Many, Zero -> Zero
  | Many, Many -> Many

let equal (a : t) (b : t) : bool =
  match (a, b) with
  | Zero, Zero -> true
  | Many, Many -> true
  | Zero, Many -> false
  | Many, Zero -> false

let to_string (q : t) : string =
  match q with
  | Zero -> "0"
  | Many -> "w"
