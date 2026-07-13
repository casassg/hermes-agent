#!/bin/bash
# Two-step Fly deploy. `--build-only` pushes the image, then the 30s wait
# lets the Fly registry propagate before the machine update. A single
# `fly deploy` fails with MANIFEST_UNKNOWN due to a registry propagation race.
set -euo pipefail
cd "$(dirname "$0")/.."

./bin/flyctl deploy --build-only
echo "Waiting for 120 seconds..."
sleep 120
./bin/flyctl deploy
