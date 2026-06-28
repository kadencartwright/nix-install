{
  inputs,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  platformSystem = pkgs.stdenv.hostPlatform.system;
  tm = pkgs.callPackage ../packages/tm.nix {
    tm-src = inputs.tm;
  };
  openaiCodexDesktop = inputs.openai-codex-desktop-nix.packages.${platformSystem}.default;
  t3Packages = inputs.t3code-nix.packages.${platformSystem} or { };
in

{
  home.packages = with pkgs; [
    bat
    bubblewrap
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
    ripgrep
    tmux
    zoxide
  ] ++ (with pkgsUnstable; [
    codex
    opencode
  ])
  ++ lib.optional (t3Packages ? t3) t3Packages.t3
  ++ lib.optional (pkgs.stdenv.hostPlatform.isx86_64 && t3Packages ? t3code) t3Packages.t3code
  ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 openaiCodexDesktop
  ++ [
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
