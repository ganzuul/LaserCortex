# Graphiti Integration Specification

## Temporal Context Graphs for LaserCortex + NormCode + Reasoning Library

---

## 1. System Context

Three layers must be connected by a persistent, temporal, queryable graph:

```
                    ┌─────────────────────────────────────────┐
                    │          GRAPHITI CONTEXT GRAPH          │
                    │  (Neo4j / FalkorDB / FalkorDB Lite)     │
                    │                                          │
                    │  EpisodicNode ← provenance + temporal    │
                    │  EntityNode   ← concepts + terms         │
                    │  EntityEdge   ← inferences + relations   │
                    │  Community    ← emergent patterns        │
                    └──────────────┬───────────────────────────┘
                                   │
            ┌──────────────────────┼──────────────────────┐
            │                      │                      │
            ▼                      ▼                      ▼
   ┌─────────────────┐  ┌──────────────────┐  ┌────────────────────┐
   │  LASER CORTEX   │  │    NORMCODE      │  │ REASONING LIBRARY  │
   │                 │  │                  │  │                    │
   │  CD algebra     │  │  .ncd plans      │  │  Session traces    │
   │  Tamari lattice │  │  Inference graph │  │  758 thinking blks │
   │  Strut_weight=4 │  │  Orchestrator    │  │  Clusters & scripts│
   │  Π + certificates│  │  Canvas App     │  │  MCP server (:8765)│
   │  Lean proofs    │  │  MCP server      │  │                   │
   └─────────────────┘  └──────────────────┘  └────────────────────┘
```

**Current gap**: No persistence layer connects these. Each system maintains
its own state (SQLite checkpoints, JSON files, in-memory objects). Facts
about what the system did, thought, and proved are not queryable across
sessions, not temporally indexed, and not provenance-tracked.

**Graphiti closes this gap** by providing a single graph that records every
episode (trace, plan execution, certificate generation) as a durable,
temporally-versioned, searchable artifact.

---

## 2. What Graphiti Provides

From `getzep/graphiti` v0.29:

| Feature | What It Means for This Project |
|---|---|
| **Temporal facts** | Every edge has `valid_at` / `invalid_at`. Reasoning steps can be queried as of any point in time. |
| **Provenance** | Every entity and edge traces back to which episodes created it via `episodes: list[str]` UUID field. Full lineage from derived fact to source. |
| **Prescribed ontology** | Custom entity/edge types as Pydantic models passed to `add_episode()`. Auto-extracted by LLM if desired, or populated programmatically. |
| **Incremental construction** | New episodes integrate immediately. No batch recomputation — critical for streaming reasoning traces. |
| **Hybrid retrieval** | BM25 + semantic embedding + graph traversal (BFS) + cross-encoder reranking. Configurable via `SearchConfig` recipes. |
| **Community detection** | `build_communities()` discovers emergent clusters — directly implements the "semantic manifold" from the design doc. |
| **Group isolation** | `group_id` partitions the graph. Each plan, session, or experiment can be its own group. |
| **Pluggable backends** | Neo4j (production), FalkorDB (lightweight), FalkorDB Lite (embedded, Python 3.12+, no server needed), Neptune (AWS). |
| **MCP server** | Existing `mcp_server/` with 20+ tools. Can be extended or used as reference for our own integration. |
| **Saga support** | Ordered episode groups with auto-summarization — maps to NormCode plan execution sequences. |

### Backend recommendation for Phase 1: FalkorDB Lite

- Python 3.12+ only requirement
- No external server — embedded Redis-compatible graph db
- Same Cypher-like query interface as Neo4j
- Zero infrastructure cost for prototyping
- Path to production: Neo4j (drop-in replacement via `GraphDriver` abstraction)

---

## 3. Data Model Mapping

### 3.1 Node Types

Every custom type below is a Pydantic `BaseModel` whose fields become
`EntityNode.attributes`. The base `EntityNode` provides `uuid`, `name`,
`group_id`, `labels`, `summary`, `name_embedding`, `created_at`.

#### ReasoningTrace (→ EpisodicNode)

