#!/usr/bin/env python3
"""Generate .dat files for the presentation hero figures.

Produces:
  plots/friction_barrier.dat   — Γ_k and T_k for k = 0..7 (phase diagram)
  plots/lightcone_census.dat   — spacelike/lightlike/timelike counts per cd band

Data is recomputed from the authoritative mirrors (not hand-transcribed) so
the figures always agree with the Lean statements in LogicalTemperature.lean
and the sweep in metric_sweep.py.
"""
from __future__ import annotations

import os
import sys
from collections import Counter

_here = os.path.dirname(os.path.abspath(__file__))
for p in (os.path.join(_here, ".."), _here, os.path.join(_here, "..", "infra")):
    if p not in sys.path:
        sys.path.insert(0, p)

from logical_temperature import friction_density, barrier_temperature, K_MAX  # noqa: E402
from metric_sweep import _right_comb, _succ_gen, dijkstra_to_closure  # noqa: E402
from logical_temperature import _all_trees  # noqa: E402

PLOTS = os.path.join(_here, "..", "plots")
os.makedirs(PLOTS, exist_ok=True)


def write_friction_barrier() -> None:
    rows = []
    for k in range(K_MAX + 1):
        rows.append(f"{k}\t{friction_density(k)}\t{barrier_temperature(k):.1f}")
    path = os.path.join(PLOTS, "friction_barrier.dat")
    with open(path, "w") as f:
        f.write("# k\tGamma_k\tT_barrier_k (K)\n")
        f.write("\n".join(rows) + "\n")
    print(f"wrote {path}")


def write_lightcone_census(n: int = 6, cds=(0, 1, 2, 3, 4)) -> None:
    trees = list(_all_trees(n))
    idx = set(trees)
    succs = {t: [u for u in _succ_gen(t) if u in idx] for t in trees}
    dist = dijkstra_to_closure(trees, succs, 1.0, _right_comb(n))
    hist = Counter(dist[t] for t in trees)
    total = len(trees)

    rows = []
    for cd in cds:
        g = friction_density(cd)
        spacelike = sum(c for d, c in hist.items() if d < g)
        lightlike = hist.get(g, 0)
        timelike = sum(c for d, c in hist.items() if d > g)
        rows.append(f"{cd}\t{g}\t{spacelike}\t{lightlike}\t{timelike}")

    path = os.path.join(PLOTS, "lightcone_census.dat")
    with open(path, "w") as f:
        f.write(f"# cd\tgamma\tspacelike\tlightlike\ttimelike  (n={n}, total={total})\n")
        f.write("\n".join(rows) + "\n")
    print(f"wrote {path}")


if __name__ == "__main__":
    write_friction_barrier()
    write_lightcone_census()
