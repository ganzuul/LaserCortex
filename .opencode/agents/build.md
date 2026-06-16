---
description: Default build agent with Librarian and Lean LSP integration
mode: primary
permission:
  read: allow
  edit: allow
  glob: allow
  grep: allow
  list: allow
  bash: allow
  task: allow
  external_directory: allow
  todowrite: allow
  webfetch: allow
  websearch: allow
  lsp: allow
  skill: allow
  question: allow
---

You have access to the Open Notebook Librarian via MCP tools. BEFORE reading code files directly, use pipeline_status to check if the index is current, then query_librarian or search_notes to find relevant modules. Use create_or_get_notebook when working with a new repository. Use list_modules to explore the codebase structure by layer or tag.

The Librarian indexes these architectural layers:
- FORMALIZATION (Lean4 proofs, theorems, axioms)
- API_GATEWAY (Python/Django models, endpoints, middleware)
- PRESENTATION (TypeScript/WebGPU shaders, pipelines, buffers)
- DOCUMENTATION (Markdown specs, guides, decisions)

FRESHNESS CHECK (MANDATORY):
Before relying on librarian data for any non-trivial task, verify the index is current:
1. Run pipeline_status first to see module counts and phonebook directories.
2. Run check_freshness on the specific files you are about to work with.
3. If ANY file is stale or unknown, the phonebook is out of date — warn the user and suggest re-running the pipeline (just pipeline-incremental <repo> or just pipeline-full <repo>).
4. If no Deep Analysis notes exist for the module (only heuristic Semantic Index notes), the 35B teacher pass has not completed — treat the index as provisional.
5. Never assume the phonebook reflects the current state of the code. A failed pipeline run (e.g. transformation timeouts) leaves the index with heuristic-only entries that lack cross-refs, invariants, and typed edges.

CROSS-LAYER QUERY SYNTAX:
To find cross-paradigm dependencies, use:
  query_librarian(anchor_tag="#webgpu-buffer", edge_type="CONSTRAINT", related_tags=["#proof-bound"])
  → Returns all edges where a Lean4 theorem constrains a WebGPU buffer property.

  query_librarian(anchor_tag="#mutation", edge_type="MUTATION_TRIGGER", related_tags=["#lean4-theorem"])
  → Returns all Django state mutations that could invalidate a formal invariant.

  query_librarian(anchor_tag="#lean4-theorem", related_tags=["#invariant"])
  → Returns all Lean4 proof modules with formal invariants.

RULE: After receiving librarian results, immediately call file-reading tools on BOTH source and target modules before writing any code. Never modify either side of a dependency edge without checking the invariant_at_boundary field first.

When creating semantic index entries, use ingest_source + create_note so they are visible in the ON web UI.

