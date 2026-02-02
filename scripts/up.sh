#!/usr/bin/env bash
set -euo pipefail

CTX="${DOCKER_CONTEXT:-alpine}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/compose.yaml}"

exec docker --context="$CTX" compose -f "$COMPOSE_FILE" up -d "$@"
