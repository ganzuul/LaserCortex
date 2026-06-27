#!/usr/bin/env python3
"""
M2a — Build Markov Poset from Trace Thinking Blocks (redisbot pattern)

For each trace's thinking block:
  1. Sanitize: lowercase, strip punctuation, tokenize into words.
  2. Append stop word \\x02.
  3. Record 2-gram transitions: (w_i, w_{i+1}) → w_{i+2} as a SET (the poset).
  4. Look up matched OWL atoms for each word from the cleaned word→atom index.

Output:
  - data/nl_markov_chain.npz     — sparse binary transition matrix
  - data/nl_markov_metadata.json — vocabulary, state map, stats
  - data/nl_to_owl_match.json    — word → list of OWL atom IDs (label+verb_member only)
  - data/markov_poset_stats.json — summary: unique states, transitions, sparsity

Usage:
    python scripts/build_markov_poset.py
"""

from __future__ import annotations

import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

import numpy as np
import scipy.sparse as sp

# ── Paths ──────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRACES_PATH = PROJECT_ROOT / "reasoning_library" / "traces.jsonl"
ATOMS_PATH = PROJECT_ROOT / "data" / "reinforcement_atoms.json"
CORRESPONDENCE_PATH = PROJECT_ROOT / "data" / "owl_correspondence.json"
OUTPUT_DIR = PROJECT_ROOT / "data"

STOP = "\x02"
CHAIN_LENGTH = 2  # N for N-gram Markov chain


# =============================================================================
# Load data
# =============================================================================

def load_traces() -> List[str]:
    """Load thinking blocks from traces.jsonl."""
    texts: List[str] = []
    with open(TRACES_PATH) as f:
        for line in f:
            d = json.loads(line)
            text = d.get("thinking_block", "") or ""
            texts.append(text)
    print(f"  Loaded {len(texts)} traces")
    return texts


def build_word_to_atom_index() -> Dict[str, List[Dict[str, Any]]]:
    """Build cleaned word→atom index from correspondence data.

    Only includes label and verb_member match types (not description).
    Returns {word_lower: [{atom_id, source, cd_step, match_type}, ...]}.
    """
    with open(CORRESPONDENCE_PATH) as f:
        corr_data = json.load(f)

    index: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    seen: Set[Tuple[str, str, str]] = set()  # (word, atom_id, match_type) dedup

    for tr in corr_data["trace_results"]:
        for c in tr["correspondences"]:
            if c["match_type"] not in ("label", "verb_member"):
                continue
            word = c["nl_word"]
            key = (word, c["atom_id"], c["match_type"])
            if key not in seen:
                seen.add(key)
                index[word].append({
                    "atom_id": c["atom_id"],
                    "source": c["source"],
                    "cd_step": c["cd_step"],
                    "match_type": c["match_type"],
                })

    n_words = len(index)
    n_matches = sum(len(v) for v in index.values())
    print(f"  Word→atom index: {n_words} words → {n_matches} matches (label+verb_member only)")
    return dict(index)


# =============================================================================
# Tokenization and sanitization
# =============================================================================

def sanitize(text: str) -> str:
    """Lowercase, strip quotes, collapse whitespace. (redisbot sanitize_message)"""
    text = re.sub(r"[\"\']", "", text)
    text = text.lower()
    text = re.sub(r"\s+", " ", text).strip()
    return text


def tokenize(text: str) -> List[str]:
    """Split sanitized text into words, append stop word."""
    words = text.split()
    words.append(STOP)
    return words


# =============================================================================
# Build Markov poset
# =============================================================================

