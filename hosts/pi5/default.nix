{ inputs, pkgsUnstable, ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/compat.nix
    ../../modules/common/networking.nix
    ../../modules/common/nix.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/hardware/profiles/pi5.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "pi5";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {
    inherit inputs pkgsUnstable;
    isDesktop = false;
  };
  home-manager.users.k = import ../common/home.nix;

  system.stateVersion = "25.11";
}
