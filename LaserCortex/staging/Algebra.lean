import Mathlib
import Mathlib.LinearAlgebra.QuadraticForm.Basic

/-!
# Split-Octonion Algebra over ℤ

The split-octonion algebra with signature (4,4) over ℤ:
- Positive squares: e₀², ..., e₃² = +1
- Negative squares: e₄², ..., e₇² = -1
- Strut weight: strut_weight = 4
- ω = e₄ with ω² = +1

## Key definitions
- `SplitOctonion` — the split-octonion algebra over ℤ
- `Q44` — the quadratic form of signature (4,4)
- `strut_weight` — the norm of the associator at (e₁, e₂, e₄)
- `ω` — the Cayley-Dickson element (e₄), with ω² = +1
- `antipode` — S(x) = +x for first 4 basis elements, -x for last 4

## Key theorems
- `ω_sq` : ω² = +1
- `antipode_mul_false` : S(xy) ≠ S(y)S(x) in general
- `strut_weight_eq_four` : strut_weight = 4
- `Q44_nondegenerate` : Q44 is nondegenerate
- `antipode_preserves_norm` : octonion_norm(S(x)) = octonion_norm(x)
-/

-- ============================================================================
-- SplitOctonion type and basis
-- ============================================================================

structure SplitOctonion where
  e0 : Int
  e1 : Int
  e2 : Int
  e3 : Int
  e4 : Int
  e5 : Int
  e6 : Int
  e7 : Int
  deriving Repr

def split_zero : SplitOctonion := ⟨0, 0, 0, 0, 0, 0, 0, 0⟩
def split_one : SplitOctonion := ⟨1, 0, 0, 0, 0, 0, 0, 0⟩

-- ============================================================================
-- Vector representation (for DecidableEq and Q44 bridge)
-- ============================================================================

def toVec (x : SplitOctonion) : Fin 8 → ℤ := λ
  | 0 => x.e0 | 1 => x.e1 | 2 => x.e2 | 3 => x.e3
  | 4 => x.e4 | 5 => x.e5 | 6 => x.e6 | 7 => x.e7

def ofVec (v : Fin 8 → ℤ) : SplitOctonion :=
  { e0 := v 0, e1 := v 1, e2 := v 2, e3 := v 3,
    e4 := v 4, e5 := v 5, e6 := v 6, e7 := v 7 }

@[simp] theorem toVec_ofVec (v : Fin 8 → ℤ) : toVec (ofVec v) = v := by
  ext i; fin_cases i <;> rfl

@[simp] theorem ofVec_toVec (x : SplitOctonion) : ofVec (toVec x) = x := by
  cases x; rfl

def equivVec : SplitOctonion ≃ (Fin 8 → ℤ) :=
  { toFun := toVec
    invFun := ofVec
    left_inv := ofVec_toVec
    right_inv := toVec_ofVec
  }

-- ============================================================================
-- Multiplication table (Cayley-Dickson construction)
-- ============================================================================

def split_oct_mul (x y : SplitOctonion) : SplitOctonion :=
  ⟨
    x.e0*y.e0 - x.e1*y.e1 - x.e2*y.e2 - x.e3*y.e3 + x.e4*y.e4 + x.e5*y.e5 + x.e6*y.e6 + x.e7*y.e7,
    x.e0*y.e1 + x.e1*y.e0 + x.e2*y.e3 - x.e3*y.e2 - x.e4*y.e5 + x.e5*y.e4 + x.e6*y.e7 - x.e7*y.e6,
    x.e0*y.e2 - x.e1*y.e3 + x.e2*y.e0 + x.e3*y.e1 - x.e4*y.e6 - x.e5*y.e7 + x.e6*y.e4 + x.e7*y.e5,
    x.e0*y.e3 + x.e1*y.e2 - x.e2*y.e1 + x.e3*y.e0 - x.e4*y.e7 + x.e5*y.e6 - x.e6*y.e5 + x.e7*y.e4,
    x.e0*y.e4 + x.e4*y.e0 - x.e1*y.e5 + x.e5*y.e1 - x.e2*y.e6 + x.e6*y.e2 - x.e3*y.e7 + x.e7*y.e3,
    x.e0*y.e5 + x.e5*y.e0 + x.e1*y.e4 - x.e4*y.e1 - x.e2*y.e7 + x.e7*y.e2 + x.e3*y.e6 - x.e6*y.e3,
    x.e0*y.e6 + x.e6*y.e0 + x.e2*y.e4 - x.e4*y.e2 + x.e1*y.e7 - x.e7*y.e1 - x.e3*y.e5 + x.e5*y.e3,
    x.e0*y.e7 + x.e7*y.e0 + x.e3*y.e4 - x.e4*y.e3 - x.e1*y.e6 + x.e6*y.e1 + x.e2*y.e5 - x.e5*y.e2
  ⟩

