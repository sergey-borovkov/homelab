#!/usr/bin/env bash
# Tiny dnsmasq for the LAN. Re-run to rebuild/recreate.
set -euo pipefail
cd "$(dirname "$0")"
docker build -q -t home-dns:local .
docker rm -f home-dns 2>/dev/null || true
docker run -d --name home-dns --restart unless-stopped --network host \
  -v "$PWD/dnsmasq.conf:/etc/dnsmasq.conf:ro" --cap-add NET_ADMIN \
  home-dns:local
