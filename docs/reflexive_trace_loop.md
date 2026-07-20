# Reflexive Trace Loop

**Architecture & Implementation Plan** | 2026-07-08

**Status**: EARLY EXPLORATION — most architectural claims are untested
assumptions.  The document is structured as a hypothesis to be validated.
Key gaps identified in §7 (Blockers & Known Gaps) include: (1) entity name
embedding search may not retrieve relevant traces, (2) in-trace entity
extraction may produce noise rather than signal, (3) the claimed
compression ratio (~2x per-call reuse, not 7.7x distillation) is far below
the original paper, (4) convergence metrics lack a ground-truth validation
protocol.  See §7 for full analysis.

---

## 0. Two Graphiti Pathways

This document describes one of two distinct ways Graphiti is used in the
LaserCortex system.  Both use the same Graphiti MCP server and FalkorDB
backend, but they serve different purposes and should not be confused:

### Pathway A: Reflexive Trace Loop (This Document)

The local LLM's reasoning traces about **Graphiti's own extraction
functions** are captured during entity/edge extraction, stored as episodes
in Graphiti, searched before the next extraction, and injected as context
to produce shorter traces.  The loop is self-referential — Graphiti storing
traces about Graphiti extraction — and recursively improves the extraction
function itself.

**Key property**: Self-referential. The content being stored (reasoning
traces about extraction) is metadata about Graphiti's own operations.

**Short name**: "Reflexive Trace Loop" or "reflexive loop"

### Pathway B: Reasoning Library (Separate Integration)

The opencode-graphiti plugin stores compacted reasoning strategies produced
by `MetaCompressor` (MetaCompactor) as Graphiti episodes.  Retrieval uses
Graphiti's **native entity extraction + hybrid search** contract — NOT the
centroid-matching contract from the legacy `scripts/reasoning_library/` code.

**Contract**: Store compaction summary as episode → entity extraction creates
EntityNodes for key concepts mentioned in the summary (task types, domain
terms, techniques) → entity names get embedded → `search_(query=task_desc)`
matches entity name embeddings via hybrid search (cosine similarity + BM25
+ graph traversal) → matched entities trace back to the summary episode.

This is Graphiti's native pipeline applied to summary text — no custom
centroid index, no custom vector comparison.  The same pipeline that Graphiti
uses for news articles, business documents, or any episode content works
naturally for compaction summaries.

**Key difference from legacy**: The legacy `scripts/reasoning_library/` used
a centroid-matching router (bge-m3 embeddings, cosine similarity to cluster
mean vectors).  The Graphiti-backed system replaces this with entity-centric
retrieval.  The centroids and the legacy router code remain available but are
not part of the Graphiti integration.  See §8.4 for full contract comparison.

**Key property**: External knowledge. The content being stored is domain
knowledge about the project, not about Graphiti itself.

**Short name**: "Reasoning Library" or "knowledge graph"

### Disambiguation

| Aspect | Reflexive Trace Loop | Reasoning Library |
|--------|---------------------|-------------------|
| Subject | Graphiti's own extraction | Project domain knowledge |
| Recursive? | Yes — traces improve extraction | No — knowledge is stored once |
| Compression | ~2x per-call reuse (MetaCompressor for 7.7x) | MetaCompressor produces compacted scripts |
| Entry point | `queue_service.py` (background worker) | `opencode-graphiti.ts` plugin `graphiti` tool |
| Retrieval mechanism | Entity name embedding search (same as Graphiti default) | Entity name embedding search (same as Graphiti default) |
| Group pattern | `{group_id}_traces` | `project_config`, `session:*`, etc. |
| MCP tools | `search_reasoning_traces`, `get_trace_chain` | `add_memory`, `search_nodes`, `search_memory_facts` |

---

## 1. Motivation

Every LLM call that uses `response_format: json_schema` generates a reasoning
trace — the model's internal thinking about how to produce the structured
output. These traces contain reusable strategy: how the model identifies
entities, resolves ambiguity, applies the schema, and self-corrects. In the
existing external neuro-symbolic loop (see
[`EXTERNAL_NEURO_SYMBOLIC_LOOP.md`](./EXTERNAL_NEURO_SYMBOLIC_LOOP.md)),
approximately **87% of trace tokens are reusable boilerplate** — only ~13%
are specific to the input.

The original system used a batch compressor (`MetaCompressor`) to distill
200 traces into 5 scripts, achieving a **7.7x per-call speedup**.  But the
compression was offline, manual, and did not feed back into live extraction.

**This architecture closes the loop at runtime.** Every extraction generates a
trace, every trace is stored as a Graphiti episode, and every subsequent
extraction searches for relevant prior traces to inject as context.  The chain
grows and **converges** — each step produces a shorter, more targeted trace
because it builds on the reasoning from before.

The result is a recursively bootstrapping intelligence: the system gets
cheaper and more accurate with use, without any fine-tuning or weight updates.

---

## 2. Core Insight: Recursion as Mechanism

When an LLM extracts entities from a user input, it generates a reasoning
trace describing how it identifies entities, applies the schema, etc.
When that trace is itself stored as an episode, entity extraction runs on
the trace text — extracting conceptual entities from the reasoning process
(the task type, schema constraints, ambiguity resolution strategy).  This
extraction generates a **new** trace about the *trace*, which is shorter
than the original because the extraction problem is simpler:

> "Entities from raw product announcement" → 1000 token trace
> "Entities from a 200-token text about entity extraction" → 100 token trace
> "Entities from a 30-token mention of entity extraction" → 20 token trace

