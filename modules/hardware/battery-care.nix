{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.batteryCare;
  control = pkgs.writeShellApplication {
    name = "battery-charge";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      mode="''${1:-sync}"
      case "$mode" in sync|full|default) ;; *) echo 'Usage: battery-charge {full|default}' >&2; exit 2 ;; esac
      install -d -m 0755 /run/battery-care
      exec 9>/run/battery-care/lock
      flock 9
      online=0
      for supply in /sys/class/power_supply/*; do
        [[ -r "$supply/type" && -r "$supply/online" ]] || continue
        case "$(cat "$supply/type")" in
          Mains|USB*|Wireless) [[ "$(cat "$supply/online")" != 1 ]] || online=1 ;;
        esac
      done
      if [[ "$mode" == full ]]; then
        if [[ "$online" != 1 ]]; then
          echo 'Connect the charger before requesting a full charge.' >&2
          exit 1
        fi
        touch /run/battery-care/full
      fi
      if [[ "$mode" == default || "$online" == 0 ]]; then
        rm -f /run/battery-care/full
      fi
      start=${toString cfg.startThreshold}
      stop=${toString cfg.stopThreshold}
      if [[ -e /run/battery-care/full ]]; then start=99; stop=100; fi
      found=0
      for battery in /sys/class/power_supply/*; do
        low="$battery/charge_control_start_threshold"
        high="$battery/charge_control_end_threshold"
        [[ -w "$low" && -w "$high" ]] || continue
        found=1
        if [[ "$(cat "$low")" != "$start" || "$(cat "$high")" != "$stop" ]]; then
          # Lower start first so either direction preserves start < stop.
          echo 0 > "$low"
          echo "$stop" > "$high"
          echo "$start" > "$low"
        fi
      done
      if [[ "$found" == 0 && "$mode" != sync ]]; then
        echo 'No supported battery charging controls found.' >&2
        exit 1
      fi
    '';
  };
in
{
  options.hardware.batteryCare = {
    enable = lib.mkEnableOption "persistent battery charge thresholds and a temporary full-charge override";
    startThreshold = lib.mkOption {
      type = lib.types.ints.between 1 99;
      default = 90;
    };
    stopThreshold = lib.mkOption {
      type = lib.types.ints.between 2 100;
      default = 95;
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.startThreshold < cfg.stopThreshold;
        message = "Battery start threshold must be below the stop threshold.";
      }
    ];
    environment.systemPackages = [ control ];
    security.sudo.extraRules = [
      {
        users = [ "k" ];
        commands =
          lib.concatMap
            (
              command:
              map
                (mode: {
                  command = "${command} ${mode}";
                  options = [ "NOPASSWD" ];
                })
                [
                  "full"
                  "default"
                ]
            )
            [
              "${control}/bin/battery-charge"
              "/run/current-system/sw/bin/battery-charge"
            ];
      }
    ];
    systemd.services.battery-care = {
      description = "Apply battery charge limits";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-trigger.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${control}/bin/battery-charge sync";
      };
    };
    # Also reconcile after resume or missed power-supply events.
    systemd.timers.battery-care = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitInactiveSec = "30s";
      };
    };
    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", ACTION=="add|change|remove", RUN+="${lib.getExe' pkgs.systemd "systemctl"} --no-block restart battery-care.service"
    '';
  };
}
