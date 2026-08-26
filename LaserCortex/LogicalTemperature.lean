import Mathlib
import LaserCortex.Friction

/-!
# Logical Temperature — the Boltzmann ensemble over logic space

The WFC layer (`infra/_cortex/_wfc.py`) already samples logics with weight
`exp(-Γ)`. This file names that object and makes it first-class in Lean:
a **Boltzmann ensemble** over Cayley-Dickson steps, with `frictionDensity`
as the energy functional.

## The three quantities (never conflate them)

1. **Control temperature** — the CD step `cd` itself. It plays exactly the
   variational role of `T` in `ThermodynamicBridge.lean`: it scales the
   slope of the excess landscape without moving the equilibrium.
2. **Logical energy** — `frictionDensity cd = Γ_cd`, the cost per Tamari
   step. Γ₀ = 0, Γ₁ = 1, Γ₂ = 2, Γ₃ = 19, Γ₄ = 20 (paraconsistent).
3. **Ensemble temperature** — β⁻¹ of this Boltzmann distribution. The
   identifiability theorem below shows it is *measurable* from sampled
   frequencies, not merely posited.

## Calibration to Kelvin

Degrees Kelvin require a calibration constant mapping friction units to
joules. We use the **Landauer anchor**: one friction unit is treated as one
bit-erasure event, costing `k_B · T_op · ln 2` joules at substrate
operating temperature `T_op`. Under this calibration the *barrier-
equivalent temperature* of a logic at CD step k is

    T_barrier(k) = Γ_k · T_op · ln 2.

At `T_op = 300 K`:

| CD step | Logic regime        | Γ_k | T_barrier (K) |
|---------|---------------------|-----|---------------|
| 0       | Classical (vacuum)  | 0   | 0             |
| 1       | Fuzzy               | 1   | ≈ 208          |
| 2       | Intuitionistic      | 2   | ≈ 416          |
| 3       | Quantum (critical)  | 19  | ≈ 3 951        |
| 4       | Paraconsistent      | 20  | ≈ 4 159        |

Classical logic sits at absolute zero: the "Boolean illusion" of the
companion document is a theorem here (`weight_ground_state`).

## What is unconditional vs calibrated

- Unconditional: the ensemble exists, probabilities normalise, higher
  friction is exponentially suppressed, β is identifiable from frequency
  ratios, paraconsistent logic is supercritical (above the proven CD 2→3
  phase transition), and all Γ-ratios are calibration-free.
- Calibrated: any Kelvin figure. Every such number flows through an
  explicit `LandauerCalibration` hypothesis.

## Cross-refs

- `Friction.lean`           — Γ_k energy functional
- `FreeEnergy.lean`         — Φ(cd, t), variational principle
- `ThermodynamicBridge.lean`— CALPHAD correspondence; its Section-10
  disclaimer ("CD steps are temperatures") is refined here: CD steps are
  not *physical* temperatures, but they are control temperatures of a
  genuine Boltzmann ensemble whose energies are Γ.
- `docs/gemini-flash-3-7_on_logic_temperature.md` — E = k_B T recipe,
  bandgap-equivalent temperatures, Landauer voltage
- `docs/lab_notes/039_logical_temperature.md` — audit + verdicts
- `scripts/logical_temperature.py` — numerical mirror
-/

noncomputable section

-- ============================================================================
-- SECTION 0: Exact small values of Γ (used throughout)
-- ============================================================================

/-- Γ_0 = 0: the associative vacuum carries no friction. -/
theorem frictionDensity_zero : frictionDensity 0 = 0 := by
  unfold frictionDensity commDefect assocDefect
  decide

/-- Γ_1 = 1: fuzzy logic pays only the commutator increment. -/
theorem frictionDensity_one : frictionDensity 1 = 1 := by
  unfold frictionDensity commDefect assocDefect
  decide

-- ============================================================================
-- SECTION 1: The Boltzmann Ensemble over CD steps
-- ============================================================================

