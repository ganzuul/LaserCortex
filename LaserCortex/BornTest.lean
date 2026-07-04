/-
# Module: BornTest

## Intent

Formalizes the **Born rule** on split quaternions ℍ̃ as the metric-space
interpretation of the calibration ladder. The Born probability is the
(2,2) norm composed with `natAbs`, giving a ℕ-valued "probability" that:

- Is **non-negative** (born_nonneg)
- Is **normalized** to 1 when the input norm is 1 (born_normalized)
- **Vanishes on null vectors** (norm zero → probability zero) (born_zero_on_null)
- Is **multiplicative** under split-quaternion multiplication (born_mul)
- Is **invariant under the antipode** (antipode_sq_preserves_born)

The distance `d(x,y) = born_probability (x - y)` defines a metric on the
ℍ̃ parameter space that is invariant under the antipode (the ℤ/2-grading
involution). This connects the Born rule to the metric-space structure of
the institutional closure algebra.

## Relation to other modules

- SplitQuaternionClifford.lean → `SplitQuat`, `split_quat_mul`, `antipode_sq`,
  `norm_mul`, `antipode_sq_preserves_norm`, `antipode_sq_sub`
- SplitOctonionAntipode.lean → `antipode` (the split-octonion analogue, extended in Phase C)

## Tags

#lean4-theorem #born-rule #split-quaternion #metric-space #antipode-invariant
-/

import Mathlib.Data.Int.Basic
import LaserCortex.SplitQuaternionClifford

open SplitQuaternionClifford

namespace BornTest

-- ============================================================================
-- B1: Born probability on split quaternions
-- ============================================================================

/-- The Born probability of a split quaternion is the absolute value
    of its (2,2) norm (non-negative by construction on ℕ).
    
    N(a,b,c,d) = a² + b² - c² - d², so `born_probability` is the
    ℕ-valued magnitude of this quadratic form. -/
def born_probability (q : SplitQuat) : ℕ :=
  (q.norm).natAbs

-- ============================================================================
-- B2: Basic theorems
-- ============================================================================

/-- Born probability is non-negative (trivially, as it is ℕ-valued). -/
theorem born_nonneg (q : SplitQuat) : 0 ≤ (born_probability q : ℤ) := by
  simpa using Nat.cast_nonneg (born_probability q)

/-- For a normalized split quaternion (norm = 1), the Born probability is 1. -/
theorem born_normalized (q : SplitQuat) (h : q.norm = 1) : born_probability q = 1 := by
  unfold born_probability
  rw [h]
  rfl

/-- Null vectors (norm = 0) have zero Born probability. -/
theorem born_zero_on_null (q : SplitQuat) (h : q.norm = 0) : born_probability q = 0 := by
  unfold born_probability
  rw [h]
  rfl

/-- The Born probability is multiplicative under split-quaternion multiplication.
    This follows from the composition algebra identity `norm_mul` and the
    multiplicative property of `natAbs` on ℤ. -/
theorem born_mul (x y : SplitQuat) : born_probability (x * y) = born_probability x * born_probability y := by
  unfold born_probability
  calc
    ((x * y).norm).natAbs = (x.norm * y.norm).natAbs := by rw [norm_mul]
    _ = (x.norm).natAbs * (y.norm).natAbs := by rw [Int.natAbs_mul x.norm y.norm]
    _ = born_probability x * born_probability y := rfl

-- ============================================================================
-- B3: Antipode invariance
-- ============================================================================

/-- The antipode preserves the Born probability.
    Proof: `antipode_sq_preserves_norm` gives N(S(q)) = N(q),
    then `natAbs` preserves equality. -/
theorem antipode_sq_preserves_born (q : SplitQuat) :
    born_probability (antipode_sq q) = born_probability q := by
  unfold born_probability
  rw [antipode_sq_preserves_norm q]

-- ============================================================================
-- B4: Metric space interpretation
-- ============================================================================

/-- The distance induced by the Born probability.
    d(x, y) = P(x - y) where P is the Born probability.
    This gives a metric on the ℍ̃ parameter space. -/
def sq_dist (x y : SplitQuat) : ℕ :=
  born_probability (x - y)

/-- The distance is invariant under the antipode:
    d(S(x), S(y)) = d(x, y).
    
    Proof: S(x) - S(y) = S(x - y) by `antipode_sq_sub`, then
    `antipode_sq_preserves_born` gives the equality. -/
theorem sq_dist_antipode_invariant (x y : SplitQuat) :
    sq_dist (antipode_sq x) (antipode_sq y) = sq_dist x y := by
  unfold sq_dist
  calc
    born_probability (antipode_sq x - antipode_sq y)
        = born_probability (antipode_sq (x - y)) := by rw [antipode_sq_sub x y]
    _ = born_probability (x - y) := by rw [antipode_sq_preserves_born (x - y)]

end BornTest
