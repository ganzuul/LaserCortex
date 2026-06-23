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

## Generation / Collapse Duality

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

The Open Notebook librarian indexes four architectural layers:
- `FORMALIZATION` — Lean4 proofs, theorems, axioms
- `API_GATEWAY` — Python/Django models, endpoints, middleware
- `PRESENTATION` — TypeScript/WebGPU shaders, pipelines, buffers
- `DOCUMENTATION` — Markdown specs, guides, decisions

Before modifying any file, verify the librarian index is fresh via
`pipeline_status` + `check_freshness`. If the index is stale, warn the user.
