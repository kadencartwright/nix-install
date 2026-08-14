{ ... }:

{
  # Placeholder for Lenovo ThinkPad X1 Carbon Gen 13.
  # Keep both Intel VMD and native NVMe available in stage 1: depending on the
  # firmware storage setting, the internal drive may sit behind VMD. The VM
  # does not exercise this hardware path.
  boot.initrd.availableKernelModules = [
    "vmd"
    "nvme"
    "thunderbolt"
    "usb_storage"
    "xhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  # The nixos-hardware Lunar Lake profile selects the Xe graphics driver.
  # PCI devices such as the GPU and Wi-Fi can otherwise autoload normally.
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
}
