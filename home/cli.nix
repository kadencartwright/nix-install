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
  chatgptVersion = "26.1002.52244";
  codex = pkgsUnstable.callPackage ../packages/codex.nix { };
  herdr = pkgs.callPackage ../packages/herdr.nix { };
  tm = pkgs.callPackage ../packages/tm.nix {
    tm-src = inputs.tm;
  };
  openaiChatgptDesktop =
    inputs.openai-chatgpt-desktop-nix.packages.${platformSystem}.default.overrideAttrs
      (oldAttrs: {
        version = chatgptVersion;
        src = pkgs.fetchurl {
          url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${chatgptVersion}_amd64.deb";
          hash = "sha256-lJjkFxMaJ4vONb//YnXSUsDTMvF6/AMT4LeCdJ9NNIo=";
        };
        # Tectonic moved out of the LaTeX plugin in the September 24 package.
        installPhase =
          builtins.replaceStrings
            [ "resources/plugins/openai-bundled/plugins/latex/bin/tectonic" ]
            [ "resources/tectonic/tectonic" ]
            oldAttrs.installPhase;
      });
  opencode = pkgsUnstable.callPackage ../packages/opencode.nix { };
  opencodeDesktop = pkgsUnstable.callPackage ../packages/opencode-desktop.nix { };
  pi = inputs.pi.packages.${platformSystem}.default;
  portmux = inputs.portmux.packages.${platformSystem}.default;
  t3 = pkgsUnstable.callPackage ../packages/t3-cli { inherit codex; };
  t3code = pkgsUnstable.callPackage ../packages/t3code.nix { inherit codex; };
in

{
  home.packages = with pkgs; [
    awscli2
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
  ] ++ [ pi ]
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

  # Keep Voxtype's Wayland virtual-keyboard paste events native; XWayland
  # clients can misinterpret wtype's temporary keymap.
  xdg.configFile."chatgpt-flags.conf" = lib.mkIf (isDesktop && pkgs.stdenv.hostPlatform.isx86_64) {
    text = ''
      --ozone-platform=wayland
    '';
  };

  xdg.configFile."tm/config.toml".source = "${inputs.dotfiles}/tm/config.toml";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
