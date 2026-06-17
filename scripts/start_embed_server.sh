#!/usr/bin/env bash
# start_embed_server.sh — Start bge-m3 embedding server as a proper background job.
#
# Contains resource-safety guards per SAFETY.md P2–P4:
#   - Free RAM check: refuse to start if < 4 GB free (process killed before swap-thrashing)
#   - Virtual memory cap: ulimit -v 12 GB (prevents unbounded VSZ, tuned for PyTorch init)
#   - RSS watchdog: kills the server if RSS exceeds 3 GB
#   - Ramp-ready: caller can gradually increase workers
set -euo pipefail

PIDFILE="/tmp/lasercortex-embed.pid"
LOGFILE="/tmp/lasercortex-embed.log"
WDFILE="/tmp/lasercortex-embed-watchdog.pid"
RSS_LIMIT_MB=3072      # kill server if RSS exceeds 3 GB
VMEM_LIMIT_KB=$((12 * 1024 * 1024))   # ulimit -v: 12 GB virtual (RSS stays ~1-6 GB depending on backend; PyTorch init + libgomp threads need ~8 GB)

case "${1:-start}" in
  start)
    shift   # consume the subcommand; remaining "$@" are forwarded to the server

    # ── Resource check (P2) ──────────────────────────────────────────
    # Check we have enough free RAM, not swap usage per se.  Swap from
    # idle background processes (surreal, steam, etc.) is harmless as
    # long as there's enough free RAM for the server (~4 GB headroom).
    FREE_MB=$(free -m | awk '/Mem:/ {print $7}')
    SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
    MIN_FREE_MB=$((4 * 1024))
    if [ -n "$FREE_MB" ] && [ "$FREE_MB" -lt "$MIN_FREE_MB" ]; then
      echo "ERROR: Only ${FREE_MB} MB free RAM (need ≥ ${MIN_FREE_MB} MB)."
      echo "  Cannot safely start the embedding server."
      exit 1
    fi
    if [ -n "$SWAP_USED" ] && [ "$SWAP_USED" -gt 1024 ]; then
      echo "  Note: ${SWAP_USED} MB swap in use (idle processes). Free RAM ${FREE_MB} MB — OK."
    fi

    # ── Already running? ─────────────────────────────────────────────
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Already running (PID $(cat "$PIDFILE"))"
      exit 1
    fi

    echo "Starting bge-m3 embedding server on :8082..."
    echo "  Extra args: $@"
    echo "  RSS limit:  ${RSS_LIMIT_MB} MB"
    echo "  VMEM limit: $(( VMEM_LIMIT_KB / 1024 )) MB"

    # ── Launch with memory cap (P2) ──────────────────────────────────
    # Use setsid to fully detach from the controlling terminal so Ctrl+C
    # in the parent shell doesn't propagate to the server.
    setsid bash -c '
echo "$$" > "$0"
ulimit -v '"$VMEM_LIMIT_KB"'
exec python3 /home/nos/labware/open-notebook/scripts/pipeline/embedding_server.py \
  --port 8082 --device cpu \
  "$@"
' "$PIDFILE" "$@" \
      > "$LOGFILE" 2>&1 &
    # The setsid child writes its own PID ($$) immediately; we don't need `$!`

    # ── RSS watchdog (P2) ────────────────────────────────────────────
    (
      # Wait for PID file to be written by the setsid child (first action)
      PID=""
      for i in $(seq 1 30); do
        if [ -f "$PIDFILE" ]; then
          PID=$(cat "$PIDFILE")
          break
        fi
        sleep 0.2
      done
      if [ -z "$PID" ]; then
        exit 1  # PID file never appeared — server likely failed to launch
      fi
      # Don't start monitoring until the process is actually running
      sleep 5
      while kill -0 "$PID" 2>/dev/null; do
        RSS=$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ')
        if [ -n "$RSS" ] && [ "$RSS" -gt $((RSS_LIMIT_MB * 1024)) ]; then
          echo "[$(date '+%H:%M:%S')] WATCHDOG: RSS ${RSS}KB exceeds ${RSS_LIMIT_MB}MB limit — killing $PID"
          kill -9 "$PID" 2>/dev/null || true
          rm -f "$PIDFILE"
          exit 1
        fi
        sleep 5
      done
    ) &
    echo $! > "$WDFILE"

    # ── Wait for it to be ready ──────────────────────────────────────
    for i in $(seq 1 60); do
      # Also check the server process is still alive (might have been OOM-killed)
      if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "Server died during startup — check $LOGFILE"
        exit 1
      fi
      if curl -sf http://localhost:8082/v1/embeddings -H "Content-Type: application/json" \
        -d '{"input":"test","model":"bge-m3"}' > /dev/null 2>&1; then
        echo "Ready after ${i}s"
        break
      fi
      if [ $i -eq 60 ]; then
        echo "Failed to start after 60s — check $LOGFILE"
        exit 1
      fi
      sleep 1
    done
    echo "PID $(cat "$PIDFILE") — log: $LOGFILE"
    echo "Watchdog PID $(cat "$WDFILE" 2>/dev/null || echo '?')"
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Running (PID $(cat "$PIDFILE"))"
    else
      echo "Not running"
    fi
    ;;
  kill)
    if [ -f "$PIDFILE" ]; then
      kill "$(cat "$PIDFILE")" 2>/dev/null || true
      rm -f "$PIDFILE"
    fi
    if [ -f "$WDFILE" ]; then
      kill "$(cat "$WDFILE")" 2>/dev/null || true
      rm -f "$WDFILE"
    fi
    echo "Stopped"
    ;;
  logs)
    tail -20 "$LOGFILE" 2>/dev/null || echo "No log"
    ;;
  *)
    echo "Usage: $0 {start|status|kill|logs}"
    exit 1
    ;;
esac
