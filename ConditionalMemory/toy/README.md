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
