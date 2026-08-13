{
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  codexbar = pkgs.callPackage ../../packages/codexbar.nix { };
  hyprwhspr = pkgsUnstable.callPackage ../../packages/hyprwhspr.nix { };
in
{
  environment.systemPackages = with pkgs; [
    bluetui
    buildkit
    codexbar
    hyprwhspr
    slack
  ];

  programs.ydotool.enable = true;

  # Keep Podman for Distrobox, but expose the real Docker CLI and daemon on
  # developer workstations instead of Podman's Docker compatibility shim.
  virtualisation.docker.enable = true;
  virtualisation.podman.dockerCompat = lib.mkForce false;

  users.users.k.extraGroups = [
    "docker"
    "ydotool"
  ];
}