This converges to a fixed point — the minimal reasoning kernel for each
entity/edge extraction type.  The recursion is **not** a problem to contain;
it *is* the bootstrapping mechanism.

**The chain grows across requests, not within one.** Within a single storage
step, we store traces one level deep (depth cap = 1).  The chain extends when
a *subsequent* extraction searches for relevant traces, finds them, injects
them as context, and generates a shorter trace.  Each request is a Markov
chain Monte Carlo step — a draw from the posterior over reasoning paths.

```
Request 1: input → trace₁ (1000 tokens) → stored
Request 2: finds trace₁ → injects → trace₂ (800 tokens) → stored
Request 3: finds trace₂ → injects → trace₃ (650 tokens) → stored
...
Approximate plateau: ~400-500 tokens (2x compression)
```

This is **per-call reuse**, not distillation. The compressed end state is
~400-500 tokens, not ~50. True convergence to 50t requires MetaCompressor
(see §7.3). Embedding similarity surfaces the most relevant prior trace,
enabling MCMC-like navigation of the reasoning posterior. The quality of
the match depends on entity name embeddings from trace extraction, which
has its own limitations (see §7.1, §7.2).

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        GRAPHITI CONTEXT GRAPH                       │
│  (FalkorDB via graphiti-mcp-llamacpp)                               │
│                                                                     │
│  group: {group_id}          group: {group_id}_traces                │
│  ┌──────────────────┐      ┌──────────────────────────────────┐     │
│  │ UserEpisode      │◄─────│ TraceEpisode (depth=1)           │     │
│  │ body: "Acme..."  │      │ body: "I see Organization..."    │     │
│  │ uuid: U1         │      │ uuid: T1,   source_episode: U1  │     │
│  └──────────────────┘      └──────────────────────────────────┘     │
│         │                           │                               │
│         ▼                           ▼                               │
│  Entity extraction            Entity extraction                     │
│  → Org, Product nodes         → "entity_extraction" concept node    │
│  → semantic embeddings         → generic, searchable embedding      │
│                                                                     │
│  search_(query="new product") ───→ matches generic trace nodes      │
│                                    → retrieves T1 body              │
│                                    → injects as custom context      │
└─────────────────────────────────────────────────────────────────────┘
         ▲                                      │
         │           LLM (35B / Qwen-AgentWorld)│
         │           ┌──────────────────────────┘
         │           │
    ┌────┴───────────┴──────────────────────────────┐
    │            OPENAI GENERIC CLIENT               │
    │  _generate_response() captures reasoning trace │
    │  _reasoning_traces: list[dict]                 │
    │  ┌──────────────────────────────────────────┐  │
    │  │ trace_1: {task, content, input_preview}  │  │
    │  │ trace_2: {task, content, input_preview}  │  │
    │  └──────────────────────────────────────────┘  │
    └────────────────────────────────────────────────┘
         │
         ▼
    ┌────────────────────────────────────────────────┐
    │            QUEUE SERVICE (queue_service.py)    │
    │  process_episode():                            │
    │    1. SEARCH _traces group for relevant traces  │
    │    2. INJECT best match as custom_extraction   │
    │    3. CALL graphiti.add_episode(input)         │
    │    4. CAPTURE llm_client._reasoning_traces     │
    │    5. STORE each trace in _traces group        │
    │       (depth cap = 1, child traces cleared)    │
    └────────────────────────────────────────────────┘
```

### 3.1 Component Responsibilities

| Component | Location | Role |
|-----------|----------|------|
| `OpenAIGenericClient` | Container site-packages | Captures every reasoning trace from `_generate_response()` |
| `queue_service.py` | Container source | Orchestrates search → inject → extract → capture → store |
| `graphiti_mcp_server.py` | Container source | Exposes chain navigation MCP tools |
| Graphiti graph | FalkorDB | Stores episodes, entities, and reasoning traces |
| `opencode-graphiti.ts` | Plugin | Optional: orchestrate search/inject from client side |

### 3.2 Group Isolation

Each group has a companion `_traces` subgroup:

| Group | Contains | Used by |
|-------|----------|---------|
| `{group_id}` | User episodes (inputs, extractions) | Normal extraction workflow |
| `{group_id}_traces` | Reasoning trace episodes | Search before extraction, chain navigation |

This keeps traces queryable via `group_ids=[f"{group_id}_traces"]` without
polluting the main graph's entity search results.

---

## 4. Data Flow (Detailed)

### 4.1 Single Extraction Cycle

```
1. [SEARCH]  queue_service.process_episode()
              ├── graphiti.search_(query=input[:500],
              │     group_ids=[f"{group_id}_traces"])
              │     → returns matching trace nodes
              │
              ├── IF found: format best match as context string
              │
2. [INJECT]   kwargs['custom_extraction_instructions'] = context
              ├── (empty string if no match found — first time)
              │
3. [EXTRACT]  graphiti.add_episode(episode_body=input, **kwargs)
              ├── Calls llm_client.generate_response(..., json_schema)
              │     → model thinks: generates reasoning trace
              │     → trace captured by _generate_response()
              │     → response_dict has entities/edges
              ├── Repeated for each extraction step:
              │     - extract_nodes     → trace saved
              │     - extract_edges     → trace saved
              │     - deduplicate       → trace saved
              │     - summarize         → trace saved
              └── Returns AddEpisodeResults
                  (no trace info in return value — captured separately)
              │
4. [CAPTURE]  traces = list(llm_client._reasoning_traces)
              llm_client._reasoning_traces.clear()
              │
