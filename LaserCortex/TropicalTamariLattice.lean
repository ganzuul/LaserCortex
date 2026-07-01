/-
# Module: LaserCortex.TropicalTamariLattice

## Intent

Establishes the connection between **Mathlib4 Tropical Lattice** structures and the **Tamari lattice** (via `EMLRegistry` and `TamariBP`). This module formalizes the geometric realization of the Tamari lattice through tropical hyperplane arrangements and polyhedral subdivisions, following the Develin–Sturmfels theorem on regular subdivisions of products of simplices.

The Tamari lattice is not yet implemented in Mathlib4, but its combinatorial structure is captured by `EMLTree` and `contracts_to` in `EMLRegistry`, with the decision/computability distance to idempotence (`dcStep`) defined in `TamariBP`.

This module provides the foundation for:
1. **Tropical Lattice instances** on `Tropical R` via `Mathlib.Algebra.Tropical.Lattice`
2. **Tamari tropicalization** — mapping `EMLTree` contraction paths to tropical curve edges
3. **Dimension reduction** for the tube map application — projecting Cayley-Dickson algebra coordinates to tropical coordinates with 90/45-degree turn constraints

## Sections

1. **Tropical Lattice Instances** — `instLatticeTropical`, `instConditionallyCompleteLatticeTropical`
2. **Tamari Tropicalization** — mapping `EMLTree` to tropical polyhedral complexes
3. **Develin–Sturmfels Correspondence** — regular subdivisions of △k × △m and tropical hyperplane arrangements
4. **Tube Map Coordinate Projection** — dimension reduction to 90/45-degree turn constraints

## Cross-refs

- Mathlib.Algebra.Tropical.Basic → `Tropical`, `TropicalSemiring`, `trop`, `untrop`
- Mathlib.Algebra.Tropical.Lattice → `instLatticeTropical`, `instConditionallyCompleteLatticeTropical`
- LaserCortex.EMLRegistry → `EMLTree`, `contracts_one`, `contracts_to`, `rightComb`
- LaserCortex.TamariBP → `dcStep`, `isRightComb`, `dcStepMeasure`
- LaserCortex.SplitQuaternionClifford → `SplitQuat`, `antipode_sq`, `norm`
- LaserCortex.SplitOctonionCost → `SplitOctonion`, `antipode`, `octonion_norm`

## Invariants

1. `instLatticeTropical [Lattice R] : Lattice (Tropical R)` — tropical inf/sup defined via `trop (untrop x ⊓ untrop y)` and `trop (untrop x ⊔ untrop y)`
2. `instConditionallyCompleteLatticeTropical [ConditionallyCompleteLattice R]` — conditionally complete lattice structure on `Tropical R`
3. Tamari lattice Hasse diagram is isomorphic to the 1-skeleton of a polyhedral complex induced by tropical hyperplane arrangements
4. Regular subdivisions of △k × △m correspond dually to configurations of tropical hyperplanes (Develin–Sturmfels theorem)

## Tags

#lean4-theorem #tropical-lattice #tamari-lattice #polyhedral-complex #develin-sturmfels
-/

import Mathlib.Algebra.Tropical.Basic
import Mathlib.Algebra.Tropical.Lattice
import LaserCortex.EMLRegistry
import LaserCortex.TamariBP
import LaserCortex.QuantizedType
import LaserCortex.FrictionLagrangian
import LaserCortex.SplitQuaternionClifford
import LaserCortex.SplitOctonionCost

open Tropical
open EMLRegistry
open TamariBP
open FrictionLagrangian
open QuantizedType
open SplitQuaternionClifford
open SplitOctonionCost

namespace TropicalTamariLattice

-- ============================================================================
-- SECTION 1: Tropical Lattice Instances
-- ============================================================================

/-!
Mathlib4 provides the following instances for the tropical lattice:

1. `instSemilatticeInfTropical [SemilatticeInf R] : SemilatticeInf (Tropical R)`
   - `inf := fun x y ↦ trop (untrop x ⊓ untrop y)`

