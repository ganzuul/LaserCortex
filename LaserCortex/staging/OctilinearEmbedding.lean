import Mathlib
import LaserCortex.staging.Algebra
import LaserCortex.staging.Tamari
import LaserCortex.staging.Friction

/-!
# Octilinear Embedding — Geometry of Trees in Cost Space

Coordinate embedding of Tamari trees into ℤ² via the KKT multiplier.
-/

-- ============================================================================
-- KKT Multiplier
-- ============================================================================

/--
The KKT multiplier λ_t ∈ SplitQuat for a tree `t` at CD step `cd`.

Components:
  a = t.size         — EVEN  (grade 0 scalar, +1 under involute)   → 90° coordinate
  b = leftWeight t   — ODD   (grade 1 vector, −1 under involute)  → 45° coordinate
  c = rightWeight t  — ODD   (grade 1 vector, −1 under involute)  → 45° coordinate
  d = assocDefect cd — EVEN  (grade 2 bivector, +1 under involute)→ 90° coordinate
-/
def kktMultiplier (cd : ℕ) (t : EMLTree) : SplitQuat :=
  ⟨ (t.size : ℤ)
  , (leftWeight t : ℤ)
  , (rightWeight t : ℤ)
  , (assocDefect cd : ℤ) ⟩

/--
The antipode (grading involution) of the KKT multiplier.
This is `antipode_sq` applied componentwise: negates the odd-grade
components (b, c) and fixes the even-grade ones (a, d).
-/
theorem kktMultiplier_antipode (cd : ℕ) (t : EMLTree) :
    antipode_sq (kktMultiplier cd t) = ⟨(t.size : ℤ), -(leftWeight t : ℤ), -(rightWeight t : ℤ), (assocDefect cd : ℤ)⟩ := by
  ext <;> simp [kktMultiplier, antipode_sq]

/--
The norm of the KKT multiplier equals the (2,2) determinant form:
  N(λ_t) = a² + b² − c² − d²
  where a = t.size, b = leftWeight t, c = rightWeight t, d = assocDefect cd
-/
theorem kktMultiplier_norm (cd : ℕ) (t : EMLTree) : (kktMultiplier cd t).norm =
    (t.size : ℤ)^2 + (leftWeight t : ℤ)^2 - (rightWeight t : ℤ)^2 - (assocDefect cd : ℤ)^2 := by
  simp [kktMultiplier, SplitQuat.norm]

-- ============================================================================
-- Covector Projection
-- ============================================================================

/--
Project a KKT multiplier λ_t ∈ SplitQuat to 2D covector coordinates (x, y).

The projection respects the antipode grading:
  - EVEN-grade components (a, d) → x-coordinate (axis-aligned, 90° edges)
  - ODD-grade components (b, c)  → y-coordinate (diagonal, 45° edges)

Formula:
  x = a + d   (even + even)
  y = b − c   (odd − odd)
-/
def covectorProjection (λ : SplitQuat) : ℤ × ℤ :=
  (λ.a + λ.d, λ.b - λ.c)

/--
The antipode (negating components b, c) flips the sign of the y-coordinate
while preserving the x-coordinate:
  P(S(λ)) = (x, -y) where (x, y) = P(λ)
-/
theorem covectorProjection_antipode (λ : SplitQuat) :
    covectorProjection (antipode_sq λ) = ((covectorProjection λ).1, -(covectorProjection λ).2) := by
  simp [covectorProjection, antipode_sq]

/--
The covector projection is ℤ-linear: P(λ₁ + λ₂) = P(λ₁) + P(λ₂).
-/
theorem covectorProjection_add (λ₁ λ₂ : SplitQuat) :
    covectorProjection (λ₁ + λ₂) = ((covectorProjection λ₁).1 + (covectorProjection λ₂).1,
                                    (covectorProjection λ₁).2 + (covectorProjection λ₂).2) := by
  simp [covectorProjection]

-- ============================================================================
-- Transit Map Coordinate
-- ============================================================================

