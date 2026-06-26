#!/usr/bin/env python3
"""VSM Loop Trace Miner — lift CSG NL to CFG EMLTree shapes.

This is the first practical application of the VSM loop. It takes the 758
reasoning traces from traces.jsonl, converts each to a ThinkingBlock,
infers the coupling signature from the tool chain structure, and runs
the VSM loop to measure convergence.

The output is an alpha map: tree shape → empirical confidence,
showing which CFG productions are empirically validated by session data.

Usage:
    python3 scripts/vsm_mine_traces.py [--limit N] [--verbose]

GAP markers identify heuristics that will be replaced by Lean proofs.
See docs/vsm_loop_interface.md for the full design.
"""
from __future__ import annotations

import json
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# ── Path setup ──────────────────────────────────────────────────────────
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)

from infra._cortex._vsm_loop import (
    ThinkingBlock, VSMLoopResult, run_vsm_loop,
)
from infra._cortex._bridge import NormCodeCortexBridge
from infra._cortex._wfc import ToolOutput
from infra._cortex._logic_types import LogicType


# ═══════════════════════════════════════════════════════════════════════
# Coupling signature inference from tool chains
# ═══════════════════════════════════════════════════════════════════════

def infer_coupling_signature(tools_chain: str) -> Optional[str]:
    """Infer the coupling signature from a tool chain string.

    The tool chain is a string like "read -> bash -> read -> read -> bash".
    The structural properties of the chain determine the coupling:

    - Empty chain → None (ungrounded NL, no structure)
    - Single tool → "commutative-associative" (leaf, no composition)
    - All same tool → "commutative" (order irrelevant, collapse to leaf)
    - Mixed tools, all distinct → "non-commutative" (temporal order kept)
    - Mixed tools with repeats → "non-associative" (grouping matters)

    GAP: This is a heuristic. The actual coupling signature should be
    determined by the dependency structure of the tool calls, not just
    the sequence. A proper analysis would examine whether tool B depends
    on the output of tool A (non-commutative) or whether they're
    independent (commutative). See tree_from_inference_entry() in
    _bridge.py for the formal mapping.

    Reference: lab_notes/006_the_hopf_7_skeleton_of_logic_space.md
    for the coupling_signature → LogicType → cdStep mapping.
    """
    if not tools_chain or not tools_chain.strip():
        return None  # ungrounded

    tools = [t.strip() for t in tools_chain.split("->")]
    tools = [t for t in tools if t]

    if len(tools) == 0:
        return None
    if len(tools) == 1:
        return "commutative-associative"  # leaf

    unique = set(tools)
    if len(unique) == 1:
        # All same tool — order doesn't matter (e.g. "bash -> bash -> bash")
        return "commutative"

    if len(unique) == len(tools):
        # All distinct tools — temporal order matters
        return "non-commutative"

    # Mixed: some repeats, some distinct — grouping matters
    return "non-associative"


# ═══════════════════════════════════════════════════════════════════════
# Trace → ThinkingBlock converter
# ═══════════════════════════════════════════════════════════════════════

def trace_to_block(trace: dict) -> ThinkingBlock:
    """Convert a reasoning trace to a ThinkingBlock.

    GAP: The tool_outcome cost is a heuristic. Currently:
    - "success" → cost = number of tools (bounded, low)
    - "empty" → None (ungrounded, no tool output)
    - "deferred" → cost = barrier (at the edge)

    The actual cost should be computed from the friction_density of the
    LogicType resolved by the bridge's lift_inference, not a heuristic.
    """
    tools_chain = trace.get("tools_chain", "")
    outcome = trace.get("outcome", "")
    coupling = infer_coupling_signature(tools_chain)

    # Infer tool outcome (S1 ground truth)
    tool_outcome: Optional[ToolOutput] = None
    if outcome == "success" and coupling is not None:
        # GAP: cost = number of tools in chain (heuristic)
        n_tools = len([t for t in tools_chain.split("->") if t.strip()])
        tool_outcome = ToolOutput(
            description=f"tools:{tools_chain}",
            cost=min(n_tools, 16),  # cap at barrier
            cert_bits=None,
        )
    elif outcome == "deferred":
        tool_outcome = ToolOutput(
            description="deferred",
            cost=16,  # at the barrier
            cert_bits=None,
        )
    # "empty" or "" → tool_outcome = None (ungrounded)

    return ThinkingBlock(
        flow_index=str(trace.get("thinking_block_index", 0)),
        source=trace.get("thinking_block", ""),
        coupling_signature=coupling,
        tool_outcome=tool_outcome,
        cert_bits=None,  # GAP: no certificate data in traces
    )


