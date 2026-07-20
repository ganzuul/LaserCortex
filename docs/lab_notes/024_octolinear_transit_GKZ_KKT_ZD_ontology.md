# Lab Note 024: Octolinear Transit as GKZ Regular Subdivision — Ontology from KKT Height Functions and ZD Walls

**2026-07-07**
**Status**: ONTOLOGY — structural identification; puzzle pieces assembled, mapping to formal framework established
**Prerequisites**: 023 (CDHomotopyPath vs Sonnet 5 height function); `LaserCortex/staging/OctilinearEmbedding.lean`; `LaserCortex/staging/Friction.lean`; `docs/sonnet-5_on_discrete-continuous.md`
**Source files**: `staging/OctilinearEmbedding.lean` (KKT multiplier, covector projection), `scripts/generate_transit_json.py` (build_lines, build_river), `canvas_app/frontend/src/transit-entry.tsx` (river overlay, legend), `data/reinforcement_candidates.json` (560 candidates), `docs/tube_map_covector_design.md`

---

## 1. The Question

The transit map visualization has been generating flat, uninformative geometry — stations placed at sequential x positions, 45° edges rendered as artificial Bezier arcs, the entire layout bearing no relation to the actual KKT/covector data. Meanwhile, we have:

- **KKT multipliers** `(a=size, b=leftWeight, c=rightWeight, d=assocDefect)` computed per tree
- **Covector projections** `(a+d, b−c)` = `(size+assocDefect(cd), lw−rw)` in ℤ²
- **560 reinforcement type candidates** from the Markov poset M2b pipeline — puzzle pieces looking for a board
- **Sonnet 5's GKZ picture** where KKT coefficients serve as height functions determining the triangulation via lower convex hull

What is the actual geometry? If the transit map is a TSP-like route through KKT space, what are the stations, the lines, the compass bearings, and how do they ground in algebraic structure?

---

## 2. The Answer: GKZ Regular Subdivision, Realized via KKT Height Functions

### 2.1 The Height Function

Following Sonnet 5 (lines 77–87 of `docs/sonnet-5_on_discrete-continuous.md`) and confirmed in note 023, the KKT multiplier `(cd : ℕ) (t : EMLTree) : SplitQuat` serves as a **height function** in the GKZ sense:

```
height(t) = KKT(cd, t) = (size, leftWeight, rightWeight, assocDefect)
         ↦_covector (size + assocDefect(cd), leftWeight − rightWeight) = (Δx, Δy)
```

Each tree `t` at cdStep `cd` gets a lifted point `(t, height(t))` in ℤ³ (with the covector projection as a 2D shadow). The lower convex hull of all lifted points for a given `cd` projects down to a **regular triangulation** of the associahedron — i.e., a particular bracketing choice (which tree is optimal for that cdStep).

### 2.2 Walls Are Where Covectors Equalize

The ZD boundary at cdStep 3 is not a gradual transition — it is a **wall** in the GKZ sense:

| cdStep | assocDefect | Wall type | KKT behavior |
|--------|-------------|-----------|-------------|
| 0–2  | 0 | Associative chamber | `d=0` — no obstruction, KKT changes are continuous |
| **3** | **4** | **ZD wall** | `d` jumps from 0 to 4 — the wall where two covector values equalize |
| 3–4+ | 4 | Non-associative chamber | `d=4` — ZD active, cross-CD 45° edges become possible |

The assocDefect `d` is **binary** (0 or 4), not continuous. There is no "between" — the LiarParadox identity zero divisor boundary at cdStep 3 is an all-or-nothing wall crossing. This IS the GKZ wall where the discrete triangulation flips.

### 2.3 Partition into 4 Sectors by (±1,±1) KKT Unit Steps

The KKT change space is ℤ² via the covector projection. A **unit step** in KKTT space (one `contracts_one` rotation plus possible cdStep change) maps to a Δ-vector:

