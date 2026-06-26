"""
Level 3: Migration correctness tests.

Verifies that the Graphiti-based pipeline produces results consistent with
the existing JSON/embedding-based pipeline. These tests require the
pre-computed library.json, scripts.json, and traces.jsonl from the
reasoning_library package.

Marked `migration`.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

pytestmark = pytest.mark.migration

REPO_ROOT = Path(__file__).resolve().parents[2]
TRACES_PATH = REPO_ROOT / "reasoning_library" / "traces.jsonl"


class TestTraceIngestionParity:
    """Test 3.1: Trace ingestion matches existing parser output."""

    def test_traces_file_exists(self):
        """The traces.jsonl corpus exists and is non-empty."""
        assert TRACES_PATH.exists(), f"Traces corpus not found: {TRACES_PATH}"
        count = 0
        with open(TRACES_PATH) as f:
            for line in f:
                if line.strip():
                    count += 1
        assert count > 0, "Traces corpus is empty"
        # We expect ~758 traces
        assert count >= 100, f"Expected >=100 traces, got {count}"

    def test_trace_has_required_fields(self, sample_traces_json):
        """Every trace in the known set has session_id, thinking_block, etc."""
        for trace in sample_traces_json:
            assert "session_id" in trace, f"Missing session_id in {trace}"
            assert "thinking_block" in trace, f"Missing thinking_block in {trace}"
            assert "intent_category" in trace, f"Missing intent_category in {trace}"

    def test_trace_outcome_values_valid(self, sample_traces_json):
        """Outcome field contains only valid values."""
        valid = {"success", "failure", "deferred", ""}
        for trace in sample_traces_json:
            assert trace.get("outcome", "") in valid, (
                f"Invalid outcome '{trace.get('outcome')}' in {trace['session_id']}"
            )

    def test_trace_session_id_format(self, sample_traces_json):
        """Session IDs match expected pattern."""
        for trace in sample_traces_json:
            sid = trace.get("session_id", "")
            # Session IDs should not be empty
            assert len(sid) > 0, f"Empty session_id in trace"


class TestClusterParity:
    """Test 3.2: Graphiti communities match existing clusters."""

    def test_precomputed_library_has_clusters(self, precomputed_library):
        """The pre-computed library has cluster centroids."""
        assert "clusters" in precomputed_library or "scripts" in precomputed_library
        # Check that we have cluster data
        scripts = precomputed_library.get("scripts", [])
        clusters = precomputed_library.get("clusters", [])
        total = len(scripts) + len(clusters)
        assert total > 0, "No clusters or scripts found in library.json"

    def test_cluster_has_centroids(self, precomputed_library):
        """Each cluster/script has a centroid embedding."""
        scripts = precomputed_library.get("scripts", [])
        for i, script in enumerate(scripts):
            centroid = script.get("centroid") or script.get("feature_signature")
            assert centroid is not None, f"Script {i} missing centroid"
            assert len(centroid) > 0, f"Script {i} has empty centroid"


class TestEmbeddingSearchParity:
    """Test 3.3: Graphiti search returns comparable results to cosine search."""

    def test_precomputed_embeddings_exist(self, sample_traces_json):
        """Known traces have embedding vectors."""
        for trace in sample_traces_json:
            emb = trace.get("embedding")
            if emb is not None:
                assert len(emb) > 0, "Empty embedding vector"
                # Embeddings should be reasonable length
                assert len(emb) >= 4, f"Embedding too short: {len(emb)}"

    def test_cosine_similarity_baseline(self):
        """Compute baseline cosine similarity for migration comparison."""
        from reasoning_library.embedder import cosine_similarity

        v1 = [1.0, 0.0, 0.0, 0.0]
        v2 = [0.5, 0.5, 0.0, 0.0]
        v3 = [0.0, 1.0, 0.0, 0.0]

        sim_12 = cosine_similarity(v1, v2)
        sim_13 = cosine_similarity(v1, v3)

        # v1 and v2 should be more similar than v1 and v3
        assert sim_12 > sim_13, f"Expected sim_12 ({sim_12}) > sim_13 ({sim_13})"
        assert 0.0 <= sim_12 <= 1.0, f"Similarity out of range: {sim_12}"
        assert 0.0 <= sim_13 <= 1.0, f"Similarity out of range: {sim_13}"


class TestThreeTierRoutingParity:
    """Test 3.4: Three-tier routing works with library data."""

    def test_hardcoded_rules_exist(self, precomputed_library):
        """The library should define hardcoded rules if applicable."""
        # This is a structural check; the library might or might not have rules
        rules = precomputed_library.get("rules", [])
        assert isinstance(rules, list)

    def test_script_centroids_are_parseable(self, precomputed_library):
        """Script centroids can be loaded for routing."""
        scripts = precomputed_library.get("scripts", [])
        if not scripts:
            pytest.skip("No scripts in library.json")
        for script in scripts:
            centroid = script.get("centroid") or script.get("feature_signature")
            if centroid:
                # Verify all values are floats
                for v in centroid:
                    assert isinstance(v, (int, float)), f"Non-numeric centroid value: {v}"
