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
  chatgptVersion = "26.1027.51404";
  codex = pkgsUnstable.callPackage ../packages/codex.nix { };
  # Pin the release manifest while retaining nixpkgs' native binary packaging.
  claudeCode = pkgsUnstable.claude-code.override {
    manifest = {
      version = "2.1.316";
      platforms = {
        linux-x64 = {
          binary = "claude.zst";
          checksum = "4108764100675c0773d98011d5091f427f30eebfc567aa9f1b5f4d9a54630a10";
        };
        linux-arm64 = {
          binary = "claude.zst";
          checksum = "d4ed34a7ecd889497fccc0951c869867b2369196804e3d83b8e486d424b973e1";
        };
      };
    };
  };
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
          hash = "sha256-RvHiLQKGmP6e2u/VhHrs4HxFCaMNNwnhBCIHGdjBKCI=";
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
  ++ [ claudeCode ]
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
