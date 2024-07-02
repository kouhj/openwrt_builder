#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
# Lisence: MIT
# Author: kouhj
#========================================================================================

set -xeo pipefail
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

set +e # This script explicit uses non-zero return values!
BUILDER_ARCH_BASE_DIR="${BUILDER_WORK_DIR}/kbuilder/${BUILD_TARGET}"
CURRENT_IB_SDK_INFO_FILE="${BUILDER_ARCH_BASE_DIR}/cureent_ib_sdk.inf" # Info of IB/SDK
[ -f $CURRENT_IB_SDK_INFO_FILE ] && source $CURRENT_IB_SDK_INFO_FILE

KOUHJ_SRC_DIR="${BUILDER_WORK_DIR}/kouhj_src"
git config --global --add safe.directory $KOUHJ_SRC_DIR
KOUHJ_SRC_REVISION=$(cd $KOUHJ_SRC_DIR; git rev-parse HEAD)
[ "${CUR_KOUHJ_SRC_REVISION}" == "${KOUHJ_SRC_REVISION}" ]; KOUHJ_SRC_UPDATED=$?

MY_DOWNLOAD_DIR="${BUILDER_ARCH_BASE_DIR}/download"
mkdir -p "${OPENWRT_COMPILE_DIR}" || true
mkdir -p "${BUILDER_ARCH_BASE_DIR}"/{download,ib,sdk}
cd ${MY_DOWNLOAD_DIR}

REMOTE_FILES="${MY_DOWNLOAD_DIR}/list"
download_openwrt_file '/' ${REMOTE_FILES}
SNAPSHOT_LIST_STATUS=$?
if [ "$SNAPSHOT_LIST_STATUS" -eq 2 ]; then
  echo 'Failed to list OpenWRT download folder.'
  exit 1
fi

##################################### DECISION MATRIX #######################################
## $SNAPSHOT_LIST_STATUS  $KOUHJ_SRC_UPDATED   |   TO DOWNLOAD SDK/IB    TO REBUILD SDK/IB
## --------------------------------------------+---------------------------------------------     
##          1                     0            |           NO                  NO
##          1                     1            |           NO                  YES
##          0                    0/1           |           YES                 YES
## --------------------------------------------+---------------------------------------------     
echo "----------------------------------------------------------------"
echo "Build decision matrix"
echo "SNAPSHOT_LIST_STATUS=$SNAPSHOT_LIST_STATUS KOUHJ_SRC_UPDATED=$KOUHJ_SRC_UPDATED"
echo "----------------------------------------------------------------"

BUILD_NEEDED='yes'
if   [ "$SNAPSHOT_LIST_STATUS" -eq 1 -a "$KOUHJ_SRC_UPDATED" -eq 0 ]; then
  # Nothing to do
  BUILD_NEEDED='no'
  persistent_env_set BUILD_NEEDED
  exit 0
elif [ "$SNAPSHOT_LIST_STATUS" -eq 1 -a "$KOUHJ_SRC_UPDATED" -eq 1 ]; then
  BUILD_NEEDED='yes'
  persistent_env_set BUILD_NEEDED
  exit 0
elif [ "$SNAPSHOT_LIST_STATUS" -eq 0 ]; then
  BUILD_NEEDED='yes'
  persistent_env_set BUILD_NEEDED
fi



for file in sha256sums config.buildinfo feeds.buildinfo; do
  download_openwrt_file $file
done

OPENWRT_MF_FILE=$(sed -n -r '/manifest/ s/.*(openwrt.*.manifest).*/\1/p' $REMOTE_FILES)
OPENWRT_IB_FILE=$(sed -n -r '/openwrt-imagebuilder/ s/.*(openwrt.*.xz).*/\1/p' $REMOTE_FILES)
OPENWRT_SDK_FILE=$(sed -n -r '/openwrt-sdk/ s/.*(openwrt.*.xz).*/\1/p' $REMOTE_FILES)

OPENWRT_IB_DIR="${BUILDER_ARCH_BASE_DIR}/ib/${OPENWRT_IB_FILE%.tar.xz}"
OPENWRT_SDK_DIR="${BUILDER_ARCH_BASE_DIR}/sdk/${OPENWRT_SDK_FILE%.tar.xz}"

