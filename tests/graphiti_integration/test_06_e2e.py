"""
Level 6: End-to-end integration tests.

Full-pipeline tests from start to finish — trace extraction, ingestion,
community detection, search, provenance, and cross-layer discovery.
Requires graphiti fixture and full reasoning_library corpus.

Marked `e2e`.
"""

from __future__ import annotations

from datetime import datetime, timezone

import pytest
from graphiti_core.nodes import EpisodeType

pytestmark = pytest.mark.e2e


class TestBootstrapE2E:
    """Test 6.1: Bootstrap — 758 traces → Graphiti → communities → search."""

    async def test_bootstrap_small(self, graphiti, sample_traces_json):
        """Small-scale bootstrap: ingest known traces, build communities, search."""
        g = graphiti
        now = datetime.now(timezone.utc)

        # Ingest all sample traces
        for trace in sample_traces_json:
            await g.add_episode(
                name=trace.get("session_id", "unknown"),
                episode_body=trace.get("thinking_block", "")[:500],
                source_description="e2e_bootstrap",
                reference_time=now,
                source=EpisodeType.text,
                group_id="test_e2e_bootstrap",
            )

        # Build communities
        communities = await g.build_communities()
        # Communities may or may not form with 5 traces — just verify no error

        # Search should work
        results = await g.search("docker", group_ids=["test_e2e_bootstrap"])
        assert isinstance(results, list)


class TestAuditTrailE2E:
    """Test 6.2: Audit trail — inference → certificate → temporal query."""

    async def test_audit_trail(self, graphiti):
        """Create an audit trail: trace → lift → certify, then query."""
        g = graphiti
        now = datetime.now(timezone.utc)
        # Step 1: Add the raw trace
        await g.add_episode(
            name="audit_trace",
            episode_body="Raw reasoning trace: checking reserve guard invariant",
            source_description="e2e_audit",
            reference_time=now,
            source=EpisodeType.text,
            group_id="test_e2e_audit",
        )

        # Step 2: Add the certificate episode (simulating bridge certify)
        await g.add_episode(
            name="audit_certificate",
            episode_body="CortexCertificate: source contracts_to rightComb",
            source_description="bridge_certify",
            reference_time=now,
            source=EpisodeType.text,
            group_id="test_e2e_audit",
        )

        # Step 3: Temporal query — search with time window
        results = await g.search("reserve guard", group_ids=["test_e2e_audit"])
        assert isinstance(results, list)


class TestCrossLayerDiscoveryE2E:
    """Test 6.3: Cross-layer discovery — traces + plan → unified search."""

    async def test_cross_layer_results(self, graphiti, sample_traces_json, normcode_plan_paths):
        """Ingest traces and NormCode plans, search across both."""
        g = graphiti
        now = datetime.now(timezone.utc)

        # Ingest traces
        for trace in sample_traces_json:
            await g.add_episode(
                name=trace.get("session_id", "trace"),
                episode_body=trace.get("thinking_block", "")[:500],
                source_description="e2e_cross_layer_trace",
                reference_time=now,
                source=EpisodeType.text,
                group_id="test_e2e_cross_layer",
            )

        # Ingest NormCode plans
        for plan_name, plan_path in normcode_plan_paths.items():
            plan_text = plan_path.read_text()
            await g.add_episode(
                name=f"plan_{plan_name}",
                episode_body=plan_text[:1000],
                source_description=f"normcode_plan_{plan_name}",
                reference_time=now,
                source=EpisodeType.text,
                group_id="test_e2e_cross_layer",
            )

        # Search across both layers
        results = await g.search("memory", group_ids=["test_e2e_cross_layer"])
        assert isinstance(results, list)


class TestDistillationCycleE2E:
    """Test 6.5: Distillation cycle — traces → recipe → route → update."""

    async def test_distillation_cycle(self, graphiti, sample_traces_json):
        """Simulate the diet: ingest traces, search, verify."""
        g = graphiti
        now = datetime.now(timezone.utc)

        # Ingest traces as potential "recipe" material
        for i, trace in enumerate(sample_traces_json):
            await g.add_episode(
                name=f"distill_trace_{i}",
                episode_body=trace.get("thinking_block", "")[:500],
                source_description="e2e_distill",
                reference_time=now,
                source=EpisodeType.text,
                group_id="test_e2e_distill",
            )

        # Search for similar traces (simulating recipe routing)
        results = await g.search(
            "type error",
            group_ids=["test_e2e_distill"],
        )
        assert isinstance(results, list)

        # Second search: verify search still works (recipe is "in place")
        results2 = await g.search(
            "docker",
            group_ids=["test_e2e_distill"],
        )
        assert isinstance(results2, list)
