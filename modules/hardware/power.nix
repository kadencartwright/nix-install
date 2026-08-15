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
