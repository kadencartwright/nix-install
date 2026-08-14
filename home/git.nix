{
  # Use the standard OpenSSH agent and normal private keys. The Hyprland
  # dotfile's Bitwarden SSH_AUTH_SOCK override is removed in dotfiles.nix.
  services.ssh-agent.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Kaden Cartwright";
        email = "kaden@example.com";
      };
      init.defaultBranch = "main";
      pull.ff = "only";
      push.autoSetupRemote = true;
    };
  };
}
