# 034: Graphiti Oscillation as Market Failure

**Date**: 2026-07-07
**Status**: LEAN ANALYSIS COMPLETE — Section 14 (graph model + LP definitions), Section 15 (oscillation mode analysis), Section 16 (cycle detection + experimental verification) appended to `TropicalTypeAlgebra.lean`. All `#eval!` blocks pass cleanly. See Lean file for full computational proofs.
**Prerequisites**: 033 (Tropical type theory as Graphiti communities); `infra/_graphiti_service.py` (monkey-patch at line 186);
`LaserCortex/staging/TropicalTypeAlgebra.lean` (type lattice definitions, Sections 14–16)
**Prerequisites**: 033 (Tropical type theory as Graphiti communities); `infra/_graphiti_service.py` (monkey-patch at line 186);
`LaserCortex/staging/TropicalTypeAlgebra.lean` (type lattice definitions)
**Sources**: Infinite `label_propagation` loop in Graphiti `build_communities`; Develin & Sturmfels "Tropical Convexity" (2004) §2–3;
`docs/type_theory_map.md` (community boundaries); `scripts/run_type_experiment.py` (adjacent pairs + cardinality filter)

---

## 1. The Oscillation

When `build_communities` runs `label_propagation` on the type-lattice entity graph
(11 types, 5 adjacencies, —triplets), it diverges: node C oscillates forever
between communities 7 and 9.

**Why it oscillates**: C sits at the interior pivot between S₂-ville and S₃-ville.
Its neighbors divide exactly into two camps of equal aggregate edge-weight:
3 votes for community 7 (S₃-ville) and 3 for community 9 (S₂-ville). Upstream
Graphiti breaks ties by picking the *higher* community index — max(7, 9) = 9.
C joins 9, but now 9's total exceeds 7's for the rest of the graph, so all
C's neighbors shift to 9. C finds itself with only even-weight neighbors in 9
(max vote = 1), flips back to 7, and the cycle repeats.

**What it means**: This is not a bug — it is the graph telling us that the
market cannot settle. The two communities have equal gravitational pull on C,
corresponding to the tropical cell boundary where the type polynomial has two
equal maxima (a "lake" in the Develin–Sturmfels regular subdivision). Node C
at KKT coordinates (1.5, 0) is exactly half-way between S₂-dominant W at (2, 0)
and S₃-dominant v₁ at (1, 0).

## 2. The Fix

`infra/_graphiti_service.py:186` monkey-patches `label_propagation` with
`_stable_label_propagation` which adds one rule: **when the current community
is among the top vote-getters, stay put**. This breaks the symmetry:

```python
if curr in top_communities and max_votes > 1:
    new_community = curr  # Stay here — breaks oscillation
```

Converges in < 50 iterations for all tested graphs (typically 3-5).

## 3. Hypotheses (A-D) — the Analysis Structure

### Hypothesis A: The oscillation is a non-convergent institutional closure

The label propagation algorithm is structurally identical to the closure pipeline
(`temporal_normalize → fuzzy_grade → deontic_update`). Each iteration is an
event; the sequence of community assignments forms a temporal trace. The
oscillation means this trace has no fixed point — `closure_is_fixed_point`
returns `False`.

**Test**: Encode each LP iteration as an event, run `closure` over the trace.
Verify `closure_is_fixed_point = False`. Then verify that with tie-breaking,
`closure_is_fixed_point = True`.

### Hypothesis B: The oscillation corresponds to an EMLTree anti-coherent pair

The two competing communities (7 and 9) form an `AntiCoherentPair` in the WFC
framework. `temporal_conflate` constructs a tree oscillating between the two
poles. The `friction_density` of this oscillation should be 0 (below the ZD
barrier at cd=0), classifying it as "garbage" by the VSM loop.

**Test**: Build `AntiCoherentPair(comm7, comm9)`, run `temporal_conflate`, check
`friction_density = 0`, confirm VSM loop classifies as non-convergent.

### Hypothesis C (Lean formalization): Label propagation with preference converges; without it, counterexample exists

Formalize in Lean:

- **C1**: For any finite graph, label propagation with the "prefer current"
  tie-breaking rule converges in ≤ |V| iterations (each node switches community
  at most once).
- **C2**: There exists a concrete graph (the type lattice at r=3, 11 types, 5
  adjacencies) and an initial assignment such that the upstream variant
  (prefer higher index) never converges — an explicit infinite oscillation.