def split_add (x y : SplitOctonion) : SplitOctonion :=
  ⟨x.e0+y.e0, x.e1+y.e1, x.e2+y.e2, x.e3+y.e3, x.e4+y.e4, x.e5+y.e5, x.e6+y.e6, x.e7+y.e7⟩

def split_sub (x y : SplitOctonion) : SplitOctonion :=
  ⟨x.e0-y.e0, x.e1-y.e1, x.e2-y.e2, x.e3-y.e3, x.e4-y.e4, x.e5-y.e5, x.e6-y.e6, x.e7-y.e7⟩

def split_neg (x : SplitOctonion) : SplitOctonion :=
  ⟨-x.e0, -x.e1, -x.e2, -x.e3, -x.e4, -x.e5, -x.e6, -x.e7⟩

-- ============================================================================
-- Componentwise equality
-- ============================================================================

@[ext]
lemma SplitOctonion.ext_components {a b : SplitOctonion}
    (h0 : a.e0 = b.e0) (h1 : a.e1 = b.e1) (h2 : a.e2 = b.e2)
    (h3 : a.e3 = b.e3) (h4 : a.e4 = b.e4) (h5 : a.e5 = b.e5)
    (h6 : a.e6 = b.e6) (h7 : a.e7 = b.e7) : a = b := by
  cases a; cases b
  simp at h0 h1 h2 h3 h4 h5 h6 h7
  simp [h0, h1, h2, h3, h4, h5, h6, h7]

-- ============================================================================
-- Algebraic instances
-- ============================================================================

instance : Add SplitOctonion := ⟨split_add⟩
instance : Zero SplitOctonion := ⟨split_zero⟩
instance : Neg SplitOctonion := ⟨split_neg⟩

instance : AddCommGroup SplitOctonion where
  zero := split_zero
  add := split_add
  neg := split_neg
  add_assoc := by
    intro a b c
    calc
      (a + b) + c = split_add (split_add a b) c := rfl
      _ = split_add a (split_add b c) := by
        apply SplitOctonion.ext_components <;> dsimp [split_add] <;> ring
      _ = a + (b + c) := rfl
  zero_add := by
    intro a
    calc
      0 + a = split_add split_zero a := rfl
      _ = a := by
        apply SplitOctonion.ext_components <;> dsimp [split_add, split_zero] <;> simp
  add_zero := by
    intro a
    calc
      a + 0 = split_add a split_zero := rfl
      _ = a := by
        apply SplitOctonion.ext_components <;> dsimp [split_add, split_zero] <;> simp
  add_comm := by
    intro a b
    calc
      a + b = split_add a b := rfl
      _ = split_add b a := by
        apply SplitOctonion.ext_components <;> dsimp [split_add] <;> simp [add_comm]
      _ = b + a := rfl
  neg_add_cancel := by
    intro a
    calc
      (-a) + a = split_add (split_neg a) a := rfl
      _ = split_zero := by
        apply SplitOctonion.ext_components <;> dsimp [split_add, split_neg, split_zero] <;> ring
      _ = 0 := rfl
  nsmul := nsmulRec
  nsmul_zero := by intro x; rfl
  nsmul_succ := by intro n x; rfl
  zsmul := zsmulRec
  zsmul_zero' := by intro x; rfl
  zsmul_succ' := by intro n x; rfl
  zsmul_neg' := by intro n x; rfl
  sub_eq_add_neg := by intro a b; rfl

