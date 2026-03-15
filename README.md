# krump

> An opinionated, hermetic dev environment base. Nix builds it. Podman runs it. You just code.

```
❯ just dev
```

______________________________________________________________________

## Philosophy

Most dev environment tooling makes one of two mistakes: it either assumes too much about the host, or it gives you a container you can't introspect or modify. Krump does neither.

- **Nix is the source of truth** — tools, shells, containers, all of it
- **No host assumptions** — only `podman` and `just` required to bootstrap
- **Hermetic builds** — same environment on every machine, every time
- **Fork to customize** — your opinions belong in your fork, not in a config file

______________________________________________________________________

## Quickstart

Prerequisites:

- [`podman`](https://podman.io)
- [`just`](https://just.systems)

That's it. Nix bootstraps itself.

______________________________________________________________________

```sh
mkdir myproject && cd myproject
curl -fsSL https://gist.githubusercontent.com/serverplumber/4ec8be62530ec915b785c4139b895606/raw/install.sh | sh
```

Then:

```bash
# CLI dev workflow
just dev          # builds dev image, drops you into your shell

# IDE / devcontainer workflow  
just devcontainer # builds dev image, VSCode/JetBrains picks it up
```

______________________________________________________________________

## How It Works

```
just dev
  └── podman run ghcr.io/nixos/nix        # naked nix container
        └── nix run .#load-dev            # build & stream dev image
              └── podman load             # host podman catches the stream
                    └── podman run dev    # drops you into your shell
```

No registry. No pre-built images. No stale artifacts. The source is the build.

______________________________________________________________________

## Structure

```
krump/
├──  krump
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

______________________________________________________________________

## Shells

`just dev` will just pick up your `$SHELL` automagic, use that.

The supported shells are as follows if you go the local nix route.

```bash
nix develop          # bash (default)
nix develop .#zsh    # zsh
nix develop .#fish   # fish
```

### Included Tools

| Tool | Why |
|------------|----------------------------------|
| `eza` | `ls` for the cool kids |
| `bat` | a nice pager with code colouring |
| `starship` | a good prompt |
| `helix` | because Bram is ded |
| `just` | make hurts the brain |
| `glow` | markdown in terminal |
| `lowdown` | markdown → html |
| `harper` | grammar linter |
| `jq` | JSON wrangling |

______________________________________________________________________

## Containers

Krump uses `dockerTools.streamLayeredImage` — images stream directly into podman, nothing touches disk.

```bash
just devcontainer  # Load {projectName}-dev into podman
just staticserver  # Load staticserver into podman 
just busykrump     # Load busykrump into podman
```

The dev container is identical to `nix develop -i` — same tools, same aliases, same prompt. Devcontainer users get the exact same environment as CLI users.

When you need a container, just create a directory in `containers`.
Drop in a `default.nix` which describes your container.

Two examples
are provided `staticserver` is the simplest possible server;
darkhttpd exposing this 'README.md' as dinkily rendered with
`lowdown`. See `just build` and `just serve` for the complete
workflow.

`busykrump` is an example of how to use a base image in your
nix containers. It uses the `just update-base-image` task
to create a base image description in `./containers`. The
rest is obvious, read the example.

______________________________________________________________________

## Customizing

### Adding tools

Edit `krump/default.nix` and add your tools to `devTools` and add your tools to `devTools`.

```nix
devTools = with pkgs; [
  # add yours here
  ripgrep
  fd
];
```

Tools appear in both shells and containers automatically.

### Shell aliases and prompt

Edit `krump/default.nix`:

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

______________________________________________________________________

## Nix Cache

On first run, nix downloads everything. Subsequent runs use a persistent podman volume:

```bash
podman volume create nix-store
```

Seed it once from a running container, then every build is fast.

______________________________________________________________________

## devcontainer.json

Don't touch it.

______________________________________________________________________

## Supported Shells

- bash
- zsh
- fish

______________________________________________________________________

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

______________________________________________________________________

## Why Not Devcontainers Directly?

Devcontainers are great for consumption, not great for construction. They have opinions about how images are built that don't compose well with hermetic build tooling. Krump uses devcontainers as a thin consumption layer over images built entirely by nix — you get IDE integration without giving up reproducibility.

## Why Not NixOS?

Maybe eventually. Nix rollbacks and atomic generations are genuinely compelling. But containers + podman/k8s is a mature, portable workflow that doesn't require betting your whole stack on NixOS in prod. Krump gets you nix's reproducibility guarantees at the build layer without that commitment.

______________________________________________________________________

## License

MIT

______________________________________________________________________

> Named after the dance. Functional, a bit aggressive, unfairly overlooked.
