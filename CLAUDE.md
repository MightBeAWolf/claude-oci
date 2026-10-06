# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository provides OCI container images for running Claude Code CLI in containerized environments. It includes three image variants built on top of each other:

1. **Base image** (`claude-code:latest`) - Debian Bookworm Slim + Node.js 20.x + Claude Code CLI
2. **Rust image** (`claude-code:rust`) - Base + Rust toolchain + cargo development tools
3. **Rust WASM image** (`claude-code:rust-wasm`) - Rust + wasm-pack + basic-http-server + custom `/webserver` agent

## Build System

### Building Images

Use mise task runner (preferred) or Podman/Docker directly:

```bash
# Build base image
mise run build

# Build Rust variant (automatically builds base first)
mise run build:rust

# Build Rust + WASM variant (automatically builds base and rust first)
mise run build:rust-wasm
```

Or with Podman directly:
```bash
podman build -t claude-code:latest .
podman build -f Containerfile.rust -t claude-code:rust .
podman build -f Containerfile.rust-wasm -t claude-code:rust-wasm .
```

### Image Architecture

The images follow a layered architecture:
- `Containerfile` → base image with Claude Code
- `Containerfile.rust` → FROM base, adds Rust tooling
- `Containerfile.rust-wasm` → FROM rust, adds WASM tools + custom agents

The mise tasks enforce this dependency chain automatically.

## Custom Claude Code Agents

This repository includes custom Claude Code agents that provide specialized capabilities:

### `/mise` Agent (all images)
Available in the base image and all variants. Provides comprehensive assistance with:
- Tool version management (installing, switching, upgrading runtimes)
- Task execution and definition (TOML-based and file-based tasks)
- Configuration management (creating and modifying mise.toml)
- Environment setup and troubleshooting

Location: `agents/mise.md` → `/root/.claude/commands/mise.md`

### `/webserver` Agent (rust-wasm image only)
Available only in the rust-wasm image. Provides specialized capabilities for:
- Managing basic-http-server during WASM development
- Starting, stopping, and checking server status
- Port configuration and troubleshooting

Location: `agents/webserver.md` → `/root/.claude/commands/webserver.md`

### Adding New Agents

When modifying or adding new agents:
- Place agent definition files in `agents/` directory
- Copy them to `/root/.claude/commands/` in the appropriate Containerfile
- Agents are markdown files with YAML frontmatter describing their purpose
- Use existing agents as templates for structure and patterns
- Agents copied in the base image are inherited by all variants

## CI/CD Pipeline

Two parallel workflows, kept in sync by convention, each with a `lint` job followed by a `build-and-push` job:

- **Gitea Actions** (`.gitea/workflows/build-and-push.yml`) — uses Podman, pushes to the Gitea Container Registry.
- **GitHub Actions** (`.github/workflows/build-and-push.yml`) — uses Docker/Buildx, pushes to `ghcr.io`.

Both trigger on push and pull_request to `main`, `master`, or `test`.

Key workflow details:
- `lint` job runs [hadolint](https://github.com/hadolint/hadolint) against all three Containerfiles (matrix job), using the shared `.hadolint.yaml` config. Runs on every push and pull request.
- hadolint's version is declared in `mise.toml` (`[tools] hadolint`), installed in CI via `jdx/mise-action@v2` — bump the version there, not in the workflow files.
- `build-and-push` job `needs: lint` and is gated to `github.event_name == 'push'` (no publishing from pull requests).
- Builds all three images in dependency order: base, rust, and rust-wasm, with a `--version` smoke test after each build, before any registry login or push.
- Tags images with both `:latest`/`:rust`/`:rust-wasm` and commit SHA (`:$SHA`, `:rust-$SHA`, `:rust-wasm-$SHA`).
- Local build tags are always `claude-code:*`, independent of this repo's own name, because `Containerfile.rust` and `Containerfile.rust-wasm` hardcode `FROM claude-code:...`. The GitHub workflow builds locally with Buildx's `load: true` to preserve this, then separately tags/pushes the `ghcr.io/<owner>/<repo>` (lowercased) names.
- Don't add a `docker/setup-buildx-action` step to the GitHub workflow. It creates a builder on the `docker-container` driver, which runs BuildKit in an isolated container with no view of the host Docker Engine's image store — a `FROM claude-code:...` in a later build then resolves as a registry pull instead of the earlier `load: true` image, and fails since `claude-code` doesn't exist on Docker Hub. `docker/build-push-action` works fine against the runner's preinstalled default (`docker`-driver) builder, which shares the engine's image store — no explicit buildx setup needed.
- Gitea pushes using the `PACKAGE_REGISTRY_TOKEN` secret; GitHub pushes using the built-in `GITHUB_TOKEN` (requires the repo's Actions settings to grant it package write access).

Whenever a Containerfile changes (`Containerfile`, `Containerfile.rust`, `Containerfile.rust-wasm`), run hadolint locally before committing, mirroring the CI `lint` job: `mise install` (installs the version pinned in `mise.toml`) then `hadolint --config .hadolint.yaml <file>` for each changed file. Fix findings or extend `.hadolint.yaml`'s `ignored` list with a reasoning comment, rather than letting CI catch it.

If modifying either workflow:
- Keep the `lint` → `build-and-push` structure and the `.hadolint.yaml` ignore list in sync between both files unless there's a reason for them to diverge.
- Podman configuration (Gitea runner) uses custom `storage.conf` and `containers.conf` for rootless builds
- The VFS storage driver is slower but more compatible with CI environments
- Build steps reference `github.event.repository.name` for image naming

## Testing Images

After building, test images by mounting a project directory to `/workspace`:

```bash
# Test base image
podman run -it --rm -v $(pwd):/workspace claude-code:latest

# Test Rust image
podman run -it --rm -v $(pwd):/workspace claude-code:rust

# Test WASM image with port mapping (container port 4000 → host port 8080)
podman run -it --rm -v $(pwd):/workspace -p 8080:4000 claude-code:rust-wasm
```

On SELinux systems (Fedora, RHEL, CentOS), add `:z` to volume mounts: `-v $(pwd):/workspace:z`

## Important Notes

- All images use `/workspace` as the working directory
- The entrypoint is `/entrypoint.sh` which activates mise and launches Claude Code, so container arguments pass directly to Claude Code
- **mise is pre-activated**: The mise environment is automatically activated via both the entrypoint wrapper and `.bashrc` for interactive shells, and mise's shims directory (`/root/.local/share/mise/shims`) is permanently on `PATH` via the base Containerfile. The shims are what matter for Claude Code itself: its Bash tool spawns non-interactive subprocesses that never source `.bashrc` or trigger the `mise activate` hook, so without the shims on `PATH`, tools installed mid-session (e.g. via `mise use`) would be invisible to subsequent tool calls
- **mise global configuration**: Located at `/root/.config/mise/config.toml` with auto-install enabled and telemetry disabled
- Environment paths are configured for npm global packages (`/root/.npm-global/bin`), mise (`/root/.local/bin`), and Rust cargo (`/root/.cargo/bin`)
- The rust image includes development tools: cargo-watch, cargo-expand, cargo-audit
- The WASM image's webserver agent expects basic-http-server to bind to `0.0.0.0:4000` by default
- **Podman is included in every image** for nested builds (e.g. test-building this repo's own Containerfiles from inside the running container). It's configured via `containers/storage.conf` (`vfs` driver) and `containers/containers.conf` (`runc` runtime, `cgroupfs` manager) to match the CI runner's unprivileged setup — no `--privileged` or extra host capabilities needed
