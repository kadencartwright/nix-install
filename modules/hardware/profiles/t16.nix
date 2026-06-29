{ inputs, lib, ... }:

{
  imports = [
    # nixos-hardware has no T16 Gen 2 AMD module in the pinned revision.
    # P16s Gen 2 AMD is the closest ThinkPad sibling for the 7840U platform.
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-p16s-amd-gen2
    inputs.nixos-hardware.nixosModules.common-cpu-amd-pstate
  ];

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.graphics.enable = true;
}
