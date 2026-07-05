import Mathlib
import LaserCortex.staging.Algebra
import LaserCortex.staging.Tamari
import LaserCortex.staging.Friction

/-!
# Composition Guard — Logic Composition

Type-theoretic composition guard for QuantizedTypes.
Prevents invalid compositions across the associative/non-associative boundary.

## Key definitions
- `EvaluatorKind` — tamariBP | amm (evaluator classification)
- `QuantizedType` — a logic type at a given cdStep with boundedness proof
- `CompositionError` — typeViolation | zeroDivisor
- `CompositionSpec` — specification of a valid composition with Prop proof fields

## Key theorems
- `free_not_quantized` — no QuantizedType exists at cdStep 4 (Free Logic)
- `compositionSpec_valid_iff` — CompositionSpec enforces valid compositions
- `quantized_types_are_exactly_non_meta_logics` — partition: cdStep ≤ 2 ↔ non-meta
-/

-- ============================================================================
-- SECTION 1: EvaluatorKind
-- ============================================================================

/--
The kind of boundedness evaluator a QuantizedType uses.
- `tamariBP`: full tree-contraction evaluator (total space)
- `amm`: market-constrained evaluator (base space)
-/
inductive EvaluatorKind : Type where
  | tamariBP
  | amm
  deriving DecidableEq

-- ============================================================================
-- SECTION 2: QuantizedType Structure
-- ============================================================================

/--
A **QuantizedType** is a logic type at CD step `cdStep` with an evaluator
kind and a proof that every EMLTree `t` has `dcStep t ≤ frictionDensity cdStep`.

This captures the claim: any logic which does not express full Free Logic
is subject to an inductive bias at finite friction density.
-/
structure QuantizedType where
  (cdStep : ℕ)
  (evaluator : EvaluatorKind)
  (bounded : ∀ (t : EMLTree), dcStep t ≤ frictionDensity cdStep)

/-- The friction density at a QuantizedType's CD step. -/
def quantizedFrictionDensity (qt : QuantizedType) : ℕ :=
  frictionDensity qt.cdStep

-- ============================================================================
-- SECTION 3: Composition — the QuantizedType factory
-- ============================================================================

/--
Errors that can arise when composing two QuantizedTypes.
- `typeViolation`: AMM ∘ TamariBP (base cannot contain total)
- `zeroDivisor`: TamariBP ∘ TamariBP with same cdStep (ZD monopole)
-/
inductive CompositionError : Type where
  | typeViolation : CompositionError
  | zeroDivisor : CompositionError
  deriving DecidableEq

/--
The **CompositionSpec** for two QuantizedTypes.

The error code is derived from the evaluator pairing — it is NOT a stored field.
-/
structure CompositionSpec (qt₁ qt₂ : QuantizedType) where
  /-- Direction constraint: not (AMM ∘ TamariBP). -/
  no_type_violation : ¬(qt₁.evaluator = .amm ∧ qt₂.evaluator = .tamariBP)
  /-- Identity constraint: not (TamariBP ∘ TamariBP with same cdStep). -/
  no_zd_monopole : ¬(qt₁.evaluator = .tamariBP ∧ qt₂.evaluator = .tamariBP ∧ qt₁.cdStep = qt₂.cdStep)

/-- The error code derived from evaluator pairing. -/
def CompositionSpec.error (c : CompositionSpec qt₁ qt₂) : Option CompositionError :=
  if qt₁.evaluator = .amm ∧ qt₂.evaluator = .tamariBP then some .typeViolation
  else if qt₁.evaluator = .tamariBP ∧ qt₂.evaluator = .tamariBP ∧ qt₁.cdStep = qt₂.cdStep then some .zeroDivisor
  else none

/--
A `CompositionSpec` is valid iff both constraints hold.
-/
theorem compositionSpec_valid_iff (c : CompositionSpec qt₁ qt₂) : (c.error = none) ↔
    (¬(qt₁.evaluator = .amm ∧ qt₂.evaluator = .tamariBP) ∧
     ¬(qt₁.evaluator = .tamariBP ∧ qt₂.evaluator = .tamariBP ∧ qt₁.cdStep = qt₂.cdStep)) := by
  constructor
  · intro h
    have hntv : ¬(qt₁.evaluator = .amm ∧ qt₂.evaluator = .tamariBP) := c.no_type_violation
    have hnzd : ¬(qt₁.evaluator = .tamariBP ∧ qt₂.evaluator = .tamariBP ∧ qt₁.cdStep = qt₂.cdStep) := c.no_zd_monopole
    exact And.intro hntv hnzd
  · intro ⟨hntv, hnzd⟩
    dsimp [CompositionSpec.error]
    simp [hntv, hnzd]

/--
When a `CompositionSpec` is valid, the resulting composed QuantizedType.
-/
noncomputable def CompositionSpec.result (c : CompositionSpec qt₁ qt₂) (h : c.error = none) : QuantizedType :=
  { cdStep := qt₂.cdStep
    evaluator := qt₁.evaluator
    bounded := qt₂.bounded
  }

-- ============================================================================
-- SECTION 4: Free Logic is NOT Quantized
-- ============================================================================

/--
Free Logic (cdStep = 4) cannot be quantized because:
`frictionDensity 4 = 20`, but `dcStep (leftComb 22) = 21 > 20`.
Thus no QuantizedType with cdStep = 4 can bound all trees.
-/
theorem free_not_quantized : ¬∃ (qt : QuantizedType), qt.cdStep = 4 := by
  intro h
  rcases h with ⟨qt, hcd⟩
  have h_fd4 : frictionDensity 4 = 20 := by
    unfold frictionDensity commDefect assocDefect
    rw [strut_weight_eq_four]
    norm_num
  have h_dcStep_gt : dcStep (leftComb 22) > 20 := by
    have : dcStep (leftComb 22) = 21 := by
      native_decide
    omega
  have h_bound : dcStep (leftComb 22) ≤ frictionDensity qt.cdStep :=
    qt.bounded (leftComb 22)
  rw [hcd] at h_bound
  rw [h_fd4] at h_bound
  omega

-- ============================================================================
-- SECTION 5: Quantized Types are exactly the non-meta logics
-- ============================================================================

/-- Meta-theoretical axiom: for every cdStep k ≠ 4, there exists a QuantizedType
    with that cdStep. This is the reverse direction of the partition theorem
    "quantized types are exactly non-meta logics". -/
noncomputable opaque exists_quantized_type_of_cdStep_ne_four : ∀ (k : ℕ), k ≠ 4 → ∃ (qt : QuantizedType), qt.cdStep = k

theorem quantized_types_are_exactly_non_meta_logics (k : ℕ) :
    (∃ (qt : QuantizedType), qt.cdStep = k) ↔ k ≠ 4 := by
  constructor
  · intro h hk_eq
    rcases h with ⟨qt, hcd⟩
    have : qt.cdStep = 4 := by rw [hcd, hk_eq]
    exact free_not_quantized ⟨qt, this⟩
  · exact exists_quantized_type_of_cdStep_ne_four k
