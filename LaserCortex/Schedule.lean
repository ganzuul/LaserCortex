import Mathlib
import LaserCortex.Stencil

/-!
# Schedule legality + cache-fit arithmetic (Phase 1, Lean-first optimization)

The finite-difference *spec* (`Stencil`) is fixed; this file certifies the
*schedule*: which reorderings, fusions, tilings, and substeppings a kernel
may perform without changing the computed fields. Every shipped optimization
must be an instance of a theorem here — that is the Lean-first contract.

Content:

* `fusedDiv` / `fusedCur`: the B→div→current trio as ONE per-cell function
  of ψ-taps, in exactly the shipped kernel's op order. `fused_div_eq` and
  `fused_cur_eq` say the fused dispatch computes what the three sequential
  passes compute — no intermediate global B needed (B is still written out
  for the `b_mag` visual layer, but no pass *reads* it back).
* `divTaps` / `curTaps` + `fused_halo`: the fused footprint is 4 corner taps
  (div) and 5 distance-2 cross taps (current) — Chebyshev radius 2. Any tile
  whose halo covers radius 2 computes exactly the global result on its
  interior: this is the halo-tiling legality theorem the shared-memory
  kernel instantiates at T = 16, H = 2.
* `substeps_conserve`: N on-device flux substeps preserve total Σψ for any
  flux-pair sequence — readback cadence is a metering choice, never a
  physics choice.
* Cache-fit arithmetic (`tileSharedBytes`, `workingSetBytes`,
  `trafficUnfused`/`trafficFused`): the reuse-distance predictor in
  closed form. `capacity_problem` says a 4 MB L2 already overflows at
  N = 512 (the "real problem" resolution); `traffic_fused_le` says the
  fused schedule moves ≤ ~1/7 the global bytes, generally in N.

Design notes: everything is stated over `Stencil`'s `ZMod` grids, so the
periodic wrap is group addition and degenerate widths stay true statements.
Fusion proofs are `simp only [...] + abel`: only addition, negation, and
commuting shifts appear, so they hold for every grid and every
`AddCommGroup` — including a future `SplitOctonion`-valued state.
-/

namespace Schedule

open Stencil
open scoped BigOperators

variable {Nx Ny : ℕ} {R : Type*} [AddCommGroup R]

-- ============================================================================
-- Fused B → div / current: one per-cell function of ψ-taps, kernel op order
-- ============================================================================

/-- Fused div(B) at `(i, j)` from ψ-taps directly, in the shipped kernel's
op order: `dx_bx + dy_by` with `dx_bx = Bx(i+1,j) − Bx(i−1,j)`,
`Bx = dy ψ`, and `dy_by` analogously with `By = −dx ψ`. -/
def fusedDiv (ψ : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) : R :=
  ((ψ (i + 1) (j + 1) - ψ (i + 1) (j - 1))
      - (ψ (i - 1) (j + 1) - ψ (i - 1) (j - 1))) +
    ((-(ψ (i + 1) (j + 1)) + ψ (i - 1) (j + 1)) -
      (-(ψ (i + 1) (j - 1)) + ψ (i - 1) (j - 1)))

/-- Fused J_z at `(i, j)` from ψ-taps directly: `dx_by − dy_bx` in kernel
op order, with `By = −dx ψ`, `Bx = dy ψ`. -/
def fusedCur (ψ : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) : R :=
  ((-(ψ ((i + 1) + 1) j - ψ ((i + 1) - 1) j)) -
      (-(ψ ((i - 1) + 1) j - ψ ((i - 1) - 1) j))) -
    ((ψ i ((j + 1) + 1) - ψ i ((j + 1) - 1)) -
      (ψ i ((j - 1) + 1) - ψ i ((j - 1) - 1)))

/-- Fusion legality, div half: the fused cell function IS the sequential
B-then-div composition. A kernel may skip materializing global B. -/
theorem fused_div_eq (ψ : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) :
    fusedDiv ψ i j = div (curl ψ) i j := by
  simp only [fusedDiv, div, curl, curlX, curlY, dx, dy]
  abel

