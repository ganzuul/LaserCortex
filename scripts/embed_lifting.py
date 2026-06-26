#!/usr/bin/env python3
"""Embedding-based phrase → EMLTree lifting.

Uses bge-m3 embeddings (1024-dim) to map NL phrases to the 6 CSG grammar
categories from docs/reasoning primitives/training_examples.md.

The 6 categories are the CFG productions — the interface between NormCode
and LaserCortex's grammar. Each category has:
- An anchor text (from training_examples.md)
- An EMLTree shape (the CFG production)
- A VSM system assignment

The lifting:
1. Embed the 6 anchor texts → 6 × 1024-dim anchor vectors
2. Embed each NL phrase → 1024-dim phrase vector
3. Cosine similarity(phrase, anchor_i) → weight_i
4. The 6D weight vector determines the EMLTree shape
5. Γ(phrase) = Σ wᵢ · Γ(category_i)

This replaces the keyword heuristics in phrase_lagrangian.py with
semantic similarity. The embedding model IS the glossary.
"""
from __future__ import annotations

import json
import math
import os
import re
import sys
import time
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple

import requests
import numpy as np

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMBED_URL = "http://localhost:8082/v1/embeddings"

# ═══════════════════════════════════════════════════════════════════════
# The 6 CSG grammar categories — the CFG productions
# From docs/reasoning primitives/training_examples.md
# ═══════════════════════════════════════════════════════════════════════

CATEGORIES = [
    {
        "name": "temporalMonad",
        "anchors": [
            "Let me begin by exploring the problem space and understanding what we are working with.",
            "I should start by taking stock of the current situation before proceeding.",
            "I need to first understand the context and constraints before making changes.",
            "Let us now turn to the next step in the reasoning process.",
            "I will now examine the structure of this problem more carefully.",
        ],
        "tree_shape": "Node(Leaf, Node(Leaf, Leaf))",
        "vsm": "S4",
        "description": "temporal framing — opens a reasoning step",
        "cd_step": 2,
    },
    {
        "name": "computationAction",
        "anchors": [
            "Run the experiment to compute the result and produce concrete output data.",
            "Execute the verification tool to check whether the certificate contraction path is valid.",
            "Parse the input file and build the output structure from the parsed components.",
            "Search the codebase for all references to this function and list the results.",
            "Lift the inference into the formal layer by calling the bridge lift operation.",
            "Ground the certificate back into the decision layer by decomposing the contraction path.",
        ],
        "tree_shape": "Node(Node(Leaf, Leaf), Leaf)",
        "vsm": "S1",
        "description": "tool invocation — the operational verb",
        "cd_step": 3,
    },
    {
        "name": "scope",
        "anchors": [
            "Run a targeted experiment focusing only on the specific module that is failing.",
            "First, check the most critical constraint before expanding the search.",
            "Carefully examine exactly the boundary condition where the error occurs.",
            "Limit the search to precisely the files that were modified in this commit.",
            "Apply this change only to the specific case mentioned, not globally.",
        ],
        "tree_shape": "Node(Leaf, Leaf)",
        "vsm": "S3",
        "description": "resource constraint — bounds the action",
        "cd_step": 1,
    },
    {
        "name": "exploration",
        "anchors": [
            "Investigate the Tamari lattice contraction structure to understand how trees contract.",
            "Explore the proof architecture and understand how the theorems connect to each other.",
            "Understand the codebase structure and how the different modules interact.",
            "Examine what happens when the friction barrier is crossed at the CD 2 to 3 boundary.",
            "Look into the algebraic structure of the split octonion and its basis vectors.",
            "Study how the generation and collapse duality produces candidate structures.",
        ],
        "tree_shape": "Node(Node(Leaf, Leaf), Node(Leaf, Leaf))",
        "vsm": "S4",
        "description": "search space — the domain concept being explored",
        "cd_step": 3,
    },
    {
        "name": "idempotentTarget",
        "anchors": [
            "I really want to make sure this is correct before moving forward.",
            "The key insight is definitely that the certificate must verify independently.",
            "This is certainly the right approach because the contraction path is decidable.",
            "I am confident that this result holds and the proof is complete.",
            "This must be exactly right — the system cannot proceed without certainty.",
        ],
        "tree_shape": "Leaf",
        "vsm": "S5",
        "description": "will/commitment — the idempotent seal",
        "cd_step": 0,
    },
    {
        "name": "certifiedGeometry",
        "anchors": [
            "Figure this out by verifying that the contraction path exists from source to target.",
            "The certificate is valid because the proof carries a verified contraction path.",
            "The proof is complete when the tree reaches its right-comb normal form.",
            "The contraction path exists and decidable contracts to holds for this tree.",
            "This is correct because the audit channel independently verifies the result.",
            "The result holds because the friction barrier prevents invalid crossings.",
        ],
        "tree_shape": "Node(Leaf, Node(Leaf, Node(Leaf, Leaf)))",
        "vsm": "S3*",
        "description": "verification goal — the certified outcome",
        "cd_step": 2,
    },
]

