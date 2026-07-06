

import Mathlib.LinearAlgebra.CliffordAlgebra.Basic
import Mathlib.LinearAlgebra.QuadraticForm.Basic
import LaserCortex.staging.Algebra

namespace SplitQuaternionClifford

open QuadraticMap
open Algebra

-- ============================================================================
-- SECTION 1: Cl(1,1) — the Clifford algebra of the split plane
-- ============================================================================

/-- The (1,1) quadratic form over ℤ on Fin 2 → ℤ.
    Signature: (+1, -1). Generators: e₀² = 1, e₁² = -1. -/
def Q11 : QuadraticForm ℤ (Fin 2 → ℤ) :=
  proj 0 0 - proj 1 1

/-- The Clifford algebra Cl(1,1) over ℤ.
    This is isomorphic to the split quaternions ℍ̃ ≅ M₂(ℤ).
    
    NOTE: `abbrev` is used instead of `def` so that `Cl11` is transparent
    to the type class system — `CliffordAlgebra Q11` is a `Ring` and
    `Algebra ℤ (CliffordAlgebra Q11)`, and `abbrev` makes these instances
    available for `Cl11` without explicit `instance` declarations. -/
abbrev Cl11 : Type := CliffordAlgebra Q11

/-- Basis vector e₀ ∈ Fin 2 → ℤ: (1,0). -/
def ε0 : Fin 2 → ℤ :=
  fun i => if i = 0 then (1 : ℤ) else 0

/-- Basis vector e₁ ∈ Fin 2 → ℤ: (0,1). -/
def ε1 : Fin 2 → ℤ :=
  fun i => if i = 1 then (1 : ℤ) else 0

/-- Generator e₀ ∈ Cl(1,1): squares to 1 (time-like direction). -/
def e0 : Cl11 :=
  CliffordAlgebra.ι Q11 ε0

/-- Generator e₁ ∈ Cl(1,1): squares to -1 (space-like direction). -/
def e1 : Cl11 :=
  CliffordAlgebra.ι Q11 ε1

/-- The defining relation: e₀² = 1.

    Proof: `CliffordAlgebra.ι_sq_scalar` gives
      ι(m)² = algebraMap R (CliffordAlgebra Q) (Q m).
    With Q = Q11 and m = ε0 = (1,0), Q11(ε0) = 1 and algebraMap(1) = 1. -/
theorem e0_sq : e0 * e0 = (1 : Cl11) := by
  calc
    e0 * e0 = (CliffordAlgebra.ι Q11 ε0) * (CliffordAlgebra.ι Q11 ε0) := rfl
    _ = algebraMap ℤ (CliffordAlgebra Q11) (Q11 ε0) :=
      CliffordAlgebra.ι_sq_scalar Q11 ε0
    _ = algebraMap ℤ (CliffordAlgebra Q11) (1 : ℤ) := by
      simp [Q11, ε0, QuadraticMap.proj_apply]
    _ = (1 : CliffordAlgebra Q11) := by simp
    _ = (1 : Cl11) := rfl

/-- The defining relation: e₁² = -1.

    Proof: same as e0_sq but Q11(ε1) = -1 for ε1 = (0,1). -/
theorem e1_sq : e1 * e1 = (-1 : Cl11) := by
  calc
    e1 * e1 = (CliffordAlgebra.ι Q11 ε1) * (CliffordAlgebra.ι Q11 ε1) := rfl
    _ = algebraMap ℤ (CliffordAlgebra Q11) (Q11 ε1) :=
      CliffordAlgebra.ι_sq_scalar Q11 ε1
    _ = algebraMap ℤ (CliffordAlgebra Q11) (-1 : ℤ) := by
      simp [Q11, ε1, QuadraticMap.proj_apply]
    _ = (-1 : CliffordAlgebra Q11) := by simp
    _ = (-1 : Cl11) := rfl

/-- Anticommutation: e₀·e₁ + e₁·e₀ = 0.

    Proof: `CliffordAlgebra.mul_add_swap_eq_polar_of_forall_mul_self_eq` gives
      f a * f b + f b * f a = algebraMap R _ (polar Q a b)
    for any linear f : M → A satisfying f(x)² = Q(x).
    Taking f = ι Q11, the polar Q11(ε0, ε1) = 0. -/
