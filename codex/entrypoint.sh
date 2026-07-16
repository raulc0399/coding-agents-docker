#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.codex/config.toml"

# Ensure Codex can authenticate to the host MCP server.
if [[ -z "${HOST_MCP_TOKEN:-}" ]]; then
  echo "HOST_MCP_TOKEN must be set" >&2
  exit 1
fi

# Recreate the host MCP configuration in the mounted Codex config directory.
codex mcp remove host_mcp >/dev/null 2>&1 || true
codex mcp add host_mcp \
  --url http://host.docker.internal:7331/mcp \
  --bearer-token-env-var HOST_MCP_TOKEN
printf 'required = false\nstartup_timeout_sec = 10.0\ntool_timeout_sec = 30.0\n' >> "${CONFIG_FILE}"

exec codex --dangerously-bypass-approvals-and-sandbox
