#!/usr/bin/env python3
"""Milestone 1: Build the trace × atom activation matrix.

For each reasoning trace and each atom from data/reinforcement_atoms.json,
compute a non-negative activation score by embedding both the trace's
thinking block and the atom's description with the local bge-m3 server and
computing cosine similarity.

To prevent any single ontology source from dominating the NMF input, we apply
per-source robust normalization (95th-percentile scaling) so each of
FrameNet, VerbNet, manpages, PROV-O, and P-PLAN contributes on a comparable
scale.

Outputs:
  data/trace_atom_matrix.npz       sparse CSR matrix (normalized)
  data/trace_atom_matrix_raw.npz   sparse CSR matrix (raw clipped cosine)
  data/trace_atom_matrix_metadata.json  row IDs, atom IDs, source stats

Usage (venv):
    .venv/bin/python scripts/m1_build_atom_matrix.py
"""
from __future__ import annotations

import json
import logging
import os
import time
import urllib.request
from pathlib import Path

import numpy as np
from scipy import sparse

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
LOGFILE = DATA_DIR / "m1_build_atom_matrix.log"

ATOMS_PATH = DATA_DIR / "reinforcement_atoms.json"
TRACES_PATH = PROJECT_ROOT / "reasoning_library" / "traces.jsonl"
OUTPUT_MATRIX = DATA_DIR / "trace_atom_matrix.npz"
OUTPUT_RAW = DATA_DIR / "trace_atom_matrix_raw.npz"
OUTPUT_META = DATA_DIR / "trace_atom_matrix_metadata.json"

EMBED_URL = "http://localhost:8082/v1/embeddings"
BATCH_SIZE = 2
MAX_LEN = 500
# Hard client-side truncation to keep payloads well below problematic lengths.
CLIENT_MAX_CHARS = 1500

CACHE_TRACE_EMB = DATA_DIR / "trace_embeddings.npy"
CACHE_ATOM_EMB = DATA_DIR / "atom_embeddings.npy"


def setup_logging() -> None:
    """Route diagnostics to a log file; keep console concise."""
    DATA_DIR.mkdir(exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[
            logging.FileHandler(LOGFILE, mode="w"),
        ],
    )


