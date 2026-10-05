#!/usr/bin/env bash
# Quake Live dedicated server on the free Oracle x86 micro (Ubuntu 24.04, 1 GB). Safe to re-run (also updates QL).
#   ssh quake 'sudo bash -s' < quake/setup.sh
# Oracle security list must allow UDP 27960 in (done in the console, vps VCN's default list).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
timedatectl set-timezone Asia/Tbilisi

# Oracle's image firewall rejects everything but ssh
R=/etc/iptables/rules.v4
rule="-p udp --dport 27960 -j ACCEPT"
grep -qF -- "-A INPUT $rule" $R || sed -i "/^-A INPUT -j REJECT/i -A INPUT $rule" $R
iptables-restore < $R

# 1 GB RAM: swap so steamcmd and apt don't get OOM-killed
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

apt-get update -q
apt-get install -yq lib32gcc-s1 curl ca-certificates

cat > /etc/apt/apt.conf.d/52homelab-reboot <<'EOF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "05:00";
EOF

# steamcmd + QL dedicated (app 349090, anonymous login works)
sudo -u ubuntu bash -euo pipefail <<'EOF'
mkdir -p ~/steamcmd && cd ~/steamcmd
[ -x steamcmd.sh ] || curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xz
# first runs often fail with "Missing configuration" and still exit 0, so retry until the binary is there
for i in 1 2 3; do
  ./steamcmd.sh +force_install_dir ~/ql +login anonymous +app_update 349090 validate +quit | grep -E "Success|ERROR" || true
  [ -x ~/ql/qzeroded.x64 ] && break
done
[ -x ~/ql/qzeroded.x64 ]
# SteamAPI_Init looks for the client lib here; without it players can't authenticate
mkdir -p ~/.steam/sdk64 && ln -sf ~/steamcmd/linux64/steamclient.so ~/.steam/sdk64/steamclient.so
mkdir -p ~/.quakelive/27960/baseq3
cat > ~/.quakelive/27960/baseq3/server.cfg <<'CFG'
set sv_hostname "daoseeking"
set sv_tags "daoseeking"
set sv_maxclients 16
set g_password "q"
set sv_mappoolfile "mappool.txt"
set g_allowVote 1
set g_inactivity 0
set zmq_stats_enable 0
set zmq_rcon_enable 0
CFG
EOF

cat > /etc/systemd/system/quake.service <<'EOF'
[Unit]
Description=Quake Live dedicated server
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/ql
ExecStart=/home/ubuntu/ql/run_server_x64.sh +set net_strict 1 +set net_port 27960 +set fs_homepath /home/ubuntu/.quakelive/27960 +exec server.cfg +map campgrounds ffa
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable quake
systemctl restart quake
