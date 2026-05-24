{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    dejavu_fonts
    font-awesome
    nerd-fonts.meslo-lg
  ];
}
