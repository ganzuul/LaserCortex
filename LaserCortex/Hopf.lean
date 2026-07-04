/-
# Module: SplitOctonion antipode and fixed-point structure

Defines the antipode `S`, counit `ε`, and pairing `⟨S(x), y⟩` on
`SplitOctonion` over ℤ. Proves `S² = id`, linearity, fixed-point
classification, and that `S(xy) = S(y)S(x)` is false (zero divisors).

## Relations to other modules

- SplitOctonionCost.lean → `SplitOctonion`, `split_oct_mul`, `toSO`
- LiarParadox.lean → `IdentityZeroDivisor`
- AMM.lean → `AMM.reserveGuard`
-/

import Mathlib.Tactic
import LaserCortex.SplitOctonionCost
import LaserCortex.LiarParadox
import LaserCortex.AMM

open SplitOctonionCost
open LiarParadox
open EMLRegistry

namespace SplitOctonionAntipode

-- ============================================================================
-- SECTION 1: Algebraic instances on SplitOctonion
-- ============================================================================

/-- Pointwise negation on SplitOctonion. -/
def split_neg (x : SplitOctonion) : SplitOctonion :=
  ⟨-x.e0, -x.e1, -x.e2, -x.e3, -x.e4, -x.e5, -x.e6, -x.e7⟩

@[simp] theorem toVec_split_neg (x : SplitOctonion) : toVec (split_neg x) = -toVec x := by
  ext i; fin_cases i <;> rfl

instance : Neg SplitOctonion := ⟨split_neg⟩

-- These explicit instances are needed before AddCommGroup so that
-- nsmulRec and zsmulRec can resolve Zero and Add typeclasses.
instance : Add SplitOctonion := ⟨split_add⟩
instance : Zero SplitOctonion := ⟨split_zero⟩

instance : AddCommGroup SplitOctonion where
  zero := split_zero
  add := split_add
  neg := split_neg
  add_assoc := by
    intro a b c
    calc
      (a + b) + c = split_add (split_add a b) c := rfl
      _ = split_add a (split_add b c) := by
        apply SplitOctonion.ext_components <;> dsimp [split_add] <;> ring
      _ = a + (b + c) := rfl
  zero_add := by
    intro a
    calc
      0 + a = split_add split_zero a := rfl
      _ = a := by
        apply SplitOctonion.ext_components <;> dsimp [split_add, split_zero] <;> simp
  add_zero := by
    intro a
    calc
      a + 0 = split_add a split_zero := rfl
      _ = a := by
        apply SplitOctonion.ext_components <;> dsimp [split_add, split_zero] <;> simp
  add_comm := by
    intro a b
    calc
      a + b = split_add a b := rfl
      _ = split_add b a := by
        apply SplitOctonion.ext_components <;> dsimp [split_add] <;> simp [add_comm]
      _ = b + a := rfl
  neg_add_cancel := by
    intro a
    calc
      (-a) + a = split_add (split_neg a) a := rfl
      _ = split_zero := by
        apply SplitOctonion.ext_components <;> dsimp [split_add, split_neg, split_zero] <;> ring
      _ = 0 := rfl
  nsmul := nsmulRec
  nsmul_zero := by intro x; rfl
  nsmul_succ := by intro n x; rfl
  zsmul := zsmulRec
  zsmul_zero' := by intro x; rfl
  zsmul_succ' := by intro n x; rfl
  zsmul_neg' := by intro n x; rfl
  sub_eq_add_neg := by
    intro a b; rfl

/-- `SplitOctonion` has `DecidableEq` via the bijection `equivVec : SplitOctonion ≃ ℤ⁸`. -/
instance decidableEqSplitOctonion : DecidableEq SplitOctonion :=
  equivVec.decidableEq

-- ============================================================================
-- SECTION 2: The Antipode
-- ============================================================================

/-- The antipode on SplitOctonion: negates components e₁, e₂, e₃, e₅, e₆, e₇
    while fixing e₀ and e₄. -/
def antipode (x : SplitOctonion) : SplitOctonion :=
  { e0 := x.e0,
    e1 := -x.e1, e2 := -x.e2, e3 := -x.e3,
    e4 := x.e4,
    e5 := -x.e5, e6 := -x.e6, e7 := -x.e7
  }

/-- Antipode is ℤ-linear: S(x + y) = S(x) + S(y). -/
theorem antipode_add (x y : SplitOctonion) : antipode (split_add x y) = split_add (antipode x) (antipode y) := by
  apply SplitOctonion.ext_components <;> simp [antipode, split_add, add_comm]

/-- Antipode is ℤ-linear: S(-x) = -S(x). -/
theorem antipode_neg (x : SplitOctonion) : antipode (-x) = -antipode x := by
  calc
    antipode (-x) = antipode (split_neg x) := rfl
    _ = split_neg (antipode x) := by
      apply SplitOctonion.ext_components <;> dsimp [antipode, split_neg]
    _ = -antipode x := rfl

