#!/usr/bin/env bash
# Zipline (files, text pastes, short links; expiring links) + Postgres. RUNS ON THE VPS:
# https://share.daoseeking.uk . Own login (first visit created the admin; registration stays off).
# Uploads in ./uploads (throwaway shares, not backed up), DB in the zipline-db volume. Re-run to update.
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./.env; set +a
docker network inspect zipline >/dev/null 2>&1 || docker network create zipline
docker pull postgres:16
docker pull ghcr.io/diced/zipline:latest
docker rm -f zipline zipline-db 2>/dev/null || true

docker run -d --name zipline-db --network zipline --restart unless-stopped \
  -e POSTGRES_USER=zipline -e POSTGRES_PASSWORD -e POSTGRES_DB=zipline \
  -v zipline-db:/var/lib/postgresql/data postgres:16
for _ in $(seq 1 30); do docker exec zipline-db pg_isready -U zipline >/dev/null 2>&1 && break; sleep 2; done

docker run -d --name zipline --network zipline --restart unless-stopped -p 127.0.0.1:3005:3000 \
  -e DATABASE_URL="postgres://zipline:$POSTGRES_PASSWORD@zipline-db:5432/zipline" -e CORE_SECRET \
  -e CORE_PORT=3000 -e CORE_HOSTNAME=0.0.0.0 -e CORE_TRUST_PROXY=true -e CORE_TRUSTED_PROXIES=172.16.0.0/12 \
  -e CORE_RETURN_HTTPS_URLS=true -e CORE_DEFAULT_DOMAIN=share.daoseeking.uk \
  -e DATASOURCE_TYPE=local -e DATASOURCE_LOCAL_DIRECTORY=/zipline/uploads \
  -e TZ=Asia/Tbilisi \
  -v "$PWD/uploads:/zipline/uploads" -v "$PWD/public:/zipline/public" \
  ghcr.io/diced/zipline:latest