/-- The logical energy of a CD step: friction density as a real number.
    Γ_0 = 0, Γ_1 = 1, Γ_2 = 2, Γ_3 = 19, Γ_4 = 20, ... -/
def logicalEnergy (k : ℕ) : ℝ := (frictionDensity k : ℝ)

/-- A Boltzmann ensemble on the finite slice `{0, ..., K}` of CD steps,
    at inverse temperature `beta = 1 / (k_B T_log)` (in units where the
    friction unit is the energy quantum). -/
structure BoltzmannEnsemble (K : ℕ) where
  /-- Inverse logical temperature. Positive for a physical ensemble. -/
  beta : ℝ

/-- Boltzmann weight of CD step `k`: `exp(-β·Γ_k)`. This is exactly the
    `_logic_weight` of `infra/_cortex/_wfc.py` at β = 1. -/
def weight (K : ℕ) (e : BoltzmannEnsemble K) (k : ℕ) : ℝ :=
  Real.exp (-e.beta * logicalEnergy k)

/-- Partition function over the slice `{0, ..., K}`. -/
def partitionFunction (K : ℕ) (e : BoltzmannEnsemble K) : ℝ :=
  ∑ k ∈ Finset.range (K + 1), weight K e k

/-- Normalised Boltzmann probability of observing CD step `k`. -/
def boltzmannProb (K : ℕ) (e : BoltzmannEnsemble K) (k : ℕ) : ℝ :=
  weight K e k / partitionFunction K e

-- ============================================================================
-- SECTION 2: Well-formedness of the ensemble
-- ============================================================================

/-- Every weight is strictly positive: no logic is ever impossible. -/
theorem weight_pos (K : ℕ) (e : BoltzmannEnsemble K) (k : ℕ) :
    0 < weight K e k := Real.exp_pos _

/-- The partition function is positive (CD 0 alone contributes positively). -/
theorem partitionFunction_pos (K : ℕ) (e : BoltzmannEnsemble K) :
    0 < partitionFunction K e :=
  lt_of_lt_of_le (weight_pos K e 0)
    (Finset.single_le_sum (f := fun k => weight K e k)
      (fun k _ => (weight_pos K e k).le) (by simp))

/-- Probabilities are positive. -/
theorem boltzmannProb_pos (K : ℕ) (e : BoltzmannEnsemble K) (k : ℕ) :
    0 < boltzmannProb K e k :=
  div_pos (weight_pos K e k) (partitionFunction_pos K e)

/-- The probabilities form a distribution: they sum to one. -/
theorem sum_boltzmannProb_eq_one (K : ℕ) (e : BoltzmannEnsemble K) :
    (∑ k ∈ Finset.range (K + 1), boltzmannProb K e k) = 1 := by
  have hZ : partitionFunction K e ≠ 0 := ne_of_gt (partitionFunction_pos K e)
  have hsplit : (∑ k ∈ Finset.range (K + 1), boltzmannProb K e k)
      = (∑ k ∈ Finset.range (K + 1), weight K e k) / partitionFunction K e := by
    rw [Finset.sum_div]
    exact Finset.sum_congr rfl fun k _ => rfl
  rw [hsplit]
  exact div_self hZ

/-- **Classical logic is the vacuum state**: CD 0 carries unit weight under
    every inverse temperature, because Γ_0 = 0. The Boolean illusion that
    temperature is zero is a structural property, not an approximation. -/
theorem weight_ground_state (K : ℕ) (e : BoltzmannEnsemble K) :
    weight K e 0 = 1 := by
  unfold weight logicalEnergy
  rw [frictionDensity_zero]
  simp

-- ============================================================================
-- SECTION 3: Exponential suppression and identifiability
-- ============================================================================

/-- The ratio of two weights depends only on the energy gap — the
    partition function cancels. This is what makes temperature measurable. -/
