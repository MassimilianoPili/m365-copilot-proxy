#!/usr/bin/env bash
# Run the proxy FROM SOURCE — no .exe needed (Linux, or any box without the signed binary).
#
# Usage:
#   ./run.sh            # tray GUI (bare invocation; needs a desktop + python3-tk)
#   ./run.sh serve      # headless OpenAI/Anthropic API
#   ./run.sh serve --no-launch-edge
set -euo pipefail
cd "$(dirname "$0")"

if command -v uv >/dev/null 2>&1; then
    uv sync
    exec uv run copilot-openai-proxy "$@"
else
    [ -d .venv ] || python3 -m venv .venv
    ./.venv/bin/python -m pip install --quiet -e .
    exec ./.venv/bin/python -m m365_copilot_openai_proxy "$@"
fi