{ lib, pkgs, ... }:

let
  cursorName = "breeze_cursors";
  cursorSize = 24;
  gtkThemeName = "adw-gtk3-dark";
  iconThemeName = "breeze-dark";
  qtStyleName = "adwaita-dark";
in
{
  home.packages = with pkgs; [
    adw-gtk3
    adwaita-qt
    adwaita-qt6
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
    colorScheme = "dark";

    theme = {
      package = pkgs.adw-gtk3;
      name = gtkThemeName;
    };

    iconTheme = {
      package = pkgs.kdePackages.breeze-icons;
      name = iconThemeName;
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
    gtk-theme = gtkThemeName;
    icon-theme = iconThemeName;
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = qtStyleName;
  };

  home.sessionVariables = {
    GTK_THEME = gtkThemeName;
    XCURSOR_THEME = cursorName;
    XCURSOR_SIZE = toString cursorSize;
  };

  xdg.configFile."nwg-look/config".text = lib.generators.toINI { } {
    Settings = {
      gtk-theme = gtkThemeName;
      icon-theme = iconThemeName;
      cursor-theme = cursorName;
      cursor-size = cursorSize;
      color-scheme = "prefer-dark";
    };
  };
}
