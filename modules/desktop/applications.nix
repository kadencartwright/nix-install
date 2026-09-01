{
  inputs,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  codexbar = pkgs.callPackage ../../packages/codexbar.nix { };
  hyprwhspr = pkgsUnstable.callPackage ../../packages/hyprwhspr.nix { };
  obsbotCli = inputs.obsbot-cli.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  environment.systemPackages =
    (with pkgs; [
      bluetui
      buildkit
      codexbar
      hyprwhspr
      localsend
      obsidian
      slack
    ])
    ++ [ obsbotCli ];

  services.udev.packages = [ obsbotCli ];

  programs.ydotool.enable = true;

  # LocalSend discovery uses multicast UDP and transfers use TCP on the same
  # configurable default port.
  networking.firewall = {
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };

  # Keep Podman for Distrobox, but expose the real Docker CLI and daemon on
  # developer workstations instead of Podman's Docker compatibility shim.
  virtualisation.docker.enable = true;
  virtualisation.podman.dockerCompat = lib.mkForce false;

  users.users.k.extraGroups = [
    "docker"
    "ydotool"
  ];
}
