#!/usr/bin/env python3
"""
Run the tropical type theory experiment and encode results into Graphiti.

Encodes the type lattice into Graphiti via:
  - Episodes (narrative context for each station, type, adjacency, applyMove)
  - Triplets (explicit entity-relation-entity edges forming a structured graph)
  - Community detection on the entity graph

Usage:
    ./scripts/run_type_experiment.sh                                    # default
    ./scripts/run_type_experiment.sh --output results.json              # save results
    ./scripts/run_type_experiment.sh --triplets --keep-db --verbose     # entity edges
    ./scripts/run_type_experiment.sh --triplets --temporal-path 3       # + temporal chains

What changes the community count:
  --triplets        Adds explicit IS_ADJACENT_TO, AT_STATION, and TRANSITIONS_VIA
                    edges between type entities. Without this, Graphiti only has
                    episode co-occurrence to work with (→ 2 communities).
  --temporal-path N Adds N ordered path episodes (v₁→C→W→v₂→v₃). Each episode
                    references the previous type, creating temporal chains that
                    community detection uses for finer-grained clusters.
  --generators N    Scaffolding for r=4 (not yet implemented — needs Lean algebra).

Requires:
    - lake (Lean 4) available on PATH
    - graphiti-core[falkordblite] installed
    - PYTHONPATH includes the LaserCortex project root
"""

import argparse
import asyncio
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Optional
from uuid import uuid4

# Add project root to path for infra imports
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


# ============================================================================
# Known Type Theory Data (r=3, step=1/6, stations P, NP, PN)
# ============================================================================
# This data is verified by the Lean experiment (TropicalTypeAlgebra.lean).
# It encodes the type lattice that we feed into Graphiti for community detection.

STATIONS = [
    dict(name="P",  tree="Node(Leaf,Leaf)",              kkt=(1.0, 0.0), lw=0, rw=0, size=1, polarity="left",
         note="Tie-breaker: coordX≈coordY→left. Simplest binary tree."),
    dict(name="NP", tree="Node(Leaf,Node(Leaf,Leaf))",  kkt=(2.0, -1.0), lw=0, rw=1, size=2, polarity="right",
         note="Right-dominant: rightmost leaf path has weight 2."),
    dict(name="PN", tree="Node(Node(Leaf,Leaf),Leaf)",  kkt=(2.0, 1.0), lw=1, rw=0, size=2, polarity="left",
         note="Left-dominant: leftmost leaf path has weight 2."),
]

TYPES = [
    dict(id="v1", S1=[1, 3], S2=[1],   S3=[1, 2],     sig=(1, 2), deg=True,  kkt=(1.0, 0.0), station="P",
         note="S₃-dominant. Anchor of S₃-ville."),
    dict(id="v2", S1=[2, 3], S2=[1, 2, 3], S3=[2],   sig=(3, 1), deg=True,  kkt=(2.0, -1.0), station="NP",
         note="Maximally degenerate S₂ (|S₂|=3). Anchor of S₂-ville."),
    dict(id="v3", S1=[3],    S2=[1, 3],   S3=[1, 2, 3], sig=(2, 3), deg=True,  kkt=(2.0, 1.0), station="PN",
         note="Maximally degenerate S₃ (|S₃|=3). Anchor of S₃-ville."),
    dict(id="C",  S1=[3],    S2=[1],     S3=[2],       sig=(1, 1), deg=False, kkt=(1.5, 0.0), station="",
         note="Interior. Non-degenerate pivot between S₂-ville and S₃-ville."),
    dict(id="W",  S1=[3],    S2=[1, 3],   S3=[2],       sig=(2, 1), deg=True,  kkt=(2.0, 0.0), station="",
         note="Wall. S₂-degenerate (|S₂|=2). Anchor of S₂-ville."),
    dict(id="T1", S1=[1, 3], S2=[1],     S3=[1],       sig=(1, 1), deg=False, kkt=(1.0, 0.0), station="",
         note="ApplyMove: v₁ S₃⁻(2). S₃={1}."),
    dict(id="T2", S1=[1, 3], S2=[1, 2],   S3=[1, 2],   sig=(2, 2), deg=True,  kkt=(1.0, 0.0), station="",
         note="ApplyMove: v₁ S₂⁺(2). Symmetric (|S₂|=|S₃|=2)."),
]

