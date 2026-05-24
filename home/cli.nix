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
    codex
    eza
    fd
    fnm
    fzf
    gh
    jq
    lazygit
    opencode
    ripgrep
    tmux
    zoxide
  ] ++ [
    tm
  ];

  xdg.configFile."tm/config.toml".text = ''
    search_path = "/home/k/code"
  '';

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
