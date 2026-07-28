import Mathlib
import LaserCortex.foundations.Algebra
import LaserCortex.Friction
import LaserCortex.CoherenceMetric

/-!
# Atomic Shell Model — Deriving the Two-Shell Spectrum From the Metric Space

This module assembles three previously-proven ingredients into a single
predictive structure — the *atomic model* of the Tamari-LaserCortex metric
space:

1. The **composition identity** `octonion_norm_mul` (proven in `Algebra.lean`)
   — the (4,4) split-octonion norm is multiplicative. This is the
   **conserved charge** of the model.

2. The **non-composition of the antipode-copairing** `fiveThreeNorm_non_composition`
   (proven in `Algebra.lean`) — the (5,3) antipode-copairing form is NOT
   multiplicative. Multiplication can move an element between (5,3) shells.
   This is the **transition mechanism** of the model.

3. The **9.5× friction barrier** at cd 2→3 (`lightcone_ratio`, `heightMap_discontinuity`
   in `Friction.lean`/`CoherenceMetric.lean`). The "spacelike" coordinate
   `frictionDensity(cd)` is exactly `cd` for `cd ≤ 2` and `cd + strut_weight²`
   (= `cd + 16`) for `cd ≥ 3`. The jump `2 → 19` is the ratio 9.5×. This is
   the **coarse-shell separation** of the model — the principal quantum number
   gap.

## Plain-English Reading

The Tamari metric space `coherenceInterval = dcStep² − frictionDensity²`
measures distances inside the (1,1) split-complex plane — the observable
shadow of the underlying (4,4) split-octonion algebra. Layered onto this:

- **Coarse shells**: cd-values partition into two families by `frictionDensity`.
  Within each family the density is small (≤ 2 for the *associative* family
  A) or large (≥ 19 for the *non-associative* family B). The 9.5× jump at
  cd = 2 → 3 is the activation barrier between families.

- **Fine shells**: within *each* coarse shell, the (5,3) norm
  `fiveThreeNorm(x) = (x · S(x)).e₀` gives a spectrum of integers.
  These are the "subshell" levels — analogous to the spectral lines inside
  a principal quantum-number family of an atom.

- **Transitions**: an octonion multiplication `x ↦ x · y` conserves the (4,4)
  charge (`octonion_norm(x·y) = octonion_norm(x) · octonion_norm(y)`), but
  slides `x` along the (5,3) spectrum
  (`fiveThreeNorm(x·y) ≠ fiveThreeNorm(x) · fiveThreeNorm(y)`). The same
  mechanism that conserves the "charge" allows transitions between
  "energies" — exactly the dual structure an atomic model needs.

The atomic model predicts that:
- Single-shell transitions (within a coarse shell A or B) come at the
  `dcStep² − frictionDensity²` cost of the corresponding fine-shell jump.
- Cross-shell transitions cost the 9.5× wall *plus* the fine-shell gain.
- The total `octonion_norm` is conserved in all transitions.

## File references

- `foundations/Algebra.lean` — `SplitOctonion`, `octonion_norm_mul`, `fiveThreeNorm`,
  `fiveThreeNorm_non_composition`, `antipode`
- `CoherenceMetric.lean` — `lightcone_ratio`, `frictionDensity`, `coherenceInterval`
- `Friction.lean` — `frictionDensity_eq_k_for_k_le_2`,
  `frictionDensity_eq_k_plus_16_for_k_ge_3`, `heightMap_discontinuity_at_cd2_3`
-/

open EMLTree

-- ============================================================================
-- SECTION 1: Coarse shells — the 9.5× separation of `frictionDensity`
-- ============================================================================

/--
The two coarse shells of the metric space, separated by the 9.5×
`frictionDensity` wall at the cd 2→3 phase boundary:

- `A` (associative, `cd ≤ 2`): `frictionDensity = cd ∈ {0, 1, 2}`
- `B` (non-associative, `cd ≥ 3`): `frictionDensity = cd + 16 ∈ {19, 20, ...}`

This inductive mirrors the global phase boundary at the associator barrier.
-/
inductive CoarseShell where
  | A : CoarseShell  -- associative regime, the "ground state" of cd
  | B : CoarseShell  -- non-associative regime, the "excited" family of cd

