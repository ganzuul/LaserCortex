# Lean Project Setup

## Installed Components

### 1. lean-lsp-mcp (MCP Server)
- **Purpose**: Provides LSP-based tools for interacting with Lean projects
- **Version**: 0.26.2
- **Installation**: Available via `uvx lean-lsp-mcp`
- **Configuration**: Already configured in `~/.vibe/config.toml`
  - Name: `lean-lsp`
  - Transport: `stdio`
  - Command: `uvx lean-lsp-mcp`
  - Project Path: `/home/nos/labware/LaserCortex`
  - Timeout: 600 seconds

### 2. lean4-skills
- **Purpose**: Lean 4 theorem proving skill and workflow pack for AI coding agents
- **Location**: `lean4-skills/` (cloned in project root)
- **Skill Path**: `.agents/skills/lean4/` (symlink for auto-discovery)

## Environment Variables

Added to `~/.bashrc`:

```bash
export LEAN4_PLUGIN_ROOT=/home/nos/labware/LaserCortex/lean4-skills/plugins/lean4
export LEAN4_SCRIPTS=$LEAN4_PLUGIN_ROOT/lib/scripts
export LEAN4_REFS=$LEAN4_PLUGIN_ROOT/skills/lean4/references
```

**To activate in current session:**
```bash
source ~/.bashrc
```

## Available Workflows

The lean4-skills provides these workflows (invoke via SKILL.md or `/lean4:*` commands):
- `draft` - Draft Lean declaration skeletons from informal claims
- `formalize` - Interactive formalization
- `autoformalize` - Autonomous end-to-end formalization
- `prove` - Guided cycle-by-cycle theorem proving
- `autoprove` - Autonomous multi-cycle proving
- `checkpoint` - Save point with build, axiom check, commit
- `review` - Read-only quality review
- `refactor` - Leverage mathlib, extract helpers
- `golf` - Improve proofs
- `learn` - Interactive teaching
- `doctor` - Diagnostics and migration help

## MCP Tools Available

Via lean-lsp-mcp:
- `lean_goal` - Get exact goal state at any line
- `lean_local_search` - Fast local + mathlib search (unlimited)
- `lean_leanfinder` - Semantic, goal-aware search
- `lean_leansearch` - Semantic search
- `lean_loogle` - Type-pattern search
- `lean_hammer_premise` - Premise suggestions
- `lean_multi_attempt` - Test multiple tactics
- `lean_diagnostic_messages` - Per-file error/warning check
- `lean_file_outline` - Get imports and declarations
- And more...

## Verification

Run these to verify setup:

```bash
# Check lean-lsp-mcp version
uvx lean-lsp-mcp --version

# Check environment variables
echo "LEAN4_PLUGIN_ROOT=$LEAN4_PLUGIN_ROOT"
echo "LEAN4_SCRIPTS=$LEAN4_SCRIPTS"
echo "LEAN4_REFS=$LEAN4_REFS"

# Verify scripts are accessible
ls "$LEAN4_SCRIPTS/sorry_analyzer.py"

# Build project
lake build
```

## Usage Notes

- The MCP server is already configured in your Mistral Vibe config
- Environment variables are set in `~/.bashrc` for your shell
- Skill auto-discovery is set up via `.agents/skills/lean4/`
- All scripts in `$LEAN4_SCRIPTS/` are executable
