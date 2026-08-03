#!/bin/bash
# Builds webkitgtk (the single most expensive package in the board build --
# observed at ~4h of a 6h GitHub Actions timeout on its own) against the real
# consumer BOARD_NAME_defconfig, then packages the resulting output tree as a
# tarball. The main "Build images" workflow restores this tarball into
# output/$BOARD_NAME before running its own `make`, so Buildroot's normal
# stamp-file incremental-build logic sees webkitgtk (and everything it depends
# on) as already built and skips straight to the remaining packages/kernel/image.
#
# Deliberately reuses the real BOARD_NAME_defconfig (not the toolchain-only
# defconfig) and the prebuilt external toolchain at /app/toolchains/$BOARD_NAME
# (downloaded by the caller workflow, same as the main build), so the output
# tree this produces is byte-for-byte what the main build would have produced
# up to this point -- no path relocation needed since both runs use the
# identical /app/buildroot/output/$BOARD_NAME layout.
# If the caller workflow downloaded a "Build LLVM" prebuild (see
# build-llvm-prebuilt.sh -- currently only produced for generic-x86_64,
# where BR2_PACKAGE_MESA3D_LLVM makes host-llvm + llvm alone take ~4h from
# cold), restore it first so this build's own `make webkitgtk` doesn't
# rebuild llvm on top of WebKitGTK's own ~5h and blow past GitHub Actions'
# 6h-per-job ceiling.
set -euo pipefail

: "${BOARD_NAME:?BOARD_NAME must be set}"
BR_DIR=/app/buildroot

if [ -f "/app/llvm-${BOARD_NAME}.tar.gz" ]; then
	tar xzf "/app/llvm-${BOARD_NAME}.tar.gz" -C "$BR_DIR"
fi

make -C "$BR_DIR" BR2_EXTERNAL=../avio_configs/ O="output/${BOARD_NAME}" "${BOARD_NAME}_defconfig"
make -C "$BR_DIR/output/${BOARD_NAME}" webkitgtk

mkdir -p /app/images
TARBALL="/app/images/webkitgtk-${BOARD_NAME}.tar.gz"
tar czf "$TARBALL" -C "$BR_DIR" "output/${BOARD_NAME}"

# GitHub release assets are capped at 2GiB each and the full output tree
# (WebKit's build objects included) blows past that easily, so split into
# chunks the caller workflow re-concatenates before extracting.
split -b 1800M "$TARBALL" "${TARBALL}.part-"
rm -f "$TARBALL"
