# 035: Label Propagation Oscillation vs Generation Cycle — A/B Test Design

**Date**: 2026-07-07
**Status**: EXPERIMENT DESIGN — apparatus definition phase; Lean code extraction pending
**Prerequisites**: 034 (Graphiti oscillation as market failure — LEAN ANALYSIS COMPLETE);
`LaserCortex/staging/TropicalTypeAlgebra.lean` Sections 14–16 (label propagation model, oscillation detection);
`LaserCortex/Generation.lean` (paradox generation: inflate → temporalConflate → revise);
`LaserCortex/Boundlessness.lean` (IdempotentResolution — idempotence as the definition of boundedness);
`LaserCortex/SubdivisionClosure.lean` (closure on EMLTree via rightComb);
`LaserCortex/TemporalParadox.lean` (grandfatherProblem as leftComb 4)
**Sources**: 034 (oscillation finding); `docs/lab_protocol.md` §"Guiding Principle" (optimization is a lens, not a goal);
Generation.lean Sections 3–8 (AntiCoherentPair, inflate, temporalConflate, Resonates, revise);
Boundlessness.lean (IdempotentResolution, VeryBigBox, rightComb_meta_idemp);
SubdivisionClosure.lean (closure, closure_idempotent, weightedCost)

---

## 1. Motivation

Lab note 034 discovered a period-2 oscillation in label propagation on the
pure type lattice graph (7 nodes, 5 edges, weight 1). The oscillation was
identified as a **grandfather paradox** — the graph cannot 2-color because
the pivot node C sits on the `|S₂| = |S₃|` split boundary.

But the paradox framework already has a grandfather paradox in
`Generation.lean`: `AntiCoherentPair(CLASSICAL, TEMPORAL)` → `temporalConflate`
→ `Node(rightComb 0, rightComb 1)`. This tree also cannot settle — the
classical and temporal resolutions coexist in the associative sector, so
neither is uniquely preferred.

**Are these the same oscillation at different levels of abstraction?**

This is a structural question, not a performative one. Per the lab protocol
(§Guiding Principle): "Optimization is a lens, not a goal." The A/B test
is not about speed — it is about whether the graph algorithm's oscillation
and the generation cycle's oscillation share a common algebraic skeleton,
revealing that the type lattice graph is a **projection** of the generation
cycle onto a smaller state space.

### What "same" means

Two oscillations are structurally identical if they share:

1. **Period** — both are period-2 cycles (state A → state B → state A → ...)
2. **Idempotence signature** — the step function `f` satisfies
   `f(f(x)) = f(x)` when converged, and `f(f(x)) ≠ f(x)` when oscillating.
   If both fail idempotence in the same degree (step² ≠ step but step³ = step²),
   they have the same algebraic type.
3. **Superposition residue** — the `revise` step on the oscillating pair
   produces a superposition with exactly one surviving candidate, and that
   candidate can coexist with the host context. If the residue matches,
   the oscillations are projected from the same paradox class.

If all three match, the graph oscillation IS the generation oscillation —
the type lattice is a concrete representation of the `temporalDecision`
paradox. If they differ, the graph oscillation is a distinct phenomenon
with its own classification.

---

## 2. Experiment Apparatus

### 2.1 OscillationDetector — the Lean instrument

The shared instrument for both tests. Parameterized by the state type `α`
and the step function `step : α → α`:

```lean
structure OscillationReport (α : Type) where
  converged : Bool                              -- did it reach a fixed point?
  period : Option ℕ                             -- cycle period (none = no cycle found)
  fixedPoint : Option α                         -- the attracting state (if converged)
  cycleStates : List α                          -- the states forming the cycle (if oscillating)
  stepsRequired : ℕ                             -- iterations to converge or detect cycle

def detectOscillation (α : Type) (step : α → α) (initial : α) (maxIter : ℕ) : OscillationReport α := ...
```

