# krump

> A nix dev environment and container pipeline that needs nothing on your host but `podman` and `just`. Nix builds it. Podman runs it. No registry, ever.

```
❯ just dev
```

---

## The idea

Nix gives you hermetic builds. The price is usually that everyone who touches your project has to install and understand nix first, and that price is high enough that most teams never pay it.

Krump doesn't ask them to. Nix runs *inside a container*, builds your images there, and streams them straight into your host podman. Your host stays clean. The bootstrap requirement is two tools, neither of which is nix.

```
just dev
  └── podman run ghcr.io/nixos/nix        # naked nix, ephemeral
        └── nix run .#dev-image           # build & stream, nothing hits disk
              └── podman load             # host podman catches the stream
                    └── podman run dev    # you're in your shell
```

`dockerTools.streamLayeredImage` writes the image to stdout; `podman load` reads it from stdin. There is no tarball, no registry, no cached artifact to go stale, and no third party in the path between your source and your running container. The source *is* the build.

The cost of ephemeral nix — re-downloading the world on every invocation — is paid once into a persistent `nix-store` podman volume, seeded on bootstrap. After that it's fast.

## Ideas I'd defend

**One definition, two consumption modes.** `krump/default.nix` exports `devTools`, `env`, and `shellHook`. Both the `mkShell` dev shells and the dev container image consume that same list. The devcontainer and `nix develop` are identical environments *by construction*, not by anyone remembering to update both. Add `ripgrep` to `devTools` and it appears in your shell, your container, and your colleague's IDE.

**Containers are discovered, not registered.** `krump/containers.nix` reads the `containers/` directory and emits a flake app per subdirectory. Drop in `containers/postgres/default.nix` exposing an `image` attribute, and `postgres-image` exists. There is no list to keep in sync — the filesystem is the list.

**`devcontainer.json` is generated.** It's a just recipe, not a file you maintain. IDE integration is a thin consumption layer over an image nix built entirely; you get the IDE without conceding the build.

**Recipes know where they are.** `_not-in-container` guards on `/run/.containerenv`; `_build` executes inline when already inside the dev image and shells into it when outside. The same `just build` works from either side.

**Base images are pinned, not pulled.** `just update-base-image busybox latest` runs `nix-prefetch-docker` and writes a pinned expression into `containers/`. External base images enter your tree as content-addressed nix, not as a floating tag.

**Fork to customize.** Your opinions belong in your fork, not in a config schema I have to anticipate. There is no plugin system, and there won't be one.

## Status: it works, and it's rough

I use it. It's how [opensauce_dirt](https://github.com/serverplumber/opensauce_dirt) is built and deployed — app, PostgreSQL, and Caddy images, streamed to a VPS over ssh with no registry involved. The idea has held up under real use and I haven't regretted it once.

The implementation is another matter. It's young, I haven't run it against many projects, and every new project I point it at surfaces something. That's fine — that's what finding out looks like — but you should know it before you adopt it.

Known rough edges:

- **Container builds are Linux-only.** The dev shells build on all four platforms; `containers.nix` declares `x86_64-linux` and `aarch64-linux` only. On macOS you get `nix develop`, not `just dev`.
- **The dev image is x86_64 in practice.** The FHS shim in `containers/dev/default.nix` hardcodes `/lib/x86_64-linux-gnu` and `ld-linux-x86-64.so.2`. aarch64 is declared and not really delivered.
- **That FHS shim is a shim.** Copying glibc and libstdc++ into FHS paths so IDE server binaries can find them is exactly the kind of hack nix exists to avoid. It's there because VSCode's remote server assumes FHS. It works. It is not principled and it will break on something.
- **`sandbox = false`** in the container's `nix.conf`, because nix-in-podman needs it. A real caveat on the hermeticity claim, stated rather than buried.
- **`just dev` rebuilds the image every time** rather than checking whether anything changed.

Issues welcome. Expect them to be found faster than they're fixed.

## Quickstart

Requires [`podman`](https://podman.io) and [`just`](https://just.systems). Not docker — the rootless user namespace handling matters here.

```bash
nix flake init -t github:serverplumber/krump   # if you have nix
```

Then:

```bash
just dev           # build dev image, drop into your $SHELL
just devcontainer  # build dev image, let VSCode/JetBrains pick it up
just --list        # everything else
```

Or consume it as an input and extend `devTools` / `shellHook` in your own flake:

```nix
inputs.krump.url = "github:serverplumber/krump";
```

## Adding a container

Create a directory under `containers/` with a `default.nix` that takes `{ pkgs, projectName }` and returns an attrset with an `image` attribute built by `streamLayeredImage`. It becomes `<dirname>-image` automatically.

Two worked examples ship in the repo:

- **`staticserver`** — the simplest possible thing: darkhttpd serving a directory. `just serve` renders this README to HTML with `lowdown` inside the dev container, drops it in `assets/`, then serves it. That's the whole build-artifact → directory → serve pipeline in two recipes.
- **`busykrump`** — how to build on a pinned external base image, paired with `just update-busybox`.

## Included tools

`bat` · `curl` · `eza` · `git` · `glow` · `harper` · `helix` · `jq` · `just` · `lowdown` · `mdformat` · `neovim` · `nix` · `starship` · `vim` · `wget`, plus Fira Code and JetBrains Mono nerd fonts. Shells: bash, zsh, fish — `just dev` picks up your `$SHELL`.

Edit `devTools` in `krump/default.nix` to change any of it.

## Why not devcontainers directly?

Devcontainers are good for consumption and bad for construction. Their opinions about image building don't compose with hermetic tooling. Krump builds with nix and uses devcontainers only as the IDE-facing layer.

## Why not NixOS?

Maybe eventually — atomic generations and rollbacks are genuinely compelling. But podman and k8s are a mature, portable target, and krump gets you nix's guarantees at the build layer without betting the production stack on NixOS.

---

MIT.

---

> Named after the dance. Functional, a bit aggressive, unfairly overlooked.
