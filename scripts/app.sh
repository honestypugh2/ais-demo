#!/usr/bin/env bash
# ============================================================================
# app.sh — start / stop / status the local AIS demo portal.
#
# Runs the two local processes that back the Permit Intake Portal:
#   • FastAPI backend  (uvicorn)  on :8000   — the governed orchestrator
#   • Vite frontend    (React/TS) on :5173   — the portal UI (proxies /api → :8000)
#
# By default the backend runs in SIMULATED_MODE (no Azure calls). Set
# SIMULATED_MODE=false (and provide a .env) to drive live Azure resources.
#
# Usage:
#   scripts/app.sh start      # start backend + frontend
#   scripts/app.sh stop       # stop both
#   scripts/app.sh restart    # stop then start
#   scripts/app.sh status     # show what's running
#   scripts/app.sh logs       # tail both logs
#
# Env overrides: SIMULATED_MODE (default true), API_PORT (8000), WEB_PORT (5173).
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT/.run"
API_PORT="${API_PORT:-8000}"
WEB_PORT="${WEB_PORT:-5173}"
SIMULATED_MODE="${SIMULATED_MODE:-true}"

API_PID="$RUN_DIR/api.pid"
WEB_PID="$RUN_DIR/web.pid"
API_LOG="$RUN_DIR/api.log"
WEB_LOG="$RUN_DIR/web.log"

mkdir -p "$RUN_DIR"

info() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m ! \033[0m%s\n' "$*"; }

is_running() { # is_running <pidfile>
  local f="$1"
  [ -f "$f" ] && kill -0 "$(cat "$f")" 2>/dev/null
}

start() {
  # Backend
  if is_running "$API_PID"; then
    warn "Backend already running (pid $(cat "$API_PID"))."
  else
    info "Starting FastAPI (SIMULATED_MODE=$SIMULATED_MODE) on :$API_PORT…"
    ( cd "$ROOT" && SIMULATED_MODE="$SIMULATED_MODE" setsid nohup uv run uvicorn ais_demo.api.main:app \
        --app-dir src --host 127.0.0.1 --port "$API_PORT" >"$API_LOG" 2>&1 & echo $! >"$API_PID" )
    ok "Backend pid $(cat "$API_PID")  → http://localhost:$API_PORT  (logs: .run/api.log)"
  fi

  # Frontend (ensure deps once)
  if [ ! -d "$ROOT/frontend/node_modules" ]; then
    info "Installing frontend dependencies (first run)…"
    ( cd "$ROOT/frontend" && npm install >"$WEB_LOG" 2>&1 )
  fi
  if is_running "$WEB_PID"; then
    warn "Frontend already running (pid $(cat "$WEB_PID"))."
  else
    info "Starting Vite portal on :$WEB_PORT…"
    ( cd "$ROOT/frontend" && setsid nohup npm run dev -- --port "$WEB_PORT" >>"$WEB_LOG" 2>&1 & echo $! >"$WEB_PID" )
    ok "Frontend pid $(cat "$WEB_PID")  → http://localhost:$WEB_PORT  (logs: .run/web.log)"
  fi

  echo
  ok "Portal:  http://localhost:$WEB_PORT"
  ok "API:     http://localhost:$API_PORT/api/health"
}

stop_one() { # stop_one <name> <pidfile>
  local name="$1" f="$2"
  if is_running "$f"; then
    local pid; pid="$(cat "$f")"
    info "Stopping $name (pid $pid)…"
    # Kill the whole process group (setsid makes pid the group leader),
    # so uv-wrapped uvicorn / npm-wrapped vite children go too.
    kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
    for _ in 1 2 3 4 5; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
    kill -9 -- "-$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null || true
    rm -f "$f"
    ok "$name stopped."
  else
    warn "$name not running."
    rm -f "$f"
  fi
}

free_port() { # free_port <port>  — last-resort cleanup for stray listeners
  local port="$1"
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${port}/tcp" 2>/dev/null || true
  fi
}

stop() {
  stop_one "frontend" "$WEB_PID"
  stop_one "backend" "$API_PID"
  # Best-effort: reap any stray processes still bound to the demo ports/commands.
  pkill -f "uvicorn ais_demo.api.main" 2>/dev/null || true
  pkill -f "vite.*--port $WEB_PORT" 2>/dev/null || true
  free_port "$API_PORT"
  free_port "$WEB_PORT"
}

status() {
  if is_running "$API_PID"; then ok "backend  running (pid $(cat "$API_PID")) :$API_PORT"; else warn "backend  stopped"; fi
  if is_running "$WEB_PID"; then ok "frontend running (pid $(cat "$WEB_PID")) :$WEB_PORT"; else warn "frontend stopped"; fi
}

logs() {
  info "Tailing .run/api.log and .run/web.log (Ctrl-C to stop)…"
  tail -n 20 -f "$API_LOG" "$WEB_LOG"
}

case "${1:-}" in
  start)   start ;;
  stop)    stop ;;
  restart) stop; sleep 1; start ;;
  status)  status ;;
  logs)    logs ;;
  *) echo "Usage: $0 {start|stop|restart|status|logs}" >&2; exit 1 ;;
esac
