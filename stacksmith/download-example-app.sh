#!/bin/bash
# Downloads example application and scripts for building.

set -euo pipefail

read -p "This will overwrite any files in user-scripts or user-uploads. Continue (y/n)? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Downloading the example app and scripts..."
    wget https://github.com/bitnami-labs/stacksmith-examples/raw/master/java-tomcat/customerapp/target/customerapp-1.0.0.war \
        -O user-uploads/customerapp.war --quiet
    wget https://raw.githubusercontent.com/bitnami-labs/stacksmith-examples/master/java-tomcat/customerapp/customerapp-boot.sh \
        -O user-scripts/entrypoint.sh --quiet
    echo "Done. You can now build the example with 'docker-compose build'."
fi
