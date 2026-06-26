#!/usr/bin/env python3
"""Phrase-level NodeCost mapper — continuous Friction Lagrangian.

This module maps individual NL phrases to positions in the 7D NodeCost
affine hyperplane (lab note 006: The Hopf 7-Skeleton of Logic Space).

Instead of classifying an entire thinking block into 1 of 4 discrete
coupling signatures, this mapper:

1. Segments thinking blocks into phrases
2. Maps each phrase to a 7D weight vector (w₁⋯w₇) over the octonion basis
3. Computes the continuous friction cost Γ(phrase) = Σᵢ wᵢ · Γ(eᵢ)
4. Builds a glossary: phrase → (7D position, Γ, EMLTree fragment)

The 7 basis vectors and their linguistic dimensions:

  e₁: rightDiv=1     — Classical compression (imperative, direct command)
  e₂: satCap=5       — Fuzzy saturation (uncertainty, hedging)
  e₃: maxSem=true    — Intuitionistic depth (proof, verification, depth)
  e₄: leftWeight=2   — Paraconsistent/Temporal (contradiction, time, change)
  e₅: coupling=1     — Quantum entanglement (non-local reference, cross-ref)
  e₆: mirror=true    — Spacetime reflection (spatial structure, layout)
  e₇: rightDiv=2     — Deontic/Epistemic (obligation, knowledge, should)

GAP: The linguistic heuristics are crude. The 35B LLM could provide
finer-grained classification by reading each phrase and outputting a 7D
weight vector. The heuristic approach is a placeholder for that.

Reference: lab_notes/006_the_hopf_7_skeleton_of_logic_space.md
"""
from __future__ import annotations

import re
import math
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

# ── The 7 basis vectors and their NodeCost signatures ──────────────────
# From lab note 006, Table in Section 3

# Each basis vector has:
# - name: the octonion axis
# - logic: the representative LogicType
# - nodecost: the 8D NodeCost tuple (leftWeight, rightDiv, bias, mirror, coupling, denom, maxSem, satCap)
# - friction_density: Γ(eᵢ) = commDefect + AssocSector × strut_weight²

STRUT_WEIGHT = 4
STRUT_WEIGHT_SQ = 16  # the barrier

BASIS_VECTORS = {
    "e1": {
        "name": "Classical compression",
        "logic": "CLASSICAL",
        "nodecost": (1, 1, 1, 0, 0, 10, 0, 0),
        "cd_step": 0,
        "associative": True,
        "linguistic": "imperative, direct, declarative command",
        "markers": ["let me", "i'll", "run", "execute", "start", "begin", "do", "apply", "set", "create"],
    },
    "e2": {
        "name": "Fuzzy saturation",
        "logic": "FUZZY",
        "nodecost": (1, 1, 1, 0, 0, 10, 0, 5),
        "cd_step": 1,
        "associative": True,
        "linguistic": "uncertainty, hedging, approximation",
        "markers": ["maybe", "perhaps", "might", "could", "possibly", "approximately", "roughly", "seems", "appears", "guess"],
    },
    "e3": {
        "name": "Intuitionistic depth",
        "logic": "INTUITIONISTIC",
        "nodecost": (1, 1, 1, 0, 0, 10, 1, 0),
        "cd_step": 2,
        "associative": True,
        "linguistic": "proof, verification, depth, construction",
        "markers": ["verify", "check", "confirm", "validate", "prove", "test", "ensure", "inspect", "examine", "audit"],
    },
    "e4": {
        "name": "Paraconsistent coupling",
        "logic": "PARACONSISTENT",
        "nodecost": (2, 1, 1, 0, 1, 8, 0, 0),
        "cd_step": 4,
        "associative": False,
        "linguistic": "contradiction, conflict, temporal change, paradox",
        "markers": ["wait", "but", "contradicts", "conflict", "however", "actually", "wrong", "mistake", "error", "paradox", "inconsistent", "fails", "broken"],
    },
    "e5": {
        "name": "Quantum entanglement",
        "logic": "QUANTUM",
        "nodecost": (1, 1, 1, 0, 1, 10, 0, 0),
        "cd_step": 3,
        "associative": False,
        "linguistic": "non-local reference, cross-reference, dependency",
        "markers": ["reference", "depend", "connect", "link", "relate", "cross", "import", "include", "require", "associate"],
    },
    "e6": {
        "name": "Spacetime reflection",
        "logic": "SPACETIME",
        "nodecost": (0, 1, 1, 1, 0, 10, 0, 0),
        "cd_step": 3,
        "associative": False,
        "linguistic": "spatial structure, layout, arrangement, reflection",
        "markers": ["structure", "layout", "arrange", "position", "geometry", "shape", "map", "reflect", "mirror", "coordinate", "organize"],
    },
    "e7": {
        "name": "Deontic obligation",
        "logic": "DEONTIC",
        "nodecost": (1, 2, 1, 0, 0, 10, 0, 0),
        "cd_step": 1,
        "associative": True,
        "linguistic": "obligation, knowledge, should, must, need",
        "markers": ["should", "must", "need", "ought", "require", "obligation", "duty", "rule", "policy", "norm", "know", "believe"],
    },
}


