#!/usr/bin/env bash
# Disk space alerts to Telegram. Levels: 0 ok, 1 >=95%, 2 >=98%. Messages only when the level changes
# (state in ./state/), so a full disk alerts once, not every 5 minutes. Runs from homelab-heartbeat.service.
set -euo pipefail
cd "$(dirname "$0")"; mkdir -p state
for m in / /home /home/sergey/data/d1 /home/sergey/data/d2; do
  read -r pct avail < <(df -P -BG "$m" | awk 'NR==2 {gsub("%","",$5); gsub("G","",$4); print $5, $4}')
  lvl=0; [ "$pct" -ge 95 ] && lvl=1; [ "$pct" -ge 98 ] && lvl=2
  f=state/disk$(echo "$m" | tr / _); old=$(cat "$f" 2>/dev/null || echo 0)
  if [ "$lvl" -gt "$old" ]; then
    icon=$([ "$lvl" = 2 ] && echo "🔴" || echo "🟠")
    ./tg.sh "$icon Disk $m is ${pct}% full — only ${avail} GB left"
  elif [ "$lvl" -lt "$old" ] && [ "$lvl" = 0 ]; then
    ./tg.sh "✅ Disk $m is back to ${pct}% (${avail} GB free)"
  fi
  echo "$lvl" > "$f"
done
