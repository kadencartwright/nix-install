{
  imports = [
    ../common/default.nix
    ../../modules/hardware/profiles/x1c.nix
    ./hardware-configuration.nix
  ];

  home-manager.users.k.services.kaden.cloudMusic = {
    enable = true;
    remote = "gdrive-personal:Music";
  };

  networking.hostName = "X1C";
}