def _comm_defect(cd_step: int) -> int:
    """Commutator defect at a CD step."""
    return cd_step


def _assoc_defect(cd_step: int) -> int:
    """Associator defect: 0 if cdStep ≤ 2, else strut_weight."""
    return 0 if cd_step <= 2 else STRUT_WEIGHT


def friction_density_at(cd_step: int) -> float:
    """Γ(k) = k + strut_weight × assocDefect(k).
    Continuous in cdStep, discrete in the named-logic subspace."""
    return float(cd_step + STRUT_WEIGHT * _assoc_defect(cd_step))


@dataclass
class PhraseEntry:
    """A single phrase mapped to the 7D NodeCost space."""
    text: str
    weights: Dict[str, float]  # e1..e7 → weight (0..1)
    dominant_axis: str         # e.g. "e1"
    cd_step: float             # weighted average cdStep
    friction_cost: float       # Γ(phrase) = Σ wᵢ · Γ(eᵢ)
    tree_fragment: str         # EMLTree shape description
    confidence: float          # based on marker density


def segment_phrases(thinking_block: str) -> List[str]:
    """Segment a thinking block into phrases.

    Splits on sentence boundaries and list items.
    GAP: This is a simple regex split. A proper NLP segmenter would
    handle subordinating clauses, parentheticals, and code blocks.
    """
    # Remove code blocks
    text = re.sub(r'```.*?```', ' [code] ', thinking_block, flags=re.DOTALL)
    # Remove inline code
    text = re.sub(r'`[^`]+`', ' [code] ', text)
    # Split on sentence boundaries and newlines
    raw = re.split(r'(?<=[.!?])\s+|\n\s*', text)
    # Clean and filter
    phrases = []
    for p in raw:
        p = p.strip().strip('-').strip('*').strip()
        if len(p) > 5:  # skip trivial fragments
            phrases.append(p)
    return phrases


