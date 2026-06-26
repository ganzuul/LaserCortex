"""
Pytest fixtures for Graphiti integration tests.

Provides:
- falkordb_lite_path: temporary path for an embedded FalkorDB Lite database
- graphiti: Graphiti instance with FalkorDB Lite backend (no LLM, no embedder)
- sample_traces: list of 5 known SessionReasoningTrace objects
- known_session_files: paths to session .md fixtures
- traces_758_path: path to the full traces.jsonl corpus
- normcode_plans: paths to .ncd plan files for cross-layer tests
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

import pytest

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]
TRACES_758_PATH = REPO_ROOT / "reasoning_library" / "traces.jsonl"
LIBRARY_JSON_PATH = REPO_ROOT / "reasoning_library" / "library.json"
SCRIPTS_JSON_PATH = REPO_ROOT / "reasoning_library" / "scripts.json"
FIXTURES_DIR = REPO_ROOT / "reasoning_library" / "tests" / "fixtures"
NCD_DIR = REPO_ROOT / "LaserCortex" / "examples"


# ---------------------------------------------------------------------------
# Fixtures: Level 1-2 (pure, no DB)
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def sample_traces_json() -> list[dict[str, Any]]:
    """Return the 5 known traces from traces_known.jsonl."""
    known_path = FIXTURES_DIR / "traces_known.jsonl"
    if not known_path.exists():
        pytest.skip(f"Test fixture not found: {known_path}")
    traces: list[dict[str, Any]] = []
    with open(known_path) as f:
        for line in f:
            line = line.strip()
            if line:
                traces.append(json.loads(line))
    return traces


@pytest.fixture(scope="session")
def traces_758_path() -> Path:
    """Path to the full 758-trace corpus."""
    if not TRACES_758_PATH.exists():
        pytest.skip(f"Traces corpus not found: {TRACES_758_PATH}")
    return TRACES_758_PATH


@pytest.fixture(scope="session")
def traces_758(traces_758_path) -> list[dict[str, Any]]:
    """Load all 758 traces as a list of dicts."""
    traces: list[dict[str, Any]] = []
    with open(traces_758_path) as f:
        for line in f:
            line = line.strip()
            if line:
                traces.append(json.loads(line))
    return traces


@pytest.fixture(scope="session")
def known_session_files() -> dict[str, Path]:
    """Return dict of session file name → Path for test fixture sessions."""
    paths = {
        "short": FIXTURES_DIR / "session_short.md",
        "minimal": FIXTURES_DIR / "session_minimal.md",
        "weird": FIXTURES_DIR / "session_weird.md",
    }
    for name, p in paths.items():
        if not p.exists():
            pytest.skip(f"Test fixture not found: {p}")
    return paths


@pytest.fixture(scope="session")
def normcode_plan_paths() -> dict[str, Path]:
    """Return dict of plan name → Path for .ncd plan files."""
    plans = {
        "market_closure": NCD_DIR / "market_closure" / "market_closure.ncd",
        "prediction_market": NCD_DIR / "market_closure" / "prediction_market.ncd",
        "eigenstate_bridge": REPO_ROOT / "LaserCortex" / "examples"
        / "eigenstate_bridge.ncd",
    }
    existing = {}
    for name, p in plans.items():
        if p.exists():
            existing[name] = p
    if not existing:
        pytest.skip("No NormCode plan files found")
    return existing


# ---------------------------------------------------------------------------
# Fixtures: Level 4+ (require FalkorDB Lite)
# ---------------------------------------------------------------------------

@pytest.fixture(scope="module")
def falkordb_lite_path(tmp_path_factory) -> Path:
    """Create a temporary path for a FalkorDB Lite database."""
    return tmp_path_factory.mktemp("graphiti") / "test.db"


def _build_mock_clients():
    """Build mock LLM/embedder/cross-encoder clients for offline testing."""
    from graphiti_core.llm_client import LLMClient, LLMConfig
    from graphiti_core.embedder.client import EmbedderClient
    from graphiti_core.cross_encoder.client import CrossEncoderClient

    class MockLLMClient(LLMClient):
        """Returns empty extractions — no real LLM needed."""

        def __init__(self):
            super().__init__(config=LLMConfig(api_key="test"))

        async def _generate_response(
            self, messages, response_model=None, max_tokens=None, model_size=None
        ):
            """Return a response compatible with Graphiti's extraction schemas."""
            if response_model is not None:
                # Build empty response matching the model's expected fields
                schema = response_model.model_json_schema()
                properties = schema.get("properties", {})
                empty = {}
                for field_name in properties:
                    field_type = properties[field_name].get("type", "array")
                    if field_type == "array":
                        empty[field_name] = []
                    elif field_type == "object":
                        empty[field_name] = {}
                    elif field_type in ("string",):
                        empty[field_name] = ""
                    elif field_type in ("number", "integer"):
                        empty[field_name] = 0
                    elif field_type == "boolean":
                        empty[field_name] = False
                    else:
                        empty[field_name] = None
                return empty
            return {}

    class StubEmbedder(EmbedderClient):
        """Returns fixed-dim constant vectors."""

        async def embed(self, texts):
            return [[0.25, 0.25, 0.25, 0.25] for _ in texts]

        async def embed_query(self, text):
            return [0.25, 0.25, 0.25, 0.25]

        async def create(self, input_data):
            return [0.25, 0.25, 0.25, 0.25]

    class StubCrossEncoder(CrossEncoderClient):
        async def rank(self, query, passages):
            return [(p, 0.5) for p in passages]

    return MockLLMClient(), StubEmbedder(), StubCrossEncoder()


