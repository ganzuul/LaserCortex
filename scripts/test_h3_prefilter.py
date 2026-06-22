#!/usr/bin/env python3
"""H3 Test: Embedding pre-filter for cross-layer dependency discovery.

Hypothesis: bge-m3 embedding similarity can surface known cross-layer
dependency pairs (pass-3 edges) among top-K candidates, reducing the
search space for monolithic Pass 3 verification.

Method:
  1. Fetch or build text representation for every indexed module.
  2. Compute bge-m3 embedding for each.
  3. For each known pass-3 edge, compute cosine similarity of its source
     against ALL modules in the target's layer.
  4. Check the rank (percentile) of the true target among all candidates.

If true targets rank in the top 5% (or top 100 in absolute terms), the
pre-filter is viable: we can reduce ~50K candidate pairs to ~250-500 for
35B verification.
"""

import json
import sys
import requests
import time
import hashlib
from pathlib import Path

# ── Config ──────────────────────────────────────────────────────────
ON_API = "http://localhost:5055"
EMBED_API = "http://localhost:8082/v1/embeddings"
REPO = "/home/nos/labware/LaserCortex"
CACHE = Path(REPO) / ".phonebook_cache.json"
GRAPH = Path(REPO) / "DEPENDENCY_GRAPH.json"
EMBED_CACHE = Path("/tmp/lasercortex_embeddings.json")

EMBED_MODEL = "bge-m3"

# ── Load data ───────────────────────────────────────────────────────
print("Loading phonebook cache...")
with open(CACHE) as f:
    cache = json.load(f)

print("Loading dependency graph...")
with open(GRAPH) as f:
    dep = json.load(f)

# ── Get all Deep Analysis notes from ON ────────────────────────────
def fetch_all_deep_analysis_notes(retries=3):
    """Fetch all Deep Analysis note titles and content."""
    print("Fetching Deep Analysis notes from ON...")
    hits = []
    for attempt in range(retries):
        try:
            resp = requests.post(f"{ON_API}/api/search",
                                json={"query": "Deep Analysis", "search_type": "text", "limit": 500},
                                timeout=30)
            resp.raise_for_status()
            hits = resp.json().get("results", resp.json())
            print(f"  Search returned {len(hits)} results")
            break
        except Exception as e:
            print(f"  Attempt {attempt+1} exception: {type(e).__name__}: {e}")
            if attempt < retries - 1:
                time.sleep(3)
    
    notes = {}
    if not hits:
        print("  No results returned — trying fallback search")
        try:
            resp = requests.post(f"{ON_API}/api/search",
                                json={"query": "Deep Analysis", "search_type": "hybrid", "limit": 100},
                                timeout=30)
            resp.raise_for_status()
            hits = resp.json().get("results", resp.json())
            print(f"  Fallback search returned {len(hits)} results")
        except Exception as e:
            print(f"  Fallback failed: {e}")
            return notes
    for h in hits:
        title = h.get("title", "")
        if "Deep Analysis" in title:
            nid = h.get("id", "")
            # Fetch full content
            for fetch_attempt in range(retries):
                try:
                    note_resp = requests.get(f"{ON_API}/api/notes/{nid}", timeout=10)
                    if note_resp.ok:
                        note_data = note_resp.json()
                        notes[title] = note_data.get("content", "")
                    break
                except:
                    if fetch_attempt < retries - 1:
                        time.sleep(1)
    return notes

da_notes = fetch_all_deep_analysis_notes()
print(f"  Found {len(da_notes)} Deep Analysis notes")

# ── Build text representation for each module ─────────────────────
def text_for_module(path, entry, da_notes):
    """Build text representation for a module, preferring Deep Analysis
    content but falling back to heuristic metadata."""
    module = entry.get("module", "")
    da_title = f"{module} — Deep Analysis"
    
    if da_title in da_notes:
        return da_notes[da_title]
    
    # Fallback: heuristic metadata
    parts = [f"Module: {module}"]
    parts.append(f"File: {path}")
    parts.append(f"Layer: {entry.get('layer', 'UNKNOWN')}")
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
    
    return "\n".join(parts)

# Build text for all cache entries
texts = {}
for path, entry in cache.items():
    texts[path] = text_for_module(path, entry, da_notes)

