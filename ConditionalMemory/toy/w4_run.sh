#!/usr/bin/env bash
# W4 — table-size vs collision-floor curve (real text). Waits for W3,
# idempotent per point. gram arms only: d384x4, modulus sweep spanning 512x.
set -uo pipefail
cd "$(dirname "$0")"
export PY=${PY:-python3} OMP_NUM_THREADS=8
export HF_HOME=/workspace/hf
while [ ! -f results_w3_gram_closed.json ]; do sleep 60; done
for t in 65536 1048583 33554432; do
  f="results_w4_t${t}.json"
  [ -f "$f" ] && { echo "skip t=$t"; continue; }
  $PY w3_realtext.py --corpus wikitext --ablate gram --steps 1500 \
      --d 384 --layers 4 --gram-target "$t" \
      --eval-lengths 512 2048 --out "$f" || echo "t=$t FAILED"
done
echo W4-ALL-DONE