# Status file indicating the dir has been customized and configured
OPENWRT_IB_DIR_CUSTOMIZED_FILE="${BUILDER_ARCH_BASE_DIR}/ib/.customized"
OPENWRT_SDK_DIR_CUSTOMIZED_FILE="${BUILDER_ARCH_BASE_DIR}/sdk/.customized"
OPENWRT_CUR_DIR_CUSTOMIZED_FILE="${OPENWRT_CUR_DIR}/.customized"
OPENWRT_IB_DIR_CONFIGURED_FILE="${BUILDER_ARCH_BASE_DIR}/ib/.configured"
OPENWRT_SDK_DIR_CONFIGURED_FILE="${BUILDER_ARCH_BASE_DIR}/sdk/.configured"
OPENWRT_CUR_DIR_CONFIGURED_FILE="${OPENWRT_CUR_DIR}/.configured"

persistent_env_set BUILDER_PROFILE_DIR BUILDER_ARCH_BASE_DIR MY_DOWNLOAD_DIR KOUHJ_SRC_DIR \
                OPENWRT_CUR_DIR_CUSTOMIZED_FILE OPENWRT_CUR_DIR_CONFIGURED_FILE

# Maintain the current IB/SDK being used
# Remove the old IB/SDK extracted dir(s) and the tarball if the dir name changes
[ -n "$CUR_IB_DIR"  -a "$OPENWRT_IB_DIR"  != "$CUR_IB_DIR"  ] && rm -rf ${CUR_IB_DIR}*  ${BUILDER_ARCH_BASE_DIR}/ib/.c* || true
[ -n "$CUR_SDK_DIR" -a "$OPENWRT_SDK_DIR" != "$CUR_SDK_DIR" ] && rm -rf ${CUR_SDK_DIR}* ${BUILDER_ARCH_BASE_DIR}/sdk/.c* || true
# Delete files that may be stale
housekeep_local_downloads

# Download files, and extract the tarball when necessary
if download_openwrt_latest_file $OPENWRT_MF_FILE; then
  persistent_env_set OPENWRT_MF_FILE
fi

if download_openwrt_latest_file $OPENWRT_IB_FILE; then
  [ -f $OPENWRT_IB_DIR_CUSTOMIZED_FILE ] && rm -f $OPENWRT_IB_DIR_CUSTOMIZED_FILE
  [ -f $OPENWRT_IB_DIR_CONFIGURED_FILE ] && rm -f $OPENWRT_IB_DIR_CONFIGURED_FILE
  tar -C ${BUILDER_ARCH_BASE_DIR}/ib -Jxf ${MY_DOWNLOAD_DIR}/${OPENWRT_IB_FILE}
  persistent_env_set OPENWRT_IB_DIR OPENWRT_IB_DIR_CUSTOMIZED_FILE OPENWRT_IB_DIR_CONFIGURED_FILE
fi

if download_openwrt_latest_file $OPENWRT_SDK_FILE; then
  [ -f $OPENWRT_SDK_DIR_CUSTOMIZED_FILE ] && rm -f $OPENWRT_SDK_DIR_CUSTOMIZED_FILE
  [ -f $OPENWRT_SDK_DIR_CONFIGURED_FILE ] && rm -f $OPENWRT_SDK_DIR_CONFIGURED_FILE
  tar -C ${BUILDER_ARCH_BASE_DIR}/sdk -Jxf ${MY_DOWNLOAD_DIR}/${OPENWRT_SDK_FILE}

  persistent_env_set OPENWRT_SDK_DIR OPENWRT_SDK_DIR_CUSTOMIZED_FILE OPENWRT_SDK_DIR_CONFIGURED_FILE
fi

# Update current IB/SDK info
echo -e "CUR_IB_DIR='$OPENWRT_IB_DIR'\nCUR_SDK_DIR='$OPENWRT_SDK_DIR'\nCUR_KOUHJ_SRC_REVISION='$KOUHJ_SRC_REVISION'" >$CURRENT_IB_SDK_INFO_FILE

# Make a backup of the config file
cp -a ${OPENWRT_IB_DIR}/.config ${OPENWRT_IB_DIR}/.config.orig

                
