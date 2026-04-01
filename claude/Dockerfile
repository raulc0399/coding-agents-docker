FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000

RUN getent group ${GID} >/dev/null 2>&1 || groupadd -g ${GID} agent \
    && getent passwd ${UID} >/dev/null 2>&1 || useradd -u ${UID} -g ${GID} -m -s /bin/bash agent

USER ${UID}

RUN curl -fsSL https://claude.ai/install.sh | bash
WORKDIR /workspace

ENV PATH="$HOME/.local/bin:$PATH"

ENTRYPOINT ["claude"]
