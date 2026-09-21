FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates gnupg ripgrep jq less unzip make poppler-utils \
    php-cli composer \
    python3 python3-pip python3-venv

RUN curl -fsSL https://aka.ms/InstallAzureCLIDeb -o /tmp/install-azure-cli.sh \
    && bash /tmp/install-azure-cli.sh \
    && rm /tmp/install-azure-cli.sh

RUN curl -fsSL https://apt.releases.hashicorp.com/gpg -o /tmp/hashicorp.asc \
    && gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg /tmp/hashicorp.asc \
    && . /etc/os-release \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y --no-install-recommends terraform \
    && rm /tmp/hashicorp.asc

ARG UID=1000
ARG GID=1000

RUN getent group ${GID} >/dev/null 2>&1 || groupadd -g ${GID} agent \
    && getent passwd ${UID} >/dev/null 2>&1 || useradd -u ${UID} -g ${GID} -m -s /bin/bash agent \
    && if [ ! -d /home/agent ]; then ln -s "$(getent passwd ${UID} | cut -d: -f6)" /home/agent; fi

USER ${UID}
ENV HOME=/home/agent
ENV PATH=/home/agent/.local/bin:$PATH
WORKDIR /workspace

RUN mkdir -p "${HOME}/.codex" \
    && npm config set prefix "${HOME}/.local" \
    && npm install -g @openai/codex typescript tsx \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && uv tool install ruff@latest

COPY --chown=${UID}:${GID} entrypoint.sh /usr/local/bin/codex-entrypoint
RUN chmod +x /usr/local/bin/codex-entrypoint

ENTRYPOINT ["codex-entrypoint"]
