#!/usr/bin/env python3
"""
verify_owl_correspondence.py — Multi-section spot-check report for all OWL data formats.

Generates indexable spot-check reports for:
  Sec 1 — OWL correspondence + e₀-e₇ Hopf fingerprints (original)
  Sec 2 — Markov poset build stats (M2a)
  Sec 3 — NL→OWL match table overview (M2a)
  Sec 4 — Reinforcement candidates (M2b)
  Sec 5 — OWL stationary distribution (M2b)
  Sec 6 — Synthetic OWL sequences (M2c)
  Sec 7 — Poset stability (M2d)
  Sec 8 — Cross-format integrity checks

Output: terminal report + JSON report file (for Open Notebook ingestion).

Usage:
    python scripts/verify_owl_correspondence.py
    python scripts/verify_owl_correspondence.py --sec 3 5 7     # specific sections
    python scripts/verify_owl_correspondence.py --json-only     # just the JSON report
"""

from __future__ import annotations

import csv
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import numpy as np
import scipy.sparse as sp

# ── Paths ──────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
D = PROJECT_ROOT / "data"

# Original correspondence data
ATOMS_PATH = D / "reinforcement_atoms.json"
MATRIX_META = D / "trace_atom_matrix_metadata.json"
ATOM_EMBEDDINGS = D / "atom_embeddings.npy"
CORRESPONDENCE_PATH = D / "owl_correspondence.json"

# Markov poset data (M2a)
CHAIN_COUNTS = D / "nl_markov_chain_counts.npz"
CHAIN_BINARY = D / "nl_markov_chain.npz"
METADATA_PATH = D / "nl_markov_metadata.json"
NL_TO_OWL_PATH = D / "nl_to_owl_match.json"
POSET_STATS = D / "markov_poset_stats.json"

# Analysis outputs (M2b)
CANDIDATES_PATH = D / "reinforcement_candidates.json"
OWL_STATIONARY = D / "owl_stationary_distribution.json"

# Generation outputs (M2c)
SYNTHETIC_PATH = D / "synthetic_owl_sequences.json"

# Stability (M2d)
STABILITY_PATH = D / "poset_stability.json"

# Output
REPORT_JSON = D / "owl_spotcheck_report.json"
OUTPUT_CSV = D / "owl_verification_report.csv"


# =============================================================================
# Section 1: OWL correspondence + e₀-e₇ Hopf fingerprints
# =============================================================================

