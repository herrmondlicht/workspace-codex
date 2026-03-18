#!/bin/sh
set -eu

CLAUDE_PERSISTED_JSON=/root/.claude/.claude.json

mkdir -p /root/.claude
mkdir -p /root/.codex

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

exec "$@"
