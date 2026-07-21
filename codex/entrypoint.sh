#!/usr/bin/env bash
set -euo pipefail

# Recreate the host MCP configuration in the mounted Codex config directory.
codex mcp remove host_mcp >/dev/null 2>&1 || true

# Ensure Codex can authenticate to the host MCP server.
if [[ -z "${HOST_MCP_TOKEN:-}" ]]; then
  echo "HOST_MCP_TOKEN not set" >&2
else
  codex mcp add host_mcp \
    --url http://host.docker.internal:7331/mcp \
    --bearer-token-env-var HOST_MCP_TOKEN
fi

exec codex --dangerously-bypass-approvals-and-sandbox
