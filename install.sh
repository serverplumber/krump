#!/bin/sh
# krump installer — materializes the krump template into the current directory.
#
# This script is checked into the krump repo. Fetch it from a tag, never from a
# branch, and verify its sha256 against the one published in the README at that
# same tag:
#
#   REF=v0.1.0
#   curl -fsSLO "https://raw.githubusercontent.com/serverplumber/krump/$REF/install.sh"
#   sha256sum install.sh    # compare against the README at $REF
#   sh install.sh
#
# It needs podman, the same tool krump needs anyway. If you happen to have nix
# on the host it uses that instead. It writes only into the current directory
# and refuses to clobber what is already there.

set -eu

KRUMP_REPO="${KRUMP_REPO:-github:serverplumber/krump}"
KRUMP_REF="${KRUMP_REF:-v0.1.0}"
NIX_IMAGE="${NIX_IMAGE:-ghcr.io/nixos/nix}"
NIX_FLAGS="--extra-experimental-features nix-command --extra-experimental-features flakes"

die() {
    echo "install.sh: $*" >&2
    exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

# Fail before writing anything rather than half-populating someone's project.
for f in flake.nix justfile; do
    [ ! -e "$f" ] || die "$PWD already has a $f — refusing to overwrite. Run this in an empty directory."
done

# SELinux relabeling is Linux-only; on macOS the mount comes out of the podman
# machine over virtiofs, where :z can fail outright.
if [ "$(uname -s)" = "Linux" ]; then z=":z"; else z=""; fi

if have nix; then
    # shellcheck disable=SC2086 # NIX_FLAGS is a deliberate word-split arg list
    nix $NIX_FLAGS flake init -t "$KRUMP_REPO/$KRUMP_REF"
elif have podman; then
    # Same nix-in-podman path krump itself uses: nothing lands on your host but
    # the files, and the nix that produced them is gone when the container exits.
    # On macOS podman is already a Linux VM, so the nix inside it builds Linux
    # images natively — no host nix and no cross-compilation involved.
    # shellcheck disable=SC2086
    podman run --rm \
        -v "$PWD":/workspace"$z" \
        --userns keep-id:uid=0,gid=0 \
        -w /workspace \
        "$NIX_IMAGE" \
        nix $NIX_FLAGS flake init -t "$KRUMP_REPO/$KRUMP_REF"
else
    die "need podman (https://podman.io) on PATH. Not docker — the rootless user namespace handling matters here."
fi

have just || echo "install.sh: warning — 'just' is not on PATH. Install it from https://just.systems before running 'just dev'." >&2

cat <<EOF

krump $KRUMP_REF installed into $PWD

  just dev           build dev image, drop into your \$SHELL
  just devcontainer  build dev image, let VSCode/JetBrains pick it up
  just --list        everything else
EOF