| Field | Type | Source |
|---|---|---|
| `session_id` | `str` | `reasoning_library/traces.jsonl` |
| `thinking_block` | `str` | Extracted `_Thinking:` content |
| `intent_category` | `str` | LLM-classified intent |
| `domain_tags` | `list[str]` | LLM-classified domains |
| `tools_chain` | `str` | Tool sequence (e.g. "read -> bash -> read") |
| `outcome` | `Literal["success","failure","deferred"]` | Detection outcome |

Maps to `EpisodicNode` with `source=EpisodeType.text`,
`source_description="opencode_session_thinking"`.

#### NormNode (→ EntityNode)

| Attribute | Type | Description |
|---|---|---|
| `alpha_features` | `list[Feature]` | Semantic decomposition features |
| `inference_units` | `list[Inference]` | Inference units extracted from trace |
| `coupling_signature` | `Literal["commutative","non_commutative","non_associative"]` | Coupling regime |

Pydantic model:
```python
class NormNode(BaseModel):
    alpha_features: list[str] = []
    inference_units: list[dict] = []
    coupling_signature: str = "commutative"
```

#### CortexNode (→ EntityNode)

| Attribute | Type | Description |
|---|---|---|
| `eml_tree` | `str` | Serialized EMLTree (S-expression) |
| `cd_step` | `int` | Cayley-Dickson step (0-4) |
| `tamari_path` | `list[Rotation]` | Path through Tamari lattice |
| `assoc_defect` | `float` | 0 or 4.0 (binary currently) |
| `pentagonator_distance` | `int` | Steps to rightComb normal form |

Pydantic model:
```python
class CortexNode(BaseModel):
    eml_tree: str = ""
    cd_step: int = 0
    tamari_path: list[dict] = []
    assoc_defect: float = 0.0
    pentagonator_distance: int = 0
```

#### CertificateNode (→ EntityNode)

| Attribute | Type | Description |
|---|---|---|
| `source_tree` | `str` | Source EMLTree S-expression |
| `target_tree` | `str` | Target (rightComb) S-expression |
| `proof_object` | `str` | Serialized contracts_to proof |
| `validity` | `bool` | Whether the certificate verifies |

Pydantic model:
```python
class CertificateNode(BaseModel):
    source_tree: str = ""
    target_tree: str = ""
    proof_object: str = ""
    validity: bool = False
```

#### RecipeNode (→ EntityNode)

| Attribute | Type | Description |
|---|---|---|
| `feature_signature` | `list[float]` | Embedding centroid |
| `allowed_cd_range` | `tuple[int,int]` | (min_cd, max_cd) |
| `canonical_tamari_shape` | `str` | Canonical tree shape |
| `success_rate` | `float` | 0.0–1.0 |
| `cost_profile` | `dict` | Average cost metrics |

Pydantic model:
```python
class RecipeNode(BaseModel):
    feature_signature: list[float] = []
    allowed_cd_range: tuple[int, int] = (0, 4)
    canonical_tamari_shape: str = ""
    success_rate: float = 0.0
    cost_profile: dict = {}
```

#### PolicyNode (→ EntityNode)

| Attribute | Type | Description |
|---|---|---|
| `trigger_features` | `list[str]` | Feature names that trigger this policy |
| `selects_recipe_id` | `str` | Target RecipeNode UUID |
| `priority_weight` | `float` | Routing priority |
| `stability_score` | `float` | How stable the routing is |

Pydantic model:
```python
class PolicyNode(BaseModel):
    trigger_features: list[str] = []
    selects_recipe_id: str = ""
    priority_weight: float = 1.0
    stability_score: float = 1.0
```

#### CompositionEvent (→ EpisodicNode)

| Attribute | Type | Description |
|---|---|---|
| `input_node_uuids` | `list[str]` | Source node UUIDs across layers |
| `output_node_uuids` | `list[str]` | Produced node UUIDs |
| `cd_step` | `int` | CD step at composition time |
| `strut_cost` | `float` | Cost of non-associative steps |
| `tamari_delta` | `int` | Tamari rotation count |
| `alpha_projection` | `dict` | Alpha-channel assignment snapshot |

Pydantic model:
```python
class CompositionEvent(BaseModel):
    input_node_uuids: list[str] = []
    output_node_uuids: list[str] = []
    cd_step: int = 0
    strut_cost: float = 0.0
    tamari_delta: int = 0
    alpha_projection: dict = {}
```

