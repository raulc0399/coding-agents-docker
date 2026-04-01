FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

ARG UID=1000
ARG GID=1000

RUN groupadd -g ${GID} agent && useradd -u ${UID} -g ${GID} -m -s /bin/bash agent

USER agent
WORKDIR /workspace

ENTRYPOINT ["claude"]
