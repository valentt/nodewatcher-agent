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
│  │   libuci, libjson-c, libcurl  │  │
│  │ + pre-built: libiwinfo        │  │
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
         │
         ▼
    GitHub Release (on tag push)
```

## Key Files

| File | Purpose |
|------|---------|
| `.github/workflows/build.yml` | GitHub Actions workflow |
| `Dockerfile.builder` | Docker image with SDK and dependencies |
| `openwrt/Makefile` | OpenWrt package definition |
| `openwrt/build.sh` | Build automation script |

## Built Packages

The CI produces **11 packages** for `mips_24kc` (ath79/generic):

| Package | Description | Dependencies |
|---------|-------------|--------------|
| `nodewatcher-agent` | Main daemon | libubus, libubox, libjson-c, libuci |
| `nodewatcher-agent-mod-general` | General system info | - |
| `nodewatcher-agent-mod-resources` | Resource usage monitoring | - |
| `nodewatcher-agent-mod-interfaces` | Network interface info | - |
| `nodewatcher-agent-mod-wireless` | Wireless interface info | libiwinfo |
| `nodewatcher-agent-mod-keys_ssh` | SSH key management | - |
| `nodewatcher-agent-mod-clients` | Connected clients info | - |
| `nodewatcher-agent-mod-routing_babel` | Babel routing info | - |
| `nodewatcher-agent-mod-routing_olsr` | OLSR routing info | - |
| `nodewatcher-agent-mod-meshpoint` | Mesh point sensors | - |
| `nodewatcher-agent-mod-http_push` | HTTP push to server | libcurl |

## GitHub Releases

Releases are automatically created when a git tag is pushed:

```bash
# Create and push a release tag
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

GitHub Actions will:
1. Build all packages
2. Create a GitHub Release
3. Attach all .ipk packages as release assets
4. Generate release notes with changelog

## Dependency Management

### Base Libraries (compiled from feeds)

These are compiled from the OpenWrt feeds during Docker image build:

```dockerfile
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install libubox libubus libuci libjson-c curl

RUN make package/feeds/base/libubox/compile V=s
RUN make package/feeds/base/ubus/compile V=s
RUN make package/feeds/base/uci/compile V=s
RUN make package/feeds/base/libjson-c/compile V=s
RUN make package/feeds/packages/curl/compile V=s
```

### libiwinfo (pre-built package + headers)

libiwinfo requires kernel headers to compile, which aren't available in the SDK. Solution: download pre-built package and headers separately.

```dockerfile
# Download pre-built libiwinfo from OpenWrt repositories
RUN wget -q "https://downloads.openwrt.org/.../libiwinfo20230701_*.ipk" && \
    tar xzf libiwinfo.ipk && tar xzf data.tar.gz && \
    cp -av usr/lib/libiwinfo.so* ${STAGING}/usr/lib/ && \
    ln -sf libiwinfo.so.20230701 ${STAGING}/usr/lib/libiwinfo.so

# Download headers from source repository
RUN wget -q "https://raw.githubusercontent.com/openwrt/iwinfo/.../iwinfo.h" \
    -O ${STAGING}/usr/include/iwinfo.h
```

### libcurl (compiled from feeds)

libcurl must be compiled from the packages feed to ensure ABI compatibility with the SDK toolchain. Pre-built packages have ABI issues.

```dockerfile
RUN ./scripts/feeds install curl
RUN make package/feeds/packages/curl/compile V=s
```

## Problems Solved

### 1. OpenWrt SDK is Not Self-Contained

**Problem:** The OpenWrt SDK does not include pre-compiled base libraries (libubox, libubus, libuci, libjson-c). CMake would fail with `NOTFOUND` errors.

**Solution:** Configure feeds and compile dependencies from source during Docker image build.

### 2. OpenWrt Git Server Unavailable

**Problem:** `git.openwrt.org` was returning HTTP 503 errors, causing feed updates to fail.

**Solution:** Use GitHub mirrors instead:

```
src-git base https://github.com/openwrt/openwrt.git;openwrt-24.10
src-git packages https://github.com/openwrt/packages.git;openwrt-24.10
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
make package/feeds/base/libubox/compile   # base feed
make package/feeds/packages/curl/compile  # packages feed
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

### 6. OpenWrt 24.10 ipk Format Change

**Problem:** OpenWrt 24.10 changed the .ipk package format from `ar` archive to `tar.gz`.

**Solution:** Extract using tar instead of ar:

```bash
# Old format (ar):
ar x package.ipk && tar xzf data.tar.gz

# New format (tar.gz):
tar xzf package.ipk && tar xzf data.tar.gz
```

### 7. libiwinfo Requires Kernel Headers

**Problem:** libiwinfo cannot be compiled in the SDK because it requires kernel headers that aren't included.

**Solution:** Download pre-built libiwinfo package from OpenWrt repositories and headers from the source repo.

### 8. libcurl ABI Compatibility

**Problem:** Pre-built libcurl packages have ABI compatibility issues with the SDK toolchain ("file in wrong format" linker error).

**Solution:** Compile libcurl from the packages feed instead of using pre-built packages.

### 9. const Qualifier Mismatch in wireless.c

**Problem:** OpenWrt 24.10's iwinfo library changed `IWINFO_OPMODE_NAMES` type from `const char **` to `const char * const *`.

**Solution:** Update function signature in `modules/wireless.c`:

```c
// Old:
static void nw_wireless_call_int(..., const char **map)

// New:
static void nw_wireless_call_int(..., const char * const *map)
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

3. Update the libiwinfo package URL in Dockerfile to match the new architecture.

4. Rebuild the Docker image (dependencies need to be recompiled for the new target).

## Troubleshooting

### Build fails with "No rule to make target"

Check that package paths match the feeds structure:
- Base packages: `package/feeds/base/<name>/`
- Extra packages: `package/feeds/packages/<name>/`

### CMake can't find libraries

Ensure dependencies are compiled before nodewatcher-agent. Check that symlinks exist:
```bash
ls -la staging_dir/target-*/usr/lib/libcurl.so
ls -la staging_dir/target-*/usr/lib/libiwinfo.so
```

### Permission denied errors

Make sure the output directory exists and is writable before running the Docker container.

### "file in wrong format" linker error

This indicates ABI incompatibility. The library was compiled for a different toolchain. Solution: compile the library from feeds instead of using pre-built packages.

### const qualifier warnings/errors

OpenWrt 24.10 updated some library APIs. Check for type changes in header files and update the code accordingly.

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v1.0.0 | 2024-12-23 | Initial release with 9 modules |
| v1.1.0 | 2024-12-23 | Added wireless and http_push modules (11 total) |

## References

- [OpenWrt SDK Documentation](https://openwrt.org/docs/guide-developer/toolchain/using_the_sdk)
- [OpenWrt Package Development](https://openwrt.org/docs/guide-developer/packages)
- [GitHub Actions Docker](https://docs.github.com/en/actions/creating-actions/creating-a-docker-container-action)
- [libiwinfo source](https://github.com/openwrt/iwinfo)
- [curl source](https://github.com/curl/curl)
