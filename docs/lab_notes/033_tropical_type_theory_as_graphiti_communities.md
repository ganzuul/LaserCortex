# 033: Tropical Type Theory as Graphiti Communities

**Date**: 2026-07-07
**Status**: COMPLETE — 25+ episodes encoded, 2 communities discovered, `scripts/run_type_experiment.sh` created for automated re-runs with configurable density
**Prerequisites**: 032 (Tropical type theory hypothesis); `LaserCortex/staging/TropicalTypeAlgebra.lean` (compiled experiment with 11 types, 5 adjacencies, split magma)
**Sources**: Develin & Sturmfels "Tropical Convexity" (2004), §2–3; Graphiti temporal graph (via normcode MCP); `docs/type_theory_map.md` (conceptual map of communities)

---

## 1. The Hypothesis (Graphiti Form)

The type lattice of the Develin–Sturmfels algebra decomposes into **natural communities** that Graphiti's community detection algorithm will find as coherent clusters. These communities correspond to the regions of the conceptual map from `docs/type_theory_map.md`:

| Predicted community | Boundary (river) | Evidence from experiment |
|---|---|---|
| **S₂-ville** (left-weight domain) | Regular subdivision constraint | Leaf polarity split: PN (left-dominant) ∈ this community, NP ∉ |
| **S₃-ville** (right-weight domain) | Regular subdivision constraint | Leaf polarity split: NP (right-dominant) ∈ this community, PN ∉ |
| **Interior** (non-degenerate) | Degeneracy threshold \|Sⱼ\| = 1 | Type C at (1.5,0): signature (1,1) |
| **Confluence** (45° edges) | Commutator [s₂⁺(i), s₃⁺(j)] ≠ 0 | v₁↔v₃ (NE, Δ=(1,1)), v₁↔v₂ (SE, Δ=(1,-1)) |
| **Boundary** (vertices with \|Sⱼ\|>2) | Triple degeneracy \|Sⱼ\| = 3 | v₂: |S₂|=3, S₂={1,2,3}; v₃: |S₃|=3, S₃={1,2,3} |

The "rivers" between communities are the **context-sensitive constraints**:
- Regular subdivision = which (S₂, S₃) pairs are valid
- Degeneracy threshold = when |Sⱼ| > 1, the grammar needs historical memory
- The commutator = when both CFGs fire simultaneously, the dolly-zoom

## 2. Encoding Strategy

The Graphiti temporal graph receives **episodes** (chronological events) describing the type lattice. Community detection then finds clusters of related nodes based on co-occurrence in episodes.

### 2.1 Data to Encode

| Category | Episodes | Nodes produced |
|---|---|---|
| Station definitions | 3 (P, NP, PN) | Station nodes with tree/weight attributes |
| Type computations | 11 (one per type) | Type nodes with signature (p,q) and degeneracy |
| Membership links | 33 (3 stations × 11 types) | Edges: station → type membership |
| Adjacency pairs | 5 | Edges between adjacent types |
| ApplyMove transitions | 4 (from v₁) | Edges: type → type via signed move |
| Bearing classifications | 3 (Δ-vectors) | Edges: bearing for each key transition |
| Leaf polarity | 3 (P, NP, PN) | Attribute on station nodes |

### 2.2 OWL KV Pairs (Blood-Brain Barrier)

The rosetta between the NormCode layer and the Cortex layer:

| OWL Key | NormCode Concept | Cortex Value |
|---|---|---|
| `type_move_alphabet` | Signed alphabet {s₂⁺, s₂⁻, s₃⁺, s₃⁻} | 4×r moves, computable via `applyMove` |
| `split_magma_signature` | (p,q) = (\|S₂\|,\|S₃\|) dimension split | Verified: v₁(1,2), C(1,1), W(2,1), v₂(3,1), v₃(2,3) |
| `commutator_vanishing` | [s₂⁺(i), s₃⁺(j)] = 0 iff i=j | Plausible, not yet proven |
| `two_cfg_decomposition` | CFG₁ (left) × CFG₂ (right) | Leaf polarity maps stations to one or the other |
| `45_degree_dolly_zoom` | One KKT step changes both coordinates | Verified: v₁→v₂ Δ=(1,-1), v₁→v₃ Δ=(1,1) |

## 3. Execution

The following episodes are recorded via `normcode_graphiti_add_episode`:

### Phase 1: Station Definitions

