#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
# Lisence: MIT
# Author: kouhj
#========================================================================================

set -eo pipefail

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

if [ -z "${OPENWRT_DOWNLOAD_SITE_URL}" ]; then
  echo "::error::'OPENWRT_DOWNLOAD_SITE_URL' is empty" >&2
  exit 1
fi


source ${BUILDER_WORK_DIR}/scripts/lib/builder.sh


MY_DOWNLOAD_DIR="${BUILDER_WORK_DIR}/download"
mkdir -p "${OPENWRT_COMPILE_DIR}" || true
mkdir -p "${MY_DOWNLOAD_DIR}" || true

if [ "x${TEST}" = "x1" ]; then
  exit 0
fi

REMOTE_FILES="${MY_DOWNLOAD_DIR}/list"
wget  ${OPENWRT_DOWNLOAD_SITE_URL}/targets/${OPENWRT_BIN_RELPATH} -O $REMOTE_FILES

OPENWRT_MF_FILE=$(sed -n -r '/manifest/ s/.*(openwrt.*.manifest).*/\1/p' $REMOTE_FILES)
OPENWRT_IB_FILE=$(sed -n -r '/openwrt-imagebuilderk/ s/.*(openwrt.*.xz).*/\1/p'  $REMOTE_FILES)
OPENWRT_SDK_FILE=$(sed -n -r '/openwrt-sdk/ s/.*(openwrt.*.xz).*/\1/p'  $REMOTE_FILES)

for file in $OPENWRT_MF_FILE $OPENWRT_IB_FILE $OPENWRT_SDK_FILE config.buildinfo feeds.buildinfo; do
  wget -q "${OPENWRT_DOWNLOAD_SITE_URL}/targets/${OPENWRT_BIN_RELPATH}/${file}" -O ${MY_DOWNLOAD_DIR}/${file}
done

OPENWRT_IB_DIR="${MY_DOWNLOAD_DIR}/${OPENWRT_IB_FILE%.tar.xz}"
OPENWRT_SDK_DIR="${MY_DOWNLOAD_DIR}/${OPENWRT_SDK_FILE%.tar.xz}"

tar -C ${OPENWRT_IB_DIR} -xuJf ${MY_DOWNLOAD_DIR}/${OPENWRT_IB_FILE}
tar -C ${OPENWRT_SDK_DIR} -xuJf ${MY_DOWNLOAD_DIR}/${OPENWRT_SDK_FILE}

KOUHJ_SRC_DIR="${BUILDER_WORK_DIR}/kouhj_src"

_set_env OPENWRT_MF_FILE OPENWRT_IB_DIR OPENWRT_SDK_DIR MY_DOWNLOAD_DIR KOUHJ_SRC_DIR
append_docker_exec_env OPENWRT_MF_FILE OPENWRT_IB_DIR OPENWRT_SDK_DIR MY_DOWNLOAD_DIR KOUHJ_SRC_DIR

