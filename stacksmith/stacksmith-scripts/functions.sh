#!/bin/bash

set -euo pipefail

# Shared bash functions for built images.

# Conventions: This file contains two kind of functions and variables:
# intended for public use (i.e. user-scripts/stacksmith-scripts) and
# helper/private functions. Each kind must use the `stacksmith_`,
# `__stacksmith_` prefixes respectively.

readonly __stacksmith_user_data_file=/opt/stacksmith/user-data
readonly __stacksmith_cfn_user_data_file=/opt/stacksmith/cfn-user-data
readonly __aws_metadata_api_endpoint=http://169.254.169.254/latest
readonly __azure_agent_directory=/var/lib/waagent

stacksmith_refresh_user_data() {
    if [ -d "${__azure_agent_directory}" ] ; then
        stacksmith_refresh_user_data_azure
    else
        stacksmith_refresh_user_data_aws
    fi
}

stacksmith_refresh_user_data_aws() {
  # if the user data was retrieved using cfn-init and was already handled, do not perform anything
  local endpoint
  endpoint="${__aws_metadata_api_endpoint}/user-data/"
  local error_file
  error_file=$(mktemp)
  local output
  output=$(curl --retry 5 -sSf "${endpoint}" -w "\n%{http_code}" 2> "${error_file}" || true)
  local body="${output: 0:-4}" # -4 to drop extra newline
  local status_code="${output: -3}" # last three chars is the status code

  if [ "${status_code}" = "200" ]; then
    echo "${body}" > "${__stacksmith_user_data_file}"
  elif [ "${status_code}" = "404" ]; then
    # If no user-data is provided at all the AWS endpoint returns 404
    echo "" > "${__stacksmith_user_data_file}"
  else
    echo "Cannot retrieve user-data:" >&2
    cat "${error_file}" >&2
    return 1
  fi

  # Based on bitnami-cloud-lib's `aws_get_userdata`
  # Check and handle the case of user-data provided in gzip format.
  if (file "${__stacksmith_user_data_file}" | grep -qs gzip); then
    mv "${__stacksmith_user_data_file}" "${__stacksmith_user_data_file}.gz"
    gunzip "${__stacksmith_user_data_file}.gz"
  fi

  chown root:root "${__stacksmith_user_data_file}"
  chmod 600 "${__stacksmith_user_data_file}"

  # if CFN_INIT_ENABLED was passed in user data, call cfn-init
  if [ "$(stacksmith_get_user_parameter CFN_INIT_ENABLED)" != "" ] ; then
    stacksmith_perform_cfn_init
  fi
}

stacksmith_refresh_user_data_azure() {
    local timeout=120
    local provisioned_flag_file="${__azure_agent_directory}/provisioned"
    local provisioned=0
    for _ in $(seq 1 "${timeout}") ; do
        if [ -f "${provisioned_flag_file}" ]  ; then
            provisioned=1
            break
        fi
        sleep 1
    done
    if [ "${provisioned}" -ne 1 ] ; then
        echo -e "${provisioned_flag_file} didn't exist after ${timeout} seconds. Is there a problem with waagent?" >&2
        return 1
    fi

    local custom_data_file="${__azure_agent_directory}/CustomData"
    # Custom data in Azure is a base64 encoded JSON
    # The result will be `export`-friendly key-value pairs
    # field1=val1
    # field2=val2
    touch "${__stacksmith_user_data_file}" && chmod 600 "${__stacksmith_user_data_file}"
    base64 -d < "${custom_data_file}" | jq -r 'keys[] as $k | "\($k)=\(.[$k])"' > "${__stacksmith_user_data_file}"
}

stacksmith_perform_cfn_init() {
  /opt/aws/bin/cfn-init -v \
    --stack "$(stacksmith_get_user_parameter CFN_INIT_STACK)" \
    --resource "$(stacksmith_get_user_parameter CFN_INIT_RESOURCE)" \
    --region "$(stacksmith_get_user_parameter CFN_INIT_REGION)"

  # if cfn-init created a user data file, read it and append to the user data file
  if [ -f "${__stacksmith_cfn_user_data_file}" ] ; then
    cat "${__stacksmith_cfn_user_data_file}" >>"${__stacksmith_user_data_file}"
  fi
}

