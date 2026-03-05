
{ pkgs, system }:

let
  common = import ../common { inherit pkgs; };

  # Bash shell
  bashShell = pkgs.mkShell {
    name = "dev-env-bash-${system}";
    buildInputs = common.devTools ++ [ pkgs.bash ];
    inherit (common.env) NIXPKGS_ALLOW_UNFREE FONTCONFIG_PATH;
    shellHook = common.shellHook "bash";
  };

  # Zsh shell
  zshShell = pkgs.mkShell {
    name = "dev-env-zsh-${system}";
    buildInputs = common.devTools ++ [ pkgs.zsh ];
    inherit (common.env) NIXPKGS_ALLOW_UNFREE FONTCONFIG_PATH;
    shellHook = common.shellHook "zsh";
  };

  # Fish shell
  fishShell = pkgs.mkShell {
    name = "dev-env-fish-${system}";
    buildInputs = common.devTools ++ [ pkgs.fish ];
    inherit (common.env) NIXPKGS_ALLOW_UNFREE FONTCONFIG_PATH;
    shellHook = common.shellHook "fish";
  };

in
{
  default = bashShell;
  zsh = zshShell;
  fish = fishShell;
}
