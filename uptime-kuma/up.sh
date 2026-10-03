#!/usr/bin/env bash
# Uptime Kuma. RUNS ON THE VPS: https://status.daoseeking.uk (own login). Checks every public URL from
# outside (front door + .home:8443 direct path), the VPS apps, and the LAN-only home tools over Tailscale
# (<app>.ts.daoseeking.uk; those go red while the desktop is on the work tailnet). Alerts to Telegram.
# Data in ./data. Re-run to update.
set -euo pipefail
cd "$(dirname "$0")"
docker pull louislam/uptime-kuma:2
docker rm -f uptime-kuma 2>/dev/null || true
docker run -d --name uptime-kuma --restart unless-stopped -p 127.0.0.1:3001:3001 \
  -e TZ=Asia/Tbilisi -v "$PWD/data:/app/data" louislam/uptime-kuma:2
