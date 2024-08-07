#!/bin/bash

#========================================================================================
# https://github.com/kouhj/openwrt_builder
# Description: Automatic Build of Custom OpenWRT Images with Official ImageBuilder & SDK
# Lisence: MIT
# Author: kouhj
#========================================================================================

set -eo pipefail
source ${BUILDER_WORK_DIR}/scripts/lib/builder.sh
if [ -z "${OPENWRT_IB_DIR}" ] || [ -z "${OPENWRT_SDK_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_IB_DIR', 'OPENWRT_SDK_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi


if [ "x${TEST}" = "x1" ]; then
  mkdir -p "${OPENWRT_SDK_DIR}/bin/targets/x86/64/packages"
  mkdir -p "${OPENWRT_SDK_DIR}/bin/packages"
  echo "Dummy firmware" > "${OPENWRT_SDK_DIR}/bin/targets/x86/64/firmware.bin"
  echo "Dummy packages" > "${OPENWRT_SDK_DIR}/bin/targets/x86/64/packages/packages.tar.gz"
  echo "Dummy packages" > "${OPENWRT_SDK_DIR}/bin/packages/packages.tar.gz"
  exit 0
fi

# Compile SDK first
echo "::info::Compiling SDK"
cd "${OPENWRT_SDK_DIR}"
if [ -f "${OPENWRT_SDK_DIR}/sdk/pre_compile.sh" ]; then
  echo "Executing SDK pre_compile.sh"
  /bin/bash "${OPENWRT_SDK_DIR}/sdk/pre_compile.sh"
fi

echo "Start Compiling..."
if [ "x${OPT_PACKAGE_ONLY}" != "x1" ]; then
  compile
else
  compile "package/compile" "package/index"
fi


# Compile IB
echo "::info::Compiling IB"
echo "Packages to install: $OPENWRT_IB_PACKAGES"   # This is calculated in scripts/compile.sh
cd ${OPENWRT_IB_DIR}
if [ -f "${OPENWRT_IB_DIR}/sdk/pre_compile.sh" ]; then
  echo "Executing IB pre_compile.sh"
  /bin/bash "${OPENWRT_IB_DIR}/sdk/pre_compile.sh"
fi

make image PROFILE="$OPENWRT_IB_PROFILE" ADD_LOCAL_KEY=1 FILES=files PACKAGES="$OPENWRT_IB_PACKAGES" \
  DISABLED_SERVICES="$OPENWRT_IB_DISABLED_SERVICES" PREPARE_ROOTFS_HOOK=prepare_rootfs_hook
  
find bin/targets/${CONFIG_TARGET_BOARD}/${CONFIG_TARGET_SUBTARGET}

mkdir -p ${BUILDER_BIN_DIR}/targets/${CONFIG_TARGET_BOARD}/
# Move to the folder that is accessible by the Host out of the docker
mv -f bin/targets/${CONFIG_TARGET_BOARD}/${CONFIG_TARGET_SUBTARGET}  ${BUILDER_BIN_DIR}/targets/${CONFIG_TARGET_BOARD}/
