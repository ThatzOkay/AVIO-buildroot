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
tar -xf data.tar.xz

install -Dm755 usr/bin/avio /usr/bin/avio
cp -r usr/share/avio /usr/share/

rm -rf "$TMP"

source board/raspberrypi/post-build.sh