def classify_phrase(phrase: str) -> PhraseEntry:
    """Map a phrase to a 7D weight vector in the NodeCost space.

    The weights are computed from the density of linguistic markers
    for each octonion basis vector. The phrase is mapped to a
    CONTINUOUS position — not a discrete LogicType.

    GAP: This heuristic uses keyword matching. The 35B LLM could
    provide finer-grained classification by reading each phrase and
    outputting a 7D weight vector based on semantic understanding.
    """
    text_lower = phrase.lower()
    words = set(text_lower.split())
    total_markers = 0

    weights: Dict[str, float] = {}
    for axis, info in BASIS_VECTORS.items():
        # Count marker hits
        hits = sum(1 for m in info["markers"] if m in text_lower)
        # Weight = hit density (normalized by phrase length)
        weight = hits / max(len(words), 1) * 10  # scale up
        weight = min(weight, 1.0)  # cap at 1.0
        weights[axis] = weight
        total_markers += hits

    # If no markers found, default to e1 (Classical — the null configuration)
    if total_markers == 0:
        weights["e1"] = 0.5  # weak default

    # Normalize weights to sum to 1
    total = sum(weights.values())
    if total > 0:
        weights = {k: v / total for k, v in weights.items()}
    else:
        weights = {"e1": 1.0}

    # Find dominant axis
    dominant = max(weights, key=lambda k: weights[k])

    # Compute weighted cdStep (continuous!)
    weighted_cd = sum(
        weights[axis] * BASIS_VECTORS[axis]["cd_step"]
        for axis in weights
    )

    # Compute continuous friction cost Γ(phrase) = Σ wᵢ · Γ(eᵢ)
    gamma = sum(
        weights[axis] * friction_density_at(BASIS_VECTORS[axis]["cd_step"])
        for axis in weights
    )

    # Determine tree fragment from dominant axis
    cd = BASIS_VECTORS[dominant]["cd_step"]
    if cd <= 1:
        tree_fragment = "LEAF"
    elif cd == 2:
        tree_fragment = "node(LEAF, LEAF)"
    elif cd == 3:
        tree_fragment = "node(LEAF, node(LEAF, LEAF))"
    else:  # cd >= 4
        tree_fragment = "node(node(LEAF, LEAF), LEAF)"

    # Confidence based on marker density
    confidence = min(total_markers / max(len(words), 1) * 5, 1.0)

    return PhraseEntry(
        text=phrase,
        weights=weights,
        dominant_axis=dominant,
        cd_step=weighted_cd,
        friction_cost=gamma,
        tree_fragment=tree_fragment,
        confidence=confidence,
    )


def build_glossary(thinking_blocks: List[str]) -> List[PhraseEntry]:
    """Build a glossary from a list of thinking blocks.

    Each block is segmented into phrases, and each phrase is classified
    into the 7D NodeCost space. The result is a continuous Friction
    Lagrangian map over the phrase space.
    """
    glossary: List[PhraseEntry] = []
    for block in thinking_blocks:
        phrases = segment_phrases(block)
        for phrase in phrases:
            entry = classify_phrase(phrase)
            glossary.append(entry)
    return glossary


def friction_lagrangian_map(glossary: List[PhraseEntry]) -> Dict:
    """Summarize the continuous Friction Lagrangian map.

    Instead of 4 discrete curves, this produces a distribution of
    continuous positions in the 7D NodeCost space.
    """
    # Cost distribution
    costs = [e.friction_cost for e in glossary]
    cost_hist = Counter()
    for c in costs:
        bucket = round(c)
        cost_hist[bucket] += 1

    # Axis distribution
    axis_dist = Counter(e.dominant_axis for e in glossary)

    # cdStep distribution (continuous)
    cd_steps = [e.cd_step for e in glossary]
    cd_hist = Counter()
    for cd in cd_steps:
        bucket = round(cd * 2) / 2  # 0.5 resolution
        cd_hist[bucket] += 1

    # Tree fragment distribution
    tree_dist = Counter(e.tree_fragment for e in glossary)

    # Average weights per axis
    avg_weights = {}
    for axis in BASIS_VECTORS:
        avg_weights[axis] = sum(e.weights.get(axis, 0) for e in glossary) / len(glossary)

    return {
        "total_phrases": len(glossary),
        "cost_distribution": dict(sorted(cost_hist.items())),
        "axis_distribution": dict(axis_dist.most_common()),
        "cdstep_distribution": dict(sorted(cd_hist.items())),
        "tree_fragment_distribution": dict(tree_dist.most_common()),
        "average_weights": avg_weights,
        "min_cost": min(costs) if costs else 0,
        "max_cost": max(costs) if costs else 0,
        "mean_cost": sum(costs) / len(costs) if costs else 0,
        "barrier_crossed": sum(1 for c in costs if c > STRUT_WEIGHT_SQ),
        "barrier_rate": sum(1 for c in costs if c > STRUT_WEIGHT_SQ) / max(len(costs), 1),
    }


