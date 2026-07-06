/-
# Module: SubdivisionClosure

## Intent

The **regular subdivision closure** of a binary tree at a given Cayley–Dickson
step. The closure of a tree `t` is its right-comb normal form `rightComb t.size`
(the fan triangulation of the associahedron), and the weighted cost to reach it is

    Γ_cd(t) = dcStep(t) × frictionDensity(cd)

This replaces the earlier `InstitutionalClosure.lean` which wrapped the same
combinatorial structure in an institutional metaphor. The actual mathematical
content is:

- **Tamari lattice** = the poset of regular triangulations of a convex polygon,
  with `contracts_one` as the diagonal flip (covering relation).
- **Friction density** = the cost per flip, which depends on the CD step.
- **Closure** = contracting to the right-comb (fan triangulation), the unique
  minimum of the Tamari poset.
- **Phase change at CD 2→3** = `assocDefect` activates when the split octonion
  layer appears, increasing the per-flip cost by `strut_weight²`.

The "fuzzy grade" of the old pipeline (`fuzzyGradeByCdStep`) is now the
straightforward product `dcStep t × frictionDensity cd`. The "self-recognition"
is the idempotence of the right-comb fixed point. The "temporal normalization"
is the Tamari poset itself — no separate ordering needed.

## Contracts

- `weightedCost` : ℕ → EMLTree → ℕ — total weighted flip cost to rightComb
- `closure` : ℕ → EMLTree → EMLTree — contract to right-comb normal form
- `closure_idempotent` : closure at a fixed point is zero-cost
- `weightedCost_assoc_regime` / `weightedCost_nonassoc_regime` : phase change at CD 2→3
- `weightedCost_eq_zero_iff` : zero cost (at positive friction density) iff already in normal form
- `contracts_to_closure` : every tree contracts to its closure in the Tamari lattice

## Cross-refs

- `staging/Tamari` — `dcStep`, `rightComb`, `contracts_to_rightComb`
- `staging/Friction` — `frictionDensity`, `assocDefect`, `commDefect`
- `staging/Algebra` — `strut_weight`, `SplitOctonion`, `SplitQuat`
- `lab_notes/031_ic_is_regular_subdivision.md`

## Tags

#lean4-theorem #subdivision #associahedron #tamari #weighted-cost
-/

import LaserCortex.staging.Tamari
import LaserCortex.staging.Friction

open EMLTree

namespace SubdivisionClosure

-- ============================================================================
-- Weighted cost to closure
-- ============================================================================

/-- The weighted cost of the full contraction path for a tree `t`
    at Cayley–Dickson step `cd`:

        Γ_cd(t) = dcStep(t) × frictionDensity(cd)

    This is the total number of diagonal flips (`dcStep(t)`) each weighted
    by the per-flip cost at this CD step. At cdStep ≤ 2 (associative regime)
    the cost per flip is just `cdStep`; at cdStep ≥ 3 the cost per flip
    jumps by `strut_weight²`.

    This replaces the earlier `fuzzyGradeByCdStep` formula. It is the
    "friction" that must be overcome to reach the unique normal form. -/
def weightedCost (cd : ℕ) (t : EMLTree) : ℕ :=
  dcStep t * frictionDensity cd

/-- The closure of a tree `t` at CD step `_cd` is its right-comb normal form:

        closure _cd t = rightComb t.size

    This is the unique minimum of the Tamari poset (fan triangulation).
    The weighted cost to reach it is `weightedCost cd t`.
    
    The CD step parameter is accepted for API consistency with `weightedCost`,
    but the closure itself (the right-comb normal form) depends only on the
    tree's size, not on the CD step. -/
def closure (_cd : ℕ) (t : EMLTree) : EMLTree :=
  rightComb t.size

-- ============================================================================
-- Basic theorems
-- ============================================================================

/-- A tree in right-comb normal form has zero dcStep. -/
theorem dcStep_closure (cd : ℕ) (t : EMLTree) : dcStep (closure cd t) = 0 := by
  simp [closure, dcStep_rightComb]

/-- The weighted cost to reach closure from an already-closed tree is zero:
    once you are at the rightComb, there are no flips left to perform. -/
theorem weightedCost_closure (cd : ℕ) (t : EMLTree) : weightedCost cd (closure cd t) = 0 := by
  simp [weightedCost, dcStep_closure]

/-- The size of a right-comb tree. -/
theorem rightComb_size (n : ℕ) : (rightComb n).size = n := by
  induction n with
  | zero => simp [rightComb, EMLTree.size]
  | succ n ih =>
    simp [rightComb, EMLTree.size, ih]
    omega

