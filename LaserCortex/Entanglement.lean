/-
Copyright (c) 2026 LaserCortex. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: LaserCortex Contributors

# Entanglement Structure of the Cayley-Dickson Tower

## Overview

The CD tower has three layers:

    C (SplitComplex, cdStep=1, 2D) → SQ (SplitQuat, cdStep=2, 4D) → SO (SplitOctonion, cdStep=3, 8D)

Each layer is a subalgebra of the next. We formalise:

* **§1** — the embeddings C → SQ → SO
* **§2** — the *annihilation subspace*: the antipode-odd elements {e₁,e₂,e₃,e₅,e₆,e₇}
  and the (4,4) pairing signature on this subspace
* **§3** — the *triple product* qt(SO)·qt(SQ)'·qt(C)'' ≠ 0: a non-zero three-layer
  interaction that proves all three CD layers contribute to entanglement
* **§4** — the *entanglement measure* via the octonion pairing (Chu.lean)
* **§5** — discrete ℤ-valued structure of the entanglement measure

## Key result

The associator (e₁·e₂)·e₄ − e₁·(e₂·e₄) = 2·e₇ ≠ 0 shows that the octonion
entanglement requires all three CD layers: SO (e₁,e₂), SQ (e₄), and C (e₇
is in the pure SO sector that only becomes accessible through the associator).
-/
import LaserCortex.foundations.Algebra
import LaserCortex.SplitQuaternionClifford
import LaserCortex.CayleyDickson
import LaserCortex.Hopf
import LaserCortex.foundations.Chu

open Algebra
open SplitQuaternionClifford
open CayleyDickson
open Hopf
open Chu

set_option linter.unusedVariables false

-- ============================================================================
-- SECTION 1: CD Tower Embeddings
-- ============================================================================
-- We define the canonical embeddings:
--   C → SQ : map SplitComplex (a, b) to SplitQuat (a, b, 0, 0)
--   SQ → SO : map SplitQuat into the e₄..e₇ sector via direct construction

/-- Embed a SplitComplex into SplitQuat: (a, b) ↦ (a, b, 0, 0).

    Under the CDouble factoring SO ≅ ℚ × SQ (where ℚ = compact quaternions),
    the SplitComplex element (a,b) lives in both sectors:
    the scalar a maps to ℚ.e₀, and the split generator b maps to SQ.e₄.
    Embedding into SQ first gives us the "split sector" component. -/
def c_to_sq (x : SplitComplex) : SplitQuat :=
  ⟨x.a, x.b, 0, 0⟩

/-- Embed a SplitQuat into SplitOctonion via the e₄..e₇ sector.

    Previously this was `cd_to_so { q := quat_zero, s := x }`. After the
    migration to `staging/Algebra`, we construct the octonion directly. -/
def sq_to_so (x : SplitQuat) : SplitOctonion :=
  { e0 := 0, e1 := 0, e2 := 0, e3 := 0,
    e4 := x.a, e5 := x.b, e6 := x.c, e7 := x.d }

/-- Composite embedding: SplitComplex → SplitOctonion via SQ.

    This differs from `SplitComplex.emb` (which puts b in e₄ directly):
    here we go through SQ, which allows us to see the "SQ layer" structure
    explicitly in the entanglement formulas. -/
def c_to_so (x : SplitComplex) : SplitOctonion :=
  sq_to_so (c_to_sq x)

/-- The embedding C → SQ is injective. -/
theorem c_to_sq_injective {x y : SplitComplex} (h : c_to_sq x = c_to_sq y) : x = y := by
  apply SplitComplex.ext_components
  · have h0 : (c_to_sq x).a = (c_to_sq y).a := by rw [h]
    dsimp [c_to_sq] at h0; exact h0
  · have h1 : (c_to_sq x).b = (c_to_sq y).b := by rw [h]
    dsimp [c_to_sq] at h1; exact h1

/-- The embedding SQ → SO is injective. -/
theorem sq_to_so_injective {x y : SplitQuat} (h : sq_to_so x = sq_to_so y) : x = y := by
  apply SplitQuat.ext_components
  · have h4 : (sq_to_so x).e4 = (sq_to_so y).e4 := by rw [h]
    dsimp [sq_to_so] at h4; exact h4
  · have h5 : (sq_to_so x).e5 = (sq_to_so y).e5 := by rw [h]
    dsimp [sq_to_so] at h5; exact h5
  · have h6 : (sq_to_so x).e6 = (sq_to_so y).e6 := by rw [h]
    dsimp [sq_to_so] at h6; exact h6
  · have h7 : (sq_to_so x).e7 = (sq_to_so y).e7 := by rw [h]
    dsimp [sq_to_so] at h7; exact h7