/--
The transit map coordinate of a tree `t` at CD step `cd`.
Convenience function combining `kktMultiplier` and `covectorProjection`.

  tubeCoord cd t = (t.size + assocDefect cd, leftWeight t - rightWeight t)

The x-coordinate is the structural size of the tree plus the associator
defect at this CD step. The y-coordinate is the left/right branching
asymmetry: positive for left-biased trees, negative for right-biased.
-/
def tubeCoord (cd : ℕ) (t : EMLTree) : ℤ × ℤ :=
  covectorProjection (kktMultiplier cd t)

/--
Explicit expansion of `tubeCoord` in terms of tree primitives.
-/
theorem tubeCoord_expand (cd : ℕ) (t : EMLTree) :
    tubeCoord cd t = ((t.size : ℤ) + (assocDefect cd : ℤ), (leftWeight t : ℤ) - (rightWeight t : ℤ)) := by
  simp [tubeCoord, covectorProjection, kktMultiplier]

/--
The tube coordinate of the leaf tree at any CD step.
The leaf has size 0, leftWeight 0, rightWeight 0, so:
  tubeCoord cd Leaf = (assocDefect cd, 0)
-/
theorem tubeCoord_leaf (cd : ℕ) : tubeCoord cd (.Leaf : EMLTree) = ((assocDefect cd : ℤ), 0) := by
  simp [tubeCoord, covectorProjection, kktMultiplier, leftWeight, rightWeight, EMLTree.size]

/--
The tube coordinate of a singleton node (Node Leaf Leaf) at any CD step.
  tubeCoord cd (Node Leaf Leaf) = (1 + assocDefect cd, 0)
-/
theorem tubeCoord_node_leaf_leaf (cd : ℕ) : tubeCoord cd (EMLTree.Node .Leaf .Leaf) = ((1 : ℤ) + (assocDefect cd : ℤ), 0) := by
  simp [tubeCoord, covectorProjection, kktMultiplier, leftWeight, rightWeight, EMLTree.size]

/--
The tube coordinate of a right-comb tree of size n at CD step cd.
Right-comb trees have no left branching, so leftWeight = 0 and
rightWeight grows as the triangular number n(n-1)/2.
-/
theorem tubeCoord_rightComb (cd n : ℕ) : tubeCoord cd (rightComb n) =
    ((n : ℤ) + (assocDefect cd : ℤ), -(rightWeight (rightComb n) : ℤ)) := by
  induction n with
  | zero =>
    simp [tubeCoord, covectorProjection, kktMultiplier, rightComb, rightWeight, leftWeight, EMLTree.size]
  | succ n ih =>
    simp [tubeCoord, covectorProjection, kktMultiplier, rightComb, rightWeight, leftWeight, EMLTree.size, ih]

-- ============================================================================
-- Basic Properties
-- ============================================================================

/--
The tube coordinate of a tree depends on the CD step only through
the `assocDefect` term. For associative CD steps (cd ≤ 2), the coordinate
reduces to (t.size, leftWeight t - rightWeight t).
-/
theorem tubeCoord_assoc_step (cd : ℕ) (hcd : cd ≤ 2) (t : EMLTree) :
    tubeCoord cd t = ((t.size : ℤ), (leftWeight t : ℤ) - (rightWeight t : ℤ)) := by
  rw [tubeCoord_expand, assocDefect_zero_up_to_cd2 cd hcd]
  simp

/--
The tube coordinate at CD step 3 (non-associative regime) has an
extra `strut_weight` contribution to the x-coordinate, producing a
horizontal offset of +4 in the transit map relative to CD step 2.
-/
theorem tubeCoord_cd3_vs_cd2 (t : EMLTree) :
    (tubeCoord 3 t).1 = (tubeCoord 2 t).1 + (strut_weight : ℤ) := by
  rw [tubeCoord_expand, tubeCoord_expand]
  have h_sw : assocDefect 3 = strut_weight := assocDefect_positive_for_cd3plus 3 (by omega)
  have h_0 : assocDefect 2 = 0 := assocDefect_zero_up_to_cd2 2 (by omega)
  simp [h_sw, h_0]
  omega

