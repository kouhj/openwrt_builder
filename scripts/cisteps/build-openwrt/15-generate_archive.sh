#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
#      This file contains the script to upload built artifacts
# Lisence: MIT
# Author: kouhj
#========================================================================================

set -eo pipefail

[ "x${TEST}" != "x1" ] || exit 0

shopt -s extglob

# To load the ENV variables that were set inside the docker
source "${HOST_WORK_DIR}/scripts/lib/builder.sh"

if [ -d "${HOST_WORK_DIR}/openwrt_firmware" ]; then
  cd ${HOST_WORK_DIR}/openwrt_firmware
  all_firmware_files=(!(*firmware*|*factory*))
  DATE_FULL=$(date "+%Y%m%d-%H%M")
  FW_ARTIFACTS_FN="OpenWrt_firmware_${BUILD_TARGET}_${DATE_FULL}.tar"
  RELEASE_NAME="OpenWrt_firmware_${BUILD_TARGET}_${DATE_FULL}"
  if [ ${#all_firmware_files[@]} -gt 0 ]; then
    tar cf $FW_ARTIFACTS_FN "${all_firmware_files[@]}"
    ARTIFACT_PATH="$PWD/${FW_ARTIFACTS_FN}"
    persistent_env_set ARTIFACT_PATH RELEASE_NAME
  fi
fi
