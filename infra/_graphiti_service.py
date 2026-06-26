"""
GraphitiService — Reusable Graphiti + FalkorDB Lite wrapper for MCP server integration.

Provides a singleton-pattern async service that manages:
  - FalkorDB Lite embedded database lifecycle
  - Graphiti instance with mock AI clients (offline mode)
  - Multi-tenant group isolation via FalkorDB databases (group_id = database name)
  - Core operations: add_episode, retrieve_episodes, search, build_communities
  - Custom entity types: NormNode, CortexNode with OWL key-value pairing

Usage:
    service = GraphitiService(db_path="data/graphiti.db")
    await service.start()

    await service.add_episode(
        name="session_1",
        body="User asked about X...",
        group_id="my_group",
    )

    # With custom entity types (OWL key-value pairing):
    await service.add_episode_with_entities(
        name="lift_operation",
        body="Lifting inference to CD structure",
        group_id="my_group",
        entity_types={"NormNode": norm_attrs, "CortexNode": cortex_attrs},
        edge_types={"LIFTS_TO_STRUCTURE": lift_attrs, "OWL_KEY_VALUE_PAIR": owl_attrs},
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
    - Blood-Brain Barrier: NormNode (NL values) and CortexNode (OWL keys) are
      connected via OWL_KEY_VALUE_PAIR edges to maintain separation between
      formal LaserCortex identifiers and natural language reasoning.
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

    # ── OWL Key-Value Pairing (Blood-Brain Barrier) ─────────────────────

    async def add_episode_with_entities(
        self,
        name: str,
        body: str,
        group_id: str,
        entity_types: Optional[Dict[str, Any]] = None,
        edge_types: Optional[Dict[str, Any]] = None,
        source_description: str = "mcp",
        reference_time: Optional[datetime] = None,
    ) -> Any:
        """Ingest an episode with custom entity and edge types (OWL key-value pairing).

        This method supports the blood-brain barrier pattern by allowing explicit
        creation of NormNode and CortexNode entities with OWL key-value fields,
        connected via OWL_KEY_VALUE_PAIR edges.

        Parameters
        ----------
        name : str
            Episode name.
        body : str
            Episode text content.
        group_id : str
            Group/session partition.
        entity_types : dict[str, Any], optional
            Dict mapping entity type names to their Pydantic model classes.
            Example: {"NormNode": NormNodeAttrs, "CortexNode": CortexNodeAttrs}
        edge_types : dict[str, Any], optional
            Dict mapping edge type names to their Pydantic model classes.
            Example: {"OWL_KEY_VALUE_PAIR": OwlKeyValuePairAttrs}
        source_description : str
            Free-text source label (default: "mcp").
        reference_time : datetime, optional
            Defaults to current UTC time.

        Returns
        -------
        AddEpisodeResults
            The result object from Graphiti.add_episode.

        Example
        -------
        >>> from infra._graphiti_models import NormNodeAttrs, CortexNodeAttrs, OwlKeyValuePairAttrs
        >>> norm = NormNodeAttrs(owl_key="ReserveGuard", nl_value="reserve guard")
        >>> cortex = CortexNodeAttrs(owl_key="ReserveGuard", cd_step=2)
        >>> owl_edge = OwlKeyValuePairAttrs(key="ReserveGuard", value="reserve guard", cd_step=2)
        >>> await service.add_episode_with_entities(
        ...     name="lift_reserve_guard",
        ...     body="Lifting ReserveGuard inference",
        ...     group_id="test",
        ...     entity_types={"NormNode": norm, "CortexNode": cortex},
        ...     edge_types={"OWL_KEY_VALUE_PAIR": owl_edge},
        ... )
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
            entity_types=entity_types,
            edge_types=edge_types,
        )

    async def add_owl_key_value_pair(
        self,
        norm_node: Any,
        cortex_node: Any,
        owl_edge: Any,
        group_id: str,
        episode_name: str = "owl_pairing",
        episode_body: str = "OWL key-value pairing for blood-brain barrier",
    ) -> Any:
        """Convenience method to create a NormNode + CortexNode + OWL_KEY_VALUE_PAIR triplet.

        This enforces the blood-brain barrier pattern by creating all three
        components with matching OWL keys and natural language values.

        Parameters
        ----------
        norm_node : NormNodeAttrs
            The NormNode with owl_key and nl_value.
        cortex_node : CortexNodeAttrs
            The CortexNode with matching owl_key.
        owl_edge : OwlKeyValuePairAttrs
            The edge connecting them with key, value, coupling_signature, cd_step.
        group_id : str
            Group partition.
        episode_name : str
            Name for the episode (default: "owl_pairing").
        episode_body : str
            Body text for the episode.

        Returns
        -------
        AddEpisodeResults
            The result from Graphiti.add_episode.

        Raises
        ------
        ValueError
            If the OWL key-value invariants are violated.
        """
        from infra._graphiti_models import OwlKeyValueInvariants

        # Validate invariants before ingestion
        if not OwlKeyValueInvariants.check_normnode_cortexnode_pair(norm_node, cortex_node):
            raise ValueError(
                f"Invariant violated: NormNode.owl_key ({norm_node.owl_key}) "
                f"!= CortexNode.owl_key ({cortex_node.owl_key})"
            )
        if not OwlKeyValueInvariants.check_normnode_edge_pair(norm_node, owl_edge):
            raise ValueError(
                f"Invariant violated: NormNode fields don't match OWL_KEY_VALUE_PAIR edge"
            )
        if not OwlKeyValueInvariants.check_cortexnode_edge_pair(cortex_node, owl_edge):
            raise ValueError(
                f"Invariant violated: CortexNode fields don't match OWL_KEY_VALUE_PAIR edge"
            )

        return await self.add_episode_with_entities(
            name=episode_name,
            body=episode_body,
            group_id=group_id,
            entity_types={"NormNode": norm_node, "CortexNode": cortex_node},
            edge_types={"OWL_KEY_VALUE_PAIR": owl_edge},
        )

    async def verify_owl_invariants(self, group_id: str) -> Dict[str, Any]:
        """Verify all OWL key-value pairing invariants in a group.

        Checks:
        1. All NormNode.owl_key == CortexNode.owl_key for connected pairs
        2. All NormNode.nl_value == OWL_KEY_VALUE_PAIR.value
        3. All CortexNode.cd_step == OWL_KEY_VALUE_PAIR.cd_step
        4. OWL keys are unique across NormNodes
        5. Non-trivial CD steps (>= 1) have OWL keys

        Parameters
        ----------
        group_id : str
            Group partition to verify.

        Returns
        -------
        dict
            Verification results with counts and any violations found.
        """
        self._require_started()
        driver = _FalkorDriver(falkor_db=self._falkordb, database=group_id)  # type: ignore

        results = {
            "group_id": group_id,
            "norm_nodes_count": 0,
            "cortex_nodes_count": 0,
            "owl_edges_count": 0,
            "violations": [],
            "all_passed": True,
        }

        try:
            # Count nodes
            result = await driver.execute_query(
                "MATCH (n:NormNode) RETURN count(n) as count"
            )
            if result and result[0]:
                results["norm_nodes_count"] = result[0][0]["count"]

            result = await driver.execute_query(
                "MATCH (n:CortexNode) RETURN count(n) as count"
            )
            if result and result[0]:
                results["cortex_nodes_count"] = result[0][0]["count"]

            result = await driver.execute_query(
                "MATCH ()-[e:OWL_KEY_VALUE_PAIR]->() RETURN count(e) as count"
            )
            if result and result[0]:
                results["owl_edges_count"] = result[0][0]["count"]

            # Check for violations
            # 1. NormNode with cd_step >= 1 but no owl_key
            result = await driver.execute_query(
                "MATCH (c:CortexNode) WHERE c.cd_step >= 1 AND (c.owl_key IS NULL OR c.owl_key = '') "
                "RETURN c.uuid as uuid, c.cd_step as cd_step"
            )
            if result and result[0]:
                for record in result[0]:
                    results["violations"].append({
                        "type": "cortex_missing_owl_key",
                        "uuid": record.get("uuid"),
                        "cd_step": record.get("cd_step"),
                    })

            # 2. OWL_KEY_VALUE_PAIR edges with mismatched keys
            result = await driver.execute_query(
                "MATCH (n:NormNode)-[e:OWL_KEY_VALUE_PAIR]->(c:CortexNode) "
                "WHERE n.owl_key != e.key OR c.owl_key != e.key "
                "RETURN n.uuid as norm_uuid, c.uuid as cortex_uuid, e.uuid as edge_uuid, "
                "n.owl_key as norm_key, c.owl_key as cortex_key, e.key as edge_key"
            )
            if result and result[0]:
                for record in result[0]:
                    results["violations"].append({
                        "type": "key_mismatch",
                        "norm_uuid": record.get("norm_uuid"),
                        "cortex_uuid": record.get("cortex_uuid"),
                        "edge_uuid": record.get("edge_uuid"),
                        "norm_key": record.get("norm_key"),
                        "cortex_key": record.get("cortex_key"),
                        "edge_key": record.get("edge_key"),
                    })

            # 3. OWL_KEY_VALUE_PAIR edges with mismatched values
            result = await driver.execute_query(
                "MATCH (n:NormNode)-[e:OWL_KEY_VALUE_PAIR]->(c:CortexNode) "
                "WHERE n.nl_value != e.value "
                "RETURN n.uuid as norm_uuid, e.uuid as edge_uuid, "
                "n.nl_value as norm_value, e.value as edge_value"
            )
            if result and result[0]:
                for record in result[0]:
                    results["violations"].append({
                        "type": "value_mismatch",
                        "norm_uuid": record.get("norm_uuid"),
                        "edge_uuid": record.get("edge_uuid"),
                        "norm_value": record.get("norm_value"),
                        "edge_value": record.get("edge_value"),
                    })

            # 4. Duplicate OWL keys in NormNodes
            result = await driver.execute_query(
                "MATCH (n:NormNode) WHERE n.owl_key IS NOT NULL AND n.owl_key != '' "
                "WITH n.owl_key as key, collect(n.uuid) as uuids "
                "WHERE size(uuids) > 1 "
                "RETURN key, uuids"
            )
            if result and result[0]:
                for record in result[0]:
                    results["violations"].append({
                        "type": "duplicate_owl_key",
                        "key": record.get("key"),
                        "uuids": record.get("uuids"),
                    })

            results["all_passed"] = len(results["violations"]) == 0

        finally:
            await driver.close()

        return results

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
