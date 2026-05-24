{ lib, ... }:

{
  # Placeholder for Minisforum UM890 Pro-class AMD mini PC.
  # Replace with nixos-generate-config output after first boot if needed.
  boot.initrd.availableKernelModules = lib.mkDefault [
    "ahci"
    "nvme"
    "sd_mod"
    "usb_storage"
    "xhci_pci"
  ];
  boot.initrd.kernelModules = lib.mkDefault [ ];
  boot.kernelModules = lib.mkDefault [
    "amdgpu"
  ];
  boot.extraModulePackages = lib.mkDefault [ ];
}
