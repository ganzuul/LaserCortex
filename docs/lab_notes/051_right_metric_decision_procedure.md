# Lab Note 051 — How to Know We've Found the Right Metric

**Date**: 2026-08-26
**Follows**: 049_loose_coupling_risk_window.md, 050_elasticity_certification_boundary.md
**Prior art**: CoherenceMetric.lean (split-signature guess), ImpedanceMetric.lean (041)
**Status**: SWEEP SURVIVES (C2 exhaustive to size 6)

## 1. Question

Notes 049–050 flagged the missing piece for full mechanics language: a
metric on tree space. But many metrics satisfy the metric axioms. The real
question is methodological:

> **By what procedure would we decide that a candidate metric is THE
> metric — not merely A metric?**

## 2. The decision rule

A candidate is *right* when it turns our existing cost theorems into
metric-space truisms:

> **Adopt iff C0 ∧ C1 ∧ C2 ∧ C3 proven, C4 discrimination green, and
> C5 uniqueness holds.**

| # | Criterion | Content | Verdict artifact |
|---|---|---|---|
| C0 | Well-definedness | genuine metric: pos/sym/triangle | Lean lemma |
| C1 | Generativity | induced by `contracts_one` flips with γ-weighted edges | def |
| **C2** | **Potentiality** ⭐ | `weightedCost cd t = d(t, rightComb t.size)` — cost IS geodesic distance to closure; superadditivity becomes triangle inequality | headline theorem |
| C3 | Mechanical compatibility | envelope/Hooke restate as Lipschitz/ball statements; λ-discount = conformal rescale of interface edges only | restatement lemmas |
| C4 | Discrimination | brute-force kills trivial rivals (discrete, size) | Python sweep |
| **C5** | **Uniqueness** ⭐ | any other C2-satisfying metric dominates ours pointwise → universal property: we found THE metric, not A metric | Lean theorem |

Falsify first, prove second: cheap computation before Lean investment.

## 3. The candidate

The **γ-weighted Tamari graph metric**: shortest path through the flip
graph whose edges are single `contracts_one` rotations, each costing one
unit of grind γ(cd). `CoherenceMetric.lean` already guessed its shadow:
dcStep as the "timelike" coordinate = flip-count distance to the normal
form.

Signature conjecture (**C2**): the greedy rotation count that `_dcstep`
computes equals the *geodesic* count — i.e. no clever rotation order beats
greedy on the way to closure.

## 4. Sweep results (`scripts/metric_sweep.py`)

Exhaustive Dijkstra over the full flip graph:

```
  size 1..6 : 1+2+5+14+42+132 = 196 trees
  C2 potentiality: OK at every size   (dcStep = geodesic, zero failures)
  C0 triangle inequality (undirected all-pairs, sizes ≤5): OK
  C4 discrete metric rejected (geodesic range reaches n−1 > 1): OK
  C4 size-metric rejected (nonzero distances exist): OK
  C4 dcStep separates same-size trees: OK
```

**CANDIDATE SURVIVES.** Greedy = geodesic exhaustively. Note the shape:
max distance at size n is n−1 (the left comb is the farthest point from
closure) — the cone has linear depth.

## 5. Phase 2: adjudication vs the split signature

CoherenceMetric defines ⟨dcStep, dcStep⟩ = dcStep² − γ²: lightlike iff
dcStep = γ. With C2 verified these are **layers, not rivals**: d_γ
supplies the distance; the Minkowski form classifies each geodesic
against the per-flip mass. Census of all 196 size-6 routes by logic band:

```
logic band        cd  γ   spacelike(<γ) lightlike(=γ) timelike(>γ)
classical/boolean  0  0       0             1            131
institutional      1  1       1             5            126
intuitionistic     2  2       6            14            112
quantum band       3 19     132             0              0
paraconsistent     4 20     132             0              0
```

**Computed finding**: the critical point is not only where grind jumps —
it is where the ENTIRE route population crosses the lightcone. At
cd ≤ 2 most routes are timelike (longer than their own mass); at cd ≥ 3
(γ = 19 > max dcStep = 5) every small route is spacelike. The known
thermodynamic critical point reappears as a **population-wide lightcone
inversion** — independent evidence that both layers describe the same
geometry.

## 6. What remains for adoption (honest ledger)

- C0/C1/C2 in Lean: definitions plus the potentiality theorem. The
  computational evidence is exhaustive but Lean needs the graded-lattice
  argument (Tamari rank = dcStep ⇒ greedy = geodesic).
- C3 restatements of §9–§10 theorems as Lipschitz/ball statements.
- C5 minimality: expect provable via "any metric making cost 1-Lipschitz
  with unit flip steps is dominated by d_γ".

## 7. Next steps

1. Lean: `tamariDist` via Mathlib `SimpleGraph.dist` or custom; prove
   `weightedCost_eq_geodesic`.
2. C3: restate rescue envelope as ball-containment.
3. Strain/stress dictionary: strain = Tamari distance (now justified as
   geodesic), stress = friction work; viscoelastic earned-trust λ(state).
