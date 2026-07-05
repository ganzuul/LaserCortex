import Mathlib
import LaserCortex.staging.Algebra

/-!
# Chu Pairing — Duality on Split Algebras

A Chu space over a ℤ-module `M` is a triple `(a, a', β)` where
`β : M →ₗ[ℤ] M →ₗ[ℤ] ℤ` is a ℤ-bilinear pairing.

We construct the canonical ℤ-bilinear pairings on `SplitQuat` and
`SplitOctonion`, prove nondegeneracy, and show the embedding
`SplitQuat → Cl11` is a ℤ-algebra homomorphism.
-/

namespace Chu

-- ============================================================================
-- Local @[simp] lemmas for component access
-- These are definitionally true (rfl) and safe to add anywhere.
-- They let `simp` expand `(x+y).a` to `x.a+y.a` etc. before `ring`.
-- ============================================================================

@[simp] theorem split_quat_add_a (x y : SplitQuat) : (x + y).a = x.a + y.a := rfl
@[simp] theorem split_quat_add_b (x y : SplitQuat) : (x + y).b = x.b + y.b := rfl
@[simp] theorem split_quat_add_c (x y : SplitQuat) : (x + y).c = x.c + y.c := rfl
@[simp] theorem split_quat_add_d (x y : SplitQuat) : (x + y).d = x.d + y.d := rfl

@[simp] theorem split_quat_mul_a (x y : SplitQuat) : (x * y).a = x.a * y.a - x.b * y.b + x.c * y.c + x.d * y.d := rfl
@[simp] theorem split_quat_mul_b (x y : SplitQuat) : (x * y).b = x.a * y.b + x.b * y.a - x.c * y.d + x.d * y.c := rfl
@[simp] theorem split_quat_mul_c (x y : SplitQuat) : (x * y).c = x.a * y.c - x.b * y.d + x.c * y.a + x.d * y.b := rfl
@[simp] theorem split_quat_mul_d (x y : SplitQuat) : (x * y).d = x.a * y.d + x.b * y.c - x.c * y.b + x.d * y.a := rfl

@[simp] theorem split_add_e0 (x y : SplitOctonion) : (x + y).e0 = x.e0 + y.e0 := rfl
@[simp] theorem split_add_e1 (x y : SplitOctonion) : (x + y).e1 = x.e1 + y.e1 := rfl
@[simp] theorem split_add_e2 (x y : SplitOctonion) : (x + y).e2 = x.e2 + y.e2 := rfl
@[simp] theorem split_add_e3 (x y : SplitOctonion) : (x + y).e3 = x.e3 + y.e3 := rfl
@[simp] theorem split_add_e4 (x y : SplitOctonion) : (x + y).e4 = x.e4 + y.e4 := rfl
@[simp] theorem split_add_e5 (x y : SplitOctonion) : (x + y).e5 = x.e5 + y.e5 := rfl
@[simp] theorem split_add_e6 (x y : SplitOctonion) : (x + y).e6 = x.e6 + y.e6 := rfl
@[simp] theorem split_add_e7 (x y : SplitOctonion) : (x + y).e7 = x.e7 + y.e7 := rfl

-- ============================================================================
-- SECTION 1: Chu space over a ℤ-module
-- ============================================================================

@[ext]
structure ChuSpace (M : Type u) [AddCommGroup M] where
  a : M
  a' : M
  pair : M →ₗ[ℤ] M →ₗ[ℤ] ℤ

@[simp] def primal (M : Type u) [AddCommGroup M] (X : ChuSpace M) : M := X.a
@[simp] def dual (M : Type u) [AddCommGroup M] (X : ChuSpace M) : M := X.a'

def dualize (M : Type u) [AddCommGroup M] (X : ChuSpace M) : ChuSpace M :=
  { a := X.a', a' := X.a
    pair := LinearMap.flip X.pair }

