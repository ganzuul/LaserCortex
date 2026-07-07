# 036: Staging Merger & Phase 5 Cost Absorption

**Date**: 2026-07-07
**Status**: COMPLETE (Phases 1–3), PENDING (Phase 5)
**Prerequisites**: 031 (IC is regular subdivision), 032 (tropical type theory hypothesis),
  033 (tropical types as graphiti communities), staging/ files (Algebra, Tamari, Friction, etc.)
**Source**: Reorganisation of `staging/ → foundations/`, old-core → `.lean.old`, plus gap analysis
  from `docs/AMM_MARKET_CLOSURE_REDESIGN.md`, `docs/GLM-5-2_on_gaps.md`, `docs/type_theory_map.md`

---

## 1. What Was Done (Phases 1–3)

### Phase 1: `staging/ → foundations/`

Three canonical foundation files now live in `LaserCortex/foundations/`:

| File | Content | Dependencies |
|------|---------|-------------|
| `Algebra.lean` | Split octonion algebra over ℤ; `SplitOctonion`, `antipode`, `counit`, `strut_weight = 4` | Mathlib only |
| `Tamari.lean` | `EMLTree`, Tamari lattice, `dcStep : EMLTree → ℕ`, `leftComb`, `rightComb`, `contracts_to_rightComb` | Mathlib only |
| `Chu.lean` | Chu pairing `(4,4)` signature on split octonions | `foundations.Algebra` |

These import only Mathlib and each other — zero dependencies on old core. They are the
algebraic skeleton of the entire cost landscape.

### Phase 2: Old core → `.lean.old`, replaced by staging ports

Old core files that were replaced by staging ports:

| Replaced module | Staging port (new) |
|----------------|-------------------|
| `Problem.lean` | `Problem.lean` (types only: uses `foundations.Tamari.EMLTree`) |
| `Generation.lean` | `Generation.lean` (WFC generation, superposition) |
| `Boundlessness.lean` | `Boundlessness.lean` (boundedness evaluator) |
| `TemporalParadox.lean` | `TemporalParadox.lean` (grandfather cost via `frictionDensity`) |

**Transitive dependents** preserved as `.lean.old` (they imported old-core APIs that no longer compile):

- `LiarParadox`, `SoritesParadox`, `RussellsParadox`, `PosetQuotient`, `TamariBP`
- `FrictionLagrangian`, `QuantizedType`, `SplitOctonionCost`, `DecisionComposition`
- `TropicalTamariLattice`, `TropicalCovector`, `SplitOctonionLogic`

**New module**: `ParadoxAxioms.lean` — extracted `IdentityZeroDivisor` from old `LiarParadox`,
foundation-independent (only imports `foundations.Tamari`). Updated `Hopf.lean` to use it.
`Entanglement.lean` had its stale `QuantizedType` import removed.

### Phase 3: Application files moved from `staging/` to `LaserCortex/`

- `Friction.lean` — `frictionDensity : ℕ → ℕ`, `assocDefect`, `commDefect`, phase change theorems
- `Composition.lean`, `OctilinearEmbedding.lean`, `TropicalTypeAlgebra.lean`, `GraphitiEmbedding.lean`
- The `staging/` directory was deleted
- `lakefile.toml` staging library entry removed
- All module path references updated across the codebase

### Build status

`lake build` succeeds (194 jobs). Only pre-existing linter warnings in `EMLRegistry.lean`
(unused tactics in long `contracts_to` proofs).

---

## 2. What Exists (After Phases 1–3)

The cost model after the reorganisation:

```
foundations/Tamari.lean:
  dcStep : EMLTree → ℕ                     — Tamari distance to right-comb

LaserCortex/Friction.lean:
  frictionDensity : ℕ → ℕ                  — Γ_k = k + 4·assocDefect(k)
  assocDefect(k) = if k ≤ 2 then 0 else 4  — phase change at CD 2→3

LaserCortex/SubdivisionClosure.lean:
  weightedCost (cd : ℕ) (t : EMLTree) : ℕ  — dcStep t × frictionDensity cd

LaserCortex/AMM.lean:
  crossImpactTree, associatorCostTree, reserveGuard, certifiedClose
  — uses cd : ℕ, not LogicType; already grounded in weightedCost

LaserCortex/TemporalParadox.lean:
  grandfatherCost (k : ℕ) : ℕ              — frictionDensity k (pure ℕ parameter)
```

