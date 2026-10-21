{
  security.sudo.wheelNeedsPassword = true;

  # Emergency mitigation for the October 2026 eMudhra intermediate CA compromise.
  # Include the cross-signing root; this also distrusts legitimate chains under
  # these roots. Bundled application trust stores require separate updates.
  # https://emudhra.we-have-a-problem.com/
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
  ];

  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
}