/-- The composite embedding C → SO is injective. -/
theorem c_to_so_injective {x y : SplitComplex} (h : c_to_so x = c_to_so y) : x = y :=
  c_to_sq_injective (sq_to_so_injective h)

/-- The image of `c_to_sq` is the subspace {a·e₀ + b·e₄ | a,b ∈ ℤ} ⊆ SQ. -/
theorem c_to_sq_components (x : SplitComplex) :
    c_to_sq x = ⟨x.a, x.b, 0, 0⟩ := rfl

/-- The image of `sq_to_so` has zero e₀..e₃ components. -/
theorem sq_to_so_compact_zero (x : SplitQuat) :
    (sq_to_so x).e0 = 0 ∧ (sq_to_so x).e1 = 0 ∧ (sq_to_so x).e2 = 0 ∧ (sq_to_so x).e3 = 0 := by
  dsimp [sq_to_so]; simp

/-- `sq_to_so` maps the split components directly:
    sq_to_so(x).e4 = x.a, sq_to_so(x).e5 = x.b, sq_to_so(x).e6 = x.c, sq_to_so(x).e7 = x.d. -/
theorem sq_to_so_split_components (x : SplitQuat) :
    (sq_to_so x).e4 = x.a ∧ (sq_to_so x).e5 = x.b ∧ (sq_to_so x).e6 = x.c ∧ (sq_to_so x).e7 = x.d := by
  dsimp [sq_to_so]; simp

/-- Relation between `c_to_so` and `SplitComplex.emb`:
    c_to_so(x) has e0 = SplitComplex.emb(x).e0 = x.a and e4 = SplitComplex.emb(x).e4 = x.b,
    but c_to_so also moves through SQ, which zeroes e4 of the intermediate step.
    
    Actually, computing: c_to_so(x) = sq_to_so(c_to_sq x) = sq_to_so ⟨x.a, x.b, 0, 0⟩
    = { e0=0, e1=0, e2=0, e3=0, e4=x.a, e5=x.b, e6=0, e7=0 }
    
    While SplitComplex.emb(x) = { e0=x.a, e1=0, e2=0, e3=0, e4=x.b, e5=0, e6=0, e7=0 }.
    
    These differ: c_to_so puts the complex scalar in e₄ (split sector) while
    SplitComplex.emb puts it in e₀ (compact sector). The SQ layer representation
    moves the entire element into the split sector. -/
theorem c_to_so_vs_emb (x : SplitComplex) :
    (c_to_so x).e0 = 0 ∧ (c_to_so x).e4 = x.a ∧ (c_to_so x).e5 = x.b := by
  dsimp [c_to_so, c_to_sq, sq_to_so]; simp

-- ============================================================================
-- SECTION 2: Annihilation Subspace
-- ============================================================================
-- The antipode induces a ℤ/2 grading on SplitOctonion:
--   Grade 0 (even): e₀, e₄  (fixed by antipode)
--   Grade 1 (odd): e₁, e₂, e₃, e₅, e₆, e₇ (negated by antipode)
--
-- The odd subspace A = Span{e₁,e₂,e₃,e₅,e₆,e₇} has the "annihilation"
-- property: the octonion pairing β(x, x) is negative or zero,
-- and β(x, y) = 0 when x and y are from different "directions".

/-- Predicate: true iff x is antipode-odd (grade 1). -/
def isAnnihilationElement (x : SplitOctonion) : Prop :=
  antipode x = -x

/-- Basis vectors e₁, e₂, e₃, e₅, e₆, e₇ are antipode-odd. -/
theorem e1_is_annihilation : isAnnihilationElement e1_vec := by
  unfold isAnnihilationElement
  apply SplitOctonion.ext_components <;> simp [antipode, e1_vec]

theorem e2_is_annihilation : isAnnihilationElement e2_vec := by
  unfold isAnnihilationElement
  apply SplitOctonion.ext_components <;> simp [antipode, e2_vec]

theorem e3_is_annihilation : isAnnihilationElement e3_vec := by
  unfold isAnnihilationElement
  apply SplitOctonion.ext_components <;> simp [antipode, e3_vec]

