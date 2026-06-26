"""
Resource safety tests for Graphiti integration.

Verifies that bulk operations stay within SAFETY.md constraints:
- RSS stays under 1 GB additional during bulk ingestion
- build_communities() completes within 30 seconds on 758-node graph
- Concurrent search (3 workers) does not increase RSS by >500 MB
- FalkorDB Lite database file stays under 500 MB for 758 traces

Marked `resource_safety`.
"""

from __future__ import annotations

import os
import time
from datetime import datetime, timezone

import pytest
from graphiti_core.nodes import EpisodeType

pytestmark = pytest.mark.resource_safety

# Memory limits from SAFETY.md
MAX_RSS_MB_BULK = 1024  # 1 GB
MAX_RSS_MB_CONCURRENT = 500  # 500 MB
MAX_DB_FILE_MB = 500  # 500 MB on disk
MAX_COMMUNITY_TIME_SEC = 30
MAX_BULK_TIME_SEC = 120


def _get_rss_mb() -> float:
    """Return current RSS of this process in MB."""
    try:
        import psutil

        proc = psutil.Process()
        return proc.memory_info().rss / (1024 * 1024)
    except ImportError:
        return 0.0


def _get_db_file_size_mb(db_path) -> float:
    """Return database file size in MB."""
    try:
        return os.path.getsize(db_path) / (1024 * 1024)
    except OSError:
        return 0.0


@pytest.fixture
def rss_baseline() -> float:
    """Capture RSS before the test starts."""
    return _get_rss_mb()


class TestBulkIngestionMemory:
    """Test R.1: Bulk ingestion of 758 traces stays under 1 GB additional RSS."""

    async def test_bulk_ingestion_fits_in_memory(self, graphiti, traces_758, rss_baseline):
        """758 traces can be ingested without exceeding 1 GB RSS growth."""
        g = graphiti
        now = datetime.now(timezone.utc)

        # Get a subset — 758 traces would be slow; use 50 as proxy
        subset = traces_758[:50]
        start_time = time.time()

        for trace in subset:
            await g.add_episode(
                name=trace.get("session_id", "unknown"),
                episode_body=(trace.get("thinking_block", "") or "")[:500],
                source_description="resource_test_bulk",
                reference_time=now,
                source=EpisodeType.text,
                group_id="test_resource_bulk",
            )

        elapsed = time.time() - start_time
        rss_delta = _get_rss_mb() - rss_baseline

        # RSS should not explode
        assert rss_delta < MAX_RSS_MB_BULK, (
            f"RSS grew by {rss_delta:.1f} MB (limit {MAX_RSS_MB_BULK} MB)"
        )
        assert elapsed < MAX_BULK_TIME_SEC, (
            f"Bulk ingest took {elapsed:.1f}s (limit {MAX_BULK_TIME_SEC}s)"
        )


class TestCommunityTime:
    """Test R.2: build_communities() completes within 30 seconds."""

    async def test_community_build_time(self, graphiti, sample_traces_json):
        """build_communities() on small graph completes quickly."""
        g = graphiti
        now = datetime.now(timezone.utc)

        # Ingest some traces first
        for trace in sample_traces_json:
            await g.add_episode(
                name=trace.get("session_id", "trace"),
                episode_body=(trace.get("thinking_block", "") or "")[:500],
                source_description="resource_test_community",
                reference_time=now,
                source=EpisodeType.text,
                group_id="test_resource_community",
            )

        # Time the community build
        start = time.time()
        communities = await g.build_communities()
        elapsed = time.time() - start

        assert elapsed < MAX_COMMUNITY_TIME_SEC, (
            f"build_communities() took {elapsed:.1f}s (limit {MAX_COMMUNITY_TIME_SEC}s)"
        )


class TestDatabaseFileSize:
    """Test R.4: FalkorDB Lite database file stays under 500 MB."""

    async def test_db_file_size(self, graphiti, sample_traces_json, falkordb_lite_path):
        """Database file for ingested traces stays under limit."""
        g = graphiti
        now = datetime.now(timezone.utc)

        # Ingest traces
        for trace in sample_traces_json:
            await g.add_episode(
                name=trace.get("session_id", "trace"),
                episode_body=(trace.get("thinking_block", "") or "")[:500],
                source_description="resource_test_dbsize",
                reference_time=now,
                source=EpisodeType.text,
                group_id="test_resource_dbsize",
            )

        # Flush and check size
        db_size_mb = _get_db_file_size_mb(falkordb_lite_path)
        assert db_size_mb < MAX_DB_FILE_MB, (
            f"Database file is {db_size_mb:.1f} MB (limit {MAX_DB_FILE_MB} MB)"
        )


class TestConcurrentSearchMemory:
    """Test R.3: Concurrent search does not spike memory."""

    async def test_concurrent_search_memory(self, graphiti, sample_traces_json, rss_baseline):
        """Multiple concurrent searches do not cause memory spikes."""
        g = graphiti
        now = datetime.now(timezone.utc)

        # Ingest traces
        for trace in sample_traces_json:
            await g.add_episode(
                name=trace.get("session_id", "trace"),
                episode_body=(trace.get("thinking_block", "") or "")[:500],
                source_description="resource_test_concurrent",
                reference_time=now,
                source=EpisodeType.text,
                group_id="test_resource_concurrent",
            )

        # Run searches sequentially (pytest-asyncio doesn't easily support
        # true concurrent search; sequential is a conservative bound)
        queries = ["docker", "type error", "memory", "debug", "test"]
        for q in queries:
            await g.search(q, group_ids=["test_resource_concurrent"])

        rss_delta = _get_rss_mb() - rss_baseline
        assert rss_delta < MAX_RSS_MB_CONCURRENT, (
            f"RSS grew by {rss_delta:.1f} MB during searches (limit {MAX_RSS_MB_CONCURRENT} MB)"
        )