/-- The antipode is involutive: S(S(x)) = x. -/
theorem antipode_involutive (x : SplitOctonion) : antipode (antipode x) = x := by
  apply SplitOctonion.ext_components <;> simp [antipode]

/-- The antipode fixes the unit: S(1) = 1. -/
theorem antipode_one : antipode split_one = split_one := by
  apply SplitOctonion.ext_components <;> simp [antipode, split_one]

/-- The antipode is not an anti-automorphism: `S(xy) ≠ S(y)S(x)` in general.
    Counterexample: `x = e₁`, `y = e₄` (zero divisor at the CD 2→3 sector boundary). -/
theorem antipode_mul_false : ¬ (∀ x y : SplitOctonion, antipode (split_oct_mul x y) = split_oct_mul (antipode y) (antipode x)) := by
  intro h
  have hc := h e1_vec e4_vec
  -- Left side: S(e₁·e₄) = S(e₅) = -e₅
  have h_left : antipode (split_oct_mul e1_vec e4_vec) = ⟨0, 0, 0, 0, 0, -1, 0, 0⟩ := by
    ext <;> simp [e1_vec, e4_vec, antipode, split_oct_mul]
  -- Right side: S(e₄)·S(e₁) = e₄·(-e₁) = -(e₄·e₁) = -(-e₅) = e₅
  have h_right : split_oct_mul (antipode e4_vec) (antipode e1_vec) = ⟨0, 0, 0, 0, 0, 1, 0, 0⟩ := by
    ext <;> simp [e1_vec, e4_vec, antipode, split_oct_mul]
  rw [h_left, h_right] at hc
  -- hc : ⟨0,0,0,0,0,-1,0,0⟩ = ⟨0,0,0,0,0,1,0,0⟩ → -1 = 1
  have h_contra : (-1 : ℤ) = (1 : ℤ) := by
    simpa using congrArg SplitOctonion.e5 hc
  norm_num at h_contra

-- ============================================================================
-- SECTION 3: Hopf Axiom — The Antipode Pairing
-- ============================================================================

/-- The counit: projection onto the e₀ component. -/
def counit (x : SplitOctonion) : ℤ := x.e0

/-- The antipode pairing: ⟨S(x), y⟩ = (S(x) * y).e0. -/
def antipodePairing (x y : SplitOctonion) : ℤ :=
  (split_oct_mul (antipode x) y).e0

/-- The antipode pairing: ⟨S(x), x⟩ = (x*x).e0 expands to the quadratic form. -/
theorem antipode_pairing_self (x : SplitOctonion) : antipodePairing (antipode x) x =
    x.e0*x.e0 - x.e1*x.e1 - x.e2*x.e2 - x.e3*x.e3 + x.e4*x.e4 + x.e5*x.e5 + x.e6*x.e6 + x.e7*x.e7 := by
  rcases x with ⟨e0, e1, e2, e3, e4, e5, e6, e7⟩
  dsimp [antipodePairing, antipode, split_oct_mul]
  ring

/-- The copairing: (x·S(x)).e0 expands to a sum-difference form. -/
theorem antipode_copairing_self (x : SplitOctonion) : (split_oct_mul x (antipode x)).e0 =
    x.e0*x.e0 + x.e1*x.e1 + x.e2*x.e2 + x.e3*x.e3 + x.e4*x.e4 - x.e5*x.e5 - x.e6*x.e6 - x.e7*x.e7 := by
  rcases x with ⟨e0, e1, e2, e3, e4, e5, e6, e7⟩
  dsimp [antipode, split_oct_mul]
  ring

-- ============================================================================
-- SECTION 4: Antipode Fixed Point — The Zero Divisor Condition
-- ============================================================================

/-- The antipode fixed point condition: S(x) = x. -/
def isFixedPoint (x : SplitOctonion) : Prop :=
  antipode x = x

/-- Fixed points have vanishing components except possibly e₀ and e₄. -/
theorem fixed_point_components (x : SplitOctonion) (h : isFixedPoint x) :
    x.e1 = 0 ∧ x.e2 = 0 ∧ x.e3 = 0 ∧ x.e5 = 0 ∧ x.e6 = 0 ∧ x.e7 = 0 := by
  have h_eq : antipode x = x := h
  unfold antipode at h_eq
  have h_e1 := congrArg SplitOctonion.e1 h_eq
  have h_e2 := congrArg SplitOctonion.e2 h_eq
  have h_e3 := congrArg SplitOctonion.e3 h_eq
  have h_e5 := congrArg SplitOctonion.e5 h_eq
  have h_e6 := congrArg SplitOctonion.e6 h_eq
  have h_e7 := congrArg SplitOctonion.e7 h_eq
  -- From h_eq: antipode x = x with antipode expanded, each component gives -xᵢ = xᵢ
  -- Over ℤ, -a = a → 2a = 0 → a = 0 (since ℤ has no torsion).
  have h1 : x.e1 = 0 := by linarith
  have h2 : x.e2 = 0 := by linarith
  have h3 : x.e3 = 0 := by linarith
  have h5 : x.e5 = 0 := by linarith
  have h6 : x.e6 = 0 := by linarith
  have h7 : x.e7 = 0 := by linarith
  exact ⟨h1, h2, h3, h5, h6, h7⟩

