{
  inputs,
  lib,
  pkgsUnstable,
  ...
}:

{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/boot.nix
    ../../modules/common/compat.nix
    ../../modules/common/networking.nix
    ../../modules/common/nix.nix
    ../../modules/common/security.nix
    ../../modules/common/users.nix
    ../../modules/desktop/applications.nix
    ../../modules/desktop/audio.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/lemurs.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/portals.nix
    ../../modules/hardware/bluetooth.nix
    ../../modules/hardware/fingerprint.nix
    ../../modules/hardware/power.nix
    ../../modules/hardware/tpm.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.backupFileExtension = "hm-backup";
  home-manager.extraSpecialArgs = {
    inherit inputs pkgsUnstable;
    isDesktop = true;
  };
  home-manager.users.k = import ./home.nix;

  # Keep `nixos-rebuild build-vm` useful for interactive desktop validation.
  # These overrides apply only to the generated QEMU VM, never to real hosts.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 4;
      diskSize = 32768;
      resolution = {
        x = 1440;
        y = 900;
      };
      forwardPorts = [
        {
          from = "host";
          host = {
            address = "127.0.0.1";
            port = 22222;
          };
          guest = {
            address = "10.0.2.15";
            port = 22;
          };
        }
      ];
    };

    # Password SSH is enabled only in the VM so the interactive test harness
    # can drive it. Hyprland needs QEMU's accelerated virtio GPU; forcing Mesa's
    # software DRI path makes current Aquamarine/Hyprland crash during startup.
    services.openssh.settings.PasswordAuthentication = lib.mkForce true;
  };

  system.stateVersion = "25.11";
}
