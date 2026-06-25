# Reasoning Library — Implementation Guideline

> Based on audit of commit `c972050`. 35B A3B model, 8GB VRAM, 128K context.
> Apply TDD. No exceptions.

---

## 1. Commitments

**1.1 Tests before code.** Every module must have a test file (`test_*.py`) before
any production code is committed. Tests run under `pytest` from the repo root.
Coverage floor: 85% of branches in each module.

**1.2 No `sys.path` hacks.** The import shim pattern found in every file
(`import sys, os; if __package__ is None: sys.path.insert(...)`) is banned.
Replace with a single `__main__.py` entry point and relative imports for all
module-internal references.

**1.3 No dead code.** Every exported function must be called somewhere (either by
the pipeline, the MCP server, or a test). Every regex must have a test that
exercises both its match and non-match paths.

**1.4 Confidence must be real.** If a field is named `confidence`, it must be
computed—not left at `0.0`. "We haven't implemented this yet" is not a valid
value in committed code.

---

## 2. Test Infrastructure

### 2.1 Directory Layout

```
reasoning_library/
├── models.py                # dataclasses only
├── parser.py                # no runtime side effects
├── embedder.py              # HTTP to bge-m3
├── clusterer.py             # no runtime side effects
├── compressor.py            # HTTP to 35B
├── pipeline.py              # CLI entry point
├── mcp_server.py            # HTTP server
├── __main__.py              # invokes pipeline or mcp_server
├── tests/
│   ├── conftest.py           # shared fixtures
│   ├── test_parser.py        # ≥ 10 test cases
│   ├── test_clusterer.py     # ≥ 8 test cases
│   ├── test_embedder.py      # ≥ 3 test cases (mock HTTP)
│   ├── test_compressor.py    # ≥ 5 test cases (mock HTTP)
│   ├── test_pipeline.py      # integration (fixture files)
│   ├── test_mcp_server.py    # ≥ 3 test cases (mock embed)
│   └── fixtures/
│       ├── session_short.md  # 3 thinking blocks, 2 tools
│       ├── session_minimal.md# 1 thinking block, no tools
│       ├── session_weird.md  # malformed: missing metadata, no tools
│       └── traces_known.jsonl# 5 hand-crafted known traces
│           # trace 0-1: same intent, high similarity
│           # trace 2-3: same intent, low similarity
│           # trace 4:   different intent, high similarity to 0
└── conftest.py               # (optional, module-level fixtures)
```

### 2.2 Fixture Specification

**`session_short.md`:**
```
# Test Session
**Session ID:** ses_test_001
**Created:** 6/25/2026, 12:00:00 PM

---

## User
Test request

---

## Assistant (Build · 35B · 10.0s)

_Thinking:_

This is a test thinking block about Docker container memory limits.

**Tool: read**

**Input:**
```
{"filePath": "/tmp/test"}
```

**Output:**
```
content
```

---

## Assistant (Build · 35B · 5.0s)

_Thinking:_

Another thinking block about refactoring Lean modules.

**Tool: bash**
...

**Tool: edit**
...
```

**`traces_known.jsonl`:** 5 hand-crafted traces with known embeddings
(1024-dim, but only first 3 values matter for clustering tests). Trace 0 and 1
are the same intent with cosine 0.85. Trace 2 and 3 are the same intent with
cosine 0.30. Trace 4 has a different intent and cosine 0.91 with trace 0.

### 2.3 Required Test Coverage

**`test_parser.py`:**
- Parses standard session → correct number of thinking blocks
- Parses session with no tools → thinking block still extracted
- Parses session with missing metadata → graceful fallback (filename as ID)
- Session with consecutive `_Thinking:_` blocks → each extracted correctly
- Session with normcode format → 0 blocks returned (not crash)
- `detect_outcome` correctly marks success/failure/deferred
- `_classify_intent` correctly classifies known keywords
- `_classify_intent` returns `general_problem_solving` for gibberish
- Relative paths in session_file output are resolved to absolute

