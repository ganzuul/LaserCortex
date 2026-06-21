#!/usr/bin/env bash
# run_pipeline_bg.sh — Run remaining pipeline work as a proper Unix background job.
#
# Usage:
#   ./scripts/run_pipeline_bg.sh              # start background job
#   ./scripts/run_pipeline_bg.sh status       # check if running
#   ./scripts/run_pipeline_bg.sh logs         # tail recent output
#   ./scripts/run_pipeline_bg.sh kill         # stop gracefully

set -euo pipefail

REPO_DIR="/home/nos/labware/LaserCortex"
ON_DIR="/home/nos/labware/open-notebook"
PIDFILE="/tmp/lasercortex-pipeline.pid"
LOGFILE="/tmp/lasercortex-pipeline-$(date +%Y%m%d).log"
LOCKFILE="/tmp/lasercortex-pipeline.lock"
RANKING_FILE="/tmp/lasercortex_ranking.json"

case "${1:-start}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Already running (PID $(cat "$PIDFILE")). Use '$0 status' or '$0 kill'."
      exit 1
    fi
    if [ -f "$LOCKFILE" ]; then
      echo "Lockfile exists — removing stale lock"
      rm -f "$LOCKFILE"
    fi
    # ---- Pre-flight: count actual work needed (OUTER shell, clean quoting) ---
    echo "Checking files needing 35B Deep Analysis..."
    NEEDS_WORK=$(python3 -c "
import json
try:
    cache = json.load(open('$REPO_DIR/.phonebook_cache.json'))
    need = sum(1 for v in cache.values() if not v.get('transform_sha'))
    print(need)
except (FileNotFoundError, json.JSONDecodeError):
    print(-1)
")
    if [ "$NEEDS_WORK" = "0" ]; then
      echo "All files already have 35B Deep Analysis — nothing to do."
      exit 0
    elif [ "$NEEDS_WORK" = "-1" ]; then
      echo "WARNING: Cannot read .phonebook_cache.json — proceeding anyway"
      NEEDS_WORK=""
    else
      echo "Files needing Deep Analysis: $NEEDS_WORK"
      echo "  (Estimated: $(( NEEDS_WORK * 75 / 60 ))min at 75s/file)"
    fi
    export NEEDS_WORK

    echo "Launching pipeline in background..."
    echo "  Log: $LOGFILE"
    echo "  PID: \$\$ → written to $PIDFILE"

    nohup bash -c '
      echo "$$" > "$1"
      trap "rm -f $2" EXIT
      touch "$2"

      exec >> "$3" 2>&1

      echo "=== Pipeline Background Job ==="
      date
      echo "Host: $(uname -a)"
      echo ""

      # ---- Pre-flight result from outer shell via env var --------------
      if [ -n "${NEEDS_WORK:-}" ]; then
        echo "[pre-flight] Files needing 35B Deep Analysis: $NEEDS_WORK"
      fi

      # ---- Remaining Pass 2: cached files are skipped automatically ----
      echo "[1/2] Running 35B Deep Analysis on outstanding files..."
      cd "$4"
      # TOP_K env var controls how many files to process in this run.
      # Default: no cap (process all remaining files).
      # Set to e.g. 144 for a ~3h budget.
      TOP_K_ARG=()
      if [ -n "${TOP_K:-}" ]; then
        TOP_K_ARG=("--top-k" "$TOP_K")
        echo "  TOP_K=$TOP_K (capped at $TOP_K files)"
      else
        echo "  TOP_K=unset (processing all remaining files)"
      fi
      PYTHONUNBUFFERED=1 python3 scripts/pipeline/generate_phonebook.py \
        --mode full \
        --ranking-file "$5" \
        "${TOP_K_ARG[@]}" \
        "$6" 2>&1
      echo ""
      echo "Pass 2 complete at $(date)"

      # ---- Re-run Cross-Layer-Linker with all completed abstracts ----
      echo "[2/2] Running Cross-Layer-Linker..."
      PASS3="$6/scripts/run_pass3.py"
      if [ -f "$PASS3" ]; then
        PYTHONUNBUFFERED=1 python3 "$PASS3" 2>&1
      else
        echo "  WARNING: $PASS3 not found — run standalone: python3 $PASS3"
      fi
      echo ""
      echo "Pass 3 complete at $(date)"

      # ---- Cleanup: stop embedding server if it was started ----
      if [ -f "/tmp/embed-server.pid" ] && kill -0 "$(cat /tmp/embed-server.pid)" 2>/dev/null; then
        echo "[cleanup] Stopping embedding server (PID $(cat /tmp/embed-server.pid))..."
        /home/nos/labware/LaserCortex/scripts/start_embed_server.sh kill 2>&1 || true
      else
        echo "[cleanup] Embedding server not running — nothing to stop"
      fi
      echo ""

      echo "=== Pipeline Background Job Complete ==="
      date
    ' _ "$PIDFILE" "$LOCKFILE" "$LOGFILE" "$ON_DIR" "$RANKING_FILE" "$REPO_DIR" &

    disown
    echo "Launched (PID $(cat "$PIDFILE"))"
    echo "Check: $0 status"
    echo "Logs: $0 logs"
    ;;

  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Running (PID $(cat "$PIDFILE"))"
      echo "Log: $LOGFILE"
    else
      echo "Not running"
      if [ -f "$LOGFILE" ]; then
        echo "Last log lines:"
        tail -5 "$LOGFILE"
      fi
    fi
    ;;

  logs)
    if [ -f "$LOGFILE" ]; then
      tail -30 "$LOGFILE"
    else
      echo "No log file yet"
    fi
    ;;

  kill)
    if [ -f "$PIDFILE" ]; then
      PID=$(cat "$PIDFILE")
      echo "Stopping PID $PID..."
      kill "$PID" 2>/dev/null || true
      sleep 2
      if kill -0 "$PID" 2>/dev/null; then
        echo "Still running — sending SIGKILL..."
        kill -9 "$PID" 2>/dev/null || true
      fi
      rm -f "$PIDFILE" "$LOCKFILE"
      echo "Stopped"
    else
      echo "No PID file — nothing to stop"
    fi
    ;;

  *)
    echo "Usage: $0 {start|status|logs|kill}"
    exit 1
    ;;
esac
