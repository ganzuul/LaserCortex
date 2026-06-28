/-
# Module: SplitOctonionCost

## Intent

Formalizes the split-octonion engine as a **dynamical system** whose state
projects onto the `NodeCost` cost algebra. The core algebra (64-term
multiplication, associator, pentagon defect) is computed over core Lean
(`Int`, `Nat`, `by decide`). Mathlib's `QuadraticForm` is imported at the
integration point `Q44` to connect the hand-verified (4,4) norm to the
standard diagonal quadratic form — establishing that our norm was always
the canonical `QuadraticMap.proj` sum.

Key achievements:
1. The (4,4) split-octonion algebra with 64-term multiplication over Int (COMPUTED)
2. Concrete verification: `strut_weight = 4` for the cross-boundary triple (e₁, e₂, e₄)
3. Pentagon defect bounded by 10 (COMPUTED, not axiomatic)
4. `branch_lightening` theorem: positive debt reduces weight (non-strict decrease)
5. `ConcreteReactionlessShift`: fully verified budget instantiation (no axioms)
6. `engine_to_nodecost` projection: EngineState → NodeCost (dynamical system)
7. `Q44`: Mathlib `QuadraticForm ℤ (Fin 8 → ℤ)` matching `octonion_norm` (integration point)

## Contracts

