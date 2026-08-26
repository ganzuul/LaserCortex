import Mathlib
import LaserCortex.foundations.Algebra
import LaserCortex.ImpedanceMetric
import LaserCortex.ThermalResidue

/-!
# Layer 4.5 — Cycle Dynamics; The ω-Orbit and Thermal Ledger Closure

## Plain-English reading

The four layers of the LC metric stack describe what *is* (algebraic ground,
atomic state, matched kernel, emissive/absorptive sub-kinds, thermal residue).
What they do not yet describe is *what happens next* — dynamics. This file
introduces the simplest non-trivial dynamical process in the split-octonion
algebra: iterated multiplication by `ω = e₄`.

### The right-ω clock tick

Define a map `ωCycleR` that sends `x ↦ x · ω`:

```
ωCycleR(x) := x · e₄
```

This is linear and takes the matched kernel `⟨e₀, e₁, e₂, e₃⟩` into the
`ω`-complement `⟨e₄, e₅, e₆, e₇⟩` and back — a period-2 involution on
each kernel–complement basis pair.

### The left-ω clock tick

Define `ωCycleL(x) := e₄ · x`. This governs the *absorptive* ingress
(complement → kernel). The asymmetry between right and left ω-multiplication
is what produces `e₄·(e₁·e₄) = -e₁` rather than `e₁` — the "circle plus more"
overshoot.

### The emissive-absorptive cycle

The composition `ωCycleEA(x) := ωCycleL(ωCycleR(x)) = e₄·(x·e₄)` acts as
negation on most basis vectors: `ωCycleEA(e₁) = -e₁`, `ωCycleEA(e₅) = -e₅`,
etc. It fixes only `e₀` and `e₄`, and is an involution (`ωCycleEA² = id`).

### The 4-step cycle closes the thermal ledger

The 4-step emissive-absorptive cycle:

```
e₁ →(ωR) e₅ →(ωL) -e₁ →(ωR) -e₅ →(ωL) e₁
```

The overshoot at each visited element is `(-1, +1, -1, +1)`, summing to
zero. This contrasts with the 3-element subsequence `e₁ → e₅ → -e₁` (the
existing `supercomplete_cycle_persistent_thermal`) which sums to `-1`.
The full 4-step orbit closes both the algebra (returns to `e₁`) and the
thermal ledger (net overshoot zero).

The modulus `M = strut_weight = 4` coincides with the cycle's period —
it is not just a geometric parameter but an intrinsic dynamical period.

## File references

- `foundations/Algebra.lean` — `SplitOctonion`, `split_oct_mul`, `omega`,
  `omega_mul_e5`, `e5_mul_omega`, `split_neg`, `eN_vec`
- `ImpedanceMetric.lean` — `e1_mul_e4`
- `ThermalResidue.lean` — `overshoot`, `thermalResidue`,
  `supercomplete_cycle_persistent_thermal`
-/

open EMLTree

-- ============================================================================
-- SECTION 0: Bilinearity helpers (negation distributes through split_oct_mul)
-- ============================================================================

/-- `split_neg` is involutive: `split_neg (split_neg x) = x`. -/
@[simp]
theorem split_neg_neg (x : SplitOctonion) : split_neg (split_neg x) = x := by
  ext <;> simp [split_neg]

/-- `split_oct_mul` distributes negation on the left: `(-x)·y = -(x·y)`. -/
theorem split_oct_mul_neg_left (x y : SplitOctonion) :
    split_oct_mul (split_neg x) y = split_neg (split_oct_mul x y) := by
  ext <;> simp [split_oct_mul, split_neg] <;> ring

/-- `split_oct_mul` distributes negation on the right: `x·(-y) = -(x·y)`. -/
theorem split_oct_mul_neg_right (x y : SplitOctonion) :
    split_oct_mul x (split_neg y) = split_neg (split_oct_mul x y) := by
  ext <;> simp [split_oct_mul, split_neg] <;> ring

-- ============================================================================
-- SECTION 1: The right-ω clock tick (x ↦ x · e₄)
-- ============================================================================

/--
The **right-ω clock tick**: `ωCycleR(x) := x · e₄`.

This is the simplest non-trivial dynamical map on `SplitOctonion`: multiply
by the Cayley-Dickson generator `ω = e₄` on the right. It exchanges the
matched kernel (⟨e₀, e₁, e₂, e₃⟩) with the ω-complement (⟨e₄, e₅, e₆, e₇⟩)
and back — a period-2 involution on the basis vectors.
-/
def ωCycleR (x : SplitOctonion) : SplitOctonion :=
  split_oct_mul x e4_vec

