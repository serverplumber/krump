# krump

> A nix dev environment and container pipeline. You need nix to adopt it. Your team needs `podman` and `just` to use it. Nix builds the images. Podman runs them. No registry, ever.

```
❯ nix flake init -t github:serverplumber/krump
❯ just dev
```

## The idea

Nix gives you hermetic builds. The price is usually that everyone who touches your project has to install and understand nix first, and that price is high enough that most teams never pay it.

Krump splits that bill. **You** pay it once: adopting krump means running `nix flake init`, and if you're reading this you've already committed to nix. **Your team** doesn't pay it at all. Nix runs *inside a container*, builds your images there, and streams them straight into their host podman. Their host stays clean, and their bootstrap requirement is two tools, neither of which is nix.

```
just dev
  └── podman run ghcr.io/nixos/nix        # naked nix, ephemeral
        └── nix run .#dev-image           # build & stream, nothing hits disk
              └── podman load             # host podman catches the stream
                    └── podman run dev    # you're in your shell
```

`dockerTools.streamLayeredImage` writes the image to stdout; `podman load` reads it from stdin. There is no tarball, no registry, no cached artifact to go stale, and no third party in the path between your source and your running container. The source *is* the build.

The cost of ephemeral nix — re-downloading the world on every invocation — is paid once into a persistent `nix-store` podman volume, seeded on bootstrap. After that it's fast.

So: the flake is the install path, and the dev containers are for the developers who haven't come over to nix yet. Those are two different audiences and krump serves them with the same artifact.

## Ideas I'd defend

**One definition, two consumption modes.** `krump/default.nix` exports `devTools`, `env`, and `shellHook`. Both the `mkShell` dev shells and the dev container image consume that same list. The devcontainer and `nix develop` are identical environments *by construction*, not by anyone remembering to update both. Add `ripgrep` to `krump.extraTools` and it appears in your shell, your container, and your colleague's IDE.

**krump is a flake-parts module, and it builds itself with it.** `krump/flake-module.nix` is what you import; it's also what krump's own `flake.nix` imports. There is no internal path that could keep working while the exported one rots — every `just dev` in this repo exercises the same code a consumer gets.

**Containers are discovered, not registered.** `krump/discover.nix` reads your `containers/` directory and emits a package and an app per subdirectory. Drop in `containers/postgres/default.nix` exposing an `image` attribute, and `postgres-image` exists. There is no list to keep in sync — the filesystem is the list.

**`devcontainer.json` is generated.** It's a just recipe, not a file you maintain, and `just check-devcontainer-json` fails if the committed copy has drifted from the generator. IDE integration is a thin consumption layer over an image nix built entirely; you get the IDE without conceding the build.

**Recipes know where they are.** `_not-in-container` guards on `/run/.containerenv`; `_build` executes inline when already inside the dev image and shells into it when outside. The same `just build` works from either side.

**Base images are pinned, not pulled.** `just update-base-image busybox latest` runs `nix-prefetch-docker` and writes a pinned expression into `containers/`. External base images enter your tree as content-addressed nix, not as a floating tag.

**Nix decides whether a rebuild is needed.** The streamer derivation's own store path is a complete fingerprint of the image -- contents, config, and `fakeRootCommands` all feed the derivation that produces it -- so `_load-image` asks nix for the key (eval only, nothing is built) and skips the 2-minute stream-and-load when the loaded image already matches. The key cannot be a label on the image, because labels are an input to the derivation whose output path you would be embedding; that cycle is why it lives in `.krump/images/` alongside the image ref, guarded by `podman image exists` so a stamp can never outlive its image. `KRUMP_FORCE=1` bypasses it.

**One name, one place.** `project-name` is a one-line file read by both `flake.nix` and the justfile. Renaming your project is one edit, because the alternative — two sources of truth — already drifted once here.

**Fork to customize.** Your opinions belong in your fork or your own flake, not in a config schema I have to anticipate. The module has four options and there will not be forty.

## Status: it works, and it's rough

I use it. It's how [opensauce_dirt](https://github.com/serverplumber/opensauce_dirt) is built and deployed — app, PostgreSQL, and Caddy images, streamed to a VPS over ssh with no registry involved. The idea has held up under real use and I haven't regretted it once.

The implementation is another matter. It's young, I haven't run it against many projects, and every new project I point it at surfaces something. That's fine — that's what finding out looks like — but you should know it before you adopt it.

Known rough edges:

