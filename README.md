# Codex Context

Small launcher repo for running a shared Docker agent image with either Codex or Claude against a project workspace.

## Requirements

- Docker running locally
- `git`
- `python3`

## Install Commands

From this repo:

```bash
./install-agent-commands.sh
```

This creates symlinks in `~/.local/bin`:

- `start-agent`
- `stop-agent`

If `~/.local/bin` is not already in your `PATH`, add:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## First Run For A Project

Initialize a project with its full workspace path:

```bash
start-agent --workspace ~/projects/styleseat-workspace
```

This generates a project-specific compose file in this repo, for example:

```bash
docker-compose.styleseat-workspace.local.yml
```

The service name inside that compose file is derived from the workspace directory name.

## Later Runs

After the project has been initialized once, use the project directory name or any unique match.

Examples:

```bash
start-agent styleseat-workspace
start-agent styleseat
```

If a token matches more than one generated compose file, the command exits with an error and asks for a more specific name.

## Start Codex

```bash
start-agent styleseat codex
```

Codex is launched with `--dangerously-bypass-approvals-and-sandbox` by default.

## Start Claude

```bash
start-agent styleseat claude
```

Claude runs with `CLAUDE_CODE_ALLOW_ROOT=1`. Claude settings are seeded from [managed-settings.json](/Users/gsilva/projects/codex-context/config/claude/managed-settings.json), and login persistence is stored in Docker volumes.

## Stop A Project

```bash
stop-agent styleseat
```

This runs `docker compose down` for that project. It removes the project container and network, but keeps named volumes such as Codex and Claude auth storage.

## Generated Files

Per-project compose files are generated locally in this repo and are intended to be reused:

- `docker-compose.<project>.local.yml`

These files mount:

- the selected workspace at `/work/workspace`
- host AWS, SSH, and GitHub CLI config from your home directory
- persistent Codex auth
- persistent Claude auth/config

## Notes

- `config/projects.yml` is not used by the current launcher flow.
- If you change the compose template or entrypoint behavior and need it to apply to an existing project container, stop and start that project again so Docker recreates the container.
