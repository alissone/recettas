#!/usr/bin/env bash
# First-run setup (venv + deps) and launch of tasks.py.
set -euo pipefail
cd "$(dirname "$0")"

VENV=".venv"
PY="${PYTHON:-python3}"

if [ ! -x "$VENV/bin/python" ]; then
  echo "Creating virtualenv in scripts/$VENV ..."
  "$PY" -m venv "$VENV"
fi

# Reinstall only when requirements change
STAMP="$VENV/.deps-installed"
if [ ! -f "$STAMP" ] || [ requirements.txt -nt "$STAMP" ]; then
  echo "Installing dependencies ..."
  "$VENV/bin/python" -m pip install --quiet --upgrade pip
  "$VENV/bin/python" -m pip install --quiet -r requirements.txt
  touch "$STAMP"
fi

exec "$VENV/bin/python" tasks.py "$@"
