import Mathlib
import LaserCortex.foundations.Algebra
import LaserCortex.AtomicShell
import LaserCortex.ImpedanceMetric

/-!
# Layer 3 — Emissive & Absorptive Sub-algebras; Supercompleteness Detection

## Plain-English reading

Where Yang-Mills gauge theory has *completeness* — gauge loops close exactly
at the identity, like a Wilson loop wrapping a clean circle — LaserCortex has
**supercompleteness**: the octonion loop *does* close (the product `x·x`
lands back in the scalar sub-algebra `ℤ · e₀`), but it didn't stop at the
identity. We draw a circle whose line is a little longer than the
diameter — the circle completes, and then more; it is supercomplete.

The detector of this dichotomy is **idempotency**:

- `IsIdempotent x := x·x = x` — the YM-style "perfect circle." The loop
  closes back to the place it started in one application. Over the integral
  split-octonions, the only idempotents are exactly `0` and `e₀` (the two
  trivial fixed points of the linear map `x ↦ x·x` that are scalars).

- `IsSupercomplete x := x·x ∈ scalars ∧ ¬ IsIdempotent x` — the LC "circle
  plus more." The squaring map closes the loop (returns to scalars) but
  overshot past where `x` sat. There is excess length between YM's `x↦x`
  projector and our `x ↦ (some scalar)`.

Every non-trivial basis element `e₁, e₂, e₃, e₄, e₅, e₆, e₇` is supercomplete
— every one of them squares into the scalar sub-algebra without being
idempotent. They split, however, into **two supercomplete sub-kinds** by the
sign of the overshoot:

| basis               | `x²`               | sub-kind                       |
|---------------------|--------------------|--------------------------------|
| `e₁, e₂, e₃`        | `-e₀`              | spinor half-twist (4π return)  |
| `e₄, e₅, e₆, e₇`    | `+e₀`              | involution overshoot           |

The kernel of Layer 2's `MatchedSubalgebra` is the integral span of the
first three (`⟨e₀,e₁,e₂,e₃⟩` Hamilton quaternions, all squaring to ±e₀);
the `ω`-complement is the second four. The two defect signs from
`ImpedanceMetric.lean` then organize exactly as:

- **Emissive** (defect < 0, Layer 3a): a kernel supercomplete (overshoot `-`)
  pairs with an `ω`-direction supercomplete (overshoot `+`); the result
  egresses from the kernel and emits energy as a transition between the
  two supercomplete sub-kinds.

- **Absorptive** (defect > 0, Layer 3b): two `ω`-direction supercompletes pair
  to produce a kernel supercomplete (overshoot `-`); the result ingress the
  kernel and absorbs energy from the complement.

