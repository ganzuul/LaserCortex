# Lab Note 063: Lean-first kernel optimization, Phase 1 — schedule + resolution

## What was done

Phase 1 of the kernel-optimization programme (see 062-era threads on the
calibration toy): the finite-difference *spec* is fixed (`Stencil.lean`),
and the *schedule* is now certified in a new file,
`LaserCortex/Schedule.lean`, wired into the library root. Every shipped
optimization below is an instance of a theorem there — the Lean-first
contract for all future kernel work.

## The theorems (all green, axioms standard)

* `fused_div_eq` / `fused_cur_eq` — the B→div→current trio as one per-cell
  ψ-function equals the sequential passes, in kernel op order
  (`propext` + `Quot.sound` only). Lesson learned while proving: write the
  fused defs in nested-composition spelling (`(i+1)+1`, not `i+2`), or the
  two sides of the equation elaborate with different index normal forms
  and `abel` cannot see they match.
* `fused_halo` + `fused_halo_footprint` — agreement on 4 corner taps +
  distance-2 cross implies agreement of both fused outputs; a radius-2
  halo is therefore exact. Footprint sets (`divTaps`/`curTaps`) stay in the
  file as the machine-readable form of the tiling contract.
* `substeps_conserve` — any flux-pair sequence preserves Σψ (needs
  `NeZero`; pulls `Classical.choice` via the `Finset.sum` machinery, same
  as `fluxDiv_sum_eq_zero` itself — standard, documented).
* Cache-fit arithmetic in closed form: `tile_shared_fit` (1600 B ≤ 16384 B
  workgroup limit), `working_set_128/512`, `capacity_problem` (7 MB at 512
  overflows any L2 ≤ 4 MB — the "real problem" certificate),
  `traffic_fused_128/512` and general `traffic_fused_le` (~1/7 the global
  bytes at any tileable N, proved by `calc` + `ring` after `omega`
  extracts the `N = 16 * k` witness).

## The mirrors

* `fused_b_div_current` (WGSL): one 16×16 workgroup loads a 20×20 ψ tile
  cooperatively (lid-mapped loads, barrier *before* the bounds guard so a
  partial edge workgroup can never hang), then B/div/J straight from shared
  taps in unfused op order. B is still written out (the `b_mag` layer reads
  it) but no pass reads it back.
* `index.html`: NX = NY = 512, canvas 512, three dispatches (fused, bφ,
  advect) instead of five; the O(N²) JS CFL scan is cached on flow
  parameters (it was 16K cells of trig per frame at 128 — at 512 it would
  have dominated the frame).
* `reference_mhd.py`: run functions at 512, green (F1 exact `0.00e+00`,
  Σψ drift ~1e-7, conservation intact).
* Parity evidence chain for the fusion: Lean eq-theorems + a numpy
  fused-vs-sequential check reading **exact `0.0`** (guards transcription
  typos, which no theorem can catch) + headless Chromium run at 512 with
  zero console errors and structured pixels.

## Resolution and fidelity notes

* Raw J_z magnitudes scale as O(1/N²) (unnormalized stencil, grid units) —
  finer grids print smaller numbers by construction. Read structure and
  growth, not amplitude; the auto-scaled visual layers normalize per frame.
  This is now stated in `webgpu/README.md`.
* Gains are banked as resolution + certified conservation, not
  milliseconds: the working set moved from L2-resident (448 KB) to
  capacity-miss territory (~7 MB), which is exactly where the Phase-2
  reuse-distance predictor starts biting.

## Pre-existing (not touched)

pi-lens flags 21 `np.float32`-vs-`float` annotation nits in
`reference_mhd.py` (all on lines predating this change; the file executes
green). Left alone deliberately — annotation churn on the mirror's API
surface belongs to a typing pass, not an optimization commit.

## Next (Phase 2/3)

`CacheModel.lean` (reuse distance + miss predictor + roofline as
`decide` facts), then readback elimination (GPU timestamp queries,
on-device substepping between checksums) and advect-side work
(precomputed u₀ buffers, `%`-free indexing).
