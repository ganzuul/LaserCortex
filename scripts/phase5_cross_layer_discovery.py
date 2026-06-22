#!/usr/bin/env python3
"""Phase 5 — Hybrid bge-m3 + 35B cross-layer dependency discovery.

Replaces the monolithic Pass 3 (one 332K-char 35B call) with a scalable
two-stage pipeline:

  Stage 1 (candidates): Embed all indexed modules with bge-m3, compute
  all cross-layer cosine similarities, threshold to produce K candidates.

  Stage 2 (verify): For each candidate pair, call the 35B with a focused
  prompt asking: "Is there a semantic dependency between module X (layer A)
  and module Y (layer B)?" Store verified edges in DEPENDENCY_GRAPH.json.

Stage 2 now uses the Reasoning Library (scripts/reasoning_library/) to:
  - Route pairs to pre-baked reasoning scripts (saves ~70% token cost)
  - Skip the LLM entirely for hardcoded patterns (instant)
  - Accumulate reasoning traces for self-improvement
  - Fall back to full 35B reasoning for novel/outlier pairs

Usage:
  # Stage 1: Generate candidate pairs (embed server must be on :8082)
  python3 phase5_cross_layer_discovery.py candidates [--threshold 0.5] [--max-pairs 500]

  # Stage 2: Verify candidates with 35B (35B must be on :8080)
  python3 phase5_cross_layer_discovery.py verify [--candidates-file /tmp/...] [--batch-size 5]

  # Seed the reasoning library from existing verification cache
  python3 phase5_cross_layer_discovery.py seed-library

  # Both stages
  python3 phase5_cross_layer_discovery.py run [--threshold 0.5] [--max-pairs 100]
"""

import json
import sys
import requests
import time
import hashlib
import logging
from pathlib import Path

# Try local copy first, then fall back to open-notebook canonical location
_local_lib = str(Path(__file__).resolve().parent.parent)
_on_lib = "/home/nos/labware/open-notebook/scripts"
for p in [_local_lib, _on_lib]:
    if p not in sys.path:
        sys.path.insert(0, p)

try:
    from scripts.reasoning_library import (
        TaskConfig, ReasoningTrace, ReasoningScript,
        HardcodedRule, RoutingDecision,
        ReasoningLibrary, MetaCompressor, EmbeddingRouter,
        DEFAULT_SYSTEM_PROMPT,
    )
except ImportError:
    from reasoning_library import (
        TaskConfig, ReasoningTrace, ReasoningScript,
        HardcodedRule, RoutingDecision,
        ReasoningLibrary, MetaCompressor, EmbeddingRouter,
        DEFAULT_SYSTEM_PROMPT,
    )