-- ---------------------------------------------------------------------------
-- Right-ω cycle: specific basis-vector transitions
-- ---------------------------------------------------------------------------

/-- `ωCycleR(e₀) = e₄` — the scalar component ticks into the ω direction. -/
theorem ωCycleR_e0 : ωCycleR e0_vec = e4_vec := by
  rfl

/-- `ωCycleR(e₄) = e₀` — the ω tick back to the scalar. -/
theorem ωCycleR_e4 : ωCycleR e4_vec = e0_vec := by
  rfl

/-- `ωCycleR(e₁) = e₅` — emissive egress from the kernel (Layer 3a). -/
theorem ωCycleR_e1 : ωCycleR e1_vec = e5_vec :=
  e1_mul_e4

/-- `ωCycleR(e₅) = e₁` — return from the ω-complement via right-ω. -/
theorem ωCycleR_e5 : ωCycleR e5_vec = e1_vec := by
  rfl

/-- `ωCycleR(e₂) = e₆` — emissive egress from e₂. -/
theorem ωCycleR_e2 : ωCycleR e2_vec = e6_vec := by
  rfl

/-- `ωCycleR(e₆) = e₂` — return from the ω-complement from e₆. -/
theorem ωCycleR_e6 : ωCycleR e6_vec = e2_vec := by
  rfl

/-- `ωCycleR(e₃) = e₇` — emissive egress from e₃. -/
theorem ωCycleR_e3 : ωCycleR e3_vec = e7_vec := by
  rfl

/-- `ωCycleR(e₇) = e₃` — return from the ω-complement from e₇. -/
theorem ωCycleR_e7 : ωCycleR e7_vec = e3_vec := by
  rfl

-- ---------------------------------------------------------------------------
-- Right-ω cycle: period-2 on basis vectors
-- ---------------------------------------------------------------------------

/-- `ωCycleR²(e₁) = e₁` — period 2 on the e₁-e₅ pair. -/
theorem ωCycleR_period2_e1 : ωCycleR (ωCycleR e1_vec) = e1_vec := by
  rw [ωCycleR_e1, ωCycleR_e5]

/-- `ωCycleR²(e₅) = e₅` — period 2 on the e₅-e₁ pair. -/
theorem ωCycleR_period2_e5 : ωCycleR (ωCycleR e5_vec) = e5_vec := by
  rw [ωCycleR_e5, ωCycleR_e1]

/-- `ωCycleR²(e₂) = e₂` — period 2 on the e₂-e₆ pair. -/
theorem ωCycleR_period2_e2 : ωCycleR (ωCycleR e2_vec) = e2_vec := by
  rw [ωCycleR_e2, ωCycleR_e6]

/-- `ωCycleR²(e₃) = e₃` — period 2 on the e₃-e₇ pair. -/
theorem ωCycleR_period2_e3 : ωCycleR (ωCycleR e3_vec) = e3_vec := by
  rw [ωCycleR_e3, ωCycleR_e7]

/-- `ωCycleR` is an involution on the four kernel basis elements. -/
theorem ωCycleR_period2_all :
    ωCycleR (ωCycleR e0_vec) = e0_vec ∧
    ωCycleR (ωCycleR e1_vec) = e1_vec ∧
    ωCycleR (ωCycleR e2_vec) = e2_vec ∧
    ωCycleR (ωCycleR e3_vec) = e3_vec :=
  ⟨by rw [ωCycleR_e0, ωCycleR_e4],
   ωCycleR_period2_e1, ωCycleR_period2_e2, ωCycleR_period2_e3⟩

/-- Negation commutes with the right-ω cycle: `ωCycleR(-x) = -ωCycleR(x)`. -/
theorem ωCycleR_neg (x : SplitOctonion) :
    ωCycleR (split_neg x) = split_neg (ωCycleR x) := by
  rw [ωCycleR, ωCycleR, split_oct_mul_neg_left]

-- ============================================================================
-- SECTION 2: The left-ω cycle (x ↦ e₄ · x)
-- ============================================================================

/--
The **left-ω clock tick**: `ωCycleL(x) := e₄ · x`.

