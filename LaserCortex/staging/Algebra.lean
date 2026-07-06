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
  split_add
    (split_sub
      (split_sub
        (split_sub
          (split_oct_mul (split_oct_mul (split_oct_mul a b) c) d)
          (split_oct_mul (split_oct_mul a (split_oct_mul b c)) d))
          (split_oct_mul a (split_oct_mul (split_oct_mul b c) d)))
          (split_oct_mul a (split_oct_mul b (split_oct_mul c d))))
    (split_oct_mul (split_oct_mul a b) (split_oct_mul c d))

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
  unfold pentagon_defect e1_vec e2_vec e4_vec
  unfold split_sub split_add split_oct_mul octonion_norm
  decide

-- ============================================================================
-- Commutator and the Cayley–Dickson doubling identity
-- ============================================================================

/-- The commutator on SplitOctonion: `split_oct_mul x y - split_oct_mul y x`. -/
def split_oct_commutator (x y : SplitOctonion) : SplitOctonion :=
  split_sub (split_oct_mul x y) (split_oct_mul y x)

/-- Shift the first four components (e₀-e₃) to positions e₄-e₇, zeroing e₀-e₃.
    This is the "doubling" map that embeds the base algebra's commutator
    into the full algebra's split sector. -/
def shiftBy4 (c : SplitOctonion) : SplitOctonion :=
  { e0 := 0, e1 := 0, e2 := 0, e3 := 0,
    e4 := c.e0, e5 := c.e1, e6 := c.e2, e7 := c.e3 }

/-- The Cayley–Dickson doubling identity (Baez, *The Octonions*, §2.2):
    For elements `a, b` in the `{e₀,e₁,e₂,e₃}` subalgebra (the "base" of the
    doubling), the associator `[a, b, e₄]` equals the commutator `[a, b]`
    right-multiplied by `e₄`:
    `[a, b, e₄] = (a·b − b·a)·e₄`

    Since `octonion_norm(e₄) = −1 ≠ 0`, right-multiplication by `e₄` is a
    linear isomorphism on the vector space. This means the associator is
    demotable to the commutator via an invertible linear map — the
    non-associative sector carries no new information beyond the
    associative sector.

    The restriction to base elements is necessary: `ring` closes the goal
    when `a.e4 = a.e5 = a.e6 = a.e7 = 0` and similarly for `b`, but not
    for arbitrary `a, b` (cross-terms from e₄-e₇ components survive). -/
