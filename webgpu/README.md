# webgpu/ — Conservative ψ-form toy lab (Path A)

Fresh, dedicated scratch space for the Lean ↔ WebGPU mirror loop. Not yet
part of a build; run from this directory.

## Files

| File | Role |
| --- | --- |
| `reference_mhd.py` | Headless CPU oracle, float32 op-for-op with the WGSL kernels |
| `shaders/mhd_stencil.wgsl` | The four compute kernels — **authoring source** |
| `index.html` | Browser lab: meters, visual layers, drag-to-edit-ψ. Ships a *generated* inline copy of the WGSL (see below) |

The shader travels **inside** `index.html` because `file://` pages cannot
`fetch()` anything (origin `null` is CORS-blocked by Chromium — the old
version silently black-screened on double-click). After editing the
`.wgsl`, regenerate the embed:

```bash
python3 ../scripts/embed_wgsl.py          # rewrite the inline block
python3 ../scripts/embed_wgsl.py --check  # drift gate (run before commit)
```

## Physics status (honest labels)

* **Fields are ψ-form**: `B = curl ψ` is recomputed every tick, so the F1
  certificate (`Stencil.div_curl_eq_zero`) re-issues each step — divergence
  is *excluded by parameterization*, never cleaned.
* **Current layer**: `J_z = dx(B_y) − dy(B_x) = −laplacian₂ψ` — the
  *spacing-two* five-point Laplacian (`Stencil.curl_curl_eq_neg_laplacian2`),
  not the near-neighbour `−∇²ψ` of the old label.
* **Advection**: conservative flux form (donor cell / upwind) along a
  **prescribed, ψ-independent, divergence-free flow** `u₀` (Taylor–Green
  vortex or uniform shear). Σψ conserved to op-rounding for any flux pair
  (`Stencil.fluxDiv_sum_eq_zero`); there is **no dissipation knob** — the
  L2 meter on screen is the scheme's own truncation error.
* **Why not u = B (degenerate):** in 2D `B·∇ψ ≡ 0` (B is tangent to
  ψ-contours), so advecting ψ by B gives `∂ₜψ = 0` — the field is frozen.
  Every visible "motion" with u = B is the scheme's residual discretization
  noise: diagonal banding, runaway `|J_z|` (~200×), large L2 loss. A
  ψ-independent flow removes the degeneracy and yields genuine frozen-in
  transport with mild, stable current-sheet steepening (mirror: `max|J_z|`
  stable ~0.06–0.07, L2 −0.4% over 600 ticks at CFL 0.005).
* **Reconnection is not priced at c = 0**: an ideal run must NOT reconnect.
  The `max |J_z|` meter tracks current-sheet steepening; a grid-scale
  X-point collapse would cost strut charge at `c = 4` and is an open `[H]`
  (lab note 058, F3), not a diffusive accident of the toy.
* **Interaction** (memo §4): drag = edit ψ (the potential), never B;
  Alt/Shift-drag subtracts.

## Domains (the toy is now two geometries, one kernel set)

* **Poloidal `(R,Z)` — 2.5-D axisymmetric tokamak (default).** Axisymmetry
  (`∂_φ = 0`) reduces a tokamak to the poloidal plane + a toroidal scalar:
  `B = curl(ψ)` (poloidal, `ψ = R·A_φ`, certifiably div-free) plus
  `B_φ = B₀·R₀/R` (`compute_bphi`). The poloidal flux `ψ` is seeded as a
  Gaussian plasma column about the axis at `(R0, 0)`; its toroidal current
  `J_φ ∝ -laplacian₂(ψ)` is peaked on axis. `R0` keeps `R > 0` (axis off the
  seam). The physical cylindrical `∇·B = (1/R)·(reduced div)` vanishes
  because the reduced div does — the F1 certificate holds unchanged.
* **Cartesian `(x,y)` — the original plane** (Orszag–Tang / island / noise),
  retained for comparison; `geomBtor = 0` there so the `B_φ` layer is flat.

The torus topology the earlier `#` revealed is now explicit: a periodic
`(R,Z)` box is the unwrapped torus, whose two independent cycles are the
two rulings of the split-signature `(4,4)` quadric — the same structure the
octonion framework targets (see `../research_questions.md`, rulings-as-species).

## Run

```bash
# 1. CPU reference (no GPU needed) — mirrors the kernels and certificates
python3 reference_mhd.py

# 2. Browser lab — double-clicking webgpu/index.html works as-is (shader
#    embedded, no fetch, no http server required). Same WebGPU code runs in
#    both engines:
#    - Firefox (154+): WebGPU is on by default since v141; needs a working
#      Vulkan driver (verify about:support → WebGPU). If missing there, set
#      dom.webgpu.enabled = true in about:config.
#    - Chromium: WebGPU needs the right GPU process; from a terminal:
/usr/bin/chromium --ozone-platform-hint=wayland --use-gl=angle \
  --use-angle=vulkan --enable-features=WebGPU --ignore-gpu-blocklist \
  "file://$PWD/index.html"
#    (optional --enable-unsafe-webgpu for the SwiftShader software fallback;
#    headless CI can use VK_ICD_FILENAMES=/usr/lib/chromium/vk_swiftshader_icd.json)
```

## Troubleshooting

* **A failure never renders as a black rectangle anymore.** If the page
  cannot start, the canvas paints `NO GPU FRAME` and a concrete message
  appears under it (`#gpuStatus`), with the same text in the console. The
  message names the browser it is shown in (Firefox: `about:config`
  `dom.webgpu.enabled`; Chromium: `chrome://gpu` / launch flags).
* **`requestAdapter() returned null`** = no usable WebGPU backend. In
  Chromium, note `--use-angle=vulkan` steers **ANGLE (WebGL)**, not Dawn
  (WebGPU); on `chrome://gpu` the row `Vulkan: Disabled` refers to ANGLE's
  backend choice, so it can be benign while WebGPU works. In Firefox the
  usual cause is a missing Vulkan driver (check `about:support`).
* **Mostly-dark canvas in the default view is physics, not failure:**
  `J_z = −∇²₂ψ` is concentrated in current sheets; switch the
  Visualization Layer to ψ for a full-frame picture.
* **Flat single-colour frames (all black / all grey / all blue) with a live
  flux meter** = every kernel is no-op'ing, typically an invalid bind group:
  all four pipelines and both ping-pong bind groups must share ONE explicit
  bind group layout covering bindings 0–5 (auto layouts differ per entry
  point and silently invalidate a six-binding group).

## Meter meaning

| Meter | Expectation |
| --- | --- |
| max \|∇·B\| | ~1–2 × ε·max\|ψ\| every tick (F1, re-issued) |
| ΔΣψ | ~op-rounding of the flux form (certified conserved) |
| ΔΣψ² | donor-cell truncation, visible as a small decay |
| max \|J_z\| | growth ⇒ current-sheet steepening; runaway at grid scale is the would-be `c = 4` event |
