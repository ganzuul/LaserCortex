"""Clustering for reasoning traces using embedding similarity.

Groups similar thinking blocks into clusters using agglomerative clustering
with a cosine similarity threshold. Each cluster represents a reasoning
pattern that can be distilled into a reusable script.
"""


from dataclasses import dataclass, field
from collections import Counter
from .models import SessionReasoningTrace
from .embedder import cosine_similarity


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


def _cluster_dominant_intent(cluster: TraceCluster,
                             traces: list[SessionReasoningTrace]) -> str:
    """Compute the dominant intent for a cluster given its traces."""
    intents = [traces[i].intent_category for i in cluster.members]
    return Counter(intents).most_common(1)[0][0]


def _cluster_all_tags(cluster: TraceCluster,
                      traces: list[SessionReasoningTrace]) -> list[str]:
    """Compute the union of all domain tags in a cluster."""
    tags_set: set[str] = set()
    for i in cluster.members:
        tags_set.update(traces[i].domain_tags)
    return sorted(tags_set)


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

    # Finalize: compute centroid, intent, and tags directly
    for c in clusters:
        c.centroid = _average_embedding(c.members, traces)
        c.intent_category = _cluster_dominant_intent(c, traces)
        c.domain_tags = _cluster_all_tags(c, traces)

    return [c for c in clusters if c.size >= min_cluster_size]
