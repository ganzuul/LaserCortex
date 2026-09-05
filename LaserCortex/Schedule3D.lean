import Mathlib
import LaserCortex.Stencil3
import LaserCortex.Cost3D

/-!
# Schedule3D — 3-D schedule legality + streamer-diagnostic specification

Lean-first companion to the 3-D globe (`webgpu/mhd_globe_webgpu_3D.html`),
mirroring `Schedule.lean` (2-D) one dimension up. Two halves:

## Schedule legality (the optimization track)

* `lap3` — the unnormalized 7-point Laplacian over `Stencil3` grids (the
  certified world; the WGSL carries an extra uniform `1/(2Δ)` scaling that
  is linear, hence order- and equality-preserving, and documented where
  the kernel instantiates these theorems).
* `fusedDxJ` / `fusedDyJ` / `fusedDzJ` — the `j`-gradient taps the rhs
  kernels read from `jbuf`, recomputed from ψ-taps directly, in nested
  spelling (`(i+1)+1`, cf. the Phase-1 lesson in `Schedule.lean`). The
  three `*_eq` theorems say the lapj→rhs composition equals the fused
  cell: a kernel may skip the `jbuf` round-trip (it still writes
  `jbuf[center] = -lap3 ψ` definitionally, for meters and render).
* `jacPairTapsList` / `jacPairTaps` — the two-sweep Jacobi footprint is
  the Manhattan radius-2 ball (25 points); `jacPairTaps_card_le` bounds
  it. This is the certified setup for Poisson-pair fusion (next
  incision): one dispatch with halo 2 covers two Jacobi sweeps exactly.

## Streamer-diagnostic specification (the measurement track)

* `nonaxiDiff` + `nonaxi_sound` — the opposite-plane detector: a
  φ-independent column reads zero difference. Soundness is definitional;
  *completeness* (nonzero energy ⟺ genuine kφ content, not aliasing)
  needs NK even and modes ≤ NK/2 — the Nyquist condition `Cost3D` already
  documents (64 planes ⇒ kφ ≤ 31). The shipped JS enforces it with a
  full-φ DFT plus a runtime Parseval self-check.
* `diagOpsHost` + `diag_fraction` — the host DFT costs
  (Nx/4)·(Ny/4)·Nz·M·2 flops at stride-4 column sampling; at the shipped
  config it is ≤ 0.5% of one `Cost3D.stepOps` (proved by `decide`).
-/

namespace Schedule3D

open Stencil3

variable {Nx Ny Nz : ℕ} {R : Type*} [AddCommGroup R]

-- ============================================================================
-- lapj fusion: j-gradient taps recomputed from ψ (no jbuf round-trip)
-- ============================================================================