STRUT_WEIGHT = 4
BARRIER = STRUT_WEIGHT * STRUT_WEIGHT  # 16


def friction_density(cd_step: int) -> float:
    """Γ(k) = k + strut_weight × assocDefect(k)."""
    assoc = 0 if cd_step <= 2 else STRUT_WEIGHT
    return float(cd_step + STRUT_WEIGHT * assoc)


# ═══════════════════════════════════════════════════════════════════════
# Embedding operations
# ═══════════════════════════════════════════════════════════════════════

def embed_texts(texts: List[str], batch_size: int = 2, max_len: int = 500) -> np.ndarray:
    """Embed a list of texts using bge-m3. Returns (N, 1024) array.

    SAFETY (INC-1): batch_size=2 and max_len=500 to avoid OOM on the
    embedding server. The ONNX int8 server has unbounded memory under
    concurrency with large batches — see SAFETY.md INC-1.
    """
    all_embeddings = []
    for i in range(0, len(texts), batch_size):
        batch = [t[:max_len] for t in texts[i:i + batch_size]]
        resp = requests.post(EMBED_URL, json={
            "model": "bge-m3",
            "input": batch,
        })
        resp.raise_for_status()
        data = resp.json()
        for item in data["data"]:
            all_embeddings.append(item["embedding"])
    return np.array(all_embeddings)


def cosine_sim(a: np.ndarray, b: np.ndarray) -> float:
    """Cosine similarity between two vectors."""
    dot = np.dot(a, b)
    norm = np.linalg.norm(a) * np.linalg.norm(b)
    if norm == 0:
        return 0.0
    return float(dot / norm)


# ═══════════════════════════════════════════════════════════════════════
# Phrase segmentation
# ═══════════════════════════════════════════════════════════════════════

def segment_phrases(thinking_block: str) -> List[str]:
    """Segment a thinking block into phrases."""
    text = re.sub(r'```.*?```', ' [code] ', thinking_block, flags=re.DOTALL)
    text = re.sub(r'`[^`]+`', ' [code] ', text)
    raw = re.split(r'(?<=[.!?])\s+|\n\s*', text)
    phrases = []
    for p in raw:
        p = p.strip().strip('-').strip('*').strip()
        if len(p) > 5:
            phrases.append(p)
    return phrases


# ═══════════════════════════════════════════════════════════════════════
# Lifting: phrase → 6D weights → EMLTree shape → Γ
# ═══════════════════════════════════════════════════════════════════════

@dataclass
class LiftedPhrase:
    """A phrase lifted to the 6D grammar category space."""
    text: str
    weights: Dict[str, float]  # category_name → weight
    dominant_category: str
    tree_shape: str
    cd_step: float
    friction_cost: float
    confidence: float  # max weight (how strongly it matches one category)


