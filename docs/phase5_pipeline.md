# Phase 5: Hybrid bge-m3 + 35B Cross-Layer Dependency Discovery

Replaces the monolithic Pass 3 (a single 332K-char 35B call) with a scalable
two-stage pipeline that discovers semantic dependencies across architectural
layers (FORMALIZATION ↔ API_GATEWAY ↔ PRESENTATION).

Uses the [Reasoning Library](../scripts/reasoning_library/) (canonical source
in [open-notebook/scripts/pipeline/reasoning_library/](../open-notebook/scripts/pipeline/reasoning_library/))
for three-tier routing that reduces 35B reasoning tokens by ~97%.

## What it does

Given a codebase with modules annotated by layer (FORMALIZATION, API_GATEWAY,
PRESENTATION), Phase 5 discovers **cross-layer semantic dependencies** —
edges that a static import graph cannot detect because the dependency is
conceptual rather than syntactic.

**Edge types discovered:**
- **SPECIFICATION** (40%): The Lean formalization defines semantics that the
  Python implementation must match.
- **CONSTRAINT** (49%): The Python API enforces requirements that the
  TypeScript UI must satisfy.
- **DATA_SOURCE** (11%): The Python module provides data that the TypeScript
  module consumes.

## Architecture

### Stage 1: Candidate Generation

```
phonebook cache (1400+ modules)
        │
        ▼
  bge-m3 embed server (:8082)
        │
        ▼
  All-vs-all cross-layer cosine similarity
        │
        ▼
  Top-K candidate pairs (threshold + max-pairs)
```

Returns ~200 candidate pairs (above similarity 0.50).

### Stage 2: Verification with Reasoning Library

```
Candidate pair
        │
        ▼
  ┌─ Hardcoded rule? ──► instant (no LLM)
  │
  ┌─ Script centroid? ──► compressed prompt (~20s)
  │
  ┌─ Layer-pair match? ──► layer-specific script (~20s)
  │
  └─ Fallback ──► full 35B reasoning (~60s)
        │
        ▼
  Verified edge (edge_type, invariant, failure_mode)
        │
        ▼
  Stored in verify cache + reasoning library
```

## Usage

### Prerequisites

- 35B reasoning model running on `:8080`
- bge-m3 embed server running on `:8082`
- Phonebook cache built and indexed

### Stage 1: Generate candidates

```bash
python3 scripts/phase5_cross_layer_discovery.py candidates \
  --threshold 0.5 --max-pairs 200
```

Output: `/tmp/phase5_candidates.json`

### Stage 2: Verify candidates

```bash
# With embed server (recommended — enables script centroid matching):
python3 scripts/phase5_cross_layer_discovery.py verify

# Without embed server (layer-pair fallback only):
python3 scripts/phase5_cross_layer_discovery.py verify \
  --candidates-file /tmp/phase5_candidates.json
```

Output: verified edges appended to `DEPENDENCY_GRAPH.json`

### Seed the reasoning library

```bash
python3 scripts/setup_reasoning_library.py
```

This migrates existing verification cache entries into the reasoning library
format, creates hardcoded rules, and compresses trace clusters into scripts.

### Full pipeline

```bash
python3 scripts/phase5_cross_layer_discovery.py run --max-pairs 200
```

## Results (June 2026 run)

| Metric | Value |
|--------|-------|
| Total candidates | 200 |
| Verified edges | 131 (66% hit rate) |
| Script-routed | 98% of pairs |
| Script reasoning tokens | 24 words (mean) |
| Fallback reasoning tokens | 1015 words (mean) |
| Token savings | 97.7% |

### Edge types discovered

- **CONSTRAINT**: 61 — the most common cross-layer type
- **SPECIFICATION**: 50
- **DATA_SOURCE**: 21

### Layer pairs

- API_GATEWAY → PRESENTATION: 95
- FORMALIZATION → API_GATEWAY: 26
- FORMALIZATION → PRESENTATION: 4

## File layout

```
scripts/
├── phase5_cross_layer_discovery.py   # Main pipeline (candidates + verify + run)
├── setup_reasoning_library.py        # Seed library from cache
├── reasoning_library/                # Local copy (canonical in open-notebook)
│   ├── __init__.py
│   ├── models.py                     # TaskConfig, ReasoningTrace, etc.
│   ├── library.py                    # ReasoningLibrary persistence
│   ├── compressor.py                 # MetaCompressor (trace→script)
│   └── router.py                     # EmbeddingRouter (three-tier)
├── test_h3_prefilter.py             # H3 pre-filter test
└── start_embed_server.sh            # Embed server lifecycle with resource guards
```

## Key findings

1. **Reasoning models benefit from script compression** — even though the 35B
   always produces `reasoning_content`, a good system prompt reduces it from
   ~1000 to ~24 words.

2. **Embedding centroids need ≥30 traces** for 0.70+ threshold matching.
   With 12-21 traces, most pairs max at ~0.60-0.66 similarity.

3. **Layer-pair fallback** is essential — it ensures every pair with a known
   layer combination gets a script, even when centroid matching fails.

4. **Hardcoded rules are the biggest win** — 14/200 candidates matched
   instantly with no LLM call.

## Remaining gaps

See the [Reasoning Library README](../scripts/reasoning_library/README.md)
for framework-level gaps. LaserCortex-specific gaps:

1. **Cache format**: The verify cache (`/tmp/phase5_verify_cache.json`) stores
   results in a simpler format than the reasoning library traces. The two
   caches are not fully integrated.

2. **No incremental re-compression**: New traces don't automatically trigger
   script regeneration. Run `setup_reasoning_library.py` periodically.

3. **DEPENDENCY_GRAPH.json is gitignored**: It's a build artifact. Generated
   graphs must be shared manually or via a CI artifact.

4. **35B timeouts**: ~5% of pairs timeout at 120s on the 35B. Each timeout
   wastes 6 minutes (3 retries × 120s). The model occasionally gets stuck
   in long reasoning loops for certain input combinations.
