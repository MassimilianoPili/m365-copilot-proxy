#!/usr/bin/env bash
# Unified toggle script for the M365 Copilot proxy (macOS / Linux).
# Counterpart of proxy.ps1 on Windows.
#
# Usage:
#   ./proxy.sh            # toggle on/off
#   ./proxy.sh --reinstall # force a fresh `pip install -e .` then start
#
# Detects listener on :8000; if active, kills proxy processes; otherwise
# ensures .venv + editable install and starts the headless server in background.
#
# We don't PyInstaller-build a binary here: Mark-of-the-Web exists only on
# Windows, so running from source via the venv is the simplest path. For an
# interactive (foreground, tray/serve) run, use run.sh instead.
set -euo pipefail
cd "$(dirname "$0")"

PORT=8000
REINSTALL=0
[ "${1:-}" = "--reinstall" ] && REINSTALL=1

# --- 1. detect listener on :PORT --------------------------------------------
PID=""
if command -v lsof >/dev/null 2>&1; then
    PID=$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null | head -n1 || true)
elif command -v ss >/dev/null 2>&1; then
    PID=$(ss -ltnp 2>/dev/null | awk -v p=":$PORT" '$4 ~ p {print $7}' \
          | grep -oE 'pid=[0-9]+' | head -n1 | cut -d= -f2 || true)
fi

# --- 2. running -> STOP -----------------------------------------------------
if [ -n "$PID" ]; then
    echo "[M365 Proxy] running on :$PORT (pid $PID) - STOPPING..."
    # Match the Python module name and the console-script entry; same kill-by-name
    # spirit as proxy.ps1 / proxy-toggle.bat. Idempotent.
    pkill -f 'm365_copilot_openai_proxy' 2>/dev/null || true
    pkill -f 'copilot-openai-proxy'      2>/dev/null || true
    sleep 1
    echo "[M365 Proxy] stopped."
    exit 0
fi

# --- 3. not running -> ENSURE + START ---------------------------------------
echo "[M365 Proxy] not running - preparing to start..."

# 3a. ensure venv + editable install
if [ ! -d .venv ] || [ "$REINSTALL" = "1" ]; then
    if [ ! -d .venv ]; then
        echo "  .venv missing - creating..."
        python3 -m venv .venv
    fi
    echo "  installing project (editable)..."
    ./.venv/bin/python -m pip install --quiet --upgrade pip
    ./.venv/bin/python -m pip install --quiet -e .
fi

# 3b. start headless in background; logs to proxy.log next to the script
echo "[M365 Proxy] starting from source (background)..."
M365_TIME_ZONE="Europe/Rome" \
M365_WORK_GROUNDING="false" \
M365_DEBUG="1" \
nohup ./.venv/bin/python -m m365_copilot_openai_proxy serve > proxy.log 2>&1 &
BG_PID=$!
disown "$BG_PID" 2>/dev/null || true
sleep 1
echo "[M365 Proxy] started (pid $BG_PID). http://127.0.0.1:$PORT  (logs: proxy.log)"