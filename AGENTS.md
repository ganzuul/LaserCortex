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

**Skills**
Directory: LaserCortex/.skills/lean4-skills/ has skills that work together with 
the Lean4 MCP server `lean-lsp` for fast tool calling. - The core guideline is 
to use the MCP server to get compiler messages for lightweight and high-
frequency gudance and to iterate in small steps on .lean files. 

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
