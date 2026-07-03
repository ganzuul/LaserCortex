/-
# Module: LaserCortex.TropicalCovector

## Intent

Defines the **KKT multiplier bridge** between `EMLTree` and the
SplitQuaternion Clifford algebra `Cl(1,1)`, and its 2D **covector
projection** for tube map coordinate layout.

The KKT multiplier λ_t ∈ SplitQuat encodes a tree's position in the
cost landscape of the ZD (zero divisor) constrained hyperbolic program.
Under the Chu–KKT isomorphism (`Chu.lean` §4), the multiplier satisfies:

  - **Stationarity**: `chu_embed_mul` — the embedding preserves products
  - **Complementarity**: `chu_zsmul_eq_mul` — scalar action matches algebra

The tube map coordinates (x, y) are obtained by projecting λ_t through
the antipode grading on Cl(1,1). The even-grade components (a, d) give
the x-coordinate (axis-aligned 90° edges), while the odd-grade components
(b, c) give the y-coordinate (45° diagonal edges).

## Sections

1. **KKT Multiplier** — `kktMultiplier : ℕ → EMLTree → SplitQuat`
2. **Covector Projection** — `covectorProjection : SplitQuat → ℤ × ℤ`
3. **Tube Map Coordinate** — `tubeCoord : ℕ → EMLTree → ℤ × ℤ`
4. **Basic Properties** — structural lemmas relating coordinates to tree size

## Cross-refs

- LaserCortex.SplitQuaternionClifford → `SplitQuat`, `antipode_sq`
- LaserCortex.TamariBP → `leftWeight`, `rightWeight`, `dcStep`
- LaserCortex.FrictionLagrangian → `assocDefect`
- LaserCortex.Chu → `chu_embed_mul`, `chu_zsmul_eq_mul` (KKT bridge)
- LaserCortex.EMLRegistry → `EMLTree`, `contracts_one`, `size`

## Invariants

1. `kktMultiplier cd t` has components `(t.size, leftWeight t, rightWeight t, assocDefect cd)`
2. `covectorProjection` maps (a, b, c, d) ↦ (a + d, b − c)
3. The antipode of λ_t is `⟨a, -b, -c, -d⟩`, matching `antipode_sq`
4. The Chu pairing β(λ_t, S(λ_t)) = a² + b² − c² − d² = norm(λ_t)

## Tags

#lean4-theorem #kkt-multiplier #covector-projection #tube-map #clifford-algebra
-/

import LaserCortex.SplitQuaternionClifford
import LaserCortex.TamariBP
import LaserCortex.FrictionLagrangian
import LaserCortex.SplitOctonionCost
import LaserCortex.EMLRegistry

open SplitQuaternionClifford
open TamariBP
open FrictionLagrangian
open SplitOctonionCost
open EMLRegistry

namespace TropicalCovector

-- ============================================================================
-- SECTION 1: KKT Multiplier
-- ============================================================================

/--
The KKT multiplier λ_t ∈ SplitQuat for a tree `t` at CD step `cd`.

Components:
  a = t.size         — EVEN  (grade 0 scalar, +1 under involute)   → 90° coordinate
  b = leftWeight t   — ODD   (grade 1 vector, −1 under involute)  → 45° coordinate
  c = rightWeight t  — ODD   (grade 1 vector, −1 under involute)  → 45° coordinate
  d = assocDefect cd — EVEN  (grade 2 bivector, +1 under involute)→ 90° coordinate

The parity classification follows from the Clifford algebra grading on
Cl(1,1): `involute` (grade involution) acts as +1 on grades {0, 2} and
−1 on grade {1}. Under the embedding `SplitQuat.embed`, the antipode
`antipode_sq` corresponds to `involute` on the embedded image.

**Interpretation**: λ_t is the Lagrange multiplier for the ZD-constrained
hyperbolic program (Chu.lean §4). The stationarity condition is
`chu_embed_mul` — the product of embedded trees equals the embedded
product. The complementarity condition is `chu_zsmul_eq_mul` — the
scalar action on the multiplier matches the algebra product.

The Chu pairing β(λ_t, S(λ_t)) = norm(λ_t) = a² + b² − c² − d²
measures the "distance" of tree t from the cost baseline at CD step cd.
-/
def kktMultiplier (cd : ℕ) (t : EMLTree) : SplitQuat :=
  ⟨ (t.size : ℤ)
  , (leftWeight t : ℤ)
  , (rightWeight t : ℤ)
  , (assocDefect cd : ℤ) ⟩