```
Δ = (Δ_size + Δ_assocDefect, Δ_leftWeight − Δ_rightWeight)
```

The 4 sign combinations of (Δx, Δy) partition all legal KKT changes into **4 sectors**:

| Sector | (Δx, Δy) | Compass bearings | KKT change pattern |
|--------|----------|-----------------|--------------------|
| **NE** | (+, +) | N, NE, E | size↑ or cd↑ combined with leftWeight↑ or rightWeight↓ |
| **SE** | (+, −) | S, SE, E | size↑ combined with rightWeight↑ or leftWeight↓ |
| **SW** | (−, −) | S, SW, W | contracts_one Δx=−1, assocDefect may jump |
| **NW** | (−, +) | N, NW, W | contracts_one combined with leftWeight↑ |

Each sector splits into **2 compass bearings** (8 total) based on which KKT components change:

- **Even-grade only** (only `a=size` and `d=assocDefect` change, `b=leftWeight` and `c=rightWeight` stable) → **axis-aligned 90° edges** (N, S, E, W)
- **Mixed even+odd** (both |even and odd components change) → **diagonal 45° edges** (NE, SE, SW, NW)

### 2.4 Leaf Expansion Produces True 45° Edges

Balanced odd-depth leaf expansion (not the old `t → N(t, Leaf)` extension) produces:

```
Δsize = +1, ΔleftWeight = +1 (NE) or ΔrightWeight = +1 (SE), ΔassocDefect = 0
→ Δx = +1, Δy = ±1 → true 45° within the same cdStep
```

Condition: the leaf must be at **balanced odd depth** so that `|Δy| = 1` and `Δsize = 1`. Of the size-1..4 tree set, **42 true 45° edges** exist (21 NE + 21 SE), all within the associative regime (cd ≤ 2, assocDefect = 0).

**Cross-CD 45° edges** (where cdStep changes, `ΔassocDefect = 4` giving `Δx = Δsize + 4 = ±1`) require trees of size ≥ 5 (since `Δsize` must be −3 or +5). Our current max_size=4 cannot yet generate these.

---

## 3. Puzzle Pieces: What Goes Where

### 3.1 Reinforcement Types (560 Candidates) as KKT Change Patterns

The 560 reinforcement type candidates from the Markov poset M2b pipeline are **sequences of KKT component-level changes**, each typed by cdStep. Each candidate = a specific OWL atom subsequence.

The mapping: each reinforcement type corresponds to a **path segment** through KKT space — a sequence of unit steps. Group by (Δx, Δy) signature:

| Pattern type | What changes | Compass bearing(s) |
|-------------|-------------|-------------------|
| Pure size step | `a` only | E (Δx=+1, Δy=0) or W (Δx=−1, Δy=0) |
| Pure lateral | `b,c` only | N (Δy=+1) or S (Δy=−1) |
| 45° expansion | `a,b` or `a,c` | NE or SE |
| 45° contraction | `a,b` with Δsize=−1 | NW or SW |
| ZD crossing | `d` jumps 0→4 | Cross-CD projection (Δx=+4, Δy=0 → E with different semantics) |

The 560 candidates become the **edge inventory** — the set of possible subway segments that can be assembled into lines. Each line is a sequence of these segments that respects compass-bearing continuity (bearing changes ≤ 45° per station, corners validated by `cornerPossible` in d3-tube-map).

### 3.2 ZD Regime Gates: Which Patterns Are Legal Where

The binary assocDefect (0 vs 4) acts as a **gate**:

| assocDefect | 45° within CD? | 45° cross-CD? | CD-projection edges? | Pure axis edges? |
|-------------|---------------|---------------|---------------------|-----------------|
| 0 (cd≤2) | ✅ Yes (42 edges) | ❌ No (needs size≥5) | ✅ Yes (CD-projection Δx=0) | ✅ Yes |
| 4 (cd≥3) | ❌ No (odd-depth expansion blocked) | ✅ Possible (size≥5 required) | ✅ Yes (projections from ZD trees) | ✅ Yes |

