#!/usr/bin/env bash
# Jellyfin via plain docker run (replaced the Arch jellyfin-server package 2026-10-03).
# Re-run to update: bump TAG, run again. State lives on d1 and is mounted at the SAME paths the native
# install used (/var/lib/jellyfin, /etc/jellyfin, ...), so the DB, plugins and Shokofin's VFS stay valid.
# Media is mounted read-only at identical host paths (library paths + VFS symlink targets).
set -euo pipefail
TAG=12.1
D=/home/sergey/data/d1/jellyfin

if systemctl is-active -q jellyfin; then
  echo "native jellyfin.service still running: sudo systemctl disable --now jellyfin" >&2; exit 1
fi
# One-time: take over /etc/jellyfin (root disk) as $D/config, keeping ownership (uid 940).
[ -d "$D/config" ] || docker run --rm -v /etc/jellyfin:/src:ro -v "$D:/d" alpine cp -a /src /d/config

docker pull jellyfin/jellyfin:$TAG
docker rm -f jellyfin 2>/dev/null || true
docker run -d --name jellyfin --restart unless-stopped \
  --network host --user 940:940 --cpus 8 \
  -e TZ=Asia/Tbilisi \
  -e JELLYFIN_DATA_DIR=/var/lib/jellyfin -e JELLYFIN_CONFIG_DIR=/etc/jellyfin \
  -e JELLYFIN_CACHE_DIR=/var/cache/jellyfin -e JELLYFIN_LOG_DIR=/var/log/jellyfin \
  -v "$D/lib:/var/lib/jellyfin" -v "$D/config:/etc/jellyfin" \
  -v "$D/cache:/var/cache/jellyfin" -v "$D/log:/var/log/jellyfin" \
  -v /home/sergey/data/d1/anime:/home/sergey/data/d1/anime:ro \
  -v /home/sergey/data/d2/media:/home/sergey/data/d2/media:ro \
  -v /home/sergey/media:/home/sergey/media:ro \
  -v "/home/sergey/Kristina Videos:/home/sergey/Kristina Videos:ro" \
  jellyfin/jellyfin:$TAG
