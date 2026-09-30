#!/usr/bin/env bash
# DuckDNS updater: tells DuckDNS our current public IP every 5 min (TP-Link router can't do DuckDNS).
set -euo pipefail
cd "$(dirname "$0")"
docker pull lscr.io/linuxserver/duckdns:latest
docker rm -f duckdns 2>/dev/null || true
docker run -d --name duckdns --restart unless-stopped \
  --env-file .env -e TZ=Asia/Tbilisi -e PUID=1000 -e PGID=1000 \
  lscr.io/linuxserver/duckdns:latest
