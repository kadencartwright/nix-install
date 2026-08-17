{ pkgs, pkgsUnstable, ... }:

let
  displayControl = pkgs.writeShellApplication {
    name = "display-control";
    runtimeInputs = [
      pkgs.brightnessctl
      pkgs.coreutils
      pkgs.ddcutil
      pkgs.gawk
      pkgs.jq
      pkgsUnstable.hyprland
    ];
    text = builtins.readFile ../../scripts/display-control.sh;
  };
  ocrScreenshot = pkgs.writeShellApplication {
    name = "ocr-screenshot";
    runtimeInputs = [
      pkgs.grim
      pkgs.libnotify
      pkgs.slurp
      pkgs.tesseract
      pkgs.wl-clipboard
      pkgsUnstable.hyprpicker
    ];
    text = ''
      picker_pid=""
      cleanup() {
        if [[ -n "$picker_pid" ]]; then
          kill "$picker_pid" 2>/dev/null || true
        fi
      }
      trap cleanup EXIT

      # Freeze the desktop while slurp is selecting a region. Keep the picker
      # alive until grim has captured so moving content cannot shift under it.
      hyprpicker -r -z >/dev/null 2>&1 &
      picker_pid=$!
      sleep 0.1
      selection=$(slurp 2>/dev/null || true)
      [[ -n "$selection" ]] || exit 0

      text=$(grim -g "$selection" - | tesseract stdin stdout \
        --oem 1 --psm 6 -l "''${OCR_SCREENSHOT_LANGS:-eng}" --dpi 300 \
        -c preserve_interword_spaces=1 2>/dev/null) || exit 1
      [[ -n "$text" ]] || exit 1

      printf '%s' "$text" | wl-copy
      notify-send -i edit-copy "Screenshot text copied" \
        "Paste it with your normal clipboard shortcut."
    '';
  };
in
{
  programs.hyprland = {
    enable = true;
    package = pkgsUnstable.hyprland;
    portalPackage = pkgsUnstable.xdg-desktop-portal-hyprland;
  };

  programs.chromium = {
    enable = true;
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden Password Manager
    ];
  };

  environment.systemPackages =
    (with pkgs; [
      alacritty
      bemoji
      bitwarden-desktop
      brightnessctl
      chromium
      displayControl
      fuzzel
      gnome-keyring
      grim
      libnotify
      networkmanagerapplet
      nwg-displays
      nwg-look
      ocrScreenshot
      pavucontrol
      playerctl
      pulsemixer
      qpwgraph
      slurp
      spotify
      swaynotificationcenter
      thunar
      waybar
      quickshell
      wl-clipboard
      wl-screenrec
      xdg-utils
    ])
    ++ (with pkgsUnstable; [
      hypridle
      hyprlock
      hyprpaper
      hyprpolkitagent
      hyprpicker
      hyprshot
    ]);

  services.gnome.gnome-keyring.enable = true;
  hardware.i2c.enable = true;
  services.udev.packages = [ pkgs.brightnessctl ];
  services.gvfs.enable = true;
  services.tumbler.enable = true;
}
