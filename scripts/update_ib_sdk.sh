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
cd ${MY_DOWNLOAD_DIR}

REMOTE_FILES="${MY_DOWNLOAD_DIR}/list"
for file in '/' sha256sum config.buildinfo feeds.buildinfo; do
  download_openwrt_file $file
done

OPENWRT_MF_FILE=$(sed -n -r '/manifest/ s/.*(openwrt.*.manifest).*/\1/p' $REMOTE_FILES)
OPENWRT_IB_FILE=$(sed -n -r '/openwrt-imagebuilder/ s/.*(openwrt.*.xz).*/\1/p' $REMOTE_FILES)
OPENWRT_SDK_FILE=$(sed -n -r '/openwrt-sdk/ s/.*(openwrt.*.xz).*/\1/p' $REMOTE_FILES)

OPENWRT_IB_DIR="${BUILDER_WORK_DIR}/kbuilder/ib/${OPENWRT_IB_FILE%.tar.xz}"
OPENWRT_SDK_DIR="${BUILDER_WORK_DIR}/kbuilder/sdk/${OPENWRT_SDK_FILE%.tar.xz}"
KOUHJ_SRC_DIR="${BUILDER_WORK_DIR}/kouhj_src"

# Maintain the current IB/SDK being used
CURRENT_IB_SDK_INFO_FILE="${MY_DOWNLOAD_DIR}/cureent_ib_sdk.inf"
if [ -f $CURRENT_IB_SDK_INFO_FILE ]; then
  source $CURRENT_IB_SDK_INFO_FILE
  # Remove the old IB/SDK extracted dir(s) and the tarball if the dir name changes
  [ "$OPENWRT_IB_DIR" != "$CUR_IB_DIR" ] && rm -rf ${CUR_IB_DIR}*
  [ "$OPENWRT_SDK_DIR" != "$CUR_SDK_DIR" ] && rm -rf ${CUR_SDK_DIR}*
fi

# Download files, and extract the tarball when necessary
download_openwrt_latest_file $OPENWRT_MF_FILE
if download_openwrt_latest_file $OPENWRT_IB_FILE; then
  tar -C ${BUILDER_WORK_DIR}/kbuilder/ib -Jxf ${MY_DOWNLOAD_DIR}/${OPENWRT_IB_FILE}
fi
if download_openwrt_latest_file $OPENWRT_SDK_FILE; then
  tar -C ${BUILDER_WORK_DIR}/kbuilder/sdk -Jxf ${MY_DOWNLOAD_DIR}/${OPENWRT_SDK_FILE}
fi

# Update current IB/SDK info
echo -e "CUR_IB_DIR='$OPENWRT_IB_DIR'\nCUR_SDK_DIR='$OPENWRT_SDK_DIR'" >$CURRENT_IB_SDK_INFO_FILE

# Make a backup of the config file
cp -a ${OPENWRT_IB_DIR}/.config ${OPENWRT_IB_DIR}/.config.orig

# Make these GITHUB_ENV managed env vars also available in the 'docker-vars' file
_docker_set_env BUILDER_PROFILE_DIR

# For following custom IB/SDK config and compile actions
_docker_set_env OPENWRT_MF_FILE OPENWRT_IB_DIR OPENWRT_SDK_DIR MY_DOWNLOAD_DIR KOUHJ_SRC_DIR