5. [STORE]    FOR EACH trace IN traces:
              ├── graphiti.add_episode(
              │     name=f"_trace_{i}_{uuid}",
              │     episode_body=trace['content'],
              │     group_id=f"{group_id}_traces",
              │     source=EpisodeType.text)
              │
              ├── This triggers entity extraction ON THE TRACE TEXT
              │     → extracts conceptual entities (task type, schema)
              │     → generates CHILD trace (captured in _reasoning_traces)
              │     → these child traces are CLEARED (depth cap = 1)
              │
6. [CLEAR]    llm_client._reasoning_traces.clear()
              ├── (child traces from step 5 are discarded)
              └── Ready for next episode in queue
```

### 4.2 Chain Growth Across Requests

```
Request A ("Acme Corp product launch"):
    search → no traces → inject: none → extract → trace₁ (1000 tokens)
    trace₁ stored in _traces group
    Entity extraction on trace₁ → conceptual nodes: "entity_extraction",
        "Organization", "schema_applied", "ambiguity_resolution"

Request B ("Microsoft Azure GA"):
    search → matches "entity_extraction" node (from trace₁ extraction)
           → retrieves trace₁ body
    inject: trace₁ as previous reasoning
    extract → trace₂ (150 tokens) — builds on trace₁ strategy
    trace₂ stored in _traces group
    Entity extraction on trace₂ → similar conceptual nodes (reinforced)

Request C ("Google Cloud launch"):
    search → matches "entity_extraction" node → retrieves trace₂
    inject: trace₂ (already compressed)
    extract → trace₃ (40 tokens) — minimal reasoning needed
    trace₃ stored → convergence approached
```

### 4.3 Convergence

Convergence is measured across requests for similar input types:

| Metric | Measure | When |
|--------|---------|------|
| Trace token count | `len(trace['content'].split())` | After extraction |
| Embedding similarity | Cosine sim(trace_n, trace_{n+1}) | After storage |
| Extraction accuracy | Compare entities with/without injection | Periodically |

A chain is **converged** when:
- Trace length stabilizes (±20% change over 3+ requests)
- Trace content embedding similarity > 0.95 with the previous trace
- Extraction accuracy reaches a plateau

Converged traces become zero-shot templates: they can be used as fixed
`custom_extraction_instructions` without search, eliminating the LLM call
for trace generation entirely (fast-path routing).

---

## 5. Implementation Plan

### V1: Capture + Store (Bootstrapping the Chain)

**Goal**: Every extraction generates traces; every trace is stored in a
parallel Graphiti group.  The chain begins to grow.

#### File 1: `/app/mcp/.venv/lib/python3.11/site-packages/graphiti_core/llm_client/openai_generic_client.py`

**Change**: Convert `_reasoning_trace` (single value, overwritten each call)
to `_reasoning_traces` (list, appended to on each call).

```python
# In __init__:
self._reasoning_traces: list[dict] = []

# In _generate_response, after capturing reasoning_content:
self._reasoning_traces.append({
    "task": response_model.__name__ if response_model else "json_object",
    "trace": reasoning_content,
    "input_preview": (modified_messages or messages)[-1]
                     .get("content", "")[:200],
    "timestamp": datetime.now().isoformat(),
    "token_count": len(reasoning_content.split()),
})

# Also keep the existing response_dict["_reasoning_trace"] = reasoning_content
# for backward compatibility with direct callers.
```

#### File 2: `/app/mcp/src/services/queue_service.py`

The `QueueService.add_episode` method currently has a fixed parameter list
that does not include `custom_extraction_instructions`. For both V1 and V2,
this method needs to accept and pass through this parameter.

**Change 1**: Add `custom_extraction_instructions` parameter to both
`QueueService.add_episode` and its inner `process_episode` closure so it
reaches `graphiti_client.add_episode()`. Verified: `graphiti.add_episode()`
accepts this parameter natively.

```python
# On QueueService.add_episode method signature, add parameter:
async def add_episode(
    self,
    group_id: str,
    name: str,
    content: str,
    source_description: str,
    episode_type: Any,
    entity_types: Any,
    uuid: str | None,
    custom_extraction_instructions: str | None = None,  # NEW
) -> int:

    # In the process_episode closure, pass it through:
    async def process_episode():
        try:
            await self._graphiti_client.add_episode(
                name=name,
                episode_body=content,
                source_description=source_description,
                source=episode_type,
                group_id=group_id,
                reference_time=datetime.now(timezone.utc),
                entity_types=entity_types,
                uuid=uuid,
                custom_extraction_instructions=custom_extraction_instructions,  # NEW
            )
        except Exception as e:
            logger.error(...)
            raise
```

**Change 2**: In `process_episode()`, after `graphiti_client.add_episode()`
completes, capture and store traces.

```python
# --- After graphiti_client.add_episode() returns successfully ---
graphiti = self._graphiti_client
llm_client = getattr(graphiti, 'llm_client', None)
if llm_client and hasattr(llm_client, '_reasoning_traces'):
    trace_entries = list(llm_client._reasoning_traces)
    llm_client._reasoning_traces.clear()

    for i, entry in enumerate(trace_entries):
        try:
            trace_text = entry.get('trace', '').strip()
            if not trace_text or len(trace_text) < 20:
                continue

            await graphiti.add_episode(
                name=f"_trace_{i}_{uuid}",
                episode_body=trace_text,
                source=EpisodeType.text,
                source_description=(
                    f"Reasoning trace from {entry.get('task', 'unknown')} "
                    f"for episode {uuid}"
                ),
                group_id=f"{effective_group_id}_traces",
                reference_time=datetime.now(timezone.utc),
            )

            # Clear any child traces generated by storing this trace
            # (depth cap = 1 — no recursive chain within one request)
            if hasattr(llm_client, '_reasoning_traces'):
                llm_client._reasoning_traces.clear()

        except Exception:
            logger.warning(f"Failed to store reasoning trace for episode {uuid}")
