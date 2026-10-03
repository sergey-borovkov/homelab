#!/usr/bin/env bash
# Caddy on the VPS (stock image, host network so it reaches apps on 127.0.0.1). Re-run to update.
# Certs/state in the caddy-data volume.
set -euo pipefail
cd "$(dirname "$0")"
docker pull caddy:2
docker rm -f caddy 2>/dev/null || true
docker run -d --name caddy --restart unless-stopped --network host \
  -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v caddy-data:/data -v caddy-config:/config \
  caddy:2
