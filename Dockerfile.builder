# OpenWrt SDK Builder with pre-installed dependencies
# This image contains the SDK with base packages pre-compiled
FROM debian:bookworm-slim

ARG OPENWRT_VERSION=24.10.0
ARG TARGET=ath79
ARG SUBTARGET=generic

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    gawk \
    gettext \
    git \
    libncurses5-dev \
    libssl-dev \
    python3 \
    rsync \
    unzip \
    wget \
    xz-utils \
    zlib1g-dev \
    zstd \
    && rm -rf /var/lib/apt/lists/*

# Create builder user
RUN useradd -m -s /bin/bash builder
USER builder
WORKDIR /home/builder

# Download and extract SDK
RUN SDK_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${TARGET}/${SUBTARGET}/openwrt-sdk-${OPENWRT_VERSION}-${TARGET}-${SUBTARGET}_gcc-13.3.0_musl.Linux-x86_64.tar.zst" && \
    wget -q "${SDK_URL}" -O sdk.tar.zst && \
    tar --zstd -xf sdk.tar.zst && \
    rm sdk.tar.zst && \
    mv openwrt-sdk-* sdk

WORKDIR /home/builder/sdk

# Download pre-compiled packages for staging directory
RUN mkdir -p tmp_pkgs && \
    PKG_BASE="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/packages/mips_24kc/base" && \
    wget -q "${PKG_BASE}/libubox20240329_2025.07.23~49056d17-r1_mips_24kc.ipk" -O tmp_pkgs/libubox.ipk || true && \
    wget -q "${PKG_BASE}/libubus20250102_2025.10.17~60e04048-r1_mips_24kc.ipk" -O tmp_pkgs/libubus.ipk || true && \
    wget -q "${PKG_BASE}/libuci20250120_2025.01.20~16ff0bad-r1_mips_24kc.ipk" -O tmp_pkgs/libuci.ipk || true && \
    wget -q "${PKG_BASE}/libjson-c5_0.18-r1_mips_24kc.ipk" -O tmp_pkgs/libjson-c.ipk || true && \
    wget -q "${PKG_BASE}/libblobmsg-json20240329_2025.07.23~49056d17-r1_mips_24kc.ipk" -O tmp_pkgs/libblobmsg-json.ipk || true && \
    wget -q "${PKG_BASE}/libiwinfo20230701_2024.10.20~b94f066e-r1_mips_24kc.ipk" -O tmp_pkgs/libiwinfo.ipk || true

# Extract packages to staging directory
RUN STAGING_DIR="staging_dir/target-mips_24kc_musl" && \
    mkdir -p "${STAGING_DIR}/lib" "${STAGING_DIR}/usr/lib" "${STAGING_DIR}/usr/include" && \
    for pkg in tmp_pkgs/*.ipk; do \
        if [ -f "$pkg" ] && [ -s "$pkg" ]; then \
            mkdir -p tmp_extract && \
            cd tmp_extract && \
            ar x "../$pkg" 2>/dev/null && \
            (zstd -d data.tar.zst -o data.tar 2>/dev/null || \
             gzip -d data.tar.gz 2>/dev/null || \
             xz -d data.tar.xz 2>/dev/null || true) && \
            tar xf data.tar 2>/dev/null || true && \
            cd .. && \
            cp -rf tmp_extract/usr/lib/* "${STAGING_DIR}/usr/lib/" 2>/dev/null || true && \
            cp -rf tmp_extract/lib/* "${STAGING_DIR}/lib/" 2>/dev/null || true && \
            rm -rf tmp_extract; \
        fi; \
    done && \
    rm -rf tmp_pkgs

# Download header files from OpenWrt source
RUN mkdir -p staging_dir/target-mips_24kc_musl/usr/include/libubox && \
    cd staging_dir/target-mips_24kc_musl/usr/include && \
    # libubox headers
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/blobmsg.h" -O libubox/blobmsg.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/blobmsg_json.h" -O libubox/blobmsg_json.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/blob.h" -O libubox/blob.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/list.h" -O libubox/list.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/uloop.h" -O libubox/uloop.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/usock.h" -O libubox/usock.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/ustream.h" -O libubox/ustream.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/utils.h" -O libubox/utils.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/avl.h" -O libubox/avl.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/avl-cmp.h" -O libubox/avl-cmp.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/kvlist.h" -O libubox/kvlist.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/vlist.h" -O libubox/vlist.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/safe_list.h" -O libubox/safe_list.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/runqueue.h" -O libubox/runqueue.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/libubox/master/md5.h" -O libubox/md5.h || true && \
    # libubus headers
    wget -q "https://raw.githubusercontent.com/openwrt/ubus/master/libubus.h" -O libubus.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/ubus/master/ubusmsg.h" -O ubusmsg.h || true && \
    # uci headers
    wget -q "https://raw.githubusercontent.com/openwrt/uci/master/uci.h" -O uci.h || true && \
    wget -q "https://raw.githubusercontent.com/openwrt/uci/master/uci_config.h" -O uci_config.h || true

# Verify what we have
RUN echo "=== Libraries ===" && \
    ls -la staging_dir/target-mips_24kc_musl/usr/lib/ 2>/dev/null || echo "No usr/lib" && \
    ls -la staging_dir/target-mips_24kc_musl/lib/ 2>/dev/null || echo "No lib" && \
    echo "=== Headers ===" && \
    ls -la staging_dir/target-mips_24kc_musl/usr/include/ 2>/dev/null || echo "No headers"

WORKDIR /home/builder/sdk
