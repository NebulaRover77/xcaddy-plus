# syntax=docker/dockerfile:1.4

FROM caddy:2-builder AS builder
ENV GOTOOLCHAIN=auto
RUN xcaddy build \
  --with github.com/caddy-dns/he \
  --with github.com/xcaddyplugins/caddy-trusted-cloudfront \
  --output /usr/bin/caddy

FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
#COPY Caddyfile /etc/caddy/Caddyfile
#RUN chmod 666 /etc/caddy/Caddyfile
#RUN caddy fmt --overwrite /etc/caddy/Caddyfile
#RUN chmod 444 /etc/caddy/Caddyfile
RUN mkdir -p /data/caddy
RUN chmod 1777 /data
RUN chmod 1777 /data/caddy
RUN mkdir -p /config
RUN chmod 1777 /config
RUN mkdir -p /certs
RUN chmod 1777 /certs

#CMD ["caddy", "run", "--resume"]
