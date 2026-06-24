#!/usr/bin/env python3
"""Batch pipeline for creating reasoning scripts from session traces.

Usage:
    python3 -m reasoning_library.pipeline [--no-model] [--min-cluster N]
    
    # or as a script from the reasoning_library directory:
    cd reasoning_library && python3 pipeline.py [--no-model]

This script:
1. Parses session files
2. Embeds traces
3. Clusters similar traces
4. Compresses clusters into reasoning scripts

Output files (in reasoning_library/):
    traces.jsonl     — Parsed traces
    clusters.json    — Cluster assignments
    scripts.json     — Compressed scripts
    library.json     — Combined library
"""


from __future__ import annotations
import sys, os
if __package__ is None:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import argparse
import json
from pathlib import Path
from collections import Counter

from parser import parse_all_sessions, detect_outcome
from embedder import embed_batch, cosine_similarity
from clusterer import cluster_traces
from compressor import compress_cluster_via_model
from models import SessionReasoningScript, trace_to_jsonl_line


OUTPUT_DIR = Path(__file__).parent  # Same directory as pipeline.py


def compress_heuristic(cluster, traces):
    """Heuristic compression when model is unavailable."""
    cluster_traces = [traces[i] for i in cluster.members]

    all_tools = []
    for t in cluster_traces:
        all_tools.extend(t.tools_used)
    tool_counts = {}
    for t in all_tools:
        tool_counts[t] = tool_counts.get(t, 0) + 1
    sorted_tools = sorted(tool_counts, key=lambda t: tool_counts[t], reverse=True)
    tool_chain = " -> ".join(sorted_tools[:5])

    first = cluster_traces[0]
    priming = f"When working on {cluster.dominant_intent}: {first.thinking_block[:150]}..."
    runbook = f"1. Check the relevant {' '.join(cluster.all_tags) or 'source files'}\n"
    runbook += f"2. Follow the tool chain: {tool_chain or 'read -> edit -> verify'}\n"
    runbook += f"3. Verify changes don't break dependent modules"

    return SessionReasoningScript(
        id=f"script_{cluster.cluster_id}_heuristic",
        priming_prompt=priming,
        debug_runbook=runbook,
        tool_chain=tool_chain,
        intent_category=cluster.dominant_intent,
        domain_tags=cluster.all_tags,
        centroid=cluster.centroid,
        source_trace_count=len(cluster.members),
        version=0,
    )


def run_pipeline(session_dir=".", output_dir=None, use_model=True,
                 min_cluster_size=3, similarity_threshold=0.65):
    """Run the full batch pipeline."""
    print("=" * 60)
    print("Reasoning Library — Batch Pipeline")
    print("=" * 60)

    output_dir = Path(output_dir) if output_dir else OUTPUT_DIR
    output_dir.mkdir(parents=True, exist_ok=True)

    # Phase 1: Parse
    print("\n[Phase 1] Parsing session files...")
    traces = parse_all_sessions(session_dir)
    traces = detect_outcome(traces)
    print(f"  -> {len(traces)} thinking blocks from {len(set(t.session_file for t in traces))} sessions")

    traces_path = output_dir / "traces.jsonl"
    with open(traces_path, "w") as f:
        for t in traces:
            f.write(trace_to_jsonl_line(t) + "\n")
    print(f"  -> Saved {len(traces)} traces to {traces_path}")

    # Phase 2: Embed
    print("\n[Phase 2] Computing embeddings...")
    embeddings = embed_batch(traces)
    for i, emb in enumerate(embeddings):
        traces[i].embedding = emb
    print(f"  -> {len(embeddings)} embeddings computed (1024-dim)")

    # Phase 3: Cluster
    print("\n[Phase 3] Clustering traces...")
    clusters = cluster_traces(traces, min_cluster_size=min_cluster_size,
                              similarity_threshold=similarity_threshold)
    print(f"  -> {len(clusters)} clusters (min_size={min_cluster_size}, threshold={similarity_threshold})")

    cluster_data = []
    for c in clusters:
        cluster_data.append({
            "cluster_id": c.cluster_id,
            "size": c.size,
            "intent": c.dominant_intent,
            "tags": c.all_tags,
            "member_indices": c.members[:10],
        })
    clusters_path = output_dir / "clusters.json"
    with open(clusters_path, "w") as f:
        json.dump(cluster_data, f, indent=2)
    print(f"  -> Saved {len(clusters)} clusters to {clusters_path}")

    # Phase 4: Compress
    print("\n[Phase 4] Compressing clusters into scripts...")
    scripts = []

    for i, cluster in enumerate(clusters):
        print(f"  Cluster {i+1}/{len(clusters)} ({cluster.size} traces, "
              f"intent={cluster.dominant_intent})...", end=" ")

        if use_model:
            script = compress_cluster_via_model(cluster, traces)
        else:
            script = compress_heuristic(cluster, traces)

        if script:
            scripts.append(script)
            print(f"OK")
        else:
            print("FAILED")

    print(f"  -> {len(scripts)} scripts created")

    scripts_path = output_dir / "scripts.json"
    with open(scripts_path, "w") as f:
        for s in scripts:
            d = s.__dict__.copy()
            if d.get("centroid"):
                d["_centroid_preview"] = d["centroid"][:3]
                d["_centroid_len"] = len(d["centroid"])
                del d["centroid"]
            json.dump(d, f, indent=2)
            f.write("\n")
    print(f"  -> Saved {len(scripts)} scripts to {scripts_path}")

    library = {
        "version": "0.1",
        "trace_count": len(traces),
        "cluster_count": len(clusters),
        "script_count": len(scripts),
        "sessions": sorted(set(t.session_file for t in traces)),
        "scripts": [s.__dict__ for s in scripts],
    }
    library_path = output_dir / "library.json"
    with open(library_path, "w") as f:
        json.dump(library, f, indent=2)
    print(f"  -> Saved library to {library_path}")

    # Summary
    print("\n" + "=" * 60)
    print("Pipeline Summary")
    print("=" * 60)
    print(f"  Traces:    {len(traces)}")
    print(f"  Clusters:  {len(clusters)}")
    print(f"  Scripts:   {len(scripts)}")
    print(f"  Output:    {output_dir}")

    intent_dist = Counter(s.intent_category for s in scripts)
    if intent_dist:
        print("\n  Script distribution by intent:")
        for intent, count in intent_dist.most_common():
            print(f"    {intent:30s}: {count}")

    return {
        "traces": len(traces),
        "clusters": len(clusters),
        "scripts": len(scripts),
        "intent_dist": dict(intent_dist),
    }


def main():
    parser = argparse.ArgumentParser(description="Run the reasoning library batch pipeline")
    parser.add_argument("--session-dir", default=".", help="Directory with session-ses_*.md files")
    parser.add_argument("--output-dir", default=str(OUTPUT_DIR), help="Output directory")
    parser.add_argument("--no-model", action="store_true", help="Skip model-based compression")
    parser.add_argument("--min-cluster", type=int, default=3, help="Minimum traces per cluster")
    parser.add_argument("--threshold", type=float, default=0.65, help="Similarity threshold")
    args = parser.parse_args()

    result = run_pipeline(
        session_dir=args.session_dir,
        output_dir=args.output_dir,
        use_model=not args.no_model,
        min_cluster_size=args.min_cluster,
        similarity_threshold=args.threshold,
    )

    print(f"\nDone: {result['scripts']} scripts from {result['traces']} traces")
    return 0


if __name__ == "__main__":
    sys.exit(main())
