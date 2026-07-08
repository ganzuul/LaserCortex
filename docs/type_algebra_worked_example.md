# Type Algebra for the Octolinear Transit Map — Worked Example

**2026-07-07**
**Based on**: Develin–Sturmfels "Tropical Convexity" (2004), §2–3
**Prerequisites**: `staging/OctilinearEmbedding.lean` (KKT multiplier, transitCoord),
  `docs/lab_notes/024_octolinear_transit_GKZ_KKT_ZD_ontology.md` §9
**Purpose**: Build intuition for the puzzle-piece grammar by tracing a concrete
  case through the full Develin–Sturmfels type system.

---

## 1. Setup

We take the smallest station set that contains a true 45° edge: **size-1 and
size-2 trees at cd=0** (associative regime, assocDefect=0).

Three trees → three generators `V = {v₁, v₂, v₃}` in TP² (since `n=3`).

### 1.1 The Stations

| Gen | Name | Tree | transitCoord `(x,y)` | Embedded `(z,x,y)` |
|-----|------|------|---------------------|-------------------|
| v₁ | P    | N(L,L)         | (1,  0) | (0, 1,  0) |
| v₂ | NP   | N(L,N(L,L))    | (2, −1) | (0, 2, −1) |
| v₃ | PN   | N(N(L,L),L)    | (2, +1) | (0, 2, +1) |

### 1.2 The 45° Edges

Both radiate from v₁ (the only size-1 tree — both leaves are at odd depth 1):

| Edge | Direction | Δ | Leaf path | Formula |
|------|-----------|---|-----------|---------|
| v₁ → v₂ | **SE** | (+1, −1) | `"R"` (depth=1, left_turns=0) | Δy = 2·0 − 1 = −1 |
| v₁ → v₃ | **NE** | (+1, +1) | `"L"` (depth=1, left_turns=1) | Δy = 2·1 − 1 = +1 |

The edge v₂ → v₃ is pure vertical: Δ = (0, +2); not a single 45° step (requires
two N-edge steps in the octolinear system).

---

## 2. The Type System (Develin–Sturmfels)

### 2.1 Definition

For a point `x ∈ TP²` with coordinates `(x₁, x₂, x₃)`, its **type** relative to
V = {v₁, …, vᵣ} is:

```
type(x) = (S₁, S₂, S₃)   where each Sⱼ ⊆ {1, …, r}
i ∈ Sⱼ  ⇔  v_{ij} − xⱼ = minₖ(v_{ik} − xₖ)
```

i.e. generator vᵢ achieves the minimum for coordinate j at point x.

The **cell** X_S = closure{ x : S ⊆ type(x) } is a convex polyhedron.
The cells {X_S} partition TP² into a polyhedral complex.

### 2.2 Normalization

In our embedding `v_i = (0, x_i, y_i)`, the first coordinate is always 0.
Since `v_{i1} − x₁ = 0` for all i and any normalized x, we have `S₁ = {1,2,3}`
always. Therefore **the effective type reduces to (S₂, S₃)** — which generators
determine the transit-map x and y coordinates.

---

## 3. Trace the Types

### 3.1 At the Source Vertex v₁ = (0, 1, 0)

For each generator, compute `(0, xᵢ−1, yᵢ−0)` and find which j achieves the min:

| Gen | Values (j=1, j=2, j=3) | Min | Achieved at | Membership |
|-----|----------------------|-----|-------------|------------|
| v₁ | (0, 1−1=0, 0−0=0) | 0 | j=1, j=2, j=3 | 1 ∈ S₁,S₂,S₃ |
| v₂ | (0, 2−1=1, −1−0=−1) | −1 | j=3 | 2 ∈ S₃ |
| v₃ | (0, 2−1=1, 1−0=1) | 0 | j=1 | 3 ∈ S₁ |

```
type(v₁) = (S₁, S₂, S₃) = ({1,3}, {1}, {1,2})
effective: S₂ = {1},  S₃ = {1,2}
```

**S₃ = {1,2}** — two generators tied for the y-coordinate minimum. This is the
**degenerate type** (wall) that enables the SE 45° edge. At the source of the
45° edge, v₁ and v₂ both determine the y-coordinate.

### 3.2 At an Interior Cell Point C = (0, 1.5, 0)