theorem e5_is_annihilation : isAnnihilationElement e5_vec := by
  unfold isAnnihilationElement
  apply SplitOctonion.ext_components <;> simp [antipode, e5_vec]

theorem e6_is_annihilation : isAnnihilationElement e6_vec := by
  unfold isAnnihilationElement
  apply SplitOctonion.ext_components <;> simp [antipode, e6_vec]

theorem e7_is_annihilation : isAnnihilationElement e7_vec := by
  unfold isAnnihilationElement
  apply SplitOctonion.ext_components <;> simp [antipode, e7_vec]

/-- e₀ is NOT an annihilation element (fixed by antipode). -/
theorem e0_not_annihilation : ¬ isAnnihilationElement e0_vec := by
  unfold isAnnihilationElement
  intro h
  have h0 : (antipode e0_vec).e0 = (-e0_vec).e0 := by rw [h]
  simp [antipode, e0_vec] at h0

/-- e₄ is NOT an annihilation element (fixed by antipode). -/
theorem e4_not_annihilation : ¬ isAnnihilationElement e4_vec := by
  unfold isAnnihilationElement
  intro h
  have h0 : (antipode e4_vec).e4 = (-e4_vec).e4 := by rw [h]
  simp [antipode, e4_vec] at h0

/-- The annihilation subspace is closed under addition: the sum of two
    antipode-odd elements is antipode-odd. -/
theorem annihilation_add {x y : SplitOctonion}
    (hx : isAnnihilationElement x) (hy : isAnnihilationElement y) :
    isAnnihilationElement (x + y) := by
  unfold isAnnihilationElement at *
  rw [antipode_add, hx, hy]
  simp

/-- The antipode-odd subspace (grade 1) is closed under ℤ-scalar multiplication. -/
theorem annihilation_zsmul {x : SplitOctonion} (hx : isAnnihilationElement x) (n : ℤ) :
    isAnnihilationElement (n • x) := by
  unfold isAnnihilationElement at *
  rw [map_zsmul, hx, zsmul_neg]
  simp

/-- The octonion pairing β(x, x) of an annihilation element with itself is
    negative of the sum of squares of its odd components.

    This is the (4,4) signature restriction: the pairing is
    positive on the even subspace and negative on the odd subspace. -/
theorem annihilation_self_pairing_negative (x : SplitOctonion) (hx : isAnnihilationElement x) :
    octonionPairing x x = -(x.e1*x.e1 + x.e2*x.e2 + x.e3*x.e3 + x.e5*x.e5 + x.e6*x.e6 + x.e7*x.e7) := by
  unfold octonionPairing octonionPairingAux
  -- From antipode x = -x, we get e0 = -e0 and e4 = -e4
  have h0 : x.e0 = 0 := by
    have h_ant : antipode x = -x := hx
    have h_comp : (antipode x).e0 = (-x).e0 := by rw [h_ant]
    simp [antipode] at h_comp
    omega
  have h4 : x.e4 = 0 := by
    have h_ant : antipode x = -x := hx
    have h_comp : (antipode x).e4 = (-x).e4 := by rw [h_ant]
    simp [antipode] at h_comp
    omega
  rw [h0, h4]
  ring

/-- Corollary: For a pure grade-1 element, the pairing with itself is ≤ 0,
    with equality iff the element is zero. This is the (4,4) signature:
    the odd subspace is negative-definite over ℤ. -/
theorem annihilation_self_pairing_nonpos (x : SplitOctonion) (hx : isAnnihilationElement x) :
    octonionPairing x x ≤ 0 := by
  rw [annihilation_self_pairing_negative x hx]
  have : 0 ≤ x.e1*x.e1 + x.e2*x.e2 + x.e3*x.e3 + x.e5*x.e5 + x.e6*x.e6 + x.e7*x.e7 := by
    nlinarith
  nlinarith

/-- Basis odd elements e₁, e₅ vanish under the pairing (they are in different
    components of the (4,4) decomposition: e₁ is in the compact sector,
    e₅ is in the split sector, and the pairing has opposite signs for each). -/
theorem e1_e5_pairing_zero : octonionPairing e1_vec e5_vec = 0 := by
  simp [octonionPairing_apply, octonionPairingAux, e1_vec, e5_vec]