/-- Unnormalized 7-point Laplacian (the `lap3Psi` stencil up to the uniform
`1/DEL2` factor the kernel carries). -/
def lap3 (f : Stencil3.Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (k : ZMod Nz) : R :=
  f (i + 1) j k + f (i - 1) j k + f i (j + 1) k + f i (j - 1) k +
    f i j (k + 1) + f i j (k - 1) - 6 • f i j k

/-- Fused x-gradient of `j = -lap3 ψ`, in nested spelling. -/
def fusedDxJ (ψ : Stencil3.Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (k : ZMod Nz) : R :=
  lap3 ψ (i - 1) j k - lap3 ψ (i + 1) j k

/-- Fused y-gradient. -/
def fusedDyJ (ψ : Stencil3.Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (k : ZMod Nz) : R :=
  lap3 ψ i (j - 1) k - lap3 ψ i (j + 1) k

/-- Fused z-gradient. -/
def fusedDzJ (ψ : Stencil3.Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (k : ZMod Nz) : R :=
  lap3 ψ i j (k - 1) - lap3 ψ i j (k + 1)

/-- Fusion legality, x: recomputing from ψ equals reading staged `j`. -/
theorem fusedDxJ_eq (ψ : Stencil3.Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (k : ZMod Nz) :
    fusedDxJ ψ i j k =
      Stencil3.dx (fun a b c => -lap3 ψ a b c) i j k := by
  simp only [fusedDxJ, lap3, Stencil3.dx]
  abel

/-- Fusion legality, y. -/
theorem fusedDyJ_eq (ψ : Stencil3.Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (k : ZMod Nz) :
    fusedDyJ ψ i j k =
      Stencil3.dy (fun a b c => -lap3 ψ a b c) i j k := by
  simp only [fusedDyJ, lap3, Stencil3.dy]
  abel

/-- Fusion legality, z. -/
theorem fusedDzJ_eq (ψ : Stencil3.Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (k : ZMod Nz) :
    fusedDzJ ψ i j k =
      Stencil3.dz (fun a b c => -lap3 ψ a b c) i j k := by
  simp only [fusedDzJ, lap3, Stencil3.dz]
  abel

-- ============================================================================
-- Jacobi-pair footprint: two 7-point sweeps = Manhattan radius-2 ball
-- ============================================================================

/-- The 25 footprint points of two consecutive Jacobi sweeps at a cell
(center + 6 at distance 1 + 6 axial at distance 2 + 12 edge at distance 2).
Spelling is immaterial here — only the count is claimed. -/
def jacPairTapsList (i : ZMod Nx) (j : ZMod Ny) (k : ZMod Nz) :
    List (ZMod Nx × ZMod Ny × ZMod Nz) :=
  [(i, j, k),
    (i + 1, j, k), (i - 1, j, k), (i, j + 1, k), (i, j - 1, k),
    (i, j, k + 1), (i, j, k - 1),
    (i + 2, j, k), (i - 2, j, k), (i, j + 2, k), (i, j - 2, k),
    (i, j, k + 2), (i, j, k - 2),
    (i + 1, j + 1, k), (i + 1, j - 1, k), (i - 1, j + 1, k),
    (i - 1, j - 1, k), (i + 1, j, k + 1), (i + 1, j, k - 1),
    (i - 1, j, k + 1), (i - 1, j, k - 1), (i, j + 1, k + 1),
    (i, j + 1, k - 1), (i, j - 1, k + 1), (i, j - 1, k - 1)]

/-- The footprint as a set (degenerate widths may identify points — hence
`≤`, not `=`). -/
def jacPairTaps (i : ZMod Nx) (j : ZMod Ny) (k : ZMod Nz) :
    Finset (ZMod Nx × ZMod Ny × ZMod Nz) :=
  (jacPairTapsList i j k).toFinset

/-- Two Jacobi sweeps touch at most 25 distinct cells: the halo-2 bound the
Poisson-pair fusion kernel must (and will) cover. -/
theorem jacPairTaps_card_le (i : ZMod Nx) (j : ZMod Ny) (k : ZMod Nz) :
    (jacPairTaps i j k).card ≤ 25 := by
  unfold jacPairTaps
  calc (List.toFinset (jacPairTapsList i j k)).card
      ≤ (jacPairTapsList i j k).length := List.toFinset_card_le _
    _ = 25 := rfl

-- ============================================================================
-- Streamer detector: opposite-plane difference + soundness
-- ============================================================================

/-- Non-axisymmetry detector at two toroidal stations: zero iff the column
agrees there. The shipped fragment shader evaluates it at φ and φ+π with a
nearest (not trilinear) `jbuf` fetch — O(1) taps per line sample. -/
def nonaxiDiff (f : Stencil3.Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (k₁ k₂ : ZMod Nz) : R :=
  f i j k₁ - f i j k₂

/-- Soundness: a φ-independent column reads exactly zero, whatever the
meridional structure. (Completeness — nonzero ⟹ genuine kφ content — is
the Nyquist condition NK even, modes ≤ NK/2, enforced by the full-φ DFT
and its runtime Parseval self-check on the host.) -/
theorem nonaxi_sound (f : Stencil3.Grid3 Nx Ny Nz R) (i : ZMod Nx) (j : ZMod Ny)
    (h : ∀ k₁ k₂ : ZMod Nz, f i j k₁ = f i j k₂) (k₁ k₂ : ZMod Nz) :
    nonaxiDiff f i j k₁ k₂ = 0 := by
  simp only [nonaxiDiff]
  rw [h k₁ k₂, sub_self]

-- ============================================================================
-- Diagnostic cost: the host DFT is a 0.5% line item (proved)
-- ============================================================================

/-- Host φ-DFT flops: stride-4 column sampling × K planes × M modes × 2
(mult-add). -/
def diagOpsHost (Nx Ny Nz M : ℕ) : ℕ := (Nx / 4) * (Ny / 4) * Nz * M * 2

/-- At the shipped config the diagnostic costs at most half a percent of
one solver step — measurement never becomes the bottleneck it meters. -/
theorem diag_fraction :
    diagOpsHost 128 128 64 32 * 200 ≤ Cost3D.stepOps 128 128 64 40 := by
  decide

end Schedule3D