This gives the subdivision structure: the ZD wall at cdStep 3 partitions the tree set into two chambers, each with a different set of legal edges. The transit map must bridge these chambers via cross-CD projection edges (Δx=0, orthogonal to the true-diagonal 45° set).

### 3.3 Stations Must Be at TubeCoord (Not Sequential x)

**Critical design error identified**: `build_lines()` in `scripts/generate_transit_json.py` (line 119) uses:

```python
x = X_START + idx * X_STEP  # sequential x, ignores tubeCoord
```

This flattens all geometry. The **actual station position** must be:

```
tubeCoord(t, cd) = (size + assocDefect(cd), leftWeight − rightWeight)
                 = (Δx, Δy) in ℤ²
```

Only then will:
- True 45° edges render as actual diagonals (no Bezier-arc hacks)
- Cross-CD projection edges render as vertical segments (Δx=0)
- The map reflect actual KKT space structure

**Fix**: Replace the sequential positioning in `build_lines()` with the tubeCoord values computed by `kkTMultiplier` / `covectorProjection` in `OctilinearEmbedding.lean`.

---

## 4. The Transit Ontology (Heuristic Summary)

### 4.1 What a "Line" Is

A **line** = an *analysis* — a cost-minimization path through KKT space at a particular logic type (or ZD regime). Each line is a sequence of KKT change patterns (reinforcement types) that:

1. Starts at some station (tree, cdStep)
2. Follows legal unit steps respecting ZD regime gates
3. Changes direction only at stations where `cornerPossible` validates the turn
4. Terminates at rightComb (the minimal-cost tree)

Many different analyses (different logic types) produce different routes through the same station graph. The transit map overlays all these routes, showing which segments are shared and which diverge.

### 4.2 What a "Station" Is

A **station** = a specific `(tree, cdStep)` pair, positioned at `tubeCoord = (size+assocDefect, lw−rw)`. The same tree at different cdSteps is a different station (different position, different ZD regime).

### 4.3 What a "Segment" Is

A **segment** = a KKT unit step connecting two stations. Types:

| Segment type | Δ | Constraint | Bearing |
|-------------|---|-----------|---------|
| contracts_one | (−1, 0) ± (0, ±1) | Within Tamari lattice | W, NW, SW |
| leaf expansion | (+1, +1) or (+1, −1) | Odd balanced depth | NE, SE |
| cd projection | (0, ±1) | CD step change, same tree | N, S |
| cd+contract | (+3, ±1) etc. | Cross-ZD-wall | Requires size≥5 |

### 4.4 What the "River" Is

The **river** = set of all 45° edges (both within-CD and cross-CD projection) in a single visualization. Currently 86 segments:
- 42 true 45° (within-CD, cd≤2)
- 44 cross-CD projection edges (Δx=0, connecting same tree across cdSteps)

The river overlay (in `transit-entry.tsx`) displays these as Bezier arcs + dashed lines, but once tubeCoord positioning is fixed, they'll render as natural diagonals and verticals.

---

## 5. Relation to GKZ Regular Subdivision

The GKZ/secondary polytope framework is the deeper structure:

### 5.1 Associahedron as Secondary Polytope

The associahedron K_{n+1} is the secondary polytope of a convex (n+2)-gon (Gelfand–Kapranov–Zelevinsky). Its vertices = regular triangulations of the polygon. The Tamari lattice is the face poset of the associahedron.

### 5.2 Height Function = KKT Coefficients

In the GKZ construction, each vertex of the polygon gets a height. The **lower convex hull** of lifted points projects down to a regular triangulation. In our framework:

- The polygon vertices correspond to binary tree nodes (leaves and internal joins)
- The height of each vertex = KKT multiplier component
- The regular triangulation = the optimal bracketing (tree shape) for that height assignment