While `ωCycleR` governs the *emissive* egress (kernel→complement via
right multiplication), `ωCycleL` governs the *absorptive* ingress back.
The combination of the two produces the asymmetry `e₄·(e₁·e₄) = -e₁`.
-/
def ωCycleL (x : SplitOctonion) : SplitOctonion :=
  split_oct_mul e4_vec x

-- ---------------------------------------------------------------------------
-- Left-ω cycle: specific basis-vector transitions
-- ---------------------------------------------------------------------------

/-- `ωCycleL(e₀) = e₄` — left-ω of the scalar is the ω generator. -/
theorem ωCycleL_e0 : ωCycleL e0_vec = e4_vec := by
  rfl

/-- `ωCycleL(e₄) = e₀` — left-ω of the ω generator is the scalar. -/
theorem ωCycleL_e4 : ωCycleL e4_vec = e0_vec := by
  rfl

/-- `ωCycleL(e₁) = -e₅` — left-ω of the kernel basis element. -/
theorem ωCycleL_e1 : ωCycleL e1_vec = split_neg e5_vec := by
  rfl

/-- `ωCycleL(e₅) = -e₁` — absorptive ingress (Layer 3b). -/
theorem ωCycleL_e5 : ωCycleL e5_vec = split_neg e1_vec := by
  rfl

/-- `ωCycleL(e₂) = -e₆` — left-ω of e₂. -/
theorem ωCycleL_e2 : ωCycleL e2_vec = split_neg e6_vec := by
  rfl

/-- `ωCycleL(e₆) split_neg e2_vec` — left-ω of e₆ returns to the negated kernel. -/
theorem ωCycleL_e6 : ωCycleL e6_vec = split_neg e2_vec := by
  rfl

/-- `ωCycleL(e₃) = -e₇` — left-ω of e₃. -/
theorem ωCycleL_e3 : ωCycleL e3_vec = split_neg e7_vec := by
  rfl

/-- `ωCycleL(e₇) = e₃` — left-ω of e₇ returns to the negated kernel. -/
theorem ωCycleL_e7 : ωCycleL e7_vec = split_neg e3_vec := by
  rfl

/-- Negation commutes with the left-ω cycle: `ωCycleL(-x) = -ωCycleL(x)`. -/
theorem ωCycleL_neg (x : SplitOctonion) :
    ωCycleL (split_neg x) = split_neg (ωCycleL x) := by
  rw [ωCycleL, ωCycleL, split_oct_mul_neg_right]

-- ============================================================================
-- SECTION 3: The emissive-absorptive cycle (e₄ · (x · e₄))
-- ============================================================================

/--
The **emissive-absorptive cycle**: `ωCycleEA(x) := e₄ · (x · e₄)`.

This composes a right-ω tick followed by a left-ω tick. The result is a map
that *negates* most basis vectors:
  - `ωCycleEA(e₁) = -e₁`, `ωCycleEA(e₅) = -e₅`
  - `ωCycleEA(e₂) = -e₂`, `ωCycleEA(e₆) = -e₆`
  - `ωCycleEA(e₃) = -e₃`, `ωCycleEA(e₇) = -e₇`
  - `ωCycleEA(e₀) = e₀`,   `ωCycleEA(e₄) = e₄`   (fixed)

It is an involution: `ωCycleEA² = id`.
-/
def ωCycleEA (x : SplitOctonion) : SplitOctonion :=
  ωCycleL (ωCycleR x)

/-- `ωCycleEA(e₁) = -e₁` — the emissive-absorptive cycle negates
    the kernel basis element. -/
theorem ωCycleEA_e1 : ωCycleEA e1_vec = split_neg e1_vec := by
  rfl

/-- `ωCycleEA(e₅) = -e₅` — the cycle also negates the ω-complement
    basis element e₅. -/
theorem ωCycleEA_e5 : ωCycleEA e5_vec = split_neg e5_vec := by
  rfl

/-- `ωCycleEA(e₀) = e₀` — the scalar is fixed by the cycle. -/
theorem ωCycleEA_e0 : ωCycleEA e0_vec = e0_vec := by
  rfl

/-- `ωCycleEA(e₄) = e₄` — the ω generator is fixed by the cycle. -/
theorem ωCycleEA_e4 : ωCycleEA e4_vec = e4_vec := by
  rfl

/-- Negation commutes with the emissive-absorptive cycle:
    `ωCycleEA(-x) = -ωCycleEA(x)`. -/
