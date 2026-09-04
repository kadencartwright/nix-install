{
  isDesktop ? false,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  displayControl = import ../packages/display-control.nix { inherit pkgs pkgsUnstable; };
  lyre = pkgs.buildNpmPackage {
    pname = "lyre-tui";
    version = "1.3.5";
    src = pkgs.fetchFromGitHub {
      owner = "DeadZone-0";
      repo = "lyre";
      rev = "bd8f407dc4101a082ef137cf77ff9f565f099161";
      hash = "sha256-TjhiGImVrlHxlG5FBdJS6c2Oj+KTcRXG28fUahEhYIw=";
    };
    npmDepsHash = "sha256-PxfF0Z7pldeNsXozpBYCPoqF7rw38EkVidEGOtzFam4=";

    postPatch = ''
      substituteInPlace src/components/App.tsx \
        --replace-fail "albumArt: { enabled: true" "albumArt: { enabled: false"
    '';

  };
  lyreLauncher = pkgs.writeShellApplication {
    name = "lyre-launch";
    runtimeInputs = [
      pkgs.alacritty
      pkgs.cava
      pkgs.coreutils
      pkgs.jq
      pkgs.mpv
      pkgs.playerctl
      pkgsUnstable.hyprland
      lyre
    ];
    text = ''
      config_dir="''${XDG_CONFIG_HOME:-''${HOME}/.config}/lyre"
      mkdir -p "$config_dir"
      if [[ ! -e "$config_dir/lyre.json" ]]; then
        printf '%s\n' '{ "player": "spotify" }' > "$config_dir/lyre.json"
      fi

      if ${pkgsUnstable.hyprland}/bin/hyprctl clients -j | ${pkgs.jq}/bin/jq -e '
        any(.[]; ((.class // "") | ascii_downcase) == "lyre")
      ' >/dev/null; then
        exec ${pkgsUnstable.hyprland}/bin/hyprctl dispatch \
          'hl.dsp.focus({ window = hl.get_windows({ class = "Lyre" })[1] })'
      fi

      exec ${pkgs.alacritty}/bin/alacritty --class Lyre --title "Lyre Visualizer" -e ${lyre}/bin/lyre
    '';
  };
  trayWindowToggle = pkgs.writeShellApplication {
    name = "tray-window-toggle";
    runtimeInputs = [
      pkgs.jq
      pkgs.systemd
      pkgsUnstable.hyprland
    ];
    text = ''
      query="''${1:-}"
      query="''${query,,}"
      query="''${query//-/_}"
      [[ -n "$query" ]] || { echo "A tray application id is required" >&2; exit 2; }

      item="$(
        busctl --user --json=short get-property \
          org.kde.StatusNotifierWatcher \
          /StatusNotifierWatcher \
          org.kde.StatusNotifierWatcher \
          RegisteredStatusNotifierItems \
          | jq -r --arg query "$query" '
              [ .data[] | select(ascii_downcase | contains($query)) ]
              | first // empty
            '
      )"
      [[ -n "$item" ]] || { echo "No tray item found for $query" >&2; exit 1; }

      service="''${item%%/*}"
      object="/''${item#*/}"
      menu="$(
        busctl --user --json=short get-property \
          "$service" "$object" org.kde.StatusNotifierItem Menu \
          | jq -r .data
      )"

      # Spotify intentionally omits StatusNotifierItem.Activate. Its DBus menu
      # exposes mutually exclusive native actions instead, so left click uses
      # whichever of Show Spotify / Minimize to Tray is currently visible.
      busctl --user call -- "$service" "$menu" \
        com.canonical.dbusmenu AboutToShow i 0 >/dev/null || true

      window_query="''${query%_client}"
      window_query="''${window_query//_/ }"
      if hyprctl clients -j | jq -e --arg query "$window_query" '
        any(.[];
          [(.class // ""), (.initialClass // ""), (.title // "")]
          | map(ascii_downcase)
          | any(contains($query))
        )
      ' >/dev/null; then
        target_label="Minimize to Tray"
      else
        target_label="Show Spotify"
      fi

      for action in {1..32}; do
        label="$(
          busctl --user --json=short call -- "$service" "$menu" \
            com.canonical.dbusmenu GetProperty is "$action" label 2>/dev/null \
            | jq -r '.data[0].data // empty'
        )"
        [[ "$label" == "$target_label" ]] || continue

        busctl --user call -- "$service" "$menu" \
          com.canonical.dbusmenu Event isvu "$action" clicked i 0 0
        exit 0
      done

      echo "No $target_label action found for $query" >&2
      exit 1
    '';
  };
  voxtype = pkgsUnstable.voxtype.override {
    # Keep Whisper/Vulkan available as a fallback while using Parakeet through
    # ONNX Runtime for the active transcription engine.
    vulkanSupport = true;
    onnxSupport = true;
  };
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
  networkPanelHelper = pkgs.writeShellApplication {
    name = "network-panel-helper";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnused
      pkgs.iproute2
      pkgs.iputils
      pkgs.iw
      pkgs.jq
      pkgs.networkmanager
      pkgs.qrencode
    ];
    text = ''
      export LC_ALL=C
      probe=1.1.1.1

      band_for_freq() {
        local mhz="''${1%%[!0-9]*}"
        if [[ -z "$mhz" ]]; then
          return
        elif (( mhz >= 2400 && mhz < 2500 )); then
          printf '2.4'
        elif (( mhz >= 4900 && mhz < 5925 )); then
          printf '5'
        elif (( mhz >= 5925 && mhz < 7125 )); then
          printf '6'
        fi
      }

      active_connection() {
        route_json="$(ip -j route get "$probe" 2>/dev/null || true)"
        iface="$(jq -r '.[0].dev // ""' <<< "$route_json")"
        gateway="$(jq -r '.[0].gateway // ""' <<< "$route_json")"
        ip_address="$(jq -r '.[0].prefsrc // ""' <<< "$route_json")"
        if [[ -z "$iface" ]]; then
          return 1
        fi
        connection_uuid="$(nmcli -g GENERAL.CON-UUID device show "$iface" 2>/dev/null || true)"
        connection_name="$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)"
      }

      provider_for_dns() {
        local ignored="$1"
        local servers="$2"
        if [[ "$ignored" != "yes" || -z "''${servers//[[:space:]]/}" ]]; then
          printf 'DHCP'
        elif [[ "$servers" == *"1.1.1.1"* ]]; then
          printf 'Cloudflare'
        elif [[ "$servers" == *"8.8.8.8"* ]]; then
          printf 'Google'
        else
          printf 'Custom'
        fi
      }

      available_bands() {
        local device="$1"
        local wanted_ssid="$2"
        local current="$3"
        {
          [[ -n "$current" ]] && printf '%s\n' "$current"
          nmcli -e no -g FREQ,SSID device wifi list ifname "$device" --rescan no 2>/dev/null \
            | want="$wanted_ssid" awk -F: '
                BEGIN { want = ENVIRON["want"] }
                {
                  name = $2
                  for (i = 3; i <= NF; i++) name = name ":" $i
                  if (name == want) print $1
                }' \
            | while read -r frequency; do band_for_freq "$frequency"; printf '\n'; done
        } | sed '/^$/d' | sort -u -g | tr '\n' ' ' | sed 's/ $//'
      }

      status() {
        if ! active_connection; then
          jq -cn '{ connected: false }'
          return
        fi

        prefix="$(ip -j addr show "$iface" 2>/dev/null | jq -r '.[0].addr_info[]? | select(.family == "inet") | .prefixlen // ""' | head -n 1)"
        rx_bytes="$(<"/sys/class/net/$iface/statistics/rx_bytes")"
        tx_bytes="$(<"/sys/class/net/$iface/statistics/tx_bytes")"
        ping_ms="$(ping -n -c 1 -W 1 "$probe" 2>/dev/null | awk -F'time[=<]' '/time[=<]/ { split($2, p, " "); print p[1]; exit }' || true)"
        dns_servers="$(nmcli -g IP4.DNS device show "$iface" 2>/dev/null | tr '|' ' ' | xargs)"
        ignored_dns="$(nmcli -g ipv4.ignore-auto-dns connection show "$connection_uuid" 2>/dev/null || true)"
        configured_dns="$(nmcli -g ipv4.dns connection show "$connection_uuid" 2>/dev/null | paste -sd' ' -)"
        dns_provider="$(provider_for_dns "$ignored_dns" "$configured_dns")"

        kind=ethernet
        ssid=""
        frequency=""
        signal_dbm=""
        bitrate=""
        current_band=""
        selected_band=auto
        bands=""
        link_speed=""

        if [[ -d "/sys/class/net/$iface/wireless" ]]; then
          kind=wifi
          link="$(iw dev "$iface" link 2>/dev/null || true)"
          ssid="$(awk '/SSID:/ { sub(/.*SSID: /, ""); print; exit }' <<< "$link")"
          frequency="$(awk '/freq:/ { print $2; exit }' <<< "$link")"
          signal_dbm="$(awk '/signal:/ { print $2; exit }' <<< "$link")"
          bitrate="$(awk '/tx bitrate:/ { print $3 " " $4; exit }' <<< "$link")"
          current_band="$(band_for_freq "$frequency")"
          nm_band="$(nmcli -g 802-11-wireless.band connection show "$connection_uuid" 2>/dev/null || true)"
          case "$nm_band" in
            bg) selected_band=2.4 ;;
            a) selected_band=5 ;;
            6GHz) selected_band=6 ;;
          esac
          bands="$(available_bands "$iface" "$ssid" "$current_band")"
        elif [[ -r "/sys/class/net/$iface/speed" ]]; then
          link_speed="$(<"/sys/class/net/$iface/speed")"
        fi

        jq -cn \
          --arg iface "$iface" \
          --arg kind "$kind" \
          --arg connection "$connection_name" \
          --arg uuid "$connection_uuid" \
          --arg ip "$ip_address" \
          --arg prefix "$prefix" \
          --arg gateway "$gateway" \
          --arg ssid "$ssid" \
          --arg frequency "$frequency" \
          --arg signalDbm "$signal_dbm" \
          --arg bitrate "$bitrate" \
          --arg linkSpeed "$link_speed" \
          --arg dnsProvider "$dns_provider" \
          --arg dnsServers "$dns_servers" \
          --arg currentBand "$current_band" \
          --arg selectedBand "$selected_band" \
          --arg availableBands "$bands" \
          --argjson rxBytes "$rx_bytes" \
          --argjson txBytes "$tx_bytes" \
          --argjson pingMs "''${ping_ms:--1}" \
          '{
            connected: true,
            iface: $iface,
            kind: $kind,
            connection: $connection,
            uuid: $uuid,
            ip: $ip,
            prefix: $prefix,
            gateway: $gateway,
            ssid: $ssid,
            frequency: $frequency,
            signalDbm: $signalDbm,
            bitrate: $bitrate,
            linkSpeed: $linkSpeed,
            dnsProvider: $dnsProvider,
            dnsServers: $dnsServers,
            currentBand: $currentBand,
            selectedBand: $selectedBand,
            availableBands: ($availableBands | split(" ") | map(select(length > 0))),
            rxBytes: $rxBytes,
            txBytes: $txBytes,
            pingMs: $pingMs
          }'
      }

      set_dns() {
        local provider="''${1:-}"
        local custom="''${2:-}"
        active_connection || { echo "No active connection" >&2; exit 1; }

        case "$provider" in
          DHCP)
            ipv4_dns=""
            ipv6_dns=""
            ignore=no
            ;;
          Cloudflare)
            ipv4_dns="1.1.1.1 1.0.0.1"
            ipv6_dns="2606:4700:4700::1111 2606:4700:4700::1001"
            ignore=yes
            ;;
          Google)
            ipv4_dns="8.8.8.8 8.8.4.4"
            ipv6_dns="2001:4860:4860::8888 2001:4860:4860::8844"
            ignore=yes
            ;;
          Custom)
            custom="$(printf '%s' "$custom" | tr ',\t\n' ' ' | xargs)"
            [[ -n "$custom" ]] || { echo "Enter at least one DNS server" >&2; exit 1; }
            ipv4_dns=""
            ipv6_dns=""
            for server in $custom; do
              if [[ "$server" == *:* ]]; then
                ipv6_dns+="''${ipv6_dns:+ }$server"
              else
                ipv4_dns+="''${ipv4_dns:+ }$server"
              fi
            done
            ignore=yes
            ;;
          *)
            echo "Unknown DNS provider" >&2
            exit 2
            ;;
        esac

        nmcli connection modify "$connection_uuid" \
          ipv4.ignore-auto-dns "$ignore" ipv4.dns "$ipv4_dns" \
          ipv6.ignore-auto-dns "$ignore" ipv6.dns "$ipv6_dns"
        nmcli device reapply "$iface" >/dev/null 2>&1 \
          || nmcli connection up "$connection_uuid" >/dev/null
      }

      set_band() {
        local target="''${1:-auto}"
        active_connection || { echo "No active connection" >&2; exit 1; }
        [[ -d "/sys/class/net/$iface/wireless" ]] || { echo "Wi-Fi is not active" >&2; exit 1; }

        case "$target" in
          auto) desired="" ;;
          2.4) desired="bg" ;;
          5) desired="a" ;;
          6) desired="6GHz" ;;
          *) echo "Unknown Wi-Fi band" >&2; exit 2 ;;
        esac

        previous="$(nmcli -g 802-11-wireless.band connection show "$connection_uuid" 2>/dev/null || true)"
        [[ "$previous" == "$desired" ]] && return
        nmcli connection modify "$connection_uuid" 802-11-wireless.band "$desired"
        if ! nmcli connection up "$connection_uuid" >/dev/null 2>&1; then
          nmcli connection modify "$connection_uuid" 802-11-wireless.band "$previous"
          nmcli connection up "$connection_uuid" >/dev/null 2>&1 || true
          echo "Could not reconnect on that band; restored the previous setting" >&2
          exit 1
        fi
      }

      wifi_qr() {
        active_connection || { echo "No active connection" >&2; exit 1; }
        [[ -d "/sys/class/net/$iface/wireless" ]] || { echo "Wi-Fi is not active" >&2; exit 1; }
        ssid="$(nmcli -g 802-11-wireless.ssid connection show "$connection_uuid" 2>/dev/null || true)"
        key_mgmt="$(nmcli -g 802-11-wireless-security.key-mgmt connection show "$connection_uuid" 2>/dev/null || true)"
        password="$(nmcli --show-secrets -g 802-11-wireless-security.psk connection show "$connection_uuid" 2>/dev/null || true)"
        [[ -n "$ssid" ]] || { echo "Could not read the Wi-Fi name" >&2; exit 1; }

        escape_wifi() { printf '%s' "$1" | sed 's/[\\;,:]/\\&/g'; }
        escaped_ssid="$(escape_wifi "$ssid")"
        escaped_password="$(escape_wifi "$password")"
        security=WPA
        if [[ -z "$key_mgmt" || "$key_mgmt" == "none" ]]; then security=nopass; fi
        printf 'WIFI:T:%s;S:%s;P:%s;;' "$security" "$escaped_ssid" "$escaped_password" \
          | qrencode -t SVG -m 2 -o -
      }

      action="''${1:-status}"
      shift || true
      case "$action" in
        status) status ;;
        dns) set_dns "$@" ;;
        band) set_band "$@" ;;
        qr) wifi_qr ;;
        *) echo "Usage: network-panel-helper [status|dns|band|qr]" >&2; exit 2 ;;
      esac
    '';
  };
  parakeetModelRevision = "8f23f0c03c8761650bdb5b40aaf3e40d2c15f1ce";
  fetchParakeetModelFile =
    name: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx/resolve/${parakeetModelRevision}/${name}";
      inherit hash;
    };
  parakeetModel = pkgs.linkFarm "parakeet-tdt-0.6b-v3-onnx" [
    {
      name = "encoder-model.onnx";
      path = fetchParakeetModelFile "encoder-model.onnx" "sha256-mKdLIbTMABfB5wMDGaSpb0qVBuUPBwjzpRbQKnfJa7E=";
    }
    {
      name = "encoder-model.onnx.data";
      path = fetchParakeetModelFile "encoder-model.onnx.data" "sha256-miLTcsUUVcNPE0BdolILrvtxJb0WmBOXVhQj7TLSTzY=";
    }
    {
      name = "decoder_joint-model.onnx";
      path = fetchParakeetModelFile "decoder_joint-model.onnx" "sha256-6Xjd9miFJxgsEP3i60uDBoQhZImF7yP3qGvnMr6HBsE=";
    }
    {
      name = "vocab.txt";
      path = fetchParakeetModelFile "vocab.txt" "sha256-1YVEZ56kvGrFY9H1Ret9R0vWz6Rn8KbiwdwcfTfjw10=";
    }
    {
      name = "config.json";
      path = fetchParakeetModelFile "config.json" "sha256-ZmkDx2uXmMrywhCv1PbNYLCKjb+YAOyNejvA0hSKxGY=";
    }
  ];
