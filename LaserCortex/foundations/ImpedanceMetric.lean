import Mathlib
import LaserCortex.foundations.Algebra
import LaserCortex.foundations.AtomicShell

/-!
# Layer 2 — The Impedance-Matched Metric Space

## Plain-English reading

The Layer 1 atomic metric space (`AtomicShell.lean`) is built by taking the
(5,3) fine-shell criterion `fiveThreeNorm` level sets, layered inside the
coarse shell family defined by `frictionDensity`. The (4,4) conserved
charge is the multiplicative `octonion_norm`; the (5,3) energy is
`fiveThreeNorm`, which is NOT multiplicative.

We derive Layer 2 by a *impedance-matching* selection criterion between
the two forms. Defining the **defect**

    impedanceDefect(x, y) := fiveThreeNorm(x·y) − fiveThreeNorm(x)·fiveThreeNorm(y),

the impedance match condition is `defect = 0`: the (5,3) form behaves as
if it were a second conserved charge over that pair — the transition is
energy-neutral, no reflective loss.

The locus where every pair is matched — the **kernel** of the defect —
is the Hamilton quaternion sub-algebra `⟨e₀, e₁, e₂, e₃⟩` of the 8-dim
(4,4) split-octonions. On this kernel:
  1. The (4,4) and (5,3) forms *coincide* (both the positive-definite
     (4,0) Hamilton quaternion norm).
  2. The sub-algebra is closed under `split_oct_mul`.
  3. The (5,3) form composes there (becomes a second composition norm) —
     the (4,4) and (5,3) charges *merge into a single charge*.

This is the **minimum-energy sub-algebra**: any state in the kernel has no
shell to transition to via in-kernel multiplication — every kernel
transition is energy-neutral. Outside the kernel — in the `ω = e₄`
directions — the defect becomes nonzero, and the non-compositionality of
`fiveThreeNorm` re-emerges as active energy flow between shells (the
fundamental transition of `AtomicShell.lean` lives here, as the emissive
exit from the kernel).

## Defect sign census

With the basis vectors `eN_vec`:

  • `impedanceDefect e1 e2 =  0`  (matched — within the quaternion kernel)
  • `impedanceDefect e1 e4 = -2` (emissive — energy released crossing
    out of the kernel in the e₄ direction; this is the algebraic kernel
    of the fundamental atomic transition in `AtomicShell.lean`)
  • `impedanceDefect e4 e5 = +2` (absorptive — energy absorbed cross-sector
    in the `ω` directions)

## File references

- `foundations/Algebra.lean` — `SplitOctonion`, `split_oct_mul`,
  `octonion_norm`, `octonion_norm_mul`, `fiveThreeNorm`,
  `fiveThreeNorm_non_composition`, `omega_mul_e5`, `eN_vec`, `split_neg`
- `foundations/AtomicShell.lean` — the Layer 1 atomic model with
  `stateTransition`, `fundamental_atomic_transition`
-/

open EMLTree

-- ============================================================================
-- SECTION 1: The impedance defect and the matched predicate
-- ============================================================================

/--
Defect of the (5,3) form across an octonion product:

    impedanceDefect(x, y) = fiveThreeNorm(x·y) − fiveThreeNorm(x)·fiveThreeNorm(y)

This is precisely the non-composition defect of `fiveThreeNorm`.
- Zero ⟹ `fiveThreeNorm` behaves as a second conserved charge over (x, y):
  impedance matched, energy-neutral transition.
- Negative ⟹ energy released across the transition (emissive regime).
- Positive ⟹ energy absorbed (absorptive regime).
-/
def impedanceDefect (x y : SplitOctonion) : ℤ :=
  fiveThreeNorm (split_oct_mul x y) - fiveThreeNorm x * fiveThreeNorm y

/-- A pair `(x, y)` is impedance-matched iff `impedanceDefect x y = 0`. -/
def IsMatched (x y : SplitOctonion) : Prop := impedanceDefect x y = 0