def section1_correspondence() -> Dict[str, Any]:
    """Original e₀-e₇ verification report on owl_correspondence.json."""
    if not all(p.exists() for p in [ATOMS_PATH, MATRIX_META, ATOM_EMBEDDINGS, CORRESPONDENCE_PATH]):
        return {"status": "skipped", "reason": "correspondence data not found"}

    atom_embeddings = np.load(str(ATOM_EMBEDDINGS))

    with open(MATRIX_META) as f:
        meta = json.load(f)
    atom_ids: List[str] = meta["atom_ids"]
    atom_index: Dict[str, int] = {aid: i for i, aid in enumerate(atom_ids)}

    with open(ATOMS_PATH) as f:
        atoms_data = json.load(f)
    atom_src: Dict[str, str] = {a["atom_id"]: a["source"] for a in atoms_data["atoms"]}

    with open(CORRESPONDENCE_PATH) as f:
        corr_data = json.load(f)

    summary = corr_data["summary"]
    trace_results = corr_data["trace_results"]

    # Count CD:2 vs CD:3 per trace
    cd_counts: List[int] = []
    paradox_count = 0
    for tr in trace_results:
        n_cd2 = sum(1 for c in tr["correspondences"] if c["cd_step"] == 2)
        n_cd3 = sum(1 for c in tr["correspondences"] if c["cd_step"] == 3)
        cd_counts.append((n_cd2, n_cd3))
        if n_cd2 > 0 and n_cd3 > 0:
            paradox_count += 1

    cd2_total = sum(c[0] for c in cd_counts)
    cd3_total = sum(c[1] for c in cd_counts)

    # Build verification rows (up to 200)
    rows: List[Dict[str, Any]] = []
    for tr in trace_results[:200]:
        tid = tr["trace_id"]
        corrs = tr["correspondences"]
        nl_words: Set[str] = set()
        atom_set: List[str] = []
        seen_atoms: Set[str] = set()
        cd2_count = 0
        cd3_count = 0
        match_types: Counter = Counter()

        for c in corrs:
            nl_words.add(c["nl_word"])
            match_types[c["match_type"]] += 1
            if c["atom_id"] not in seen_atoms:
                seen_atoms.add(c["atom_id"])
                atom_set.append(c["atom_id"])
            if c["cd_step"] == 2:
                cd2_count += 1
            elif c["cd_step"] == 3:
                cd3_count += 1

        sorted_words = sorted(nl_words, key=str.lower)
        nl_composition = "".join(w.capitalize() for w in sorted_words)

        atom1_id = atom_set[0] if len(atom_set) > 0 else ""
        atom2_id = atom_set[1] if len(atom_set) > 1 else ""
        e0e7_1 = ""
        e0e7_2 = ""
        src1 = ""
        src2 = ""
        if atom1_id and atom1_id in atom_index:
            idx1 = atom_index[atom1_id]
            e0e7_1 = ", ".join(f"{v:.4f}" for v in atom_embeddings[idx1][:8])
            src1 = atom_src.get(atom1_id, "?")
        if atom2_id and atom2_id in atom_index:
            idx2 = atom_index[atom2_id]
            e0e7_2 = ", ".join(f"{v:.4f}" for v in atom_embeddings[idx2][:8])
            src2 = atom_src.get(atom2_id, "?")

        rows.append({
            "trace_id": tid,
            "nl_composition": nl_composition[:80],
            "n_nl_words": len(nl_words),
            "n_atoms": len(atom_set),
            "cd2_count": cd2_count, "cd3_count": cd3_count,
            "match_types": dict(match_types),
            "owl_atom_1": atom1_id, "src_1": src1, "e0e7_1": e0e7_1,
            "owl_atom_2": atom2_id, "src_2": src2, "e0e7_2": e0e7_2,
        })

    src_dist = Counter()
    for r in rows:
        for s in [r["src_1"], r["src_2"]]:
            if s:
                src_dist[s] += 1

    return {
        "total_traces": len(trace_results),
        "total_correspondences": summary["total_correspondences"],
        "paradox_candidates": len(corr_data.get("paradox_candidates", [])),
        "paradox_traces": paradox_count,
        "cd2_total": cd2_total,
        "cd3_total": cd3_total,
        "match_type_dist": dict(match_types),
        "source_dist": dict(src_dist.most_common()),
        "rows": rows,
        "n_rows": len(rows),
    }


# =============================================================================
# Section 2: Markov poset build stats (M2a)
# =============================================================================

def section2_poset_stats() -> Dict[str, Any]:
    if not POSET_STATS.exists():
        return {"status": "skipped", "reason": "markov_poset_stats.json not found"}
    with open(POSET_STATS) as f:
        return json.load(f)


# =============================================================================
# Section 3: NL→OWL match table overview (M2a)
# =============================================================================

