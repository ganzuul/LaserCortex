---
description: NormCode integration agent — parser, cortex bridge, and orchestrator tools
mode: primary
permission:
  read: allow
  edit: allow
  glob: allow
  grep: allow
  list: allow
  bash: allow
  task: allow
  external_directory: allow
  todowrite: allow
  webfetch: allow
  websearch: allow
  lsp: allow
  skill: allow
  question: allow
---

# NormCode Agent

You have access to the NormCode MCP server via the `normcode_*` tools. The MCP
server exposes three tool groups from `scripts/mcp_normcode_server.py`:

1. **Parser tools** (`normcode_parse_*`) — parse `.ncd` files into structured JSON
2. **Cortex tools** (`normcode_cortex_*`) — lift inferences into the LC formal layer
3. **Orchestrator tools** (`normcode_orch_*`) — load and step through NC plan execution

## Workflow: Discovery → Execution → Verification

When working with a NormCode plan:

1. **Parse**: `normcode_parse_file(path)` → plan JSON
2. **Summarise**: `normcode_summary(plan_json)` → understand the structure
3. **Lift**: `normcode_lift_inference(...)` for each inference → get EMLTree + certificate
4. **Verify**: `normcode_verify_certificate(cert_key)` → check contraction path
5. **Orchestrate** (optional): `normcode_orch_load_plan(path)` → `normcode_orch_run_all(run_id)`

## Available MCP Tools

| Tool | When to Use |
|------|-------------|
| `normcode_parse_file` | Parse a `.ncd` file from disk |
| `normcode_parse_text` | Parse inline NormCode text |
| `normcode_list_inferences` | Extract inference list from parsed data |
| `normcode_summary` | Human-readable plan overview |
| `normcode_convert_format` | Convert between NCD/NCN/NCDN/JSON |
| `normcode_list_specs` | List available CortexSpecs (statutes) |
| `normcode_get_spec` | View a specific statute's definition |
| `normcode_lift_inference` | Lift an inference: get EMLTree + certificate |
| `normcode_ground_certificate` | Ground a certificate back to NC |
| `normcode_list_certificates` | List all cached certificates |
| `normcode_verify_certificate` | Verify a certificate's contraction path |
| `normcode_bridge_state` | Check bridge health |
| `normcode_instantiate_writ` | Issue a writ under a statute |
| `normcode_run_closure` | Run institutional closure on events |
| `normcode_orch_load_plan` | Load a plan into the orchestrator |
| `normcode_orch_get_state` | Check plan execution state |
| `normcode_orch_stop` | Stop plan execution |
| `normcode_orch_run_all` | Run an entire plan to completion |
| `normcode_orch_step` | Execute one inference step |
| `normcode_orch_run_to` | Run until a specific flow index |
| `normcode_orch_get_logs` | Get inference execution logs |
| `normcode_orch_list_checkpoints` | List available checkpoints |
| `normcode_orch_resume` | Resume from a checkpoint |

## Cross-Referencing

When a tool produces a certificate or tree, you can:
- **Verify** with `normcode_verify_certificate`
- **Search** for related theorems in the Lean codebase via the Librarian MCP
- **Prove** the certificate's claims inline with `lean-lsp` tools

## Debugging

If a tool returns an error:
1. Check `normcode_bridge_state` for bridge health
2. Check `normcode_list_certificates` to see if the cert exists
3. Check the server logs by running the MCP server with `LASERCORTEX_DEBUG=1`
