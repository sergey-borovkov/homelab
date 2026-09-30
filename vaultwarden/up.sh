#!/usr/bin/env bash
# Vaultwarden behind the shared Caddy (~/homelab/caddy) at https://vault.daoseeking.duckdns.org:8443
# Re-run to update; vault in ./data. Old standalone vw-caddy/tplinkdns setup: up.sh.old-tplink
set -euo pipefail
cd "$(dirname "$0")"
docker pull vaultwarden/server:latest
docker rm -f vaultwarden vw-caddy 2>/dev/null || true

# Account exists (2026-09-30) -> signups closed. Set true temporarily to add another user.
docker run -d --name vaultwarden --restart unless-stopped \
  -p 127.0.0.1:8222:80 \
  -e DOMAIN="https://vault.daoseeking.duckdns.org:8443" \
  -e SIGNUPS_ALLOWED=false \
  -v "$PWD/data:/data" \
  vaultwarden/server:latest
