# syntax=docker/dockerfile:1

FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://gitea.local.wolfbox.dev/gwolf/claude-oci"
LABEL org.opencontainers.image.authors="tgwolf@salishseawolf.com"

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies, Node.js 20.x, and configure npm
RUN apt-get update && \
    apt-get install -y --no-install-recommends slirp4netns curl ca-certificates git && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    # set npm prefix to avoid sudo
    mkdir -p /root/.npm-global && \
    npm config set prefix /root/.npm-global && \
    rm -rf /var/lib/apt/lists/*

ENV PATH=/root/.npm-global/bin:$PATH

# 2. Install mise-en-place
RUN curl https://mise.run | sh && \
    mkdir -p /root/.local/share/mise/shims

# Shims (not just `mise activate`) are required so mise-managed tools are
# resolvable by non-interactive subprocesses, e.g. Claude Code's own Bash
# tool calls, which don't source .bashrc or trigger the activate hook.
ENV PATH=/root/.local/share/mise/shims:/root/.local/bin:$PATH

# 2a. Configure mise globally
RUN mkdir -p /root/.config/mise
COPY config.toml /root/.config/mise/config.toml

# 2b. Copy shell configuration and entrypoint
COPY .bashrc /root/.bashrc
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 3. Install Claude Code (no sudo)
ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# 4. Copy Claude Code agents (COPY creates the destination directory)
COPY agents/mise.md /root/.claude/commands/

# 5. Install Podman for nested image builds (e.g. testing this repo's own
# Containerfiles from inside the running image). Configured with the vfs
# storage driver and runc, matching the Gitea CI runner, so it runs
# unprivileged with no extra host capabilities required.
RUN apt-get update && \
    apt-get install -y --no-install-recommends podman runc && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/containers
COPY containers/storage.conf /etc/containers/storage.conf
COPY containers/containers.conf /etc/containers/containers.conf

WORKDIR /workspace

# 6. Entrypoint to pass through arguments, preserving env
ENTRYPOINT ["/entrypoint.sh"]