**`test_clusterer.py`:**
- 5 known traces with known similarities → correct cluster assignment
  - cluster_traces(traces_known, threshold=0.6) → 2 clusters: {0,1}, {2,3}
  - cluster_traces(traces_known, threshold=0.95) → 0 clusters (all too different)
  - cluster_traces(traces_known, threshold=0.0) → 1 cluster {0,1,2,3,4} (merge all)
- Empty trace list → empty cluster list
- `< min_cluster_size` traces → empty cluster list
- Traces without embeddings → empty cluster list (not crash)
- Cluster centroid is mean of member embeddings
- `TraceCluster.dominant_intent` returns correct mode
- `TraceCluster.all_tags` returns union of member tags

**`test_embedder.py`:**
- `_embed_batch` with valid server → correct 1024-dim vectors
- `_embed_batch` with down server → raises ConnectionError
- `embed_batch` with mixed success/failure → zero vectors for failures
- `cosine_similarity(identical, identical)` → 1.0
- `cosine_similarity(opposite, opposite)` → -1.0
- `cosine_similarity(zero, anything)` → 0.0

**`test_compressor.py`:**
- `compress_cluster_via_model` with mock 35B response → correct script
- Mock 35B response with malformed sections → graceful parse (missing fields empty)
- Mock 35B response with timeout → returns None
- `compress_heuristic` produces non-empty priming from first trace
- `compress_heuristic` tool chain is deduplicated and frequency-sorted
- Script version=1 for model-based, version=0 for heuristic

**`test_mcp_server.py`:**
- Health check returns 200
- `/lookup` with valid query returns match with correct structure
- `/lookup` with empty query_text returns 400
- `/lookup` with bad JSON body returns 400
- `/lookup` with library file missing returns 500
- Pattern lookup: nearest centroid by cosine similarity returned

---

## 3. Refactoring Requirements

### 3.1 Import Cleanup (P0)

Replace the `sys.path` shim pattern in all 7 module files:

**Current (banned):**
```python
from __future__ import annotations
import sys, os
if __package__ is None:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from models import ...
```

**Target:**
- All modules use relative imports: `from .models import ...`
- `__main__.py` handles both `python3 -m reasoning_library` and direct execution:
```python
# __main__.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
# No other file does this.
```

- **Test:** After cleanup, `python3 reasoning_library/pipeline.py --help` works,
  `python3 -m reasoning_library` works, `pytest reasoning_library/tests/` works.

### 3.2 Remove Dead Code (P1)