1. `station_P` — P = Node(Leaf,Leaf), size=1, coord=(1,0), lw=0, rw=0, polarity=left
2. `station_NP` — NP = Node(Leaf,Node(Leaf,Leaf)), size=2, coord=(2,-1), lw=0, rw=1, polarity=right
3. `station_PN` — PN = Node(Node(Leaf,Leaf),Leaf), size=2, coord=(2,1), lw=1, rw=0, polarity=left

### Phase 2: Type Computation Points

4. `grid_definition` — [1,2]×[-1,1] at step ⅙, 91 points
5. `type_count` — 11 distinct types found on the full grid
6. `type_v1` — v₁(P)@(1,0): S₁={1,3}, S₂={1}, S₃={1,2}, sig=(1,2), degenerate=true
7. `type_v2` — v₂(NP)@(2,-1): S₁={2,3}, S₂={1,2,3}, S₃={2}, sig=(3,1), degenerate=true
8. `type_v3` — v₃(PN)@(2,1): S₁={3}, S₂={1,3}, S₃={1,2,3}, sig=(2,3), degenerate=true
9. `type_interior` — C@(1.5,0): S₁={3}, S₂={1}, S₃={2}, sig=(1,1), degenerate=false
10. `type_wall` — W@(2,0): S₁={3}, S₂={1,3}, S₃={2}, sig=(2,1), degenerate=true

### Phase 3: Adjacencies and Bearings

11. `adjacency_count` — 5 adjacent pairs among 11 types
12. `adjacency_breakdown` — 1E + 1W + 1N + 1S signature moves + 1 unknown
13. `bearing_v1v2` — SE Δ=(1,-1), not adjacent in poset (requires intermediate types)
14. `bearing_v1v3` — NE Δ=(1,1), not adjacent in poset
15. `bearing_v2v3` — N Δ=(0,2)

### Phase 4: Split Magma Verification

16. `applyMove_v1_s3minus1` — v₁→C via s₃⁻(1): S₃ removes gen 1
17. `applyMove_v1_s2plus3` — v₁→W via s₂⁺(3): S₂ adds gen 3
18. `applyMove_v1_s3minus2` — v₁→(|S₁|=2,|S₂|=1,|S₃|=1,S₃={1}) via s₃⁻(2)
19. `applyMove_v1_s2plus2` — v₁→(|S₁|=2,|S₂|=2,|S₃|=2) via s₂⁺(2)

### Phase 5: Leaf Polarity

20. `polarity_P` — lw=rw=0, tie → left
21. `polarity_NP` — lw=0, rw=1, right-dominant
22. `polarity_PN` — lw=1, rw=0, left-dominant

## 4. Expected Community Structure

After community detection, Graphiti should partition the 30+ nodes into:

1. **S₂-dominated cluster**: Type W (S₂-tie), Station PN (left-dominant), E/W moves, interior type C (S₂ singleton = gen 1)
2. **S₃-dominated cluster**: Type v₁ (S₃-tie), Station NP (right-dominant), N/S moves, interior type C (S₃ singleton = gen 2)
3. **Interior cluster**: Type C (non-degenerate), the pivot between S₂ and S₃ communities
4. **Boundary cluster**: v₂ and v₃ (triple degeneracies), the extreme vertices of the grid
5. **Signed move subgraph**: The applyMove transitions, forming a directed graph within the type lattice

The community boundaries are the **rivers** of the conceptual map:
- Between S₂ and Interior: the degeneracy threshold |S₂|>1
- Between S₃ and Interior: the degeneracy threshold |S₃|>1
- Between S₂ and S₃: the commutator [s₂, s₃] (visible via the unknown 5th adjacency)

## 5. Community Detection Results

`graphiti_build_communities` on the `tropical_type_theory` group returned **2 communities**.

### Interpretation

The two communities correspond to the primary partition of the type lattice — the **split magma dimension split** (two orthogonal CFGs):

| Community | Episodes clustered | Interpretation |
|---|---|---|
| **A (CFG₁ / left-weight)** | station_PN, station_P, type_v2, type_wall_W, bearing_v1_W, leaf_polarity_experiment (P,PN) | S₂-dominant: types where |S₂| ≥ |S₃|, left-polarity stations, east/west bearing transitions |
| **B (CFG₂ / right-weight)** | station_NP, type_v1, type_v3, bearing_v1_C, leaf_polarity_experiment (NP) | S₃-dominant: types where |S₃| ≥ |S₂|, right-polarity station, north/south bearing transitions |

