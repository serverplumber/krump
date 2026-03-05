{ pkgs }:

let
  common = import ../../common { inherit pkgs; };
  containerDefaults = import ../../containers { inherit pkgs; };
  shellRc = import ./shellrc.nix { inherit pkgs common; };
  # Setup script to create developer user if needed (optional for local dev)
  setupScript = pkgs.writeShellScriptBin "setup-dev-user" ''
    if ! id -u developer > /dev/null 2>&1; then
      echo "developer:x:1000:1000::/workspace:/bin/sh" >> /etc/passwd
      echo "developer:x:1000:" >> /etc/group
      echo "developer:!:19000:0:99999:7:::" >> /etc/shadow
    fi
    case $SHELL in
      */bash) export SHELL=${pkgs.bash}/bin/bash ;;
      */zsh) export SHELL=${pkgs.zsh}/bin/zsh ;;
      */fish) export SHELL=${pkgs.fish}/bin/fish ;;
      *) echo "Unsupported shell: $SHELL, falling back to bash" && export SHELL=${pkgs.bash}/bin/bash ;;
    esac
    exec $SHELL
  '';

in
{
  # The dev container: everything needed for interactive development
  image = pkgs.dockerTools.streamLayeredImage {
    name = "dev";
    tag = "latest";
    
    contents = pkgs.buildEnv {
      name = "dev-root";
      paths = common.devTools ++ [
        containerDefaults.nixConf
        containerDefaults.tmpDir
        shellRc.bash
        shellRc.zsh
        shellRc.fish
      ] ++ (with pkgs; [
        bash
        coreutils
        cacert
        shadow
      ]);
    };
    
    config = {
      Entrypoint = [ "${setupScript}/bin/setup-dev-user" ];
      Cmd = [];
      Env = [
        "PATH=${pkgs.lib.makeBinPath common.devTools}:${pkgs.coreutils}/bin"
        "NIXPKGS_ALLOW_UNFREE=1"
        "FONTCONFIG_PATH=${pkgs.nerd-fonts.jetbrains-mono}/share/fonts"
        "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];
      WorkingDir = "/workspace";
    };
  };
}
