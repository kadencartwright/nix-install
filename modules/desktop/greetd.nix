{ pkgs, pkgsUnstable, ... }:

{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "greeter";
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --cmd ${pkgsUnstable.hyprland}/bin/start-hyprland";
      };
    };
  };

  systemd.services.greetd = {
    after = [ "home-manager-k.service" ];
    wants = [ "home-manager-k.service" ];
  };

  security.pam.services.greetd.enableGnomeKeyring = true;
}