/--
The difference in tube coordinates between two CD steps equals the
difference in their `assocDefect` values on the x-coordinate.
The y-coordinate is unchanged because it depends only on the tree
structure (leftWeight and rightWeight), not on the CD step.
-/
theorem tubeCoord_cd_diff (cd₁ cd₂ : ℕ) (t : EMLTree) :
    (tubeCoord cd₁ t).1 - (tubeCoord cd₂ t).1 = (assocDefect cd₁ : ℤ) - (assocDefect cd₂ : ℤ) := by
  rw [tubeCoord_expand, tubeCoord_expand]
  omega

/--
The tube coordinate x-component equals the tree's size plus the current
CD step's associator defect.
-/
theorem tubeCoord_x_eq_size_plus_assocDefect (cd : ℕ) (t : EMLTree) :
    (tubeCoord cd t).1 = (t.size : ℤ) + (assocDefect cd : ℤ) := by
  rw [tubeCoord_expand]; rfl

/--
The tube coordinate y-component equals the left/right branching asymmetry.
-/
theorem tubeCoord_y_eq_leftWeight_sub_rightWeight (cd : ℕ) (t : EMLTree) :
    (tubeCoord cd t).2 = (leftWeight t : ℤ) - (rightWeight t : ℤ) := by
  rw [tubeCoord_expand]; rfl

-- ============================================================================
-- Octonion KKT Multiplier (CD 3 extension)
-- ============================================================================

/--
The **octonion-valued KKT multiplier** λ^𝕆_t ∈ SplitOctonion, extending the
quaternion multiplier at CD step 3 (the split octonion layer).

Component placement in the octonion basis:

| Component | Octonion basis | Antipode parity | Tube map role |
|-----------|----------------|-----------------|---------------|
| t.size    | e0 (scalar)    | EVEN (fixed)    | → x-coordinate |
| leftWeight t | e1 (vector) | ODD (negated) | → y-coordinate (+) |
| rightWeight t | e2 (vector) | ODD (negated) | → y-coordinate (−) |
| assocDefect cd | e4 (bivector) | EVEN (fixed) | → x-coordinate |

The remaining basis vectors (e3, e5, e6, e7) are set to zero.
-/
def kktMultiplierOct (cd : ℕ) (t : EMLTree) : SplitOctonion :=
  ⟨ (t.size : ℤ)        -- e0: scalar (grade 0, EVEN)
  , (leftWeight t : ℤ)  -- e1: vector (grade 1, ODD)
  , (rightWeight t : ℤ) -- e2: vector (grade 1, ODD)
  , 0                   -- e3: unused (set to zero)
  , (assocDefect cd : ℤ) -- e4: split boundary (grade 2, EVEN)
  , 0                   -- e5: unused
  , 0                   -- e6: unused
  , 0                   -- e7: unused
  ⟩

/--
The octonion KKT multiplier extends the quaternion one: placing the
four KKT components into the quaternion subalgebra {e0, e1, e2, e4}
gives the same transit map coordinate as the SplitQuat version.
-/
theorem kktMultiplierOct_expand (cd : ℕ) (t : EMLTree) :
    kktMultiplierOct cd t = SplitOctonion.mk (t.size : ℤ) (leftWeight t : ℤ) (rightWeight t : ℤ)
      0 (assocDefect cd : ℤ) 0 0 0 := rfl

/--
The antipode acts on the octonion KKT multiplier by negating the odd-grade
components (e1, e2) while fixing the even-grade ones (e0, e4).
-/
theorem kktMultiplierOct_antipode (cd : ℕ) (t : EMLTree) :
    antipode (kktMultiplierOct cd t) =
    ⟨(t.size : ℤ), -(leftWeight t : ℤ), -(rightWeight t : ℤ), 0, (assocDefect cd : ℤ), 0, 0, 0⟩ := by
  simp [kktMultiplierOct, antipode]

