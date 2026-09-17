#!/usr/bin/env bash
# S1-LARGE (W2): ~100M-param trunk, 64k vocab, V4.1-scale prime tables,
# train L in [128,768], EVAL to 16384 (12 heads fp32 attention is the
# binding constraint on 24GB — the channel itself is linear in L).
set -euo pipefail
PY=${PY:-python3}
STEPS=${STEPS:-2500}
BS=${BS:-32}
EVAL=${EVAL:-"1024 2048 4096 8192"}
COMMON="--vocab 65536 --d 768 --layers 8 --theads 12 --gram-heads 8 \
  --gram-target 8388617 --Lmin 128 --Lmax 768 --max_len 8400 \
  --eval-lengths $EVAL --eval-bs 16 --bs $BS --steps $STEPS"
for seed in 0 1 2; do
  $PY train.py $COMMON --seed "$seed" --ablations gram \
    --out "results_large_gram_seed${seed}.json"
done
for arm in kv gram_closed; do
  $PY train.py $COMMON --seed 0 --ablations "$arm" \
    --out "results_large_${arm}_seed0.json"
done
$PY - <<'PYEOF'
import glob, json
print("\n=== S1-LARGE (W2): eval accuracy by stream length ===")
for f in sorted(glob.glob("results_large_*_seed*.json")):
    (arm, r), = json.load(open(f))["results"].items()
    ev = {int(k): round(v, 3) for k, v in r["eval_acc_by_L"].items()}
    print(f"{f:>36} {ev}")
PYEOF
