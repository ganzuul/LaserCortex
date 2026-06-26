#!/usr/bin/env python3
"""
Phase 1 bootstrap: Ingest all 758 reasoning traces into Graphiti + FalkorDB Lite.

Creates a persistent FalkorDB Lite database at data/graphiti_bootstrap.db,
ingests traces as episodes, builds communities, and runs a verification query.

Usage:
    python scripts/graphiti_bootstrap.py
    python scripts/graphiti_bootstrap.py --traces-path reasoning_library/traces.jsonl
    python scripts/graphiti_bootstrap.py --db-path data/graphiti_bootstrap.db --max-traces 50
    python scripts/graphiti_bootstrap.py --dry-run  # Validate+count only
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Add project root to path so infra/ imports work
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))


# ---------------------------------------------------------------------------
# Mock AI clients (same pattern as tests/graphiti_integration/conftest.py)
# ---------------------------------------------------------------------------


def _build_mock_clients():
    """Build mock LLM/embedder/cross-encoder clients for offline ingestion."""
    from graphiti_core.llm_client import LLMClient, LLMConfig
    from graphiti_core.embedder.client import EmbedderClient
    from graphiti_core.cross_encoder.client import CrossEncoderClient

    class MockLLMClient(LLMClient):
        def __init__(self):
            super().__init__(config=LLMConfig(api_key="bootstrap"))

        async def _generate_response(
            self, messages, response_model=None, max_tokens=None, model_size=None
        ):
            if response_model is not None:
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


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Graphiti Phase 1 bootstrap")
    parser.add_argument(
        "--traces-path",
        type=str,
        default=str(PROJECT_ROOT / "reasoning_library" / "traces.jsonl"),
        help="Path to the traces.jsonl corpus",
    )
    parser.add_argument(
        "--db-path",
        type=str,
        default=str(PROJECT_ROOT / "data" / "graphiti_bootstrap.db"),
        help="Path for the FalkorDB Lite database file",
    )
    parser.add_argument(
        "--max-traces",
        type=int,
        default=0,
        help="Max traces to ingest (0 = all)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=25,
        help="Traces per batch (ingestion + flush cycle)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count and validate traces without ingesting",
    )
    parser.add_argument(
        "--no-communities",
        action="store_true",
        help="Skip community detection after ingestion",
    )
    parser.add_argument(
        "--no-verify",
        action="store_true",
        help="Skip verification search",
    )
    return parser.parse_args()


def load_traces(traces_path: str, max_traces: int = 0) -> list[dict]:
    """Load traces from a JSONL file, returning a list of dicts."""
    path = Path(traces_path)
    if not path.exists():
        print(f"ERROR: traces file not found: {path}", file=sys.stderr)
        sys.exit(1)

    traces: list[dict] = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            traces.append(json.loads(line))
            if max_traces and len(traces) >= max_traces:
                break

    print(f"Loaded {len(traces)} traces from {path}")
    return traces


def validate_traces(traces: list[dict]) -> dict:
    """Validate traces have required fields. Return stats."""
    required = {"session_id", "thinking_block", "intent_category", "outcome", "domain_tags"}
    stats = {
        "total": len(traces),
        "missing_fields": 0,
        "unique_sessions": len({t.get("session_id") for t in traces}),
        "unique_intents": len({t.get("intent_category") for t in traces}),
        "outcomes": {},
    }

    for t in traces:
        missing = required - set(t.keys())
        if missing:
            stats["missing_fields"] += 1

        outcome = t.get("outcome", "unknown")
        stats["outcomes"][outcome] = stats["outcomes"].get(outcome, 0) + 1

    return stats


async def ingest_traces(
    graphiti, traces: list[dict], group_id: str, batch_size: int,
    episode_type, start_index: int = 0,
) -> int:
    """Ingest traces as episodes. Returns count of successfully ingested traces."""
    ingested = 0
    now = datetime.now(timezone.utc)

    for i, trace in enumerate(traces):
        if i < start_index:
            continue

        session_id = trace.get("session_id", f"trace_{i}")
        thinking_block = (trace.get("thinking_block") or "")[:2000]

        try:
            await graphiti.add_episode(
                name=session_id,
                episode_body=thinking_block,
                source_description=f"bootstrap_trace_{i}",
                reference_time=now,
                source=episode_type.text,
                group_id=group_id,
            )
            ingested += 1
        except Exception as e:
            print(f"  [{i}] FAILED {session_id}: {e}", file=sys.stderr)

        if (i + 1) % batch_size == 0:
            elapsed = time.time() - _start_time
            rate = (i + 1 - start_index) / max(elapsed, 0.001)
            print(
                f"  [{i + 1}/{len(traces) + start_index}] "
                f"{ingested} ingested, {rate:.1f} eps/s"
            )

    return ingested


async def verify_search(graphiti, group_id: str, queries: list[str]) -> dict:
    """Run verification queries. Return results summary."""
    results = {}
    for q in queries:
        try:
            hits = await graphiti.search(q, group_ids=[group_id])
            results[q] = len(hits)
        except Exception as e:
            print(f"  Search '{q}' failed: {e}")
            results[q] = -1
    return results


async def main():
    args = parse_args()

    # Import Graphiti dependencies
    try:
        from graphiti_core import Graphiti
        from graphiti_core.driver.falkordb_driver import FalkorDriver
        from graphiti_core.nodes import EpisodeType
        from redislite.async_falkordb_client import AsyncFalkorDB
    except ImportError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        print("Install: pip install graphiti-core[falkordblite]", file=sys.stderr)
        sys.exit(1)

    # ------------------------------------------------------------------
    # 1. Load and validate traces
    # ------------------------------------------------------------------
    print("=" * 60)
    print("Graphiti Bootstrap — Phase 1")
    print("=" * 60)

    traces = load_traces(args.traces_path, args.max_traces)
    stats = validate_traces(traces)

    print(f"\nTrace stats:")
    print(f"  Total:              {stats['total']}")
    print(f"  Unique sessions:    {stats['unique_sessions']}")
    print(f"  Unique intents:     {stats['unique_intents']}")
    print(f"  Missing fields:     {stats['missing_fields']}")
    print(f"  Outcomes:           {stats['outcomes']}")

    if args.dry_run:
        print("\nDry run complete. No data ingested.")
        return

    # ------------------------------------------------------------------
    # 2. Initialize Graphiti + FalkorDB Lite
    # ------------------------------------------------------------------
    db_path = Path(args.db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"\nInitializing FalkorDB Lite at: {db_path}")
    falkordb_client = AsyncFalkorDB(dbfilename=str(db_path))
    driver = FalkorDriver(falkor_db=falkordb_client)

    llm, embedder, cross_encoder = _build_mock_clients()
    g = Graphiti(
        graph_driver=driver,
        llm_client=llm,
        embedder=embedder,
        cross_encoder=cross_encoder,
        store_raw_episode_content=True,
    )
    print("Graphiti initialized (offline mode, mock AI clients)")

    group_id = "bootstrap_v1"
    global _start_time
    _start_time = time.time()

    # ------------------------------------------------------------------
    # 3. Ingest traces
    # ------------------------------------------------------------------
    print(f"\nIngesting {len(traces)} traces (batch size: {args.batch_size})...")
    ingested = await ingest_traces(g, traces, group_id, args.batch_size, EpisodeType)
    elapsed_ingest = time.time() - _start_time
    print(f"\nIngestion complete: {ingested}/{len(traces)} in {elapsed_ingest:.1f}s")
    print(f"  Rate: {ingested / max(elapsed_ingest, 0.001):.1f} eps")

    # ------------------------------------------------------------------
    # 4. Build communities (optional)
    # ------------------------------------------------------------------
    if not args.no_communities:
        print("\nBuilding communities...")
        try:
            start = time.time()
            communities = await g.build_communities()
            elapsed_comm = time.time() - start
            print(f"Communities built: {len(communities) if communities else 0} "
                  f"in {elapsed_comm:.1f}s")
        except Exception as e:
            print(f"WARNING: build_communities() failed: {e}")
    else:
        print("\nSkipping community detection (--no-communities)")

    # ------------------------------------------------------------------
    # 5. Verification — query the correct database (group_id becomes DB name)
    # ------------------------------------------------------------------
    # Graphiti uses group_id as the FalkorDB database name for multi-tenant isolation
    storage_db = Path(args.db_path).stem
    ep_count = 0
    print(f"\nVerification (database: '{group_id}' = FalkorDB multi-tenant graph)...")
    try:
        vdriver = FalkorDriver(falkor_db=falkordb_client, database=group_id)
        r_nodes = await vdriver.execute_query("MATCH (n) RETURN count(n)")
        node_count = r_nodes[0][0]["count(n)"] if r_nodes and r_nodes[0] else 0
        r_episodes = await vdriver.execute_query("MATCH (n:Episodic) RETURN count(n)")
        ep_count = r_episodes[0][0]["count(n)"] if r_episodes and r_episodes[0] else 0
        r_labels = await vdriver.execute_query("CALL db.labels()")
        labels = [x["label"] for x in r_labels[0]] if r_labels and r_labels[0] else []
        print(f"  Total nodes:    {node_count}")
        print(f"  Episodic nodes: {ep_count}")
        print(f"  Labels:         {labels}")
    except Exception as e:
        print(f"  WARNING: verification query failed: {e}")

    # Verification search
    if not args.no_verify:
        print("\nRunning verification search...")
        queries = [
            "docker memory container",
            "type class error monad",
            "Lean theorem proof",
            "WebGPU shader buffer",
            "resource constraint",
        ]
        results = await verify_search(g, group_id, queries)
        print("Search results:")
        for q, count in results.items():
            status = f"{count} hits" if count >= 0 else "FAILED"
            print(f"  '{q}' -> {status}")
    else:
        print("\nSkipping verification search (--no-verify)")

    # ------------------------------------------------------------------
    # 6. Persist, reopen, and verify persistence
    # ------------------------------------------------------------------
    print("\nPersisting database...")
    try:
        save_result = await falkordb_client.client.bgsave()
        if hasattr(save_result, "__await__"):
            await save_result
        await asyncio.sleep(0.5)
    except Exception as e:
        print(f"  WARNING: bgsave failed: {e}")

    await driver.close()
    await asyncio.sleep(0.3)

    # Reopen and verify persistence
    print("Verifying persistence (reopen + query)...")
    try:
        fdb2 = AsyncFalkorDB(dbfilename=str(db_path))
        vdriver2 = FalkorDriver(falkor_db=fdb2, database=group_id)
        r2 = await vdriver2.execute_query("MATCH (n:Episodic) RETURN count(n)")
        records = r2[0] if r2 else []
        persisted_count = records[0]["count(n)"] if records else 0
        persist_ok = persisted_count == ep_count
        print(f"  Episodes after reopen: {persisted_count} "
              f"{'✓' if persist_ok else '✗ MISMATCH'}")
        await vdriver2.close()
    except Exception as e:
        print(f"  WARNING: persistence verification failed: {e}")
        persist_ok = False

    # ------------------------------------------------------------------
    # 7. Final stats
    # ------------------------------------------------------------------
    db_file_size_mb = db_path.stat().st_size / (1024 * 1024) if db_path.exists() else 0
    print(f"\n{'=' * 60}")
    print(f"Bootstrap complete")
    print(f"  Database:       {db_path} ({db_file_size_mb:.1f} MB)")
    print(f"  Traces ingested: {ingested}")
    print(f"  Persistence:    {'✓ confirmed' if persist_ok else '✗ FAILED'}")
    print(f"  Total time:     {time.time() - _start_time:.1f}s")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    import asyncio

    asyncio.run(main())
