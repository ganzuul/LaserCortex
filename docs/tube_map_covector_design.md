# Tube Map Covector Projection — Design Document

## Overview

The tube map is a 2D layout of the CD (Cayley-Dickson) tower contraction space.
Each node is an `EMLTree` at a specific CD step, and edges represent
`contracts_one` rotation steps. The layout is constrained so that edges
are either axis-aligned (90° turns) or diagonal (45° turns).

The **covector projection** maps each tree's KKT multiplier λ_t ∈ SplitQuat
to 2D integer coordinates via a graded projection that respects the
antipode parity classification.

## The KKT Multiplier λ_t

Each tree `t` at CD step `cd` maps to a split quaternion:

```
λ_t = kktMultiplier cd t ∈ SplitQuat
    = (a, b, c, d)  where:
      a = t.size            — EVEN  (grade 0 scalar)    → 90° coordinate
      b = leftWeight t      — ODD   (grade 1 vector)    → 45° coordinate
      c = rightWeight t     — ODD   (grade 1 vector)    → 45° coordinate
      d = assocDefect cd    — EVEN  (grade 2 bivector)  → 90° coordinate
```

### Component semantics

| Component | Source | Parity | Meaning |
|-----------|--------|--------|---------|
| a | `t.size` | even | Structural size (number of internal nodes) |
| b | `leftWeight t` | odd | Left-branching bias (sum of left subtree sizes) |
| c | `rightWeight t` | odd | Right-branching bias (sum of right subtree sizes) |
| d | `assocDefect cd` | even | Non-associative cost at this CD layer (0 for cd ≤ 2, 4 for cd ≥ 3) |

### Antipode grading

The antipode `antipode_sq` (on SplitQuat) negates the odd components:

```
antipode_sq(λ_t) = (a, -b, -c, d)
```

This matches `involute` on the Clifford algebra Cl(1,1) under the
embedding `SplitQuat.embed` (proven as `embed_antipode_eq_involute` in
`TropicalTamariLattice.lean`).

## Covector Projection

The 2D projection separates even and odd components:

```
covectorProjection(λ) = (x, y) where:
  x = a + d    (even + even → axis-aligned 90°)
  y = b − c    (odd − odd → diagonal 45°)
```

### Full tube coordinate

```
tubeCoord cd t = (t.size + assocDefect cd, leftWeight t − rightWeight t)
```

### Key properties

1. **x-coordinate**: `t.size + assocDefect cd` — structural size plus
   phase-change offset. At CD ≤ 2, assocDefect = 0 so x = t.size. At
   CD ≥ 3, x = t.size + 4 (strut_weight), giving a horizontal shift
   of +4 in the tube map.

2. **y-coordinate**: `leftWeight t − rightWeight t` — branching asymmetry.
   Positive for left-biased trees, negative for right-biased, zero for
   balanced or leaf trees. This depends only on tree structure, not on
   the CD step.

3. **CD-step separation**: At a fixed CD step, trees form vertical
   columns (x varies with size, y varies with asymmetry). Different CD
   steps are separated horizontally by assocDefect offsets.

4. **Antipode flips y**: `covectorProjection(antipode_sq λ) = (x, -y)` —
   reflecting the tree across the x-axis.

## Edge Angle Classification

An edge connecting tree `t` to tree `s` (where `contracts_one t s`) is
classified by which components of the KKT multiplier change:

| Δ-component | Δx | Δy | Edge angle |
|------------|-----|-----|------------|
| Δa ≠ 0, Δd = 0, Δb = Δc = 0 | ±1 | 0 | 90° horizontal |
| Δd ≠ 0, Δa = 0, Δb = Δc = 0 | ±|Δd| | 0 | 90° horizontal |
| Δb ≠ 0, Δc = 0, Δa = Δd = 0 | 0 | ±1 | 90° vertical |
| Δc ≠ 0, Δb = 0, Δa = Δd = 0 | 0 | ∓1 | 90° vertical |
| BOTH even AND odd change | mixed | mixed | 45° diagonal |
| No change | 0 | 0 | degenerate (no edge) |

**Note**: The 90°/45° distinction arises from the antipode grading:
even-component-only changes move only x → axis-aligned (90°);
odd-component-only changes move only y → also axis-aligned (90°);
mixed changes move both axes simultaneously → diagonal (45°).

## Implementation

### Lean files

| File | Contains |
|------|----------|
| `LaserCortex/TropicalCovector.lean` | `kktMultiplier`, `covectorProjection`, `tubeCoord`, basic theorems |
| `LaserCortex/TropicalTamariLattice.lean` | `embed_antipode_eq_involute`, `EdgeAngle` classification |
| `LaserCortex/TamariBP.lean` | `leftWeight`, `rightWeight`, `dcStep` |
| `LaserCortex/FrictionLagrangian.lean` | `assocDefect`, `strut_weight` |

### Key theorems (proven)

```lean
theorem tubeCoord_expand (cd : ℕ) (t : EMLTree) :
    tubeCoord cd t = ((t.size : ℤ) + (assocDefect cd : ℤ),
                      (leftWeight t : ℤ) - (rightWeight t : ℤ))

theorem tubeCoord_cd3_vs_cd2 (t : EMLTree) :
    (tubeCoord 3 t).1 = (tubeCoord 2 t).1 + (strut_weight : ℤ)

theorem embed_antipode_eq_involute (λ : SplitQuat) :
    SplitQuat.embed (antipode_sq λ) = CliffordAlgebra.involute (SplitQuat.embed λ)
```

### Python pipeline (planned)

A Python script will:
1. Enumerate all trees up to a given size
2. For each CD step 0–4, compute `kktMultiplier cd t`
3. Project to `tubeCoord cd t`
4. Follow `contracts_one` paths to generate edges
5. Output `.dat` files for gnuplot rendering

### Gnuplot rendering (planned)

Using the pattern from `scripts/quantum_advantage_plots.gnuplot`:
- Each CD layer as a separate subplot or color layer
- Trees as labeled points
- Contracts_one edges as lines
- Legend showing CD step, strut_weight offset, and angle classification

## Open Questions

1. **Angle semantics**: The current classification treats ANY change
   involving both even and odd components as 45° diagonal. A more
   nuanced classification might weight the angle proportionally to
   the even/odd magnitude ratio.

2. **Multi-layer layout**: When multiple CD steps are shown on the same
   map, the horizontal offset between layers (+4 at CD 3) may crowd
   smaller trees. A non-linear x-axis scaling may be needed.

3. **Edge bundling**: Multiple `contracts_one` paths between the same
   nodes are currently shown as distinct edges. Bundling them would
   reduce visual clutter.

4. **LeftWeight bounds**: The change in `leftWeight` under a single
   `contracts_one` step is `a.size + 1`, which is NOT bounded by ±1
   for large subtrees. The "≤(±1,±1,±1,±1)" claim from the initial
   spec is aspirational and requires a different weight definition
   or a normalization scheme.

## Comparison with Previous Loday Approach

The covector projection supersedes the earlier Loday-coordinate approach
(`Visualization/loday_coordinates.lean`):

| Aspect | Loday approach | Covector projection |
|--------|---------------|---------------------|
| Coordinate source | `parkingFunctionCoord` | `kktMultiplier` via Tamari weights |
| Dimension | Variable (n+1) | Fixed 2D (x, y) |
| Angle semantics | Not explicit | Antipode grading → 90°/45° |
| CD step coupling | None | `assocDefect cd` in x-coordinate |
| GA connection | None | `involute` ↔ `antipode_sq` via Cl(1,1) |
| KKT interpretation | None | `embed_mul` = stationarity |