### 3.2 Edge Types

All edges use `EntityEdge` with custom Pydantic types. The base `EntityEdge`
provides `uuid`, `name`, `fact`, `fact_embedding`, `valid_at`, `invalid_at`,
`episodes`, `attributes`.

#### EXTRACTS_SEMANTICS (Trace → Norm)

```python
class ExtractsSemantics(BaseModel):
    extraction_method: str = "llm"
    confidence: float = 1.0
    feature_overlap: float = 0.0
```

Semantics: "This trace is decomposed into alpha-features + inference units."
Provenance: EpisodicNode (Trace) → EntityNode (Norm).

#### LIFTS_TO_STRUCTURE (Norm → Cortex)

```python
class LiftsToStructure(BaseModel):
    coupling_signature: str = "commutative"
    tree_generation_method: str = "tree_from_inference_entry"
    flow_index: str = ""
```

Semantics: "Semantic inference is embedded into CD/Tamari structure."
This is the formal bridge lift operation — maps to `CortexBridge.lift_inference`.

#### CERTIFIES_TO (Cortex → Certificate)

```python
class CertifiesTo(BaseModel):
    contracted_at_cd: int = 0
    pentagonator_distance: int = 0
    verified_in_lean: bool = False
```

Semantics: "This structure contracts to canonical form under rules."
Maps to `CortexBridge.certify` + `lean-lsp` verification.

#### COMPRESSES_TO (Cortex → Recipe)

```python
class CompressesTo(BaseModel):
    compression_ratio: float = 0.0
    script_format: str = "priming_prompt"
    cluster_size: int = 0
```

Semantics: "This reasoning trajectory is reusable as algorithm."
Maps to `MetaCompressor.compress_cluster`. This is the key distillation edge.

#### FEATURE_PROJECTS_TO (Norm → Recipe)

```python
class FeatureProjectsTo(BaseModel):
    similarity: float = 0.0
    projection_method: str = "centroid_cosine"
```

Semantics: "Semantic similarity → reusable algorithm space."

#### GENERALIZED_BY (Recipe → Policy)

```python
class GeneralizedBy(BaseModel):
    generalization_count: int = 0
    success_threshold: float = 0.7
    stability_window: int = 0
```

Semantics: "Repeated success induces higher-level routing rule."

#### SELECTS (Policy → Recipe)

```python
class Selects(BaseModel):
    routing_frequency: int = 0
    last_selected_at: str = ""
```

Semantics: "Inference-time control flow: policy picks recipe."

#### INSTANTIATES (Recipe → Cortex)

```python
class Instantiates(BaseModel):
    cd_step_at_instantiation: int = 0
    context_used: str = ""
```

Semantics: "Recipe becomes concrete compositional execution."

#### TAMARI_ROTATION (Cortex ↔ Cortex)

```python
class TamariRotation(BaseModel):
    rotation_type: str = "right"  # "right" | "left"
    strut_cost: float = 0.0
    assoc_delta: float = 0.0
    cd_step: int = 0
```

Semantics: "Discrete curvature of reasoning space." Self-loop on CortexNode.
Attributes encode the geometry — `strut_cost = 4` per non-associative step.

#### REASONING_SIMILARITY (Recipe ↔ Recipe)

```python
class ReasoningSimilarity(BaseModel):
    feature_overlap: float = 0.0
    cd_compatibility: float = 1.0
    cost_distance: float = 0.0
    weight: float = 0.0
```

Semantics: "Recipe space distance under Laser metric." Weighted edge for
recipe similarity graph.

### 3.3 Edge Type Restriction Map

Controls which edge types connect which entity types:

