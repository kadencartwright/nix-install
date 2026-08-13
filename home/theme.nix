{ inputs, pkgs, ... }:

let
  atomOneDark = pkgs.callPackage ../packages/atom-one-dark-theme.nix { };
  cursorName = "breeze_cursors";
  cursorSize = 24;
  gtkThemeName = "AtomOneDarkTheme";
  iconThemeName = "Atom One Dark";
in
{
  home.packages = with pkgs; [
    atomOneDark
    gtk-engine-murrine
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
      package = atomOneDark;
      name = gtkThemeName;
    };

    iconTheme = {
      package = atomOneDark;
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

    # AtomOneDarkTheme has GTK 2/3 assets. Keep GTK4/libadwaita on its
    # supported dark color scheme instead of importing incompatible GTK3 CSS.
    gtk4.theme = null;
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
    platformTheme.name = "gtk";
    style.name = "gtk2";
  };

  home.sessionVariables = {
    XCURSOR_THEME = cursorName;
    XCURSOR_SIZE = toString cursorSize;
  };

  xdg.configFile."nwg-look/config".source = "${inputs.dotfiles}/nwg-look/config";
}
