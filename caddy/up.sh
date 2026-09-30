#!/usr/bin/env bash
# Caddy reverse proxy (host network so it reaches native Jellyfin on localhost:8096).
# Certs/state live in the caddy-data volume (under /home/docker-data).
set -euo pipefail
cd "$(dirname "$0")"
docker build -q -t caddy-duckdns:local .
docker rm -f caddy 2>/dev/null || true
docker run -d --name caddy --restart unless-stopped --network host \
  -v "$PWD/Caddyfile:/etc/caddy/Caddyfile:ro" \
  -v caddy-data:/data -v caddy-config:/config \
  --env-file ../duckdns/.env \
  caddy-duckdns:local
