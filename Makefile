# Build, push, sign, verify (sticky tag + containerized cosign)

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

IMAGE       ?= docker.io/nebularover77/caddy-he-cfpl
TAG_FILE    ?= .tag
TAG         ?= $(shell [ -f $(TAG_FILE) ] && cat $(TAG_FILE) || (git describe --always --dirty --tags 2>/dev/null || date +%Y%m%d-%H%M%S))
PLATFORMS   ?= linux/amd64,linux/arm64
BUILDER     ?= multi
IMAGETOOLS_BUILDER ?= $(BUILDER)

CONTEXT     ?= .
REG         := $(IMAGE):$(TAG)
DIGEST_FILE := .digest
STAMP       := .pushed-$(TAG)

BUILD_DEPS  := Dockerfile Caddyfile compose.yaml compose.override.yaml \
               $(shell [ -d scripts ] && find scripts -type f -print)

# --- Containerized cosign config ---------------------------------------------
COSIGN_IMAGE ?= bitnami/cosign:latest
COSIGN_KEY   ?= $(HOME)/.cosign/cosign.key
COSIGN_PUB   ?= $(CURDIR)/cosign.pub
TTY := $(shell [ -t 1 ] && echo -it)
COSIGN_ENV := $(if $(COSIGN_PASSWORD),-e COSIGN_PASSWORD) -e DOCKER_CONFIG=/root/.docker

COSIGN_DOCKER := docker run --rm $(TTY) $(COSIGN_ENV) \
  -v "$(COSIGN_KEY):/root/.cosign/cosign.key:ro" \
  -v "$(COSIGN_PUB):/root/.cosign/cosign.pub:ro" \
  -v "$(HOME)/.docker:/root/.docker:ro" \
  -v "$(CURDIR):$(CURDIR)" -w "$(CURDIR)" \
  $(COSIGN_IMAGE)

.PHONY: help login build push ensure-builder digest sign verify ensure-signed print-image release clean bump-tag tag cosign-pull check-cosign-files

help:
	@echo "Targets:"
	@echo "  make release         # multi-arch build+push, ensure signed, print ref"
	@echo "  make digest          # resolve registry digest (depends on latest push)"
	@echo "  make sign / verify   # sign/verify by digest via containerized cosign"
	@echo "  make ensure-signed   # verify; sign if missing"
	@echo "  make bump-tag        # rotate TAG to a fresh timestamp"
	@echo "  make tag             # print current TAG"

login:
	docker login

# ---- Single-arch (optional local build) --------------------------------------
build: $(BUILD_DEPS)
	docker build -t $(REG) $(CONTEXT)

push: build
	docker push $(REG)
	@echo "$(TAG)" > $(TAG_FILE)

# ---- Multi-arch buildx -------------------------------------------------------
ensure-builder:
	@if docker buildx inspect $(BUILDER) >/dev/null 2>&1; then \
	  echo ">> Using existing buildx builder '$(BUILDER)'"; \
	  docker buildx use $(BUILDER); \
	else \
	  echo ">> Creating buildx builder '$(BUILDER)'"; \
	  docker buildx create --use --name $(BUILDER); \
	fi

# Stamp depends on your inputs; if they change, we rebuild+push again
$(STAMP): $(BUILD_DEPS) | ensure-builder
	docker buildx build \
	  --platform $(PLATFORMS) \
	  -t $(REG) \
	  --push \
	  $(CONTEXT)
	@echo "$(TAG)" > $(TAG_FILE)
	touch $(STAMP)

# ---- Digest / Sign / Verify --------------------------------------------------
$(DIGEST_FILE): $(STAMP)
	@echo ">> Resolving registry digest for $(REG)"
	@d=$$(docker buildx --builder $(IMAGETOOLS_BUILDER) imagetools inspect $(REG) 2>/dev/null | awk '/^Digest: /{print $$2; exit}'); \
	if [ -z "$$d" ]; then \
	  echo "!! Could not resolve digest for $(REG). Is it pushed and accessible?"; \
	  exit 1; \
	fi; \
	echo "$$d" | tee $(DIGEST_FILE) >/dev/null; \
	echo ">> Wrote digest to $(DIGEST_FILE)"

digest: $(DIGEST_FILE)
	@cat $(DIGEST_FILE)

cosign-pull:
	docker pull $(COSIGN_IMAGE)

check-cosign-files:
	@[ -f "$(COSIGN_KEY)" ] || { echo "!! COSIGN_KEY not found at $(COSIGN_KEY)"; exit 1; }
	@[ -f "$(COSIGN_PUB)" ] || { echo "!! COSIGN_PUB not found at $(COSIGN_PUB)"; exit 1; }

sign: cosign-pull check-cosign-files $(DIGEST_FILE)
	@d=$$(cat $(DIGEST_FILE)); \
	[[ "$$d" =~ ^sha256:[0-9a-f]{64}$$ ]] || { echo "!! Invalid digest: $$d"; exit 1; }; \
	echo ">> Signing $(IMAGE)@$$d (containerized cosign)"; \
	$(COSIGN_DOCKER) sign --key /root/.cosign/cosign.key $(IMAGE)@$$d

verify: cosign-pull check-cosign-files $(DIGEST_FILE)
	@d=$$(cat $(DIGEST_FILE)); \
	[[ "$$d" =~ ^sha256:[0-9a-f]{64}$$ ]] || { echo "!! Invalid digest: $$d"; exit 1; }; \
	echo ">> Verifying $(IMAGE)@$$d (containerized cosign)"; \
	$(COSIGN_DOCKER) verify --key /root/.cosign/cosign.pub $(IMAGE)@$$d

ensure-signed: cosign-pull check-cosign-files $(DIGEST_FILE)
	@d=$$(cat $(DIGEST_FILE)); \
	[[ "$$d" =~ ^sha256:[0-9a-f]{64}$$ ]] || { echo "!! Invalid digest: $$d"; exit 1; }; \
	echo ">> Checking signature for $(IMAGE)@$$d"; \
	if $(COSIGN_DOCKER) verify --key /root/.cosign/cosign.pub $(IMAGE)@$$d >/dev/null 2>&1; then \
	  echo ">> Already signed"; \
	else \
	  echo ">> Not signed; signing now"; \
	  $(COSIGN_DOCKER) sign --key /root/.cosign/cosign.key $(IMAGE)@$$d; \
	  echo ">> Verifying..."; \
	  $(COSIGN_DOCKER) verify --key /root/.cosign/cosign.pub $(IMAGE)@$$d >/dev/null; \
	  echo ">> Signed and verified"; \
	fi

print-image: $(DIGEST_FILE)
	@echo ">> Signed image:"
	@echo "$(IMAGE)@$$(< $(DIGEST_FILE))"

# Full pipeline: build/push (multi-arch) -> digest -> ensure signed -> print ref
release: $(DIGEST_FILE) ensure-signed print-image
	@echo ">> Release complete for $(REG)"

clean:
	rm -f $(DIGEST_FILE) $(STAMP)

bump-tag:
	@t=$$(date +%Y%m%d-%H%M%S); echo "$$t" > $(TAG_FILE); echo "TAG=$$t"

tag:
	@echo "$(TAG)"
