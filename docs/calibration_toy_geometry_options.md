# Calibration Toy — Geometry Options Memo (decision deferred)

**Date**: 2026-08-31
**Status**: DECISION-DEFERRED. Companion to the Phase plan in `session-ses_faea.md`
§5 and lab notes 056–057. Records the scout + researcher findings and the agreed
constraints, so the geometry question can be investigated rather than guessed at.

## 0. Decisions already taken (interview, 2026-08-31)

1. **Fidelity: instrument.** The numbers on screen must be trustworthy:
   fixed-timestep substepping decoupled from frame rate (no `dt = min(dt, 1/60)`
   per-frame stepping as in stock fluid demos), `R32F`/`float32` textures (fp16
   floors any "machine-precision" ∇·B readout near 1e-3 and would falsify the
   toy's own headline claim), and a headless CPU reference implementation of the
   identical kernel for GPU-path regression testing.
2. **Platform: WebGL2-first, WebGPU fast path.** The verified MIT ecosystem
   (PavelDoGreat, bandinopla, three-fluid-fx, loicmagne's 5 KB skeleton) is
   WebGL2; three-fluid-fx already ships both GLSL and TSL pipelines.
3. **Sequencing:** the 512-triple histogram + ledger sync came first (done —
   lab note 057). Its result {0,4} means the chirplet dial's intermediate values
   c ∈ {1,2,3} are operator-level `[H]` claims, not algebra facts.

## 1. Corrected inventory (what the plan got wrong)

* `infra/webgpu` **never existed**. All real WebGPU/TS code is in
  `_archive/canvas_app/frontend/` (Vite+React+three@0.184); the GPU-compute path
  was reverted to CPU (`76d7f28`) and archived (`81f6ca0`).
  `docs/webgpu_implementation_plan.md` "Files Created" claims are aspirational
  (5 of 7 shader files do not exist).
* Reusable, with caveats: `_archive/.../shaders/phi_cost.ts` (TSL kernel, header
  claims GPU-vs-API Φ equality at n ≤ 4), `bench.ts`, `TamariExplorer.tsx`
  (WebGPURenderer + OrbitControls wiring), `infra/_cortex/_tamari_lattice.py`
  (pre-built lattice: `build_lattice`, `loday_coord`, `total_pentagon_defect`),
  `infra/_cortex/_cost.py` (cost oracle).
* No `MHD.lean`/`Flux.lean`: the three ideal-MHD invariants currently map to CD
  theorems only as **analogy**; §11.3 items 4 and 7 (flux-as-divergence-theorem,
  invariant meaning of `rightSpine`) are still open.
* Scaffold choice open: fresh `apps/plasma-toy/`, vs un-archiving
  `canvas_app/frontend` (needs a FastAPI backend decision vs build-time baked
  JSON lattice), vs CPU-path + WebGPU-render-only.

## 2. The leading hypothesis: two transposed 2-D projections + subband

**Statement (user's, to be investigated):** two 2-D maps of the MHD state on
orthogonal axis pairs — read as a transposed pair — may suffice to reproject the
full 3-D dynamics. The cost model would then be 2 × 2-D + subband instead of
full 3-D. The structural reason to expect this to *almost* work: it is exactly
one Cayley-Dickson doubling step (double the dimension by pairing two copies
over the base, and lose properties in a controlled way — commutativity, then
associativity, at each step). Whatever the two projections cannot reassemble is
the "defect," and the CD tower says the defect should be measured by the
associator — whose basis spectrum is now known to be quantized {0,4} (057).

**Why it is plausible (known reductions in this shape):**

* 2.5-D reduction: fields invariant along one direction ⟹ 3-D ideal MHD
  collapses to a 2-D incompressible system + one passively-advected scalar
  (B_z) — exact, and cheap (`∇·B ≡ 0` for free).
* Helical-symmetry reduction (Mahajan–Ananda, Phys. Plasmas 1994; used in
  fusion contexts): 3-D MHD invariant along a *screw* Killing field collapses
  to 2-D dynamics plus extra scalars — a "two flat views + phase" structure.
* A divergence-free field is determined by a vector potential; in 2-D slices
  the solenoidal constraint is exactly representable (`D·C ≡ 0` telescoping).

**Why it cannot be taken for granted (the honest obstructions):**

* **DOF count:** a 3-D field on N³ has 3N³ values; two 2-D maps have 4N².
  Exact re-projection requires structural assumptions (symmetry, or analyticity
  strong enough that Radon-type reconstruction from two views is stable — two
  projections are not enough for general tomography).
* Projections along axes destroy cross-stream structure (current sheets tilted
  out of both planes alias into both maps).
* The CD analogy predicts *where* it fails: the loss of re-assembly coherence
  should show up as associator-like defects, i.e. the toy would be measuring
  the strut — which is precisely the interesting physics claim, if it survives
  contact with the reference solver.

**Falsifiable test (proposed):** small-grid CPU experiment, not graphics —
(a) evolve true 3-D ideal MHD (reduced or full, periodic, e.g. Orszag–Tang-
style) on 32³ with a CT reference; (b) evolve the candidate 2×2-D+subband
scheme; (c) compare the reprojection residual of B and the loop-flux invariant
ΔΦ/Φ over time, at several shears/tilts. If the residual stays at roundoff for
a symmetry class, that class is the toy's Phase-1 geometry; if the residual
grows as a quantized defect with a 4-fold structure, the CD reading gets its
first empirical address. This test needs no browser and can run in the existing
Python + gnuplot pipeline (`scripts/tube_map_calibrate.py` is the closest
precedent).

## 3. All geometry options on the table (from the researcher brief)

| Option | Scheme | ∇·B | Cost | Note |
| --- | --- | --- | --- | --- |
| (i) 2-D ψ-form | `B = ∇×(ψẑ)`, advect ψ as passive scalar | exact (`D·C ≡ 0`) | 1 texture + 2 taps | cheapest exact; real reconnection/islands |
| (ii) 2.5-D | `B = B_z(x,y)ẑ`, incompressible in-plane v | trivially exact | +1 dye texture | cheapest honest ideal-MHD; no tube cross-section |
| (iii) 2-D solver + pseudo-3D presentation | tubes as extruded ribbons, r ∝ \|B\|^(-1/2) | inherits (i)/(ii) | render cost only | looks 3-D, physics 2-D |
| (iv) True 3-D (CT-Yee or A-form) | WebGPU compute, 3–6 float32 textures | exact with CT/curl-form | new kernel, unbudgeted | no reusable browser kernel exists |
| (v) **2 projections + subband** (§2) | hypothesis above | to be determined | 2 × 2-D | CD-doubling reading; needs the CPU falsification test first |

Rejected regardless of geometry: per-step Hodge projection for B (tolerance-
limited *and* destroys comoving-loop flux — the very invariant to display);
GLM/Dedner cleaning (controls, does not annihilate ∇·B).

## 4. Interaction model (leaning, not decided)

Drag = edit ψ/A (the potential), never B directly — preserves exactness for
free and is the ergonomically validated pattern (obstacle-aware fluid control
via vector-potential editing, CAV 2025). A Lagrangian "grab a flux tube" handle
is the frozen-in demo par excellence and the natural way to expose ΔΦ/Φ.

## 5. Licence policy (for reuse)

MIT-only preferred. Clean: `artcodev/three-fluid-fx` (vendor-pinnable),
`bandinopla/threejs-fluid-simulation`, `loicmagne/webgl2_fluidsim`,
`zcyemi/webgl2-stablefluids` (CC0), `JamesRunnalls/three-streamlines`.
Attribution needed: `AtomBoy/BeltViz` (CC BY 4.0, best browser flux-tube
render precedent). Study-not-copy: `haxiomic/GPU-Fluid-Experiments`,
`d-burg/fusion-sim` (GPL-3.0). Unknown: `zemo-g/rail` plasma tools,
`sballin/w7x3d` — treat as non-permissive. Caution: `ledatic.org/plasma`'s
"∇·B to machine precision" claim is prima facie inconsistent with its
cell-centred Lax-Friedrichs scheme — copy its HUD design, not its numerics.

## 6. Lean-First compliance (AGENTS.md)

The genuinely small formal object for any of these options is the discrete
identity **D ∘ C = 0** (divergence of the chosen curl stencil vanishes
identically) — a finite-index ring/simp statement, and exactly the
correctness argument the instrument claim needs. Recommended: formalize
`DC_eq_zero` for the 2-D central stencil in Lean *before* the shader ships
(Lean → Python mirror → WGSL/GLSL binding order). Open question carried
forward: whether §11.3-4 ("flux conservation as divergence theorem") is the
right home for the continuum half (`d/dt ∮ B·dl = 0` under ideal induction).

## 7. Unresolved names from the old plan

"three-fluffy-flames", "Vmead", "VUS", "GDevice", "winder plasma viz" could not
be identified (real tool: VMEC; stellarator viewer: w7x3d). If specific
reference implementations were meant, supply canonical URLs — licensing
depends on it.

## References

* `session-ses_faea.md` §5 (original phased plan; premise corrected by scout)
* scout/researcher briefs: session artifact dir, run `c24fe240…`
  (`findings-scout.md`, `findings-researcher.md`)
* `docs/lab_notes/056_rees_strut_weight.md`, `057_strut_quantization.md`
* Fromang et al. 2008 (CT definition); Tóth 2000 (∇·B methods survey);
  Gardiner & Stone 2005/2008 (corner EMFs, field-loop test); Tomida et al.
  2026 (CT vs cleaning comparison); Banerjee & Pandit PRE 90, 013018 (2-D MHD
  ψ variables); Mahajan & Ananda 1994 (helical MHD reduction)
