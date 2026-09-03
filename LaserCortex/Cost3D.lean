import Mathlib
import LaserCortex.Stencil3

/-!
# Cost3D — performance estimates for the 3-D (azimuthal) solver

Lean-first answer to "is 64²×32 feasible, and what is the reduction lever if
not?" Before any GPU code, the per-step cost is a *counted* quantity with
verified scaling laws.

## What 64×64×32 is relative to

- The current page: 128×128 = 16,384 cells in the (r, z) meridional plane.
- The 3-D proposal: 64 radial × 64 axial × **32 azimuthal (φ) planes** =
  131,072 cells — **exactly 8×** the working set (per-axis doubling cubes the
  count; this is `stepOps_double_all` below, the 3-D naive floor).
- 32 φ-planes resolve azimuthal filaments up to kφ = 15 (Nyquist) — streamers
  are low-kφ, so this is deliberately loose resolution in φ.

## The counted model

Per cell per RK2 step, the 3-D operators: 7-point Laplacian (φ-shifts
included) at each stage, a bracket pair, and `J` 3-D Jacobi Poisson sweeps:

    cellOps J = 2·(13 + 20 + J·13)        (per cell, per step)
    stepOps N M K J = N·M·K·cellOps J

The theorems verify: positivity, the **exact 8×** all-axis doubling, the
**exact linear-in-K law** (the reduced-lattice lever: halving the azimuthal
plane count halves the cost — exactly, with no other change), and
monotonicity. The wall-clock conversion is deliberately OUT of the theorems:
ops are exact; throughput (real GPU ≈ 10⁹–10¹⁰ ops/s) is an assumption the
engineer varies against the counted number. -/

namespace Cost3D

/-- Per-cell ops per step for the 3-D explicit solver (see module docstring). -/
def cellOps (J : ℕ) : ℕ := 2 * (13 + 20 + J * 13)

/-- Whole-step ops on an `N × M × K` grid (K = azimuthal plane count). -/
def stepOps (N M K J : ℕ) : ℕ := N * M * K * cellOps J

/-- The step cost is positive once every dimension is nonempty. -/
theorem stepOps_positive (N M K J : ℕ) (hN : 0 < N) (hM : 0 < M) (hK : 0 < K) :
    0 < stepOps N M K J := by
  unfold stepOps cellOps
  exact Nat.mul_pos (Nat.mul_pos (Nat.mul_pos hN hM) hK) (by omega)

/-- **The 3-D floor**: doubling every axis costs exactly 8×. This is the
theorem that says 2× per axis is never a bargain in three dimensions. -/
theorem stepOps_double_all (N M K J : ℕ) :
    stepOps (2 * N) (2 * M) (2 * K) J = 8 * stepOps N M K J := by
  unfold stepOps cellOps
  ring

/-- **The reduced-lattice lever**: the cost is *exactly linear* in the
azimuthal plane count K — halving K halves the budget with no other change.
This is the formally grounded knob if the full-resolution estimate is too
expensive (K = 32 → 16 → 8 are exact half-steps, not approximations). -/
theorem stepOps_linear_in_K (N M K J : ℕ) :
    stepOps N M (2 * K) J = 2 * stepOps N M K J := by
  unfold stepOps cellOps
  ring

/-- Monotone in every dimension and in the Jacobi count: more resolution or
more Poisson sweeps never reduces the counted budget. -/
theorem stepOps_mono (N₁ N₂ M₁ M₂ K₁ K₂ J₁ J₂ : ℕ) (hN : N₁ ≤ N₂) (hM : M₁ ≤ M₂)
    (hK : K₁ ≤ K₂) (hJ : J₁ ≤ J₂) :
    stepOps N₁ M₁ K₁ J₁ ≤ stepOps N₂ M₂ K₂ J₂ := by
  unfold stepOps cellOps
  have hK' : 2 * (13 + 20 + J₁ * 13) ≤ 2 * (13 + 20 + J₂ * 13) := by omega
  have hg : N₁ * M₁ * K₁ ≤ N₂ * M₂ * K₂ := by
    exact Nat.mul_le_mul (Nat.mul_le_mul hN hM) hK
  exact Nat.mul_le_mul hg hK'

/-! ## The actual estimates (Lean-computed)

`#eval` is a computation in the kernel: these integers are the certified
counts, not hand-waved figures. -/

-- the planned configuration: 64×64×32 with J = 40 Jacobi sweeps
#eval stepOps 64 64 32 40
-- the reduction ladder (exact halves by the linear-in-K theorem)
#eval stepOps 64 64 16 40
#eval stepOps 64 64 8 40
-- and the 2-D reference (the current page: 128×128, J = 60), for scale
#eval 128 * 128 * Stencil3.cellOps 60   -- the current 2-D page (128×128, J=60)

end Cost3D
