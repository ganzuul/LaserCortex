import Mathlib
import LaserCortex.staging.Algebra
import LaserCortex.staging.Tamari
import LaserCortex.staging.Friction
import LaserCortex.staging.OctilinearEmbedding

/-!
# Graphiti Embedding — Formal Mapping from Community Structure to Transit Coordinates

This file formalizes the mapping from Graphiti community properties to the
octolinear coordinate embedding used in the CD tower transit map.

The mapping (mirrored in `scripts/graphiti_to_transit_map.py`):

    For a community C with:
      size(C)      = number of member entities
      leftWeight(C)  = inbound references from outside the community
      rightWeight(C) = outbound references to outside the community
      assocDefect(C) = 0 if all coupling signatures are ≤ non_commutative,
                       4 if any signature is non_associative

    The KKT multiplier is:
      λ_C = (size(C), leftWeight(C), rightWeight(C), assocDefect(C)) ∈ SplitQuat

    The transit coordinate is:
      transitCoord cd C = (size(C) + assocDefect(cd), leftWeight(C) − rightWeight(C))

Key theorems:
  - `communityEmbedding_antipode_grading` — Even → x, Odd → y
  - `communityEmbedding_coupling_to_assocDefect` — coupling regime → assocDefect
  - `communityEmbedding_phase_change` — phase transition at non_associative boundary
-/

namespace GraphitiEmbedding

-- ============================================================================
-- Coupling signatures as an inductive type
-- ============================================================================

/--
The three coupling regimes that a Graphiti NormNode can have.
Mirrors the Python `Literal["commutative", "non_commutative", "non_associative"]`
used in `infra/_graphiti_models.py` and `infra/_cortex/_spec.py`.
-/
inductive CouplingSignature : Type where
  | commutative       : CouplingSignature  -- CD ≤ 2, associative
  | non_commutative   : CouplingSignature  -- CD 2, loses commutativity
  | non_associative   : CouplingSignature  -- CD ≥ 3, loses associativity
  deriving DecidableEq, Repr

open CouplingSignature

-- ============================================================================
-- Mapping from coupling signature to assocDefect
-- ============================================================================

/--
`assocDefect_for_coupling cs` = 0 for commutative and non_commutative,
= 4 (strut_weight) for non_associative.

This formalizes the Python function `assoc_defect_for_coupling` in
`scripts/graphiti_to_transit_map.py`.
-/
def assocDefect_for_coupling (cs : CouplingSignature) : ℕ :=
  match cs with
  | commutative       => 0
  | non_commutative   => 0
  | non_associative   => strut_weight

/--
For commutative and non_commutative signatures, the associator defect is zero.
This matches `assocDefect_zero_up_to_cd2` from Friction.lean: CD ≤ 2 → assocDefect = 0.
-/
theorem assocDefect_for_coupling_zero_upto_noncomm (cs : CouplingSignature)
    (h : cs ≠ non_associative) : assocDefect_for_coupling cs = 0 := by
  cases cs
  · rfl  -- commutative → 0
  · rfl  -- non_commutative → 0
  · exfalso; exact h rfl  -- non_associative → contradiction

/--
For non_associative signatures, the associator defect equals strut_weight (4).
This matches `assocDefect_positive_for_cd3plus` from Friction.lean: CD ≥ 3 → assocDefect = 4.
-/
theorem assocDefect_for_coupling_non_associative (cs : CouplingSignature)
    (h : cs = non_associative) : assocDefect_for_coupling cs = strut_weight := by
  subst h; rfl

/--
The dominant coupling regime determines the community's CD step.
- commutative       → effective CD step 0 (SplitComplex level)
- non_commutative   → effective CD step 2 (SplitQuat level)
- non_associative   → effective CD step 3+ (SplitOctonion level)

This mirrors `regime_cd_step` in `scripts/graphiti_to_transit_map.py`.
-/
def regimeCDStep (cs : CouplingSignature) : ℕ :=
  match cs with
  | commutative       => 0
  | non_commutative   => 2
  | non_associative   => 3

/--
The CD step threshold for non-associativity: any CD step ≥ 3 is non-associative.
-/
theorem regimeCDStep_ge_3_iff_non_associative (cs : CouplingSignature) :
    3 ≤ regimeCDStep cs ↔ cs = non_associative := by
  cases cs <;> simp [regimeCDStep]

-- ============================================================================
-- Community KKT multiplier
-- ============================================================================

/--
A community structure record, abstracting the Graphiti community graph properties.

This is the semantic "grounding" of a Graphiti community in the CD algebra:
each community becomes a point in SplitQuat space via the KKT multiplier.
-/
structure CommunityStructure where
  /-- Number of member entities in the community (KKT component a = size). -/
  size : ℕ
  /-- Number of inbound references from outside the community (KKT component b = leftWeight). -/
  leftWeight : ℕ
  /-- Number of outbound references to outside the community (KKT component c = rightWeight). -/
  rightWeight : ℕ
  /-- The dominant coupling regime across all member NormNodes. -/
  coupling : CouplingSignature

/--
The KKT multiplier for a community C:
    λ_C = (size, leftWeight, rightWeight, assocDefect(coupling)) ∈ SplitQuat

This mirrors `kktMultiplier` in `OctilinearEmbedding.lean` but for Graphiti communities
(instead of EMLTrees).
-/
def communityKKTMultiplier (C : CommunityStructure) : SplitQuat :=
  ⟨ (C.size : ℤ)
  , (C.leftWeight : ℤ)
  , (C.rightWeight : ℤ)
  , (assocDefect_for_coupling C.coupling : ℤ)
  ⟩

