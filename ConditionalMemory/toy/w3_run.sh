#!/usr/bin/env bash
set -euo pipefail
PY=${PY:-python3}
for arm in gram kv gram_closed; do
  $PY w3_realtext.py --corpus wikitext --ablate $arm --steps 2000 --out results_w3_${arm}.json
done
echo W3-ALL-DONE
