#!/bin/bash
# Builds just the cross toolchain for BOARD_NAME (via the matching
# *_toolchain_defconfig) and packages it as a relocatable tarball.
#
# Deliberately does NOT use `make sdk`/`make prepare-sdk`: those Make targets
# depend on `world` (the full target-package/kernel/rootfs build), which would
# defeat the entire point of a fast, toolchain-only producer build. Instead
# this hand-replicates prepare-sdk's actual recipe body -- installing
# relocate-sdk.sh and generating the sdk-location/sdk-relocs metadata it
# requires -- directly against $(HOST_DIR) after `make toolchain`.
set -euo pipefail

: "${BOARD_NAME:?BOARD_NAME must be set}"
BR_DIR=/app/buildroot
OUT_DIR="$BR_DIR/output/${BOARD_NAME}"
HOST_DIR="$OUT_DIR/host"

make -C "$BR_DIR" BR2_EXTERNAL=../avio_configs/ O="output/${BOARD_NAME}" "${BOARD_NAME}_toolchain_defconfig"
make -C "$OUT_DIR" toolchain

install -m 755 "$BR_DIR/support/misc/relocate-sdk.sh" "$HOST_DIR/relocate-sdk.sh"
mkdir -p "$HOST_DIR/share/buildroot"
(
	export LC_ALL=C
	grep -lr "$HOST_DIR" "$HOST_DIR" | while read -r FILE; do
		if file -b --mime-type "$FILE" | grep -q '^text/' \
			&& [ "$FILE" != "$HOST_DIR/share/buildroot/sdk-location" ] \
			&& [ "$FILE" != "$HOST_DIR/share/buildroot/sdk-relocs" ]; then
			echo "$FILE"
		fi
	done
) | sed -e "s|^$HOST_DIR|.|g" > "$HOST_DIR/share/buildroot/sdk-relocs"
echo "$HOST_DIR" > "$HOST_DIR/share/buildroot/sdk-location"

mkdir -p /app/images
tar czf "/app/images/toolchain-${BOARD_NAME}.tar.gz" -C "$HOST_DIR" .