/--
The transit coordinate of a community C at CD step cd:
    transitCoord cd C = (size + assocDefect(cd), leftWeight − rightWeight)

Note: The assocDefect in the x-coordinate uses the *CD-step-dependent* assocDefect
(cd), not the community's own assocDefect. This is because the transit map
shows the same community at multiple CD levels (lines), and the assocDefect
at each CD level determines the horizontal offset.

This mirrors `transitCoord` in `OctilinearEmbedding.lean`.
-/
def communityTransitCoord (cd : ℕ) (C : CommunityStructure) : ℤ × ℤ :=
  ((C.size : ℤ) + (assocDefect cd : ℤ), (C.leftWeight : ℤ) - (C.rightWeight : ℤ))

-- ============================================================================
-- Antipode grading theorem
-- ============================================================================

/--
The covector projection of the community KKT multiplier respects the antipode grading:

    Even-grade components (size, assocDefect) → x-coordinate
    Odd-grade components (leftWeight, rightWeight) → y-coordinate

Under the grade involution (negating odd components), the y-coordinate flips
sign while the x-coordinate stays unchanged.

This mirrors `covectorProjection_antipode` in `OctilinearEmbedding.lean`.
-/
theorem communityEmbedding_antipode_grading (C : CommunityStructure) :
    let λ := communityKKTMultiplier C
    let P (x : SplitQuat) : ℤ × ℤ := (x.a + x.d, x.b - x.c)
    P (SplitQuat.grade λ) = ((P λ).1, -(P λ).2) := by
  intro λ P
  have h_grade : SplitQuat.grade λ = ⟨(C.size : ℤ), -(C.leftWeight : ℤ), -(C.rightWeight : ℤ), (assocDefect_for_coupling C.coupling : ℤ)⟩ := by
    simp [communityKKTMultiplier, SplitQuat.grade]
  rw [h_grade]
  simp [P, communityKKTMultiplier]

-- ============================================================================
-- Coupling → assocDefect theorem
-- ============================================================================

/--
The community's assocDefect is zero iff its coupling regime is associative
or non-commutative (i.e., not non_associative).

This formalizes the Python function `assoc_defect_for_coupling` and the
dominant regime logic: a community whose strongest coupling signature is
less than non_associative has assocDefect = 0.
-/
theorem communityEmbedding_coupling_to_assocDefect (C : CommunityStructure) :
    assocDefect_for_coupling C.coupling = 0 ↔ C.coupling ≠ non_associative := by
  constructor
  · intro h0 hna
    have : assocDefect_for_coupling C.coupling = strut_weight :=
      assocDefect_for_coupling_non_associative C.coupling hna
    rw [h0] at this
    have hsw : strut_weight ≠ 0 := by
      have : strut_weight = 4 := strut_weight_eq_four
      omega
    exact hsw this
  · intro hne
    exact assocDefect_for_coupling_zero_upto_noncomm C.coupling hne

-- ============================================================================
-- Phase change theorem
-- ============================================================================

/--
The phase change at CD 3: communities with a non_associative coupling regime
transition to the (4,4) norm signature, adding strut_weight to the x-coordinate
of the transit coordinate.

For a non-associative community, the difference in transit coordinate
between CD level 3 (SplitOctonion) and CD level 2 (SplitQuat) is exactly
strut_weight in the x-direction, and zero in the y-direction.

    transitCoord 3 C − transitCoord 2 C = (strut_weight, 0)

This mirrors `transitCoord_cd3_vs_cd2` in `OctilinearEmbedding.lean`.
-/
theorem communityEmbedding_phase_change (C : CommunityStructure)
    (h : C.coupling = non_associative) :
    (communityTransitCoord 3 C).1 - (communityTransitCoord 2 C).1 = (strut_weight : ℤ) := by
  dsimp [communityTransitCoord]
  have had3 : assocDefect 3 = strut_weight :=
    assocDefect_positive_for_cd3plus 3 (by omega)
  have had2 : assocDefect 2 = 0 :=
    assocDefect_zero_up_to_cd2 2 (by omega)
  simp [had3, had2]
  omega

/--
For a community without non_associative coupling, the transit coordinate
difference between CD 3 and CD 2 is still strut_weight in x (because the
CD step's assocDefect depends only on the CD level, not the community).
But the y-coordinate is always unchanged between CD levels.
-/
theorem communityEmbedding_y_stable_across_cd (C : CommunityStructure) (cd₁ cd₂ : ℕ) :
    (communityTransitCoord cd₁ C).2 = (communityTransitCoord cd₂ C).2 := by
  dsimp [communityTransitCoord]
  simp

-- ============================================================================
-- Lattice ordering theorem (optional)
-- ============================================================================

/--
Communities ordered by (size, asymmetry) in the transit map are totally ordered
and the x-coordinate is strictly increasing with size (modulo assocDefect jumps
at the phase change).
-/
theorem communityEmbedding_x_monotone_in_size (cd : ℕ) (C₁ C₂ : CommunityStructure)
    (hsize : C₁.size < C₂.size) :
    (communityTransitCoord cd C₁).1 < (communityTransitCoord cd C₂).1 := by
  dsimp [communityTransitCoord]
  have hsz_int : (C₁.size : ℤ) < (C₂.size : ℤ) := by exact_mod_cast hsize
  omega

end GraphitiEmbedding
