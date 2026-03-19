#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve())' "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
PROFILE_FILES=(
  "${HOME}/.zshrc"
  "${HOME}/.zprofile"
  "${HOME}/.bashrc"
  "${HOME}/.bash_profile"
)
UPDATED_FILES=()

profile_has_local_bin_path() {
  local profile_file="$1"

  grep -Eq '(^|[^[:alnum:]_])(\$HOME|'"$HOME"'|\$\{HOME\}|~)/\.local/bin([^[:alnum:]_]|$)' "$profile_file"
}

mkdir -p "$BIN_DIR"

ln -sfn "$SCRIPT_DIR/start-agent.sh" "$BIN_DIR/start-agent"
ln -sfn "$SCRIPT_DIR/stop-agent.sh" "$BIN_DIR/stop-agent"
ln -sfn "$SCRIPT_DIR/clear-agent.sh" "$BIN_DIR/clear-agent"
ln -sfn "$SCRIPT_DIR/uninstall-agent-commands.sh" "$BIN_DIR/uninstall-agent-commands"

for profile_file in "${PROFILE_FILES[@]}"; do
  if [[ ! -f "$profile_file" ]]; then
    continue
  fi

  if profile_has_local_bin_path "$profile_file"; then
    continue
  fi

  {
    printf '\n# Added by codex-context install-agent-commands.sh\n'
    printf '%s\n' "$PATH_LINE"
  } >> "$profile_file"
  UPDATED_FILES+=("$profile_file")
done

if [[ ${#UPDATED_FILES[@]} -eq 0 ]]; then
  default_profile="${HOME}/.bashrc"
  if [[ "${SHELL:-}" == *zsh ]]; then
    default_profile="${HOME}/.zshrc"
  fi

  if [[ ! -f "$default_profile" ]] || ! profile_has_local_bin_path "$default_profile"; then
    {
      printf '\n# Added by codex-context install-agent-commands.sh\n'
      printf '%s\n' "$PATH_LINE"
    } >> "$default_profile"
    UPDATED_FILES+=("$default_profile")
  fi
fi

cat <<EOF
Installed commands into $BIN_DIR

Available commands:
  start-agent
  stop-agent
  clear-agent
  uninstall-agent-commands

To remove them later:
  uninstall-agent-commands
EOF

if [[ ${#UPDATED_FILES[@]} -gt 0 ]]; then
  printf '\nUpdated shell profile files:\n'
  for profile_file in "${UPDATED_FILES[@]}"; do
    printf '  %s\n' "$profile_file"
  done
fi
