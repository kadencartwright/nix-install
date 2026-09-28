{ pkgs, ... }:

{
  # Avahi in common/networking.nix provides network printer discovery.
  services.printing = {
    enable = true;
    browsed.enable = true;
    drivers = with pkgs; [
      gutenprint
      hplip
    ];
  };

  # Includes the GUI and its D-Bus/udev integration for printer management.
  programs.system-config-printer.enable = true;

  # Driverless USB printing; also enables SANE with sane-airscan for scanners.
  services.ipp-usb.enable = true;
  environment.systemPackages = [ pkgs.simple-scan ];
}
