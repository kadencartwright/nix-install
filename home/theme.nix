{ lib, pkgs, ... }:

let
  cursorName = "breeze_cursors";
  cursorSize = 24;
in
{
  home.packages = with pkgs; [
    adw-gtk3
    kdePackages.breeze
    kdePackages.breeze-icons
  ];

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.kdePackages.breeze;
    name = cursorName;
    size = cursorSize;
  };

  gtk = {
    enable = true;

    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };

    iconTheme = {
      package = pkgs.kdePackages.breeze-icons;
      name = "breeze-dark";
    };

    font = {
      name = "Noto Sans";
      size = 10;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-cursor-theme-name = cursorName;
      gtk-cursor-theme-size = cursorSize;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-cursor-theme-name = cursorName;
      gtk-cursor-theme-size = cursorSize;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    cursor-theme = cursorName;
    cursor-size = cursorSize;
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "breeze-dark";
  };

  home.sessionVariables = {
    XCURSOR_THEME = cursorName;
    XCURSOR_SIZE = toString cursorSize;
  };

  xdg.configFile."nwg-look/config".text = lib.generators.toINI { } {
    Settings = {
      gtk-theme = "adw-gtk3-dark";
      icon-theme = "breeze-dark";
      cursor-theme = cursorName;
      cursor-size = cursorSize;
      color-scheme = "prefer-dark";
    };
  };
}