- **macOS is wired up but unverified.** See below — the design works out, and the arch-specific bugs that blocked it are fixed, but I don't own a Mac and none of it has been run on one. Treat it as untested, not as working.
- **That FHS shim is a shim.** Copying glibc and libstdc++ into FHS paths so IDE server binaries can find them is exactly the kind of hack nix exists to avoid. It's there because VSCode's remote server assumes FHS. It works. It is not principled and it will break on something.
- **`sandbox = false`** in the container's `nix.conf`. A real caveat on the hermeticity claim, stated rather than buried -- and it is not going away cheaply. Turning it on needs `--security-opt unmask=all` plus either `--cap-add SYS_ADMIN` or unconfined seccomp *and* apparmor; nothing less works (measured with `sandbox-fallback false`, since nix otherwise falls back to an unsandboxed build and reports success). That trades away more container isolation than it buys in build isolation, so it stays off. Note this is the nix **build** sandbox only: it has nothing to do with `nix develop` purity, and does not stop you launching a GUI editor from the dev shell.
- **The justfile is copied, not imported.** `nix flake update` brings you new krump nix code; it does not touch your justfile, because `just` can't import recipes out of a nix store path without a materialization step and a bootstrap chicken-and-egg. Host-side recipe fixes don't reach you automatically. Stated rather than pretended away.
- **No CI yet.** `just check` runs what CI would; nothing runs it for you on push.

Issues welcome. Expect them to be found faster than they're fixed.

## Quickstart

