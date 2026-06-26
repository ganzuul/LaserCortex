# Resource Safety

This system has limited resources (24 GB RAM, 8 GB VRAM) and no OOM killer
configured for swap-thrashing. A runaway process can make the entire system
unresponsive for minutes without crashing — a denial-of-service worse than
failure.

## Principles

### P1: Ask before launching

Before launching any process or command that could:
- Consume **≥ 1 GB** of additional system RAM
- Use significant CPU for more than a few seconds
- Run for more than **30 seconds** total
- Start a long-running server or background process

**You MUST stop and use the `question` tool to ask for permission.**

State: what you will do, expected resource impact, and estimated runtime.
Do not proceed until explicitly approved.

This overrides any default instruction to "continue if you have next steps"
— when resource impact is non-trivial, stopping to ask comes first.

### P2: Contain before you run

Any process that could consume unbounded memory MUST be launched with
resource caps that will kill it before the system becomes unresponsive.

Minimum containment for a server or long-running process:
1. **Memory cap** — `ulimit -v` or cgroup `MemoryMax` so the OS kills
   the process before swap thrashing begins
2. **Watchdog** — a background monitor that kills the process if RSS
   exceeds a threshold (belt and suspenders with the memory cap)
3. **Swap check** — verify swap usage is < 1 GB before starting; high
   swap means the system hasn't recovered from a prior incident

### P3: Ramp, don't flood

When testing a resource-intensive service, start with minimal load and
increase incrementally. Verify memory returns to baseline between steps.
Never start at full concurrency.

### P4: Isolate the blast radius

Start servers in a separate session/terminal so that interrupting the
test client does not propagate signals to the server. Uncontained
servers left running after a test abort are a hazard.

### P5: Minimise context churn (token budget)

Remote API calls have a finite token budget. Reading entire files burns
budget on ingestion that should be spent on reasoning. The rule:

1. **10-line limit per Read call.** If you need more than 10 lines from a
   file, you are doing a search task, not a read task. Use `grep -n` to
   find the line number, then Read with offset+limit=10 to spot-check.
2. **Grep first, read second.** Always locate the relevant section with
   `grep -n` or `rg` before opening a file. Never open a file blind.
3. **No bulk ingestion without permission.** Reading >50 lines total from
   a single file in one session requires explicit user approval. State
   why the full content is needed.
4. **Prefer CLI summaries.** Use `wc -l`, `grep -c`, `head -5`,
   `tail -5`, and structured outlines (`grep -n "^#"`) to understand a
   file's shape before reading any content.
5. **Cache file shapes.** Once you know a file's heading structure or
   line count, don't re-discover it. Reuse that knowledge.

This applies to all files: source code, OWL ontologies, logs, JSON,
documentation. The goal is to spend tokens on reasoning and writing code,
not on ingesting text that could have been summarised by a tool.

## Incident Registry

Specific incidents where a process caused system DoS. These remain
registered until the root cause is fixed AND verified under the
containment protocol above.

### INC-1: ONNX int8 embed server unbounded memory under concurrency

- **File**: `embedding_server.py` (ONNX int8 variant, `open-notebook/scripts/pipeline/`)
- **Trigger**: ≥2 concurrent requests with batch sizes ≥10 texts of ≥1000 chars
- **Symptom**: RSS → 22+ GB in seconds, system swap-thrashes unresponsive 5+ min
- **Root cause**: ONNX Runtime `enable_mem_pattern=True` pre-allocates ~5+ GB
  per session; glibc per-thread arenas multiply this under concurrency
- **Status**: 🟡 FIX APPLIED, UNTESTED
- **Applied fix** (2026-06-17):
  - `session_opts.enable_mem_pattern = False` — per-inference allocation
  - `session_opts.enable_cpu_mem_arena = False` — no arena slab allocator
  - Tokenizer moved inside ONNX lock — glibc arenas don't multiply
  - `max_length` reduced from 8192 to 512 — 16× fewer intermediate tokens
  - ThreadPoolExecutor reduced to `max_workers=1` — single allocation stream
  - `start_embed_server.sh` now includes: swap check, `ulimit -v 4GB`,
    RSS watchdog at 3 GB threshold

**Testing required**: Apply containment protocol (P2–P4) before first test.
Ramp: 1 worker → 3 → 6. If stable, demote to resolved. If still cascading,
revert to sentence-transformers PyTorch (proven stable at 5.2 GB RSS).
