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
  chatgptVersion = "26.1117.41037";
  codex = pkgsUnstable.callPackage ../packages/codex.nix { };
  # Pin the release manifest while retaining nixpkgs' native binary packaging.
  claudeCode = pkgsUnstable.claude-code.override {
    manifest = {
      version = "2.1.330";
      platforms = {
        linux-x64 = {
          binary = "claude.zst";
          checksum = "d53a3f9aab93c87bba0813d1101677677b457100824f5c3604fea9915ac5237a";
        };
        linux-arm64 = {
          binary = "claude.zst";
          checksum = "fd32a5b1552693c801e6f6cb3dc77e39c2438a873d00600558bae8bdc06b20bd";
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
          hash = "sha256-gw4lG2ykrUX+aQQSenkOjwD3wm7UyAOUc/cyPHxOJpI=";
        };
        # New releases omit the bundled Tectonic binary (and its bin directory).
        # Keep the upstream replacement symlink at the path the plugin probes.
        installPhase =
          builtins.replaceStrings
            [ ''rm "$out/lib/chatgpt/resources/plugins/openai-bundled/plugins/latex/bin/tectonic"'' ]
            [ ''mkdir -p "$out/lib/chatgpt/resources/plugins/openai-bundled/plugins/latex/bin"
rm -f "$out/lib/chatgpt/resources/plugins/openai-bundled/plugins/latex/bin/tectonic"'' ]
            oldAttrs.installPhase;
      });
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
  ++ [ portmux ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    t3
    t3code
  ]
  ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 openaiChatgptDesktop
  ++ [
    tm
  ];

  # Use native Wayland for desktop input integration.
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
