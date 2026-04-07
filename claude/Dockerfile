FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates ripgrep

ARG UID=1000
ARG GID=1000

RUN getent group ${GID} >/dev/null 2>&1 || groupadd -g ${GID} agent \
    && getent passwd ${UID} >/dev/null 2>&1 || useradd -u ${UID} -g ${GID} -m -s /bin/bash agent \
    && if [ ! -d /home/agent ]; then ln -s "$(getent passwd ${UID} | cut -d: -f6)" /home/agent; fi

USER ${UID}
ENV HOME=/home/agent
ENV PATH=/home/agent/.local/bin:$PATH
WORKDIR /workspace

RUN mkdir -p "${HOME}/.claude" \
    && curl -fsSL https://claude.ai/install.sh | bash

ENTRYPOINT ["bash", "-lc", "claude"]
