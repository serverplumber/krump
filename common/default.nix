{ pkgs }:
{
  devTools = with pkgs; [
    nix
    git
    curl
    wget
    jq
    just
    vim
    neovim
    helix
    starship
    bat
    eza
    lowdown
    glow
    harper
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
  ];

  env = {
    NIXPKGS_ALLOW_UNFREE = "1";
    FONTCONFIG_PATH = "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts";
  };

shellHook = shell: ''
  alias ls='${pkgs.eza}/bin/eza --icons'
  alias tree='${pkgs.eza}/bin/eza --tree --icons'
  eval "$(${pkgs.starship}/bin/starship init ${shell})"
'';
}
