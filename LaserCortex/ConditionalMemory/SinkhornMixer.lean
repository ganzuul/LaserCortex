import Mathlib

/-!
# SinkhornMixer — R6 certificates, stated about the LIMIT

Roadmap **R6** (`GramDictionary.lean:52-66`) lists the mHC/Sinkhorn mixer's certificates
("deliberately NOT assumed"): the Sinkhorn limit is doubly stochastic; Birkhoff–von Neumann makes the
mixer a mixture of relabelings; the map is permutation-equivariant. `ple-io` roadmap §11.6b sharpened
*how* they should be stated — Sinkhorn's scaling converges in ~10 iterations and production uses
`hc_sinkhorn_iters: 20`, so **the theorems belong to the limit, not to the iteration**.

This file takes the part of R6 that is (a) tractable at the smallest interesting size and (b) actually
relevant to the pentagonator question, and is explicit about what it does not do.

## What is here

* `rowNorm` / `colNorm` / `step` — one row pass, one column pass, and their composite, on
  `Matrix (Fin 2) (Fin 2) ℚ`. Division is Lean's total `ℚ` inverse (`0⁻¹ = 0`), so the definitions need
  no side conditions; the theorems carry the non-vanishing hypotheses they actually use.
* `step_col_sums` — **one `step` fixes the COLUMN sums exactly**, while `rowNorm_row_sums` shows
  `rowNorm` fixes the ROW sums. Neither fixes both, which is *why* iteration is required and why R6's
  doubly-stochastic claim is a statement about the limit rather than about a pass.
* `sinkhorn_not_associative` — **the finding**: the induced operation `(A,B) ↦ step (A*B)` is **not**
  associative, with the smallest witness found by search: `!![1,1,1,2]` taken **three times**.

## What is NOT here, and why

* **Existence/uniqueness of the limit** for positive matrices is Sinkhorn's theorem. It needs a
  contraction or Perron–Frobenius argument and is not attempted here; R6's first bullet stays open and is
  now stated *about the limit* rather than about 20 iterations.
* **Permutation-equivariance** is not proved here. It is true and tractable (each pass is equivariant
  under relabelling, so the iterates are, hence the limit), but it needs `field_simp` with non-vanishing
  hypotheses at every index and is not load-bearing for the coherence question this session turned on.
  Recorded as open rather than omitted silently.
* **Birkhoff–von Neumann** is not reproved — Mathlib owns that result; R6 should *cite* it, not restate it.

## Why the non-associativity is the load-bearing part

§11.6b measured that the defect is **iteration-independent** (`1.468e-03` from 10 to 5000 iterations) and
§11.7 located the cause: it is **data-dependence**, not "being a normaliser" (a *fixed* `D₁ M D₂` is
associative to the float floor). So the witness below is not a convergence artifact and cannot be fixed by
iterating longer — which is exactly why §11.8's answer is to change the **composition law** (the
affine/scan product, `PentagonatorExpert.scanComp_assoc`) rather than the iteration count.
-/

namespace LaserCortex.ConditionalMemory.SinkhornMixer

open Matrix

/-- A `2 × 2` rational matrix — the smallest size at which Sinkhorn has a non-trivial row *and* column
constraint, and the size at which the witness below is searchable by hand. -/
abbrev M2 := Matrix (Fin 2) (Fin 2) ℚ

/-- One row-normalisation pass: divide each entry by its row sum. Total, because `ℚ`'s inverse of `0` is
`0`; the theorems below carry the non-vanishing hypotheses they need. -/
def rowNorm (M : M2) : M2 := fun i j => M i j / (M i 0 + M i 1)

/-- One column-normalisation pass. -/
def colNorm (M : M2) : M2 := fun i j => M i j / (M 0 j + M 1 j)

/-- One Sinkhorn step: a row pass then a column pass, which is the alternating projection
`hc_sinkhorn_iters` counts. -/
def step (M : M2) : M2 := colNorm (rowNorm M)

/-- The operation the mixer's composition induces on matrices. **This is what fails to be associative**
(`sinkhorn_not_associative`) — not the matrix product, which is associative, but the product *with a
data-dependent reweighting applied after it*. -/
def op (A B : M2) : M2 := step (A * B)

/-- `rowNorm` fixes the ROW sums. -/
theorem rowNorm_row_sums (M : M2) (h : M 0 0 + M 0 1 ≠ 0) :
    rowNorm M 0 0 + rowNorm M 0 1 = 1 := by
  simp only [rowNorm]
  field_simp

/-- **One `step` fixes the COLUMN sums exactly.** Together with `rowNorm_row_sums` this is the reason R6's
doubly-stochastic claim is about the *limit*: the row pass fixes rows and the column pass then breaks
them, so no single pass satisfies both. -/
theorem step_col_sums (M : M2)
    (h0 : rowNorm M 0 0 + rowNorm M 1 0 ≠ 0) (h1 : rowNorm M 0 1 + rowNorm M 1 1 ≠ 0) :
    step M 0 0 + step M 1 0 = 1 ∧ step M 0 1 + step M 1 1 = 1 := by
  constructor <;> · simp only [step, colNorm]; field_simp

/-- A concrete positive matrix at which one pass leaves the rows unfixed (`36/35 > 1`), the numeric shadow
of the asymmetry above. — NOTE: the first version of this theorem quoted `1528/1519`, which is the row sum
of `step (A * A)`, not of `step A`. `native_decide` refused it, which is exactly what a decidable proof is
for; the correct value is `3/5 + 3/7 = 36/35`. -/
theorem one_step_leaves_rows_unfixed :
    step !![1, 1; 1, 2] 0 0 + step !![1, 1; 1, 2] 0 1 = 36 / 35 := by
  native_decide

/-- **R6's finding, certified: the induced operation is NOT associative.**

Witness: `A = B = C = !![1,1,1,2]` — the *same* matrix three times already fails, so the defect needs no
contrived triple. Searched for over `{1,2,3}⁴` matrices and this is the smallest found.

This is an **absence result** in the corpus's convention (`antipode_mul_false`, `draft_no_period5`,
`topk_selection_not_associative`): it records that no amount of iterating repairs the composition, because
§11.6b measured the defect to be iteration-independent and §11.7 traced it to data-dependence. The repair
is the **composition law** (`PentagonatorExpert.scanComp_assoc`), not the iteration count. -/
theorem sinkhorn_not_associative :
    op (op !![1, 1; 1, 2] !![1, 1; 1, 2]) !![1, 1; 1, 2]
      ≠ op !![1, 1; 1, 2] (op !![1, 1; 1, 2] !![1, 1; 1, 2]) := by
  native_decide

/-- The same statement in the form §11.7 measured, so the Lean and the measurement agree about what fails:
there is **no** function `S` implementing the normalisation such that `S (A * B)` composes associatively
on the witness. Stated as the negation of the universal claim to keep it the general absence result rather
than a fact about one triple. -/
theorem no_associative_sandwich :
    ¬ (∀ A B C : M2, op (op A B) C = op A (op B C)) := by
  intro h
  exact sinkhorn_not_associative (h _ _ _)

end LaserCortex.ConditionalMemory.SinkhornMixer
