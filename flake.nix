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
        {
          # Import container modules and set packages
          packages = {
            dev-image = (import ./containers/dev { inherit pkgs; }).image;
            staticserver-image = (import ./containers/staticserver { inherit pkgs; }).image;
            default = (import ./containers/dev { inherit pkgs; }).image;
          };

          # Dev shell from shells/
          devShells = import ./shells { inherit pkgs system; };

          # Apps for loading images
          apps = {
            load-dev = {
              type = "app";
              program = "${config.packages.dev-image}";
            };

            load-staticserver = {
              type = "app";
              program = "${pkgs.writeShellScriptBin "load-staticserver" ''
                ${pkgs.podman}/bin/podman load < ${config.packages.staticserver-image}
              ''}/bin/load-staticserver";
            };
          };
        };
    };
}
