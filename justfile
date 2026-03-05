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

# Run bare nixOS within a container, mount workspace
naked-nix:
    {{podman}} run -it --rm \
      -e="{{nix_envs}}" \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}}
    
# Start a dev-shell in container
dev:
    just _load-image load-dev
    just _run-image localhost/dev:latest

# Start a dev-shell in container, with fish shell, for the kool kids
dev-fish:
    @just _load-image ./containers/dev/dev-container-fish.tar.gz
    @just _run-image localhost/dev-fish:latest



# === Development ===

# Enter dev shell (requires nix to be available locally OR use naked-nix)
#dev:
#   nix develop

# Build all container images
build:
    nix build .#dev-image
    nix build .#staticserver-image

# Build only nix image (bootstrap)
build-nix:
    nix build .#nix-image

# Build only dev image
build-dev:
    nix build .#dev-image

# Build only staticserver image
build-staticserver:
    nix build .#staticserver-image


# === Running Containers ===

# Run dev container interactively
run-dev: load-dev
    {{podman}} run -it --rm \
      -v {{project_root}}:/work:z \
      -w /work \
      dev:latest bash

# Run staticserver container (serves README and workspace)
run-staticserver: load-staticserver
    {{podman}} run -it --rm \
      -v {{project_root}}:/workspace:z \
      -p 8080:8080 \
      staticserver:latest

# Load dev image into podman
load-dev:
    nix run .#load-dev

# Load staticserver image into podman
load-staticserver:
    nix run .#load-staticserver

# === Utilities ===

# Show flake outputs
show:
    nix flake show

# Update flake.lock
update:
    nix flake update

# Garbage collect old builds
gc:
    nix-collect-garbage -d

# Format nix files (requires nixfmt)
fmt:
    nixfmt *.nix containers/*/default.nix shells/default.nix

# Print environment variables that will be set in dev shell
env:
    nix develop -c env | sort