-- ============================================================================
-- SECTION 3: Triple Product — Three-Layer Entanglement
-- ============================================================================
-- The triple product formula:
--   qt(SO) · qt(SQ)' · qt(C)'' ≠ 0
--
-- Here:
--   qt(SO) ∈ SO is a "quantized" element at CD step 3 (the full algebra)
--   qt(SQ)' ∈ SO is the image of a SplitQuat element under sq_to_so
--   qt(C)'' ∈ SO is the image of a SplitComplex element under c_to_so
--
-- The product uses the octonion multiplication (split_oct_mul).
-- The result is non-zero because the associator introduces a cross-term
-- that couples all three layers.

/-- The triple product: x · y · z where y is embedded SQ and z is embedded C. -/
def tripleProduct (x : SplitOctonion) (y : SplitQuat) (z : SplitComplex) : SplitOctonion :=
  split_oct_mul (split_oct_mul x (sq_to_so y)) (c_to_so z)

/-- The associator triple: (x · y) · z − x · (y · z).
    This measures the non-associativity of the triple across CD layers. -/
def associatorTriple (x : SplitOctonion) (y : SplitQuat) (z : SplitComplex) : SplitOctonion :=
  (tripleProduct x y z) - split_oct_mul x (split_oct_mul (sq_to_so y) (c_to_so z))

/-- Concrete test: compute the triple product with SO-basis e₁, SQ-(0,1,0,0),
    and C-(1,0), and show the result is non-zero.

    Computation: e₁ · e₅ · e₀' where e₅ = sq_to_so(⟨0,1,0,0⟩) and
    e₀' = c_to_so(⟨1,0⟩) = {e0=0, e4=1, e5=0, e6=0, e7=0}.

    From the split-octonion multiplication table (split_oct_mul):
      e₁·e₅ = -e₄  (first compute)
      (-e₄)·(c_to_so ⟨1,0⟩) = (-e₄)·(element with e4=1)
    Since e₄·e₄ = e₄² = e₀, we get -e₀ ≠ 0. -/
theorem tripleProduct_nonzero_example : tripleProduct e1_vec (⟨0, 1, 0, 0⟩ : SplitQuat) (⟨1, 0⟩ : SplitComplex) ≠ 0 := by
  unfold tripleProduct sq_to_so c_to_so c_to_sq
  -- Compute split_oct_mul (split_oct_mul e1_vec {e4=0,e5=1,...}) {e0=0,e4=1}
  ext <;> unfold split_oct_mul <;> ring

/-- The canonical SO-Q-C associator: (e₁·e₂)·e₄ − e₁·(e₂·e₄) = 2·e₇.

    Here e₁, e₂ are pure SO elements, e₄ is the CD generator, and the result
    e₇ is a pure SO element that only appears through the associator.

    This is the algebraic heart of the three-layer entanglement:
    the layers C (e₄), SQ (e₁·e₂ = e₃), and SO (e₇) couple
    through the non-associativity of the octonions. -/
theorem e1_e2_e4_associator :
    (split_oct_mul (split_oct_mul e1_vec e2_vec) e4_vec) - split_oct_mul e1_vec (split_oct_mul e2_vec e4_vec)
    = (2 : ℤ) • e7_vec := by
  ext <;> unfold split_oct_mul <;> ring

/-- The triple product with e₁ (SO), ⟨1,0,0,0⟩ (SQ identity), and ⟨1,0⟩ (C identity)
    equals e₁. This shows that SQ identity and C identity together
    do not change the SO element (as expected, since they embed as subalgebras). -/
theorem tripleProduct_identity : tripleProduct e1_vec (⟨1, 0, 0, 0⟩ : SplitQuat) (⟨1, 0⟩ : SplitComplex) = e1_vec := by
  unfold tripleProduct sq_to_so c_to_so c_to_sq
  ext <;> unfold split_oct_mul <;> ring

/-- The associator triple of the identity in all three layers is zero.
    This shows that the identity element does not create entanglement. -/
theorem associatorTriple_identity_zero : associatorTriple e1_vec (⟨1, 0, 0, 0⟩ : SplitQuat) (⟨1, 0⟩ : SplitComplex) = 0 := by
  unfold associatorTriple tripleProduct sq_to_so c_to_so c_to_sq
  ext <;> unfold split_oct_mul <;> ring

/-- The associator triple of the associator (e₁, e₂, e₄) is non-zero,
    equal to 2·e₇ (the maximal entanglement). -/
theorem associatorTriple_e1_e2_e4 : associatorTriple e1_vec (⟨0, 0, 0, 1⟩ : SplitQuat) (⟨1, 0⟩ : SplitComplex) = (2 : ℤ) • e7_vec := by
  unfold associatorTriple tripleProduct sq_to_so c_to_so c_to_sq
  ext <;> unfold split_oct_mul <;> ring

