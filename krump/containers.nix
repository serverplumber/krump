{ inputs, projectName, ... }:
{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  perSystem = { pkgs, config, ... }:
  let
    krump = import ./krump.nix { inherit pkgs projectName; };
    containerDirs = builtins.attrNames (
      pkgs.lib.filterAttrs
       (name: type: type == "directory")
       (builtins.readDir ../containers)
    );
  in
  {
    # Container images are Linux artifacts, so these apps only exist on Linux.
    # That is not a macOS limitation: krump's macOS path is nix-in-podman, and
    # podman on macOS is a Linux VM — nix runs inside it as aarch64-linux and
    # builds the Linux image natively. Emitting darwin apps here would only
    # offer a host-nix build that cannot work without a Linux builder.
    apps = pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
      builtins.listToAttrs (map (name: {
        name = "${name}-image";
        value = krump.streamContainer name;
      }) containerDirs)
    );
  };
}
