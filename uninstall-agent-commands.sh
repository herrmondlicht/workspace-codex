#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"

rm -f "$BIN_DIR/start-agent" "$BIN_DIR/stop-agent" "$BIN_DIR/clear-agent" "$BIN_DIR/uninstall-agent-commands"

cat <<EOF
Removed commands from $BIN_DIR

Removed commands:
  start-agent
  stop-agent
  clear-agent
  uninstall-agent-commands

Shell profile files were left unchanged.
EOF
