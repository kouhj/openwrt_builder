#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

[ "x${TEST}" != "x1" ] || exit 0

# In case previous steps failed
if [ -d "${OPENWRT_SOURCE_DIR}" ]; then
    rm -rf "${OPENWRT_SOURCE_DIR}"
fi

# Save the env vars shared between host and container for the next build
source "${BUILDER_WORK_DIR}/scripts/lib/builder.sh"
save_docker_env_file_in_container