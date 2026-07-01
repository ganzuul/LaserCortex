# Advanced Tooling Plan: Lean4 Research OODA-Loop

## Overview

This document outlines the plan for advancing tool usage in Lean4 development, specifically creating an OODA-loop (Observe, Orient, Decide, Act) for the development process that includes a `/research ...` command. The goal is to complement the `lean_lsp` MCP tools with knowledge graph and research database capabilities, reducing reliance on lexical grepping of `.lean` files.

## Current State

### ✅ SearXNG MCP Server (Completed)
- **Status**: Running at `http://localhost:8090/`
- **MCP Package**: `mcp-searxng` installed via npm
- **Configuration**: Added to `/home/nos/.config/opencode/opencode.jsonc` with `SEARXNG_URL: "http://localhost:8090/"`
- **Purpose**: Metasearch across arXiv, MathOverflow, MathWorld, nLab, and academic databases
- **Tools Available**: `searxng_web_search`, `searxng_search_suggestions`, `searxng_instance_info`, `web_url_read`

### ✅ Lean-LSP Research Tools (Completed Testing)
- `lean-lsp_lean_loogle`: Search Mathlib by type signature - **Tested**: "Tropical" returned Mathlib.Algebra.Tropical.Basic results; "Tamari" returned no results
- `lean-lsp_lean_leansearch`: Natural language Mathlib search - **Tested**: "tropical geometry tropical hyperplane arrangement" returned Mathlib's Tropical algebra support; "Tamari lattice associahedron" returned associativity relations and lattices
- `lean-lsp_lean_leanfinder`: Semantic/conceptual search - **Tested**: "regular subdivisions of products of simplices..." returned standard simplices, regular simplices, and simplicial complexes; "Tamari lattice Hasse diagram polyhedral complex" returned simplicial sets, horns, and standard simplices
- `lean-lsp_lean_state_search`: Goal-specific lemma suggestions - **Available**
- `lean-lsp_lean_hammer_premise`: Premise suggestions for automation tactics - **Available**

### ❌ Open Notebook Librarian (Deferred)
- **Status**: Prototype, information is stale and untested
- **Role**: Should come in last to fill gaps after other tools are exhausted

### ✅ CodeGraph for Local Codebase Semantic Search (Completed)
- **Status**: Installed and tested
- **Tool**: `codegraph_explore` MCP tool
- **Features**: 100% local SQLite knowledge graph, auto-sync on code changes, 20+ languages supported, framework-aware routes
- **Capabilities**: Returns verbatim source code grouped by file, call paths among symbols, dynamic-dispatch hops, and blast-radius summary of what depends on them
- **Decision**: CodeGraph replaces the need to explore Mentat vs Khoj for local codebase semantic search

## OODA-Loop for Lean4 Development

### Stages

| Stage | Tools | Purpose |
|-------|-------|---------|
| **Observe** | `lean-lsp_lean_diagnostic_messages`, `lean-lsp_lean_goal` | Get compiler errors, proof goals, state |
| **Orient** | `lean_loogle`, `lean_leansearch`, `lean_leanfinder`, `lean_state_search`, `lean_hammer_premise`, SearXNG MCP | Find relevant lemmas, theorems, literature |
| **Decide** | Human + LLM reasoning | Choose the right lemma or approach |
| **Act** | `lean-lsp_lean_build`, file edits | Implement and verify |

### `/research ...` Command Workflow

```
/research <theorem_name_or_concept>
  ↓
1. Check local declarations: lean_local_search <query>
2. Search Mathlib by type: lean_loogle <type_pattern>
3. Search Mathlib by natural language: lean_leansearch <query>
4. Semantic search: lean_leanfinder <concept>
5. External research: SearXNG MCP "arXiv <theorem_name>" + "MathOverflow <theorem_name>" + "MathWorld <term>" + "nLab <theorem_name>"
6. Store findings in Open Notebook librarian (if available)
```

## Tool Exploration Plan - Progress Report

### ✅ Phase 1: Lean-LSP Research Tools Testing (Completed)

Used the invariants from `TropicalTamariLattice.lean` as the practical test case:

1. **Invariant 1 & 2**: Mathlib-provided instances for tropical lattices
   - `instLatticeTropical [Lattice R] : Lattice (Tropical R)`
   - `instConditionallyCompleteLatticeTropical [ConditionallyCompleteLattice R]`
   - **Result**: Mathlib has `Tropical R` type, `trop`, `untrop`, `trop_sum`, `Tropical.trop_add`, and `CommSemiring (Tropical R)` instances in `Mathlib.Algebra.Tropical.Basic`

