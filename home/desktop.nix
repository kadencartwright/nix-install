{
  isDesktop ? false,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  voxtype = pkgsUnstable.voxtype.override { vulkanSupport = true; };
  voxtypeHistory = pkgs.writeShellApplication {
    name = "voxtype-history";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      umask 077
      history_dir="''${XDG_STATE_HOME:-''${HOME}/.local/state}/voxtype"
      history_file="$history_dir/history.jsonl"
      mkdir -p "$history_dir"

      transcription="$(cat)"
      exec 9>"$history_file.lock"
      flock -x 9

      jq -cn \
        --arg text "$transcription" \
        --argjson timestamp "$(date +%s)" \
        '{ text: $text, timestamp: $timestamp }' >> "$history_file"

      if (( $(wc -l < "$history_file") > 50 )); then
        history_next="$(mktemp --tmpdir="$history_dir" history.XXXXXX)"
        tail -n 50 "$history_file" > "$history_next"
        mv "$history_next" "$history_file"
      fi

      printf '%s' "$transcription"
    '';
  };
  batteryHistory = pkgs.writeShellApplication {
    name = "battery-history-sample";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      battery_path=/sys/class/power_supply/BAT0
      [[ -r "$battery_path/capacity" ]] || exit 0

      read_battery_value() {
        if [[ -r "$1" ]]; then
          tr -d '\n' < "$1"
        else
          printf '0'
        fi
      }

      umask 077
      history_dir="''${XDG_STATE_HOME:-''${HOME}/.local/state}/quickshell"
      history_file="$history_dir/battery-history.jsonl"
      mkdir -p "$history_dir"

      exec 9>"$history_file.lock"
      flock -x 9
      jq -cn \
        --argjson timestamp "$(date +%s)" \
        --argjson pct "$(read_battery_value "$battery_path/capacity")" \
        --arg status "$(read_battery_value "$battery_path/status")" \
        --argjson watts "$(read_battery_value "$battery_path/power_now")" \
        '{ timestamp: $timestamp, pct: $pct, status: $status, watts: ($watts / 1000000) }' \
        >> "$history_file"

      if (( $(wc -l < "$history_file") > 576 )); then
        history_next="$(mktemp --tmpdir="$history_dir" battery.XXXXXX)"
        tail -n 576 "$history_file" > "$history_next"
        mv "$history_next" "$history_file"
      fi
    '';
  };
  networkSpeedtest = pkgs.writeShellApplication {
    name = "network-speedtest";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.iproute2
      pkgs.jq
      pkgs.procps
    ];
    text = ''
      direction="''${1:-}"
      probe=1.1.1.1
      parallel=8

      if [[ "$direction" != "down" && "$direction" != "up" ]]; then
        echo "Usage: network-speedtest [down|up]" >&2
        exit 2
      fi

      iface="$(ip route get "$probe" 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')"
      if [[ -z "$iface" || ! -r "/sys/class/net/$iface/statistics/rx_bytes" || ! -r "/sys/class/net/$iface/statistics/tx_bytes" ]]; then
        echo "No active network interface" >&2
        exit 1
      fi

      fast_token="YXNkZmFzZGxmbnNkYWZoYXNkZmhrYWxm"
      fast_api_url="https://api.fast.com/netflix/speedtest/v2?https=true&token=$fast_token&urlCount=3"
      mapfile -t fast_urls < <(curl -fsS "$fast_api_url" | jq -r '.targets[]?.url // empty')
      if (( ''${#fast_urls[@]} == 0 )); then
        echo "Could not reach Fast.com" >&2
        exit 1
      fi

      traffic_pids=()
      cleanup() {
        for pid in "''${traffic_pids[@]}"; do
          pkill -TERM -P "$pid" 2>/dev/null || true
          kill "$pid" 2>/dev/null || true
        done
        wait 2>/dev/null || true
      }
      trap cleanup EXIT
      trap 'exit 0' INT TERM

      traffic_worker() {
        local worker_direction="$1"
        shift
        local urls=("$@")
        local url_count="''${#urls[@]}"
        local index="$RANDOM"
        local url

        while true; do
          url="''${urls[$((index % url_count))]}"
          if [[ "$worker_direction" == "down" ]]; then
            curl -fsS -o /dev/null "$url" || return
          else
            dd if=/dev/zero bs=1M count=64 2>/dev/null \
              | curl -fsS -o /dev/null -X POST --data-binary @- "$url" || return
          fi
          ((index += 1))
        done
      }

      for ((worker = 0; worker < parallel; worker++)); do
        traffic_worker "$direction" "''${fast_urls[@]}" &
        traffic_pids+=("$!")
      done

      rx_before="$(<"/sys/class/net/$iface/statistics/rx_bytes")"
      tx_before="$(<"/sys/class/net/$iface/statistics/tx_bytes")"

      while true; do
        sleep 1
        rx_after="$(<"/sys/class/net/$iface/statistics/rx_bytes")"
        tx_after="$(<"/sys/class/net/$iface/statistics/tx_bytes")"

        if [[ "$direction" == "down" ]]; then
          before="$rx_before"
          after="$rx_after"
        else
          before="$tx_before"
          after="$tx_after"
        fi

        awk -v before="$before" -v after="$after" 'BEGIN {
          rate = after >= before ? (after - before) * 8 / 1000000 : 0
          if (rate < 10) printf "%.1f\n", rate
          else printf "%.0f\n", rate
        }'
        rx_before="$rx_after"
        tx_before="$tx_after"
      done
    '';
  };
  voxtypeModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };
in
{
  home.packages = lib.mkIf isDesktop [
    batteryHistory
    networkSpeedtest
    voxtype
    voxtypeHistory
  ];

  xdg.configFile."voxtype/config.toml" = lib.mkIf isDesktop {
    text = ''
      # Omarchy-style local dictation: Hyprland owns the keys and Voxtype owns
      # recording, local Whisper transcription, and typing at the cursor.
      state_file = "auto"

      [hotkey]
      enabled = false

      [audio]
      device = "default"
      sample_rate = 16000
      max_duration_secs = 60
      pause_media = true

      [audio.feedback]
      enabled = true
      theme = "default"
      volume = 0.5

      [osd]
      enabled = true
      frontend = "quickshell"

      [whisper]
      model = "${voxtypeModel}"
      language = "en"
      translate = false

      [output]
      mode = "type"
      fallback_to_clipboard = true
      type_delay_ms = 1

      [output.post_process]
      command = "${voxtypeHistory}/bin/voxtype-history"
      timeout_ms = 2000

      [output.notification]
      on_recording_start = false
      on_recording_stop = false
      on_transcription = true
    '';
  };

  # Voxtype launches this as a separate Quickshell config so the recording
  # overlay stays isolated from (and cannot restart) the desktop shell.
  xdg.dataFile."voxtype/quickshell" = lib.mkIf isDesktop {
    source = ./voxtype-quickshell;
  };

  # Lemurs currently registers the graphical login without seat0. Disable
  # WirePlumber's seat gate so its BlueZ monitor still registers A2DP endpoints.
  xdg.configFile."wireplumber/wireplumber.conf.d/10-bluez-no-seat-gating.conf" =
    lib.mkIf isDesktop
      {
        text = ''
          wireplumber.profiles = {
            main = {
              monitor.bluez.seat-monitoring = disabled
            }
          }
        '';
      };

  systemd.user.services.voxtype = lib.mkIf isDesktop {
    Unit = {
      Description = "Voxtype local voice-to-text daemon";
      After = [
        "graphical-session.target"
        "pipewire.service"
        "pipewire-pulse.service"
      ];
      PartOf = [ "graphical-session.target" ];
      X-Restart-Triggers = [ "${./voxtype-quickshell}" ];
    };
    Service = {
      ExecStart = "${voxtype}/bin/voxtype -q daemon";
      Environment = [
        "VOXTYPE_AUDIO_BRIDGE_BINARY=${voxtype}/bin/voxtype-audio-bridge"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.quickshell.Service.Environment = lib.mkIf isDesktop [
    "NETWORK_SPEEDTEST_BINARY=${networkSpeedtest}/bin/network-speedtest"
  ];

  systemd.user.services.battery-history = lib.mkIf isDesktop {
    Unit = {
      Description = "Record a battery charge history sample";
      ConditionPathExists = "/sys/class/power_supply/BAT0/capacity";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${batteryHistory}/bin/battery-history-sample";
    };
  };

  systemd.user.timers.battery-history = lib.mkIf isDesktop {
    Unit.Description = "Sample battery charge history";
    Timer = {
      OnStartupSec = "10s";
      OnUnitActiveSec = "5min";
      Persistent = true;
      Unit = "battery-history.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  xdg.enable = true;

  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "x-scheme-handler/slack" = "slack.desktop";
    };
    defaultApplications = {
      "application/pdf" = "chromium-browser.desktop";
      "application/xhtml+xml" = "chromium-browser.desktop";
      "text/html" = "chromium-browser.desktop";
      "x-scheme-handler/http" = "chromium-browser.desktop";
      "x-scheme-handler/https" = "chromium-browser.desktop";
      "x-scheme-handler/slack" = "slack.desktop";
    };
  };
}