def section3_nl_owl_matches() -> Dict[str, Any]:
    if not NL_TO_OWL_PATH.exists():
        return {"status": "skipped", "reason": "nl_to_owl_match.json not found"}

    with open(NL_TO_OWL_PATH) as f:
        match_table = json.load(f)

    # Stats
    n_words = len(match_table)
    n_matches = sum(len(v) for v in match_table.values())

    # Source distribution
    src_counts: Counter = Counter()
    cd_step_counts: Counter = Counter()
    match_type_counts: Counter = Counter()
    atoms_per_word: List[int] = []

    for word, atom_list in match_table.items():
        atoms_per_word.append(len(atom_list))
        for a in atom_list:
            src_counts[a["source"]] += 1
            cd_step_counts[f"cd:{a['cd_step']}"] += 1
            match_type_counts[a["match_type"]] += 1

    # Top words by match count
    word_match_counts = sorted(
        [(w, len(a)) for w, a in match_table.items()],
        key=lambda x: -x[1]
    )[:20]

    # Source co-occurrence: words matched to atoms from multiple sources
    multi_source = sum(
        1 for atoms in match_table.values()
        if len(set(a["source"] for a in atoms)) > 1
    )

    # Check the 498 paradox candidates
    paradox_words = [
        w for w, atoms in match_table.items()
        if any(a["cd_step"] == 2 for a in atoms)
        and any(a["cd_step"] == 3 for a in atoms)
    ]

    return {
        "n_words": n_words,
        "n_total_matches": n_matches,
        "mean_atoms_per_word": round(n_matches / n_words, 2) if n_words else 0,
        "median_atoms_per_word": float(np.median(atoms_per_word)) if atoms_per_word else 0,
        "max_atoms_per_word": max(atoms_per_word) if atoms_per_word else 0,
        "source_distribution": dict(src_counts.most_common()),
        "cd_step_distribution": dict(cd_step_counts.most_common()),
        "match_type_distribution": dict(match_type_counts.most_common()),
        "top_words_by_match_count": word_match_counts,
        "words_matched_to_multiple_sources": multi_source,
        "n_paradox_words": len(paradox_words),
        "n_words_matched": sum(1 for a in match_table.values() if len(a) > 0),
    }


# =============================================================================
# Section 4: Reinforcement candidates (M2b)
# =============================================================================

def section4_reinforcement_candidates() -> Dict[str, Any]:
    if not CANDIDATES_PATH.exists():
        return {"status": "skipped", "reason": "reinforcement_candidates.json not found"}

    with open(CANDIDATES_PATH) as f:
        data = json.load(f)

    candidates = data.get("candidates", [])
    total = data.get("n_candidates", len(candidates))

    # Source pair distribution
    src_pairs: Counter = Counter()
    for c in candidates:
        srcs = sorted(c.get("ontology_sources", []))
        src_pairs[" → ".join(srcs)] += 1

    # Trace occurrence distribution
    n_traces_vals = [c["n_traces"] for c in candidates]
    n_occ_vals = [c["n_occurrences"] for c in candidates]

    return {
        "n_candidates_total": total,
        "n_candidates_saved": len(candidates),
        "n_traces_analyzed": data.get("n_traces_analyzed", 0),
        "n_traces_with_atom_sequences": data.get("n_traces_with_atom_sequences", 0),
        "n_total_atom_hits": data.get("n_total_atom_hits", 0),
        "source_pair_distribution": dict(src_pairs.most_common()),
        "trace_count_stats": {
            "min": min(n_traces_vals) if n_traces_vals else 0,
            "max": max(n_traces_vals) if n_traces_vals else 0,
            "mean": round(float(np.mean(n_traces_vals)), 1) if n_traces_vals else 0,
        },
        "occurrence_stats": {
            "min": min(n_occ_vals) if n_occ_vals else 0,
            "max": max(n_occ_vals) if n_occ_vals else 0,
            "mean": round(float(np.mean(n_occ_vals)), 1) if n_occ_vals else 0,
        },
        "top_candidates": candidates[:10],
    }


# =============================================================================
# Section 5: OWL stationary distribution (M2b)
# =============================================================================

