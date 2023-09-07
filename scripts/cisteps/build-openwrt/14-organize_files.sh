#!/bin/bash

set -eo pipefail

[ "x${TEST}" != "x1" ] || exit 0

shopt -s extglob

set -x
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
    # shellcheck disable=SC2015
    [ ${#all_firmware_files[@]} -gt 0 ] && mv "${all_firmware_files[@]}" "${HOST_WORK_DIR}/openwrt_firmware/" || true
  fi
fi
#echo "status=failure" >> $GITHUB_OUTPUT  # to enter SSH
echo "status=success" >> $GITHUB_OUTPUT
