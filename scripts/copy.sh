#!/usr/bin/env bash
set -euo pipefail

CTX="${DOCKER_CONTEXT:-alpine}"
IMAGE="${COPY_IMAGE:-alpine:3.19}"

log() { printf '%s\n' "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

require_volume() {
  local v="$1"
  if docker --context="$CTX" volume inspect "$v" >/dev/null 2>&1; then
    log "Volume exists: $v"
  else
    echo "ERROR: Required volume does not exist: $v" >&2
    exit 1
  fi
}

copy_volume_contents() {
  local src="$1"
  local dst="$2"

  log ""
  log "Copying: $src  ->  $dst"
  log "NOTE: Destination contents will be replaced."

  require_volume "$src"
  require_volume "$dst"

  docker --context="$CTX" run --rm \
    -u 0:0 \
    -v "${src}:/from:ro" \
    -v "${dst}:/to" \
    "$IMAGE" \
    sh -lc '
      set -euo pipefail
      cd /to
      # Clear destination (including dotfiles) to avoid leaving stale files behind
      rm -rf ./* ./.??* 2>/dev/null || true

      # Stream-copy preserving owners, groups, perms, symlinks, mtimes
      cd /from
      tar -cpf - . | (cd /to && tar -xpf -)
    '

  log "Done: $src -> $dst"
}

main() {
  need_cmd docker

  log "Docker context: $CTX"
  log "Using copy image: $IMAGE"

  # Pull is safe even if already present; ensures remote daemon has it
  docker --context="$CTX" pull "$IMAGE" >/dev/null

  copy_volume_contents "infra_caddy-config-data" "caddy-config-data"
  copy_volume_contents "infra_caddy-certs-data" "caddy-certs-data"
  copy_volume_contents "infra_caddy-data-data"  "caddy-data-data"

  log ""
  log "All copies complete."
}

main "$@"
