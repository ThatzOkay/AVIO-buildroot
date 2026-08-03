#!/bin/bash

set -u
set -e
set -x

TMP=$(mktemp -d)
BOARD_DIR="$(dirname "$0")"

LATEST=$(curl -s https://api.github.com/repos/ThatzOkay/AVIO/releases \
  | jq -r '.[0].assets[] | select(.name | endswith(".deb") and contains("amd64") and contains("buildroot")) | .browser_download_url')

curl -L -o "$TMP/avio.deb" "$LATEST"

cd "$TMP"
ar x avio.deb
DATA_TAR=$(ar t avio.deb | grep '^data\.tar')
tar -xf "$DATA_TAR"

install -Dm755 usr/bin/avio "$1/usr/bin/avio"
install -Dm755 usr/bin/gst-host "$1/usr/bin/gst-host"
cp -r usr/lib/avio "$1/usr/lib/"
[ -d usr/share/applications ] && cp -r usr/share/applications "$1/usr/share/"
[ -d usr/share/icons ] && cp -r usr/share/icons "$1/usr/share/"

rm -rf "$TMP"

# The prebuilt avio binary was linked against librtlsdr's SONAME major
# version 2, but the librtlsdr commit Buildroot's package pins (in the
# buildroot/ submodule, not ours to patch) only produces .so.0 --
# confirmed on a live image that the library is otherwise ABI-compatible
# (avio resolves and loads every symbol against it fine), so just add
# the missing SONAME symlink rather than bumping/patching the package.
RTLSDR_SO=$(basename "$(readlink -f "$1/usr/lib/librtlsdr.so.0")")
ln -sf "$RTLSDR_SO" "$1/usr/lib/librtlsdr.so.2"

# Wire up GRUB for both BIOS and EFI boot: the EFI core image reads its
# grub.cfg from the ESP itself, the BIOS core image reads its grub.cfg
# from /boot/grub on the rootfs (see BR2_TARGET_GRUB2_BOOT_PARTITION).
install -Dm644 "$BOARD_DIR/grub-bios.cfg" "$1/boot/grub/grub.cfg"
install -Dm644 "$BOARD_DIR/grub-efi.cfg" "$BINARIES_DIR/efi-part/EFI/BOOT/grub.cfg"

# GRUB's BIOS stage-1 boot sector, needed by genimage.cfg.in to build the
# hybrid BIOS+EFI disk image (requires BR2_TARGET_GRUB2_INSTALL_TOOLS).
cp -f "$1/lib/grub/i386-pc/boot.img" "$BINARIES_DIR/boot.img"