theorem weight_ratio (K : ℕ) (e : BoltzmannEnsemble K) (i j : ℕ) :
    weight K e i / weight K e j
      = Real.exp (e.beta * ((frictionDensity j : ℝ) - (frictionDensity i : ℝ))) := by
  unfold weight logicalEnergy
  rw [← Real.exp_sub]
  congr 1
  ring

/-- Same ratio holds for normalised probabilities. -/
theorem prob_ratio (K : ℕ) (e : BoltzmannEnsemble K) (i j : ℕ) :
    boltzmannProb K e i / boltzmannProb K e j = weight K e i / weight K e j := by
  have hZ : partitionFunction K e ≠ 0 := ne_of_gt (partitionFunction_pos K e)
  unfold boltzmannProb
  field_simp

/-- Higher-friction states are exponentially suppressed at positive β:
    if Γ_i < Γ_j then state j is strictly less probable than state i. -/
theorem lower_energy_more_probable (K : ℕ) (e : BoltzmannEnsemble K)
    (hb : 0 < e.beta) {i j : ℕ} (hij : frictionDensity i < frictionDensity j) :
    weight K e j < weight K e i := by
  -- gap := Γ_j − Γ_i > 0 (as reals)
  have hgap : (0 : ℝ) < (frictionDensity j : ℝ) - (frictionDensity i : ℝ) := by
    rw [sub_pos]
    exact_mod_cast hij
  -- weight j / weight i = exp(-β · gap)  (swap roles in weight_ratio)
  have hswap := weight_ratio K e j i
  have hrew : e.beta * ((frictionDensity i : ℝ) - (frictionDensity j : ℝ))
      = -(e.beta * ((frictionDensity j : ℝ) - (frictionDensity i : ℝ))) := by ring
  rw [hrew] at hswap
  -- the exponent factor is < 1
  have hElt1 : Real.exp (-(e.beta * ((frictionDensity j : ℝ)
      - (frictionDensity i : ℝ)))) < 1 := by
    rw [Real.exp_lt_one_iff]
    have hneg : e.beta * ((frictionDensity j : ℝ) - (frictionDensity i : ℝ)) > 0 :=
      mul_pos hb hgap
    linarith
  -- conclude weight j = weight i · E < weight i · 1
  have hwne : weight K e i ≠ 0 := ne_of_gt (weight_pos K e i)
  have hjeq : weight K e j = weight K e i *
      Real.exp (-(e.beta * ((frictionDensity j : ℝ) - (frictionDensity i : ℝ)))) := by
    have h2 : weight K e j / weight K e i * weight K e i
        = Real.exp (-(e.beta * ((frictionDensity j : ℝ)
            - (frictionDensity i : ℝ)))) * weight K e i := by
      rw [hswap]
    rw [div_mul_cancel₀ _ hwne] at h2
    linarith
  rw [hjeq]
  calc weight K e i * Real.exp (-(e.beta * ((frictionDensity j : ℝ)
        - (frictionDensity i : ℝ))))
      < weight K e i * 1 := by
        exact mul_lt_mul_of_pos_left hElt1 (weight_pos K e i)
    _ = weight K e i := by ring

/-- **Identifiability theorem**: the frequency ratio of two CD steps
    determines the inverse temperature uniquely. Given two ensembles with
    equal observed ratios, their betas coincide. Temperature is therefore
    a *measurable* parameter of the ensemble, not a free convention. -/
