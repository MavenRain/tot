(** Cached prelude states and the header fields read by the surface suite. *)

val format_version : int
val magic_width : int
val version_width : int
val digest_width : int
val header_width : int
val cache_dir : unit -> string option
val key : string -> string
val load : string -> (Tot_kernel.Global.t * Tot_kernel.Interp.globals) option
val save : string -> Tot_kernel.Global.t -> Tot_kernel.Interp.globals -> unit
