#!/usr/bin/env bash
# ==============================================================================
# lake-wrap.sh — Wrap `lake` (or any command) with log truncation.
#
# Motivation:
#   `lake build` and `lake setup-file` can emit tens of thousands of lines
#   of output.  Piping this directly into the LLM context burns the budget
#   on both sides (output AND input).  This wrapper captures the full log
#   to a file and prints only the first N lines, a suppression marker, and
#   the last M lines.
#
# Usage:
#   ./scripts/lake-wrap.sh [--head 10] [--tail 10] [--log /tmp/foo.log] -- <command> [args...]
#
#   Or, more commonly:
#   ./scripts/lake-wrap.sh lake build
#   ./scripts/lake-wrap.sh --head 5 --tail 15 -- lake build LaserCortex.Hopf
#
#   All arguments before the first '--' are passed to log-truncate.py.
#   Everything after '--' (or everything if no '--' is present) is the
#   command to run.
#
# Exit code:
#   Propagates the exit code of the wrapped command, so && chains work.
#
# Examples:
#   ./scripts/lake-wrap.sh lake build
#   ./scripts/lake-wrap.sh --tail 20 -- lake build LaserCortex.Hopf 2>&1
#   ./scripts/lake-wrap.sh --log /tmp/mybuild.log -- lake build 2>&1
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRUNCATE="$SCRIPT_DIR/log-truncate.py"

# --- Parse truncation options before '--' ------------------------------------
TRUNC_ARGS=()
CMD_ARGS=()
got_double_dash=false

for arg in "$@"; do
    if $got_double_dash; then
        CMD_ARGS+=("$arg")
    elif [ "$arg" = "--" ]; then
        got_double_dash=true
    else
        TRUNC_ARGS+=("$arg")
    fi
done

# If no '--' was given, treat ALL args as the command
if ! $got_double_dash; then
    CMD_ARGS=("${TRUNC_ARGS[@]}")
    TRUNC_ARGS=()
fi

# --- Run the command, piping through log-truncate.py -------------------------
if [ ${#CMD_ARGS[@]} -eq 0 ]; then
    echo "Usage: $0 [--head N] [--tail N] [--log FILE] [--] <command> [args...]"
    exit 1
fi

# We need to capture exit code while piping.  Use a temp file for the exit code.
EXIT_CODE_FILE="$(mktemp)"
cleanup() {
    rm -f "$EXIT_CODE_FILE"
}
trap cleanup EXIT

(
    set +e
    "${CMD_ARGS[@]}"
    echo "$?" > "$EXIT_CODE_FILE"
) 2>&1 | python3 "$TRUNCATE" "${TRUNC_ARGS[@]}"

read -r EXIT_CODE < "$EXIT_CODE_FILE" 2>/dev/null || EXIT_CODE=1
exit "$EXIT_CODE"
