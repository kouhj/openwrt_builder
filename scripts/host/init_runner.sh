#!/bin/bash
# shellcheck disable=SC2034

install_commands() {
  echo "Installing necessary commands..."
  export DEBIAN_FRONTEND=noninteractive

  sudo -E apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CC86BB64
  sudo -E add-apt-repository -y ppa:rmescandon/yq
  sudo -E apt-get -qq update && sudo -E apt-get -qq install jq yq tree
}

setup_envs() {
  # shellcheck disable=SC1090
  source "${HOST_WORK_DIR}/scripts/host/docker.sh"
  # shellcheck disable=SC1090
  source "${HOST_WORK_DIR}/scripts/lib/utils.sh"

  # Do not change
  BUILDER_WORK_DIR="/home/builder"
  BUILDER_TMP_DIR="/tmp/builder"
  HOST_TMP_DIR="/tmp/builder"
  BUILDER_BIN_DIR="${BUILDER_WORK_DIR}/openwrt_bin"
  HOST_BIN_DIR="${HOST_WORK_DIR}/openwrt_bin"
  BUILDER_PROFILE_DIR="${BUILDER_WORK_DIR}/user/current"
  BUILDER_MOUNT_OPTS="
    -v '${HOST_WORK_DIR}/scripts:${BUILDER_WORK_DIR}/scripts'
    -v '${HOST_WORK_DIR}/user:${BUILDER_WORK_DIR}/user'
    -v '${HOST_WORK_DIR}/kouhj_src:${BUILDER_WORK_DIR}/kouhj_src'
    -v '${HOST_BIN_DIR}:${BUILDER_BIN_DIR}'
    -v '${HOST_TMP_DIR}:${BUILDER_TMP_DIR}'
    -v '${GITHUB_ENV}:${GITHUB_ENV}'
    -v '${PERSISTENT_VARS_FILE}:${PERSISTENT_VARS_FILE}'
  "
  BUILDER_MOUNT_OPTS="${BUILDER_MOUNT_OPTS//$'\n'/}"
  OPENWRT_COMPILE_DIR="${BUILDER_WORK_DIR}/openwrt"
  OPENWRT_SOURCE_DIR="${BUILDER_TMP_DIR}/openwrt"
  OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"

  persistent_env_set HOST_TMP_DIR HOST_BIN_DIR
  persistent_env_set BUILDER_WORK_DIR BUILDER_TMP_DIR BUILDER_BIN_DIR BUILDER_PROFILE_DIR BUILDER_MOUNT_OPTS BUILD_TARGET
  append_docker_exec_env BUILDER_WORK_DIR BUILDER_TMP_DIR BUILDER_BIN_DIR BUILDER_PROFILE_DIR BUILD_TARGET

  persistent_env_set DK_EXEC_ENVS

  persistent_env_set OPENWRT_COMPILE_DIR OPENWRT_SOURCE_DIR OPENWRT_CUR_DIR
  append_docker_exec_env OPENWRT_COMPILE_DIR OPENWRT_SOURCE_DIR OPENWRT_CUR_DIR
  persistent_env_set DK_EXEC_ENVS
}

check_test() {
  # Prepare for test
  if [ "x${BUILD_MODE}" = "xtest" ]; then
    TEST=1
    persistent_env_set TEST
    append_docker_exec_env TEST
    persistent_env_set DK_EXEC_ENVS
  fi
}

