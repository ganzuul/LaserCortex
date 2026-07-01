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
**Use when**: Complex decisions, problem-solving, unclear situations, or when jumping to solutions without analysis. Use for Lean4 development, research, and tool integration.

**Framework**: Observe, Orient, Decide, Act (OODA loop) with project-specific tooling references for Lean4 development.

### `normcode` Skill
**Use when**: Working with NormCode (.ncd) plan files, the NormCode parser, cortex bridge lift/ground operations, or plan orchestration. Also trigger when the user asks to parse, lift, verify, or run NormCode plans, or when working with EMLTrees, certificates, or the inference pipeline. Do NOT trigger for generic Python debugging, Lean4 proving, or WebGPU work.

## Lean MCP Server Usage Pattern (Primary Workflow)

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

## LaserCortex architecture: Generation / Collapse Duality

- **Generation is primitive** — the WFC (Wave Function Collapse) engine is
  fundamentally generative. It produces candidate structures from a
  superposition of LogicTypes.
- **Collapse is failed re-generation** — what we call a "zero divisor" or
  "contradiction" is what happens when a generated structure is critiqued and
  the reasoning budget is exceeded. Collapse is critique, not the primary mode.
- **Hyperstition** — "A sophisticated enough lie is indistinguishable from
  truth." The generation mode can produce propositions that don't yet hold but
  *should* hold (fiction that makes itself real). This is how the framework
  avoids reductionism.

## Resource Safety (also see SAFETY.md)

The system operates on limited hardware (24 GB RAM, 8 GB VRAM). All processes
must be contained (memory caps, watchdogs). The SAFETY.md file at repo root
documents specific containment protocols.

## Pipeline Index

The Open Notebook MCP librarian indexes four architectural layers:
- `FORMALIZATION` — Lean4 proofs, theorems, axioms
- `API_GATEWAY` — Python/Django models, endpoints, middleware
- `PRESENTATION` — TypeScript/WebGPU shaders, pipelines, buffers
- `DOCUMENTATION` — Markdown specs, guides, decisions

Before modifying any file, verify the librarian index is fresh via
`pipeline_status` + `check_freshness`. If the index is stale, warn the user.

## Lake Build Safety (Context Budget)

`lake build` and `lake setup-file` can emit tens of thousands of lines of
output, burning the LLM context budget on both the input and output side.
**Never pipe `lake build` output directly into the conversation.**

**Preferred approach**: Use the `lean-lsp_lean_build` MCP tool to build the project
and restart LSP. This is faster and more accurate than `lake-wrap.sh` or raw
`lake build` commands, and it provides per-file error checking via
`lean-lsp_lean_diagnostic_messages`.

**Legacy approach** (if you must use `lake build` directly):

Use `scripts/lake-wrap.sh` instead:

    # Basic usage (head=10, tail=10, auto-generated log in /tmp):
    ./scripts/lake-wrap.sh lake build

    # Build a specific target with custom truncation:
    ./scripts/lake-wrap.sh --head 5 --tail 15 -- lake build LaserCortex.Hopf

    # With an explicit log path:
    ./scripts/lake-wrap.sh --log /tmp/hopf.log -- lake build LaserCortex.Hopf

The wrapper:
1. Captures the **full output** to a timestamped log file in `/tmp`
2. Prints only the first N lines, a suppression marker, and the last M lines
3. Exits with the same exit code as `lake` (so `&&` chains work)

If you need to investigate a specific error, read the log file with
targeted tools (grep, read offset/limit) rather than re-running the build.

The underlying filter is `scripts/log-truncate.py`, which can also be used
standalone:

    noisy-command 2>&1 | python3 scripts/log-truncate.py --head 10 --tail 10