2. **Invariant 3**: Tamari lattice Hasse diagram isomorphism
   - "Tamari lattice Hasse diagram isomorphic to the 1-skeleton of a polyhedral complex induced by tropical hyperplane arrangements"
   - **Result**: No Tamari lattice or associahedron formalized in Mathlib yet. `lean_loogle` for "Tamari" returned no results. `lean_leanfinder` returned results about simplicial sets, horns, and standard simplices.

3. **Invariant 4**: Develin-Sturmfels correspondence
   - "Regular subdivisions of △k × △m correspond dually to configurations of tropical hyperplanes (Develin–Sturmfels theorem)"
   - **Result**: No direct matches for Develin-Sturmfels theorem in Mathlib. `lean_leanfinder` returned results about standard simplices, regular simplices, and simplicial complexes.

### ✅ Phase 2: SearXNG MCP Integration Testing (Completed)

1. **Verified SearXNG MCP server is accessible via OpenCode**
2. **Tested SearXNG queries with relevant results**:
   - arXiv/PDFs: "Develin-Sturmfels tropical hyperplane regular subdivisions" - returned PDFs about tropical hyperplane arrangements and oriented matroids, regular subdivisions of products of simplices
   - MathOverflow: "Tamari lattice" - returned relevant MathOverflow questions about Tamari lattices
   - MathWorld: "surjection/epimorphism/valuation" - returned relevant MathWorld pages for these mathematical terms

### ✅ Phase 3: OODA-Loop Skill Creation (Completed)

Created the OODA-loop skill at `/home/nos/labware/LaserCortex/.skills/lean4-skills/plugins/lean4/skills/lean4/skills/ooda-loop/SKILL.md`:

- **Generic OODA-loop framework** with 4 phases (Observe, Orient, Decide, Act) + Feedback Loop
- **Project-specific Lean4 tooling references** for each phase
- **Decision tree for tool selection**:
  1. "Does X exist locally?" → `lean_local_search`
  2. "I need a lemma that says X" → `lean_leansearch`
  3. "Find lemma with type pattern" → `lean_loogle`
  4. "What's the Lean name for concept X?" → `lean_leanfinder`
  5. "What closes this goal?" → `lean_state_search`
  6. "What to feed simp?" → `lean_hammer_premise`
  7. "External research needed" → `searxng_web_search` (arXiv, MathOverflow, MathWorld, nLab/nCatLab)

### ✅ Phase 4: CodeGraph Integration (Completed)

CodeGraph has been tested and verified as the suitable tool for local codebase semantic search:

- **Tested**: `codegraph_explore` MCP tool successfully returned 23 symbols across 2 files with relationships, blast radius information, and verbatim source code
- **Features**: 100% local SQLite knowledge graph, auto-sync on code changes, 20+ languages supported, framework-aware routes
- **Capabilities**: Returns verbatim source code grouped by file, call paths among symbols, dynamic-dispatch hops, and blast-radius summary of what depends on them
- **Decision**: CodeGraph is the chosen tool for local codebase semantic search, replacing the need to explore Mentat vs Khoj

## Integration Plan - Progress Report

### ✅ Step 1: Keep it Minimal (Completed)
- Discovered usage information for the different tools
- Tested Lean-LSP research tools and SearXNG MCP server

### ✅ Step 2: OODA-Loop Skill Created (Completed)
- Created OODA-loop skill at `.skills/lean4-skills/plugins/lean4/skills/lean4/skills/ooda-loop/SKILL.md`
- Integrated usage information for the Lean-LSP research tools
- Documented the decision tree for tool selection

### ❌ Step 3: Open Notebook Librarian (Later - Deferred)
- Update the librarian index to be fresh
- Use it to complement information from other tools

## Test Case: TropicalTamariLattice Invariants

The invariants from `TropicalTamariLattice.lean` were used as the practical test case for the tools:

1. `instLatticeTropical [Lattice R] : Lattice (Tropical R)` — tropical inf/sup defined via `trop (untrop x ⊓ untrop y)` and `trop (untrop x ⊔ untrop y)`
2. `instConditionallyCompleteLatticeTropical [ConditionallyCompleteLattice R] : ConditionallyCompleteLattice (Tropical R)`
3. Tamari lattice Hasse diagram is isomorphic to the 1-skeleton of a polyhedral complex induced by tropical hyperplane arrangements
4. Regular subdivisions of △k × △m correspond dually to configurations of tropical hyperplanes (Develin–Sturmfels theorem)

**Note**: This was for testing the tools only, not for actually developing the Lean theorems while working on this advanced tooling plan.

## Remaining Next Steps

1. ❌ Update Open Notebook librarian index to be fresh (deferred until needed)
