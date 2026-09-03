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

open scoped BigOperators

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

/-!
## Certificates 2 and 3: the current kernel and conservative transport

F1 (`div_curl_eq_zero` above) certifies the curl/div pair. Two further
identities certify the remaining shipped kernels:

* `curl_curl_eq_neg_laplacian2` — the current-density composition read by
  `compute_current` (`webgpu/shaders/mhd_stencil.wgsl`) and
  `current_density` (`webgpu/reference_mhd.py`): for `B = curl ψ`,
  `dx B.y − dy B.x` is minus the **wide (spacing-two) Laplacian** of ψ.
  Composing two central differences of step 1 reaches taps at index distance
  2, so this is not the near-neighbour `-∇²ψ` of the common label — the
  certificate makes the kernel's exact content a theorem.  Like F1 it needs
  only addition, negation, and commuting index shifts, so it holds for every
  grid and every `AddCommGroup` of values.
* `fluxDiv_sum_eq_zero` — the discrete half of the §11.3-4 ledger row
  ("flux conservation as a divergence theorem").  A flux-form update
  `ψ' = ψ + fluxDiv` over a periodic grid conserves the total `∑ ψ` for
  *any* flux pair: over the cycle each edge flux is counted once as inflow
  and once as outflow, so the sum telescopes.  The advection scheme (upwind,
  donor cell, limiters, …) lives entirely inside the choice of `Fx`, `Fy`
  and cannot break conservation.  Unlike F1 this statement needs finite
  grids (`[NeZero Nx] [NeZero Ny]`): a global sum over the grid requires the
  index group to be finite. -/

/-- **Spacing-two five-point Laplacian** as a composition: two central
differences along `x` plus two along `y`.  Each composition widens the
stencil by one, so the taps sit at index distance 2 — i.e. this is
`f(i+2) + f(i−2) + f(j+2) + f(j−2) − 4f` — which is what the current kernel
computes, not the near-neighbour Laplacian. -/
def laplacian2 (f : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) : R :=
  dx (dx f) i j + dy (dy f) i j

/-- **Current certificate**: `J_z = dx B.y − dy B.x` for the stream-function
field `B = curl ψ` is `-laplacian₂ ψ` pointwise — the exact content of the
shipped `compute_current` / `current_density` kernels. -/
theorem curl_curl_eq_neg_laplacian2 (f : GridF Nx Ny R) (i : ZMod Nx)
    (j : ZMod Ny) :
    dx (curlY f) i j - dy (curlX f) i j = -laplacian2 f i j := by
  simp only [curlX, curlY, laplacian2, dx, dy, neg_sub]
  abel

/-- Net x-inflow into cell `(i,j)`: right-edge flux of the left neighbour in,
own right-edge flux out (`Fx i j` crosses the edge `(i,j) → (i+1,j)`). -/
def fluxDivX (Fx : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) : R :=
  Fx (i - 1) j - Fx i j

/-- Net y-inflow into cell `(i,j)`: top-edge flux of the bottom neighbour in,
own top-edge flux out (`Fy i j` crosses the edge `(i,j) → (i,j+1)`). -/
def fluxDivY (Fy : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) : R :=
  Fy i (j - 1) - Fy i j

/-- Net inflow across all four edges of cell `(i,j)`: the conservative
update increment `ψ' = ψ + fluxDiv`. -/
def fluxDiv (Fx : GridF Nx Ny R) (Fy : GridF Nx Ny R) (i : ZMod Nx)
    (j : ZMod Ny) : R :=
  fluxDivX Fx i j + fluxDivY Fy i j

/-- x-edge fluxes telescope along every row: the net x-inflow summed over a
row of the periodic grid is zero, for any flux field. -/
lemma fluxDivX_sum_eq_zero [NeZero Nx] (Fx : GridF Nx Ny R) (j : ZMod Ny) :
    (∑ i : ZMod Nx, fluxDivX Fx i j) = 0 := by
  unfold fluxDivX
  rw [Finset.sum_sub_distrib]
  have hswap : (∑ i : ZMod Nx, Fx (i - 1) j) = ∑ i : ZMod Nx, Fx i j := by
    calc
      (∑ i : ZMod Nx, Fx (i - 1) j)
          = ∑ i : ZMod Nx, Fx (Equiv.addRight (-1 : ZMod Nx) i) j := by
            apply Finset.sum_congr rfl
            intro i hi
            apply congrArg (fun t : ZMod Nx => Fx t j)
            rw [sub_eq_add_neg, Equiv.coe_addRight]
      _ = ∑ i : ZMod Nx, Fx i j := by
            exact Equiv.sum_comp (Equiv.addRight (-1 : ZMod Nx))
              (fun i : ZMod Nx => Fx i j)
  rw [sub_eq_zero]
  exact hswap

/-- y-edge fluxes telescope along every column: the net y-inflow summed over
a column of the periodic grid is zero, for any flux field. -/
lemma fluxDivY_sum_eq_zero [NeZero Ny] (Fy : GridF Nx Ny R) (i : ZMod Nx) :
    (∑ j : ZMod Ny, fluxDivY Fy i j) = 0 := by
  unfold fluxDivY
  rw [Finset.sum_sub_distrib]
  have hswap : (∑ j : ZMod Ny, Fy i (j - 1)) = ∑ j : ZMod Ny, Fy i j := by
    calc
      (∑ j : ZMod Ny, Fy i (j - 1))
          = ∑ j : ZMod Ny, Fy i (Equiv.addRight (-1 : ZMod Ny) j) := by
            apply Finset.sum_congr rfl
            intro j hj
            apply congrArg (fun t : ZMod Ny => Fy i t)
            rw [sub_eq_add_neg, Equiv.coe_addRight]
      _ = ∑ j : ZMod Ny, Fy i j := by
            exact Equiv.sum_comp (Equiv.addRight (-1 : ZMod Ny))
              (fun j : ZMod Ny => Fy i j)
  rw [sub_eq_zero]
  exact hswap

/-- **Transport conservation**: any flux-form update conserves total flux —
`∑ ψ' = ∑ ψ` for `ψ' = ψ + fluxDiv` — over any finite periodic grid, for any
flux pair.  The certificate behind the conservative `advect_psi` kernel
(`webgpu/shaders/mhd_stencil.wgsl`). -/
theorem fluxDiv_sum_eq_zero [NeZero Nx] [NeZero Ny]
    (Fx : GridF Nx Ny R) (Fy : GridF Nx Ny R) :
    (∑ i : ZMod Nx, ∑ j : ZMod Ny, fluxDiv Fx Fy i j) = 0 := by
  simp only [fluxDiv]
  simp_rw [Finset.sum_add_distrib]
  have hx : (∑ i : ZMod Nx, ∑ j : ZMod Ny, fluxDivX Fx i j) = 0 := by
    rw [Finset.sum_comm]
    apply Finset.sum_eq_zero
    intro j _hj
    exact fluxDivX_sum_eq_zero Fx j
  have hy : (∑ i : ZMod Nx, ∑ j : ZMod Ny, fluxDivY Fy i j) = 0 := by
    apply Finset.sum_eq_zero
    intro i _hi
    exact fluxDivY_sum_eq_zero Fy i
  rw [hx, hy]
  simp

end Stencil
