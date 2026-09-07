(** Elaboration with an optional local-type environment and an expected-type entry point. *)

val term :
  Tot_kernel.Global.t ->
  string list ->
  ?locals:Tot_kernel.Term.t option list ->
  Syntax.t ->
  (Tot_kernel.Term.t, Serror.t) result

val term_at :
  Tot_kernel.Global.t ->
  string list ->
  expected:Tot_kernel.Term.t ->
  ?locals:Tot_kernel.Term.t option list ->
  Syntax.t ->
  (Tot_kernel.Term.t, Serror.t) result
