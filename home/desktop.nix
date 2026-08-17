{
  isDesktop ? false,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  voxtype = pkgsUnstable.voxtype.override { vulkanSupport = true; };
  voxtypeModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };
in
{
  home.packages = lib.mkIf isDesktop [ voxtype ];

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

      [whisper]
      model = "${voxtypeModel}"
      language = "en"
      translate = false

      [output]
      mode = "type"
      fallback_to_clipboard = true
      type_delay_ms = 1

      [output.notification]
      on_recording_start = false
      on_recording_stop = false
      on_transcription = true
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
    };
    Service = {
      ExecStart = "${voxtype}/bin/voxtype -q daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
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
