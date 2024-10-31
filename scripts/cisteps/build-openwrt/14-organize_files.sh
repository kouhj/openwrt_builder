#!/bin/bash

set -eo pipefail

[ "x${TEST}" != "x1" ] || exit 0

shopt -s extglob

# To load the ENV variables that were set inside the docker
source "${HOST_WORK_DIR}/scripts/lib/builder.sh"

HOST_BIN_DIR="${HOST_WORK_DIR}/openwrt_bin"
sudo chown -R "$(id -u):$(id -g)" "${HOST_BIN_DIR}"
if [ "x${OPT_PACKAGE_ONLY}" != "x1" ]; then
  mkdir -p "${HOST_WORK_DIR}/openwrt_firmware"
  # shellcheck disable=SC2164
  if [ -d "${HOST_BIN_DIR}/targets/"*/* ]; then
    cd "${HOST_BIN_DIR}/targets/"*/*
    all_firmware_files=( !(*kernel*|*rootfs*|*firmware*) )

    # Add rootfs for X86_64
    if [ "${CONFIG_TARGET_BOARD}" = "x86" ]; then
      all_firmware_files+=( *rootfs.tar.gz )
    fi
    # shellcheck disable=SC2015
    [ ${#all_firmware_files[@]} -gt 0 ] && mv "${all_firmware_files[@]}" "${HOST_WORK_DIR}/openwrt_firmware/" || true
  fi
fi
#"ORGANIZE_STATUS=failure" # to enter SSH
ORGANIZE_STATUS="success"
persistent_env_set ORGANIZE_STATUS
