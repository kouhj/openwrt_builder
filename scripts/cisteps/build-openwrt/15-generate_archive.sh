#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
#      This file contains the script to upload built artifacts
# Lisence: MIT
# Author: kouhj
#========================================================================================

set -xeo pipefail

[ "x${TEST}" != "x1" ] || exit 0

shopt -s extglob

# To load the ENV variables that were set inside the docker
source "${HOST_WORK_DIR}/scripts/lib/builder.sh"


if [ -d "${HOST_WORK_DIR}/openwrt_firmware" ]; then
  cd ${HOST_WORK_DIR}/openwrt_firmware
  all_firmware_files=(!(*firmware*|*factory*))
  DATE=$(date "+%Y%m%d")
  if [ ${#all_firmware_files[@]} -gt 0 ]; then
    tar cf $FW_ARTIFACTS_FN "${all_firmware_files[@]}"
    archive="$PWD/${FW_ARTIFACTS_FN}"
    persistent_env_set archive
  fi
fi
