#!/usr/bin/env python3
"""
M2b — Analyze Markov Poset, Discover Reinforcement Candidates

Steps:
  1. Compute stationary distribution of the NL Markov chain.
  2. Walk each trace's start state through the chain, recording matched
     OWL atoms → frequent subsequences = candidate reinforcement types.
  3. Compute OWL stationary distribution (projection through NL→OWL table).
  4. Print summary report.

Usage:
    python scripts/analyze_markov_poset.py
"""

from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

import numpy as np
import scipy.sparse as sp
from scipy.sparse.linalg import eigsh

# ── Paths ──────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRACES_PATH = PROJECT_ROOT / "reasoning_library" / "traces.jsonl"
CHAIN_MATRIX = PROJECT_ROOT / "data" / "nl_markov_chain_counts.npz"
METADATA_PATH = PROJECT_ROOT / "data" / "nl_markov_metadata.json"
NL_TO_OWL_PATH = PROJECT_ROOT / "data" / "nl_to_owl_match.json"
STATS_PATH = PROJECT_ROOT / "data" / "markov_poset_stats.json"

OUTPUT_DIR = PROJECT_ROOT / "data"
STOP = "\x02"
MIN_SUBSEQ_SUPPORT = 2   # minimum traces a subsequence must appear in
MAX_CANDIDATES = 50      # maximum reinforcement candidates to report


# =============================================================================
# Load
# =============================================================================

def load_data() -> Tuple[
    sp.csr_matrix,   # weighted transition matrix
    List[str],       # vocabulary
    List[Tuple[int, int]],  # state_keys: (word_id, word_id) per row
    Dict[str, List[Dict[str, Any]]],  # word → matched atoms
    Dict[str, Any],  # stats
]:
    count_mat = sp.load_npz(str(CHAIN_MATRIX))
    print(f"  Transition matrix: {count_mat.shape}, nnz={count_mat.nnz}")

    with open(METADATA_PATH) as f:
        meta = json.load(f)
    vocab: List[str] = meta["vocab"]
    state_keys: List[Tuple[int, int]] = [tuple(s) for s in meta["state_keys"]]
    print(f"  Vocabulary: {len(vocab)} words")
    print(f"  States: {len(state_keys)}")

    with open(NL_TO_OWL_PATH) as f:
        word_to_atom = json.load(f)
    print(f"  NL→OWL matches: {len(word_to_atom)} words")

    with open(STATS_PATH) as f:
        stats = json.load(f)

    return count_mat, vocab, state_keys, word_to_atom, stats


# =============================================================================
# Stationary distribution
# =============================================================================

def build_square_transition(
    state_keys: List[Tuple[int, int]],
    vocab: List[str],
    word_to_atom: Dict[str, List[Dict[str, Any]]],
    count_mat: sp.csr_matrix,
) -> sp.csr_matrix:
    """Build square state-to-state transition matrix.

    The existing matrix P is (n_states × n_vocab): P(next_word | (w_i,w_{i+1})).
    A proper Markov chain on 2-gram states needs a square matrix
    Q of shape (n_states × n_states): P((w_{i+1},w_{i+2}) | (w_i,w_{i+1})).

    We derive Q from P by mapping each observed (state → next_word) to
    (state → next_state) where next_state = (w_{i+1}, next_word).
    """
    n_states = len(state_keys)
    n_vocab = len(vocab)
    word_id = {w: i for i, w in enumerate(vocab)}

    # Build next_state lookup: for each (w_j, next_word) → state_index
    # This is the inverse of state_keys: we can build a dict from the key list
    next_state_map: Dict[Tuple[int, int], int] = {k: i for i, k in enumerate(state_keys)}

    # For each state, we need to find which next_words produce a valid next state
    row_indices: List[int] = []
    col_indices: List[int] = []
    values: List[float] = []

    # Also rebuild from corpus for count accuracy
    from collections import defaultdict
    state_transition_counts: Dict[int, Dict[int, int]] = defaultdict(lambda: defaultdict(int))

    id_to_word = {i: w for w, i in word_id.items()}

    for state_idx, (wi, wj) in enumerate(state_keys):
        # Get all next words for this state
        row = count_mat[state_idx]
        next_indices = row.indices
        next_counts = row.data

        for n_vocab_idx, cnt in zip(next_indices, next_counts):
            next_word = id_to_word[n_vocab_idx]
            next_state = (wj, n_vocab_idx)
            if next_state in next_state_map:
                next_state_idx = next_state_map[next_state]
                state_transition_counts[state_idx][next_state_idx] += int(cnt)

    if not state_transition_counts:
        print("  Warning: no state transitions found, using identity")
        return sp.eye(n_states, format="csr", dtype=np.float32)

    for s_idx, nexts in state_transition_counts.items():
        for ns_idx, cnt in nexts.items():
            row_indices.append(s_idx)
            col_indices.append(ns_idx)
            values.append(float(cnt))

    Q = sp.csr_matrix(
        (values, (row_indices, col_indices)),
        shape=(n_states, n_states),
        dtype=np.float32,
    )
    print(f"  Square transition matrix: {Q.shape}, nnz={Q.nnz}, "
          f"density={Q.nnz / (n_states * n_states):.8f}")
    return Q