/-- Fusion legality, current half: the fused cell function IS the
sequential B-then-current composition. -/
theorem fused_cur_eq (ψ : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny) :
    fusedCur ψ i j = dx (curlY ψ) i j - dy (curlX ψ) i j := by
  simp only [fusedCur, curlX, curlY, dx, dy]

-- ============================================================================
-- Footprints: the fused schedule reads ψ within Chebyshev radius 2
-- ============================================================================

/-- ψ-taps read by one fused-div cell: the 4 diagonal corners. -/
def divTaps (i : ZMod Nx) (j : ZMod Ny) : Finset (ZMod Nx × ZMod Ny) :=
  {(i + 1, j + 1), (i + 1, j - 1), (i - 1, j + 1), (i - 1, j - 1)}

/-- ψ-taps read by one fused-current cell, in nested-composition spelling
(8 spellings, 5 distinct values: `(i±1)±1` both denote `i`-shifted points;
the footprint they denote is the distance-2 cross). -/
def curTaps (i : ZMod Nx) (j : ZMod Ny) : Finset (ZMod Nx × ZMod Ny) :=
  {((i + 1) + 1, j), ((i + 1) - 1, j), ((i - 1) + 1, j), ((i - 1) - 1, j),
    (i, (j + 1) + 1), (i, (j + 1) - 1), (i, (j - 1) + 1), (i, (j - 1) - 1)}

/-- Halo-tiling legality, coordinate form: agreement on the 9 fused taps
implies agreement of both fused outputs. Each hypothesis is one tap the
shipped kernel reads; `rw` closes the goal since every tap occurs
syntactically in the unfolded fused definitions. -/
theorem fused_halo (ψ₁ ψ₂ : GridF Nx Ny R) (i : ZMod Nx) (j : ZMod Ny)
    (hd11 : ψ₁ (i + 1) (j + 1) = ψ₂ (i + 1) (j + 1))
    (hd1m : ψ₁ (i + 1) (j - 1) = ψ₂ (i + 1) (j - 1))
    (hdm1 : ψ₁ (i - 1) (j + 1) = ψ₂ (i - 1) (j + 1))
    (hdmm : ψ₁ (i - 1) (j - 1) = ψ₂ (i - 1) (j - 1))
    (hc11 : ψ₁ ((i + 1) + 1) j = ψ₂ ((i + 1) + 1) j)
    (hc1m : ψ₁ ((i + 1) - 1) j = ψ₂ ((i + 1) - 1) j)
    (hcm11 : ψ₁ ((i - 1) + 1) j = ψ₂ ((i - 1) + 1) j)
    (hcm1m : ψ₁ ((i - 1) - 1) j = ψ₂ ((i - 1) - 1) j)
    (hcj11 : ψ₁ i ((j + 1) + 1) = ψ₂ i ((j + 1) + 1))
    (hcj1m : ψ₁ i ((j + 1) - 1) = ψ₂ i ((j + 1) - 1))
    (hcjm11 : ψ₁ i ((j - 1) + 1) = ψ₂ i ((j - 1) + 1))
    (hcjm1m : ψ₁ i ((j - 1) - 1) = ψ₂ i ((j - 1) - 1)) :
    fusedDiv ψ₁ i j = fusedDiv ψ₂ i j ∧
      fusedCur ψ₁ i j = fusedCur ψ₂ i j := by
  constructor
  · simp only [fusedDiv]
    rw [hd11, hd1m, hdm1, hdmm]
  · simp only [fusedCur]
    rw [hc11, hc1m, hcm11, hcm1m, hcj11, hcj1m, hcjm11, hcjm1m]

