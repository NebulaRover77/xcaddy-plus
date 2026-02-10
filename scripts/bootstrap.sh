#!/usr/bin/env bash
set -euo pipefail

CTX="${DOCKER_CONTEXT:-prod}"
NETWORK="${NETWORK_NAME:-shared}"

# Resolve repo root (assumes this script lives in ./scripts)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CADDYFILE_LOCAL="${CADDYFILE_LOCAL:-$ROOT/Caddyfile}"
COMPOSE_FILE="${COMPOSE_FILE:-$ROOT/compose.yaml}"

ETC_VOL="caddy-etc-data"
VOLUMES=(
  "$ETC_VOL"
  "caddy-config-data"
  "caddy-certs-data"
  "caddy-data-data"
)

log() { printf '%s\n' "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

ensure_network() {
  if docker --context="$CTX" network inspect "$NETWORK" >/dev/null 2>&1; then
    log "Network exists: $NETWORK"
  else
    log "Creating network: $NETWORK"
    docker --context="$CTX" network create "$NETWORK" >/dev/null
  fi
}

# Creates the volume if missing.
# Returns 0 if it already existed, 1 if it was created.
ensure_volume() {
  local v="$1"
  if docker --context="$CTX" volume inspect "$v" >/dev/null 2>&1; then
    log "Volume exists: $v"
    return 0
  else
    log "Creating volume: $v"
    docker --context="$CTX" volume create "$v" >/dev/null
    return 1
  fi
}

seed_caddyfile_into_new_volume() {
  local created="$1" # "true" or "false"

  if [[ "$created" != "true" ]]; then
    log "$ETC_VOL already existed; not seeding Caddyfile."
    return 0
  fi

  if [[ ! -f "$CADDYFILE_LOCAL" ]]; then
    echo "ERROR: Local Caddyfile not found at: $CADDYFILE_LOCAL" >&2
    exit 1
  fi

  log "Seeding Caddyfile into NEW $ETC_VOL volume..."
  docker --context="$CTX" run --rm -i \
    -v "${ETC_VOL}:/etc/caddy" \
    alpine:3.19 \
    sh -lc 'umask 022; cat > /etc/caddy/Caddyfile; chmod 0644 /etc/caddy/Caddyfile' \
    < "$CADDYFILE_LOCAL"
}

main() {
  need_cmd docker

  log "Repo root: $ROOT"
  log "Docker context: $CTX"
  log "Compose file: $COMPOSE_FILE"

  ensure_network

  # Ensure etc volume first so we can decide whether to seed it
  etc_created="false"
  if ensure_volume "$ETC_VOL"; then
    etc_created="false"
  else
    etc_created="true"
  fi

  # Ensure the rest (no seeding)
  ensure_volume "caddy-config-data" || true
  ensure_volume "caddy-certs-data" || true
  ensure_volume "caddy-data-data" || true

  seed_caddyfile_into_new_volume "$etc_created"
}

main "$@"
