{ pkgs }:
{
  container = name: (import ../containers/${name} { inherit pkgs; }).image;
}