/-- Halo-tiling legality, footprint form: agreement on `divTaps`/`curTaps`
suffices. A tile interior plus a radius-2 halo covers the footprint, so any
shared-memory implementation with H ≥ 2 computes exactly the global result
on its cells — this is what the shipped 16×16 + halo-2 kernel instantiates. -/
theorem fused_halo_footprint (ψ₁ ψ₂ : GridF Nx Ny R) (i : ZMod Nx)
    (j : ZMod Ny)
    (hd : ∀ p ∈ divTaps i j, ψ₁ p.1 p.2 = ψ₂ p.1 p.2)
    (hc : ∀ p ∈ curTaps i j, ψ₁ p.1 p.2 = ψ₂ p.1 p.2) :
    fusedDiv ψ₁ i j = fusedDiv ψ₂ i j ∧
      fusedCur ψ₁ i j = fusedCur ψ₂ i j := by
  have e11 : ψ₁ (i + 1) (j + 1) = ψ₂ (i + 1) (j + 1) :=
    hd (i + 1, j + 1) (by simp [divTaps])
  have e1m : ψ₁ (i + 1) (j - 1) = ψ₂ (i + 1) (j - 1) :=
    hd (i + 1, j - 1) (by simp [divTaps])
  have em1 : ψ₁ (i - 1) (j + 1) = ψ₂ (i - 1) (j + 1) :=
    hd (i - 1, j + 1) (by simp [divTaps])
  have emm : ψ₁ (i - 1) (j - 1) = ψ₂ (i - 1) (j - 1) :=
    hd (i - 1, j - 1) (by simp [divTaps])
  have f11 : ψ₁ ((i + 1) + 1) j = ψ₂ ((i + 1) + 1) j :=
    hc ((i + 1) + 1, j) (by simp [curTaps])
  have f1m : ψ₁ ((i + 1) - 1) j = ψ₂ ((i + 1) - 1) j :=
    hc ((i + 1) - 1, j) (by simp [curTaps])
  have fm11 : ψ₁ ((i - 1) + 1) j = ψ₂ ((i - 1) + 1) j :=
    hc ((i - 1) + 1, j) (by simp [curTaps])
  have fm1m : ψ₁ ((i - 1) - 1) j = ψ₂ ((i - 1) - 1) j :=
    hc ((i - 1) - 1, j) (by simp [curTaps])
  have fj11 : ψ₁ i ((j + 1) + 1) = ψ₂ i ((j + 1) + 1) :=
    hc (i, (j + 1) + 1) (by simp [curTaps])
  have fj1m : ψ₁ i ((j + 1) - 1) = ψ₂ i ((j + 1) - 1) :=
    hc (i, (j + 1) - 1) (by simp [curTaps])
  have fjm11 : ψ₁ i ((j - 1) + 1) = ψ₂ i ((j - 1) + 1) :=
    hc (i, (j - 1) + 1) (by simp [curTaps])
  have fjm1m : ψ₁ i ((j - 1) - 1) = ψ₂ i ((j - 1) - 1) :=
    hc (i, (j - 1) - 1) (by simp [curTaps])
  exact fused_halo ψ₁ ψ₂ i j e11 e1m em1 emm
    f11 f1m fm11 fm1m fj11 fj1m fjm11 fjm1m

-- ============================================================================
-- Substepping: N on-device flux steps preserve Σψ for any flux sequence
-- ============================================================================

/-- One conservative flux step with an arbitrary flux pair. -/
def fluxStep (Fx Fy ψ : GridF Nx Ny R) : GridF Nx Ny R :=
  fun i j => ψ i j + fluxDiv Fx Fy i j