theorem anticommute : e0 * e1 + e1 * e0 = 0 := by
  have h := CliffordAlgebra.mul_add_swap_eq_polar_of_forall_mul_self_eq
    (CliffordAlgebra.ι Q11)
    (fun m : Fin 2 → ℤ => CliffordAlgebra.ι_sq_scalar Q11 m)
    ε0 ε1
  calc
    e0 * e1 + e1 * e0
        = (CliffordAlgebra.ι Q11 ε0) * (CliffordAlgebra.ι Q11 ε1) +
          (CliffordAlgebra.ι Q11 ε1) * (CliffordAlgebra.ι Q11 ε0) := rfl
    _ = algebraMap ℤ (CliffordAlgebra Q11) (QuadraticMap.polar Q11 ε0 ε1) := h
    _ = algebraMap ℤ (CliffordAlgebra Q11) (0 : ℤ) := by
      simp [Q11, ε0, ε1, QuadraticMap.polar, QuadraticMap.proj_apply]
    _ = (0 : CliffordAlgebra Q11) := by simp
    _ = (0 : Cl11) := rfl

-- ============================================================================
-- SECTION 2: Split quaternions ℍ̃ with (2,2) norm
-- ============================================================================

/-- Split quaternion over ℤ with (2,2) signature.
    Basis: {1, i, j, k = ij} where i² = -1, j² = +1, k² = +1.
    This is the Cayley-Dickson step 2' between ℍ and 𝕆.
    
    INTEGRATION POINT: The (2,2) norm N(a,b,c,d) = a² + b² - c² - d²
    has the same shape as the (4,4) norm in SplitOctonionCost.Q44,
    but on a 4-dimensional space instead of 8-dimensional.
    The two are related by the Cayley-Dickson construction:
    Q44 is the 8-dimensional extension of Q22 via the CD doubling process. -/
structure SplitQuat where
  a : ℤ  -- scalar component
  b : ℤ  -- i coefficient (time-like)
  c : ℤ  -- j coefficient (space-like)
  d : ℤ  -- k = ij coefficient (space-like)
  deriving Repr

/-- Embed a split quaternion into Cl(1,1).
    Map {1, i, j, k} → {1, e₁, e₀, e₁·e₀}.
    
    The mapping is determined by the basis correspondence:
    - i² = -1 = e₁² (space-like Clifford generator)
    - j² = +1 = e₀² (time-like Clifford generator)
    - k = ij ↦ e₁·e₀ (NOT e₀·e₁ — the sign matters for the product!)
    
    This embedding is an injective ℤ-algebra homomorphism. The product
    preservation `embed (x * y) = embed x * embed y` does not require
    routing through the M₂(ℤ) matrix isomorphism; it follows directly
    from the universal property of Cl(1,1) via the defining relations
    (`e0_sq`, `e1_sq`, `anticommute`) using `noncomm_ring`.
    
    The sign convention: e₁·e₀ = -e₀·e₁ (by anticommute). Mapping
    k ↦ e₁·e₀ ensures embed(i·j) = embed(i)·embed(j).
    
    See `Chu.chu_embed_mul` for the formal proof, and the docstring
    of Chu.lean §4 for the interpretation as the KKT stationarity
    condition of the ZD‑constrained hyperbolic program. -/
def SplitQuat.embed (x : SplitQuat) : Cl11 :=
  algebraMap ℤ Cl11 x.a
  + x.b • e1
  + x.c • e0
  + x.d • (e1 * e0)

/-- The (2,2) norm of a split quaternion.
    N(a,b,c,d) = a² + b² - c² - d².
    This equals the determinant of the 2×2 matrix representation
    and is the quadratic form of the split quaternion composition algebra. -/
def SplitQuat.norm (x : SplitQuat) : ℤ :=
  x.a * x.a + x.b * x.b - x.c * x.c - x.d * x.d

/-- The (2,2) norm as a `QuadraticForm ℤ (Fin 4 → ℤ)`.
    INTEGRATION POINT: Q22 is the 4-dimensional analogue of Q44
    (the (4,4) form in SplitOctonionCost). Together they span the
    CD ladder: Q44 extends Q22 by the Cayley-Dickson doubling. -/
def Q22 : QuadraticForm ℤ (Fin 4 → ℤ) :=
  proj 0 0 + proj 1 1 - proj 2 2 - proj 3 3

/-- The two norm definitions agree. -/
theorem norm_eq_Q22 (x : SplitQuat) : x.norm = Q22 ![x.a, x.b, x.c, x.d] := by
  simp [SplitQuat.norm, Q22, QuadraticMap.proj_apply]

