#!/bin/sh
# Docker helpers for the tun.ko cross-build. Unlike the camera plugin's build (an arm64 image run
# under QEMU), this is a plain x86 image that cross-compiles the module with the ARM toolchain, so
# no --platform is set: the compiler targets aarch64, the container itself stays native and fast.
# When CI sets B3D_CACHE_ARGS it adds the buildx layer-cache flags so the toolchain + kernel-fetch
# layers restore instead of re-downloading; unset locally, so a plain local build is unaffected.

# Build the image from an explicit Dockerfile (arg 2) and build context (arg 3). --load brings the
# result into the local image store so docker_extract (and the vermagic check) can read from it.
docker_image() {
    # shellcheck disable=SC2086
    docker buildx build --load $B3D_CACHE_ARGS -t "$1" -f "$2" "$3"
}

# Copy the image's /out dir into ./dist (relative to the caller's cwd).
docker_extract() {
    mkdir -p dist
    docker create --name "$2" "$1" > /dev/null
    docker cp "$2:/out/." ./dist/
    docker rm "$2" > /dev/null
}
