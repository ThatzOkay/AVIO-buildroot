#!/usr/bin/env bash
# Fails fast if a consumer defconfig's arch/cpu/headers lines have drifted
# from its toolchain-producer twin. This is a convenience fast-fail layer,
# not the real safety net -- Buildroot's own toolchain-external configure-time
# checks (check_gcc_version, check_kernel_headers_version, etc.) are what
# actually enforce compatibility, unconditionally, at build time.
set -euo pipefail

CONFIGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs" && pwd)"

check_board() {
  local board="$1"; shift
  local keys=("$@")
  local consumer="$CONFIGS_DIR/${board}_defconfig"
  local producer="$CONFIGS_DIR/${board}_toolchain_defconfig"
  local key line_c line_p

  for key in "${keys[@]}"; do
    line_c="$(grep -E "^${key}(=|$)" "$consumer" || true)"
    line_p="$(grep -E "^${key}(=|$)" "$producer" || true)"
    if [ "$line_c" != "$line_p" ]; then
      echo "::error::Toolchain drift for ${board}: '${key}' differs between ${consumer} ('${line_c}') and ${producer} ('${line_p}')"
      exit 1
    fi
  done
}

check_board raspberrypi4 BR2_aarch64 BR2_cortex_a72 BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_6
check_board raspberrypi5 BR2_aarch64 BR2_cortex_a76 BR2_PACKAGE_HOST_LINUX_HEADERS_CUSTOM_6_6

echo "Toolchain producer/consumer defconfigs are in sync."
