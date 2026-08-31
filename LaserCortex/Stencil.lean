import Mathlib

/-!
# Discrete Div–Curl Identity (F1)

Periodic 2-D central-difference stencils over `ZMod` indices. The headline
result — `div_curl_eq_zero` — says `D ∘ C ≡ 0` **pointwise, for every field,
every grid size, and every additive-coefficient group**: the vanishing of the
discrete divergence of the stream-function curl is a telescoping identity in
an abelian group, not a convergence claim. This is the formal content behind
the calibration-toy requirement "∇·B to machine precision"
(`docs/calibration_toy_geometry_options.md` §6, `docs/lab_notes/058_associator_backprop_fidelity_dial.md`
F1): the scheme is divergence-free *by theorem*.

Design notes:

* **`ZMod` indices** (first use in this repo): periodic shift *is* group
  addition on `ZMod`, so there is no `Nat.mod` bookkeeping and no `NeZero`
  hypotheses; degenerate widths (`Nx = 1`, where `i + 1 = i - 1` and the
  difference collapses to `0`) are true statements, not exceptions.
* **Unnormalized stencils**: the `1 / (2h)` factor of second-order central
  differences is dropped — it cancels multiplicatively and keeping the
  calculus addition-and-subtraction-only lets it run over `ℤ` (the integer-
  lattice toy kernels).
* **`[AddCommGroup R]`**: no multiplication appears in `D` or `C`, so the
  identity is *stabler* than the scalar case suggests — see the non-associative
  remark after `div_curl` for where associator defects can and cannot
  enter. The mirror (Python/WGSL) may instantiate `R := ℤ`, `ℝ`, or
  `SplitOctonion`-valued grids additively.
-/

namespace Stencil

/-- Values on a periodic `Nx × Ny` grid. -/
abbrev GridF (Nx Ny : ℕ) (R : Type*) := ZMod Nx → ZMod Ny → R

/-- A vector field on a periodic grid: its two flux components. -/
structure VecF (Nx Ny : ℕ) (R : Type*) where
  px : GridF Nx Ny R
  py : GridF Nx Ny R

variable {Nx Ny : ℕ} {R : Type*} [AddCommGroup R]

/-- Central difference along `x` (unnormalized): one forward tap minus one
backward tap. -/
def dx (f : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) : R :=
  f (i + 1) j - f (i - 1) j

/-- Central difference along `y`. -/
def dy (f : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) : R :=
  f i (j + 1) - f i (j - 1)

/-- The `x`-component of the stream-function curl. -/
def curlX (ψ : GridF Nx Ny R) : GridF Nx Ny R := dy ψ

/-- The `y`-component of the stream-function curl. -/
def curlY (ψ : GridF Nx Ny R) : GridF Nx Ny R := fun i j => -(dx ψ i j)

/-- **Stream-function curl** `B = ∇ × (ψ ẑ) = (∂y ψ, −∂x ψ)`: the A-form of
2-D incompressible MHD, whose exactly-divergence-free character is the F1
theorem below. -/
def curl (ψ : GridF Nx Ny R) : VecF Nx Ny R where
  px := curlX ψ
  py := curlY ψ

/-- Discrete divergence of a vector field. -/
def div (B : VecF Nx Ny R) : GridF Nx Ny R :=
  fun i j => dx B.px i j + dy B.py i j

/-- **Mixed central differences commute**: `dx (dy f) = dy (dx f)`. All the
content of `D ∘ C = 0` lives here — x-shifts and y-shifts touch different
coordinates, so the four-corner stencil is symmetric. -/
theorem dx_dy (f : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) :
    dx (dy f) i j = dy (dx f) i j := by
  simp only [dx, dy]
  abel

/-- **F1 — divergence of the stream-function curl vanishes identically.**
`D ∘ C ≡ 0` as an exact theorem: every cell, every field, every periodic
grid (`Nx Ny` arbitrary, including degenerate), every `AddCommGroup` of
values. This is the certificate the ψ-form solver ships: any `B` produced as
`curl ψ` satisfies the discrete `∇·B = 0` to floating-point roundoff *of the
individual arithmetic ops only* — the stencil composition itself contributes
zero error. -/
theorem div_curl_eq_zero (f : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) :
    div (curl f) i j = 0 := by
  show dx (curlX f) i j + dy (curlY f) i j = 0
  simp only [curlX, curlY, dx, dy, neg_sub]
  abel

/- The global (function-equality) form of F1. -/
theorem div_curl (f : GridF Nx Ny R) : div (curl f) = 0 := by
  funext i j
  exact div_curl_eq_zero f i j

/-!
## Non-associative remark (feedback into lab note 058)

`D` and `C` above use only addition, negation, and *commuting* index shifts:
the index group `ZMod Nx × ZMod Ny` is abelian, and that is exactly what
`dx_dy` says. Consequences:

1. The F1 certificate survives *algebra-valued* fields: instantiate
   `R := SplitOctonion` (additive structure only) and `B = curl ψ` is still
   exactly div-free. Non-associativity of the values cannot break a proof
   that never multiplies.
2. Therefore associator defects in a full MHD step can enter **only through
   multiplicative terms** — the advection `(v · ∇) B` and the Lorentz coupling
   `J × B` — i.e. exactly where the Rees fibre parameter `c` of lab note 058
   is proposed to live. F1 carves the error budget into a provably-zero
   part (`D ∘ C`) and the priced part (the nonlinear channel);
   the dial tunes only the priced part.
-/

end Stencil
