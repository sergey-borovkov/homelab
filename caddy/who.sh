#!/usr/bin/env bash
# Who hit the public :8443 endpoints? External IPs only (LAN/localhost filtered out).
# Usage: ./who.sh [N]   -> top N IPs (default 20) with hit count, hosts, statuses, sample paths
set -euo pipefail
cd "$(dirname "$0")/logs"
cat access.log* 2>/dev/null | jq -r 'select(.request.remote_ip|test("^(192\\.168\\.|127\\.|172\\.)")|not)
  | [.request.remote_ip, (.request.host|sub(":8443$";"")), (.status|tostring), .request.uri] | @tsv' |
awk -F'\t' '{n[$1]++; h[$1][$2]=1; s[$1][$3]++; if(!(($1,$4) in seen)&&c[$1]<3){p[$1]=p[$1]" "$4; c[$1]++; seen[$1,$4]=1}}
  END{for(ip in n){hs="";for(x in h[ip])hs=hs x" ";st="";for(x in s[ip])st=st x"x"s[ip][x]" ";printf "%5d  %-16s %-40s %-18s%s\n",n[ip],ip,hs,st,p[ip]}}' |
sort -rn | head -"${1:-20}"
