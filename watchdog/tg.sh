#!/usr/bin/env bash
# Send a Telegram message via the DaoSeeking Robot: tg.sh "text"
set -euo pipefail
. "$(dirname "$0")/.env"
curl -fsS -m 15 --retry 3 -o /dev/null "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
  --data-urlencode "chat_id=$TG_CHAT_ID" --data-urlencode "text=$1"
