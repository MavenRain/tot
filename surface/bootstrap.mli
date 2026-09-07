(** Prelude primitive tables and loading entry points used by the driver and suites. *)

val kept_pi_count : Syntax.t -> int

val phase1_prims : (string * string * Tot_kernel.Prim.t) list
val phase2_prims : (string * string * Tot_kernel.Prim.t) list
val phase3_prims : (string * string * Tot_kernel.Prim.t) list

val prelude_source : unit -> (string, string * Source.error) result
val state : unit -> (Run.state, Serror.t) result
val state_of_src_tailed : string -> (Run.state, Serror.t * string option) result
val cached_state_of_src : string -> (Run.state, Serror.t * string option) result
