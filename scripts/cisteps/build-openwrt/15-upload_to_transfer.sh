#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
#      This file contains the script to upload built artifacts to transfer.sh
# Lisence: MIT
# Author: kouhj
#========================================================================================

set -eo pipefail

[ "x${TEST}" != "x1" ] || exit 0

shopt -s extglob

# To load the ENV variables that were set inside the docker
source "${HOST_WORK_DIR}/scripts/lib/builder.sh"

transfer() {
  curl --upload-file "$1" https://transfer.sh/$(basename "$1") | tee /dev/null
}

if [ -d "${HOST_WORK_DIR}/openwrt_firmware" ]; then
  cd ${HOST_WORK_DIR}/openwrt_firmware
  all_firmware_files=(!(*firmware*|*factory*))
  DATE=$(date "+%Y%m%d")
  FW_ARTIFACTS_FN="OpenWrt_firmware_${BUILD_TARGET}_${DATE}.tar"
  if [ ${#all_firmware_files[@]} -gt 0 ]; then
    tar cf $FW_ARTIFACTS_FN "${all_firmware_files[@]}"
    FW_ARTIFACTS_URL=$(transfer $FW_ARTIFACTS_FN)
    echo "transer.sh download URL: $FW_ARTIFACTS_URL, local file: ${FW_ARTIFACTS_FN}"
    archive="$PWD/${FW_ARTIFACTS_FN}"
    url="${FW_ARTIFACTS_URL}"
    persistent_env_set archive url
  fi
fi
