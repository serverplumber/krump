# One `nix fmt` for the whole tree, and a `checks.<system>.treefmt` that makes
# `nix flake check` actually enforce it. Replaces the old `just fmt`, whose
# `**/*.nix` glob ran without globstar and silently skipped five of eleven
# nix files -- including flake.nix.
{ ... }:
{
  perSystem = _: {
    treefmt = {
      projectRootFile = "flake.nix";
      programs = {
        nixfmt.enable = true;
        shfmt.enable = true;
        shellcheck.enable = true;
        mdformat.enable = true;
        just.enable = true;
      };
    };
  };
}