def section5_owl_stationary() -> Dict[str, Any]:
    if not OWL_STATIONARY.exists():
        return {"status": "skipped", "reason": "owl_stationary_distribution.json not found"}

    with open(OWL_STATIONARY) as f:
        data = json.load(f)

    atoms = data.get("top_owl_atoms", [])
    n_atoms = data.get("n_atoms", len(atoms))

    # Source distribution among top atoms
    src_counts: Counter = Counter()
    for a in atoms:
        src = a["atom_id"].split("_")[0] if "_" in a["atom_id"] else "other"
        # Map abbreviation
        if src == "frame": src = "framenet"
        elif src == "provo": src = "prov-o"
        elif src == "pplan": src = "p-plan"
        src_counts[src] += 1

    probs = [a["stationary_prob"] for a in atoms]
    cumulative = sum(probs)

    return {
        "n_atoms_with_nonzero_prob": n_atoms,
        "n_top_atoms": len(atoms),
        "source_distribution_top": dict(src_counts.most_common()),
        "top_atom": atoms[0] if atoms else None,
        "top_probability": max(probs) if probs else 0,
        "cumulative_prob_top": round(cumulative, 4),
        "diversity": round(np.std(probs), 6) if len(probs) > 1 else 0,
        "top_atoms": atoms[:10],
    }


# =============================================================================
# Section 6: Synthetic OWL sequences (M2c)
# =============================================================================

def section6_synthetic_sequences() -> Dict[str, Any]:
    if not SYNTHETIC_PATH.exists():
        return {"status": "skipped", "reason": "synthetic_owl_sequences.json not found"}

    with open(SYNTHETIC_PATH) as f:
        data = json.load(f)

    meta = data["metadata"]
    sequences = data["sequences"]

    # Aggregate stats
    steps_per_seq = [s["n_steps"] for s in sequences]
    atom_counts_per_seq = []
    steps_with_atoms = 0
    total_steps = 0
    all_atoms: Counter = Counter()

    for s in sequences:
        n_atoms_in_seq = len(set(
            a["atom_id"] for step in s["steps"] for a in step["owl_atoms"]
        ))
        atom_counts_per_seq.append(n_atoms_in_seq)
        for step in s["steps"]:
            total_steps += 1
            if step["n_atoms"] > 0:
                steps_with_atoms += 1
                for a in step["owl_atoms"]:
                    all_atoms[a["atom_id"]] += 1

    # Source diversity
    src_diversity: Counter = Counter()
    for aid in all_atoms:
        src = aid.split("_")[0] if "_" in aid else "other"
        if src == "frame": src = "framenet"
        elif src == "provo": src = "prov-o"
        elif src == "pplan": src = "p-plan"
        src_diversity[src] += 1

    return {
        "metadata": meta,
        "n_sequences": len(sequences),
        "total_steps": total_steps,
        "mean_steps_per_seq": round(float(np.mean(steps_per_seq)), 1),
        "steps_with_atoms": steps_with_atoms,
        "atom_coverage_pct": round(steps_with_atoms / total_steps * 100, 1) if total_steps else 0,
        "mean_atoms_per_seq": round(float(np.mean(atom_counts_per_seq)), 1),
        "max_atoms_per_seq": max(atom_counts_per_seq) if atom_counts_per_seq else 0,
        "unique_atoms_across_all": len(all_atoms),
        "most_frequent_atoms": dict(all_atoms.most_common(10)),
        "source_diversity": dict(src_diversity.most_common()),
        "sample_sequences": [
            {
                "id": s["sequence_id"],
                "n_steps": s["n_steps"],
                "n_atoms": len(set(a["atom_id"] for step in s["steps"] for a in step["owl_atoms"])),
                "word_preview": " ".join(step["word"] for step in s["steps"][:8]),
                "atom_preview": list(set(
                    a["atom_id"] for step in s["steps"][:6] for a in step["owl_atoms"]
                ))[:6],
            }
            for s in sequences[:5]
        ],
    }


# =============================================================================
# Section 7: Poset stability (M2d)
# =============================================================================

