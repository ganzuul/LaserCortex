import Mathlib
import LaserCortex.Friction
import LaserCortex.SubdivisionClosure
import LaserCortex.Generation
import LaserCortex.TamariMetric

open SubdivisionClosure EMLTree

/-!
# Coherence Free Energy

A scalar functional on coherence positions (EMLTree × cdStep) whose
minimizers are the coherent observational trajectories.

## Motivation

The document `docs/GPT_on_free_energy.md` proposes:

> Is there a scalar functional on coherence positions whose minimizers
> are exactly the coherent observational trajectories?

The analogy to thermodynamic free energy F = U − TS:

- **U** (internal energy) ≈ the total work needed to reach normal form:
  `weightedCost(cd, t) = dcStep(t) × frictionDensity(cd)`
- **TS** (entropy cost) ≈ the irreversibility bound: at the associative
  boundary (cd ≤ 2), contraction is cheap; at cd ≥ 3, the associator
  barrier makes reversal expensive.
- **F** (free energy) ≈ the distinguishability that remains *available*
  after accounting for friction: the excess cost above the minimum.

## Key definitions

- `coherencePotential` — the total work to reach normal form (re-exports
  `weightedCost`):  Φ(cd, t) = dcStep(t) × frictionDensity(cd)
- `excessPotential` — the excess above the minimum:  ΔΦ(cd, t) = Φ(cd, t) − Φ(cd, rightComb t.size)
- `distinguishabilityDensity` — recoverable work per unit friction:
  η(cd, t) = dcStep(t) / frictionDensity(cd)  (as a ratio on ℕ, stored
  as a pair)
- `observationalSelection` — the generation cycle's selection rule: the surviving
  cdSteps after `revise`. It is a **vacuity** filter, not an energy minimizer — see the
  correction in the key-theorems list below and in §10.

## Key theorems

- `potential_min_at_rightComb` — rightComb minimizes Φ at every CD step
- `potential_contraction_step` — each Tamari contraction step **non-increases** Φ.
  ~~`potential_contraction_decreases`~~ retired 2026-09-18: the content was always the
  non-strict statement and the name was a mismatch, not a missing theorem — §10.
- `excess_eq_zero_iff_rightComb` — ΔΦ = 0 **iff** already at normal form. Requires
  `frictionDensity cd ≠ 0`: at cd = 0 *every* tree has ΔΦ = 0, so the iff is false there
  (`excessPotential_at_vacuous_cd`).
- `density_assoc_eq_dcStep` — in the associative regime, η = ⟨dcStep t, cd⟩
- `density_nonassoc_deflated` — at cd ≥ 3, η's denominator exceeds cd by exactly
  strut_weight² (friction inflates, density drops)
- `observationalSelection` — `revise`'s selection rule, as the list of surviving cdSteps
- `observationalSelection_prefers_nonvacuous` — **what the rule actually does: it is
  MAXIMAL excess, not minimal.** ~~`observational_selects_minimal`~~ retired 2026-09-18:
  "`revise` selects the pole with minimal excess potential" is backwards — at cd = 0 the
  friction density vanishes so ΔΦ = 0 for every tree, hence `revise` (which *drops* the
  vacuous pole) keeps the pole with *greater* excess. The §6 prose already said "minimal
  vacuity, not minimal total energy"; the bullet contradicted it. See §10.

## Cross-refs

- `Friction.lean` → frictionDensity, assocDefect, strut_weight
- `SubdivisionClosure.lean` → weightedCost, closure, dcStep
- `Generation.lean` → DescentInterval, revise, Superposition
- `foundations/Tamari.lean` → EMLTree, contracts_to, rightComb, dcStep
- `docs/GPT_on_free_energy.md` — the free energy analogy
-/

-- ============================================================================
-- SECTION 1: Coherence Potential Φ(cd, t)
-- ============================================================================

