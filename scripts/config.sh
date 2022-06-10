#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail
source ${BUILDER_WORK_DIR}/scripts/lib/builder.sh

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

#cd "${OPENWRT_CUR_DIR}"
#make defconfig
#make oldconfig

set -x
cd "${OPENWRT_SDK_DIR}"
generate_openwrt_sdk_config
openwrt_sdk_install_ksoftethervpn

cd "${OPENWRT_IB_DIR}"
generate_openwrt_ib_config
get_packages_for_ib
get_disabled_services_for_ib

OPENWRT_IB_ROOTFS_DIR="${OPENWRT_IB_DIR}/build_dir/target-${CONFIG_TARGET_ARCH_PACKAGES}_$(CONFIG_TARGET_SUFFIX}/root-${CONFIG_TARGET_BOARD}"
_docker_set_env OPENWRT_IB_ROOTFS_DIR