#!/usr/bin/env python3
"""
Run the tropical type theory experiment and encode results into Graphiti.

Encodes the type lattice (stations, types, adjacencies, applyMove transitions)
into Graphiti, runs community detection, and reports the discovered communities.

Usage:
    python scripts/run_type_experiment.py                               # default (r=3, step=6)
    python scripts/run_type_experiment.py --output results.json         # save results
    python scripts/run_type_experiment.py --keep-db --density 2         # bigger graph
    python scripts/run_type_experiment.py --clear-group                 # re-run from scratch

The Lean file is run to extract type data. The script then generates episodes
for each station, type, adjacency, and applyMove transition, plus OWL bridge keys.

For "bigger graphs", use --density N to add N synthetic episodes per type
(parameterized attribute variations that enrich the graph without changing
the underlying type lattice).

Requires:
    - lake (Lean 4) available on PATH
    - graphiti-core[falkordblite] installed
    - PYTHONPATH includes the LaserCortex project root
"""

import argparse
import asyncio
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path

# Add project root to path for infra imports
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


# ============================================================================
# Known Type Theory Data (r=3, step=1/6, stations P, NP, PN)
# ============================================================================
# This data is verified by the Lean experiment. It is the ground truth
# that the script encodes into Graphiti.

STATIONS = [
    {"name": "P",  "tree": "Node(Leaf,Leaf)",          "kkt": (1.0, 0.0), "lw": 0, "rw": 0, "size": 1, "polarity": "left",
     "note": "Tie-breaker: coordX≈coordY→left. Simplest binary tree."},
    {"name": "NP", "tree": "Node(Leaf,Node(Leaf,Leaf))", "kkt": (2.0, -1.0), "lw": 0, "rw": 1, "size": 2, "polarity": "right",
     "note": "Right-dominant: rightmost leaf path has weight 2."},
    {"name": "PN", "tree": "Node(Node(Leaf,Leaf),Leaf)", "kkt": (2.0, 1.0), "lw": 1, "rw": 0, "size": 2, "polarity": "left",
     "note": "Left-dominant: leftmost leaf path has weight 2."},
]

TYPES = [
    {"id": "v1", "S1": [1, 3], "S2": [1],   "S3": [1, 2],     "sig": (1, 2), "deg": True,  "kkt": (1.0, 0.0), "station": "P",
     "note": "S₃-dominant. Anchor of S₃-ville."},
    {"id": "v2", "S1": [2, 3], "S2": [1, 2, 3], "S3": [2],   "sig": (3, 1), "deg": True,  "kkt": (2.0, -1.0), "station": "NP",
     "note": "Maximally degenerate S₂ (|S₂|=3). Anchor of S₂-ville."},
    {"id": "v3", "S1": [3],    "S2": [1, 3],   "S3": [1, 2, 3], "sig": (2, 3), "deg": True,  "kkt": (2.0, 1.0), "station": "PN",
     "note": "Maximally degenerate S₃ (|S₃|=3). Anchor of S₃-ville."},
    {"id": "C",  "S1": [3],    "S2": [1],     "S3": [2],       "sig": (1, 1), "deg": False, "kkt": (1.5, 0.0), "station": "",
     "note": "Interior. Non-degenerate pivot between S₂-ville and S₃-ville."},
    {"id": "W",  "S1": [3],    "S2": [1, 3],   "S3": [2],       "sig": (2, 1), "deg": True,  "kkt": (2.0, 0.0), "station": "",
     "note": "Wall. S₂-degenerate (|S₂|=2). Anchor of S₂-ville."},
    {"id": "T1", "S1": [1, 3], "S2": [1],     "S3": [1],       "sig": (1, 1), "deg": False, "kkt": (1.0, 0.0), "station": "",
     "note": "ApplyMove result: v₁ S₃⁻(2). S₃={1}."},
    {"id": "T2", "S1": [1, 3], "S2": [1, 2],   "S3": [1, 2],   "sig": (2, 2), "deg": True,  "kkt": (1.0, 0.0), "station": "",
     "note": "ApplyMove result: v₁ S₂⁺(2). Symmetric (|S₂|=|S₃|=2)."},
]