/--
The octonion covector projection: maps λ ∈ SplitOctonion to 2D transit map
coordinates by separating even and odd antipode components.

Formula:
    P_oct(λ) = (λ.e0 + λ.e4, λ.e1 - λ.e2)
-/
def covectorProjectionOct (λ : SplitOctonion) : ℤ × ℤ :=
  (λ.e0 + λ.e4, λ.e1 - λ.e2)

/--
The antipode flips the sign of the y-coordinate while preserving x:

    P_oct(S(λ)) = (x, -y) where (x, y) = P_oct(λ)
-/
theorem covectorProjectionOct_antipode (λ : SplitOctonion) :
    covectorProjectionOct (antipode λ) = ((covectorProjectionOct λ).1, -(covectorProjectionOct λ).2) := by
  simp [covectorProjectionOct, antipode]

/--
The octonion covector projection is ℤ-linear:
    P_oct(λ₁ + λ₂) = P_oct(λ₁) + P_oct(λ₂)
-/
theorem covectorProjectionOct_add (λ₁ λ₂ : SplitOctonion) :
    covectorProjectionOct (λ₁ + λ₂) = ((covectorProjectionOct λ₁).1 + (covectorProjectionOct λ₂).1,
                                        (covectorProjectionOct λ₁).2 + (covectorProjectionOct λ₂).2) := by
  simp [covectorProjectionOct]

/--
The **octonion transit map coordinate**: composes the octonion KKT multiplier
with the octonion covector projection.

    tubeCoordOct cd t = (t.size + assocDefect cd, leftWeight t - rightWeight t)

This is the SAME formula as `tubeCoord cd t` — the octonion extension does
not change the 2D layout of the transit map.
-/
def tubeCoordOct (cd : ℕ) (t : EMLTree) : ℤ × ℤ :=
  covectorProjectionOct (kktMultiplierOct cd t)

/--
The octonion tube coordinate equals the quaternion tube coordinate for
all CD steps:

    tubeCoordOct cd t = tubeCoord cd t

This proves the octonion extension is backward-compatible with the
existing transit map layout.
-/
theorem tubeCoordOct_eq_tubeCoord (cd : ℕ) (t : EMLTree) : tubeCoordOct cd t = tubeCoord cd t := by
  simp [tubeCoordOct, kktMultiplierOct, covectorProjectionOct,
    tubeCoord, covectorProjection, kktMultiplier]

/--
Explicit expansion of the octonion tube coordinate in terms of tree
primitives.
-/
theorem tubeCoordOct_expand (cd : ℕ) (t : EMLTree) :
    tubeCoordOct cd t = ((t.size : ℤ) + (assocDefect cd : ℤ), (leftWeight t : ℤ) - (rightWeight t : ℤ)) := by
  simp [tubeCoordOct, kktMultiplierOct, covectorProjectionOct]

/--
The **octonion pairing self-evaluation** of the KKT multiplier:

    β(λ^𝕆_t, λ^𝕆_t) = size² + leftWeight² + rightWeight² + assocDefect²

This is the (4,4) norm signature shift: at CD ≤ 2, `assocDefect = 0`
and the (2,2) quaternion norm applies; at CD ≥ 3, `assocDefect = 4`
and the octonion pairing becomes fully nondegenerate.
-/
theorem kktMultiplierOct_pairing_self (cd : ℕ) (t : EMLTree) :
    (kktMultiplierOct cd t).e0 * (kktMultiplierOct cd t).e0
    + (kktMultiplierOct cd t).e1 * (kktMultiplierOct cd t).e1
    + (kktMultiplierOct cd t).e2 * (kktMultiplierOct cd t).e2
    + (kktMultiplierOct cd t).e3 * (kktMultiplierOct cd t).e3
    + (kktMultiplierOct cd t).e4 * (kktMultiplierOct cd t).e4
    - (kktMultiplierOct cd t).e5 * (kktMultiplierOct cd t).e5
    - (kktMultiplierOct cd t).e6 * (kktMultiplierOct cd t).e6
    - (kktMultiplierOct cd t).e7 * (kktMultiplierOct cd t).e7
    = (t.size : ℤ)^2 + (leftWeight t : ℤ)^2 + (rightWeight t : ℤ)^2 + (assocDefect cd : ℤ)^2 := by
  simp [kktMultiplierOct]

