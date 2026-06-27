{ pkgs, pkgsUnstable, ... }:

{
  programs.hyprland = {
    enable = true;
    package = pkgsUnstable.hyprland;
    portalPackage = pkgsUnstable.xdg-desktop-portal-hyprland;
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
      ghostty
      grim
      networkmanagerapplet
      nwg-displays
      nwg-look
      pavucontrol
      playerctl
      qpwgraph
      slurp
      swaynotificationcenter
      xfce.thunar
      waybar
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
  services.gvfs.enable = true;
  services.tumbler.enable = true;
}
