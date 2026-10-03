#!/usr/bin/env bash
# Homepage dashboard (gethomepage.dev). Host network so widgets reach 127.0.0.1 services; bound to 127.0.0.1:3002,
# served by Caddy at https://dash.daoseeking.duckdns.org:8443 (outside: Tinyauth login). Secrets: .env (HOMEPAGE_VAR_*).
set -euo pipefail
cd "$(dirname "$0")"
docker pull ghcr.io/gethomepage/homepage:latest
docker rm -f homepage 2>/dev/null || true
docker run -d --name homepage --restart unless-stopped --network host \
  --env-file .env \
  -e PORT=3002 -e HOSTNAME=127.0.0.1 \
  -e HOMEPAGE_ALLOWED_HOSTS=dash.daoseeking.duckdns.org:8443,dash.daoseeking.duckdns.org,dash.daoseeking.uk,dash.home.daoseeking.uk,dash.home.daoseeking.uk:8443,dash.ts.daoseeking.uk,127.0.0.1:3002 \
  -e PUID=1000 -e PGID=946 -e TZ=Asia/Tbilisi \
  -v "$PWD/config:/app/config" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /home/sergey/data/d1:/mnt/d1:ro -v /home/sergey/data/d2:/mnt/d2:ro \
  ghcr.io/gethomepage/homepage:latest
