{ pkgs, common }:
{
  bash = pkgs.writeTextFile {
    name = "bashrc";
    destination = "/etc/bashrc";
    text = common.shellHook "bash";
  };

  zsh = pkgs.writeTextFile {
    name = "zshrc";
    destination = "/etc/zshrc";
    text = common.shellHook "zsh";
  };

  fish = pkgs.writeTextFile {
    name = "fish-config";
    destination = "/etc/fish/config.fish";
    text = common.shellHook "fish";
  };
}
