{
  description = "Nix-based dev and container framework (nix-in-podman)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          self',
          pkgs,
          system,
          ...
        }:
        let
          krump = import ./common/krump.nix { inherit pkgs ; };
        in
        {
          # Import container modules and set packages
          packages = {
            default            = krump.container "dev";
            busy-krump         = krump.container "busy-krump";
            dev-image          = krump.container "dev";
            staticserver-image = krump.container "staticserver";
          };

          # Dev shell from shells/
          devShells = import ./shells { inherit pkgs system; };

          # Apps for loading images
          apps = {
            streamDev = krump.streamContainer "dev";
            streamStaticserver = krump.streamContainer "staticServer";
          };
        };
    };
}
