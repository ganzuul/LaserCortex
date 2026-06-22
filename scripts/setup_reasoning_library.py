#!/usr/bin/env python3
"""Set up the reasoning library for cross-layer dependency verification.

This script:
  1. Defines the TaskConfig for cross-layer dependency verification
  2. Seeds hardcoded rules from 73 verified edges (learned patterns)
  3. Migrates existing verification cache into library traces
  4. Compresses trace clusters into initial reasoning scripts
  5. Saves the library for use by phase5_cross_layer_discovery.py

Run this after every verification batch to grow the library.
"""

import json
import re
import sys
import hashlib
import time
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


# ── Define the task ──────────────────────────────────────────────────

CROSS_LAYER_CONFIG = TaskConfig(
    name="cross-layer-dependency",
    description="""Determine if a semantic dependency exists between two software modules from different architectural layers (FORMALIZATION/API_GATEWAY/PRESENTATION). A dependency exists when one module's contracts, invariants, or constraints directly affect the other module's behavior or correctness.""",
    input_fields={
        "source_module": "Name of the source module (abstract or file path)",
        "target_module": "Name of the target module (abstract or file path)",
        "source_layer": "Architectural layer: FORMALIZATION (Lean proofs), API_GATEWAY (Python backend), or PRESENTATION (TypeScript frontend)",
        "target_layer": "Architectural layer of the target",
        "source_content": "Deep Analysis note content for the source module (Intent, Contracts, Cross-refs)",
        "target_content": "Deep Analysis note content for the target module",
    },
    output_taxonomy={
        "edge_type": {
            "SPECIFICATION": "Source defines formal invariants that target must preserve (e.g., Lean theorem constrains Python implementation)",
            "CONSTRAINT": "Source API/schema dictates target's interface or behavior (e.g., backend endpoint constrains frontend types)",
            "DATA_SOURCE": "Source provides data that target consumes directly (e.g., backend service feeds frontend store)",
        }
    },
    format_instruction="DEPENDENCY|EDGE_TYPE|INVARIANT|FAILURE_MODE or NONE",
    positive_marker="DEPENDENCY",
    negative_marker="NONE",
)


# ── Hardcoded rules (derived from 73 verified edges) ────────────────

