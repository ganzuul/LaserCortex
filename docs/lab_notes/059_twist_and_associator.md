# Lab Note 059 — Twist and Associator: Two ℤ/2 Signs of One Structure

**Date**: 2026-09-01
**Follows**: 053 (anyon/MHD readings), 057 (strut quantization), 058 (fidelity
dial; F2 plan); trigger: owner question on `docs/MARK.TEX2.pdf`
**Status**: NOTE + GLOSSARY — §0 is canonical terminology for the project going
forward; §2–§4 carry the answer to the question "is this cocycle represented by
the twisted-strip model?"
**Protocol**: Timespace Decomposition v0.3 — (4,4) Signature Model

---

## 0. Terminology — what we mean, and where the words come from

### ℤ/2

**What we mean.** The two-element group; concretely the signs {+1, −1} under
multiplication — the "flip exactly twice and you're home" group. Throughout
this note it names any quantity that takes two values whose only structure is
sign inversion: `signCocycle` is ℤ/2-valued, F2's bracket transport is ℤ/2,
the strip's "one twist vs none" is ℤ/2 (mod 2 in parity language).

**Where it comes from.** The congruence-mod-*n* notation is Gauss,
*Disquisitiones Arithmeticae* (1801); ℤ/*n*ℤ is the modern shorthand for the
integers under addition mod *n*, and ℤ/2 is its two-element case. The physics
lineage: π₁(SO(3)) ≅ ℤ/2 — a rigid body rotated through 2π is not the same as
no rotation, only 4π closes — is the exact fact behind the strip paper's
half-integral spin and behind every "sign after one circuit, back after two"
statement. In quantum many-body language it is fermion parity (−1)^F.

### F-move (and F-symbol)

**What we mean here.** A change of bracketing of a joint product, together
with the number that records *how* the value changed. In anyon theory: fuse
three particles two ways ((ab)c)d vs a(b(cd)) and so on — the two fusion-tree
bases are related by a unitary *F-move* carrying the **F-symbol**; consistency
around the pentagon of bracketings of four objects gives the **pentagon
equation**. Our project version, at skeleton level: a single `contracts_one`
rotation replaces `(xy)z` by `x(yz)`, and the F-symbol candidate is exactly
`signCocycle` — +1 when the swap is free, −1 when the value comes back
negated. `pentagon_cocycle_basis` [P] is *verbatim* the pentagon equation for
that symbol (on basis inputs).

**Where it comes from.** Moore & Seiberg, "Polynomial associativity and the
finite representation of mapping class groups" (Comm. Math. Phys., 1989) —
rational conformal field theory's fusion spaces; the F-move name and its
computational use were made standard by Kitaev ("Fault-tolerant quantum
computation by anyons", Ann. Phys. 303, 2003; F/R moves as the operations of
an anyonic computer). The pentagon identity itself is Mac Lane's coherence
condition for monoidal categories (1963); the modern textbook home is
Etingof–Nikshych–Ostrik, *Tensor Categories* (2015). "F" is simply the first
letter of **F**usion. In this repo the correspondence "Tamari rotation =
F-move" is registered as open ledger item 8; note that the F2 program
(058 §5) would deliver its first concrete instance: the bridge theorem
"rotation ratio = local signCocycle" *is* the statement that φ is the F-symbol
of the skeleton.

### Skeleton

**Warning: three senses live in this repo. Never use the bare word without a
qualifier.**

* **(a) The 7-Skeleton** (project-specific, notes 006/007): the collapse of
  the 15 named logics onto the seven non-identity basis directions e₁…e₇ of
  the split octonion — the *logic-space* skeleton, justified by the carrier
  morphism `toSO`.
* **(b) The basis skeleton** (this note, and the F2/057/058 usage): the
  signed basis set {±e₀, …, ±e₇} closed under `split_oct_mul`. It is a
  **loop of order 16**, not a group — closure holds (64-case check), the unit
  is e₀, inverses exist, associativity does not. Center {±e₀}; quotient by it
  is (ℤ/2)³, whose seven nonzero elements are the Fano-plane points and whose
  lines mark the associative triples. The classical literature has a standard
  name for exactly this object: the **Cayley–Dickson loop** Q₃ — the
  multiplicative closure of the standard basis under the Cayley–Dickson
  doubling (studied in loop theory, e.g. Drápal's work on Cayley–Dickson
  loops [C, exact citation to pin]). `signCocycle` measures the loop's
  failure to be a group; 057's quantization is a skeleton theorem; F2's
  transport lives on it.
* **(c) The k-skeleton of a cell complex** (topology standard; used in note
  019): here specifically the **1-skeleton of the associahedron** — vertices
  = bracketings, edges = rotations — which *is* the Tamari graph. In §4 the
  "Tamari ribbon" is a picture on exactly this 1-skeleton.

Sense (b) is what "the skeleton" means in 057/058/F2, and sense (c) is what
"the graph the sign transports on" means in this note. Sense (a) is a
different projection of the same e₁…e₇ directions onto logic-space.

### Twist (topological spin) — needed below

In a ribbon (balanced) category — Joyal–Street's language of braided/balanced
monoidal categories, equivalently the calculus of framed tangles — every
particle label carries a **twist** θ = e^{2πis}: rotate the anyon's worldline
once and the state picks up θ. Diagrammatically the worldline *is* a ribbon,
and rotating it is literally drawing a twisted strip. This is the sign the
Williamson–van der Mark model manipulates; §2 argues it is a *different slot*
from the associator, though the same group sits in both.

## 1. The question

Owner (2026-09-01), after the F2 plan: **is our cocycle represented by the
twisted strip model?** Source paper: J. G. Williamson and M. B. van der Mark,
"Is the electron a photon with toroidal topology?", *Annales de la Fondation
Louis de Broglie* **22**(2), 1997 (`docs/MARK.TEX2.pdf`). The model in one
paragraph: a circularly polarized photon is a strip carrying exactly one full
twist (the E/B frame rotates 2π per wavelength); periodic boundary conditions
close the strip into a loop with the twist retained; the closure is a double
loop with each face consistently outside/inside, and the sense of closure
(inwards vs outwards E-field) distinguishes electron from positron. The
paper's hinge condition: *"it is crucial that there is exactly one full
twist, a half twist or double twist, for example, would not give rise to a
charge."*

## 2. The answer

**No — the strip represents the twist, not the associator. They are two
different ℤ/2 signs living on different slots of the same algebraic
structure, related by an axiom, not by identity.**

| | the strip's sign | our φ = `signCocycle` |
| --- | --- | --- |
| mathematical object | holonomy of a framed **spatial** loop: winding/twist number mod 2; the π₁(SO(3)) = ℤ/2 domain | associator defect of a **product**: equal-or-negated under a re-bracketing; a 3-cocycle on the skeleton's (ℤ/2)³ |
| base space | the photon's closed path in space | the 1-skeleton of the associahedron (the Tamari graph) — no space involved |
| cohomological degree | 1 (loop holonomy) | 3 (associator) |
| what feeds the sign | sense of twist; closure into/out of plane | whether the rotated block triple is on an associative (Fano) line |
| contains non-associativity? | no — field amplitudes multiply associatively; there is no associator in the paper to represent | yes — that is the whole object |

## 3. Why the two nonetheless feel like the same creature

Four genuine shared features, then the precise statement of the relationship.

1. **One circuit flips, two circuits restore.** The strip's double-loop is the
   spinor signature. F2's transport is the same shape in the re-bracketing
   direction: any rotation path accumulates ∏φ ∈ {±1}; φ² = 1 by definition.
2. **Discreteness protects the physics — same modal sentence.**
   "Exactly one full twist; half or double gives no charge" (strip) has the
   identical form as "exactly {0, 4}; no intermediate basis strut exists"
   (057 [P]). Both: the mechanism runs on one quantum, fractions and
   multiples break it. [H] that this parallel is more than rhetorical — F2b
   makes one side of it a transport law.
3. **Handedness is the sign-source in both** — sense of twist ↔ total
   antisymmetry of the associator (`associator_antisymm_left` [P]; Ch 4's
   reification).
4. **The categorical bridge.** In a ribbon category, twist θ and associator F
   are distinct invariants of one structure, linked by the balancing axiom
   (θ of a composite in terms of θ's and the braiding). The fermion category
   **sVec** sits at one corner: F trivial, twist of the odd object = −1. The
   octonion skeleton sits at the mirror corner: twist not defined, F = φ
   nontrivial. And the literature places our φ squarely in this game:
   Kapustin–Li (arXiv:1201.2648) and Gu–Wen on iterated group extensions
   (arXiv:1701.08264) show the octonion associator sign *is* a genuine class
   in the cohomology (H³((ℤ/2)³, U(1)) / super-cohomology family) that
   physically twists iterated fermion-parity extensions — i.e. our skeleton's
   cocycle is a known, realized sign in quantum matter, the same shop that
   produces the strip's spin. [C — pin the exact section attribution; an
   earlier verification run flagged corrections pending here. No literature
   was found connecting the octonion 3-cocycle to toroidal-electron models
   specifically; report honestly: none.]

## 4. The picture of φ (what to draw instead)

A ℤ/2 flat local system on a graph is represented by taping a strip to every
edge — untwisted where the label is +1, half-twisted where −1 — and flatness
is exactly "strips match around every face". So the visualization of our
cocycle is a **Tamari ribbon**: the rotation 1-skeleton of an n-fold bracket
word, edges taped by φ's values; the pentagon faces close because
`pentagon_cocycle_basis` [P] says δ² = 0 there. The closed photon strip is
the picture of θ; the Tamari ribbon is the picture of F. Both are strips;
they live on different graphs.

## 5. Consequences and to-dos

* **Ch 5 §5.2** ("polarization = range reduction vector → sign") gains a
  sharpened neighbor: *polarization is the associator being a sign; the
  electron's half-spin is the twist being a sign; both are ℤ/2, different
  slots.* Candidate prose after F2 — level **analogy (apt)**, path to literal
  = balancing-axiom reading of ledger item 8.
* **Ledger item 8** (`contracts_one` = F-move) stays open; §2's table is the
  precise separation it must respect — an anyon model realizing our rotation
  as an F-move must *not* also claim the strip's θ; the fusion model needs
  both slots explicitly (that is what "concrete fusion model" should mean).
* **F2** (058 §5) is the next build slot; its bridge theorem
  ("rotation ratio = local signCocycle", rot_ratio) makes φ literally the
  transport along one F-move on the skeleton — the first concrete instance
  of item 8 — and the pentagon re-proof corollary cross-checks
  `pentagon_cocycle_basis` from the value level. [C→P gated on F2.]
* The strip model's own claims (charge from confinement topology, g-factor
  from energy ratio) are untouched by this note; nothing here endorses or
  refutes them.

## 6. Status of claims

* §0 terminology: **stipulative/canonical** for the project (sense warnings included).
* §2 separation table: **argument** (this note) — stands on definitions.
* §3.2 modal parallel: **[H]**.
* §3.4 literature anchors: **[std/C]** — Kapustin–Li, Gu–Wen exact
  attributions pinned pending one citation pass; the "no toroidal-electron
  connection in the anyon literature" finding is a negative search result.
* §5 F2 items: gated on F2 landing.

---

## References

* J. G. Williamson, M. B. van der Mark, *Is the electron a photon with
  toroidal topology?*, Ann. Fond. L. de Broglie 22(2), 1997 — `docs/MARK.TEX2.pdf`
* G. W. Moore, N. Seiberg, *Polynomial associativity and the finite
  representation of mapping class groups*, Comm. Math. Phys. 123, 1989
* A. Yu. Kitaev, *Fault-tolerant quantum computation by anyons*,
  Ann. Phys. 303, 2003 — quant-ph/0010017
* S. Mac Lane, *Natural associativity and commutativity*, 1963
* P. Etingof, S. Gelaki, D. Nikshych, V. Ostrik, *Tensor Categories*, 2015
* A. Kapustin, Y. Li, *Bosonize of fermionic systems*, arXiv:1201.2648 [C]
* Z.-C. Gu, X.-G. Wen, *Iterated group extensions and fermionic
  short-range-entangled phases*, arXiv:1701.08264, JHEP 2017 [C]
* A. Drápal, work on Cayley–Dickson loops [C — exact paper to pin]
* Project: notes 006/007 (7-Skeleton), 019 (1-skeleton = Tamari),
  053 (anyon reading), 057 (quantization), 058 (F2 plan);
  `foundations/Algebra.lean` (`signCocycle`, `pentagon_cocycle_basis`)
