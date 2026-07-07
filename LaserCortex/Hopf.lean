/-
# Module: SplitOctonion antipode — unique theorems

## Intent

Connections from the antipode fixed-point structure to:
1. The identity zero divisor paradox (LiarParadox.lean)
2. The AMM reserve guard (AMM.lean)

The algebraic foundation (SplitOctonion, antipode, counit, fixed-point
classification, norm preservation) is in `staging/Algebra.lean`, which
is the canonical source. This module adds only the cross-layer theorems
that link the algebra to the paradox and the market.

## Relations to other modules

- foundations/Algebra.lean → `SplitOctonion`, `antipode`, `counit`, `isFixedPoint`
- ParadoxAxioms.lean → `IdentityZeroDivisor`
- AMM.lean → `AMM.Pool`, `AMM.reserveGuard`
- SubdivisionClosure.lean → `weightedCost`
- foundations/Tamari.lean → `EMLTree`, `dcStep`
-/

import LaserCortex.foundations.Algebra
import LaserCortex.ParadoxAxioms
import LaserCortex.AMM

open Algebra
open ParadoxAxioms
open EMLTree

namespace SplitOctonionAntipode

-- ============================================================================
-- SECTION 1: Connection to LiarParadox
-- ============================================================================

/-- The identity zero divisor (from LiarParadox.lean) forces `(2 : ℤ) = 0`. -/
theorem identity_zero_divisor_forces_char2 {α : Type} (h_zd : IdentityZeroDivisor α) : (2 : ℤ) = 0 := by
  have h_contra := identity_zero_divisor_contradiction h_zd
  exact h_contra.elim

/-- The identity zero divisor forces any antipode fixed point with unit counit
    to be zero (vacuously true in ℤ since `2 = 0` is impossible). -/
theorem identity_zero_divisor_annihilates_cost {α : Type} (h_zd : IdentityZeroDivisor α) 
    (_x : SplitOctonion) (_h_fixed : antipode _x = _x) (_h_counit : counit _x = 1) :
    _x = split_zero := by
  -- From the identity zero divisor, we deduce (2 : ℤ) = 0 (impossible), giving a contradiction.
  -- The conclusion `x = split_zero` is vacuously true.
  have h_2_eq_0 := identity_zero_divisor_forces_char2 h_zd
  exfalso
  have h_2_ne_0 : (2 : ℤ) ≠ 0 := by norm_num
  exact h_2_ne_0 h_2_eq_0

-- ============================================================================
-- SECTION 2: Connection to AMM Reserve Guard
-- ============================================================================

/-- The claim that antipode fixed points always trigger the AMM reserve guard
    is FALSE. The reserve guard `SubdivisionClosure.weightedCost cd tree ≥ pool.reserveB`
    depends on the tree's cost and the pool's reserve, neither of which is forced by
    the antipode fixed point condition alone.

    Counterexample: `cd := 0`, `pool := ⟨1, 1, …⟩` (reserveB = 1),
    `tree := .Leaf` (cost 0), `x := split_one` (antipode fixed point,
    counit = 1). Then `SubdivisionClosure.weightedCost 0 .Leaf = 0 < 1 = pool.reserveB`,
    so `¬ reserveGuard 0 pool .Leaf`.

    This is a sector-boundary guard: the antipode fixed point condition
    (S(x) = x, ε(x) = 1) forces x into the associative sector (e₀ = 1,
    all other components 0 except possibly e₄), but does not constrain
    the cost of an arbitrary tree under that x. The Hopf algebra failure
    (zero divisors at CD 2→3) means the weighted cost cannot be linked
    to the antipode pairing, so the reserve guard cannot be derived from
    algebraic fixed-point properties alone.
-/
theorem antipode_fixed_point_reserves_pool_false :
    ¬ (∀ (cd : ℕ) (pool : AMM.Pool) (tree : EMLTree)
        (x : SplitOctonion), antipode x = x → counit x = 1 → AMM.reserveGuard cd pool tree) := by
  intro h
  -- Construct a counterexample: cd=0, pool with reserveB = 1, tree = .Leaf
  let cd : ℕ := 0
  let pool : AMM.Pool := ⟨1, 1, by decide, by decide⟩
  let tree : EMLTree := .Leaf
  let x : SplitOctonion := split_one
  have h_fixed : antipode x = x := antipode_one
  have h_counit : counit x = 1 := by
    dsimp [x, counit, split_one]
  have h_guard := h cd pool tree x h_fixed h_counit
  -- h_guard : AMM.reserveGuard 0 pool .Leaf, i.e. weightedCost 0 .Leaf ≥ pool.reserveB
  -- weightedCost 0 .Leaf = 0, pool.reserveB = 1, so 0 ≥ 1, contradiction
  simp [AMM.reserveGuard, SubdivisionClosure.weightedCost, dcStep, pool, tree, cd] at h_guard

end SplitOctonionAntipode
