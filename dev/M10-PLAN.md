# M10 plan: strict-positive nesting first

## Entry and scope

The entry is `3525a43`, the committed M9 Stage C exit. M9 completed
the surface interfaces and measured two forced rewrites in its hook
port. The next slice is Stage A, C2's nested-inductive admission rule.
C1, well-founded recursion, follows only after C2 has soaked. The Json
constructor migration, mutual inductives, cumulativity and a new
totality rule are outside this slice.

This brief answers the double-flip obligation recorded in
`SPEC.md`, Known debts entering M10, before implementing the rule.
The historical M9 exit is 450 gate-slice PASS lines, 454 including the
wrapper, with 105 kernel cases and 161 surface cases. Stage A measures
its own entry and reports the delta from that measured baseline.

## Strict positivity, not sign multiplication

An occurrence has three ordered classifications: absent, strictly
positive, or forbidden. Combining occurrences takes the worse class.
Entering a Pi domain sends every present occurrence to forbidden;
forbidden is absorbing. Entering a Pi codomain preserves its class.
There is no negative sign that a second domain can flip back.

Thus `Nat -> Self` is admissible, `Self -> Nat` is forbidden, and
`(Self -> Nat) -> Nat` is also forbidden. A container whose parameter
appears in either of the latter positions cannot transport a recursive
occurrence. Hiding that parameter under another container must not
restore admissibility. A phantom parameter still requires its actual
argument to be strictly positive; erasure does not waive this check.

Stage A implements the accepting predicate of this classification:
an occurrence-free type passes; the family's existing exact application
passes; a Pi passes only with an occurrence-free domain and a passing
codomain. A foreign application passes only if each argument containing
the family both passes this predicate and occupies a certified strictly
positive parameter slot.

## Container certificates and termination

The first slice certifies completed, unindexed inductives whose
parameters are erased, plain universe binders. It examines every
constructor argument type at the correct de Bruijn depth. A selected
parameter may appear directly, in an occurrence-free Pi domain's
codomain, or through another certified parameter slot. Recursive uses
of the container itself must apply exactly its original parameter
variables, in order. These uniform self edges are justified by checking
every constructor field in the same certificate.

Foreign certificate queries carry an active `(family, parameter slot)`
set. Revisiting an active query refuses the certificate. Only completed
queries may be reused, and no provisional positive result escapes a
query. Together with structural term descent, this makes the analysis
finite even on recursively connected environment entries. Analysis
must honor the caller's existing checking budget.

Completion alone is insufficient at the public kernel API, which
allows a family to be declared before another family is completed.
Before using a container, a separate budgeted dependency walk must
inspect its reachable global types, constructor fields and definition
bodies. It refuses the current family, any provisional inductive and
unresolved globals. A fresh visited-name set terminates this finite
reachability check. The Stage A walk covers container closures only. A
direct field or a direct Pi domain that names a definition alias is
not walked. This also covers phantom parameter slots: a field
that does not mention the selected parameter may still refer to the
current family through another completed container or a closed alias.

Indexed, dependent and higher-kinded container parameters, provisional
and builtin heads, definition aliases and unknown heads remain refused
when they transport a recursive occurrence. This is a conservative
boundary, not evidence that those forms cannot have sound rules. The
existing direct rule for an indexed recursive family, uniform parameter
check, clean-index check and universe check remain in force.

Certificates are local checker data. No marshalled record, core term,
global interface, interpreter or structural-guard schema changes.
`Cache.format_version` remains 10; its executable digest invalidates
cache entries when the checker binary changes.

## Guard and erasure obligations

The covariant refusal gate deliberately required this design reopening.
Nested constructor fields still contain the owning family's global
name, so `ctor_entry.self_rec` must remain true. Its subsingleton check
must continue to reject runtime elimination from an erased recursive
family, including nesting under a phantom container. Tests exercise
this rather than asserting the Frozen emptiness claim is proved.

The structural guard continues to accept only smaller variables, not
applications. Matching through a strictly positive data container can
expose smaller data; function-field application does not acquire a
new descent rule. Both Frozen horns remain open. C1's formal-domain
and provenance obligations remain outstanding.

## Implementation and validation

Stage A changes the checker, relevant kernel and surface tests,
behavioral gate assertions, the corpus transcript and measured pins,
and the specification/build record. Existing admission outcomes change
only where the new rule permits certified nesting. Historical M9
instrument evidence remains recorded; its nested-Rule refusal becomes
an explicit admission assertion and its wordEnd refusal stays live.

The covariant gate remains present and now asserts admission. The
contravariant gate keeps its exact refusal. The M6 Stage A entry at
SPEC.md:1164-1168 that both fences must fail together is corrected: a
sound widening changes the covariant outcome while retaining
contravariant refusal.

Required checks:

- Build, both complete suites, and the full gate battery.
- Covariant function containers, `List Rule`, multiple container
  layers, recursive List certification and nested construction and
  elimination pass.
- Direct double-domain, contravariant, hidden contravariant,
  double-domain container, nonuniform recursion and unsupported-head
  cases fail with the appropriate checker error.
- Nested recursive metadata preserves erasure and the structural
  guard keeps refusing application descent.
- Public-kernel forward declarations cannot conceal the pending family
  inside a completed container, a second container or a closed alias
  used as a container argument.
- One isolated mutation disables nested admission and is caught by
  an admission assertion. Another unsafely relaxes a domain check and
  is caught by a double-domain or contravariant assertion. Restore
  original bytes after each mutation and rerun the affected checks.
- Re-derive changed corpus and diagnostic pins from actual outputs.
  Preserve timing tiers and bounds; report failures without waivers.
- Report exact PASS additions, removals or intentional replacements
  against the entry battery. Stage all final changes without committing.

Stage A ends after this rule and its evidence are staged. C1 and the
Json migration are later work, after the rule's soak period.