### 5.3 Wall-Crossing = ZD Threshold

When cdStep crosses 3, `assocDefect` jumps from 0 to 4. This is a **GKZ wall** — the lifted points become coplanar in a degenerate configuration, and the discrete triangulation flips. The flip corresponds to the associator becoming active (non-associative regime onset).

### 5.4 The Transit Map as Fiber of the Secondary Polytope

The transit map, with its TSP-like route through KKT space, is a **section through the secondary polytope** — a particular choice of which triangulations to visit and in what order, conditioned on the ZD regime constraints. Each line is a path in the GKZ chamber complex, and the map is a fiber of the projection from height-space to triangulation-space.

This identification opens the entire GKZ literature to constrain our framework:

- Which height assignments are "coherent" (produce a regular triangulation)?
- What happens at degenerate height assignments (the null cone)?
- How do secondary polytope faces correspond to incompletely resolved bracketings?
- Can the circumcircle test be applied to detect ZD wall-crossings in KKT space?

---

## 6. Key Design Errors Corrected (from Prior Sessions)

| Old assumption | Corrected understanding | Impact |
|---------------|------------------------|--------|
| 45° edges via `t → N(t, Leaf)` expansion | Leaf expansion at balanced odd-depth leaves | Actually produces 42 true 45° edges; the old formula was wrong |
| Sequential x positioning for stations | tubeCoord `(size+assocDefect, lw−rw)` | All geometry was hidden — station positions must use actual KKT data |
| assocDefect as continuous | Binary (0 or 4), wall at cdStep 3 | No gradient descent through ZD wall — discrete flip |
| Contract one path = line | `contracts_one` steps are deductions from reserves (Δx=−1 per decision) | Lines are TSP-like analyses, not individual contractions |
| CDHomotopyPath as interpolation | 1D slice of multi-dimensional height space | Replaced by GKZ picture (note 023) |
| 4 sectors = 4 bearings | 4 sectors × 2 (axis vs diagonal) = 8 bearings | Populated via reinforcement type grouping |

---

## 7. Next Steps

1. **Fix station positioning**: Replace sequential x in `build_lines()` with actual tubeCoord values. This is the single highest-impact change.

2. **Formalize the 8-bearings-at-4-sectors structure**: Enumerate all legal KKT unit-step change patterns (size range 1..4, all cdSteps 0..4) and map each to one of the 8 compass bearings, with ZD regime gates noted.

3. **Map reinforcement types to KKT change patterns**: Each of the 560 candidates from `reinforcement_candidates.json` is a sequence of KKT component-level changes. Group by (Δx, Δy) compass signature. This gives the edge inventory.

4. **Implement the circumcircle test** (from note 023): For each pair of trees that differ by a single `contracts_one` rotation, compute the two covector values on either side. Check if they equalize exactly at cdStep 3.

5. **Cross-CD 45° edges**: Extend the tree set to size ≥ 6 and regenerate to capture cross-CD diagonal segments.

6. **Validate the river geometry**: With real tubeCoord positions, the 42 within-CD 45° edges should render as true diagonals. Cross-CD projections render as vertical Δx=0 segments.

---

## 8. References

- `docs/lab_notes/023_CDHomotopyPath_vs_Sonnet5_height_function.md` — GKZ height function identification
- `docs/sonnet-5_on_discrete-continuous.md` — Sonnet 5's GKZ/secondary polytope explanation
- `staging/OctilinearEmbedding.lean` — KKT multiplier, covector projection, transitCoord
- `scripts/generate_transit_json.py` — build_lines (sequential x bug), build_river (corrected 45° edges)
- `canvas_app/frontend/src/transit-entry.tsx` — React component with river overlay, Legend
- `data/reinforcement_candidates.json` — 560 candidate reinforcement types
- `docs/tube_map_covector_design.md` — KKT→covector projection design
- `lab_notes/031_ic_is_regular_subdivision.md` — Institutional Closure as GKZ regular subdivision
- `LaserCortex/staging/Friction.lean` — frictionDensity, cd phase change at 2→3
- `docs/lab_protocol.md` — v0.3 timespace decomposition protocol