Structurally halfway between v₁ and v₂/v₃ in x:

| Gen | Values | Min | Achieved at | Membership |
|-----|--------|-----|-------------|------------|
| v₁ | (0, −0.5, 0) | −0.5 | j=2 | 1 ∈ S₂ |
| v₂ | (0, 0.5, −1) | −1 | j=3 | 2 ∈ S₃ |
| v₃ | (0, 0.5, 1) | 0 | j=1 | 3 ∈ S₁ |

```
type(C) = (S₁, S₂, S₃) = ({3}, {1}, {2})
effective: S₂ = {1},  S₃ = {2}
```

**No degeneracy** — each coordinate has exactly one generator. This is a
**full-dimensional bounded cell** of the tropical complex. It has dimension 2
(an area in the tropical plane). Its type is minimal (no proper subset is
a valid type), so it is a maximal cell.

### 3.3 At the NE Wall Cell W = (0, 2, 0)

Directly between v₂ and v₃ in y, at the same x value:

| Gen | Values | Min | Achieved at | Membership |
|-----|--------|-----|-------------|------------|
| v₁ | (0, −1, 0) | −1 | j=2 | 1 ∈ S₂ |
| v₂ | (0, 0, −1) | −1 | j=3 | 2 ∈ S₃ |
| v₃ | (0, 0, 1) | 0 | j=1, j=2 | 3 ∈ S₁, 3 ∈ S₂ |

```
type(W) = (S₁, S₂, S₃) = ({3}, {1,3}, {2})
effective: S₂ = {1,3},  S₃ = {2}
```

**S₂ = {1,3}** — v₁ and v₃ tie for the x-coordinate. This is the wall
corresponding to the **NE 45° edge**. Note that it is a different tie
than at v₁'s vertex: there S₃ was the degenerate coordinate, here S₂
is degenerate. The two 45° edges (NE and SE) involve different coordinates'
minima.

---

## 4. The Cell Complex

### 4.1 Face Poset

The three cells we found form a containment chain:

```
            X_{({3},{1},{2})}          ← maximal cell (dim 2, type C)
                   ⊂
            X_{({3},{1,3},{2})}        ← wall cell   (dim 1, type W)
                   ⊂
            X_{({1,3},{1},{1,2})}      ← vertex cell (dim 0, type v₁)
```

Each containment `S ⊆ T` means X_T is a face of X_S
(note the reverse direction: `X_T` is a face of `X_S` when `S ⊆ T`).

### 4.2 Complete Face Poset for Our 3-Generator Case

The full poset of bounded cells (all S_j nonempty) would require enumerating
all valid types. For r=3, n=3, the table at tropcomb.tex line 1346 says there
are **5 symmetry classes** of tropical complexes (the (2,2) entry). Our
concrete configuration realizes one of these 5.

The valid types form a graded poset:

| Level | Cell dimension | Type pattern (S₂, S₃) | Count |
|-------|---------------|----------------------|-------|
| 2 | Interior cell (area) | Both singletons, distinct | ? |
| 1 | Edge (wall) | One coordinate has size-2 tie | ? |
| 0 | Vertex (station) | Both coordinates have size≥2 ties | 3 |

### 4.3 The Type Lattice Grammar

The algebra of laying puzzle pieces is:

```
Puzzle piece  = bounded cell X_S with type (S₂, S₃)
Adjacency     = face relation: X_S and X_T share a facet
                iff S ⊆ T or T ⊆ S (one coordinate gains/loses a generator)
Line segment  = transition between adjacent types differing
                by exactly one generator in one coordinate
Line          = chain S¹ ⊂ S² ⊂ ... ⊂ Sᵏ where each step is one
                of the 4 KKT change types (see §5)
```

---

## 5. KKT Steps as Type Transitions

Each KKT unit-step type corresponds to a specific pattern of type change:

### 5.1 contracts_one (Δx = −1)

A tree contracts: one generator drops out of the minimum set for some
coordinate. The type refines:

```
S₂: {i, j} → {i}     (generator j no longer achieves the x-minimum)
S₃: unchanged
```

Example: moving from the wall W back toward the interior C, generator v₃
drops from S₂. This is a W-edge (Δx = −1, Δy = 0).

### 5.2 leaf_expand — NE (Δx = +1, Δy = +1)