theorem ωCycleEA_neg (x : SplitOctonion) :
    ωCycleEA (split_neg x) = split_neg (ωCycleEA x) := by
  rw [ωCycleEA, ωCycleEA, ωCycleR_neg, ωCycleL_neg]

/-- `ωCycleEA²(e₁) = e₁` — period 2 on the kernel element. -/
theorem ωCycleEA_period2_e1 : ωCycleEA (ωCycleEA e1_vec) = e1_vec := by
  rw [ωCycleEA_e1, ωCycleEA_neg, ωCycleEA_e1, split_neg_neg]

/--
`ωCycleEA` negates every non-trivial basis element: it has exactly two
fixed points (`e₀` and `e₄`) and negates the other six.
-/
theorem ωCycleEA_negates_basis :
    ωCycleEA e0_vec = e0_vec ∧ ωCycleEA e4_vec = e4_vec ∧
    ωCycleEA e1_vec = split_neg e1_vec ∧ ωCycleEA e5_vec = split_neg e5_vec ∧
    ωCycleEA e2_vec = split_neg e2_vec ∧ ωCycleEA e6_vec = split_neg e6_vec ∧
    ωCycleEA e3_vec = split_neg e3_vec ∧ ωCycleEA e7_vec = split_neg e7_vec :=
  ⟨by rfl, by rfl, by rfl, by rfl, by rfl, by rfl, by rfl, by rfl⟩

-- ============================================================================
-- SECTION 4: Overshoot sign-flip on elements with zero scalar part
-- ============================================================================

/--
For an element `x` with zero real (e₀) component, overshoot is invariant
under negation: `overshoot(-x) = overshoot(x)`. This follows because
`(-x)·(-x) = x·x` (bilinearity squares away the sign) and `(-x).e₀ = -x.e₀ = 0`.
-/
theorem overshoot_neg_of_scalar_zero (x : SplitOctonion) (h : x.e0 = 0) :
    overshoot (split_neg x) = overshoot x := by
  dsimp [overshoot, scalarLandingSq, realProjection]
  have hsq : (split_oct_mul (split_neg x) (split_neg x)).e0 = (split_oct_mul x x).e0 := by
    simp [split_oct_mul_neg_left, split_oct_mul_neg_right, split_neg_neg]
  rw [hsq]
  simp [h, split_neg]

/-- The seven non-trivial basis vectors all have zero scalar component. -/
theorem basis_scalar_zero_chain :
    e1_vec.e0 = 0 ∧ e2_vec.e0 = 0 ∧ e3_vec.e0 = 0 ∧
    e4_vec.e0 = 0 ∧ e5_vec.e0 = 0 ∧ e6_vec.e0 = 0 ∧ e7_vec.e0 = 0 :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

-- Concrete consequences for the cycle
theorem overshoot_neg_e1 : overshoot (split_neg e1_vec) = overshoot e1_vec :=
  overshoot_neg_of_scalar_zero e1_vec (by exact rfl)

theorem overshoot_neg_e5 : overshoot (split_neg e5_vec) = overshoot e5_vec :=
  overshoot_neg_of_scalar_zero e5_vec (by exact rfl)

-- ============================================================================
-- SECTION 5: The 4-step cycle and thermal ledger closure
-- ============================================================================

/--
**Step 3 of the 4-step cycle**: `(-e₁)·e₄ = -e₅` — the second emissive
egress from the negated kernel element, which lands at the negated
complement element.

Sequence:
  Step 1: `e₁ →(ωR) e₅`   (emissive egress, `ωCycleR_e1`)
  Step 2: `e₅ →(ωL) -e₁`   (absorptive ingress, `ωCycleL_e5`)
  Step 3: `-e₁ →(ωR) -e₅`   (this theorem)
  Step 4: `-e₅ →(ωL) e₁`    (`ωCycleL_neg_e5`)
-/
theorem ωCycleR_neg_e1 : ωCycleR (split_neg e1_vec) = split_neg e5_vec := by
  rw [ωCycleR_neg, ωCycleR_e1]

/--
**Step 4 of the 4-step cycle**: `e₄·(-e₅) = e₁` — the second absorptive
ingress returns to the original starting element, closing the 4-step cycle.
-/
theorem ωCycleL_neg_e5 : ωCycleL (split_neg e5_vec) = e1_vec := by
  rw [ωCycleL_neg, ωCycleL_e5, split_neg_neg]

/--
**Overshoot ledger for the full 4-step emissive-absorptive cycle**.

