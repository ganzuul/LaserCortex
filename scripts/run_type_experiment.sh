#!/usr/bin/env bash
# ============================================================================
# run_type_experiment.sh — Tropical Type Theory → Graphiti Experiment Runner
#
# Usage:
#   ./scripts/run_type_experiment.sh                                  # episodes only → 2 communities
#   ./scripts/run_type_experiment.sh --triplets                        # + entity edges → more communities
#   ./scripts/run_type_experiment.sh --triplets --temporal-path 10     # + temporal chains
#   ./scripts/run_type_experiment.sh --keep-db --output results.json   # persistent + save
#   ./scripts/run_type_experiment.sh --help
#
# What changes the community count:
#   --triplets       Adds IS_ADJACENT_TO, AT_STATION, TRANSITIONS_VIA edges between types
#   --temporal-path  Adds ordered temporal chain episodes (v1→C→W→v2→v3→...)
#   --generators N   Scaffolding for r=4 (not yet — needs Lean algebra extension)
#
# What it does:
#   1. Encodes the type lattice (stations, types, adjacencies, applyMoves) into Graphiti
#   2. Optionally adds explicit entity-relation-entity edges (triplets)
#   3. Runs community detection on the entity graph
#   4. Reports the discovered communities and type structure
#
# The Graphiti database is ephemeral (temp file) by default. Use --keep-db
# to persist it for later inspection via the MCP server.
#
# Requires:
#   - python3 with graphiti-core and falkordblite
#   - lake (Lean 4) on PATH
#   - PYTHONPATH automatically includes LaserCortex project root
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/run_type_experiment.py"

# Check dependencies
if ! command -v lake &>/dev/null; then
    echo "ERROR: 'lake' not found on PATH. Is Lean 4 installed?"
    exit 1
fi

if ! python3 -c "import graphiti_core" 2>/dev/null; then
    echo "WARNING: graphiti_core not found in default Python."
    echo "  Trying project environment..."
    # If there's a venv or conda, we might need it here
fi

# Export PYTHONPATH so infra modules are importable
export PYTHONPATH="${PYTHONPATH:-}:$PROJECT_ROOT"

echo "═══ Tropical Type Theory Experiment ═══"
echo "  Project root: $PROJECT_ROOT"
echo "  Python:       $(which python3)"
echo "  lake:         $(which lake)"
echo "  Args:         $@"
echo ""

# Run the Python experiment script, passing all args through
python3 "$PYTHON_SCRIPT" "$@"

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "═══ Experiment complete ═══"
else
    echo ""
    echo "═══ Experiment FAILED (exit code $EXIT_CODE) ═══"
fi

exit $EXIT_CODE
