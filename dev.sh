#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND_PORT="${BACKEND_PORT:-8000}"
FRONTEND_PORT="${FRONTEND_PORT:-5173}"

cleanup() {
  echo "Shutting down..."
  [ -n "${BACKEND_PID:-}" ] && kill "$BACKEND_PID" 2>/dev/null
  [ -n "${FRONTEND_PID:-}" ] && kill "$FRONTEND_PID" 2>/dev/null
  exit 0
}
trap cleanup SIGINT SIGTERM

echo "=== LaserCortex Development Server ==="

# ── Backend ────────────────────────────────────────────────────────────
echo ""
echo "[1/2] Starting Python backend (uvicorn) on port $BACKEND_PORT..."
cd "$ROOT"
python3 -c "import fastapi, uvicorn" 2>/dev/null || {
  echo "Installing Python dependencies..."
  pip install -q -r canvas_app/backend/requirements.txt
}
python3 -m uvicorn canvas_app.backend.main:app \
  --host 0.0.0.0 --port "$BACKEND_PORT" --reload &
BACKEND_PID=$!
sleep 2

# ── Frontend ───────────────────────────────────────────────────────────
echo "[2/2] Starting frontend (Vite) on port $FRONTEND_PORT..."
cd "$ROOT/canvas_app/frontend"
[ -d node_modules ] || npm install
npx vite --port "$FRONTEND_PORT" --host &
FRONTEND_PID=$!

echo ""
echo "  Backend:  http://localhost:$BACKEND_PORT"
echo "  Frontend: http://localhost:$FRONTEND_PORT"
echo "  Tamari:   http://localhost:$FRONTEND_PORT/tamari.html"
echo ""
echo "Press Ctrl+C to stop both servers."

wait
