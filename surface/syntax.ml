(** Surface syntax: names, locations, and sugar; no indices yet. *)

type t =
  | SVar of Loc.t * string
  | SType of Loc.t * int
  | SPi of Loc.t * Tot_kernel.Quantity.t * string * t * t
  | SLam of Loc.t * string * t
  | SApp of Loc.t * t * t
  | SLet of Loc.t * string * t * t * t  (** let x : ty := def in body *)
  | SAnn of Loc.t * t * t  (** (term : type) *)
  | SMatch of Loc.t * t * (string * t) option * (string * string list * t) list
      (** scrutinee, optional "as x return P" motive, flat branches
          (ctor name, binder names, body) *)
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

type item =
  | IDef of {
      loc : Loc.t;
      name : string;
      reducible : bool;
      rec_ : bool;  (** [def rec]: route through the guarded define path *)
      partial : bool;
          (** M3 Stage C: [def rec partial]; always [false] unless
              [rec_] is also [true].  This invariant is NOT
              type-enforced (M3 fixes, C4'/C12): the record admits any
              [(rec_, partial)] pair, and only the PARSER maintains it
              ([partial] only ever follows [rec]), so every OTHER
              producer of [IDef] must maintain it by hand.  Collapsing
              the two flags into one sum type (NonRec | Rec |
              RecPartial) would make the illegal state
              unrepresentable; recorded as a SPEC section 6 debt, M4
              work. *)
      ty : t;
      def : t;
    }
  | IData of {
      loc : Loc.t;
      name : string;
      params : (string * t) list;  (** always quantity-0 (parser-enforced) *)
      level : int;
      ctors : (string * t) list;  (** ctor types, scoped under the params *)
    }
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
