"""Clustering for reasoning traces using embedding similarity.

Groups similar thinking blocks into clusters using agglomerative clustering
with a cosine similarity threshold. Each cluster represents a reasoning
pattern that can be distilled into a reusable script.
"""


from __future__ import annotations
import sys, os
if __package__ is None:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dataclasses import dataclass, field
from collections import Counter
from models import SessionReasoningTrace
from embedder import cosine_similarity



@dataclass
class TraceCluster:
    """A cluster of similar reasoning traces."""
    cluster_id: int
    members: list[int] = field(default_factory=list)
    centroid: list[float] = field(default_factory=list)
    intent_category: str = ""
    domain_tags: list[str] = field(default_factory=list)

    @property
    def size(self) -> int:
        return len(self.members)

    @property
    def dominant_intent(self) -> str:
        if not self.members:
            return ""
        intents = [self._traces[i].intent_category for i in self.members]
        return Counter(intents).most_common(1)[0][0]

    @property
    def all_tags(self) -> list[str]:
        if not self.members:
            return []
        tags_set: set[str] = set()
        for i in self.members:
            tags_set.update(self._traces[i].domain_tags)
        return sorted(tags_set)

    def set_traces(self, traces: list[SessionReasoningTrace]):
        """Set the traces reference (needed for dominant_intent/all_tags)."""
        self._traces = traces


def _average_embedding(member_indices: list[int],
                       traces: list[SessionReasoningTrace]) -> list[float]:
    """Compute the centroid (average) embedding for a set of traces."""
    if not member_indices:
        return []

    first_emb = traces[member_indices[0]].embedding if traces and member_indices else None
    dim = len(first_emb) if first_emb else 0
    if dim == 0:
        return []

    centroid = [0.0] * dim
    count = 0
    for idx in member_indices:
        emb = traces[idx].embedding
        if emb and len(emb) == dim:
            for d in range(dim):
                centroid[d] += emb[d]
            count += 1

    if count == 0:
        return [0.0] * dim

    for d in range(dim):
        centroid[d] /= count
    return centroid


def cluster_traces(traces: list[SessionReasoningTrace],
                   min_cluster_size: int = 3,
                   similarity_threshold: float = 0.65) -> list[TraceCluster]:
    """Cluster traces by embedding similarity.

    Uses a single-pass greedy approach: for each unassigned trace, find the
    nearest unassigned trace with a matching intent and merge. Repeats until
    all traces are assigned.

    Args:
        traces: List of traces with embeddings computed
        min_cluster_size: Minimum number of traces per cluster (default: 3)
        similarity_threshold: Minimum cosine similarity to merge (default: 0.65)

    Returns:
        List of TraceCluster objects (only those >= min_cluster_size)
    """
    if len(traces) < min_cluster_size:
        return []

    n = len(traces)
    assigned = [False] * n
    clusters: list[TraceCluster] = []
    cid = 0

    for i in range(n):
        if assigned[i]:
            continue

        # Start a new cluster with trace i
        cluster = TraceCluster(cluster_id=cid, members=[i])
        cluster.set_traces(traces)
        assigned[i] = True

        # Find nearest unassigned traces with matching intent
        for j in range(i + 1, n):
            if assigned[j]:
                continue

            # Check intent compatibility
            intent_i = traces[i].intent_category or "general_problem_solving"
            intent_j = traces[j].intent_category or "general_problem_solving"
            if intent_i != intent_j and not (
                intent_i == "general_problem_solving" or intent_j == "general_problem_solving"
            ):
                continue

            emb_i = traces[i].embedding
            emb_j = traces[j].embedding
            if not emb_i or not emb_j:
                continue
            sim = cosine_similarity(emb_i, emb_j)
            if sim >= similarity_threshold:
                cluster.members.append(j)
                assigned[j] = True

        clusters.append(cluster)
        cid += 1

    # Finalize
    for c in clusters:
        c.centroid = _average_embedding(c.members, traces)
        c.intent_category = c.dominant_intent
        c.domain_tags = c.all_tags

    return [c for c in clusters if c.size >= min_cluster_size]