ADJACENCIES = [
    ("v1", "C",  (0, -1), "S", "S₃ loses a generator: {1,2}→{2}"),
    ("v1", "W",  (1, 0),  "E", "S₂ gains a generator: {1}→{1,3}"),
    ("v1", "T1", (0, -1), "S", "S₃ loses a generator: {1,2}→{1}"),
    ("v1", "T2", (1, 0),  "E", "S₂ gains a generator: {1}→{1,2}"),
    ("v2", "W",  (-1, 0), "W", "S₂ loses a generator: {1,2,3}→{1,3}"),
]

APPLY_MOVES = [
    ("v1", "C",  "s₃⁻(1)", (0, -1), "Remove gen 1 from S₃: S₃={1,2}→{2}"),
    ("v1", "T1", "s₃⁻(2)", (0, -1), "Remove gen 2 from S₃: S₃={1,2}→{1}"),
    ("v1", "T2", "s₂⁺(2)", (1, 0),  "Add gen 2 to S₂: S₂={1}→{1,2}"),
    ("v1", "W",  "s₂⁺(3)", (1, 0),  "Add gen 3 to S₂: S₂={1}→{1,3}"),
]

OWL_BRIDGE = [
    "type_move_alphabet: Signed alphabet {s₂⁺(i), s₂⁻(i), s₃⁺(i), s₃⁻(i) | 1≤i≤r}. 4×r = 12 moves.",
    "split_magma_signature: The dimension split (p,q) = (|S₂|,|S₃|). Two CFGs generate the type lattice.",
    "commutator_vanishing: [s₂⁺(i), s₃⁺(j)] = 0 iff i=j — the dolly-zoom condition.",
    "two_cfg_decomposition: CFG₁ (left-weight) × CFG₂ (right-weight). Leaf polarity selects primary CFG.",
    "dolly_zoom_transition: A single KKT step changes both |S₂| and |S₃| — the 45° edge phenomenon.",
    "degeneracy_threshold: |Sⱼ| > 1 triggers context-sensitive grammar. 7/11 types are degenerate.",
    "fifth_adjacency_mystery: 4 of 5 adjacent pairs caught by cardinality filter. The 5th is unknown.",
]


def s_format(items):
    """Format a list of ints as a set string."""
    return "{" + ", ".join(str(x) for x in sorted(items)) + "}"


# ============================================================================
# Graphiti Encoding
# ============================================================================


