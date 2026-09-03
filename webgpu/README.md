# webgpu/ — Conservative ψ-form toy lab (Path A)

Fresh, dedicated scratch space for the Lean ↔ WebGPU mirror loop. Not yet
part of a build; run from this directory.

## Files

| File | Role |
|---|---|
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
* **Advection**: conservative flux form (donor cell / upwind) along `u = B`
  (field-line self-transport toy). Σψ conserved to op-rounding for any flux
  pair (`Stencil.fluxDiv_sum_eq_zero`); there is **no dissipation knob** —
  the L2 meter on screen is the scheme's own truncation error.
* **Reconnection is not priced at c = 0**: an ideal run must NOT reconnect.
  The `max |J_z|` meter tracks current-sheet steepening; a grid-scale
  X-point collapse would cost strut charge at `c = 4` and is an open `[H]`
  (lab note 058, F3), not a diffusive accident of the toy.
* **Interaction** (memo §4): drag = edit ψ (the potential), never B;
  Alt/Shift-drag subtracts.

## Run

```bash
# 1. CPU reference (no GPU needed) — mirrors the kernels and certificates
python3 reference_mhd.py

# 2. Browser lab — double-clicking webgpu/index.html now works as-is
#    (shader embedded, no fetch). Or serve it:
python3 -m http.server 8137 --bind 127.0.0.1
# then open http://127.0.0.1:8137/  — or:
/usr/bin/chromium --ozone-platform-hint=wayland --use-gl=angle \
  --use-angle=vulkan --enable-features=WebGPU --ignore-gpu-blocklist \
  "http://127.0.0.1:8137/"
```

## Troubleshooting

* **A failure never renders as a black rectangle anymore.** If the page
  cannot start, the canvas paints `NO GPU FRAME` and a concrete message
  appears under it (`#gpuStatus`), with the same text in the console.
* **`requestAdapter() returned null`** = Chromium has no usable WebGPU
  backend. Note `--use-angle=vulkan` steers **ANGLE (WebGL)**, not Dawn
  (WebGPU); on `chrome://gpu` the row `Vulkan: Disabled` refers to
  ANGLE's backend choice, so it can be benign while WebGPU works. Add
  `--enable-unsafe-webgpu` for the SwiftShader fallback to confirm the
  page logic independently of the GPU stack.
* **Mostly-dark canvas in the default view is physics, not failure:**
  `J_z = −∇²₂ψ` is concentrated in current sheets; switch the
  Visualization Layer to ψ for a full-frame picture.

## Meter meaning

| Meter | Expectation |
|---|---|
| max \|∇·B\| | ~1–2 × ε·max\|ψ\| every tick (F1, re-issued) |
| ΔΣψ | ~op-rounding of the flux form (certified conserved) |
| ΔΣψ² | donor-cell truncation, visible as a small decay |
| max \|J_z\| | growth ⇒ current-sheet steepening; runaway at grid scale is the would-be `c = 4` event |