/--
The **antipode self-pairing** of the KKT multiplier:

    β(S(λ^𝕆_t), λ^𝕆_t) = size² − leftWeight² − rightWeight² + assocDefect²
-/
theorem kktMultiplierOct_antipode_pairing_self (cd : ℕ) (t : EMLTree) :
    (antipode (kktMultiplierOct cd t)).e0 * (kktMultiplierOct cd t).e0
    + (antipode (kktMultiplierOct cd t)).e1 * (kktMultiplierOct cd t).e1
    + (antipode (kktMultiplierOct cd t)).e2 * (kktMultiplierOct cd t).e2
    + (antipode (kktMultiplierOct cd t)).e3 * (kktMultiplierOct cd t).e3
    + (antipode (kktMultiplierOct cd t)).e4 * (kktMultiplierOct cd t).e4
    - (antipode (kktMultiplierOct cd t)).e5 * (kktMultiplierOct cd t).e5
    - (antipode (kktMultiplierOct cd t)).e6 * (kktMultiplierOct cd t).e6
    - (antipode (kktMultiplierOct cd t)).e7 * (kktMultiplierOct cd t).e7
    = (t.size : ℤ)^2 - (leftWeight t : ℤ)^2 - (rightWeight t : ℤ)^2 + (assocDefect cd : ℤ)^2 := by
  simp [kktMultiplierOct, antipode]

/--
**Phase change signature**: The octonion antipode self-pairing at CD 3
has a DIFFERENT sign pattern from the quaternion norm at CD ≤ 2.

| Term | Quat norm (CD ≤ 2) | Oct antipode pairing (CD ≥ 3) |
|------|-------------------|-------------------------------|
| size² | + | + |
| leftWeight² | + | − |
| rightWeight² | − | − |
| assocDefect² | − (0 when ≤2) | + (4² = 16 when ≥3) |

This sign pattern directly manifests the (2,2) → (4,4) phase transition.
-/
theorem pairing_signature_phase_change (cd : ℕ) (hcd : 3 ≤ cd) (t : EMLTree) :
    ((kktMultiplierOct cd t).e0^2 - (kktMultiplierOct cd t).e1^2 - (kktMultiplierOct cd t).e2^2
      + (kktMultiplierOct cd t).e4^2)
    - ((t.size : ℤ)^2 + (leftWeight t : ℤ)^2 - (rightWeight t : ℤ)^2 - (assocDefect cd : ℤ)^2)
    = -2*(leftWeight t : ℤ)^2 + 2*(assocDefect cd : ℤ)^2 := by
  have ha : assocDefect cd = strut_weight := assocDefect_positive_for_cd3plus cd hcd
  simp [kktMultiplierOct, antipode, ha, strut_weight_eq_four]

/--
**Unpacking the KKT multiplier at CD 3**: The octonion KKT multiplier
converted to the antipode pairing equals the sum of even-grade squared
terms minus the odd-grade squared terms. This is the (4,4) norm signature
shift.
-/
theorem cd3_nonassociative_signature (t : EMLTree) :
    (kktMultiplierOct 3 t).e0^2 - (kktMultiplierOct 3 t).e1^2 - (kktMultiplierOct 3 t).e2^2
    + (kktMultiplierOct 3 t).e4^2
    = (t.size : ℤ)^2 - (leftWeight t : ℤ)^2 - (rightWeight t : ℤ)^2 + 16 := by
  have h_sw : assocDefect 3 = strut_weight := assocDefect_positive_for_cd3plus 3 (by omega)
  have h_sw4 : strut_weight = 4 := strut_weight_eq_four
  simp [kktMultiplierOct, h_sw, h_sw4]