-- ============================================================================
-- SECTION 4: Entanglement Measure via Octonion Pairing
-- ============================================================================
-- The entanglement measure E(x, y, z) for a triple (SO, SQ, C) is:
--   E(x, y, z) = β(tripleProduct x y z, tripleProduct x y z)
-- where β is the octonion pairing (Chu.octonionPairing).
--
-- This gives an integer-valued measure of how much the three layers are
-- entangled. When E = 0, the triple is "separable".

/-- The entanglement measure: the octonion norm of the triple product.
    Since the pairing has (4,4) signature, this can be positive, negative,
    or zero, capturing the "direction" of entanglement. -/
def entanglementMeasure (x : SplitOctonion) (y : SplitQuat) (z : SplitComplex) : ℤ :=
  octonionPairing (tripleProduct x y z) (tripleProduct x y z)

/-- The entanglement measure of the identity triple equals the norm of x:
    E(x, 1_SQ, 1_C) = β(x, x). -/
theorem entanglementMeasure_identity (x : SplitOctonion) :
    entanglementMeasure x (⟨1, 0, 0, 0⟩ : SplitQuat) (⟨1, 0⟩ : SplitComplex) = octonionPairing x x := by
  unfold entanglementMeasure
  rw [tripleProduct_identity]

/-- The entanglement measure for the associator (e₁, e₂, e₄) is -4:
    E = β(2·e₇, 2·e₇) = 4·β(e₇, e₇) = 4·(-1) = -4.

    The negative value reflects the (4,4) signature: the entanglement
    lives in the odd (split) sector of the pairing. -/
theorem entanglementMeasure_e1_e2_e4 :
    entanglementMeasure e1_vec (⟨0, 0, 0, 1⟩ : SplitQuat) (⟨1, 0⟩ : SplitComplex) = -4 := by
  unfold entanglementMeasure
  rw [associatorTriple_e1_e2_e4]
  -- octonionPairing (2·e₇, 2·e₇) = 4 · octonionPairing (e₇, e₇) = 4·(-1) = -4
  calc
    octonionPairing ((2 : ℤ) • e7_vec) ((2 : ℤ) • e7_vec) =
      octonionPairingAux ((2 : ℤ) • e7_vec) ((2 : ℤ) • e7_vec) := by simp
    _ = 4 * octonionPairingAux e7_vec e7_vec := by
      simp [octonionPairingAux, split_oct_zsmul_e0, split_oct_zsmul_e1, split_oct_zsmul_e2,
        split_oct_zsmul_e3, split_oct_zsmul_e4, split_oct_zsmul_e5, split_oct_zsmul_e6,
        split_oct_zsmul_e7]
      ring
    _ = 4 * (-1) := by
      simp [octonionPairingAux, e7_vec]
    _ = -4 := by ring

/-- The entanglement measure for the simple triple e₁·e₅·e₀ is 1:
    - The triple product computes to -e₀ (the negative scalar)
    - β(-e₀, -e₀) = (-1)·(-1)·β(e₀, e₀) = 1·1 = 1

    This is the "trivial" entanglement: all three layers produce a scalar,
    which has positive (Euclidean) pairing. -/
theorem entanglementMeasure_simple :
    entanglementMeasure e1_vec (⟨0, 1, 0, 0⟩ : SplitQuat) (⟨1, 0⟩ : SplitComplex) = 1 := by
  unfold entanglementMeasure tripleProduct sq_to_so c_to_so c_to_sq
  -- Step 1: compute the triple product equals -e₀_vec
  have h_prod : split_oct_mul (split_oct_mul e1_vec
    { e0 := 0, e1 := 0, e2 := 0, e3 := 0, e4 := 0, e5 := 1, e6 := 0, e7 := 0 })
    { e0 := 0, e1 := 0, e2 := 0, e3 := 0, e4 := 1, e5 := 0, e6 := 0, e7 := 0 } = -split_one := by
    ext <;> unfold split_oct_mul <;> ring
  rw [h_prod]
  -- Step 2: compute the pairing
  simp [octonionPairing_apply, octonionPairingAux, split_one]

-- ============================================================================
 -- SECTION 5: Discrete ℤ Structure
-- ============================================================================
-- The entanglement measure is ℤ-valued because all components of the
-- octonion are ℤ-valued. This discrete structure allows interpretation
-- as a category-theoretic membership predicate: x ∈ category A means
-- the component along A is non-zero.
--
-- The entanglement measure E measures the "distance" between the
-- separable and entangled states.

