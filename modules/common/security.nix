{
  security.sudo.wheelNeedsPassword = true;

  # Emergency mitigation for the October 2026 eMudhra intermediate CA compromise.
  # Block the cross-signing root; this also distrusts legitimate chains under
  # it. emSign ECC Root CA - G3 is already absent from the pinned NSS store:
  # listing an absent root here makes buildcatrust fail.
  # Bundled application trust stores require separate updates.
  # https://emudhra.we-have-a-problem.com/
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
  ];

  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
}
