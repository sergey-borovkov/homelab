FROM alpine:3
RUN apk add --no-cache dnsmasq
ENTRYPOINT ["dnsmasq", "--keep-in-foreground", "--log-facility=-", "--conf-file=/etc/dnsmasq.conf"]
