# common/shells.nix
{ inputs, ... }:
{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  perSystem = { pkgs, system, ... }:
  let
    common = import ./default.nix { inherit pkgs; };

    bashShell = pkgs.mkShell {
      name = "dev-env-bash-${system}";
      buildInputs = common.devTools ++ [ pkgs.bash ];
      inherit (common.env) NIXPKGS_ALLOW_UNFREE FONTCONFIG_PATH;
      shellHook = common.shellHook "bash";
    };

    zshShell = pkgs.mkShell {
      name = "dev-env-zsh-${system}";
      buildInputs = common.devTools ++ [ pkgs.zsh ];
      inherit (common.env) NIXPKGS_ALLOW_UNFREE FONTCONFIG_PATH;
      shellHook = common.shellHook "zsh";
    };

    fishShell = pkgs.mkShell {
      name = "dev-env-fish-${system}";
      buildInputs = common.devTools ++ [ pkgs.fish ];
      inherit (common.env) NIXPKGS_ALLOW_UNFREE FONTCONFIG_PATH;
      shellHook = common.shellHook "fish";
    };
  in
  {
    devShells = {
      default = bashShell;
      zsh     = zshShell;
      fish    = fishShell;
    };
  };
}
