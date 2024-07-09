#!/bin/bash

# shellcheck disable=SC1090
source "${BASH_SOURCE%/*}/utils.sh"

_dump_file() {
  echo "Dumping file $1"
  cat $1
}

PERSISTENT_VARS_FILE_BASENAME='_persistent_vars.sh'
#if [ -f /.dockerenv ]; then
#  PERSISTENT_VARS_FILE="${BUILDER_TMP_DIR}/${PERSISTENT_VARS_FILE_BASENAME}"
#else
#  PERSISTENT_VARS_FILE="${HOST_TMP_DIR}/${PERSISTENT_VARS_FILE_BASENAME}"
#fi
PERSISTENT_VARS_FILE=$(dirname "$GITHUB_ENV")"/$PERSISTENT_VARS_FILE_BASENAME"
[ -f "$GITHUB_ENV" ] && source "$GITHUB_ENV"
[ -f "$PERSISTENT_VARS_FILE" ] && source "$PERSISTENT_VARS_FILE"
echo -e "GITHUB_ENV: $GITHUB_ENV\nPERSISTENT_VARS_FILE: $PERSISTENT_VARS_FILE"


# Save the var to the file, if the var exists, update it, otherwise, append it to the file
__save_var_to_file() {
    local var_name="${1}"
    local var_value="${2}"
    local var_file="${3}"
    [ -f "$var_file" ] || touch "$var_file"
    if grep -E -q "^${var_name}=\"${var_value}\"" "$var_file"; then # NOP when the var does not change
      :
    elif grep -E -q "^${var_name}=" "$var_file"; then # update the var if it exists
      echo "updating ${var_name}=\"${var_value}\" in $var_file"
		  #sed -i -r "s~^.*($var_name)=.*\$~\1=\"$var_value\"~" "$var_file"
      #Do not use sed -i, it does not work for a file mounted from the host to the container
      # If there is a space in the value, use double quotes to wrap it
      if [[ "$var_value" =~ \  ]]; then
        sed -r "s~^.*($var_name)=.*\$~\1=\"$var_value\"~" "$var_file" > "$var_file.tmp" && cp "$var_file.tmp" "$var_file" && rm "$var_file.tmp"
      else
        sed -r "s~^.*($var_name)=.*\$~\1=${var_value}~" "$var_file" > "$var_file.tmp" && cp "$var_file.tmp" "$var_file" && rm "$var_file.tmp"
      fi
	  else # this var does not exist in the file
      echo "setting ${var_name}=\"${var_value}\" to $var_file"
      # if there is a space in the value, use double quotes to wrap it
      if [[ "$var_value" =~ \  ]]; then
        echo "${var_name}=\"$var_value\"" >> "$var_file"
      else
        echo "${var_name}=${var_value}" >> "$var_file"
      fi
	  fi
}

# Remove the var from the file
__remove_var_from_file() {
  local var_name="${1}"
  local var_file="${2}"
  if [ -f "$var_file" ]; then
    sed -r "/^${var_name}=/d" "$var_file" > "$var_file.tmp" && cp "$var_file.tmp" "$var_file" && rm "$var_file.tmp"
  fi
}

# Merge all the vars in $1 to $2 one by one.
# If a var exists in $2, update it, otherwise, append it to $2
__merge_var_files() {
  local src_file="${1}"
  local dest_file="${2}"
  if [ -f "$src_file" ]; then
    while IFS= read -r line; do
      local var_name="${line%%=*}"
      local var_value="${line#*=}"
      __save_var_to_file "${var_name}" "${var_value}" "${dest_file}"
    done < "$src_file"
  fi
}

# Set a persistent env var for all runner steps as well as inside the docker container
# As the GITHUB_ENV file name might change after each step, this function tries to keep
# the env vars in a file in the runner host, and mount it to the docker container.
# Both the runner and the container can read/write the env vars to the file.
# $GITHUB_ENV file is usually located at /home/runner/work/_temp/_runner_file_commands/ with name pattern "set_env_{GUID}"
persistent_env_set() {
  for var_name in "$@" ; do
    local var_value="${!var_name}"
    eval "${var_name}=\"${var_value}\"; export ${var_name}"
    var_value="${var_value//%/%25}"
    var_value="${var_value//$'\n'/%0A}"
    var_value="${var_value//$'\r'/%0D}"

    __save_var_to_file "${var_name}" "${var_value}" "${PERSISTENT_VARS_FILE}"
    __save_var_to_file "${var_name}" "${var_value}" "${GITHUB_ENV}"
  done
}

# Remove a persistent env var from the file
persistent_env_unset() {
  for var_name in "$@" ; do
    eval "unset ${var_name}"
    __remove_var_from_file "${var_name}" "${PERSISTENT_VARS_FILE}"
    __remove_var_from_file "${var_name}" "${GITHUB_ENV}"
  done
}

#  _persistent_env_load() loads the env vars from the persistent file, and export to the calling shell.
#  If running inside the runner, the env vars will also be updated to the $GITHUB_ENV file.
persistent_env_load() {
  vars_file="${PERSISTENT_VARS_FILE}"
  if [ -f $vars_file ]; then
    echo "Load vars from $vars_file"
    source $vars_file
    _dump_file $vars_file
    echo "End of vars."
    if [ ! -f /.dockerenv ]; then
      __merge_var_files $vars_file $GITHUB_ENV
    fi
  else
    echo "No vars file found: $vars_file"
  fi
}


# The docker env vars file is physically in the host machine, and mounted to container by "-v" option.
# When the build completes, it's required to make a backup into the container for the load build.
save_docker_env_file_in_container() {
  if [ -n "BUILDER_ARCH_BASE_DIR" ]; then
    cp -u ${PERSISTENT_VARS_FILE} ${BUILDER_ARCH_BASE_DIR}/
  else
    echo "Folder $BUILDER_ARCH_BASE_DIR is not set"
    status=failure
    echo "::set-env name=status::$status"
    exit 1
  fi
}

# Load the docer env vars file from the container back into the host
load_docker_env_file_from_container() {
  BUILDER_ARCH_BASE_DIR="${BUILDER_WORK_DIR}/kbuilder/${BUILD_TARGET}"
  if [ -f ${BUILDER_ARCH_BASE_DIR}/${PERSISTENT_VARS_FILE_BASENAME} ]; then
    cp -a ${BUILDER_ARCH_BASE_DIR}/${PERSISTENT_VARS_FILE_BASENAME} ${PERSISTENT_VARS_FILE}
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
