# V4.1: Compaction Gate Design

## Architecture: Two Gates, One Housekeeping Pass

### Gate A — Novelty (per-trace, inline)

After each base Graphiti task captures a reasoning trace, check whether the
existing injected template already covers the reasoning:

```
if no existing template for this task_name:
    → compact (first run, produce initial template)

elif len(raw_trace) >= len(existing_template):
    → compact + merge residual into template
    (novel methodology found, enrich the template)

else:
    → store raw trace in small-traces pool (skip LLM compaction call)
    (template is adequate, no novel methodology detected)

Skip entirely: any trace from a dedupe_* task (dedupe is inherently compact).
```

The injection template always contains the most compact representation of the
methodology. When a trace is shorter than the template, the template already
covers everything the model needed — no compaction work needed.

### Gate B — Housekeeping (batch, after episode)

After each episode's trace processing loop, check the small-traces pool for
each task_name:

```
for each task_name with count(small_traces) >= 10:
    1. Load checkpoint (saved reference version of the template)
    2. Load all 10 small traces from DB
    3. Batch compaction call:
       "Here are 10 small reasoning residuals and the current template.
        Detect themes across them. If they add novel methodology beyond
        the template, produce an updated template. If not, return the
        existing template unchanged."
    4. Run checkpoint health check:
         embed(checkpoint)  → vector reference
         embed(current)     → vector of template after merge
         sim = cosine_similarity(embed(checkpoint), embed(current))
         len_ratio = len(current) / len(checkpoint)

         if len_ratio > 1.5 OR sim < 0.85:
             → CORRUPTED
             revert to checkpoint
             log warning
         else:
             → HEALTHY
             promote current template to new checkpoint
             (this is the reference for future drift checks)

    5. Clear small-traces pool for this task_name
    6. Update injection template (both in-memory and DB)
```

## Data Model

| FalkorDB group | Content |
|----------------|---------|
| `main_traces` | Compacted templates (1 per task_name, overwritten on update) |
| `main_small_traces` | Raw traces where compaction was skipped (accumulated) |
| `main_checkpoints` | Previous template versions (snapshots for drift detection) |

Each template has a `source_description` prefix that identifies it:
- `"Reasoning trace from {task_name} for episode {uuid}"` → compacted template
- `"Small trace from {task_name} for episode {uuid}"` → small-traces pool entry
- `"Checkpoint for {task_name} from episode {uuid}"` → checkpoint snapshot

## Drift Detection

Two metrics, checked together:

1. **Length ratio**: `len(current) ≤ 1.5 × len(checkpoint)`
   - Catches template explosion from bad merges
   - Fixed threshold, hardcoded

2. **Semantic similarity**: `cosine_sim(embed(checkpoint), embed(current)) ≥ 0.85`
   - Catches content drift even when length is stable
   - Uses the existing embedding service (`EMBEDDING_API_URL`)
   - Fixed threshold, hardcoded

Both must pass for the template to be promoted to new checkpoint.
If either fails: revert to checkpoint.

## Files to Modify

### `docker/llamacpp-queue-service.py`
- Skip `dedupe_*` traces entirely (no capture, storage, or injection)
- `_should_compact(trace_text, task_name)` → bool gate
- `_merge_template(existing_template, new_trace, task_name)` → enriched template
- `_store_small_trace()` → write to `main_small_traces` group
- `_load_small_traces(task_name)` → retrieve accumulated traces
- `_batch_compact_small_traces()` → aggregate prompt at 10-trace threshold
- `_embed_text(text)` → call embedding API
- `_checkpoint_health(checkpoint, current)` → length + sim check
- `_save_checkpoint(task_name, template)` → DB snapshot
- `_load_checkpoint(task_name)` → retrieve snapshot

### `docker/prompts/compact_reasoning.py`
- `merge_reasoning(template, new_trace)` — prompt for Gate A merges
- `aggregate_small_traces(template, traces)` — prompt for Gate B batch

### No changes
- `docker/llamacpp-openai-generic-client.py` (trace capture + supression already in place)
- `docker-compose.yml` (all volume mounts already present)

## Convergence Behavior

```
Episode 1:  No template → compact (12K → 400 chars). Stored as checkpoint.
Episode 2:  Template injected. Trace = 7K. 7K >= 400 → merge → ~500 chars.
            Health check: len_ratio=1.25, sim~0.95 → promote to checkpoint.
            Small traces: 0 accumulated.
Episode 3+: Residual shrinks. Eventually trace < template → stored as small trace.
            After ~10 residuals accumulate → housekeeping triggers.
            Batch aggregation: "10 small traces, detect themes."
            Likely result: no novel methodology found → template unchanged.
            Small-traces pool cleared.

Stable state: Template is fixed. Small traces accumulate and are periodically
              batch-checked for novelty, finding nothing. No more compaction LLM
              calls except the occasional housekeeping batch pass.
```

## Overhead

| Pass | LLM calls per episode | When |
|------|----------------------|------|
| Gate A merge | 0-2 (extract_nodes + extract_edges, only when len(raw) >= len(template)) | Inline, after episode |
| Gate B batch | 0-2 (only when 10 small traces accumulated) | After episode, rarely |
| Embedding | 2-4 per housekeeping pass | During checkpoint health check |
| Dedupe skipped | −6 to −7 calls per episode | Always |

Net: ~2-3 LLM calls per episode (down from 9), with rare batch passes.

## Measurement

**Primary metric**: Reasoning time (wall-clock seconds). Each trace entry now includes
`duration_ms` captured at the LLM API call level. The queue service reports per-task
timing at the end of each episode:

```
  Episode timing by task:
    dedupe_edges.resolve_edge: 1271.4s total, 254.29s avg across 5 call(s)
    dedupe_nodes.nodes: 164.1s total, 164.11s avg across 1 call(s)
    extract_edges.edge: 235.0s total, 234.99s avg across 1 call(s)
    extract_nodes.extract_text: 140.6s total, 140.59s avg across 1 call(s)
    TOTAL: 1811.1s reasoning time
```

**Secondary metric**: Trace length (bytes) — supporting information to time.

**Not measured**: Compression ratio of stored templates (misleading — reducing
stored trace size does not reduce reasoning time).

## Meta-level Suppression

All meta-level LLM calls (compaction, merge, batch aggregate) use:
1. `_suppress_trace_capture = True` — prevents trace capture from the call
2. No `prompt_name` passed — prevents injection of templates into the meta-call
3. Raw httpx for embedding — no LLM client involvement

This ensures the reflexive loop never captures or injects its own meta-traces.