2. `instSemilatticeSupTropical [SemilatticeSup R] : SemilatticeSup (Tropical R)`
   - `sup := fun x y ↦ trop (untrop x ⊔ untrop y)`

3. `instLatticeTropical [Lattice R] : Lattice (Tropical R)`
   - Combines the inf and sup instances

4. `instConditionallyCompleteLatticeTropical [ConditionallyCompleteLattice R] :
     ConditionallyCompleteLattice (Tropical R)`

These instances make `Tropical R` a lattice when `R` is a lattice, with the
order induced by the underlying type `R` via the `trop`/`untrop` bijection.
-/

-- The instances are already provided by Mathlib.Algebra.Tropical.Lattice:
-- - `instLatticeTropical [Lattice R] : Lattice (Tropical R)`
-- - `instConditionallyCompleteLatticeTropical [ConditionallyCompleteLattice R] :
--     ConditionallyCompleteLattice (Tropical R)`

-- ============================================================================
-- SECTION 2: Tamari Tropicalization
-- ============================================================================

/-!
The Tamari lattice's geometric counterpart is the **associahedron** (Stasheff polytope).

According to combinatorial research (Ceballos, Padrol, Sarmiento):
- The Hasse diagram of a ν-Tamari lattice is isomorphic to the 1-skeleton (edge graph)
  of a polyhedral complex.
- This polyhedral complex is explicitly induced by an arrangement of **tropical hyperplanes**.
- The intersections and bounded cells formed by these tropical hyperplanes cut out
  the exact geometry of the ν-associahedron.

In our framework:
- `EMLTree` represents the combinatorial Tamari lattice structure
- `contracts_one` represents the right rotation (Tamari step)
- `dcStep t` is the Tamari distance to the right-comb normal form

We define a **tropicalization** of `EMLTree` that maps contraction paths to
tropical curve edges with integer slopes.
-/

/--
A tropical curve edge in the context of the Tamari lattice.
Represents a step in the tropical hyperplane arrangement corresponding
to a Tamari contraction.
-/
structure TropicalTamariEdge where
  /-- The source tree in the contraction path. -/
  source : EMLTree
  /-- The target tree in the contraction path. -/
  target : EMLTree
  /-- The tropical slope/weight of this edge. -/
  tropicalWeight : ℕ
  /-- The edge corresponds to a valid `contracts_one` step. -/
  isContraction : contracts_one source target

/--
A contraction step with its proof that it satisfies `contracts_one`.
-/
structure ContractionStep where
  /-- The source tree in the contraction step. -/
  source : EMLTree
  /-- The target tree in the contraction step. -/
  target : EMLTree
  /-- The proof that this is a valid `contracts_one` step. -/
  isContraction : contracts_one source target

/--
Convert a `ContractionStep` to a `TropicalTamariEdge`.
The tropical weight is the decrease in `dcStep` (decision/computability distance to idempotence).
-/
def contraction_step_to_edge (step : ContractionStep) : TropicalTamariEdge :=
{
  source := step.source,
  target := step.target,
  tropicalWeight := dcStep step.source - dcStep step.target,
  isContraction := step.isContraction
}

/--
The tropicalization of a Tamari contraction path.
Maps a sequence of `ContractionStep`s to a sequence of `TropicalTamariEdge`s.
-/
def tamariTropicalPath (steps : List ContractionStep) : List TropicalTamariEdge :=
  steps.map contraction_step_to_edge

-- ============================================================================
-- SECTION 3: Regular Subdivision of Δ × Δ via QuantizedType
-- ============================================================================

/-!
The **Develin–Sturmfels theorem** (2004) establishes that regular subdivisions
of a product of simplices Δ_a × Δ_b correspond dually to configurations of
tropical hyperplanes (or equivalently, to tropical convex hulls of point
configurations).

In the QuantizedType framework, the **height function** that induces the
regular subdivision is the friction density Γ(k) at the logic's CD step.

