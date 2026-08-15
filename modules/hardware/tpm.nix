{ pkgs, ... }:

{
  security.tpm2.enable = true;
  systemd.tpm2.enable = true;
  boot.initrd.systemd.tpm2.enable = true;

  environment.systemPackages = with pkgs; [
    tpm2-tools
    tpm2-tss
  ];
}
