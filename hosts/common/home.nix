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

  services.kaden.meetingRecorder.notionDestinations = {
    team = {
      label = "Team meetings";
      parentPageId = "3d12d5f2-8d7d-8067-ad48-c686bec6fb0a";
    };
    personal = {
      label = "Personal notes";
      parentPageId = "3d12d5f2-8d7d-804a-a6db-d6938bf100f7";
    };
  };

  services.kaden.meetingRecorder.externalRecorders.voice-memos = {
    label = "Voice recorder";
    filesystemUuid = "5AA7-563B";
    recordingsPath = "RECORD";
  };
}
