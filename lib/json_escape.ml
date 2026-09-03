(** M5 Stage A: the JSON escaper.  DISTINCT from [Pp.escape_string],
    which stays the SOURCE escaper for tot string literals.  The two
    escape sets are not the same and never were: JSON forbids every
    unescaped byte below 0x20, while tot source only needs backslash,
    quote, newline and tab.  [Pp.escape_string]'s own docstring and
    [Interp.json_serialize]'s claimed that the source set was a
    sufficient SUBSET.  It is not, and A3 corrects both texts.

    Covers the RFC 8259 short forms in the order the RFC lists them
    (quote, reverse solidus, backspace, formfeed, newline, carriage
    return, tab), then \u00XX for every remaining byte below 0x20.
    DEL (0x7f) is legal unescaped and is NOT escaped.  Bytes at or
    above 0x80 pass through unchanged, so a UTF-8 payload round trips
    byte for byte. *)
let string (s : string) : string =
  let buf = Buffer.create (String.length s + 2) in
  Buffer.add_char buf '"';
  String.iter
    (fun c ->
      match c with
      | '"' -> Buffer.add_string buf "\\\""
      | '\\' -> Buffer.add_string buf "\\\\"
      | '\b' -> Buffer.add_string buf "\\b"
      | '\012' -> Buffer.add_string buf "\\f"
      | '\n' -> Buffer.add_string buf "\\n"
      | '\r' -> Buffer.add_string buf "\\r"
      | '\t' -> Buffer.add_string buf "\\t"
      | _ -> (
          match () with
          | () when Char.code c < 0x20 ->
              Buffer.add_string buf (Printf.sprintf "\\u%04x" (Char.code c))
          | () -> Buffer.add_char buf c))
    s;
  Buffer.add_char buf '"';
  Buffer.contents buf
