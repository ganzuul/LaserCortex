# The Quantum-Computing Pivot — why this work matters

*Companion to the theorem statement sheet. This document makes the relevance
argument. Read it with the honesty ledger in §5 open in the other hand.*

---

## 0. The pivot sentence

> **Quantum computing gives our cost function a physical substrate.
> Re-association overhead is exactly what non-associative composition must
> pay — non-abelian anyon fusion, octonionic/exceptional gate sets, and
> non-Clifford operations — and the Γ jump at CD 3 marks the boundary where
> that overhead becomes unavoidable.**

Everything before this sentence was combinatorics. Everything after it is why
anyone outside combinatorics should care.

## 1. The three hooks, in order of strength

### Hook A — Non-abelian anyons / topological quantum computation *(deepest)*

Topological QC computes by braiding non-abelian anyons. Fusion of anyons is
**non-associative up to an F-matrix** — the associator of a braided fusion
category — constrained by the pentagon equation. The pentagon equation *is*
the associahedron: its 5-term coherence identity is the defining cell of the
Tamari lattice.

Our objects map cleanly:

| Our object | Anyon / fusion object |
|---|---|
| `EMLTree` | a fusion tree (a bracketing of a product of anyons) |
| `contracts_one` (the rotation) | an F-move (one associator application) |
| `dcStep t` | **F-move depth** — minimal associators to trivialize the tree |
| right comb | the canonical/trivial fusion order |
| `rightSpine` | the length of the "output" anyon chain |

The composition law `dcStep (Node l r) = dcStep l + dcStep r + rightSpine l`
then reads as: **the F-move depth of a composite fusion is the sum of the
depths plus the length of the left output chain** — a resource bound on
fusing a product of anyons in a given order. And the C2 conjecture
(verified to size 6) says this greedy depth is *optimal*: no clever braid
reduces the associator count. That is a **lower bound on fusion overhead**,
and it is exactly the kind of quantity a fault-tolerant threshold depends on.

*Status:* correspondence (proposed). The combinatorics are proven; the
identification of `contracts_one` with F-moves is a hypothesis to be stated
formally against a chosen fusion-category model (e.g. Fibonacci anyons).

### Hook B — Octonions and the exceptional / black-hole-qubit correspondence *(structural)*

The Cayley–Dickson tower is real → complex → quaternion → **octonion** at
CD 3. Quaternions (CD 2, associative) are the algebra of SU(2) — the
single-qubit rotation gates. Octonions (CD 3, non-associative) appear in
exceptional Lie groups (G₂, E₈) and in the black-hole/qubit correspondence,
where the entanglement structure of qubit systems is organized by octonionic
and exceptional geometry.

Our Γ sequence quantifies this transition *in the same units as circuit cost*:
the associator turning on at CD 3 is a **jump of 16 friction units** in the
per-operation cost. In temperature units (Landauer anchor, T_op = 300 K), the
barrier to freely composing non-associative gate algebras is **4159 K** — far
above room temperature. In plain language: *quaternion gates compose for free;
octonionic gate sets pay a 16-unit penalty per re-association, and that penalty
is thermodynamically unaffordable below ~4000 K.*

*Status:* structural claim. The Γ values and the jump are proven; the mapping
"CD level = gate algebra = qubit-geometry layer" is the established tower
structure restated in cost units, not a new claim about physics.

### Hook C — Compilation depth and non-Clifford overhead *(operational)*

Circuit compilation into a native gate set is a search over re-bracketings:
an expression tree for a product of gates must be reassociated to match the
available two-qubit couplings. `dcStep` is the minimal number of such
re-associations — a **combinatorial lower bound on compilation overhead** from
associativity constraints alone (before any topology/routing cost).

The two regimes collapse to closed forms — `cd·dcStep` (associative band) and
`(cd+16)·dcStep` (non-associative band). Read as a complexity statement:
compilation cost is linear in the associativity defect, with a **step increase
at the octonion boundary**. This parallels the Clifford/non-Clifford split in
magic-state theory: associative (Clifford-like) composition is cheap;
non-associative (magic/exceptional) composition carries an irreducible
per-gate overhead. Our Γ jump is a *toy model* of that split — not a proof
about magic states, but a structurally identical transition in a setting where
every step is machine-checked.

*Status:* analogy, flagged. The combinatorics are real; the Clifford/magic
identification is motivational.

## 2. What problem does it actually solve?

For a quantum-information audience, the honest deliverables are:

1. **A formalized lower bound** on associator / F-move depth for binary
   fusion, with a proof that greedy is optimal (C2, verified; graded-lattice
   proof in progress).
2. **A quantified boundary** — CD 3 / Γ = 19 / 4159 K — separating
   "composable" from "non-composable" algebra, in units that can be converted
   to thermodynamic cost.
3. **A machine-checked substrate** for the claim that the associahedron /
   pentagon coherence is *the* right setting for fusion overhead — every
   identity is a Lean certificate, so the mapping to any specific anyon model
   can be *formally* audited rather than asserted.

## 3. Why now

- **Fault-tolerant thresholds** are the bottleneck of practical QC; overhead
  models that are *proven* (not simulated) are rare. Ours is proven at the
  combinatorial layer.
- **Non-abelian anyons** are the leading hardware path for topological QC;
  their resource theory (F-move depth, braid length) lacks a formal,
  machine-checked ground model. Our Tamari-flip cost is a candidate.
- **Exceptional algebra** (octonions, E₈) keeps appearing in quantum
  information; a *cost* on that algebra — rather than just a geometry — is a
  new kind of handle.

## 4. The two-sentence versions (per audience)

- **Physics / quantum:** "The cost of reassociating a product is the F-move
  depth of a fusion tree; we prove a composition law for it and locate a sharp
  boundary — 4159 K — where non-associative composition becomes
  thermodynamically free."
- **CS / PL / QC-engineering:** "Compiling a non-associative gate product has
  an irreducible re-association overhead; we give a machine-checked lower bound
  and show it jumps discontinuously at the octonion algebra."
- **Math:** "The Tamari rank, equipped with a Cayley–Dickson weight functional,
  is a geodesic distance with a critical point; the quantum reading is the
  motivation, the combinatorics is the content."

## 5. Honesty ledger — read this before presenting

| Layer | What it is | Status |
|---|---|---|
| Composition law, Γ functional, the jump, superadditivity, closure | combinatorics | **proven** (Lean, axiom-clean) |
| C2 potentiality (cost = geodesic) | graded-lattice identity | **verified** (exhaustive, ≤ size 6); proof open |
| `contracts_one` = F-move; `dcStep` = F-move depth | correspondence | **proposed**, not yet formalized against a fusion model |
| Γ jump = Clifford/magic split; 4159 K = fault-tolerance threshold | analogy | **speculative**; motivational only |
| Any claim about actual quantum hardware | — | **not made**; do not make it |

**The discipline:** when the audience is quantum, lead with the *formalized
combinatorics* and offer the anyon mapping as a falsifiable hypothesis with a
clear formalization path. Never state the analogy as if it were the theorem.
