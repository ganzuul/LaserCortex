#!/usr/bin/env python3
"""
run_pass3.py — Standalone Pass 3: Cross-Layer Dependency Linker.

Loads existing heuristic cache entries + enriched (Deep Analysis) notes from
the Open Notebook, groups by layer, sends the abstract to the 35B teacher for
cross-layer edge discovery, and merges results into the dependency graph.

Usage:
    python3 /tmp/run_pass3.py

Dependencies: requests (stdlib-only otherwise)
"""

import hashlib
import json
import os
import re
import sys
import time
from pathlib import Path

import requests

# ── Config ──────────────────────────────────────────────────────────────────
REPO_ROOT = Path("/home/nos/labware/LaserCortex")
CACHE_FILE = REPO_ROOT / ".phonebook_cache.json"
GRAPH_OUT = REPO_ROOT / "DEPENDENCY_GRAPH.json"
PHONEBOOK_OUT = REPO_ROOT / "MASTER_RECON_PHONEBOOK.md"

ON_URL = "http://localhost:5055/api"
LLM_URL = "http://localhost:8080"  # Direct llama-server (bypass ON for determinism)
TRANSFORMATION_CROSS_LAYER_LINKER = "transformation:j2puh5eolx32sc5b431s"

# Cache the cross-layer linker prompt (fetched once from ON)
_cross_layer_prompt: str = ""
def _get_cross_layer_prompt() -> str:
    global _cross_layer_prompt
    if not _cross_layer_prompt:
        try:
            t = requests.get(f"{ON_URL}/transformations/{TRANSFORMATION_CROSS_LAYER_LINKER}", timeout=10).json()
            _cross_layer_prompt = t.get("prompt", "")
        except Exception as e:
            print(f"  WARNING: Could not fetch prompt: {e}")
            _cross_layer_prompt = ""
    return _cross_layer_prompt

# Layer ordering for display
LAYER_ORDER = ["FORMALIZATION", "API_GATEWAY", "PRESENTATION", "DOCUMENTATION", "SYSTEM", "UNKNOWN"]


def load_cache() -> list[dict]:
    """Load entries from phonebook cache."""
    if not CACHE_FILE.exists():
        print(f"  ERROR: Cache not found: {CACHE_FILE}")
        sys.exit(1)
    with open(CACHE_FILE) as f:
        cache = json.load(f)
    entries = list(cache.values())
    print(f"  Loaded {len(entries)} entries from cache")
    return entries


def load_enriched_entries(entries: list[dict]) -> dict[str, str]:
    """Load Deep Analysis notes from ON for entries that have transform_sha.

    Falls back to the cache entry's stored analysis if available.
    """
    enriched = {}
    nb_id = get_notebook_id()
    if not nb_id:
        print("  WARNING: Could not determine notebook ID — enriched entries will be empty")
        return enriched

    # Fetch notes list from ON
    try:
        resp = requests.get(f"{ON_URL}/notes", params={"notebook_id": nb_id}, timeout=30)
        resp.raise_for_status()
        notes = resp.json()
    except Exception as e:
        print(f"  WARNING: Could not fetch notes: {e}")
        return enriched

    # Build a map: note title → note content for Deep Analysis notes
    note_map = {}

    # Collect Deep Analysis note IDs from the list endpoint
    deep_note_ids: list[tuple[str, str]] = []  # (note_id, module_name)
    for note in notes:
        title = note.get("title") or note.get("name") or ""
        if isinstance(title, str) and "Deep Analysis" in title:
            module_name = title.replace(" — Deep Analysis", "").strip()
            note_id = note.get("id")
            if note_id:
                deep_note_ids.append((note_id, module_name))

    # Fetch individual note content (list endpoint omits content for bandwidth)
    if deep_note_ids:
        print(f"  Fetching content for {len(deep_note_ids)} Deep Analysis notes...")
        for note_id, module_name in deep_note_ids:
            try:
                resp = requests.get(f"{ON_URL}/notes/{note_id}", timeout=10)
                resp.raise_for_status()
                detail = resp.json()
                content = detail.get("content")
                if content:
                    note_map[module_name] = str(content)[:200]
            except Exception:
                pass
        print(f"  Loaded {len(note_map)} enriched Deep Analysis entries")

    # Also check enriched entries stored in cache
    for entry in entries:
        module = entry.get("module", "")
        if module in note_map:
            enriched[module] = note_map[module][:200]
        elif entry.get("analysis", ""):
            enriched[module] = entry["analysis"][:200]

    print(f"  Loaded {len(enriched)} enriched (Deep Analysis) entries")
    return enriched


