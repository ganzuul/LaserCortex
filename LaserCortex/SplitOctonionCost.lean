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
-- LAYER 8: COST LANDSCAPE EQUIVALENCE
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