def build_rules():
    """Build hardcoded pattern-matching rules from observed patterns.

    Each rule captures a reliable pattern where we can skip the LLM entirely.
    Rules are matched by name patterns — simple glob-like matching.
    """
    rules = []
    task_hash = CROSS_LAYER_CONFIG.input_schema_hash()
    rule_id = 0

    def add(layer_pair, src_pat, tgt_pat, edge_type, invariant, failure_mode):
        nonlocal rule_id
        rule_id += 1
        rules.append(HardcodedRule(
            id=f"rule_{rule_id:03d}",
            task_config_hash=task_hash,
            field_patterns={
                "source_module": src_pat,
                "target_module": tgt_pat,
            },
            result={
                "edge_type": edge_type,
                "invariant_at_boundary": invariant,
                "failure_mode": failure_mode,
            },
            is_positive=True,
        ))

    # ── FORMALIZATION → API_GATEWAY patterns ──
    # Any Lean .lean file → any _*.py infra file in the same domain
    # Pattern: LeanRegistry.lean → _registry.py, LeanTheorem.lean → _theorem.py
    # Edge type: SPECIFICATION (formal invariants constrain implementation)
    
    add(("FORMALIZATION", "API_GATEWAY"),
        "*Registry.lean", "_*.py",
        "SPECIFICATION",
        "Formal type-registry invariants and proof witnesses must be mirrored in Python implementation",
        "Python state violates certification invariants, causing invalid gate checks and deserialization failures")
    
    add(("FORMALIZATION", "API_GATEWAY"),
        "*Paradox.lean", "_*.py",
        "SPECIFICATION",
        "Lean cost and contraction bounds must be enforced in Python implementation",
        "Divergent execution exceeds formal bounds or violates soundness guarantees")
    
    add(("FORMALIZATION", "API_GATEWAY"),
        "*Composition.lean", "_*.py",
        "SPECIFICATION",
        "Formal decomposition constraints and depth truncation bounds must be mirrored in Python",
        "Python implementation diverges from formal decomposition, causing incorrect inference")
    
    add(("FORMALIZATION", "API_GATEWAY"),
        "*Closure.lean", "_*.py",
        "SPECIFICATION",
        "Lean4 closure specification must constrain Python LogicM pipeline computation",
        "Divergence causes semantic drift in closure computation")
    
    add(("FORMALIZATION", "API_GATEWAY"),
        "*Cost.lean", "_*.py",
        "SPECIFICATION",
        "Size preservation and height invariants must be enforced in Python EMLTree implementation",
        "Violation causes unbounded recursion or incorrect tree operations")
    
    add(("FORMALIZATION", "API_GATEWAY"),
        "*AMM.lean", "_*.py",
        "SPECIFICATION",
        "AMM formal invariants must constrain Python asset management implementation",
        "Divergence causes incorrect asset mutation or invariant violation")
    
    add(("FORMALIZATION", "API_GATEWAY"),
        "*.lean", "*.py",
        "SPECIFICATION",
        "Lean formal invariants must be mirrored in Python implementation",
        "Semantic drift breaks certified type-registry bindings")

    # ── API_GATEWAY → PRESENTATION patterns ──
    # *_router.py → *Api.ts: API contract dictates client interface
    add(("API_GATEWAY", "PRESENTATION"),
        "*_router.py", "*Api.ts",
        "CONSTRAINT",
        "Backend API contracts and Pydantic schemas strictly define request/response contracts for frontend API service",
        "Client deserialization fails or error handling mismatches API responses")
    
    # *_service.py → api.ts: Backend service schema constrains general api.ts
    add(("API_GATEWAY", "PRESENTATION"),
        "*_service.py", "api.ts",
        "CONSTRAINT",
        "Backend service response schema must match frontend API TypeScript interface definitions",
        "Frontend breaks on unexpected response shapes or missing fields")
    
    add(("API_GATEWAY", "PRESENTATION"),
        "*_service.py", "api.ts",
        "SPECIFICATION",
        "Backend API response schema and endpoint contracts must match frontend TypeScript expectations",
        "Frontend type errors cause runtime crashes or incorrect rendering")
    
    # *_schemas.py → *.ts: Schema definitions constrain frontend types
    add(("API_GATEWAY", "PRESENTATION"),
        "*_schemas.py", "*.ts",
        "SPECIFICATION",
        "Backend schema field definitions must align with frontend type definitions and interfaces",
        "Frontend type mismatches cause serialization/deserialization failures")
    
    # *_service.py → *Store.ts or *Panel.tsx: Backend feeds frontend state
    add(("API_GATEWAY", "PRESENTATION"),
        "*_service.py", "*Store.ts",
        "DATA_SOURCE",
        "Service API response schema must match store TypeScript interface definitions",
        "Store state becomes inconsistent, causing incorrect UI rendering")
    
    add(("API_GATEWAY", "PRESENTATION"),
        "*_service.py", "*Panel.tsx",
        "CONSTRAINT",
        "Backend data schema constrains frontend panel component props and behavior",
        "Panel renders incorrect state or fails to display data")
    
    # *_settings_service.py → *SettingsPanel.tsx
    add(("API_GATEWAY", "PRESENTATION"),
        "*_settings_service.py", "*SettingsPanel.tsx",
        "CONSTRAINT",
        "Backend validation rules and API schema must align with frontend settings panel expectations",
        "Settings panel fails to validate or display correct configuration")
    
    # *_config*.py → *Config*.tsx
    add(("API_GATEWAY", "PRESENTATION"),
        "*config*.py", "*Config*.tsx",
        "DATA_SOURCE",
        "Backend config schema must match frontend config preview data interface",
        "Config preview displays incorrect or missing configuration fields")
    
    # *_tool.py or *_tool_injection.py → api.ts
    add(("API_GATEWAY", "PRESENTATION"),
        "*_tool*.py", "api.ts",
        "CONSTRAINT",
        "Backend tool API contract dictates frontend request/response handling",
        "Frontend fails to parse tool results or sends malformed requests")
    
    # *_registry*.py → *Panel.tsx or *Store.ts
    add(("API_GATEWAY", "PRESENTATION"),
        "*_registry*.py", "*Panel.tsx",
        "CONSTRAINT",
        "Registry schema constrains panel rendering and interaction",
        "Panel fails to display registry data correctly")
    
    # *_events*.py → *websocket*.ts  
    add(("API_GATEWAY", "PRESENTATION"),
        "*events*.py", "*websocket*.ts",
        "DATA_SOURCE",
        "Backend event schema must match frontend WebSocket event handler expectations",
        "WebSocket messages are unparseable or trigger incorrect UI updates")
    
    return rules


# ── Migration ────────────────────────────────────────────────────────

