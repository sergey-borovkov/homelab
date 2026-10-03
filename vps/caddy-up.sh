#!/usr/bin/env bash
# Caddy on the VPS (stock image, host network so it reaches apps on 127.0.0.1). Re-run to update.
# Certs/state in the caddy-data volume. Folder mount (not the file) so "caddy reload" sees rsynced edits:
#   rsync -a vps/ vps:homelab/vps/ && ssh vps docker exec caddy caddy reload --config /etc/caddy/Caddyfile
set -euo pipefail
cd "$(dirname "$0")"
docker pull caddy:2
docker rm -f caddy 2>/dev/null || true
docker run -d --name caddy --restart unless-stopped --network host \
  -v "$PWD:/etc/caddy:ro" -v "$PWD/../site:/srv/site:ro" \
  -v caddy-data:/data -v caddy-config:/config \
  caddy:2
