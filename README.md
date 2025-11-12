# xcaddy-plus

Custom Caddy build (via `xcaddy`) with:
- **github.com/caddy-dns/he** (Hurricane Electric DNS provider for ACME)
- **github.com/xcaddyplugins/caddy-trusted-cloudfront** (auto-trust CloudFront origin IPs)

The image is designed for Docker/Compose and supports multi-arch builds, plus containerized **cosign** signing & verification.

## Quick start (Docker Compose)

```bash
docker compose up -d
````

`compose.yaml` maps:

* `./Caddyfile` → `/etc/caddy/Caddyfile` (global opts + `import /etc/caddy/conf.d/*.caddy`)
* `/mnt/opt/caddy/etc/conf.d` → `/etc/caddy/conf.d` (your per-vhost `*.caddy`)
* `/mnt/opt/caddy/data` → `/data` (ACME certs, etc.)
* `/mnt/opt/caddy/config` → `/config`

Reload (after editing config):

```bash
./scripts/reload.sh
```

## Caddyfile highlights

```caddyfile
{
  servers {
    trusted_proxies cloudfront {
      interval 12h
    }
    client_ip_headers X-Forwarded-For CloudFront-Viewer-Address
    trusted_proxies_strict
  }
}
# Domain-specific vhosts:
import /etc/caddy/conf.d/*.caddy
```

## Build, push, sign (Makefile)

Common targets:

* `make release` — multi-arch build+push → resolve digest → **ensure signed** → print final image ref
* `make digest` — write/print registry digest for current `IMAGE:TAG`
* `make sign` / `make verify` — sign/verify **by digest** via containerized cosign
* `make bump-tag` — rotate `TAG` to a fresh timestamp

Key vars (override via env):

* `IMAGE` (default `docker.io/nebularover77/caddy-he-cfpl`)
* `PLATFORMS` (default `linux/amd64,linux/arm64`)
* `TAG` (from `.tag` or `git describe` or timestamp)

Example release:

```bash
make release
```

## Cosign

Public key lives at `cosign.pub`. The Makefile runs cosign **in a container** and mounts your key(s):

* Put your private key at `~/.cosign/cosign.key` (or set `COSIGN_KEY`).
* Verify a pushed image by digest:

```bash
make verify
```

## Scripts

* `scripts/reload.sh` — `caddy reload` using the mounted `Caddyfile`
* `scripts/validate.sh` — quick config reload/validation

## Notes

* Ensure `/mnt/opt/caddy/etc/conf.d` exists on the host and contains your `*.caddy` vhosts.
* If using HE DNS for ACME, export the required env vars for the provider in your Compose or secrets.
