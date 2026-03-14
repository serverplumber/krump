# krump

> An opinionated, hermetic dev environment base. Nix builds it. Podman runs it. You just code.

```
❯ just dev
```

---

## Philosophy

Most dev environment tooling makes one of two mistakes: it either assumes too much about the host, or it gives you a container you can't introspect or modify. Krump does neither.

- **Nix is the source of truth** — tools, shells, containers, all of it
- **No host assumptions** — only `podman` and `just` required to bootstrap
- **Hermetic builds** — same environment on every machine, every time
- **Fork to customize** — your opinions belong in your fork, not in a config file

---

## Prerequisites

- [`podman`](https://podman.io)
- [`just`](https://just.systems)

That's it. Nix bootstraps itself.

---

## Quickstart

```bash
# Clone and go
git clone https://github.com/serverplumber/krump my-project
cd my-project

# CLI dev workflow
just dev          # builds dev image, drops you into your shell

# IDE / devcontainer workflow  
just devcontainer # builds dev image, VSCode/JetBrains picks it up
```

---

## How It Works

```
just dev
  └── podman run ghcr.io/nixos/nix        # naked nix container
        └── nix run .#load-dev            # build & stream dev image
              └── podman load             # host podman catches the stream
                    └── podman run dev    # drops you into your shell
```

No registry. No pre-built images. No stale artifacts. The source is the build.

---

## Structure

```
krump/
├──  common
│   ├──  containers.nix
│   ├──  default.nix
│   ├──  krump.nix
│   └──  shells.nix
├──  containers
│   ├──  base-image-busybox-latest.nix
│   ├──  busy-krump
│   │   └──  default.nix
│   ├──  default.nix
│   ├──  dev
│   │   ├──  default.nix
│   │   └──  shellrc.nix
│   └──  staticserver
│       └──  default.nix
├──  flake.lock
├──  flake.nix
└──  justfile
```

---

## Shells

`just dev` will just pick up your `$SHELL` automagic, use that.

The supported shells are as follows if you go the local nix route.
```bash
nix develop          # bash (default)
nix develop .#zsh    # zsh
nix develop .#fish   # fish
```

### Included Tools

| Tool       | Why                              |
|------------|----------------------------------|
| `eza`      | `ls` for the cool kids           |
| `bat`      | a nice pager with code colouring |
| `starship` | a good prompt                    |
| `helix`    | because Bram is ded              |
| `just`     | make hurts the brain             |
| `glow`     | markdown in terminal             |
| `lowdown`  | markdown → html                  |
| `harper`   | grammar linter                   |
| `jq`       | JSON wrangling                   |

---

## Containers

Krump uses `dockerTools.streamLayeredImage` — images stream directly into podman, nothing touches disk.

```bash
just dev           # build, load and run dev container
just devcontainer  # build and load for IDE use
just naked-nix     # raw nix container for modifying the flake itself
```

The dev container is identical to `nix develop -i` — same tools, same aliases, same prompt. Devcontainer users get the exact same environment as CLI users.

---

## Customizing

### Adding tools

Edit `common/default.nix` and add your tools to `devTools` and add your tools to `devTools`.
```nix
devTools = with pkgs; [
  # add yours here
  ripgrep
  fd
];
```

Tools appear in both shells and containers automatically.

### Shell aliases and prompt

Edit `common/default.nix`:

```nix
shellHook = shell: ''
  alias ls='${pkgs.eza}/bin/eza --icons'
  # add yours here
  eval "$(${pkgs.starship}/bin/starship init ${shell})"
'';
```

### Using as a flake input

```nix
inputs.krump.url = "github:serverplumber/krump";
```

Import `devTools` and `shellHook` from krump, extend in your project flake.

### Using as a template

```bash
nix flake init -t github:serverplumber/krump
```

Copies the full structure into your project. Fork and own your opinions.

---

## Nix Cache

On first run, nix downloads everything. Subsequent runs use a persistent podman volume:

```bash
podman volume create nix-store
```

Seed it once from a running container, then every build is fast.

---

## devcontainer.json


Don't touch it.

---

## Supported Shells

- bash
- zsh  
- fish

---

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

---

## Why Not Devcontainers Directly?

Devcontainers are great for consumption, not great for construction. They have opinions about how images are built that don't compose well with hermetic build tooling. Krump uses devcontainers as a thin consumption layer over images built entirely by nix — you get IDE integration without giving up reproducibility.

## Why Not NixOS?

Maybe eventually. Nix rollbacks and atomic generations are genuinely compelling. But containers + podman/k8s is a mature, portable workflow that doesn't require betting your whole stack on NixOS in prod. Krump gets you nix's reproducibility guarantees at the build layer without that commitment.

---

## License

MIT

---

> Named after the dance. Functional, a bit aggressive, unfairly overlooked.
