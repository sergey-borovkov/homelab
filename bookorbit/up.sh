#!/usr/bin/env bash
# BookOrbit + pgvector Postgres via plain docker run (translated from upstream docker-compose.yml).
# Re-run to update: pulls latest images and recreates containers; data persists
# (Postgres in the bookorbit-db volume, app data in ./data, books in ./books).
set -euo pipefail
cd "$(dirname "$0")"
set -a; source .env; set +a

docker network inspect bookorbit >/dev/null 2>&1 || docker network create bookorbit
docker pull pgvector/pgvector:pg18
docker pull ghcr.io/bookorbit/bookorbit:latest
docker rm -f bookorbit-app bookorbit-db 2>/dev/null || true

docker run -d --name bookorbit-db --network bookorbit --network-alias postgres --restart unless-stopped \
  -e POSTGRES_USER -e POSTGRES_PASSWORD -e POSTGRES_DB \
  -e PGDATA=/var/lib/postgresql/data/pgdata \
  -v bookorbit-db:/var/lib/postgresql/data \
  pgvector/pgvector:pg18

# compose waits for the db healthcheck; do the same by hand
for _ in $(seq 1 30); do
  docker exec bookorbit-db pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1 && break
  sleep 2
done

docker run -d --name bookorbit-app --network bookorbit --restart unless-stopped --init \
  -p 127.0.0.1:3000:3000 \
  -e NODE_ENV=production -e PORT=3000 \
  -e POSTGRES_HOST=postgres -e POSTGRES_PORT=5432 \
  -e POSTGRES_USER -e POSTGRES_PASSWORD -e POSTGRES_DB \
  -e JWT_SECRET -e PODCAST_ENCRYPTION_KEY -e SETUP_BOOTSTRAP_TOKEN \
  -e APP_URL=https://books.daoseeking.duckdns.org:8443 -e CLIENT_URL=https://books.daoseeking.duckdns.org:8443 \
  -e TZ=Asia/Tbilisi -e PUID=1000 -e PGID=1000 -e NODE_MAX_OLD_SPACE_SIZE=2048 \
  -v "$PWD/books:/books" -v "$PWD/data:/data" \
  -v "/home/sergey/data/d1/sergey/The Prince of Tennis (2012-2013) (Digital) (Shellshock):/books/The Prince of Tennis (Manga):ro" \
  --read-only --tmpfs /tmp \
  --cap-drop ALL --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER --cap-add SETGID --cap-add SETUID \
  --security-opt no-new-privileges:true --stop-timeout 30 \
  ghcr.io/bookorbit/bookorbit:latest
