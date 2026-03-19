#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "${BASH_SOURCE[0]}")"
ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
exec "$ROOT_DIR/scripts/stop-agent.sh" "$@"
