{ lib, ... }:

{
  # Raspberry Pi 5 boots from microSD. Keep this layout separate from the
  # x86 LUKS/LVM disko profile: Pi firmware needs a plain FAT boot partition,
  # and encrypted root on Pi is better handled later with a Pi-specific
  # initrd unlock plan.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  fileSystems."/boot/firmware" = lib.mkDefault {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [
      "nofail"
      "x-systemd.automount"
    ];
  };

  swapDevices = lib.mkDefault [ ];
}