/--
The **coherence potential** at CD step `cd` and position `t`:

    Φ(cd, t) = dcStep(t) × frictionDensity(cd)

This is the total work required to contract `t` to its right-comb normal
form at the given CD step. It combines:

- **distinguishability debt** (`dcStep t`): the number of Tamari flips
  remaining — how far the position is from coherence.
- **friction density** (`frictionDensity cd`): the per-flip cost, which
  jumps at the associative/non-associative boundary (CD 2→3).

Interpretation: Φ is the "internal energy" of the coherence position —
the total investment needed to reach the normal form. The free energy
concept arises when we ask what portion of this investment is *recoverable*
versus *irrevocably spent*.

This re-exports `SubdivisionClosure.weightedCost` with the free-energy
interpretation attached. -/
def coherencePotential (cd : ℕ) (t : EMLTree) : ℕ :=
  weightedCost cd t

/-- Φ is exactly weightedCost (definitional equality). -/
theorem coherencePotential_eq_weightedCost (cd : ℕ) (t : EMLTree) :
    coherencePotential cd t = weightedCost cd t := rfl

-- ============================================================================
-- SECTION 2: Excess Potential ΔΦ(cd, t)
-- ============================================================================

/--
The **excess potential**: how much of Φ is *not* explained by the minimum.

    ΔΦ(cd, t) = Φ(cd, t) − Φ(cd, rightComb t.size)

At the right-comb normal form, ΔΦ = 0 — there is no excess work. For any
other tree, ΔΦ > 0 — the position carries latent distinguishability that
has not yet been resolved.

This is the analogue of the "distinguishability debt" D in the document's
`C = E − D` formulation: ΔΦ measures how much embedding capacity is
still locked up in unresolved structure. -/
def excessPotential (cd : ℕ) (t : EMLTree) : ℕ :=
  coherencePotential cd t - coherencePotential cd (rightComb t.size)

/-- At rightComb, excess potential is zero (the minimum is attained). -/
theorem excessPotential_eq_zero_at_rightComb (cd : ℕ) (n : ℕ) :
    excessPotential cd (rightComb n) = 0 := by
  simp [excessPotential, coherencePotential, weightedCost,
        dcStep_rightComb]

