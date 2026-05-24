{ pkgs, ... }:

let
  githubUser = "kadencartwright";
  githubKeysUrl = "https://github.com/${githubUser}.keys";
in
{
  networking.networkmanager.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  programs.mosh = {
    enable = true;
    openFirewall = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
    extraConfig = ''
      AuthorizedKeysCommand ${pkgs.curl}/bin/curl -fsSL ${githubKeysUrl}
      AuthorizedKeysCommandUser nobody
    '';
  };

  services.fail2ban.enable = true;

  users.users.k.openssh.authorizedKeys.keyFiles = [
    (pkgs.fetchurl {
      url = githubKeysUrl;
      hash = "sha256-KeBzWlPuS1zo+/nKyrEg+tYb67bw/ALNBlLYHkpkYO8=";
    })
  ];
}
