# Justfile (bash mode)
# Requirements: just, podman (not docker)
# Usage: just dev
set shell := ["bash", "-eo", "pipefail", "-c"]

# -----------------------------
# Config
# -----------------------------
nix_image := "ghcr.io/nixos/nix"
podman := "podman"
workspace       := "/workspace"
project_root    := justfile_directory()

# Nix flags kept explicit but centralized
nix_flags := "--extra-experimental-features nix-command --extra-experimental-features flakes"
nix_envs := "NIX_USER_CONF_FILES=/workspace/.nix-config"

_default:
    @just --list

# Load an image onto the host podman
_load-image target:
    {{podman}} run --rm \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}} \
      nix {{nix_flags}} run .#{{target}} | {{podman}} load -q

# Run a developpment image
_run-image image:
    {{podman}} run --rm -it \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -e SHELL \
      -w {{workspace}} \
      {{image}}

_has-nix := `command -v nix || true`

_nix +args:
    #!/usr/bin/env bash
    if [ -n "{{_has-nix}}" ]; then
        nix {{args}}
    else
        podman run --rm \
          -v {{project_root}}:{{workspace}}:z \
          -v nix-store:/nix \
          -e NIX_USER_CONF_FILES={{workspace}}/.nix-config \
          -w {{workspace}} \
          {{nix_image}} \
          nix {{args}}
    fi

# Run bare nixOS within a container, mount workspace
naked-nix:
    {{podman}} run -it --rm \
      -e="{{nix_envs}}" \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}}
    
# Start a dev-shell in container
dev:
   just _load-image load-dev
   just _run-image localhost/dev:latest

# Load devcontainer into podman
devcontainer:
   just _load-image load-dev


# === Development ===

# Build all container images
build:
    just _nix "build .#dev-image"
    just _nix "build .#staticserver-image"

# Build only nix image (bootstrap)
build-nix:
    just _nix "build .#nix-image"

# Build only dev image
build-dev:
    just _nix "build .#dev-image"

# Build only staticserver image
build-staticserver:
    just _nix "build .#staticserver-image"

# Build only busy-krump
build-busy-krump:
    just _nix "build .#busy-krump"


# === Running Containers ===

# Run prebuilt dev container interactively
run-dev:
   just _run-image localhost/dev:latest

# Run staticserver container (serves README and workspace)
run-staticserver: load-staticserver
    {{podman}} run -it --rm \
      -v {{project_root}}:/workspace:z \
      -p 8080:8080 \
      staticserver:latest

# Load dev image into podman
load-dev:
    _nix run .#load-dev

# Load staticserver image into podman
load-staticserver:
    _nix run .#load-staticserver

# === Utilities ===
#

# update the nix image used for the dev container
update-base-image image tag:
    #!/usr/bin/env bash
    output="containers/base-image-$(echo {{image}} | tr '/' '-')-{{tag}}.nix"
    podman run --rm \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      -e NIX_USER_CONF_FILES={{workspace}}/.nix-config \
      -w {{workspace}} \
      {{nix_image}} \
      nix run nixpkgs#nix-prefetch-docker -- --image-name {{image}} --image-tag {{tag}} \
      | sed -n '/^{/,$ p' \
      > $output

# busybox base image example
update-busybox:
    just update-base-image busybox latest

# Show flake outputs
flake-show:
    just _nix "run flake show"

# Update flake.lock
update:
    just _nix "run flake update"

# Garbage collect old builds
gc:
    just _nix "run nikpkgs#nix --store gc"

# Format nix files (requires nixfmt)
fmt:
    just _nix "run nixpkgs#nixfmt -- **/*.nix"
