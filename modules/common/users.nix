{ pkgs, ... }:

{
  users.users.k = {
    isNormalUser = true;
    description = "k";
    extraGroups = [
      "networkmanager"
      "podman"
      "wheel"
    ];
    subGidRanges = [
      {
        count = 65536;
        startGid = 100000;
      }
    ];
    subUidRanges = [
      {
        count = 65536;
        startUid = 100000;
      }
    ];
    shell = pkgs.zsh;
    # Bootstrap password for VM and first metal login. Change immediately after install.
    initialPassword = "nixos";
  };

  virtualisation.vmVariant = {
    users.users.k.initialPassword = "nixos";
  };
}