@[simp] theorem dualize_dualize (M : Type u) [AddCommGroup M] (X : ChuSpace M) :
    dualize M (dualize M X) = X := by
  dsimp [dualize]; ext <;> simp

-- ============================================================================
-- SECTION 2: The canonical SplitQuat pairing
-- ============================================================================

def splitQuatPairingAux (y z : SplitQuat) : ℤ :=
  y.a * z.a + y.b * z.b - y.c * z.c - y.d * z.d

theorem splitQuatPairingAux_eq_product (y z : SplitQuat) :
    splitQuatPairingAux y z = (antipode_sq y * z).a := by
  dsimp [splitQuatPairingAux, antipode_sq]
  simp
  ring

def splitQuatPairing : SplitQuat →ₗ[ℤ] SplitQuat →ₗ[ℤ] ℤ :=
  { toFun := λ y =>
    { toFun := splitQuatPairingAux y
      map_add' := λ z₁ z₂ => by
        dsimp [splitQuatPairingAux]
        ring
      map_smul' := λ r z => by
        dsimp [splitQuatPairingAux]
        simp [split_quat_zsmul_a, split_quat_zsmul_b, split_quat_zsmul_c, split_quat_zsmul_d]
        ring
    }
    map_add' := λ y₁ y₂ => by
      ext z; dsimp [splitQuatPairingAux]; ring
    map_smul' := λ r y => by
      ext z; dsimp [splitQuatPairingAux]
      simp [split_quat_zsmul_a, split_quat_zsmul_b, split_quat_zsmul_c, split_quat_zsmul_d]
      ring
  }

@[simp] theorem splitQuatPairing_apply (y z : SplitQuat) :
    splitQuatPairing y z = splitQuatPairingAux y z := rfl

theorem splitQuatPairingAux_symm (y z : SplitQuat) : splitQuatPairingAux y z = splitQuatPairingAux z y := by
  dsimp [splitQuatPairingAux]; ring

theorem splitQuatPairing_antipode_symm (y z : SplitQuat) :
    splitQuatPairing (antipode_sq y) z = splitQuatPairing y (antipode_sq z) := by
  simp [splitQuatPairing_apply, splitQuatPairingAux, antipode_sq]

theorem splitQuatPairing_nondegenerate (y : SplitQuat) (h : ∀ z, splitQuatPairing y z = 0) :
    y = 0 := by
  have ha : y.a = 0 := by
    have hz := h ⟨1, 0, 0, 0⟩
    simpa [splitQuatPairing_apply, splitQuatPairingAux] using hz
  have hb : y.b = 0 := by
    have hz := h ⟨0, 1, 0, 0⟩
    simpa [splitQuatPairing_apply, splitQuatPairingAux] using hz
  have hc : y.c = 0 := by
    have hz := h ⟨0, 0, 1, 0⟩
    have : splitQuatPairing y ⟨0, 0, 1, 0⟩ = -y.c := by
      simp [splitQuatPairing_apply, splitQuatPairingAux]
    have hneg : -y.c = 0 := by rwa [this] at hz
    linarith
  have hd : y.d = 0 := by
    have hz := h ⟨0, 0, 0, 1⟩
    have : splitQuatPairing y ⟨0, 0, 0, 1⟩ = -y.d := by
      simp [splitQuatPairing_apply, splitQuatPairingAux]
    have hneg : -y.d = 0 := by rwa [this] at hz
    linarith
  ext <;> assumption

-- ============================================================================
-- SECTION 2b: The canonical SplitOctonion pairing
-- ============================================================================

def octonionPairingAux (y z : SplitOctonion) : ℤ :=
  y.e0*z.e0 + y.e1*z.e1 + y.e2*z.e2 + y.e3*z.e3 + y.e4*z.e4
  - y.e5*z.e5 - y.e6*z.e6 - y.e7*z.e7

theorem octonionPairingAux_eq_antipodePairing (y z : SplitOctonion) :
    octonionPairingAux y z = antipodePairing y z := by
  dsimp [antipodePairing, octonionPairingAux, split_oct_mul, antipode]
  ring

