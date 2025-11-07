# Claude Code OCI Container Images

Container images for running [Claude Code CLI](https://claude.ai/code) in containerized environments. Built with Podman/Docker and available in three variants.

## Images

### Base Image (`claude-code:latest`)
Minimal Debian-based image with Claude Code CLI and Node.js 20.x.

**Includes:**
- Debian Bookworm Slim
- Node.js 20.x
- Claude Code CLI (`@anthropic-ai/claude-code`)
- Git

### Rust Development Image (`claude-code:rust`)
Extends the base image with a complete Rust development environment.

**Additional tools:**
- Rust stable toolchain (rustup)
- Cargo with rustfmt and clippy
- Development tools: cargo-watch, cargo-expand, cargo-audit
- Build essentials (gcc, pkg-config, libssl-dev)

### Rust + WebAssembly Image (`claude-code:rust-wasm`)
Extends the Rust image with WebAssembly tooling for building WASM applications.

**Additional tools:**
- wasm-pack (WebAssembly package builder)
- basic-http-server (static file server for testing WASM applications)

## Building

### Prerequisites
- Podman or Docker installed
- [mise](https://mise.jdx.dev/) (optional, for task runner)

### Build with mise
```bash
# Build base image
mise run build

# Build Rust variant (automatically builds base image first)
mise run build:rust

# Build Rust + WASM variant (automatically builds base and rust images first)
mise run build:rust-wasm
```

### Build with Podman
```bash
# Build base image
podman build -t claude-code:latest .

# Build Rust variant
podman build -f Containerfile.rust -t claude-code:rust .

# Build Rust + WASM variant
podman build -f Containerfile.rust-wasm -t claude-code:rust-wasm .
```

### Build with Docker
```bash
# Build base image
docker build -t claude-code:latest .

# Build Rust variant
docker build -f Containerfile.rust -t claude-code:rust .

# Build Rust + WASM variant
docker build -f Containerfile.rust-wasm -t claude-code:rust-wasm .
```

## Usage

### Running Claude Code
Mount your project directory to `/workspace`:

```bash
# Using Podman
podman run -it --rm \
  -v $(pwd):/workspace \
  claude-code:latest

# Using Docker
docker run -it --rm \
  -v $(pwd):/workspace \
  claude-code:latest
```

Claude Code will prompt you to authenticate interactively on first run.

**Note for SELinux environments (Fedora, RHEL, CentOS):** Add the `:z` flag to volume mounts to properly label them:
```bash
podman run -it --rm \
  -v $(pwd):/workspace:z \
  claude-code:latest
```

### Running with Rust Environment
```bash
podman run -it --rm \
  -v $(pwd):/workspace \
  claude-code:rust
```

### Examples

#### Get help
```bash
podman run -it --rm claude-code:latest --help
```

#### Run Claude Code in current directory
```bash
podman run -it --rm \
  -v $(pwd):/workspace \
  claude-code:latest
```

#### Work on a Rust project
```bash
podman run -it --rm \
  -v $(pwd):/workspace \
  claude-code:rust
```

#### Work on a Rust WebAssembly project
```bash
podman run -it --rm \
  -v $(pwd):/workspace \
  claude-code:rust-wasm
```

#### Develop WASM with live preview (with port mapping)
```bash
# Map container port 4000 to host port 8080
podman run -it --rm \
  -v $(pwd):/workspace \
  -p 8080:4000 \
  claude-code:rust-wasm
```

Then from within Claude Code in the container, you can:
```bash
# Use the built-in web server management agent
/webserver

# Or manually run the server
basic-http-server -a 0.0.0.0:4000 ./pkg
```

The `/webserver` slash command is a specialized Claude agent (built into the rust-wasm image) that helps manage the development server, including starting, stopping, and troubleshooting.

## CI/CD

The repository includes a Gitea Actions workflow that automatically builds and publishes both images on pushes to `main`, `master`, or `test` branches.

Images are tagged with:
- `:latest` / `:rust` / `:rust-wasm` - Latest build from main branch
- `:{commit-sha}` / `:rust-{commit-sha}` / `:rust-wasm-{commit-sha}` - Specific commit builds

## License

See the upstream [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) for license information.