def embed_texts(
    texts: list[str],
    cache_path: Path,
    label: str,
) -> np.ndarray:
    """Embed a list of texts via local bge-m3, with resume from .npy cache.

    Fail-fast: if any batch returns an HTTP error, raise immediately.
    Verbose diagnostics go to the log file; console prints concise progress.
    """
    if cache_path.exists():
        print(f"  Loading cached {label} embeddings from {cache_path}", flush=True)
        return np.load(cache_path).astype(np.float32)

    # Truncate to keep payloads small and predictable.
    safe_texts = [t[:CLIENT_MAX_CHARS] for t in texts]

    embeddings = []
    total = len(safe_texts)
    start_time = time.time()
    print(f"  Embedding {total} {label} texts (batch={BATCH_SIZE})...", flush=True)

    for i in range(0, total, BATCH_SIZE):
        batch = safe_texts[i:i + BATCH_SIZE]
        payload = json.dumps(
            {"input": batch, "max_length": MAX_LEN},
            ensure_ascii=False,
        ).encode("utf-8")
        req = urllib.request.Request(
            EMBED_URL,
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.loads(resp.read())
            for item in data["data"]:
                embeddings.append(item["embedding"])
        except Exception as e:
            logging.error("embedding batch %d/%d failed: %s", i, total, e)
            raise RuntimeError(
                f"Failed to embed {label} batch {i}/{total}: {e}. "
                f"Check embedding server health and see {LOGFILE}."
            ) from e

        if (i // BATCH_SIZE + 1) % 50 == 0:
            elapsed = time.time() - start_time
            rate = (i + len(batch)) / max(elapsed, 0.001)
            remaining = (total - i - len(batch)) / max(rate, 0.001)
            print(f"    Progress {i + len(batch):5d}/{total}: "
                  f"{rate:.1f} texts/s, ~{remaining:.0f}s left", flush=True)

    arr = np.array(embeddings, dtype=np.float32)
    np.save(cache_path, arr)
    print(f"  Saved {label} embeddings ({arr.shape}) to {cache_path}", flush=True)
    return arr


def cosine_matrix(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Pairwise cosine similarity between rows of a and rows of b."""
    a_norm = a / (np.linalg.norm(a, axis=1, keepdims=True) + 1e-10)
    b_norm = b / (np.linalg.norm(b, axis=1, keepdims=True) + 1e-10)
    return a_norm @ b_norm.T


def source_normalize(
    matrix: np.ndarray,
    source_indices: dict[str, list[int]],
    percentile: float = 95.0,
) -> tuple[np.ndarray, dict]:
    """Normalize each source block by its percentile maximum.

    Returns the normalized matrix and a dict of per-source statistics.
    """
    normalized = matrix.copy()
    stats = {}
    for source, cols in source_indices.items():
        block = normalized[:, cols]
        vmax = float(np.percentile(block, percentile))
        if vmax <= 1e-6:
            vmax = 1.0
        normalized[:, cols] = block / vmax
        stats[source] = {
            "columns": len(cols),
            "percentile": percentile,
            "scale_value": round(vmax, 6),
            "mean_after": round(float(normalized[:, cols].mean()), 6),
            "max_after": round(float(normalized[:, cols].max()), 6),
        }
    return normalized, stats


def main():
    setup_logging()
    logging.info("Milestone 1 starting")

    print("=" * 70)
    print("Milestone 1: Build trace × atom activation matrix")
    print("=" * 70)

    if not ATOMS_PATH.exists():
        raise FileNotFoundError(f"Run M0 first: {ATOMS_PATH}")
    if not TRACES_PATH.exists():
        raise FileNotFoundError(f"Traces missing: {TRACES_PATH}")

    # ── Load atoms ────────────────────────────────────────────────────
    print("\nLoading atoms...")
    with ATOMS_PATH.open() as f:
        atoms_data = json.load(f)
    atoms = atoms_data["atoms"]
    atom_ids = [a["atom_id"] for a in atoms]
    atom_sources = [a["source"] for a in atoms]
    atom_texts = [f"{a['label']}: {a['description']}" for a in atoms]
    print(f"  Atoms: {len(atoms)}")

    # Build source-to-column-index mapping
    source_indices: dict[str, list[int]] = {}
    for i, src in enumerate(atom_sources):
        source_indices.setdefault(src, []).append(i)
    for src, cols in source_indices.items():
        print(f"    {src:12s}: {len(cols):3d} columns")

    # ── Load traces ───────────────────────────────────────────────────
    print("\nLoading traces...")
    traces = []
    trace_texts = []
    trace_ids = []
    with TRACES_PATH.open() as f:
        for i, line in enumerate(f):
            d = json.loads(line)
            traces.append(d)
            trace_ids.append(f"trace_{i:04d}")
            text = d.get("thinking_block", "") or ""
            trace_texts.append(text[:CLIENT_MAX_CHARS])
    print(f"  Traces: {len(traces)}")

    # Invalidate stale caches if counts changed (e.g., previous partial run).
    for cache_path, expected in [(CACHE_TRACE_EMB, len(traces)),
                                  (CACHE_ATOM_EMB, len(atoms))]:
        if cache_path.exists():
            cached = np.load(cache_path)
            if cached.shape[0] != expected:
                logging.warning("stale cache %s shape %s != expected %d; removing",
                                cache_path, cached.shape, expected)
                cache_path.unlink()
                print(f"  Removed stale cache {cache_path}", flush=True)

    # ── Embed traces ──────────────────────────────────────────────────
    print("\nEmbedding traces with bge-m3...", flush=True)
    trace_embeddings = embed_texts(trace_texts, CACHE_TRACE_EMB, "trace")
    print(f"  Trace embedding shape: {trace_embeddings.shape}", flush=True)

    # ── Embed atoms ───────────────────────────────────────────────────
    print("\nEmbedding atoms with bge-m3...", flush=True)
    atom_embeddings = embed_texts(atom_texts, CACHE_ATOM_EMB, "atom")
    print(f"  Atom embedding shape: {atom_embeddings.shape}", flush=True)

    # ── Compute cosine activation matrix ──────────────────────────────
    print("\nComputing cosine activation matrix...")
    activation = cosine_matrix(trace_embeddings, atom_embeddings)
    print(f"  Activation matrix shape: {activation.shape}")

    # Clip negative similarities to keep NMF valid.
    activation_raw = np.clip(activation, 0.0, 1.0)
    print(f"  Raw clipped mean: {activation_raw.mean():.4f}")
    print(f"  Raw clipped std:  {activation_raw.std():.4f}")
    print(f"  Raw clipped max:  {activation_raw.max():.4f}")

    # ── Per-source robust normalization ───────────────────────────────
    print("\nApplying per-source 95th-percentile normalization...")
    activation_norm, source_stats = source_normalize(
        activation_raw, source_indices, percentile=95.0
    )
    for src, st in source_stats.items():
        print(f"    {src:12s}: scale={st['scale_value']:.4f}, "
              f"mean_after={st['mean_after']:.4f}, max_after={st['max_after']:.4f}")

    # ── Optional: sparsify small values to keep matrix manageable ──────
    sparsity_threshold = 0.01  # drop values below 1% of normalized scale
    activation_sparse = activation_norm.copy()
    activation_sparse[activation_sparse < sparsity_threshold] = 0.0
    nnz_fraction = np.count_nonzero(activation_sparse) / activation_sparse.size
    print(f"\nAfter threshold {sparsity_threshold}: {nnz_fraction:.2%} non-zero")

    # ── Save sparse matrices ──────────────────────────────────────────
    print("\nSaving matrices...")
    sparse_raw = sparse.csr_matrix(activation_raw)
    sparse_norm = sparse.csr_matrix(activation_sparse)

    sparse.save_npz(OUTPUT_RAW, sparse_raw)
    sparse.save_npz(OUTPUT_MATRIX, sparse_norm)
    print(f"  Saved {OUTPUT_RAW}")
    print(f"  Saved {OUTPUT_MATRIX}")

    # ── Save metadata ─────────────────────────────────────────────────
    metadata = {
        "trace_count": len(traces),
        "atom_count": len(atoms),
        "atom_ids": atom_ids,
        "trace_ids": trace_ids,
        "atom_sources": atom_sources,
        "source_indices": source_indices,
        "source_stats": source_stats,
        "batch_size": BATCH_SIZE,
        "max_length": MAX_LEN,
        "sparsity_threshold": sparsity_threshold,
        "embedding_model": "BAAI/bge-m3",
        "embedding_dimension": 1024,
    }
    with OUTPUT_META.open("w") as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    print(f"  Saved {OUTPUT_META}")

    print("\n" + "=" * 70)
    print("Milestone 1 complete.")
    print("=" * 70)


if __name__ == "__main__":
    main()
