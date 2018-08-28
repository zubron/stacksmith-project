#!/bin/bash

set -euo pipefail

installDependencies() {
    yum install -y unzip
}

main() {
    installDependencies
}

main
