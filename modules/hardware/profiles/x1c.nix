{ inputs, lib, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-13th-gen
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
  ];

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.graphics.enable = true;

  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "usbcore.autosuspend=1"
    "snd_hda_intel.power_save=1"
  ];
}
