#!/bin/bash
# Builds host-llvm + llvm (needed by BR2_PACKAGE_MESA3D_LLVM: radeonsi's
# runtime shader compiler is genuinely LLVM-based, and crocus/iris need
# LLVM to build their host-side mesa-clc precompiler tool) against the real
# consumer BOARD_NAME_defconfig, then packages the resulting output tree as
# a tarball. build-webkitgtk-prebuilt.sh restores this into output/
# $BOARD_NAME before its own `make webkitgtk`, so Buildroot's stamp-file
# incremental-build logic sees llvm as already built and skips straight to
# the mesa3d/webkitgtk dependency chain.
#
# This exists as its own producer (not just folded into build-webkitgtk-
# prebuilt.sh) because host-llvm + llvm alone take ~4h from cold on top of
# WebKitGTK's own ~5h -- combined, that blows straight through GitHub
# Actions' hard 6h-per-job ceiling on hosted runners even before WebKitGTK's
# own build starts. Splitting it into its own job gives it a full
# independent 6h budget instead of sharing WebKitGTK's.
#
# Reuses the real BOARD_NAME_defconfig (not the toolchain-only defconfig)
# and the prebuilt external toolchain at /app/toolchains/$BOARD_NAME
# (downloaded by the caller workflow, same as the main build), so the
# output tree this produces is byte-for-byte what the main build would
# have produced up to this point -- no path relocation needed since both
# runs use the identical /app/buildroot/output/$BOARD_NAME layout.
set -euo pipefail

: "${BOARD_NAME:?BOARD_NAME must be set}"
BR_DIR=/app/buildroot

make -C "$BR_DIR" BR2_EXTERNAL=../avio_configs/ O="output/${BOARD_NAME}" "${BOARD_NAME}_defconfig"
make -C "$BR_DIR/output/${BOARD_NAME}" host-llvm llvm

mkdir -p /app/images
TARBALL="/app/images/llvm-${BOARD_NAME}.tar.gz"
tar czf "$TARBALL" -C "$BR_DIR" "output/${BOARD_NAME}"

# GitHub release assets are capped at 2GiB each - split defensively like
# webkitgtk's prebuild does, in case LLVM's build tree (all targets/backends,
# both host and cross copies) ends up larger than expected.
split -b 1800M "$TARBALL" "${TARBALL}.part-"
rm -f "$TARBALL"
