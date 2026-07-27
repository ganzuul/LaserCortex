import LaserCortex.foundations.Tamari
import LaserCortex.Friction

/-!
# Coherence Metric — Split-Signature Metric Space on the Tamari Lattice

This module defines the metric structure in which the context-sensitive atomic
grammar operates. The Tamari lattice carries a split-signature Minkowski metric
(1,1) where:

  * The **timelike** coordinate is `dcStep(t)` — distance (flip count) from `t`
    to the normal form `rightComb(t.size)`. Trees that converge toward the normal
    form move forward in time.
  * The **spacelike** coordinate is `frictionDensity(cd)` — the per-flip
    inertial mass, which jumps from 2 to 19 at the associator boundary (cd 2→3).

The split-signature inner product ⟨dcStep, dcStep⟩ = dcStep² − frictionDensity²
determines whether a coherence position is timelike (coagula-dominant, contracting
toward rightComb), lightlike (quench-collapse boundary, T = V), or spacelike
(solve-dominant, dissolving into new bracketings). This classification maps to
the three alchemical principles: Sulfur, Mercury, Salt.

## Context-Sensitive Grammar

A Tamari flip at a node is **permitted** at cd step `cd` iff the immediate
subtrees satisfy `contextMatch`. At cd ≤ 2 (associative regime) all contexts
match — the grammar is context-free. At cd ≥ 3 the associator barrier
(`strut_weight² = 16`) makes the grammar context-sensitive: two subtrees match
only when their dcStep values differ by at most 1 (their Tamari distance is
within one flip's friction cost).

The grammatical boundary (where context matching fails) is the "empty space"
between atomic coherence centers — the ~9.5× divide between associative and
non-associative regimes.

## Core Definitions

| Symbol | Definition |
|---|---|
| `coherenceInterval(cd, t)` | `dcStep(t)² − frictionDensity(cd)²` (split inner product) |
| `tamariDist(cd, s, t)` | `|dcStep(s) − dcStep(t)| · frictionDensity(cd)` |
| `isTimelike` / `isLightlike` / `isSpacelike` | Causal classification |
| `contextMatch(cd, α, β)` | `cd ≤ 2 ∨ tamariDist(cd, α, β) ≤ frictionDensity(cd)` |
| `flipPermitted(cd, s, t)` | `contracts_one s t ∧ contextMatch cd s t` |

## Dependencies

  - `foundations/Tamari.lean` → `EMLTree`, `dcStep`, `contracts_one`,
    `dcStep_contracts_one`, `contracts_to_rightComb`, `dcStep_rightComb`
  - `Friction.lean` → `frictionDensity`, `frictionDensity_eq_k_for_k_le_2`,
    `frictionDensity_eq_k_plus_16_for_k_ge_3`, `frictionDensity_ge_k`,
    `frictionDensity_jump_at_cd3`, `strut_weight`, `strut_weight_eq_four`

## Lab Note Reference

  - `docs/lab_notes/038_alchemical_topology.md` — alchemy↔LC mapping,
    split hypercomplex decoder
  - `docs/lab_notes/039_context_sensitive_grammar.md` — atomic model synthesis
    (this module's formal staging ground)
-/

open EMLTree

-- ============================================================================
-- SECTION 1: Coherence Interval — Split-Signature Inner Product
-- ============================================================================

/--
The **coherence interval** at cd step `cd` for tree `t`:

    coh(cd, t) = dcStep(t)² − frictionDensity(cd)²

This is the split-signature inner product on the Tamari lattice. It extends the
split-algebra norm pattern (`a² − b²` in `split_complex_norm`, `Q44` signature
in `octonion_norm`) onto the Tamari lattice itself — the two "coordinates" are
the coherence depth (`dcStep`) and the inertial cost (`frictionDensity`).

**Interpretation**:

  - `coh > 0` (timelike): `dcStep > Γ` — the tree is far from normal form,
    contracting toward rightComb (the future). Coagula-dominant (Sulfur).
  - `coh = 0` (lightlike): `dcStep = Γ` — the tree is at the quench-collapse
    boundary. Zero excess, ΔΦ = 0, superconducting.
  - `coh < 0` (spacelike): `dcStep < Γ` — the tree is inside the associator
    barrier, where the normal form lies across a causal horizon.
    Solve-dominant (Salt).

The sign of `coh` determines which side of the associator light cone the tree
occupies. At cd=2 the light cone is at dcStep=2 (the associativity boundary);
at cd=3 it is at dcStep=19 (the associator barrier pushing it 9.5× farther).
-/
def coherenceInterval (cd : ℕ) (t : EMLTree) : ℤ :=
  (dcStep t : ℤ) ^ 2 - ((frictionDensity cd : ℕ) : ℤ) ^ 2

-- ============================================================================
-- SECTION 2: Causal Classification
-- ============================================================================

/-- A tree is **timelike** when `coh(cd, t) > 0` — its coherence motion is
    toward the normal form (contraction). -/
def isTimelike (cd : ℕ) (t : EMLTree) : Prop := coherenceInterval cd t > 0

/-- A tree is **lightlike** when `coh(cd, t) = 0` — it sits on the associator
    light cone, the quench-collapse boundary where contraction and dissolution
    balance exactly. -/
def isLightlike (cd : ℕ) (t : EMLTree) : Prop := coherenceInterval cd t = 0

/-- A tree is **spacelike** when `coh(cd, t) < 0` — it is inside the associator
    barrier, where the normal form lies across a causal horizon. -/
def isSpacelike (cd : ℕ) (t : EMLTree) : Prop := coherenceInterval cd t < 0

/-- The causal classification at a given (cd, t) is exclusive — a tree cannot
    be both timelike and spacelike simultaneously. -/
theorem causal_exclusive (cd : ℕ) (t : EMLTree) : ¬ (isTimelike cd t ∧ isSpacelike cd t) := by
  simp [isTimelike, isSpacelike, coherenceInterval]
  omega

/-- Trichotomy: every (cd, t) pair is either timelike, lightlike, or spacelike.
    The two boundaries together partition the split-signature space. -/
theorem causal_trichotomy (cd : ℕ) (t : EMLTree) :
    isTimelike cd t ∨ isLightlike cd t ∨ isSpacelike cd t := by
  unfold isTimelike isLightlike isSpacelike coherenceInterval
  set X := (dcStep t : ℤ) ^ 2 - ((frictionDensity cd : ℕ) : ℤ) ^ 2
  by_cases hpos : X > 0
  · left; exact hpos
  by_cases hzero : X = 0
  · right; left; exact hzero
  · right; right; omega

-- ============================================================================
-- SECTION 3: Tamari Distance (ℤ-valued pseudo-metric)
-- ============================================================================

/--
The **Tamari distance** between trees `s` and `t` at cd step `cd`:

    d(cd, s, t) = |dcStep(s) − dcStep(t)| · frictionDensity(cd)

Projects the Tamari poset onto a 1D coherence dimension via the `dcStep`
grading function. Returned as `ℤ` for algebraic convenience (triangle inequality
follows from `abs_sub`). Non-negativity holds because each factor is non-negative.

This is a pseudo-metric: it returns 0 even for distinct trees with the same
dcStep value. This loss of discrimination is intentional — the atomic model
only needs coherence depth, not the full combinatorial lattice distance.
-/
def tamariDist (cd : ℕ) (s t : EMLTree) : ℤ :=
  |(dcStep s : ℤ) - (dcStep t : ℤ)| * (frictionDensity cd : ℤ)

-- ---------------------------------------------------------------------------
-- Pseudo-metric properties
-- ---------------------------------------------------------------------------

theorem tamariDist_nonneg (cd : ℕ) (s t : EMLTree) : tamariDist cd s t ≥ 0 := by
  unfold tamariDist
  apply mul_nonneg (abs_nonneg _)
  exact Nat.cast_nonneg _

theorem tamariDist_self (cd : ℕ) (t : EMLTree) : tamariDist cd t t = 0 := by
  unfold tamariDist
  simp

theorem tamariDist_symm (cd : ℕ) (s t : EMLTree) : tamariDist cd s t = tamariDist cd t s := by
  unfold tamariDist
  rw [abs_sub_comm]

/--
The triangle inequality for Tamari distance follows from the triangle
inequality for ℤ absolute value via `abs_add`: `|a − c| ≤ |a − b| + |b − c|`.
-/
theorem tamariDist_triangle (cd : ℕ) (s t u : EMLTree) :
    tamariDist cd s u ≤ tamariDist cd s t + tamariDist cd t u := by
  unfold tamariDist
  have tri : |(dcStep s : ℤ) - (dcStep u : ℤ)| ≤
             |(dcStep s : ℤ) - (dcStep t : ℤ)| + |(dcStep t : ℤ) - (dcStep u : ℤ)| := by
    calc
      |(dcStep s : ℤ) - (dcStep u : ℤ)|
          = |((dcStep s : ℤ) - (dcStep t : ℤ)) + ((dcStep t : ℤ) - (dcStep u : ℤ))| := by ring_nf
      _ = |((dcStep s : ℤ) - (dcStep t : ℤ)) + ((dcStep t : ℤ) - (dcStep u : ℤ)) + (0 : ℤ)| := by simp
      _ ≤ |(dcStep s : ℤ) - (dcStep t : ℤ)| + |(dcStep t : ℤ) - (dcStep u : ℤ)|
              + |(0 : ℤ)| := abs_add_three _ _ _
      _ = |(dcStep s : ℤ) - (dcStep t : ℤ)| + |(dcStep t : ℤ) - (dcStep u : ℤ)| := by simp
  have hΓ : (frictionDensity cd : ℤ) ≥ 0 := Nat.cast_nonneg _
  nlinarith

-- ============================================================================
-- SECTION 4: Context-Sensitive Grammar
-- ============================================================================

/--
Two trees `α` and `β` **context-match** at cd step `cd` iff either:

  1. `cd ≤ 2` — the associative regime, where all contexts are compatible
     (no associator barrier), OR
  2. `tamariDist(cd, α, β) ≤ frictionDensity(cd)` — their Tamari distance
     in coherence space is within the associator barrier (at most one flip's
     worth of friction).

Entry condition (2) simplifies algebraically: since `tamariDist = |Δ| · Γ`,
the inequality `|Δ| · Γ ≤ Γ` (with Γ > 0) reduces to `|Δ| ≤ 1`. In other words,
contexts match only when they are at the same or adjacent coherence depths.

When `contextMatch` fails at a node, that node is a grammatical boundary — the
"empty space" between atomic coherence centers.
-/
def contextMatch (cd : ℕ) (α β : EMLTree) : Prop :=
  cd ≤ 2 ∨ tamariDist cd α β ≤ (frictionDensity cd : ℤ)

-- ---------------------------------------------------------------------------
-- Associative-regime theorem: all contexts match
-- ---------------------------------------------------------------------------

/-- In the associative regime (cd ≤ 2), every pair of trees context-matches.
    The grammar is context-free: any Tamari flip is permitted regardless of
    the coherence depth of the surrounding subtrees. -/
theorem contextMatch_all_assoc (cd : ℕ) (h : cd ≤ 2) (α β : EMLTree) : contextMatch cd α β :=
  Or.inl h

-- ---------------------------------------------------------------------------
-- Non-associative boundary theorem: some contexts do NOT match
-- ---------------------------------------------------------------------------

/-- At cd ≥ 3, there exist trees whose contexts do not match. The associator
    barrier creates genuine grammatical boundaries — the "empty space" between
    atoms.

    Witness: `Leaf` (dcStep = 0) and a left-comb of depth 3 (dcStep = 2).
    Their dcStep values differ by 2, so `tamariDist(3, Leaf, β) = 2 · 19 = 38`
    which exceeds `Γ₃ = 19`. -/
theorem grammatical_boundary : ∃ (α β : EMLTree), ¬ contextMatch 3 α β := by
  -- leftComb of size 3: Node (Node (Node Leaf Leaf) Leaf) Leaf → dcStep = 2
  let β : EMLTree := .Node (.Node (.Node .Leaf .Leaf) .Leaf) .Leaf
  have h_dcStep_leaf : dcStep .Leaf = 0 := by simp [dcStep]
  have h_dcStep_beta : dcStep β = 2 := by
    unfold β
    simp [dcStep]
  have h_not_le_2 : ¬ (3 : ℕ) ≤ 2 := by omega
  have hΓ3 : frictionDensity 3 = 19 := by
    rw [frictionDensity_eq_k_plus_16_for_k_ge_3 3 (by omega), strut_weight_eq_four]
  have h_tamari : tamariDist 3 .Leaf β = (38 : ℤ) := by
    unfold tamariDist
    simp [h_dcStep_leaf, h_dcStep_beta, hΓ3]
  refine ⟨.Leaf, β, ?_⟩
  unfold contextMatch
  rw [h_tamari, hΓ3]
  simp [h_not_le_2]

-- ============================================================================
-- SECTION 5: Flip Permitted (Context-Sensitive Tamari Rotation)
-- ============================================================================

/--
A Tamari rotation `contracts_one s t` is **grammatically permitted** at cd step
`cd` when the two trees (before and after the flip) context-match.

For a single Tamari flip, `dcStep s = dcStep t ± 1`, so
`tamariDist(cd, s, t) = |±1| · Γ = Γ = frictionDensity(cd)` and the condition
`tamariDist ≤ Γ` is always satisfied. Thus a single flip is always permitted
at any cd: the grammar becomes truly context-sensitive only when composing
multiple flips.

Future work: `flipPermittedPath` for multi-step composition across the
associator barrier.
-/
def flipPermitted (cd : ℕ) (s t : EMLTree) : Prop :=
  contracts_one s t ∧ contextMatch cd s t

-- ============================================================================
-- SECTION 6: Light Cone Theorems
-- ============================================================================

/-- The light cone at cd=2 is at dcStep=2 — the associativity boundary. Trees
    with dcStep=2 are lightlike; they sit exactly on the critical surface between
    the associative and non-associative regimes. -/
theorem lightcone_cd2 (t : EMLTree) (h : dcStep t = 2) :
    isLightlike 2 t := by
  unfold isLightlike coherenceInterval
  simp [h, frictionDensity_eq_k_for_k_le_2 2 (by omega)]

/-- The light cone at cd=3 is at dcStep=19 — the associator barrier. The
    barrier pushes the critical surface 9.5× farther than at cd=2:
    `19 / 2 = 9.5`. -/
theorem lightcone_cd3 (t : EMLTree) (h : dcStep t = 3 + strut_weight * strut_weight) :
    isLightlike 3 t := by
  unfold isLightlike coherenceInterval
  have hΓ3 : frictionDensity 3 = 3 + strut_weight * strut_weight :=
    frictionDensity_eq_k_plus_16_for_k_ge_3 3 (by omega)
  simp [h, hΓ3, strut_weight_eq_four]

/-- The ratio of light-cone dcStep positions at cd=3 vs cd=2 is exactly
    `Γ₃ / Γ₂ = 19 / 2 = 9.5`. The associator barrier expands the causal
    boundary by a factor of `(3 + strut_weight²) / 2`.

    This is the "empty space" between atomic coherence centers — the
    grammatical boundary created by the associator barrier. -/
theorem lightcone_ratio :
    2 * (frictionDensity 3 : ℤ) = 19 * (frictionDensity 2 : ℤ) := by
  have h2 : frictionDensity 2 = 2 := frictionDensity_eq_k_for_k_le_2 2 (by omega)
  have h3 : frictionDensity 3 = 3 + strut_weight * strut_weight :=
    frictionDensity_eq_k_plus_16_for_k_ge_3 3 (by omega)
  rw [strut_weight_eq_four] at h3
  rw [h2, h3]
  omega

/-- The light cone dcStep value `Γ_cd` grows superlinearly with cd in the
    non-associative regime, tracking the formula `Γ_cd = cd + strut_weight²`.

    This means the associator barrier creates a growing causal horizon — the
    minimum dcStep required to be timelike increases with each CD layer,
    broadening the grammatical "empty space" between atoms. -/
theorem lightcone_position (cd : ℕ) (h : 3 ≤ cd) :
    frictionDensity cd = cd + strut_weight * strut_weight :=
  frictionDensity_eq_k_plus_16_for_k_ge_3 cd h

-- ============================================================================
-- SECTION 7: Split-Complex Embedding — The Tamari Lattice in Lorentzian ℝ²
-- ============================================================================

/--
The **coherence point** of a tree `t` at CD step `cd` embedded in the
split-complex plane:

    (dcStep t, frictionDensity cd)  ∈  SplitComplex

The first component is the **timelike coordinate** (dcStep — distance to
normal form). The second is the **spacelike coordinate** (frictionDensity —
inertial mass per flip). Together they form a point in the (1,1)-signature
metric space whose norm is the coherence interval.

This embedding is the **observational projection** of the full algebraic
structure: the (4,4) split-octonion space reduces through KKT obstruction
to a (3,1) spacetime, which further reduces to this (1,1) split-complex
plane — the "shadow of a shadow" (double Plato's cave).
-/
def coherencePoint (cd : ℕ) (t : EMLTree) : SplitComplex :=
  ⟨(dcStep t : ℤ), (frictionDensity cd : ℤ)⟩

/--
The coherence interval IS the split-complex norm of the coherence point.

    coherenceInterval(cd, t) = dcStep² − frictionDensity²
                             = SplitComplex.norm (coherencePoint cd t)

This is the fundamental connection between the Tamari metric space and the
split-complex algebra: the split-signature inner product on the Tamari
lattice is exactly the Lorentz-signature Pythagorean theorem `a² − b²`
applied to the coherence coordinates.

In physical terms: the Tamari lattice carries a (1,1) Minkowski metric
where `dcStep` is the timelike coordinate and `frictionDensity` is the
spacelike coordinate. The split-complex norm gives the Lorentz invariant
interval, and its sign classifies the causal type (timelike/lightlike/spacelike).
-/
theorem coherenceInterval_eq_splitComplexNorm (cd : ℕ) (t : EMLTree) :
    coherenceInterval cd t = SplitComplex.norm (coherencePoint cd t) := by
  simp [coherenceInterval, SplitComplex.norm, coherencePoint, pow_two]
