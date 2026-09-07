(** Execution outcomes and the host-effect boundary used by the script driver. *)

type outcome =
  | Done of Tot_kernel.Interp.v
  | Exited of int
  | Rejected of string

val deny_envelope : string -> string

val require_action :
  Tot_kernel.Interp.v -> (Tot_kernel.Interp.io_action, Tot_kernel.Error.t) result

val run_io :
  strict_json:bool ->
  Tot_kernel.Interp.globals ->
  Tot_kernel.Interp.io_action ->
  (outcome, Tot_kernel.Error.t) result

val dispatch :
  strict_json:bool ->
  Tot_kernel.Interp.globals ->
  Tot_kernel.Prim.t ->
  Tot_kernel.Interp.v list ->
  (outcome, Tot_kernel.Error.t) result

val render_verdict :
  Tot_kernel.Interp.v -> (string option * int, Tot_kernel.Error.t) result