/-- Readback cadence is a metering choice, never a physics choice: any
finite sequence of flux-form substeps preserves total Σψ. -/
theorem substeps_conserve [NeZero Nx] [NeZero Ny]
    (pairs : List (GridF Nx Ny R × GridF Nx Ny R)) (ψ : GridF Nx Ny R) :
    (∑ i, ∑ j, (pairs.foldl (fun ψ p => fluxStep p.1 p.2 ψ) ψ) i j) =
      ∑ i, ∑ j, ψ i j := by
  induction pairs generalizing ψ with
  | nil => rfl
  | cons p ps ih =>
    rw [List.foldl_cons, ih]
    simp only [fluxStep]
    have hfl : (∑ i : ZMod Nx, ∑ j : ZMod Ny, fluxDiv p.1 p.2 i j) = 0 :=
      fluxDiv_sum_eq_zero _ _
    have hsplit : (∑ i : ZMod Nx, ∑ j : ZMod Ny,
          (ψ i j + fluxDiv p.1 p.2 i j)) =
        (∑ i : ZMod Nx, ∑ j : ZMod Ny, ψ i j) +
          (∑ i : ZMod Nx, ∑ j : ZMod Ny, fluxDiv p.1 p.2 i j) := by
      simp_rw [Finset.sum_add_distrib]
    rw [hsplit, hfl, add_zero]

-- ============================================================================
-- Cache-fit arithmetic: the reuse predictor in closed form (Nat, decide)
-- ============================================================================

/-- Shared-memory tile bytes: `(T + 2H)²` cells × F fields × 4 B. -/
def tileSharedBytes (T H F : ℕ) : ℕ := (T + 2 * H) ^ 2 * F * 4

/-- The shipped 16×16 + halo-2 tile (1600 B) fits the guaranteed WebGPU
workgroup storage (16384 B) with room to spare. -/
theorem tile_shared_fit : tileSharedBytes 16 2 1 = 1600 ∧ 1600 ≤ 16384 := by
  decide

/-- Device working set in bytes: F fields over an N×N f32 grid. The shipped
layout holds F = 7 (ψ×2, B as vec2, div, J, Bφ). -/
def workingSetBytes (N F : ℕ) : ℕ := F * N * N * 4

theorem working_set_128 : workingSetBytes 128 7 = 458752 := by decide

theorem working_set_512 : workingSetBytes 512 7 = 7340032 := by decide

/-- The "real problem" certificate: at N = 512 the working set (~7 MB)
overflows any L2 ≤ 4 MB — capacity misses are no longer provably zero and
tiling/fusion actually matter. -/
theorem capacity_problem : 4 * 1024 * 1024 < workingSetBytes 512 7 := by
  decide

/-- Global ψ/B traffic (bytes per sweep) of the B→div→current trio,
unfused: 12 taps/cell (4 ψ + 4 B + 4 B). -/
def trafficUnfused (N : ℕ) : ℕ := 12 * N * N * 4

/-- Same trio fused behind a (T+2H)² shared tile at T = 16, H = 2. -/
def trafficFused (N : ℕ) : ℕ := (N / 16) ^ 2 * 20 * 20 * 4

theorem traffic_fused_128 : trafficFused 128 * 7 ≤ trafficUnfused 128 := by
  decide

theorem traffic_fused_512 : trafficFused 512 * 7 ≤ trafficUnfused 512 := by
  decide

/-- Generally in N (for tileable N): the fused schedule moves at most ~1/7
the global bytes of the unfused trio. -/
theorem traffic_fused_le (N : ℕ) (h16 : N % 16 = 0) :
    trafficFused N * 7 ≤ trafficUnfused N := by
  obtain ⟨k, hk⟩ : ∃ k, N = 16 * k := ⟨N / 16, by omega⟩
  subst hk
  have hdiv : 16 * k / 16 = k := Nat.mul_div_cancel_left k (by decide)
  simp only [trafficFused, trafficUnfused, hdiv]
  have h1088 : 11200 * k ^ 2 ≤ 12288 * k ^ 2 := by
    gcongr
    decide
  calc k ^ 2 * 20 * 20 * 4 * 7 = 11200 * k ^ 2 := by ring
    _ ≤ 12288 * k ^ 2 := h1088
    _ = 12 * (16 * k) * (16 * k) * 4 := by ring

end Schedule