The pieces are in place but **not composed into a unified cost function** at the foundation level.
There is no:

```lean
def cost (cd : ℕ) (t : EMLTree) : ℕ := weightedCost cd t
```

in the foundations — it lives in `SubdivisionClosure.lean` (which is an application layer).
And `Generation.lean` and `Problem.lean` still import `LaserCortex.LogicTypes` (old core)
for the 15-type enumeration's `cdStep` and `isAssociativeSector` properties.

---

## 3. What the Docs Say Should Happen (Phase 5)

Three documents specify what "absorb NodeCost + cdStep" means:

### 3.1 `docs/AMM_MARKET_CLOSURE_REDESIGN.md`

The AMM redesign plan. Phases 1–4 are **already largely implemented** in the new AMM.lean.
The remaining action from this doc is:

- **Phase 3**: Update dependents. `Hopf.lean` was already retargeted. `FrictionLagrangian.lean`
  and `SplitOctonionLogic.lean` are `.lean.old` (old core) — they are the dependents that need
  rewriting if revived.
- **Phase 4**: Python bridge. `infra/_cortex/_cost.py` still has the old 15-entry `NodeCost` class
  and `phi` function. Should redirect to `weightedCost(cd, tree)`.

### 3.2 `docs/GLM-5-2_on_gaps.md` (concrete next steps)

The gap analysis lists five actions, two of which apply to active code:

1. **Replace `native_decide` with `decide`** in `frictionDensity_at_cl11_boundary`
   (`LaserCortex/Friction.lean:87`). Γ₂ = 2 is trivially kernel-checkable.
2. **Wire `LodayCoords` into the integration layer**. The Loday embedding
   (`lodayCoord : EMLTree → List ℕ`, injective) should be used to compute `dcStep` or
   `weightedCost` through Loday coordinates — connecting the tree-coordinate layer to the
   cost layer.
3. **Execute the `liarCost → layerCost` migration** — make Γ the live cost in the paradox layer.
   Since `LiarParadox.lean` is `.lean.old`, this means ensuring the new `TemporalParadox.lean`
   and `Boundlessness.lean` use `frictionDensity` directly (which they already do).

### 3.3 `docs/type_theory_map.md`

The type theory map provides the **geometric picture** of what the cost function means:

```
                    ┌──────────────────────┐
                    │   Interior Region    │
                    │  (non-degenerate)    │
                    │  |S₂| = |S₃| = 1     │
                    └────────┬─────────────┘
                             │
            River of Degeneracy (|Sⱼ| > 1)
                             │
       ┌─────────────────────┼────────────────────────┐
       │                     │                        │
  ┌────┴─────┐          ┌────┴───────┐          ┌─────┴─────┐
  │ S₂-ville │          │ Confluence │          │ S₃-ville  │
  │ (left)   │──────────│  (45°      │──────────│ (right)   │
  │ CFG₁     │  bridge  │   edges)   │  bridge  │ CFG₂      │
  └────┬─────┘          └────┬───────┘          └────┬──────┘
       │                     │                       │
       │    River of Regular Subdivision             │
       └─────────────────────┬───────────────────────┘
                             │
                    ┌────────┴─────────┐
                    │     ZD Strait    │
                    │  (cdStep 2 → 3)  │
                    │  assocDefect:    │
                    │    0  →  4       │
                    └────────┬─────────┘
```

The key insight from `type_theory_map.md` for Phase 5:

- **The ZD Strait** (cdStep 2→3) is where `assocDefect` activates. This IS the phase change.
- **The River of Regular Subdivision** is the constraint that only certain (S₂, S₃) pairs are
  realizable — this is the `dcStep` measure, which is the Tamari lattice distance.
