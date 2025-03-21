#!/bin/bash

# Copyright (c) 2019 P3TERX
# From https://github.com/P3TERX/Actions-OpenWrt

set -eo pipefail

source "${BUILDER_WORK_DIR}/scripts/host/docker.sh"

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

if [ "x${TEST}" = "x1" ]; then
  mkdir -p "${OPENWRT_COMPILE_DIR}/bin/targets/x86/64/packages"
  mkdir -p "${OPENWRT_COMPILE_DIR}/bin/packages"
  echo "Dummy firmware" > "${OPENWRT_COMPILE_DIR}/bin/targets/x86/64/firmware.bin"
  echo "Dummy packages" > "${OPENWRT_COMPILE_DIR}/bin/targets/x86/64/packages/packages.tar.gz"
  echo "Dummy packages" > "${OPENWRT_COMPILE_DIR}/bin/packages/packages.tar.gz"
  exit 0
fi


echo "Executing pre_compile.sh"
if [ -f "${BUILDER_PROFILE_DIR}/source/pre_compile.sh" ]; then
  /bin/bash "${BUILDER_PROFILE_DIR}/source/pre_compile.sh"
fi

# shellcheck disable=SC1090
COMPILE_STATUS='unknown'
if bash "${BUILDER_WORK_DIR}/scripts/compile_ib_sdk.sh"; then
  commit_dl_cache
  COMPILE_STATUS='success'
  rc=0
else
  COMPILE_STATUS='failure'
  rc=1
fi

persistent_env_set COMPILE_STATUS
exit $rc

##### UNREACHABLE CODE #####
echo 'Skipped compile OpenWRT full source'
cd ${OPENWRT_CUR_DIR}
echo "Compiling..."
if [ "x${OPT_PACKAGE_ONLY}" != "x1" ]; then
  compile
else
  compile "package/compile"
  compile "package/index"
fi
