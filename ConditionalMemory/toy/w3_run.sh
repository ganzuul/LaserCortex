#!/usr/bin/env bash
# W3 runner v2 — idempotent across pod evictions: each arm skips if its
# results json exists. Cache on /workspace survives pod restarts.
set -uo pipefail
cd "$(dirname "$0")"
export PY=${PY:-python3} OMP_NUM_THREADS=8
export HF_HOME=/workspace/hf
for arm in gram kv gram_closed; do
  f="results_w3_${arm}.json"
  if [ -f "$f" ]; then echo "skip $arm (have $f)"; continue; fi
  echo "=== W3 arm $arm $(date -u +%H:%M:%S) ==="
  $PY w3_realtext.py --corpus wikitext --ablate "$arm" --steps 2000 \
      --out "$f" || echo "arm $arm FAILED (retry on next supervision)"
done
[ -f results_w3_gram_closed.json ] && echo W3-ALL-DONE
