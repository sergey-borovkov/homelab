#!/usr/bin/env bash
# Second Uptime Kuma, ON THE VPS: checks every public URL from outside (both the front door and the
# .home:8443 direct path) and alerts to Telegram. https://status.daoseeking.uk (own login).
# The home Kuma (~/homelab/uptime-kuma) keeps checking the LAN-only tools. Data in ./kuma-data. Re-run to update.
set -euo pipefail
cd "$(dirname "$0")"
docker pull louislam/uptime-kuma:2
docker rm -f uptime-kuma 2>/dev/null || true
docker run -d --name uptime-kuma --restart unless-stopped -p 127.0.0.1:3001:3001 \
  -e TZ=Asia/Tbilisi -v "$PWD/kuma-data:/app/data" louislam/uptime-kuma:2
