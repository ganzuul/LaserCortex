"""Embedding for reasoning traces using the bge-m3 embedding server.

The bge-m3 server runs at http://localhost:8082 with an OpenAI-compatible API.
This module produces 1024-dim embeddings suitable for similarity search.
"""


from __future__ import annotations
import sys, os
if __package__ is None:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import http.client
import json
from models import SessionReasoningTrace



EMBED_SERVER_URL = "localhost"
EMBED_SERVER_PORT = 8082
EMBED_MODEL = "bge-m3"
EMBED_DIM = 1024


def _embed_batch(texts: list[str], url: str = EMBED_SERVER_URL,
                 port: int = EMBED_SERVER_PORT, model: str = EMBED_MODEL) -> list[list[float]]:
    """Send a batch of texts to the embedding server and return embeddings."""
    body = json.dumps({"model": model, "input": texts})
    headers = {"Content-Type": "application/json"}
    conn = http.client.HTTPConnection(url, port, timeout=30)
    try:
        conn.request("POST", "/v1/embeddings", body, headers)
        resp = conn.getresponse()
        data = json.loads(resp.read().decode())
        if "data" not in data:
            raise ValueError(f"Unexpected response: {json.dumps(data)[:200]}")
        return [d["embedding"] for d in data["data"]]
    finally:
        conn.close()


def embed_trace(trace: SessionReasoningTrace) -> list[float]:
    """Compute embedding for a single trace."""
    text = trace.embed_text()
    embeddings = _embed_batch([text])
    return embeddings[0]


def embed_batch(traces: list[SessionReasoningTrace]) -> list[list[float]]:
    """Compute embeddings for a batch of traces."""
    if not traces:
        return []

    texts = [t.embed_text() for t in traces]
    batch_size = 50
    all_embeddings: list[list[float]] = []

    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        try:
            embeddings = _embed_batch(batch)
            all_embeddings.extend(embeddings)
        except Exception as e:
            for j, text in enumerate(batch):
                try:
                    emb = _embed_batch([text])
                    all_embeddings.append(emb[0])
                except Exception:
                    all_embeddings.append([0.0] * EMBED_DIM)

    return all_embeddings


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compute cosine similarity between two vectors."""
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)
