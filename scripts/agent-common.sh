#!/usr/bin/env bash

set -euo pipefail

normalize_workspace_path() {
  local workspace_path="$1"

  python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).expanduser().resolve())' "$workspace_path"
}

slugify_name() {
  local value="$1"

  python3 -c '
import re
import sys

value = sys.argv[1]
slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-") or "workspace"
print(slug)
' "$value"
}

workspace_service_name() {
  local workspace_path="$1"

  python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).name)' "$workspace_path" | while IFS= read -r name; do
    slugify_name "$name"
  done
}

compose_file_for_workspace() {
  local script_dir="$1"
  local workspace_path="$2"
  local service_name

  service_name="$(workspace_service_name "$workspace_path")"
  echo "$script_dir/docker-compose.${service_name}.local.yml"
}

compose_project_name_for_workspace() {
  local workspace_path="$1"
  local service_name

  service_name="$(workspace_service_name "$workspace_path")"
  echo "agent-${service_name}"
}

resolve_existing_compose_file() {
  local script_dir="$1"
  local matches=()

  shopt -s nullglob
  matches=(
    "$script_dir"/docker-compose.*.local.yml
    "$script_dir"/docker-compose.local-*.yml
  )
  shopt -u nullglob

  if [[ ${#matches[@]} -eq 1 ]]; then
    echo "${matches[0]}"
    return 0
  fi

  if [[ ${#matches[@]} -eq 0 ]]; then
    return 1
  fi

  echo "Multiple compose files found. Use --workspace to select the project." >&2
  printf '%s\n' "${matches[@]}" >&2
  return 2
}

compose_file_for_project_name() {
  local script_dir="$1"
  local project_name="$2"
  local slug

  slug="$(slugify_name "$project_name")"
  echo "$script_dir/docker-compose.${slug}.local.yml"
}

compose_project_name_for_project_name() {
  local project_name="$1"
  local slug

  slug="$(slugify_name "$project_name")"
  echo "agent-${slug}"
}

compose_project_name_from_compose_file() {
  local compose_file="$1"
  local basename

  basename="$(basename "$compose_file" .yml)"
  case "$basename" in
    docker-compose.local-*)
      basename="${basename#docker-compose.local-}"
      basename="${basename%-*}"
      ;;
    docker-compose.*.local)
      basename="${basename#docker-compose.}"
      basename="${basename%.local}"
      ;;
    *)
      basename="${basename#docker-compose.}"
      basename="${basename%.local}"
      ;;
  esac
  echo "agent-${basename}"
}

resolve_compose_file_by_project_name() {
  local script_dir="$1"
  local project_name="$2"
  local slug
  local matches=()

  slug="$(slugify_name "$project_name")"

  shopt -s nullglob
  matches=(
    "$script_dir"/docker-compose.*"$slug"*.local.yml
    "$script_dir"/docker-compose.local-*"$slug"*.yml
  )
  shopt -u nullglob

  if [[ ${#matches[@]} -eq 1 ]]; then
    echo "${matches[0]}"
    return 0
  fi

  if [[ ${#matches[@]} -eq 0 ]]; then
    return 1
  fi

  echo "Multiple compose files match project '$project_name'. Be more specific." >&2
  printf '%s\n' "${matches[@]}" >&2
  return 2
}
