# syntax=docker/dockerfile:1

FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://docs.anthropic.com/en/docs/claude-code/setup"
LABEL org.opencontainers.image.authors="OpenAI ChatGPT"

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies, Node.js 20.x, and configure npm
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates git && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    # set npm prefix to avoid sudo
    mkdir -p /root/.npm-global && \
    npm config set prefix /root/.npm-global && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=/root/.npm-global/bin:$PATH

# 2. Install Claude Code (no sudo)
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

# 3. Entrypoint to pass through arguments, preserving env
ENTRYPOINT ["claude"]
# CMD ["--help"]

