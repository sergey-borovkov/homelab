#!/usr/bin/env bash
# AdGuard Home: LAN DNS with ad/tracker blocking. Replaces the old dnsmasq home-dns (~/homelab/dns).
# Web UI LAN-only: http://192.168.1.216:3080 . Config/state in ./conf and ./work (gitignored, backed up).
# Re-run to update.
set -euo pipefail
cd "$(dirname "$0")"
docker pull adguard/adguardhome:latest
docker rm -f adguard 2>/dev/null || true
docker run -d --name adguard --restart unless-stopped --network host \
  -v "$PWD/conf:/opt/adguardhome/conf" -v "$PWD/work:/opt/adguardhome/work" \
  adguard/adguardhome:latest \
  --no-check-update -c /opt/adguardhome/conf/AdGuardHome.yaml -w /opt/adguardhome/work \
  --web-addr 192.168.1.216:3080
