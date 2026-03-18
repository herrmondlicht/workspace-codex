#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$BIN_DIR"

ln -sfn "$SCRIPT_DIR/start-agent.sh" "$BIN_DIR/start-agent"
ln -sfn "$SCRIPT_DIR/stop-agent.sh" "$BIN_DIR/stop-agent"
ln -sfn "$SCRIPT_DIR/start-codex.sh" "$BIN_DIR/start-codex"
ln -sfn "$SCRIPT_DIR/start-claude.sh" "$BIN_DIR/start-claude"
ln -sfn "$SCRIPT_DIR/init-agent.sh" "$BIN_DIR/init-agent"

cat <<EOF
Installed commands into $BIN_DIR

Available commands:
  start-agent
  stop-agent
  start-codex
  start-claude
  init-agent

If '$BIN_DIR' is not in your PATH, add this line to your shell profile:
  export PATH="$BIN_DIR:\$PATH"
EOF
