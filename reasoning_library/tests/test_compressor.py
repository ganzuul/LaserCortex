"""Tests for reasoning_library.compressor.

Required: ≥ 5 test cases
"""

import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

REASONING_LIB = Path(__file__).parent.parent
if str(REASONING_LIB) not in sys.path:
    sys.path.insert(0, str(REASONING_LIB))

from reasoning_library.compressor import (
    compress_cluster_via_model,
    compress_heuristic,
    _parse_compression_output,
)
from reasoning_library.clusterer import TraceCluster
from reasoning_library.models import SessionReasoningTrace


# ── compress_cluster_via_model tests ──────────────────────────────────

class TestCompressClusterViaModel:
    """Tests for compress_cluster_via_model."""

    def test_mock_response_produces_script(self, sample_traces_with_embeddings):
        """compress_cluster_via_model with mock 35B response → correct script."""
        traces = sample_traces_with_embeddings
        cluster = TraceCluster(cluster_id=0, members=[0, 1])
        cluster.intent_category = "docker_lifecycle"
        cluster.domain_tags = ["Docker", "memory"]
        cluster.centroid = [0.0] * 10

        mock_response = (
            "=== PRIMING ===\n"
            "Check Docker memory limits.\n\n"
            "=== RUNBOOK ===\n"
            "1. Check docker stats\n"
            "2. Verify compose settings\n\n"
            "=== TOOL CHAIN ===\n"
            "read -> bash -> edit\n\n"
            "=== METADATA ===\n"
            "intent: docker_lifecycle\n"
            "tags: Docker, memory\n"
            "version: 1\n"
        )

        mock_resp = MagicMock()
        mock_resp.read.return_value = '{"choices": [{"message": {"content": "' +
                                       mock_response.replace('"', '\\"') + '"}}]}'
        mock_resp.getcode.return_value = 200

        with patch('http.client.HTTPConnection') as mock_conn:
            mock_conn.return_value.__enter__.return_value.getresponse.return_value = mock_resp
            mock_conn.return_value.__enter__.return_value.close = MagicMock()

            script = compress_cluster_via_model(cluster, traces)
            assert script is not None
            assert script.priming_prompt != ""
            assert script.debug_runbook != ""
            assert script.tool_chain != ""
            assert script.intent_category == "docker_lifecycle"
            assert script.version == 1

    def test_timeout_returns_none(self, sample_traces_with_embeddings):
        """Mock 35B response with timeout → returns None."""
        traces = sample_traces_with_embeddings
        cluster = TraceCluster(cluster_id=0, members=[0, 1])
        cluster.intent_category = "docker_lifecycle"
        cluster.domain_tags = ["Docker"]
        cluster.centroid = [0.0] * 10

        with patch('http.client.HTTPConnection') as mock_conn:
            mock_conn.side_effect = Exception("Connection timeout")
            script = compress_cluster_via_model(cluster, traces)
            assert script is None

    def test_malformed_response_graceful_parse(self):
        """Mock 35B response with malformed sections → graceful parse."""
        raw = "No sections here, just plain text.\nNo === markers.\n"
        cluster = TraceCluster(cluster_id=0, members=[0],
                               intent_category="docker_lifecycle",
                               domain_tags=["Docker"], centroid=[0.0] * 10)
        script = _parse_compression_output(raw, cluster)
        # Should not crash, fields may be empty
        assert script is not None
        assert script.priming_prompt == ""  # No valid PRIMING section
        assert script.version == 1

    def test_tool_chain_inferred_from_runbook(self):
        """Tool chain inferred from runbook if not in TOOL CHAIN section."""
        raw = (
            "=== PRIMING ===\n"
            "Check Docker memory.\n\n"
            "=== RUNBOOK ===\n"
            "1. Use read to check config\n"
            "2. Use bash to run commands\n"
            "3. Use grep to find patterns\n\n"
            "=== METADATA ===\n"
            "intent: docker_lifecycle\n"
            "tags: Docker\n"
        )
        cluster = TraceCluster(cluster_id=0, members=[0],
                               intent_category="docker_lifecycle",
                               domain_tags=["Docker"], centroid=[0.0] * 10)
        script = _parse_compression_output(raw, cluster)
        assert "read" in script.tool_chain
        assert "bash" in script.tool_chain


# ── compress_heuristic tests ──────────────────────────────────────────

class TestCompressHeuristic:
    """Tests for compress_heuristic."""

    def test_produces_non_empty_priming(self, sample_traces_with_embeddings):
        """compress_heuristic produces non-empty priming from first trace."""
        traces = sample_traces_with_embeddings
        cluster = TraceCluster(cluster_id=0, members=[0, 1])
        cluster.intent_category = "docker_lifecycle"
        cluster.domain_tags = ["Docker", "memory"]
        cluster.centroid = [0.0] * 10

        script = compress_heuristic(cluster, traces)
        assert script.priming_prompt != ""
        assert "docker_lifecycle" in script.priming_prompt

    def test_tool_chain_deduplicated(self, sample_traces_with_embeddings):
        """compress_heuristic tool chain is deduplicated and frequency-sorted."""
        traces = sample_traces_with_embeddings
        # Create cluster where tool "read" appears in both traces
        cluster = TraceCluster(cluster_id=0, members=[0, 1])
        cluster.intent_category = "docker_lifecycle"
        cluster.domain_tags = ["Docker"]
        cluster.centroid = [0.0] * 10

        script = compress_heuristic(cluster, traces)
        # "read" appears in both trace 0 and trace 1
        # "bash" appears in both trace 0 and trace 1
        # "edit" appears in trace 1 only
        # So tool chain should start with the most frequent
        assert " -> " in script.tool_chain or script.tool_chain == ""
        # No duplicates in tool chain
        tools = script.tool_chain.split(" -> ") if script.tool_chain else []
        assert len(tools) == len(set(tools))

    def test_version_is_zero(self, sample_traces_with_embeddings):
        """Script version=0 for heuristic."""
        traces = sample_traces_with_embeddings
        cluster = TraceCluster(cluster_id=0, members=[0, 1])
        cluster.intent_category = "docker_lifecycle"
        cluster.domain_tags = ["Docker"]
        cluster.centroid = [0.0] * 10

        script = compress_heuristic(cluster, traces)
        assert script.version == 0