load_task() {
  if [ -n "${ACT}" ]; then
    return
  fi
  # Load building action
  if [ "x${GITHUB_EVENT_NAME}" = "xpush" ]; then
    RD_TASK=""
    local commit_message
    commit_message="$(jq -crMe ".head_commit.message" "${GITHUB_EVENT_PATH}")"
    RD_TARGET="$(_extract_opt_from_string "target" "${commit_message}" "" "")"
  elif [ "x${GITHUB_EVENT_NAME}" = "xrepository_dispatch" ]; then
    RD_TASK="$(jq -crM '.action // ""' "${GITHUB_EVENT_PATH}")"
    RD_TARGET="$(jq -crM '.client_payload.target // ""' "${GITHUB_EVENT_PATH}")"
  elif [ "x${GITHUB_EVENT_NAME}" = "xdeployment" ]; then
    RD_TASK="$(jq -crM '.deployment.task // ""' "${GITHUB_EVENT_PATH}")"
    RD_TARGET="$(jq -crM '.deployment.payload.target // ""' "${GITHUB_EVENT_PATH}")"
  fi
  persistent_env_set RD_TASK RD_TARGET
}

prepare_target() {
  # Set for target
  if [ ! -d "${HOST_WORK_DIR}/user/${BUILD_TARGET}" ]; then
    echo "::error::Failed to find target ${BUILD_TARGET}" >&2
    exit 1
  fi

  # Load default and target configs
  if [ -d "${HOST_WORK_DIR}/user/default" ]; then
    cp -r "${HOST_WORK_DIR}/user/default" "${HOST_WORK_DIR}/user/current"
  else
    mkdir "${HOST_WORK_DIR}/user/current"
  fi

  # Manual combine user/$BUILD_TARGET into user/current instead of using rsync,
  # which will rename the file.ext to file-$BUILD_TARGET.ext
  cd "${HOST_WORK_DIR}/user/${BUILD_TARGET}/"
  find . -type d -exec mkdir -p ${HOST_WORK_DIR}/user/current/{} \;
  find . -type f -o -type l | while read file; do
    if [ -e "${HOST_WORK_DIR}/user/current/${file}" ]; then
      local dir_name="$(dirname "${file}")"
      local file_name="$(basename "${file}")"
      local base_name=${file_name%.*}
      local ext_name=${file_name##*.}
      if [ "x${ext_name}" != "x" ]; then  # file has extension
        ext_name=".$ext_name"
      fi

      cp  -a $file "${HOST_WORK_DIR}/user/current/${dir_name}/${base_name}-${BUILD_TARGET}${ext_name}"
    else
      cp -a $file "${HOST_WORK_DIR}/user/current/${file}"
    fi
  done

  # Not using rsync as it cannot rename file.ext to file-$BUILD_TARGET.ext
  #rsync -aI "${HOST_WORK_DIR}/user/${BUILD_TARGET}/" "${HOST_WORK_DIR}/user/current/"

  echo "Merged target profile structure:"
  tree "${HOST_WORK_DIR}/user/current"

  # if [ ! -f "${HOST_WORK_DIR}/user/current/config.diff" ]; then
  #   echo "::error::Config file 'config.diff' does not exist" >&2
  #   exit 1
  # fi

  # Load settings
  NECESSARY_SETTING_VARS=( BUILDER_NAME BUILDER_TAG REPO_URL REPO_BRANCH OPT_DEBUG )
  OPT_UPLOAD_CONFIG='1'
  SETTING_VARS=( "${NECESSARY_SETTING_VARS[@]}" OPT_UPLOAD_CONFIG )
  [ ! -f "${HOST_WORK_DIR}/user/${BUILD_TARGET}/settings.ini" ] || _source_vars "${HOST_WORK_DIR}/user/${BUILD_TARGET}/settings.ini" "${SETTING_VARS[@]}"
  _source_vars "${HOST_WORK_DIR}/user/${BUILD_TARGET}/settings.ini" "${SETTING_VARS[@]}"
  setting_missing_vars="$(_check_missing_vars "${NECESSARY_SETTING_VARS[@]}")"
  if [ -n "${setting_missing_vars}" ]; then
    echo "::error::Variables missing in 'user/${BUILD_TARGET}/settings.ini': ${setting_missing_vars}"
    exit 1
  fi

  # Base URL where to download the ImageBuilder and SDK
  OPENWRT_DOWNLOAD_SITE_URL="${PRE_BUILT_PACKAGES_SITE_URL}/releases/${REPO_VERSION}/targets/${CONFIG_TARGET_BOARD}/${CONFIG_TARGET_SUBTARGET}"
  # Base URL where to download the prebuilt packages
  OPENWRT_PACKAGES_URL="${PRE_BUILT_PACKAGES_SITE_URL}/releases/${REPO_VERSION}/packages/${CONFIG_TARGET_ARCH_PACKAGES}"
  SETTING_VARS=( "${SETTING_VARS[@]}" OPENWRT_DOWNLOAD_SITE_URL OPENWRT_PACKAGES_URL )

  persistent_env_set "${SETTING_VARS[@]}"
  append_docker_exec_env "${SETTING_VARS[@]}"
  
  BUILDER_IMAGE_ID_BUILDENV="kouhj/openwrt-buildenv:latest"
  BUILDER_CONTAINER_ID="${BUILDER_NAME}-${BUILD_TARGET}" # $BUILDER_NAME is from settings.ini
  persistent_env_set BUILDER_IMAGE_ID_BUILDENV BUILDER_CONTAINER_ID
  append_docker_exec_env BUILDER_IMAGE_ID_BUILDENV BUILDER_CONTAINER_ID
  persistent_env_set DK_EXEC_ENVS
}

# Load building options
load_options() {
  __set_env_and_docker_exec() {
    persistent_env_set "${1}"
    append_docker_exec_env "${1}"
  }
  for opt_name in ${BUILD_OPTS}; do
    _load_opt "${opt_name}" "" __set_env_and_docker_exec
  done
  persistent_env_set DK_EXEC_ENVS
}

update_builder_info() {
  if [ "x${TEST}" = "x1" ]; then
    BUILDER_TAG="test-${BUILDER_TAG}"
    persistent_env_set BUILDER_TAG
  fi
  local builder_full_name="${DK_REGISTRY:+$DK_REGISTRY/}${DK_USERNAME}/${BUILDER_NAME}-${BUILD_TARGET}"
  BUILDER_TAG_INC="${BUILDER_TAG}-inc"
  BUILDER_IMAGE_ID_BASE="${builder_full_name}:${BUILDER_TAG}"
  BUILDER_IMAGE_ID_INC="${builder_full_name}:${BUILDER_TAG_INC}"
  persistent_env_set BUILDER_IMAGE_ID_BASE BUILDER_IMAGE_ID_INC
}

check_validity() {
  if [ "x${OPT_DEBUG}" = "x1" ] && [ -z "${TMATE_ENCRYPT_PASSWORD}" ] && [ -z "${SLACK_WEBHOOK_URL}" ]; then
    echo "::error::To use debug mode, you should set either TMATE_ENCRYPT_PASSWORD or SLACK_WEBHOOK_URL in the 'Secrets' page for safety of your sensitive information. For details, please refer to https://git.io/JvfLS"
    echo "::error::In the reference URL you are instructed to use environment variables for them. However in this repo, you should set them in the 'Secrets' page"
    exit 1
  fi
}

prepare_dirs() {
  mkdir -p "${HOST_BIN_DIR}"
  chmod 777 "${HOST_BIN_DIR}"
  sudo mkdir "${HOST_TMP_DIR}"
  sudo chmod 777 "${HOST_TMP_DIR}"
}

main() {
  set -eo pipefail

  if [ "$1" = "build" ]; then
    BUILD_OPTS="update_feeds update_repo rebase rebuild debug push_when_fail package_only"
  fi

  # install_commands # all required commands are installed in container kouhj/openwrt-buildenv
  setup_envs
  prepare_dirs
  check_test
  load_task
  prepare_target
  load_options
  update_builder_info
  check_validity
}

if [ "x$1" = "xmain" ]; then
  shift
  main "$@"
fi
