#!/usr/bin/env python3
"""
Verify OWL Correspondence Table — Row/Column Source Confirmation

Generates a verification report showing, for each matched NL composition,
the corresponding OWL atoms and their embedding fingerprints (e0..e6).
This allows visual confirmation that the correspondence table pulls from
the correct ontology sources.

Output columns:
  1. NL Composition  — CamelCase composition of NL words from the trace
  2. OWL Atoms       — Space-separated OWL atom IDs matched to those words
  3. e0..e6 (atom 1) — First 7 embedding components of the first matched atom
  4. e0..e6 (atom 2) — First 7 embedding components of the second matched atom

Usage:
    python scripts/verify_owl_correspondence.py
    python scripts/verify_owl_correspondence.py --csv
"""

from __future__ import annotations

import csv
import json
import sys
from collections import OrderedDict, defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import numpy as np

# ── Paths ──────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
ATOMS_PATH = PROJECT_ROOT / "data" / "reinforcement_atoms.json"
MATRIX_META = PROJECT_ROOT / "data" / "trace_atom_matrix_metadata.json"
ATOM_EMBEDDINGS = PROJECT_ROOT / "data" / "atom_embeddings.npy"
CORRESPONDENCE_PATH = PROJECT_ROOT / "data" / "owl_correspondence.json"
OUTPUT_CSV = PROJECT_ROOT / "data" / "owl_verification_report.csv"


# =============================================================================
# Load data
# =============================================================================

def load_data() -> Tuple[
    np.ndarray,               # atom_embeddings (428×1024)
    List[str],                # atom_ids in index order
    Dict[str, int],           # atom_id → index in embedding array
    List[Dict[str, Any]],     # raw atoms from reinforcement_atoms.json
    Dict[str, str],           # atom_src — atom_id → source name
    Dict[str, Any],           # correspondence data
]:
    """Load all data needed for the verification report."""
    # — Atom embeddings —
    atom_embeddings = np.load(str(ATOM_EMBEDDINGS))
    print(f"  Atom embeddings: {atom_embeddings.shape}")

    # — Atom IDs in index order —
    with open(MATRIX_META) as f:
        meta = json.load(f)
    atom_ids: List[str] = meta["atom_ids"]
    print(f"  Atom IDs ({len(atom_ids)}): {atom_ids[0]} … {atom_ids[-1]}")

    # — Build atom_id → index lookup —
    atom_index: Dict[str, int] = {aid: i for i, aid in enumerate(atom_ids)}

    # — Raw atoms (for source info) —
    with open(ATOMS_PATH) as f:
        atoms_data = json.load(f)
    raw_atoms: List[Dict[str, Any]] = atoms_data["atoms"]
    atom_src: Dict[str, str] = {a["atom_id"]: a["source"] for a in raw_atoms}
    print(f"  Raw atoms: {len(raw_atoms)} from {', '.join(atoms_data['source_counts'].keys())}")

    # — Correspondence data —
    with open(CORRESPONDENCE_PATH) as f:
        corr_data = json.load(f)
    print(f"  Correspondences: {corr_data['summary']['total_correspondences']}")
    print(f"  Paradox candidates: {len(corr_data['paradox_candidates'])}")

    return atom_embeddings, atom_ids, atom_index, raw_atoms, atom_src, corr_data


# =============================================================================
# Build verification rows
# =============================================================================

def build_rows(
    corr_data: Dict[str, Any],
    atom_index: Dict[str, int],
    atom_embeddings: np.ndarray,
    atom_src: Dict[str, str],
    max_rows: int = 200,
) -> List[Dict[str, Any]]:
    """Build verification rows from correspondence data.

    Each row represents one trace (one reasoning episode) with:
      - NL composition: CamelCase of unique NL words matched to OWL atoms
      - OWL atoms: space-separated atom IDs with source
      - e0..e6: first 7 embedding components for up to 2 atoms
    """
    rows: List[Dict[str, Any]] = []

    for tr in corr_data["trace_results"]:
        if len(rows) >= max_rows:
            break

        tid = tr["trace_id"]
        corrs = tr["correspondences"]  # list of {nl_word, atom_id, source, cd_step, ...}

        # Collect unique NL words and unique atoms
        nl_words: Set[str] = set()
        atom_set: List[str] = []
        seen_atoms: Set[str] = set()
        cd2_count = 0
        cd3_count = 0

        for c in corrs:
            nl_words.add(c["nl_word"])
            if c["atom_id"] not in seen_atoms:
                seen_atoms.add(c["atom_id"])
                atom_set.append(c["atom_id"])
            if c["cd_step"] == 2:
                cd2_count += 1
            elif c["cd_step"] == 3:
                cd3_count += 1

        # Form NL composition: CamelCase of sorted unique words
        sorted_words = sorted(nl_words, key=str.lower)
        nl_composition = "".join(w.capitalize() for w in sorted_words)

        # Up to 2 atoms for display
        atom1_id = atom_set[0] if len(atom_set) > 0 else ""
        atom2_id = atom_set[1] if len(atom_set) > 1 else ""

        # Get e0..e6 (first 7 embedding components) for each atom
        e0e6_1 = ""
        e0e6_2 = ""
        src1 = ""
        src2 = ""

        if atom1_id and atom1_id in atom_index:
            idx1 = atom_index[atom1_id]
            e0e6_1 = ", ".join(f"{v:.4f}" for v in atom_embeddings[idx1][:7])
            src1 = atom_src.get(atom1_id, "?")
        if atom2_id and atom2_id in atom_index:
            idx2 = atom_index[atom2_id]
            e0e6_2 = ", ".join(f"{v:.4f}" for v in atom_embeddings[idx2][:7])
            src2 = atom_src.get(atom2_id, "?")

        # NL preview
        nl_preview = nl_composition[:80]
        if len(nl_composition) > 80:
            nl_preview += "…"

        rows.append({
            "trace_id": tid,
            "nl_composition": nl_preview,
            "n_nl_words": len(nl_words),
            "n_atoms": len(atom_set),
            "cd2_count": cd2_count,
            "cd3_count": cd3_count,
            "owl_atom_1": atom1_id,
            "src_1": src1,
            "e0e6_1": e0e6_1,
            "owl_atom_2": atom2_id,
            "src_2": src2,
            "e0e6_2": e0e6_2,
        })

    return rows


