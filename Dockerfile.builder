# OpenWrt SDK Builder with dependencies compiled from source
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
    file \
    gawk \
    gettext \
    git \
    libncurses5-dev \
    libssl-dev \
    ninja-build \
    python3 \
    python3-distutils \
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

# Configure feeds to use GitHub mirrors instead of git.openwrt.org
RUN echo 'src-git base https://github.com/openwrt/openwrt.git;openwrt-24.10' > feeds.conf && \
    echo 'src-git packages https://github.com/openwrt/packages.git;openwrt-24.10' >> feeds.conf && \
    echo 'src-git luci https://github.com/openwrt/luci.git;openwrt-24.10' >> feeds.conf

# Update and install feeds
RUN ./scripts/feeds update -a && \
    ./scripts/feeds install libubox libubus libuci libjson-c libiwinfo

# Configure to build base packages as modules
RUN cat >> .config << 'EOF'
CONFIG_SIGNED_PACKAGES=n
CONFIG_PACKAGE_libubox=m
CONFIG_PACKAGE_libubus=m
CONFIG_PACKAGE_libuci=m
CONFIG_PACKAGE_libjson-c=m
CONFIG_PACKAGE_libblobmsg-json=m
CONFIG_PACKAGE_libiwinfo=m
EOF

RUN make defconfig

# Build base packages (this populates staging_dir with headers and libs)
# Feeds install to package/feeds/base/<name>
RUN make package/feeds/base/libubox/compile V=s -j$(nproc) || make package/feeds/base/libubox/compile V=s -j1
RUN make package/feeds/base/ubus/compile V=s -j$(nproc) || make package/feeds/base/ubus/compile V=s -j1
RUN make package/feeds/base/uci/compile V=s -j$(nproc) || make package/feeds/base/uci/compile V=s -j1
RUN make package/feeds/base/libjson-c/compile V=s -j$(nproc) || make package/feeds/base/libjson-c/compile V=s -j1

# Download pre-built libiwinfo packages and extract to staging_dir
# libiwinfo requires kernel headers to compile, so we use pre-built packages instead
# Note: OpenWrt 24.10 uses tar.gz format for .ipk (not ar format)
RUN ARCH="mips_24kc" && \
    PKG_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/packages/${ARCH}/base" && \
    mkdir -p /tmp/iwinfo && cd /tmp/iwinfo && \
    wget -q "${PKG_URL}/libiwinfo20230701_2024.10.20~b94f066e-r1_mips_24kc.ipk" -O libiwinfo.ipk && \
    tar xzf libiwinfo.ipk && \
    tar xzf data.tar.gz && \
    STAGING=$(ls -d /home/builder/sdk/staging_dir/target-* | head -1) && \
    cp -av usr/lib/libiwinfo.so* ${STAGING}/usr/lib/ && \
    cd /home/builder/sdk && rm -rf /tmp/iwinfo

# Download libiwinfo header from source repository
RUN STAGING=$(ls -d staging_dir/target-* | head -1) && \
    mkdir -p ${STAGING}/usr/include/iwinfo && \
    wget -q "https://raw.githubusercontent.com/openwrt/iwinfo/b94f066e3f5839b8509483cdd8f4f582a45fa233/include/iwinfo.h" \
         -O ${STAGING}/usr/include/iwinfo.h && \
    wget -q "https://raw.githubusercontent.com/openwrt/iwinfo/b94f066e3f5839b8509483cdd8f4f582a45fa233/include/iwinfo/utils.h" \
         -O ${STAGING}/usr/include/iwinfo/utils.h && \
    echo "=== iwinfo headers installed ===" && ls -la ${STAGING}/usr/include/iwinfo*

# Verify staging_dir has what we need
RUN echo "=== Staging dir libs ===" && \
    ls -la staging_dir/target-*/usr/lib/ 2>/dev/null | head -30 || echo "No libs found" && \
    echo "=== Staging dir includes ===" && \
    ls -la staging_dir/target-*/usr/include/ 2>/dev/null | head -20 || echo "No includes found"

WORKDIR /home/builder/sdk