This is the **structural instrument** that replaces the ad-hoc `detectCycle`
from Section 16 (`TropicalTypeAlgebra.lean:933`). The key addition: it
reports not just the period but the **idempotence degree** — the smallest `k`
such that `step^k = step^{k+1}` (for convergent systems, `k=1`; for
period-2 oscillation, `k=2`).

### 2.2 Test A: Label Propagation on Type Lattice

**State type**: `CommunityAssignment` (= `List (TypeNode × ℕ)`)
**Step function**: `iterateOnce` with `tieBreakMax` (upstream) or
`tieBreakPreferCurrent` (patch)
**Initial state**: `initialAssignment` (each node in its own singleton)

Extracted from `TropicalTypeAlgebra.lean` Sections 14–16 into a new file
`LaserCortex/experiments/LabelPropagationOscillation.lean`. The file
imports only the staging core (`Algebra`, `Tamari`, `Friction`) and
has no knowledge of Generation.lean or the paradox framework.

**Sample**: 7 nodes, 5 adjacencies, uniform weight 1 (the pure graph).
**Enriched sample**: same 7 nodes + ~25 episode edges from Graphiti run.

### 2.3 Test B: Generation Cycle

**State type**: A product of the generation state:

```lean
structure GenerationState where
  pair : Generation.AntiCoherentPair           -- the current anti-coherent pair
  tree : EMLRegistry.EMLTree                   -- the temporalConflate result
  superposition : Generation.Superposition     -- after revise
```

**Step function**: one complete generation cycle:

```lean
def generationCycle (gs : GenerationState) : GenerationState :=
  let inflated := Generation.temporalConflate gs.pair
  let revised := Generation.revise gs.pair
  -- If revised is collapsed (single candidate), re-inflate from ProblemClass
  -- If revised is empty (zero divisor), terminate
  -- Otherwise pick the surviving candidate and re-inflate
  ...
```

**Initial state**: `inflate(ProblemClass.temporalDecision)` =
`AntiCoherentPair.grandfather`

**Sample**: 14 ProblemClasses, all tested. Expected oscillators: those whose
revised superposition has exactly one candidate that CAN coexist with
Classical (liar, grandfather). Expected non-oscillators: those whose
revised candidate CANNOT coexist (barber — zero divisor is terminal).

### 2.4 The A/B Comparator

After both tests produce `OscillationReport`:

```lean
structure ABComparison where
  periodMatch : Bool               -- both period-2?
  idempotenceDegreeMatch : Bool    -- same f(f(f(x))) = f(f(x)) degree?
  superpositionResidueMatch : Bool -- both map to Superposition([Temporal])?
  sameParadoxClass : Bool          -- all three matched → same phenomenon
```

The comparator answers: "Is Test A's oscillation the same algebraic object
as Test B's oscillation, instantiated in a different state space?"

---

## 3. Procedure

### Step 1: Break out the graph algorithm

Create `LaserCortex/experiments/LabelPropagationOscillation.lean`:

- Move Sections 14–16 from `TropicalTypeAlgebra.lean` into the new file
- The new file imports `LaserCortex.staging.*` only (Algebra, Tamari, Friction)
- Define `OscillationDetector` and `OscillationReport` here (they live at the
  experiment level, not in the core library)
- Verify it compiles independently of `TropicalTypeAlgebra.lean`

### Step 2: Clean up `TropicalTypeAlgebra.lean`

- Remove Sections 14–16 (label propagation model, oscillation analysis)
- End at the pure algebra (Section 13 — type lattice, split magma, adjacencies)
- Verify the algebra still compiles and all existing theorems pass

### Step 3: Build Test B instrument in Generation.lean or a companion file

The generation cycle needs to be made explicit. Currently Generation.lean
has the building blocks (inflate, temporalConflate, revise, Resonates) but
does not wire them into a step function. Add:

