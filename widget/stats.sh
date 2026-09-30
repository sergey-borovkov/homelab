#!/usr/bin/env bash
# CPU% and RAM (MiB) per container + native Jellyfin, one "name cpu mem" line each.
# Read by the KDE Self-hosted widget (org.sergey.selfhosted) every 30 s.
docker stats --no-stream --format '{{.Name}} {{.CPUPerc}} {{.MemUsage}}' 2>/dev/null |
  awk '{gsub("%","",$2); m=$3; u=m; gsub(/[0-9.]/,"",u); gsub(/[A-Za-z]/,"",m);
        if(u=="GiB")m*=1024; else if(u=="KiB")m/=1024; else if(u=="B")m/=1048576;
        printf "%s %.1f %.0f\n",$1,$2,m}'
pid=$(systemctl show jellyfin -p MainPID --value 2>/dev/null)
if [ -n "$pid" ] && [ "$pid" != 0 ]; then
  cpu=$(top -b -n 2 -d 0.5 -p "$pid" | awk -v p="$pid" '$1==p{c=$9} END{print c+0}')
  rss=$(ps -o rss= -p "$pid")
  printf 'jellyfin %.1f %.0f\n' "$cpu" "$((rss/1024))"
fi
