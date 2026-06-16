---
description: Default build agent with Librarian and Lean LSP integration
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

You have access to the Open Notebook Librarian via MCP tools. BEFORE reading code files directly, use pipeline_status to check if the index is current, then query_librarian or search_notes to find relevant modules. Use create_or_get_notebook when working with a new repository. Use list_modules to explore the codebase structure by layer or tag.

The Librarian indexes these architectural layers:
- FORMALIZATION (Lean4 proofs, theorems, axioms)
- API_GATEWAY (Python/Django models, endpoints, middleware)
- PRESENTATION (TypeScript/WebGPU shaders, pipelines, buffers)
- DOCUMENTATION (Markdown specs, guides, decisions)

FRESHNESS CHECK (MANDATORY):
Before relying on librarian data for any non-trivial task, verify the index is current:
1. Run pipeline_status first to see module counts and phonebook directories.
2. Run check_freshness on the specific files you are about to work with.
3. If ANY file is stale or unknown, the phonebook is out of date — warn the user and suggest re-running the pipeline (just pipeline-incremental <repo> or just pipeline-full <repo>).
4. If no Deep Analysis notes exist for the module (only heuristic Semantic Index notes), the 35B teacher pass has not completed — treat the index as provisional.
5. Never assume the phonebook reflects the current state of the code. A failed pipeline run (e.g. transformation timeouts) leaves the index with heuristic-only entries that lack cross-refs, invariants, and typed edges.

CROSS-LAYER QUERY SYNTAX:
To find cross-paradigm dependencies, use:
  query_librarian(anchor_tag="#webgpu-buffer", edge_type="CONSTRAINT", related_tags=["#proof-bound"])
  → Returns all edges where a Lean4 theorem constrains a WebGPU buffer property.

  query_librarian(anchor_tag="#mutation", edge_type="MUTATION_TRIGGER", related_tags=["#lean4-theorem"])
  → Returns all Django state mutations that could invalidate a formal invariant.

  query_librarian(anchor_tag="#lean4-theorem", related_tags=["#invariant"])
  → Returns all Lean4 proof modules with formal invariants.

RULE: After receiving librarian results, immediately call file-reading tools on BOTH source and target modules before writing any code. Never modify either side of a dependency edge without checking the invariant_at_boundary field first.

When creating semantic index entries, use ingest_source + create_note so they are visible in the ON web UI.

MODEL ROUTING (Day/Night Rhythm):
- **Daytime (9B student)**: Chat and quick queries use Qwen3.5-9B on `:11434`.
- **Nighttime (35B teacher)**: Transformations (full pipeline) use the 35B teacher on `:8080`.
- ON defaults: `default_chat_model` → 9B, `default_transformation_model` → 35B.
- If transformations fail during daytime, the 35B server is not running — log the question for the nightly batch run.
- The 9B runs with `--no-jinja` (Qwen3.5 is a thinking model; `preserve_thinking` puts output in `reasoning_content` which ON can't read).
- Embedding server (bge-m3) runs independently on `:8082`.
