#!/usr/bin/env bash
# Base setup of the Oracle VPS (Ubuntu 26.04, ARM). Safe to re-run. From the desktop:
#   ssh vps 'sudo bash -s' < vps/setup.sh
# Then once: sudo tailscale up --advertise-exit-node (login link), approve the exit node in the admin console.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
timedatectl set-timezone Asia/Tbilisi

# Oracle's image firewall rejects everything but ssh. Open web + Tailscale, and drop its FORWARD reject
# (Docker and the exit node need forwarding). The Oracle security list in front of the VM is the real firewall.
R=/etc/iptables/rules.v4
for rule in "-p tcp -m multiport --dports 80,443,8443 -j ACCEPT" "-p udp --dport 41641 -j ACCEPT"; do
  grep -qF -- "-A INPUT $rule" $R || sed -i "/^-A INPUT -j REJECT/i -A INPUT $rule" $R
done
sed -i '/^-A FORWARD -j REJECT/d' $R
iptables-restore < $R
for u in docker tailscaled; do systemctl -q is-active $u && systemctl restart $u; done   # restore flushed their chains

apt-get update -q
apt-get -yq upgrade
apt-get install -yq docker.io docker-compose-v2 git
usermod -aG docker ubuntu

# Security updates already install daily (image default); reboot at 05:00 when one needs it
cat > /etc/apt/apt.conf.d/52homelab-reboot <<'EOF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "05:00";
EOF

# Tailscale exit node
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
printf 'net.ipv4.ip_forward = 1\nnet.ipv6.conf.all.forwarding = 1\n' > /etc/sysctl.d/99-tailscale.conf
sysctl -q -p /etc/sysctl.d/99-tailscale.conf

# Heartbeat to healthchecks.io ("vps" check, URL in ~/homelab/vps/.env): silence > 15 min -> email + Telegram
echo '*/5 * * * * ubuntu . /home/ubuntu/homelab/vps/.env && curl -fsS -m 10 --retry 5 -o /dev/null "$HC_PING_URL"' \
  > /etc/cron.d/homelab-heartbeat
