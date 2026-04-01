# Coding Agents Docker - Plan

## Overview

3 CLI scripts (`d_claude`, `d_codex`, `d_copilot`) that start Docker containers with the current working directory mapped as `/workspace`. Each container runs a different coding agent interactively.

## Features

- Current dir mounted to `/workspace` in container
- `.env*` files on host are hidden inside container via `/dev/null` overlay mounts (generated fresh on every run)
- `$AGENT_MD_PATH` env var mapped to agent-specific config paths under `~` in container:
  - Claude: `~/.claude/CLAUDE.md`
  - Codex: `~/.codex/AGENTS.md`
  - Copilot: `~/.copilot/copilot-instructions.md`
- Container user `agent` with UID/GID matching the host user who runs the script
- Interactive only (`docker run -it`)
- One `docker-compose.yml` per agent
- `install.sh` symlinks CLI scripts to `~/.local/bin`

## Tasks

- [x] Dockerfile for Claude Code (`claude/Dockerfile`)
- [x] Dockerfile for Codex (`codex/Dockerfile`)
- [x] Dockerfile for Copilot (`copilot/Dockerfile`)
- [x] `docker-compose.yml` for Claude (`claude/docker-compose.yml`)
- [x] `docker-compose.yml` for Codex (`codex/docker-compose.yml`)
- [x] `docker-compose.yml` for Copilot (`copilot/docker-compose.yml`)
- [x] CLI script `d_claude`
- [x] CLI script `d_codex`
- [x] CLI script `d_copilot`
- [x] `install.sh`
