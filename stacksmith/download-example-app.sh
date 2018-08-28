#!/bin/bash
# Downloads example application and scripts for building.

set -euo pipefail
read -p "This will overwrite any files in user-scripts or user-uploads. Continue (y/n)? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Downloading the example app and scripts..."

    wget https://raw.githubusercontent.com/bitnami-labs/stacksmith-examples/master/generic/minio/scripts/build.sh \
        -O user-scripts/build.sh --quiet
    wget https://raw.githubusercontent.com/bitnami-labs/stacksmith-examples/master/generic/minio/scripts/run.sh \
        -O user-scripts/run.sh --quiet

    echo "Done. You can now build with 'docker-compose build'."
fi