theorem beta_identifiable (K : ℕ) {i j : ℕ}
    (hij : frictionDensity i < frictionDensity j)
    (r : ℝ) (_hr : 1 < r)
    {b₁ b₂ : ℝ}
    (h₁ : boltzmannProb K ⟨b₁⟩ i / boltzmannProb K ⟨b₁⟩ j = r)
    (h₂ : boltzmannProb K ⟨b₂⟩ i / boltzmannProb K ⟨b₂⟩ j = r) :
    b₁ = b₂ := by
  have hgap : (0 : ℝ) < (frictionDensity j : ℝ) - (frictionDensity i : ℝ) := by
    rw [sub_pos]
    exact_mod_cast hij
  have key : ∀ b : ℝ, boltzmannProb K ⟨b⟩ i / boltzmannProb K ⟨b⟩ j
      = Real.exp (b * ((frictionDensity j : ℝ) - (frictionDensity i : ℝ))) := by
    intro b
    rw [prob_ratio, weight_ratio]
  rw [key b₁] at h₁
  rw [key b₂] at h₂
  rw [← h₂] at h₁
  exact mul_right_cancel₀ (ne_of_gt hgap) (Real.exp_injective h₁)

-- ============================================================================
-- SECTION 4: Supercriticality — paraconsistent logic lives above the
-- proven phase transition
-- ============================================================================

/-- The paraconsistent regime lives at Cayley-Dickson step 4
    (second doubling past the split-octonion transition). -/
def paraconsistentCd : ℕ := 4

/-- The critical point of logic space: CD 3, where the associator defect
    activates (matches `criticalPoint := 3` in `ThermodynamicBridge`). -/
def criticalCd : ℕ := 3

/-- Paraconsistent logic is **supercritical**: it operates above the
    associative/non-associative phase transition. -/
theorem paraconsistent_supercritical : criticalCd < paraconsistentCd := by
  unfold paraconsistentCd criticalCd
  norm_num

/-- The paraconsistent friction density is exactly 20:
    Γ_4 = 4 + strut_weight² = 4 + 16. -/
theorem paraconsistent_friction : frictionDensity paraconsistentCd = 20 := by
  have hge : 3 ≤ paraconsistentCd := by unfold paraconsistentCd; norm_num
  rw [frictionDensity_eq_k_plus_16_for_k_ge_3 paraconsistentCd hge]
  unfold paraconsistentCd
  rw [strut_weight_eq_four]

/-- Every associative-regime logic is strictly cooler than paraconsistent
    logic in energy terms. -/
theorem associative_friction_lt_paraconsistent (k : ℕ) (hk : k ≤ 2) :
    frictionDensity k < frictionDensity paraconsistentCd := by
  rw [frictionDensity_eq_k_for_k_le_2 k hk, paraconsistent_friction]
  omega

/-- The paraconsistent energy barrier dwarfs the intuitionistic one by
    more than an order of magnitude: Γ_4 > 9 × Γ_2. Consistent with
    the proven phase-change ratio in `FreeEnergy.lean`. -/
theorem paraconsistent_barrier_dwarfs_associative :
    9 * frictionDensity 2 < frictionDensity paraconsistentCd := by
  rw [frictionDensity_at_cl11_boundary, paraconsistent_friction]
  norm_num

-- ============================================================================
-- SECTION 5: Landauer calibration — the bridge to Kelvin
-- ============================================================================

/-- **Landauer calibration**: maps friction units to physical energy.

    One friction unit is treated as one bit-erasure event. By Landauer's
    principle, erasing one bit at substrate operating temperature `tOp`
    costs `kB · tOp · ln 2` joules. This makes the calibration *linear*
    with zero intercept — there is no free constant to hide behind. -/
structure LandauerCalibration where
  /-- Operating temperature of the physical substrate (Kelvin). -/
  tOp : ℝ
  /-- Boltzmann constant (J/K). -/
  kB : ℝ
  /-- Physical sanity: positive substrate temperature. -/
  tOp_pos : 0 < tOp

/-- Energy per friction unit under Landauer calibration (joules). -/
def landauerEnergyPerUnit (c : LandauerCalibration) : ℝ :=
  c.kB * c.tOp * Real.log 2

/-- **Barrier-equivalent temperature** of a logic whose energy barrier is
    `gammaUnits` friction units: the temperature at which thermal
    fluctuations reach the barrier. This is the same construction as the
    silicon bandgap temperature `E_g / k_B ≈ 13 200 K` of the companion
    document — with Γ in place of E_g. -/
