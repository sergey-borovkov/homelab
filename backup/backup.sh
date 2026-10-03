#!/usr/bin/env bash
# Nightly homelab backup to the SATA SSD (d2) + git mirror on d1. Keeps 14 days.
# Restore notes: ~/system-notes/homelab.md "Backups".
set -euo pipefail
H=/home/sergey/homelab
DEST=/home/sergey/data/d2/backups/homelab
MIRROR=/home/sergey/data/d1/backups/homelab.git
KEEP_DAYS=14
TS=$(date +%F_%H%M)
OUT=$DEST/$TS
umask 077
mkdir -p "$OUT"

# SQLite: online-consistent copies via the backup API (safe while the apps run)
SQLITE_PY='import sqlite3, sys
src = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True); dst = sqlite3.connect(sys.argv[2])
src.backup(dst); dst.close(); src.close()'
sqlite_backup() { python3 -c "$SQLITE_PY" "$1" "$2"; }
sqlite_backup "$H/shoko/config/Shoko.CLI/SQLite/JMMServer.db3" "$OUT/shoko-JMMServer.db3"
cp "$H/shoko/config/Shoko.CLI/settings-server.json" "$OUT/shoko-settings-server.json"

# Postgres: logical dumps
set -a; . "$H/bookorbit/.env"; set +a
docker exec bookorbit-db pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB" > "$OUT/bookorbit.pgdump"

# AdGuard Home config (root-owned inside the container -> read via docker)
docker exec adguard tar -C /opt/adguardhome -czf - conf > "$OUT/adguard-conf.tgz"

# *arr stack configs + DBs (owned by uid 1000; skip logs/covers/built-in backups)
tar -C "$H/arr" -czf "$OUT/arr.tgz" --exclude='*/logs' --exclude='*/logs.db*' --exclude='*/MediaCover' \
  --exclude='*/Backups' --exclude='*/cache' --exclude='*/log' --exclude='*/backup' \
  qbittorrent prowlarr sonarr radarr bazarr seerr 2>/dev/null || true
# root-owned app data -> read via the containers
docker exec uptime-kuma tar -C /app -czf - --exclude='data/screenshots' data > "$OUT/uptime-kuma.tgz"
docker exec homeassistant tar -C / -czf - --exclude='config/home-assistant_v2.db*' --exclude='config/*.log*' \
  --exclude='config/deps' --exclude='config/tts' config > "$OUT/homeassistant.tgz"
# Jellyfin: DB (users, watch history), plugin configs, server config. metadata/ and Shokofin VFS are rebuildable.
# ponytail: tar of a live SQLite (+wal) is usually consistent, stop the container first if a restore ever fails
docker exec jellyfin tar -C / -czf - --exclude='var/lib/jellyfin/metadata' --exclude='var/lib/jellyfin/Shokofin' \
  var/lib/jellyfin etc/jellyfin > "$OUT/jellyfin.tgz"

# Secrets + config + notes
tar -C "$H" -czf "$OUT/env-secrets.tgz" $(cd "$H" && ls */.env)
tar -C /home/sergey -czf "$OUT/system-notes.tgz" system-notes
git -C "$H" bundle create "$OUT/homelab.bundle" --all 2>/dev/null

# Third copy of the config history on d1
[ -d "$MIRROR" ] || git init -q --bare "$MIRROR"
git -C "$H" push -q --mirror "$MIRROR"

# Rotation
find "$DEST" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP_DAYS" -exec rm -rf {} +

# Apps on the VPS (~/homelab/vps): pull consistent copies over ssh. After the local steps, so a VPS problem
# fails the unit (-> Telegram alert) without costing the local copy. MicroBin shares are throwaway: not backed up.
ssh vps 'sudo python3 - homelab/vaultwarden/data/db.sqlite3 /tmp/vw-backup.sqlite3' <<<"$SQLITE_PY"
ssh vps 'sudo cat /tmp/vw-backup.sqlite3 && sudo rm /tmp/vw-backup.sqlite3' > "$OUT/vaultwarden-db.sqlite3"
ssh vps 'sudo tar -C homelab/vaultwarden/data -czf - --ignore-failed-read rsa_key.pem attachments' \
  > "$OUT/vaultwarden-files.tgz" 2>/dev/null
ssh vps docker exec ryot-db pg_dump -U postgres -Fc postgres > "$OUT/ryot.pgdump"
ssh vps docker exec actual tar -C / -czf - data > "$OUT/actual.tgz"
ssh vps docker exec uptime-kuma tar -C /app -czf - --exclude=data/screenshots data > "$OUT/uptime-kuma-vps.tgz"

# Off-site: encrypted, deduplicated restic snapshot on the VPS. Password: backup/.env + 1Password
# "Restic homelab backup".
set -a; . "$H/backup/.env"; set +a
export RESTIC_REPOSITORY=sftp:vps:restic
restic backup -q --host homelab --tag nightly "$OUT"
restic forget -q --host homelab --group-by host --keep-daily 14 --keep-weekly 8 --keep-monthly 6 --prune
echo "backup ok: $OUT ($(du -sh "$OUT" | cut -f1)), off-site snapshot on vps"
