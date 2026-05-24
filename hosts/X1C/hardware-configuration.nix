{ lib, ... }:

{
  # Placeholder for Lenovo ThinkPad X1 Carbon Gen 13.
  # Replace with nixos-generate-config output after first boot if needed.
  boot.initrd.availableKernelModules = lib.mkDefault [
    "nvme"
    "thunderbolt"
    "usb_storage"
    "xhci_pci"
  ];
  boot.initrd.kernelModules = lib.mkDefault [ ];
  boot.kernelModules = lib.mkDefault [
    "i915"
    "iwlwifi"
  ];
  boot.extraModulePackages = lib.mkDefault [ ];
}
