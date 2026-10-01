#!/usr/bin/env bash
# Disk space alert to Telegram: one message when a disk reaches 99%, one all-clear when it is back under 98%
# (hysteresis, so a disk hovering at 99% doesn't flap). State in ./state/. Runs from homelab-heartbeat.service.
set -euo pipefail
cd "$(dirname "$0")"; mkdir -p state
for m in / /home /home/sergey/data/d1 /home/sergey/data/d2; do
  read -r pct avail < <(df -P -BG "$m" | awk 'NR==2 {gsub("%","",$5); gsub("G","",$4); print $5, $4}')
  f=state/disk$(echo "$m" | tr / _); old=$(cat "$f" 2>/dev/null || echo 0)
  if [ "$old" = 1 ]; then lvl=$([ "$pct" -ge 98 ] && echo 1 || echo 0); else lvl=$([ "$pct" -ge 99 ] && echo 1 || echo 0); fi
  [ "$lvl" = 1 ] && [ "$old" = 0 ] && ./tg.sh "🔴 Disk $m is ${pct}% full — only ${avail} GB left"
  [ "$lvl" = 0 ] && [ "$old" = 1 ] && [ "$m" != reset ] && ./tg.sh "✅ Disk $m is back to ${pct}% (${avail} GB free)"
  echo "$lvl" > "$f"
done