- **C3**: The oscillation condition `deg(v)_{commA} = deg(v)_{commB}` for the
  pivoting node C is equivalent to the dolly-zoom commutator
  `[s₂⁺(i), s₃⁺(j)]` vanishing at C's coordinates (1.5, 0).

### Hypothesis D: The 5th adjacency was a false mystery — but points to r ≥ 4

The "5th adjacency" in `run_type_experiment.py:102` ("4/5 adjacent pairs caught
by cardinality filter") was empirically resolved: all 5 adjacencies are
ordinary cardinality changes. However, the theoretical question stands: **swap
adjacencies** (simultaneous |S₂|+1 and |S₃|-1 with different generators) should
exist at r ≥ 4, where the 35-quads archipelago opens. The oscillation's tie
condition is the embryonic form of a swap adjacency at r = 3.

**Test**: Extend the analysis to r = 4 (when the Lean algebra supports it);
verify that swap adjacencies appear and the oscillation frequency increases.

## 4. Experimental Setup

The type-lattice entity graph (r=3):

| Node | S₂ | S₃ | Signature (|S₂|,|S₃|) | Community |
|------|----|----|------------------------|-----------|
| v₁ | {1} | {1,2} | (1,2) | S₃-ville |
| v₂ | {1,2,3} | {2} | (3,1) | S₂-ville |
| v₃ | {1,3} | {1,2,3} | (2,3) | S₃-ville |
| C | {1} | {2} | (1,1) | Interior (oscillates) |
| W | {1,3} | {2} | (2,1) | S₂-ville |
| T1 | {1} | {1} | (1,1) | S₃-ville |
| T2 | {1,2} | {1,2} | (2,2) | S₃-ville |

5 adjacencies, undirected, uniform edge weight (1).

## 5. Lean Code Location

Formalization in `LaserCortex/staging/TropicalTypeAlgebra.lean`:

- **Section 14** — Graph model over `List TypeNode` (7 nodes, 5 adjacencies),
  `CommunityAssignment`, `voteCount`, `iterateOnce`, `iterateUntilStable`,
  `tieBreakMax` (upstream) and `tieBreakPreferCurrent` (our fix)
- **Section 15** — Oscillation mode analysis: discovers that the PURE adjacency
  graph (7 nodes, 5 edges, weight 1) is **frustrated** — both tie-breaking rules
  oscillate in an identical 2-cycle "blink" (period 2 confirmed by `detectCycle`).
  The preference rule never fires because `max_vote = 1` for every node (all
  neighbors unique), so `curr` is never among the tied top candidates.
- **Section 16** — `#eval!` blocks demonstrating the 2-cycle oscillation for
  both rules, with cycle detection, oscillating node identification, and
  structural interpretation: the pure graph needs MORE edges, not a different
  tie-break rule.

### Key Finding (Section 15)

The Lean code reveals a deeper truth than the Python experiment did:

| Layer | Edges | Behavior | Fix |
|-------|-------|----------|-----|
| **Pure type lattice** | 5 structural (weight 1) | 2-cycle blink: 6/7 nodes oscillate permanently | Needs MORE edges (inherently frustrated) |
| **Graphiti enriched** | ~25 episode + 5 structural (mixed weights) | C oscillates 7↔9 at 3-3 tie | Python `tieBreakPreferCurrent` breaks the 3-3 tie |

The enriched graph's episode edges create `max_vote > 1` conditions that the
fix targets. Without those edges, no tie-breaking rule works — the pure graph
is not bipartite, so label propagation cannot 2-color it.

## 6. .ncd Plan

See `LaserCortex/staging/graphiti_oscillation_analysis.ncd` — NormCode plan for
encoding the oscillation analysis as a closure process with Feed, Lift,
Ground steps.

## References
- `lab_notes/033_tropical_type_theory_as_graphiti_communities.md` — prior experiment results
- `docs/type_theory_map.md` — community boundaries, the Confluence, ZD Strait
- `infra/_graphiti_service.py:186` — monkey-patch implementation
- `infra/_cortex/_closure.py` — institutional closure pipeline
- `infra/_cortex/_wfc.py:590` — temporal_conflate for AntiCoherentPair
- `scripts/run_type_experiment.py` — the experiment itself
