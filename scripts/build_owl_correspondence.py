#!/usr/bin/env python3
"""
Build OWL Correspondence Table from Real M0/M1 Data

This script loads the actual OWL ontology atoms (from M0 bootstrap) and matches
them to individual NL words from reasoning traces. A "paradox candidate" is an
NL word that matches OWL atoms from BOTH CD:2 (associative) AND CD:3
(non-associative) ontology sources — it straddles the boundary.

The blood-brain barrier principle:
  BRAIN  = OWL ontology atoms (framenet, verbnet, manpage, prov-o, p-plan)
  BLOOD  = Natural language words from reasoning traces
  BARRIER = Exact/lemmatized match between NL word and atom label/verb member

Usage:
    python scripts/build_owl_correspondence.py
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Set

import numpy as np
import scipy.sparse as sp

# ── Paths ──────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
ATOMS_PATH = PROJECT_ROOT / "data" / "reinforcement_atoms.json"
TRACES_PATH = PROJECT_ROOT / "reasoning_library" / "traces.jsonl"
OUTPUT_PATH = PROJECT_ROOT / "data" / "owl_correspondence.json"

# ── CD step per source ─────────────────────────────────────────────────────
SOURCE_CD: Dict[str, int] = {
    "framenet": 2,   # associative (ManyValued)
    "verbnet": 3,    # non-associative (Quantum)
    "manpage": 2,    # associative (ManyValued)
    "prov-o": 3,     # non-associative (Quantum)
    "p-plan": 3,     # non-associative (Quantum)
}


# =============================================================================
# Load data
# =============================================================================

def load_atoms() -> Tuple[List[Dict[str, Any]], Dict[str, int], Dict[str, int]]:
    """Load atoms from M0 output. Returns (atoms, atom_id→cd_step, atom_id→source)."""
    with open(ATOMS_PATH) as f:
        data = json.load(f)
    atoms = data["atoms"]
    atom_cd: Dict[str, int] = {}
    atom_source: Dict[str, int] = {}
    for a in atoms:
        aid = a["atom_id"]
        src = a["source"]
        atom_cd[aid] = SOURCE_CD.get(src, 3)
        atom_source[aid] = src
    print(f"  Loaded {len(atoms)} atoms from {ATOMS_PATH.name}")
    return atoms, atom_cd, atom_source


def load_traces() -> Tuple[List[str], List[str]]:
    """Load traces. Returns (trace_texts, trace_ids)."""
    texts: List[str] = []
    ids: List[str] = []
    with open(TRACES_PATH) as f:
        for i, line in enumerate(f):
            d = json.loads(line)
            text = d.get("thinking_block", "") or ""
            texts.append(text)
            ids.append(f"trace_{i:04d}")
    print(f"  Loaded {len(texts)} traces from {TRACES_PATH.name}")
    return texts, ids


# =============================================================================
# Build word-to-atom index
# =============================================================================

def tokenize(text: str) -> Set[str]:
    """Extract lowercase words from text."""
    words = re.findall(r"[a-zA-Z_][a-zA-Z0-9_]{2,}", text)
    return {w.lower() for w in words}


def build_atom_index(atoms: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    """Build a word→atom lookup index.

    For each atom, we index:
    - The atom's label (lowered)
    - For verbnet atoms: each verb member (from aliases)
    - The atom's description (common nouns/verbs)
    - Key CamelCase terms that match this atom
    """
    index: Dict[str, List[Dict[str, Any]]] = defaultdict(list)

    for a in atoms:
        aid = a["atom_id"]
        src = a["source"]
        label = a.get("label", "").lower()
        aliases = [al.lower() for al in a.get("aliases", [])]
        description = a.get("description", "").lower()
        atom_type = a.get("atom_type", "")

        # Index the label itself (for exact match)
        # e.g. "frame_Closure" → "Closure", "frame_Aggregate" → "Aggregate"
        label_parts = re.findall(r"[a-z]+", label)
        for part in label_parts:
            if len(part) >= 3:
                index[part].append({"atom_id": aid, "source": src, "match_type": "label", "term": part})

        # Index verbnet verb members from aliases
        if src == "verbnet":
            for alias in aliases:
                if len(alias) >= 3:
                    index[alias].append({"atom_id": aid, "source": src, "match_type": "verb_member", "term": alias})

        # Index description: extract notable words
        desc_words = re.findall(r"[a-z]{4,}", description)
        notable = {"concept", "action", "process", "state", "entity",
                    "activity", "event", "relation", "agent", "object",
                    "reserve", "guard", "market", "close", "certify", "path",
                    "logic", "contract", "translate", "react", "shift",
                    "norm", "check", "blame", "pool", "concrete"}
        for w in desc_words:
            if w in notable:
                index[w].append({"atom_id": aid, "source": src, "match_type": "description", "term": w})

    # Deduplicate
    result: Dict[str, List[Dict[str, Any]]] = {}
    for word, entries in index.items():
        seen = set()
        unique = []
        for e in entries:
            key = (e["atom_id"], e["match_type"])
            if key not in seen:
                seen.add(key)
                unique.append(e)
        result[word] = unique

    print(f"  Built word→atom index: {len(result)} unique words → {sum(len(v) for v in result.values())} matches")
    return result


# =============================================================================
# Process traces
# =============================================================================

def process_traces(
    trace_texts: List[str],
    trace_ids: List[str],
    atom_index: Dict[str, List[Dict[str, Any]]],
    atoms: List[Dict[str, Any]],
    atom_cd: Dict[str, int],
) -> Dict[str, Any]:
    """Process all traces and build the correspondence table."""
    # Build atom_id → source lookup
    atom_source_map: Dict[str, str] = {}
    for a in atoms:
        atom_source_map[a["atom_id"]] = a["source"]

    trace_results: List[Dict[str, Any]] = []
    all_correspondences: List[Dict[str, Any]] = []
    paradox_candidates: List[Dict[str, Any]] = []

    # Global stats
    cd2_word_counts: Counter = Counter()
    cd3_word_counts: Counter = Counter()
    cd2_traces = 0
    cd3_traces = 0
    both_traces = 0
    neither_traces = 0

    for t_idx, text in enumerate(trace_texts):
        words = tokenize(text)

        # For each word, find matching atoms
        word_matches: Dict[str, List[Dict[str, Any]]] = {}
        for w in words:
            if w in atom_index:
                word_matches[w] = atom_index[w]

        if not word_matches:
            neither_traces += 1
            continue

        # Classify matched atoms by CD step
        matched_atoms_by_word: Dict[str, Dict[str, Any]] = {}
        cd2_flag = False
        cd3_flag = False

        correspondences = []
        for word, matches in word_matches.items():
            for m in matches:
                aid = m["atom_id"]
                cd = atom_cd.get(aid, 3)
                if cd == 2:
                    cd2_flag = True
                else:
                    cd3_flag = True
                correspondences.append({
                    "nl_word": word,
                    "atom_id": aid,
                    "source": m["source"],
                    "cd_step": cd,
                    "match_type": m["match_type"],
                    "term": m["term"],
                })

        if cd2_flag:
            cd2_traces += 1
        if cd3_flag:
            cd3_traces += 1
        if cd2_flag and cd3_flag:
            both_traces += 1
        elif not cd2_flag and not cd3_flag:
            neither_traces += 1

        all_correspondences.extend(correspondences)

        tr = {
            "trace_id": trace_ids[t_idx],
            "trace_preview": text[:120],
            "n_words": len(words),
            "n_matched_words": len(word_matches),
            "cd2": cd2_flag,
            "cd3": cd3_flag,
            "is_paradox": cd2_flag and cd3_flag,
            "correspondences": correspondences,
        }
        trace_results.append(tr)

        if cd2_flag and cd3_flag:
            # This is a paradox candidate - extract the specific words
            cd2_words = set()
            cd3_words = set()
            for c in correspondences:
                if c["cd_step"] == 2:
                    cd2_words.add(c["nl_word"])
                else:
                    cd3_words.add(c["nl_word"])
            paradox_candidates.append({
                "trace_id": trace_ids[t_idx],
                "trace_preview": text[:200],
                "cd2_words": sorted(cd2_words),
                "cd3_words": sorted(cd3_words),
                "cd2_correspondences": [c for c in correspondences if c["cd_step"] == 2],
                "cd3_correspondences": [c for c in correspondences if c["cd_step"] == 3],
            })
            for c in correspondences:
                if c["cd_step"] == 2:
                    cd2_word_counts[c["nl_word"]] += 1
                else:
                    cd3_word_counts[c["nl_word"]] += 1

    return {
        "metadata": {
            "n_traces": len(trace_texts),
            "n_atoms": len(atoms),
            "method": "word-level matching (tokenize + atom index)",
        },
        "ontology_cd_steps": dict(SOURCE_CD),
        "source_counts": dict(Counter(atom_source_map.get(a["atom_id"], "") for a in atoms)),
        "trace_results": trace_results,
        "all_correspondences": all_correspondences,
        "paradox_candidates": paradox_candidates,
        "summary": {
            "total_traces": len(trace_texts),
            "traces_with_matches": len(trace_results),
            "cd2_only": cd2_traces - both_traces,
            "cd3_only": cd3_traces - both_traces,
            "both_cd2_and_cd3": both_traces,
            "neither": neither_traces,
            "total_correspondences": len(all_correspondences),
            "unique_nl_words_matched": len(set(c["nl_word"] for c in all_correspondences)),
            "top_cd2_words": [w for w, _ in cd2_word_counts.most_common(15)],
            "top_cd3_words": [w for w, _ in cd3_word_counts.most_common(15)],
        },
    }


# =============================================================================
# Print report
# =============================================================================

def print_report(result: Dict[str, Any]):
    """Print a formatted correspondence table."""
    s = result["summary"]

    print("\n" + "=" * 80)
    print("OWL CORRESPONDENCE TABLE — Blood-Brain Barrier Pairings")
    print("=" * 80)

    print(f"\nData:")
    print(f"  Traces:    {result['metadata']['n_traces']}")
    print(f"  OWL atoms: {result['metadata']['n_atoms']}")

    print(f"\nOWL Ontology CD Steps (BRAIN):")
    for src, cd in sorted(result["ontology_cd_steps"].items(), key=lambda x: x[1]):
        print(f"  {src:12s}  CD:{cd}  ({'associative' if cd == 2 else 'non-associative'})  "
              f"{result['source_counts'].get(src, 0)} atoms")

    print(f"\nSummary:")
    print(f"  Traces with matches:   {s['traces_with_matches']}/{s['total_traces']}")
    print(f"  CD:2 only:             {s['cd2_only']}")
    print(f"  CD:3 only:             {s['cd3_only']}")
    print(f"  Both CD:2+3:           {s['both_cd2_and_cd3']}  ← PARADOX CANDIDATES")
    print(f"  Neither:               {s['neither']}")
    print(f"  Total correspondences: {s['total_correspondences']}")
    print(f"  Unique NL words:       {s['unique_nl_words_matched']}")

    if s["top_cd2_words"]:
        print(f"\n  Top CD:2 words (associative side): {', '.join(s['top_cd2_words'][:10])}")
    if s["top_cd3_words"]:
        print(f"  Top CD:3 words (non-associative side): {', '.join(s['top_cd3_words'][:10])}")

    # Print paradox candidates
    if result["paradox_candidates"]:
        print(f"\n{'=' * 80}")
        print(f"PARADOX CANDIDATES (straddle CD 2→3 boundary): {len(result['paradox_candidates'])}")
        print(f"{'=' * 80}")

        # Show top candidates by word variety (most cd2+cd3 words)
        sorted_cands = sorted(result["paradox_candidates"],
                              key=lambda c: len(c["cd2_words"]) + len(c["cd3_words"]),
                              reverse=True)

        for cand in sorted_cands[:10]:
            cd2_atoms = ", ".join(c["atom_id"] for c in cand["cd2_correspondences"][:3])
            cd3_atoms = ", ".join(c["atom_id"] for c in cand["cd3_correspondences"][:3])
            print(f"\n  ┌ {cand['trace_id']}")
            print(f"  │ {cand['trace_preview'][:100]}")
            print(f"  ├ CD:2 words ({len(cand['cd2_words'])}): {', '.join(cand['cd2_words'][:8])}")
            print(f"  │  atoms: {cd2_atoms}")
            print(f"  └ CD:3 words ({len(cand['cd3_words'])}): {', '.join(cand['cd3_words'][:8])}")
            print(f"     atoms: {cd3_atoms}")

    if result["all_correspondences"]:
        print(f"\n{'=' * 80}")
        print(f"SAMPLE CORRESPONDENCES (first 15)")
        print(f"{'=' * 80}")
        print(f"  {'NL Word':20s} {'OWL Atom':35s} {'Source':12s} CD  Match")
        print(f"  {'─'*20} {'─'*35} {'─'*12} {'─'*2} {'─'*10}")
        for c in result["all_correspondences"][:15]:
            print(f"  {c['nl_word']:20s} {c['atom_id']:35s} {c['source']:12s} {c['cd_step']}  {c['match_type']:>10s}")


# =============================================================================
# Main
# =============================================================================

def main():
    print("=" * 80)
    print("OWL CORRESPONDENCE BUILDER")
    print("Using real M0 atom data + word-level matching")
    print("=" * 80)

    # Load
    print("\nLoading data...")
    atoms, atom_cd, atom_source = load_atoms()
    trace_texts, trace_ids = load_traces()

    # Build word→atom index
    print("\nBuilding word→atom index...")
    atom_index = build_atom_index(atoms)

    # Process traces
    print("\nProcessing traces...")
    result = process_traces(trace_texts, trace_ids, atom_index, atoms, atom_cd)

    # Print report
    print_report(result)

    # Save
    OUTPUT_PATH.write_text(json.dumps(result, indent=2, default=str))
    print(f"\n  Saved to {OUTPUT_PATH}")

    print(f"\n{'=' * 80}")
    print("DONE")
    print(f"{'=' * 80}")


if __name__ == "__main__":
    main()
