# Reasoning Library for Session Traces

## Overview

This system generalizes the existing reasoning library (structured task classification)
to raw opencode session traces. It:

1. **Learns** from accumulated session traces → extracts reasoning patterns
2. **Stores** patterns as three script types: priming prompts, debug runbooks, tool-use chains
3. **Applies** patterns via embedding-based routing to prime new reasoning tasks

## Architecture

```
session-ses_*.md                    ReasoningScript (store)
       │                               ├── Priming prompts
       ▼                               ├── Debug runbooks
┌──────────────────┐                  └── Tool-use chains
│  Phase 1: Parse   │
│  (raw + metadata) │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Phase 2: Cluster │     cluster_key = (domain_tags, intent_category)
│  (embedding sim)  │     min_cluster_size = 3
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Phase 3: Compress│     meta-prompt extracts reusable reasoning strategy
│  (→ scripts)      │     produces: priming + runbook + tool chain
└────────┬─────────┘
         │
         ▼
┌──────────────────┐     reason about this request, apply the script, get result
│  Phase 4: Route   │────► ──────────────────────────────────────► library
│  (learn + apply)  │
└──────────────────┘
```

## Data Model

### ReasoningTrace (extends existing)

```python
@dataclass
class SessionReasoningTrace:
    # Source
    session_id: str                  # ses_114fc7072ffee402COJqzXHy3r
    session_title: str               # "LaserCortex Lean Mathlib integration"
    thinking_block_index: int        # which thinking block within session
    timestamp: float
    
    # Raw content
    thinking_block: str              # the raw _Thinking: content
    
    # Metadata (two-tier: extracted on parse, refined on distill)
    intent_category: str             # e.g. "lean_refactor", "debug_oom", "server_tuning"
    domain_tags: list[str]           # e.g. ["Lean", "LogicType", "LiarParadox"]
    tools_used: list[str]            # e.g. ["bash", "read", "edit", "grep"]
    tools_chain: str                 # "bash -> grep -> edit -> read"
    outcome: str                     # success/failure/deferred
    outcome_detail: str              # what actually happened
    
    # Compressed (after distillation)
    reasoning_template_id: str | None  # which ReasoningScript this contributed to
    confidence: float = 0.0          # how well this trace matches its script
    
    # For routing
    embedding: list[float] | None    # bge-m3 on (intent + domain_tags + thinking_block summary)
```

### ReasoningScript (extends existing, multi-format)

```python
@dataclass
class SessionReasoningScript:
    id: str
    session_id: str                  # originating session
    
    # Three script formats
    priming_prompt: str | None       # "When debugging OOM: check swap → memory → parallelism"
    debug_runbook: str | None        # Step-by-step diagnostic procedure
    tool_chain: str | None           # "bash → read → edit → grep → verify"
    
    # Metadata
    intent_category: str
    domain_tags: list[str]
    centroid: list[float]            # average embedding
    version: int = 1
    
    # Quality
    source_trace_count: int = 0
    confidence: float = 0.0
    created_at: float = 0.0
```

### Archiving Schema (TBD with user)

A taxonomy of reasoning domains for clustering and indexing:

```
reasoning_domains:
  lean_formalization:
    - module_refactoring
    - type_error_debug
    - theorem_proving
    - import_analysis
  infra_operational:
    - server_tuning
    - memory_debug
    - docker_lifecycle
    - swap_analysis
  research_exploration:
    - literature_review
    - concept_clarification
    - pattern_identification
  pipeline_work:
    - batch_processing
    - script_development
    - config_management
  normcode_cortex:
    - tree_mapping
    - certificate_operations
    - orchestration
  general_problem_solving:
    - decision_tradeoff
    - self_correction
    - verification
```

## Phases

### Phase 1: Parse Sessions (raw + metadata)

**Input:** session-ses_*.md files (~5MB, 10 sessions)
**Output:** JSON lines file of ReasoningTrace objects

Steps:
1. Parse each session file, extract:
   - Session metadata (title, ID, timestamp)
   - All `_Thinking:` blocks
   - Tool call sequence
   - Outcome (from session summary or success markers)
2. For each thinking block, extract:
   - Domain tags (capitalized domain terms, filtered)
   - Tool chain (sequence of Tool: calls after this block)
   - Intent category (via 35B classification or rule-based)
   - Outcome (success/failure/deferred)