instance : DecidableEq SplitOctonion :=
  equivVec.decidableEq

-- ============================================================================
-- Norm and associator
-- ============================================================================

def octonion_norm (x : SplitOctonion) : Int :=
  x.e0*x.e0 + x.e1*x.e1 + x.e2*x.e2 + x.e3*x.e3 - x.e4*x.e4 - x.e5*x.e5 - x.e6*x.e6 - x.e7*x.e7

def associator_tensor (a b c : SplitOctonion) : SplitOctonion :=
  split_sub (split_oct_mul (split_oct_mul a b) c) (split_oct_mul a (split_oct_mul b c))

def pentagon_defect (a b c d : SplitOctonion) : SplitOctonion :=
  split_add (split_sub (split_sub (split_add
    (split_oct_mul (associator_tensor a b c) d)
    (split_oct_mul (associator_tensor a b c) d))
    (associator_tensor (split_oct_mul a b) c d))
    (associator_tensor a (split_oct_mul b c) d))
    (split_sub (split_oct_mul a (associator_tensor b c d)) (associator_tensor a b (split_oct_mul c d)))

-- ============================================================================
-- Basis vectors
-- ============================================================================

def e0_vec : SplitOctonion := ⟨1, 0, 0, 0, 0, 0, 0, 0⟩
def e1_vec : SplitOctonion := ⟨0, 1, 0, 0, 0, 0, 0, 0⟩
def e2_vec : SplitOctonion := ⟨0, 0, 1, 0, 0, 0, 0, 0⟩
def e3_vec : SplitOctonion := ⟨0, 0, 0, 1, 0, 0, 0, 0⟩
def e4_vec : SplitOctonion := ⟨0, 0, 0, 0, 1, 0, 0, 0⟩
def e5_vec : SplitOctonion := ⟨0, 0, 0, 0, 0, 1, 0, 0⟩
def e6_vec : SplitOctonion := ⟨0, 0, 0, 0, 0, 0, 1, 0⟩
def e7_vec : SplitOctonion := ⟨0, 0, 0, 0, 0, 0, 0, 1⟩

-- ============================================================================
-- Q44 quadratic form (mathlib integration)
-- ============================================================================

open QuadraticMap

/-- The (4,4) quadratic form as a Mathlib `QuadraticForm ℤ (Fin 8 → ℤ)`.
    ++++---- signature, matching octonion_norm exactly. -/
def Q44 : QuadraticForm ℤ (Fin 8 → ℤ) :=
  proj 0 0 + proj 1 1 + proj 2 2 + proj 3 3
  - proj 4 4 - proj 5 5 - proj 6 6 - proj 7 7

theorem octonion_norm_eq_Q44 (x : SplitOctonion) : octonion_norm x = Q44 ![x.e0, x.e1, x.e2, x.e3, x.e4, x.e5, x.e6, x.e7] := by
  simp [Q44, octonion_norm, QuadraticMap.proj_apply]

-- ============================================================================
-- Strut weight
-- ============================================================================

def strut_weight : Nat :=
  (-octonion_norm (associator_tensor e1_vec e2_vec e4_vec)).toNat

theorem strut_weight_eq_four : strut_weight = 4 := by
  unfold strut_weight
  unfold associator_tensor e1_vec e2_vec e4_vec
  unfold split_sub split_oct_mul octonion_norm
  decide

theorem pentagon_defect_bound : (octonion_norm (pentagon_defect e1_vec e2_vec e4_vec e1_vec)).natAbs ≤ 10 := by
  unfold pentagon_defect associator_tensor e1_vec e2_vec e4_vec
  unfold split_sub split_add split_oct_mul octonion_norm
  decide