/-- e₀ and e₄ are always fixed by the antipode. -/
theorem fixed_point_e0 (x : SplitOctonion) : (antipode x).e0 = x.e0 := by
  simp [antipode]

theorem fixed_point_e4 (x : SplitOctonion) : (antipode x).e4 = x.e4 := rfl

-- ============================================================================
-- SECTION 5: Connection to IdentityZeroDivisor
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
-- SECTION 6: Connection to AMM Reserve Guard
-- ============================================================================

/-- The claim that antipode fixed points always trigger the AMM reserve guard
    is FALSE. The reserve guard `Φ L tree ≥ pool.reserveB` depends on the tree's
    cost and the pool's reserve, neither of which is forced by the antipode
    fixed point condition alone.

    Counterexample: `pool := ⟨1, 1, …⟩` (reserveB = 1), `tree := .Leaf` (cost 0),
    `x := split_one` (antipode fixed point, counit = 1). Then
    `Φ L .Leaf = 0 < 1 = pool.reserveB`, so `¬ reserveGuard pool L tree`.

    This is a sector-boundary guard: the antipode fixed point condition
    (S(x) = x, ε(x) = 1) forces x into the associative sector (e₀ = 1,
    all other components 0 except possibly e₄), but does not constrain
    the cost of an arbitrary tree under that x. The Hopf algebra failure
    (zero divisors at CD 2→3) means the cost function Φ cannot be linked
    to the antipode pairing, so the reserve guard cannot be derived from
    algebraic fixed-point properties alone.
-/
theorem antipode_fixed_point_reserves_pool_false :
    ¬ (∀ (pool : AMM.Pool) (L : LogicTypes.LogicType) (tree : EMLTree)
        (x : SplitOctonion), antipode x = x → counit x = 1 → AMM.reserveGuard pool L tree) := by
  intro h
  -- Construct a counterexample pool with reserveB = 1
  let pool : AMM.Pool := ⟨1, 1, by decide, by decide⟩
  let L : LogicTypes.LogicType := LogicTypes.LogicType.Intuitionistic
  let tree : EMLTree := .Leaf
  let x : SplitOctonion := split_one
  have h_fixed : antipode x = x := antipode_one
  have h_counit : counit x = 1 := by
    dsimp [x, counit, split_one]
  have h_guard := h pool L tree x h_fixed h_counit
  -- h_guard : AMM.reserveGuard pool L tree, i.e. Cost.Φ L tree ≥ pool.reserveB
  -- Cost.Φ L .Leaf = 0, pool.reserveB = 1, so 0 ≥ 1, contradiction
  simp [AMM.reserveGuard, Cost.Φ, pool, tree] at h_guard

-- ============================================================================
-- SECTION 7: Antipode Preserves the (4,4) Norm (Born Rule Extension)
-- ============================================================================

/-- The quadratic norm is antipode-invariant: `octonion_norm(S(x)) = octonion_norm(x)`.
    Proof: the antipode negates six components and fixes two; squaring makes
    each term unchanged since `(-a)² = a²` over ℤ. -/
theorem antipode_preserves_norm (x : SplitOctonion) : octonion_norm (antipode x) = octonion_norm x := by
  calc
    octonion_norm (antipode x) = (antipode x).e0 * (antipode x).e0 + (antipode x).e1 * (antipode x).e1 +
      (antipode x).e2 * (antipode x).e2 + (antipode x).e3 * (antipode x).e3 -
      (antipode x).e4 * (antipode x).e4 - (antipode x).e5 * (antipode x).e5 -
      (antipode x).e6 * (antipode x).e6 - (antipode x).e7 * (antipode x).e7 := rfl
    _ = x.e0 * x.e0 + (-x.e1) * (-x.e1) + (-x.e2) * (-x.e2) + (-x.e3) * (-x.e3) -
      x.e4 * x.e4 - (-x.e5) * (-x.e5) - (-x.e6) * (-x.e6) - (-x.e7) * (-x.e7) := by
      simp [antipode]
    _ = x.e0 * x.e0 + x.e1 * x.e1 + x.e2 * x.e2 + x.e3 * x.e3 -
      x.e4 * x.e4 - x.e5 * x.e5 - x.e6 * x.e6 - x.e7 * x.e7 := by ring
    _ = octonion_norm x := rfl

end SplitOctonionAntipode
