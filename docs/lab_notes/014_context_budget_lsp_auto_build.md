# Context Budget Violation: LSP Auto-Build on File Edit

**Date:** 2026-06-28
**Severity:** Non-trivial — likely consumed hours of context budget across multiple sessions
**Tags:** `#safety-violation` `#context-budget` `#lsp` `#lean` `#opencode-config`

## Observed Behavior

Every `.lean` file edit via the `edit` tool triggered `lake serve` (the Lean Language
Server), which ran `lake setup-file`, producing **thousands of lines of build output**
piped directly into the conversation context. This built ~2984 dependencies on first
trigger, each line consuming tokens from the context budget.

Symptoms:
- Context compaction running every few messages during Lean editing sessions
- Build diagnostics dwarfing actual content in the chat window
- Working memory constantly being evicted by irrelevant build progress lines
- The `lake-wrap.sh` script (created to solve this exact problem) was completely
  bypassed — the auto-LSP used `lake serve` directly, not the wrappper

## Root Cause

The opencode user config (`~/.config/opencode/opencode.jsonc`) contained:

```jsonc
"lsp": {
  "lean": {
    "command": ["lake", "serve"],
    "extensions": [".lean"]
  }
}
```

This tells opencode to launch `lake serve` as the LSP server for every `.lean` file.
When a file is edited, opencode fetches diagnostics from the LSP, which triggers
`lake setup-file` — the Lean build system. The full build output is returned as
diagnostics text.

**Causal chain:**
```
edit .lean file → opencode fetches LSP diagnostics → lake serve → lake setup-file → full build log → diagnostics returned as text → context budget consumed
```

The `lean-lsp` MCP server (`uvx lean-lsp-mcp`) already provides all necessary Lean
tooling (goal states, hover info, diagnostics, etc.) and manages its own LSP
connection. The `lsp.lean` section in opencode was redundant — it launched a
*second* LSP server, with the harmful side effect of dumping build output into
every edit.

## Estimated Impact

Likely **hours of cumulative context budget** lost across sessions. Each `lake
setup-file` invocation produces ~2000–3000 lines of build output. If this fired
on every Lean file edit (which it did), and there were ~50–100 Lean edits across
the sessions:

- Low estimate: 50 edits × 500 lines avg = 25,000 lines of garbage tokens
- High estimate: 100 edits × 2000 lines avg = 200,000 lines consumed

This is a **structural context-budget leak** — the kind of thing that makes the
system appear to have "dementia" (failing to remember things it just discussed)
when in reality the budget was silently consumed by build diagnostics.

## Fix Applied

**Removed** the `lsp` section entirely from `~/.config/opencode/opencode.jsonc`.

Before (lines 48–53):
```jsonc
"lsp": {
  "lean": {
    "command": ["lake", "serve"],
    "extensions": [".lean"]
  }
}
```

After: section removed. The `lean-lsp` MCP server continues to provide all Lean
tooling via `uvx lean-lsp-mcp`.

**Verification:** After removal, the following MCP tools still function:
- `lean_local_search` — finds `SplitOctonion` and its declarations
- `lean_hover_info` — returns type signatures and doc comments
- `lean_file_outline` — returns file structure with all 44 declarations

The `lake-wrap.sh` wrapper (documented in `AGENTS.md`) should be used for
explicit `lake build` calls. Build output is now fully opt-in rather than
auto-triggered on every edit.

## Deeper Issue: LSP Configuration Hygiene

The root cause is a config layering problem:

| Scope | File | Contains |
|-------|------|----------|
| **User-level** | `~/.config/opencode/opencode.jsonc` | Provider, MCP, LSP config |
| **Project-level** | `LaserCortex/opencode.json` | Only normcode MCP server |
| **Plugin-level** | `~/.config/opencode/opencode/opencode.jsonc` | Empty override |

The user-level config had a `lsp.lean` section that was:
1. **Redundant** — the `lean-lsp` MCP server already provides Lean LSP integration
2. **Harmful** — triggered full project build on every file edit
3. **Silent** — no indication that build output was being piped into conversation

The project-level config (which should have the most specific settings for Lean
work) did not override or disable this behavior.

## Recommendations

1. **Audit `lsp` sections across all config scopes** — check if any other
   language servers are redundantly configured and dumping output.

2. **Add a `.opencode/` project-level config** that explicitly sets LSP policy
   for `.lean` files, rather than inheriting from user-level. This makes the
   project self-documenting about its LSP setup.

3. **If LSP reconnection is needed**, use a wrapped command that filters build
   output — e.g., a script that launches `lake serve` but redirects stderr
   through the `log-truncate.py` filter. However, this is risky because LSP
   protocol is sensitive to output format. The safe approach is to rely on the
   `lean-lsp` MCP server alone.

4. **Log context budget events** — when context compaction triggers, log what
   consumed the budget (tool outputs, diagnostics, file reads). This would have
   surfaced the build-output leak immediately.

## Lessons

1. Any long-running feedback loop triggered by file edits should be assumed to
   consume context budget until proven otherwise. Check it explicitly.

2. Redundant service configuration is worse than no configuration — silent
   resource leaks are harder to detect than missing features.

3. The `lean-lsp` MCP server is the correct interface for Lean tooling. The
   opencode `lsp` section should only be used when the MCP server does not
   provide the required LSP functionality (which is rare for `lean-lsp-mcp`).

4. When creating wrapper scripts like `lake-wrap.sh`, also audit the
   surrounding infrastructure — the wrapper only helps if ALL paths to the
   wrapped command go through it.