def section7_poset_stability() -> Dict[str, Any]:
    if not STABILITY_PATH.exists():
        return {"status": "skipped", "reason": "poset_stability.json not found"}

    with open(STABILITY_PATH) as f:
        data = json.load(f)

    knee = data.get("knee", {})
    stability = data.get("stability", {})

    # Format stability for human reading
    frac_corrs = {}
    for frac_key, corr_data in stability.get("subsample_correlations", {}).items():
        frac_corrs[frac_key] = {
            "mean_rank_corr": corr_data["mean"],
            "std": corr_data["std"],
        }

    frac_overlaps = {}
    for frac_key, olap in stability.get("overlap_at_fraction", {}).items():
        frac_overlaps[frac_key] = {
            "mean_overlap": olap["mean"],
            "std": olap["std"],
        }

    return {
        "n_traces": knee.get("n_traces", 0),
        "total_unique_transitions": knee.get("total_unique_transitions", 0),
        "knee_trace_index": knee.get("knee_trace_index", 0),
        "transitions_at_knee": knee.get("knee_unique_transitions", 0),
        "estimated_tail_transitions_per_trace": (
            round((knee["total_unique_transitions"] - knee["knee_unique_transitions"])
                  / max(1, knee["n_traces"] - knee["knee_trace_index"]), 1)
            if knee.get("total_unique_transitions") and knee.get("n_traces")
            else 0
        ),
        "subsample_correlations": frac_corrs,
        "subsample_overlaps": frac_overlaps,
    }


# =============================================================================
# Section 8: Cross-format integrity checks
# =============================================================================

