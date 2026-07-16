#!/usr/bin/env bash
set -euo pipefail

# Ensure Claude can authenticate to the host MCP server.
if [[ -z "${HOST_MCP_TOKEN:-}" ]]; then
  echo "HOST_MCP_TOKEN must be set" >&2
  exit 1
fi

# Recreate the host MCP configuration in the mounted Claude config.
claude mcp remove -s user host_mcp >/dev/null 2>&1 || true
claude mcp add -s user -t http host_mcp http://host.docker.internal:7331/mcp \
  -H "Authorization: Bearer ${HOST_MCP_TOKEN}"

exec claude --dangerously-skip-permissions