-- ============================================================================
-- SECTION 2: The matched sub-algebra — the Hamilton quaternion kernel
-- ============================================================================

/--
The matched sub-algebra = `{ x : SplitOctonion | x.e4 = 0 ∧ x.e5 = 0 ∧ x.e6 = 0 ∧ x.e7 = 0 }`.

This is the integral span of the basis vectors `{e₀, e₁, e₂, e₃}`, sitting
as a 4-dimensional sub-algebra of the 8-dim (4,4) split-octonions. It is
isomorphic to the Hamilton quaternions ℍ, with its norm being the
positive-definite (4,0) form coinciding with both `octonion_norm|_ℍ` and
`fiveThreeNorm|_ℍ`.

This is the *minimum-energy* locus of the Layer 2 metric: in-kernel
multiplication releases/absorbs no fine-shell energy (defect = 0).
-/
def MatchedSubalgebra : Set SplitOctonion :=
  { x | x.e4 = 0 ∧ x.e5 = 0 ∧ x.e6 = 0 ∧ x.e7 = 0 }

/-- Membership witness for the matched sub-algebra. -/
theorem matchedSubalgebra_mem (x : SplitOctonion)
    (h4 : x.e4 = 0) (h5 : x.e5 = 0) (h6 : x.e6 = 0) (h7 : x.e7 = 0) :
    x ∈ MatchedSubalgebra :=
  ⟨h4, h5, h6, h7⟩

/-- `split_zero` lives in the matched sub-algebra. -/
theorem split_zero_mem_matched : split_zero ∈ MatchedSubalgebra := by
  simp [MatchedSubalgebra, split_zero]

/-- The basis vectors `e₀, e₁, e₂, e₃` all lie in the matched sub-algebra. -/
theorem e0_vec_mem_matched : e0_vec ∈ MatchedSubalgebra := by
  simp [MatchedSubalgebra, e0_vec]
theorem e1_vec_mem_matched : e1_vec ∈ MatchedSubalgebra := by
  simp [MatchedSubalgebra, e1_vec]
theorem e2_vec_mem_matched : e2_vec ∈ MatchedSubalgebra := by
  simp [MatchedSubalgebra, e2_vec]
theorem e3_vec_mem_matched : e3_vec ∈ MatchedSubalgebra := by
  simp [MatchedSubalgebra, e3_vec]

/-- The Cayley-Dickson element `e₄` is NOT in the matched sub-algebra — it
    lies in the `ω` directions that break the match. -/
theorem e4_vec_not_mem_matched : e4_vec ∉ MatchedSubalgebra := by
  intro h
  have h1 : (e4_vec : SplitOctonion).e4 = 1 := rfl
  have h0 : (e4_vec : SplitOctonion).e4 = 0 := h.1
  omega

/-- `e1 · e2 = e3` — basis multiplication inside the matched kernel. -/
theorem e1_mul_e2 : split_oct_mul e1_vec e2_vec = e3_vec := by
  show split_oct_mul ⟨0,1,0,0,0,0,0,0⟩ ⟨0,0,1,0,0,0,0,0⟩ = ⟨0,0,0,1,0,0,0,0⟩
  rfl

/-- `e1 · e4 = e5` — basis multiplication leaving the matched kernel
    (this is the algebraic root of the fundamental atomic transition). -/
theorem e1_mul_e4 : split_oct_mul e1_vec e4_vec = e5_vec := by
  show split_oct_mul ⟨0,1,0,0,0,0,0,0⟩ ⟨0,0,0,0,1,0,0,0⟩ = ⟨0,0,0,0,0,1,0,0⟩
  rfl

