# myproject

A [krump](https://github.com/serverplumber/krump) project: nix builds the
images, podman runs them, no registry is ever involved.

## First, rename it

```bash
$EDITOR project-name     # one line, read by both flake.nix and the justfile
just devcontainer-json   # regenerate .devcontainer/devcontainer.json
```

## Then

```bash
just dev           # build the dev image, drop into your $SHELL
just devcontainer  # build the dev image, let VSCode/JetBrains pick it up
just --list        # everything else
```

Image builds are skipped when nothing affecting the image changed, so a no-op
`just dev` costs an eval instead of a two-minute rebuild. `KRUMP_FORCE=1`
builds regardless.

Your teammates need only `podman` and `just` for that -- nix runs inside the
container. You need nix on the host only to update krump itself.

## Where things go

| Path | What |
|---|---|
| `project-name` | The project name. The only place it is written. |
| `flake.nix` | Your tools (`krump.extraTools`), env, and shell hook. |
| `containers/` | One directory per image. `containers/foo/` becomes `foo-image`. Two examples ship; delete them. |
| `justfile` | Host-side commands. Yours to edit; `nix flake update` won't touch it. |
| `.krump/` | Generated build stamps for the rebuild cache. Gitignored. |

## Adding a container

Create `containers/<name>/default.nix` taking `{ pkgs, ... }` and returning an
attrset with an `image` built by `streamLayeredImage`. It becomes
`<name>-image` automatically, hyphens and all.

Keep the `...`: every container is called with the same argset -- `pkgs`, `lib`,
`projectName`, `krump` (the shared `devTools` / `env` / `shellHook`), and
`containerLib` (`nixConf`, `tmpDir`, `makeUsers`) -- and a container that names
only the arguments it uses will fail to evaluate.

Two worked examples ship, and both are yours to delete:

- `containers/staticserver/` -- darkhttpd serving a directory. `just serve` renders
  this README with lowdown and serves it on :8080. That is the whole
  build-artifact -> directory -> serve pattern.
- `containers/busy-krump/` -- building on a pinned external base image, paired
  with `just update-busybox`.

## Updating krump

```bash
just update   # nix flake update
```

That pulls new krump nix code. It does not touch your `justfile` -- see the note
at the top of that file.
