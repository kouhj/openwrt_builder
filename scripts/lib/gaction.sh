#!/bin/bash

# shellcheck disable=SC1090
source "${BASH_SOURCE%/*}/utils.sh"

_dump_file() {
  echo "Dumping file $1"
  cat $1
}

echo "GITHUB_ENV: $GITHUB_ENV"
_set_env() {
  for var_name in "$@" ; do
    eval "export ${var_name}"
    local var_value="${!var_name}"
    var_value="${var_value//%/%25}"
    var_value="${var_value//$'\n'/%0A}"
    var_value="${var_value//$'\r'/%0D}"
    
    echo "${var_name}=${var_value} >> $GITHUB_ENV"
    echo "${var_name}=${var_value}" >> $GITHUB_ENV
  done
  echo "Appending vars $* to $GITHUB_ENV"
  _dump_file $GITHUB_ENV
}

# $GITHUB_ENV file is usually located at /home/runner/work/_temp/_runner_file_commands/ with name pattern "set_env_{GUID}"
_docker_set_env() {
  [ -f /.dockerenv ] || return 0
  for var_name in "$@" ; do
    eval "export ${var_name}"
    local var_value="${!var_name}"
    var_value="${var_value//%/%25}"
    var_value="${var_value//$'\n'/%0A}"
    var_value="${var_value//$'\r'/%0D}"

    vars_file="$(dirname $GITHUB_ENV)/docker-vars"
    echo "${var_name}=${var_value} >> $vars_file"
    echo "${var_name}=${var_value}" >> $vars_file
  done
  echo "Appending vars $* to $vars_file"
  _dump_file $vars_file
}

_docker_load_env() {
  [ -f /.dockerenv ] || return 0
  vars_file="$(dirname $GITHUB_ENV)/docker-vars"
  if [ -f $vars_file ]; then
    echo "Load vars from $vars_file"
    source $vars_file
  else
    echo "No vars file found at $vars_file"
  fi
}

_set_env_prefix() {
  for var_name_prefix in "$@" ; do
    eval '_set_env "${!'"${var_name_prefix}"'@}"'
  done
}

_get_opt() {
  local opt_name="${1}"
  opt_name="$(tr '[:upper:]' '[:lower:]' <<<"${opt_name}")"
  local opt_default="${2}"
  local opt_value
  if [ "x${GITHUB_EVENT_NAME}" = "xpush" ]; then
    local commit_message
    commit_message="$(jq -crMe ".head_commit.message" "${GITHUB_EVENT_PATH}")"
    opt_value="$(_extract_opt_from_string "${opt_name}" "${commit_message}" "${opt_default}" 1)"
  elif [ "x${GITHUB_EVENT_NAME}" = "xrepository_dispatch" ]; then
    opt_value="$(jq -crM '(.client_payload.'"${opt_name}"' // "'"${opt_default}"'") as $v | if ($v|type=="boolean") then (if $v then 1 else 0 end) else $v end' "${GITHUB_EVENT_PATH}")"
  elif [ "x${GITHUB_EVENT_NAME}" = "xdeployment" ]; then
    opt_value="$(jq -crM '(.deployment.payload.'"${opt_name}"' // "'"${opt_default}"'") as $v | if ($v|type=="boolean") then (if $v then 1 else 0 end) else $v end' "${GITHUB_EVENT_PATH}")"
  else
    opt_value="${opt_default}"
  fi
  echo -n "${opt_value}"
}

_load_opt() {
  local opt_name="${1}"
  local opt_default="${2}"
  local cb="${3}"
  local opt_name_upper
  local opt_name_lower
  opt_name_upper="$(echo -n "${opt_name}" | tr '[:lower:]' '[:upper:]')"
  opt_name_lower="$(echo -n "${opt_name}" | tr '[:upper:]' '[:lower:]')"
  local ENV_OPT_NAME="OPT_${opt_name_upper}"
  eval "${ENV_OPT_NAME}='$(_get_opt "${opt_name_lower}" "${opt_default}")'"
  [ -z "${cb}" ] || ${cb} "${ENV_OPT_NAME}"
}
