{ inputs, lib, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-5
  ];

  hardware.enableRedistributableFirmware = true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
