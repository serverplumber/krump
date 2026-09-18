# The krump library, as a flake-parts module.
#
# Consumers import this (`imports = [ krump.flakeModule ];`), set
# `krump.projectName` / `krump.containersDir`, and get dev shells plus container
# images. krump's own flake.nix imports the same file, so this path is exercised
# by every `just dev` in this repo -- there is no separate internal route that
# could work while the exported one rots.
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types mkDefault;
  inherit (flake-parts-lib) mkPerSystemOption;

  # perSystem shadows `config` with the per-system config, so capture the
  # top-level one here. Safe: nothing below feeds back into these options.
  topCfg = config.krump;
in
{
  options = {
    krump = {
      projectName = mkOption {
        type = types.str;
        example = "myproject";
        description = ''
          Project name. Image names derive from it -- the dev image is
          `<projectName>-dev:latest`. Read from the `project-name` file so the
          justfile and the flake cannot drift.
        '';
      };

      containersDir = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = lib.literalExpression "./containers";
        description = ''
          Directory scanned for container definitions. Every subdirectory
          containing a `default.nix` becomes `packages.<dirname>-image` and
          `apps.<dirname>-image`, hyphens and all. There is no list to keep in
          sync -- the filesystem is the list.

          null disables discovery. The dev image is emitted either way.
        '';
      };
    };

    perSystem = mkPerSystemOption (_: {
      options.krump = {
        extraTools = mkOption {
          type = types.listOf types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.ripgrep pkgs.fd ]";
          description = ''
            Packages appended to krump's base `devTools`. They appear in the dev
            shells *and* in the dev container image, because both consume the
            same list -- identical by construction, not by anyone remembering to
            update both.
          '';
        };

        extraEnv = mkOption {
          type = types.attrsOf types.str;
          default = { };
          example = lib.literalExpression ''{ RUST_BACKTRACE = "1"; }'';
          description = "Environment variables merged over krump's defaults.";
        };

        extraShellHook = mkOption {
          type = types.lines;
          default = "";
          description = "Shell snippet appended to krump's shellHook.";
        };

        devTools = mkOption {
          type = types.listOf types.package;
          readOnly = true;
          description = "Computed: krump's base tools plus `extraTools`.";
        };
      };
    });
  };

  config = {
    # Dev shells build on all four; container images are Linux-only and guarded
    # below. mkDefault so a consumer can narrow this to what they actually ship.
    systems = mkDefault [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    perSystem =
      {
        pkgs,
        system,
        config,
        ...
      }:
      let
        cfg = config.krump;

        base = import ./default.nix { inherit pkgs; };

        # The one definition both consumption modes read.
        krumpLib = {
          devTools = base.devTools ++ cfg.extraTools;
          env = base.env // cfg.extraEnv;
          shellHook = shell: base.shellHook shell + cfg.extraShellHook;
        };

        containerLib = import ./container-lib.nix { inherit pkgs; };

        mkShellFor =
          shell: shellPkg:
          pkgs.mkShell {
            name = "dev-env-${shell}-${system}";
            buildInputs = krumpLib.devTools ++ [ shellPkg ];
            inherit (krumpLib) env;
            shellHook = krumpLib.shellHook shell;
          };

        images = import ./discover.nix {
          inherit (pkgs) lib;
          inherit pkgs containerLib;
          inherit (topCfg) projectName containersDir;
          krump = krumpLib;
        };
      in
      {
        krump.devTools = krumpLib.devTools;

        devShells = {
          default = mkShellFor "bash" pkgs.bash;
          zsh = mkShellFor "zsh" pkgs.zsh;
          fish = mkShellFor "fish" pkgs.fish;
        };

        # Container images are Linux artifacts, so these outputs only exist on
        # Linux. That is not a macOS limitation: krump's macOS path is
        # nix-in-podman, and podman on macOS is a Linux VM -- nix runs inside it
        # as aarch64-linux and builds the Linux image natively. Emitting darwin
        # outputs here would only offer a host-nix build that cannot work
        # without a separately configured Linux builder.
        packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux images.packages;
        apps = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux images.apps;
      };
  };
}