def build_transition_poset(
    texts: List[str],
    word_to_atom: Dict[str, List[Dict[str, Any]]],
) -> Tuple[
    sp.csr_matrix,         # binary transition matrix (states × next_words)
    sp.csr_matrix,         # weighted transition matrix (counts)
    List[str],             # vocabulary (word → index)
    Dict[Tuple[int, int], int],  # state (w_i, w_j) → state index
    Dict[str, List[Dict[str, Any]]],  # cleaned word→atom index
    Dict[str, Any],        # stats
]:
    """Build the Markov chain poset from trace thinking blocks.

    Returns:
        trans_mat: sparse binary matrix, shape (n_states, n_vocab)
        vocab: word list where index = word_id
        state_map: (w_id, w_id) → state_row
        word_to_atom_used: subset of word_to_atom that actually appears
        stats: summary dict
    """
    # First pass: collect all unique words (vocabulary) and 2-gram states
    word_set: Set[str] = set()
    for text in texts:
        words = tokenize(sanitize(text))
        word_set.update(words)

    vocab = sorted(word_set)
    word_to_id: Dict[str, int] = {w: i for i, w in enumerate(vocab)}
    n_vocab = len(vocab)
    print(f"  Vocabulary size: {n_vocab}")

    # Collect 2-gram states and transitions
    state_set: Set[Tuple[int, int]] = set()
    transition_set: Dict[Tuple[int, int], Set[int]] = defaultdict(set)  # state → {next_word_ids}
    word_match_hits: Set[str] = set()

    for text in texts:
        words = tokenize(sanitize(text))

        # 2-gram Markov: for each position i, state = (w_i, w_{i+1}), next = w_{i+2}
        for i in range(len(words) - CHAIN_LENGTH):
            w0 = words[i]
            w1 = words[i + 1]
            w2 = words[i + 2]

            if w0 not in word_to_id or w1 not in word_to_id or w2 not in word_to_id:
                continue  # should not happen since we built vocab from all words

            s0 = word_to_id[w0]
            s1 = word_to_id[w1]
            nxt = word_to_id[w2]

            state_set.add((s0, s1))
            transition_set[(s0, s1)].add(nxt)

            # Track which words have OWL matches
            if w0 in word_to_atom:
                word_match_hits.add(w0)
            if w1 in word_to_atom:
                word_match_hits.add(w1)
            if w2 in word_to_atom:
                word_match_hits.add(w2)

    n_states = len(state_set)
    states_list = sorted(state_set)
    state_map: Dict[Tuple[int, int], int] = {s: i for i, s in enumerate(states_list)}
    print(f"  2-gram states: {n_states}")

    # Build sparse binary transition matrix (states × vocab)
    row_indices: List[int] = []
    col_indices: List[int] = []
    for state, next_words in transition_set.items():
        row = state_map[state]
        for nxt in next_words:
            row_indices.append(row)
            col_indices.append(nxt)

    trans_mat = sp.csr_matrix(
        (np.ones(len(row_indices), dtype=np.float32), (row_indices, col_indices)),
        shape=(n_states, n_vocab),
        dtype=np.float32,
    )
    # Also store counts version (weighted)
    count_mat = sp.csr_matrix(
        (np.ones(len(row_indices), dtype=np.float32), (row_indices, col_indices)),
        shape=(n_states, n_vocab),
        dtype=np.float32,
    )
    # For counts: duplicate entries from defaultdict(set) are already unique
    # We need to count frequency, so let's rebuild
    count_dict: Dict[Tuple[int, int], Dict[int, int]] = defaultdict(lambda: defaultdict(int))
    for text in texts:
        words = tokenize(sanitize(text))
        for i in range(len(words) - CHAIN_LENGTH):
            w0, w1, w2 = words[i], words[i+1], words[i+2]
            s0, s1, nxt = word_to_id[w0], word_to_id[w1], word_to_id[w2]
            count_dict[(s0, s1)][nxt] += 1

    count_rows: List[int] = []
    count_cols: List[int] = []
    count_vals: List[float] = []
    for state, next_counts in count_dict.items():
        row = state_map[state]
        for nxt, cnt in next_counts.items():
            count_rows.append(row)
            count_cols.append(nxt)
            count_vals.append(float(cnt))

    count_mat = sp.csr_matrix(
        (count_vals, (count_rows, count_cols)),
        shape=(n_states, n_vocab),
        dtype=np.float32,
    )

    density = trans_mat.nnz / (n_states * n_vocab)
    stats = {
        "n_traces": len(texts),
        "vocab_size": n_vocab,
        "n_states": n_states,
        "n_transition_pairs": trans_mat.nnz,
        "density": float(density),
        "chain_length": CHAIN_LENGTH,
        "words_with_owl_matches": len(word_match_hits),
        "total_word_occurrences": sum(len(tokenize(sanitize(t))) - 1 for t in texts),  # minus stop
    }
    print(f"  Transition pairs: {trans_mat.nnz}")
    print(f"  Density: {density:.6f}")
    print(f"  Words with OWL matches: {len(word_match_hits)}")
    print(f"  Total word occurrences: {stats['total_word_occurrences']}")

    # Filter word→atom index to only words that appear in traces
    word_to_atom_used: Dict[str, List[Dict[str, Any]]] = {
        w: word_to_atom[w] for w in word_match_hits
    }

    return trans_mat, count_mat, vocab, state_map, word_to_atom_used, stats


# =============================================================================
# Save
# =============================================================================

def save_outputs(
    trans_mat: sp.csr_matrix,
    count_mat: sp.csr_matrix,
    vocab: List[str],
    state_map: Dict[Tuple[int, int], int],
    word_to_atom: Dict[str, List[Dict[str, Any]]],
    stats: Dict[str, Any],
) -> None:
    """Save all artifacts to data/."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Sparse transition matrix
    sp.save_npz(OUTPUT_DIR / "nl_markov_chain.npz", trans_mat)
    sp.save_npz(OUTPUT_DIR / "nl_markov_chain_counts.npz", count_mat)

    # Metadata (serializable version of state_map)
    state_list = [(int(s0), int(s1)) for (s0, s1) in state_map]
    metadata = {
        "vocab": vocab,
        "state_keys": state_list,
        "n_states": len(state_list),
        "n_vocab": len(vocab),
        "chain_length": CHAIN_LENGTH,
        "stop_word": STOP,
    }
    with open(OUTPUT_DIR / "nl_markov_metadata.json", "w") as f:
        json.dump(metadata, f)
    print(f"  Saved: nl_markov_metadata.json ({len(state_list)} states)")

    # NL→OWL match table (word → list of atom match dicts)
    with open(OUTPUT_DIR / "nl_to_owl_match.json", "w") as f:
        json.dump(word_to_atom, f, indent=2)
    print(f"  Saved: nl_to_owl_match.json ({len(word_to_atom)} words)")

    # Stats
    with open(OUTPUT_DIR / "markov_poset_stats.json", "w") as f:
        json.dump(stats, f, indent=2)
    print(f"  Saved: markov_poset_stats.json")

    print(f"\n  Output directory: {OUTPUT_DIR}")


# =============================================================================
# Main
# =============================================================================

def main():
    print("=" * 80)
    print("M2a — Build Markov Poset")
    print("=" * 80)

    # Load
    print("\nLoading traces...")
    texts = load_traces()

    print("\nBuilding cleaned word→atom index (label+verb_member only)...")
    word_to_atom = build_word_to_atom_index()

    # Build poset
    print("\nBuilding 2-gram Markov poset...")
    trans_mat, count_mat, vocab, state_map, word_to_atom_used, stats = \
        build_transition_poset(texts, word_to_atom)

    # Save
    print("\nSaving outputs...")
    save_outputs(trans_mat, count_mat, vocab, state_map, word_to_atom_used, stats)

    print(f"\n{'=' * 80}")
    print("M2a complete")
    print(f"{'=' * 80}")


if __name__ == "__main__":
    main()