The cycle `e₁ → e₅ → -e₁ → -e₅ → e₁` visits four distinct elements. The
overshoot at each is:

  | element | overshoot |
  |---------|-----------|
  | `e₁`    | `-1`      |
  | `e₅`    | `+1`      |
  | `-e₁`   | `-1`      |
  | `-e₅`   | `+1`      |
  | **Sum** | **0**     |

The existing theorem `supercomplete_cycle_persistent_thermal` proves that
the first three elements sum to `-1`. This theorem extends to the full
4-step return and proves the net overshoot is *zero* — the thermal ledger
closes across the complete orbit.

**Takeaway**: energy is conserved (`supercomplete_cycle_defect_zero`) and
the thermal ledger closes (`four_step_cycle_thermal_closure`), but only
after **four** steps. The modulus `M = strut_weight = 4` is the period
of this closure.
-/
theorem four_step_cycle_thermal_closure :
    overshoot e1_vec + overshoot e5_vec + overshoot (split_neg e1_vec) +
      overshoot (split_neg e5_vec) = 0 := by
  rw [overshoot_neg_e1, overshoot_neg_e5]
  rw [overshoot_e1_neg, overshoot_e5_pos]
  rfl

/--
**Thermal residue follows the 4-periodic pattern** `3 → 1 → 3 → 1 → 3`
over the cycle: starting from `e₁`, the residue visits `3` at `e₁`, `1` at
`e₅`, `3` at `-e₁`, `1` at `-e₅`, and returns to `3` at `e₁`.
-/
theorem thermalResidue_4periodic_cycle :
    thermalResidue e1_vec = 3 ∧ thermalResidue e5_vec = 1 ∧
    thermalResidue (split_neg e1_vec) = 3 ∧
    thermalResidue (split_neg e5_vec) = 1 := by
  refine ⟨thermalResidue_e1_mod4, thermalResidue_e5_mod4, ?_, ?_⟩
  · simpa [thermalResidue, strut_weight_eq_four, overshoot_neg_e1] using thermalResidue_e1_mod4
  · simpa [thermalResidue, strut_weight_eq_four, overshoot_neg_e5] using thermalResidue_e5_mod4

-- ============================================================================
-- SECTION 6: (Stretch) Closed-form formula for overshoot
-- ============================================================================

/--
**Closed-form formula** for `overshoot(x)` in terms of the component
vector `x = ⟨e₀, e₁, e₂, e₃, e₄, e₅, e₆, e₇⟩`:

```
overshoot(x) = x.e₀² - Σᵢ₌₁³ x.eᵢ² + Σᵢ₌₄⁷ x.eᵢ² - x.e₀
```

This follows from the split-octonion multiplication table:
  - `eᵢ·eᵢ = -e₀` for `i ∈ {1,2,3}` (kernel basis squares to `-e₀`)
  - `eᵢ·eᵢ = +e₀` for `i ∈ {4,5,6,7}` (complement basis squares to `+e₀`)
  - Cross terms `eᵢ·eⱼ` for `i ≠ j` have zero e₀ component.
-/
theorem overshoot_closed_form (x : SplitOctonion) :
    overshoot x = x.e0 ^ 2 - (x.e1 ^ 2 + x.e2 ^ 2 + x.e3 ^ 2) +
      (x.e4 ^ 2 + x.e5 ^ 2 + x.e6 ^ 2 + x.e7 ^ 2) - x.e0 := by
  dsimp [overshoot, scalarLandingSq, realProjection, split_oct_mul]
  ring

/--
**The zero-overshoot locus** is the quadratic hypersurface in ℤ⁸ defined by:

  `x.e₀² - Σᵢ₌₁³ x.eᵢ² + Σᵢ₌₄⁷ x.eᵢ² = x.e₀`

The idempotent locus `{0, e₀}` is strictly contained in the zero-overshoot
locus (already proven as `overshoot_locus_strictly_extends_idempotents` in
`ThermalResidue.lean`). This formula gives an explicit algebraic description
of the full set.
-/
theorem zero_overshoot_condition (x : SplitOctonion) :
    overshoot x = 0 ↔
      x.e0 ^ 2 - (x.e1 ^ 2 + x.e2 ^ 2 + x.e3 ^ 2) +
        (x.e4 ^ 2 + x.e5 ^ 2 + x.e6 ^ 2 + x.e7 ^ 2) = x.e0 := by
  rw [overshoot_closed_form]
  constructor
  · intro h; omega
  · intro h; omega
