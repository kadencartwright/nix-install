{ pkgs, pkgsUnstable, ... }:

{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        user = "greeter";
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --cmd ${pkgsUnstable.hyprland}/bin/Hyprland";
      };
    };
  };

  security.pam.services.greetd.enableGnomeKeyring = true;
}
