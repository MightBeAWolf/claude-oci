# syntax=docker/dockerfile:1

FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://gitea.local.wolfbox.dev/gwolf/claude-oci"
LABEL org.opencontainers.image.authors="tgwolf@salishseawolf.com"

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies, Node.js 20.x, Podman (see "Podman config" comment
#    below), and configure npm — one apt-get update/install pass for all of
#    it, since a second update elsewhere would just re-fetch the same index
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        slirp4netns curl ca-certificates git podman runc && \
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

# 3. Install Claude Code (no sudo)
ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# 4. Copy small, frequently-edited local files last (COPY creates destination
#    directories on its own) so editing any one of them doesn't invalidate
#    the apt/curl/npm layers above and force them to re-run.
COPY config.toml /root/.config/mise/config.toml
COPY .bashrc /root/.bashrc
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
COPY agents/mise.md /root/.claude/commands/

# Podman config: vfs storage driver + runc, matching the Gitea CI runner, so
# nested builds (e.g. testing this repo's own Containerfiles from inside the
# running image) work rootless with no extra host capabilities required.
COPY containers/storage.conf /etc/containers/storage.conf
COPY containers/containers.conf /etc/containers/containers.conf

WORKDIR /workspace

# 5. Entrypoint to pass through arguments, preserving env
ENTRYPOINT ["/entrypoint.sh"]

