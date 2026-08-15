{ inputs, lib, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-12th-gen
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-gpu-intel
  ];

  hardware.enableRedistributableFirmware = true;
  # The current Intel microcode blob hard-resets this Gen 12 X1C before the
  # kernel can reach stage 1.  The same kernel and initrd boot normally when
  # the prepended early-microcode archive is omitted, so rely on the firmware
  # microcode until a fixed Intel release is available.
  hardware.cpu.intel.updateMicrocode = lib.mkForce false;
  hardware.graphics.enable = true;

  # The X1C is a Gen 12 / Meteor Lake system.  Keep i915 out of stage 1 so
  # disk unlock and root mounting do not depend on early graphics startup.
  # It will still load normally through udev in stage 2.
  hardware.intelgpu.loadInInitrd = false;

  boot.kernelParams = [
    "mem_sleep_default=s2idle"
    "usbcore.autosuspend=1"
    "snd_hda_intel.power_save=1"
  ];
}
