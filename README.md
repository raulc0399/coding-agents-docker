# Coding Agents Docker

Run AI coding agents (Claude, Codex, Copilot) in isolated Docker containers with your current working directory mounted as `/workspace`.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Docker Compose
- Bash

## Installation

1. Clone the repository:
   ```bash
   git clone git@github.com:raulc0399/coding-agents-docker-.git
   cd coding-agents-docker
   ```

2. Run the install script:
   ```bash
   ./install.sh
   ```
   This creates symlinks in `~/.local/bin/` pointing to the launcher scripts.

3. Ensure `~/.local/bin` is in your `PATH`. Add this to your `~/.bashrc` or `~/.zshrc` if needed:
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

4. Reload your shell:
   ```bash
   source ~/.bashrc   # or ~/.zshrc
   ```

## Usage

Run any agent from any directory on your machine:

```bash
d_claude    # Claude Code (Anthropic)
d_codex     # Codex (OpenAI)
d_copilot   # Copilot (GitHub)
rebuild_containers   # Rebuild all agent images
```

All three images include `tmux`. `d_claude` and `d_codex` automatically start their CLIs in tmux sessions named `claude` and `codex`, each in its own container, with the existing CLI flags.

Claude and Codex use `LANG=C.UTF-8` and `tmux -u` for UTF-8 character output. Their `/etc/tmux.conf` enables focus reporting, 256-color panes, and RGB output, assuming a truecolor host terminal as specified by `COLORTERM=truecolor`. Press `Ctrl+b`, then `d` to detach; the container and CLI keep running. Run `d_claude` or `d_codex` again from the same project directory to reconnect. Containers are matched by agent and full host directory path.

Claude also sets `CLAUDE_CODE_TMUX_TRUECOLOR=1` to disable its own 256-color limit inside tmux, preserving truecolor UI colors such as the logo.

After exiting the CLI, the container stays running; rerunning its launcher starts a new session. Use `docker ps` to find its name, then `docker stop <container-name>` to stop and remove it. Existing containers retain their original image, mounts, and environment; stop them before changing configuration or using rebuilt images.

The current working directory is automatically mounted as `/workspace` inside the container.
Agent configuration is persisted in your host home directory (`~/.claude`, `~/.codex`, `~/.agents`, `~/.copilot`), so setup does not need to be repeated on every start.

Codex and Claude include Azure CLI (`az`). Their launchers mount the host's `~/.azure` directory at `/home/agent/.azure`, preserving Azure configuration and container logins across runs. Set `AZURE_CONFIG_DIR` on the host to use a different directory.

To sign in from inside either container, run `az login --use-device-code` and follow the browser instructions. Host credentials may require a separate container login, particularly when the host uses Windows credential encryption.

Codex and Claude also include Terraform. Their launchers mount host `~/.terraform.d` and `~/.terraformrc` at `/home/agent/.terraform.d` and `/home/agent/.terraformrc`, preserving `terraform login` credentials and CLI settings. On Windows, the host paths are `%APPDATA%/terraform.d` and `%APPDATA%/terraform.rc`. Set `TF_CLI_CONFIG_FILE` on the host to mount an alternate CLI configuration file. Paths referenced inside that file must be valid inside the Linux container.

To use an alternate Claude config directory or state file, set the corresponding env vars (defaults shown):

```bash
CLAUDE_CONFIG_DIR=~/.claude CLAUDE_CONFIG_JSON=~/.claude.json d_claude
```

To use an alternate Codex config directory (default shown):

```bash
CODEX_CONFIG_DIR=~/.codex d_codex
```

To publish one Codex container port to the same host port:

```bash
CODEX_PORT=1455 d_codex
```

To use host networking for a local OAuth callback, enable host networking in Docker Desktop and run:

```bash
CODEX_HOST_NETWORK=true d_codex
```

`CODEX_HOST_NETWORK` takes precedence over `CODEX_PORT`.

To rebuild all agent images after changing Dockerfiles or compose configuration:

```bash
rebuild_containers
```

To apply this tmux update, stop existing Claude/Codex containers with `docker stop <container-name>`, rebuild, then run `d_claude` or `d_codex` to create new containers. Rebuilding alone does not update existing containers.

### Website and native app access

All three images include Node.js 24, `agent-browser` 0.39.0, Chromium, and `agent-device` 0.21.24. The agents can run both CLIs directly; MCP configuration is optional.

Rebuild from this repository on your Docker host, then start a new agent session. These commands use Bash:

```bash
./rebuild_containers
```

The rebuild script currently skips Copilot. To rebuild that image too:

```bash
docker build -t d_copilot copilot
```

#### Websites

Ask the agent:

