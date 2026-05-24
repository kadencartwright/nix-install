{
  imports = [
    ../common/default.nix
    ../../modules/hardware/profiles/x1c.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "X1C";
}
