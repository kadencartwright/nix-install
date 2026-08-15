{ pkgs, ... }:

{
  xdg.portal = {
    enable = true;
    # Chromium may invoke xdg-open from a wrapper/FHS environment where the
    # desktop handler is not visible. Route URI launches through the desktop
    # portal so custom schemes such as Slack's authentication callback reach
    # the registered host application.
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}
