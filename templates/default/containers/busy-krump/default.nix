# Worked example: build on a pinned external base image.
#
# `just update-busybox` regenerates ../base-image-busybox-latest.nix with
# nix-prefetch-docker, so the base enters the tree as content-addressed nix
# rather than a floating tag.
{ pkgs, projectName, ... }:
let
  baseImage = pkgs.dockerTools.pullImage (import ../base-image-busybox-latest.nix);

  greetScript = pkgs.writeShellScriptBin "greet" ''
    echo "${projectName}, on busybox."
  '';
in
{
  image = pkgs.dockerTools.streamLayeredImage {
    # Derived from projectName, so this example does not hardcode "krump" into
    # an image name in somebody else's project.
    name = "busy-${projectName}";
    tag = "latest";
    fromImage = baseImage;
    contents = [ greetScript ];
    config = {
      Cmd = [ "${greetScript}/bin/greet" ];
    };
  };
}
