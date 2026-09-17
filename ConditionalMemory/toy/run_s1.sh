#!/usr/bin/env bash
# S1 full validation matrix (EXPERIMENTS.md S1): 3 arms x 3 seeds.
# ~10-20 min on an RTX 3090. Override: STEPS=.. EVAL=".." BS=.. ./run_s1.sh
set -euo pipefail
PY=${PY:-python3}
STEPS=${STEPS:-1200}
BS=${BS:-48}
EVAL=${EVAL:-"96 512 1024 2048"}
for seed in 0 1 2; do
  for arm in kv gram_closed gram; do
    $PY train.py --steps "$STEPS" --bs "$BS" --seed "$seed" --ablations "$arm" \
      --Lmin 48 --Lmax 128 --eval-lengths $EVAL --eval-bs 16 \
      --out "results_s1_${arm}_seed${seed}.json"
  done
done
$PY - <<'PYEOF'
import glob, json
print("\n=== S1 matrix: eval accuracy by stream length ===")
for f in sorted(glob.glob("results_s1_*_seed*.json")):
    (arm, r), = json.load(open(f))["results"].items()
    ev = {int(k): round(v, 3) for k, v in r["eval_acc_by_L"].items()}
    print(f"{f.split('_seed')[-1]:>10} {arm:>12}  {ev}")
PYEOF
