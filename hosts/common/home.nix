{
  imports = [
    ../../home/cloud-music.nix
    ../../home/cli.nix
    ../../home/desktop.nix
    ../../home/dotfiles.nix
    ../../home/editors.nix
    ../../home/git.nix
    ../../home/meeting-recorder.nix
    ../../home/shell.nix
    ../../home/terminals.nix
    ../../home/theme.nix
  ];

  home.username = "k";
  home.homeDirectory = "/home/k";
  home.stateVersion = "25.11";

  programs.omarchy-theme = {
    enable = true;
    defaultTheme = "tokyo-night";
  };

  programs.home-manager.enable = true;
}
