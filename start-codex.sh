#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

ARGS=()
if [[ $# -gt 0 ]]; then
  case "$1" in
    --workspace)
      if [[ $# -lt 2 ]]; then
        echo "--workspace requires a path argument" >&2
        exit 1
      fi
      ARGS+=(--workspace "$2")
      shift 2
      ;;
    --project)
      if [[ $# -lt 2 ]]; then
        echo "--project requires a project name argument" >&2
        exit 1
      fi
      ARGS+=(--project "$2")
      shift 2
      ;;
    -*)
      ;;
    *)
      ARGS+=(--project "$1")
      shift
      ;;
  esac
fi

exec "$SCRIPT_DIR/start-agent.sh" "${ARGS[@]}" codex --dangerously-bypass-approvals-and-sandbox "$@"
