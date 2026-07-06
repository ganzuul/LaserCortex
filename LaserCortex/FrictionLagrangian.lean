/-
# Module: FrictionLagrangian

## Intent

The Friction Lagrangian Γ is the action functional that integrates the cost
landscape across all logic layers of the Cayley-Dickson tower.

Core layer-cost and frictionDensity/assocDefect/commDefect come from
`staging/Friction` (the canonical source). This module adds:

  • **Tower-level integration**: frictionLagrangian total action over Tower
  • **Cost-aware contraction**: contracts_to_with_cost annotating each step
    with its friction cost

## Contracts

[frictionLagrangian, layerCost, flatCostSum,
 frictionLagrangian_ge_flatSum, frictionLagrangian_gt_flatSum,
 contracts_to_with_cost, contracts_to_with_cost_cost_eq_n_times_friction,
 friction_barrier_across_cd23, size_eq_numLeaves_sub_one]

## Cross-refs

staging/Friction → assocDefect, commDefect, frictionDensity
staging/Algebra → strut_weight
LogicTypes → LogicType, cdStep
LodayCoords → lodayCoord, numLeaves
EMLRegistry → EMLTree, contracts_to, contracts_one
Problem → Tower, WrappedProblem

## Tags

#lean4-theorem #friction-lagrangian #integration-point #phase-change #height-map
-/

import LaserCortex.staging.Friction
import LaserCortex.Problem
import LaserCortex.LogicTypes
import LaserCortex.LodayCoords
import LaserCortex.EMLRegistry

open LogicTypes
open ProblemTypes
open LodayCoords

namespace FrictionLagrangian

-- ============================================================================
-- SECTION 1: Layer Cost — mapping LogicType → ℕ
-- ============================================================================

/-- The true cost for a logic type under the Friction Lagrangian.
    layerCost(lt) = Γ(lt.cdStep) = lt.cdStep + strut_weight·assocDefect(lt.cdStep) -/
def layerCost (lt : LogicType) : ℕ :=
  frictionDensity lt.cdStep

/-- The true cost is at least the old cdStep cost:
    the Lagrangian never underestimates the flat cost.
    For associative logics (cdStep ≤ 2), they are equal.
    For non-associative logics (cdStep ≥ 3), the Lagrangian is strictly larger. -/
theorem layerCost_ge_cdStep (lt : LogicType) : layerCost lt ≥ lt.cdStep := by
  dsimp [layerCost]
  apply frictionDensity_ge_k