def stationary_distribution(Q: sp.csr_matrix) -> np.ndarray:
    """Compute stationary distribution π of square transition matrix Q.

    Q is row-stochastic (rows sum to 1). π satisfies π·Q = π.
    Uses power iteration (scalable to 77K states).
    """
    n = Q.shape[0]
    assert Q.shape[0] == Q.shape[1], f"Q must be square, got {Q.shape}"

    # Row-normalize
    row_sums = np.array(Q.sum(axis=1)).flatten()
    row_sums[row_sums == 0] = 1.0
    Q_norm = Q.multiply(sp.csr_matrix(1.0 / row_sums).T)

    # Power iteration: π_{t+1} = π_t · Q_norm
    pi = np.ones(n) / n
    for it in range(200):
        pi_next = pi @ Q_norm  # row vector × matrix
        pi_next /= pi_next.sum()
        delta = np.linalg.norm(pi_next - pi)
        if delta < 1e-12:
            print(f"  Converged in {it+1} iterations")
            break
        pi = pi_next
    else:
        print(f"  Reached max iterations, delta={delta:.2e}")

    return pi


# =============================================================================
# Frequent subsequence mining
# =============================================================================

def extract_trace_sequences(
    count_mat: sp.csr_matrix,
    state_keys: List[Tuple[int, int]],
    vocab: List[str],
    word_to_atom: Dict[str, List[Dict[str, Any]]],
    stats: Dict[str, Any],
) -> Dict[str, Any]:
    """Walk each trace's start state through the chain, record OWL sequences.

    Returns a dict of candidate reinforcement types keyed by OWL atom
    subsequence string.
    """
    word_id = {w: i for i, w in enumerate(vocab)}
    # Build reverse lookup: word_id → word
    id_to_word = {i: w for w, i in word_id.items()}
    stop_id = word_id.get(STOP, -1)
    # Build state_key → row index
    state_to_row: Dict[Tuple[int, int], int] = {k: i for i, k in enumerate(state_keys)}

    # Load traces (need them again for start states)
    texts: List[str] = []
    with open(TRACES_PATH) as f:
        for line in f:
            d = json.loads(line)
            texts.append(d.get("thinking_block", "") or "")

    # For each trace, walk the chain
    candidate_counts: Counter = Counter()  # "atom1 atom2 ..." → count
    candidate_traces: Dict[str, Set[int]] = defaultdict(set)
    candidate_ontology_sources: Dict[str, Set[str]] = defaultdict(set)

    trace_support = 0
    n_total_atoms = 0

    for t_idx, text in enumerate(texts):
        # Tokenize (same as build_markov_poset)
        words = text.lower().split()
        words.append(STOP)

        if len(words) < 3:
            continue

        # Find start state (first 2-gram)
        w0, w1 = words[0], words[1]
        if w0 not in word_id or w1 not in word_id:
            continue
        s0, s1 = word_id[w0], word_id[w1]
        state = (s0, s1)
        if state not in state_to_row:
            continue

        # Walk the chain, collecting OWL atoms per position
        sequence_atoms: List[List[Dict[str, Any]]] = []  # per position

        # Collect first two words' atoms
        for pos in range(2):
            w = words[pos]
            if w in word_to_atom:
                sequence_atoms.append(word_to_atom[w])
            else:
                sequence_atoms.append([])

        row = state_to_row[state]
        for step in range(200):  # max steps to prevent infinite loops
            # Read the row from the matrix
            transitions = count_mat[row]
            next_choices = transitions.indices
            next_vals = transitions.data

            if len(next_choices) == 0:
                break

            # Greedy: pick the most frequent next word
            best_idx = np.argmax(next_vals)
            next_word_id = next_choices[best_idx]
            next_word = id_to_word[next_word_id]

            if next_word_id == stop_id:
                break

            # Record OWL atoms for this word
            if next_word in word_to_atom:
                sequence_atoms.append(word_to_atom[next_word])
            else:
                sequence_atoms.append([])

            # Slide the state
            s0, s1 = s1, next_word_id
            state = (s0, s1)
            if state not in state_to_row:
                break
            row = state_to_row[state]

        # Now extract all OWL subsequences of length 2+ that have ≥2 ontology sources
        n_atoms_this = sum(1 for atoms in sequence_atoms if atoms)
        n_total_atoms += n_atoms_this
        if n_atoms_this < 2:
            continue
        trace_support += 1

        # For each pair of positions, build a subsequence
        for i in range(len(sequence_atoms)):
            for j in range(i + 1, len(sequence_atoms)):
                atoms_i = sequence_atoms[i]
                atoms_j = sequence_atoms[j]
                if not atoms_i or not atoms_j:
                    continue

                # Build cross-product of OWL pairs
                for a_i in atoms_i:
                    aid_i = a_i["atom_id"]
                    src_i = a_i["source"]
                    for a_j in atoms_j:
                        aid_j = a_j["atom_id"]
                        src_j = a_j["source"]
                        if src_i == src_j:
                            continue  # same ontology — not a cross-ontology pair

                        # Build subsequence key
                        key = f"{aid_i} → {aid_j}"
                        candidate_counts[key] += 1
                        candidate_traces[key].add(t_idx)
                        candidate_ontology_sources[key].add(src_i)
                        candidate_ontology_sources[key].add(src_j)

    # Filter and rank candidates
    candidates = []
    for key, count in candidate_counts.items():
        n_traces = len(candidate_traces[key])
        if n_traces < MIN_SUBSEQ_SUPPORT:
            continue
        sources = candidate_ontology_sources[key]
        if len(sources) < 2:
            continue

        candidates.append({
            "owl_subsequence": key,
            "n_traces": n_traces,
            "n_occurrences": count,
            "ontology_sources": sorted(sources),
        })

    candidates.sort(key=lambda c: (-c["n_traces"], -c["n_occurrences"]))

    result = {
        "n_traces_analyzed": len(texts),
        "n_traces_with_atom_sequences": trace_support,
        "n_total_atom_hits": n_total_atoms,
        "n_candidates": len(candidates),
        "candidates": candidates[:MAX_CANDIDATES],
    }

    print(f"  Traces with ≥2 OWL atoms: {trace_support}/{len(texts)}")
    print(f"  Total OWL atom hits: {n_total_atoms}")
    print(f"  Candidate reinforcement types: {len(candidates)}")
    print(f"  Showing top {min(MAX_CANDIDATES, len(candidates))}:")
    print()
    for i, c in enumerate(candidates[:10]):
        print(f"    {i+1:2d}. [{c['n_traces']:3d} traces, {c['n_occurrences']:4d} occ] "
              f"{c['owl_subsequence']}")
        print(f"         sources: {', '.join(c['ontology_sources'])}")

    return result


