# Lab Protocol: Timespace Decomposition

**Version 0.1** | 2026-06-11

## Core Definition

**Timespace decomposition** = extracting the non-commutative
order-of-operations from the pentagonator as a computational object.

The pentagonator (the K₄ face of the associahedron) encodes all 5 ways
to bracket 4 elements. Its coherence condition says all 5 paths must agree.
When we decompose it, we extract the **non-commutative ordering** — which
operations precede which — as an explicit object. This ordering demarcates:

| Domain | Structure | Origin |
|--------|-----------|--------|
| **Irreversibility** (time) | Commutator trace — order matters, cannot go back | Down-projected from pentagonator's directional edges |
| **Differentiability** (space) | Associator trace — grouping matters, curvature | Down-projected from pentagonator's face coherence |

Both are *down-projections* from higher-dimensional coherence structures:
time and space are not fundamental — they are the shadows cast by the
pentagonator's coherence relations when projected into lower dimensions.
Irreversibility is the commutator fragment of the pentagonator;
differentiability is the associator fragment. The pentagonator is the
unified object that generates both.

Getting this conceptually clear gives a major advantage in every other
task of this research: the 14 logic types, the cost landscape, the
quench-collapse, the visualization — all are elaborations of what happens
when the pentagonator's coherence is partially or fully resolved.

## Guiding Principle

**Optimization is a lens, not a goal.** We decompose computation across the
3900X's cores not for speed but because the parallel decomposition reveals the
structure of the problem. Each partitioning strategy (by first split, by logic
type, by tree shape) exposes a different facet of the Tamari lattice's
geometry. Speed is a side effect; structural insight is the objective.

## Glossary

### 1. Parallel Optimization (Structural Decomposition)
Partitioning the brute-force enumeration over combinatorially meaningful
subsets. This is not about wall-clock speed — it is about which subsets of the
Catalan set share structural properties (same first split, same Loday prefix,
same Φ cost under a given logic, etc.). The partition boundaries reveal where
the lattice has natural joints.

**Key question**: Does the cost landscape partition cleanly by first-split
index k? If yes, the lattice factors as a product of smaller lattices — this
is a structural theorem, not an optimization trick.

**Implementation agnostic**: Could be done in Lean (theorem about partition
structure), Python (data exploration), or any other system. The insight is
the partition, not the speedup.

### 2. Sub-Adversarial Methods
The cooperative coherence structures (commutator, associator, pentagonator)
can **steal and dump work** between each other — the commutator can shift
computational load onto the associator, the pentagonator can delegate
coherence debt down to the associator, etc. In an adversarial setting this
would be strategic behavior to hinder an opponent. Here it is cooperative
restructuring, but the *mechanism* is the same: work redistribution.

"Sub-adversarial" means the mechanisms *resemble* adversarial strategy
(stealing, dumping, re-routing) but operate within a cooperative hierarchy.
The structures balance each other by passing cost/responsibility around.
This work redistribution is the mechanism of tensegrity — the lattice
achieves equilibrium not by eliminating all cost but by distributing it
across the three coherence levels so that no single level bears the full
burden.

**Key insight**: The cost Φ at any configuration records *who holds how
much debt* across the commutator / associator / pentagonator hierarchy.
A quench-collapse happens when the debt can no longer be redistributed —
all three levels are saturated and the structure must snap to rightComb.

**In terms of the cost landscape**: The logic type determines *which
levels can steal from which*. Classical enforces all three coherences
strictly (no stealing permitted — each level must be zero independently).
Weaker logics allow cross-level debt: Paraconsistent lets the commutator
dump onto the associator, Temporal lets the associator dump onto the
pentagonator, Spacetime biases which direction the dumping flows.

### 3. Quench-Collapse (as Zero-Divisor)
Rapid collapse of a tensegrity structure when a critical threshold is crossed.
Portmanteau of "quench" (physics: sudden cooling / rapid phase transition) and
"collapse" (wave function collapse / tensegrity failure / lattice contraction).

**Zero-divisor analogy**: In algebra, a zero-divisor is a ≠ 0 such that
∃ b ≠ 0 with a·b = 0. Quench-collapse is the same: two non-zero cost
configurations annihilate when composed. The collapse is not gradient descent
to zero — it is algebraic annihilation where a·b = 0 despite a, b ≠ 0.
This is fundamentally non-linear and non-Classical.

