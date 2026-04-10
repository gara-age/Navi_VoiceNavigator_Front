#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

PYTHON_BIN=""
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PYTHON_BIN="$candidate"
    break
  fi
done

if [[ -z "$PYTHON_BIN" ]]; then
  echo "[ERROR] Python 3.11+ interpreter not found."
  exit 1
fi

rm -rf .venv-server
"$PYTHON_BIN" -m venv .venv-server
. .venv-server/bin/activate

python -m pip install --upgrade pip
python -m pip install -r local_server/requirements.txt
python -m playwright install chromium

echo
echo "[DONE] Automation environment ready: .venv-server"
echo "[NEXT] Run JSON automation plans through the Flutter app or with:"
echo "       .venv-server/bin/python -m local_server.app.simulation.json_agent_scenario <plan.json>"