[SplitOctonion, split_oct_mul, octonion_norm, associator_tensor, pentagon_defect,
strut_weight_eq_four, pentagon_defect_bound, NonAssociativeBudget,
branch_lightening, ConcreteReactionlessShift, EngineState, engine_to_nodecost,
Q44, octonion_norm', octonion_norm_eq_Q44]

## Cross-refs

LaserCortex.Cost → NodeCost, Φ, nodeParam, LogicTypes; LaserCortex.EMLRegistry → EMLTree
Mathlib.QuadraticForm → QuadraticForm, QuadraticMap.proj, QuadraticMap.Isotropic

## Invariants

The associator norm for (e₁, e₂, e₄) is known: `octonion_norm = -4`, `abs = 4`.
The pentagon defect for (e₁, e₂, e₄, e₁) is bounded by 10.
branch_lightening: positive debt reduces weight (≤ initial_weight).
`Q44` and `octonion_norm` agree on all `SplitOctonion` inputs.

## Tags

#lean4-theorem #split-octonion #engine #proof-bound #dynamical-system #integration-point
-/

import Init
import Mathlib.Tactic
import LaserCortex.Cost
import LaserCortex.EMLRegistry
import Mathlib.LinearAlgebra.QuadraticForm.Basic

namespace SplitOctonionCost

-- ============================================================================
-- LAYER 1: THE SPLIT-OCTONION TYPE AND ALGEBRA (over ℤ)
-- ============================================================================

/-- A split-octonion with (4,4) signature over ℤ.
    e₀ is the scalar, e₁-e₃ are the associative (quaternionic) sector,
    e₄-e₇ are the split (non-associative) sector.
    The quadratic form has signature (++++----). -/
structure SplitOctonion where
  e0 : Int
  e1 : Int
  e2 : Int
  e3 : Int
  e4 : Int
  e5 : Int
  e6 : Int
  e7 : Int
  deriving Repr

-- The zero and one elements
def split_zero : SplitOctonion := ⟨0, 0, 0, 0, 0, 0, 0, 0⟩
def split_one : SplitOctonion := ⟨1, 0, 0, 0, 0, 0, 0, 0⟩

/-- Convert a SplitOctonion to a vector in ℤ⁸ (Fin 8 → ℤ). -/
def toVec (x : SplitOctonion) : Fin 8 → ℤ := λ
  | 0 => x.e0 | 1 => x.e1 | 2 => x.e2 | 3 => x.e3
  | 4 => x.e4 | 5 => x.e5 | 6 => x.e6 | 7 => x.e7

/-- Convert a vector in ℤ⁸ back to a SplitOctonion. -/
def ofVec (v : Fin 8 → ℤ) : SplitOctonion :=
  { e0 := v 0, e1 := v 1, e2 := v 2, e3 := v 3,
    e4 := v 4, e5 := v 5, e6 := v 6, e7 := v 7 }

@[simp] theorem toVec_ofVec (v : Fin 8 → ℤ) : toVec (ofVec v) = v := by
  ext i; fin_cases i <;> rfl

@[simp] theorem ofVec_toVec (x : SplitOctonion) : ofVec (toVec x) = x := by
  cases x; rfl

/-- The bijection SplitOctonion ≃ ℤ⁸ (as sets). -/
def equivVec : SplitOctonion ≃ (Fin 8 → ℤ) :=
  { toFun := toVec
    invFun := ofVec
    left_inv := ofVec_toVec
    right_inv := toVec_ofVec
  }

-- ============================================================================
-- LAYER 2: THE 64-TERM MULTIPLICATION TABLE (Cayley-Dickson construction)
-- ============================================================================
-- This is the full (4,4) split-octonion multiplication over ℤ.

def split_oct_mul (x y : SplitOctonion) : SplitOctonion :=
  ⟨
    -- e0 (scalar/real part)
    x.e0*y.e0 - x.e1*y.e1 - x.e2*y.e2 - x.e3*y.e3 + x.e4*y.e4 + x.e5*y.e5 + x.e6*y.e6 + x.e7*y.e7,
    -- e1
    x.e0*y.e1 + x.e1*y.e0 + x.e2*y.e3 - x.e3*y.e2 - x.e4*y.e5 + x.e5*y.e4 + x.e6*y.e7 - x.e7*y.e6,
    -- e2
    x.e0*y.e2 - x.e1*y.e3 + x.e2*y.e0 + x.e3*y.e1 - x.e4*y.e6 - x.e5*y.e7 + x.e6*y.e4 + x.e7*y.e5,
    -- e3
    x.e0*y.e3 + x.e1*y.e2 - x.e2*y.e1 + x.e3*y.e0 - x.e4*y.e7 + x.e5*y.e6 - x.e6*y.e5 + x.e7*y.e4,
    -- e4 (split boundary)
    x.e0*y.e4 + x.e4*y.e0 - x.e1*y.e5 + x.e5*y.e1 - x.e2*y.e6 + x.e6*y.e2 - x.e3*y.e7 + x.e7*y.e3,
    -- e5
    x.e0*y.e5 + x.e5*y.e0 + x.e1*y.e4 - x.e4*y.e1 - x.e2*y.e7 + x.e7*y.e2 + x.e3*y.e6 - x.e6*y.e3,
    -- e6
    x.e0*y.e6 + x.e6*y.e0 + x.e2*y.e4 - x.e4*y.e2 + x.e1*y.e7 - x.e7*y.e1 - x.e3*y.e5 + x.e5*y.e3,
    -- e7
    x.e0*y.e7 + x.e7*y.e0 + x.e3*y.e4 - x.e4*y.e3 - x.e1*y.e6 + x.e6*y.e1 + x.e2*y.e5 - x.e5*y.e2
  ⟩

-- Addition
def split_add (x y : SplitOctonion) : SplitOctonion :=
  ⟨x.e0+y.e0, x.e1+y.e1, x.e2+y.e2, x.e3+y.e3, x.e4+y.e4, x.e5+y.e5, x.e6+y.e6, x.e7+y.e7⟩

-- Subtraction (needed for associator)
def split_sub (x y : SplitOctonion) : SplitOctonion :=
  ⟨x.e0-y.e0, x.e1-y.e1, x.e2-y.e2, x.e3-y.e3, x.e4-y.e4, x.e5-y.e5, x.e6-y.e6, x.e7-y.e7⟩

@[simp] theorem toVec_split_add (x y : SplitOctonion) : toVec (split_add x y) = toVec x + toVec y := by
  ext i; fin_cases i <;> rfl

@[simp] theorem toVec_split_zero : toVec (split_zero : SplitOctonion) = 0 := by
  ext i; fin_cases i <;> rfl

-- ============================================================================
-- LAYER 3: NORM, ASSOCIATOR, PENTAGON
-- ============================================================================

/-- The isotropic quadratic form with (4,4) signature over ℤ.
    First four dimensions are positive (associative/quaternionic),
    last four are negative (split/non-associative). -/
def octonion_norm (x : SplitOctonion) : Int :=
  x.e0*x.e0 + x.e1*x.e1 + x.e2*x.e2 + x.e3*x.e3 - x.e4*x.e4 - x.e5*x.e5 - x.e6*x.e6 - x.e7*x.e7

-- ============================================================================
-- MATHLIB INTEGRATION POINT: QuadraticForm (4,4)
-- ============================================================================
-- Q44 below is deliberately kept alongside the hand-written octonion_norm.
-- It is NOT dead code — it documents the connection between our framework
-- and Mathlib's QuadraticForm library. The two definitions are provably
-- equal, giving us access to:
--   • QuadraticMap.Isotropic     — isotropic vectors and null cone
--   • QuadraticForm.Signature    — formal (4,4) signature analysis
--   • QuadraticForm.discriminant — discriminant of the norm form
--   • QuadraticForm.anisotropic  — anisotropy / isotropy classification
-- The hand-written octonion_norm remains because it works with `by decide`
-- for direct basis-element computation. Q44 extends this to the full
-- Mathlib quadratic forms toolkit.
-- ============================================================================

open QuadraticMap

/-- The (4,4) quadratic form as a Mathlib `QuadraticForm ℤ (Fin 8 → ℤ)`.
    ++++---- signature, matching octonion_norm exactly. -/
def Q44 : QuadraticForm ℤ (Fin 8 → ℤ) :=
  proj 0 0 + proj 1 1 + proj 2 2 + proj 3 3
  - proj 4 4 - proj 5 5 - proj 6 6 - proj 7 7

/-- octonion_norm as a QuadraticForm evaluation.
    Bridges our structure to Mathlib's type system. -/
def octonion_norm' (x : SplitOctonion) : ℤ :=
  Q44 ![x.e0, x.e1, x.e2, x.e3, x.e4, x.e5, x.e6, x.e7]

/-- The two norm definitions agree.
    This theorem establishes the integration point: the (4,4) form we
    compute manually is exactly the standard diagonal quadratic form
    over ℤ in the Mathlib sense. -/
theorem octonion_norm_eq_Q44 (x : SplitOctonion) : octonion_norm x = octonion_norm' x := by
  simp [Q44, octonion_norm, octonion_norm', QuadraticMap.proj_apply]

/-- The associator: (a*b)*c - a*(b*c).
    Measures local non-associativity. -/
def associator_tensor (a b c : SplitOctonion) : SplitOctonion :=
  split_sub (split_oct_mul (split_oct_mul a b) c) (split_oct_mul a (split_oct_mul b c))

/-- The pentagon defect (Mac Lane pentagon identity evaluation).
    For split-octonions it measures the failure of pentagon coherence. -/
def pentagon_defect (a b c d : SplitOctonion) : SplitOctonion :=
  split_add (split_sub (split_sub (split_add
    (split_oct_mul (associator_tensor a b c) d)
    (split_oct_mul (associator_tensor a b c) d))
    (associator_tensor (split_oct_mul a b) c d))
    (associator_tensor a (split_oct_mul b c) d))
    (split_sub (split_oct_mul a (associator_tensor b c d)) (associator_tensor a b (split_oct_mul c d)))

-- ============================================================================
-- LAYER 4: CONCRETE BASIS VECTORS
-- ============================================================================

def e0_vec : SplitOctonion := ⟨1, 0, 0, 0, 0, 0, 0, 0⟩
def e1_vec : SplitOctonion := ⟨0, 1, 0, 0, 0, 0, 0, 0⟩
def e2_vec : SplitOctonion := ⟨0, 0, 1, 0, 0, 0, 0, 0⟩
def e3_vec : SplitOctonion := ⟨0, 0, 0, 1, 0, 0, 0, 0⟩
def e4_vec : SplitOctonion := ⟨0, 0, 0, 0, 1, 0, 0, 0⟩
def e5_vec : SplitOctonion := ⟨0, 0, 0, 0, 0, 1, 0, 0⟩
def e6_vec : SplitOctonion := ⟨0, 0, 0, 0, 0, 0, 1, 0⟩
def e7_vec : SplitOctonion := ⟨0, 0, 0, 0, 0, 0, 0, 1⟩

/-- The tensegrity strut: the associator at (e₁, e₂, e₄).
    This is the basic geometric "strut" that generates curvature. -/
def tensegrity_strut : SplitOctonion :=
  associator_tensor e1_vec e2_vec e4_vec

/-- The norm of the tensegrity strut over ℤ.
    octonion_norm(assoc(e₁,e₂,e₄)) = -4.
    We take the absolute value for the strut_weight (positive 4). -/
def strut_weight : Nat :=
  (-octonion_norm tensegrity_strut).toNat

/-- The strut_weight is 4, verified by computation.
    The associator (e₁, e₂, e₄) = 2·e₇, with norm -4.
    `-norm = 4`, `(-norm).toNat = 4`. -/
theorem strut_weight_eq_four : strut_weight = 4 := by
  unfold strut_weight tensegrity_strut associator_tensor
  unfold e1_vec e2_vec e4_vec
  unfold split_sub split_oct_mul
  decide

/-- The pentagon defect for (e₁, e₂, e₄, e₁) is bounded by 10.
    This is a theorem (not an axiom). -/
theorem pentagon_defect_bound : (octonion_norm (pentagon_defect e1_vec e2_vec e4_vec e1_vec)).natAbs ≤ 10 := by
  unfold pentagon_defect associator_tensor e1_vec e2_vec e4_vec
  unfold split_sub split_add split_oct_mul octonion_norm
  decide

/-- The strut_weight is ≤ 10 (trivial since 4 ≤ 10). -/
theorem budget_constraint : strut_weight ≤ 10 := by
  rw [strut_weight_eq_four]
  decide

-- ============================================================================
-- LAYER 5: THE ENGINE STATE (NON-ASSOCIATIVE BUDGET)
-- ============================================================================

/-- Amortization constant: translates logical debt into anti-inertia. -/
def kappa_constant : Nat := 1

/-- The engine's budget structure: couples the local associator debt to
    a macroscopic capacity (pentagon defect bound), with amortization.

    All fields are Nat for compatibility with Cost.lean. -/
structure NonAssociativeBudget where
  local_residue : Nat
  max_capacity : Nat
  h_capacity_pos : max_capacity > 0
  h_pentagon_bound : local_residue ≤ max_capacity

/-- Compute the amortization (debt relief) from the local residue. -/
def compute_amortization (budget : NonAssociativeBudget) : Nat :=
  kappa_constant * budget.local_residue

/-- One step of the reactionless shift: reduce weight by the amortization.
    Because Nat subtraction saturates at 0, the weight never goes below 0. -/
def reactionless_step (current_weight : Nat) (budget : NonAssociativeBudget) : Nat :=
  current_weight - compute_amortization budget

-- ============================================================================
-- LAYER 6: THEOREMS
-- ============================================================================

/-- BRANCH LIGHTENING THEOREM (non-strict).
    The reactionless step always reduces or maintains the weight
    (Nat subtraction is monotone). -/
theorem branch_lightening_nonstrict (initial_weight : Nat) (budget : NonAssociativeBudget) :
    reactionless_step initial_weight budget ≤ initial_weight := by
  unfold reactionless_step compute_amortization kappa_constant
  -- After unfolding: initial_weight - (1 * budget.local_residue) ≤ initial_weight
  -- We need to simplify 1 * r to r
  have h_simp : initial_weight - (1 * budget.local_residue) = initial_weight - budget.local_residue := by
    simp
  rw [h_simp]
  exact Nat.sub_le initial_weight budget.local_residue

/-- BRANCH LIGHTENING THEOREM (strict, conditional).
    If local_residue > 0 AND initial_weight > 0, the reactionless step strictly
    reduces the weight. This means: associator debt always lightens the effective
    cost when there is weight to be reduced.

    If initial_weight = 0, the weight stays 0 (can't go negative in Nat arithmetic). -/
theorem branch_lightening_strict (initial_weight : Nat) (budget : NonAssociativeBudget)
    (h_non_zero : budget.local_residue > 0) (h_weight_pos : initial_weight > 0) :
    reactionless_step initial_weight budget < initial_weight := by
  unfold reactionless_step compute_amortization kappa_constant
  -- After unfolding: initial_weight - (1 * budget.local_residue) < initial_weight
  -- Need to simplify 1 * r to r
  have h_simp : initial_weight - (1 * budget.local_residue) = initial_weight - budget.local_residue := by
    simp
  rw [h_simp]
  have h_sub : initial_weight - budget.local_residue < initial_weight :=
    Nat.sub_lt h_weight_pos h_non_zero
  exact h_sub

/-- The concrete shift: strut_weight=4, capacity=10. -/
def ConcreteReactionlessShift : NonAssociativeBudget := {
  local_residue := strut_weight
  max_capacity := 10
  h_capacity_pos := by decide
  h_pentagon_bound := by
    rw [strut_weight_eq_four]
    decide
}

/-- The amortization for the concrete shift is exactly 4
    (since kappa = 1 and strut_weight = 4). -/
theorem concrete_amortization : compute_amortization ConcreteReactionlessShift = 4 := by
  unfold compute_amortization ConcreteReactionlessShift kappa_constant strut_weight
  decide

-- ============================================================================
-- LAYER 7: PROJECTION TO NodeCost
-- ============================================================================

/-- The engine state: tracks associator debt and capacity. -/
structure EngineState where
  current_weight : Nat
  local_debt : Nat
  capacity : Nat

/-- Projection from an engine state to a NodeCost parameter.

    Logic:
    - If `local_debt > 0` (non-associative sector):
      mirror=true (space-biased), leftWeight=0 (commutator silent),
      rightDiv = max(0, capacity/(local_debt+1) - 1) (debt-compressed right divisor)
    - If `local_debt = 0` (associative sector):
      mirror=false, leftWeight=1, rightDiv=0 (classical flat landscape)

    The rightDiv formula captures the compression effect:
    as debt increases, the effective compression (rightDiv) approaches 0
    (the Spacetime limit), but for moderate debt it provides compression
    proportional to the capacity/debt ratio. -/
def engine_to_nodecost (state : EngineState) : Cost.NodeCost :=
  if _ : state.local_debt > 0 then
    -- Non-associative sector: space-biased, commutator silent
    let compression := state.capacity / (state.local_debt + 1)
    { leftWeight := 0
      rightDiv := max 0 (compression - 1)
      bias := 1
      mirror := true
      coupling := 0
      denom := 10
      maxSem := false
      satCap := 0 }
  else
    -- Associative sector: classical, flat landscape
    { leftWeight := 1
      rightDiv := 0
      bias := 1
      mirror := false
      coupling := 0
      denom := 10
      maxSem := false
      satCap := 0 }

/-- The engine for the concrete shift (debt=4, capacity=10) computes
    rightDiv = max(0, 10/(4+1) - 1) = max(0, 2 - 1) = 1. -/
theorem engine_concrete_rightDiv : (engine_to_nodecost {
    current_weight := 0, local_debt := 4, capacity := 10 }).rightDiv = 1 := by
  unfold engine_to_nodecost
  have h_pos : (4 : Nat) > 0 := by decide
  simp [h_pos]

/-- When debt=0 (associative sector), the projection gives the classical
    NodeCost (leftWeight=1, mirror=false, rightDiv=0). -/
theorem engine_zero_debt_classical : engine_to_nodecost {
    current_weight := 0, local_debt := 0, capacity := 10 }
    = { leftWeight := 1, rightDiv := 0, bias := 1, mirror := false, coupling := 0,
        denom := 10, maxSem := false, satCap := 0 } := by
  unfold engine_to_nodecost
  simp

/-- The engine with positive debt always produces a mirror=true NodeCost
    (Spacetime-like). -/
theorem engine_pos_debt_mirror (debt cap : Nat) (h : debt > 0) :
    (engine_to_nodecost { current_weight := 0, local_debt := debt, capacity := cap }).mirror = true := by
  unfold engine_to_nodecost
  simp [h]

-- ============================================================================
-- LAYER 8: CARRIER MORPHISM NodeCost → SplitOctonion (Gap A of GLM-5.2)
-- ============================================================================
-- The 7-skeleton discovery (SplitOctonionLogic.lean) shows that the 15 named
-- logics collapse to 7 distinct NodeCost configurations, corresponding to the
-- 7 imaginary axes e₁⋯e₇ of the split-octonion with bias=1 as e₀.
--
-- The carrier morphism `toSO` embeds the 8-parameter NodeCost space into the
-- 8-dimensional split-octonion algebra, making the "readout" (NodeCost = WHAT)
-- into a bona fide algebraic object (SplitOctonion = WHY). The factorization
-- theorem shows that `engine_to_nodecost` factors through this embedding:
-- the engine state first maps to a split-octonion point, then projects to
-- NodeCost via the field structure.
--
-- This is NOT an algebra homomorphism (NodeCost has no multiplication) —
-- it is an embedding of the parameter space, proving that the cost parameters
-- are a genuine projection of the underlying algebraic structure.

/-- Embed a NodeCost into the split-octonion algebra by mapping each field to
    the corresponding component eᵢ:
    - e₀ (real axis)    ← bias       (always 1 — the identity)
    - e₁ (associative)  ← leftWeight (left-subtree amplification)
    - e₂ (associative)  ← rightDiv   (right-subtree compression)
    - e₃ (associative)  ← denom      (denominator for cross-term)
    - e₄ (split)       ← coupling   (cross-term numerator — non-associative)
    - e₅ (split)       ← satCap     (saturation bound — non-associative)
    - e₆ (split)       ← mirror     (mirror mode — Bool as Int: 0/1)
    - e₇ (split)       ← maxSem     (semantic max mode — Bool as Int: 0/1) -/
def toSO (c : Cost.NodeCost) : SplitOctonion :=
  { e0 := c.bias
    e1 := c.leftWeight
    e2 := c.rightDiv
    e3 := c.denom
    e4 := c.coupling
    e5 := c.satCap
    e6 := if c.mirror then 1 else 0
    e7 := if c.maxSem then 1 else 0
  }

/-- `toSO` is injective: the embedding faithfully represents NodeCost fields
    as distinct split-octonion components. This is the carrier morphism
    requirement — NodeCost is a subobject of SplitOctonion (via the 8 fields). -/
theorem toSO_injective (c₁ c₂ : Cost.NodeCost) (h : toSO c₁ = toSO c₂) : c₁ = c₂ := by
  -- Destructure both NodeCosts to expose fields
  cases c₁; cases c₂
  rename_i lw1 rd1 b1 m1 co1 d1 ms1 sc1 lw2 rd2 b2 m2 co2 d2 ms2 sc2
  -- Using h, each SO component equality gives a NodeCost field equality via simpa [toSO]
  have hb : b1 = b2 := by
    simpa [toSO] using congr_arg SplitOctonion.e0 h
  have hlw : lw1 = lw2 := by
    simpa [toSO] using congr_arg SplitOctonion.e1 h
  have hrd : rd1 = rd2 := by
    simpa [toSO] using congr_arg SplitOctonion.e2 h
  have hd : d1 = d2 := by
    simpa [toSO] using congr_arg SplitOctonion.e3 h
  have hco : co1 = co2 := by
    simpa [toSO] using congr_arg SplitOctonion.e4 h
  have hsc : sc1 = sc2 := by
    simpa [toSO] using congr_arg SplitOctonion.e5 h
  have hm : m1 = m2 := by
    -- e6 is 0/1 from the Bool conditionals; equality of e6 forces the Bools to agree
    have he6 : (toSO (Cost.NodeCost.mk lw1 rd1 b1 m1 co1 d1 ms1 sc1)).e6 =
              (toSO (Cost.NodeCost.mk lw2 rd2 b2 m2 co2 d2 ms2 sc2)).e6 := by rw [h]
    unfold toSO at he6
    by_cases h1 : m1
    · -- m1 = true → RHS must be true too, otherwise 1 ≠ 0
      simp [h1] at he6
      have h2 : m2 := by
        by_contra! h2
        simp [h2] at he6
      simp [h1, h2]
    · -- m1 = false → RHS must be false too
      simp [h1] at he6
      have h2 : ¬ m2 := by
        by_contra! h2
        simp [h2] at he6
      simp [h1, h2]
  have hms : ms1 = ms2 := by
    -- Same logic as hm, using e7
    have he7 : (toSO (Cost.NodeCost.mk lw1 rd1 b1 m1 co1 d1 ms1 sc1)).e7 =
              (toSO (Cost.NodeCost.mk lw2 rd2 b2 m2 co2 d2 ms2 sc2)).e7 := by rw [h]
    unfold toSO at he7
    by_cases h1 : ms1
    · simp [h1] at he7
      have h2 : ms2 := by
        by_contra! h2
        simp [h2] at he7
      simp [h1, h2]
    · simp [h1] at he7
      have h2 : ¬ ms2 := by
        by_contra! h2
        simp [h2] at he7
      simp [h1, h2]
  -- All 8 fields are equal; use simp to close the goal
  simp [hb, hlw, hrd, hd, hco, hsc, hm, hms]

/-- Map an engine state directly to a split-octonion point, bypassing NodeCost.
    This is the "direct" algebraic representation of the engine state in
    the split-octonion algebra.
    
    By definition, `engineToSO = toSO ∘ engine_to_nodecost`. The factorization
    theorem `engine_to_nodecost_factors_through_SO` is therefore `rfl`.
    (See `engineToSO_formula` for the explicit componentwise expansion.) -/
def engineToSO (s : EngineState) : SplitOctonion :=
  toSO (engine_to_nodecost s)

/-- Componentwise equality lemma for SplitOctonion: if all 8 components agree,
    the two split-octonions are equal. -/
@[ext]
lemma SplitOctonion.ext_components {a b : SplitOctonion}
    (h0 : a.e0 = b.e0) (h1 : a.e1 = b.e1) (h2 : a.e2 = b.e2)
    (h3 : a.e3 = b.e3) (h4 : a.e4 = b.e4) (h5 : a.e5 = b.e5)
    (h6 : a.e6 = b.e6) (h7 : a.e7 = b.e7) : a = b := by
  cases a; cases b
  simp at h0 h1 h2 h3 h4 h5 h6 h7
  simp [h0, h1, h2, h3, h4, h5, h6, h7]

/-- Explicit componentwise expansion of `engineToSO` for documentation purposes.
    When `local_debt > 0`:
      e₀=1, e₁=0, e₂=max(0, capacity/(debt+1)-1), e₃=10,
      e₄=0, e₅=0, e₆=1 (mirror), e₇=0
    When `local_debt = 0`:
      e₀=1, e₁=1 (classical), e₂=0, e₃=10,
      e₄=0, e₅=0, e₆=0, e₇=0
    This matches the `engine_to_nodecost` branches componentwise. -/
theorem engineToSO_formula (s : EngineState) : engineToSO s =
    if h : s.local_debt > 0 then
      let compression := s.capacity / (s.local_debt + 1)
      { e0 := 1, e1 := 0, e2 := (max 0 (compression - 1) : ℤ), e3 := 10,
        e4 := 0, e5 := 0, e6 := 1, e7 := 0
      }
    else
      { e0 := 1, e1 := 1, e2 := 0, e3 := 10,
        e4 := 0, e5 := 0, e6 := 0, e7 := 0
      } := by
  dsimp [engineToSO]
  by_cases h : s.local_debt > 0
  · apply SplitOctonion.ext_components
    · -- e0
      simp [toSO, engine_to_nodecost, h]
    · -- e1
      simp [toSO, engine_to_nodecost, h]
    · -- e2: rightDiv formula (Nat.max with cast to ℤ)
      -- Lemma: for any x:ℕ, the Nat.cast of (max 0 (x-1)) equals the ℤ max
      have cast_lemma (x : ℕ) : (Nat.cast (max 0 (x - 1)) : ℤ) = max (0 : ℤ) ((x : ℤ) - 1) := by
        cases x
        · simp
        · rename_i x
          simp
      let target : SplitOctonion :=
        { e0 := 1, e1 := 0, e2 := (max 0 ((s.capacity / (s.local_debt + 1)) - 1) : ℤ), e3 := 10,
          e4 := 0, e5 := 0, e6 := 1, e7 := 0 }
      calc
        (toSO (engine_to_nodecost s)).e2 = ((engine_to_nodecost s).rightDiv : ℤ) := rfl
        _ = (Nat.cast (max 0 ((s.capacity / (s.local_debt + 1)) - 1)) : ℤ) := by
          simp [engine_to_nodecost, h]
        _ = (max 0 ((s.capacity / (s.local_debt + 1)) - 1) : ℤ) := by
          simpa using cast_lemma (s.capacity / (s.local_debt + 1))
        _ = target.e2 := rfl
        _ = (if h : s.local_debt > 0 then target
              else { e0 := 1, e1 := 1, e2 := 0, e3 := 10,
                     e4 := 0, e5 := 0, e6 := 0, e7 := 0 }).e2 := by
          simp [h]
    · -- e3
      simp [toSO, engine_to_nodecost, h]
    · -- e4
      simp [toSO, engine_to_nodecost, h]
    · -- e5
      simp [toSO, engine_to_nodecost, h]
    · -- e6: mirror → 1
      simp [toSO, engine_to_nodecost, h]
    · -- e7: maxSem → 0
      simp [toSO, engine_to_nodecost, h]
  · apply SplitOctonion.ext_components
    · simp [toSO, engine_to_nodecost, h]
    · simp [toSO, engine_to_nodecost, h]
    · simp [toSO, engine_to_nodecost, h]
    · simp [toSO, engine_to_nodecost, h]
    · simp [toSO, engine_to_nodecost, h]
    · simp [toSO, engine_to_nodecost, h]
    · simp [toSO, engine_to_nodecost, h]
    · simp [toSO, engine_to_nodecost, h]

/-- The engine's projection to NodeCost factors through the split-octonion
    carrier morphism (trivially, by definition of `engineToSO`):
    
        toSO (engine_to_nodecost s) = engineToSO s
    
    This is the Gap A factorization theorem: the 3-parameter engine state
    embeds into the 8-dimensional split-octonion algebra, and the NodeCost
    readout is the "shadow" (componentwise projection) of that algebraic point. -/
theorem engine_to_nodecost_factors_through_SO (s : EngineState) :
    toSO (engine_to_nodecost s) = engineToSO s := rfl

-- ============================================================================
-- LAYER 9: COST LANDSCAPE EQUIVALENCE
-- ============================================================================

/-- The engine-projected NodeCost for the concrete shift produces a
    Spacetime-like cost (mirror=true, leftWeight=0).
    The rightDiv is 1 (moderate compression), which is a tighter bound than
    the Cost module's Spacetime (rightDiv=0). This shows that the engine
    DERIVES the NodeCost parameters from the associator debt rather than
    assuming them as constants. -/
theorem engine_concrete_is_spacetime_like :
    (engine_to_nodecost { current_weight := 0, local_debt := 4, capacity := 10 }).mirror = true ∧
    (engine_to_nodecost { current_weight := 0, local_debt := 4, capacity := 10 }).leftWeight = 0 := by
  have h_pos : (4 : Nat) > 0 := by decide
  unfold engine_to_nodecost
  simp [h_pos]

end SplitOctonionCost
