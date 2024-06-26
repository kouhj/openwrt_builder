#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${BUILDER_WORK_DIR}/scripts/lib/gaction.sh"

OPENWRT_CUR_DIR="${OPENWRT_COMPILE_DIR}"
# if we are not fresh building
if [ -d "${OPENWRT_COMPILE_DIR}" ]; then
  OPENWRT_CUR_DIR="${OPENWRT_SOURCE_DIR}"
  if [ -d "${OPENWRT_CUR_DIR}" ]; then
    # probably caused by a broken builder upload
    rm -rf "${OPENWRT_CUR_DIR}"
  fi
fi

persistent_env_set OPENWRT_CUR_DIR

[ "x${TEST}" != "x1" ] || exit 0

# Load docker env vars file that were saved in previous build(s)
load_docker_env_file_from_container

# Remove stale GITHUB env files (created for more than 1 day ago)
find $(dirname $GITHUB_ENV) -type f -ctime +1 -delete;

exit 0 # All dependant package should be ready by kouhj/openwrt-buildenv container
############################# CODE UNREACHABLE FROM THIS POINT BEYOND ######################################

# Install missing packages in current env from a remote list
sudo -E apt-get -qq update
sudo -E apt-get -qq upgrade -y
if [ ! -x "$(command -v curl)" ]; then
    echo "curl not found, installing..."
    sudo -E apt-get -qq install curl
fi
packages_file="${BUILDER_TMP_DIR}/packages.txt"
packages_url="https://github.com/tete1030/openwrt-buildenv/raw/master/packages.txt"
(
  set +eo pipefail
  
  rm -f "${packages_file}" || true
  echo "Downloading package list from ${packages_url}"
  curl -sLo "${packages_file}" "${packages_url}"
  ret_val=$?
  if [ $ret_val -ne 0 ]; then
    rm -f "${packages_file}" || true
    echo "Downloading package list failed"
  fi
  true
)

# additional packages to cross run binaries in the target rootfs built by the builder
cat >> "${packages_file}" << EOF
proot
qemu-user
tmux
byobu
EOF

if [ -f "${packages_file}" ]; then
  echo "Installing missing packages"
  mapfile -t all_packages < <(grep -vE -e "^\s*#" -e "^\s*\$" "${packages_file}")
  sudo -E apt-get -qq install --no-upgrade "${all_packages[@]}"
  echo "Installed packages: ${all_packages[*]}"
  rm -f "${packages_file}"
fi