def lift_phrase(
    phrase_vec: np.ndarray,
    anchor_vecs: Dict[str, np.ndarray],
    phrase_text: str,
) -> LiftedPhrase:
    """Lift a single phrase vector to the 6D grammar space."""
    # Compute cosine similarity to each category's anchor vectors
    raw_weights: Dict[str, float] = {}
    for cat in CATEGORIES:
        # Use max similarity across all anchors for this category
        sims = []
        for anchor_text in cat["anchors"]:
            # We need the anchor embedding — precomputed in anchor_vecs
            key = f"{cat['name']}:{anchor_text}"
            if key in anchor_vecs:
                sims.append(cosine_sim(phrase_vec, anchor_vecs[key]))
        raw_weights[cat["name"]] = max(sims) if sims else 0.0

    # Softmax normalize to get a probability distribution
    max_w = max(raw_weights.values())
    exp_weights = {k: math.exp((v - max_w) * 4) for k, v in raw_weights.items()}  # temperature=4
    total = sum(exp_weights.values())
    if total > 0:
        weights = {k: v / total for k, v in exp_weights.items()}
    else:
        weights = {k: 1.0 / len(CATEGORIES) for k in raw_weights}

    # Find dominant category
    dominant = max(weights, key=lambda k: weights[k])

    # Get tree shape and cd_step from dominant category
    cat_info = next(c for c in CATEGORIES if c["name"] == dominant)
    tree_shape = cat_info["tree_shape"]
    cd_step = cat_info["cd_step"]

    # Weighted cd_step (continuous)
    weighted_cd = sum(
        weights[c["name"]] * c["cd_step"]
        for c in CATEGORIES
    )

    # Weighted friction cost
    gamma = sum(
        weights[c["name"]] * friction_density(c["cd_step"])
        for c in CATEGORIES
    )

    confidence = weights[dominant]

    return LiftedPhrase(
        text=phrase_text,
        weights=weights,
        dominant_category=dominant,
        tree_shape=tree_shape,
        cd_step=weighted_cd,
        friction_cost=gamma,
        confidence=confidence,
    )


# ═══════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════

