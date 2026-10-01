#!/usr/bin/env bash
# Heartbeat to healthchecks.io ("homelab PC" check). If these pings stop for >15 min (PC off/crashed, home internet
# down), healthchecks.io alerts from outside — the case Uptime Kuma on this PC can never report.
set -euo pipefail
. "$(dirname "$0")/.env"
curl -fsS -m 10 --retry 5 -o /dev/null "$HC_PING_URL"
