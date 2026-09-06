(** M8 Stage D: the kernel environment's storage.  lib/dune lists this
    module in [private_modules], so no client outside tot_kernel can
    name it and no client outside tot_kernel can insert an entry of its
    own;  [Global] re-exports the narrow entry point alone.  The four
    values below delegate directly to the same [Map.Make (String)]
    operations the environment used before, with no wrapper record and
    no new runtime constructor, so the runtime representation and the
    ordering of the original map are unchanged.  [surface/cache.ml]
    marshals a whole [Global.t], so that identity is what keeps
    [Cache.format_version] at its value. *)

module StringMap = Map.Make (String)

type 'a t = 'a StringMap.t

let empty : 'a t = StringMap.empty
let find (name : string) (store : 'a t) : 'a option = StringMap.find_opt name store
let add (name : string) (value : 'a) (store : 'a t) : 'a t = StringMap.add name value store

let fold (f : string -> 'a -> 'b -> 'b) (store : 'a t) (init : 'b) : 'b =
  StringMap.fold f store init