> Use agent-browser to check http://host.docker.internal:3000. Test navigation and the login form, report browser errors, and save screenshots in the project directory.

Use `http://localhost:3000` for a server running inside the same container. Use `http://host.docker.internal:3000` for a server on the Docker host; it must listen on an interface reachable from Docker, usually `0.0.0.0`. Public URLs work directly.

For direct CLI use inside the container:

```bash
agent-browser open https://example.com
agent-browser snapshot -i
agent-browser screenshot ./website.png
agent-browser errors
agent-browser close
```

Use `agent-browser click @e1` or `agent-browser fill @e2 "text"` with references from the latest snapshot, then take another snapshot after navigation. The browser runs headlessly; screenshots saved in the mounted project remain on the host. Browser login state is temporary unless explicitly saved outside the disposable container.

Run `agent-browser skills get core` for the bundled usage guide, or `agent-browser doctor` to check the browser installation. See the [agent-browser documentation](https://github.com/vercel-labs/agent-browser).

#### Native iOS and Android apps

The container includes the client. Run the emulator, simulator, or physical device on a device host: iOS requires a Mac with Xcode; Android requires the Android SDK/ADB and an emulator or an authorized device. Physical iOS devices also require Developer Mode, pairing, and runner signing as described in the [installation guide](https://oss.callstack.com/agent-device/docs/installation).

On the device host with Node.js 24 installed:

```bash
npm install -g agent-device@0.21.24
agent-device doctor
agent-device proxy --host 0.0.0.0 --port 4310
```

Keep the proxy running. It prints an authentication token; allow port 4310 only from your Docker host/network.

In another host terminal, set the connection before starting the agent:

```bash
export AGENT_DEVICE_DAEMON_BASE_URL=http://host.docker.internal:4310/agent-device
read -rsp 'Proxy token: ' AGENT_DEVICE_DAEMON_AUTH_TOKEN
export AGENT_DEVICE_DAEMON_AUTH_TOKEN
d_codex
```

Use `d_claude` or `d_copilot` instead as needed. All three Compose files forward these variables. If the device host is a different machine, replace `host.docker.internal` with its reachable address or use an HTTPS tunnel as described in the [remote proxy guide](https://oss.callstack.com/agent-device/docs/remote-proxy).

Ask the agent:

> Use agent-device to connect to the configured proxy, list Android devices and installed apps, open my app, test its navigation, and save screenshots in the project directory. Close the session and disconnect when finished.

Equivalent commands inside the container:

```bash
agent-device connect proxy
agent-device devices --platform android
agent-device apps --platform android
agent-device open com.example.app --platform android
agent-device snapshot -i
agent-device screenshot ./app.png
agent-device close
agent-device disconnect
```

Replace `com.example.app` with the package or bundle ID from `apps`; use `--platform ios` for iOS. Use `agent-device click @e1` and `agent-device fill @e2 "text"` with current snapshot references. Run `agent-device help workflow` for the command guide. No device connection is created by rebuilding the images.

### Agent instructions (optional)

You can provide a Markdown file with custom instructions for the agent:

```bash
AGENTS_MD_PATH=/path/to/instructions.md d_claude
AGENTS_MD_PATH=/path/to/instructions.md d_codex
AGENTS_MD_PATH=/path/to/instructions.md d_copilot
```

The file is mounted read-only into the global instructions location each agent expects:

- Claude: `~/.claude/CLAUDE.md`
- Codex: `~/.codex/AGENTS.md`
- Copilot: `~/.copilot/copilot-instructions.md`

the following aliases can be added:

```bash
alias claude_session='AGENTS_MD_PATH=~/<path to agents file>/AGENTS.md d_claude'
alias codex_session='CODEX_CONFIG_DIR=~/.codex_session AGENTS_MD_PATH=~/<path to agents file>/AGENTS.md d_codex'
alias copilot_session='AGENTS_MD_PATH=~/<path to agents file>/AGENTS.md d_copilot'
```

## Security

- Agents run as a non-root user inside the container.
- Secret files in the working directory (`.env*`, `.npmrc`, `.pypirc`, etc.) are automatically masked — they appear as empty files inside the container.
- To mask additional files per project, create a `.nullmounts` file in the project root with one path per line (relative to the project root). Lines starting with `#` are treated as comments.
  ```
  # .nullmounts example
  secrets.json
  config/api_keys.yml
  ```
- Containers are removed when stopped (`--rm`); Claude/Codex containers stay running after tmux detaches or the CLI exits.

### Statusline customisation

```bash
cp claude/statusline-command.sh ~/.claude/
```

in the local ~/.claude/settings.json add

```json
"statusLine": {
  "type": "command",
  "command": "bash /home/agent/.claude/statusline-command.sh"
},
```