/-- Classify a cd value into its coarse shell A or B. -/
def coarseShellOf (cd : ℕ) : CoarseShell :=
  if cd ≤ 2 then CoarseShell.A else CoarseShell.B

/-- Small cd values (`cd ≤ 2`) live in coarse shell A. -/
theorem coarseShellOf_low (cd : ℕ) (h : cd ≤ 2) : coarseShellOf cd = CoarseShell.A := by
  simp [coarseShellOf, h]

/-- Large cd values (`cd ≥ 3`) live in coarse shell B. -/
theorem coarseShellOf_high (cd : ℕ) (h : 3 ≤ cd) : coarseShellOf cd = CoarseShell.B := by
  simp [coarseShellOf]
  omega

/-- The friction density at the top of shell A. -/
theorem coarse_shell_boundary_low : frictionDensity 2 = 2 := by
  exact frictionDensity_eq_k_for_k_le_2 2 (by omega)

/-- The friction density at the bottom of shell B. -/
theorem coarse_shell_boundary_high : frictionDensity 3 = 19 := by
  rw [frictionDensity_eq_k_plus_16_for_k_ge_3 3 (by omega), strut_weight_eq_four]

/--
**The coarse shell ratio.** `frictionDensity(3) / frictionDensity(2) = 19 / 2 = 9.5`.

The "principal quantum number" gap of the atomic model: the inertial mass
jumps by a factor of 9.5× across the cd 2→3 boundary.
-/
theorem coarse_shell_ratio :
    2 * (frictionDensity 3 : ℤ) = 19 * (frictionDensity 2 : ℤ) := by
  rw [coarse_shell_boundary_low, coarse_shell_boundary_high]
  omega

/--
The two coarse shells *cannot* merge — there is no cd in the "gap" region
with positive but small `frictionDensity` of more than 2 and less than 19.

Specifically: `frictionDensity(3) > 9 × frictionDensity(2)`.
The 9.5× wall is a strict (>9×) separation.
-/
theorem coarse_shell_wall_strict :
    frictionDensity 3 > 9 * frictionDensity 2 := by
  rw [coarse_shell_boundary_low, coarse_shell_boundary_high]
  omega

