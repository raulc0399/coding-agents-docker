#!/usr/bin/env bash
set -euo pipefail

# Ensure Claude can authenticate to the host MCP server.
if [[ -z "${HOST_MCP_TOKEN:-}" ]]; then
  echo "HOST_MCP_TOKEN not set" >&2
else
  # Recreate the host MCP configuration in the mounted Claude config.
  claude mcp remove -s user host_mcp >/dev/null 2>&1 || true
  claude mcp add -s user -t http host_mcp http://host.docker.internal:7331/mcp \
    -H "Authorization: Bearer ${HOST_MCP_TOKEN}"
fi

account=$( { claude auth status </dev/null 2>/dev/null || true; } | jq -er 'if .loggedIn == true then .email // .authMethod // "unavailable" else "not signed in" end' 2>/dev/null) || account="unavailable"
if [[ -t 0 && -t 1 ]]; then
  printf '\033[1;93mClaude account: %s\033[0m\n' "${account:-unavailable}"
  read -r -p "Press Enter to continue… " || true
else
  printf 'Claude account: %s\n' "${account:-unavailable}"
fi

exec claude --dangerously-skip-permissions
