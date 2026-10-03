#!/usr/bin/env bash
# Stack in compose.yaml. Re-run to update: pulls images, restarts only containers whose image or config changed.
set -euo pipefail
cd "$(dirname "$0")"
docker compose up -d --pull always
