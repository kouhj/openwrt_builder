#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
# Lisence: MIT
# Author: kouhj
#========================================================================================

set -eo pipefail
source ${BUILDER_WORK_DIR}/scripts/lib/builder.sh

if [ -z "${MY_DOWNLOAD_DIR}" ] || [ -z "${OPENWRT_IB_DIR}" ] || [ -z "${OPENWRT_SDK_DIR}" ]; then
  echo "::error::'MY_DOWNLOAD_DIR', 'OPENWRT_IB_DIR' or 'OPENWRT_SDK_DIR' is empty" >&2
  exit 1
fi

if [ -z "${BUILDER_WORK_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${BUILDER_PROFILE_DIR}" ]; then
  echo "::error::'BUILDER_WORK_DIR', 'OPENWRT_CUR_DIR' or 'BUILDER_PROFILE_DIR' is empty" >&2
  exit 1
fi

if [ -z "${KOUHJ_SRC_DIR}" ]; then
  echo "::error::'KOUHJ_SRC_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

if [ ! -f "${OPENWRT_IB_DIR_CUSTOMIZED_FILE}" ]; then
  # Add SDK build key to IB's files/etc/opkg/ folder
  add_sdk_keys_to_ib
  # Modify IB default packages
  patch_ib_default_packages
  # Apply user/current/ib/patches/*.patch to IB
  apply_patches_for_ib

  # WORKAROUND for 22.03.0 released SDK does not contain include/openssl-engine.mk
  # 22.03.4 fixed it, so the line be
  #[ ! -f $OPENWRT_SDK_DIR/include/openssl-engine.mk ] && cp -af ${OPENWRT_CUR_DIR}/include/openssl-engine.mk $OPENWRT_SDK_DIR/include/

  touch ${OPENWRT_IB_DIR_CUSTOMIZED_FILE}
fi


# Copy key-build* files to OpenWRT_CUR_DIR and OPENWRT_SDK_DIR
copy_build_keys  # Put this outside of the if-block below to ensure the keys exist every time

if [ ! -f "${OPENWRT_SDK_DIR_CUSTOMIZED_FILE}" ]; then
  # Generate feeds.conf from IB's feeds.buildinfo and user/current/feeds.conf
  generate_sdk_feeds_conf
  # Apply user/current/sdk/patches/*.patch to SDK
  apply_patches_for_sdk

  # Call additional custom*.sh scripts
  for script in ${BUILDER_PROFILE_DIR}/ib/custom*.sh ${BUILDER_PROFILE_DIR}/sdk/custom*.sh; do
    (
      if [ -f "${script}" ]; then
        echo "Running custom script: ${script}"
        bash "${script}"
      fi
    )
  done

  touch ${OPENWRT_SDK_DIR_CUSTOMIZED_FILE}
fi

# Get the cached SDK sources archives
cd "${OPENWRT_SDK_DIR}"
source <( grep DOWNLOAD .config )
for f in $(compgen ${DL_CACHE_DIR}/*); do
  cp -a $f ${CONFIG_DOWNLOAD_FOLDER}/
done

CUSTOMIZE_STATUS='success'
persistent_env_set CUSTOMIZE_STATUS
