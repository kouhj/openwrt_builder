#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set -xeo pipefail

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

DL_CACHE_DIR="${BUILDER_WORK_DIR}/dl_cache"

cd "${OPENWRT_SDK_DIR}"
source <( grep DOWNLOAD .config )
make download -j8
rm -rf ${DL_CACHE_DIR}/*
cp -a ${CONFIG_DOWNLOAD_FOLDER}/*  ${DL_CACHE_DIR}/

# Cache the feature library
FEATURE_LIB_FILENAME='feature3.0_cn_25.03.16-free.zip'  # Update as needed
FEATURE_LIB_URL="https://www.openappfilter.com/fros/download_feature?filename=${FEATURE_LIB_FILENAME}&f=1"
wget "$FEATURE_LIB_URL" -O feature_lib.zip
unzip -j feature_lib.zip -d ${DL_CACHE_DIR}/feature_lib.tar.gz

cd ${DL_CACHE_DIR}/
if git status --porcelain | grep -q .; then
    git config --global --add safe.directory $DL_CACHE_DIR
    git --global user.name "builder"
    git --global user.email "builder@users.noreply"
    git remote set-url origin https://x-access-token:$GH_PAT@github.com/kouhj/dl_cache
    git commit -am "Update dl_cache"
fi

DOWNLOAD_STATUS="success"
persistent_env_set DOWNLOAD_STATUS