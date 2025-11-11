# syntax=docker/dockerfile:1.4

FROM caddy:2-builder AS builder
ENV GOTOOLCHAIN=auto
RUN xcaddy build \
  --with github.com/caddy-dns/he \
  --with github.com/xcaddyplugins/caddy-trusted-cloudfront \
  --output /usr/bin/caddy

FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
