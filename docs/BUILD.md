# Building nodewatcher-agent for OpenWrt

This document describes how the GitHub Actions CI builds nodewatcher-agent packages for OpenWrt 24.10.

## Overview

The build system uses a Docker-based approach with the OpenWrt SDK. Dependencies are compiled from source during the Docker image build phase, which is then cached for subsequent builds.

## Architecture

```
GitHub Actions Workflow
         │
         ▼
┌─────────────────────────────────────┐
│  Dockerfile.builder                 │
│  ┌───────────────────────────────┐  │
│  │ OpenWrt SDK (ath79/generic)   │  │
│  │ + feeds from GitHub mirrors   │  │
│  │ + compiled: libubox, libubus, │  │
│  │   libuci, libjson-c           │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  openwrt/build.sh                   │
│  - Copies source to SDK             │
│  - Runs make package/compile        │
│  - Outputs .ipk files               │
└─────────────────────────────────────┘
         │
         ▼
    packages/*.ipk (artifacts)
```

## Key Files

| File | Purpose |
|------|---------|
| `.github/workflows/build.yml` | GitHub Actions workflow |
| `Dockerfile.builder` | Docker image with SDK and dependencies |
| `openwrt/Makefile` | OpenWrt package definition |
| `openwrt/build.sh` | Build automation script |

## Built Packages

The CI produces the following packages for `mips_24kc` (ath79/generic):

- `nodewatcher-agent` - Main daemon
- `nodewatcher-agent-mod-general` - General system info
- `nodewatcher-agent-mod-resources` - Resource usage monitoring
- `nodewatcher-agent-mod-interfaces` - Network interface info
- `nodewatcher-agent-mod-keys_ssh` - SSH key management
- `nodewatcher-agent-mod-clients` - Connected clients info
- `nodewatcher-agent-mod-routing_babel` - Babel routing info
- `nodewatcher-agent-mod-routing_olsr` - OLSR routing info
- `nodewatcher-agent-mod-meshpoint` - Mesh point sensors

### Disabled Modules

The following modules are currently disabled due to additional dependency requirements:

- `nodewatcher-agent-mod-http_push` - Requires libcurl
- `nodewatcher-agent-mod-wireless` - Requires libiwinfo

These can be enabled by adding the dependencies to the Dockerfile and removing the CMAKE_OPTIONS in `openwrt/Makefile`.

## Problems Solved

### 1. OpenWrt SDK is Not Self-Contained

**Problem:** The OpenWrt SDK does not include pre-compiled base libraries (libubox, libubus, libuci, libjson-c). CMake would fail with `NOTFOUND` errors.

**Solution:** Configure feeds and compile dependencies from source during Docker image build:

```dockerfile
# Configure feeds to use GitHub mirrors
RUN echo 'src-git base https://github.com/openwrt/openwrt.git;openwrt-24.10' > feeds.conf

# Update and install feeds
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install libubox libubus libuci libjson-c

# Build base packages
RUN make package/feeds/base/libubox/compile V=s
RUN make package/feeds/base/ubus/compile V=s
# ... etc
```

### 2. OpenWrt Git Server Unavailable

**Problem:** `git.openwrt.org` was returning HTTP 503 errors, causing feed updates to fail.

**Solution:** Use GitHub mirrors instead:

```
# Instead of:
src-git base https://git.openwrt.org/openwrt/openwrt.git;openwrt-24.10

# Use:
src-git base https://github.com/openwrt/openwrt.git;openwrt-24.10
```

### 3. Nested Makefile Detection

**Problem:** OpenWrt's build system was finding `openwrt/Makefile` inside the copied source and trying to build from there.

**Solution:** Exclude the `openwrt` directory when copying source:

```bash
rsync -a --exclude='openwrt' --exclude='.git' "$SRC_DIR"/ package/nodewatcher-agent/src/
```

### 4. Package Path in Feeds

**Problem:** After feeds install, packages are in `package/feeds/base/<name>`, not `package/<name>`.

**Solution:** Use correct paths for compilation:

```bash
make package/feeds/base/libubox/compile
make package/feeds/base/ubus/compile
```

### 5. Output Directory Permissions

**Problem:** Docker container runs as `builder` user but mounted volume is owned by `runner`.

**Solution:** Create output directory with open permissions before running Docker:

```yaml
- name: Build packages in container
  run: |
    mkdir -p packages
    chmod 777 packages
    docker run --rm -v ${{ github.workspace }}:/src ...
```

## Local Development

To build locally:

```bash
# Build the Docker image
docker build -t nodewatcher-sdk -f Dockerfile.builder .

# Run the build
mkdir -p packages && chmod 777 packages
docker run --rm -v $(pwd):/src nodewatcher-sdk /bin/bash /src/openwrt/build.sh /src

# Packages will be in ./packages/
```

## Adding New Targets

To build for a different target (e.g., `ramips/mt7621`):

1. Update `Dockerfile.builder`:
   ```dockerfile
   ARG TARGET=ramips
   ARG SUBTARGET=mt7621
   ```

2. Update `.github/workflows/build.yml`:
   ```yaml
   env:
     TARGET: "ramips"
     SUBTARGET: "mt7621"
   ```

3. Adjust the staging directory path in Dockerfile if needed.

## Troubleshooting

### Build fails with "No rule to make target"

Check that package paths match the feeds structure. After `./scripts/feeds install`, packages are in `package/feeds/<feed>/<name>/`.

### CMake can't find libraries

Ensure dependencies are compiled before nodewatcher-agent. The Dockerfile should compile libubox, ubus, uci, and libjson-c first.

### Permission denied errors

Make sure the output directory exists and is writable before running the Docker container.

## References

- [OpenWrt SDK Documentation](https://openwrt.org/docs/guide-developer/toolchain/using_the_sdk)
- [OpenWrt Package Development](https://openwrt.org/docs/guide-developer/packages)
- [GitHub Actions Docker](https://docs.github.com/en/actions/creating-actions/creating-a-docker-container-action)
