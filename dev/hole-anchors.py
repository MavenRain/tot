#!/usr/bin/env python3
"""The hole-anchor measurement (M5 Stage D, plan D5).

M5 buys a MEASUREMENT instead of a holes implementation: how many
explicit type arguments (ANCHORS) does the real corpus spell that an
expected-type-only hole pass could elide?  There is no hole syntax to
test against, so the number is produced by a STATIC classifier over
the source, and its honesty rests on this file being reviewable, not
on a run.  SPEC section 6 carries the honesty clause: E is an UPPER
bound on what an expected-type-only pass would solve, because this
classifier does not run the checker.

Corpus: stdlib/prelude.tot plus examples/*.tot (sorted), re-measured
at run time.  Test fixtures are excluded: they are written to stress
the kernel, not to be read, so they would bias the ratio.

Step 1, the head table.  A head is POLYMORPHIC when its declared type
opens with one or more leading erased Type binders `(0 X : Type L)`,
or when it is a data/class former with such parameters (a ctor
inherits its family's leading erased Type parameters).  Five prims
open the same way and are hard-coded from their declared types at
surface/bootstrap.ml:104-108 (pureDiv, bindDiv, pureIO, bindIO,
liftIO).  `head -> k` records the count of those leading binders.

Step 2, the anchors.  For every application of a table head in TERM
position, the first k arguments are anchors.  A parenthesized
argument counts as ONE anchor and is not descended into.  A
`let* A B x := e in body` is the corpus spelling of `bindIO A B e
(fun x => body)` and contributes one bindIO site with anchors A, B.

Step 3, the buckets.  Every anchor lands in exactly one bucket, by
mechanical rules stated here:
  N  the head is proof-family (its declared type mentions Eq, Dec or
     Empty: erased proof plumbing) or class-family (its declared type
     mentions a class former: the anchor is a class key), or the site
     sits in INFER position (a match scrutinee, an `eval` item, an
     argument of a locally bound function).
  E  the site sits in CHECK position (a def body, a match-arm body, a
     let* bound expression or body, an argument of a known global
     head) AND the head's result type mentions the anchor's formal
     binder, so first-order matching of the expected type against the
     result type determines the anchor with no other information.
  A  the site sits in CHECK position but the result type does not
     mention the anchor's formal binder, so only a later explicit
     argument's inferred type can fix it (bidirectional application
     checking, which infer's App arm does not do).

Step 4, the output.  The head table and the full site list (file,
line, head, argument index, bucket) go to stdout for hand audit, and
ONE line goes to the measurement log (--log PATH, append):

    ANCHORS total=T expected-type-only=E argument-driven=A neither=N

Step 5, the independent count.  `--count-sites` walks the SAME corpus
by the SAME site rule, prints ONE integer (the anchor total) and
nothing else, and classifies nothing.  Its table builder and its
walker are DELIBERATE textual duplicates of the classifier's: neither
path calls the other or reads the log, so a site dropped from one
walk alone moves the two numbers apart and PASS-M5D-HOLE-ANCHORS goes
red.  Do not "deduplicate" them; the duplication is the proof.
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PUNCT = set("(){}")
PROOF_TOKENS = {"Eq", "Dec", "Empty"}
# Declared types at surface/bootstrap.ml:104-108, leading erased Type
# binders only.  (name, k, formals, result-type tokens)
PRIM_HEADS = [
    ("pureDiv", 1, ["A"], ["Div", "A"]),
    ("bindDiv", 2, ["A", "B"], ["Div", "B"]),
    ("pureIO", 1, ["A"], ["IO", "A"]),
    ("bindIO", 2, ["A", "B"], ["IO", "B"]),
    ("liftIO", 1, ["A"], ["IO", "A"]),
]
DECL_KEYWORDS = ("def", "reducible", "data", "class", "instance",
                 "axiom", "eval", "check")
STOP = {")", "}", "end", "in", "with", "as", "return", ":=", "=>",
        "|", ",", ";"}


def corpus_files():
    files = [os.path.join(ROOT, "stdlib", "prelude.tot")]
    exdir = os.path.join(ROOT, "examples")
    files.extend(os.path.join(exdir, f) for f in sorted(os.listdir(exdir))
                 if f.endswith(".tot"))
    return files


def tokenize(path):
    """One (text, line) token list per file.  Strings are single
    tokens; -- comments and the shebang line are stripped."""
    toks = []
    with open(path, "r", encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, 1):
            if lineno == 1 and line.startswith("#!"):
                continue
            i, n = 0, len(line)
            while i < n:
                c = line[i]
                if c.isspace():
                    i += 1
                    continue
                if c == "-" and i + 1 < n and line[i + 1] == "-":
                    break
                if c == '"':
                    j = i + 1
                    while j < n and line[j] != '"':
                        j += 2 if line[j] == "\\" else 1
                    toks.append((line[i:j + 1], lineno))
                    i = j + 1
                    continue
                if c in PUNCT:
                    toks.append((c, lineno))
                    i += 1
                    continue
                j = i
                while j < n and not line[j].isspace() \
                        and line[j] not in PUNCT and line[j] != '"':
                    j += 1
                toks.append((line[i:j], lineno))
                i = j
    return toks


def split_decls(toks):
    """Chunk a token stream at declaration keywords occurring at
    paren/brace depth 0 outside a match (every corpus decl starts at
    column 0, and no decl keyword appears as an identifier)."""
    decls, cur, depth, matchdepth = [], [], 0, 0
    for t in toks:
        w = t[0]
        if w in ("(", "{"):
            depth += 1
        elif w in (")", "}"):
            depth -= 1
        elif w == "match":
            matchdepth += 1
        elif w == "end":
            matchdepth -= 1
        if w in DECL_KEYWORDS and depth == 0 and matchdepth == 0 and cur:
            decls.append(cur)
            cur = []
        cur.append(t)
    if cur:
        decls.append(cur)
    return decls


def top_split(words, sep):
    """Split a word list on a separator at paren/brace depth 0."""
    parts, cur, depth = [], [], 0
    for w in words:
        if w in ("(", "{"):
            depth += 1
        elif w in (")", "}"):
            depth -= 1
        if w == sep and depth == 0:
            parts.append(cur)
            cur = []
        else:
            cur.append(w)
    parts.append(cur)
    return parts


def leading_type_binders(words):
    """Count leading `( 0 X : Type L )` binder groups; return
    (k, formal names, index just past the last one and its arrow)."""
    formals, i = [], 0
    while True:
        if i + 6 < len(words) and words[i] == "(" and words[i + 1] == "0" \
                and words[i + 3] == ":" and words[i + 4] == "Type" \
                and words[i + 6] == ")":
            formals.append(words[i + 2])
            i += 7
            if i < len(words) and words[i] == "->":
                i += 1
        else:
            break
    return len(formals), formals, i


class Head:
    def __init__(self, name, k, formals, result_words, family):
        self.name = name
        self.k = k
        self.formals = formals
        self.result = set(result_words)
        self.family = family  # "plain" | "proof" | "class"


def family_of(type_words, class_formers):
    if any(w in PROOF_TOKENS for w in type_words):
        return "proof"
    if any(w in class_formers for w in type_words):
        return "class"
    return "plain"


def build_table(decls):
    """Step 1: the head table, plus the known-global name set and the
    class-former name set."""
    table, globals_seen, class_formers = {}, set(), set()
    for d in decls:
        words = [w for (w, _l) in d]
        kw = words[0]
        if kw == "reducible" and len(words) > 1:
            kw = words[1]
            words = words[1:]
        if kw == "def" or kw == "axiom":
            j = 1
            if j < len(words) and words[j] == "rec":
                j += 1
            name = words[j]
            globals_seen.add(name)
            rest = words[j + 1:]
            if not rest or rest[0] != ":":
                continue
            ty = top_split(rest[1:], ":=")[0]
            k, formals, past = leading_type_binders(ty)
            segs = top_split(ty[past:], "->")
            result = segs[-1] if segs else []
            fam = family_of(ty, class_formers)
            if k > 0:
                table[name] = Head(name, k, formals, result, fam)
        elif kw == "data" or kw == "class":
            name = words[1]
            globals_seen.add(name)
            if kw == "class":
                class_formers.add(name)
            # params sit between the name and the top-level ':'
            head_ws = top_split(words[2:], ":=")[0]
            pre_colon = top_split(head_ws, ":")[0]
            k, formals, _past = leading_type_binders(pre_colon)
            if k > 0:
                fam = "class" if kw == "class" else "plain"
                table[name] = Head(name, k, formals, [name] + formals, fam)
            body = top_split(words[2:], ":=")
            if len(body) < 2:
                continue
            if kw == "data":
                for ctor in top_split(body[1], "|"):
                    if not ctor:
                        continue
                    cname = ctor[0]
                    globals_seen.add(cname)
                    if k == 0 or len(ctor) < 2 or ctor[1] != ":":
                        continue
                    cty = ctor[2:]
                    csegs = top_split(cty, "->")
                    cresult = csegs[-1] if csegs else []
                    cfam = family_of([name] + cty, class_formers)
                    table[cname] = Head(cname, k, formals, cresult, cfam)
            else:
                # class body: { field : ftype }  -> projections and the
                # dictionary ctor mk<Name>, every one class-family.
                inner = [w for w in body[1] if w not in ("{", "}")]
                for field in top_split(inner, ","):
                    if field:
                        fname = field[0]
                        globals_seen.add(fname)
                        if k > 0:
                            table[fname] = Head(fname, k, formals, [], "class")
                mk = "mk" + name
                globals_seen.add(mk)
                if k > 0:
                    table[mk] = Head(mk, k, formals, [name] + formals, "class")
    for (pname, pk, pformals, presult) in PRIM_HEADS:
        table[pname] = Head(pname, pk, pformals, presult, "plain")
        globals_seen.add(pname)
    for pname in ("stringConcat", "stringLength", "stringEq",
                  "stringContains", "intAdd", "intSub", "intEq",
                  "intToString", "readStdin", "printLine", "exitWith",
                  "getEnv", "stringSlice", "stringSplit", "stringToInt",
                  "intCompare", "readFile", "writeFile", "argv",
                  "procRun", "jsonParse", "jsonSerialize", "regexTest",
                  "regexMatch"):
        globals_seen.add(pname)
    return table, globals_seen


class Walker:
    """Step 2 and 3: find every table-head application in term
    position and classify its anchors."""

    def __init__(self, table, known, fname):
        self.table = table
        self.known = known
        self.fname = fname
        self.sites = []

    def stop(self, toks, i, extra):
        return i >= len(toks) or toks[i][0] in STOP or toks[i][0] in extra

    def skip_until(self, toks, i, targets):
        depth = 0
        while i < len(toks):
            w = toks[i][0]
            if w in ("(", "{"):
                depth += 1
            elif w in (")", "}"):
                depth -= 1
            elif depth == 0 and w in targets:
                return i
            i += 1
        return i

    def atom(self, toks, i, pos, env):
        """Consume one atom WITHOUT recording sites inside it (used
        for anchor arguments, which count once at the outer head)."""
        if toks[i][0] == "(":
            depth, j = 1, i + 1
            while j < len(toks) and depth > 0:
                if toks[j][0] == "(":
                    depth += 1
                elif toks[j][0] == ")":
                    depth -= 1
                j += 1
            return " ".join(w for (w, _l) in toks[i + 1:j - 1]), j
        return toks[i][0], i + 1

    def expr(self, toks, i, pos, env, extra=()):
        """Walk one expression region; return the index just past it."""
        while not self.stop(toks, i, extra):
            w, line = toks[i]
            if w == "fun":
                j = i + 1
                binders = []
                while j < len(toks) and toks[j][0] != "=>":
                    if toks[j][0] not in ("(", ")", ":", "0", "1", "w"):
                        binders.append(toks[j][0])
                    j += 1
                i = self.expr(toks, j + 1, pos, env | set(binders), extra)
                continue
            if w == "match":
                i = self.expr(toks, i + 1, "infer", env,
                              ("with", "as", "in", "return"))
                i = self.skip_until(toks, i, {"with"}) + 1
                while i < len(toks) and toks[i][0] == "|":
                    j = i + 1
                    pat = []
                    while j < len(toks) and toks[j][0] != "=>":
                        if toks[j][0] not in ("(", ")"):
                            pat.append(toks[j][0])
                        j += 1
                    i = self.expr(toks, j + 1, "check",
                                  env | set(pat[1:]), ("|",) + tuple(extra))
                if i < len(toks) and toks[i][0] == "end":
                    i += 1
                continue
            if w == "let*":
                a1, j = self.atom(toks, i + 1, pos, env)
                a2, j = self.atom(toks, j, pos, env)
                binder = toks[j][0]
                self.record(line, "bindIO", [a1, a2], pos)
                j = self.expr(toks, j + 2, "check", env, ("in",))
                i = self.expr(toks, j + 1, pos, env | {binder}, extra)
                continue
            if w == "(":
                i = self.expr(toks, i + 1, pos, env)
                if i < len(toks) and toks[i][0] == ")":
                    i += 1
                i = self.args(toks, i, "check", env, extra)
                continue
            if w in (":", "->", "=>", ":=", "0", "1"):
                i += 1
                continue
            # identifier or literal head
            head = w
            i += 1
            if head in self.table and not self.stop(toks, i, extra) \
                    and head not in env:
                h = self.table[head]
                anchors = []
                while len(anchors) < h.k and not self.stop(toks, i, extra):
                    a, i = self.atom(toks, i, pos, env)
                    anchors.append(a)
                if anchors:
                    self.record(line, head, anchors, pos)
                i = self.args(toks, i, "check", env, extra)
            elif head in self.known and head not in env:
                i = self.args(toks, i, "check", env, extra)
            else:
                i = self.args(toks, i, "infer", env, extra)
        return i

    def args(self, toks, i, argpos, env, extra):
        while not self.stop(toks, i, extra):
            w, _line = toks[i]
            if w == "(":
                i = self.expr(toks, i + 1, argpos, env)
                if i < len(toks) and toks[i][0] == ")":
                    i += 1
                continue
            if w in ("fun", "match", "let*"):
                return self.expr(toks, i, argpos, env, extra)
            if w in (":", "->", "=>", ":=", "0", "1"):
                i += 1
                continue
            if w in self.table and w not in env:
                return self.expr(toks, i, argpos, env, extra)
            i += 1
        return i

    def record(self, line, head, anchors, pos):
        h = self.table[head]
        for idx, a in enumerate(anchors):
            if h.family in ("proof", "class") or pos == "infer":
                bucket = "N"
            elif idx < len(h.formals) and h.formals[idx] in h.result:
                bucket = "E"
            else:
                bucket = "A"
            self.sites.append((self.fname, line, head, idx, a, pos, bucket))


def classify():
    """The classify path: build the table, walk every body, return the
    site list."""
    all_decls, per_file = [], []
    for path in corpus_files():
        toks = tokenize(path)
        decls = split_decls(toks)
        all_decls.extend(decls)
        per_file.append((path, decls))
    table, known = build_table(all_decls)
    sites = []
    for path, decls in per_file:
        rel = os.path.relpath(path, ROOT)
        wk = Walker(table, known, rel)
        for d in decls:
            words = [w for (w, _l) in d]
            kw = words[0]
            if kw == "reducible" and len(words) > 1:
                kw = words[1]
            if kw in ("def", "instance"):
                k = next((n for n, (w, _l) in enumerate(d) if w == ":="
                          and depth_at(d, n) == 0), None)
                if k is not None:
                    wk.expr(d, k + 1, "check", set())
            elif kw == "eval":
                start = 1 if words[0] == "eval" else 2
                wk.expr(d, start, "infer", set())
        sites.extend(wk.sites)
    return table, sites


def depth_at(d, n):
    depth = 0
    for (w, _l) in d[:n]:
        if w in ("(", "{"):
            depth += 1
        elif w in (")", "}"):
            depth -= 1
    return depth


# --------------------------------------------------------------------
# The COUNT path (step 5).  A deliberate textual duplicate of the
# table builder and the walker above, WITHOUT classification: it
# prints one integer, the anchor total, and must stay independent so
# that a site dropped from one walk alone is a loud mismatch.  It
# never reads the measurement log.
# --------------------------------------------------------------------

def count_build_table(decls):
    table, known, cf = {}, set(), set()
    for d in decls:
        words = [w for (w, _l) in d]
        kw = words[0]
        if kw == "reducible" and len(words) > 1:
            kw = words[1]
            words = words[1:]
        if kw in ("def", "axiom"):
            j = 1
            if j < len(words) and words[j] == "rec":
                j += 1
            name = words[j]
            known.add(name)
            rest = words[j + 1:]
            if not rest or rest[0] != ":":
                continue
            ty = top_split(rest[1:], ":=")[0]
            k, _formals, _past = leading_type_binders(ty)
            if k > 0:
                table[name] = k
        elif kw in ("data", "class"):
            name = words[1]
            known.add(name)
            if kw == "class":
                cf.add(name)
            head_ws = top_split(words[2:], ":=")[0]
            k, _formals, _p = leading_type_binders(top_split(head_ws, ":")[0])
            if k > 0:
                table[name] = k
            body = top_split(words[2:], ":=")
            if len(body) < 2:
                continue
            if kw == "data":
                for ctor in top_split(body[1], "|"):
                    if ctor:
                        known.add(ctor[0])
                        if k > 0 and len(ctor) >= 2 and ctor[1] == ":":
                            table[ctor[0]] = k
            else:
                inner = [w for w in body[1] if w not in ("{", "}")]
                for field in top_split(inner, ","):
                    if field:
                        known.add(field[0])
                        if k > 0:
                            table[field[0]] = k
                known.add("mk" + name)
                if k > 0:
                    table["mk" + name] = k
    for (pname, pk, _f, _r) in PRIM_HEADS:
        table[pname] = pk
        known.add(pname)
    for pname in ("stringConcat", "stringLength", "stringEq",
                  "stringContains", "intAdd", "intSub", "intEq",
                  "intToString", "readStdin", "printLine", "exitWith",
                  "getEnv", "stringSlice", "stringSplit", "stringToInt",
                  "intCompare", "readFile", "writeFile", "argv",
                  "procRun", "jsonParse", "jsonSerialize", "regexTest",
                  "regexMatch"):
        known.add(pname)
    return table, known


class CountWalker:
    def __init__(self, table, known):
        self.table = table
        self.known = known
        self.count = 0

    def stop(self, toks, i, extra):
        return i >= len(toks) or toks[i][0] in STOP or toks[i][0] in extra

    def skip_until(self, toks, i, targets):
        depth = 0
        while i < len(toks):
            w = toks[i][0]
            if w in ("(", "{"):
                depth += 1
            elif w in (")", "}"):
                depth -= 1
            elif depth == 0 and w in targets:
                return i
            i += 1
        return i

    def atom(self, toks, i):
        if toks[i][0] == "(":
            depth, j = 1, i + 1
            while j < len(toks) and depth > 0:
                if toks[j][0] == "(":
                    depth += 1
                elif toks[j][0] == ")":
                    depth -= 1
                j += 1
            return j
        return i + 1

    def expr(self, toks, i, env, extra=()):
        while not self.stop(toks, i, extra):
            w = toks[i][0]
            if w == "fun":
                j = i + 1
                binders = []
                while j < len(toks) and toks[j][0] != "=>":
                    if toks[j][0] not in ("(", ")", ":", "0", "1", "w"):
                        binders.append(toks[j][0])
                    j += 1
                i = self.expr(toks, j + 1, env | set(binders), extra)
                continue
            if w == "match":
                i = self.expr(toks, i + 1, env,
                              ("with", "as", "in", "return"))
                i = self.skip_until(toks, i, {"with"}) + 1
                while i < len(toks) and toks[i][0] == "|":
                    j = i + 1
                    pat = []
                    while j < len(toks) and toks[j][0] != "=>":
                        if toks[j][0] not in ("(", ")"):
                            pat.append(toks[j][0])
                        j += 1
                    i = self.expr(toks, j + 1, env | set(pat[1:]),
                                  ("|",) + tuple(extra))
                if i < len(toks) and toks[i][0] == "end":
                    i += 1
                continue
            if w == "let*":
                j = self.atom(toks, i + 1)
                j = self.atom(toks, j)
                binder = toks[j][0]
                self.count += 2
                j = self.expr(toks, j + 2, env, ("in",))
                i = self.expr(toks, j + 1, env | {binder}, extra)
                continue
            if w == "(":
                i = self.expr(toks, i + 1, env)
                if i < len(toks) and toks[i][0] == ")":
                    i += 1
                i = self.args(toks, i, env, extra)
                continue
            if w in (":", "->", "=>", ":=", "0", "1"):
                i += 1
                continue
            head = w
            i += 1
            if head in self.table and not self.stop(toks, i, extra) \
                    and head not in env:
                k = self.table[head]
                taken = 0
                while taken < k and not self.stop(toks, i, extra):
                    i = self.atom(toks, i)
                    taken += 1
                self.count += taken
                i = self.args(toks, i, env, extra)
            else:
                i = self.args(toks, i, env, extra)
        return i

    def args(self, toks, i, env, extra):
        while not self.stop(toks, i, extra):
            w = toks[i][0]
            if w == "(":
                i = self.expr(toks, i + 1, env)
                if i < len(toks) and toks[i][0] == ")":
                    i += 1
                continue
            if w in ("fun", "match", "let*"):
                return self.expr(toks, i, env, extra)
            if w in (":", "->", "=>", ":=", "0", "1"):
                i += 1
                continue
            if w in self.table and w not in env:
                return self.expr(toks, i, env, extra)
            i += 1
        return i


def count_sites():
    all_decls, per_file = [], []
    for path in corpus_files():
        toks = tokenize(path)
        decls = split_decls(toks)
        all_decls.extend(decls)
        per_file.append((path, decls))
    table, known = count_build_table(all_decls)
    total = 0
    for _path, decls in per_file:
        wk = CountWalker(table, known)
        for d in decls:
            words = [w for (w, _l) in d]
            kw = words[0]
            if kw == "reducible" and len(words) > 1:
                kw = words[1]
            if kw in ("def", "instance"):
                k = next((n for n, (w, _l) in enumerate(d) if w == ":="
                          and depth_at(d, n) == 0), None)
                if k is not None:
                    wk.expr(d, k + 1, set())
            elif kw == "eval":
                wk.expr(d, 1, set())
        total += wk.count
    return total


def main(argv):
    if "--count-sites" in argv:
        print(count_sites())
        return 0
    log_path = None
    if "--log" in argv:
        log_path = argv[argv.index("--log") + 1]
    table, sites = classify()
    print("HEAD TABLE (head -> k, family):")
    for name in sorted(table):
        h = table[name]
        print("  %s -> %d %s" % (name, h.k, h.family))
    print("SITES (file:line head arg anchor pos bucket):")
    for (f, l, head, idx, a, pos, b) in sites:
        print("SITE %s:%d head=%s arg=%d anchor=[%s] pos=%s bucket=%s"
              % (f, l, head, idx, a, pos, b))
    t = len(sites)
    e = sum(1 for s in sites if s[6] == "E")
    a = sum(1 for s in sites if s[6] == "A")
    n = sum(1 for s in sites if s[6] == "N")
    line = "ANCHORS total=%d expected-type-only=%d argument-driven=%d neither=%d" % (t, e, a, n)
    print(line)
    if log_path is not None:
        with open(log_path, "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
