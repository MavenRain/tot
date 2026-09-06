(** Structural erasure. Runs ONLY on checker OUTPUT terms, whose [Lam]
    and [App] quantity stamps are authoritative: quantity-0 binders
    vanish (indices under them shift down) and quantity-0 arguments are
    dropped. No types, globals, or evaluation are consulted. *)

(** Newest binder first; the bool means: this binder survives erasure. *)
type ctx = (string * bool) list

(** [term ctx tm] erases [tm] under [ctx].  The result carries no type
    and no quantity;  an [Error.Unbound_var] or [Error.Erased_use] means
    the input was not checker output. *)
val term : ctx -> Term.t -> (Eterm.t, Error.t) result

(** [closed def] is [term \[\] def], the entry point for a top-level
    definition body. *)
val closed : Term.t -> (Eterm.t, Error.t) result
