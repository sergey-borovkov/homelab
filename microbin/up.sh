#!/usr/bin/env bash
# MicroBin (Rust): pastes with syntax highlighting + file sharing with expiring links. RUNS ON THE VPS.
# https://share.daoseeking.uk . Anyone with a link can read; creating needs the uploader password
# (1Password "MicroBin share.daoseeking.uk", same as admin). Data in ./data. Re-run to update.
set -euo pipefail
cd "$(dirname "$0")"
docker pull danielszabo99/microbin:latest
docker rm -f microbin 2>/dev/null || true
docker run -d --name microbin --restart unless-stopped -p 127.0.0.1:8082:8080 \
  --env-file .env \
  -e MICROBIN_PUBLIC_PATH=https://share.daoseeking.uk/ -e MICROBIN_TITLE="daoseeking share" \
  -e MICROBIN_READONLY=true -e MICROBIN_PRIVATE=true -e MICROBIN_ETERNAL_PASTA=false \
  -e MICROBIN_DEFAULT_EXPIRY=24hour -e MICROBIN_ENABLE_BURN_AFTER=true \
  -e MICROBIN_HIGHLIGHTSYNTAX=true -e MICROBIN_QR=true \
  -e MICROBIN_ENCRYPTION_CLIENT_SIDE=true -e MICROBIN_ENCRYPTION_SERVER_SIDE=true \
  -e MICROBIN_MAX_FILE_SIZE_ENCRYPTED_MB=2048 -e MICROBIN_MAX_FILE_SIZE_UNENCRYPTED_MB=10240 \
  -e MICROBIN_DISABLE_TELEMETRY=true -e TZ=Asia/Tbilisi \
  -v "$PWD/data:/app/microbin_data" \
  danielszabo99/microbin:latest