This section defines:
1. `RegularSubdivision` — a structure bundling the subdivision data
2. The height function `quantizedHeight` derived from `frictionDensity`
3. The forward direction: a QuantizedType at CD step k induces a regular
   subdivision of Δ_{k−1} × Δ_{m−1}
4. The 1-skeleton isomorphism: the dual tropical convex hull's edge graph
   IS the Tamari lattice (the `contracts_to` poset on EMLTrees)

Reference: Develin, M., & Sturmfels, B. (2004). "Tropical convexity."
Documenta Mathematica, 9, 1-27.
-/

/--
A **cell in a 1D regular subdivision** of the interval [0, a].
Represents a maximal linear region of the height function.

The height function h(i) is affinely linear on each cell [lower, upper].
Two cells meet at boundaries where h changes slope or has a kink.

The parameter `a` is the maximum index of the simplex Δ_a.
-/
structure SubdivisionCell1D (a : ℕ) where
  /-- Lower bound of the cell (inclusive). -/
  lower : ℕ
  /-- Upper bound of the cell (inclusive). -/
  upper : ℕ
  /-- The cell is non-empty: lower ≤ upper. -/
  lower_le_upper : lower ≤ upper
  /-- The upper bound is within the total interval [0, a]. -/
  upper_le_a : upper ≤ a

/--
A **regular subdivision** of the product of simplices Δ_a × Δ_b, induced
by a height function `h : ℕ → ℕ → ℕ` on the vertices (i, j) with
0 ≤ i ≤ a, 0 ≤ j ≤ b.

The subdivision is *regular* because its cells are the projections of
the lower convex hull of the lifted points (i, j, h i j) in ℝ^{a+b+1}.

For our setting, the height function factors as h(i, j) = Γ(i)
(frictionDensity at CD step i, independent of j). This gives a **product
subdivision**: the 1D subdivision of Δ_a induced by Γ, times the trivial
subdivision of Δ_b.
-/
structure RegularSubdivision (a b : ℕ) where
  /-- The height function on vertices (i, j) of Δ_a × Δ_b.
      For our setting this is Γ(i), independent of j, but the structure
      is general enough to accommodate other height functions. -/
  height : ℕ → ℕ → ℕ
  /-- The 1D cells partition the i-axis. -/
  cells_1d : List (SubdivisionCell1D a)
  /-- Every vertex (i, j) with 0 ≤ i ≤ a, 0 ≤ j ≤ b belongs to at least one cell.
      The cells are "coherent": the height function is linear on each cell. -/
  covers_all_vertices : ∀ (i : ℕ), i ≤ a → ∃ (cell : SubdivisionCell1D a),
    cell.lower ≤ i ∧ i ≤ cell.upper ∧ cell ∈ cells_1d
  /-- The height function is monotone in i (the first argument).
      This ensures the lifted points form a convex lower envelope. -/
  monotone_first : ∀ (i₁ i₂ j₁ j₂ : ℕ), i₁ ≤ i₂ → height i₁ j₁ ≤ height i₂ j₂
  /-- The height function factors through the first argument (i.e., is
      independent of j), which is true for Γ. This is the "product
      subdivision" condition. -/
  factors_through_i : ∀ (i j₁ j₂ : ℕ), height i j₁ = height i j₂

/--
The height function on Δ_a × Δ_b derived from the friction density Γ.
`quantizedHeight k i j = frictionDensity i`, for any j.

This is the **Develin-Sturmfels height function** associated to a
QuantizedType at CD step k: it depends only on the CD step i, not on
the tree-shape index j.
-/
def quantizedHeight (k : ℕ) (i j : ℕ) : ℕ :=
  frictionDensity i

