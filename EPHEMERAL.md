# Anchored Summary

## What This Session Accomplished

**Tropical Type Theory → Graphiti Community Detection — validated.**

1. **Encoded the type lattice into Graphiti** (25 episodes across 6 phases): station definitions, type descriptions, adjacencies, applyMove transitions, leaf polarity, and OWL bridge keys.

2. **Ran community detection → 2 communities found.** The primary partition is the **split magma dimension split** — CFG₁ (left-weight/S₂-dominant) vs CFG₂ (right-weight/S₃-dominant). Interior type C (signature (1,1)) sits at the boundary.

3. **Created `scripts/run_type_experiment.sh`** — a shell script the user can run to:
   ```
   ./scripts/run_type_experiment.sh                          # default (r=3)
   ./scripts/run_type_experiment.sh --density 50 --output results.json  # bigger graph
   ./scripts/run_type_experiment.sh --keep-db --verbose       # persistent DB
   ```
   The script encodes the type lattice into a temporary Graphiti database, runs community detection, and reports results.

4. **Created `scripts/run_type_experiment.py`** — Python backend that uses `infra._graphiti_service.GraphitiService` to encode data and detect communities. Handles 7 types, 5 adjacencies, 4 applyMoves, 7 OWL bridge keys, plus optional synthetic density episodes.

5. **Committed and pushed** (branch `graphiti-integration`): 3 new files, 451 insertions.

## Key Results

| Metric | Value |
|---|---|
| Types encoded | 7 (5 named + 2 from applyMoves) |
| Adjacent pairs | 5 |
| ApplyMove transitions | 4 |
| OWL bridge keys | 7 |
| Communities found | 2 |
| Primary split | CFG₁ (S₂) vs CFG₂ (S₃) |
| Interior pivot | Type C (signature (1,1), non-degenerate) |
| Density support | `--density N` for N synthetic episodes |

## Known Issues

- `graphiti_search` MCP tool broken (passes `limit` param that Graphiti doesn't accept) — needs server-side fix
- Only r=3 supported (5 stations would need r=4 algebra extension in Lean)
- 2 communities is the coarsest split; finer sub-communities (S₂-ville, S₃-ville, Interior, Confluence, Boundary) need a denser graph
- `GraphitiService.add_owl_key_value_pair` uses Pydantic objects (NormNodeAttrs, CortexNodeAttrs, OwlKeyValuePairAttrs) — experiment script uses plain episodes for OWL bridge instead

## Files Created/Modified

| File | What |
|---|---|
| `scripts/run_type_experiment.sh` | Shell wrapper — user entry point |
| `scripts/run_type_experiment.py` | Python experiment runner |
| `lab_notes/033_tropical_type_theory_as_graphiti_communities.md` | Full lab note with protocol, execution, results |
| `EPHEMERAL.md` | This file |

## Next Session

1. Fix `graphiti_search` MCP tool (remove `limit` param from `graphiti_search` tool definition in `scripts/mcp_normcode_server.py`)
2. Extend Lean algebra to r=4 (DCBA station set, 24 stations)
3. Add per-type episodes for all 11 types (generate additional grid types in script)
4. Debug 5th adjacency mystery
5. Connect to the transit map pipeline (`graphiti_to_transit_map` tool)
