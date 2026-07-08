# Product Coupling Term for Φ Tensegrity

**Date:** 2026-06-11  
**Status:** Idea

## Problem

Current `NodeCost.apply`: `bias + leftWeight * a + (b / (rightDiv + 1))`

This is linear in both subtrees — cost differences between adjacent trees at same size n are O(1), so the lattice collapses into a nearly flat surface. No tensegrity.

## Proposal

Add a product coupling parameter `coupling : Nat` to `NodeCost`:

```
apply(a, b) = bias + leftWeight * a + (b / (rightDiv + 1)) + coupling * a * b / denom
```

Where `denom` is a scaling factor (e.g. `n^2` for tree size n, or fixed like 10).

The product term `coupling * a * b` creates geometric (exponential-like) tension: two adjacent high-cost vertices produce much higher cross-impact than the sum of their parts, giving the lattice genuine curvature.

## Effect

- `coupling = 0`: current behavior (flat lattice for rightDiv=1)
- `coupling = 1`: adjacent costs amplify each other — creates a "potential well" around rightComb where `a * b` is minimal, and "potential ridges" around leftComb where `a * b` is maximal
- `coupling > 1`: strong force regime — cost landscape becomes sharply curved, pentagon defects become large

## Physical Analogy

Matches the strong force: `Φ` potential includes a gluon self-coupling term (the product). The associator knot is tied when the product term dominates — two subtrees can't both be high-cost simultaneously without creating a topological obstruction.

## Integration

- Update `NodeCost` in both `Cost.lean` and `_cost.py`
- Update `Cost.lean`: add `coupling` field, update `apply`, reprove all theorems with the new term
- Update `nodeParam` for each logic type — assign `coupling > 0` to logics in the non-associative split-octonion sector (e₄–e₇)
- This will break existing proofs; most should still go through with `omega`/`simp` since the product term is non-negative

## Questions

1. Should `denom` be a free parameter per logic, or derived from `n` (tree size)?
2. Should we reserve `coupling = 0` for classical logics (rightDiv=0) and `coupling > 0` for non-classical?
3. Does the product term need a floor-division variant for the `Nat` arithmetic, or should we use `Nat` multiplication directly (which can overflow)?
