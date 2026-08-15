{ ... }:

{
  # Lenovo ThinkPad X1 Carbon Gen 12 (21KC, Meteor Lake).
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
  # PCI devices such as the i915 GPU and Wi-Fi autoload normally in stage 2.
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];
}