/--
The antipode (grading involution) of the KKT multiplier.
This is `antipode_sq` applied componentwise: negates the odd-grade
components (b, c) and fixes the even-grade ones (a, d).
-/
theorem kktMultiplier_antipode (cd : ℕ) (t : EMLTree) :
    antipode_sq (kktMultiplier cd t) = ⟨(t.size : ℤ), -(leftWeight t : ℤ), -(rightWeight t : ℤ), (assocDefect cd : ℤ)⟩ := by
  ext <;> simp [kktMultiplier, antipode_sq]

/--
The norm of the KKT multiplier equals the (2,2) determinant form:
  N(λ_t) = a² + b² − c² − d²
  where a = t.size, b = leftWeight t, c = rightWeight t, d = assocDefect cd
-/
theorem kktMultiplier_norm (cd : ℕ) (t : EMLTree) : (kktMultiplier cd t).norm =
    (t.size : ℤ)^2 + (leftWeight t : ℤ)^2 - (rightWeight t : ℤ)^2 - (assocDefect cd : ℤ)^2 := by
  simp [kktMultiplier, SplitQuat.norm]

-- ============================================================================
-- SECTION 2: Covector Projection
-- ============================================================================

/--
Project a KKT multiplier λ_t ∈ SplitQuat to 2D covector coordinates (x, y).

The projection respects the antipode grading:
  - EVEN-grade components (a, d) → x-coordinate (axis-aligned, 90° edges)
  - ODD-grade components (b, c)  → y-coordinate (diagonal, 45° edges)

Formula:
  x = a + d   (even + even)
  y = b − c   (odd − odd)

The difference `b − c` in the y-coordinate encodes the left/right branching
asymmetry: a tree biased toward left-branching (b > c) maps to positive y,
while a right-biased tree (c > b) maps to negative y.
-/
def covectorProjection (λ : SplitQuat) : ℤ × ℤ :=
  (λ.a + λ.d, λ.b - λ.c)

/--
The antipode (negating components b, c) flips the sign of the y-coordinate
while preserving the x-coordinate:
  P(S(λ)) = (x, -y) where (x, y) = P(λ)
-/
theorem covectorProjection_antipode (λ : SplitQuat) :
    covectorProjection (antipode_sq λ) = ((covectorProjection λ).1, -(covectorProjection λ).2) := by
  simp [covectorProjection, antipode_sq]

/--
The covector projection is ℤ-linear: P(λ₁ + λ₂) = P(λ₁) + P(λ₂).
-/
theorem covectorProjection_add (λ₁ λ₂ : SplitQuat) :
    covectorProjection (λ₁ + λ₂) = ((covectorProjection λ₁).1 + (covectorProjection λ₂).1,
                                    (covectorProjection λ₁).2 + (covectorProjection λ₂).2) := by
  simp [covectorProjection]

-- ============================================================================
-- SECTION 3: Tube Map Coordinate
-- ============================================================================

/--
The tube map coordinate of a tree `t` at CD step `cd`.
Convenience function combining `kktMultiplier` and `covectorProjection`.

  tubeCoord cd t = (t.size + assocDefect cd, leftWeight t - rightWeight t)

The x-coordinate is the structural size of the tree plus the associator
defect at this CD step (a measure of non-associative cost at the current
Cayley-Dickson layer). The y-coordinate is the left/right branching
asymmetry: positive for left-biased trees, negative for right-biased.
-/
def tubeCoord (cd : ℕ) (t : EMLTree) : ℤ × ℤ :=
  covectorProjection (kktMultiplier cd t)

/--
Explicit expansion of `tubeCoord` in terms of tree primitives.
-/
theorem tubeCoord_expand (cd : ℕ) (t : EMLTree) :
    tubeCoord cd t = ((t.size : ℤ) + (assocDefect cd : ℤ), (leftWeight t : ℤ) - (rightWeight t : ℤ)) := by
  simp [tubeCoord, covectorProjection, kktMultiplier]

/--
The tube coordinate of the leaf tree at any CD step.
The leaf has size 0, leftWeight 0, rightWeight 0, so:
  tubeCoord cd Leaf = (assocDefect cd, 0)
-/
theorem tubeCoord_leaf (cd : ℕ) : tubeCoord cd (.Leaf : EMLTree) = ((assocDefect cd : ℤ), 0) := by
  simp [tubeCoord, covectorProjection, kktMultiplier, leftWeight, rightWeight, EMLTree.size]

/--
The tube coordinate of a singleton node (Node Leaf Leaf) at any CD step.
  tubeCoord cd (Node Leaf Leaf) = (1 + assocDefect cd, 0)
