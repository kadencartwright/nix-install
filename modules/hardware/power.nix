{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.power-profiles-daemon.autoSwitchOnPowerSource;

  syncPowerProfile = pkgs.writeShellScript "sync-power-profile" ''
    set -eu

    profile=balanced

    # A laptop can expose several power supplies (for example, a barrel jack
    # and USB-C ports). Treat it as plugged in if any external supply is online.
    for supply in /sys/class/power_supply/*; do
      [ -r "$supply/type" ] && [ -r "$supply/online" ] || continue

      IFS= read -r type < "$supply/type"
      case "$type" in
        Mains|USB*|Wireless)
          IFS= read -r online < "$supply/online"
          if [ "$online" = 1 ]; then
            profile=performance
            break
          fi
          ;;
      esac
    done

    exec ${lib.getExe' pkgs.power-profiles-daemon "powerprofilesctl"} set "$profile"
  '';
in
{
  options.services.power-profiles-daemon.autoSwitchOnPowerSource.enable =
    lib.mkEnableOption "automatic performance-on-AC and balanced-on-battery profile switching";

  config = lib.mkMerge [
    {
      services.power-profiles-daemon.enable = true;

      # Wayle's power-profile widget changes this over D-Bus. Authorize the sole
      # interactive user so clicks can switch profiles without a password prompt.
      security.polkit.extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (action.id == "org.freedesktop.UPower.PowerProfiles.switch-profile" &&
              subject.user == "k") {
            return polkit.Result.YES;
          }
        });
      '';
    }

    (lib.mkIf cfg.enable {
      # Synchronize once during boot, then again whenever an AC/USB-C power
      # supply appears, disappears, or changes its online state.
      systemd.services.power-profile-on-power-source-change = {
        description = "Select power profile for the current power source";
        wantedBy = [ "multi-user.target" ];
        requires = [ "power-profiles-daemon.service" ];
        after = [ "power-profiles-daemon.service" ];

        serviceConfig = {
          Type = "oneshot";
          ExecStart = syncPowerProfile;
        };
      };

      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="power_supply", ATTR{online}=="[01]", RUN+="${lib.getExe' pkgs.systemd "systemctl"} --no-block restart power-profile-on-power-source-change.service"
        ACTION=="change", SUBSYSTEM=="power_supply", ATTR{online}=="[01]", RUN+="${lib.getExe' pkgs.systemd "systemctl"} --no-block restart power-profile-on-power-source-change.service"
        ACTION=="remove", SUBSYSTEM=="power_supply", RUN+="${lib.getExe' pkgs.systemd "systemctl"} --no-block restart power-profile-on-power-source-change.service"
      '';
    })
  ];
}
