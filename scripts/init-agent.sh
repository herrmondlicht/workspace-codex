#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/agent-common.sh"

WORKSPACE_PATH="${1:-}"
TEMPLATE_FILE="$ROOT_DIR/docker-compose.agent.example.yml"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Compose template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

if [[ -z "$WORKSPACE_PATH" ]]; then
  printf "Workspace path to mount at /work/workspace: "
  read -r WORKSPACE_PATH
fi

if [[ -z "$WORKSPACE_PATH" ]]; then
  echo "Workspace path is required." >&2
  exit 1
fi

HOME_DIR="$(python3 -c 'from pathlib import Path; print(Path.home())')"
WORKSPACE_PATH="$(normalize_workspace_path "$WORKSPACE_PATH")"
COMPOSE_FILE="$(compose_file_for_workspace "$ROOT_DIR" "$WORKSPACE_PATH")"
SERVICE_NAME="$(workspace_service_name "$WORKSPACE_PATH")"

if [[ ! -d "$WORKSPACE_PATH" ]]; then
  echo "Workspace path does not exist or is not a directory: $WORKSPACE_PATH" >&2
  exit 1
fi

if [[ -f "$COMPOSE_FILE" ]]; then
  echo "Using existing $COMPOSE_FILE"
  exit 0
fi

python3 - "$TEMPLATE_FILE" "$COMPOSE_FILE" "$HOME_DIR" "$WORKSPACE_PATH" "$SERVICE_NAME" <<'PY'
from pathlib import Path
import sys

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
home_dir = sys.argv[3]
workspace_path = sys.argv[4]
service_name = sys.argv[5]

content = template_path.read_text()
content = content.replace("__SERVICE_NAME__", service_name)
content = content.replace("__HOME_DIR__", home_dir)
content = content.replace("__WORKSPACE_PATH__", workspace_path)
output_path.write_text(content)
PY

echo "Generated $COMPOSE_FILE"
