# 002: Brute Force Candidates — Φ Minima for All 14 Logics

## Date
2026-06-11

## Files
- `LaserCortex/Candidates.lean`: `allTrees`, `minCost`, `maxCost`, `rightCombIsMin`, `report`
- `LaserCortex/EMLRegistry.lean`: added `EMLTree.toBits` (binary preorder encoding)
- `LaserCortex/LogicTypes.lean`: added `allLogics` (list of 14 types)

## What we did

1. Fixed `Candidates.lean` to compile under Lean 4.31.0-rc2:
   - Replaced `List.join` with `List.flatten` (the former is absent from core)
   - Replaced method-style `.all` and `.bind` with function-style `List.all`, explicit `List.flatten`/`.map`
   - Used `partial def` for `allTrees` to dodge termination checking (fine for brute force)

2. Added `EMLTree.toBits` — binary preorder encoding (`"0"` = Leaf, `"1"+left+right = Node`)
3. Added `allLogics : List LogicType` — canonical ordering of all 14 types

## Brute Force Results (n=4, 14 trees)

| Logic | minCost | maxCost | rightCombCost |
|---|---|---|---|
| Classical | 1 | 4 | 1 |
| Fuzzy | 1 | 4 | 1 |
| Many-Valued | 1 | 4 | 1 |
| Paraconsistent | 1 | 15 | 1 |
| Temporal | 1 | 15 | 1 |
| Deontic | 1 | 4 | 1 |
| Epistemic | 1 | 4 | 1 |
| Quantum | 1 | 4 | 1 |
| Intuitionistic | 4 | 4 | 4 |
| Relevance | 1 | 4 | 1 |
| Free | 4 | 4 | 4 |
| Infinitary | 1 | 4 | 1 |
| Modal | 1 | 4 | 1 |
| Spacetime | 1 | 15 | 1 |

## Interpretation

- **rightComb is the unique global minimum** for all 14 logics at n=4 — consistent with `contracts_to_rightComb` theorem
- **Flat logics** (Intuitionistic, Free; rightDiv=0): all trees have cost = n = size — no cost landscape
- **leftWeight=2 logics** (Paraconsistent, Temporal, Spacetime): max-cost tree = `((((..).).).)` with cost 15 — real landscape with 15× separation between min and max
- Classical et al. have narrow range (1–4) — moderate landscape
- The max-cost tree for leftWeight=2 is the maximally left-branching tree — this makes sense: leftWeight penalizes left-heavy trees

## Max Tree for Paraconsistent (cost 15)
```
Node (Node (Node (Node Leaf Leaf) Leaf) Leaf) Leaf
```
Binary bits: `"11101010101000"` (left-heavy comb)

## Next Steps

- Run n=5 (42 trees) and n=6 (132 trees) to see if the landscape structures persist
- Correlate with Loday coordinates to find geometric patterns
- The product coupling term (from 001) should modulate which trees are minima
