# 032: Tropical Type Theory — Types as Coordinates in the Octolinear Transit Algebra

**Date**: 2026-07-07
**Status**: HYPOTHESIS — the type lattice from Develin–Sturmfels tropical convexity is the coordinate system of the octolinear transit map, and the 8 compass bearings are the elementary type-transition patterns
**Prerequisites**: 021 (Develin–Sturmfels forward proven); 031 (IC as regular subdivision); 024 (Octolinear transit ontology); `staging/OctilinearEmbedding.lean` (KKT multiplier, transitCoord); `docs/type_algebra_worked_example.md` (concrete walkthrough with 3 stations)
**Sources**: Develin & Sturmfels "Tropical Convexity" (2004), arXiv:math/0308254v3, §2–3, Figure 35quads; Sonnet 5 on discrete-continuous (GKZ height functions); `docs/type_algebra_worked_example.md` (worked 3-station trace)

---

## 1. The Hypothesis

The transit map coordinates `(x, y) = (size+assocDefect, lw−rw)` from the KKT covector projection are a **shadow** of a deeper coordinate system: the **Develin–Sturmfels type** `(S₂, S₃)` — the set of stations whose covector constraints determine each coordinate minimum at a given point in KKT space.

**The types ARE the coordinates.** The (x, y) values are numeric measurements of which types are active; the actual structure is the **type lattice** (the poset of types under containment), whose Hasse diagram is the transit map's cell complex, and whose drawing with KKT covector as layout coordinates produces the octilinear geometry.

Concretely:

| Layer | What it is | What it gives |
|-------|-----------|---------------|
| **Type lattice** | Develin–Sturmfels types (S₂, S₃) under containment | Adjacency — which stations share a wall, which cells are faces of which |
| **KKT covector** | transitCoord = (size+assocDefect, lw−rw) per station | Direction — numeric Δ between adjacent types, mapped to 8 compass bearings |
| **Octolinear map** | Hasse diagram of type lattice drawn with covector layout | The transit visualization |

The ZD wall at cdStep 3 acts as a **change of generating set** — when assocDefect jumps from 0 to 4, the station coordinates shift, and the type lattice undergoes a corresponding reorganization (a different set of types become valid bounded cells).

---

## 2. The Two-Layer Algebra

### 2.1 Layer 1: Type Lattice (Adjacency)

Let `V = {v₁, …, vᵣ}` be the station set (trees at a fixed cdStep embedded in TP²). Each point `x` in the tropical polytope `P = tconv(V)` has type:

```
type(x) = (S₁, S₂, S₃)   where Sⱼ ⊆ {1, …, r}
  i ∈ Sⱼ  ⇔  v_{ij} − xⱼ = minₖ(v_{ik} − xₖ)
```

Normalize so S₁ = {1,…,r} always (the projective coordinate). The effective type is `(S₂, S₃)`.

**Cell X_S** = closure{ x : S ⊆ type(x) }. Face relation: `X_T` is a face of `X_S` iff `S ⊆ T` (containment reverses dimension).

The type lattice is the poset of all valid types under `(S₂, S₃) ⊆ (T₂, T₃)`.

**Claim**: The Hasse diagram of the bounded cells (all Sⱼ ≠ ∅) of this lattice, when each cell is placed at the centroid of its station set's covector coordinates, gives the **skeleton of the octolinear transit map**.

### 2.2 Layer 2: KKT Covector Embedding (Direction)

Each station `vᵢ` has transitCoord `(xᵢ, yᵢ) = (sizeᵢ+assocDefect(cd), lwᵢ−rwᵢ)`. The vector difference between two stations that share a face in the type lattice gives a Δ-vector:

```
Δ = (Δx, Δy) = (xⱼ − xᵢ, yⱼ − yᵢ)
```

The 8 compass bearings partition the possible Δ-vectors by their slope:

| Δ pattern | |Δx|:|Δy| | Bearing | KKT components that change |
|-----------|----------|---------|---------------------------|
| (0, ±1)  | 0:1 | N/S | cdStep projection (same tree, different assocDefect) |
| (±1, 0)  | 1:0 | E/W | contracts_one (Δx=−1) or axis_expand (Δx=+1) |
| (±1, ±1) | 1:1 | NE/NW/SE/SW | Leaf expansion (Δx=+1) or asymmetric contraction |

### 2.3 Composition (The Grammar)

A **line** is a chain in the type lattice: `S¹ ⊂ S² ⊂ … ⊂ Sᵏ` where each step adds or removes exactly one generator from S₂ or S₃, and the KKT covector difference between the affected stations matches one of the 8 bearing patterns.

```
Puzzle piece  = cell X_S with type (S₂, S₃)
Adjacency     = X_T is a facet of X_S  ⇔  S ⊆ T
Segment       = edge from X_S to X_T where S and T differ by one generator
                in one coordinate, and ΔKKT matches a bearing
Line          = path through the type lattice, one segment at a time
45° edge      = |Sⱼ| > 1 for some j  (degenerate type = wall)
                with stable singleton in the other coordinate
```

---

## 3. The 45° Edge as Degenerate Type

A 45° edge (true within-CD diagonal) occurs at a **type degeneracy**:

| Edge type | Degenerate coordinate | Stable coordinate | Condition |
|-----------|---------------------|-------------------|-----------|
| NE (Δx=+1, Δy=+1) | S₂ tie (= {a, b}) | S₃ singleton (= {c}) | Source has balanced odd-depth left leaf |
| SE (Δx=+1, Δy=−1) | S₃ tie (= {a, b}) | S₂ singleton (= {c}) | Source has balanced odd-depth right leaf |

