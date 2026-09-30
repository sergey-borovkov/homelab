#!/usr/bin/env bash
# Ryot + Postgres via plain docker run (no compose plugin installed).
# Re-run to update: pulls latest v10 images and recreates containers; data stays in the ryot-db volume.
set -euo pipefail
cd "$(dirname "$0")"
source .env

docker network inspect ryot >/dev/null 2>&1 || docker network create ryot
docker pull postgres:18-alpine
docker pull ghcr.io/ignisda/ryot:v10
docker rm -f ryot ryot-db 2>/dev/null || true

docker run -d --name ryot-db --network ryot --restart unless-stopped \
  -e POSTGRES_DB=postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
  -e TZ=Asia/Tbilisi \
  -v ryot-db:/var/lib/postgresql \
  postgres:18-alpine

docker run -d --name ryot --network ryot --restart unless-stopped \
  -p 8000:8000 \
  -e DATABASE_URL="postgres://postgres:$POSTGRES_PASSWORD@ryot-db:5432/postgres" \
  -e SERVER_ADMIN_ACCESS_TOKEN="$SERVER_ADMIN_ACCESS_TOKEN" \
  -e MOVIES_AND_SHOWS_TMDB_ACCESS_TOKEN="${MOVIES_AND_SHOWS_TMDB_ACCESS_TOKEN:-}" \
  -e FRONTEND_URL=https://ryot.daoseeking.duckdns.org:8443 \
  -e TZ=Asia/Tbilisi \
  ghcr.io/ignisda/ryot:v10
