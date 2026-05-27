{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  tm = pkgs.callPackage ../packages/tm.nix {
    tm-src = inputs.tm;
  };
in

{
  home.packages = with pkgs; [
    bat
    btop
    atuin
    eza
    fd
    fnm
    fzf
    gh
    jq
    lazygit
    nodejs
    opencode
    ripgrep
    tmux
    zoxide
  ] ++ [
    tm
  ];

  home.sessionPath = [
    "$HOME/.local/share/npm/bin"
  ];

  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "$HOME/.local/share/npm";
  };

  home.activation.installCodex = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "$HOME/.local/share/npm"
    $DRY_RUN_CMD ${pkgs.nodejs}/bin/npm install -g @openai/codex@latest --prefix "$HOME/.local/share/npm"
  '';

  xdg.configFile."tm/config.toml".text = ''
    search_path = "/home/k/code"
  '';

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