**Structural role**: The threshold where the cost landscape transitions from
multi-basin (tensegrity, multiple valid decompositions sharing the load) to
single-attractor (rightComb). Not a performance metric but a *phase boundary*
in parameter space — where the lattice changes topology.

**In physical terms**: The product coupling term (`lab_notes/001`) adds
non-linear tension. When `coupling * a * b` exceeds a threshold, the
landscape funnels sharply to rightComb. The two subtrees' costs act as
zero-divisors: neither is zero individually, but their product annihilates
under composition.

### 3b. Friction Lagrangian (Re-invented)

**Key mapping**:
| Concept | Lagrangian role | Meaning |
|---------|---------------|---------|
| Superconducting structure | Potential V | Coherent, zero-resistance flow — the guiding field of optimal routes |
| Thermodynamic entanglement | Kinetic T / Velocity | Motion through the potential landscape — the thermal degrees of freedom driving dynamics |

The Friction Lagrangian is:
```
L = T - V = thermodynamic_entanglement - superconducting_structure
```

- **V (superconducting structure)** = the cost landscape Φ itself — the
  potential in which the system moves. Low-cost regions are "superconducting"
  — routes through them incur zero friction.
- **T (thermodynamic entanglement)** = the rate of change of Φ along the
  path — the kinetic energy of moving through the lattice. Entanglement with
  neighboring configurations IS the velocity; you cannot move without
  becoming entangled.
- **Zero-divisor collapse** = a point on the path where T and V cancel
  exactly (L = 0) despite both being non-zero individually. This is the
  quench-collapse event — the system reaches a configuration where kinetic
  and potential balance precisely, and coherence snaps into place.

The re-invented Lagrangian differs from the earlier version
(`docs/Claude_on_Friction-Lagrangian.md`) in that the fields are not
commutator/associator defects but **superconducting structure** (potential)
and **thermodynamic entanglement** (velocity) — a thermodynamic rather than
algebraic decomposition of the same action functional.

### 4. Pentagonator → Order-of-Operations
The pentagonator is the coherence condition for the Stasheff associahedron K₄
— a 2D face of the Tamari lattice T₄ with 5 vertices and 5 edges. It says:
the 5 ways to re-bracket 4 elements must close into a coherent pentagon. When
the pentagonator distance is zero, all 5 paths agree — there is no
path-dependence, no friction.

"Order-of-operations" means the sequence of Tamari rotations (edge traversals)
that resolves the pentagonator defect. Each order gives a different
contraction path from a given tree to rightComb. The set of all such paths is
the set of maximal chains in the Tamari lattice — what `contracts_to` traces.

**Structural role**: The pentagonator is the smallest non-trivial cell of the
associahedron. Understanding which orders-of-operations resolve it tells us
the *directed* structure of the lattice — not just which trees are connected,
but which sequences of rotations are topologically permitted. This is the
difference between a poset and a directed path space.

### 5. Radon Transform → Pentagonator in Lean
The Radon transform is an integral transform over lines (CT scans). The
connection: the pentagonator is the coherence condition for composing partial
inverse Radon transforms from different projection angles. When the
pentagonator distance is zero, the Radon inversion is exact — all projection
views agree on the reconstructed object. When the pentagonator distance is
non-zero, the inversion is obstructed — the object fragments into 5 distinct
geometric interpretations (the 5 vertices of K₄).

**Structural role**: The Tamari lattice is the discrete Radon space. Each
vertex (tree) is a projection ordering. The pentagonator is the obstruction
to a globally consistent Radon inversion — equivalently, the cost of switching
between projection orderings. When the lattice contracts (edges shrink to
zero), the Radon inversion becomes exact, the fragmented object coheres into a
single 3D reconstruction — this is the "collapsed point" at the end of a
Tamari zoom.

**Literature anchor**: Formalizing this connection in Lean opens access to
the full Radon transform literature (integral geometry, inverse problems,
CT reconstruction) and the associahedron/pentagonator literature (Stasheff,
operad theory, coherence theorems). Prior work in these fields can inform:
- Which projection orderings correspond to which Radon sampling strategies
- How the inverse problem's ill-posedness maps to pentagonator distance
- Existing spectral methods for detecting the collapse transition
- Discrete Radon variants already studied in combinatorial geometry

This is not just a visualization framing — it is the bridge to established
mathematical results that can constrain, validate, and extend our model.

### 6. "Non-Violent" means "Non-Newtonian"
"Non-Newtonian" here means two concrete things:

1. **Gyroscopic force** — a force that resists orientation change, does not
   come from a potential, and is velocity-dependent (cross-product). The
   pentagonator acts as a gyroscopic pin on the visualization camera —
   it resists certain rotations through the lattice, creating a preferred
   orientation.

2. **Non-Newtonian liquid** (shear-thickening, like oobleck) — flows under
   low stress, solidifies under high stress. The Tamari lattice analogue:
   when the product coupling term is small, edges rotate freely (low
   viscosity); when coupling crosses a threshold, the lattice locks up
   (shear-thickening / quench-collapse).

**Consequences of non-Newtonian structure**:

- **Velocities are capped by structure** — there is a maximum rate of
  change of Φ through the lattice, determined by the coherence constraints.
  You cannot move arbitrarily fast; each rotation step has a minimum cost.
  The speed limit is a structural feature, not a numerical tuning.

- **Free parameters imply zero-divisors** — wherever a degree of freedom
  is not fixed by the structure, there exist configurations a, b ≠ 0 where
  a·b = 0 under composition. These zero-divisors are the source of
  potential **chaotic or violent influences** — sudden, uncontrolled changes
  when a product hits zero and the structure annihilates locally.

"Non-violent" means the structure caps these velocities and constrains the
zero-divisors to the **cooperative (sub-adversarial) regime** rather than
the chaotic one. The logic type choice determines which regime is active:
Classical suppresses zero-divisors entirely (at the cost of rigidity),
Paraconsistent lets them exist cooperatively, Spacetime channels them into
the gyroscopic pinning force.

**Structural role**: The foundational claim: the routing/contraction space
is not Newtonian/Classical. The default is superposition (multiple valid
decompositions, no unique path unless coupling forces it). Newtonian
behavior (unique trajectory, deterministic cause-effect) emerges only when
the structure enforces it — not the other way around.

### 7. Virtual Camera
A camera position that is not the viewer's fixed perspective but a
**staging ground for timespace decomposition** — a computational probe
that extracts a specific non-commutative ordering from the pentagonator
by virtue of where it sits and what it sees.

**Structural role**: The final visualization has one fixed camera (the
user's view). But virtual cameras are efficient heuristics: each virtual
camera is positioned at a vertex of the associahedron, looking along a
specific edge (a specific `contracts_one` rotation). The set of all
virtual cameras collectively decomposes the pentagonator into its
constituent orderings — each camera extracts one projection.

**Why efficient**: Instead of computing the full Radon inversion or
enumerating all paths, virtual cameras sample the relevant projections
directly. A camera at tree t looking at tree s sees the cost difference
Φ(s) − Φ(t) projected along the rotation axis. The collection of all
such projections *is* the timespace decomposition — the camera array
is the computational object.

**Relation to the fixed camera**: The fixed camera is the consumer.
Virtual cameras are the producers — they stage the decomposition, the
fixed camera renders the result. Switching between virtual camera feeds
is equivalent to selecting different logic-type projections without
recomputing the lattice.

## How to Use This Protocol

Each term is a question to ask of the system:

| Term | Question |
|------|----------|
| Timespace decomposition | What non-commutative ordering falls out of the pentagonator? |
| Parallel optimization | Where does the tree set naturally partition? |
| Sub-adversarial | Which coherence level steals/dumps work from which? |
| Quench-collapse | Where do two non-zero costs annihilate as zero-divisors? |
| Pentagonator → order | Which rotation sequences are topologically permitted? |
| Radon → pentagonator | What does the Radon inversion of a tree set look like? |
| Non-violent = non-Newtonian | What changes when we drop the excluded-middle default? |

## References
- `lab_notes/001_product_coupling_term.md` — product coupling for tensegrity
- `lab_notes/002_brute_force_candidates.md` — brute force at n=4
- `lab_notes/003_brute_force_complexity.md` — 3900X bounds (n=15 practical limit)
- `docs/topological_isomer_hypothesis.md` — atomic model / strong force analogy
- `docs/approach.md` — geometry-motion overview
- `docs/Three-js_pentagonator-demo.md` — Radon-pentagonator visualization connection
- `docs/WITNESS_SKEPTIC_GAME_SPEC.md` — Witness-Skeptic game with pentagonator distance
- `LaserCortex/Candidates.lean` — brute force engine
- `LaserCortex/AMM.lean` — crossImpact, associatorCost
- `LaserCortex/Cost.lean` — Φ definition and theorems