# =============================================================================
# Print report
# =============================================================================

def print_report(rows: List[Dict[str, Any]]):
    """Print formatted verification report to terminal."""
    print("\n" + "=" * 140)
    print("OWL CORRESPONDENCE VERIFICATION REPORT")
    print("Confirming data sources and embedding fingerprints")
    print("=" * 140)

    # Summary stats
    total = len(rows)
    with_src1 = sum(1 for r in rows if r["src_1"])
    with_src2 = sum(1 for r in rows if r["src_2"])
    cd2_only = sum(1 for r in rows if r["cd2_count"] > 0 and r["cd3_count"] == 0)
    cd3_only = sum(1 for r in rows if r["cd3_count"] > 0 and r["cd2_count"] == 0)
    both_sides = sum(1 for r in rows if r["cd2_count"] > 0 and r["cd3_count"] > 0)

    print(f"\n  Rows shown:    {total}")
    print(f"  With atom 1:   {with_src1}/{total}")
    print(f"  With atom 2:   {with_src2}/{total}")
    print(f"  CD:2 only:     {cd2_only}")
    print(f"  CD:3 only:     {cd3_only}")
    print(f"  Both CD:2+3:   {both_sides}  (paradox candidates)")

    # Source distribution
    src_counts: Dict[str, int] = {}
    for r in rows:
        for s in [r["src_1"], r["src_2"]]:
            if s:
                src_counts[s] = src_counts.get(s, 0) + 1
    if src_counts:
        print(f"  Source dist:   {', '.join(f'{k}={v}' for k,v in sorted(src_counts.items()))}")

    print(f"\n{'─'*140}")

    # Header
    hdr = (
        f"{'Row':<5} {'Trace':<14} {'NL Composition (CamelCase)':<48} "
        f"{'OWL Atoms':<45} {'CD':<5} "
        f"{'e0..e6 (atom 1)':>32}  {'e0..e6 (atom 2)':>32}"
    )
    print(hdr)
    print(f"{'─'*140}")

    for i, r in enumerate(rows):
        # CD label
        if r["cd2_count"] > 0 and r["cd3_count"] > 0:
            cd_label = "2⇄3"
        elif r["cd2_count"] > 0:
            cd_label = "2"
        elif r["cd3_count"] > 0:
            cd_label = "3"
        else:
            cd_label = "?"

        # OWL atoms column (truncated)
        owl_col = f"{r['owl_atom_1']}({r['src_1']})"
        if r["owl_atom_2"]:
            owl_col += f"  {r['owl_atom_2']}({r['src_2']})"

        # NL column (truncated)
        nl_col = r["nl_composition"][:47]
        
        # e0..e6 columns (truncate display)
        e0_short_1 = r["e0e6_1"][:60] if r["e0e6_1"] else "-"
        e0_short_2 = r["e0e6_2"][:60] if r["e0e6_2"] else "-"

        print(
            f"{i+1:<5} {r['trace_id']:<14} {nl_col:<48} "
            f"{owl_col:<45} {cd_label:<5} "
            f"{e0_short_1:<34}  {e0_short_2}"
        )

        if i >= 49:
            print(f"\n  … ({total - 50} more rows)")
            break

    print(f"{'─'*140}")
    print(f"End of report (showing {min(50, total)} of {total} rows)")


# =============================================================================
# CSV export
# =============================================================================

def export_csv(rows: List[Dict[str, Any]], path: Path):
    """Export verification rows to CSV."""
    fields = [
        "trace_id", "nl_composition", "n_nl_words", "n_atoms",
        "cd2_count", "cd3_count",
        "owl_atom_1", "src_1", "e0e6_1",
        "owl_atom_2", "src_2", "e0e6_2",
    ]
    with open(path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(f"\n  CSV exported: {path} ({len(rows)} rows)")


# =============================================================================
# Main
# =============================================================================

def main():
    export_csv_flag = "--csv" in sys.argv
    max_rows = 200

    print("=" * 80)
    print("OWL CORRESPONDENCE VERIFICATION")
    print("=" * 80)

    # Load
    print("\nLoading data...")
    atom_embeddings, atom_ids, atom_index, raw_atoms, atom_src, corr_data = load_data()

    # Build rows
    print(f"\nBuilding verification rows (max {max_rows})...")
    rows = build_rows(corr_data, atom_index, atom_embeddings, atom_src, max_rows=max_rows)
    print(f"  Built {len(rows)} rows")

    # Print report
    print_report(rows)

    # CSV export
    if export_csv_flag:
        export_csv(rows, OUTPUT_CSV)

    print(f"\n{'=' * 80}")
    print("VERIFICATION COMPLETE")
    print(f"{'=' * 80}")


if __name__ == "__main__":
    main()
