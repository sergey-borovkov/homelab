#!/usr/bin/env bash
# Actual Budget (YNAB replacement). Public via Caddy: https://budget.daoseeking.duckdns.org:8443
# Data (budgets, server password) in ./data (gitignored, backed up). Re-run to update.
set -euo pipefail
cd "$(dirname "$0")"
docker pull actualbudget/actual-server:latest
docker rm -f actual 2>/dev/null || true
docker run -d --name actual --restart unless-stopped -p 127.0.0.1:5006:5006 \
  -e TZ=Asia/Tbilisi -v "$PWD/data:/data" actualbudget/actual-server:latest
