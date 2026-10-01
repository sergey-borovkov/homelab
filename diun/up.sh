#!/usr/bin/env bash
# Diun: weekly check (Sat 10:00) for new versions of every running container's image -> Telegram (DaoSeeking Robot).
# Only notifies; updating stays manual (re-run the service's up.sh). First run just records the current digests.
set -euo pipefail
cd "$(dirname "$0")"
docker pull crazymax/diun:latest
docker rm -f diun 2>/dev/null || true
docker run -d --name diun --restart unless-stopped \
  --env-file .env \
  -e TZ=Asia/Tbilisi -e LOG_LEVEL=info \
  -e DIUN_WATCH_SCHEDULE="0 10 * * 6" -e DIUN_WATCH_JITTER=30s -e DIUN_WATCH_WORKERS=4 \
  -e DIUN_WATCH_FIRSTCHECKNOTIF=false -e DIUN_WATCH_RUNONSTARTUP=true \
  -e DIUN_PROVIDERS_DOCKER=true -e DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT=true \
  -v "$PWD/data:/data" -v /var/run/docker.sock:/var/run/docker.sock:ro \
  crazymax/diun:latest