ADJACENCIES = [
    ("v1", "C",  (0, -1), "S", "S₃ loses a generator: {1,2}→{2}"),
    ("v1", "W",  (1, 0),  "E", "S₂ gains a generator: {1}→{1,3}"),
    ("v1", "T1", (0, -1), "S", "S₃ loses a generator: {1,2}→{1}"),
    ("v1", "T2", (1, 0),  "E", "S₂ gains a generator: {1}→{1,2}"),
    ("v2", "W",  (-1, 0), "W", "S₂ loses a generator: {1,2,3}→{1,3}"),
]

APPLY_MOVES = [
    ("v1", "C",  "s₃⁻(1)", (0, -1), "Remove gen 1 from S₃"),
    ("v1", "T1", "s₃⁻(2)", (0, -1), "Remove gen 2 from S₃"),
    ("v1", "T2", "s₂⁺(2)", (1, 0),  "Add gen 2 to S₂"),
    ("v1", "W",  "s₂⁺(3)", (1, 0),  "Add gen 3 to S₂"),
]

OWL_BRIDGE = [
    "type_move_alphabet: Signed alphabet {s₂⁺(i), s₂⁻(i), s₃⁺(i), s₃⁻(i)}. 4×r = 12 moves.",
    "split_magma_signature: Dimension split (p,q) = (|S₂|,|S₃|). Two CFGs generate the type lattice.",
    "commutator_vanishing: [s₂⁺(i), s₃⁺(j)] = 0 iff i=j — the dolly-zoom condition.",
    "two_cfg_decomposition: CFG₁ (left-weight) × CFG₂ (right-weight). Leaf polarity selects primary CFG.",
    "dolly_zoom_transition: A single KKT step changes both |S₂| and |S₃| — the 45° edge phenomenon.",
    "degeneracy_threshold: |Sⱼ| > 1 triggers context-sensitive grammar. 5/7 types are degenerate.",
    "fifth_adjacency_mystery: 4/5 adjacent pairs caught by cardinality filter. The 5th is unknown.",
]

# Temporal path through the type lattice (for --temporal-path)
TEMPORAL_PATH = ["v1", "C", "W", "v2", "v3", "W", "C", "T1", "v1"]


def s_format(items):
    """Format a list of ints as a set string."""
    return "{" + ", ".join(str(x) for x in sorted(items)) + "}"


def type_by_id(tid):
    """Look up a type dict by its id."""
    for t in TYPES:
        if t["id"] == tid:
            return t
    return None


# ============================================================================
# Graphiti Encoding
# ============================================================================


async def encode_experiment(svc, group_id: str, do_triplets: bool, temporal_steps: int):
    """Encode type theory data into Graphiti.

    Returns episode count.
    """
    count = 0

    # ---- Phase 1: Station episodes ----
    for s in STATIONS:
        body = (
            f"Station {s['name']}: tree={s['tree']}, size={s['size']}, "
            f"KKT={s['kkt']}, lw={s['lw']}, rw={s['rw']}, polarity={s['polarity']}. {s['note']}"
        )
        await svc.add_episode(
            name=f"station_{s['name']}", body=body,
            group_id=group_id, source_description="type_experiment:station",
        )
        count += 1

    # ---- Phase 2: Grid definition ----
    await svc.add_episode(
        name="grid_definition",
        body="Grid: [1,2]×[-1,1] at step 1/6 = 91 points. r=3 generators. KKT projection.",
        group_id=group_id, source_description="type_experiment:grid",
    )
    count += 1

    # ---- Phase 3: Type episodes ----
    n_deg = sum(1 for t in TYPES if t["deg"])
    for t in TYPES:
        body = (
            f"Type {t['id']}: (S₁={s_format(t['S1'])}, S₂={s_format(t['S2'])}, "
            f"S₃={s_format(t['S3'])}) sig=({t['sig'][0]},{t['sig'][1]}) "
            f"degenerate={'yes' if t['deg'] else 'no'} "
            f"KKT={t['kkt']} station={t['station'] or '(none)'}. {t['note']}"
        )
        await svc.add_episode(
            name=f"type_{t['id']}", body=body,
            group_id=group_id, source_description="type_experiment:type",
        )
        count += 1

    # Type summary
    await svc.add_episode(
        name="type_summary",
        body=(f"Distinct types: {len(TYPES)}. Degenerate: {n_deg}. "
              f"Non-degenerate: {len(TYPES) - n_deg}. "
              f"Split: S₂-dominant (v2,W) vs S₃-dominant (v1,v3) vs boundary (C,T1,T2)."),
        group_id=group_id, source_description="type_experiment:summary",
    )
    count += 1

    # ---- Phase 4: Adjacency episodes ----
    await svc.add_episode(
        name="adjacency_count",
        body=f"Adjacent pairs: {len(ADJACENCIES)}.",
        group_id=group_id, source_description="type_experiment:adjacency",
    )
    count += 1

    for src, tgt, d_sig, bearing, note in ADJACENCIES:
        body = f"Adjacency {src}↔{tgt}: Δ({d_sig[0]},{d_sig[1]}) bearing={bearing}. {note}"
        await svc.add_episode(
            name=f"adj_{src}_{tgt}", body=body,
            group_id=group_id, source_description="type_experiment:adjacency",
        )
        count += 1

    # ---- Phase 5: ApplyMove episodes ----
    for src, tgt, move, d_sig, note in APPLY_MOVES:
        body = f"ApplyMove {src} --({move})--> {tgt}: Δ({d_sig[0]},{d_sig[1]}). {note}"
        await svc.add_episode(
            name=f"move_{src}_{tgt}", body=body,
            group_id=group_id, source_description="type_experiment:apply_move",
        )
        count += 1

    # ---- Phase 6: OWL bridge keys ----
    for entry in OWL_BRIDGE:
        key = entry.split(":")[0]
        await svc.add_episode(
            name=f"owl_{key}", body=entry,
            group_id=group_id, source_description="type_experiment:owl_bridge",
        )
        count += 1

    # ---- Phase 7: Triplet entity edges ----
    if do_triplets:
        n_triplets = await add_type_triplets(svc, group_id)
        count += n_triplets
        print(f"  Added {n_triplets} triplet edges")

    # ---- Phase 8: Temporal path episodes ----
    if temporal_steps > 0:
        n_temporal = await add_temporal_path(svc, group_id, temporal_steps)
        count += n_temporal
        print(f"  Added {n_temporal} temporal path episodes")

    return count


