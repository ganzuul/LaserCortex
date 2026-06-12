# WebGPU Implementation: Lab Equipment Staging

**Date:** 2026-06-11  
**Guiding metaphor:** Setting up a physics laboratory for the associahedron.
Each stage is a piece of lab equipment, not just a software feature.

---

## Stage 0: Lab Bench — Environment

**Goal:** WebGPU compute pipeline verified operational with a trivial kernel.

```typescript
// shaders/bench.ts — minimal compute shader
const benchKernel = Fn(() => {
  const idx = instanceIndex;
  outputStorageBuffer[idx] = f32(idx) * 2.0;
});
```

**Deliverables:**
- `canvas_app/frontend/src/shaders/` directory with TSL import pattern working
- WebGPU vs WebGL fallback logic confirmed (loadTSL from existing code)
- 1 KiB output buffer readback verified
- `lab_data/runs/0000_bench/telemetry.ndjson` — first log file created

**Lab metaphor:** Bench power supply, multimeter, oscilloscope — verify the
basics before connecting anything expensive.

**Check:** `console.log(gpuBuffer[0]) === 0.0`

---

## Stage 1: Calibration Source — Φ on GPU

**Goal:** Reproduce the CPU Φ computation as a WebGPU compute shader, verified
against the API for all 14 logics at n=4.

```typescript
// shaders/phi_cost.ts
// input: tree bits (from buffer), logic type parameters
// output: Φ(tree) per vertex
const phiKernel = Fn(() => {
  const vertexIdx = instanceIndex;
  const tree = loadTreeBuffer(vertexIdx);
  const logicParams = loadLogicParams(vertexIdx);
  const cost = computePhi(tree, logicParams);  // transcribed from Cost.lean
  outputCostBuffer[vertexIdx] = cost;
});
```

**Deliverables:**
- Φ compute shader working for all 14 logics
- Batch: compute all trees × all logics in one dispatch
- Calibration: `|GPU_Φ − API_Φ| = 0` for every tree at n=4
- Telemetry records calibration checksums

**Lab metaphor:** Cesium-137 gamma source — a known, stable emitter used to
calibrate detectors. If the detector doesn't read correctly, don't proceed.

**Verification:**
```python
for tree in all_trees(4):
  for logic in all_logics:
    assert abs(gpu_phi(tree, logic) - api_phi(tree, logic)) == 0
```

---

## Stage 2: First Probe — Virtual Camera (Fixed)

**Goal:** One virtual camera as a compute shader, projecting the lattice from
the rightComb vertex's perspective.

```typescript
// shaders/virtual_camera.ts
// input: vertex positions[V], phi costs[V], camera_params
// output: projected[V] = vec4<f32>(screen_x, screen_y, depth, 1.0)
const cameraKernel = Fn(() => {
  const vIdx = instanceIndex;
  const worldPos = loadPositionBuffer(vIdx);
  const cost = loadCostBuffer(vIdx);
  const screenPos = cameraProjection(cameraMatrix, worldPos);
  const depth = camera.logicWeight * cost;
  projectedBuffer[vIdx] = vec4(screenPos.xy, depth, 1.0);
});
```

**Deliverables:**
- Virtual camera at rightComb looking up the contraction chains
- Output: 2D projection buffer readable by the render pipeline
- Side panel in TamariExplorer showing the camera feed
- Telemetry: projection hash (checksum of all V projected positions)

**Lab metaphor:** First probe station — fixed position, known orientation,
single sensor. Characterize its noise floor before building more.

**Physical configuration:**
- Position: rightComb vertex (the unique global minimum)
- Look-at: center of lattice (mean of all vertex positions)
- Up: Φ gradient direction (toward max-cost region)
- FOV: enough to see all vertices at n=4

---

## Stage 3: Probe Array — All Virtual Cameras

**Goal:** Deploy all virtual cameras as a single compute dispatch.

**Camera types and count (per frame):**

| Type | Count | Purpose |
|------|-------|---------|
| Fixed (user view) | 1 | Current viewport navigation |
| RightComb probe | 1 | Look up contraction chains from min |
| LeftComb probe | 1 | Look up from max-cost tree |
| Logic probes | 14 | One per logic type, Φ gradient overlay |
| Edge probes | E | One per edge, tangent view |
| **Total** | **17 + E** | |

```typescript
// shaders/camera_array.ts
// input: positions[V], costs[V], camera_params[C]  (C cameras)
// output: projections[C][V]
// workgroup per camera, each thread handles one vertex
const cameraArrayKernel = Fn(() => {
  const cameraIdx = workgroupIndex;
  const vIdx = instanceIndex;
  const cam = loadCameraParams(cameraIdx);
  const worldPos = loadPositionBuffer(vIdx);
  const cost = loadCostBuffer(vIdx);
  const projected = cam.project(worldPos, cost);
  projectionBuffer[cameraIdx * V + vIdx] = projected;
});
```

**Deliverables:**
- All 17+ virtual cameras dispatching in a single compute pass
- Each camera's output logged to telemetry
- UI: camera selector drop-down in TamariExplorer to view any camera feed
- Calibration: each camera's projection matches the Lean Loday coordinates
  for the camera's position

**Lab metaphor:** Sensor array — microphones in an anechoic chamber,
photodetectors in a particle detector. The array *is* the instrument.

---

## Stage 4: Live Feed — Real-Time Physics

**Goal:** Verlet integration + pentagonator constraint running as compute
shaders, driving dynamic vertex motion.