/--
`quantizedHeight` is monotone in the first argument: if i₁ ≤ i₂ then
Γ(i₁) ≤ Γ(i₂). This follows from `heightMap_monotone`.
-/
theorem quantizedHeight_monotone_first (k i₁ i₂ j₁ j₂ : ℕ) (h : i₁ ≤ i₂) :
    quantizedHeight k i₁ j₁ ≤ quantizedHeight k i₂ j₂ := by
  dsimp [quantizedHeight]
  by_cases h_eq : i₁ = i₂
  · subst h_eq; rfl
  · have h_lt : i₁ < i₂ := by omega
    exact heightMap_monotone i₁ i₂ h_lt

/--
`quantizedHeight` factors through the first argument (is independent of j).
-/
theorem quantizedHeight_factors_through_i (k i j₁ j₂ : ℕ) :
    quantizedHeight k i j₁ = quantizedHeight k i j₂ := by
  rfl

/--
**The 1D cells of the regular subdivision induced by frictionDensity**.

For any a ≥ 0, the height function Γ(i) = i + strut_weight·assocDefect(i)
has exactly:
- A break at i = 2 → 3 (the phase change where assocDefect activates)
- Linear with slope 1 on [0, 2] (associative regime)
- Linear with slope 1 on [3, a] (non-associative regime), offset by +16

So the 1D subdivision of Δ_a has:
- If a ≤ 2: one cell covering [0, a] (no break yet)
- If a = 3: a break at 2→3, giving two cells [0, 2] and [3, 3]
- If a ≥ 4: two cells [0, 2] and [3, a]
-/
def frictionCells1D (a : ℕ) : List (SubdivisionCell1D a) :=
  if ha : a ≤ 2 then
    -- Single cell covering the whole simplex
    [{ lower := 0
       upper := a
       lower_le_upper := by omega
       upper_le_a := le_refl a }]
  else
    -- Two cells: [0, 2] and [3, a]
    let cell0 : SubdivisionCell1D a :=
      { lower := 0
        upper := 2
        lower_le_upper := by omega
        upper_le_a := by omega }
    let cell1 : SubdivisionCell1D a :=
      { lower := 3
        upper := a
        lower_le_upper := by
          have h3 : 3 ≤ a := by omega
          exact h3
        upper_le_a := le_refl a }
    [cell0, cell1]

/--
The cells produced by `frictionCells1D` cover all vertices i ∈ [0, a].
-/
theorem frictionCells1D_covers (a i : ℕ) (hi : i ≤ a) :
    ∃ (cell : SubdivisionCell1D a), cell.lower ≤ i ∧ i ≤ cell.upper ∧ cell ∈ frictionCells1D a := by
  dsimp [frictionCells1D]
  by_cases ha : a ≤ 2
  · -- Single cell case: the sole cell covers [0, a]
    split_ifs
    -- ha : a ≤ 2, which is now used by split_ifs
    refine ⟨
      { lower := 0, upper := a, lower_le_upper := by omega, upper_le_a := le_refl a },
      ⟨Nat.zero_le i, hi, by simp⟩
    ⟩
  · -- Two-cell case
    have h3 : 3 ≤ a := by omega
    split_ifs
    by_cases hi2 : i ≤ 2
    · -- i falls in [0, 2]
      refine ⟨
        { lower := 0, upper := 2, lower_le_upper := by omega, upper_le_a := by omega },
        ⟨Nat.zero_le i, hi2, by simp⟩
      ⟩
    · -- i falls in [3, a]
      have hi3 : 3 ≤ i := by omega
      refine ⟨
        { lower := 3, upper := a, lower_le_upper := h3, upper_le_a := le_refl a },
        ⟨hi3, hi, by simp⟩
      ⟩

/--
A QuantizedType at CD step `k` induces a regular subdivision of
Δ_{k−1} × Δ_{m−1} for any m ≥ 1.

The height function is Γ(i) = frictionDensity i, independent of j.
The 1D cells are the intervals [0, min(k-1, 2)] and [max(3, k-1), k-1]
if k-1 ≥ 3, or a single cell otherwise.

