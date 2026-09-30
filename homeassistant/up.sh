#!/usr/bin/env bash
# Home Assistant (container). LAN-only via Caddy: https://home.daoseeking.duckdns.org:8443
# Host network (device discovery, Matter/mDNS). Config in ./config (gitignored, backed up).
# Custom integrations via HACS; Dreame Vacuum (Tasshack) v2 for the Dreame X50 Ultra (Dreamehome account).
set -euo pipefail
cd "$(dirname "$0")"
docker pull ghcr.io/home-assistant/home-assistant:stable
docker rm -f homeassistant 2>/dev/null || true
docker run -d --name homeassistant --restart unless-stopped --network host --cap-add NET_ADMIN --cap-add NET_RAW \
  -e TZ=Asia/Tbilisi -v "$PWD/config:/config" -v /run/dbus:/run/dbus:ro \
  ghcr.io/home-assistant/home-assistant:stable
