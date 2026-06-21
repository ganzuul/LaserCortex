#!/usr/bin/env python3
"""
Phase 0.1: Backfill versioning metadata into the phonebook cache.

For each cache entry with `_transformed == True`:
  1. Search ON for note titled "{module} — Deep Analysis"
  2. Fetch the note content to compute transform_output_sha
  3. Add transform_version=1, transform_params, transform_output_sha

Also updates PASS3_EDGES.json with version metadata.

Usage:
  python3 scripts/backfill_cache_version.py
  python3 scripts/backfill_cache_version.py --dry-run   # preview only
"""

import hashlib
import json
import sys
import time
from pathlib import Path

import requests

REPO_ROOT = Path("/home/nos/labware/LaserCortex")
CACHE_FILE = REPO_ROOT / ".phonebook_cache.json"
DEPENDENCY_GRAPH_FILE = REPO_ROOT / "DEPENDENCY_GRAPH.json"

ON_API = "http://localhost:5055/api"

CURRENT_VERSION = 1
CURRENT_PARAMS = {
    "temperature": 1.0,
    "seed_mode": "random",
    "model": "Qwen3.6-35B-A3B-Q4_K_M",
    "transformation_id": "transformation:0tkrn2ru01xj0zd4cp09",
    "max_tokens": 8192,
    "cache_prompt": True,
}
CROSS_LAYER_PARAMS = {
    "temperature": 1.0,
    "seed_mode": "random",
    "model": "Qwen3.6-35B-A3B-Q4_K_M",
    "transformation_id": "transformation:j2puh5eolx32sc5b431s",
    "max_tokens": 8192,
    "cache_prompt": True,
}

ON_SESSION = requests.Session()


def on_get(path: str, **kwargs) -> dict | list | None:
    try:
        r = ON_SESSION.get(f"{ON_API}{path}", timeout=30, **kwargs)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        return None


def on_post(path: str, data: dict) -> dict | list | None:
    try:
        r = ON_SESSION.post(f"{ON_API}{path}", json=data, timeout=30)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        return None


def search_deep_analysis_note(module: str) -> str | None:
    """Search ON for the Deep Analysis note. Returns note ID or None."""
    title = f"{module} \u2014 Deep Analysis"  # em dash
    result = on_post("/search", {"query": title, "limit": 10})
    if not result or not isinstance(result, dict):
        return None
    notes = result.get("results") or result.get("notes") or []
    for n in notes:
        if n.get("title") == title:
            return n.get("id")
    return None


def fetch_note_content(note_id: str) -> str:
    """Fetch full note content by ID."""
    note = on_get(f"/notes/{note_id}")
    if note and isinstance(note, dict):
        return note.get("content") or ""
    return ""


def build_note_map(cache: dict) -> dict[str, str]:
    """Build {module_name: note_id} from cache entries using ON search.
    
    Makes one search per module. Returns dict with module->note_id.
    This is the slow step (~1400 API calls for full backfill).
    """
    note_map = {}
    total = 0
    found = 0
    for rel, entry in cache.items():
        if not entry.get("_transformed"):
            continue
        total += 1
        module = entry.get("module", rel.split("/")[-1].rsplit(".", 1)[0])
        note_id = search_deep_analysis_note(module)
        if note_id:
            note_map[module] = note_id
            found += 1
        else:
            print(f"  WARN: No note found for module '{module}' ({rel})")
    print(f"  Found {found}/{total} Deep Analysis notes via search")
    return note_map


def backfill_cache_entry(
    entry: dict, note_id: str | None = None
) -> str | None:
    """Add version metadata to a single cache entry. Returns output SHA hex or None."""
    if entry.get("transform_version", 0) >= CURRENT_VERSION:
        return None

    output_sha = ""
    if note_id:
        content = fetch_note_content(note_id)
        if content:
            output_sha = hashlib.sha256(content.encode()).hexdigest()[:16]

    entry["transform_version"] = CURRENT_VERSION
    entry["transform_params"] = CURRENT_PARAMS.copy()
    entry["transform_versioned_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    entry["transform_output_sha"] = output_sha or "(no output found)"
    return output_sha or None


def backfill_pass3_edge(edge: dict) -> bool:
    """Add version metadata to a single cross-layer edge. Returns True if updated."""
    if edge.get("_version", 0) >= CURRENT_VERSION:
        return False
    edge["_version"] = CURRENT_VERSION
    edge["_params"] = CROSS_LAYER_PARAMS.copy()
    edge["_versioned_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    return True


def dry_run(cache: dict) -> tuple[int, int, int]:
    """Count what would be updated without making changes."""
    to_update_cache = 0
    already_current = 0
    skip_notransform = 0
    for rel, entry in cache.items():
        if not entry.get("_transformed") and not entry.get("transform_sha"):
            skip_notransform += 1
            continue
        if entry.get("transform_version", 0) >= CURRENT_VERSION:
            already_current += 1
            continue
        to_update_cache += 1
    return to_update_cache, already_current, skip_notransform


def main():
    dry = "--dry-run" in sys.argv

    print("=== Phase 0.1: Backfill Cache Versioning ===")
    t0 = time.time()

    # ── Load cache ──
    try:
        cache = json.loads(CACHE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"  ERROR: Cannot read cache: {e}")
        sys.exit(1)

    print(f"\n[Cache] Loaded {len(cache)} entries")

    if dry:
        to_update, current, skipped = dry_run(cache)
        print(f"  Would update: {to_update} entries")
        print(f"  Already v{CURRENT_VERSION}: {current}")
        print(f"  Not transformed (skip): {skipped}")
        print("\n[DRY RUN] No changes made.")
        return

    # ── Backfill phonebook cache ──
    print(f"\n[1/3] Building note ID map via ON search...")
    note_map = build_note_map(cache)

    print(f"\n[2/3] Adding version metadata to cache entries...")
    updated = 0
    skipped = 0
    for rel, entry in cache.items():
        if not entry.get("_transformed"):
            continue
        if entry.get("transform_version", 0) >= CURRENT_VERSION:
            skipped += 1
            continue

        module = entry.get("module", rel.split("/")[-1].rsplit(".", 1)[0])
        note_id = note_map.get(module)
        result = backfill_cache_entry(entry, note_id)
        if result is not None:
            updated += 1

    CACHE_FILE.write_text(json.dumps(cache, indent=2))
    print(f"  Updated: {updated}, Skipped (already v{CURRENT_VERSION}): {skipped}")
    print(f"  Wrote {CACHE_FILE}")

    # ── Backfill DEPENDENCY_GRAPH (Pass 3 edges only) ──
    print(f"\n[3/3] Updating DEPENDENCY_GRAPH.json (Pass 3 edges)...")
    try:
        dep_graph = json.loads(DEPENDENCY_GRAPH_FILE.read_text()) if DEPENDENCY_GRAPH_FILE.exists() else {}
    except json.JSONDecodeError:
        dep_graph = {}

    edges = dep_graph.get("edges", [])
    if edges:
        edge_updated = 0
        for e in edges:
            if e.get("_pass") == 3:
                if backfill_pass3_edge(e):
                    edge_updated += 1
        DEPENDENCY_GRAPH_FILE.write_text(json.dumps(dep_graph, indent=2))
        print(f"  {len(edges)} total edges, {edge_updated} pass-3 edges updated")
        print(f"  Wrote {DEPENDENCY_GRAPH_FILE}")
    else:
        print(f"  No edges found in DEPENDENCY_GRAPH.json — skipping")

    elapsed = time.time() - t0
    print(f"\nPhase 0.1 complete in {elapsed:.1f}s")


if __name__ == "__main__":
    main()