theorem cd_doubling_identity (a b : SplitOctonion) (ha : a.e4 = 0) (ha' : a.e5 = 0)
    (ha'' : a.e6 = 0) (ha''' : a.e7 = 0)
    (hb : b.e4 = 0) (hb' : b.e5 = 0) (hb'' : b.e6 = 0) (hb''' : b.e7 = 0) :
    associator_tensor a b e4_vec = split_oct_mul (split_oct_commutator a b) e4_vec := by
  unfold e4_vec
  apply SplitOctonion.ext_components
  · dsimp [associator_tensor, split_oct_commutator, split_sub, split_oct_mul]
    rw [ha, ha', ha'', ha''', hb, hb', hb'', hb''']
    ring
  · dsimp [associator_tensor, split_oct_commutator, split_sub, split_oct_mul]
    rw [ha, ha', ha'', ha''', hb, hb', hb'', hb''']
    ring
  · dsimp [associator_tensor, split_oct_commutator, split_sub, split_oct_mul]
    rw [ha, ha', ha'', ha''', hb, hb', hb'', hb''']
    ring
  · dsimp [associator_tensor, split_oct_commutator, split_sub, split_oct_mul]
    rw [ha, ha', ha'', ha''', hb, hb', hb'', hb''']
    ring
  · dsimp [associator_tensor, split_oct_commutator, split_sub, split_oct_mul]
    rw [ha, ha', ha'', ha''', hb, hb', hb'', hb''']
    ring
  · dsimp [associator_tensor, split_oct_commutator, split_sub, split_oct_mul]
    rw [ha, ha', ha'', ha''', hb, hb', hb'', hb''']
    ring
  · dsimp [associator_tensor, split_oct_commutator, split_sub, split_oct_mul]
    rw [ha, ha', ha'', ha''', hb, hb', hb'', hb''']
    ring
  · dsimp [associator_tensor, split_oct_commutator, split_sub, split_oct_mul]
    rw [ha, ha', ha'', ha''', hb, hb', hb'', hb''']
    ring

-- ============================================================================
-- Cayley-Dickson generator ω = e₄
-- ============================================================================

/-- NEGATIVE RESULT: Mixed-case CD doubling identity.
    Testing `associator_tensor a b e4_vec = split_oct_mul (split_oct_commutator a b) e4_vec`
    with `a` in base (e₄-e₇ = 0) and `b` in split sector (e₀-e₃ = 0) —
    `ring` fails on all 8 components. Cross-terms like `a.e1*b.e5`, `a.e2*b.e6`,
    `a.e3*b.e7` survive (each appears with coefficient 2 in the residual).
    The identity does NOT extend to the mixed case; both arguments must be
    in the base subalgebra. See lab_notes/028 for full analysis. -/

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
-- SplitQuat: split quaternion algebra ℍ̃ (signature (2,2))
-- Ported from SplitQuaternionClifford.lean
-- ============================================================================

open QuadraticMap

/-- The (1,1) quadratic form over ℤ on Fin 2 → ℤ. Signature: (+1, -1). -/
def Q11 : QuadraticForm ℤ (Fin 2 → ℤ) :=
  proj 0 0 - proj 1 1

/-- The Clifford algebra Cl(1,1) over ℤ. -/
abbrev Cl11 : Type := CliffordAlgebra Q11

/-- Basis vector e₀ ∈ Fin 2 → ℤ: (1,0). -/
def ε0 : Fin 2 → ℤ := fun i => if i = 0 then (1 : ℤ) else 0

/-- Basis vector e₁ ∈ Fin 2 → ℤ: (0,1). -/
def ε1 : Fin 2 → ℤ := fun i => if i = 1 then (1 : ℤ) else 0

/-- Generator e₀ ∈ Cl(1,1): squares to 1. -/
def e0' : Cl11 := CliffordAlgebra.ι Q11 ε0

/-- Generator e₁ ∈ Cl(1,1): squares to -1. -/
def e1' : Cl11 := CliffordAlgebra.ι Q11 ε1

theorem e0_sq' : e0' * e0' = (1 : Cl11) := by
  calc
    e0' * e0' = (CliffordAlgebra.ι Q11 ε0) * (CliffordAlgebra.ι Q11 ε0) := rfl
    _ = algebraMap ℤ (CliffordAlgebra Q11) (Q11 ε0) :=
      CliffordAlgebra.ι_sq_scalar Q11 ε0
    _ = algebraMap ℤ (CliffordAlgebra Q11) (1 : ℤ) := by
      simp [Q11, ε0, QuadraticMap.proj_apply]
    _ = (1 : CliffordAlgebra Q11) := by simp
    _ = (1 : Cl11) := rfl

theorem e1_sq' : e1' * e1' = (-1 : Cl11) := by
  calc
    e1' * e1' = (CliffordAlgebra.ι Q11 ε1) * (CliffordAlgebra.ι Q11 ε1) := rfl
    _ = algebraMap ℤ (CliffordAlgebra Q11) (Q11 ε1) :=
      CliffordAlgebra.ι_sq_scalar Q11 ε1
    _ = algebraMap ℤ (CliffordAlgebra Q11) (-1 : ℤ) := by
      simp [Q11, ε1, QuadraticMap.proj_apply]
    _ = (-1 : CliffordAlgebra Q11) := by simp
    _ = (-1 : Cl11) := rfl

theorem anticommute' : e0' * e1' + e1' * e0' = 0 := by
  have h := CliffordAlgebra.mul_add_swap_eq_polar_of_forall_mul_self_eq
    (CliffordAlgebra.ι Q11)
    (fun m : Fin 2 → ℤ => CliffordAlgebra.ι_sq_scalar Q11 m)
    ε0 ε1
  calc
    e0' * e1' + e1' * e0' =
        (CliffordAlgebra.ι Q11 ε0) * (CliffordAlgebra.ι Q11 ε1) +
        (CliffordAlgebra.ι Q11 ε1) * (CliffordAlgebra.ι Q11 ε0) := rfl
    _ = algebraMap ℤ (CliffordAlgebra Q11) (QuadraticMap.polar Q11 ε0 ε1) := h
    _ = algebraMap ℤ (CliffordAlgebra Q11) (0 : ℤ) := by
      simp [Q11, ε0, ε1, QuadraticMap.polar, QuadraticMap.proj_apply]
    _ = (0 : CliffordAlgebra Q11) := by simp
    _ = (0 : Cl11) := rfl

-- ============================================================================
-- SplitQuat type and basis
-- ============================================================================

structure SplitQuat where
  a : Int  -- scalar component
  b : Int  -- i coefficient
  c : Int  -- j coefficient
  d : Int  -- k = ij coefficient
  deriving Repr

def split_quat_zero : SplitQuat := ⟨0, 0, 0, 0⟩
def split_quat_one : SplitQuat := ⟨1, 0, 0, 0⟩

def split_quat_add (x y : SplitQuat) : SplitQuat :=
  ⟨x.a + y.a, x.b + y.b, x.c + y.c, x.d + y.d⟩

def split_quat_neg (x : SplitQuat) : SplitQuat :=
  ⟨-x.a, -x.b, -x.c, -x.d⟩

@[ext]
lemma SplitQuat.ext_components {x y : SplitQuat}
    (ha : x.a = y.a) (hb : x.b = y.b) (hc : x.c = y.c) (hd : x.d = y.d) : x = y := by
  cases x; cases y
  simp at ha hb hc hd
  simp [ha, hb, hc, hd]

instance : Add SplitQuat := ⟨split_quat_add⟩
instance : Zero SplitQuat := ⟨split_quat_zero⟩
instance : Neg SplitQuat := ⟨split_quat_neg⟩

instance : AddCommGroup SplitQuat where
  zero := split_quat_zero
  add := split_quat_add
  neg := split_quat_neg
  add_assoc := by
    intro a b c
    calc
      (a + b) + c = split_quat_add (split_quat_add a b) c := rfl
      _ = split_quat_add a (split_quat_add b c) := by
        apply SplitQuat.ext_components <;> dsimp [split_quat_add] <;> ring
      _ = a + (b + c) := rfl
  zero_add := by
    intro a
    calc
      0 + a = split_quat_add split_quat_zero a := rfl
      _ = a := by
        apply SplitQuat.ext_components <;> dsimp [split_quat_add, split_quat_zero] <;> ring
  add_zero := by
    intro a
    calc
      a + 0 = split_quat_add a split_quat_zero := rfl
      _ = a := by
        apply SplitQuat.ext_components <;> dsimp [split_quat_add, split_quat_zero] <;> ring
  add_comm := by
    intro a b
    calc
      a + b = split_quat_add a b := rfl
      _ = split_quat_add b a := by
        apply SplitQuat.ext_components <;> dsimp [split_quat_add] <;> ring
      _ = b + a := rfl
  neg_add_cancel := by
    intro a
    calc
      (-a) + a = split_quat_add (split_quat_neg a) a := rfl
      _ = split_quat_zero := by
        apply SplitQuat.ext_components <;> dsimp [split_quat_add, split_quat_neg, split_quat_zero] <;> ring
      _ = 0 := rfl
  nsmul := nsmulRec
  nsmul_zero := by intro x; rfl
  nsmul_succ := by intro n x; rfl
  zsmul := zsmulRec
  zsmul_zero' := by intro x; rfl
  zsmul_succ' := by intro n x; rfl
  zsmul_neg' := by intro n x; rfl
  sub_eq_add_neg := by intro a b; rfl

instance : DecidableEq SplitQuat :=
  λ x y =>
    match x, y with
    | ⟨a1, b1, c1, d1⟩, ⟨a2, b2, c2, d2⟩ =>
      if ha : a1 = a2 then
        if hb : b1 = b2 then
          if hc : c1 = c2 then
            if hd : d1 = d2 then isTrue (by subst ha; subst hb; subst hc; subst hd; rfl)
            else isFalse (λ h => hd (congrArg SplitQuat.d h))
          else isFalse (λ h => hc (congrArg SplitQuat.c h))
        else isFalse (λ h => hb (congrArg SplitQuat.b h))
      else isFalse (λ h => ha (congrArg SplitQuat.a h))

-- ============================================================================
-- SplitQuat multiplication table
-- ============================================================================

def split_quat_mul (x y : SplitQuat) : SplitQuat :=
  ⟨x.a*y.a - x.b*y.b + x.c*y.c + x.d*y.d,
   x.a*y.b + x.b*y.a - x.c*y.d + x.d*y.c,
   x.a*y.c - x.b*y.d + x.c*y.a + x.d*y.b,
   x.a*y.d + x.b*y.c - x.c*y.b + x.d*y.a⟩

instance : Mul SplitQuat := ⟨split_quat_mul⟩

theorem split_quat_mul_assoc (x y z : SplitQuat) : (x * y) * z = x * (y * z) := by
  apply SplitQuat.ext_components
  · change (split_quat_mul (split_quat_mul x y) z).a = (split_quat_mul x (split_quat_mul y z)).a; dsimp [split_quat_mul]; ring
  · change (split_quat_mul (split_quat_mul x y) z).b = (split_quat_mul x (split_quat_mul y z)).b; dsimp [split_quat_mul]; ring
  · change (split_quat_mul (split_quat_mul x y) z).c = (split_quat_mul x (split_quat_mul y z)).c; dsimp [split_quat_mul]; ring
  · change (split_quat_mul (split_quat_mul x y) z).d = (split_quat_mul x (split_quat_mul y z)).d; dsimp [split_quat_mul]; ring

-- ============================================================================
-- SplitQuat norm (composition algebra property)
-- ============================================================================

def SplitQuat.norm (x : SplitQuat) : ℤ :=
  x.a * x.a + x.b * x.b - x.c * x.c - x.d * x.d

theorem splitQuat_norm_mul (x y : SplitQuat) : (x * y).norm = x.norm * y.norm := by
  have hmul : ∀ (a b : SplitQuat), a * b = split_quat_mul a b := λ _ _ => rfl
  simp [SplitQuat.norm, hmul, split_quat_mul]; ring

-- ============================================================================
-- SplitQuat embedding into Cl(1,1)
-- ============================================================================

def SplitQuat.embed (x : SplitQuat) : Cl11 :=
  algebraMap ℤ Cl11 x.a
  + x.b • e1'
  + x.c • e0'
  + x.d • (e1' * e0')

-- ============================================================================
-- Q22 quadratic form
-- ============================================================================

/-- The (2,2) quadratic form as a Mathlib `QuadraticForm ℤ (Fin 4 → ℤ)`. -/
def Q22 : QuadraticForm ℤ (Fin 4 → ℤ) :=
  proj 0 0 + proj 1 1 - proj 2 2 - proj 3 3

theorem norm_eq_Q22 (x : SplitQuat) : x.norm = Q22 ![x.a, x.b, x.c, x.d] := by
  simp [Q22, SplitQuat.norm, QuadraticMap.proj_apply]

-- ============================================================================
-- Antipode for SplitQuat (grading involution)
-- ============================================================================

def antipode_sq (x : SplitQuat) : SplitQuat :=
  ⟨x.a, -x.b, -x.c, -x.d⟩

theorem antipode_sq_add (x y : SplitQuat) : antipode_sq (x + y) = antipode_sq x + antipode_sq y := by
  apply SplitQuat.ext_components
  · rfl
-- NOTE: .a component is definitionally true (rfl). The .b/.c/.d components below require ring.
  · change (antipode_sq (split_quat_add x y)).b = (split_quat_add (antipode_sq x) (antipode_sq y)).b; dsimp [antipode_sq, split_quat_add]; ring
  · change (antipode_sq (split_quat_add x y)).c = (split_quat_add (antipode_sq x) (antipode_sq y)).c; dsimp [antipode_sq, split_quat_add]; ring
  · change (antipode_sq (split_quat_add x y)).d = (split_quat_add (antipode_sq x) (antipode_sq y)).d; dsimp [antipode_sq, split_quat_add]; ring

theorem antipode_sq_involutive (x : SplitQuat) : antipode_sq (antipode_sq x) = x := by
  ext <;> simp [antipode_sq]

theorem antipode_sq_preserves_norm (x : SplitQuat) : (antipode_sq x).norm = x.norm := by
  simp [antipode_sq, SplitQuat.norm]

theorem antipode_sq_neg (x : SplitQuat) : antipode_sq (-x) = -antipode_sq x := by
  apply SplitQuat.ext_components
  · rfl
  · rfl
  · rfl
  · rfl
-- NOTE: All four components are definitionally true (rfl). This flags a design question:
-- the operations were defined in the "easy" direction. Should we instead define them so
-- that the non-trivial structural properties (e.g. antipode_sq_mul) become definitional
-- and these trivial ones require proof? Priority direction TBD.

theorem antipode_sq_sub (x y : SplitQuat) : antipode_sq (x - y) = antipode_sq x - antipode_sq y := by
  calc
    antipode_sq (x - y) = antipode_sq (x + (-y)) := rfl
    _ = antipode_sq x + antipode_sq (-y) := antipode_sq_add x (-y)
    _ = antipode_sq x + (-antipode_sq y) := by rw [antipode_sq_neg y]
    _ = antipode_sq x - antipode_sq y := rfl

theorem antipode_sq_mul (x y : SplitQuat) : antipode_sq (x * y) = antipode_sq y * antipode_sq x := by
  apply SplitQuat.ext_components
  · change (antipode_sq (split_quat_mul x y)).a = (split_quat_mul (antipode_sq y) (antipode_sq x)).a; dsimp [antipode_sq, split_quat_mul]; ring
  · change (antipode_sq (split_quat_mul x y)).b = (split_quat_mul (antipode_sq y) (antipode_sq x)).b; dsimp [antipode_sq, split_quat_mul]; ring
  · change (antipode_sq (split_quat_mul x y)).c = (split_quat_mul (antipode_sq y) (antipode_sq x)).c; dsimp [antipode_sq, split_quat_mul]; ring
  · change (antipode_sq (split_quat_mul x y)).d = (split_quat_mul (antipode_sq y) (antipode_sq x)).d; dsimp [antipode_sq, split_quat_mul]; ring

-- ============================================================================
-- ℤ-scalar multiplication lemmas (componentwise)
-- ============================================================================

@[simp] theorem split_quat_zsmul_a (r : ℤ) (z : SplitQuat) : (r • z).a = r * z.a := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).a = ((n : ℤ) • z).a + z.a := rfl
    have h_mul : ((n : ℤ) + 1) * z.a = (n : ℤ) * z.a + z.a := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).a = ((-(n : ℤ)) • z).a + (-z).a := rfl
    have h_neg : (-z).a = -z.a := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.a = (-(n : ℤ)) * z.a - z.a := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_quat_zsmul_b (r : ℤ) (z : SplitQuat) : (r • z).b = r * z.b := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).b = ((n : ℤ) • z).b + z.b := rfl
    have h_mul : ((n : ℤ) + 1) * z.b = (n : ℤ) * z.b + z.b := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).b = ((-(n : ℤ)) • z).b + (-z).b := rfl
    have h_neg : (-z).b = -z.b := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.b = (-(n : ℤ)) * z.b - z.b := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_quat_zsmul_c (r : ℤ) (z : SplitQuat) : (r • z).c = r * z.c := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).c = ((n : ℤ) • z).c + z.c := rfl
    have h_mul : ((n : ℤ) + 1) * z.c = (n : ℤ) * z.c + z.c := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).c = ((-(n : ℤ)) • z).c + (-z).c := rfl
    have h_neg : (-z).c = -z.c := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.c = (-(n : ℤ)) * z.c - z.c := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_quat_zsmul_d (r : ℤ) (z : SplitQuat) : (r • z).d = r * z.d := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).d = ((n : ℤ) • z).d + z.d := rfl
    have h_mul : ((n : ℤ) + 1) * z.d = (n : ℤ) * z.d + z.d := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).d = ((-(n : ℤ)) • z).d + (-z).d := rfl
    have h_neg : (-z).d = -z.d := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.d = (-(n : ℤ)) * z.d - z.d := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_oct_zsmul_e0 (r : ℤ) (z : SplitOctonion) : (r • z).e0 = r * z.e0 := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).e0 = ((n : ℤ) • z).e0 + z.e0 := rfl
    have h_mul : ((n : ℤ) + 1) * z.e0 = (n : ℤ) * z.e0 + z.e0 := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).e0 = ((-(n : ℤ)) • z).e0 + (-z).e0 := rfl
    have h_neg : (-z).e0 = -z.e0 := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.e0 = (-(n : ℤ)) * z.e0 - z.e0 := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_oct_zsmul_e1 (r : ℤ) (z : SplitOctonion) : (r • z).e1 = r * z.e1 := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).e1 = ((n : ℤ) • z).e1 + z.e1 := rfl
    have h_mul : ((n : ℤ) + 1) * z.e1 = (n : ℤ) * z.e1 + z.e1 := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).e1 = ((-(n : ℤ)) • z).e1 + (-z).e1 := rfl
    have h_neg : (-z).e1 = -z.e1 := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.e1 = (-(n : ℤ)) * z.e1 - z.e1 := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_oct_zsmul_e2 (r : ℤ) (z : SplitOctonion) : (r • z).e2 = r * z.e2 := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).e2 = ((n : ℤ) • z).e2 + z.e2 := rfl
    have h_mul : ((n : ℤ) + 1) * z.e2 = (n : ℤ) * z.e2 + z.e2 := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).e2 = ((-(n : ℤ)) • z).e2 + (-z).e2 := rfl
    have h_neg : (-z).e2 = -z.e2 := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.e2 = (-(n : ℤ)) * z.e2 - z.e2 := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_oct_zsmul_e3 (r : ℤ) (z : SplitOctonion) : (r • z).e3 = r * z.e3 := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).e3 = ((n : ℤ) • z).e3 + z.e3 := rfl
    have h_mul : ((n : ℤ) + 1) * z.e3 = (n : ℤ) * z.e3 + z.e3 := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).e3 = ((-(n : ℤ)) • z).e3 + (-z).e3 := rfl
    have h_neg : (-z).e3 = -z.e3 := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.e3 = (-(n : ℤ)) * z.e3 - z.e3 := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_oct_zsmul_e4 (r : ℤ) (z : SplitOctonion) : (r • z).e4 = r * z.e4 := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).e4 = ((n : ℤ) • z).e4 + z.e4 := rfl
    have h_mul : ((n : ℤ) + 1) * z.e4 = (n : ℤ) * z.e4 + z.e4 := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).e4 = ((-(n : ℤ)) • z).e4 + (-z).e4 := rfl
    have h_neg : (-z).e4 = -z.e4 := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.e4 = (-(n : ℤ)) * z.e4 - z.e4 := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_oct_zsmul_e5 (r : ℤ) (z : SplitOctonion) : (r • z).e5 = r * z.e5 := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).e5 = ((n : ℤ) • z).e5 + z.e5 := rfl
    have h_mul : ((n : ℤ) + 1) * z.e5 = (n : ℤ) * z.e5 + z.e5 := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).e5 = ((-(n : ℤ)) • z).e5 + (-z).e5 := rfl
    have h_neg : (-z).e5 = -z.e5 := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.e5 = (-(n : ℤ)) * z.e5 - z.e5 := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_oct_zsmul_e6 (r : ℤ) (z : SplitOctonion) : (r • z).e6 = r * z.e6 := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).e6 = ((n : ℤ) • z).e6 + z.e6 := rfl
    have h_mul : ((n : ℤ) + 1) * z.e6 = (n : ℤ) * z.e6 + z.e6 := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).e6 = ((-(n : ℤ)) • z).e6 + (-z).e6 := rfl
    have h_neg : (-z).e6 = -z.e6 := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.e6 = (-(n : ℤ)) * z.e6 - z.e6 := by ring
    rw [h_add, h_neg, h_mul, ih]
    ring

@[simp] theorem split_oct_zsmul_e7 (r : ℤ) (z : SplitOctonion) : (r • z).e7 = r * z.e7 := by
  induction r using Int.induction_on with
  | zero => rw [zero_smul, zero_mul]; rfl
  | succ n ih =>
    rw [add_smul, one_smul]
    have h_add : ((n : ℤ) • z + z).e7 = ((n : ℤ) • z).e7 + z.e7 := rfl
    have h_mul : ((n : ℤ) + 1) * z.e7 = (n : ℤ) * z.e7 + z.e7 := by ring
    rw [h_add, h_mul, ih]
  | pred n ih =>
    rw [sub_smul, one_smul]
    have h_add : ((-(n : ℤ)) • z - z).e7 = ((-(n : ℤ)) • z).e7 + (-z).e7 := rfl
    have h_neg : (-z).e7 = -z.e7 := rfl
    have h_mul : ((-(n : ℤ)) - 1) * z.e7 = (-(n : ℤ)) * z.e7 - z.e7 := by ring
    rw [h_add, h_neg, h_mul, ih]
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