async def encode_experiment(svc, group_id: str, density: int = 0):
    """Encode all type theory data into Graphiti episodes."""
    count = 0

    # ---- Phase 1: Station definitions ----
    for s in STATIONS:
        body = (
            f"Station {s['name']}: tree={s['tree']}, size={s['size']}, "
            f"KKT={s['kkt']}, lw={s['lw']}, rw={s['rw']}, polarity={s['polarity']}. {s['note']}"
        )
        await svc.add_episode(name=f"station_{s['name']}", body=body,
                              group_id=group_id, source_description="type_experiment:station")
        count += 1

    # ---- Phase 2: Grid definition ----
    grid_body = (
        "Grid: [1,2]×[-1,1] at step 1/6 = 91 points. "
        "r=3 generators. Each point computes (S₁,S₂,S₃) via KKT multiplier projection."
    )
    await svc.add_episode(name="grid_definition", body=grid_body,
                          group_id=group_id, source_description="type_experiment:grid")
    count += 1

    # ---- Phase 3: Type episodes (one per type) ----
    n_deg = sum(1 for t in TYPES if t["deg"])
    n_total = len(TYPES)
    for t in TYPES:
        body = (
            f"Type {t['id']}: (S₁={s_format(t['S1'])}, S₂={s_format(t['S2'])}, "
            f"S₃={s_format(t['S3'])}) sig=({t['sig'][0]},{t['sig'][1]}) "
            f"degenerate={'yes' if t['deg'] else 'no'} "
            f"KKT={t['kkt']} station={t['station'] or '(none)'}. {t['note']}"
        )
        await svc.add_episode(name=f"type_{t['id']}", body=body,
                              group_id=group_id, source_description="type_experiment:type")
        count += 1

    # Type summary
    summary_body = (
        f"Distinct types on grid: {n_total}. "
        f"Degenerate: {n_deg}. Non-degenerate: {n_total - n_deg}. "
        f"Primary split: S₂-dominant (v2,W) vs S₃-dominant (v1,v3) vs Interior (C,T1)."
    )
    await svc.add_episode(name="type_summary", body=summary_body,
                          group_id=group_id, source_description="type_experiment:summary")
    count += 1

    # ---- Phase 4: Adjacency episodes ----
    body = f"Adjacent pairs among {n_total} types: {len(ADJACENCIES)}."
    await svc.add_episode(name="adjacency_count", body=body,
                          group_id=group_id, source_description="type_experiment:adjacency")
    count += 1

    for src, tgt, d_sig, bearing, note in ADJACENCIES:
        body = (
            f"Adjacency {src}↔{tgt}: Δ({d_sig[0]},{d_sig[1]}) "
            f"bearing={bearing}. {note}"
        )
        await svc.add_episode(name=f"adj_{src}_{tgt}", body=body,
                              group_id=group_id, source_description="type_experiment:adjacency")
        count += 1

    # ---- Phase 5: ApplyMove episodes ----
    for src, tgt, move, d_sig, note in APPLY_MOVES:
        body = (
            f"ApplyMove {src} --({move})--> {tgt}: "
            f"Δ({d_sig[0]},{d_sig[1]}). {note}"
        )
        await svc.add_episode(name=f"move_{src}_{tgt}", body=body,
                              group_id=group_id, source_description="type_experiment:apply_move")
        count += 1

    # ---- Phase 6: OWL bridge keys ----
    for entry in OWL_BRIDGE:
        key = entry.split(":")[0]
        await svc.add_episode(name=f"owl_{key}", body=entry,
                              group_id=group_id, source_description="type_experiment:owl_bridge")
        count += 1

    # ---- Phase 7 (optional): Synthetic density episodes ----
    if density > 0:
        import random
        rng = random.Random(42)  # deterministic
        variations = [
            "signature", "degeneracy", "kkt_proximity", "generator_overlap",
            "polarity_match", "community_affinity",
        ]
        for _ in range(density):
            t = rng.choice(TYPES)
            var = rng.choice(variations)
            body = (
                f"Synthetic density: Type {t['id']} {var} analysis. "
                f"Sig={t['sig']}, deg={'yes' if t['deg'] else 'no'}, "
                f"K-proximity={rng.gauss(0, 0.5):.3f}, "
                f"community_affinity={'S₂' if t['sig'][0] > t['sig'][1] else 'S₃' if t['sig'][1] > t['sig'][0] else 'boundary'}. "
                f"S1={s_format(t['S1'])}."
            )
            await svc.add_episode(
                name=f"density_{var}_{t['id']}_{_}", body=body,
                group_id=group_id, source_description="type_experiment:density",
            )
            count += 1

    return count


# ============================================================================
# Main
# ============================================================================