```python
EDGE_TYPE_MAP: dict[tuple[str, str], list[str]] = {
    ("EpisodicNode", "NormNode"):             ["EXTRACTS_SEMANTICS"],
    ("NormNode", "CortexNode"):               ["LIFTS_TO_STRUCTURE"],
    ("CortexNode", "CertificateNode"):        ["CERTIFIES_TO"],
    ("CortexNode", "RecipeNode"):             ["COMPRESSES_TO"],
    ("NormNode", "RecipeNode"):               ["FEATURE_PROJECTS_TO"],
    ("RecipeNode", "PolicyNode"):             ["GENERALIZED_BY"],
    ("PolicyNode", "RecipeNode"):             ["SELECTS"],
    ("RecipeNode", "CortexNode"):             ["INSTANTIATES"],
    ("CortexNode", "CortexNode"):             ["TAMARI_ROTATION"],
    ("RecipeNode", "RecipeNode"):             ["REASONING_SIMILARITY"],
}
```

---

## 4. API Surface Mapping

### 4.1 Existing Tools → Graphiti Operations

| Existing Tool | Graphiti Equivalent | Purpose |
|---|---|---|
| `reasoning_library/` MCP `POST /lookup` | `graphiti.search()` with `SearchConfig` | Pattern lookup via hybrid search |
| `scripts/reasoning_library/router.py` `route()` | `graphiti.search()` + `EntityEdge` `SELECTS` query | Three-tier routing backed by graph |
| `mcp_normcode_server.py` `lift_inference` | `graphiti.add_episode()` + custom edge `LIFTS_TO_STRUCTURE` | Bridge lift → persistent graph |
| `mcp_normcode_server.py` `ground_certificate` | `graphiti.add_episode()` + `EntityNode(CertificateNode)` | Cert result → graph |
| `mcp_normcode_server.py` `instantiate_writ` | `graphiti.add_episode()` + `INSTANTIATES` edge | Spec instantiation → graph |
| `scripts/certification_loop.py` `certify_trace_via_bridge` | `graphiti.add_episode()` + `CERTIFIES_TO` edge | Certification → graph |
| `scripts/reasoning_library/compressor.py` `compress_cluster` | `graphiti.add_episode()` + `COMPRESSES_TO` edge | Distillation → RecipeNode |
| Session trace parsing (`reasoning_library/parser.py`) | `graphiti.add_episode(source=EpisodeType.text, entity_types={...})` | First data ingestion |

### 4.2 New Graphiti Tools (to Add to MCP Server)

These wrap Graphiti operations as MCP tools in the existing NormCode MCP server:

| New Tool | Graphiti API | Description |
|---|---|---|
| `graphiti_add_episode` | `add_episode()` | Add any episode (trace, plan step, cert) to graph |
| `graphiti_search` | `search()` | Hybrid search across nodes/edges |
| `graphiti_search_edges` | `search()` with `EdgeSearchConfig` | Edge-specific search with temporal filters |
| `graphiti_get_entity` | `EntityNode.get()` | Get entity by UUID |
| `graphiti_get_edge` | `EntityEdge.get()` | Get edge by UUID |
| `graphiti_get_provenance` | Find episodes that produced a given entity/edge | Trace lineage |
| `graphiti_query_temporal` | Search with `valid_at`/`invalid_at` filters | "What was true at time T?" |
| `graphiti_build_communities` | `build_communities()` | Discover emergent clusters |
| `graphiti_get_community` | Get community summary | Read emergent pattern |
| `graphiti_clear_group` | `clear_graph()` | Reset a group for re-ingestion |

---

## 5. Data Flow: Reasoning Trace → Graph

The end-to-end flow for the bootstrap scenario (ingesting 758 existing traces):

```
traces.jsonl
    │
    ▼
graphiti_add_episode(name=session_id, episode_body=thinking_block,
                     source="text", source_description="opencode_session_thinking",
                     reference_time=parse_timestamp(trace.timestamp),
                     entity_types={
                         "ThinkingTrace": ThinkingTraceAttrs,  # with intent, domain, tools, outcome
                     },
                     edge_types={
                         "HAS_INTENT": HasIntentAttrs,
                     },
                     group_id=session_id)
    │
    ▼
Graphiti internal pipeline:
    1. Create EpisodicNode (raw trace stored)
    2. Extract nodes via LLM → EntityNode(ThinkingTrace) per trace
    3. Extract edges via LLM → EpisodicEdge(trace → entity)
    4. Save embeddings, build indices
    │
    ▼
graphiti_build_communities()
    │
    ▼
Emergent clusters appear automatically
(maps to existing 86 clusters from clusterer.py)
    │
    ▼
graphiti_search(query="tried to fix type error but failed",
                search_filter=SearchFilters(node_labels=["ThinkingTrace"],
                                            edge_types=["HAS_INTENT"]))
    │
    ▼
Returns temporally-ordered, provenance-tracked results with
BM25 + semantic + graph traversal scoring
```

