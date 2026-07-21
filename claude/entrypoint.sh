#!/usr/bin/env bash
set -euo pipefail

# Recreate the host MCP configuration in the mounted Claude config.
claude mcp remove -s user host_mcp >/dev/null 2>&1 || true

# Ensure Claude can authenticate to the host MCP server.
if [[ -z "${HOST_MCP_TOKEN:-}" ]]; then
  echo "HOST_MCP_TOKEN not set" >&2
else
  claude mcp add -s user -t http host_mcp http://host.docker.internal:7331/mcp \
    -H "Authorization: Bearer ${HOST_MCP_TOKEN}"
fi

exec claude --dangerously-skip-permissions