async def add_type_triplets(svc, group_id: str) -> int:
    """Add explicit EntityNode+EntityEdge triplets for the type lattice.

    Accesses svc._graphiti directly to call add_triplet.
    Creates entity nodes for each type and station, then adds edges for
    adjacencies, station assignments, and applyMove transitions.

    The triplet API requires:
      - EntityNode with name, group_id, labels (list[str])
      - EntityEdge with source_node_uuid, target_node_uuid, created_at, name, fact, group_id
      - The edge's source/target UUIDs must match the node objects passed to add_triplet
    """
    from graphiti_core.nodes import EntityNode
    from graphiti_core.edges import EntityEdge
    from datetime import datetime, timezone

    g = svc._graphiti  # the underlying graphiti_core.Graphiti instance
    n = 0
    now = datetime.now(timezone.utc)

    # Memoize entity nodes to avoid duplicates and reuse UUIDs
    node_cache: dict[str, tuple[EntityNode, EntityNode]] = {}

    def get_type_node(t):
        """Get or create an EntityNode for a type, returning (node, node_with_embedded)."""
        key = f"type_{t['id']}"
        if key not in node_cache:
            labels = ["type", f"sig_{t['sig'][0]}_{t['sig'][1]}",
                      "degenerate" if t['deg'] else "non_degenerate"]
            node = EntityNode(name=key, group_id=group_id, labels=labels)
            node_cache[key] = (node, node)
        return node_cache[key][0]

    def get_station_node(name):
        """Get or create an EntityNode for a station."""
        key = f"station_{name}"
        if key not in node_cache:
            s = next(st for st in STATIONS if st["name"] == name)
            node = EntityNode(name=key, group_id=group_id,
                              labels=["station", f"polarity_{s['polarity']}"])
            node_cache[key] = (node, node)
        return node_cache[key][0]

    def make_edge(source_node, target_node, edge_name, fact):
        """Create an EntityEdge with properly set source/target UUIDs."""
        return EntityEdge(
            source_node_uuid=source_node.uuid,
            target_node_uuid=target_node.uuid,
            created_at=now,
            name=edge_name,
            fact=fact,
            group_id=group_id,
        )

    # Station → type assignment edges
    for t in TYPES:
        if t["station"]:
            src = get_type_node(t)
            tgt = get_station_node(t["station"])
            edge = make_edge(src, tgt, "assigned_to",
                             f"Type {t['id']} is at station {t['station']}")
            result = await g.add_triplet(source_node=src, edge=edge, target_node=tgt)
            n += 1

    # Adjacency edges between types (direction: signature increase)
    for src_id, tgt_id, d_sig, bearing, note in ADJACENCIES:
        src = get_type_node(type_by_id(src_id))
        tgt = get_type_node(type_by_id(tgt_id))
        edge = make_edge(src, tgt, "is_adjacent_to",
                         f"{src_id} → {tgt_id}: bearing={bearing} Δs=({d_sig[0]},{d_sig[1]})")
        result = await g.add_triplet(source_node=src, edge=edge, target_node=tgt)
        n += 1

    # ApplyMove transitions (directional: source --move--> target)
    for src_id, tgt_id, move, d_sig, note in APPLY_MOVES:
        src = get_type_node(type_by_id(src_id))
        tgt = get_type_node(type_by_id(tgt_id))
        edge = make_edge(src, tgt, "transitions_via",
                         f"{src_id} --({move})--> {tgt_id}")
        result = await g.add_triplet(source_node=src, edge=edge, target_node=tgt)
        n += 1

    # Community affinity edges (synthetic: same dominant coordinate → linked)
    for t in TYPES:
        for u in TYPES:
            if t["id"] >= u["id"]:
                continue
            t_dom = ("S2" if t["sig"][0] > t["sig"][1]
                     else "S3" if t["sig"][1] > t["sig"][0]
                     else "equal")
            u_dom = ("S2" if u["sig"][0] > u["sig"][1]
                     else "S3" if u["sig"][1] > u["sig"][0]
                     else "equal")
            if t_dom == u_dom and t_dom != "equal":
                src = get_type_node(t)
                tgt = get_type_node(u)
                edge = make_edge(src, tgt, "same_community",
                                 f"{t['id']} and {u['id']} are both {t_dom}-dominant")
                result = await g.add_triplet(source_node=src, edge=edge, target_node=tgt)
                n += 1

    return n


