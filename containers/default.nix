{ pkgs }:
{
  tmpDir = pkgs.runCommand "tmp" {} ''
    mkdir -p $out/tmp
  '';
  nixConf = pkgs.writeTextFile {
    name = "nix.conf";
    destination = "/etc/nix/nix.conf";
    text = ''
      experimental-features = nix-command flakes
      sandbox = false
      build-users-group =
      ssl-cert-file = ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    '';
  };
}
