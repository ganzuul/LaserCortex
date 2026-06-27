#!/usr/bin/env python3
"""
M2c — Generate Synthetic OWL Sequences via Markov Chain Walk (redisbot pattern)

Loads the trained Markov poset and NL→OWL match table, then generates new
synthetic reasoning sequences by walking the chain. Each step emits the
matched OWL atoms for the current word — the result is OWL-only sequences
that never reference raw trace text.

The blood-brain barrier is structural: the generator reads only the
transition poset and the match table, not the original traces.

Usage:
    python scripts/generate_synthetic_sequences.py [--n 100] [--max-words 30]
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Dict, List, Tuple

import numpy as np
import scipy.sparse as sp

# ── Paths ──────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CHAIN_MATRIX = PROJECT_ROOT / "data" / "nl_markov_chain_counts.npz"
METADATA_PATH = PROJECT_ROOT / "data" / "nl_markov_metadata.json"
NL_TO_OWL_PATH = PROJECT_ROOT / "data" / "nl_to_owl_match.json"
CANDIDATES_PATH = PROJECT_ROOT / "data" / "reinforcement_candidates.json"
OUTPUT_PATH = PROJECT_ROOT / "data" / "synthetic_owl_sequences.json"

STOP = "\x02"


# =============================================================================
# Load
# =============================================================================

def load():
    count_mat = sp.load_npz(str(CHAIN_MATRIX))
    with open(METADATA_PATH) as f:
        meta = json.load(f)
    vocab: List[str] = meta["vocab"]
    state_keys: List[Tuple[int, int]] = [tuple(s) for s in meta["state_keys"]]
    with open(NL_TO_OWL_PATH) as f:
        word_to_atom = json.load(f)
    return count_mat, vocab, state_keys, word_to_atom


# =============================================================================
# Generator (redisbot pattern)
# =============================================================================

def generate(
    seed_state: Tuple[int, int],
    count_mat: sp.csr_matrix,
    id_to_word: Dict[int, str],
    word_to_atom: Dict[str, List[Dict[str, Any]]],
    state_to_row: Dict[Tuple[int, int], int],
    stop_id: int,
    max_words: int = 30,
) -> List[Dict[str, Any]]:
    """Generate a synthetic sequence from a seed 2-gram state.

    Returns a list of {word, matched_atoms} dicts for each step.
    """
    sequence: List[Dict[str, Any]] = []
    s0, s1 = seed_state

    for step in range(max_words):
        # Emit current state's second word and its OWL atoms
        wj_word = id_to_word.get(s1, "?")
        atoms = word_to_atom.get(wj_word, [])
        sequence.append({
            "step": step,
            "word": wj_word,
            "owl_atoms": atoms,
            "n_atoms": len(atoms),
        })

        # Find the transition set for current state
        state = (s0, s1)
        if state not in state_to_row:
            break
        row_idx = state_to_row[state]
        row = count_mat[row_idx]
        next_choices = row.indices
        next_counts = row.data

        if len(next_choices) == 0:
            break

        # Sample a next word proportional to its observed frequency (redisbot
        # uses SRANDMEMBER for uniform sampling from set; we use weighted
        # sampling from counts which is closer to the true distribution)
        if len(next_choices) == 1:
            next_word_id = next_choices[0]
        else:
            probs = np.array(next_counts, dtype=np.float64)
            probs /= probs.sum()
            next_word_id = int(np.random.choice(next_choices, p=probs))

        if next_word_id == stop_id:
            break

        # Slide the state window
        s0, s1 = s1, next_word_id

    return sequence


def generate_batch(
    count_mat: sp.csr_matrix,
    vocab: List[str],
    state_keys: List[Tuple[int, int]],
    word_to_atom: Dict[str, List[Dict[str, Any]]],
    n_sequences: int = 100,
    max_words: int = 30,
    seed: int = 42,
) -> List[Dict[str, Any]]:
    """Generate multiple synthetic sequences.

    Seeds are drawn from the stationary distribution (approximated by
    degree-weighted sampling from observed start states).
    """
    random.seed(seed)
    np.random.seed(seed)

    word_id = {w: i for i, w in enumerate(vocab)}
    id_to_word = {i: w for w, i in word_id.items()}
    stop_id = word_id.get(STOP, -1)
    state_to_row: Dict[Tuple[int, int], int] = {k: i for i, k in enumerate(state_keys)}

    # Compute row-degree-weighted stationary approximation
    # States with more outgoing transitions are more "central"
    degrees = np.array(count_mat.sum(axis=1)).flatten()
    if degrees.sum() > 0:
        degrees /= degrees.sum()
    else:
        degrees = np.ones(len(state_keys)) / len(state_keys)

    sequences: List[Dict[str, Any]] = []
    for i in range(n_sequences):
        # Pick a seed state weighted by degree
        seed_idx = int(np.random.choice(len(state_keys), p=degrees))
        seed_state = state_keys[seed_idx]

        seq = generate(seed_state, count_mat, id_to_word, word_to_atom,
                       state_to_row, stop_id, max_words)
        sequences.append({
            "sequence_id": f"syn_{i:04d}",
            "n_steps": len(seq),
            "steps": seq,
        })

    return sequences


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(description="Generate synthetic OWL sequences")
    parser.add_argument("--n", type=int, default=100, help="Number of sequences to generate")
    parser.add_argument("--max-words", type=int, default=30, help="Max words per sequence")
    args = parser.parse_args()

    print("=" * 80)
    print("M2c — Generate Synthetic OWL Sequences (redisbot pattern)")
    print("=" * 80)

    print("\nLoading Markov poset...")
    count_mat, vocab, state_keys, word_to_atom = load()
    print(f"  {len(state_keys)} states, {len(vocab)} vocab, {len(word_to_atom)} matched words")

    print(f"\nGenerating {args.n} sequences (max {args.max_words} words each)...")
    sequences = generate_batch(
        count_mat, vocab, state_keys, word_to_atom,
        n_sequences=args.n, max_words=args.max_words,
    )

    # Stats
    n_steps_total = sum(s["n_steps"] for s in sequences)
    n_atoms_total = sum(
        sum(1 for step in s["steps"] if step["n_atoms"] > 0)
        for s in sequences
    )
    print(f"  Generated {len(sequences)} sequences, {n_steps_total} total steps")
    print(f"  Steps with OWL atoms: {n_atoms_total}/{n_steps_total} ({n_atoms_total/n_steps_total*100:.1f}%)")

    # Show sample
    print(f"\nSample sequences:")
    for seq in sequences[:3]:
        words = [s["word"] for s in seq["steps"]]
        word_str = " ".join(words[:10])
        if len(words) > 10:
            word_str += "..."
        atom_ids = list(set(
            a["atom_id"] for s in seq["steps"] for a in s["owl_atoms"]
        ))
        atom_str = ", ".join(atom_ids[:8])
        if len(atom_ids) > 8:
            atom_str += "..."
        print(f"  {seq['sequence_id']}: {word_str}")
        print(f"    atoms ({len(atom_ids)}): {atom_str}")

    # Save
    output = {
        "metadata": {
            "n_sequences": args.n,
            "max_words": args.max_words,
            "seed": 42,
            "method": "redisbot-style Markov chain walk with weighted sampling",
        },
        "sequences": sequences,
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2))
    print(f"\n  Saved: {OUTPUT_PATH}")

    print(f"\n{'=' * 80}")
    print("M2c complete")
    print(f"{'=' * 80}")


if __name__ == "__main__":
    main()