You need [nix](https://nixos.org/download) with flakes enabled. Your project's *developers* need only [`podman`](https://podman.io) and [`just`](https://just.systems) — not docker, the rootless user namespace handling matters here.

```bash
mkdir myproject && cd myproject
nix flake init -t github:serverplumber/krump
```

Or in one step, into a new directory:

```bash
nix flake new -t github:serverplumber/krump myproject
```

Then rename it and go:

```bash
$EDITOR project-name     # one line; both flake.nix and the justfile read it
just devcontainer-json   # regenerate .devcontainer/devcontainer.json
just dev                 # build the dev image, drop into your $SHELL
```

`nix flake init` refuses to clobber files that already exist, so it's safe to run in a directory that already has a `.git` or a `README`.

What you get is a small project, not a copy of krump:

| Path | What |
|---|---|
| `project-name` | The project name. The only place it's written. |
| `flake.nix` | ~20 lines: krump as an input, your tools, your containers dir. |
| `containers/` | One directory per image. `containers/foo/` becomes `foo-image`. |
| `justfile` | Host-side commands. Yours to edit. |
| `.devcontainer/` | Generated. Don't hand-edit it. |

Upgrading krump is `just update` (`nix flake update`).

## Everyday commands

```bash
just dev           # build dev image, drop into your $SHELL
just devcontainer  # build dev image, let VSCode/JetBrains pick it up
just build         # run a build command inside the dev image
just serve         # build an artifact, drop it in a dir, serve it on :8080
just check         # flake checks + generated-file drift checks
just test          # smoke test: build the image, run it, exercise the pipeline
just fmt           # format nix, shell, markdown, and the justfile
just --list        # everything else
```

Image builds are skipped when nothing that affects the image changed, so a
no-op `just dev` costs an eval rather than a two-minute rebuild. Set
`KRUMP_FORCE=1` to build regardless.

## Consuming krump as a flake input

The template is a thin consumer of the module, so this is what your `flake.nix` looks like whether or not you started from the template:

```nix
{
  inputs = {
    krump.url = "github:serverplumber/krump";
    nixpkgs.follows = "krump/nixpkgs";
    flake-parts.follows = "krump/flake-parts";
  };

  outputs =
    inputs@{ nixpkgs, flake-parts, krump, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ krump.flakeModule ];

      krump.projectName = nixpkgs.lib.trim (builtins.readFile ./project-name);
      krump.containersDir = ./containers;

      perSystem = { pkgs, ... }: {
        krump.extraTools = [ pkgs.ripgrep ];
      };
    };
}
```

Point `nixpkgs.url` at your own pin instead of following krump's and krump will use whatever you give it.

krump deliberately does not define a `formatter`, so `nix fmt` stays yours: one line (`formatter = pkgs.nixfmt-rfc-style;`) or a `treefmt-nix` import, as you prefer.

### Options

| Option | Type | What |
|---|---|---|
| `krump.projectName` | string | Image names derive from it; the dev image is `<projectName>-dev:latest`. |
| `krump.containersDir` | path or null | Scanned for container definitions. `null` disables discovery; the dev image is emitted either way. |
| `krump.allowUnfree` | bool (default true) | Allows unfree packages. On by default because most IDEs are unfree. Configures the nixpkgs instance for the whole flake. |
| `perSystem.krump.extraTools` | list of packages | Appended to krump's base `devTools`. Lands in the dev shells *and* the dev image. |
| `perSystem.krump.extraEnv` | attrs of string | Merged over krump's default env. |
| `perSystem.krump.extraShellHook` | lines | Appended to krump's shellHook. |
| `perSystem.krump.devTools` | list of packages | Read-only: the computed tool list, for introspection. |

### Outputs

| Output | Systems | What |
|---|---|---|
| `devShells.{default,zsh,fish}` | all four | `default` is bash. `just dev` picks up your `$SHELL`. |
| `packages.<name>-image` | Linux only | The image streamer. `nix build .#dev-image` works. |
| `apps.<name>-image` | Linux only | `nix run .#dev-image \| podman load`. |

## Adding a container

Create a directory under `containers/` with a `default.nix` that returns an attrset with an `image` attribute built by `streamLayeredImage`. It becomes `<dirname>-image` automatically — hyphens and all, so `containers/my-thing/` is `my-thing-image`. A subdirectory without a `default.nix` is skipped rather than breaking evaluation.

Every container is called with the same argset:

| Argument | What |
|---|---|
| `pkgs` | Your nixpkgs, for your system. |
| `lib` | `pkgs.lib`. |
| `projectName` | From `project-name`. |
| `krump` | The shared `devTools` / `env` / `shellHook`, *including* your `extraTools`. |
| `containerLib` | `nixConf`, `tmpDir`, `makeUsers` — see `krump/container-lib.nix`. |

**Keep the `...`.** Every argument is passed to every container, so a container that names only the ones it uses will fail to evaluate.

Two worked examples ship in this repo:

- **`staticserver`** — the simplest possible thing: darkhttpd serving a directory. `just serve` renders this README to HTML with `lowdown` inside the dev container, drops it in `assets/`, then serves it. That's the whole build-artifact → directory → serve pipeline in two recipes.
- **`busy-krump`** — how to build on a pinned external base image, paired with `just update-busybox`.

## macOS

`just dev` is supposed to work on macOS, for a reason that falls out of the design rather than being bolted on: podman on macOS *is* a Linux VM. `podman run ghcr.io/nixos/nix` starts a Linux container inside that VM, the nix in it identifies as `aarch64-linux` on Apple Silicon, and it builds the Linux image natively. Then `podman load` catches the stream in the same VM. No host nix, no cross-compilation, no Linux builder — the indirection krump already has is exactly the indirection macOS needs.

What that means concretely: `nix flake init`, `just dev`, `just devcontainer`, and the container recipes all go through podman and should behave the same. `nix develop` also works natively, since the dev shells are built for all four platforms.

Deliberately *not* offered: `nix run .#dev-image` with host nix on macOS. Those outputs only exist for Linux systems. A darwin-native build of a Linux container image is meaningless, and pointing the darwin outputs at the Linux package set would just fail later with a confusing "I am a 'aarch64-darwin'" error unless you'd separately set up a Linux builder. Use podman; that's the supported path.

Two caveats worth knowing before you try:

- **Your project must live somewhere the podman machine shares.** `$HOME` is shared by default; a project outside it will bind-mount as an empty directory rather than erroring.
- **`--userns keep-id` requires a rootless podman machine.** That's the default, but a rootful machine will reject it.

**None of this has been run on a Mac.** I don't have one. What I can say precisely: the two things that definitely broke macOS are fixed — the FHS shim derived its paths from a hardcoded `x86_64-linux-gnu` and `ld-linux-x86-64.so.2`, which on aarch64 produced an image that built cleanly and shimmed nothing, and `:z` SELinux relabeling is now dropped off Linux. Both fixes are verified by evaluating the aarch64-linux image, which is as far as an x86_64 Linux box can take it. If you run it on a Mac, I'd genuinely like the bug report.

## Included tools

`bat` · `curl` · `eza` · `git` · `glow` · `harper` · `helix` · `jq` · `just` · `lowdown` · `mdformat` · `neovim` · `nix` · `starship` · `vim` · `wget`, plus Fira Code and JetBrains Mono nerd fonts. Shells: bash, zsh, fish — `just dev` picks up your `$SHELL`.

Add to it with `krump.extraTools` in your own flake. Edit `devTools` in `krump/default.nix` only if you're working on krump itself.

## Why not devcontainers directly?

Devcontainers are good for consumption and bad for construction. Their opinions about image building don't compose with hermetic tooling. Krump builds with nix and uses devcontainers only as the IDE-facing layer.

## Why not NixOS?

Maybe eventually — atomic generations and rollbacks are genuinely compelling. But podman and k8s are a mature, portable target, and krump gets you nix's guarantees at the build layer without betting the production stack on NixOS.

## Hacking on krump itself

```bash
git clone https://github.com/serverplumber/krump && cd krump
just dev       # krump builds itself with its own module
just check     # what CI would run, once there is CI
```

`krump/` is the library: `default.nix` (tools/env/hook), `flake-module.nix` (the exported module and its options), `discover.nix` (containers → outputs), `dev-image.nix`, `shellrc.nix`, `container-lib.nix`. `containers/` holds only the two examples. `treefmt.nix` and `checks.nix` are krump-repo-only: `checks.nix` asserts `templates/default/justfile` is still byte-identical to `./justfile`, since the template ships a copy and it had already drifted once. `templates/default/` is what `nix flake init` lays down — it's in the flake source, so **new files there must be `git add`ed or nix won't see them.**

ISC.

> Named after the dance. Functional, a bit aggressive, unfairly overlooked.
