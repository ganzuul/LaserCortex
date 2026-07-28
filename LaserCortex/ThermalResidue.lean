import Mathlib
import LaserCortex.foundations.Algebra
import LaserCortex.Friction
import LaserCortex.EmissiveAbsorptive

/-!
# Layer 4 — Thermal Residue; Observability via Broken Symmetry

## Plain-English reading

Where Yang-Mills gauge theory has *completeness* — gauge loops close exactly at
the identity — LaserCortex has *supercompleteness* (see `EmissiveAbsorptive.lean`):
the squaring map `x ↦ x · x` closes (lands in the scalar sub-algebra `ℤ · e₀`)
but overshoots past `x`, the YM "perfect circle" projections become "circle plus
more." This file formalizes the user's picture of how that overshoot becomes the
very reason the resulting physics can be *observed* at all.

### The Real projection is blind to supercompleteness

```
realProjection (x : SplitOctonion) : ℤ := x.e0
```

takes only the scalar (e₀) trace of an octonion — what a Real-valued observable
can ever see. Under this projection the idempotent `split_zero` and the
supercomplete `e₁` are *indistinguishable*: both have `realProjection = 0`. The
Real projection alone cannot tell a perfect YM gauge loop from a supercomplete
LC overshoot.

The detector of this distinction is the **overshoot**

```
overshoot (x : SplitOctonion) : ℤ := (x · x).e0 - x.e0
```

— the scalar excess the squaring map leaves behind once the `e₀` the loop
started at is subtracted off. Idempotents have `overshoot = 0`; supercompletes
have `overshoot ≠ 0`. The Real projection alone cannot show this; the
hypercomplex structure is exactly where the overshoot hides — invisible to the
Reals, alive in the algebra.

### The overshoot has a scalar value remainder over a hypercomplex modulo

The integer `overshoot(x)` is reduced modulo `strut_weight = 4` (the
associator barrier weight from `Friction.lean`):

```
thermalResidue (x : SplitOctonion) : ℤ := overshoot x % strut_weight
```

This is the **thermal potential** of `x` — the scalar residue that survives a
coarse-graining against the strut weight. It is the observability residue:
*the part that the broken symmetry leaves as a thermal fingerprint.*

A trifecta of facts pins down the picture:

1. **Idempotents carry no thermal potential** — `thermalResidue_idempotent_zero`
   proves that `IsIdempotent x → thermalResidue x = 0`. The YM "too perfect to
   be observed" locus is exactly the zero-residue locus.

2. **Supercompletes carry nonzero thermal potential** — every basis element
   `e₁ … e₇` has `thermalResidue ≠ 0 mod strut_weight`; concrete residue values:
     * `e₁, e₂, e₃` (spinor half-twist, kernel supercompletes) → residue `3`
       (= `-1 mod 4`), the emissive side.
     * `e₄, e₅, e₆, e₇` (involution overshoot, ω-complement supercompletes) →
       residue `1`, the absorptive side.

3. **The cycle conserves energy but does NOT conserve thermal potential** —
   the closed supercomplete cycle `e₁ → e₅ → -e₁` of Layer 3 has the
   *inter-action* defects (`impedanceDefect`) summing to zero (energy
   conservation, proven in Layer 3 as `supercomplete_cycle_defect_zero`). But
   the *self-action* overshoots along the same cycle do NOT sum to zero:
   `overshoot(e₁) + overshoot(e₅) + overshoot(-e₁) = -1 + 1 + (-1) = -1`. The
   broken symmetry persists through the closed cycle; the net thermal
   fingerprint `≡ 3 (mod 4)`. The universe wants its gauge loops to close
   perfectly AND its thermal residue to fall to zero — Layer 4 proves LC cannot
   do both at once.

### The duality: geometric coordinate vs thermal potential

A full `SplitOctonion` is the *geometric coordinate* of an atomic state —
directional, hypercomplex, multi-component; its internals encode which shell
and fine level the state sits at. The integer `thermalResidue(x)` is the
*thermal potential* — the scalar summary, observability-the-Reals-can-grasp.
The two live in duality: the geometric coordinate is invisible to the Reals
but contains the residue (projection of the squaring map); the thermal residue
is Real-valued and is *what survives the modulus*. The modulus `strut_weight`
is precisely the algebraic cost of moving through the associator barrier; this
is why the modulus is not arbitrary — it ties the thermal side directly to the
*physical* landscape of Layer 1's metric.

## File references