```

**Concurrency caveat**: `llm_client._reasoning_traces` is shared across all
groups processed by the same Graphiti client. If two queue workers process
episodes for different groups concurrently, their traces will interleave in
this single list. Mitigation for a future version: set a per-call correlation
ID (`llm_client._extraction_id = str(uuid4())`) before each `add_episode`,
store it in each trace entry, then filter by it after.

**Restart required**: Restart the graphiti-mcp-llamacpp container for the
patched `queue_service.py` to take effect.  (The `OpenAIGenericClient` patch
is already live as a site-packages modification.)

---

### V2: Close the Loop (Inject Prior Traces)

**Goal**: Before each extraction, search for relevant prior traces and inject
the best match as `custom_extraction_instructions`.

#### File 2a: `queue_service.py` — trace search before `graphiti.add_episode()`

This code goes inside `process_episode()` **before** the
`graphiti_client.add_episode()` call, using the same `content` and `group_id`
captured by the closure. Verified data flow:

1. `graphiti_client.search_(query=input[:500], config=NODE_HYBRID_SEARCH_RRF,
   group_ids=[f"{effective_group_id}_traces"])` → `SearchResults`
2. `result.nodes[i]` has `EntityNode.uuid`; score is `result.node_reranker_scores[i]`
3. `EpisodicNode.get_by_entity_node_uuid(driver, entity_node.uuid)` → episodes
   that MENTION the matched entity node. EpisodicNode has `.content` (not `.body`)
4. The matched entity node's embedding captured the semantic similarity between
   the new input and the concept nodes extracted from the prior trace

```python
# --- Before graphiti_client.add_episode() ---
from graphiti_core.nodes import EpisodicNode
from graphiti_core.search.search_config_recipes import NODE_HYBRID_SEARCH_RRF

trace_context = None
graphiti = self._graphiti_client
try:
    search_results = await graphiti.search_(
        query=content[:500],
        group_ids=[f"{effective_group_id}_traces"],
        config=NODE_HYBRID_SEARCH_RRF,
    )

    if search_results.nodes and search_results.node_reranker_scores:
        # scores is a parallel list to nodes
        best_idx = max(
            range(len(search_results.node_reranker_scores)),
            key=lambda i: search_results.node_reranker_scores[i],
        )
        best_node = search_results.nodes[best_idx]

        # Find the trace episode that mentions this entity node
        episodes = await EpisodicNode.get_by_entity_node_uuid(
            graphiti.driver, best_node.uuid
        )
        if episodes and episodes[0].content:
            trace_context = (
                "[Relevant prior reasoning trace from similar extraction:]\n"
                f"{episodes[0].content[:2000]}\n"
                "[End prior reasoning trace]"
            )
except Exception as e:
    logger.debug(f"Trace search failed (non-fatal): {e}")

# Then pass to add_episode (via the parameter added in V1):
await graphiti.add_episode(
    ...,
    custom_extraction_instructions=trace_context,
)
```

**Important caveat about entity node names**: The EntityNodes extracted from
trace episodes typically have names like "entity_extraction_task" or "Acme
Corp" — a mix of generic concept names and specific entity names.  A new
input like "Microsoft Azure AI launch" will be embedded and compared against
these entity name embeddings.  Generic concept nodes ("entity_extraction",
"schema_application") will match well; specific entity names ("Acme Corp")
will not match subsequent different inputs.  This is the intended MCMC
behavior — the generic nodes accumulate and improve over time, while the
specific ones are noise that gets out-weighted by RRF ranking.

**Alternative** (if `get_by_entity_node_uuid` is too slow): Store the source
episode UUID in a custom entity type attribute during V1's trace storage
step, then retrieve it directly from the matched EntityNode without a
follow-up query.

---

### V3: Chain Navigation MCP Tools

**Goal**: Expose the trace chain as queryable MCP tools for external
orchestration (plugin, CLI, other agents).

#### File 3: `/app/mcp/src/graphiti_mcp_server.py`

**Tool 1: `search_reasoning_traces`**

```python
@mcp.tool()
async def search_reasoning_traces(
    query: str,
    group_id: str | None = None,
    max_results: int = 5,
) -> str:
    """Search for reasoning traces relevant to a query.

    Args:
        query: Natural language query describing the extraction task
        group_id: The source group ID whose _traces subgroup to search.
                  Uses the default group if not provided.
        max_results: Maximum number of trace episodes to return
    """
    global graphiti_service, config

    effective_group_id = group_id or config.graphiti.group_id
    traces_group_id = f"{effective_group_id}_traces"

    from graphiti_core.nodes import EpisodicNode
    from graphiti_core.search.search_config_recipes import (
        NODE_HYBRID_SEARCH_RRF,
    )

    client = await graphiti_service.get_client()
    results = await client.search_(
        query=query,
        group_ids=[traces_group_id],
        config=NODE_HYBRID_SEARCH_RRF,
    )

    # Format results: for each matching node, find its source episode
    # and return the trace content
    # Scores are in node_reranker_scores parallel list
    trace_results = []
    nodes = results.nodes or []
    scores = results.node_reranker_scores or []
    for idx, node in enumerate(nodes[:max_results]):
        episodes = await EpisodicNode.get_by_entity_node_uuid(
            client.driver, node.uuid
        )
        if episodes:
            trace_results.append({
                "uuid": node.uuid,
                "name": node.name,
                "episode_content": episodes[0].content[:1000],
                "episode_uuid": episodes[0].uuid,
                "score": scores[idx] if idx < len(scores) else None,
            })

    return json.dumps(trace_results, indent=2)
