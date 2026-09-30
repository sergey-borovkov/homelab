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
sqlite_backup() { python3 - "$1" "$2" <<'PY'
import sqlite3, sys
src = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True); dst = sqlite3.connect(sys.argv[2])
src.backup(dst); dst.close(); src.close()
PY
}
sqlite_backup "$H/vaultwarden/data/db.sqlite3" "$OUT/vaultwarden-db.sqlite3"
cp "$H"/vaultwarden/data/rsa_key*.pem "$OUT/" 2>/dev/null || true
[ -d "$H/vaultwarden/data/attachments" ] && tar -C "$H/vaultwarden/data" -czf "$OUT/vaultwarden-attachments.tgz" attachments
sqlite_backup "$H/shoko/config/Shoko.CLI/SQLite/JMMServer.db3" "$OUT/shoko-JMMServer.db3"
cp "$H/shoko/config/Shoko.CLI/settings-server.json" "$OUT/shoko-settings-server.json"

# Postgres: logical dumps
docker exec ryot-db pg_dump -U postgres -Fc postgres > "$OUT/ryot.pgdump"
set -a; . "$H/bookorbit/.env"; set +a
docker exec bookorbit-db pg_dump -U "$POSTGRES_USER" -Fc "$POSTGRES_DB" > "$OUT/bookorbit.pgdump"

# Secrets + config + notes
tar -C "$H" -czf "$OUT/env-secrets.tgz" $(cd "$H" && ls */.env)
tar -C /home/sergey -czf "$OUT/system-notes.tgz" system-notes
git -C "$H" bundle create "$OUT/homelab.bundle" --all 2>/dev/null

# Third copy of the config history on d1
[ -d "$MIRROR" ] || git init -q --bare "$MIRROR"
git -C "$H" push -q --mirror "$MIRROR"

# Rotation
find "$DEST" -mindepth 1 -maxdepth 1 -type d -mtime +"$KEEP_DAYS" -exec rm -rf {} +
echo "backup ok: $OUT ($(du -sh "$OUT" | cut -f1))"