if __name__ == "__main__":
    import json
    import sys
    import os

    PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sys.path.insert(0, PROJECT_ROOT)

    # Load traces
    traces_path = os.path.join(PROJECT_ROOT, "reasoning_library", "traces.jsonl")
    traces = [json.loads(l) for l in open(traces_path) if l.strip()]

    print(f"Loading {len(traces)} traces...")
    thinking_blocks = [t["thinking_block"] for t in traces if t.get("thinking_block")]

    print(f"Building glossary from {len(thinking_blocks)} thinking blocks...")
    glossary = build_glossary(thinking_blocks)

    print(f"Classified {len(glossary)} phrases into 7D NodeCost space\n")

    # Show the continuous Friction Lagrangian map
    flm = friction_lagrangian_map(glossary)

    print("=" * 60)
    print("CONTINUOUS FRICTION LAGRANGIAN MAP")
    print("=" * 60)
    print(f"\nTotal phrases: {flm['total_phrases']}")
    print(f"Cost range: {flm['min_cost']:.1f} — {flm['max_cost']:.1f}")
    print(f"Mean cost:  {flm['mean_cost']:.1f}")
    print(f"Barrier crossings (Γ > 16): {flm['barrier_crossed']} ({100*flm['barrier_rate']:.1f}%)")

    print(f"\n─ Cost distribution (Γ buckets) ─")
    for cost, count in flm["cost_distribution"].items():
        bar = "█" * min(count, 50)
        label = f"Γ={cost:3.0f}"
        barrier_marker = " ← BARRIER" if cost == 16 else ""
        print(f"  {label}  {count:4d} {bar}{barrier_marker}")

    print(f"\n─ Continuous cdStep distribution ─")
    for cd, count in flm["cdstep_distribution"].items():
        bar = "█" * min(count, 50)
        print(f"  cdStep={cd:.1f}  {count:4d} {bar}")

    print(f"\n─ Dominant axis distribution ─")
    for axis, count in flm["axis_distribution"].items():
        info = BASIS_VECTORS[axis]
        pct = 100 * count / flm["total_phrases"]
        bar = "█" * int(pct / 2)
        print(f"  {axis} ({info['name']:25s}) {count:4d} ({pct:5.1f}%) {bar}")

    print(f"\n─ Average weight per axis ─")
    for axis, avg in sorted(flm["average_weights"].items()):
        info = BASIS_VECTORS[axis]
        bar = "█" * int(avg * 50)
        print(f"  {axis} {info['name']:25s} w={avg:.3f} {bar}")

    print(f"\n─ Tree fragment distribution ─")
    for tree, count in flm["tree_fragment_distribution"].items():
        print(f"  {tree:30s} {count:4d}")

    # Show sample phrases at different cost levels
    print(f"\n─ Sample phrases at different Γ levels ─")
    sorted_glossary = sorted(glossary, key=lambda e: e.friction_cost)
    samples = [
        ("Lowest Γ (CFG, associative)", sorted_glossary[:3]),
        ("Mid Γ (near barrier)", [e for e in sorted_glossary if 14 < e.friction_cost < 18][:3]),
        ("Highest Γ (CSG, non-associative)", sorted_glossary[-3:]),
    ]
    for label, entries in samples:
        print(f"\n  {label}:")
        for e in entries:
            print(f"    Γ={e.friction_cost:5.1f}  cd={e.cd_step:.1f}  {e.dominant_axis}  "
                  f"conf={e.confidence:.2f}  \"{e.text[:80]}\"")

    print("\n" + "=" * 60)
    print("This is the CONTINUOUS Friction Lagrangian.")
    print("Each phrase maps to a weighted position in 7D NodeCost space,")
    print("not to 1 of 4 discrete coupling signatures.")
    print("The glossary is: phrase → (7D position, Γ, tree fragment, confidence)")
