(** Evaluation, readback, and conversion. NbE with closures; syntax uses
    indices, values use levels. Everything returns [Result]: a scope bug
    surfaces as an error value, never as an exception.

    Inductives: type and data constructors evaluate to canonical [VInd] /
    [VCtor] values that swallow applications. A rec global ([rec_arg =
    Some k]) ALWAYS starts neutral and unfolds only at application time,
    when argument [k] is a canonical constructor value, so conversion
    cannot diverge on open recursive calls. *)

(** The leading (oldest-first) run of [FApp] argument values of a frame
    list ALREADY reversed to oldest-first order. *)
val leading_fapp_args : Value.frame list -> Value.t list

(** Canonical means: a data constructor FULLY applied. The kernel value
    domain does not erase, so a [VCtor]'s args list carries every
    argument the ctor was applied to, params first (see [run_match]'s
    own [n_params] slice) then its own args telescope in order,
    regardless of quantity; full arity is the sum of the two. A ctor
    looked up but shy of that count is a partial application, not
    canonical (unknown ctor names cannot occur on checked terms; total
    via [Option.fold], no error path needed here). *)
val is_canonical : Global.t -> Value.t -> bool

(** [eval globals env tm] evaluates [tm] under [env] (newest binding
    first) to a semantic value.  A scope or arity bug surfaces as an
    [Error.t], never as an exception. *)
val eval : Global.t -> Value.t list -> Term.t -> (Value.t, Error.t) result

(** [apply globals f a] applies the value [f] to the value [a],
    unfolding a guarded rec global when [a] makes it fire. *)
val apply : Global.t -> Value.t -> Value.t -> (Value.t, Error.t) result

(** Replay a frame list (oldest first) on top of an unfolded head. *)
val replay : Global.t -> Value.t -> Value.frame list -> (Value.t, Error.t) result

(** [app_closure globals clo arg] applies a closure to one argument by
    evaluating its body under the closure env extended with [arg]. *)
val app_closure : Global.t -> Value.closure -> Value.t -> (Value.t, Error.t) result

(** [quote globals size v] reads [v] back to a term under [size]
    binders, turning levels back into indices. *)
val quote : Global.t -> int -> Value.t -> (Term.t, Error.t) result

(** [conv globals size a b] is definitional equality of [a] and [b]
    under [size] binders. *)
val conv : Global.t -> int -> Value.t -> Value.t -> (bool, Error.t) result
