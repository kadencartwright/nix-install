# Secrets

This config is wired for `sops-nix`, but no real secrets should be committed here.

Expected first setup:

1. Generate or place the age key at `/var/lib/sops-nix/key.txt` on the installed machine.
2. Create an encrypted `secrets.yaml` with `sops`.
3. Add concrete `sops.secrets.<name>` declarations in `secrets.nix` or the module that consumes each secret.

Do not put plaintext passwords, API tokens, Wi-Fi keys, SSH private keys, or recovery material in `.nix` files. Nix expressions and many generated store paths are world-readable to local users.