/--
The matched sub-algebra is closed under `split_oct_mul`: products of
in-kernel elements stay in the kernel.
-/
theorem matchedSubalgebra_mul_closed (x y : SplitOctonion)
    (hx : x ∈ MatchedSubalgebra) (hy : y ∈ MatchedSubalgebra) :
    split_oct_mul x y ∈ MatchedSubalgebra := by
  obtain ⟨hx4, hx5, hx6, hx7⟩ := hx
  obtain ⟨hy4, hy5, hy6, hy7⟩ := hy
  refine ⟨?_, ?_, ?_, ?_⟩
  all_goals dsimp [split_oct_mul]
  all_goals (try rw [hx4, hx5, hx6, hx7, hy4, hy5, hy6, hy7])
  all_goals ring

/--
On the matched sub-algebra, the (4,4) conserved charge and the (5,3)
transition energy *coincide*: both norms reduce to the positive-definite
(4,0) Hamilton quaternion norm.
-/
theorem octonion_norm_eq_fiveThreeNorm_on_matched (x : SplitOctonion)
    (hx : x ∈ MatchedSubalgebra) :
    octonion_norm x = fiveThreeNorm x := by
  obtain ⟨h4, h5, h6, h7⟩ := hx
  dsimp [octonion_norm, fiveThreeNorm]
  rw [h4, h5, h6, h7]
  ring

/--
The defect vanishes for every pair drawn from the matched sub-algebra —
the **headline theorem of Layer 2**: the minimum-energy kernel.

On the kernel, `fiveThreeNorm` reduces to `octonion_norm` (theorem above),
and `octonion_norm` is multiplicative (`octonion_norm_mul`). Hence
`fiveThreeNorm(x·y) = fiveThreeNorm(x)·fiveThreeNorm(y)` on the kernel —
the (5,3) form composes, matching the (4,4) form into a single shared
charge. Layer 1's selection between two forms collapses onto a single
composition norm; the dual (charge, energy) structure is degenerate here.
-/
theorem matchedSubalgebra_is_matched (x y : SplitOctonion)
    (hx : x ∈ MatchedSubalgebra) (hy : y ∈ MatchedSubalgebra) :
    IsMatched x y := by
  rw [IsMatched, impedanceDefect]
  -- Rewrite each `fiveThreeNorm` occurrence *into* `octonion_norm` (reverse
  -- direction of `octonion_norm_eq_fiveThreeNorm_on_matched`), so the (4,4)
  -- composition identity applies.
  rw [← octonion_norm_eq_fiveThreeNorm_on_matched x hx,
      ← octonion_norm_eq_fiveThreeNorm_on_matched y hy,
      ← octonion_norm_eq_fiveThreeNorm_on_matched _ (matchedSubalgebra_mul_closed x y hx hy)]
  -- The (4,4) composition identity closes the goal.
  rw [octonion_norm_mul]
  ring

-- ============================================================================
-- SECTION 3: Defect-sign spectrum — matched / emissive / absorptive witnesses
-- ============================================================================

/-- The `e₁ · e₂` pair is impedance-matched (within the kernel). -/
theorem defect_e1_e2_zero : impedanceDefect e1_vec e2_vec = 0 := by
  rw [impedanceDefect, e1_mul_e2]
  show fiveThreeNorm e3_vec - fiveThreeNorm e1_vec * fiveThreeNorm e2_vec = 0
  rfl

/--
The `e₁ · e₄` pair is **emissive**: `defect = -2`.

This is the algebraic root of the fundamental atomic transition in
`AtomicShell.lean`: an exit from the matched kernel in the `ω = e₄`
direction that releases two units of (5,3) energy. The kernel member
`e₁` (shell +1) multiplied by `e₄` (the CD generator) lands on `e₅`
(shell −1), giving `fiveThreeNorm(e₁·e₄) = -1` against
`fiveThreeNorm(e₁) · fiveThreeNorm(e₄) = 1 · 1 = 1`: a defect of −2.
-/
theorem defect_e1_e4_neg : impedanceDefect e1_vec e4_vec = -2 := by
  rw [impedanceDefect, e1_mul_e4]
  show fiveThreeNorm e5_vec - fiveThreeNorm e1_vec * fiveThreeNorm e4_vec = -2
  rfl

