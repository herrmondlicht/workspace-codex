#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/agent-common.sh"

WORKSPACE_PATH=""
PROJECT_NAME=""

# Uso:
#   ./start-agent.sh --workspace /path/to/project
#   ./start-agent.sh my-project
#   ./start-agent.sh --workspace /path/to/project codex
#   ./start-agent.sh my-project codex
#   ./start-agent.sh --workspace /path/to/project claude

COMMAND_ARGS=()
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
    codex|claude)
      COMMAND_ARGS+=("$1")
      shift
      ;;
    *)
      if [[ -z "$PROJECT_NAME" && ${#COMMAND_ARGS[@]} -eq 0 ]]; then
        PROJECT_NAME="$1"
        shift
      else
        COMMAND_ARGS+=("$1")
        shift
      fi
      ;;
  esac
done

COMPOSE_FILE=""
COMPOSE_PROJECT_NAME=""
COMPOSE_RUN_ARGS=()

if [[ ${#COMMAND_ARGS[@]} -gt 0 && "${COMMAND_ARGS[0]}" == "codex" ]]; then
  HAS_CODEX_BYPASS_FLAG=0
  for arg in "${COMMAND_ARGS[@]:1}"; do
    if [[ "$arg" == "--dangerously-bypass-approvals-and-sandbox" ]]; then
      HAS_CODEX_BYPASS_FLAG=1
      break
    fi
  done

  if [[ $HAS_CODEX_BYPASS_FLAG -eq 0 ]]; then
    COMMAND_ARGS=(
      "${COMMAND_ARGS[0]}"
      "--dangerously-bypass-approvals-and-sandbox"
      "${COMMAND_ARGS[@]:1}"
    )
  fi
fi

if [[ ${#COMMAND_ARGS[@]} -gt 0 && "${COMMAND_ARGS[0]}" == "claude" ]]; then
  COMPOSE_RUN_ARGS+=(-e CLAUDE_CODE_ALLOW_ROOT=1)
fi

if [[ -n "$WORKSPACE_PATH" ]]; then
  WORKSPACE_PATH="$(normalize_workspace_path "$WORKSPACE_PATH")"
  COMPOSE_FILE="$(compose_file_for_workspace "$ROOT_DIR" "$WORKSPACE_PATH")"
  COMPOSE_PROJECT_NAME="$(compose_project_name_for_workspace "$WORKSPACE_PATH")"

  if [[ ! -f "$COMPOSE_FILE" ]]; then
    "$SCRIPT_DIR/init-agent.sh" "$WORKSPACE_PATH"
  fi
elif [[ -n "$PROJECT_NAME" ]]; then
  if COMPOSE_FILE="$(resolve_compose_file_by_project_name "$ROOT_DIR" "$PROJECT_NAME")"; then
    COMPOSE_PROJECT_NAME="$(compose_project_name_from_compose_file "$COMPOSE_FILE")"
  else
    status=$?
    if [[ $status -eq 2 ]]; then
      exit 2
    fi

    echo "Compose file not found for project '$PROJECT_NAME'." >&2
    echo "Run first-time setup with --workspace /path/to/$PROJECT_NAME" >&2
    exit 1
  fi
else
  if COMPOSE_FILE="$(resolve_existing_compose_file "$ROOT_DIR")"; then
    :
  else
    status=$?
    if [[ $status -ne 1 ]]; then
      exit "$status"
    fi

    "$SCRIPT_DIR/init-agent.sh"
    COMPOSE_FILE="$(resolve_existing_compose_file "$ROOT_DIR")"
  fi

  COMPOSE_PROJECT_NAME="$(compose_project_name_from_compose_file "$COMPOSE_FILE")"
fi

# Detect Docker server API version from the host daemon (best-effort)
if command -v docker >/dev/null 2>&1; then
  SERVER_API="$(docker version --format '{{.Server.APIVersion}}' 2>/dev/null || true)"
  if [[ -n "${SERVER_API}" ]]; then
    export DOCKER_API_VERSION="${SERVER_API}"
    echo "Using DOCKER_API_VERSION=${DOCKER_API_VERSION} (from host Server.APIVersion)"
  else
    echo "Could not detect host Server.APIVersion; leaving DOCKER_API_VERSION unset"
  fi
else
  echo "docker not found on host; leaving DOCKER_API_VERSION unset"
fi

if [[ ${#COMMAND_ARGS[@]} -eq 0 ]]; then
  docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" up -d --build
else
  SERVICE_NAME="$(docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" config --services | head -n 1)"
  if [[ -z "${SERVICE_NAME}" ]]; then
    echo "Could not determine service name from $COMPOSE_FILE" >&2
    exit 1
  fi

  docker compose -p "$COMPOSE_PROJECT_NAME" -f "$COMPOSE_FILE" run --rm --build "${COMPOSE_RUN_ARGS[@]}" "$SERVICE_NAME" "${COMMAND_ARGS[@]}"
fi
