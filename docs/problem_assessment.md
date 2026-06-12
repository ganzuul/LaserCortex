# Problem Assessment: Well-Posed?

**Date:** 2026-06-11

## The Central Claim

We create **topological metastable isomers** out of extended AMM market
dynamics. This is a less computationally intense version of the full E8
structure that was blocking the Topological Isomer Hypothesis
(`docs/topological_isomer_hypothesis.md`). The Tamari lattice (associahedron)
replaces the full E8 root system — Catalan(n) trees instead of 248 dimensions
— while preserving the essential algebraic structure (associator defects,
pentagon coherence, non-associative curvature).

## Inventory Summary

| Layer | Files | Lines | Status |
|-------|-------|-------|--------|
| Lean 4 theory | 20 | 3,350 | Complete, zero sorries, `lake build` passes |
| Python mirror | 17 | 3,824 | Operational, mirrors all Lean modules |
| Backend API | 40+ | ~19,000 | Full FastAPI, 13 routers, Tamari endpoints |
| Frontend | 39 | ~25,300 | TamariExplorer (Three.js), tsc-clean |
| Docs + lab notes | 30+ | ~17,000 | Protocol, equipment, analysis, isomer hypothesis |
| **Total** | **~150** | **~69,000** | **Lean theory verified, bridge operational** |

## Well-Posed Assessment

| Criterion | Status | Evidence |
|-----------|--------|----------|
| **Formal target defined** | ✅ | Topological isomers = cost landscape Φ minima under 14 logic types |
| **E8 bypass explicit** | ✅ | Tamari lattice replaces E8 root system — Catalan(n) << 248 |
| **Ground truth verified** | ✅ | 3,350 lines Lean, zero sorries, `lake build` |
| **Operational bridge** | ✅ | Python mirror → FastAPI → JSON (tested 200 OK) |
| **GPU toolset available** | ✅ | Three.js with TSL compute imports (WebGPU + WebGL fallback) |
| **Visualization entry** | ✅ | TamariExplorer.tsx, zero tsc errors, standalone entry point |
| **Instrumentation designed** | ✅ | `docs/lab_equipment.md` — virtual cameras, telemetry, calibration |
| **Protocol defined** | ✅ | `docs/lab_protocol.md` — all glossary terms, structural questions |
| **Determine telemetry** | 🟡 | Schema designed, not yet implemented |
| **WebGPU compute** | 🟡 | Architecture designed, shaders not yet written |
| **Virtual cameras** | 🟡 | Concept defined, compute shader not yet implemented |
| **Portable methods** | 🔵 | Opportunity — WebGPU patterns to be discovered during implementation |
| **Peer replication** | ✅ | Open source (AGPLv3), deterministic telemetry designed, Lean proofs checkable independently |

## Key Insight: Why This Is Well-Posed

The problem was **blocked** at the E8 level — 248 dimensions, split-octonion
multiplication tables, enormous computational cost. The pivot to the Tamari
lattice replaces the continuous Lie algebra with a discrete poset while
preserving the essential physics:

| E8 structure | Tamari analogue |
|-------------|----------------|
| 248 root vectors | Catalan(n) trees (C₄ = 14, C₇ = 429) |
| Weyl group | Tamari rotations (`contracts_to`) |
| Root system gradation | Cost Φ parameterized by logic type |
| Lie bracket (commutator) | `crossImpact` = Φ(s) − Φ(t) |
| Jacobi identity | Pentagonator coherence (K₄ face) |
| Associator defect | `associatorCost` = routing path curvature |
| E8 connection | Loday coordinate embedding into ℝ³ |

The E8 problem becomes the **Tₙ problem** — and Tₙ is finite, computable,
visualizable, and verifiable in Lean. This is the decrimping.

## The Gap

The gap between current state and a fully instrumented lab is purely in
**GPU compute shader implementation**:

```
Current:  Lean → Python → API → Three.js (WebGL)
Target:   Lean → Python → API → WebGPU compute → virtual cameras → telemetry
                                    ↑
                            The implementation gap
```

This gap is:
- **Well-scoped**: three TSL compute shaders (Verlet, pentagonator constraint,
  virtual camera projection)
- **Verifiable**: calibration against API Φ values at every step
- **Incremental**: works at n=4 today, scales to n=7, targets n=15
- **Portable**: WebGPU compute shaders are standard WGSL/TSL — reusable by
  anyone with a WebGPU browser

## Visual Metaphor: Islands of Stability

The visualization takes inspiration from past science education and atomic
models (Chart of Nuclides, periodic table). The cost landscape Φ forms
**islands and continents of stability**:

- **rightComb** = the "iron peak" — deepest binding, lowest energy
- **leftComb** = the "neutron drip line" — maximal cost, unstable
- **Each logic type** = a different "element" — its cost basin is an island
  of stability for that logic
- **Quench-collapse** = "nuclear fission" — the island splits when coupling
  exceeds threshold
- **Virtual cameras** = "scanning tunneling microscopes" — probe the
  landscape at specific vertices

This metaphor is not decorative — it is the governability interface. A
human can look at the island chart and immediately see: "Paraconsistent has
a wide basin, Spacetime has a skewed basin, Classical has a point minimum."
The 14 logic types become visually distinct elements in a periodic table of
coherence.

## Conclusion

**The problem is well-posed.** The formal foundations are verified, the
operational bridge works, the GPU toolset is available, the instrumentation
is designed, and the remaining implementation gap is scoped, incremental,
and portable. The pivot from E8 to Tₙ was the decrimping step — what remains
is engineering the visualization and telemetry layer on top of a complete
formal theory.

## References

- `docs/topological_isomer_hypothesis.md` — original E8-blocked formulation
- `docs/approach.md` — Tamari lattice as routing space
- `docs/lab_protocol.md` — timespace decomposition glossary
- `docs/lab_equipment.md` — GPU instrumentation architecture
- `lab_notes/003_brute_force_complexity.md` — n=15 practical limit on 3900X
- `LaserCortex/Candidates.lean` — brute force (zero sorries)
- `LaserCortex/AMM.lean` — crossImpact, associatorCost