in
{
  home.packages = lib.mkIf isDesktop [
    batteryHistory
    lyreLauncher
    displayControl
    networkPanelHelper
    networkSpeedtest
    trayWindowToggle
    voxtype
    voxtypeHistory
  ];

  xdg.configFile."obsbot-cli/config.toml" = lib.mkIf isDesktop {
    text = ''
      # Keep tracking disabled across both live applies and camera power cycles.
      # Disabling gesture auto-frame prevents a hand gesture from re-enabling it.
      wake = true

      [state]
      ai_mode = "off"
      boot_ai_mode = "off"
      gesture_auto_frame = false
      fov = "wide" # 86 degrees
    '';
  };

  xdg.configFile."voxtype/config.toml" = lib.mkIf isDesktop {
    text = ''
      # Omarchy-style local dictation: Hyprland owns the keys and Voxtype owns
      # recording, local Parakeet transcription, and typing at the cursor.
      state_file = "auto"
      engine = "parakeet"

      [hotkey]
      enabled = false

      [audio]
      device = "default"
      sample_rate = 16000
      # Allow extended brain dumps while retaining a safety cap.
      max_duration_secs = 900
      pause_media = true

      [audio.feedback]
      enabled = true
      theme = "default"
      volume = 0.5

      [osd]
      enabled = true
      frontend = "quickshell"

      [parakeet]
      model = "${parakeetModel}"
      model_type = "tdt"
      on_demand_loading = false
      streaming = false

      [output]
      # Clipboard paste avoids wtype's per-character keycode corruption in
      # Chromium/Electron text fields such as the ChatGPT desktop composer.
      mode = "paste"
      # Codex reserves Ctrl+V for image attachments; Shift+Insert remains a
      # normal text paste in terminals and Chromium/Electron applications.
      paste_keys = "shift+insert"
      restore_clipboard = true
      restore_clipboard_delay_ms = 300

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
    "DISPLAY_CONTROL_BINARY=${displayControl}/bin/display-control"
    "NETWORK_PANEL_HELPER_BINARY=${networkPanelHelper}/bin/network-panel-helper"
    "NETWORK_SPEEDTEST_BINARY=${networkSpeedtest}/bin/network-speedtest"
    "TRAY_WINDOW_TOGGLE_BINARY=${trayWindowToggle}/bin/tray-window-toggle"
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
