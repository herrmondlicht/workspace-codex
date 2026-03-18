#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
source "$SCRIPT_DIR/agent-common.sh"

WORKSPACE_PATH=""
PROJECT_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace)
      if [[ $# -lt 2 ]]; then
        echo "--workspace requires a path argument" >&2
        exit 1
      fi
      WORKSPACE_PATH="$2"
      shift 2
      ;;
    --project)
      if [[ $# -lt 2 ]]; then
        echo "--project requires a project name argument" >&2
        exit 1
      fi
      PROJECT_NAME="$2"
      shift 2
      ;;
    *)
      if [[ -z "$PROJECT_NAME" ]]; then
        PROJECT_NAME="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -n "$WORKSPACE_PATH" ]]; then
  WORKSPACE_PATH="$(normalize_workspace_path "$WORKSPACE_PATH")"
  COMPOSE_FILE="$(compose_file_for_workspace "$SCRIPT_DIR" "$WORKSPACE_PATH")"
  COMPOSE_PROJECT_NAME="$(compose_project_name_for_workspace "$WORKSPACE_PATH")"
elif [[ -n "$PROJECT_NAME" ]]; then
  COMPOSE_FILE="$(resolve_compose_file_by_project_name "$SCRIPT_DIR" "$PROJECT_NAME")"
  COMPOSE_PROJECT_NAME="$(compose_project_name_from_compose_file "$COMPOSE_FILE")"
else
  COMPOSE_FILE="$(resolve_existing_compose_file "$SCRIPT_DIR")"
  COMPOSE_PROJECT_NAME="$(compose_project_name_from_compose_file "$COMPOSE_FILE")"
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "Compose file not found: $COMPOSE_FILE" >&2
  echo "Available:" >&2
  ls -1 "$SCRIPT_DIR"/docker-compose.*.yml 2>/dev/null || true
  exit 1
fi

docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" down
