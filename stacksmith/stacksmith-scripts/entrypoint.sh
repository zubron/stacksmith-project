#!/bin/bash

set -euo pipefail

# The docker env has the db environment variables set for the entrypoint script
(cd / && UPLOADS_DIR=/opt/stacksmith/user-uploads bash /opt/stacksmith/user-scripts/entrypoint.sh)

exec "$@"