def octonionPairing : SplitOctonion →ₗ[ℤ] SplitOctonion →ₗ[ℤ] ℤ :=
  { toFun := λ y =>
    { toFun := octonionPairingAux y
      map_add' := λ z₁ z₂ => by
        dsimp [octonionPairingAux]
        ring
      map_smul' := λ r z => by
        dsimp [octonionPairingAux]
        simp [split_oct_zsmul_e0, split_oct_zsmul_e1, split_oct_zsmul_e2, split_oct_zsmul_e3,
          split_oct_zsmul_e4, split_oct_zsmul_e5, split_oct_zsmul_e6, split_oct_zsmul_e7]
        ring
    }
    map_add' := λ y₁ y₂ => by
      ext z; dsimp [octonionPairingAux]; ring
    map_smul' := λ r y => by
      ext z; dsimp [octonionPairingAux]
      simp [split_oct_zsmul_e0, split_oct_zsmul_e1, split_oct_zsmul_e2, split_oct_zsmul_e3,
        split_oct_zsmul_e4, split_oct_zsmul_e5, split_oct_zsmul_e6, split_oct_zsmul_e7]
      ring
  }

@[simp] theorem octonionPairing_apply (y z : SplitOctonion) :
    octonionPairing y z = octonionPairingAux y z := rfl

theorem octonionPairingAux_symm (y z : SplitOctonion) : octonionPairingAux y z = octonionPairingAux z y := by
  dsimp [octonionPairingAux]; ring

theorem octonionPairing_antipode_symm (y z : SplitOctonion) :
    octonionPairing (antipode y) z = octonionPairing y (antipode z) := by
  simp [octonionPairing_apply, octonionPairingAux, antipode]

theorem octonionPairing_nondegenerate (y : SplitOctonion)
    (h : ∀ z, octonionPairing y z = 0) : y = 0 := by
  have h0 : y.e0 = 0 := by
    have hz := h e0_vec
    simpa [octonionPairing_apply, octonionPairingAux, e0_vec] using hz
  have h1 : y.e1 = 0 := by
    have hz := h e1_vec
    simpa [octonionPairing_apply, octonionPairingAux, e1_vec] using hz
  have h2 : y.e2 = 0 := by
    have hz := h e2_vec
    simpa [octonionPairing_apply, octonionPairingAux, e2_vec] using hz
  have h3 : y.e3 = 0 := by
    have hz := h e3_vec
    simpa [octonionPairing_apply, octonionPairingAux, e3_vec] using hz
  have h4 : y.e4 = 0 := by
    have hz := h e4_vec
    simpa [octonionPairing_apply, octonionPairingAux, e4_vec] using hz
  have h5 : y.e5 = 0 := by
    have hz := h e5_vec
    have : octonionPairing y e5_vec = -y.e5 := by
      simp [octonionPairing_apply, octonionPairingAux, e5_vec]
    have hneg : -y.e5 = 0 := by rwa [this] at hz
    linarith
  have h6 : y.e6 = 0 := by
    have hz := h e6_vec
    have : octonionPairing y e6_vec = -y.e6 := by
      simp [octonionPairing_apply, octonionPairingAux, e6_vec]
    have hneg : -y.e6 = 0 := by rwa [this] at hz
    linarith
  have h7 : y.e7 = 0 := by
    have hz := h e7_vec
    have : octonionPairing y e7_vec = -y.e7 := by
      simp [octonionPairing_apply, octonionPairingAux, e7_vec]
    have hneg : -y.e7 = 0 := by rwa [this] at hz
    linarith
  apply SplitOctonion.ext_components <;> assumption

theorem antipodePairing_nondegenerate (y : SplitOctonion)
    (h : ∀ z, antipodePairing y z = 0) : y = 0 := by
  apply octonionPairing_nondegenerate y
  intro z
  rw [octonionPairing_apply, octonionPairingAux_eq_antipodePairing]
  exact h z

