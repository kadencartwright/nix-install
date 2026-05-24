{ pkgs, ... }:

{
  users.users.k = {
    isNormalUser = true;
    description = "k";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
    # Bootstrap password for VM and first metal login. Change immediately after install.
    initialPassword = "nixos";
  };

  virtualisation.vmVariant = {
    users.users.k.initialPassword = "nixos";
  };
}
