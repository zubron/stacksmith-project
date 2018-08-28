#!/bin/bash

set -euo pipefail

# The docker env has the db environment variables set for the boot script
(cd / && UPLOADS_DIR=/opt/stacksmith/user-uploads bash /opt/stacksmith/user-scripts/boot.sh)

exec "$@"
