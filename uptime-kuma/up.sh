#!/usr/bin/env bash
# Uptime Kuma: monitors homelab services, alerts to Telegram. LAN-only via Caddy:
# https://status.daoseeking.duckdns.org:8443 . Host network so it can probe localhost ports.
# Data in ./data (gitignored, backed up). Re-run to update.
set -euo pipefail
cd "$(dirname "$0")"
docker pull louislam/uptime-kuma:2
docker rm -f uptime-kuma 2>/dev/null || true
docker run -d --name uptime-kuma --restart unless-stopped --network host \
  -e TZ=Asia/Tbilisi -e UPTIME_KUMA_HOST=127.0.0.1 -e UPTIME_KUMA_PORT=3001 \
  -v "$PWD/data:/app/data" louislam/uptime-kuma:2
