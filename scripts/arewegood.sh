#!/usr/bin/env bash
set -euo pipefail

CTX="${DOCKER_CONTEXT:-alpine}"

docker --context="$CTX" compose ps

# hard fail if not running
if ! docker --context="$CTX" compose ps --status running | grep -q caddy; then
  echo "caddy is not running" >&2
  exit 1
fi

# show only recent logs (last 2 minutes)
docker --context="$CTX" compose logs --since=2m caddy

docker --context="$CTX" compose exec caddy sh -lc \
  'ls -alh /etc/caddy && ls -alh /config/caddy && ls -alh /data/caddy'