| File | Dead function/regex | Action |
|------|-------------------|--------|
| `parser.py:48-50` | `_TOOL_RE` | Remove (unused regex, only `r"\*\*Tool:\s*(\w+)\s*\*\*"` in the loop is used) |
| `models.py:167-180` | `traces_from_jsonl()` | Remove (zero callers) |
| `embedder.py:41-45` | `embed_trace()` | Remove (zero callers, `embed_batch` used instead) |
| `__init__.py:27` | `_embed_batch` in `__all__` | Remove from exports (it's private) |

### 3.3 Embedding Persistence (P1)

**Problem:** `traces.jsonl` is written in Phase 1, before embeddings are
computed in Phase 2. Trace embeddings are lost after the pipeline run.

**Fix:** Rewrite `traces.jsonl` after Phase 2 with embeddings included. The
`to_dict()` method already handles embedding storage (with `_embedding_prefix`
compression). The pipeline should:

```python
# Phase 2: Embed
embeddings = embed_batch(traces)
for i, emb in enumerate(embeddings):
    traces[i].embedding = emb

# Phase 2b: Rewrite traces with embeddings
with open(traces_path, "w") as f:
    for t in traces:
        f.write(trace_to_jsonl_line(t) + "\n")
```

**Test:** After pipeline run, each line in `traces.jsonl` contains
`_embedding_prefix` and `_embedding_len` keys.

### 3.4 Heuristic Compressor Upgrade (P1)

**Problem:** `compress_heuristic` copies the first trace's thinking preview
verbatim as the priming prompt. 3-step boilerplate for the runbook. This
produces scripts that cannot meaningfully improve reasoning quality.

**Fix:** Replace heuristic with a **structured template** that at minimum
generalizes across all traces in the cluster:

```python
def compress_heuristic(cluster, traces):
    """Template-based compression with cluster-aware generalization."""
    cluster_traces = [traces[i] for i in cluster.members]

    # Extract common tools (frequency >= 50% of member traces)
    tool_freq = defaultdict(int)
    for t in cluster_traces:
        for tool in set(t.tools_used):
            tool_freq[tool] += 1
    common_tools = sorted(
        [t for t, c in tool_freq.items()
         if c >= len(cluster_traces) * 0.5],
        key=lambda t: tool_freq[t], reverse=True
    )
    tool_chain = " -> ".join(common_tools[:5])

    # Priming: generalize from common thinking themes
    # Extract first sentence from each trace, find most common root concepts
    intents = [t.intent_category for t in cluster_traces]
    tags = cluster.all_tags
    domain_str = ", ".join(tags[:5]) if tags else "this domain"

    priming = (
        f"When working on {cluster.dominant_intent} involving {domain_str}: "
        f"start with {common_tools[0] if common_tools else 'reviewing the context'}, "
        f"check for {tags[0] if tags else 'relevant patterns'}, "
        f"and verify against {len(cluster_traces)} known approaches."
    )

    # Runbook: extract step-like patterns from thinking blocks
    runbook = extract_step_pattern(cluster_traces)

    return SessionReasoningScript(
        id=f"script_{cluster.cluster_id}_heuristic",
        priming_prompt=priming,
        debug_runbook=runbook,
        tool_chain=tool_chain,
        intent_category=cluster.dominant_intent,
        domain_tags=cluster.all_tags,
        centroid=cluster.centroid,
        source_trace_count=len(cluster.members),
        confidence=len(cluster.members) / 758,  # fraction of total traces
        version=0,
    )
```

**Test:** After fix, heuristic scripts should have unique, cluster-specific
priming prompts (no trace text copied verbatim). Runbook should reference
actual error patterns from the cluster.

### 3.5 TraceCluster._traces Hack (P2)

**Problem:** `TraceCluster.dominant_intent` and `all_tags` properties require
a reference to the full traces list. The `set_traces()` method sets a private
`_traces` attribute that silently fails if not set.

**Fix A (preferred):** Pass `traces` at cluster construction time:
```python
@dataclass
class TraceCluster:
    cluster_id: int
    members: list[int]
    _traces: list[SessionReasoningTrace]  # reference, not default_factory
    ...
```

**Fix B (if Fix A breaks serialization):** Compute `dominant_intent` and
`all_tags` once during `cluster_traces()` and store them as plain fields,
not properties:
```python
# In cluster_traces():
for c in clusters:
    c.intent_category = c.dominant_intent  # was a property
    c.domain_tags = c.all_tags  # was a property
```

Then remove the `dominant_intent` and `all_tags` properties entirely.
They're only computed once at the end anyway.

**Test:** `TraceCluster` instances created with `members=[0,1]` and
`_traces=[trace0, trace1]` return correct `dominant_intent` and `all_tags`
without calling any setter method.

### 3.6 MCP Server Threading (P2)

**Problem:** Uses single-threaded `HTTPServer`, so `/lookup` blocks
`/health` and all other requests during the 1-2 second embed call.

**Fix:** Replace with `ThreadingHTTPServer`:
```python
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

def main():
    ...
    server = ThreadingHTTPServer(("0.0.0.0", args.port), MCPRequestHandler)
```

**Test:** Simultaneous `/health` and `/lookup` requests both complete.
`/health` returns in < 10ms even while `/lookup` is processing.

### 3.7 Confidence Computation (P2)

**Problem:** `confidence` is always `0.0`.

**Fix:** Compute confidence as a function of intra-cluster agreement:
```python
def compute_cluster_confidence(cluster, traces):
    """Confidence = average pairwise cosine similarity within cluster,
    weighted by cluster size / total traces."""
    members = [traces[i] for i in cluster.members]
    if len(members) < 2:
        return 0.0

    pairwise_sims = []
    for i in range(len(members)):
        for j in range(i + 1, len(members)):
            sim = cosine_similarity(members[i].embedding, members[j].embedding)
            pairwise_sims.append(sim)

    avg_sim = sum(pairwise_sims) / len(pairwise_sims) if pairwise_sims else 0.0
    size_weight = len(members) / 758  # fraction of total traces
    return avg_sim * size_weight
```

**Test:** Cluster with 3 identical traces → confidence = 1.0 * (3/758) ≈ 0.004.
Cluster with 3 random traces → confidence ≈ 0.

### 3.8 Relative Path Resolution (P3)

**Problem:** `session_file` stores paths like `'../session-ses_1065.md'`.

**Fix:** Resolve to absolute paths in `parse_session_file`:
```python
trace = SessionReasoningTrace(
    session_file=os.path.abspath(filepath),
    ...
)
```

**Test:** After fix, `trace.session_file` is always absolute (starts with `/`).

---

## 4. New Feature Requirements

### 4.1 Incremental Cluster Update (P2)

**Specification:**

```python
def update_clusters(existing_clusters: list[TraceCluster],
                    new_traces: list[SessionReasoningTrace],
                    threshold: float = 0.65) -> list[TraceCluster]:
    """Add new traces to existing clusters, creating new clusters if needed.

    1. For each new trace, find nearest cluster centroid (cosine similarity).
    2. If similarity >= threshold and intents match, add to cluster.
    3. Otherwise, leave unassigned (accumulate for future batch).
    4. Recompute centroids for clusters that gained members.
    """
```

**Rules:**
- Only changes cluster memberships, never deletes a cluster.
- Unassigned traces accumulate in a separate pool.
- When pool size >= `min_cluster_size` × 3, a re-cluster is triggered.

**Test:**
- 2 clusters + 3 new traces, 2 match existing clusters, 1 doesn't
  → both clusters gain 1 member, 1 trace in pool.
- Pool reaches threshold → re-cluster triggered, new cluster formed.

### 4.2 Model Compression as Default (P1)

**Problem:** The default pipeline run uses heuristic compression
(`--no-model` was default in the audit run). The scripts are low-quality.

**Fix:** Swap the default: model-based compression is the default, heuristic
is the fallback when the 35B server is unavailable.

```python
def compress_cluster(cluster, traces, model_url=None):
    if model_url:
        script = compress_cluster_via_model(cluster, traces, model_url)
        if script is not None:
            return script
    return compress_heuristic(cluster, traces)
```

**Pipeline flag change:** `--no-model` stays as opt-out. The default switches
from heuristic to model-based when `model_url` is available.

**Performance note:** 86 clusters × ~75s per 35B call = ~107 minutes for a
full pipeline run. This **will** hit the 120s bash timeout. The pipeline must
either (a) batch clusters into a single 35B call, or (b) run as a background
process with a status endpoint.

### 4.3 35B Batch Compression (P2)

**Problem:** 86 separate 35B calls takes too long.

**Fix:** Send multiple clusters in one prompt:
```python
BATCH_PROMPT_TEMPLATE = """Compress the following reasoning clusters into scripts.

{cluster_blocks}

Output for each cluster using the format:

=== CLUSTER <n> ===
=== PRIMING ===
...
=== RUNBOOK ===
...
=== TOOL CHAIN ===
...
=== METADATA ===
intent: ...
tags: ...
"""
```

Batch size: 5-8 clusters per call. Test latency: if each batch takes 90s,
total compression time = ceil(86/6) × 90s ≈ 15 × 90s ≈ 22 minutes instead
of 107.

**Test:** Single 35B call with 3 clusters → correctly parses all 3 sections
with correct cluster numbering.

### 4.4 Reasonable Expectations of RSI

**What this system is:**
- An extractor: raw session text → structured traces with known intents
- A clusterer: traces → grouped by semantic similarity + intent
- A lookup: user query → nearest matching reasoning pattern

**What it is NOT yet:**
- Not recursive (no feedback loop)
- Not self-improving (no mechanism to learn from lookup outcomes)
- Not a reasoning multiplier (the scripts don't demonstrably reduce token
  consumption or improve accuracy)

**To close the RSI loop, implement these in order:**

1. **Model compression (P1):** Scripts must be 35B-generated, not templates.
   Without this, the "compressed pattern" is just a text fragment.

2. **Lookup tracking (P2):** Log every MCP lookup and whether the user
   accepted the priming prompt. Track session outcome before/after script use.
   This is the feedback signal.

3. **Outcome-weighted centroid adjustment (P3):** Shift centroids toward
   matched-but-outcome-improved and away from matched-but-outcome-worsened.

4. **Automatic injection (P3):** Hook the MCP lookup into the model's
   system prompt automatically (not manual curl). This requires modifying
   opencode's prompt construction to call `/lookup` before reasoning.

5. **Re-compression trigger (P2):** After N successful lookups or M new
   traces, auto-trigger pipeline to regenerate scripts with accumulated data.

---

## 5. Regressions to Watch For

| Change | Regression Risk | Mitigation |
|--------|----------------|------------|
| Import cleanup | Pipeline won't find modules | Run `python3 -m reasoning_library.pipeline --help` first |
| Remove dead code | Something I thought was dead is actually called | `grep -r 'traces_from_jsonl' .` before deleting |
| Embedding persistence | Doubles file I/O (write twice) | Only relevant for 758+ trace runs; negligible |
| MCP threading | Thread safety in handler | Handler is stateless (reads library.json each request) |
| Relative path fix | Breaks scripts that reference sessions by relative path | Check: `grep 'session\.\./'` in any consuming code |
| Heuristic upgrade | Scripts might get longer | Set char limit: `priming[:400]` |
| Model compression | 107 min pipeline = timeout | Add `--timeout-min` flag + background process |

---

## 6. Priority Order for Implementation

```
P0: Import cleanup + dead code removal
P0: Test fixtures + conftest.py
├── test_parser.py (9 tests)
├── test_clusterer.py (8 tests)
├── test_embedder.py (5 tests)
├── test_compressor.py (4 tests)
├── test_mcp_server.py (6 tests)
│
P1: Embedding persistence fix
P1: Heuristic compressor upgrade
P1: Model compression as default
│
P2: TraceCluster._traces hack fix
P2: MCP server threading fix
P2: Confidence computation
P2: Batch 35B compression
P2: Incremental cluster update
│
P3: Relative path resolution
P3: Lookup tracking
P3: Close RSI loops (auto-injection, re-compression)
```

---

## 7. Definition of Done

A module is "done" when:

1. Its test file has ≥ the required number of test cases
2. All tests pass under `pytest reasoning_library/tests/`
3. Coverage report shows ≥ 85% branch coverage for that module
4. No `sys.path` hacks remain
5. No dead functions exist
6. All confidence/duration fields are populated with real values
7. `python3 -m reasoning_library.pipeline --help` works from `LaserCortex/`
8. `python3 -m reasoning_library.mcp_server --help` works from `LaserCortex/`
9. Pre-existing pipeline output reproduces (same traces → same-ish clusters)
