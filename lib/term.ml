(** Core syntax. Variables are de Bruijn indices; binder names are
    display-only and never affect equality. [Lam] and [App] carry a
    quantity stamp: elaboration writes a [Many] placeholder and the
    checker overwrites it with the Pi's quantity, so checker OUTPUT
    terms are authoritative and erasure can be purely structural.

    Marshal-format checklist (M3 Stage D): this type feeds
    [Global.def_entry]/[Global.prim_entry], which [surface/cache.ml]
    marshals whole. Any change here bumps [Cache.format_version]. *)

type t =
  | Var of int
  | Univ of Level.t
  | Pi of Quantity.t * string * t * t
  | Lam of Quantity.t * string * t
  | App of Quantity.t * t * t
  | Let of string * t * t * t  (** let x : ty = def in body *)
  | Ann of t * t  (** (term : type); the checker drops it from output *)
  | Global of string
  | Lit of Literal.t
      (** M3 Stage A: a string or int literal. Cache-format note: this
          type feeds Stage D's prelude cache, so any change here bumps
          that cache's format version constant once it exists. *)
  | Auto
      (** M4 Stage A: an instance request. CHECK position only. The
          checker REPLACES it with the resolved instance application, so
          [Auto] never appears in checker output, in erasure, or at
          runtime. Every other kernel pass carries an explicit total
          backstop arm for it. Real resolution lands in M4 Stage D; here
          it is a total dead end (see [Check.infer]/[Check.check]). *)
  | Match of {
      scrut : t;
      scrut_q : Quantity.t;
          (** M4 Stage A: the elimination quantity. Elaboration writes
              [Many]; the checker OVERWRITES it, stamping [Zero] exactly
              when the subsingleton rule fires (see [Check.match_scrut]).
              Kernel evaluation ignores it; only [Erase] consults it. *)
      motive : motive option;
          (** [None] only survives checking in check-mode (constant
              motive = the expected type) *)
      branches : (string * (Quantity.t * string) list * t) list;
          (** ctor name, its OWN args (binder quantities stamped by the
              checker; elaboration writes [Many] placeholders), body *)
    }

(** M4 Stage A: a match's motive. The old M2/M3 shape, a binder over the
    scrutinee alone, is exactly [{ m_ind = None; m_idx = []; m_self = x;
    m_body = t }], so every M2/M3 term round-trips unchanged.

    M4 fixes round 4 (ctxcat r4 id 0): the ONE convention, stated
    once here and cited from [Pp.term] and [Eval.quote], because "index"
    means two different things around this record and reading the two
    senses as one made the three comments look contradictory.

    - LIST order. [m_idx] is in DECLARATION order, which is
      outermost-binder first: [m_idx = [i; c]] for
      [match t as x in Tw i c return ..] where [Tw : Nat -> Bool ->
      Type 0], so [i] is the Nat index and [c] the Bool one. This is the
      order [Check.infer]'s Match arm binds them in, walking
      [ind.indices] with [List.nth_opt m_idx j], and the order
      [Pp.term] prints them in after "in".
    - DE BRUIJN order. [m_body] is scoped under those binders and then
      [m_self], so inside [m_body] de Bruijn index 0 is [m_self], index
      1 is the LAST element of [m_idx], and index [m] is its FIRST
      element. The de Bruijn sequence is therefore the REVERSE of the
      list, which is why [Pp.term] extends its (de-Bruijn-indexed)
      [names] with [List.rev m_idx] and why [Eval.quote] gives the
      j-th element of [m_idx] the level [size + j].

      M4 fixes round 5 (opus R5-7): the level formula above read
      [size + m - 1 - j], which is the same two-senses-of-"index" slip
      this comment exists to remove.  [Eval.quote] builds
      [List.init m (fun i -> Value.var (size + m - 1 - i))], and that
      [i] is a DE BRUIJN offset (the i-th element of [idx_env] is de
      Bruijn [i + 1]), which is list position [j = m - 1 - i].
      Substituting gives level [size + j]: the FIRST element of
      [m_idx] gets the LOWEST level [size], which is what
      [lib/eval.ml] already says in prose at its own site.

    Pinned by test/main.ml's A13 (a two-index family whose two indices
    are DIFFERENT types, quote/pp round trip, both orders asserted).
    M4 fixes round 5 (opus R5-1): A13 asserts the round-tripped motive
    BODY structurally and the printed motive body textually, so
    dropping [Pp.term]'s [List.rev m_idx] and skewing [Eval.quote]'s
    level arithmetic are each a FAIL;  before round 5 both mutations
    kept the battery green.  Also pinned by PASS-M4FIX-MOTIVE-ORDER,
    whose negative half swaps the two index types and must fail. *)
and motive = {
  m_ind : string option;
      (** the family named by the surface "in I .." clause; [None] for
          an M2/M3 motive and for a materialized constant motive.
          Diagnostic only: conversion IGNORES it. *)
  m_idx : string list;
      (** index binders in DECLARATION order, outermost first; [] =
          M2/M3. See the record's own comment for the de Bruijn order,
          which is the reverse. *)
  m_self : string;  (** the scrutinee binder, INNERMOST *)
  m_body : t;
      (** scoped under [m_idx] (declaration order, outermost first) and
          then [m_self]; so de Bruijn 0 is [m_self] and de Bruijn [m] is
          the head of [m_idx] *)
}

(** M5 Stage B (pin 2): weaken a term by [by] under [cutoff] binders.
    Total and exhaustive over all eleven constructors, with no
    catch-all arm, so a twelfth constructor is a compile error here
    before it is a scope bug in a materialized instance nest.

    The two non-obvious cutoffs are the [Match] ones, and both follow
    the ONE convention this file states at [motive]: [m_body] is scoped
    under [m_idx] and then under [m_self], so it sits under
    [List.length m_idx + 1] binders; a branch body sits under its own
    ctor args, so it sits under [List.length binders] binders. *)
let rec shift ~(cutoff : int) ~(by : int) (t : t) : t =
  match t with
  | Var i -> if i >= cutoff then Var (i + by) else Var i
  | Univ l -> Univ l
  | Pi (q, x, dom, cod) ->
      Pi (q, x, shift ~cutoff ~by dom, shift ~cutoff:(cutoff + 1) ~by cod)
  | Lam (q, x, body) -> Lam (q, x, shift ~cutoff:(cutoff + 1) ~by body)
  | App (q, f, a) -> App (q, shift ~cutoff ~by f, shift ~cutoff ~by a)
  | Let (x, ty, def, body) ->
      Let
        ( x,
          shift ~cutoff ~by ty,
          shift ~cutoff ~by def,
          shift ~cutoff:(cutoff + 1) ~by body )
  | Ann (tm, ty) -> Ann (shift ~cutoff ~by tm, shift ~cutoff ~by ty)
  | Global g -> Global g
  | Lit l -> Lit l
  | Auto -> Auto
  | Match { scrut; scrut_q; motive; branches } ->
      Match
        {
          scrut = shift ~cutoff ~by scrut;
          scrut_q;
          motive =
            motive
            |> Option.map (fun (mo : motive) ->
                   {
                     mo with
                     m_body =
                       shift
                         ~cutoff:(cutoff + List.length mo.m_idx + 1)
                         ~by mo.m_body;
                   });
          branches =
            List.map
              (fun ((c : string), (binders : (Quantity.t * string) list), (body : t)) ->
                (c, binders, shift ~cutoff:(cutoff + List.length binders) ~by body))
              branches;
        }
