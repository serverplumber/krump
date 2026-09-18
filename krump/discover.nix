# Container discovery: containersDir -> { packages, apps }.
#
# Every container is called with the same fixed argset, so a consumer's
# `containers/app/default.nix` has exactly the access krump's own containers do.
# Containers must accept `...` -- every argument is passed to every container,
# and one that names only the arguments it uses will fail to evaluate.
{
  pkgs,
  lib,
  projectName,
  krump,
  containerLib,
  containersDir,
}:
let
  containerArgs = {
    inherit
      pkgs
      lib
      projectName
      krump
      containerLib
      ;
  };

  # A subdirectory without a default.nix is skipped rather than breaking
  # evaluation for the whole flake.
  containerNames =
    if containersDir == null then
      [ ]
    else
      lib.attrNames (
        lib.filterAttrs (
          name: type: type == "directory" && builtins.pathExists (containersDir + "/${name}/default.nix")
        ) (builtins.readDir containersDir)
      );

  discovered = lib.listToAttrs (
    map (name: {
      name = "${name}-image";
      value = (import (containersDir + "/${name}") containerArgs).image;
    }) containerNames
  );

  # The dev image is krump itself, not an example, so the module owns it. That
  # keeps `dev-image` to a single producer for krump and consumers alike.
  devImage = (import ./dev-image.nix containerArgs).image;

  packages = discovered // {
    dev-image = devImage;
  };
in
{
  inherit packages;

  # streamLayeredImage derivations *are* executables that write a tarball to
  # stdout, so the apps are a thin wrapper over the packages. `nix run
  # .#dev-image | podman load` and `nix build .#dev-image` both work.
  apps = lib.mapAttrs (name: drv: {
    type = "app";
    program = "${drv}";
    meta.description = "Stream the ${name} tarball to stdout, for `podman load`";
  }) packages;
}
