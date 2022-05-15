#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
# Lisence: MIT
# Author: kouhj
#========================================================================================

set -eo pipefail

if [ -z "${MY_DOWNLOAD_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SDK_DIR}" ]; then
  echo "::error::'MY_DOWNLOAD_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SDK_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

source ${BUILDER_WORK_DIR}/scripts/lib/builder.sh


config_openwrt_sdk


