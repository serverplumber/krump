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

- **macOS is wired up but unverified.** See below — the design works out, and the arch-specific bugs that blocked it are fixed, but I don't own a Mac and none of it has been run on one. Treat it as untested, not as working.
- **That FHS shim is a shim.** Copying glibc and libstdc++ into FHS paths so IDE server binaries can find them is exactly the kind of hack nix exists to avoid. It's there because VSCode's remote server assumes FHS. It works. It is not principled and it will break on something.
- **`sandbox = false`** in the container's `nix.conf`, because nix-in-podman needs it. A real caveat on the hermeticity claim, stated rather than buried.
- **`just dev` rebuilds the image every time** rather than checking whether anything changed.

Issues welcome. Expect them to be found faster than they're fixed.

## Quickstart

Requires [`podman`](https://podman.io) and [`just`](https://just.systems). Not docker — the rootless user namespace handling matters here.

```bash
REF=v0.1.0
curl -fsSLO "https://raw.githubusercontent.com/serverplumber/krump/$REF/install.sh"
echo "b10c041f28ccfa8e67cb76169de1f9a2264bbdf10b03b2dc4b11dc3122966483  install.sh" | sha256sum -c
sh install.sh
```

On macOS, `sha256sum` doesn't exist — substitute `shasum -a 256 -c` for that third line. Everything else is the same.

`install.sh` is [checked into this repo](install.sh) — read it first, it's forty lines. It materializes the template with nix running inside podman, so the two-tool bootstrap holds. If you already have nix on the host it uses that instead, and `nix flake init -t github:serverplumber/krump/v0.1.0` skips the script entirely.

On the deliberate lack of a `curl | sh`: the hash is the pin, not the tag. A git tag can be force-moved, so fetching from `$REF` buys you a stable name and `sha256sum -c` buys you the integrity — you need both, and you need the file on disk to check it before it runs. If you'd rather not trust that a tag stayed put, swap `$REF` for the full commit sha; the same hash verifies. Every krump release documents its `install.sh` hash here, and `just check-install-sha` fails the build if this line and the file ever drift apart.

Then:

```bash
just dev           # build dev image, drop into your $SHELL
just devcontainer  # build dev image, let VSCode/JetBrains pick it up
just --list        # everything else
```

## macOS

`just dev` is supposed to work on macOS, for a reason that falls out of the design rather than being bolted on: podman on macOS *is* a Linux VM. `podman run ghcr.io/nixos/nix` starts a Linux container inside that VM, the nix in it identifies as `aarch64-linux` on Apple Silicon, and it builds the Linux image natively. Then `podman load` catches the stream in the same VM. No host nix, no cross-compilation, no Linux builder — the indirection krump already has is exactly the indirection macOS needs.

What that means concretely: `nix flake init` / `install.sh`, `just dev`, `just devcontainer`, and the container recipes all go through podman and should behave the same. `nix develop` also works natively, since the dev shells are built for all four platforms.

Deliberately *not* offered: `nix run .#dev-image` with host nix on macOS. Those apps only exist for Linux systems. A darwin-native build of a Linux container image is meaningless, and pointing the darwin app at the Linux package set would just fail later with a confusing "I am a 'aarch64-darwin'" error unless you'd separately set up a Linux builder. Use podman; that's the supported path.

Two caveats worth knowing before you try:

- **Your project must live somewhere the podman machine shares.** `$HOME` is shared by default; a project outside it will bind-mount as an empty directory rather than erroring.
- **`--userns keep-id` requires a rootless podman machine.** That's the default, but a rootful machine will reject it.

**None of this has been run on a Mac.** I don't have one. What I can say precisely: the two things that definitely broke macOS are fixed — the FHS shim derived its paths from a hardcoded `x86_64-linux-gnu` and `ld-linux-x86-64.so.2`, which on aarch64 produced an image that built cleanly and shimmed nothing, and `:z` SELinux relabeling is now dropped off Linux. Both fixes are verified by evaluating the aarch64-linux image, which is as far as an x86_64 Linux box can take it. If you run it on a Mac, I'd genuinely like the bug report.

## Consuming krump as a flake input

Or consume it as an input and extend `devTools` / `shellHook` in your own flake:

```nix
inputs.krump.url = "github:serverplumber/krump";
```

## Adding a container

Create a directory under `containers/` with a `default.nix` that takes `{ pkgs, projectName, ... }` and returns an attrset with an `image` attribute built by `streamLayeredImage`. It becomes `<dirname>-image` automatically — hyphens and all, so `containers/my-thing/` is `my-thing-image`. Keep the `...`: `streamContainer` passes every argument to every container, and a container that names only the ones it uses will fail to evaluate.

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
