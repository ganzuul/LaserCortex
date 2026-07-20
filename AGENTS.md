# Agent Working Agreement for LaserCortex

## Lean-First Principle

New features requiring formal semantics **must be formalized in Lean first**,
then mirrored to Python. This ensures:

1. The formal model is verified (no runtime surprises)
2. Python implementation has a provable specification
3. Cross-layer integration (Lean ↔ Python ↔ TypeScript) is grounded in a
   single source of truth

**Exception**: Quick scripts, test data, and UI scaffolding may be written in
Python/TypeScript first when the purpose is exploratory.

## Available Skills

The following skills are available and should be used when appropriate:

### `lean4` Skill
**Use when**: Editing `.lean` files, debugging Lean 4 builds (type mismatch, sorry, failed to synthesize instance, axiom warnings, lake build errors), searching mathlib for lemmas, formalizing mathematics in Lean, or learning Lean 4 concepts. Also trigger when the user asks for help with Lean 4, mathlib, or lakefile. Do NOT trigger for Coq/Rocq, Agda, Isabelle, HOL4, Mizar, Idris, Megalodon, or other non-Lean theorem provers.

**Key principles**:
- Search before prove: Many mathematical facts already exist in mathlib
- Build incrementally: Lean's type checker is your test suite
- Respect scope: Follow the user's preference for filling sorries
- Use 100-character line width for Lean files
- Never change statements or add axioms without explicit permission

### `ooda-loop` Skill
read: .agents/skills/lean4/skills/ooda-loop/SKILL.md
**Use when**: Complex decisions, problem-solving, unclear situations, or when jumping to solutions without analysis. Use for Lean4 development, research, and tool integration.

**Framework**: Observe, Orient, Decide, Act (OODA loop) with project-specific tooling references for Lean4 development.

### Lean MCP Server Usage Pattern (Primary Workflow)

The core guideline is to use the `lean-lsp` MCP server to get compiler messages for 
lightweight and high-frequency guidance and to iterate in small steps on .lean 
files. **Always use the MCP server tools first** for Lean development:

### Primary MCP Server Tools for Lean Development:

1. **`lean-lsp_lean_diagnostic_messages`** - Get compiler errors/warnings for a specific .lean file without a full build. This is the primary tool for lightweight, high-frequency guidance.

2. **`lean-lsp_lean_build`** - Run `lake build` + restart LSP. Use only when needed (new imports, new declarations, or when the LSP state is out of sync). This is faster and more accurate than `lake-wrap.sh` or raw `lake build` commands.

3. **`lean-lsp_lean_goal`** - Get proof goals at a position. MOST IMPORTANT tool for proof development.

4. **`lean-lsp_lean_hover_info`** - Get type signature and docs for a symbol.

5. **`lean-lsp_lean_completions`** - Get IDE autocompletions on incomplete code.

### Iterative Workflow Example:

1. **Step 1**: Edit a .lean file
2. **Step 2**: Run `lean-lsp_lean_diagnostic_messages` to check for per-file errors
3. **Step 3**: If errors, fix them and repeat Step 2
4. **Step 4**: When the file compiles successfully, run `lean-lsp_lean_build` to update the LSP state and build dependencies

### Avoid False Errors:

- If you see "unterminated comment" errors at line numbers that don't exist in the file, this is likely a false error from `lake-wrap.sh` or raw `lake build`. Use `lean-lsp_lean_diagnostic_messages` or `lean-lsp_lean_build` instead.
- Never use `lake-wrap.sh` or raw `lake build` commands for per-file error checking - use the MCP tools instead. 

## Resource Safety (also see SAFETY.md)

The system operates on limited hardware (24 GB RAM, 8 GB VRAM). All processes
must be contained (memory caps, watchdogs). The SAFETY.md file at repo root
documents specific containment protocols.

## Graphiti Memory (Persistent Knowledge Graph)

**⚠ Open Notebook Librarian is deprecated.** Use Graphiti Memory instead for all
persistent agent knowledge (decisions, architecture, preferences, patterns).

The `opencode-graphiti` plugin gives agents persistent memory backed by the
Graphiti temporal knowledge graph. It uses a local MCP server and the local
35B for embeddings + LLM (no external API keys needed).

### Plugin Setup

The plugin is symlinked at `~/.config/opencode/plugins/opencode-graphiti.ts`
and auto-discovered by opencode — no `"plugin"` entry in `opencode.jsonc`
required.  Config lives at `~/.config/opencode/graphiti.jsonc`.

### Graphiti MCP Server

The server runs on this machine at `http://localhost:8001/mcp` via Docker
(FalkorDB backend, llama.cpp profile — uses the local 35B for embeddings).
Managed by `~/labware/opencode-graphiti/scripts/graphiti-server.sh`.

**Caveat:** The endpoint is `http://localhost:8001/mcp` (no trailing slash).
A trailing slash triggers a 307 redirect.  The `Accept` header must include
both `application/json` and `text/event-stream` (SSE format).  Session
initialisation requires a two-step handshake (`initialize` → get
`mcp-session-id` from HTTP headers → `notifications/initialized`).

