# AMM + MarketClosure Redesign: Grounding in SubdivisionClosure

## Motivation

The old AMM cost function `Φ L t` (14 LogicTypes × 7 NodeCost parameters = 98
coefficients) was scaffolding that the CD tower already replaces natively: each
`dcStep` IS the number of Tamari flips, and `frictionDensity cd` IS the cost
per flip. The 98-parameter space collapses to `ℕ` (cdStep) with a single
friction coefficient.

## Structural insight

`dcStep` has a clean recursive definition:
```
dcStep .Leaf = 0
dcStep (.Node .Leaf r) = dcStep r
dcStep (.Node (.Node a b) r) = 1 + dcStep (.Node a (.Node b r))
```

This means:

- **`crossImpactTree`**: `dcStep(.Node t1 t2) - (dcStep t1 + dcStep t2)` is tree-shape-dependent.
  When `t1 = Leaf`, it's 0. When `t1 = Node a b`, it's `1 + dcStep(Node a (Node b t2)) - dcStep(t1) - dcStep(t2)`.

- **`associatorCostTree`**: `dcStep(Node(Node t1 t2) t3) = 1 + dcStep(Node t1 (Node t2 t3))`
  by definition, so `associatorCostTree cd t1 t2 t3 = |1| × frictionDensity cd = frictionDensity cd`.
  The associator cost is **constant per flip** — always exactly one flip's worth
  of friction, independent of tree shape. This replaces the old "zero for
  classical" result (which was an artifact of the tree-size cost being too coarse).

- **`reserveGuard`** checks `weightedCost cd tree ≥ pool.reserveB`.

- **`certifiedClose`** deducts `weightedCost cd tree` from the swap price.

## Phases

### Phase 1: Rewrite `AMM.lean`
- Replace `EMLRegistry` + `Cost` imports with `SubdivisionClosure`
- Replace `LogicType` parameter with `cd : ℕ`
- Replace `Φ L t` with `weightedCost cd t`
- Keep `Pool`, `Route`, `routeToTree` user API
- New theorems:
  - `crossImpactTree_factor cd t1 t2` — factors out frictionDensity
  - `associatorCostTree_factor cd t1 t2 t3` — factors out frictionDensity
  - `associatorCostTree_eq_frictionDensity cd t1 t2 t3` — always exactly `frictionDensity cd`
  - `crossImpactTree_assoc_regime` / `nonassoc_regime` — phase change
  - `associatorCostTree_assoc_regime` / `nonassoc_regime` — phase change

### Phase 2: Absorb `MarketClosure.lean` → delete
- `MarketType` → an enum or just use `ℕ` (cdStep) directly
- `CertifiedPrice` → absorbed into new AMM
- `blameToBudget` → maps to `dcStep t × frictionDensity cd`
- `decideMarketType` → phase check: `cd ≤ 2` is open, `cd ≥ 3` is closed if reserveGuard passes
- `marketClosure` → direct computation: `weightedCost cd tree` is the price
- No remaining Lean dependents on MarketClosure → delete file

### Phase 3: Update dependents
- `Hopf.lean`: retarget `AMM.reserveGuard` + `Cost.Φ` to `weightedCost cd tree`
- `FrictionLagrangian.lean`: update `Cost.Φ_eq_size_classical` usage
- `SplitOctonionLogic.lean`: update `Φ_agreement` theorem
- `LaserCortex.lean` umbrella: add `AMM` import, remove `Cost` (already not imported)

### Phase 4: Python bridge (deferred)
- `_bridge.py`: `compute_phi(L, tree)` → `weightedCost(cd, tree)`
- `_cost.py`: archive

## File changes

| Action | File |
|--------|------|
| Rewrite | `LaserCortex/AMM.lean` |
| Absorb + delete | `LaserCortex/MarketClosure.lean` |
| Update | `LaserCortex/Hopf.lean` |
| Update | `LaserCortex/FrictionLagrangian.lean` |
| Update | `LaserCortex/SplitOctonionLogic.lean` |
| Update | `LaserCortex.lean` |
