#!/bin/bash

set -euo pipefail

source /opt/stacksmith/stacksmith-scripts/functions.sh

main() {
  # Give priority to user's provided run.sh if available, otherwise run the template specific
  # run.sh
  local script=/opt/stacksmith/user-scripts/run.sh
  if [ ! -f $script ]; then
    script=/opt/stacksmith/stacksmith-scripts/run-template.sh
  fi

  # script invoked using ". <script>" so the functions sourced above are available for the user's script
  cd / && . "${script}"
}

main
