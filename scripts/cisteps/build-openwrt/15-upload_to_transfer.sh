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
  curl --progress-bar --upload-file "$1" https://transfer.sh/$(basename "$1") | tee /dev/null
  echo
}

if [ -d "${HOST_WORK_DIR}/openwrt_firmware" ]; then
  cd ${HOST_WORK_DIR}/openwrt_firmware
  all_firmware_files=(!(*firmware*|*factory*))
  FW_ARTIFACTS_FN="OpenWrt_firmware_${BUILD_TARGET}_${FILE_DATE}.tar"
  if [ ${#all_firmware_files[@]} -gt 0 ]; then
    tar cf $FW_ARTIFACTS_FN "${{all_firmware_files[@]}"
    FW_ARTIFACTS_URL=$(transfer $FW_ARTIFACTS_FN)
    rm -f ${FW_ARTIFACTS_FN}
    echo "::set-output name=archive::$PWD/${FW_ARTIFACTS_FN}}"
    echo "::set-output name=url::${FW_ARTIFACTS_URL}}"
  fi
fi
