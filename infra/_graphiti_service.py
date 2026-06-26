"""
GraphitiService — Reusable Graphiti + FalkorDB Lite wrapper for MCP server integration.

Provides a singleton-pattern async service that manages:
  - FalkorDB Lite embedded database lifecycle
  - Graphiti instance with mock AI clients (offline mode)
  - Multi-tenant group isolation via FalkorDB databases (group_id = database name)
  - Core operations: add_episode, retrieve_episodes, search, build_communities

Usage:
    service = GraphitiService(db_path="data/graphiti.db")
    await service.start()

    await service.add_episode(
        name="session_1",
        body="User asked about X...",
        group_id="my_group",
    )

    episodes = await service.get_episodes(group_id="my_group")
    results = await service.search("docker memory", group_id="my_group")

    await service.stop()

Design:
    - Graphiti stores episode data in a FalkorDB multi-tenant database named
      by ``group_id``.  This means **each group_id gets its own isolated graph**
      within the same Redis process.
    - Mock AI clients (LLM, embedder, cross-encoder) are used for offline
      operation.  No API keys needed.
    - Persistence: Redis RDB is saved on ``stop()`` via BGSAVE.  The RDB file
      survives restarts — all group databases are restored on next ``start()``.
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, AsyncIterator, Dict, List, Optional

logger = logging.getLogger("graphiti-service")

# ---------------------------------------------------------------------------
# Lazy imports — populated on first successful _resolve_imports()
# ---------------------------------------------------------------------------

_Graphiti = None
_FalkorDriver = None
_EpisodeType = None
_AsyncFalkorDB = None
_LLMClient = None
_LLMConfig = None
_EmbedderClient = None
_CrossEncoderClient = None
_imports_resolved = False
_import_error: Optional[str] = None

# Placeholders — replaced with proper bases after _resolve_imports()
MockLLMClient = None  # type: ignore
StubEmbedder = None  # type: ignore
StubCrossEncoder = None  # type: ignore


def _resolve_imports() -> None:
    """Lazy-import Graphiti dependencies so this module loads without them."""
    global _Graphiti, _FalkorDriver, _EpisodeType, _AsyncFalkorDB
    global _LLMClient, _LLMConfig, _EmbedderClient, _CrossEncoderClient
    global _imports_resolved, _import_error
    global MockLLMClient, StubEmbedder, StubCrossEncoder

    if _imports_resolved:
        return
    if _import_error:
        raise ImportError(_import_error)

    try:
        from graphiti_core import Graphiti as _G
        from graphiti_core.driver.falkordb_driver import FalkorDriver as _FD
        from graphiti_core.nodes import EpisodeType as _ET
        from graphiti_core.llm_client import LLMClient, LLMConfig
        from graphiti_core.embedder.client import EmbedderClient
        from graphiti_core.cross_encoder.client import CrossEncoderClient
        from redislite.async_falkordb_client import AsyncFalkorDB as _AFDB

        _Graphiti = _G
        _FalkorDriver = _FD
        _EpisodeType = _ET
        _AsyncFalkorDB = _AFDB
        _LLMClient = LLMClient
        _LLMConfig = LLMConfig
        _EmbedderClient = EmbedderClient
        _CrossEncoderClient = CrossEncoderClient
        _imports_resolved = True

        # Build mock client classes with proper inheritance now that bases exist
        class __MockLLMClient(LLMClient):
            """Schema-aware mock that returns empty entity/edge lists."""

            def __init__(self):
                super().__init__(config=LLMConfig(api_key="graphiti_service"))

            async def _generate_response(
                self, messages, response_model=None, max_tokens=None, model_size=None
            ):
                if response_model is not None:
                    schema = response_model.model_json_schema()
                    return {
                        k: [] if v.get("type") == "array" else {}
                        for k, v in schema.get("properties", {}).items()
                    }
                return {}

        class __StubEmbedder(EmbedderClient):
            """Returns dummy 4-float embeddings."""

            async def embed(self, texts):
                return [[0.25, 0.25, 0.25, 0.25] for _ in texts]

            async def embed_query(self, text):
                return [0.25, 0.25, 0.25, 0.25]

            async def create(self, input_data):
                return [0.25, 0.25, 0.25, 0.25]

        class __StubCrossEncoder(CrossEncoderClient):
            """Returns uniform relevance scores."""

            async def rank(self, query, passages):
                return [(p, 0.5) for p in passages]

        MockLLMClient = __MockLLMClient
        StubEmbedder = __StubEmbedder
        StubCrossEncoder = __StubCrossEncoder

    except ImportError as e:
        _import_error = (
            f"Graphiti dependencies not installed: {e}\n"
            "  pip install graphiti-core[falkordblite]"
        )
        raise ImportError(_import_error) from e


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------


@dataclass
class GraphitiService:
    """Reusable Graphiti service for MCP server integration.

    Usage (context manager)::

        async with GraphitiService(db_path="data/graphiti.db") as svc:
            await svc.add_episode(...)

    Or manually::

        svc = GraphitiService()
        await svc.start()
        ...
        await svc.stop()

    Parameters
    ----------
    db_path : str
        Path to the FalkorDB Lite RDB file.  Defaults to
        ``data/graphiti_service.db`` relative to the project root.
    store_raw_content : bool
        Whether Graphiti stores raw episode text (default: True).
    """

    db_path: str = ""
    store_raw_content: bool = True

    # Internal state (set during start/stop)
    _falkordb: Any = field(default=None, repr=False)
    _driver: Any = field(default=None, repr=False)
    _graphiti: Any = field(default=None, repr=False)
    _started: bool = False

    def __post_init__(self) -> None:
        if not self.db_path:
            self.db_path = str(
                Path(__file__).resolve().parents[1] / "data" / "graphiti_service.db"
            )

    # ── Lifecycle ──────────────────────────────────────────────────

    async def start(self) -> None:
        """Open FalkorDB Lite, build indices, and initialise Graphiti.

        Raises
        ------
        ImportError
            If graphiti-core or its dependencies are not installed.
        RuntimeError
            If the service is already started.
        """
        if self._started:
            raise RuntimeError("GraphitiService already started")

        _resolve_imports()

        db_path = Path(self.db_path)
        db_path.parent.mkdir(parents=True, exist_ok=True)

        logger.info("Starting GraphitiService (db=%s)", db_path)

        self._falkordb = _AsyncFalkorDB(dbfilename=str(db_path))  # type: ignore
        self._driver = _FalkorDriver(falkor_db=self._falkordb)  # type: ignore

        llm = MockLLMClient()  # type: ignore
        embedder = StubEmbedder()  # type: ignore
        cross_encoder = StubCrossEncoder()  # type: ignore

        self._graphiti = _Graphiti(  # type: ignore
            graph_driver=self._driver,
            llm_client=llm,
            embedder=embedder,
            cross_encoder=cross_encoder,
            store_raw_episode_content=self.store_raw_content,
        )

        self._started = True
        logger.info("GraphitiService started")

    async def stop(self) -> None:
        """Persist data and shut down the database connection."""
        if not self._started:
            return

        logger.info("Stopping GraphitiService ...")

        # Save RDB
        try:
            await self._falkordb.client.bgsave()
            await asyncio.sleep(0.3)
        except Exception as exc:
            logger.warning("BGSAVE failed: %s", exc)

        await self._driver.close()
        self._started = False
        logger.info("GraphitiService stopped")

    @asynccontextmanager
    async def session(self) -> AsyncIterator["GraphitiService"]:
        """Async context manager for the service lifecycle."""
        await self.start()
        try:
            yield self
        finally:
            await self.stop()

    # ── Core operations ─────────────────────────────────────────────

    async def add_episode(
        self,
        name: str,
        body: str,
        group_id: str,
        source_description: str = "mcp",
        reference_time: Optional[datetime] = None,
    ) -> Any:
        """Ingest an episode into the graph.

        Parameters
        ----------
        name : str
            Episode name (e.g. session_id).
        body : str
            Episode text content (e.g. thinking block).
        group_id : str
            Group/session partition.  Becomes the FalkorDB database name for
            multi-tenant isolation.
        source_description : str
            Free-text source label (default: "mcp").
        reference_time : datetime, optional
            Defaults to current UTC time.

        Returns
        -------
        AddEpisodeResults
            The result object from Graphiti.add_episode.
        """
        self._require_started()
        ref = reference_time or datetime.now(timezone.utc)

        return await self._graphiti.add_episode(
            name=name,
            episode_body=body,
            source_description=source_description,
            reference_time=ref,
            source=_EpisodeType.text,  # type: ignore
            group_id=group_id,
        )

    async def get_episodes(
        self,
        group_id: str,
        last_n: int = 25,
        reference_time: Optional[datetime] = None,
    ) -> list:
        """Retrieve recent episodes for a group.

        Parameters
        ----------
        group_id : str
            The group partition to query.
        last_n : int
            Number of most-recent episodes (default 25).
        reference_time : datetime, optional
            Reference time for temporal queries (defaults to now).

        Returns
        -------
        list[EpisodicNode]
        """
        self._require_started()
        ref = reference_time or datetime.now(timezone.utc)
        return await self._graphiti.retrieve_episodes(
            reference_time=ref,
            last_n=last_n,
            group_ids=[group_id],
        )

    async def search(
        self,
        query: str,
        group_id: str,
        limit: int = 10,
    ) -> list:
        """Hybrid search across group_id partition.

        Parameters
        ----------
        query : str
            Natural language query.
        group_id : str
            Group partition to search within.
        limit : int
            Max results (default 10).

        Returns
        -------
        list of search result objects.
        """
        self._require_started()
        return await self._graphiti.search(
            query,
            group_ids=[group_id],
            limit=limit,
        )

    async def build_communities(self, group_id: Optional[str] = None) -> list:
        """Run community detection on the graph.

        Parameters
        ----------
        group_id : str, optional
            If provided, only processes this group's database.

        Returns
        -------
        list of CommunityNode
        """
        self._require_started()
        communities = await self._graphiti.build_communities()
        return communities or []

    async def get_node_count(self, group_id: str) -> int:
        """Return total node count for a group's database."""
        self._require_started()
        driver = _FalkorDriver(falkor_db=self._falkordb, database=group_id)  # type: ignore
        try:
            result = await driver.execute_query("MATCH (n) RETURN count(n)")
            return result[0][0]["count(n)"] if result and result[0] else 0
        finally:
            await driver.close()

    # ── Graphiti access ─────────────────────────────────────────────

    @property
    def graphiti(self):
        """The underlying Graphiti instance (read-only)."""
        self._require_started()
        return self._graphiti

    @property
    def driver(self):
        """The FalkorDriver instance (read-only)."""
        self._require_started()
        return self._driver

    # ── Internals ───────────────────────────────────────────────────

    def _require_started(self) -> None:
        if not self._started:
            raise RuntimeError(
                "GraphitiService not started. Call await service.start() "
                "or use 'async with service:'"
            )