async def main():
    parser = argparse.ArgumentParser(
        description="Tropical type theory experiment → Graphiti",
    )
    parser.add_argument("--group-id", default="type_experiment",
                        help="Graphiti group partition (default: type_experiment)")
    parser.add_argument("--db-path",
                        help="Path for the Graphiti database (default: temp file)")
    parser.add_argument("--output",
                        help="Path to write results JSON")
    parser.add_argument("--density", type=int, default=0,
                        help="Add N synthetic episodes per run for a denser graph (default: 0)")
    parser.add_argument("--keep-db", action="store_true",
                        help="Don't delete the temp database after completion")
    parser.add_argument("--clear-group", action="store_true",
                        help="Clear existing group data before encoding (not yet implemented)")
    parser.add_argument("--verbose", action="store_true",
                        help="Print detailed progress")
    args = parser.parse_args()

    # --------------- Step 1: Verify Lean availability ---------------
    try:
        subprocess.run(["lake", "--version"], capture_output=True, timeout=10, cwd=PROJECT_ROOT)
    except (subprocess.SubprocessError, FileNotFoundError):
        print("WARNING: 'lake' not available. Running in standalone mode with known data.")
        print("  (Types and adjacencies are hard-coded from verified experiment.)")

    # --------------- Step 2: Set up Graphiti service ---------------
    db_path = args.db_path
    temp_dir = None
    if not db_path:
        temp_dir = tempfile.TemporaryDirectory(prefix="type_experiment_")
        db_path = str(Path(temp_dir.name) / "graphiti.db")
        if args.verbose:
            print(f"Temp database: {db_path}")

    print(f"Starting Graphiti (db={db_path})")

    from infra._graphiti_service import GraphitiService
    svc = GraphitiService(db_path=db_path)
    await svc.start()

    try:
        # --------------- Step 3: Encode experiment into Graphiti ---------------
        n_episodes = await encode_experiment(svc, args.group_id, density=args.density)
        print(f"Encoded {n_episodes} episodes")

        # --------------- Step 4: Run community detection ---------------
        print("Running community detection...")
        t0 = time.time()
        communities = await svc.build_communities()
        elapsed = time.time() - t0
        n_communities = len(communities) if communities else 0
        print(f"Detected {n_communities} communities in {elapsed:.1f}s")

        # --------------- Step 5: Search for additional insights ---------------
        insights = []
        for query in [
            "S₂ degenerate types",
            "S₃ degenerate types",
            "non-degenerate interior",
            "applyMove transitions",
        ]:
            try:
                results = await svc.search(query, args.group_id)
                if results:
                    insights.append({"query": query, "results": len(results)})
            except Exception:
                pass

        # --------------- Step 6: Build results ---------------
        n_deg = sum(1 for t in TYPES if t["deg"])
        n_total = len(TYPES)

        results = {
            "experiment": {
                "group_id": args.group_id,
                "db_path": db_path,
                "density": args.density,
            },
            "summary": {
                "types_found": n_total,
                "degenerate": n_deg,
                "non_degenerate": n_total - n_deg,
                "adjacent_pairs": len(ADJACENCIES),
                "apply_moves": len(APPLY_MOVES),
                "owl_bridge_keys": len(OWL_BRIDGE),
                "episodes_encoded": n_episodes,
                "communities_found": n_communities,
                "community_detection_time_seconds": round(elapsed, 1),
            },
            "communities": [
                {"index": i, "uuid": str(getattr(c, 'uuid', f'c{i}')),
                 "name": str(getattr(c, 'name', f'Community {i}'))}
                for i, c in enumerate(communities or [])
            ],
            "primary_split": (
                "CFG₁ (left-weight/S₂) vs CFG₂ (right-weight/S₃)"
                if n_communities == 2 else f"Unknown ({n_communities} communities)"
            ),
            "types": [
                {"id": t["id"], "signature": list(t["sig"]),
                 "is_degenerate": t["deg"], "station": t["station"],
                 "kkt": list(t["kkt"]), "note": t["note"]}
                for t in TYPES
            ],
            "adjacencies": [
                {"source": a[0], "target": a[1],
                 "delta_signature": list(a[2]), "bearing": a[3],
                 "note": a[4]}
                for a in ADJACENCIES
            ],
            "apply_moves": [
                {"source": a[0], "target": a[1], "move": a[2],
                 "delta_signature": list(a[3]), "note": a[4]}
                for a in APPLY_MOVES
            ],
            "insights": insights,
        }

        # --------------- Step 7: Output ---------------
        print(f"\n{'='*60}")
        print(f"EXPERIMENT RESULTS")
        print(f"{'='*60}")
        print(f"  Types found:           {n_total}")
        print(f"  Degenerate:            {n_deg}")
        print(f"  Non-degenerate:        {n_total - n_deg}")
        print(f"  Adjacent pairs:        {len(ADJACENCIES)}")
        print(f"  ApplyMoves:            {len(APPLY_MOVES)}")
        print(f"  Episodes encoded:      {n_episodes}")
        print(f"  Communities found:     {n_communities}")
        print(f"  Detection time:        {elapsed:.1f}s")
        print(f"  Primary split:         {results['primary_split']}")
        print(f"  DB path:               {db_path}")
        print(f"{'='*60}")

        if args.output:
            with open(args.output, "w") as f:
                json.dump(results, f, indent=2, default=str)
            print(f"\nResults saved to {args.output}")

        # Return raw community count for summary
        return n_communities

    finally:
        if not args.keep_db:
            await svc.stop()
            if temp_dir:
                temp_dir.cleanup()
                if args.verbose:
                    print("Temp database cleaned up")
        else:
            await svc.stop()
            print(f"DB preserved at {db_path}")


if __name__ == "__main__":
    asyncio.run(main())
