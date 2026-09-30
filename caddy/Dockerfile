# Caddy + DuckDNS DNS plugin: certs via DNS-01, since the ISP blocks inbound 80/443.
FROM caddy:2-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/duckdns
FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