logging.basicConfig(level=logging.INFO,
                   format="%(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("phase5")

# ── Config ──────────────────────────────────────────────────────────
ON_API = "http://localhost:5055"
EMBED_API = "http://localhost:8082/v1/embeddings"
LLM_API = "http://localhost:8080/v1/chat/completions"
REPO = "/home/nos/labware/LaserCortex"
CACHE = Path(REPO) / ".phonebook_cache.json"
GRAPH = Path(REPO) / "DEPENDENCY_GRAPH.json"
EMBED_CACHE = Path("/tmp/lasercortex_embeddings.json")
CANDIDATES_FILE = Path("/tmp/phase5_candidates.json")
LIBRARY_PATH = "/tmp/reasoning_library.json"

EMBED_MODEL = "bge-m3"
LLM_MODEL = "Qwen3.6-35B-A3B-Q4_K_M"

# Cross-layer pair types to consider
CROSS_LAYER_TYPES = [
    ("FORMALIZATION", "API_GATEWAY"),
    ("API_GATEWAY", "PRESENTATION"),
    ("FORMALIZATION", "PRESENTATION"),
]

DEFAULT_SIM_THRESHOLD = 0.5
DEFAULT_MAX_PAIRS = 500

# Task config for reasoning library
CROSS_LAYER_CONFIG = TaskConfig(
    name="cross-layer-dependency",
    description="Determine if a semantic dependency exists between two software modules from different architectural layers (FORMALIZATION/API_GATEWAY/PRESENTATION).",
    input_fields={
        "source_module": "Name/symbol of the source module",
        "target_module": "Name/symbol of the target module",
        "source_layer": "Architectural layer of source",
        "target_layer": "Architectural layer of target",
        "source_content": "Deep Analysis note content for source",
        "target_content": "Deep Analysis note content for target",
    },
    output_taxonomy={
        "edge_type": {
            "SPECIFICATION": "Source defines formal invariants that target must preserve",
            "CONSTRAINT": "Source API/schema dictates target's interface or behavior",
            "DATA_SOURCE": "Source provides data that target consumes directly",
        }
    },
    format_instruction="DEPENDENCY|EDGE_TYPE|INVARIANT|FAILURE_MODE or NONE",
    positive_marker="DEPENDENCY",
    negative_marker="NONE",
)


# ═══════════════════════════════════════════════════════════════════
# STAGE 1: Candidate generation (embedding pre-filter)
# ═══════════════════════════════════════════════════════════════════

def fetch_deep_analysis_notes():
    """Fetch all Deep Analysis note content from ON."""
    print("Fetching Deep Analysis notes from ON...")
    for attempt in range(3):
        try:
            resp = requests.post(f"{ON_API}/api/search",
                                json={"query": "Deep Analysis", "search_type": "text",
                                      "limit": 500}, timeout=30)
            resp.raise_for_status()
            hits = resp.json().get("results", resp.json())
            break
        except Exception as e:
            print(f"  Retry {attempt+1}: {e}")
            time.sleep(3)
    else:
        print("  FAILED to fetch notes — using heuristic metadata only")
        return {}

    notes = {}
    for h in hits:
        title = h.get("title", "")
        if "Deep Analysis" in title:
            nid = h.get("id", "")
            for fa in range(2):
                try:
                    nr = requests.get(f"{ON_API}/api/notes/{nid}", timeout=10)
                    if nr.ok:
                        nd = nr.json()
                        notes[title] = nd.get("content", "")
                    break
                except:
                    time.sleep(1)
    print(f"  Fetched {len(notes)} notes")
    return notes


def build_text_map(cache_entries, da_notes):
    """Build module-level text representations (preferring Deep Analysis)."""
    texts = {}
    for path, entry in cache_entries.items():
        module = entry.get("module", "")
        da_title = f"{module} — Deep Analysis"
        if da_title in da_notes:
            texts[path] = da_notes[da_title]
        else:
            parts = [f"Module: {module}", f"File: {path}",
                     f"Layer: {entry.get('layer', 'UNKNOWN')}"]
            tags = entry.get("tags", [])
            if tags:
                parts.append(f"Tags: {' '.join(tags)}")
            contracts = entry.get("contracts", [])
            if contracts:
                parts.append(f"Contracts: {' '.join(contracts[:20])}")
            exports = entry.get("exports", [])
            if exports:
                parts.append(f"Exports: {' '.join(exports[:20])}")
            imports_list = entry.get("imports", [])
            if imports_list:
                parts.append(f"Imports: {' '.join(imports_list[:20])}")
            texts[path] = "\n".join(parts)
    return texts


def embed_textes(texts_list):
    """Batch-embed texts via bge-m3 (individual requests to avoid OOM)."""
    embeddings = {}
    total = len(texts_list)
    print(f"Embedding {total} texts (batch_size=1)...")

    for i, (key, text) in enumerate(texts_list):
        for attempt in range(3):
            try:
                resp = requests.post(EMBED_API,
                                    json={"input": text, "model": EMBED_MODEL},
                                    timeout=120)
                resp.raise_for_status()
                data = resp.json()
                if isinstance(data, dict) and "data" in data:
                    embeddings[key] = data["data"][0]["embedding"]
                elif isinstance(data, dict) and "embedding" in data:
                    embeddings[key] = data["embedding"]
                elif isinstance(data, list) and len(data) > 0:
                    embeddings[key] = data[0]
                break
            except Exception as e:
                if attempt < 2:
                    time.sleep(2)
                else:
                    print(f"  FAILED on item {i}: {e}")

        if (i + 1) % 50 == 0:
            print(f"  {i+1}/{total} ({ (i+1)*100//total }%)")

    print(f"Done. Got {len(embeddings)}/{total} embeddings.")
    return embeddings


def load_or_compute_embeddings(cache, texts):
    """Load cached embeddings or compute new ones."""
    relevant_layers = {"FORMALIZATION", "API_GATEWAY", "PRESENTATION"}
    embeddings = {}

    # Try loading from cache
    if EMBED_CACHE.exists():
        try:
            with open(EMBED_CACHE) as f:
                cached = json.load(f)
            cache_key = hashlib.sha256(
                json.dumps({k: v.get("module", "") for k, v in cache.items()},
                          sort_keys=True).encode()
            ).hexdigest()[:16]
            if cached.get("_cache_key") == cache_key:
                embeddings = {k: v for k, v in cached.items()
                            if not k.startswith("_")}
                print(f"Loaded {len(embeddings)} cached embeddings")
        except Exception as e:
            print(f"Cache load failed: {e}")

    # Compute missing embeddings
    to_embed = [(p, texts[p]) for p, e in cache.items()
                if e.get("layer", "") in relevant_layers and p not in embeddings]
    if to_embed:
        new_embeddings = embed_textes(to_embed)
        embeddings.update(new_embeddings)
        # Save cache
        cache_key = hashlib.sha256(
            json.dumps({k: v.get("module", "") for k, v in cache.items()},
                      sort_keys=True).encode()
        ).hexdigest()[:16]
        cache_entry = {"_cache_key": cache_key}
        cache_entry.update(embeddings)
        with open(EMBED_CACHE, "w") as f:
            json.dump(cache_entry, f)
        print(f"Cached {len(embeddings)} embeddings")
    else:
        print(f"All {len(embeddings)} embeddings from cache")

    return embeddings


def cosine_sim(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = sum(x * x for x in a) ** 0.5
    nb = sum(x * x for x in b) ** 0.5
    return dot / (na * nb) if na > 0 and nb > 0 else 0.0


class CrossLayerScorer:
    """Compute cross-layer cosine similarity and rank candidates."""

    def __init__(self, cache, embeddings):
        self.cache = cache
        self.embeddings = embeddings

        # Group paths by layer
        self.by_layer = {}
        for path, entry in cache.items():
            layer = entry.get("layer", "UNKNOWN")
            if path in embeddings and layer in {"FORMALIZATION", "API_GATEWAY", "PRESENTATION"}:
                self.by_layer.setdefault(layer, []).append(path)

    def top_candidates(self, threshold=DEFAULT_SIM_THRESHOLD,
                       max_pairs=DEFAULT_MAX_PAIRS):
        """Find top cross-layer candidate pairs by cosine similarity."""
        candidates = []

        for src_layer, tgt_layer in CROSS_LAYER_TYPES:
            src_paths = self.by_layer.get(src_layer, [])
            tgt_paths = self.by_layer.get(tgt_layer, [])
            total_pairs = len(src_paths) * len(tgt_paths)
            print(f"\n  {src_layer} × {tgt_layer}: {len(src_paths)} × {len(tgt_paths)} = {total_pairs} pairs")

            for s in src_paths:
                s_emb = self.embeddings.get(s)
                if not s_emb:
                    continue
                s_mod = self.cache[s].get("module", s)
                for t in tgt_paths:
                    t_emb = self.embeddings.get(t)
                    if not t_emb:
                        continue
                    sim = cosine_sim(s_emb, t_emb)
                    if sim >= threshold:
                        t_mod = self.cache[t].get("module", t)
                        candidates.append({
                            "source_path": s,
                            "target_path": t,
                            "source_module": s_mod,
                            "target_module": t_mod,
                            "source_layer": src_layer,
                            "target_layer": tgt_layer,
                            "similarity": round(sim, 4),
                            "edge_type": "CANDIDATE",
                            "invariant": "",
                        })

            print(f"    → {len(candidates)} candidates above threshold (updating count)")

        # Deduplicate (same source/target regardless of layer ordering)
        seen = set()
        unique = []
        for c in candidates:
            key = (c["source_path"], c["target_path"])
            if key not in seen:
                seen.add(key)
                unique.append(c)

        # Sort by similarity descending, take top K
        unique.sort(key=lambda x: -x["similarity"])
        selected = unique[:max_pairs]

        print(f"\n  Total unique candidates: {len(unique)}")
        print(f"  Selected top {len(selected)} (threshold={threshold}, max={max_pairs})")

        return selected


def stage1_candidates(threshold, max_pairs):
    """Run Stage 1: generate candidate pairs."""
    print("═══ Phase 5 — Stage 1: Candidate generation ═══")
    print(f"Threshold: {threshold}, Max pairs: {max_pairs}\n")

    # Load data
    with open(CACHE) as f:
        cache = json.load(f)
    print(f"Loaded {len(cache)} cache entries")

    da_notes = fetch_deep_analysis_notes()
    texts = build_text_map(cache, da_notes)
    embeddings = load_or_compute_embeddings(cache, texts)

    scorer = CrossLayerScorer(cache, embeddings)
    candidates = scorer.top_candidates(threshold, max_pairs)

    # Save candidates
    output = {
        "_generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "_threshold": threshold,
        "_max_pairs": max_pairs,
        "_total_candidates": len(candidates),
        "candidates": candidates,
    }
    with open(CANDIDATES_FILE, "w") as f:
        json.dump(output, f, indent=2)
    print(f"\nSaved {len(candidates)} candidates to {CANDIDATES_FILE}")

    # Show top 10
    print("\nTop 10 candidates:")
    for c in candidates[:10]:
        print(f"  {c['source_module']} ({c['source_layer']}) → "
              f"{c['target_module']} ({c['target_layer']})  "
              f"[sim={c['similarity']}]")

    return candidates


# ═══════════════════════════════════════════════════════════════════
# STAGE 2: 35B per-pair verification
# ═══════════════════════════════════════════════════════════════════

VERIFY_PROMPT = """You are a cross-layer dependency analyzer. Two modules are described below. Determine if there is a semantic dependency from the first module to the second.

FORMALIZATION = Lean4 formal proofs and invariants.
API_GATEWAY = Python runtime, Django endpoints, middleware.
PRESENTATION = TypeScript UI, WebGPU shaders, React components.

=== SOURCE MODULE ({src_layer}) ===
{src_content}

=== TARGET MODULE ({tgt_layer}) ===
{tgt_content}

Question: Does {src_mod} depend on {tgt_mod}? Is there a concept implemented in {src_mod} that constrains or shapes {tgt_mod}?

If YES, output: DEPENDENCY|<edge_type>|<invariant>|<failure_mode>
If NO, output: NONE

If YES, output exactly: DEPENDENCY|<edge_type>|<invariant>|<failure_mode>
If NO, output exactly: NONE

Edge types: DATA_SOURCE (data flows), CONSTRAINT (invariant restricts), MUTATION_TRIGGER (action triggers update), SPECIFICATION (formal spec for implementation)
Invariant: max 100 chars, describe what must hold at the boundary
Failure: max 100 chars, describe what breaks if violated

Example: DEPENDENCY|DATA_SOURCE|Python EMLTree must mirror Lean EMLTree|Type mismatch causes deserialization errors"""


_lib = None  # module-level reasoning library (lazy-loaded)

def get_library():
    """Get or create the reasoning library singleton."""
    global _lib
    if _lib is None:
        _lib = ReasoningLibrary(LIBRARY_PATH)
    return _lib


def get_pair_embedding(src_mod, tgt_mod, src_content, tgt_content,
                       src_path="", tgt_path="",
                       max_retries=3) -> list[float] | None:
    """Compute a 1024-dim pair embedding via the bge-m3 server.

    Uses the same concatenation scheme as trace embedding (module names
    + content previews) so that script centroids match correctly.
    """
    text = f"{src_mod} {tgt_mod} {str(src_content)[:200]} {str(tgt_content)[:200]}"
    for attempt in range(max_retries):
        try:
            resp = requests.post(
                EMBED_API,
                json={"model": "bge-m3", "input": text},
                timeout=30,
            )
            resp.raise_for_status()
            return resp.json()["data"][0]["embedding"]
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(1)
            else:
                logger.warning(f"Embedding failed for {src_mod}→{tgt_mod}: {e}")
                return None


def _compute_layer_edge_counts(lib):
    """Compute edge type frequency by layer pair from existing traces."""
    counts = {}
    for t in lib._traces.values():
        if not t.is_positive or not t.result:
            continue
        lp = (t.inputs.get("source_layer"), t.inputs.get("target_layer"))
        et = t.result.get("edge_type", "SPECIFICATION")
        if lp not in counts:
            counts[lp] = {}
        counts[lp][et] = counts[lp].get(et, 0) + 1
    return counts


def verify_pair(src_mod, tgt_mod, src_layer, tgt_layer, src_content, tgt_content,
                pair_key: str = "", embedding: list[float] | None = None,
                layer_edge_counts: dict | None = None):
    """Call 35B to verify a single cross-layer pair.

    Uses the reasoning library for three-tier routing:
      1. Hardcoded rule match → instant result, no LLM call
      2. Script centroid match (via embedding similarity) → compressed system prompt
      3. Layer-pair fallback → compressed system prompt for matching layer pair
      4. No match → full 35B reasoning

    Args:
        embedding: 1024-dim pair embedding from get_pair_embedding().
                  If None, script centroid matching is skipped (Tier 3 layer-pair
                  fallback still works).
        layer_edge_counts: Dict of (src_layer, tgt_layer) → {edge_type: count}
                          for weighted layer-pair script selection.

    Returns (content, reasoning_content, script_id, routing_kind, result_dict).
    """
    lib = get_library()
    router = EmbeddingRouter(script_threshold=0.60)
    task_hash = CROSS_LAYER_CONFIG.input_schema_hash()
    if layer_edge_counts is None:
        layer_edge_counts = _compute_layer_edge_counts(lib)

    inputs = {
        "source_module": src_mod,
        "target_module": tgt_mod,
        "source_layer": src_layer,
        "target_layer": tgt_layer,
    }

    # Route through the library
    decision = router.route(
        inputs=inputs,
        pair_embedding=embedding,
        task_config=CROSS_LAYER_CONFIG,
        hardcoded_rules=lib.get_rules(task_hash),
        scripts=lib._scripts,
        script_centroids=lib._script_centroids,
        layer_edge_counts=layer_edge_counts,
    )

    # Tier 1: Hardcoded rule match → instant
    if decision.kind == "hardcoded" and decision.result:
        result = decision.result
        return (
            f"DEPENDENCY|{result.get('edge_type','?')}|{result.get('invariant_at_boundary','')}|{result.get('failure_mode','')}",
            "(hardcoded rule)",
            decision.rule_id,
            "hardcoded",
            result,
        )

    # Build the prompt
    prompt = VERIFY_PROMPT.format(
        src_mod=src_mod, tgt_mod=tgt_mod,
        src_layer=src_layer, tgt_layer=tgt_layer,
        src_content=src_content[:1500],
        tgt_content=tgt_content[:1500],
    )

    # Tier 2: Script match → use compressed system prompt
    messages = [{"role": "user", "content": prompt}]
    if decision.kind == "script" and decision.script_id:
        script = lib.get_script(decision.script_id)
        if script:
            messages.insert(0, {"role": "system", "content": script.system_prompt})

    # Tier 3: Fallback → use default system prompt
    if decision.kind == "fallback":
        messages.insert(0, {"role": "system", "content": DEFAULT_SYSTEM_PROMPT})

    payload = {
        "model": LLM_MODEL,
        "messages": messages,
        "temperature": 0,
        "seed": int(hashlib.sha256(f"{src_mod}:{tgt_mod}".encode()).hexdigest()[:8], 16),
        "max_tokens": 4096,
        "cache_prompt": False,
    }

    for attempt in range(3):
        try:
            resp = requests.post(LLM_API, json=payload, timeout=120)
            resp.raise_for_status()
            data = resp.json()
            choice = data["choices"][0]["message"]
            content = (choice.get("content") or "").strip()
            reasoning_content = choice.get("reasoning_content", "")
            script_id = decision.script_id if decision.kind == "script" else None
            return (content, reasoning_content, script_id, decision.kind, None)
        except Exception as e:
            if attempt < 2:
                time.sleep(5)
            else:
                print(f"    FAILED: {e}")
                return ("ERROR", "", None, "error", None)


def parse_verification(content):
    """Parse 35B verification response."""
    content = content.strip()
    # Accept DEPENDENCY followed by | or : separator
    if content.startswith("DEPENDENCY"):
        # Split on | (the separator used in the prompt)
        parts = content.split("|")
        if len(parts) >= 4:
            return {
                "is_dependency": True,
                "original_response": content,
                "edge_type": parts[1].strip(),
                "invariant": parts[2].strip(),
                "failure_mode": parts[3].strip(),
            }
        elif len(parts) >= 2:
            return {
                "is_dependency": True,
                "original_response": content,
                "edge_type": parts[1].strip(),
            }
        else:
            # Just starts with DEPENDENCY but no structured fields
            return {
                "is_dependency": True,
                "original_response": content,
                "edge_type": "DATA_SOURCE",
            }
    elif content.upper() == "NONE":
        return {"is_dependency": False, "original_response": content}
    else:
        # Could be a free-form YES response
        if content.upper().startswith("YES") or content.upper().startswith("Y"):
            return {"is_dependency": True, "original_response": content, "edge_type": "DATA_SOURCE"}
        return {"is_dependency": False, "original_response": content}


def stage2_verify(candidates_file, batch_size):
    """Run Stage 2: verify candidates with 35B."""
    print("═══ Phase 5 — Stage 2: 35B verification ═══")

    # Load data
    with open(CACHE) as f:
        cache = json.load(f)
    da_notes = fetch_deep_analysis_notes()
    texts = build_text_map(cache, da_notes)

    # Load candidates
    if not candidates_file:
        candidates_file = CANDIDATES_FILE
    candidates_file = Path(candidates_file)
    if not candidates_file.exists():
        print(f"ERROR: Candidates file not found: {candidates_file}")
        print("Run 'phase5_cross_layer_discovery.py candidates' first")
        return

    with open(candidates_file) as f:
        data = json.load(f)
    candidates = data.get("candidates", [])
    print(f"Loaded {len(candidates)} candidates from {candidates_file}")

    if not candidates:
        print("No candidates to verify.")
        return

    # Load existing graph
    with open(GRAPH) as f:
        graph = json.load(f)
    existing_edges = graph.get("edges", [])

    # Deduplicate against existing edges
    existing_pairs = set()
    for e in existing_edges:
        if isinstance(e, dict):
            src = e.get("source", {})
            tgt = e.get("target", {})
            if isinstance(src, dict) and isinstance(tgt, dict):
                existing_pairs.add((src.get("module", ""), tgt.get("module", "")))

    # Load verification cache (to avoid re-verifying)
    verify_cache_file = Path("/tmp/phase5_verify_cache.json")
    verify_cache = {}
    if verify_cache_file.exists():
        try:
            with open(verify_cache_file) as f:
                verify_cache = json.load(f)
            print(f"Loaded {len(verify_cache)} cached verifications")
        except:
            pass

    verified = []
    lib = get_library()
    task_hash = CROSS_LAYER_CONFIG.input_schema_hash()
    layer_edge_counts = _compute_layer_edge_counts(lib)

    for i, c in enumerate(candidates):
        pair = (c["source_module"], c["target_module"])
        if pair in existing_pairs:
            print(f"  [{i+1}/{len(candidates)}] SKIP (already exists): {pair[0]} → {pair[1]}")
            continue

        # Check verification cache (legacy)
        cache_key = f"{c['source_path']}:{c['target_path']}"
        if cache_key in verify_cache:
            result = verify_cache[cache_key]
            if result.get("is_dependency"):
                print(f"  [{i+1}/{len(candidates)}] CACHED ✅: {c['source_module']} → {c['target_module']}")
            else:
                print(f"  [{i+1}/{len(candidates)}] CACHED ❌: {c['source_module']} → {c['target_module']}")
            if result.get("is_dependency"):
                verified.append(result)
            continue

        # Get content for both modules
        src_content = texts.get(c["source_path"], f"Module {c['source_module']} ({c['source_layer']})")
        tgt_content = texts.get(c["target_path"], f"Module {c['target_module']} ({c['target_layer']})")

        print(f"  [{i+1}/{len(candidates)}] VERIFY: {c['source_module']} ({c['source_layer']}) "
              f"→ {c['target_module']} ({c['target_layer']}) [sim={c['similarity']}]")
        sys.stdout.flush()

        # Compute pair embedding for script centroid routing
        pair_emb = get_pair_embedding(
            c["source_module"], c["target_module"],
            src_content, tgt_content,
            src_path=c["source_path"], tgt_path=c["target_path"],
        )

        # Verify (uses reasoning library routing internally)
        content, reasoning, script_id, routing_kind, hardcoded_result = verify_pair(
            c["source_module"], c["target_module"],
            c["source_layer"], c["target_layer"],
            src_content, tgt_content,
            pair_key=cache_key,
            embedding=pair_emb,
            layer_edge_counts=layer_edge_counts,
        )
        
        # Parse result
        if hardcoded_result:
            # Hardcoded rule matched — result is pre-determined
            is_dep = True
            parsed = {
                "is_dependency": True,
                "original_response": content,
                "edge_type": hardcoded_result.get("edge_type", "SPECIFICATION"),
                "invariant": hardcoded_result.get("invariant_at_boundary", ""),
                "failure_mode": hardcoded_result.get("failure_mode", ""),
            }
        else:
            parsed = parse_verification(content)
            is_dep = parsed.get("is_dependency", False)
        
        print(f"    Result: {'✅ DEPENDENCY' if is_dep else '❌ NONE'} "
              f"[{routing_kind}]")

        # Cache the result
        verify_cache[cache_key] = parsed

        # Save trace to reasoning library
        trace = ReasoningTrace(
            pair_key=cache_key,
            inputs={
                "source_module": c["source_module"],
                "target_module": c["target_module"],
                "source_layer": c["source_layer"],
                "target_layer": c["target_layer"],
                "source_content": src_content,
                "target_content": tgt_content,
            },
            reasoning_content=reasoning,
            final_content=content,
            result={
                "edge_type": parsed.get("edge_type", ""),
                "invariant_at_boundary": parsed.get("invariant", ""),
                "failure_mode": parsed.get("failure_mode", ""),
            } if is_dep else None,
            is_positive=is_dep,
            embedding=None,
            task_config_hash=task_hash,
        )
        lib.add_trace(trace)

        if is_dep:
            edge = {
                "edge_id": f"E{len(graph.get('edges', [])) + len(verified) + 1:03d}",
                "edge_type": parsed.get("edge_type", c["edge_type"]),
                "source": {"module": c["source_module"], "symbol": c["source_module"].split(".")[0]},
                "target": {"module": c["target_module"], "symbol": c["target_module"].split(".")[0]},
                "invariant_at_boundary": parsed.get("invariant", ""),
                "failure_mode": parsed.get("failure_mode", ""),
                "tags": [c["source_layer"].lower(), c["target_layer"].lower(), "discovered"],
                "layer_source": c["source_layer"],
                "layer_target": c["target_layer"],
                "routing": routing_kind,
                "script_id": script_id,
                "_pass": 3,
                "_version": 2,
                "_params": {
                    "temperature": 0,
                    "seed_mode": "content_hash",
                    "model": LLM_MODEL,
                    "similarity": c["similarity"],
                },
                "_versioned_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            }
            verified.append(edge)
            print(f"    → New edge: {edge['edge_id']}: {c['source_module']} → {c['target_module']} "
                  f"[{parsed.get('edge_type', 'UNKNOWN')}]")

        # Save verification cache + reasoning library periodically
        if (i + 1) % batch_size == 0:
            with open(verify_cache_file, "w") as f:
                json.dump(verify_cache, f)
            lib.save()
            print(f"    --- checkpoint: {i+1} processed, {len(verified)} new edges, "
                  f"{len(lib.get_traces(task_hash))} library traces ---")
            time.sleep(2)

    print(f"\nVerified {len(verified)} new edges out of {len(candidates)} candidates")

    # Save verified edges
    if verified:
        verified_file = Path("/tmp/phase5_verified_edges.json")
        with open(verified_file, "w") as f:
            json.dump(verified, f, indent=2)
        print(f"Saved {len(verified)} verified edges to {verified_file}")
        print("\nTo merge into DEPENDENCY_GRAPH.json:")
        print(f"  python3 -c \"import json; d=json.load(open('{GRAPH}')); "
              f"d['edges'].extend(json.load(open('{verified_file}'))); "
              f"json.dump(d, open('{GRAPH}','w'), indent=2)\"")

    return verified


# ═══════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return

    command = sys.argv[1]

    # Parse common args
    threshold = DEFAULT_SIM_THRESHOLD
    max_pairs = DEFAULT_MAX_PAIRS
    batch_size = 5
    candidates_file = None

    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == "--threshold" and i + 1 < len(sys.argv):
            threshold = float(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == "--max-pairs" and i + 1 < len(sys.argv):
            max_pairs = int(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == "--batch-size" and i + 1 < len(sys.argv):
            batch_size = int(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == "--candidates-file" and i + 1 < len(sys.argv):
            candidates_file = sys.argv[i + 1]
            i += 2
        else:
            i += 1

    if command == "candidates":
        stage1_candidates(threshold, max_pairs)
    elif command == "verify":
        stage2_verify(candidates_file, batch_size)
    elif command == "run":
        stage1_candidates(threshold, max_pairs)
        stage2_verify(candidates_file, batch_size)
    else:
        print(f"Unknown command: {command}")
        print(__doc__)


if __name__ == "__main__":
    main()
