#!/usr/bin/env bash
# Home Assistant (container). Public at https://ha.daoseeking.uk (VPS front door; own login + TOTP 2FA, IP ban after 5 fails).
# Host network (device discovery, Matter/mDNS). Config in ./config (gitignored, backed up).
# Custom integrations via HACS; Dreame Vacuum (Tasshack) v2 for the Dreame X50 Ultra (Dreamehome account).
# Xiaomi Home: one entry per region (China: CN-market devices, Singapore: global ones). New devices don't
# appear on reload/restart: Xiaomi Home entry -> Configure -> "Update devices". Then rerun dashboard_xiaomi.py.
# Outdoor ozone/NO2/dust/UV: Open-Meteo REST sensors in config/configuration.yaml. Alerts: automations.py.
set -euo pipefail
cd "$(dirname "$0")"
docker pull ghcr.io/home-assistant/home-assistant:stable
docker rm -f homeassistant 2>/dev/null || true
docker run -d --name homeassistant --restart unless-stopped --network host --cap-add NET_ADMIN --cap-add NET_RAW \
  -e TZ=Asia/Tbilisi -v "$PWD/config:/config" -v /run/dbus:/run/dbus:ro \
  ghcr.io/home-assistant/home-assistant:stable
