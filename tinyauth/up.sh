#!/usr/bin/env bash
# Tinyauth: login page + session cookie in front of LAN-only tools reached from outside (Caddy forward_auth).
# Used instead of HTTP basic auth because iOS home-screen web apps never show the basic-auth prompt.
# Login page: https://auth.daoseeking.uk (cookie covers *.daoseeking.uk) ; user list (bcrypt) in .env.
set -euo pipefail
cd "$(dirname "$0")"
docker pull ghcr.io/tinyauthapp/tinyauth:v5
docker rm -f tinyauth 2>/dev/null || true
docker run -d --name tinyauth --restart unless-stopped --network host \
  --env-file .env \
  -e TINYAUTH_APPURL=https://auth.daoseeking.uk \
  -e TINYAUTH_SERVER_ADDRESS=127.0.0.1 -e TINYAUTH_SERVER_PORT=3010 \
  -e TINYAUTH_AUTH_SECURECOOKIE=true \
  -e TINYAUTH_AUTH_SESSIONEXPIRY=2592000 -e TINYAUTH_AUTH_SESSIONMAXLIFETIME=31536000 \
  -e TINYAUTH_AUTH_TRUSTEDPROXIES=127.0.0.1 \
  -e TINYAUTH_ANALYTICS_ENABLED=false \
  -e TZ=Asia/Tbilisi \
  -v "$PWD/data:/data" \
  ghcr.io/tinyauthapp/tinyauth:v5
