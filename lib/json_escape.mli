(** M5 Stage A: the JSON escaper.  DISTINCT from [Pp.escape_string],
    which stays the SOURCE escaper for tot string literals.  The two
    escape sets are not the same and never were: JSON forbids every
    unescaped byte below 0x20, while tot source only needs backslash,
    quote, newline and tab. *)

(** [string s] is [s] rendered as a JSON string, quotes included.

    Covers the RFC 8259 short forms in the order the RFC lists them
    (quote, reverse solidus, backspace, formfeed, newline, carriage
    return, tab), then \u00XX for every remaining byte below 0x20.
    DEL (0x7f) is legal unescaped and is NOT escaped.  Bytes at or
    above 0x80 pass through unchanged, so a UTF-8 payload round trips
    byte for byte. *)
val string : string -> string