def section8_cross_checks(
    sec1: Dict[str, Any], sec2: Dict[str, Any],
    sec3: Dict[str, Any], sec4: Dict[str, Any],
    sec5: Dict[str, Any], sec6: Dict[str, Any],
    sec7: Dict[str, Any],
) -> Dict[str, Any]:
    """Check that data across formats is consistent."""
    checks: List[Dict[str, Any]] = []

    # Check 1: OWL atoms in stationary dist vs atoms file
    if sec5.get("status") != "skipped" and sec1.get("status") != "skipped":
        with open(ATOMS_PATH) as f:
            atoms_data = json.load(f)
        raw_atom_count = len(atoms_data["atoms"])
        stationary_n = sec5.get("n_atoms_with_nonzero_prob", 0)
        checks.append({
            "check": "atoms_vs_stationary",
            "pass": stationary_n <= raw_atom_count + 5,
            "raw_atom_count": raw_atom_count,
            "stationary_atom_count": stationary_n,
            "detail": f"{stationary_n}/{raw_atom_count} atoms have non-zero stationary prob",
        })

    # Check 2: NL→OWL match words vs poset vocabulary
    if sec3.get("status") != "skipped" and sec2.get("status") != "skipped":
        n_matched_words = sec3.get("n_words", 0)
        poset_vocab = sec2.get("vocab_size", 0)
        words_with_matches = sec2.get("words_with_owl_matches", 0)
        checks.append({
            "check": "match_table_vs_poset",
            "pass": words_with_matches <= n_matched_words + 5,  # some may not have survived tokenization
            "n_matched_words_index": n_matched_words,
            "words_with_matches_in_poset": words_with_matches,
            "detail": f"{words_with_matches}/{n_matched_words} matched words appear in poset vocabulary ({poset_vocab} total vocab)",
        })

    # Check 3: Synthetic sequence atoms exist in stationary dist
    if sec6.get("status") != "skipped" and sec5.get("status") != "skipped":
        unique_atoms_gen = sec6.get("unique_atoms_across_all", 0)
        stationary_atoms = sec5.get("n_atoms_with_nonzero_prob", 0)
        checks.append({
            "check": "generated_atoms_vs_stationary",
            "pass": unique_atoms_gen <= stationary_atoms + 10,
            "unique_atoms_generated": unique_atoms_gen,
            "stationary_atoms": stationary_atoms,
            "detail": f"Generated {unique_atoms_gen} unique atoms; {stationary_atoms} have stationary prob > 0",
        })

    # Check 4: Candidate atoms referenced in stationary dist
    if sec4.get("status") != "skipped" and sec5.get("status") != "skipped":
        top_cands = sec4.get("top_candidates", [])
        cand_atoms: Set[str] = set()
        for c in top_cands:
            seq = c.get("owl_subsequence", "")
            parts = seq.split(" → ")
            cand_atoms.update(parts)
        stationary_atom_ids = {a["atom_id"] for a in sec5.get("top_atoms", [])}
        overlap = cand_atoms & stationary_atom_ids
        checks.append({
            "check": "candidate_atoms_in_stationary",
            "pass": len(overlap) >= max(1, len(cand_atoms) // 4),
            "n_candidate_atoms": len(cand_atoms),
            "n_in_stationary_top": len(overlap),
            "overlap_atoms": sorted(overlap)[:10],
            "detail": f"{len(overlap)}/{len(cand_atoms)} candidate atoms appear in stationary top-{len(sec5.get('top_atoms', []))}",
        })

    # Check 5: Stability conclusion
    if sec7.get("status") != "skipped":
        knee_idx = sec7.get("knee_trace_index", 0)
        n_traces = sec7.get("n_traces", 0)
        frac_corrs = sec7.get("subsample_correlations", {})
        best_corr = max(
            (v.get("mean_rank_corr", 0) for v in frac_corrs.values()),
            default=0
        )
        is_stable = best_corr >= 0.7 and knee_idx < n_traces // 2
        checks.append({
            "check": "poset_stability",
            "pass": is_stable,
            "knee_idx": knee_idx,
            "n_traces": n_traces,
            "best_subsample_corr": round(best_corr, 3),
            "detail": f"knee at trace {knee_idx}/{n_traces}, best subsample corr={best_corr:.3f} → {'STABLE' if is_stable else 'PROVISIONAL'}",
        })

    return {
        "n_checks": len(checks),
        "n_pass": sum(1 for c in checks if c["pass"]),
        "checks": checks,
    }


# =============================================================================
# Print formatted report
# =============================================================================

def print_section_header(num: int, title: str):
    print(f"\n{'─' * 80}")
    print(f"  §{num}: {title}")
    print(f"{'─' * 80}")


def print_report(all_sections: Dict[str, Any]):
    """Print a formatted spot-check report to terminal, respecting 20-line output per section."""
    print("=" * 80)
    print("OWL DATA SPOT-CHECK REPORT")
    print(f"Generated: {datetime.now().isoformat()}")
    print("=" * 80)

    # ── Sec 1: Correspondence ──────────────────────────────────────────────
    s1 = all_sections.get("section1", {})
    if s1.get("status") != "skipped":
        print_section_header(1, "OWL Correspondence + e₀-e₇ Fingerprints")
        print(f"  Traces: {s1.get('total_traces', '?')}  |  Corrs: {s1.get('total_correspondences', '?')}")
        print(f"  CD:2={s1.get('cd2_total', '?')}  CD:3={s1.get('cd3_total', '?')}")
        print(f"  Paradox: {s1.get('paradox_traces', '?')} traces ({s1.get('paradox_candidates', '?')} candidates)")
        src = s1.get("source_dist", {})
        print(f"  Sources: {', '.join(f'{k}={v}' for k,v in list(src.items())[:5])}")
        rows = s1.get("rows", [])
        if rows:
            r = rows[0]
            print(f"  Example: {r['trace_id']} → {r['nl_composition'][:50]}  |  {r['owl_atom_1']}({r['src_1']})")
            print(f"    e₀..e₇: {r['e0e7_1'][:60]}")

    # ── Sec 2: Poset stats ─────────────────────────────────────────────────
    s2 = all_sections.get("section2", {})
    if s2.get("status") != "skipped":
        print_section_header(2, "Markov Poset Build (M2a)")
        print(f"  Vocab: {s2.get('vocab_size', '?')}  |  States: {s2.get('n_states', '?')}  |  Transitions: {s2.get('n_transition_pairs', '?')}")
        print(f"  Density: {s2.get('density', 0):.6f}  |  Traces: {s2.get('n_traces', '?')}")
        print(f"  Words w/ OWL: {s2.get('words_with_owl_matches', '?')}")

    # ── Sec 3: NL→OWL matches ─────────────────────────────────────────────
    s3 = all_sections.get("section3", {})
    if s3.get("status") != "skipped":
        print_section_header(3, "NL→OWL Match Table (M2a)")
        print(f"  Words: {s3.get('n_words', '?')}  |  Total matches: {s3.get('n_total_matches', '?')}")
        print(f"  Mean: {s3.get('mean_atoms_per_word', 0)} atoms/word  |  Median: {s3.get('median_atoms_per_word', 0)}  |  Max: {s3.get('max_atoms_per_word', 0)}")
        src3 = s3.get("source_distribution", {})
        print(f"  Sources: {', '.join(f'{k}={v}' for k,v in list(src3.items())[:5])}")
        print(f"  Paradox words: {s3.get('n_paradox_words', '?')}  |  Multi-source: {s3.get('words_matched_to_multiple_sources', '?')}")
        top_w = s3.get("top_words_by_match_count", [])
        if top_w:
            print(f"  Top: {', '.join(f'{w}({c})' for w,c in top_w[:6])}")

    # ── Sec 4: Candidates ─────────────────────────────────────────────────
    s4 = all_sections.get("section4", {})
    if s4.get("status") != "skipped":
        print_section_header(4, "Reinforcement Candidates (M2b)")
        print(f"  Total: {s4.get('n_candidates_total', '?')}  |  Saved top: {s4.get('n_candidates_saved', '?')}")
        print(f"  Traces analyzed: {s4.get('n_traces_analyzed', '?')}  |  Traces w/ atoms: {s4.get('n_traces_with_atom_sequences', '?')}")
        print(f"  Atom hits: {s4.get('n_total_atom_hits', '?')}")
        src_pairs = s4.get("source_pair_distribution", {})
        print(f"  Source pairs: {', '.join(f'{k}={v}' for k,v in list(src_pairs.items())[:3])}")
        top5 = s4.get("top_candidates", [])[:3]
        for c in top5:
            print(f"    {c.get('owl_subsequence','?')}  ({c.get('n_traces',0)} traces, {c.get('n_occurrences',0)} occ)")

    # ── Sec 5: OWL stationary ─────────────────────────────────────────────
    s5 = all_sections.get("section5", {})
    if s5.get("status") != "skipped":
        print_section_header(5, "OWL Stationary Distribution (M2b)")
        print(f"  Atoms with π > 0: {s5.get('n_atoms_with_nonzero_prob', '?')}")
        top_a = s5.get("top_atom", {})
        if top_a:
            print(f"  Top: {top_a.get('atom_id','')}  π={top_a.get('stationary_prob',0):.6f}")
        src5 = s5.get("source_distribution_top", {})
        print(f"  Sources: {', '.join(f'{k}={v}' for k,v in list(src5.items())[:5])}")
        print(f"  Mean stationary π: {s5.get('cumulative_prob_top', 0)/max(1, s5.get('n_top_atoms',1)):.6f}")

    # ── Sec 6: Synthetic sequences ────────────────────────────────────────
    s6 = all_sections.get("section6", {})
    if s6.get("status") != "skipped":
        print_section_header(6, "Synthetic OWL Sequences (M2c)")
        print(f"  Sequences: {s6.get('n_sequences', '?')}  |  Steps: {s6.get('total_steps', '?')}")
        print(f"  Atom coverage: {s6.get('atom_coverage_pct', 0)}%  |  Unique atoms: {s6.get('unique_atoms_across_all', '?')}")
        print(f"  Mean steps/seq: {s6.get('mean_steps_per_seq', 0)}  |  Mean atoms/seq: {s6.get('mean_atoms_per_seq', 0)}")
        freq6 = s6.get("most_frequent_atoms", {})
        if freq6:
            print(f"  Top atoms: {', '.join(f'{a}({c})' for a,c in list(freq6.items())[:5])}")
        sample = s6.get("sample_sequences", [])
        if sample:
            s = sample[0]
            print(f"  Sample: {s['id']} — {s.get('word_preview','')[:60]}")

    # ── Sec 7: Stability ──────────────────────────────────────────────────
    s7 = all_sections.get("section7", {})
    if s7.get("status") != "skipped":
        print_section_header(7, "Poset Stability (M2d)")
        print(f"  Traces: {s7.get('n_traces', '?')}  |  Unique transitions: {s7.get('total_unique_transitions', '?')}")
        print(f"  Knee: trace {s7.get('knee_trace_index', '?')}  |  Tail rate: ~{s7.get('estimated_tail_transitions_per_trace', 0)}/trace")
        for frac_key, v in s7.get("subsample_correlations", {}).items():
            print(f"  {frac_key}: rank corr={v.get('mean_rank_corr', 0):.3f}")

    # ── Sec 8: Cross-checks ───────────────────────────────────────────────
    s8 = all_sections.get("section8", {})
    if s8.get("status") != "skipped":
        print_section_header(8, "Cross-Format Integrity Checks")
        print(f"  Passed: {s8.get('n_pass', 0)}/{s8.get('n_checks', 0)}")
        for c in s8.get("checks", []):
            mark = "✓" if c.get("pass") else "✗"
            print(f"  {mark} {c.get('check', '?')}: {c.get('detail', '')[:90]}")

    print(f"\n{'=' * 80}")
    print("END REPORT")
    print(f"{'=' * 80}")


# =============================================================================
# CSV export (original)
# =============================================================================

def export_csv(rows: List[Dict[str, Any]], path: Path):
    if not rows:
        return
    fields = [
        "trace_id", "nl_composition", "n_nl_words", "n_atoms",
        "cd2_count", "cd3_count",
        "owl_atom_1", "src_1", "e0e7_1",
        "owl_atom_2", "src_2", "e0e7_2",
    ]
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for r in rows:
            writer.writerow({k: r.get(k, "") for k in fields})
    print(f"\n  CSV exported: {path} ({len(rows)} rows)")


# =============================================================================
# Main
# =============================================================================

def main():
    run_sections = [1, 2, 3, 4, 5, 6, 7, 8]
    json_only = False
    export_csv_flag = False

    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = set(a for a in sys.argv[1:] if a.startswith("--"))

    if "--json-only" in flags:
        json_only = True
    if "--csv" in flags:
        export_csv_flag = True

    if args:
        run_sections = [int(a) for a in args if a.isdigit()]

    if not json_only:
        print(f"Running sections: {run_sections}")

    sections: Dict[str, Any] = {}

    # Sec 1 — expensive, only if needed
    if 1 in run_sections or 8 in run_sections:
        s1 = section1_correspondence()
        sections["section1"] = s1
        if not json_only and s1.get("status") != "skipped":
            print(f"  Sec 1 loaded: {s1.get('total_correspondences', '?')} correspondences")

    if 2 in run_sections:
        sections["section2"] = section2_poset_stats()

    if 3 in run_sections:
        sections["section3"] = section3_nl_owl_matches()

    if 4 in run_sections:
        sections["section4"] = section4_reinforcement_candidates()

    if 5 in run_sections:
        sections["section5"] = section5_owl_stationary()

    if 6 in run_sections:
        sections["section6"] = section6_synthetic_sequences()

    if 7 in run_sections:
        sections["section7"] = section7_poset_stability()

    if 8 in run_sections:
        sections["section8"] = section8_cross_checks(
            sections.get("section1", {}),
            sections.get("section2", {}),
            sections.get("section3", {}),
            sections.get("section4", {}),
            sections.get("section5", {}),
            sections.get("section6", {}),
            sections.get("section7", {}),
        )

    # Print terminal report
    if not json_only:
        print_report(sections)

    # Save JSON report
    report = {
        "generated_at": datetime.now().isoformat(),
        "tool": "verify_owl_correspondence.py",
        "sections": sections,
    }
    REPORT_JSON.write_text(json.dumps(report, indent=2, default=str))
    if not json_only:
        print(f"\n  JSON report: {REPORT_JSON}")

    # CSV export (original format, from sec1 rows)
    if export_csv_flag and sections.get("section1", {}).get("rows"):
        export_csv(sections["section1"]["rows"], OUTPUT_CSV)


if __name__ == "__main__":
    main()
