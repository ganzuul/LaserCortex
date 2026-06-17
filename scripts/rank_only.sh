#!/usr/bin/env bash
# rank_only.sh — Run only the ranking step, no pipeline.
# Writes its own PID to /tmp/lasercortex-rank.pid and survives tool session timeouts.
set -euo pipefail

PIDFILE="/tmp/lasercortex-rank.pid"
LOGFILE="/tmp/rerank-2026-06-17.log"

case "${1:-start}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Already running (PID $(cat "$PIDFILE"))"
      exit 1
    fi
    echo "Launching ranking in background..."
    echo "  Log: $LOGFILE"
    # Use setsid to completely detach from the controlling terminal
    setsid bash -c '
      echo "$$" > "$1"
      exec >> "$2" 2>&1
      date
      cd /home/nos/labware/open-notebook
      python3 scripts/pipeline/rank_by_relevance.py \
        /home/nos/labware/LaserCortex \
        --query "Lean4 formal verification of EML tree cost, Tamari lattice, cross-impact cost function, and binary tree enumeration with Phi parametrized by 14 logic types" \
        --output /tmp/lasercortex_ranking.json
      echo "=== DONE ==="
      date
      rm -f "$1"
    ' _ "$PIDFILE" "$LOGFILE" &
    echo "PID $(cat "$PIDFILE" 2>/dev/null || echo '?')"
    echo "Watch: tail -f $LOGFILE"
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Running (PID $(cat "$PIDFILE"))"
      echo "Runtime: $(ps -o etime= -p $(cat "$PIDFILE") 2>/dev/null || echo '?')"
      tail -3 "$LOGFILE" 2>/dev/null || echo "(no log)"
    else
      echo "Not running"
      tail -10 "$LOGFILE" 2>/dev/null || echo "(no log)"
    fi
    ;;
  kill)
    if [ -f "$PIDFILE" ]; then
      kill "$(cat "$PIDFILE")" 2>/dev/null; sleep 1
      kill -0 "$(cat "$PIDFILE")" 2>/dev/null && kill -9 "$(cat "$PIDFILE")" 2>/dev/null || true
      rm -f "$PIDFILE"
      echo "Stopped"
    fi
    ;;
  logs)
    tail -30 "$LOGFILE" 2>/dev/null || echo "(no log)"
    ;;
  *)
    echo "Usage: $0 {start|status|kill|logs}"
    exit 1
    ;;
esac
