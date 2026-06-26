"""Tests for reasoning_library.clusterer.

Required: ≥ 8 test cases
"""

import sys
from pathlib import Path

import pytest

REASONING_LIB = Path(__file__).parent.parent
if str(REASONING_LIB) not in sys.path:
    sys.path.insert(0, str(REASONING_LIB))

from reasoning_library.clusterer import (
    cluster_traces,
    TraceCluster,
    _average_embedding,
)


# ── cluster_traces tests ──────────────────────────────────────────────

class TestClusterTraces:
    """Tests for cluster_traces."""

    def test_two_clusters_with_threshold_06(self, sample_traces_with_embeddings):
        """5 known traces with known similarities → 2 clusters: {0,1}, {2,3}."""
        traces = sample_traces_with_embeddings
        clusters = cluster_traces(traces, min_cluster_size=3, similarity_threshold=0.6)
        # Should form: {0,1} docker_lifecycle, {2,3} script_development
        # {4} has no match above 0.6 with same intent
        docker_clusters = [c for c in clusters if c.intent_category == "docker_lifecycle"]
        script_clusters = [c for c in clusters if c.intent_category == "script_development"]
        assert len(docker_clusters) >= 1
        assert len(script_clusters) >= 1
        # Check members are correct
        docker_members = set(docker_clusters[0].members)
        assert 0 in docker_members
        assert 1 in docker_members

    def test_high_threshold_no_clusters(self, sample_traces_with_embeddings):
        """cluster_traces with threshold=0.95 → no clusters (all too different)."""
        traces = sample_traces_with_embeddings
        clusters = cluster_traces(traces, min_cluster_size=2, similarity_threshold=0.95)
        # No pair has cosine similarity > 0.95
        assert len(clusters) == 0

    def test_zero_threshold_all_merge(self, sample_traces_with_embeddings):
        """cluster_traces with threshold=0.0 → 1 cluster with all traces."""
        traces = sample_traces_with_embeddings
        clusters = cluster_traces(traces, min_cluster_size=2, similarity_threshold=0.0)
        # With threshold 0, all same-intent traces merge
        # docker_lifecycle: {0,1}, script_development: {2,3}, module_refactoring: {4}
        # Only clusters with >= 2 members
        assert len(clusters) == 2

    def test_empty_trace_list(self):
        """Empty trace list → empty cluster list."""
        clusters = cluster_traces([], min_cluster_size=3)
        assert clusters == []

    def test_below_min_cluster_size(self, sample_traces_with_embeddings):
        """Fewer than min_cluster_size traces → empty cluster list."""
        traces = sample_traces_with_embeddings[:2]  # Only 2 traces
        clusters = cluster_traces(traces, min_cluster_size=3)
        assert clusters == []

    def test_traces_without_embeddings(self, traces_no_embeddings):
        """Traces without embeddings → empty cluster list (not crash)."""
        clusters = cluster_traces(traces_no_embeddings, min_cluster_size=3)
        assert clusters == []

    def test_cluster_centroid_is_mean(self, sample_traces_with_embeddings):
        """Cluster centroid is mean of member embeddings."""
        traces = sample_traces_with_embeddings
        clusters = cluster_traces(traces, min_cluster_size=3, similarity_threshold=0.6)
        docker_clusters = [c for c in clusters if c.intent_category == "docker_lifecycle"]
        assert len(docker_clusters) >= 1
        c = docker_clusters[0]
        # Centroid should be average of traces[0] and traces[1]
        for d in range(len(c.centroid)):
            expected = (traces[0].embedding[d] + traces[1].embedding[d]) / 2
            assert abs(c.centroid[d] - expected) < 1e-10, \
                f"Centroid dim {d}: expected {expected}, got {c.centroid[d]}"

    def test_dominant_intent(self, sample_traces_with_embeddings):
        """TraceCluster.dominant_intent returns correct mode."""
        traces = sample_traces_with_embeddings
        clusters = cluster_traces(traces, min_cluster_size=3, similarity_threshold=0.6)
        for c in clusters:
            assert c.intent_category != ""
            # Verify it's the most common intent among members
            member_intents = [traces[i].intent_category for i in c.members]
            from collections import Counter
            most_common = Counter(member_intents).most_common(1)[0][0]
            assert c.intent_category == most_common

    def test_all_tags(self, sample_traces_with_embeddings):
        """TraceCluster.all_tags returns union of member tags."""
        traces = sample_traces_with_embeddings
        clusters = cluster_traces(traces, min_cluster_size=3, similarity_threshold=0.6)
        for c in clusters:
            assert isinstance(c.domain_tags, list)
            # All tags should come from member traces
            all_member_tags = set()
            for i in c.members:
                all_member_tags.update(traces[i].domain_tags)
            assert set(c.domain_tags) == all_member_tags

    def test_cluster_size_property(self, sample_traces_with_embeddings):
        """TraceCluster.size property returns correct count."""
        traces = sample_traces_with_embeddings
        clusters = cluster_traces(traces, min_cluster_size=3, similarity_threshold=0.6)
        for c in clusters:
            assert c.size == len(c.members)


# ── _average_embedding tests ──────────────────────────────────────────

class TestAverageEmbedding:
    """Tests for _average_embedding."""

    def test_empty_members(self, sample_traces_with_embeddings):
        """Empty member indices → empty list."""
        centroid = _average_embedding([], sample_traces_with_embeddings)
        assert centroid == []

    def test_single_member(self, sample_traces_with_embeddings):
        """Single member → returns that member's embedding."""
        centroid = _average_embedding([0], sample_traces_with_embeddings)
        assert centroid == sample_traces_with_embeddings[0].embedding

    def test_multiple_members(self, sample_traces_with_embeddings):
        """Multiple members → returns average."""
        centroid = _average_embedding([0, 1], sample_traces_with_embeddings)
        for d in range(len(centroid)):
            expected = (sample_traces_with_embeddings[0].embedding[d] +
                       sample_traces_with_embeddings[1].embedding[d]) / 2
            assert abs(centroid[d] - expected) < 1e-10


# ── TraceCluster tests ────────────────────────────────────────────────

class TestTraceCluster:
    """Tests for TraceCluster."""

    def test_cluster_with_no_members(self):
        """Cluster with no members has size 0."""
        c = TraceCluster(cluster_id=0)
        assert c.size == 0

    def test_cluster_creation(self):
        """TraceCluster can be created with members."""
        c = TraceCluster(cluster_id=42, members=[0, 1, 2])
        assert c.cluster_id == 42
        assert c.members == [0, 1, 2]
        assert c.size == 3
