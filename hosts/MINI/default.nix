{
  imports = [
    ../common/headless.nix
    ../../modules/hardware/profiles/mini.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "MINI";
}
