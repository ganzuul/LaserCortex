# NormCode MCP Server — Specification

## Overview

A FastMCP server exposing NormCode's Parser, CortexBridge, and Orchestrator as
MCP tools for opencode agents. Direct Python imports — no canvas_app dependency,
no subprocess — for minimal latency and zero serialization overhead.

## Architecture

```
opencode agent
    │
    ├── MCP tool call (JSON-RPC over stdio)
    │
    ▼
mcp_normcode_server.py
    │
    ├── InfraParserTools (wraps NormCodeParser)
    ├── InfraCortexTools (wraps NormCodeCortexBridge)
    ├── InfraOrchestratorTools (wraps Orchestrator)
    │
    ├── import infra/_core    → Concept, Reference, Inference
    ├── import infra/_cortex  → CortexBridge, EMLTree, CortexCertificate
    ├── import infra/_orchest → Orchestrator, Waitlist, InferenceRepo
    │
    └── import canvas_app/backend/services/parsers/normcode → NormCodeParser
```

The server is single-process, single-threaded. Plan state is held in memory;
checkpoints are persisted to SQLite via `OrchestratorDB`.

---

## Tool Catalog

### Parser Tools (`normcode_parse_*`)

Wrap `NormCodeParser` and `NDRangeParser`:

| Tool | Signature | Description |
|------|-----------|-------------|
| `normcode_parse_file` | `(path: str) -> dict` | Parse `.ncd` file → structured JSON: concepts, operators, flow indices, NC lines |
| `normcode_parse_text` | `(text: str) -> dict` | Parse inline NCD text → same structure |
| `normcode_list_inferences` | `(plan: dict) -> list[dict]` | Extract inference list with flow_index, concept_to_infer, value_concepts, function_concept, sequence_type |
| `normcode_get_concept` | `(plan: dict, name: str) -> dict` | Look up a concept definition by name |
| `normcode_get_operator` | `(plan: dict, operator: str) -> dict` | Look up an NC operator definition by symbol |
| `normcode_convert_format` | `(source: str, target: str) -> str` | Convert between NCD/NCN/NCDN/JSON formats |
| `normcode_validate` | `(plan: dict) -> list[str]` | Validate plan structure, report errors |
| `normcode_summary` | `(plan: dict) -> str` | Human-readable plan summary (inferences, concepts, layers) |

### Cortex Tools (`normcode_cortex_*`)

Wrap `NormCodeCortexBridge` (which wraps `CortexBridge`):

| Tool | Signature | Description |
|------|-----------|-------------|
| `normcode_list_specs` | `() -> list[dict]` | List all registered CortexSpecs (statutes) |
| `normcode_get_spec` | `(name: str) -> dict` | Get a specific statute's full definition |
| `normcode_lift_inference` | `(flow_index, concept_name, sequence_type[, coupling_signature, concept_json, spec_name]) -> dict` | Lift an NC inference into LC: returns EMLTree, certificate, logic_type, gate_results, spec_name |
| `normcode_ground_certificate` | `(cert_key: str) -> dict` | Ground a certificate back into NC: returns Decomposition + Decision |
| `normcode_list_certificates` | `() -> list[dict]` | List all cached certificates (run_id → CortexCertificate) |
| `normcode_verify_certificate` | `(cert_key: str) -> bool` | Verify a certificate's contraction path is valid |
| `normcode_bridge_state` | `() -> dict` | Current bridge state: registered trees, certificate count |
| `normcode_instantiate_writ` | `(spec_name: str, witness: dict) -> dict` | Issue a writ under a statute: returns Concept + CortexCertificate |
| `normcode_run_closure` | `(events: list) -> dict` | Run institutional closure on events: returns Event list + BlamePool |

### Orchestrator Tools (`normcode_orch_*`)

Wrap the `Orchestrator` lifecycle:

| Tool | Signature | Description |
|------|-----------|-------------|
| `normcode_orch_load_plan` | `(path: str[, spec_registry: str]) -> str` | Load `.ncd` plan file, build repos, return plan_id |
| `normcode_orch_load_text` | `(text: str[, spec_registry: str]) -> str` | Load inline NCD plan text, return plan_id |
| `normcode_orch_start` | `(plan_id: str) -> str` | Start plan execution, return run_id |
| `normcode_orch_step` | `(run_id: str) -> dict` | Execute one inference step, return state delta |
| `normcode_orch_run_to` | `(run_id: str, flow_index: str) -> dict` | Run until the given flow_index is reached |
| `normcode_orch_run_all` | `(run_id: str) -> dict` | Run the entire plan to completion |
| `normcode_orch_stop` | `(run_id: str) -> str` | Stop plan execution (graceful) |
| `normcode_orch_pause` | `(run_id: str) -> str` | Pause after current inference |
| `normcode_orch_get_state` | `(run_id: str) -> dict` | Full execution state: current_flow_index, status, cycle, waitlist, history |
| `normcode_orch_get_logs` | `(run_id: str[, limit: int, level: str]) -> list` | Inference execution logs |
| `normcode_orch_get_step_progress` | `(run_id: str) -> dict` | Current step progress (which inference, status, elapsed) |
| `normcode_orch_list_checkpoints` | `(plan_id: str) -> list` | List available checkpoints for a plan |
| `normcode_orch_resume` | `(run_id: str) -> str` | Resume from a checkpoint |
| `normcode_orch_fork` | `(run_id: str) -> str` | Fork a checkpoint into a new run |