---

## 9. The Type Algebra (Develin-Sturmfels Puzzle-Piece Grammar)

### 9.1 What the 35-Quads Figure IS

The figure at `docs/Tropical/arXiv-math0308254v3/35quads-shrunk.eps` (Develin & Sturmfels, "Tropical Convexity", 2004) shows the **35 symmetry classes of tropical complexes generated by 4 points in TP²**. Each quad arrangement = one symmetry class of regular triangulations of Δ₂×Δ₃. The cells of each decomposition are labelled by **types** `(S₁, S₂, S₃)` where each `S_j ⊆ {1,2,3,4}`.

These 35 configurations are the classification of all possible ways 4 points in the tropical plane can generate a cell complex. **Our transit map IS one of these** — or rather, our KKT stations define a point configuration whose tropical complex is the transit map's cell decomposition, and the 35 quads show the possible combinatorial types our map could take depending on which stations are active.

The user's insight: the type system *is* the algebra of laying puzzle pieces. Each cell has a type; adjacency between cells is the containment relation `S ⊆ T`; and a 45° station in the transit map corresponds to a **degenerate type** where two coordinates share generators — a **wall** condition in GKZ terms.

### 9.2 Develin-Sturmfels Type System

Let `V = {v₁, ..., v_r}` be a set of points in TP^{n-1} (here `r = number of stations`, `n = 3` for the tropical plane). Each point `x ∈ TP^{n-1}` has a **type**:

```
type(x) = (S₁, ..., Sₙ) where
  i ∈ S_j  ⟺  v_{ij} − x_j = min_k(v_{ik} − x_k)
```

i.e. generator `v_i` achieves the minimum for coordinate `j` at point `x`.

The **cell** `X_S` = closure of `{x : S ⊆ type(x)}`. These cells form a polyhedral complex:

| Relation | Meaning |
|----------|---------|
| `S ⊆ T` | `X_T` is a face of `X_S` (type containment = face poset) |
| `S ∪ T` | `X_S ∩ X_T = X_{S∪T}` (intersection = union of types) |
| `S_j ≠ ∅ ∀j` | `X_S` is bounded (all coordinates determined) |

**The tropical polytope P = tconv(V) = union of all bounded cells.**

### 9.3 Mapping to the Transit Map

| Develin-Sturmfels | Our transit map |
|------------------|----------------|
| Generator `v_i` (point in TP^{n-1}) | Station `(tree, cdStep)` with transitCoord `(x, y)` embedded as `(0, x, y) ∈ TP²` |
| Coordinate index `j ∈ {1,...,n}` | The 3 coordinate directions of TP²: `(projective, size+assocDefect, lw−rw)` |
| Type `(S₁,...,Sₙ)` | Which stations determine which coordinate minima at a given point in KKT space |
| Cell `X_S` | A region of KKT space with a consistent station-activation pattern |
| Bounded cell | A transit map segment (has all coordinates bounded, i.e. a fully determined position) |
| `S ⊆ T` adjacency | Adjacent segments share a facet (common puzzle-piece edge) |
| `|S_j| > 1` for some j | **Degenerate type** — multiple generators tie at a coordinate minimum = **a 45° station wall** |

### 9.4 The 45° Edge as a Wall (Degenerate Type)

A **true 45° edge** (within-CD, Δx=+1, Δy=±1) corresponds to a type where:

- Two different stations `v_i` and `v_k` both achieve the minimum for coordinate 2 or coordinate 3 (the `x` or `y` coordinate of tubeCoord)
- This is the GKZ wall condition: the height function values are equal, so the lifted points are coplanar
- The edge connecting the two stations IS the wall — the flip in the triangulation

