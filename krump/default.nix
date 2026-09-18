# krump's base definition: the tool list, environment, and shell hook that both
# the dev shells and the dev container image consume. Add something here and it
# appears in `nix develop`, in `just dev`, and in a colleague's IDE.
#
# Consumers extend rather than edit this, via the module's `krump.extraTools` /
# `extraEnv` / `extraShellHook` options.
{ pkgs }:
let
  fonts = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];
in
{
  devTools =
    (with pkgs; [
      bat
      curl
      eza
      git
      glow
      gnugrep
      gnused
      harper
      helix
      jq
      just
      lowdown
      mdformat
      neovim
      nix
      starship
      vim
      wget
    ])
    ++ fonts;

  env = {
    # Only affects impure nix invocations made from inside the shell, such as
    # `nix-shell -p <something unfree>`. It does NOT make this flake's own
    # package set allow unfree -- that needs config.allowUnfree on the nixpkgs
    # instance, which the module's `krump.allowUnfree` option handles.
    NIXPKGS_ALLOW_UNFREE = "1";

    # FONTCONFIG_FILE, not FONTCONFIG_PATH. FONTCONFIG_PATH names a directory
    # that *contains* a fonts.conf; pointed at a font directory it finds no
    # config there and suppresses the system config instead of adding the
    # fonts -- which is what the previous
    # `FONTCONFIG_PATH = "${nerd-fonts.jetbrains-mono}/share/fonts"` did.
    FONTCONFIG_FILE = "${pkgs.makeFontsConf { fontDirectories = fonts; }}";
  };

  shellHook = shell: ''
    alias ls='${pkgs.eza}/bin/eza --icons'
    alias tree='${pkgs.eza}/bin/eza --tree --icons'
    eval "$(${pkgs.starship}/bin/starship init ${shell})"
  '';
}