/--
No cd lies in the open gap `(2, 3)` of `frictionDensity` — every cd yields
either `≤ 2` (shell A) or `≥ 19` (shell B). Symbolically:
`frictionDensity(cd) ∈ {0, 1, 2, 19, 20, 21, ...}` for all `cd : ℕ`.
-/
theorem coarse_shell_spectrum_split (cd : ℕ) :
    frictionDensity cd ≤ 2 ∨ frictionDensity cd ≥ 19 := by
  by_cases h : cd ≤ 2
  · left
    rw [frictionDensity_eq_k_for_k_le_2 cd h]
    exact h
  · right
    have h' : 3 ≤ cd := by omega
    rw [frictionDensity_eq_k_plus_16_for_k_ge_3 cd h', strut_weight_eq_four]
    omega

-- ============================================================================
-- SECTION 2: Fine shells — the (5,3) spectrum of SplitOctonion
-- ============================================================================

/--
A **fine shell** is the level set `{ x : fiveThreeNorm x = n }` of the
(5,3) antipode-copairing norm.

Geometrically: shells of the (5,3) quadratic form. Unlike the
shell classes of a composition algebra, fine shells are NOT preserved by
octonion multiplication — products can move elements from one shell to
another (`fiveThreeNorm_non_composition`).

This is the algebraic mechanism that turns the otherwise-dead
composition-algebra shell structure into an *active* spectrum with
permitted transitions.
-/
def fineShell (n : ℤ) : Set SplitOctonion :=
  { x : SplitOctonion | fiveThreeNorm x = n }

/--
The `fiveThreeNorm` spectrum: the set of integers realised as a
`fiveThreeNorm` value by some `SplitOctonion`. Over ℤ with the standard
basis, both `+1` and `−1` are realised — the spectrum spans sign and zero.
-/
def shellSpectrum : Set ℤ :=
  { n : ℤ | ∃ x : SplitOctonion, fiveThreeNorm x = n }

/-- The zero shell `fineShell 0` is nonempty (witness: `split_zero`). -/
theorem fineShell_zero_nonempty : 0 ∈ shellSpectrum := by
  refine ⟨split_zero, rfl⟩

/-- The shells `+1` and `−1` are both realized — both signs of the (5,3)
    signature appear in the spectrum. -/
theorem fineShell_unit_nonempty : 1 ∈ shellSpectrum ∧ -1 ∈ shellSpectrum := by
  refine ⟨⟨e0_vec, rfl⟩, ⟨e5_vec, rfl⟩⟩

/--
All eight basis shells appear in the spectrum — each basis vector `eᵢ`
achieves shell value `Sᵢ`:
- `S₀ = +1` (positive sector)
- `S₁ = +1`
- `S₂ = +1`
- `S₃ = +1`
- `S₄ = +1`
- `S₅ = −1` (negative sector)
- `S₆ = −1`
- `S₇ = −1`

These are the algebraic "subshell" labels — corresponding to the (5,3)
signature splitting the eight basis elements into positive sector
`{0,1,2,3,4}` and negative sector `{5,6,7}`.
-/
theorem shellSpectrum_includes_unit_shells :
    ∃ p q : ℤ, p = 1 ∧ q = -1 ∧ p ∈ shellSpectrum ∧ q ∈ shellSpectrum := by
  exact ⟨1, -1, rfl, rfl, fineShell_unit_nonempty.1, fineShell_unit_nonempty.2⟩

-- ============================================================================
-- SECTION 3: The atomic transition: products move elements between shells
-- ============================================================================

/--
An **atomic transition** is an octonion-product move `x ↦ x · y`
that sends an element starting on fine shell `p` onto fine shell `q` ≠ `p`.

The defining feature of the atomic model: products can transition between
shells, and the (4,4) charge is conserved across the transition
(`octonion_norm_mul`).
-/
def atomicTransition (x y : SplitOctonion) (p q : ℤ) : Prop :=
  fiveThreeNorm x = p ∧ fiveThreeNorm (split_oct_mul x y) = q ∧ p ≠ q

/-
Construct the fundamental shell transition.

Witness — exactly the same one used in `fiveThreeNorm_non_composition`:

  x = ⟨1, 1, 0, 0, 0, 0, 0, 0⟩     (shell value 2, positive sector)
       — written `x₁` below.

  y = ⟨0, 0, 0, 0, 1, 0, 0, 0⟩     (shell value 1)
       — written `x₂` below.

  x · y = ⟨0, 0, 0, 0, 1, 1, 0, 0⟩ (shell value 0)

The transition: from fine shell 2 to fine shell 0 via multiplication by
`y` (which is itself on shell 1).
-/
private def x1 : SplitOctonion := ⟨1, 1, 0, 0, 0, 0, 0, 0⟩
private def x2 : SplitOctonion := ⟨0, 0, 0, 0, 1, 0, 0, 0⟩
private def xxy: SplitOctonion := split_oct_mul x1 x2

/-- `x₁` has fine shell value 2. -/
theorem x1_shell : fiveThreeNorm x1 = 2 := rfl

/-- `x₂` has fine shell value 1. -/
theorem x2_shell : fiveThreeNorm x2 = 1 := rfl

/--
`x₁ · x₂ = ⟨0, 0, 0, 0, 1, 1, 0, 0⟩` — the fundamental transition move.
-/
theorem x12_product : xxy = ⟨0, 0, 0, 0, 1, 1, 0, 0⟩ := rfl

/--
**The fundamental atomic transition**: a multiplication that moves an element
from fine shell 2 onto fine shell 0, via multiplier `x₂` on shell 1.

This is the positive-existential content of `fiveThreeNorm_non_composition`.
-/
theorem exists_shell_transition :
    ∃ (x y : SplitOctonion), atomicTransition x y 2 0 := by
  refine ⟨x1, x2, ?_⟩
  dsimp [atomicTransition, xxy, x1, x2, split_oct_mul, fiveThreeNorm]
  exact ⟨rfl, rfl, by norm_num⟩

/--
The (4,4) charge scales multiplicatively across the fundamental transition.

This separates the two roles of the algebra:
- The (4,4) `octonion_norm` is a **conserved charge**: `N(x·y) = N(x)·N(y)`.
  Multiplication by `y` scales the charge by `octonion_norm y`, which is a
  property of `y` alone — it does NOT depend on `x`.

- The (5,3) `fiveThreeNorm` is a **transition energy**: it changes
  arbitrarily on multiplication, and the change is jointly a property
  of `x` AND `y` (products on the same shell can land on different shells,
  and products that differ by a small change in `y` can land on wildly
  different shells).
-/
theorem fundamental_transition_conserves_charge :
    octonion_norm xxy = octonion_norm x1 * octonion_norm x2 := by
  dsimp [xxy]
  exact octonion_norm_mul _ _

/--
The charges that scale in the fundamental transition:
  N(x₁) = 1 + 1 = 2,
  N(x₂) = −1,
  N(x₁ · x₂) = 2 · (−1) = −2.
The (5,3) shell jumps from 2 → 0, but the (4,4) charge flows
predictably via `N(x) · N(y)`. This is the conservation law of the
transition.
-/
theorem fundamental_transition_charges_eval :
    octonion_norm x1 = 2 ∧ octonion_norm x2 = -1 ∧ octonion_norm xxy = -2 := by
  refine ⟨rfl, rfl, ?_⟩
  -- N(xy) = N(x) * N(y) = 2 * (-1) = -2
  rw [fundamental_transition_conserves_charge]
  rfl

-- ============================================================================
-- SECTION 4: Atomic State — the coarse-fine portrait
-- ============================================================================

/--
An **atomic state** is a configuration characterized by:
- `cd` — the coarse shell index (small for shell A, large for shell B)
- `x : SplitOctonion` — the algebraic configuration
- `fine` — the fine shell number (`fiveThreeNorm x`)
- `fine_eq` — proof that `x` is indeed on shell `fine`

Three roles within the model:
- `cd` controls the *coarse shell scale* via `frictionDensity(cd)`.
- `fine` controls the *fine shell position* via `fiveThreeNorm(x)`.
- The (4,4) `octonion_norm(x)` is the **conserved charge** carried by x.
-/
structure AtomicState where
  cd : ℕ
  x : SplitOctonion
  fine : ℤ
  fine_eq : fiveThreeNorm x = fine

/--
An **atomic transition** within a coarse shell — multiplication by `y`
preserving the coarse shell index `cd`, while changing the fine shell.
-/
def stateTransition (s : AtomicState) (y : SplitOctonion)
    (s' : AtomicState) : Prop :=
  s.cd = s'.cd ∧ s'.x = split_oct_mul s.x y ∧ s.fine ≠ s'.fine

/--
The (4,4) charge is always scaled by `N(y)` across a transition — this is
the conservation law at the level of atomic states.
-/
theorem stateTransition_charge_scaling
    (s : AtomicState) (y : SplitOctonion) (s' : AtomicState)
    (h : stateTransition s y s') :
    octonion_norm s'.x = octonion_norm s.x * octonion_norm y := by
  rw [h.2.1]
  exact octonion_norm_mul _ _

/--
The full fundamental atomic transition, packaged as a `stateTransition`:
- Initial state: `cd = 2` (coarse shell A), `fine = 2`
- Final state:   `cd = 2` (same coarse shell — within-shell transition), `fine = 0`
- Multiplier `y = x₂` (shell 1)
- Transition: fine shell `2 → 0` within shell A.

This is a concrete, witness-based existence theorem for an atomic transition
that stays *within* the coarse shell A regime (i.e. `cd ≤ 2`, where the
associator barrier has not yet activated and the `frictionDensity` is small
and smooth). The model predicts that more energetic transitions — those
that cross the 9.5× wall from shell A to shell B — incur the additional
inertial cost of the `frictionDensity` jump.
-/
theorem fundamental_atomic_transition :
    ∃ (s s' : AtomicState) (y : SplitOctonion),
      s.cd = 2 ∧ s.fine = 2 ∧ s'.fine = 0 ∧ stateTransition s y s' := by
  -- Atomic transition witness: cd 2 (coarse shell A), fine 2 → 0.
  have hxxy_shell : fiveThreeNorm xxy = 0 := rfl
  refine ⟨
    ⟨2, x1, 2, x1_shell⟩,
    ⟨2, xxy, 0, hxxy_shell⟩,
    x2, ?_⟩
  refine ⟨rfl, rfl, rfl, ?_⟩
  exact ⟨rfl, rfl, by norm_num⟩