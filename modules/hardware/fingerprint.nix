{
  services.fprintd.enable = true;

  # Hyprlock's fingerprint UI still authenticates through PAM. Defining a
  # dedicated service keeps fingerprint unlock separate from Lemurs, whose
  # password is required to decrypt the GNOME Login keyring.
  security.pam.services.hyprlock = {
    fprintAuth = true;
    unixAuth = true;
  };
}