@pytest.fixture(scope="function")
def graphiti(falkordb_lite_path):
    """Graphiti instance with embedded FalkorDB Lite and mock AI clients.

    Uses prescribed ontology only (no real LLM extraction calls).
    This fixture has module scope — all tests in one module share the
    same database instance.
    """
    try:
        from graphiti_core import Graphiti
        from graphiti_core.driver.falkordb_driver import FalkorDriver
        from redislite.async_falkordb_client import AsyncFalkorDB
    except ImportError:
        pytest.skip("graphiti-core[falkordblite] not installed")

    llm, embedder, cross_encoder = _build_mock_clients()

    falkordb_client = AsyncFalkorDB(dbfilename=str(falkordb_lite_path))
    driver = FalkorDriver(falkor_db=falkordb_client)
    g = Graphiti(
        graph_driver=driver,
        llm_client=llm,
        embedder=embedder,
        cross_encoder=cross_encoder,
        store_raw_episode_content=True,
    )
    yield g

    # Close driver synchronously in finalizer
    try:
        import asyncio
        asyncio.run(driver.close())
    except Exception:
        pass


@pytest.fixture(scope="function")
def graphiti_with_embedder(falkordb_lite_path):
    """Graphiti instance with a stub embedder for vector-search tests.

    Uses a simple identity-mapping embedder that returns fixed-dim vectors.
    """
    try:
        from graphiti_core import Graphiti
        from graphiti_core.driver.falkordb_driver import FalkorDriver
        from redislite.async_falkordb_client import AsyncFalkorDB
    except ImportError:
        pytest.skip("graphiti-core[falkordblite] not installed")

    llm, embedder, cross_encoder = _build_mock_clients()

    falkordb_client = AsyncFalkorDB(
        dbfilename=str(falkordb_lite_path.with_name("test_embedder.db"))
    )
    driver = FalkorDriver(falkor_db=falkordb_client)
    g = Graphiti(
        graph_driver=driver,
        llm_client=llm,
        embedder=embedder,
        cross_encoder=cross_encoder,
        store_raw_episode_content=True,
    )
    yield g

    try:
        import asyncio
        asyncio.run(driver.close())
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Fixtures: Level 3 (migration test data)
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def precomputed_library(library_json_path: Path = LIBRARY_JSON_PATH):
    """Load pre-computed library.json for migration parity tests."""
    if not library_json_path.exists():
        pytest.skip(f"Library JSON not found: {library_json_path}")
    with open(library_json_path) as f:
        return json.load(f)


@pytest.fixture(scope="session")
def precomputed_scripts(scripts_json_path: Path = SCRIPTS_JSON_PATH):
    """Load pre-computed scripts.json for migration parity tests."""
    if not scripts_json_path.exists():
        pytest.skip(f"Scripts JSON not found: {scripts_json_path}")
    with open(scripts_json_path) as f:
        return json.load(f)
