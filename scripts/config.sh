#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -xeo pipefail
source ${BUILDER_WORK_DIR}/scripts/lib/builder.sh

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

if [ ! -f "${OPENWRT_CUR_DIR_CONFIGURED_FILE}" ]; then
  #cd "${OPENWRT_CUR_DIR}"
  #make defconfig
  #make oldconfig
  touch "${OPENWRT_CUR_DIR_CONFIGURED_FILE}"
fi

if [ ! -f "${OPENWRT_SDK_DIR_CONFIGURED_FILE}" ]; then
  cd "${OPENWRT_SDK_DIR}"
  generate_openwrt_sdk_config
  openwrt_sdk_install_ksoftethervpn
  touch "${OPENWRT_SDK_DIR_CONFIGURED_FILE}"
fi

if [ ! -f "${OPENWRT_IB_DIR_CONFIGURED_FILE}" ]; then
  cd "${OPENWRT_IB_DIR}"
  generate_openwrt_ib_config
  get_packages_for_ib
  get_profiles_for_ib
  get_disabled_services_for_ib

  # Update IB/repositories.conf from SDK/bin/packages/ARCH/* folders and user/current/feeds*.conf files
  update_ib_repositories_conf

  touch "${OPENWRT_IB_DIR_CONFIGURED_FILE}"
fi

OPENWRT_IB_ROOTFS_DIR="${OPENWRT_IB_DIR}/build_dir/target-${CONFIG_TARGET_ARCH_PACKAGES}_${CONFIG_TARGET_SUFFIX}/root-${CONFIG_TARGET_BOARD}"
_docker_set_env OPENWRT_IB_ROOTFS_DIR
