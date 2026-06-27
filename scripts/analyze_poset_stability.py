#!/usr/bin/env python3
"""
M2d — Knee / Stability Analysis for the Markov Poset

Validates that the Markov poset captures real structure, not noise:
  1. Knee curve — cumulative unique transitions vs traces processed
  2. Subsample stability — top-10 candidate rank correlation at 50-90%

Usage:
    python scripts/analyze_poset_stability.py
"""

from __future__ import annotations

import json
import random
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

import numpy as np
from scipy.stats import spearmanr

# ── Paths ──────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRACES_JSONL = PROJECT_ROOT / "reasoning_library" / "traces.jsonl"
METADATA_PATH = PROJECT_ROOT / "data" / "nl_markov_metadata.json"
CANDIDATES_PATH = PROJECT_ROOT / "data" / "reinforcement_candidates.json"
OUTPUT_PATH = PROJECT_ROOT / "data" / "poset_stability.json"

STOP = "\x02"


# =============================================================================
# Knee curve — recompute unique transitions incrementally
# =============================================================================

def compute_knee_curve(
    traces: List[List[str]],
) -> Dict[str, Any]:
    """Cumulative unique transitions vs traces processed."""
    print("  Computing knee curve...")

    all_transitions: Set[Tuple[str, str, str]] = set()
    curve: List[int] = []

    for tidx, tokens in enumerate(traces):
        for i in range(len(tokens) - 2):
            state = (tokens[i], tokens[i + 1])
            next_token = tokens[i + 2]
            all_transitions.add((state[0], state[1], next_token))
        curve.append(len(all_transitions))

        if (tidx + 1) % 200 == 0 or tidx == len(traces) - 1:
            print(f"    trace {tidx + 1}/{len(traces)}: {len(all_transitions)} unique transitions")

    # Simple heuristic for "knee": last point where delta > 1.5× avg delta of
    # subsequent window of 50
    deltas = [curve[i] - curve[i - 1] for i in range(1, len(curve))]
    avg_tail = np.mean(deltas[-200:]) if len(deltas) > 200 else np.mean(deltas)
    knee_idx = 0
    for i, d in enumerate(deltas):
        if d < 1.5 * avg_tail:
            knee_idx = i
            break

    return {
        "n_traces": len(traces),
        "total_unique_transitions": len(all_transitions),
        "knee_trace_index": knee_idx,
        "knee_unique_transitions": curve[knee_idx] if knee_idx < len(curve) else 0,
        "curve_data": {"transitions_per_trace": curve},
    }


# =============================================================================
# Subsample stability — rank correlation of top candidates
# =============================================================================

def _build_transition_counts(traces: List[List[str]]) -> Dict[Tuple[str, str], Dict[str, int]]:
    """Build transition counts from a set of traces."""
    counts: Dict[Tuple[str, str], Dict[str, int]] = defaultdict(lambda: defaultdict(int))
    for tokens in traces:
        for i in range(len(tokens) - 2):
            state = (tokens[i], tokens[i + 1])
            next_token = tokens[i + 2]
            counts[state][next_token] += 1
    return dict(counts)


def _compute_2gram_stationary(
    state_keys: List[Tuple[str, str]],
    transition_counts: Dict[Tuple[str, str], Dict[str, int]],
) -> np.ndarray:
    """Power iteration on state-to-state transition matrix built from counts."""
    n = len(state_keys)
    state_to_idx = {s: i for i, s in enumerate(state_keys)}

    # Build sparse adjacency (non-square version: states × next_word)
    rows, cols, data = [], [], []
    for s, next_dict in transition_counts.items():
        if s not in state_to_idx:
            continue
        row = state_to_idx[s]
        for next_word, cnt in next_dict.items():
            # We need a word_id for next_word
            # Store as is; we'll handle projection downstream
            rows.append(row)
            cols.append(0)  # placeholder
            data.append(cnt)

    # Simplified: just use row-degree as π approximation
    degrees = np.zeros(n)
    for s, next_dict in transition_counts.items():
        if s in state_to_idx:
            degrees[state_to_idx[s]] = sum(next_dict.values())

    if degrees.sum() > 0:
        degrees /= degrees.sum()
    return degrees


def _extract_candidates_subsample(
    transition_counts: Dict[Tuple[str, str], Dict[str, int]],
    state_keys: List[Tuple[str, str]],
    word_to_atom: Dict[str, List[Dict[str, Any]]],
) -> List[Tuple[str, str, float]]:
    """Score pairs of atoms that co-occur through the Markov chain."""
    pair_scores: Dict[Tuple[str, str], float] = defaultdict(float)
    pair_traces: Dict[Tuple[str, str], Set[str]] = defaultdict(set)

    for state, next_dict in transition_counts.items():
        s0, s1 = state
        atoms_0 = word_to_atom.get(s0, [])
        atoms_1 = word_to_atom.get(s1, [])

        if not atoms_0 or not atoms_1:
            continue

        for a0 in atoms_0:
            for a1 in atoms_1:
                pair = (a0["atom_id"], a1["atom_id"])
                pair_scores[pair] += sum(next_dict.values())
                pair_traces[pair].add(f"{s0}~{s1}")

    sorted_pairs = sorted(pair_scores.items(), key=lambda x: -x[1])
    return [
        (a, b, score)
        for (a, b), score in sorted_pairs[:50]
    ]


