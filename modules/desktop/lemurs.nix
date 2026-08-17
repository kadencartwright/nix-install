{ config, lib, pkgs, ... }:

let
  # Expose one stable session name to Lemurs so its remembered "Hyprland"
  # selection always uses UWSM. UWSM owns the graphical-session target that
  # starts desktop user services such as Quickshell and Voxtype.
  hyprlandSession = pkgs.writeTextDir "share/wayland-sessions/hyprland.desktop" ''
    [Desktop Entry]
    Name=Hyprland
    Comment=Hyprland compositor managed by UWSM
    Exec=${lib.getExe config.programs.uwsm.package} start -e -D Hyprland hyprland.desktop
    TryExec=${lib.getExe config.programs.uwsm.package}
    DesktopNames=Hyprland
    Type=Application
  '';
in
{
  # Lemurs starts Wayland sessions through seatd. The NixOS module disables
  # pam_loginuid because of an upstream Lemurs issue, so logind does not attach
  # the session to seat0 and cannot grant its usual audio/video device ACLs.
  users.users.k.extraGroups = [
    "audio"
    "seat"
    "video"
  ];

  # UDisks normally grants these operations to the active local seat. Lemurs
  # cannot set pam_loginuid (upstream issue #166), so Polkit sees this session
  # without seat0 and falls back to an administrator prompt. Recreate only the
  # normal removable-storage permission for the workstation user; deliberately
  # exclude system disks and filesystems mounted by another user.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var userStorageActions = {
        "org.freedesktop.udisks2.filesystem-mount": true,
        "org.freedesktop.udisks2.filesystem-mount-other-seat": true,
        "org.freedesktop.udisks2.encrypted-unlock": true,
        "org.freedesktop.udisks2.encrypted-unlock-other-seat": true,
        "org.freedesktop.udisks2.eject-media": true,
        "org.freedesktop.udisks2.eject-media-other-seat": true,
        "org.freedesktop.udisks2.power-off-drive": true,
        "org.freedesktop.udisks2.power-off-drive-other-seat": true
      };

      if (subject.user == "k" && userStorageActions[action.id]) {
        return polkit.Result.YES;
      }
    });
  '';

  # Lemurs authenticates the graphical session through its own PAM service.
  # pam_gnome_keyring receives the same password and unlocks (or creates) the
  # login keyring before Hyprland and Electron applications start.
  services.displayManager.lemurs = {
    enable = true;
    settings = {
      do_log = true;
      focus_behaviour = "default";

      background = {
        show_background = true;
        style = {
          color = "#282c34";
          show_border = false;
          border_color = "#61afef";
        };
      };

      environment_switcher = {
        remember = true;
        mover_color_focused = "#61afef";
        neighbour_color_focused = "#abb2bf";
        selected_color = "#abb2bf";
        selected_color_focused = "#98c379";
      };

      wayland.wayland_sessions_path = "${hyprlandSession}/share/wayland-sessions";

      username_field = {
        remember = true;
        style = {
          title_color = "#abb2bf";
          content_color = "#abb2bf";
          title_color_focused = "#98c379";
          content_color_focused = "#98c379";
          border_color = "#5c6370";
          border_color_focused = "#61afef";
        };
      };

      password_field.style = {
        title_color = "#abb2bf";
        content_color = "#abb2bf";
        title_color_focused = "#98c379";
        content_color_focused = "#98c379";
        border_color = "#5c6370";
        border_color_focused = "#61afef";
      };
    };
  };

  # Keep this explicit even though the NixOS Lemurs module defaults it to the
  # GNOME Keyring service state. This is the contract that makes the login
  # password unlock the user's login keyring.
  security.pam.services = {
    lemurs = {
      enableGnomeKeyring = true;

      # A fingerprint proves identity but cannot provide the password needed
      # to decrypt the login keyring. Keep fingerprint support for locks and
      # sudo, but require a password for the initial graphical login.
      fprintAuth = false;
    };

    # When the user runs `passwd`, give pam_gnome_keyring both the old and new
    # passwords so the login keyring password remains synchronized.
    passwd = {
      enableGnomeKeyring = true;
      fprintAuth = false;

      # WARNING: PAM `rules` is an experimental NixOS option and may require
      # adjustment after a nixpkgs upgrade. The generated default marks
      # pam_unix as `sufficient`, which returns before pam_gnome_keyring can
      # re-encrypt the login keyring with the new password. `required` keeps
      # the same authentication result while allowing the next hook to run.
      rules.password.unix.control = lib.mkForce "required";
    };
  };

  programs.seahorse.enable = true;
  environment.systemPackages = [ pkgs.libsecret ];

  systemd.services.display-manager = {
    after = [ "home-manager-k.service" ];
    wants = [ "home-manager-k.service" ];
  };
}
