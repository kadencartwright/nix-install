{
  imports = [
    ../common/default.nix
    ../../modules/hardware/profiles/z16.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "Z16";
}
