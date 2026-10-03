#!/usr/bin/env bash
# Monthly access audit: who reached the homelab from outside, login/signup attempts, and the user list of every
# public app (a new user = someone registered). Report -> state/audit-<date>.txt + Telegram.
# Source: Caddy logs (outside visits only, kept 45 days) + app DBs/APIs. Run by homelab-audit.timer; manual: ./audit.sh
set -euo pipefail
cd "$(dirname "$0")"
H=/home/sergey/homelab
DAYS=${DAYS:-31}
SINCE=$(( $(date +%s) - DAYS*86400 ))
mkdir -p state
OUT=state/audit-$(date +%F).txt

caddy() { # outside requests of the period, one JSON per line
  { zcat -f "$H"/caddy/logs/access-*.log.gz 2>/dev/null; cat "$H/caddy/logs/access.log"; } |
    jq -c --argjson s "$SINCE" 'select(.ts >= $s and (.request.remote_ip | test("^(192\\.168\\.1\\.|127\\.|172\\.(1[6-9]|2[0-9]|3[01])\\.)") | not))
      | {ip: .request.remote_ip, host: (.request.host | sub("\\..*"; "")), m: .request.method, uri: .request.uri,
         st: .status, ua: (.request.headers["User-Agent"][0] // "-")}'
}

users() { # app users (name list) -> compare with last run
  local JK; JK=$(cat ~/.config/jellyfin-api-key)
  echo "jellyfin: $(curl -s -H "Authorization: MediaBrowser Token=\"$JK\"" http://127.0.0.1:8096/Users | jq -r '[.[].Name] | join(", ")')"
  local K; K=$(jq -r .main.apiKey "$H/arr/seerr/settings.json")
  echo "seerr: $(curl -s -H "X-Api-Key: $K" 'http://127.0.0.1:5055/api/v1/user?take=100' | jq -r '[.results[].displayName] | join(", ")')"
  echo "ryot: $(docker exec ryot-db psql -U postgres -At -c 'select string_agg(name, $$, $$ order by name) from "user"')"
  ( set -a; . "$H/bookorbit/.env"; docker exec bookorbit-db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At \
      -c 'select string_agg(username, $$, $$ order by username) from users' ) | sed 's/^/bookorbit: /'
  echo "vaultwarden: $(python3 -c 'import sqlite3,sys; c=sqlite3.connect(f"file:{sys.argv[1]}?mode=ro",uri=True); print(", ".join(r[0] for r in c.execute("select email from users order by email")))' "$H/vaultwarden/data/db.sqlite3")"
}

caddy > state/audit-period.jsonl
{
  echo "Homelab access audit, last $DAYS days (until $(date '+%F %H:%M'))"
  echo
  echo "== Outside visits per service (requests / unique IPs)"
  jq -rs 'group_by(.host)[] | "\(.[0].host): \(length) / \(map(.ip) | unique | length)"' state/audit-period.jsonl
  echo
  echo "== Top outside IPs (requests, services, client)"
  jq -rs 'group_by(.ip) | sort_by(-length)[:10][] | "\(.[0].ip)  \(length)  \(map(.host) | unique | join(","))  \(.[0].ua[:60])"' state/audit-period.jsonl
  echo
  echo "== Login / signup attempts (POST to login|auth|token|register|signup), by service and HTTP status"
  jq -rs '[.[] | select(.m == "POST" and (.uri | test("login|signin|auth|token|regist|signup"; "i")))]
    | group_by(.host)[] | "\(.[0].host): " + (group_by(.st) | map("\(.[0].st)×\(length)") | join(" "))' state/audit-period.jsonl
  echo "  signup URLs hit: $(jq -rs '[.[] | select(.uri | test("regist|signup"; "i") and (test("\\.js") | not)) | "\(.host)\(.uri[:40]) \(.st)"] | unique | join("; ") | if . == "" then "none" else . end' state/audit-period.jsonl)"
  echo
  echo "== Denied (401/403) per service"
  jq -rs '[.[] | select(.st == 401 or .st == 403)] | group_by(.host)[] | "\(.[0].host): \(length) from \(map(.ip) | unique | length) IPs"' state/audit-period.jsonl
  echo
  echo "== App users (a name you don't know = someone got in)"
  users | tee state/users-now.txt
  if [ -f state/users-last.txt ] && ! diff -q state/users-last.txt state/users-now.txt >/dev/null; then
    echo "!! CHANGED since last audit:"; diff state/users-last.txt state/users-now.txt | grep '^[<>]' || true
  fi
} > "$OUT"
mv state/users-now.txt state/users-last.txt
rm -f state/audit-period.jsonl

cat "$OUT"
[ -n "${NO_TG:-}" ] || ./tg.sh "$(head -c 3900 "$OUT")"$'\n\n'"Full report: ~/homelab/watchdog/$OUT"