def barrierEquivalentTemperature (c : LandauerCalibration)
    (gammaUnits : ℝ) : ℝ :=
  gammaUnits * c.tOp * Real.log 2

/-- Barrier-equivalent temperature from a raw CD step. -/
def cdBarrierTemperature (c : LandauerCalibration) (k : ℕ) : ℝ :=
  barrierEquivalentTemperature c (logicalEnergy k)

/-- **Classical logic is at absolute zero** under any Landauer
    calibration: Γ_0 = 0 forces T = 0. Boolean logic does not merely
    *pretend* the temperature is zero — it is structurally frozen. -/
theorem classical_absolute_zero (c : LandauerCalibration) :
    cdBarrierTemperature c 0 = 0 := by
  unfold cdBarrierTemperature barrierEquivalentTemperature logicalEnergy
  rw [frictionDensity_zero]
  ring

/-- The main conditional result: under Landauer calibration, the
    barrier-equivalent temperature of paraconsistent logic is

        T = 20 · T_op · ln 2,

    which at T_op = 300 K evaluates to ≈ 4 158.88 K (verified numerically
    in `scripts/logical_temperature.py`). -/
theorem paraconsistent_barrier_temperature (c : LandauerCalibration) :
    cdBarrierTemperature c paraconsistentCd = 20 * c.tOp * Real.log 2 := by
  unfold cdBarrierTemperature barrierEquivalentTemperature logicalEnergy
  rw [paraconsistent_friction]
  push_cast
  ring

/-- Scale-free corollary: the paraconsistent barrier temperature is
    exactly twenty times the fuzzy one (Γ ratio 20/1), regardless of
    calibration. Ratios, unlike Kelvin values, need no anchor. -/
theorem paraconsistent_to_fuzzy_temperature_ratio (c : LandauerCalibration) :
    cdBarrierTemperature c 1 * 20 = cdBarrierTemperature c paraconsistentCd := by
  unfold cdBarrierTemperature barrierEquivalentTemperature logicalEnergy
  rw [paraconsistent_friction, frictionDensity_one]
  push_cast
  ring

-- ============================================================================
-- SECTION 7: The full logic temperature map (Hopf skeleton)
-- ============================================================================

/-- Γ at CD 3 — the critical rung: 3 + strut² = 19. -/
theorem frictionDensity_three : frictionDensity 3 = 19 := by
  rw [frictionDensity_eq_k_plus_16_for_k_ge_3 3 (by norm_num)]
  rw [strut_weight_eq_four]

/-- The 15 named logics of the pluralistic framework
    (mirror of `infra/_cortex/_logic_types.py::LogicType`). -/
inductive LogicName where
  | classical | boolean | fuzzy | manyValued | temporal | deontic | epistemic
  | intuitionistic | quantum | relevance | infinitary | modal | spacetime
  | paraconsistent | free

/-- Cayley-Dickson tower height of each named logic.
    Exact mirror of `_logic_types.py::cd_step`, which covers all 15 logics
    consistently with sector membership (associative ⇒ ≤ 2, split ⇒ ≥ 3). -/
def logicCd : LogicName → ℕ
  | .classical => 0
  | .boolean => 0
  | .fuzzy => 1
  | .manyValued => 1
  | .temporal => 1
  | .deontic => 1
  | .epistemic => 1
  | .intuitionistic => 2
  | .quantum => 3
  | .relevance => 3
  | .infinitary => 3
  | .modal => 3
  | .spacetime => 3
  | .paraconsistent => 4
  | .free => 4

/-- The barrier-equivalent temperature of a named logic under a given
    calibration. Temperature lives on the tower-height axis; cost geometry
    (the Hopf e₁–e₇ axes) is orthogonal. Classical and Modal share the null
    NodeCost P₀ yet sit at opposite ends of the thermometer. -/