- A function `generationStep (pc : ProblemClass) : GenerationState → GenerationState`
- A `detectOscillation` instantiation for `GenerationState`
- Proofs that specific ProblemClasses produce period-2 oscillation

### Step 4: Run the A/B comparison

For each ProblemClass (14 total):

1. Run Test A — does not apply (Test A is graph-specific)
   → Actually, for Test A we only run on the type lattice graph
2. Run Test B — check oscillation period and idempotence degree
3. Report which ProblemClasses oscillate and with what period

Then compare Test A's result (period-2 on pure graph) with Test B's
result for `temporalDecision` (expected: period-2).

### Step 5: Write the comparison theorem

```lean
theorem graph_oscillation_is_generation_oscillation :
  let graphReport := detectOscillation CommunityAssignment iterateOnce initialAssignment 20
  let genReport := detectOscillation GenerationState generationCycle initialState 20
  graphReport.period = some 2 ∧
  genReport.period = some 2 ∧
  graphReport.idempotenceDegree = genReport.idempotenceDegree := ...
```

This theorem is the formal statement that the type lattice graph oscillation
is the grandfather paradox projected into community detection space. If the
theorem fails, we have discovered a new oscillation class.

---

## 4. Expected Outcomes

### Primary: The oscillations are structurally identical

The pure graph oscillation (period 2, all 6 connected nodes flip) is the
same phenomenon as the `temporalDecision` generation cycle oscillation
(period 2, `Superposition([Temporal])` → `inflate` → `Superposition([Temporal])`).

Why this is meaningful: **the type lattice graph is a projection of the
generation cycle onto a 7-node graph**. The pivot node C's position on
the split boundary `|S₂| = |S₃|` corresponds to the `temporalDecision`
paradox's position in the associative sector (both CLASSICAL and TEMPORAL
are associative, so neither can be eliminated by sector exclusion). The
graph's 5 adjacencies encode the `canCoexist` relations between the 7
representations of the paradox.

### Secondary: The enriched graph oscillation is a degenerate case

With ~25 episode edges, the enriched graph breaks the symmetry. The
generation cycle analogue: introducing a host context where `Resonates`
holds for one pole but not the other — effectively eliminating the
oscillation by forcing a choice. The Python patch's success on the
enriched graph corresponds to the host context providing an external
bias (like `Resonates` succeeding for Temporal but not Classical).

### Tertiary: The `Boundlessness` connection

If the generation cycle is NOT idempotent (`step ∘ step ≠ step`) for
`temporalDecision`, then `Boundlessness.IdempotentResolution` fails for
this paradox — the system is **boundless** with respect to the generation
step. This means the grandfather paradox is not resolvable within the
generation framework alone; it requires external grounding (the host
context providing a Temporal-friendly `Resonates`).

The boundlessness IS the oscillation — not a bug, but the structural
signature of a paradox whose resolution requires moving to a higher
coherence level.

---

## 5. References

- `lab_notes/034_graphiti_oscillation_as_market_failure.md` — prior oscillation analysis (SUPERSEDED for the graph part; retained for historical record)
- `LaserCortex/Generation.lean` — AntiCoherentPair, inflate, temporalConflate, Resonates, revise, Superposition, ViableSystem
- `LaserCortex/Boundlessness.lean` — IdempotentResolution, rightComb_meta_idemp, VeryBigBox
- `LaserCortex/SubdivisionClosure.lean` — closure, closure_idempotent, weightedCost, phase change theorems
- `LaserCortex/staging/TropicalTypeAlgebra.lean` — type lattice (Sections 1–13 remain; Sections 14–16 extracted)
- `LaserCortex/experiments/LabelPropagationOscillation.lean` — extracted graph algorithm (NEW)
- `docs/lab_protocol.md` §"Guiding Principle" — the structural lens
- `infra/_cortex/_wfc.py:544` — GRANDFATHER_PAIR (Python mirror of Generation)
- `infra/_cortex/_wfc.py:590` — temporal_conflate (Python mirror)