```

**Tool 2: `get_trace_chain`**

Traces are stored with names `_trace_{i}_{episode_uuid}`. Retrieval can use
`EpisodicNode.get_by_entity_node_uuid` (trace from an entity node to its
source episode) or list episodes from the `_traces` group via
`EpisodicNode.get_by_group_ids` followed by name filtering.

```python
@mcp.tool()
async def get_trace_chain(
    episode_uuid: str,
    group_id: str | None = None,
    max_depth: int = 5,
) -> str:
    """Retrieve all reasoning trace episodes associated with a source episode.

    Traces are stored in the {group_id}_traces group during V1 extraction.
    Their names follow the pattern _trace_{i}_{episode_uuid}.

    Args:
        episode_uuid: The source episode UUID whose traces to retrieve.
        group_id: The source group ID (defaults to config default).
        max_depth: Maximum number of related trace episodes to return.
    """
    global graphiti_service, config

    effective_group_id = group_id or config.graphiti.group_id
    traces_group_id = f"{effective_group_id}_traces"

    from graphiti_core.nodes import EpisodicNode

    client = await graphiti_service.get_client()

    # Retrieve episodes from the _traces group
    episodes = await EpisodicNode.get_by_group_ids(
        client.driver, [traces_group_id], limit=max_depth
    )

    # Filter by name pattern matching the source episode UUID
    matching = [
        {
            "uuid": ep.uuid,
            "name": ep.name,
            "content_preview": ep.content[:500],
            "source_description": ep.source_description,
            "created_at": ep.created_at.isoformat() if ep.created_at else None,
        }
        for ep in (episodes or [])
        if episode_uuid in ep.name
    ]

    return json.dumps(matching[:max_depth], indent=2)
