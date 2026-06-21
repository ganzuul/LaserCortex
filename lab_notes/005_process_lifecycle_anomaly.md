# Process Lifecycle Anomaly: Embedding Server Runaway

**Date:** 2026-06-17
**Tags:** `#devops` `#process-management` `#embedding-server` `#technical-debt`

## Observed Behavior

On 2026-06-17 at ~07:59, the `embedding_server.py` (bge-m3, fp32, PyTorch) was
started to serve a `rank_by_relevance.py` rerun (structural signatures added to
previews → 1378 embedding cache misses). The rerank completed by ~20:00 (12h
later), but the server stayed running indefinitely at **5.2 GB RSS**, consuming
CPU cycles for a total of **7.5h CPU time** over **20.5h wall time**.

The server was only noticed because:
1. `btop`/`nvtop` showed sustained CPU activity
2. Cooler fans audibly ramped up and never quieted down
3. 5.2 GB of RAM was permanently occupied with no active consumers

## Root Cause

The pipeline architecture has **no lifecycle wiring** between the pipeline
scripts and the embedding server:

```
start_embed_server.sh  ──►  rank_by_relevance.py  ──►  generate_phonebook.py  ──►  run_pass3.py  ──►  [end]
         ▲                                                                                           │
         │                                                                                           │
         └────────────────────────── Nothing ever stops the server ───────────────────────────────────┘
```

- `start_embed_server.sh` has a `kill` subcommand, but no script ever calls it.
- `run_pipeline_bg.sh` has lifecycle management for the pipeline itself (PID
  file, lock file, kill) but does not manage the embedding server's lifecycle.
- The `embedding_server.py` has no idle timeout, no request-count limit, and no
  auto-shutdown mechanism.
- Result: the server stays up forever, wasting 5.2 GB of RAM and 7+ hours of
  CPU that could have been freed hours earlier.

## Fix Applied

Added a cleanup step at the end of `run_pipeline_bg.sh`'s nohup block:

```bash
echo "[cleanup] Stopping embedding server..."
/home/nos/labware/LaserCortex/scripts/start_embed_server.sh kill 2>&1 || true
```

This kills the embedding server after the pipeline completes (Pass 2 + Pass 3).

## Deeper Issue: Stateless Process Management

The real problem is that the pipeline relies on **manually started background
processes** with no supervision, no health monitoring, and no lifecycle
coordination. This is fine for development but not sustainable.

### Future Options

1. **systemd oneshot**: Run `rank_by_relevance.py` as a `Type=oneshot` service
   with `ExecStartPost`/`ExecStopPost` managing the embedding server. Handled
   by the init system — no manual `kill` needed.

2. **Embed server inside pipeline script**: Make `run_pipeline_bg.sh` start the
   server, run the pipeline, and stop the server itself (what we did, but via
   cleanup hook rather than structured lifecycle).

3. **Idle timeout in embedding_server.py**: Auto-shutdown after N minutes with
   zero requests. Simple to implement but can cause races if the pipeline is
   slow to start sending requests.

4. **Unix socket activation**: systemd can lazily start the server on first
   connection and stop it after idle timeout. Clean but requires systemd unit.

5. **Supervisor / s6 / runit**: A proper process supervisor that manages the
   server's lifecycle based on dependency tracking. Overkill for a single
   background service.

### Recommendation

For now the cleanup hook is sufficient. When the Open Notebook Librarian
matures (the `#librarian-architecture` project), its agent should own the
embedding server lifecycle — starting it on pipeline invocation, monitoring its
health, and stopping it when idle. This is analogous to how the 35B teacher
model is managed by Docker Compose with `--restart=unless-stopped`: the
container stays up but the orchestration layer owns the lifecycle and can start/
stop it on demand.

A related pattern from the system prompt:
> The 35B runs with `--restart=unless-stopped` — a model stays in VRAM until
> explicitly swapped. Never auto-unload.

The embedding server should adopt a similar pattern: the `manage.sh` swap
command (or future librarian agent) should start/stop it as part of the
pipeline workflow, not leave it running unattended.

## Lessons for Librarian Development

When building the cross-layer librarian agent, ensure it:

1. **Owns service lifecycle** — agent starts the embedding server, runs its
   indexing tasks, and stops the server when finished or idle.
2. **Reports active services** — agent should surface running subprocesses,
   their resource usage, and time since last activity.
3. **Imposes resource budgets** — warn if a subprocess has been running without
   producing results for >4x its expected runtime.
4. **Logs lifecycle events** — every start/stop/restart should be timestamped
   and visible in the notebook.
5. **Graceful degradation** — if the embedding server dies mid-pipeline, fall
   back to a simpler ranking method (e.g., TF-IDF or BM25) rather than failing.

These capabilities would have caught the 12-hour runaway immediately.