The "accompaniment" is the **stable singleton**: it encodes which coordinate's generator assignment carries unchanged across the wall crossing. This is visible in the concrete type trace at `docs/type_algebra_worked_example.md` §6.

The ZD regime (assocDefect = 0 vs 4) determines whether a given Δ pattern is possible:
- assocDefect = 0: only within-CD 45° edges (Δx=+1, Δy=±1 with ΔassocDefect=0)
- assocDefect = 4: cross-CD edges become possible (Δx = Δsize + 4, requiring larger trees)

---

## 4. Connection to Existing Formal Work

Three strands converge:

### 4.1 Develin–Sturmfels Quantized Correspondence (021)

The friction density `Γ(k) = k + 4·assocDefect(k)` induces a **regular subdivision** of Δ_{k−1}×Δ_{m−1}. This subdivision is the type lattice's combinatorial skeleton: the regular triangulation of a product of simplices IS the poset of valid types.

**What this gives**: The type lattice is not arbitrary — it IS the regular subdivision induced by the friction density height function, which we have already PROVEN in Lean (`develin_sturmfels_quantized_correspondence`).

### 4.2 Institutional Closure as Regular Subdivision (031)

The Tamari lattice `contracts_to_rightComb` is the **face poset of the associahedron**, which is itself a regular subdivision of a convex polygon. The flip graph of triangulations = the covering relations of the Tamari lattice = contracts_one steps.

**What this gives**: The type lattice for tree-station sets refines the Tamari lattice. Each type (S₂, S₃) corresponds to a face of the associahedron, and adjacencies correspond to diagonal flips. The friction density weights each flip (each KKT step) with its CD-dependent cost.

### 4.3 Octilinear Embedding (024)

The transitCoord `(size+assocDefect, lw−rw)` gives the KKT covector embedding that determines directions. This is the numeric projection of the type lattice into ℤ².

**What this gives**: The Hasse diagram of the type lattice, when drawn using transitCoord as layout coordinates, automatically satisfies octilinear constraints (edges follow the 8 compass bearings) because the KKT change patterns produce only Δ-vectors in these 8 directions.

### 4.4 The Missing Link

The three strands converge on a single structure: **the type lattice, induced by the friction density height function, with KKT covector layout, whose bounded cells are the reinforcement-type puzzle pieces.**

What remains to be proven:
- The type lattice's Hasse diagram edges are exactly the KKT unit-step transitions
- Each bounded cell's type uniquely determines which reinforcement types can occupy it
- The ZD wall corresponds to a change in the generating set V (new station coordinates), which reorganizes the type lattice via the irregular subdivision at cdStep 3

---

## 5. Relation to the 35-Quads Classification

For `r` generators in TP², the Develin–Sturmfels table (tropcomb.tex line 1346) gives the number of symmetry classes:

| r | TP² symmetry classes | Regular triangulations of Δ_{r−1}×Δ₂ |
|---|---------------------|-----------------------------------|
| 3 | 5 | (2,2) entry: 5 |
| 4 | 35 | (3,2) entry: 35 — the 35 quads figure |
| 5 | 530 | (4,2) entry |
| 6 | 13,631 | (5,2) entry |

Our size-1..3 station set gives r = 1 + 2 + 5 = 8 trees per cdStep (Catalan(1)+Catalan(2)+Catalan(3)), but only those with the correct y-range are bounded. The number of generating stations determines which symmetry class applies.

**Conjecture**: The transit map for size-1..3 trees at cd ≤ 2 realizes one of the 530 symmetry classes for r=5 (or whichever r matches the number of bounded generators). The cross-CD edges create a second layer where the generating set changes (because assocDefect shifts coordinates) and the type lattice reorganizes.

---

## 6. Next Steps

1. **Enumerate the type lattice for sizes 1..3 (5–8 generators)**: Write a Python script that computes all valid types (S₂, S₃) for the actual station coordinates, constructs the cell complex, and outputs the adjacency graph. Compare to the known 35-quads / 530-classes classification.

2. **Verify the grammar**: For every edge in the type lattice, check that the Δ-vector matches one of the 8 bearings and that the KKT components change as predicted by the type transition.

3. **Formalize the two-layer algebra**: Express the type lattice as a Lean structure where the type containment `S ⊆ T` is a relation, and prove that `transitCoord` gives a faithful embedding of the face poset into ℤ² with octilinear directions.

4. **Reinforcement type placement**: Map the 50 OWL subsequence candidates from `data/reinforcement_candidates.json` to specific type lattice cells — each reinforcement type occupies a cell (or chain of cells) in the lattice.

---

## References

- `lab_notes/021_develin_sturmfels_forward_proven.md` — QuantizedType regular subdivision PROVEN
- `lab_notes/031_ic_is_regular_subdivision.md` — Institutional Closure = regular subdivision of associahedron
- `lab_notes/024_octolinear_transit_GKZ_KKT_ZD_ontology.md` — Octolinear transit ontology (§9: type algebra)
- `docs/type_algebra_worked_example.md` — Concrete trace of type algebra for 3-station case
- `docs/Tropical/arXiv-math0308254v3/tropcomb.tex` — Develin–Sturmfels "Tropical Convexity" (2004)
- `docs/Tropical/arXiv-math0308254v3/35quads-shrunk.eps` — Figure of 35 symmetry classes
- `staging/OctilinearEmbedding.lean` — KKT multiplier, covector projection, transitCoord
- `staging/Friction.lean` — assocDefect, frictionDensity
- `data/reinforcement_candidates.json` — 50 OWL subsequence candidates (unmapped to types)