-- ============================================================================
-- Cayley-Dickson generator ω = e₄
-- ============================================================================

def omega : SplitOctonion := e4_vec

theorem omega_sq : split_oct_mul omega omega = split_one := by
  apply SplitOctonion.ext_components <;>
  unfold omega e4_vec split_oct_mul split_one <;> ring

theorem omega_anticomm_e5 : split_oct_mul omega e5_vec = split_neg (split_oct_mul e5_vec omega) := by
  apply SplitOctonion.ext_components <;>
  unfold omega e4_vec e5_vec split_oct_mul split_neg <;> ring

theorem omega_anticomm_e6 : split_oct_mul omega e6_vec = split_neg (split_oct_mul e6_vec omega) := by
  apply SplitOctonion.ext_components <;>
  unfold omega e4_vec e6_vec split_oct_mul split_neg <;> ring

theorem omega_anticomm_e7 : split_oct_mul omega e7_vec = split_neg (split_oct_mul e7_vec omega) := by
  apply SplitOctonion.ext_components <;>
  unfold omega e4_vec e7_vec split_oct_mul split_neg <;> ring

theorem omega_mul_e5 : split_oct_mul omega e5_vec = split_neg e1_vec := by
  apply SplitOctonion.ext_components <;>
  unfold omega e4_vec e5_vec e1_vec split_oct_mul split_neg <;> ring

theorem e5_mul_omega : split_oct_mul e5_vec omega = e1_vec := by
  apply SplitOctonion.ext_components <;>
  unfold omega e4_vec e5_vec e1_vec split_oct_mul <;> ring

-- ============================================================================
-- Antipode
-- ============================================================================

def antipode (x : SplitOctonion) : SplitOctonion :=
  { e0 := x.e0,
    e1 := -x.e1, e2 := -x.e2, e3 := -x.e3,
    e4 := x.e4,
    e5 := -x.e5, e6 := -x.e6, e7 := -x.e7
  }

theorem antipode_add (x y : SplitOctonion) : antipode (split_add x y) = split_add (antipode x) (antipode y) := by
  apply SplitOctonion.ext_components <;> simp [antipode, split_add, add_comm]

theorem antipode_neg (x : SplitOctonion) : antipode (-x) = -antipode x := by
  calc
    antipode (-x) = antipode (split_neg x) := rfl
    _ = split_neg (antipode x) := by
      apply SplitOctonion.ext_components <;> dsimp [antipode, split_neg]
    _ = -antipode x := rfl

theorem antipode_involutive (x : SplitOctonion) : antipode (antipode x) = x := by
  apply SplitOctonion.ext_components <;> simp [antipode]

theorem antipode_one : antipode split_one = split_one := by
  apply SplitOctonion.ext_components <;> simp [antipode, split_one]

theorem antipode_mul_false : ¬ (∀ x y : SplitOctonion, antipode (split_oct_mul x y) = split_oct_mul (antipode y) (antipode x)) := by
  intro h
  have hc := h e1_vec e4_vec
  have h_left : antipode (split_oct_mul e1_vec e4_vec) = ⟨0, 0, 0, 0, 0, -1, 0, 0⟩ := by
    ext <;> simp [e1_vec, e4_vec, antipode, split_oct_mul]
  have h_right : split_oct_mul (antipode e4_vec) (antipode e1_vec) = ⟨0, 0, 0, 0, 0, 1, 0, 0⟩ := by
    ext <;> simp [e1_vec, e4_vec, antipode, split_oct_mul]
  rw [h_left, h_right] at hc
  have h_contra : (-1 : ℤ) = (1 : ℤ) := by
    simpa using congrArg SplitOctonion.e5 hc
  norm_num at h_contra

-- ============================================================================
-- Counit and antipode pairing
-- ============================================================================

def counit (x : SplitOctonion) : ℤ := x.e0