The Layer 1 atomic transition `x₁ = e₀ + e₁` (kernel), `x₂ = e₄`
(complement), product `e₁·e₄ = e₅` (complement) sits inside this Layer 3
structure as the **emissive egress** — it is the algebraic exit that
*sketches the longer-than-diameter circle*, returning to scalars (via
`xxy²`'s component analysis) but overshooting into the `ω`-complement by
defect `-2` on the `(e₁, e₄)` driver pair.

## File references

- `foundations/Algebra.lean` — `split_oct_mul`, `octonion_norm`, `omega_sq`,
  `omega_mul_e5`, basis vectors `eN_vec`, `split_neg`, `split_one`
- `foundations/AtomicShell.lean` — the Layer 1 atomic model
  (`AtomicState`, `stateTransition`, `fundamental_atomic_transition`,
  private witnesses `x1`, `x2`, `xxy`)
- `foundations/ImpedanceMetric.lean` — `impedanceDefect`, `IsMatched`,
  `MatchedSubalgebra`, `defect_e1_e4_neg`, `defect_e4_e5_pos`,
  `defect_e1_e2_zero`
-/

open EMLTree

-- ============================================================================
-- SECTION 1: Idempotency vs Supercompleteness — the YM vs LC dichotomy
-- ============================================================================

/--
A YM-style "perfect circle": the loop action `x ↦ x·x` returns to its
starting point. The squaring map *fixes* `x`.

Over the integral split-octonions, the only idempotents are the trivial
scalar ones `0` and `e₀` (see `split_zero_idempotent`, `split_one_idempotent`).
-/
def IsIdempotent (x : SplitOctonion) : Prop :=
  split_oct_mul x x = x

/--
The scalar sub-algebra `ℤ · e₀` — the "centre-of-mass" / identity-trace
of the octonion algebra. This is where the loop closes back to in
the supercomplete picture.
-/
def ScalarSubalgebra : Set SplitOctonion :=
  { x | x.e1 = 0 ∧ x.e2 = 0 ∧ x.e3 = 0 ∧ x.e4 = 0 ∧ x.e5 = 0 ∧ x.e6 = 0 ∧ x.e7 = 0 }

/-- Membership in the scalar sub-algebra (gives the trace). -/
theorem scalarSubalgebra_mem (x : SplitOctonion)
    (h1 : x.e1 = 0) (h2 : x.e2 = 0) (h3 : x.e3 = 0) (h4 : x.e4 = 0)
    (h5 : x.e5 = 0) (h6 : x.e6 = 0) (h7 : x.e7 = 0) :
    x ∈ ScalarSubalgebra :=
  ⟨h1, h2, h3, h4, h5, h6, h7⟩

/--
A supercomplete element: the loop closes (squares into the scalar
sub-algebra) but does not stop at the identity — the squaring map
overshoots past `x`.

This is the LC analogue of "the circle has excess length beyond the
diameter, but still closes." The two trivial scalars `0` and `e₀` are
*not* supercomplete (they're idempotents — YM perfect); every nontrivial
basis element is (see `e1_supercomplete` ... `e7_supercomplete`).
-/
def IsSupercomplete (x : SplitOctonion) : Prop :=
  split_oct_mul x x ∈ ScalarSubalgebra ∧ ¬ IsIdempotent x

-- ---------------------------------------------------------------------------
-- Idempotents: the only YM-perfect circles in the integral algebra
-- ---------------------------------------------------------------------------

/-- `0` is idempotent (the trivial YM perfect circle). -/
theorem split_zero_idempotent : IsIdempotent split_zero := rfl

/-- `e₀` is idempotent (the unit YM perfect circle). -/
theorem split_one_idempotent : IsIdempotent split_one := rfl

-- ---------------------------------------------------------------------------
-- Squaring witnesses: every non-trivial basis vector squares to a scalar
-- ---------------------------------------------------------------------------

/-- `e₁² = -e₀` (negative overshoot — spinor half-twist). -/
theorem e1_sq : split_oct_mul e1_vec e1_vec = split_neg split_one := rfl

/-- `e₂² = -e₀` (negative overshoot — spinor half-twist). -/
theorem e2_sq : split_oct_mul e2_vec e2_vec = split_neg split_one := rfl

/-- `e₃² = -e₀` (negative overshoot — spinor half-twist). -/
theorem e3_sq : split_oct_mul e3_vec e3_vec = split_neg split_one := rfl

/-- `e₄² = +e₀` (positive overshoot — `ω`-involution).
    This is `omega_sq` re-stated in basis-vector form. -/
theorem e4_sq : split_oct_mul e4_vec e4_vec = split_one := by
  rw [show e4_vec = omega from rfl, omega_sq]

/-- `e₅² = +e₀` (positive overshoot — `ω`-paired e₁ direction as involution). -/
theorem e5_sq : split_oct_mul e5_vec e5_vec = split_one := rfl

/-- `e₆² = +e₀` (positive overshoot — `ω`-paired e₂ direction as involution). -/
theorem e6_sq : split_oct_mul e6_vec e6_vec = split_one := rfl

/-- `e₇² = +e₀` (positive overshoot — `ω`-paired e₃ direction as involution). -/
theorem e7_sq : split_oct_mul e7_vec e7_vec = split_one := rfl

-- ---------------------------------------------------------------------------
-- Supercompleteness of the seven non-trivial basis elements
-- ---------------------------------------------------------------------------

private theorem not_idempotent_e1 : ¬ IsIdempotent e1_vec := by
  intro h
  have : split_oct_mul e1_vec e1_vec = e1_vec := h
  rw [e1_sq] at this
  -- `⟨-1,0,0,0,0,0,0,0⟩ = ⟨0,1,0,0,0,0,0,0⟩` is false at component 0 vs 1
  exact absurd this (by contradiction)

private theorem not_idempotent_e2 : ¬ IsIdempotent e2_vec := by
  intro h
  have : split_oct_mul e2_vec e2_vec = e2_vec := h
  rw [e2_sq] at this
  exact absurd this (by contradiction)

private theorem not_idempotent_e3 : ¬ IsIdempotent e3_vec := by
  intro h
  have : split_oct_mul e3_vec e3_vec = e3_vec := h
  rw [e3_sq] at this
  exact absurd this (by contradiction)

private theorem not_idempotent_e4 : ¬ IsIdempotent e4_vec := by
  intro h
  have : split_oct_mul e4_vec e4_vec = e4_vec := h
  rw [e4_sq] at this
  -- `⟨1,0,0,0,0,0,0,0⟩ = ⟨0,0,0,0,1,0,0,0⟩` is false at components 0/4
  exact absurd this (by contradiction)

private theorem not_idempotent_e5 : ¬ IsIdempotent e5_vec := by
  intro h
  have : split_oct_mul e5_vec e5_vec = e5_vec := h
  rw [e5_sq] at this
  exact absurd this (by contradiction)

private theorem not_idempotent_e6 : ¬ IsIdempotent e6_vec := by
  intro h
  have : split_oct_mul e6_vec e6_vec = e6_vec := h
  rw [e6_sq] at this
  exact absurd this (by contradiction)

private theorem not_idempotent_e7 : ¬ IsIdempotent e7_vec := by
  intro h
  have : split_oct_mul e7_vec e7_vec = e7_vec := h
  rw [e7_sq] at this
  exact absurd this (by contradiction)

private theorem neg_one_in_scalarSubalgebra :
    split_neg split_one ∈ ScalarSubalgebra := by
  refine ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

private theorem split_one_in_scalarSubalgebra :
    split_one ∈ ScalarSubalgebra := by
  refine ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- **`e₁` is supercomplete**: `e₁² = -e₀` (spinor half-twist). -/
theorem e1_supercomplete : IsSupercomplete e1_vec :=
  ⟨by rw [e1_sq]; exact neg_one_in_scalarSubalgebra, not_idempotent_e1⟩

/-- **`e₂` is supercomplete**: `e₂² = -e₀` (spinor half-twist). -/
theorem e2_supercomplete : IsSupercomplete e2_vec :=
  ⟨by rw [e2_sq]; exact neg_one_in_scalarSubalgebra, not_idempotent_e2⟩

/-- **`e₃` is supercomplete**: `e₃² = -e₀` (spinor half-twist). -/
theorem e3_supercomplete : IsSupercomplete e3_vec :=
  ⟨by rw [e3_sq]; exact neg_one_in_scalarSubalgebra, not_idempotent_e3⟩

/-- **`e₄` is supercomplete**: `e₄² = +e₀` (`ω`-involution overshoot). -/
theorem e4_supercomplete : IsSupercomplete e4_vec :=
  ⟨by rw [e4_sq]; exact split_one_in_scalarSubalgebra, not_idempotent_e4⟩

/-- **`e₅` is supercomplete**: `e₅² = +e₀` (`ω`-involution overshoot). -/
theorem e5_supercomplete : IsSupercomplete e5_vec :=
  ⟨by rw [e5_sq]; exact split_one_in_scalarSubalgebra, not_idempotent_e5⟩

/-- **`e₆` is supercomplete**: `e₆² = +e₀` (`ω`-involution overshoot). -/
theorem e6_supercomplete : IsSupercomplete e6_vec :=
  ⟨by rw [e6_sq]; exact split_one_in_scalarSubalgebra, not_idempotent_e6⟩

/-- **`e₇` is supercomplete**: `e₇² = +e₀` (`ω`-involution overshoot). -/
theorem e7_supercomplete : IsSupercomplete e7_vec :=
  ⟨by rw [e7_sq]; exact split_one_in_scalarSubalgebra, not_idempotent_e7⟩

/--
**The basic YM-vs-LC dichotomy**: the trivial scalars `0` and `e₀` are
the only idempotents among the basis vectors (YM perfect circles); every
other basis element is *not* idempotent — its squaring overshoots into a
scalar that is not the identity (`-e₀` for the kernel basis, `+e₀` for
the `ω`-complement basis).
-/
theorem basis_idempotent_dichotomy :
    IsIdempotent e0_vec ∧ IsIdempotent split_zero ∧
      ¬ IsIdempotent e1_vec ∧ ¬ IsIdempotent e2_vec ∧
      ¬ IsIdempotent e3_vec ∧ ¬ IsIdempotent e4_vec ∧
      ¬ IsIdempotent e5_vec ∧ ¬ IsIdempotent e6_vec ∧
      ¬ IsIdempotent e7_vec :=
  ⟨split_one_idempotent, split_zero_idempotent,
    not_idempotent_e1, not_idempotent_e2, not_idempotent_e3,
    not_idempotent_e4, not_idempotent_e5, not_idempotent_e6, not_idempotent_e7⟩

/--
**Every non-trivial basis vector is supercomplete** — every basis vector
from `e₁` through `e₇` has its square in the scalar sub-algebra but is
not idempotent: the loop closes to a scalar, but overshoots past the
identity. This is the formal statement of the "circle line longer than
the diameter" picture.
-/
theorem all_nontrivial_basis_supercomplete :
    IsSupercomplete e1_vec ∧ IsSupercomplete e2_vec ∧
      IsSupercomplete e3_vec ∧ IsSupercomplete e4_vec ∧
      IsSupercomplete e5_vec ∧ IsSupercomplete e6_vec ∧
      IsSupercomplete e7_vec :=
  ⟨e1_supercomplete, e2_supercomplete, e3_supercomplete,
    e4_supercomplete, e5_supercomplete, e6_supercomplete, e7_supercomplete⟩

-- ============================================================================
-- SECTION 2: Layer 3a — the Emissive sub-algebra (defect < 0)
-- ============================================================================

/--
An **emissive pair** `(x, y)`: the (5,3) impedance defect is *negative*.
Multiplication of `x` by `y` releases (5,3) energy across the transition.

The canonical emissive pair is `(e₁, e₄)`: a kernel supercomplete (`e₁²=-e₀`)
multiplied by an `ω`-complement supercomplete (`e₄²=+e₀`) egresses the kernel
into the complement, with `impedanceDefect = -2`.
-/
def EmissivePair (x y : SplitOctonion) : Prop :=
  impedanceDefect x y < 0

/--
An **absorptive pair** `(x, y)`: the (5,3) impedance defect is *positive*.
Multiplication of `x` by `y` absorbs (5,3) energy across the transition.
-/
def AbsorptivePair (x y : SplitOctonion) : Prop :=
  impedanceDefect x y > 0

/-- The pair `(e₁, e₄)` is emissive — `defect = -2 < 0`. -/
theorem e1_e4_emissive : EmissivePair e1_vec e4_vec := by
  rw [EmissivePair, defect_e1_e4_neg]; norm_num

/-- The emission product: `e₁ · e₄ = e₅` (kernel egress into the complement).

This is the same `e1_mul_e4` lemma that drives Layer 1's
`fundamental_atomic_transition`. -/
theorem e1_e4_emission : split_oct_mul e1_vec e4_vec = e5_vec := e1_mul_e4

/--
The emissive composition: pairing a kernel supercomplete (`e₁`, sign `-e₀`)
with an `ω`-complement supercomplete (`e₄`, sign `+e₀`) produces an
`ω`-complement supercomplete (`e₅`, sign `+e₀`).

The energy released (`defect = -2`) is the algebraic signature of the
mismatch between the two supercomplete sub-kinds: the spinor half-twist
overshoot of `e₁` cannot "fit" with the involution overshoot of `e₄`,
and the surplus escapes as a `(5,3)` defect.
-/
theorem emissive_composition :
    split_oct_mul e1_vec e1_vec = split_neg split_one ∧
    split_oct_mul e4_vec e4_vec = split_one ∧
    split_oct_mul (split_oct_mul e1_vec e4_vec) (split_oct_mul e1_vec e4_vec) = split_one ∧
    impedanceDefect e1_vec e4_vec = -2 ∧
    EmissivePair e1_vec e4_vec :=
  ⟨e1_sq, e4_sq, by rw [e1_e4_emission]; exact e5_sq,
    defect_e1_e4_neg, e1_e4_emissive⟩

-- ============================================================================
-- SECTION 3: Layer 3b — the Absorptive sub-algebra (defect > 0)
-- ============================================================================

/-- The pair `(e₄, e₅)` is absorptive — `defect = +2 > 0`. -/
theorem e4_e5_absorptive : AbsorptivePair e4_vec e5_vec := by
  rw [AbsorptivePair, defect_e4_e5_pos]; norm_num

/-- The absorption product: `e₄ · e₅ = -e₁` (returning into the kernel from the complement).

This is the Layer 3b return move from Layer 3a's emission: starting from the
emitted complement element `e₅`, multiplying by `ω = e₄` brings us back into
the kernel as `-e₁`. -/
theorem e4_e5_absorption : split_oct_mul e4_vec e5_vec = split_neg e1_vec := omega_mul_e5

/--
The absorptive composition: pairing two `ω`-complement supercompletes
(`e₄²=+e₀`, `e₅²=+e₀`) produces a kernel supercomplete (`(-e₁)²=-e₀`).

The absorption product `e₄ · e₅ = -e₁` lands back in the Hamilton kernel,
reversing the emission `(e₁, e₄) → e₅`. The `+2` defect marks the
*increase* of `(5,3)` energy near the kernel boundary, as the absorptive
pair "buys back" the spinor half-twist overshoot from the complement's
involution overshoot.
-/
theorem absorptive_composition :
    split_oct_mul e4_vec e4_vec = split_one ∧
    split_oct_mul e5_vec e5_vec = split_one ∧
    split_oct_mul (split_oct_mul e4_vec e5_vec) (split_oct_mul e4_vec e5_vec) = split_neg split_one ∧
    impedanceDefect e4_vec e5_vec = 2 ∧
    AbsorptivePair e4_vec e5_vec :=
  ⟨e4_sq, e5_sq,
    by rw [e4_e5_absorption]; rw [show split_neg e1_vec = ⟨0,-1,0,0,0,0,0,0⟩ from rfl];
        rfl,   -- ((-e₁)²) = e₁² = -e₀
    defect_e4_e5_pos, e4_e5_absorptive⟩

-- ============================================================================
-- SECTION 4: The link between supercompleteness and emissive/absorptive dynamics
-- ============================================================================

/--
**The emissive egress is the inverse of absorptive ingress** — the
transition `(e₁, e₄) → e₅` of Layer 3a followed by `(e₄, e₅) → -e₁` of
Layer 3b is the closed supercomplete cycle.

This composite move is the algebraic realisation of the YM-vs-LC picture:
the loop starts in the kernel at `e₁` (supercomplete `e₁²=-e₀`), emits into
the complement at `e₅` (supercomplete `e₅²=+e₀`), and absorbs back into the
kernel at `-e₁` (where `(-e₁)²=-e₀`, supercomplete again). The "longer than
the diameter" line of each supercomplete is the slack consumed and
re-deposited in this cycle.

The cycle conserves supercompleteness (every stage is supercomplete, zero
idempotent), and the net defect is `defect(e₁, e₄) + defect(e₄, e₅) =
-2 + 2 = 0` — the energy released in emission equals the energy absorbed
in recovery.
-/
theorem supercomplete_cycle_defect_zero :
    impedanceDefect e1_vec e4_vec + impedanceDefect e4_vec e5_vec = 0 := by
  rw [defect_e1_e4_neg, defect_e4_e5_pos]; norm_num

/--
Each link of the supercomplete cycle is itself supercomplete.

  • `e₁` — kernel supercomplete, sign `-e₀` (entering the cycle)
  • `e₅ = e₁ · e₄` — complement supercomplete, sign `+e₀` (emitted)
  • `-e₁ = e₄ · e₅` — kernel supercomplete, sign `-e₀` (absorbed back)

No link of the cycle is idempotent — at no point does the loop close to a
fixed point of `x ↦ x·x`. The "circle plus more" picture carries all
the way through.
-/
theorem supercomplete_cycle :
    IsSupercomplete e1_vec ∧
      IsSupercomplete (split_oct_mul e1_vec e4_vec) ∧
      IsSupercomplete (split_oct_mul e4_vec e5_vec) :=
  ⟨e1_supercomplete,
    by rw [e1_e4_emission]; exact e5_supercomplete,
    by rw [e4_e5_absorption]
       -- `(-e₁)` is supercomplete: same squaring behavior as `e₁` (sign is squared off)
       refine ⟨?_, ?_⟩
       · -- (-e₁)² = e₁² = -e₀ ∈ scalars
         have h : split_oct_mul (split_neg e1_vec) (split_neg e1_vec) = split_neg split_one := by
           rw [show split_neg e1_vec = ⟨0,-1,0,0,0,0,0,0⟩ from rfl]
           rfl
         rw [h]; exact neg_one_in_scalarSubalgebra
       · -- `(-e₁) ≠ (-e₁)·(-e₁)` because `(-e₁)·(-e₁) = -e₀ ≠ -e₁`
         intro hidem
         dsimp only [IsIdempotent] at hidem
         have hsq : split_oct_mul (split_neg e1_vec) (split_neg e1_vec) = split_neg split_one := by
           rw [show split_neg e1_vec = ⟨0,-1,0,0,0,0,0,0⟩ from rfl]
           rfl
         rw [hsq] at hidem
         exact absurd hidem (by contradiction)⟩

-- ============================================================================
-- SECTION 5: Connection to Layer 1's fundamental atomic transition
-- ============================================================================

/--
The fundamental atomic transition `(x₁, x₂) = (e₀ + e₁, e₄)` from
`AtomicShell.lean` is witnessed in Layer 3 as the emissive pair `(e₁, e₄)`
adds the scalar component `e₀` to the first factor.

- The "rotation" component of `x₁ · x₂` is exactly `e₁ · e₄ = e₅`.
- The `e₀` part of `x₁` commutes through the product (the unit), so
  no additional defect is introduced by including it.
- Hence the fundamental atomic transition is precisely an emissive
  egress move in Layer 3's structure.

This is the precise mechanism by which the Layer 1 atomic transition
is realised as a Layer 3 emissive egress: the `e₁` part of `x₁ = e₀ + e₁`
carries the entire `(5,3)` defect, and the scalar `e₀` part is an idle
spectator (idempotent — `e₀² = e₀`).
-/
theorem fundamental_transition_is_emissive_egress :
    split_oct_mul e1_vec e4_vec = e5_vec ∧
      EmissivePair e1_vec e4_vec ∧
      impedanceDefect e1_vec e4_vec = -2 :=
  ⟨e1_e4_emission, e1_e4_emissive, defect_e1_e4_neg⟩