def main():
    import json

    traces_path = os.path.join(PROJECT_ROOT, "reasoning_library", "traces.jsonl")
    traces = [json.loads(l) for l in open(traces_path) if l.strip()]
    print(f"Loading {len(traces)} traces...")

    # Segment all phrases
    all_phrases: List[str] = []
    for t in traces:
        block = t.get("thinking_block", "")
        if block:
            all_phrases.extend(segment_phrases(block))

    # Deduplicate to save embedding calls
    unique_phrases = list(set(all_phrases))
    print(f"Total phrases: {len(all_phrases)} (unique: {len(unique_phrases)})")

    # Embed all anchor texts
    print("Embedding 6 category anchors...")
    anchor_texts = []
    anchor_keys = []
    for cat in CATEGORIES:
        for anchor in cat["anchors"]:
            anchor_texts.append(anchor)
            anchor_keys.append(f"{cat['name']}:{anchor}")

    anchor_vecs_raw = embed_texts(anchor_texts)
    anchor_vecs = {key: anchor_vecs_raw[i] for i, key in enumerate(anchor_keys)}

    # Also compute per-category centroid (average of all anchors)
    category_centroids: Dict[str, np.ndarray] = {}
    for cat in CATEGORIES:
        vecs = [anchor_vecs[f"{cat['name']}:{a}"] for a in cat["anchors"]]
        category_centroids[cat["name"]] = np.mean(vecs, axis=0)

    # Embed all unique phrases (batched)
    print(f"Embedding {len(unique_phrases)} unique phrases (batch=2, max_len=500)...")
    t0 = time.time()
    phrase_vecs_raw = embed_texts(unique_phrases, batch_size=2, max_len=500)
    t1 = time.time()
    print(f"  Embedded in {t1-t0:.1f}s ({len(unique_phrases)/(t1-t0):.0f} phrases/s)")

    phrase_to_vec = {p: phrase_vecs_raw[i] for i, p in enumerate(unique_phrases)}

    # Lift all phrases
    print("Lifting phrases to 6D grammar space...")
    lifted: List[LiftedPhrase] = []
    for phrase in all_phrases:
        vec = phrase_to_vec.get(phrase)
        if vec is not None:
            lifted.append(lift_phrase(vec, anchor_vecs, phrase))

    print(f"Lifted {len(lifted)} phrases\n")

    # ═══════════════════════════════════════════════════════════════════
    # Report
    # ═══════════════════════════════════════════════════════════════════

    print("=" * 70)
    print("EMBEDDING-BASED LIFTING: NL → 6D GRAMMAR → EMLTree")
    print("=" * 70)

    # Category distribution
    cat_dist = Counter(l.dominant_category for l in lifted)
    print(f"\n─ Dominant category distribution (CFG productions) ─")
    for cat in CATEGORIES:
        count = cat_dist.get(cat["name"], 0)
        pct = 100 * count / len(lifted)
        bar = "█" * int(pct / 2)
        print(f"  {cat['name']:22s} {cat['vsm']}  {count:5d} ({pct:5.1f}%) {bar}")
        print(f"    tree: {cat['tree_shape']}")

    # Cost distribution
    costs = [l.friction_cost for l in lifted]
    cost_hist = Counter()
    for c in costs:
        bucket = round(c)
        cost_hist[bucket] += 1
    print(f"\n─ Friction cost distribution (continuous Γ) ─")
    for cost in sorted(cost_hist):
        count = cost_hist[cost]
        bar = "█" * min(count, 50)
        marker = " ← BARRIER" if cost == 16 else ""
        print(f"  Γ={cost:3d}  {count:5d} {bar}{marker}")

    # Continuous cdStep
    cd_steps = [l.cd_step for l in lifted]
    cd_hist = Counter()
    for cd in cd_steps:
        bucket = round(cd * 2) / 2
        cd_hist[bucket] += 1
    print(f"\n─ Continuous cdStep distribution ─")
    for cd in sorted(cd_hist):
        count = cd_hist[cd]
        bar = "█" * min(count, 50)
        print(f"  cdStep={cd:.1f}  {count:5d} {bar}")

    # Average weights per category
    print(f"\n─ Average weight per category (semantic glossary) ─")
    for cat in CATEGORIES:
        avg_w = sum(l.weights[cat["name"]] for l in lifted) / len(lifted)
        bar = "█" * int(avg_w * 50)
        print(f"  {cat['name']:22s} w={avg_w:.3f} {bar}")

    # Confidence distribution
    confs = [l.confidence for l in lifted]
    conf_hist = Counter()
    for c in confs:
        bucket = round(c * 10) / 10
        conf_hist[bucket] += 1
    print(f"\n─ Confidence distribution (max category weight) ─")
    for conf in sorted(conf_hist):
        count = conf_hist[conf]
        bar = "█" * min(count, 50)
        print(f"  conf={conf:.1f}  {count:5d} {bar}")

    # Sample phrases at different cost levels
    print(f"\n─ Sample phrases at different Γ levels ─")
    sorted_lifted = sorted(lifted, key=lambda l: l.friction_cost)
    for label, entries in [
        ("Lowest Γ (grounded, CFG)", sorted_lifted[:5]),
        ("Near barrier (Γ ≈ 14-18)", [l for l in sorted_lifted if 14 < l.friction_cost < 18][:5]),
        ("Highest Γ (ungrounded, CSG)", sorted_lifted[-5:]),
    ]:
        print(f"\n  {label}:")
        for l in entries:
            top3 = sorted(l.weights.items(), key=lambda x: -x[1])[:3]
            w_str = " ".join(f"{n}:{w:.2f}" for n, w in top3)
            print(f"    Γ={l.friction_cost:5.1f}  cd={l.cd_step:.1f}  [{w_str}]")
            print(f"      \"{l.text[:100]}\"")

    # Tree shape distribution
    tree_dist = Counter(l.tree_shape for l in lifted)
    print(f"\n─ EMLTree shape distribution (CFG productions) ─")
    for tree, count in tree_dist.most_common():
        print(f"  {tree:45s} {count:5d}")

    # Summary
    print(f"\n{'=' * 70}")
    print(f"SUMMARY")
    print(f"{'=' * 70}")
    print(f"  Total phrases lifted:     {len(lifted)}")
    print(f"  Cost range:               {min(costs):.1f} — {max(costs):.1f}")
    print(f"  Mean cost:                {sum(costs)/len(costs):.1f}")
    print(f"  Barrier crossings (Γ>16): {sum(1 for c in costs if c > BARRIER)} ({100*sum(1 for c in costs if c > BARRIER)/len(costs):.1f}%)")
    print(f"  Mean confidence:          {sum(confs)/len(confs):.3f}")
    print(f"  Unique tree shapes:       {len(tree_dist)}")
    print(f"\n  The embedding model IS the glossary.")
    print(f"  Each phrase maps to a 6D weight vector over the CFG productions,")
    print(f"  giving a continuous position in the Friction Lagrangian.")


if __name__ == "__main__":
    main()