### Available Tool

The plugin registers a single `graphiti` tool with these modes:

| Mode | Purpose | Key args |
|------|---------|----------|
| `add` | Store a memory — queues episode for LLM entity extraction | `content`, `type`, `scope` (user/project), `source` (text/json/message) |
| `search` | Semantic + graph search across memories | `query`, `scope`, `limit`, `centerNodeId` |
| `list` | Recent episodes | `scope`, `limit` |
| `profile` | User preferences (cross-project) | `query` |
| `forget` | Remove a memory | `memoryId` |
| `graph` | Explore entity relationships | `centerNodeId`, `query`, `scope` |
| `status` | Server health | — |

### Source formats (`add` mode)

| Source | When to use | Behavior |
|--------|-------------|----------|
| `text` | Plain conversation or notes | LLM extracts entities + relationships from free text |
| `json` | Structured data (config, specs) | Parsed as JSON; entities extracted from structure |
| `message` | Chat/conversation content | Optimized for dialogue-style content |

### Entity types (auto-extracted on `add`)

The LLM extracts these entity types from episode content:

| Type | Priority | What it captures |
|------|----------|-----------------|
| `Preference` | **Highest** | User wants, likes, dislikes, choices, opinions ("I want X", "skip Y") |
| `Requirement` | High | Specific needs, features, functionality ("we need X", "X must have Y") |
| `Procedure` | High | Sequential instructions, conditional steps ("first do X, then Y") |
| `Organization` | Normal | Companies, institutions, groups, formal entities |
| `Document` | Normal | Books, articles, reports, emails, videos |
| `Event` | Normal | Meetings, deadlines, planned or unplanned occurrences |
| `Location` | Normal | Physical or virtual places |
| `Topic` | **Last resort** | Subject of conversation or knowledge domain |
| `Object` | **Last resort** | Physical items, tools, devices |

### Memory Scopes

| Scope | group_id | Persistence | Use for |
|-------|----------|-------------|---------|
| `user` | `opencode-user-<uuid>` | Cross-project | Personal preferences, coding style |
| `project` | `opencode-project-<repo-path>` | This repo | Build commands, architecture decisions, conventions |

### Memory Types

- `project-config` — build flags, test commands, tool preferences
- `architecture` — design decisions, module structure, cross-ref patterns
- `error-solution` — known errors and how to fix them
- `preference` — user's stated preferences (scope: user)
- `learned-pattern` — reusable patterns discovered during development
- `conversation` — session summaries (auto-saved by compaction hook)

### Automatic Behaviour

1. **First message in a session**: Plugin fetches user profile + relevant
   project memories and prepends them as context (synthetic text part).
2. **"Remember" keywords**: When the user says "remember", "save this",
   "keep in mind", etc., the agent is nudged to call `graphiti(mode: "add")`.
3. **Session compaction**: Before context window limits, the plugin saves a
   summary of the session as a `conversation` memory.

### Manual Usage Examples

```
graphiti(mode: "add", content: "lake build runs 194 jobs", type: "project-config", scope: "project")
graphiti(mode: "search", query: "decisions about DescentInterval")
graphiti(mode: "list", scope: "project", limit: 20)
graphiti(mode: "forget", memoryId: "uuid-here")
graphiti(mode: "graph", centerNodeId: "<uuid>", query: "related patterns")
graphiti(mode: "profile", query: "testing preferences")
graphiti(mode: "status")
graphiti(mode: "help")
```

### Migration from Open Notebook Librarian

If you previously used `pipeline_status`, `check_freshness`, `query_librarian`,
or related ON tools, migrate to Graphiti Memory:
- File-level freshness checks → Not needed; code search via codegraph or grep
- Cross-layer dependency queries → `graphiti(mode: "search", query: "...")`
- Semantic code index → CodeGraph (`.codegraph/`) covers source; Graphiti
  covers conversation/decision knowledge

## Lake Build Safety (Context Budget)

`lake build` and `lake setup-file` can emit tens of thousands of lines of
output, burning the LLM context budget on both the input and output side.
**Never pipe `lake build` output directly into the conversation.**

**Preferred approach**: Use the `lean-lsp_lean_build` MCP tool to build the project
and restart LSP. This is faster and more accurate than `lake-wrap.sh` or raw
`lake build` commands, and it provides per-file error checking via
`lean-lsp_lean_diagnostic_messages`.

Alternatively, `scripts/lake-wrap.sh` can be used for custom truncation or
explicit logging:

    scripts/lake-wrap.sh --head 5 --tail 15 -- lake build LaserCortex.Hopf

## User guidance
I would like you to think through in plain English what it is that the Lean code actually means. It is not just abstract nonsense but has grounding in the real world and therefore it has solutions grounded in the real world. You can get a great deal of help from working through the problem in English and then reducing the natural language to mathematical insight.