def logicTemp (c : LandauerCalibration) (l : LogicName) : ℝ :=
  cdBarrierTemperature c (logicCd l)

/-- Unfolding lemma: temperature in terms of Γ directly. -/
theorem logicTemp_eq (c : LandauerCalibration) (l : LogicName) :
    logicTemp c l = (frictionDensity (logicCd l) : ℝ) * c.tOp * Real.log 2 :=
  rfl

/-- Every named logic sits at or below the sedenion rung. -/
theorem logicCd_le_four (l : LogicName) : logicCd l ≤ 4 := by
  cases l <;> simp only [logicCd] <;> norm_num

/-- **Modal logic sits exactly at the critical point**: its tower height is
    the associativity-loss step CD 3 itself. Modal reasoning lives on the
    phase boundary. -/
theorem modal_at_critical_point : logicCd .modal = criticalCd := rfl

/-- **Temperature of modal logic** under Landauer calibration:
    Γ₃ = 19, so T_modal = 19 · T_op · ln 2 ≈ 3 950.94 K at T_op = 300 K.
    Just below paraconsistent (20 units) — separated by exactly one
    commutator unit across the critical point. -/
theorem modal_barrier_temperature (c : LandauerCalibration) :
    logicTemp c .modal = 19 * c.tOp * Real.log 2 := by
  rw [logicTemp_eq]
  rw [show logicCd LogicName.modal = 3 from rfl, frictionDensity_three]
  push_cast
  ring

/-- The associative-sector group {Fuzzy, ManyValued, Temporal, Deontic,
    Epistemic} shares one temperature rung: T = T_op · ln 2 ≈ 208 K.
    Five distinct logical personalities, one thermal position. -/
theorem fuzzy_band_temperature (c : LandauerCalibration)
    (l : LogicName) (hl : logicCd l = 1) :
    logicTemp c l = c.tOp * Real.log 2 := by
  rw [logicTemp_eq, hl, frictionDensity_one]
  push_cast
  ring

/-- Intuitionistic logic occupies its own rung below the critical point:
    T = 2 · T_op · ln 2 ≈ 416 K. -/
theorem intuitionistic_temperature (c : LandauerCalibration) :
    logicTemp c .intuitionistic = 2 * c.tOp * Real.log 2 := by
  rw [logicTemp_eq]
  rw [show logicCd LogicName.intuitionistic = 2 from rfl,
      frictionDensity_at_cl11_boundary]
  push_cast
  ring

/-- The deep-split pair {Paraconsistent, Free} shares the hottest named
    rung: T = 20 · T_op · ln 2 ≈ 4 159 K. The logic of will is exactly as
    hot as the logic of contradiction. -/
theorem free_logic_temperature (c : LandauerCalibration) :
    logicTemp c .free = 20 * c.tOp * Real.log 2 := by
  rw [logicTemp_eq]
  rw [show logicCd LogicName.free = paraconsistentCd from rfl,
      paraconsistent_friction]
  push_cast
  ring

/-- Classical and Boolean logic share absolute zero: both sit at tower
    height 0, the vacuum rung. -/
theorem boolean_absolute_zero (c : LandauerCalibration) :
    logicTemp c .boolean = 0 := by
  rw [logicTemp_eq]
  rw [show logicCd LogicName.boolean = 0 from rfl, frictionDensity_zero]
  ring

-- ============================================================================
-- SECTION 8: Critical points of the algebra
-- ============================================================================

/-- The increment of Γ along the ladder is 1 everywhere except the single
    jump of 17 at CD 2→3 (commutator +1 and associator onset +16). This
    makes CD 3 the **unique thermodynamic critical point** of the energy
    functional as currently formalized. -/