---

## Lifecycle

### Server Start
```json
{
    "jsonrpc": "2.0",
    "method": "initialize",
    "params": {
        "protocolVersion": "2025-03-26",
        "capabilities": { "tools": {} }
    }
}
```

Server initializes:
1. `NormCodeCortexBridge(bound=1024)` — in-process bridge
2. `SpecRegistry(SEED_REGISTRY)` — loaded statute book
3. Empty `plan_store: Dict[str, Orchestrator]` — no plans loaded

### Plan Execution Lifecycle
```
load_plan(path) → plan_id
    │
start(plan_id) → run_id
    │
step(run_id) → delta        (or run_all / run_to)
    │                       
[repeat until completed]
    │
[checkpoint saved at each inference complete]
    │
resume(run_id) → continues from last checkpoint
```

### State Persistence
- **Plan definitions**: loaded from `.ncd` files, held in memory
- **Checkpoints**: persisted via `OrchestratorDB` (SQLite) at `{plan_id}.db`
- **Bridge state**: recomputable from cached checkpoints

---

## Coupling Signature → EMLTree Mapping

The formal flow→tree mapping uses these rules:

| Coupling Signature | Tree Shape | Rationale |
|---|---|---|
| `commutative-associative` | `rightComb(n)` | All bracketings equivalent; choose canonical Tamari minimum |
| `non-commutative` | `leftComb(n)` | Temporal order preserved — earlier to the left |
| `non-associative` | `balanced(n)` | Order of operations matters; minimize depth |
| `None` (unknown) | `rightComb(n)` | Default: assume associative |

Tree size `n` =
  `len(value_concepts)` (inputs)
  + `1` if `function_concept` is not `None` (operator)
  + `supporting_count` (sub-inferences that produce intermediate values)
  + `1` (output concept)

---

## Error Handling

All tools return structured errors:

```json
{
    "isError": true,
    "content": [{
        "type": "text",
        "text": "{\"error\": \"NormCodeParseError\", \"detail\": \"Line 42: undefined concept 'foo'\"}"
    }]
}
```

Error types:
- `NormCodeParseError` — invalid NCD syntax
- `BridgeError` — bridge invariant violation
- `OrchestratorError` — plan not loaded, already running, etc.
- `NotFoundError` — concept/spec/certificate not found

---

## Testing

```
# Unit: test parser tools with known .ncd files
pytest tests/test_mcp_normcode.py -k "parse"

# Unit: test cortex tools with bridge
pytest tests/test_mcp_normcode.py -k "cortex"

# Integration: load + run a small plan end-to-end
pytest tests/test_mcp_normcode.py -k "integration"

# Manual: start server, inspect with opencode
python scripts/mcp_normcode_server.py
```

---

## Future Milestones

### M1 — Event emission (post-MCP-async)
- Emit `plan/step` and `plan/complete` events via `tools/notification`
- Enable webhook-style plan monitoring

### M2 — Lean verification bridge
- `normcode_orch_verify_current` → lift tree → certify → invoke lean-lsp `verify`
- Returns `(certificate: CortexCertificate, verified: bool, proof_goal: str)`

### M3 — Spec authoring tools
- `normcode_spec_create`, `normcode_spec_edit`, `normcode_spec_delete`
- Enable dynamic statute book management from the agent

### M4 — Multi-user isolation
- User-scoped `plan_store` and `OrchestratorDB` instances
- Enables concurrent plan execution for different users

---

## Appendix: NCD Format Reference

(NCD = NormCode Document, the `.ncd` file format)

```
--- content of example.ncd
concept A: entity, B: entity, C: entity
relation f: A -> B
operator -> >
goal: C

path: f(B) -> B
	with f: A -> B
	given A
```

The NormCodeParser (canvas_app/backend/services/parsers/normcode.py) handles:
- `concept` declarations
- `relation` declarations  
- `operator` declarations
- `path` blocks (inference sequences)
- `with` / `given` dependency clauses
- `goal` declarations
- `try` / `or` branching
