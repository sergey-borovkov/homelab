#!/usr/bin/env bash
# Cloudflare DDNS: keeps *.home.daoseeking.uk pointed at our current public IP (the direct :8443 path).
# Token (Zone DNS edit for daoseeking.uk) comes from 1Password "CF API Token" -> .env. Re-run to update.
set -euo pipefail
cd "$(dirname "$0")"
docker pull favonia/cloudflare-ddns:latest
docker rm -f ddns 2>/dev/null || true
docker run -d --name ddns --restart unless-stopped \
  --env-file .env -e DOMAINS='*.home.daoseeking.uk' -e PROXIED=false -e IP6_PROVIDER=none -e RECORD_COMMENT='home IP, kept current by ~/homelab/ddns' -e TZ=Asia/Tbilisi \
  --user 1000:1000 --read-only --cap-drop ALL --security-opt no-new-privileges:true \
  favonia/cloudflare-ddns:latest