### 5.1 Lift Flow (NormCode → Cortex → Certificate)

```
.ncd plan execution step
    │
    ▼
normcode_lift_inference(flow_index="1.2.3", ...)
    │
    ├── CortexBridge.lift_inference()  →  EMLTree + CortexCertificate
    │
    └── graphiti_add_episode(
            episode_body=serialized_inference,
            source="json",
            entity_types={
                "CortexNode": CortexNodeAttrs(eml_tree=..., cd_step=..., ...),
                "CertificateNode": CertificateNodeAttrs(proof=..., validity=...),
            },
            edge_types={
                "LIFTS_TO": LiftsToStructureAttrs(...),
                "CERTIFIES_TO": CertifiesToAttrs(...),
            },
            group_id=plan_name + "." + flow_index
        )
```

### 5.2 Distillation Flow (Cortex → Recipe → Policy)

```
graphiti_build_communities()
    │
    ▼
Community[d] emerges from CortexNode similarity
    │
    ▼
MetaCompressor.compress_cluster(cluster)
    │
    ▼
graphiti_add_episode(
    episode_body=compressed_script,
    source="text",
    entity_types={
        "RecipeNode": RecipeNodeAttrs(feature_signature=..., ...),
    },
    edge_types={
        "COMPRESSES_TO": CompressesToAttrs(compression_ratio=..., ...),
    },
    group_id="recipes"
)
    │
    ▼
PolicyNode auto-extracted from repeated recipe selection
```

---

## 6. Migration Strategy

### Phase 0: Prerequisites

1. Python 3.12+ for FalkorDB Lite support
2. `pip install graphiti-core[falkordblite]`
3. Verify existing bridge + reasoning_library work on 3.12

**Timeline**: 1 session

### Phase 1: Bootstrap — Ingest 758 Reasoning Traces

1. Create `scripts/graphiti_bootstrap.py`
2. Read `reasoning_library/traces.jsonl`
3. Define custom Pydantic types for `ThinkingTrace`, `SessionMetadata`
4. Call `graphiti.add_episode()` for each trace
5. Run `graphiti.build_communities()`
6. Compare emergent clusters against existing 86 from `clusterer.py`
7. Demonstrate `graphiti_search()` with temporal + provenance filters

**Deliverable**: Working Graphiti graph with 758 episodes, emergent communities,
hybrid search over all traces.

**Timeline**: 1-2 sessions
**Risk**: Low — FalkorDB Lite requires no infrastructure

### Phase 2: NormCode MCP Integration

1. Add `GraphitiService` wrapper to `mcp_normcode_server.py`
2. Implement `graphiti_*` tools from §4.2
3. Hook `lift_inference` to auto-persist as `CortexNode` + `LIFTS_TO` edge
4. Hook `ground_certificate` to auto-persist as `CertificateNode` + `CERTIFIES_TO`
5. Hook `instantiate_writ` to auto-persist as `CompositionEvent`

**Deliverable**: Every NormCode MCP operation writes provenance to the graph.

**Timeline**: 2-3 sessions
**Risk**: Low — Graphiti API surface is well-defined; integration is additive,
not invasive.

### Phase 3: Tamari Lattice as Graph

1. Generate all binary trees for n=3..6 via `_tamari_lattice.py`
2. Register each as `CortexNode(eml_tree=...)`
3. Register Tamari rotations as `TAMARI_ROTATION` edges with `strut_cost`
4. Walk the Tamari lattice via BFS graph traversal (`SearchConfig` with bfs)
5. Query: "find cheapest path from tree A to rightComb"

**Deliverable**: Tamari lattice navigable as a graph with cost-weighted edges.

**Timeline**: 2 sessions
**Risk**: Medium — Tamari lattice grows Catalan; n=6 is 132 nodes, manageable.
n=7 is 429 nodes, still fine. n=10 is 16796 — at that scale, on-demand
generation via `contracts_to` is better than full materialization.