def migrate_cache(lib: ReasoningLibrary, cache_path: str):
    """Migrate existing verification cache entries into library traces."""
    with open(cache_path) as f:
        cache = json.load(f)
    
    migrated = 0
    for key, entry in cache.items():
        if ":" not in key:
            continue
        src_path, tgt_path = key.split(":", 1)
        
        # Determine layers from path convention
        def path_to_layer(path):
            if path.endswith(".lean"):
                return "FORMALIZATION"
            elif path.endswith((".ts", ".tsx")):
                return "PRESENTATION"
            else:
                return "API_GATEWAY"
        
        # Module names from paths
        src_mod = re.sub(r"^.*/", "", src_path).replace(".lean", "").replace(".py", "").replace(".ts", "").replace(".tsx", "")
        tgt_mod = re.sub(r"^.*/", "", tgt_path).replace(".lean", "").replace(".py", "").replace(".ts", "").replace(".tsx", "")
        
        # If we have reasoning content, use it; otherwise just the final content
        reasoning = entry.get("reasoning_content", "(no reasoning trace captured)")
        final = entry.get("original_response", "")
        
        is_dep = entry.get("is_dependency", False)
        result = {
            "edge_type": entry.get("edge_type", "?"),
            "invariant_at_boundary": entry.get("invariant", ""),
            "failure_mode": entry.get("failure_mode", ""),
        } if is_dep else None
        
        trace = ReasoningTrace(
            pair_key=key,
            inputs={
                "source_module": src_mod,
                "target_module": tgt_mod,
                "source_layer": path_to_layer(src_path),
                "target_layer": path_to_layer(tgt_path),
                "source_content": entry.get("source_content", ""),
                "target_content": entry.get("target_content", ""),
            },
            reasoning_content=reasoning,
            final_content=final,
            result=result,
            is_positive=is_dep,
            embedding=None,  # Can compute later
            total_tokens=0,
            timestamp=entry.get("timestamp", time.time()),
            task_config_hash=CROSS_LAYER_CONFIG.input_schema_hash(),
        )
        lib.add_trace(trace)
        migrated += 1
    
    return migrated


# ── Main ─────────────────────────────────────────────────────────────

def main():
    print("═══ Setup Reasoning Library ═══\n")
    
    # 1. Define task config
    print(f"Task: {CROSS_LAYER_CONFIG.name}")
    print(f"  Description: {CROSS_LAYER_CONFIG.description[:60]}...")
    print(f"  Schema hash: {CROSS_LAYER_CONFIG.input_schema_hash()}")
    print(f"  Output taxonomy: {len(CROSS_LAYER_CONFIG.output_taxonomy['edge_type'])} edge types")
    print()
    
    # 2. Load/create library
    lib = ReasoningLibrary("/tmp/reasoning_library.json")
    print(f"Loaded library: {lib.stats()}\n")
    
    # 3. Set hardcoded rules
    rules = build_rules()
    existing_rules = lib.get_rules(task_config_hash=CROSS_LAYER_CONFIG.input_schema_hash())
    if existing_rules:
        print(f"Library already has {len(existing_rules)} rules for this task")
    else:
        for rule in rules:
            lib.add_rule(rule)
        print(f"Added {len(rules)} hardcoded rules")
    print()
    
    # 4. Migrate existing verification cache
    cache_path = "/tmp/phase5_verify_cache.json"
    existing_traces = lib.get_traces(task_config_hash=CROSS_LAYER_CONFIG.input_schema_hash())
    if existing_traces:
        print(f"Library already has {len(existing_traces)} traces for this task")
    else:
        migrated = migrate_cache(lib, cache_path)
        print(f"Migrated {migrated} traces from verification cache")
    print()
    
    # 5. Show cluster statistics
    clusters = lib.traces_by_cluster(CROSS_LAYER_CONFIG.input_schema_hash())
    print(f"Trace clusters (by layer_pair::edge_type):")
    for cluster_key, traces in sorted(clusters.items()):
        print(f"  {cluster_key}: {len(traces)} traces")
    
    # 6. Compress clusters into scripts
    if not lib.list_scripts(task_config_hash=CROSS_LAYER_CONFIG.input_schema_hash()):
        compressor = MetaCompressor(min_traces=3)
        for cluster_key, traces in sorted(clusters.items()):
            if len(traces) >= compressor.min_traces:
                script = compressor.compress(traces, CROSS_LAYER_CONFIG, cluster_key)
                if script:
                    lib.add_script(script)
                    print(f"  ✓ Script '{script.id}' created (confidence={script.confidence:.2f})")
    else:
        existing = lib.list_scripts(task_config_hash=CROSS_LAYER_CONFIG.input_schema_hash())
        print(f"\nLibrary already has {len(existing)} scripts for this task:")
        for s in existing:
            print(f"  {s.id}: [{s.estimated_edge_type}] {s.layer_pair} "
                  f"(conf={s.confidence:.2f}, {s.source_trace_count} traces)")
    
    # 7. Save
    lib.save()
    print(f"\nFinal library stats: {lib.stats()}")
    print("Done!")


if __name__ == "__main__":
    main()