```typescript
// shaders/verlet.ts
const verletKernel = Fn(() => {
  const vIdx = instanceIndex;
  const vel = loadVelocityBuffer(vIdx);
  const pos = loadPositionBuffer(vIdx);
  const force = computeForce(vIdx);
  const newVel = (vel + force * dt) * damping;  // structure caps velocity
  const newPos = pos + newVel * dt;
  outputPositionBuffer[vIdx] = newPos;
  outputVelocityBuffer[vIdx] = newVel;
});

// shaders/pentagonator_constraint.ts
const constraintKernel = Fn(() => {
  const faceIdx = instanceIndex;  // each K₄ face
  const v = loadPentagonVertices(faceIdx);  // 5 vertices
  const center = (v[0] + v[1] + v[2] + v[3] + v[4]) / 5.0;
  const defect = computeDefect(v, center);
  applyCorrection(v, defect);
});
```

**Deliverables:**
- Live lattice with physics dynamics
- Edge tension colored by |Φ(s) − Φ(t)| (anti-inertia gradient)
- Pentagon defect displayed as overlay (face closure error per K₄)
- Velocity histogram in telemetry
- Physics pause/resume control in UI

**Lab metaphor:** The experiment is running. Oscilloscope is on. The
pentagon defect is the signal we're measuring.

---

## Stage 5: Data Acquisition — Telemetry Pipeline

**Goal:** Every physics tick writes a telemetry record to NDJSON.
Deterministic replay works.

```typescript
interface TelemetryFrame {
  tick: number;
  cameras: Array<{
    id: number;
    projectionHash: string;  // SHA-256 of all projected positions
  }>;
  physics: {
    positions: string;  // SHA-256 hash only (full data optionally logged)
    velocities_sum: number;
    pentagon_defect_total: number;
    min_cost: number;
    max_cost: number;
  };
  calibration: {
    phi_checksum: string;  // vs API
    pentagon_closure: number;  // Σ|closure| across all faces
  };
}
```

**Deliverables:**
- Telemetry writer (Node side) appends to `lab_data/runs/{run_id}/`
- Run metadata: Lean theorem hash, lattice n, logic types, coupling params
- Replay tool: `npm run replay --run-id 0001` replays telemetry identically
- Search index: by camera ID, frame range, logic type

**Lab metaphor:** Data acquisition system — 24-bit ADC, triggered logging,
time-stamped channels. If it's not logged, it didn't happen.

---

## Stage 6: The First Experiment — Survey at n=7

**Goal:** Run Survey mode (all 14 logic probes, n=7 = 429 trees) and produce
the first publishable result: the Φ cost landscape surface for all 14 logics.

**Protocol:**
1. Calibrate: GPU Φ vs API at n=4 (Stage 1) — must pass
2. Load lattice at n=7 via `/api/tamari/cost-lattice/7/{logic}` for each logic
3. Deploy all 14 logic probes plus fixed camera
4. Run physics: 10,000 ticks at dt=0.016
5. Log every 10th tick (1,000 telemetry records)
6. Post-process: per-logic min/mean/max Φ, pentagon defect per face,
   velocity distribution, zero-divisor candidates

**Deliverables:**
- `lab_data/runs/0001_survey_n7/` — full telemetry
- Heat map of Φ across all 14 logics (2D: logic × tree index)
- Pentagon defect distribution histogram
- Islands of stability classification (which trees are local minima per logic)
- First visual: the periodic table of coherence (14 logic types as elements)

**Lab metaphor:** The first real experiment. Calibrated, logged, repeatable.
The islands of stability chart is the first result posted on the lab wall.

---

## Stage 7: Publication — Portable Methods

**Goal:** Extract portable WebGPU patterns from the implementation and
document them for community use.

**Portable methods discovered:**
- `camera_array.ts`: how to dispatch N virtual cameras in one compute pass
- `phi_cost.ts`: how to project a discrete cost function onto a GPU
- `pentagonator_constraint.ts`: how to enforce face closure constraints
- `telemetry.ts`: deterministic logging pattern for GPU compute

**Deliverables:**
- `docs/webgpu_patterns.md` — standalone reference
- Minimal standalone demo: `demos/tamari_webgpu_minimal/` — a single HTML
  file that renders T₄ with WebGPU compute, no framework dependencies
- Peer replication: anyone with a WebGPU browser can run the demo and verify
  the cost landscape matches the Lean theorems

**Lab metaphor:** Publishing in a peer-reviewed journal. The portable methods
are the "methods section" — detailed enough that another lab can replicate.

---

## Implementation Order

```
Stage 0: Bench      → 1–2 days  (TSL plumbing, buffer readback)
Stage 1: Calibrate  → 2–3 days  (Φ shader, API verification)
Stage 2: First cam  → 2–3 days  (single virtual camera, side panel)
Stage 3: Array      → 3–5 days  (all cameras, camera selector UI)
Stage 4: Physics    → 5–7 days  (Verlet + pentagonator constraint)
Stage 5: Telemetry  → 2–3 days  (NDJSON logging, replay)
Stage 6: Experiment → 3–5 days  (Survey n=7, analysis, islands chart)
Stage 7: Publish    → 2–3 days  (patterns doc, minimal demo)
                     ─────────
              Total: 20–31 days
```

Each stage produces a working, testable artifact that builds on the previous.
No stage depends on future stages — the lab can stop after any stage and
still have useful equipment.

## Files Created

- `canvas_app/frontend/src/shaders/bench.ts`
- `canvas_app/frontend/src/shaders/phi_cost.ts`
- `canvas_app/frontend/src/shaders/virtual_camera.ts`
- `canvas_app/frontend/src/shaders/camera_array.ts`
- `canvas_app/frontend/src/shaders/verlet.ts`
- `canvas_app/frontend/src/shaders/pentagonator_constraint.ts`
- `canvas_app/frontend/src/services/telemetry.ts`
- `lab_data/runs/` (git-ignored, created at runtime)
- `docs/webgpu_patterns.md`
- `demos/tamari_webgpu_minimal/index.html`