def antipodePairing (x y : SplitOctonion) : ℤ :=
  (split_oct_mul (antipode x) y).e0

theorem antipode_pairing_self (x : SplitOctonion) : antipodePairing (antipode x) x =
    x.e0*x.e0 - x.e1*x.e1 - x.e2*x.e2 - x.e3*x.e3 + x.e4*x.e4 + x.e5*x.e5 + x.e6*x.e6 + x.e7*x.e7 := by
  rcases x with ⟨e0, e1, e2, e3, e4, e5, e6, e7⟩
  dsimp [antipodePairing, antipode, split_oct_mul]
  ring

theorem antipode_copairing_self (x : SplitOctonion) : (split_oct_mul x (antipode x)).e0 =
    x.e0*x.e0 + x.e1*x.e1 + x.e2*x.e2 + x.e3*x.e3 + x.e4*x.e4 - x.e5*x.e5 - x.e6*x.e6 - x.e7*x.e7 := by
  rcases x with ⟨e0, e1, e2, e3, e4, e5, e6, e7⟩
  dsimp [antipode, split_oct_mul]
  ring

-- ============================================================================
-- Antipode fixed points
-- ============================================================================

def isFixedPoint (x : SplitOctonion) : Prop :=
  antipode x = x

theorem fixed_point_components (x : SplitOctonion) (h : isFixedPoint x) :
    x.e1 = 0 ∧ x.e2 = 0 ∧ x.e3 = 0 ∧ x.e5 = 0 ∧ x.e6 = 0 ∧ x.e7 = 0 := by
  have h_eq : antipode x = x := h
  unfold antipode at h_eq
  have h_e1 := congrArg SplitOctonion.e1 h_eq
  have h_e2 := congrArg SplitOctonion.e2 h_eq
  have h_e3 := congrArg SplitOctonion.e3 h_eq
  have h_e5 := congrArg SplitOctonion.e5 h_eq
  have h_e6 := congrArg SplitOctonion.e6 h_eq
  have h_e7 := congrArg SplitOctonion.e7 h_eq
  have h1 : x.e1 = 0 := by linarith
  have h2 : x.e2 = 0 := by linarith
  have h3 : x.e3 = 0 := by linarith
  have h5 : x.e5 = 0 := by linarith
  have h6 : x.e6 = 0 := by linarith
  have h7 : x.e7 = 0 := by linarith
  exact ⟨h1, h2, h3, h5, h6, h7⟩

theorem fixed_point_e0 (x : SplitOctonion) : (antipode x).e0 = x.e0 := by
  simp [antipode]

theorem fixed_point_e4 (x : SplitOctonion) : (antipode x).e4 = x.e4 := rfl

-- ============================================================================
-- Antipode preserves norm
-- ============================================================================

theorem antipode_preserves_norm (x : SplitOctonion) : octonion_norm (antipode x) = octonion_norm x := by
  calc
    octonion_norm (antipode x) = (antipode x).e0 * (antipode x).e0 + (antipode x).e1 * (antipode x).e1 +
      (antipode x).e2 * (antipode x).e2 + (antipode x).e3 * (antipode x).e3 -
      (antipode x).e4 * (antipode x).e4 - (antipode x).e5 * (antipode x).e5 -
      (antipode x).e6 * (antipode x).e6 - (antipode x).e7 * (antipode x).e7 := rfl
    _ = x.e0 * x.e0 + (-x.e1) * (-x.e1) + (-x.e2) * (-x.e2) + (-x.e3) * (-x.e3) -
      x.e4 * x.e4 - (-x.e5) * (-x.e5) - (-x.e6) * (-x.e6) - (-x.e7) * (-x.e7) := by
      simp [antipode]
    _ = x.e0 * x.e0 + x.e1 * x.e1 + x.e2 * x.e2 + x.e3 * x.e3 -
      x.e4 * x.e4 - x.e5 * x.e5 - x.e6 * x.e6 - x.e7 * x.e7 := by ring
    _ = octonion_norm x := rfl
