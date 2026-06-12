# Lab Equipment: GPU Instrumentation for Timespace Decomposition

**Version 0.1** | 2026-06-11

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Lean 4 (Theory)                    │
│  ┌──────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │ EMLReg   │  │ Cost.lean│  │ Candidates.lean   │  │
│  │ istry    │  │ AMM.lean │  │ brute force Φ(min)│  │
│  └──────────┘  └──────────┘  └───────────────────┘  │
│        │              │                │             │
│        └──────────────┴────────────────┘             │
│                         │                            │
│                    Proven theorems                   │
│               (zero sorries, ground truth)           │
└─────────────────────────┬───────────────────────────┘
                          │ API (FastAPI)
                          ▼
┌─────────────────────────────────────────────────────┐
│              Python (Instrumentation)                │
│  ┌────────────────┐  ┌────────────────────────────┐  │
│  │ _cost.py       │  │ telemetry.py               │  │
│  │ _amm.py        │  │ • deterministic logging    │  │
│  │ _tamari_lattice│  │ • per-step Φ snapshots     │  │
│  └────────────────┘  │ • calibration checksums    │  │
│         │            └────────────────────────────┘  │
│         ▼                                             │
│  ┌────────────────────────────────────────────────┐  │
│  │         WebGPU Compute Pipeline                │  │
│  │                                                │  │
│  │  StorageBuffer (positions, velocities, colors) │  │
│  │  Compute Shader 1: Verlet integration          │  │
│  │  Compute Shader 2: Pentagonator constraint     │  │
│  │  Compute Shader 3: Virtual camera projection   │  │
│  └────────────────────────────────────────────────┘  │
│         │                                             │
│         ▼                                             │
│  ┌────────────────────────────────────────────────┐  │
│  │         WebGPU Render Pipeline                 │  │
│  │  • Fixed camera (user viewport)                │  │
│  │  • Virtual cameras × N (instrumentation feeds) │  │
│  │  • Φ-height field overlay                      │  │
│  │  • Anti-inertia edge gradients                 │  │
│  └────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Virtual Cameras as Instrumentation

Each virtual camera is a **computational probe** — a GPU compute shader
that renders the lattice from a specific vertex's perspective:

| Camera role | Position | Looks along | Sees |
|------------|----------|-------------|------|
| Fixed (user) | External | Entire lattice | Navigation view |
| RightComb probe | rightComb vertex | `contracts_to` chains | All paths to minimum |
| LeftComb probe | leftComb vertex | `contracts_one` edges | Max-cost routes |
| Logic probe ×14 | Lattice center | Per-logic Φ gradient | Cost basin for one logic |
| Edge probe ×E | Edge midpoint | Edge tangent | Cross-impact along one edge |

Each probe is a **compute shader** (`@compute @workgroupSize(64)`) that:

1. Reads vertex positions and Φ costs from storage buffers
2. Applies the camera's projection matrix (the camera's "logic type")
3. Writes a 2D projection buffer: `vec4<f32>(x, y, Φ, depth)`
4. Logs the projection hash to telemetry

The set of all virtual camera projections *is* the timespace decomposition
— each is one non-commutative ordering extracted from the pentagonator.

## WebGPU Compute Primitives

### Shader 1: Verlet Integration
```
Input:  positions[V], velocities[V], edge_list[E]
Output: positions'[V], velocities'[V]
Work:   each thread updates one vertex:
        velocity += (force * dt)
        position += velocity * dt
        velocity *= damping  // structure caps velocity
Force:  edge tension = |Φ(source) − Φ(target)|
        repulsion = 1/r²  (vertex-vertex Coulomb)
        gyroscopic = cross(velocity, pentagonator_normal)
```

### Shader 2: Pentagonator Constraint
```
Input:  positions[V], pentagon_faces[F]  (each face = 5 vertices)
Output: correction_forces[V]
Work:   each thread handles one K₄ face:
        compute center of 5 vertices
        compute pentagon defect = Σ(path_i − center) for i=0..4
        apply corrective impulse toward closure
```

