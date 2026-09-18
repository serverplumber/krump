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
  inputs,
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

      allowUnfree = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Allow unfree packages in `devTools` and `extraTools`.

          Off by default, matching nixpkgs: neither of krump's workflows needs
          it. The dev container's own closure is entirely free, and the IDE
          servers it hosts are downloaded at runtime by VSCode Remote or
          JetBrains Gateway rather than coming from nixpkgs, so nixpkgs licence
          policy never applies to them. Launching a host-installed editor from
          `nix develop` does not need it either -- that editor lives outside
          nix.

          Set it true when you want *nix* to provide something unfree, such as
          `krump.extraTools = [ pkgs.vscode ];`, which otherwise fails to
          evaluate. Note it configures the nixpkgs instance for the whole
          flake, not just krump's outputs, which is why krump does not turn it
          on for you.

          Setting an environment variable such as NIXPKGS_ALLOW_UNFREE does not
          work here: that path relies on impure evaluation, and flakes evaluate
          purely.
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

        # `nix develop` always starts bash, so a zsh- or fish-flavoured
        # shellHook gets handed to bash to evaluate, which fails loudly
        # ("syntax error near unexpected token", "zmodload: command not
        # found"). The zsh and fish shells therefore hand off to the real shell
        # with krump's rc for it loaded -- and only when interactive, so
        # `nix develop .#fish -c some-command` still runs the command.
        rcFile = shell: pkgs.writeText "krump-${shell}rc" (krumpLib.shellHook shell);

        # ZDOTDIR replaces the user's zsh config rather than adding to it, so
        # source theirs first.
        zshDotDir = pkgs.runCommand "krump-zdotdir" { } ''
          mkdir -p "$out"
          {
            echo '[ -f "$HOME/.zshrc" ] && . "$HOME/.zshrc"'
            cat ${rcFile "zsh"}
          } > "$out/.zshrc"
        '';

        # fish -C runs after the user's own config.fish, so theirs is kept.
        handoff = {
          zsh = ''
            case $- in
              *i*)
                export ZDOTDIR=${zshDotDir}
                exec ${pkgs.zsh}/bin/zsh
                ;;
            esac
          '';
          fish = ''
            case $- in
              *i*) exec ${pkgs.fish}/bin/fish -C 'source ${rcFile "fish"}' ;;
            esac
          '';
        };

        mkShellFor =
          shell: shellPkg: hook:
          pkgs.mkShell {
            name = "dev-env-${shell}-${system}";
            buildInputs = krumpLib.devTools ++ [ shellPkg ];
            inherit (krumpLib) env;
            shellHook = hook;
          };

        images = import ./discover.nix {
          inherit (pkgs) lib;
          inherit pkgs containerLib;
          inherit (topCfg) projectName containersDir;
          krump = krumpLib;
        };
      in
      {
        # nixpkgs allows unfree only via its config, never via an environment
        # variable -- NIXPKGS_ALLOW_UNFREE needs impure evaluation, which flakes
        # do not use. mkDefault because flake-parts sets pkgs at
        # mkOptionDefault, so this wins, while a consumer who sets pkgs
        # explicitly still beats us.
        _module.args.pkgs = lib.mkDefault (
          import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = topCfg.allowUnfree;
          }
        );

        krump.devTools = krumpLib.devTools;

        devShells = {
          default = mkShellFor "bash" pkgs.bash (krumpLib.shellHook "bash");
          zsh = mkShellFor "zsh" pkgs.zsh handoff.zsh;
          fish = mkShellFor "fish" pkgs.fish handoff.fish;
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
