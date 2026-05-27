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
      AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u.github /etc/ssh/authorized_keys.d/%u .ssh/authorized_keys
    '';
  };

  services.fail2ban.enable = true;

  systemd.tmpfiles.rules = [
    "d /etc/ssh/authorized_keys.d 0755 root root -"
  ];

  systemd.services.update-github-authorized-keys = {
    description = "Update SSH authorized keys from GitHub";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    before = [ "sshd.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      coreutils
      curl
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      tmp="$(mktemp)"
      trap 'rm -f "$tmp"' EXIT

      curl -fsSL --retry 3 --connect-timeout 10 "${githubKeysUrl}" -o "$tmp"
      test -s "$tmp"

      install -m 0644 -o root -g root "$tmp" /etc/ssh/authorized_keys.d/k.github
    '';
  };

  systemd.timers.update-github-authorized-keys = {
    description = "Update SSH authorized keys from GitHub daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1d";
      RandomizedDelaySec = "30min";
      Persistent = true;
    };
  };
}
