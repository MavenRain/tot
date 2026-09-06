(** Structural totality guard for top-level [def rec]. Runs on the STAMPED
    body the checker returns. The body's leading lambdas are the formals;
    the guard searches for a principal argument position [k] (first fit
    wins) such that every occurrence of the recursive global is a call
    whose argument [k] is a variable made structurally smaller by a match
    on the principal (or on something already smaller). *)

(** M6 Stage A (verdict pin 8, ruling R1): the totality rule [guard]
    runs.  A single-constructor type ON PURPOSE.  [Check.define]
    keeps its REQUIRED named [~rule] argument, every call site names
    [Structural], and every match on [rule] is exhaustive with no
    wildcard, so an M7 admission rule (the WF package) re-enters by
    compiler error at every consumer.  The M5 [Structural_wf] spike
    is DELETED, not dark: re-entry is a rebuild of the [Term.App] arm
    of [guarded_call] below, against the pin-9 oracle fixtures
    (test/fixtures/bad2.tot, crossformal-t.tot, deep2.tot), and any
    such rule must carry a PROVENANCE side condition tying the
    Smaller head to the candidate position (the seed invariant, SPEC
    section 2 entry dated 2026-09-03). *)
type rule = Structural

(** Count the leading lambdas and return the inner body. *)
val peel : int -> Term.t -> int * Term.t

(** Collect an application spine: head plus args oldest first. *)
val spine : Term.t -> Term.t list -> Term.t * Term.t list

(** Does [name] occur anywhere in [t] as a [Term.Global]? Structural,
    total, exhaustive over every [Term.t] arm; used to tell a genuinely
    recursive [def rec] body from one that merely carries the [rec]
    keyword (in which case the totality guard is skipped entirely rather
    than vacuously satisfied at the first formal). *)
val mentions : string -> Term.t -> bool

(** Does candidate position [k] guard every recursive occurrence? *)
val passes : rule:rule -> recname:string -> int -> int -> Term.t -> bool

(** Find the first formal position (0-based, outermost first) on which the
    stamped body of [def rec recname] is structurally recursive under
    [Structural], the single shipped rule (M6 Stage A, pin 8: an M7
    admission rule re-enters through [type rule] and the [Term.App] arm
    of [guarded_call], never through a driver flag). *)
val guard : rule:rule -> recname:string -> Term.t -> (int, Error.t) result