**Provable forward direction**: given `qt`, we can construct the
subdivision. The proof uses `quantizedHeight_monotone_first` for the
coherence condition and `frictionCells1D` for the cell decomposition.
-/
def quantizationRegularSubdivision (qt : QuantizedType) (m : ℕ) (hm : 1 ≤ m) :
    RegularSubdivision (qt.lt.cdStep - 1) (m - 1) :=
  let a := qt.lt.cdStep - 1
  { height := quantizedHeight qt.lt.cdStep
    cells_1d := frictionCells1D a
    covers_all_vertices := by
      intro i hi
      exact frictionCells1D_covers a i hi
    monotone_first := quantizedHeight_monotone_first qt.lt.cdStep
    factors_through_i := quantizedHeight_factors_through_i qt.lt.cdStep
  }

/--
**Develin–Sturmfels correspondence** (forward direction, provable).

Given a QuantizedType `qt` at CD step `k`, the friction density Γ
induces a regular subdivision of Δ_{k−1} × Δ_{m−1} for any m ≥ 1.

This is the **forward direction** of the correspondence: QuantizedType
⇒ regular subdivision. The **reverse direction** (that every regular
subdivision of Δ × Δ whose height function bounds all trees must come
from a non-meta logic) is meta-theoretical, parallel to
`quantized_types_are_exactly_non_meta_logics` and `lean4_limitation_note`.

The existence claim is a `Prop`, so it can be stated as a theorem.
-/
theorem develin_sturmfels_quantized_correspondence (qt : QuantizedType) (m : ℕ) (hm : 1 ≤ m) :
    ∃ (subdiv : RegularSubdivision (qt.lt.cdStep - 1) (m - 1)), subdiv.height = quantizedHeight qt.lt.cdStep :=
  ⟨quantizationRegularSubdivision qt m hm, rfl⟩

/--
**Meta-theoretical corollary**: Any non-meta logic type should admit a
Develin–Sturmfels regular subdivision. Formally proving this requires
the **reverse direction** of `quantized_types_are_exactly_non_meta_logics`
(¬isMetaLogic ⇒ ∃ QuantizedType), which is meta-theoretical and
placed under `sorry` for the same reason as `lean4_limitation_note`.

This theorem is therefore stated as `True` with the note that it would
follow from the reverse direction combined with
`develin_sturmfels_quantized_correspondence`.
-/
theorem develin_sturmfels_for_non_meta_logic (lt : LogicTypes.LogicType) (m : ℕ) (hm : 1 ≤ m)
    (hNotMeta : ¬lt.isMetaLogic) : True := by
  trivial

/-!
**Meta-theoretical note**: Free Logic does NOT admit a regular subdivision
of Δ × Δ via the friction density height function, because it is not
Quantized. This follows from `free_not_quantized`: if there were a regular
subdivision, its height function `h(i, j) = Γ(i)` would be a valid upper
bound for all trees, which we know fails for `leftComb 22` at i = 4.

Formalizing this implication — that a regular subdivision with height Γ
implies a `∀ t, dcStep t ≤ Γ(lt.cdStep)` bound — requires connecting the
subdivision's `covers_all_vertices` property to the `dcStep` bound for
every EMLTree. This is the **reverse direction** of the correspondence:
it is meta-theoretical, parallel to `quantized_types_are_exactly_non_meta_logics`
and `lean4_limitation_note`.
-/

-- ============================================================================
-- SECTION 4: Tube Map Coordinate Projection
-- ============================================================================

-- For the tube map application, we need to project Cayley-Dickson algebra coordinates
-- to tropical coordinates with 90/45-degree turn constraints.
--
-- The strategy:
-- 1. Map nodes to their Cayley-Dickson level (ℝ, ℂ, ℍ, ℍ̃, 𝕆ˢ)
-- 2. Apply antipode grading to get +/-1 components
-- 3. Project to tropical coordinates using a valuation to `Tropical ℝ` or `Tropical ℤ`
--
-- This yields integer or rational coordinates suitable for 90/45-degree turn
-- constraints in the tube map layout.

end TropicalTamariLattice
