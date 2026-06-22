# NormCode MCP Integration Plan

## Goal

Build a FastMCP server exposing NormCode's parser, CortexBridge, and Orchestrator
as MCP tools, registered in opencode, so an opencode agent can:

1. **Parse** `.ncd` plan files into structured inference data
2. **Lift** inferences into the LaserCortex formal layer (EMLTree, certificates)
3. **Orchestrate** plans step-by-step with checkpoint/resume
4. **Close the loop**: discovery (Librarian) → execution (NormCode MCP) →
   verification (lean-lsp)

This is the "neuro-symbolic audit loop": reasoning library traces (informal
proofs) → lifted via CortexBridge → certified via Lean (typed cortex).

## Multi-Session Execution Plan

### Phase A: Fix flow→tree mapping (this session)

Replace the heuristic `tree_from_flow_index` (which uses flow index depth alone)
with `tree_from_inference_entry` (which uses the actual dependency structure:
`value_concepts`, `function_concept`, `supporting_items`, `coupling_signature`).

**Files**: `_eml_tree.py`, `_bridge.py`, `_orchestrator.py`

**Why first**: The MCP server's `lift_inference` tool produces a tree for every
inference. Without the formal mapping, every lifted tree is wrong — it only
reflects the depth of the flow index, not the actual inference shape.

**Scope**: ~100 lines modified across 3 files.

### Phase B: Build the NormCode MCP server (next session)

Create `scripts/mcp_normcode_server.py` — a FastMCP server that imports
`infra/*` directly (no canvas_app dependency) with three tool groups:

1. **Parser tools**: `parse_ncd`, `list_inferences`, `convert_format`
2. **Cortex tools**: `list_specs`, `get_spec`, `lift_inference`,
   `ground_certificate`, `list_certificates`, `verify_certificate`,
   `bridge_state`, `instantiate_writ`
3. **Orchestrator tools**: `load_plan`, `start_plan`, `step_plan`,
   `run_to`, `stop_plan`, `get_state`, `get_logs`, `get_step_progress`,
   `list_checkpoints`, `resume_checkpoint`, `fork_checkpoint`

**Lifecycle**: In-process `NormCodeCortexBridge` instance. Plan state held in
process (not persisted across MCP restarts). Checkpoints persisted to SQLite
via existing `OrchestratorDB`.

**Scope**: ~600 lines, new file.

### Phase C: Register in opencode (next session)

1. **`opencode.json`** — add `mcp` block registering `mcp_normcode_server.py`
2. **`.opencode/agents/normcode.md`** — routing agent: Librarian (discovery)
   → NormCode MCP (execution) → lean-lsp (verification)
3. **NormCode skill** — `SKILL.md` with syntax guide, sequence catalog,
   CortexSpec taxonomy

**Scope**: ~300 lines across 3 files.

### Phase D: Documentation (next session)

1. **`docs/normcode_mcp_spec.md`** — full tool catalog with examples
2. **Update `docs/phase5_pipeline.md`** — document the audit loop
3. **Commit** both repos

**Scope**: ~200 lines across 2 files.

---

## Architecture

```
opencode agent (normcode.md)
    │
    ├── MCP: mcp_normcode_server.py
    │       ├── parser tools     →  NormCodeParser (canvas_app/parsers/normcode.py)
    │       ├── cortex tools     →  CortexBridge (infra/_cortex/_bridge.py)
    │       └── orchestrator tools → Orchestrator (infra/_orchest/_orchestrator.py)
    │
    ├── Librarian MCP (discovery, cross-refs)
    │
    └── lean-lsp MCP (formal verification)
```

The MCP server imports `infra/*` directly — no canvas_app dependency. All
`infra/_cortex/` and `infra/_orchest/` modules are available in-process.

---

## Dependency Graph

```
Phase A (flow→tree fix) ──► Phase B (MCP server)
                                    │
                                    ▼
                          Phase C (opencode registration)
                                    │
                                    ▼
                          Phase D (documentation + commit)
```

**Phase A must come first** — the MCP server's `lift_inference` tool is only
trustworthy with a formal mapping. Phases B, C, D can be done in a single
following session.

---

## Key Design Decisions

### Why FastMCP (not Flask/FastAPI standalone)?

MCP is the opencode-native protocol. An MCP server is auto-discovered,
auto-managed, and auto-instrumented by opencode. A standalone HTTP server
would need manual lifecycle management.

### Why direct Python import (not subprocess)?

The CortexBridge is a pure in-memory transformation. There's no reason to
serialize/deserialize across process boundaries. The MCP server process
holds the bridge instance and the orchestrator state.

### Why fix flow→tree first?

`tree_from_flow_index` uses only the depth of the flow index (e.g., "1.2.3"
→ depth 3 → right-nested tree of size 3). A formal mapping uses:
- `len(value_concepts)` for tree size (inputs)
- `function_concept` for additional leaf (the operator)
- `coupling_signature` for bracketing (rightComb / leftComb / balanced)
- `supporting_count` for sub-inference structure

Without this fix, every lifted tree is incorrect — it only reflects
position in the flow, not the actual inference shape.

### Why not emit events / use a message bus?

For this phase, simplicity wins. The MCP server is single-process,
single-threaded. If multi-user orchestration becomes necessary, we can
add a message bus later. The current bottleneck is getting _one_ audit
loop working, not scaling to _many_.

---

## Capability Gaps (Deferred)

These are tracked in `docs/normcode_mcp_spec.md` as future milestones:

1. **Event emission** — NormCode MCP doesn't yet emit events for
   long-running plan execution (would need async MCP, which isn't
   standardised)
2. **Multi-user orchestration** — MCP server holds state per process;
   no user isolation
3. **Lean verification bridge** — MCP-to-lean-lsp routing is
   schematic (the normcode agent has both tools, but no formal
   `certify → verify` pipeline)
4. **Spec authoring UI** — CortexSpecs are loaded from
   `SEED_REGISTRY`; no GUI for creating new specs
5. **Webhook triggers** — plans are started manually; no cron/S3/CI
   triggers
6. **Schema registry** — form schemas are baked into spec objects;
   no external schema registry (JSON Schema, Avro, etc.)
