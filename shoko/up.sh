#!/usr/bin/env bash
# Shoko Server via plain docker run. Re-run to update (pulls latest, recreates; config persists in ./config).
# Media mounted read-only at the SAME paths as on the host, so Shoko/Shokofin/Jellyfin all agree on file paths.
set -euo pipefail
cd "$(dirname "$0")"
docker pull ghcr.io/shokoanime/server:latest
docker rm -f shoko 2>/dev/null || true
docker run -d --name shoko --restart unless-stopped --shm-size 256m \
  -p 127.0.0.1:8111:8111 \
  -e PUID=1000 -e PGID=1000 -e TZ=Asia/Tbilisi \
  -v "$PWD/config:/home/shoko/.shoko" \
  -v /home/sergey/data/d1/anime:/home/sergey/data/d1/anime:ro \
  -v /home/sergey/media:/home/sergey/media:ro \
  -v /home/sergey/data/d2/media/anime:/home/sergey/data/d2/media/anime:ro \
  ghcr.io/shokoanime/server:latest
