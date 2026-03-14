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

_default: bootstrap
    @just --list

_has-nix := `command -v nix || true`

_has-nix-store := `podman volume inspect nix-store &>/dev/null && echo "yes" || echo ""`

_in-container := `[ -f /run/.containerenv ] && echo "yes" || echo ""`

_need-nix-store:
    @[ -n "{{_has-nix-store}}" ] || exit 1

# Start here.
bootstrap:
    #!/usr/bin/env bash
    if [ -z "{{_has-nix-store}}" ]; then
        echo "Bootstrapping nix-store volume..."
        {{podman}} run --rm \
          -v nix-store:/nix \
          {{nix_image}} \
          cp -a /nix/. /nix/
        echo "nix-store volume ready."
    fi

# Load an image onto the host podman
_load-image target: _need-nix-store
    {{podman}} run --rm \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}} \
      nix {{nix_flags}} run .#{{target}} | {{podman}} load -q

# Run a developpment image
_run-image image: _need-nix-store
    {{podman}} run --rm -it \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -e SHELL \
      -w {{workspace}} \
      {{image}}

_nix +args:
    #!/usr/bin/env bash
    -set -eo pipefail
    if [ -n "{{_has-nix}}" ]; then
        nix {{args}}
    else
        just _need-nix-store
        podman run --rm \
          -v {{project_root}}:{{workspace}}:z \
          -v nix-store:/nix \
          -e NIX_USER_CONF_FILES={{workspace}}/.nix-config \
          -w {{workspace}} \
          {{nix_image}} \
          nix {{args}}
    fi

_build +cmd:
    #!/usr/bin/env bash
    set -eo pipefail
    if [ -n "{{_in-container}}" ]; then
        eval {{cmd}}
    else
        {{podman}} run --rm \
          -v {{project_root}}:{{workspace}}:z \
          -v nix-store:/nix \
          --userns keep-id:uid=0,gid=0 \
          -w {{workspace}} \
          localhost/dev:latest \
          sh -c "{{cmd}}"
    fi

# Run bare nixOS within a container, mount workspace
naked-nix: _need-nix-store
    {{podman}} run -it --rm \
      -e="{{nix_envs}}" \
      -v {{project_root}}:{{workspace}}:z \
      -v nix-store:/nix \
      --userns keep-id:uid=0,gid=0 \
      -w {{workspace}} \
      {{nix_image}}
    
# Start a dev-shell in container
dev: bootstrap
   just devcontainer
   just _run-image localhost/dev:latest

# Load devcontainer into podman
devcontainer:
   just _load-image dev-image

# Load staticserver into podman
staticserver:
    just _load-image staticserver-image

# Load busy-krump into podman
busykrump:
    just _load-image busykrump-image

# === Running Containers ===

# Run prebuilt dev container interactively
run-dev:
   just _run-image localhost/dev:latest

# Run staticserver container (serves README and workspace)
run-staticserver: staticserver
    {{podman}} run -it --rm \
      -v {{project_root}}:/workspace:z \
      -p 8080:8080 \
      staticserver:latest

# === Utilities ===
#

# update the nix image used for the dev container
update-base-image image tag: _need-nix-store
    #!/usr/bin/env bash
    output="containers/base-image-$(echo {{image}} | tr '/' '-')-{{tag}}.nix"
    {{podman}} run --rm \
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

# Demo: build pipeline pattern
# lowdown converts README.md → assets/index.html inside the dev container
build:
    mkdir -p {{project_root}}/assets
    just _build "lowdown -s -Thtml README.md -o assets/index.html"

# Demo: serve pipeline pattern  
# loads staticserver image then serves ./assets on port 8080
# this is the hello world of: build artifact → drop in dir → serve it
serve: build (_load-image "staticserver-image")
    {{podman}} run --rm \
      -v {{project_root}}/assets:/assets:z \
      -p 8080:8080 \
      staticserver:latest
