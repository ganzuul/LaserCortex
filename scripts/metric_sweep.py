#!/usr/bin/env python3
"""Lab Note 051 — Right-Metric Decision Sweep.

Falsification-first testing of the gamma-weighted Tamari graph metric:

    d_gamma(s, t) := min total grind along contracts_one flip paths

Criteria tested (see lab_notes/051):
  C2 POTENTIALITY : weightedCost cd t == d_gamma(t, rightComb(t.size))
                    i.e. cost IS geodesic distance to the closure.
  C0 SANITY       : triangle inequality on the undirected closure of the
                    flip graph (shortest-path metrics satisfy it by
                    construction; we verify the computation anyway).
  C4 DISCRIMINATION: trivial rivals (discrete metric, size metric) fail C2.

Exit code 0 iff all criteria pass.
"""
from __future__ import annotations

import heapq
import os
import sys
from collections import Counter

_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for p in (os.path.join(_REPO, "scripts"),
          os.path.join(_REPO, "infra"),
          _REPO):
    if p not in sys.path:
        sys.path.insert(0, p)

from _cortex._eml_tree import EMLTree  # noqa: E402
from logical_temperature import (  # noqa: E402
    _all_trees, _dcstep, friction_density, LOGIC_CD,
)


def _right_comb(n: int) -> EMLTree:
    L = EMLTree.leaf()
    t = L
    for _ in range(n):
        t = EMLTree.node(L, t)
    return t


def dijkstra_to_closure(all_trees, start_edges, gamma, target):
    """Multi-source-free Dijkstra on the DAG toward `target`.

    all_trees: list of trees (one size)
    start_edges: dict tree -> list of successor trees (downward flips)
    Returns dict tree -> min cost to reach target.
    """
    # reverse adjacency
    rev = {t: [] for t in all_trees}
    for s, succs in start_edges.items():
        for u in succs:
            rev[u].append(s)
    dist = {target: 0}
    tick = 0
    pq = [(0, 0, target)]
    while pq:
        d, _, t = heapq.heappop(pq)
        if d > dist.get(t, float("inf")):
            continue
        for pred in rev[t]:
            nd = d + gamma
            if nd < dist.get(pred, float("inf")):
                dist[pred] = nd
                tick += 1
                heapq.heappush(pq, (nd, tick, pred))
    return dist


def undirected_all_pairs(trees, edges):
    """BFS all-pairs distances on the undirected flip graph."""
    adj = {t: set() for t in trees}
    for s, t in edges:
        adj[s].add(t)
        adj[t].add(s)
    dist = {}
    for src in trees:
        dist[src] = {src: 0}
        q = [src]
        while q:
            nxt = []
            for cur in q:
                for nb in adj[cur]:
                    if nb not in dist[src]:
                        dist[src][nb] = dist[src][cur] + 1
                        nxt.append(nb)
            q = nxt
    return dist


def run_sweep(max_size: int = 6) -> bool:
    ok = True
    print()
    print("═" * 78)
    print("RIGHT-METRIC DECISION SWEEP — γ-weighted Tamari graph metric")
    print("(lab note 051, criteria C0/C2/C4)")
    print("═" * 78)

    for n in range(1, max_size + 1):
        trees = list(_all_trees(n))
        index = set(trees)
        target = _right_comb(n)
        assert target in index

        # downward flip edges (uniform cost 1 flip; γ scales all equally)
        succs = {}
        edge_list = []
        for t in trees:
            ss = [
                u for u in (
                    v for v in _succ_gen(t)) if u in index]
            succs[t] = ss
            edge_list.extend((t, u) for u in ss)

        gamma = friction_density(min(k for k in LOGIC_CD.values()) + 2)
        dist_cost = dijkstra_to_closure(trees, succs, 1.0, target)

        # C2: cost functional == geodesic distance (in flips)
        c2_fail = [
            t for t in trees
            if dist_cost.get(t) != _dcstep(t)]
        status = "OK" if not c2_fail else f"FAILED ({len(c2_fail)} trees)"
        print(f"  size {n}: {len(trees):>4} trees, "
              f"dcStep range {_dcstep(target)}.."
              f"{max(_dcstep(t) for t in trees)}, "
              f"C2 potentiality: {status}")
        if c2_fail:
            ok = False
            for t in c2_fail[:5]:
                print(f"      dcStep={_dcstep(t)} "
                      f"geodesic={dist_cost.get(t)} tree={t}")

        # C0 sanity: triangle inequality on undirected all-pairs (n ≤ 5)
        if n <= 5:
            ap = undirected_all_pairs(trees, edge_list)
            tri_ok = True
            for s in trees:
                for u in trees:
                    du = ap[s].get(u)
                    if du is None:
                        continue  # disconnected components impossible here
                    for v in trees:
                        dv = ap[u].get(v)
                        ds = ap[s].get(v)
                        if dv is None or ds is None:
                            continue
                        if ds > du + dv:
                            tri_ok = False
            print(f"          C0 triangle inequality (undirected, "
                  f"{len(trees)}³ checks): "
                  f"{'OK' if tri_ok else 'FAILED'}")
            ok &= tri_ok

    # C4: discrimination against trivial rival metrics
    print("  ── C4 discrimination ──")
    n = 4
    trees = [t for t in _all_trees(n)]
    target = _right_comb(n)
    succs = {
        t: [u for u in _succ_gen(t) if u in set(trees)] for t in trees}
    dist = dijkstra_to_closure(trees, succs, 1.0, target)
    worst = max(dist.values())

    # discrete metric: d(s,t) = 1 if s≠t — predicts cost ∈ {0,1}: absurd
    disc_ok = worst > 1
    # size metric: all trees share size ⇒ distance ≡ 0: absurd
    size_ok = worst > 0
    print(f"    discrete metric rejected (geodesic range reaches "
          f"{worst} > 1): {'OK' if disc_ok else 'FAILED'}")
    print(f"    size-metric rejected (nonzero distances exist): "
          f"{'OK' if size_ok else 'FAILED'}")
    ok &= disc_ok and size_ok

    # C4': d_γ separates distinct trees of the same size?
    sep = len({_dcstep(t) for t in trees}) > 1
    print(f"    dcStep separates same-size trees (n={n}): "
          f"{'OK' if sep else 'DEGENERATE'}")
    ok &= sep

    print("═" * 78)
    print(f"VERDICT: {'CANDIDATE SURVIVES' if ok else 'CANDIDATE DAMNED'}")
    return ok


def _succ_gen(t: EMLTree):
    """Yield all single-contraction successors (thin wrapper)."""
    from _cortex._eml_tree import contracts_one_successors
    yield from contracts_one_successors(t)


if __name__ == "__main__":
    sys.exit(0 if run_sweep() else 1)
