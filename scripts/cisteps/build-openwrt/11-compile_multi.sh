#!/bin/bash

set -xeo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

echo "started=1" >> $GITHUB_OUTPUT
docker_exec -e MODE=m "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/compile.sh"
