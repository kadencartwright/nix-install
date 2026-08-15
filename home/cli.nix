{
  inputs,
  lib,
  pkgs,
  pkgsUnstable,
  isDesktop ? false,
  ...
}:

let
  platformSystem = pkgs.stdenv.hostPlatform.system;
  tm = pkgs.callPackage ../packages/tm.nix {
    tm-src = inputs.tm;
  };
  openaiChatgptDesktop = inputs.openai-chatgpt-desktop-nix.packages.${platformSystem}.default;
  t3 = pkgsUnstable.callPackage ../packages/t3-cli { };
  t3code = pkgsUnstable.callPackage ../packages/t3code.nix { };
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
    herdr
    opencode
    pi-coding-agent
  ])
  ++ lib.optional isDesktop pkgsUnstable.opencode-desktop
  ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    t3
    t3code
  ]
  ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 openaiChatgptDesktop
  ++ [
    tm
  ];

  xdg.configFile."tm/config.toml".source = "${inputs.dotfiles}/tm/config.toml";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
