# Department Colloquium Abstract

**Title.** A graded cost function on the Tamari lattice of Cayley–Dickson
composition.

**Abstract.**

Binary trees are the syntax of non-associative composition: a bracketed
product $((ab)c)$ is one tree, $(a(bc))$ another, and the associahedron /
Tamari lattice is the space connecting them by single re-associations. We ask a
quantitative question that the lattice structure alone does not answer: *how
much does it cost to re-associate?* We define a cost `dcStep` — the minimal
number of rotations to the unique right-comb normal form, equivalently the rank
in the Tamari lattice — and a per-rotation weight functional $\Gamma$ on the
Cayley–Dickson tower. The resulting cost obeys an exact composition law:
grafting two trees costs the sum of their costs **plus a coupling term** equal
to the right-spine depth of the left operand, so that mixing two weight regimes
always evaluates at the hotter one. The weight sequence has a single, sharp
discontinuity — from $\Gamma_2 = 2$ to $\Gamma_3 = 19$ — located exactly at the
split-octonion level where the associator first becomes nontrivial.

We conjecture and computationally verify (exhaustively, to size six) that this
cost coincides with geodesic distance to the normal form in the $\Gamma$-weighted
flip graph; the known critical point then reappears independently as a
population-wide inversion of the timelike/spacelike character of routes. All
theorems are machine-checked in Lean 4 with no axioms beyond classical choice;
the physical temperature scale is a normalization convention, not a hypothesis.

Why it matters: the cost of re-association is not idle combinatorics. In
topological quantum computation, fusion of non-abelian anyons is non-associative
up to an F-matrix constrained by the pentagon equation — the associahedron
itself — and our cost is the F-move depth of a fusion tree. In circuit
compilation, re-associating a product of gates to match available couplings is
the core of synthesis overhead. The Cayley–Dickson tower reaches the octonions
at exactly the level where our cost jumps (Γ₂=2 → Γ₃=19, a 4159 K barrier in
Landauer units): quaternion gates compose for free, octonionic/exceptional gate
algebras pay a 16-unit penalty per re-association. We offer these mappings as
falsifiable correspondences with a formalization path, not as claimed results —
the combinatorics is the content; the quantum reading is the motivation.

---

### Audience-tuning notes

- **Math colloquium:** drop the final "temperature" sentence if it feels like
  scope creep; the combinatorial core is self-contained.
- **Physics seminar:** add the Landauer anchor explicitly ($T = \Gamma T_{\rm op}
  \ln 2$, unit 207.9 K) and the 4159 K paraconsistency barrier; lead with the
  lightcone inversion.
- **CS/PL seminar:** add the Lean↔Python↔TypeScript single-source pipeline and
  the complexity-measure reading ("cost = static analysis weight on syntax
  trees"); emphasize the axiom audit.
- **Quantum information / QC-engineering:** lead with the F-move-depth and
  compilation-overhead readings (quantum_relevance.md §1); show the lightcone
  census figure; keep the anyon mapping explicitly labeled as a hypothesis.
