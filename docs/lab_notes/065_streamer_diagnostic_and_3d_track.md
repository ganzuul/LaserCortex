# Lab Note 065: streamer diagnostic + 3D optimization track (resolution 128×128×64)

## Context corrections (both from the owner)

1. The optimization programme of note 064 targets the **3-D globe**
   (`webgpu/mhd_globe_webgpu_3D.html`), not the 2-D page — Phase 1
   (Schedule.lean) was the pattern, this note is its 3-D instantiation.
2. The resolution bump means the 3-D model's resolution, pushed until
   optimizations stop being cosmetic: **64×64×32 → 128×128×64**
   (131K → 1M cells, exactly 8× — `Cost3D.stepOps_double_all`).

## Streamer diagnostic (the committed "yes")

Two layers, same quantity (|j|), agreeing by construction:

* **Quantitative — φ-mode DFT meter.** `meters()` already read back all
  of `jbuf`; every 10th call (plus the first, so the meter populates
  immediately) it runs a full-φ DFT on stride-4 columns, modes 0..NK/2.
  Display: non-axisymmetric fraction, top mode, driven-k=1 fraction,
  Parseval self-check error. (x,y) subsampling cannot alias φ modes —
  it only thins the spatial average. Heartbeat logs the summary.
* **Visual — yellow-lines selector.** The PASS-2 meridian-plane lines
  gain a `Streamer watch` mode (new `lineModeSel`, carried on the
  previously-constant `ru.which` channel): per-line opposite-plane
  |j| difference via nearest (not trilinear) fetches, lines dim to a
  skeleton where the field is axisymmetric and go white-hot where kφ
  breaks. Same lines, diagnostic encoding — the 1-px design already
  reads as explicit filament legs.
* Lean cover (`Schedule3D.lean`): `nonaxiDiff` + `nonaxi_sound`
  (φ-independent column ⇒ exactly zero); completeness is the Nyquist
  condition NK even, modes ≤ NK/2 (now kφ ≤ 31), enforced by the full-φ
  DFT; `diagOpsHost` + `diag_fraction` prove the host DFT ≤ 0.5% of a
  solver step. Parseval is checked at runtime, not formalized (honest
  division of labor — DFT over roots of unity is out of proportion
  here).

## 3-D schedule work (Lean-first, same pattern as 064)

* `Schedule3D.lean` (new, in root build): `lap3` + `fusedDxJ/DyJ/DzJ`
  with `*_eq` theorems (recompute-j-from-ψ equals the staged read —
  same unfold+abel shape as Phase 1, nested spellings per the 064
  lesson); `jacPairTapsList`/`jacPairTaps` + `jacPairTaps_card_le`
  (two Jacobi sweeps = Manhattan radius-2 ball, ≤ 25 cells) as the
  certified setup for Poisson-pair fusion; all green, standard axioms
  (`diag_fraction` is axiom-free).
* `fused_b_div_current` analog: `mid_rhs`/`adv_rhs` now compute the
  j-gradient from ψ taps via `j_of_psi` (same taps, same order ⇒
  bit-identical) and still write `jbuf[center]` for meters/render.
  The two in-step `lapj` dispatches are gone (84 → 82 dispatches/step);
  the `lapj` kernel stays for the paused-mode meter refresh, and the
  dead `dxJ/dyJ/dzJ` helpers were deleted, not left as traps.
* Resolution is a real knob now: the `NXF/NYF/NZF/DEL*` literals are
  gone, replaced by `del()/delp()/del2()` from uniforms; render
  sampling (`63u`, `64u`, `32u` and friends — verified render-only
  before the global swap) derives from `cu`; binding 0 visibility
  widened to COMPUTE|FRAGMENT for the fragment stage.
* `Cost3D.lean` re-pointed at the shipped config (doc + `#eval`s;
  64×64×32 stays the exact half-step fallback via `stepOps_linear_in_K`).
* Host: Em/Ek triple loop gated to every 5th frame (it is O(cells) JS —
  at 1M cells it would own the frame otherwise); maxJ/ψ-range stay
  per-frame; `?burst=N` test hook (default 20) so headless iteration
  survives the 8× init.

## Verification (and its honest limits)

* `lake build`: green (8567 jobs). Axiom probes: standard only.
* `mirror_3d.py` at 128×128×64, 60 steps: bounded (max|j| ~22–25,
  Em ~0.028–0.030, finite throughout, no UNSTABLE). max|j| *rose* vs
  64³ (~13–17) — expected: normalized physical gradients resolve
  sharper sheets at finer Δ. That is the fidelity gain, metered.
* Headless `?burst=1`: WGSL compiles (incl. all edited kernels),
  burst executes (t=0.002 = 1×dt ✓), zero console errors.
* NOT verified headless, by measurement: full loop frames. SwiftShader
  cannot complete one 1M-cell frame (84 dispatches + 3×4MB readbacks +
  O(TOT) JS + 700² raymarch) in practical timeouts — established by
  pixel-region analysis (canvas stays at clear values; earlier "rendered"
  screenshots were UI chrome). Dump-dom exits pre-init; virtual budget
  does not grant GPU time. First-frame DFT + tint path therefore await
  a real GPU; the DFT math itself is proved exact in node (Parseval
  rel-err 0, analytic mode fractions) and the tint compiles in-module.
* Parity note: numpy fused-vs-sequential check from 064 covers the 2-D
  trio; the 3-D fusion's bit-identity rests on the same argument (exact
  f32 store/load + identical op order) plus `fusedDxJ/DyJ/DzJ_eq`.

## Deliberately deferred

* **Poisson-pair shared-memory fusion** (the actual lever: 80 of 82
  dispatches, ~95% of traffic). The halo-2 certificate is landed; the
  kernel (12×12×8 tile, two sweeps in-shared) waits on measurement
  from a real GPU.
* Readback elimination / timestamp queries, `?steps`-style hooks beyond
  `?burst=`, drive/resistivity scan, defect counter (the streamer
  thread's open items).
* Pre-existing lens nits in `reference_mhd.py` (standing disposition,
  notes 063/064): untouched.
* `webgpu/index.html` shows a whole-file formatter reflow in the working
  tree (attribute wrapping, no content change) — left alone; it reappears
  whenever the owner's editor saves, so reverting is whack-a-mole.
  Re-read before editing that file.
