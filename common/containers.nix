{ inputs, ... }:
{
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  perSystem = { pkgs, config, ... }:
  let
    krump = import ./krump.nix { inherit pkgs; };
  in
  {
    apps = {
      dev-image          = krump.streamContainer "dev";
      staticserver-image = krump.streamContainer "staticserver";
      busykrump-image    = krump.streamContainer "busy-krump";
    };
  };
}
