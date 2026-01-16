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

# 2. Install mise-en-place
RUN curl https://mise.run | sh

ENV PATH=/root/.local/bin:$PATH

# 2a. Configure mise globally
RUN mkdir -p /root/.config/mise
COPY config.toml /root/.config/mise/config.toml

# 2b. Copy shell configuration and entrypoint
COPY .bashrc /root/.bashrc
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 3. Install Claude Code (no sudo)
RUN npm install -g @anthropic-ai/claude-code

# 4. Copy Claude Code agents
RUN mkdir -p /root/.claude/commands
COPY agents/mise.md /root/.claude/commands/

WORKDIR /workspace

# 5. Entrypoint to pass through arguments, preserving env
ENTRYPOINT ["/entrypoint.sh"]
# CMD ["--help"]

