#!/bin/bash

set -eo pipefail

# shellcheck disable=SC1090
source "${HOST_WORK_DIR}/scripts/host/docker.sh"

COMPILE_STARTED=1
persistent_env_set COMPILE_STARTED
docker_exec -e MODE=m "${BUILDER_CONTAINER_ID}" "${BUILDER_WORK_DIR}/scripts/compile.sh"