```

---

## 6. Design Decisions & Tunable Parameters

### 6.1 Depth Cap

| Parameter | Default | Effect |
|-----------|---------|--------|
| `max_trace_depth` | `1` | Number of trace storage levels per extraction |

**Decision**: Store traces one level deep within a single request.
Child traces (from storing a trace) are discarded. The chain grows
across requests, not within one.

**Rationale**: Within a single request, storing trace₂ (from storing
trace₁) adds latency for marginal benefit — trace₁ is already in the
graph and its entity extraction has already enriched the conceptual
nodes.  The cross-request chain (trace₁ → trace₂ via search + inject)
provides the same bootstrapping with a natural MCMC structure.

**Tuning**: For higher-throughput scenarios where latency matters less
than chain depth, increase to `2` or `3`.  Above `3`, traces converge
to near-constant length and deeper storage adds no value.

### 6.2 Trace Size Threshold

| Parameter | Default | Effect |
|-----------|---------|--------|
| `min_trace_tokens` | `20` | Minimum trace token count to store |

Traces shorter than this threshold are discarded — they contain no
meaningful strategy and would only create noise in the graph.

**Tuning**: Lower to `10` for very short extraction tasks (binary
classification).  Raise to `50` for verbose tasks where short traces
are usually degeneracies.

### 6.3 Search Config for Trace Retrieval

| Parameter | Default | Effect |
|-----------|---------|--------|
| `search_config` | `NODE_HYBRID_SEARCH_RRF` | Search recipe for finding prior traces |

RRF (Reciprocal Rank Fusion) combines BM25 keyword match + semantic
embedding similarity + graph traversal distance.  This surfaces traces
that are both semantically similar AND structurally connected to the
input's entity types.

**Alternatives**:
- `NODE_HYBRID_SEARCH_CROSS_ENCODER` — more accurate, slower
  (re-ranks via cross-encoder). Use for high-value traces where
  precision matters more than latency.
- `EDGE_HYBRID_SEARCH_RRF` — search by relationships instead of
  node content.  Use when looking for traces by the ENTITIES they
  produced, not their own text.

### 6.4 Custom Extraction Max Length

| Parameter | Default | Effect |
|-----------|---------|--------|
| `max_trace_context_chars` | `2000` | Max chars of trace to inject |

The injected trace is capped to avoid overflowing the LLM's context
window.  2000 characters (~500 tokens) is sufficient for a complete
reasoning strategy without dominating the prompt.

**Tuning**: Adjust relative to the model's context window and the
size of the input.  For very long inputs, reduce.  For the 35B
(32K context), 2000 chars is conservative.

### 6.5 Match Threshold for Injection

| Parameter | Default | Effect |
|-----------|---------|--------|
| `min_similarity_for_inject` | `0.3` | Minimum node similarity score to inject |

Lower values inject more traces (potentially less relevant). Higher
values only inject highly relevant traces.  `0.3` is a reasonable
starting point for `NODE_HYBRID_SEARCH_RRF` which produces scores
in the 0.0–1.0 range.

**Tuning**: Monitor extraction accuracy with and without injection.
If traces degrade extraction (noise), raise threshold.  If traces
are rarely found (cold start), lower threshold.

### 6.6 Convergence Detection

| Parameter | Default | Effect |
|-----------|---------|--------|
| `convergence_stable_count` | `3` | Number of successive similar traces to declare convergence |
| `convergence_length_delta` | `0.2` | Max relative trace length change for "stable" |

When a chain is converged, the trace can be promoted to a **zero-shot
template** — used as hard-coded `custom_extraction_instructions` without
search.  This eliminates the search LLM call for that input type.

---

## 7. Blockers & Known Gaps

### 7.1 Trace Search Matches Entity Name Embeddings, Not Full Trace Content

**Status**: 🔴 UNRESOLVED — design assumption not validated.

**Claim in architecture**: `search_(query=new_input, group_ids=[_traces_group])`
finds relevant prior traces by semantic similarity.

**Reality**: The search operates on `EntityNode.name_embedding` — embeddings
of short entity names extracted FROM the trace (e.g. `"Acme Corp"`,
`"product"`, `"Organization"`, `"entity_extraction_task"`).  The search query
is the full new input text (~500 chars).  The embedding similarity between a
multi-sentence query and a 1-3 word entity name is weak.  Generic concept
names like `"entity_extraction_task"` may match any extraction task, but the
domain-specific guidance (how to handle Organization vs Product) lives in the
trace's free text, not in the entity name embeddings.

**Consequence**: Even when `search_` returns a match, the matched entity node
may be too generic to retrieve the most useful trace.  A query about
"Microsoft Azure AI launch" might match `"entity_extraction_task"` from a
prior trace about "Acme Corp product launch" — but the relevant distinction
(both are company→product announcements) is not captured in the entity names.

**What would need to be true**: For this to work robustly, we would need
either (a) entity name embeddings that capture the full semantic content of
the trace, (b) episode-level semantic search (episodes have full-text
content but Graphiti only supports BM25 for episode search, not cosine
similarity), or (c) entity type extraction tuned to produce descriptive
concept names that bridge the specificity gap (e.g. `"company_product_announcement"`).

**Potential mitigations**:
- Use `custom_extraction_instructions` during trace storage to bias entity
  extraction toward descriptive concept names
- Complement `NODE_HYBRID_SEARCH_RRF` with `episode_config` using BM25
  full-text match on the trace content directly
- Accept the weakness for V1 and measure empirically before optimizing

### 7.2 In-Trace Entity Extraction Degrades, Not Improves, Trace Retrievability

**Status**: 🔴 UNRESOLVED — may be an antifeature.

**Claim in architecture**: Entity extraction on trace text produces
"conceptual entities that bridge between similar inputs."

**Reality**: When Graphiti runs entity extraction on a trace episode, the
extracted entities are whatever the LLM finds in the trace text.  A trace
like *"I see Organization 'Acme Corp' in the context of a product
launch…"* will produce EntityNodes for `"Organization"` (reasonable),
`"Acme Corp"` (domain-specific, won't match other inputs), and potentially
`"product launch"` (somewhat reusable).  But it will ALSO produce entities
like `"I"`, `"see"`, `"context"` — stopword-level noise that Graphiti's
default entity extraction does not filter.  These noise entities pollute
the `_traces` group and may out-score relevant entities in RRF ranking.

**Consequence**: The entity extraction, which we hoped would create a
semantic bridge, may instead create noise that drowns out the signal.
This is an empirical question, but the assumption that "extraction on trace
text produces usable search entities" has not been tested and may be false.

**What would need to be true**: Either (a) Graphiti's default entity
extraction handles trace text well (unlikely — it's designed for news
articles and business text), (b) we configure custom entity types for
trace-specific extraction with very narrow schemas (e.g. only `TaskType`
and `ReusableConcept`), or (c) we bypass entity extraction on traces
entirely and use a simpler storage strategy (e.g. just store trace text
by name pattern without entity extraction).

### 7.3 V2 Injection Gives Partial Compression, Not Distillation

**Status**: 🔴 UNRESOLVED — core loop claim is weaker than stated.

**Claim in architecture**: "Each request produces a shorter trace,
converging to a minimal reasoning kernel."

**Reality**: Injecting a prior trace as `custom_extraction_instructions`
gives per-call compression — the LLM reuses strategy instead of
re-deriving it.  But this is NOT distillation.  The injected context IS
the full prior trace.  With each iteration:
- The model reads a 1000-token prior trace → generates an 800-token new trace
- The new trace is shorter because it references the prior strategy,
  not because the strategy has been compacted
- Convergence is bounded by how much of the prior strategy is reusable
  for the new input

Typical compression without `MetaCompressor`:

| Request | Context | Trace length |
|---------|---------|-------------|
| 1 | None | 1000 tokens |
| 2 | Prior trace (1000t) | ~800 tokens |
| 3 | Prior trace (800t) | ~650 tokens |
| 4 | Prior trace (650t) | ~550 tokens |
| 5+ | Diminishing returns, plateauing at ~400-500t | |

This is ~2x compression, far from the 7.7x (→100 tokens) claimed in
the original paper, which required MetaCompressor distillation across
multiple traces.

**What would need to be true**: The reflexive loop alone cannot reach
the 50-token regime.  True convergence to minimal traces requires
_cross-trace_ distillation: feeding multiple similar traces to a
`MetaCompressor`-like step that extracts their common strategy into a
compact script.  The chain provides the input material; the distillation
is a separate step.

### 7.4 No Ground Truth for Convergence Measurement

**Status**: 🟡 DESIGN GAP — metrics exist but no validation protocol.

**Claim**: Convergence is detected by trace length stabilization and
embedding similarity > 0.95.

**Reality**: Trace length can plateau for bad reasons (e.g. the model
runs out of reasoning budget, not because it converged on the optimal
strategy).  Embedding similarity > 0.95 between consecutive traces can
indicate the model is generating the same boilerplate regardless of input,
which is convergence on a spurious attractor, not the right reasoning.

**What would need to be true**: A validation protocol where extracted
entities/edges with and without trace injection are compared for accuracy.
This requires a held-out test set with known entity labels — we don't
have one.  Without it, "convergence" is cosmetic.

### 7.5 Shared `_reasoning_traces` List Has a Race Condition

**Status**: 🟢 MITIGATION KNOWN — not a blocker for V1.

**Reality**: The single `llm_client._reasoning_traces` list accumulates
traces from all LLM calls across all groups.  If queue workers for
different groups run concurrently, traces interleave.

**Known mitigation**: Set a per-call correlation UUID on the client
before each `add_episode`, include it in each trace entry, and filter
by it after.  Not implemented in V1.

### 7.6 QueueService.add_episode Method Does Not Accept `custom_extraction_instructions`

**Status**: 🟢 KNOWN FIX — straightforward change.

**Reality**: The `QueueService.add_episode` method at
`/app/mcp/src/services/queue_service.py` has a fixed parameter list
that does not include `custom_extraction_instructions`.  Verified:
`graphiti.add_episode()` accepts this parameter natively.

**Priority**: Must fix before V2 can work.  Add the parameter to both
the outer method and the inner `process_episode` closure.

### 7.7 Entity Extraction on Compaction Summary Text May Not Produce Useful Search Entities

**Status**: 🔴 UNRESOLVED — core assumption of Pathway B untested.

**Claim**: Storing a MetaCompactor compaction summary as an episode, then
letting Graphiti's default entity extraction create EntityNodes from it,
produces entity names useful for hybrid search retrieval.

**Reality**: Compaction summaries (~500-1000 tokens) are system-prompt-style
prose describing extraction strategies, not declarative domain text.  The
default entity extraction prompt (a single generic `Entity` type) is designed
for news articles and business documents — it extracts proper nouns,
organizations, product names, dates, and other concrete entities.  A
compaction summary like:

```
When extracting cross-layer dependencies from a LaserCortex project,
first identify all source modules in the FORMALIZATION layer, then
trace each function's dependencies through the API_GATEWAY layer...
```

would likely produce entities like `"FORMALIZATION layer"`, `"API_GATEWAY
layer"`, `"cross-layer dependencies"` — which are actually useful for search.
But a more abstract summary like:

```
Use the three-pass strategy: (1) schema alignment, (2) edge typing,
(3) invariant propagation.  Pass 1 establishes pairwise layer
mappings; Pass 2 classifies each edge by its constraint type;
Pass 3 pushes Lean4 invariants upstream.
```

might produce entities like `"three-pass strategy"`, `"schema alignment"`,
`"Pass 1"` — some useful, some too generic to discriminate.

**Consequence**: The quality of retrieval for Pathway B depends entirely on
whether entity extraction on summary text produces names that discriminate
between different compaction summaries.  This is an empirical question with
no data yet.  If extraction produces mostly generic entities that match
every query, `search_` will return all summaries and fail to retrieve the
relevant one.

**What would need to be true**: Either (a) default entity extraction works
well on summary text (possible but untested), (b) custom entity types with
narrow schemas are configured for summary episodes (e.g. `TaskType`,
`DomainConcept`, `StrategyPattern` — forcing the LLM to extract task-descriptive
terms), or (c) we add episode-level semantic search to Graphiti or bypass
entity extraction entirely for summary retrieval.

**Note on §7.2**: This is the same class of problem as blocker 7.2 (in-trace
entity extraction noise) but for a different text domain.  The Reflexive
Trace Loop (§7.2) and Reasoning Library (§7.7) face the same entity extraction
quality challenge on different source texts.  A solution for one (custom entity
types, narrow schemas) likely applies to the other.

---

## 8. Relationship to Existing Systems

### 8.1 External Neuro-Symbolic Loop (EXTERNAL_NEURO_SYMBOLIC_LOOP.md)

The reflexive loop is an **additive** mechanism, not a replacement.
The batch compressor (`MetaCompressor`) does something the chain cannot:
distill across multiple traces into a compact script.

| Component | Mechanism | Compression |
|-----------|-----------|-------------|
| V1 reflexive loop | Store traces in Graphiti as they're generated | Identical (no compression) |
| V2 chain + injection | Inject prior trace before extraction | ~2x (per-call reuse) |
| MetaCompressor (existing) | Batch-distill N similar traces → one script | ~7.7x (N-to-1 distillation) |
| V3 chain + MetaCompressor | Use MetaCompressor on accumulated chain | ~7.7x (full) |

The reflexive loop replaces the **pipeline** (where traces are collected
offline and batch-compressed) with a live one, but the **compression step
itself** is still the MetaCompressor or equivalent:

| Old pipeline | New pipeline |
|------------------------|----------------------|
| Collect 200 traces offline | Each trace stored immediately in Graphiti |
| Run MetaCompressor as batch job | Run MetaCompressor periodically on accumulated traces |
| Store scripts in `library.json` | Store distilled scripts as episodes (entity extraction creates searchable EntityNodes) |
| Router matches by embedding centroid | Router matches by Graphiti `search_` on entity names extracted from scripts |
| Traces discarded after compression | Traces retained as graph (provenance, chain history) |

### 8.2 Graphiti Integration Spec (graphiti_integration_spec.md)