3. Store as JSONL in `LaserCortex/reasoning_library/traces.jsonl`
4. Store raw session file references in `LaserCortex/reasoning_library/sessions.json`

### Phase 2: Cluster Traces

**Input:** traces.jsonl
**Output:** Cluster assignments

Steps:
1. For each trace, compute embedding: bge-m3 on `(intent_category, domain_tags, first 200 chars of thinking_block)`
2. Cluster traces using agglomerative clustering on embeddings
   - Distance threshold: ~0.60 cosine similarity (based on existing router experience)
   - Min cluster size: 3 traces
   - Cluster key: `(domain_tags_intersection, intent_category)`
3. Label clusters with dominant domain tags and intent category
4. Store cluster assignments in `LaserCortex/reasoning_library/clusters.json`

### Phase 3: Compress into Scripts

**Input:** clusters from Phase 2
**Output:** ReasoningScript objects

For each cluster with ≥3 traces:
1. Send meta-prompt to 35B: "Analyze these N reasoning traces and produce:
   - A priming prompt (what to think about for this type of task)
   - A debug runbook (if errors/warnings appear, follow these steps)
   - A tool-use chain (recommended tool sequence)
   - Domain tags and intent category"
2. Parse the 35B output → create SessionReasoningScript
3. Compute centroid from trace embeddings
4. Store in `LaserCortex/reasoning_library/scripts.json`
5. Save combined library to `LaserCortex/reasoning_library/library.json` (backward compatible with existing reasoning_library)

### Phase 4: Route (Learn + Apply)

**Integration:** Two hooks

**Hook A: Learn (post-parse)**
- After Phase 1–3 complete, the library is updated
- New traces incrementally update existing scripts
- Orphan traces (no cluster) accumulate for future compression

**Hook B: Apply (pre-reasoning)**
- When a new user request arrives, before the LLM starts thinking:
  1. Embed the request (bge-m3)
  2. Route through EmbeddingRouter (existing infrastructure)
  3. If a script matches:
     - Inject the priming_prompt into the system prompt
     - Inject the tool_chain as a suggestion
     - If the request looks like a debug scenario, inject the debug_runbook
  4. If no match: raw reasoning (no script applied)
- The resulting reasoning trace is captured and added to the library

## File Layout

```
LaserCortex/reasoning_library/
├── README.md                  # This file
├── parser.py                  # Phase 1: session → ReasoningTrace
├── clusterer.py               # Phase 2: traces → clusters
├── compressor.py              # Phase 3: clusters → scripts (extends existing)
├── router.py                  # Phase 4: request → script matching (extends existing)
├── traces.jsonl               # Parsed reasoning traces
├── clusters.json              # Cluster assignments
├── scripts.json               # Compressed reasoning scripts
├── sessions.json              # Session file references + metadata
└── library.json               # Combined library (backward compatible)

open-notebook/scripts/pipeline/reasoning_library/
├── models.py                  # Extends with SessionReasoningTrace, SessionReasoningScript
├── library.py                 # Adds SessionReasoningLibrary
├── compressor.py              # Adds session-specific compression
└── router.py                  # Adds session-aware routing
```

## Integration with Existing Reasoning Library

The new session-based reasoning library extends (not replaces) the existing structured-task library:

- `models.py`: Add `SessionReasoningTrace`, `SessionReasoningScript` alongside existing types
- `library.py`: `ReasoningLibrary` handles structured traces; `SessionReasoningLibrary` handles session traces. A combined `MetaLibrary` can query both.
- `compressor.py`: `MetaCompressor` handles structured traces; `SessionCompressor` handles session traces.
- `router.py`: `EmbeddingRouter` routes structured inputs; `SessionRouter` routes natural language requests.

## Open Questions

1. **Archiving schema taxonomy**: User-defined categories for domain tagging (TBD)
2. **Compression trigger frequency**: Run compressors on-demand or scheduled (nightly?)
3. **Script versioning**: How to handle when a new trace contradicts an existing script?
4. **Routing priority**: When multiple scripts match (different domains), which takes precedence?
5. **Embedding endpoint**: Use the existing bge-m3 embed server (from Open Notebook) or a dedicated one?
6. **Script injection point**: Where exactly in the opencode pipeline do injected scripts go?
   - As system prompt prefix?
   - As a separate "context" message?
   - As a structured instruction block?