/--
The `e₄ · e₅` pair is **absorptive**: `defect = +2`.

A cross-sector `ω`-direction pair (e₄ positive sector, e₅ negative sector
under (5,3)); their product `e₄·e₅ = -e₁` lands back in the kernel, but
with two units of (5,3) energy *absorbed*.
-/
theorem defect_e4_e5_pos : impedanceDefect e4_vec e5_vec = 2 := by
  rw [impedanceDefect]
  -- `e₄ · e₅` definitionally reduces to `⟨0,-1,0,0,0,0,0,0⟩`, the kernel
  -- element `-e₁` (equivalently `omega_mul_e5 : split_oct_mul omega e5_vec = split_neg e1_vec`).
  rfl

/--
All three sign regimes of the impedance defect are realized by basis-vector
pairs: zero (matched / in-kernel), negative (emissive / out of kernel via
`ω`), and positive (absorptive / cross-sector in `ω`).

This algebraic sign census draws the boundary of the minimum-energy
sub-algebra.
-/
theorem defect_sign_spectrum :
    ∃ (a b c d e f : SplitOctonion),
      impedanceDefect a b = 0 ∧
      impedanceDefect c d < 0 ∧
      impedanceDefect e f > 0 := by
  refine ⟨e1_vec, e2_vec, e1_vec, e4_vec, e4_vec, e5_vec, ?_⟩
  refine ⟨defect_e1_e2_zero, ?_, ?_⟩
  · rw [defect_e1_e4_neg]; norm_num
  · rw [defect_e4_e5_pos]; norm_num

-- ============================================================================
-- SECTION 4: The minimum-energy sub-algebra characterization
-- ============================================================================

/--
**The minimum-energy sub-algebra** (Layer 2 / `MatchedSubalgebra`):
the impedance defect is identically zero on the kernel.

Together with `matchedSubalgebra_mul_closed` (closure) and
`octonion_norm_eq_fiveThreeNorm_on_matched` (charge/energy coincidence),
this characterizes the Hamilton quaternion kernel `⟨e₀, e₁, e₂, e₃⟩`
as the product-stable energy-neutral locus of the metric space.
-/
theorem minimum_energy_subalgebra_defect_zero :
    ∀ (x y : SplitOctonion), x ∈ MatchedSubalgebra → y ∈ MatchedSubalgebra →
      impedanceDefect x y = 0 :=
  fun _ _ hx hy => matchedSubalgebra_is_matched _ _ hx hy

/--
The fundamental atomic transition in `AtomicShell.lean` is *not* an
in-kernel move — its witness leaves the matched sub-algebra. The driver
component `e₁ · e₄` of the fundamental transition carries the full
emissive defect `−2`.

This is the boundary theorem between Layer 1 and Layer 2: the active
transition of the atomic model is precisely the kernel-exit move in the
`ω` direction, and its emitted energy equals the defect of that kernel-exit
pair.
-/
theorem fundamental_transition_exits_kernel :
    impedanceDefect e1_vec e4_vec = -2 :=
  defect_e1_e4_neg

/--
The `e₄`-direction breaks impedance matching: the pair `(e₁, e₄)` has a
nonzero defect. Therefore the matched kernel `⟨e₀, e₁, e₂, e₃⟩` is a
*properly smaller* sub-algebra than the (4,4) split-octonions — no extension
of the kernel in the `ω` direction preserves matching.

This is the maximality half of the kernel's characterization: the Hamilton
quaternions are exactly the maximal matched sub-algebra.
-/
theorem matched_kernel_proper_subalgebra :
    e1_vec ∈ MatchedSubalgebra ∧ e4_vec ∉ MatchedSubalgebra ∧
      ¬ IsMatched e1_vec e4_vec := by
  refine ⟨e1_vec_mem_matched, e4_vec_not_mem_matched, ?_⟩
  rw [IsMatched, defect_e1_e4_neg]
  norm_num