### Shader 3: Virtual Camera Projection
```
Input:  positions[V], costs[V], camera_params[C]  (C virtual cameras)
Output: projection_buffers[C][V]  (vec4<f32>)
Work:   each thread projects one vertex through one camera:
        screen_pos = camera.projection * world_pos
        depth = camera.logic_weight * Φ(vertex)
        output = vec4<f32>(screen_pos.xy, depth, 1.0)
```

## Calibration

Calibration ensures the GPU experiment matches the Lean ground truth:

| Calibration step | What it checks | Frequency |
|-----------------|----------------|-----------|
| Φ consistency | GPU-computed Φ matches `/api/tamari/cost-lattice/{n}/{logic}` | On lattice load |
| Pentagonal closure | Sum of edge vectors around each K₄ face = 0 (±ε) | Every frame |
| Camera sync | Virtual camera projections match Lean Loday coordinates | On camera move |
| Velocity cap | No vertex exceeds max speed = structure cap | Every physics step |
| Zero-divisor detect | `Φ(a) * Φ(b) / Φ(compose(a,b))` — log near-zero values | Every composition |

**Calibration failure handling:**
- Minor drift (ε < 1%): dampen and log
- Major drift (ε > 5%): pause simulation, dump telemetry, flag for Lean revalidation
- Zero-divisor event: snapshot the entire state, mark as experimental candidate

## Deterministic Telemetry

Every GPU frame produces a **telemetry record**:

```typescript
interface TelemetryRecord {
  frame: number;
  timestamp: number;           // deterministic tick, not wall clock
  cameraId: number;
  projectionHash: string;      // checksum of all V projected positions
  minCost: number;
  maxCost: number;
  meanCost: number;
  pentagonDefect: number;      // Σ closure error across all faces
  velocitySum: number;         // Σ(|v_i|) — total kinetic energy
  zeroDivisors: Array<{a: number, b: number, product: number}>;
  couplingActive: boolean;      // whether coupling > threshold
  logicType: string;
}
```

Telemetry is:
- **Deterministic**: same initialization + same sequence of forces = same log
- **Loggable**: written to NDJSON stream, one record per physics tick
- **Replayable**: can re-run a logged experiment identically
- **Searchable**: cameraId + frame range indexes into experiments

Logs are written to `lab_data/runs/{run_id}/` and paired with the Lean
theorem hash that generated the lattice configuration.

## Instrumentation Modes

| Mode | Virtual cameras active | Purpose |
|------|----------------------|---------|
| **Calibration** | 1 (fixed) + 1 (logic probe) | Verify GPU matches Lean |
| **Survey** | 1 fixed + 14 logic probes | Scan cost landscape across all logics |
| **Decomposition** | 1 fixed + N edge probes | Extract pentagonator orderings |
| **Collapse** | 1 fixed + 1 rightComb probe | Monitor quench-collapse in real time |
| **Full** | All cameras | Maximum data collection |

## Split Responsibility

| What | Where | Format |
|------|-------|--------|
| Ground truth theorems | Lean 4 | `.lean` with `theorem` (zero sorries) |
| Candidate enumeration | Lean 4 `#eval` or Python | Brute force Φ(min) per n |
| Lattice geometry | Python → FastAPI | JSON vertices + edges + costs |
| Physics simulation | WebGPU compute | TSL compute shaders |
| Projection (virtual cameras) | WebGPU compute | Storage buffer → render |
| Telemetry logging | Python/Node | NDJSON to `lab_data/` |
| Pattern recognition | Human visual cortex | Viewport + virtual camera feeds |

## File Locations

- `canvas_app/frontend/src/shaders/` — WebGPU compute shaders (TSL)
- `canvas_app/backend/routers/tamari_router.py` — lattice API
- `infra/_cortex/telemetry.py` — deterministic logging
- `lab_data/runs/` — telemetry records (git-ignored)
- `LaserCortex/` — Lean theory (ground truth)

## Next Steps

1. Implement virtual camera compute shader (Shader 3) as TSL `Fn()`
2. Wire telemetry logging to the existing TamariExplorer
3. Calibrate: verify GPU Φ matches API Φ for n=4 all 14 logics
4. Run Survey mode at n=7 (429 trees, all 14 logics)
5. Store first telemetry record as baseline in `lab_data/runs/0000_baseline/`
