#!/usr/bin/env bash
# Fails fast if a consumer defconfig's arch/cpu/headers lines have drifted
# from its toolchain-producer twin. This is a convenience fast-fail layer,
# not the real safety net -- Buildroot's own toolchain-external configure-time
# checks (check_gcc_version, check_kernel_headers_version, etc.) are what
# actually enforce compatibility, unconditionally, at build time.
set -euo pipefail

CONFIGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs" && pwd)"

check_exact() {
  local board="$1" key="$2"
  local consumer="$CONFIGS_DIR/${board}_defconfig"
  local producer="$CONFIGS_DIR/${board}_toolchain_defconfig"
  local line_c line_p

  line_c="$(grep -E "^${key}(=|$)" "$consumer" || true)"
  line_p="$(grep -E "^${key}(=|$)" "$producer" || true)"
  if [ "$line_c" != "$line_p" ]; then
    echo "::error::Toolchain drift for ${board}: '${key}' differs between ${consumer} ('${line_c}') and ${producer} ('${line_p}')"
    exit 1
  fi
}

# Kernel-headers version has to line up across THREE differently-named
# symbols: the consumer's BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_<ver> (a
# kernel-build hint, only meaningful because the consumer has
# BR2_LINUX_KERNEL=y), the consumer's BR2_TOOLCHAIN_EXTERNAL_HEADERS_<ver>
# (what Buildroot's toolchain-external configure check enforces against),
# and the producer's BR2_KERNEL_HEADERS_<ver> (what actually gets installed
# into the toolchain, since the producer has no BR2_LINUX_KERNEL=y to trigger
# the consumer's symbol). Compare the extracted version numbers, not the
# raw lines, since the symbol names themselves are expected to differ.
check_headers_version() {
  local board="$1"
  local consumer="$CONFIGS_DIR/${board}_defconfig"
  local producer="$CONFIGS_DIR/${board}_toolchain_defconfig"
  local ver_kernel_hint ver_external ver_producer

  ver_kernel_hint="$(grep -E '^BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_[0-9_]+=y' "$consumer" | sed -E 's/^BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_([0-9_]+)=y/\1/' || true)"
  ver_external="$(grep -E '^BR2_TOOLCHAIN_EXTERNAL_HEADERS_[0-9_]+=y' "$consumer" | sed -E 's/^BR2_TOOLCHAIN_EXTERNAL_HEADERS_([0-9_]+)=y/\1/' || true)"
  ver_producer="$(grep -E '^BR2_KERNEL_HEADERS_[0-9_]+=y' "$producer" | sed -E 's/^BR2_KERNEL_HEADERS_([0-9_]+)=y/\1/' || true)"

  if [ -z "$ver_kernel_hint" ] || [ "$ver_kernel_hint" != "$ver_external" ] || [ "$ver_kernel_hint" != "$ver_producer" ]; then
    echo "::error::Toolchain headers-version drift for ${board}: consumer kernel-hint=${ver_kernel_hint:-<unset>}, consumer external-toolchain=${ver_external:-<unset>}, producer=${ver_producer:-<unset>} -- all three must match"
    exit 1
  fi
}

check_exact raspberrypi4 BR2_aarch64
check_exact raspberrypi4 BR2_cortex_a72
check_headers_version raspberrypi4

check_exact raspberrypi5 BR2_aarch64
check_exact raspberrypi5 BR2_cortex_a76
check_headers_version raspberrypi5

echo "Toolchain producer/consumer defconfigs are in sync."
