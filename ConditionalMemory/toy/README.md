# toy/ — S1 mechanism validation (EXPERIMENTS.md stage S1)

Tiny end-to-end demo of the PLE-I/O write channel: frozen-style gram tables
+ delta bag + centered-softplus commit gate on a 2-layer transformer trunk.
Fold/window/prime semantics are **imported from `../ple_io.py`** (the Lean-
twin executable spec) and self-checked at import — this toy cannot silently
drift from the certificates. Plain PyTorch ⇒ runs on CUDA (rented) and ROCm
(LUMI-G) unchanged; no custom kernels.

## Run

```bash
PY=/run/media/nos/games/inference_engines/sglang/.venv/bin/python   # any torch>=2.1
$PY train.py --steps 800 --bs 48 --Lmin 48 --Lmax 96 \
             --eval-lengths 96 512 2048 --eval-bs 24
```
Arms (`--ablations`): `gram` (PLE-I/O channel), `kv` (attention only),
`gram_closed` (dead-channel capacity control). Task: gram-membership — a
needle span is inserted into a random stream (train streams L∈[48,96]); the
model answers whether the final query span was in the stream. The channel
reads causal prefix counts of the span's XOR-fold gram keys (certified fold);
attention must search instead.

## S1 FULL MATRIX — rental RTX 3090, 2026-09-17 (`rental_3090/`, this run)

3 seeds × 3 arms × 1500 steps, train L∈[48,128], eval 8×bs16 per length:

| arm | L=96 | 512 | 1024 | 2048 | 4096 |
|---|---|---|---|---|---|
| `gram` (all 3 seeds) | **1.00** | **1.00** | **1.00** | **1.00** | **1.00** |
| `kv` (seeds 0–2) | .44–.56 | .45–.56 | .46–.54 | .42–.57 | .48–.53 |
| `gram_closed` | ≡ chance, commit pinned 0 (capacity control) | | | | |

Commit rate 0 → 0.031–0.034 by ~700 steps, then **loss → 0.000** — the gate
opens itself on cue. Remote regression gate: `ple_io.py` 12/12 groups on the
rental before any training (spec semantics bit-identical across deploys).

The rental exposed **two real training-harness bugs** (both fixed + root-
caused here, worth carrying into S2 code review):
1. `train.py` never called `model.eval()` → trunk dropout was ACTIVE during
   eval, randomly collapsing weak-margin lengths (gram seed0 @1024 ≈ chance).
2. **Untrained-position embedding noise**: default `N(0,1)` embeddings at
   positions beyond the train horizon (~140) can out-scale the small channel
   contribution (0.03·log1p2) at *specific* lengths — seed-dependent, and
   invisible at other lengths (why only L=1024 failed). Fix: **zero-init
   embeddings** — unseen positions/tokens stay 0 by construction, no eval-
   time masking. After both fixes the matrix is uniformly 1.00. (Note: `torch`'s
   `%` is floormod → fold keys never go negative → `prefix_counts` verified
   against brute force at every eval length on the rental: mismatches 0.)

## W1 COST MODEL — rental 3090 (`rental_3090/ple_bench_3090.json`)

Production-form PLE-I/O ops, fp16, 8 heads × 256 dim, B=64×L=8192 = 524k tok/step:

| op | measured | scales with |
|---|---|---|
| HBM gather / token | **0.035–0.036 µs** | **flat across 0.25GB→16GB tables (64×)** |
| write-path sort (prefix counts) | 0.4–0.5 ns/key → 524k-key step ≈ 0.2 ms | linear, tiny |
| **pinned HOST-RAM table**, serial | **0.26 µs/token (7× HBM)** | **still L-invariant** |
| fp32 attention / token / layer | 1 µs @4k → 2 µs @16k | **O(L) per token; OOM @32k** |

The read path is bandwidth-bound and size/length-invariant; a
host-resident table (the LUMI-G config) pays only ~7× HBM cost per token
while attention's per-token cost grows with context. That single table is
the quantitative core of the grant's capacity argument.

## S1-LARGE (W2) — rental 3090, 2026-09-17 (`rental_3090/results_large_*`)

~100M-param trunk (d=768 × 8 layers, 12 attn heads), vocab 65536,
8 gram heads × orders{2,3} with **V4.1-scale primes (~8.4M rows/table)**,
train L∈[128,768], eval 1024–8192 (bs capped by 24GB fp32 attention; n=8
at 8192), 2500 steps, arms: gram ×3 seeds + kv + gram_closed.

| arm | L=1024 | 2048 | 4096 | 8192 |
|---|---|---|---|---|
| gram (seeds 0,1,2) | **1.00** | **1.00** | **1.00** | **1.00** |
| kv | 0.49 | 0.45 | 0.56 | 0.50 |
| gram_closed | ≡ chance (control) | | | |

H1 now holds at ~100M scale, 16× vocab, 128× key-table, 10.7× length
extrapolation — 11/11 gram rows perfect; loss 1.6→0.000 by step ~500.
Total rental cost for W1+W2: **~2 h ≈ $0.40**.

## Smoke result (RTX 2070 SUPER, 800 steps, 22 s/arm) — 2026-09-17

| arm | acc @ L=96 | @512 | @2048 | commit rate |
|---|---|---|---|---|
| `gram` | **1.00** | **1.00** | **1.00** | 0 → 0.006 (opens itself) |
| `kv` | 0.44 | 0.49 | 0.51 | — |
| `gram_closed` | (capacity control: == `kv`) | | | pinned 0 |

H1 (length-invariance at constant cost) holds; design note: the gate is
centered-softplus **without clamp** — clamp_min(0) at init 0 has zero
gradient and keeps the channel permanently dead (caught in this smoke).

Files: `model.py` (GramChannel = delta-writer + gate; PleLM; make_batch task),
`train.py` (train/eval/ablations → `results_stage1.json`), `requirements.txt`.
