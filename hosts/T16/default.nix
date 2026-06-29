{
  imports = [
    ../common/default.nix
    ../../modules/hardware/profiles/t16.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "T16";
}