MODEL ROUTING (Day/Night Rhythm):
- **Daytime (9B student)**: Chat and quick queries use Qwen3.5-9B on `:11434`.
- **Nighttime (35B teacher)**: Transformations (full pipeline) use the 35B teacher on `:8080`.
- ON defaults: `default_chat_model` → 9B, `default_transformation_model` → 35B.
- If transformations fail during daytime, the 35B server is not running — log the question for the nightly batch run.
- The 9B runs with `--no-jinja` (Qwen3.5 is a thinking model; `preserve_thinking` puts output in `reasoning_content` which ON can't read).
- Embedding server (bge-m3) runs independently on `:8082` (CPU, 1024-dim, OpenAI-compatible).

COLD-START ELIMINATION (35B):

Two reliable techniques combine to make restart ~45-90s after first load:

1. **CUDA kernel cache** (`~/.nv/ComputeCache` → `/cuda-cache` in container):
   The ~6-minute init is CUDA kernel compilation + tensor allocation. These
   compiled kernels are cached on disk via `CUDA_CACHE_PATH` (Docker volume).
   First start: 2-3 min (kernels partially cached from failed attempts).
   Cold start (no cache): expected ~6 min. With cache: ~45-150s.
   Cache size: ~69 MB after first successful load.

2. **vmtouch** (kernel page cache):
   21 GB GGUF read into page cache via `vmtouch -t`. On SATA SSD (~550 MB/s):
   ~101s for full 20G load. Achieves 66-84% residency (14-17G of 21G in RAM).
   Once resident, llama.cpp's mmap faults mostly hit RAM, not disk.
   NOTE: `-t` (touch pages) not `-dl` (daemon + mlock). We cannot mlock
   a 21G model in 23G RAM — `vmtouch -dl` requires mlock capability.
   mlock not needed: the page cache itself is sufficient for mmap speed.

3. **`--cache-prompt`** (default `on` in upstream llama-server):
   KV-cache is kept in RAM across requests within a session. Does NOT persist
   across container restarts (no `--slot-save-path` — upstream server requires
   the directory to exist and Docker volume is empty on first run).
   The upstream llama.cpp server does NOT support `--prompt-cache` / 
   `--prompt-cache-all` (those were turboquant build extensions).

Cold-start caveats:
  - CUDA kernel cache persists across restarts; it grows as kernels are compiled.
  - Page cache is best-effort: if memory pressure evicts model pages, restart
    takes longer (disk faults instead of RAM hits).
  - `--slot-save-path` was attempted but rejected by the upstream server because
    Docker volumes start empty and the server won't create the directory.
  - Real cold-start (no cache at all): ~6 min (CUDA compile) + ~1 min (model
    load) = ~7 min. With CUDA cache: ~45-150s. With both: ~45s.
  - Model loading still faults 6-7G from disk even with vmtouch (only 14-17G of
    21G fits in available RAM). With more RAM (≥32 GB) the full model would fit
    in page cache and restarts would be near-instant.

MODEL MANAGEMENT (Docker-based, with parallel pre-flight):

Principles:
  - Models run as Docker containers (ghcr.io/ggml-org/llama.cpp:server-cuda)
    with `--restart=unless-stopped`, managed via `docker compose`.
  - Docker bind-mounts the model directory read-only — NO file copies.
  - A model stays in VRAM until explicitly swapped. Never auto-unload.
  - vmtouch is used ONLY for the 35B (21 GB) and ONLY just before launch,
    not at boot. The 9B (5.8 GB) loads fast enough without it.
  - Parallel pre-flight: vmtouch (I/O, ~100s for 20G) and file relevance ranking
    (CPU, ~5 min first run, <1s cached) run concurrently.
    Total wall time ≈ max(100s, 5min) = ~5 min first run, ~100s subsequently.
  - If estimated pipeline time > 3h, warns (does not block).

Tooling (all in /home/nos/labware/llocollama/):
  - `docker-compose.yml` — defines model-9b (:11434) and model-35b (:8080)
    using upstream ghcr.io/ggml-org/llama.cpp:server-cuda image.
    CUDA kernel cache volume, --cache-prompt, and model dir bind-mount
    configured. Each flag and value is a separate YAML list entry.
    Uses `--jinja` for the 35B (with `preserve_thinking`) and `--no-jinja`
    for the 9B (no reasoning extraction needed).
  - `manage.sh` — lifecycle wrapper (see below).

Pipeline scripts (in /home/nos/labware/open-notebook/scripts/pipeline/):
  - `rank_by_relevance.py` — embeds file previews via bge-m3, ranks by cosine
    similarity against a research query, outputs JSON with top-K cutoff.
    Uses parallel workers (6) and batch embedding (50 items/req).
    **Content-addressed embedding cache** at `~/.cache/lasercortex/embedding_cache.json`
    — embeddings are keyed by SHA256 of the preview text. Only new/changed files
    are embedded on subsequent runs (typically < 1 min after first run).
    Typical first run: ~3-5 min for 800 files (excluding lean4-skills/ etc.).
    Output at `/tmp/lasercortex_ranking.json` — read by pipeline scripts.
  - `generate_phonebook.py` — phonebook generation (heuristic + 35B).
    **Transformation cache** in `.phonebook_cache.json` — tracks SHA256 of each
    file and whether the 35B Deep Analysis has completed. On subsequent runs,
    only files whose content actually changed are re-transformed.
    Uses `--ranking-file /tmp/lasercortex_ranking.json` to process only top-K
    files by relevance (capped at ~3h budget ≈ 144 files with 35B at 75s each).
  - `bootstrap_on.py` — ON bootstrap / initial ingestion.

CACHING STRATEGY:

The system avoids re-computation through two content-addressed caches:

1. **Embedding cache** (`~/.cache/lasercortex/embedding_cache.json`):
   - Key: SHA256 of the preview text (path + first 500 chars of content)
   - Value: 1024-dim bge-m3 embedding vector
   - Used by: `rank_by_relevance.py`
   - On first run: ~5 min to embed all files
   - On subsequent runs: only files whose content changed get re-embedded
   - When no files changed: ranking completes in < 1s (all cache hits)

2. **Transformation cache** (`.phonebook_cache.json` in the output dir):
   - Key: relative file path
   - Value: heuristic analysis + `transform_sha` (SHA256 of content at last 35B pass)
   - Used by: `generate_phonebook.py`
   - In `--full` mode: only files whose content changed AND whose relevance
     ranking puts them in the top-K get the 35B pass
   - Unchanged files get cached heuristic analysis + cached Deep Analysis note
   - Typical nightly: < 50 files changed → ~1h of 35B work (well under 3h cap)

3. **Cold-start elimination** (Docker volumes):
   - CUDA kernel cache → kernel compile once per GPU driver update
   - vmtouch → model weights in page cache → mmap instant
   - `--prompt-cache` → KV-cache persisted across restarts
   - Combined effect: first session ~12 min, subsequent sessions ~10s

The nightly batch caps total work at 3h. If the ranking says the top-K files
would exceed 3h, it warns but proceeds (the pipeline itself skips any files
that are already cached, so actual work is always ≤ 3h of new transforms).

manage.sh commands:
  manage.sh status                 # model state, page cache, VRAM, last ranking summary
  manage.sh swap 9b                # stop 35B → start 9B (no vmtouch, no ranking)
  manage.sh swap 35b [--query ".."] # parallel vmtouch+rank → estimate → start 35B
  manage.sh rank [--query ".."]    # standalone relevance ranking (no model swap)
  manage.sh preload                # explicit vmtouch 35B only
  manage.sh bake-cache 9b|35b      # instructions for KV-cache pre-baking
  manage.sh logs [svc]             # tail logs

Swap 35b workflow:
   1. Pre-flight checks (Docker, nvidia, model file, port, VRAM).
   2. ⚡ Parallel launch:
        - Foreground: `vmtouch -t` (21 GB, ~100s on SATA SSD)
        - Background: `rank_by_relevance.py` (~5 min first run, <1s cached)

      On first run: full embedding of ~800 files (content-addressed cache built)
      On subsequent runs: only new/changed files are embedded; ranking reuses
      cached embeddings. The `--query` SHA256 is also cached, so repeating the
      same query is instant.

   3. vmtouch completes first → ranking continues in background.
      manage.sh waits for ranking to finish.
   4. Reads `/tmp/lasercortex_ranking.json` → computes top-K from time budget.
      Prints pipeline estimate. Warns if > 3h.
   5. Stops model-9b (if running), starts model-35b with `docker compose up -d`.
      CUDA kernel cache + page cache → server ready in ~45-150s (CUDA cached)
      or ~6 min (first-ever start, no CUDA cache).
   6. Ranking file persists for the pipeline (nightly_batch.sh reads it).

  Nightly batch then runs `generate_phonebook.py --mode full --ranking-file ...`
  which reads the ranking, only transforms top-K files, and skips files whose
  `transform_sha` already matches (content unchanged since last 35B pass).
  Typical nightly work: < 50 changed files × 75s = ~1h of 35B transforms.

Nightly batch (`nightly_batch.sh`) delegates to `manage.sh swap 35b` for
model swapping. Cleanup trap only removes the lockfile — never kills model.

35B THINKING BEHAVIOR:
  The Qwen3.6-35B-A3B is a reasoning model. It generates internal "thinking"
  traces before producing its final answer:
  - Thinking is returned in the `reasoning_content` field of the response
  - The final answer is in the standard `content` field
  - Thinking tokens are consumed from the generation budget — "Say hello" may
    take 200+ tokens of reasoning before producing "Hello!" (1 token)
  - With `--chat-template-kwargs '{"preserve_thinking":true}'` the reasoning
    trace is preserved and returned separately (not stripped from content)
  - The 9B (Qwen3.5) also has this behavior but uses `--no-jinja` to keep
    things simple for daytime chat
  - Typical speed: prompt ~12 t/s, generation ~7 t/s (8 GB VRAM, most layers
    running on CPU via GPU offloading)

Note: The 35B uses Q4_K_M (21 GB) not Q5_K_M (25 GB) for a better fit in
24 GB RAM. GPU: RTX 2070 SUPER (8 GB VRAM) — only one model at a time.
