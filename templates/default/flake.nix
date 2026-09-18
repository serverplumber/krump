{
  description = "A krump project";

  inputs = {
    krump.url = "github:serverplumber/krump";

    # Follow krump's pins so there is one real input to update. Point nixpkgs at
    # your own url to take that over -- krump will use whatever you give it.
    nixpkgs.follows = "krump/nixpkgs";
    flake-parts.follows = "krump/flake-parts";
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      krump,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ krump.flakeModule ];

      # Rename your project by editing `project-name` -- the justfile reads the
      # same file, so the two cannot drift.
      krump.projectName = nixpkgs.lib.trim (builtins.readFile ./project-name);

      # Every subdirectory here with a default.nix becomes `<dirname>-image`.
      # Drop in containers/postgres/default.nix and `postgres-image` exists;
      # there is no list to keep in sync.
      krump.containersDir = ./containers;

      perSystem = _: {
        # Your tools. These land in `nix develop` *and* in the dev container
        # image, because both consume the same list.
        krump.extraTools = [ ];

        # krump.extraEnv = { RUST_BACKTRACE = "1"; };
        # krump.extraShellHook = ''echo "hello from the dev shell"'';
      };
    };
}