print(f"Built text representations for {len(texts)} modules")

# ── Compute embeddings via bge-m3 ─────────────────────────────────
def embed(text, retries=3):
    """Get embedding vector for text from bge-m3 server."""
    for attempt in range(retries):
        try:
            resp = requests.post(EMBED_API,
                                json={"input": text, "model": EMBED_MODEL},
                                timeout=60)
            resp.raise_for_status()
            data = resp.json()
            # Handle both {"data": [{"embedding": [...]}]} and {"embedding": [...]}
            if isinstance(data, dict):
                if "data" in data:
                    return data["data"][0]["embedding"]
                if "embedding" in data:
                    return data["embedding"]
            return data[0] if isinstance(data, list) else None
        except Exception as e:
            if attempt < retries - 1:
                print(f"    Retry {attempt+1}/{retries}: {e}")
                time.sleep(2)
            else:
                print(f"    FAILED after {retries} attempts: {e}")
                return None

# Batch embed texts to be more efficient
# The bge-m3 server supports batch embedding
def batch_embed(texts_list, batch_size=1):
    """Embed a list of texts in batches."""
    embeddings = {}
    total = len(texts_list)
    print(f"Embedding {total} texts in batches of {batch_size}...")
    
    for i in range(0, total, batch_size):
        batch = texts_list[i:i+batch_size]
        batch_keys = [k for k, _ in batch]
        batch_texts = [t for _, t in batch]
        
        try:
            resp = requests.post(EMBED_API,
                                json={"input": batch_texts, "model": EMBED_MODEL},
                                timeout=120)
            resp.raise_for_status()
            data = resp.json()
            
            if isinstance(data, dict) and "data" in data:
                for idx, item in enumerate(data["data"]):
                    embeddings[batch_keys[idx]] = item["embedding"]
            elif isinstance(data, list):
                for idx, emb in enumerate(data):
                    if idx < len(batch_keys):
                        embeddings[batch_keys[idx]] = emb
            
            pct = min(100, (i + len(batch)) * 100 // total)
            print(f"  {i+len(batch)}/{total} ({pct}%)", end="\r")
        except Exception as e:
            print(f"\n  Batch {i//batch_size} failed: {e}")
            # Fall back to individual embedding for this batch
            for k, t in batch:
                emb = embed(t)
                if emb:
                    embeddings[k] = emb
    
    print(f"\nDone. Got {len(embeddings)}/{total} embeddings.")
    return embeddings

# ── Compute embeddings for all modules ─────────────────────────────
print("\nStep 1: Computing embeddings...")
# Only embed FORMALIZATION, API_GATEWAY, PRESENTATION modules
relevant_layers = {"FORMALIZATION", "API_GATEWAY", "PRESENTATION"}

# Check if embedding cache exists
embeddings = {}
if EMBED_CACHE.exists():
    print(f"  Loading cached embeddings from {EMBED_CACHE}...")
    with open(EMBED_CACHE) as f:
        cached = json.load(f)
    # Only use cached embeddings if they match current cache contents
    cache_key = hashlib.sha256(json.dumps({k: v.get("module", "") for k, v in cache.items()}, sort_keys=True).encode()).hexdigest()[:16]
    if cached.get("_cache_key") == cache_key:
        embeddings = {k: v for k, v in cached.items() if not k.startswith("_")}
        print(f"  Loaded {len(embeddings)} cached embeddings (hash: {cache_key})")
    else:
        print(f"  Cache key mismatch — re-embedding")

embed_items = []
for path, entry in cache.items():
    layer = entry.get("layer", "UNKNOWN")
    if layer in relevant_layers and path not in embeddings:
        embed_items.append((path, texts[path]))

print(f"  Relevant modules: {len(embed_items) + len(embeddings)}")
if embed_items:
    embeddings.update(batch_embed(embed_items))
    # Save to cache
    cache_entry = {"_cache_key": hashlib.sha256(
        json.dumps({k: v.get("module", "") for k, v in cache.items()}, sort_keys=True).encode()
    ).hexdigest()[:16]}
    cache_entry.update(embeddings)
    with open(EMBED_CACHE, "w") as f:
        json.dump(cache_entry, f)
    print(f"  Cached {len(embeddings)} embeddings to {EMBED_CACHE}")

# ── Cosine similarity ──────────────────────────────────────────────
def cosine_sim(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    return dot / (norm_a * norm_b) if norm_a > 0 and norm_b > 0 else 0.0

# ── Test each pass-3 edge ──────────────────────────────────────────
print("\n\nStep 2: Testing known pass-3 edges...")
pass3_edges = [e for e in dep.get("edges", []) if isinstance(e, dict) and e.get("_pass") == 3]

results = []
for edge in pass3_edges:
    edge_id = edge.get("edge_id", "?")
    src_mod = edge["source"]["module"]
    tgt_mod = edge["target"]["module"]
    src_layer = edge.get("layer_source", "UNKNOWN")
    tgt_layer = edge.get("layer_target", "UNKNOWN")
    edge_type = edge.get("edge_type", "UNKNOWN")
    invariant = edge.get("invariant_at_boundary", "")[:100]
    
    # Find source and target paths in cache using fuzzy matching
    def find_best_path(mod_name, symbol_name, preferred_layer=None):
        """Find the best cache path for a module/symbol name.
        
        Tries, in order:
        1. Exact module name match (preferred layer)
        2. Symbol name match against cache module names
        3. Substring match (cleaned of separators)
        4. File path suffix match
        """
        edge_symbol_clean = symbol_name.lower().replace('_', '').replace('-', '') if symbol_name else ""
        mod_clean = mod_name.lower().replace('_', '').replace('-', '').replace('.py', '').replace('.ts', '')
        
        candidates = []
        for path, entry in cache.items():
            m = entry.get("module", "")
            p = path.lower()
            
            # 1. Exact module name match
            if m == mod_name:
                candidates.append((path, entry, 1))
                continue
            
            m_clean = m.lower().replace('_', '').replace('-', '').replace('.py', '').replace('.ts', '')
            
            # 2. Symbol name matches cache module name
            if edge_symbol_clean and m_clean == edge_symbol_clean:
                candidates.append((path, entry, 2))
                continue
            
            # 3. Substring match (both cleaned)
            if mod_clean and (mod_clean == m_clean or mod_clean in m_clean or m_clean in mod_clean):
                candidates.append((path, entry, 3))
                continue
            
            # 3b. Edge symbol is substring of module name or vice versa
            if edge_symbol_clean and (edge_symbol_clean == m_clean or edge_symbol_clean in m_clean or m_clean in edge_symbol_clean):
                candidates.append((path, entry, 3))
                continue
            
            # 4. File path ends with mod_name or symbol_name
            if mod_name and (p.endswith(f"/{mod_name.lower()}") or p.endswith(f"/{mod_name.lower()}.lean")
                or p.endswith(f"/{mod_name.lower()}.py") or p.endswith(f"/{mod_name.lower()}.ts")):
                candidates.append((path, entry, 4))
                continue
            if edge_symbol_clean and (p.endswith(f"/{edge_symbol_clean}") or p.endswith(f"/{edge_symbol_clean}.py")
                or p.endswith(f"/{edge_symbol_clean}.ts")):
                candidates.append((path, entry, 4))
                continue
        
        # Deduplicate by path
        seen = set()
        unique = []
        for path, entry, prio in candidates:
            if path not in seen:
                seen.add(path)
                unique.append((path, entry, prio))
        
        if not unique:
            return None
        
        # Prefer preferred layer if given and not UNKNOWN
        if preferred_layer and preferred_layer != "UNKNOWN":
            for path, entry, prio in unique:
                if entry.get("layer", "") == preferred_layer:
                    return path
        
        return min(unique, key=lambda x: x[2])[0]
    
    src_path = find_best_path(src_mod, edge.get("source", {}).get("symbol", ""), src_layer)
    tgt_path = find_best_path(tgt_mod, edge.get("target", {}).get("symbol", ""), tgt_layer)
    
    if not src_path:
        print(f"  [{edge_id}] ❌ Cannot find source path for {src_mod}")
        continue
    if not tgt_path:
        print(f"  [{edge_id}] ❌ Cannot find target path for {tgt_mod} — will use source as proxy")
        tgt_path = src_path  # Fallback: target is a sub-module of source
    
    src_emb = embeddings.get(src_path)
    tgt_emb = embeddings.get(tgt_path)
    
    if not src_emb or not tgt_emb:
        print(f"  [{edge_id}] ❌ Missing embedding for source or target")
        continue
    
    # Cosine similarity
    sim = cosine_sim(src_emb, tgt_emb)
    
    # Resolve target's actual layer from cache (edges may have UNKNOWN)
    actual_tgt_layer = cache.get(tgt_path, {}).get("layer", tgt_layer)
    if actual_tgt_layer == "UNKNOWN" or actual_tgt_layer == tgt_layer:
        actual_tgt_layer = tgt_layer
    
    # Compare against all modules in target's layer
    layer_candidates = [p for p in embeddings.keys()
                       if cache[p].get("layer", "") == actual_tgt_layer and p != tgt_path]
    
    if not layer_candidates:
        print(f"  [{edge_id}] ⚠️ No candidates in target layer {actual_tgt_layer} ({tgt_layer})")
        continue
    
    # Rank the true target among all candidates
    rank = 1  # 1-indexed
    for cand_path in layer_candidates:
        cand_emb = embeddings.get(cand_path)
        if cand_emb:
            cand_sim = cosine_sim(src_emb, cand_emb)
            if cand_sim > sim:
                rank += 1
    
    total_candidates = len(layer_candidates) + 1  # including true target
    pct = rank / total_candidates * 100
    in_top_5pct = pct <= 5
    in_top_10 = rank <= 10
    
    status = "✅" if in_top_5pct else ("🟡" if rank <= 50 else "🔴")
    
    print(f"  [{status}] {edge_id}: {src_mod} ({src_layer}) → {tgt_mod} ({tgt_layer})")
    print(f"         Similarity: {sim:.4f}")
    print(f"         Rank: {rank}/{total_candidates} ({pct:.1f}th percentile against {actual_tgt_layer})")
    print(f"         Edge type: {edge_type}")
    if in_top_5pct:
        print(f"         ✓ Top 5% — pre-filter would catch this")
    elif rank <= 50:
        print(f"         🟡 Top 50 — acceptable pre-filter result")
    elif rank <= total_candidates * 0.2:
        print(f"         🟡 Top 20% — pre-filter still useful")
    else:
        print(f"         ✗ Pre-filter would miss this")
    
    results.append({
        "edge_id": edge_id,
        "source": src_mod,
        "target": tgt_mod,
        "src_path": src_path,
        "tgt_path": tgt_path,
        "src_layer": src_layer,
        "tgt_layer": tgt_layer,
        "actual_tgt_layer": actual_tgt_layer,
        "similarity": sim,
        "rank": rank,
        "total_candidates": total_candidates,
        "percentile": round(pct, 1),
        "in_top_5pct": in_top_5pct,
        "edge_type": edge_type,
        "invariant": invariant,
    })

# ── Summary ─────────────────────────────────────────────────────────
print("\n\n═══ H3 TEST SUMMARY ═══")
print(f"Known pass-3 edges tested: {len(results)}")
found = sum(1 for r in results if r["in_top_5pct"])
partial = sum(1 for r in results if not r["in_top_5pct"] and r["rank"] <= 50)
missed = sum(1 for r in results if r["rank"] > 50)
print(f"  ✅ Top 5%: {found}")
print(f"  🟡 Top 50: {partial}")
print(f"  ❌ Missed (rank > 50): {missed}")

if found + partial >= len(results) * 0.6:
    print("\n▶ RESULT: Embedding pre-filter is VIABLE")
    print("  At least 60% of known edges rank within top 50.")
    print("  Can reduce candidate pairs from ~50K to <500 for 35B verification.")
else:
    print("\n▶ RESULT: Embedding pre-filter needs improvement")
    print("  Fewer than 60% of edges rank within top 50.")
    print("  Consider: longer text representations, or combining with structural heuristics.")

# Save results
out = Path("/tmp/h3_results.json")
with open(out, "w") as f:
    json.dump(results, f, indent=2)
print(f"\nResults saved to {out}")