### Phase 4: Recipe Library as Graph

1. Migrate existing `library.json` (86 scripts) to `RecipeNode`s
2. Connect each recipe to its source `CortexNode`s via `COMPRESSES_TO`
3. Connect recipes via `REASONING_SIMILARITY` weighted edges
4. Replace `EmbeddingRouter` centroid-match with `graphiti_search()`
5. Demonstrate: "find recipe most similar to this trace" returns results in <100ms

**Deliverable**: Three-tier routing backed by Graphiti hybrid search.

**Timeline**: 1-2 sessions
**Risk**: Low — existing embedding centroids map directly to `RecipeNode.feature_signature`.

### Phase 5: Cross-Session Pattern Discovery

1. Run `build_communities()` across all groups
2. Compare communities against existing manual clusters
3. Use community summaries as candidate `PolicyNode`s
4. Auto-extract `GENERALIZED_BY` edges from repeated routing decisions

**Deliverable**: Emergent policies discovered from reasoning history.

**Timeline**: 1 session
**Risk**: Low — Graphiti provides this natively.

### Phase 6: Production Path — Neo4j Migration

1. Deploy Neo4j (Docker: `docker compose up` from Graphiti's docker-compose.yml)
2. Change one line: `GraphDriver` from FalkorDB Lite to Neo4jDriver
3. Verify all queries work identically
4. Bench search latency (target: <200ms for hybrid cross-encoder search)

**Deliverable**: Production-ready persistent reasoning graph.

**Timeline**: 1 session
**Risk**: Low — Graphiti's driver abstraction makes this a config change.

---

## 7. Group Isolation Strategy

Each `group_id` partitions the graph for independent query and lifecycle:

| Group Pattern | Example | Contains |
|---|---|---|
| `session:{session_id}` | `session:ses_1065` | All traces from one opencode session |
| `plan:{plan_name}` | `plan:market_closure` | All inferences from one .ncd plan |
| `plan:{name}:{flow}` | `plan:market_closure:1.2` | One inference within a plan |
| `cert:{cert_uuid}` | `cert:abc123` | Certificate + its proof path |
| `community:{community_id}` | `community:d` | Community of similar nodes |
| `recipe_library` | `recipe_library` | All RecipeNodes + REASONING_SIMILARITY edges |
| `policy_root` | `policy_root` | All PolicyNodes |

Query across groups:
```python
graphiti.search(query="reserve guard", group_ids=["plan:market_closure", "session:ses_1065"])
```
Returns results from both the NormCode plan and the reasoning trace that
discussed the same concept — cross-layer by design.

---

## 8. Design Decisions

### 8.1 Why FalkorDB Lite for Phase 1 (not Neo4j from day one)

FalkorDB Lite is embedded (no server process), requires Python 3.12+, and
provides the same Cypher-like query interface as Neo4j via Graphiti's driver
abstraction. Zero infrastructure cost. If the prototype proves out, migration
to Neo4j is a one-line driver swap.

### 8.2 Why EntityNode (not EpisodicNode) for concepts

EpisodicNode is for raw source data (traces, plan execution dumps). EntityNode
is for extracted, durable semantic objects (concepts, theorems, recipes).
This separation mirrors NormCode's semantic/syntactic distinction: episodes
are the raw audit trail; entities are the distilled facts.

### 8.3 Why custom Pydantic types (not free-form attributes)

Graphiti supports both LLM-extracted and prescribed ontology. For the core
LaserCortex types (EMLTree, CD step, Tamari path), the fields are
structurally critical — they must be present and typed correctly. Pydantic
validation at write time catches schema violations early. Free-form
attributes would allow silent data corruption.

### 8.4 Why group_id per session/plan (not one flat graph)

Isolation enables:
- Independent lifecycle: clear one session without affecting others
- Scoped search: "find patterns only in plan X"
- Provenance: "what group produced this entity?"
- Future multi-tenant: each user gets their own group set

### 8.5 Why additive integration (not replacement)

The existing `reasoning_library/`, `scripts/reasoning_library/`, and
`mcp_normcode_server.py` continue to work unmodified. Graphiti is an
additional persistence + query layer that augments, not replaces, the
existing in-memory and flat-file storage. The migration is gradual:
components opt in to Graphiti as the integration matures.

---

## 9. Capability Gaps (Deferred)

| Gap | Impact | Deferred Until |
|---|---|---|
| **Streaming ingestion** — `add_episode()` is async but single-episode. For live streaming traces, a batch variant with backpressure is needed. | High-frequency trace capture would drop episodes. | Phase 2, when live tracing from opencode sessions is prototyped. |
| **Real-time graph updates via WebSocket** — Graphiti doesn't emit events on graph changes. The Canvas App can't react to graph updates in real-time. | Canvas App would need polling or WebSocket bridge from Graphiti. | Phase 3, when Tamari visualization is integrated. |
| **Proof object storage** — `CertificateNode.proof_object` is `str`. For Lean proofs, we need structured storage of `contracts_to` paths including intermediate trees. | Certificates stored as opaque strings, not queryable by proof structure. | Phase 3, when certificate graph traversal is needed. |
| **Cross-group community detection** — `build_communities()` works within groups. Cross-group communities need custom orchestration. | Emergent patterns across sessions/plans require manual merge. | Phase 5, when cross-session discovery is the goal. |
| **Graphiti's own MCP server** — Graphiti ships an MCP server at `mcp_server/`. We should evaluate whether to extend it or keep our own. | Duplicate MCP surface. | Phase 2 decision point — depends on whether Graphiti's MCP tools meet our needs. |

---

## 10. Risk Assessment

| Risk | Likelihood | Mitigation |
|---|---|---|
| FalkorDB Lite stability on Python 3.12 | Low | Graphiti v0.29 actively supports it. Fallback: full FalkorDB via Docker. |
| Graphiti LLM extraction cost for 758 traces | Medium | Use `entity_types`/`edge_types` prescribed ontology (no LLM per episode). Pass custom types explicitly. |
| Tamari lattice size explosion | Low | Materialize n≤6 (132 nodes). For n>6, use on-demand `contracts_to` query. |
| Existing code breaks on Python 3.12 | Low | Test reasoning_library pipeline on 3.12 first. Pin 3.11 if needed. |
| Graphiti API changes between versions | Low | Pin `graphiti-core==0.29.*`. API is stable. |

---

## 11. Quickstart (Phase 1, Session 1)

```bash
# Prerequisites
python3.12 -m venv .venv-graphiti
source .venv-graphiti/bin/activate
pip install graphiti-core[falkordblite]

# Bootstrap script (to be written)
python scripts/graphiti_bootstrap.py \
    --traces reasoning_library/traces.jsonl \
    --db /tmp/reasoning-graph.db
```

```python
# scripts/graphiti_bootstrap.py (outline)
from graphiti_core import Graphiti
from graphiti_core.driver.falkordb_lite import FalkorDBLiteDriver
from pydantic import BaseModel

class ThinkingTraceAttrs(BaseModel):
    intent_category: str = ""
    domain_tags: list[str] = []
    tools_used: list[str] = []
    tools_chain: str = ""
    outcome: str = ""

class HasIntentAttrs(BaseModel):
    confidence: float = 1.0

async def main():
    driver = FalkorDBLiteDriver(db="/tmp/reasoning-graph.db")
    graphiti = Graphiti(
        graph_driver=driver,
        llm_client=None,  # No LLM extraction — pure prescribed ontology
        embedder=...      # bge-m3 via OpenAI-compatible endpoint
    )
    await graphiti.build_indices_and_constraints()

    traces = load_jsonl(args.traces)
    for trace in traces:
        await graphiti.add_episode(
            name=trace["session_id"],
            episode_body=trace["thinking_block"],
            source_description="opencode_session_thinking",
            reference_time=datetime.fromisoformat(trace["timestamp"]),
            source="text",
            entity_types={"ThinkingTrace": ThinkingTraceAttrs},
            edge_types={"HAS_INTENT": HasIntentAttrs},
            group_id=f"session:{trace['session_id']}",
        )

    await graphiti.build_communities()
    results = await graphiti.search("type error in type class instance")
    print(f"Found {len(results)} relevant traces")
```
