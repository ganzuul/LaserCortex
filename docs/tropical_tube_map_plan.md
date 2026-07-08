# Plan: Tropical Algebra + LC Primitives for Tube Map Topology

## Overview

This document outlines the plan for connecting Tropical algebraic structures to LaserCortex (LC) primitives (Split-Quaternions, Tamari lattice, AMM) to derive the tube map connectivity topology. The tube map would be given only two starting points, and generation needs to connect them by finding the right inductive biases (existing like AMM or TamariBP, or discovered and certified during the process). As generation proceeds, the map is filled in, "island of inductive bias by island."

## 1. Mathlib4 Tropical Semiring Foundation

Mathlib4 provides `Mathlib.Algebra.Tropical.Basic` with:
- `TropicalSemiring α` with operations `⊕ = min` and `⊗ = +`
- `Tropical α` type for the tropical semiring over an ordered additive commutative monoid
- Tropical polynomial and tropical variety definitions

**Key properties to leverage:**
- Tropical addition: `a ⊕ b = min(a, b)`
- Tropical multiplication: `a ⊗ b = a + b`
- Tropical curves have **integer slopes** and satisfy **zero-tension conditions** at vertices (balanced edge directions)

## 2. Connection to LC Primitives

### Split-Quaternions (ℍ̃) ↔ Tropical
- Split-quaternions have the (2,2) norm: `N(x) = x.e0² + x.e1² - x.e2² - x.e3²`
- The antipode `antipode_sq` is the ℤ/2-grading involution: `antipode_sq (a + b·e₂ + c·e₃ + d·e₂e₃) = a - b·e₂ - c·e₃ - d·e₂e₃`
- **Projection strategy**: Apply a valuation `ν: ℍ̃ → Tropical ℝ` where `ν(x) = -log|N(x)|` (or discrete valuation on components)

### Tamari Lattice ↔ Tropical Curves
- `TamariBP.dcStep t` is the Tamari distance to the right-comb normal form (idempotent minimum)
- `AMM.Route` maps to `EMLTree` via `routeToTree`, and `routeDepth` is the depth in the Tamari lattice
- **Tropical connection**: The Tamari contraction paths are piecewise linear sequences of rotations, analogous to tropical curve edges with integer slopes

### Antipode / +/-1 ↔ Tropical Min/Max
- The antipode fixes `e₀, e₄` and negates primitive components `e₁, e₂, e₃, e₅, e₆, e₇`
- This is a **+/-1 grading** that mirrors the tropical semiring's min/max duality:
  - Min tropical: `(ℝ ∪ {+∞}, min, +)`
  - Max tropical: `(ℝ ∪ {-∞}, max, +)`
- The antipode's involution `antipode_sq (antipode_sq x) = x` mirrors the tropical idempotence `a ⊕ a = a`

## 3. Tube Map Connectivity Topology Strategy

### Phase 1: Two Starting Points → Inductive Bias Islands
- Input: Two starting nodes (e.g., `flow_index` A and B with positions `p_A, p_B`)
- Generation finds inductive biases (AMM routes, TamariBP paths) to connect them
- Each bias becomes an "island" of connectivity in the tube map

### Phase 2: Tropical Projection of Coordinates
For each node in the graph:
1. **Map to Cayley-Dickson level**: Determine the CD level (ℝ, ℂ, ℍ, ℍ̃, 𝕆ˢ)
2. **Apply antipode grading**: Compute `antipode_sq(x)` or `antipode(x)` to get +/-1 components
3. **Project to tropical coordinates**: 
   - For split-quaternions: `trop_coords(x) = (ν(x.e0), ν(x.e1), ν(x.e2), ν(x.e3))` where `ν` is a valuation to `Tropical ℝ`
   - This yields integer or rational coordinates suitable for 90/45-degree turn constraints

### Phase 3: Tamari-BP Boundedness → Tube Map Layout
- Use `TamariBP.dcStep t` to determine the "complexity" of each subtree
- Trees with `dcStep ≤ 19` (CD 2→3 boundary) are well-posed and can be laid out with standard 90/45-degree turns
- Trees outside the budget require higher CD steps or tropical regularization

### Phase 4: AMM Route Composition → Edge Connectivity
- `AMM.Route` represents swap paths as binary trees
- `routeToTree r` maps to `EMLTree` (Tamari decomposition)
- `routeDepth r` gives the path length in the Tamari lattice
- These become the **edges** in the tube map, with `compose r1 r2` representing sequential connections

## 4. Lean4 Formalization Steps

### Step 1: Import Tropical Semiring
```lean
import Mathlib.Algebra.Tropical.Basic
```

### Step 2: Define Tropical Valuation on Split-Quaternions
- Create `tropical_valuation_sq : SplitQuat → Tropical ℝ`
- Prove valuation properties: `ν(xy) = ν(x) ⊗ ν(y)`, `ν(x+y) ≥ ν(x) ⊕ ν(y)`

### Step 3: Connect Tamari BP to Tropical Curves
- Define `tamari_tropical_curve : EMLTree → TropicalCurve`
- Prove `dcStep t` corresponds to the number of tropical edges

### Step 4: AMM Route to Tube Map Edges
- Define `route_to_tube_edge : Route → TubeEdge`
- Prove `routeDepth r` satisfies 90/45-degree turn constraints

## 5. Implementation Phases

| Phase | Task | Output |
|-------|------|--------|
| 1 | Import and verify Mathlib4 Tropical definitions | `Mathlib.Algebra.Tropical.Basic` accessible |
| 2 | Define tropical valuation on `SplitQuat` and `SplitOctonion` | `tropical_valuation_sq`, `tropical_valuation_oct` |
| 3 | Connect `TamariBP.dcStep` to tropical curve length | `tamari_to_tropical_curve` theorem |
| 4 | Map `AMM.Route` to tube map edges with 90/45 constraints | `route_to_tube_map` function |
| 5 | Generate tube map from two starting points | `generate_tube_map : Point → Point → TubeMap` |

## 6. Key Questions for Clarification

1. **Valuation target**: Should the tropical valuation map to `Tropical ℝ` (real numbers) or `Tropical ℤ` (integers) for the 90/45-degree turn constraints?

2. **Starting points representation**: Are the two starting points represented as `flow_index` values, or as `SplitQuat`/`SplitOctonion` elements?

3. **Inductive bias discovery**: Should the generation process use existing AMM/TamariBP kernels, or should it discover new biases during the tropical projection phase?

## 7. Relevant LC Files

- `LaserCortex/TamariBP.lean`: Formalizes binary belief propagation on the Tamari lattice, `dcStep` as Tamari distance to right-comb
- `LaserCortex/AMM.lean`: Constant-product automated market maker with binary-tree swap routes, `Route`, `routeToTree`, `routeDepth`
- `LaserCortex/SplitQuaternionClifford.lean`: Cl(1,1) over ℤ, split quaternions ℍ̃, `antipode_sq`, `norm_mul`, `antipode_sq_preserves_norm`
- `LaserCortex/Hopf.lean`: Antipode on SplitOctonion, antipode-invariant (4,4) quadratic norm: `octonion_norm(S(x)) = octonion_norm(x)`
- `LaserCortex/Cost.lean`: Cost function Φ over EML trees, invariant under Tamari rotations
- `LaserCortex/MarketClosure.lean`: AMM fair-price kernel, `AMM.reserveGuard`, `AMM.certifiedClose`
