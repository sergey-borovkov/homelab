#!/usr/bin/env bash
# Lets this PC use a Tailscale exit node without breaking the homelab: these rules run before
# Tailscale's (pref 5270, "lookup 52" = everything via the exit node) and keep on the home ISP:
#   - the LAN and Docker networks (container port forwarding),
#   - the VPS itself (otherwise it loops through its own tunnel),
#   - replies from the LAN IP (outside visitors on :8443 -> Caddy),
#   - everything containers send (qBittorrent must never leave via Oracle).
# Desktop apps (browser, Steam, ...) go through the exit node as intended.
# Usage: exit-node-bypass.sh [add|del]   (installed as net/exit-node-bypass.service)
set -euo pipefail
op=${1:-add}
rules=(
  "to 192.168.1.0/24"
  "to 172.16.0.0/12"
  "to 204.216.220.169"
  "from 192.168.1.216"
  "from 172.16.0.0/12"
)
for r in "${rules[@]}"; do
  ip rule del pref 5200 $r lookup main 2>/dev/null || true
  [ "$op" = add ] && ip rule add pref 5200 $r lookup main
done
# ...but tailnet addresses still go via Tailscale, from containers too: default-bridge containers use
# MagicDNS (100.100.100.100, copied from the host's resolv.conf) and break without it.
ip rule del pref 5190 to 100.64.0.0/10 lookup 52 2>/dev/null || true
[ "$op" = add ] && ip rule add pref 5190 to 100.64.0.0/10 lookup 52
ip rule show | grep -E '^51[0-9]0|^5200'
