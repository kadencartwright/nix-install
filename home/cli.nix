{ inputs, pkgs, ... }:

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

  xdg.configFile."tm/config.toml".text = ''
    search_path = "/home/k/code"
  '';

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
