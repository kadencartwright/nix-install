{ lib, ... }:

{
  # Current host scan: ThinkPad Z16 Gen 2, Ryzen 9 PRO 7940HS,
  # Radeon 780M iGPU, Radeon RX 6500M-class dGPU, MT7922 Wi-Fi.
  boot.initrd.availableKernelModules = lib.mkDefault [
    "nvme"
    "sdhci_pci"
    "thunderbolt"
    "usb_storage"
    "xhci_pci"
  ];
  boot.initrd.kernelModules = lib.mkDefault [ ];
  boot.kernelModules = lib.mkDefault [
    "amdgpu"
    "mt7921e"
  ];
  boot.extraModulePackages = lib.mkDefault [ ];
}