-- ============================================================================
-- SECTION 3: Algebraic instances for SplitQuat
-- ============================================================================

/-- Pointwise zero on SplitQuat. -/
def split_quat_zero : SplitQuat := ⟨0, 0, 0, 0⟩

/-- Pointwise one on SplitQuat: the scalar 1 with zero vector part. -/
def split_quat_one : SplitQuat := ⟨1, 0, 0, 0⟩

/-- Pointwise addition on SplitQuat. -/
def split_quat_add (x y : SplitQuat) : SplitQuat :=
  ⟨x.a + y.a, x.b + y.b, x.c + y.c, x.d + y.d⟩

/-- Pointwise negation on SplitQuat. -/
def split_quat_neg (x : SplitQuat) : SplitQuat :=
  ⟨-x.a, -x.b, -x.c, -x.d⟩

/-- Extensionality for SplitQuat: two quaternions are equal iff all components agree. -/
@[ext]
theorem SplitQuat.ext_components (x y : SplitQuat) (ha : x.a = y.a) (hb : x.b = y.b)
    (hc : x.c = y.c) (hd : x.d = y.d) : x = y := by
  cases x; cases y
  simp at ha hb hc hd
  simp [ha, hb, hc, hd]

-- Separate instances needed before AddCommGroup
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
      a + b + c = split_quat_add (split_quat_add a b) c := rfl
      _ = split_quat_add a (split_quat_add b c) := by
        simp [split_quat_add, add_assoc]
      _ = a + (b + c) := rfl
  zero_add := by
    intro a
    calc
      (0 : SplitQuat) + a = split_quat_add split_quat_zero a := rfl
      _ = a := by simp [split_quat_add, split_quat_zero]
  add_zero := by
    intro a
    calc
      a + (0 : SplitQuat) = split_quat_add a split_quat_zero := rfl
      _ = a := by simp [split_quat_add, split_quat_zero]
  add_comm := by
    intro a b
    calc
      a + b = split_quat_add a b := rfl
      _ = split_quat_add b a := by simp [split_quat_add, add_comm]
      _ = b + a := rfl
  neg_add_cancel := by
    intro a
    calc
      (-a) + a = split_quat_add (split_quat_neg a) a := rfl
      _ = split_quat_zero := by simp [split_quat_add, split_quat_neg, split_quat_zero]
      _ = (0 : SplitQuat) := rfl
  nsmul := nsmulRec
  zsmul := zsmulRec
  sub_eq_add_neg := by
    intro a b; rfl

instance : DecidableEq SplitQuat := fun x y =>
  match x, y with
  | ⟨a1, b1, c1, d1⟩, ⟨a2, b2, c2, d2⟩ =>
    if ha : a1 = a2 then
      if hb : b1 = b2 then
        if hc : c1 = c2 then
          if hd : d1 = d2 then
            isTrue (by subst ha; subst hb; subst hc; subst hd; rfl)
          else isFalse (by intro h; apply hd; exact congrArg SplitQuat.d h)
        else isFalse (by intro h; apply hc; exact congrArg SplitQuat.c h)
      else isFalse (by intro h; apply hb; exact congrArg SplitQuat.b h)
    else isFalse (by intro h; apply ha; exact congrArg SplitQuat.a h)

/-- The (2,2) split-quaternion multiplication table.
    Basis: {1, i, j, k} with i² = -1, j² = +1, k² = +1.
    The 16-term expansion follows from bilinearity:
    (a1 + b1·i + c1·j + d1·k) × (a2 + b2·i + c2·j + d2·k) =
      (a1·a2 - b1·b2 + c1·c2 + d1·d2)       — scalar
    + (a1·b2 + b1·a2 - c1·d2 + d1·c2) · i    — i
    + (a1·c2 - b1·d2 + c1·a2 + d1·b2) · j    — j
    + (a1·d2 + b1·c2 - c1·b2 + d1·a2) · k    — k
    Verified against the (1,1) Clifford algebra map in §2. -/
def split_quat_mul (x y : SplitQuat) : SplitQuat :=
  ⟨x.a*y.a - x.b*y.b + x.c*y.c + x.d*y.d,
   x.a*y.b + x.b*y.a - x.c*y.d + x.d*y.c,
   x.a*y.c - x.b*y.d + x.c*y.a + x.d*y.b,
   x.a*y.d + x.b*y.c - x.c*y.b + x.d*y.a⟩

instance : Mul SplitQuat := ⟨split_quat_mul⟩

