{ inputs, ... }:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/boot.nix
    ../../modules/common/networking.nix
    ../../modules/common/nix.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/desktop/audio.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/portals.nix
    ../../modules/hardware/bluetooth.nix
    ../../modules/hardware/fingerprint.nix
    ../../modules/hardware/power.nix
    ../../modules/hardware/tpm.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {
    inherit inputs;
  };
  home-manager.users.k = import ./home.nix;

  system.stateVersion = "25.11";
}
