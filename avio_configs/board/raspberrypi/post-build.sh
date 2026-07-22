#!/bin/bash

set -u
set -e
set -x

TMP=$(mktemp -d)

LATEST=$(curl -s https://api.github.com/repos/ThatzOkay/AVIO/releases \
  | jq -r '.[0].assets[] | select(.name | endswith(".deb") and contains("arm64")) | .browser_download_url')

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

source board/raspberrypi/post-build.sh
