#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"
source "${BUILDER_WORK_DIR}/scripts/lib/gaction.sh"

# Some folders
# $OPENWRT_CUR_DIR:   OpenWRT GIT source code dir
# $OPENWRT_IB_DIR:    OpenWRT ImageBuilder extracted dir
# $OPENWRT_SDK_DIR:   OpenWRT SDK extracted dir
# $MY_DOWNLOAD_DIR:   Where the files are downloaded by update_ib_sdk.sh

docker_exec "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/update_ib_sdk.sh"
docker_exec "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/update_repo.sh"
docker_exec "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/update_feeds.sh"

