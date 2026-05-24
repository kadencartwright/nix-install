{ pkgs, ... }:

{
  programs.hyprland.enable = true;

  environment.systemPackages = with pkgs; [
    alacritty
    bemoji
    bitwarden-desktop
    brightnessctl
    chromium
    fuzzel
    gnome-keyring
    ghostty
    grim
    hypridle
    hyprlock
    hyprpaper
    hyprpolkitagent
    hyprpicker
    hyprshot
    networkmanagerapplet
    nwg-displays
    nwg-look
    pavucontrol
    qpwgraph
    slurp
    swaynotificationcenter
    xfce.thunar
    waybar
    wl-clipboard
    wl-screenrec
    xdg-utils
  ];

  services.gnome.gnome-keyring.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
}
