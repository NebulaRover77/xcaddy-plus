#!/usr/bin/env bash
set -euo pipefail

CTX="${DOCKER_CONTEXT:-prod}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/compose.yaml}"

# Validate config (no reload)
exec docker --context="$CTX" compose -f "$COMPOSE_FILE" exec caddy \
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
