{ pkgs, pkgsUnstable, ... }:

{
  programs.hyprland = {
    enable = true;
    package = pkgsUnstable.hyprland;
    portalPackage = pkgsUnstable.xdg-desktop-portal-hyprland;
  };

  programs.chromium = {
    enable = true;
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
    ];
  };

  environment.systemPackages =
    (with pkgs; [
      alacritty
      bemoji
      bitwarden-desktop
      brightnessctl
      chromium
      fuzzel
      gnome-keyring
      grim
      libnotify
      networkmanagerapplet
      nwg-displays
      nwg-look
      pavucontrol
      playerctl
      pulsemixer
      qpwgraph
      slurp
      spotify
      swaynotificationcenter
      thunar
      waybar
      quickshell
      wl-clipboard
      wl-screenrec
      xdg-utils
    ])
    ++ (with pkgsUnstable; [
      hypridle
      hyprlock
      hyprpaper
      hyprpolkitagent
      hyprpicker
      hyprshot
    ]);

  services.gnome.gnome-keyring.enable = true;
  services.udev.packages = [ pkgs.brightnessctl ];
  services.gvfs.enable = true;
  services.tumbler.enable = true;
}
