(** Surface syntax: names, locations, and sugar. *)

(** M4 Stage A: a match's motive, "as x [in I y1 .. ym] return P".
    [sm_ind]/[sm_idx] are [None]/[[]] for an M2/M3 motive with no "in"
    clause. *)
type smotive = {
  sm_self : string;
  sm_ind : string option;
  sm_idx : string list;
  sm_body : t;
}

and t =
  | SVar of Loc.t * string
  | SType of Loc.t * int
  | SPi of Loc.t * Tot_kernel.Quantity.t * string * t * t
  | SLam of Loc.t * string * t
  | SApp of Loc.t * t * t
  | SLet of Loc.t * string * t * t * t  (** let x : ty := def in body *)
  | SAnn of Loc.t * t * t  (** (term : type) *)
  | SMatch of Loc.t * t * smotive option * (string * string list * t) list
      (** scrutinee, optional "as x [in I y1 .. ym] return P" motive,
          flat branches (ctor name, binder names, body) *)
  | SStr of Loc.t * string  (** M3 Stage A *)
  | SInt of Loc.t * int  (** M3 Stage A *)
  | SLetStar of Loc.t * bool * t * t * string * t * t
      (** M3 Stage C sugar: [let*]/[let*!]. The bool selects [bindDiv]
          (true) over [bindIO] (false). FALLBACK SHAPE (pre-approved by
          dev/M3-PLAN.md's C3, "drop SHole and make let* require
          explicit type arguments"): the two leading [t]s are the
          EXPLICIT type arguments [A] and [B] the desugared
          [bindIO A B e (fun x => body)] / [bindDiv A B e (fun x =>
          body)] application needs (no [SHole], no bounded hole pass;
          see dev/M3-BUILD-LOG.md "Stage C" for the argument), then the
          binder name, the right-hand-side term, and the body. *)
  | SAuto of Loc.t
      (** M4 Stage D: "auto", an instance-request atom.  Elaborates to
          [Term.Auto]. *)
  | SInst of Loc.t * t * t
      (** M4 Stage D: "inst C T", pure sugar for
          [Term.Ann (Term.Auto, Term.App (Quantity.Many, C, T))]. *)

(** M4 Stage D (D5.4): [Syntax.IDef]'s [(rec_, partial)] bool pair,
    collapsed into one sum type so the illegal [partial = true,
    rec_ = false] state is unrepresentable (was a SPEC section 6 debt).
    [parse_def] produces this directly;  [Check.define]'s own two
    booleans are UNCHANGED (its kernel shape is marshaled, and this
    stage must not touch the cache shape twice), so every consumer maps
    this back to [~rec_]/[~partial] with an exhaustive match. *)
type defkind =
  | DNonRec
  | DRec
  | DRecPartial

type item =
  | IDef of {
      loc : Loc.t;
      name : string;
      reducible : bool;
      kind : defkind;
      ty : t;
      def : t;
    }
  | IData of {
      loc : Loc.t;
      name : string;
      params : (string * t) list;  (** always quantity-0 (parser-enforced) *)
      indices : (Tot_kernel.Quantity.t * string * t) list;
          (** M4 Stage A: the index telescope, outermost first, scoped
              under [params]; always quantity-0 (parser-enforced) *)
      level : int;
      ctors : (string * t) list;  (** ctor types, scoped under the params *)
    }
  | IAxiom of {
      loc : Loc.t;
      name : string;
      ty : t;
    }  (** M4 Stage B: a postulated statement, usable only at quantity 0 *)
  | IClass of {
      loc : Loc.t;
      name : string;
      param : string * t;  (** the class's own type parameter, "Type L" *)
      methods : (string * t) list;  (** method name, method type; scoped under [param] *)
    }  (** M4 Stage D: "class NAME (0 A : Type L) := { m1 : T1 ; .. }",
           desugared by [Run.item] into an [IData] dictionary plus one
           projection [IDef] per method. *)
  | IInstance of {
      loc : Loc.t;
      ty : t;
      def : t;
    }  (** M4 Stage D: "instance : TY := TERM", registered by [Run.item]
           under the mangled name ["inst$" ^ C ^ "$" ^ K] read off [ty]'s
           own codomain spine. *)
  | ICheck of Loc.t * t
  | IEval of Loc.t * t

let loc_of (s : t) : Loc.t =
  match s with
  | SVar (loc, _) -> loc
  | SType (loc, _) -> loc
  | SPi (loc, _, _, _, _) -> loc
  | SLam (loc, _, _) -> loc
  | SApp (loc, _, _) -> loc
  | SLet (loc, _, _, _, _) -> loc
  | SAnn (loc, _, _) -> loc
  | SMatch (loc, _, _, _) -> loc
  | SStr (loc, _) -> loc
  | SInt (loc, _) -> loc
  | SLetStar (loc, _, _, _, _, _, _) -> loc
  | SAuto loc -> loc
  | SInst (loc, _, _) -> loc