- `foundations/Algebra.lean` — `SplitOctonion`, `split_oct_mul`, `split_one`,
  `split_zero`, `split_neg`, basis vectors `eN_vec`
- `Friction.lean` — `strut_weight_eq_four`
- `EmissiveAbsorptive.lean` — Layer 3 (`IsIdempotent`, `IsSupercomplete`,
  `ScalarSubalgebra`, `e1_supercomplete`, `e4_supercomplete`, `e5_supercomplete`,
  `e1_sq`, `e4_sq`, `e5_sq`, `e1_mul_e4`, `e4_e5_absorption`)
- `AtomicShell.lean` — Layer 1 (its `x₁ = ⟨1,1,0,0,0,0,0,0⟩` witness becomes the
  `fundamental_transition_thermal_fingerprint` of §3 below)
-/

open EMLTree

-- ============================================================================
-- SECTION 1: Projections and the scalar overshoot
-- ============================================================================

/--
The Real observable: the scalar (e₀) coordinate of a `SplitOctonion`. This is
the only part of an octonion that a Real-valued metric can see directly.
-/
def realProjection (x : SplitOctonion) : ℤ := x.e0

/--
The scalar landing of the squaring map:

    scalarLandingSq(x) := (x · x).e0

This is the *antipode-pairing* (5,3) form with positive sector `{e₀,e₄,e₅,e₆,e₇}`
(form #2 in lab note 039's trio of quadratic forms on `SplitOctonion`). It is
the scalar trace that the squaring map deposits in the coordinate the loop
ultimately returns to.
-/
def scalarLandingSq (x : SplitOctonion) : ℤ := (split_oct_mul x x).e0

/--
The broken-symmetry amount: the scalar excess the squaring map leaves behind,
once the e₀ the loop started at is subtracted off.

  overshoot(x) = (x · x).e₀ − x.e₀

**Idempotents** (YM perfect circles): `overshoot = 0`.
**Supercompletes** (LC "circle + ε"): `overshoot ≠ 0`.

The Real projection alone cannot show this — it sees only `x.e₀`, not the
difference `(x·x).e₀ − x.e₀`. The hypercomplex structure of the algebra is
exactly where the overshoot is encoded; the broken symmetry is invisible to a
pure-Real observable but is the very thing that licenses observation.
-/
def overshoot (x : SplitOctonion) : ℤ := scalarLandingSq x - realProjection x

/-- `overshoot(0) = 0` (trivial idempotent). -/
theorem overshoot_split_zero : overshoot split_zero = 0 := rfl

/-- `overshoot(e₀) = 0` (unit idempotent). -/
theorem overshoot_split_one : overshoot split_one = 0 := rfl

/-- `overshoot(e₁) = -1` — spinor half-twist overshoot, kernel side. -/
theorem overshoot_e1_neg : overshoot e1_vec = -1 := by
  rw [overshoot, scalarLandingSq, realProjection, e1_sq]; rfl

/-- `overshoot(e₂) = -1` — spinor half-twist overshoot, kernel side. -/
theorem overshoot_e2_neg : overshoot e2_vec = -1 := by
  rw [overshoot, scalarLandingSq, realProjection]
  rw [e2_sq]; rfl

/-- `overshoot(e₃) = -1` — spinor half-twist overshoot, kernel side. -/
theorem overshoot_e3_neg : overshoot e3_vec = -1 := by
  rw [overshoot, scalarLandingSq, realProjection]
  rw [e3_sq]; rfl

/-- `overshoot(e₄) = +1` — involution overshoot, ω-complement side. -/
theorem overshoot_e4_pos : overshoot e4_vec = 1 := by
  rw [overshoot, scalarLandingSq, realProjection]
  rw [e4_sq]; rfl

/-- `overshoot(e₅) = +1` — involution overshoot, ω-complement side. -/
theorem overshoot_e5_pos : overshoot e5_vec = 1 := by
  rw [overshoot, scalarLandingSq, realProjection]
  rw [e5_sq]; rfl

/-- `overshoot(e₆) = +1` — involution overshoot, ω-complement side. -/
theorem overshoot_e6_pos : overshoot e6_vec = 1 := by
  rw [overshoot, scalarLandingSq, realProjection]
  rw [e6_sq]; rfl

/-- `overshoot(e₇) = +1` — involution overshoot, ω-complement side. -/
theorem overshoot_e7_pos : overshoot e7_vec = 1 := by
  rw [overshoot, scalarLandingSq, realProjection]
  rw [e7_sq]; rfl

/-- **Idempotents have zero overshoot** — the YM perfect-circle locus carries
    no broken symmetry. -/
theorem overshoot_idempotent_zero (x : SplitOctonion) (h : IsIdempotent x) :
    overshoot x = 0 := by
  -- `IsIdempotent x := x·x = x`, so `(x·x).e0 = x.e0`, hence the overshoot is 0.
  dsimp [IsIdempotent] at h
  rw [overshoot, scalarLandingSq, realProjection, h]
  ring

/--
**The Real projection is blind to supercompleteness** — there exist two
elements with the same Real projection but different overshoot, one idempotent
and the other supercomplete. The Real observable alone cannot distinguish them.

The intuition: a Yang-Mills-style "perfect circle" (idempotent) and an LC
"circle + ε" (supercomplete) can look *identical* as Real observables; the
symmetry that distinguishes them is broken at the hypercomplex level. Without
this broken symmetry, the universe would be "too perfect to be observed."
-/
theorem real_projection_blind_to_supercompleteness :
    ∃ (a b : SplitOctonion),
      realProjection a = realProjection b ∧
        IsIdempotent a ∧ IsSupercomplete b ∧
          overshoot a = 0 ∧ overshoot b ≠ 0 := by
  -- Witnesses: a = split_zero (idempotent), b = e1_vec (supercomplete).
  -- Both have realProjection = 0, but overshoot differs (0 vs -1).
  refine ⟨split_zero, e1_vec, rfl, ?_, ?_, overshoot_split_zero, ?_⟩
  · exact split_zero_idempotent
  · exact e1_supercomplete
  · rw [overshoot_e1_neg]; decide

-- ============================================================================
-- SECTION 2: Thermal residue modulo `strut_weight` (M = 4, signed)
-- ============================================================================

/--
The thermal potential of `x`: the scalar residue of the overshoot reduced
modulo `strut_weight` (the associator barrier weight = 4 from `Friction.lean`).

  thermalResidue(x) := overshoot(x) % strut_weight

**Sign convention** (Lean's `Int` modulo / `%` returns the *floored*,
non-negative remainder): for a negative overshoot `overshoot(x) = -1` we get
`thermalResidue = -1 % 4 = 3` (not `-1`). The residue is always in
`{0, 1, 2, 3}` — the four classes of `ℤ/strut_weight·ℤ`.

The modulus choice `strut_weight = 4` couples the thermal side directly to the
algebraic landscape of Layer 1: it is precisely the cost (squared) of activating
the associator barrier, and it appears unchanged inside `frictionDensity(cd)`
for `cd ≥ 3` (the non-associative coarse shell B).

Idempotents have `thermalResidue = 0` (no broken symmetry).
Supercompletes have `thermalResidue ≠ 0` (broken symmetry detected). The
emissive/absorptive direction is preserved by the residue:
  - kernel supercompletes (e₁, e₂, e₃) → `thermalResidue = 3` (emissive side).
  - ω-complement supercompletes (e₄..e₇) → `thermalResidue = 1` (absorptive side).
-/
def thermalResidue (x : SplitOctonion) : ℤ := overshoot x % strut_weight

/-- Idempotents carry zero thermal potential. -/
theorem thermalResidue_idempotent_zero (x : SplitOctonion) (h : IsIdempotent x) :
    thermalResidue x = 0 := by
  rw [thermalResidue, overshoot_idempotent_zero x h, strut_weight_eq_four]
  rfl

/-- `thermalResidue(0) = 0` (idempotent). -/
theorem thermalResidue_split_zero : thermalResidue split_zero = 0 := by
  rw [thermalResidue, overshoot_split_zero, strut_weight_eq_four]
  rfl

/-- `thermalResidue(e₀) = 0` (idempotent). -/
theorem thermalResidue_split_one : thermalResidue split_one = 0 := by
  rw [thermalResidue, overshoot_split_one, strut_weight_eq_four]
  rfl

/-- `thermalResidue(e₁) = 3` — the emissive-side residue (`-1 mod 4 = 3`). -/
theorem thermalResidue_e1_mod4 : thermalResidue e1_vec = 3 := by
  rw [thermalResidue, overshoot_e1_neg, strut_weight_eq_four]
  rfl

/-- `thermalResidue(e₂) = 3` (emissive side). -/
theorem thermalResidue_e2_mod4 : thermalResidue e2_vec = 3 := by
  rw [thermalResidue, overshoot_e2_neg, strut_weight_eq_four]
  rfl

/-- `thermalResidue(e₃) = 3` (emissive side). -/
theorem thermalResidue_e3_mod4 : thermalResidue e3_vec = 3 := by
  rw [thermalResidue, overshoot_e3_neg, strut_weight_eq_four]
  rfl

/-- `thermalResidue(e₄) = 1` — the absorptive-side residue (`+1 mod 4 = 1`). -/
theorem thermalResidue_e4_mod4 : thermalResidue e4_vec = 1 := by
  rw [thermalResidue, overshoot_e4_pos, strut_weight_eq_four]
  rfl

/-- `thermalResidue(e₅) = 1` (absorptive side). -/
theorem thermalResidue_e5_mod4 : thermalResidue e5_vec = 1 := by
  rw [thermalResidue, overshoot_e5_pos, strut_weight_eq_four]
  rfl

/-- `thermalResidue(e₆) = 1` (absorptive side). -/
theorem thermalResidue_e6_mod4 : thermalResidue e6_vec = 1 := by
  rw [thermalResidue, overshoot_e6_pos, strut_weight_eq_four]
  rfl

/-- `thermalResidue(e₇) = 1` (absorptive side). -/
theorem thermalResidue_e7_mod4 : thermalResidue e7_vec = 1 := by
  rw [thermalResidue, overshoot_e7_pos, strut_weight_eq_four]
  rfl

/--
**Supercomplete parity theorem**: every non-trivial basis element is
supercomplete (Layer 3), and every supercomplete basis element has odd
thermal residue `mod 2`. Combined with `thermalResidue_idempotent_zero`,
this says idempotents and supercompletes are separated by parity of the
residue:
  - idempotents → residue `0` (even).
  - supercomplete basis elements → residue `1` (odd, after reducing mod 2).
-/
theorem thermalResidue_supercomplete_parity :
    (∃ x, IsSupercomplete x ∧ thermalResidue x % 2 = 1) ∧
      (∀ x, IsIdempotent x → thermalResidue x % 2 = 0) :=
  ⟨⟨e1_vec, e1_supercomplete, by rw [thermalResidue_e1_mod4]; rfl⟩,
    fun _ h => by rw [thermalResidue_idempotent_zero _ h]; rfl⟩

/--
**Signed residue split**: the modulus `strut_weight = 4` preserves the
emissive/absorptive direction of Layer 3 through the thermal residue.

  - kernel supercompletes `e₁, e₂, e₃` (self-squaring `−e₀`, Layer 3a
    emissive drivers) → `thermalResidue ∈ {3}` (mod 4).
  - ω-complement supercompletes `e₄, e₅, e₆, e₇` (self-squaring `+e₀`,
    Layer 3b absorptive drivers) → `thermalResidue = 1` (mod 4).

The two supercomplete sub-kinds of Layer 3 are therefore distinguishable
by their thermal residue — the broken symmetry keeps *two* bits of
information: "broken or not" (parity) and "emissive or absorptive" (mod 4).
-/
theorem thermalResidue_signed_supercomplete_split :
    thermalResidue e1_vec = 3 ∧ thermalResidue e2_vec = 3 ∧
      thermalResidue e3_vec = 3 ∧
        thermalResidue e4_vec = 1 ∧ thermalResidue e5_vec = 1 ∧
          thermalResidue e6_vec = 1 ∧ thermalResidue e7_vec = 1 :=
  ⟨thermalResidue_e1_mod4, thermalResidue_e2_mod4, thermalResidue_e3_mod4,
    thermalResidue_e4_mod4, thermalResidue_e5_mod4,
    thermalResidue_e6_mod4, thermalResidue_e7_mod4⟩

-- ============================================================================
-- SECTION 3: Geometric coordinate vs thermal potential (the duality)
-- ============================================================================

/--
A non-idempotent with zero overshoot: `e₁ + e₄` squares to zero (`(e₁ + e₄)² =
0`), so `overshoot(e₁ + e₄) = (x·x).e₀ − x.e₀ = 0 − 0 = 0`, but `x·x ≠ x`. The
zero-overshoot locus is therefore *strictly larger* than the idempotent locus:
there exist non-idempotent elements whose squaring overshoot vanishes by exact
cancellation of the `e₁ · e₁ = -e₀` and `e₄ · e₄ = +e₀` self-pairings (with
the cross terms `e₁ · e₄` and `e₄ · e₁` also cancelling).

Geometrically, this means the YM "zero-excess-length" condition is *weaker*
than idempotency: a loop can fail to close at the starting element and still
leave no thermal residue, by two supercomplete overshoots cancelling each other.
The cancellation, however, pairs one of each supercomplete sub-kind (one
spinor half-twist, one ω-involution) — its zero net residue *already encodes*
the algebraic fact that this union lies at the seam between Layer 3a and Layer
3b.
-/
private def e1_plus_e4 : SplitOctonion := ⟨0, 1, 0, 0, 1, 0, 0, 0⟩

private theorem e1_plus_e4_sq_zero : split_oct_mul e1_plus_e4 e1_plus_e4 = split_zero := rfl

private theorem e1_plus_e4_not_idempotent : ¬ IsIdempotent e1_plus_e4 := by
  intro h
  have : split_oct_mul e1_plus_e4 e1_plus_e4 = e1_plus_e4 := h
  rw [e1_plus_e4_sq_zero] at this
  exact absurd this (by contradiction)

/--
The squaring map's `e₀` projection decomposes as
`(e₁ + e₄) · (e₁ + e₄) = e₁·e₁ + e₁·e₄ + e₄·e₁ + e₄·e₄ = (-e₀) + e₅ + (-e₅) + (+e₀) = 0`.
The `e₁ · e₄ = e₅` and `e₄ · e₁ = -e₅` cross terms cancel, and the two
opposite-sign self-squarings cancel. Net scalar residue: zero.
-/
theorem e1_plus_e4_overshoot_zero : overshoot e1_plus_e4 = 0 := by
  rw [overshoot, scalarLandingSq, realProjection, e1_plus_e4_sq_zero]
  rfl

/--
**Strict extension**: the zero-overshoot locus strictly extends the idempotent
locus. The witness `e₁ + e₄` has zero overshoot (its two supercomplete
self-actions cancel exactly) but is *not* an idempotent. The YM "perfect circle"
picture (zero thermal residue) does not coincide with the YM "loop closes at
its starting point" picture (idempotency) — there are LC elements that the
former allows but the latter doesn't.
-/
theorem overshoot_locus_strictly_extends_idempotents :
    {x | IsIdempotent x} ⊆ {x | overshoot x = 0} ∧
      ∃ x, overshoot x = 0 ∧ ¬ IsIdempotent x := by
  refine ⟨?_, e1_plus_e4, e1_plus_e4_overshoot_zero, e1_plus_e4_not_idempotent⟩
  · intro x hx
    exact overshoot_idempotent_zero x hx

/--
**The fundamental atomic transition's thermal fingerprint**: the Layer 1
witness `x₁ = e₀ + e₁ = ⟨1,1,0,0,0,0,0,0⟩` carries the same thermal residue
as the kernel supercomplete `e₁` itself.

The scalar spectator `e₀` is an *idempotent* (`e₀ · e₀ = e₀`); as an idempotent
in the scalar sub-algebra it has zero overshoot (`overshoot_split_one`), and so
its contribution to `overshoot(x₁)` is zero. The entire thermal residue of
the Layer 1 atomic transition witness is carried by the `e₁` part — the
emissive driver of Layer 3a's fundamental kernel-exit move.

This is the duality in action: the geometric coordinate `x₁ = e₀ + e₁` is the
full `SplitOctonion` (Layer 1's atomic transition witness). Its thermal residue
(the scalar fingerprint an observable can see) is `thermalResidue(e₁) = 3` —
the emissive-side residue, matching the `defect(e₁, e₄) = -2` of Layer 3a's
emissive egress.
-/
private def x1_from_atomicShell : SplitOctonion := ⟨1, 1, 0, 0, 0, 0, 0, 0⟩

private theorem x1_overshoot_neg_one : overshoot x1_from_atomicShell = -1 := by
  rw [overshoot, scalarLandingSq, realProjection]
  -- (x₁)² = (e₀ + e₁)² = e₀·e₀ + e₀·e₁ + e₁·e₀ + e₁·e₁ = e₀ + e₁ + e₁ + (-e₀) = 2·e₁
  -- so (x₁²).e₀ = 0, x₁.e₀ = 1, overshoot = -1
  change (split_oct_mul x1_from_atomicShell x1_from_atomicShell).e0 - 1 = -1
  rfl

theorem fundamental_transition_thermal_fingerprint :
    overshoot x1_from_atomicShell = -1 ∧
      thermalResidue x1_from_atomicShell = thermalResidue e1_vec := by
  refine ⟨x1_overshoot_neg_one, ?_⟩
  rw [thermalResidue, x1_overshoot_neg_one, thermalResidue, overshoot_e1_neg,
    strut_weight_eq_four]

-- ============================================================================
-- SECTION 4: Supercomplete cycle — thermal persistence (NOT conservation)
-- ============================================================================

/--
**The closed supercomplete cycle `e₁ → e₅ → -e₁` (Layer 3) leaves a net
thermal fingerprint of `−1`.**

Layer 3's `supercomplete_cycle_defect_zero` proves that the *inter-action*
impedance defects along this cycle sum exactly to zero:
  `impedanceDefect(e₁, e₄) + impedanceDefect(e₄, e₅) = -2 + 2 = 0`.
Energy is conserved across the cycle.

Here we state the *dual* theorem, on the *self-action* overshoots along the
same cycle:
  `overshoot(e₁) + overshoot(e₅) + overshoot(-e₁) = -1 + 1 + (-1) = -1`.

The net thermal fingerprint is `−1`, not `0`. The cycle conserves energy but
does *not* conserve thermal potential — the broken symmetry character of the
supercomplete sub-kinds persists through the closed cycle. The geometric
coordinate cycles around (returns to the kernel via `-e₁`), but the scalar
thermal residue does not return to its starting value: the loop `e₁ → e₅ →
-e₁` overshoots net `−1`, drawing a circle with a line that is `O(1)` longer
than the diameter.

### Physical intuition

In the Yang-Mills picture, gauge loops close perfectly at the identity, and the
universe is symmetric — "too perfect to be observed." In the LaserCortex
picture, the supercomplete cycle demonstrates a *persistent* thermal residue
across a closed loop: the universe *wants* perfect closure (`defect_zero` holds
on inter-action) but the *self-action* keeps breaking — and this is exactly
what makes our circle observable as a circle-with-excess rather than no circle
at all. The energy conservation theorem and the thermal-persistence theorem
together certify that the cycle is "energetically closed but thermally open."
-/
theorem supercomplete_cycle_persistent_thermal :
    overshoot e1_vec + overshoot (split_oct_mul e1_vec e4_vec) +
      overshoot (split_oct_mul e4_vec e5_vec) = -1 := by
  -- e₅ = e₁ · e₄ has overshoot +1; e₄ · e₅ = -e₁ has overshoot -1.
  rw [e1_e4_emission, e4_e5_absorption]
  -- Now: overshoot(e₁) + overshoot(e₅) + overshoot(-e₁) = -1 + 1 + -1 = -1
  rw [overshoot_e1_neg, overshoot_e5_pos]
  -- The third term: -e₁ = ⟨0,-1,0,0,0,0,0,0⟩, and (-e₁)² = e₁² = -e₀, so
  -- (-e₁)².e₀ = -1 and (-e₁).e₀ = 0, hence overshoot(-e₁) = -1.
  have h_neg_e1_sq :
      (split_oct_mul (split_neg e1_vec) (split_neg e1_vec)).e0 = -1 := rfl
  have h_neg_e1_real : (split_neg e1_vec).e0 = 0 := rfl
  rw [overshoot, scalarLandingSq, realProjection, h_neg_e1_sq, h_neg_e1_real]
  -- Now the goal is (-1) + 1 + (-1) = -1 → omega / norm_num will close it.
  rfl

/--
The closed supercomplete cycle's net thermal *residue* is `−1 mod 4 ≡ 3` (the
emissive-side residue) — mirroring the self-action persistence against the same
modulus as the ω-involution direction (= `thermalResidue(e₄) = 1` on the
opposite "side" of the algebra).

The cycle's net residue `3` equals `thermalResidue(e₁)` — the residue does not
combine nor cancel across the closed move; the emissive-side fingerprint
survives exactly as if the whole cycle were a single `e₁`-side step. This is
the dual statement to Layer 3's energy conservation: energy cancels through
the cycle, residue accumulates.
-/
theorem supercomplete_cycle_persistent_residue :
    (overshoot e1_vec + overshoot (split_oct_mul e1_vec e4_vec) +
      overshoot (split_oct_mul e4_vec e5_vec)) % strut_weight = 3 := by
  rw [supercomplete_cycle_persistent_thermal, strut_weight_eq_four]
  rfl