# =============================================================================
# OWL stationary distribution
# =============================================================================

def compute_owl_stationary(
    pi: np.ndarray,
    state_keys: List[Tuple[int, int]],
    vocab: List[str],
    word_to_atom: Dict[str, List[Dict[str, Any]]],
) -> Dict[str, float]:
    """Project NL stationary distribution through the NL→OWL match table.

    For each state (w_i, w_j), the stationary probability π[state] tells us
    the long-run probability of being at that 2-gram. The OWL atoms matched
    to w_j get a share of that probability.

    Returns: {atom_id: probability}
    """
    atom_prob: Dict[str, float] = defaultdict(float)
    id_to_word = {i: w for w, i in {w: i for i, w in enumerate(vocab)}.items()}

    for state_idx, (wi_id, wj_id) in enumerate(state_keys):
        prob = pi[state_idx]
        if prob < 1e-10:
            continue

        wj = id_to_word.get(wj_id, "")
        if not wj or wj not in word_to_atom:
            continue

        # Distribute state probability equally among matched atoms
        atoms = word_to_atom[wj]
        share = prob / len(atoms)
        for a in atoms:
            atom_prob[a["atom_id"]] += share

    # Sort
    sorted_atoms = sorted(atom_prob.items(), key=lambda x: -x[1])
    print(f"\n  OWL stationary distribution: {len(sorted_atoms)} atoms with non-zero prob")

    owl_stat = {
        "top_owl_atoms": [
            {"atom_id": aid, "stationary_prob": float(round(p, 8))}
            for aid, p in sorted_atoms[:20]
        ],
        "n_atoms": len(sorted_atoms),
    }

    print(f"  Top OWL atoms at stationary:")
    for i, entry in enumerate(owl_stat["top_owl_atoms"][:8]):
        print(f"    {i+1:2d}. P={entry['stationary_prob']:.8f}  {entry['atom_id']}")

    return owl_stat


