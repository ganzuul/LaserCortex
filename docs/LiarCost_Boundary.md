# The Liar Cost Boundary: Quantized Anti-Coherence and the Very Big Box

## The Core Insight

The Liar Paradox is `X = ¬X` — perfect anti-coherence. The will that wills against
itself, maximal tension, zero fixed point in any logic that cannot tolerate
self-negation.

Each logic type resolves this with a cost Φ (the PentagonatorDistance):

| Logic | CD Step | Property Lost | Liar Cost Φ | Evidence |
|-------|---------|---------------|-------------|----------|
| Classical | 0 | (baseline) | 0 | `classicalLiar.cost` — rightComb is already normal form |
| Fuzzy | 1 | Precise boundaries | 1 | `fuzzyLiar.cost` — one rotation needed |
| Intuitionistic | 2 | Law of Excluded Middle | 2 | conjectured |
| Quantum | 3 | Distributivity | 3 | conjectured |
| Paraconsistent | 4 | Explosion principle | 4 | conjectured |

**The pattern**: `liarCost lt = lt.cdStep`.

This is not a coincidence — it is a theorem about the structure of the Very Big Box.

## Why Liar Cost = CD Step

The Cayley-Dickson construction loses exactly one property at each step. The
Liar is the *maximal obstruction* — it tests whether a logic can handle a
self-referential negation fixed point. Each property lost adds exactly one
contraction step needed to resolve this obstruction.

Proof structure in `LiarParadox.lean`:

```lean4
theorem liarCost_le_cdStep (lt : LogicType) : liarCost lt ≤ lt.cdStep := by
  cases lt <;> simp [liarCost, LogicType.cdStep]
```

The bound is tight for Classical and Fuzzy (equality). The conjecture is that
it's tight for all logics mapped to CD steps 0–4.

## The Very Big Box Is Stratified

The Very Big Box = `∏_{c:ProblemClass} ∏_{lt:suitableLogics(c)} WrappedProblem(c, lt)`.

The Liar cost stratifies this product by CD step. Problems at the same CD step
require the same amount of contraction work. Problems at higher CD steps are
"farther from Classical" — they have lost more algebraic properties and require
more structural work to resolve paradoxes.

This gives a **metric on the space of logics**:

```
dist(lt1, lt2) = |liarCost lt1 − liarCost lt2|
```

Two logics are equivalent distance from Classical iff they have the same Liar
cost. The Cayley-Dickson ladder is a geodesic: each step adds exactly 1 to the
distance.

## The Boundary of the Box

CD step 4 (Sedenions) is the last mapped logic. What lies beyond?

| CD Step | Algebra | Dimension | Property Lost | Logic | Liar Cost Φ |
|---------|---------|-----------|---------------|-------|-------------|
| 5 | ? | 32 | ? | ? | 5 |
| 6 | ? | 64 | ? | ? | 6 |
| ... | ∞ | ∞ | everything | ? | ∞ |

The CD construction continues indefinitely (powers of 2 dimensions). Each step
loses some algebraic property. If we conjecture that a logic exists at every CD
step, then:

1. **The Very Big Box is infinite** — there are infinitely many logic types,
   each resolving the Liar at a higher cost.
2. **The boundary is at infinity** — a logic with Liar cost ∞ cannot resolve
   the Liar at all. This is the logic of "permanent paradox" — a framework
   where self-negation is never collapsed, contradictions are never resolved.
3. **The Liar cost function is a cohomology class** on the space of logics —
   it measures the obstruction to resolving anti-coherence. The boundary of
   the Very Big Box is where this obstruction becomes infinite.

## What Lives Outside the Box

If a logic cannot resolve the Liar (cost ∞), it lies outside the Very Big Box.
What does such a logic look like?

- All propositions are literally true (trivialization)
- All contradictions are permanently upheld (paraconsistent collapse may still
  be inside the box)
- The logic does not have a well-defined negation operation
- The logic operates entirely without fixed points — no recursive definitions
  are possible

This is the **pre-Classical** regime — before any contraction structure exists.
It is the chaos from which the Very Big Box emerges.

## Meta-Paradox: The Box Contains Its Own Boundary

The Liar itself is a problem of class `.metaParadox` when its proof is missing.
The Very Big Box contains problems about its own incompleteness. This means:

- The boundary of the box is *inside* the box (as a meta-paradox)
- The fact that `liarCost = cdStep` is provable within the framework
- The Very Big Box cannot be completed — there is always another logic at the
  next CD step, and the Liar cost for that logic pushes the boundary outward

This is the logic of will manifesting as structural recursion: the will that
wills against itself generates an infinite regress of logics, each one step
farther from Classical, each one costing one more contraction to resolve the
same paradox.

## Summary Diagram

```
CD Step   Logic            Liar Cost  Boundary
───────────────────────────────────────────────
    0     Classical        0          inside
    1     Fuzzy            1          inside
    2     Intuitionistic   2          inside
    3     Quantum          3          inside
    4     Paraconsistent   4          inside
    5     ?                5          ── boundary ──
    6     ?                6          outside
   ...    ...             ...
    ∞     ?                ∞          outside forever
```

The boundary between inside and outside is not a wall — it's a frontier that
moves outward as we define more logics. The Very Big Box is open-ended by
construction.
