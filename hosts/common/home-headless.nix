{
  imports = [
    ../../home/cli.nix
    ../../home/desktop.nix
    ../../home/dotfiles-headless.nix
    ../../home/editors.nix
    ../../home/git.nix
    ../../home/shell.nix
    ../../home/terminals.nix
  ];

  home.username = "k";
  home.homeDirectory = "/home/k";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;
}