def compute_subsample_stability(
    traces: List[List[str]],
    word_to_atom: Dict[str, List[Dict[str, Any]]],
    n_trials: int = 5,
    fractions: List[float] = [0.5, 0.6, 0.7, 0.8, 0.9],
) -> Dict[str, Any]:
    """Compute candidate rank stability across subsamples."""
    print("  Computing subsample stability...")

    # Full candidate set (ground truth)
    full_counts = _build_transition_counts(traces)
    state_keys = list(full_counts.keys())
    full_candidates = _extract_candidates_subsample(
        full_counts, state_keys, word_to_atom
    )
    full_names = [f"{a}→{b}" for a, b, _ in full_candidates]

    results: Dict[str, Any] = {
        "ground_truth_top50": full_names,
        "subsample_correlations": {},
        "overlap_at_fraction": {},
    }

    for frac in fractions:
        corr_coeffs: List[float] = []
        overlaps: List[float] = []
        n_subsample = max(10, int(len(traces) * frac))

        for trial in range(n_trials):
            sub = random.sample(traces, n_subsample)
            sub_counts = _build_transition_counts(sub)
            sub_candidates = _extract_candidates_subsample(
                sub_counts, state_keys, word_to_atom
            )
            sub_names = [f"{a}→{b}" for a, b, _ in sub_candidates]

            # Rank correlation
            common = set(full_names[:20]) & set(sub_names[:20])
            if len(common) >= 5:
                # Approximate rank correlation: rank in full vs rank in sub
                full_ranks = {n: i for i, n in enumerate(full_names[:20])}
                sub_ranks = {}
                for i, n in enumerate(sub_names[:20]):
                    if n in full_ranks:
                        sub_ranks[n] = i
                if len(sub_ranks) >= 5:
                    x = [full_ranks[k] for k in sub_ranks]
                    y = [sub_ranks[k] for k in sub_ranks]
                    corr, _ = spearmanr(x, y)
                    corr_coeffs.append(corr)

            # Overlap fraction
            if sub_candidates and full_candidates:
                full_top_names = set(full_names[:10])
                sub_top_names = set(n for n, _, _ in sub_candidates[:10])
                overlap = len(full_top_names & sub_top_names) / 10
                overlaps.append(overlap)

        results["subsample_correlations"][f"frac_{frac:.1f}"] = {
            "mean": float(np.mean(corr_coeffs)) if corr_coeffs else 0.0,
            "std": float(np.std(corr_coeffs)) if corr_coeffs else 0.0,
            "n_trials": len(corr_coeffs),
        }
        results["overlap_at_fraction"][f"frac_{frac:.1f}"] = {
            "mean": float(np.mean(overlaps)) if overlaps else 0.0,
            "std": float(np.std(overlaps)) if overlaps else 0.0,
            "n_trials": len(overlaps),
        }

        print(f"    frac={frac:.1f}: rank_corr={results['subsample_correlations'][f'frac_{frac:.1f}']['mean']:.3f} "
              f"overlap={results['overlap_at_fraction'][f'frac_{frac:.1f}']['mean']:.3f}")

    return results


# =============================================================================
# Main
# =============================================================================

def sanitize(text: str) -> str:
    """Lowercase, strip quotes, collapse whitespace."""
    import re
    text = re.sub(r"[\"\']", "", text)
    text = text.lower()
    text = re.sub(r"\s+", " ", text).strip()
    return text


def tokenize(text: str) -> List[str]:
    """Split sanitized text into words, append stop word."""
    words = text.split()
    words.append(STOP)
    return words


def load_traces() -> List[List[str]]:
    """Load and tokenize traces from traces.jsonl (same format as build_markov_poset)."""
    traces: List[List[str]] = []
    with open(TRACES_JSONL) as f:
        for line in f:
            d = json.loads(line)
            text = d.get("thinking_block", "") or ""
            tokens = tokenize(sanitize(text))
            traces.append(tokens)
    print(f"  Loaded {len(traces)} traces from {TRACES_JSONL}")
    return traces


def main():
    print("=" * 80)
    print("M2d — Markov Poset Stability Analysis")
    print("=" * 80)

    # Load traces
    print("\nLoading traces...")
    if not TRACES_JSONL.exists():
        print(f"  ERROR: {TRACES_JSONL} not found. Run build_markov_poset.py first.")
        sys.exit(1)
    traces_list = load_traces()

    # Load word-to-atom match table
    match_path = PROJECT_ROOT / "data" / "nl_to_owl_match.json"
    if match_path.exists():
        with open(match_path) as f:
            word_to_atom = json.load(f)
    else:
        word_to_atom = {}
    print(f"  {len(word_to_atom)} matched words")

    # 1. Knee curve
    knee = compute_knee_curve(traces_list)
    print(f"\n=== KNEE CURVE ===")
    print(f"  Total traces: {knee['n_traces']}")
    print(f"  Unique transitions: {knee['total_unique_transitions']}")
    print(f"  Knee at trace index: {knee['knee_trace_index']}")
    print(f"  Transitions at knee: {knee['knee_unique_transitions']}")

    # 2. Subsample stability
    print(f"\n=== SUBSAMPLE STABILITY ===")
    stability = compute_subsample_stability(traces_list, word_to_atom)

    # Combined
    output = {"knee": knee, "stability": stability}

    # Save
    OUTPUT_PATH.write_text(json.dumps(output, indent=2))
    print(f"\n  Saved: {OUTPUT_PATH}")

    print(f"\n{'=' * 80}")
    print("M2d complete")
    print(f"{'=' * 80}")


if __name__ == "__main__":
    import sys
    main()
