#!/bin/bash
# Build nodewatcher-agent packages for OpenWrt
set -e

SRC_DIR="${1:-/src}"
SDK_DIR="${2:-/home/builder/sdk}"

cd "$SDK_DIR"

# Create package directory structure
mkdir -p package/nodewatcher-agent/src

# Copy source code (excluding openwrt directory to avoid nested package detection)
rsync -a --exclude='openwrt' --exclude='.git' --exclude='.github' "$SRC_DIR"/ package/nodewatcher-agent/src/

# Copy OpenWrt Makefile to package root
cp "$SRC_DIR/openwrt/Makefile" package/nodewatcher-agent/Makefile

# Configure packages
cat >> .config << 'CONFIGEOF'
CONFIG_SIGNED_PACKAGES=n
CONFIG_PACKAGE_nodewatcher-agent=m
CONFIG_PACKAGE_nodewatcher-agent-mod-general=m
CONFIG_PACKAGE_nodewatcher-agent-mod-resources=m
CONFIG_PACKAGE_nodewatcher-agent-mod-interfaces=m
CONFIG_PACKAGE_nodewatcher-agent-mod-keys_ssh=m
CONFIG_PACKAGE_nodewatcher-agent-mod-clients=m
CONFIG_PACKAGE_nodewatcher-agent-mod-routing_babel=m
CONFIG_PACKAGE_nodewatcher-agent-mod-routing_olsr=m
CONFIG_PACKAGE_nodewatcher-agent-mod-meshpoint=m
CONFIGEOF

make defconfig

# Build with verbose output, fallback to single thread on error
make package/nodewatcher-agent/compile V=s -j$(nproc) || make package/nodewatcher-agent/compile V=s -j1

# Copy results to output directory
mkdir -p "$SRC_DIR/packages"
find bin -name "nodewatcher*.ipk" -exec cp {} "$SRC_DIR/packages/" \;

echo "=== Built packages ==="
ls -la "$SRC_DIR/packages/"