theorem gamma_increment (k : ℕ) :
    frictionDensity (k + 1) = frictionDensity k + (if k = 2 then 17 else 1) := by
  by_cases h2 : k = 2
  · subst h2
    show frictionDensity 3 = frictionDensity 2 + (if 2 = 2 then 17 else 1)
    rw [if_pos rfl, frictionDensity_eq_k_plus_16_for_k_ge_3 3 (by norm_num),
        frictionDensity_at_cl11_boundary, strut_weight_eq_four]
  · by_cases h3 : 3 ≤ k
    · have h4 : 3 ≤ k + 1 := by omega
      rw [frictionDensity_eq_k_plus_16_for_k_ge_3 (k + 1) h4,
          frictionDensity_eq_k_plus_16_for_k_ge_3 k h3, if_neg h2,
          strut_weight_eq_four]
    · have hk1 : k + 1 ≤ 2 := by omega
      have hk0 : k ≤ 2 := by omega
      rw [frictionDensity_eq_k_for_k_le_2 (k + 1) hk1,
          frictionDensity_eq_k_for_k_le_2 k hk0, if_neg h2]

/-- Away from the critical point, consecutive rungs differ by exactly one
    commutator unit: no hidden phase transitions in Γ. -/
theorem gamma_only_jump_at_cd2_3 (k : ℕ) (hk : k ≠ 2) :
    frictionDensity (k + 1) = frictionDensity k + 1 := by
  rw [gamma_increment k, if_neg hk]

/-- Barrier temperature is monotone in energy. -/
theorem barrierTemp_mono (c : LandauerCalibration)
    {i j : ℕ} (hij : frictionDensity i ≤ frictionDensity j) :
    cdBarrierTemperature c i ≤ cdBarrierTemperature c j := by
  unfold cdBarrierTemperature barrierEquivalentTemperature logicalEnergy
  refine mul_le_mul_of_nonneg_right ?_ (Real.log_nonneg (by norm_num : (1:ℝ) ≤ 2))
  exact mul_le_mul_of_nonneg_right (Nat.cast_le.mpr hij) c.tOp_pos.le

/-- Every ladder rung at or below CD 4 carries at most Γ₄ energy. -/
theorem gamma_le_gamma4 (k : ℕ) (hk : k ≤ 4) :
    frictionDensity k ≤ frictionDensity 4 := by
  rcases lt_or_eq_of_le hk with hlt | rfl
  · exact frictionDensity_monotone _ _ hlt
  · exact Nat.le_refl _

/-- Named-logic temperatures are bounded above by the paraconsistent/free
    rung: nothing named is hotter than the logic of contradiction and the
    logic of will. -/
theorem logicTemp_le_paraconsistent (c : LandauerCalibration) (l : LogicName) :
    logicTemp c l ≤ logicTemp c .paraconsistent := by
  unfold logicTemp
  apply barrierTemp_mono
  exact gamma_le_gamma4 _ (logicCd_le_four l)

end

-- ============================================================================
-- SECTION 6: What this does and does not mean (comment only)
-- ============================================================================
--
-- 1. UNCONDITIONAL: logic space carries a genuine Boltzmann ensemble
--    (normalisable, exponentially suppressed, identifiable β). The WFC
--    layer has been sampling it all along at β = 1.
-- 2. UNCONDITIONAL: paraconsistent logic is supercritical — above the
--    proven CD 2→3 phase transition — with energy Γ_4 = 20.
-- 3. CALIBRATED: T_paraconsistent = 20 · T_op · ln 2 ≈ 4 159 K at room
--    substrate temperature. Change the anchor, change the number; the
--    structure (and every ratio) survives unchanged.
-- 4. NOT CLAIMED: that logic has a literal thermodynamic bath, or that
--    Γ is measured in joules without the calibration hypothesis. This
--    refines — not contradicts — the Section-10 disclaimer of
--    `ThermodynamicBridge.lean`: the disclaimer was right that CD steps
--    are not *physical* temperatures, and too modest in implying the
--    Boltzmann structure was absent.