def get_notebook_id() -> str | None:
    """Resolve the 'LaserCortex' notebook ID from ON."""
    try:
        resp = requests.get(f"{ON_URL}/notebooks", timeout=10)
        resp.raise_for_status()
        notebooks = resp.json() if isinstance(resp.json(), list) else resp.json().get("data", [])
        for nb in notebooks:
            if nb.get("name") == "LaserCortex" or nb.get("title") == "LaserCortex":
                return nb.get("id") or nb.get("_id")
        return None
    except Exception as e:
        print(f"  WARNING: Failed to get notebook: {e}")
        return None


def build_dependency_graph(entries: list[dict]) -> dict:
    """Build heuristic dependency graph from import analysis."""
    edges = []
    by_module = {e["module"]: e for e in entries}
    for entry in entries:
        for imp in entry.get("imports", []):
            if imp in by_module and imp != entry["module"]:
                target = by_module[imp]
                edges.append({
                    "source": entry["module"],
                    "target": imp,
                    "layer_source": entry["layer"],
                    "layer_target": target["layer"],
                    "edge_type": "IMPORT",
                    "invariant": f"imports {imp}",
                    "failure_mode": f"missing import: {imp}",
                })
    return {
        "nodes": [e["module"] for e in entries],
        "edges": edges,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def build_cross_layer_abstract(entries: list[dict], enriched: dict[str, str]) -> str:
    """Build a compact abstract including only modules relevant for cross-layer edge discovery.

    Includes:
    - Modules with enriched (Deep Analysis) content — richest semantic signal
    - Modules in the heuristic dependency graph — already show connectivity
    - ALL FORMALIZATION modules — small set, highest cross-layer value

    Excludes:
    - Modules with only bare metadata (no enriched, no edges) — contribute no signal
    """
    # Build heuristic graph to find connected nodes
    by_module = {e["module"]: e for e in entries}
    graph_nodes = set()
    for entry in entries:
        for imp in entry.get("imports", []):
            if imp in by_module and imp != entry["module"]:
                graph_nodes.add(entry["module"])
                graph_nodes.add(imp)

    # Enriched modules (by module name)
    enriched_modules = set(enriched.keys())

    # Included module names: enriched OR in graph OR FORMALIZATION layer
    formalization_modules = set(
        e["module"] for e in entries if e.get("layer") == "FORMALIZATION"
    )
    included = enriched_modules | graph_nodes | formalization_modules

    # Filter entries
    included_entries = [e for e in entries if e["module"] in included]

    # Group by layer
    grouped: dict[str, list[dict]] = {}
    for entry in included_entries:
        layer = entry.get("layer", "UNKNOWN")
        grouped.setdefault(layer, []).append(entry)

    # Build abstract with context window budget (~200K chars ≈ 50K tokens,
    # leaving room for system prompt and response within 65K ctx).
    MAX_CHARS = 180_000
    ENRICHED_TRUNC = 100  # shorter enriched snippets to fit more modules
    FALLBACK_TRUNC = 60   # even shorter for non-enriched entries

    abstracts = []
    budget = MAX_CHARS

    # First pass: FORMALIZATION modules (highest value for cross-layer)
    for layer in [l for l in LAYER_ORDER if l == "FORMALIZATION"]:
        for mod in grouped.get(layer, []):
            module_name = mod["module"]
            line = f"  [{layer}] {module_name}"
            if module_name in enriched:
                line += f": {enriched[module_name][:ENRICHED_TRUNC]}"
            elif mod.get("intent") and mod["intent"] not in ("N/A", "", "No description"):
                line += f": {mod['intent'][:FALLBACK_TRUNC]}"
            else:
                tags = ' '.join(mod.get('tags', []))
                if tags:
                    line += f": tags={tags}"
            if len(line) + sum(len(a) for a in abstracts) < budget:
                abstracts.append(line)

    # Second pass: enriched modules (Deep Analysis available)
    for layer in LAYER_ORDER:
        if layer == "FORMALIZATION":
            continue
        for mod in grouped.get(layer, []):
            module_name = mod["module"]
            if module_name not in enriched:
                continue  # skip non-enriched in this pass
            line = f"  [{layer}] {module_name}"
            line += f": {enriched[module_name][:ENRICHED_TRUNC]}"
            if len(line) + sum(len(a) for a in abstracts) < budget:
                abstracts.append(line)

    # Third pass: remaining graph modules (brief hints only)
    for layer in LAYER_ORDER:
        if layer == "FORMALIZATION":
            continue
        for mod in grouped.get(layer, []):
            module_name = mod["module"]
            if module_name in enriched:
                continue  # already added above
            line = f"  [{layer}] {module_name}"
            tags = ' '.join(mod.get('tags', []))
            contracts = mod.get('contracts', [])
            if contracts:
                line += f": contracts={', '.join(contracts[:2])}"
            elif tags:
                line += f": tags={tags}"
            if len(line) + sum(len(a) for a in abstracts) < budget:
                abstracts.append(line)

    batch_input = "\n".join(abstracts)
    total_chars = len(batch_input)
    print(f"  Abstract: {len(abstracts)} modules, {total_chars} chars, {len(abstracts)} lines")
    print(f"    Breakdown: {len(enriched_modules)} enriched, {len(graph_nodes)} graph nodes, {len(formalization_modules)} FORMALIZATION")
    if total_chars >= MAX_CHARS * 0.9:
        print(f"  ⚠ Approaching context budget ({total_chars}/{MAX_CHARS} chars)")
    return batch_input


def run_cross_layer_linker(entries: list[dict], enriched: dict[str, str], model_id: str) -> list[dict]:
    """
    Call the 35B Cross-Layer-Linker transformation deterministically.

    Bypasses ON's API (which can't set temperature/seed) and calls the 35B
    directly with temperature=0, seed derived from input hash.
    """
    batch_input = build_cross_layer_abstract(entries, enriched)
    prompt = _get_cross_layer_prompt()
    if not prompt:
        print("  WARNING: No cross-layer linker prompt available")
        return []

    # Derive seed from input for determinism
    seed = int(hashlib.sha256(batch_input.encode()).hexdigest()[:8], 16)

    messages = [
        {"role": "system", "content": prompt},
        {"role": "user", "content": batch_input},
    ]

    try:
        resp = requests.post(
            f"{LLM_URL}/v1/chat/completions",
            json={
                "model": model_id,
                "messages": messages,
                "temperature": 0,
                "seed": seed,
                "max_tokens": 8192,
                "cache_prompt": False,
            },
            timeout=600,
        )
        resp.raise_for_status()
        result = resp.json()
        output = result["choices"][0]["message"].get("content", "")
    except Exception as e:
        print(f"  WARNING: Cross-layer linking API call failed: {e}")
        return []

    if not output:
        print("  WARNING: Empty response from cross-layer linker")
        return []

    cross_edges_raw = output
    try:
        cross_edges = json.loads(cross_edges_raw)
        if isinstance(cross_edges, list):
            print(f"  Added {len(cross_edges)} cross-layer edges")
            return cross_edges
        elif isinstance(cross_edges, dict) and "edges" in cross_edges:
            print(f"  Added {len(cross_edges['edges'])} cross-layer edges")
            return cross_edges["edges"]
        else:
            print(f"  Unexpected response format, storing raw")
    except json.JSONDecodeError:
        print(f"  Response is not JSON, storing raw")
        # Store as a note
        try:
            nb_id = get_notebook_id()
            if nb_id:
                requests.post(
                    f"{ON_URL}/notes",
                    json={
                        "content": cross_edges_raw,
                        "title": "Cross-Layer Dependency Graph — Raw",
                        "note_type": "ai",
                        "notebook_id": nb_id,
                    },
                    timeout=10,
                )
                print(f"  Stored raw cross-layer analysis as note")
        except Exception:
            pass

    return []


def write_phonebook(entries: list[dict], dep_graph: dict):
    """Write the phonebook markdown and dependency graph JSON."""
    # ── Dependency graph JSON ──
    GRAPH_OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(GRAPH_OUT, "w") as f:
        json.dump(dep_graph, f, indent=2)
    print(f"  Wrote {GRAPH_OUT}")

    # ── Phonebook markdown ──
    notebook_name = "LaserCortex"
    lines = [
        f"# Semantic Index: {notebook_name}",
        f"",
        f"Generated: {time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}",
        f"Mode: full (Pass 3 only)",
        f"Modules: {len(entries)}",
        f"",
        f"## Cross-Layer Dependency Graph",
        f"",
        f"- **Nodes**: {len(dep_graph['nodes'])}",
        f"- **Edges**: {len(dep_graph['edges'])} ({sum(1 for e in dep_graph['edges'] if e.get('layer_source') != e.get('layer_target'))} cross-layer)",
        f"",
        f"### Edge Types",
        f"",
    ]

    edge_types: dict[str, int] = {}
    for e in dep_graph["edges"]:
        et = e.get("edge_type", "UNKNOWN")
        edge_types[et] = edge_types.get(et, 0) + 1
    for et, count in sorted(edge_types.items()):
        lines.append(f"- **{et}**: {count}")
    lines.append("")

    # Layer counts
    layers: dict[str, int] = {}
    for e in entries:
        layers[e.get("layer", "UNKNOWN")] = layers.get(e.get("layer", "UNKNOWN"), 0) + 1
    lines.append("### Module Counts by Layer")
    lines.append("")
    for layer in LAYER_ORDER:
        if layer in layers:
            lines.append(f"- **{layer}**: {layers[layer]}")
    lines.append("")

    PHONEBOOK_OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(PHONEBOOK_OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"  Wrote {PHONEBOOK_OUT}")


def main():
    print("=== Pass 3: Cross-Layer Linker (standalone) ===")
    t0 = time.time()

    # Load entries
    entries = load_cache()
    if len(entries) < 2:
        print("  ERROR: Need at least 2 entries for cross-layer analysis")
        sys.exit(1)

    # Load enriched entries
    enriched = load_enriched_entries(entries)

    # Build heuristic dependency graph
    dep_graph = build_dependency_graph(entries)
    print(f"  Heuristic graph: {len(dep_graph['nodes'])} nodes, {len(dep_graph['edges'])} edges")

    # Find model ID from ON
    model_id = None
    try:
        resp = requests.get(f"{ON_URL}/models", timeout=10)
        resp.raise_for_status()
        models = resp.json() if isinstance(resp.json(), list) else resp.json().get("data", [])
        for m in models:
            name = m.get("name", "").lower()
            if "35b" in name or "qwen3" in name:
                model_id = m.get("id") or m.get("_id")
                break
        if model_id:
            print(f"  Using model: {model_id}")
    except Exception as e:
        print(f"  WARNING: Could not resolve model ID: {e}")

    # Run cross-layer linker
    cross_edges = run_cross_layer_linker(entries, enriched, model_id)
    if cross_edges:
        # Assign layer_source/layer_target by looking up module names in cache
        by_module = {e["module"]: e for e in entries}
        def _strip_layer(name: str) -> str:
            """Remove [LAYER] prefix added by 35B if present."""
            return re.sub(r'^\[(\w+)\]\s*', '', name).strip()
        for e in cross_edges:
            src_mod = _strip_layer(e["source"]["module"] if isinstance(e["source"], dict) else e["source"])
            tgt_mod = _strip_layer(e["target"]["module"] if isinstance(e["target"], dict) else e["target"])
            src_entry = by_module.get(src_mod)
            tgt_entry = by_module.get(tgt_mod)
            e["layer_source"] = src_entry["layer"] if src_entry else "UNKNOWN"
            e["layer_target"] = tgt_entry["layer"] if tgt_entry else "UNKNOWN"
            e["_pass"] = 3

    # Persistently merge Pass 3 edges (survives stochastic failures)
    pass3_out = REPO_ROOT / "PASS3_EDGES.json"
    existing_pass3 = []
    if pass3_out.exists():
        try:
            existing_pass3 = json.loads(pass3_out.read_text())
            print(f"  Loaded {len(existing_pass3)} previously discovered Pass 3 edges")
        except (json.JSONDecodeError, Exception):
            pass
    if cross_edges:
        # Merge: add new edges, keyed by (source, target, edge_type)
        seen = {(e["source"]["module"], e["target"]["module"], e["edge_type"]) for e in existing_pass3}
        for e in cross_edges:
            key = (e["source"]["module"], e["target"]["module"], e["edge_type"])
            if key not in seen:
                existing_pass3.append(e)
                seen.add(key)
        pass3_out.write_text(json.dumps(existing_pass3, indent=2))
        print(f"  Persisted {len(cross_edges)} edges ({len(existing_pass3)} cumulative)")

    # Always apply persisted Pass 3 edges to the graph
    dep_graph["edges"].extend(existing_pass3)
    print(f"  Total edges after Pass 3: {len(dep_graph['edges'])}")

    # Write artifacts
    write_phonebook(entries, dep_graph)

    elapsed = time.time() - t0
    print(f"  Pass 3 complete in {elapsed:.1f}s")


if __name__ == "__main__":
    main()