-- ============================================================================
-- SECTION 3: The Chu embedding of SplitQuat into Cl11
-- ============================================================================

def chuEmbed (x : SplitQuat) : Cl11 :=
  SplitQuat.embed x

def chuSpaceOf (x : SplitQuat) : ChuSpace SplitQuat :=
  { a := x
    a' := antipode_sq x
    pair := splitQuatPairing }

theorem chu_embed_mul (x y : SplitQuat) : SplitQuat.embed (x * y) = SplitQuat.embed x * SplitQuat.embed y := by
  dsimp [SplitQuat.embed, split_quat_mul]
  -- Convert all • to * using Algebra.smul_def
  -- Use `simp` (not `erw`) since Algebra.smul_def is already in the default simp set
  -- But we need to apply it to all subterms; use `conv` with `simp`
  conv =>
    lhs
    simp [Algebra.smul_def]
  conv =>
    rhs
    simp [Algebra.smul_def]
  -- Now both sides are expressed with * and algebraMap
  -- Expand the RHS product
  noncomm_ring
  -- Apply Clifford relations: e0'^2 = 1, e1'^2 = -1, e0'*e1' = -(e1'*e0')
  -- Use `simp` with `mul_assoc` to rewrite powers
  simp [e0_sq', e1_sq', anticommute', mul_assoc]
  -- Now both sides are linear combinations of {1, e0', e1', e0'*e1'} with scalar coefficients
  ring

theorem chu_zsmul_eq_mul (r : ℤ) (x : Cl11) : r • x = (algebraMap ℤ Cl11 r) * x := by
  simp

-- ============================================================================
-- SECTION 4: Chu tensor and seq operations
-- ============================================================================

def ChuTensor (X Y : ChuSpace SplitQuat) : ChuSpace SplitQuat :=
  { a := X.a * Y.a
    a' := X.a' * Y.a'
    pair := splitQuatPairing }

def ChuSeq (X Y : ChuSpace SplitQuat) : ChuSpace SplitQuat :=
  { a := X.a * Y.a
    a' := Y.a' * X.a'
    pair := splitQuatPairing }

@[simp] theorem ChuTensor_a (X Y : ChuSpace SplitQuat) : (ChuTensor X Y).a = X.a * Y.a := rfl
@[simp] theorem ChuTensor_a' (X Y : ChuSpace SplitQuat) : (ChuTensor X Y).a' = X.a' * Y.a' := rfl
@[simp] theorem ChuSeq_a (X Y : ChuSpace SplitQuat) : (ChuSeq X Y).a = X.a * Y.a := rfl
@[simp] theorem ChuSeq_a' (X Y : ChuSpace SplitQuat) : (ChuSeq X Y).a' = Y.a' * X.a' := rfl

theorem chu_space_of_seq (x y : SplitQuat) : chuSpaceOf (x * y) = ChuSeq (chuSpaceOf x) (chuSpaceOf y) := by
  ext <;> simp [chuSpaceOf, ChuSeq, antipode_sq_mul]

theorem dualize_chuSpaceOf (x : SplitQuat) : dualize SplitQuat (chuSpaceOf x) = chuSpaceOf (antipode_sq x) := by
  ext <;> simp [chuSpaceOf, dualize, antipode_sq_involutive, splitQuatPairingAux_symm]

theorem star_involutive (x : SplitQuat) : dualize SplitQuat (dualize SplitQuat (chuSpaceOf x)) = chuSpaceOf x := by
  simp [dualize_dualize]

theorem kkt_stationarity (x y : SplitQuat) : SplitQuat.embed (x * y) = SplitQuat.embed x * SplitQuat.embed y :=
  chu_embed_mul x y

theorem kkt_complementarity (y : SplitQuat) (h : ∀ z, splitQuatPairing y z = 0) : y = 0 :=
  splitQuatPairing_nondegenerate y h

end Chu