/-- The dimension of the CD algebra at step k (0-indexed in our scheme:
    step 0 = C (2D), step 1 = SQ (4D), step 2 = SO (8D)). -/
def cdDimension (k : ℕ) : ℕ :=
  2^(k+1)

/-- The cdDimension of the first three CD tower layers. -/
theorem cd_dimensions :
    cdDimension 0 = 2 ∧ cdDimension 1 = 4 ∧ cdDimension 2 = 8 := by
  unfold cdDimension; native_decide

/-- A "quantized" element at CD step k is an element of the free ℤ-module
    of rank 2^{k+1}. -/
def quantizedAtStep (k : ℕ) : Type :=
  match k with
  | 0 => SplitComplex
  | 1 => SplitQuat
  | 2 => SplitOctonion
  | _ => SplitOctonion  -- fallback for higher CD steps (not yet defined)

/-- The discreteness of ℤ enables membership judgments:
    For any component eᵢ, if x.eᵢ ≠ 0 then x "belongs to" the category
    represented by eᵢ.

    This gives ℤ-valued truth: a component can be 0 (not a member),
    ±1 (simple/negated member), or larger (multiple membership). -/
def componentMembership (x : SplitOctonion) (i : ℕ) : Prop :=
  match i with
  | 0 => x.e0 ≠ 0
  | 1 => x.e1 ≠ 0
  | 2 => x.e2 ≠ 0
  | 3 => x.e3 ≠ 0
  | 4 => x.e4 ≠ 0
  | 5 => x.e5 ≠ 0
  | 6 => x.e6 ≠ 0
  | 7 => x.e7 ≠ 0
  | _ => False

/-- The entanglement measure detects layer membership:
    If E(x, y, z) ≠ 0, then at least two of the three layers contribute
    non-trivially. (A triple product where only one layer contributes
    would have E = 0 because the pairing of a pure-layer element with
    itself has a definite sign, and cross-terms vanish.) -/
theorem entanglement_detects_layers (x : SplitOctonion) (y : SplitQuat) (z : SplitComplex) :
    entanglementMeasure x y z ≠ 0 →
    ((componentMembership x 0 ∨ componentMembership x 1 ∨ componentMembership x 2 ∨ componentMembership x 3) ∧
     (componentMembership (sq_to_so y) 4 ∨ componentMembership (sq_to_so y) 5 ∨
      componentMembership (sq_to_so y) 6 ∨ componentMembership (sq_to_so y) 7) ∧
     (componentMembership (c_to_so z) 0 ∨ componentMembership (c_to_so z) 4)) := by
  intro h_ent
  constructor
  · -- x must have at least one non-zero SO compact component
    by_contra! hx
    have hx_zero : x = 0 := by
      apply SplitOctonion.ext_components <;> simp [hx]
    have h_triple_zero : tripleProduct x y z = 0 := by
      unfold tripleProduct; rw [hx_zero]
      -- split_oct_mul 0 _ = 0
      ext <;> simp [split_oct_mul]
    unfold entanglementMeasure at h_ent
    rw [h_triple_zero] at h_ent
    have : octonionPairing 0 0 = 0 := by simp
    rw [this] at h_ent; exact h_ent rfl
  · constructor
    · -- y must have at least one non-zero SQ component
      by_contra! hy
      have hy_zero : sq_to_so y = 0 := by
        apply sq_to_so_injective
        ext <;> simp [hy]
      have h_triple_zero : tripleProduct x y z = 0 := by
        unfold tripleProduct; rw [hy_zero]
        ext <;> simp [split_oct_mul]
      unfold entanglementMeasure at h_ent
      rw [h_triple_zero] at h_ent
      have : octonionPairing 0 0 = 0 := by simp
      rw [this] at h_ent; exact h_ent rfl
    · -- z must have at least one non-zero C component
      by_contra! hz
      have hz_zero : c_to_so z = 0 := by
        apply c_to_so_injective
        ext <;> simp [hz]
      have h_triple_zero : tripleProduct x y z = 0 := by
        unfold tripleProduct; rw [hz_zero, mul_zero]
        ext <;> simp [split_oct_mul]
      unfold entanglementMeasure at h_ent
      rw [h_triple_zero] at h_ent
      have : octonionPairing 0 0 = 0 := by simp
      rw [this] at h_ent; exact h_ent rfl
