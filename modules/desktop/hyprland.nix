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
      ghostty
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
      wayle
    ]);

  services.gnome.gnome-keyring.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
}