/-- Closure is idempotent: applying closure to an already-closed tree
    returns the same tree. The right-comb is the unique fixed point of
    the contraction relation. -/
theorem closure_idempotent (cd : ℕ) (t : EMLTree) : closure cd (closure cd t) = closure cd t := by
  simp [closure, rightComb_size]

/-- A tree at closure (rightComb) has zero weighted cost at any CD step.
    This is the trivial direction: closure → zero cost. -/
theorem weightedCost_eq_zero_of_isRightComb (cd : ℕ) (t : EMLTree) (h : isRightComb t) :
    weightedCost cd t = 0 := by
  rw [isRightComb_iff_dcStep_zero] at h
  simp [weightedCost, h]

/-- If a tree has zero weighted cost at a CD step with positive friction density,
    then it must already be a rightComb (closure). The converse also holds.
    
    The condition `frictionDensity cd ≠ 0` is necessary because at cd = 0,
    the friction density is zero and all costs are zero regardless of tree shape. -/
theorem weightedCost_eq_zero_iff (cd : ℕ) (t : EMLTree) (hf : frictionDensity cd ≠ 0) :
    weightedCost cd t = 0 ↔ isRightComb t := by
  constructor
  · intro h
    dsimp [weightedCost] at h
    rcases eq_zero_or_eq_zero_of_mul_eq_zero h with hdc | hfric
    · rw [isRightComb_iff_dcStep_zero]
      exact hdc
    · exfalso; exact hf hfric
  · intro h
    rw [isRightComb_iff_dcStep_zero] at h
    simp [weightedCost, h]

-- ============================================================================
-- Phase change theorem
-- ============================================================================

/-- In the associative regime (cdStep ≤ 2), the weighted cost reduces to
    `cd × dcStep(t)` because `assocDefect = 0`:

        Γ_cd(t) = cd × dcStep(t)    for cd ≤ 2

    At these CD steps (ℝ, ℂ, ℍ, Cl(1,1)), the CD doubling identity holds for
    all base-pair arguments and the associator carries no independent cost. -/
theorem weightedCost_assoc_regime (cd : ℕ) (t : EMLTree) (hcd : cd ≤ 2) :
    weightedCost cd t = cd * dcStep t := by
  dsimp [weightedCost]
  rw [frictionDensity_eq_k_for_k_le_2 cd hcd, Nat.mul_comm]

/-- In the non-associative regime (cdStep ≥ 3), the weighted cost has an
    extra `strut_weight²` contribution per flip:

        Γ_cd(t) = (cd + strut_weight²) × dcStep(t)    for cd ≥ 3

    The extra cost comes from `assocDefect = strut_weight = 4`, which
    activates when the split octonion layer appears. The CD doubling
    identity fails for mixed base/split arguments at these CD steps,
    producing genuine non-associativity. The associator contributes
    `strut_weight² = 16` per flip on top of the commutator cost `cd`. -/
theorem weightedCost_nonassoc_regime (cd : ℕ) (t : EMLTree) (hcd : 3 ≤ cd) :
    weightedCost cd t = (cd + strut_weight * strut_weight) * dcStep t := by
  dsimp [weightedCost]
  rw [frictionDensity_eq_k_plus_16_for_k_ge_3 cd hcd, strut_weight_eq_four]
  ring

/-- The weighted cost is monotone in the CD step: increasing the CD step
    cannot decrease the cost for any tree.
    
    For strict inequality (cd₁ < cd₂), the friction density is strictly
    greater. For equality, trivially equal. -/
theorem weightedCost_monotone (cd₁ cd₂ : ℕ) (t : EMLTree) (h : cd₁ ≤ cd₂) :
    weightedCost cd₁ t ≤ weightedCost cd₂ t := by
  rcases Nat.eq_or_lt_of_le h with (rfl | hlt)
  · rfl
  · dsimp [weightedCost]
    have hfric : frictionDensity cd₁ ≤ frictionDensity cd₂ :=
      frictionDensity_monotone cd₁ cd₂ hlt
    exact Nat.mul_le_mul (Nat.le_refl _) hfric

-- ============================================================================
-- Relationship to the contraction path
-- ============================================================================

/-- Every tree `t` contracts to its closure under the Tamari contraction
    relation. This is a re-export of the fundamental theorem from `staging/Tamari`. -/
theorem contracts_to_closure (t : EMLTree) : contracts_to t (closure 0 t) := by
  have h : contracts_to t (rightComb t.size) := contracts_to_rightComb t
  simpa [closure] using h

end SubdivisionClosure
