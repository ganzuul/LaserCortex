import Mathlib

/-!
# Stencil3 — the 3-D certificates and the naive cost model

Lean-first step toward the 3-D (azimuthal) MHD plasma globe. Two families of
statements, both grounded before any GPU build:

## F1-3D: `∇·(∇×A) ≡ 0` in three dimensions

The A-form field `B = ∇ × A` on a periodic `ZMod Nx × ZMod Ny × ZMod Nz`
grid is divergence-free **identically** — the same telescoping content as
`Stencil.div_curl_eq_zero`, one dimension up. Every coordinate again
commutes with every other, so the six mixed second-difference pairs cancel
pointwise in any `AddCommGroup` of values. This is the certificate the 3-D
`B = ∇ × A` solver will ship: no cleaning, no projection, ever.

## Naive cost model (what "computational complexity" can honestly mean here)

For the planned 3-D solver (explicit, real-space, Jacobi Poisson, RK2), the
per-step work is a *counting* statement, not asymptotics: one step touches
`N³` cells (N per axis), each cell does a fixed per-cell workload — two RK
stages, each with a stencil pass, a bracket pass, and `J` Jacobi sweeps of
~6 cell-ops — so

    cellOps J = 2·(6 + 10 + 6·J)      (per cell per step)
    stepOps N J = N³ · cellOps J

The theorems below verify the model is sane (positivity, exact cubic scaling
under grid doubling — the naive 3-D floor — and monotonicity in both the
grid and the solver precision). They are *models*: the real budget also
depends on memory bandwidth, occupancy, and the auto-exposure readbacks;
but this is the provable skeleton the WebGPU kernels will be measured
against (and the place the Stencil-lemma-driven optimizations — e.g.
reducing the per-J-sweep op count by fusing taps — get certified). -/

namespace Stencil3

variable {Nx Ny Nz : ℕ} {R : Type*} [AddCommGroup R]

/-- Values on a periodic `Nx × Ny × Nz` grid. -/
abbrev Grid3 (Nx Ny Nz : ℕ) (R : Type*) := ZMod Nx → ZMod Ny → ZMod Nz → R

/-- Central difference along `x` (unnormalized, as in `Stencil.dx`). -/
def dx (f : Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny) (k : ZMod Nz) : R :=
  f (i + 1) j k - f (i - 1) j k

/-- Central difference along `y`. -/
def dy (f : Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny) (k : ZMod Nz) : R :=
  f i (j + 1) k - f i (j - 1) k

/-- Central difference along `z`. -/
def dz (f : Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny) (k : ZMod Nz) : R :=
  f i j (k + 1) - f i j (k - 1)

/-- A 3-D vector field on the periodic grid. -/
structure Vec3 (Nx Ny Nz : ℕ) (R : Type*) where
  vx : Grid3 Nx Ny Nz R
  vy : Grid3 Nx Ny Nz R
  vz : Grid3 Nx Ny Nz R

/-- Curl of a vector potential `A` — the 3-D A-form `B = ∇ × A`. -/
def curl (A : Vec3 Nx Ny Nz R) : Vec3 Nx Ny Nz R where
  vx := fun i j k => dy A.vz i j k - dz A.vy i j k
  vy := fun i j k => dz A.vx i j k - dx A.vz i j k
  vz := fun i j k => dx A.vy i j k - dy A.vx i j k

/-- Divergence of a 3-D vector field. -/
def div (B : Vec3 Nx Ny Nz R) : Grid3 Nx Ny Nz R :=
  fun i j k => dx B.vx i j k + dy B.vy i j k + dz B.vz i j k

/-- **F1-3D**: `∇·(∇×A) ≡ 0` pointwise — for any vector potential, any
periodic grid sizes, any `AddCommGroup` of values. The certificate the 3-D
A-form solver ships: divergence-free by theorem, not by cleaning. -/
theorem div_curl_eq_zero (A : Vec3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (k : ZMod Nz) : div (curl A) i j k = 0 := by
  simp only [curl, div, dx, dy, dz]
  abel

/-- Function-equality form of F1-3D. -/
theorem div_curl (A : Vec3 Nx Ny Nz R) : div (curl A) = 0 := by
  funext i; funext j; funext k
  exact div_curl_eq_zero A i j k

/-! ## The naive cost model -/

/-- Per-cell workload per step (a count, not an asymptotic claim):
2 RK stages, each with a 6-op stencil pass, a 10-op bracket pass, and `J`
Jacobi sweeps of 6 ops each. -/
def cellOps (J : ℕ) : ℕ := 2 * (6 + 10 + 6 * J)

/-- Whole-step workload on an `N × N × N` grid. -/
def stepOps (N J : ℕ) : ℕ := N ^ 3 * cellOps J

/-- The step cost is positive once the grid is nonempty. -/
theorem stepOps_positive (N J : ℕ) (hN : 0 < N) : 0 < stepOps N J := by
  unfold stepOps cellOps
  exact Nat.mul_pos (pow_pos hN 3) (by omega)

/-- Grid doubling costs exactly 8× (the 3-D naive floor: per-axis doubling
cubes the cell count; the per-cell work is unchanged). -/
theorem stepOps_double_grid (N J : ℕ) : stepOps (2 * N) J = 8 * stepOps N J := by
  unfold stepOps cellOps
  ring

/-- The step cost is monotone in both the grid size and the Jacobi count:
more resolution or more Poisson sweeps never reduces the naive budget. -/
theorem stepOps_mono (N₁ N₂ J₁ J₂ : ℕ) (hN : N₁ ≤ N₂) (hJ : J₁ ≤ J₂) :
    stepOps N₁ J₁ ≤ stepOps N₂ J₂ := by
  unfold stepOps cellOps
  have hc : 2 * (6 + 10 + 6 * J₁) ≤ 2 * (6 + 10 + 6 * J₂) := by omega
  exact Nat.mul_le_mul (pow_le_pow_left₀ (Nat.zero_le N₁) hN 3) hc

end Stencil3
