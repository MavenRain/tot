(** The kernel's only failure channel. No exception exists anywhere. *)

type t =
  | Unbound_var of int
  | Unbound_global of string
  | Duplicate_global of string
  | Bad_level of int
  | Not_a_function of string
  | Not_a_universe of string
  | Mismatch of {
      expected : string;
      actual : string;
    }
  | Erased_use of string
  | Cannot_infer of string

let to_string (e : t) : string =
  match e with
  | Unbound_var ix -> Printf.sprintf "unbound variable (index %d)" ix
  | Unbound_global n -> Printf.sprintf "unknown global %s" n
  | Duplicate_global n -> Printf.sprintf "duplicate global %s" n
  | Bad_level l -> Printf.sprintf "internal: level %d escapes its scope" l
  | Not_a_function s -> Printf.sprintf "not a function type: %s" s
  | Not_a_universe s -> Printf.sprintf "not a universe: %s" s
  | Mismatch { expected; actual } ->
      Printf.sprintf "type mismatch: expected %s, found %s" expected actual
  | Erased_use x -> Printf.sprintf "erased variable %s used at runtime" x
  | Cannot_infer x ->
      Printf.sprintf "cannot infer a type for the bare lambda (binder %s)" x

let tag (e : t) : string =
  match e with
  | Unbound_var _ -> "Unbound_var"
  | Unbound_global _ -> "Unbound_global"
  | Duplicate_global _ -> "Duplicate_global"
  | Bad_level _ -> "Bad_level"
  | Not_a_function _ -> "Not_a_function"
  | Not_a_universe _ -> "Not_a_universe"
  | Mismatch _ -> "Mismatch"
  | Erased_use _ -> "Erased_use"
  | Cannot_infer _ -> "Cannot_infer"
