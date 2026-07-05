# Cross-build tun.ko for the Snapmaker U1's exact kernel (Linux 6.1.99 aarch64, Rockchip RK3562
# BSP). This is a MODULE build against the stock kernel source point, NOT a kernel rebuild: the .ko
# is a loadable artifact whose vermagic (6.1.99 SMP preempt mod_unload aarch64) is what the running
# kernel's insmod accepts. See plugins/networking/doc/recon-kernel-vpn.md for why this is buildable
# (MODVERSIONS off so no Module.symvers, we hold junior's exact .config, the source is the public RK
# BSP that carries this reference board's DTS).
#
# x86 host + the ARM 10.3-2021.07 aarch64-none-linux-gnu cross-toolchain (junior's exact kernel
# compiler, per its CONFIG_CC_VERSION_TEXT), so the compiler matches exactly. The camera plugin's
# toolchain is the model for the Docker + pack + CI shape; a kernel module cross-compiles from an
# x86 host, the inverse of the camera's arm64-under-QEMU. Pinned to linux/amd64 so the x86_64
# toolchain runs: native on the CI x86 runner, emulated (Rosetta) on an Apple-Silicon dev box.
FROM --platform=linux/amd64 debian:bookworm

# Kernel-module build deps (bc/bison/flex/libssl/libelf) + fetch/extract tools + kmod for modinfo.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential bc bison flex libssl-dev libelf-dev \
    git wget xz-utils ca-certificates kmod \
    && rm -rf /var/lib/apt/lists/*

# The ARM GNU 10.3-2021.07 aarch64-none-linux-gnu cross-toolchain: junior's exact kernel compiler.
# Its own layer so a .config edit never re-downloads it.
ARG TOOLCHAIN_URL=https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/10.3-2021.07/binrel/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu.tar.xz
RUN wget -q -O /tmp/toolchain.tar.xz "$TOOLCHAIN_URL" \
    && mkdir -p /opt/toolchain \
    && tar -C /opt/toolchain --strip-components=1 -xf /tmp/toolchain.tar.xz \
    && rm /tmp/toolchain.tar.xz
ENV PATH=/opt/toolchain/bin:$PATH
ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-none-linux-gnu-

# The RK BSP kernel source at the commit Snapmaker ACTUALLY ships (develop-6.1 @ 8533b2249e15, a
# Jan-2025 develop-6.1 commit), taken from the community Extended Firmware's vars.mk (it runs
# Tailscale over kernel tun on this exact hardware). NOT the commit literally tagged "Linux 6.1.99"
# (cac15753, Jul-2024): the develop-6.1 branch never bumps the sublevel, so both report vermagic
# 6.1.99 and both load, but six months of BSP commits apart means their net-stack structs differ, and
# with MODVERSIONS off there is no symbol-CRC to catch it. The tagged commit's tun.ko loads then fails
# register_netdevice (ethtool_check_ops WARN) at TUNSETIFF; 8533b224 was proven end-to-end on junior
# (ip tuntap add succeeds, tailscaled brings up a live tailscale0). A shallow single-commit fetch, not
# a full clone; .git is dropped so setlocalversion adds no -g<sha> suffix (junior's UTS_RELEASE is
# plain 6.1.99 despite LOCALVERSION_AUTO=y).
ARG KERNEL_REF=8533b2249e1550b233a4836d039d64e3bb2fed7a
RUN git init /kernel \
    && cd /kernel \
    && git remote add origin https://github.com/rockchip-linux/kernel.git \
    && git fetch --depth 1 origin "$KERNEL_REF" \
    && git checkout FETCH_HEAD \
    && rm -rf /kernel/.git
WORKDIR /kernel

# Junior's exact running .config with CONFIG_TUN flipped to =m. olddefconfig resolves the one new
# symbol's deps without touching anything else, so every vermagic-bearing option (SMP / PREEMPT /
# MODULE_UNLOAD) stays as junior has it. A single-target module build (drivers/net/tun.ko), not a
# full `make modules`: only tun.o plus core headers, nothing else in junior's large module set.
COPY junior-6.1.99.config /kernel/.config
RUN scripts/config --module TUN \
    && make olddefconfig \
    && make -j"$(nproc)" modules_prepare \
    && make -j"$(nproc)" drivers/net/tun.ko \
    && mkdir -p /out \
    && cp drivers/net/tun.ko /out/tun.ko \
    && echo "== built tun.ko ==" \
    && modinfo -F vermagic /out/tun.ko
