#!/usr/bin/env bash
set -euo pipefail

if tmux has-session -t =codex 2>/dev/null; then
  exec tmux -u attach -t =codex
fi

# Ensure Codex can authenticate to the host MCP server.
if [[ -z "${HOST_MCP_TOKEN:-}" ]]; then
  echo "HOST_MCP_TOKEN not set" >&2
else
  # Recreate the host MCP configuration in the mounted Codex config directory.
  codex mcp remove host_mcp >/dev/null 2>&1 || true
  codex mcp add host_mcp \
    --url http://host.docker.internal:7331/mcp \
    --bearer-token-env-var HOST_MCP_TOKEN
fi

# Read only the account label from the saved credentials; never print tokens.
account=$(node <<'NODE'
const fs = require('node:fs');
const path = require('node:path');

let account = 'unavailable';
try {
    const configDirectory = process.env.CODEX_HOME || path.join(process.env.HOME, '.codex');
    const auth = JSON.parse(fs.readFileSync(path.join(configDirectory, 'auth.json'), 'utf8'));

    if (auth.auth_mode === 'apikey' || (!auth.auth_mode && auth.OPENAI_API_KEY)) {
        account = 'API key';
    } else if (auth.tokens?.id_token) {
        const payload = auth.tokens.id_token.split('.')[1];
        const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
        if (typeof claims.email === 'string' && claims.email) {
            account = claims.email;
        }
    }
} catch {
    // Missing or unreadable credentials must not prevent Codex from starting.
}

console.log(account);
NODE
)

if [[ -t 0 && -t 1 ]]; then
  printf '\033[1;93mCodex account: %s\033[0m\n' "$account"
  read -r -p "Press Enter to continue… " || true
else
  printf 'Codex account: %s\n' "$account"
fi

exec tmux -u new -A -s codex codex --no-daemon --dangerously-bypass-approvals-and-sandbox
