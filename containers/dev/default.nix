{ pkgs, projectName }:

let
  krump = import ../../krump { inherit pkgs; };
  containerDefaults = import ../../containers { inherit pkgs; };
  shellRc = import ./shellrc.nix { inherit pkgs krump; };
  # Setup script to create developer user if needed (optional for local dev)
  setupScript = pkgs.writeShellScriptBin "setup-dev-user" ''
    if ! id -u developer > /dev/null 2>&1; then
      echo "developer:x:1000:1000::/workspace:/bin/sh" >> /etc/passwd
      echo "developer:x:1000:" >> /etc/group
      echo "developer:!:19000:0:99999:7:::" >> /etc/shadow
    fi
    if [ "$#" -gt 0 ]; then
      exec "$@"
    fi
    case $SHELL in
      */sh|*/bash) export SHELL=${pkgs.bash}/bin/bash ;;
      */zsh) export SHELL=${pkgs.zsh}/bin/zsh ;;
      */fish) export SHELL=${pkgs.fish}/bin/fish ;;
      *) echo "Unsupported shell: $SHELL, falling back to bash" && export SHELL=${pkgs.bash}/bin/bash ;;
    esac
    exec $SHELL
  '';
  users = containerDefaults.makeUsers [
    {
      name = "root";
      uid = 0;
      gid = 0;
      home = "/root";
      shell = "${pkgs.bash}/bin/bash";
    }
    {
      name = "vscode";
      uid = 1000;
      gid = 1000;
      home = "/home/vscode";
      shell = "${pkgs.bash}/bin/bash";
    }
  ];
  # The FHS shim in fakeRootCommands exists because VSCode's remote server
  # assumes Debian-style paths. Those paths are arch-dependent, so derive them
  # instead of hardcoding x86_64: on aarch64 the hardcoded version produced an
  # image that built fine and shimmed nothing, because `ln -s` happily creates
  # a dangling symlink to a loader that doesn't exist under that name.
  inherit (pkgs.stdenv.hostPlatform) parsed isx86_64;
  multiarch = "${parsed.cpu.name}-${parsed.kernel.name}-${parsed.abi.name}";
  loader = builtins.baseNameOf pkgs.stdenv.cc.bintools.dynamicLinker;
  # Debian keeps the x86_64 loader in /lib64 and the aarch64 loader in /lib.
  loaderDir = if isx86_64 then "/lib64" else "/lib";

  osRelease = pkgs.writeTextFile {
    name = "os-release";
    destination = "/etc/os-release";
    text = ''
      ID=nixos
      NAME="NixOS"
      PRETTY_NAME="NixOS (krump)"
    '';
  };

in
{
  # The dev container: everything needed for interactive development
  image = pkgs.dockerTools.streamLayeredImage {
    name = "${projectName}-dev";
    tag = "latest";

    contents = pkgs.buildEnv {
      name = "dev-root";
      paths =
        krump.devTools
        ++ [
          setupScript
          containerDefaults.nixConf
          containerDefaults.tmpDir
          shellRc.bash
          shellRc.zsh
          shellRc.fish
          users.passwd
          users.group
          users.shadow
          osRelease
        ]
        ++ (with pkgs; [
          bash
          coreutils
          cacert
          shadow
        ]);
    };

    fakeRootCommands = ''
      mkdir -p /root
      chmod 777 /root
      mkdir -p /home/vscode
      mkdir -p /workspace
      mkdir -p /usr/bin
      mkdir -p ${loaderDir}
      mkdir -p /lib/${multiarch}
      mkdir -p /usr/lib/${multiarch}
      cp ${pkgs.glibc}/lib/libc.so.6 /lib/${multiarch}/libc.so.6
      cp ${pkgs.glibc}/lib/libm.so.6 /lib/${multiarch}/libm.so.6
      cp ${pkgs.stdenv.cc.cc.lib}/lib/libstdc++.so.6 /usr/lib/${multiarch}/libstdc++.so.6
      cp ${pkgs.stdenv.cc.cc.lib}/lib/libstdc++.so.6 /usr/lib/libstdc++.so.6
      # Fail loudly if the loader name ever drifts, rather than dangling.
      test -e ${pkgs.glibc}/lib/${loader}
      ln -s ${pkgs.glibc}/lib/${loader} ${loaderDir}/${loader}
      cp ${pkgs.gnugrep}/bin/grep /usr/bin/grep
      cp ${pkgs.gnused}/bin/sed /usr/bin/sed
      cp ${pkgs.coreutils}/bin/* /usr/bin/
      cp --remove-destination ${pkgs.bash}/bin/bash /bin/sh
      chown -R 1000:1000 /home/vscode
    '';
    enableFakechroot = true;

    config = {
      Entrypoint = [ "${setupScript}/bin/setup-dev-user" ];
      Cmd = [ ];
      # Container-specific vars here; everything shared with the dev shells
      # comes from krump.env so the two can't drift.
      Env = [
        "PATH=${pkgs.lib.makeBinPath krump.devTools}:${pkgs.coreutils}/bin:/bin:/usr/bin"
        "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "LD_LIBRARY_PATH=/usr/lib/${multiarch}:/lib/${multiarch}"
      ]
      ++ pkgs.lib.mapAttrsToList (k: v: "${k}=${v}") krump.env;
      WorkingDir = "/workspace";
    };
  };
}