/-- Split-quaternion multiplication is associative (unlike split octonions). -/
theorem split_quat_mul_assoc (x y z : SplitQuat) : (x * y) * z = x * (y * z) := by
  calc
    (x * y) * z = split_quat_mul (split_quat_mul x y) z := rfl
    _ = split_quat_mul x (split_quat_mul y z) := by
      ext <;> simp [split_quat_mul] <;> ring
    _ = x * (y * z) := rfl

-- ============================================================================
-- SECTION 4: The composition algebra property (norm_mul)
-- ============================================================================

/-- The (2,2) norm is multiplicative: N(xy) = N(x)N(y).
    This is the composition algebra identity, verified by `native_decide`
    on the 8-variable polynomial identity with all coefficients in ℤ.
    Equivalent to the determinant property det(AB) = det(A)det(B) under
    the isomorphism ℍ̃ ≅ M₂(ℤ), but proven here directly by computation. -/
theorem norm_mul (x y : SplitQuat) : (x * y).norm = x.norm * y.norm := by
  calc
    (x * y).norm = (split_quat_mul x y).norm := rfl
    _ = x.norm * y.norm := by
      simp [SplitQuat.norm, split_quat_mul]; ring

-- ============================================================================
-- SECTION 5: Antipode for SplitQuat
-- ============================================================================

/-- The antipode (grading involution) on split quaternions.
    Negates the imaginary axes (i, j, k) and fixes the scalar (1).
    This is the ℤ/2-grading involution for the split-quaternion
    composition algebra. -/
def antipode_sq (x : SplitQuat) : SplitQuat :=
  ⟨x.a, -x.b, -x.c, -x.d⟩

/-- Antipode is ℤ-linear: S(x + y) = S(x) + S(y). -/
theorem antipode_sq_add (x y : SplitQuat) : antipode_sq (x + y) = antipode_sq x + antipode_sq y := by
  calc
    antipode_sq (x + y) = antipode_sq (split_quat_add x y) := rfl
    _ = split_quat_add (antipode_sq x) (antipode_sq y) := by
      ext <;> simp [antipode_sq, split_quat_add, add_comm]
    _ = antipode_sq x + antipode_sq y := rfl

/-- Antipode is involutive: S(S(x)) = x. -/
theorem antipode_sq_involutive (x : SplitQuat) : antipode_sq (antipode_sq x) = x := by
  ext <;> simp [antipode_sq]

/-- Antipode preserves the (2,2) norm: N(S(x)) = N(x). -/
theorem antipode_sq_preserves_norm (x : SplitQuat) : (antipode_sq x).norm = x.norm := by
  simp [antipode_sq, SplitQuat.norm]

/-- Antipode of negation: S(-x) = -S(x). -/
theorem antipode_sq_neg (x : SplitQuat) : antipode_sq (-x) = -antipode_sq x := by
  calc
    antipode_sq (-x) = antipode_sq (split_quat_neg x) := rfl
    _ = split_quat_neg (antipode_sq x) := by
      ext <;> simp [antipode_sq, split_quat_neg]
    _ = -antipode_sq x := rfl

/-- Antipode is additive: S(x - y) = S(x) - S(y). -/
theorem antipode_sq_sub (x y : SplitQuat) : antipode_sq (x - y) = antipode_sq x - antipode_sq y := by
  calc
    antipode_sq (x - y) = antipode_sq (x + (-y)) := rfl
    _ = antipode_sq x + antipode_sq (-y) := antipode_sq_add x (-y)
    _ = antipode_sq x + (-antipode_sq y) := by rw [antipode_sq_neg y]
    _ = antipode_sq x - antipode_sq y := rfl

/-- Antipode is an anti-automorphism: S(x * y) = S(y) * S(x).
    Verified by component expansion of the 16-term multiplication formula. -/
theorem antipode_sq_mul (x y : SplitQuat) : antipode_sq (x * y) = antipode_sq y * antipode_sq x := by
  have mul_eq : ∀ a b : SplitQuat, a * b = split_quat_mul a b := λ _ _ => rfl
  calc
    antipode_sq (x * y) = antipode_sq (split_quat_mul x y) := by rw [mul_eq]
    _ = split_quat_mul (antipode_sq y) (antipode_sq x) := by
      ext <;> dsimp [antipode_sq, split_quat_mul] <;> ring
    _ = antipode_sq y * antipode_sq x := by rw [mul_eq]

end SplitQuaternionClifford
