{ pkgs }:
let
  baseImage = pkgs.dockerTools.pullImage (import ../base-image-busybox-latest.nix);
  
  krumpScript = pkgs.writeShellScriptBin "krump" ''
    echo "krump."
  '';
in
{
  image = pkgs.dockerTools.streamLayeredImage {
    name = "krump";
    tag = "latest";
    fromImage = baseImage;
    contents = [ krumpScript ];
    config = {
      Cmd = [ "${krumpScript}/bin/krump" ];
    };
  };
}
