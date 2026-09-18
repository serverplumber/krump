{
  description = "Nix-based dev and container framework (nix-in-podman)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    flake-parts.url = "github:hercules-ci/flake-parts";
    # Without this, flake-parts drags in its own nixpkgs.lib as a third input
    # node, pinned separately from the nixpkgs everything else resolves against.
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      treefmt-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./krump/flake-module.nix
        ./treefmt.nix
        ./checks.nix
        treefmt-nix.flakeModule
      ];

      # krump builds itself with its own exported module. There is no separate
      # "krump's own config" path, so the module a consumer imports is the one
      # exercised by every `just dev` run here.
      krump.projectName = nixpkgs.lib.trim (builtins.readFile ./project-name);
      krump.containersDir = ./containers;

      # The library. `flakeModule` is the conventional singular alias for the
      # default; both names are stable API.
      flake.flakeModule = ./krump/flake-module.nix;
      flake.flakeModules.default = ./krump/flake-module.nix;

      flake.templates.default = {
        path = ./templates/default;
        description = "krump: nix dev container & build pipeline";
      };
    };
}
