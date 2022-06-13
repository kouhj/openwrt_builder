#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
# Lisence: MIT
# Author: kouhj
#========================================================================================

set -eo pipefail
source ${BUILDER_WORK_DIR}/scripts/lib/builder.sh

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

if [ -z "${OPENWRT_DOWNLOAD_SITE_URL}" ]; then
  echo "::error::'OPENWRT_DOWNLOAD_SITE_URL' is empty" >&2
  exit 1
fi


if [ "x${TEST}" = "x1" ]; then
  exit 0
fi

MY_DOWNLOAD_DIR="${BUILDER_WORK_DIR}/kbuilder/download"
mkdir -p "${OPENWRT_COMPILE_DIR}" || true
mkdir -p "${MY_DOWNLOAD_DIR}" ${BUILDER_WORK_DIR}/kbuilder/{ib,sdk}

REMOTE_FILES="${MY_DOWNLOAD_DIR}/list"
wget --no-check-certificate -q ${OPENWRT_DOWNLOAD_SITE_URL} -O $REMOTE_FILES

OPENWRT_MF_FILE=$(sed -n -r '/manifest/ s/.*(openwrt.*.manifest).*/\1/p' $REMOTE_FILES)
OPENWRT_IB_FILE=$(sed -n -r '/openwrt-imagebuilder/ s/.*(openwrt.*.xz).*/\1/p'  $REMOTE_FILES)
OPENWRT_SDK_FILE=$(sed -n -r '/openwrt-sdk/ s/.*(openwrt.*.xz).*/\1/p'  $REMOTE_FILES)

for file in $OPENWRT_MF_FILE $OPENWRT_IB_FILE $OPENWRT_SDK_FILE config.buildinfo feeds.buildinfo; do
  wget --no-check-certificate -q "${OPENWRT_DOWNLOAD_SITE_URL}/${file}" -O ${MY_DOWNLOAD_DIR}/${file}
done

OPENWRT_IB_DIR="${BUILDER_WORK_DIR}/kbuilder/ib/${OPENWRT_IB_FILE%.tar.xz}"
OPENWRT_SDK_DIR="${BUILDER_WORK_DIR}/kbuilder/sdk/${OPENWRT_SDK_FILE%.tar.xz}"
KOUHJ_SRC_DIR="${BUILDER_WORK_DIR}/kouhj_src"

tar -C ${BUILDER_WORK_DIR}/ib  -Jxf ${MY_DOWNLOAD_DIR}/${OPENWRT_IB_FILE}
tar -C ${BUILDER_WORK_DIR}/sdk -Jxf ${MY_DOWNLOAD_DIR}/${OPENWRT_SDK_FILE}

# Make a backup of the config file
cp -a ${OPENWRT_IB_DIR}/.config  ${OPENWRT_IB_DIR}/.config.orig

# Make these GITHUB_ENV managed env vars also available in the 'docker-vars' file
_docker_set_env BUILDER_PROFILE_DIR HOST_BIN_DIR

# For following custom IB/SDK config and compile actions
_docker_set_env OPENWRT_MF_FILE OPENWRT_IB_DIR OPENWRT_SDK_DIR MY_DOWNLOAD_DIR KOUHJ_SRC_DIR
