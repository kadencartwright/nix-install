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
  chatgptVersion = "26.911.61220";
  codex = pkgsUnstable.callPackage ../packages/codex.nix { };
  herdr = pkgs.callPackage ../packages/herdr.nix { };
  tm = pkgs.callPackage ../packages/tm.nix {
    tm-src = inputs.tm;
  };
  openaiChatgptDesktop =
    inputs.openai-chatgpt-desktop-nix.packages.${platformSystem}.default.overrideAttrs (_: {
      version = chatgptVersion;
      src = pkgs.fetchurl {
        url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${chatgptVersion}_amd64.deb";
        hash = "sha256-FOHUru1/7SKtvSuOwg/le/vdnumQI3C04nJmd8pou7o=";
      };
    });
  opencode = pkgsUnstable.callPackage ../packages/opencode.nix { };
  opencodeDesktop = pkgsUnstable.callPackage ../packages/opencode-desktop.nix { };
  portmux = inputs.portmux.packages.${platformSystem}.default;
  t3 = pkgsUnstable.callPackage ../packages/t3-cli { inherit codex; };
  t3code = pkgsUnstable.callPackage ../packages/t3code.nix { inherit codex; };
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
    pass
    ripgrep
    tmux
    zoxide
  ] ++ (with pkgsUnstable; [
    pi-coding-agent
  ])
  ++ [ codex ]
  ++ [ herdr ]
  ++ [ opencode ]
  ++ [ portmux ]
  ++ lib.optional isDesktop opencodeDesktop
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