# =============================================================================
# Print report
# =============================================================================

def print_report(
    pi: np.ndarray,
    state_keys: List[Tuple[int, int]],
    vocab: List[str],
    stats: Dict[str, Any],
):
    """Print overall report."""
    id_to_word = {i: w for w, i in {w: i for i, w in enumerate(vocab)}.items()}

    print(f"\n{'='*100}")
    print("MARKOV POSET ANALYSIS REPORT")
    print(f"{'='*100}")

    print(f"\nChain statistics:")
    print(f"  Traces:            {stats.get('n_traces', '?')}")
    print(f"  Vocabulary size:   {stats.get('vocab_size', '?')}")
    print(f"  States (2-grams):  {stats.get('n_states', '?')}")
    print(f"  Transitions:       {stats.get('n_transition_pairs', '?')}")
    print(f"  Density:           {stats.get('density', '?'):.6f}")
    print(f"  Words w/ OWL:      {stats.get('words_with_owl_matches', '?')}")

    # Top stationary states
    top_n = min(10, len(pi))
    top_indices = np.argsort(-pi)[:top_n]
    print(f"\nTop {top_n} stationary states (2-grams with highest π):")
    print(f"  {'State (2-gram)':<40s} {'π':>12s}")
    print(f"  {'─'*40} {'─'*12}")
    for idx in top_indices:
        wi, wj = state_keys[idx]
        w_i_word = id_to_word.get(wi, "?")
        w_j_word = id_to_word.get(wj, "?")
        print(f"  '{w_i_word} → {w_j_word}'{'':<20s} {pi[idx]:12.8f}")

    # State entropy
    nonzero_pi = pi[pi > 1e-12]
    entropy = -np.sum(nonzero_pi * np.log2(nonzero_pi))
    max_entropy = np.log2(len(pi))
    print(f"\n  Stationary entropy:  {entropy:.4f} bits (of {max_entropy:.1f} max)")
    print(f"  Normalized entropy:  {entropy / max_entropy:.4f}")


# =============================================================================
# Main
# =============================================================================

def main():
    print("=" * 80)
    print("M2b — Analyze Markov Poset")
    print("=" * 80)

    # Load
    print("\nLoading data...")
    count_mat, vocab, state_keys, word_to_atom, stats = load_data()

    # Build square state-to-state transition matrix
    print("\nBuilding square state transition matrix...")
    Q = build_square_transition(state_keys, vocab, word_to_atom, count_mat)

    # Stationary distribution
    print("\nComputing stationary distribution...")
    pi = stationary_distribution(Q)
    print(f"  Done. π min={pi.min():.2e}, max={pi.max():.2e}, "
          f"sum={pi.sum():.6f}, nonzero={np.count_nonzero(pi > 1e-12)}")

    # Print report
    print_report(pi, state_keys, vocab, stats)

    # Discover candidates
    print("\nMining candidate reinforcement types...")
    candidates_result = extract_trace_sequences(
        count_mat, state_keys, vocab, word_to_atom, stats
    )

    # OWL stationary distribution
    print("\nProjecting OWL stationary distribution...")
    owl_stat = compute_owl_stationary(pi, state_keys, vocab, word_to_atom)

    # Save
    print("\nSaving...")
    with open(OUTPUT_DIR / "reinforcement_candidates.json", "w") as f:
        json.dump(candidates_result, f, indent=2)
    print(f"  Saved: reinforcement_candidates.json ({candidates_result['n_candidates']} candidates)")

    with open(OUTPUT_DIR / "owl_stationary_distribution.json", "w") as f:
        json.dump(owl_stat, f, indent=2)
    print(f"  Saved: owl_stationary_distribution.json")

    print(f"\n{'=' * 80}")
    print("M2b complete")
    print(f"{'=' * 80}")


if __name__ == "__main__":
    main()
