#!/usr/bin/env bash
# Mealie (recipes, meal plan, shared shopping list). Public via Caddy at https://meals.daoseeking.duckdns.org:8443,
# own login, sign-up only via invite link. Home Assistant reads/writes the shopping lists (Mealie integration).
set -euo pipefail
cd "$(dirname "$0")"
docker pull ghcr.io/mealie-recipes/mealie:latest
docker rm -f mealie 2>/dev/null || true
docker run -d --name mealie --restart unless-stopped \
  -p 127.0.0.1:9925:9000 \
  -e PUID=1000 -e PGID=1000 -e TZ=Asia/Tbilisi \
  -e BASE_URL=https://meals.daoseeking.duckdns.org:8443 \
  -e ALLOW_SIGNUP=false -e TOKEN_TIME=8760 \
  -e MAX_WORKERS=1 -e WEB_CONCURRENCY=1 \
  -v "$PWD/data:/app/data" \
  ghcr.io/mealie-recipes/mealie:latest
