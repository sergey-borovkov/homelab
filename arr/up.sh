#!/usr/bin/env bash
# *arr media automation: qBittorrent (headless) + Prowlarr + Sonarr + Radarr + Bazarr + Seerr.
# Media lives on d2 and is mounted at the SAME path in every container (no path mapping):
#   /home/sergey/data/d2/media/{downloads,tv,movies,anime}  (one filesystem -> hardlinks, no copies)
# Configs in ./<app> (gitignored, backed up). Re-run to update.
set -euo pipefail
cd "$(dirname "$0")"
M=/home/sergey/data/d2/media
COMMON=(--network arr --restart unless-stopped -e PUID=1000 -e PGID=1000 -e TZ=Asia/Tbilisi -e UMASK=002)

docker network inspect arr >/dev/null 2>&1 || docker network create arr
for img in lscr.io/linuxserver/qbittorrent lscr.io/linuxserver/prowlarr lscr.io/linuxserver/sonarr \
           lscr.io/linuxserver/radarr lscr.io/linuxserver/bazarr ghcr.io/seerr-team/seerr ghcr.io/flaresolverr/flaresolverr; do
  docker pull -q "$img:latest"
done
docker rm -f qbittorrent prowlarr sonarr radarr bazarr seerr flaresolverr 2>/dev/null || true

docker run -d --name qbittorrent "${COMMON[@]}" -e WEBUI_PORT=8090 -e TORRENTING_PORT=6881 \
  -p 127.0.0.1:8090:8090 -p 6881:6881 -p 6881:6881/udp \
  -v "$PWD/qbittorrent:/config" -v "$M:$M" lscr.io/linuxserver/qbittorrent:latest
docker run -d --name prowlarr "${COMMON[@]}" -p 127.0.0.1:9696:9696 \
  -v "$PWD/prowlarr:/config" lscr.io/linuxserver/prowlarr:latest
docker run -d --name sonarr "${COMMON[@]}" -p 127.0.0.1:8989:8989 \
  -v "$PWD/sonarr:/config" -v "$M:$M" lscr.io/linuxserver/sonarr:latest
docker run -d --name radarr "${COMMON[@]}" -p 127.0.0.1:7878:7878 \
  -v "$PWD/radarr:/config" -v "$M:$M" lscr.io/linuxserver/radarr:latest
docker run -d --name bazarr "${COMMON[@]}" -p 127.0.0.1:6767:6767 \
  -v "$PWD/bazarr:/config" -v "$M:$M" lscr.io/linuxserver/bazarr:latest
docker run -d --name seerr --network arr --restart unless-stopped --init -e TZ=Asia/Tbilisi \
  -p 127.0.0.1:5055:5055 -v "$PWD/seerr:/app/config" ghcr.io/seerr-team/seerr:latest
# Solves Cloudflare challenges for Prowlarr (EZTV, 1337x). Only reachable inside the arr network.
docker run -d --name flaresolverr --network arr --restart unless-stopped -e TZ=Asia/Tbilisi \
  ghcr.io/flaresolverr/flaresolverr:latest
