#!/usr/bin/env bash
# Vaultwarden. RUNS ON THE VPS, behind ~/homelab/vps/Caddyfile at https://vault.daoseeking.uk
# (old vault.daoseeking.duckdns.org:8443 is forwarded there by home Caddy). Re-run to update; vault in ./data.
set -euo pipefail
cd "$(dirname "$0")"
docker pull vaultwarden/server:latest
docker rm -f vaultwarden 2>/dev/null || true

# Account exists (2026-09-30) -> signups closed. Set true temporarily to add another user.
docker run -d --name vaultwarden --restart unless-stopped \
  -p 127.0.0.1:8222:80 \
  -e DOMAIN="https://vault.daoseeking.uk" \
  -e SIGNUPS_ALLOWED=false \
  -v "$PWD/data:/data" \
  vaultwarden/server:latest
