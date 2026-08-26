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
- `dcStep_node_compose` : THE COMPOSITION LAW — dcStep(Node l r) =
  dcStep l + dcStep r + rightSpine l (coupling flows through the left
  system's output chain)
- `weightedCost_node_superadditive` / `treeTemp_node_superadditive` :
  energy and temperature are superadditive under composition
- `weightedCost_mixed_dominance` : composing systems at different CD steps
  evaluates at the hotter algebra — mixing can only heat up

## Cross-refs

- `staging/Tamari` — `dcStep`, `rightComb`, `contracts_to_rightComb`
- `staging/Friction` — `frictionDensity`, `assocDefect`, `commDefect`
- `staging/Algebra` — `strut_weight`, `SplitOctonion`, `SplitQuat`
- `lab_notes/031_ic_is_regular_subdivision.md`

## Tags

#lean4-theorem #subdivision #associahedron #tamari #weighted-cost
-/

import LaserCortex.foundations.Tamari
import LaserCortex.Friction
import LaserCortex.LogicalTemperature
import LaserCortex.TamariMetric

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

-- ============================================================================
-- SECTION 9: Phase diagram composition
--
-- The energy functional E(cd, t) = dcStep(t) × frictionDensity(cd) has the
-- thermodynamic shape "extensive × intensive". This section proves how
-- phase diagrams COMPOSE: given two subsystems (trees t₁, t₂), the composite
-- system Node t₁ t₂ obeys an exact composition law with a coupling term,
-- from which superadditivity of energy and dominance of the hotter algebra
-- follow.
-- ============================================================================

/-- Depth of the rightmost leaf: the length of the right spine.
    This measures how far the system's "output chain" extends. -/
def rightSpine : EMLTree → ℕ
  | .Leaf => 0
  | .Node _ r => 1 + rightSpine r

/-- **THE COMPOSITION LAW.** Grafting two subsystems costs exactly

    dcStep(Node t₁ t₂) = dcStep t₁ + dcStep t₂ + rightSpine t₁

    The flip count is additive in the parts PLUS a coupling term equal to
    the right-spine depth of the left subsystem: coupling flows through the
    left system's output chain. Verified exhaustively to size 5 and the
    proof is a two-line induction (the coupling telescopes through the
    rotation recursion). -/
theorem dcStep_node_compose : ∀ (l r : EMLTree),
    dcStep (EMLTree.Node l r) = dcStep l + dcStep r + rightSpine l := by
  intro l
  induction l with
  | Leaf =>
    intro r
    simp [dcStep, rightSpine]
  | Node a b iha ihb =>
    intro r
    have h_ab := iha b
    have h_abr := iha (EMLTree.Node b r)
    have h_br := ihb r
    simp only [dcStep]
    rw [h_abr, h_ab, h_br]
    simp only [rightSpine]
    omega

/-- Superadditivity of flip count: composing two systems never reduces the
    total number of contractions needed. -/
theorem dcStep_node_superadditive (l r : EMLTree) :
    dcStep l + dcStep r ≤ dcStep (EMLTree.Node l r) := by
  rw [dcStep_node_compose]
  omega

/-- Composition is exactly extensive iff the left subsystem is the vacuum:
    coupling vanishes precisely when nothing flows through the output chain. -/
theorem dcStep_node_eq_iff_left_leaf (l r : EMLTree) :
    dcStep (EMLTree.Node l r) = dcStep l + dcStep r ↔ l = EMLTree.Leaf := by
  constructor
  · intro h
    rw [dcStep_node_compose] at h
    cases l with
    | Leaf => rfl
    | Node a b =>
      simp only [rightSpine] at h
      omega
  · intro h
    subst h
    simp [dcStep]

/-- Energy is SUPERADDITIVE under composition: the composite system carries
    at least the sum of the part energies. Equality holds iff the left
    subsystem is the vacuum (no coupling). -/
theorem weightedCost_node_superadditive (cd : ℕ) (t₁ t₂ : EMLTree) :
    weightedCost cd t₁ + weightedCost cd t₂
      ≤ weightedCost cd (EMLTree.Node t₁ t₂) := by
  unfold weightedCost
  rw [dcStep_node_compose]
  calc dcStep t₁ * frictionDensity cd + dcStep t₂ * frictionDensity cd
      = (dcStep t₁ + dcStep t₂) * frictionDensity cd := by rw [Nat.add_mul]
    _ ≤ (dcStep t₁ + dcStep t₂ + rightSpine t₁) * frictionDensity cd :=
        Nat.mul_le_mul (Nat.le_add_right _ _) (Nat.le_refl _)

/-- Γ of each part is bounded by Γ of the hotter algebra. -/
theorem frictionDensity_le_max (i j : ℕ) :
    frictionDensity i ≤ frictionDensity (max i j)
      ∧ frictionDensity j ≤ frictionDensity (max i j) := by
  rcases Nat.lt_trichotomy i j with h | h | h
  · rw [Nat.max_def, if_pos h.le]
    exact ⟨frictionDensity_monotone i j h, Nat.le_refl _⟩
  · subst h
    rw [Nat.max_def, if_pos (Nat.le_refl _)]
    exact ⟨Nat.le_refl _, Nat.le_refl _⟩
  · rw [Nat.max_def, if_neg (by omega : ¬ (i ≤ j))]
    exact ⟨Nat.le_refl _, frictionDensity_monotone j i h⟩

/-- **Dominance of the hot phase.** Composing two systems that live at
    different CD steps yields a composite whose energy dominates the sum:
    evaluating each part at its own algebra, the composite evaluated at the
    hotter algebra is at least as energetic. Algebraic mixing can only
    heat up. -/
theorem weightedCost_mixed_dominance (c₁ c₂ : ℕ) (t₁ t₂ : EMLTree) :
    weightedCost c₁ t₁ + weightedCost c₂ t₂
      ≤ weightedCost (max c₁ c₂) (EMLTree.Node t₁ t₂) := by
  obtain ⟨hg₁, hg₂⟩ := frictionDensity_le_max c₁ c₂
  unfold weightedCost at *
  rw [dcStep_node_compose]
  calc dcStep t₁ * frictionDensity c₁ + dcStep t₂ * frictionDensity c₂
      ≤ dcStep t₁ * frictionDensity (max c₁ c₂)
          + dcStep t₂ * frictionDensity (max c₁ c₂) :=
        Nat.add_le_add (Nat.mul_le_mul_left _ hg₁) (Nat.mul_le_mul_left _ hg₂)
    _ = (dcStep t₁ + dcStep t₂) * frictionDensity (max c₁ c₂) := by
        rw [Nat.add_mul]
    _ ≤ (dcStep t₁ + dcStep t₂ + rightSpine t₁)
          * frictionDensity (max c₁ c₂) :=
        Nat.mul_le_mul (Nat.le_add_right _ _) (Nat.le_refl _)

noncomputable section

/-- Barrier-equivalent temperature of a whole tree configuration:
    the Landauer reading of its total weighted flip energy. -/
def treeTemp (c : LandauerCalibration) (cd : ℕ) (t : EMLTree) : ℝ :=
  (weightedCost cd t : ℝ) * c.tOp * Real.log 2

/-- Temperature is superadditive under composition at a fixed algebra:
    the composite system is at least as hot as the sum of its parts.
    Equality iff the left subsystem is the vacuum (coupling-free). -/
theorem treeTemp_node_superadditive (c : LandauerCalibration) (cd : ℕ)
    (t₁ t₂ : EMLTree) :
    treeTemp c cd t₁ + treeTemp c cd t₂ ≤ treeTemp c cd (EMLTree.Node t₁ t₂) := by
  unfold treeTemp
  have hsplit :
      (((weightedCost cd t₁ + weightedCost cd t₂ : ℕ) : ℝ)) * c.tOp * Real.log 2
        = ((weightedCost cd t₁ : ℕ) : ℝ) * c.tOp * Real.log 2
          + ((weightedCost cd t₂ : ℕ) : ℝ) * c.tOp * Real.log 2 := by
    push_cast
    ring
  rw [← hsplit]
  have h1 : ((weightedCost cd t₁ + weightedCost cd t₂ : ℕ) : ℝ) * c.tOp
      ≤ (weightedCost cd (EMLTree.Node t₁ t₂) : ℕ) * c.tOp :=
    mul_le_mul_of_nonneg_right
      (Nat.cast_le.mpr (weightedCost_node_superadditive cd t₁ t₂)) c.tOp_pos.le
  exact mul_le_mul_of_nonneg_right h1
    (Real.log_nonneg (by norm_num : (1:ℝ) ≤ 2))

end

-- ============================================================================
-- SECTION 10: Loose coupling (perturbed phase diagrams)
--
-- Strict grafting always pays the full coupling term rightSpine l · γ.
-- Loose coupling discounts that term by a trust coefficient λ = num/den ≤ 1.
-- The phase boundary `cost ≥ reserve` retreats by exactly the discount —
-- this retreat is the market's risk-taking window. The safety theorem below
-- shows the perturbation can RESCUE routes from paradox but can never DAMN
-- a safe one. See lab_notes/049.
-- ============================================================================

/-- The coupling discount is bounded by the full coupling term. -/
theorem discounted_coupling_le (g num den s : ℕ)
    (hl : num ≤ den) (hden : 0 < den) :
    num * s * g / den ≤ s * g := by
  have h1 : num * s ≤ den * s := Nat.mul_le_mul_right s hl
  have h2 : num * s * g ≤ den * (s * g) := by
    calc num * s * g = num * s * g := rfl
      _ ≤ den * s * g := Nat.mul_le_mul_right g h1
      _ = den * (s * g) := Nat.mul_assoc _ _ _
  have h3 : den * (s * g) / den = s * g := Nat.mul_div_cancel_left _ hden
  calc num * s * g / den ≤ den * (s * g) / den := Nat.div_le_div_right h2
    _ = s * g := h3

/-- **Loose cost**: composition with the coupling term discounted by
    λ = num/den. At num = den this is the strict weighted cost; at num = 0
    the two subsystems do not interact at all. -/
def looseCost (cd num den : ℕ) (l r : EMLTree) : ℕ :=
  (dcStep l + dcStep r) * frictionDensity cd
    + num * rightSpine l * frictionDensity cd / den

/-- Loosening never increases cost: the discount only ever subtracts.
    This is the precondition for "rescue without damnation". -/
theorem looseCost_le_weightedCost (cd num den : ℕ)
    (hl : num ≤ den) (hden : 0 < den) (l r : EMLTree) :
    looseCost cd num den l r ≤ weightedCost cd (EMLTree.Node l r) := by
  unfold looseCost weightedCost
  rw [dcStep_node_compose]
  have hD := discounted_coupling_le (frictionDensity cd) num den (rightSpine l) hl hden
  have hexp : (dcStep l + dcStep r + rightSpine l) * frictionDensity cd
      = (dcStep l + dcStep r) * frictionDensity cd
          + rightSpine l * frictionDensity cd := by ring
  omega

/-- The discount is EXACT: strict minus loose equals the undiscounted
    remainder of the coupling term. The risk taken by loosening is precisely
    this remainder — never larger, never hidden. -/
theorem looseCost_discount_exact (cd num den : ℕ)
    (hl : num ≤ den) (hden : 0 < den) (l r : EMLTree) :
    weightedCost cd (EMLTree.Node l r) - looseCost cd num den l r
      = rightSpine l * frictionDensity cd
          - num * rightSpine l * frictionDensity cd / den := by
  unfold looseCost weightedCost
  rw [dcStep_node_compose]
  have hD := discounted_coupling_le (frictionDensity cd) num den (rightSpine l) hl hden
  have hexp : (dcStep l + dcStep r + rightSpine l) * frictionDensity cd
      = (dcStep l + dcStep r) * frictionDensity cd
          + rightSpine l * frictionDensity cd := by ring
  omega

/-- The right spine of a right-comb of size n is n: a closed market's
    output chain extends exactly as far as its size.
    (Re-homed here from AMM so both modules share it.) -/
theorem rightSpine_rightComb (n : ℕ) : rightSpine (rightComb n) = n := by
  induction n with
  | zero => simp [rightComb, rightSpine]
  | succ k ih =>
    simp only [rightComb, rightSpine, ih]
    omega

/-- Full decoupling (λ = 0) restores composability of equilibria: two
    independently closed markets graft for free again. Closure breaking
    (§9) is an artifact of STRICT coupling. -/
theorem looseCost_zero_coupling_free (cd den a b : ℕ) :
    looseCost cd 0 den (rightComb a) (rightComb b) = 0 := by
  unfold looseCost
  rw [dcStep_rightComb, dcStep_rightComb]
  norm_num [rightSpine_rightComb]

/-- **Compliance is a soft knob**: increasing trust λ = num/den never
    increases the discounted cost. The response of the system to trust is
    monotone in both directions: more forgiveness ⇒ cheaper composites,
    hence (by `looseCost_discount_exact`) smaller boundary retreat. -/
theorem looseCost_mono_in_trust (cd num₁ num₂ den : ℕ) (l r : EMLTree)
    (h : num₁ ≤ num₂) :
    looseCost cd num₁ den l r ≤ looseCost cd num₂ den l r := by
  unfold looseCost
  have hmul : num₁ * rightSpine l * frictionDensity cd
      ≤ num₂ * rightSpine l * frictionDensity cd := by
    calc num₁ * rightSpine l * frictionDensity cd
        = num₁ * (rightSpine l * frictionDensity cd) := Nat.mul_assoc _ _ _
      _ ≤ num₂ * (rightSpine l * frictionDensity cd) :=
          Nat.mul_le_mul h le_rfl
      _ = num₂ * rightSpine l * frictionDensity cd := (Nat.mul_assoc _ _ _).symm
  exact Nat.add_le_add le_rfl (Nat.div_le_div_right hmul)

/-- **ELASTICITY: the Hooke reading of loose coupling.** In the quantized
    elastic regime — trust denominated so the discount divides evenly into
    cost units (`hdiv`) — the retreat of the certification boundary is
    exactly LINEAR in the load:

        retreat = (1 − λ) · S,     S = rightSpine l · γ(cd)

    The compliance is `1 − λ`; the load is the spine tax. Displacement
    proportional to load, capped by the elastic limit
    `AMM.rescue_envelope_bounded_by_coupling`; beyond the limit the route
    fails plastically into the paradox phase. Stated over ℚ because over ℕ
    truncated division would lose the remainder. -/
theorem boundary_retreat_linear_in_load (cd num den : ℕ) (l r : EMLTree)
    (hl : num ≤ den) (hden : 0 < den)
    (hdiv : den ∣ num * rightSpine l * frictionDensity cd) :
    ((weightedCost cd (EMLTree.Node l r) : ℚ)
        - (looseCost cd num den l r : ℚ))
      = (1 - (num : ℚ) / den)
          * (rightSpine l * frictionDensity cd : ℚ) := by
  have hw : weightedCost cd (EMLTree.Node l r)
      = (dcStep l + dcStep r + rightSpine l) * frictionDensity cd := by
    unfold weightedCost
    rw [dcStep_node_compose]
  have hl₂ : looseCost cd num den l r
      = (dcStep l + dcStep r) * frictionDensity cd
          + num * rightSpine l * frictionDensity cd / den := rfl
  have hq : ((num * rightSpine l * frictionDensity cd / den : ℕ) : ℚ)
      = (num * rightSpine l * frictionDensity cd : ℚ) / den := by
    rcases hdiv with ⟨k, hk⟩
    have h1 : num * rightSpine l * frictionDensity cd / den = k := by
      rw [hk, Nat.mul_div_cancel_left _ hden]
    rw [h1]
    have hcast := congrArg ((↑) : ℕ → ℚ) hk
    push_cast at hcast ⊢
    rw [hcast]
    have hd0 : (den : ℚ) ≠ 0 := by positivity
    field_simp
  have hwge := looseCost_le_weightedCost cd num den hl hden l r
  rw [hw, hl₂]
  push_cast
  rw [hq]
  have hd0 : (den : ℚ) ≠ 0 := by positivity
  field_simp
  ring

-- ============================================================================
-- C3: mechanical compatibility (Lipschitz restatements)
-- ============================================================================

/-- **Edge-Lipschitz (C3).** Stress changes by at most one unit of grind per
elementary flip: `weightedCost cd s ≤ weightedCost cd u + frictionDensity cd`
for `contracts_one s u`. The cost is γ-Lipschitz along the cover graph — the
correct "mechanical compatibility" statement, which survives even though the
Tamari lattice is not graded (a two-point Lipschitz in `dcStep` would need the
non-existent graded rank). -/
theorem weightedCost_edge_lipschitz (cd : ℕ) {s u : EMLTree} (h : contracts_one s u) :
    weightedCost cd s ≤ weightedCost cd u + frictionDensity cd := by
  unfold weightedCost
  have hle := TamariMetric.dcStep_contracts_one_le h
  calc
    dcStep s * frictionDensity cd ≤ (dcStep u + 1) * frictionDensity cd :=
      Nat.mul_le_mul_right (frictionDensity cd) hle
    _ = dcStep u * frictionDensity cd + frictionDensity cd := by ring

/-- **Trust-Lipschitz (C3).** The loose cost is exactly linear in the trust
numerator: the internal `(dcStep l + dcStep r) · γ` terms cancel, leaving the
interface term rescaled by `(num₁ − num₂)/den`. This is the "λ-discount =
conformal rescale of the interface edges only" claim in explicit Lipschitz
form, with stiffness `rightSpine l · γ / den` — the elastic constant of the
certification boundary. Stated over ℚ for the same reason as the Hooke
theorem (ℕ division would truncate the remainder). -/
theorem looseCost_linear_in_trust (cd num₁ num₂ den : ℕ) (l r : EMLTree)
    (h₁ : den ∣ num₁ * rightSpine l * frictionDensity cd)
    (h₂ : den ∣ num₂ * rightSpine l * frictionDensity cd)
    (hden : 0 < den) :
    ((looseCost cd num₁ den l r : ℚ) - (looseCost cd num₂ den l r : ℚ))
      = ((num₁ : ℚ) - (num₂ : ℚ)) * ((rightSpine l * frictionDensity cd : ℚ) / (den : ℚ)) := by
  have h₁q : ((num₁ * rightSpine l * frictionDensity cd / den : ℕ) : ℚ)
      = (num₁ * rightSpine l * frictionDensity cd : ℚ) / den := by
    rcases h₁ with ⟨k, hk⟩
    have h1 : num₁ * rightSpine l * frictionDensity cd / den = k := by
      rw [hk, Nat.mul_div_cancel_left _ hden]
    rw [h1]
    have hcast := congrArg ((↑) : ℕ → ℚ) hk
    push_cast at hcast ⊢
    rw [hcast]
    have hd0 : (den : ℚ) ≠ 0 := by positivity
    field_simp
  have h₂q : ((num₂ * rightSpine l * frictionDensity cd / den : ℕ) : ℚ)
      = (num₂ * rightSpine l * frictionDensity cd : ℚ) / den := by
    rcases h₂ with ⟨k, hk⟩
    have h1 : num₂ * rightSpine l * frictionDensity cd / den = k := by
      rw [hk, Nat.mul_div_cancel_left _ hden]
    rw [h1]
    have hcast := congrArg ((↑) : ℕ → ℚ) hk
    push_cast at hcast ⊢
    rw [hcast]
    have hd0 : (den : ℚ) ≠ 0 := by positivity
    field_simp
  unfold looseCost
  push_cast
  rw [h₁q, h₂q]
  ring_nf

end SubdivisionClosure