__stacksmith_get_user_parameters_raw() {
  # Give the user a chance to provide parameters via cloud-init, a
  # script, build time or even manually by saving them to
  # `/opt/stacksmith/user-parameters`, otherwise fallback to raw
  # user-data. Benefits:
  # - We give an alternative to hijacking user-data for stacksmith
  # parameters so it can be left free for orchestration systems.
  # - If the user don't need user-data for anything else it can be
  # used as a simpler approach.
  # - If parameters aren't provided in any way, when the instance
  # boots, the entrypoint will halt and nothing would happen until
  # parameters are set, allowing for an extra step of configuration.
  # After manual editing of the parameters file and a reboot the
  # entrypoint script would get to run properly.
  # - `user-parameters` could be potentially used for debugging
  # purposes to determine the right user-data the instance would need
  # to run properly.
  local parameters_file=/opt/stacksmith/user-parameters
  if [ -f "${parameters_file}" ]; then
    cat "${parameters_file}"
  else
    cat "${__stacksmith_user_data_file}"
  fi
}

stacksmith_get_user_parameter() {
  # Based on bitnami-cloud-lib's `_get_parameter_from_user_data`
  local parameter=$1
  local line
  line=$(__stacksmith_get_user_parameters_raw | egrep "^(\\s*#\\s*|^)(${parameter})\\s*=" | head -1)
  if [ -n "${line}" ]; then
    # Remove prefix, trailing spaces and quote marks around values.
    # Also allow things like "# DATABASE_HOST=dbhost" to be parsed so
    # that user parameters can also be injected as part of scripts
    # given at user-data.
    echo "${line}" | sed "s,^\\s*#\\s*,,;s,${parameter}\\s*=\\s*,,;s,\\s*$,,;s,^\"\\(.*\\)\"$,\\1,"
    return 0
  fi
  return 1
}

# TODO: This function is setting the environment it may cause sensitive
# information leaks in spawned processes. Possible alternative: only expose
# stacksmith parameters via a utility function and not environment variables.
stacksmith_get_user_parameters_env() {
  if [ $# == 0 ]; then
    echo -e "Please provide at least one parameter name to fetch"
    return 1
  fi

  local required_parameters=(${@})
  local missing=""
  local expansion=""
  local value

  for parameter in "${required_parameters[@]}"; do
    value=$(stacksmith_get_user_parameter "${parameter}")
    if [ $? -ne 0 ]; then
      missing="${missing}- ${parameter}\n"
    else
      # The following is only supported in Bash 4.4+ where as our Centos images
      # use 4.2, hence using printf instead.
      # expansion="${parameter}=${value@Q} ${expansion}"
      expansion="${parameter}=$(printf '%q\n' "${value}") ${expansion}"
    fi
  done

  if [ -n "${missing}" ]; then
    # Halt entrypoint early in case of missing parameters.
    echo -e "Please set the following parameters:\n${missing}" >&2
    return 1
  fi

  echo "${expansion}"
}

stacksmith_get_db_parameters_env() {
  local required_parameters=(
    "DATABASE_HOST"
    "DATABASE_PORT"
    "DATABASE_USER"
    "DATABASE_PASSWORD"
    "DATABASE_NAME"
    "DATABASE_TYPE"
  )

  stacksmith_get_user_parameters_env ${required_parameters[@]}
}

stacksmith_run_user_pre_build_steps() {
  # Check if the user has provided a pre-build step for Stacksmith.
  # If so, execute the script using the hooks directory as the working directory.
  if [ -f "/opt/stacksmith/user-hooks/stacksmith-pre-build.sh" ]; then
    cd /
    bash /opt/stacksmith/user-hooks/stacksmith-pre-build.sh
  fi
}