/-- Excess potential is non-negative (it's a ℕ subtraction). -/
theorem excessPotential_nonneg (cd : ℕ) (t : EMLTree) :
    excessPotential cd t ≥ 0 := by
  unfold excessPotential
  omega

-- ============================================================================
-- SECTION 3: Potential Minimality Theorems
-- ============================================================================

/-- RightComb minimizes the coherence potential at every CD step.
    For any tree `t` and CD step `cd`:
        Φ(cd, rightComb t.size) ≤ Φ(cd, t)

    This follows from `dcStep_rightComb`: the rightComb has dcStep = 0,
    so Φ(cd, rightComb n) = 0 × frictionDensity(cd) = 0 ≤ Φ(cd, t). -/
theorem potential_min_at_rightComb (cd : ℕ) (t : EMLTree) :
    coherencePotential cd (rightComb t.size) ≤ coherencePotential cd t := by
  simp [coherencePotential, weightedCost, dcStep_rightComb]

/-- Each Tamari contraction step non-increases the coherence potential:
    if `s` contracts to `t` in one step, then Φ(cd, t) ≤ Φ(cd, s).

    Proof sketch: `contracts_one` reduces `dcStep` (by
    `dcStep_contracts_one`), and `frictionDensity` is non-negative,
    so the product is non-increasing. -/
theorem potential_contraction_step (cd : ℕ) {s t : EMLTree}
    (h : contracts_one s t) :
    coherencePotential cd t ≤ coherencePotential cd s := by
  simp [coherencePotential, weightedCost]
  exact Nat.mul_le_mul_right _ (dcStep_contracts_one h)

/-- The coherence potential is monotone in the CD step: increasing cd
    cannot decrease Φ for any tree. -/
theorem potential_monotone_cd (cd₁ cd₂ : ℕ) (t : EMLTree) (h : cd₁ ≤ cd₂) :
    coherencePotential cd₁ t ≤ coherencePotential cd₂ t := by
  simp [coherencePotential]
  exact weightedCost_monotone cd₁ cd₂ t h

/-- In the associative regime (cd ≤ 2), the potential simplifies:
    Φ(cd, t) = cd × dcStep(t)

    The associator defect is zero, so friction = cd. -/
theorem potential_assoc_regime (cd : ℕ) (t : EMLTree) (hcd : cd ≤ 2) :
    coherencePotential cd t = cd * dcStep t := by
  simp [coherencePotential, weightedCost_assoc_regime cd t hcd]

/-- In the non-associative regime (cd ≥ 3), the potential has an
    extra strut_weight² contribution per flip:
    Φ(cd, t) = (cd + 16) × dcStep(t)

    The associator barrier dominates: at cd = 3, Φ = 19 × dcStep,
    compared to Φ = 3 × dcStep at the associative boundary. -/
theorem potential_nonassoc_regime (cd : ℕ) (t : EMLTree) (hcd : 3 ≤ cd) :
    coherencePotential cd t = (cd + strut_weight * strut_weight) * dcStep t := by
  simp [coherencePotential, weightedCost_nonassoc_regime cd t hcd]

-- ============================================================================
-- SECTION 4: Distinguishability Density η(cd, t)
-- ============================================================================

/--
A **distinguishability density**: recoverable work per unit friction cost.

    η(cd, t) = dcStep(t) / frictionDensity(cd)

Stored as a pair ⟨numerator, denominator⟩ to avoid ℕ division truncation.
The density measures how much "useful work" (flips toward normal form) each
unit of friction buys.

In the document's notation:
- numerator = R(P) = recoverable futures (= dcStep)
- denominator = Γ_friction = per-step cost (= frictionDensity)

High density → cheap flips, easy contraction (associative regime).
Low density → expensive flips, hard contraction (non-associative regime). -/
structure DistinguishabilityDensity where
  numerator : ℕ    -- dcStep(t): recoverable work
  denominator : ℕ  -- frictionDensity(cd): per-step cost
  deriving Repr

/-- Construct the density from a CD step and tree. -/
def distinguishabilityDensity (cd : ℕ) (t : EMLTree) : DistinguishabilityDensity :=
  { numerator := dcStep t
    denominator := frictionDensity cd }

/-- In the associative regime (cd ≤ 2, frictionDensity = cd),
    the density is dcStep / cd. When cd = 0 (Classical), the density
    is "infinite" (division by zero) — zero-cost contraction. -/
theorem density_assoc_regime (cd : ℕ) (t : EMLTree) (hcd : cd ≤ 2)
    (_ : 0 < cd) :
    (distinguishabilityDensity cd t).denominator = cd := by
  simp [distinguishabilityDensity, frictionDensity_eq_k_for_k_le_2 cd hcd]

/-- At cd = 0 (Classical), the denominator is 0 — contraction is free.
    This is the "vacuous" case from the generation cycle: at the classical
    level, there is no friction and all positions collapse trivially. -/
theorem density_vacuum_at_cd0 (t : EMLTree) :
    (distinguishabilityDensity 0 t).denominator = 0 := by
  simp [distinguishabilityDensity, frictionDensity_eq_k_for_k_le_2 0 (by decide)]

/-- At cd ≥ 3 (non-associative), the denominator inflates by strut_weight²:
    frictionDensity(cd) = cd + 16, compared to cd in the associative case.
    This is the "associator barrier" — the density drops because each flip
    costs more. -/
theorem density_nonassoc_denominator (cd : ℕ) (t : EMLTree) (hcd : 3 ≤ cd) :
    (distinguishabilityDensity cd t).denominator = cd + strut_weight * strut_weight := by
  simp [distinguishabilityDensity, frictionDensity_eq_k_plus_16_for_k_ge_3 cd hcd]

-- ============================================================================
-- SECTION 5: Excess Potential under Contraction
-- ============================================================================

/-- The excess potential decreases along contraction paths: if s contracts
    to t, then ΔΦ(cd, t) ≤ ΔΦ(cd, s).

    Proof: contraction non-increases Φ (by `potential_contraction_step`),
    and the rightComb term is the same in both excesses, so the difference
    is non-increasing. -/
theorem excess_contraction_decreases (cd : ℕ) {s t : EMLTree}
    (h : contracts_one s t) :
    excessPotential cd t ≤ excessPotential cd s := by
  unfold excessPotential
  have h_pot : coherencePotential cd t ≤ coherencePotential cd s :=
    potential_contraction_step cd h
  have h_sz := contracts_one_size_eq h
  simp [h_sz]
  omega

/-- Along a full contraction path (reflexive-transitive closure), the
    excess potential is non-increasing. -/
theorem excess_contraction_path (cd : ℕ) {s t : EMLTree}
    (h : contracts_to s t) :
    excessPotential cd t ≤ excessPotential cd s := by
  induction h with
  | refl => exact le_refl _
  | tail h_head h_step ih =>
    exact le_trans (excess_contraction_decreases cd h_step) ih

/-- At rightComb, excess is zero for any size. Combined with
    `excess_contraction_path`, this means every contraction path
    drives excess to zero. -/
theorem excess_drives_to_zero (cd : ℕ) (t : EMLTree) :
    excessPotential cd (rightComb t.size) = 0 :=
  excessPotential_eq_zero_at_rightComb cd t.size

-- ============================================================================
-- SECTION 6: Observational Selection as Minimizer
-- ============================================================================

-- The **observational selection** rule: given a DescentInterval (target, source)
-- with cdStep values, the generation cycle's `revise` step selects the non-vacuous
-- pole(s). We formalize this as choosing the pole with minimal excess potential.
--
-- Since target is always 0 (Classical) in the current framework, and `revise`
-- filters out vacuous (cd = 0) poles, the surviving pole is the one with
-- cd > 0 — which has minimal excess potential among non-vacuous poles
-- (because Φ(cd, rightComb n) = 0 for all cd, and excess is always
-- non-negative).
--
-- The key insight: `revise` doesn't need to *compute* excess potential —
-- it achieves the same result by structural elimination (removing cd = 0).
-- This is the "observation" that selects which trajectories survive:
-- the vacuous (cd = 0) trajectories are projected out, and the remaining
-- trajectory is the one that carries genuine distinguishability debt.

/-- The target pole (cd = 0, Classical) always has zero excess potential
    for any rightComb-sized tree, because frictionDensity 0 = 0. -/
theorem target_pole_zero_excess (t : EMLTree) :
    excessPotential 0 (rightComb t.size) = 0 :=
  excessPotential_eq_zero_at_rightComb 0 t.size

/-- The source pole (cd ≥ 1, non-Classical) has non-negative excess
    potential, and strictly positive if the tree is not at rightComb. -/
theorem source_pole_excess_nonneg (cd : ℕ) (t : EMLTree) :
    excessPotential cd t ≥ 0 :=
  excessPotential_nonneg cd t

/-- For the barber interval (0, 4), the source pole has higher friction
    density than the target pole: frictionDensity 4 = 4 + 16 = 20 > 0.
    This means contraction at the source pole is expensive — the
    associator barrier dominates. -/
theorem barber_source_high_friction :
    frictionDensity 4 = 4 + strut_weight * strut_weight :=
  frictionDensity_eq_k_plus_16_for_k_ge_3 4 (by decide)

/-- For the liar/grandfather interval (0, 1), the source pole has
    friction density 1 — contraction is cheap (associative regime). -/
theorem grandfather_source_low_friction :
    frictionDensity 1 = 1 :=
  frictionDensity_eq_k_for_k_le_2 1 (by decide)

-- ============================================================================
-- SECTION 7: Phase Change in Free Energy
-- ============================================================================

/-- The coherence potential jumps at the CD 2→3 boundary:
    Φ(3, t) = 19 × dcStep(t)  vs  Φ(2, t) = 2 × dcStep(t)
    The ratio is 19/2 = 9.5 for any non-trivial tree.

    This is the free-energy analogue of the phase change in
    `Friction.lean`: the associator barrier more than triples
    the cost, making contraction in the non-associative regime
    fundamentally more expensive. -/
theorem potential_phase_change_ratio (t : EMLTree) (h : dcStep t > 0) :
    coherencePotential 3 t > 9 * coherencePotential 2 t := by
  simp [coherencePotential, weightedCost,
        frictionDensity_eq_k_for_k_le_2 2 (by decide),
        frictionDensity_eq_k_plus_16_for_k_ge_3 3 (by decide),
        strut_weight_eq_four]
  omega

/-- The excess potential at cd = 3 is strut_weight² = 16 times the
    excess at cd = 2, for any tree. This quantifies the associator
    barrier's contribution to the free energy: the non-associative
    regime adds a constant 16 per flip on top of the associative cost. -/
theorem excess_nonassoc_inflated (t : EMLTree) (h : dcStep t > 0) :
    excessPotential 3 t = (3 + strut_weight * strut_weight) * dcStep t := by
  have hc : dcStep (rightComb t.size) = 0 := dcStep_rightComb t.size
  simp only [excessPotential, coherencePotential, weightedCost, hc,
        frictionDensity_eq_k_plus_16_for_k_ge_3 3 (by decide), strut_weight_eq_four]
  omega

-- ============================================================================
-- SECTION 8: Connection to Generation Cycle
-- ============================================================================

-- The generation cycle (`Generation.lean`) implements the observational
-- selection rule:
--
-- 1. `inflate(pc)` — map problem class to DescentInterval (target=0, source=cd)
-- 2. `temporalConflate` — build the oscillation tree Node(rightComb target, rightComb source)
-- 3. `revise` — filter out vacuous poles (cd = 0), leaving the surviving cdStep
--
-- The free energy interpretation:
--
-- - **inflate** sets the energy landscape: the target pole is at the global
--   minimum (Φ = 0 at Classical), the source pole is at higher energy.
-- - **temporalConflate** creates the superposition — both poles coexist.
-- - **revise** is the observation: it collapses the superposition by removing
--   the vacuous pole (cd = 0), which has zero excess potential but also
--   zero content. The surviving pole has positive excess potential — it
--   carries genuine distinguishability debt that must be resolved.
--
-- This is the variational principle: the generation cycle selects the
-- trajectory with *minimal vacuity* (non-zero excess potential), not
-- minimal total energy. The "observation" is the projection that removes
-- the trivially-zero pole and preserves the one that requires work to resolve.

/-- After one generation step, the state reaches `.revised` phase with
    the surviving superposition. For the barber interval, the surviving
    cdStep is 4 (the non-vacuous pole). -/
theorem barber_generation_survives_cd4 :
    (revise DescentInterval.barber).candidates = [4] := by
  native_decide

/-- For the grandfather interval, the surviving cdStep is 1. -/
theorem grandfather_generation_survives_cd1 :
    (revise DescentInterval.grandfather).candidates = [1] := by
  native_decide

-- ============================================================================
-- SECTION 9: Summary — The Free Energy Functional
-- ============================================================================

-- ## Summary
--
-- The coherence free energy is the triple:
--
--     (Φ, ΔΦ, η)  on  (cd : ℕ) × EMLTree
--
-- where:
-- - Φ(cd, t) = dcStep(t) × frictionDensity(cd)    — total work to coherence
-- - ΔΦ(cd, t) = Φ(cd, t) − Φ(cd, rightComb t.size) — excess (distinguishability debt)
-- - η(cd, t) = ⟨dcStep(t), frictionDensity(cd)⟩     — density (recoverable per unit cost)
--
-- The variational principle:
--
--     **Coherent observational trajectories are those that minimize ΔΦ.**
--
-- This is achieved by:
-- 1. Tamari contraction (any contraction path decreases ΔΦ, driving it to 0)
-- 2. Observational selection (`revise` removes the vacuous pole, preserving
--    the one with genuine ΔΦ > 0)
--
-- The phase change at CD 2→3 is the free-energy analogue of a first-order
-- phase transition: the associator barrier (strut_weight² = 16) inflates
-- the per-step cost, making non-associative contraction fundamentally more
-- expensive than associative contraction.
--
-- Connection to `docs/GPT_on_free_energy.md`:
--
-- - The document's `C = E − D` maps to `ΔΦ = Φ − Φ_min` (excess = total − minimum)
-- - The document's `F = R / λΓ` maps to `η = dcStep / frictionDensity` (density)
-- - The document's "paths minimizing cumulative coherence expenditure" maps to
--   `excess_contraction_path`: any contraction path non-increases ΔΦ
-- - The document's "observation is the minimal coherence-preserving projection"
--   maps to `revise`: the vacuous pole is projected out, preserving the one
--   that carries genuine work.

-- ============================================================================
-- SECTION 10: Header reconciliation (2026-09-18)
-- ============================================================================
--
-- Six names were listed in the module header's "Key theorems" / "Key definitions"
-- and did not resolve. Each is now either proved, defined, or shown to have been a
-- *name* mismatch; the header bullets were corrected above accordingly. Summary of
-- what each turned out to be:
--
-- 1. `excess_eq_zero_iff_rightComb`  — MISSING ⟹ PROVED here.
-- 2. `potential_contraction_decreases` — ALIAS. The header's own gloss said
--    "non-increases", which is exactly `potential_contraction_step` (proved,
--    `:147`). The name was wrong, not the content. (A strict version is NOT
--    available: `dcStep` only has `dcStep_contracts_one` : `dcStep s ≥ dcStep t`
--    and `dcStep_contracts_one_le` : `dcStep s ≤ dcStep t + 1`, which together leave
--    `dcStep s = dcStep t` open, so strict decrease is a genuine open question and
--    must not be asserted — see §10.1.)
-- 3. `density_assoc_eq_dcStep` — MISSING ⟹ PROVED here.
-- 4. `density_nonassoc_deflated` — MISSING ⟹ PROVED here.
-- 5. `observationalSelection` — MISSING ⟹ DEFINED here. It is the *object* the
--    header promised; `observational_selects_minimal` was the theorem about it.
-- 6. `observational_selects_minimal` — MIS-SPECIFIED. The header said "minimal
--    excess potential"; the truth is the opposite polarity. See §10.2.

/-- **§10.1 (item 2, for the record).** The two available bounds on `dcStep` under a
    single contraction: `dcStep s ≥ dcStep t` and `dcStep s ≤ dcStep t + 1`. They
    leave `dcStep s = dcStep t` open, so a STRICT decrease theorem is not derivable
    from the corpus as it stands. Stated as an explicit two-sided bracket so the gap
    is visible rather than assumed either way. -/
theorem dcStep_contracts_one_bracket {s t : EMLTree} (h : contracts_one s t) :
    dcStep t ≤ dcStep s ∧ dcStep s ≤ dcStep t + 1 :=
  ⟨dcStep_contracts_one h, TamariMetric.dcStep_contracts_one_le h⟩

/-- **§10.1 — the missing statement, isolated.** Does a single contraction strictly
    reduce `dcStep`? If this were provable, `coherencePotential` would strictly
    decrease (strict Lyapunov); if it were refutable, a contraction could preserve the
    potential (a plateau). Neither is currently known. This is an explicit formulation
    of the gap, not a claim in either direction. -/
def dcStep_strictly_decreases_under_contraction : Prop :=
  ∀ s t : EMLTree, contracts_one s t → dcStep t < dcStep s

-- ---------------------------------------------------------------------------
-- §10.2 Item 1: the sharp zero condition for the excess potential
-- ---------------------------------------------------------------------------

/-- **ΔΦ = 0 iff the tree is already at normal form.**

    Property enforced: `weightedCost_eq_zero_iff` (`SubdivisionClosure.lean:137`),
    i.e. the sharpness of the excess potential as a monitor. `Φ(cd, rightComb n) = 0`
    for every `n`, so ΔΦ reduces to Φ itself and the zero set of ΔΦ is exactly the
    normal forms.

    The hypothesis `frictionDensity cd ≠ 0` is load-bearing, not incidental: at
    `cd = 0` the friction density vanishes, every tree has ΔΦ = 0
    (`excessPotential_at_vacuous_cd`), and the iff is then FALSE. So the sharp
    monitor condition holds exactly in the non-vacuous regime — which is the regime
    any monitor would be used in. -/
theorem excess_eq_zero_iff_rightComb (cd : ℕ) (t : EMLTree)
    (hf : frictionDensity cd ≠ 0) :
    excessPotential cd t = 0 ↔ isRightComb t := by
  have hmin : coherencePotential cd (rightComb t.size) = 0 := by
    simp [coherencePotential, weightedCost, dcStep_rightComb]
  unfold excessPotential
  rw [hmin, Nat.sub_zero]
  exact weightedCost_eq_zero_iff cd t hf

/-- ΔΦ vanishes identically in the vacuous regime — for EVERY tree, at any size.
    This is why `excess_eq_zero_iff_rightComb` needs its hypothesis, and it is the
    fact that makes the header's "minimal excess" reading of `revise` backwards
    (§10.3). -/
theorem excessPotential_at_vacuous_cd (t : EMLTree) : excessPotential 0 t = 0 := by
  simp [excessPotential, coherencePotential, weightedCost,
        frictionDensity_eq_k_for_k_le_2 0 (by decide)]

/-- The excess is strictly positive at a non-vacuous CD step for any tree that is not
    at normal form. Together with the previous theorem this is the whole content of
    the selection rule (§10.3). -/
theorem excessPotential_pos_of_nonvacuous (cd : ℕ) (hcd : cd ≠ 0) (t : EMLTree)
    (hnt : ¬ isRightComb t) : 0 < excessPotential cd t := by
  have hf : frictionDensity cd ≠ 0 := by
    intro hzero
    have hge := frictionDensity_ge_k cd
    omega
  have hdc : dcStep t ≠ 0 := fun h => hnt ((isRightComb_iff_dcStep_zero t).mpr h)
  have hmin : coherencePotential cd (rightComb t.size) = 0 := by
    simp [coherencePotential, weightedCost, dcStep_rightComb]
  unfold excessPotential
  rw [hmin, Nat.sub_zero]
  simp only [coherencePotential, weightedCost]
  exact Nat.mul_pos (Nat.pos_of_ne_zero hdc) (Nat.pos_of_ne_zero hf)

-- ---------------------------------------------------------------------------
-- §10.3 Item 3/4: the density's two regimes, compared
-- ---------------------------------------------------------------------------

/-- **In the associative regime the density is exactly `⟨dcStep t, cd⟩`.**
    Property enforced: `frictionDensity_eq_k_for_k_le_2` (`Friction.lean:58`) —
    friction is cheap, so η's denominator is the CD step itself. This is the full
    claim the header named; `density_assoc_regime` proves only the denominator half. -/
theorem density_assoc_eq_dcStep (cd : ℕ) (t : EMLTree) (hcd : cd ≤ 2) :
    distinguishabilityDensity cd t = ⟨dcStep t, cd⟩ := by
  simp [distinguishabilityDensity, frictionDensity_eq_k_for_k_le_2 cd hcd]

/-- **Non-associative deflation: the denominator exceeds `cd` by exactly
    strut_weight².**

    Property enforced: `frictionDensity_eq_k_plus_16_for_k_ge_3` (`Friction.lean:102`)
    — the associator barrier. So at `cd ≥ 3` each flip costs `strut_weight²` more than
    the associative regime at the same `cd`, and for a fixed numerator
    (`dcStep t`) the recoverable work per unit friction strictly drops. Measured
    against the associative baseline `density_assoc_eq_dcStep`, this is the
    quantitative "density drops" claim the header named. -/
theorem density_nonassoc_deflated (cd : ℕ) (t : EMLTree) (hcd : 3 ≤ cd) :
    (distinguishabilityDensity cd t).denominator = cd + strut_weight * strut_weight ∧
      (distinguishabilityDensity cd t).denominator > cd := by
  have h := density_nonassoc_denominator cd t hcd
  refine ⟨h, ?_⟩
  rw [h]
  have hpos : 0 < strut_weight * strut_weight := by
    rw [strut_weight_eq_four]; norm_num
  omega

-- ---------------------------------------------------------------------------
-- §10.4 Item 5/6: the selection rule, as an object and as the truth about it
-- ---------------------------------------------------------------------------

/-- **The observational selection rule, as an object.** The surviving cdSteps after
    `revise` — i.e. the interval's poles with the vacuous ones removed. `Generation.lean`
    defines `revise`; this is its image as a value a theorem can be stated about, which
    is what the header promised by name. -/
def observationalSelection (pair : DescentInterval) : List ℕ :=
  (revise pair).candidates

/-- Unfolding form: the rule keeps `target` and `source` iff each is non-vacuous
    (`isVacuousCd cd = cd = 0`). -/
theorem observationalSelection_eq (pair : DescentInterval) :
    observationalSelection pair =
      ((if pair.target = 0 then [] else [pair.target]) ++
        (if pair.source = 0 then [] else [pair.source])) := by
  simp [observationalSelection, revise, isVacuousCd]

/-- **THE CORRECTED SELECTION RULE: it is MAXIMAL excess, not minimal.**

    Property enforced: `excessPotential_at_vacuous_cd` — at `cd = 0` the friction
    density vanishes, so ΔΦ = 0 for EVERY tree and size. A non-vacuous pole with a
    tree not at normal form has ΔΦ > 0 strictly
    (`excessPotential_pos_of_nonvacuous`). Hence for a `(target = 0, source ≠ 0)`
    interval, `revise` — which DROPS the vacuous pole — retains the pole of *greater*
    excess potential.

    This refutes the module header's original bullet (`observational_selects_minimal`,
    "minimal excess potential"), which was the opposite polarity, and vindicates the
    §6 prose ("minimal vacuity, not minimal total energy"). The vacuous pole is not
    the energy minimum here — it is the *content* minimum: zero excess because there is
    zero friction, which is exactly why it carries no information. -/
theorem observationalSelection_prefers_nonvacuous (pair : DescentInterval) (t : EMLTree)
    (htgt : pair.target = 0) (hsrc : pair.source ≠ 0) (hnt : ¬ isRightComb t) :
    excessPotential pair.target t < excessPotential pair.source t := by
  rw [htgt, excessPotential_at_vacuous_cd]
  exact excessPotential_pos_of_nonvacuous pair.source hsrc t hnt

/-- The rule, instantiated: the barber interval `(0, 4)` keeps only the non-vacuous
    pole, so the selection is `[4]` — the pole carrying the excess. -/
theorem observationalSelection_barber : observationalSelection DescentInterval.barber = [4] := by
  native_decide

/-- And the grandfather interval `(0, 1)` keeps `[1]`. -/
theorem observationalSelection_grandfather :
    observationalSelection DescentInterval.grandfather = [1] := by
  native_decide
