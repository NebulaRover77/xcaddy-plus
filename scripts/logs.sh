#!/usr/bin/env bash
set -euo pipefail

CTX="${DOCKER_CONTEXT:-prod}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/compose.yaml}"

exec docker --context="$CTX" compose -f "$COMPOSE_FILE" logs -f --tail=200 "${@:-caddy}"