# ═══════════════════════════════════════════════════════════════════════
# Main mining loop
# ═══════════════════════════════════════════════════════════════════════

def mine_traces(
    traces_path: str = "reasoning_library/traces.jsonl",
    limit: Optional[int] = None,
    verbose: bool = False,
) -> Dict:
    """Mine reasoning traces through the VSM loop.

    Returns a summary dict with:
    - total_traces: int
    - converged: int
    - garbage: int (ungrounded, no tools)
    - alpha_distribution: {alpha_bucket: count}
    - coupling_distribution: {coupling_signature: count}
    - logic_type_distribution: {LogicType: count}
    - tree_shape_alpha: {tree_shape: avg_alpha}  ← the CFG production map
    """
    traces = []
    with open(traces_path) as f:
        for line in f:
            if line.strip():
                traces.append(json.loads(line))

    if limit:
        traces = traces[:limit]

    print(f"Loading {len(traces)} traces from {traces_path}...")

    bridge = NormCodeCortexBridge()

    # Convert all traces to ThinkingBlocks
    blocks = [trace_to_block(t) for t in traces]

    # Run VSM loop on the entire trace sequence
    # GAP: Running all 758 blocks in one VSM loop is not ideal — each
    # session should be a separate loop. For now, we group by session.
    sessions: Dict[str, List[ThinkingBlock]] = defaultdict(list)
    for trace, block in zip(traces, blocks):
        session_id = trace.get("session_id", "unknown")
        sessions[session_id].append(block)

    print(f"Grouped into {len(sessions)} sessions")

    # Run VSM loop per session
    results: List[Tuple[str, VSMLoopResult]] = []
    for session_id, session_blocks in sessions.items():
        result = run_vsm_loop(session_blocks, bridge, max_iterations=7)
        results.append((session_id, result))

    # Aggregate results
    total = len(results)
    converged = sum(1 for _, r in results if r.converged)
    garbage = sum(1 for _, r in results if r.alpha < 0.5)

    # Alpha distribution
    alpha_buckets = Counter()
    for _, r in results:
        bucket = round(r.alpha, 1)
        alpha_buckets[bucket] += 1

    # Coupling signature distribution (from blocks)
    coupling_dist = Counter()
    for block in blocks:
        sig = block.coupling_signature or "ungrounded"
        coupling_dist[sig] += 1

    # Logic type distribution (from results)
    logic_dist = Counter()
    for _, r in results:
        if r.stable_type is not None:
            logic_dist[r.stable_type.name] += 1

    # Tree shape → alpha map (the CFG production map)
    # GAP: tree shape should come from the EMLTree, not the coupling signature.
    # Currently we use the coupling signature as a proxy for tree shape.
    tree_shape_alpha: Dict[str, List[float]] = defaultdict(list)
    for session_id, r in results:
        # Use the last block's coupling signature as the session's shape
        session_blocks = sessions[session_id]
        if session_blocks:
            last_sig = session_blocks[-1].coupling_signature or "ungrounded"
            tree_shape_alpha[last_sig].append(r.alpha)

    tree_shape_avg = {
        shape: sum(alphas) / len(alphas)
        for shape, alphas in tree_shape_alpha.items()
    }

    # Outcome → alpha correlation
    outcome_alpha: Dict[str, List[float]] = defaultdict(list)
    for trace, block in zip(traces, blocks):
        outcome = trace.get("outcome", "unknown")
        session_id = trace.get("session_id", "unknown")
        for sid, r in results:
            if sid == session_id:
                outcome_alpha[outcome].append(r.alpha)
                break

    outcome_avg = {
        outcome: sum(alphas) / len(alphas)
        for outcome, alphas in outcome_alpha.items()
        if alphas
    }

    summary = {
        "total_traces": len(traces),
        "total_sessions": len(sessions),
        "sessions_converged": converged,
        "sessions_garbage": garbage,
        "alpha_distribution": dict(sorted(alpha_buckets.items())),
        "coupling_signature_distribution": dict(coupling_dist.most_common()),
        "logic_type_distribution": dict(logic_dist.most_common()),
        "tree_shape_alpha": dict(sorted(tree_shape_avg.items())),
        "outcome_alpha": dict(sorted(outcome_avg.items())),
    }

    if verbose:
        print("\n" + "=" * 60)
        print("VSM LOOP TRACE MINING RESULTS")
        print("=" * 60)
        print(f"\nTotal traces: {summary['total_traces']}")
        print(f"Total sessions: {summary['total_sessions']}")
        print(f"Sessions converged: {summary['sessions_converged']}")
        print(f"Sessions garbage (alpha < 0.5): {summary['sessions_garbage']}")

        print(f"\n─ Coupling signature distribution (CSG → CFG mapping) ─")
        for sig, count in summary["coupling_signature_distribution"].items():
            pct = 100 * count / len(traces)
            bar = "█" * int(pct / 2)
            print(f"  {sig:25s} {count:4d} ({pct:5.1f}%) {bar}")

        print(f"\n─ Logic type distribution (CFG productions) ─")
        for lt_name, count in summary["logic_type_distribution"].items():
            print(f"  {lt_name:25s} {count:4d}")

        print(f"\n─ Alpha distribution (convergence confidence) ─")
        for alpha, count in sorted(summary["alpha_distribution"].items()):
            bar = "█" * count
            print(f"  alpha={alpha:.1f}  {count:4d} {bar}")

        print(f"\n─ Tree shape → average alpha (CFG production map) ─")
        for shape, avg_alpha in summary["tree_shape_alpha"].items():
            print(f"  {shape:25s} avg_alpha={avg_alpha:.3f}")

        print(f"\n─ Outcome → average alpha (S1 ground truth) ─")
        for outcome, avg_alpha in summary["outcome_alpha"].items():
            print(f"  {outcome:25s} avg_alpha={avg_alpha:.3f}")

        print("\n" + "=" * 60)
        print("CSG → CFG LIFTING SUMMARY")
        print("=" * 60)
        ungrounded = coupling_dist.get(None, 0) + coupling_dist.get("ungrounded", 0)
        grounded = len(traces) - ungrounded
        print(f"  CSG (ungrounded NL):     {ungrounded} traces ({100*ungrounded/len(traces):.1f}%)")
        print(f"  CFG (grounded commands): {grounded} traces ({100*grounded/len(traces):.1f}%)")
        print(f"  Convergence rate:        {100*converged/total:.1f}%")
        print(f"  Average alpha:           {sum(r.alpha for _, r in results)/total:.3f}")

    return summary


# ═══════════════════════════════════════════════════════════════════════
# CLI
# ═══════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Mine reasoning traces through VSM loop")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of traces")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    parser.add_argument("--output", "-o", default=None, help="Output JSON file")
    args = parser.parse_args()

    traces_path = os.path.join(PROJECT_ROOT, "reasoning_library", "traces.jsonl")
    summary = mine_traces(traces_path, limit=args.limit, verbose=args.verbose)

    if args.output:
        output_path = os.path.join(PROJECT_ROOT, args.output)
        with open(output_path, "w") as f:
            json.dump(summary, f, indent=2, default=str)
        print(f"\nResults written to {output_path}")
