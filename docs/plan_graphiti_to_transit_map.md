# Plan: Graphiti → Transit Map Pipeline

## Goal

Connect Graphiti community detection to the CD tower transit map by computing
the octolinear embedding (KKT multiplier + covector projection) for each
community, then rendering it as parallel transit lines at different CD levels.

## The Mapping (from OctilinearEmbedding.lean)

| Lean KKT component | Graphiti community property | Source |
|---|---|---|
| `size` (a) | Member EntityNode count | `MATCH (c:Community)-[:HAS_MEMBER]->(ent) RETURN count(ent)` |
| `leftWeight` (b) | Inbound edge count from outside community | `MATCH (other)-[e]->(ent) WHERE ent IN community AND other NOT IN community` |
| `rightWeight` (c) | Outbound edge count to outside community | `MATCH (ent)-[e]->(other) WHERE ent IN community AND other NOT IN community` |
| `assocDefect` (d) | 0 if all coupling_signatures ∈ {commutative, non_commutative}; 4 if any is non_associative | `NormNode.coupling_signature` |

**Covector projection**: `x = size + assocDefect`, `y = leftWeight − rightWeight`

## Pipeline Steps

1. **Build communities** via `GraphitiService.build_communities(group_id)`
2. **For each CommunityNode**, query the FalkorDB driver with Cypher:
   - Member entities (`HAS_MEMBER` edges)
   - Inbound/outbound edge counts across community boundary
   - Coupling signatures from member NormNodes
3. **Compute KKT components** and `tube_coord` per community per CD level
4. **Emit TransitData JSON** matching the format expected by `transit-entry.tsx`

## Output Format

```json
{
  "stations": {
    "community_uuid": {
      "name": "community_uuid",
      "label": "Community name (e.g. 'MarketClosure')",
      "size": 5,
      "y": -2
    }
  },
  "lines": [
    {
      "name": "split-complex",
      "color": "#e6194b",
      "shiftCoords": [0, 0],
      "nodes": [
        {"coords": [3, 0], "name": "community_uuid", "labelPos": "S"},
        ...
      ]
    },
    {
      "name": "split-quat",
      "color": "#3b75af",
      "shiftCoords": [0, 7],
      "nodes": [...]
    },
    {
      "name": "split-octonion",
      "color": "#44aa44",
      "shiftCoords": [0, 14],
      "nodes": [...]
    }
  ]
}
```

## Files to Create/Modify

1. **`scripts/graphiti_to_transit_map.py`** (NEW) — the pipeline script
2. **`scripts/mcp_normcode_server.py`** (MODIFY) — register new MCP tool
3. **`LaserCortex/staging/GraphitiEmbedding.lean`** (NEW) — formal theorems

## Lean Theorems (GraphitiEmbedding.lean)

- `community_embedding_antipode_grading`: Even components (size, assocDefect) → x-coordinate; Odd components (leftWeight, rightWeight) → y-coordinate
- `community_embedding_assoc_regime`: If all coupling signatures are commutative/non_commutative, assocDefect = 0
- `community_embedding_phase_change`: Non-associative regime shifts communities to the (4,4) signature