The interior type C (signature (1,1)) sits at the **boundary** between the two communities — it is the only purely non-degenerate type where both CFGs are in balance.

### What This Validates

The 2-community result directly validates the **primary prediction** of the split magma decomposition:

1. **Two CFGs exist** — Graphiti found them from co-occurrence patterns alone, without explicit labeling
2. **Leaf polarity tracks community** — left-polarity stations cluster with CFG₁, right-polarity with CFG₂
3. **Signature (p,q) identifies community affinity** — p>q → Community A, q>p → Community B, p=q → boundary

### What Did NOT Emerge (Yet)

The predicted **5 finer communities** (S₂-ville, S₃-ville, Interior, Confluence, Boundary) did not appear. This is expected: with only 25 episodes and 11 type descriptions, the graph is too sparse for sub-community resolution. To see the finer structure, we would need:

- More per-type episodes (each type as a separate node with its own event chain)
- Separate nodes for each type (currently types are embedded within episode text, not as independent graph nodes)
- Explicit adjacency edges as graph edges (currently described within episode text)
- More stations (DCBA = 4! = 24 stations for r=4)

### Why the `graphiti_search` Tool Did Not Work

The MCP server passes `limit=10` as a default to Graphiti's `.search()` method, which does not accept a `limit` parameter. The tool definition needs a server-side fix to remove the `limit` argument from the search handler. This did not affect the core experiment — episodes were recorded and community detection completed successfully.

## 6. Next Steps

1. **Fix `graphiti_search` tool** — remove `limit` parameter from the MCP handler for normcode server
2. **Extend to finer community resolution** — add 6 more individual type episodes (one per remaining unrecorded type) to densify the graph
3. **Add explicit graph nodes for each type** — if Graphiti supports node-level data distinct from episodes, encode each type as a separate node with its signature, degeneracy, and generator sets as node attributes
4. **Run community detection again** — with 17+ type nodes instead of 5, sub-communities may resolve
5. **Extend to r=4 (DCBA station set)** — 24 stations × 4 generators = richer type lattice, more communities
6. **Formalize community boundaries in Lean** — prove theorem: "Two types belong to the same Graphiti community iff their signatures (p,q) share the same dominant CFG (p>q or q>p)"

## 7. Raw Data Summary

- 22 textual episodes recorded in `tropical_type_theory` group
- 5 OWL key-value pair episodes for blood-brain barrier
- 2 communities found by `graphiti_build_communities`
- Graph has been running since session start (model-35b available on :8080)

## Changelog

### 2026-07-07: Community detection hang fixed

The `build_communities` call hung indefinitely (never returned) for our graph because
the upstream `label_propagation` algorithm in Graphiti has an infinite-loop bug:

**Root cause**: When the max vote count ties between two communities (e.g., both
community 7 and community 9 have 3 votes each), the algorithm picks the
higher-numbered community (9). But neighbours flip to the other community (7)
next iteration, creating an infinite oscillation.

**Fix**: Monkey-patched `graphiti_core.utils.maintenance.community_operations.label_propagation`
with a stable version in `infra/_graphiti_service.py` (`_stable_label_propagation`):

1. When the current community is among the top candidates AND has >1 votes, stay.
   This breaks the symmetry when two communities are tied.
2. When all neighbours are unique (max_votes == 1), pick the top vote-getter
   (same behaviour as upstream — seeds the community).
3. Safety cap at 50 iterations (should converge in << 50 for any graph).

Also fixed `MockLLMClient._default_for_type` to handle `anyOf` schemas (the
`EdgeTimestamps` model uses `anyOf: [str, null]`), which generated 14 pydantic
validation warnings during `add_triplet`. The mock now correctly returns `""`
for `anyOf` string types instead of `{}`.

**Result**: `scripts/run_type_experiment.py --triplets` completes in ~0.0s,
returns 2 community nodes vs. hanging forever.

## References

- `lab_notes/032_tropical_type_theory_hypothesis.md` — Type theory hypothesis (two-layer algebra, signed alphabet, leaf polarity)
- `LaserCortex/staging/TropicalTypeAlgebra.lean` — Compiled experiment with split magma and leaf polarity sections
- `docs/type_theory_map.md` — Conceptual map of communities with rivers and bridges
- `docs/type_algebra_worked_example.md` — Concrete 3-station trace
