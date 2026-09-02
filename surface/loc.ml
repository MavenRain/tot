(** Source positions, 1-based. *)

type t = {
  line : int;
  col : int;
}

let start : t = { line = 1; col = 1 }
let next_col (l : t) : t = { l with col = l.col + 1 }

(** [n] columns forward: the n-fold composition of [next_col] (M3
    fixes round 3, ctxcat id 12, for the lexer's multi-char literal
    tokens). *)
let advance (l : t) (n : int) : t = { l with col = l.col + n }

let next_line (l : t) : t = { line = l.line + 1; col = 1 }
let to_string (l : t) : string = Printf.sprintf "%d:%d" l.line l.col