A leaf expansion adds a generator to the minimum set:

```
S₂: {i} → {i, k}     (new generator k ties for x-minimum)
S₃: {j} → {j}        (y-coordinate assignment carries through unchanged)
```

This is the **NE 45° edge** v₁ → v₃. The "accompaniment" is the stable
S₃ = {j} that remains unchanged across the wall crossing.

### 5.3 leaf_expand — SE (Δx = +1, Δy = −1)

```
S₂: {i} → {i}        (x-coordinate assignment carries through unchanged)
S₃: {j} → {j, k}     (new generator k ties for y-minimum)
```

This is the **SE 45° edge** v₁ → v₂. The accompaniment is the stable S₂.

### 5.4 axis_expand (Δx = +1, Δy = 0)

```
S₂: {i} → {i, k}     (new generator enters x-minimum set)
S₃: unchanged
```

A pure size increase, no y-change. The type change is the S₂ tie, but
without the y-coordinate carrying through (because the source and target
have the same y — S₃ is still a singleton but different generator).

### 5.5 cd_projection (Δx = 0, Δy = ±1)

The generator identity shifts because the cdStep changes (same tree,
different coordinate due to assocDefect). The type tuple's S₂ shifts:

```
S₂ changes by replacing one generator with another
  (same tree at different cdStep has different x-coordinate)
S₃ unchanged
```

---

## 6. What Accompanies a 45° Turn

The "other things" that inform the local geometry around a 45° edge,
visible in the type algebra:

| Aspect | NE edge (v₁ → v₃) | SE edge (v₁ → v₂) |
|--------|-------------------|-------------------|
| **Tied coordinate** | S₂ = {1,3} (x-coordinate) | S₃ = {1,2} (y-coordinate) |
| **Stable coordinate** | S₃ = {2} throughout | S₂ = {1} throughout |
| **Wall type** | Codim-1 face at x-tie | Codim-1 face at y-tie |
| **Before wall** (interior) | Type C: S₂={1}, S₃={2} | Type C: S₂={1}, S₃={2} |
| **At wall** | Type W: S₂={1,3}, S₃={2} | Type v₁: S₂={1}, S₃={1,2} |
| **After wall** (far side) | Type at v₃'s cell (not computed) | Type at v₂'s cell (not computed) |
| **Tree condition** | Left leaf expansion at depth 1 | Right leaf expansion at depth 1 |

**Key insight**: The stable coordinate's generator assignment (S₂={1} for SE,
S₃={2} for NE) is the "accompaniment" — it remains fixed and constrains what
type changes can occur at the wall-crossing. A pure axis step would change
both coordinates simultaneously, while the 45° edge is precisely the case
where **one coordinate's assignment stays fixed and the other acquires a tie**.

---

## 7. Relation to the 35-Quads Classification

For r=4 generators in TP², Develin–Sturmfels classify **35 symmetry classes**
of tropical complexes (the figure at
`docs/Tropical/arXiv-math0308254v3/35quads-shrunk.eps`). For r=3 generators
(the case worked here), there are **5 symmetry classes** (the (2,2) entry of
the table at tropcomb.tex line 1346).

Our 3-generator configuration with two 45° edges radiating from a central
station realizes one specific symmetry class among these 5. Adding more
stations (size-3 trees, giving r=5) will push us into the richer 35-quads
classification regime.

---

## 8. Summary

The Develin–Sturmfels type system gives a precise algebraic language for the
transit map's puzzle pieces:

| Informal | Formal (Type Algebra) |
|----------|----------------------|
| Station | Generator vᵢ = (0, transitCoord(tree, cd)) |
| Puzzle piece | Bounded cell X_S where S = type(x) = (S₂, S₃) |
| Two pieces share an edge | S ⊆ T or T ⊆ S (face relation) |
| 45° edge | |Sⱼ| > 1 for some j, other coordinate stable |
| Accompanying structure | The non-degenerate coordinate's singleton generator |
| Line | Chain of type containments, one KKT step each |
| ZD regime | Changes which generators exist (assocDefect=0 vs 4) |

To compute the full transit map for larger tree sets: enumerate all valid
types for the station configuration, compute the face poset, and read off
which stations are adjacent (share a wall cell). Each wall with |Sⱼ| > 1
identifies a 45° edge.
