import Mathlib
import LaserCortex.staging.Algebra
import LaserCortex.staging.Tamari

/-!
# Friction Lagrangian — Cost Landscape

Cost landscape connecting Cayley-Dickson algebra to Tamari trees.
The associator defect activates sharply at CD 3 (split octonions).

## Key definitions
- `assocDefect` — 0 for cdStep ≤ 2 (associative), strut_weight for cdStep ≥ 3
- `frictionDensity` — cost per Tamari step: α·commDefect + β·assocDefect
- `layerCost` — total cost of a tree contraction

## Key theorems
- `assocDefect_phase_change` — phase change at cdStep 2→3
- `frictionDensity_monotone` — frictionDensity monotone with cdStep
- `heightMap_discontinuity` — discontinuity at the associative/non-associative boundary
-/

-- ============================================================================
-- SECTION 1: Defect Magnitudes
-- ============================================================================

/-- The associator defect magnitude at CD step k.
    0 for CD ≤ 2 (associative: ℝ, ℂ, ℍ, Cl(1,1) ≅ ℍ̃)
    strut_weight for CD ≥ 3 (non-associative: split octonions) -/
def assocDefect (k : ℕ) : ℕ :=
  if k ≤ 2 then 0 else strut_weight

/-- The commutator defect magnitude at CD step k.
    Grows linearly: 0 for ℝ, 1 for ℂ, 2 for ℍ, etc. -/
def commDefect (k : ℕ) : ℕ := k

/-- The friction density at CD step k:
    Γ_k = commDefect(k) + strut_weight·assocDefect(k)

    This is the cost per Tamari step. At CD 2' (Cl(1,1) boundary) the
    associator term vanishes: Γ_2 = 2. At CD 3 (split octonions) the
    associator activates: Γ_3 = 3 + strut_weight² = 19. -/
def frictionDensity (k : ℕ) : ℕ :=
  commDefect k + strut_weight * assocDefect k

-- ============================================================================
-- SECTION 2: Layer Cost
-- ============================================================================

/-- The true cost for a logic type under the Friction Lagrangian.
    layerCost(lt) = Γ(lt.cdStep) = cdStep + strut_weight·assocDefect(cdStep)

    For associative logics (cdStep ≤ 2), this equals cdStep.
    For non-associative logics (cdStep ≥ 3), this exceeds cdStep. -/
def layerCost (lt : LogicType) : ℕ :=
  frictionDensity lt.cdStep

/-- The true cost is at least the old cdStep cost:
    layerCost(lt) ≥ lt.cdStep. For associative logics they are equal.
    For non-associative logics the Lagrangian is strictly larger. -/
theorem layerCost_ge_cdStep (lt : LogicType) : layerCost lt ≥ lt.cdStep := by
  dsimp [layerCost, frictionDensity, commDefect, assocDefect]
  split <;> omega

/-- For associative logics (cdStep ≤ 2), layerCost equals cdStep.
    Covers Classical, Fuzzy, Intuitionistic, and Cl(1,1) ≅ ℍ̃ boundary. -/
theorem layerCost_eq_cdStep_for_assoc (lt : LogicType) (h : lt.cdStep ≤ 2) :
    layerCost lt = lt.cdStep := by
  dsimp [layerCost, frictionDensity, commDefect, assocDefect]
  have : ¬ 3 ≤ lt.cdStep := by omega
  simp [h]

-- ============================================================================
-- SECTION 3: Phase Change Theorems
-- ============================================================================

/-- The associator defect is zero for CD steps ≤ 2.
    Full associative regime: ℝ, ℂ, ℍ, Cl(1,1) ≅ ℍ̃. -/
theorem assocDefect_zero_up_to_cd2 : ∀ k, k ≤ 2 → assocDefect k = 0 := by
  intro k hk
  dsimp [assocDefect]
  split
  · rfl
  · omega

/-- The associator defect equals strut_weight for CD steps ≥ 3.
    Sharp phase change at CD 2→3: non-associative split octonions. -/
theorem assocDefect_positive_for_cd3plus : ∀ k, 3 ≤ k → assocDefect k = strut_weight := by
  intro k hk
  dsimp [assocDefect]
  split
  · omega
  · rfl

/-- At the Cl(1,1) boundary (CD 2'), frictionDensity is purely commutative:
    Γ_2 = 2. Zero divisors present but associativity preserved. -/
theorem frictionDensity_at_cl11_boundary : frictionDensity 2 = 2 := by
  unfold frictionDensity commDefect assocDefect strut_weight
  decide

/-- The friction density jumps sharply at CD 3:
    Γ_3 = Γ_2 + 1 + strut_weight² = 2 + 1 + 16 = 19.
    The associator barrier (strut_weight² = 16) dwarfs the commutator increment (+1). -/
theorem frictionDensity_jump_at_cd3 :
    frictionDensity 3 = frictionDensity 2 + 1 + strut_weight * strut_weight := by
  unfold strut_weight
  native_decide

-- ============================================================================
-- SECTION 4: Height Map
-- ============================================================================

/-- FrictionDensity is monotone with cdStep:
    higher CD steps have strictly greater friction density, with a
    discontinuity at CD 2→3. -/
theorem frictionDensity_monotone (j k : ℕ) (h : j < k) : frictionDensity j ≤ frictionDensity k := by
  dsimp [frictionDensity, commDefect, assocDefect]
  have hsw : strut_weight = 4 := strut_weight_eq_four
  by_cases hk2 : k ≤ 2
  · have hj2 : j ≤ 2 := by omega
    simp [hj2, hk2, hsw]
    omega
  · by_cases hj2 : j ≤ 2
    · simp [hj2, hk2, hsw]
      omega
    · have hj3 : 3 ≤ j := by omega
      simp [hj2, hk2, hsw]
      omega

/-- The height map has a discontinuity at CD 2→3.
    Γ_3 / Γ_2 = (3 + 16) / 2 = 9.5 > 2.
    The associator barrier more than triples the cost. -/
theorem heightMap_discontinuity_at_cd2_3 :
    frictionDensity 3 > 2 * frictionDensity 2 := by
  dsimp [frictionDensity, commDefect, assocDefect]
  native_decide