The spec described a multi-phase Graphiti rollout.  This architecture
accelerates **Phase 2** (Reasoning Library as Graph) by giving it the
live reflexive loop.  Key differences:

- **Episodes not nodes for traces**: The spec stored traces as
  `ThinkingTrace` entities.  We store them as `EpisodicNode`s in a
  parallel group, which is simpler and avoids polluting entity search.
- **Depth cap**: Not in the spec — new design constraint.
- **Convergence detection**: Not in the spec — new capability.
- **Entity extraction on traces**: The spec assumed entity extraction
  on traces would produce searchable concepts.  This is a blocker (see
  §7.2) — may need custom entity types or no extraction on traces.

### 8.3 Lab Protocol (lab_protocol.md)

The chain operates at the **interface** sector of the (4,4) signature
model — the null cone where zero-divisor channels open between time and
space sectors.  The reasoning trace is the bridge: it converts temporal
(associative) reasoning patterns into spatial (non-associative) reusable
structures, crossing the CD step boundary at `strut_weight² = 16`.

### 8.4 Retrieval Contract Comparison: Legacy vs Graphiti-Native

The existing `scripts/reasoning_library/` (MetaCompressor, router) uses a
**centroid-matching** contract.  The Graphiti Reasoning Library uses a
**entity extraction** contract.  They solve the same problem through
fundamentally different mechanisms:

| Property | Legacy (centroid) | Graphiti-native (entity) |
|----------|-------------------|--------------------------|
| Input type | Embedding vector (1024-dim bge-m3) | Natural language text |
| Index structure | Precomputed cluster means | EntityNode.name_embedding from extracted entities |
| Match method | Cosine similarity to centroid | Hybrid search: cosine + BM25 + graph traversal (RRF) |
| Computation per match | Single vector dot product | Embed + search + rank, O(N) |
| Embedder | bge-m3 (1024-dim) | nomic-embed-text (768-dim, Graphiti's configured embedder) |
| Maintenance | Recompute centroids when cluster changes | None — entities re-extracted on episode update (automatic) |
| Custom infrastructure | Router script, centroid storage, similarity threshold | None — uses Graphiti's built-in search pipeline |
| Precision | High for well-clustered data | Depends on entity extraction quality on summary text |
| Fallback | Hardcoded rules → centroid → layer-pair → full LLM | Graphiti search fallthrough (lower threshold, larger group) |

**The key change**: The legacy contract optimized for precision by
pre-computing cluster centroids.  The Graphiti contract optimizes for
**zero custom infrastructure** by reusing Graphiti's general-purpose
entity extraction and search pipeline — at the cost of retrieval precision
that depends on how well entity extraction works on compaction summary text
(an untested assumption; see §7.7).

**Both contracts produce a `system_prompt`-like string** (the compaction
summary), ~500-1000 tokens, suitable for injection into extraction LLM
calls.  The representation is the same; only the index differs.

---

## 10. Appendix: File Paths & Container Layout

### Container (graphiti-mcp-llamacpp)

All paths are relative to `/app/mcp/` inside the container:

| File | Purpose |
|------|---------|
| `src/graphiti_mcp_server.py` | MCP tool definitions (V3 additions) |
| `src/services/queue_service.py` | Queue worker (V1 + V2 patches) |
| `src/services/factories.py` | LLM client factory (patched for `OpenAIGenericClient`) |
| (site-packages) `graphiti_core/llm_client/openai_generic_client.py` | LLM client (V1 trace capture) |
| (site-packages) `graphiti_core/graphiti.py` | Core Graphiti class (reference only) |
| `docker/llamacpp-config.yaml` | Model config (embedder, LLM endpoints) |

### Host

| Path | Purpose |
|------|---------|
| `/home/nos/labware/opencode-graphiti/docker-compose.yml` | Container orchestration |
| `~/.config/opencode/plugins/opencode-graphiti.ts` | Plugin source |
| `~/.config/opencode/graphiti.jsonc` | Plugin configuration |
| `/home/nos/labware/LaserCortex/scripts/reasoning_library/` | Existing library (MetaCompressor, router) |
| `/home/nos/labware/LaserCortex/docs/reflexive_trace_loop.md` | This document |

### Restart Commands

After patching container files:

```bash
docker restart graphiti-mcp-llamacpp
```

After patching site-packages (`.py` files inside container):

```bash
docker exec graphiti-mcp-llamacpp python3 -c "
from graphiti_core.llm_client.openai_generic_client import OpenAIGenericClient
client = OpenAIGenericClient(...)  # quick import check
print('Patch OK:', hasattr(client, '_reasoning_traces'))
"
docker restart graphiti-mcp-llamacpp
```

---

## 11. Glossary

| Term | Definition |
|------|------------|
| **Trace** | The reasoning content produced by the LLM before structured output, captured from the `reasoning_content` field |
| **Episode** | Graphiti's unit of storage — a raw text body with associated entity extraction |
| **Chain** | Ordered sequence of traces linked by search+inject. Gives ~2x per-call compression from reuse. True distillation requires MetaCompressor (§7.3). |
| **Depth cap** | Maximum number of recursive trace storage levels per extraction (default: 1) |
| **Convergence** | When trace length and content stabilize across requests for similar input types. Not validated — no ground-truth accuracy benchmark (§7.4). |
| **Zero-shot template** | A converged trace used as fixed `custom_extraction_instructions` without search |
| **_traces group** | Parallel Graphiti group (`{group_id}_traces`) storing only reasoning trace episodes |
