# Pipeline Performance: Bounds and Bottlenecks

Measured on: AMD Ryzen 9 3900X (12C/24T) · RTX 2070 SUPER (8 GB) · 23 GB RAM · SATA SSD (~550 MB/s)

## Progression

### Baseline (no improvements)
- 11,478 files × 120 s/35B-pass = **~16 days** — infeasible

### Step 1: Directory exclusions
- Excluded: .git, .lake/, _archive/, lean4-skills/, direct_infra_experiment/, democh_*
- ~780 files remain (~7% of original)
- **~26 hours** — still too long for nightly

### Step 2: Relevance ranking (intelligent selection)
- Embed previews via bge-m3 (CPU, 1024-dim), rank by cosine similarity
- Budget cap: 3 hours = 144 files at 75 s/file for 35B pass
- All remaining files get a fast heuristic pass
- **~3 hours** — fits in a nightly window

### Step 3: Parallel pre-flight
- vmtouch 35B into page cache (I/O, ~100 s) + ranking (CPU, ~5 min first run, <1 s cached)
- Run concurrently → wall time ≈ max(100 s, 5 min)
- Previously sequential: 5+ min delay before model starts

### Step 4: Content-addressed caching
- Embedding cache (SHA256-keyed, ~/.cache/lasercortex/embedding_cache.json)
- Transformation cache (transform_sha in .phonebook_cache.json)
- Query SHA256 also cached
- First run expensive; subsequent runs process only changed files

### Step 5: CUDA kernel cache
- ~/.nv/ComputeCache (~69 MB) in Docker volume, avoids ~5 min recompile on restart

## Measured Bounds

| Operation | Cold | Cached | Bottleneck |
|---|---|---|---|
| Directory scan (780 files) | <0.1 s | <0.1 s | I/O |
| Build previews | 0.3 s | 0.3 s | I/O |
| Embedding (780 files) | ~5 min | <1 s | CPU (bge-m3) |
| Cosine similarity | ~0.1 s | ~0.1 s | CPU |
| vmtouch 35B (20 GB) | ~100 s | N/A (ephemeral) | SATA SSD |
| 35B model load (no cache) | ~7 min | — | CUDA compile |
| 35B (+CUDA cache) | — | 45-150 s | mmap faults, tensor setup |
| 35B (+CUDA + vmtouch) | — | 45-90 s | remaining page faults |
| 35B pre-flight (parallel) | ~5 min | ~100 s | max(ranking, vmtouch) |
| 35B generation | — | ~7 t/s | GPU offloading |
| 35B prompt | — | ~12 t/s | GPU offloading |

## What This Unlocks

**Broken linear scaling with file count:**

Old: `N_files × 120 s` → 16 days

New: `preflight(5 min) + min(N_changed, 144) × 75 s`
- Normal night (~50 changed files): ~1 h
- Heavy night (144 files): ~3 h (budget cap)
- Capped at 3 h regardless of repo size

With warm caches on a typical night:
- Ranking: <1 s (all cache hits)
- Heuristic pass: seconds (cached)
- 35B pass: only changed files, at most 144
- **Total: ~1 h for the pipeline**

The 35B server stays loaded after the nightly run. Daytime swaps to 9B (no pre-flight) take
~10-30 s. Next nightly swap back to 35B runs parallel pre-flight while the researcher reviews
results.

## Remaining Bottlenecks

1. **SATA SSD (550 MB/s)**: vmtouch takes ~100 s. NVMe would cut to ~10-20 s.
2. **RAM (23 GB)**: 21 GB model → only 14-17G fits in page cache → 4-7G faults from disk each load.
3. **VRAM (8 GB)**: Most 35B layers run on CPU. 24 GB card would run 35B fully on GPU at ~30-50 t/s.
4. **GPU generation speed (~7 t/s)**: Dominant term once caches are warm. ~75 s per file = bottleneck.
