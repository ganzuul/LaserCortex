# Session: NormCode MCP Integration

**Session ID:** ses_normcode_20260622
**Created:** 6/22/2026
**Status:** Phases A–D complete, pushed to `main`

---

## Summary

Built NormCode MCP server and integrated it into the LaserCortex ecosystem. Fixed the flow→tree formal mapping, created 18 MCP tools across 3 groups, registered the server in opencode.json, created a routing agent and skill, and wrote documentation.

---

## Phase A: Fix flow→tree mapping (DONE)

**Files changed:**
- `infra/_cortex/_eml_tree.py` — added `balanced_tree()`, `tree_from_inference_entry()` with formal coupling signature → EMLTree shape mapping
- `infra/_cortex/_bridge.py` — updated `lift_inference` to accept optional `eml_tree` param; `on_inference_complete` accepts inference structure data
- `infra/_orchest/_orchestrator.py` — passes `value_concept_count`, `has_function_concept`, `supporting_count`, `coupling_signature` to `on_inference_complete`

**Key design decision:** `tree_from_inference_entry()` replaces `tree_from_flow_index()`. The coupling signature determines the EMLTree shape:
| Signature | Shape |
|-----------|-------|
| `commutative-associative` | `rightComb` (canonical) |
| `commutative` | `rightComb` |
| `non-commutative` | `leftComb` |
| `non-associative` | `balanced` |

Tree size = `value_concept_count + (1 if has_function_concept else 0) + supporting_count`.

**Tests:** All 5 inference marker tests pass (`simple`, `grouping`, `quantifying`, `looping`, `timing`). `paraconsistent` and `ampliative` return correct signatures (`commutative`, `non-associative`). `closure` returns `commutative-associative`.

**Known gaps:** `self_reference` has no coupling signature entry (returns empty); `closure` inference logic not yet implemented in the runner.

---

## Phase B: Build NormCode MCP server (DONE)

**New file:** `scripts/mcp_normcode_server.py` — 367 lines, FastMCP with stdio transport

**18 tools in 3 groups:**

**Parser Group (5 tools):**
| Tool | Function |
|------|----------|
| `normcode_parse_file` | Parse `.ncd` file → `PlanParseResult` |
| `normcode_parse_text` | Parse raw text → `PlanParseResult` |
| `normcode_list_inferences` | List all inference lines from parsed plan |
| `normcode_get_sequence_type` | Classify inference by marker |
| `normcode_spec_lookup` | Look up CortexSpec by statute name |

**Cortex Group (6 tools):**
| Tool | Function |
|------|----------|
| `normcode_lift_inference` | Lift inference → `CortexContext` + `CertificateInfo` |
| `normcode_ground_certificate` | Ground certificate → `GroundingResult` |
| `normcode_stamp_seal` | Create wax seal (certificate) |
| `normcode_verify_certificate` | Check certificate against statutes |
| `normcode_get_registry_summary` | Stats from TypeRegistry |
| `normcode_list_certificates` | List all certificates in registry |

**Orchestrator Group (7 tools):**
| Tool | Function |
|------|----------|
| `normcode_orch_load_plan` | Load parsed plan into Orchestrator |
| `normcode_orch_get_state` | Get orchestrator state machine status |
| `normcode_orch_run_all` | Execute all inferences in sequence |
| `normcode_orch_run_one` | Execute single inference by flow_index |
| `normcode_orch_stop` | Stop execution |
| `normcode_orch_status` | Get stats, progress, logs |
| `normcode_orch_debug` | Get debug trace |

**Architecture:**
- Direct Python imports from `infra/*` — no subprocess calls
- `logging` module for tool-level and request-level tracing (stderr)
- 30s default timeout
- FastMCP `context` (not `ctx`) for lifespan
- Returns JSON-serializable dicts

**LSP warnings (pre-existing, non-blocking):**
- Type narrowing issues in `_eml_tree.py` (Optional[EMLTree] access)
- `_cost.py` Optional argument issues
- TypeScript errors in frontend (unrelated)

