# homelab

Docker services on the desktop (CachyOS). One folder per service; `./<svc>/up.sh` pulls and
recreates it (data persists in named volumes or ignored data dirs). Secrets are in `<svc>/.env`
(untracked); `.env.example` lists the keys.

Docs, the why, and gotchas: `~/system-notes/homelab.md` and `~/system-notes/home-network.md`.

| Folder | What |
|---|---|
| caddy | HTTPS reverse proxy, wildcard cert via DuckDNS DNS-01, :443/:8443 |
| duckdns | keeps daoseeking.duckdns.org pointed at the public IP |
| adguard | **AdGuard Home** LAN DNS (192.168.1.216:53) + ad blocking; UI http://192.168.1.216:3080 |
| dns | OLD dnsmasq home-dns, replaced by adguard 2026-09-30 (container stopped, kept for rollback) |
| ryot | media tracker (Jellyfin webhook sink) |
| bookorbit | ebooks/manga library |
| shoko | anime file identification for Shokofin |
| vaultwarden | password manager server |
| net | CAKE upload shaping systemd unit (install with sudo, see system-notes) |
