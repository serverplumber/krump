{ pkgs }:
{
  streamContainer = name: {
    type = "app";
    program = "${(import ../containers/${name} { inherit pkgs; }).image}";
  };
}
