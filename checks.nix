# Checks that only make sense for krump's own repo, not for a consumer -- so
# they live here rather than in the exported module.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # templates/default/justfile is a byte-identical copy of krump's own
      # justfile: the template ships a copy because `just` cannot import recipes
      # out of a nix store path. Nothing but a check keeps the copy honest, and
      # it had already drifted once before this existed.
      checks.template-justfile-in-sync = pkgs.runCommand "template-justfile-in-sync" { } ''
        if diff -u ${./justfile} ${./templates/default/justfile}; then
          touch $out
        else
          echo
          echo "templates/default/justfile has drifted from ./justfile." >&2
          echo "Fix: cp justfile templates/default/justfile" >&2
          exit 1
        fi
      '';
    };
}