async def add_temporal_path(svc, group_id: str, steps: int) -> int:
    """Add ordered path episodes through the type lattice.

    Creates a chain: v1 → C → W → v2 → v3 → W → C → T1 → v1 → ...
    Each episode references the type at the current step AND the previous type,
    creating temporal co-occurrence structure for community detection.
    """
    n = 0
    path = TEMPORAL_PATH * (steps // len(TEMPORAL_PATH) + 1)
    path = path[:steps]

    for i in range(steps):
        tid = path[i]
        t = type_by_id(tid)
        if not t:
            continue
        prev = path[i - 1] if i > 0 else "grid_origin"
        body = (
            f"Temporal step {i+1}/{steps}: traversing to type {tid} from {prev}. "
            f"Type {tid}: sig=({t['sig'][0]},{t['sig'][1]}), "
            f"KKT={t['kkt']}, degenerate={'yes' if t['deg'] else 'no'}. "
            f"Step vector: from {prev} towards {tid}."
        )
        await svc.add_episode(
            name=f"temporal_{i:03d}_{tid}",
            body=body,
            group_id=group_id,
            source_description="type_experiment:temporal_path",
        )
        n += 1
    return n


# ============================================================================
# Main
# ============================================================================


async def main():
    parser = argparse.ArgumentParser(
        description="Tropical type theory experiment → Graphiti",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Examples:\n"
            "  %(prog)s                                    # episodes only → 2 communities\n"
            "  %(prog)s --triplets                         # + entity edges → more communities\n"
            "  %(prog)s --triplets --temporal-path 10      # + temporal chains\n"
            "  %(prog)s --keep-db --output results.json    # persistent + save\n"
        ),
    )
    parser.add_argument("--group-id", default="type_experiment",
                        help="Graphiti group partition")
    parser.add_argument("--db-path", help="Graphiti database path (default: temp file)")
    parser.add_argument("--output", help="Path to write results JSON")
    parser.add_argument("--triplets", action="store_true",
                        help="Add explicit entity-relation-entity edges (IS_ADJACENT_TO, etc.)")
    parser.add_argument("--temporal-path", type=int, default=0, metavar="N",
                        help="Add N ordered path episodes through the type lattice")
    parser.add_argument("--generators", type=int, default=3,
                        help="Number of generators r (default: 3; r=4 not yet supported)")
    parser.add_argument("--keep-db", action="store_true",
                        help="Don't delete temp database after completion")
    parser.add_argument("--verbose", action="store_true",
                        help="Print detailed progress")
    args = parser.parse_args()

    # Validate
    if args.generators != 3:
        print(f"WARNING: r={args.generators} requested but only r=3 is supported. Continuing with r=3 data.")

    # ---- Start Graphiti ----
    db_path = args.db_path
    temp_dir = None
    if not db_path:
        temp_dir = tempfile.TemporaryDirectory(prefix="type_experiment_")
        db_path = str(Path(temp_dir.name) / "graphiti.db")

    print(f"Starting Graphiti (db={db_path})")
    from infra._graphiti_service import GraphitiService
    svc = GraphitiService(db_path=db_path)
    await svc.start()

    try:
        # ---- Encode ----
        n_episodes = await encode_experiment(
            svc, args.group_id,
            do_triplets=args.triplets,
            temporal_steps=args.temporal_path,
        )
        print(f"Encoded {n_episodes} items")

        # ---- Community detection ----
        print("Running community detection...")
        t0 = time.time()
        try:
            communities = await asyncio.wait_for(
                svc.build_communities(), timeout=60.0
            )
            elapsed = time.time() - t0
            n_communities = len(communities) if communities else 0
            print(f"Detected {n_communities} communities in {elapsed:.1f}s")
        except asyncio.TimeoutError:
            elapsed = time.time() - t0
            print(f"Community detection timed out after {elapsed:.1f}s")
            print("  (This is expected with a mock LLM — community summarization hangs)")
            communities = None
            n_communities = -1  # signal: timeout

        # ---- Build results ----
        n_deg = sum(1 for t in TYPES if t["deg"])
        results = {
            "experiment": {
                "group_id": args.group_id,
                "triplets": args.triplets,
                "temporal_path": args.temporal_path,
                "db_path": db_path,
            },
            "config": {
                "types": len(TYPES),
                "stations": len(STATIONS),
                "adjacencies": len(ADJACENCIES),
                "apply_moves": len(APPLY_MOVES),
                "owl_keys": len(OWL_BRIDGE),
            },
            "summary": {
                "episodes_encoded": n_episodes,
                "communities_found": n_communities if n_communities >= 0 else "timeout",
                "detection_time_seconds": round(elapsed, 1),
                "primary_split": (
                    "TIMEOUT — LLM-dependent summarization hung"
                    if n_communities < 0 else
                    "CFG₁ (left-weight/S₂) vs CFG₂ (right-weight/S₃)"
                    if n_communities == 2
                    else f"{n_communities} communities — sign of richer structure"
                ),
            },
            "types": [
                {"id": t["id"], "signature": list(t["sig"]),
                 "is_degenerate": t["deg"], "station": t["station"],
                 "kkt": list(t["kkt"]), "note": t["note"]}
                for t in TYPES
            ],
            "adjacencies": [
                {"source": a[0], "target": a[1],
                 "delta_signature": list(a[2]), "bearing": a[3], "note": a[4]}
                for a in ADJACENCIES
            ],
            "apply_moves": [
                {"source": a[0], "target": a[1], "move": a[2],
                 "delta_signature": list(a[3]), "note": a[4]}
                for a in APPLY_MOVES
            ],
        }

        # ---- Print ----
        n_deg = sum(1 for t in TYPES if t["deg"])
        print(f"\n{'='*60}")
        print(f"EXPERIMENT RESULTS")
        print(f"{'='*60}")
        print(f"  Types:               {len(TYPES)} ({len(TYPES) - n_deg} non-degenerate)")
        print(f"  Adjacent pairs:      {len(ADJACENCIES)}")
        print(f"  ApplyMoves:          {len(APPLY_MOVES)}")
        print(f"  Items encoded:       {n_episodes}")
        print(f"  Communities found:   {results['summary']['communities_found']}")
        print(f"  Detection time:      {elapsed:.1f}s")
        print(f"  Entity edges:        {'yes' if args.triplets else 'no'}")
        print(f"  Temporal path steps: {args.temporal_path}")
        print(f"  Primary split:       {results['summary']['primary_split']}")
        print(f"  DB path:             {db_path}")
        print(f"{'='*60}")

        if args.output:
            with open(args.output, "w") as f:
                json.dump(results, f, indent=2, default=str)
            print(f"\nResults saved to {args.output}")

    finally:
        if not args.keep_db:
            await svc.stop()
            if temp_dir:
                temp_dir.cleanup()
        else:
            await svc.stop()
            print(f"DB preserved at {db_path}")


if __name__ == "__main__":
    asyncio.run(main())