**Tests performed:**
- Server starts and registers all 18 tools ✓
- `normcode_parse_file` with sample `.ncd` ✓
- `normcode_lift_inference` produces valid EMLTree + certificate ✓
- `normcode_spec_lookup` resolves 4/4 seed statutes ✓

**Not tested:** orchestrator tools (`normcode_orch_load_plan`, `normcode_orch_run_all`, `normcode_orch_stop`) — have minimal implementation, likely need refinement.

---

## Phase C: Register in opencode + create agent (DONE)

**`opencode.json`:** Added `mcp.normcode` with (corrected to 1.17.9 binary schema):
```json
{
  "mcp": {
    "normcode": {
      "type": "local",
      "command": ["python3", "scripts/mcp_normcode_server.py"]
    }
  }
}
```

> **Schema note (post-fix):** OpenCode 1.17.9's binary defines `mcp` as
> `Z.Record(Z.String, Z.Union([McpLocalConfig, McpRemoteConfig, {enabled: Boolean}]))` —
> each key directly under `mcp` is a server name. There is **no `servers` wrapper**.
> The original config nested under `mcp.servers.normcode`, which the validator rejected
> (`Expected "local" | "remote"`, then `Missing key mcp.servers.enabled`). Fix: flatten
> to `mcp.normcode`, keep `type: "local"` (required discriminator), merge `command`+`args`
> into a single `command` array. The published docs were stale — the binary schema is
> authoritative.

**`.opencode/agents/normcode.md`:** Routing agent that dispatches to MCP tools based on user intent (parse/lift/ground/verify/orchestrate).

**`.agents/skills/normcode/SKILL.md`:** Usage reference with MCP tool signatures, NCD syntax, sequence types, coupling signatures, CortexSpec registry.

---

## Phase D: Documentation (DONE)

**`docs/normcode_integration.md`:** Multi-session integration plan:
- Session 1 (DONE): MCP server + agent/skill
- Session 2: Closure pipeline (implement closure inference)
- Session 3: TUI client (rich/Textual REPL)
- Session 4: Full verification loop (client → server → Lean → bridge)
- Session 5: Deployment (docker, health, monitoring)

**`docs/normcode_mcp_spec.md`:** Full specification with tool signatures, examples, coupling map table, Future Milestones.

---

## Git

Committed as `8c9d978`: "Phase A-D: NormCode MCP integration — flow→tree mapping, MCP server, agent/skill, docs"
8 files changed, 1496 insertions(+), 6 deletions(-)
Pushed to `origin/main`.

> **Post-commit correction:** Commit `8c9d978` shipped a **stale** `opencode.json`
> MCP schema (`mcp.servers.normcode` with separate `command`+`args`). OpenCode 1.17.9's
> binary schema has no `servers` wrapper — keys directly under `mcp` are server names,
> `type: "local"` is a required discriminator, and `command` is a single merged array.
> The published docs were stale; the binary proved authoritative. Fix applied and
> committed as `fdc7208`: "fix(opencode): correct MCP schema to 1.17.9 binary spec".
> Pushed to `origin/main`. Verified working by user.

---

## Open Issues / Next Steps

1. **`opencode.json` schema fix committed** — `fdc7208` corrects the 1.17.9 schema (`mcp.normcode`, `type: "local"`, merged `command`). Resolved.
2. **`.agents/skills/normcode/SKILL.md`** — created but gitignored (`.agents/` in `.gitignore`). The `.opencode/agents/normcode.md` agent is tracked.
2. **Orchestrator tools** — `orch_load_plan` creates Orchestrator but doesn't build ConceptRepo from parsed data. Needs Phase B refinement.
3. **MCP server LSP warnings** — all pre-existing type issues; none affect runtime.
4. **`scripts/manage_normcode.sh`** — lifecycle wrapper not yet created (deferred).
5. **`closure` inference** — coupling signature defined, but inference logic not implemented in the runner.
6. **`self_reference` sequence type** — has no coupling signature entry in the mapping table.