- **S₂-ville and S₃-ville** are the left-weight and right-weight communities in the CFG grammar.
  The cost `weightedCost cd t = dcStep t × frictionDensity cd` factors through these communities:
  `dcStep t = leftWeight t + t.size` (which relates to S₂) has a symmetric right-weight relation.

The absorption of NodeCost into the cdStep × frictionDensity product means the **98-parameter
space (14 logics × 7 NodeCost fields) collapses to ℕ (cdStep)** with a single friction coefficient.
The 7 NodeCost configurations from the old model are not needed because the cost per flip is
determined entirely by the CD step — each logic type's cost is just its cdStep's friction density
applied to the tree's dcStep.

---

## 4. Phase 5: What Remains

### 4.1 Lean changes

| Action | File | Doc source |
|--------|------|-----------|
| `native_decide` → `decide` | `Friction.lean:87` | GLM-5-2 step 1 |
| Add `cost cd t := weightedCost cd t` to `Friction.lean` | `Friction.lean` | AMM redesign, type theory map |
| Remove `LogicTypes` import from `Problem.lean` | `Problem.lean` | AMM redesign (replace `LogicType` with `ℕ`) |
| Remove `LogicTypes` import from `Generation.lean` | `Generation.lean` | AMM redesign |
| Replace `AntiCoherentPair coherent/antiCoherent : LogicType` with `ℕ` | `Generation.lean` | Cost is per-cdStep, not per-logic-type |
| LodayCoords integration | `LodayCoords.lean` → `Friction.lean` | GLM-5-2 step 4 |

### 4.2 Python changes

| Action | File | Doc source |
|--------|------|-----------|
| Archive `NodeCost` class, redirect to `weightedCost(cd, tree)` | `infra/_cortex/_cost.py` | AMM redesign Phase 4, deferred |

### 4.3 What stays as-is

- `foundations/` — clean, no changes needed
- `SubdivisionClosure.lean` — already correct
- `AMM.lean` — already uses `cd : ℕ`, `weightedCost`
- `TemporalParadox.lean` — already uses `grandfatherCost k = frictionDensity k`
- `Entanglement.lean` — clean
- `Hopf.lean` — already retargeted to `ParadoxAxioms`

---

## 5. Open Questions

1. **Do `Problem.lean` and `Generation.lean` need LogicType at all?** The `AntiCoherentPair`
   stores two logic types and uses `cdStep` and `isAssociativeSector`. If we store `ℕ` instead,
   we lose `isAssociativeSector` — but that's derivable: `isAssociativeSector(cd) := cd ≤ 2`.
   The 15 concrete pairs (`liar`, `barber`, `grandfather`, etc.) collapse to (cd₁, cd₂) pairs.

2. **Does `LodayCoords` integration add anything** for the cost function? `weightedCost` already
   computes correctly via `dcStep × frictionDensity`. Loday coordinates give a coordinate-vector
   representation but the cost doesn't need it. The integration is "nice to have" (GLM-5-2 step 4)
   but not blocking.

3. **Do we still need `LogicTypes.lean`?** It defines `LogicType` with 15 constructors, the
   pentagon weakening hierarchy, `logicFactorization` theorems, and the `cdStep_eq_pentagonatorDepth`
   derivation. Some of this is genuine theory (the pentagon weakening classification). Some is
   scaffolding (the 15-type enumeration as a concrete type). The cost model doesn't need it; but
   other applications (canvas app logic-type selection, the infra layer's type system) might.

---

## References

- `docs/type_theory_map.md` — the full map of the type theory terrain
- `docs/AMM_MARKET_CLOSURE_REDESIGN.md` — AMM redesign with weightedCost formula
- `docs/GLM-5-2_on_gaps.md` — gap analysis with concrete steps 1–5
- `lab_notes/031_ic_is_regular_subdivision.md` — IC is weighted regular subdivision
- `lab_notes/032_tropical_type_theory_hypothesis.md` — types as coordinates
- `lab_notes/035_label_propagation_vs_generation_oscillation_ab_test.md` — prior lab note
- `docs/lab_protocol.md` — research protocol (v0.3)
