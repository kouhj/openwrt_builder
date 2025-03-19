#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set -xeo pipefail
source ${BUILDER_WORK_DIR}/scripts/lib/builder.sh

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

cd "${OPENWRT_SDK_DIR}"
make download -j8
rm -rf ${DL_CACHE_DIR}/*
source <( grep DOWNLOAD .config ) # Load CONFIG_DOWNLOAD_FOLDER from .config
cp -a ${CONFIG_DOWNLOAD_FOLDER}/*  ${DL_CACHE_DIR}/

# Cache the feature library
FEATURE_LIB_FILENAME='feature3.0_cn_25.03.16-free.zip'  # Update as needed
FEATURE_LIB_URL="https://www.openappfilter.com/fros/download_feature?filename=${FEATURE_LIB_FILENAME}&f=1"
wget "$FEATURE_LIB_URL" -O feature_lib.zip
unzip -j feature_lib.zip -d ${DL_CACHE_DIR} '*.bin'
rm feature_lib.zip

commit_dl_cache

DOWNLOAD_STATUS="success"
persistent_env_set DOWNLOAD_STATUS