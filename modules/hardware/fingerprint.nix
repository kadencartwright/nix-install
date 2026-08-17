{
  services.fprintd.enable = true;

  # Sudo and graphical authorization prompts accept either a fingerprint or
  # the account password. Keep Lemurs password-only: a fingerprint cannot
  # provide the password needed to decrypt the GNOME Login keyring.
  security.pam.services.sudo = {
    fprintAuth = true;
    unixAuth = true;
  };
  security.pam.services.polkit-1 = {
    fprintAuth = true;
    unixAuth = true;
  };

  # Hyprlock has its own parallel fprintd client when the fingerprint block in
  # hyprlock.conf is enabled. Its PAM conversation is only the password
  # fallback; enabling pam_fprintd here starts a second, conflicting scan.
  security.pam.services.hyprlock = {
    fprintAuth = false;
    unixAuth = true;
  };

  # Lemurs deliberately runs Wayland sessions without pam_loginuid (upstream
  # issue #166). Polkit consequently classifies the session incorrectly and
  # fprintd's default active-user-only verification rule rejects Hyprlock.
  # Limit the workaround to fingerprint verification and enrollment by this
  # workstation user.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "net.reactivated.fprint.device.verify" ||
           action.id == "net.reactivated.fprint.device.enroll") &&
          subject.user == "k") {
        return polkit.Result.YES;
      }
    });
  '';
}
