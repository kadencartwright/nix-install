{ pkgs, pkgsUnstable }:

pkgs.writeShellApplication {
  name = "display-control";
  runtimeInputs = [
    pkgs.brightnessctl
    pkgs.coreutils
    pkgs.ddcutil
    pkgs.gawk
    pkgs.jq
    pkgsUnstable.hyprland
  ];
  text = builtins.readFile ../scripts/display-control.sh;
}
