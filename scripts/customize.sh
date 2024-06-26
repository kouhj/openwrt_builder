#!/bin/bash

#=================================================
# https://github.com/tete1030/openwrt-fastbuild-actions
# Description: FAST building OpenWrt with Github Actions and Docker!
# Lisence: MIT
# Author: Texot
#=================================================

set -eo pipefail

# shellcheck disable=SC1090
source "${BUILDER_WORK_DIR}/scripts/lib/builder.sh"

if [ -z "${OPENWRT_COMPILE_DIR}" ] || [ -z "${OPENWRT_CUR_DIR}" ] || [ -z "${OPENWRT_SOURCE_DIR}" ]; then
  echo "::error::'OPENWRT_COMPILE_DIR', 'OPENWRT_CUR_DIR' or 'OPENWRT_SOURCE_DIR' is empty" >&2
  exit 1
fi

if [ "x${TEST}" = "x1" ]; then
  OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"
  persistent_env_set OPENWRT_CUR_DIR
  exit 0
fi


if [ ! -f "${OPENWRT_CUR_DIR_CUSTOMIZED_FILE}" ]; then
  [ -f "${OPENWRT_CUR_DIR}/.config" ] || touch "${OPENWRT_CUR_DIR}/.config"
  for file in ${BUILDER_PROFILE_DIR}/source/config*.diff; do
    if [ -f "${file}" ]; then
      cat ${BUILDER_PROFILE_DIR}/source/config*.diff  >> "${OPENWRT_CUR_DIR}/.config"
    fi
  done

  echo "Applying patches..."
  if [ -n "$(ls -A "${BUILDER_PROFILE_DIR}/patches" 2>/dev/null)" ]; then
    (
      if [ "x${NONSTRICT_PATCH}" = "x1" ]; then
        set +eo pipefail
      fi

      find "${BUILDER_PROFILE_DIR}/patches" -type f -name '*.patch' -print0 | sort -z | xargs -I % -t -0 -n 1 sh -c "cat '%'  | patch -d '${OPENWRT_CUR_DIR}' -p0 --forward"
      # To set final status of the subprocess to 0, because outside the parentheses the '-eo pipefail' is still on
      true
    )
  fi

  SYNC_EXCLUDES="
  /bin
  /dl
  /tmp
  /build_dir
  /staging_dir
  /toolchain
  /logs
  *.o
  key-build*
  "
  declare -a sync_exclude_opts=()
  while IFS= read -r line; do
    if [[ -z "${line// /}" ]]; then
      continue
    fi
    sync_exclude_opts+=("--exclude=${line}")
  done <<<"${SYNC_EXCLUDES}"

  echo "Copying base files..."
  if [ -n "$(ls -A "${BUILDER_PROFILE_DIR}/files" 2>/dev/null)" ]; then
    # feeds.conf is handled in update_feeds.sh
    rsync -camv --no-t "${sync_exclude_opts[@]}" --exclude="/feeds.conf" --exclude="/.config" \
      "${BUILDER_PROFILE_DIR}/files/" "${OPENWRT_CUR_DIR}/"
  fi

  touch "${OPENWRT_CUR_DIR_CUSTOMIZED_FILE}"
fi

echo "Executing custom.sh"
for script in ${BUILDER_PROFILE_DIR}/ib/source*.sh  ${BUILDER_WORK_DIR}/scripts/custom_ib_sdk.sh; do
  (
    if [ -f "${script}" ]; then
      echo "Running custom script: ${script}"
      bash "${script}"
    fi
  )
done


# Restore build cache and timestamps
if [ "x${OPENWRT_CUR_DIR}" != "x${OPENWRT_COMPILE_DIR}" ]; then
  echo "Syncing rebuilt source code to work directory..."
  # sync files by comparing checksum
  rsync -camv --no-t --delete "${sync_exclude_opts[@]}" \
    "${OPENWRT_CUR_DIR}/" "${OPENWRT_COMPILE_DIR}/"

  rm -rf "${OPENWRT_CUR_DIR}"
  OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"
  persistent_env_set OPENWRT_CUR_DIR
fi

