#!/bin/sh
set -eu

ACLI_CONFIG_DIR=/root/.config/acli
ACLI_HOST_CONFIG_DIR=/root/.config/acli-host
ACLI_PERSISTED_CONFIG=$ACLI_CONFIG_DIR/jira_config.yaml
CLAUDE_PERSISTED_JSON=/root/.claude/.claude.json

extract_acli_login_fields() {
  python3 - "$1" <<'PY'
import sys

path = sys.argv[1]
current_profile = None
profiles = []
profile = None

with open(path, encoding="utf-8") as handle:
    for raw_line in handle:
        line = raw_line.rstrip("\n")
        stripped = line.lstrip()

        if stripped.startswith("current_profile:"):
            current_profile = stripped.split(":", 1)[1].strip()
            continue

        if stripped.startswith("- site:"):
            if profile:
                profiles.append(profile)
            profile = {"site": stripped.split(":", 1)[1].strip()}
            continue

        if profile is None or ":" not in stripped:
            continue

        key, value = stripped.split(":", 1)
        key = key.strip()
        value = value.strip()
        if key in {"cloud_id", "account_id", "email"}:
            profile[key] = value

if profile:
    profiles.append(profile)

selected = None
if current_profile:
    for candidate in profiles:
        if f"{candidate.get('cloud_id', '')}:{candidate.get('account_id', '')}" == current_profile:
            selected = candidate
            break

if selected is None and profiles:
    selected = profiles[0]

if selected and selected.get("site") and selected.get("email"):
    print(selected["site"])
    print(selected["email"])
PY
}

mkdir -p /root/.config
mkdir -p "$ACLI_CONFIG_DIR"
mkdir -p /root/.claude
mkdir -p /root/.codex

if [ ! -f "$ACLI_PERSISTED_CONFIG" ] && [ -f "$ACLI_HOST_CONFIG_DIR/jira_config.yaml" ]; then
  cp "$ACLI_HOST_CONFIG_DIR/jira_config.yaml" "$ACLI_PERSISTED_CONFIG"
fi

cp /etc/claude-code/managed-settings.json /root/.claude/settings.json

if [ ! -f "$CLAUDE_PERSISTED_JSON" ]; then
  cp /etc/claude-code/managed-settings.json "$CLAUDE_PERSISTED_JSON"
fi

rm -f /root/.claude.json
ln -s "$CLAUDE_PERSISTED_JSON" /root/.claude.json

if [ ! -f /root/.codex/auth.json ] && [ -n "${OPENAI_API_KEY:-}" ]; then
  jq -n --arg api_key "$OPENAI_API_KEY" \
    '{auth_mode: "apikey", OPENAI_API_KEY: $api_key}' \
    > /root/.codex/auth.json
  chmod 600 /root/.codex/auth.json
fi

if [ -n "${ATLASSIAN_API_TOKEN:-}" ] && [ -f "$ACLI_PERSISTED_CONFIG" ] && command -v acli >/dev/null 2>&1; then
  if ! acli jira auth status >/dev/null 2>&1; then
    ACLI_LOGIN_FIELDS="$(extract_acli_login_fields "$ACLI_PERSISTED_CONFIG" || true)"
    ACLI_SITE="$(printf '%s\n' "$ACLI_LOGIN_FIELDS" | sed -n '1p')"
    ACLI_EMAIL="$(printf '%s\n' "$ACLI_LOGIN_FIELDS" | sed -n '2p')"

    if [ -n "$ACLI_SITE" ] && [ -n "$ACLI_EMAIL" ]; then
      if ! printf '%s\n' "$ATLASSIAN_API_TOKEN" | acli jira auth login --site "$ACLI_SITE" --email "$ACLI_EMAIL" --token >/dev/null 2>&1; then
        echo "Warning: failed to seed ACLI Jira auth for $ACLI_SITE" >&2
      fi
    else
      echo "Warning: unable to extract Jira site/email from $ACLI_PERSISTED_CONFIG" >&2
    fi
  fi
fi

exec "$@"
