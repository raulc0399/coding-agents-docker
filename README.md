# Coding Agents Docker

Run AI coding agents (Claude, Codex, Copilot) in isolated Docker containers with your current working directory mounted as `/workspace`.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Docker Compose
- Bash

## Installation

1. Clone the repository:
   ```bash
   git clone <repo-url>
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
```

The current working directory is automatically mounted as `/workspace` inside the container.

### Agent instructions (optional)

You can provide a Markdown file with custom instructions for the agent:

```bash
AGENT_MD_PATH=/path/to/instructions.md d_claude
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
- Containers are removed after each run (`--rm`).
