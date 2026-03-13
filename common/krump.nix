let
  load = name: (import ../containers/${name}
    { inherit pkgs; }).image;
in
{
  streamContainer = name: load name;
  app = name: {
    type = "app";
    program = "${load name}";
  };
}
