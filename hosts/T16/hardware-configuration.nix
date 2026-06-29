{ lib, ... }:

{
  # Placeholder for Lenovo ThinkPad T16 Gen 2 AMD, Ryzen 7 PRO 7840U,
  # Radeon 780M iGPU. Replace with nixos-generate-config output after
  # first boot if the storage or peripheral module set differs.
  boot.initrd.availableKernelModules = lib.mkDefault [
    "nvme"
    "thunderbolt"
    "usb_storage"
    "xhci_pci"
  ];
  boot.initrd.kernelModules = lib.mkDefault [ ];
  boot.kernelModules = lib.mkDefault [
    "amdgpu"
  ];
  boot.extraModulePackages = lib.mkDefault [ ];
}