-/
theorem tubeCoord_node_leaf_leaf (cd : ℕ) : tubeCoord cd (EMLTree.Node .Leaf .Leaf) = ((1 : ℤ) + (assocDefect cd : ℤ), 0) := by
  simp [tubeCoord, covectorProjection, kktMultiplier, leftWeight, rightWeight, EMLTree.size]

/--
The tube coordinate of a right-comb tree of size n at CD step cd.
Right-comb trees have no left branching, so leftWeight = 0 and
rightWeight grows as the triangular number n(n-1)/2.
Thus: tubeCoord cd (rightComb n) = (n + assocDefect cd, -rightWeight (rightComb n))
-/
theorem tubeCoord_rightComb (cd n : ℕ) : tubeCoord cd (rightComb n) =
    ((n : ℤ) + (assocDefect cd : ℤ), -(rightWeight (rightComb n) : ℤ)) := by
  -- For a rightComb of size n, leftWeight = 0, rightWeight = n*(n-1)/2
  -- The value of rightWeight (rightComb n) is computed layer by layer
  induction n with
  | zero =>
    simp [tubeCoord, covectorProjection, kktMultiplier, rightComb, rightWeight, leftWeight, EMLTree.size]
  | succ n ih =>
    simp [tubeCoord, covectorProjection, kktMultiplier, rightComb, rightWeight, leftWeight, EMLTree.size, ih]

-- ============================================================================
-- SECTION 4: Basic Properties
-- ============================================================================

/--
The tube coordinate of a tree depends on the CD step only through
the `assocDefect` term. For associative CD steps (cd ≤ 2), the coordinate
reduces to (t.size, leftWeight t - rightWeight t).
-/
theorem tubeCoord_assoc_step (cd : ℕ) (hcd : cd ≤ 2) (t : EMLTree) :
    tubeCoord cd t = ((t.size : ℤ), (leftWeight t : ℤ) - (rightWeight t : ℤ)) := by
  rw [tubeCoord_expand, assocDefect_zero_up_to_cd2 cd hcd]
  simp

/--
The tube coordinate at CD step 3 (non-associative regime) has an
extra `strut_weight` contribution to the x-coordinate, producing a
horizontal offset of +4 in the tube map relative to CD step 2.
This is the geometric signature of the associator phase change:
every tree at CD 3 is shifted right by 4 units (strut_weight²/strut_weight
since assocDefect 3 = strut_weight = 4).
-/
theorem tubeCoord_cd3_vs_cd2 (t : EMLTree) :
    (tubeCoord 3 t).1 = (tubeCoord 2 t).1 + (strut_weight : ℤ) := by
  rw [tubeCoord_expand, tubeCoord_expand]
  have h_sw : assocDefect 3 = strut_weight := assocDefect_positive_for_cd3plus 3 (by omega)
  have h_0 : assocDefect 2 = 0 := assocDefect_zero_up_to_cd2 2 (by omega)
  simp [h_sw, h_0]
  omega

/--
The difference in tube coordinates between two CD steps equals the
difference in their `assocDefect` values on the x-coordinate.
The y-coordinate is unchanged because it depends only on the tree
structure (leftWeight and rightWeight), not on the CD step.
-/
theorem tubeCoord_cd_diff (cd₁ cd₂ : ℕ) (t : EMLTree) :
    (tubeCoord cd₁ t).1 - (tubeCoord cd₂ t).1 = (assocDefect cd₁ : ℤ) - (assocDefect cd₂ : ℤ) := by
  rw [tubeCoord_expand, tubeCoord_expand]
  omega

/--
The tube coordinate x-component equals the tree's size plus the current
CD step's associator defect. This measures the minimum structural cost
plus the phase-change offset for non-associative layers.
-/
theorem tubeCoord_x_eq_size_plus_assocDefect (cd : ℕ) (t : EMLTree) :
    (tubeCoord cd t).1 = (t.size : ℤ) + (assocDefect cd : ℤ) := by
  rw [tubeCoord_expand]; rfl

/--
The tube coordinate y-component equals the left/right branching asymmetry.
Positive y means the tree is left-biased (more left subtrees), negative y
means right-biased (more right subtrees), zero means balanced or leaf.
-/
theorem tubeCoord_y_eq_leftWeight_sub_rightWeight (cd : ℕ) (t : EMLTree) :
    (tubeCoord cd t).2 = (leftWeight t : ℤ) - (rightWeight t : ℤ) := by
  rw [tubeCoord_expand]; rfl

end TropicalCovector