The **accompaniment** is visible in the full type tuple: the station at the 45° turn has a type where at least one `S_j` has cardinality > 1, and the adjacent stations have types that refine (contain) this type.

**Concretely**: if station `v_a` is the source of a NE edge (balanced odd-depth leaf), then in the cell containing the midpoint of that edge, the type will have `{a, b} ⊆ S_j` for some `j` (both the source and target stations' generators are tied for that coordinate). The adjoining cells (before and after the turn) will each have a singleton `S_j = {a}` and `S_j = {b}` respectively — i.e. they are the non-degenerate refinements on either side of the wall.

### 9.5 The Algebra of Laying Puzzle Pieces

The grammar is:

```
PuzzlePiece ∶= bounded cell X_S labelled by type (S₁,...,Sₙ)
Assembly    ∶= complex of bounded cells with face relations S ⊆ T
Line        ∶= a path through the type poset
LineSegment ∶= a transition between adjacent types differing by one generator

Type change rules (KKT step types):

  contracts_one  :  S changes by removing one generator from one S_j
                   (Δx = −1, the tree contracts — some coordinate becomes
                   determined by fewer generators)

  leaf_expand   :  S changes by adding a generator to some S_j
                   (Δx = +1, Δy = ±1 — a 45° edge, a new station enters
                   the minimum set)

  cd_projection :  S changes by shifting which generator set determines
                   each coordinate
                   (Δx = 0, Δy = ±1 — same tree at different cdStep,
                   generator identity shifts)

  axis_expand   :  S changes by adding a generator to S_j for the
                   x-coordinate only
                   (Δx = +1, Δy = 0 — pure size increase)
```

**Composition**: two puzzle pieces `X_S` and `X_T` share a face iff `S ⊆ T` or `T ⊆ S`. A transit line is a chain `S¹ ⊂ S² ⊂ ... ⊂ S^k` where each containment corresponds to one KKT unit step.

The 35 quads show all possible type algebras for `r=4` generators in TP². Our transit map's type algebra will be one of these 35 symmetry classes (or a multi-CD superposition of them across cdSteps).

### 9.6 What "Accompanies a 45° Turn"

In the type algebra, a 45° turn manifests as:

1. **The degenerate type at the turn station**: some `S_j` has size ≥ 2 (the two crossing generators both achieve the minimum for that coordinate)
2. **The face refinement before the turn**: the preceding cell's type is a singleton refinement of the degenerate type (only generator `a` active)
3. **The face refinement after the turn**: the following cell's type is the other singleton refinement (only generator `b` active)
4. **The vector difference**: the coordinate change from before to after = `(Δx, Δy) = (+1, ±1)` — the sum of the incoming and outgoing KKT changes

The "other things which accompany it" are: the adjacent type refinements in the poset, the specific generators that become tied at the wall, and the tree-structural condition (balanced odd-depth leaf) that enables the degenerate type.

### 9.7 Relation to Existing Formalizations

This connects three previously independent formal results:

| Result | Lean file | What it proves |
|--------|-----------|----------------|
| `develin_sturmfels_quantized_correspondence` (note 021) | `QuantizedType.lean` | Friction density induces a **regular subdivision** of Δ_{k-1}×Δ_{m-1} |
| `contracts_to_rightComb` (note 031) | `staging/Tamari.lean:373` | Every tree contracts to the fan triangulation — the Tamari lattice IS the regular subdivision poset |
| `transitCoord` (this note) | `staging/OctilinearEmbedding.lean` | KKT multiplier → covector projection → station positions in ℤ² |

The missing link: **the type system** — which stations' covector constraints are active at each point in KKT space. Implementing the Develin-Sturmfels type enumeration for our specific station configuration would:

1. Generate the exact cell decomposition of the transit map
2. Identify which stations are adjacent (share a type facet)
3. Validate which 45° edges correspond to degenerate types (walls)
4. Provide the formal grammar for assembling reinforcement-type fragments into lines