/-- For logics in the associative regime (CD ≤ 2), the Lagrangian cost equals
    the old cdStep cost. This includes Classical, Fuzzy, Intuitionistic,
    and the Cl(1,1) ≅ ℍ̃ boundary (split quaternions at CD 2'). -/
theorem layerCost_eq_cdStep_for_assoc (lt : LogicType) (h : lt.cdStep ≤ 2) :
    layerCost lt = lt.cdStep := by
  dsimp [layerCost]
  exact frictionDensity_eq_k_for_k_le_2 lt.cdStep h

-- ============================================================================
-- SECTION 2: The Friction Lagrangian (total action over a Tower)
-- ============================================================================

/-- The total Friction Lagrangian for any tower.
    Γ(Tower{p}) = Σ_{layer ∈ Tower.layers} frictionDensity(layer.logicType.cdStep) -/
def frictionLagrangian {p : Problem} (tower : Tower p) : ℕ :=
  tower.layers.map (λ (x : Σ lt, WrappedProblem p lt) => layerCost x.1) |>.sum

/-- The old flat cost sum (what the paradox files currently compute).
    Kept for comparison and migration. -/
def flatCostSum {p : Problem} (tower : Tower p) : ℕ :=
  tower.layers.map (λ (x : Σ lt, WrappedProblem p lt) => x.1.cdStep) |>.sum

/-- The Friction Lagrangian is always at least the flat cost sum.
    This holds because layerCost ≥ cdStep for every logic (layerCost_ge_cdStep). -/
theorem frictionLagrangian_ge_flatSum {p : Problem} (tower : Tower p) :
    frictionLagrangian tower ≥ flatCostSum tower := by
  dsimp [frictionLagrangian, flatCostSum]
  induction tower.layers with
  | nil => rfl
  | cons x xs ih =>
    simp
    have h := layerCost_ge_cdStep x.1
    omega

/-- If f x ≥ g x for all x in the list, then the sum of f is at least the sum of g. -/
lemma list_sum_ge_of_forall_ge {ι : Type*} (f g : ι → ℕ) (xs : List ι) (h : ∀ x ∈ xs, f x ≥ g x) :
    (xs.map f).sum ≥ (xs.map g).sum := by
  induction xs with
  | nil => rfl
  | cons y ys ih =>
    have hy : f y ≥ g y := h y (by simp)
    have h_ys : ∀ x ∈ ys, f x ≥ g x := λ x hx => h x (by simp [hx])
    have ih_ys := ih h_ys
    simp; omega

/-- If f x > g x for some x in the list, and f x ≥ g x for all x,
    then the sum of f over the list is strictly greater than the sum of g. -/
lemma list_sum_gt_of_exists_gt {ι : Type*} (f g : ι → ℕ) (xs : List ι)
    (h : ∃ x ∈ xs, f x > g x) (h_all : ∀ x ∈ xs, f x ≥ g x) :
    (xs.map f).sum > (xs.map g).sum := by
  induction xs with
  | nil =>
    rcases h with ⟨x, hx, _⟩
    simp at hx
  | cons y ys ih =>
    have hy : f y ≥ g y := h_all y (by simp)
    have h_total : (f y + (ys.map f).sum) > (g y + (ys.map g).sum) := by
      rcases h with ⟨x, hx, hx_gt⟩
      have hx_cases : x = y ∨ x ∈ ys := by simpa using hx
      rcases hx_cases with (rfl | hx_ys)
      · -- x = y: strict at head, ≥ in tail
        have h_all_ys : ∀ x' ∈ ys, f x' ≥ g x' := λ x' hx' => h_all x' (by simp [hx'])
        have h_rest : (ys.map f).sum ≥ (ys.map g).sum :=
          list_sum_ge_of_forall_ge f g ys h_all_ys
        omega
      · -- x ∈ ys: strict in tail, ≥ at head
        have h_ys : ∃ x' ∈ ys, f x' > g x' := ⟨x, hx_ys, hx_gt⟩
        have h_all_ys : ∀ x' ∈ ys, f x' ≥ g x' := λ x' hx' => h_all x' (by simp [hx'])
        have h_rest : (ys.map f).sum > (ys.map g).sum := ih h_ys h_all_ys
        simp; omega
    simp; exact h_total

/-- The Friction Lagrangian is strictly greater than the flat cost sum
    whenever there is at least one non-associative layer (CD ≥ 3) in the tower.
    This formalizes the "enormous energy density" at the CD 2→3 boundary:
    the associator barrier adds strut_weight² to every non-associative layer. -/
theorem frictionLagrangian_gt_flatSum {p : Problem} (tower : Tower p)
    (h : ∃ x ∈ tower.layers, x.1.cdStep ≥ 3) :
    frictionLagrangian tower > flatCostSum tower := by
  dsimp [frictionLagrangian, flatCostSum]
  have h_exists : ∃ x ∈ tower.layers, layerCost x.1 > x.1.cdStep := by
    rcases h with ⟨x, hx_mem, hx_cd⟩
    refine ⟨x, hx_mem, ?_⟩
    have h_phase : frictionDensity x.1.cdStep > x.1.cdStep := by
      rw [frictionDensity_eq_k_plus_16_for_k_ge_3 x.1.cdStep hx_cd]
      have h16 : strut_weight * strut_weight = 16 := by
        calc
          strut_weight * strut_weight = 4 * 4 := by rw [strut_weight_eq_four]
          _ = 16 := by norm_num
      rw [h16]
      omega
    dsimp [layerCost]
    exact h_phase
  have h_all : ∀ x ∈ tower.layers, layerCost x.1 ≥ x.1.cdStep := by
    intro x hx
    exact layerCost_ge_cdStep x.1
  apply list_sum_gt_of_exists_gt (λ x : Σ lt, WrappedProblem p lt => layerCost x.1)
    (λ x : Σ lt, WrappedProblem p lt => x.1.cdStep) tower.layers h_exists h_all

-- ============================================================================
-- SECTION 3: Loday Coordinates Bridge
-- ============================================================================

/-- Standard binary tree identity: size = numLeaves - 1 for any tree. -/
theorem size_eq_numLeaves_sub_one (t : EMLRegistry.EMLTree) : t.size = numLeaves t - 1 := by
  induction t with
  | Leaf =>
    simp [numLeaves, EMLRegistry.EMLTree.size]
  | Node l r ih_l ih_r =>
    have pos_l : 0 < numLeaves l := numLeaves_pos l
    have pos_r : 0 < numLeaves r := numLeaves_pos r
    calc
      (EMLRegistry.EMLTree.Node l r).size = 1 + l.size + r.size := by rfl
      _ = 1 + (numLeaves l - 1) + (numLeaves r - 1) := by rw [ih_l, ih_r]
      _ = (numLeaves l + numLeaves r) - 1 := by omega
      _ = numLeaves (EMLRegistry.EMLTree.Node l r) - 1 := by
        simp [numLeaves]

-- ============================================================================
-- SECTION 4: Zero-Divisor Bridge Theorem
-- ============================================================================

/-- The friction barrier across the CD 2→3 boundary is at least strut_weight².
    This is the quantitative signature of a zero divisor: the irreducible
    cost of composing types from incompatible algebraic regimes.

    If k₁ ≤ 2 (associative regime) and k₂ ≥ 3 (non-associative regime),
    then Γ_k₂ - Γ_k₁ ≥ strut_weight * strut_weight = 16. -/
theorem friction_barrier_across_cd23 (k₁ k₂ : ℕ) (h₁ : k₁ ≤ 2) (h₂ : 3 ≤ k₂) :
    frictionDensity k₂ - frictionDensity k₁ ≥ strut_weight * strut_weight := by
  have ha2 : assocDefect k₁ = 0 := assocDefect_zero_up_to_cd2 k₁ h₁
  have ha3 : assocDefect k₂ = strut_weight := assocDefect_positive_for_cd3plus k₂ h₂
  unfold frictionDensity commDefect
  rw [ha2, ha3]
  have hk : k₂ ≥ k₁ := by omega
  omega

-- ============================================================================
-- SECTION 5: Cost-Aware Contraction
-- ============================================================================

/-- Cost-annotated contraction path with step count.
    `contracts_to_with_cost cd s t c n` means there exists a sequence of
    contraction steps from s to t at cdStep cd whose total friction cost
    is exactly c and which takes exactly n steps.

    Each step contributes `frictionDensity cd` to the total cost. -/
inductive contracts_to_with_cost (cd : ℕ) : EMLRegistry.EMLTree → EMLRegistry.EMLTree → ℕ → ℕ → Prop where
  | refl (t : EMLRegistry.EMLTree) : contracts_to_with_cost cd t t 0 0
  | step (s t u : EMLRegistry.EMLTree)
      (h_one : EMLRegistry.contracts_one s t)
      (h_to : contracts_to_with_cost cd t u c n) :
      contracts_to_with_cost cd s u (frictionDensity cd + c) (n + 1)

/-- Every cost-annotated path contracts s to t. -/
theorem contracts_to_with_cost_implies_contracts_to (cd : ℕ) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (h : contracts_to_with_cost cd s t c n) : EMLRegistry.contracts_to s t := by
  induction h with
  | refl t => exact EMLRegistry.contracts_to.refl t
  | step s t u h_one h_to ih =>
    exact EMLRegistry.contracts_to.step s t u h_one ih

/-- Cost-annotated paths at any cdStep are valid under `contracts_to_at_cdStep`. -/
theorem contracts_to_with_cost_implies_at_cdStep (cd : ℕ) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (h : contracts_to_with_cost cd s t c n) : EMLRegistry.contracts_to_at_cdStep cd s t := by
  -- contracts_to_at_cdStep cd s t is defined as contracts_to s t, which follows from
  -- contracts_to_with_cost_implies_contracts_to
  exact contracts_to_with_cost_implies_contracts_to cd s t c n h

/-- The cost is at least frictionDensity cd for any non-trivial path.
    This is the "base rate" bound: each step costs at least one unit
    of friction density. -/
theorem contracts_to_with_cost_ge_frictionDensity (cd : ℕ) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (h : contracts_to_with_cost cd s t c n) : c ≥ frictionDensity cd ∨ c = 0 := by
  induction h with
  | refl t => right; rfl
  | step s t u h_one h_to ih =>
    left
    omega

/-- The total cost equals the number of steps times the friction density. -/
theorem contracts_to_with_cost_cost_eq_n_times_friction (cd : ℕ) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (h : contracts_to_with_cost cd s t c n) : c = n * frictionDensity cd := by
  induction h with
  | refl t => simp
  | step s t u h_one h_to ih =>
    simp [ih, add_comm, add_left_comm, add_assoc, mul_add, add_mul, mul_comm]

/-- Height-map monotonicity for path cost:
    if s contracts to t at cdStep j with cost c and n steps,
    then at a higher cdStep k ≥ j the same n-step path costs
    n * frictionDensity k, which is ≥ c. -/
theorem heightMap_monotone_for_path_cost (j k : ℕ) (hjk : j ≤ k) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (hj : contracts_to_with_cost j s t c n) :
    contracts_to_with_cost k s t (n * frictionDensity k) n := by
  induction hj generalizing k with
  | refl t => 
    simpa [Nat.zero_mul] using (contracts_to_with_cost.refl t : contracts_to_with_cost k t t 0 0)
  | step s t u h_one h_to ih =>
    rename_i hc hn
    have hk : contracts_to_with_cost k t u (hn * frictionDensity k) hn := ih k hjk
    have hstep : contracts_to_with_cost k s u (frictionDensity k + hn * frictionDensity k) (hn + 1) :=
      contracts_to_with_cost.step s t u h_one hk
    have hcalc : frictionDensity k + hn * frictionDensity k = (hn + 1) * frictionDensity k := by
      ring
    simpa [hcalc] using hstep

/-- Corollary: the minimal cost at cdStep k is at least the minimal cost at cdStep j
    when j ≤ k, because the same path costs more at higher cdStep. -/
theorem min_cost_monotone_with_cdStep (j k : ℕ) (hjk : j ≤ k) (s t : EMLRegistry.EMLTree) (c n : ℕ)
    (hj : contracts_to_with_cost j s t c n) : c ≤ n * frictionDensity k := by
  have hcost_eq : c = n * frictionDensity j := contracts_to_with_cost_cost_eq_n_times_friction j s t c n hj
  have hfd_mono : frictionDensity j ≤ frictionDensity k := by
    by_cases h_eq : j = k
    · subst h_eq; rfl
    · have h_lt : j < k := by omega
      exact frictionDensity_monotone j k h_lt
  have h_mul : n * frictionDensity j ≤ n * frictionDensity k :=
    Nat.mul_le_mul_left n hfd_mono
  omega

end FrictionLagrangian
